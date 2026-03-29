## Test: Destruction Cleanup
##
## Unit tests verifying that when a ship is destroyed, its damage cards
## are returned to the discard pile and its persistent effects are
## unregistered from the EffectRegistry.
##
## Rules Reference: DM-030 — destroyed ships return damage cards.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Minimal stub that satisfies get_ship_instance().
var _StubShipToken: GDScript = GDScript.new()


func before_all() -> void:
	_StubShipToken = GDScript.new()
	_StubShipToken.source_code = """
extends Node2D

func get_ship_instance() -> RefCounted:
	return get_meta("ship_instance")
"""
	_StubShipToken.reload()


func before_each() -> void:
	GameManager.start_new_game()
	# Attach a DamageDeck to the game state for cleanup testing.
	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	GameManager.current_game_state.damage_deck = deck


func after_each() -> void:
	GameManager.is_game_active = false
	GameManager.current_game_state = null


## Creates a ShipInstance with the given hull, owner, and shields.
func _make_ship(hull: int, owner_player: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = hull
	data.point_cost = 50
	data.shields = {"FRONT": 2, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	data.defense_tokens = []
	data.max_speed = 2
	data.engineering_value = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1]]
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 1, owner_player)
	return ship


## Creates a stub Node2D token for the given ShipInstance.
func _make_token(si: ShipInstance) -> Node2D:
	var token: Node2D = Node2D.new()
	token.set_script(_StubShipToken)
	token.set_meta("ship_instance", si)
	add_child_autofree(token)
	return token


## Helper to create a DamageCard and deal it facedown to a ship.
func _deal_facedown(ship: ShipInstance, title: String) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", title)
	ship.add_facedown_damage(card)
	return card


## Helper to create a DamageCard and deal it faceup to a ship.
func _deal_faceup(ship: ShipInstance, title: String) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", title)
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


# ---------------------------------------------------------------------------
# ShipInstance.clear_all_damage_cards()
# ---------------------------------------------------------------------------


func test_clear_all_damage_cards_returns_all_cards() -> void:
	var ship: ShipInstance = _make_ship(5, 0)
	var c1: DamageCard = _deal_facedown(ship, "Structural Damage")
	var c2: DamageCard = _deal_facedown(ship, "Structural Damage")
	var c3: DamageCard = _deal_faceup(ship, "Ruptured Engine")
	var cards: Array = ship.clear_all_damage_cards()
	assert_eq(cards.size(), 3,
			"Should return all 3 damage cards (DM-030)")
	assert_has(cards, c1, "Should contain facedown card 1")
	assert_has(cards, c2, "Should contain facedown card 2")
	assert_has(cards, c3, "Should contain faceup card")


func test_clear_all_damage_cards_empties_ship_arrays() -> void:
	var ship: ShipInstance = _make_ship(5, 0)
	_deal_facedown(ship, "Structural Damage")
	_deal_faceup(ship, "Ruptured Engine")
	ship.clear_all_damage_cards()
	assert_eq(ship.facedown_damage.size(), 0,
			"Facedown array should be empty after clear")
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup array should be empty after clear")


func test_clear_all_damage_cards_empty_ship_returns_empty() -> void:
	var ship: ShipInstance = _make_ship(5, 0)
	var cards: Array = ship.clear_all_damage_cards()
	assert_eq(cards.size(), 0,
			"Should return empty array when no damage cards")


# ---------------------------------------------------------------------------
# Destruction cleanup — damage cards returned to discard pile
# ---------------------------------------------------------------------------


func test_destroyed_ship_cards_returned_to_discard() -> void:
	var si: ShipInstance = _make_ship(5, 0)
	GameManager.current_game_state.player_states[0].ships.append(si)
	# Need a second player ship to avoid game ending.
	var si1: ShipInstance = _make_ship(5, 1)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Deal 5 damage cards (enough to destroy).
	var dealt_cards: Array[DamageCard] = []
	for i: int in range(5):
		dealt_cards.append(_deal_facedown(si, "Structural Damage"))
	assert_true(si.is_destroyed(), "Ship should be destroyed (5 damage >= 5 hull)")
	var deck: DamageDeck = GameManager.current_game_state.damage_deck
	var discard_before: int = deck.get_discard_count()
	# Act — emit ship_destroyed.
	var token: Node2D = _make_token(si)
	EventBus.ship_destroyed.emit(token)
	# Assert — cards should be in discard pile.
	assert_eq(deck.get_discard_count(), discard_before + 5,
			"Discard pile should grow by 5 (DM-030)")
	assert_eq(si.facedown_damage.size(), 0,
			"Ship should have no facedown damage after cleanup")


func test_destroyed_ship_faceup_cards_also_returned() -> void:
	var si: ShipInstance = _make_ship(5, 0)
	GameManager.current_game_state.player_states[0].ships.append(si)
	var si1: ShipInstance = _make_ship(5, 1)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Mix of facedown and faceup.
	_deal_facedown(si, "Structural Damage")
	_deal_facedown(si, "Structural Damage")
	_deal_facedown(si, "Structural Damage")
	_deal_faceup(si, "Ruptured Engine")
	_deal_faceup(si, "Damaged Controls")
	assert_true(si.is_destroyed(), "Ship should be destroyed (5 damage >= 5 hull)")
	var deck: DamageDeck = GameManager.current_game_state.damage_deck
	var discard_before: int = deck.get_discard_count()
	var token: Node2D = _make_token(si)
	EventBus.ship_destroyed.emit(token)
	assert_eq(deck.get_discard_count(), discard_before + 5,
			"All 5 cards (3 facedown + 2 faceup) returned to discard (DM-030)")


# ---------------------------------------------------------------------------
# Destruction cleanup — effects unregistered
# ---------------------------------------------------------------------------


func test_destroyed_ship_effects_unregistered() -> void:
	var si: ShipInstance = _make_ship(5, 0)
	GameManager.current_game_state.player_states[0].ships.append(si)
	var si1: ShipInstance = _make_ship(5, 1)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Register a fake effect owned by this ship.
	var effect: GameEffect = GameEffect.new()
	effect.owner = si
	effect.source_type = GameEffect.EffectSource.DAMAGE_CARD
	effect.source_id = "ruptured_engine"
	var reg: EffectRegistry = GameManager.current_game_state.effect_registry
	reg.register(effect)
	assert_eq(reg.get_effect_count(), 1, "Pre-condition: 1 effect registered")
	# Destroy the ship.
	for i: int in range(5):
		_deal_facedown(si, "Structural Damage")
	var token: Node2D = _make_token(si)
	EventBus.ship_destroyed.emit(token)
	assert_eq(reg.get_effect_count(), 0,
			"Effect should be unregistered after ship destruction (DM-030)")

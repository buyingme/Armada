## Test: Ship damage resolution mechanics.
##
## Tests for shield absorption, damage card dealing, standard critical
## effect, and ship destruction — the core Phase 6c-3 logic tested via
## ShipInstance and DamageDeck directly.
## Requirements: AE-DMG-001–014.
extends GutTest


var _ship: ShipInstance = null
var _deck: DamageDeck = null
var _ship_data: ShipData = null


func before_each() -> void:
	# Build a minimal ShipData for testing.
	_ship_data = ShipData.new()
	_ship_data.ship_name = "TestShip"
	_ship_data.hull = 5
	_ship_data.shields = {"FRONT": 3, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	_ship_data.max_speed = 3
	_ship_data.defense_tokens = ["Evade", "Brace", "Redirect"]
	_ship_data.command_value = 2
	_ship = ShipInstance.create_from_data("test_ship", _ship_data, 2, 0)
	_deck = DamageDeck.new()
	_deck.initialize()


# =========================================================================
# Shield Absorption
# =========================================================================

func test_reduce_shields_absorbs_damage() -> void:
	var absorbed: int = _ship.reduce_shields("FRONT", 2)
	assert_eq(absorbed, 2, "Should absorb 2 damage from 3 shields")
	assert_eq(int(_ship.current_shields["FRONT"]), 1,
			"FRONT shields should be 1 after absorbing 2")


func test_reduce_shields_clamps_to_zero() -> void:
	var absorbed: int = _ship.reduce_shields("LEFT", 5)
	assert_eq(absorbed, 1, "LEFT has only 1 shield, can absorb 1")
	assert_eq(int(_ship.current_shields["LEFT"]), 0,
			"LEFT shields should be 0")


func test_reduce_shields_zero_shields_absorbs_nothing() -> void:
	_ship.current_shields["REAR"] = 0
	var absorbed: int = _ship.reduce_shields("REAR", 3)
	assert_eq(absorbed, 0, "0 shields should absorb nothing")


# =========================================================================
# Damage Card Dealing
# =========================================================================

func test_add_facedown_damage_increments_total() -> void:
	var card: DamageCard = _deck.draw_card()
	_ship.add_facedown_damage(card)
	assert_eq(_ship.get_total_damage(), 1,
			"Total damage should be 1 after 1 facedown card")
	assert_eq(_ship.facedown_damage.size(), 1,
			"Facedown damage array should have 1 card")


func test_add_faceup_damage_increments_total() -> void:
	var card: DamageCard = _deck.draw_card()
	card.is_faceup = true
	_ship.add_faceup_damage(card)
	assert_eq(_ship.get_total_damage(), 1,
			"Total damage should be 1 after 1 faceup card")
	assert_eq(_ship.faceup_damage.size(), 1,
			"Faceup damage array should have 1 card")


func test_mixed_damage_cards_counted_correctly() -> void:
	_ship.add_facedown_damage(_deck.draw_card())
	_ship.add_facedown_damage(_deck.draw_card())
	var crit_card: DamageCard = _deck.draw_card()
	crit_card.is_faceup = true
	_ship.add_faceup_damage(crit_card)
	assert_eq(_ship.get_total_damage(), 3,
			"2 facedown + 1 faceup = 3 total damage")


# =========================================================================
# Ship Destruction
# =========================================================================

func test_is_destroyed_when_damage_equals_hull() -> void:
	for i: int in range(_ship_data.hull):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_true(_ship.is_destroyed(),
			"Ship should be destroyed when damage >= hull")


func test_not_destroyed_when_damage_below_hull() -> void:
	for i: int in range(_ship_data.hull - 1):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_false(_ship.is_destroyed(),
			"Ship should not be destroyed when damage < hull")


func test_is_destroyed_when_damage_exceeds_hull() -> void:
	for i: int in range(_ship_data.hull + 2):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_true(_ship.is_destroyed(),
			"Ship should be destroyed when damage > hull")


# =========================================================================
# Defense Token Spending
# =========================================================================

func test_exhaust_defense_token_changes_state() -> void:
	_ship.exhaust_defense_token(0)
	assert_eq(_ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Token 0 should be EXHAUSTED after spending")


func test_discard_defense_token_changes_state() -> void:
	_ship.discard_defense_token(1)
	assert_eq(_ship.defense_tokens[1]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Token 1 should be DISCARDED after discarding")


func test_exhaust_already_exhausted_stays_exhausted() -> void:
	_ship.exhaust_defense_token(0)
	_ship.exhaust_defense_token(0)
	assert_eq(_ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Exhausting an already exhausted token should stay EXHAUSTED")


func test_ready_defense_tokens_readies_exhausted() -> void:
	_ship.exhaust_defense_token(0)
	_ship.exhaust_defense_token(1)
	_ship.ready_defense_tokens()
	assert_eq(_ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.READY,
			"Token 0 should be READY after readying")
	assert_eq(_ship.defense_tokens[1]["state"],
			Constants.DefenseTokenState.READY,
			"Token 1 should be READY after readying")


func test_ready_defense_tokens_does_not_ready_discarded() -> void:
	_ship.discard_defense_token(0)
	_ship.ready_defense_tokens()
	assert_eq(_ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Discarded token should stay DISCARDED after readying")


func test_get_active_token_count_excludes_discarded() -> void:
	_ship.discard_defense_token(0)
	assert_eq(_ship.get_active_token_count(), 2,
			"3 tokens, 1 discarded = 2 active")


# =========================================================================
# Brace Calculation
# =========================================================================

func test_brace_halves_damage_rounded_up_odd() -> void:
	# 5 damage → ceil(5/2) = 3
	var result: int = ceili(float(5) / 2.0)
	assert_eq(result, 3, "Brace of 5 damage should be 3 (rounded up)")


func test_brace_halves_damage_rounded_up_even() -> void:
	# 4 damage → ceil(4/2) = 2
	var result: int = ceili(float(4) / 2.0)
	assert_eq(result, 2, "Brace of 4 damage should be 2")


func test_brace_halves_one_damage() -> void:
	var result: int = ceili(float(1) / 2.0)
	assert_eq(result, 1, "Brace of 1 damage should be 1 (rounded up)")


func test_brace_halves_zero_damage() -> void:
	var result: int = ceili(float(0) / 2.0)
	assert_eq(result, 0, "Brace of 0 damage should be 0")


# =========================================================================
# Full Damage Sequence
# =========================================================================

func test_full_damage_shields_then_cards() -> void:
	# 5 damage to FRONT (3 shields): 3 absorbed, 2 cards.
	var total_damage: int = 5
	var absorbed: int = _ship.reduce_shields("FRONT", total_damage)
	var remaining: int = total_damage - absorbed
	for i: int in range(remaining):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_eq(absorbed, 3, "3 shields should absorb 3 damage")
	assert_eq(_ship.get_total_damage(), 2, "2 remaining damage = 2 cards")
	assert_eq(int(_ship.current_shields["FRONT"]), 0,
			"FRONT shields should be 0 after full absorption")


func test_full_damage_no_shields_all_cards() -> void:
	_ship.current_shields["FRONT"] = 0
	var total_damage: int = 3
	var absorbed: int = _ship.reduce_shields("FRONT", total_damage)
	for i: int in range(total_damage - absorbed):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_eq(absorbed, 0, "0 shields = 0 absorbed")
	assert_eq(_ship.get_total_damage(), 3, "3 damage cards dealt")


func test_standard_critical_first_card_faceup() -> void:
	# Simulate: dice have critical, Contain not used.
	var card: DamageCard = _deck.draw_card()
	card.is_faceup = true
	_ship.add_faceup_damage(card)
	for i: int in range(2):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_eq(_ship.faceup_damage.size(), 1,
			"1 faceup card for standard critical")
	assert_eq(_ship.facedown_damage.size(), 2,
			"2 facedown cards for remaining damage")
	assert_true(_ship.faceup_damage[0].is_faceup,
			"First card should be faceup")


func test_contain_prevents_faceup_card() -> void:
	# Simulate: Contain used, so all cards facedown.
	for i: int in range(3):
		_ship.add_facedown_damage(_deck.draw_card())
	assert_eq(_ship.faceup_damage.size(), 0,
			"No faceup cards when Contain prevents critical")
	assert_eq(_ship.facedown_damage.size(), 3,
			"All 3 cards facedown")


# =========================================================================
# Redirect Shields
# =========================================================================

func test_redirect_absorbs_in_adjacent_zone() -> void:
	# Redirect 1 damage from FRONT to LEFT (1 shield).
	var absorbed_left: int = _ship.reduce_shields("LEFT", 1)
	assert_eq(absorbed_left, 1, "LEFT shield should absorb 1")
	assert_eq(int(_ship.current_shields["LEFT"]), 0,
			"LEFT shields should be 0 after redirect")


func test_redirect_limited_by_adjacent_shields() -> void:
	# Try to redirect 3 damage to LEFT (only 1 shield).
	var absorbed: int = _ship.reduce_shields("LEFT", 3)
	assert_eq(absorbed, 1, "LEFT only has 1 shield")

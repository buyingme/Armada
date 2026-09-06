## OverlapDamageCommand
##
## Deals one facedown damage card to both the moving ship and the
## closest overlapped ship after a ship–ship overlap is resolved.
## Also handles destruction if the resulting damage exceeds hull.
##
## The authority/replay command draws both cards atomically. Passive Network
## peers apply only aggregate count changes from the accepted empty result.
##
## Payload:
##   [code]ship_index[/code]       — int — moving ship's fleet index
##   [code]other_owner[/code]      — int — overlapped ship's owner player
##   [code]other_ship_index[/code] — int — overlapped ship's fleet index
##
## Rules Reference: RRG "Overlapping", p.8 — OV-011.
class_name OverlapDamageCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("overlap_damage", func(
			player: int, pl: Dictionary) -> GameCommand:
		return OverlapDamageCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "overlap_damage", p_payload)


func application_contract_id() -> String:
	return "overlap_damage"


func project_application_result(_authority_result: Dictionary,
		_viewer_player: int) -> Dictionary:
	return {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not application_result.is_empty():
		return {}
	var ledger: PassiveDamageLedger = game_state.passive_damage_ledger
	if ledger == null or not ledger.can_consume_hidden_draws(2):
		return {}
	var moving: ShipInstance = game_state.get_ship(
			player_index, int(payload.get("ship_index", -1)))
	var other_owner: int = int(payload.get("other_owner", -1))
	var other_idx: int = int(payload.get("other_ship_index", -1))
	var other: ShipInstance = game_state.get_ship(other_owner, other_idx)
	if not ledger.consume_hidden_draws(2) \
			or not ledger.increment_facedown(moving.passive_damage_key()) \
			or not ledger.increment_facedown(other.passive_damage_key()):
		return {}
	return _finish_damage(moving, other, other_owner, other_idx)


## Validates that both ships and two damage draws are available.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var moving: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if moving == null:
		return "Moving ship not found."
	var other_owner: int = int(payload.get("other_owner", -1))
	var other_idx: int = int(payload.get("other_ship_index", -1))
	var other: ShipInstance = game_state.get_ship(other_owner, other_idx)
	if other == null:
		return "Overlapped ship not found."
	if game_state.passive_damage_ledger != null:
		if not game_state.passive_damage_ledger.can_consume_hidden_draws(2):
			return "Passive damage ledger does not contain two cards."
	elif game_state.damage_deck == null \
			or game_state.damage_deck.get_total_count() < 2:
		return "Damage deck does not contain two cards."
	return ""


## Deals facedown damage to both ships and checks for destruction.
func execute(game_state: GameState) -> Dictionary:
	var moving: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var other_owner: int = int(payload.get("other_owner", -1))
	var other_idx: int = int(payload.get("other_ship_index", -1))
	var other: ShipInstance = game_state.get_ship(other_owner, other_idx)
	var snapshot: Dictionary = game_state.damage_deck.serialize()
	# Draw and commit both cards inside the owning command.
	var m_card: DamageCard = game_state.damage_deck.draw_card()
	var o_card: DamageCard = game_state.damage_deck.draw_card()
	if m_card == null or o_card == null:
		game_state.damage_deck = DamageDeck.deserialize(snapshot)
		game_state.damage_deck.set_rng(game_state.rng)
		return {}
	m_card.is_faceup = false
	moving.add_facedown_damage(m_card)
	o_card.is_faceup = false
	other.add_facedown_damage(o_card)
	return _finish_damage(moving, other, other_owner, other_idx)


func _finish_damage(moving: ShipInstance, other: ShipInstance,
		other_owner: int, other_idx: int) -> Dictionary:
	var m_hull: int = moving.ship_data.hull - moving.get_total_damage()
	var m_destroyed: bool = moving.is_destroyed()
	if m_destroyed:
		moving.mark_destroyed()
	var o_hull: int = other.ship_data.hull - other.get_total_damage()
	var o_destroyed: bool = other.is_destroyed()
	if o_destroyed:
		other.mark_destroyed()
	return {
		"ship_index": payload.get("ship_index", -1),
		"other_owner": other_owner,
		"other_ship_index": other_idx,
		"moving_hull": m_hull,
		"moving_destroyed": m_destroyed,
		"other_hull": o_hull,
		"other_destroyed": o_destroyed,
	}

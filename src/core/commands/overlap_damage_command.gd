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


func application_contract_version() -> int:
	return 2


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_valid(application_result):
		return {}
	var ledger: PassiveDamageLedger = game_state.passive_damage_ledger
	if ledger == null or not ledger.can_consume_hidden_draws(2):
		return {}
	var moving: ShipInstance = game_state.get_ship(
			player_index, int(payload.get("ship_index", -1)))
	var other_owner: int = int(payload.get("other_owner", -1))
	var other_idx: int = int(payload.get("other_ship_index", -1))
	var other: ShipInstance = game_state.get_ship(other_owner, other_idx)
	var moving_destroyed: bool = moving.ship_data.hull \
			- moving.get_total_damage() - 1 <= 0
	var other_destroyed: bool = other.ship_data.hull \
			- other.get_total_damage() - 1 <= 0
	var dying: Array[Dictionary] = []
	if moving_destroyed:
		dying.append({"owner_player": player_index,
			"ship_index": int(payload["ship_index"])})
	if other_destroyed:
		dying.append({"owner_player": other_owner,
			"ship_index": other_idx})
	var moving_interrupted: bool = moving_destroyed \
			and moving.has_active_ship_activation()
	var other_interrupted: bool = other_destroyed \
			and other.has_active_ship_activation()
	var moving_next: int = DestroyUnitCommand.next_controller_after_source(
			game_state, player_index, dying) if moving_interrupted else -1
	var other_next: int = DestroyUnitCommand.next_controller_after_source(
			game_state, other_owner, dying) if other_interrupted else -1
	var moving_cleanup: Dictionary = application_result[
			"moving_destruction_cleanup"] as Dictionary
	var other_cleanup: Dictionary = application_result[
			"other_destruction_cleanup"] as Dictionary
	if application_result["ship_index"] != payload["ship_index"] \
			or application_result["other_owner"] != other_owner \
			or application_result["other_ship_index"] != other_idx \
			or application_result["moving_hull"] \
				!= moving.ship_data.hull - moving.get_total_damage() - 1 \
			or application_result["other_hull"] \
				!= other.ship_data.hull - other.get_total_damage() - 1 \
			or application_result["moving_destroyed"] != moving_destroyed \
			or application_result["other_destroyed"] != other_destroyed \
			or (moving_destroyed and not DestroyUnitCommand.prevalidate_source_cleanup(
					moving_cleanup, moving.get_facedown_damage_count() + 1,
					moving_interrupted, moving_next)) \
			or (not moving_destroyed and not moving_cleanup.is_empty()) \
			or (other_destroyed and not DestroyUnitCommand.prevalidate_source_cleanup(
					other_cleanup, other.get_facedown_damage_count() + 1,
					other_interrupted, other_next)) \
			or (not other_destroyed and not other_cleanup.is_empty()):
		return {}
	if not ledger.consume_hidden_draws(2) \
			or not ledger.increment_facedown(moving.passive_damage_key()) \
			or not ledger.increment_facedown(other.passive_damage_key()):
		return {}
	return _finish_damage(game_state, moving, other, other_owner, other_idx,
			moving_cleanup, other_cleanup, true)


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
	return _finish_damage(game_state, moving, other, other_owner, other_idx)


func _finish_damage(game_state: GameState, moving: ShipInstance,
		other: ShipInstance, other_owner: int, other_idx: int,
		projected_moving_cleanup: Dictionary = {},
		projected_other_cleanup: Dictionary = {}, passive: bool = false) -> Dictionary:
	var m_hull: int = moving.ship_data.hull - moving.get_total_damage()
	var m_destroyed: bool = moving.is_destroyed()
	var m_interrupted: bool = m_destroyed and moving.has_active_ship_activation()
	if m_destroyed:
		moving.mark_destroyed()
	var o_hull: int = other.ship_data.hull - other.get_total_damage()
	var o_destroyed: bool = other.is_destroyed()
	var o_interrupted: bool = o_destroyed and other.has_active_ship_activation()
	if o_destroyed:
		other.mark_destroyed()
	var moving_cleanup: Dictionary = {}
	var other_cleanup: Dictionary = {}
	if m_destroyed:
		if passive:
			if not DestroyUnitCommand.install_cleanup_in_source(game_state,
					player_index, int(payload["ship_index"]), m_interrupted,
					projected_moving_cleanup):
				return {}
			moving_cleanup = projected_moving_cleanup
		else:
			moving_cleanup = DestroyUnitCommand.cleanup_in_source(game_state,
					player_index, int(payload["ship_index"]), m_interrupted)
	if o_destroyed:
		if passive:
			if not DestroyUnitCommand.install_cleanup_in_source(game_state,
					other_owner, other_idx, o_interrupted,
					projected_other_cleanup):
				return {}
			other_cleanup = projected_other_cleanup
		else:
			other_cleanup = DestroyUnitCommand.cleanup_in_source(game_state,
					other_owner, other_idx, o_interrupted)
	return {
		"ship_index": payload.get("ship_index", -1),
		"other_owner": other_owner,
		"other_ship_index": other_idx,
		"moving_hull": m_hull,
		"moving_destroyed": m_destroyed,
		"other_hull": o_hull,
		"other_destroyed": o_destroyed,
		"moving_destruction_cleanup": moving_cleanup,
		"other_destruction_cleanup": other_cleanup,
	}


static func _result_valid(result: Dictionary) -> bool:
	var keys: Array[String] = ["ship_index", "other_owner",
		"other_ship_index", "moving_hull", "moving_destroyed",
		"other_hull", "other_destroyed", "moving_destruction_cleanup",
		"other_destruction_cleanup"]
	if result.size() != keys.size():
		return false
	for key: String in keys:
		if not result.has(key):
			return false
	return typeof(result["ship_index"]) == TYPE_INT \
			and typeof(result["other_owner"]) == TYPE_INT \
			and typeof(result["other_ship_index"]) == TYPE_INT \
			and typeof(result["moving_hull"]) == TYPE_INT \
			and typeof(result["other_hull"]) == TYPE_INT \
			and typeof(result["moving_destroyed"]) == TYPE_BOOL \
			and typeof(result["other_destroyed"]) == TYPE_BOOL \
			and result["moving_destruction_cleanup"] is Dictionary \
			and result["other_destruction_cleanup"] is Dictionary

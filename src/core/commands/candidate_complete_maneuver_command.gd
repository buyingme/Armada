## Dormant protocol-7 normal Maneuver completion candidate.
class_name CandidateCompleteManeuverCommand
extends GameCommand


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")
const OBSTACLES: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")
const EXACT_PAYLOAD_KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "complete_maneuver", p_payload)


func application_contract_id() -> String:
	return "complete_maneuver"


func application_contract_version() -> int:
	return 2


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_is_valid(authority_result) \
			else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_is_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	var expected: Dictionary = payload.duplicate(true)
	expected["maneuver_opportunity_disposition"] = "CONSUMED"
	expected["maneuver_execution_retired"] = true
	if application_result != expected:
		return {}
	var applied: Dictionary = execute(game_state)
	return application_result.duplicate(true) if applied == expected else {}


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, EXACT_PAYLOAD_KEYS) \
			or typeof(payload.get("owner_player")) != TYPE_INT \
			or typeof(payload.get("ship_index")) != TYPE_INT \
			or typeof(payload.get("ship_activation_identity")) != TYPE_STRING \
			or str(payload["ship_activation_identity"]).is_empty() \
			or typeof(payload.get("maneuver_execution_id")) != TYPE_STRING \
			or str(payload["maneuver_execution_id"]).is_empty():
		return "Invalid complete_maneuver payload."
	if int(payload["owner_player"]) != player_index:
		return "Wrong Maneuver owner."
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return "Ship is unavailable."
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity", "")) \
			!= str(payload["ship_activation_identity"]) \
			or str(execution.get("maneuver_execution_id", "")) \
			!= str(payload["maneuver_execution_id"]):
		return "Maneuver execution identity mismatch."
	if not bool(execution.get("final_transform_applied", false)):
		return "Final Maneuver transform has not been applied."
	var collision: Dictionary = execution.get("ship_collision", {}) \
			as Dictionary
	if str(collision.get("kind", "")) == "closest_ship" \
			and not bool(collision.get("damage_resolved", false)):
		return "Ship collision damage remains unresolved."
	if ship.has_active_immediate_resolution():
		return "An immediate damage obligation remains unresolved."
	if ship.has_active_obstacle_resolution() \
			or not OBSTACLES.unresolved_overlaps(
					game_state, player_index, int(payload["ship_index"]),
					str(payload["maneuver_execution_id"])).is_empty():
		return "An obstacle consequence remains unresolved."
	if not AUTHORITY.derive_affected_squadrons_from_canonical(
			game_state, player_index, int(payload["ship_index"])).is_empty():
		return "Squadron displacement remains unresolved."
	if str(collision.get("kind", "")) == "closest_ship":
		for raw_card: Variant in ship.faceup_damage:
			if raw_card is DamageCard:
				var card: DamageCard = raw_card as DamageCard
				if card.is_faceup and card.effect_id == "damaged_controls" \
						and card.last_damaged_controls_execution_id \
								!= str(payload["maneuver_execution_id"]):
					return "Ship-collision Damaged Controls remains unresolved."
	if ship.current_speed > 1:
		for raw_card: Variant in ship.faceup_damage:
			if raw_card is DamageCard:
				var card: DamageCard = raw_card as DamageCard
				if card.is_faceup and card.effect_id == "ruptured_engine" \
						and card.last_ruptured_engine_execution_id \
								!= str(payload["maneuver_execution_id"]):
					return "Ruptured Engine remains unresolved."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload["ship_index"]))
	if not ship.complete_maneuver_execution(
			str(payload["ship_activation_identity"]),
			str(payload["maneuver_execution_id"]), true):
		return {}
	return {
		"owner_player": player_index,
		"ship_index": int(payload["ship_index"]),
		"ship_activation_identity": payload["ship_activation_identity"],
		"maneuver_execution_id": payload["maneuver_execution_id"],
		"maneuver_opportunity_disposition": "CONSUMED",
		"maneuver_execution_retired": true,
	}


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true


static func _result_is_valid(result: Dictionary) -> bool:
	var keys: Array[String] = EXACT_PAYLOAD_KEYS.duplicate()
	keys.append_array([
		"maneuver_opportunity_disposition", "maneuver_execution_retired"])
	return _has_exact_keys(result, keys) \
			and typeof(result.get("owner_player")) == TYPE_INT \
			and int(result["owner_player"]) in [0, 1] \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and int(result["ship_index"]) >= 0 \
			and typeof(result.get("ship_activation_identity")) == TYPE_STRING \
			and not str(result["ship_activation_identity"]).is_empty() \
			and typeof(result.get("maneuver_execution_id")) == TYPE_STRING \
			and not str(result["maneuver_execution_id"]).is_empty() \
			and result.get("maneuver_opportunity_disposition") == "CONSUMED" \
			and result.get("maneuver_execution_retired") == true

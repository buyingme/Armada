## Dormant protocol-7 final Maneuver transform application candidate.
##
## Authority generates this command only after all post-commitment/
## pre-movement obligations have converged. It is intentionally unregistered
## before the coordinated WP6 cutover.
class_name CandidateApplyManeuverTransformCommand
extends GameCommand


const PRE_MOVEMENT: GDScript = preload(
		"res://src/core/movement/maneuver_pre_movement_evaluator.gd")
const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")
const EXACT_PAYLOAD_KEYS: Array[String] = [
	"owner_player",
	"ship_index",
	"ship_activation_identity",
	"maneuver_execution_id",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "apply_maneuver_transform", p_payload)


func application_contract_id() -> String:
	return "apply_maneuver_transform"


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
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload["ship_index"]))
	var committed: Dictionary = ship.active_maneuver_execution_snapshot()[
			"committed_result"]
	var expected: Dictionary = payload.duplicate(true)
	expected["pos_x"] = committed["pos_x"]
	expected["pos_y"] = committed["pos_y"]
	expected["rotation_deg"] = committed["rotation_deg"]
	expected["final_transform_applied"] = true
	if application_result != expected:
		return {}
	var applied: Dictionary = execute(game_state)
	return application_result.duplicate(true) if applied == expected else {}


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, EXACT_PAYLOAD_KEYS):
		return "Invalid apply_maneuver_transform payload shape."
	for key: String in ["owner_player", "ship_index"]:
		if typeof(payload[key]) != TYPE_INT:
			return "Invalid apply_maneuver_transform payload types."
	for key: String in ["ship_activation_identity", "maneuver_execution_id"]:
		if typeof(payload[key]) != TYPE_STRING or str(payload[key]).is_empty():
			return "Invalid apply_maneuver_transform payload types."
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
	if bool(execution.get("final_transform_applied", false)) \
			or not execution.has("committed_result"):
		return "Final Maneuver transform is not pending."
	if PRE_MOVEMENT.has_mandatory_work(ship):
		return "A pre-movement obligation remains active."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload["ship_index"]))
	var applied: Dictionary = ship.apply_maneuver_final_transform(
			str(payload["ship_activation_identity"]),
			str(payload["maneuver_execution_id"]))
	if applied.is_empty():
		return {}
	# SMI-065 is evaluated from the actual applied result. Its exceptional
	# cleanup preserves the final transform and never fabricates completion.
	if not AUTHORITY.canonical_ship_is_inside_play_area(
			game_state, player_index, int(payload["ship_index"])):
		ship.mark_destroyed()
	return {
		"owner_player": player_index,
		"ship_index": int(payload["ship_index"]),
		"ship_activation_identity": payload["ship_activation_identity"],
		"maneuver_execution_id": payload["maneuver_execution_id"],
		"pos_x": applied["pos_x"],
		"pos_y": applied["pos_y"],
		"rotation_deg": applied["rotation_deg"],
		"final_transform_applied": true,
	}


static func _has_exact_keys(value: Dictionary,
		expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


static func _result_is_valid(result: Dictionary) -> bool:
	var keys: Array[String] = EXACT_PAYLOAD_KEYS.duplicate()
	keys.append_array([
		"pos_x", "pos_y", "rotation_deg", "final_transform_applied"])
	if not _has_exact_keys(result, keys) \
			or typeof(result.get("owner_player")) != TYPE_INT \
			or int(result["owner_player"]) not in [0, 1] \
			or typeof(result.get("ship_index")) != TYPE_INT \
			or int(result["ship_index"]) < 0 \
			or typeof(result.get("ship_activation_identity")) != TYPE_STRING \
			or str(result["ship_activation_identity"]).is_empty() \
			or typeof(result.get("maneuver_execution_id")) != TYPE_STRING \
			or str(result["maneuver_execution_id"]).is_empty() \
			or result.get("final_transform_applied") != true:
		return false
	for key: String in ["pos_x", "pos_y", "rotation_deg"]:
		if typeof(result.get(key)) != TYPE_FLOAT \
				or not is_finite(float(result[key])):
			return false
	return true

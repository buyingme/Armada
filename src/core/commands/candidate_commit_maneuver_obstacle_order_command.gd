## Dormant v7 purpose-order boundary for final-position obstacle consequences.
class_name CandidateCommitManeuverObstacleOrderCommand
extends GameCommand


const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")
const KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id", "obstacle_ids",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "commit_maneuver_obstacle_order", p_payload)


func application_contract_id() -> String:
	return command_type


func application_contract_version() -> int:
	return 2


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _exact_keys(payload, KEYS) \
			or typeof(payload.get("owner_player")) != TYPE_INT \
			or typeof(payload.get("ship_index")) != TYPE_INT \
			or not payload.get("obstacle_ids") is Array:
		return "Invalid obstacle-order payload."
	var owner: int = int(payload["owner_player"])
	var ship: ShipInstance = game_state.get_ship(owner, int(payload["ship_index"]))
	if player_index != owner or ship == null or ship.is_destroyed():
		return "Invalid obstacle-order actor or ship."
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity", "")) \
			!= str(payload["ship_activation_identity"]) \
			or str(execution.get("maneuver_execution_id", "")) \
					!= str(payload["maneuver_execution_id"]) \
			or not bool(execution.get("final_transform_applied", false)) \
			or not (execution.get("obstacle_resolution_order", []) as Array).is_empty():
		return "Obstacle order is stale or already committed."
	var unresolved: Array[Dictionary] = OVERLAP.unresolved_overlaps(
			game_state, owner, int(payload["ship_index"]),
			str(payload["maneuver_execution_id"]))
	var required: Dictionary = {}
	for item: Dictionary in unresolved:
		if str(item["obstacle_type"]) == "station" \
				and game_state.selected_objective_key() \
						== "obj_def_contested_outpost":
			return "Station behavior is unsupported for the active objective."
		required[str(item["obstacle_id"])] = true
	var submitted: Array = payload["obstacle_ids"] as Array
	var seen: Dictionary = {}
	for raw: Variant in submitted:
		if typeof(raw) != TYPE_STRING or not required.has(str(raw)) \
				or seen.has(str(raw)):
			return "Obstacle order does not match current final overlaps."
		seen[str(raw)] = true
	if seen.size() != required.size() or seen.is_empty():
		return "Obstacle order must contain every unresolved overlap exactly once."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	var ids: Array[String] = []
	for raw: Variant in payload["obstacle_ids"] as Array:
		ids.append(str(raw))
	if not ship.commit_maneuver_obstacle_order(
			str(payload["ship_activation_identity"]),
			str(payload["maneuver_execution_id"]), ids) \
			or not OVERLAP.open_next_purpose_resolution(
					game_state, int(payload["owner_player"]),
					int(payload["ship_index"])):
		return {}
	return payload.duplicate(true)


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _exact_keys(
					authority_result, KEYS) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if application_result != payload or not validate(game_state).is_empty():
		return {}
	return execute(game_state)


static func _exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true

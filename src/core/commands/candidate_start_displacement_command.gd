## Dormant protocol-7 authority-generated displacement opener.
class_name CandidateStartDisplacementCommand
extends GameCommand


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")
const FLOW_SPEC: GDScript = preload("res://src/core/state/flow_spec.gd")
const KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id", "displaced_squadrons",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "start_displacement", p_payload)


func application_contract_id() -> String:
	return "start_displacement"


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
	expected["controller_player"] = 1 - int(payload["owner_player"])
	if application_result != expected:
		return {}
	var applied: Dictionary = execute(game_state)
	return application_result.duplicate(true) if applied == expected else {}


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, KEYS) \
			or typeof(payload["owner_player"]) != TYPE_INT \
			or typeof(payload["ship_index"]) != TYPE_INT \
			or typeof(payload["ship_activation_identity"]) != TYPE_STRING \
			or typeof(payload["maneuver_execution_id"]) != TYPE_STRING \
			or not payload["displaced_squadrons"] is Array:
		return "Invalid start_displacement v2 payload."
	var owner: int = int(payload["owner_player"])
	if player_index != owner:
		return "Wrong moving-ship authority."
	var ship: ShipInstance = game_state.get_ship(
			owner, int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return "Moving ship is unavailable."
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity", "")) \
			!= str(payload["ship_activation_identity"]) \
			or str(execution.get("maneuver_execution_id", "")) \
			!= str(payload["maneuver_execution_id"]) \
			or not bool(execution.get("final_transform_applied", false)):
		return "Displacement is outside the applied Maneuver execution."
	if game_state.interaction_flow != null \
			and game_state.interaction_flow.flow_type \
					== Constants.InteractionFlow.SQUADRON_DISPLACEMENT:
		return "Displacement is already active."
	var derived: Array[Dictionary] = AUTHORITY \
			.derive_affected_squadrons_from_canonical(
					game_state, owner, int(payload["ship_index"]))
	if derived.is_empty() or not _same_identities(
			derived, payload["displaced_squadrons"] as Array):
		return "Displaced Squadron set is incomplete or stale."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var displaced: Array = (payload["displaced_squadrons"] as Array) \
			.duplicate(true)
	var controller: int = 1 - int(payload["owner_player"])
	game_state.interaction_flow = FLOW_SPEC.make_interaction_flow(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			game_state, {"moving_player": int(payload["owner_player"])},
			Constants.Visibility.ALL, {
				"owner_player": payload["owner_player"],
				"ship_index": payload["ship_index"],
				"ship_activation_identity": payload[
						"ship_activation_identity"],
				"maneuver_execution_id": payload["maneuver_execution_id"],
				"displaced_squadrons": displaced,
			})
	var result: Dictionary = payload.duplicate(true)
	result["controller_player"] = controller
	return result


static func _same_identities(a: Array, b: Array) -> bool:
	return _identity_keys(a) == _identity_keys(b)


static func _identity_keys(values: Array) -> Array[String]:
	var keys: Array[String] = []
	for raw: Variant in values:
		if not raw is Dictionary:
			return []
		var data: Dictionary = raw as Dictionary
		if not _has_exact_keys(data, ["owner", "squadron_index"]) \
				or typeof(data["owner"]) != TYPE_INT \
				or typeof(data["squadron_index"]) != TYPE_INT:
			return []
		var key: String = "%d:%d" % [data["owner"], data["squadron_index"]]
		if key in keys:
			return []
		keys.append(key)
	keys.sort()
	return keys


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true


static func _result_is_valid(result: Dictionary) -> bool:
	var keys: Array[String] = KEYS.duplicate()
	keys.append("controller_player")
	return _has_exact_keys(result, keys) \
			and typeof(result.get("owner_player")) == TYPE_INT \
			and int(result["owner_player"]) in [0, 1] \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and int(result["ship_index"]) >= 0 \
			and typeof(result.get("ship_activation_identity")) == TYPE_STRING \
			and not str(result["ship_activation_identity"]).is_empty() \
			and typeof(result.get("maneuver_execution_id")) == TYPE_STRING \
			and not str(result["maneuver_execution_id"]).is_empty() \
			and result.get("displaced_squadrons") is Array \
			and typeof(result.get("controller_player")) == TYPE_INT \
			and int(result["controller_player"]) \
					== 1 - int(result["owner_player"]) \
			and _identity_keys(result.get("displaced_squadrons", []) as Array) \
					.size() == (result.get("displaced_squadrons", []) as Array).size()

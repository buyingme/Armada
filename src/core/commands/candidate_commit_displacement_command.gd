## Dormant protocol-7 complete-batch Squadron displacement candidate.
class_name CandidateCommitDisplacementCommand
extends GameCommand


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_displacement_authority.gd")
const KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id", "placements", "excluded_squadrons",
]
var _last_deficiency: Dictionary = {}


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "commit_displacement", p_payload)


func application_contract_id() -> String:
	return "commit_displacement"


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
	var expected: Dictionary = {
		"owner_player": payload["owner_player"],
		"ship_index": payload["ship_index"],
		"ship_activation_identity": payload["ship_activation_identity"],
		"maneuver_execution_id": payload["maneuver_execution_id"],
		"placements": (payload["placements"] as Array).duplicate(true),
		"destroyed_squadrons":
				(payload["excluded_squadrons"] as Array).duplicate(true),
	}
	if application_result != expected:
		return {}
	var applied: Dictionary = execute(game_state)
	return application_result.duplicate(true) if applied == expected else {}


func rejection_projection() -> Dictionary:
	return _last_deficiency.duplicate(true)


func validate(game_state: GameState) -> String:
	_last_deficiency.clear()
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, KEYS) \
			or typeof(payload["owner_player"]) != TYPE_INT \
			or typeof(payload["ship_index"]) != TYPE_INT \
			or typeof(payload["ship_activation_identity"]) != TYPE_STRING \
			or typeof(payload["maneuver_execution_id"]) != TYPE_STRING \
			or not payload["placements"] is Array \
			or not payload["excluded_squadrons"] is Array:
		return "Invalid commit_displacement v2 payload."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type \
			!= Constants.InteractionFlow.SQUADRON_DISPLACEMENT \
			or flow.step_id != Constants.InteractionStep.DISPLACEMENT_PLACE \
			or player_index != flow.controller_player:
		return "No matching controlled displacement decision."
	for key: String in [
		"owner_player", "ship_index", "ship_activation_identity",
		"maneuver_execution_id"]:
		if payload[key] != flow.payload.get(key):
			return "Displacement Maneuver identity mismatch."
	var ship: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return "Moving ship is unavailable."
	var analysis: Dictionary = AUTHORITY.analyze_batch(
			game_state, int(payload["owner_player"]), int(payload["ship_index"]),
			flow.payload.get("displaced_squadrons", []) as Array,
			payload["placements"] as Array,
			payload["excluded_squadrons"] as Array)
	if not bool(analysis.get("ok", false)):
		for key: String in [
			"required_placeable_count", "submitted_placeable_count",
			"required_direct_touch_count", "submitted_direct_touch_count"]:
			_last_deficiency[key] = int(analysis.get(key, 0))
		return str(analysis.get("reason", "Invalid displacement batch."))
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var placements: Array = (payload["placements"] as Array).duplicate(true)
	var destroyed: Array[Dictionary] = []
	for raw: Variant in placements:
		var data: Dictionary = raw as Dictionary
		var squadron: SquadronInstance = game_state.get_squadron(
				int(data["owner"]), int(data["squadron_index"]))
		squadron.pos_x = float(data["pos_x"])
		squadron.pos_y = float(data["pos_y"])
	for raw: Variant in payload["excluded_squadrons"]:
		var identity: Dictionary = (raw as Dictionary).duplicate(true)
		var squadron: SquadronInstance = game_state.get_squadron(
				int(identity["owner"]), int(identity["squadron_index"]))
		squadron.mark_destroyed()
		destroyed.append(identity)
	game_state.interaction_flow = InteractionFlow.empty()
	return {
		"owner_player": payload["owner_player"],
		"ship_index": payload["ship_index"],
		"ship_activation_identity": payload["ship_activation_identity"],
		"maneuver_execution_id": payload["maneuver_execution_id"],
		"placements": placements,
		"destroyed_squadrons": destroyed,
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
	if not (_has_exact_keys(result, [
		"owner_player", "ship_index", "ship_activation_identity",
		"maneuver_execution_id", "placements", "destroyed_squadrons"]) \
			and typeof(result.get("owner_player")) == TYPE_INT \
			and int(result["owner_player"]) in [0, 1] \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and int(result["ship_index"]) >= 0 \
			and typeof(result.get("ship_activation_identity")) == TYPE_STRING \
			and not str(result["ship_activation_identity"]).is_empty() \
			and typeof(result.get("maneuver_execution_id")) == TYPE_STRING \
			and not str(result["maneuver_execution_id"]).is_empty() \
			and result.get("placements") is Array \
			and result.get("destroyed_squadrons") is Array):
		return false
	var seen: Dictionary = {}
	for raw: Variant in result["placements"] as Array:
		if not raw is Dictionary:
			return false
		var placement: Dictionary = raw as Dictionary
		if not _has_exact_keys(placement,
				["owner", "squadron_index", "pos_x", "pos_y"]) \
				or typeof(placement["owner"]) != TYPE_INT \
				or int(placement["owner"]) not in [0, 1] \
				or typeof(placement["squadron_index"]) != TYPE_INT \
				or int(placement["squadron_index"]) < 0 \
				or typeof(placement["pos_x"]) != TYPE_FLOAT \
				or typeof(placement["pos_y"]) != TYPE_FLOAT \
				or not is_finite(float(placement["pos_x"])) \
				or not is_finite(float(placement["pos_y"])):
			return false
		var key: String = "%d:%d" % [placement["owner"],
				placement["squadron_index"]]
		if seen.has(key):
			return false
		seen[key] = true
	for raw: Variant in result["destroyed_squadrons"] as Array:
		if not raw is Dictionary:
			return false
		var identity: Dictionary = raw as Dictionary
		if not _has_exact_keys(identity, ["owner", "squadron_index"]) \
				or typeof(identity["owner"]) != TYPE_INT \
				or int(identity["owner"]) not in [0, 1] \
				or typeof(identity["squadron_index"]) != TYPE_INT \
				or int(identity["squadron_index"]) < 0:
			return false
		var key: String = "%d:%d" % [identity["owner"],
				identity["squadron_index"]]
		if seen.has(key):
			return false
		seen[key] = true
	return true

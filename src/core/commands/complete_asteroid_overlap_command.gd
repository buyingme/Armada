## Completes a surviving non-immediate Asteroid after its card inspection.
class_name CompleteAsteroidOverlapCommand
extends GameCommand


const TYPE: String = "complete_asteroid_overlap"
const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")
const KEYS: Array[String] = ["owner_player", "ship_index",
	"ship_activation_identity", "maneuver_execution_id",
	"ordered_ordinal", "occurrence_id", "obstacle_id",
	"inspection_id"]


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return CompleteAsteroidOverlapCommand.new(player, pl))


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


func application_contract_id() -> String:
	return TYPE


func application_contract_version() -> int:
	return 1


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if payload.size() != KEYS.size():
		return "Invalid Asteroid completion identity."
	for key: String in KEYS:
		if not payload.has(key):
			return "Invalid Asteroid completion identity."
	for key: String in ["owner_player", "ship_index", "ordered_ordinal"]:
		if typeof(payload[key]) != TYPE_INT:
			return "Invalid Asteroid completion target."
	for key: String in ["ship_activation_identity", "maneuver_execution_id",
			"occurrence_id", "obstacle_id", "inspection_id"]:
		if typeof(payload[key]) != TYPE_STRING or str(payload[key]).is_empty():
			return "Invalid Asteroid completion identity."
	if player_index != int(payload["owner_player"]):
		return "Only the Maneuver authority completes this Asteroid."
	var ship: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	if ship == null or ship.is_destroyed() \
			or not ship.has_active_maneuver_execution() \
			or ship.has_active_immediate_resolution() \
			or game_state.faceup_damage_inspection != null:
		return "Asteroid completion is not ready."
	var record: Dictionary = ship.asteroid_completion_outstanding_snapshot()
	if record != _record_from_payload(true):
		return "Asteroid completion is stale or unreleased."
	var placement: Dictionary = game_state.obstacle_placement(
			str(payload["obstacle_id"]))
	if placement.is_empty() \
			or (game_state.passive_damage_ledger == null \
				and placement.get("last_maneuver_execution_id") \
					== payload["maneuver_execution_id"]):
		return "Asteroid completion was already committed."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var owner: int = int(payload["owner_player"])
	var index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, index)
	var boundary_before: Dictionary = ship.ship_activation_boundary_snapshot()
	var placement: Dictionary = game_state.obstacle_placement(
			str(payload["obstacle_id"]))
	var marker_before: String = str(placement.get(
			"last_maneuver_execution_id", ""))
	if not ship.consume_released_asteroid_completion(
			_record_from_payload(true)) \
			or not game_state.mark_obstacle_resolved_for_maneuver(
				str(payload["obstacle_id"]),
				str(payload["maneuver_execution_id"])) \
			or not OVERLAP.open_next_purpose_resolution(game_state,
				owner, index, str(payload["obstacle_id"])):
		ship.restore_ship_activation_boundary(boundary_before)
		if game_state.passive_damage_ledger == null:
			placement["last_maneuver_execution_id"] = marker_before
		return {}
	var result: Dictionary = payload.duplicate(true)
	result["next_obstacle_pre_effect"] = \
			ship.pending_obstacle_pre_effect_snapshot()
	return result


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	for key: String in KEYS:
		if application_result[key] != payload[key]:
			return {}
	var expected_next: Dictionary = OVERLAP.next_pre_effect_after(
			game_state, int(payload["owner_player"]),
			int(payload["ship_index"]), int(payload["ordered_ordinal"]))
	if application_result["next_obstacle_pre_effect"] != expected_next:
		return {}
	var applied: Dictionary = execute(game_state)
	return application_result.duplicate(true) \
			if applied == application_result else {}


func _record_from_payload(released: bool) -> Dictionary:
	return {"ship_activation_identity": payload["ship_activation_identity"],
		"maneuver_execution_id": payload["maneuver_execution_id"],
		"ordered_ordinal": payload["ordered_ordinal"],
		"occurrence_id": payload["occurrence_id"],
		"obstacle_id": payload["obstacle_id"],
		"inspection_id": payload["inspection_id"],
		"inspection_released": released}


static func _result_valid(result: Dictionary) -> bool:
	if result.size() != KEYS.size() + 1 \
			or not result.get("next_obstacle_pre_effect") is Dictionary:
		return false
	for key: String in KEYS:
		if not result.has(key):
			return false
	return true

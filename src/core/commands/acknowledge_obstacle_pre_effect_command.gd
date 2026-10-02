## Records one principal's notice of the next Maneuver obstacle consequence.
class_name AcknowledgeObstaclePreEffectCommand
extends GameCommand


const TYPE: String = "acknowledge_obstacle_pre_effect"


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return AcknowledgeObstaclePreEffectCommand.new(player, pl))


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
	if payload.size() != 1 \
			or typeof(payload.get("occurrence_id")) != TYPE_STRING:
		return "Obstacle acknowledgment requires one occurrence identity."
	var ship: ShipInstance = game_state.get_active_ship_activation()
	if ship == null or not ship.has_active_maneuver_execution():
		return "No active Maneuver owns an obstacle notice."
	var record: Dictionary = ship.pending_obstacle_pre_effect_snapshot()
	if record.is_empty() or record.get("occurrence_id") \
			!= payload["occurrence_id"]:
		return "No matching obstacle notice is pending."
	var principal_id: String = game_state.principal_id_for_player(player_index)
	if principal_id.is_empty() \
			or principal_id not in record["required_principal_ids"]:
		return "Player is not required for this obstacle notice."
	if principal_id in record["received_principal_ids"]:
		return "Obstacle notice was already acknowledged."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = game_state.get_active_ship_activation()
	var occurrence_id: String = str(payload["occurrence_id"])
	var principal_id: String = game_state.principal_id_for_player(player_index)
	if not ship.acknowledge_obstacle_pre_effect(occurrence_id, principal_id):
		return {}
	var record: Dictionary = ship.pending_obstacle_pre_effect_snapshot()
	return {"occurrence_id": occurrence_id, "principal_id": principal_id,
		"released": record["required_principal_ids"] \
				== record["received_principal_ids"]}


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = game_state.get_active_ship_activation()
	var record: Dictionary = ship.pending_obstacle_pre_effect_snapshot()
	var principal_id: String = game_state.principal_id_for_player(player_index)
	var expected_release: bool = (record["received_principal_ids"] as Array) \
			.size() + 1 == (record["required_principal_ids"] as Array).size()
	if application_result != {"occurrence_id": payload["occurrence_id"],
			"principal_id": principal_id, "released": expected_release}:
		return {}
	return execute(game_state)


static func _result_valid(result: Dictionary) -> bool:
	return result.size() == 3 \
			and typeof(result.get("occurrence_id")) == TYPE_STRING \
			and typeof(result.get("principal_id")) == TYPE_STRING \
			and typeof(result.get("released")) == TYPE_BOOL

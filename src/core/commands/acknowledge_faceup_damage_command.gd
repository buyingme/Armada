## Records one principal's acknowledgment of a dealt faceup damage card.
class_name AcknowledgeFaceupDamageCommand
extends GameCommand


const TYPE: String = "acknowledge_faceup_damage"


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return AcknowledgeFaceupDamageCommand.new(player, pl))


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
	if payload.size() != 1 or typeof(payload.get("inspection_id")) != TYPE_STRING:
		return "Faceup acknowledgment requires exactly one inspection identity."
	var inspection: FaceupDamageInspection = game_state.faceup_damage_inspection
	if inspection == null or inspection.inspection_id() \
			!= str(payload["inspection_id"]):
		return "No matching faceup inspection is pending."
	var principal_id: String = game_state.principal_id_for_player(player_index)
	if principal_id.is_empty() \
			or not inspection.required_principal_ids().has(principal_id):
		return "Player is not required to acknowledge this faceup card."
	if inspection.has_received(principal_id):
		return "Faceup acknowledgment was already received."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var inspection_id: String = str(payload["inspection_id"])
	var principal_id: String = game_state.principal_id_for_player(player_index)
	return game_state.apply_faceup_damage_acknowledgment(
			inspection_id, principal_id)


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	var inspection: FaceupDamageInspection = game_state.faceup_damage_inspection
	var principal_id: String = game_state.principal_id_for_player(player_index)
	var expected_release: bool = inspection.received_principal_ids().size() + 1 \
			== inspection.required_principal_ids().size()
	if application_result != {
		"inspection_id": payload["inspection_id"],
		"principal_id": principal_id, "released": expected_release,
	}:
		return {}
	return execute(game_state)


static func _result_valid(result: Dictionary) -> bool:
	return result.size() == 3 \
			and typeof(result.get("inspection_id")) == TYPE_STRING \
			and typeof(result.get("principal_id")) == TYPE_STRING \
			and typeof(result.get("released")) == TYPE_BOOL

## Adds one authorised human principal to the current result inspection.
class_name AcknowledgeAttackResultCommand
extends GameCommand


const TYPE: String = "acknowledge_attack_result"


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return AcknowledgeAttackResultCommand.new(player, pl))


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if payload.size() != 1 or not (payload.get("inspection_id") is String):
		return "Acknowledge result requires exactly one inspection identity."
	var inspection: CompletedAttackInspection = game_state.completed_attack_inspection
	if inspection == null:
		return "No completed attack inspection is pending."
	var inspection_id: String = str(payload.get("inspection_id", ""))
	if inspection_id.is_empty() or inspection.inspection_id() != inspection_id:
		return "Stale completed attack inspection identity."
	var principal_id: String = game_state.principal_id_for_player(player_index)
	if principal_id.is_empty() \
			or not inspection.required_principal_ids().has(principal_id):
		return "Player is not required to acknowledge this result."
	if inspection.has_received(principal_id):
		return "Result acknowledgement was already received."
	return ""


func execute(game_state: GameState) -> Dictionary:
	var principal_id: String = game_state.principal_id_for_player(player_index)
	var inspection_id: String = str(payload.get("inspection_id", ""))
	if not game_state.acknowledge_completed_attack_inspection(
				inspection_id, principal_id):
		return {}
	var updated: CompletedAttackInspection = game_state.completed_attack_inspection
	return {
		"inspection_id": inspection_id,
		"principal_id": principal_id,
		"satisfied": updated != null and updated.is_satisfied(),
	}

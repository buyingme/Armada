## Installs one authoritative terminal result after all applicable cleanup.
class_name CompleteMatchCommand
extends GameCommand

const TYPE: String = "complete_match"


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return CompleteMatchCommand.new(player, pl))


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
	if not payload.is_empty():
		return "Match completion has no caller-supplied outcome."
	if not game_state.terminal_match_result.is_empty():
		return "Match result was already installed."
	if not game_state.terminal_result_ready():
		return "Terminal cleanup or inspection remains outstanding."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var inspection: CompletedAttackInspection = \
			game_state.completed_attack_inspection
	var consumed_id: String = inspection.inspection_id() \
			if inspection != null else ""
	var result: Dictionary = game_state.expected_terminal_match_result(
			sequence)
	if result.is_empty():
		return {}
	if not consumed_id.is_empty() \
			and not game_state.consume_completed_attack_inspection(consumed_id):
		return {}
	if not game_state.install_terminal_match_result(result, sequence):
		if inspection != null:
			game_state.restore_completed_attack_inspection_for_rollback(
					inspection)
		return {}
	return {"terminal_match_result": result,
		"consumed_completed_attack_inspection_id": consumed_id}


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) if viewer_player in [0, 1] \
			and _result_is_closed(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_is_closed(application_result) \
			or not validate(game_state).is_empty():
		return {}
	var inspection: CompletedAttackInspection = \
			game_state.completed_attack_inspection
	var expected_id: String = inspection.inspection_id() \
			if inspection != null else ""
	if application_result != {
		"terminal_match_result": game_state.expected_terminal_match_result(
			sequence),
		"consumed_completed_attack_inspection_id": expected_id,
	}:
		return {}
	return execute(game_state)


static func _result_is_closed(result: Dictionary) -> bool:
	return result.size() == 2 \
			and result.get("terminal_match_result") is Dictionary \
			and typeof(result.get(
				"consumed_completed_attack_inspection_id")) == TYPE_STRING

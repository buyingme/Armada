## Test: CommandProcessor Applicability Gate
##
## Unit tests for Phase M4 command-scope enforcement before validation.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")

var _processor: Node
var _state: GameState
var _rejected_reasons: Array[String] = []


func before_each() -> void:
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)
	_state = GameState.new()
	_state.initialize()
	GameManager.current_game_state = _state
	_rejected_reasons.clear()
	_processor.command_rejected.connect(_on_rejected)


func after_each() -> void:
	GameManager.current_game_state = null


func _on_rejected(_command: GameCommand, reason: String) -> void:
	_rejected_reasons.append(reason)


func test_submit_flow_step_allowed_step_executes() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE)
	var cmd := _ScopedCommand.new("commit_displacement")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"FLOW_STEP command should execute in its declared FlowSpec step.")
	assert_eq(_processor.get_command_count(), 1,
			"Allowed command should be recorded in history.")


func test_submit_flow_step_wrong_step_rejected_before_validate() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	var cmd := _ScopedCommand.new("commit_displacement")
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Rejected FLOW_STEP command should return an empty result.")
	assert_false(cmd.validate_called,
			"Applicability should reject before command-specific validation.")
	assert_true(_rejected_reasons[0].contains(
			"command commit_displacement not allowed in step"),
			"Rejection should name the disallowed command and step.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected command should not be recorded.")
	assert_engine_error(1,
			"CommandProcessor should warn for the applicability rejection.")


func test_submit_phase_command_wrong_phase_rejected_before_validate() -> void:
	_set_phase_and_flow(Constants.GamePhase.COMMAND,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_CRITICAL_CHOICE)
	var cmd := _ScopedCommand.new("resolve_immediate_effect")
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Rejected PHASE command should return an empty result.")
	assert_false(cmd.validate_called,
			"Phase applicability should reject before command validation.")
	assert_true(_rejected_reasons[0].contains(
			"command resolve_immediate_effect not allowed in phase"),
			"Rejection should name the disallowed command and phase.")
	assert_engine_error(1,
			"CommandProcessor should warn for the phase rejection.")


func test_submit_advance_activation_step_allowed_after_attack_flow_clears() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE)
	var cmd := _ScopedCommand.new("advance_activation_step")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Ship-phase activation transitions should survive cleared attack flow.")


func test_submit_end_activation_allowed_when_flow_is_cleared() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE)
	var cmd := _ScopedCommand.new("end_activation")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"End activation should preserve the command's Ship Phase surface.")


func test_submit_move_squadron_allowed_when_flow_is_cleared() -> void:
	_set_phase_and_flow(Constants.GamePhase.SQUADRON,
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE)
	var cmd := _ScopedCommand.new("move_squadron")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Squadron movement should preserve the command's phase-based surface.")


func test_submit_activate_squadron_allowed_when_flow_is_cleared() -> void:
	_set_phase_and_flow(Constants.GamePhase.SQUADRON,
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE)
	var cmd := _ScopedCommand.new("activate_squadron")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Squadron activation should be able to start from Squadron Phase.")


func test_submit_roll_dice_allowed_from_ship_phase_legacy_flow() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN)
	var cmd := _ScopedCommand.new("roll_dice")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Attack commands prevalidated by AttackExecutor remain phase-scoped.")


func test_submit_resolve_immediate_effect_attack_flow_executes() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_CRITICAL_CHOICE)
	var cmd := _ScopedCommand.new("resolve_immediate_effect")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Attack-flow immediate effects should remain legal in Ship Phase.")


func test_submit_resolve_immediate_effect_ship_debug_followup_executes() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE)
	var cmd := _ScopedCommand.new("resolve_immediate_effect")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Debug-dealt immediate effects should remain legal in Ship Phase.")


func test_submit_resolve_immediate_effect_squadron_followup_executes() -> void:
	_set_phase_and_flow(Constants.GamePhase.SQUADRON,
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE)
	var cmd := _ScopedCommand.new("resolve_immediate_effect")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Debug-dealt immediate effects should remain legal in Squadron Phase.")


func test_submit_global_command_any_flow_executes() -> void:
	_set_phase_and_flow(Constants.GamePhase.SETUP,
			Constants.InteractionFlow.GAME_OVER,
			Constants.InteractionStep.GAME_OVER_STEP)
	var cmd := _ScopedCommand.new("debug_deal_damage")
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"GLOBAL commands should bypass flow and phase applicability gates.")


func test_submit_missing_declaration_rejected_before_validate() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP)
	var cmd := _ScopedCommand.new("_test_unscoped")
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Undeclared commands should be rejected.")
	assert_false(cmd.validate_called,
			"Missing applicability declarations should reject before validation.")
	assert_true(_rejected_reasons[0].contains(
			"no applicability declaration"),
			"Rejection should explain that the declaration is missing.")
	assert_engine_error(1,
			"CommandProcessor should warn for the missing declaration.")


func _set_phase_and_flow(phase: Constants.GamePhase,
		flow: Constants.InteractionFlow,
		step: Constants.InteractionStep) -> void:
	_state.current_phase = phase
	_state.interaction_flow = InteractionFlow.make(flow, step, -1)


class _ScopedCommand extends GameCommand:
	var validate_called: bool = false

	func _init(p_type: String,
			p_player: int = 0,
			p_payload: Dictionary = {}) -> void:
		super._init(p_player, p_type, p_payload)

	func validate(game_state: GameState) -> String:
		validate_called = true
		return super.validate(game_state)

	func execute(_game_state: GameState) -> Dictionary:
		return {"ok": true}
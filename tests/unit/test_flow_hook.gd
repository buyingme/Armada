## Test: FlowHook
##
## Unit tests for Phase M static rule hook descriptors.
extends GutTest


func test_validator_sets_command_surface() -> void:
	var hook: FlowHook = FlowHook.validator("test_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice",
			Callable(),
			20)
	assert_eq(int(hook.kind), int(FlowHook.HookKind.VALIDATOR),
			"validator() should set VALIDATOR kind.")
	assert_eq(hook.command_type, "roll_dice",
			"Validator hooks should record the command type.")
	assert_eq(hook.priority, 20,
			"Validator hooks should record priority.")


func test_modifier_sets_target_surface() -> void:
	var hook: FlowHook = FlowHook.modifier("test_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool",
			Callable())
	assert_eq(int(hook.kind), int(FlowHook.HookKind.MODIFIER),
			"modifier() should set MODIFIER kind.")
	assert_eq(hook.target, "dice_pool",
			"Modifier hooks should record the target surface.")


func test_matches_step_matching_pair_returns_true() -> void:
	var hook: FlowHook = FlowHook.observer("test_rule",
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			FlowHook.ANY,
			Callable())
	assert_true(hook.matches_step(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP),
			"Hook should match its registered FlowSpec pair.")


func test_matches_command_wildcard_accepts_any_command() -> void:
	var hook: FlowHook = FlowHook.observer("test_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			FlowHook.ANY,
			Callable())
	assert_true(hook.matches_command("roll_dice"),
			"Command wildcard should match arbitrary command types.")


func test_blocker_sets_target_surface() -> void:
	var hook: FlowHook = FlowHook.blocker("test_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			"redirect",
			Callable())
	assert_eq(int(hook.kind), int(FlowHook.HookKind.BLOCKER),
			"blocker() should set BLOCKER kind.")
	assert_eq(hook.target, "redirect",
			"Blocker hooks should record the target surface.")


func test_matches_target_wildcard_accepts_any_target() -> void:
	var hook: FlowHook = FlowHook.enabler("test_rule",
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REVEAL_DIAL,
			FlowHook.ANY,
			Callable())
	assert_true(hook.matches_target("crew_panic_choice"),
			"Target wildcard should match arbitrary target surfaces.")
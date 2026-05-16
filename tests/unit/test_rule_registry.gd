## Test: RuleRegistry
##
## Unit tests for the Phase M static rule registry scaffold.
extends GutTest


const FlowSpecScript: GDScript = preload("res://src/core/state/flow_spec.gd")


func before_each() -> void:
	RuleRegistry.clear()


func after_each() -> void:
	RuleRegistry.clear()


func test_validators_for_empty_registry_returns_empty_for_every_step() -> void:
	for pair: Dictionary in FlowSpecScript.all_pairs():
		var hooks: Array[FlowHook] = RuleRegistry.validators_for(
				int(pair["flow_id"]), int(pair["step_id"]), "any_command")
		assert_eq(hooks, [],
				"M5 empty registry should expose no validators for FlowSpec pairs.")


func test_modifiers_for_empty_registry_returns_empty_for_every_step() -> void:
	for pair: Dictionary in FlowSpecScript.all_pairs():
		var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
				int(pair["flow_id"]), int(pair["step_id"]), "dice_pool")
		assert_eq(hooks, [],
				"M5 empty registry should expose no modifiers for FlowSpec pairs.")


func test_observers_for_empty_registry_returns_empty_for_every_step() -> void:
	for pair: Dictionary in FlowSpecScript.all_pairs():
		var hooks: Array[FlowHook] = RuleRegistry.observers_for(
				int(pair["flow_id"]), int(pair["step_id"]), "roll_dice")
		assert_eq(hooks, [],
				"M5 empty registry should expose no observers for FlowSpec pairs.")


func test_blockers_for_empty_registry_returns_empty_for_every_step() -> void:
	for pair: Dictionary in FlowSpecScript.all_pairs():
		var hooks: Array[FlowHook] = RuleRegistry.blockers_for(
				int(pair["flow_id"]), int(pair["step_id"]), "redirect")
		assert_eq(hooks, [],
				"M5 empty registry should expose no blockers for FlowSpec pairs.")


func test_register_validator_returns_matching_command_only() -> void:
	var hook: FlowHook = FlowHook.validator("test_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice",
			Callable())
	RuleRegistry.register_validator(hook)
	assert_eq(RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice"), [hook],
			"Registered validators should be returned for matching commands.")
	assert_eq(RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"skip_attack"), [],
			"Registered validators should not match unrelated commands.")


func test_register_rule_uses_canonical_rule_id() -> void:
	var hook: FlowHook = FlowHook.modifier("local_id",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool",
			Callable())
	RuleRegistry.register_rule("canonical_rule", [hook])
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool")
	assert_eq(hooks[0].rule_id, "canonical_rule",
			"register_rule() should pin the canonical rule identifier.")


func test_hooks_sort_by_priority_desc_then_rule_id() -> void:
	var low: FlowHook = _validator("low_rule", 5)
	var zed: FlowHook = _validator("z_rule", 10)
	var alpha: FlowHook = _validator("a_rule", 10)
	RuleRegistry.register_validator(low)
	RuleRegistry.register_validator(zed)
	RuleRegistry.register_validator(alpha)
	assert_eq(RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice"), [alpha, zed, low],
			"Hooks should sort by priority descending, then rule_id ascending.")


func _validator(rule_id: String, priority: int) -> FlowHook:
	return FlowHook.validator(rule_id,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice",
			Callable(),
			priority)
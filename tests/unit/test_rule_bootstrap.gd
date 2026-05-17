## Test: RuleBootstrap
##
## Unit tests for the Phase M rule bootstrap autoload script.
extends GutTest


const RuleBootstrapScript: GDScript = preload("res://src/autoload/rule_bootstrap.gd")


func before_each() -> void:
	RuleRegistry.clear()


func after_each() -> void:
	RuleRegistry.clear()


func test_bootstrap_rules_registers_production_rules() -> void:
	RuleRegistry.register_validator(FlowHook.validator("stale_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice",
			Callable()))
	var bootstrap: Node = RuleBootstrapScript.new()
	var registered: int = bootstrap.bootstrap_rules()
	bootstrap.free()
	var hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			"spend_defense_token")
	var commit_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			"commit_defense")
	var ready_hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP,
			StatusPhaseCleanupCommand.TARGET_DEFENSE_TOKEN_READYING)
	var dice_hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool")
	assert_eq(registered, 3,
			"Bootstrap should invoke all three production rule scripts.")
	assert_eq(RuleRegistry.registered_hook_count(), 3,
			"Bootstrap should clear stale hooks before registering rules.")
	assert_eq(hooks.size(), 1,
			"Faulty Countermeasures should register one validator hook.")
	assert_eq(hooks[0].rule_id, FaultyCountermeasures.RULE_ID,
			"Validator should carry the Faulty Countermeasures rule id.")
	assert_eq(commit_hooks.size(), 1,
			"The same validator should cover defense commits.")
	assert_eq(ready_hooks.size(), 1,
			"Compartment Fire should register one token-readying modifier.")
	assert_eq(ready_hooks[0].rule_id, CompartmentFire.RULE_ID,
			"Modifier should carry the Compartment Fire rule id.")
	assert_eq(dice_hooks.size(), 1,
			"Damaged Munitions should register one dice-pool modifier.")
	assert_eq(dice_hooks[0].rule_id, DamagedMunitions.RULE_ID,
			"Modifier should carry the Damaged Munitions rule id.")

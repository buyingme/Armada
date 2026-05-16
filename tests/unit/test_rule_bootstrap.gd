## Test: RuleBootstrap
##
## Unit tests for the M5 rule bootstrap autoload script.
extends GutTest


const RuleBootstrapScript: GDScript = preload("res://src/autoload/rule_bootstrap.gd")


func before_each() -> void:
	RuleRegistry.clear()


func after_each() -> void:
	RuleRegistry.clear()


func test_bootstrap_rules_empty_list_clears_registry() -> void:
	RuleRegistry.register_validator(FlowHook.validator("stale_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"roll_dice",
			Callable()))
	var bootstrap: Node = RuleBootstrapScript.new()
	var registered: int = bootstrap.bootstrap_rules()
	bootstrap.free()
	assert_eq(registered, 0,
			"M5 bootstrap should not invoke any production rule scripts.")
	assert_eq(RuleRegistry.registered_hook_count(), 0,
			"M5 bootstrap should leave the static registry empty.")
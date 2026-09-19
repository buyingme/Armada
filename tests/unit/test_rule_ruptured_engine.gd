## Regression: the WP5 final consequence command supersedes the raw observer.
extends GutTest


func before_each() -> void:
	RuleRegistry.clear()


func after_each() -> void:
	RuleRegistry.clear()


func test_legacy_execute_maneuver_observer_is_retired() -> void:
	var hooks: Array[FlowHook] = RuleRegistry.observers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.COMMAND_EXECUTE_MANEUVER)
	assert_true(hooks.is_empty())
	assert_eq(RupturedEngine.EFFECT_ID, "ruptured_engine")

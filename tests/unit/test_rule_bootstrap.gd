## Test: RuleBootstrap
##
## Unit tests for the Phase M rule bootstrap autoload script.
extends GutTest


const RuleBootstrapScript: GDScript = preload("res://src/autoload/rule_bootstrap.gd")
const ECM_RULE_ID: String = "upgrade.electronic_countermeasures"


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
	var counter_roll_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			CounterKeyword.COMMAND_ROLL_DICE)
	var counter_choice_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			CounterKeyword.COMMAND_COUNTER_CHOICE)
	var crew_hooks: Array[FlowHook] = RuleRegistry.enablers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			CrewPanic.TARGET_COMMAND_DIAL_REVEAL)
	var repair_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			"repair_action")
	var engineering_hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			RuleSurface.TARGET_ENGINEERING_VALUE)
	var token_gain_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			LifeSupportFailure.COMMAND_CONVERT_DIAL_TO_TOKEN)
	var token_gain_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			RuleSurface.TARGET_COMMAND_TOKEN_GAIN)
	var target_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			RuleSurface.TARGET_ATTACK_TARGET)
	var accuracy_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			RuleSurface.TARGET_ACCURACY_SPEND)
	var critical_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_CRITICAL_EFFECT)
	var damage_modifiers: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_ATTACK_DAMAGE)
	var defense_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			RuleSurface.TARGET_DEFENSE_TOKEN_SPEND)
	var repair_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			CapacitorFailure.TARGET_REPAIR_SHIELD)
	var maneuver_yaw_hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.TARGET_MANEUVER_YAW)
	var maneuver_observers: Array[FlowHook] = RuleRegistry.observers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.COMMAND_EXECUTE_MANEUVER)
	var ecm_status_enablers: Array[FlowHook] = RuleRegistry.enablers_for(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP,
			"status_ready_upgrade_card")
	var dice_rule_ids: Array[String] = []
	for dice_hook: FlowHook in dice_hooks:
		dice_rule_ids.append(dice_hook.rule_id)
	assert_eq(registered, 23,
			"Bootstrap should invoke all twenty-three production rule scripts.")
	assert_eq(RuleRegistry.registered_hook_count(), 41,
			"Bootstrap should clear stale hooks before registering rules.")
	assert_eq(hooks.size(), 2,
			"Faulty Countermeasures and Capacitor Failure should validate spends.")
	assert_eq(commit_hooks.size(), 2,
			"Both defense-token rules should cover defense commits.")
	assert_eq(ready_hooks.size(), 1,
			"Compartment Fire should register one token-readying modifier.")
	assert_eq(ready_hooks[0].rule_id, CompartmentFire.RULE_ID,
			"Modifier should carry the Compartment Fire rule id.")
	assert_eq(dice_hooks.size(), 2,
			"Damaged Munitions and Point-Defense Failure should register modifiers.")
	assert_true(dice_rule_ids.has(DamagedMunitions.RULE_ID),
			"Dice-pool modifiers should include Damaged Munitions.")
	assert_true(dice_rule_ids.has(PointDefenseFailure.RULE_ID),
			"Dice-pool modifiers should include Point-Defense Failure.")
	assert_eq(counter_roll_hooks.size(), 1,
			"Counter should validate Counter roll dice pools.")
	assert_eq(counter_roll_hooks[0].rule_id, CounterKeyword.RULE_ID,
			"Counter roll validator should carry the Counter rule id.")
	assert_eq(counter_choice_hooks.size(), 1,
			"Counter should validate Counter choice markers.")
	assert_eq(crew_hooks.size(), 1,
			"Crew Panic should register one pre-reveal enabler.")
	assert_eq(crew_hooks[0].rule_id, CrewPanic.RULE_ID,
			"Enabler should carry the Crew Panic rule id.")
	assert_eq(repair_hooks.size(), 1,
			"Capacitor Failure should validate repair actions.")
	assert_eq(engineering_hooks.size(), 1,
			"Power Failure should register one engineering modifier.")
	assert_eq(token_gain_hooks.size(), 1,
			"Life Support Failure should validate command-token gain.")
	assert_eq(token_gain_blockers.size(), 1,
			"Life Support Failure should expose token-gain blocker metadata.")
	assert_eq(target_blockers.size(), 4,
			"Three damage cards plus Escort should expose blockers.")
	assert_eq(accuracy_blockers.size(), 1,
			"Blinded Gunners should expose accuracy-spend blocker metadata.")
	assert_eq(critical_blockers.size(), 2,
			"Targeter Disruption and Bomber should expose critical blockers.")
	assert_eq(damage_modifiers.size(), 1,
			"Bomber should expose attack-damage modifier metadata.")
	assert_eq(defense_blockers.size(), 2,
			"Faulty Countermeasures and Capacitor Failure should expose blockers.")
	assert_eq(repair_blockers.size(), 1,
			"Capacitor Failure should expose one repair-shield blocker.")
	assert_eq(maneuver_yaw_hooks.size(), 1,
			"Thrust Control Malfunction should expose one yaw modifier.")
	assert_eq(maneuver_observers.size(), 3,
			"Three movement damage cards should observe execute_maneuver.")
	assert_eq(ecm_status_enablers.size(), 1,
			"Electronic Countermeasures should expose one status ready-cost enabler.")
	assert_eq(ecm_status_enablers[0].rule_id, ECM_RULE_ID,
			"ECM status ready-cost enabler should carry the ECM rule id.")

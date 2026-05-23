## RuleBootstrap
##
## Autoload that initializes the static Phase M RuleRegistry catalogue.
## Production rule scripts register static command-time hooks while legacy
## EffectRegistry behaviour remains available during the Phase M migration.
extends Node


const RULE_SCRIPTS: Array[GDScript] = [
	preload("res://src/core/effects/rules/damage_cards/ship/blinded_gunners.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/capacitor_failure.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/compartment_fire.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/coolant_discharge.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/crew_panic.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/damaged_controls.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/damaged_munitions.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/depowered_armament.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/disengaged_fire_control.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/faulty_countermeasures.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/life_support_failure.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/point_defense_failure.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/power_failure.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/ruptured_engine.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/targeter_disruption.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/thrust_control_malfunction.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/thruster_fissure.gd"),
	preload("res://src/core/effects/rules/squadron_keywords/heavy.gd"),
	preload("res://src/core/effects/rules/squadron_keywords/escort.gd"),
	preload("res://src/core/effects/rules/squadron_keywords/counter.gd"),
	preload("res://src/core/effects/rules/squadron_keywords/swarm.gd"),
	preload("res://src/core/effects/rules/squadron_keywords/bomber.gd"),
]

var _log: GameLogger = GameLogger.new("RuleBootstrap")


func _ready() -> void:
	bootstrap_rules()


## Clears and re-registers every static rule definition script.
## Returns the number of rule scripts invoked.
func bootstrap_rules() -> int:
	RuleRegistry.clear()
	var registered: int = 0
	for rule_script: GDScript in RULE_SCRIPTS:
		if rule_script == null:
			continue
		rule_script.call("register")
		registered += 1
	_log.info("Registered %d rule definition scripts." % registered)
	return registered

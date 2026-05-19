## RuleBootstrap
##
## Autoload that initializes the static Phase M RuleRegistry catalogue.
## Production rule scripts register static command-time hooks while legacy
## EffectRegistry behaviour remains available during the Phase M migration.
extends Node


const RULE_SCRIPTS: Array[GDScript] = [
	preload("res://src/core/effects/rules/damage_cards/ship/capacitor_failure.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/compartment_fire.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/crew_panic.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/damaged_munitions.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/faulty_countermeasures.gd"),
	preload("res://src/core/effects/rules/damage_cards/ship/point_defense_failure.gd"),
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

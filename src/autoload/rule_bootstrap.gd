## RuleBootstrap
##
## Autoload that initializes the static Phase M RuleRegistry catalogue.
## M5 keeps [constant RULE_SCRIPTS] empty so the registry has no production
## hooks and legacy EffectRegistry behaviour remains unchanged.
extends Node


const RULE_SCRIPTS: Array[GDScript] = []

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

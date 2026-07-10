## ReadyECMCommand
##
## Replayable CAP-ECM-001 command for the Status Phase ECM Repair-token ready
## cost. It spends one Repair token from the source ship and readies the source
## ECM runtime upgrade instance.
class_name ReadyECMCommand
extends GameCommand


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const SCRIPT_PATH: String = "res://src/core/commands/ready_ecm_command.gd"


static func register() -> void:
	GameCommand.register_type("ready_ecm", func(player: int,
			pl: Dictionary) -> GameCommand:
		return load(SCRIPT_PATH).new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "ready_ecm", p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	return ECM_SCRIPT.validate_status_ready_cost(
			game_state, player_index, _runtime_upgrade_id())


func execute(game_state: GameState) -> Dictionary:
	return ECM_SCRIPT.ready_status_cost(game_state, _runtime_upgrade_id())


func _runtime_upgrade_id() -> String:
	return str(payload.get("runtime_upgrade_id", ""))

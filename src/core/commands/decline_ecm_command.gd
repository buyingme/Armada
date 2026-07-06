## DeclineECMCommand
##
## Replayable CAP-ECM-001 command that records an explicit public decline
## of the ECM opportunity for the current attack window.
class_name DeclineECMCommand
extends GameCommand


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const SCRIPT_PATH: String = "res://src/core/commands/decline_ecm_command.gd"


static func register() -> void:
	GameCommand.register_type("decline_ecm", func(player: int,
			pl: Dictionary) -> GameCommand:
		return load(SCRIPT_PATH).new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "decline_ecm", p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	return ECM_SCRIPT.validate_decline(
			game_state, player_index, _runtime_upgrade_id())


func execute(game_state: GameState) -> Dictionary:
	var source: Dictionary = ECM_SCRIPT.find_defender_source(
			game_state, game_state.interaction_flow)
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var decline_scope: Dictionary = ECM_SCRIPT.decline_ecm(
			game_state, runtime_upgrade)
	return {
		"runtime_upgrade_id": _runtime_upgrade_id(),
		"defender_player": player_index,
		"defender_ship_index": int(source.get("ship_index", -1)),
		"declined": true,
		"decline_scope": decline_scope,
	}


func _runtime_upgrade_id() -> String:
	return str(payload.get("runtime_upgrade_id", ""))

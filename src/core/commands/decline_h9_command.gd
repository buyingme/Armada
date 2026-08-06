## Declines one H9 Turbolasers opportunity for the current attack.
class_name DeclineH9Command
extends GameCommand


const TYPE: String = "decline_h9"
const SCRIPT_PATH: String = "res://src/core/commands/decline_h9_command.gd"
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		var command_script: GDScript = load(SCRIPT_PATH) as GDScript
		return command_script.new(player, pl))


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	return H9_RULE.validate_resolution_context(
			game_state, player_index, payload)


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var runtime_upgrade_id: String = str(payload.get(
			H9_RULE.PAYLOAD_RUNTIME_UPGRADE_ID, ""))
	var source: Dictionary = H9_RULE.pending_source(
			game_state, game_state.timing_window_state, runtime_upgrade_id)
	if source.is_empty():
		return {}
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {}) \
			as Dictionary
	if not H9_RULE.write_resolution_guard(
			runtime_upgrade, attack.attack_id, H9_RULE.RESOLUTION_DECLINED):
		return {}
	return {
		"attack_id": attack.attack_id,
		"runtime_upgrade_id": runtime_upgrade_id,
		"semantic_key": H9_RULE.SEMANTIC_KEY,
		"resolution": H9_RULE.RESOLUTION_DECLINED,
	}

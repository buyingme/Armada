## Resolves one H9 Turbolasers die-change opportunity.
class_name UseH9Command
extends GameCommand


const TYPE: String = "use_h9"
const SCRIPT_PATH: String = "res://src/core/commands/use_h9_command.gd"
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
	var context_reason: String = H9_RULE.validate_resolution_context(
			game_state, player_index, payload)
	if not context_reason.is_empty():
		return context_reason
	if typeof(payload.get("die_index")) != TYPE_INT:
		return "Invalid H9 die index."
	var attack: CurrentAttackState = game_state.current_attack_state
	var dice_results: Array[Dictionary] = attack.dice_results
	var die_index: int = int(payload.get("die_index", -1))
	if die_index < 0 or die_index >= dice_results.size():
		return "Invalid H9 die index."
	var selected: Dictionary = dice_results[die_index]
	if typeof(payload.get("expected_color")) != TYPE_INT \
			or int(payload.get("expected_color")) \
					!= int(selected.get("color", -1)) \
			or typeof(payload.get("expected_face")) != TYPE_INT \
			or int(payload.get("expected_face")) \
					!= int(selected.get("face", -1)):
		return "Stale H9 die selection."
	if typeof(payload.get(H9_RULE.PAYLOAD_TARGET_FACE)) != TYPE_INT:
		return "Invalid H9 target face."
	return H9_RULE.selected_die_reason(
			selected, int(payload.get(H9_RULE.PAYLOAD_TARGET_FACE, -1)))


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var timing: TimingWindowState = game_state.timing_window_state
	var runtime_upgrade_id: String = str(payload.get(
			H9_RULE.PAYLOAD_RUNTIME_UPGRADE_ID, ""))
	var source: Dictionary = H9_RULE.pending_source(
			game_state, timing, runtime_upgrade_id)
	if source.is_empty():
		return {}
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {}) \
			as Dictionary
	var previous_rule_state: Dictionary = (runtime_upgrade.get(
			"rule_state", {}) as Dictionary).duplicate(true)
	var dice_results: Array[Dictionary] = attack.dice_results
	var die_index: int = int(payload.get("die_index", -1))
	var old_result: Dictionary = dice_results[die_index].duplicate(true)
	var new_result: Dictionary = {
		"color": int(old_result.get("color", -1)),
		"face": int(Constants.DiceFace.ACCURACY),
	}
	dice_results[die_index] = new_result
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_results": dice_results,
	})
	if replacement == null \
			or not H9_RULE.write_resolution_guard(
				runtime_upgrade, attack.attack_id, H9_RULE.RESOLUTION_USED):
		return {}
	if not game_state.set_current_attack_state(replacement):
		runtime_upgrade["rule_state"] = previous_rule_state
		return {}
	return {
		"attack_id": attack.attack_id,
		"runtime_upgrade_id": runtime_upgrade_id,
		"semantic_key": H9_RULE.SEMANTIC_KEY,
		"resolution": H9_RULE.RESOLUTION_USED,
		"die_index": die_index,
		"old_result": old_result,
		"new_result": new_result,
		"dice_results": dice_results,
	}

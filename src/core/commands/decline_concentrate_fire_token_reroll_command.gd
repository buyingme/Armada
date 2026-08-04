## Declines the shared Concentrate Fire token reroll opportunity.
class_name DeclineConcentrateFireTokenRerollCommand
extends GameCommand


const TYPE: String = "decline_concentrate_fire_token_reroll"
const SCRIPT_PATH: String = \
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd"
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")


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
	return CF_RULE.validate_resolution_context(
			game_state, player_index, payload)


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var replacement: CurrentAttackState = attack.with_patch({
		"cf_token_resolution": CurrentAttackState.RESOLUTION_DECLINED,
	})
	if replacement == null \
			or not game_state.set_current_attack_state(replacement):
		return {}
	return {
		"attack_id": attack.attack_id,
		"attacking_ship_id": str(payload.get("attacking_ship_id", "")),
		"runtime_source_id": str(payload.get("runtime_source_id", "")),
		"semantic_key": CF_RULE.SEMANTIC_KEY,
		"resolution": CurrentAttackState.RESOLUTION_DECLINED,
	}

## Resolves the shared Concentrate Fire token reroll opportunity.
class_name UseConcentrateFireTokenRerollCommand
extends GameCommand


const TYPE: String = "use_concentrate_fire_token_reroll"
const SCRIPT_PATH: String = \
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd"
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
	var context_reason: String = CF_RULE \
			.validate_resolution_context(game_state, player_index, payload)
	if not context_reason.is_empty():
		return context_reason
	var attack: CurrentAttackState = game_state.current_attack_state
	var dice_results: Array[Dictionary] = attack.dice_results
	if typeof(payload.get("die_index")) != TYPE_INT:
		return "Invalid Concentrate Fire die index."
	var die_index: int = int(payload.get("die_index", -1))
	if die_index < 0 or die_index >= dice_results.size():
		return "Invalid Concentrate Fire die index."
	var selected: Dictionary = dice_results[die_index]
	if typeof(payload.get("expected_color")) != TYPE_INT \
			or int(payload.get("expected_color")) \
					!= int(selected.get("color", -1)) \
			or typeof(payload.get("expected_face")) != TYPE_INT \
			or int(payload.get("expected_face")) \
					!= int(selected.get("face", -1)):
		return "Stale Concentrate Fire die selection."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	var dice_results: Array[Dictionary] = attack.dice_results
	var die_index: int = int(payload.get("die_index", -1))
	var old_result: Dictionary = dice_results[die_index].duplicate(true)
	var color: Constants.DiceColor = int(old_result.get("color", -1)) \
			as Constants.DiceColor
	var rng_state: int = game_state.rng.get_state()
	var new_result: Dictionary = {
		"color": int(color),
		"face": int(Dice.roll_die(color, game_state.rng)),
	}
	dice_results[die_index] = new_result
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_results": dice_results,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_USED,
	})
	if replacement == null \
			or not game_state.set_current_attack_state(replacement):
		game_state.rng.set_state(rng_state)
		return {}
	if ship == null or ship.command_tokens == null \
			or not ship.command_tokens.spend_token(
				Constants.CommandType.CONCENTRATE_FIRE):
		game_state.set_current_attack_state(attack)
		game_state.rng.set_state(rng_state)
		return {}
	return {
		"attack_id": attack.attack_id,
		"attacking_ship_id": str(payload.get("attacking_ship_id", "")),
		"runtime_source_id": str(payload.get("runtime_source_id", "")),
		"semantic_key": CF_RULE.SEMANTIC_KEY,
		"resolution": CurrentAttackState.RESOLUTION_USED,
		"die_index": die_index,
		"old_result": old_result,
		"new_result": new_result,
		"dice_results": dice_results,
	}

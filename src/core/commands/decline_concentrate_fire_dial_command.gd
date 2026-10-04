## Records the current attacker's explicit Concentrate Fire dial decline.
class_name DeclineConcentrateFireDialCommand
extends GameCommand

const TYPE: String = "decline_concentrate_fire_dial"

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return DeclineConcentrateFireDialCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	return UseConcentrateFireDialCommand.validate_context(
			game_state, player_index, payload)

func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var replacement: CurrentAttackState = attack.with_patch({
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_DECLINED,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	return {"attack_id": attack.attack_id, "declined": true}

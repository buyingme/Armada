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
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_PRE_ROLL \
			or attack.cf_dial_resolution != CurrentAttackState.RESOLUTION_PENDING:
		return "Concentrate Fire dial is not pending."
	if attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or player_index != attack.attacker_player:
		return "Concentrate Fire dial belongs to the attacking ship."
	return ""

func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var replacement: CurrentAttackState = attack.with_patch({
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_DECLINED,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	return {"attack_id": attack.attack_id, "declined": true}

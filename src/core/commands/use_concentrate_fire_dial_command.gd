## Atomically spends the current attacker's Concentrate Fire dial and adds a die.
class_name UseConcentrateFireDialCommand
extends GameCommand

const TYPE: String = "use_concentrate_fire_dial"

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return UseConcentrateFireDialCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	var reason: String = _validate_attack(attack)
	if reason != "":
		return reason
	var color: String = str(payload.get("color", "")).to_upper()
	if int(attack.dice_pool.get(color, 0)) <= 0:
		return "Concentrate Fire die color is not in the pool."
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if ship == null or ship.command_dial_stack == null:
		return "Attacking ship has no command dial stack."
	var dial: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if dial.is_empty() or int(dial.get("command", -1)) \
			!= int(Constants.CommandType.CONCENTRATE_FIRE):
		return "No Concentrate Fire dial is available."
	return ""

func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var color: String = str(payload.get("color", "")).to_upper()
	var pool: Dictionary = attack.dice_pool
	pool[color] = int(pool.get(color, 0)) + 1
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_pool": pool,
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_USED,
	})
	if replacement == null:
		return {}
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if not game_state.set_current_attack_state(replacement):
		return {}
	if ship.command_dial_stack.spend_revealed().is_empty():
		game_state.set_current_attack_state(attack)
		return {}
	return {"attack_id": attack.attack_id, "color": color, "dice_pool": pool}

func _validate_attack(attack: CurrentAttackState) -> String:
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

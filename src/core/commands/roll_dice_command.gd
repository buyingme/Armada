## RollDiceCommand
##
## Rolls attack dice during the Ship Phase attack sequence.
## Uses [member GameState.rng] for deterministic replay support.
##
## Payload:
##   "dice_pool" — Dictionary mapping colour string ("red"/"blue"/"black")
##                 to count, e.g. {"red": 2, "blue": 1}.
## Optional attack identity metadata:
##   "attacker_kind", "attacker_player", "attacker_ship_index",
##   "target_kind" — records ship-target attacks for damage rules.
##
## Rules Reference: "Attack", Step 2, p.2 — "Roll Attack Dice".
class_name RollDiceCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("roll_dice", func(player: int,
			pl: Dictionary) -> GameCommand:
		return RollDiceCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "roll_dice", p_payload)


## Validates that rolling dice is legal.
## Attack-step-specific validation is handled by [AttackExecutor] before
## submitting; this only checks GameState-level preconditions.
## Allowed in both Ship and Squadron phases (squadron attacks roll dice too).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var pool: Dictionary = payload.get("dice_pool", {})
	if pool.is_empty():
		return "Dice pool is empty."
	return ""


## Rolls the dice pool deterministically via [member GameState.rng].
## Returns {"dice_results": Array[Dictionary]} where each entry is
## {"color": DiceColor, "face": DiceFace}.
func execute(game_state: GameState) -> Dictionary:
	var raw_pool: Dictionary = payload.get("dice_pool", {})
	# Normalise keys to uppercase for DicePool.to_engine_pool().
	var upper_pool: Dictionary = {}
	for key: String in raw_pool:
		upper_pool[key.to_upper()] = raw_pool[key]
	var engine_pool: Dictionary = DicePool.to_engine_pool(upper_pool)
	var results: Array[Dictionary] = Dice.roll_pool(
			engine_pool, game_state.rng)
	_record_ship_target_attack(game_state)
	return {"dice_results": results}


func _record_ship_target_attack(game_state: GameState) -> void:
	if game_state == null:
		return
	if str(payload.get("attacker_kind", "")) != "ship":
		return
	if str(payload.get("target_kind", "")) != "ship":
		return
	var owner: int = int(payload.get("attacker_player", player_index))
	var ship_index: int = int(payload.get("attacker_ship_index", -1))
	var attacker: ShipInstance = game_state.get_ship(owner, ship_index)
	game_state.record_ship_target_attack(attacker)

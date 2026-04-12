## RollDiceCommand
##
## Rolls attack dice during the Ship Phase attack sequence.
## Uses [member GameState.rng] for deterministic replay support.
##
## Payload:
##   "dice_pool" — Dictionary mapping colour string ("red"/"blue"/"black")
##                 to count, e.g. {"red": 2, "blue": 1}.
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
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
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
	return {"dice_results": results}

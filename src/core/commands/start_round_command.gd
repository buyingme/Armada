## StartRoundCommand
##
## Starts a new round by incrementing [member GameState.current_round]
## and resetting [member GameState.current_phase] to COMMAND.
##
## This is the only command that transitions from STATUS to COMMAND.
## The presentation layer is responsible for emitting EventBus signals
## and setting up the dial-assignment flow after the command executes.
##
## Payload:  (none required)
##
## Rules Reference: "Game Round", GF-002, GF-003 — six rounds,
## strict phase order; "Command Phase", p.3.
class_name StartRoundCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("start_round", func(player: int,
			pl: Dictionary) -> GameCommand:
		return StartRoundCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "start_round", p_payload)


## Validates that starting a new round is legal.
## Must be in SETUP (initial game start) or STATUS phase, and the next
## round must not exceed MAX_ROUNDS.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.STATUS and phase != Constants.GamePhase.SETUP:
		return "Can only start a new round from STATUS or SETUP phase."
	if game_state.current_round >= Constants.MAX_ROUNDS:
		return "Already at maximum rounds (%d)." % Constants.MAX_ROUNDS
	return ""


## Increments round counter and resets phase to COMMAND.
## Returns {"new_round": int, "new_phase": int}.
func execute(game_state: GameState) -> Dictionary:
	game_state.current_round += 1
	game_state.current_phase = Constants.GamePhase.COMMAND
	return {
		"new_round": game_state.current_round,
		"new_phase": int(Constants.GamePhase.COMMAND),
	}

## Game Manager
##
## Central game manager responsible for orchestrating the overall game flow.
## Manages game state, round progression, and phase transitions.
## This is the top-level controller for the Armada game.
extends Node


## The current game state. Null when no game is active.
var current_game_state: GameState = null

## Whether a game is currently in progress.
var is_game_active: bool = false


## Starts a new game with the given configuration.
func start_new_game(_config: Dictionary = {}) -> void:
	current_game_state = GameState.new()
	current_game_state.initialize()
	is_game_active = true
	EventBus.game_started.emit()
	_start_round()


## Ends the current game.
func end_game(winner_index: int = -1) -> void:
	is_game_active = false
	EventBus.game_ended.emit(winner_index)


## Returns the current round number.
func get_current_round() -> int:
	if current_game_state:
		return current_game_state.current_round
	return 0


## Returns the current game phase.
func get_current_phase() -> Constants.GamePhase:
	if current_game_state:
		return current_game_state.current_phase
	return Constants.GamePhase.SETUP


## Advances to the next phase in the current round.
func advance_phase() -> void:
	if not is_game_active or not current_game_state:
		return

	var next_phase := _get_next_phase(current_game_state.current_phase)

	if next_phase == Constants.GamePhase.COMMAND:
		# We've wrapped around — start a new round
		_end_round()
		if is_game_active:
			_start_round()
	else:
		current_game_state.current_phase = next_phase
		EventBus.phase_changed.emit(next_phase)


## Starts a new round.
func _start_round() -> void:
	current_game_state.current_round += 1

	if current_game_state.current_round > Constants.MAX_ROUNDS:
		end_game()
		return

	current_game_state.current_phase = Constants.GamePhase.COMMAND
	EventBus.round_started.emit(current_game_state.current_round)
	EventBus.phase_changed.emit(Constants.GamePhase.COMMAND)


## Ends the current round.
func _end_round() -> void:
	EventBus.round_ended.emit(current_game_state.current_round)


## Returns the next phase after the given phase.
func _get_next_phase(current: Constants.GamePhase) -> Constants.GamePhase:
	match current:
		Constants.GamePhase.COMMAND:
			return Constants.GamePhase.SHIP
		Constants.GamePhase.SHIP:
			return Constants.GamePhase.SQUADRON
		Constants.GamePhase.SQUADRON:
			return Constants.GamePhase.STATUS
		Constants.GamePhase.STATUS:
			return Constants.GamePhase.COMMAND
		_:
			return Constants.GamePhase.COMMAND

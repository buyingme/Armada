## Game Manager
##
## Central game manager responsible for orchestrating the overall game flow.
## Manages game state, round progression, and phase transitions.
## This is the top-level controller for the Armada game.
##
## During the Command Phase, tracks per-player dial submission via the
## "both submitted" gate: once both players have submitted their dials
## the phase automatically advances to the Ship Phase.
## Rules Reference: "Command Phase", p.3.
extends Node


## The current game state. Null when no game is active.
var current_game_state: GameState = null

var _log: GameLogger = GameLogger.new("GameManager")

## Whether a game is currently in progress.
var is_game_active: bool = false

## Tracks which players have submitted command dials this round.
## Indexed by player index (0 and 1). Reset at the start of each round.
var _command_submitted: Array[bool] = [false, false]


func _ready() -> void:
	EventBus.command_dials_submitted.connect(_on_command_dials_submitted)
	EventBus.command_picker_confirmed.connect(_on_command_picker_confirmed)


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

	# Reset submission tracking for the new round.
	_command_submitted = [false, false]

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


## Called when a player explicitly signals that their dials are submitted.
## [param player_index] — 0 or 1.
## Rules Reference: "Command Phase", p.3 — both players must assign dials
## before the phase ends.
func _on_command_dials_submitted(player_index: int) -> void:
	if not is_game_active or not current_game_state:
		return
	if current_game_state.current_phase != Constants.GamePhase.COMMAND:
		return
	if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
		return

	_command_submitted[player_index] = true
	_check_command_phase_complete()


## Called when the picker confirms dials for a specific ship.
## Assigns the selected commands into that ship's dial stack and checks
## whether all ships for the owning player have been assigned.
func _on_command_picker_confirmed(ship: ShipInstance,
		commands: Array) -> void:
	if not is_game_active or not current_game_state:
		return
	if ship.command_dial_stack == null:
		return

	# Convert plain Array to typed Array[int].
	var typed_commands: Array[int] = []
	for cmd: Variant in commands:
		typed_commands.append(cmd as int)

	var result: bool = ship.command_dial_stack.assign_dials(
			typed_commands, current_game_state.current_round)
	if not result:
		_log.warn("assign_dials failed for '%s'" % [
				ship.ship_data.ship_name if ship.ship_data else "?"])
	EventBus.command_dials_changed.emit(ship)

	# Auto-check whether all ships for this player are done.
	var player_index: int = ship.owner_player
	if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
		return

	var ps: PlayerState = current_game_state.get_player_state(player_index)
	if ps == null:
		return

	var all_assigned: bool = true
	for s: Variant in ps.ships:
		if s is ShipInstance:
			var si: ShipInstance = s as ShipInstance
			if si.command_dial_stack == null:
				continue
			var needed: int = si.command_dial_stack.get_dials_needed(
					current_game_state.current_round)
			var hidden_count: int = si.command_dial_stack.get_hidden_count()
			if hidden_count < needed:
				all_assigned = false
				break

	if all_assigned:
		_command_submitted[player_index] = true
		EventBus.command_dials_submitted.emit(player_index)
		_check_command_phase_complete()


## Checks whether both players have submitted and, if so, ends the Command
## Phase and advances to Ship Phase.
func _check_command_phase_complete() -> void:
	for i: int in range(Constants.PLAYER_COUNT):
		if not _command_submitted[i]:
			return

	EventBus.command_phase_complete.emit()
	advance_phase()

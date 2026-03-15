## Game Manager
##
## Central game manager responsible for orchestrating the overall game flow.
## Manages game state, round progression, phase transitions, and active
## player turn tracking.
##
## During the Command Phase, tracks per-player dial submission via the
## "both submitted" gate: once both players have submitted their dials
## the phase automatically advances to the Ship Phase.
##
## During Ship and Squadron Phases, tracks alternating activations between
## the initiative player and the second player, with automatic pass
## detection when a player has no remaining unactivated units.
##
## Rules Reference: "Command Phase", p.3; SP-001–004; SQ-001–005.
## Requirements: TF-001–014, PM-001–004, IN-001–003.
extends Node


## The current game state. Null when no game is active.
var current_game_state: GameState = null

var _log: GameLogger = GameLogger.new("GameManager")

## Whether a game is currently in progress.
var is_game_active: bool = false

## Tracks which players have submitted command dials this round.
## Indexed by player index (0 and 1). Reset at the start of each round.
var _command_submitted: Array[bool] = [false, false]

## The player index that currently has UI control.
## Requirements: TF-001 — only the active player can interact.
var active_player: int = 0

## The player currently assigning dials in hot-seat command phase.
## -1 means no player is assigning (phase not active or both done).
var _command_assigning_player: int = -1


func _ready() -> void:
	EventBus.command_dials_submitted.connect(_on_command_dials_submitted)
	EventBus.command_picker_confirmed.connect(_on_command_picker_confirmed)
	EventBus.activation_ended.connect(_on_activation_ended)
	EventBus.handoff_accepted.connect(_on_handoff_accepted)


## Starts a new game with the given configuration.
func start_new_game(_config: Dictionary = {}) -> void:
	current_game_state = GameState.new()
	current_game_state.initialize()
	is_game_active = true
	active_player = current_game_state.initiative_player
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
## Calls phase-specific begin methods for Ship and Squadron phases.
## Requirements: GF-002 — strict phase order.
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
		# Initialise per-phase state.
		match next_phase:
			Constants.GamePhase.SHIP:
				_begin_ship_phase()
			Constants.GamePhase.SQUADRON:
				_begin_squadron_phase()


## Starts a new round.
## Requirements: TF-002 — initiative player assigns dials first in hot-seat.
func _start_round() -> void:
	current_game_state.current_round += 1

	if current_game_state.current_round > Constants.MAX_ROUNDS:
		end_game()
		return

	# Reset submission tracking for the new round.
	_command_submitted = [false, false]

	current_game_state.current_phase = Constants.GamePhase.COMMAND

	# In hot-seat, initiative player assigns dials first.
	# Requirements: TF-002, BP-006.
	var init_player: int = current_game_state.initiative_player
	_command_assigning_player = init_player
	_set_active_player(init_player)

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
## In hot-seat mode, triggers handoff to the second player if the first
## player just finished. In network mode, checks if both are done.
## Rules Reference: "Command Phase", p.3 — both players must assign dials
## before the phase ends.
## Requirements: TF-002, HO-003.
func _on_command_dials_submitted(player_index: int) -> void:
	if not is_game_active or not current_game_state:
		return
	if current_game_state.current_phase != Constants.GamePhase.COMMAND:
		return
	if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
		return

	_command_submitted[player_index] = true

	if PlayMode.is_hot_seat():
		# In hot-seat: if the initiative player just finished, hand off
		# to the second player. If the second player finished, advance.
		if _command_assigning_player == player_index:
			var next_player: int = 1 - player_index
			if not _command_submitted[next_player]:
				_command_assigning_player = next_player
				_set_active_player(next_player)
				return

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
		# NOTE: Do NOT call _check_command_phase_complete() here.
		# The emit above synchronously triggers _on_command_dials_submitted,
		# which already calls _check_command_phase_complete(). Calling it
		# again would double-advance the phase (Command → Ship → Squadron).


## Checks whether both players have submitted and, if so, ends the Command
## Phase and advances to Ship Phase.
func _check_command_phase_complete() -> void:
	if not is_game_active or not current_game_state:
		return
	if current_game_state.current_phase != Constants.GamePhase.COMMAND:
		return
	for i: int in range(Constants.PLAYER_COUNT):
		if not _command_submitted[i]:
			return

	_command_assigning_player = -1
	EventBus.command_phase_complete.emit()
	advance_phase()


# ---------------------------------------------------------------------------
# Active player management
# ---------------------------------------------------------------------------

## Sets the active player and emits the signal.
## Requirements: TF-001 — only the active player can interact.
func _set_active_player(player_index: int) -> void:
	if player_index == active_player:
		# Still emit so listeners always get the notification.
		EventBus.active_player_changed.emit(player_index)
		return
	active_player = player_index
	_log.info("Active player changed to %d." % player_index)
	EventBus.active_player_changed.emit(player_index)


## Returns the player index who currently has UI control.
## Requirements: TF-001.
func get_active_player() -> int:
	return active_player


## Returns the player who is currently assigning command dials, or -1.
func get_command_assigning_player() -> int:
	return _command_assigning_player


# ---------------------------------------------------------------------------
# Ship Phase turn management
# ---------------------------------------------------------------------------

## Called when the active player presses "End Activation" (Ship or Squadron).
## Requirements: TF-005, TF-011.
func _on_activation_ended() -> void:
	if not is_game_active or not current_game_state:
		return

	match current_game_state.current_phase:
		Constants.GamePhase.SHIP:
			_advance_ship_phase_turn()
		Constants.GamePhase.SQUADRON:
			_advance_squadron_phase_turn()


## Advances to the next player's turn in the Ship Phase.
## Auto-passes for players with no unactivated ships.
## Requirements: TF-003, TF-006, TF-007.
func _advance_ship_phase_turn() -> void:
	var next: int = 1 - active_player
	var next_has: bool = _has_unactivated_ships(next)
	var curr_has: bool = _has_unactivated_ships(active_player)

	if not next_has and not curr_has:
		# Both done — advance to Squadron Phase.
		advance_phase()
		return

	if next_has:
		if not curr_has:
			_log.info("auto_pass(player=%d, phase=Ship) — no unactivated ships" % active_player)
		_set_active_player(next)
	elif curr_has:
		# Opponent has no ships; current player continues.
		# Requirements: TF-006 — auto-pass.
		_log.info("auto_pass(player=%d, phase=Ship) — no unactivated ships" % next)
		_set_active_player(active_player)
	else:
		advance_phase()


## Advances to the next player's turn in the Squadron Phase.
## Auto-passes for players with no unactivated squadrons.
## Requirements: TF-008, TF-009, TF-012.
func _advance_squadron_phase_turn() -> void:
	var next: int = 1 - active_player
	var next_has: bool = _has_unactivated_squadrons(next)
	var curr_has: bool = _has_unactivated_squadrons(active_player)

	if not next_has and not curr_has:
		advance_phase()
		return

	if next_has:
		if not curr_has:
			_log.info("auto_pass(player=%d, phase=Squadron) — no unactivated squadrons" % active_player)
		_set_active_player(next)
	elif curr_has:
		_log.info("auto_pass(player=%d, phase=Squadron) — no unactivated squadrons" % next)
		_set_active_player(active_player)
	else:
		advance_phase()


## Returns true if the given player has at least one unactivated ship.
## Requirements: TF-006 — auto-pass detection.
func _has_unactivated_ships(player_index: int) -> bool:
	if not current_game_state:
		return false
	var ps: PlayerState = current_game_state.get_player_state(player_index)
	if ps == null:
		return false
	for s: Variant in ps.ships:
		if s is ShipInstance:
			var si: ShipInstance = s as ShipInstance
			if not si.activated_this_round:
				return true
	return false


## Returns true if the given player has at least one unactivated squadron.
## Requirements: TF-009 — auto-pass detection.
func _has_unactivated_squadrons(player_index: int) -> bool:
	if not current_game_state:
		return false
	var ps: PlayerState = current_game_state.get_player_state(player_index)
	if ps == null:
		return false
	for sq: Variant in ps.squadrons:
		if sq is SquadronInstance:
			var sqi: SquadronInstance = sq as SquadronInstance
			if not sqi.activated_this_round:
				return true
	return false


## Called when a handoff overlay or banner is dismissed.
## Requirements: HO-002, HO-004.
func _on_handoff_accepted() -> void:
	# Currently a no-op in GameManager — the game board handles
	# starting the appropriate flow (command pickers, ship selection, etc.)
	# when the active player changes. This signal acts as a gate so
	# the board knows the player is ready.
	pass


## Begins the Ship Phase by setting the initiative player as active.
## Requirements: TF-003, SP-001 — initiative player activates first.
func _begin_ship_phase() -> void:
	if not current_game_state:
		return
	var init_player: int = current_game_state.initiative_player
	_set_active_player(init_player)


## Begins the Squadron Phase by setting the initiative player as active.
## Requirements: TF-008, SQ-003 — initiative player activates first.
func _begin_squadron_phase() -> void:
	if not current_game_state:
		return
	var init_player: int = current_game_state.initiative_player
	_set_active_player(init_player)

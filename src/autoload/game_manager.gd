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

## The ship currently being activated during Ship Phase.
## Set when a command dial is dropped on a ship; cleared on End Activation.
## Requirements: UI-024, UI-026.
var _activating_ship: ShipInstance = null

## Whether fixed round-1 commands were applied this game.
## Set by [method apply_fixed_round1_commands]; reset on [method start_new_game].
## Used by the game board to show a brief toast notification.
## Requirements: CP-009, CP-010.
var fixed_commands_applied: bool = false


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
	_activating_ship = null
	fixed_commands_applied = false
	EventBus.game_started.emit()
	_start_round()


## Ends the current game.
func end_game(winner_index: int = -1) -> void:
	is_game_active = false
	EventBus.game_ended.emit(winner_index)


## Applies pre-assigned (fixed) command dials to all ships for round 1,
## then immediately skips the command phase.
## [param commands] — Dictionary mapping ship data_key → Array[int] of
##     Constants.CommandType values (first element = top of stack).
## Must be called while the game is in round 1 / COMMAND phase and after
## ship instances have been registered in the game state.
## Rules Reference: LTP p.10 — "suggested commands"; CP-009, CP-010.
func apply_fixed_round1_commands(commands: Dictionary) -> void:
	if not is_game_active or not current_game_state:
		_log.warn("apply_fixed_round1_commands: no active game.")
		return
	if current_game_state.current_round != 1:
		_log.warn("apply_fixed_round1_commands: only valid in round 1.")
		return
	if current_game_state.current_phase != Constants.GamePhase.COMMAND:
		_log.warn("apply_fixed_round1_commands: not in COMMAND phase.")
		return

	var assigned_count: int = 0
	for player_idx: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = current_game_state.get_player_state(player_idx)
		if ps == null:
			continue
		for s: Variant in ps.ships:
			if not s is ShipInstance:
				continue
			var ship: ShipInstance = s as ShipInstance
			if not commands.has(ship.data_key):
				_log.warn("No fixed commands for ship '%s' — skipping." % ship.data_key)
				continue
			var cmds: Variant = commands[ship.data_key]
			if not cmds is Array:
				continue
			var typed_cmds: Array[int] = []
			for cmd: Variant in (cmds as Array):
				typed_cmds.append(cmd as int)
			var ok: bool = ship.command_dial_stack.assign_dials(
					typed_cmds, 1)
			if ok:
				assigned_count += 1
				_log.info("Auto-assigned round 1 commands: %s = %s" % [
						ship.data_key, str(typed_cmds)])
				EventBus.command_dials_changed.emit(ship)
			else:
				_log.warn("assign_dials failed for '%s' (fixed commands)." % ship.data_key)

	# Mark both players as submitted and skip the command phase.
	_command_submitted = [true, true]
	_command_assigning_player = -1
	fixed_commands_applied = true
	_log.info("Fixed round-1 commands applied to %d ships. Skipping command phase." % assigned_count)
	EventBus.command_phase_complete.emit()
	advance_phase()


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
			Constants.GamePhase.STATUS:
				_begin_status_phase()


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
			if si.command_dial_stack.get_dials_needed() > 0:
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


## Returns the ship currently being activated, or null.
## Requirements: UI-024, UI-026.
func get_activating_ship() -> ShipInstance:
	return _activating_ship


## Starts a ship's activation by revealing its top command dial.
## Called when a command dial is successfully dropped on a ship token.
## Requirements: SP-010, SP-011, UI-024.
## [param ship] — the ship to activate.
func activate_ship(ship: ShipInstance) -> void:
	if _activating_ship != null:
		_log.warn("Cannot activate — already activating a ship.")
		return
	if ship.activated_this_round:
		_log.warn("Cannot activate — ship already activated this round.")
		return
	if ship.command_dial_stack == null:
		_log.warn("Cannot activate — ship has no command dial stack.")
		return
	# The dial may already be revealed (early reveal on drag start).
	var dial: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		dial = ship.command_dial_stack.reveal_top()
	if dial.is_empty():
		_log.warn("Cannot activate — no dials to reveal.")
		return
	_activating_ship = ship
	EventBus.command_dials_changed.emit(ship)
	_log.info("Ship activated: %s (command: %d)" % [
			ship.data_key, int(dial.get("command", -1))])


## Starts a ship's activation by revealing and immediately spending its top
## command dial, then attempting to convert it to a matching command token.
## The dial goes directly to the spent area (activation marker) instead of
## remaining revealed on the board.
## If adding the token causes overflow (tokens > command value), the token is
## still added but ``token_discard_required`` is emitted so the UI can prompt
## the player to choose one to discard.
## If the token is a duplicate of one already held, the duplicate is
## immediately removed and ``duplicate_token_discarded`` is emitted.
## Rules Reference: "Command Dials", p.3 — "spend the command dial to gain
## a command token of the same type." SP-011b.
## Rules Reference: "Command Tokens", p.4 — overflow / duplicate discard.
## Requirements: UI-028, SP-011, CM-004–006.
## [param ship] — the ship to activate.
## Returns a dictionary with "command" (CommandType), "token_added" (bool),
## and "needs_discard" (bool), or an empty dictionary on failure.
func activate_ship_as_token(ship: ShipInstance) -> Dictionary:
	if _activating_ship != null:
		_log.warn("Cannot activate — already activating a ship.")
		return {}
	if ship.activated_this_round:
		_log.warn("Cannot activate — ship already activated this round.")
		return {}
	if ship.command_dial_stack == null:
		_log.warn("Cannot activate — ship has no command dial stack.")
		return {}

	# The dial may already be revealed (early reveal on drag start).
	var dial: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		dial = ship.command_dial_stack.reveal_top()
	if dial.is_empty():
		_log.warn("Cannot activate — no dials to reveal.")
		return {}

	var cmd: int = int(dial.get("command", 0))

	# Immediately spend the revealed dial (goes to spent area).
	ship.command_dial_stack.spend_revealed()

	# Force-add the token — overflow and duplicate are handled after.
	var token_added: bool = false
	var needs_discard: bool = false
	if ship.command_tokens:
		var result: Dictionary = ship.command_tokens.force_add_token(cmd)
		token_added = true

		if result.get("duplicate", false):
			# Auto-discard the duplicate immediately (CM-005).
			ship.command_tokens.remove_token(cmd)
			EventBus.command_tokens_changed.emit(ship)
			EventBus.duplicate_token_discarded.emit(ship, cmd)
			_log.info("Duplicate token %d auto-discarded for %s" % [cmd, ship.data_key])
		elif result.get("overflow", false):
			# Player must choose which token to discard (CM-004).
			needs_discard = true
			EventBus.command_tokens_changed.emit(ship)
			EventBus.token_discard_required.emit(ship)
			_log.info("Token overflow for %s — player must discard one." % ship.data_key)
		else:
			EventBus.command_tokens_changed.emit(ship)

	_activating_ship = ship
	EventBus.command_dials_changed.emit(ship)

	_log.info("Ship activated (token convert): %s (command: %d, token_added: %s, needs_discard: %s)" % [
			ship.data_key, cmd, str(token_added), str(needs_discard)])
	return {"command": cmd, "token_added": token_added, "needs_discard": needs_discard}


# ---------------------------------------------------------------------------
# Ship Phase turn management
# ---------------------------------------------------------------------------

## Called when the active player presses "End Activation" (Ship or Squadron).
## During Ship Phase: spends the revealed dial, marks the ship as activated,
## and advances the turn. During Squadron Phase: advances the turn.
## Requirements: TF-005, TF-011, UI-026, SP-002.
func _on_activation_ended() -> void:
	if not is_game_active or not current_game_state:
		return

	# Ship Phase: spend revealed dial and mark ship as activated.
	# The dial may already have been spent by activate_ship_as_token()
	# (card-drop token conversion), so only spend if still revealed.
	if current_game_state.current_phase == Constants.GamePhase.SHIP:
		if _activating_ship != null:
			var revealed: Dictionary = \
					_activating_ship.command_dial_stack.get_revealed_dial()
			if not revealed.is_empty():
				_activating_ship.command_dial_stack.spend_revealed()
			_activating_ship.activated_this_round = true
			EventBus.command_dials_changed.emit(_activating_ship)
			_log.info("Ship activation ended: %s" % _activating_ship.data_key)
			_activating_ship = null

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


## Begins the Squadron Phase.
## --- Placeholder: auto-passes all squadron activations immediately. ---
## Full squadron activation (movement, attacks, engagement, keywords)
## will be implemented in Phase 7.
## Requirements: TF-008, SQ-001–005.
func _begin_squadron_phase() -> void:
	if not current_game_state:
		return
	_auto_pass_all_squadrons()
	advance_phase()


## Marks all squadrons as activated so the phase can advance.
## Placeholder — Phase 7 will replace this with interactive activation.
func _auto_pass_all_squadrons() -> void:
	for i: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = current_game_state.get_player_state(i)
		if ps == null:
			continue
		for sq: Variant in ps.squadrons:
			if sq is SquadronInstance:
				(sq as SquadronInstance).activated_this_round = true
	_log.info("Squadron Phase: auto-passed all squadrons (placeholder).")


## Begins the Status Phase.
## Performs end-of-round cleanup (ready tokens, reset activations, flip
## initiative) then auto-advances to the next round.
## --- Placeholder: auto-advances immediately with no player interaction. ---
## Full Status Phase UI (HUD updates, visual token readying) will be
## implemented in Phase 8.
## Rules Reference: "Status Phase", p.6; ST-001–004.
func _begin_status_phase() -> void:
	if not current_game_state:
		return
	_perform_status_phase_cleanup()
	advance_phase()


## Performs all end-of-round state changes.
## ST-001: Ready all exhausted defense tokens.
## ST-004: Reset activation flags on all ships and squadrons.
## Rules Reference: "Status Phase", p.6; "Initiative", p.8 — initiative
## does NOT change; the first player retains it for the entire game.
func _perform_status_phase_cleanup() -> void:
	for i: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = current_game_state.get_player_state(i)
		if ps == null:
			continue
		for s: Variant in ps.ships:
			if s is ShipInstance:
				var si: ShipInstance = s as ShipInstance
				si.ready_defense_tokens()
				si.reset_activation()
				# Clear spent dial marker so it doesn't persist into the
				# next round's card panel display.
				if si.command_dial_stack != null:
					si.command_dial_stack.clear_spent_history()
					EventBus.command_dials_changed.emit(si)
		for sq: Variant in ps.squadrons:
			if sq is SquadronInstance:
				var sqi: SquadronInstance = sq as SquadronInstance
				sqi.ready_defense_tokens()
				sqi.reset_activation()
	# Rules Reference: "Initiative", p.8 — "The first player retains
	# initiative for the entire game." Initiative does NOT change.
	_log.info("Status Phase: cleanup complete. Initiative stays with player %d." % [
			current_game_state.initiative_player])

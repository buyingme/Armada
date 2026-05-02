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

## The squadron currently being activated during Squadron Phase, or null.
## Set when a squadron token is clicked; cleared after move+attack resolves.
## Requirements: SQ-006.
var _activating_squadron: SquadronInstance = null

## How many squadrons the active player has activated in the current turn
## during the Squadron Phase.  Each turn activates exactly 2 squadrons
## (or fewer if the player has fewer remaining).
## Resets when the active player changes.
## Requirements: SQ-002.
var _squadrons_activated_this_turn: int = 0

## Whether fixed round-1 commands were applied this game.
## Set by [method apply_fixed_round1_commands]; reset on [method start_new_game].
## Used by the game board to show a brief toast notification.
## Requirements: CP-009, CP-010.
var fixed_commands_applied: bool = false

## Scenario identifier for the current game (used in replay headers).
## Set by [method start_new_game] from the [code]"scenario_id"[/code]
## config key.
var _scenario_id: String = ""

## Strategy for submitting commands — [LocalCommandSubmitter] for hot-seat
## and single-player, [NetworkCommandSubmitter] for network multiplayer.
## G4 Network Plan: §1.5 — CommandSubmitter Strategy.
var _submitter: CommandSubmitter = LocalCommandSubmitter.new()


## Returns true when this instance is a network client (not the server/host).
## Used to suppress game-flow commands that the server drives.  G4.6.5 fix.
func _is_network_client() -> bool:
	return PlayMode.is_network() and not NetworkManager.is_server()


func _ready() -> void:
	EventBus.command_dials_submitted.connect(_on_command_dials_submitted)
	EventBus.command_picker_confirmed.connect(_on_command_picker_confirmed)
	EventBus.activation_ended.connect(_on_activation_ended)
	EventBus.handoff_accepted.connect(_on_handoff_accepted)
	EventBus.squadron_activation_ended.connect(
			_on_squadron_activation_ended)
	# Phase 8 — continuous elimination check (GF-004, WN-001).
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.squadron_destroyed.connect(_on_squadron_destroyed)
	# G4.6.5.6 — client-side command result handler.
	NetworkManager.command_result_received.connect(
			_on_network_command_result)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		auto_save_replay()
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_PREDELETE:
		# Release the GameState RefCounted chain so scripts are freed cleanly
		# at exit (avoids "resources still in use" warnings).
		current_game_state = null
		_activating_ship = null
		_activating_squadron = null


## Sets the active command submitter strategy.
## Call before [method start_new_game] to switch between local and network.
## [param submitter] — a [CommandSubmitter] instance.
func set_command_submitter(submitter: CommandSubmitter) -> void:
	_submitter = submitter
	_log.info("Command submitter set to %s." % submitter.get_class())


## Returns the active [CommandSubmitter].
func get_command_submitter() -> CommandSubmitter:
	return _submitter


## Starts a new game in a play-mode-aware way.  Hot-seat passes
## [code]{"scenario_id": default_scenario_id}[/code] straight through.
## Network mode pulls the shared RNG seed + scenario from
## [code]NetworkManager.get_pending_game_config()[/code] (set by the host
## via the lobby G4.6.5.2/3 RPC) and tags the dictionary with
## [code]"client_mode": true[/code] when this peer is a non-server client
## so [method start_new_game] skips the local [code]_start_round[/code]
## (the server broadcasts [StartRoundCommand]).  Phase I6e-2 — replaces
## the [code]if PlayMode.is_network()[/code] branch in [code]_ready[/code]
## of [GameBoard].
func bootstrap_game(default_scenario_id: String) -> void:
	var config: Dictionary
	if PlayMode.is_network():
		config = NetworkManager.get_pending_game_config()
		if not NetworkManager.is_server():
			config["client_mode"] = true
	else:
		config = {"scenario_id": default_scenario_id}
	start_new_game(config)


## Starts a new game with the given configuration.
## [param config] — optional settings:
##   [code]"rng_seed"[/code] (int) — deterministic RNG seed.  If 0 or
##       absent a random seed is chosen.
##   [code]"scenario_id"[/code] (String) — scenario identifier stored
##       for replay headers (default: [code]""[/code]).
func start_new_game(config: Dictionary = {}) -> void:
	CommandProcessor.reset()
	current_game_state = GameState.new()
	# Inject a deterministic seed before initialize() if provided.
	var seed_value: int = config.get("rng_seed", 0) as int
	if seed_value != 0:
		current_game_state.rng = GameRng.new(seed_value)
	current_game_state.initialize()
	is_game_active = true
	active_player = current_game_state.initiative_player
	_activating_ship = null
	_activating_squadron = null
	_squadrons_activated_this_turn = 0
	fixed_commands_applied = false
	_scenario_id = config.get("scenario_id", "") as String
	EventBus.game_started.emit()
	# Per-instance file logging for network games.  G4.6.5 C1.
	if PlayMode.is_network():
		var role: String = "host" if NetworkManager.is_server() else "client"
		var ts: String = Time.get_datetime_string_from_system() \
				.replace(":", "").replace("-", "").replace("T", "_")
		var log_path: String = "res://logs/%s_%s.log" % [role, ts]
		GameLogger.enable_file_logging(log_path)
	# In network client mode, skip _start_round() — the server broadcasts
	# StartRoundCommand and the client applies it via the handler.  G4.6.5 A1.
	if not config.get("client_mode", false):
		_start_round()


## Installs a previously-serialised [param state] as the live game state
## (Phase J2).  Called by the load-game flow once a save has been read
## and validated by [SaveGameManager].  Hot-seat only in J2; network
## load is deferred to J7.
##
## [param state] — the deserialised [GameState], with ship/squadron
##     templates already re-resolved by [PlayerState.deserialize].
## [param scenario_id] — the saved scenario identifier, used by replay
##     headers and for any scene rebuild that needs the JSON definition.
##
## Side effects: resets [CommandProcessor], assigns
## [member current_game_state], restores [member is_game_active] and
## [member active_player], clears per-round trackers, and emits
## [signal EventBus.game_started] so the board can rebuild.
func start_new_game_from_state(
		state: GameState, scenario_id: String) -> void:
	if state == null:
		_log.error("start_new_game_from_state called with null state.")
		return
	CommandProcessor.reset()
	current_game_state = state
	if current_game_state.effect_registry == null:
		current_game_state.effect_registry = EffectRegistry.new()
	if current_game_state.interaction_flow == null:
		current_game_state.interaction_flow = InteractionFlow.new()
	is_game_active = true
	active_player = current_game_state.initiative_player
	_activating_ship = null
	_activating_squadron = null
	_squadrons_activated_this_turn = 0
	_command_submitted = [false, false]
	_command_assigning_player = -1
	# Loaded saves always have interaction_flow == NONE (Phase J Q5),
	# so fixed_commands_applied is set true to suppress the round-1 toast.
	fixed_commands_applied = true
	_scenario_id = scenario_id
	_log.info("Loaded game from save: scenario='%s' round=%d phase=%d." % [
			scenario_id,
			current_game_state.current_round,
			current_game_state.current_phase])
	EventBus.game_started.emit()


## Scoring calculator (created lazily, reused across end-game checks).
var _scoring: ScoringCalculator = null


## Ends the current game, computing scores and determining the winner.
## [param reason] — why the game ended: "elimination", "round_6", or
##   "mutual_destruction".
## [param eliminated_player] — the player whose fleet was wiped (only used
##   when [param reason] is "elimination").
## Rules Reference: WN-001–004, GO-004, GF-003.
func end_game(
		reason: String = "round_6",
		eliminated_player: int = -1) -> void:
	is_game_active = false
	auto_save_replay()
	if _scoring == null:
		_scoring = ScoringCalculator.new()
	var details: Dictionary = {}
	if current_game_state:
		details = _scoring.determine_winner(
				current_game_state, reason, eliminated_player)
		details["round"] = current_game_state.current_round
	else:
		details = {
			"winner_index": - 1,
			"reason": reason,
			"scores": [0, 0],
			"round": 0,
		}
	EventBus.game_ended.emit(details)


## Returns the scenario identifier for the current game session.
func get_scenario_id() -> String:
	return _scenario_id


## Auto-saves a replay file when the game exits or ends.
## Silently skips if no game is active or no commands have been recorded.
## The replay is saved to [code]res://replays/[/code] with a timestamped
## filename.
func auto_save_replay() -> void:
	# Network client: only the host/server saves replays.  G4.6.5 D1.
	if _is_network_client():
		return
	if not is_instance_valid(CommandProcessor):
		return
	var replay: GameReplay = CommandProcessor.create_replay()
	if replay == null or replay.get_command_count() == 0:
		return
	var path: String = GameReplay.generate_file_path()
	var err: Error = replay.save_to_file(path)
	if err == OK:
		_log.info("Auto-saved replay: %s (%d commands)." % [
				path, replay.get_command_count()])
	else:
		_log.error("Auto-save replay failed: %s" % error_string(err))


## Applies pre-assigned (fixed) command dials to all ships for round 1,
## then immediately skips the command phase.
## [param commands] — Dictionary mapping ship data_key → Array[int] of
##     Constants.CommandType values (first element = top of stack).
## Must be called while the game is in round 1 / COMMAND phase and after
## ship instances have been registered in the game state.
## Rules Reference: LTP p.10 — "suggested commands"; CP-009, CP-010.
func apply_fixed_round1_commands(commands: Dictionary) -> void:
	# Phase I6e-2: network clients must not author fixed round-1
	# command-dial assignments.  The host runs the auto-assignment and
	# broadcasts each [AssignDialCommand]; the client receives them via
	# [_handle_remote_command_effects].  Centralising the guard here
	# (instead of at every call site) removes one more
	# [code]is_network()[/code] branch from [GameBoard].
	if _is_network_client():
		return
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
			if _assign_fixed_commands_to_ship(
					s as ShipInstance, commands):
				assigned_count += 1

	_command_submitted = [true, true]
	_command_assigning_player = -1
	fixed_commands_applied = true
	_log.info("Fixed round-1 commands applied to %d ships. Skipping command phase." % assigned_count)
	EventBus.command_phase_complete.emit()
	advance_phase()


## Assigns fixed commands to a single ship from the commands dictionary.
## Routes through [CommandProcessor] for history and replay tracking.
## Returns true if assignment succeeded.
func _assign_fixed_commands_to_ship(ship: ShipInstance,
		commands: Dictionary) -> bool:
	if not commands.has(ship.data_key):
		_log.warn("No fixed commands for ship '%s' — skipping." % ship.data_key)
		return false
	var cmds: Variant = commands[ship.data_key]
	if not cmds is Array:
		return false
	var typed_cmds: Array[int] = []
	for cmd: Variant in (cmds as Array):
		typed_cmds.append(cmd as int)
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := AssignDialCommand.new(ship.owner_player, {
			"ship_index": ship_index,
			"commands": typed_cmds})
	var result: Dictionary = _submitter.submit(cmd)
	if result.get("success", false):
		_log.info("Auto-assigned round 1 commands: %s = %s" % [
				ship.data_key, str(typed_cmds)])
		EventBus.command_dials_changed.emit(ship)
		return true
	_log.warn("assign_dials failed for '%s' (fixed commands)." % ship.data_key)
	return false


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
	# Network client: server drives phase advancement.  G4.6.5 A4.
	if _is_network_client():
		return

	var next_phase := _get_next_phase(current_game_state.current_phase)

	if next_phase == Constants.GamePhase.COMMAND:
		# We've wrapped around — start a new round
		_end_round()
		if is_game_active:
			_start_round()
	else:
		# Route phase mutation through command for replay determinism.
		var cmd := AdvancePhaseCommand.new(
				active_player,
				{"next_phase": int(next_phase)})
		_submitter.submit(cmd)
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
	# Network client: server drives round start.  G4.6.5 A5.
	if _is_network_client():
		return
	# Check whether all rounds have been played before attempting to start
	# a new one.  The command's own validate() guards against this too, but
	# we need the end_game() call here on the presentation side.
	if current_game_state.current_round >= Constants.MAX_ROUNDS:
		end_game("round_6")
		return

	# Route round/phase mutation through command for replay determinism.
	var cmd := StartRoundCommand.new(
			active_player, {})
	_submitter.submit(cmd)

	# Reset submission tracking for the new round.
	_command_submitted = [false, false]

	# Activate the sync gate for network play (G4.4).
	if PlayMode.is_network():
		NetworkManager.activate_sync_gate()

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
## Routes through [CommandProcessor] for history and replay tracking.
## Assigns the selected commands into that ship's dial stack and checks
## whether all ships for the owning player have been assigned.
func _on_command_picker_confirmed(ship: ShipInstance,
		commands: Array) -> void:
	if not is_game_active or not current_game_state:
		return
	if ship.command_dial_stack == null:
		return

	var typed_commands: Array[int] = []
	for cmd: Variant in commands:
		typed_commands.append(cmd as int)

	var ship_index: int = current_game_state.find_ship_index(ship)
	var assign_cmd := AssignDialCommand.new(ship.owner_player, {
			"ship_index": ship_index,
			"commands": typed_commands})
	var result: Dictionary = _submitter.submit(assign_cmd)
	if not result.get("success", false):
		_log.warn("assign_dials failed for '%s'" % [
				ship.ship_data.ship_name if ship.ship_data else "?"])
		return
	EventBus.command_dials_changed.emit(ship)

	_check_player_all_assigned(ship.owner_player)


## Checks if all ships for the given player have been assigned dials.
## If so, marks the player as submitted and emits the signal.
func _check_player_all_assigned(player_index: int) -> void:
	if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
		return

	var ps: PlayerState = current_game_state.get_player_state(player_index)
	if ps == null:
		return

	var all_assigned: bool = true
	for s: Variant in ps.ships:
		if s is ShipInstance:
			var si: ShipInstance = s as ShipInstance
			if si.is_destroyed():
				continue
			if si.command_dial_stack == null:
				continue
			if si.command_dial_stack.get_dials_needed() > 0:
				all_assigned = false
				break

	if all_assigned:
		_command_submitted[player_index] = true
		EventBus.command_dials_submitted.emit(player_index)


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
	# Network client: server broadcasts AdvancePhaseCommand.  G4.6.5 A6.
	if not _is_network_client():
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
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := ActivateShipCommand.new(ship.owner_player,
			{"ship_index": ship_index})
	var result: Dictionary = _submitter.submit(cmd)
	if result.is_empty():
		return
	_activating_ship = ship
	EventBus.command_dials_changed.emit(ship)
	_log.info("Ship activated: %s (command: %d)" % [
			ship.data_key, result.get("command", -1)])


## Activates a ship without requiring a revealed dial.
## Used when Crew Panic discards the command dial before reveal.
## The ship is marked as activating but has no command for this round.
## Rules Reference: "Crew Panic" — "discard that dial … do not reveal a
## dial this round."
func force_activate_ship(ship: ShipInstance) -> void:
	if _activating_ship != null:
		_log.warn("Cannot force-activate — already activating a ship.")
		return
	if ship.activated_this_round:
		_log.warn("Cannot force-activate — already activated this round.")
		return
	_activating_ship = ship
	_log.info("Ship force-activated (no dial): %s" % ship.data_key)


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
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := ConvertDialToTokenCommand.new(ship.owner_player,
			{"ship_index": ship_index})
	var result: Dictionary = _submitter.submit(cmd)
	if result.is_empty():
		return {}

	_activating_ship = ship
	EventBus.command_dials_changed.emit(ship)

	# Emit token-related EventBus signals based on command result.
	var cmd_type: int = result.get("command", -1)
	var token_added: bool = result.get("token_added", false)
	var needs_discard: bool = result.get("overflow", false)

	if not result.get("token_blocked", false):
		if result.get("duplicate", false):
			EventBus.command_tokens_changed.emit(ship)
			EventBus.duplicate_token_discarded.emit(ship, cmd_type)
		elif needs_discard:
			EventBus.command_tokens_changed.emit(ship)
			EventBus.token_discard_required.emit(ship)
		else:
			EventBus.command_tokens_changed.emit(ship)

	_log.info(("Ship activated (token convert): %s (command: %d, "
			+"token_added: %s, needs_discard: %s)") % [
			ship.data_key, cmd_type, str(token_added),
			str(needs_discard)])
	return {"command": cmd_type, "token_added": token_added,
			"needs_discard": needs_discard}


## Force-adds a command token and handles duplicate / overflow cases.
## Returns a dictionary with "token_added" and "needs_discard" keys.
## ON_COMMAND_TOKEN_GAIN hook — Life Support Failure blocks token gain.
## Rules Reference: "Life Support Failure" card text.
func _handle_token_add_result(ship: ShipInstance,
		cmd: int) -> Dictionary:
	# Check for damage card effects that block token gain.
	if _is_token_gain_blocked(ship):
		_log.info("Token gain blocked for %s (damage effect)." % ship.data_key)
		return {"token_added": false, "needs_discard": false}
	var result: Dictionary = ship.command_tokens.force_add_token(cmd)

	if result.get("duplicate", false):
		ship.command_tokens.remove_token(cmd)
		EventBus.command_tokens_changed.emit(ship)
		EventBus.duplicate_token_discarded.emit(ship, cmd)
		_log.info("Duplicate token %d auto-discarded for %s" % [cmd, ship.data_key])
		return {"token_added": true, "needs_discard": false}

	if result.get("overflow", false):
		EventBus.command_tokens_changed.emit(ship)
		EventBus.token_discard_required.emit(ship)
		_log.info("Token overflow for %s — player must discard one." % ship.data_key)
		return {"token_added": true, "needs_discard": true}

	EventBus.command_tokens_changed.emit(ship)
	return {"token_added": true, "needs_discard": false}


## Submits a [SpendTokenCommand] for the given ship + token type.
## Called by Node-layer code after a resolver's [code]finalize()[/code]
## returns a [code]{"token_type": int}[/code] result.
## Emits [signal EventBus.command_tokens_changed] on success.
## [param ship] — the ship to spend the token from.
## [param token_type] — [Constants.CommandType] int value.
func submit_spend_token(ship: ShipInstance, token_type: int) -> void:
	if not current_game_state:
		return
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := SpendTokenCommand.new(ship.owner_player,
			{"ship_index": ship_index, "token_type": token_type})
	var result: Dictionary = _submitter.submit(cmd)
	if not result.is_empty():
		EventBus.command_tokens_changed.emit(ship)


## Submits a [DiscardTokenCommand] to remove one token during overflow.
## The UI (ShipCardPanel) enters discard mode and calls this when the
## player clicks a token to discard.
## Emits [signal EventBus.command_tokens_changed] and
## [signal EventBus.token_discarded] on success.
## [param ship] — the ship to discard the token from.
## [param token_type] — [Constants.CommandType] int value.
func submit_discard_token(ship: ShipInstance,
		token_type: int) -> void:
	if not current_game_state:
		return
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := DiscardTokenCommand.new(ship.owner_player,
			{"ship_index": ship_index, "token_type": token_type})
	var result: Dictionary = _submitter.submit(cmd)
	if not result.is_empty():
		EventBus.command_tokens_changed.emit(ship)
		EventBus.token_discarded.emit(ship, token_type)


## Submits a [RevealDialCommand] to reveal the top hidden dial.
## Called by ShipCardPanel when the player clicks a ship card (step 1
## of the two-click activation flow).
## Emits [signal EventBus.command_dials_changed] on success.
## [param ship] — the ship whose top dial should be revealed.
func submit_reveal_dial(ship: ShipInstance) -> void:
	if not current_game_state:
		return
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := RevealDialCommand.new(ship.owner_player,
			{"ship_index": ship_index, "action": "reveal"})
	var result: Dictionary = _submitter.submit(cmd)
	if not result.is_empty():
		EventBus.command_dials_changed.emit(ship)


## Submits a [RevealDialCommand] to unreveal a previously revealed dial.
## Called when the player changes their mind (clicks a different ship) or
## when a dial drag is cancelled.
## Emits [signal EventBus.command_dials_changed] on success.
## [param ship] — the ship whose dial should be unrevealed.
func submit_unreveal_dial(ship: ShipInstance) -> void:
	if not current_game_state:
		return
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := RevealDialCommand.new(ship.owner_player,
			{"ship_index": ship_index, "action": "unreveal"})
	var result: Dictionary = _submitter.submit(cmd)
	if not result.is_empty():
		EventBus.command_dials_changed.emit(ship)


## Submits a [SpendDialCommand] to spend (or discard) the top dial.
## Called by Node-layer code after a resolver's [code]finalize()[/code]
## returns a [code]{"dial_spent": true}[/code] result, or directly by
## presentation code that used to call [code]spend_revealed()[/code].
## Emits [signal EventBus.command_dials_changed] on success.
## [param ship] — the ship whose dial should be spent.
## [param mode] — [code]"spend"[/code] (default) or [code]"discard"[/code].
func submit_spend_dial(ship: ShipInstance, mode: String = "spend") -> void:
	if not current_game_state:
		return
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := SpendDialCommand.new(ship.owner_player,
			{"ship_index": ship_index, "mode": mode})
	var result: Dictionary = _submitter.submit(cmd)
	if not result.is_empty():
		EventBus.command_dials_changed.emit(ship)


## Submits a [MoveSquadronCommand] recording a squadron's new normalised position.
## Called after the presentation layer commits a validated squadron move.
## [param squadron] — the SquadronInstance that moved.
## [param norm_x] — normalised X position (0.0–1.0).
## [param norm_y] — normalised Y position (0.0–1.0).
func submit_move_squadron(squadron: SquadronInstance,
		norm_x: float, norm_y: float) -> Dictionary:
	if not current_game_state:
		return {}
	var sq_index: int = current_game_state.find_squadron_index(squadron)
	var cmd := MoveSquadronCommand.new(squadron.owner_player,
			{"squadron_index": sq_index, "pos_x": norm_x, "pos_y": norm_y})
	return _submitter.submit(cmd)


## Submits a [StartDisplacementCommand] opening the squadron-displacement
## flow on the squadron-owner peer.  Phase I6b-4.
##
## [param ship] — the maneuvering ship that triggered the overlap.
## [param controller_player] — the peer that must drive the placement
##     modal (always the squadron owner; in mixed-owner edge cases the
##     caller picks one).
## [param displaced_squadrons] — Array of [SquadronInstance] that must
##     be re-placed.
func submit_start_displacement(ship: ShipInstance,
		controller_player: int,
		displaced_squadrons: Array) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var entries: Array = []
	for sq: SquadronInstance in displaced_squadrons:
		entries.append({
			"owner": sq.owner_player,
			"squadron_index":
					current_game_state.find_squadron_index(sq),
		})
	var cmd := StartDisplacementCommand.new(ship.owner_player, {
		"ship_index": ship_index,
		"controller_player": controller_player,
		"displaced_squadrons": entries,
	})
	return _submitter.submit(cmd)


## Submits a [CommitDisplacementCommand] closing the squadron-displacement
## flow.  Submitted by the controller peer once they confirm placements.
## Phase I6b-4.
##
## [param placements] — Array[Dictionary] of
##     [code]{ owner, squadron_index, pos_x, pos_y }[/code] entries.
func submit_commit_displacement(placements: Array) -> Dictionary:
	if not current_game_state:
		return {}
	var flow: InteractionFlow = current_game_state.interaction_flow
	var controller: int = flow.controller_player if flow != null else -1
	if controller < 0:
		_log.warn("submit_commit_displacement: no displacement flow active.")
		return {}
	var cmd := CommitDisplacementCommand.new(controller,
			{"placements": placements})
	return _submitter.submit(cmd)


## Submits an [ExecuteManeuverCommand] recording a ship's final position.
## Called after the presentation layer resolves overlaps and snaps the ship.
## [param ship] — the ShipInstance that manoeuvred.
## [param speed] — the speed used for this maneuver.
## [param yaw_clicks] — signed yaw clicks per joint.
## [param norm_x] — normalised X position (0.0–1.0).
## [param norm_y] — normalised Y position (0.0–1.0).
## [param rotation_deg] — final rotation in degrees.
func submit_execute_maneuver(ship: ShipInstance, speed: int,
		yaw_clicks: Array, norm_x: float, norm_y: float,
		rotation_deg: float) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := ExecuteManeuverCommand.new(ship.owner_player, {
		"ship_index": ship_index, "speed": speed,
		"yaw_clicks": yaw_clicks, "pos_x": norm_x, "pos_y": norm_y,
		"rotation_deg": rotation_deg})
	return _submitter.submit(cmd)


## Submits a [RollDiceCommand] for deterministic dice rolling.
## Returns the command result containing [code]"dice_results"[/code].
## [param player] — the attacking player index.
## [param dice_pool] — Dictionary mapping colour string to count.
func submit_roll_dice(player: int,
		dice_pool: Dictionary) -> Dictionary:
	if not current_game_state:
		return {}
	var cmd := RollDiceCommand.new(player,
			{"dice_pool": dice_pool.duplicate()})
	return _submitter.submit(cmd)


## Submits a [SpendDefenseTokenCommand] for defense token spending.
## [param ship] — the defending ShipInstance.
## [param token_index] — index in defense_tokens array.
## [param spend_method] — "exhaust" or "discard".
func submit_spend_defense_token(ship: ShipInstance, token_index: int,
		spend_method: String) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := SpendDefenseTokenCommand.new(ship.owner_player,
			{"ship_index": ship_index, "token_index": token_index,
			"spend_method": spend_method})
	return _submitter.submit(cmd)


## Submits a [CommitDefenseCommand] from the defender peer when the
## player presses [i]Commit Defense[/i] on the [AttackPanelMirror].
## Phase I6b-3 R2 — closes NW-006.
## [param ship] — the defending ShipInstance.
## [param selected_indices] — token indices in canonical resolution
##                            order; may be empty.
func submit_commit_defense(ship: ShipInstance,
		selected_indices: Array[int]) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var indices_payload: Array = []
	for idx: int in selected_indices:
		indices_payload.append(idx)
	var cmd := CommitDefenseCommand.new(ship.owner_player,
			{"ship_index": ship_index,
			"selected_indices": indices_payload})
	return _submitter.submit(cmd)


## Submits a [SelectEvadeDieCommand] from the defender peer when the
## player picks an attack die for the Evade defense effect on the
## [AttackPanelMirror].  Phase I6b-3 R3.
## [param ship] — the defending ShipInstance.
## [param die_index] — index into the attacker's dice-results buffer.
func submit_select_evade_die(ship: ShipInstance,
		die_index: int) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := SelectEvadeDieCommand.new(ship.owner_player,
			{"ship_index": ship_index, "die_index": die_index})
	return _submitter.submit(cmd)


## Submits a [SelectRedirectZoneCommand] for redirect damage allocation.
## [param ship] — the defending ShipInstance.
## [param zone] — [Constants.HullZone] int value of the target zone.
func submit_select_redirect_zone(ship: ShipInstance,
		zone: int) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := SelectRedirectZoneCommand.new(ship.owner_player,
			{"ship_index": ship_index, "zone": zone})
	return _submitter.submit(cmd)


## Submits a [RedirectDoneCommand] when the defender ends the redirect
## sub-step early via the [i]Done Redirecting[/i] button on the
## [AttackPanelMirror].  Phase I6b-3 R4.
## [param ship] — the defending ShipInstance.
func submit_redirect_done(ship: ShipInstance) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := RedirectDoneCommand.new(ship.owner_player,
			{"ship_index": ship_index})
	return _submitter.submit(cmd)


## Submits a [SkipAttackCommand] for replay recording.
## [param player] — the active player index.
## [param reason] — skip reason string.
func submit_skip_attack(player: int, reason: String = "voluntary") -> Dictionary:
	if not current_game_state:
		return {}
	var cmd := SkipAttackCommand.new(player, {"reason": reason})
	return _submitter.submit(cmd)


## Submits a [PublishAttackFlowCommand] that broadcasts the current
## attack [InteractionFlow] snapshot to all peers.  Phase I6b-3 fix:
## restores the attack-flow replication that was previously carried by
## the legacy [code]NetworkInteractionState[/code] channel (deleted in
## I6c) so the defender's [UIProjector] can detect
## [constant Constants.InteractionStep.ATTACK_DEFENSE_TOKENS].
##
## In hot-seat mode this is a no-op:  the local FSM has already mutated
## [member GameState.interaction_flow], the command would be redundant,
## and skipping it keeps replays free of synthetic snapshot entries.
##
## [param flow] — the freshly-mutated [InteractionFlow] (typically
##     [code]GameManager.current_game_state.interaction_flow[/code]).
## [param submitting_player] — the player attribute on the command
##     (defaults to the active player).
func submit_publish_attack_flow(flow: InteractionFlow,
		submitting_player: int = -1) -> Dictionary:
	if not current_game_state or flow == null:
		return {}
	if not PlayMode.is_network():
		return {}
	var player: int = submitting_player
	if player < 0:
		player = get_active_player()
	var is_final: bool = (flow.flow_type
			== Constants.InteractionFlow.NONE)
	var cmd := PublishAttackFlowCommand.new(player, {
		"step_id": int(flow.step_id),
		"controller_player": flow.controller_player,
		"flow_payload": flow.payload.duplicate(true),
		"final": is_final,
	})
	return _submitter.submit(cmd)


## Submits an [AdvanceActivationStepCommand] to record a ship-activation
## modal step transition in network/replay flow.
## [param ship] - the currently activating ship.
## [param step_id] - canonical step identifier (e.g. "repair_step").
func submit_advance_activation_step(ship: ShipInstance,
		step_id: String) -> Dictionary:
	if not current_game_state or ship == null:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := AdvanceActivationStepCommand.new(ship.owner_player,
			{"ship_index": ship_index, "step_id": step_id})
	return _submitter.submit(cmd)


## Submits a [ResolveDamageCommand] for ship damage resolution.
## [param ship] — the defending ShipInstance.
## [param hull_zone] — zone string ("FRONT", "LEFT", "RIGHT", "REAR").
## [param shield_damage] — shields absorbed (pre-computed).
## [param damage_cards] — Array of serialized card dicts.
## [param destroyed] — whether the ship is destroyed.
func submit_resolve_ship_damage(ship: ShipInstance, hull_zone: String,
		shield_damage: int, damage_cards: Array,
		destroyed: bool) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := ResolveDamageCommand.new(ship.owner_player, {
		"target_type": "ship",
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"hull_zone": hull_zone,
		"shield_damage": shield_damage,
		"damage_cards": damage_cards,
		"target_destroyed": destroyed,
	})
	return _submitter.submit(cmd)


## Submits a [ResolveDamageCommand] for squadron damage resolution.
## [param squadron] — the defending SquadronInstance.
## [param hull_damage] — total damage to apply.
## [param actual_damage] — damage actually applied (capped by hull).
## [param destroyed] — whether the squadron is destroyed.
func submit_resolve_squadron_damage(squadron: SquadronInstance,
		hull_damage: int, actual_damage: int,
		destroyed: bool) -> Dictionary:
	if not current_game_state:
		return {}
	var sq_index: int = current_game_state.find_squadron_index(squadron)
	var cmd := ResolveDamageCommand.new(squadron.owner_player, {
		"target_type": "squadron",
		"owner_player": squadron.owner_player,
		"squadron_index": sq_index,
		"hull_damage": hull_damage,
		"actual_damage": actual_damage,
		"target_destroyed": destroyed,
	})
	return _submitter.submit(cmd)


## Submits a [RepairActionCommand] to move 1 shield between hull zones.
## [param ship] — the ShipInstance being repaired.
## [param from_zone] — source hull zone key (e.g. "FRONT").
## [param to_zone] — destination hull zone key.
func submit_repair_move_shields(ship: ShipInstance,
		from_zone: String, to_zone: String) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := RepairActionCommand.new(ship.owner_player, {
		"action_type": "move_shields",
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"from_zone": from_zone,
		"to_zone": to_zone,
	})
	return _submitter.submit(cmd)


## Submits a [RepairActionCommand] to recover 1 shield on a hull zone.
## [param ship] — the ShipInstance being repaired.
## [param zone] — the hull zone to restore a shield on.
func submit_repair_recover_shields(ship: ShipInstance,
		zone: String) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := RepairActionCommand.new(ship.owner_player, {
		"action_type": "recover_shields",
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"zone": zone,
	})
	return _submitter.submit(cmd)


## Submits a [RepairActionCommand] to discard a damage card.
## [param ship] — the ShipInstance being repaired.
## [param card] — the DamageCard to discard.
func submit_repair_hull(ship: ShipInstance,
		card: DamageCard) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var is_faceup: bool = ship.faceup_damage.has(card)
	var card_idx: int = -1
	if is_faceup:
		card_idx = ship.faceup_damage.find(card)
	else:
		card_idx = ship.facedown_damage.find(card)
	var cmd := RepairActionCommand.new(ship.owner_player, {
		"action_type": "repair_hull",
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"card_is_faceup": is_faceup,
		"card_index": card_idx,
	})
	return _submitter.submit(cmd)


## Submits a [ResolveImmediateEffectCommand] for a faceup damage card.
## The caller must pre-draw any extra card (structural_damage) and pass
## the serialized dict as [param extra_card_data].  Player choices are
## passed in [param choice].
## [param ship] — the ShipInstance that received the card.
## [param card] — the faceup DamageCard to resolve.
## [param choice] — player selection dictionary (may be empty).
## [param extra_card_data] — serialized DamageCard dict for pre-drawn
##   extra card (structural_damage only; empty otherwise).
func submit_resolve_immediate_effect(ship: ShipInstance,
		card: DamageCard, choice: Dictionary = {},
		extra_card_data: Dictionary = {}) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var card_idx: int = ship.faceup_damage.find(card)
	var pl: Dictionary = {
		"effect_id": card.effect_id,
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"card_index": card_idx,
		"choice": choice,
	}
	if not extra_card_data.is_empty():
		pl["extra_card_data"] = extra_card_data
	# Network: route authority through the **submitting peer** so the
	# server's peer/player check accepts the command regardless of who
	# is the chooser (attacker vs defender, debug tool, etc.).  The
	# payload's [code]owner_player[/code] still identifies the ship.
	var submitter_player: int = ship.owner_player
	if PlayMode.is_network():
		var local_idx: int = NetworkManager.get_local_player_index()
		if local_idx >= 0:
			submitter_player = local_idx
	var cmd := ResolveImmediateEffectCommand.new(
			submitter_player, pl)
	return _submitter.submit(cmd)


## Submits a [SetSpeedCommand] when the player clicks +1/−1 during
## the Navigate step of ship activation.
## [param ship] — the activating ship.
## [param new_speed] — desired speed (budget-validated by caller).
func submit_set_speed(ship: ShipInstance,
		new_speed: int) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := SetSpeedCommand.new(ship.owner_player, {
		"ship_index": ship_index,
		"new_speed": new_speed,
	})
	return _submitter.submit(cmd)


## Submits an [OverlapDamageCommand] after a ship–ship overlap.
## [param moving] — the moving ship.
## [param other] — the overlapped ship.
## [param moving_card_data] — serialized pre-drawn DamageCard.
## [param other_card_data] — serialized pre-drawn DamageCard.
func submit_overlap_damage(moving: ShipInstance,
		other: ShipInstance, moving_card_data: Dictionary,
		other_card_data: Dictionary) -> Dictionary:
	if not current_game_state:
		return {}
	var m_idx: int = current_game_state.find_ship_index(moving)
	var o_idx: int = current_game_state.find_ship_index(other)
	var cmd := OverlapDamageCommand.new(moving.owner_player, {
		"ship_index": m_idx,
		"other_owner": other.owner_player,
		"other_ship_index": o_idx,
		"moving_card": moving_card_data,
		"other_card": other_card_data,
	})
	return _submitter.submit(cmd)


## Submits a [PersistentEffectDamageCommand] when a persistent damage
## card effect deals facedown damage.
## [param ship] — the affected ship.
## [param effect_id] — which effect triggered (e.g. "ruptured_engine").
## [param card_data] — serialized pre-drawn DamageCard.
func submit_persistent_effect_damage(ship: ShipInstance,
		effect_id: String,
		card_data: Dictionary) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var cmd := PersistentEffectDamageCommand.new(ship.owner_player, {
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"effect_id": effect_id,
		"card_data": card_data,
	})
	return _submitter.submit(cmd)


## Submits a [DebugDealDamageCommand] when the debug damage tool deals
## a faceup damage card to a ship.
## [param ship] — the target ship.
## [param card_data] — serialized [DamageCard] with overridden identity.
## [param effect_id] — chosen damage card effect ID.
##
## In network mode the command's [code]player_index[/code] is set to the
## **submitting peer**'s slot (not the ship's owner) so the server's
## peer-authority check accepts the command regardless of who Shift+D'd.
## The payload's [code]owner_player[/code] still points at the ship owner.
func submit_debug_deal_damage(ship: ShipInstance,
		card_data: Dictionary,
		effect_id: String) -> Dictionary:
	if not current_game_state:
		return {}
	var ship_index: int = current_game_state.find_ship_index(ship)
	var submitter_player: int = ship.owner_player
	if PlayMode.is_network():
		var local_idx: int = NetworkManager.get_local_player_index()
		if local_idx >= 0:
			submitter_player = local_idx
	var cmd := DebugDealDamageCommand.new(submitter_player, {
		"owner_player": ship.owner_player,
		"ship_index": ship_index,
		"effect_id": effect_id,
		"card_data": card_data,
	})
	return _submitter.submit(cmd)


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
	# Routes through EndActivationCommand for history tracking.
	if current_game_state.current_phase == Constants.GamePhase.SHIP:
		if _activating_ship != null:
			var ship_index: int = current_game_state.find_ship_index(
					_activating_ship)
			var cmd := EndActivationCommand.new(
					_activating_ship.owner_player,
					{"ship_index": ship_index})
			var result: Dictionary = _submitter.submit(cmd)
			if not result.is_empty():
				EventBus.command_dials_changed.emit(_activating_ship)
				_log.info("Ship activation ended: %s" \
						% _activating_ship.data_key)
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
	# Network client: server drives turn changes.  G4.6.5 A8.
	if _is_network_client():
		return
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
## Resets the per-turn squadron activation counter for the new player.
## Requirements: TF-008, TF-009, TF-012.
func _advance_squadron_phase_turn() -> void:
	# Network client: server drives turn changes.  G4.6.5 A9.
	if _is_network_client():
		return
	var next: int = 1 - active_player
	var next_has: bool = _has_unactivated_squadrons(next)
	var curr_has: bool = _has_unactivated_squadrons(active_player)

	if not next_has and not curr_has:
		advance_phase()
		return

	if next_has:
		if not curr_has:
			_log.info("auto_pass(player=%d, phase=Squadron) — no unactivated squadrons" % active_player)
		_squadrons_activated_this_turn = 0
		_set_active_player(next)
	elif curr_has:
		_log.info("auto_pass(player=%d, phase=Squadron) — no unactivated squadrons" % next)
		_squadrons_activated_this_turn = 0
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
			if si.is_destroyed():
				continue
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
			if sqi.is_destroyed():
				continue
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
## Sets the initiative player as active and resets per-turn counters.
## Players alternate activating up to 2 squadrons each turn.
## If neither player has unactivated squadrons, the phase is auto-skipped.
## Requirements: TF-008, SQ-001–005.
func _begin_squadron_phase() -> void:
	if not current_game_state:
		return
	# Register keyword effects for all squadrons if not already done.
	if current_game_state.effect_registry.get_effect_count() == 0:
		EffectFactory.register_squadron_keywords(
				current_game_state,
				current_game_state.initiative_player)
	# If neither player has unactivated squadrons, auto-skip.
	var init: int = current_game_state.initiative_player
	if not _has_unactivated_squadrons(init) \
			and not _has_unactivated_squadrons(1 - init):
		_log.info("Squadron Phase: no squadrons to activate — auto-skip.")
		advance_phase()
		return
	_squadrons_activated_this_turn = 0
	_activating_squadron = null
	_set_active_player(init)
	_log.info("Squadron Phase: initiative player %d activates first." % init)


## Activates a squadron during the Squadron Phase.
## Called by the game board when the active player clicks a squadron token.
## Requirements: SQ-003, SQ-006.
## [param squadron] — the squadron instance to activate.
func activate_squadron(squadron: SquadronInstance) -> void:
	if not is_game_active or not current_game_state:
		return
	if _activating_squadron != null:
		_log.warn("activate_squadron: already activating a squadron.")
		return
	if squadron.owner_player != active_player:
		_log.warn("activate_squadron: squadron not owned by active player.")
		return
	var sq_index: int = current_game_state.find_squadron_index(
			squadron)
	var cmd := ActivateSquadronCommand.new(squadron.owner_player,
			{"squadron_index": sq_index})
	# Network client: set optimistically before submit so the modal
	# sees the correct state immediately.  The broadcast will confirm.
	if _is_network_client():
		_activating_squadron = squadron
	var result: Dictionary = _submitter.submit(cmd)
	if result.is_empty() and not _is_network_client():
		return
	_activating_squadron = squadron
	_log.info("Squadron activated: %s (player %d, turn count %d)" % [
			squadron.data_key, squadron.owner_player,
			_squadrons_activated_this_turn + 1])


## Returns the squadron currently being activated, or null.
func get_activating_squadron() -> SquadronInstance:
	return _activating_squadron


## Called when a squadron finishes its activation (move and/or attack done).
## Marks it as activated, increments the per-turn counter, and advances
## the turn when the player has activated 2 squadrons (or has no more).
## Requirements: SQ-002, SQ-005, TF-010, TF-011.
func _on_squadron_activation_ended(squadron: RefCounted) -> void:
	if not is_game_active or not current_game_state:
		return
	if current_game_state.current_phase != Constants.GamePhase.SQUADRON:
		return
	if squadron is SquadronInstance:
		var sq: SquadronInstance = squadron as SquadronInstance
		sq.activated_this_round = true
		_log.info("Squadron activation ended: %s" % sq.data_key)
	# Network client: activation counting is handled by
	# _handle_remote_move/activate_squadron when the broadcast arrives.
	if _is_network_client():
		return
	_activating_squadron = null
	_squadrons_activated_this_turn += 1
	# SQ-002: each player activates up to 2 squadrons per turn.
	if _squadrons_activated_this_turn >= Constants.SQUADRONS_PER_ACTIVATION \
			or not _has_unactivated_squadrons(active_player):
		_advance_squadron_phase_turn()


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
	# Network client: server broadcasts cleanup + advance.  G4.6.5 A7.
	if _is_network_client():
		return
	_perform_status_phase_cleanup()
	advance_phase()


## Performs all end-of-round state changes via [StatusPhaseCleanupCommand].
## ST-001: Ready all exhausted defense tokens.
## ST-004: Reset activation flags on all ships and squadrons.
## Rules Reference: "Status Phase", p.6; "Initiative", p.8 — initiative
## does NOT change; the first player retains it for the entire game.
func _perform_status_phase_cleanup() -> void:
	var cmd := StatusPhaseCleanupCommand.new(active_player, {})
	var result: Dictionary = _submitter.submit(cmd)

	# Emit UI events so visuals stay in sync.
	for i: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = current_game_state.get_player_state(i)
		if ps == null:
			continue
		for s: Variant in ps.ships:
			if s is ShipInstance:
				var si: ShipInstance = s as ShipInstance
				if si.is_destroyed():
					continue
				EventBus.ship_defense_token_changed.emit(si)
				if si.command_dial_stack != null:
					EventBus.command_dials_changed.emit(si)
		# Squadrons have no UI events for token readying currently.

	var blocked: Array = result.get("ships_blocked", [])
	if blocked.size() > 0:
		for key: Variant in blocked:
			_log.info("Token readying blocked for %s (damage effect)." % str(key))

	_log.info("Status Phase: cleanup complete. Initiative stays with player %d." % [
			current_game_state.initiative_player])


## Returns true if the ON_COMMAND_TOKEN_GAIN hook cancels token gain
## for [param ship] (e.g. Life Support Failure).
## Rules Reference: RRG "Damage Cards", p.4; "Life Support Failure".
func _is_token_gain_blocked(ship: ShipInstance) -> bool:
	if not current_game_state or not current_game_state.effect_registry:
		return false
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx = current_game_state.effect_registry.resolve_hook(
			&"ON_COMMAND_TOKEN_GAIN", ctx)
	return ctx.cancelled


# ---------------------------------------------------------------------------
# Elimination & scoring — Phase 8 (GF-004, WN-001, GO-004)
# ---------------------------------------------------------------------------

## Called when any ship is destroyed during an attack.
## Checks if the owning player has lost all ships → immediate game end.
## Routes destruction cleanup (damage card return, effect unregistration)
## through [DestroyUnitCommand] for replay determinism.
## Rules Reference: "Winning and Losing", RRG p.21; GF-004, WN-001.
func _on_ship_destroyed(ship: Node) -> void:
	if not is_game_active or not current_game_state:
		return
	# Determine which player owns this ship.
	var owner: int = -1
	var si: ShipInstance = null
	if ship.has_method("get_ship_instance"):
		si = ship.get_ship_instance()
		if si != null:
			owner = si.owner_player
	if owner < 0:
		return
	# Check elimination FIRST — before cleanup changes is_destroyed() result.
	_check_elimination()
	# Route cleanup through command for replay determinism.
	var idx: int = current_game_state.find_ship_index(si)
	if idx < 0:
		return
	var cmd := DestroyUnitCommand.new(owner, {
		"owner_player": owner,
		"ship_index": idx,
	})
	_submitter.submit(cmd)


## Called when any squadron is destroyed.  Squadrons alone never trigger
## elimination (GO-004), but we may want to update score HUD later.
func _on_squadron_destroyed(_squadron: Node) -> void:
	pass # Score HUD update handled in game_board.gd.


## Checks whether either (or both) player fleets have been eliminated.
## Must be called after damage resolution so [method is_destroyed] is current.
## Rules Reference: "Winning and Losing", RRG p.21; GF-004, WN-001.
func _check_elimination() -> void:
	if not is_game_active or not current_game_state:
		return
	if _scoring == null:
		_scoring = ScoringCalculator.new()
	var p0_elim: bool = _scoring.is_fleet_eliminated(0, current_game_state)
	var p1_elim: bool = _scoring.is_fleet_eliminated(1, current_game_state)
	if p0_elim and p1_elim:
		end_game("mutual_destruction")
	elif p0_elim:
		end_game("elimination", 0)
	elif p1_elim:
		end_game("elimination", 1)


# ---------------------------------------------------------------------------
# Network command result handler (G4.6.5.6)
# ---------------------------------------------------------------------------

## Called when the server broadcasts a command result to all clients.
## On the client, deserializes and executes the command locally so state stays
## in sync, then triggers post-execution effects (EventBus signals, phase
## progression).  The host ignores this — it already processed the command
## inline via [NetworkHostCommandSubmitter].
func _on_network_command_result(
		command_data: Dictionary, result: Dictionary) -> void:
	if not PlayMode.is_network():
		return
	var cmd: GameCommand = GameCommand.deserialize(command_data)
	if cmd == null:
		_log.warn("Failed to deserialize remote command.")
		return
	if NetworkManager.is_server():
		# Host: command already executed by NetworkManager.
		# Process side effects for the remote player's commands AND for
		# host-owned commands authored by the remote peer (e.g. attacker
		# peer authored [code]resolve_damage[/code] / [code]spend_defense_token[/code]
		# for the host-owned defender — see I6b-3 R2 follow-up).
		var remote_authored: bool = bool(result.get("__remote_authored", false))
		if cmd.player_index != NetworkManager.get_local_player_index() \
				or remote_authored:
			_handle_remote_command_effects(cmd, result)
		return
	CommandProcessor.submit(cmd)
	_handle_remote_command_effects(cmd, result)
	if _submitter is NetworkCommandSubmitter:
		(_submitter as NetworkCommandSubmitter).clear_awaiting()


## Emits the appropriate EventBus signals after a remotely-received command
## has been applied to local [GameState].  Mirrors the post-submit logic
## that runs inline on the host / in hot-seat mode.
## G4.6.5 Phase B — handles all 26 command types.
func _handle_remote_command_effects(
		cmd: GameCommand, result: Dictionary) -> void:
	match cmd.command_type:
		"start_round":
			_handle_remote_start_round()
		"assign_dials":
			_handle_remote_assign_dials(cmd)
		"advance_phase":
			_handle_remote_advance_phase(cmd)
		"activate_ship":
			_handle_remote_activate_ship(cmd, result)
		"convert_dial_to_token":
			_handle_remote_convert_dial_to_token(cmd, result)
		"reveal_dial", "spend_dial":
			_handle_remote_dial_change(cmd)
		"set_speed":
			pass # GameState mutated by execute(); no GM side effects.
		"execute_maneuver":
			_handle_remote_execute_maneuver(cmd)
		"end_activation":
			_handle_remote_end_activation(cmd)
		"activate_squadron":
			_handle_remote_activate_squadron(cmd)
		"move_squadron":
			_handle_remote_move_squadron(cmd)
		"start_displacement":
			# Phase I6b-4d: modal lifecycle is driven by the
			# [signal EventBus.command_executed] projection in
			# [GameBoard._on_command_executed_project_ui]; no
			# additional GameManager-side handling required.
			pass
		"commit_displacement":
			_handle_remote_commit_displacement(cmd)
		"spend_token":
			_handle_remote_spend_token(cmd)
		"discard_token":
			_handle_remote_discard_token(cmd)
		"roll_dice":
			# Network client: forward dice results to attack executor.
			if not NetworkManager.is_server():
				EventBus.network_dice_result.emit(result)
		"advance_activation_step":
			pass # UI consumes authoritative interaction-state broadcast.
		"select_redirect_zone":
			_handle_remote_select_redirect_zone(cmd, result)
		"skip_attack":
			pass # Attack executor handles display from result.
		"publish_attack_flow":
			# Phase I6b-3 follow-up: pure flow-snapshot command.
			# CommandProcessor.execute() has already written the
			# authoritative interaction_flow into GameState; the UI
			# projection runs from the command_executed signal.  No
			# additional GameManager-side handling required.
			pass
		"spend_defense_token":
			_handle_remote_spend_defense_token(cmd)
		"commit_defense":
			# Phase I6b-3 R2: marker command — attacker peer's
			# AttackExecutor reacts via command_executed.  No
			# additional GameManager-side handling required.
			pass
		"resolve_damage":
			_handle_remote_resolve_damage(cmd, result)
		"overlap_damage", "persistent_effect_damage":
			_handle_remote_damage_event(cmd, result)
		"repair_action":
			_handle_remote_repair_action(cmd)
		"resolve_immediate_effect":
			_handle_remote_immediate_effect(cmd, result)
		"status_phase_cleanup":
			_handle_remote_status_cleanup()
		"destroy_unit":
			_handle_remote_destroy_unit(cmd, result)
		"debug_deal_damage":
			pass # Debug only — no network side effects.
		_:
			_log.warn("Unhandled remote command type: %s" \
					% cmd.command_type)


## B1: Mirror start_round side effects on client.
func _handle_remote_start_round() -> void:
	_command_submitted = [false, false]
	var init: int = current_game_state.initiative_player
	_command_assigning_player = init
	# I5b-4: must use _set_active_player so active_player_changed
	# fires on the client.  Without it, GameBoard never sees the
	# round-2 transition and CmdPhase.begin_command_dial_flow() is
	# never called, leaving the Imperial dial panel closed.
	_set_active_player(init)
	if PlayMode.is_network():
		NetworkManager.activate_sync_gate()
	EventBus.round_started.emit(current_game_state.current_round)
	EventBus.phase_changed.emit(Constants.GamePhase.COMMAND)


## B2: Mirror assign_dials side effects on client.
func _handle_remote_assign_dials(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		EventBus.command_dials_changed.emit(ship)
	_check_player_all_assigned(cmd.player_index)


## B3: Mirror advance_phase side effects on client.
func _handle_remote_advance_phase(cmd: GameCommand) -> void:
	var next_phase: Constants.GamePhase = cmd.payload.get(
			"next_phase", 0) as Constants.GamePhase
	_command_assigning_player = -1
	# Only emit command_phase_complete if it hasn't already been emitted
	# by _check_command_phase_complete() via the assign_dials handler.
	# BF-3: avoids duplicate emission.
	var from_command: bool = current_game_state.current_phase \
			== Constants.GamePhase.COMMAND
	if not from_command and next_phase == Constants.GamePhase.SHIP:
		EventBus.command_phase_complete.emit()
	EventBus.phase_changed.emit(next_phase)
	match next_phase:
		Constants.GamePhase.SHIP:
			_begin_ship_phase()
		Constants.GamePhase.SQUADRON:
			_begin_squadron_phase_client()
		Constants.GamePhase.STATUS:
			pass # Server handles cleanup + advance.


## B4: Mirror activate_ship side effects on client.
func _handle_remote_activate_ship(
		cmd: GameCommand, result: Dictionary) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	_activating_ship = ship
	EventBus.command_dials_changed.emit(ship)
	# Notify the passive peer (host or client) so it can open the activation
	# modal as a read-only observer. Skip for the local player's own activation,
	# because that modal is opened from local dial-drag UI flow.
	if cmd.player_index != NetworkManager.get_local_player_index():
		EventBus.ship_activated_remotely.emit(ship)


## B5: Mirror convert_dial_to_token side effects on client.
func _handle_remote_convert_dial_to_token(
		cmd: GameCommand, result: Dictionary) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	_activating_ship = ship
	EventBus.command_dials_changed.emit(ship)
	# Dial-to-card-drop also activates the ship — notify the passive peer
	# (host or client) so it opens the mirrored activation modal.
	# Same guard as _handle_remote_activate_ship: skip only local activations.
	if cmd.player_index != NetworkManager.get_local_player_index():
		EventBus.ship_activated_remotely.emit(ship)
	if result.get("token_blocked", false):
		return
	EventBus.command_tokens_changed.emit(ship)
	var cmd_type: int = result.get("command", -1)
	if result.get("duplicate", false):
		EventBus.duplicate_token_discarded.emit(ship, cmd_type)
	elif result.get("overflow", false):
		EventBus.token_discard_required.emit(ship)


## B6: Mirror reveal_dial / spend_dial side effects on client.
func _handle_remote_dial_change(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		EventBus.command_dials_changed.emit(ship)


## BF-2: Mirror execute_maneuver — snap visual token on client.
func _handle_remote_execute_maneuver(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		EventBus.ship_repositioned_remotely.emit(ship)


## BF-2: Mirror move_squadron — snap visual token on client.
## BF-2: Mirror move_squadron — snap visual token and finish activation
## on remote peer.  Displacement moves (Ship Phase) only reposition
## the token without touching activation state.  G4.6.5.
func _handle_remote_move_squadron(cmd: GameCommand) -> void:
	var is_local: bool = not NetworkManager.is_server() \
			and cmd.player_index == NetworkManager.get_local_player_index()
	var sq: SquadronInstance = _find_squadron_from_command(cmd)
	# Displacement move during Ship Phase — only reposition, skip
	# activation tracking and turn advancement.
	if current_game_state \
			and current_game_state.current_phase == Constants.GamePhase.SHIP:
		if sq and not is_local:
			EventBus.squadron_repositioned_remotely.emit(sq)
		return
	if sq:
		sq.activated_this_round = true
		if not is_local:
			EventBus.squadron_repositioned_remotely.emit(sq)
	_activating_squadron = null
	_finish_remote_squadron_activation()


## Phase I6b-4d: Mirror commit_displacement — snap each repositioned
## squadron token to the authoritative position written by
## [CommitDisplacementCommand.execute].  Replaces the per-squadron
## [code]move_squadron[/code] mirror that the displacement modal used
## to submit one-by-one.  Idempotent on the controller peer (tokens
## are already at their final position from the modal drag).
func _handle_remote_commit_displacement(cmd: GameCommand) -> void:
	var raw: Variant = cmd.payload.get("placements", [])
	if not (raw is Array):
		return
	for entry: Variant in raw as Array:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry as Dictionary
		var sq_owner: int = int(d.get("owner", -1))
		var sq_idx: int = int(d.get("squadron_index", -1))
		if not current_game_state:
			return
		var sq: SquadronInstance = current_game_state.get_squadron(
				sq_owner, sq_idx)
		if sq:
			EventBus.squadron_repositioned_remotely.emit(sq)


## B10: Mirror end_activation side effects on remote peer.
func _handle_remote_end_activation(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		EventBus.command_dials_changed.emit(ship)
		_log.info("Ship activation ended: %s" % ship.data_key)
	_activating_ship = null
	if NetworkManager.is_server():
		_advance_ship_phase_turn()
	else:
		_advance_ship_phase_turn_client()


## B11: Mirror activate_squadron side effects on remote peer.
## If a previous squadron was being activated (i.e. skip — no move_squadron
## was sent), finish that activation first.  Only applies to the REMOTE
## player's commands; the local player's activations are tracked via
## the optimistic set in [method activate_squadron].
func _handle_remote_activate_squadron(cmd: GameCommand) -> void:
	var is_local: bool = not NetworkManager.is_server() \
			and cmd.player_index == NetworkManager.get_local_player_index()
	# Remote player: a new activate_squadron means the previous one
	# finished (skip path — no move_squadron was sent).
	if not is_local and _activating_squadron != null:
		_activating_squadron.activated_this_round = true
		_activating_squadron = null
		_finish_remote_squadron_activation()
	var sq: SquadronInstance = _find_squadron_from_command(cmd)
	if sq:
		_activating_squadron = sq


## Shared helper: increments remote squadron activation counter and
## advances the squadron-phase turn when the per-turn limit is reached.
func _finish_remote_squadron_activation() -> void:
	if current_game_state == null:
		return
	if current_game_state.current_phase != Constants.GamePhase.SQUADRON:
		return
	_squadrons_activated_this_turn += 1
	if _squadrons_activated_this_turn >= Constants.SQUADRONS_PER_ACTIVATION \
			or not _has_unactivated_squadrons(active_player):
		if NetworkManager.is_server():
			_advance_squadron_phase_turn()
		else:
			_advance_squadron_phase_turn_client()


## B13: Mirror spend_token side effects on client.
func _handle_remote_spend_token(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		EventBus.command_tokens_changed.emit(ship)


## B14: Mirror discard_token side effects on client.
func _handle_remote_discard_token(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		var token_type: int = cmd.payload.get("token_type", -1)
		EventBus.command_tokens_changed.emit(ship)
		EventBus.token_discarded.emit(ship, token_type)


## B16: Mirror spend_defense_token side effects on client.
func _handle_remote_spend_defense_token(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship:
		EventBus.ship_defense_token_changed.emit(ship)


## Phase I6b-3 R4 follow-up: refresh the defender's shield pip overlay
## on the passive peer when a redirect zone is committed.
## [SelectRedirectZoneCommand.execute] reduces shields on both peers
## (commands are replicated), but only the attacker peer's
## [AttackExecutor.apply_defender_redirect_zone] emits the
## [signal EventBus.ship_shields_changed] that the ship token listens
## to.  Mirror the emit here so the defender peer's VSD pip updates.
func _handle_remote_select_redirect_zone(
		cmd: GameCommand, result: Dictionary) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	var zone_name: String = String(result.get("zone_name", ""))
	if zone_name == "":
		return
	EventBus.ship_shields_changed.emit(
			ship, zone_name, int(result.get("new_shields", 0)))


## B19: Mirror resolve_damage side effects on client.
func _handle_remote_resolve_damage(
		cmd: GameCommand, result: Dictionary) -> void:
	var target_type: String = result.get("target_type", "ship")
	if target_type == "squadron":
		var sq: SquadronInstance = _find_squadron_from_command(cmd)
		if sq and result.get("destroyed", false):
			EventBus.squadron_destroyed.emit(sq)
		return
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	EventBus.ship_defense_token_changed.emit(ship)
	# Phase I6b-3 R2 follow-up: refresh shield/hull visuals on the
	# client peer.  ResolveDamageCommand.execute() mutated the
	# authoritative GameState on both peers, but only the host's
	# AttackExecutor emits the ship_shields_changed / ship_hull_changed
	# signals that ship_token listens to.  Mirror those signals here so
	# the defender's shield pips and hull readout update on the client.
	if int(result.get("shield_absorbed", 0)) > 0:
		var hull_zone: String = String(result.get("hull_zone", ""))
		if hull_zone != "":
			EventBus.ship_shields_changed.emit(ship, hull_zone,
					int(result.get("new_shields", 0)))
	if int(result.get("cards_added", 0)) > 0 and ship.ship_data:
		var new_hull: int = ship.ship_data.hull \
				- ship.get_total_damage()
		EventBus.ship_hull_changed.emit(ship, new_hull)
		# Phase I6b-3 R2 follow-up: refresh the defender's damage-card
		# column on the passive peer.  ResolveDamageCommand.execute()
		# already added the cards to the ship's faceup/facedown stacks
		# on this peer (commands are replicated and executed on both
		# sides), but only the attacker's AttackExecutor emits
		# `damage_card_dealt` per card.  A single null-card emit is
		# enough to trigger ShipCardPanel._refresh_damage_for_ship()
		# which reads the full stacks off the ShipInstance.
		EventBus.damage_card_dealt.emit(ship, null, false)
		# Phase I6b-3 R2 follow-up: also surface the
		# DamageSummaryOverlay close-up on the passive peer.  Walk the
		# command's payload to figure out which dealt cards were
		# faceup, deserialize them (so the overlay can pull
		# effect_id / title), and emit
		# [signal EventBus.damage_summary_requested] with the same
		# shape the attacker peer's AttackExecutor uses.
		var faceup_cards: Array[DamageCard] = []
		var facedown_count: int = 0
		var cards_payload: Array = cmd.payload.get(
				"damage_cards", []) as Array
		for entry: Variant in cards_payload:
			if not (entry is Dictionary):
				continue
			var card_dict: Dictionary = entry as Dictionary
			if bool(card_dict.get("is_faceup", false)):
				faceup_cards.append(DamageCard.deserialize(card_dict))
			else:
				facedown_count += 1
		EventBus.damage_summary_requested.emit(
				ship, faceup_cards, facedown_count,
				ship.ship_data.ship_name)
	if result.get("destroyed", false):
		EventBus.ship_destroyed.emit(ship)
	_check_elimination()


## B20–B21: Mirror overlap/persistent damage side effects on client.
func _handle_remote_damage_event(
		cmd: GameCommand, result: Dictionary) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	if result.get("destroyed", false):
		EventBus.ship_destroyed.emit(ship)
	_check_elimination()


## B22: Mirror repair_action side effects on client.
func _handle_remote_repair_action(cmd: GameCommand) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	var action: String = cmd.payload.get("action_type", "")
	match action:
		"move_shields", "recover_shields":
			EventBus.ship_defense_token_changed.emit(ship)
		"repair_hull":
			EventBus.command_dials_changed.emit(ship)


## B23: Mirror resolve_immediate_effect side effects on client.
func _handle_remote_immediate_effect(cmd: GameCommand,
		result: Dictionary) -> void:
	var ship: ShipInstance = _find_ship_from_command(cmd)
	if ship == null:
		return
	# After [ResolveImmediateEffectCommand.execute] the card has been
	# flipped and moved into [code]ship.facedown_damage[/code].  Locate
	# it (most-recently-added match) so [ImmediateEffectSignals] can
	# fire the correct [code]damage_card_flipped[/code] visual on the
	# passive peer — closing the gap that left auto-resolve cards
	# (Structural Damage, Projector Misaligned, Comm Noise, …) without
	# a card-column refresh on the non-originating peer.
	var effect_id: String = cmd.payload.get("effect_id", "") as String
	var card: DamageCard = null
	for i: int in range(ship.facedown_damage.size() - 1, -1, -1):
		var c: DamageCard = ship.facedown_damage[i]
		if c != null and c.effect_id == effect_id:
			card = c
			break
	# Use the **broadcast result** verbatim — it is the authoritative
	# return value of [ResolveImmediateEffectCommand.execute] from the
	# server, so [code]action[/code] / [code]new_speed[/code] /
	# [code]shield_changes[/code] / [code]zone[/code] etc. are exactly
	# the values the originator's [_emit_immediate_signals] uses.
	if card != null:
		ImmediateEffectSignals.emit(card, ship, result)
	# Always refresh dial / token state — covers life_support_failure
	# and any other side-channel mutations.
	EventBus.command_dials_changed.emit(ship)
	EventBus.ship_defense_token_changed.emit(ship)


## B24: Mirror status_phase_cleanup side effects on client.
func _handle_remote_status_cleanup() -> void:
	for i: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = current_game_state.get_player_state(i)
		if ps == null:
			continue
		for s: Variant in ps.ships:
			if s is ShipInstance:
				var si: ShipInstance = s as ShipInstance
				if si.is_destroyed():
					continue
				EventBus.ship_defense_token_changed.emit(si)
				if si.command_dial_stack != null:
					EventBus.command_dials_changed.emit(si)


## B25: Mirror destroy_unit side effects on client.
func _handle_remote_destroy_unit(
		cmd: GameCommand, result: Dictionary) -> void:
	var unit_type: String = cmd.payload.get("unit_type", "ship")
	if unit_type == "squadron":
		var sq: SquadronInstance = _find_squadron_from_command(cmd)
		if sq:
			EventBus.squadron_destroyed.emit(sq)
	else:
		var ship: ShipInstance = _find_ship_from_command(cmd)
		if ship:
			EventBus.ship_destroyed.emit(ship)
	_check_elimination()


## Client-side ship-phase turn advancement.
## Determines the next active player locally (same logic as host) and sets
## the tracking variable.  Does NOT call advance_phase — that comes from
## the server's AdvancePhaseCommand broadcast.
func _advance_ship_phase_turn_client() -> void:
	var next: int = 1 - active_player
	var next_has: bool = _has_unactivated_ships(next)
	var curr_has: bool = _has_unactivated_ships(active_player)
	if not next_has and not curr_has:
		return # Server will broadcast advance_phase.
	if next_has:
		_set_active_player(next)
	elif curr_has:
		_set_active_player(active_player)


## Client-side squadron-phase turn advance.
## Same as _advance_squadron_phase_turn but without calling advance_phase
## (server handles that).
func _advance_squadron_phase_turn_client() -> void:
	var next: int = 1 - active_player
	var next_has: bool = _has_unactivated_squadrons(next)
	var curr_has: bool = _has_unactivated_squadrons(active_player)
	if not next_has and not curr_has:
		return # Server will broadcast advance_phase.
	if next_has:
		_squadrons_activated_this_turn = 0
		_set_active_player(next)
	elif curr_has:
		_squadrons_activated_this_turn = 0
		_set_active_player(active_player)


## Client-side squadron-phase begin.
## Same as _begin_squadron_phase but without auto-skip advance_phase
## (server handles that).
func _begin_squadron_phase_client() -> void:
	if not current_game_state:
		return
	if current_game_state.effect_registry.get_effect_count() == 0:
		EffectFactory.register_squadron_keywords(
				current_game_state,
				current_game_state.initiative_player)
	_squadrons_activated_this_turn = 0
	_activating_squadron = null
	var init: int = current_game_state.initiative_player
	_set_active_player(init)


## Looks up the [ShipInstance] referenced by a command's payload.
func _find_ship_from_command(cmd: GameCommand) -> ShipInstance:
	if not current_game_state:
		return null
	var ship_index: int = cmd.payload.get("ship_index", -1)
	# Damage / repair commands carry the ship's owner in the payload
	# (`owner_player`) because the author may be a different player —
	# e.g. ResolveDamageCommand is authored by the attacker but mutates
	# the defender's ship.  Prefer the payload owner when present so
	# the canonical ShipInstance reference matches the one bound to
	# the on-board ship_token (which is required for
	# ship_token._on_state_changed equality checks to fire).
	var owner_index: int = int(
			cmd.payload.get("owner_player", cmd.player_index))
	var ps: PlayerState = current_game_state.get_player_state(owner_index)
	if ps == null or ship_index < 0 or ship_index >= ps.ships.size():
		return null
	return ps.ships[ship_index] as ShipInstance


## Looks up the [SquadronInstance] referenced by a command's payload.
func _find_squadron_from_command(cmd: GameCommand) -> SquadronInstance:
	if not current_game_state:
		return null
	var sq_index: int = cmd.payload.get("squadron_index", -1)
	var ps: PlayerState = current_game_state.get_player_state(
			cmd.player_index)
	if ps == null or sq_index < 0 or sq_index >= ps.squadrons.size():
		return null
	return ps.squadrons[sq_index] as SquadronInstance

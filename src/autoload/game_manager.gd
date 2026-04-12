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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_PREDELETE:
		# Release the GameState RefCounted chain so scripts are freed cleanly
		# at exit (avoids "resources still in use" warnings).
		current_game_state = null
		_activating_ship = null
		_activating_squadron = null


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
	_start_round()


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
	var result: Dictionary = CommandProcessor.submit(cmd)
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
		end_game("round_6")
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
	var result: Dictionary = CommandProcessor.submit(assign_cmd)
	if not result.get("success", false):
		_log.warn("assign_dials failed for '%s'" % [
				ship.ship_data.ship_name if ship.ship_data else "?"])
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
	var result: Dictionary = CommandProcessor.submit(cmd)
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
	var result: Dictionary = CommandProcessor.submit(cmd)
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
	var result: Dictionary = CommandProcessor.submit(cmd)
	if not result.is_empty():
		EventBus.command_tokens_changed.emit(ship)


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
	var result: Dictionary = CommandProcessor.submit(cmd)
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
	return CommandProcessor.submit(cmd)


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
	return CommandProcessor.submit(cmd)


## Submits a [RollDiceCommand] for deterministic dice rolling.
## Returns the command result containing [code]"dice_results"[/code].
## [param player] — the attacking player index.
## [param dice_pool] — Dictionary mapping colour string to count.
func submit_roll_dice(player: int,
		dice_pool: Dictionary) -> Dictionary:
	if not current_game_state:
		return {}
	var cmd := RollDiceCommand.new(player, {"dice_pool": dice_pool})
	return CommandProcessor.submit(cmd)


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
	return CommandProcessor.submit(cmd)


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
	return CommandProcessor.submit(cmd)


## Submits a [SkipAttackCommand] for replay recording.
## [param player] — the active player index.
## [param reason] — skip reason string.
func submit_skip_attack(player: int, reason: String = "voluntary") -> Dictionary:
	if not current_game_state:
		return {}
	var cmd := SkipAttackCommand.new(player, {"reason": reason})
	return CommandProcessor.submit(cmd)


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
			var result: Dictionary = CommandProcessor.submit(cmd)
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
	var result: Dictionary = CommandProcessor.submit(cmd)
	if result.is_empty():
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
				if si.is_destroyed():
					continue
				# STATUS_READY_TOKENS hook — Compartment Fire blocks readying.
				# Rules Reference: "Compartment Fire" card text.
				if not _is_token_ready_blocked(si):
					si.ready_defense_tokens()
					EventBus.ship_defense_token_changed.emit(si)
				else:
					_log.info("Token readying blocked for %s (damage effect)."
							% si.data_key)
				si.reset_activation()
				# Clear spent dial marker so it doesn't persist into the
				# next round's card panel display.
				if si.command_dial_stack != null:
					si.command_dial_stack.clear_spent_history()
					EventBus.command_dials_changed.emit(si)
		for sq: Variant in ps.squadrons:
			if sq is SquadronInstance:
				var sqi: SquadronInstance = sq as SquadronInstance
				if sqi.is_destroyed():
					continue
				sqi.ready_defense_tokens()
				sqi.reset_activation()
	# Rules Reference: "Initiative", p.8 — "The first player retains
	# initiative for the entire game." Initiative does NOT change.
	_log.info("Status Phase: cleanup complete. Initiative stays with player %d." % [
			current_game_state.initiative_player])


## Returns true if the STATUS_READY_TOKENS hook cancels readying
## for [param ship] (e.g. Compartment Fire).
## Rules Reference: RRG "Damage Cards", p.4; "Compartment Fire".
func _is_token_ready_blocked(ship: ShipInstance) -> bool:
	if not current_game_state or not current_game_state.effect_registry:
		return false
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx = current_game_state.effect_registry.resolve_hook(
			&"STATUS_READY_TOKENS", ctx)
	return ctx.cancelled


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
## If both fleets lost their last ship in the same attack, that's mutual
## destruction — scored by points (RRG p.21).
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
	# --- Destruction cleanup (DM-030) ---
	# 1. Unregister all persistent effects owned by this ship.
	if current_game_state and current_game_state.effect_registry and si:
		current_game_state.effect_registry.unregister_by_owner(si)
	# 2. Return all damage cards to the discard pile.
	if si:
		var cards: Array = si.clear_all_damage_cards()
		if current_game_state and current_game_state.damage_deck:
			for card: Variant in cards:
				current_game_state.damage_deck.discard(card)


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

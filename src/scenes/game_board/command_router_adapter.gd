## CommandRouterAdapter
##
## Single subscriber to [signal CommandProcessor.command_executed] that
## routes each applied command + result into the appropriate controllers
## and projects the resulting [UIProjector.UIIntent] onto the HUD.
##
## Responsibilities (formerly inline on `game_board.gd._on_command_executed_project_ui`):
##   1. Forward the command/result to [AttackPanelController.react_to_command]
##      so the attacker can route defender responses.
##   2. Forward `debug_deal_damage` commands to [DebugController.react_to_command].
##   3. Compute the local viewer ([NetworkManager] / [GameManager]) and
##      run [UIProjector.project] so the HUD status text follows the
##      authoritative [GameState.interaction_flow] field.
##   4. (Network-only) Drive the squadron-displacement modal lifecycle
##      from [StartDisplacementCommand] / [CommitDisplacementCommand].
##   5. Sync the read-only [AttackPanelMirror] from the current flow.
##   6. Drive the activation modal lifecycle (open / close / interactivity)
##      and step sync via [ShipActivationController].
##
## Extracted from [game_board.gd](game_board.gd) as part of refactoring
## phase K12.
class_name CommandRouterAdapter
extends Node

# ---------------------------------------------------------------------------
# Injected dependencies
# ---------------------------------------------------------------------------

var _panel_mgr: UIPanelManager = null
var _attack_panel_controller: AttackPanelController = null
var _debug_controller: DebugController = null
var _ship_activation_controller: ShipActivationController = null
var _displacement_controller: DisplacementController = null
var _activation_ctx: ActivationContext = null

## Callable returning the ShipToken bound to a ShipInstance (or null).
var _find_ship_token_fn: Callable

## Callable returning the SquadronToken bound to a SquadronInstance (or null).
var _find_squadron_token_fn: Callable

## Logger.
var _log: GameLogger = GameLogger.new("CommandRouterAdapter")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores controller / context references and connects to
## [signal CommandProcessor.command_executed].
##
## All controllers are required.  Token-finder callables are required
## for the network-only displacement modal lifecycle.
func initialize(
		panel_mgr: UIPanelManager,
		attack_panel_controller: AttackPanelController,
		debug_controller: DebugController,
		ship_activation_controller: ShipActivationController,
		displacement_controller: DisplacementController,
		activation_ctx: ActivationContext,
		find_ship_token_fn: Callable,
		find_squadron_token_fn: Callable) -> void:
	_panel_mgr = panel_mgr
	_attack_panel_controller = attack_panel_controller
	_debug_controller = debug_controller
	_ship_activation_controller = ship_activation_controller
	_displacement_controller = displacement_controller
	_activation_ctx = activation_ctx
	_find_ship_token_fn = find_ship_token_fn
	_find_squadron_token_fn = find_squadron_token_fn

	CommandProcessor.command_executed.connect(_on_command_executed)


# ---------------------------------------------------------------------------
# Command routing
# ---------------------------------------------------------------------------

## Phase I4 / I6a — sole driver of HUD status, activation-step sync,
## modal lifecycle and modal interactivity in network mode.  Reads the
## authoritative [GameState.interaction_flow] domain field after every
## applied command.
func _on_command_executed(_command: GameCommand,
		_result: Dictionary) -> void:
	if _panel_mgr == null:
		return
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	_route_to_controllers(_command, _result)
	var local: int = _local_viewer()
	_project_hud_status(gs, local)
	# Phase K allow-list: session-mode dispatcher (plan §3.1a, §3.1d).
	# Network-only modal lifecycle.  Hot-seat opens the activation modal
	# via the local activation flow itself; running this path there would
	# double-open.  Phase I migrated network to projection-driven modal
	# lifecycle but left hot-seat on direct callbacks; converging the
	# two is a Phase L candidate.
	if PlayMode.is_network():
		_drive_network_displacement_modal(_command)
	_sync_attack_panel_mirror(gs, local)
	_drive_activation_modal(gs)


## Routes the command to controllers that own command-type-specific
## reactions (attack pipeline, debug damage card chain).
func _route_to_controllers(cmd: GameCommand, result: Dictionary) -> void:
	# Phase K9: attacker-side defender-response routing
	# (commit_defense / select_evade_die / select_redirect_zone /
	# redirect_done / resolve_immediate_effect) lives on
	# [AttackPanelController].
	if _attack_panel_controller != null:
		_attack_panel_controller.react_to_command(cmd, result)
	# DBG-050: when a [DebugDealDamageCommand] is broadcast / executed,
	# emit the visual signals on every peer (so hot-seat, host, and
	# client all refresh the [ShipCardPanel] / hull display) and chain
	# the immediate-effect resolution on the originating peer only.
	# Owned by [DebugController] since Phase K10.
	if cmd != null and _debug_controller != null \
			and cmd.command_type == "debug_deal_damage":
		_debug_controller.react_to_command(cmd, result)


## Projects the current authoritative [GameState.interaction_flow] into
## a [UIProjector.UIIntent] and applies the HUD status text.
func _project_hud_status(gs: GameState, local: int) -> void:
	var intent: UIProjector.UIIntent = UIProjector.project(gs, local)
	if not intent.hud_status_text.is_empty():
		_panel_mgr.set_network_status_text(intent.hud_status_text)


## Network-only — drives the squadron-displacement modal lifecycle in
## response to [StartDisplacementCommand] / [CommitDisplacementCommand].
func _drive_network_displacement_modal(cmd: GameCommand) -> void:
	if cmd == null:
		return
	if cmd.command_type == "start_displacement":
		_open_displacement_modal_from_command(cmd)
	elif cmd.command_type == "commit_displacement":
		# Phase I6b-4d: deferred so the host's follow-up
		# [code]advance_activation_step[/code] submitted inside
		# [_show_end_activation_after_maneuver] broadcasts *after* the
		# outer [code]commit_displacement[/code] broadcast.
		call_deferred("_resume_after_remote_displacement")


## Calls [method AttackPanelController.sync_mirror_from_flow] BEFORE the
## "no flow" early-return below — read-only mirrors must close when the
## flow ends, and the helper is a no-op when already in the right state.
func _sync_attack_panel_mirror(gs: GameState, local: int) -> void:
	if _attack_panel_controller == null:
		return
	_attack_panel_controller.sync_mirror_from_flow(gs.interaction_flow, local)


## Drives the ship-activation modal: step sync, lifecycle (open / close),
## and interactivity refresh.  No-op when no flow is active.
func _drive_activation_modal(gs: GameState) -> void:
	var flow: InteractionFlow = gs.interaction_flow
	if flow == null or flow.flow_type == Constants.InteractionFlow.NONE:
		return
	_ship_activation_controller.sync_activation_step_from_flow(flow)
	# Modal lifecycle: open when activation starts, close when it ends.
	if flow.flow_type == Constants.InteractionFlow.SHIP_ACTIVATION:
		match flow.step_id:
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN:
				if _ship_activation_controller.is_command_squadron_modal_active():
					_ship_activation_controller.ensure_activation_modal_hidden_for_squadron_command()
				else:
					_ship_activation_controller.open_modal_from_interaction_state()
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT:
				_ship_activation_controller.close_modal_from_interaction_state()
	_ship_activation_controller.update_activation_modal_interactivity()


# ---------------------------------------------------------------------------
# Network displacement helpers (OV-002 fix, Phase I6b-4c-2)
# ---------------------------------------------------------------------------

## Opens the squadron-displacement modal on the non-moving (opposing)
## peer when [StartDisplacementCommand] broadcasts.  The maneuvering
## peer skips this branch because its [code]_can_act_as(controller)[/code]
## check fails — the controller is its opponent.
## Rules Reference: RRG "Overlapping", p.8 — the player who is NOT
## moving the ship places the overlapped squadrons.
func _open_displacement_modal_from_command(cmd: GameCommand) -> void:
	var payload: Dictionary = cmd.payload
	var controller: int = int(payload.get("controller_player", -1))
	if controller < 0:
		return
	if not _can_act_as(controller):
		return
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var ship_index: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = gs.get_ship(cmd.player_index, ship_index)
	if ship == null:
		_log.warn("Displacement modal: ship not found.")
		return
	var ship_token: ShipToken = _find_ship_token_fn.call(ship) as ShipToken
	if ship_token == null:
		_log.warn("Displacement modal: ship token not found.")
		return
	var ship_base: ShipBase = ShipBase.new(
			ship_token.get_ship_size(),
			Transform2D(ship_token.global_rotation,
					ship_token.global_position))
	var displaced_tokens: Array[SquadronToken] = _resolve_displaced_squadron_tokens(
			gs, payload.get("displaced_squadrons", []) as Array)
	if displaced_tokens.is_empty():
		_log.warn("Displacement modal: no squadron tokens resolved.")
		return
	_displacement_controller.start(displaced_tokens, ship_base)


## Resolves the list of [SquadronToken]s referenced by the
## [code]displaced_squadrons[/code] payload entries.
func _resolve_displaced_squadron_tokens(
		gs: GameState, entries: Array) -> Array[SquadronToken]:
	var displaced_tokens: Array[SquadronToken] = []
	for raw: Variant in entries:
		var entry: Dictionary = raw as Dictionary
		var sq_owner: int = int(entry.get("owner", -1))
		var sq_idx: int = int(entry.get("squadron_index", -1))
		var inst: SquadronInstance = gs.get_squadron(sq_owner, sq_idx)
		if inst == null:
			continue
		var token: SquadronToken = _find_squadron_token_fn.call(inst) as SquadronToken
		if token != null:
			displaced_tokens.append(token)
	return displaced_tokens


## Triggered on every peer when [CommitDisplacementCommand] broadcasts.
## On the maneuvering peer (active player), runs the post-maneuver
## resume logic that the legacy [signal displacement_completed]
## connection used to fire — but only after the controller peer has
## finished placement.
func _resume_after_remote_displacement() -> void:
	if _local_viewer() != GameManager.get_active_player():
		return
	if _activation_ctx == null \
			or _activation_ctx.ship_activation_state == null:
		return
	_ship_activation_controller.show_end_activation_after_maneuver()


# ---------------------------------------------------------------------------
# Local viewer / actor helpers (Phase I6e)
# ---------------------------------------------------------------------------

## Returns the player index whose perspective is shown locally on this
## peer.  In network mode this is [code]NetworkManager.get_local_player_index()[/code].
## In hot-seat both players share one screen, so the local viewer
## follows [code]GameManager.get_active_player()[/code].
func _local_viewer() -> int:
	var idx: int = NetworkManager.get_local_player_index()
	if idx < 0:
		return GameManager.get_active_player()
	return idx


## Returns whether this peer is responsible for executing the actions of
## [param player_index].  In hot-seat always true.
func _can_act_as(player_index: int) -> bool:
	var idx: int = NetworkManager.get_local_player_index()
	return idx < 0 or idx == player_index

## ModalRouter
##
## Single projection-driven subscriber to [signal CommandProcessor.command_executed].
## It reads [member GameState.interaction_flow] after each applied command,
## builds a [UIProjector.UIIntent], and dispatches the resulting HUD and
## modal lifecycle updates to the focused game-board controllers.
##
## Extracted from [CommandRouterAdapter] in Phase L1 so the adapter can remain
## the composition root while modal lifecycle routing becomes one controller.
class_name ModalRouter
extends Node

const ECM_READY_COST_MODAL_SCRIPT: GDScript = preload(
		"res://src/ui/upgrades/ecm_ready_cost_modal.gd")

var _panel_mgr: UIPanelManager = null
var _attack_panel_controller: AttackPanelController = null
var _ship_activation_controller: ShipActivationController = null
var _squadron_phase_controller: SquadronPhaseController = null
var _displacement_controller: DisplacementController = null
var _tarkin_choice_modal: TarkinChoiceModal = null
var _ecm_ready_cost_modal: Variant = null
var _activation_ctx: ActivationContext = null
var _find_ship_token_fn: Callable
var _find_squadron_token_fn: Callable
var _command_reaction_fn: Callable
var _timing_window_submit_fn: Callable
var _log: GameLogger = GameLogger.new("ModalRouter")


## Stores controller references and connects to the command-executed signal.
## [param command_reaction_fn] is called before projection for command-type
## reactions that are not modal lifecycle concerns, such as debug visuals and
## attacker-side defender response routing.
func initialize(
		panel_mgr: UIPanelManager,
	attack_panel_controller: AttackPanelController,
	ship_activation_controller: ShipActivationController,
	squadron_phase_controller: SquadronPhaseController,
	displacement_controller: DisplacementController,
		activation_ctx: ActivationContext,
		find_ship_token_fn: Callable,
		find_squadron_token_fn: Callable,
		command_reaction_fn: Callable = Callable(),
		timing_window_submit_fn: Callable = Callable()) -> void:
	_panel_mgr = panel_mgr
	_attack_panel_controller = attack_panel_controller
	_ship_activation_controller = ship_activation_controller
	_squadron_phase_controller = squadron_phase_controller
	_displacement_controller = displacement_controller
	_activation_ctx = activation_ctx
	_find_ship_token_fn = find_ship_token_fn
	_find_squadron_token_fn = find_squadron_token_fn
	_command_reaction_fn = command_reaction_fn
	_timing_window_submit_fn = timing_window_submit_fn
	_connect_command_signal()


## Disconnects from global signals when this router leaves the tree.
func _exit_tree() -> void:
	if CommandProcessor.command_executed.is_connected(_on_command_executed):
		CommandProcessor.command_executed.disconnect(_on_command_executed)
	if CommandProcessor.command_rejected.is_connected(_on_command_rejected):
		CommandProcessor.command_rejected.disconnect(_on_command_rejected)
	if GameManager.network_command_rejected.is_connected(
			_on_network_command_rejected):
		GameManager.network_command_rejected.disconnect(
				_on_network_command_rejected)


## Applies controller reactions and projection-driven modal routing for one
## executed command. Exposed for unit tests; live games use the signal path.
func route_command_result(command: GameCommand, result: Dictionary) -> void:
	if _panel_mgr == null:
		return
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	_dismiss_activation_before_attack_reaction(game_state)
	_route_to_command_reactions(command, result)
	var local: int = _local_viewer(game_state)
	var intent: UIProjector.UIIntent = UIProjector.project(game_state, local)
	_apply_hud_intent(intent)
	_dispatch_modal_intent(intent, game_state, command)


func _connect_command_signal() -> void:
	if not CommandProcessor.command_executed.is_connected(_on_command_executed):
		CommandProcessor.command_executed.connect(_on_command_executed)
	if not CommandProcessor.command_rejected.is_connected(_on_command_rejected):
		CommandProcessor.command_rejected.connect(_on_command_rejected)
	if not GameManager.network_command_rejected.is_connected(
			_on_network_command_rejected):
		GameManager.network_command_rejected.connect(
				_on_network_command_rejected)


func _on_command_executed(command: GameCommand, result: Dictionary) -> void:
	route_command_result(command, result)


func _on_command_rejected(command: GameCommand, _reason: String) -> void:
	_refresh_rejected_attack_modify_projection(command)


func _on_network_command_rejected(
		command: GameCommand, _reason: String) -> void:
	_refresh_rejected_attack_modify_projection(command)


func _refresh_rejected_attack_modify_projection(command: GameCommand) -> void:
	if command == null or command.command_type not in [
			"use_concentrate_fire_token_reroll",
			"decline_concentrate_fire_token_reroll",
			"use_h9",
			"decline_h9",
	]:
		return
	var game_state: GameState = GameManager.current_game_state
	if _panel_mgr == null or game_state == null:
		return
	var intent: UIProjector.UIIntent = UIProjector.project(
			game_state, _local_viewer(game_state))
	_apply_hud_intent(intent)
	_dispatch_modal_intent(intent, game_state, command)


func _route_to_command_reactions(command: GameCommand, result: Dictionary) -> void:
	if not _command_reaction_fn.is_valid():
		return
	_command_reaction_fn.call(command, result)


func _dismiss_activation_before_attack_reaction(game_state: GameState) -> void:
	if _ship_activation_controller == null:
		return
	var attack: CurrentAttackState = game_state.current_attack_state
	var flow: InteractionFlow = game_state.interaction_flow
	if (attack != null and attack.active) \
			or (flow != null \
					and flow.flow_type == Constants.InteractionFlow.ATTACK):
		_ship_activation_controller.dismiss_activation_modal_for_attack()


func _apply_hud_intent(intent: UIProjector.UIIntent) -> void:
	if intent.hud_status_text.is_empty():
		return
	_panel_mgr.set_network_status_text(intent.hud_status_text)


func _dispatch_modal_intent(intent: UIProjector.UIIntent,
		game_state: GameState, command: GameCommand) -> void:
	_drive_tarkin_choice_modal(intent)
	_drive_ecm_ready_cost_modal(intent)
	_drive_displacement_modal(intent, command)
	_drive_activation_modal(intent, game_state.interaction_flow, command)
	_drive_squadron_phase_activation(intent, game_state)
	_sync_attack_panel_mirror(game_state, intent.attack_dice_results)
	_drive_current_attack_dice(intent.attack_dice_results)
	_drive_timing_window_panel(intent.timing_window)
	_apply_activation_affordances(intent)


## Reprojects the existing Squadron Phase selection only from its canonical
## WAIT_FOR_SQUAD_SELECT result. It never selects a squadron or advances the
## phase; command and GameState ownership remain unchanged.
func _drive_squadron_phase_activation(intent: UIProjector.UIIntent,
		game_state: GameState) -> void:
	if _squadron_phase_controller == null or game_state == null:
		return
	if intent.flow_type != Constants.InteractionFlow.SQUADRON_ACTIVATION \
			or intent.step_id != Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT:
		return
	_squadron_phase_controller.restore_phase_selection_from_interaction_state(
			game_state)


func _drive_tarkin_choice_modal(intent: UIProjector.UIIntent) -> void:
	if intent.modal_kind != Constants.ModalKind.TARKIN_COMMAND_CHOICE:
		if _tarkin_choice_modal != null:
			_tarkin_choice_modal.close()
		return
	var modal: TarkinChoiceModal = _ensure_tarkin_choice_modal()
	modal.open_from_intent(intent)


func _ensure_tarkin_choice_modal() -> TarkinChoiceModal:
	if _tarkin_choice_modal != null:
		return _tarkin_choice_modal
	_tarkin_choice_modal = TarkinChoiceModal.new()
	_tarkin_choice_modal.name = "TarkinChoiceModal"
	_tarkin_choice_modal.choice_submitted.connect(_on_tarkin_choice_submitted)
	_tarkin_choice_modal.decline_submitted.connect(_on_tarkin_declined)
	var parent: Node = _panel_mgr.turn_management_layer \
			if _panel_mgr.turn_management_layer != null else _panel_mgr
	parent.add_child(_tarkin_choice_modal)
	_panel_mgr.register_resizable(
			_tarkin_choice_modal, &"centre_on_screen", true)
	return _tarkin_choice_modal


func _drive_ecm_ready_cost_modal(intent: UIProjector.UIIntent) -> void:
	if intent.modal_kind != Constants.ModalKind.STATUS_CLEANUP \
			or not _has_ecm_ready_cost_choices(intent):
		if _ecm_ready_cost_modal != null:
			_ecm_ready_cost_modal.close()
		return
	var modal: Variant = _ensure_ecm_ready_cost_modal()
	modal.open_from_intent(intent, NetworkManager.get_local_player_index())


func _has_ecm_ready_cost_choices(intent: UIProjector.UIIntent) -> bool:
	var raw: Variant = intent.payload.get("ecm_ready_cost_choices",
			intent.payload.get("optional_status_rules", []))
	if raw is Array and not (raw as Array).is_empty():
		return _has_ready_ecm_choice(raw as Array)
	raw = intent.affordances.get("ecm_ready_cost_choices",
			intent.affordances.get("optional_status_rules", []))
	return raw is Array and _has_ready_ecm_choice(raw as Array)


func _has_ready_ecm_choice(raw_choices: Array) -> bool:
	for entry: Variant in raw_choices:
		if entry is Dictionary \
				and str((entry as Dictionary).get("accepted_command", "")) \
						== "ready_ecm":
			return true
	return false


func _ensure_ecm_ready_cost_modal() -> Variant:
	if _ecm_ready_cost_modal != null:
		return _ecm_ready_cost_modal
	_ecm_ready_cost_modal = ECM_READY_COST_MODAL_SCRIPT.new()
	_ecm_ready_cost_modal.name = "ECMReadyCostModal"
	_ecm_ready_cost_modal.ready_submitted.connect(_on_ecm_ready_submitted)
	_ecm_ready_cost_modal.decline_submitted.connect(_on_ecm_ready_declined)
	var parent: Node = _panel_mgr.turn_management_layer \
			if _panel_mgr.turn_management_layer != null else _panel_mgr
	parent.add_child(_ecm_ready_cost_modal)
	_panel_mgr.register_resizable(
			_ecm_ready_cost_modal, &"centre_on_screen", true)
	return _ecm_ready_cost_modal


func _drive_displacement_modal(intent: UIProjector.UIIntent,
		command: GameCommand) -> void:
	if command == null:
		return
	match command.command_type:
		"start_displacement":
			if _is_displacement_place_intent(intent):
				_open_displacement_modal_from_command(command)
		"commit_displacement":
			if _is_network_peer():
				call_deferred("_resume_after_remote_displacement")


func _is_displacement_place_intent(intent: UIProjector.UIIntent) -> bool:
	return intent.flow_type == Constants.InteractionFlow.SQUADRON_DISPLACEMENT \
			and intent.step_id == Constants.InteractionStep.DISPLACEMENT_PLACE \
			and intent.modal_kind == Constants.ModalKind.DISPLACEMENT


func _sync_attack_panel_mirror(
		game_state: GameState,
		attack_dice_results: Array[Dictionary]) -> void:
	if _attack_panel_controller == null:
		return
	if not _is_network_peer():
		_attack_panel_controller.close_mirror()
		return
	_attack_panel_controller.sync_mirror_from_flow(
			game_state.interaction_flow, attack_dice_results)


func _drive_current_attack_dice(
		attack_dice_results: Array[Dictionary]) -> void:
	if _attack_panel_controller == null:
		return
	_attack_panel_controller.sync_current_attack_dice_projection(
			attack_dice_results)


func _drive_timing_window_panel(timing_window: Dictionary) -> void:
	if _attack_panel_controller == null:
		return
	_attack_panel_controller.sync_timing_window_projection(
			timing_window, _timing_window_submit_fn)


func _drive_activation_modal(intent: UIProjector.UIIntent,
		flow: InteractionFlow, command: GameCommand) -> void:
	if _ship_activation_controller == null:
		return
	if intent.flow_type == Constants.InteractionFlow.ATTACK:
		return
	if flow == null or intent.flow_type == Constants.InteractionFlow.NONE:
		return
	_ship_activation_controller.sync_activation_step_from_flow(flow)
	if intent.flow_type == Constants.InteractionFlow.SHIP_ACTIVATION:
		_drive_ship_activation_lifecycle(intent, command)
	_ship_activation_controller.update_activation_modal_interactivity()


func _drive_ship_activation_lifecycle(intent: UIProjector.UIIntent,
		command: GameCommand) -> void:
	match intent.step_id:
		Constants.InteractionStep.WAIT_FOR_SHIP_SELECT:
			_ship_activation_controller.close_modal_from_interaction_state()
		Constants.InteractionStep.SQUADRON_STEP:
			if _is_squadron_command_projection_command(command):
				_ship_activation_controller.open_squadron_command_from_interaction_state()
		_:
			if intent.modal_kind == Constants.ModalKind.ACTIVATION \
					and (_is_activation_modal_open_command(command) \
							or _is_ship_skip_maneuver_projection(intent, command)):
				_open_activation_modal_from_intent()


func _apply_activation_affordances(intent: UIProjector.UIIntent) -> void:
	if _ship_activation_controller == null:
		return
	var show_button: bool = bool(
			intent.affordances.get("activation_sequence_button", false))
	_ship_activation_controller.apply_activation_sequence_affordance(show_button)


func _is_activation_modal_open_command(command: GameCommand) -> bool:
	if command == null:
		return false
	match command.command_type:
		"activate_ship", "convert_dial_to_token", "advance_activation_step":
			return true
	return false


## A completed commanded squadron returns to the already-open Squadron-command
## opportunity.  This is presentation recovery from ShipInstance's canonical
## OPEN disposition and committed count; it must not submit a second step
## transition.
func _is_squadron_command_projection_command(command: GameCommand) -> bool:
	return _is_activation_modal_open_command(command) \
			or (command != null \
					and command.command_type \
							== CompleteSquadronActivationCommand.TYPE)


func _is_ship_skip_maneuver_projection(intent: UIProjector.UIIntent,
		command: GameCommand) -> bool:
	if command == null or command.command_type != "skip_attack" \
			or intent.step_id != Constants.InteractionStep.MANEUVER_STEP:
		return false
	var ship: ShipInstance = GameManager.get_activating_ship()
	return ship != null and not ship.attack_step_active \
			and ship.maneuver_opportunity_disposition \
					== ShipInstance.ACTIVATION_DISPOSITION_OPEN


func _open_activation_modal_from_intent() -> void:
	if _ship_activation_controller.is_command_squadron_modal_active():
		_ship_activation_controller.ensure_activation_modal_hidden_for_squadron_command()
		return
	if _ship_activation_controller.is_activation_modal_open():
		return
	_ship_activation_controller.open_modal_from_interaction_state()


func _open_displacement_modal_from_command(command: GameCommand) -> void:
	if _displacement_controller == null:
		return
	var payload: Dictionary = command.payload
	var controller: int = int(payload.get("controller_player", -1))
	if controller < 0 or not _can_act_as(controller):
		return
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	var ship: ShipInstance = _resolve_displacing_ship(game_state, command)
	if ship == null:
		return
	var ship_token: ShipToken = _find_ship_token_fn.call(ship) as ShipToken
	if ship_token == null:
		_log.warn("Displacement modal: ship token not found.")
		return
	var ship_base: ShipBase = _ship_base_from_token(ship_token)
	var displaced_tokens: Array[SquadronToken] = _resolve_displaced_squadron_tokens(
			game_state, payload.get("displaced_squadrons", []) as Array)
	if displaced_tokens.is_empty():
		_log.warn("Displacement modal: no squadron tokens resolved.")
		return
	_displacement_controller.start(displaced_tokens, ship_base)


func _resolve_displacing_ship(game_state: GameState,
		command: GameCommand) -> ShipInstance:
	var ship_index: int = int(command.payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(command.player_index, ship_index)
	if ship == null:
		_log.warn("Displacement modal: ship not found.")
	return ship


func _ship_base_from_token(ship_token: ShipToken) -> ShipBase:
	return ShipBase.new(
			ship_token.get_ship_size(),
			Transform2D(ship_token.global_rotation,
					ship_token.global_position))


func _resolve_displaced_squadron_tokens(
		game_state: GameState, entries: Array) -> Array[SquadronToken]:
	var displaced_tokens: Array[SquadronToken] = []
	for raw: Variant in entries:
		var entry: Dictionary = raw as Dictionary
		var squadron_owner: int = int(entry.get("owner", -1))
		var squadron_index: int = int(entry.get("squadron_index", -1))
		var squadron: SquadronInstance = game_state.get_squadron(
				squadron_owner, squadron_index)
		if squadron == null:
			continue
		var token: SquadronToken = _find_squadron_token_fn.call(squadron) as SquadronToken
		if token != null:
			displaced_tokens.append(token)
	return displaced_tokens


func _resume_after_remote_displacement() -> void:
	if _local_viewer(GameManager.current_game_state) \
			!= GameManager.get_active_player():
		return
	if _activation_ctx == null \
			or _activation_ctx.ship_activation_state == null:
		return
	_ship_activation_controller.show_end_activation_after_maneuver()


func _local_viewer(game_state: GameState) -> int:
	var local_index: int = NetworkManager.get_local_player_index()
	if local_index < 0:
		if _is_tarkin_prompt(game_state):
			return game_state.interaction_flow.controller_player
		return GameManager.get_active_player()
	return local_index


func _is_tarkin_prompt(game_state: GameState) -> bool:
	if game_state == null or game_state.interaction_flow == null:
		return false
	var flow: InteractionFlow = game_state.interaction_flow
	return flow.flow_type == Constants.InteractionFlow.SHIP_ACTIVATION \
			and flow.step_id == Constants.InteractionStep.TARKIN_COMMAND_CHOICE


func _on_tarkin_choice_submitted(command: int) -> void:
	_submit_tarkin_choice({"command": command})


func _on_tarkin_declined() -> void:
	_submit_tarkin_choice({"declined": true})


func _submit_tarkin_choice(choice_payload: Dictionary) -> void:
	if _tarkin_choice_modal == null:
		return
	choice_payload["runtime_upgrade_id"] = \
			_tarkin_choice_modal.runtime_upgrade_id()
	var result: Dictionary = GameManager.get_command_submitter().submit(
			TarkinChoiceCommand.new(_tarkin_controller(), choice_payload))
	if result.is_empty() or bool(result.get("awaiting_remote", false)):
		return
	GameManager.project_tarkin_choice_result(result)


func _tarkin_controller() -> int:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null or game_state.interaction_flow == null:
		return -1
	return game_state.interaction_flow.controller_player


func _on_ecm_ready_submitted(runtime_upgrade_id: String,
		owner_player: int) -> void:
	if owner_player < 0:
		return
	GameManager.submit_ready_ecm_runtime(owner_player, runtime_upgrade_id)


func _on_ecm_ready_declined(runtime_upgrade_id: String,
		owner_player: int) -> void:
	if owner_player < 0:
		return
	GameManager.submit_decline_ecm_ready_runtime(owner_player,
			runtime_upgrade_id)


func _is_network_peer() -> bool:
	return NetworkManager.get_local_player_index() >= 0


func _can_act_as(player_index: int) -> bool:
	var local_index: int = NetworkManager.get_local_player_index()
	return local_index < 0 or local_index == player_index

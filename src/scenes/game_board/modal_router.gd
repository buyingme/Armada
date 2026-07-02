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


var _panel_mgr: UIPanelManager = null
var _attack_panel_controller: AttackPanelController = null
var _ship_activation_controller: ShipActivationController = null
var _displacement_controller: DisplacementController = null
var _tarkin_choice_modal: TarkinChoiceModal = null
var _activation_ctx: ActivationContext = null
var _find_ship_token_fn: Callable
var _find_squadron_token_fn: Callable
var _command_reaction_fn: Callable
var _log: GameLogger = GameLogger.new("ModalRouter")


## Stores controller references and connects to the command-executed signal.
## [param command_reaction_fn] is called before projection for command-type
## reactions that are not modal lifecycle concerns, such as debug visuals and
## attacker-side defender response routing.
func initialize(
		panel_mgr: UIPanelManager,
		attack_panel_controller: AttackPanelController,
		ship_activation_controller: ShipActivationController,
		displacement_controller: DisplacementController,
		activation_ctx: ActivationContext,
		find_ship_token_fn: Callable,
		find_squadron_token_fn: Callable,
		command_reaction_fn: Callable = Callable()) -> void:
	_panel_mgr = panel_mgr
	_attack_panel_controller = attack_panel_controller
	_ship_activation_controller = ship_activation_controller
	_displacement_controller = displacement_controller
	_activation_ctx = activation_ctx
	_find_ship_token_fn = find_ship_token_fn
	_find_squadron_token_fn = find_squadron_token_fn
	_command_reaction_fn = command_reaction_fn
	_connect_command_signal()


## Disconnects from global signals when this router leaves the tree.
func _exit_tree() -> void:
	if CommandProcessor.command_executed.is_connected(_on_command_executed):
		CommandProcessor.command_executed.disconnect(_on_command_executed)


## Applies controller reactions and projection-driven modal routing for one
## executed command. Exposed for unit tests; live games use the signal path.
func route_command_result(command: GameCommand, result: Dictionary) -> void:
	if _panel_mgr == null:
		return
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	_route_to_command_reactions(command, result)
	var local: int = _local_viewer(game_state)
	var intent: UIProjector.UIIntent = UIProjector.project(game_state, local)
	_apply_hud_intent(intent)
	_dispatch_modal_intent(intent, game_state, local, command)


func _connect_command_signal() -> void:
	if CommandProcessor.command_executed.is_connected(_on_command_executed):
		return
	CommandProcessor.command_executed.connect(_on_command_executed)


func _on_command_executed(command: GameCommand, result: Dictionary) -> void:
	route_command_result(command, result)


func _route_to_command_reactions(command: GameCommand, result: Dictionary) -> void:
	if not _command_reaction_fn.is_valid():
		return
	_command_reaction_fn.call(command, result)


func _apply_hud_intent(intent: UIProjector.UIIntent) -> void:
	if intent.hud_status_text.is_empty():
		return
	_panel_mgr.set_network_status_text(intent.hud_status_text)


func _dispatch_modal_intent(intent: UIProjector.UIIntent,
		game_state: GameState, local: int, command: GameCommand) -> void:
	_drive_tarkin_choice_modal(intent)
	_drive_displacement_modal(intent, command)
	_sync_attack_panel_mirror(game_state, local)
	_drive_activation_modal(intent, game_state.interaction_flow, command)
	_apply_activation_affordances(intent)


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


func _sync_attack_panel_mirror(game_state: GameState, local: int) -> void:
	if _attack_panel_controller == null:
		return
	if not _is_network_peer():
		_attack_panel_controller.close_mirror()
		return
	_attack_panel_controller.sync_mirror_from_flow(
			game_state.interaction_flow, local)


func _drive_activation_modal(intent: UIProjector.UIIntent,
		flow: InteractionFlow, command: GameCommand) -> void:
	if flow == null or intent.flow_type == Constants.InteractionFlow.NONE:
		return
	if _ship_activation_controller == null:
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
			if _is_activation_modal_open_command(command):
				_ship_activation_controller.open_squadron_command_from_interaction_state()
		_:
			if intent.modal_kind == Constants.ModalKind.ACTIVATION \
					and _is_activation_modal_open_command(command):
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
	GameManager.get_command_submitter().submit(
			TarkinChoiceCommand.new(_tarkin_controller(), choice_payload))


func _tarkin_controller() -> int:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null or game_state.interaction_flow == null:
		return -1
	return game_state.interaction_flow.controller_player


func _is_network_peer() -> bool:
	return NetworkManager.get_local_player_index() >= 0


func _can_act_as(player_index: int) -> bool:
	var local_index: int = NetworkManager.get_local_player_index()
	return local_index < 0 or local_index == player_index

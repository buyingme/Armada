## SetupPlacementController
##
## Owns setup-package obstacle placement, deployment dragging, and the local
## Start Round button on the board. All persistent mutations flow through
## setup placement commands so setup remains replay/network-safe.
class_name SetupPlacementController
extends Node


signal setup_turn_prompt_requested(player_index: int, player_label: String)


const COMPONENT_SHIP: String = "ship"
const COMPONENT_SQUADRON: String = "squadron"
const PREVIEW_ROTATE_SENSITIVITY: float = 2.0
const STATUS_ERROR: Color = Color(0.92, 0.48, 0.44)
const STATUS_OK: Color = Color(0.52, 0.88, 0.55)
const STATUS_TEXT: Color = Color(0.94, 0.94, 0.94)
const SETUP_AREA_OVERLAY_SCRIPT: GDScript = preload(
		"res://src/scenes/game_board/setup_area_overlay.gd")
const SETUP_OBSTACLE_MODAL_SCRIPT: GDScript = preload(
		"res://src/ui/setup/setup_placement_modal.gd")
const SETUP_OBSTACLE_TOKEN_SCRIPT: GDScript = preload(
		"res://src/scenes/game_board/setup_obstacle_token.gd")
const SETUP_OBSTACLE_VALIDATOR_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_obstacle_validator.gd")

var _board: Node2D = null
var _setup_overlay = null
var _token_container: Node2D = null
var _token_mover: TokenMover = null
var _setup_layer: CanvasLayer = null
var _modal = null
var _obstacle_tokens: Dictionary = {}
var _pending_obstacle_key: String = ""
var _preview_obstacle_token: Node2D = null
var _selected_token: Node2D = null
var _selected_origin: Vector2 = Vector2.ZERO
var _selected_rotation: float = 0.0
var _preview_is_moving: bool = false
var _preview_validation_error: String = ""
var _status_text: String = ""
var _status_colour: Color = STATUS_TEXT
var _last_obstacle_controller: int = -2


## Injects board dependencies and creates the setup overlay.
func initialize(board: Node2D,
		token_container: Node2D,
		token_mover: TokenMover) -> void:
	_board = board
	_token_container = token_container
	_token_mover = token_mover
	_build_ui()
	_connect_signals()
	refresh_from_state()


## Refreshes obstacle visuals and status from the live setup state.
func refresh_from_state() -> void:
	var intent: UIProjector.UIIntent = _current_setup_intent()
	_sync_modal_visibility(intent)
	_sync_overlay(intent)
	if not _is_setup_intent(intent):
		_cancel_obstacle_preview(false)
		_clear_selection()
		_last_obstacle_controller = -2
		return
	_sync_obstacles_from_state()
	_sync_preview_state(intent)
	_emit_setup_turn_prompt_if_needed(intent)
	_render_modal(intent)


## Updates the selected token during setup dragging.
func process_setup_dragging() -> void:
	if not _is_active() or not _is_interactive():
		return
	if _preview_obstacle_token != null and _preview_is_moving:
		_move_obstacle_token(_preview_obstacle_token,
				_board.get_global_mouse_position())
		_update_obstacle_preview_feedback()
		return
	if _selected_token == null or not _can_deploy():
		return
	_move_selected_token(_board.get_global_mouse_position())


## Handles board clicks for pending obstacle placement and token release.
func try_handle_input(event: InputEvent) -> bool:
	if not _is_active() or not _is_interactive():
		return false
	if event is InputEventKey:
		return _try_handle_cancel_key(event as InputEventKey)
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if _can_place_obstacles():
		return _try_handle_obstacle_click(mouse_event)
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return false
	if not _can_place_obstacles() and not _can_deploy():
		return false
	return _try_commit_selected_token()


## Starts setup dragging for a ship token.
func try_handle_ship_click(token: ShipToken) -> bool:
	if not _can_deploy():
		return false
	_cancel_obstacle_preview(false)
	_select_token(token)
	return true


## Starts setup dragging for a squadron token.
func try_handle_squadron_click(token: SquadronToken) -> bool:
	if not _can_deploy():
		return false
	_cancel_obstacle_preview(false)
	_select_token(token)
	return true


## Reuses the debug magnify-gesture rotation path for setup previews/tokens.
func try_handle_rotate_input(event: InputEventMagnifyGesture) -> bool:
	if not _is_active() or not _is_interactive():
		return false
	var token: Node2D = _rotatable_setup_token()
	if token == null:
		return false
	token.rotation += (event.factor - 1.0) * PREVIEW_ROTATE_SENSITIVITY
	token.queue_redraw()
	if token == _preview_obstacle_token:
		_update_obstacle_preview_feedback()
	get_viewport().set_input_as_handled()
	return true


func _build_ui() -> void:
	_setup_layer = CanvasLayer.new()
	_setup_layer.name = "SetupPlacementLayer"
	_setup_layer.layer = 95
	add_child(_setup_layer)
	_setup_overlay = SETUP_AREA_OVERLAY_SCRIPT.new()
	_setup_overlay.name = "SetupAreaOverlay"
	_setup_overlay.visible = false
	_setup_overlay.z_index = -1
	_board.add_child(_setup_overlay)
	var token_index: int = _board.get_children().find(_token_container)
	if token_index >= 0:
		_board.move_child(_setup_overlay, token_index)
	_modal = SETUP_OBSTACLE_MODAL_SCRIPT.new()
	_modal.name = "SetupPlacementModal"
	_setup_layer.add_child(_modal)
	_modal.obstacle_selected.connect(_on_obstacle_button_pressed)
	_modal.cancel_preview_requested.connect(_on_cancel_preview_requested)
	_modal.confirm_preview_requested.connect(_on_confirm_preview_requested)
	_modal.start_round_requested.connect(_on_start_round_pressed)


func _connect_signals() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	CommandProcessor.command_executed.connect(_on_command_executed)


func _sync_modal_visibility(intent: UIProjector.UIIntent) -> void:
	if _modal != null:
		_modal.visible = _is_setup_intent(intent)


func _sync_overlay(intent: UIProjector.UIIntent) -> void:
	if _setup_overlay != null:
		_setup_overlay.set_modal_kind(intent.modal_kind)


func _is_setup_intent(intent: UIProjector.UIIntent) -> bool:
	return intent.flow_type == Constants.InteractionFlow.SETUP


func _is_active() -> bool:
	return _current_setup_intent().flow_type == Constants.InteractionFlow.SETUP


func _is_interactive() -> bool:
	return _current_setup_intent().is_interactive


func _can_place_obstacles() -> bool:
	return _current_setup_intent().modal_kind \
			== Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT and _is_interactive()


func _can_deploy() -> bool:
	var modal_kind: Constants.ModalKind = _current_setup_intent().modal_kind
	return _is_interactive() and (
			modal_kind == Constants.ModalKind.SETUP_SHIP_DEPLOYMENT
			or modal_kind == Constants.ModalKind.SETUP_SQUADRON_DEPLOYMENT)


func _can_start_round() -> bool:
	return _current_setup_intent().modal_kind == Constants.ModalKind.SETUP_REVIEW \
			and _is_interactive()


func _current_setup_intent() -> UIProjector.UIIntent:
	var state: GameState = GameManager.current_game_state
	if state == null:
		return UIProjector.UIIntent.new()
	return UIProjector.project(state, _viewer_player())


func _viewer_player() -> int:
	var local_player: int = NetworkManager.get_local_player_index()
	if local_player >= 0:
		return local_player
	var state: GameState = GameManager.current_game_state
	if state != null and state.interaction_flow != null:
		if state.interaction_flow.controller_player >= 0:
			return state.interaction_flow.controller_player
	return GameManager.active_player


func _sync_obstacles_from_state() -> void:
	var seen: Dictionary = {}
	for obstacle: Dictionary in _state_obstacles():
		var key: String = str(obstacle.get("data_key", ""))
		seen[key] = true
		_sync_obstacle_token(key, obstacle)
	_remove_stale_obstacles(seen)


func _sync_obstacle_token(data_key: String, obstacle: Dictionary) -> void:
	var token: Variant = _obstacle_tokens.get(data_key, null)
	if token == null:
		token = SETUP_OBSTACLE_TOKEN_SCRIPT.new()
		_token_container.add_child(token)
		token.token_clicked.connect(_on_obstacle_token_clicked)
		_obstacle_tokens[data_key] = token
		token.setup(data_key,
				float(obstacle.get("pos_x", 0.0)),
				float(obstacle.get("pos_y", 0.0)),
				float(obstacle.get("rotation_deg", 0.0)))
		return
	token.set_normalized_transform(
			float(obstacle.get("pos_x", 0.0)),
			float(obstacle.get("pos_y", 0.0)),
			float(obstacle.get("rotation_deg", 0.0)))
	token.reset_outline_colour()


func _remove_stale_obstacles(seen: Dictionary) -> void:
	for data_key: String in _obstacle_tokens.keys():
		if seen.has(data_key):
			continue
		var token: Variant = _obstacle_tokens[data_key]
		if token != null:
			token.queue_free()
		_obstacle_tokens.erase(data_key)


func _state_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = GameManager.current_game_state.objectives.get(
			FleetSetupBootstrapper.KEY_OBSTACLES, [])
	if not raw is Array:
		return result
	for value: Variant in raw as Array:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


func _placed_obstacle_keys() -> Dictionary:
	var placed: Dictionary = {}
	for obstacle: Dictionary in _state_obstacles():
		placed[str(obstacle.get("data_key", ""))] = true
	return placed


func _pending_label_text(obstacle_count: int) -> String:
	if _preview_obstacle_token != null and not _pending_obstacle_key.is_empty():
		if _preview_is_moving:
			return "Preview: %s. Move it, rotate it, then click once to drop it." \
					% _obstacle_button_text(_pending_obstacle_key)
		return "Preview dropped: %s. Click it again to move, or confirm placement." \
				% _obstacle_button_text(_pending_obstacle_key)
	if obstacle_count < StartRoundCommand.STANDARD_OBSTACLE_COUNT:
		return "Select a remaining obstacle to begin a live placement preview."
	return "All six obstacles placed. Continue with deployment or setup review."


func _on_obstacle_button_pressed(obstacle_key: String) -> void:
	if not _can_place_obstacles():
		return
	_begin_obstacle_preview(obstacle_key)
	_render_modal(_current_setup_intent())


func _on_cancel_preview_requested() -> void:
	_cancel_obstacle_preview(true)


func _on_confirm_preview_requested() -> void:
	_try_commit_obstacle_preview()


func _on_obstacle_token_clicked(token: Node2D) -> void:
	if token != _preview_obstacle_token:
		return
	if _preview_is_moving:
		return
	_resume_obstacle_preview_move()


func _select_token(token: Node2D) -> void:
	_selected_token = token
	_selected_origin = token.position
	_selected_rotation = token.rotation
	_set_status("", STATUS_TEXT)


func _try_handle_cancel_key(event: InputEventKey) -> bool:
	if not event.pressed or event.keycode != KEY_ESCAPE:
		return false
	return _cancel_obstacle_preview(true)


func _try_handle_obstacle_click(mouse_event: InputEventMouseButton) -> bool:
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		return _cancel_obstacle_preview(true)
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false
	if _preview_obstacle_token == null:
		return false
	if _preview_is_moving:
		_drop_obstacle_preview()
		return true
	return true


func _try_commit_obstacle_preview() -> bool:
	if _preview_obstacle_token == null or _preview_is_moving:
		return false
	if not _preview_validation_error.is_empty():
		_render_modal(_current_setup_intent())
		return false
	var success: bool = _commit_obstacle_token(_preview_obstacle_token)
	if success:
		_cancel_obstacle_preview(false)
	return success


func _try_commit_selected_token() -> bool:
	if _selected_token == null:
		return false
	var success: bool = _commit_token(_selected_token)
	if not success:
		_revert_selection()
	_clear_selection()
	return true


func _move_selected_token(mouse_world: Vector2) -> void:
	if _selected_token is ShipToken:
		_move_ship_token(_selected_token as ShipToken, mouse_world)
		return
	if _selected_token is SquadronToken:
		_move_squadron_token(_selected_token as SquadronToken, mouse_world)
		return
	if _is_setup_obstacle_token(_selected_token):
		_move_obstacle_token(_selected_token, mouse_world)


func _move_ship_token(token: ShipToken, desired: Vector2) -> void:
	token.position = _token_mover.resolve_ship_position_in_area(
			desired,
			token.position,
			token.get_ship_size(),
			token.rotation,
			token.get_faction(),
			_build_other_ship_rects(token),
			_build_other_squad_circles(token),
			DeploymentZoneOverlay.get_top_line_y(),
			DeploymentZoneOverlay.get_bottom_line_y(),
			GameScale.play_area_size_px,
			true)


func _move_squadron_token(token: SquadronToken, desired: Vector2) -> void:
	token.position = _token_mover.resolve_squadron_position_in_area(
			desired,
			token.position,
			token.get_radius_px(),
			token.get_faction(),
			_build_other_ship_rects(token),
			_build_other_squad_circles(token),
			DeploymentZoneOverlay.get_top_line_y(),
			DeploymentZoneOverlay.get_bottom_line_y(),
			GameScale.play_area_size_px,
			false)


func _move_obstacle_token(token: Node2D, desired: Vector2) -> void:
	var candidate: Vector2 = _candidate_obstacle_position(desired, token)
	if token == _preview_obstacle_token and _would_enter_deployment_zone(candidate):
		_set_status(SETUP_OBSTACLE_VALIDATOR_SCRIPT.ERROR_DEPLOYMENT_ZONE,
				STATUS_ERROR)
		return
	token.position = candidate


func _build_other_ship_rects(exclude: Node) -> Array:
	var result: Array = []
	for child: Node in _token_container.get_children():
		if child == exclude or not child is ShipToken:
			continue
		var ship: ShipToken = child as ShipToken
		result.append({
			"position": ship.position,
			"rotation": ship.rotation,
			"half_w": ship.get_half_width(),
			"half_l": ship.get_half_length(),
		})
	return result


func _build_other_squad_circles(exclude: Node) -> Array:
	var result: Array = []
	for child: Node in _token_container.get_children():
		if child == exclude or not child is SquadronToken:
			continue
		var squadron: SquadronToken = child as SquadronToken
		result.append({
			"position": squadron.position,
			"radius": squadron.get_radius_px(),
		})
	return result


func _commit_token(token: Node2D) -> bool:
	if token is ShipToken:
		return _commit_ship_token(token as ShipToken)
	if token is SquadronToken:
		return _commit_squadron_token(token as SquadronToken)
	if _is_setup_obstacle_token(token):
		return _commit_obstacle_token(token)
	return false


func _commit_ship_token(token: ShipToken) -> bool:
	var ship: ShipInstance = token.get_ship_instance()
	if ship == null:
		return false
	var result: Dictionary = GameManager.submit_setup_deployment_placement(
			ship.owner_player,
			COMPONENT_SHIP,
			ship.roster_entry_id,
			token.position.x / GameScale.play_area_size_px.x,
			token.position.y / GameScale.play_area_size_px.y,
			rad_to_deg(token.rotation),
			ship.current_speed)
	return _handle_commit_result(result)


func _commit_squadron_token(token: SquadronToken) -> bool:
	var squadron: SquadronInstance = token.get_squadron_instance()
	if squadron == null:
		return false
	var result: Dictionary = GameManager.submit_setup_deployment_placement(
			squadron.owner_player,
			COMPONENT_SQUADRON,
			squadron.roster_entry_id,
			token.position.x / GameScale.play_area_size_px.x,
			token.position.y / GameScale.play_area_size_px.y,
			rad_to_deg(token.rotation))
	return _handle_commit_result(result)


func _commit_obstacle_token(token: Node2D) -> bool:
	var result: Dictionary = GameManager.submit_setup_obstacle_placement(
			str(token.call("get_data_key")),
			token.position.x / GameScale.play_area_size_px.x,
			token.position.y / GameScale.play_area_size_px.y,
			rad_to_deg(token.rotation))
	return _handle_commit_result(result)


func _handle_commit_result(result: Dictionary) -> bool:
	if result.is_empty() or result.has("reason"):
		_set_status(str(result.get("reason", "Setup placement was rejected.")),
				STATUS_ERROR)
		_render_modal(_current_setup_intent())
		return false
	_set_status("", STATUS_TEXT)
	refresh_from_state()
	return true


func _revert_selection() -> void:
	if _selected_token == null:
		return
	_selected_token.position = _selected_origin
	_selected_token.rotation = _selected_rotation


func _clear_selection() -> void:
	_selected_token = null
	_selected_origin = Vector2.ZERO
	_selected_rotation = 0.0


func _on_phase_changed(_phase: Constants.GamePhase) -> void:
	refresh_from_state()


func _on_command_executed(command: GameCommand, _result: Dictionary) -> void:
	if command == null or not _is_active():
		return
	if command.command_type == "commit_setup_obstacle":
		refresh_from_state()
		return
	if command.command_type == "commit_setup_deployment":
		_sync_runtime_token(command.payload)
		_render_modal(_current_setup_intent())


func _sync_runtime_token(payload: Dictionary) -> void:
	if str(payload.get("component_type", "")) == COMPONENT_SHIP:
		_sync_ship_token(payload)
		return
	if str(payload.get("component_type", "")) == COMPONENT_SQUADRON:
		_sync_squadron_token(payload)


func _sync_preview_state(intent: UIProjector.UIIntent) -> void:
	if intent.modal_kind != Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT:
		_cancel_obstacle_preview(false)
	if not intent.is_interactive and _preview_obstacle_token != null:
		_cancel_obstacle_preview(false)


func _emit_setup_turn_prompt_if_needed(intent: UIProjector.UIIntent) -> void:
	if intent.modal_kind != Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT:
		_last_obstacle_controller = -2
		return
	if intent.controller_player < 0 \
			or intent.controller_player == _last_obstacle_controller:
		return
	_last_obstacle_controller = intent.controller_player
	setup_turn_prompt_requested.emit(
			intent.controller_player, intent.controller_player_label)


func _render_modal(intent: UIProjector.UIIntent) -> void:
	if _modal == null:
		return
	_modal.centre_on_screen(get_viewport().get_visible_rect().size)
	match intent.modal_kind:
		Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT:
			_render_obstacle_modal(intent)
		Constants.ModalKind.SETUP_REVIEW:
			_render_review_modal(intent)
		_:
			_render_deployment_modal(intent)


func _render_obstacle_modal(intent: UIProjector.UIIntent) -> void:
	var status: Dictionary = _status_snapshot()
	_modal.render_obstacle_step(
			_obstacle_title(intent),
			_obstacle_prompt(intent),
			_pending_label_text(_state_obstacles().size()),
			str(status.get("text", "")),
			status.get("color", STATUS_TEXT) as Color,
			_obstacle_entries(),
			_preview_obstacle_token != null,
			_preview_obstacle_token != null,
			not _can_confirm_preview())


func _render_review_modal(intent: UIProjector.UIIntent) -> void:
	var status: Dictionary = _status_snapshot()
	_modal.render_setup_summary(
			"Setup Review",
			_review_prompt(intent),
			"",
			str(status.get("text", "")),
			status.get("color", STATUS_TEXT) as Color,
			true,
			not (_is_ready_for_start() and _can_start_round()))


func _render_deployment_modal(intent: UIProjector.UIIntent) -> void:
	var status: Dictionary = _status_snapshot()
	_modal.render_setup_summary(
			"Deployment",
			_deployment_prompt(intent),
			"",
			str(status.get("text", "")),
			status.get("color", STATUS_TEXT) as Color,
			false,
			true)


func _obstacle_title(intent: UIProjector.UIIntent) -> String:
	if intent.is_interactive:
		return "%s place obstacle" % intent.controller_player_label
	return "%s is placing obstacle" % intent.controller_player_label


func _obstacle_prompt(intent: UIProjector.UIIntent) -> String:
	if intent.is_interactive:
		return "Select a remaining obstacle, move the preview, click once to drop it, then confirm placement."
	return "Waiting for %s to place the next obstacle." % intent.controller_player_label


func _deployment_prompt(intent: UIProjector.UIIntent) -> String:
	if intent.is_interactive:
		return "Drag your eligible setup tokens into position. Deployment validation remains command-backed."
	return "Waiting for %s to continue setup deployment." % intent.controller_player_label


func _review_prompt(intent: UIProjector.UIIntent) -> String:
	if intent.is_interactive:
		return "Inspect the finished setup state before round one begins."
	return "Both players may inspect the setup before round one begins."


func _obstacle_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var placed: Dictionary = _placed_obstacle_keys()
	for obstacle_key: String in AssetLoader.list_obstacle_keys():
		entries.append({
			"key": obstacle_key,
			"label": _obstacle_button_text(obstacle_key),
			"disabled": placed.has(obstacle_key) or not _can_place_obstacles(),
			"selected": obstacle_key == _pending_obstacle_key,
		})
	return entries


func _status_snapshot() -> Dictionary:
	if not _status_text.is_empty():
		return {"text": _status_text, "color": _status_colour}
	return {
		"text": _setup_progress_text(),
		"color": STATUS_OK if _is_ready_for_start() else STATUS_TEXT,
	}


func _setup_progress_text() -> String:
	return "Obstacles: %d/%d  |  Missing deployments: %d" % [
		_state_obstacles().size(),
		StartRoundCommand.STANDARD_OBSTACLE_COUNT,
		_missing_deployment_keys().size(),
	]


func _missing_deployment_keys() -> Array[String]:
	return StartRoundCommand._missing_deployment_keys(
			GameManager.current_game_state,
			StartRoundCommand._deployment_key_map(GameManager.current_game_state))


func _is_ready_for_start() -> bool:
	return _state_obstacles().size() >= StartRoundCommand.STANDARD_OBSTACLE_COUNT \
			and _missing_deployment_keys().is_empty()


func _set_status(text: String, colour: Color) -> void:
	_status_text = text
	_status_colour = colour


func _begin_obstacle_preview(obstacle_key: String) -> void:
	_cancel_obstacle_preview(false)
	_clear_selection()
	_pending_obstacle_key = obstacle_key
	_preview_obstacle_token = SETUP_OBSTACLE_TOKEN_SCRIPT.new()
	_token_container.add_child(_preview_obstacle_token)
	_preview_obstacle_token.token_clicked.connect(_on_obstacle_token_clicked)
	_preview_obstacle_token.setup(obstacle_key, 0.5, 0.5, 0.0)
	_preview_obstacle_token.set_click_enabled(false)
	_preview_obstacle_token.modulate = Color(1.0, 1.0, 1.0, 0.86)
	_preview_is_moving = true
	_preview_validation_error = ""
	_move_obstacle_token(_preview_obstacle_token, _board.get_global_mouse_position())
	_update_obstacle_preview_feedback()


func _cancel_obstacle_preview(report_cancel: bool) -> bool:
	if _preview_obstacle_token == null:
		return false
	_preview_obstacle_token.queue_free()
	_preview_obstacle_token = null
	_pending_obstacle_key = ""
	_preview_is_moving = false
	_preview_validation_error = ""
	_set_status("Obstacle preview cancelled." if report_cancel else "", STATUS_TEXT)
	if _is_active():
		_render_modal(_current_setup_intent())
	return true


func _update_obstacle_preview_feedback() -> void:
	if _preview_obstacle_token == null:
		return
	var validation_error: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			GameManager.current_game_state,
			_current_setup_intent().controller_player,
			_preview_payload())
	_preview_validation_error = validation_error
	if validation_error.is_empty():
		_preview_obstacle_token.set_outline_colour(STATUS_OK)
		if _preview_is_moving:
			_set_status("Legal preview. Click once to drop the obstacle.", STATUS_OK)
		else:
			_set_status("Legal preview. Confirm placement or click the obstacle to move it again.", STATUS_OK)
		return
	_preview_obstacle_token.set_outline_colour(STATUS_ERROR)
	_set_status(validation_error, STATUS_ERROR)


func _preview_payload() -> Dictionary:
	return {
		"data_key": str(_preview_obstacle_token.get_data_key()),
		"pos_x": _preview_obstacle_token.position.x / GameScale.play_area_size_px.x,
		"pos_y": _preview_obstacle_token.position.y / GameScale.play_area_size_px.y,
		"rotation_deg": rad_to_deg(_preview_obstacle_token.rotation),
	}


func _rotatable_setup_token() -> Node2D:
	if _preview_obstacle_token != null:
		return _preview_obstacle_token
	return _selected_token


func _can_confirm_preview() -> bool:
	return _preview_obstacle_token != null \
			and not _preview_is_moving \
			and _preview_validation_error.is_empty()


func _drop_obstacle_preview() -> void:
	_preview_is_moving = false
	_preview_obstacle_token.set_click_enabled(true)
	_update_obstacle_preview_feedback()
	_render_modal(_current_setup_intent())


func _resume_obstacle_preview_move() -> void:
	_preview_is_moving = true
	_preview_obstacle_token.set_click_enabled(false)
	_set_status("Preview unlocked. Move it, rotate it, then click once to drop it.",
			STATUS_TEXT)
	_render_modal(_current_setup_intent())


func _candidate_obstacle_position(desired: Vector2, token: Node2D) -> Vector2:
	var extents: Vector2 = token.call("get_half_extents") as Vector2
	return Vector2(
			clampf(desired.x, extents.x, GameScale.play_area_size_px.x - extents.x),
			clampf(desired.y, extents.y, GameScale.play_area_size_px.y - extents.y))


func _preview_payload_for_position(position: Vector2) -> Dictionary:
	return {
		"data_key": str(_preview_obstacle_token.get_data_key()),
		"pos_x": position.x / GameScale.play_area_size_px.x,
		"pos_y": position.y / GameScale.play_area_size_px.y,
		"rotation_deg": rad_to_deg(_preview_obstacle_token.rotation),
	}


func _would_enter_deployment_zone(position: Vector2) -> bool:
	var error: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			GameManager.current_game_state,
			_current_setup_intent().controller_player,
			_preview_payload_for_position(position))
	return error == SETUP_OBSTACLE_VALIDATOR_SCRIPT.ERROR_DEPLOYMENT_ZONE


func _sync_ship_token(payload: Dictionary) -> void:
	for child: Node in _token_container.get_children():
		if not child is ShipToken:
			continue
		var token: ShipToken = child as ShipToken
		var ship: ShipInstance = token.get_ship_instance()
		if ship == null or not _payload_matches_instance(payload, ship.owner_player, ship.roster_entry_id):
			continue
		token.position = Vector2(
				float(payload.get("pos_x", ship.pos_x)) * GameScale.play_area_size_px.x,
				float(payload.get("pos_y", ship.pos_y)) * GameScale.play_area_size_px.y)
		token.rotation = deg_to_rad(float(payload.get("rotation_deg", ship.rotation_deg)))
		return


func _sync_squadron_token(payload: Dictionary) -> void:
	for child: Node in _token_container.get_children():
		if not child is SquadronToken:
			continue
		var token: SquadronToken = child as SquadronToken
		var squadron: SquadronInstance = token.get_squadron_instance()
		if squadron == null \
				or not _payload_matches_instance(payload, squadron.owner_player, squadron.roster_entry_id):
			continue
		token.position = Vector2(
				float(payload.get("pos_x", squadron.pos_x)) * GameScale.play_area_size_px.x,
				float(payload.get("pos_y", squadron.pos_y)) * GameScale.play_area_size_px.y)
		token.rotation = deg_to_rad(float(payload.get("rotation_deg", squadron.rotation_deg)))
		return


func _payload_matches_instance(payload: Dictionary,
		owner_player: int,
		roster_entry_id: String) -> bool:
	return int(payload.get("owner_player", -1)) == owner_player \
			and str(payload.get("roster_entry_id", "")) == roster_entry_id


func _is_setup_obstacle_token(value: Variant) -> bool:
	return value is Node and value.get_script() == SETUP_OBSTACLE_TOKEN_SCRIPT


func _on_start_round_pressed() -> void:
	if not _can_start_round():
		return
	var result: Dictionary = GameManager.complete_setup_and_start_round()
	if result.has("new_round"):
		refresh_from_state()
		return
	_set_status(str(result.get("reason", "Setup could not be completed.")),
			STATUS_ERROR)
	_render_modal(_current_setup_intent())


func _obstacle_button_text(obstacle_key: String) -> String:
	var obstacle_data: ObstacleData = AssetLoader.load_obstacle_data(obstacle_key)
	if obstacle_data == null:
		return obstacle_key.capitalize()
	return obstacle_data.obstacle_name


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label

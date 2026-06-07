## SetupPlacementController
##
## Owns setup-package obstacle placement, deployment dragging, and the local
## Start Round button on the board. All persistent mutations flow through
## setup placement commands so setup remains replay/network-safe.
class_name SetupPlacementController
extends Node


const BUTTON_WIDTH_PX: float = 184.0
const COMPONENT_SHIP: String = "ship"
const COMPONENT_SQUADRON: String = "squadron"
const PANEL_MARGIN: Vector2 = Vector2(16, 16)
const PANEL_WIDTH_PX: float = 228.0
const STATUS_ERROR: Color = Color(0.92, 0.48, 0.44)
const STATUS_OK: Color = Color(0.52, 0.88, 0.55)
const STATUS_TEXT: Color = Color(0.94, 0.94, 0.94)
const SETUP_OBSTACLE_TOKEN_SCRIPT: GDScript = preload(
		"res://src/scenes/game_board/setup_obstacle_token.gd")

var _board: Node2D = null
var _token_container: Node2D = null
var _token_mover: TokenMover = null
var _setup_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _pending_label: Label = null
var _status_label: Label = null
var _start_button: Button = null
var _obstacle_buttons: Dictionary = {}
var _obstacle_tokens: Dictionary = {}
var _pending_obstacle_key: String = ""
var _selected_token: Node2D = null
var _selected_origin: Vector2 = Vector2.ZERO
var _selected_rotation: float = 0.0


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
	_sync_panel_visibility()
	if not _is_active():
		return
	_sync_obstacles_from_state()
	_update_obstacle_buttons()
	_update_status()


## Updates the selected token during setup dragging.
func process_setup_dragging() -> void:
	if not _is_active() or not _is_interactive() or _selected_token == null:
		return
	if _is_setup_obstacle_token(_selected_token) and not _can_place_obstacles():
		return
	if not _is_setup_obstacle_token(_selected_token) and not _can_deploy():
		return
	_move_selected_token(_board.get_global_mouse_position())


## Handles board clicks for pending obstacle placement and token release.
func try_handle_input(event: InputEvent) -> bool:
	if not _is_active() or not _is_interactive() or not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mouse_event.pressed:
		if _can_place_obstacles():
			return _try_place_pending_obstacle()
		return false
	if not _can_place_obstacles() and not _can_deploy():
		return false
	return _try_commit_selected_token()


## Starts setup dragging for a ship token.
func try_handle_ship_click(token: ShipToken) -> bool:
	if not _can_deploy():
		return false
	_select_token(token)
	return true


## Starts setup dragging for a squadron token.
func try_handle_squadron_click(token: SquadronToken) -> bool:
	if not _can_deploy():
		return false
	_select_token(token)
	return true


func _build_ui() -> void:
	_setup_layer = CanvasLayer.new()
	_setup_layer.name = "SetupPlacementLayer"
	_setup_layer.layer = 95
	add_child(_setup_layer)
	_panel = PanelContainer.new()
	_panel.position = PANEL_MARGIN
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH_PX, 0.0)
	_setup_layer.add_child(_panel)
	_panel.add_child(_build_panel_content())


func _build_panel_content() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(_build_panel_vbox())
	return margin


func _build_panel_vbox() -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_label("Setup Placement", 18, STATUS_TEXT))
	vbox.add_child(_label(
			"Pick an obstacle button, click the board to place it, then drag ships, squadrons, or placed obstacles.",
			14, STATUS_TEXT))
	vbox.add_child(_build_obstacle_buttons())
	_pending_label = _label("No obstacle selected.", 14, STATUS_TEXT)
	_status_label = _label("", 14, STATUS_TEXT)
	vbox.add_child(_pending_label)
	vbox.add_child(_status_label)
	_start_button = Button.new()
	_start_button.text = "Start Round"
	_start_button.custom_minimum_size = Vector2(BUTTON_WIDTH_PX, 0.0)
	_start_button.pressed.connect(_on_start_round_pressed)
	vbox.add_child(_start_button)
	return vbox


func _build_obstacle_buttons() -> VBoxContainer:
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	for obstacle_key: String in AssetLoader.list_obstacle_keys():
		var button: Button = Button.new()
		button.text = _obstacle_button_text(obstacle_key)
		button.custom_minimum_size = Vector2(BUTTON_WIDTH_PX, 0.0)
		button.pressed.connect(_on_obstacle_button_pressed.bind(obstacle_key))
		buttons.add_child(button)
		_obstacle_buttons[obstacle_key] = button
	return buttons


func _connect_signals() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	CommandProcessor.command_executed.connect(_on_command_executed)


func _sync_panel_visibility() -> void:
	if _panel != null:
		_panel.visible = _is_active()


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


func _update_obstacle_buttons() -> void:
	var placed: Dictionary = _placed_obstacle_keys()
	for obstacle_key: String in _obstacle_buttons.keys():
		(_obstacle_buttons[obstacle_key] as Button).disabled = placed.has(obstacle_key) \
				or not _can_place_obstacles()


func _placed_obstacle_keys() -> Dictionary:
	var placed: Dictionary = {}
	for obstacle: Dictionary in _state_obstacles():
		placed[str(obstacle.get("data_key", ""))] = true
	return placed


func _update_status() -> void:
	var obstacle_count: int = _state_obstacles().size()
	var missing: Array[String] = StartRoundCommand._missing_deployment_keys(
			GameManager.current_game_state,
			StartRoundCommand._deployment_key_map(GameManager.current_game_state))
	var is_ready_for_start: bool = \
			obstacle_count >= StartRoundCommand.STANDARD_OBSTACLE_COUNT \
			and missing.is_empty()
	_pending_label.text = _pending_label_text(obstacle_count)
	_status_label.text = "Obstacles: %d/%d  |  Missing deployments: %d" % [
		obstacle_count,
		StartRoundCommand.STANDARD_OBSTACLE_COUNT,
		missing.size(),
	]
	_status_label.add_theme_color_override(
			"font_color", STATUS_OK if is_ready_for_start else STATUS_TEXT)
	_start_button.disabled = not is_ready_for_start or not _can_start_round()


func _pending_label_text(obstacle_count: int) -> String:
	if not _pending_obstacle_key.is_empty():
		return "Pending obstacle: %s" % _obstacle_button_text(_pending_obstacle_key)
	if obstacle_count < StartRoundCommand.STANDARD_OBSTACLE_COUNT:
		return "Select an obstacle, then click the board to place it."
	return "All six obstacles placed. Drag any token to fine-tune setup."


func _on_obstacle_button_pressed(obstacle_key: String) -> void:
	_pending_obstacle_key = obstacle_key
	_update_status()


func _on_obstacle_token_clicked(token: Node2D) -> void:
	if not _can_place_obstacles():
		return
	_select_token(token)


func _select_token(token: Node2D) -> void:
	_selected_token = token
	_selected_origin = token.position
	_selected_rotation = token.rotation
	_pending_obstacle_key = ""
	_update_status()


func _try_place_pending_obstacle() -> bool:
	if _pending_obstacle_key.is_empty():
		return false
	var temp_token: Variant = SETUP_OBSTACLE_TOKEN_SCRIPT.new()
	_token_container.add_child(temp_token)
	temp_token.setup(_pending_obstacle_key, 0.5, 0.5, 0.0)
	_move_obstacle_token(temp_token, _board.get_global_mouse_position())
	var success: bool = _commit_obstacle_token(temp_token)
	temp_token.queue_free()
	if success:
		_pending_obstacle_key = ""
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
	var extents: Vector2 = token.call("get_half_extents") as Vector2
	token.position = Vector2(
			clampf(desired.x, extents.x, GameScale.play_area_size_px.x - extents.x),
			clampf(desired.y, extents.y, GameScale.play_area_size_px.y - extents.y))


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
		_status_label.text = str(result.get("reason", "Setup placement was rejected."))
		_status_label.add_theme_color_override("font_color", STATUS_ERROR)
		return false
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
		_update_status()


func _sync_runtime_token(payload: Dictionary) -> void:
	if str(payload.get("component_type", "")) == COMPONENT_SHIP:
		_sync_ship_token(payload)
		return
	if str(payload.get("component_type", "")) == COMPONENT_SQUADRON:
		_sync_squadron_token(payload)


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
	_status_label.text = str(result.get("reason", "Setup could not be completed."))
	_status_label.add_theme_color_override("font_color", STATUS_ERROR)


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

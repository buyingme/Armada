## GameBoard
##
## Root scene for the play area. Manages the game board visual, camera,
## and all ship/squadron token nodes.
##
## On [method _ready], the Learning Scenario token arrangement is placed
## automatically using [LearningScenarioSetup]. Tokens can be repositioned
## by Phase 3 state wiring once [ShipInstance] / [SquadronInstance] exist.
##
## Debug mode (Phase 2b): when DebugMode.enabled is true, left-click selects
## a token, the selected token follows the mouse, two-finger gesture rotates
## it, and Ctrl+S saves all positions to the scenario JSON.
##
## Coordinate system: world (0,0) = top-left corner of the play area.
## Play area extends to (play_area_side_px, play_area_side_px).
##
## Rules Reference: "Setup", p.11; SU-001/002/027; GC-001.
## Requirements: DBG-001–041
class_name GameBoard
extends Node2D


## Packed scenes for token instantiation.
const SHIP_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/ship_token.tscn")
const SQUADRON_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/squadron_token.tscn")

## Background colour for the play area.
const PLAY_AREA_COLOUR: Color = Color(0.05, 0.07, 0.14)
## Colour for the play area border line.
const BORDER_COLOUR: Color = Color(0.40, 0.50, 0.70, 0.80)
## Border line width in pixels.
const BORDER_WIDTH_PX: float = 3.0

## Rotation sensitivity for trackpad magnify gesture when a token is selected.
## Factor arrives near 1.0; this converts to a usable radian delta.
const DEBUG_ROTATE_SENSITIVITY: float = 2.0

## Logger instance.
var _log: GameLogger = GameLogger.new("GameBoard")

## Camera node reference.
var _camera: BoardCamera = null

## Container for all token nodes.
var _token_container: Node2D = null

## Deployment zone overlay (visible in debug mode only).
var _deploy_overlay: DeploymentZoneOverlay = null

## Debug HUD label (shows "DEBUG" in top-left corner).
var _debug_label: Label = null

## Core mover logic for collision resolution.
var _token_mover: TokenMover = TokenMover.new()

## Scenario saver utility.
var _scenario_saver: ScenarioSaver = ScenarioSaver.new()


func _ready() -> void:
	_create_camera()
	_create_token_container()
	_create_deploy_overlay()
	_create_debug_label()
	_connect_signals()
	_spawn_learning_scenario_tokens()
	_update_debug_visibility()
	queue_redraw()


## Returns all current ship tokens on the board.
func get_ship_tokens() -> Array[ShipToken]:
	var result: Array[ShipToken] = []
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			result.append(child as ShipToken)
	return result


## Returns all current squadron tokens on the board.
func get_squadron_tokens() -> Array[SquadronToken]:
	var result: Array[SquadronToken] = []
	for child: Node in _token_container.get_children():
		if child is SquadronToken:
			result.append(child as SquadronToken)
	return result


## Removes all tokens from the board.
func clear_tokens() -> void:
	for child: Node in _token_container.get_children():
		child.queue_free()


func _draw() -> void:
	var side: float = GameScale.play_area_side_px
	if side <= 0.0:
		return
	var area: Rect2 = Rect2(Vector2.ZERO, Vector2(side, side))
	draw_rect(area, PLAY_AREA_COLOUR, true)
	draw_rect(area, BORDER_COLOUR, false, BORDER_WIDTH_PX)


func _process(_delta: float) -> void:
	if not DebugMode.has_selection():
		return
	_move_selected_token_to_mouse()


## Handles input for debug-mode interactions.
## DBG-003 — must not interfere with camera controls (right-click, scroll).
func _unhandled_input(event: InputEvent) -> void:
	if not DebugMode.enabled:
		return

	if event is InputEventMouseButton:
		_handle_debug_click(event as InputEventMouseButton)
	elif event is InputEventMagnifyGesture and DebugMode.has_selection():
		_handle_debug_rotate(event as InputEventMagnifyGesture)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Creates and attaches the BoardCamera as a child of this node.
func _create_camera() -> void:
	_camera = BoardCamera.new()
	_camera.name = "BoardCamera"
	add_child(_camera)


## Creates the container node that holds all token nodes.
func _create_token_container() -> void:
	_token_container = Node2D.new()
	_token_container.name = "TokenContainer"
	add_child(_token_container)


## Creates the deployment zone overlay (initially hidden).
func _create_deploy_overlay() -> void:
	_deploy_overlay = DeploymentZoneOverlay.new()
	_deploy_overlay.name = "DeploymentZoneOverlay"
	_deploy_overlay.visible = false
	add_child(_deploy_overlay)


## Creates the debug-mode HUD label on a CanvasLayer.
func _create_debug_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DebugHUDLayer"
	layer.layer = 100
	add_child(layer)

	_debug_label = Label.new()
	_debug_label.text = "DEBUG"
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.position = Vector2(10, 10)
	_debug_label.visible = false
	layer.add_child(_debug_label)


## Connects EventBus and DebugMode signals relevant to the board.
func _connect_signals() -> void:
	EventBus.firing_arc_toggled.connect(_on_firing_arc_toggled)
	DebugMode.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugMode.save_positions_requested.connect(_on_save_positions)


## Places all Learning Scenario tokens from setup data.
## Rules Reference: "Learning Scenario Setup", step 9, p.5.
func _spawn_learning_scenario_tokens() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	for placement: TokenPlacement in setup.get_all_placements():
		if placement.is_ship:
			_spawn_ship_token(placement)
		else:
			_spawn_squadron_token(placement)
	_log.info("Spawned %d tokens for the Learning Scenario." %
			_token_container.get_child_count())


## Instantiates and configures a ShipToken for the given placement.
func _spawn_ship_token(
		placement: TokenPlacement) -> void:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	_token_container.add_child(token)
	token.setup(placement)
	token.token_clicked.connect(_on_token_clicked)


## Instantiates and configures a SquadronToken for the given placement.
func _spawn_squadron_token(
		placement: TokenPlacement) -> void:
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	_token_container.add_child(token)
	token.setup(placement)
	token.token_clicked.connect(_on_squadron_clicked)


## Called when a ship token is clicked.
func _on_token_clicked(token: ShipToken) -> void:
	if DebugMode.enabled:
		DebugMode.select_token(token)
	else:
		EventBus.element_selected.emit(token)


## Called when a squadron token is clicked.
func _on_squadron_clicked(token: SquadronToken) -> void:
	if DebugMode.enabled:
		DebugMode.select_token(token)
	else:
		EventBus.element_selected.emit(token)


## Handles the global firing arc toggle signal.
## Rules Reference: UI-011 — player toggles arc overlay for a ship token.
func _on_firing_arc_toggled(token: Node) -> void:
	if token is ShipToken:
		(token as ShipToken).toggle_arc_overlay()


## Updates visibility of debug-only UI elements.
func _on_debug_mode_changed(_enabled: bool) -> void:
	_update_debug_visibility()


## Toggles debug-specific overlays.
func _update_debug_visibility() -> void:
	var on: bool = DebugMode.enabled
	if _deploy_overlay:
		_deploy_overlay.visible = on
	if _debug_label:
		_debug_label.visible = on


## Handles left-click in debug mode: clicks on empty space deselect.
## DBG-010 — left-click empty space deselects.
func _handle_debug_click(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# If we have a selection and clicked empty space, deselect.
	# Token clicks are handled by token _input → token_clicked signal first.
	# If input reaches here, no token was hit.
	if DebugMode.has_selection():
		DebugMode.deselect_token()
		get_viewport().set_input_as_handled()


## Handles two-finger magnify gesture as rotation for the selected token.
## DBG-012 — trackpad gesture rotates.
func _handle_debug_rotate(event: InputEventMagnifyGesture) -> void:
	var token: Node2D = DebugMode.selected_token
	if token == null:
		return
	# Convert magnify factor to rotation delta.
	var delta_rad: float = (event.factor - 1.0) * DEBUG_ROTATE_SENSITIVITY
	token.rotation += delta_rad
	token.queue_redraw()
	get_viewport().set_input_as_handled()


## Moves the currently selected token toward the mouse with collision resolution.
## DBG-011, DBG-020, DBG-021, DBG-032
func _move_selected_token_to_mouse() -> void:
	var token: Node2D = DebugMode.selected_token
	if token == null:
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	var side: float = GameScale.play_area_side_px
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()

	if token is ShipToken:
		_move_ship_token(token as ShipToken, mouse_world, side, top_y, bottom_y)
	elif token is SquadronToken:
		_move_squadron_token(
				token as SquadronToken, mouse_world, side, top_y, bottom_y)


## Resolves and applies position for a ship token.
func _move_ship_token(
		token: ShipToken, desired: Vector2, side: float,
		top_y: float, bottom_y: float
) -> void:
	var other_ships: Array = _build_other_ship_rects(token)
	var other_squads: Array = _build_other_squad_circles(token)
	var new_pos: Vector2 = _token_mover.resolve_ship_position(
			desired, token.position,
			token.get_ship_size(), token.rotation,
			token.get_faction(),
			other_ships, other_squads,
			top_y, bottom_y, side)
	token.position = new_pos


## Resolves and applies position for a squadron token.
func _move_squadron_token(
		token: SquadronToken, desired: Vector2, side: float,
		top_y: float, bottom_y: float
) -> void:
	var other_ships: Array = _build_other_ship_rects(token)
	var other_squads: Array = _build_other_squad_circles(token)
	var new_pos: Vector2 = _token_mover.resolve_squadron_position(
			desired, token.position,
			token.get_radius_px(), token.get_faction(),
			other_ships, other_squads,
			top_y, bottom_y, side)
	token.position = new_pos


## Builds collision descriptors for all ship tokens except [exclude].
func _build_other_ship_rects(exclude: Node) -> Array:
	var result: Array = []
	for child: Node in _token_container.get_children():
		if child == exclude:
			continue
		if child is ShipToken:
			var ship: ShipToken = child as ShipToken
			result.append({
				"position": ship.position,
				"rotation": ship.rotation,
				"half_w": ship.get_half_width(),
				"half_l": ship.get_half_length(),
			})
	return result


## Builds collision descriptors for all squadron tokens except [exclude].
func _build_other_squad_circles(exclude: Node) -> Array:
	var result: Array = []
	for child: Node in _token_container.get_children():
		if child == exclude:
			continue
		if child is SquadronToken:
			var squad: SquadronToken = child as SquadronToken
			result.append({
				"position": squad.position,
				"radius": squad.get_radius_px(),
			})
	return result


## Saves all token positions to the learning scenario JSON.
## DBG-040, DBG-041
func _on_save_positions() -> void:
	var success: bool = _scenario_saver.save_positions(
			"scenarios/", "learning_scenario.json",
			get_ship_tokens(), get_squadron_tokens(),
			GameScale.play_area_side_px)
	if success:
		_log.info("Token positions saved successfully.")
	else:
		_log.error("Failed to save token positions.")

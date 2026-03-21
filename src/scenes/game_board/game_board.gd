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

## Fallback background colour when no map image is configured.
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

## Debug help panel showing all keyboard shortcuts.
var _debug_help_panel: DebugHelpPanel = null

## Background map texture loaded from the scenario JSON (may be null).
var _map_texture: Texture2D = null

## Core mover logic for collision resolution.
var _token_mover: TokenMover = TokenMover.new()

## Scenario saver utility.
var _scenario_saver: ScenarioSaver = ScenarioSaver.new()

## Ship card side panels: Rebel (left) and Imperial (right).
## Rules Reference: SU-026, UI-016, UI-017.
var _rebel_card_panel: ShipCardPanel = null
var _imperial_card_panel: ShipCardPanel = null

## Command Dial Picker modal (shared, one at a time).
var _command_dial_picker: CommandDialPicker = null

## Command Dial Order Modal (shared, one at a time).
var _command_dial_order_modal: CommandDialOrderModal = null

## Phase / round HUD label shown at the top-centre of the screen.
var _phase_hud_label: Label = null

## Handoff overlay for hot-seat turn transitions (Command Phase).
## Requirements: HO-001, HO-002, HO-003.
var _handoff_overlay: HandoffOverlay = null

## Brief "Your Turn" banner (Ship / Squadron Phases).
## Requirements: HO-004, HO-005.
var _your_turn_banner: YourTurnBanner = null

## "End Activation" button (Ship / Squadron Phases).
## Requirements: TF-005, TF-011.
var _end_activation_button: EndActivationButton = null

## Queue of ships still awaiting dial assignment during the Command Phase.
## Populated at the start of each Command Phase, drained as each picker
## is confirmed. Initiative player's ships come first.
var _ships_needing_dials: Array[ShipInstance] = []

## --- Dial drag state (Phase 4c: Ship Activation Trigger) ---

## Whether a command dial drag is currently in progress.
var _drag_active: bool = false
## The ShipInstance whose dial is being dragged.
var _drag_ship_instance: ShipInstance = null
## Floating preview Control shown during drag (on TurnManagement layer).
var _drag_preview: Control = null
## The ShipToken currently being activated (dial shown behind base).
var _activating_ship_token: ShipToken = null

## --- Maneuver Tool state (Phase 5a) ---

## Whether we are in "select ship for maneuver tool" mode.
var _maneuver_tool_selecting: bool = false

## Active ManeuverToolScene instance (null when not displayed).
var _maneuver_tool_scene: ManeuverToolScene = null

## ActionToolbar in the lower-right corner.
var _action_toolbar: ActionToolbar = null

## --- Phase 5b: Activation flow state ---

## "Show Activation Sequence" button (replaces End Activation after dial reveal).
## Requirements: ACT-007, FLOW-002.
var _show_activation_button: ShowActivationButton = null

## Activation modal panel (centred on screen, same style as CommandDialPicker).
## Requirements: ACT-001–004.
var _activation_modal: ActivationModal = null

## Current ship activation state tracker (nil when not in activation).
## Requirements: FLOW-004.
var _ship_activation_state: ShipActivationState = null

## Human-readable names for each game phase.
const PHASE_NAMES: Dictionary = {
	Constants.GamePhase.SETUP: "Setup",
	Constants.GamePhase.COMMAND: "Command Phase",
	Constants.GamePhase.SHIP: "Ship Phase",
	Constants.GamePhase.SQUADRON: "Squadron Phase",
	Constants.GamePhase.STATUS: "Status Phase",
}


func _ready() -> void:
	_create_camera()
	_create_token_container()
	_create_deploy_overlay()
	_create_debug_label()
	_create_ship_card_panels()
	_create_command_phase_ui()
	_create_turn_management_ui()
	_create_phase_hud()
	_create_action_toolbar()
	# Start game so GameState exists BEFORE tokens are spawned.
	GameManager.start_new_game()
	_spawn_learning_scenario_tokens()
	_connect_signals()
	_update_debug_visibility()
	queue_redraw()
	# The phase_changed and active_player_changed signals fired inside
	# start_new_game() before _connect_signals(), so trigger the initial
	# phase UI and handoff overlay manually.
	_on_phase_changed(GameManager.get_current_phase())
	# Show the initial handoff overlay so the first player must click
	# "Ready" before dials appear — same UX as every subsequent handoff.
	_on_active_player_changed(GameManager.get_active_player())


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
	if _map_texture != null:
		# The map images contain a white border around the 3×3 ft play area.
		# Extract the central 2160×2160 px region (matching the play area).
		var tex_w: float = _map_texture.get_width()
		var tex_h: float = _map_texture.get_height()
		var crop: float = side # 2160 — the play area we want
		var src: Rect2 = Rect2(
				(tex_w - crop) * 0.5, (tex_h - crop) * 0.5, crop, crop)
		draw_texture_rect_region(_map_texture, area, src)
	else:
		draw_rect(area, PLAY_AREA_COLOUR, true)
	draw_rect(area, BORDER_COLOUR, false, BORDER_WIDTH_PX)


func _process(_delta: float) -> void:
	# Move dial drag preview to follow mouse (Phase 4c).
	if _drag_active and _drag_preview:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		_drag_preview.position = mouse - _drag_preview.size * 0.5

	if not DebugMode.has_selection():
		return
	_move_selected_token_to_mouse()


## Intercepts magnify gesture BEFORE the camera when a token is selected,
## converting it to rotation and consuming the event so the camera does not zoom.
## DBG-012 — pinch gesture rotates selected token.
## Also intercepts mouse release during dial drag (Phase 4c).
func _input(event: InputEvent) -> void:
	# Handle dial drag release (Phase 4c).
	if _drag_active and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_handle_drag_release()
			get_viewport().set_input_as_handled()
			return

	if not DebugMode.has_selection():
		return
	if event is InputEventMagnifyGesture:
		_handle_debug_rotate(event as InputEventMagnifyGesture)


## Handles input for debug-mode interactions.
## DBG-003 — must not interfere with camera controls (right-click, scroll).
func _unhandled_input(event: InputEvent) -> void:
	# Maneuver tool: Escape dismisses or cancels selection.
	if _handle_maneuver_tool_escape(event):
		return

	if not DebugMode.enabled:
		return

	if event is InputEventMouseButton:
		_handle_debug_click(event as InputEventMouseButton)


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


## Creates the debug-mode HUD on a CanvasLayer (label + help panel).
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

	_debug_help_panel = DebugHelpPanel.new()
	_debug_help_panel.name = "DebugHelpPanel"
	_debug_help_panel.position = Vector2(10, 44)
	_debug_help_panel.visible = false
	layer.add_child(_debug_help_panel)


## Creates ship card side panels on a CanvasLayer.
## Rebel cards on the left, Imperial cards on the right.
## Rules Reference: SU-026, UI-016, UI-017.
func _create_ship_card_panels() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ShipCardPanelLayer"
	layer.layer = 50
	add_child(layer)

	_rebel_card_panel = ShipCardPanel.new()
	_rebel_card_panel.name = "RebelCardPanel"
	_rebel_card_panel.setup(
			Constants.Faction.REBEL_ALLIANCE, true, 0)
	layer.add_child(_rebel_card_panel)

	_imperial_card_panel = ShipCardPanel.new()
	_imperial_card_panel.name = "ImperialCardPanel"
	_imperial_card_panel.setup(
			Constants.Faction.GALACTIC_EMPIRE, false, 1)
	layer.add_child(_imperial_card_panel)


## Adds a ship instance to the correct faction's card panel.
## Rules Reference: SU-026 — defense tokens placed next to ship card.
func _add_ship_to_card_panel(instance: ShipInstance) -> void:
	if instance.ship_data == null:
		return
	match instance.ship_data.faction:
		Constants.Faction.REBEL_ALLIANCE:
			_rebel_card_panel.add_ship_entry(instance)
		Constants.Faction.GALACTIC_EMPIRE:
			_imperial_card_panel.add_ship_entry(instance)


## Updates the position of both ship card panels based on viewport size.
func _update_card_panel_positions() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_rebel_card_panel.update_position(vp_size)
	_imperial_card_panel.update_position(vp_size)


## Connects EventBus and DebugMode signals relevant to the board.
func _connect_signals() -> void:
	EventBus.firing_arc_toggled.connect(_on_firing_arc_toggled)
	DebugMode.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugMode.save_positions_requested.connect(_on_save_positions)
	get_tree().root.size_changed.connect(_on_viewport_resized)
	# Command phase signals.
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.round_started.connect(_on_round_started)
	EventBus.command_picker_requested.connect(_on_command_picker_requested)
	EventBus.command_picker_confirmed.connect(_on_picker_confirmed)
	EventBus.command_dial_order_requested.connect(_on_command_dial_order_requested)
	EventBus.command_phase_complete.connect(_on_command_phase_complete)
	# Turn management signals.
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.handoff_accepted.connect(_on_handoff_accepted)
	# Ship activation drag-and-drop (Phase 4c).
	EventBus.dial_drag_started.connect(_on_dial_drag_started)
	EventBus.activation_ended.connect(_on_board_activation_ended)
	# Maneuver tool (Phase 5a).
	EventBus.maneuver_tool_requested.connect(_on_maneuver_tool_requested)
	EventBus.maneuver_tool_dismissed.connect(_dismiss_maneuver_tool)


## Places all Learning Scenario tokens from setup data and loads the map image.
## Also creates [ShipInstance] / [SquadronInstance] runtime objects, registers
## them in [GameState] so GameManager tracks dial submission, binds instances
## to visual tokens, and adds ship cards to the side panels.
## Rules Reference: "Learning Scenario Setup", step 9, p.5; SU-010–030.
func _spawn_learning_scenario_tokens() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	_load_map_texture(setup.get_map_image_filename())
	var ship_placements: Array[TokenPlacement] = setup.get_ship_placements()
	var squad_placements: Array[TokenPlacement] = setup.get_squadron_placements()
	var ship_instances: Array[ShipInstance] = setup.create_ship_instances()
	var squad_instances: Array[SquadronInstance] = setup.create_squadron_instances()
	# Register the SAME instances in GameManager's GameState so that the
	# auto-submit logic in GameManager sees the same objects the picker
	# assigns dials to. Do NOT call populate_game_state() — that creates
	# separate duplicate instances.
	_register_instances_in_game_state(ship_instances, squad_instances)
	# Spawn ship tokens and bind instances (same order as placements).
	for i: int in range(ship_placements.size()):
		var token: ShipToken = _spawn_ship_token(ship_placements[i])
		if i < ship_instances.size():
			token.bind_instance(ship_instances[i])
			_add_ship_to_card_panel(ship_instances[i])
	# Spawn squadron tokens and bind instances.
	for i: int in range(squad_placements.size()):
		var token: SquadronToken = _spawn_squadron_token(squad_placements[i])
		if i < squad_instances.size():
			token.bind_instance(squad_instances[i])
	_log.info("Spawned %d tokens for the Learning Scenario." %
			_token_container.get_child_count())
	# Update panel positions now that entries have been added.
	_update_card_panel_positions()


## Instantiates and configures a ShipToken for the given placement.
## Returns the created token.
func _spawn_ship_token(
		placement: TokenPlacement) -> ShipToken:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	_token_container.add_child(token)
	token.setup(placement)
	token.token_clicked.connect(_on_token_clicked)
	return token


## Loads a map background texture from the maps/ folder.
## [param filename] — the image filename from the scenario JSON (may be empty).
func _load_map_texture(filename: String) -> void:
	if filename.is_empty():
		_log.info("No map_image configured in scenario — using solid background.")
		return
	_map_texture = AssetLoader.load_texture("maps/", filename)
	if _map_texture != null:
		_log.info("Loaded map background: %s" % filename)
	else:
		_log.warn("Map image not found: maps/%s — using solid background." % filename)


## Instantiates and configures a SquadronToken for the given placement.
## Returns the created token.
func _spawn_squadron_token(
		placement: TokenPlacement) -> SquadronToken:
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	_token_container.add_child(token)
	token.setup(placement)
	token.token_clicked.connect(_on_squadron_clicked)
	return token


## Called when a ship token is clicked.
func _on_token_clicked(token: ShipToken) -> void:
	if _maneuver_tool_selecting:
		_show_maneuver_tool(token)
		return
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


## Repositions ship card panels and turn-management UI when the window is
## resized.
func _on_viewport_resized() -> void:
	_update_card_panel_positions()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if _handoff_overlay != null:
		_handoff_overlay.update_size(vp_size)
	if _your_turn_banner != null:
		_your_turn_banner.update_size(vp_size)
	if _end_activation_button != null:
		_end_activation_button.update_position(vp_size)
	if _action_toolbar != null:
		_action_toolbar.update_position(vp_size)
	if _show_activation_button != null:
		_show_activation_button.update_position(vp_size)
	if _activation_modal != null and _activation_modal.visible:
		_activation_modal.centre_on_screen(vp_size)


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
	if _debug_help_panel:
		_debug_help_panel.visible = on


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


# ---------------------------------------------------------------------------
# Game state registration
# ---------------------------------------------------------------------------

## Registers ship and squadron instances into the active [GameState] so
## that [GameManager]'s auto-submit logic sees the same objects the UI
## operates on. Also sets faction and initiative per the Learning Scenario.
## Rules Reference: SU-020 — Rebel has initiative.
func _register_instances_in_game_state(
		ships: Array[ShipInstance],
		squads: Array[SquadronInstance]) -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	gs.initiative_player = 0 # Rebel has initiative (SU-020).
	var rebel_ps: PlayerState = gs.get_player_state(0)
	var imperial_ps: PlayerState = gs.get_player_state(1)
	rebel_ps.faction = Constants.Faction.REBEL_ALLIANCE
	imperial_ps.faction = Constants.Faction.GALACTIC_EMPIRE
	for ship: ShipInstance in ships:
		if ship.ship_data == null:
			continue
		if ship.ship_data.faction == Constants.Faction.GALACTIC_EMPIRE:
			imperial_ps.ships.append(ship)
		else:
			rebel_ps.ships.append(ship)
	for squad: SquadronInstance in squads:
		if squad.squadron_data == null:
			continue
		if squad.squadron_data.faction == Constants.Faction.GALACTIC_EMPIRE:
			imperial_ps.squadrons.append(squad)
		else:
			rebel_ps.squadrons.append(squad)


# ---------------------------------------------------------------------------
# Command-phase UI creation
# ---------------------------------------------------------------------------

## Instantiates the [CommandDialPicker] and [CommandDialOrderModal] on a
## CanvasLayer above the card panels so they overlay everything.
func _create_command_phase_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CommandPhaseUILayer"
	layer.layer = 60
	add_child(layer)

	_command_dial_picker = CommandDialPicker.new()
	_command_dial_picker.name = "CommandDialPicker"
	_command_dial_picker.visible = false
	layer.add_child(_command_dial_picker)

	_command_dial_order_modal = CommandDialOrderModal.new()
	_command_dial_order_modal.name = "CommandDialOrderModal"
	_command_dial_order_modal.visible = false
	layer.add_child(_command_dial_order_modal)


## Creates the turn-management UI: handoff overlay, "Your Turn" banner,
## and "End Activation" button on a high-layer CanvasLayer.
## Requirements: HO-001–005, TF-005, TF-011.
func _create_turn_management_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TurnManagementLayer"
	layer.layer = 80
	add_child(layer)

	_handoff_overlay = HandoffOverlay.new()
	_handoff_overlay.name = "HandoffOverlay"
	layer.add_child(_handoff_overlay)

	_your_turn_banner = YourTurnBanner.new()
	_your_turn_banner.name = "YourTurnBanner"
	layer.add_child(_your_turn_banner)

	_end_activation_button = EndActivationButton.new()
	_end_activation_button.name = "EndActivationButton"
	layer.add_child(_end_activation_button)

	# Phase 5b: Show Activation Sequence button.
	_show_activation_button = ShowActivationButton.new()
	_show_activation_button.name = "ShowActivationButton"
	_show_activation_button.activation_sequence_requested.connect(
			_on_activation_sequence_requested)
	layer.add_child(_show_activation_button)

	# Phase 5b: Activation modal (centred, same style as CommandDialPicker).
	_activation_modal = ActivationModal.new()
	_activation_modal.name = "ActivationModal"
	_activation_modal.maneuver_step_entered.connect(
			_on_maneuver_step_entered)
	_activation_modal.maneuver_commit_requested.connect(
			_on_execute_maneuver)
	_activation_modal.modal_closed.connect(
			_on_activation_modal_closed)
	layer.add_child(_activation_modal)


## Creates a phase / round HUD label at the top-centre of the screen.
func _create_phase_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "PhaseHUDLayer"
	layer.layer = 90
	add_child(layer)

	_phase_hud_label = Label.new()
	_phase_hud_label.name = "PhaseHUDLabel"
	_phase_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_hud_label.add_theme_font_size_override("font_size", 20)
	_phase_hud_label.add_theme_color_override(
			"font_color", Color(0.9, 0.85, 0.6))
	_phase_hud_label.text = ""
	# Anchored to top-centre; position updated in _update_phase_hud().
	layer.add_child(_phase_hud_label)
	_update_phase_hud()


# ---------------------------------------------------------------------------
# Phase / round HUD
# ---------------------------------------------------------------------------

## Updates the phase HUD label text and position.
func _update_phase_hud() -> void:
	if _phase_hud_label == null:
		return
	var round_num: int = GameManager.get_current_round()
	var phase: Constants.GamePhase = GameManager.get_current_phase()
	var phase_name: String = PHASE_NAMES.get(phase, "Unknown")
	if round_num > 0:
		_phase_hud_label.text = "Round %d — %s" % [round_num, phase_name]
	else:
		_phase_hud_label.text = phase_name
	# Centre the label horizontally.
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	_phase_hud_label.position = Vector2(
			(vp_size.x - _phase_hud_label.size.x) * 0.5, 8)


# ---------------------------------------------------------------------------
# Command-phase signal handlers
# ---------------------------------------------------------------------------

## Called when the game phase changes.
## Updates the HUD and shows/hides the End Activation button.
## For Command Phase, the dial flow is NOT started here — it is started
## by _on_handoff_accepted() after the player dismisses the overlay.
## For Ship Phase, the End Activation button is hidden until a ship is
## activated via dial drag-and-drop (Phase 4c: UI-024).
## Requirements: TF-005, TF-011.
func _on_phase_changed(new_phase: Constants.GamePhase) -> void:
	_update_phase_hud()
	match new_phase:
		Constants.GamePhase.COMMAND:
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
		Constants.GamePhase.SHIP:
			# Button hidden until a ship is activated via dial drag (Phase 4c).
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
		Constants.GamePhase.SQUADRON:
			# Placeholder — auto-passes immediately.
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
		_:
			_end_activation_button.hide_button()
			_hide_phase5b_ui()


## Called when a new round begins.
func _on_round_started(_round_number: int) -> void:
	_update_phase_hud()


## Builds the ordered queue of ships needing dials and opens the first
## picker. In hot-seat mode, only queues ships for the currently assigning
## player; in network mode, queues both (initiative player first).
## Rules Reference: CP-001 — all ships must be assigned dials.
## Requirements: TF-002 — initiative player assigns first in hot-seat.
func _begin_command_dial_flow() -> void:
	_ships_needing_dials.clear()
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var current_round: int = gs.current_round
	var assigning: int = GameManager.get_command_assigning_player()

	# In hot-seat, only show ships for the assigning player.
	var player_order: Array[int] = []
	if PlayMode.is_hot_seat() and assigning >= 0:
		player_order.append(assigning)
	else:
		player_order.append(gs.initiative_player)
		player_order.append(1 - gs.initiative_player)

	for pi: int in player_order:
		var ps: PlayerState = gs.get_player_state(pi)
		if ps == null:
			continue
		for s: Variant in ps.ships:
			if s is ShipInstance:
				var si: ShipInstance = s as ShipInstance
				if si.command_dial_stack == null:
					continue
				var needed: int = si.command_dial_stack.get_dials_needed()
				if needed > 0:
					_ships_needing_dials.append(si)
	_log.info("Command Phase: %d ships need dials (player %d)." % [
			_ships_needing_dials.size(), assigning])
	_advance_picker_queue()


## Opens the picker for the next ship in the queue, or does nothing
## if the queue is empty (GameManager handles auto-submit).
func _advance_picker_queue() -> void:
	if _ships_needing_dials.is_empty():
		return
	var ship: ShipInstance = _ships_needing_dials[0]
	var current_round: int = GameManager.get_current_round()
	_command_dial_picker.open(ship, current_round)
	_command_dial_picker.centre_on_screen(
			get_viewport().get_visible_rect().size)


## Called when the player explicitly requests the picker for a ship
## (e.g. from the card panel). Opens the picker.
func _on_command_picker_requested(
		ship_ref: RefCounted, current_round: int) -> void:
	if ship_ref is ShipInstance:
		_command_dial_picker.open(
				ship_ref as ShipInstance, current_round)
		_command_dial_picker.centre_on_screen(
				get_viewport().get_visible_rect().size)


## Called when the picker confirms dials for a ship.
## Removes the ship from the queue and advances to the next ship.
## GameManager handles the actual dial assignment and auto-submit.
func _on_picker_confirmed(
		ship_ref: RefCounted, _commands: Array) -> void:
	if ship_ref is ShipInstance:
		var idx: int = _ships_needing_dials.find(
				ship_ref as ShipInstance)
		if idx >= 0:
			_ships_needing_dials.remove_at(idx)
	_advance_picker_queue()


## Called when a ship's dial order is requested (from card panel click).
## Opens the [CommandDialOrderModal].
func _on_command_dial_order_requested(ship_ref: RefCounted) -> void:
	if ship_ref is ShipInstance:
		_command_dial_order_modal.open(ship_ref as ShipInstance)
		_command_dial_order_modal.centre_on_screen(
				get_viewport().get_visible_rect().size)


## Called when the Command Phase completes (both players submitted).
## Updates the HUD.
func _on_command_phase_complete() -> void:
	_ships_needing_dials.clear()
	_log.info("Command Phase complete — advancing to Ship Phase.")
	_update_phase_hud()


# ---------------------------------------------------------------------------
# Turn management signal handlers
# ---------------------------------------------------------------------------

## Called when the active player changes.
## In hot-seat mode, shows the handoff overlay (Command Phase) or "Your Turn"
## banner (Ship / Squadron Phase), rotates the camera, and swaps card panels.
## Requirements: TF-001, BP-001, BP-003, HO-001, HO-004.
func _on_active_player_changed(player_index: int) -> void:
	if not PlayMode.is_hot_seat():
		return

	var phase: Constants.GamePhase = GameManager.get_current_phase()

	# Update viewer on both card panels so the active player can only
	# inspect their own dial stacks.
	# Requirements: UI-023 — cannot view opponent's unrevealed dials.
	_rebel_card_panel.set_viewer_player(player_index)
	_imperial_card_panel.set_viewer_player(player_index)

	# Rotate camera to the new player's perspective.
	# Requirements: BP-001 — camera rotates 180°.
	_camera.rotate_to_player(player_index)

	# Swap card panels so the active player's cards are on the left.
	_swap_card_panels(player_index)

	# Show appropriate overlay / banner.
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	match phase:
		Constants.GamePhase.COMMAND:
			var phase_name: String = PHASE_NAMES.get(phase, "Command Phase")
			_handoff_overlay.show_handoff(player_index, phase_name)
			_handoff_overlay.update_size(vp_size)
		Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON:
			_your_turn_banner.show_banner(player_index)
			_your_turn_banner.update_size(vp_size)


## Called when the handoff overlay or banner is dismissed by the player.
## Resumes the appropriate game flow for the current phase.
## Requirements: HO-002, HO-004.
func _on_handoff_accepted() -> void:
	var phase: Constants.GamePhase = GameManager.get_current_phase()

	match phase:
		Constants.GamePhase.COMMAND:
			# Restart the dial flow for the now-assigned player.
			_begin_command_dial_flow()
		Constants.GamePhase.SHIP:
			# Player is ready — they can now drag a dial to activate a ship.
			# "End Activation" appears only after the dial is dropped (Phase 4c).
			pass
		Constants.GamePhase.SQUADRON:
			pass


## Swaps card panel sides so the active player's faction panel is on the
## left and the opponent's is on the right.
## Requirements: BP-003 — active player's cards always on the left.
func _swap_card_panels(player_index: int) -> void:
	# Player 0 = Rebel, Player 1 = Imperial (Learning Scenario mapping).
	var rebel_left: bool = (player_index == 0)
	_rebel_card_panel.set_side(rebel_left)
	_imperial_card_panel.set_side(not rebel_left)
	_update_card_panel_positions()


## Shows and positions the End Activation button.
func _show_end_activation_button() -> void:
	if _end_activation_button == null:
		return
	_end_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_end_activation_button.update_position(vp_size)


# ---------------------------------------------------------------------------
# Dial drag-and-drop — Ship Activation (Phase 4c)
# ---------------------------------------------------------------------------

## Called when the player clicks on an already-revealed command dial in the
## card panel (second click of the two-step flow). The dial was revealed by
## the first click in ShipCardPanel._handle_dial_stack_click().
## Requirements: UI-024, UI-027.
func _on_dial_drag_started(ship_ref: RefCounted) -> void:
	if not ship_ref is ShipInstance:
		_log.info("dial_drag_started ignored — ship_ref is not ShipInstance.")
		return
	if _drag_active:
		_log.info("dial_drag_started ignored — drag already active.")
		return
	_drag_active = true
	_drag_ship_instance = ship_ref as ShipInstance
	# Dial is already revealed — read the command type for the preview icon.
	var revealed: Dictionary = _drag_ship_instance.command_dial_stack \
			.get_revealed_dial()
	var cmd: int = int(revealed.get("command", 0)) if not revealed.is_empty() \
			else -1
	_create_drag_preview(cmd)
	TooltipManager.show_text(
			"Drag to ship for full command effect\n"
			+"Drag to ship card for command token")
	_log.info("Dial drag started for '%s' (command: %d)." % [
			_drag_ship_instance.data_key, cmd])


## Map from CommandType to icon filename for the drag preview.
const CMD_DRAG_ICON_FILES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}


## Creates a semi-transparent floating dial preview on the TurnManagement layer.
## Shows the dial background with the revealed command icon composited on top
## when [param cmd] is valid, otherwise the hidden dial back.  The preview
## matches the dial size used on the card panel (no enlargement).
func _create_drag_preview(cmd: int = -1) -> void:
	var dial_w: float = GameScale.card_panel_dial_width_px
	var dial_h: float = GameScale.card_panel_dial_height_px

	# Outer container holds the composited dial (background + icon).
	_drag_preview = Control.new()
	_drag_preview.custom_minimum_size = Vector2(dial_w, dial_h)
	_drag_preview.size = Vector2(dial_w, dial_h)
	_drag_preview.modulate.a = 0.75
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dial background (hidden-dial circle).
	var bg_tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", "cmd_dial_hidden.png")
	if bg_tex:
		var bg_rect: TextureRect = TextureRect.new()
		bg_rect.texture = bg_tex
		bg_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_rect.custom_minimum_size = Vector2(dial_w, dial_h)
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_preview.add_child(bg_rect)

	# Command icon on top of the dial background.
	var icon_file: String = CMD_DRAG_ICON_FILES.get(cmd, "")
	if not icon_file.is_empty():
		var icon_tex: Texture2D = AssetLoader.load_texture(
				"command_tokens/", icon_file)
		if icon_tex:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_size: float = dial_h * 0.7
			var icon_offset: float = (dial_h - icon_size) * 0.5
			icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
			icon_rect.position = Vector2(
					(dial_w - icon_size) * 0.5, icon_offset)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_drag_preview.add_child(icon_rect)

	var tm_layer: CanvasLayer = get_node_or_null("TurnManagementLayer")
	if tm_layer:
		tm_layer.add_child(_drag_preview)


## Handles mouse button release during dial drag.
## First checks if the mouse is over the dragged ship's card panel entry
## (convert to token). Falls back to checking ship tokens on the board
## (keep for full effect). Otherwise cancels the drag.
## Requirements: UI-024, UI-028.
func _handle_drag_release() -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()

	# Check card panel drop first (convert to command token).
	var card_hit: ShipInstance = _find_card_panel_hit(screen_pos)
	if card_hit and card_hit == _drag_ship_instance:
		_complete_token_conversion()
		return

	# Check board ship token drop (keep dial for full command effect).
	var world_pos: Vector2 = get_global_mouse_position()
	var target_token: ShipToken = _find_ship_token_at(world_pos)

	if target_token and _is_valid_drop_target(target_token):
		_complete_ship_activation(target_token)
	else:
		_cancel_drag()


## Finds the ship token whose base contains [param world_pos], or null.
func _find_ship_token_at(world_pos: Vector2) -> ShipToken:
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var ship: ShipToken = child as ShipToken
			if ship.is_point_in_base(world_pos):
				return ship
	return null


## Returns true if [param token] is a valid drop target for the current drag.
## The token must be bound to the same ShipInstance being dragged, and the
## ship must not already be activated.
func _is_valid_drop_target(token: ShipToken) -> bool:
	if _drag_ship_instance == null:
		return false
	if token.get_ship_instance() != _drag_ship_instance:
		return false
	if _drag_ship_instance.activated_this_round:
		return false
	return true


## Finds the ShipToken on the board bound to the given ShipInstance.
## Returns null if not found.
func _find_ship_token_for_instance(ship: ShipInstance) -> ShipToken:
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var st: ShipToken = child as ShipToken
			if st.get_ship_instance() == ship:
				return st
	return null


## Completes a ship activation: reveals the dial, shows it behind the base,
## and shows the "Show Activation Sequence" button.
## Requirements: UI-024, UI-025, SP-010, ACT-007, FLOW-002.
func _complete_ship_activation(token: ShipToken) -> void:
	var ship_key: String = _drag_ship_instance.data_key if _drag_ship_instance \
			else "?"
	GameManager.activate_ship(_drag_ship_instance)
	var revealed: Dictionary = _drag_ship_instance.command_dial_stack \
			.get_revealed_dial()
	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		token.show_revealed_dial(cmd)
	_activating_ship_token = token
	_ship_activation_state = ShipActivationState.create(_drag_ship_instance)
	_clean_up_drag()
	_show_activation_sequence_button()
	_log.info("Ship activated via dial drop: '%s'." % ship_key)


## Completes a "convert to token" activation: reveals and immediately spends
## the dial, attempts to add a matching command token, and shows the End
## Activation button. No revealed dial sprite is shown on the board.
## If overflow triggers a discard prompt, the End Activation button is delayed
## until the player resolves the discard.
## Rules Reference: "Command Dials", p.3 — "spend the command dial to gain
## a command token of the same type."
## Requirements: UI-028, SP-011, CM-004–006.
func _complete_token_conversion() -> void:
	var ship: ShipInstance = _drag_ship_instance
	# Clean up drag state FIRST so that hide_tooltip() fires before
	# activate_ship_as_token() emits duplicate/overflow signals that may
	# call show_text() again (preventing the toast from being killed).
	_clean_up_drag()
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	_ship_activation_state = ShipActivationState.create(ship)
	_activating_ship_token = _find_ship_token_for_instance(ship)

	var needs_discard: bool = result.get("needs_discard", false)
	if needs_discard:
		# Delay activation sequence button until the discard is resolved.
		if not EventBus.token_discarded.is_connected(
				_on_token_discard_resolved):
			EventBus.token_discarded.connect(
					_on_token_discard_resolved, CONNECT_ONE_SHOT)
	else:
		_show_activation_sequence_button()

	var cmd_name: String = ""
	if not result.is_empty():
		cmd_name = Constants.CommandType.keys()[result["command"]]
	_log.info("Ship activated via card drop (token convert): '%s' (%s, added=%s, discard=%s)." % [
			ship.data_key if ship else "?", cmd_name,
			str(result.get("token_added", false)),
			str(needs_discard)])


## Called (one-shot) when the player resolves a token overflow discard.
## Shows the activation sequence button now that the token count is legal.
func _on_token_discard_resolved(_ship: RefCounted, _discarded: int) -> void:
	_show_activation_sequence_button()
	_log.info("Token discard resolved — showing activation sequence button.")


## Checks both card panels for a ship entry at [param screen_pos].
## Returns the [ShipInstance] if found, or null.
func _find_card_panel_hit(screen_pos: Vector2) -> ShipInstance:
	if _rebel_card_panel:
		var hit: ShipInstance = _rebel_card_panel \
				.get_ship_instance_at_screen_pos(screen_pos)
		if hit:
			return hit
	if _imperial_card_panel:
		var hit: ShipInstance = _imperial_card_panel \
				.get_ship_instance_at_screen_pos(screen_pos)
		if hit:
			return hit
	return null


## Cancels the current dial drag (invalid drop target or no target).
## Unreveals the dial so it returns to the hidden state.
func _cancel_drag() -> void:
	_log.info("Dial drag cancelled.")
	# Unreveal the dial before cleaning up (which clears _drag_ship_instance).
	if _drag_ship_instance:
		_drag_ship_instance.command_dial_stack.unreveal_top()
		EventBus.command_dials_changed.emit(_drag_ship_instance)
	_clean_up_drag()
	EventBus.dial_drag_cancelled.emit()


## Cleans up drag state and removes the floating preview and help text.
func _clean_up_drag() -> void:
	_drag_active = false
	_drag_ship_instance = null
	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null
	TooltipManager.hide_tooltip()


## Called when End Activation is pressed — cleans up the dial sprite on the
## board, activation modal, and resets activation visual state.
## Requirements: UI-026, FLOW-002.
func _on_board_activation_ended() -> void:
	if _activating_ship_token:
		_activating_ship_token.hide_revealed_dial()
		_activating_ship_token = null
	_end_activation_button.hide_button()
	if _show_activation_button:
		_show_activation_button.hide_button()
	if _activation_modal:
		_activation_modal.close_and_clear()
	_ship_activation_state = null
	_dismiss_maneuver_tool()
	# Re-enable simulation maneuver button.
	if _action_toolbar:
		_action_toolbar.set_maneuver_button_disabled(false)


# ---------------------------------------------------------------------------
# Ship Activation Sequence (Phase 5b)
# ---------------------------------------------------------------------------


## Shows the "Show Activation Sequence" button at bottom-centre.
## Replaces the old direct "End Activation" after dial reveal.
## Requirements: ACT-007, FLOW-002.
func _show_activation_sequence_button() -> void:
	if _show_activation_button == null:
		return
	_show_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_show_activation_button.update_position(vp_size)


## Hides all Phase 5b UI elements (activation button, modal).
func _hide_phase5b_ui() -> void:
	if _show_activation_button:
		_show_activation_button.hide_button()
	if _activation_modal:
		_activation_modal.close_and_clear()
	_ship_activation_state = null


## Called when the activation modal is dismissed (Escape or ✕ Close).
## Re-shows the "Show Activation Sequence" button so the player can reopen.
func _on_activation_modal_closed() -> void:
	_log.info("Activation modal dismissed by player.")
	if _ship_activation_state != null and _show_activation_button:
		_show_activation_button.show_button()
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_show_activation_button.update_position(vp_size)


## Called when the player presses "Show Activation Sequence".
## Opens the activation modal and starts the step sequence.
## Requirements: ACT-001, ACT-007.
func _on_activation_sequence_requested() -> void:
	_log.info("Activation sequence requested.")
	if _ship_activation_state == null:
		_log.info("No activation state — cannot open modal.")
		return
	if _activation_modal:
		_activation_modal.open(_ship_activation_state)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_modal.centre_on_screen(vp_size)


## Called when the activation modal reaches the Execute Maneuver step.
## Shows the maneuver tool on the activating ship and the Execute Maneuver
## button. For speed 0, skips the tool and executes immediately.
## Requirements: FLOW-003, AC-5b-03, EXE-004.
func _on_maneuver_step_entered() -> void:
	_log.info("Maneuver step entered.")
	if _ship_activation_state == null or _activating_ship_token == null:
		_log.info("Cannot show maneuver tool — state=%s, token=%s." % [
				str(_ship_activation_state != null),
				str(_activating_ship_token != null)])
		return
	var ship: ShipInstance = _ship_activation_state.get_ship()
	# Speed 0: no tool, ship stays in place, maneuver counts as executed.
	if ship.current_speed == 0:
		_log.info("Speed 0 — executing maneuver without tool.")
		_ship_activation_state.mark_maneuver_executed()
		EventBus.ship_moved.emit(_activating_ship_token)
		_show_end_activation_after_maneuver()
		return
	# Show the maneuver tool in activation mode.
	_dismiss_maneuver_tool()
	# Disable the simulation maneuver button while activation tool is active.
	if _action_toolbar:
		_action_toolbar.set_maneuver_button_disabled(true)
	_maneuver_tool_scene = ManeuverToolScene.new()
	_maneuver_tool_scene.name = "ManeuverToolScene"
	_token_container.add_child(_maneuver_tool_scene)
	_maneuver_tool_scene.setup(_activating_ship_token)
	_maneuver_tool_scene.set_activation_mode(_ship_activation_state)
	# Yaw bonus (Navigate dial) is applied interactively when the player
	# clicks a joint beyond its base limit — not auto-assigned to joint 0.
	# Modal's embedded Execute button is already visible — no extra button needed.


## Called when the player commits the maneuver (modal "Commit ►" button).
## Snaps the ship to the final transform and shows End Activation.
## Requirements: EXE-001, EXE-002, AC-5b-08, AC-5b-09, AC-5b-12, AC-5b-13.
func _on_execute_maneuver() -> void:
	_log.info("Execute maneuver requested.")
	if _ship_activation_state == null or _activating_ship_token == null:
		return
	if _maneuver_tool_scene == null:
		return
	var tool_state: ManeuverToolState = _maneuver_tool_scene.get_state()
	# Compute final transform.
	var attach: Dictionary = _maneuver_tool_scene._compute_attachment()
	var start_pos: Vector2 = attach["position"]
	var start_rot: float = attach["rotation"]
	var ghost_side: String = tool_state.compute_ghost_side()
	var final_xform: Transform2D = tool_state.compute_final_transform(
			start_pos, start_rot, ghost_side)
	# Snap ship to final position.
	_activating_ship_token.global_position = final_xform.origin
	_activating_ship_token.global_rotation = final_xform.get_rotation()
	# Mark maneuver executed.
	_ship_activation_state.mark_maneuver_executed()
	# Emit ship_moved.
	EventBus.ship_moved.emit(_activating_ship_token)
	# Dismiss maneuver tool.
	_dismiss_maneuver_tool()
	# Show End Activation.
	_show_end_activation_after_maneuver()
	_log.info("Ship snapped to final position.")


## Auto-ends the activation after maneuver execution.
## Advances the step to DONE and emits activation_ended so the
## GameManager spends the dial, marks the ship activated, and advances
## the turn — no extra button press required.
## Requirements: AC-5b-11, FLOW-002.
func _show_end_activation_after_maneuver() -> void:
	# Update state to reflect completion before signalling.
	if _ship_activation_state:
		_ship_activation_state.advance_step()  ## MANEUVER → DONE
	# Auto-end the activation (next player's turn).
	EventBus.activation_ended.emit()


# ---------------------------------------------------------------------------
# Maneuver Tool (Phase 5a)
# ---------------------------------------------------------------------------

## Creates the ActionToolbar on a CanvasLayer in the lower-right corner.
## Requirements: MT-U-001, AC-13.
func _create_action_toolbar() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ActionToolbarLayer"
	layer.layer = 95
	add_child(layer)
	_action_toolbar = ActionToolbar.new()
	_action_toolbar.name = "ActionToolbar"
	layer.add_child(_action_toolbar)
	_action_toolbar.setup_buttons()


## Handles the "Display Maneuver Tool" button press.
## Requirements: MT-U-002, MT-U-003.
func _on_maneuver_tool_requested() -> void:
	# Block simulation requests while the activation-mode maneuver tool
	# is active — the player must use the modal's Commit button instead.
	if _ship_activation_state != null and _maneuver_tool_scene != null:
		_log.info("Simulation maneuver blocked — activation maneuver in progress.")
		return
	if _maneuver_tool_scene:
		_dismiss_maneuver_tool()
		return
	if _maneuver_tool_selecting:
		_cancel_maneuver_tool_selection()
		return
	_maneuver_tool_selecting = true
	TooltipManager.show_text("Select a ship", Vector2.INF, 0.0, true)
	_log.info("Maneuver tool: ship selection mode active.")


## Shows the maneuver tool attached to the given ship token.
## Requirements: MT-U-004, MT-G-005, AC-08.
func _show_maneuver_tool(token: ShipToken) -> void:
	_maneuver_tool_selecting = false
	TooltipManager.hide_tooltip()
	if _maneuver_tool_scene:
		_maneuver_tool_scene.queue_free()
	_maneuver_tool_scene = ManeuverToolScene.new()
	_maneuver_tool_scene.name = "ManeuverToolScene"
	_token_container.add_child(_maneuver_tool_scene)
	_maneuver_tool_scene.setup(token)
	_log.info("Maneuver tool displayed on ship.")


## Dismisses the maneuver tool and exits selection mode.
## Requirements: MT-U-005, MT-U-006, AC-15.
func _dismiss_maneuver_tool() -> void:
	_maneuver_tool_selecting = false
	TooltipManager.hide_tooltip()
	# Clear Navigate token spend preview overlay.
	if _ship_activation_state and _ship_activation_state.get_ship():
		EventBus.navigate_token_spend_preview.emit(
				_ship_activation_state.get_ship(), false)
	if _maneuver_tool_scene:
		_maneuver_tool_scene.queue_free()
		_maneuver_tool_scene = null
	_log.info("Maneuver tool dismissed.")


## Cancels ship selection mode without showing the tool.
func _cancel_maneuver_tool_selection() -> void:
	_maneuver_tool_selecting = false
	TooltipManager.hide_tooltip()
	_log.info("Maneuver tool selection cancelled.")


## Checks if an Escape key press should dismiss the maneuver tool.
## Returns true if the event was consumed.
func _handle_maneuver_tool_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _maneuver_tool_scene:
		_dismiss_maneuver_tool()
		get_viewport().set_input_as_handled()
		return true
	if _maneuver_tool_selecting:
		_cancel_maneuver_tool_selection()
		get_viewport().set_input_as_handled()
		return true
	return false

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

## --- Range Overlay state ---

## Whether we are in "select ship for range overlay" mode.
var _range_overlay_selecting: bool = false

## Active RangeOverlayScene instance (null when not displayed).
var _range_overlay_scene: RangeOverlayScene = null

## Targeting list modal (null when not displayed).
var _targeting_list_modal: TargetingListModal = null

## ActionToolbar in the lower-right corner.
var _action_toolbar: ActionToolbar = null

## --- Attack Simulator state (Phase 6a / 6a-2) ---

## Whether we are in "select attacker" mode.
var _attack_sim_selecting: bool = false

## Whether we are in "select target" mode (attacker already chosen).
## Requirements: AS-TGT-001, AS-TGT-010.
var _attack_sim_target_selecting: bool = false

## Attack simulator info panel (null when not displayed).
var _attack_sim_panel: AttackSimPanel = null

## Attack simulator visual-aid overlay (null when not displayed).
var _attack_sim_overlay: AttackSimOverlay = null

## Range overlay shown as part of the attack simulator (separate from the R tool).
var _attack_sim_range_overlay: RangeOverlayScene = null

## --- Attacker state (stored after attacker selection) ---

## The attacking ship token (null if attacker is a squadron).
var _attack_sim_atk_ship: ShipToken = null
## The attacking hull zone (only valid when _attack_sim_atk_ship != null).
var _attack_sim_atk_zone: int = -1
## The attacking squadron token (null if attacker is a ship).
var _attack_sim_atk_squad: SquadronToken = null
## Attacker display name (cached for panel text).
var _attack_sim_atk_name: String = ""
## Attacker zone display name (empty for squadrons).
var _attack_sim_atk_zone_name: String = ""

## --- Target state (stored after target selection) ---

## The defending ship token (null if target is a squadron).
var _attack_sim_def_ship: ShipToken = null
## The defending hull zone (only valid when _attack_sim_def_ship != null).
var _attack_sim_def_zone: int = -1
## The defending squadron token (null if target is a ship).
var _attack_sim_def_squad: SquadronToken = null
## Target display name (cached for panel text).
var _attack_sim_def_name: String = ""
## Target zone display name (empty for squadrons).
var _attack_sim_def_zone_name: String = ""

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

## Tracks whether the currently dragged token was inside its deployment zone
## on the previous frame, so the toast fires only on crossing (DBG-033).
var _was_in_deploy_zone: bool = true

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
	# Show a brief toast if fixed round-1 commands were auto-assigned.
	# Requirements: CP-009, CP-010.
	if GameManager.fixed_commands_applied:
		TooltipManager.show_text(
				"Round 1 commands pre-assigned", Vector2.INF, 3.0)


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
	# Attack simulator: Escape dismisses.
	if _handle_attack_sim_escape(event):
		return
	# Targeting list: Escape dismisses.
	if _handle_targeting_list_escape(event):
		return
	# Range overlay: Escape dismisses or cancels selection.
	if _handle_range_overlay_escape(event):
		return
	# Maneuver tool: Escape dismisses or cancels selection.
	if _handle_maneuver_tool_escape(event):
		return

	# Keyboard shortcuts for tool buttons (M / R / T).
	# Available in all modes; guarded by the same disabled flag as toolbar buttons.
	# Requirements: MT-U-007, RO-008, TL-UI-003a.
	if _handle_tool_shortcut(event):
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
	# Range overlay.
	EventBus.range_overlay_requested.connect(_on_range_overlay_requested)
	EventBus.range_overlay_dismissed.connect(_dismiss_range_overlay)
	# Targeting list (Phase 5d).
	EventBus.targeting_list_requested.connect(_on_targeting_list_requested)
	# Attack simulator (Phase 6a).
	EventBus.attack_simulator_requested.connect(_on_attack_simulator_requested)


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
	# Apply fixed round-1 commands if configured (CP-009, CP-010).
	# Must happen after instances are registered so GameManager can
	# find them in the GameState.
	if setup.has_fixed_round1_commands():
		var fixed_cmds: Dictionary = setup.get_fixed_round1_commands()
		GameManager.apply_fixed_round1_commands(fixed_cmds)
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
	if _attack_sim_target_selecting:
		_attack_sim_handle_target_ship_click(token)
		return
	if _attack_sim_selecting:
		_attack_sim_handle_ship_click(token)
		return
	if _range_overlay_selecting:
		_show_range_overlay(token)
		return
	if _maneuver_tool_selecting:
		_show_maneuver_tool(token)
		return
	if DebugMode.enabled:
		DebugMode.select_token(token)
		_was_in_deploy_zone = true
	else:
		EventBus.element_selected.emit(token)


## Called when a squadron token is clicked.
func _on_squadron_clicked(token: SquadronToken) -> void:
	if _attack_sim_target_selecting:
		_attack_sim_handle_target_squadron_click(token)
		return
	if _attack_sim_selecting:
		_attack_sim_handle_squadron_click(token)
		return
	if DebugMode.enabled:
		DebugMode.select_token(token)
		_was_in_deploy_zone = true
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
## In debug mode, deployment zone constraints are advisory (DBG-032 revised).
## A toast fires when the dragged token crosses outside its zone (DBG-033).
## DBG-011, DBG-020, DBG-032, DBG-033
func _move_selected_token_to_mouse() -> void:
	var token: Node2D = DebugMode.selected_token
	if token == null:
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	var side: float = GameScale.play_area_side_px
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	var enforce_zones: bool = not DebugMode.enabled

	if token is ShipToken:
		_move_ship_token(
				token as ShipToken, mouse_world, side,
				top_y, bottom_y, enforce_zones)
	elif token is SquadronToken:
		_move_squadron_token(
				token as SquadronToken, mouse_world, side,
				top_y, bottom_y, enforce_zones)

	# Check zone crossing for toast warning (debug mode only).
	if DebugMode.enabled:
		_check_zone_crossing_toast(token, top_y, bottom_y)


## Resolves and applies position for a ship token.
## DBG-032, DBG-034 — enforce_zones=false in debug mode.
func _move_ship_token(
		token: ShipToken, desired: Vector2, side: float,
		top_y: float, bottom_y: float, enforce_zones: bool
) -> void:
	var other_ships: Array = _build_other_ship_rects(token)
	var other_squads: Array = _build_other_squad_circles(token)
	var new_pos: Vector2 = _token_mover.resolve_ship_position(
			desired, token.position,
			token.get_ship_size(), token.rotation,
			token.get_faction(),
			other_ships, other_squads,
			top_y, bottom_y, side, enforce_zones)
	token.position = new_pos


## Resolves and applies position for a squadron token.
## DBG-032, DBG-034 — enforce_zones=false in debug mode.
func _move_squadron_token(
		token: SquadronToken, desired: Vector2, side: float,
		top_y: float, bottom_y: float, enforce_zones: bool
) -> void:
	var other_ships: Array = _build_other_ship_rects(token)
	var other_squads: Array = _build_other_squad_circles(token)
	var new_pos: Vector2 = _token_mover.resolve_squadron_position(
			desired, token.position,
			token.get_radius_px(), token.get_faction(),
			other_ships, other_squads,
			top_y, bottom_y, side, enforce_zones)
	token.position = new_pos


## Checks if a dragged token just crossed outside its deployment zone and
## shows a one-shot toast warning. Resets when the token re-enters.
## DBG-033 — advisory toast on zone crossing in debug mode.
func _check_zone_crossing_toast(
		token: Node2D, top_y: float, bottom_y: float
) -> void:
	var faction: Constants.Faction = Constants.Faction.GALACTIC_EMPIRE
	var token_name: String = token.name
	if token is ShipToken:
		faction = (token as ShipToken).get_faction()
		var data: ShipData = (token as ShipToken).get_ship_data()
		if data != null:
			token_name = data.ship_name
	elif token is SquadronToken:
		faction = (token as SquadronToken).get_faction()
		token_name = token.name
	var in_zone: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			token.position.y, faction)
	if _was_in_deploy_zone and not in_zone:
		TooltipManager.show_text(
				"%s is outside deployment zone" % token_name,
				Vector2.INF, 3.0)
	_was_in_deploy_zone = in_zone


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
	_dismiss_range_overlay()
	# Re-enable simulation tool buttons.
	if _action_toolbar:
		_action_toolbar.set_tool_buttons_disabled(false)


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
		_action_toolbar.set_tool_buttons_disabled(true)
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


## Handles keyboard shortcuts for the tool buttons (M / R / T).
## Returns true if the event was consumed.
## Requirements: MT-U-007, RO-008, TL-UI-003a.
func _handle_tool_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if not _are_tool_buttons_enabled():
		return false
	match key_event.keycode:
		KEY_M:
			_log.info("Keyboard shortcut: M (Maneuver Tool).")
			EventBus.maneuver_tool_requested.emit()
			get_viewport().set_input_as_handled()
			return true
		KEY_R:
			_log.info("Keyboard shortcut: R (Range Overlay).")
			EventBus.range_overlay_requested.emit()
			get_viewport().set_input_as_handled()
			return true
		KEY_T:
			_log.info("Keyboard shortcut: T (Targeting List).")
			EventBus.targeting_list_requested.emit()
			get_viewport().set_input_as_handled()
			return true
		KEY_A:
			_log.info("Keyboard shortcut: A (Attack Simulator).")
			EventBus.attack_simulator_requested.emit()
			get_viewport().set_input_as_handled()
			return true
	return false


## Returns true when the toolbar action buttons are interactable.
## Mirrors the disabled state applied by [method ActionToolbar.set_tool_buttons_disabled].
func _are_tool_buttons_enabled() -> bool:
	if _action_toolbar == null:
		return false
	if _action_toolbar._maneuver_tool_btn and _action_toolbar._maneuver_tool_btn.disabled:
		return false
	return true


# ---------------------------------------------------------------------------
# Range Overlay
# ---------------------------------------------------------------------------

## Handles the "Range Overlay" button press.
## Toggle behaviour: if an overlay is already visible, dismiss it.
## If selecting, cancel selection. Otherwise enter selection mode.
## When a maneuver tool is active, toggles the overlay on the ghost
## preview instead of requiring ship selection.
## Requirements: RO-001, RO-002.
func _on_range_overlay_requested() -> void:
	# If a maneuver tool is active, toggle the overlay on the ghost.
	if _maneuver_tool_scene:
		_maneuver_tool_scene.toggle_ghost_range_overlay()
		return
	if _range_overlay_scene:
		_dismiss_range_overlay()
		return
	if _range_overlay_selecting:
		_cancel_range_overlay_selection()
		return
	_range_overlay_selecting = true
	TooltipManager.show_text("Select a ship", Vector2.INF, 0.0, true)
	_log.info("Range overlay: ship selection mode active.")


## Shows the range overlay attached to the given ship token.
## Requirements: RO-003, RO-004, RO-005, RO-006.
func _show_range_overlay(token: ShipToken) -> void:
	_range_overlay_selecting = false
	TooltipManager.hide_tooltip()
	if _range_overlay_scene:
		_range_overlay_scene.queue_free()
	_range_overlay_scene = RangeOverlayScene.new()
	_range_overlay_scene.name = "RangeOverlayScene"
	_token_container.add_child(_range_overlay_scene)
	# Move to index 0 so it draws above the map but behind all tokens.
	_token_container.move_child(_range_overlay_scene, 0)
	_range_overlay_scene.setup(token)
	_log.info("Range overlay displayed on ship.")


## Dismisses the range overlay and exits selection mode.
## Requirements: RO-007.
func _dismiss_range_overlay() -> void:
	_range_overlay_selecting = false
	TooltipManager.hide_tooltip()
	if _range_overlay_scene:
		_range_overlay_scene.queue_free()
		_range_overlay_scene = null
	_log.info("Range overlay dismissed.")


## Cancels ship selection mode without showing the overlay.
func _cancel_range_overlay_selection() -> void:
	_range_overlay_selecting = false
	TooltipManager.hide_tooltip()
	_log.info("Range overlay selection cancelled.")


## Checks if an Escape key press should dismiss the range overlay.
## Returns true if the event was consumed.
func _handle_range_overlay_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _range_overlay_scene:
		_dismiss_range_overlay()
		get_viewport().set_input_as_handled()
		return true
	if _range_overlay_selecting:
		_cancel_range_overlay_selection()
		get_viewport().set_input_as_handled()
		return true
	return false


# ---------------------------------------------------------------------------
# Targeting List (Phase 5d)
# ---------------------------------------------------------------------------

## Handles the "Targeting List" button press.
## Toggle behaviour: if the modal is visible, close it. Otherwise open it.
## Requirements: TL-UI-001, TL-UI-003, TL-UI-004.
func _on_targeting_list_requested() -> void:
	if _targeting_list_modal and _targeting_list_modal.visible:
		_dismiss_targeting_list()
		return
	_show_targeting_list()


## Builds the targeting data and opens the modal.
func _show_targeting_list() -> void:
	_dismiss_targeting_list()
	var ships_info: Array = _collect_ship_infos()
	var squads_info: Array = _collect_squad_infos()
	var active_player: int = GameManager.get_active_player()
	var ghost: TargetingListBuilder.ShipInfo = _collect_ghost_info()
	var build_result: TargetingListBuilder.BuildResult = TargetingListBuilder.build(
			ships_info, squads_info, active_player, ghost)
	# Create the modal on a CanvasLayer so it's always on top.
	if _targeting_list_modal == null:
		_targeting_list_modal = TargetingListModal.new()
		# Add on a CanvasLayer for screen-space display.
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "TargetingListLayer"
		layer.layer = 90
		add_child(layer)
		layer.add_child(_targeting_list_modal)
	_targeting_list_modal.show_results(build_result)
	_log.info("Targeting list opened.")


## Closes the targeting list modal.
func _dismiss_targeting_list() -> void:
	if _targeting_list_modal:
		_targeting_list_modal.close()
	_log.info("Targeting list dismissed.")


## Checks if an Escape key press should dismiss the targeting list.
## Returns true if the event was consumed.
func _handle_targeting_list_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _targeting_list_modal and _targeting_list_modal.visible:
		_dismiss_targeting_list()
		get_viewport().set_input_as_handled()
		return true
	return false


## Collects ShipInfo data from all ship tokens on the board.
func _collect_ship_infos() -> Array:
	var infos: Array = []
	var tokens: Array[ShipToken] = get_ship_tokens()
	for token: ShipToken in tokens:
		var info: TargetingListBuilder.ShipInfo = TargetingListBuilder.ShipInfo.new()
		var inst: ShipInstance = token.get_ship_instance()
		info.ship_name = token.get_ship_data().ship_name if token.get_ship_data() else "Unknown"
		info.data_key = inst.data_key if inst else ""
		info.owner_player = inst.owner_player if inst else 0
		info.pos = token.global_position
		info.rot = token.global_rotation
		info.half_w = token.get_half_width()
		info.half_l = token.get_half_length()
		info.arc_pts = token.get_firing_arc_world_points()
		info.los_pts = token.get_los_origins_world()
		var sd: ShipData = token.get_ship_data()
		if sd:
			info.battery_armament = sd.battery_armament
			info.anti_squadron_armament = sd.anti_squadron_armament
		infos.append(info)
	return infos


## Collects SquadInfo data from all squadron tokens on the board.
## Requirements: TL-LIST-010.
func _collect_squad_infos() -> Array:
	var infos: Array = []
	var tokens: Array[SquadronToken] = get_squadron_tokens()
	for token: SquadronToken in tokens:
		var info: TargetingListBuilder.SquadInfo = TargetingListBuilder.SquadInfo.new()
		var inst: SquadronInstance = token.get_squadron_instance()
		if inst and inst.squadron_data:
			info.squad_name = inst.squadron_data.squadron_name
			info.battery_armament = inst.squadron_data.battery_armament
			info.anti_squadron_armament = inst.squadron_data.anti_squadron_armament
		else:
			info.squad_name = "Squadron"
		info.owner_player = inst.owner_player if inst else 0
		info.pos = token.global_position
		info.radius = token.get_radius_px()
		infos.append(info)
	return infos


## Collects ghost ship info from the maneuver tool if active.
## Returns null if no ghost is present.
## Requirements: TL-LIST-004.
func _collect_ghost_info() -> TargetingListBuilder.ShipInfo:
	if _maneuver_tool_scene == null:
		return null
	if not _maneuver_tool_scene.has_method("get_ghost_transform"):
		return null
	var ghost_data: Dictionary = _maneuver_tool_scene.get_ghost_transform()
	if ghost_data.is_empty():
		return null
	var info: TargetingListBuilder.ShipInfo = TargetingListBuilder.ShipInfo.new()
	info.ship_name = ghost_data.get("ship_name", "Ghost")
	info.data_key = ghost_data.get("data_key", "")
	info.owner_player = ghost_data.get("owner_player", 0)
	info.pos = ghost_data.get("position", Vector2.ZERO)
	info.rot = ghost_data.get("rotation", 0.0)
	info.half_w = ghost_data.get("half_w", 0.0)
	info.half_l = ghost_data.get("half_l", 0.0)
	info.arc_pts = ghost_data.get("arc_pts", {})
	info.los_pts = ghost_data.get("los_pts", {})
	info.battery_armament = ghost_data.get("battery_armament", {})
	info.anti_squadron_armament = ghost_data.get("anti_squadron_armament", {})
	return info


# ---------------------------------------------------------------------------
# Attack Simulator (Phase 6a)
# ---------------------------------------------------------------------------

## Maps Constants.HullZone values to their firing-arc boundary key pairs.
## Each entry has "inner_a"/"outer_a" (left boundary) and
## "inner_b"/"outer_b" (right boundary).
const _ATTACK_SIM_ARC_KEYS: Dictionary = {
	Constants.HullZone.FRONT: {
		"inner_a": "inner_point_front_left",
		"outer_a": "outer_point_front_left",
		"inner_b": "inner_point_front_right",
		"outer_b": "outer_point_front_right",
	},
	Constants.HullZone.LEFT: {
		"inner_a": "inner_point_front_left",
		"outer_a": "outer_point_front_left",
		"inner_b": "inner_point_rear_left",
		"outer_b": "outer_point_rear_left",
	},
	Constants.HullZone.RIGHT: {
		"inner_a": "inner_point_front_right",
		"outer_a": "outer_point_front_right",
		"inner_b": "inner_point_rear_right",
		"outer_b": "outer_point_rear_right",
	},
	Constants.HullZone.REAR: {
		"inner_a": "inner_point_rear_left",
		"outer_a": "outer_point_rear_left",
		"inner_b": "inner_point_rear_right",
		"outer_b": "outer_point_rear_right",
	},
}

## Human-readable zone names for logging and panel display.
const _ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}


## Handles the "Attack Simulator" button/key press.
## Toggle behaviour: if already active, dismiss. Otherwise activate
## and dismiss any other active tool first.
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
func _on_attack_simulator_requested() -> void:
	if _attack_sim_selecting or _attack_sim_target_selecting \
			or (_attack_sim_panel and _attack_sim_panel.visible):
		_dismiss_attack_sim()
		return
	# Dismiss other tools first (AS-ACT-005).
	_dismiss_range_overlay()
	_dismiss_targeting_list()
	_dismiss_maneuver_tool()
	_activate_attack_sim()


## Enters attacker-selection mode and shows the info panel.
## Requirements: AS-ACT-001, AS-PNL-001, AS-PNL-002.
func _activate_attack_sim() -> void:
	_attack_sim_selecting = true
	# Create the info panel on a CanvasLayer for screen-space display.
	if _attack_sim_panel == null:
		_attack_sim_panel = AttackSimPanel.new()
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "AttackSimPanelLayer"
		layer.layer = 90
		add_child(layer)
		layer.add_child(_attack_sim_panel)
	_attack_sim_panel.show_initial()
	_log.info("Attack simulator activated.")


## Dismisses the attack simulator, removing all visual aids and the panel.
## Requirements: AS-ACT-003, AS-PNL-003, AS-TGT-022.
func _dismiss_attack_sim() -> void:
	_attack_sim_selecting = false
	_attack_sim_target_selecting = false
	_attack_sim_clear_attacker_state()
	_attack_sim_clear_target_state()
	# Remove info panel.
	if _attack_sim_panel:
		_attack_sim_panel.close()
	# Remove visual overlay.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	# Remove attack sim range overlay.
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	_log.info("Attack simulator cancelled.")


## Handles a ship token click during attacker selection.
## Determines the hull zone from the click position and sets up visual aids.
## Requirements: AS-SEL-001, AS-SEL-002.
func _attack_sim_handle_ship_click(token: ShipToken) -> void:
	# Determine hull zone from click position.
	var click_pos: Vector2 = token.get_global_mouse_position()
	var zone: int = token.get_hull_zone_at(click_pos)
	if zone < 0:
		_log.debug("Click outside ship base — ignored.")
		return
	var zone_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
	var ship_name: String = ""
	if token.get_ship_data():
		ship_name = token.get_ship_data().ship_name
	_log.info("Attacker selected: %s — %s arc." % [ship_name, zone_name])
	_log.debug("Click at %s → %s hull zone." % [click_pos, zone_name])
	# Store attacker state.
	_attack_sim_atk_ship = token
	_attack_sim_atk_zone = zone
	_attack_sim_atk_squad = null
	_attack_sim_atk_name = ship_name
	_attack_sim_atk_zone_name = zone_name
	# End attacker selection, enter target selection.
	_attack_sim_selecting = false
	_attack_sim_target_selecting = true
	# Update info panel.
	if _attack_sim_panel:
		_attack_sim_panel.show_hull_zone_selected(ship_name, zone_name)
	# Show visual aids.
	_attack_sim_show_hull_zone_visuals(token, zone)


## Creates the visual aids for a hull zone attacker: range overlay, arc
## boundary lines, and LOS marker.
## Requirements: AS-VIS-001, AS-VIS-002, AS-VIS-003.
func _attack_sim_show_hull_zone_visuals(token: ShipToken,
		zone: int) -> void:
	# Clear any previous visuals.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	# Range overlay (reuse RangeOverlayScene).
	_attack_sim_range_overlay = RangeOverlayScene.new()
	_attack_sim_range_overlay.name = "AttackSimRangeOverlay"
	_token_container.add_child(_attack_sim_range_overlay)
	_token_container.move_child(_attack_sim_range_overlay, 0)
	_attack_sim_range_overlay.setup(token)
	# Firing arc boundary lines + LOS marker via AttackSimOverlay.
	var arc_pts: Dictionary = token.get_firing_arc_world_points()
	var los_pts: Dictionary = token.get_los_origins_world()
	var keys: Dictionary = _ATTACK_SIM_ARC_KEYS.get(zone, {})
	if keys.is_empty() or arc_pts.is_empty():
		_log.warn("No arc boundary data for zone %s." % zone)
		return
	var inner_a: Vector2 = arc_pts.get(keys["inner_a"], Vector2.ZERO)
	var outer_a: Vector2 = arc_pts.get(keys["outer_a"], Vector2.ZERO)
	var inner_b: Vector2 = arc_pts.get(keys["inner_b"], Vector2.ZERO)
	var outer_b: Vector2 = arc_pts.get(keys["outer_b"], Vector2.ZERO)
	var zone_name: String = _ZONE_NAMES.get(zone, "FRONT")
	var los_pos: Vector2 = los_pts.get(zone_name, Vector2.ZERO)
	_attack_sim_overlay = AttackSimOverlay.new()
	_attack_sim_overlay.name = "AttackSimOverlay"
	_token_container.add_child(_attack_sim_overlay)
	_attack_sim_overlay.setup_hull_zone(inner_a, outer_a, inner_b, outer_b,
			los_pos)


## Handles a squadron token click during attacker selection.
## Requirements: AS-SEL-010, AS-SEL-011.
func _attack_sim_handle_squadron_click(token: SquadronToken) -> void:
	var inst: SquadronInstance = token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_log.info("Attacker selected: %s." % squad_name)
	# Store attacker state.
	_attack_sim_atk_ship = null
	_attack_sim_atk_zone = -1
	_attack_sim_atk_squad = token
	_attack_sim_atk_name = squad_name
	_attack_sim_atk_zone_name = ""
	# End attacker selection, enter target selection.
	_attack_sim_selecting = false
	_attack_sim_target_selecting = true
	# Update info panel.
	if _attack_sim_panel:
		_attack_sim_panel.show_squadron_selected(squad_name)
	# Show visual aids.
	_attack_sim_show_squadron_visuals(token)


## Creates the visual aids for a squadron attacker: close-range circle.
## Requirements: AS-VIS-010.
func _attack_sim_show_squadron_visuals(token: SquadronToken) -> void:
	# Clear any previous visuals.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	_attack_sim_overlay = AttackSimOverlay.new()
	_attack_sim_overlay.name = "AttackSimOverlay"
	_token_container.add_child(_attack_sim_overlay)
	_attack_sim_overlay.setup_squadron(
			token.global_position, token.get_radius_px())


# =========================================================================
# Attack Simulator — Target Selection (Phase 6a-2)
# =========================================================================

## Handles a ship token click during target selection.
## Checks for deselection (same attacker hull zone), same-ship guard,
## arc containment, or sets the target.
## Requirements: AS-TGT-001–003, AS-TGT-020–021, AS-TGT-030, AS-ARC-001.
func _attack_sim_handle_target_ship_click(token: ShipToken) -> void:
	var click_pos: Vector2 = token.get_global_mouse_position()
	var zone: int = token.get_hull_zone_at(click_pos)
	if zone < 0:
		_log.debug("Target click outside ship base — ignored.")
		return
	# Check: clicking the attacker hull zone → deselect both (AS-TGT-021).
	if _attack_sim_atk_ship == token and _attack_sim_atk_zone == zone:
		_log.info("Attacker re-clicked — both deselected.")
		_attack_sim_deselect_both()
		return
	# Check: clicking the current target hull zone → deselect target (AS-TGT-020).
	if _attack_sim_def_ship == token and _attack_sim_def_zone == zone:
		_log.info("Target deselected.")
		_attack_sim_deselect_target()
		return
	# Same-ship guard: different zone on the same ship → reject (AS-TGT-030).
	if _attack_sim_atk_ship == token:
		_log.info("Target rejected: same ship as attacker.")
		TooltipManager.show_text("Cannot target the same ship.",
				Vector2.INF, 2.0, true)
		return
	# Arc check for ship attacker → ship target (AS-ARC-001).
	if _attack_sim_atk_ship:
		if not _attack_sim_is_ship_target_in_arc(token, zone):
			_log.info("Target rejected: not in arc.")
			TooltipManager.show_text("Defender is not in arc.",
					Vector2.INF, 2.0, true)
			return
	# New target selected.
	var zone_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
	var ship_name: String = ""
	if token.get_ship_data():
		ship_name = token.get_ship_data().ship_name
	_log.info("Target selected: %s — %s arc." % [ship_name, zone_name])
	# Store target state.
	_attack_sim_def_ship = token
	_attack_sim_def_zone = zone
	_attack_sim_def_squad = null
	_attack_sim_def_name = ship_name
	_attack_sim_def_zone_name = zone_name
	# Compute and display LOS + range.
	_attack_sim_compute_and_show_los()


## Handles a squadron token click during target selection.
## Checks for deselection (same attacker squadron), arc containment,
## or sets the target.
## Requirements: AS-TGT-010–012, AS-TGT-020–021, AS-ARC-001–002.
func _attack_sim_handle_target_squadron_click(token: SquadronToken) -> void:
	# Check: clicking the attacker squadron → deselect both (AS-TGT-021).
	if _attack_sim_atk_squad == token:
		_log.info("Attacker re-clicked — both deselected.")
		_attack_sim_deselect_both()
		return
	# Check: clicking the current target squadron → deselect target (AS-TGT-020).
	if _attack_sim_def_squad == token:
		_log.info("Target deselected.")
		_attack_sim_deselect_target()
		return
	# Arc check for ship attacker → squadron target (AS-ARC-001).
	# Skipped when attacker is a squadron (AS-ARC-002).
	if _attack_sim_atk_ship:
		if not _attack_sim_is_squadron_target_in_arc(token):
			_log.info("Target rejected: not in arc.")
			TooltipManager.show_text("Defender is not in arc.",
					Vector2.INF, 2.0, true)
			return
	# New target selected.
	var inst: SquadronInstance = token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_log.info("Target selected: %s." % squad_name)
	# Store target state.
	_attack_sim_def_ship = null
	_attack_sim_def_zone = -1
	_attack_sim_def_squad = token
	_attack_sim_def_name = squad_name
	_attack_sim_def_zone_name = ""
	# Compute and display LOS + range.
	_attack_sim_compute_and_show_los()


## Deselects the target only; returns to "Select a target" prompt.
## Attacker visuals remain active.
## Requirements: AS-TGT-020.
func _attack_sim_deselect_target() -> void:
	_attack_sim_clear_target_state()
	# Remove target visuals from overlay (keep attacker visuals).
	if _attack_sim_overlay:
		_attack_sim_overlay.clear_target()
	# Restore "Select a target" prompt.
	if _attack_sim_panel:
		if _attack_sim_atk_zone_name != "":
			_attack_sim_panel.show_hull_zone_selected(
					_attack_sim_atk_name, _attack_sim_atk_zone_name)
		else:
			_attack_sim_panel.show_squadron_selected(_attack_sim_atk_name)


## Deselects both attacker and target; returns to initial prompt.
## Requirements: AS-TGT-021.
func _attack_sim_deselect_both() -> void:
	_attack_sim_clear_attacker_state()
	_attack_sim_clear_target_state()
	_attack_sim_target_selecting = false
	_attack_sim_selecting = true
	# Remove all visuals.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	# Show initial prompt.
	if _attack_sim_panel:
		_attack_sim_panel.show_initial()


## Clears stored attacker state.
func _attack_sim_clear_attacker_state() -> void:
	_attack_sim_atk_ship = null
	_attack_sim_atk_zone = -1
	_attack_sim_atk_squad = null
	_attack_sim_atk_name = ""
	_attack_sim_atk_zone_name = ""


## Clears stored target state.
func _attack_sim_clear_target_state() -> void:
	_attack_sim_def_ship = null
	_attack_sim_def_zone = -1
	_attack_sim_def_squad = null
	_attack_sim_def_name = ""
	_attack_sim_def_zone_name = ""


## Computes LOS and range between attacker and target, then updates the
## overlay and info panel with the results.
## Requirements: AS-VIS-020–022, AS-PNL-011, AS-LOG-010, AS-RNG-010–014.
func _attack_sim_compute_and_show_los() -> void:
	# Determine LOS endpoints and trace result.
	var endpoints: Dictionary = _attack_sim_compute_los_endpoints()
	var atk_pt: Vector2 = endpoints["atk"]
	var def_pt: Vector2 = endpoints["def"]
	var los_result: LineOfSightChecker.LOSResult = _attack_sim_trace_los(
			atk_pt, def_pt)
	# Determine overlay status.
	var status: int = AttackSimOverlay.LOSStatus.CLEAR
	var los_text: String = "Clear"
	if not los_result.has_los:
		status = AttackSimOverlay.LOSStatus.BLOCKED
		los_text = "Blocked"
	elif los_result.obstructed:
		status = AttackSimOverlay.LOSStatus.OBSTRUCTED
		if los_result.obstructed_by.size() > 0:
			los_text = "Obstructed by %s" % ", ".join(
					los_result.obstructed_by)
		else:
			los_text = "Obstructed"
	_log.info("LOS: %s." % los_text)
	# Compute range measurement.
	var range_data: Dictionary = _attack_sim_compute_range_endpoints()
	var range_distance: float = range_data.get("distance", INF)
	var range_band: String = Constants.RANGE_BAND_BEYOND
	if range_distance < INF:
		range_band = GameScale.get_range_band(range_distance)
	_log.info("Range: %s (%.0f px)." % [range_band, range_distance])
	# Update overlay: target marker + LOS line + range line.
	if _attack_sim_overlay:
		if _attack_sim_def_ship:
			_attack_sim_overlay.setup_target_hull_zone(def_pt)
		else:
			_attack_sim_overlay.setup_target_squadron(def_pt)
		_attack_sim_overlay.setup_los_line(atk_pt, def_pt, status)
		if range_distance < INF:
			_attack_sim_overlay.setup_range_line(
					range_data["atk_pt"], range_data["def_pt"], range_band)
	# Update panel.
	if _attack_sim_panel:
		_attack_sim_panel.show_target_selected(
				_attack_sim_atk_name, _attack_sim_atk_zone_name,
				_attack_sim_def_name, _attack_sim_def_zone_name,
				los_text, range_band)


## Computes the LOS line endpoints for the current attacker/target pair.
## Returns a Dictionary with "atk" and "def" Vector2 keys.
## Rules Reference: "Line of Sight", p.10.
func _attack_sim_compute_los_endpoints() -> Dictionary:
	var atk_pt: Vector2 = Vector2.ZERO
	var def_pt: Vector2 = Vector2.ZERO
	# Attacker endpoint.
	if _attack_sim_atk_ship:
		# Ship hull zone → targeting point.
		var los_pts: Dictionary = _attack_sim_atk_ship.get_los_origins_world()
		var zone_key: String = _ZONE_NAMES.get(_attack_sim_atk_zone, "FRONT")
		atk_pt = los_pts.get(zone_key, Vector2.ZERO)
	# Defender endpoint (depends on type).
	if _attack_sim_def_ship:
		# Ship hull zone → targeting point.
		var los_pts: Dictionary = _attack_sim_def_ship.get_los_origins_world()
		var zone_key: String = _ZONE_NAMES.get(_attack_sim_def_zone, "FRONT")
		def_pt = los_pts.get(zone_key, Vector2.ZERO)
	if _attack_sim_atk_ship and _attack_sim_def_squad:
		# Ship → Squadron: defender = closest point on squadron base.
		def_pt = RangeFinder.closest_point_on_circle(
				atk_pt,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px())
	if _attack_sim_atk_squad and _attack_sim_def_ship:
		# Squadron → Ship: attacker = closest point on squadron base to
		# defender's targeting point.
		var d_los_pts: Dictionary = _attack_sim_def_ship.get_los_origins_world()
		var d_zone_key: String = _ZONE_NAMES.get(_attack_sim_def_zone, "FRONT")
		def_pt = d_los_pts.get(d_zone_key, Vector2.ZERO)
		atk_pt = RangeFinder.closest_point_on_circle(
				def_pt,
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px())
	if _attack_sim_atk_squad and _attack_sim_def_squad:
		# Squadron → Squadron: both = closest points on each base to the
		# other's centre.
		atk_pt = RangeFinder.closest_point_on_circle(
				_attack_sim_def_squad.global_position,
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px())
		def_pt = RangeFinder.closest_point_on_circle(
				_attack_sim_atk_squad.global_position,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px())
	return {"atk": atk_pt, "def": def_pt}


## Traces LOS between the attacker and target using LineOfSightChecker.
## Builds obstruction bodies from all ships except the attacker/defender.
## Requirements: AS-VIS-022, TL-LOS-001–005.
func _attack_sim_trace_los(atk_pt: Vector2,
		def_pt: Vector2) -> LineOfSightChecker.LOSResult:
	# Build obstruction bodies from all ships excluding attacker and defender.
	var bodies: Array = []
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var st: ShipToken = child as ShipToken
			if st == _attack_sim_atk_ship or st == _attack_sim_def_ship:
				continue
			var sd: ShipData = st.get_ship_data()
			if sd:
				bodies.append(
						LineOfSightChecker.ObstructionBody.from_ship_base(
								sd.ship_name, st.global_position,
								st.rotation, st.get_half_width(),
								st.get_half_length()))
	var obstacles: Array = []  # Future: obstacle tokens.
	# Determine which trace method to use.
	# Ship → Ship
	if _attack_sim_atk_ship and _attack_sim_def_ship:
		var ds: ShipToken = _attack_sim_def_ship
		return LineOfSightChecker.trace_los_ship_to_ship(
				atk_pt, def_pt,
				_attack_sim_def_zone as Constants.HullZone,
				ds.global_position, ds.rotation,
				ds.get_half_width(), ds.get_half_length(),
				bodies, obstacles)
	# Ship → Squadron
	if _attack_sim_atk_ship and _attack_sim_def_squad:
		return LineOfSightChecker.trace_los_ship_to_squadron(
				atk_pt,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px(),
				bodies, obstacles)
	# Squadron → Ship
	if _attack_sim_atk_squad and _attack_sim_def_ship:
		var ds: ShipToken = _attack_sim_def_ship
		return LineOfSightChecker.trace_los_squad_to_ship(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				def_pt,
				_attack_sim_def_zone as Constants.HullZone,
				ds.global_position, ds.rotation,
				ds.get_half_width(), ds.get_half_length(),
				bodies, obstacles)
	# Squadron → Squadron — no hull zone blocking, just obstruction.
	if _attack_sim_atk_squad and _attack_sim_def_squad:
		return LineOfSightChecker.trace_los_squad_to_squad(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px(),
				bodies, obstacles)
	# Fallback (should not happen).
	return LineOfSightChecker.LOSResult.new()


# =========================================================================
# Attack Simulator — Arc Validation (Phase 6a-3)
# =========================================================================

## Returns true if the defending ship hull zone is inside the attacker's
## firing arc.  Only valid when the attacker is a ship hull zone.
## Requirements: AS-ARC-001.
func _attack_sim_is_ship_target_in_arc(
		def_token: ShipToken, def_zone: int) -> bool:
	if not _attack_sim_atk_ship:
		return true
	var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return true  # No arc data → allow.
	var def_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
			def_token.global_position, def_token.rotation,
			def_token.get_half_width(), def_token.get_half_length(),
			def_zone as Constants.HullZone)
	return RangeFinder.is_hull_zone_edge_in_arc(
			def_edge[0], def_edge[1],
			_attack_sim_atk_zone as Constants.HullZone,
			atk_arc_pts)


## Returns true if the defending squadron is inside the attacker's
## firing arc.  Only valid when the attacker is a ship hull zone.
## Requirements: AS-ARC-001.
func _attack_sim_is_squadron_target_in_arc(
		def_token: SquadronToken) -> bool:
	if not _attack_sim_atk_ship:
		return true
	var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return true
	return RangeFinder.is_squadron_in_arc(
			def_token.global_position,
			def_token.get_radius_px(),
			_attack_sim_atk_zone as Constants.HullZone,
			atk_arc_pts)


# =========================================================================
# Attack Simulator — Range Measurement (Phase 6a-3)
# =========================================================================

## Computes the range measurement endpoints and distance for the current
## attacker/target pair.  Returns a Dictionary with "distance" (float),
## "atk_pt" (Vector2), "def_pt" (Vector2).
## Requirements: AS-RNG-010, AS-RNG-011.
func _attack_sim_compute_range_endpoints() -> Dictionary:
	# Ship → Ship
	if _attack_sim_atk_ship and _attack_sim_def_ship:
		var atk_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				_attack_sim_atk_ship.global_position,
				_attack_sim_atk_ship.rotation,
				_attack_sim_atk_ship.get_half_width(),
				_attack_sim_atk_ship.get_half_length(),
				_attack_sim_atk_zone as Constants.HullZone)
		var def_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				_attack_sim_def_ship.global_position,
				_attack_sim_def_ship.rotation,
				_attack_sim_def_ship.get_half_width(),
				_attack_sim_def_ship.get_half_length(),
				_attack_sim_def_zone as Constants.HullZone)
		var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
				.get_firing_arc_world_points()
		return RangeFinder.measure_attack_range_ship_endpoints(
				atk_edge, def_edge,
				_attack_sim_atk_zone as Constants.HullZone,
				atk_arc_pts)
	# Ship → Squadron
	if _attack_sim_atk_ship and _attack_sim_def_squad:
		var atk_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				_attack_sim_atk_ship.global_position,
				_attack_sim_atk_ship.rotation,
				_attack_sim_atk_ship.get_half_width(),
				_attack_sim_atk_ship.get_half_length(),
				_attack_sim_atk_zone as Constants.HullZone)
		var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
				.get_firing_arc_world_points()
		return RangeFinder.measure_attack_range_squadron_endpoints(
				atk_edge,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px(),
				_attack_sim_atk_zone as Constants.HullZone,
				atk_arc_pts)
	# Squadron → Ship
	if _attack_sim_atk_squad and _attack_sim_def_ship:
		var def_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				_attack_sim_def_ship.global_position,
				_attack_sim_def_ship.rotation,
				_attack_sim_def_ship.get_half_width(),
				_attack_sim_def_ship.get_half_length(),
				_attack_sim_def_zone as Constants.HullZone)
		return RangeFinder.measure_range_squad_to_ship(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				def_edge)
	# Squadron → Squadron
	if _attack_sim_atk_squad and _attack_sim_def_squad:
		return RangeFinder.measure_range_squad_to_squad(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px())
	# Fallback.
	return {"distance": INF, "atk_pt": Vector2.ZERO, "def_pt": Vector2.ZERO}


## Checks if an Escape key press should dismiss the attack simulator.
## Returns true if the event was consumed.
## Requirements: AS-ACT-003, AS-TGT-022.
func _handle_attack_sim_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _attack_sim_selecting or _attack_sim_target_selecting \
			or (_attack_sim_panel and _attack_sim_panel.visible):
		_dismiss_attack_sim()
		get_viewport().set_input_as_handled()
		return true
	return false

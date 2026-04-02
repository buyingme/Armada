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

## Victory screen overlay shown when the game ends.
## Requirements: WN-001–004.
var _victory_screen: VictoryScreen = null

## Scoring calculator for live HUD score display.
## Requirements: GF-001–004.
var _scoring: ScoringCalculator = ScoringCalculator.new()

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

## Attack executor — owns all attack simulator / execution logic and UI.
## Created in [method _create_attack_executor].
var _attack_executor: AttackExecutor = null

## Shared damage deck for the game. Initialised during scenario setup.
var _damage_deck: DamageDeck = null

## --- Phase 5b: Activation flow state ---

## "Show Activation Sequence" button (replaces End Activation after dial reveal).
## Requirements: ACT-007, FLOW-002.
var _show_activation_button: ShowActivationButton = null

## Activation modal panel (centred on screen, same style as CommandDialPicker).
## Requirements: ACT-001–004.
var _activation_modal: ActivationModal = null

## Repair panel modal (centred, used during Repair step).
var _repair_panel: RepairPanel = null

## Current ship activation state tracker (nil when not in activation).
## Requirements: FLOW-004.
var _ship_activation_state: ShipActivationState = null

## Tracks whether the currently dragged token was inside its deployment zone
## on the previous frame, so the toast fires only on crossing (DBG-033).
var _was_in_deploy_zone: bool = true

## --- Phase 7b: Squadron Activation flow state ---

## Squadron Activation Modal (bottom-centre, guides through squadron actions).
## Requirements: SQA-001–013.
var _squadron_modal: SquadronActivationModal = null

## "Show Squadron Modal" button (appears when modal is dismissed).
## Requirements: SQA-011, SQA-013.
var _show_squadron_modal_button: ShowSquadronModalButton = null

## Move overlay (movement + armament range circles) shown on squadron select.
## Requirements: SQM-001, SQM-002.
var _squadron_move_overlay: SquadronMoveOverlay = null

## Range overlay (arc-based) shown during squadron command selection.
## Reuses the same RangeOverlayScene as the R-button and attack flow.
## Requirements: CM-020.
var _squad_cmd_range_overlay: RangeOverlayScene = null

## Saved original position of the moving squadron (for revert on cancel).
var _squadron_move_original_pos: Vector2 = Vector2.ZERO

## Maximum movement distance in pixels for the currently moving squadron.
var _squadron_move_max_dist: float = 0.0

## How many squadron activations have been completed this turn.
## Reset in [method _begin_squadron_activation_flow].
var _squadron_activation_count: int = 0

## --- Phase 5b-2: Overlap / displacement state ---

## Queue of displaced squadron tokens awaiting placement by the opponent.
## Populated in [method _start_squadron_displacement].
var _displacement_queue: Array[SquadronToken] = []

## The ship base that displaced the squadrons (for touch-validation).
var _displacement_ship_base: ShipBase = null

## Index into [member _displacement_queue] for the next squadron to place.
var _displacement_index: int = 0

## True while a displaced squadron follows the mouse (snap-to-edge mode).
var _displacement_moving: bool = false

## Displacement modal panel (squadron checklist + commit).
var _displacement_modal: DisplacementModal = null

## CanvasLayer for the displacement modal.
var _displacement_modal_layer: CanvasLayer = null

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
	_create_attack_executor()
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

	# Phase 7b: Squadron follows mouse during MOVING state.
	_move_squadron_during_activation()

	# Phase 5b-2: Displaced squadron follows mouse, snapped to ship edge.
	_move_displaced_squadron_to_mouse()

	if not DebugMode.has_selection():
		return
	_move_selected_token_to_mouse()


## Intercepts magnify gesture BEFORE the camera when a token is selected,
## converting it to rotation and consuming the event so the camera does not zoom.
## DBG-012 — pinch gesture rotates selected token.
## Also intercepts mouse release during dial drag (Phase 4c).
## Also intercepts squadron placement clicks/Escape in MOVING state —
## must run in _input so the event is consumed before GUI Controls
## (the SquadronActivationModal panel) and before SquadronToken's
## _unhandled_input (which would eat the click since the token follows
## the mouse).
func _input(event: InputEvent) -> void:
	# Phase 7b: Squadron movement — intercept before GUI / token can consume.
	if _handle_squadron_move_input(event):
		return
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
	# Squadron displacement: left-click locks the currently moving squadron.
	if _displacement_moving and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_lock_displacement_position()
			get_viewport().set_input_as_handled()
			return
	# Attack simulator: Escape dismisses.
	if _attack_executor and _attack_executor.handle_escape(event):
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
	# Attack simulator (Phase 6a) — delegated to AttackExecutor.
	EventBus.attack_simulator_requested.connect(_on_attack_simulator_requested)
	# Game end (Phase 8).
	EventBus.game_ended.connect(_on_game_ended)
	# Live score updates in HUD (Phase 8c).
	EventBus.ship_destroyed.connect(_on_score_changed)
	EventBus.squadron_destroyed.connect(_on_score_changed)


## Places all Learning Scenario tokens from setup data and loads the map image.
## Also creates [ShipInstance] / [SquadronInstance] runtime objects, registers
## them in [GameState] so GameManager tracks dial submission, binds instances
## to visual tokens, and adds ship cards to the side panels.
## Rules Reference: "Learning Scenario Setup", step 9, p.5; SU-010–030.
func _spawn_learning_scenario_tokens() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	_load_map_texture(setup.get_map_image_filename())
	# Initialise the shared damage deck for this game.
	_damage_deck = setup.get_damage_deck()
	# Store on GameState so GameManager can access it for destruction cleanup.
	if GameManager.current_game_state:
		GameManager.current_game_state.damage_deck = _damage_deck
	# Pass deck to the attack executor.
	if _attack_executor:
		_attack_executor.set_damage_deck(_damage_deck)
	# Pass the handoff overlay so the executor can show it for
	# immediate damage card choices (DM-011).
	if _attack_executor and _handoff_overlay:
		_attack_executor.set_handoff_overlay(_handoff_overlay)
	# Wire the effect registry to the attack executor.
	if _attack_executor and GameManager.current_game_state \
			and GameManager.current_game_state.effect_registry:
		_attack_executor.set_effect_registry(
				GameManager.current_game_state.effect_registry)
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
	if _attack_executor and _attack_executor.handle_ship_click(token):
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
	if _attack_executor and _attack_executor.handle_squadron_click(token):
		return
	# Phase 7b: route to squadron activation modal.
	if _squadron_modal != null and _squadron_modal.visible:
		if _squadron_modal.handle_squadron_click(token):
			_on_squadron_selected_in_modal(token)
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
	if _repair_panel != null and _repair_panel.visible:
		_repair_panel.centre_on_screen(vp_size)
	if _show_squadron_modal_button != null:
		_show_squadron_modal_button.update_position(vp_size)


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
		token: Node2D, _top_y: float, _bottom_y: float
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
	_activation_modal.attack_step_entered.connect(
			_on_attack_step_entered)
	_activation_modal.repair_step_entered.connect(
			_on_repair_step_entered)
	_activation_modal.squadron_step_entered.connect(
			_on_squadron_step_entered)
	_activation_modal.squadron_step_skipped.connect(
			_on_squadron_step_skipped)
	_activation_modal.modal_closed.connect(
			_on_activation_modal_closed)
	_activation_modal.end_activation_requested.connect(
			_on_activation_end_requested)
	layer.add_child(_activation_modal)

	# Phase 9: Repair panel (centred, same style as ActivationModal).
	_repair_panel = RepairPanel.new()
	_repair_panel.name = "RepairPanel"
	_repair_panel.repair_done.connect(_on_repair_done)
	_repair_panel.repair_skipped.connect(_on_repair_done)
	layer.add_child(_repair_panel)

	# Phase 7b: Squadron Activation Modal.
	_squadron_modal = SquadronActivationModal.new()
	_squadron_modal.name = "SquadronActivationModal"
	_squadron_modal.move_requested.connect(_on_squadron_move_requested)
	_squadron_modal.move_commit_requested.connect(
			_on_squadron_move_commit)
	_squadron_modal.attack_requested.connect(
			_on_squadron_attack_requested)
	_squadron_modal.activation_done.connect(
			_on_squadron_activation_done)
	_squadron_modal.command_done.connect(
			_on_squadron_command_done)
	_squadron_modal.modal_closed.connect(
			_on_squadron_modal_closed)
	layer.add_child(_squadron_modal)

	# Phase 7b: Show Squadron Modal button.
	_show_squadron_modal_button = ShowSquadronModalButton.new()
	_show_squadron_modal_button.name = "ShowSquadronModalButton"
	_show_squadron_modal_button.squadron_modal_requested.connect(
			_on_show_squadron_modal_requested)
	layer.add_child(_show_squadron_modal_button)


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
## Displays round, phase, and live scores for both players.
## Format: "Round 3 — Ship Phase  |  Rebel: 42  |  Imperial: 0"
## Requirements: GF-001–004, UI-003.
func _update_phase_hud() -> void:
	if _phase_hud_label == null:
		return
	var round_num: int = GameManager.get_current_round()
	var phase: Constants.GamePhase = GameManager.get_current_phase()
	var phase_name: String = PHASE_NAMES.get(phase, "Unknown")
	var base_text: String = ""
	if round_num > 0:
		base_text = "Round %d — %s" % [round_num, phase_name]
	else:
		base_text = phase_name
	# Append live scores when a game is in progress.
	# Player 0 = Rebel Alliance, Player 1 = Galactic Empire.
	var state: GameState = GameManager.current_game_state
	if state != null:
		var rebel_score: int = _scoring.calculate_score(0, state)
		var imperial_score: int = _scoring.calculate_score(1, state)
		base_text += "  |  Rebel: %d  |  Imperial: %d" % [
				rebel_score, imperial_score]
	_phase_hud_label.text = base_text
	# Centre the label horizontally.
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	_phase_hud_label.position = Vector2(
			(vp_size.x - _phase_hud_label.size.x) * 0.5, 8)


## Called when a ship or squadron is destroyed — refreshes the HUD scores.
func _on_score_changed(_token: Node) -> void:
	_update_phase_hud()


# ---------------------------------------------------------------------------
# Game end — Phase 8 (WN-001–004)
# ---------------------------------------------------------------------------

## Called when the game ends (elimination, round 6, or mutual destruction).
## Creates and displays the VictoryScreen overlay.
func _on_game_ended(details: Dictionary) -> void:
	if _victory_screen != null:
		return # Already shown.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "VictoryScreenLayer"
	layer.layer = 110
	add_child(layer)
	_victory_screen = VictoryScreen.new()
	layer.add_child(_victory_screen)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_victory_screen.update_size(vp_size)
	_victory_screen.show_results(details)


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
			# Phase 7b: Squadron modal opens after handoff.
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
			_show_activation_button.hide_button()
		_:
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
			_hide_squadron_phase_ui()


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
	var _current_round: int = gs.current_round
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
			_begin_squadron_activation_flow()


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


## Hides all Squadron Phase UI (modal, reopen button, overlay).
func _hide_squadron_phase_ui() -> void:
	if _squadron_modal:
		_squadron_modal.close_modal()
	if _show_squadron_modal_button:
		_show_squadron_modal_button.hide_button()
	_remove_squadron_overlay()


## Called when the activation modal is dismissed (Escape or ✕ Close).
## Re-shows the "Show Activation Sequence" button so the player can reopen,
## unless the attack panel is currently active (same screen position).
func _on_activation_modal_closed() -> void:
	_log.info("Activation modal dismissed by player.")
	if _ship_activation_state == null or _show_activation_button == null:
		return
	# Do not show the button while the attack executor is active —
	# both occupy the same bottom-centre position.
	if _attack_executor and _attack_executor.is_in_exec_mode():
		return
	# Do not show the button while the squadron command modal is active.
	if _squadron_modal and _squadron_modal.visible \
			and _squadron_modal.is_command_mode():
		return
	_show_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_show_activation_button.update_position(vp_size)


## Called when the player presses "Execute Attack ►" in the activation modal.
## Sets up the attack execution flow: shows the range overlay for the
## activated ship, opens the info panel, and enters hull-zone selection mode.
## Requirements: AE-FLOW-001, AE-ACT-001.
func _on_attack_step_entered() -> void:
	_log.info("Attack step entered — delegating to AttackExecutor.")
	if _ship_activation_state == null or _activating_ship_token == null:
		_log.info("Cannot start attack — no activation state or token.")
		return
	# Hide the "Show Activation Sequence" button while the attack panel
	# is on-screen — both occupy the same bottom-centre position.
	if _show_activation_button:
		_show_activation_button.hide_button()
	if _attack_executor:
		_attack_executor.start_ship_attack(_activating_ship_token)


## Called when the player presses "Execute Repair ►" in the activation modal.
## Creates a RepairResolver and opens the RepairPanel.
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
func _on_repair_step_entered() -> void:
	_log.info("Repair step entered — opening RepairPanel.")
	if _ship_activation_state == null or _activating_ship_token == null:
		_log.info("Cannot start repair — no activation state or token.")
		return
	var ship: ShipInstance = _activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	var resolver: RepairResolver = RepairResolver.create(
			ship, _damage_deck, registry)
	if resolver.is_empty():
		_log.info("No engineering points — auto-advancing repair step.")
		_on_repair_done()
		return
	if not resolver.has_any_repair_target():
		_log.info("Ship at full strength — nothing to repair. "
				+ "Consuming dial/token and auto-advancing.")
		resolver.finalize()
		_on_repair_done()
		return
	if _show_activation_button:
		_show_activation_button.hide_button()
	if _repair_panel:
		_repair_panel.open(resolver, ship)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_repair_panel.centre_on_screen(vp_size)


## Called when the player presses "Execute Squadron ►" in the activation modal.
## Creates a SquadronCommandResolver and opens the SquadronActivationModal
## in command mode.
## Rules Reference: RRG "Commands" p.4 — Squadron; CM-020–CM-022.
func _on_squadron_step_entered() -> void:
	_log.info("Squadron step entered — starting squadron command flow.")
	if _ship_activation_state == null or _activating_ship_token == null:
		_log.info("Cannot start squadron command — no activation state.")
		return
	var ship: ShipInstance = _activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, _activating_ship_token.global_position)
	if resolver.is_empty():
		_log.info("No squadron activations available — auto-advancing.")
		_on_squadron_command_done()
		return
	# Check if there are any eligible friendly squadrons in range.
	var has_target: bool = false
	var tokens: Array[SquadronToken] = get_squadron_tokens()
	for sq_token: SquadronToken in tokens:
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.owner_player == ship.owner_player \
				and resolver.is_squadron_in_range(sq_token.global_position):
			has_target = true
			break
	if not has_target:
		_log.info("No friendly squadrons in range — consuming resources "
				+ "and auto-advancing.")
		resolver.finalize()
		_on_squadron_command_done()
		return
	if _show_activation_button:
		_show_activation_button.hide_button()
	# Show the per-ship range overlay (arcs + range bands) so the
	# player can see which squadrons are within close–medium range.
	_show_squad_cmd_range_overlay(_activating_ship_token)
	if _squadron_modal:
		_squadron_modal.open_for_command(resolver, _activating_ship_token)


## Called when the player presses "Skip" on the squadron step (token only).
## Advances the activation step without entering the squadron command flow.
## Rules Reference: "Commands" p.4 — spending a command token is optional.
func _on_squadron_step_skipped() -> void:
	_log.info("Squadron step skipped by player (token not spent).")
	if _ship_activation_state:
		_ship_activation_state.advance_step()
	if _activation_modal and _ship_activation_state:
		_activation_modal.set_squadron_skippable(
				not _has_squadron_resources(_activating_ship_token))
		_activation_modal.set_squadron_token_only(
				_is_squadron_token_only(_activating_ship_token))
		_activation_modal.set_repair_skippable(
				not _has_repair_resources(_activating_ship_token))
		_activation_modal.set_attack_skippable(
				not _attack_executor.has_any_attack_target(
				_activating_ship_token))
		_activation_modal.open(_ship_activation_state)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_modal.centre_on_screen(vp_size)


## Called when the squadron command flow is complete (all activations used
## or the player finishes early).
## Finalizes the resolver (spends dial/token), advances the activation
## step, and re-opens the activation modal.
## Rules Reference: CM-020.
func _on_squadron_command_done() -> void:
	_log.info("Squadron command done — advancing activation step.")
	_dismiss_squad_cmd_range_overlay()
	if _ship_activation_state:
		_ship_activation_state.advance_step()
	# Show the activation button again.
	if _show_activation_button and _activating_ship_token:
		_show_activation_button.show_button()
	if _activation_modal and _ship_activation_state:
		_activation_modal.set_squadron_skippable(
				not _has_squadron_resources(_activating_ship_token))
		_activation_modal.set_squadron_token_only(
				_is_squadron_token_only(_activating_ship_token))
		_activation_modal.set_repair_skippable(
				not _has_repair_resources(_activating_ship_token))
		_activation_modal.set_attack_skippable(
				not _attack_executor.has_any_attack_target(
				_activating_ship_token))
		_activation_modal.open(_ship_activation_state)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_modal.centre_on_screen(vp_size)


## Called when the repair panel finishes (Done or Skip pressed).
## Advances activation state and re-opens the activation modal.
func _on_repair_done() -> void:
	_log.info("Repair done — advancing activation step.")
	if _ship_activation_state:
		_ship_activation_state.advance_step()
	if _activation_modal and _ship_activation_state:
		_activation_modal.set_squadron_skippable(
				not _has_squadron_resources(_activating_ship_token))
		_activation_modal.set_squadron_token_only(
				_is_squadron_token_only(_activating_ship_token))
		_activation_modal.set_repair_skippable(
				not _has_repair_resources(_activating_ship_token))
		_activation_modal.set_attack_skippable(
				not _attack_executor.has_any_attack_target(
				_activating_ship_token))
		_activation_modal.open(_ship_activation_state)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_modal.centre_on_screen(vp_size)


## Called when the attack execution step is fully complete.
## Advances activation state and re-opens the modal.
## Routes to the squadron modal when a squadron attack just completed.
## Requirements: AE-FLOW-003, AE-CONF-002, SQA-ATK-003.
func _on_attack_exec_completed() -> void:
	_log.info("Attack exec completed — advancing activation step.")
	# Phase 7b: squadron attack completed — route to squadron modal.
	if _squadron_modal and _squadron_modal.get_state() \
			== SquadronActivationModal.State.ATTACKING:
		_squadron_modal.notify_attack_completed()
		return
	if _ship_activation_state:
		_ship_activation_state.advance_step()
	if _activation_modal and _ship_activation_state:
		_activation_modal.set_squadron_skippable(
				not _has_squadron_resources(_activating_ship_token))
		_activation_modal.set_squadron_token_only(
				_is_squadron_token_only(_activating_ship_token))
		_activation_modal.set_repair_skippable(
				not _has_repair_resources(_activating_ship_token))
		_activation_modal.set_attack_skippable(
				not _attack_executor.has_any_attack_target(
				_activating_ship_token))
		_activation_modal.open(_ship_activation_state)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_modal.centre_on_screen(vp_size)


## Called when the player cancels attack execution (Escape).
## Re-opens the activation modal without advancing.
## Routes to the squadron modal when a squadron attack was cancelled.
## Requirements: AE-FLOW-004, SQA-ATK-005.
func _on_attack_exec_cancelled() -> void:
	_log.info("Attack exec cancelled — returning to activation modal.")
	# Phase 7b: squadron attack cancelled — route to squadron modal.
	if _squadron_modal and _squadron_modal.get_state() \
			== SquadronActivationModal.State.ATTACKING:
		_squadron_modal.notify_attack_cancelled()
		return
	if _activation_modal and _ship_activation_state:
		_activation_modal.set_squadron_skippable(
				not _has_squadron_resources(_activating_ship_token))
		_activation_modal.set_squadron_token_only(
				_is_squadron_token_only(_activating_ship_token))
		_activation_modal.set_repair_skippable(
				not _has_repair_resources(_activating_ship_token))
		_activation_modal.set_attack_skippable(
				not _attack_executor.has_any_attack_target(
				_activating_ship_token))
		_activation_modal.open(_ship_activation_state)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_modal.centre_on_screen(vp_size)


## Called when the player presses "Show Activation Sequence".
## Opens the activation modal and starts the step sequence.
## Requirements: ACT-001, ACT-007.
func _on_activation_sequence_requested() -> void:
	_log.info("Activation sequence requested.")
	if _ship_activation_state == null:
		_log.info("No activation state — cannot open modal.")
		return
	if _activation_modal:
		_activation_modal.set_squadron_skippable(
				not _has_squadron_resources(_activating_ship_token))
		_activation_modal.set_squadron_token_only(
				_is_squadron_token_only(_activating_ship_token))
		_activation_modal.set_repair_skippable(
				not _has_repair_resources(_activating_ship_token))
		_activation_modal.set_attack_skippable(
				not _attack_executor.has_any_attack_target(
				_activating_ship_token))
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
## Snaps the ship to the final transform, resolves ship–ship and
## ship–squadron overlaps, then ends the activation.
## Requirements: EXE-001, EXE-002, AC-5b-08, AC-5b-09, AC-5b-12, AC-5b-13,
##     OV-001–004, OV-010–013.
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
	# --- Ship–ship overlap resolution (OV-010–013) ---
	var original_xform: Transform2D = Transform2D(
			_activating_ship_token.global_rotation,
			_activating_ship_token.global_position)
	var ship_size: Constants.ShipSize = _activating_ship_token.get_ship_size()
	var other_bases: Array = _build_other_ship_bases(_activating_ship_token)
	var resolver: OverlapResolver = OverlapResolver.new()
	var result: OverlapResolver.ShipShipResult = (
			resolver.check_ship_ship_overlap(
					tool_state, start_pos, start_rot, ghost_side,
					ship_size, other_bases, original_xform))
	var final_xform: Transform2D = result.final_transform
	# Snap ship to final position.
	_activating_ship_token.global_position = final_xform.origin
	_activating_ship_token.global_rotation = final_xform.get_rotation()
	# Deal overlap damage if any ship–ship overlap occurred.
	if result.overlaps or result.stayed_in_place:
		_apply_overlap_damage(result)
	else:
		# No collision — clear any stale message.
		if _activation_modal:
			_activation_modal.set_collision_message("")
	# --- Ship–squadron overlap resolution (OV-001–004) ---
	var moved_ship_base: ShipBase = ShipBase.new(ship_size, final_xform)
	var displaced: Array[SquadronToken] = _find_displaced_squadrons(
			moved_ship_base)
	# Mark maneuver executed.
	_ship_activation_state.mark_maneuver_executed()
	# Emit ship_moved.
	EventBus.ship_moved.emit(_activating_ship_token)
	# Dismiss maneuver tool.
	_dismiss_maneuver_tool()
	# If squadrons were displaced, start the displacement flow;
	# otherwise end activation immediately.
	if displaced.size() > 0:
		_start_squadron_displacement(displaced, moved_ship_base)
	else:
		_show_end_activation_after_maneuver()
	_log.info("Ship snapped to final position.")


## Shows the activation modal at the DONE step so the player can review
## all completed steps and deliberately end their activation.
## Replaces the previous auto-end behaviour (activation_ended was emitted
## immediately after maneuver).
## Requirements: AC-5b-11, FLOW-002.
func _show_end_activation_after_maneuver() -> void:
	# Update state to reflect completion.
	if _ship_activation_state:
		_ship_activation_state.advance_step() ## MANEUVER → DONE
	# If the modal is still open (normal commit path), just refresh it
	# so it shows all steps checked + "End Activation ►".  If it was
	# closed (displacement path closes it), re-open it.
	if _activation_modal and _ship_activation_state:
		if _activation_modal.is_open():
			_activation_modal.refresh()
		else:
			_activation_modal.open(_ship_activation_state)
	# Re-show the "Show Activation Sequence" button so the player
	# can close and reopen the modal before pressing End Activation.
	_show_activation_sequence_button()


## Called when the player presses "End Activation ►" in the modal.
## Emits activation_ended so GameManager spends the dial, marks the ship
## activated, and advances the turn.
## Rules Reference: RRG "Ship Activation" p.16 — activation ends.
func _on_activation_end_requested() -> void:
	_log.info("Player ended activation via End Activation button.")
	EventBus.activation_ended.emit()


# ---------------------------------------------------------------------------
# Overlap Resolution (Phase 5b-2) — OV-001–013
# ---------------------------------------------------------------------------

## Builds an Array of [ShipBase] for every ship on the board except
## [param exclude].  Used for ship–ship overlap checks.
func _build_other_ship_bases(exclude: ShipToken) -> Array:
	var bases: Array = []
	for token: ShipToken in get_ship_tokens():
		if token == exclude:
			continue
		var inst: ShipInstance = token.get_ship_instance()
		if inst and inst.is_destroyed():
			continue
		var xform: Transform2D = Transform2D(
				token.global_rotation, token.global_position)
		bases.append(ShipBase.new(token.get_ship_size(), xform))
	return bases


## Deals one facedown damage card to both the moving ship and the
## closest overlapping ship after an overlap resolution.
## Rules Reference: RRG "Overlapping", p.8 — OV-011.
func _apply_overlap_damage(result: OverlapResolver.ShipShipResult) -> void:
	var moving_inst: ShipInstance = (
			_activating_ship_token.get_ship_instance())
	# Identify the overlapped ship token.
	var other_token: ShipToken = _get_other_ship_token(
			result.overlapped_ship_index)
	# Build toast text.
	var toast_parts: Array[String] = []
	if result.stayed_in_place:
		toast_parts.append(
				"⚠ Collision detected! Ship stays in place (speed 0).")
	else:
		toast_parts.append(
				"⚠ Collision detected! Speed temporarily reduced to %d (was %d)."
				% [result.final_speed, result.original_speed])
	# Deal one facedown damage to the moving ship.
	_deal_overlap_facedown(moving_inst, _activating_ship_token)
	toast_parts.append("%s takes 1 damage."
			% moving_inst.ship_data.ship_name)
	# Deal one facedown damage to the overlapped ship.
	if other_token:
		var other_inst: ShipInstance = other_token.get_ship_instance()
		if other_inst:
			_deal_overlap_facedown(other_inst, other_token)
			toast_parts.append("%s takes 1 damage."
					% other_inst.ship_data.ship_name)
	# Show collision info inside the activation modal so it's unmissable.
	if _activation_modal:
		_activation_modal.set_collision_message("\n".join(toast_parts))
	_log.info("Overlap damage applied: %s" % " | ".join(toast_parts))


## Deals a single facedown damage card to [param inst] and emits the
## appropriate EventBus signals.  Checks for destruction afterwards.
## Rules Reference: RRG "Overlapping", p.8 — OV-011.
func _deal_overlap_facedown(inst: ShipInstance, token: ShipToken) -> void:
	if _damage_deck == null:
		_log.error("No damage deck — cannot deal overlap damage.")
		return
	var card: DamageCard = _damage_deck.draw_card()
	if card == null:
		_log.error("Damage deck empty — cannot deal overlap damage.")
		return
	inst.add_facedown_damage(card)
	var new_hull: int = inst.ship_data.hull - inst.get_total_damage()
	EventBus.ship_hull_changed.emit(inst, new_hull)
	EventBus.ship_damaged.emit(token, 1, Constants.HullZone.FRONT)
	_log.info("Overlap facedown damage dealt to %s. Hull: %d/%d."
			% [inst.ship_data.ship_name, new_hull, inst.ship_data.hull])
	if inst.is_destroyed():
		_log.info("Ship destroyed by overlap: %s" % inst.data_key)
		EventBus.ship_destroyed.emit(token)
		_fade_out_destroyed_token(token)


## Fades out a destroyed ship token (visual only).
func _fade_out_destroyed_token(token: Node2D) -> void:
	if token == null:
		return
	var tween: Tween = token.create_tween()
	tween.tween_property(token, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		token.visible = false
		token.modulate.a = 1.0
	)


## Returns the [ShipToken] corresponding to an index among the "other"
## ships (excluding the active ship, matching _build_other_ship_bases order).
func _get_other_ship_token(index: int) -> ShipToken:
	if index < 0:
		return null
	var idx: int = 0
	for token: ShipToken in get_ship_tokens():
		if token == _activating_ship_token:
			continue
		var inst: ShipInstance = token.get_ship_instance()
		if inst and inst.is_destroyed():
			continue
		if idx == index:
			return token
		idx += 1
	return null


## Finds all squadron tokens whose bases overlap the given ship base.
## Returns the list of displaced [SquadronToken] nodes.
## Rules Reference: RRG "Overlapping", p.8 — OV-001.
func _find_displaced_squadrons(ship_base: ShipBase) -> Array[SquadronToken]:
	var displaced: Array[SquadronToken] = []
	for sq_token: SquadronToken in get_squadron_tokens():
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.is_destroyed():
			continue
		var sq_base: SquadronBase = SquadronBase.new(
				sq_token.global_position, sq_token.get_radius_px())
		if sq_base.overlaps_ship(ship_base):
			displaced.append(sq_token)
	return displaced


## Starts the squadron displacement flow.  Hides the "Show Activation
## Sequence" button, flips the camera to the opposing player, then
## presents a modal for placing each displaced squadron.
## Rules Reference: RRG "Overlapping", p.8 — OV-002, OV-003.
func _start_squadron_displacement(
		displaced: Array[SquadronToken],
		ship_base: ShipBase) -> void:
	_displacement_queue = displaced.duplicate()
	_displacement_ship_base = ship_base
	_displacement_index = 0
	_displacement_moving = false
	# Disable input on displaced squadron tokens so their _unhandled_input
	# doesn't consume clicks meant for the displacement lock action.
	for sq: SquadronToken in displaced:
		sq.set_process_unhandled_input(false)
	# Hide the activation sequence button during displacement.
	if _show_activation_button:
		_show_activation_button.hide_button()
	if _activation_modal and _activation_modal.is_open():
		_activation_modal.close()
	_log.info("Starting squadron displacement: %d squadron(s)."
			% displaced.size())
	# Flip camera to the opposing player.
	var opponent: int = 1 - GameManager.get_active_player()
	_camera.rotate_to_player(opponent)
	# Wait for the rotation to finish before prompting.
	if not EventBus.perspective_change_complete.is_connected(
			_on_displacement_camera_ready):
		EventBus.perspective_change_complete.connect(
				_on_displacement_camera_ready, CONNECT_ONE_SHOT)


## Called once the camera finishes rotating to the opponent's view.
func _on_displacement_camera_ready() -> void:
	_create_displacement_modal()
	_select_displacement_squadron(_displacement_modal.get_first_unchecked())


## Selects a squadron for placement: auto-places it at the nearest ship
## edge and enters mouse-follow mode.  Updates the modal to highlight
## the active row.
func _select_displacement_squadron(index: int) -> void:
	if index < 0 or index >= _displacement_queue.size():
		return
	_displacement_index = index
	var sq_token: SquadronToken = _displacement_queue[index]
	var sq_radius: float = sq_token.get_radius_px()
	# Auto-place at the nearest ship edge from the old position.
	var snap_pos: Vector2 = OverlapResolver.snap_to_ship_edge(
			sq_token.global_position, sq_radius, _displacement_ship_base)
	sq_token.global_position = snap_pos
	sq_token.visible = true
	_displacement_moving = true
	if _displacement_modal:
		_displacement_modal.set_active(index)
	var sq_name: String = _get_squadron_display_name(sq_token)
	_log.info("Displacement: auto-placed %s at %s — mouse-follow active."
			% [sq_name, str(snap_pos)])


## Each frame, snaps the current displaced squadron to the ship edge
## at the closest point to the mouse cursor.
func _move_displaced_squadron_to_mouse() -> void:
	if not _displacement_moving:
		return
	if _displacement_index >= _displacement_queue.size():
		return
	var sq_token: SquadronToken = _displacement_queue[_displacement_index]
	var mouse_pos: Vector2 = get_global_mouse_position()
	var sq_radius: float = sq_token.get_radius_px()
	var snap_pos: Vector2 = OverlapResolver.snap_to_ship_edge(
			mouse_pos, sq_radius, _displacement_ship_base)
	sq_token.global_position = snap_pos


## Called on left-click during displacement: locks the squadron at its
## current snapped position and checks it in the modal.  Auto-selects
## the next unchecked squadron if one exists.
func _lock_displacement_position() -> void:
	_displacement_moving = false
	var sq_token: SquadronToken = _displacement_queue[_displacement_index]
	var sq_name: String = _get_squadron_display_name(sq_token)
	_log.info("Displacement: %s locked at %s."
			% [sq_name, str(sq_token.global_position)])
	# Check in modal.
	if _displacement_modal:
		_displacement_modal.check_squadron(_displacement_index)
		# Auto-select the next unchecked squadron.
		var next: int = _displacement_modal.get_first_unchecked()
		if next >= 0:
			_select_displacement_squadron(next)


## Called when the modal emits squadron_selected (row click on unchecked).
func _on_displacement_row_selected(index: int) -> void:
	_select_displacement_squadron(index)


## Called when the modal emits squadron_unchecked (row click on checked).
## Un-checks the squadron and re-enters mouse-follow for repositioning.
func _on_displacement_row_unchecked(index: int) -> void:
	_displacement_index = index
	_displacement_moving = true
	if _displacement_modal:
		_displacement_modal.uncheck_squadron(index)
	var sq_name: String = _get_squadron_display_name(
			_displacement_queue[index])
	_log.info("Displacement: %s unchecked for repositioning." % sq_name)


## Called when the modal emits placement_committed (all checked, commit pressed).
func _on_displacement_committed() -> void:
	_log.info("Displacement commit pressed — all squadrons placed.")
	_finish_displacement()


## Finishes the displacement flow: removes modal, flips camera back,
## and ends the activation (triggering normal turn transition + banner).
func _finish_displacement() -> void:
	_displacement_moving = false
	# Re-enable input on displaced squadron tokens.
	for sq: SquadronToken in _displacement_queue:
		sq.set_process_unhandled_input(true)
	_displacement_queue.clear()
	_displacement_ship_base = null
	_remove_displacement_modal()
	TooltipManager.hide_tooltip()
	_log.info("All displaced squadrons placed — flipping camera back.")
	# Flip camera back to the active player.
	var active: int = GameManager.get_active_player()
	_camera.rotate_to_player(active)
	if not EventBus.perspective_change_complete.is_connected(
			_on_displacement_camera_returned):
		EventBus.perspective_change_complete.connect(
				_on_displacement_camera_returned, CONNECT_ONE_SHOT)


## Called when the camera returns to the active player after displacement.
## Fires activation_ended which triggers the normal turn transition
## (GameManager advances turn → active_player_changed → YourTurnBanner).
func _on_displacement_camera_returned() -> void:
	_show_end_activation_after_maneuver()


## Creates the displacement modal on a CanvasLayer and wires its signals.
func _create_displacement_modal() -> void:
	if _displacement_modal_layer != null:
		return
	_displacement_modal_layer = CanvasLayer.new()
	_displacement_modal_layer.name = "DisplacementModalLayer"
	_displacement_modal_layer.layer = 96
	add_child(_displacement_modal_layer)

	_displacement_modal = DisplacementModal.new()
	_displacement_modal.name = "DisplacementModal"
	# Build the names list from the queue.
	var names: Array[String] = []
	for sq_token: SquadronToken in _displacement_queue:
		names.append(_get_squadron_display_name(sq_token))
	_displacement_modal.squadron_selected.connect(
			_on_displacement_row_selected)
	_displacement_modal.squadron_unchecked.connect(
			_on_displacement_row_unchecked)
	_displacement_modal.placement_committed.connect(
			_on_displacement_committed)
	_displacement_modal_layer.add_child(_displacement_modal)
	_displacement_modal.open(names)


## Removes the displacement modal and its CanvasLayer.
func _remove_displacement_modal() -> void:
	if _displacement_modal:
		_displacement_modal.close_and_clear()
	if _displacement_modal_layer:
		_displacement_modal_layer.queue_free()
		_displacement_modal_layer = null
		_displacement_modal = null


## Returns a display-friendly name for a squadron token.
func _get_squadron_display_name(sq_token: SquadronToken) -> String:
	var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
	if sq_inst and sq_inst.squadron_data:
		return sq_inst.squadron_data.squadron_name
	return "Squadron"


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


## Shows the per-ship range overlay (with arcs and range bands) during
## the Squadron command selection step.
## Reuses [RangeOverlayScene] — identical to the R-button overlay.
## Requirements: CM-020.
func _show_squad_cmd_range_overlay(ship_token: ShipToken) -> void:
	_dismiss_squad_cmd_range_overlay()
	_squad_cmd_range_overlay = RangeOverlayScene.new()
	_squad_cmd_range_overlay.name = "SquadCmdRangeOverlay"
	_token_container.add_child(_squad_cmd_range_overlay)
	_token_container.move_child(_squad_cmd_range_overlay, 0)
	_squad_cmd_range_overlay.setup(ship_token)
	_log.info("Squadron command range overlay displayed.")


## Removes the squadron command range band overlay.
func _dismiss_squad_cmd_range_overlay() -> void:
	if _squad_cmd_range_overlay:
		_squad_cmd_range_overlay.queue_free()
		_squad_cmd_range_overlay = null


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
# Attack Executor — Setup & Delegation
# ---------------------------------------------------------------------------


## Creates the [AttackExecutor] child node and wires its signals.
func _create_attack_executor() -> void:
	_attack_executor = AttackExecutor.new()
	_attack_executor.name = "AttackExecutor"
	add_child(_attack_executor)
	_attack_executor.initialize(self , _token_container, _camera)
	_attack_executor.attack_exec_completed.connect(
			_on_attack_exec_completed)
	_attack_executor.attack_exec_cancelled.connect(
			_on_attack_exec_cancelled)
	_attack_executor.dismiss_other_tools_requested.connect(
			_on_dismiss_other_tools_requested)


## Delegates the Attack Simulator toolbar / keyboard toggle to the executor.
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
func _on_attack_simulator_requested() -> void:
	if _attack_executor:
		_attack_executor.on_simulator_requested()


## Called by [signal AttackExecutor.dismiss_other_tools_requested].
## Dismisses range overlay, targeting list, and maneuver tool.
func _on_dismiss_other_tools_requested() -> void:
	_dismiss_range_overlay()
	_dismiss_targeting_list()
	_dismiss_maneuver_tool()


# ---------------------------------------------------------------------------
# Squadron Phase Activation (Phase 7b)
# ---------------------------------------------------------------------------


## Starts the squadron activation flow for the current player.
## Called after the handoff overlay is dismissed.
## Requirements: SQA-001, SQA-TM-001.
func _begin_squadron_activation_flow() -> void:
	_squadron_activation_count = 0
	# Update engagement flags before showing the modal.
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	EngagementResolver.update_engagement_flags(all_squads)
	if _squadron_modal:
		_squadron_modal.open_for_turn(1, Constants.SQUADRONS_PER_ACTIVATION)
	_log.info("Squadron activation flow started for player %d." %
			GameManager.active_player)


## Called after the squadron modal accepts a squadron click.
## Shows the movement + armament range overlay centred on the token.
## Computes action availability and passes it to the modal.
## Requirements: SQM-001, SQM-002.
func _on_squadron_selected_in_modal(token: SquadronToken) -> void:
	_remove_squadron_overlay()
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance == null:
		return
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	var can_move: bool = EngagementResolver.can_squadron_move(
			instance, token.global_position, all_squads)
	var has_targets: bool = _squadron_has_valid_targets(
			instance, token, all_squads)
	var faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE
	if instance.squadron_data:
		faction = instance.squadron_data.faction
	var speed: int = 3
	if instance.squadron_data:
		speed = instance.squadron_data.speed
	# Cache the max move distance for real-time clamping.
	_squadron_move_max_dist = SquadronMover._get_max_move_distance(speed)
	_squadron_move_overlay = SquadronMoveOverlay.new()
	_squadron_move_overlay.name = "SquadronMoveOverlay"
	_token_container.add_child(_squadron_move_overlay)
	_token_container.move_child(_squadron_move_overlay, 0)
	_squadron_move_overlay.setup(
			token.global_position, speed, can_move, faction,
			token.get_radius_px())
	# Tell the modal which actions are available for this squadron.
	_squadron_modal.set_action_availability(can_move, has_targets)
	_log.info("Squadron overlay shown for %s (can_move=%s, targets=%s)." % [
			instance.data_key, str(can_move), str(has_targets)])


## Called when the modal emits [signal SquadronActivationModal.move_requested].
## Saves the original position for real-time mouse following.
## Requirements: SQM-003.
func _on_squadron_move_requested(token: SquadronToken) -> void:
	_squadron_move_original_pos = token.global_position
	# Recompute max distance (safety; already cached in _on_squadron_selected).
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance and instance.squadron_data:
		_squadron_move_max_dist = SquadronMover._get_max_move_distance(
				instance.squadron_data.speed)
	_log.info("Squadron move started — token follows mouse.")


## Called when the modal emits
## [signal SquadronActivationModal.move_commit_requested].
## Finalises the squadron's position, updates engagement, emits EventBus.
## Requirements: SQM-006, SQM-007.
func _on_squadron_move_commit(token: SquadronToken) -> void:
	_remove_squadron_overlay()
	# Update engagement flags for all squadrons after the move.
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	EngagementResolver.update_engagement_flags(all_squads)
	EventBus.squadron_moved.emit(token)
	_log.info("Squadron move committed — engagement updated.")


## Called when the modal emits
## [signal SquadronActivationModal.attack_requested].
## Delegates to the attack executor in squadron mode.
## Requirements: SQA-ATK-001.
func _on_squadron_attack_requested(token: SquadronToken) -> void:
	if _attack_executor:
		_attack_executor.start_squadron_attack(token)
	var key: String = "?"
	var inst: SquadronInstance = token.get_squadron_instance()
	if inst:
		key = inst.data_key
	_log.info("Squadron attack requested for %s." % key)


## Called when a single squadron activation is done.
## Emits the EventBus signal, dims the token visually, removes overlay,
## and opens the modal for the next activation if applicable.
## Requirements: SQA-TM-002, SQA-TM-003, SQA-013.
func _on_squadron_activation_done(instance: SquadronInstance) -> void:
	EventBus.squadron_activation_ended.emit(instance)
	# Dim the activated token.
	var token: SquadronToken = _find_squadron_token_for_instance(instance)
	if token:
		token.set_activated_visual(true)
	_remove_squadron_overlay()
	# In command mode the modal manages the cycle internally;
	# do not touch squadron-phase counters or open_for_turn.
	# Mark activated manually since GameManager ignores SHIP-phase events.
	if _squadron_modal and _squadron_modal.is_command_mode():
		instance.activated_this_round = true
		_log.info("Command-mode activation done: %s" % instance.data_key)
		return
	_squadron_activation_count += 1
	_log.info("Squadron activation done: %s (%d of %d)" % [
			instance.data_key, _squadron_activation_count,
			Constants.SQUADRONS_PER_ACTIVATION])
	# Advance to the next activation if more remain.
	if _squadron_activation_count < Constants.SQUADRONS_PER_ACTIVATION:
		var next_num: int = _squadron_activation_count + 1
		if _squadron_modal:
			_squadron_modal.open_for_turn(
					next_num, Constants.SQUADRONS_PER_ACTIVATION)
	else:
		_log.info("All squadron activations done for player %d." %
				GameManager.active_player)
		_hide_squadron_phase_ui()


## Called when the squadron modal is dismissed by the player.
## Shows the floating ShowSquadronModalButton.
## Requirements: SQA-011.
func _on_squadron_modal_closed() -> void:
	# In command mode, show the activation button instead of the
	# squadron-phase reopen button.
	if _squadron_modal and _squadron_modal.is_command_mode():
		_log.info("Squadron command modal dismissed — show activation button.")
		if _show_activation_button and _ship_activation_state:
			_show_activation_button.show_button()
			_show_activation_button.update_position(
					get_viewport().get_visible_rect().size)
		return
	if _show_squadron_modal_button:
		_show_squadron_modal_button.show_button()
		_show_squadron_modal_button.update_position(
				get_viewport().get_visible_rect().size)
	_log.info("Squadron modal closed — button shown.")


## Called when the player presses the ShowSquadronModalButton.
## Re-shows the squadron modal.
## Requirements: SQA-013.
func _on_show_squadron_modal_requested() -> void:
	if _show_squadron_modal_button:
		_show_squadron_modal_button.hide_button()
	if _squadron_modal:
		_squadron_modal.visible = true
	_log.info("Squadron modal re-opened via button.")


## Handles board input during squadron movement.
## Escape reverts to original position; left-click commits the current pos.
## The token already follows the mouse each frame via
## [method _move_squadron_during_activation].
## Returns true if the event was consumed.
## Requirements: SQM-003, SQM-004, SQM-005.
func _handle_squadron_move_input(event: InputEvent) -> bool:
	if _squadron_modal == null or not _squadron_modal.visible:
		return false
	var modal_state: SquadronActivationModal.State = \
			_squadron_modal.get_state()
	if modal_state != SquadronActivationModal.State.MOVING:
		return false
	var token: SquadronToken = _squadron_modal.get_selected_token()
	if token == null:
		return false
	# Escape: revert position and go back to ACTION_CHOICE.
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			token.global_position = _squadron_move_original_pos
			if _squadron_move_overlay:
				_squadron_move_overlay.reset_tracking()
			_squadron_modal.cancel_move()
			get_viewport().set_input_as_handled()
			return true
	# Left click: commit current position (already clamped + resolved).
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_commit_squadron_placement(token)
			get_viewport().set_input_as_handled()
			return true
	return false


## Commits the squadron's current position after a click during MOVING.
## Validates via [SquadronMover] as a safety check (position was clamped
## in real-time, so this should always pass).
## Requirements: SQM-004, SQM-005.
func _commit_squadron_placement(token: SquadronToken) -> void:
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance == null:
		return
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	var bases: Array[ShipBase] = _build_ship_bases()
	var error: String = SquadronMover.validate_move(
			instance, _squadron_move_original_pos, token.global_position,
			all_squads, bases)
	if error.is_empty():
		# Commit first so engagement flags are up-to-date for target check.
		_on_squadron_move_commit(token)
		# Recalculate targets at the new position and inform the modal.
		var updated_squads: Array[Dictionary] = _build_all_squadron_positions()
		var new_has_targets: bool = _squadron_has_valid_targets(
				instance, token, updated_squads)
		_squadron_modal.set_action_availability(false, new_has_targets)
		_squadron_modal.notify_move_completed()
		_log.info("Squadron placed at %s." % str(token.global_position))
	else:
		_squadron_modal.notify_move_preview_failed(error)
		_log.info("Squadron placement invalid: %s" % error)


## Moves the currently-moving squadron token to follow the mouse each frame.
## The desired position is clamped to the maximum movement distance from
## the original position, then collision-resolved via [TokenMover].
## Requirements: SQM-003.
func _move_squadron_during_activation() -> void:
	if _squadron_modal == null or not _squadron_modal.visible:
		return
	if _squadron_modal.get_state() != SquadronActivationModal.State.MOVING:
		return
	var token: SquadronToken = _squadron_modal.get_selected_token()
	if token == null:
		return
	var desired: Vector2 = get_global_mouse_position()
	# Clamp to max movement distance from original position.
	var offset: Vector2 = desired - _squadron_move_original_pos
	if offset.length() > _squadron_move_max_dist:
		desired = _squadron_move_original_pos + \
				offset.normalized() * _squadron_move_max_dist
	# Resolve collisions (overlap with other tokens / ships).
	var side: float = GameScale.play_area_side_px
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	_move_squadron_token(token, desired, side, top_y, bottom_y, false)
	# Re-clamp after collision resolution — the resolver may push the
	# token slightly past the movement distance.  The visual ring is the
	# single source of truth for movement range.
	var post_offset: Vector2 = token.global_position - _squadron_move_original_pos
	if post_offset.length() > _squadron_move_max_dist:
		token.global_position = _squadron_move_original_pos + \
				post_offset.normalized() * _squadron_move_max_dist
	# Keep the armament (attack range) ring centred on the token.
	if _squadron_move_overlay:
		_squadron_move_overlay.update_tracking_position(token.global_position)


## Removes the squadron movement overlay if present.
func _remove_squadron_overlay() -> void:
	if _squadron_move_overlay:
		_squadron_move_overlay.queue_free()
		_squadron_move_overlay = null


## Finds the [SquadronToken] on the board bound to the given instance.
## Returns null if not found.
func _find_squadron_token_for_instance(
		instance: SquadronInstance) -> SquadronToken:
	for child: Node in _token_container.get_children():
		if child is SquadronToken:
			var st: SquadronToken = child as SquadronToken
			if st.get_squadron_instance() == instance:
				return st
	return null


## Builds an array of {"instance": SquadronInstance, "position": Vector2}
## for all non-destroyed squadrons on the board.
## Used for engagement resolution and move validation.
func _build_all_squadron_positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child: Node in _token_container.get_children():
		if child is SquadronToken:
			var st: SquadronToken = child as SquadronToken
			var inst: SquadronInstance = st.get_squadron_instance()
			if inst and not inst.is_destroyed():
				result.append({
					"instance": inst,
					"position": st.global_position,
				})
	return result


## Builds an array of [ShipBase] for all ships on the board.
## Used for squadron move validation (overlap check).
func _build_ship_bases() -> Array[ShipBase]:
	var result: Array[ShipBase] = []
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var ship: ShipToken = child as ShipToken
			var inst: ShipInstance = ship.get_ship_instance()
			if inst and inst.ship_data:
				var xform: Transform2D = Transform2D(
						ship.global_rotation, ship.global_position)
				result.append(ShipBase.new(
						inst.ship_data.ship_size, xform))
	return result


## Returns true if the squadron has at least one valid attack target
## (enemy squadron or enemy ship) within distance 1.
## Squadron attacks always occur at close range (distance 1).
## Rules Reference: "Squadron Attacks", RRG p.19.
func _squadron_has_valid_targets(
		instance: SquadronInstance,
		token: SquadronToken,
		all_squads: Array[Dictionary]) -> bool:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist1_px: float = EngagementResolver._get_distance_1_px()
	var pos: Vector2 = token.global_position
	# Check enemy squadrons at distance 1.
	for entry: Dictionary in all_squads:
		var other: SquadronInstance = entry["instance"] as SquadronInstance
		if other == instance:
			continue
		if other.owner_player == instance.owner_player:
			continue
		if other.is_destroyed():
			continue
		var other_pos: Vector2 = entry["position"] as Vector2
		var edge_dist: float = pos.distance_to(other_pos) - radius * 2.0
		if edge_dist <= dist1_px:
			return true
	# Check enemy ships at distance 1 (close range for battery armament).
	for child: Node in _token_container.get_children():
		if not child is ShipToken:
			continue
		var ship: ShipToken = child as ShipToken
		var ship_inst: ShipInstance = ship.get_ship_instance()
		if ship_inst == null:
			continue
		if ship_inst.owner_player == instance.owner_player:
			continue
		# Approximate distance: centre-to-centre minus radii.
		var ship_half: float = ship.get_half_length()
		var dist: float = pos.distance_to(ship.global_position)
		var edge_approx: float = dist - radius - ship_half
		if edge_approx <= dist1_px:
			return true
	return false


## Returns true if the given ship token has a revealed Repair dial
## or a Repair command token **and** the ship actually has something
## to repair (damage cards or shields below max).  When false the
## Repair step is auto-skipped in the activation modal.
## Rules Reference: CM-030 — Engineering requires dial or token.
func _has_repair_resources(ship_token: Variant) -> bool:
	if ship_token == null:
		return false
	if not ship_token is ShipToken:
		return false
	var inst: ShipInstance = (ship_token as ShipToken).get_ship_instance()
	if inst == null:
		return false
	var has_resource: bool = false
	# Check revealed dial.
	if inst.command_dial_stack:
		var revealed: Dictionary = inst.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) == Constants.CommandType.REPAIR:
			has_resource = true
	# Check command token.
	if not has_resource and inst.command_tokens and \
			inst.command_tokens.has_token(Constants.CommandType.REPAIR):
		has_resource = true
	if not has_resource:
		return false
	# Even with resources, skip if the ship is at full health.
	return not inst.is_fully_healthy()


## Returns true if the given ship token has a revealed Squadron dial
## or a Squadron command token **and** there is at least one friendly
## squadron on the board.  When false the Squadron step is auto-skipped
## in the activation modal.
## Rules Reference: CM-020 — Squadron requires dial or token.
func _has_squadron_resources(ship_token: Variant) -> bool:
	if ship_token == null or not ship_token is ShipToken:
		return false
	var inst: ShipInstance = (ship_token as ShipToken).get_ship_instance()
	if inst == null:
		return false
	var has_resource: bool = false
	# Check revealed dial.
	if inst.command_dial_stack:
		var revealed: Dictionary = inst.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) == \
				Constants.CommandType.SQUADRON:
			has_resource = true
	# Check command token.
	if not has_resource and inst.command_tokens and \
			inst.command_tokens.has_token(Constants.CommandType.SQUADRON):
		has_resource = true
	if not has_resource:
		return false
	# Even with resources, skip if no friendly squadrons exist.
	var tokens: Array[SquadronToken] = get_squadron_tokens()
	for sq_token: SquadronToken in tokens:
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.owner_player == inst.owner_player:
			return true
	return false


## Returns true if the ship has a Squadron token but no matching dial.
## In that case spending the token is optional and the player should be
## offered a "Skip" button.
## Rules Reference: "Commands" p.4 — command tokens are optional.
func _is_squadron_token_only(ship_token: Variant) -> bool:
	if ship_token == null or not ship_token is ShipToken:
		return false
	var inst: ShipInstance = (ship_token as ShipToken).get_ship_instance()
	if inst == null:
		return false
	var has_dial: bool = false
	if inst.command_dial_stack:
		var revealed: Dictionary = inst.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) == \
				Constants.CommandType.SQUADRON:
			has_dial = true
	var has_token: bool = inst.command_tokens != null and \
			inst.command_tokens.has_token(Constants.CommandType.SQUADRON)
	return has_token and not has_dial

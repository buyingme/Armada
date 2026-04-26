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
## SHARED — Created: _create_camera(). Read: displacement (rotation),
## attack executor (zoom), debug (overlay). Write: _create_camera() only.
## Extractable: pass via initialize() to controllers.
var _camera: BoardCamera = null

## Container for all token nodes.
## SHARED — Created: _create_token_container(). Read: token spawning,
## get_ship_tokens(), get_squadron_tokens(), attack executor, displacement.
## Write: _create_token_container() only. Extractable: pass via initialize().
var _token_container: Node2D = null

## Debug controller — owns deploy overlay, debug HUD, help panel, and
## scenario saver.  Created in [method _create_debug_controller].
var _debug_controller: DebugController = null

## UI panel manager — owns all UI panel creation, positioning,
## resizing, and isolated UI callbacks.
## Created in [method _ready].
var _panel_mgr: UIPanelManager = null

## Background map texture loaded from the scenario JSON (may be null).
var _map_texture: Texture2D = null

## Core mover logic for collision resolution.
## SHARED — Created: inline. Read: maneuver execution, displacement
## validation, overlap resolution. Write: never after init.
## Extractable: pass via initialize() to ManeuverToolController.
var _token_mover: TokenMover = TokenMover.new()

## Controller owning the command-dial picker, order modal, and ship queue.
## Created in [method _create_command_phase_controller].
var _command_phase_controller: CommandPhaseController = null

## Queue of ships still awaiting dial assignment during the Command Phase.
## Populated at the start of each Command Phase, drained as each picker
## is confirmed. Initiative player's ships come first.

## --- Dial drag controller (Phase 4c: Ship Activation Trigger) ---

## Controller owning dial drag-and-drop state and preview UI.
## Created in [method _create_dial_drag_controller].
var _dial_drag_controller: DialDragController = null

## The ShipToken currently being activated (dial shown behind base).
## SHARED — Created: DialDragController signals. Read: maneuver tool, attack
## step, repair step, squadron step, overlap resolution, displacement.
## Write: dial drag start/end, activation end.
## Held in [ActivationContext] — controllers access via injected reference.
var _activation_ctx: ActivationContext = ActivationContext.new()

## --- Maneuver Tool state (Phase 5a) ---

## Maneuver tool controller — owns selection flag and ManeuverToolScene.
## Created in [method _create_maneuver_tool_controller].
var _maneuver_tool_controller: ManeuverToolController = null

## --- Range Overlay state ---

## Range tool controller — owns selection flag and RangeOverlayScene.
## Created in [method _create_range_tool_controller].
var _range_tool_controller: RangeToolController = null

## --- Targeting List state (Phase F5c) ---

## Targeting list controller — owns modal lifecycle and data collection.
## Created in [method _create_targeting_list_controller].
var _targeting_list_controller: TargetingListController = null

## Target selector — owns attacker/target selection, visual aids, and the
## attack sim panel. Used by both the free-form simulator and the attack
## executor. Created in [method _create_target_selector].
var _target_selector: TargetSelector = null

## Attack executor — owns the dice / defense / damage execution flow.
## Created in [method _create_attack_executor].
## SHARED — Created: _create_attack_executor(). Read: ship activation
## (attack step), escape handling.
## Write: _create_attack_executor() only. Already extracted as child Node.
var _attack_executor: AttackExecutor = null

## Shared damage deck for the game. Initialised during scenario setup.
## SHARED — Created: _spawn_learning_scenario_tokens(). Read: attack
## executor (set_damage_deck), debug damage dealing, immediate effect
## resolution. Write: scenario setup only. Extractable: pass via
## initialize() to any controller needing damage draws.
var _damage_deck: DamageDeck = null

## --- Crew Panic BEFORE_REVEAL_DIAL modal state ---

## Ship instance for the pending Crew Panic choice (stored independently
## of the drag controller's state because no drag is active during the modal).
var _pending_crew_panic_ship: ShipInstance = null

## Pending ship key for the Crew Panic choice callback.
var _pending_crew_panic_ship_key: String = ""

## Lazily created OpponentChoiceModal for the Crew Panic prompt.
var _crew_panic_modal: OpponentChoiceModal = null

## --- Debug damage dealing state (DBG-050) ---

## Whether we are in "click a ship to deal faceup damage" targeting mode.
var _debug_damage_targeting: bool = false

## Lazily created OpponentChoiceModal for the debug damage card picker.
var _debug_damage_modal: OpponentChoiceModal = null

## The ShipToken that was clicked during debug damage targeting.
var _debug_damage_target_token: ShipToken = null

## Deferred immediate-effect card awaiting choice resolution.
var _debug_immediate_card: DamageCard = null

## Ship that received the deferred immediate-effect card.
var _debug_immediate_ship: ShipInstance = null

## --- Phase 7b: Squadron Activation flow state ---

## Squadron phase controller — owns all squadron activation state and UI.
## Created in [method _create_squadron_phase_controller].
var _squadron_phase_controller: SquadronPhaseController = null

## Displacement controller — owns all displacement state and UI.
## Created in [method _create_displacement_controller].
var _displacement_controller: DisplacementController = null

## Latest known interaction-state controller player for network authority gates.
var _interaction_controller_player: int = -1

## True once at least one interaction-state update has been received.
var _has_interaction_controller: bool = false

func _ready() -> void:
	_create_camera()
	_create_token_container()
	_create_debug_controller()
	_create_command_phase_controller()
	_create_squadron_phase_controller()
	# UI panels, resize infrastructure, and isolated UI callbacks.
	_panel_mgr = UIPanelManager.new()
	_panel_mgr.name = "UIPanelManager"
	add_child(_panel_mgr)
	_panel_mgr.initialize(self )
	# Wire squadron UI (needs TurnManagementLayer from UIPanelManager).
	_squadron_phase_controller.create_ui(
			_panel_mgr.turn_management_layer, _panel_mgr.register_resizable)
	_create_target_selector()
	_create_attack_executor()
	_create_maneuver_tool_controller()
	_create_range_tool_controller()
	_create_targeting_list_controller()
	_create_displacement_controller()
	_create_dial_drag_controller()
	# Start game so GameState exists BEFORE tokens are spawned.
	# In network mode, use the shared config (RNG seed + scenario) received
	# from the server before scene transition.  G4.6.5.4.
	if PlayMode.is_network():
		var config: Dictionary = NetworkManager.get_pending_game_config()
		# Client does not drive game flow — server broadcasts StartRoundCommand.
		# G4.6.5 A2.
		if not NetworkManager.is_server():
			config["client_mode"] = true
		GameManager.start_new_game(config)
	else:
		GameManager.start_new_game({"scenario_id": "learning_scenario"})
	_spawn_learning_scenario_tokens()
	_connect_signals()
	_connect_panel_signals()
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
	# Phase 7b: Squadron follows mouse during MOVING state.
	if _squadron_phase_controller:
		_squadron_phase_controller.process_squadron_movement()

	if not DebugMode.has_selection():
		return
	_move_selected_token_to_mouse()

## Intercepts magnify gesture BEFORE the camera when a token is selected,
## converting it to rotation and consuming the event so the camera does not zoom.
## DBG-012 — pinch gesture rotates selected token.
## Also intercepts squadron placement clicks/Escape in MOVING state —
## must run in _input so the event is consumed before GUI Controls
## (the SquadronActivationModal panel) and before SquadronToken's
## _unhandled_input (which would eat the click since the token follows
## the mouse).
func _input(event: InputEvent) -> void:
	# Phase 7b: Squadron movement — intercept before GUI / token can consume.
	if _squadron_phase_controller \
			and _squadron_phase_controller.handle_move_input(event):
		return

	if not DebugMode.has_selection():
		return
	if event is InputEventMagnifyGesture:
		_handle_debug_rotate(event as InputEventMagnifyGesture)

## Handles input for debug-mode interactions.
## DBG-003 — must not interfere with camera controls (right-click, scroll).
func _unhandled_input(event: InputEvent) -> void:
	# Squadron displacement: left-click locks the currently moving squadron.
	if _displacement_controller and _displacement_controller.is_displacement_active():
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_displacement_controller.handle_lock_click()
				get_viewport().set_input_as_handled()
				return
	# Range overlay: Escape dismisses or cancels selection.
	if _range_tool_controller.handle_escape(event):
		return
	# Maneuver tool: Escape dismisses or cancels selection.
	if _maneuver_tool_controller.handle_escape(event):
		return

	# Keyboard shortcuts for tool buttons (M / R / T).
	# Available in all modes; guarded by the same disabled flag as toolbar buttons.
	# Requirements: MT-U-007, RO-008, TL-UI-003a.
	if _handle_tool_shortcut(event):
		return

	# Debug damage targeting: Escape cancels. DBG-050.
	if _handle_debug_damage_escape(event):
		return

	# Debug damage dealing: Shift+D enters targeting mode. DBG-050.
	if _handle_debug_damage_shortcut(event):
		return

	# Quit confirmation: ESC when no other handler consumed it. UI-034.
	if _panel_mgr.handle_quit_escape(event):
		return

	if not DebugMode.enabled:
		return

	if event is InputEventMouseButton:
		_debug_controller.handle_debug_click(event as InputEventMouseButton)

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
## Connects EventBus and DebugMode signals relevant to the board.
func _connect_signals() -> void:
	#region Debug & viewport signals
	EventBus.firing_arc_toggled.connect(_on_firing_arc_toggled)
	# debug_mode_changed / save_positions_requested are connected inside
	# DebugController.initialize().
	# Viewport resize is handled by UIPanelManager._connect_ui_signals().
	#endregion

	#region Command Phase signals
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.round_started.connect(_on_round_started)
	# command_picker_requested / confirmed / dial_order_requested / command_phase_complete
	# are connected inside CommandPhaseController.initialize().
	#endregion

	#region Turn management signals
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.handoff_accepted.connect(_on_handoff_accepted)
	EventBus.interaction_state_changed.connect(_on_interaction_state_changed)
	# Phase I4: UIProjector-driven HUD status.  Recomputes after every
	# applied command using the authoritative [GameState.interaction_flow]
	# domain field.  Runs in parallel with the legacy interaction-state
	# path during I4; legacy paths are removed in I5/I6.
	CommandProcessor.command_executed.connect(_on_command_executed_project_ui)
	#endregion

	#region Ship activation signals (dial drag controller, activation end)
	# EventBus.dial_drag_started is connected inside DialDragController.initialize().
	EventBus.activation_ended.connect(_on_board_activation_ended)
	#endregion

	#region Maneuver tool signals
	EventBus.maneuver_tool_requested.connect(_on_maneuver_tool_requested)
	EventBus.maneuver_tool_dismissed.connect(
			func() -> void: _maneuver_tool_controller.dismiss(null))
	#endregion

	#region Range overlay signals
	EventBus.range_overlay_requested.connect(_on_range_overlay_requested)
	EventBus.range_overlay_dismissed.connect(
			func() -> void: _range_tool_controller.dismiss())
	#endregion

	#region Targeting & attack signals
	EventBus.targeting_list_requested.connect(
			_targeting_list_controller.on_targeting_list_requested)
	EventBus.attack_simulator_requested.connect(_on_attack_simulator_requested)
	#endregion

	#region Game end & scoring signals
	# game_ended / ship_destroyed / squadron_destroyed / damage_summary_requested
	# are connected inside UIPanelManager._connect_ui_signals().
	#endregion

	#region Damage card signals
	EventBus.damage_card_dealt.connect(_on_damage_card_dealt)
	#endregion

	#region Network remote repositioning (BF-2)
	EventBus.ship_repositioned_remotely.connect(
			_on_ship_repositioned_remotely)
	EventBus.squadron_repositioned_remotely.connect(
			_on_squadron_repositioned_remotely)
	#endregion

	#region Network passive-peer modal mirroring (C7/C8)
	if not EventBus.ship_activated_remotely.is_connected(_on_remote_ship_activated):
		EventBus.ship_activated_remotely.connect(_on_remote_ship_activated)
	#endregion


## Connects game-logic signals from UIPanelManager-created panels
## to game_board signal handlers.
func _connect_panel_signals() -> void:
	# Activation modal — 8 game-logic signals.
	_panel_mgr.activation_modal.maneuver_step_entered.connect(
			_on_maneuver_step_entered)
	_panel_mgr.activation_modal.maneuver_commit_requested.connect(
			_on_execute_maneuver)
	_panel_mgr.activation_modal.attack_step_entered.connect(
			_on_attack_step_entered)
	_panel_mgr.activation_modal.repair_step_entered.connect(
			_on_repair_step_entered)
	_panel_mgr.activation_modal.squadron_step_entered.connect(
			_on_squadron_step_entered)
	_panel_mgr.activation_modal.squadron_step_skipped.connect(
			_on_squadron_step_skipped)
	_panel_mgr.activation_modal.modal_closed.connect(
			_on_activation_modal_closed)
	_panel_mgr.activation_modal.end_activation_requested.connect(
			_on_activation_end_requested)
	# Repair panel — done/skipped signals.
	_panel_mgr.repair_panel.repair_done.connect(_on_repair_done)
	_panel_mgr.repair_panel.repair_skipped.connect(_on_repair_done)
	# Show Activation Sequence button.
	_panel_mgr.show_activation_button.activation_sequence_requested.connect(
			_on_activation_sequence_requested)
	# Command phase controller — phase_complete updates HUD.
	_command_phase_controller.phase_complete.connect(
			_panel_mgr.update_phase_hud)


## Places all Learning Scenario tokens from setup data and loads the map image.
## Also creates [ShipInstance] / [SquadronInstance] runtime objects, registers
## them in [GameState] so GameManager tracks dial submission, binds instances
## to visual tokens, and adds ship cards to the side panels.
## Rules Reference: "Learning Scenario Setup", step 9, p.5; SU-010–030.
func _spawn_learning_scenario_tokens() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	_load_map_texture(setup.get_map_image_filename())
	_init_scenario_systems(setup)
	var ship_instances: Array[ShipInstance] = setup.create_ship_instances()
	var squad_instances: Array[SquadronInstance] = setup.create_squadron_instances()
	_register_instances_in_game_state(ship_instances, squad_instances)
	# Network client: server auto-assigns fixed commands and broadcasts.
	# Client receives via _handle_remote_command_effects().  G4.6.5 A3.
	if setup.has_fixed_round1_commands() \
			and (not PlayMode.is_network() or NetworkManager.is_server()):
		var fixed_cmds: Dictionary = setup.get_fixed_round1_commands()
		GameManager.apply_fixed_round1_commands(fixed_cmds)
	_spawn_and_bind_tokens(setup, ship_instances, squad_instances)
	_log.info("Spawned %d tokens for the Learning Scenario." %
			_token_container.get_child_count())
	_panel_mgr.update_card_panel_positions()
	if _panel_mgr.activation_sidebar and GameManager.current_game_state:
		_panel_mgr.activation_sidebar.populate(GameManager.current_game_state)
		_panel_mgr.activation_sidebar.connect_signals()
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_panel_mgr.activation_sidebar.update_position(vp_size)

## Initialises the damage deck, attack executor references, and effect
## registry from the given scenario setup.
func _init_scenario_systems(setup: LearningScenarioSetup) -> void:
	var game_rng: GameRng = null
	if GameManager.current_game_state:
		game_rng = GameManager.current_game_state.rng
	_damage_deck = setup.get_damage_deck(game_rng)
	if GameManager.current_game_state:
		GameManager.current_game_state.damage_deck = _damage_deck
	if _attack_executor:
		_attack_executor.set_damage_deck(_damage_deck)
	if _attack_executor and _panel_mgr.handoff_overlay:
		_attack_executor.set_handoff_overlay(_panel_mgr.handoff_overlay)
	if _attack_executor and GameManager.current_game_state \
			and GameManager.current_game_state.effect_registry:
		_attack_executor.set_effect_registry(
				GameManager.current_game_state.effect_registry)

## Spawns ship and squadron tokens and binds them to their instances.
func _spawn_and_bind_tokens(setup: LearningScenarioSetup,
		ship_instances: Array[ShipInstance],
		squad_instances: Array[SquadronInstance]) -> void:
	var ship_placements: Array[TokenPlacement] = setup.get_ship_placements()
	var squad_placements: Array[TokenPlacement] = setup.get_squadron_placements()
	for i: int in range(ship_placements.size()):
		var token: ShipToken = _spawn_ship_token(ship_placements[i])
		if i < ship_instances.size():
			token.bind_instance(ship_instances[i])
			_panel_mgr.add_ship_to_card_panel(ship_instances[i])
	for i: int in range(squad_placements.size()):
		var token: SquadronToken = _spawn_squadron_token(squad_placements[i])
		if i < squad_instances.size():
			token.bind_instance(squad_instances[i])

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
	if _target_selector and _target_selector.handle_ship_click(token):
		return
	if _range_tool_controller.is_selecting():
		_range_tool_controller.show_overlay(token)
		return
	if _maneuver_tool_controller.is_selecting():
		_maneuver_tool_controller.show_tool(token)
		return
	if _debug_damage_targeting:
		_open_debug_damage_modal(token)
		return
	if DebugMode.enabled:
		DebugMode.select_token(token)
		_debug_controller.reset_zone_tracking()
	else:
		EventBus.element_selected.emit(token)

## Called when a squadron token is clicked.
func _on_squadron_clicked(token: SquadronToken) -> void:
	if _target_selector and _target_selector.handle_squadron_click(token):
		return
	# Phase 7b: route to squadron activation modal.
	if _squadron_phase_controller \
			and _squadron_phase_controller.try_handle_squadron_click(token):
		return
	if DebugMode.enabled:
		DebugMode.select_token(token)
		_debug_controller.reset_zone_tracking()
	else:
		EventBus.element_selected.emit(token)

## Handles the global firing arc toggle signal.
## Rules Reference: UI-011 — player toggles arc overlay for a ship token.
func _on_firing_arc_toggled(token: Node) -> void:
	if token is ShipToken:
		(token as ShipToken).toggle_arc_overlay()
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
		_debug_controller.check_zone_crossing_toast(token, top_y, bottom_y)

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
# Turn-management UI creation
# ---------------------------------------------------------------------------
## Called when the game phase changes.
## Updates the HUD and shows/hides the End Activation button.
## For Command Phase, the dial flow is NOT started here — it is started
## by _on_handoff_accepted() after the player dismisses the overlay.
## For Ship Phase, the End Activation button is hidden until a ship is
## activated via dial drag-and-drop (Phase 4c: UI-024).
## Requirements: TF-005, TF-011.
func _on_phase_changed(new_phase: Constants.GamePhase) -> void:
	_panel_mgr.update_phase_hud()
	match new_phase:
		Constants.GamePhase.COMMAND:
			_panel_mgr.end_activation_button.hide_button()
			_hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()
		Constants.GamePhase.SHIP:
			# Button hidden until a ship is activated via dial drag (Phase 4c).
			_panel_mgr.end_activation_button.hide_button()
			_hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()
		Constants.GamePhase.SQUADRON:
			# Phase 7b: Squadron modal opens after handoff.
			_panel_mgr.end_activation_button.hide_button()
			_hide_phase5b_ui()
			_panel_mgr.show_activation_button.hide_button()
		_:
			_panel_mgr.end_activation_button.hide_button()
			_hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()

## Called when a new round begins.
func _on_round_started(_round_number: int) -> void:
	_panel_mgr.update_phase_hud()
	# Safety net: ensure squadron-phase UI never leaks into a new round.
	_squadron_phase_controller.hide_ui()
	# Restore squadron token opacity after Status Phase dimming.
	# Skip destroyed squadrons — they must stay hidden.
	for sq_token: SquadronToken in get_squadron_tokens():
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.is_destroyed():
			continue
		sq_token.set_activated_visual(false)

# ---------------------------------------------------------------------------
# Turn management signal handlers
# ---------------------------------------------------------------------------

## Called when the active player changes.
## In hot-seat mode, shows the handoff overlay (Command Phase) or "Your Turn"
## banner (Ship / Squadron Phase), rotates the camera, and swaps card panels.
## In network mode, locks camera to the local player's perspective and shows
## "Waiting for opponent…" when it is not the local player's turn.
## Requirements: TF-001, BP-001, BP-003, HO-001, HO-004.  G4.6.5.7/8.
func _on_active_player_changed(player_index: int) -> void:
	if PlayMode.is_network():
		_handle_network_active_player(player_index)
		return
	if not PlayMode.is_hot_seat():
		return

	var phase: Constants.GamePhase = GameManager.get_current_phase()

	# Update viewer on both card panels so the active player can only
	# inspect their own dial stacks.
	# Requirements: UI-023 — cannot view opponent's unrevealed dials.
	_panel_mgr.rebel_card_panel.set_viewer_player(player_index)
	_panel_mgr.imperial_card_panel.set_viewer_player(player_index)

	# Rotate camera to the new player's perspective.
	# Requirements: BP-001 — camera rotates 180°.
	_camera.rotate_to_player(player_index)

	# Swap card panels so the active player's cards are on the left.
	_swap_card_panels(player_index)

	# Show appropriate overlay / banner.
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	match phase:
		Constants.GamePhase.COMMAND:
			var phase_name: String = UIPanelManager.PHASE_NAMES.get(phase, "Command Phase")
			_panel_mgr.handoff_overlay.show_handoff(player_index, phase_name)
			_panel_mgr.handoff_overlay.update_size(vp_size)
		Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON:
			_panel_mgr.your_turn_banner.show_banner(player_index)
			_panel_mgr.your_turn_banner.update_size(vp_size)

## Called when the handoff overlay or banner is dismissed by the player.
## Resumes the appropriate game flow for the current phase.
## Requirements: HO-002, HO-004.
func _on_handoff_accepted() -> void:
	# Network mode: only proceed when it is the local player's turn.
	# Prevents opening SqActModal for the remote player's squadrons.
	if PlayMode.is_network():
		var local: int = NetworkManager.get_local_player_index()
		if GameManager.active_player != local:
			return
	var phase: Constants.GamePhase = GameManager.get_current_phase()

	match phase:
		Constants.GamePhase.COMMAND:
			# Restart the dial flow for the now-assigned player.
			_command_phase_controller.begin_command_dial_flow()
		Constants.GamePhase.SHIP:
			# Player is ready — they can now drag a dial to activate a ship.
			# "End Activation" appears only after the dial is dropped (Phase 4c).
			pass
		Constants.GamePhase.SQUADRON:
			_squadron_phase_controller.begin_activation_flow()

## Swaps card panel sides so the active player's faction panel is on the
## left and the opponent's is on the right.
## Requirements: BP-003 — active player's cards always on the left.
func _swap_card_panels(player_index: int) -> void:
	# Player 0 = Rebel, Player 1 = Imperial (Learning Scenario mapping).
	var rebel_left: bool = (player_index == 0)
	_panel_mgr.rebel_card_panel.set_side(rebel_left)
	_panel_mgr.imperial_card_panel.set_side(not rebel_left)
	_panel_mgr.update_card_panel_positions()


## Network-mode active-player handler.
## Locks camera to the local player's perspective (no rotation), updates
## card panel viewer, and shows "Your Turn" banner or starts the Command
## Phase dial flow.  During Ship/Squadron phases, the non-active player
## sees the banner for the active player but cannot interact.
## G4.6.5.7/8 — network active-player handling + input lockout.
func _handle_network_active_player(_player_index: int) -> void:
	var local: int = NetworkManager.get_local_player_index()
	var phase: Constants.GamePhase = GameManager.get_current_phase()
	if _panel_mgr != null:
		# Fallback while server-side interaction-state publishing is still
		# being rolled out: keep score-header guidance visible from the
		# active-player signal path.
		var status_text: String = "waiting for opponent's choice"
		if phase == Constants.GamePhase.COMMAND or _player_index == local:
			status_text = "make your choices"
		_panel_mgr.set_network_status_text(status_text)
		_update_activation_modal_interactivity()

	# Always lock viewer to local player's perspective.
	_panel_mgr.rebel_card_panel.set_viewer_player(local)
	_panel_mgr.imperial_card_panel.set_viewer_player(local)
	_camera.rotate_to_player(local)
	_swap_card_panels(local)

	# Command Phase: both players assign dials simultaneously — no lockout.
	if phase == Constants.GamePhase.COMMAND:
		_command_phase_controller.begin_command_dial_flow()
		return

	# Ship / Squadron Phase: only show "Your Turn" banner when it IS
	# the local player's turn.  The non-active player just watches.
	# G4.6.5 — prevents begin_activation_flow() from opening the
	# SqActModal for the remote player's squadrons.
	if _player_index != local:
		# Passive peer: start the squadron flow as a read-only observer so
		# the modal mirrors the opponent's activation.  G4.6.6 T1a C8.
		if phase == Constants.GamePhase.SQUADRON:
			_squadron_phase_controller.begin_activation_flow()
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.your_turn_banner.show_banner(_player_index)
	_panel_mgr.your_turn_banner.update_size(vp_size)


## Phase I4: HUD status text from [UIProjector].
##
## Re-runs after every applied command (and after snapshot apply) so the
## HUD status text reflects the current authoritative interaction-flow
## domain field on [GameState].
##
## Networked + hot-seat: uses [code]NetworkManager.get_local_player_index()[/code]
## as the viewer.  In hot-seat, the active player is also the local
## viewer (camera handles handoff), so the projection produces the same
## "make your choices" wording the active player would see in network mode.
##
## Runs in parallel with the legacy parallel-channel handler during
## Phase I4.  When I5/I6 delete the legacy path, this becomes the sole
## HUD status producer.
func _on_command_executed_project_ui(_command: GameCommand,
		_result: Dictionary) -> void:
	if _panel_mgr == null:
		return
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var local: int = NetworkManager.get_local_player_index()
	if local < 0:
		# Hot-seat: viewer is the active player.
		local = gs.active_player
	var intent: UIProjector.UIIntent = UIProjector.project(gs, local)
	# I4 pilot scope: only overwrite when projector has a non-empty
	# value, so we do not stomp on the legacy active-player fallback in
	# phases that have no interaction flow yet.  I5/I6 expand coverage.
	if intent.hud_status_text.is_empty():
		return
	_panel_mgr.set_network_status_text(intent.hud_status_text)


## Applies score-header helper text from authoritative interaction-state
## updates. Uses ui_status_text when provided, otherwise falls back to
## controller-based wording from StatusTextPolicy.
func _on_interaction_state_changed(state: NetworkInteractionState) -> void:
	if not PlayMode.is_network() or _panel_mgr == null:
		return
	_has_interaction_controller = true
	_interaction_controller_player = state.controller_player
	_sync_activation_step_from_interaction_state(state)
	# Modal lifecycle: open when activation starts, close when it ends.
	if state.step_id == "activation_modal_open":
		_open_modal_from_interaction_state()
	elif state.step_id == "wait_for_ship_select":
		_close_modal_from_interaction_state()
	var status_text: String = state.ui_status_text.strip_edges()
	if status_text.is_empty():
		var local: int = NetworkManager.get_local_player_index()
		if state.controller_player == local:
			status_text = "make your choices"
		else:
			status_text = "waiting for opponent's choice"
	_panel_mgr.set_network_status_text(status_text)
	_update_activation_modal_interactivity()


## Opens the activation modal in response to an authoritative interaction-state
## update (step_id == "activation_modal_open").
## The controller peer runs the full flow with auto-skip; the passive peer
## gets a mirror view with no auto-skip so the first step is held until the
## next interaction-state update advances it.
func _open_modal_from_interaction_state() -> void:
	if _activation_ctx.ship_activation_state == null:
		return
	var is_controller: bool = _is_local_activation_modal_controller()
	if is_controller:
		_configure_and_open_activation_modal()
	else:
		_open_activation_modal_mirror()
	# Always show the "Show Activation Sequence" button so both peers can
	# re-open the modal if they close it manually.
	_show_activation_sequence_button()


## Opens the activation modal without running auto-skip.
## Used for the passive (non-controller) peer who mirrors the active player's
## activation sequence and must not advance steps locally.
func _open_activation_modal_mirror() -> void:
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return
	if _activation_ctx.ship_activation_state == null:
		return
	_panel_mgr.activation_modal.set_squadron_skippable(
			not _has_squadron_resources(_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_squadron_token_only(
			_is_squadron_token_only(_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_repair_skippable(
			not _has_repair_resources(_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_attack_skippable(
			not _attack_executor.has_any_attack_target(
			_activation_ctx.activating_ship_token))
	_update_activation_modal_interactivity()
	_panel_mgr.activation_modal.open_mirror(_activation_ctx.ship_activation_state)


## Closes the activation modal and cleans up activation state in response to
## an authoritative interaction-state update (step_id == "wait_for_ship_select").
## Safe to call even if the modal is already closed (idempotent).
func _close_modal_from_interaction_state() -> void:
	_on_board_activation_ended()


## Applies authoritative ship-activation step snapshots from interaction state.
## This keeps modal checkmarks synchronized across peers even when local UI
## flows differ.
func _sync_activation_step_from_interaction_state(
		state: NetworkInteractionState) -> void:
	if state.flow_type != "ship_activation":
		return
	if _activation_ctx.ship_activation_state == null:
		return
	var step_id: String = state.step_id
	var target_step: int = -1
	match step_id:
		"squadron_step":
			target_step = ShipActivationState.Step.SQUADRON
		"repair_step":
			target_step = ShipActivationState.Step.REPAIR
		"attack_step":
			target_step = ShipActivationState.Step.ATTACK
		"maneuver_step":
			target_step = ShipActivationState.Step.MANEUVER
		"activation_done":
			target_step = ShipActivationState.Step.DONE
		_:
			return
	_activation_ctx.ship_activation_state.set_current_step(
			target_step as ShipActivationState.Step)
	if _panel_mgr.activation_modal and _panel_mgr.activation_modal.is_open():
		_panel_mgr.activation_modal.refresh()


## Submits an authoritative activation-step transition marker in network mode.
func _submit_network_activation_step(step_id: String) -> void:
	if not PlayMode.is_network() or _activation_ctx.ship_activation_state == null:
		return
	var ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	if ship == null:
		return
	GameManager.submit_advance_activation_step(ship, step_id)


## Returns whether the local player may interact with ActivationModal controls.
func _is_local_activation_modal_controller() -> bool:
	if not PlayMode.is_network():
		return true
	var local: int = NetworkManager.get_local_player_index()
	if _has_interaction_controller:
		return _interaction_controller_player == local
	return GameManager.get_active_player() == local


## Applies current controller authority to activation and squadron modals.
func _update_activation_modal_interactivity() -> void:
	var is_controller: bool = _is_local_activation_modal_controller()
	if _panel_mgr != null and _panel_mgr.activation_modal != null:
		_panel_mgr.activation_modal.set_interactable(is_controller)
	if _squadron_phase_controller != null:
		_squadron_phase_controller.set_modal_interactable(is_controller)


## Applies dynamic skip/interactable flags and opens the activation modal.
func _configure_and_open_activation_modal() -> void:
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return
	if _activation_ctx.ship_activation_state == null:
		return
	_panel_mgr.activation_modal.set_squadron_skippable(
			not _has_squadron_resources(_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_squadron_token_only(
			_is_squadron_token_only(_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_repair_skippable(
			not _has_repair_resources(_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_attack_skippable(
			not _attack_executor.has_any_attack_target(
			_activation_ctx.activating_ship_token))
	_update_activation_modal_interactivity()
	_panel_mgr.activation_modal.open(_activation_ctx.ship_activation_state)

## Shows and positions the End Activation button.
func _show_end_activation_button() -> void:
	if _panel_mgr.end_activation_button == null:
		return
	_panel_mgr.end_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.end_activation_button.update_position(vp_size)

# ---------------------------------------------------------------------------
# Dial drag-and-drop — Ship Activation (Phase 4c)
# Drag state + preview UI managed by DialDragController.
# ---------------------------------------------------------------------------

## Called by [signal DialDragController.ship_activated] when the player drops
## the dial on the owning ship token.  Sets up activation state and shows the
## activation-sequence button.
## Requirements: UI-024, UI-025, SP-010, ACT-007, FLOW-002.
func _on_dial_ship_activated(token: ShipToken, ship: ShipInstance) -> void:
	GameManager.activate_ship(ship)
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		token.show_revealed_dial(cmd)
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)
	_show_activation_sequence_button()
	_log.info("Ship activated via dial drop: '%s'." % ship.data_key)

## Called by [signal DialDragController.token_converted] when the player drops
## the dial on the owning ship's card-panel entry.  Converts the dial to a
## command token.
## Rules Reference: "Command Dials", p.3 — "spend the command dial to gain
## a command token of the same type."
## Requirements: UI-028, SP-011, CM-004–006.
func _on_dial_token_converted(ship: ShipInstance) -> void:
	# Set up activation context BEFORE submitting the command so that the
	# activation_modal_open interaction-state callback (which fires synchronously
	# via call_local RPC inside NetworkHostCommandSubmitter) can find the context.
	var token: ShipToken = _find_ship_token_for_instance(ship)
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar:
		_panel_mgr.activation_sidebar.highlight_active(ship)

	var result: Dictionary = GameManager.activate_ship_as_token(ship)

	# Network mode: modal lifecycle is driven by interaction-state updates.
	# activation_modal_open  → _open_modal_from_interaction_state()
	# wait_for_ship_select   → _close_modal_from_interaction_state()
	# No need to show the sequence button or open the modal here.
	if PlayMode.is_network() and result.is_empty():
		_log.info("Ship activated via card drop (token convert): '%s' " \
				% [ship.data_key if ship else "?"] \
				+"(awaiting server result).")
		return

	var needs_discard: bool = result.get("needs_discard", false)
	if needs_discard:
		# Delay activation sequence button until the discard is resolved.
		if not EventBus.token_discarded.is_connected(
				_on_token_discard_resolved):
			EventBus.token_discarded.connect(
					_on_token_discard_resolved, CONNECT_ONE_SHOT)
	elif not PlayMode.is_network():
		# Hot-seat: show the sequence button; network uses interaction state.
		_show_activation_sequence_button()

	var cmd_name: String = ""
	if not result.is_empty():
		cmd_name = Constants.CommandType.keys()[result["command"]]
	_log.info("Ship activated via card drop (token convert): '%s' (%s, added=%s, discard=%s)." % [
			ship.data_key if ship else "?", cmd_name,
			str(result.get("token_added", false)),
			str(needs_discard)])

## Finds the ship token whose base contains [param world_pos], or null.
func _find_ship_token_at(world_pos: Vector2) -> ShipToken:
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var ship: ShipToken = child as ShipToken
			if ship.is_point_in_base(world_pos):
				return ship
	return null

## Finds the ShipToken on the board bound to the given ShipInstance.
## Returns null if not found.
func _find_ship_token_for_instance(ship: ShipInstance) -> ShipToken:
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var st: ShipToken = child as ShipToken
			if st.get_ship_instance() == ship:
				return st
	return null


## Opens the activation modal as a read-only observer on the passive peer.
## Called when the opponent activates a ship in network mode (either via
## dial-to-ship-token [ActivateShipCommand] or dial-to-card-panel
## [ConvertDialToTokenCommand]).  Sets up [member _activation_ctx] and
## opens the modal so the passive peer sees the same activation sequence.
## G4.6.6 T1a C7.
func _on_remote_ship_activated(ship: ShipInstance) -> void:
	if ship == null:
		return
	var token: ShipToken = _find_ship_token_for_instance(ship)
	if token == null:
		_log.warn("_on_remote_ship_activated: token not found for ship %s" % ship.data_key)
		return
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)
	# Do NOT open modal here. In network mode the modal lifecycle is driven by
	# interaction-state updates (activation_modal_open / wait_for_ship_select)
	# which arrive immediately after this handler via _flush_pending_interaction_states().
	# Opening here would run auto-skip on a fresh state before the authoritative
	# step arrives, causing all checkmarks to flash past on the passive peer.


## Snaps a ShipToken to the position stored in its ShipInstance model
## after a remote execute_maneuver command.  G4.6.5 BF-2.
func _on_ship_repositioned_remotely(ship: ShipInstance) -> void:
	var token: ShipToken = _find_ship_token_for_instance(ship)
	if token == null:
		return
	var pa: Vector2 = GameScale.play_area_size_px
	if pa.x <= 0.0 or pa.y <= 0.0:
		return
	token.global_position = Vector2(
			ship.pos_x * pa.x, ship.pos_y * pa.y)
	token.global_rotation = deg_to_rad(ship.rotation_deg)
	EventBus.ship_moved.emit(token)


## Snaps a SquadronToken to the position stored in its SquadronInstance
## model after a remote move_squadron command.  G4.6.5 BF-2.
func _on_squadron_repositioned_remotely(sq: SquadronInstance) -> void:
	var token: SquadronToken = _find_squadron_token_for_instance(sq)
	if token == null:
		return
	var pa: Vector2 = GameScale.play_area_size_px
	if pa.x <= 0.0 or pa.y <= 0.0:
		return
	token.global_position = Vector2(
			sq.pos_x * pa.x, sq.pos_y * pa.y)
	EventBus.squadron_moved.emit(token)


## Finds the SquadronToken on the board bound to the given SquadronInstance.
## Returns null if not found.
func _find_squadron_token_for_instance(
		sq: SquadronInstance) -> SquadronToken:
	for child: Node in _token_container.get_children():
		if child is SquadronToken:
			var st: SquadronToken = child as SquadronToken
			if st.get_squadron_instance() == sq:
				return st
	return null

## Finishes activation when Crew Panic discarded the dial.
## The revealed dial is spent (moved to the discarded pile) and the ship
## activates without any command available this round.  No drag is active
## — the ship is passed directly from the callback.
## Rules Reference: "Crew Panic" — "discard that dial … do not reveal a
## dial this round."
func _finish_crew_panic_dial_discarded(
		ship: ShipInstance, ship_key: String) -> void:
	# Spend the already-revealed dial so it moves to the discarded pile.
	if ship and ship.command_dial_stack:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty():
			GameManager.submit_spend_dial(ship, "spend")
		else:
			GameManager.submit_spend_dial(ship, "discard")
	GameManager.force_activate_ship(ship)
	var act_token: ShipToken = _find_ship_token_for_instance(ship)
	_activation_ctx.set_active(act_token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)
	_show_activation_sequence_button()
	_log.info("Ship activated (dial discarded by Crew Panic): '%s'."
			% ship_key)

## Checks if BEFORE_REVEAL_DIAL effects need to fire (Crew Panic).
## Called from [DialDragController] via callable BEFORE the drag begins.
## Returns true if a modal was shown (drag will start — or not — in the
## callback).
## Rules Reference: "Crew Panic" card text — "Before you reveal a command
## dial, you must either suffer 1 damage or discard that dial.  If you
## discard it, do not reveal a dial this round."
func _check_crew_panic_before_drag(ship: ShipInstance) -> bool:
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry == null:
		return false
	if ship == null:
		return false
	var effects: Array[GameEffect] = registry.get_effects_for_hook(
			&"BEFORE_REVEAL_DIAL")
	var has_crew_panic: bool = false
	for eff: GameEffect in effects:
		if eff is DamageCardEffect:
			var dce: DamageCardEffect = eff as DamageCardEffect
			if dce.effect_id == "crew_panic" and dce.owner == ship:
				has_crew_panic = true
				break
	if not has_crew_panic:
		return false
	# Store ship independently — no drag is active yet.
	_pending_crew_panic_ship = ship
	_pending_crew_panic_ship_key = ship.data_key
	var choice_info: Dictionary = {
		"choice_type": "crew_panic",
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"card_title": "Crew Panic",
		"effect_text": "Before you reveal a command dial, you must either "
				+"suffer 1 damage or discard that dial. If you discard it, "
				+"do not reveal a dial this round.",
		"options": [
			{"id": "discard_card", "label": "Discard command dial",
					"available": true},
			{"id": "suffer_damage", "label": "Suffer 1 facedown damage",
					"available": true},
		],
	}
	_ensure_crew_panic_modal()
	if not _crew_panic_modal.choice_confirmed.is_connected(
			_on_crew_panic_choice):
		_crew_panic_modal.choice_confirmed.connect(
				_on_crew_panic_choice, CONNECT_ONE_SHOT)
	_crew_panic_modal.open(choice_info)
	_log.info("Crew Panic — showing choice modal for %s." % ship.data_key)
	return true

## Callback when the player makes their Crew Panic choice.
## No drag is active — the ship is stored in [member _pending_crew_panic_ship].
## On "discard dial": spend the revealed dial, activate ship without command.
## On "suffer damage": resolve the hook, then start the dial drag.
func _on_crew_panic_choice(selection: Dictionary) -> void:
	var ship: ShipInstance = _pending_crew_panic_ship
	var ship_key: String = _pending_crew_panic_ship_key
	_pending_crew_panic_ship = null
	_pending_crew_panic_ship_key = ""
	if ship == null:
		_log.error("Crew Panic choice callback but no pending ship!")
		return
	var chose_discard: bool = str(selection.get("id", "")) == "discard_card"
	# Resolve the BEFORE_REVEAL_DIAL hook with the player's choice.
	var dial_discarded: bool = false
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry:
		var ctx: EffectContext = EffectContext.new()
		ctx.set_meta_value("ship", ship)
		ctx.set_meta_value("damage_deck", _damage_deck)
		ctx.set_meta_value("dial_discarded", chose_discard)
		ctx.set_meta_value("effect_registry", registry)
		registry.resolve_hook(&"BEFORE_REVEAL_DIAL", ctx)
		dial_discarded = ctx.get_meta_value(
				"crew_panic_dial_discarded", false) as bool
		if ctx.get_meta_value("extra_damage_dealt", false) as bool:
			_submit_persistent_damage(ship,
					str(ctx.get_meta_value("persistent_effect_id", "")))
	if dial_discarded:
		_finish_crew_panic_dial_discarded(ship, ship_key)
	else:
		# Player chose to suffer damage — resume the normal drag flow.
		_dial_drag_controller.start_dial_drag(ship)

## Lazily creates the Crew Panic choice modal.
func _ensure_crew_panic_modal() -> void:
	if _crew_panic_modal != null:
		return
	_crew_panic_modal = OpponentChoiceModal.new()
	_crew_panic_modal.name = "CrewPanicModal"
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CrewPanicModalLayer"
	layer.layer = 95
	add_child(layer)
	layer.add_child(_crew_panic_modal)

## Called (one-shot) when the player resolves a token overflow discard.
## Shows the activation sequence button now that the token count is legal.
func _on_token_discard_resolved(_ship: RefCounted, _discarded: int) -> void:
	_show_activation_sequence_button()
	_log.info("Token discard resolved — showing activation sequence button.")

## Checks both card panels for a ship entry at [param screen_pos].
## Returns the [ShipInstance] if found, or null.
func _find_card_panel_hit(screen_pos: Vector2) -> ShipInstance:
	if _panel_mgr.rebel_card_panel:
		var hit: ShipInstance = _panel_mgr.rebel_card_panel \
				.get_ship_instance_at_screen_pos(screen_pos)
		if hit:
			return hit
	if _panel_mgr.imperial_card_panel:
		var hit: ShipInstance = _panel_mgr.imperial_card_panel \
				.get_ship_instance_at_screen_pos(screen_pos)
		if hit:
			return hit
	return null

## Called when End Activation is pressed — cleans up the dial sprite on the
## board, activation modal, and resets activation visual state.
## Requirements: UI-026, FLOW-002.
func _on_board_activation_ended() -> void:
	if _activation_ctx.activating_ship_token:
		_activation_ctx.activating_ship_token.hide_revealed_dial()
	_activation_ctx.clear()
	_panel_mgr.end_activation_button.hide_button()
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.close_and_clear()
	_squadron_phase_controller.hide_ui()
	if _panel_mgr.activation_sidebar:
		_panel_mgr.activation_sidebar.clear_active()
		_panel_mgr.activation_sidebar.refresh()
	_dismiss_maneuver_tool_with_preview()
	_range_tool_controller.dismiss()
	# Re-enable simulation tool buttons.
	if _panel_mgr.action_toolbar:
		_panel_mgr.action_toolbar.set_tool_buttons_disabled(false)

# ---------------------------------------------------------------------------
# Ship Activation Sequence (Phase 5b)
# ---------------------------------------------------------------------------

## Shows the "Show Activation Sequence" button at bottom-centre.
## Replaces the old direct "End Activation" after dial reveal.
## Requirements: ACT-007, FLOW-002.
func _show_activation_sequence_button() -> void:
	if _panel_mgr.show_activation_button == null:
		return
	_panel_mgr.show_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.show_activation_button.update_position(vp_size)

## Hides all Phase 5b UI elements (activation button, modal).
func _hide_phase5b_ui() -> void:
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.close_and_clear()
	if _activation_ctx.activating_ship_token:
		_activation_ctx.activating_ship_token.hide_revealed_dial()
	_activation_ctx.clear()

## Called when the activation modal is dismissed (Escape or ✕ Close).
## Re-shows the "Show Activation Sequence" button so the player can reopen,
## unless the attack panel is currently active (same screen position).
func _on_activation_modal_closed() -> void:
	_log.info("Activation modal dismissed by player.")
	if _activation_ctx.ship_activation_state == null or _panel_mgr.show_activation_button == null:
		return
	# Do not show the button while the attack executor is active —
	# both occupy the same bottom-centre position.
	if _attack_executor and _attack_executor.is_in_exec_mode():
		return
	# Do not show the button while the squadron command modal is active.
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_modal_visible() \
			and _squadron_phase_controller.is_command_mode():
		return
	_panel_mgr.show_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.show_activation_button.update_position(vp_size)

## Called when the player presses "Execute Attack ►" in the activation modal.
## Sets up the attack execution flow: shows the range overlay for the
## activated ship, opens the info panel, and enters hull-zone selection mode.
## Requirements: AE-FLOW-001, AE-ACT-001.
func _on_attack_step_entered() -> void:
	_log.info("Attack step entered — delegating to AttackExecutor.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot start attack — no activation state or token.")
		return
	# Hide the "Show Activation Sequence" button while the attack panel
	# is on-screen — both occupy the same bottom-centre position.
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _attack_executor:
		_attack_executor.start_ship_attack(_activation_ctx.activating_ship_token)

## Called when the player presses "Execute Repair ►" in the activation modal.
## Creates a RepairResolver and opens the RepairPanel.
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
func _on_repair_step_entered() -> void:
	_log.info("Repair step entered — opening RepairPanel.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot start repair — no activation state or token.")
		return
	var ship: ShipInstance = _activation_ctx.activating_ship_token.get_ship_instance()
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
				+"Consuming dial/token and auto-advancing.")
		var token_result: Dictionary = resolver.finalize()
		_submit_resolver_spends(ship, token_result)
		_on_repair_done()
		return
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.repair_panel:
		_panel_mgr.repair_panel.open(resolver, ship)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_panel_mgr.repair_panel.centre_on_screen(vp_size)

## Called when the player presses "Execute Squadron ►" in the activation modal.
## Creates a SquadronCommandResolver and opens the SquadronActivationModal
## in command mode.
## Rules Reference: RRG "Commands" p.4 — Squadron; CM-020–CM-022.
func _on_squadron_step_entered() -> void:
	_log.info("Squadron step entered — starting squadron command flow.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot start squadron command — no activation state.")
		return
	var ship: ShipInstance = _activation_ctx.activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var ship_token: ShipToken = _activation_ctx.activating_ship_token
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, ship_token.global_position, ship_token.global_rotation,
			ship_token.get_half_width(), ship_token.get_half_length())
	if resolver.is_empty():
		_log.info("No squadron activations available — auto-advancing.")
		_on_squadron_command_done()
		return
	if not _has_eligible_squadron_in_range(ship, resolver):
		_log.info("No friendly squadrons in range — consuming resources "
				+"and auto-advancing.")
		var token_result: Dictionary = resolver.finalize()
		_submit_resolver_spends(ship, token_result)
		_on_squadron_command_done()
		return
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	_squadron_phase_controller.open_for_command(resolver, _activation_ctx.activating_ship_token)

## Returns true if at least one friendly non-activated squadron is within
## range of the ship's squadron command resolver.
func _has_eligible_squadron_in_range(ship: ShipInstance,
		resolver: SquadronCommandResolver) -> bool:
	var tokens: Array[SquadronToken] = get_squadron_tokens()
	for sq_token: SquadronToken in tokens:
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and not sq_inst.is_destroyed() \
				and sq_inst.owner_player == ship.owner_player \
				and resolver.is_squadron_in_range(sq_token.global_position):
			return true
	return false

## Called when the player presses "Skip" on the squadron step (token only).
## Advances the activation step without entering the squadron command flow.
## Rules Reference: "Commands" p.4 — spending a command token is optional.
func _on_squadron_step_skipped() -> void:
	_log.info("Squadron step skipped by player (token not spent).")
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	_submit_network_activation_step("repair_step")
	_configure_and_open_activation_modal()

## Called when the squadron command flow is complete (all activations used
## or the player finishes early).
## Finalizes the resolver (spends dial/token), advances the activation
## step, and re-opens the activation modal.
## Rules Reference: CM-020.
func _on_squadron_command_done() -> void:
	_log.info("Squadron command done — advancing activation step.")
	_squadron_phase_controller.dismiss_cmd_range_overlay()
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	_submit_network_activation_step("repair_step")
	# Show the activation button again.
	if _panel_mgr.show_activation_button and _activation_ctx.activating_ship_token:
		_panel_mgr.show_activation_button.show_button()
	_configure_and_open_activation_modal()


## Submits [SpendDialCommand] and/or [SpendTokenCommand] based on a
## resolver's return dictionary.
## [param ship] — the ship that resolved the command.
## [param result] — the dictionary returned by [code]finalize()[/code] or
## [code]mark_maneuver_executed()[/code]; may contain [code]"dial_spent"[/code]
## and/or [code]"token_type"[/code].
func _submit_resolver_spends(ship: ShipInstance,
		result: Dictionary) -> void:
	if result.get("dial_spent", false):
		GameManager.submit_spend_dial(ship)
	if result.has("token_type"):
		GameManager.submit_spend_token(ship, result["token_type"])


## Called when the repair panel finishes (Done or Skip pressed).
## Advances activation state and re-opens the activation modal.
func _on_repair_done() -> void:
	_log.info("Repair done — advancing activation step.")
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	_submit_network_activation_step("attack_step")
	_configure_and_open_activation_modal()

## Called when the attack execution step is fully complete.
## Advances activation state and re-opens the modal.
## Routes to the squadron modal when a squadron attack just completed.
## Requirements: AE-FLOW-003, AE-CONF-002, SQA-ATK-003.
func _on_attack_exec_completed() -> void:
	_log.info("Attack exec completed — advancing activation step.")
	# Phase 7b: squadron attack completed — route to squadron modal.
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_in_attacking_state():
		_squadron_phase_controller.notify_attack_completed()
		return
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	_submit_network_activation_step("maneuver_step")
	_configure_and_open_activation_modal()

## Called when the player cancels attack execution (Escape).
## Re-opens the activation modal without advancing.
## Routes to the squadron modal when a squadron attack was cancelled.
## Requirements: AE-FLOW-004, SQA-ATK-005.
func _on_attack_exec_cancelled() -> void:
	_log.info("Attack exec cancelled — returning to activation modal.")
	# Phase 7b: squadron attack cancelled — route to squadron modal.
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_in_attacking_state():
		_squadron_phase_controller.notify_attack_cancelled()
		return
	_configure_and_open_activation_modal()

## Called when the player presses "Show Activation Sequence".
## Opens the activation modal and starts the step sequence.
## Requirements: ACT-001, ACT-007.
func _on_activation_sequence_requested() -> void:
	_log.info("Activation sequence requested.")
	if _activation_ctx.ship_activation_state == null:
		_log.info("No activation state — cannot open modal.")
		return
	_configure_and_open_activation_modal()

## Called when the activation modal reaches the Execute Maneuver step.
## Shows the maneuver tool on the activating ship and the Execute Maneuver
## button. For speed 0, skips the tool and executes immediately.
## Requirements: FLOW-003, AC-5b-03, EXE-004.
func _on_maneuver_step_entered() -> void:
	_log.info("Maneuver step entered.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot show maneuver tool — state=%s, token=%s." % [
				str(_activation_ctx.ship_activation_state != null),
				str(_activation_ctx.activating_ship_token != null)])
		return
	var ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	# Speed 0: no tool, ship stays in place, maneuver counts as executed.
	if ship.current_speed == 0:
		_log.info("Speed 0 — executing maneuver without tool.")
		var token_result: Dictionary = _activation_ctx.ship_activation_state.mark_maneuver_executed()
		_submit_resolver_spends(ship, token_result)
		EventBus.ship_moved.emit(_activation_ctx.activating_ship_token)
		_show_end_activation_after_maneuver()
		return
	# Show the maneuver tool in activation mode.
	_maneuver_tool_controller.show_activation_tool(
			_activation_ctx.activating_ship_token,
			_activation_ctx.ship_activation_state)
	# Disable the simulation maneuver button while activation tool is active.
	if _panel_mgr.action_toolbar:
		_panel_mgr.action_toolbar.set_tool_buttons_disabled(true)
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
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		return
	if _maneuver_tool_controller.get_scene() == null:
		return
	var final_xform: Transform2D = _resolve_maneuver_overlaps_ex()
	_activation_ctx.activating_ship_token.global_position = final_xform.origin
	_activation_ctx.activating_ship_token.global_rotation = final_xform.get_rotation()
	# Ship–squadron overlap resolution (OV-001–004).
	var ship_size: Constants.ShipSize = _activation_ctx.activating_ship_token.get_ship_size()
	var moved_ship_base: ShipBase = ShipBase.new(ship_size, final_xform)
	var displaced: Array[SquadronToken] = _find_displaced_squadrons(
			moved_ship_base)
	var token_result: Dictionary = _activation_ctx.ship_activation_state.mark_maneuver_executed()
	var maneuver_ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	_submit_resolver_spends(maneuver_ship, token_result)

	# Record the maneuver via command for replay determinism.
	var mt_scene_ref: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if mt_scene_ref:
		var tool_st: ManeuverToolState = mt_scene_ref.get_state()
		var spd: int = tool_st.get_speed()
		var all_clicks: Array[int] = tool_st.get_joint_clicks()
		# Slice to active joints only (joint_count == speed).
		var active_clicks: Array = []
		for i: int in range(mini(spd, all_clicks.size())):
			active_clicks.append(all_clicks[i])
		var pa: Vector2 = GameScale.play_area_size_px
		if pa.x > 0.0 and pa.y > 0.0:
			var norm_x: float = final_xform.origin.x / pa.x
			var norm_y: float = final_xform.origin.y / pa.y
			var rot_deg: float = rad_to_deg(final_xform.get_rotation())
			GameManager.submit_execute_maneuver(maneuver_ship,
					spd, active_clicks, norm_x, norm_y, rot_deg)

	# AFTER_MANEUVER_EXECUTE hook — Ruptured Engine and Damaged Controls.
	# Rules Reference: "Ruptured Engine" / "Damaged Controls" card texts.
	_resolve_after_maneuver_hook(_activation_ctx.last_maneuver_overlapped)
	# ON_SPEED_CHANGE hook — Thruster Fissure deals facedown damage.
	# Only fires if the player's final speed differs from the original.
	# Deferred to commit time because speed changes are reversible during preview.
	# Rules Reference: "Thruster Fissure" card text.
	if _activation_ctx.ship_activation_state.get_total_speed_change() != 0:
		_resolve_speed_change_hook()
	EventBus.ship_moved.emit(_activation_ctx.activating_ship_token)
	_dismiss_maneuver_tool_with_preview()
	if displaced.size() > 0:
		_displacement_controller.start(displaced, moved_ship_base)
	else:
		_show_end_activation_after_maneuver()
	_log.info("Ship snapped to final position.")

## Computes the final transform after ship–ship overlap resolution.
## Applies overlap damage if a collision occurred.
## Sets [member _activation_ctx].last_maneuver_overlapped for the AFTER_MANEUVER_EXECUTE hook.
## Requirements: OV-010–013.
func _resolve_maneuver_overlaps_ex() -> Transform2D:
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	var tool_state: ManeuverToolState = mt_scene.get_state()
	var attach: Dictionary = mt_scene._compute_attachment()
	var start_pos: Vector2 = attach["position"]
	var start_rot: float = attach["rotation"]
	var ghost_side: String = tool_state.compute_ghost_side()
	var original_xform: Transform2D = Transform2D(
			_activation_ctx.activating_ship_token.global_rotation,
			_activation_ctx.activating_ship_token.global_position)
	var ship_size: Constants.ShipSize = _activation_ctx.activating_ship_token.get_ship_size()
	var other_bases: Array = _build_other_ship_bases(_activation_ctx.activating_ship_token)
	var resolver: OverlapResolver = OverlapResolver.new()
	var result: OverlapResolver.ShipShipResult = (
			resolver.check_ship_ship_overlap(
					tool_state, start_pos, start_rot, ghost_side,
					ship_size, other_bases, original_xform))
	_activation_ctx.last_maneuver_overlapped = result.overlaps or result.stayed_in_place
	if _activation_ctx.last_maneuver_overlapped:
		_apply_overlap_damage(result)
	else:
		if _panel_mgr.activation_modal:
			_panel_mgr.activation_modal.set_collision_message("")
	return result.final_transform

## Resolves the AFTER_MANEUVER_EXECUTE hook for persistent damage cards.
## Ruptured Engine: suffer 1 facedown if speed > 1.
## Damaged Controls: suffer 1 facedown if overlapping a ship or obstacle.
## Rules Reference: "Ruptured Engine", "Damaged Controls" card texts.
func _resolve_after_maneuver_hook(did_overlap: bool) -> void:
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry == null:
		return
	var ship: ShipInstance = _activation_ctx.activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", ship.current_speed)
	ctx.set_meta_value("did_overlap", did_overlap)
	ctx.set_meta_value("damage_deck", _damage_deck)
	ctx = registry.resolve_hook(&"AFTER_MANEUVER_EXECUTE", ctx)
	if ctx.get_meta_value("extra_damage_dealt", false) as bool:
		_submit_persistent_damage(ship,
				str(ctx.get_meta_value("persistent_effect_id", "")))


## Resolves the ON_SPEED_CHANGE hook after maneuver commit.
## Thruster Fissure: suffer 1 facedown damage when speed changes.
## Called only when total_speed_change != 0 (deferred from preview to commit).
## Rules Reference: "Thruster Fissure" card text.
func _resolve_speed_change_hook() -> void:
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry == null:
		return
	var ship: ShipInstance = _activation_ctx.activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("damage_deck", _damage_deck)
	ctx = registry.resolve_hook(&"ON_SPEED_CHANGE", ctx)
	if ctx.get_meta_value("extra_damage_dealt", false) as bool:
		_submit_persistent_damage(ship,
				str(ctx.get_meta_value("persistent_effect_id", "")))


## Shows the activation modal at the DONE step so the player can review
## all completed steps and deliberately end their activation.
## Replaces the previous auto-end behaviour (activation_ended was emitted
## immediately after maneuver).
## Requirements: AC-5b-11, FLOW-002.
func _show_end_activation_after_maneuver() -> void:
	# Update state to reflect completion.
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step() ## MANEUVER → DONE
	_submit_network_activation_step("activation_done")
	# If the modal is still open (normal commit path), just refresh it
	# so it shows all steps checked + "End Activation ►".  If it was
	# closed (displacement path closes it), re-open it.
	if _panel_mgr.activation_modal and _activation_ctx.ship_activation_state:
		_update_activation_modal_interactivity()
		if _panel_mgr.activation_modal.is_open():
			_panel_mgr.activation_modal.refresh()
		else:
			_configure_and_open_activation_modal()
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
			_activation_ctx.activating_ship_token.get_ship_instance())
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
	# Pre-draw cards from the damage deck.
	if _damage_deck == null:
		_log.error("No damage deck — cannot deal overlap damage.")
		return
	var m_card: DamageCard = _damage_deck.draw_card()
	if m_card == null:
		_log.error("Damage deck empty — cannot deal overlap damage.")
		return
	var other_inst: ShipInstance = null
	var o_card: DamageCard = null
	if other_token:
		other_inst = other_token.get_ship_instance()
	if other_inst:
		o_card = _damage_deck.draw_card()
	# Submit command with pre-drawn cards.
	var cmd_result: Dictionary = GameManager.submit_overlap_damage(
			moving_inst,
			other_inst if other_inst else moving_inst,
			m_card.serialize(),
			o_card.serialize() if o_card else m_card.serialize())
	if cmd_result.is_empty():
		_log.error("OverlapDamageCommand rejected.")
		return
	# Emit signals for the moving ship.
	_emit_overlap_signals(moving_inst,
			_activation_ctx.activating_ship_token, cmd_result,
			"moving_hull", "moving_destroyed")
	toast_parts.append("%s takes 1 damage."
			% moving_inst.ship_data.ship_name)
	# Emit signals for the overlapped ship.
	if other_inst and other_token:
		_emit_overlap_signals(other_inst, other_token, cmd_result,
				"other_hull", "other_destroyed")
		toast_parts.append("%s takes 1 damage."
				% other_inst.ship_data.ship_name)
	# Show collision info inside the activation modal so it's unmissable.
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.set_collision_message("\n".join(toast_parts))
	_log.info("Overlap damage applied: %s" % " | ".join(toast_parts))


## Emits EventBus signals for one side of an overlap damage result.
func _emit_overlap_signals(inst: ShipInstance, token: ShipToken,
		cmd_result: Dictionary, hull_key: String,
		destroyed_key: String) -> void:
	EventBus.damage_card_dealt.emit(inst, null, false)
	var new_hull: int = int(cmd_result.get(hull_key, 0))
	EventBus.ship_hull_changed.emit(inst, new_hull)
	EventBus.ship_damaged.emit(token, 1, Constants.HullZone.FRONT)
	if cmd_result.get(destroyed_key, false) as bool:
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


## Pre-draws a card from [member _damage_deck] and submits a
## [PersistentEffectDamageCommand] for the given ship and effect.
## Emits [code]damage_card_dealt[/code], [code]ship_hull_changed[/code],
## and — on destruction — [code]ship_destroyed[/code] + fade-out.
func _submit_persistent_damage(ship: ShipInstance,
		eff_id: String) -> void:
	if _damage_deck == null:
		return
	var card: DamageCard = _damage_deck.draw_card()
	if card == null:
		return
	var result: Dictionary = GameManager.submit_persistent_effect_damage(
			ship, eff_id, card.serialize())
	if not result.is_empty():
		EventBus.damage_card_dealt.emit(ship, null, false)
		var new_hull: int = int(result.get("new_hull", 0))
		EventBus.ship_hull_changed.emit(ship, new_hull)
		_log.info("Persistent damage (%s) dealt (hull now %d)." % [
				eff_id, new_hull])
		if result.get("destroyed", false) as bool:
			var token: ShipToken = _find_ship_token_for_instance(ship)
			if token:
				_log.info("Ship destroyed by %s: %s" % [eff_id, ship.data_key])
				EventBus.ship_destroyed.emit(token)
				_fade_out_destroyed_token(token)

## Shows a brief toast when a damage card is dealt to a ship.
## Faceup cards show the card name in red; facedown cards show a generic message.
## [param ship_instance] — the ShipInstance receiving the card.
## [param card] — the DamageCard that was dealt.
## [param is_faceup] — true if dealt faceup (critical), false if facedown.
func _on_damage_card_dealt(ship_instance: RefCounted, card: RefCounted,
		is_faceup: bool) -> void:
	var ship_name: String = "Ship"
	if ship_instance is ShipInstance and ship_instance.ship_data:
		ship_name = ship_instance.ship_data.ship_name
	var msg: String = ""
	if is_faceup and card is DamageCard:
		var dc: DamageCard = card as DamageCard
		msg = "%s — CRIT: %s" % [ship_name, dc.title]
	else:
		msg = "%s — damage card dealt" % ship_name
	TooltipManager.show_text(msg, Vector2.INF, 2.0, true)

## Returns the [ShipToken] corresponding to an index among the "other"
## ships (excluding the active ship, matching _build_other_ship_bases order).
func _get_other_ship_token(index: int) -> ShipToken:
	if index < 0:
		return null
	var idx: int = 0
	for token: ShipToken in get_ship_tokens():
		if token == _activation_ctx.activating_ship_token:
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

# ---------------------------------------------------------------------------
# Maneuver Tool (Phase 5a)
# ---------------------------------------------------------------------------
## Handles the "Display Maneuver Tool" button press.
## Requirements: MT-U-002, MT-U-003.
func _on_maneuver_tool_requested() -> void:
	# Block simulation requests while the activation-mode maneuver tool
	# is active — the player must use the modal's Commit button instead.
	if _activation_ctx.ship_activation_state != null \
			and _maneuver_tool_controller.get_scene() != null:
		_log.info("Simulation maneuver blocked — activation maneuver in progress.")
		return
	if _maneuver_tool_controller.get_scene():
		_dismiss_maneuver_tool_with_preview()
		return
	if _maneuver_tool_controller.is_selecting():
		_maneuver_tool_controller.cancel_selection()
		return
	_maneuver_tool_controller.start_selection()

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
	if _panel_mgr.action_toolbar == null:
		return false
	if _panel_mgr.action_toolbar._maneuver_tool_btn and _panel_mgr.action_toolbar._maneuver_tool_btn.disabled:
		return false
	return true
## Handles the "Range Overlay" button press.
## Toggle behaviour: if an overlay is already visible, dismiss it.
## If selecting, cancel selection. Otherwise enter selection mode.
## When a maneuver tool is active, toggles the overlay on the ghost
## preview instead of requiring ship selection.
## Requirements: RO-001, RO-002.
func _on_range_overlay_requested() -> void:
	# If a maneuver tool is active, toggle the overlay on the ghost.
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if mt_scene:
		mt_scene.toggle_ghost_range_overlay()
		return
	if _range_tool_controller.get_scene():
		_range_tool_controller.dismiss()
		return
	if _range_tool_controller.is_selecting():
		_range_tool_controller.cancel_selection()
		return
	_range_tool_controller.start_selection()


# ---------------------------------------------------------------------------
# Attack Executor — Setup & Delegation
# ---------------------------------------------------------------------------

## Creates the [TargetSelector] child node.
func _create_target_selector() -> void:
	_target_selector = TargetSelector.new()
	_target_selector.name = "TargetSelector"
	add_child(_target_selector)
	_target_selector.initialize(
			get_ship_tokens, get_squadron_tokens,
			_token_container, _camera, AttackState.new(),
			AttackDiceResolver.new())
	_target_selector.dismiss_other_tools_requested.connect(
			_on_dismiss_other_tools_requested)

## Creates the [AttackExecutor] child node and wires its signals.
func _create_attack_executor() -> void:
	_attack_executor = AttackExecutor.new()
	_attack_executor.name = "AttackExecutor"
	add_child(_attack_executor)
	_attack_executor.initialize(_target_selector, _camera)
	_attack_executor.attack_exec_completed.connect(
			_on_attack_exec_completed)
	_attack_executor.attack_exec_cancelled.connect(
			_on_attack_exec_cancelled)

## Creates the [ManeuverToolController] child node.
func _create_maneuver_tool_controller() -> void:
	_maneuver_tool_controller = ManeuverToolController.new()
	_maneuver_tool_controller.name = "ManeuverToolController"
	add_child(_maneuver_tool_controller)
	_maneuver_tool_controller.initialize(_token_container)

## Creates the [RangeToolController] child node.
func _create_range_tool_controller() -> void:
	_range_tool_controller = RangeToolController.new()
	_range_tool_controller.name = "RangeToolController"
	add_child(_range_tool_controller)
	_range_tool_controller.initialize(_token_container)

## Creates the [TargetingListController] child node.
func _create_targeting_list_controller() -> void:
	_targeting_list_controller = TargetingListController.new()
	_targeting_list_controller.name = "TargetingListController"
	add_child(_targeting_list_controller)
	_targeting_list_controller.initialize(
			get_ship_tokens, get_squadron_tokens,
			_maneuver_tool_controller, _panel_mgr, self )

## Creates the [SquadronPhaseController] child node and wires its signals.
func _create_squadron_phase_controller() -> void:
	_squadron_phase_controller = SquadronPhaseController.new()
	_squadron_phase_controller.name = "SquadronPhaseController"
	add_child(_squadron_phase_controller)
	var start_sq_attack: Callable = func(token: SquadronToken) -> void:
		if _attack_executor:
			_attack_executor.start_squadron_attack(token)
	var show_act_btn: Callable = func() -> void:
		if _panel_mgr and _panel_mgr.show_activation_button \
				and _activation_ctx.activating_ship_token:
			_panel_mgr.show_activation_button.show_button()
	var highlight_sq: Callable = func(inst: Variant) -> void:
		if _panel_mgr and _panel_mgr.activation_sidebar:
			_panel_mgr.activation_sidebar.highlight_active(inst)
	_squadron_phase_controller.initialize(
			_token_container,
			get_squadron_tokens,
			start_sq_attack,
			show_act_btn,
			_move_squadron_token,
			highlight_sq,
	)
	_squadron_phase_controller.squadron_command_done.connect(
			_on_squadron_command_done)

## Dismisses the maneuver tool, passing the current activation ship so the
## Navigate-token spend preview overlay is cleared when appropriate.
func _dismiss_maneuver_tool_with_preview() -> void:
	var ship: ShipInstance = null
	if _activation_ctx.ship_activation_state:
		ship = _activation_ctx.ship_activation_state.get_ship()
	_maneuver_tool_controller.dismiss(ship)

## Creates the [DebugController] child node with overlay, HUD, and saver.
func _create_debug_controller() -> void:
	_debug_controller = DebugController.new()
	_debug_controller.name = "DebugController"
	add_child(_debug_controller)
	_debug_controller.initialize(self , get_ship_tokens, get_squadron_tokens)

## Creates the [DisplacementController] child node and wires its signals.
func _create_displacement_controller() -> void:
	_displacement_controller = DisplacementController.new()
	_displacement_controller.name = "DisplacementController"
	add_child(_displacement_controller)
	_displacement_controller.initialize(
			_camera, get_squadron_tokens, get_ship_tokens,
			_panel_mgr.show_activation_button,
			_panel_mgr.activation_modal)
	_displacement_controller.displacement_completed.connect(
			_show_end_activation_after_maneuver)

## Creates the [DialDragController] child node and wires its signals.
func _create_dial_drag_controller() -> void:
	var tm_layer: CanvasLayer = _panel_mgr.turn_management_layer
	_dial_drag_controller = DialDragController.new()
	_dial_drag_controller.name = "DialDragController"
	add_child(_dial_drag_controller)
	_dial_drag_controller.initialize(
			_find_ship_token_at, _find_card_panel_hit,
			_check_crew_panic_before_drag, tm_layer)
	_dial_drag_controller.ship_activated.connect(
			_on_dial_ship_activated)
	_dial_drag_controller.token_converted.connect(
			_on_dial_token_converted)

## Creates the [CommandPhaseController] child node and wires its signal.
func _create_command_phase_controller() -> void:
	_command_phase_controller = CommandPhaseController.new()
	_command_phase_controller.name = "CommandPhaseController"
	add_child(_command_phase_controller)
	_command_phase_controller.initialize()

## Delegates the Attack Simulator toolbar / keyboard toggle to the executor.
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
func _on_attack_simulator_requested() -> void:
	if _target_selector:
		_target_selector.on_simulator_requested()

## Called by [signal AttackExecutor.dismiss_other_tools_requested].
## Dismisses range overlay, targeting list, and maneuver tool.
func _on_dismiss_other_tools_requested() -> void:
	_range_tool_controller.dismiss()
	_targeting_list_controller.dismiss()
	_dismiss_maneuver_tool_with_preview()

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

# ---------------------------------------------------------------------------
# Debug Damage Dealing (Shift+D) — DBG-050, DBG-051, DBG-052
# ---------------------------------------------------------------------------

## All 22 damage card types: [effect_id, title, trait].
const DEBUG_DAMAGE_CARDS: Array[Array] = [
	["blinded_gunners", "Blinded Gunners", "Crew"],
	["comm_noise", "Comm Noise", "Crew"],
	["compartment_fire", "Compartment Fire", "Crew"],
	["crew_panic", "Crew Panic", "Crew"],
	["damaged_controls", "Damaged Controls", "Crew"],
	["injured_crew", "Injured Crew", "Crew"],
	["life_support_failure", "Life Support Failure", "Crew"],
	["capacitor_failure", "Capacitor Failure", "Ship"],
	["coolant_discharge", "Coolant Discharge", "Ship"],
	["damaged_munitions", "Damaged Munitions", "Ship"],
	["depowered_armament", "Depowered Armament", "Ship"],
	["disengaged_fire_control", "Disengaged Fire Control", "Ship"],
	["faulty_countermeasures", "Faulty Countermeasures", "Ship"],
	["point_defense_failure", "Point-Defense Failure", "Ship"],
	["power_failure", "Power Failure", "Ship"],
	["projector_misaligned", "Projector Misaligned", "Ship"],
	["ruptured_engine", "Ruptured Engine", "Ship"],
	["shield_failure", "Shield Failure", "Ship"],
	["structural_damage", "Structural Damage", "Ship"],
	["targeter_disruption", "Targeter Disruption", "Ship"],
	["thrust_control_malfunction", "Thrust Control Malfunction", "Ship"],
	["thruster_fissure", "Thruster Fissure", "Ship"],
]

## Handles Shift+D to enter debug damage targeting mode.
## Returns true if the event was consumed.
func _handle_debug_damage_shortcut(event: InputEvent) -> bool:
	if not DebugMode.enabled:
		return false
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode != KEY_D or not key_event.shift_pressed:
		return false
	_debug_damage_targeting = true
	TooltipManager.show_text(
			"Click a ship to deal faceup damage", Vector2.INF, 0.0, true)
	_log.info("Debug damage targeting mode entered (Shift+D).")
	get_viewport().set_input_as_handled()
	return true

## Handles Escape to cancel debug damage targeting mode.
## Returns true if the event was consumed.
func _handle_debug_damage_escape(event: InputEvent) -> bool:
	if not _debug_damage_targeting:
		return false
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	_cancel_debug_damage_targeting()
	get_viewport().set_input_as_handled()
	return true

## Cancels debug damage targeting mode and hides the tooltip.
func _cancel_debug_damage_targeting() -> void:
	_debug_damage_targeting = false
	_debug_damage_target_token = null
	TooltipManager.hide_tooltip()
	_log.info("Debug damage targeting cancelled.")

## Opens the damage card picker modal for the clicked ship.
func _open_debug_damage_modal(token: ShipToken) -> void:
	_debug_damage_targeting = false
	_debug_damage_target_token = token
	TooltipManager.hide_tooltip()
	_ensure_debug_damage_modal()
	var options: Array[Dictionary] = []
	for entry: Array in DEBUG_DAMAGE_CARDS:
		options.append({
			"id": entry[0] as String,
			"label": "%s (%s)" % [entry[1], entry[2]],
			"available": true,
		})
	var choice_info: Dictionary = {
		"card_title": "Debug: Deal Faceup Damage",
		"effect_text": "Choose a damage card to deal faceup.",
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"options": options,
	}
	_debug_damage_modal.open(choice_info)
	_log.info("Debug damage modal opened for '%s'." %
			token.get_ship_instance().ship_data.ship_name)

## Lazily creates the debug damage modal on a CanvasLayer.
func _ensure_debug_damage_modal() -> void:
	if _debug_damage_modal != null:
		return
	_debug_damage_modal = OpponentChoiceModal.new()
	_debug_damage_modal.name = "DebugDamageModal"
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DebugDamageModalLayer"
	layer.layer = 120
	add_child(layer)
	layer.add_child(_debug_damage_modal)
	_debug_damage_modal.choice_confirmed.connect(
			_on_debug_damage_card_chosen)

## Callback when the player picks a damage card from the debug modal.
func _on_debug_damage_card_chosen(selection: Dictionary) -> void:
	_debug_damage_modal.close_and_clear()
	var chosen_id: String = str(selection.get("id", ""))
	if chosen_id.is_empty():
		_log.warn("Debug damage: no card selected.")
		return
	if _debug_damage_target_token == null:
		_log.warn("Debug damage: no target ship.")
		return
	var ship: ShipInstance = _debug_damage_target_token.get_ship_instance()
	if ship == null:
		_log.warn("Debug damage: target has no ShipInstance.")
		return
	_debug_deal_faceup_card(ship, chosen_id)
	_debug_damage_target_token = null

## Draws a card from the damage deck, overrides its identity, and deals
## it faceup to the ship with the full pipeline.
## DBG-050 — debug damage dealing.
func _debug_deal_faceup_card(ship: ShipInstance,
		effect_id: String) -> void:
	if _damage_deck == null:
		TooltipManager.show_text("Damage deck not available", Vector2.INF, 3.0)
		return
	var card: DamageCard = _damage_deck.draw_card()
	if card == null:
		TooltipManager.show_text("Damage deck empty", Vector2.INF, 3.0)
		_log.warn("Debug damage: deck empty.")
		return
	# Find the title for this effect_id.
	var title: String = effect_id
	var timing: String = "persistent"
	for entry: Array in DEBUG_DAMAGE_CARDS:
		if entry[0] as String == effect_id:
			title = entry[1] as String
			break
	# Determine timing from data.
	match effect_id:
		"comm_noise", "injured_crew", "projector_misaligned", \
				"shield_failure", "structural_damage":
			timing = "immediate"
		"life_support_failure":
			timing = "immediate_persistent"
		_:
			timing = "persistent"
	# Override card identity.
	card.effect_id = effect_id
	card.title = title
	card.timing = timing
	card.trait_type = "Ship"
	for entry: Array in DEBUG_DAMAGE_CARDS:
		if entry[0] as String == effect_id:
			card.trait_type = entry[2] as String
			break
	# Look up the correct effect_text from damage_cards.json so the
	# immediate-choice modal shows the right description.
	var json_data: Dictionary = AssetLoader.load_json("", "damage_cards.json")
	if json_data.has("cards"):
		for cdef: Dictionary in json_data["cards"]:
			if cdef.get("effect_id", "") == effect_id:
				card.effect_text = cdef.get("effect_text", "")
				break
	card.is_faceup = true
	# Submit through command for replay/multiplayer safety.
	var result: Dictionary = GameManager.submit_debug_deal_damage(
			ship, card.serialize(), effect_id)
	if result.is_empty():
		_log.warn("Debug damage: command rejected.")
		return
	# Retrieve the actual card object added to the ship.
	var dealt_card: DamageCard = ship.faceup_damage.back()
	_log.info("Debug: dealt faceup '%s' [%s] to %s." % [
			title, effect_id, ship.ship_data.ship_name])
	if result.get("persistent_registered", false):
		_log.info("Debug: persistent effect registered for '%s'." % title)
	# Emit standard signals so UI updates (card panel, hull display).
	EventBus.damage_card_flipped.emit(ship, dealt_card, true)
	EventBus.damage_card_dealt.emit(ship, dealt_card, true)
	EventBus.ship_hull_changed.emit(
			ship, int(result.get("new_hull", 0)))
	# Resolve immediate effect if applicable.
	if ImmediateEffectResolver.is_immediate(dealt_card):
		_resolve_debug_immediate_effect(dealt_card, ship)
	TooltipManager.show_text(
			"Dealt: %s" % title, Vector2.INF, 2.5)

## Resolves an immediate damage card effect dealt via the debug tool.
## Auto-resolve cards resolve instantly; choice cards open a second
## modal for the player to make their selection.
func _resolve_debug_immediate_effect(card: DamageCard,
		ship: ShipInstance) -> void:
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var choice_info: Dictionary = resolver.get_required_choice(card, ship)
	if choice_info.is_empty():
		var extra_card_data: Dictionary = {}
		if card.effect_id == "structural_damage" and _damage_deck:
			var extra: DamageCard = _damage_deck.draw_card()
			if extra:
				extra_card_data = extra.serialize()
		var result: Dictionary = GameManager.submit_resolve_immediate_effect(
				ship, card, {}, extra_card_data)
		if not result.is_empty():
			_emit_debug_immediate_signals(card, ship, result)
			_log.info("Debug: immediate effect auto-resolved for '%s'." %
					card.title)
	else:
		# Choice needed — open a second modal using the same debug modal.
		_debug_immediate_card = card
		_debug_immediate_ship = ship
		_ensure_debug_damage_modal()
		_debug_damage_modal.choice_confirmed.disconnect(
				_on_debug_damage_card_chosen)
		_debug_damage_modal.choice_confirmed.connect(
				_on_debug_immediate_choice_confirmed)
		_debug_damage_modal.open(choice_info)
		_log.info("Debug: choice modal opened for immediate '%s'." %
				card.title)

## Callback when the player confirms their immediate-effect choice
## (e.g. Injured Crew token, Shield Failure zones, Comm Noise action).
func _on_debug_immediate_choice_confirmed(selection: Dictionary) -> void:
	_debug_damage_modal.close_and_clear()
	# Reconnect the normal handler.
	_debug_damage_modal.choice_confirmed.disconnect(
			_on_debug_immediate_choice_confirmed)
	_debug_damage_modal.choice_confirmed.connect(
			_on_debug_damage_card_chosen)
	if _debug_immediate_card == null or _debug_immediate_ship == null:
		return
	var extra_card_data: Dictionary = {}
	if _debug_immediate_card.effect_id == "structural_damage" and _damage_deck:
		var extra: DamageCard = _damage_deck.draw_card()
		if extra:
			extra_card_data = extra.serialize()
	var result: Dictionary = GameManager.submit_resolve_immediate_effect(
			_debug_immediate_ship, _debug_immediate_card,
			selection, extra_card_data)
	if not result.is_empty():
		_emit_debug_immediate_signals(
				_debug_immediate_card, _debug_immediate_ship, result)
		_log.info("Debug: immediate effect resolved for '%s'." %
				_debug_immediate_card.title)
	_debug_immediate_card = null
	_debug_immediate_ship = null


## Emits EventBus signals after a debug immediate effect command executes.
func _emit_debug_immediate_signals(card: DamageCard,
		ship: ShipInstance, result: Dictionary) -> void:
	var eid: String = result.get("effect_id", "") as String
	match eid:
		"structural_damage":
			EventBus.damage_card_flipped.emit(ship, card, false)
		"projector_misaligned":
			var zone: String = result.get("zone", "") as String
			if not zone.is_empty():
				EventBus.ship_shields_changed.emit(
						ship, zone,
						int(result.get("new_shields", 0)))
			EventBus.damage_card_flipped.emit(ship, card, false)
		"life_support_failure":
			EventBus.command_tokens_changed.emit(ship)
		"injured_crew":
			EventBus.ship_defense_token_changed.emit(ship)
			EventBus.damage_card_flipped.emit(ship, card, false)
		"shield_failure":
			var changes: Array = result.get("shield_changes", [])
			for sc: Variant in changes:
				var d: Dictionary = sc as Dictionary
				EventBus.ship_shields_changed.emit(
						ship, d.get("zone", ""),
						int(d.get("new_shields", 0)))
			EventBus.damage_card_flipped.emit(ship, card, false)
		"comm_noise":
			var action: String = result.get("action", "") as String
			if action == "reduce_speed":
				EventBus.ship_speed_changed.emit(
						ship, int(result.get("new_speed", 0)))
			elif action == "change_dial":
				EventBus.command_dials_changed.emit(ship)
			EventBus.damage_card_flipped.emit(ship, card, false)

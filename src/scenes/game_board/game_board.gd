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
## Play area extends to GameScale.play_area_size_px.
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
const SETUP_PLACEMENT_CONTROLLER_SCRIPT: GDScript = preload(
		"res://src/scenes/game_board/setup_placement_controller.gd")

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

## --- Tool Overlay Controller (Phase K11) ---

## Owns the maneuver tool, range overlay, and targeting list sub-controllers,
## the M / R / T / A keyboard shortcuts, the toolbar request handlers, and
## the dismiss-other-tools coordination.  Created in
## [method _create_tool_overlay_controller].
var _tool_overlay_controller: ToolOverlayController = null

## --- Command Router Adapter (Phase K12) ---

## Owns the [ModalRouter] composition root that subscribes to
## [signal CommandProcessor.command_executed], routes modal lifecycle
## projection, and delegates non-modal command reactions.  Created in
## [method _create_command_router_adapter].
var _command_router_adapter: CommandRouterAdapter = null

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

## Attack panel controller — owns the attack-panel mirror sync, the
## attacker-side defender-response routing into [AttackExecutor], and
## the Attack Simulator toolbar / keyboard toggle.  Created in
## [method _create_attack_panel_controller] (Phase K9).
var _attack_panel_controller: AttackPanelController = null

## Shared damage deck for the game. Initialised during scenario setup.
## SHARED — Created: _spawn_learning_scenario_tokens(). Read: attack
## executor (set_damage_deck), debug damage dealing, immediate effect
## resolution. Write: scenario setup only. Extractable: pass via
## initialize() to any controller needing damage draws.
var _damage_deck: DamageDeck = null

## --- Ship Activation Controller (Phase K8a) ---

## Owns activation-modal lifecycle, dial-drop entry points, the Crew Panic
## pre-reveal choice modal, and the projection-driven open/close +
## step-sync helpers.  Created in [method _create_ship_activation_controller].
## Maneuver / overlap resolution / step routing remain on this scene until
## the K8b extraction.
var _ship_activation_controller: ShipActivationController = null

## --- Phase 7b: Squadron Activation flow state ---

## Squadron phase controller — owns all squadron activation state and UI.
## Created in [method _create_squadron_phase_controller].
var _squadron_phase_controller: SquadronPhaseController = null

## Displacement controller — owns all displacement state and UI.
## Created in [method _create_displacement_controller].
var _displacement_controller: DisplacementController = null

## Setup placement controller — owns setup obstacle/deployment interaction.
## Created in [method _create_setup_placement_controller].
var _setup_placement_controller = null

func _ready() -> void:
	_create_board_components()
	_bootstrap_or_load_board_state()
	_finalize_ready_sequence()
	_show_fixed_round1_toast_if_needed()

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
	var play_area_size: Vector2 = GameScale.play_area_size_px
	if play_area_size.x <= 0.0 or play_area_size.y <= 0.0:
		return
	var area: Rect2 = Rect2(Vector2.ZERO, play_area_size)
	if _map_texture != null:
		draw_texture_rect_region(_map_texture, area, _map_source_rect(play_area_size))
	else:
		draw_rect(area, PLAY_AREA_COLOUR, true)
	draw_rect(area, BORDER_COLOUR, false, BORDER_WIDTH_PX)

func _process(_delta: float) -> void:
	# Phase 7b: Squadron follows mouse during MOVING state.
	if _squadron_phase_controller:
		_squadron_phase_controller.process_squadron_movement()
	if _setup_placement_controller:
		_setup_placement_controller.process_setup_dragging()

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
	if event is InputEventMagnifyGesture and _setup_placement_controller \
			and _setup_placement_controller.try_handle_rotate_input(
					event as InputEventMagnifyGesture):
		return

	if not DebugMode.has_selection():
		return
	if event is InputEventMagnifyGesture:
		_handle_debug_rotate(event as InputEventMagnifyGesture)

## Handles input for debug-mode interactions.
## DBG-003 — must not interfere with camera controls (right-click, scroll).
func _unhandled_input(event: InputEvent) -> void:
	if _try_handle_displacement_lock_click(event):
		return
	if _setup_placement_controller and _setup_placement_controller.try_handle_input(event):
		return
	if _tool_overlay_controller.try_handle_escape(event):
		return
	if _tool_overlay_controller.try_handle_tool_shortcut(event):
		return
	if _debug_controller and _debug_controller.try_handle_input(event):
		return
	if _panel_mgr.handle_quit_escape(event):
		return
	if DebugMode.enabled and event is InputEventMouseButton:
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
	_connect_board_core_signals()
	_connect_board_damage_and_remote_signals()
	_connect_board_passive_peer_visual_signals()


## Connects game-logic signals from UIPanelManager-created panels
## to game_board signal handlers.  Activation-modal, repair-panel, and
## show-activation-button signals are owned by [ShipActivationController]
## (Phase K8b) and connected from inside its [code]initialize()[/code].
func _connect_panel_signals() -> void:
	# Command phase controller — phase_complete updates HUD.
	_command_phase_controller.phase_complete.connect(
			_panel_mgr.update_phase_hud)


## Places all Learning Scenario tokens from setup data and loads the map image.
## Also creates [ShipInstance] / [SquadronInstance] runtime objects, registers
## them in [GameState] so GameManager tracks dial submission, binds instances
## to visual tokens, and adds ship cards to the side panels.
## Rules Reference: "Learning Scenario Setup", step 9, p.5; SU-010–030.
func _spawn_learning_scenario_tokens(scenario_id: String) -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new(scenario_id)
	var prepared: Dictionary = _prepare_learning_scenario_instances(setup)
	var ship_instances: Array[ShipInstance] = prepared["ships"] as Array[ShipInstance]
	var squad_instances: Array[SquadronInstance] = prepared["squadrons"] as Array[SquadronInstance]
	_apply_fixed_round1_commands_if_configured(setup)
	_spawn_and_bind_tokens(setup, ship_instances, squad_instances)
	_finalize_learning_scenario_spawn_ui()

## Spawns ship and squadron tokens from the already-installed loaded
## [GameState] (positions, hull damage, defense tokens, command dials,
## etc. already populated by [GameManager.start_new_game_from_state]).
## Used in place of [method _spawn_learning_scenario_tokens] when the
## board scene is entered after a save was loaded.  Phase J5.6.
##
## Differences from the scenario-JSON path:
## [br]- Skips [method _register_instances_in_game_state] (instances
##   are already in [member GameState.player_states]).
## [br]- Skips [code]apply_fixed_round1_commands[/code] (command-dial
##   stacks were serialised with the save).
## [br]- Reuses the loaded [member GameState.damage_deck] instead of
##   building a fresh one.
## [br]- Constructs [TokenPlacement] objects from each instance's
##   [code]pos_x[/code] / [code]pos_y[/code] / [code]rotation_deg[/code].
func _spawn_tokens_from_loaded_state() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new(
			GameManager.get_scenario_id())
	_load_map_texture(_map_image_for_loaded_state(setup))
	_init_scenario_systems_for_loaded_state()
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		_log.error("_spawn_tokens_from_loaded_state: no GameState.")
		return
	for player_index: int in [0, 1]:
		var ps: PlayerState = gs.get_player_state(player_index)
		if ps == null:
			continue
		_spawn_loaded_tokens_for_player(ps)
	_log.info("Spawned %d tokens from loaded state." %
			_token_container.get_child_count())
	_panel_mgr.update_card_panel_positions()
	_refresh_activation_sidebar_ui()

## Wires [member _attack_executor] / damage deck from the loaded
## [GameState] (no fresh deck construction).  Phase J5.6.
func _init_scenario_systems_for_loaded_state() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	_damage_deck = gs.damage_deck
	if _attack_executor and _damage_deck:
		_attack_executor.set_damage_deck(_damage_deck)
	if _debug_controller and _damage_deck:
		_debug_controller.set_damage_deck(_damage_deck)
	if _attack_executor and _panel_mgr.handoff_overlay:
		_attack_executor.set_handoff_overlay(_panel_mgr.handoff_overlay)

## Builds a [TokenPlacement] from a [ShipInstance]'s position fields.
func _placement_from_ship(ship: ShipInstance) -> TokenPlacement:
	return TokenPlacement.new(
			ship.data_key,
			true,
			ship.ship_data.faction,
			ship.pos_x,
			ship.pos_y,
			ship.get_rotation_rad(),
			ship.ship_data.ship_size)

## Builds a [TokenPlacement] from a [SquadronInstance]'s position fields.
func _placement_from_squadron(squad: SquadronInstance) -> TokenPlacement:
	return TokenPlacement.new(
			squad.data_key,
			false,
			squad.squadron_data.faction,
			squad.pos_x,
			squad.pos_y,
			squad.get_rotation_rad(),
			Constants.ShipSize.SMALL)

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
	if _debug_controller:
		_debug_controller.set_damage_deck(_damage_deck)
	if _attack_executor and _panel_mgr.handoff_overlay:
		_attack_executor.set_handoff_overlay(_panel_mgr.handoff_overlay)

## Spawns ship and squadron tokens and binds them to their instances.
##
## Position seeding has already been performed by
## [method _seed_instance_positions]; this method only spawns the
## visual nodes and binds them to the (already-positioned) instances.
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
	GameScale.configure_play_area_for_map_filename(filename)
	_map_texture = AssetLoader.load_texture("maps/", filename)
	if _map_texture != null:
		_log.info("Loaded map background: %s" % filename)
	else:
		_log.warn("Map image not found: maps/%s — using solid background." % filename)
	if _camera != null:
		_camera.reset_to_default_view()


func _map_source_rect(play_area_size: Vector2) -> Rect2:
	var texture_size: Vector2 = Vector2(_map_texture.get_width(), _map_texture.get_height())
	var source_size: Vector2 = Vector2(
			minf(play_area_size.x, texture_size.x),
			minf(play_area_size.y, texture_size.y))
	return Rect2((texture_size - source_size) * 0.5, source_size)


func _map_image_for_loaded_state(setup: LearningScenarioSetup) -> String:
	var payload_filename: String = _state_map_filename()
	if not payload_filename.is_empty():
		return payload_filename
	return setup.get_map_image_filename()


func _state_map_filename() -> String:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return ""
	var payload: Variant = gs.objectives.get(FleetSetupBootstrapper.KEY_MAP, {})
	if payload is Dictionary:
		return str((payload as Dictionary).get("filename", "")).strip_edges()
	return ""

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
	if _setup_placement_controller \
			and _setup_placement_controller.try_handle_ship_click(token):
		return
	if _target_selector and _target_selector.handle_ship_click(token):
		return
	if _tool_overlay_controller.try_handle_token_click(token):
		return
	if _debug_controller and _debug_controller.is_damage_targeting():
		_debug_controller.open_damage_modal_for_token(token)
		return
	if DebugMode.enabled:
		DebugMode.select_token(token)
		_debug_controller.reset_zone_tracking()
	else:
		EventBus.element_selected.emit(token)

## Called when a squadron token is clicked.
func _on_squadron_clicked(token: SquadronToken) -> void:
	if _setup_placement_controller \
			and _setup_placement_controller.try_handle_squadron_click(token):
		return
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
	var play_area_size: Vector2 = GameScale.play_area_size_px
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	var enforce_zones: bool = not DebugMode.enabled

	if token is ShipToken:
		_move_ship_token(
				token as ShipToken, mouse_world, play_area_size,
				top_y, bottom_y, enforce_zones)
	elif token is SquadronToken:
		_move_squadron_token(
				token as SquadronToken, mouse_world, play_area_size,
				top_y, bottom_y, enforce_zones)

	# Check zone crossing for toast warning (debug mode only).
	if DebugMode.enabled:
		_debug_controller.check_zone_crossing_toast(token, top_y, bottom_y)

## Resolves and applies position for a ship token.
## DBG-032, DBG-034 — enforce_zones=false in debug mode.
func _move_ship_token(
		token: ShipToken, desired: Vector2, play_area_size: Vector2,
		top_y: float, bottom_y: float, enforce_zones: bool
) -> void:
	var other_ships: Array = _build_other_ship_rects(token)
	var other_squads: Array = _build_other_squad_circles(token)
	var new_pos: Vector2 = _token_mover.resolve_ship_position_in_area(
			desired, token.position,
			token.get_ship_size(), token.rotation,
			token.get_faction(),
			other_ships, other_squads,
			top_y, bottom_y, play_area_size, enforce_zones)
	token.position = new_pos

## Resolves and applies position for a squadron token.
## DBG-032, DBG-034 — enforce_zones=false in debug mode.
func _move_squadron_token(
		token: SquadronToken, desired: Vector2, play_area_size: Vector2,
		top_y: float, bottom_y: float, enforce_zones: bool
) -> void:
	var other_ships: Array = _build_other_ship_rects(token)
	var other_squads: Array = _build_other_squad_circles(token)
	var new_pos: Vector2 = _token_mover.resolve_squadron_position_in_area(
			desired, token.position,
			token.get_radius_px(), token.get_faction(),
			other_ships, other_squads,
			top_y, bottom_y, play_area_size, enforce_zones)
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
			_ship_activation_controller.hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()
		Constants.GamePhase.SHIP:
			# Button hidden until a ship is activated via dial drag (Phase 4c).
			_panel_mgr.end_activation_button.hide_button()
			_ship_activation_controller.hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()
		Constants.GamePhase.SQUADRON:
			# Phase 7b: Squadron modal opens after handoff.
			_panel_mgr.end_activation_button.hide_button()
			_ship_activation_controller.hide_phase5b_ui()
			_panel_mgr.show_activation_button.hide_button()
		_:
			_panel_mgr.end_activation_button.hide_button()
			_ship_activation_controller.hide_phase5b_ui()
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
## Projects a turn-transition intent so shared-screen and network seats use
## one rendering path for camera/card perspective, HUD status, and prompts.
## Requirements: TF-001, BP-001, BP-003, HO-001, HO-004.  G4.6.5.7/8.
func _on_active_player_changed(player_index: int) -> void:
	var phase: Constants.GamePhase = GameManager.get_current_phase()
	var intent: UIProjector.UIIntent = UIProjector.project_turn_transition(
			phase, player_index, _local_viewer(), _is_shared_screen(),
			GameManager.current_game_state)
	_apply_turn_transition_intent(intent, phase)

## Called when the handoff overlay or banner is dismissed by the player.
## Resumes the appropriate game flow for the current phase.
## Requirements: HO-002, HO-004.
func _on_handoff_accepted() -> void:
	# Only proceed when the local viewer is the active player.  In hot-seat
	# this is always true (handoff overlay swaps active_player to the
	# dismisser).  In network mode this prevents opening SqActModal for the
	# remote player's squadrons.  Phase I6e.
	if GameManager.active_player != _local_viewer():
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
func _swap_card_panels(player_index: int, player_faction: int) -> void:
	var rebel_left: bool = _is_rebel_panel_left(player_index, player_faction)
	_panel_mgr.rebel_card_panel.set_side(rebel_left)
	_panel_mgr.imperial_card_panel.set_side(not rebel_left)
	_panel_mgr.update_card_panel_positions()


func _is_rebel_panel_left(player_index: int, player_faction: int) -> bool:
	if player_faction >= 0:
		return player_faction == int(Constants.Faction.REBEL_ALLIANCE)
	return player_index == 0


# ---------------------------------------------------------------------------
# Command-executed routing
# ---------------------------------------------------------------------------
# The single subscription to [signal CommandProcessor.command_executed]
# and all per-command-type routing (attack panel, debug damage, ship
# activation modal lifecycle, network displacement modal lifecycle)
# lives on [CommandRouterAdapter] (Phase K12).


## Returns the player index whose perspective is shown locally on this peer.
##
## In network mode this is [code]NetworkManager.get_local_player_index()[/code].
## In hot-seat both players share one screen, so the local viewer follows
## [code]GameManager.get_active_player()[/code] (which the handoff overlay
## swaps between activations).  Phase I6e helper — replaces the
## [code]if PlayMode.is_network(): ... else: active_player[/code] pattern.
func _local_viewer() -> int:
	var idx: int = NetworkManager.get_local_player_index()
	if idx < 0:
		return GameManager.get_active_player()
	return idx


## Returns whether this peer is responsible for executing the actions of
## [param player_index].
##
## In network mode only the matching peer acts.  In hot-seat both players
## share one process, so this peer always acts on behalf of either player.
## Phase I6e helper — distinct from [method _local_viewer] because the
## chooser/controller of a sub-flow may be the **opposite** of the local
## viewer (e.g. defender during attack), but the hot-seat process must
## still run the logic for them.
func _can_act_as(player_index: int) -> bool:
	var idx: int = NetworkManager.get_local_player_index()
	return idx < 0 or idx == player_index


## Returns whether [param result] indicates the command was submitted to
## the server and is now awaiting the authoritative broadcast.
##
## Phase I6e-3 (sentinel slice): [NetworkCommandSubmitter] now returns
## [constant NetworkCommandSubmitter.AWAITING_REMOTE_RESULT] (which
## carries [code]awaiting_remote: true[/code]) on submit, distinct from
## the truly-empty [code]{}[/code] that local /
## [NetworkHostCommandSubmitter] return on validation rejection.  This
## helper now reads the sentinel directly — no [method PlayMode.is_network]
## branch required.
func _is_pending_remote_result(result: Dictionary) -> bool:
	return result.get("awaiting_remote", false)


## Returns whether [param result] is the synchronous [code]{}[/code] that
## a local submitter ([LocalCommandSubmitter] /
## [NetworkHostCommandSubmitter]) returns when a command is rejected by
## validation.  Phase I6e-3 helper — distinct from
## [method _is_pending_remote_result] thanks to the
## [code]awaiting_remote[/code] sentinel.
func _is_local_command_rejection(result: Dictionary) -> bool:
	return result.is_empty()


## Returns whether the local player may interact with SqActModal controls.
##
## In the Squadron Phase the controller is always the active player —
## there is no sub-step where the non-active player needs interactivity.
## [code]GameManager._advance_squadron_phase_turn[/code] does not update
## [member InteractionFlow.controller_player] on the implicit between-turn
## handoff, so reading [code]flow.controller_player[/code] would gate on
## stale data.  Always trust [code]active_player[/code] here.  G4 Phase I5c.
## Phase I6e: hot-seat and network unified via [method _local_viewer].
func _is_local_squadron_modal_controller() -> bool:
	return GameManager.get_active_player() == _local_viewer()


# ---------------------------------------------------------------------------
# Dial drag-and-drop — Ship Activation (Phase 4c)
# Drag state + preview UI managed by DialDragController.
# ---------------------------------------------------------------------------

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
	# Note: do NOT emit [signal EventBus.squadron_moved] here.  The only
	# listener is [SfxManager], and replaying the flyby SFX on the passive
	# peer plays an unwanted sound when the opponent moves a squadron.
	# The active peer's [SquadronPhaseController._on_squadron_move_commit]
	# already emits the signal locally for the player who made the move.


## Fades and hides the SquadronToken matching a destroyed
## [SquadronInstance].  Idempotent: skips tokens that are already
## invisible (e.g. attacker peer where [AttackExecutor._fade_out_token]
## already ran).  Closes the passive-peer-destroy gap where the network
## client kept showing the token after a kill.
func _on_squadron_destroyed_fade_token(sq_or_token: Variant) -> void:
	var token: SquadronToken = null
	if sq_or_token is SquadronToken:
		token = sq_or_token as SquadronToken
	elif sq_or_token is SquadronInstance:
		token = _find_squadron_token_for_instance(
				sq_or_token as SquadronInstance)
	if token == null or not token.visible:
		return
	token.set_process_unhandled_input(false)
	var tween: Tween = token.create_tween()
	tween.tween_property(token, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		token.visible = false
		token.modulate.a = 1.0
	)


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

# Activation step routing, maneuver execute, and overlap resolution
# moved to ShipActivationController in Phase K8b.

# ---------------------------------------------------------------------------
# Persistent damage helper (used by ShipActivationController via Callable)
# ---------------------------------------------------------------------------


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
## Command-result routing emits card, hull, and destruction presentation events.
## Returns the submitted command result, or an empty dictionary on failure.
func _submit_persistent_damage(ship: ShipInstance,
		eff_id: String) -> Dictionary:
	if _damage_deck == null:
		return {}
	var card: DamageCard = _damage_deck.draw_card()
	if card == null:
		return {}
	return GameManager.submit_persistent_effect_damage(
			ship, eff_id, card.serialize())

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

# ---------------------------------------------------------------------------
# Maneuver Tool / Range Overlay / Targeting List
# ---------------------------------------------------------------------------
# All toolbar request handlers, keyboard shortcuts (M / R / T / A), the
# Escape → dismiss / cancel routing and the dismiss-other-tools coordination
# now live on [ToolOverlayController] (Phase K11).


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

## Creates the [AttackExecutor] child node.  Its
## attack_exec_completed / attack_exec_cancelled signals are connected
## by [ShipActivationController] (Phase K8b).
func _create_attack_executor() -> void:
	_attack_executor = AttackExecutor.new()
	_attack_executor.name = "AttackExecutor"
	add_child(_attack_executor)
	_attack_executor.initialize(_target_selector, _camera)

## Creates and initialises the [AttackPanelController] child node
## (Phase K9).  Owns the attack-panel mirror sync, the attacker-side
## defender-response routing into [AttackExecutor], and the Attack
## Simulator toolbar / keyboard toggle.
func _create_attack_panel_controller() -> void:
	_attack_panel_controller = AttackPanelController.new()
	_attack_panel_controller.name = "AttackPanelController"
	add_child(_attack_panel_controller)
	_attack_panel_controller.initialize(
			_attack_executor, _panel_mgr, _target_selector)

## Creates the [ToolOverlayController] child node which owns the
## maneuver / range / targeting sub-controllers (Phase K11).
func _create_tool_overlay_controller() -> void:
	_tool_overlay_controller = ToolOverlayController.new()
	_tool_overlay_controller.name = "ToolOverlayController"
	add_child(_tool_overlay_controller)
	_tool_overlay_controller.initialize(
			_token_container,
			_panel_mgr,
			_activation_ctx,
			get_ship_tokens,
			get_squadron_tokens,
			self )

## Creates the [CommandRouterAdapter] child node which wires [ModalRouter]
## and per-command-type effects to the appropriate controllers.
func _create_command_router_adapter() -> void:
	_command_router_adapter = CommandRouterAdapter.new()
	_command_router_adapter.name = "CommandRouterAdapter"
	add_child(_command_router_adapter)
	_command_router_adapter.initialize(
			_panel_mgr,
			_attack_panel_controller,
			_debug_controller,
			_ship_activation_controller,
			_displacement_controller,
			_activation_ctx,
			_find_ship_token_for_instance,
			_find_squadron_token_for_instance)

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
	# squadron_command_done is connected by ShipActivationController
	# (Phase K8b).

## Dismisses the maneuver tool, passing the current activation ship so the
## Navigate-token spend preview overlay is cleared when appropriate.
## Thin wrapper around [method ToolOverlayController.dismiss_maneuver_tool_with_preview]
## kept because [ShipActivationController] receives this Callable on init.
func _dismiss_maneuver_tool_with_preview() -> void:
	_tool_overlay_controller.dismiss_maneuver_tool_with_preview()

## Creates the [DebugController] child node with overlay, HUD, and saver.
func _create_debug_controller() -> void:
	_debug_controller = DebugController.new()
	_debug_controller.name = "DebugController"
	add_child(_debug_controller)
	_debug_controller.initialize(self , get_ship_tokens, get_squadron_tokens)

## Creates the [DisplacementController] child node.  The
## displacement_completed signal is connected by
## [ShipActivationController] (Phase K8b).
func _create_displacement_controller() -> void:
	_displacement_controller = DisplacementController.new()
	_displacement_controller.name = "DisplacementController"
	add_child(_displacement_controller)
	_displacement_controller.initialize(
			_camera, get_squadron_tokens, get_ship_tokens,
			_panel_mgr.show_activation_button,
			_panel_mgr.activation_modal)

## Creates the [DialDragController] child node and wires its signals.
func _create_dial_drag_controller() -> void:
	var tm_layer: CanvasLayer = _panel_mgr.turn_management_layer
	_dial_drag_controller = DialDragController.new()
	_dial_drag_controller.name = "DialDragController"
	add_child(_dial_drag_controller)
	_dial_drag_controller.initialize(
			_find_ship_token_at, _find_card_panel_hit, tm_layer)
	_dial_drag_controller.ship_activated.connect(
			_ship_activation_controller.on_dial_ship_activated)
	_dial_drag_controller.token_converted.connect(
			_ship_activation_controller.on_dial_token_converted)


## Creates the [ShipActivationController] child node.  Initialize is
## deferred until after token spawn (the controller needs [member
## _damage_deck], populated during scenario / loaded-state spawn).
func _create_ship_activation_controller() -> void:
	_ship_activation_controller = ShipActivationController.new()
	_ship_activation_controller.name = "ShipActivationController"
	add_child(_ship_activation_controller)


## Initializes the [ShipActivationController] once the damage deck and
## attack executor are ready.  Called from [method _ready] after spawn.
func _initialize_ship_activation_controller() -> void:
	if _ship_activation_controller == null:
		return
	_ship_activation_controller.initialize(
			_activation_ctx,
			_panel_mgr,
			_attack_executor,
			_squadron_phase_controller,
			_damage_deck,
			_dial_drag_controller,
			_tool_overlay_controller.get_maneuver_tool_controller(),
			_displacement_controller,
			_find_ship_token_for_instance,
			_has_repair_resources,
			_has_squadron_resources,
			_is_squadron_token_only,
			_submit_persistent_damage,
			_is_pending_remote_result,
			_is_local_squadron_modal_controller,
			get_ship_tokens,
			get_squadron_tokens,
			_dismiss_maneuver_tool_with_preview)
	_panel_mgr.set_pre_reveal_dial_handler(
			_ship_activation_controller.check_crew_panic_before_reveal)

## Creates the [CommandPhaseController] child node and wires its signal.
func _create_command_phase_controller() -> void:
	_command_phase_controller = CommandPhaseController.new()
	_command_phase_controller.name = "CommandPhaseController"
	add_child(_command_phase_controller)
	_command_phase_controller.initialize()

## Called by [signal TargetSelector.dismiss_other_tools_requested].
## Dismisses range overlay, targeting list, and maneuver tool via the
## [ToolOverlayController].  Phase K11: thin delegation wrapper kept for
## startup safety: [TargetSelector] can connect to this board-owned callable
## without dereferencing [member _tool_overlay_controller] during creation.
func _on_dismiss_other_tools_requested() -> void:
	if _tool_overlay_controller == null:
		_log.info("Dismiss-other-tools requested before ToolOverlayController was ready.")
		return
	_tool_overlay_controller.dismiss_other_tools()

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
	if not _has_command_resource(inst, Constants.CommandType.REPAIR):
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
	if not _has_command_resource(inst, Constants.CommandType.SQUADRON):
		return false
	return _has_friendly_squadron_token_for_owner(inst.owner_player)

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


func _create_board_components() -> void:
	_create_camera()
	_create_token_container()
	_create_setup_placement_controller()
	_create_debug_controller()
	_create_command_phase_controller()
	_create_squadron_phase_controller()
	# UI panels, resize infrastructure, and isolated UI callbacks.
	_panel_mgr = UIPanelManager.new()
	_panel_mgr.name = "UIPanelManager"
	add_child(_panel_mgr)
	_panel_mgr.initialize(self )
	_squadron_phase_controller.create_ui(
			_panel_mgr.turn_management_layer, _panel_mgr.register_resizable)
	_create_tool_overlay_controller()
	_create_target_selector()
	_create_attack_executor()
	_create_attack_panel_controller()
	_create_displacement_controller()
	_create_ship_activation_controller()
	_create_dial_drag_controller()


func _create_setup_placement_controller() -> void:
	_setup_placement_controller = SETUP_PLACEMENT_CONTROLLER_SCRIPT.new()
	_setup_placement_controller.name = "SetupPlacementController"
	_setup_placement_controller.setup_turn_prompt_requested.connect(
			_on_setup_turn_prompt_requested)
	add_child(_setup_placement_controller)
	_setup_placement_controller.initialize(self , _token_container, _token_mover)


func _bootstrap_or_load_board_state() -> void:
	# Phase J5.6: when a save was loaded just before entering the board,
	# skip bootstrap and spawn directly from the preloaded GameState.
	if GameManager.consume_preloaded_flag():
		_spawn_tokens_from_loaded_state()
		return
	var scenario_id: String = GameManager.consume_next_scenario_id(
			LearningScenarioSetup.DEFAULT_SCENARIO_ID)
	GameManager.bootstrap_game(scenario_id)
	if GameManager.consume_preloaded_flag():
		_spawn_tokens_from_loaded_state()
		return
	_spawn_learning_scenario_tokens(_scenario_id_for_spawn(scenario_id))


func _scenario_id_for_spawn(fallback_scenario_id: String) -> String:
	var active_scenario_id: String = GameManager.get_scenario_id().strip_edges()
	if active_scenario_id.is_empty():
		return fallback_scenario_id
	return active_scenario_id


func _finalize_ready_sequence() -> void:
	_initialize_ship_activation_controller()
	_create_command_router_adapter()
	_connect_signals()
	_connect_panel_signals()
	if _setup_placement_controller:
		_setup_placement_controller.refresh_from_state()
	queue_redraw()
	_on_phase_changed(GameManager.get_current_phase())
	_on_active_player_changed(GameManager.get_active_player())


func _show_fixed_round1_toast_if_needed() -> void:
	if GameManager.fixed_commands_applied:
		TooltipManager.show_text(
				"Round 1 commands pre-assigned", Vector2.INF, 3.0)


func _try_handle_displacement_lock_click(event: InputEvent) -> bool:
	if not _displacement_controller \
			or not _displacement_controller.is_displacement_active():
		return false
	if not event is InputEventMouseButton:
		return false
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	_displacement_controller.handle_lock_click()
	get_viewport().set_input_as_handled()
	return true


func _connect_board_core_signals() -> void:
	EventBus.firing_arc_toggled.connect(_on_firing_arc_toggled)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.round_started.connect(_on_round_started)
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.handoff_accepted.connect(_on_handoff_accepted)


func _connect_board_damage_and_remote_signals() -> void:
	EventBus.damage_card_dealt.connect(_on_damage_card_dealt)
	EventBus.ship_repositioned_remotely.connect(
			_on_ship_repositioned_remotely)
	EventBus.squadron_repositioned_remotely.connect(
			_on_squadron_repositioned_remotely)


func _connect_board_passive_peer_visual_signals() -> void:
	# Passive peer still needs destroy fade visuals when not executing attacks.
	EventBus.squadron_destroyed.connect(_on_squadron_destroyed_fade_token)


func _apply_fixed_round1_commands_if_configured(
		setup: LearningScenarioSetup) -> void:
	if not setup.has_fixed_round1_commands():
		return
	var fixed_cmds: Dictionary = setup.get_fixed_round1_commands()
	GameManager.apply_fixed_round1_commands(fixed_cmds)


func _prepare_learning_scenario_instances(
		setup: LearningScenarioSetup) -> Dictionary:
	_load_map_texture(setup.get_map_image_filename())
	_init_scenario_systems(setup)
	return LearningScenarioPreparer.prepare_game_state(
			setup, GameManager.current_game_state)


func _finalize_learning_scenario_spawn_ui() -> void:
	_log.info("Spawned %d tokens for the Learning Scenario." %
			_token_container.get_child_count())
	_panel_mgr.update_card_panel_positions()
	_refresh_activation_sidebar_ui()


func _refresh_activation_sidebar_ui() -> void:
	if not _panel_mgr.activation_sidebar or not GameManager.current_game_state:
		return
	_panel_mgr.activation_sidebar.populate(GameManager.current_game_state)
	_panel_mgr.activation_sidebar.connect_signals()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.activation_sidebar.update_position(vp_size)


func _spawn_loaded_tokens_for_player(ps: PlayerState) -> void:
	for ship: ShipInstance in ps.ships:
		var placement: TokenPlacement = _placement_from_ship(ship)
		var token: ShipToken = _spawn_ship_token(placement)
		token.bind_instance(ship)
		_panel_mgr.add_ship_to_card_panel(ship)
	for squad: SquadronInstance in ps.squadrons:
		var sq_placement: TokenPlacement = _placement_from_squadron(squad)
		var sq_token: SquadronToken = _spawn_squadron_token(sq_placement)
		sq_token.bind_instance(squad)


func _apply_turn_transition_intent(
		intent: UIProjector.UIIntent,
		phase: Constants.GamePhase) -> void:
	_apply_turn_perspective(
			intent.perspective_player, intent.perspective_player_faction)
	_panel_mgr.set_network_status_text(intent.hud_status_text)
	_ship_activation_controller.update_activation_modal_interactivity()
	_show_projected_turn_prompt(intent, phase)
	if intent.should_begin_command_dial_flow:
		_command_phase_controller.begin_command_dial_flow()
	if intent.should_begin_passive_squadron_observer:
		_squadron_phase_controller.begin_activation_flow()


func _apply_turn_perspective(player_index: int, player_faction: int) -> void:
	if player_index < 0:
		return
	_panel_mgr.rebel_card_panel.set_viewer_player(player_index)
	_panel_mgr.imperial_card_panel.set_viewer_player(player_index)
	_camera.rotate_to_player(player_index)
	_swap_card_panels(player_index, player_faction)


func _show_projected_turn_prompt(
		intent: UIProjector.UIIntent,
		phase: Constants.GamePhase) -> void:
	if intent.needs_handoff_overlay:
		_show_projected_handoff(
				intent.controller_player, phase, intent.controller_player_label)
		return
	if intent.needs_turn_banner:
		_show_projected_turn_banner(
				intent.controller_player, intent.controller_player_label)


func _show_projected_handoff(
		player_index: int,
		phase: Constants.GamePhase,
		player_label: String) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var phase_name: String = UIPanelManager.PHASE_NAMES.get(
			phase, "Command Phase")
	_panel_mgr.handoff_overlay.show_handoff(player_index, phase_name, player_label)
	_panel_mgr.handoff_overlay.update_size(vp_size)


func _show_projected_turn_banner(player_index: int, player_label: String) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.your_turn_banner.show_banner(
			player_index, YourTurnBanner.DEFAULT_DURATION, player_label)
	_panel_mgr.your_turn_banner.update_size(vp_size)


func _on_setup_turn_prompt_requested(player_index: int, player_label: String) -> void:
	if not _is_shared_screen():
		return
	var player_faction: int = UIProjector.player_faction(
			GameManager.current_game_state, player_index)
	_apply_turn_perspective(player_index, player_faction)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.handoff_overlay.show_handoff(player_index, "Setup", player_label)
	_panel_mgr.handoff_overlay.update_size(vp_size)


func _is_shared_screen() -> bool:
	return NetworkManager.get_local_player_index() < 0


func _has_command_resource(ship: ShipInstance,
		command_type: Constants.CommandType) -> bool:
	return _has_revealed_command(ship, command_type) \
			or (ship.command_tokens != null
			and ship.command_tokens.has_token(command_type))


func _has_revealed_command(ship: ShipInstance,
		command_type: Constants.CommandType) -> bool:
	if ship.command_dial_stack == null:
		return false
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if revealed.is_empty():
		return false
	return int(revealed.get("command", -1)) == int(command_type)


func _has_friendly_squadron_token_for_owner(owner_player: int) -> bool:
	for sq_token: SquadronToken in get_squadron_tokens():
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.owner_player == owner_player:
			return true
	return false

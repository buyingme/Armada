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

## Registry of widgets that need repositioning/resizing on viewport change.
## Each entry: { "node": Control, "method": StringName, "only_visible": bool }.
## Populated by [method _register_resizable].
var _resizable_widgets: Array[Dictionary] = []

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

## Background map texture loaded from the scenario JSON (may be null).
var _map_texture: Texture2D = null

## Core mover logic for collision resolution.
## SHARED — Created: inline. Read: maneuver execution, displacement
## validation, overlap resolution. Write: never after init.
## Extractable: pass via initialize() to ManeuverToolController.
var _token_mover: TokenMover = TokenMover.new()

## Ship card side panels: Rebel (left) and Imperial (right).
## Rules Reference: SU-026, UI-016, UI-017.
var _rebel_card_panel: ShipCardPanel = null
var _imperial_card_panel: ShipCardPanel = null

## Full-screen overlay for viewing card detail art (UI-002).
var _card_detail_overlay: CardDetailOverlay = null

## Full-screen overlay for showing damage cards dealt (DM-005).
var _damage_summary_overlay: DamageSummaryOverlay = null

## Confirmation modal for quitting the game and returning to the main menu.
## Shown when Escape is pressed with no other modal active. UI-034.
var _quit_modal: QuitConfirmationModal = null

## Activation sidebar showing ship/squadron activation status (UI-014).
## SHARED — Created: _create_activation_sidebar_layer(). Read: scenario
## setup (populate), ship activation (highlight). Write: resize registry.
## Extractable: pass via initialize() to activation controllers.
var _activation_sidebar: ActivationSidebar = null

## Controller owning the command-dial picker, order modal, and ship queue.
## Created in [method _create_command_phase_controller].
var _command_phase_controller: CommandPhaseController = null

## Phase / round HUD label shown at the top-centre of the screen.
## SHARED — Created: _create_phase_hud(). Read: phase changes, round
## starts, damage summary show/hide, score updates. Write: _create_phase_hud()
## only. Extractable: move to dedicated HUD controller.
var _phase_hud_label: Label = null

## Handoff overlay for hot-seat turn transitions (Command Phase).
## Requirements: HO-001, HO-002, HO-003.
## SHARED — Created: _create_core_turn_ui(). Read: turn management,
## attack executor (set_handoff_overlay), command phase. Write: resize
## registry. Extractable: pass via initialize() to turn controllers.
var _handoff_overlay: HandoffOverlay = null

## Brief "Your Turn" banner (Ship / Squadron Phases).
## Requirements: HO-004, HO-005.
var _your_turn_banner: YourTurnBanner = null

## Victory screen overlay shown when the game ends.
## Requirements: WN-001–004.
var _victory_screen: VictoryScreen = null

## Scoring calculator for live HUD score display.
## Requirements: GF-001–004.
## SHARED — Created: inline. Read: phase HUD (score display), game-end
## (victory screen). Write: never after init. Extractable: pass to HUD/end.
var _scoring: ScoringCalculator = ScoringCalculator.new()

## "End Activation" button (Ship / Squadron Phases).
## Requirements: TF-005, TF-011.
var _end_activation_button: EndActivationButton = null

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
## Write: dial drag start/end, activation end. Extractable: move to
## ActivationContext (Phase F) or pass as argument to controllers.
var _activating_ship_token: ShipToken = null

## --- Maneuver Tool state (Phase 5a) ---

## Maneuver tool controller — owns selection flag and ManeuverToolScene.
## Created in [method _create_maneuver_tool_controller].
var _maneuver_tool_controller: ManeuverToolController = null

## Whether the last committed maneuver resulted in a ship–ship overlap.
## Set by [method _resolve_maneuver_overlaps_ex], consumed by the
## AFTER_MANEUVER_EXECUTE hook.
var _last_maneuver_overlapped: bool = false

## --- Range Overlay state ---

## Range tool controller — owns selection flag and RangeOverlayScene.
## Created in [method _create_range_tool_controller].
var _range_tool_controller: RangeToolController = null

## Targeting list modal (null when not displayed).
var _targeting_list_modal: TargetingListModal = null

## ActionToolbar in the lower-right corner.
## SHARED — Created: _create_action_toolbar(). Read: dismiss-other-tools,
## escape handling, phase transitions (button visibility). Write: resize
## registry. Extractable: pass via initialize() to tool controllers.
var _action_toolbar: ActionToolbar = null

## Attack executor — owns all attack simulator / execution logic and UI.
## Created in [method _create_attack_executor].
## SHARED — Created: _create_attack_executor(). Read: ship activation
## (attack step), attack simulator request, escape handling.
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

## --- Phase 7b: Squadron Activation flow state ---

## Squadron phase controller — owns all squadron activation state and UI.
## Created in [method _create_squadron_phase_controller].
var _squadron_phase_controller: SquadronPhaseController = null

## Displacement controller — owns all displacement state and UI.
## Created in [method _create_displacement_controller].
var _displacement_controller: DisplacementController = null

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
	_create_debug_controller()
	_create_ship_card_panels()
	_create_command_phase_controller()
	_create_squadron_phase_controller()
	_create_turn_management_ui()
	_create_phase_hud()
	_create_action_toolbar()
	_create_attack_executor()
	_create_maneuver_tool_controller()
	_create_range_tool_controller()
	_create_displacement_controller()
	_create_dial_drag_controller()
	# Start game so GameState exists BEFORE tokens are spawned.
	GameManager.start_new_game()
	_spawn_learning_scenario_tokens()
	_connect_signals()
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
	# Attack simulator: Escape dismisses.
	if _attack_executor and _attack_executor.handle_escape(event):
		return
	# Targeting list: Escape dismisses.
	if _handle_targeting_list_escape(event):
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
	if _handle_quit_escape(event):
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

	# Connect right-click → card detail overlay (UI-002).
	_rebel_card_panel.card_detail_requested.connect(
			_on_card_detail_requested)
	_imperial_card_panel.card_detail_requested.connect(
			_on_card_detail_requested)

	# Connect damage card overview overlay (click damage column → show all).
	_rebel_card_panel.damage_overview_requested.connect(
			_on_damage_overview_requested)
	_imperial_card_panel.damage_overview_requested.connect(
			_on_damage_overview_requested)

	_create_card_detail_layer()
	_create_quit_modal_layer()
	_create_activation_sidebar_layer()


## Creates the card detail and damage summary overlays on a high layer.
func _create_card_detail_layer() -> void:
	var detail_layer: CanvasLayer = CanvasLayer.new()
	detail_layer.name = "CardDetailLayer"
	detail_layer.layer = 85
	add_child(detail_layer)
	_card_detail_overlay = CardDetailOverlay.new()
	_card_detail_overlay.name = "CardDetailOverlay"
	detail_layer.add_child(_card_detail_overlay)

	_damage_summary_overlay = DamageSummaryOverlay.new()
	_damage_summary_overlay.name = "DamageSummaryOverlay"
	detail_layer.add_child(_damage_summary_overlay)
	_damage_summary_overlay.dismissed.connect(_on_damage_summary_dismissed)
	_register_resizable(_damage_summary_overlay, &"update_size", true)


## Creates the quit confirmation modal on a top-level layer (UI-034).
func _create_quit_modal_layer() -> void:
	var quit_layer: CanvasLayer = CanvasLayer.new()
	quit_layer.name = "QuitConfirmationLayer"
	quit_layer.layer = 95
	add_child(quit_layer)
	_quit_modal = QuitConfirmationModal.new()
	_quit_modal.name = "QuitConfirmationModal"
	quit_layer.add_child(_quit_modal)
	_quit_modal.confirmed.connect(_on_quit_confirmed)


## Creates the activation sidebar on its own layer (UI-014).
func _create_activation_sidebar_layer() -> void:
	var sidebar_layer: CanvasLayer = CanvasLayer.new()
	sidebar_layer.name = "ActivationSidebarLayer"
	sidebar_layer.layer = 45
	add_child(sidebar_layer)
	_activation_sidebar = ActivationSidebar.new()
	_activation_sidebar.name = "ActivationSidebar"
	sidebar_layer.add_child(_activation_sidebar)
	_register_resizable(_activation_sidebar, &"update_position")


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
	if _card_detail_overlay:
		_card_detail_overlay.update_size(vp_size)


## Handles the card_detail_requested signal from a ShipCardPanel.
## Loads the full card texture and shows it in the overlay.
## Requirements: UI-002.
func _on_card_detail_requested(data_key: String,
		ship_name: String) -> void:
	if _card_detail_overlay == null:
		return
	var texture: Texture2D = AssetLoader.load_texture(
			"ships/", "%s_card.png" % data_key)
	if texture:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_card_detail_overlay.update_size(vp_size)
		_card_detail_overlay.show_card(texture, ship_name)
	else:
		_log.warn("No card texture for '%s'." % data_key)


## Handles the damage_overview_requested signal from a ShipCardPanel.
## Loads ALL damage card textures for the ship and shows them in the
## DamageSummaryOverlay with the "Damage Cards" title.
func _on_damage_overview_requested(
		ship_instance: RefCounted) -> void:
	if _damage_summary_overlay == null:
		return
	var inst: ShipInstance = ship_instance as ShipInstance
	if inst == null:
		return
	var faceup_textures: Array = []
	for card: RefCounted in inst.faceup_damage:
		var eid: String = card.effect_id if card else ""
		var tex: Texture2D = AssetLoader.load_texture(
				"damage_deck/", "damage_%s.png" % eid)
		if tex:
			faceup_textures.append({
				"texture": tex,
				"title": card.title if card else "",
			})
	var facedown_count: int = inst.facedown_damage.size()
	var back_tex: Texture2D = AssetLoader.load_texture(
			"damage_deck/", "damage_back.png")
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_damage_summary_overlay.update_size(vp_size)
	_damage_summary_overlay.show_summary(
			faceup_textures, facedown_count, back_tex,
			inst.ship_data.ship_name, "Damage Cards")
	_set_phase_hud_visible(false)


## Handles the damage_summary_requested signal from EventBus.
## Loads faceup card textures and the card-back, then shows the overlay.
## Requirements: DM-005, DM-006.
func _on_damage_summary_requested(_ship_instance: RefCounted,
		faceup_cards: Array, facedown_count: int,
		ship_name: String) -> void:
	if _damage_summary_overlay == null:
		return
	var faceup_textures: Array = []
	for card: RefCounted in faceup_cards:
		var eid: String = card.effect_id if card else ""
		var tex: Texture2D = AssetLoader.load_texture(
				"damage_deck/", "damage_%s.png" % eid)
		if tex:
			faceup_textures.append({
				"texture": tex,
				"title": card.title if card else "",
			})
	var back_tex: Texture2D = AssetLoader.load_texture(
			"damage_deck/", "damage_back.png")
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_damage_summary_overlay.update_size(vp_size)
	_damage_summary_overlay.show_summary(
			faceup_textures, facedown_count, back_tex, ship_name)
	_set_phase_hud_visible(false)


## Forwards the overlay's dismissed signal to EventBus so AttackExecutor
## can resolve deferred immediate effects.
func _on_damage_summary_dismissed() -> void:
	_set_phase_hud_visible(true)
	EventBus.damage_summary_dismissed.emit()


## Toggles the phase / round HUD label visibility.
## Hidden while the DamageSummaryOverlay is open to avoid text overlap.
func _set_phase_hud_visible(show: bool) -> void:
	if _phase_hud_label != null:
		_phase_hud_label.visible = show


## Connects EventBus and DebugMode signals relevant to the board.
func _connect_signals() -> void:
	#region Debug & viewport signals
	EventBus.firing_arc_toggled.connect(_on_firing_arc_toggled)
	# debug_mode_changed / save_positions_requested are connected inside
	# DebugController.initialize().
	get_tree().root.size_changed.connect(_on_viewport_resized)
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
	EventBus.targeting_list_requested.connect(_on_targeting_list_requested)
	EventBus.attack_simulator_requested.connect(_on_attack_simulator_requested)
	#endregion

	#region Game end & scoring signals
	EventBus.game_ended.connect(_on_game_ended)
	EventBus.ship_destroyed.connect(_on_score_changed)
	EventBus.squadron_destroyed.connect(_on_score_changed)
	#endregion

	#region Damage card signals
	EventBus.damage_card_dealt.connect(_on_damage_card_dealt)
	EventBus.damage_summary_requested.connect(_on_damage_summary_requested)
	#endregion


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
	if setup.has_fixed_round1_commands():
		var fixed_cmds: Dictionary = setup.get_fixed_round1_commands()
		GameManager.apply_fixed_round1_commands(fixed_cmds)
	_spawn_and_bind_tokens(setup, ship_instances, squad_instances)
	_log.info("Spawned %d tokens for the Learning Scenario." %
			_token_container.get_child_count())
	_update_card_panel_positions()
	if _activation_sidebar and GameManager.current_game_state:
		_activation_sidebar.populate(GameManager.current_game_state)
		_activation_sidebar.connect_signals()
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_activation_sidebar.update_position(vp_size)


## Initialises the damage deck, attack executor references, and effect
## registry from the given scenario setup.
func _init_scenario_systems(setup: LearningScenarioSetup) -> void:
	_damage_deck = setup.get_damage_deck()
	if GameManager.current_game_state:
		GameManager.current_game_state.damage_deck = _damage_deck
	if _attack_executor:
		_attack_executor.set_damage_deck(_damage_deck)
	if _attack_executor and _handoff_overlay:
		_attack_executor.set_handoff_overlay(_handoff_overlay)
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
			_add_ship_to_card_panel(ship_instances[i])
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
	if _attack_executor and _attack_executor.handle_ship_click(token):
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
	if _attack_executor and _attack_executor.handle_squadron_click(token):
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


## Repositions ship card panels and turn-management UI when the window is
## resized. Iterates the registered widget list populated by
## [method _register_resizable].
func _on_viewport_resized() -> void:
	_update_card_panel_positions()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for entry: Dictionary in _resizable_widgets:
		var node: Control = entry["node"] as Control
		if node == null:
			continue
		if entry["only_visible"] and not node.visible:
			continue
		var method: StringName = entry["method"] as StringName
		node.call(method, vp_size)


## Registers a widget for automatic viewport-resize handling.
## [param node] — the Control to call on resize.
## [param method] — the method name to invoke with the viewport size.
## [param only_visible] — when true, skip the call if the widget is hidden.
func _register_resizable(node: Control, method: StringName,
		only_visible: bool = false) -> void:
	_resizable_widgets.append({
		"node": node,
		"method": method,
		"only_visible": only_visible,
	})


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

## Creates the turn-management UI: handoff overlay, "Your Turn" banner,
## and "End Activation" button on a high-layer CanvasLayer.
## Requirements: HO-001–005, TF-005, TF-011.
func _create_turn_management_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TurnManagementLayer"
	layer.layer = 80
	add_child(layer)

	_create_core_turn_ui(layer)
	_create_activation_modal_ui(layer)
	_create_repair_squadron_ui(layer)


## Creates the handoff overlay, "Your Turn" banner, end-activation button,
## and show-activation button on the given layer.
func _create_core_turn_ui(layer: CanvasLayer) -> void:
	_handoff_overlay = HandoffOverlay.new()
	_handoff_overlay.name = "HandoffOverlay"
	layer.add_child(_handoff_overlay)
	_register_resizable(_handoff_overlay, &"update_size")

	_your_turn_banner = YourTurnBanner.new()
	_your_turn_banner.name = "YourTurnBanner"
	layer.add_child(_your_turn_banner)
	_register_resizable(_your_turn_banner, &"update_size")

	_end_activation_button = EndActivationButton.new()
	_end_activation_button.name = "EndActivationButton"
	layer.add_child(_end_activation_button)
	_register_resizable(_end_activation_button, &"update_position")

	_show_activation_button = ShowActivationButton.new()
	_show_activation_button.name = "ShowActivationButton"
	_show_activation_button.activation_sequence_requested.connect(
			_on_activation_sequence_requested)
	layer.add_child(_show_activation_button)
	_register_resizable(_show_activation_button, &"update_position")


## Creates the activation modal and connects its signals.
func _create_activation_modal_ui(layer: CanvasLayer) -> void:
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
	_register_resizable(_activation_modal, &"centre_on_screen", true)


## Creates the repair panel, squadron modal, and show-squadron button.
func _create_repair_squadron_ui(layer: CanvasLayer) -> void:
	_repair_panel = RepairPanel.new()
	_repair_panel.name = "RepairPanel"
	_repair_panel.repair_done.connect(_on_repair_done)
	_repair_panel.repair_skipped.connect(_on_repair_done)
	layer.add_child(_repair_panel)
	_register_resizable(_repair_panel, &"centre_on_screen", true)

	_squadron_phase_controller.create_ui(layer, _register_resizable)


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
	# Centre the label by spanning the full viewport width.
	# horizontal_alignment = CENTER handles the text centering.
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	_phase_hud_label.position = Vector2(0, 8)
	_phase_hud_label.size = Vector2(vp_size.x, _phase_hud_label.size.y)


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
			_squadron_phase_controller.hide_ui()
		Constants.GamePhase.SHIP:
			# Button hidden until a ship is activated via dial drag (Phase 4c).
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()
		Constants.GamePhase.SQUADRON:
			# Phase 7b: Squadron modal opens after handoff.
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
			_show_activation_button.hide_button()
		_:
			_end_activation_button.hide_button()
			_hide_phase5b_ui()
			_squadron_phase_controller.hide_ui()


## Called when a new round begins.
func _on_round_started(_round_number: int) -> void:
	_update_phase_hud()
	# Safety net: ensure squadron-phase UI never leaks into a new round.
	_squadron_phase_controller.hide_ui()
	# Restore squadron token opacity after Status Phase dimming.
	for sq_token: SquadronToken in get_squadron_tokens():
		sq_token.set_activated_visual(false)


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
	_activating_ship_token = token
	_ship_activation_state = ShipActivationState.create(ship)
	if _activation_sidebar and ship:
		_activation_sidebar.highlight_active(ship)
	_show_activation_sequence_button()
	_log.info("Ship activated via dial drop: '%s'." % ship.data_key)


## Called by [signal DialDragController.token_converted] when the player drops
## the dial on the owning ship's card-panel entry.  Converts the dial to a
## command token.
## Rules Reference: "Command Dials", p.3 — "spend the command dial to gain
## a command token of the same type."
## Requirements: UI-028, SP-011, CM-004–006.
func _on_dial_token_converted(ship: ShipInstance) -> void:
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	_ship_activation_state = ShipActivationState.create(ship)
	_activating_ship_token = _find_ship_token_for_instance(ship)
	if _activation_sidebar:
		_activation_sidebar.highlight_active(ship)

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
		var spent: Dictionary = ship.command_dial_stack.spend_revealed()
		if spent.is_empty():
			ship.command_dial_stack.discard_top()
		EventBus.command_dials_changed.emit(ship)
	GameManager.force_activate_ship(ship)
	_activating_ship_token = _find_ship_token_for_instance(ship)
	_ship_activation_state = ShipActivationState.create(ship)
	if _activation_sidebar and ship:
		_activation_sidebar.highlight_active(ship)
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
			var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
			EventBus.ship_hull_changed.emit(ship, new_hull)
			_log.info("Crew Panic damage dealt (hull now %d)." % new_hull)
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
	_squadron_phase_controller.hide_ui()
	_ship_activation_state = null
	if _activation_sidebar:
		_activation_sidebar.clear_active()
		_activation_sidebar.refresh()
	_dismiss_maneuver_tool_with_preview()
	_range_tool_controller.dismiss()
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
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_modal_visible() \
			and _squadron_phase_controller.is_command_mode():
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
				+"Consuming dial/token and auto-advancing.")
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
	if not _has_eligible_squadron_in_range(ship, resolver):
		_log.info("No friendly squadrons in range — consuming resources "
				+"and auto-advancing.")
		resolver.finalize()
		_on_squadron_command_done()
		return
	if _show_activation_button:
		_show_activation_button.hide_button()
	_squadron_phase_controller.open_for_command(resolver, _activating_ship_token)


## Returns true if at least one friendly non-activated squadron is within
## range of the ship's squadron command resolver.
func _has_eligible_squadron_in_range(ship: ShipInstance,
		resolver: SquadronCommandResolver) -> bool:
	var tokens: Array[SquadronToken] = get_squadron_tokens()
	for sq_token: SquadronToken in tokens:
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.owner_player == ship.owner_player \
				and resolver.is_squadron_in_range(sq_token.global_position):
			return true
	return false


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


## Called when the squadron command flow is complete (all activations used
## or the player finishes early).
## Finalizes the resolver (spends dial/token), advances the activation
## step, and re-opens the activation modal.
## Rules Reference: CM-020.
func _on_squadron_command_done() -> void:
	_log.info("Squadron command done — advancing activation step.")
	_squadron_phase_controller.dismiss_cmd_range_overlay()
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
	_maneuver_tool_controller.show_activation_tool(
			_activating_ship_token, _ship_activation_state)
	# Disable the simulation maneuver button while activation tool is active.
	if _action_toolbar:
		_action_toolbar.set_tool_buttons_disabled(true)
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
	if _maneuver_tool_controller.get_scene() == null:
		return
	var final_xform: Transform2D = _resolve_maneuver_overlaps_ex()
	_activating_ship_token.global_position = final_xform.origin
	_activating_ship_token.global_rotation = final_xform.get_rotation()
	# Ship–squadron overlap resolution (OV-001–004).
	var ship_size: Constants.ShipSize = _activating_ship_token.get_ship_size()
	var moved_ship_base: ShipBase = ShipBase.new(ship_size, final_xform)
	var displaced: Array[SquadronToken] = _find_displaced_squadrons(
			moved_ship_base)
	_ship_activation_state.mark_maneuver_executed()
	# AFTER_MANEUVER_EXECUTE hook — Ruptured Engine and Damaged Controls.
	# Rules Reference: "Ruptured Engine" / "Damaged Controls" card texts.
	_resolve_after_maneuver_hook(_last_maneuver_overlapped)
	EventBus.ship_moved.emit(_activating_ship_token)
	_dismiss_maneuver_tool_with_preview()
	if displaced.size() > 0:
		_displacement_controller.start(displaced, moved_ship_base)
	else:
		_show_end_activation_after_maneuver()
	_log.info("Ship snapped to final position.")


## Computes the final transform after ship–ship overlap resolution.
## Applies overlap damage if a collision occurred.
## Sets [member _last_maneuver_overlapped] for the AFTER_MANEUVER_EXECUTE hook.
## Requirements: OV-010–013.
func _resolve_maneuver_overlaps_ex() -> Transform2D:
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	var tool_state: ManeuverToolState = mt_scene.get_state()
	var attach: Dictionary = mt_scene._compute_attachment()
	var start_pos: Vector2 = attach["position"]
	var start_rot: float = attach["rotation"]
	var ghost_side: String = tool_state.compute_ghost_side()
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
	_last_maneuver_overlapped = result.overlaps or result.stayed_in_place
	if _last_maneuver_overlapped:
		_apply_overlap_damage(result)
	else:
		if _activation_modal:
			_activation_modal.set_collision_message("")
	return result.final_transform


## Resolves the AFTER_MANEUVER_EXECUTE hook for persistent damage cards.
## Ruptured Engine: suffer 1 facedown if speed > 1.
## Damaged Controls: suffer 1 facedown if overlapping an obstacle.
## Rules Reference: "Ruptured Engine", "Damaged Controls" card texts.
func _resolve_after_maneuver_hook(did_overlap: bool) -> void:
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry == null:
		return
	var ship: ShipInstance = _activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", ship.current_speed)
	ctx.set_meta_value("did_overlap", did_overlap)
	ctx.set_meta_value("damage_deck", _damage_deck)
	ctx = registry.resolve_hook(&"AFTER_MANEUVER_EXECUTE", ctx)
	if ctx.get_meta_value("extra_damage_dealt", false) as bool:
		var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
		EventBus.ship_hull_changed.emit(ship, new_hull)
		_log.info("After-maneuver damage dealt (hull now %d)." % new_hull)


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
	EventBus.damage_card_dealt.emit(inst, card, false)
	var new_hull: int = inst.ship_data.hull - inst.get_total_damage()
	EventBus.ship_hull_changed.emit(inst, new_hull)
	EventBus.ship_damaged.emit(token, 1, Constants.HullZone.FRONT)
	_log.info("Overlap facedown damage dealt to %s. Hull: %d/%d."
			% [inst.ship_data.ship_name, new_hull, inst.ship_data.hull])
	if inst.is_destroyed():
		inst.mark_destroyed()
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
	_register_resizable(_action_toolbar, &"update_position")


## Handles the "Display Maneuver Tool" button press.
## Requirements: MT-U-002, MT-U-003.
func _on_maneuver_tool_requested() -> void:
	# Block simulation requests while the activation-mode maneuver tool
	# is active — the player must use the modal's Commit button instead.
	if _ship_activation_state != null \
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
	if _action_toolbar == null:
		return false
	if _action_toolbar._maneuver_tool_btn and _action_toolbar._maneuver_tool_btn.disabled:
		return false
	return true


## Shows the quit confirmation modal when Escape is pressed and no other
## handler consumed the event. Returns true if handled.
## Requirements: UI-034.
func _handle_quit_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _quit_modal == null or _quit_modal.visible:
		return false
	_quit_modal.show_modal()
	get_viewport().set_input_as_handled()
	return true


## Handles the player confirming they want to quit. Transitions to the
## main menu scene. UI-034.
func _on_quit_confirmed() -> void:
	get_tree().change_scene_to_file(
			"res://src/scenes/main_menu/main_menu.tscn")


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
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if mt_scene == null:
		return null
	if not mt_scene.has_method("get_ghost_transform"):
		return null
	var ghost_data: Dictionary = mt_scene.get_ghost_transform()
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
	_attack_executor.initialize(
			get_ship_tokens, get_squadron_tokens,
			_token_container, _camera)
	_attack_executor.attack_exec_completed.connect(
			_on_attack_exec_completed)
	_attack_executor.attack_exec_cancelled.connect(
			_on_attack_exec_cancelled)
	_attack_executor.dismiss_other_tools_requested.connect(
			_on_dismiss_other_tools_requested)


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


## Creates the [SquadronPhaseController] child node and wires its signals.
func _create_squadron_phase_controller() -> void:
	_squadron_phase_controller = SquadronPhaseController.new()
	_squadron_phase_controller.name = "SquadronPhaseController"
	add_child(_squadron_phase_controller)
	var start_sq_attack: Callable = func(token: SquadronToken) -> void:
		if _attack_executor:
			_attack_executor.start_squadron_attack(token)
	var show_act_btn: Callable = func() -> void:
		if _show_activation_button and _activating_ship_token:
			_show_activation_button.show_button()
	_squadron_phase_controller.initialize(
			_token_container,
			get_squadron_tokens,
			start_sq_attack,
			show_act_btn,
			_move_squadron_token,
	)
	_squadron_phase_controller.squadron_command_done.connect(
			_on_squadron_command_done)


## Dismisses the maneuver tool, passing the current activation ship so the
## Navigate-token spend preview overlay is cleared when appropriate.
func _dismiss_maneuver_tool_with_preview() -> void:
	var ship: ShipInstance = null
	if _ship_activation_state:
		ship = _ship_activation_state.get_ship()
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
			_show_activation_button, _activation_modal)
	_displacement_controller.displacement_completed.connect(
			_show_end_activation_after_maneuver)


## Creates the [DialDragController] child node and wires its signals.
func _create_dial_drag_controller() -> void:
	var tm_layer: CanvasLayer = get_node_or_null("TurnManagementLayer")
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
	_command_phase_controller.phase_complete.connect(_update_phase_hud)


## Delegates the Attack Simulator toolbar / keyboard toggle to the executor.
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
func _on_attack_simulator_requested() -> void:
	if _attack_executor:
		_attack_executor.on_simulator_requested()


## Called by [signal AttackExecutor.dismiss_other_tools_requested].
## Dismisses range overlay, targeting list, and maneuver tool.
func _on_dismiss_other_tools_requested() -> void:
	_range_tool_controller.dismiss()
	_dismiss_targeting_list()
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
	ship.add_faceup_damage(card)
	_log.info("Debug: dealt faceup '%s' [%s] to %s." % [
			title, effect_id, ship.ship_data.ship_name])
	# Register persistent effect if applicable.
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry and DamageCardEffectFactory.is_persistent(card):
		DamageCardEffectFactory.register_effect(card, ship, registry)
		_log.info("Debug: persistent effect registered for '%s'." % title)
	# Emit standard signals so UI updates (card panel, hull display).
	EventBus.damage_card_flipped.emit(ship, card, true)
	EventBus.damage_card_dealt.emit(ship, card, true)
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	EventBus.ship_hull_changed.emit(ship, new_hull)
	# Resolve immediate effect if applicable.
	if ImmediateEffectResolver.is_immediate(card):
		_resolve_debug_immediate_effect(card, ship)
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
		var ok: bool = resolver.resolve(card, ship, _damage_deck)
		if ok:
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
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var ok: bool = resolver.resolve(
			_debug_immediate_card, _debug_immediate_ship,
			_damage_deck, selection)
	if ok:
		_log.info("Debug: immediate effect resolved for '%s'." %
				_debug_immediate_card.title)
	_debug_immediate_card = null
	_debug_immediate_ship = null

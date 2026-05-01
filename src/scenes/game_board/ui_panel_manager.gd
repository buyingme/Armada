## Manages all UI panel creation, positioning, resizing, and isolated
## UI callbacks for the game board.
##
## Extracted from game_board.gd as part of refactoring Phase F3.
## Panel properties are public (read) so game_board can connect game-logic
## signals and call methods on cross-cluster panels.
##
## Owns: panel creation, resize infrastructure, card-detail overlay,
## damage-summary overlay, quit modal, victory screen, phase HUD.
class_name UIPanelManager
extends Node


# ---------------------------------------------------------------------------
# Public panel references — game_board accesses these directly
# ---------------------------------------------------------------------------

## Ship card side panels: Rebel (left) and Imperial (right).
## Rules Reference: SU-026, UI-016, UI-017.
var rebel_card_panel: ShipCardPanel = null
var imperial_card_panel: ShipCardPanel = null

## Full-screen overlay for viewing card detail art (UI-002).
var card_detail_overlay: CardDetailOverlay = null

## Full-screen overlay for showing damage cards dealt (DM-005).
var damage_summary_overlay: DamageSummaryOverlay = null

## Confirmation modal for quitting the game (UI-034).
var quit_modal: QuitConfirmationModal = null

## Activation sidebar showing ship/squadron activation status (UI-014).
var activation_sidebar: ActivationSidebar = null

## Phase / round HUD label at the top-centre of the screen.
var phase_hud_label: Label = null

## Handoff overlay for hot-seat turn transitions (HO-001–003).
var handoff_overlay: HandoffOverlay = null

## Brief "Your Turn" banner (HO-004, HO-005).
var your_turn_banner: YourTurnBanner = null

## Victory screen overlay shown when the game ends (WN-001–004).
var victory_screen: VictoryScreen = null

## "End Activation" button (TF-005, TF-011).
var end_activation_button: EndActivationButton = null

## "Show Activation Sequence" button (ACT-007, FLOW-002).
var show_activation_button: ShowActivationButton = null

## Activation modal panel (ACT-001–004).
var activation_modal: ActivationModal = null

## Repair panel modal (CM-030–CM-037).
var repair_panel: RepairPanel = null

## Read-only mirror of the attacker's [AttackSimPanel] shown on the
## non-attacker peer for the duration of the attack flow.  Phase I6b-3
## R1b.  Owns its own [AttackSimPanel] instance; signals are NOT
## connected — the mirror is informational at R1b.
var attack_panel_mirror: AttackPanelMirror = null

## ActionToolbar in the lower-right corner (MT-U-001, AC-13).
var action_toolbar: ActionToolbar = null

## Targeting list modal — lazily created (may be null).
var targeting_list_modal: TargetingListModal = null

## CanvasLayer for turn management UI (exposed for DialDragController).
var turn_management_layer: CanvasLayer = null


# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Reference to the game board Node2D (CanvasLayers added as children).
var _board: Node2D = null

## Scoring calculator for live HUD score display (GF-001–004).
var _scoring: ScoringCalculator = ScoringCalculator.new()

## Registry of widgets that need repositioning on viewport change.
## Each entry: { "node": Control, "method": StringName, "only_visible": bool }.
var _resizable_widgets: Array[Dictionary] = []

## Current network-mode status text displayed below the score header context.
## Empty string means no extra status suffix is shown.
var _network_status_text: String = ""

## Logger instance.
var _log: GameLogger = GameLogger.new("UIPanelManager")

## Human-readable names for each game phase.
const PHASE_NAMES: Dictionary = {
	Constants.GamePhase.SETUP: "Setup",
	Constants.GamePhase.COMMAND: "Command Phase",
	Constants.GamePhase.SHIP: "Ship Phase",
	Constants.GamePhase.SQUADRON: "Squadron Phase",
	Constants.GamePhase.STATUS: "Status Phase",
}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Creates all UI panels and connects isolated UI signals.
## [param board] — the game board Node2D (parent for CanvasLayers).
func initialize(board: Node2D) -> void:
	_board = board
	_create_ship_card_panels()
	_create_turn_management_ui()
	_create_phase_hud()
	_create_action_toolbar()
	_connect_ui_signals()


## Registers a widget for automatic viewport-resize handling.
## [param node] — the Control to call on resize.
## [param method] — the method name to invoke with the viewport size.
## [param only_visible] — when true, skip the call if the widget is hidden.
func register_resizable(node: Control, method: StringName,
		only_visible: bool = false) -> void:
	_resizable_widgets.append({
		"node": node,
		"method": method,
		"only_visible": only_visible,
	})


## Repositions ship card panels and all registered widgets when the
## window is resized.
func on_viewport_resized() -> void:
	_update_card_panel_positions()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for entry: Dictionary in _resizable_widgets:
		var node: Control = entry["node"] as Control
		if node == null:
			continue
		if entry["only_visible"] and not node.visible:
			continue
		var method_name: StringName = entry["method"] as StringName
		node.call(method_name, vp_size)


## Updates the phase HUD label text and position.
## Displays round, phase, and live scores for both players.
## Format: "Round 3 — Ship Phase  |  Rebel: 42  |  Imperial: 0"
## Requirements: GF-001–004, UI-003.
func update_phase_hud() -> void:
	if phase_hud_label == null:
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
	if not _network_status_text.is_empty():
		base_text += "  |  %s" % _network_status_text
	phase_hud_label.text = base_text
	# Centre the label by spanning the full viewport width.
	var vp_size: Vector2 = Vector2(1280, 720)
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	phase_hud_label.position = Vector2(0, 8)
	phase_hud_label.size = Vector2(vp_size.x, phase_hud_label.size.y)


## Toggles the phase / round HUD label visibility.
## Hidden while the DamageSummaryOverlay is open to avoid text overlap.
func set_phase_hud_visible(show: bool) -> void:
	if phase_hud_label != null:
		phase_hud_label.visible = show


## Sets the network-mode score-header helper text.
## Rendering is driven by this value directly so the suffix remains visible
## even if PlayMode has not been switched yet on a scene-transition edge.
## [param text] New helper text; empty clears the suffix.
func set_network_status_text(text: String) -> void:
	_network_status_text = text.strip_edges()
	update_phase_hud()


## Adds a ship instance to the correct faction's card panel.
## Rules Reference: SU-026 — defense tokens placed next to ship card.
func add_ship_to_card_panel(instance: ShipInstance) -> void:
	if instance.ship_data == null:
		return
	match instance.ship_data.faction:
		Constants.Faction.REBEL_ALLIANCE:
			rebel_card_panel.add_ship_entry(instance)
		Constants.Faction.GALACTIC_EMPIRE:
			imperial_card_panel.add_ship_entry(instance)


## Creates and displays the VictoryScreen overlay.
## Requirements: WN-001–004.
func show_game_end(details: Dictionary) -> void:
	if victory_screen != null:
		return # Already shown.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "VictoryScreenLayer"
	layer.layer = 110
	add_child(layer)
	victory_screen = VictoryScreen.new()
	layer.add_child(victory_screen)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	victory_screen.update_size(vp_size)
	victory_screen.show_results(details)


## Shows the quit confirmation modal when Escape is pressed and no other
## handler consumed the event. Returns true if handled.
## Requirements: UI-034.
func handle_quit_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if quit_modal == null or quit_modal.visible:
		return false
	quit_modal.show_modal()
	get_viewport().set_input_as_handled()
	return true


## Updates card panel positions after token spawning or panel swap.
func update_card_panel_positions() -> void:
	_update_card_panel_positions()


# ---------------------------------------------------------------------------
# Private — Panel creation
# ---------------------------------------------------------------------------

## Creates ship card side panels on a CanvasLayer.
## Rebel cards on the left, Imperial cards on the right.
## Also creates card-detail overlay, quit modal, and activation sidebar.
## Rules Reference: SU-026, UI-016, UI-017.
func _create_ship_card_panels() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ShipCardPanelLayer"
	layer.layer = 50
	add_child(layer)

	rebel_card_panel = ShipCardPanel.new()
	rebel_card_panel.name = "RebelCardPanel"
	rebel_card_panel.setup(
			Constants.Faction.REBEL_ALLIANCE, true, 0)
	layer.add_child(rebel_card_panel)

	imperial_card_panel = ShipCardPanel.new()
	imperial_card_panel.name = "ImperialCardPanel"
	imperial_card_panel.setup(
			Constants.Faction.GALACTIC_EMPIRE, false, 1)
	layer.add_child(imperial_card_panel)

	# Connect right-click → card detail overlay (UI-002).
	rebel_card_panel.card_detail_requested.connect(
			_on_card_detail_requested)
	imperial_card_panel.card_detail_requested.connect(
			_on_card_detail_requested)

	# Connect damage card overview overlay (click damage column → show all).
	rebel_card_panel.damage_overview_requested.connect(
			_on_damage_overview_requested)
	imperial_card_panel.damage_overview_requested.connect(
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
	card_detail_overlay = CardDetailOverlay.new()
	card_detail_overlay.name = "CardDetailOverlay"
	detail_layer.add_child(card_detail_overlay)

	damage_summary_overlay = DamageSummaryOverlay.new()
	damage_summary_overlay.name = "DamageSummaryOverlay"
	detail_layer.add_child(damage_summary_overlay)
	damage_summary_overlay.dismissed.connect(_on_damage_summary_dismissed)
	register_resizable(damage_summary_overlay, &"update_size", true)


## Creates the quit confirmation modal on a top-level layer (UI-034).
func _create_quit_modal_layer() -> void:
	var quit_layer: CanvasLayer = CanvasLayer.new()
	quit_layer.name = "QuitConfirmationLayer"
	quit_layer.layer = 95
	add_child(quit_layer)
	quit_modal = QuitConfirmationModal.new()
	quit_modal.name = "QuitConfirmationModal"
	quit_layer.add_child(quit_modal)
	quit_modal.confirmed.connect(_on_quit_confirmed)


## Creates the activation sidebar on its own layer (UI-014).
func _create_activation_sidebar_layer() -> void:
	var sidebar_layer: CanvasLayer = CanvasLayer.new()
	sidebar_layer.name = "ActivationSidebarLayer"
	sidebar_layer.layer = 45
	add_child(sidebar_layer)
	activation_sidebar = ActivationSidebar.new()
	activation_sidebar.name = "ActivationSidebar"
	sidebar_layer.add_child(activation_sidebar)
	register_resizable(activation_sidebar, &"update_position")


## Creates the turn management UI layer and all its child elements.
func _create_turn_management_ui() -> void:
	turn_management_layer = CanvasLayer.new()
	turn_management_layer.name = "TurnManagementLayer"
	turn_management_layer.layer = 80
	add_child(turn_management_layer)

	_create_core_turn_ui(turn_management_layer)
	_create_activation_modal_ui(turn_management_layer)
	_create_repair_panel(turn_management_layer)
	_create_attack_panel_mirror(turn_management_layer)


## Creates the handoff overlay, "Your Turn" banner, end-activation button,
## and show-activation button on the given layer.
func _create_core_turn_ui(layer: CanvasLayer) -> void:
	handoff_overlay = HandoffOverlay.new()
	handoff_overlay.name = "HandoffOverlay"
	layer.add_child(handoff_overlay)
	register_resizable(handoff_overlay, &"update_size")

	your_turn_banner = YourTurnBanner.new()
	your_turn_banner.name = "YourTurnBanner"
	layer.add_child(your_turn_banner)
	register_resizable(your_turn_banner, &"update_size")

	end_activation_button = EndActivationButton.new()
	end_activation_button.name = "EndActivationButton"
	layer.add_child(end_activation_button)
	register_resizable(end_activation_button, &"update_position")

	show_activation_button = ShowActivationButton.new()
	show_activation_button.name = "ShowActivationButton"
	layer.add_child(show_activation_button)
	register_resizable(show_activation_button, &"update_position")


## Creates the activation modal on the given layer.
## Game-logic signals are NOT connected here — game_board connects them.
func _create_activation_modal_ui(layer: CanvasLayer) -> void:
	activation_modal = ActivationModal.new()
	activation_modal.name = "ActivationModal"
	layer.add_child(activation_modal)
	register_resizable(activation_modal, &"centre_on_screen", true)


## Creates the repair panel on the given layer.
## Game-logic signals are NOT connected here — game_board connects them.
func _create_repair_panel(layer: CanvasLayer) -> void:
	repair_panel = RepairPanel.new()
	repair_panel.name = "RepairPanel"
	layer.add_child(repair_panel)
	register_resizable(repair_panel, &"centre_on_screen", true)


## Creates the non-attacker peer's read-only attack-panel mirror.
## Phase I6b-3 R1b: owns an [AttackSimPanel] instance whose input
## signals are NEVER connected; population is driven by
## [member InteractionFlow.payload] on the
## [signal CommandProcessor.command_executed] projection.
##
## Phase I6b-3 R3 follow-up: hosted on its own [CanvasLayer] at layer
## [code]90[/code] (matching [TargetSelector]'s real attack panel) so
## the mirror's dice strip + damage readout render [b]on top of[/b] the
## [DamageSummaryOverlay] (layer 85) for the 1.2 s damage-info window.
## This mirrors the hot-seat behaviour where the attacker sees the
## final modified attack result over the close-up.
func _create_attack_panel_mirror(_layer: CanvasLayer) -> void:
	var mirror_layer: CanvasLayer = CanvasLayer.new()
	mirror_layer.name = "AttackPanelMirrorLayer"
	mirror_layer.layer = 90
	add_child(mirror_layer)
	attack_panel_mirror = AttackPanelMirror.new()
	attack_panel_mirror.setup(mirror_layer)


## Creates a phase / round HUD label at the top-centre of the screen.
func _create_phase_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "PhaseHUDLayer"
	layer.layer = 90
	add_child(layer)

	phase_hud_label = Label.new()
	phase_hud_label.name = "PhaseHUDLabel"
	phase_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_hud_label.add_theme_font_size_override("font_size", 20)
	phase_hud_label.add_theme_color_override(
			"font_color", Color(0.9, 0.85, 0.6))
	phase_hud_label.text = ""
	layer.add_child(phase_hud_label)
	update_phase_hud()


## Creates the ActionToolbar on a CanvasLayer in the lower-right corner.
## Requirements: MT-U-001, AC-13.
func _create_action_toolbar() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ActionToolbarLayer"
	layer.layer = 95
	add_child(layer)
	action_toolbar = ActionToolbar.new()
	action_toolbar.name = "ActionToolbar"
	layer.add_child(action_toolbar)
	action_toolbar.setup_buttons()
	register_resizable(action_toolbar, &"update_position")


# ---------------------------------------------------------------------------
# Private — Signal connections
# ---------------------------------------------------------------------------

## Connects EventBus and viewport signals for UI-only callbacks.
func _connect_ui_signals() -> void:
	get_tree().root.size_changed.connect(on_viewport_resized)
	EventBus.game_ended.connect(show_game_end)
	EventBus.ship_destroyed.connect(_on_score_changed)
	EventBus.squadron_destroyed.connect(_on_score_changed)
	EventBus.damage_summary_requested.connect(
			_on_damage_summary_requested)


# ---------------------------------------------------------------------------
# Private — Isolated UI callbacks
# ---------------------------------------------------------------------------

## Handles the card_detail_requested signal from a ShipCardPanel.
## Loads the full card texture and shows it in the overlay.
## Requirements: UI-002.
func _on_card_detail_requested(data_key: String,
		ship_name: String) -> void:
	if card_detail_overlay == null:
		return
	var texture: Texture2D = AssetLoader.load_texture(
			"ships/", "%s_card.png" % data_key)
	if texture:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		card_detail_overlay.update_size(vp_size)
		card_detail_overlay.show_card(texture, ship_name)
	else:
		_log.warn("No card texture for '%s'." % data_key)


## Handles the damage_overview_requested signal from a ShipCardPanel.
## Loads ALL damage card textures for the ship and shows them in the
## DamageSummaryOverlay with the "Damage Cards" title.
func _on_damage_overview_requested(
		ship_instance: RefCounted) -> void:
	if damage_summary_overlay == null:
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
	damage_summary_overlay.update_size(vp_size)
	damage_summary_overlay.show_summary(
			faceup_textures, facedown_count, back_tex,
			inst.ship_data.ship_name, "Damage Cards")
	set_phase_hud_visible(false)


## Handles the damage_summary_requested signal from EventBus.
## Loads faceup card textures and the card-back, then shows the overlay.
## Requirements: DM-005, DM-006.
func _on_damage_summary_requested(_ship_instance: RefCounted,
		faceup_cards: Array, facedown_count: int,
		ship_name: String) -> void:
	if damage_summary_overlay == null:
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
	damage_summary_overlay.update_size(vp_size)
	damage_summary_overlay.show_summary(
			faceup_textures, facedown_count, back_tex, ship_name)
	set_phase_hud_visible(false)


## Forwards the overlay's dismissed signal to EventBus so AttackExecutor
## can resolve deferred immediate effects.
func _on_damage_summary_dismissed() -> void:
	set_phase_hud_visible(true)
	EventBus.damage_summary_dismissed.emit()


## Called when a ship or squadron is destroyed — refreshes the HUD scores.
func _on_score_changed(_token: Node) -> void:
	update_phase_hud()


## Handles the player confirming they want to quit. Transitions to the
## main menu scene. UI-034.
func _on_quit_confirmed() -> void:
	GameManager.auto_save_replay()
	get_tree().change_scene_to_file(
			"res://src/scenes/main_menu/main_menu.tscn")


# ---------------------------------------------------------------------------
# Private — Layout helpers
# ---------------------------------------------------------------------------

## Updates the position of both ship card panels based on viewport size.
func _update_card_panel_positions() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	rebel_card_panel.update_position(vp_size)
	imperial_card_panel.update_position(vp_size)
	if card_detail_overlay:
		card_detail_overlay.update_size(vp_size)

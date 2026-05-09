## ToolOverlayController
##
## Owns the three board-level overlay sub-controllers — maneuver tool,
## range overlay, and targeting list — and the orchestration that used to
## live on `game_board.gd`: keyboard shortcuts (M / R / T / A), Escape
## handling for active overlays, the toolbar request handlers
## ([signal EventBus.maneuver_tool_requested] /
## [signal EventBus.range_overlay_requested]), and the "dismiss other
## tools" coordination requested by the attack pipeline.
##
## Extracted from [game_board.gd](game_board.gd) as part of refactoring
## phase K11.
class_name ToolOverlayController
extends Node

# ---------------------------------------------------------------------------
# Sub-controllers (owned, exposed via getters)
# ---------------------------------------------------------------------------

## Maneuver tool — owns selection flag and live ManeuverToolScene.
var _maneuver_tool_controller: ManeuverToolController = null

## Range overlay — owns selection flag and live RangeOverlayScene.
var _range_tool_controller: RangeToolController = null

## Targeting list — owns the targeting list modal lifecycle.
var _targeting_list_controller: TargetingListController = null

# ---------------------------------------------------------------------------
# Injected dependencies
# ---------------------------------------------------------------------------

## Activation context — read to detect when a modal-driven maneuver tool
## is in progress (blocks the simulator) and to recover the activating
## ship for [method dismiss_maneuver_tool_with_preview].
var _activation_ctx: ActivationContext = null

## UI panel manager — used for the action toolbar disabled-flag check.
var _panel_mgr: UIPanelManager = null

## Logger.
var _log: GameLogger = GameLogger.new("ToolOverlayController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Creates and initialises the three sub-controllers, wires the EventBus
## signals they own, and stores injected references.
##
## [param token_container] — Node2D parent for tool / overlay scenes.
## [param panel_mgr] — UIPanelManager (toolbar enabled check + targeting modal).
## [param activation_ctx] — read-only access to the current activating ship.
## [param get_ship_tokens_fn] — Callable returning Array[ShipToken].
## [param get_squad_tokens_fn] — Callable returning Array[SquadronToken].
## [param targeting_layer_parent] — Node parent for the targeting modal's
##     CanvasLayer (typically the GameBoard scene root).
func initialize(
		token_container: Node2D,
		panel_mgr: UIPanelManager,
		activation_ctx: ActivationContext,
		get_ship_tokens_fn: Callable,
		get_squad_tokens_fn: Callable,
		targeting_layer_parent: Node) -> void:
	_panel_mgr = panel_mgr
	_activation_ctx = activation_ctx

	_maneuver_tool_controller = ManeuverToolController.new()
	_maneuver_tool_controller.name = "ManeuverToolController"
	add_child(_maneuver_tool_controller)
	_maneuver_tool_controller.initialize(token_container)

	_range_tool_controller = RangeToolController.new()
	_range_tool_controller.name = "RangeToolController"
	add_child(_range_tool_controller)
	_range_tool_controller.initialize(token_container)

	_targeting_list_controller = TargetingListController.new()
	_targeting_list_controller.name = "TargetingListController"
	add_child(_targeting_list_controller)
	_targeting_list_controller.initialize(
			get_ship_tokens_fn, get_squad_tokens_fn,
			_maneuver_tool_controller, panel_mgr, targeting_layer_parent)

	_connect_signals()


## Returns the maneuver tool sub-controller.
func get_maneuver_tool_controller() -> ManeuverToolController:
	return _maneuver_tool_controller


## Returns the range overlay sub-controller.
func get_range_tool_controller() -> RangeToolController:
	return _range_tool_controller


## Returns the targeting list sub-controller.
func get_targeting_list_controller() -> TargetingListController:
	return _targeting_list_controller


## Lets the active overlay consume Escape to cancel selection or dismiss.
## Returns true when the event was consumed.
func try_handle_escape(event: InputEvent) -> bool:
	if _range_tool_controller.handle_escape(event):
		return true
	if _maneuver_tool_controller.handle_escape(event):
		return true
	return false


## Handles keyboard shortcuts for the tool buttons (M / R / T / A).
## Returns true when the event was consumed.
## Requirements: MT-U-007, RO-008, TL-UI-003a.
func try_handle_tool_shortcut(event: InputEvent) -> bool:
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


## Routes a token click to the active overlay (range / maneuver) when
## one is in selection mode.  Returns true when consumed.
func try_handle_token_click(token: ShipToken) -> bool:
	if _range_tool_controller.is_selecting():
		_range_tool_controller.show_overlay(token)
		return true
	if _maneuver_tool_controller.is_selecting():
		_maneuver_tool_controller.show_tool(token)
		return true
	return false


## Dismisses the maneuver tool, passing the current activation ship so
## the Navigate-token spend preview overlay is cleared when appropriate.
func dismiss_maneuver_tool_with_preview() -> void:
	var ship: ShipInstance = null
	if _activation_ctx and _activation_ctx.ship_activation_state:
		ship = _activation_ctx.ship_activation_state.get_ship()
	_maneuver_tool_controller.dismiss(ship)


## Dismisses range overlay, targeting list, and the maneuver tool.
## Bound to [signal TargetSelector.dismiss_other_tools_requested].
func dismiss_other_tools() -> void:
	_range_tool_controller.dismiss()
	_targeting_list_controller.dismiss()
	dismiss_maneuver_tool_with_preview()


# ---------------------------------------------------------------------------
# Private — signal wiring & toolbar handlers
# ---------------------------------------------------------------------------

## Connects the EventBus toolbar signals owned by this controller.
func _connect_signals() -> void:
	EventBus.maneuver_tool_requested.connect(_on_maneuver_tool_requested)
	EventBus.maneuver_tool_dismissed.connect(
			func() -> void: _maneuver_tool_controller.dismiss(null))
	EventBus.range_overlay_requested.connect(_on_range_overlay_requested)
	EventBus.range_overlay_dismissed.connect(
			func() -> void: _range_tool_controller.dismiss())
	EventBus.targeting_list_requested.connect(
			_targeting_list_controller.on_targeting_list_requested)


## Returns true when the toolbar action buttons are interactable.
## Mirrors the disabled state applied by
## [method ActionToolbar.set_tool_buttons_disabled].
func _are_tool_buttons_enabled() -> bool:
	if _panel_mgr == null or _panel_mgr.action_toolbar == null:
		return false
	if _panel_mgr.action_toolbar._maneuver_tool_btn \
			and _panel_mgr.action_toolbar._maneuver_tool_btn.disabled:
		return false
	return true


## Handles the "Maneuver Tool" toolbar / shortcut press.
## Toggle behaviour: dismiss if visible, cancel if selecting, else
## enter selection mode.  When the modal-driven activation maneuver
## tool is already attached, the simulator request is blocked.
## Requirements: MT-U-007.
func _on_maneuver_tool_requested() -> void:
	# Block simulation requests while the activation-mode maneuver tool
	# is active — the player must use the modal's Commit button instead.
	if _activation_ctx and _activation_ctx.ship_activation_state != null \
			and _maneuver_tool_controller.get_scene() != null:
		_log.info("Simulation maneuver blocked — activation maneuver in progress.")
		return
	if _maneuver_tool_controller.get_scene():
		dismiss_maneuver_tool_with_preview()
		return
	if _maneuver_tool_controller.is_selecting():
		_maneuver_tool_controller.cancel_selection()
		return
	_maneuver_tool_controller.start_selection()


## Handles the "Range Overlay" toolbar / shortcut press.
## When a maneuver tool is active, toggles the overlay on the ghost
## preview instead of requiring ship selection.  Otherwise cycles
## visible → selecting → dismissed.
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

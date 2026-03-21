## Tooltip Manager
##
## Singleton autoload that manages the global hover tooltip system.
## Provides a registration API for Controls and a programmatic show/hide
## API for essential game instructions (drag help, discard prompts, etc.).
##
## Uses a 4-state FSM: IDLE → WAITING → SHOWING / FORCED.
## - IDLE:    no tooltip activity.
## - WAITING: cursor entered a registered region; delay timer running.
## - SHOWING: tooltip visible via hover (respects toggle).
## - FORCED:  tooltip visible via programmatic show_text() — ignores toggle.
##
## The tooltip panel lives on a CanvasLayer at layer 100, ensuring it
## renders above all other UI.
##
## Requirements: TT-001–007, TT-012–013, TT-050–052, TT-070–075.
extends Node


## Tooltip FSM states.
enum State {
	IDLE,
	WAITING,
	SHOWING,
	FORCED,
}

## Logger for this system.
var _log: GameLogger = null

## Current FSM state.
var _state: int = State.IDLE

## Whether hover tooltips are enabled (toggled by the player). TT-070.
## Programmatic show_text() calls always work regardless of this flag.
var tooltips_enabled: bool = true

## Settings file path for persisting the toggle. TT-074.
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "tooltip"
const SETTINGS_KEY: String = "enabled"

## CanvasLayer at layer 100 for the tooltip. TT-050.
var _canvas_layer: CanvasLayer = null

## The visual tooltip panel. TT-030.
var _panel: TooltipPanel = null

## Toggle button in the lower-right corner. TT-070.
var _toggle_button: Button = null

## Delay timer before showing hover tooltip. TT-002.
var _delay_timer: Timer = null

## Auto-hide timer for programmatic show_text with duration. TT-006.
var _auto_hide_timer: Timer = null

## Registration table: Control → { callback: Callable }.
## The callback returns the BBCode text to display (or "" to suppress).
## TT-012.
var _registrations: Dictionary = {}

## The Control currently being hovered (if any).
var _hovered_control: Control = null

## Offset vector for cursor-following positioning.
var _offset: Vector2 = Vector2.ZERO


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	_log = GameLogger.new("TooltipManager")
	_offset = Vector2(GameScale.tooltip_offset_x, GameScale.tooltip_offset_y)

	_load_toggle_setting()
	_create_canvas_layer()
	_create_panel()
	_create_toggle_button()
	_create_timers()
	_log.info("Ready — tooltips_enabled=%s, offset=%s" % [
			str(tooltips_enabled), str(_offset)])


func _process(_delta: float) -> void:
	if _state == State.SHOWING or _state == State.FORCED:
		_update_position()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	# While in WAITING or SHOWING from hover, track hovered control.
	if _state == State.WAITING or _state == State.SHOWING:
		if _hovered_control and is_instance_valid(_hovered_control):
			var mouse_pos: Vector2 = _hovered_control.get_global_mouse_position()
			var rect: Rect2 = _hovered_control.get_global_rect()
			if not rect.has_point(mouse_pos):
				_on_hover_exit()


# ------------------------------------------------------------------
# Public API — Registration (TT-001, TT-003, TT-012, TT-052)
# ------------------------------------------------------------------

## Registers a Control for hover tooltip display.
## [param control]  — the UI element whose hover is tracked.
## [param callback] — a Callable that returns the BBCode text to show
##                    (called at display-time so text can reflect game state).
##                    Return "" to suppress the tooltip for this invocation.
func register(control: Control, callback: Callable) -> void:
	if control == null:
		return
	_registrations[control] = {"callback": callback}
	control.mouse_entered.connect(_on_region_entered.bind(control))
	control.mouse_exited.connect(_on_region_exited.bind(control))
	# Auto-deregister when control leaves the tree (TT-052).
	if not control.tree_exiting.is_connected(_deregister_on_exit):
		control.tree_exiting.connect(_deregister_on_exit.bind(control))


## Removes a Control from the registration table.
func deregister(control: Control) -> void:
	if control == null:
		return
	if _hovered_control == control:
		_on_hover_exit()
	_registrations.erase(control)
	# Disconnect signals if still connected.
	if control.mouse_entered.is_connected(_on_region_entered):
		control.mouse_entered.disconnect(_on_region_entered)
	if control.mouse_exited.is_connected(_on_region_exited):
		control.mouse_exited.disconnect(_on_region_exited)
	if control.tree_exiting.is_connected(_deregister_on_exit):
		control.tree_exiting.disconnect(_deregister_on_exit)


# ------------------------------------------------------------------
# Public API — Programmatic show/hide (TT-005, TT-006, TT-007)
# ------------------------------------------------------------------

## Shows the tooltip at the current cursor position with the given text.
## By default respects the global toggle switch.  Pass [code]force=true[/code]
## for essential gameplay instructions (e.g. discard prompt) that must
## always be visible.
## [param text]     — BBCode text to display.
## [param position] — screen position override (Vector2.INF = follow cursor).
## [param duration] — auto-hide after N seconds; 0.0 = no auto-hide.
## [param force]    — if true, enters FORCED state (ignores toggle).
func show_text(text: String, position: Vector2 = Vector2.INF,
		duration: float = 0.0, force: bool = false) -> void:
	if text.is_empty():
		if _log:
			_log.info("show_text() called with empty text — ignored.")
		return
	if not force and not tooltips_enabled:
		if _log:
			_log.info("show_text() suppressed (toggle OFF): '%s'" % text.left(60))
		return
	_cancel_delay()
	_auto_hide_timer.stop()
	_state = State.FORCED
	_panel.set_content(text)
	_panel.visible = true
	if position != Vector2.INF:
		_panel.position = position
	else:
		_update_position()
	if duration > 0.0:
		_auto_hide_timer.wait_time = duration
		_auto_hide_timer.start()
	if _log:
		_log.info("show_text() SHOWN (force=%s, dur=%.1f): '%s'" % [
				str(force), duration, text.left(60)])


## Hides the tooltip and returns to IDLE state.
func hide_tooltip() -> void:
	_cancel_delay()
	_auto_hide_timer.stop()
	_panel.visible = false
	var prev_state: int = _state
	_state = State.IDLE
	_hovered_control = null
	if _log:
		_log.info("hide_tooltip() — was %s, now IDLE." % State.keys()[prev_state])


## Toggles tooltips on/off programmatically. Used by ActionToolbar.
## Requirements: TT-070.
func toggle_tooltips() -> void:
	_on_toggle_pressed()


## Returns the toggle button node so it can be reparented into the
## ActionToolbar. Requirements: MT-U-001.
func get_toggle_button() -> Button:
	return _toggle_button


# ------------------------------------------------------------------
# Toggle button (TT-070–075)
# ------------------------------------------------------------------

## Toggles the tooltip enabled state and persists it.
func _on_toggle_pressed() -> void:
	tooltips_enabled = not tooltips_enabled
	_update_toggle_visual()
	_save_toggle_setting()
	if not tooltips_enabled and _state == State.SHOWING:
		hide_tooltip()
	if _log:
		_log.info("Tooltips toggled %s" % (
				"ON" if tooltips_enabled else "OFF"))


## Updates the toggle button's visual appearance.
func _update_toggle_visual() -> void:
	if _toggle_button == null:
		return
	_toggle_button.text = "?" if tooltips_enabled else "X"
	_toggle_button.modulate = Color.WHITE if tooltips_enabled \
			else Color(1.0, 1.0, 1.0, 0.4)


## Saves the toggle setting to the user config file.
func _save_toggle_setting() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	# Load existing settings first.
	if FileAccess.file_exists(SETTINGS_PATH):
		cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, tooltips_enabled)
	cfg.save(SETTINGS_PATH)


## Loads the toggle setting from the user config file.
func _load_toggle_setting() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		tooltips_enabled = cfg.get_value(
				SETTINGS_SECTION, SETTINGS_KEY, true)


# ------------------------------------------------------------------
# Hover FSM callbacks
# ------------------------------------------------------------------

## Called when the cursor enters a registered Control.
func _on_region_entered(control: Control) -> void:
	if not _registrations.has(control):
		return
	if _state == State.FORCED:
		if _log:
			_log.info("Region entered while FORCED — ignoring.")
		return # Programmatic tooltip takes priority.
	# Reset if switching regions.
	if _hovered_control != control:
		_cancel_delay()
		_panel.visible = false
	_hovered_control = control
	if not tooltips_enabled:
		if _log:
			_log.info("Region entered but tooltips disabled — ignoring.")
		return
	_state = State.WAITING
	_delay_timer.wait_time = GameScale.tooltip_hover_delay_sec
	_delay_timer.start()
	if _log:
		_log.info("Region entered — WAITING (delay=%.2fs)." % [
				GameScale.tooltip_hover_delay_sec])


## Called when the cursor exits a registered Control.
func _on_region_exited(control: Control) -> void:
	if _hovered_control != control:
		return
	if _state == State.FORCED:
		return # Programmatic tooltip unaffected.
	_on_hover_exit()


## Internal: cancel hover and return to IDLE.
func _on_hover_exit() -> void:
	_cancel_delay()
	if _state == State.SHOWING:
		_panel.visible = false
	var prev: int = _state
	if _state != State.FORCED:
		_state = State.IDLE
	_hovered_control = null
	if _log:
		_log.info("Hover exit — was %s, now %s." % [
				State.keys()[prev], State.keys()[_state]])


## Delay timer expired — show the hover tooltip.
func _on_delay_timeout() -> void:
	if _state != State.WAITING:
		return
	if _hovered_control == null or not is_instance_valid(_hovered_control):
		_state = State.IDLE
		return
	if not _registrations.has(_hovered_control):
		_state = State.IDLE
		return
	var reg: Dictionary = _registrations[_hovered_control]
	var callback: Callable = reg["callback"] as Callable
	var text: String = callback.call() as String
	if text.is_empty():
		_state = State.IDLE
		if _log:
			_log.info("Delay timeout — callback returned empty, back to IDLE.")
		return
	_state = State.SHOWING
	_panel.set_content(text)
	_panel.visible = true
	_update_position()
	if _log:
		_log.info("Delay timeout — SHOWING: '%s'" % text.left(60))


## Auto-hide timer expired — hide the forced tooltip.
func _on_auto_hide_timeout() -> void:
	if _log:
		_log.info("Auto-hide timer expired (state=%s)." % State.keys()[_state])
	if _state == State.FORCED:
		hide_tooltip()


# ------------------------------------------------------------------
# Internal helpers
# ------------------------------------------------------------------

## Cancels the delay timer.
func _cancel_delay() -> void:
	if _delay_timer:
		_delay_timer.stop()


## Updates the tooltip panel position to follow the cursor.
func _update_position() -> void:
	if _panel == null or not _panel.visible:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var cursor: Vector2 = vp.get_mouse_position()
	var vp_size: Vector2 = vp.get_visible_rect().size
	_panel.position = TooltipLayout.compute_position(
			cursor, _panel.size, vp_size, _offset)


## Auto-deregister callback for tree_exiting (TT-052).
func _deregister_on_exit(control: Control) -> void:
	deregister(control)


# ------------------------------------------------------------------
# Setup helpers (called once from _ready)
# ------------------------------------------------------------------

## Creates the CanvasLayer at layer 100. TT-050.
func _create_canvas_layer() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "TooltipLayer"
	_canvas_layer.layer = 100
	add_child(_canvas_layer)


## Creates the TooltipPanel widget.
func _create_panel() -> void:
	_panel = TooltipPanel.new()
	_panel.name = "TooltipPanel"
	_canvas_layer.add_child(_panel)


## Creates the toggle button in the lower-right corner. TT-070.
func _create_toggle_button() -> void:
	_toggle_button = Button.new()
	_toggle_button.name = "TooltipToggle"
	_toggle_button.text = "?"
	_toggle_button.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_toggle_button.custom_minimum_size = Vector2(btn_size, btn_size)
	_toggle_button.size = Vector2(btn_size, btn_size)
	_toggle_button.add_theme_font_size_override("font_size", 16)
	_toggle_button.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_toggle_button.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_toggle_button.tooltip_text = "Toggle hover tooltips"
	_toggle_button.pressed.connect(_on_toggle_pressed)
	# Anchor to bottom-right corner.
	_toggle_button.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_toggle_button.anchor_left = 1.0
	_toggle_button.anchor_top = 1.0
	_toggle_button.anchor_right = 1.0
	_toggle_button.anchor_bottom = 1.0
	var pad: float = GameScale.tooltip_toggle_button_edge_padding
	_toggle_button.offset_left = - (btn_size + pad)
	_toggle_button.offset_top = - (btn_size + pad)
	_toggle_button.offset_right = - pad
	_toggle_button.offset_bottom = - pad
	_canvas_layer.add_child(_toggle_button)
	_update_toggle_visual()


## Creates the delay and auto-hide timers.
func _create_timers() -> void:
	_delay_timer = Timer.new()
	_delay_timer.name = "DelayTimer"
	_delay_timer.one_shot = true
	_delay_timer.timeout.connect(_on_delay_timeout)
	add_child(_delay_timer)

	_auto_hide_timer = Timer.new()
	_auto_hide_timer.name = "AutoHideTimer"
	_auto_hide_timer.one_shot = true
	_auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
	add_child(_auto_hide_timer)

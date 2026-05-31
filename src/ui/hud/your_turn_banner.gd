## YourTurnBanner
##
## Brief "Your Turn" banner displayed during Ship and Squadron Phase
## player transitions. Auto-dismisses after a configurable duration
## or on click.
##
## Requirements: HO-004 — brief banner on player switch.
class_name YourTurnBanner
extends ColorRect


## Banner background colour (semi-transparent).
const BANNER_COLOR: Color = Color(0.05, 0.05, 0.15, 0.85)

## Default display duration in seconds before auto-dismiss.
const DEFAULT_DURATION: float = 2.0

## Banner height in pixels.
const BANNER_HEIGHT: float = 100.0

## The title label.
var _title_label: Label = null

## Timer for auto-dismiss.
var _timer: Timer = null

## Logger.
var _log: GameLogger = GameLogger.new("YourTurnBanner")


func _init() -> void:
	color = BANNER_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_build_ui()


## Shows the banner for the given player.
## [param player_index] — the player who should take control.
## [param duration] — how long to show (0 = no auto-dismiss).
## [param player_label] — projected player identity label from GameState.
func show_banner(
		player_index: int,
		duration: float = DEFAULT_DURATION,
		player_label: String = "") -> void:
	var player_name: String = _resolved_player_label(player_index, player_label)
	_title_label.text = "%s — Your Turn" % player_name
	visible = true

	if duration > 0.0:
		_timer.start(duration)

	_log.info("Your Turn banner shown for player %d." % player_index)


func _resolved_player_label(player_index: int, player_label: String) -> String:
	var label: String = player_label.strip_edges()
	if not label.is_empty():
		return label
	if player_index < 0:
		return "Player"
	return "Player %d" % player_index


## Hides the banner and emits handoff_accepted.
func dismiss() -> void:
	if not visible:
		return
	_timer.stop()
	visible = false
	EventBus.handoff_accepted.emit()


## Positions the banner centred horizontally at the vertical centre.
## [param viewport_size] — the current viewport dimensions.
func update_size(viewport_size: Vector2) -> void:
	var banner_w: float = viewport_size.x * 0.5
	position = Vector2(
			(viewport_size.x - banner_w) * 0.5,
			(viewport_size.y - BANNER_HEIGHT) * 0.5)
	size = Vector2(banner_w, BANNER_HEIGHT)
	custom_minimum_size = size


## Builds the UI elements.
func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_title_label.name = "TitleLabel"
	_title_label.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_title_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			dismiss()
			get_viewport().set_input_as_handled()


func _on_timer_timeout() -> void:
	dismiss()

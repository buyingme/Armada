## DebugToast
##
## A small, self-removing notification label that fades in at the top-centre
## of the viewport, holds briefly, then fades out and frees itself.
##
## Usage:
##   var toast := DebugToast.new("Quicksave complete.")
##   some_canvas_layer.add_child(toast)
##
## The toast positions itself in [method _ready], animates via a
## [Tween], and calls [method queue_free] when finished.
## No external cleanup is needed.
class_name DebugToast
extends PanelContainer


## Duration the toast stays fully visible (seconds).
const HOLD_DURATION: float = 1.5

## Fade-in / fade-out duration (seconds).
const FADE_DURATION: float = 0.3

## Vertical offset from the top edge of the viewport.
const TOP_MARGIN: int = 24

## Toast background colour — dark, semi-transparent blue.
const BG_COLOUR: Color = Color(0.1, 0.14, 0.22, 0.92)

## Toast border colour — teal accent.
const BORDER_COLOUR: Color = Color(0.3, 0.7, 0.65, 1.0)

## Toast text colour.
const TEXT_COLOUR: Color = Color(0.85, 0.95, 0.9)

## Font size for the toast message.
const FONT_SIZE: int = 14

## The inner label displaying the message.
var _label: Label = null


## Creates a toast with the given [param message].
func _init(message: String) -> void:
	_apply_style()
	_build_label(message)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func _ready() -> void:
	_position_top_centre()
	_animate()


## Applies the panel background style.
func _apply_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOUR
	style.border_color = BORDER_COLOUR
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	add_theme_stylebox_override("panel", style)


## Creates the inner label.
func _build_label(message: String) -> void:
	_label = Label.new()
	_label.text = message
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOUR)
	add_child(_label)


## Centres the toast horizontally near the top of the viewport.
func _position_top_centre() -> void:
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2((vp_size.x - size.x) * 0.5, TOP_MARGIN)


## Runs the fade-in → hold → fade-out → free sequence.
func _animate() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)

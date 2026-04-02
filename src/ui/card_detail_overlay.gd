## CardDetailOverlay
##
## Full-screen semi-transparent overlay that displays a large card image
## centred on screen. Activated by right-clicking a ship card entry in
## [ShipCardPanel]. Click anywhere or press Escape to dismiss.
##
## Styled per .skills/ui_styling.md §1 (colour palette) and §10
## (anchor reset pattern).
##
## Requirements: UI-002.
class_name CardDetailOverlay
extends ColorRect


## Overlay background colour (dark semi-transparent).
const OVERLAY_BG: Color = Color(0.02, 0.02, 0.08, 0.85)

## Maximum card image height fraction of viewport height.
const MAX_CARD_HEIGHT_FRACTION: float = 0.85

## Maximum card image width fraction of viewport width.
const MAX_CARD_WIDTH_FRACTION: float = 0.6

## Logger.
var _log: GameLogger = GameLogger.new("CardDetailOverlay")

## Texture rect showing the full-size card.
var _card_rect: TextureRect = null

## Title label (ship name) above the card image.
var _title_label: Label = null

## Container for card + label.
var _content: VBoxContainer = null


func _init() -> void:
	color = OVERLAY_BG
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


## Shows the overlay with the given card texture and ship name.
## [param texture] — the full card image.
## [param ship_name] — the ship name displayed above the card.
func show_card(texture: Texture2D, ship_name: String = "") -> void:
	if texture == null:
		_log.warn("No texture provided — cannot show card detail.")
		return
	_card_rect.texture = texture
	_title_label.text = ship_name
	_title_label.visible = ship_name != ""
	visible = true
	_fit_to_viewport()
	_log.info("Showing card detail for '%s'." % ship_name)


## Hides the overlay.
func dismiss() -> void:
	visible = false
	_card_rect.texture = null
	_log.info("Card detail dismissed.")


## Resizes the overlay and card image to fill the viewport.
## [param viewport_size] — current viewport dimensions.
func update_size(viewport_size: Vector2) -> void:
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size
	_fit_to_viewport()


## Builds the internal UI.
func _build_ui() -> void:
	# CenterContainer holds the card + label.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 8)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(_content)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color",
			Color(0.9, 0.85, 0.6))
	_title_label.visible = false
	_content.add_child(_title_label)

	_card_rect = TextureRect.new()
	_card_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_card_rect)

	# Hint label at the bottom.
	var hint: Label = Label.new()
	hint.text = "Click anywhere or press Escape to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_content.add_child(hint)


## Sizes the card image to fit within viewport bounds.
func _fit_to_viewport() -> void:
	if _card_rect == null or _card_rect.texture == null:
		return
	var vp: Vector2 = size
	if vp == Vector2.ZERO and get_viewport():
		vp = get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	var max_w: float = vp.x * MAX_CARD_WIDTH_FRACTION
	var max_h: float = vp.y * MAX_CARD_HEIGHT_FRACTION
	_card_rect.custom_minimum_size = Vector2(max_w, max_h)


## Handles click-to-dismiss and Escape-to-dismiss.
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			dismiss()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			dismiss()
			accept_event()

## DamageSummaryOverlay
##
## Full-screen semi-transparent overlay that displays damage cards in a
## horizontal row:  [faceup₁] [faceup₂] … [card-back] ×N
##
## Two use-cases:
##   1. **After an attack** — shows only the cards just dealt.
##   2. **Panel click** — shows ALL damage cards currently on a ship.
##
## Click anywhere or press Escape to dismiss.
##
## Styled per .skills/ui_styling.md §1 (colour palette).
## Requirements: DM-005, DM-006.
class_name DamageSummaryOverlay
extends ColorRect


## Overlay background colour (dark semi-transparent).
const OVERLAY_BG: Color = Color(0.02, 0.02, 0.08, 0.82)

## Maximum card height as fraction of viewport height.
const MAX_CARD_HEIGHT_FRAC: float = 0.60

## Gap between all card images in the row (px).
const CARD_GAP: float = 16.0

## Emitted when the user dismisses the overlay (click or Escape).
signal dismissed()

## Logger.
var _log: GameLogger = GameLogger.new("DamageSummaryOverlay")

## Internal container (freed + rebuilt on each show).
var _content: Control = null


func _init() -> void:
	color = OVERLAY_BG
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Shows the damage summary overlay.
## [param faceup_textures] — Array of {texture: Texture2D, title: String}
##     for each faceup card (in order).
## [param facedown_count] — number of facedown cards.
## [param facedown_texture] — the card-back texture.
## [param ship_name] — name of the ship (shown in title).
## [param title_suffix] — text appended after the ship name in the title
##     (default "Damage Dealt"; use "Damage Cards" for the panel overview).
func show_summary(faceup_textures: Array, facedown_count: int,
		facedown_texture: Texture2D, ship_name: String,
		title_suffix: String = "Damage Dealt") -> void:
	_clear_content()
	if faceup_textures.is_empty() and facedown_count == 0:
		return
	visible = true
	_build_content(faceup_textures, facedown_count,
			facedown_texture, ship_name, title_suffix)
	_log.info("Showing damage summary for '%s': %d faceup, %d facedown."
			% [ship_name, faceup_textures.size(), facedown_count])


## Hides the overlay and frees content nodes.
func dismiss() -> void:
	visible = false
	_clear_content()
	_log.info("Damage summary dismissed.")
	dismissed.emit()


## Resizes the overlay to fill the viewport.
func update_size(viewport_size: Vector2) -> void:
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size


## Builds the visual layout of card images in a flat horizontal row:
## [faceup₁] [faceup₂] … [card-back] ×N
func _build_content(faceup_textures: Array, facedown_count: int,
		facedown_texture: Texture2D, ship_name: String,
		title_suffix: String) -> void:
	var vp: Vector2 = size
	if vp == Vector2.ZERO and get_viewport():
		vp = get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)

	var max_card_h: float = vp.y * MAX_CARD_HEIGHT_FRAC

	# --- Title ---
	var title: Label = Label.new()
	title.text = "%s — %s" % [ship_name, title_suffix]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color",
			Color(0.95, 0.85, 0.6))
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(vp.x, 32.0)
	_content.add_child(title)

	# Compute card dimensions from the first available texture.
	var card_h: float = max_card_h
	var card_w: float = card_h * 0.7  # fallback aspect
	var sample_tex: Texture2D = null
	if not faceup_textures.is_empty():
		sample_tex = faceup_textures[0].get("texture", null) as Texture2D
	elif facedown_texture:
		sample_tex = facedown_texture
	if sample_tex:
		var aspect: float = (
				float(sample_tex.get_width())
				/ maxf(float(sample_tex.get_height()), 1.0))
		card_w = card_h * aspect

	# Count total card-width items: each faceup + 1 facedown stack.
	var faceup_count: int = faceup_textures.size()
	var has_facedown: bool = facedown_count > 0 and facedown_texture != null
	var item_count: int = faceup_count + (1 if has_facedown else 0)

	# Estimate ×N label width.
	var xn_label_w: float = 0.0
	if has_facedown:
		xn_label_w = 8.0 + 28.0 * 1.5  # gap + rough char width

	# Total row width.
	var total_w: float = card_w * item_count
	if item_count > 1:
		total_w += CARD_GAP * (item_count - 1)
	total_w += xn_label_w

	# Scale down card_h if the row would exceed 90 % of viewport width.
	var max_row_w: float = vp.x * 0.90
	if total_w > max_row_w and item_count > 0:
		var scale_down: float = max_row_w / total_w
		card_h *= scale_down
		card_w *= scale_down
		xn_label_w *= scale_down
		total_w = max_row_w

	# Centre the row horizontally, vertically below title.
	var group_x: float = (vp.x - total_w) * 0.5
	var group_y: float = (vp.y - card_h) * 0.5 + 16.0

	# --- Faceup cards ---
	var x_cursor: float = group_x
	for entry: Dictionary in faceup_textures:
		var tex: Texture2D = entry.get("texture", null) as Texture2D
		var card_title: String = entry.get("title", "") as String
		if tex == null:
			continue
		var rect: TextureRect = _make_card_rect(tex, card_w, card_h)
		rect.position = Vector2(x_cursor, group_y)
		rect.tooltip_text = card_title
		_content.add_child(rect)
		x_cursor += card_w + CARD_GAP

	# --- Facedown card-back + ×N ---
	if has_facedown:
		var back_rect: TextureRect = _make_card_rect(
				facedown_texture, card_w, card_h)
		back_rect.position = Vector2(x_cursor, group_y)
		_content.add_child(back_rect)

		var count_label: Label = Label.new()
		count_label.text = "×%d" % facedown_count
		count_label.add_theme_font_size_override("font_size", 28)
		count_label.add_theme_color_override(
				"font_color", Color.WHITE)
		count_label.position = Vector2(
				x_cursor + card_w + 8.0,
				group_y + card_h * 0.5 - 16.0)
		_content.add_child(count_label)

	# --- Hint ---
	var hint: Label = Label.new()
	hint.text = "Click anywhere or press Escape to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.position = Vector2(0.0, vp.y - 40.0)
	hint.size = Vector2(vp.x, 24.0)
	_content.add_child(hint)


## Creates a TextureRect sized to [param w] × [param h].
func _make_card_rect(tex: Texture2D, w: float, h: float) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(w, h)
	rect.size = Vector2(w, h)
	rect.mouse_filter = Control.MOUSE_FILTER_PASS
	return rect


## Frees all content children.
func _clear_content() -> void:
	if _content and is_instance_valid(_content):
		_content.queue_free()
		_content = null


## Click-to-dismiss.
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			dismiss()
			accept_event()


## Escape-to-dismiss.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			dismiss()
			accept_event()

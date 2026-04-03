## DamageSummaryOverlay
##
## Full-screen semi-transparent overlay shown after damage cards are dealt
## to a ship during an attack. Displays faceup cards on the left and
## facedown cards (card-back) shifted 50 px right and down, giving a clear
## visual indication of the cards just dealt.
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

## Facedown stack offset in pixels (right and down from faceup group).
const FACEDOWN_OFFSET: Vector2 = Vector2(50.0, 50.0)

## Gap between faceup card images in pixels.
const FACEUP_GAP: float = 16.0

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
##     for each faceup card dealt (in order).
## [param facedown_count] — number of facedown cards dealt.
## [param facedown_texture] — the card-back texture.
## [param ship_name] — name of the damaged ship (shown as title).
func show_summary(faceup_textures: Array, facedown_count: int,
		facedown_texture: Texture2D, ship_name: String) -> void:
	_clear_content()
	if faceup_textures.is_empty() and facedown_count == 0:
		return
	visible = true
	_build_content(faceup_textures, facedown_count,
			facedown_texture, ship_name)
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


## Builds the visual layout of card images.
func _build_content(faceup_textures: Array, facedown_count: int,
		facedown_texture: Texture2D, ship_name: String) -> void:
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
	title.text = ship_name + " — Damage Dealt"
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

	# Total width of the faceup group.
	var faceup_count: int = faceup_textures.size()
	var faceup_total_w: float = 0.0
	if faceup_count > 0:
		faceup_total_w = (
				card_w * faceup_count
				+ FACEUP_GAP * (faceup_count - 1))
	# Facedown adds one card width shifted by FACEDOWN_OFFSET.
	var has_facedown: bool = facedown_count > 0 and facedown_texture != null
	var total_w: float = faceup_total_w
	if has_facedown:
		if faceup_count > 0:
			total_w += FACEDOWN_OFFSET.x + card_w
		else:
			total_w = card_w

	# Centre the group horizontally, vertically below title.
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
		x_cursor += card_w + FACEUP_GAP

	# --- Facedown card(s) ---
	if has_facedown:
		var fd_x: float = group_x + faceup_total_w + FACEDOWN_OFFSET.x
		if faceup_count == 0:
			fd_x = group_x
		var fd_y: float = group_y + FACEDOWN_OFFSET.y
		if faceup_count == 0:
			fd_y = group_y
		var back_rect: TextureRect = _make_card_rect(
				facedown_texture, card_w, card_h)
		back_rect.position = Vector2(fd_x, fd_y)
		_content.add_child(back_rect)

		if facedown_count > 1:
			var count_label: Label = Label.new()
			count_label.text = "×%d" % facedown_count
			count_label.add_theme_font_size_override("font_size", 28)
			count_label.add_theme_color_override(
					"font_color", Color.WHITE)
			count_label.position = Vector2(
					fd_x + card_w + 8.0,
					fd_y + card_h * 0.5 - 16.0)
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

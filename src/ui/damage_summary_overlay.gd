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
	SfxManager.play_sfx("skip_beep")
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
	var vp: Vector2 = _get_viewport_size()
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)
	_add_title_label(vp, ship_name, title_suffix)
	var dims: Dictionary = _compute_card_layout(
			vp, faceup_textures, facedown_count, facedown_texture)
	var x_cursor: float = _add_faceup_cards(faceup_textures, dims)
	_add_facedown_stack(facedown_count, facedown_texture, dims, x_cursor)
	_add_dismiss_hint(vp)


## Returns the effective viewport size for layout.
func _get_viewport_size() -> Vector2:
	var vp: Vector2 = size
	if vp == Vector2.ZERO and get_viewport():
		vp = get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	return vp


## Adds the centred title label at the top of the overlay.
func _add_title_label(vp: Vector2, ship_name: String,
		title_suffix: String) -> void:
	var title: Label = Label.new()
	title.text = "%s — %s" % [ship_name, title_suffix]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(vp.x, 32.0)
	_content.add_child(title)


## Computes card dimensions and row layout. Returns a Dictionary with keys:
## card_w, card_h, group_x, group_y, item_count, has_facedown.
func _compute_card_layout(vp: Vector2, faceup_textures: Array,
		facedown_count: int,
		facedown_texture: Texture2D) -> Dictionary:
	var card_h: float = vp.y * MAX_CARD_HEIGHT_FRAC
	var card_w: float = card_h * 0.7
	var sample_tex: Texture2D = _pick_sample_texture(
			faceup_textures, facedown_texture)
	if sample_tex:
		var aspect: float = float(sample_tex.get_width()) / maxf(
				float(sample_tex.get_height()), 1.0)
		card_w = card_h * aspect
	var has_fd: bool = facedown_count > 0 and facedown_texture != null
	var item_count: int = faceup_textures.size() + (1 if has_fd else 0)
	var xn_w: float = (8.0 + 42.0) if has_fd else 0.0
	var total_w: float = card_w * item_count + xn_w
	if item_count > 1:
		total_w += CARD_GAP * (item_count - 1)
	var max_row_w: float = vp.x * 0.90
	if total_w > max_row_w and item_count > 0:
		var s: float = max_row_w / total_w
		card_h *= s
		card_w *= s
		total_w = max_row_w
	return {"card_w": card_w, "card_h": card_h,
			"group_x": (vp.x - total_w) * 0.5,
			"group_y": (vp.y - card_h) * 0.5 + 16.0,
			"has_facedown": has_fd}


## Returns the first available texture for size sampling.
func _pick_sample_texture(faceup_textures: Array,
		facedown_texture: Texture2D) -> Texture2D:
	if not faceup_textures.is_empty():
		return faceup_textures[0].get("texture", null) as Texture2D
	return facedown_texture


## Adds faceup card rects. Returns the x cursor after the last card.
func _add_faceup_cards(faceup_textures: Array,
		dims: Dictionary) -> float:
	var card_w: float = dims["card_w"]
	var card_h: float = dims["card_h"]
	var x_cursor: float = dims["group_x"]
	var group_y: float = dims["group_y"]
	for entry: Dictionary in faceup_textures:
		var tex: Texture2D = entry.get("texture", null) as Texture2D
		if tex == null:
			continue
		var rect: TextureRect = _make_card_rect(tex, card_w, card_h)
		rect.position = Vector2(x_cursor, group_y)
		rect.tooltip_text = entry.get("title", "") as String
		_content.add_child(rect)
		x_cursor += card_w + CARD_GAP
	return x_cursor


## Adds the facedown card-back rect and ×N count label.
func _add_facedown_stack(facedown_count: int,
		facedown_texture: Texture2D, dims: Dictionary,
		x_cursor: float) -> void:
	if not dims["has_facedown"]:
		return
	var card_w: float = dims["card_w"]
	var card_h: float = dims["card_h"]
	var group_y: float = dims["group_y"]
	var back_rect: TextureRect = _make_card_rect(
			facedown_texture, card_w, card_h)
	back_rect.position = Vector2(x_cursor, group_y)
	_content.add_child(back_rect)
	var count_label: Label = Label.new()
	count_label.text = "×%d" % facedown_count
	count_label.add_theme_font_size_override("font_size", 28)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.position = Vector2(
			x_cursor + card_w + 8.0, group_y + card_h * 0.5 - 16.0)
	_content.add_child(count_label)


## Adds the dismiss hint label at the bottom of the overlay.
func _add_dismiss_hint(vp: Vector2) -> void:
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

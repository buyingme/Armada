## Builds and refreshes the damage-card column in a ship-card-panel entry.
##
## Creates faceup damage-card thumbnails (clickable to open the
## [DamageSummaryOverlay]) and a facedown "×N" badge.
##
## This class is [RefCounted] and scene-tree independent.  The
## [member _tree_node] reference (any node in the tree) is kept solely to
## call [code]get_viewport().set_input_as_handled()[/code] when consuming
## input events.
##
## Extracted from [ShipCardPanel] in refactoring Phase D3.
class_name DamageCardDisplay
extends RefCounted


## Emitted when the player clicks a damage card or facedown badge
## to view ALL damage on the ship in the [DamageSummaryOverlay].
## [param ship_instance] — the ShipInstance whose damage should be shown.
signal damage_overview_requested(ship_instance: RefCounted)


## Height of damage card thumbnails in the side panel (pixels at 1× scale).
const DAMAGE_CARD_HEIGHT_PX: float = 28.0


## Shared texture cache (same Dictionary reference as the panel).
var _tex_cache: Dictionary

## Logger instance.
var _log: GameLogger = GameLogger.new("DamageCardDisplay")

## Any node in the tree — used only for [code]get_viewport()[/code].
var _tree_node: Control


## Creates a damage card display helper.
## [param tex_cache] — shared texture cache dictionary.
## [param tree_node] — a node in the scene tree (for viewport access).
func _init(tex_cache: Dictionary, tree_node: Control) -> void:
	_tex_cache = tex_cache
	_tree_node = tree_node


# ── Populate ─────────────────────────────────────────────────────────

## Rebuilds the damage card column for a ship entry.
## Shows one thumbnail per faceup card and a single card-back badge
## with ×N count for facedown cards.
func populate_damage_cards(col: VBoxContainer,
		instance: ShipInstance, scale_factor: float) -> void:
	for child: Node in col.get_children():
		col.remove_child(child)
		child.queue_free()

	var dmg_h: float = DAMAGE_CARD_HEIGHT_PX * scale_factor
	var faceup: Array = instance.faceup_damage
	var facedown_count: int = instance.facedown_damage.size()
	_log.info("Populating damage col for '%s': %d faceup, %d facedown"
			% [instance.ship_data.ship_name, faceup.size(),
				facedown_count])

	for card: RefCounted in faceup:
		var rect: TextureRect = _create_faceup_damage_rect(
				card, instance, dmg_h)
		if rect:
			col.add_child(rect)

	if facedown_count > 0:
		col.add_child(_create_facedown_badge(
				facedown_count, instance, dmg_h))

	for child: Node in col.get_children():
		if child is HBoxContainer:
			ShipCardEntryBuilder.set_children_mouse_pass(child as Control)


# ── Widget construction ──────────────────────────────────────────────

## Creates a [TextureRect] thumbnail for a single faceup damage card.
func _create_faceup_damage_rect(card: RefCounted,
		instance: ShipInstance, dmg_h: float) -> TextureRect:
	var tex: Texture2D = _get_damage_card_texture(card.effect_id)
	if tex == null:
		return null
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var t_aspect: float = (
			float(tex.get_width())
			/ maxf(float(tex.get_height()), 1.0))
	rect.custom_minimum_size = Vector2(dmg_h * t_aspect, dmg_h)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.tooltip_text = card.title
	rect.gui_input.connect(
			_on_damage_card_click.bind(card, instance))
	return rect


## Creates an HBoxContainer badge for facedown damage cards.
func _create_facedown_badge(facedown_count: int,
		instance: ShipInstance, dmg_h: float) -> HBoxContainer:
	var badge: HBoxContainer = HBoxContainer.new()
	badge.add_theme_constant_override("separation", 2)

	var bw: float = 0.0
	var back_tex: Texture2D = _get_damage_back_texture()
	if back_tex:
		var back_rect: TextureRect = TextureRect.new()
		back_rect.texture = back_tex
		back_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		back_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var b_aspect: float = (
				float(back_tex.get_width())
				/ maxf(float(back_tex.get_height()), 1.0))
		bw = dmg_h * b_aspect
		back_rect.custom_minimum_size = Vector2(bw, dmg_h)
		badge.add_child(back_rect)

	var label: Label = Label.new()
	label.text = "×%d" % facedown_count
	var font_sz: int = int(dmg_h * 0.55)
	label.add_theme_font_size_override("font_size", font_sz)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)

	var badge_w: float = bw + 2.0 + font_sz * 1.5
	badge.custom_minimum_size = Vector2(badge_w, dmg_h)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.gui_input.connect(
			_on_facedown_badge_click.bind(instance))
	return badge


# ── Click handlers ───────────────────────────────────────────────────

## Handles click on a faceup damage card thumbnail.
func _on_damage_card_click(event: InputEvent,
		card: RefCounted, ship_instance: RefCounted) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT \
			and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_log.info("Damage overview requested for '%s' via card '%s'."
			% [ship_instance.ship_data.ship_name, card.title])
	damage_overview_requested.emit(ship_instance)
	_tree_node.get_viewport().set_input_as_handled()


## Handles click on the facedown damage badge.
func _on_facedown_badge_click(event: InputEvent,
		ship_instance: RefCounted) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT \
			and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_log.info("Damage overview requested for '%s' via facedown badge."
			% ship_instance.ship_data.ship_name)
	damage_overview_requested.emit(ship_instance)
	_tree_node.get_viewport().set_input_as_handled()


# ── Texture loading ──────────────────────────────────────────────────

## Loads (or returns cached) the texture for a faceup damage card.
func _get_damage_card_texture(effect_id: String) -> Texture2D:
	var cache_key: String = "dmg_" + effect_id
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var filename: String = "damage_%s.png" % effect_id
	var tex: Texture2D = AssetLoader.load_texture(
			"damage_deck/", filename)
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Loads (or returns cached) the damage card back texture.
func _get_damage_back_texture() -> Texture2D:
	var cache_key: String = "dmg_back"
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var tex: Texture2D = AssetLoader.load_texture(
			"damage_deck/", "damage_back.png")
	if tex:
		_tex_cache[cache_key] = tex
	return tex

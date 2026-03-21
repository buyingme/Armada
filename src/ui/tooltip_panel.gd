## Tooltip Panel
##
## The visual widget for hover tooltips. A styled PanelContainer containing
## a MarginContainer and a RichTextLabel for BBCode content.
##
## All visual parameters (colours, font size, padding, corner radius) are
## read from GameScale at creation time, so they stay data-driven.
##
## The entire panel tree has MOUSE_FILTER_IGNORE so it never intercepts
## clicks or hover events.
##
## The panel enforces a minimum 4:3 aspect ratio to avoid vertical-stripe
## appearance, and will widen beyond max_width if content is very tall.
##
## Requirements: TT-010, TT-011, TT-030–035.
class_name TooltipPanel
extends PanelContainer


## Minimum aspect ratio (width / height).  Prevents vertical stripes.
## 4:3 ≈ 1.33.
const MIN_ASPECT_RATIO: float = 1.33

## The RichTextLabel used to display tooltip content.
var _rich_label: RichTextLabel = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# --- StyleBox ---
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = GameScale.tooltip_bg_color
	style.corner_radius_top_left = GameScale.tooltip_corner_radius
	style.corner_radius_top_right = GameScale.tooltip_corner_radius
	style.corner_radius_bottom_left = GameScale.tooltip_corner_radius
	style.corner_radius_bottom_right = GameScale.tooltip_corner_radius
	# Content margins are handled by the MarginContainer, so set panel's
	# content margin to zero to avoid double-padding.
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", style)

	# --- MarginContainer for inner padding ---
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(
			"margin_left", GameScale.tooltip_padding_h)
	margin.add_theme_constant_override(
			"margin_right", GameScale.tooltip_padding_h)
	margin.add_theme_constant_override(
			"margin_top", GameScale.tooltip_padding_v)
	margin.add_theme_constant_override(
			"margin_bottom", GameScale.tooltip_padding_v)
	add_child(margin)

	# --- RichTextLabel ---
	_rich_label = RichTextLabel.new()
	_rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich_label.bbcode_enabled = true
	_rich_label.fit_content = true
	_rich_label.scroll_active = false
	_rich_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rich_label.add_theme_font_size_override(
			"normal_font_size", GameScale.tooltip_font_size)
	_rich_label.add_theme_font_size_override(
			"bold_font_size", GameScale.tooltip_font_size)
	_rich_label.add_theme_font_size_override(
			"italics_font_size", GameScale.tooltip_font_size)
	_rich_label.add_theme_color_override(
			"default_color", GameScale.tooltip_text_color)
	_rich_label.add_theme_color_override(
			"font_shadow_color", GameScale.tooltip_shadow_color)
	_rich_label.add_theme_constant_override(
			"shadow_offset_x", GameScale.tooltip_shadow_offset)
	_rich_label.add_theme_constant_override(
			"shadow_offset_y", GameScale.tooltip_shadow_offset)
	margin.add_child(_rich_label)

	# Enforce max width (the panel will shrink-wrap when text is shorter).
	custom_minimum_size.x = 0.0
	size.x = 0.0


## Sets the BBCode content.  Measures at max_width, then widens if the
## resulting aspect ratio would be narrower than 4:3.
func set_content(bbcode_text: String) -> void:
	_rich_label.text = bbcode_text

	var max_w: float = GameScale.tooltip_max_width_px
	if max_w <= 0.0:
		max_w = 320.0
	var pad_h: float = float(GameScale.tooltip_padding_h) * 2.0
	var pad_v: float = float(GameScale.tooltip_padding_v) * 2.0
	var label_w: float = max_w - pad_h

	# Width constraint via custom_minimum_size so the Container layout
	# does NOT collapse the label to zero width during the await.
	_rich_label.custom_minimum_size = Vector2(label_w, 0.0)
	custom_minimum_size = Vector2(max_w, 0.0)
	size = Vector2(max_w, 0.0)

	# Wait one frame for the RichTextLabel to compute content height.
	await get_tree().process_frame

	# --- Aspect-ratio guard (widen if taller than 4:3) ---
	var content_h: float = float(_rich_label.get_content_height())
	var panel_h: float = content_h + pad_v
	if panel_h > 0.0 and max_w / panel_h < MIN_ASPECT_RATIO:
		var needed_w: float = ceilf(panel_h * MIN_ASPECT_RATIO)
		_rich_label.custom_minimum_size.x = needed_w - pad_h
		custom_minimum_size.x = needed_w
		size.x = needed_w
		# Re-measure after reflow at the wider width.
		await get_tree().process_frame

	_fit_to_content()


## Reads the final content height and applies the matching panel size.
func _fit_to_content() -> void:
	var pad_h: float = float(GameScale.tooltip_padding_h) * 2.0
	var pad_v: float = float(GameScale.tooltip_padding_v) * 2.0
	var content_h: float = float(_rich_label.get_content_height())
	var panel_w: float = _rich_label.custom_minimum_size.x + pad_h
	var panel_h: float = content_h + pad_v
	custom_minimum_size = Vector2(panel_w, panel_h)
	size = Vector2(panel_w, panel_h)

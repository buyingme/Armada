## Centralises repeated UI styling constants and factory methods.
##
## Provides the canonical modal-panel StyleBoxFlat, semantic colour
## constants, font-size tiers, and small label factories so that
## individual UI files no longer duplicate the same 6-8 lines.
class_name UIStyleHelper
extends RefCounted

# ── Modal panel colours ──────────────────────────────────────────────
## Standard modal background.  ui_styling.md §1.
const MODAL_BG: Color = Color(0.12, 0.12, 0.18, 0.95)
## Standard modal border.  ui_styling.md §1.
const MODAL_BORDER: Color = Color(0.4, 0.5, 0.7, 1.0)

# ── Semantic text colours ────────────────────────────────────────────
## Gold accent used for modal titles and highlighted text.
const GOLD_TITLE: Color = Color(0.9, 0.85, 0.6)
## Subdued hint text (dismiss prompts, secondary info).
const DIMMED_HINT: Color = Color(0.6, 0.6, 0.6)
## Standard body text for info labels.
const BODY_TEXT: Color = Color(0.8, 0.8, 0.85)
## Blue accent for informational highlights.
const BLUE_ACCENT: Color = Color(0.4, 0.7, 1.0)
## Red accent for errors or warnings.
const ERROR_RED: Color = Color(0.9, 0.3, 0.3)

# ── Font-size tiers ──────────────────────────────────────────────────
## Modal / section title.
const FONT_TITLE: int = 16
## Body / info labels.
const FONT_BODY: int = 13
## Subtitle / secondary labels.
const FONT_SUBTITLE: int = 12
## Dismiss-hint / micro text.
const FONT_HINT: int = 11


## Creates the canonical modal-panel StyleBoxFlat.
##
## [param content_margin]: set to [code]0.0[/code] when the panel uses
##     a child MarginContainer instead of StyleBox content margins.
## ui_styling.md §1.
static func create_modal_panel_style(
		content_margin: float = 16.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = MODAL_BG
	style.border_color = MODAL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	if content_margin > 0.0:
		style.set_content_margin_all(content_margin)
	return style


## Creates a small centered dismiss-hint label.
##
## Typical texts: "Press Escape to dismiss", "Click anywhere to close".
static func create_dismiss_hint(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_HINT)
	label.add_theme_color_override("font_color", DIMMED_HINT)
	return label


## Creates a centered title label with an optional colour override.
##
## Pass [constant GOLD_TITLE] for the standard gold highlight, or omit
## the colour to keep the theme default.
static func create_title_label(text: String,
		colour: Color = Color(-1, -1, -1)) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_TITLE)
	if colour != Color(-1, -1, -1):
		label.add_theme_color_override("font_color", colour)
	return label


## Creates a generic centered label with explicit size and colour.
##
## Use for body, subtitle, or any non-title label that still follows
## the standard centered pattern.
static func create_section_label(text: String, font_size: int,
		colour: Color = Color(-1, -1, -1)) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	if colour != Color(-1, -1, -1):
		label.add_theme_color_override("font_color", colour)
	return label

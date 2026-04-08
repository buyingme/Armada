extends GutTest
## Tests for UIStyleHelper — modal panel styles, colour constants,
## font-size tiers, and label factory methods.


# ── Colour constants ─────────────────────────────────────────────────

func test_gold_title_matches_canonical_value() -> void:
	assert_eq(UIStyleHelper.GOLD_TITLE, Color(0.9, 0.85, 0.6),
			"GOLD_TITLE should match canonical gold")


func test_dimmed_hint_matches_canonical_value() -> void:
	assert_eq(UIStyleHelper.DIMMED_HINT, Color(0.6, 0.6, 0.6),
			"DIMMED_HINT should match canonical grey")


func test_body_text_matches_canonical_value() -> void:
	assert_eq(UIStyleHelper.BODY_TEXT, Color(0.8, 0.8, 0.85),
			"BODY_TEXT should match canonical light")


func test_blue_accent_matches_canonical_value() -> void:
	assert_eq(UIStyleHelper.BLUE_ACCENT, Color(0.4, 0.7, 1.0),
			"BLUE_ACCENT should match canonical blue")


func test_error_red_matches_canonical_value() -> void:
	assert_eq(UIStyleHelper.ERROR_RED, Color(0.9, 0.3, 0.3),
			"ERROR_RED should match canonical red")


# ── Font-size tiers ──────────────────────────────────────────────────

func test_font_title_is_16() -> void:
	assert_eq(UIStyleHelper.FONT_TITLE, 16, "Title tier should be 16")


func test_font_body_is_13() -> void:
	assert_eq(UIStyleHelper.FONT_BODY, 13, "Body tier should be 13")


func test_font_subtitle_is_12() -> void:
	assert_eq(UIStyleHelper.FONT_SUBTITLE, 12, "Subtitle tier should be 12")


func test_font_hint_is_11() -> void:
	assert_eq(UIStyleHelper.FONT_HINT, 11, "Hint tier should be 11")


# ── create_modal_panel_style ─────────────────────────────────────────

func test_create_modal_panel_style_returns_stylebox() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style()
	assert_not_null(style, "Should return a StyleBoxFlat")


func test_create_modal_panel_style_bg_color() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style()
	assert_eq(style.bg_color, UIStyleHelper.MODAL_BG,
			"Background should match MODAL_BG")


func test_create_modal_panel_style_border_color() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style()
	assert_eq(style.border_color, UIStyleHelper.MODAL_BORDER,
			"Border colour should match MODAL_BORDER")


func test_create_modal_panel_style_border_width() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style()
	assert_eq(style.border_width_top, 2,
			"Border width should be 2 on all sides")
	assert_eq(style.border_width_bottom, 2,
			"Border width should be 2 on all sides")


func test_create_modal_panel_style_corner_radius() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style()
	assert_eq(style.corner_radius_top_left, 8,
			"Corner radius should be 8")
	assert_eq(style.corner_radius_bottom_right, 8,
			"Corner radius should be 8")


func test_create_modal_panel_style_default_content_margin() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style()
	assert_eq(style.content_margin_top, 16.0,
			"Default content margin should be 16")
	assert_eq(style.content_margin_left, 16.0,
			"Default content margin should be 16")


func test_create_modal_panel_style_no_content_margin() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style(0.0)
	assert_eq(style.content_margin_top, -1.0,
			"Zero margin should leave content margin at default -1")


func test_create_modal_panel_style_custom_content_margin() -> void:
	var style: StyleBoxFlat = UIStyleHelper.create_modal_panel_style(24.0)
	assert_eq(style.content_margin_top, 24.0,
			"Custom margin should be applied")


# ── create_dismiss_hint ──────────────────────────────────────────────

func test_create_dismiss_hint_text() -> void:
	var label: Label = UIStyleHelper.create_dismiss_hint("Press Escape")
	assert_eq(label.text, "Press Escape",
			"Label text should match input")


func test_create_dismiss_hint_centered() -> void:
	var label: Label = UIStyleHelper.create_dismiss_hint("test")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"Hint should be centered")


func test_create_dismiss_hint_font_size() -> void:
	var label: Label = UIStyleHelper.create_dismiss_hint("test")
	assert_eq(label.get_theme_font_size("font_size"),
			UIStyleHelper.FONT_HINT,
			"Hint should use FONT_HINT size")


func test_create_dismiss_hint_colour() -> void:
	var label: Label = UIStyleHelper.create_dismiss_hint("test")
	assert_eq(label.get_theme_color("font_color"),
			UIStyleHelper.DIMMED_HINT,
			"Hint should use DIMMED_HINT colour")


# ── create_title_label ───────────────────────────────────────────────

func test_create_title_label_text() -> void:
	var label: Label = UIStyleHelper.create_title_label("Title")
	assert_eq(label.text, "Title", "Label text should match input")


func test_create_title_label_centered() -> void:
	var label: Label = UIStyleHelper.create_title_label("T")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"Title should be centered")


func test_create_title_label_font_size() -> void:
	var label: Label = UIStyleHelper.create_title_label("T")
	assert_eq(label.get_theme_font_size("font_size"),
			UIStyleHelper.FONT_TITLE,
			"Title should use FONT_TITLE size")


func test_create_title_label_no_colour_by_default() -> void:
	var label: Label = UIStyleHelper.create_title_label("T")
	assert_false(label.has_theme_color_override("font_color"),
			"No colour override when sentinel is used")


func test_create_title_label_with_gold_colour() -> void:
	var label: Label = UIStyleHelper.create_title_label("T",
			UIStyleHelper.GOLD_TITLE)
	assert_eq(label.get_theme_color("font_color"),
			UIStyleHelper.GOLD_TITLE,
			"Gold colour should be applied")


# ── create_section_label ─────────────────────────────────────────────

func test_create_section_label_text_and_size() -> void:
	var label: Label = UIStyleHelper.create_section_label("Body", 13)
	assert_eq(label.text, "Body", "Label text should match")
	assert_eq(label.get_theme_font_size("font_size"), 13,
			"Font size should match input")


func test_create_section_label_centered() -> void:
	var label: Label = UIStyleHelper.create_section_label("X", 12)
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"Section label should be centered")


func test_create_section_label_no_colour_by_default() -> void:
	var label: Label = UIStyleHelper.create_section_label("X", 12)
	assert_false(label.has_theme_color_override("font_color"),
			"No colour override when sentinel is used")


func test_create_section_label_with_colour() -> void:
	var label: Label = UIStyleHelper.create_section_label("X", 12,
			UIStyleHelper.BLUE_ACCENT)
	assert_eq(label.get_theme_color("font_color"),
			UIStyleHelper.BLUE_ACCENT,
			"Colour override should be applied")

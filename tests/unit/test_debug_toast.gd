## Test: DebugToast
##
## Unit tests for the DebugToast notification widget.
extends GutTest


func test_toast_creates_with_message() -> void:
	var toast: DebugToast = DebugToast.new("Test message")
	assert_not_null(toast, "Toast should be created")
	assert_true(toast is PanelContainer,
			"Toast should extend PanelContainer")
	toast.free()


func test_toast_starts_invisible() -> void:
	var toast: DebugToast = DebugToast.new("Hello")
	assert_eq(toast.modulate.a, 0.0,
			"Toast should start fully transparent")
	toast.free()


func test_toast_mouse_filter_is_ignore() -> void:
	var toast: DebugToast = DebugToast.new("Ignored clicks")
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"Toast should not intercept mouse events")
	toast.free()


func test_toast_has_label_child() -> void:
	var toast: DebugToast = DebugToast.new("Label check")
	var label: Label = null
	for child: Node in toast.get_children():
		if child is Label:
			label = child as Label
			break
	assert_not_null(label, "Toast should have a Label child")
	assert_eq(label.text, "Label check",
			"Label text should match the message")
	toast.free()


func test_toast_has_panel_style() -> void:
	var toast: DebugToast = DebugToast.new("Styled")
	var style: StyleBox = toast.get_theme_stylebox("panel")
	assert_not_null(style, "Toast should have a panel stylebox")
	toast.free()


func test_toast_constants_are_positive() -> void:
	assert_gt(DebugToast.HOLD_DURATION, 0.0,
			"Hold duration should be positive")
	assert_gt(DebugToast.FADE_DURATION, 0.0,
			"Fade duration should be positive")
	assert_gt(DebugToast.TOP_MARGIN, 0,
			"Top margin should be positive")

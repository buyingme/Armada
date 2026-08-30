## DBG-001 bounded DEBUG controller interaction coverage.
extends GutTest

const ControllerScript: GDScript = preload(
		"res://src/scenes/game_board/debug_controller.gd")

var _board: Node2D
var _controller: DebugController


func before_each() -> void:
	DebugMode.enabled = false
	DebugMode.deselect_token()
	_board = Node2D.new()
	add_child_autofree(_board)
	_controller = ControllerScript.new()
	add_child_autofree(_controller)


func after_each() -> void:
	DebugMode.enabled = false
	DebugMode.deselect_token()


func test_f12_respects_board_eligibility() -> void:
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return false)
	assert_true(_controller.try_handle_input(_key(KEY_F12)))
	assert_false(DebugMode.enabled)


func test_escape_cancels_reposition_preview_without_a_command() -> void:
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return true)
	DebugMode.enabled = true
	var token := Node2D.new()
	add_child_autofree(token)
	_controller.handle_token_click(token)
	assert_true(_controller.is_reposition_preview_active())
	assert_true(_controller.try_handle_input(_key(KEY_ESCAPE)))
	assert_false(_controller.is_reposition_preview_active())
	assert_null(DebugMode.selected_token)


func test_damage_targeting_clears_reposition_preview() -> void:
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return true)
	DebugMode.enabled = true
	var token := Node2D.new()
	add_child_autofree(token)
	_controller.handle_token_click(token)
	assert_true(_controller.is_reposition_preview_active())
	var shortcut := _key(KEY_D)
	shortcut.shift_pressed = true
	assert_true(_controller.try_handle_input(shortcut))
	assert_false(_controller.is_reposition_preview_active())
	assert_null(DebugMode.selected_token)
	assert_true(_controller.is_damage_targeting())


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event

## Tests for [UIPanelManager].
##
## Verifies panel creation, resize registration, and isolated callbacks.
extends GutTest


var _mgr: UIPanelManager = null


func before_each() -> void:
	_mgr = UIPanelManager.new()
	_mgr.name = "TestUIPanelManager"
	add_child(_mgr)


func after_each() -> void:
	if _mgr and is_instance_valid(_mgr):
		_mgr.queue_free()
	_mgr = null


# -----------------------------------------------------------------------
# register_resizable
# -----------------------------------------------------------------------

func test_register_resizable_adds_entry() -> void:
	# Arrange
	var ctrl: Control = Control.new()
	add_child(ctrl)
	# Act
	_mgr.register_resizable(ctrl, &"set_size")
	# Assert
	assert_eq(_mgr._resizable_widgets.size(), 1,
			"Should have one registered widget.")
	assert_eq(_mgr._resizable_widgets[0]["node"], ctrl,
			"Node should match.")
	assert_eq(_mgr._resizable_widgets[0]["method"], &"set_size",
			"Method should match.")
	assert_eq(_mgr._resizable_widgets[0]["only_visible"], false,
			"only_visible should default to false.")
	ctrl.queue_free()


func test_register_resizable_only_visible_flag() -> void:
	# Arrange
	var ctrl: Control = Control.new()
	add_child(ctrl)
	# Act
	_mgr.register_resizable(ctrl, &"set_size", true)
	# Assert
	assert_eq(_mgr._resizable_widgets[0]["only_visible"], true,
			"only_visible should be true when specified.")
	ctrl.queue_free()


# -----------------------------------------------------------------------
# PHASE_NAMES constant
# -----------------------------------------------------------------------

func test_phase_names_contains_all_phases() -> void:
	assert_true(UIPanelManager.PHASE_NAMES.has(Constants.GamePhase.SETUP),
			"Should have SETUP.")
	assert_true(UIPanelManager.PHASE_NAMES.has(Constants.GamePhase.COMMAND),
			"Should have COMMAND.")
	assert_true(UIPanelManager.PHASE_NAMES.has(Constants.GamePhase.SHIP),
			"Should have SHIP.")
	assert_true(UIPanelManager.PHASE_NAMES.has(Constants.GamePhase.SQUADRON),
			"Should have SQUADRON.")
	assert_true(UIPanelManager.PHASE_NAMES.has(Constants.GamePhase.STATUS),
			"Should have STATUS.")


# -----------------------------------------------------------------------
# set_phase_hud_visible
# -----------------------------------------------------------------------

func test_set_phase_hud_visible_null_safe() -> void:
	# Arrange — phase_hud_label is null before initialization
	# Act + Assert — should not error
	_mgr.set_phase_hud_visible(false)
	assert_null(_mgr.phase_hud_label,
			"phase_hud_label should be null before init.")


func test_set_phase_hud_visible_toggles_label() -> void:
	# Arrange
	var label: Label = Label.new()
	label.visible = true
	add_child(label)
	_mgr.phase_hud_label = label
	# Act
	_mgr.set_phase_hud_visible(false)
	# Assert
	assert_false(label.visible, "Label should be hidden.")
	_mgr.set_phase_hud_visible(true)
	assert_true(label.visible, "Label should be visible again.")
	label.queue_free()


# -----------------------------------------------------------------------
# add_ship_to_card_panel — null safety only (no full panel in unit test)
# -----------------------------------------------------------------------

func test_add_ship_to_card_panel_null_data_returns() -> void:
	# Arrange
	var inst: ShipInstance = ShipInstance.new()
	inst.ship_data = null
	# Act + Assert — should not error
	_mgr.rebel_card_panel = null
	_mgr.add_ship_to_card_panel(inst)
	pass_test("No error with null ship_data.")


# -----------------------------------------------------------------------
# handle_quit_escape — without quit_modal
# -----------------------------------------------------------------------

func test_handle_quit_escape_returns_false_without_modal() -> void:
	# Arrange
	_mgr.quit_modal = null
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	# Act
	var result: bool = _mgr.handle_quit_escape(event)
	# Assert
	assert_false(result, "Should return false when quit_modal is null.")


func test_handle_quit_escape_ignores_non_key_event() -> void:
	# Arrange
	var event: InputEventMouseButton = InputEventMouseButton.new()
	# Act
	var result: bool = _mgr.handle_quit_escape(event)
	# Assert
	assert_false(result, "Should return false for non-key event.")

## Test: CommandDialOrderModal
##
## Unit tests for CommandDialOrderModal — queued dial order overlay.
## Rules Reference: UI-022, UI-023.
extends GutTest


var _modal: CommandDialOrderModal = null
var _ship_data: ShipData = null
var _ship: ShipInstance = null


func before_each() -> void:
	_modal = CommandDialOrderModal.new()
	add_child_autofree(_modal)
	_modal.visible = false

	_ship_data = ShipData.new()
	_ship_data.ship_name = "Test Ship"
	_ship_data.hull = 5
	_ship_data.command_value = 2
	_ship_data.max_speed = 3
	_ship_data.shields = {"FRONT": 2, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	_ship_data.defense_tokens = []
	_ship = ShipInstance.create_from_data("test_ship", _ship_data, 2, 0)


# --- open() / close() ---

func test_open_makes_visible() -> void:
	_modal.open(_ship)
	assert_true(_modal.visible,
			"Modal should be visible after open()")


func test_close_hides() -> void:
	_modal.open(_ship)
	_modal.close()
	assert_false(_modal.visible,
			"Modal should be hidden after close()")


func test_is_open_true_when_visible() -> void:
	_modal.open(_ship)
	assert_true(_modal.is_open(),
			"is_open() should return true when modal is visible")


func test_is_open_false_after_close() -> void:
	_modal.open(_ship)
	_modal.close()
	assert_false(_modal.is_open(),
			"is_open() should return false after close()")


# --- History with no spent dials ---

func test_empty_stack_shows_no_crash() -> void:
	_modal.open(_ship)
	# If no dials assigned, the modal should still open without crashing.
	assert_true(_modal.visible,
			"Modal should be visible even with empty stack")


# --- Queued dials ---

func test_queued_dials_shown_in_stack_order() -> void:
	# Assign dials without revealing or spending.
	_ship.command_dial_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.REPAIR], 1)

	_modal.open(_ship)
	assert_true(_modal.visible,
			"Modal should show after assigning dials")
	# The _get_queued_dials method should return the hidden dials.
	var queued: Array[Dictionary] = _modal._get_queued_dials()
	assert_eq(queued.size(), 2,
			"Should have 2 queued dials")
	assert_eq(int(queued[0]["command"]), Constants.CommandType.NAVIGATE,
			"First queued dial should be NAVIGATE (top of stack)")
	assert_eq(int(queued[1]["command"]), Constants.CommandType.REPAIR,
			"Second queued dial should be REPAIR")


func test_ui_shows_icon_entries_for_assigned_dials() -> void:
	# Assign dials, open modal, verify UI has the right children.
	_ship.command_dial_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.REPAIR], 1)

	_modal.open(_ship)
	# The _order_container HBoxContainer should have 2 children (one per dial).
	var container: HBoxContainer = _modal._order_container
	assert_not_null(container,
			"Modal should have an _order_container")
	assert_eq(container.get_child_count(), 2,
			"Order container should have 2 dial entries")


func test_queued_dials_excludes_revealed() -> void:
	# Assign dials, then reveal the top one.
	_ship.command_dial_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.REPAIR], 1)
	_ship.command_dial_stack.reveal_top()

	_modal.open(_ship)
	var queued: Array[Dictionary] = _modal._get_queued_dials()
	assert_eq(queued.size(), 1,
			"Should have 1 queued dial after revealing top")
	assert_eq(int(queued[0]["command"]), Constants.CommandType.REPAIR,
			"Remaining queued dial should be REPAIR")


func test_queued_dials_excludes_spent() -> void:
	# Assign, reveal, spend.
	_ship.command_dial_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.REPAIR], 1)
	_ship.command_dial_stack.reveal_top()
	_ship.command_dial_stack.spend_revealed()

	_modal.open(_ship)
	var queued: Array[Dictionary] = _modal._get_queued_dials()
	assert_eq(queued.size(), 1,
			"Should have 1 queued dial after spending top")
	assert_eq(int(queued[0]["command"]), Constants.CommandType.REPAIR,
			"Remaining queued dial should be REPAIR")


# --- centre_on_screen() ---

func test_centre_on_screen_updates_bottom_centre_offsets() -> void:
	_modal.open(_ship)
	_modal.centre_on_screen(Vector2(1920, 1080))
	var panel_w: float = _modal.custom_minimum_size.x
	assert_almost_eq(_modal.offset_left, - panel_w * 0.5, 1.0,
			"offset_left should be -half panel width")
	assert_almost_eq(_modal.offset_right, panel_w * 0.5, 1.0,
			"offset_right should be +half panel width")
	assert_almost_eq(_modal.offset_bottom, -40.0, 1.0,
			"Modal should be 40px above screen bottom")

## Test: CommandDialPicker
##
## Unit tests for CommandDialPicker — modal for assigning command dials.
## Rules Reference: CP-001–005, UI-005, UI-021.
extends GutTest


var _picker: CommandDialPicker = null
var _ship_data: ShipData = null
var _ship: ShipInstance = null


func before_each() -> void:
	_picker = CommandDialPicker.new()
	add_child_autofree(_picker)
	_picker.visible = false

	_ship_data = ShipData.new()
	_ship_data.ship_name = "Test Cruiser"
	_ship_data.hull = 5
	_ship_data.command_value = 3
	_ship_data.max_speed = 2
	_ship_data.ship_size = Constants.ShipSize.MEDIUM
	_ship_data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	_ship_data.defense_tokens = []
	_ship = ShipInstance.create_from_data("test_cruiser", _ship_data, 2, 0)


# --- open() / close() ---

func test_open_makes_visible() -> void:
	_picker.open(_ship, 1)
	assert_true(_picker.visible,
			"Picker should be visible after open()")


func test_close_hides() -> void:
	_picker.open(_ship, 1)
	_picker.close()
	assert_false(_picker.visible,
			"Picker should be hidden after close()")


func test_is_open_true_when_visible() -> void:
	_picker.open(_ship, 1)
	assert_true(_picker.is_open(),
			"is_open() should return true when picker is visible with a ship")


func test_is_open_false_after_close() -> void:
	_picker.open(_ship, 1)
	_picker.close()
	assert_false(_picker.is_open(),
			"is_open() should return false after close()")


# --- Dials needed ---

func test_round_1_needs_command_value_dials() -> void:
	_picker.open(_ship, 1)
	assert_eq(_picker._dials_needed, 3,
			"Round 1: should need command_value (3) dials (CP-002)")


func test_round_2_needs_one_dial() -> void:
	_picker.open(_ship, 2)
	assert_eq(_picker._dials_needed, 1,
			"Rounds 2+: should need 1 dial (CP-003)")


func test_round_1_cmd_value_1_needs_one() -> void:
	var small_data: ShipData = ShipData.new()
	small_data.ship_name = "Small Ship"
	small_data.hull = 3
	small_data.command_value = 1
	small_data.max_speed = 3
	small_data.shields = {"FRONT": 1, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	small_data.defense_tokens = []
	var small_ship: ShipInstance = ShipInstance.create_from_data(
			"small_ship", small_data, 2, 0)
	_picker.open(small_ship, 1)
	assert_eq(_picker._dials_needed, 1,
			"Command value 1: needs 1 dial even in round 1")


# --- Command selection ---

func test_selecting_commands_adds_to_queue() -> void:
	_picker.open(_ship, 1)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	assert_eq(_picker._queued_commands.size(), 1,
			"Queue should have 1 command after selection")
	assert_eq(_picker._queued_commands[0], Constants.CommandType.NAVIGATE,
			"Queued command should be NAVIGATE")


func test_cannot_exceed_dials_needed() -> void:
	_picker.open(_ship, 2) # Needs 1 dial.
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	_picker._on_command_selected(Constants.CommandType.REPAIR)
	assert_eq(_picker._queued_commands.size(), 1,
			"Should not add more dials than needed")


func test_can_select_same_command_multiple_times() -> void:
	_picker.open(_ship, 1) # Needs 3 dials.
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	assert_eq(_picker._queued_commands.size(), 3,
			"Should allow selecting the same command type multiple times")


# --- Dial removal ---

func test_remove_dial_from_queue() -> void:
	_picker.open(_ship, 1)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	_picker._on_command_selected(Constants.CommandType.REPAIR)
	_picker._on_dial_removed(0)
	assert_eq(_picker._queued_commands.size(), 1,
			"Queue should shrink after removal")
	assert_eq(_picker._queued_commands[0], Constants.CommandType.REPAIR,
			"Remaining command should be REPAIR")


func test_remove_invalid_index_no_crash() -> void:
	_picker.open(_ship, 1)
	_picker._on_dial_removed(-1)
	_picker._on_dial_removed(99)
	assert_eq(_picker._queued_commands.size(), 0,
			"Invalid removal should not crash and queue stays empty")


# --- Confirm button state ---

func test_confirm_disabled_when_incomplete() -> void:
	_picker.open(_ship, 1)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	# Only 1 of 3 needed.
	assert_true(_picker._confirm_button.disabled,
			"Confirm should be disabled when fewer than needed dials queued")


func test_confirm_enabled_when_complete() -> void:
	_picker.open(_ship, 1)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	_picker._on_command_selected(Constants.CommandType.SQUADRON)
	_picker._on_command_selected(Constants.CommandType.REPAIR)
	assert_false(_picker._confirm_button.disabled,
			"Confirm should be enabled when all 3 dials are queued")


func test_confirm_disabled_after_removal() -> void:
	_picker.open(_ship, 1)
	_picker._on_command_selected(Constants.CommandType.NAVIGATE)
	_picker._on_command_selected(Constants.CommandType.SQUADRON)
	_picker._on_command_selected(Constants.CommandType.REPAIR)
	_picker._on_dial_removed(1)
	assert_true(_picker._confirm_button.disabled,
			"Confirm should be disabled after removing a dial")


# --- Confirm emission ---

func test_confirm_emits_signal_and_closes() -> void:
	var received_ship: Array = []
	var received_cmds: Array = []
	var callback: Callable = func(ship: ShipInstance, cmds: Array) -> void:
		received_ship.append(ship)
		received_cmds.append_array(cmds)
	EventBus.command_picker_confirmed.connect(callback)

	_picker.open(_ship, 2) # Needs 1 dial.
	_picker._on_command_selected(Constants.CommandType.CONCENTRATE_FIRE)
	_picker._on_confirm_pressed()

	assert_eq(received_ship.size(), 1,
			"Signal should emit exactly once")
	assert_eq(received_ship[0], _ship,
			"Signal should emit the correct ShipInstance")
	assert_eq(received_cmds.size(), 1,
			"Signal should emit the queued commands")
	assert_eq(int(received_cmds[0]), Constants.CommandType.CONCENTRATE_FIRE,
			"Emitted command should be CONCENTRATE_FIRE")
	assert_false(_picker.visible,
			"Picker should close after confirm")

	EventBus.command_picker_confirmed.disconnect(callback)


# --- COMMAND_CYCLE order ---

func test_command_cycle_order() -> void:
	assert_eq(CommandDialPicker.COMMAND_CYCLE.size(), 4,
			"Should have 4 commands in cycle")
	assert_eq(CommandDialPicker.COMMAND_CYCLE[0], Constants.CommandType.NAVIGATE,
			"Cycle[0] should be NAVIGATE (CP-005)")
	assert_eq(CommandDialPicker.COMMAND_CYCLE[1], Constants.CommandType.SQUADRON,
			"Cycle[1] should be SQUADRON")
	assert_eq(CommandDialPicker.COMMAND_CYCLE[2], Constants.CommandType.CONCENTRATE_FIRE,
			"Cycle[2] should be CONCENTRATE_FIRE")
	assert_eq(CommandDialPicker.COMMAND_CYCLE[3], Constants.CommandType.REPAIR,
			"Cycle[3] should be REPAIR")


# --- centre_on_screen() ---

func test_centre_on_screen_positions_in_middle() -> void:
	_picker.open(_ship, 1)
	_picker.centre_on_screen(Vector2(1920, 1080))
	var expected_x: float = (1920 - _picker.custom_minimum_size.x) * 0.5
	var expected_y: float = (1080 - _picker.custom_minimum_size.y) * 0.5
	assert_almost_eq(_picker.position.x, expected_x, 1.0,
			"Picker should be horizontally centred")
	assert_almost_eq(_picker.position.y, expected_y, 1.0,
			"Picker should be vertically centred")

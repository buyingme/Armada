## Test: CommandDialStack
##
## Unit tests for CommandDialStack — command dial management per ship.
## Rules Reference: CP-001–007, SP-010–012, CM-007.
extends GutTest


var _stack: CommandDialStack = null
var _saved_log_level: GameLogger.Level = GameLogger.Level.DEBUG


func before_each() -> void:
	_stack = CommandDialStack.create(3)
	_saved_log_level = GameLogger.min_level


func after_each() -> void:
	GameLogger.min_level = _saved_log_level


# --- Factory / create() ---

func test_create_sets_command_value() -> void:
	assert_eq(_stack.command_value, 3,
			"command_value should equal the value passed to create()")


func test_create_starts_with_empty_stack() -> void:
	assert_eq(_stack.get_dial_count(), 0,
			"New stack should have zero dials")


func test_create_starts_with_no_hidden() -> void:
	assert_eq(_stack.get_hidden_count(), 0,
			"New stack should have zero hidden dials")


func test_create_starts_with_empty_history() -> void:
	var history: Array[Dictionary] = _stack.get_spent_history()
	assert_eq(history.size(), 0,
			"New stack should have no spent history")


# --- get_dials_needed() ---

func test_get_dials_needed_empty_stack_equals_command_value() -> void:
	assert_eq(_stack.get_dials_needed(), 3,
			"Empty stack: should need command_value dials (CP-002)")


func test_get_dials_needed_full_stack_equals_zero() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	assert_eq(_stack.get_dials_needed(), 0,
			"Full stack: should need 0 dials")


func test_get_dials_needed_after_spend_equals_one() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	_stack.reveal_top()
	_stack.spend_revealed()
	assert_eq(_stack.get_dials_needed(), 1,
			"After spending 1 of 3: should need 1 dial")


func test_get_dials_needed_cmd_value_1_empty() -> void:
	var small_stack: CommandDialStack = CommandDialStack.create(1)
	assert_eq(small_stack.get_dials_needed(), 1,
			"Command value 1 empty stack needs 1 dial")


# --- assign_dials() ---

func test_assign_dials_round_1_accepts_correct_count() -> void:
	var result: bool = _stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			 Constants.CommandType.SQUADRON,
			 Constants.CommandType.REPAIR], 1)
	assert_true(result, "Should accept 3 dials in round 1 for cmd_value 3")


func test_assign_dials_round_1_rejects_wrong_count() -> void:
	GameLogger.min_level = GameLogger.Level.ERROR
	var result: bool = _stack.assign_dials(
			[Constants.CommandType.NAVIGATE], 1)
	assert_false(result, "Should reject 1 dial when 3 needed in round 1")


func test_assign_dials_round_2_accepts_one() -> void:
	# First fill round 1 and spend top dial (simulate activation).
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	_stack.reveal_top()
	_stack.spend_revealed()
	var result: bool = _stack.assign_dials(
			[Constants.CommandType.CONCENTRATE_FIRE], 2)
	assert_true(result, "Should accept 1 dial in round 2 after spending")


func test_assign_dials_round_2_rejects_two() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	_stack.reveal_top()
	_stack.spend_revealed()
	GameLogger.min_level = GameLogger.Level.ERROR
	var result: bool = _stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			 Constants.CommandType.REPAIR], 2)
	assert_false(result, "Should reject 2 dials when only 1 needed in round 2")


func test_assign_dials_adds_to_bottom() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	var dials: Array[Dictionary] = _stack.get_all_dials()
	assert_eq(int(dials[0]["command"]), Constants.CommandType.NAVIGATE,
			"First assigned dial should be at top (index 0)")
	assert_eq(int(dials[2]["command"]), Constants.CommandType.REPAIR,
			"Last assigned dial should be at bottom (index 2)")


func test_assign_dials_new_go_after_existing() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	_stack.reveal_top()
	_stack.spend_revealed()
	_stack.assign_dials([Constants.CommandType.CONCENTRATE_FIRE], 2)
	var dials: Array[Dictionary] = _stack.get_all_dials()
	assert_eq(dials.size(), 3,
			"Should have 3 dials after round-1 spend + round-2 assign")
	assert_eq(int(dials[2]["command"]), Constants.CommandType.CONCENTRATE_FIRE,
			"Round 2 dial should be at bottom (CP-004)")


func test_assign_dials_sets_state_hidden() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	var dials: Array[Dictionary] = s1.get_all_dials()
	assert_eq(dials[0]["state"], CommandDialStack.STATE_HIDDEN,
			"New dials should be in hidden state")


func test_assign_dials_records_round() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	var dials: Array[Dictionary] = s1.get_all_dials()
	assert_eq(int(dials[0]["round"]), 1,
			"Dial should record the round it was assigned")


# --- reveal_top() ---

func test_reveal_top_changes_state() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.SQUADRON], 1)
	var dial: Dictionary = s1.reveal_top()
	assert_eq(dial["state"], CommandDialStack.STATE_REVEALED,
			"Revealed dial should have state 'revealed' (SP-010)")


func test_reveal_top_returns_command() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.REPAIR], 1)
	var dial: Dictionary = s1.reveal_top()
	assert_eq(int(dial["command"]), Constants.CommandType.REPAIR,
			"Revealed dial should have correct command type")


func test_reveal_top_empty_stack_returns_empty() -> void:
	GameLogger.min_level = GameLogger.Level.ERROR
	var dial: Dictionary = _stack.reveal_top()
	assert_true(dial.is_empty(),
			"Revealing from empty stack should return empty dict")


func test_reveal_top_already_revealed_returns_empty() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	s1.reveal_top()
	GameLogger.min_level = GameLogger.Level.ERROR
	var second: Dictionary = s1.reveal_top()
	assert_true(second.is_empty(),
			"Should not re-reveal an already revealed dial")


func test_reveal_top_does_not_remove_dial() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	s1.reveal_top()
	assert_eq(s1.get_dial_count(), 1,
			"Revealing should not remove the dial from the stack")


# --- spend_revealed() ---

func test_spend_revealed_removes_dial() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	s1.reveal_top()
	var spent: Dictionary = s1.spend_revealed()
	assert_false(spent.is_empty(),
			"Should return the spent dial")
	assert_eq(s1.get_dial_count(), 0,
			"Stack should be empty after spending the only dial")


func test_spend_revealed_adds_to_history() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.SQUADRON], 1)
	s1.reveal_top()
	s1.spend_revealed()
	var history: Array[Dictionary] = s1.get_spent_history()
	assert_eq(history.size(), 1,
			"Spent history should have 1 entry (CM-007)")
	assert_eq(int(history[0]["command"]), Constants.CommandType.SQUADRON,
			"History entry should record correct command")
	assert_eq(int(history[0]["round"]), 1,
			"History entry should record correct round")


func test_spend_revealed_not_revealed_returns_empty() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	# Don't reveal first.
	GameLogger.min_level = GameLogger.Level.ERROR
	var spent: Dictionary = s1.spend_revealed()
	assert_true(spent.is_empty(),
			"Should not spend a hidden dial")


func test_spend_revealed_empty_returns_empty() -> void:
	GameLogger.min_level = GameLogger.Level.ERROR
	var spent: Dictionary = _stack.spend_revealed()
	assert_true(spent.is_empty(),
			"Cannot spend from empty stack")


# --- get_display_state() ---

func test_get_display_state_empty() -> void:
	var state: Dictionary = _stack.get_display_state()
	assert_eq(state["hidden_dials"].size(), 0,
			"Empty stack has no hidden dials")
	assert_eq(int(state["top_command"]), -1,
			"Empty stack has no top command")


func test_get_display_state_with_hidden_dials() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.REPAIR,
		Constants.CommandType.SQUADRON], 1)
	var state: Dictionary = _stack.get_display_state()
	assert_eq(state["hidden_dials"].size(), 3,
			"Should show 3 hidden dials")
	assert_eq(int(state["top_command"]), Constants.CommandType.NAVIGATE,
			"Top command should be NAVIGATE")
	assert_true(state["revealed"].is_empty(),
			"No revealed dial before reveal_top()")


func test_get_display_state_with_revealed() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	s1.reveal_top()
	var state: Dictionary = s1.get_display_state()
	assert_false(state["revealed"].is_empty(),
			"Should have a revealed dial after reveal_top()")
	assert_eq(int(state["revealed"]["command"]), Constants.CommandType.NAVIGATE,
			"Revealed command should be NAVIGATE")


func test_get_display_state_spent_marker_after_spend() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.REPAIR], 1)
	s1.reveal_top()
	s1.spend_revealed()
	var state: Dictionary = s1.get_display_state()
	assert_false(state["spent_marker"].is_empty(),
			"Should have a spent marker after spending")
	assert_eq(int(state["spent_marker"]["command"]), Constants.CommandType.REPAIR,
			"Spent marker command should be REPAIR")


# --- peek_top() / get_top_command() ---

func test_peek_top_empty() -> void:
	assert_true(_stack.peek_top().is_empty(),
			"peek_top on empty stack returns empty dict")


func test_peek_top_returns_first_dial() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.CONCENTRATE_FIRE], 1)
	var top: Dictionary = s1.peek_top()
	assert_eq(int(top["command"]), Constants.CommandType.CONCENTRATE_FIRE,
			"peek_top should return the first dial")


func test_get_top_command_empty() -> void:
	assert_eq(_stack.get_top_command(), -1,
			"get_top_command on empty returns -1")


func test_get_top_command_returns_first() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	assert_eq(s1.get_top_command(), Constants.CommandType.NAVIGATE,
			"get_top_command should return the top dial's command")


# --- get_revealed_dial() ---

func test_get_revealed_dial_none() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	assert_true(s1.get_revealed_dial().is_empty(),
			"No revealed dial before reveal_top()")


func test_get_revealed_dial_after_reveal() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	s1.reveal_top()
	var revealed: Dictionary = s1.get_revealed_dial()
	assert_eq(int(revealed["command"]), Constants.CommandType.NAVIGATE,
			"get_revealed_dial should return the revealed entry")


# --- clear() ---

func test_clear_removes_all_dials() -> void:
	var s1: CommandDialStack = CommandDialStack.create(1)
	s1.assign_dials([Constants.CommandType.NAVIGATE], 1)
	s1.clear()
	assert_eq(s1.get_dial_count(), 0,
			"clear() should remove all dials")


# --- serialize() / deserialize() ---

func test_serialize_round_trip() -> void:
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	_stack.reveal_top()
	_stack.spend_revealed()

	var data: Dictionary = _stack.serialize()
	var restored: CommandDialStack = CommandDialStack.deserialize(data)
	assert_eq(restored.command_value, 3,
			"Deserialized command_value should match")
	assert_eq(restored.get_dial_count(), 2,
			"Deserialized dial count should match (3-1 spent)")
	assert_eq(restored.get_spent_history().size(), 1,
			"Deserialized spent history should have 1 entry")


# --- Multi-round workflow ---

func test_full_three_round_workflow() -> void:
	# Round 1: assign 3 dials.
	_stack.assign_dials([
		Constants.CommandType.NAVIGATE,
		Constants.CommandType.SQUADRON,
		Constants.CommandType.REPAIR], 1)
	assert_eq(_stack.get_hidden_count(), 3, "3 hidden after round 1 assign")

	# Ship phase round 1: reveal and spend top.
	var r1: Dictionary = _stack.reveal_top()
	assert_eq(int(r1["command"]), Constants.CommandType.NAVIGATE,
			"Round 1 top should be NAVIGATE")
	_stack.spend_revealed()
	assert_eq(_stack.get_dial_count(), 2, "2 dials after spend")

	# Round 2: assign 1 new dial.
	_stack.assign_dials([Constants.CommandType.CONCENTRATE_FIRE], 2)
	assert_eq(_stack.get_dial_count(), 3, "3 dials after round 2 assign")
	assert_eq(_stack.get_hidden_count(), 3, "All 3 hidden")

	# Ship phase round 2: reveal and spend top.
	var r2: Dictionary = _stack.reveal_top()
	assert_eq(int(r2["command"]), Constants.CommandType.SQUADRON,
			"Round 2 top should be SQUADRON (from round 1)")
	_stack.spend_revealed()
	assert_eq(_stack.get_dial_count(), 2, "2 dials after round 2 spend")

	# Round 3: assign 1 new dial.
	_stack.assign_dials([Constants.CommandType.NAVIGATE], 3)
	assert_eq(_stack.get_dial_count(), 3, "3 dials after round 3 assign")

	# Verify spent history tracks all spent dials.
	assert_eq(_stack.get_spent_history().size(), 2,
			"Spent history should have 2 entries after 2 rounds of spending")


# ---------------------------------------------------------------------------
# unreveal_top
# ---------------------------------------------------------------------------

func test_unreveal_top_returns_empty_on_empty_stack() -> void:
	var stack: CommandDialStack = CommandDialStack.create(1)
	var result: Dictionary = stack.unreveal_top()
	assert_true(result.is_empty(),
			"unreveal_top on empty stack should return empty dict")


func test_unreveal_top_returns_empty_when_hidden() -> void:
	var stack: CommandDialStack = CommandDialStack.create(1)
	stack.assign_dials([Constants.CommandType.NAVIGATE], 1)
	var result: Dictionary = stack.unreveal_top()
	assert_true(result.is_empty(),
			"unreveal_top on hidden dial should return empty dict")


func test_unreveal_top_sets_state_back_to_hidden() -> void:
	var stack: CommandDialStack = CommandDialStack.create(1)
	stack.assign_dials([Constants.CommandType.NAVIGATE], 1)
	stack.reveal_top()
	var result: Dictionary = stack.unreveal_top()
	assert_false(result.is_empty(),
			"unreveal_top should return the dial")
	assert_eq(result["state"], CommandDialStack.STATE_HIDDEN,
			"Dial state should be back to hidden")
	assert_eq(stack.get_hidden_count(), 1,
			"Hidden count should be 1 after unreveal")
	assert_true(stack.get_revealed_dial().is_empty(),
			"get_revealed_dial should return empty after unreveal")

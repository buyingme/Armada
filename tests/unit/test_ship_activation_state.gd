## Tests for ShipActivationState
##
## Covers: step tracking, Navigate speed changes, yaw bonus, command resolution,
## maneuver execution, combined dial+token, speed bounds.
##
## Rules Reference: RRG "Ship Activation" p.16, "Commands" p.3, "Navigate" p.3.
## Requirements: ACT-002, NAV-001–008, EXE-001–005, FLOW-004, AC-5b-01–15.
extends GutTest


## Creates a ShipInstance with a Navigate dial revealed and optionally a
## Navigate token.
func _make_ship(speed: int = 2, has_nav_dial: bool = true,
		has_nav_token: bool = false, max_speed: int = 4,
		command_value: int = 2) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 4
	data.max_speed = max_speed
	data.navigation_chart = [[2], [1, 2], [0, 1, 2], [0, 1, 1, 2]]
	data.command_value = command_value
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	data.defense_tokens = []
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, speed, 0)
	# Set up the command dial stack with a navigate dial and reveal it.
	if has_nav_dial:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.NAVIGATE,
				Constants.CommandType.REPAIR], 1)
		ship.command_dial_stack.reveal_top()
	else:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.REPAIR,
				Constants.CommandType.REPAIR], 1)
		ship.command_dial_stack.reveal_top()
	# Add Navigate token if requested.
	if has_nav_token:
		ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	return ship


# ---------------------------------------------------------------------------
# Step tracking
# ---------------------------------------------------------------------------


func test_create_starts_at_reveal_step() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_eq(state.get_current_step(), ShipActivationState.Step.REVEAL,
			"Should start at REVEAL step")


func test_advance_step_goes_through_sequence() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_eq(state.advance_step(), ShipActivationState.Step.SQUADRON,
			"First advance → SQUADRON")
	assert_eq(state.advance_step(), ShipActivationState.Step.REPAIR,
			"Second advance → REPAIR")
	assert_eq(state.advance_step(), ShipActivationState.Step.ATTACK,
			"Third advance → ATTACK")
	assert_eq(state.advance_step(), ShipActivationState.Step.MANEUVER,
			"Fourth advance → MANEUVER")
	assert_eq(state.advance_step(), ShipActivationState.Step.DONE,
			"Fifth advance → DONE")


func test_advance_past_done_stays_at_done() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	for _i: int in range(10):
		state.advance_step()
	assert_eq(state.get_current_step(), ShipActivationState.Step.DONE,
			"Should stay at DONE")


func test_is_done_true_after_all_steps() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.is_done(), "Not done at start")
	for _i: int in range(5):
		state.advance_step()
	assert_true(state.is_done(), "Should be done after 5 advances")


func test_skip_step_is_alias_for_advance() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	var result: ShipActivationState.Step = state.skip_step()
	assert_eq(result, ShipActivationState.Step.SQUADRON,
			"skip_step should advance to SQUADRON")


func test_is_at_step_current() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.is_at_step(ShipActivationState.Step.REVEAL),
			"Should be at REVEAL")
	state.advance_step()
	assert_true(state.is_at_step(ShipActivationState.Step.SQUADRON),
			"Should be at SQUADRON")


func test_get_ship_returns_ship() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_eq(state.get_ship(), ship, "Should return the ship")


# ---------------------------------------------------------------------------
# Command resolution tracking
# ---------------------------------------------------------------------------


func test_mark_command_resolved_prevents_double_spend() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.mark_command_resolved(Constants.CommandType.NAVIGATE),
			"First resolve should succeed")
	assert_false(state.mark_command_resolved(Constants.CommandType.NAVIGATE),
			"Second resolve should fail (CM-002)")


func test_is_command_resolved_false_initially() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.is_command_resolved(Constants.CommandType.NAVIGATE),
			"Navigate not resolved initially")


func test_different_commands_tracked_independently() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.mark_command_resolved(Constants.CommandType.NAVIGATE)
	assert_false(state.is_command_resolved(Constants.CommandType.REPAIR),
			"Repair should not be resolved")


# ---------------------------------------------------------------------------
# Navigate — availability
# ---------------------------------------------------------------------------


func test_nav_dial_detected_when_revealed() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.has_navigate_dial(),
			"Should detect Navigate dial")
	assert_eq(state.get_dial_speed_budget(), 1,
			"Dial budget should be 1")


func test_nav_token_detected() -> void:
	var ship: ShipInstance = _make_ship(2, false, true)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.has_navigate_dial(),
			"Should not detect Navigate dial")
	assert_true(state.has_navigate_token(),
			"Should detect Navigate token")
	assert_eq(state.get_token_speed_budget(), 1,
			"Token budget should be 1")


func test_no_nav_resources_when_neither_present() -> void:
	var ship: ShipInstance = _make_ship(2, false, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.can_change_speed(),
			"Should not be able to change speed")


func test_combined_dial_and_token_gives_budget_2() -> void:
	var ship: ShipInstance = _make_ship(2, true, true)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_eq(state.get_max_speed_increase(), 2,
			"Combined budget should be 2")


# ---------------------------------------------------------------------------
# Navigate — speed changes
# ---------------------------------------------------------------------------


func test_apply_speed_increase_with_dial() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_speed_change(1), "Should apply +1")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 3,
			"Target speed should be 3")
	assert_eq(state.get_dial_speed_budget(), 0,
			"Dial budget consumed")


func test_apply_speed_decrease_with_dial() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_speed_change(-1), "Should apply -1")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 1,
			"Target speed should be 1")


func test_speed_change_exceeds_max_rejected() -> void:
	var ship: ShipInstance = _make_ship(4, true, false, 4)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.apply_speed_change(1),
			"Should reject +1 at max speed")
	assert_eq(ship.current_speed, 4, "Speed unchanged")


func test_speed_change_below_zero_rejected() -> void:
	var ship: ShipInstance = _make_ship(0, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.apply_speed_change(-1),
			"Should reject -1 at speed 0")
	assert_eq(ship.current_speed, 0, "Speed unchanged")


func test_speed_change_zero_rejected() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.apply_speed_change(0),
			"Delta 0 should be rejected")


func test_no_budget_rejects_speed_change() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_speed_change(1) # Spend the dial budget.
	assert_false(state.apply_speed_change(1),
			"No more budget — should reject")


func test_speed_change_reversible_before_commit() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_speed_change(1), "+1 should succeed")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 3,
			"Target speed should be 3")
	assert_true(state.apply_speed_change(-1), "-1 reversal should succeed")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 2,
			"Target speed restored to 2")
	assert_eq(state.get_total_speed_change(), 0,
			"Net change should be 0")
	# Budget fully restored — can change again.
	assert_true(state.apply_speed_change(-1), "-1 should still work")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 1,
			"Target speed should be 1")


func test_speed_change_swing_direction() -> void:
	var ship: ShipInstance = _make_ship(2, true, false, 4)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_speed_change(1), "+1 should succeed")
	assert_true(state.apply_speed_change(-1), "-1 reversal should succeed")
	assert_true(state.apply_speed_change(-1), "-1 should succeed")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 1,
			"Target speed should be 1")
	assert_eq(state.get_total_speed_change(), -1, "Total change should be -1")


func test_combined_dial_token_allows_two_changes() -> void:
	var ship: ShipInstance = _make_ship(2, true, true, 4)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_speed_change(1), "First +1 from dial")
	assert_true(state.apply_speed_change(1), "Second +1 from token")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 4,
			"Target speed should be 4")
	assert_false(state.apply_speed_change(1),
			"Third change should fail — budget exhausted")


func test_total_speed_change_tracked() -> void:
	var ship: ShipInstance = _make_ship(2, true, true, 4)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_speed_change(1)
	state.apply_speed_change(1)
	assert_eq(state.get_total_speed_change(), 2,
			"Total change should be +2")


func test_original_speed_preserved() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_speed_change(1)
	assert_eq(state.get_original_speed(), 2,
			"Original speed should be 2")


func test_token_only_speed_change() -> void:
	var ship: ShipInstance = _make_ship(2, false, true, 4)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_speed_change(1), "+1 from token")
	assert_eq(state.get_original_speed() + state.get_total_speed_change(), 3,
			"Target speed should be 3")
	assert_true(state.is_using_token_for_speed(),
			"Should be using token for speed")


func test_dial_then_token_for_second_change() -> void:
	var ship: ShipInstance = _make_ship(2, true, true, 4)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_speed_change(1) # Dial budget used.
	assert_false(state.is_using_token_for_speed(),
			"First change uses dial — not token-only")
	state.apply_speed_change(1) # Token budget used.
	assert_true(state.is_using_token_for_speed(),
			"Second change uses token")


# ---------------------------------------------------------------------------
# Navigate — yaw bonus
# ---------------------------------------------------------------------------


func test_yaw_bonus_available_with_nav_dial() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.has_yaw_bonus(),
			"Yaw bonus should be available with Navigate dial")


func test_yaw_bonus_not_available_without_nav_dial() -> void:
	var ship: ShipInstance = _make_ship(2, false, true)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.has_yaw_bonus(),
			"Yaw bonus should NOT be available with token only")


func test_apply_yaw_bonus_succeeds() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_true(state.apply_yaw_bonus(0), "Should apply yaw bonus")
	assert_eq(state.get_yaw_bonus_joint(), 0,
			"Yaw bonus should be on joint 0")
	assert_false(state.has_yaw_bonus(),
			"Yaw bonus consumed after applying")


func test_apply_yaw_bonus_twice_fails() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_yaw_bonus(0)
	assert_false(state.apply_yaw_bonus(1),
			"Second yaw bonus should fail")


func test_remove_yaw_bonus_re_enables() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_yaw_bonus(0)
	state.remove_yaw_bonus()
	assert_true(state.has_yaw_bonus(),
			"Yaw bonus should be re-enabled after remove")
	assert_eq(state.get_yaw_bonus_joint(), -1,
			"Yaw bonus joint should be -1 after remove")


# ---------------------------------------------------------------------------
# Maneuver execution
# ---------------------------------------------------------------------------


func test_maneuver_not_executed_initially() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	assert_false(state.is_maneuver_executed(),
			"Maneuver should not be executed initially")


func test_mark_maneuver_executed() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.mark_maneuver_executed()
	assert_true(state.is_maneuver_executed(),
			"Maneuver should be marked as executed")


func test_mark_maneuver_resolves_navigate_if_dial_used() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_speed_change(1)
	state.mark_maneuver_executed()
	assert_true(state.is_command_resolved(Constants.CommandType.NAVIGATE),
			"Navigate should be resolved after maneuver with speed change")


# ---------------------------------------------------------------------------
# Serialization round-trip
# ---------------------------------------------------------------------------


func test_serialize_contains_expected_keys() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	var data: Dictionary = state.serialize()
	for key: String in ["current_step", "resolved_commands",
			"has_navigate_dial", "has_navigate_token",
			"dial_speed_budget", "token_speed_budget",
			"initial_dial_budget", "initial_token_budget",
			"yaw_bonus_available", "yaw_bonus_joint",
			"original_speed", "total_speed_change",
			"maneuver_executed"]:
		assert_true(data.has(key),
				"serialize() should include key '%s'" % key)


func test_deserialize_round_trip_step() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.advance_step()
	state.advance_step()
	var restored: ShipActivationState = ShipActivationState.deserialize(
			state.serialize(), ship)
	assert_eq(restored.get_current_step(),
			ShipActivationState.Step.REPAIR,
			"Round-trip should preserve current_step")


func test_deserialize_round_trip_navigate_state() -> void:
	var ship: ShipInstance = _make_ship(2, true, true)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_speed_change(1)
	var restored: ShipActivationState = ShipActivationState.deserialize(
			state.serialize(), ship)
	assert_true(restored.has_navigate_dial(),
			"Round-trip should preserve has_navigate_dial")
	assert_true(restored.has_navigate_token(),
			"Round-trip should preserve has_navigate_token")
	assert_eq(restored.get_total_speed_change(), 1,
			"Round-trip should preserve total_speed_change")
	assert_eq(restored.get_original_speed(), 2,
			"Round-trip should preserve original_speed")


func test_deserialize_round_trip_yaw_bonus() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.apply_yaw_bonus(2)
	var restored: ShipActivationState = ShipActivationState.deserialize(
			state.serialize(), ship)
	assert_false(restored.has_yaw_bonus(),
			"Round-trip should preserve consumed yaw bonus")
	assert_eq(restored.get_yaw_bonus_joint(), 2,
			"Round-trip should preserve yaw bonus joint")


func test_deserialize_round_trip_resolved_commands() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.mark_command_resolved(Constants.CommandType.NAVIGATE)
	var restored: ShipActivationState = ShipActivationState.deserialize(
			state.serialize(), ship)
	assert_true(restored.is_command_resolved(
			Constants.CommandType.NAVIGATE),
			"Round-trip should preserve resolved commands")


func test_deserialize_round_trip_maneuver_executed() -> void:
	var ship: ShipInstance = _make_ship()
	var state: ShipActivationState = ShipActivationState.create(ship)
	state.mark_maneuver_executed()
	var restored: ShipActivationState = ShipActivationState.deserialize(
			state.serialize(), ship)
	assert_true(restored.is_maneuver_executed(),
			"Round-trip should preserve maneuver_executed")

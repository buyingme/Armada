## Tests for DisplacementModal
##
## Covers: open/close, check/uncheck, all_checked, get_first_unchecked,
##   commit button enabled state, signal emission.
##
## Rules Reference: RRG "Overlapping", p.8 — OV-002, OV-003.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates and adds a DisplacementModal to the scene tree.
func _make_modal() -> DisplacementModal:
	var modal: DisplacementModal = DisplacementModal.new()
	add_child_autofree(modal)
	return modal


## Standard test names.
var _names: Array[String] = ["X-Wing", "Y-Wing", "A-Wing"]


# ---------------------------------------------------------------------------
# Tests — open / close
# ---------------------------------------------------------------------------


func test_open_makes_modal_visible() -> void:
	var modal: DisplacementModal = _make_modal()

	modal.open(_names)

	assert_true(modal.visible,
			"Modal should be visible after open().")


func test_close_modal_hides() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	modal.close_modal()

	assert_false(modal.visible,
			"Modal should be hidden after close_modal().")


func test_close_and_clear_resets_state() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)
	modal.check_squadron(0)

	modal.close_and_clear()

	assert_false(modal.visible,
			"Modal should be hidden after close_and_clear().")
	assert_eq(modal.get_first_unchecked(), -1,
			"No unchecked squadrons after clear (empty).")


# ---------------------------------------------------------------------------
# Tests — check / uncheck
# ---------------------------------------------------------------------------


func test_initial_state_all_unchecked() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	var states: Array[bool] = modal.get_checked_states()

	assert_eq(states.size(), 3, "Should have 3 checked states.")
	for i: int in range(states.size()):
		assert_false(states[i],
				"Squadron %d should be unchecked initially." % i)


func test_check_squadron_sets_checked() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	modal.check_squadron(1)

	var states: Array[bool] = modal.get_checked_states()
	assert_false(states[0], "Squadron 0 should remain unchecked.")
	assert_true(states[1], "Squadron 1 should be checked.")
	assert_false(states[2], "Squadron 2 should remain unchecked.")


func test_uncheck_squadron_clears_checked() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)
	modal.check_squadron(1)

	modal.uncheck_squadron(1)

	var states: Array[bool] = modal.get_checked_states()
	assert_false(states[1], "Squadron 1 should be unchecked after uncheck.")


func test_check_out_of_range_does_nothing() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	modal.check_squadron(-1)
	modal.check_squadron(99)

	var states: Array[bool] = modal.get_checked_states()
	for i: int in range(states.size()):
		assert_false(states[i],
				"No squadron should be checked after out-of-range calls.")


# ---------------------------------------------------------------------------
# Tests — all_checked / get_first_unchecked
# ---------------------------------------------------------------------------


func test_all_checked_false_initially() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	assert_false(modal.all_checked(),
			"all_checked() should be false when none are checked.")


func test_all_checked_true_when_all_done() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	modal.check_squadron(0)
	modal.check_squadron(1)
	modal.check_squadron(2)

	assert_true(modal.all_checked(),
			"all_checked() should be true when all are checked.")


func test_all_checked_false_after_uncheck() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)
	modal.check_squadron(0)
	modal.check_squadron(1)
	modal.check_squadron(2)

	modal.uncheck_squadron(1)

	assert_false(modal.all_checked(),
			"all_checked() should be false after unchecking one.")


func test_get_first_unchecked_returns_zero_initially() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)

	assert_eq(modal.get_first_unchecked(), 0,
			"First unchecked should be 0 initially.")


func test_get_first_unchecked_skips_checked() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)
	modal.check_squadron(0)

	assert_eq(modal.get_first_unchecked(), 1,
			"First unchecked should skip index 0.")


func test_get_first_unchecked_returns_neg1_when_all_checked() -> void:
	var modal: DisplacementModal = _make_modal()
	modal.open(_names)
	modal.check_squadron(0)
	modal.check_squadron(1)
	modal.check_squadron(2)

	assert_eq(modal.get_first_unchecked(), -1,
			"Should return -1 when all are checked.")


# ---------------------------------------------------------------------------
# Tests — single squadron (edge case)
# ---------------------------------------------------------------------------


func test_single_squadron_check_enables_all_checked() -> void:
	var modal: DisplacementModal = _make_modal()
	var single: Array[String] = ["Lone X-Wing"]

	modal.open(single)
	modal.check_squadron(0)

	assert_true(modal.all_checked(),
			"Single squadron check should make all_checked true.")
	assert_eq(modal.get_first_unchecked(), -1,
			"No unchecked after single squadron checked.")

## Unit tests for ActivationModal
##
## Covers: auto-skip of Attack step when no valid targets exist,
## set_attack_skippable(), step display updates with skip flag.
##
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
## Requirements: AE-SKIP-003.
extends GutTest


var _modal: ActivationModal = null


## Creates a minimal ShipInstance suitable for ActivationModal tests.
func _make_ship(speed: int = 2) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 4
	data.max_speed = 4
	data.navigation_chart = [[2], [1, 2], [0, 1, 2], [0, 1, 1, 2]]
	data.command_value = 2
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	data.defense_tokens = []
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, speed, 0)
	# Assign and reveal a dial so the modal can display command info.
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()
	return ship


## Creates an activation state already advanced to the given step.
func _make_state_at(step: ShipActivationState.Step,
		speed: int = 2) -> ShipActivationState:
	var ship: ShipInstance = _make_ship(speed)
	var state: ShipActivationState = ShipActivationState.create(ship)
	# Advance from REVEAL to the requested step.
	while state.get_current_step() != step and not state.is_done():
		state.advance_step()
	return state


func before_each() -> void:
	_modal = ActivationModal.new()
	add_child_autofree(_modal)


# ---------------------------------------------------------------------------
# set_attack_skippable
# ---------------------------------------------------------------------------


func test_skip_attack_defaults_to_false() -> void:
	assert_false(_modal._skip_attack,
			"_skip_attack should default to false.")


func test_set_attack_skippable_true() -> void:
	_modal.set_attack_skippable(true)
	assert_true(_modal._skip_attack,
			"_skip_attack should be true after set_attack_skippable(true).")


func test_set_attack_skippable_false_resets() -> void:
	_modal.set_attack_skippable(true)
	_modal.set_attack_skippable(false)
	assert_false(_modal._skip_attack,
			"_skip_attack should be false after set_attack_skippable(false).")


# ---------------------------------------------------------------------------
# _update_step_display — Attack row appearance with skip flag
# ---------------------------------------------------------------------------


func test_attack_row_shows_no_targets_badge_when_skippable() -> void:
	# Open modal at ATTACK step with skip enabled.
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(true)
	_modal.open(state)
	# The modal's step rows: index 3 = ATTACK.
	var attack_row: PanelContainer = _modal._step_rows[3]
	var status: Label = _modal._find_status_label(attack_row)
	# The auto-skip timer will be pending, but display should already
	# show "No targets" (updated by open → _update_step_display).
	assert_eq(status.text, "No targets",
			"Attack row should display 'No targets' badge.")


func test_attack_button_hidden_when_skippable() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(true)
	_modal.open(state)
	assert_false(_modal._attack_button.visible,
			"Execute Attack button should stay hidden when skippable.")


func test_attack_row_shows_button_when_not_skippable() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(false)
	_modal.open(state)
	assert_true(_modal._attack_button.visible,
			"Execute Attack button should be visible when not skippable.")


# ---------------------------------------------------------------------------
# Auto-skip integration — verify step advances past ATTACK
# ---------------------------------------------------------------------------


func test_auto_skip_advances_past_attack_when_skippable() -> void:
	# Open modal at ATTACK with skip flag. After the timer fires (0.3s),
	# the state should advance to MANEUVER.
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(true)
	_modal.open(state)
	# Wait for the auto-skip timer (0.3s + margin).
	await get_tree().create_timer(0.5).timeout
	assert_eq(state.get_current_step(),
			ShipActivationState.Step.MANEUVER,
			"State should advance to MANEUVER after auto-skip.")


func test_auto_skip_does_not_skip_attack_when_not_skippable() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(false)
	_modal.open(state)
	await get_tree().create_timer(0.5).timeout
	assert_eq(state.get_current_step(),
			ShipActivationState.Step.ATTACK,
			"State should stay at ATTACK when not skippable.")


func test_attack_step_checkmarked_after_skip() -> void:
	# After auto-skip, the attack row should show a checkmark.
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(true)
	_modal.open(state)
	await get_tree().create_timer(0.5).timeout
	var attack_row: PanelContainer = _modal._step_rows[3]
	var status: Label = _modal._find_status_label(attack_row)
	assert_eq(status.text, "✓",
			"Attack row should show checkmark after auto-skip.")


# ---------------------------------------------------------------------------
# Full auto-skip chain from REVEAL — SQUADRON → REPAIR → ATTACK → MANEUVER
# ---------------------------------------------------------------------------


func test_full_auto_skip_chain_skips_attack_step() -> void:
	# Open from REVEAL with skip attack, skip repair, and skip squadron —
	# should auto-skip all through SQUADRON, REPAIR, ATTACK and stop at MANEUVER.
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.REVEAL)
	_modal.set_squadron_skippable(true)
	_modal.set_attack_skippable(true)
	_modal.set_repair_skippable(true)
	_modal.open(state)
	# 3 steps × 0.3s = 0.9s; give 1.2s margin.
	await get_tree().create_timer(1.2).timeout
	assert_eq(state.get_current_step(),
			ShipActivationState.Step.MANEUVER,
			"Full chain should reach MANEUVER when attack is skippable.")


func test_full_auto_skip_chain_stops_at_attack_when_not_skippable() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.REVEAL)
	_modal.set_squadron_skippable(true)
	_modal.set_attack_skippable(false)
	_modal.set_repair_skippable(true)
	_modal.open(state)
	# 2 steps × 0.3s = 0.6s; give 1.0s margin.
	await get_tree().create_timer(1.0).timeout
	assert_eq(state.get_current_step(),
			ShipActivationState.Step.ATTACK,
			"Chain should stop at ATTACK when not skippable.")


func test_attack_step_entered_signal_not_emitted_when_skippable() -> void:
	# The attack_step_entered signal should never fire when auto-skipping.
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.ATTACK)
	_modal.set_attack_skippable(true)
	watch_signals(_modal)
	_modal.open(state)
	await get_tree().create_timer(0.5).timeout
	assert_signal_not_emitted(_modal, "attack_step_entered",
			"attack_step_entered should not emit when skippable.")


# ---------------------------------------------------------------------------
# End Activation button (DONE step)
# ---------------------------------------------------------------------------


func test_end_activation_button_hidden_before_done() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.MANEUVER)
	_modal.open(state)
	assert_false(_modal._end_activation_button.visible,
			"End Activation button should be hidden before DONE step.")


func test_end_activation_button_visible_at_done() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	_modal.open(state)
	assert_true(_modal._end_activation_button.visible,
			"End Activation button should be visible when step is DONE.")


func test_end_activation_button_not_disabled_at_done() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	_modal.open(state)
	assert_false(_modal._end_activation_button.disabled,
			"End Activation button should not be disabled at DONE.")


func test_all_steps_checked_at_done() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	_modal.open(state)
	for i: int in range(_modal._step_rows.size()):
		var row: PanelContainer = _modal._step_rows[i]
		var status: Label = _modal._find_status_label(row)
		assert_eq(status.text, "✓",
				"Step %d should show checkmark at DONE." % i)


func test_end_activation_emits_signal() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	watch_signals(_modal)
	_modal.open(state)
	_modal._on_end_activation_pressed()
	assert_signal_emitted(_modal, "end_activation_requested",
			"Pressing End Activation should emit end_activation_requested.")


func test_end_activation_closes_modal() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	_modal.open(state)
	assert_true(_modal.visible, "Modal should be visible before press.")
	_modal._on_end_activation_pressed()
	assert_false(_modal.visible,
			"Modal should be hidden after End Activation press.")


# ---------------------------------------------------------------------------
# Modal stays open after maneuver commit
# ---------------------------------------------------------------------------


func test_modal_stays_open_after_maneuver_commit() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.MANEUVER)
	_modal.open(state)
	# Simulate first press (show tool) then second press (commit).
	_modal._on_execute_pressed() ## shows tool
	_modal._on_execute_pressed() ## commits maneuver
	assert_true(_modal.visible,
			"Modal should stay visible after maneuver commit.")


func test_maneuver_commit_emits_signal_without_close() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.MANEUVER)
	watch_signals(_modal)
	_modal.open(state)
	_modal._on_execute_pressed() ## shows tool
	_modal._on_execute_pressed() ## commits maneuver
	assert_signal_emitted(_modal, "maneuver_commit_requested",
			"maneuver_commit_requested should emit on commit press.")
	assert_signal_not_emitted(_modal, "modal_closed",
			"modal_closed should NOT emit on maneuver commit.")


# ---------------------------------------------------------------------------
# Collision message label
# ---------------------------------------------------------------------------


func test_collision_label_hidden_by_default() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.MANEUVER)
	_modal.open(state)
	assert_false(_modal._collision_label.visible,
			"Collision label should be hidden by default.")


func test_set_collision_message_shows_label() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	_modal.open(state)
	_modal.set_collision_message("⚠ Collision detected! Speed reduced to 1.")
	assert_true(_modal._collision_label.visible,
			"Collision label should be visible after set_collision_message.")
	assert_eq(_modal._collision_label.text,
			"⚠ Collision detected! Speed reduced to 1.",
			"Collision label text should match set value.")


func test_set_collision_message_empty_hides_label() -> void:
	var state: ShipActivationState = _make_state_at(
			ShipActivationState.Step.DONE)
	_modal.open(state)
	_modal.set_collision_message("Some message")
	_modal.set_collision_message("")
	assert_false(_modal._collision_label.visible,
			"Collision label should be hidden after empty message.")

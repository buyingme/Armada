## Tests for ManeuverToolState
##
## Covers: setup, joint clicks, segment transforms, type lookups.
## Uses the CR90 Corvette A navigation chart as reference data.
##
## Rules Reference: RRG "Maneuver Tool" p.10; MT-M-001–006, AC-01–03, AC-12.
extends GutTest


## CR90 navigation chart (same as in test_maneuver_calculator.gd).
var CR90_NAV: Array = [[2], [1, 2], [0, 1, 2], [0, 1, 1, 2]]

## Reusable instance.
var _state: ManeuverToolState = null


func before_each() -> void:
	_state = ManeuverToolState.new()


# ---------------------------------------------------------------------------
# setup / getters
# ---------------------------------------------------------------------------

func test_setup_sets_speed_and_ship_size() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_speed(), 3, "Speed should be 3 after setup")
	assert_eq(_state.get_ship_size(), Constants.ShipSize.SMALL,
			"Ship size should be SMALL")


func test_setup_clamps_speed_to_max_joints() -> void:
	_state.setup(10, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_speed(), ManeuverToolState.MAX_JOINTS,
			"Speed should clamp to MAX_JOINTS")


func test_setup_resets_joint_clicks() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_right(0)
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	var clicks: Array[int] = _state.get_joint_clicks()
	assert_eq(clicks, [0, 0, 0, 0] as Array[int],
			"Joints should reset on setup")


# ---------------------------------------------------------------------------
# is_joint_active
# ---------------------------------------------------------------------------

func test_is_joint_active_speed2_joint0_true() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	assert_true(_state.is_joint_active(0),
			"Joint 0 should be active at speed 2")


func test_is_joint_active_speed2_joint2_false() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	assert_false(_state.is_joint_active(2),
			"Joint 2 should be inactive at speed 2")


func test_is_joint_active_negative_index_false() -> void:
	_state.setup(4, CR90_NAV, Constants.ShipSize.SMALL)
	assert_false(_state.is_joint_active(-1),
			"Negative joint index should be inactive")


# ---------------------------------------------------------------------------
# click_joint_left / click_joint_right
# ---------------------------------------------------------------------------

func test_click_joint_right_applies_correctly() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	var result: bool = _state.click_joint_right(1)
	assert_true(result, "Clicking right on joint 1 should succeed")
	assert_eq(_state.get_joint_clicks()[1], 1,
			"Joint 1 should be at +1 click")


func test_click_joint_left_applies_correctly() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	var result: bool = _state.click_joint_left(0)
	assert_true(result, "Clicking left on joint 0 should succeed")
	assert_eq(_state.get_joint_clicks()[0], -1,
			"Joint 0 should be at -1 click")


func test_click_joint_rejects_exceeding_max_yaw() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	# Joint 0 at speed 2 has max yaw = 1 (CR90)
	_state.click_joint_right(0)
	var result: bool = _state.click_joint_right(0)
	assert_false(result, "Exceeding max yaw should be rejected")
	assert_eq(_state.get_joint_clicks()[0], 1,
			"Click value should remain at 1")


func test_click_joint_rejects_beyond_absolute_max() -> void:
	# Joint 1 at speed 2 has max yaw = 2 (CR90)
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_left(1)
	_state.click_joint_left(1)
	var result: bool = _state.click_joint_left(1)
	assert_false(result, "Exceeding ±2 absolute max should be rejected")


func test_click_inactive_joint_returns_false() -> void:
	_state.setup(1, CR90_NAV, Constants.ShipSize.SMALL)
	var result: bool = _state.click_joint_right(1)
	assert_false(result, "Clicking inactive joint should be rejected")


func test_click_locked_joint_returns_false() -> void:
	# Speed 4, joint 0 is locked (max yaw = 0) for CR90
	_state.setup(4, CR90_NAV, Constants.ShipSize.SMALL)
	var result: bool = _state.click_joint_right(0)
	assert_false(result, "Clicking locked joint should be rejected")


# ---------------------------------------------------------------------------
# reset_joints
# ---------------------------------------------------------------------------

func test_reset_joints_clears_all_clicks() -> void:
	_state.setup(4, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_right(2)
	_state.click_joint_left(3)
	_state.reset_joints()
	assert_eq(_state.get_joint_clicks(), [0, 0, 0, 0] as Array[int],
			"All clicks should be zeroed after reset")


# ---------------------------------------------------------------------------
# get_active_segment_count
# ---------------------------------------------------------------------------

func test_get_active_segment_count_speed0_is_1() -> void:
	_state.setup(0, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_active_segment_count(), 1,
			"Speed 0 should have 1 segment (root)")


func test_get_active_segment_count_speed2_is_3() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_active_segment_count(), 3,
			"Speed 2 should have 3 segments")


func test_get_active_segment_count_speed4_is_5() -> void:
	_state.setup(4, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_active_segment_count(), 5,
			"Speed 4 should have all 5 segments")


# ---------------------------------------------------------------------------
# get_segment_type
# ---------------------------------------------------------------------------

func test_get_segment_type_index0_is_root() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_segment_type(0), "root",
			"Segment 0 should be root")


func test_get_segment_type_middle_is_segment() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_segment_type(1), "segment",
			"Segment 1 at speed 3 should be segment")


func test_get_segment_type_last_is_segment_end() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.get_segment_type(3), "segment_end",
			"Last active segment should be segment_end")


# ---------------------------------------------------------------------------
# compute_segment_transforms
# ---------------------------------------------------------------------------

func test_compute_segment_transforms_speed0_one_segment() -> void:
	_state.setup(0, CR90_NAV, Constants.ShipSize.SMALL)
	var data: Dictionary = _state.compute_segment_transforms(
			Vector2.ZERO, 0.0)
	assert_eq((data["segments"] as Array).size(), 1,
			"Speed 0 should return 1 segment transform")
	assert_eq((data["joints"] as Array).size(), 0,
			"Speed 0 should return 0 joints")


func test_compute_segment_transforms_speed2_correct_counts() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	var data: Dictionary = _state.compute_segment_transforms(
			Vector2.ZERO, 0.0)
	assert_eq((data["segments"] as Array).size(), 3,
			"Speed 2 should return 3 segment transforms")
	assert_eq((data["joints"] as Array).size(), 2,
			"Speed 2 should return 2 joints")


func test_compute_segment_transforms_straight_moves_forward() -> void:
	_state.setup(1, CR90_NAV, Constants.ShipSize.SMALL)
	var data: Dictionary = _state.compute_segment_transforms(
			Vector2.ZERO, 0.0)
	var segs: Array = data["segments"]
	var seg1: Transform2D = segs[1] as Transform2D
	assert_true(seg1.origin.y < 0.0,
			"Straight segment should move in -Y direction")


func test_compute_segment_transforms_yaw_changes_heading() -> void:
	# Speed 2, joint 0 max 1 click for CR90 → click right once
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_right(0)
	var data: Dictionary = _state.compute_segment_transforms(
			Vector2.ZERO, 0.0)
	var segs: Array = data["segments"]
	var seg1: Transform2D = segs[1] as Transform2D
	assert_true(seg1.get_rotation() > 0.01,
			"Segment after right-clicked joint should have positive rotation")


func test_compute_segment_transforms_joint_positions_advance() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	var data: Dictionary = _state.compute_segment_transforms(
			Vector2.ZERO, 0.0)
	var joints: Array = data["joints"]
	# Both joints should be ahead of origin (negative Y)
	for j: int in range(joints.size()):
		var jpos: Vector2 = joints[j] as Vector2
		assert_true(jpos.y < 0.0,
				"Joint %d should be in -Y direction" % j)


# ---------------------------------------------------------------------------
# compute_final_transform
# ---------------------------------------------------------------------------

func test_compute_final_transform_straight_ahead() -> void:
	_state.setup(1, CR90_NAV, Constants.ShipSize.SMALL)
	var xform: Transform2D = _state.compute_final_transform(
			Vector2.ZERO, 0.0)
	assert_true(xform.origin.y < 0.0,
			"Final position should be ahead of start (negative Y)")


func test_compute_final_transform_preserves_rotation() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_right(0)
	var xform: Transform2D = _state.compute_final_transform(
			Vector2.ZERO, 0.0)
	assert_true(xform.get_rotation() > 0.01,
			"Final rotation should match cumulative yaw")


# ---------------------------------------------------------------------------
# get_tool_scale — universal scaling
# ---------------------------------------------------------------------------

func test_get_tool_scale_returns_consistent_value() -> void:
	var s: float = ManeuverToolState.get_tool_scale()
	assert_true(s > 0.0, "Tool scale should be positive")
	# Scale = maneuver_segment_px / segment entry-to-exit distance
	var seg_cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"segment", {})
	var entry: Vector2 = seg_cfg.get("entry_intersection", Vector2.ZERO)
	var exit_pt: Vector2 = seg_cfg.get("exit_intersection", Vector2.ZERO)
	var expected: float = GameScale.maneuver_segment_px / absf(
			entry.y - exit_pt.y)
	assert_almost_eq(s, expected, 0.001,
			"Tool scale should match segment entry-to-exit ratio")


func test_root_advance_shorter_than_segment_advance() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	var data: Dictionary = _state.compute_segment_transforms(
			Vector2.ZERO, 0.0)
	var joints: Array = data["joints"]
	# Joint 0 = root advance, Joint 1 = joint 0 + segment advance
	var root_advance: float = absf((joints[0] as Vector2).y)
	var seg_advance: float = absf(
			(joints[1] as Vector2).y - (joints[0] as Vector2).y)
	assert_true(root_advance < seg_advance,
			"Root advance should be smaller than segment advance")
	assert_almost_eq(seg_advance, GameScale.maneuver_segment_px, 0.1,
			"Segment advance should equal maneuver_segment_px")


func test_compute_final_transform_places_ghost_ahead_of_ship() -> void:
	## At speed 1, straight, the ghost centre should be directly ahead of
	## the hypothetical original ship position (same X for tool on left side).
	_state.setup(1, CR90_NAV, Constants.ShipSize.SMALL)
	var base: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var half_w: float = base.x * 0.5
	var half_l: float = base.y * 0.5
	## Simulate the attachment point as if the ship centre were at (0,0)
	## and the tool attaches to the front-left corner.
	var root_cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"root", {})
	var root_entry: Vector2 = root_cfg.get("entry_intersection",
			Vector2.ZERO) as Vector2
	var root_contact_r: Vector2 = root_cfg.get("contact_right",
			Vector2.ZERO) as Vector2
	var s: float = ManeuverToolState.get_tool_scale()
	var corner: Vector2 = Vector2(-half_w, -half_l)
	var offset: Vector2 = (root_entry - root_contact_r) * s
	var attach_pos: Vector2 = corner + offset
	var xform: Transform2D = _state.compute_final_transform(
			attach_pos, 0.0, "left")
	## Ghost centre X should be close to 0 (directly ahead of ship centre).
	assert_almost_eq(xform.origin.x, 0.0, 2.0,
			"Ghost should be directly ahead of the ship (same X)")
	## Ghost centre Y should be negative (forward of origin).
	assert_true(xform.origin.y < 0.0,
			"Ghost should be ahead of ship (negative Y)")


func test_compute_final_transform_right_side_mirrors_left() -> void:
	_state.setup(1, CR90_NAV, Constants.ShipSize.SMALL)
	## Same attachment logic but for right side.
	var base: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var half_w: float = base.x * 0.5
	var half_l: float = base.y * 0.5
	var root_cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"root", {})
	var root_entry: Vector2 = root_cfg.get("entry_intersection",
			Vector2.ZERO) as Vector2
	var root_contact_l: Vector2 = root_cfg.get("contact_left",
			Vector2.ZERO) as Vector2
	var s: float = ManeuverToolState.get_tool_scale()
	var corner: Vector2 = Vector2(half_w, -half_l)
	var offset: Vector2 = (root_entry - root_contact_l) * s
	offset.x = - offset.x
	var attach_pos: Vector2 = corner + offset
	var left_xform: Transform2D = _state.compute_final_transform(
			attach_pos, 0.0, "left")
	var right_xform: Transform2D = _state.compute_final_transform(
			attach_pos, 0.0, "right")
	## Left and right should produce different X positions.
	assert_true(absf(left_xform.origin.x - right_xform.origin.x) > 10.0,
			"Left vs right side should produce different X positions")


# ---------------------------------------------------------------------------
# compute_ghost_side  (Phase 5a+)
# ---------------------------------------------------------------------------

func test_compute_ghost_side_all_straight_returns_left() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL)
	assert_eq(_state.compute_ghost_side(), "left",
			"All straight joints should default to left")


func test_compute_ghost_side_bend_right_returns_right() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_right(1)
	assert_eq(_state.compute_ghost_side(), "right",
			"Starboard bend should switch side to right")


func test_compute_ghost_side_bend_left_returns_left() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_left(1)
	assert_eq(_state.compute_ghost_side(), "left",
			"Port bend should keep side on left")


func test_compute_ghost_side_end_joint_takes_priority() -> void:
	## Speed 3: joint 0 max 0, joint 1 max 1, joint 2 max 2.
	## Click joint 1 right (+1) and joint 2 left (-1).
	## End joint (2) should take priority → "left".
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_right(1)
	_state.click_joint_left(2)
	assert_eq(_state.compute_ghost_side(), "left",
			"End joint should take priority over earlier joints")


func test_compute_ghost_side_skips_zero_joints() -> void:
	## Speed 3: click joint 1 left but leave joint 2 at 0.
	## Scanning from end: joint 2 = 0 (skip), joint 1 < 0 → "left".
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL)
	_state.click_joint_left(1)
	assert_eq(_state.compute_ghost_side(), "left",
			"Should skip zero joints and find first non-zero")


# ---------------------------------------------------------------------------
# Speed simulation  (Phase 5a+)
# ---------------------------------------------------------------------------

func test_setup_sets_simulated_speed_to_current() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL, 4)
	assert_eq(_state.get_simulated_speed(), 3,
			"Simulated speed should equal initial speed after setup")


func test_setup_sets_max_speed() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL, 4)
	assert_eq(_state.get_max_speed(), 4,
			"Max speed should be set from setup parameter")


func test_set_simulated_speed_increases() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL, 4)
	_state.set_simulated_speed(3)
	assert_eq(_state.get_simulated_speed(), 3,
			"Simulated speed should increase to 3")
	assert_eq(_state.get_active_segment_count(), 4,
			"Active segment count should adapt to simulated speed 3")


func test_set_simulated_speed_decreases() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL, 4)
	_state.set_simulated_speed(1)
	assert_eq(_state.get_simulated_speed(), 1,
			"Simulated speed should decrease to 1")
	assert_eq(_state.get_active_segment_count(), 2,
			"Active segment count should be 2 at simulated speed 1")


func test_set_simulated_speed_clamps_to_max() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL, 4)
	_state.set_simulated_speed(10)
	assert_eq(_state.get_simulated_speed(), 4,
			"Simulated speed should clamp to max_speed")


func test_set_simulated_speed_clamps_to_min_1() -> void:
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL, 4)
	_state.set_simulated_speed(0)
	assert_eq(_state.get_simulated_speed(), 1,
			"Simulated speed should clamp to minimum 1")


func test_set_simulated_speed_clamps_joint_clicks() -> void:
	## Speed 4 joint 3 max yaw = 2; speed 3 joint 2 max yaw = 2.
	## But at speed 2 only joints 0,1 are active → joint 2,3 zeroed.
	_state.setup(4, CR90_NAV, Constants.ShipSize.SMALL, 4)
	_state.click_joint_right(2) # max 1 at speed 4
	_state.click_joint_right(3) # max 2 at speed 4
	_state.click_joint_right(3)
	_state.set_simulated_speed(2)
	var clicks: Array[int] = _state.get_joint_clicks()
	assert_eq(clicks[2], 0,
			"Joint 2 should be zeroed when speed drops to 2")
	assert_eq(clicks[3], 0,
			"Joint 3 should be zeroed when speed drops to 2")


func test_set_simulated_speed_clamps_yaw_to_nav_chart() -> void:
	## At speed 2: joint 1 max yaw = 2. Click it to 2.
	## At speed 1: only joint 0 is active with max yaw = 2.
	## Joint 1 becomes inactive → zeroed.
	_state.setup(2, CR90_NAV, Constants.ShipSize.SMALL, 4)
	_state.click_joint_right(1)
	_state.click_joint_right(1)
	assert_eq(_state.get_joint_clicks()[1], 2,
			"Joint 1 should be at 2 clicks")
	_state.set_simulated_speed(1)
	assert_eq(_state.get_joint_clicks()[1], 0,
			"Joint 1 should be zeroed at speed 1")


func test_is_joint_active_uses_simulated_speed() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL, 4)
	assert_true(_state.is_joint_active(2),
			"Joint 2 should be active at simulated speed 3")
	_state.set_simulated_speed(2)
	assert_false(_state.is_joint_active(2),
			"Joint 2 should be inactive at simulated speed 2")


func test_get_segment_type_uses_simulated_speed() -> void:
	_state.setup(3, CR90_NAV, Constants.ShipSize.SMALL, 4)
	assert_eq(_state.get_segment_type(3), "segment_end",
			"At simulated speed 3, segment 3 is segment_end")
	_state.set_simulated_speed(2)
	assert_eq(_state.get_segment_type(2), "segment_end",
			"At simulated speed 2, segment 2 is segment_end")

## Tests for ManeuverCalculator
##
## Covers: get_max_yaw, get_joint_count, validate_yaw_clicks, is_joint_locked,
##   compute_tool_joints, compute_final_transform.
##
## Uses the CR90 Corvette A navigation chart as reference data:
##   [[2],[1,2],[0,1,2],[0,1,1,2]]
##
## Rules Reference: "Maneuver", p.7; "Navigation Chart", p.8; MV-001–006, MV-010–015
extends GutTest


## CR90 Corvette A navigation chart (exactly as in JSON).
## Row index = speed - 1, column index = joint index.
## Value = max yaw clicks (0 = locked).
var CR90_NAV_CHART: Array = [[2], [1, 2], [0, 1, 2], [0, 1, 1, 2]]


# ---------------------------------------------------------------------------
# get_max_yaw (MV-001)
# ---------------------------------------------------------------------------

func test_get_max_yaw_speed1_joint0_is_2() -> void:
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 1, 0)
	assert_eq(result, 2, "CR90 speed 1, joint 0: max yaw should be 2")


func test_get_max_yaw_speed2_joint0_is_1() -> void:
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 2, 0)
	assert_eq(result, 1, "CR90 speed 2, joint 0: max yaw should be 1")


func test_get_max_yaw_speed2_joint1_is_2() -> void:
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 2, 1)
	assert_eq(result, 2, "CR90 speed 2, joint 1: max yaw should be 2")


func test_get_max_yaw_speed4_joint0_is_0() -> void:
	# Speed 4, joint 0 is locked (0)
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 4, 0)
	assert_eq(result, 0, "CR90 speed 4, joint 0: should be locked (0)")


func test_get_max_yaw_speed4_joint3_is_2() -> void:
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 4, 3)
	assert_eq(result, 2, "CR90 speed 4, joint 3: max yaw should be 2")


func test_get_max_yaw_invalid_speed_zero_returns_zero() -> void:
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 0, 0)
	assert_eq(result, 0, "Speed 0 should return 0 (no movement)")


func test_get_max_yaw_out_of_range_speed_returns_zero() -> void:
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 5, 0)
	assert_eq(result, 0, "Speed beyond chart should return 0")


func test_get_max_yaw_invalid_joint_index_returns_zero() -> void:
	# Speed 1 only has joint 0; asking for joint 1 should return 0.
	var result: int = ManeuverCalculator.get_max_yaw(CR90_NAV_CHART, 1, 1)
	assert_eq(result, 0, "Joint beyond speed's active joints should return 0")


# ---------------------------------------------------------------------------
# get_joint_count (MV-002)
# ---------------------------------------------------------------------------

func test_get_joint_count_speed1_is_1() -> void:
	assert_eq(ManeuverCalculator.get_joint_count(1), 1,
			"Speed 1 should have 1 active joint")


func test_get_joint_count_speed4_is_4() -> void:
	assert_eq(ManeuverCalculator.get_joint_count(4), 4,
			"Speed 4 should have 4 active joints")


func test_get_joint_count_speed0_is_0() -> void:
	assert_eq(ManeuverCalculator.get_joint_count(0), 0,
			"Speed 0 should have 0 active joints")


# ---------------------------------------------------------------------------
# is_joint_locked (MV-001, "Navigation Chart")
# ---------------------------------------------------------------------------

func test_is_joint_locked_speed4_joint0_is_true() -> void:
	var result: bool = ManeuverCalculator.is_joint_locked(CR90_NAV_CHART, 4, 0)
	assert_true(result, "Speed 4 joint 0 should be locked for CR90")


func test_is_joint_locked_speed1_joint0_is_false() -> void:
	var result: bool = ManeuverCalculator.is_joint_locked(CR90_NAV_CHART, 1, 0)
	assert_false(result, "Speed 1 joint 0 should not be locked for CR90")


# ---------------------------------------------------------------------------
# validate_yaw_clicks (MV-003)
# ---------------------------------------------------------------------------

func test_validate_yaw_clicks_valid_returns_true() -> void:
	# Speed 2: joints 0 (max 1), 1 (max 2). Using [1, -1] = ok.
	var result: bool = ManeuverCalculator.validate_yaw_clicks(
			CR90_NAV_CHART, 2, [1, -1])
	assert_true(result, "Valid click array should pass validation")


func test_validate_yaw_clicks_exceeds_max_returns_false() -> void:
	# Speed 1: joint 0 max = 2. Requesting 3 = invalid.
	var result: bool = ManeuverCalculator.validate_yaw_clicks(
			CR90_NAV_CHART, 1, [3])
	assert_false(result, "Exceeding max clicks should fail validation")


func test_validate_yaw_clicks_wrong_length_returns_false() -> void:
	# Speed 2 needs 2 joints. Providing only 1.
	var result: bool = ManeuverCalculator.validate_yaw_clicks(
			CR90_NAV_CHART, 2, [1])
	assert_false(result, "Wrong number of click values should fail validation")


func test_validate_yaw_clicks_locked_joint_zero_is_valid() -> void:
	# Speed 4, joint 0 is locked (max=0). Providing 0 clicks = valid.
	var result: bool = ManeuverCalculator.validate_yaw_clicks(
			CR90_NAV_CHART, 4, [0, 0, 1, -2])
	assert_true(result, "Zero clicks on locked joint should pass validation")


func test_validate_yaw_clicks_locked_joint_nonzero_is_invalid() -> void:
	# Speed 4, joint 0 is locked. Requesting 1 click = invalid.
	var result: bool = ManeuverCalculator.validate_yaw_clicks(
			CR90_NAV_CHART, 4, [1, 0, 1, -2])
	assert_false(result, "Non-zero clicks on locked joint should fail validation")


# ---------------------------------------------------------------------------
# compute_tool_joints (MV-002, MV-004)
# ---------------------------------------------------------------------------

func test_compute_tool_joints_speed0_empty() -> void:
	var joints: Array[Transform2D] = ManeuverCalculator.compute_tool_joints(
			Transform2D.IDENTITY, 0, [])
	assert_eq(joints.size(), 0, "Speed 0 should return empty joints array")


func test_compute_tool_joints_speed1_returns_one_joint() -> void:
	var joints: Array[Transform2D] = ManeuverCalculator.compute_tool_joints(
			Transform2D.IDENTITY, 1, [0])
	assert_eq(joints.size(), 1, "Speed 1 should return 1 joint transform")


func test_compute_tool_joints_speed2_returns_two_joints() -> void:
	var joints: Array[Transform2D] = ManeuverCalculator.compute_tool_joints(
			Transform2D.IDENTITY, 2, [0, 0])
	assert_eq(joints.size(), 2, "Speed 2 should return 2 joint transforms")


func test_compute_tool_joints_straight_ahead_moves_forward() -> void:
	# Ship at origin facing -Y. Straight movement (0 yaw) at speed 1.
	var start: Transform2D = Transform2D.IDENTITY
	var joints: Array[Transform2D] = ManeuverCalculator.compute_tool_joints(
			start, 1, [0])
	# The joint should be further in -Y than the start.
	assert_true(joints[0].origin.y < 0.0,
			"Straight-ahead joint should move in -Y direction")


# ---------------------------------------------------------------------------
# compute_final_transform (MV-005)
# ---------------------------------------------------------------------------

func test_compute_final_transform_empty_joints_returns_identity() -> void:
	var joints: Array[Transform2D] = []
	var result: Transform2D = ManeuverCalculator.compute_final_transform(
			joints, Constants.ShipSize.SMALL)
	assert_eq(result, Transform2D.IDENTITY,
			"Empty joints should return IDENTITY transform")


func test_compute_final_transform_straight_sets_new_position() -> void:
	var start: Transform2D = Transform2D.IDENTITY
	var joints: Array[Transform2D] = ManeuverCalculator.compute_tool_joints(
			start, 1, [0])
	var final_xform: Transform2D = ManeuverCalculator.compute_final_transform(
			joints, Constants.ShipSize.SMALL)
	# New centre should be ahead of origin.
	assert_true(final_xform.origin.y < 0.0,
			"Final transform origin should be ahead of starting position")

## ManeuverCalculator
##
## Computes ship movement using the maneuver tool (speed 1–4, yaw 0–2 per joint).
##
## Maneuver tool: a rigid plastic tool with 3 joints (numbered 1–3 from the front).
## Each joint may be deflected left or right by 0, 1, or 2 clicks.
## The tool is placed at the front edge notch of the ship base.
##
## Navigation chart format (from ship JSON):
##   navigation_chart[speed - 1][joint_index] = max_yaw_clicks
##   e.g. [[2],[1,2],[0,1,2],[0,0,1,2]] — speed 1 has 1 joint max 2 clicks,
##        speed 4 has 4 joints at 0/0/1/2 max clicks each.
## Note: speed 0 is stationary — no movement.
##
## Coordinate convention matches ShipBase: ship faces -Y, X is starboard.
## Each maneuver segment length is GameScale.maneuver_segment_px.
## Positive yaw_clicks = starboard (right), negative = port (left).
##
## Rules Reference: "Maneuver", p.7; MV-001–006, MV-010–015
class_name ManeuverCalculator
extends RefCounted


## Degrees rotated per yaw click on the maneuver tool.
## Rules Reference: "Maneuver", p.7 (each click ≈ 11.25°)
const YAW_DEGREES_PER_CLICK: float = 11.25

## Radian equivalent.
const YAW_RADIANS_PER_CLICK: float = YAW_DEGREES_PER_CLICK * PI / 180.0


## Returns the maximum yaw clicks allowed for a given joint at a given speed.
## joint_index is 0-based (joint 0 = closest to ship).
## Returns 0 if the joint is locked or the speed/joint combination is invalid.
##
## Rules Reference: "Navigation Chart", p.8; MV-001
static func get_max_yaw(nav_chart: Array, speed: int, joint_index: int) -> int:
	if speed <= 0 or speed > nav_chart.size():
		return 0
	var speed_row: Array = nav_chart[speed - 1]
	if joint_index < 0 or joint_index >= speed_row.size():
		return 0
	return int(speed_row[joint_index])


## Returns the number of active joints for the given speed.
## Rules Reference: "Maneuver", p.7 — at speed N, joints 0 to N-1 are active.
static func get_joint_count(speed: int) -> int:
	return max(0, speed)


## Validates that yaw_clicks_per_joint does not exceed the nav chart limits.
## yaw_clicks_per_joint: Array[int] of signed clicks (positive=starboard),
##   length must equal joint_count for the given speed.
## Returns true if all clicks are within limits.
##
## Rules Reference: MV-003
static func validate_yaw_clicks(
		nav_chart: Array, speed: int, yaw_clicks_per_joint: Array) -> bool:
	var joint_count: int = get_joint_count(speed)
	if yaw_clicks_per_joint.size() != joint_count:
		return false
	for idx: int in range(joint_count):
		var clicks: int = abs(int(yaw_clicks_per_joint[idx]))
		var max_clicks: int = get_max_yaw(nav_chart, speed, idx)
		if clicks > max_clicks:
			return false
	return true


## Computes the Transform2D at each joint of the maneuver tool.
## start_transform: ship's current Transform2D (centre of base).
## speed: ship speed (1–4). speed 0 returns an empty array.
## yaw_clicks_per_joint: signed int per active joint (positive=starboard).
##
## Returns Array[Transform2D] of length `speed`, representing the world-space
## transform at the END of each tool segment (joint 0 = first segment, etc.).
## The final element is the position where the new ship base front notch rests.
##
## Rules Reference: "Maneuver", p.7; MV-002, MV-004
static func compute_tool_joints(
		start_transform: Transform2D,
		speed: int,
		yaw_clicks_per_joint: Array) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	if speed <= 0:
		return result

	var seg_len: float = GameScale.maneuver_segment_px
	var current: Transform2D = start_transform

	# Move from the base centre to the front notch (leading edge).
	# In local space, the front notch is at (0, -half_length_px).
	# We advance the tool from there.
	var ship_size: Constants.ShipSize = Constants.ShipSize.SMALL # default
	var half_len: float = GameScale.get_base_size(ship_size).y * 0.5
	var notch_fwd: Vector2 = current.basis_xform(Vector2(0.0, -half_len))
	current = Transform2D(current.get_rotation(), current.origin + notch_fwd)

	var joint_count: int = get_joint_count(speed)
	for idx: int in range(joint_count):
		# Apply yaw rotation at this joint.
		var clicks: int = 0
		if idx < yaw_clicks_per_joint.size():
			clicks = int(yaw_clicks_per_joint[idx])
		var yaw_rad: float = float(clicks) * YAW_RADIANS_PER_CLICK
		var rot: float = current.get_rotation() + yaw_rad
		current = Transform2D(rot, current.origin)

		# Advance one segment length in the current facing direction.
		var forward: Vector2 = current.basis_xform(Vector2(0.0, -seg_len))
		current = Transform2D(rot, current.origin + forward)
		result.append(current)

	return result


## Computes the final ship Transform2D after completing the maneuver.
## joints: Array[Transform2D] from compute_tool_joints.
## ship_size: size of the ship (determines half_length for notch offset).
##
## The new ship centre is set so its front notch aligns with the last joint.
##
## Rules Reference: "Maneuver", p.7; MV-005
static func compute_final_transform(
		joints: Array[Transform2D],
		ship_size: Constants.ShipSize) -> Transform2D:
	if joints.is_empty():
		return Transform2D.IDENTITY

	var final_joint: Transform2D = joints[joints.size() - 1]
	var half_len: float = GameScale.get_base_size(ship_size).y * 0.5
	# The new centre is half_len behind the final joint (along its facing axis).
	var backward: Vector2 = final_joint.basis_xform(Vector2(0.0, half_len))
	return Transform2D(final_joint.get_rotation(), final_joint.origin + backward)


## Checks whether a navigation chart value represents a locked joint.
## 0 = locked (displayed as "-" on the card), 1 or 2 = click count.
##
## Rules Reference: "Navigation Chart", p.8; MV-001
static func is_joint_locked(nav_chart: Array, speed: int, joint_index: int) -> bool:
	return get_max_yaw(nav_chart, speed, joint_index) == 0

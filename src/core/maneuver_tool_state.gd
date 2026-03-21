## ManeuverToolState
##
## Core model for the maneuver tool. Tracks joint angles, active speed,
## and validates yaw against the ship's navigation chart.
## Scene-tree independent (extends RefCounted).
##
## Rules Reference: RRG "Maneuver Tool" p.10, "Ship Movement" p.16–17.
## Requirements: MT-M-001–006, AC-01–03, AC-12.
class_name ManeuverToolState
extends RefCounted


## Maximum number of joints on the maneuver tool.
const MAX_JOINTS: int = 4

## Maximum clicks in either direction on any single joint.
const MAX_CLICKS_PER_JOINT: int = 2

## Total number of physical segments (root + 3 middle + end).
const TOTAL_SEGMENTS: int = 5

## Current speed (determines active joints: 0 to speed-1).
var _speed: int = 0

## Simulated speed for what-if preview. Defaults to _speed on setup.
## Does not modify ShipInstance.current_speed.
## Requirements: MT-S-002, MT-S-006, AC-24.
var _simulated_speed: int = 0

## Maximum speed from the ship's card data.
var _max_speed: int = 0

## Navigation chart from the ship's card data.
## Format: nav_chart[speed-1][joint_index] = max_yaw_clicks.
var _nav_chart: Array = []

## Ship size for base dimension lookups.
var _ship_size: Constants.ShipSize = Constants.ShipSize.SMALL

## Current click value per joint (negative = port, positive = starboard).
var _joint_clicks: Array[int] = [0, 0, 0, 0]

## Joint index that has a Navigate yaw bonus (+1 max yaw), or -1 if none.
## Requirements: NAV-002, NAV-006, EXE-005, AC-5b-04.
var _yaw_bonus_joint: int = -1


## Initialises the tool state for a specific ship.
## [param speed] — the ship's current speed (0–4).
## [param nav_chart] — the ship's navigation chart array.
## [param ship_size] — the ship's base size class.
func setup(speed: int, nav_chart: Array,
		ship_size: Constants.ShipSize,
		max_speed: int = -1) -> void:
	_speed = clampi(speed, 0, MAX_JOINTS)
	_max_speed = max_speed if max_speed >= 0 else _speed
	_simulated_speed = _speed
	_nav_chart = nav_chart
	_ship_size = ship_size
	reset_joints()


## Returns the current speed.
func get_speed() -> int:
	return _speed


## Returns the ship size.
func get_ship_size() -> Constants.ShipSize:
	return _ship_size


## Returns a copy of the current joint click values.
func get_joint_clicks() -> Array[int]:
	return _joint_clicks.duplicate()


## Resets all joints to straight (0 clicks).
func reset_joints() -> void:
	_joint_clicks = [0, 0, 0, 0]


## Returns true if the given joint is active at the simulated speed.
## Rules Reference: MT-M-004 — at speed N, joints 0 to N-1 are active.
func is_joint_active(joint_index: int) -> bool:
	return joint_index >= 0 and joint_index < _simulated_speed


## Returns the maximum absolute yaw clicks for a joint at simulated speed.
## If a yaw bonus is applied to this joint, the limit is increased by 1.
## Rules Reference: MT-M-005, NAV-002, NAV-006.
func get_max_yaw(joint_index: int) -> int:
	var base: int = ManeuverCalculator.get_max_yaw(
			_nav_chart, _simulated_speed, joint_index)
	if _yaw_bonus_joint == joint_index:
		base += 1
	return base


## Clicks a joint one step to the left (port, negative direction).
## Returns true if the click was applied, false if rejected.
## Rules Reference: MT-G-003, MT-M-002, AC-02.
func click_joint_left(joint_index: int) -> bool:
	return _apply_click(joint_index, -1)


## Clicks a joint one step to the right (starboard, positive direction).
## Returns true if the click was applied, false if rejected.
## Rules Reference: MT-G-003, MT-M-002, AC-02.
func click_joint_right(joint_index: int) -> bool:
	return _apply_click(joint_index, 1)


## Returns the number of active segments (simulated_speed + 1, minimum 1).
## Requirements: MT-S-003, MT-S-004, AC-21.
func get_active_segment_count() -> int:
	if _simulated_speed <= 0:
		return 1
	return _simulated_speed + 1


## Returns the segment type string for the given segment index.
## "root" for index 0, "segment_end" for the last active segment,
## "segment" for all middle segments.
func get_segment_type(segment_index: int) -> String:
	if segment_index == 0:
		return "root"
	if segment_index == _simulated_speed:
		return "segment_end"
	return "segment"


## Returns the universal sprite scale for maneuver tool PNGs.
## All segment types share a single scale so contact widths match.
## Based on the standard segment's entry-to-exit PNG distance.
## Requirements: MT-D-003, AC-09.
static func get_tool_scale() -> float:
	var cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"segment", {})
	var entry: Vector2 = cfg.get("entry_intersection", Vector2.ZERO)
	var exit_pt: Vector2 = cfg.get("exit_intersection", Vector2.ZERO)
	var png_len: float = absf(entry.y - exit_pt.y)
	if png_len <= 0.0:
		return 1.0
	return GameScale.maneuver_segment_px / png_len


## Returns the game-pixel advance (entry to exit) for a segment type.
## Uses the universal scale factor so joints align visually.
func _get_segment_advance_px(seg_type: String) -> float:
	var cfg: Dictionary = GameScale.maneuver_tool_config.get(
			seg_type, {})
	var entry_px: Vector2 = cfg.get("entry_intersection",
			Vector2.ZERO)
	if not cfg.has("exit_intersection"):
		return 0.0
	var exit_px: Vector2 = cfg.get("exit_intersection",
			Vector2.ZERO)
	var png_dist: float = absf(entry_px.y - exit_px.y)
	return png_dist * get_tool_scale()


## Computes segment entry transforms for visual rendering.
## [param start_pos] — world position of the root segment's entry.
## [param start_rot] — world rotation (radians) of the root's heading.
## Returns Dictionary with "segments" (Array[Transform2D]) and
## "joints" (Array[Vector2]).
## Rules Reference: MT-M-003.
func compute_segment_transforms(
		start_pos: Vector2, start_rot: float) -> Dictionary:
	var segments: Array[Transform2D] = []
	var joints: Array[Vector2] = []
	var num_segs: int = get_active_segment_count()
	var pos: Vector2 = start_pos
	var rot: float = start_rot
	for i: int in range(num_segs):
		segments.append(Transform2D(rot, pos))
		if i < _simulated_speed:
			var seg_type: String = get_segment_type(i)
			var advance: float = _get_segment_advance_px(seg_type)
			var fwd: Vector2 = Vector2(0.0, -advance).rotated(rot)
			pos = pos + fwd
			joints.append(pos)
			var yaw: float = float(_joint_clicks[i]) \
					* ManeuverCalculator.YAW_RADIANS_PER_CLICK
			rot += yaw
	return {"segments": segments, "joints": joints}


## Computes the final ship transform (centre position) after maneuver.
## The ship's front corner aligns to the last segment's contact point.
## When [param side] is "left" the ship's front-left corner meets
## the segment's contact_right; when "right" the front-right corner
## meets contact_left.
## [param start_pos] — tool attachment world position.
## [param start_rot] — tool attachment heading (radians).
## [param side] — which side the tool is on ("left" or "right").
## Rules Reference: MT-G-007, MV-005.
func compute_final_transform(
		start_pos: Vector2, start_rot: float,
		side: String = "left") -> Transform2D:
	var data: Dictionary = compute_segment_transforms(start_pos, start_rot)
	var segs: Array = data["segments"]
	if segs.is_empty():
		return Transform2D.IDENTITY
	var last_idx: int = segs.size() - 1
	var last_seg: Transform2D = segs[last_idx] as Transform2D
	var seg_rot: float = last_seg.get_rotation()
	## Determine which contact maps to which ship corner.
	var seg_type: String = get_segment_type(last_idx)
	var cfg: Dictionary = GameScale.maneuver_tool_config.get(
			seg_type, {})
	var entry_px: Vector2 = cfg.get("entry_intersection",
			Vector2.ZERO) as Vector2
	var contact_key: String = "contact_right" if side == "left" \
			else "contact_left"
	var contact_pt: Vector2 = cfg.get(contact_key,
			Vector2.ZERO) as Vector2
	var contact_offset: Vector2 = (
			contact_pt - entry_px) * get_tool_scale()
	var contact_world: Vector2 = last_seg.origin \
			+ contact_offset.rotated(seg_rot)
	## Corner-to-centre offset.
	var base: Vector2 = GameScale.get_base_size(_ship_size)
	var half_w: float = base.x * 0.5
	var half_len: float = base.y * 0.5
	var corner_to_center: Vector2
	if side == "left":
		corner_to_center = Vector2(half_w, half_len)
	else:
		corner_to_center = Vector2(-half_w, half_len)
	var center_pos: Vector2 = contact_world \
			+ corner_to_center.rotated(seg_rot)
	return Transform2D(seg_rot, center_pos)


## Internal: applies a click delta to a joint with validation.
func _apply_click(joint_index: int, delta: int) -> bool:
	if not is_joint_active(joint_index):
		return false
	var new_clicks: int = _joint_clicks[joint_index] + delta
	if absi(new_clicks) > MAX_CLICKS_PER_JOINT:
		return false
	if absi(new_clicks) > get_max_yaw(joint_index):
		return false
	_joint_clicks[joint_index] = new_clicks
	return true


# ------------------------------------------------------------------
# Dynamic alignment  (Phase 5a+)
# ------------------------------------------------------------------


## Computes the alignment side based on the dominant bend direction.
## Scans active joints from end to start. The first non-zero click
## determines the side: negative (port / left bend) → "left",
## positive (starboard / right bend) → "right".
## The tool attaches on the same side as the bend; the ghost appears
## on the opposite side, preventing overlap.
## If all joints are straight, returns "left" (default).
## Requirements: MT-A-001, MT-A-002, MT-A-004, AC-17, AC-18.
## Rules Reference: MT-A-003 — prevents ghost overlapping the tool.
func compute_ghost_side() -> String:
	var last_active: int = _simulated_speed - 1
	for i: int in range(last_active, -1, -1):
		if _joint_clicks[i] > 0:
			return "right"
		if _joint_clicks[i] < 0:
			return "left"
	return "left"


# ------------------------------------------------------------------
# Speed simulation  (Phase 5a+)
# ------------------------------------------------------------------


## Returns the current simulated speed.
## Requirements: MT-S-006, AC-24.
func get_simulated_speed() -> int:
	return _simulated_speed


## Returns the maximum speed from the ship's card data.
func get_max_speed() -> int:
	return _max_speed


## Sets the simulated speed and clamps joint clicks that exceed the
## new navigation chart row. Speed is clamped to [1, _max_speed].
## Requirements: MT-S-002, MT-S-003, AC-20, AC-21, AC-22.
func set_simulated_speed(new_speed: int) -> void:
	_simulated_speed = clampi(new_speed, 1, maxi(_max_speed, 1))
	_clamp_joints_to_nav_chart()


## Clamps each joint's click value to the max yaw allowed at the
## current simulated speed. Retains the sign (port/starboard).
## Deactivated joints (index >= simulated_speed) are zeroed.
## Call after changing the yaw bonus assignment so that the old joint's
## clicks do not exceed the (now reduced) limit.
## Requirements: MT-S-003, AC-22.
func clamp_joints() -> void:
	_clamp_joints_to_nav_chart()


## Internal: clamps each joint's click value to the max yaw allowed at the
## current simulated speed.
func _clamp_joints_to_nav_chart() -> void:
	for i: int in range(MAX_JOINTS):
		if i >= _simulated_speed:
			_joint_clicks[i] = 0
			continue
		var max_yaw: int = get_max_yaw(i)
		if absi(_joint_clicks[i]) > max_yaw:
			_joint_clicks[i] = max_yaw * signi(_joint_clicks[i])


# ------------------------------------------------------------------
# Yaw bonus  (Phase 5b — Navigate command)
# ------------------------------------------------------------------


## Sets the yaw bonus on a specific joint (+1 max yaw for this maneuver).
## Only one joint can hold the bonus at a time. Returns true if applied.
## [param joint_index] — the joint to receive the bonus (0-based).
## Requirements: NAV-002, NAV-006, EXE-005, AC-5b-04.
func set_yaw_bonus_joint(joint_index: int) -> bool:
	if joint_index < 0 or joint_index >= MAX_JOINTS:
		return false
	if not is_joint_active(joint_index):
		return false
	_yaw_bonus_joint = joint_index
	return true


## Removes the yaw bonus from all joints.
func clear_yaw_bonus() -> void:
	_yaw_bonus_joint = -1


## Returns the joint index with the yaw bonus, or -1 if none.
func get_yaw_bonus_joint() -> int:
	return _yaw_bonus_joint


## Returns true if the given joint has a yaw bonus.
func has_yaw_bonus_on(joint_index: int) -> bool:
	return _yaw_bonus_joint == joint_index

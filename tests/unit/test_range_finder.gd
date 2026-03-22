## Unit tests for RangeFinder.
##
## Tests firing-arc containment, closest-point calculations, range measurement,
## maximum attack range, and dice-at-range logic.
##
## Requirements: TL-RNG-001–006, TL-ARC-001–006, AC-TL-15, AC-TL-18.
extends GutTest


# =========================================================================
# Helpers — create a minimal set of firing arc boundary points for a ship
# at a given position and rotation.  Simulates a rectangular base with
# 4 boundary lines meeting at the centre.
# =========================================================================

## Creates world-space arc boundary points for a ship at [pos] with [rot].
## The test ship is a small rectangle with half_w=20, half_l=35.
## Boundary lines radiate from the centre outward through the corners.
func _make_arc_pts(pos: Vector2, rot: float) -> Dictionary:
	var hw: float = 20.0
	var hl: float = 35.0
	var centre: Vector2 = pos
	# Inner points: all at the centre (matches CR90 pattern).
	# Outer points: at the base corners.
	var fl: Vector2 = pos + Vector2(-hw, -hl).rotated(rot)
	var fr: Vector2 = pos + Vector2(hw, -hl).rotated(rot)
	var rl: Vector2 = pos + Vector2(-hw, hl).rotated(rot)
	var rr: Vector2 = pos + Vector2(hw, hl).rotated(rot)
	# Extend outer points further outward for clearer arcs.
	var fl_ext: Vector2 = pos + (Vector2(-hw, -hl).normalized() * 100.0).rotated(rot)
	var fr_ext: Vector2 = pos + (Vector2(hw, -hl).normalized() * 100.0).rotated(rot)
	var rl_ext: Vector2 = pos + (Vector2(-hw, hl).normalized() * 100.0).rotated(rot)
	var rr_ext: Vector2 = pos + (Vector2(hw, hl).normalized() * 100.0).rotated(rot)
	return {
		"inner_point_front_left": centre,
		"outer_point_front_left": fl_ext,
		"inner_point_front_right": centre,
		"outer_point_front_right": fr_ext,
		"inner_point_rear_left": centre,
		"outer_point_rear_left": rl_ext,
		"inner_point_rear_right": centre,
		"outer_point_rear_right": rr_ext,
	}


# =========================================================================
# is_point_in_arc
# =========================================================================

func test_point_in_front_arc_returns_true_for_point_ahead() -> void:
	# Arrange
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var point: Vector2 = Vector2(500, 300)  # directly ahead (Y negative = front)
	# Act
	var result: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.FRONT, arc_pts)
	# Assert
	assert_true(result, "Point ahead should be in FRONT arc")


func test_point_in_front_arc_returns_false_for_point_behind() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var point: Vector2 = Vector2(500, 700)  # directly behind
	var result: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.FRONT, arc_pts)
	assert_false(result, "Point behind should NOT be in FRONT arc")


func test_point_in_rear_arc_returns_true_for_point_behind() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var point: Vector2 = Vector2(500, 700)
	var result: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.REAR, arc_pts)
	assert_true(result, "Point behind should be in REAR arc")


func test_point_in_left_arc_returns_true_for_point_left() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var point: Vector2 = Vector2(300, 500)  # directly left
	var result: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.LEFT, arc_pts)
	assert_true(result, "Point to the left should be in LEFT arc")


func test_point_in_right_arc_returns_true_for_point_right() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var point: Vector2 = Vector2(700, 500)  # directly right
	var result: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.RIGHT, arc_pts)
	assert_true(result, "Point to the right should be in RIGHT arc")


func test_point_in_arc_with_rotation_returns_correct() -> void:
	# Ship rotated 90° clockwise — front now points to the right (+X).
	var pos: Vector2 = Vector2(500, 500)
	var rot: float = PI / 2.0
	var arc_pts: Dictionary = _make_arc_pts(pos, rot)
	var point: Vector2 = Vector2(700, 500)  # to the right = front
	var result: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.FRONT, arc_pts)
	assert_true(result, "Point ahead of rotated ship should be in FRONT arc")


func test_point_on_boundary_is_in_both_adjacent_arcs() -> void:
	# Point exactly on the front-left boundary line should be in both
	# FRONT and LEFT arcs (TL-ARC-002).
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	# The front-left boundary goes from centre toward (-20, -35) normalised.
	var boundary_dir: Vector2 = Vector2(-20, -35).normalized()
	var point: Vector2 = pos + boundary_dir * 50.0
	var in_front: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.FRONT, arc_pts)
	var in_left: bool = RangeFinder.is_point_in_arc(
			point, Constants.HullZone.LEFT, arc_pts)
	assert_true(in_front, "Boundary point should be in FRONT arc")
	assert_true(in_left, "Boundary point should be in LEFT arc")


# =========================================================================
# is_hull_zone_edge_in_arc
# =========================================================================

func test_hull_zone_edge_in_arc_returns_true_when_edge_ahead() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	# Defender's front edge is 200px ahead.
	var def_start: Vector2 = Vector2(480, 300)
	var def_end: Vector2 = Vector2(520, 300)
	var result: bool = RangeFinder.is_hull_zone_edge_in_arc(
			def_start, def_end, Constants.HullZone.FRONT, arc_pts)
	assert_true(result, "Edge ahead should be in FRONT arc")


func test_hull_zone_edge_in_arc_returns_false_when_edge_behind() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var def_start: Vector2 = Vector2(480, 700)
	var def_end: Vector2 = Vector2(520, 700)
	var result: bool = RangeFinder.is_hull_zone_edge_in_arc(
			def_start, def_end, Constants.HullZone.FRONT, arc_pts)
	assert_false(result, "Edge behind should NOT be in FRONT arc")


# =========================================================================
# is_squadron_in_arc
# =========================================================================

func test_squadron_in_arc_returns_true_when_centre_in_arc() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var squad_pos: Vector2 = Vector2(500, 350)
	var result: bool = RangeFinder.is_squadron_in_arc(
			squad_pos, 15.0, Constants.HullZone.FRONT, arc_pts)
	assert_true(result, "Squadron centre in arc → should be in arc")


func test_squadron_in_arc_returns_true_when_edge_in_arc() -> void:
	# Centre is outside the FRONT arc but the circle edge extends into it.
	# FRONT arc spans roughly ±30° around the Y-negative axis.
	# Centre at (380, 340) is at ~233° from ship — just outside the
	# front-left boundary at ~240°.  Right-side edge at (430, 340) is at
	# ~246° — inside FRONT.
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var squad_pos: Vector2 = Vector2(380, 340)
	var result: bool = RangeFinder.is_squadron_in_arc(
			squad_pos, 50.0, Constants.HullZone.FRONT, arc_pts)
	assert_true(result, "Squadron with edge in arc should be detected")


# =========================================================================
# get_hull_zone_edge
# =========================================================================

func test_hull_zone_edge_front_returns_correct_world_coords() -> void:
	var pos: Vector2 = Vector2(100, 200)
	var rot: float = 0.0
	var hw: float = 20.0
	var hl: float = 35.0
	var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
			pos, rot, hw, hl, Constants.HullZone.FRONT)
	# Front edge in local space: (-20, -35) to (20, -35).
	assert_almost_eq(edge[0].x, 80.0, 0.01, "Front edge start X")
	assert_almost_eq(edge[0].y, 165.0, 0.01, "Front edge start Y")
	assert_almost_eq(edge[1].x, 120.0, 0.01, "Front edge end X")
	assert_almost_eq(edge[1].y, 165.0, 0.01, "Front edge end Y")


func test_hull_zone_edge_rear_returns_correct_world_coords() -> void:
	var pos: Vector2 = Vector2(100, 200)
	var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
			pos, 0.0, 20.0, 35.0, Constants.HullZone.REAR)
	assert_almost_eq(edge[0].y, 235.0, 0.01, "Rear edge Y")
	assert_almost_eq(edge[1].y, 235.0, 0.01, "Rear edge Y")


# =========================================================================
# closest_point_on_segment
# =========================================================================

func test_closest_point_on_segment_midpoint() -> void:
	var a: Vector2 = Vector2(0, 0)
	var b: Vector2 = Vector2(100, 0)
	var p: Vector2 = Vector2(50, 30)
	var cp: Vector2 = RangeFinder.closest_point_on_segment(p, a, b)
	assert_almost_eq(cp.x, 50.0, 0.01, "Closest X should be 50")
	assert_almost_eq(cp.y, 0.0, 0.01, "Closest Y should be 0")


func test_closest_point_on_segment_clamped_start() -> void:
	var a: Vector2 = Vector2(0, 0)
	var b: Vector2 = Vector2(100, 0)
	var p: Vector2 = Vector2(-50, 0)
	var cp: Vector2 = RangeFinder.closest_point_on_segment(p, a, b)
	assert_almost_eq(cp.x, 0.0, 0.01, "Should clamp to start")


func test_closest_point_on_segment_clamped_end() -> void:
	var a: Vector2 = Vector2(0, 0)
	var b: Vector2 = Vector2(100, 0)
	var p: Vector2 = Vector2(150, 0)
	var cp: Vector2 = RangeFinder.closest_point_on_segment(p, a, b)
	assert_almost_eq(cp.x, 100.0, 0.01, "Should clamp to end")


# =========================================================================
# measure_attack_range_ship
# =========================================================================

func test_measure_attack_range_ship_returns_inf_when_no_portion_in_arc() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var atk_edge: Array[Vector2] = [Vector2(480, 465), Vector2(520, 465)]
	# Defender behind the attacker — not in FRONT arc.
	var def_edge: Array[Vector2] = [Vector2(480, 700), Vector2(520, 700)]
	var dist: float = RangeFinder.measure_attack_range_ship(
			atk_edge, def_edge, Constants.HullZone.FRONT, arc_pts)
	assert_eq(dist, INF, "No portion in arc → should return INF")


func test_measure_attack_range_ship_returns_distance_when_in_arc() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var atk_edge: Array[Vector2] = [Vector2(480, 465), Vector2(520, 465)]
	# Defender 100px ahead, centred.
	var def_edge: Array[Vector2] = [Vector2(480, 365), Vector2(520, 365)]
	var dist: float = RangeFinder.measure_attack_range_ship(
			atk_edge, def_edge, Constants.HullZone.FRONT, arc_pts)
	assert_almost_eq(dist, 100.0, 1.0,
			"Distance should be ~100 px between parallel edges")


# =========================================================================
# measure_attack_range_squadron
# =========================================================================

func test_measure_attack_range_squadron_returns_distance() -> void:
	var pos: Vector2 = Vector2(500, 500)
	var arc_pts: Dictionary = _make_arc_pts(pos, 0.0)
	var atk_edge: Array[Vector2] = [Vector2(480, 465), Vector2(520, 465)]
	var squad_pos: Vector2 = Vector2(500, 350)
	var radius: float = 15.0
	var dist: float = RangeFinder.measure_attack_range_squadron(
			atk_edge, squad_pos, radius, Constants.HullZone.FRONT, arc_pts)
	# Distance from atk_edge (Y=465) to closest circle point (Y=350+15=365).
	assert_almost_eq(dist, 100.0, 2.0,
			"Distance should be ~100 px to squadron edge")


# =========================================================================
# max_attack_range_band
# =========================================================================

func test_max_attack_range_band_red_returns_long() -> void:
	assert_eq(RangeFinder.max_attack_range_band({"RED": 2, "BLUE": 1}),
			"long", "Red dice → long range")


func test_max_attack_range_band_blue_only_returns_medium() -> void:
	assert_eq(RangeFinder.max_attack_range_band({"BLUE": 2}),
			"medium", "Blue only → medium range")


func test_max_attack_range_band_black_only_returns_close() -> void:
	assert_eq(RangeFinder.max_attack_range_band({"BLACK": 3}),
			"close", "Black only → close range")


# =========================================================================
# is_within_max_range
# =========================================================================

func test_is_within_max_range_close_in_medium_max_returns_true() -> void:
	assert_true(RangeFinder.is_within_max_range("close", {"BLUE": 1}),
			"Close ≤ medium max → true")


func test_is_within_max_range_long_in_medium_max_returns_false() -> void:
	assert_false(RangeFinder.is_within_max_range("long", {"BLUE": 1}),
			"Long > medium max → false")


func test_is_within_max_range_medium_in_long_max_returns_true() -> void:
	assert_true(RangeFinder.is_within_max_range("medium", {"RED": 1}),
			"Medium ≤ long max → true")


func test_is_within_max_range_beyond_returns_false() -> void:
	assert_false(RangeFinder.is_within_max_range("beyond", {"RED": 1}),
			"Beyond > any max → false")


# =========================================================================
# dice_at_range
# =========================================================================

func test_dice_at_range_close_returns_all_dice() -> void:
	var arm: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 3}
	var dice: Dictionary = RangeFinder.dice_at_range(arm, "close")
	assert_eq(dice.get("RED", 0), 2, "Close: red included")
	assert_eq(dice.get("BLUE", 0), 1, "Close: blue included")
	assert_eq(dice.get("BLACK", 0), 3, "Close: black included")


func test_dice_at_range_medium_excludes_black() -> void:
	var arm: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 3}
	var dice: Dictionary = RangeFinder.dice_at_range(arm, "medium")
	assert_eq(dice.get("RED", 0), 2, "Medium: red included")
	assert_eq(dice.get("BLUE", 0), 1, "Medium: blue included")
	assert_false(dice.has("BLACK"), "Medium: black excluded")


func test_dice_at_range_long_red_only() -> void:
	var arm: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 3}
	var dice: Dictionary = RangeFinder.dice_at_range(arm, "long")
	assert_eq(dice.get("RED", 0), 2, "Long: red included")
	assert_false(dice.has("BLUE"), "Long: blue excluded")
	assert_false(dice.has("BLACK"), "Long: black excluded")


# =========================================================================
# format_dice
# =========================================================================

func test_format_dice_mixed() -> void:
	var dice: Dictionary = {"RED": 2, "BLUE": 1}
	assert_eq(RangeFinder.format_dice(dice), "2 red, 1 blue",
			"Format should list red then blue")


func test_format_dice_empty() -> void:
	assert_eq(RangeFinder.format_dice({}), "no dice",
			"Empty dict → 'no dice'")

## Unit tests for LineOfSightChecker.
##
## Tests LOS tracing ship-to-ship and ship-to-squadron, hull-zone blocking,
## obstruction detection, and segment-vs-polygon intersection.
##
## Requirements: TL-LOS-001–009, AC-TL-16.
extends GutTest


# =========================================================================
# Helpers
# =========================================================================

## Creates minimal arc boundary points for a ship at pos with rotation.
func _make_arc_pts(pos: Vector2, rot: float) -> Dictionary:
	var hw: float = 20.0
	var hl: float = 35.0
	var centre: Vector2 = pos
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


## Creates an ObstructionBody for a rectangle centred at pos with given size.
func _make_body(
		ship_name: String, pos: Vector2, rot: float,
		hw: float, hl: float) -> LineOfSightChecker.ObstructionBody:
	return LineOfSightChecker.ObstructionBody.from_ship_base(
			ship_name, pos, rot, hw, hl)


# =========================================================================
# segment_intersects_polygon
# =========================================================================

func test_segment_intersects_polygon_true_for_crossing_segment() -> void:
	# Arrange — a 40×40 square centred at (100, 100).
	var poly: Array[Vector2] = [
		Vector2(80, 80), Vector2(120, 80),
		Vector2(120, 120), Vector2(80, 120),
	]
	# Segment cuts right through the square.
	var p1: Vector2 = Vector2(60, 100)
	var p2: Vector2 = Vector2(140, 100)
	# Act / Assert
	assert_true(LineOfSightChecker.segment_intersects_polygon(p1, p2, poly),
			"Segment crossing polygon should return true")


func test_segment_intersects_polygon_true_for_endpoint_inside() -> void:
	var poly: Array[Vector2] = [
		Vector2(0, 0), Vector2(100, 0),
		Vector2(100, 100), Vector2(0, 100),
	]
	var p1: Vector2 = Vector2(50, 50)  # inside
	var p2: Vector2 = Vector2(200, 200)
	assert_true(LineOfSightChecker.segment_intersects_polygon(p1, p2, poly),
			"Segment with endpoint inside should return true")


func test_segment_intersects_polygon_false_for_miss() -> void:
	var poly: Array[Vector2] = [
		Vector2(0, 0), Vector2(100, 0),
		Vector2(100, 100), Vector2(0, 100),
	]
	var p1: Vector2 = Vector2(200, 0)
	var p2: Vector2 = Vector2(200, 100)
	assert_false(LineOfSightChecker.segment_intersects_polygon(p1, p2, poly),
			"Segment missing polygon should return false")


func test_segment_intersects_polygon_false_for_too_few_vertices() -> void:
	var poly: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0)]
	var p1: Vector2 = Vector2(50, -10)
	var p2: Vector2 = Vector2(50, 10)
	assert_false(LineOfSightChecker.segment_intersects_polygon(p1, p2, poly),
			"Polygon with < 3 vertices should return false")


# =========================================================================
# trace_los_ship_to_ship — clear LOS
# =========================================================================

func test_los_ship_to_ship_clear_when_direct_path() -> void:
	# Arrange — attacker at (500, 700), defender at (500, 300).
	# Both facing up (rot = 0).
	# LOS from attacker FRONT → defender REAR (closest).
	var atk_los: Vector2 = Vector2(500, 665)  # front LOS point
	var def_los: Vector2 = Vector2(500, 335)  # rear LOS point
	var def_pos: Vector2 = Vector2(500, 300)
	var def_hw: float = 20.0
	var def_hl: float = 35.0
	# Act
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_ship(
					atk_los, def_los, Constants.HullZone.REAR,
					def_pos, 0.0, def_hw, def_hl, [], [])
	# Assert
	assert_true(result.has_los, "Clear LOS should have line of sight")
	assert_false(result.obstructed, "Clear LOS should not be obstructed")


# =========================================================================
# trace_los_ship_to_ship — blocked by other hull zone
# =========================================================================

func test_los_blocked_when_enters_through_different_hull_zone() -> void:
	# Arrange — attacker is to the left of a defender who faces straight up.
	# LOS from the attacker enters the defender's LEFT zone but we claim
	# the defending zone is FRONT.
	var atk_los: Vector2 = Vector2(200, 300)
	var def_los: Vector2 = Vector2(500, 265)  # defender's front LOS point
	var def_pos: Vector2 = Vector2(500, 300)
	var def_hw: float = 20.0
	var def_hl: float = 35.0
	# Act
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_ship(
					atk_los, def_los, Constants.HullZone.FRONT,
					def_pos, 0.0, def_hw, def_hl, [], [])
	# Assert
	assert_false(result.has_los,
			"LOS entering through LEFT should block FRONT zone")


# =========================================================================
# trace_los_ship_to_ship — obstructed by intervening ship
# =========================================================================

func test_los_obstructed_by_intervening_ship() -> void:
	# Arrange — direct path, but a ship sits between attacker and defender.
	var atk_los: Vector2 = Vector2(500, 700)
	var def_los: Vector2 = Vector2(500, 300)
	var def_pos: Vector2 = Vector2(500, 300)
	var def_hw: float = 20.0
	var def_hl: float = 35.0
	var blocker: LineOfSightChecker.ObstructionBody = _make_body(
			"Blocker", Vector2(500, 500), 0.0, 20.0, 35.0)
	# Act
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_ship(
					atk_los, def_los, Constants.HullZone.REAR,
					def_pos, 0.0, def_hw, def_hl, [blocker], [])
	# Assert
	assert_true(result.has_los, "LOS should still exist (obstructed != blocked)")
	assert_true(result.obstructed, "LOS should be obstructed by intervening ship")
	assert_has(result.obstructed_by, "Blocker",
			"Obstructed_by should contain the blocker name")


# =========================================================================
# trace_los_ship_to_squadron
# =========================================================================

func test_los_ship_to_squadron_clear() -> void:
	var atk_los: Vector2 = Vector2(500, 600)
	var squad_centre: Vector2 = Vector2(500, 400)
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_squadron(
					atk_los, squad_centre, 15.0, [], [])
	assert_true(result.has_los, "Clear LOS to squadron")
	assert_false(result.obstructed, "Should not be obstructed")


func test_los_ship_to_squadron_obstructed() -> void:
	var atk_los: Vector2 = Vector2(500, 600)
	var squad_centre: Vector2 = Vector2(500, 300)
	var blocker: LineOfSightChecker.ObstructionBody = _make_body(
			"Intervener", Vector2(500, 450), 0.0, 25.0, 25.0)
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_squadron(
					atk_los, squad_centre, 15.0, [blocker], [])
	assert_true(result.has_los, "Has LOS but obstructed")
	assert_true(result.obstructed, "Should be obstructed")
	assert_has(result.obstructed_by, "Intervener",
			"Obstructed by should include intervener")


# =========================================================================
# trace_los_squad_to_ship — clear LOS
# =========================================================================

func test_los_squad_to_ship_clear_when_direct_path() -> void:
	# Arrange — squadron directly behind (south of) defender facing up.
	# LOS targets the REAR hull zone — enters through REAR edge.
	var squad_centre: Vector2 = Vector2(500, 500)
	var squad_r: float = 15.0
	var def_los: Vector2 = Vector2(500, 335)  # rear targeting point
	var def_pos: Vector2 = Vector2(500, 300)
	var def_hw: float = 20.0
	var def_hl: float = 35.0
	# Act
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_squad_to_ship(
					squad_centre, squad_r,
					def_los, Constants.HullZone.REAR,
					def_pos, 0.0, def_hw, def_hl, [], [])
	# Assert
	assert_true(result.has_los,
			"Clear squad→ship LOS should have line of sight")
	assert_false(result.obstructed,
			"Clear squad→ship LOS should not be obstructed")


# =========================================================================
# trace_los_squad_to_ship — blocked by other hull zone
# =========================================================================

func test_los_squad_to_ship_blocked_by_other_hull_zone() -> void:
	# Arrange — squadron is to the left of defender facing up.
	# LOS targets the FRONT hull zone — but the line enters through LEFT.
	var squad_centre: Vector2 = Vector2(200, 300)
	var squad_r: float = 15.0
	var def_los: Vector2 = Vector2(500, 265)  # front targeting point
	var def_pos: Vector2 = Vector2(500, 300)
	var def_hw: float = 20.0
	var def_hl: float = 35.0
	# Act
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_squad_to_ship(
					squad_centre, squad_r,
					def_los, Constants.HullZone.FRONT,
					def_pos, 0.0, def_hw, def_hl, [], [])
	# Assert
	assert_false(result.has_los,
			"Squad LOS entering through LEFT should block FRONT zone")


# =========================================================================
# trace_los_squad_to_ship — obstructed by intervening ship
# =========================================================================

func test_los_squad_to_ship_obstructed_by_intervening_ship() -> void:
	# Arrange — direct path, but a ship sits between squadron and defender.
	var squad_centre: Vector2 = Vector2(500, 600)
	var squad_r: float = 15.0
	var def_los: Vector2 = Vector2(500, 335)  # rear targeting point
	var def_pos: Vector2 = Vector2(500, 300)
	var def_hw: float = 20.0
	var def_hl: float = 35.0
	var blocker: LineOfSightChecker.ObstructionBody = _make_body(
			"Blocker", Vector2(500, 450), 0.0, 20.0, 35.0)
	# Act
	var result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_squad_to_ship(
					squad_centre, squad_r,
					def_los, Constants.HullZone.REAR,
					def_pos, 0.0, def_hw, def_hl, [blocker], [])
	# Assert
	assert_true(result.has_los,
			"LOS should still exist (obstructed != blocked)")
	assert_true(result.obstructed,
			"LOS should be obstructed by intervening ship")
	assert_has(result.obstructed_by, "Blocker",
			"Obstructed_by should contain the blocker name")


# =========================================================================
# is_range_path_blocked
# =========================================================================

func test_range_path_blocked_returns_false_for_correct_zone() -> void:
	# Arrange — range path enters defender base through FRONT edge.
	var atk_pt: Vector2 = Vector2(500, 100)
	var def_pt: Vector2 = Vector2(500, 265)  # on front edge
	var def_pos: Vector2 = Vector2(500, 300)
	# Act
	var blocked: bool = LineOfSightChecker.is_range_path_blocked(
			atk_pt, def_pt, Constants.HullZone.FRONT,
			def_pos, 0.0, 20.0, 35.0)
	# Assert
	assert_false(blocked,
			"Range path entering correct zone should not be blocked")


func test_range_path_blocked_returns_true_for_wrong_zone() -> void:
	# Arrange — range path comes from the left side into the base.
	var atk_pt: Vector2 = Vector2(200, 300)
	var def_pt: Vector2 = Vector2(480, 300)  # on left edge
	var def_pos: Vector2 = Vector2(500, 300)
	# Claim it's targeting the FRONT zone.
	var blocked: bool = LineOfSightChecker.is_range_path_blocked(
			atk_pt, def_pt, Constants.HullZone.FRONT,
			def_pos, 0.0, 20.0, 35.0)
	assert_true(blocked,
			"Range path entering through LEFT should block FRONT zone")


# =========================================================================
# ObstructionBody
# =========================================================================

func test_obstruction_body_from_ship_base_creates_4_corners() -> void:
	var body: LineOfSightChecker.ObstructionBody = \
			LineOfSightChecker.ObstructionBody.from_ship_base(
					"TestShip", Vector2(100, 200), 0.0, 20.0, 35.0)
	assert_eq(body.entity_name, "TestShip", "Name should match")
	assert_eq(body.polygon.size(), 4, "Should have 4 corners")


func test_obstruction_body_corners_match_expected_positions() -> void:
	var body: LineOfSightChecker.ObstructionBody = \
			LineOfSightChecker.ObstructionBody.from_ship_base(
					"Ship", Vector2(0, 0), 0.0, 10.0, 20.0)
	# Corners should be at (-10,-20), (10,-20), (10,20), (-10,20).
	assert_almost_eq(body.polygon[0].x, -10.0, 0.01, "TL corner X")
	assert_almost_eq(body.polygon[0].y, -20.0, 0.01, "TL corner Y")
	assert_almost_eq(body.polygon[1].x, 10.0, 0.01, "TR corner X")
	assert_almost_eq(body.polygon[2].x, 10.0, 0.01, "BR corner X")
	assert_almost_eq(body.polygon[2].y, 20.0, 0.01, "BR corner Y")
	assert_almost_eq(body.polygon[3].x, -10.0, 0.01, "BL corner X")

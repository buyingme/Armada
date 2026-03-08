## Tests for FiringArc
##
## Covers: arc membership for all 4 hull zones, boundary-on-arc (AT-042),
##   origin (no-arc), 45° diagonal boundary positions, far-field points.
##
## Rules Reference: "Firing Arcs", p.3; AT-041, AT-042
extends GutTest


## Helper: create a small ship base at the origin, facing -Y (no rotation).
func _make_base() -> ShipBase:
	return ShipBase.new(Constants.ShipSize.SMALL, Transform2D.IDENTITY)


func _make_arc(base: ShipBase) -> FiringArc:
	return FiringArc.new(base)


# ---------------------------------------------------------------------------
# Basic directional arc membership (ship at origin, facing -Y = NORTH)
# ---------------------------------------------------------------------------

func test_point_directly_ahead_is_in_front_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	# Directly ahead = negative Y
	var result: bool = arc.is_in_arc(Vector2(0.0, -500.0), Constants.HullZone.FRONT)
	assert_true(result, "Point directly ahead should be in FRONT arc")


func test_point_directly_ahead_is_not_in_rear_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var result: bool = arc.is_in_arc(Vector2(0.0, -500.0), Constants.HullZone.REAR)
	assert_false(result, "Point directly ahead should not be in REAR arc")


func test_point_directly_behind_is_in_rear_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var result: bool = arc.is_in_arc(Vector2(0.0, 500.0), Constants.HullZone.REAR)
	assert_true(result, "Point directly behind should be in REAR arc")


func test_point_directly_right_is_in_right_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var result: bool = arc.is_in_arc(Vector2(500.0, 0.0), Constants.HullZone.RIGHT)
	assert_true(result, "Point to starboard should be in RIGHT arc")


func test_point_directly_left_is_in_left_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var result: bool = arc.is_in_arc(Vector2(-500.0, 0.0), Constants.HullZone.LEFT)
	assert_true(result, "Point to port should be in LEFT arc")


func test_point_directly_right_is_not_in_front_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var result: bool = arc.is_in_arc(Vector2(500.0, 0.0), Constants.HullZone.FRONT)
	assert_false(result, "Point to starboard should not be in FRONT arc")


func test_point_directly_left_is_not_in_rear_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var result: bool = arc.is_in_arc(Vector2(-500.0, 0.0), Constants.HullZone.REAR)
	assert_false(result, "Point to port should not be in REAR arc")


# ---------------------------------------------------------------------------
# 45-degree boundary points (AT-042 — on boundary = in arc for both adjacent)
# ---------------------------------------------------------------------------

func test_front_right_boundary_is_in_front_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	# 45° forward-starboard diagonal
	var p: Vector2 = Vector2(400.0, -400.0).normalized() * 500.0
	var result: bool = arc.is_in_arc(p, Constants.HullZone.FRONT)
	assert_true(result, "FRONT/RIGHT boundary should be in FRONT arc (AT-042)")


func test_front_right_boundary_is_in_right_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var p: Vector2 = Vector2(400.0, -400.0).normalized() * 500.0
	var result: bool = arc.is_in_arc(p, Constants.HullZone.RIGHT)
	assert_true(result, "FRONT/RIGHT boundary should be in RIGHT arc (AT-042)")


func test_rear_left_boundary_is_in_rear_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var p: Vector2 = Vector2(-400.0, 400.0).normalized() * 500.0
	var result: bool = arc.is_in_arc(p, Constants.HullZone.REAR)
	assert_true(result, "REAR/LEFT boundary should be in REAR arc (AT-042)")


func test_rear_left_boundary_is_in_left_arc() -> void:
	var arc: FiringArc = _make_arc(_make_base())
	var p: Vector2 = Vector2(-400.0, 400.0).normalized() * 500.0
	var result: bool = arc.is_in_arc(p, Constants.HullZone.LEFT)
	assert_true(result, "REAR/LEFT boundary should be in LEFT arc (AT-042)")


# ---------------------------------------------------------------------------
# Rotated ship — arc moves with ship orientation
# ---------------------------------------------------------------------------

func test_rotated_ship_front_arc_follows_orientation() -> void:
	# Ship rotated 90° CW — now faces +X (right).
	var base: ShipBase = ShipBase.new(
			Constants.ShipSize.SMALL,
			Transform2D(PI * 0.5, Vector2.ZERO))
	var arc: FiringArc = FiringArc.new(base)
	# Ship faces +X now, so +X should be in FRONT arc.
	var result: bool = arc.is_in_arc(Vector2(500.0, 0.0), Constants.HullZone.FRONT)
	assert_true(result, "Rotated ship: +X point should be in FRONT arc")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_is_at_origin_returns_true_for_ship_centre() -> void:
	var base: ShipBase = _make_base()
	var arc: FiringArc = FiringArc.new(base)
	var result: bool = arc.is_at_origin(Vector2(0.0, 0.0))
	assert_true(result, "Ship centre itself should be at origin")


func test_is_at_origin_returns_false_for_distant_point() -> void:
	var base: ShipBase = _make_base()
	var arc: FiringArc = FiringArc.new(base)
	var result: bool = arc.is_at_origin(Vector2(100.0, 0.0))
	assert_false(result, "Non-centre point should not be at origin")

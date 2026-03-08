## Geometry2DHelper
##
## Pure 2D geometry utilities: point-in-polygon, segment intersection,
## closest-point-on-segment, polygon overlap, and related helpers.
##
## All methods are static. No scene tree dependency.
## Intended for reuse by FiringArc, RangeMeasurer, and future LOS systems.
##
## Rules Reference: "Firing Arc", p.3; "Range and Distance", p.10
class_name Geometry2DHelper
extends RefCounted


## Returns true if point p is strictly inside the convex or non-convex polygon.
## Uses ray-casting algorithm.
## Rules Reference: Used to determine if a target point is within a firing arc.
static func point_in_polygon(p: Vector2, polygon: PackedVector2Array) -> bool:
	var n: int = polygon.size()
	if n < 3:
		return false
	var inside: bool = false
	var j: int = n - 1
	for i: int in range(n):
		var xi: float = polygon[i].x
		var yi: float = polygon[i].y
		var xj: float = polygon[j].x
		var yj: float = polygon[j].y
		var intersect: bool = ((yi > p.y) != (yj > p.y)) and \
			(p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi)
		if intersect:
			inside = not inside
		j = i
	return inside


## Returns true if point p lies on the line segment (a, b) within tolerance.
static func point_on_segment(p: Vector2, a: Vector2, b: Vector2,
		tolerance: float = 0.5) -> bool:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var cross: float = ab.cross(ap)
	if abs(cross) > tolerance * ab.length():
		return false
	var dot: float = ab.dot(ap)
	if dot < 0.0:
		return false
	var len_sq: float = ab.length_squared()
	return dot <= len_sq


## Returns the closest point on segment (a, b) to point p.
## Rules Reference: Used for closest-point range measurement (AT-050–052).
static func closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq == 0.0:
		return a
	var t: float = clampf(ab.dot(p - a) / len_sq, 0.0, 1.0)
	return a + t * ab


## Returns the closest point on the edges of a polygon to point p.
## Rules Reference: AT-050 — range measured to closest point of hull zone.
static func closest_point_on_polygon(p: Vector2,
		polygon: PackedVector2Array) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	var n: int = polygon.size()
	for i: int in range(n):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % n]
		var candidate: Vector2 = closest_point_on_segment(p, a, b)
		var d: float = p.distance_squared_to(candidate)
		if d < best_dist:
			best_dist = d
			best = candidate
	return best


## Returns the minimum distance from point p to any edge of the polygon.
static func distance_point_to_polygon(p: Vector2,
		polygon: PackedVector2Array) -> float:
	if point_in_polygon(p, polygon):
		return 0.0
	return p.distance_to(closest_point_on_polygon(p, polygon))


## Returns true if two line segments (a1,a2) and (b1,b2) intersect.
## Rules Reference: Used for firing arc boundary intersection checks (AT-042).
static func segments_intersect(a1: Vector2, a2: Vector2,
		b1: Vector2, b2: Vector2) -> bool:
	var r: Vector2 = a2 - a1
	var s: Vector2 = b2 - b1
	var denom: float = r.cross(s)
	if abs(denom) < 1e-6:
		return false
	var t: float = (b1 - a1).cross(s) / denom
	var u: float = (b1 - a1).cross(r) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


## Returns the intersection point of two infinite lines defined by (a1,a2)
## and (b1,b2). Returns Vector2.INF if lines are parallel.
static func line_intersection(a1: Vector2, a2: Vector2,
		b1: Vector2, b2: Vector2) -> Vector2:
	var r: Vector2 = a2 - a1
	var s: Vector2 = b2 - b1
	var denom: float = r.cross(s)
	if abs(denom) < 1e-6:
		return Vector2(INF, INF)
	var t: float = (b1 - a1).cross(s) / denom
	return a1 + t * r


## Returns the minimum distance between two convex or non-convex polygons.
## Uses closest-point sampling over each polygon's edges.
## Rules Reference: AT-050 — range measurement between hull zones.
static func distance_polygon_to_polygon(poly_a: PackedVector2Array,
		poly_b: PackedVector2Array) -> float:
	var best: float = INF
	var n_a: int = poly_a.size()
	var n_b: int = poly_b.size()

	# Check vertices of A against edges of B.
	for i: int in range(n_a):
		var d: float = distance_point_to_polygon(poly_a[i], poly_b)
		if d < best:
			best = d

	# Check vertices of B against edges of A.
	for i: int in range(n_b):
		var d: float = distance_point_to_polygon(poly_b[i], poly_a)
		if d < best:
			best = d

	# Check for edge intersections — if any edges cross, polygons overlap → 0.
	# The vertex-to-edge loops above cover all non-crossing minimum distances.
	for i: int in range(n_a):
		var a1: Vector2 = poly_a[i]
		var a2: Vector2 = poly_a[(i + 1) % n_a]
		for j: int in range(n_b):
			var b1: Vector2 = poly_b[j]
			var b2: Vector2 = poly_b[(j + 1) % n_b]
			if segments_intersect(a1, a2, b1, b2):
				return 0.0

	return best


## Rotates a polygon by angle_rad around origin (0, 0), then translates by offset.
static func transform_polygon(polygon: PackedVector2Array,
		angle_rad: float, offset: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(polygon.size())
	for i: int in range(polygon.size()):
		result[i] = polygon[i].rotated(angle_rad) + offset
	return result


## Builds a rectangle polygon centred at origin, aligned along the Y axis.
## Width = x dimension, height = y dimension.
static func make_rect_polygon(width: float, height: float) -> PackedVector2Array:
	var hw: float = width * 0.5
	var hh: float = height * 0.5
	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(Vector2(-hw, -hh))
	poly.append(Vector2(hw, -hh))
	poly.append(Vector2(hw, hh))
	poly.append(Vector2(-hw, hh))
	return poly


## Builds a regular polygon approximating a circle (for squadron base overlap).
static func make_circle_polygon(radius: float, segments: int = 16) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments):
		var angle: float = (TAU / float(segments)) * float(i)
		poly.append(Vector2(cos(angle), sin(angle)) * radius)
	return poly

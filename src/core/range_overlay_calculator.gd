## RangeOverlayCalculator
##
## Computes the geometry for a per-arc range overlay around a ship:
## arc boundary lines (extended), and range-band fill polygons (close,
## medium, long) clipped to each firing arc.
##
## All coordinates are in world space (pixels). The caller converts
## PNG-space boundary points to world space before passing them here.
##
## For each hull zone the calculator builds a hull zone polygon (the area
## of the ship token within the two bounding arc lines), then creates
## Minkowski sums (Geometry2D.offset_polygon with JOIN_ROUND) of that
## hull zone polygon at each range distance. This ensures the distance
## is measured from the closest point of the attacking hull zone, not
## from the full ship base.
##
## Rules Reference: "Measuring Firing Arc and Range" — "To measure attack
##   range from a ship, measure from the closest point of the attacking
##   hull zone." / "Hull Zones" — "A hull zone is a section of a ship
##   token delineated by the two firing arc lines that border it."
##   RO-003, RO-004, RO-005.
class_name RangeOverlayCalculator
extends RefCounted


## Factor beyond long range for the drawn boundary lines.
## Lines extend 1.2 × ruler length from the outer point.
## Rules Reference: RO-003.
const ARC_LINE_EXTENSION_FACTOR: float = 1.2

## Extension for the clipping sector polygon (generous margin so it always
## encloses the offset polygons).
const SECTOR_EXTENSION_PX: float = 2500.0

## Minimum number of vertices for a valid polygon.
const MIN_POLY_VERTS: int = 3

# --- Results (populated by compute()) ---

## Boundary line segments: Array of [from: Vector2, to: Vector2].
## 4 entries (one per boundary line).
var arc_lines: Array = []

## Band fill polygons keyed by hull zone then band name.
## {Constants.HullZone.FRONT: {"close": Array[PackedVector2Array], …}, …}
var band_polygons: Dictionary = {}


## Computes the overlay geometry.
## [param base_poly] — ship base polygon in world space (4 verts, CW in screen).
##   Vertices ordered: 0=front-left, 1=front-right, 2=rear-right, 3=rear-left.
## [param boundaries] — world-space arc boundary points (8 keys, same names as
##   ShipData.firing_arc_boundaries).
## [param close_px] — close-range distance in pixels.
## [param medium_px] — medium-range distance in pixels.
## [param long_px] — long-range distance in pixels.
func compute(
		base_poly: PackedVector2Array,
		boundaries: Dictionary,
		close_px: float,
		medium_px: float,
		long_px: float) -> void:
	arc_lines.clear()
	band_polygons.clear()
	if base_poly.size() < MIN_POLY_VERTS or boundaries.is_empty():
		return

	# Ensure clockwise winding (Godot 2D screen-space convention).
	var base: PackedVector2Array = _ensure_cw(base_poly)

	# Unpack boundary points.
	var ifl: Vector2 = boundaries.get("inner_point_front_left", Vector2.ZERO)
	var ofl: Vector2 = boundaries.get("outer_point_front_left", Vector2.ZERO)
	var ifr: Vector2 = boundaries.get("inner_point_front_right", Vector2.ZERO)
	var ofr: Vector2 = boundaries.get("outer_point_front_right", Vector2.ZERO)
	var irl: Vector2 = boundaries.get("inner_point_rear_left", Vector2.ZERO)
	var orl: Vector2 = boundaries.get("outer_point_rear_left", Vector2.ZERO)
	var irr: Vector2 = boundaries.get("inner_point_rear_right", Vector2.ZERO)
	var orr: Vector2 = boundaries.get("outer_point_rear_right", Vector2.ZERO)

	# Build boundary lines (extended from inner through outer).
	var line_ext: float = long_px * ARC_LINE_EXTENSION_FACTOR
	arc_lines = _build_arc_lines(
			ifl, ofl, ifr, ofr, irl, orl, irr, orr, line_ext)

	# Per-arc definitions: boundary points + base corner indices for the
	# hull zone polygon.  Each hull zone's edge is the ship base edge
	# between the two outer boundary points on that zone's side.
	# Base polygon vertices: 0=front-left, 1=front-right,
	#   2=rear-right, 3=rear-left.
	var arc_defs: Array = [
		{
			"zone": Constants.HullZone.FRONT,
			"ia": ifl, "oa": ofl, "ib": ifr, "ob": ofr,
			"corners": [0, 1],
		},
		{
			"zone": Constants.HullZone.LEFT,
			"ia": irl, "oa": orl, "ib": ifl, "ob": ofl,
			"corners": [3, 0],
		},
		{
			"zone": Constants.HullZone.RIGHT,
			"ia": ifr, "oa": ofr, "ib": irr, "ob": orr,
			"corners": [1, 2],
		},
		{
			"zone": Constants.HullZone.REAR,
			"ia": irr, "oa": orr, "ib": irl, "ob": orl,
			"corners": [2, 3],
		},
	]

	for def_dict: Dictionary in arc_defs:
		var ia: Vector2 = def_dict["ia"]
		var oa: Vector2 = def_dict["oa"]
		var ib: Vector2 = def_dict["ib"]
		var ob: Vector2 = def_dict["ob"]
		var corners: Array = def_dict["corners"]
		var zone: int = def_dict["zone"]

		var sector: PackedVector2Array = _build_sector(ia, oa, ib, ob)
		if sector.size() < MIN_POLY_VERTS:
			continue

		# Build the hull zone polygon — the area of the ship token
		# within this arc.  Range is measured from the closest point
		# of this polygon, NOT from the full base.
		# Rules Reference: "Measuring Firing Arc and Range", p.8.
		var hz_poly: PackedVector2Array = _build_hull_zone_poly(
				ia, oa, ib, ob, base, corners)
		if hz_poly.size() < MIN_POLY_VERTS:
			continue

		# Offset the hull zone polygon (Minkowski sum with circle)
		# at each range distance.
		var off_close_arr: Array = Geometry2D.offset_polygon(
				hz_poly, close_px, Geometry2D.JOIN_ROUND)
		var off_medium_arr: Array = Geometry2D.offset_polygon(
				hz_poly, medium_px, Geometry2D.JOIN_ROUND)
		var off_long_arr: Array = Geometry2D.offset_polygon(
				hz_poly, long_px, Geometry2D.JOIN_ROUND)
		if off_close_arr.is_empty() or off_medium_arr.is_empty() \
				or off_long_arr.is_empty():
			continue

		var hz_off_close: PackedVector2Array = off_close_arr[0]
		var hz_off_medium: PackedVector2Array = off_medium_arr[0]
		var hz_off_long: PackedVector2Array = off_long_arr[0]

		# Close band: outside the full ship base, within close range
		# of the hull zone, clipped to the firing arc sector.
		var close_bands: Array = _ring_in_sector(
				base, hz_off_close, sector)
		# Medium/long: annular rings between successive offsets.
		var medium_bands: Array = _ring_in_sector(
				hz_off_close, hz_off_medium, sector)
		var long_bands: Array = _ring_in_sector(
				hz_off_medium, hz_off_long, sector)

		band_polygons[zone] = {
			"close": close_bands,
			"medium": medium_bands,
			"long": long_bands,
		}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds the hull zone polygon — the area of the ship token within one
## firing arc, bounded by the two arc boundary lines and the base edge
## between them.
## [param inner_a] — inner point of boundary line A.
## [param outer_a] — outer point of boundary line A (on base edge).
## [param inner_b] — inner point of boundary line B.
## [param outer_b] — outer point of boundary line B (on base edge).
## [param base] — full ship base polygon (4 verts, CW).
## [param corner_indices] — indices into [base] for corners between the
##   two outer points (walking CW along the base perimeter).
## Rules Reference: "Hull Zones", p.7 — "A hull zone is a section of a
##   ship token delineated by the two firing arc lines that border it."
static func _build_hull_zone_poly(
		inner_a: Vector2, outer_a: Vector2,
		inner_b: Vector2, outer_b: Vector2,
		base: PackedVector2Array,
		corner_indices: Array) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(inner_a)
	_append_if_unique(pts, outer_a)
	for idx: int in corner_indices:
		_append_if_unique(pts, base[idx])
	_append_if_unique(pts, outer_b)
	_append_if_unique(pts, inner_b)
	return _ensure_cw(pts)


## Appends [pt] to [pts] only if it is farther than 1 px from every
## existing vertex.  Prevents degenerate spikes when boundary points
## coincide with base corners.
static func _append_if_unique(
		pts: PackedVector2Array, pt: Vector2) -> void:
	for existing: Vector2 in pts:
		if pt.distance_to(existing) <= 1.0:
			return
	pts.append(pt)


## Builds the 4 boundary line segments (one per boundary line).
static func _build_arc_lines(
		ifl: Vector2, ofl: Vector2,
		ifr: Vector2, ofr: Vector2,
		irl: Vector2, orl: Vector2,
		irr: Vector2, orr: Vector2,
		ext: float) -> Array:
	return [
		[ifl, _extend_ray(ifl, ofl, ext)],
		[ifr, _extend_ray(ifr, ofr, ext)],
		[irl, _extend_ray(irl, orl, ext)],
		[irr, _extend_ray(irr, orr, ext)],
	]


## Extends a ray from [inner] through [outer] by [dist] beyond [outer].
static func _extend_ray(inner: Vector2, outer: Vector2, dist: float) -> Vector2:
	var dir: Vector2 = (outer - inner).normalized()
	return outer + dir * dist


## Builds the arc sector clipping polygon from two boundary rays.
## The sector is a triangle (if both inner points coincide) or quad.
static func _build_sector(
		inner_a: Vector2, outer_a: Vector2,
		inner_b: Vector2, outer_b: Vector2) -> PackedVector2Array:
	var dir_a: Vector2 = (outer_a - inner_a).normalized()
	var dir_b: Vector2 = (outer_b - inner_b).normalized()
	var far_a: Vector2 = outer_a + dir_a * SECTOR_EXTENSION_PX
	var far_b: Vector2 = outer_b + dir_b * SECTOR_EXTENSION_PX

	var sector: PackedVector2Array = PackedVector2Array()
	sector.append(inner_a)
	sector.append(far_a)
	sector.append(far_b)
	if inner_b.distance_to(inner_a) > 1.0:
		sector.append(inner_b)

	return _ensure_cw(sector)


## Returns the ring (annular region) between [inner_poly] and [outer_poly],
## clipped to [sector]. Result is an array of PackedVector2Array polygons.
static func _ring_in_sector(
		inner_poly: PackedVector2Array,
		outer_poly: PackedVector2Array,
		sector: PackedVector2Array) -> Array:
	var outer_in_sector: Array = Geometry2D.intersect_polygons(
			outer_poly, sector)
	if outer_in_sector.is_empty():
		return []

	var result: Array = []
	for poly: PackedVector2Array in outer_in_sector:
		var clipped: Array = Geometry2D.clip_polygons(poly, inner_poly)
		for c: PackedVector2Array in clipped:
			if c.size() >= MIN_POLY_VERTS:
				result.append(c)
	return result


## Ensures a polygon has clockwise winding (Godot 2D screen convention).
static func _ensure_cw(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < MIN_POLY_VERTS:
		return poly
	if not Geometry2D.is_polygon_clockwise(poly):
		var reversed: PackedVector2Array = PackedVector2Array()
		reversed.resize(poly.size())
		for i: int in range(poly.size()):
			reversed[i] = poly[poly.size() - 1 - i]
		return reversed
	return poly

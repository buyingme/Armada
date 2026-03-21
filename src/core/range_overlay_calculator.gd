## RangeOverlayCalculator
##
## Computes the geometry for a per-arc range overlay around a ship:
## arc boundary lines (extended), and range-band fill polygons (close,
## medium, long) clipped to each firing arc.
##
## All coordinates are in world space (pixels). The caller converts
## PNG-space boundary points to world space before passing them here.
##
## Range bands use Minkowski sums (Geometry2D.offset_polygon with
## JOIN_ROUND) so that the band edges are proper curved arcs at a
## constant distance from the ship base edge.
##
## Rules Reference: "Firing Arcs", p.3; "Range and Distance", p.10;
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
## 8 entries total (2 per arc × 4 arcs).
var arc_lines: Array = []

## Band fill polygons keyed by hull zone then band name.
## {Constants.HullZone.FRONT: {"close": Array[PackedVector2Array], …}, …}
var band_polygons: Dictionary = {}


## Computes the overlay geometry.
## [param base_poly] — ship base polygon in world space (4 verts, CW in screen).
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

	# Compute offset polygons once (shared by all four arcs).
	var off_close: Array = Geometry2D.offset_polygon(
			base, close_px, Geometry2D.JOIN_ROUND)
	var off_medium: Array = Geometry2D.offset_polygon(
			base, medium_px, Geometry2D.JOIN_ROUND)
	var off_long: Array = Geometry2D.offset_polygon(
			base, long_px, Geometry2D.JOIN_ROUND)
	if off_close.is_empty() or off_medium.is_empty() or off_long.is_empty():
		return

	var poly_close: PackedVector2Array = off_close[0]
	var poly_medium: PackedVector2Array = off_medium[0]
	var poly_long: PackedVector2Array = off_long[0]

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

	# Per-arc definitions: zone → [inner_a, outer_a, inner_b, outer_b].
	# Each arc is bounded by two of the four boundary lines.
	var arc_defs: Dictionary = {
		Constants.HullZone.FRONT: [ifl, ofl, ifr, ofr],
		Constants.HullZone.LEFT:  [irl, orl, ifl, ofl],
		Constants.HullZone.RIGHT: [ifr, ofr, irr, orr],
		Constants.HullZone.REAR:  [irr, orr, irl, orl],
	}

	for zone: int in arc_defs:
		var d: Array = arc_defs[zone]
		var sector: PackedVector2Array = _build_sector(d[0], d[1], d[2], d[3])
		if sector.size() < MIN_POLY_VERTS:
			continue

		var close_bands: Array = _ring_in_sector(base, poly_close, sector)
		var medium_bands: Array = _ring_in_sector(poly_close, poly_medium, sector)
		var long_bands: Array = _ring_in_sector(poly_medium, poly_long, sector)

		band_polygons[zone] = {
			"close": close_bands,
			"medium": medium_bands,
			"long": long_bands,
		}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds the 8 boundary line segments (2 per boundary × 4 boundaries).
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

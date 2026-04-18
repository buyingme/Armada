## SquadronBase
##
## Represents the circular base of a squadron token on the play area.
## Radius is derived from GameScale (half the squadron base diameter).
##
## Squadron firing arc is always 360° — any point within range is in arc (AT-043).
## Overlap detection uses circle-polygon and circle-circle intersection.
##
## Rules Reference: "Squadrons", p.11; AT-043; AT-051, AT-052; SM-001, SM-003
class_name SquadronBase
extends RefCounted


## World-space centre position of the squadron token.
var position: Vector2

## Radius of the squadron base in pixels.
var radius_px: float


func _init(pos: Vector2, r: float = -1.0) -> void:
	position = pos
	if r < 0.0:
		radius_px = GameScale.squadron_base_diameter_px * 0.5
	else:
		radius_px = r


## Returns a polygon approximating the circular base (for geometry operations).
func get_polygon(segments: int = 16) -> PackedVector2Array:
	return Geometry2DHelper.make_circle_polygon(radius_px, segments)


## Returns the closest point on the perimeter of this squadron base to target.
func closest_point_to(target: Vector2) -> Vector2:
	if position.distance_squared_to(target) < 0.0001:
		return position + Vector2(radius_px, 0.0)
	var dir: Vector2 = (target - position).normalized()
	return position + dir * radius_px


## Returns true if this squadron base overlaps (or touches) a ship base polygon.
## Rules Reference: SM-001 — squadron cannot be placed overlapping a ship base.
func overlaps_ship(ship: ShipBase) -> bool:
	var base_poly: PackedVector2Array = ship.get_base_polygon()
	# If centre is inside polygon, definitely overlapping.
	if Geometry2DHelper.point_in_polygon(position, base_poly):
		return true
	# Otherwise check if closest point on polygon is within radius.
	var closest: Vector2 = Geometry2DHelper.closest_point_on_polygon(position, base_poly)
	return position.distance_to(closest) <= radius_px


## Returns true if this squadron base overlaps another squadron base.
## Rules Reference: SM-003 — squadrons cannot overlap each other.
func overlaps_squadron(other: SquadronBase) -> bool:
	return position.distance_to(other.position) <= (radius_px + other.radius_px)


## Returns true if the target point is within max_distance_px of the base edge.
## Squadron arc is 360° so only range (not arc) is checked (AT-043).
##
## Rules Reference: AT-043 — squadron tokens have a 360° firing arc.
func is_in_range_of(target_pos: Vector2, max_distance_px: float) -> bool:
	var dist: float = position.distance_to(target_pos)
	return dist - radius_px <= max_distance_px


## Returns the pixel distance from the edge of this base to the target point.
## Negative if target_pos is inside the base.
func distance_to_point(target_pos: Vector2) -> float:
	return position.distance_to(target_pos) - radius_px


## Returns the pixel distance from the edge of this base to the nearest edge
## of another squadron base. Returns 0.0 if overlapping.
func distance_to_squadron(other: SquadronBase) -> float:
	return maxf(0.0, position.distance_to(other.position) - radius_px - other.radius_px)

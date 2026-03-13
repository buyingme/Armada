## ShipBase
##
## Represents the physical footprint of a ship on the play area.
## Computes the base rectangle, hull zone polygons, and firing arc boundary rays.
##
## Coordinate convention: ship faces FORWARD in the -Y direction (Godot default
## for a sprite pointing up). Rotation is applied via the provided Transform2D.
##
## Hull zone layout (local space, Y-up convention, ship faces -Y):
##   FRONT  — leading third of the base (negative Y in local space)
##   REAR   — trailing third (positive Y)
##   LEFT   — port side, middle region (negative X, left when facing -Y)
##   RIGHT  — starboard side, middle region (positive X)
##
## Rules Reference: "Hull Zones", p.4; "Firing Arcs", p.3; AT-010–014
class_name ShipBase
extends RefCounted


## The ship size determines physical base dimensions.
var ship_size: Constants.ShipSize

## World-space transform (position + rotation) of the ships base centre.
var ship_transform: Transform2D

## Half-width and half-length of the base polygon in pixels (local space).
var half_width_px: float
var half_length_px: float


func _init(size: Constants.ShipSize, xform: Transform2D) -> void:
	ship_size = size
	ship_transform = xform
	var base_size: Vector2 = GameScale.get_base_size(size)
	half_width_px = base_size.x * 0.5
	half_length_px = base_size.y * 0.5


## Returns the four corners of the base in world space.
## Corner order: front-left, front-right, rear-right, rear-left.
## Rules Reference: AT-010 — ship occupies its base polygon.
func get_base_polygon() -> PackedVector2Array:
	var local: PackedVector2Array = _local_base_polygon()
	return _to_world(local)


## Returns the world-space polygon for the given hull zone.
## Rules Reference: "Hull Zones", p.4; AT-011
func get_hull_zone_polygon(zone: Constants.HullZone) -> PackedVector2Array:
	var local: PackedVector2Array = _local_hull_zone_polygon(zone)
	return _to_world(local)


## Returns the world-space centre of a hull zone.
## Useful for shield display positioning.
func get_hull_zone_centre(zone: Constants.HullZone) -> Vector2:
	var poly: PackedVector2Array = get_hull_zone_polygon(zone)
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in poly:
		sum += v
	return sum / float(poly.size())


## Returns the two world-space points defining the firing arc boundary ray
## between two adjacent hull zones. These rays are used by FiringArc to
## determine arc membership. All four arcs share the ship centre origin.
##
## Rules Reference: "Firing Arcs", p.3; AT-041
## Rays: FRONT/RIGHT boundary, FRONT/LEFT, REAR/LEFT, REAR/RIGHT
## Arc lines extend at 45° from the ship's long axis at the base centre.
func get_arc_boundary_rays() -> Array[Array]:
	var origin: Vector2 = ship_transform.origin
	# In local space (ship faces -Y), arc boundaries are 45° diagonals
	# from the centre of the base (not edge-to-edge – they extend to infinity).
	# We return two points: the centre and a point far along the ray direction.
	var far: float = 10000.0
	var rays: Array[Array] = []
	var directions: Array[Vector2] = [
		Vector2(1.0, -1.0).normalized(), # FRONT/RIGHT boundary
		Vector2(-1.0, -1.0).normalized(), # FRONT/LEFT boundary
		Vector2(-1.0, 1.0).normalized(), # REAR/LEFT boundary
		Vector2(1.0, 1.0).normalized(), # REAR/RIGHT boundary
	]
	for dir: Vector2 in directions:
		var world_dir: Vector2 = ship_transform.basis_xform(dir)
		rays.append([origin, origin + world_dir * far])
	return rays


## Returns the four notch positions (maneuver tool attachment points) on the
## short edges of the base in world space.
## Rules Reference: "Maneuver", p.7; AT-040
func get_notch_positions() -> Array[Vector2]:
	# Notches are at the midpoints of the two short (width) edges.
	var front_mid: Vector2 = Vector2(0.0, -half_length_px) # leading edge centre
	var rear_mid: Vector2 = Vector2(0.0, half_length_px) # trailing edge centre
	# Two notches per edge, at ±1/4 of the widget
	var result: Array[Vector2] = []
	result.append(_world_point(Vector2(-half_width_px * 0.5, -half_length_px)))
	result.append(_world_point(Vector2(half_width_px * 0.5, -half_length_px)))
	result.append(_world_point(Vector2(-half_width_px * 0.5, half_length_px)))
	result.append(_world_point(Vector2(half_width_px * 0.5, half_length_px)))
	# Suppress unused variable warnings
	var _fn: Vector2 = front_mid
	var _rn: Vector2 = rear_mid
	return result


## Returns world-space centre of the base.
func get_centre() -> Vector2:
	return ship_transform.origin


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds the base rectangle in local space (origin = centre, Y up).
func _local_base_polygon() -> PackedVector2Array:
	return Geometry2DHelper.make_rect_polygon(
			half_width_px * 2.0, half_length_px * 2.0)


## Builds a hull zone polygon in local space.
## Hull zone proportions:
##   FRONT / REAR : occupies the leading/trailing 1/3 of the base length.
##   LEFT / RIGHT : occupies the middle 1/3 of the length and half the width.
##
## Rules Reference: "Hull Zones", p.4; AT-011
func _local_hull_zone_polygon(zone: Constants.HullZone) -> PackedVector2Array:
	var hw: float = half_width_px
	var hl: float = half_length_px
	var third: float = hl * 2.0 / 3.0 # 1/3 of total length
	var front_y: float = - hl # topmost Y (front)
	var rear_y: float = hl # bottommost Y (rear)
	var mid_front_y: float = front_y + third
	var mid_rear_y: float = rear_y - third

	var poly: PackedVector2Array = PackedVector2Array()
	match zone:
		Constants.HullZone.FRONT:
			poly.append(Vector2(-hw, front_y))
			poly.append(Vector2(hw, front_y))
			poly.append(Vector2(hw, mid_front_y))
			poly.append(Vector2(-hw, mid_front_y))
		Constants.HullZone.REAR:
			poly.append(Vector2(-hw, mid_rear_y))
			poly.append(Vector2(hw, mid_rear_y))
			poly.append(Vector2(hw, rear_y))
			poly.append(Vector2(-hw, rear_y))
		Constants.HullZone.LEFT:
			# Port side: negative X half, middle region
			poly.append(Vector2(-hw, mid_front_y))
			poly.append(Vector2(0.0, mid_front_y))
			poly.append(Vector2(0.0, mid_rear_y))
			poly.append(Vector2(-hw, mid_rear_y))
		Constants.HullZone.RIGHT:
			# Starboard side: positive X half, middle region
			poly.append(Vector2(0.0, mid_front_y))
			poly.append(Vector2(hw, mid_front_y))
			poly.append(Vector2(hw, mid_rear_y))
			poly.append(Vector2(0.0, mid_rear_y))
	return poly


## Transforms a polygon from local ship space to world space.
func _to_world(local_poly: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(local_poly.size())
	for i: int in range(local_poly.size()):
		result[i] = ship_transform * local_poly[i]
	return result


## Transforms a single point from local to world space.
func _world_point(local: Vector2) -> Vector2:
	return ship_transform * local

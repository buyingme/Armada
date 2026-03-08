## FiringArc
##
## Determines whether a target is within a ship's firing arc for a given hull zone.
##
## The four firing arcs are defined by the 45° diagonal arc-boundary rays that
## pass through the ship base centre. Arcs extend infinitely outward.
## A target that falls on an arc boundary line is considered inside the arc (AT-042).
##
## Squadron token firing arcs are always 360° (AT-043).
##
## Rules Reference: "Firing Arcs", p.3; AT-041, AT-042, AT-043
class_name FiringArc
extends RefCounted


## The ship base whose arcs are being evaluated.
var ship_base: ShipBase

## Tolerance for arc boundary line membership (pixels). A point within this
## distance of a boundary ray is considered on the line (AT-042).
const ARC_BOUNDARY_TOLERANCE_PX: float = 0.5


func _init(base: ShipBase) -> void:
	ship_base = base


## Returns true if target_point is inside the firing arc for the given hull zone.
## target_point should be the closest point on the target (hull zone or squadron
## base circle) to the attacker — see RangeMeasurer for how to compute this.
##
## Rules Reference: "Firing Arcs", p.3; AT-041, AT-042
func is_in_arc(target_point: Vector2, zone: Constants.HullZone) -> bool:
	var origin: Vector2 = ship_base.get_centre()
	var rel: Vector2 = target_point - origin

	# Transform rel into local ship space so we can apply simple axis comparisons.
	# ship_transform maps local→world, so inverse maps world→local.
	var inv: Transform2D = ship_base.ship_transform.affine_inverse()
	var local_rel: Vector2 = inv.basis_xform(rel)

	# The arc division is a simple quadrant comparison in local space.
	# Boundary lines are y = x and y = -x (the 45° diagonals).
	# A point on the boundary line is considered inside the arc (AT-042).
	var lx: float = local_rel.x
	var ly: float = local_rel.y

	# On boundary: include (AT-042).
	var tol: float = ARC_BOUNDARY_TOLERANCE_PX

	match zone:
		Constants.HullZone.FRONT:
			# Front arc: ly ≤ 0 AND |lx| ≤ |ly|
			return _front_quadrant(lx, ly, tol)
		Constants.HullZone.REAR:
			# Rear arc: ly > 0 AND |lx| ≤ ly
			return _rear_quadrant(lx, ly, tol)
		Constants.HullZone.LEFT:
			# Left (port) arc: lx < 0 AND |ly| ≤ |lx|
			return _left_quadrant(lx, ly, tol)
		Constants.HullZone.RIGHT:
			# Right (starboard) arc: lx > 0 AND |ly| ≤ lx
			return _right_quadrant(lx, ly, tol)
	return false


## Returns true if the point is at the ship origin (no direction — not in any arc).
func is_at_origin(target_point: Vector2) -> bool:
	return target_point.distance_squared_to(ship_base.get_centre()) < 0.01


# ---------------------------------------------------------------------------
# Private quadrant helpers — each implements the arc membership test
# with boundary tolerance. All coordinates are in local ship space.
# Ship faces -Y (FRONT arc is the negative-Y region).
# ---------------------------------------------------------------------------

## FRONT arc: |lx| ≤ |ly| AND ly ≤ 0.
## Conditions: lx + ly ≤ 0 (right boundary) AND lx - ly ≥ 0 (left boundary).
## On both diagonals counts as FRONT (AT-042).
func _front_quadrant(lx: float, ly: float, tol: float) -> bool:
	return (lx + ly <= tol) and (lx - ly >= -tol) and (ly <= tol)

## REAR arc: |lx| ≤ ly AND ly ≥ 0.
## i.e. d1 = lx - ly ≤ 0  AND  d2 = lx + ly ≥ 0 (positive Y half)
## equivalently: ly - |lx| ≥ 0
func _rear_quadrant(lx: float, ly: float, tol: float) -> bool:
	return (ly - lx >= -tol) and (ly + lx >= -tol) and (ly >= -tol)


## LEFT arc: |ly| ≤ |lx| AND lx ≤ 0.
## i.e. d1 = lx - ly ≤ 0  AND  d2 = lx + ly ≤ 0  AND  lx ≤ 0
## equivalently: -lx - |ly| ≥ 0
func _left_quadrant(lx: float, ly: float, tol: float) -> bool:
	return (-lx - ly >= -tol) and (-lx + ly >= -tol) and (lx <= tol)


## RIGHT arc: |ly| ≤ lx AND lx ≥ 0.
## i.e. d1 = lx - ly ≥ 0  AND  d2 = lx + ly ≥ 0  AND  lx ≥ 0
func _right_quadrant(lx: float, ly: float, tol: float) -> bool:
	return (lx - ly >= -tol) and (lx + ly >= -tol) and (lx >= -tol)

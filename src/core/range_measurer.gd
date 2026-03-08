## RangeMeasurer
##
## Measures ranges between ships and squadrons according to the official rules.
## All distances are in pixels. Use GameScale.get_range_band(px) to classify.
##
## Measurement principles:
## • Ship-to-ship: closest point on the attacker's specified hull zone polygon
##   to the closest point on the defender's specified hull zone polygon (AT-050).
## • Ship-to-squadron: closest point on the hull zone to the closest point on
##   the squadron's circular base (AT-051).
## • Squadron-to-squadron: closest points on both circular bases (AT-052).
##
## Rules Reference: "Attack", step 1, p.1; "Range and Distance", p.10;
##   AT-050, AT-051, AT-052
class_name RangeMeasurer
extends RefCounted


## Measures the range (in pixels) between two hull zones on two ships.
## Returns the pixel distance between the closest edge points of the two zones.
## Returns 0.0 if the zones overlap.
##
## Rules Reference: AT-050
static func measure_ship_to_ship(
		attacker: ShipBase,
		attacker_zone: Constants.HullZone,
		defender: ShipBase,
		defender_zone: Constants.HullZone) -> float:
	var poly_a: PackedVector2Array = attacker.get_hull_zone_polygon(attacker_zone)
	var poly_b: PackedVector2Array = defender.get_hull_zone_polygon(defender_zone)
	return Geometry2DHelper.distance_polygon_to_polygon(poly_a, poly_b)


## Measures the range (in pixels) from a hull zone to a squadron's circular base.
## Returns 0.0 if the squadron overlaps the hull zone.
##
## Rules Reference: AT-051
static func measure_ship_to_squadron(
		attacker: ShipBase,
		attacker_zone: Constants.HullZone,
		squadron_position: Vector2,
		squadron_radius_px: float) -> float:
	var poly: PackedVector2Array = attacker.get_hull_zone_polygon(attacker_zone)

	# Closest point on the hull zone polygon to the squadron centre.
	var closest_on_zone: Vector2
	if Geometry2DHelper.point_in_polygon(squadron_position, poly):
		closest_on_zone = squadron_position
	else:
		closest_on_zone = Geometry2DHelper.closest_point_on_polygon(squadron_position, poly)

	var dist_centre: float = squadron_position.distance_to(closest_on_zone)

	# The measurement is to the edge of the squadron base, not the centre.
	var dist_to_edge: float = maxf(0.0, dist_centre - squadron_radius_px)
	return dist_to_edge


## Measures the range (in pixels) between two squadron circular bases.
## Returns 0.0 if bases overlap.
##
## Rules Reference: AT-052
static func measure_squadron_to_squadron(
		pos_a: Vector2,
		radius_a: float,
		pos_b: Vector2,
		radius_b: float) -> float:
	var centre_dist: float = pos_a.distance_to(pos_b)
	return maxf(0.0, centre_dist - radius_a - radius_b)


## Convenience: returns the range band string for a ship-to-ship measurement.
## Uses GameScale to classify the pixel distance.
##
## Rules Reference: "Range and Distance", p.10
static func get_ship_to_ship_band(
		attacker: ShipBase,
		attacker_zone: Constants.HullZone,
		defender: ShipBase,
		defender_zone: Constants.HullZone) -> String:
	var px: float = measure_ship_to_ship(
			attacker, attacker_zone, defender, defender_zone)
	return GameScale.get_range_band(px)


## Convenience: returns the range band for a ship-to-squadron measurement.
static func get_ship_to_squadron_band(
		attacker: ShipBase,
		attacker_zone: Constants.HullZone,
		squadron_position: Vector2,
		squadron_radius_px: float) -> String:
	var px: float = measure_ship_to_squadron(
			attacker, attacker_zone, squadron_position, squadron_radius_px)
	return GameScale.get_range_band(px)

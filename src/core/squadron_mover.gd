## SquadronMover
##
## Pure-logic helper that validates and resolves squadron movement.
## Squadrons move using the distance side of the range ruler: the token
## is picked up and placed anywhere up to its speed's distance band.
##
## Rules Reference: "Squadron Movement", RRG p.12; SM-001–005.
class_name SquadronMover
extends RefCounted


## Validates whether a squadron can be placed at [param target_pos].
## Returns an empty string if valid, or an error message if invalid.
## Distance is enforced by the real-time clamp in
## [method GameBoard._move_squadron_during_activation] — this function
## only checks placement constraints (overlap with ships / squadrons).
## [param squadron] — the squadron being moved.
## [param origin_pos] — current centre position of the squadron.
## [param target_pos] — proposed new centre position.
## [param all_squadron_positions] — Array of {"instance": SquadronInstance,
##     "position": Vector2} for overlap checks.
## [param ship_bases] — Array of ShipBase for ship overlap checks.
## Requirements: SM-003, SM-005.
static func validate_move(
		squadron: SquadronInstance,
		origin_pos: Vector2,
		target_pos: Vector2,
		all_squadron_positions: Array[Dictionary],
		ship_bases: Array[ShipBase]) -> String:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	# SM-005: staying in place is always valid.
	if origin_pos.distance_to(target_pos) < 1.0:
		return ""
	# SM-003: cannot overlap another squadron.
	var target_base: SquadronBase = SquadronBase.new(target_pos, radius)
	for entry: Dictionary in all_squadron_positions:
		var other: SquadronInstance = entry["instance"] as SquadronInstance
		if other == squadron:
			continue
		if other.is_destroyed():
			continue
		var other_pos: Vector2 = entry["position"] as Vector2
		var other_base: SquadronBase = SquadronBase.new(other_pos, radius)
		if target_base.overlaps_squadron(other_base):
			return "Overlaps another squadron."
	# SM-003: cannot overlap a ship.
	for ship_base: ShipBase in ship_bases:
		if target_base.overlaps_ship(ship_base):
			return "Overlaps a ship."
	return ""


## Returns the maximum distance in pixels a squadron with [param speed]
## can move.  Speed maps to distance band index (speed 1 = band 0, etc.).
## Rules Reference: SM-002 — "up to the distance band matching its speed."
static func _get_max_move_distance(speed: int) -> float:
	var band_idx: int = clampi(speed - 1, 0,
			GameScale.distance_bands_px.size() - 1)
	if band_idx < GameScale.distance_bands_px.size():
		return GameScale.distance_bands_px[band_idx]
	return 999999.0

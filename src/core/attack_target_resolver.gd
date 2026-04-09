## AttackTargetResolver
##
## Pure-geometry resolver for attack targeting: arc validation, line-of-sight
## tracing, range measurement, and target-availability queries.  All methods
## take explicit parameters (usually via [CombatParticipants]) and never
## reference UI panels or overlays.
##
## Covers all four combatant combinations:
## - Ship → Ship (all arcs)
## - Ship → Squadron
## - Squadron → Ship
## - Squadron → Squadron
##
## Extracted from [AttackExecutor] in Phase F4a to improve testability and
## reduce AttackExecutor's size.
##
## Rules Reference: "Attack", Steps 1–2, pp.2–3; "Line of Sight", p.10;
## "Range and Distance", pp.15–16; "Firing Arc", p.6.
class_name AttackTargetResolver
extends RefCounted


# ---------------------------------------------------------------------------
# Dependencies (injected via constructor)
# ---------------------------------------------------------------------------

## Callable returning [code]Array[ShipToken][/code].
var _get_ship_tokens: Callable

## Callable returning [code]Array[SquadronToken][/code].
var _get_squadron_tokens: Callable

## Callable returning [code]Array[LineOfSightChecker.ObstructionBody][/code].
## Allows the scene-tree iteration to stay in [AttackExecutor].
var _get_obstruction_bodies: Callable


# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

## [param ship_tokens_fn] — returns [code]Array[ShipToken][/code].
## [param squadron_tokens_fn] — returns [code]Array[SquadronToken][/code].
## [param obstruction_bodies_fn] — returns [code]Array[/code] of
## [LineOfSightChecker.ObstructionBody], excluding attacker/defender.
func _init(ship_tokens_fn: Callable, squadron_tokens_fn: Callable,
		obstruction_bodies_fn: Callable) -> void:
	_get_ship_tokens = ship_tokens_fn
	_get_squadron_tokens = squadron_tokens_fn
	_get_obstruction_bodies = obstruction_bodies_fn


# ===========================================================================
# Edge Geometry
# ===========================================================================


## Returns the hull-zone edge polyline for [param token], preferring
## arc-based multi-segment edges when boundary data with corner_* keys
## is available, otherwise falling back to rectangle corners.
## Requirements: HZ-EDGE-001.
func get_ship_edge(
		token: ShipToken, zone: Constants.HullZone) -> Array[Vector2]:
	var arc_pts: Dictionary = token.get_firing_arc_world_points()
	if not arc_pts.is_empty() and arc_pts.has("corner_front_left"):
		return RangeFinder.get_hull_zone_edge_from_arcs(arc_pts, zone)
	return RangeFinder.get_hull_zone_edge(
			token.global_position, token.rotation,
			token.get_half_width(), token.get_half_length(), zone)


# ===========================================================================
# Arc Validation
# ===========================================================================


## Returns [code]true[/code] if the defending ship hull zone is inside the
## attacker's firing arc.  Returns [code]true[/code] when the attacker is
## a squadron (squadrons have no arcs).
## Requirements: AS-ARC-001, HZ-EDGE-001.
func is_ship_target_in_arc(parts: CombatParticipants,
		def_token: ShipToken, def_zone: int) -> bool:
	if not parts.atk_is_ship():
		return true
	var atk_arc_pts: Dictionary = parts.atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return true # No arc data → allow.
	var def_edge: Array[Vector2] = get_ship_edge(
			def_token, def_zone as Constants.HullZone)
	return RangeFinder.is_hull_zone_edge_in_arc(
			def_edge,
			parts.atk_zone as Constants.HullZone,
			atk_arc_pts)


## Returns [code]true[/code] if the defending squadron is inside the
## attacker's firing arc.  Returns [code]true[/code] when the attacker
## is a squadron.
## Requirements: AS-ARC-001.
func is_squadron_target_in_arc(parts: CombatParticipants,
		def_token: SquadronToken) -> bool:
	if not parts.atk_is_ship():
		return true
	var atk_arc_pts: Dictionary = parts.atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return true
	return RangeFinder.is_squadron_in_arc(
			def_token.global_position,
			def_token.get_radius_px(),
			parts.atk_zone as Constants.HullZone,
			atk_arc_pts)


# ===========================================================================
# LOS Computation
# ===========================================================================


## Computes LOS endpoints, traces the line, and determines the status.
## Returns a Dictionary:
## [codeblock]
## {
##   "atk_pt": Vector2,       # LOS origin on attacker
##   "def_pt": Vector2,       # LOS endpoint on defender
##   "los_result": LOSResult, # raw trace result
##   "status": int,           # AttackSimOverlay.LOSStatus enum
##   "text": String,          # "Clear" / "Blocked" / "Obstructed by …"
##   "obstructed": bool,      # shorthand for status == OBSTRUCTED
## }
## [/codeblock]
## Requirements: AS-VIS-020–022, TL-LOS-001–005.
func compute_los(parts: CombatParticipants) -> Dictionary:
	var endpoints: Dictionary = _compute_los_endpoints(parts)
	var atk_pt: Vector2 = endpoints["atk"]
	var def_pt: Vector2 = endpoints["def"]
	var los_result: LineOfSightChecker.LOSResult = _trace_los(
			parts, atk_pt, def_pt)
	var los_info: Dictionary = _determine_los_status(
			parts, los_result, atk_pt, def_pt)
	los_info["atk_pt"] = atk_pt
	los_info["def_pt"] = def_pt
	los_info["los_result"] = los_result
	return los_info


## Computes the LOS line endpoints for the given combatants.
## Returns a Dictionary with "atk" and "def" Vector2 keys.
## Rules Reference: "Line of Sight", p.10.
func _compute_los_endpoints(parts: CombatParticipants) -> Dictionary:
	var atk_pt: Vector2 = Vector2.ZERO
	var def_pt: Vector2 = Vector2.ZERO
	# Attacker endpoint.
	if parts.atk_is_ship():
		var los_pts: Dictionary = \
				parts.atk_ship.get_los_origins_world()
		var zone_key: String = CombatParticipants.ZONE_NAMES.get(
				parts.atk_zone, "FRONT")
		atk_pt = los_pts.get(zone_key, Vector2.ZERO)
	# Defender endpoint (depends on type).
	if parts.def_is_ship():
		var los_pts: Dictionary = \
				parts.def_ship.get_los_origins_world()
		var zone_key: String = CombatParticipants.ZONE_NAMES.get(
				parts.def_zone, "FRONT")
		def_pt = los_pts.get(zone_key, Vector2.ZERO)
	return _adjust_los_for_squadrons(parts, atk_pt, def_pt)


## Adjusts LOS endpoints when one or both combatants are squadrons.
func _adjust_los_for_squadrons(parts: CombatParticipants,
		atk_pt: Vector2, def_pt: Vector2) -> Dictionary:
	if parts.atk_is_ship() and parts.def_is_squadron():
		def_pt = RangeFinder.closest_point_on_circle(
				atk_pt,
				parts.def_squad.global_position,
				parts.def_squad.get_radius_px())
	if parts.atk_is_squadron() and parts.def_is_ship():
		var d_los_pts: Dictionary = \
				parts.def_ship.get_los_origins_world()
		var d_zone_key: String = CombatParticipants.ZONE_NAMES.get(
				parts.def_zone, "FRONT")
		def_pt = d_los_pts.get(d_zone_key, Vector2.ZERO)
		atk_pt = RangeFinder.closest_point_on_circle(
				def_pt,
				parts.atk_squad.global_position,
				parts.atk_squad.get_radius_px())
	if parts.atk_is_squadron() and parts.def_is_squadron():
		atk_pt = RangeFinder.closest_point_on_circle(
				parts.def_squad.global_position,
				parts.atk_squad.global_position,
				parts.atk_squad.get_radius_px())
		def_pt = RangeFinder.closest_point_on_circle(
				parts.atk_squad.global_position,
				parts.def_squad.global_position,
				parts.def_squad.get_radius_px())
	return {"atk": atk_pt, "def": def_pt}


## Traces LOS between the attacker and target using LineOfSightChecker.
## Requirements: AS-VIS-022, TL-LOS-001–005.
func _trace_los(parts: CombatParticipants, atk_pt: Vector2,
		def_pt: Vector2) -> LineOfSightChecker.LOSResult:
	var bodies: Array = _get_obstruction_bodies.call()
	var obstacles: Array = [] # Future: obstacle tokens.
	if parts.def_is_ship():
		return _trace_los_to_ship_target(
				parts, atk_pt, def_pt, bodies, obstacles)
	if parts.def_is_squadron():
		return _trace_los_to_squad_target(
				parts, atk_pt, bodies, obstacles)
	return LineOfSightChecker.LOSResult.new()


## Traces LOS when the defender is a ship.
func _trace_los_to_ship_target(parts: CombatParticipants,
		atk_pt: Vector2, def_pt: Vector2,
		bodies: Array,
		obstacles: Array) -> LineOfSightChecker.LOSResult:
	var ds: ShipToken = parts.def_ship
	if parts.atk_is_ship():
		return LineOfSightChecker.trace_los_ship_to_ship(
				atk_pt, def_pt,
				parts.def_zone as Constants.HullZone,
				ds.global_position, ds.rotation,
				ds.get_half_width(), ds.get_half_length(),
				bodies, obstacles,
				ds.get_firing_arc_world_points())
	return LineOfSightChecker.trace_los_squad_to_ship(
			parts.atk_squad.global_position,
			parts.atk_squad.get_radius_px(),
			def_pt,
			parts.def_zone as Constants.HullZone,
			ds.global_position, ds.rotation,
			ds.get_half_width(), ds.get_half_length(),
			bodies, obstacles,
			ds.get_firing_arc_world_points())


## Traces LOS when the defender is a squadron.
func _trace_los_to_squad_target(parts: CombatParticipants,
		atk_pt: Vector2,
		bodies: Array,
		obstacles: Array) -> LineOfSightChecker.LOSResult:
	if parts.atk_is_ship():
		return LineOfSightChecker.trace_los_ship_to_squadron(
				atk_pt,
				parts.def_squad.global_position,
				parts.def_squad.get_radius_px(),
				bodies, obstacles)
	return LineOfSightChecker.trace_los_squad_to_squad(
			parts.atk_squad.global_position,
			parts.atk_squad.get_radius_px(),
			parts.def_squad.global_position,
			parts.def_squad.get_radius_px(),
			bodies, obstacles)


## Determines the LOS status and descriptive text from a trace result.
## Returns [code]{"status": int, "text": String, "obstructed": bool}[/code].
func _determine_los_status(parts: CombatParticipants,
		los_result: LineOfSightChecker.LOSResult,
		atk_pt: Vector2, def_pt: Vector2) -> Dictionary:
	var status: int = AttackSimOverlay.LOSStatus.CLEAR
	var los_text: String = "Clear"
	var obstructed: bool = false
	if not los_result.has_los:
		status = AttackSimOverlay.LOSStatus.BLOCKED
		los_text = "Blocked"
		if parts.def_is_ship():
			var def_arc: Dictionary = \
					parts.def_ship.get_firing_arc_world_points()
			var _info: Dictionary = \
					LineOfSightChecker.get_blocking_boundary_info(
							atk_pt, def_pt, def_arc)
			# Debug info logged by caller if needed.
	elif los_result.obstructed:
		status = AttackSimOverlay.LOSStatus.OBSTRUCTED
		obstructed = true
		if los_result.obstructed_by.size() > 0:
			los_text = "Obstructed by %s" % ", ".join(
					los_result.obstructed_by)
		else:
			los_text = "Obstructed"
	return {"status": status, "text": los_text, "obstructed": obstructed}


# ===========================================================================
# Range Measurement
# ===========================================================================


## Computes the range measurement endpoints and distance for the given
## combatants.  Returns a Dictionary with [code]"distance"[/code] (float),
## [code]"atk_pt"[/code] (Vector2), [code]"def_pt"[/code] (Vector2).
## Requirements: AS-RNG-010, AS-RNG-011, HZ-EDGE-001.
func compute_range(parts: CombatParticipants) -> Dictionary:
	if parts.atk_is_ship():
		return _measure_range_from_ship(parts)
	# Squadron → Ship.
	if parts.atk_is_squadron() and parts.def_is_ship():
		var def_edge: Array[Vector2] = get_ship_edge(
				parts.def_ship,
				parts.def_zone as Constants.HullZone)
		return RangeFinder.measure_range_squad_to_ship(
				parts.atk_squad.global_position,
				parts.atk_squad.get_radius_px(),
				def_edge)
	# Squadron → Squadron.
	if parts.atk_is_squadron() and parts.def_is_squadron():
		return RangeFinder.measure_range_squad_to_squad(
				parts.atk_squad.global_position,
				parts.atk_squad.get_radius_px(),
				parts.def_squad.global_position,
				parts.def_squad.get_radius_px())
	# Fallback.
	return {"distance": INF, "atk_pt": Vector2.ZERO,
			"def_pt": Vector2.ZERO}


## Computes range from a ship attacker to the current target.
func _measure_range_from_ship(parts: CombatParticipants) -> Dictionary:
	var atk_edge: Array[Vector2] = get_ship_edge(
			parts.atk_ship,
			parts.atk_zone as Constants.HullZone)
	var atk_arc_pts: Dictionary = parts.atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return {"distance": INF, "atk_pt": Vector2.ZERO,
				"def_pt": Vector2.ZERO}
	if parts.def_is_ship():
		var def_edge: Array[Vector2] = get_ship_edge(
				parts.def_ship,
				parts.def_zone as Constants.HullZone)
		return RangeFinder.measure_attack_range_ship_endpoints(
				atk_edge, def_edge,
				parts.atk_zone as Constants.HullZone,
				atk_arc_pts)
	return RangeFinder.measure_attack_range_squadron_endpoints(
			atk_edge,
			parts.def_squad.global_position,
			parts.def_squad.get_radius_px(),
			parts.atk_zone as Constants.HullZone,
			atk_arc_pts)


## Checks whether a squadron is at attack range (not beyond) from the
## given attacker hull zone.
## Requirements: AE-SQ-003.
func is_squadron_at_range(parts: CombatParticipants,
		sq_token: SquadronToken) -> bool:
	var atk_edge: Array[Vector2] = get_ship_edge(
			parts.atk_ship,
			parts.atk_zone as Constants.HullZone)
	var atk_arc_pts: Dictionary = parts.atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return false
	var range_data: Dictionary = (
			RangeFinder.measure_attack_range_squadron_endpoints(
			atk_edge, sq_token.global_position,
			sq_token.get_radius_px(),
			parts.atk_zone as Constants.HullZone,
			atk_arc_pts))
	var dist: float = range_data.get("distance", INF)
	if dist >= INF:
		return false
	var band: String = GameScale.get_range_band(dist)
	return band != Constants.RANGE_BAND_BEYOND


# ===========================================================================
# Target Availability Queries
# ===========================================================================


## Returns [code]true[/code] if any enemy target (ship or squadron)
## is in arc and at attack range from the given hull zone.
## Requirements: AE-SKIP-003.
func zone_has_targets(ship_token: ShipToken,
		zone: Constants.HullZone) -> bool:
	var atk_arc_pts: Dictionary = \
			ship_token.get_firing_arc_world_points()
	var atk_edge: Array[Vector2] = get_ship_edge(ship_token, zone)
	var attacker_faction: int = ship_token.get_faction()
	if _zone_has_enemy_ship_target(
			ship_token, zone, atk_arc_pts, atk_edge,
			attacker_faction):
		return true
	return _zone_has_enemy_squad_target(
			zone, atk_arc_pts, atk_edge, attacker_faction)


## Returns [code]true[/code] if any enemy ship hull zone is in arc and
## range from the given attacker.
func _zone_has_enemy_ship_target(ship_token: ShipToken,
		zone: Constants.HullZone, atk_arc_pts: Dictionary,
		atk_edge: Array[Vector2],
		attacker_faction: int) -> bool:
	for def_token: ShipToken in _get_ship_tokens.call():
		if def_token.get_faction() == attacker_faction:
			continue
		if def_token == ship_token:
			continue
		for def_zone: int in [Constants.HullZone.FRONT,
				Constants.HullZone.LEFT, Constants.HullZone.RIGHT,
				Constants.HullZone.REAR]:
			var def_edge: Array[Vector2] = get_ship_edge(
					def_token, def_zone as Constants.HullZone)
			if not RangeFinder.is_hull_zone_edge_in_arc(
					def_edge, zone, atk_arc_pts):
				continue
			var range_data: Dictionary = (
					RangeFinder.measure_attack_range_ship_endpoints(
					atk_edge, def_edge, zone, atk_arc_pts))
			var dist: float = range_data.get("distance", INF)
			if dist >= INF:
				continue
			var rng_band: String = GameScale.get_range_band(dist)
			if rng_band != Constants.RANGE_BAND_BEYOND:
				return true
	return false


## Returns [code]true[/code] if any enemy squadron is in arc and range
## from the given attacker hull zone.
func _zone_has_enemy_squad_target(
		zone: Constants.HullZone, atk_arc_pts: Dictionary,
		atk_edge: Array[Vector2],
		attacker_faction: int) -> bool:
	for sq_token: SquadronToken in _get_squadron_tokens.call():
		if sq_token.get_faction() == attacker_faction:
			continue
		if not RangeFinder.is_squadron_in_arc(
				sq_token.global_position, sq_token.get_radius_px(),
				zone, atk_arc_pts):
			continue
		var range_data: Dictionary = (
				RangeFinder.measure_attack_range_squadron_endpoints(
				atk_edge, sq_token.global_position,
				sq_token.get_radius_px(), zone, atk_arc_pts))
		var dist: float = range_data.get("distance", INF)
		if dist >= INF:
			continue
		var rng_band: String = GameScale.get_range_band(dist)
		if rng_band != Constants.RANGE_BAND_BEYOND:
			return true
	return false


## Returns [code]true[/code] if the given ship has at least one valid
## attack target from any of its four hull zones.  Does NOT exclude
## fired zones — used before the attack step begins.
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
func has_any_attack_target(ship_token: ShipToken) -> bool:
	if ship_token == null:
		return false
	var all_zones: Array[int] = [
		Constants.HullZone.FRONT, Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT, Constants.HullZone.REAR,
	]
	for zone: int in all_zones:
		if zone_has_targets(
				ship_token, zone as Constants.HullZone):
			return true
	return false


## Returns [code]true[/code] if the attacker has valid targets from any
## unfired hull zone.
## Requirements: AE-SKIP-003.
func has_any_valid_target(ship_token: ShipToken,
		fired_zones: Array[int]) -> bool:
	if ship_token == null:
		return false
	var all_zones: Array[int] = [
		Constants.HullZone.FRONT, Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT, Constants.HullZone.REAR,
	]
	for zone: int in all_zones:
		if zone in fired_zones:
			continue
		if zone_has_targets(
				ship_token, zone as Constants.HullZone):
			return true
	return false


## Returns [code]true[/code] if there are more enemy squadrons in arc
## and at range that haven't been attacked yet.
## Requirements: AE-SQ-003.
## Rules Reference: "Attack", Step 6, p.2.
func has_more_squad_targets(parts: CombatParticipants,
		attacked_squads: Array[SquadronToken]) -> bool:
	if not parts.atk_is_ship():
		return false
	var attacker_faction: int = parts.get_atk_faction()
	for sq_token: SquadronToken in _get_squadron_tokens.call():
		if sq_token.get_faction() == attacker_faction:
			continue
		if sq_token in attacked_squads:
			continue
		if not is_squadron_target_in_arc(parts, sq_token):
			continue
		if not is_squadron_at_range(parts, sq_token):
			continue
		return true
	return false

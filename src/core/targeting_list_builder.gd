## TargetingListBuilder
##
## Orchestrator class that builds the complete targeting list for the active
## player's fleet.  Iterates friendly ships × hull zones × enemies, using
## [RangeFinder] and [LineOfSightChecker] to determine valid targets, range
## bands, dice availability, and obstruction status.
##
## Returns a structured result array suitable for display in the UI modal.
##
## No scene-tree dependency — receives all geometry as parameters.
##
## Requirements: TL-LIST-001–007, TL-ALGO-003.
## Rules Reference: "Attack", Step 1, p.2.
class_name TargetingListBuilder
extends RefCounted


## A single targeting entry (one arc → one target).
class TargetEntry:
	extends RefCounted
	## Name of the target.
	var target_name: String = ""
	## The attacking hull zone.
	var arc: Constants.HullZone = Constants.HullZone.FRONT
	## Range band string ("close", "medium", "long").
	var range_band: String = ""
	## Dice available at this range.
	var dice: Dictionary = {}
	## Whether the attack is obstructed.
	var obstructed: bool = false
	## Names of obstructing entities.
	var obstructed_by: Array[String] = []


## A single incoming threat entry (enemy arc → friendly ship).
class ThreatEntry:
	extends RefCounted
	## Name of the friendly ship being threatened.
	var friendly_name: String = ""
	## Name of the enemy ship.
	var enemy_name: String = ""
	## The enemy's attacking hull zone.
	var arc: Constants.HullZone = Constants.HullZone.FRONT
	## Range band string.
	var range_band: String = ""
	## Whether obstructed.
	var obstructed: bool = false


## Per-ship targeting result.
class ShipTargetingResult:
	extends RefCounted
	## The friendly ship's display name.
	var ship_name: String = ""
	## Outgoing targets grouped by hull zone.
	var outgoing: Array = []  # Array[TargetEntry]
	## Incoming threats.
	var incoming: Array = []  # Array[ThreatEntry]


## Description of a ship on the board (passed in as input data).
class ShipInfo:
	extends RefCounted
	## Display name.
	var ship_name: String = ""
	## Data key (for looking up armament).
	var data_key: String = ""
	## Owning player index.
	var owner_player: int = 0
	## World position.
	var pos: Vector2 = Vector2.ZERO
	## World rotation (radians).
	var rot: float = 0.0
	## Base half-width in pixels.
	var half_w: float = 0.0
	## Base half-length in pixels.
	var half_l: float = 0.0
	## Firing arc boundary points in world space.
	var arc_pts: Dictionary = {}
	## LOS targeting points in world space: {"FRONT": Vector2, …}.
	var los_pts: Dictionary = {}
	## Battery armament per hull zone: {"FRONT": {"RED": 2, "BLUE": 1}, …}.
	var battery_armament: Dictionary = {}
	## Anti-squadron armament: {"BLUE": 1}.
	var anti_squadron_armament: Dictionary = {}


## Description of a squadron on the board.
class SquadInfo:
	extends RefCounted
	## Display name.
	var squad_name: String = ""
	## Owning player index.
	var owner_player: int = 0
	## World position.
	var pos: Vector2 = Vector2.ZERO
	## Base radius in pixels.
	var radius: float = 0.0
	## Battery armament (for attacking ships): {"RED": 1}.
	## Requirements: TL-LIST-010.
	var battery_armament: Dictionary = {}
	## Anti-squadron armament: {"BLUE": 4}.
	## Requirements: TL-LIST-010.
	var anti_squadron_armament: Dictionary = {}


# =========================================================================
# Public API
# =========================================================================

## Builds the full targeting list for the active player.
## [param ships]         — all ships on the board.
## [param squadrons]     — all squadrons on the board.
## [param active_player] — the player index whose fleet to analyse.
## [param ghost]         — optional ghost ShipInfo (maneuver preview).
## Returns: Array[ShipTargetingResult].
## Requirements: TL-LIST-001–007, TL-ALGO-003.
static func build(
		ships: Array,
		squadrons: Array,
		active_player: int,
		ghost: ShipInfo = null) -> Array:
	var _log: GameLogger = GameLogger.new("Targeting")
	_log.debug("=== build() start — active_player=%d, ships=%d, squads=%d ===" % [
			active_player, ships.size(), squadrons.size()])
	var results: Array = []
	var friendly_ships: Array = []
	var enemy_ships: Array = []
	var enemy_squads: Array = []
	# Sort into friendly and enemy.
	for ship: Variant in ships:
		var s: ShipInfo = ship as ShipInfo
		if s.owner_player == active_player:
			friendly_ships.append(s)
		else:
			enemy_ships.append(s)
	for squad: Variant in squadrons:
		var sq: SquadInfo = squad as SquadInfo
		if sq.owner_player != active_player:
			enemy_squads.append(sq)
	_log.debug("friendly=%d, enemies=%d ships + %d squads" % [
			friendly_ships.size(), enemy_ships.size(), enemy_squads.size()])
	# Build obstruction bodies from ALL ships (used for LOS checks).
	var all_ship_bodies: Array = []
	for ship2: Variant in ships:
		var s2: ShipInfo = ship2 as ShipInfo
		all_ship_bodies.append({
			"info": s2,
			"body": LineOfSightChecker.ObstructionBody.from_ship_base(
					s2.ship_name, s2.pos, s2.rot, s2.half_w, s2.half_l),
		})
	# Process each friendly ship.
	for friendly: Variant in friendly_ships:
		var fs: ShipInfo = friendly as ShipInfo
		_log_ship_geometry(_log, fs)
		var entry: ShipTargetingResult = _build_ship_entry(
				_log, fs, enemy_ships, enemy_squads, all_ship_bodies)
		# Incoming threats from enemy ships and squadrons.
		entry.incoming = _build_incoming_threats(
				fs, enemy_ships, enemy_squads, all_ship_bodies)
		results.append(entry)
	# Ghost section.
	if ghost != null:
		_log_ship_geometry(_log, ghost)
		var ghost_entry: ShipTargetingResult = _build_ship_entry(
				_log, ghost, enemy_ships, enemy_squads, all_ship_bodies)
		ghost_entry.incoming = _build_incoming_threats(
				ghost, enemy_ships, enemy_squads, all_ship_bodies)
		ghost_entry.ship_name = ghost.ship_name + " (projected)"
		results.append(ghost_entry)
	_log.debug("=== build() complete — %d results ===" % results.size())
	return results


## Logs the geometry of a ship (position, rotation, arc boundary world points).
static func _log_ship_geometry(log: GameLogger, ship: ShipInfo) -> void:
	log.debug("[%s] pos=%s rot=%.2f° base=%.0fx%.0f" % [
			ship.ship_name,
			_v2str(ship.pos),
			rad_to_deg(ship.rot),
			ship.half_w * 2.0,
			ship.half_l * 2.0])
	if ship.arc_pts.is_empty():
		log.debug("  arc_pts: (empty)")
		return
	for key: String in ship.arc_pts:
		log.debug("  arc %s = %s" % [key, _v2str(ship.arc_pts[key])])


# =========================================================================
# Internal — Outgoing Targets
# =========================================================================

## Builds outgoing targets for one friendly ship.
static func _build_ship_entry(
		log: GameLogger,
		friendly: ShipInfo,
		enemy_ships: Array,
		enemy_squads: Array,
		all_ship_bodies: Array) -> ShipTargetingResult:
	var result: ShipTargetingResult = ShipTargetingResult.new()
	result.ship_name = friendly.ship_name
	var zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	for zone: int in zones:
		var hz: Constants.HullZone = zone as Constants.HullZone
		var atk_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				friendly.pos, friendly.rot,
				friendly.half_w, friendly.half_l, hz)
		log.debug("  [%s] zone %s edge=[%s, %s]" % [
				friendly.ship_name, _hz_key(hz),
				_v2str(atk_edge[0]), _v2str(atk_edge[1])])
		# Ship targets (need battery armament for this hull zone).
		var armament: Dictionary = friendly.battery_armament.get(
				_hz_key(hz), {})
		if not armament.is_empty():
			for enemy: Variant in enemy_ships:
				var es: ShipInfo = enemy as ShipInfo
				var entry: TargetEntry = _check_ship_target(
						log, friendly, hz, atk_edge, armament,
						es, all_ship_bodies)
				if entry != null:
					result.outgoing.append(entry)
		# Squadron targets — use anti-squadron armament for dice/range.
		# Anti-squadron armament is global (not per hull zone) so we check
		# even if this hull zone has no battery armament.
		# Requirements: TL-RNG-007, AC-TL-20, AC-TL-21.
		var anti_sq: Dictionary = friendly.anti_squadron_armament
		for squad: Variant in enemy_squads:
			var sq: SquadInfo = squad as SquadInfo
			var entry2: TargetEntry = _check_squadron_target(
					log, friendly, hz, atk_edge, anti_sq,
					sq, all_ship_bodies)
			if entry2 != null:
				result.outgoing.append(entry2)
	return result


## Checks if one enemy ship is a valid target from a given hull zone.
## Returns a TargetEntry or null.
static func _check_ship_target(
		log: GameLogger,
		atk: ShipInfo,
		atk_zone: Constants.HullZone,
		atk_edge: Array[Vector2],
		armament: Dictionary,
		defender: ShipInfo,
		all_ship_bodies: Array) -> TargetEntry:
	log.debug("    check ship '%s' from %s arc" % [
			defender.ship_name, _hz_key(atk_zone)])
	var def_zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	# Try each defending hull zone; pick the one with the closest valid range.
	var best_entry: TargetEntry = null
	var best_dist: float = INF
	for dz: int in def_zones:
		var def_hz: Constants.HullZone = dz as Constants.HullZone
		var def_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				defender.pos, defender.rot,
				defender.half_w, defender.half_l, def_hz)
		# Step 1: arc containment test (TL-ARC-006 step 1).
		var in_arc: bool = RangeFinder.is_hull_zone_edge_in_arc(
				def_edge[0], def_edge[1], atk_zone, atk.arc_pts)
		log.debug("      def_zone %s edge=[%s,%s] in_arc=%s" % [
				_hz_key(def_hz), _v2str(def_edge[0]),
				_v2str(def_edge[1]), str(in_arc)])
		if not in_arc:
			continue
		# Step 2: range measurement within arc (TL-ARC-006 step 2).
		var dist: float = RangeFinder.measure_attack_range_ship(
				atk_edge, def_edge, atk_zone, atk.arc_pts)
		if dist >= INF:
			log.debug("      dist=INF — skipped")
			continue
		var band: String = GameScale.get_range_band(dist)
		log.debug("      dist=%.1f band=%s" % [dist, band])
		if band == Constants.RANGE_BAND_BEYOND:
			continue
		# Step 3: max attack range filter (TL-RNG-004).
		if not RangeFinder.is_within_max_range(band, armament):
			continue
		# Step 4: LOS check (TL-LOS-001, TL-LOS-004).
		var atk_los: Vector2 = atk.los_pts.get(
				_hz_key(atk_zone), atk.pos)
		var def_los: Vector2 = defender.los_pts.get(
				_hz_key(def_hz), defender.pos)
		# Build intervening ship bodies (exclude attacker and defender).
		var bodies: Array = _get_intervening_bodies(atk, defender, all_ship_bodies)
		var los_result: LineOfSightChecker.LOSResult = \
				LineOfSightChecker.trace_los_ship_to_ship(
						atk_los, def_los, def_hz,
						defender.pos, defender.rot,
						defender.half_w, defender.half_l,
						bodies, [])
		if not los_result.has_los:
			continue
		# TL-LOS-004: also check range path blocking.
		# Approximate range path endpoints.
		var range_blocked: bool = LineOfSightChecker.is_range_path_blocked(
				RangeFinder.closest_point_on_segment(
						def_edge[0].lerp(def_edge[1], 0.5),
						atk_edge[0], atk_edge[1]),
				def_edge[0].lerp(def_edge[1], 0.5),
				def_hz,
				defender.pos, defender.rot,
				defender.half_w, defender.half_l)
		if range_blocked:
			continue
		if dist < best_dist:
			best_dist = dist
			var entry: TargetEntry = TargetEntry.new()
			entry.target_name = defender.ship_name
			entry.arc = atk_zone
			entry.range_band = band
			entry.dice = RangeFinder.dice_at_range(armament, band)
			entry.obstructed = los_result.obstructed
			entry.obstructed_by = los_result.obstructed_by
			best_entry = entry
	if best_entry:
		log.debug("    -> HIT ship '%s' zone=%s band=%s dist=%.1f" % [
				best_entry.target_name, _hz_key(best_entry.arc),
				best_entry.range_band, best_dist])
	else:
		log.debug("    -> no valid target from '%s'" % defender.ship_name)
	return best_entry


## Checks if one enemy squadron is a valid target from a given hull zone.
## Uses the ship's anti-squadron armament for dice and max-range check.
## Requirements: TL-RNG-007, AC-TL-20, AC-TL-21.
static func _check_squadron_target(
		log: GameLogger,
		atk: ShipInfo,
		atk_zone: Constants.HullZone,
		atk_edge: Array[Vector2],
		anti_sq_armament: Dictionary,
		squad: SquadInfo,
		all_ship_bodies: Array) -> TargetEntry:
	# Skip if no anti-squadron armament.
	if anti_sq_armament.is_empty():
		return null
	# Arc test.
	var in_arc: bool = RangeFinder.is_squadron_in_arc(
			squad.pos, squad.radius, atk_zone, atk.arc_pts)
	log.debug("    check squad '%s' pos=%s r=%.0f %s arc in_arc=%s" % [
			squad.squad_name, _v2str(squad.pos), squad.radius,
			_hz_key(atk_zone), str(in_arc)])
	if not in_arc:
		return null
	# Range measurement.
	var dist: float = RangeFinder.measure_attack_range_squadron(
			atk_edge, squad.pos, squad.radius, atk_zone, atk.arc_pts)
	if dist >= INF:
		log.debug("      dist=INF — skipped")
		return null
	var band: String = GameScale.get_range_band(dist)
	log.debug("      dist=%.1f band=%s" % [dist, band])
	if band == Constants.RANGE_BAND_BEYOND:
		return null
	if not RangeFinder.is_within_max_range(band, anti_sq_armament):
		log.debug("      beyond max range for armament — skipped")
		return null
	# LOS check (ship → squadron).
	var atk_los: Vector2 = atk.los_pts.get(_hz_key(atk_zone), atk.pos)
	var bodies: Array = []
	for entry: Variant in all_ship_bodies:
		var d: Dictionary = entry as Dictionary
		var info: ShipInfo = d["info"] as ShipInfo
		if info.ship_name == atk.ship_name:
			continue
		bodies.append(d["body"])
	var los_result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_squadron(
					atk_los, squad.pos, squad.radius, bodies, [])
	if not los_result.has_los:
		log.debug("      no LOS — skipped")
		return null
	log.debug("    -> HIT squad '%s' zone=%s band=%s dist=%.1f" % [
			squad.squad_name, _hz_key(atk_zone), band, dist])
	var entry: TargetEntry = TargetEntry.new()
	entry.target_name = squad.squad_name
	entry.arc = atk_zone
	# Compute dice using the measured band, then override range_band
	# for display — squadrons have a single engagement range.
	entry.dice = RangeFinder.dice_at_range(anti_sq_armament, band)
	entry.range_band = "in range"
	entry.obstructed = los_result.obstructed
	entry.obstructed_by = los_result.obstructed_by
	return entry


# =========================================================================
# Internal — Incoming Threats
# =========================================================================

## Builds incoming threats for one friendly ship from all enemy ships and
## squadrons.
## Requirements: TL-LIST-002, TL-LIST-008, AC-TL-22.
static func _build_incoming_threats(
		friendly: ShipInfo,
		enemy_ships: Array,
		enemy_squads: Array,
		all_ship_bodies: Array) -> Array:
	var threats: Array = []
	var zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	# --- Ship threats ---
	for enemy: Variant in enemy_ships:
		var es: ShipInfo = enemy as ShipInfo
		for zone: int in zones:
			var hz: Constants.HullZone = zone as Constants.HullZone
			var armament: Dictionary = es.battery_armament.get(
					_hz_key(hz), {})
			if armament.is_empty():
				continue
			var atk_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
					es.pos, es.rot, es.half_w, es.half_l, hz)
			# Check each friendly hull zone.
			var friendly_zones: Array = [
				Constants.HullZone.FRONT,
				Constants.HullZone.LEFT,
				Constants.HullZone.RIGHT,
				Constants.HullZone.REAR,
			]
			var found_threat: bool = false
			for fz: int in friendly_zones:
				if found_threat:
					break
				var fhz: Constants.HullZone = fz as Constants.HullZone
				var def_edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
						friendly.pos, friendly.rot,
						friendly.half_w, friendly.half_l, fhz)
				if not RangeFinder.is_hull_zone_edge_in_arc(
						def_edge[0], def_edge[1], hz, es.arc_pts):
					continue
				var dist: float = RangeFinder.measure_attack_range_ship(
						atk_edge, def_edge, hz, es.arc_pts)
				if dist >= INF:
					continue
				var band: String = GameScale.get_range_band(dist)
				if band == Constants.RANGE_BAND_BEYOND:
					continue
				if not RangeFinder.is_within_max_range(band, armament):
					continue
				# LOS check.
				var atk_los: Vector2 = es.los_pts.get(
						_hz_key(hz), es.pos)
				var def_los: Vector2 = friendly.los_pts.get(
						_hz_key(fhz), friendly.pos)
				var bodies: Array = _get_intervening_bodies(
						es, friendly, all_ship_bodies)
				var los_result: LineOfSightChecker.LOSResult = \
						LineOfSightChecker.trace_los_ship_to_ship(
								atk_los, def_los, fhz,
								friendly.pos, friendly.rot,
								friendly.half_w, friendly.half_l,
								bodies, [])
				if not los_result.has_los:
					continue
				var threat: ThreatEntry = ThreatEntry.new()
				threat.friendly_name = friendly.ship_name
				threat.enemy_name = es.ship_name
				threat.arc = hz
				threat.range_band = band
				threat.obstructed = los_result.obstructed
				threats.append(threat)
				found_threat = true
	# --- Squadron threats (TL-LIST-008) ---
	# Squadrons attack at distance 1 (close range) with 360° arc.
	# No LOS check needed (squadrons don't have hull zones to block).
	for squad: Variant in enemy_squads:
		var sq: SquadInfo = squad as SquadInfo
		if sq.battery_armament.is_empty():
			continue
		# Measure from squadron base edge to nearest point on ship base.
		var dist: float = _measure_squad_to_ship_distance(sq, friendly)
		var band: String = GameScale.get_range_band(dist)
		# Squadron attack range is distance 1 = close range only.
		if band != Constants.RANGE_BAND_CLOSE:
			continue
		var threat: ThreatEntry = ThreatEntry.new()
		threat.friendly_name = friendly.ship_name
		threat.enemy_name = sq.squad_name
		threat.arc = Constants.HullZone.FRONT  # Placeholder — 360° arc.
		threat.range_band = "in range"
		threat.obstructed = false
		threats.append(threat)
	return threats


# =========================================================================
# Helpers
# =========================================================================

## Measures distance from a squadron's base edge to the nearest point on a
## ship's base (any hull zone). Used for squadron → ship threat range check.
## Requirements: TL-LIST-008.
static func _measure_squad_to_ship_distance(
		squad: SquadInfo, ship: ShipInfo) -> float:
	var best_dist: float = INF
	var zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	for zone: int in zones:
		var hz: Constants.HullZone = zone as Constants.HullZone
		var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				ship.pos, ship.rot, ship.half_w, ship.half_l, hz)
		# Closest point on the hull zone edge from the squadron centre.
		var cp: Vector2 = RangeFinder.closest_point_on_segment(
				squad.pos, edge[0], edge[1])
		# Subtract squadron radius (measure from base edge, not centre).
		var dist: float = squad.pos.distance_to(cp) - squad.radius
		if dist < 0.0:
			dist = 0.0
		if dist < best_dist:
			best_dist = dist
	return best_dist


## Returns the hull-zone key string for a hull zone enum.
static func _hz_key(zone: Constants.HullZone) -> String:
	match zone:
		Constants.HullZone.FRONT:
			return "FRONT"
		Constants.HullZone.LEFT:
			return "LEFT"
		Constants.HullZone.RIGHT:
			return "RIGHT"
		Constants.HullZone.REAR:
			return "REAR"
		_:
			return "FRONT"


## Returns an array of ObstructionBody excluding the attacker and defender.
## Requirements: TL-LOS-005, TL-LOS-007.
static func _get_intervening_bodies(
		atk: ShipInfo,
		defender: ShipInfo,
		all_ship_bodies: Array) -> Array:
	var bodies: Array = []
	for entry: Variant in all_ship_bodies:
		var d: Dictionary = entry as Dictionary
		var info: ShipInfo = d["info"] as ShipInfo
		if info.ship_name == atk.ship_name:
			continue
		if info.ship_name == defender.ship_name:
			continue
		bodies.append(d["body"])
	return bodies


## Formats a Vector2 compactly for log output.
static func _v2str(v: Vector2) -> String:
	return "(%.1f,%.1f)" % [v.x, v.y]

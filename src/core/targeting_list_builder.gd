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
	## The defending hull zone (ship targets only).
	## Requirements: TL-LIST-013, AC-TL-35.
	var target_zone: Constants.HullZone = Constants.HullZone.FRONT
	## Whether [member target_zone] is meaningful (false for squadron targets).
	var has_target_zone: bool = false
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
	var outgoing: Array = [] # Array[TargetEntry]
	## Incoming threats.
	var incoming: Array = [] # Array[ThreatEntry]


## Per-squadron targeting result.
## Requirements: TL-LIST-014, AC-TL-30.
class SquadTargetingResult:
	extends RefCounted
	## The friendly squadron's display name.
	var squad_name: String = ""
	## Outgoing targets (ships at distance 1 + enemy squadrons at distance 1).
	var outgoing: Array = [] # Array[TargetEntry]
	## Incoming threats from enemy ships and squadrons.
	var incoming: Array = [] # Array[ThreatEntry]


## Combined build result containing both ship and squadron targeting data.
## Requirements: TL-LIST-014.
class BuildResult:
	extends RefCounted
	## Per-ship targeting results for friendly ships (+ ghost).
	var ship_results: Array = [] # Array[ShipTargetingResult]
	## Per-squadron targeting results for friendly squadrons.
	var squad_results: Array = [] # Array[SquadTargetingResult]


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
## Returns: BuildResult containing ship_results and squad_results.
## Requirements: TL-LIST-001–007, TL-LIST-011–014, TL-ALGO-003.
static func build(
		ships: Array,
		squadrons: Array,
		active_player: int,
		ghost: ShipInfo = null) -> BuildResult:
	var _log: GameLogger = GameLogger.new("Targeting")
	_log.debug("=== build() start — active_player=%d, ships=%d, squads=%d ===" % [
			active_player, ships.size(), squadrons.size()])
	var build_result: BuildResult = BuildResult.new()
	var fleets: Dictionary = _sort_into_fleets(
			ships, squadrons, active_player)
	var friendly_ships: Array = fleets["friendly_ships"]
	var enemy_ships: Array = fleets["enemy_ships"]
	var friendly_squads: Array = fleets["friendly_squads"]
	var enemy_squads: Array = fleets["enemy_squads"]
	_log.debug("friendly=%d ships + %d squads, enemies=%d ships + %d squads" % [
			friendly_ships.size(), friendly_squads.size(),
			enemy_ships.size(), enemy_squads.size()])
	var all_ship_bodies: Array = _build_all_ship_bodies(ships)
	_build_friendly_ship_results(_log, build_result, friendly_ships,
			enemy_ships, enemy_squads, all_ship_bodies)
	_build_ghost_result(_log, build_result, ghost,
			enemy_ships, enemy_squads, all_ship_bodies)
	_build_friendly_squad_results(_log, build_result, friendly_squads,
			enemy_ships, enemy_squads, all_ship_bodies)
	_log.debug("=== build() complete — %d ship + %d squad results ===" % [
			build_result.ship_results.size(),
			build_result.squad_results.size()])
	return build_result


## Sorts ships and squadrons into friendly/enemy arrays.
static func _sort_into_fleets(ships: Array, squadrons: Array,
		active_player: int) -> Dictionary:
	var friendly_ships: Array = []
	var enemy_ships: Array = []
	var friendly_squads: Array = []
	var enemy_squads: Array = []
	for ship: Variant in ships:
		var s: ShipInfo = ship as ShipInfo
		if s.owner_player == active_player:
			friendly_ships.append(s)
		else:
			enemy_ships.append(s)
	for squad: Variant in squadrons:
		var sq: SquadInfo = squad as SquadInfo
		if sq.owner_player == active_player:
			friendly_squads.append(sq)
		else:
			enemy_squads.append(sq)
	return {
		"friendly_ships": friendly_ships,
		"enemy_ships": enemy_ships,
		"friendly_squads": friendly_squads,
		"enemy_squads": enemy_squads,
	}


## Builds ObstructionBody entries from ALL ships for LOS checks.
static func _build_all_ship_bodies(ships: Array) -> Array:
	var bodies: Array = []
	for ship: Variant in ships:
		var s: ShipInfo = ship as ShipInfo
		bodies.append({
			"info": s,
			"body": LineOfSightChecker.ObstructionBody.from_ship_base(
					s.ship_name, s.pos, s.rot, s.half_w, s.half_l),
		})
	return bodies


## Processes each friendly ship and appends results to [param build_result].
static func _build_friendly_ship_results(log: GameLogger,
		build_result: BuildResult, friendly_ships: Array,
		enemy_ships: Array, enemy_squads: Array,
		all_ship_bodies: Array) -> void:
	for friendly: Variant in friendly_ships:
		var fs: ShipInfo = friendly as ShipInfo
		_log_ship_geometry(log, fs)
		var entry: ShipTargetingResult = _build_ship_entry(
				log, fs, enemy_ships, enemy_squads, all_ship_bodies)
		entry.incoming = _build_incoming_threats(
				fs, enemy_ships, enemy_squads, all_ship_bodies)
		build_result.ship_results.append(entry)


## Processes the optional ghost ship and appends to [param build_result].
static func _build_ghost_result(log: GameLogger,
		build_result: BuildResult, ghost: ShipInfo,
		enemy_ships: Array, enemy_squads: Array,
		all_ship_bodies: Array) -> void:
	if ghost == null:
		return
	_log_ship_geometry(log, ghost)
	var ghost_entry: ShipTargetingResult = _build_ship_entry(
			log, ghost, enemy_ships, enemy_squads, all_ship_bodies)
	ghost_entry.incoming = _build_incoming_threats(
			ghost, enemy_ships, enemy_squads, all_ship_bodies)
	ghost_entry.ship_name = ghost.ship_name + " (projected)"
	build_result.ship_results.append(ghost_entry)


## Processes each friendly squadron and appends to [param build_result].
static func _build_friendly_squad_results(log: GameLogger,
		build_result: BuildResult, friendly_squads: Array,
		enemy_ships: Array, enemy_squads: Array,
		all_ship_bodies: Array) -> void:
	for friendly_sq: Variant in friendly_squads:
		var fsq: SquadInfo = friendly_sq as SquadInfo
		log.debug("[%s] pos=%s r=%.0f" % [
				fsq.squad_name, _v2str(fsq.pos), fsq.radius])
		var sq_entry: SquadTargetingResult = _build_squad_entry(
				log, fsq, enemy_ships, enemy_squads, all_ship_bodies)
		sq_entry.incoming = _build_incoming_squad_threats(
				log, fsq, enemy_ships, enemy_squads, all_ship_bodies)
		build_result.squad_results.append(sq_entry)


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
# Internal — Hull-Zone Edge Helper
# =========================================================================

## Returns the hull-zone edge polyline for [param ship], preferring arc-based
## multi-segment edges when corner_* keys are present in arc_pts.
## Falls back to a rectangle-corner two-point edge otherwise.
## Requirements: HZ-EDGE-001.
static func _get_ship_edge(
		ship: ShipInfo, zone: Constants.HullZone) -> Array[Vector2]:
	if not ship.arc_pts.is_empty() and ship.arc_pts.has("corner_front_left"):
		return RangeFinder.get_hull_zone_edge_from_arcs(ship.arc_pts, zone)
	return RangeFinder.get_hull_zone_edge(
			ship.pos, ship.rot, ship.half_w, ship.half_l, zone)


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
		var atk_edge: Array[Vector2] = _get_ship_edge(friendly, hz)
		log.debug("  [%s] zone %s edge=[%s..%s]" % [
				friendly.ship_name, _hz_key(hz),
				_v2str(atk_edge[0]), _v2str(atk_edge[-1])])
		# Ship targets (need battery armament for this hull zone).
		var armament: Dictionary = friendly.battery_armament.get(
				_hz_key(hz), {})
		if not armament.is_empty():
			for enemy: Variant in enemy_ships:
				var es: ShipInfo = enemy as ShipInfo
				var entries: Array = _check_ship_target(
						log, friendly, hz, atk_edge, armament,
						es, all_ship_bodies)
				result.outgoing.append_array(entries)
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
## Returns an Array of TargetEntry — one per reachable defending hull zone.
## Requirements: TL-LIST-013, AC-TL-34.
static func _check_ship_target(
		log: GameLogger,
		atk: ShipInfo,
		atk_zone: Constants.HullZone,
		atk_edge: Array[Vector2],
		armament: Dictionary,
		defender: ShipInfo,
		all_ship_bodies: Array) -> Array:
	log.debug("    check ship '%s' from %s arc" % [
			defender.ship_name, _hz_key(atk_zone)])
	var def_zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	var results: Array = []
	for dz: int in def_zones:
		var def_hz: Constants.HullZone = dz as Constants.HullZone
		var entry: TargetEntry = _validate_ship_zone(
				log, atk, atk_zone, atk_edge, armament,
				defender, def_hz, all_ship_bodies)
		if entry != null:
			results.append(entry)
	if results.is_empty():
		log.debug("    -> no valid target from '%s'" % defender.ship_name)
	return results


## Validates one defending hull zone of [param defender] as a target.
## Returns a TargetEntry if valid, null otherwise.
static func _validate_ship_zone(
		log: GameLogger,
		atk: ShipInfo,
		atk_zone: Constants.HullZone,
		atk_edge: Array[Vector2],
		armament: Dictionary,
		defender: ShipInfo,
		def_hz: Constants.HullZone,
		all_ship_bodies: Array) -> TargetEntry:
	var def_edge: Array[Vector2] = _get_ship_edge(defender, def_hz)
	var in_arc: bool = RangeFinder.is_hull_zone_edge_in_arc(
			def_edge, atk_zone, atk.arc_pts)
	log.debug("      def_zone %s edge=[%s..%s] in_arc=%s" % [
			_hz_key(def_hz), _v2str(def_edge[0]),
			_v2str(def_edge[-1]), str(in_arc)])
	if not in_arc:
		return null
	var dist: float = RangeFinder.measure_attack_range_ship(
			atk_edge, def_edge, atk_zone, atk.arc_pts)
	if dist >= INF:
		log.debug("      dist=INF — skipped")
		return null
	var band: String = GameScale.get_range_band(dist)
	log.debug("      dist=%.1f band=%s" % [dist, band])
	if band == Constants.RANGE_BAND_BEYOND:
		return null
	if not RangeFinder.is_within_max_range(band, armament):
		return null
	var los_result: LineOfSightChecker.LOSResult = _check_ship_los(
			atk, atk_zone, atk_edge, defender, def_hz, def_edge,
			all_ship_bodies)
	if los_result == null:
		return null
	var entry: TargetEntry = TargetEntry.new()
	entry.target_name = defender.ship_name
	entry.arc = atk_zone
	entry.target_zone = def_hz
	entry.has_target_zone = true
	entry.range_band = band
	entry.dice = RangeFinder.dice_at_range(armament, band)
	entry.obstructed = los_result.obstructed
	entry.obstructed_by = los_result.obstructed_by
	log.debug("    -> HIT ship '%s' atk=%s def=%s band=%s dist=%.1f" % [
			defender.ship_name, _hz_key(atk_zone),
			_hz_key(def_hz), band, dist])
	return entry


## Performs LOS trace and range-path blocking for ship→ship.
## Returns LOSResult if LOS and range path are valid, null otherwise.
## Requirements: TL-LOS-001, TL-LOS-004.
static func _check_ship_los(
		atk: ShipInfo,
		atk_zone: Constants.HullZone,
		atk_edge: Array[Vector2],
		defender: ShipInfo,
		def_hz: Constants.HullZone,
		def_edge: Array[Vector2],
		all_ship_bodies: Array) -> LineOfSightChecker.LOSResult:
	var atk_los: Vector2 = atk.los_pts.get(
			_hz_key(atk_zone), atk.pos)
	var def_los: Vector2 = defender.los_pts.get(
			_hz_key(def_hz), defender.pos)
	var bodies: Array = _get_intervening_bodies(atk, defender,
			all_ship_bodies)
	var los_result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_ship_to_ship(
					atk_los, def_los, def_hz,
					defender.pos, defender.rot,
					defender.half_w, defender.half_l,
					bodies, [],
					defender.arc_pts)
	if not los_result.has_los:
		return null
	var range_blocked: bool = LineOfSightChecker.is_range_path_blocked(
			RangeFinder.closest_point_on_segment(
					def_edge[0].lerp(def_edge[1], 0.5),
					atk_edge[0], atk_edge[1]),
			def_edge[0].lerp(def_edge[1], 0.5),
			def_hz,
			defender.pos, defender.rot,
			defender.half_w, defender.half_l,
			defender.arc_pts)
	if range_blocked:
		return null
	return los_result


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
	if anti_sq_armament.is_empty():
		return null
	var in_arc: bool = RangeFinder.is_squadron_in_arc(
			squad.pos, squad.radius, atk_zone, atk.arc_pts)
	log.debug("    check squad '%s' pos=%s r=%.0f %s arc in_arc=%s" % [
			squad.squad_name, _v2str(squad.pos), squad.radius,
			_hz_key(atk_zone), str(in_arc)])
	if not in_arc:
		return null
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
	var los_result: LineOfSightChecker.LOSResult = \
			_check_squad_los(atk, atk_zone, squad, all_ship_bodies)
	if not los_result.has_los:
		log.debug("      no LOS — skipped")
		return null
	log.debug("    -> HIT squad '%s' zone=%s band=%s dist=%.1f" % [
			squad.squad_name, _hz_key(atk_zone), band, dist])
	return _make_squad_target_entry(
			squad, atk_zone, anti_sq_armament, band, los_result)


## Performs LOS trace from a ship hull zone to a squadron.
## Requirements: TL-LOS-001.
static func _check_squad_los(
		atk: ShipInfo,
		atk_zone: Constants.HullZone,
		squad: SquadInfo,
		all_ship_bodies: Array) -> LineOfSightChecker.LOSResult:
	var atk_los: Vector2 = atk.los_pts.get(_hz_key(atk_zone), atk.pos)
	var bodies: Array = []
	for entry: Variant in all_ship_bodies:
		var d: Dictionary = entry as Dictionary
		var info: ShipInfo = d["info"] as ShipInfo
		if info.ship_name == atk.ship_name:
			continue
		bodies.append(d["body"])
	return LineOfSightChecker.trace_los_ship_to_squadron(
			atk_los, squad.pos, squad.radius, bodies, [])


## Creates a TargetEntry for a squadron target.
static func _make_squad_target_entry(
		squad: SquadInfo,
		atk_zone: Constants.HullZone,
		anti_sq_armament: Dictionary,
		band: String,
		los_result: LineOfSightChecker.LOSResult) -> TargetEntry:
	var entry: TargetEntry = TargetEntry.new()
	entry.target_name = squad.squad_name
	entry.arc = atk_zone
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
	_collect_incoming_ship_threats(
			friendly, enemy_ships, all_ship_bodies, threats)
	_collect_incoming_squad_threats_to_ship(
			friendly, enemy_squads, threats)
	return threats


## Collects ship-to-ship incoming threats and appends to [param out].
static func _collect_incoming_ship_threats(
		friendly: ShipInfo, enemy_ships: Array,
		all_ship_bodies: Array, out: Array) -> void:
	var zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	for enemy: Variant in enemy_ships:
		var es: ShipInfo = enemy as ShipInfo
		for zone: int in zones:
			var hz: Constants.HullZone = zone as Constants.HullZone
			var threat: ThreatEntry = _check_ship_threat_from_zone(
					friendly, es, hz, all_ship_bodies)
			if threat != null:
				out.append(threat)


## Checks whether [param enemy] can threaten [param friendly] from
## hull zone [param hz].  Returns a ThreatEntry or null.
static func _check_ship_threat_from_zone(
		friendly: ShipInfo, enemy: ShipInfo,
		hz: Constants.HullZone,
		all_ship_bodies: Array) -> ThreatEntry:
	var armament: Dictionary = enemy.battery_armament.get(
			_hz_key(hz), {})
	if armament.is_empty():
		return null
	var atk_edge: Array[Vector2] = _get_ship_edge(enemy, hz)
	var friendly_zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	for fz: int in friendly_zones:
		var fhz: Constants.HullZone = fz as Constants.HullZone
		var def_edge: Array[Vector2] = _get_ship_edge(friendly, fhz)
		if not RangeFinder.is_hull_zone_edge_in_arc(
				def_edge, hz, enemy.arc_pts):
			continue
		var dist: float = RangeFinder.measure_attack_range_ship(
				atk_edge, def_edge, hz, enemy.arc_pts)
		if dist >= INF:
			continue
		var band: String = GameScale.get_range_band(dist)
		if band == Constants.RANGE_BAND_BEYOND:
			continue
		if not RangeFinder.is_within_max_range(band, armament):
			continue
		var los_result: LineOfSightChecker.LOSResult = _check_ship_los(
				enemy, hz, atk_edge, friendly, fhz, def_edge,
				all_ship_bodies)
		if los_result == null:
			continue
		var threat: ThreatEntry = ThreatEntry.new()
		threat.friendly_name = friendly.ship_name
		threat.enemy_name = enemy.ship_name
		threat.arc = hz
		threat.range_band = band
		threat.obstructed = los_result.obstructed
		return threat
	return null


## Collects squadron-to-ship incoming threats and appends to [param out].
## Squadrons attack at distance 1 (close range) with 360° arc.
## Requirements: TL-LIST-008.
static func _collect_incoming_squad_threats_to_ship(
		friendly: ShipInfo, enemy_squads: Array, out: Array) -> void:
	for squad: Variant in enemy_squads:
		var sq: SquadInfo = squad as SquadInfo
		if sq.battery_armament.is_empty():
			continue
		var dist: float = _measure_squad_to_ship_distance(sq, friendly)
		var band: String = GameScale.get_range_band(dist)
		if band != Constants.RANGE_BAND_CLOSE:
			continue
		var threat: ThreatEntry = ThreatEntry.new()
		threat.friendly_name = friendly.ship_name
		threat.enemy_name = sq.squad_name
		threat.arc = Constants.HullZone.FRONT
		threat.range_band = "in range"
		threat.obstructed = false
		out.append(threat)


# =========================================================================
# Internal — Squadron Outgoing Targets
# =========================================================================

## Builds outgoing targets for one friendly squadron.
## Squadrons have 360° arc and attack at distance 1 (close range).
## Requirements: TL-LIST-011, TL-RNG-003, AC-TL-30–32.
## Rules Reference: "Firing Arc" — "Each squadron has a 360° firing arc."
## Rules Reference: "Attack Range" — "Each squadron's attack range is distance 1."
static func _build_squad_entry(
		log: GameLogger,
		squad: SquadInfo,
		enemy_ships: Array,
		enemy_squads: Array,
		all_ship_bodies: Array) -> SquadTargetingResult:
	var result: SquadTargetingResult = SquadTargetingResult.new()
	result.squad_name = squad.squad_name
	_collect_squad_vs_ships(log, squad, enemy_ships,
			all_ship_bodies, result.outgoing)
	_collect_squad_vs_squads(log, squad, enemy_squads, result.outgoing)
	return result


## Collects outgoing targets from a friendly squadron vs enemy ships.
## Appends TargetEntry items to [param out].
## Rules Reference: "Attack", Step 1 — "The attacker must declare the
## defending hull zone."
static func _collect_squad_vs_ships(log: GameLogger, squad: SquadInfo,
		enemy_ships: Array, all_ship_bodies: Array,
		out: Array) -> void:
	if squad.battery_armament.is_empty():
		return
	var def_zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	for enemy: Variant in enemy_ships:
		var es: ShipInfo = enemy as ShipInfo
		for dz: int in def_zones:
			var def_hz: Constants.HullZone = dz as Constants.HullZone
			var entry: TargetEntry = _check_squad_vs_ship_zone(
					log, squad, es, def_hz, all_ship_bodies)
			if entry != null:
				out.append(entry)


## Validates one defending hull zone for a squadron→ship attack.
## Returns a TargetEntry if valid, null otherwise.
## Requirements: TL-LOS-003, TL-LOS-004.
static func _check_squad_vs_ship_zone(log: GameLogger, squad: SquadInfo,
		es: ShipInfo, def_hz: Constants.HullZone,
		all_ship_bodies: Array) -> TargetEntry:
	var edge: Array[Vector2] = _get_ship_edge(es, def_hz)
	var cp: Vector2 = RangeFinder.closest_point_on_polyline(
			squad.pos, edge)
	var dist: float = squad.pos.distance_to(cp) - squad.radius
	if dist < 0.0:
		dist = 0.0
	var band: String = GameScale.get_range_band(dist)
	log.debug("  squad '%s' -> ship '%s' %s dist=%.1f band=%s" % [
			squad.squad_name, es.ship_name,
			_hz_key(def_hz), dist, band])
	if band != Constants.RANGE_BAND_CLOSE:
		return null
	var def_los: Vector2 = es.los_pts.get(_hz_key(def_hz), es.pos)
	var bodies: Array = _get_intervening_squad_bodies(es, all_ship_bodies)
	var los_result: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_squad_to_ship(
					squad.pos, squad.radius,
					def_los, def_hz,
					es.pos, es.rot,
					es.half_w, es.half_l,
					bodies, [],
					es.arc_pts)
	if not los_result.has_los:
		log.debug("    LOS blocked for zone %s — skipped" %
				_hz_key(def_hz))
		return null
	var range_blocked: bool = LineOfSightChecker.is_range_path_blocked(
			RangeFinder.closest_point_on_circle(
					cp, squad.pos, squad.radius),
			cp, def_hz,
			es.pos, es.rot,
			es.half_w, es.half_l,
			es.arc_pts)
	if range_blocked:
		log.debug("    range path blocked for zone %s — skipped" %
				_hz_key(def_hz))
		return null
	var entry: TargetEntry = TargetEntry.new()
	entry.target_name = es.ship_name
	entry.arc = Constants.HullZone.FRONT
	entry.target_zone = def_hz
	entry.has_target_zone = true
	entry.range_band = "in range"
	entry.dice = RangeFinder.dice_at_range(squad.battery_armament, band)
	entry.obstructed = los_result.obstructed
	entry.obstructed_by = los_result.obstructed_by
	log.debug("    -> HIT ship '%s' zone=%s" % [
			es.ship_name, _hz_key(def_hz)])
	return entry


## Collects outgoing targets from a friendly squadron vs enemy squadrons.
## Appends TargetEntry items to [param out].
static func _collect_squad_vs_squads(log: GameLogger, squad: SquadInfo,
		enemy_squads: Array, out: Array) -> void:
	if squad.anti_squadron_armament.is_empty():
		return
	for enemy_sq: Variant in enemy_squads:
		var esq: SquadInfo = enemy_sq as SquadInfo
		var dist: float = _measure_squad_to_squad_distance(squad, esq)
		var band: String = GameScale.get_range_band(dist)
		log.debug("  squad '%s' -> squad '%s' dist=%.1f band=%s" % [
				squad.squad_name, esq.squad_name, dist, band])
		if band != Constants.RANGE_BAND_CLOSE:
			continue
		var entry: TargetEntry = TargetEntry.new()
		entry.target_name = esq.squad_name
		entry.arc = Constants.HullZone.FRONT
		entry.has_target_zone = false
		entry.range_band = "in range"
		entry.dice = RangeFinder.dice_at_range(
				squad.anti_squadron_armament, band)
		out.append(entry)
		log.debug("    -> HIT squad '%s'" % esq.squad_name)


## Builds incoming threats for one friendly squadron from all enemy ships
## and squadrons.
## Requirements: TL-LIST-012, AC-TL-33.
static func _build_incoming_squad_threats(
		log: GameLogger,
		squad: SquadInfo,
		enemy_ships: Array,
		enemy_squads: Array,
		all_ship_bodies: Array) -> Array:
	var threats: Array = []
	_collect_ship_threats_to_squad(
			log, squad, enemy_ships, all_ship_bodies, threats)
	_collect_squad_threats_to_squad(log, squad, enemy_squads, threats)
	return threats


## Collects ship→squadron incoming threats and appends to [param out].
static func _collect_ship_threats_to_squad(log: GameLogger,
		squad: SquadInfo, enemy_ships: Array,
		all_ship_bodies: Array, out: Array) -> void:
	var zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]
	for enemy: Variant in enemy_ships:
		var es: ShipInfo = enemy as ShipInfo
		if es.anti_squadron_armament.is_empty():
			continue
		var threat: ThreatEntry = _check_ship_threat_to_squad(
				log, squad, es, zones, all_ship_bodies)
		if threat != null:
			out.append(threat)


## Checks if [param es] can threaten [param squad] from any hull zone.
## Returns the first valid ThreatEntry, or null.
static func _check_ship_threat_to_squad(log: GameLogger,
		squad: SquadInfo, es: ShipInfo, zones: Array,
		all_ship_bodies: Array) -> ThreatEntry:
	for zone: int in zones:
		var hz: Constants.HullZone = zone as Constants.HullZone
		var atk_edge: Array[Vector2] = _get_ship_edge(es, hz)
		if not RangeFinder.is_squadron_in_arc(
				squad.pos, squad.radius, hz, es.arc_pts):
			continue
		var dist: float = RangeFinder.measure_attack_range_squadron(
				atk_edge, squad.pos, squad.radius, hz, es.arc_pts)
		if dist >= INF:
			continue
		var band: String = GameScale.get_range_band(dist)
		if band == Constants.RANGE_BAND_BEYOND:
			continue
		if not RangeFinder.is_within_max_range(
				band, es.anti_squadron_armament):
			continue
		var los_result: LineOfSightChecker.LOSResult = \
				_check_squad_los(es, hz, squad, all_ship_bodies)
		if not los_result.has_los:
			continue
		var threat: ThreatEntry = ThreatEntry.new()
		threat.friendly_name = squad.squad_name
		threat.enemy_name = es.ship_name
		threat.arc = hz
		threat.range_band = band
		threat.obstructed = los_result.obstructed
		log.debug("  squad '%s' threatened by ship '%s' %s arc" % [
				squad.squad_name, es.ship_name, _hz_key(hz)])
		return threat
	return null


## Collects squad→squad incoming threats and appends to [param out].
static func _collect_squad_threats_to_squad(log: GameLogger,
		squad: SquadInfo, enemy_squads: Array, out: Array) -> void:
	for enemy_sq: Variant in enemy_squads:
		var esq: SquadInfo = enemy_sq as SquadInfo
		if esq.anti_squadron_armament.is_empty():
			continue
		var dist: float = _measure_squad_to_squad_distance(esq, squad)
		var band: String = GameScale.get_range_band(dist)
		if band != Constants.RANGE_BAND_CLOSE:
			continue
		var threat: ThreatEntry = ThreatEntry.new()
		threat.friendly_name = squad.squad_name
		threat.enemy_name = esq.squad_name
		threat.arc = Constants.HullZone.FRONT
		threat.range_band = "in range"
		threat.obstructed = false
		out.append(threat)
		log.debug("  squad '%s' threatened by squad '%s'" % [
				squad.squad_name, esq.squad_name])


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
		var edge: Array[Vector2] = _get_ship_edge(ship, hz)
		# Closest point on the hull zone edge from the squadron centre.
		var cp: Vector2 = RangeFinder.closest_point_on_polyline(
				squad.pos, edge)
		# Subtract squadron radius (measure from base edge, not centre).
		var dist: float = squad.pos.distance_to(cp) - squad.radius
		if dist < 0.0:
			dist = 0.0
		if dist < best_dist:
			best_dist = dist
	return best_dist


## Measures distance between two squadron base edges (edge to edge).
## Requirements: TL-LIST-011, TL-LIST-012.
static func _measure_squad_to_squad_distance(
		sq_a: SquadInfo, sq_b: SquadInfo) -> float:
	var centre_dist: float = sq_a.pos.distance_to(sq_b.pos)
	var edge_dist: float = centre_dist - sq_a.radius - sq_b.radius
	if edge_dist < 0.0:
		edge_dist = 0.0
	return edge_dist


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


## Returns an array of ObstructionBody excluding only the defender ship.
## Used for squadron→ship LOS where the squadron is not in all_ship_bodies.
## Requirements: TL-LOS-005.
static func _get_intervening_squad_bodies(
		defender: ShipInfo,
		all_ship_bodies: Array) -> Array:
	var bodies: Array = []
	for entry: Variant in all_ship_bodies:
		var d: Dictionary = entry as Dictionary
		var info: ShipInfo = d["info"] as ShipInfo
		if info.ship_name == defender.ship_name:
			continue
		bodies.append(d["body"])
	return bodies


## Formats a Vector2 compactly for log output.
static func _v2str(v: Vector2) -> String:
	return "(%.1f,%.1f)" % [v.x, v.y]

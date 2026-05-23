## EngagementResolver
##
## Pure-logic helper that determines squadron engagement status.
## A squadron is engaged with every enemy squadron at distance 1 of it with
## unobstructed squadron-to-squadron line of sight.
## Engaged squadrons cannot move and (normally) must attack an engaged target.
##
## Distance 1 is measured edge-to-edge using [SquadronBase.distance_to_squadron].
## The threshold is GameScale.distance_bands_px[0] (the first distance band).
##
## Rules Reference: "Engagement", RRG p.4 — obstructed squadrons are not
## engaged even when they are at distance 1; SM-010–015.
class_name EngagementResolver
extends RefCounted


## Returns all enemy SquadronInstances that are engaged with [param squadron].
## [param squadron] — the squadron to check.
## [param squadron_pos] — world position of the squadron token.
## [param all_squadrons] — array of dictionaries:
##     {"instance": SquadronInstance, "position": Vector2}
## Rules Reference: SM-010 — distance 1 from enemy squadron; RRG
## "Engagement" — obstructed squadron LOS breaks engagement.
static func get_engaged_enemies(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> Array[SquadronInstance]:
	var result: Array[SquadronInstance] = []
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist1_px: float = _get_distance_1_px()
	for entry: Dictionary in all_squadrons:
		var other: SquadronInstance = _entry_squadron(entry)
		if _skip_engagement_candidate(squadron, other):
			continue
		var other_pos: Vector2 = entry["position"] as Vector2
		var edge_dist: float = _edge_distance(
				squadron_pos, radius, other_pos, radius)
		if edge_dist <= dist1_px and _has_unobstructed_squadron_los(
				squadron_pos, other_pos, radius, obstruction_bodies, obstacles):
			result.append(other)
	return result


## Returns true if [param squadron] is engaged with any enemy.
## Convenience wrapper around [method get_engaged_enemies].
static func is_engaged(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	return not get_engaged_enemies(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles).is_empty()


## Updates [member SquadronInstance.is_engaged] for every squadron in the
## provided list.  Call this after any position change (move, destruction).
## [param all_squadrons] — array of {"instance": SquadronInstance,
##     "position": Vector2}.
## Rules Reference: SM-010, SM-015; RRG "Engagement" obstruction clause.
static func update_engagement_flags(
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> void:
	for entry: Dictionary in all_squadrons:
		var sq: SquadronInstance = entry["instance"] as SquadronInstance
		if sq.is_destroyed():
			sq.is_engaged = false
			continue
		sq.is_engaged = is_engaged(
				sq, entry["position"] as Vector2, all_squadrons,
				obstruction_bodies, obstacles)


## Returns true if [param squadron] can move.
## An engaged squadron cannot move (SM-011), unless the future Heavy/Grit
## keywords say otherwise (resolved via the effect system).
## This method checks raw engagement only; callers should also run the
## SQUADRON_CAN_MOVE hook for keyword overrides.
## Rules Reference: SM-011 — "An engaged squadron cannot move."
static func can_squadron_move(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	return not is_engaged(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles)


## Returns true if [param squadron] must attack an engaged enemy (rather
## than a ship).  Engagement forces anti-squadron attacks (SM-012).
## Rules Reference: SM-012 — "An engaged squadron must attack an enemy
## squadron it is engaged with."
static func must_attack_engaged_target(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	return is_engaged(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles)


## Returns all enemy squadrons engaged with [param squadron] that are
## valid attack targets.  If any of them has the Escort keyword, only
## Escort targets are returned (SM-031).
## Rules Reference: SM-012, SM-031.
static func get_valid_engaged_targets(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> Array[SquadronInstance]:
	var engaged: Array[SquadronInstance] = get_engaged_enemies(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles)
	if engaged.is_empty():
		return engaged
	# Check if any engaged enemy has Escort.
	var has_escort: bool = false
	for enemy: SquadronInstance in engaged:
		if enemy.squadron_data and enemy.squadron_data.has_keyword("Escort"):
			has_escort = true
			break
	if not has_escort:
		return engaged
	# Filter to Escort targets only.
	var escort_targets: Array[SquadronInstance] = []
	for enemy: SquadronInstance in engaged:
		if enemy.squadron_data and enemy.squadron_data.has_keyword("Escort"):
			escort_targets.append(enemy)
	return escort_targets


## Returns true if [param attacker] has the Swarm keyword and the
## [param target] is also engaged with at least one other friendly
## squadron of the attacker.
## Rules Reference: SM-032.
static func is_swarm_eligible(
		attacker: SquadronInstance,
		_attacker_pos: Vector2,
		target: SquadronInstance,
		target_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	if not attacker.squadron_data:
		return false
	if not attacker.squadron_data.has_keyword("Swarm"):
		return false
	# Check if any other friendly squadron of the attacker also engages
	# the target.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist1_px: float = _get_distance_1_px()
	for entry: Dictionary in all_squadrons:
		var sq: SquadronInstance = entry["instance"] as SquadronInstance
		if sq == attacker or sq == target:
			continue
		if sq.owner_player != attacker.owner_player:
			continue
		if sq.is_destroyed():
			continue
		var sq_pos: Vector2 = entry["position"] as Vector2
		var edge_dist: float = _edge_distance(
				sq_pos, radius, target_pos, radius)
		if edge_dist <= dist1_px and _has_unobstructed_squadron_los(
				sq_pos, target_pos, radius, obstruction_bodies, obstacles):
			return true
	return false


## Builds ship obstruction bodies from serialized [GameState] ship positions.
## Rules Reference: RRG "Engagement" — obstructed squadron LOS breaks
## engagement; RRG "Line of Sight" — ships can obstruct line of sight.
static func obstruction_bodies_from_state(game_state: GameState) -> Array:
	var bodies: Array = []
	if game_state == null:
		return bodies
	var play_area_size: Vector2 = _play_area_size_for_positions()
	for player_state: PlayerState in game_state.player_states:
		_append_player_ship_obstructions(bodies, player_state, play_area_size)
	return bodies


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns the pixel threshold for distance band 1 (engagement range).
static func _get_distance_1_px() -> float:
	if GameScale.distance_bands_px.size() > 0:
		return GameScale.distance_bands_px[0]
	# Fallback — should never happen in a properly initialised game.
	return 100.0


## Returns edge-to-edge distance between two circles.
## Delegates to [code]RangeFinder.measure_range_squad_to_squad()[/code]
## for single-source compliance.
static func _edge_distance(
		pos_a: Vector2, radius_a: float,
		pos_b: Vector2, radius_b: float) -> float:
	var result: Dictionary = RangeFinder.measure_range_squad_to_squad(
			pos_a, radius_a, pos_b, radius_b)
	return result["distance"]


static func _entry_squadron(entry: Dictionary) -> SquadronInstance:
	return entry.get("instance", null) as SquadronInstance


static func _skip_engagement_candidate(squadron: SquadronInstance,
		other: SquadronInstance) -> bool:
	if squadron == null or other == null or other == squadron:
		return true
	if other.owner_player == squadron.owner_player:
		return true
	return other.is_destroyed()


static func _has_unobstructed_squadron_los(pos_a: Vector2,
		pos_b: Vector2,
		radius: float,
		obstruction_bodies: Array,
		obstacles: Array) -> bool:
	if obstruction_bodies.is_empty() and obstacles.is_empty():
		return true
	var los: LineOfSightChecker.LOSResult = \
			LineOfSightChecker.trace_los_squad_to_squad(
					pos_a, radius, pos_b, radius,
					obstruction_bodies, obstacles)
	return los.has_los and not los.obstructed


static func _append_player_ship_obstructions(target: Array,
		player_state: PlayerState,
		play_area_size: Vector2) -> void:
	if player_state == null:
		return
	for ship_var: Variant in player_state.ships:
		var ship: ShipInstance = ship_var as ShipInstance
		if ship != null and ship.ship_data != null and not ship.is_destroyed():
			target.append(_ship_obstruction_body(ship, play_area_size))


static func _ship_obstruction_body(ship: ShipInstance,
		play_area_size: Vector2) -> LineOfSightChecker.ObstructionBody:
	var ship_size: Vector2 = GameScale.get_base_size(ship.ship_data.ship_size)
	return LineOfSightChecker.ObstructionBody.from_ship_base(
			ship.ship_data.ship_name,
			ship.get_pixel_position(play_area_size),
			ship.get_rotation_rad(),
			ship_size.x * 0.5,
			ship_size.y * 0.5)


static func _play_area_size_for_positions() -> Vector2:
	if GameScale.play_area_size_px.x > 0.0 and GameScale.play_area_size_px.y > 0.0:
		return GameScale.play_area_size_px
	return Vector2(1000.0, 1000.0)

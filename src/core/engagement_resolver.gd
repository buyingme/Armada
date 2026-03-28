## EngagementResolver
##
## Pure-logic helper that determines squadron engagement status.
## A squadron is engaged with every enemy squadron at distance 1 of it.
## Engaged squadrons cannot move and (normally) must attack an engaged target.
##
## Distance 1 is measured edge-to-edge using [SquadronBase.distance_to_squadron].
## The threshold is GameScale.distance_bands_px[0] (the first distance band).
##
## Rules Reference: "Engagement", RRG p.4; SM-010–015.
class_name EngagementResolver
extends RefCounted


## Returns all enemy SquadronInstances that are engaged with [param squadron].
## [param squadron] — the squadron to check.
## [param squadron_pos] — world position of the squadron token.
## [param all_squadrons] — array of dictionaries:
##     {"instance": SquadronInstance, "position": Vector2}
## Rules Reference: SM-010 — distance 1 from enemy squadron.
static func get_engaged_enemies(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary]) -> Array[SquadronInstance]:
	var result: Array[SquadronInstance] = []
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist1_px: float = _get_distance_1_px()
	for entry: Dictionary in all_squadrons:
		var other: SquadronInstance = entry["instance"] as SquadronInstance
		if other == squadron:
			continue
		# SM-013: squadrons do not engage friendly squadrons.
		if other.owner_player == squadron.owner_player:
			continue
		# SM-015: destroyed squadrons are not engaged.
		if other.is_destroyed():
			continue
		var other_pos: Vector2 = entry["position"] as Vector2
		var edge_dist: float = _edge_distance(
				squadron_pos, radius, other_pos, radius)
		if edge_dist <= dist1_px:
			result.append(other)
	return result


## Returns true if [param squadron] is engaged with any enemy.
## Convenience wrapper around [method get_engaged_enemies].
static func is_engaged(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary]) -> bool:
	return not get_engaged_enemies(
			squadron, squadron_pos, all_squadrons).is_empty()


## Updates [member SquadronInstance.is_engaged] for every squadron in the
## provided list.  Call this after any position change (move, destruction).
## [param all_squadrons] — array of {"instance": SquadronInstance,
##     "position": Vector2}.
## Rules Reference: SM-010, SM-015.
static func update_engagement_flags(
		all_squadrons: Array[Dictionary]) -> void:
	for entry: Dictionary in all_squadrons:
		var sq: SquadronInstance = entry["instance"] as SquadronInstance
		if sq.is_destroyed():
			sq.is_engaged = false
			continue
		sq.is_engaged = is_engaged(
				sq, entry["position"] as Vector2, all_squadrons)


## Returns true if [param squadron] can move.
## An engaged squadron cannot move (SM-011), unless the future Heavy/Grit
## keywords say otherwise (resolved via the effect system).
## This method checks raw engagement only; callers should also run the
## SQUADRON_CAN_MOVE hook for keyword overrides.
## Rules Reference: SM-011 — "An engaged squadron cannot move."
static func can_squadron_move(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary]) -> bool:
	return not is_engaged(squadron, squadron_pos, all_squadrons)


## Returns true if [param squadron] must attack an engaged enemy (rather
## than a ship).  Engagement forces anti-squadron attacks (SM-012).
## Rules Reference: SM-012 — "An engaged squadron must attack an enemy
## squadron it is engaged with."
static func must_attack_engaged_target(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary]) -> bool:
	return is_engaged(squadron, squadron_pos, all_squadrons)


## Returns all enemy squadrons engaged with [param squadron] that are
## valid attack targets.  If any of them has the Escort keyword, only
## Escort targets are returned (SM-031).
## Rules Reference: SM-012, SM-031.
static func get_valid_engaged_targets(
		squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary]) -> Array[SquadronInstance]:
	var engaged: Array[SquadronInstance] = get_engaged_enemies(
			squadron, squadron_pos, all_squadrons)
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
		attacker_pos: Vector2,
		target: SquadronInstance,
		target_pos: Vector2,
		all_squadrons: Array[Dictionary]) -> bool:
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
		if edge_dist <= dist1_px:
			return true
	return false


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
static func _edge_distance(
		pos_a: Vector2, radius_a: float,
		pos_b: Vector2, radius_b: float) -> float:
	return maxf(0.0, pos_a.distance_to(pos_b) - radius_a - radius_b)

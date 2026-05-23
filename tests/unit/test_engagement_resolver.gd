## Test: EngagementResolver
##
## Unit tests for pure-logic engagement calculations.
## Rules Reference: "Engagement", RRG p.4; SM-010–015, SM-031, SM-032.
extends GutTest


## Helper: create a SquadronInstance with optional keywords.
func _make_squadron(player: int, keywords: Array[String] = [],
		speed: int = 3) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "TestSquad"
	data.hull = 3
	data.speed = speed
	data.defense_tokens = []
	var kw_array: Array[Dictionary] = []
	for kw: String in keywords:
		kw_array.append({"name": kw})
	data.keywords = kw_array
	return SquadronInstance.create_from_data("sq", data, player)


## Helper: create all-squadrons array entry.
func _entry(inst: SquadronInstance,
		pos: Vector2) -> Dictionary:
	return {"instance": inst, "position": pos}


## Returns the pixel threshold for distance 1 (engagement).
func _dist1() -> float:
	return GameScale.distance_bands_px[0]


func _close_pos() -> Vector2:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	return Vector2(center_dist, 0.0)


func _obstruction_between(pos_a: Vector2, pos_b: Vector2) -> Array:
	var mid_point: Vector2 = pos_a.lerp(pos_b, 0.5)
	return [LineOfSightChecker.ObstructionBody.from_ship_base(
			"Blocker", mid_point, 0.0, 40.0, 80.0)]


# ===========================================================================
# get_engaged_enemies
# ===========================================================================

func test_engaged_enemies_empty_when_alone() -> void:
	var sq: SquadronInstance = _make_squadron(0)
	var all: Array[Dictionary] = [_entry(sq, Vector2.ZERO)]
	var result: Array[SquadronInstance] = \
			EngagementResolver.get_engaged_enemies(sq, Vector2.ZERO, all)
	assert_eq(result.size(), 0,
			"No enemies when squadron is alone")


func test_engaged_enemies_ignores_friendly() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(0)
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(10, 0)),
	]
	var result: Array[SquadronInstance] = \
			EngagementResolver.get_engaged_enemies(
					sq_a, Vector2.ZERO, all)
	assert_eq(result.size(), 0,
			"Friendly squadrons should not be engaged (SM-013)")


func test_engaged_enemies_finds_close_enemy() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	# Place them within distance 1.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	# Edge-to-edge = centre distance − 2×radius
	# Want edge distance = dist1 − 1 (just inside range)
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(center_dist, 0)),
	]
	var result: Array[SquadronInstance] = \
			EngagementResolver.get_engaged_enemies(
					sq_a, Vector2.ZERO, all)
	assert_eq(result.size(), 1,
			"Enemy squadron within distance 1 should be engaged")
	assert_eq(result[0], sq_b,
			"Engaged enemy should be sq_b")


func test_engaged_enemies_excludes_obstructed_close_enemy() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var enemy_pos: Vector2 = _close_pos()
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, enemy_pos),
	]
	var result: Array[SquadronInstance] = \
			EngagementResolver.get_engaged_enemies(
					sq_a, Vector2.ZERO, all,
					_obstruction_between(Vector2.ZERO, enemy_pos))
	assert_eq(result.size(), 0,
			"Obstructed close squadrons should not be engaged.")


func test_engaged_enemies_excludes_far_enemy() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	# Place far outside distance 1.
	var far_center: float = _dist1() + 2.0 * radius + 100.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(far_center, 0)),
	]
	var result: Array[SquadronInstance] = \
			EngagementResolver.get_engaged_enemies(
					sq_a, Vector2.ZERO, all)
	assert_eq(result.size(), 0,
			"Enemy beyond distance 1 should not be engaged")


func test_engaged_enemies_ignores_destroyed() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	sq_b.suffer_damage(sq_b.current_hull) # destroy it
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(10, 0)),
	]
	var result: Array[SquadronInstance] = \
			EngagementResolver.get_engaged_enemies(
					sq_a, Vector2.ZERO, all)
	assert_eq(result.size(), 0,
			"Destroyed squadrons should not be engaged (SM-015)")


# ===========================================================================
# is_engaged
# ===========================================================================

func test_is_engaged_true_when_enemy_close() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(center_dist, 0)),
	]
	assert_true(
			EngagementResolver.is_engaged(sq_a, Vector2.ZERO, all),
			"Should be engaged with close enemy")


func test_is_engaged_false_when_alone() -> void:
	var sq: SquadronInstance = _make_squadron(0)
	var all: Array[Dictionary] = [_entry(sq, Vector2.ZERO)]
	assert_false(
			EngagementResolver.is_engaged(sq, Vector2.ZERO, all),
			"Should not be engaged when alone")


# ===========================================================================
# update_engagement_flags
# ===========================================================================

func test_update_engagement_flags_sets_true() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(center_dist, 0)),
	]
	EngagementResolver.update_engagement_flags(all)
	assert_true(sq_a.is_engaged,
			"sq_a should be flagged as engaged")
	assert_true(sq_b.is_engaged,
			"sq_b should be flagged as engaged")


func test_update_engagement_flags_clears_when_far() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	sq_a.is_engaged = true # pre-set to true
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(9999, 0)),
	]
	EngagementResolver.update_engagement_flags(all)
	assert_false(sq_a.is_engaged,
			"Engagement flag should be cleared when enemies are far")


func test_update_engagement_flags_destroyed_not_engaged() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	sq_a.suffer_damage(sq_a.current_hull)
	sq_a.is_engaged = true
	var all: Array[Dictionary] = [_entry(sq_a, Vector2.ZERO)]
	EngagementResolver.update_engagement_flags(all)
	assert_false(sq_a.is_engaged,
			"Destroyed squadron should not be flagged as engaged")


# ===========================================================================
# can_squadron_move
# ===========================================================================

func test_can_move_true_when_not_engaged() -> void:
	var sq: SquadronInstance = _make_squadron(0)
	var all: Array[Dictionary] = [_entry(sq, Vector2.ZERO)]
	assert_true(
			EngagementResolver.can_squadron_move(sq, Vector2.ZERO, all),
			"Unengaged squadron should be able to move (SM-011)")


func test_can_move_false_when_engaged() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(center_dist, 0)),
	]
	assert_false(
			EngagementResolver.can_squadron_move(
					sq_a, Vector2.ZERO, all),
			"Engaged squadron should not be able to move (SM-011)")


func test_can_move_true_when_close_enemy_obstructed() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var enemy_pos: Vector2 = _close_pos()
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, enemy_pos),
	]
	assert_true(
			EngagementResolver.can_squadron_move(
					sq_a, Vector2.ZERO, all,
					_obstruction_between(Vector2.ZERO, enemy_pos)),
			"Obstructed close enemies should not prevent movement.")


# ===========================================================================
# must_attack_engaged_target
# ===========================================================================

func test_must_attack_engaged_true_when_engaged() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(center_dist, 0)),
	]
	assert_true(
			EngagementResolver.must_attack_engaged_target(
					sq_a, Vector2.ZERO, all),
			"Must attack engaged target when engaged (SM-012)")


func test_must_attack_engaged_false_when_not_engaged() -> void:
	var sq: SquadronInstance = _make_squadron(0)
	var all: Array[Dictionary] = [_entry(sq, Vector2.ZERO)]
	assert_false(
			EngagementResolver.must_attack_engaged_target(
					sq, Vector2.ZERO, all),
			"No engagement constraint when not engaged")


func test_must_attack_engaged_false_when_close_enemy_obstructed() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var enemy_pos: Vector2 = _close_pos()
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, enemy_pos),
	]
	assert_false(
			EngagementResolver.must_attack_engaged_target(
					sq_a, Vector2.ZERO, all,
					_obstruction_between(Vector2.ZERO, enemy_pos)),
			"Obstructed close enemies should not force squadron targets.")


# ===========================================================================
# get_valid_engaged_targets
# ===========================================================================

func test_valid_targets_no_escort_returns_all() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var sq_b: SquadronInstance = _make_squadron(1)
	var sq_c: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(sq_b, Vector2(center_dist, 0)),
		_entry(sq_c, Vector2(0, center_dist)),
	]
	var targets: Array[SquadronInstance] = \
			EngagementResolver.get_valid_engaged_targets(
					sq_a, Vector2.ZERO, all)
	assert_eq(targets.size(), 2,
			"Both enemies should be valid targets without Escort")


func test_valid_targets_escort_filters_to_escort() -> void:
	var sq_a: SquadronInstance = _make_squadron(0)
	var escort: SquadronInstance = _make_squadron(1, ["Escort"])
	var plain: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(sq_a, Vector2.ZERO),
		_entry(escort, Vector2(center_dist, 0)),
		_entry(plain, Vector2(0, center_dist)),
	]
	var targets: Array[SquadronInstance] = \
			EngagementResolver.get_valid_engaged_targets(
					sq_a, Vector2.ZERO, all)
	assert_eq(targets.size(), 1,
			"Only Escort target should be valid (SM-031)")
	assert_eq(targets[0], escort,
			"Valid target should be the Escort squadron")


func test_valid_targets_empty_when_not_engaged() -> void:
	var sq: SquadronInstance = _make_squadron(0)
	var all: Array[Dictionary] = [_entry(sq, Vector2.ZERO)]
	var targets: Array[SquadronInstance] = \
			EngagementResolver.get_valid_engaged_targets(
					sq, Vector2.ZERO, all)
	assert_eq(targets.size(), 0,
			"No targets when not engaged")


# ===========================================================================
# is_swarm_eligible
# ===========================================================================

func test_swarm_eligible_true_when_friendly_also_engages() -> void:
	# attacker(0) + friendly(0) both engage target(1)
	var attacker: SquadronInstance = _make_squadron(0, ["Swarm"])
	var friendly: SquadronInstance = _make_squadron(0)
	var target: SquadronInstance = _make_squadron(1)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist: float = _dist1() + 2.0 * radius - 1.0
	var all: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(target, Vector2(dist, 0)),
		_entry(friendly, Vector2(dist * 2.0, 0)), # close to target
	]
	# Friendly is dist from target (within range 1 of target).
	# But let's place friendly close to target to ensure engagement.
	all[2] = _entry(friendly, Vector2(dist + dist, 0))
	# Actually recalculate: friendly must be within dist1 edge-to-edge of target.
	# Target is at (dist, 0). Friendly at (dist + gap, 0) where gap < dist1 + 2r
	var friendly_pos: Vector2 = Vector2(dist + _dist1() + radius, 0)
	all[2] = _entry(friendly, friendly_pos)
	assert_true(
			EngagementResolver.is_swarm_eligible(
					attacker, Vector2.ZERO, target,
					Vector2(dist, 0), all),
			"Swarm should be eligible when friendly also engages target (SM-032)")


func test_swarm_eligible_false_without_keyword() -> void:
	var attacker: SquadronInstance = _make_squadron(0)
	var target: SquadronInstance = _make_squadron(1)
	var all: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(target, Vector2(10, 0)),
	]
	assert_false(
			EngagementResolver.is_swarm_eligible(
					attacker, Vector2.ZERO, target,
					Vector2(10, 0), all),
			"Swarm not eligible without Swarm keyword")


func test_swarm_eligible_false_when_no_friendly_engages() -> void:
	var attacker: SquadronInstance = _make_squadron(0, ["Swarm"])
	var target: SquadronInstance = _make_squadron(1)
	var all: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(target, Vector2(50, 0)),
	]
	assert_false(
			EngagementResolver.is_swarm_eligible(
					attacker, Vector2.ZERO, target,
					Vector2(50, 0), all),
			"Swarm not eligible when no other friendly engages target")


func test_swarm_eligible_false_when_friendly_engagement_obstructed() -> void:
	var attacker: SquadronInstance = _make_squadron(0, ["Swarm"])
	var friendly: SquadronInstance = _make_squadron(0)
	var target: SquadronInstance = _make_squadron(1)
	var target_pos: Vector2 = _close_pos()
	var friendly_pos: Vector2 = target_pos + _close_pos()
	var all: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(target, target_pos),
		_entry(friendly, friendly_pos),
	]
	assert_false(
			EngagementResolver.is_swarm_eligible(
					attacker, Vector2.ZERO, target, target_pos, all,
					_obstruction_between(target_pos, friendly_pos)),
			"Swarm should require unobstructed friendly engagement.")

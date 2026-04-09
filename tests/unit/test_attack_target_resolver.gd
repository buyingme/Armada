## Test: AttackTargetResolver
##
## Unit tests for [AttackTargetResolver] — pure-geometry resolver for attack
## targeting.  Uses real ShipToken / SquadronToken instances with manually
## set internal fields to control geometry and faction.
##
## Geometry-heavy methods (arc checking, LOS tracing, range measurement) are
## validated through the real RangeFinder / LineOfSightChecker infrastructure,
## using tokens positioned at known coordinates.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a ShipToken with the given position and faction.
## Sets _half_w and _half_l directly since setup() requires textures.
func _make_ship(pos: Vector2,
		faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE,
		half_w: float = 30.0, half_l: float = 50.0) -> ShipToken:
	var token: ShipToken = ShipToken.new()
	token._placement = TokenPlacement.new(
			"test_ship", true, faction, 0.5, 0.5, 0.0,
			Constants.ShipSize.SMALL)
	token._half_w = half_w
	token._half_l = half_l
	add_child_autofree(token)
	token.global_position = pos
	return token


## Creates a SquadronToken with the given position and faction.
## Sets _radius_px directly since setup() requires textures.
func _make_squad(pos: Vector2,
		faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE,
		radius: float = 20.0) -> SquadronToken:
	var token: SquadronToken = SquadronToken.new()
	token._placement = TokenPlacement.new(
			"test_squad", false, faction, 0.5, 0.5, 0.0)
	token._radius_px = radius
	add_child_autofree(token)
	token.global_position = pos
	return token


## Creates an AttackTargetResolver with configurable token lists.
func _make_resolver(
		ships: Array = [],
		squads: Array = [],
		obstructions: Array = []) -> AttackTargetResolver:
	return AttackTargetResolver.new(
			func() -> Array: return ships,
			func() -> Array: return squads,
			func() -> Array: return obstructions)


## Creates a CombatParticipants for ship-attacker scenarios.
func _make_ship_attack_parts(
		atk: ShipToken, zone: int,
		def_ship: ShipToken = null, def_zone: int = -1,
		def_squad: SquadronToken = null) -> CombatParticipants:
	return CombatParticipants.create(
			atk, zone, null, def_ship, def_zone, def_squad)


## Creates a CombatParticipants for squadron-attacker scenarios.
func _make_squad_attack_parts(
		atk_sq: SquadronToken,
		def_ship: ShipToken = null, def_zone: int = -1,
		def_squad: SquadronToken = null) -> CombatParticipants:
	return CombatParticipants.create(
			null, -1, atk_sq, def_ship, def_zone, def_squad)


# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

func test_constructor_stores_callables() -> void:
	var resolver: AttackTargetResolver = _make_resolver()
	assert_not_null(resolver,
			"Constructor should create a valid resolver instance")


# ---------------------------------------------------------------------------
# Arc validation — squadron attacker bypass
# ---------------------------------------------------------------------------

func test_is_ship_target_in_arc_true_for_squadron_attacker() -> void:
	var atk_sq: SquadronToken = _make_squad(Vector2(100, 100))
	var def_ship: ShipToken = _make_ship(Vector2(300, 300))
	var parts: CombatParticipants = _make_squad_attack_parts(
			atk_sq, def_ship, Constants.HullZone.FRONT)
	var resolver: AttackTargetResolver = _make_resolver()
	assert_true(resolver.is_ship_target_in_arc(parts, def_ship,
			Constants.HullZone.FRONT),
			"Squadron attacker should always be 'in arc' (no arcs)")


func test_is_squadron_target_in_arc_true_for_squadron_attacker() -> void:
	var atk_sq: SquadronToken = _make_squad(Vector2(100, 100))
	var def_sq: SquadronToken = _make_squad(Vector2(300, 300),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_squad_attack_parts(
			atk_sq, null, -1, def_sq)
	var resolver: AttackTargetResolver = _make_resolver()
	assert_true(resolver.is_squadron_target_in_arc(parts, def_sq),
			"Squadron attacker should always be 'in arc' (no arcs)")


# ---------------------------------------------------------------------------
# Arc validation — ship attacker with no arc data
# ---------------------------------------------------------------------------

func test_is_ship_target_in_arc_true_when_no_arc_data() -> void:
	# Ship with empty arc points → allow (fallback).
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var def_ship: ShipToken = _make_ship(Vector2(300, 300),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT,
			def_ship, Constants.HullZone.FRONT)
	var resolver: AttackTargetResolver = _make_resolver()
	assert_true(resolver.is_ship_target_in_arc(parts, def_ship,
			Constants.HullZone.FRONT),
			"Ship with no arc data should allow targeting (fallback)")


func test_is_squadron_target_in_arc_true_when_no_arc_data() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var def_sq: SquadronToken = _make_squad(Vector2(300, 300),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT,
			null, -1, def_sq)
	var resolver: AttackTargetResolver = _make_resolver()
	assert_true(resolver.is_squadron_target_in_arc(parts, def_sq),
			"Ship with no arc data should allow targeting (fallback)")


# ---------------------------------------------------------------------------
# Target availability — zone_has_targets
# ---------------------------------------------------------------------------

func test_zone_has_targets_false_when_no_enemies() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [])
	assert_false(resolver.zone_has_targets(
			atk_ship, Constants.HullZone.FRONT),
			"Should return false when no enemies exist")


func test_zone_has_targets_false_for_same_faction() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var ally_ship: ShipToken = _make_ship(Vector2(300, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship, ally_ship], [])
	assert_false(resolver.zone_has_targets(
			atk_ship, Constants.HullZone.FRONT),
			"Should return false when only same-faction ships exist")


func test_zone_has_targets_ignores_self() -> void:
	# Even if a ship is the only ship, skip self.
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [])
	assert_false(resolver.zone_has_targets(
			atk_ship, Constants.HullZone.FRONT),
			"zone_has_targets should skip the attacker itself")


func test_zone_has_targets_false_for_same_faction_squads() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var ally_sq: SquadronToken = _make_squad(Vector2(150, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [ally_sq])
	assert_false(resolver.zone_has_targets(
			atk_ship, Constants.HullZone.FRONT),
			"Should return false when only same-faction squadrons exist")


# ---------------------------------------------------------------------------
# Target availability — has_any_attack_target
# ---------------------------------------------------------------------------

func test_has_any_attack_target_false_for_null() -> void:
	var resolver: AttackTargetResolver = _make_resolver()
	assert_false(resolver.has_any_attack_target(null),
			"has_any_attack_target should return false for null token")


func test_has_any_attack_target_false_when_no_enemies() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [])
	assert_false(resolver.has_any_attack_target(atk_ship),
			"has_any_attack_target should return false with no enemies")


# ---------------------------------------------------------------------------
# Target availability — has_any_valid_target
# ---------------------------------------------------------------------------

func test_has_any_valid_target_false_for_null() -> void:
	var resolver: AttackTargetResolver = _make_resolver()
	var fired: Array[int] = []
	assert_false(resolver.has_any_valid_target(null, fired),
			"has_any_valid_target should return false for null token")


func test_has_any_valid_target_false_when_all_zones_fired() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [])
	var all_fired: Array[int] = [
		Constants.HullZone.FRONT, Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT, Constants.HullZone.REAR,
	]
	assert_false(resolver.has_any_valid_target(atk_ship, all_fired),
			"has_any_valid_target should return false when all zones fired")


func test_has_any_valid_target_false_when_no_enemies() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [])
	var fired: Array[int] = []
	assert_false(resolver.has_any_valid_target(atk_ship, fired),
			"has_any_valid_target should return false with no enemies")


# ---------------------------------------------------------------------------
# has_more_squad_targets
# ---------------------------------------------------------------------------

func test_has_more_squad_targets_false_for_squadron_attacker() -> void:
	var atk_sq: SquadronToken = _make_squad(Vector2(100, 100))
	var def_sq: SquadronToken = _make_squad(Vector2(150, 100),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_squad_attack_parts(
			atk_sq, null, -1, def_sq)
	var resolver: AttackTargetResolver = _make_resolver([], [def_sq])
	var attacked: Array[SquadronToken] = []
	assert_false(resolver.has_more_squad_targets(parts, attacked),
			"has_more_squad_targets should be false for squadron atk")


func test_has_more_squad_targets_false_when_no_squads() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT)
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [])
	var attacked: Array[SquadronToken] = []
	assert_false(resolver.has_more_squad_targets(parts, attacked),
			"has_more_squad_targets should be false with no enemy squads")


func test_has_more_squad_targets_false_when_only_same_faction() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var ally_sq: SquadronToken = _make_squad(Vector2(150, 100))
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT)
	var resolver: AttackTargetResolver = _make_resolver(
			[atk_ship], [ally_sq])
	var attacked: Array[SquadronToken] = []
	assert_false(resolver.has_more_squad_targets(parts, attacked),
			"has_more_squad_targets should skip same-faction squads")


# ---------------------------------------------------------------------------
# compute_los — dictionary structure
# ---------------------------------------------------------------------------

func test_compute_los_returns_required_keys() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 300))
	var def_ship: ShipToken = _make_ship(Vector2(100, 100),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT,
			def_ship, Constants.HullZone.REAR)
	var resolver: AttackTargetResolver = _make_resolver()
	var result: Dictionary = resolver.compute_los(parts)
	assert_has(result, "atk_pt",
			"compute_los result should contain 'atk_pt'")
	assert_has(result, "def_pt",
			"compute_los result should contain 'def_pt'")
	assert_has(result, "los_result",
			"compute_los result should contain 'los_result'")
	assert_has(result, "status",
			"compute_los result should contain 'status'")
	assert_has(result, "text",
			"compute_los result should contain 'text'")
	assert_has(result, "obstructed",
			"compute_los result should contain 'obstructed'")


func test_compute_los_status_is_valid_enum() -> void:
	var atk_ship: ShipToken = _make_ship(Vector2(100, 300))
	var def_ship: ShipToken = _make_ship(Vector2(100, 100),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT,
			def_ship, Constants.HullZone.REAR)
	var resolver: AttackTargetResolver = _make_resolver()
	var result: Dictionary = resolver.compute_los(parts)
	var valid_statuses: Array[int] = [
		AttackSimOverlay.LOSStatus.CLEAR,
		AttackSimOverlay.LOSStatus.OBSTRUCTED,
		AttackSimOverlay.LOSStatus.BLOCKED,
	]
	assert_has(valid_statuses, result["status"],
			"LOS status should be a valid LOSStatus enum value")


# ---------------------------------------------------------------------------
# compute_range — dictionary structure
# ---------------------------------------------------------------------------

func test_compute_range_returns_required_keys() -> void:
	var atk_sq: SquadronToken = _make_squad(Vector2(100, 300))
	var def_ship: ShipToken = _make_ship(Vector2(100, 100),
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _make_squad_attack_parts(
			atk_sq, def_ship, Constants.HullZone.REAR)
	var resolver: AttackTargetResolver = _make_resolver()
	var result: Dictionary = resolver.compute_range(parts)
	assert_has(result, "distance",
			"compute_range result should contain 'distance'")
	assert_has(result, "atk_pt",
			"compute_range result should contain 'atk_pt'")
	assert_has(result, "def_pt",
			"compute_range result should contain 'def_pt'")


func test_compute_range_squad_to_squad() -> void:
	var atk_sq: SquadronToken = _make_squad(Vector2(100, 100),
			Constants.Faction.REBEL_ALLIANCE, 20.0)
	var def_sq: SquadronToken = _make_squad(Vector2(200, 100),
			Constants.Faction.GALACTIC_EMPIRE, 20.0)
	var parts: CombatParticipants = _make_squad_attack_parts(
			atk_sq, null, -1, def_sq)
	var resolver: AttackTargetResolver = _make_resolver()
	var result: Dictionary = resolver.compute_range(parts)
	assert_has(result, "distance",
			"Squad-to-squad range should return 'distance'")
	# Distance should be roughly 100 - 20 - 20 = 60 (edge to edge).
	assert_gt(result["distance"], 0.0,
			"Squad-to-squad distance should be positive")


func test_compute_range_fallback_when_no_combatants() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	var resolver: AttackTargetResolver = _make_resolver()
	var result: Dictionary = resolver.compute_range(p)
	assert_eq(result["distance"], INF,
			"Range should be INF when no combatants are set")


# ---------------------------------------------------------------------------
# get_ship_edge — basic
# ---------------------------------------------------------------------------

func test_get_ship_edge_returns_array() -> void:
	var ship: ShipToken = _make_ship(Vector2(100, 100),
			Constants.Faction.REBEL_ALLIANCE, 30.0, 50.0)
	var resolver: AttackTargetResolver = _make_resolver()
	var edge: Array[Vector2] = resolver.get_ship_edge(
			ship, Constants.HullZone.FRONT)
	assert_typeof(edge, TYPE_ARRAY,
			"get_ship_edge should return an Array")


# ---------------------------------------------------------------------------
# is_squadron_at_range — basic
# ---------------------------------------------------------------------------

func test_is_squadron_at_range_false_when_no_arc_data() -> void:
	# Ship with no arc data; measure_attack_range_squadron_endpoints
	# should still be called but may return INF → false.
	var atk_ship: ShipToken = _make_ship(Vector2(100, 100))
	var parts: CombatParticipants = _make_ship_attack_parts(
			atk_ship, Constants.HullZone.FRONT)
	var sq: SquadronToken = _make_squad(Vector2(5000, 5000),
			Constants.Faction.GALACTIC_EMPIRE)
	var resolver: AttackTargetResolver = _make_resolver()
	assert_false(resolver.is_squadron_at_range(parts, sq),
			"Far-away squadron should not be at range")

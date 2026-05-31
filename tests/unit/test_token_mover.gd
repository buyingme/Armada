## Test: TokenMover
##
## Unit tests for TokenMover — projection-based collision resolution,
## deployment zone enforcement, and closest-legal-position logic
## for debug-mode token placement.
##
## Requirements: DBG-011, DBG-020, DBG-022, DBG-032
extends GutTest


var _mover: TokenMover = null

## Scale config mimicking 720 px ruler → 2160 px play area.
var _scale_config: Dictionary = {
	"ruler_total_length_px": 720,
	"physical_dimensions_mm": {
		"ruler_length": 305.0,
		"play_area_ruler_multiplier": 3.0,
		"maneuver_segments": 5,
		"small_base_width": 43.0,
		"small_base_length": 71.0,
		"medium_base_width": 63.0,
		"medium_base_length": 102.0,
		"large_base_width": 77.5,
		"large_base_length": 129.0,
		"squadron_base_diameter": 34.2,
	},
	"range_bands": {
		"close": {"max_px": 292},
		"medium": {"max_px": 442},
		"long": {"max_px": 720},
	},
	"distance_bands_px": [181, 294, 434, 577, 720],
	"base_graphics": {
		"small_ship": {
			"base_region_width_px": 103,
			"base_region_length_px": 171,
		},
		"medium_ship": {
			"base_region_width_px": 148,
			"base_region_length_px": 243,
		},
		"squadron_base": {
			"base_region_diameter_px": 82,
		},
	},
}


func before_each() -> void:
	_mover = TokenMover.new()
	GameScale.initialise_from_dict(_scale_config)


func after_each() -> void:
	_mover = null


# ---------------------------------------------------------------------------
# Squadron — free movement (no obstacles)
# ---------------------------------------------------------------------------

func test_resolve_squadron_free_move_returns_desired() -> void:
	# Arrange
	var desired: Vector2 = Vector2(500.0, 500.0)
	var current: Vector2 = Vector2(400.0, 400.0)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert
	assert_almost_eq(result.x, desired.x, 1.0,
			"Free squadron should reach desired X")
	assert_almost_eq(result.y, desired.y, 1.0,
			"Free squadron should reach desired Y")


# ---------------------------------------------------------------------------
# Squadron — collision with another squadron
# ---------------------------------------------------------------------------

func test_resolve_squadron_blocked_by_other_squadron() -> void:
	# Arrange — blocker at (500, 500), approach from the left.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var blocker: Array = [ {"position": Vector2(500.0, 500.0), "radius": radius}]
	var current: Vector2 = Vector2(300.0, 500.0)
	var desired: Vector2 = Vector2(460.0, 500.0)
	# Act — desired is inside the blocker's exclusion zone.
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — pushed outward along blocker→desired direction (left of blocker).
	var min_separation: float = radius * 2.0
	var dist_to_blocker: float = result.distance_to(Vector2(500.0, 500.0))
	assert_true(dist_to_blocker >= min_separation - 2.0,
			"Squadron should be pushed to at least contact distance from blocker")
	assert_true(result.x < 500.0,
			"Squadron should be to the left of the blocker (push direction)")


# ---------------------------------------------------------------------------
# Squadron — mouse beyond blocker (no overlap at desired → returns desired)
# ---------------------------------------------------------------------------

func test_resolve_squadron_beyond_blocker_returns_desired() -> void:
	# Arrange — blocker at (500, 500), cursor at (700, 500) — far side is free.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var blocker: Array = [ {"position": Vector2(500.0, 500.0), "radius": radius}]
	var current: Vector2 = Vector2(300.0, 500.0)
	var desired: Vector2 = Vector2(700.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — desired has no overlap, so it is returned directly.
	assert_almost_eq(result.x, desired.x, 1.0,
			"Squadron should reach desired X when no overlap exists")
	assert_almost_eq(result.y, desired.y, 1.0,
			"Squadron should reach desired Y when no overlap exists")


# ---------------------------------------------------------------------------
# Ship — free movement
# ---------------------------------------------------------------------------

func test_resolve_ship_free_move_returns_desired() -> void:
	# Arrange
	var desired: Vector2 = Vector2(600.0, 600.0)
	var current: Vector2 = Vector2(400.0, 400.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert
	assert_almost_eq(result.x, desired.x, 1.0,
			"Free ship should reach desired X")
	assert_almost_eq(result.y, desired.y, 1.0,
			"Free ship should reach desired Y")


# ---------------------------------------------------------------------------
# Ship — collision with another ship
# ---------------------------------------------------------------------------

func test_resolve_ship_blocked_by_other_ship() -> void:
	# Arrange — blocker small ship at (500, 500), approach from the left.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var blocker: Array = [ {
		"position": Vector2(500.0, 500.0),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	var current: Vector2 = Vector2(300.0, 500.0)
	var desired: Vector2 = Vector2(460.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			blocker, [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — pushed to closest legal position (left of blocker).
	assert_true(result.x < 500.0 - hw + 2.0,
			"Ship should be pushed to the left of the blocker")


# ---------------------------------------------------------------------------
# DBG-020 / DBG-022 — closest-to-mouse projection tests
# ---------------------------------------------------------------------------

func test_squadron_pushout_direction_follows_mouse() -> void:
	# Arrange — blocker at (500, 500), mouse above and right of blocker.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var blocker: Array = [ {"position": Vector2(500.0, 500.0), "radius": radius}]
	var current: Vector2 = Vector2(300.0, 300.0)
	var desired: Vector2 = Vector2(510.0, 480.0) # just inside exclusion zone, above-right
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — pushed along blocker→desired direction: x > 500, y < 500.
	assert_true(result.x >= 500.0,
			"Push-out should be to the right of blocker (follows mouse)")
	assert_true(result.y < 500.0,
			"Push-out should be above blocker (follows mouse)")


func test_squadron_pushout_independent_of_current_pos() -> void:
	# Arrange — same desired and blocker, but different current positions.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var blocker: Array = [ {"position": Vector2(500.0, 500.0), "radius": radius}]
	var desired: Vector2 = Vector2(510.0, 480.0)
	# Act — approach from two very different current positions.
	var result_a: Vector2 = _mover.resolve_squadron_position(
			desired, Vector2(100.0, 100.0), radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	var result_b: Vector2 = _mover.resolve_squadron_position(
			desired, Vector2(900.0, 900.0), radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — both results should be the same (position is independent of
	# the token's previous location).
	assert_almost_eq(result_a.x, result_b.x, 2.0,
			"Push-out X should be identical regardless of current_pos")
	assert_almost_eq(result_a.y, result_b.y, 2.0,
			"Push-out Y should be identical regardless of current_pos")


func test_ship_pushout_closest_to_mouse_not_movement_line() -> void:
	# Arrange — blocker at (500, 500), ship approaches from bottom-left but
	# mouse is directly above the blocker → push-out should go upward.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var blocker: Array = [ {
		"position": Vector2(500.0, 500.0),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	var current: Vector2 = Vector2(200.0, 800.0)
	var desired: Vector2 = Vector2(500.0, 450.0) # above blocker centre
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			blocker, [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — pushed upward (above blocker), not along approach diagonal.
	assert_true(result.y < 500.0,
			"Ship push-out should follow mouse direction (above blocker)")


# ---------------------------------------------------------------------------
# Deployment zone — Imperial ship blocked from crossing top line
# ---------------------------------------------------------------------------

func test_imperial_ship_blocked_by_deploy_zone() -> void:
	# Arrange — top deploy line at distance band 3 = 434 px.
	var top_y: float = 434.0
	var bottom_y: float = GameScale.play_area_side_px - 434.0
	var desired: Vector2 = Vector2(500.0, 800.0) # deep into no-go zone
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], top_y, bottom_y, GameScale.play_area_side_px)
	# Assert — Y should be above top_y.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var extent_y: float = base_size.y * 0.5 # rotation=0, so extent = half_length
	assert_true(result.y + extent_y <= top_y + 1.0,
			"Imperial ship should be clamped above the top deployment line")


func test_rebel_ship_blocked_by_deploy_zone() -> void:
	# Arrange — bottom deploy line.
	var top_y: float = 434.0
	var bottom_y: float = GameScale.play_area_side_px - 434.0
	var desired: Vector2 = Vector2(500.0, 400.0) # deep into no-go zone
	var current: Vector2 = Vector2(500.0, 1900.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], top_y, bottom_y, GameScale.play_area_side_px)
	# Assert — Y should be below bottom_y.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var extent_y: float = base_size.y * 0.5
	assert_true(result.y - extent_y >= bottom_y - 1.0,
			"Rebel ship should be clamped below the bottom deployment line")


# ---------------------------------------------------------------------------
# Deployment zone — squadron blocked
# ---------------------------------------------------------------------------

func test_imperial_squadron_blocked_by_deploy_zone() -> void:
	var top_y: float = 434.0
	var bottom_y: float = GameScale.play_area_side_px - 434.0
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var desired: Vector2 = Vector2(500.0, 800.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], top_y, bottom_y, GameScale.play_area_side_px)
	assert_true(result.y + radius <= top_y + 1.0,
			"Imperial squadron should be clamped above the top line")


# ---------------------------------------------------------------------------
# Play area clamping
# ---------------------------------------------------------------------------

func test_resolve_ship_in_rectangular_play_area_preserves_valid_wide_x() -> void:
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	var play_area_size: Vector2 = GameScale.play_area_size_px
	var desired: Vector2 = Vector2(3200.0, 1000.0)
	var current: Vector2 = Vector2(1000.0, 1000.0)
	var result: Vector2 = _mover.resolve_ship_position_in_area(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], -1.0, -1.0, play_area_size)
	assert_almost_eq(result.x, desired.x, 1.0,
			"3x6 movement should keep legal X values beyond the square height alias")
	assert_true(result.x > GameScale.play_area_side_px,
			"3x6 movement should use rectangular width, not the square-side alias")


func test_resolve_squadron_in_rectangular_play_area_clamps_to_width() -> void:
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	var play_area_size: Vector2 = GameScale.play_area_size_px
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var desired: Vector2 = Vector2(play_area_size.x + 250.0, 500.0)
	var current: Vector2 = Vector2(1000.0, 500.0)
	var result: Vector2 = _mover.resolve_squadron_position_in_area(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], -1.0, -1.0, play_area_size)
	assert_almost_eq(result.x, play_area_size.x, 1.0,
			"3x6 movement should clamp X against the rectangular board width")
	assert_almost_eq(result.y, desired.y, 1.0,
			"Rectangular X clamping should not disturb legal Y values")

func test_resolve_squadron_clamped_to_play_area() -> void:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var desired: Vector2 = Vector2(-100.0, -100.0)
	var current: Vector2 = Vector2(100.0, 100.0)
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], -1.0, -1.0, GameScale.play_area_side_px)
	assert_true(result.x >= 0.0,
			"X should be clamped to 0 or greater")
	assert_true(result.y >= 0.0,
			"Y should be clamped to 0 or greater")


func test_resolve_ship_clamped_to_play_area() -> void:
	var desired: Vector2 = Vector2(3000.0, 3000.0)
	var current: Vector2 = Vector2(1000.0, 1000.0)
	var side: float = GameScale.play_area_side_px
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], -1.0, -1.0, side)
	assert_true(result.x <= side,
			"X should be clamped to play area side")
	assert_true(result.y <= side,
			"Y should be clamped to play area side")


# ---------------------------------------------------------------------------
# Disabled deployment zones (negative values)
# ---------------------------------------------------------------------------

func test_disabled_deploy_zones_no_clamping() -> void:
	var desired: Vector2 = Vector2(500.0, 100.0)
	var current: Vector2 = Vector2(500.0, 1000.0)
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], -1.0, -1.0, GameScale.play_area_side_px)
	assert_almost_eq(result.y, desired.y, 1.0,
			"With deploy zones disabled, ship should reach desired Y")


# ---------------------------------------------------------------------------
# Bug fix — squadron centre inside ship polygon pushes outward correctly
# ---------------------------------------------------------------------------

func test_squadron_inside_ship_pushes_outward() -> void:
	# Arrange — place a ship at (500, 500), drag a squadron so its centre
	# lands INSIDE the ship polygon (to the left of the ship centre).
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var ship_blocker: Array = [ {
		"position": Vector2(500.0, 500.0),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	# Desired is inside the ship polygon, slightly left of centre.
	var desired: Vector2 = Vector2(480.0, 500.0)
	var current: Vector2 = Vector2(300.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			ship_blocker, [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — should be pushed LEFT (towards mouse), NOT right (into ship).
	assert_true(result.x < 500.0 - hw,
			"Squadron should be pushed left (outward from ship), not into it")
	# Must not overlap the ship polygon.
	var dist_to_ship: float = result.distance_to(Vector2(500.0, 500.0))
	assert_true(dist_to_ship > hw,
			"Squadron should be clear of the ship after push-out")


func test_squadron_inside_ship_approaches_from_above() -> void:
	# Arrange — squadron desired position is inside the ship polygon,
	# approaching from above (y < ship centre).
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var ship_blocker: Array = [ {
		"position": Vector2(500.0, 500.0),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	var desired: Vector2 = Vector2(500.0, 480.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			ship_blocker, [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — pushed upward (towards mouse direction from ship centre).
	assert_true(result.y < 500.0 - hl,
			"Squadron should be pushed above the ship (towards mouse)")


# ---------------------------------------------------------------------------
# Bug fix — cascade: token between two close blockers finds valid position
# ---------------------------------------------------------------------------

func test_squadron_cascade_between_two_blockers() -> void:
	# Arrange — two squadron blockers close together. Desired is between them
	# with a slight vertical offset so cascade push directions have a lateral
	# component (axis-aligned setups keep all pushes collinear and can't escape).
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var gap: float = radius * 1.5 # tight gap — no horizontal fit at all
	var blocker_a: Dictionary = {"position": Vector2(500.0, 500.0), "radius": radius}
	var blocker_b: Dictionary = {"position": Vector2(500.0 + gap, 500.0), "radius": radius}
	var desired: Vector2 = Vector2(500.0 + gap * 0.5, 490.0) # slightly above midpoint
	var current: Vector2 = Vector2(500.0 + gap * 0.5, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], [blocker_a, blocker_b], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — should NOT fall back to current_pos; cascade should find a
	# valid position near the two blockers.
	var dist_a: float = result.distance_to(blocker_a.position)
	var dist_b: float = result.distance_to(blocker_b.position)
	assert_true(dist_a >= radius * 2.0 - 2.0,
			"Result should not overlap blocker A")
	assert_true(dist_b >= radius * 2.0 - 2.0,
			"Result should not overlap blocker B")
	# Should be close to the desired position — not at current_pos (far away).
	var dist_to_desired: float = result.distance_to(desired)
	assert_true(dist_to_desired < 200.0,
			"Cascade result should be near the desired position, not at current_pos")


# ---------------------------------------------------------------------------
# Bug fix — only push from overlapping blockers (no spurious candidates)
# ---------------------------------------------------------------------------

func test_squadron_not_pushed_toward_non_overlapping_blocker() -> void:
	# Arrange — squadron overlaps Ship A at (500, 500). Ship B at (200, 500)
	# does NOT overlap the squadron. Previously, the push from B generated a
	# spurious candidate on B's contact surface that could be selected.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var ship_a: Dictionary = {
		"position": Vector2(500.0, 500.0), "rotation": 0.0,
		"half_w": hw, "half_l": hl,
	}
	var ship_b: Dictionary = {
		"position": Vector2(200.0, 500.0), "rotation": 0.0,
		"half_w": hw, "half_l": hl,
	}
	# Desired is left of Ship A's center, inside Ship A's polygon.
	var desired: Vector2 = Vector2(470.0, 500.0)
	var current: Vector2 = Vector2(300.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[ship_a, ship_b], [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — result should be pushed from Ship A leftward,
	# not snapped to Ship B's contact surface.
	assert_true(result.x < 500.0 - hw,
			"Squadron should slide off Ship A to the left")
	assert_true(result.x > 250.0 + hw + radius,
			"Squadron should NOT be snapped to Ship B's right contact edge")


func test_ship_pushout_uses_candidate_not_raw_mouse() -> void:
	# Arrange — Imperial faction, deploy zone at Y=434. Mouse is deep in
	# the forbidden zone. After clamping, the candidate is at the zone edge.
	# Push-out should be relative to the clamped candidate, not the raw mouse.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var top_y: float = 434.0
	var bottom_y: float = GameScale.play_area_side_px - 434.0
	# Deploy zone extent for unrotated ship: hl.
	# Maximum Y for Imperial ship center: 434 - hl.
	var max_y: float = top_y - hl
	# Blocker ship near the deploy zone edge.
	var blocker: Array = [ {
		"position": Vector2(500.0, max_y - 50.0), "rotation": 0.0,
		"half_w": hw, "half_l": hl,
	}]
	# Mouse far inside the forbidden zone — gets clamped to max_y.
	var desired: Vector2 = Vector2(500.0, 1500.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			blocker, [], top_y, bottom_y, GameScale.play_area_side_px)
	# Assert — result should be pushed in a consistent direction from blocker,
	# not jump to an arbitrary position.
	var dist_to_blocker_center: float = result.distance_to(Vector2(500.0, max_y - 50.0))
	assert_true(dist_to_blocker_center > 0.0,
			"Ship should be pushed away from blocker")
	# The ship should remain within its deployment zone.
	assert_true(result.y + hl <= top_y + 1.0,
			"Ship should remain within Imperial deployment zone")

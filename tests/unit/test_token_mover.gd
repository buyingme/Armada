## Test: TokenMover
##
## Unit tests for TokenMover — collision resolution, deployment zone enforcement,
## and jump-past logic for debug-mode token placement.
##
## Requirements: DBG-011, DBG-020, DBG-021, DBG-032
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
	# Arrange — blocker at (500, 500), try to move to same position.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var blocker: Array = [{"position": Vector2(500.0, 500.0), "radius": radius}]
	var current: Vector2 = Vector2(300.0, 500.0)
	var desired: Vector2 = Vector2(500.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — should stop before reaching the blocker.
	assert_true(result.x < 500.0 - radius,
			"Squadron should be stopped before the blocker centre")
	assert_true(result.distance_to(current) > 0.0,
			"Squadron should have moved toward blocker")


# ---------------------------------------------------------------------------
# Squadron — jump past another squadron
# ---------------------------------------------------------------------------

func test_resolve_squadron_jump_past_blocker() -> void:
	# Arrange — blocker at (500, 500), cursor at (700, 500) — far side is free.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var blocker: Array = [{"position": Vector2(500.0, 500.0), "radius": radius}]
	var current: Vector2 = Vector2(300.0, 500.0)
	var desired: Vector2 = Vector2(700.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], blocker, -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — should jump to the far side (near desired).
	assert_almost_eq(result.x, desired.x, 1.0,
			"Squadron should jump past the blocker to the far side")


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
	# Arrange — blocker small ship at (500, 500).
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var blocker: Array = [{
		"position": Vector2(500.0, 500.0),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	var current: Vector2 = Vector2(300.0, 500.0)
	var desired: Vector2 = Vector2(500.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			blocker, [], -1.0, -1.0, GameScale.play_area_side_px)
	# Assert — should stop before reaching the blocker.
	assert_true(result.x < 500.0 - hw,
			"Ship should be stopped before the blocker")


# ---------------------------------------------------------------------------
# Deployment zone — Imperial ship blocked from crossing top line
# ---------------------------------------------------------------------------

func test_imperial_ship_blocked_by_deploy_zone() -> void:
	# Arrange — top deploy line at distance band 3 = 434 px.
	var top_y: float = 434.0
	var bottom_y: float = GameScale.play_area_side_px - 434.0
	var desired: Vector2 = Vector2(500.0, 800.0)  # deep into no-go zone
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], top_y, bottom_y, GameScale.play_area_side_px)
	# Assert — Y should be above top_y.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var extent_y: float = base_size.y * 0.5  # rotation=0, so extent = half_length
	assert_true(result.y + extent_y <= top_y + 1.0,
			"Imperial ship should be clamped above the top deployment line")


func test_rebel_ship_blocked_by_deploy_zone() -> void:
	# Arrange — bottom deploy line.
	var top_y: float = 434.0
	var bottom_y: float = GameScale.play_area_side_px - 434.0
	var desired: Vector2 = Vector2(500.0, 400.0)  # deep into no-go zone
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

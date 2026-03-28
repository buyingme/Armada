## Test: Relaxed Deployment Zones (Phase 2c)
##
## Unit tests for debug-mode deployment zone relaxation:
## - TokenMover enforces zones when enforce_deploy_zones=true (default).
## - TokenMover skips zone clamping when enforce_deploy_zones=false.
## - DeploymentZoneOverlay.is_in_deploy_zone() returns correct results.
##
## Requirements: DBG-032 (revised), DBG-033, DBG-034
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

## Top deployment line Y (distance band 3).
var _top_y: float = 434.0
## Bottom deployment line Y.
var _bottom_y: float = 0.0
## Play area side.
var _side: float = 0.0


func before_each() -> void:
	_mover = TokenMover.new()
	GameScale.initialise_from_dict(_scale_config)
	_side = GameScale.play_area_side_px
	_bottom_y = _side - _top_y


func after_each() -> void:
	_mover = null


# ---------------------------------------------------------------------------
# TokenMover — enforce_deploy_zones=true (default, existing behaviour)
# ---------------------------------------------------------------------------

func test_ship_clamped_with_enforce_true_default() -> void:
	# Arrange — Imperial ship tries to cross below top deploy line.
	var desired: Vector2 = Vector2(500.0, 800.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act — default parameter (enforce_deploy_zones=true).
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], _top_y, _bottom_y, _side)
	# Assert — should be clamped above the top line.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var extent_y: float = base_size.y * 0.5
	assert_true(result.y + extent_y <= _top_y + 1.0,
			"Imperial ship should be clamped above deploy line with default flag")


func test_squadron_clamped_with_enforce_true_explicit() -> void:
	# Arrange — Imperial squadron tries to cross deploy line.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var desired: Vector2 = Vector2(500.0, 800.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act — explicitly pass true.
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], _top_y, _bottom_y, _side, true)
	# Assert — clamped above top line.
	assert_true(result.y + radius <= _top_y + 1.0,
			"Imperial squadron should be clamped with enforce=true")


# ---------------------------------------------------------------------------
# TokenMover — enforce_deploy_zones=false (debug mode)
# ---------------------------------------------------------------------------

func test_ship_crosses_deploy_zone_with_enforce_false() -> void:
	# Arrange — Imperial ship wants to go deep into the Rebel zone.
	var desired: Vector2 = Vector2(500.0, 1800.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], _top_y, _bottom_y, _side, false)
	# Assert — should reach the desired position (no zone clamping).
	assert_almost_eq(result.y, desired.y, 1.0,
			"Imperial ship should cross deploy zone with enforce=false")


func test_squadron_crosses_deploy_zone_with_enforce_false() -> void:
	# Arrange — Imperial squadron wants to go past deploy line.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var desired: Vector2 = Vector2(500.0, 800.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], _top_y, _bottom_y, _side, false)
	# Assert — should reach the desired position.
	assert_almost_eq(result.y, desired.y, 1.0,
			"Imperial squadron should cross deploy zone with enforce=false")


func test_rebel_ship_crosses_deploy_zone_with_enforce_false() -> void:
	# Arrange — Rebel ship wants to go into Imperial zone.
	var desired: Vector2 = Vector2(500.0, 200.0)
	var current: Vector2 = Vector2(500.0, 1800.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], _top_y, _bottom_y, _side, false)
	# Assert — should reach the desired position.
	assert_almost_eq(result.y, desired.y, 1.0,
			"Rebel ship should cross deploy zone with enforce=false")


func test_rebel_squadron_crosses_deploy_zone_with_enforce_false() -> void:
	# Arrange — Rebel squadron wants to go into Imperial zone.
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var desired: Vector2 = Vector2(500.0, 200.0)
	var current: Vector2 = Vector2(500.0, 1800.0)
	# Act
	var result: Vector2 = _mover.resolve_squadron_position(
			desired, current, radius,
			Constants.Faction.REBEL_ALLIANCE,
			[], [], _top_y, _bottom_y, _side, false)
	# Assert — should reach the desired position.
	assert_almost_eq(result.y, desired.y, 1.0,
			"Rebel squadron should cross deploy zone with enforce=false")


# ---------------------------------------------------------------------------
# Play area clamping still enforced when deploy zones are relaxed
# ---------------------------------------------------------------------------

func test_play_area_clamping_still_enforced_with_no_zones() -> void:
	# Arrange — ship tries to go beyond the play area.
	var desired: Vector2 = Vector2(-100.0, 3000.0)
	var current: Vector2 = Vector2(500.0, 500.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			[], [], _top_y, _bottom_y, _side, false)
	# Assert — still clamped to play area.
	assert_true(result.x >= 0.0,
			"X should be clamped to play area even with deploy zones off")
	assert_true(result.y <= _side,
			"Y should be clamped to play area even with deploy zones off")


# ---------------------------------------------------------------------------
# Token-token collision still enforced when deploy zones are relaxed
# ---------------------------------------------------------------------------

func test_token_collision_still_enforced_with_no_zones() -> void:
	# Arrange — two ships, try to place one on top of the other, outside zone.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	var blocker: Array = [ {
		"position": Vector2(500.0, 800.0),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	var desired: Vector2 = Vector2(500.0, 800.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act — deploy zones off, but collision still on.
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			blocker, [], _top_y, _bottom_y, _side, false)
	# Assert — pushed away from blocker, NOT at blocker position.
	var dist: float = result.distance_to(Vector2(500.0, 800.0))
	assert_true(dist > hw,
			"Ship should still be pushed from blocker even with deploy zones off")


# ---------------------------------------------------------------------------
# Push-out candidates skip zone clamping when enforce=false
# ---------------------------------------------------------------------------

func test_pushout_not_clamped_to_zone_with_enforce_false() -> void:
	# Arrange — Imperial ship near deploy line, blocker inside zone, push goes
	# across the line. With enforce=false, push-out should cross.
	var base_size: Vector2 = GameScale.get_base_size(Constants.ShipSize.SMALL)
	var hw: float = base_size.x * 0.5
	var hl: float = base_size.y * 0.5
	# Blocker just inside the zone near the deploy line.
	var blocker_y: float = _top_y - hl - 10.0
	var blocker: Array = [ {
		"position": Vector2(500.0, blocker_y),
		"rotation": 0.0,
		"half_w": hw,
		"half_l": hl,
	}]
	# Desired is just below the blocker (across the deploy line).
	var desired: Vector2 = Vector2(500.0, blocker_y + hl + 5.0)
	var current: Vector2 = Vector2(500.0, 200.0)
	# Act
	var result: Vector2 = _mover.resolve_ship_position(
			desired, current,
			Constants.ShipSize.SMALL, 0.0,
			Constants.Faction.GALACTIC_EMPIRE,
			blocker, [], _top_y, _bottom_y, _side, false)
	# Assert — result should be below the deploy line (push-out crossed it).
	assert_true(result.y > _top_y - hl,
			"Push-out should cross deploy line when enforce=false")


# ---------------------------------------------------------------------------
# DeploymentZoneOverlay.is_in_deploy_zone()
# ---------------------------------------------------------------------------

func test_imperial_in_zone_above_top_line() -> void:
	# Y above top line → in zone.
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			200.0, Constants.Faction.GALACTIC_EMPIRE)
	assert_true(result, "Imperial at Y=200 should be in zone (top_y=434)")


func test_imperial_at_top_line_in_zone() -> void:
	# Y exactly at top line → in zone (edge case).
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			_top_y, Constants.Faction.GALACTIC_EMPIRE)
	assert_true(result, "Imperial at Y=top_y should be in zone (boundary)")


func test_imperial_below_top_line_outside_zone() -> void:
	# Y below top line → outside zone.
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			_top_y + 100.0, Constants.Faction.GALACTIC_EMPIRE)
	assert_false(result, "Imperial at Y=top_y+100 should be outside zone")


func test_rebel_in_zone_below_bottom_line() -> void:
	# Y below bottom line → in zone.
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			_bottom_y + 100.0, Constants.Faction.REBEL_ALLIANCE)
	assert_true(result, "Rebel at Y=bottom_y+100 should be in zone")


func test_rebel_at_bottom_line_in_zone() -> void:
	# Y exactly at bottom line → in zone (edge case).
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			_bottom_y, Constants.Faction.REBEL_ALLIANCE)
	assert_true(result, "Rebel at Y=bottom_y should be in zone (boundary)")


func test_rebel_above_bottom_line_outside_zone() -> void:
	# Y above bottom line → outside zone.
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			_bottom_y - 100.0, Constants.Faction.REBEL_ALLIANCE)
	assert_false(result, "Rebel at Y=bottom_y-100 should be outside zone")


func test_is_in_zone_returns_true_when_zones_not_loaded() -> void:
	# When distance bands are not loaded, is_in_deploy_zone returns true.
	# Save and restore GameScale state.
	var saved_bands: Array = GameScale.distance_bands_px.duplicate()
	GameScale.distance_bands_px = []
	var result: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			9999.0, Constants.Faction.GALACTIC_EMPIRE)
	GameScale.distance_bands_px = saved_bands
	assert_true(result, "Should return true when zones are not loaded")

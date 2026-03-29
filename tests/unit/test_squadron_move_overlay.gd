## Test: SquadronMoveOverlay
##
## Unit tests for the visual overlay drawn during squadron activation.
## Verifies setup, radius calculations, circle visibility toggles,
## and faction colour selection.
##
## Rules Reference: "Squadron Movement" p.19; "Engagement" p.4.
## Requirements: SQM-001, SQM-002.
extends GutTest


var _overlay: SquadronMoveOverlay = null


func before_each() -> void:
	_overlay = SquadronMoveOverlay.new()
	add_child_autofree(_overlay)


# ===========================================================================
# setup — basic configuration
# ===========================================================================

func test_setup_sets_position() -> void:
	var pos: Vector2 = Vector2(400, 300)
	_overlay.setup(pos, 3, true, Constants.Faction.REBEL_ALLIANCE)
	assert_eq(_overlay.position, pos,
			"Overlay position should match the given centre position")


func test_setup_can_move_true_has_positive_radius() -> void:
	_overlay.setup(Vector2.ZERO, 3, true, Constants.Faction.REBEL_ALLIANCE)
	assert_gt(_overlay.get_move_radius_px(), 0.0,
			"Move radius should be positive when can_move is true")


func test_setup_can_move_false_has_zero_radius() -> void:
	_overlay.setup(Vector2.ZERO, 3, false, Constants.Faction.REBEL_ALLIANCE)
	assert_eq(_overlay.get_move_radius_px(), 0.0,
			"Move radius should be 0 when can_move is false")


# ===========================================================================
# Faction colours
# ===========================================================================

func test_rebel_uses_red_armament_colour() -> void:
	_overlay.setup(Vector2.ZERO, 3, true, Constants.Faction.REBEL_ALLIANCE)
	assert_eq(_overlay._armament_colour,
			SquadronMoveOverlay.ARMAMENT_COLOUR_REBEL,
			"Rebel should use red armament colour")


func test_imperial_uses_green_armament_colour() -> void:
	_overlay.setup(Vector2.ZERO, 3, true,
			Constants.Faction.GALACTIC_EMPIRE)
	assert_eq(_overlay._armament_colour,
			SquadronMoveOverlay.ARMAMENT_COLOUR_IMPERIAL,
			"Imperial should use green armament colour")


# ===========================================================================
# Speed vs radius — higher speed = larger circle
# ===========================================================================

func test_speed_4_larger_than_speed_2() -> void:
	var overlay_slow: SquadronMoveOverlay = SquadronMoveOverlay.new()
	add_child_autofree(overlay_slow)
	overlay_slow.setup(Vector2.ZERO, 2, true,
			Constants.Faction.REBEL_ALLIANCE)
	var overlay_fast: SquadronMoveOverlay = SquadronMoveOverlay.new()
	add_child_autofree(overlay_fast)
	overlay_fast.setup(Vector2.ZERO, 4, true,
			Constants.Faction.REBEL_ALLIANCE)
	assert_gt(overlay_fast.get_move_radius_px(),
			overlay_slow.get_move_radius_px(),
			"Speed 4 radius should be larger than speed 2")


# ===========================================================================
# Static helpers
# ===========================================================================

func test_get_distance_1_px_positive() -> void:
	var d1: float = SquadronMoveOverlay._get_distance_1_px()
	assert_gt(d1, 0.0,
			"Distance 1 px should be a positive value")


func test_get_max_move_distance_speed_1_positive() -> void:
	var d: float = SquadronMoveOverlay._get_max_move_distance(1)
	assert_gt(d, 0.0,
			"Move distance for speed 1 should be positive")


func test_get_max_move_distance_higher_speed_larger() -> void:
	var d1: float = SquadronMoveOverlay._get_max_move_distance(1)
	var d3: float = SquadronMoveOverlay._get_max_move_distance(3)
	assert_gt(d3, d1,
			"Speed 3 move distance should exceed speed 1")


# ===========================================================================
# base_radius — overlay circles enlarged by squadron base radius
# ===========================================================================

func test_base_radius_increases_move_radius() -> void:
	var base_r: float = GameScale.squadron_base_diameter_px * 0.5
	var overlay_no_r: SquadronMoveOverlay = SquadronMoveOverlay.new()
	add_child_autofree(overlay_no_r)
	overlay_no_r.setup(Vector2.ZERO, 3, true,
			Constants.Faction.REBEL_ALLIANCE, 0.0)
	var overlay_with_r: SquadronMoveOverlay = SquadronMoveOverlay.new()
	add_child_autofree(overlay_with_r)
	overlay_with_r.setup(Vector2.ZERO, 3, true,
			Constants.Faction.REBEL_ALLIANCE, base_r)
	assert_almost_eq(
			overlay_with_r.get_move_radius_px(),
			overlay_no_r.get_move_radius_px() + base_r, 0.01,
			"Move radius should increase by base_radius")


func test_base_radius_increases_armament_radius() -> void:
	var base_r: float = GameScale.squadron_base_diameter_px * 0.5
	var overlay_no_r: SquadronMoveOverlay = SquadronMoveOverlay.new()
	add_child_autofree(overlay_no_r)
	overlay_no_r.setup(Vector2.ZERO, 3, true,
			Constants.Faction.REBEL_ALLIANCE, 0.0)
	var overlay_with_r: SquadronMoveOverlay = SquadronMoveOverlay.new()
	add_child_autofree(overlay_with_r)
	overlay_with_r.setup(Vector2.ZERO, 3, true,
			Constants.Faction.REBEL_ALLIANCE, base_r)
	assert_almost_eq(
			overlay_with_r._armament_radius_px,
			overlay_no_r._armament_radius_px + base_r, 0.01,
			"Armament radius should increase by base_radius")


func test_base_radius_zero_when_cannot_move() -> void:
	var base_r: float = GameScale.squadron_base_diameter_px * 0.5
	_overlay.setup(Vector2.ZERO, 3, false,
			Constants.Faction.REBEL_ALLIANCE, base_r)
	assert_eq(_overlay.get_move_radius_px(), 0.0,
			"Move radius should remain 0 when can_move is false")


# ===========================================================================
# update_tracking_position — armament ring follows token during drag
# ===========================================================================

func test_initial_armament_offset_is_zero() -> void:
	_overlay.setup(Vector2(100, 200), 3, true,
			Constants.Faction.REBEL_ALLIANCE)
	assert_eq(_overlay._armament_offset, Vector2.ZERO,
			"Armament offset should start at Vector2.ZERO")


func test_update_tracking_position_sets_offset() -> void:
	var origin: Vector2 = Vector2(100, 200)
	_overlay.setup(origin, 3, true, Constants.Faction.REBEL_ALLIANCE)
	_overlay.update_tracking_position(Vector2(150, 250))
	assert_eq(_overlay._armament_offset, Vector2(50, 50),
			"Armament offset should equal new_pos minus overlay position")


func test_update_tracking_position_same_pos_no_change() -> void:
	var origin: Vector2 = Vector2(100, 200)
	_overlay.setup(origin, 3, true, Constants.Faction.REBEL_ALLIANCE)
	_overlay.update_tracking_position(origin)
	assert_eq(_overlay._armament_offset, Vector2.ZERO,
			"Offset should remain zero when tracking position equals origin")


func test_reset_tracking_clears_offset() -> void:
	var origin: Vector2 = Vector2(100, 200)
	_overlay.setup(origin, 3, true, Constants.Faction.REBEL_ALLIANCE)
	_overlay.update_tracking_position(Vector2(300, 400))
	assert_ne(_overlay._armament_offset, Vector2.ZERO,
			"Offset should be non-zero after update")
	_overlay.reset_tracking()
	assert_eq(_overlay._armament_offset, Vector2.ZERO,
			"Offset should be reset to Vector2.ZERO after reset_tracking")


func test_successive_tracking_updates_replace_offset() -> void:
	var origin: Vector2 = Vector2(100, 200)
	_overlay.setup(origin, 3, true, Constants.Faction.REBEL_ALLIANCE)
	_overlay.update_tracking_position(Vector2(200, 300))
	assert_eq(_overlay._armament_offset, Vector2(100, 100),
			"First update offset should be (100, 100)")
	_overlay.update_tracking_position(Vector2(120, 210))
	assert_eq(_overlay._armament_offset, Vector2(20, 10),
			"Second update should replace offset with (20, 10)")

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

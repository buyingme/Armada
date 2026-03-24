## Unit tests for AttackSimOverlay
##
## Covers: AS-VIS-002, AS-VIS-003, AS-VIS-010.
extends GutTest


var _overlay: AttackSimOverlay = null


func before_each() -> void:
	_overlay = AttackSimOverlay.new()
	add_child_autofree(_overlay)


func test_initial_state_no_draw() -> void:
	assert_false(_overlay._draw_hull_zone,
			"Hull zone draw flag should be false initially.")
	assert_false(_overlay._draw_squadron,
			"Squadron draw flag should be false initially.")


func test_setup_hull_zone_sets_draw_flag() -> void:
	var inner_l: Vector2 = Vector2(100, 200)
	var outer_l: Vector2 = Vector2(50, 100)
	var inner_r: Vector2 = Vector2(100, 200)
	var outer_r: Vector2 = Vector2(150, 100)
	var los: Vector2 = Vector2(100, 150)
	_overlay.setup_hull_zone(inner_l, outer_l, inner_r, outer_r, los)
	assert_true(_overlay._draw_hull_zone,
			"Hull zone draw flag should be true after setup_hull_zone().")
	assert_false(_overlay._draw_squadron,
			"Squadron draw flag should remain false after setup_hull_zone().")


func test_setup_hull_zone_stores_los_position() -> void:
	var los: Vector2 = Vector2(123, 456)
	_overlay.setup_hull_zone(Vector2.ZERO, Vector2.ZERO,
			Vector2.ZERO, Vector2.ZERO, los)
	assert_eq(_overlay._los_position, los,
			"LOS position should be stored.")


func test_setup_squadron_sets_draw_flag() -> void:
	_overlay.setup_squadron(Vector2(500, 500), 20.0)
	assert_true(_overlay._draw_squadron,
			"Squadron draw flag should be true after setup_squadron().")
	assert_false(_overlay._draw_hull_zone,
			"Hull zone draw flag should be false after setup_squadron().")


func test_setup_squadron_stores_centre_and_radius() -> void:
	var centre: Vector2 = Vector2(300, 400)
	var base_radius: float = 25.0
	_overlay.setup_squadron(centre, base_radius)
	assert_eq(_overlay._squad_centre, centre,
			"Squadron centre should be stored.")
	var expected_radius: float = base_radius + GameScale.range_close_px
	assert_almost_eq(_overlay._squad_circle_radius, expected_radius, 0.1,
			"Squadron circle radius should be base_radius + close range.")


func test_clear_resets_draw_flags() -> void:
	_overlay.setup_hull_zone(Vector2.ZERO, Vector2.ZERO,
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_overlay.clear()
	assert_false(_overlay._draw_hull_zone,
			"Hull zone draw flag should be false after clear().")
	assert_false(_overlay._draw_squadron,
			"Squadron draw flag should be false after clear().")


func test_extend_to_boundary_right_edge() -> void:
	# Ray going right from (100, 500) through (200, 500) should hit x=2160.
	_overlay._play_area_side = 2160.0
	var result: Vector2 = _overlay._extend_to_boundary(
			Vector2(100, 500), Vector2(200, 500))
	assert_almost_eq(result.x, 2160.0, 0.1,
			"Ray should hit right edge of play area.")
	assert_almost_eq(result.y, 500.0, 0.1,
			"Y should remain unchanged for horizontal ray.")


func test_extend_to_boundary_top_edge() -> void:
	# Ray going up from (500, 500) through (500, 400) should hit y=0.
	_overlay._play_area_side = 2160.0
	var result: Vector2 = _overlay._extend_to_boundary(
			Vector2(500, 500), Vector2(500, 400))
	assert_almost_eq(result.y, 0.0, 0.1,
			"Ray should hit top edge of play area.")
	assert_almost_eq(result.x, 500.0, 0.1,
			"X should remain unchanged for vertical ray.")


func test_extend_to_boundary_diagonal() -> void:
	# Ray going up-right from (1080, 1080) through (1180, 980).
	# Direction = (100, -100) normalized. Should hit top or right edge.
	_overlay._play_area_side = 2160.0
	var result: Vector2 = _overlay._extend_to_boundary(
			Vector2(1080, 1080), Vector2(1180, 980))
	# It should hit y=0 at x=2160 or whichever comes first.
	# t for x=2160: (2160-1080)/100 = 10.8 → y = 1080 + (-100)*10.8 = 0.
	# t for y=0: (0-1080)/(-100) = 10.8 → x = 1080 + 100*10.8 = 2160.
	# Both hit at the same time (corner case).
	assert_almost_eq(result.x, 2160.0, 1.0,
			"Diagonal ray should reach x = 2160.")
	assert_almost_eq(result.y, 0.0, 1.0,
			"Diagonal ray should reach y = 0.")

## Tests for OverlapResolver
##
## Covers: ship–ship overlap detection, speed reduction loop, stay-in-place,
##   squadron overlap detection, squadron placement validation.
##
## Rules Reference: RRG "Overlapping", p.8; OV-001–004, OV-010–013.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a ShipBase at the given position with no rotation.
func _make_ship_base(pos: Vector2,
		size: Constants.ShipSize = Constants.ShipSize.SMALL) -> ShipBase:
	return ShipBase.new(size, Transform2D(0.0, pos))


## Creates a ManeuverToolState set up for a small ship at the given speed.
## Nav chart: all clicks = 0 (straight ahead, no yaw).
func _make_tool_state(speed: int,
		max_speed: int = -1) -> ManeuverToolState:
	var state: ManeuverToolState = ManeuverToolState.new()
	# Simple nav chart: speed levels 1–4, each joint allows 0 clicks.
	var nav: Array = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
	var ms: int = max_speed if max_speed >= 0 else speed
	state.setup(speed, nav, Constants.ShipSize.SMALL, ms)
	return state


# ---------------------------------------------------------------------------
# check_ship_ship_overlap — no overlap
# ---------------------------------------------------------------------------

func test_check_no_overlap_returns_no_overlap() -> void:
	# Arrange: two ships far apart.
	var resolver: OverlapResolver = OverlapResolver.new()
	var tool_state: ManeuverToolState = _make_tool_state(2)
	var original_xform: Transform2D = Transform2D(0.0, Vector2(0.0, 0.0))
	# The moving ship will compute its final transform via the tool state.
	# Place the other ship 2000px away — no overlap possible.
	var other: ShipBase = _make_ship_base(Vector2(2000.0, 0.0))
	# Act.
	var result: OverlapResolver.ShipShipResult = (
			resolver.check_ship_ship_overlap(
					tool_state,
					Vector2(0.0, 0.0), 0.0, "left",
					Constants.ShipSize.SMALL, [other], original_xform))
	# Assert.
	assert_false(result.overlaps,
			"No overlap should be reported when ships are far apart.")
	assert_false(result.stayed_in_place,
			"Ship should not stay in place when there is no overlap.")
	assert_eq(result.final_speed, 2,
			"Final speed should remain at the original speed.")


# ---------------------------------------------------------------------------
# check_ship_ship_overlap — overlap resolved at lower speed
# ---------------------------------------------------------------------------

func test_check_overlap_resolves_at_reduced_speed() -> void:
	# Arrange: place the other ship directly in front of the
	# moving ship at roughly the distance the tool would reach at
	# speed 2 but NOT at speed 1.
	var resolver: OverlapResolver = OverlapResolver.new()
	var tool_state: ManeuverToolState = _make_tool_state(2, 2)
	var original_xform: Transform2D = Transform2D(0.0, Vector2(0.0, 0.0))
	# Compute where the ship ends up at speed 2 to place blocker there.
	tool_state.set_simulated_speed(2)
	var xform_s2: Transform2D = tool_state.compute_final_transform(
			Vector2(0.0, 0.0), 0.0, "left")
	# Place blocker at the speed-2 final position.
	var other: ShipBase = _make_ship_base(xform_s2.origin)
	# Restore speed for the resolver.
	tool_state.set_simulated_speed(2)
	# Act.
	var result: OverlapResolver.ShipShipResult = (
			resolver.check_ship_ship_overlap(
					tool_state,
					Vector2(0.0, 0.0), 0.0, "left",
					Constants.ShipSize.SMALL, [other], original_xform))
	# Assert: overlap detected, resolved at lower speed.
	assert_true(result.overlaps or result.final_speed < 2,
			"Should have detected overlap and reduced speed.")
	assert_lt(result.final_speed, 2,
			"Final speed should be less than original 2.")
	assert_eq(result.original_speed, 2,
			"Original speed should be recorded as 2.")


# ---------------------------------------------------------------------------
# check_ship_ship_overlap — speed 0 stay in place
# ---------------------------------------------------------------------------

func test_check_overlap_stays_in_place_when_blocked_at_all_speeds() -> void:
	# Arrange: place the other ship at the original position — overlapping.
	var resolver: OverlapResolver = OverlapResolver.new()
	var tool_state: ManeuverToolState = _make_tool_state(1, 1)
	var original_xform: Transform2D = Transform2D(0.0, Vector2(0.0, 0.0))
	# Place the blocker right at the origin (overlapping at speed 0 too).
	var other: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	# Act.
	var result: OverlapResolver.ShipShipResult = (
			resolver.check_ship_ship_overlap(
					tool_state,
					Vector2(0.0, 0.0), 0.0, "left",
					Constants.ShipSize.SMALL, [other], original_xform))
	# Assert.
	assert_true(result.overlaps or result.stayed_in_place,
			"Overlap should be reported or ship should stay in place.")
	assert_true(result.stayed_in_place,
			"Ship should stay in place when blocked at all speeds.")
	assert_eq(result.final_speed, 0,
			"Final speed should be 0 when staying in place.")
	assert_eq(result.final_transform, original_xform,
			"Ship should be at its original transform when staying in place.")


# ---------------------------------------------------------------------------
# check_ship_ship_overlap — simulated speed is restored
# ---------------------------------------------------------------------------

func test_check_overlap_restores_simulated_speed() -> void:
	# Arrange.
	var resolver: OverlapResolver = OverlapResolver.new()
	var tool_state: ManeuverToolState = _make_tool_state(2, 2)
	var original_xform: Transform2D = Transform2D(0.0, Vector2(0.0, 0.0))
	var other: ShipBase = _make_ship_base(Vector2(2000.0, 0.0))
	# Act.
	resolver.check_ship_ship_overlap(
			tool_state,
			Vector2(0.0, 0.0), 0.0, "left",
			Constants.ShipSize.SMALL, [other], original_xform)
	# Assert: simulated speed should be restored to original.
	assert_eq(tool_state.get_simulated_speed(), 2,
			"Simulated speed should be restored after overlap check.")


# ---------------------------------------------------------------------------
# find_overlapped_squadrons
# ---------------------------------------------------------------------------

func test_find_overlapped_squadrons_detects_overlap() -> void:
	# Arrange: ship at origin, squadron at origin (inside the ship base).
	var resolver: OverlapResolver = OverlapResolver.new()
	var ship_base: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	var squad_data: Array = [
		{"position": Vector2(0.0, 0.0), "radius": 10.0, "index": 0},
	]
	# Act.
	var overlapped: Array[int] = resolver.find_overlapped_squadrons(
			ship_base, squad_data)
	# Assert.
	assert_true(overlapped.has(0),
			"Squadron at ship centre should be detected as overlapping.")


func test_find_overlapped_squadrons_ignores_distant() -> void:
	# Arrange: squadron far from the ship.
	var resolver: OverlapResolver = OverlapResolver.new()
	var ship_base: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	var squad_data: Array = [
		{"position": Vector2(5000.0, 5000.0), "radius": 10.0, "index": 0},
	]
	# Act.
	var overlapped: Array[int] = resolver.find_overlapped_squadrons(
			ship_base, squad_data)
	# Assert.
	assert_eq(overlapped.size(), 0,
			"Distant squadron should not be detected as overlapping.")


# ---------------------------------------------------------------------------
# validate_squadron_placement
# ---------------------------------------------------------------------------

func test_validate_placement_valid_touching_ship() -> void:
	# Arrange: ship at origin, place squadron just outside the ship edge.
	var resolver: OverlapResolver = OverlapResolver.new()
	var ship_base: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	# Place squadron just beyond the ship's half-width + a small gap.
	var hw: float = ship_base.half_width_px
	var squad_pos: Vector2 = Vector2(hw + 12.0, 0.0)
	var squad_radius: float = 10.0
	# Act.
	var error: String = resolver.validate_squadron_placement(
			squad_pos, squad_radius, ship_base, [], [])
	# Assert: should be valid (edge of circle is ~2px from ship edge,
	# within default tolerance of 5px).
	assert_eq(error, "",
			"Placement adjacent to ship should be valid: %s" % error)


func test_validate_placement_too_far_from_ship() -> void:
	# Arrange: ship at origin, squadron way too far.
	var resolver: OverlapResolver = OverlapResolver.new()
	var ship_base: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	var squad_pos: Vector2 = Vector2(5000.0, 5000.0)
	var squad_radius: float = 10.0
	# Act.
	var error: String = resolver.validate_squadron_placement(
			squad_pos, squad_radius, ship_base, [], [])
	# Assert.
	assert_ne(error, "",
			"Placement far from ship should fail with an error message.")
	assert_string_contains(error, "touching",
			"Error should mention 'touching'.")


func test_validate_placement_overlapping_ship_rejected() -> void:
	# Arrange: ship at origin, squadron inside the ship.
	var resolver: OverlapResolver = OverlapResolver.new()
	var ship_base: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	var squad_pos: Vector2 = Vector2(0.0, 0.0)
	var squad_radius: float = 10.0
	# Act.
	var error: String = resolver.validate_squadron_placement(
			squad_pos, squad_radius, ship_base, [], [])
	# Assert.
	assert_ne(error, "",
			"Placement overlapping the ship should be rejected.")


func test_validate_placement_overlapping_other_squadron_rejected() -> void:
	# Arrange: ship at origin, another squadron next to it.
	var resolver: OverlapResolver = OverlapResolver.new()
	var ship_base: ShipBase = _make_ship_base(Vector2(0.0, 0.0))
	var hw: float = ship_base.half_width_px
	var existing_squad: SquadronBase = SquadronBase.new(
			Vector2(hw + 12.0, 0.0), 10.0)
	# Try to place at the same spot as the existing squadron.
	var squad_pos: Vector2 = Vector2(hw + 12.0, 0.0)
	var squad_radius: float = 10.0
	# Act.
	var error: String = resolver.validate_squadron_placement(
			squad_pos, squad_radius, ship_base, [], [existing_squad])
	# Assert.
	assert_ne(error, "",
			"Placement overlapping another squadron should be rejected.")
	assert_string_contains(error, "squadron",
			"Error should mention 'squadron'.")

## Test: SquadronMover
##
## Unit tests for squadron movement validation.
## Rules Reference: "Squadron Movement", RRG p.12; SM-001–005.
extends GutTest


## Creates a SquadronInstance with the given speed.
func _make_squadron(speed: int = 3,
		player: int = 0) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "TestSquad"
	data.hull = 3
	data.speed = speed
	data.defense_tokens = []
	return SquadronInstance.create_from_data("sq", data, player)


# ===========================================================================
# validate_move — distance checks
# ===========================================================================

func test_staying_in_place_is_valid() -> void:
	var sq: SquadronInstance = _make_squadron(3)
	var result: String = SquadronMover.validate_move(
			sq, Vector2.ZERO, Vector2.ZERO, [], [])
	assert_eq(result, "",
			"Staying in place should always be valid (SM-005)")


func test_move_within_speed_band_valid() -> void:
	var sq: SquadronInstance = _make_squadron(3)
	# Move a short distance — well within any speed band.
	var result: String = SquadronMover.validate_move(
			sq, Vector2.ZERO, Vector2(10, 0), [], [])
	assert_eq(result, "",
			"Move within speed band should be valid")


func test_move_far_accepted_distance_enforced_by_clamp() -> void:
	var sq: SquadronInstance = _make_squadron(1)
	# Distance enforcement is the responsibility of the real-time clamp
	# in GameBoard._move_squadron_during_activation, not validate_move.
	var far_pos: Vector2 = Vector2(99999, 0)
	var result: String = SquadronMover.validate_move(
			sq, Vector2.ZERO, far_pos, [], [])
	assert_eq(result, "",
			"validate_move should accept any distance (clamp is authoritative)")


# ===========================================================================
# validate_move — overlap checks
# ===========================================================================

func test_move_overlapping_squadron_returns_error() -> void:
	var sq: SquadronInstance = _make_squadron(3)
	var other: SquadronInstance = _make_squadron(3, 1)
	var target: Vector2 = Vector2(100, 0)
	# Other squadron sits right at the target position.
	var squad_positions: Array[Dictionary] = [
		{"instance": sq, "position": Vector2.ZERO},
		{"instance": other, "position": target},
	]
	var result: String = SquadronMover.validate_move(
			sq, Vector2.ZERO, target, squad_positions, [])
	assert_ne(result, "",
			"Overlapping another squadron should be invalid (SM-003)")
	assert_true(result.contains("Overlaps"),
			"Error should mention 'Overlaps'")


func test_move_overlapping_self_position_is_ok() -> void:
	var sq: SquadronInstance = _make_squadron(3)
	# Only self in the list — should not overlap with itself.
	var squad_positions: Array[Dictionary] = [
		{"instance": sq, "position": Vector2.ZERO},
	]
	var result: String = SquadronMover.validate_move(
			sq, Vector2.ZERO, Vector2(50, 0), squad_positions, [])
	assert_eq(result, "",
			"Moving should not conflict with own entry in position list")


func test_move_ignores_destroyed_squadrons() -> void:
	var sq: SquadronInstance = _make_squadron(3)
	var dead: SquadronInstance = _make_squadron(3, 1)
	dead.suffer_damage(dead.current_hull)
	var target: Vector2 = Vector2(100, 0)
	var squad_positions: Array[Dictionary] = [
		{"instance": sq, "position": Vector2.ZERO},
		{"instance": dead, "position": target},
	]
	var result: String = SquadronMover.validate_move(
			sq, Vector2.ZERO, target, squad_positions, [])
	assert_eq(result, "",
			"Destroyed squadrons should not cause overlap")

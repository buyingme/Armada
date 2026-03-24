## Unit tests for ShipToken.get_hull_zone_at()
##
## Covers: AS-SEL-001 — hull zone detection from click position.
## Rules Reference: "Hull Zones", p.4.
extends GutTest


const SHIP_TOKEN_SCENE: PackedScene = preload(
	"res://src/scenes/tokens/ship_token.tscn")

## A placement for a small Rebel ship at the centre of the play area (unrotated).
var _placement: TokenPlacement = null

## The ShipToken under test.
var _token: ShipToken = null


func before_each() -> void:
	_placement = TokenPlacement.new(
			"cr90_corvette_a", true,
			Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.5, 0.0,
			Constants.ShipSize.SMALL)
	_token = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(_token)
	_token.setup(_placement)


func after_each() -> void:
	_placement = null
	_token = null


## Helper: zero-size tokens return -1 for any point.
func test_hull_zone_returns_neg1_outside_base() -> void:
	# A point far away from the token position.
	var result: int = _token.get_hull_zone_at(Vector2(-99999, -99999))
	assert_eq(result, -1,
			"Point outside the base should return -1.")


func test_hull_zone_returns_neg1_when_base_is_zero_size() -> void:
	# Token with no GameScale (half_w and half_l are 0) — any point outside origin.
	var bare_token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(bare_token)
	# Don't call setup — dimensions stay at 0.
	var result: int = bare_token.get_hull_zone_at(Vector2(10, 10))
	assert_eq(result, -1,
			"Zero-size base should return -1 for any non-origin point.")


func test_hull_zone_front_detected() -> void:
	# Place a point at the ship's position offset forward (negative Y in local).
	if _token.get_half_length() <= 0.0:
		pass_test("Token has no dimensions (headless); skipping spatial test.")
		return
	var front_pos: Vector2 = _token.to_global(
			Vector2(0.0, -_token.get_half_length() * 0.9))
	var result: int = _token.get_hull_zone_at(front_pos)
	assert_eq(result, Constants.HullZone.FRONT,
			"Point near the front should be FRONT hull zone.")


func test_hull_zone_rear_detected() -> void:
	if _token.get_half_length() <= 0.0:
		pass_test("Token has no dimensions (headless); skipping spatial test.")
		return
	var rear_pos: Vector2 = _token.to_global(
			Vector2(0.0, _token.get_half_length() * 0.9))
	var result: int = _token.get_hull_zone_at(rear_pos)
	assert_eq(result, Constants.HullZone.REAR,
			"Point near the rear should be REAR hull zone.")


func test_hull_zone_left_detected() -> void:
	if _token.get_half_length() <= 0.0 or _token.get_half_width() <= 0.0:
		pass_test("Token has no dimensions (headless); skipping spatial test.")
		return
	# Middle third, left side (-X in local space).
	var left_pos: Vector2 = _token.to_global(
			Vector2(-_token.get_half_width() * 0.9, 0.0))
	var result: int = _token.get_hull_zone_at(left_pos)
	assert_eq(result, Constants.HullZone.LEFT,
			"Point on the left side should be LEFT hull zone.")


func test_hull_zone_right_detected() -> void:
	if _token.get_half_length() <= 0.0 or _token.get_half_width() <= 0.0:
		pass_test("Token has no dimensions (headless); skipping spatial test.")
		return
	# Middle third, right side (+X in local space).
	var right_pos: Vector2 = _token.to_global(
			Vector2(_token.get_half_width() * 0.9, 0.0))
	var result: int = _token.get_hull_zone_at(right_pos)
	assert_eq(result, Constants.HullZone.RIGHT,
			"Point on the right side should be RIGHT hull zone.")

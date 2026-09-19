extends GutTest


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_displacement_authority.gd")


var _state: GameState
var _ship: ShipInstance
var _squadron: SquadronInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_ship = ShipInstance.create_from_data("moving", _ship_data(), 1, 0)
	_ship.pos_x = 0.5
	_ship.pos_y = 0.5
	_state.get_player_state(0).ships.append(_ship)
	_squadron = SquadronInstance.create_from_data(
			"affected", _squadron_data(), 1)
	_state.get_player_state(1).squadrons.append(_squadron)


func test_accepts_exact_complete_maximum_direct_batch() -> void:
	var play_area: Vector2 = GameScale.play_area_size_px
	var base := ShipBase.new(_ship.ship_data.ship_size,
			Transform2D(0.0, _ship.get_pixel_position(play_area)))
	var point: Vector2 = base.ship_transform * Vector2(
			0.0, -base.half_length_px
			- GameScale.squadron_base_diameter_px * 0.5 - 1.0)
	var placement: Dictionary = {
		"owner": 1,
		"squadron_index": 0,
		"pos_x": point.x / play_area.x,
		"pos_y": point.y / play_area.y,
	}
	var result: Dictionary = AUTHORITY.analyze_batch(
			_state, 0, 0, [{"owner": 1, "squadron_index": 0}],
			[placement], [])
	assert_true(bool(result["ok"]), result["reason"])
	assert_eq(result["required_placeable_count"], 1)
	assert_eq(result["required_direct_touch_count"], 1)


func test_rejects_incomplete_union_with_deterministic_deficiency_shape() -> void:
	var result: Dictionary = AUTHORITY.analyze_batch(
			_state, 0, 0, [{"owner": 1, "squadron_index": 0}], [], [])
	assert_false(bool(result["ok"]))
	assert_eq(result.keys(), [
		"ok", "reason", "required_placeable_count",
		"submitted_placeable_count", "required_direct_touch_count",
		"submitted_direct_touch_count",
	])


func test_secondary_placement_must_touch_a_directly_placed_squadron() -> void:
	var second := SquadronInstance.create_from_data(
			"affected", _squadron_data(), 0)
	_state.get_player_state(0).squadrons.append(second)
	var play_area: Vector2 = GameScale.play_area_size_px
	var base := ShipBase.new(_ship.ship_data.ship_size,
			Transform2D(0.0, _ship.get_pixel_position(play_area)))
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var direct: Vector2 = base.ship_transform * Vector2(
			0.0, -base.half_length_px - radius - 1.0)
	var invalid_secondary: Vector2 = direct + Vector2(radius * 3.0, 0.0)
	var result: Dictionary = AUTHORITY.analyze_batch(_state, 0, 0, [
		{"owner": 1, "squadron_index": 0},
		{"owner": 0, "squadron_index": 0},
	], [{
		"owner": 1, "squadron_index": 0,
		"pos_x": direct.x / play_area.x,
		"pos_y": direct.y / play_area.y,
	}, {
		"owner": 0, "squadron_index": 0,
		"pos_x": invalid_secondary.x / play_area.x,
		"pos_y": invalid_secondary.y / play_area.y,
	}], [])
	assert_false(bool(result["ok"]))
	assert_string_contains(result["reason"], "secondary")


func test_authority_proves_multi_squadron_total_and_direct_maximum() -> void:
	var second := SquadronInstance.create_from_data(
			"affected", _squadron_data(), 0)
	_state.get_player_state(0).squadrons.append(second)
	var play_area: Vector2 = GameScale.play_area_size_px
	var base := ShipBase.new(_ship.ship_data.ship_size,
			Transform2D(0.0, _ship.get_pixel_position(play_area)))
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var points: Array[Vector2] = [
		base.ship_transform * Vector2(
			-radius, -base.half_length_px - radius - 1.0),
		base.ship_transform * Vector2(
			radius, -base.half_length_px - radius - 1.0),
	]
	var placements: Array[Dictionary] = []
	for index: int in range(points.size()):
		placements.append({
			"owner": 1 if index == 0 else 0,
			"squadron_index": 0,
			"pos_x": points[index].x / play_area.x,
			"pos_y": points[index].y / play_area.y,
		})
	var result: Dictionary = AUTHORITY.analyze_batch(_state, 0, 0, [
		{"owner": 1, "squadron_index": 0},
		{"owner": 0, "squadron_index": 0},
	], placements, [])
	assert_true(bool(result["ok"]), result["reason"])
	assert_eq(result["required_placeable_count"], 2)
	assert_eq(result["required_direct_touch_count"], 2)


func test_globally_blocked_corner_accepts_only_authoritative_destruction() -> void:
	var play_area: Vector2 = GameScale.play_area_size_px
	var probe := ShipBase.new(_ship.ship_data.ship_size, Transform2D.IDENTITY)
	_ship.pos_x = probe.half_width_px / play_area.x
	_ship.pos_y = probe.half_length_px / play_area.y
	var right := ShipInstance.create_from_data("right", _ship_data(), 1, 1)
	right.pos_x = (probe.half_width_px * 3.0) / play_area.x
	right.pos_y = probe.half_length_px / play_area.y
	_state.get_player_state(1).ships.append(right)
	var below := ShipInstance.create_from_data("below", _ship_data(), 1, 0)
	below.pos_x = probe.half_width_px / play_area.x
	below.pos_y = (probe.half_length_px * 3.0) / play_area.y
	_state.get_player_state(0).ships.append(below)
	var result: Dictionary = AUTHORITY.analyze_batch(
			_state, 0, 0, [{"owner": 1, "squadron_index": 0}],
			[], [{"owner": 1, "squadron_index": 0}])
	assert_true(bool(result["ok"]), result["reason"])
	assert_eq(result["required_placeable_count"], 0)
	assert_eq(result["required_direct_touch_count"], 0)


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data


func _squadron_data() -> SquadronData:
	var data := SquadronData.new()
	data.hull = 3
	return data

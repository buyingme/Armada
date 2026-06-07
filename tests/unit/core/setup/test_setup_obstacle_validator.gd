## Test: SetupObstacleValidator
##
## Unit tests for FB14E obstacle placement validation.
extends GutTest


const MAP_3X3: String = "map_3x3_azure_v4.jpg"
const MAP_3X6: String = "map_3x6_distant-planet_v4.jpg"
const SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_interaction_flow_resolver.gd")
const SETUP_OBSTACLE_VALIDATOR_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_obstacle_validator.gd")
const OBSTACLE_KEYS: Array[String] = [
	"asteroid_1",
	"asteroid_2",
	"asteroid_3",
	"debris_1",
	"debris_2",
	"station",
]


var _state: GameState = null


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SETUP
	_state.current_round = 0
	_state.initiative_player = 0
	_state.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: {
			"player_display_names": ["Alex", "Blake"],
		},
		FleetSetupBootstrapper.KEY_OBSTACLES: [],
		FleetSetupBootstrapper.KEY_DEPLOYMENTS: [],
		FleetSetupBootstrapper.KEY_MAP: {"filename": MAP_3X3},
	}
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(_state)


func test_validate_commit_wrong_controller_rejected() -> void:
	var result: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _payload("asteroid_1", 0.5, 0.5))
	assert_ne(result, "",
			"Only the projected obstacle-placement controller should be allowed to act.")


func test_validate_commit_duplicate_obstacle_rejected() -> void:
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = [
		_obstacle("asteroid_1", 0.5, 0.5, 1, 0),
	]
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _payload("asteroid_1", 0.6, 0.5))

	assert_ne(result, "",
			"A committed obstacle key should not be placeable a second time.")


func test_validate_commit_3x6_deployment_zone_overlap_rejected() -> void:
	_state.objectives[FleetSetupBootstrapper.KEY_MAP] = {"filename": MAP_3X6}
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _payload("asteroid_2", 0.5, 0.18))

	assert_ne(result, "",
			"3x6 obstacle placements should reject footprints that overlap deployment zones.")


func test_validate_commit_3x3_full_play_area_allows_near_edge_expected() -> void:
	var result: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _payload("asteroid_2", 0.12, 0.12))

	assert_eq(result, "",
			"3x3 setup should use the full play area instead of the 3x6 setup band.")


func test_validate_commit_distance_one_separation_rejected() -> void:
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = [
		_obstacle("asteroid_1", 0.5, 0.5, 1, 0),
	]
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _payload("debris_1", 0.56, 0.5))

	assert_ne(result, "",
			"Obstacle placements must stay beyond distance 1 of each other.")


func test_validate_commit_rotation_changes_setup_band_legality_expected() -> void:
	_state.objectives[FleetSetupBootstrapper.KEY_MAP] = {"filename": MAP_3X6}
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(_state)
	var threshold_y: float = _rotation_threshold_y("asteroid_1")

	var unrotated: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _payload("asteroid_1", 0.5, threshold_y, 0.0))
	var rotated: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _payload("asteroid_1", 0.5, threshold_y, 90.0))

	assert_eq(unrotated, "",
			"The unrotated obstacle should fit within the 3x6 setup band at this Y value.")
	assert_ne(rotated, "",
			"Rotating a wide obstacle should change its setup-band footprint test.")


func test_validate_commit_standard_pool_allows_exact_sixth_obstacle_expected() -> void:
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = _five_obstacles()
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_OBSTACLE_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _payload("station", 0.82, 0.12))

	assert_eq(result, "",
			"The final standard obstacle should remain legal when it satisfies spacing rules.")


func _payload(data_key: String,
		pos_x: float,
		pos_y: float,
		rotation_deg: float = 0.0) -> Dictionary:
	return {
		"data_key": data_key,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
	}


func _obstacle(data_key: String,
		pos_x: float,
		pos_y: float,
		placing_player: int,
		placement_order: int,
		rotation_deg: float = 0.0) -> Dictionary:
	return {
		"data_key": data_key,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
		"placing_player": placing_player,
		"placement_order": placement_order,
	}


func _five_obstacles() -> Array[Dictionary]:
	return [
		_obstacle(OBSTACLE_KEYS[0], 0.12, 0.12, 1, 0),
		_obstacle(OBSTACLE_KEYS[1], 0.28, 0.88, 0, 1),
		_obstacle(OBSTACLE_KEYS[2], 0.46, 0.16, 1, 2),
		_obstacle(OBSTACLE_KEYS[3], 0.64, 0.84, 0, 3),
		_obstacle(OBSTACLE_KEYS[4], 0.82, 0.5, 1, 4),
	]


func _rotation_threshold_y(data_key: String) -> float:
	var obstacle_data: ObstacleData = AssetLoader.load_obstacle_data(data_key)
	var metadata: Dictionary = obstacle_data.shape_metadata
	var scale: float = GameScale.squadron_base_diameter_px
	var unrotated_half_y: float = float(metadata.get("height_factor", 0.0)) * scale * 0.5
	var rotated_half_y: float = float(metadata.get("width_factor", 0.0)) * scale * 0.5
	var top_clearance: float = GameScale.distance_bands_px[2]
	var play_area_height: float = GameScale.ruler_length_px * 3.0
	return (top_clearance + ((unrotated_half_y + rotated_half_y) * 0.5)) / play_area_height
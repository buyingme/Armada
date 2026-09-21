extends GutTest


const REMOTE_LOG_PATH := "user://logs/candidate_damage_projection.log"

var _saved_state: GameState = null


func before_each() -> void:
	_saved_state = GameManager.current_game_state


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameLogger.disable_file_logging()
	if FileAccess.file_exists(REMOTE_LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REMOTE_LOG_PATH))


func test_debris_result_refreshes_shields_without_fabricating_damage_card() -> void:
	var ship: ShipInstance = _ship()
	GameManager.current_game_state = _state_with_ship(ship)
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(adapter)
	var command := GameCommand.new(0, "resolve_debris_overlap", {})
	watch_signals(EventBus)

	adapter._emit_candidate_damage_events(command, {
		"damage_application": {
			"owner_player": 0,
			"ship_index": 0,
			"shield_changes": [{"zone": "left", "new_shields": 1}],
			"facedown_delta": 0,
			"faceup_additions": [],
			"new_hull": 8,
		},
	})

	assert_signal_emitted_with_parameters(EventBus, "ship_shields_changed",
			[ship, "left", 1])
	assert_signal_not_emitted(EventBus, "damage_card_dealt",
			"Shield-only Debris damage must not fabricate a card refresh.")
	assert_signal_emitted_with_parameters(EventBus, "ship_hull_changed",
			[ship, 8])


func test_candidate_result_refreshes_damage_cards_when_card_was_dealt() -> void:
	var ship: ShipInstance = _ship()
	GameManager.current_game_state = _state_with_ship(ship)
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(adapter)
	var command := GameCommand.new(0, "resolve_debris_overlap", {})
	watch_signals(EventBus)

	adapter._emit_candidate_damage_events(command, {
		"damage_application": {
			"owner_player": 0,
			"ship_index": 0,
			"shield_changes": [],
			"facedown_delta": 1,
			"faceup_additions": [],
			"new_hull": 7,
		},
	})

	assert_signal_emitted_with_parameters(EventBus, "damage_card_dealt",
			[ship, null, false])
	assert_signal_emitted_with_parameters(EventBus, "ship_hull_changed",
			[ship, 7])


func test_debris_remote_sequence_is_owned_by_candidate_presentation() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var previous_log_level: int = GameLogger.min_level
	var previous_file_level: int = GameLogger.min_file_level
	GameLogger.disable_file_logging()
	GameLogger.min_level = GameLogger.Level.ERROR + 1
	GameLogger.min_file_level = GameLogger.Level.DEBUG
	assert_true(GameLogger.enable_file_logging(REMOTE_LOG_PATH))
	for command_type: String in ["commit_maneuver_obstacle_order",
			"resolve_debris_overlap", "complete_maneuver"]:
		GameManager._handle_remote_command_effects(
				GameCommand.new(0, command_type, {}), {})
	GameLogger.disable_file_logging()
	GameLogger.min_level = previous_log_level
	GameLogger.min_file_level = previous_file_level
	var content := FileAccess.get_file_as_string(REMOTE_LOG_PATH)
	assert_false(content.contains("Unhandled remote command type"),
			"Candidate Debris sequence must not fall through remote routing.")


func _state_with_ship(ship: ShipInstance) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.player_states[0].ships.append(ship)
	return state


func _ship() -> ShipInstance:
	var data := ShipData.new()
	data.hull = 8
	data.max_speed = 2
	data.navigation_chart = [[1], [1, 1]]
	data.command_value = 3
	data.shields = {"front": 3, "left": 3, "right": 3, "rear": 1}
	data.defense_tokens = []
	return ShipInstance.create_from_data("projection_ship", data, 1, 0)

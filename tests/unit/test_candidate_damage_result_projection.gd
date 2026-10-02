extends GutTest


const REMOTE_LOG_PATH := "user://logs/candidate_damage_projection.log"

var _saved_state: GameState = null
var _saved_role: NetworkManager.Role


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_role = NetworkManager.role


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	NetworkManager.role = _saved_role
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


func test_life_support_result_refreshes_canonical_command_tokens() -> void:
	var ship: ShipInstance = _ship()
	GameManager.current_game_state = _state_with_ship(ship)
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(adapter)
	var command := GameCommand.new(0, "resolve_immediate_effect", {})
	watch_signals(EventBus)
	adapter._emit_candidate_damage_events(command, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "life_support_failure",
		"effect_result": {"tokens_cleared": true},
	})
	assert_signal_emitted_with_parameters(EventBus,
			"command_tokens_changed", [ship])


func test_maneuver_injured_crew_result_removes_discarded_panel_token() -> void:
	var data := ShipData.new()
	data.hull = 8
	data.max_speed = 2
	data.navigation_chart = [[1], [1, 1]]
	data.command_value = 3
	data.shields = {"front": 3, "left": 3, "right": 3, "rear": 1}
	data.defense_tokens = ["EVADE", "BRACE"]
	var ship := ShipInstance.create_from_data("injured_projection", data, 1, 0)
	GameManager.current_game_state = _state_with_ship(ship)
	var panel := ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	panel.add_ship_entry(ship)
	var token_col: VBoxContainer = panel._entries[0]["token_col"] \
			as VBoxContainer
	var before_count: int = token_col.get_child_count()
	assert_gt(before_count, 0)
	ship.discard_defense_token(0)
	assert_eq(int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.DISCARDED)
	assert_true(EventBus.ship_defense_token_changed.is_connected(
			panel._on_defense_tokens_changed))
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(adapter)
	NetworkManager.role = NetworkManager.Role.NONE
	watch_signals(EventBus)
	adapter._emit_candidate_damage_events(GameCommand.new(
			0, "resolve_immediate_effect", {"enclosing_kind": "maneuver"}), {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "injured_crew",
		"effect_result": {"defense_token_index": 0},
	})
	assert_signal_emitted_with_parameters(EventBus,
			"ship_defense_token_changed", [ship])
	await get_tree().process_frame
	assert_eq(token_col.get_child_count(), before_count - 1,
			"Accepted Maneuver result must refresh the existing panel immediately.")
	NetworkManager.role = NetworkManager.Role.CLIENT
	var client_emissions: Array[RefCounted] = []
	var count_client_emissions := func(changed: RefCounted) -> void:
		client_emissions.append(changed)
	EventBus.ship_defense_token_changed.connect(count_client_emissions)
	adapter._emit_candidate_damage_events(GameCommand.new(
			0, "resolve_immediate_effect", {"enclosing_kind": "maneuver"}), {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "injured_crew",
	})
	assert_eq(client_emissions.size(), 0,
			"The passive remote handler already owns the client refresh.")
	NetworkManager.role = NetworkManager.Role.NONE
	adapter._emit_candidate_damage_events(GameCommand.new(
			0, "resolve_immediate_effect", {"enclosing_kind": "attack"}), {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "injured_crew",
	})
	assert_eq(client_emissions.size(), 0,
			"The Attack immediate-effect owner retains its existing refresh.")
	EventBus.ship_defense_token_changed.disconnect(count_client_emissions)


func test_lethal_source_projects_cleaned_damage_without_second_command() \
		-> void:
	var ship: ShipInstance = _ship()
	GameManager.current_game_state = _state_with_ship(ship)
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(adapter)
	var command := GameCommand.new(0, "apply_maneuver_transform", {
		"owner_player": 0, "ship_index": 0,
	})
	ship.mark_destroyed()
	watch_signals(EventBus)
	adapter._emit_source_destruction_presentation(command, {
		"owner_player": 0,
		"ship_index": 0,
		"destruction_cleanup": {
			"facedown_discards": [],
			"ship_phase_turn_terminated": true,
			"next_ship_phase_controller": 1,
		},
	})
	assert_signal_emitted_with_parameters(EventBus, "damage_card_dealt",
			[ship, null, false])
	assert_signal_emitted_with_parameters(EventBus, "ship_hull_changed",
			[ship, 0])


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

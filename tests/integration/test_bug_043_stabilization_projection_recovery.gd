extends GutTest


const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
const SAVE_MANAGER_SCRIPT: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const ACTIVATION_ID := "ship-activation:v4"
const EXECUTION_ID := "maneuver:v4"
const TEST_SAVE_PREFIX := "gut_bug_043_v5_"

var _saved_state: GameState
var _saved_active: bool
var _saved_preloaded: bool
var _saved_submitter: CommandSubmitter
var _saved_mode: PlayMode.Mode
var _saved_role: NetworkManager.Role
var _saved_local_player: int


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return {"recorded": true}


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_preloaded = GameManager.is_state_preloaded
	_saved_submitter = GameManager.get_command_submitter()
	_saved_mode = PlayMode.current_mode
	_saved_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.is_state_preloaded = _saved_preloaded
	GameManager.set_command_submitter(_saved_submitter)
	PlayMode.current_mode = _saved_mode
	NetworkManager.role = _saved_role
	NetworkManager._local_player_index = _saved_local_player


func test_v4_live_and_reconstructed_decision_projection_are_equivalent() \
		-> void:
	var cases: Array[Dictionary] = [
		{"shape": "obstacle_order", "command": "commit_maneuver_obstacle_order",
			"choice": "", "options": 2, "multi": false, "chooser": "owner"},
		{"shape": "hull_zone", "command": "resolve_debris_overlap",
			"choice": "", "options": 4, "multi": false, "chooser": "owner"},
		{"shape": "station_union", "command": "resolve_station_overlap",
			"choice": "", "options": 3, "multi": false, "chooser": "owner"},
		{"shape": "immediate_single", "command": "resolve_immediate_effect",
			"choice": "defense_token_index", "options": 3, "multi": false,
			"chooser": "owner"},
		{"shape": "shield_multi", "command": "resolve_immediate_effect",
			"choice": "shield_zones", "options": 4, "multi": true,
			"chooser": "opponent"},
		{"shape": "comm_union", "command": "resolve_immediate_effect",
			"choice": "comm_noise", "options": 5, "multi": false,
			"chooser": "opponent"},
	]
	for spec: Dictionary in cases:
		var state: GameState = _decision_state(str(spec["shape"]))
		assert_true(GameManager.start_new_game_from_state(
				state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0),
				str(spec["shape"]))
		var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
		add_child(board)
		var submitter := RecordingSubmitter.new()
		GameManager.set_command_submitter(submitter)
		var controller: ShipActivationController = \
				board._ship_activation_controller
		controller._close_maneuver_consequence_modal()

		board._command_router_adapter._modal_router.route_command_result(
				GameCommand.new(0, "v4_projection_trigger", {}), {})
		var live_action: Dictionary = \
				controller._pending_maneuver_action.duplicate(true)
		var live_descriptor: Dictionary = controller \
				._maneuver_consequence_modal._choice_info.duplicate(true)
		assert_eq(live_action.get("command_type"), spec["command"],
				str(spec["shape"]))
		assert_eq(live_action.get("choice", ""), spec["choice"],
				str(spec["shape"]))
		assert_eq((live_descriptor.get("options", []) as Array).size(),
				spec["options"], str(spec["shape"]))
		assert_eq(bool(live_descriptor.get("multi_select", false)),
				spec["multi"], str(spec["shape"]))
		assert_eq(live_descriptor.get("chooser"), spec["chooser"],
				"The adapter must preserve the symbolic modal contract.")
		assert_eq(submitter.submitted.size(), 0,
				"Live projection must not submit semantic work.")

		controller._close_maneuver_consequence_modal()
		board._command_router_adapter.reconstruct_presentation()
		assert_eq(controller._pending_maneuver_action, live_action,
				"Reconstruction must derive the same action for %s." % spec["shape"])
		assert_eq(controller._maneuver_consequence_modal._choice_info,
				live_descriptor,
				"Reconstruction must derive the same options for %s." % spec["shape"])
		assert_eq(submitter.submitted.size(), 0,
				"Reconstruction must not submit semantic work.")

		var actor: int = int(live_action["player_index"])
		PlayMode.set_mode(PlayMode.Mode.NETWORK)
		NetworkManager.role = NetworkManager.Role.CLIENT
		NetworkManager._local_player_index = 1 - actor
		controller._close_maneuver_consequence_modal()
		board._command_router_adapter.reconstruct_presentation()
		assert_true(controller._pending_maneuver_action.is_empty(),
				"A passive viewer must remain read-only for %s." % spec["shape"])
		assert_false(controller._maneuver_consequence_modal.visible,
				"A passive viewer must not receive an actionable modal.")
		assert_eq(submitter.submitted.size(), 0)
		await get_tree().process_frame
		board.free()
		PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
		NetworkManager.role = NetworkManager.Role.NONE
		NetworkManager._local_player_index = -1


func test_v5_production_save_install_and_filtered_reconnect_preserve_owners() \
		-> void:
	var cases: Array[String] = [
		"uncommitted_open", "committed_pre_movement", "displacement",
		"obstacle_order", "debris", "station", "ruptured",
		"projector_choice", "injured_choice", "shield_choice", "comm_choice",
		"automatic_boundary", "completed", "destroyed",
	]
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	for kind: String in cases:
		var source: GameState = _recovery_state(kind)
		var source_ship: ShipInstance = source.get_ship(0, 0)
		var expected_action: Dictionary = ManeuverExecutionEvaluator.next_action(
				source, 0, 0)
		GameManager.current_game_state = source
		GameManager.is_game_active = true
		CommandProcessor.reset()
		var save_name: String = TEST_SAVE_PREFIX + kind
		assert_true(manager.save_game(source, save_name), kind)
		var loaded: Dictionary = manager.load_game(save_name)
		assert_true(bool(loaded.get("ok", false)), kind)
		var restored: GameState = loaded.get("state") as GameState
		assert_not_null(restored, kind)
		if restored == null:
			manager.delete_save(save_name)
			continue
		var restored_ship: ShipInstance = restored.get_ship(0, 0)
		assert_eq(restored_ship.ship_activation_boundary_snapshot(),
				source_ship.ship_activation_boundary_snapshot(), kind)
		assert_eq(restored_ship.active_immediate_resolution_snapshot(),
				source_ship.active_immediate_resolution_snapshot(), kind)
		assert_eq(restored.interaction_flow.flow_type,
				source.interaction_flow.flow_type, kind)
		assert_eq(restored.interaction_flow.step_id,
				source.interaction_flow.step_id, kind)
		assert_eq(restored.interaction_flow.controller_player,
				source.interaction_flow.controller_player, kind)
		_assert_action_equivalent(
				ManeuverExecutionEvaluator.next_action(restored, 0, 0),
				expected_action, kind)
		assert_true(GameManager.start_new_game_from_state(
				restored, LearningScenarioSetup.DEFAULT_SCENARIO_ID,
				(loaded.get("meta") as SaveGameMetadata).next_command_sequence), kind)
		assert_true(CommandProcessor.get_history().is_empty(),
				"Save installation must not synthesize work for %s." % kind)
		if str(expected_action.get("kind", "")) == "decision":
			var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
			add_child(board)
			var submitter := RecordingSubmitter.new()
			GameManager.set_command_submitter(submitter)
			board._command_router_adapter.reconstruct_presentation()
			var projected: Dictionary = board._ship_activation_controller \
					._pending_maneuver_action
			_assert_action_equivalent(projected, expected_action,
					"real-board:%s" % kind)
			assert_eq(submitter.submitted.size(), 0, kind)
			await get_tree().process_frame
			board.free()

		var filtered: Dictionary = StateFilter.filter_for_player(
				source.serialize(), 1)
		var passive: GameState = GameState.deserialize_passive_network(filtered)
		assert_not_null(passive, kind)
		if passive != null:
			PlayMode.set_mode(PlayMode.Mode.NETWORK)
			NetworkManager.role = NetworkManager.Role.CLIENT
			NetworkManager._local_player_index = 1
			assert_true(GameManager.start_new_game_from_state(
					passive, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0), kind)
			_assert_action_equivalent(
					ManeuverExecutionEvaluator.next_action(passive, 0, 0),
					expected_action, "filtered:%s" % kind)
			assert_true(CommandProcessor.get_history().is_empty(),
					"Filtered reconnect must not synthesize work for %s." % kind)
		PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
		NetworkManager.role = NetworkManager.Role.NONE
		NetworkManager._local_player_index = -1
		manager.delete_save(save_name)
	manager.free()


func _assert_action_equivalent(actual: Dictionary, expected: Dictionary,
		label: String) -> void:
	for key: String in [
		"kind", "command_type", "player_index", "choice", "multi_select",
		"max_selections", "speed_available", "dial_available",
	]:
		assert_eq(actual.get(key), expected.get(key), "%s.%s" % [label, key])
	for key: String in ["faceup_refs", "obstacles"]:
		assert_eq(actual.get(key, []), expected.get(key, []),
				"%s.%s" % [label, key])
	var actual_hull_zones: Array = actual.get("hull_zones", []).duplicate()
	var expected_hull_zones: Array = expected.get("hull_zones", []).duplicate()
	actual_hull_zones.sort()
	expected_hull_zones.sort()
	assert_eq(actual_hull_zones, expected_hull_zones,
			"%s.hull_zones" % label)
	var actual_options: Array = actual.get("options", []).duplicate(true)
	var expected_options: Array = expected.get("options", []).duplicate(true)
	if str(expected.get("choice", "")) == "shield_zones":
		actual_options.sort()
		expected_options.sort()
	assert_eq(actual_options, expected_options, "%s.options" % label)
	var actual_payload: Dictionary = actual.get("payload", {}) as Dictionary
	var expected_payload: Dictionary = expected.get("payload", {}) as Dictionary
	for key: String in [
		"owner_player", "ship_index", "ship_activation_identity",
		"maneuver_execution_id", "obstacle_id", "public_card_ref",
		"immediate_resolution_id", "maneuver_source_kind",
		"maneuver_source_id",
	]:
		assert_eq(actual_payload.get(key), expected_payload.get(key),
				"%s.payload.%s" % [label, key])


func test_v5_json_normalization_rejects_fractional_canonical_integers() \
		-> void:
	var committed: Dictionary = _plain_maneuver_state("committed").serialize()
	var committed_ship: Dictionary = committed["player_states"][0]["ships"][0]
	committed_ship["active_maneuver_execution"]["committed_result"] \
			["yaw_clicks"][0] = 0.5
	assert_null(GameState.deserialize(committed),
			"Fractional yaw clicks must not enter canonical state.")

	var immediate: Dictionary = _decision_state("immediate_single").serialize()
	var immediate_ship: Dictionary = immediate["player_states"][0]["ships"][0]
	immediate_ship["active_immediate_resolution"]["actor_player"] = 0.5
	assert_null(GameState.deserialize(immediate),
			"Fractional actors must not enter canonical state.")

	var obstacles: Dictionary = _decision_state("obstacle_order").serialize()
	obstacles["objectives"]["obstacles"][0]["placement_order"] = 0.5
	assert_null(GameState.deserialize(obstacles),
			"Fractional placement identity must not enter canonical state.")


func _recovery_state(kind: String) -> GameState:
	match kind:
		"obstacle_order":
			return _decision_state("obstacle_order")
		"debris":
			return _decision_state("hull_zone")
		"station":
			return _decision_state("station_union")
		"injured_choice":
			return _decision_state("immediate_single")
		"shield_choice":
			return _decision_state("shield_multi")
		"comm_choice":
			return _decision_state("comm_union")
	var stage: String = "uncommitted" \
			if kind == "uncommitted_open" else "committed" \
			if kind == "committed_pre_movement" else "applied"
	var state: GameState = _plain_maneuver_state(stage)
	var ship: ShipInstance = state.get_ship(0, 0)
	match kind:
		"displacement":
			var squadron_data: SquadronData = AssetLoader.load_squadron_data(
					"x_wing_squadron")
			var squadron := SquadronInstance.create_from_data(
					"x_wing_squadron", squadron_data, 1)
			squadron.pos_x = ship.pos_x
			squadron.pos_y = ship.pos_y
			state.get_player_state(1).squadrons.append(squadron)
			var start := CandidateStartDisplacementCommand.new(0, {
				"owner_player": 0, "ship_index": 0,
				"ship_activation_identity": ACTIVATION_ID,
				"maneuver_execution_id": EXECUTION_ID,
				"displaced_squadrons": [{"owner": 1, "squadron_index": 0}],
			})
			assert_false(start.execute(state).is_empty())
		"ruptured":
			ship.current_speed = 2
			_add_faceup(state, ship, "ruptured_engine")
		"projector_choice":
			_open_immediate(state, ship, "projector_misaligned", 0)
		"automatic_boundary":
			_open_immediate(state, ship, "structural_damage", -1)
		"completed":
			assert_true(ship.complete_maneuver_execution(
					ACTIVATION_ID, EXECUTION_ID, true))
		"destroyed":
			ship.mark_destroyed()
			state.interaction_flow = InteractionFlow.make(
					Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.WAIT_FOR_SHIP_SELECT, 1)
	return state


func _plain_maneuver_state(stage: String) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(4305)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize_for_save7()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	var data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var ship := ShipInstance.create_from_data("cr90_corvette_a", data, 1, 0)
	ship.roster_entry_id = "v5:ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(ship.open_maneuver_opportunity(ACTIVATION_ID))
	if stage != "uncommitted":
		assert_true(ship.commit_maneuver_execution(
				ACTIVATION_ID, EXECUTION_ID, false, {
					"yaw_clicks": [0], "yaw_bonus_joint": -1,
					"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
				}, {"kind": "none"}))
	if stage == "applied":
		assert_false(ship.apply_maneuver_final_transform(
				ACTIVATION_ID, EXECUTION_ID).is_empty())
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP, 0,
			Constants.Visibility.ALL, {
				"ship_index": 0,
				"ship_activation_identity": ACTIVATION_ID,
			})
	return state


func _decision_state(shape: String) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(4304)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize_for_save7()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	var data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var ship := ShipInstance.create_from_data("cr90_corvette_a", data, 1, 0)
	ship.roster_entry_id = "v4:ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(ship.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(ship.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP, 0,
			Constants.Visibility.ALL, {
				"ship_index": 0,
				"ship_activation_identity": ACTIVATION_ID,
			})
	match shape:
		"obstacle_order":
			state.objectives["obstacles"] = [
				_obstacle("obstacle:0", "debris_1", 0),
				_obstacle("obstacle:1", "station", 1),
			]
		"hull_zone":
			assert_true(ship.open_debris_resolution(
					ACTIVATION_ID, EXECUTION_ID, "obstacle:debris", 0))
		"station_union":
			_add_faceup(state, ship, "ordinary")
			ship.add_facedown_damage(_take_card(state, "ordinary", false))
			assert_true(ship.open_station_resolution(
					ACTIVATION_ID, EXECUTION_ID, "obstacle:station", 0))
		"immediate_single":
			_open_immediate(state, ship, "injured_crew", 0)
		"shield_multi":
			_open_immediate(state, ship, "shield_failure", 1)
		"comm_union":
			assert_true(ship.command_dial_stack.assign_dials(
					[Constants.CommandType.NAVIGATE], 1))
			_open_immediate(state, ship, "comm_noise", 1)
	return state


func _open_immediate(state: GameState, ship: ShipInstance,
		effect: String, actor: int) -> void:
	var public_ref: String = "faceup:v4:%s" % effect
	var card: DamageCard = _take_card(state, effect, true)
	var physical_id: String = card.physical_card_id
	card.public_card_ref = public_ref
	ship.add_faceup_damage(card)
	var immediate_id: String = "immediate:%s" % public_ref
	assert_true(ship.open_asteroid_resolution(
			ACTIVATION_ID, EXECUTION_ID, "obstacle:asteroid", immediate_id))
	assert_true(ship.establish_immediate_resolution({
		"immediate_resolution_id": immediate_id,
		"public_card_ref": public_ref,
		"physical_card_id": physical_id,
		"effect_id": effect,
		"actor_player": actor,
		"exact_once_key": "immediate:maneuver:%s:%s:%s" % [
			ACTIVATION_ID, EXECUTION_ID, physical_id],
		"enclosing_kind": "maneuver",
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"maneuver_source_kind": "asteroid",
		"maneuver_source_id": "obstacle:asteroid",
	}))


func _obstacle(id: String, key: String, order: int) -> Dictionary:
	return {
		"obstacle_id": id, "data_key": key,
		"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
		"placing_player": 0, "placement_order": order,
		"last_maneuver_execution_id": "",
	}


func _add_faceup(state: GameState, ship: ShipInstance,
		effect: String) -> void:
	var card: DamageCard = _take_card(state, effect, true)
	card.public_card_ref = "faceup:%s" % card.physical_card_id
	ship.add_faceup_damage(card)


func _take_card(state: GameState, effect: String,
		faceup: bool) -> DamageCard:
	var card: DamageCard = state.damage_deck.draw_card()
	assert_not_null(card)
	card.effect_id = effect
	card.title = effect
	card.trait_type = "Ship"
	card.timing = "immediate" if effect in [
		"injured_crew", "shield_failure", "comm_noise"] else "persistent"
	card.is_faceup = faceup
	return card

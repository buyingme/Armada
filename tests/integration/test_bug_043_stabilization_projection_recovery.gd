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
var _saved_host_principal: String
var _saved_principal_admission: bool


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []
	var authoritative_submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return {"recorded": true}

	func submit_authoritative(command: GameCommand) -> Dictionary:
		authoritative_submitted.append(command)
		return {"recorded": true}


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_preloaded = GameManager.is_state_preloaded
	_saved_submitter = GameManager.get_command_submitter()
	_saved_mode = PlayMode.current_mode
	_saved_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	_saved_host_principal = NetworkManager._host_match_principal_id
	_saved_principal_admission = NetworkManager._principal_command_admission_enabled
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
	NetworkManager._host_match_principal_id = _saved_host_principal
	NetworkManager._principal_command_admission_enabled = \
			_saved_principal_admission


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
			var projected: Dictionary = board._ship_activation_controller \
					._pending_maneuver_action
			_assert_action_equivalent(projected, expected_action,
					"real-board:%s" % kind)
			assert_eq(submitter.submitted.size(), 0, kind)
			await get_tree().process_frame
			board.free()
		if kind == "displacement":
			var flow_payload: Dictionary = \
					GameManager.current_game_state.interaction_flow.payload
			assert_eq(typeof(flow_payload.get("owner_player")), TYPE_INT)
			assert_eq(typeof(flow_payload.get("ship_index")), TYPE_INT)
			var entries: Array = flow_payload["displaced_squadrons"] as Array
			assert_eq(typeof(entries[0]["owner"]), TYPE_INT)
			assert_eq(typeof(entries[0]["squadron_index"]), TYPE_INT)
			var displacement_board: GameBoard = \
					GAME_BOARD_SCENE.instantiate() as GameBoard
			add_child(displacement_board)
			assert_eq(displacement_board._displacement_controller \
					._displacement_queue.size(), 1,
					"Normal board entry must route recovered displacement.")
			assert_true(CommandProcessor.get_history().is_empty(),
					"Displacement reconstruction must not submit work.")
			await get_tree().process_frame
			displacement_board.free()

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
			var passive_action: Dictionary = \
					ManeuverExecutionEvaluator.next_action(passive, 0, 0)
			if kind in ["committed_pre_movement", "displacement"]:
				assert_eq(passive_action.get("kind"), "waiting",
						"Passive recovery must await authority for %s." % kind)
			else:
				_assert_action_equivalent(passive_action, expected_action,
						"filtered:%s" % kind)
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

	var displaced: Dictionary = _recovery_state("displacement").serialize()
	displaced["interaction_flow"]["payload"]["ship_index"] = 0.5
	assert_null(GameState.deserialize(displaced),
			"Fractional displacement identity must reject installation.")


func test_bug056_signed_displacement_restore_submits_through_game_manager() \
		-> void:
	var source: GameState = _recovery_state("displacement")
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	var save_name: String = TEST_SAVE_PREFIX + "displacement_submission"
	assert_true(manager.save_game(source, save_name))
	var loaded: Dictionary = manager.load_game(save_name)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	assert_not_null(restored)
	if restored != null:
		assert_true(GameManager.start_new_game_from_state(restored,
				LearningScenarioSetup.DEFAULT_SCENARIO_ID,
				int((loaded.get("meta") as SaveGameMetadata) \
						.next_command_sequence)))
		var ship: ShipInstance = restored.get_ship(0, 0)
		var base := ShipBase.new(ship.ship_data.ship_size,
				Transform2D(0.0, ship.get_pixel_position(
						GameScale.play_area_size_px)))
		var point: Vector2 = base.ship_transform * Vector2(0.0,
				-base.half_length_px \
				- GameScale.squadron_base_diameter_px * 0.5 - 1.0)
		var result: Dictionary = GameManager.submit_commit_displacement([{
			"owner": 1, "squadron_index": 0,
			"pos_x": point.x / GameScale.play_area_size_px.x,
			"pos_y": point.y / GameScale.play_area_size_px.y,
		}])
		assert_false(result.is_empty(),
				"Recovered displacement must pass its real submission adapter.")
	manager.delete_save(save_name)
	manager.free()


func test_bug054_thruster_modal_confirmation_preserves_public_source() -> void:
	var state: GameState = _plain_maneuver_state("uncommitted")
	var ship: ShipInstance = state.get_ship(0, 0)
	assert_true(ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	_add_faceup(state, ship, "thruster_fissure")
	var card: DamageCard = ship.faceup_damage[0] as DamageCard
	assert_true(GameManager.start_new_game_from_state(state,
			LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var submitter := RecordingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	var controller: ShipActivationController = \
			board._ship_activation_controller
	assert_eq(controller._pending_maneuver_action.get("command_type"),
			"resolve_thruster_fissure")
	controller._maneuver_consequence_modal.choice_confirmed.emit({"id": "FRONT"})
	assert_eq(submitter.submitted.size(), 1)
	if not submitter.submitted.is_empty():
		var command: GameCommand = submitter.submitted[0]
		assert_eq(command.payload.get("public_card_ref"),
				card.public_card_ref)
		assert_eq(command.payload.get("hull_zone"), "FRONT")
		assert_eq(command.validate(state), "",
				"The actual modal submission must satisfy strict authority.")


func test_bug055_automatic_immediate_edges_match_canonical_union() -> void:
	var cases: Array[Dictionary] = [
		{"effect": "injured_crew", "branch": "single_token"},
		{"effect": "comm_noise", "branch": "speed_only",
			"expected_action": "speed"},
		{"effect": "comm_noise", "branch": "neither",
			"expected_action": "none"},
	]
	for spec: Dictionary in cases:
		var state: GameState = _plain_maneuver_state("applied")
		var ship: ShipInstance = state.get_ship(0, 0)
		if spec["branch"] == "single_token":
			for index: int in range(1, ship.defense_tokens.size()):
				ship.discard_defense_token(index)
		elif spec["branch"] == "neither":
			ship.current_speed = 0
		_open_immediate(state, ship, str(spec["effect"]), -1)
		var card: DamageCard = ship.faceup_card_for_public_ref(
				"faceup:v4:%s" % spec["effect"])
		assert_true(ImmediateEffectResolver.new().get_required_choice(
				card, ship).is_empty(), str(spec["branch"]))
		GameManager.current_game_state = state
		var submitter := RecordingSubmitter.new()
		GameManager.set_command_submitter(submitter)
		GameManager.submit_resolve_immediate_effect(ship, card)
		assert_eq(submitter.authoritative_submitted.size(), 1,
				str(spec["branch"]))
		if not submitter.authoritative_submitted.is_empty():
			var command: GameCommand = submitter.authoritative_submitted[0]
			assert_false(command.payload.has("defense_token_index"),
					str(spec["branch"]))
			if spec.has("expected_action"):
				assert_eq(command.payload.get("comm_noise_action"),
						spec["expected_action"])
			assert_eq(command.validate(state), "", str(spec["branch"]))


func test_bug058_two_ruptured_sources_advance_on_passive_and_reconnect() -> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var ship: ShipInstance = authority.get_ship(0, 0)
	ship.current_speed = 2
	_add_faceup(authority, ship, "ruptured_engine")
	_add_faceup(authority, ship, "ruptured_engine")
	var host_before: Dictionary = StateFilter.filter_for_player(
			authority.serialize(), 0)
	var before: Dictionary = StateFilter.filter_for_player(
			authority.serialize(), 1)
	var passive: GameState = GameState.deserialize_passive_network(before)
	assert_not_null(passive)
	if passive == null:
		return
	var refs: Array = ship.faceup_damage.map(func(card: DamageCard) -> String:
		return card.public_card_ref)
	assert_eq(passive.get_ship(0, 0)
			.passive_maneuver_consequence_view_snapshot().get(
					"public_card_refs", []), refs)
	var command := CandidateResolveRupturedEngineCommand.new(0, {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": refs[0], "hull_zone": "FRONT",
	})
	assert_eq(command.validate(authority), "")
	var result: Dictionary = command.execute(authority)
	assert_false(result.is_empty())
	var replacement: Dictionary = \
			ManeuverConsequenceProjection.capture_authority(authority)
	assert_eq((replacement["consequence_view"] as Dictionary)[
			"public_card_refs"], [refs[1]])
	GameManager.current_game_state = passive
	CommandProcessor.reset()
	command.sequence = 0
	var envelope: Dictionary = {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": command.application_contract_id(),
		"application_contract_version": 2,
		"viewer_player": 1,
		"application_result": result,
		"presentation_result": {},
		"maneuver_consequence_view": replacement,
	}
	var mirrored: Dictionary = CommandProcessor.submit_mirror(
			command, envelope, 1)
	assert_false(mirrored.is_empty())
	assert_eq(passive.get_ship(0, 0)
			.passive_maneuver_consequence_view_snapshot().get(
					"public_card_refs", []), [refs[1]])
	assert_eq((passive.get_ship(0, 0).faceup_damage[0] as DamageCard)
			.last_ruptured_engine_execution_id, "")
	var resumed: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(authority.serialize(), 1))
	assert_not_null(resumed)
	if resumed != null:
		assert_eq(resumed.get_ship(0, 0)
				.passive_maneuver_consequence_view_snapshot(),
				passive.get_ship(0, 0)
						.passive_maneuver_consequence_view_snapshot())
	var stale := CandidateResolveRupturedEngineCommand.new(0,
			command.payload.duplicate(true))
	assert_ne(stale.validate(passive), "")
	var host_passive: GameState = GameState.deserialize_passive_network(
			host_before)
	assert_not_null(host_passive)
	if host_passive != null:
		GameManager.current_game_state = host_passive
		CommandProcessor.reset()
		var host_envelope: Dictionary = envelope.duplicate(true)
		host_envelope["viewer_player"] = 0
		assert_false(CommandProcessor.submit_mirror(
				command, host_envelope, 0).is_empty())
		assert_eq(host_passive.get_ship(0, 0)
				.passive_maneuver_consequence_view_snapshot(),
				passive.get_ship(0, 0)
						.passive_maneuver_consequence_view_snapshot())
		var host_reconnect: GameState = GameState.deserialize_passive_network(
				StateFilter.filter_for_player(authority.serialize(), 0))
		assert_not_null(host_reconnect)
		if host_reconnect != null:
			assert_eq(host_reconnect.get_ship(0, 0)
					.passive_maneuver_consequence_view_snapshot(),
					host_passive.get_ship(0, 0)
							.passive_maneuver_consequence_view_snapshot())


func test_bug058_three_ruptured_sources_preserve_nonfirst_choice() -> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var ship: ShipInstance = authority.get_ship(0, 0)
	ship.current_speed = 2
	for source_index: int in range(3):
		_add_faceup(authority, ship, "ruptured_engine")
	var refs: Array = ship.faceup_damage.map(func(card: DamageCard) -> String:
		return card.public_card_ref)
	var passive: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(authority.serialize(), 1))
	assert_not_null(passive)
	if passive == null:
		return
	GameManager.current_game_state = passive
	CommandProcessor.reset()
	for selected_index: int in [1, 2]:
		var command := CandidateResolveRupturedEngineCommand.new(0, {
			"owner_player": 0, "ship_index": 0,
			"ship_activation_identity": ACTIVATION_ID,
			"maneuver_execution_id": EXECUTION_ID,
			"public_card_ref": refs[selected_index], "hull_zone": "FRONT",
		})
		command.sequence = CommandProcessor.get_next_sequence()
		assert_eq(command.validate(authority), "")
		var result: Dictionary = command.execute(authority)
		assert_false(result.is_empty())
		var replacement: Dictionary = \
				ManeuverConsequenceProjection.capture_authority(authority)
		var expected_refs: Array = [refs[0], refs[2]] \
				if selected_index == 1 else [refs[0]]
		assert_eq((replacement["consequence_view"] as Dictionary)[
				"public_card_refs"], expected_refs)
		var envelope: Dictionary = {
			"protocol_version": NetworkManager.PROTOCOL_VERSION,
			"application_contract": command.application_contract_id(),
			"application_contract_version": 2,
			"viewer_player": 1,
			"application_result": result,
			"presentation_result": {},
			"maneuver_consequence_view": replacement,
		}
		assert_false(CommandProcessor.submit_mirror(
				command, envelope, 1).is_empty())
		assert_eq(passive.get_ship(0, 0)
				.passive_maneuver_consequence_view_snapshot().get(
						"public_card_refs"), expected_refs)
		var reconnect: GameState = GameState.deserialize_passive_network(
				StateFilter.filter_for_player(authority.serialize(), 1))
		assert_not_null(reconnect)
		if reconnect != null:
			assert_eq(reconnect.get_ship(0, 0)
					.passive_maneuver_consequence_view_snapshot(),
					passive.get_ship(0, 0)
							.passive_maneuver_consequence_view_snapshot())
	assert_eq(CommandProcessor.get_next_sequence(), 2)


func test_bug058_replacement_rejection_precedes_canonical_mutation() -> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var ship: ShipInstance = authority.get_ship(0, 0)
	ship.current_speed = 2
	_add_faceup(authority, ship, "ruptured_engine")
	_add_faceup(authority, ship, "ruptured_engine")
	var refs: Array = ship.faceup_damage.map(func(card: DamageCard) -> String:
		return card.public_card_ref)
	var passive: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(authority.serialize(), 1))
	assert_not_null(passive)
	if passive == null:
		return
	var command := CandidateResolveRupturedEngineCommand.new(0, {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": refs[0], "hull_zone": "FRONT",
	})
	command.sequence = 0
	var result: Dictionary = command.execute(authority)
	var replacement: Dictionary = \
			ManeuverConsequenceProjection.capture_authority(authority)
	var valid_envelope: Dictionary = {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": command.application_contract_id(),
		"application_contract_version": 2,
		"viewer_player": 1,
		"application_result": result,
		"presentation_result": {},
		"maneuver_consequence_view": replacement,
	}
	GameManager.current_game_state = passive
	CommandProcessor.reset()
	var before: Dictionary = passive.serialize()
	var observations: Array[Dictionary] = []
	var observer: Callable = func(_accepted: GameCommand,
			_accepted_result: Dictionary) -> void:
		observations.append({
			"view": passive.get_ship(0, 0)
					.passive_maneuver_consequence_view_snapshot(),
			"cursor": CommandProcessor.get_next_sequence(),
		})
	CommandProcessor.command_executed.connect(observer)
	var invalid: Array[Dictionary] = []
	var missing: Dictionary = valid_envelope.duplicate(true)
	missing.erase("maneuver_consequence_view")
	invalid.append(missing)
	var old_protocol: Dictionary = valid_envelope.duplicate(true)
	old_protocol["protocol_version"] = 7
	invalid.append(old_protocol)
	var wrong_viewer: Dictionary = valid_envelope.duplicate(true)
	wrong_viewer["viewer_player"] = 0
	invalid.append(wrong_viewer)
	var wrong_execution: Dictionary = valid_envelope.duplicate(true)
	wrong_execution["maneuver_consequence_view"][
			"maneuver_execution_id"] = "maneuver:wrong"
	invalid.append(wrong_execution)
	var nonpublic_ref: Dictionary = valid_envelope.duplicate(true)
	nonpublic_ref["maneuver_consequence_view"]["consequence_view"][
			"public_card_refs"] = ["faceup:missing"]
	invalid.append(nonpublic_ref)
	var already_resolved: Dictionary = valid_envelope.duplicate(true)
	already_resolved["maneuver_consequence_view"]["consequence_view"][
			"public_card_refs"] = refs
	invalid.append(already_resolved)
	for envelope: Dictionary in invalid:
		assert_true(CommandProcessor.submit_mirror(
				command, envelope, 1).is_empty())
		assert_eq(passive.serialize(), before)
		assert_eq(CommandProcessor.get_next_sequence(), 0)
		assert_true(CommandProcessor.get_history().is_empty())
		assert_eq(CommandProcessor.get_pending_observer_followup_count(), 0)
		assert_true(observations.is_empty())
	var bad_application: Dictionary = valid_envelope.duplicate(true)
	bad_application["application_result"]["damage_application"][
			"facedown_delta"] = 9
	assert_true(CommandProcessor.submit_mirror(
			command, bad_application, 1).is_empty())
	assert_eq(passive.serialize(), before)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_true(CommandProcessor.get_history().is_empty())
	assert_true(observations.is_empty())
	assert_engine_error(invalid.size() + 1)
	assert_false(CommandProcessor.submit_mirror(
			command, valid_envelope, 1).is_empty())
	assert_eq(observations.size(), 1)
	if not observations.is_empty():
		assert_eq(observations[0]["view"], replacement["consequence_view"])
		assert_eq(observations[0]["cursor"], 1)
	CommandProcessor.command_executed.disconnect(observer)


func test_bug043_nonfixture_replay_preserves_partial_maneuver_consequence() \
		-> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var ship: ShipInstance = authority.get_ship(0, 0)
	ship.current_speed = 2
	_add_faceup(authority, ship, "ruptured_engine")
	_add_faceup(authority, ship, "ruptured_engine")
	var initial: Dictionary = authority.serialize()
	var refs: Array = ship.faceup_damage.map(func(card: DamageCard) -> String:
		return card.public_card_ref)
	GameManager.current_game_state = authority
	CommandProcessor.reset()
	var command := CandidateResolveRupturedEngineCommand.new(0, {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": refs[1], "hull_zone": "FRONT",
	})
	assert_false(CommandProcessor.submit(command).is_empty())
	var authority_final: Dictionary = authority.serialize()
	var replay_file: GameReplay = CommandProcessor.create_replay()
	assert_not_null(replay_file)
	if replay_file == null:
		return
	var loaded: GameReplay = GameReplay.deserialize(
			JSON.parse_string(JSON.stringify(replay_file.serialize())))
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.header["format_version"], 10)
	assert_eq(loaded.commands.size(), 1)
	var replay_state: GameState = GameState.deserialize(initial)
	assert_not_null(replay_state)
	if replay_state == null:
		return
	GameManager.current_game_state = replay_state
	CommandProcessor.reset()
	for recorded: Dictionary in loaded.commands:
		var replay_command: GameCommand = GameCommand.deserialize(recorded)
		assert_not_null(replay_command)
		if replay_command != null:
			assert_false(CommandProcessor.submit_replay(
					replay_command).is_empty())
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(ManeuverConsequenceProjection.capture_authority(replay_state),
			ManeuverConsequenceProjection.capture_authority(authority))
	assert_eq(CommandProcessor.get_next_sequence(), 1)


func test_bug058_result_envelopes_keep_each_committed_frozen_view() -> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var ship: ShipInstance = authority.get_ship(0, 0)
	ship.current_speed = 2
	for source_index: int in range(3):
		_add_faceup(authority, ship, "ruptured_engine")
	var refs: Array = ship.faceup_damage.map(func(card: DamageCard) -> String:
		return card.public_card_ref)
	GameManager.current_game_state = authority
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	CommandProcessor.reset()
	var first := CandidateResolveRupturedEngineCommand.new(0, {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": refs[0], "hull_zone": "FRONT",
	})
	var first_result: Dictionary = CommandProcessor.submit_deferred_followups(
			first)
	assert_false(first_result.is_empty())
	var first_view: Dictionary = CommandProcessor \
			.frozen_maneuver_consequence_view(first.sequence)
	assert_eq((first_view["consequence_view"] as Dictionary)[
			"public_card_refs"], [refs[1], refs[2]])
	var second := CandidateResolveRupturedEngineCommand.new(0, {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": refs[2], "hull_zone": "FRONT",
	})
	var second_result: Dictionary = CommandProcessor.submit_deferred_followups(
			second)
	assert_false(second_result.is_empty())
	var second_view: Dictionary = CommandProcessor \
			.frozen_maneuver_consequence_view(second.sequence)
	assert_eq((second_view["consequence_view"] as Dictionary)[
			"public_card_refs"], [refs[1]])
	assert_eq(NetworkManager._build_result_envelope(
			first, first_result, 0)["maneuver_consequence_view"], first_view)
	assert_eq(NetworkManager._build_result_envelope(
			first, first_result, 1)["maneuver_consequence_view"], first_view)
	assert_eq(NetworkManager._build_result_envelope(
			second, second_result, 1)["maneuver_consequence_view"], second_view)
	CommandProcessor.release_frozen_maneuver_consequence_view(first.sequence)
	CommandProcessor.release_frozen_maneuver_consequence_view(second.sequence)


func test_bug058_obstacle_order_and_return_reject_public_skips() -> void:
	var authority: GameState = _decision_state("obstacle_order")
	var passive: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(authority.serialize(), 1))
	assert_not_null(passive)
	if passive == null:
		return
	var base: Dictionary = {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
	}
	var order := CandidateCommitManeuverObstacleOrderCommand.new(0,
			base.merged({"obstacle_ids": ["obstacle:0", "obstacle:1"]}))
	order.sequence = 0
	var order_result: Dictionary = order.execute(authority)
	assert_false(order_result.is_empty())
	var order_replacement: Dictionary = \
			ManeuverConsequenceProjection.capture_authority(authority)
	assert_eq(order_replacement["consequence_view"]["obstacle_id"],
			"obstacle:0")
	GameManager.current_game_state = passive
	CommandProcessor.reset()
	var order_envelope: Dictionary = {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": order.application_contract_id(),
		"application_contract_version": 2,
		"viewer_player": 1,
		"application_result": order.project_application_result(
				order_result, 1),
		"presentation_result": {},
		"maneuver_consequence_view": order_replacement,
	}
	var before: Dictionary = passive.serialize()
	var skipped_order: Dictionary = order_envelope.duplicate(true)
	skipped_order["maneuver_consequence_view"]["consequence_view"][
			"obstacle_id"] = "obstacle:1"
	assert_true(CommandProcessor.submit_mirror(
			order, skipped_order, 1).is_empty())
	assert_eq(passive.serialize(), before)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_engine_error(1)
	assert_false(CommandProcessor.submit_mirror(
			order, order_envelope, 1).is_empty())
	assert_eq(passive.get_ship(0, 0)
			.passive_maneuver_consequence_view_snapshot()["obstacle_id"],
			"obstacle:0")
	var hull_zone: String = str(authority.get_ship(0, 0)
			.current_shields.keys()[0])
	var debris := CandidateResolveDebrisOverlapCommand.new(0,
			base.merged({"obstacle_id": "obstacle:0", "hull_zone": hull_zone}))
	debris.sequence = 1
	var debris_result: Dictionary = debris.execute(authority)
	assert_false(debris_result.is_empty())
	var next_replacement: Dictionary = \
			ManeuverConsequenceProjection.capture_authority(authority)
	assert_eq(next_replacement["consequence_view"]["obstacle_id"],
			"obstacle:1")
	var debris_envelope: Dictionary = {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": debris.application_contract_id(),
		"application_contract_version": 2,
		"viewer_player": 1,
		"application_result": debris.project_application_result(
				debris_result, 1),
		"presentation_result": {},
		"maneuver_consequence_view": next_replacement,
	}
	before = passive.serialize()
	var stale_current: Dictionary = debris_envelope.duplicate(true)
	stale_current["maneuver_consequence_view"]["consequence_view"][
			"obstacle_id"] = "obstacle:0"
	assert_true(CommandProcessor.submit_mirror(
			debris, stale_current, 1).is_empty())
	assert_eq(passive.serialize(), before)
	assert_eq(CommandProcessor.get_next_sequence(), 1)
	assert_engine_error(2)
	assert_false(CommandProcessor.submit_mirror(
			debris, debris_envelope, 1).is_empty())
	assert_eq(passive.get_ship(0, 0)
			.passive_maneuver_consequence_view_snapshot()["obstacle_id"],
			"obstacle:1")
	assert_eq(CommandProcessor.get_next_sequence(), 2)


func test_bug058_damaged_controls_nonfirst_sources_survive_recovery() -> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var data: ShipData = AssetLoader.load_ship_data(
			"victory_ii_class_star_destroyer")
	var ship := ShipInstance.create_from_data(
			"victory_ii_class_star_destroyer", data, 1, 0)
	ship.roster_entry_id = "v5:ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	assert_true(ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(ship.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(ship.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	authority.get_player_state(0).ships[0] = ship
	ship.current_speed = 0
	authority.objectives["obstacles"] = [
		_obstacle("obstacle:0", "asteroid_1", 0)]
	for source_index: int in range(3):
		_add_faceup(authority, ship, "damaged_controls")
	var refs: Array = ship.faceup_damage.map(func(card: DamageCard) -> String:
		return card.public_card_ref)
	var initial: Dictionary = authority.serialize()
	var alternate: GameState = GameState.deserialize(initial)
	assert_not_null(alternate)
	if alternate == null:
		return
	(alternate.get_ship(0, 0).faceup_damage[2] as DamageCard) \
			.last_damaged_controls_execution_id = EXECUTION_ID
	assert_eq(alternate.get_ship(0, 0).faceup_damage.map(
			func(card: DamageCard) -> Dictionary:
				return card.public_faceup_damage_card()),
			ship.faceup_damage.map(func(card: DamageCard) -> Dictionary:
				return card.public_faceup_damage_card()))
	assert_eq((ManeuverConsequenceProjection.capture_authority(
			authority)["consequence_view"] as Dictionary)[
				"public_card_refs"], refs)
	assert_eq((ManeuverConsequenceProjection.capture_authority(
			alternate)["consequence_view"] as Dictionary)[
				"public_card_refs"], [refs[0], refs[1]])
	var passive: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(initial, 1))
	assert_not_null(passive)
	if passive == null:
		return
	GameManager.current_game_state = passive
	CommandProcessor.reset()
	for selected_index: int in [2, 1]:
		var command := CandidateResolveDamagedControlsCommand.new(0, {
			"owner_player": 0, "ship_index": 0,
			"ship_activation_identity": ACTIVATION_ID,
			"maneuver_execution_id": EXECUTION_ID,
			"public_card_ref": refs[selected_index],
			"overlap_kind": "obstacle", "obstacle_id": "obstacle:0",
		})
		command.sequence = CommandProcessor.get_next_sequence()
		assert_eq(command.validate(authority), "")
		var result: Dictionary = command.execute(authority)
		assert_false(result.is_empty())
		var replacement: Dictionary = \
				ManeuverConsequenceProjection.capture_authority(authority)
		var expected_refs: Array = [refs[0], refs[1]] \
				if selected_index == 2 else [refs[0]]
		assert_eq((replacement["consequence_view"] as Dictionary)[
				"public_card_refs"], expected_refs)
		var envelope: Dictionary = {
			"protocol_version": NetworkManager.PROTOCOL_VERSION,
			"application_contract": command.application_contract_id(),
			"application_contract_version": 2,
			"viewer_player": 1,
			"application_result": command.project_application_result(
					result, 1),
			"presentation_result": {},
			"maneuver_consequence_view": replacement,
		}
		assert_false(CommandProcessor.submit_mirror(
				command, envelope, 1).is_empty())
		assert_eq(passive.get_ship(0, 0)
				.passive_maneuver_consequence_view_snapshot()[
						"public_card_refs"], expected_refs)
		var saved: GameState = GameState.deserialize(authority.serialize())
		assert_not_null(saved)
		if saved != null:
			assert_eq((ManeuverConsequenceProjection.capture_authority(
					saved)["consequence_view"] as Dictionary)[
						"public_card_refs"], expected_refs)
		var reconnect: GameState = GameState.deserialize_passive_network(
				StateFilter.filter_for_player(authority.serialize(), 1))
		assert_not_null(reconnect)
		if reconnect != null:
			assert_eq(reconnect.get_ship(0, 0)
					.passive_maneuver_consequence_view_snapshot(),
					passive.get_ship(0, 0)
							.passive_maneuver_consequence_view_snapshot())
	assert_eq(CommandProcessor.get_next_sequence(), 2)


func test_bug058_filtered_install_rejects_obsolete_and_invalid_view() -> void:
	var authority: GameState = _plain_maneuver_state("applied")
	var ship: ShipInstance = authority.get_ship(0, 0)
	ship.current_speed = 2
	_add_faceup(authority, ship, "ruptured_engine")
	var filtered: Dictionary = StateFilter.filter_for_player(
			authority.serialize(), 1)
	assert_false(filtered["player_states"][0]["ships"][0][
			"faceup_damage"][0].has("last_ruptured_engine_execution_id"))
	assert_not_null(GameState.deserialize_passive_network(filtered))
	var missing: Dictionary = filtered.duplicate(true)
	var missing_execution: Dictionary = missing["player_states"][0][
			"ships"][0]["active_maneuver_execution"]
	missing_execution.erase("consequence_view")
	assert_null(GameState.deserialize_passive_network(missing),
			"Protocol-7 filtered snapshots cannot install under protocol 8.")
	var extra: Dictionary = filtered.duplicate(true)
	extra["player_states"][0]["ships"][0][
			"active_maneuver_execution"]["consequence_view"][
				"private_marker"] = "forbidden"
	assert_null(GameState.deserialize_passive_network(extra))
	var wrong_source: Dictionary = filtered.duplicate(true)
	wrong_source["player_states"][0]["ships"][0][
			"active_maneuver_execution"]["consequence_view"][
				"public_card_refs"] = ["faceup:nonpublic"]
	assert_null(GameState.deserialize_passive_network(wrong_source))
	var duplicate_source: Dictionary = filtered.duplicate(true)
	var refs: Array = duplicate_source["player_states"][0]["ships"][0][
			"active_maneuver_execution"]["consequence_view"][
				"public_card_refs"]
	refs.append(refs[0])
	assert_null(GameState.deserialize_passive_network(duplicate_source))


func test_r1_automatic_immediate_uses_authority_submission_across_principals() \
		-> void:
	var state: GameState = _recovery_state("automatic_boundary")
	var ship: ShipInstance = state.get_ship(0, 0)
	var card: DamageCard = ship.faceup_card_for_public_ref(
			"faceup:v4:structural_damage")
	GameManager.current_game_state = state
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 1
	var submitter := RecordingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	GameManager.submit_resolve_immediate_effect(ship, card)
	assert_eq(submitter.submitted.size(), 0,
			"Automatic work must not enter the player principal gate.")
	assert_eq(submitter.authoritative_submitted.size(), 1)
	if not submitter.authoritative_submitted.is_empty():
		assert_eq(submitter.authoritative_submitted[0].player_index, 0,
				"The command retains the canonical ship owner as actor identity.")


func test_r1_host_player_gate_rejects_automatic_immediate_branch() -> void:
	var state: GameState = _recovery_state("automatic_boundary")
	GameManager.current_game_state = state
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._principal_command_admission_enabled = true
	NetworkManager._host_match_principal_id = state.principal_id_for_player(0)
	var ship: ShipInstance = state.get_ship(0, 0)
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	var command := CandidateResolveImmediateEffectCommand.new(0, {
		"owner_player": 0, "ship_index": 0,
		"public_card_ref": record["public_card_ref"],
		"immediate_resolution_id": record["immediate_resolution_id"],
		"enclosing_kind": "maneuver",
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"maneuver_source_kind": "asteroid",
		"maneuver_source_id": "obstacle:0",
	})
	assert_eq(command.validate(state), "")
	var before: Dictionary = state.serialize()
	var result: Dictionary = NetworkHostCommandSubmitter.new().submit(command)
	assert_true(result.is_empty(),
			"A host player cannot author an authority-only immediate branch.")
	assert_eq(state.serialize(), before)


func test_r2_v2_comm_noise_result_refreshes_speed_visual_consumer() -> void:
	var state: GameState = _decision_state("comm_union")
	GameManager.current_game_state = state
	var ship: ShipInstance = state.get_ship(0, 0)
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(record["public_card_ref"]))
	var command := CandidateResolveImmediateEffectCommand.new(1, {
		"owner_player": 0, "ship_index": 0,
		"public_card_ref": record["public_card_ref"],
		"immediate_resolution_id": record["immediate_resolution_id"],
		"enclosing_kind": "maneuver",
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"maneuver_source_kind": "asteroid",
		"maneuver_source_id": "obstacle:0",
		"comm_noise_action": "speed",
	})
	assert_eq(command.validate(state), "")
	var result: Dictionary = command.execute(state)
	assert_false(result.is_empty())
	var speed_events: Array[int] = []
	var on_speed := func(_changed_ship: RefCounted, speed: int) -> void:
		speed_events.append(speed)
	EventBus.ship_speed_changed.connect(on_speed)
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(adapter)
	adapter._emit_candidate_damage_events(command, result)
	EventBus.ship_speed_changed.disconnect(on_speed)
	assert_eq(speed_events, [ship.current_speed],
			"The v2 result must refresh the actual speed visual consumer.")
	var helper_events: Array[int] = []
	var on_helper_speed := func(_changed_ship: RefCounted, speed: int) -> void:
		helper_events.append(speed)
	EventBus.ship_speed_changed.connect(on_helper_speed)
	ImmediateEffectSignals.emit(card, ship, result)
	EventBus.ship_speed_changed.disconnect(on_helper_speed)
	assert_eq(helper_events, [ship.current_speed],
			"The shared Attack/debug visual helper must read the v2 result.")
	var dial_state: GameState = _decision_state("comm_union")
	GameManager.current_game_state = dial_state
	var dial_ship: ShipInstance = dial_state.get_ship(0, 0)
	var dial_record: Dictionary = dial_ship.active_immediate_resolution_snapshot()
	var dial_card: DamageCard = dial_ship.faceup_card_for_public_ref(
			str(dial_record["public_card_ref"]))
	var dial_payload: Dictionary = command.payload.duplicate(true)
	dial_payload["comm_noise_action"] = "dial"
	dial_payload["replacement_command"] = int(Constants.CommandType.REPAIR)
	var dial_command := CandidateResolveImmediateEffectCommand.new(
			1, dial_payload)
	assert_eq(dial_command.validate(dial_state), "")
	var dial_result: Dictionary = dial_command.execute(dial_state)
	var dial_events: Array[ShipInstance] = []
	var on_dial := func(changed_ship: RefCounted) -> void:
		dial_events.append(changed_ship as ShipInstance)
	EventBus.command_dials_changed.connect(on_dial)
	adapter._emit_candidate_damage_events(dial_command, dial_result)
	EventBus.command_dials_changed.disconnect(on_dial)
	assert_eq(dial_events, [dial_ship])
	dial_events.clear()
	EventBus.command_dials_changed.connect(on_dial)
	ImmediateEffectSignals.emit(dial_card, dial_ship, dial_result)
	EventBus.command_dials_changed.disconnect(on_dial)
	assert_eq(dial_events, [dial_ship])


func test_r3_debug_choice_recovers_through_normal_board_entry() -> void:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(4306)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize_for_save7()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	var data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var ship := ShipInstance.create_from_data("cr90_corvette_a", data, 1, 0)
	ship.roster_entry_id = "r3:ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	state.get_player_state(0).ships.append(ship)
	var card: DamageCard = _take_card(state, "shield_failure", true)
	card.public_card_ref = "faceup:r3:shield"
	ship.add_faceup_damage(card)
	assert_true(ship.establish_immediate_resolution({
		"immediate_resolution_id": "immediate:faceup:r3:shield",
		"public_card_ref": card.public_card_ref,
		"physical_card_id": card.physical_card_id,
		"effect_id": "shield_failure", "actor_player": 1,
		"exact_once_key": "immediate:debug:debug:60:%s" % card.physical_card_id,
		"enclosing_kind": "debug", "debug_application_id": "debug:60",
	}))
	GameManager.current_game_state = state
	assert_true(GameManager.start_new_game_from_state(state,
			LearningScenarioSetup.DEFAULT_SCENARIO_ID, 61))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	await get_tree().process_frame
	var controller: DamageCardImmediateEffectController = \
			board._damage_card_immediate_effect_controller
	assert_eq(ship.active_immediate_resolution_snapshot().get("enclosing_kind"),
			"debug")
	assert_false(ImmediateEffectResolver.new().get_required_choice(
			card, ship).is_empty())
	assert_true(controller._can_act_as(1))
	assert_eq(controller._pending_card, card,
			"Normal board entry must recover the pending debug decision.")
	EventBus.handoff_accepted.emit()
	assert_not_null(controller.get_node_or_null(
			"DebugDamageImmediateEffectModalLayer"),
			"The recovered decision must open after the normal handoff.")
	assert_true(CommandProcessor.get_history().is_empty(),
			"Reconstruction must submit no semantic command.")


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
			state.objectives["obstacles"] = [
				_obstacle("obstacle:0", "debris_1", 0)]
			assert_true(ship.commit_maneuver_obstacle_order(
					ACTIVATION_ID, EXECUTION_ID, ["obstacle:0"]))
			assert_true(ship.open_debris_resolution(
					ACTIVATION_ID, EXECUTION_ID, "obstacle:0", 0))
		"station_union":
			state.objectives["obstacles"] = [
				_obstacle("obstacle:0", "station", 0)]
			assert_true(ship.commit_maneuver_obstacle_order(
					ACTIVATION_ID, EXECUTION_ID, ["obstacle:0"]))
			_add_faceup(state, ship, "ordinary")
			ship.add_facedown_damage(_take_card(state, "ordinary", false))
			assert_true(ship.open_station_resolution(
					ACTIVATION_ID, EXECUTION_ID, "obstacle:0", 0))
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
	state.objectives["obstacles"] = [
		_obstacle("obstacle:0", "asteroid_1", 0)]
	assert_true(ship.commit_maneuver_obstacle_order(
			ACTIVATION_ID, EXECUTION_ID, ["obstacle:0"]))
	var public_ref: String = "faceup:v4:%s" % effect
	var card: DamageCard = _take_card(state, effect, true)
	var physical_id: String = card.physical_card_id
	card.public_card_ref = public_ref
	ship.add_faceup_damage(card)
	var immediate_id: String = "immediate:%s" % public_ref
	assert_true(ship.open_asteroid_resolution(
			ACTIVATION_ID, EXECUTION_ID, "obstacle:0", immediate_id))
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
		"maneuver_source_id": "obstacle:0",
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

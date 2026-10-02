extends GutTest


const EXECUTE: GDScript = preload(
		"res://src/core/commands/candidate_execute_maneuver_command.gd")
const APPLY: GDScript = preload(
		"res://src/core/commands/candidate_apply_maneuver_transform_command.gd")
const PROCESSOR: GDScript = preload("res://src/autoload/command_processor.gd")

var _state: GameState
var _ship: ShipInstance
var _previous_state: GameState


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_ship = ShipInstance.create_from_data("candidate", _ship_data(), 1, 0)
	_ship.pos_x = 0.5
	_ship.pos_y = 0.75
	_state.get_player_state(0).ships.append(_ship)
	assert_true(_ship.establish_ship_activation("ship-activation:10"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:10"))
	var commit: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": 1,
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 10
	assert_false(commit.execute(_state).is_empty())


func after_each() -> void:
	GameManager.current_game_state = _previous_state


func test_applies_committed_transform_atomically_once() -> void:
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	var committed: Dictionary = _ship.active_maneuver_execution_snapshot()[
			"committed_result"]
	var command: GameCommand = _command()
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_false(result.is_empty())
	assert_ne(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_eq(_ship.pos_x, committed["pos_x"])
	assert_eq(_ship.pos_y, committed["pos_y"])
	var execution: Dictionary = _ship.active_maneuver_execution_snapshot()
	assert_true(bool(execution["final_transform_applied"]))
	assert_false(execution.has("committed_result"))
	assert_ne(_command().validate(_state), "")


func test_active_pre_movement_obligation_blocks_application() -> void:
	var card := DamageCard.new()
	card.physical_card_id = "damage:0"
	card.public_card_ref = "faceup:1:0"
	card.effect_id = "structural_damage"
	card.timing = "immediate"
	card.is_faceup = true
	_ship.add_faceup_damage(card)
	assert_true(_ship.establish_immediate_resolution({
		"immediate_resolution_id": "immediate:faceup:1:0",
		"public_card_ref": "faceup:1:0",
		"physical_card_id": "damage:0",
		"effect_id": "structural_damage",
		"actor_player": -1,
		"exact_once_key": "immediate:debug:debug:1:damage:0",
		"enclosing_kind": "debug",
		"debug_application_id": "debug:1",
	}))
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	assert_ne(_command().validate(_state), "")
	assert_eq(_command().execute(_state), {})
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)


func test_destruction_before_application_suppresses_transform() -> void:
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	_ship.mark_destroyed()
	assert_eq(_command().execute(_state), {})
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_false(_ship.has_active_maneuver_execution())


func test_applied_out_of_play_result_is_retained_then_terminates_execution() -> void:
	# Rebuild a speed-zero execution whose actual base is outside play.
	_ship.mark_destroyed()
	_ship = ShipInstance.create_from_data("candidate", _ship_data(), 0, 0)
	_ship.pos_x = 0.001
	_ship.pos_y = 0.001
	_state.get_player_state(0).ships[0] = _ship
	assert_true(_ship.establish_ship_activation("ship-activation:10"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:10"))
	var commit: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 10
	assert_false(commit.execute(_state).is_empty())
	var result: Dictionary = _command().execute(_state)
	assert_false(result.is_empty())
	assert_true(_ship.is_destroyed())
	assert_false(_ship.has_active_maneuver_execution())
	assert_almost_eq(_ship.pos_x, 0.001, 0.00001)


func test_v3_processor_out_of_play_cleanup_occurs_once_without_completion() \
		-> void:
	_ship.mark_destroyed()
	_ship = ShipInstance.create_from_data("candidate", _ship_data(), 0, 0)
	_ship.pos_x = 0.001
	_ship.pos_y = 0.001
	_state.get_player_state(0).ships[0] = _ship
	var next_ship := ShipInstance.create_from_data(
			"next", _ship_data(), 1, 1)
	_state.get_player_state(1).ships.append(next_ship)
	var surviving_ship := ShipInstance.create_from_data(
			"survivor", _ship_data(), 1, 0)
	_state.get_player_state(0).ships.append(surviving_ship)
	assert_true(_ship.establish_ship_activation("ship-activation:v3:oob"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:v3:oob"))
	var commit := EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:v3:oob",
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 30
	assert_false(commit.execute(_state).is_empty())
	GameManager.current_game_state = _state
	var processor: Node = PROCESSOR.new()
	add_child_autofree(processor)
	var apply := APPLY.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:v3:oob",
		"maneuver_execution_id": "maneuver:30",
	})

	assert_false(processor.submit(apply).is_empty())

	assert_true(_ship.has_finalized_destruction())
	var types: Array[String] = []
	for command: GameCommand in processor.get_history():
		types.append(command.command_type)
	assert_eq(types, ["apply_maneuver_transform"])
	assert_eq(types.count("destroy_unit"), 0)
	assert_false(types.has("complete_maneuver"))
	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_eq(_state.interaction_flow.controller_player, 1)


func test_contract_3_application_accepts_only_recorded_committed_transform() -> void:
	var mirror := GameState.new()
	mirror.initialize()
	mirror.current_phase = Constants.GamePhase.SHIP
	var mirror_ship := ShipInstance.create_from_data(
			"candidate", _ship_data(), 1, 0)
	mirror_ship.pos_x = 0.5
	mirror_ship.pos_y = 0.75
	mirror.get_player_state(0).ships.append(mirror_ship)
	assert_true(mirror_ship.establish_ship_activation("ship-activation:10"))
	assert_true(mirror_ship.open_maneuver_opportunity("ship-activation:10"))
	var commit: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": 1,
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 10
	assert_false(commit.execute(mirror).is_empty())
	var authority: GameCommand = _command()
	var result: Dictionary = authority.execute(_state)
	var passive: GameCommand = APPLY.new(0, authority.payload.duplicate(true))
	assert_eq(passive.project_application_result(result, 1), result)
	assert_eq(passive.execute_with_application_result(mirror, result), result)
	assert_eq(Vector2(mirror_ship.pos_x, mirror_ship.pos_y),
			Vector2(_ship.pos_x, _ship.pos_y))


func test_out_of_play_transfers_assigned_cards_and_returns_from_activation() \
		-> void:
	_prepare_out_of_play_source(true)
	var other := ShipInstance.create_from_data("cr90_corvette_a",
			AssetLoader.load_ship_data("cr90_corvette_a"), 1, 1)
	other.roster_entry_id = "opponent"
	_state.get_player_state(1).ships.append(other)
	var passive_data: Dictionary = StateFilter.filter_for_player(
			_state.serialize(), 1)
	assert_false(passive_data.is_empty())
	var passive: GameState = GameState.deserialize_passive_network(passive_data)
	assert_not_null(passive)
	var command: GameCommand = _out_of_play_command()
	var result: Dictionary = command.execute(_state)
	assert_true(bool(result.get("destroyed", false)))
	assert_true(_ship.has_finalized_destruction())
	assert_eq(_ship.faceup_damage.size(), 0)
	assert_eq(_ship.facedown_damage.size(), 0)
	assert_eq(_state.damage_deck.get_discard_count(), 2)
	var discarded: Dictionary = {}
	for raw: Variant in _state.damage_deck.serialize_for_save7()["discard_pile"]:
		discarded[(raw as Dictionary)["physical_card_id"]] = true
	assert_true(discarded.has("damage:faceup"))
	assert_true(discarded.has("damage:facedown"))
	assert_true(bool(result["destruction_cleanup"][
			"ship_phase_turn_terminated"]))
	assert_eq(_state.ship_phase_selection_controller, 1)
	assert_eq(_state.detected_terminal_reason(), "elimination")
	assert_ne(CommandProcessor.preflight(
			AdvancePhaseCommand.new(0, {}), _state), "")
	var projected: Dictionary = command.project_application_result(result, 1)
	assert_eq(_out_of_play_command().execute_with_application_result(
			passive, projected), projected)
	assert_true(passive.get_ship(0, 0).has_finalized_destruction())
	assert_eq(passive.get_ship(0, 0).get_total_damage(), 0)
	assert_eq(passive.passive_damage_ledger.discard_pile.size(), 2)
	assert_eq(passive.ship_phase_selection_controller, 1)
	assert_eq(passive.detected_terminal_reason(), "elimination")
	assert_true(passive.validate_for_passive_network_installation())
	var recovered: GameState = GameState.deserialize_passive_network(
			passive.serialize())
	assert_not_null(recovered)
	assert_true(recovered.validate_for_passive_network_installation())
	assert_eq(recovered.passive_damage_ledger.discard_pile.size(), 2)


func test_out_of_play_zero_card_passive_result_is_atomic_and_terminal() \
		-> void:
	_prepare_out_of_play_source(false)
	var opponent := ShipInstance.create_from_data(
			"cr90_corvette_a",
			AssetLoader.load_ship_data("cr90_corvette_a"), 1, 1)
	opponent.roster_entry_id = "opponent"
	_state.get_player_state(1).ships.append(opponent)
	var passive_data: Dictionary = StateFilter.filter_for_player(
			_state.serialize(), 1)
	assert_false(passive_data.is_empty())
	var passive: GameState = GameState.deserialize_passive_network(passive_data)
	assert_not_null(passive)
	var command: GameCommand = _out_of_play_command()
	var result: Dictionary = command.execute(_state)
	assert_true(bool(result.get("destroyed", false)))
	assert_eq(_state.detected_terminal_reason(), "elimination")
	var projected: Dictionary = command.project_application_result(result, 1)
	var mirror: GameCommand = _out_of_play_command()
	var malformed: Dictionary = projected.duplicate(true)
	malformed["destruction_cleanup"]["ship_phase_turn_terminated"] = false
	var before: Dictionary = passive.serialize()
	assert_true(mirror.execute_with_application_result(
			passive, malformed).is_empty())
	assert_eq(passive.serialize(), before)
	assert_eq(mirror.execute_with_application_result(passive, projected),
			projected)
	assert_true(passive.get_ship(0, 0).has_finalized_destruction())
	assert_eq(passive.ship_phase_selection_controller,
			_state.ship_phase_selection_controller)
	assert_eq(passive.detected_terminal_reason(), "elimination")
	assert_true(passive.validate_for_passive_network_installation())
	assert_true(mirror.execute_with_application_result(
			passive, projected).is_empty())


func test_out_of_play_final_ship_commits_cleanup_before_match_result() -> void:
	_prepare_out_of_play_source(false)
	var opponent := ShipInstance.create_from_data("cr90_corvette_a",
			AssetLoader.load_ship_data("cr90_corvette_a"), 1, 1)
	opponent.roster_entry_id = "opponent"
	_state.get_player_state(1).ships.append(opponent)
	GameManager.current_game_state = _state
	var processor: Node = PROCESSOR.new()
	add_child_autofree(processor)
	assert_false(processor.submit(_out_of_play_command()).is_empty())
	var types: Array[String] = []
	for command: GameCommand in processor.get_history():
		types.append(command.command_type)
	assert_eq(types, ["apply_maneuver_transform", "complete_match"])
	assert_true(_ship.has_finalized_destruction())
	assert_eq(_state.terminal_match_result["reason"], "elimination")
	assert_eq(_state.terminal_match_result["winner_index"], 1)
	assert_ne(CommandProcessor.preflight(
			AdvancePhaseCommand.new(0, {}), _state), "")


func _prepare_out_of_play_source(with_cards: bool) -> void:
	_ship.mark_destroyed()
	_ship = ShipInstance.create_from_data("cr90_corvette_a",
			AssetLoader.load_ship_data("cr90_corvette_a"), 0, 0)
	_ship.roster_entry_id = "candidate"
	_ship.pos_x = 0.001
	_ship.pos_y = 0.001
	_state.get_player_state(0).ships[0] = _ship
	_state.current_round = 2
	_state.ship_phase_selection_controller = 0
	assert_true(_state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	_state.damage_deck = DamageDeck.new()
	_state.damage_deck.initialize_for_save7()
	_state.rng = GameRng.new(41)
	if with_cards:
		var faceup := DamageCard.new()
		faceup.physical_card_id = "damage:faceup"
		faceup.public_card_ref = "faceup:before-maneuver"
		faceup.effect_id = "ordinary"
		faceup.title = "Faceup before Maneuver"
		faceup.trait_type = "Ship"
		faceup.timing = "persistent"
		faceup.is_faceup = true
		_ship.add_faceup_damage(faceup)
		var facedown := DamageCard.new()
		facedown.physical_card_id = "damage:facedown"
		facedown.effect_id = "ordinary"
		facedown.title = "Facedown before Maneuver"
		facedown.trait_type = "Ship"
		facedown.timing = "persistent"
		_ship.add_facedown_damage(facedown)
	assert_true(_ship.establish_ship_activation("ship-activation:oob"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:oob"))
	var commit := EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:oob",
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 73
	assert_false(commit.execute(_state).is_empty())


func _out_of_play_command() -> GameCommand:
	return APPLY.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:oob",
		"maneuver_execution_id": "maneuver:73",
	})


func _command() -> GameCommand:
	return APPLY.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"maneuver_execution_id": "maneuver:10",
	})


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data

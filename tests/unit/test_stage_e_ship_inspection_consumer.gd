## Stage E B-1: Ship activation cannot consume Counter I or J.
extends GutTest


const ACTIVATION_ID: String = "ship-activation:inspection-consumer"

var _previous_state: GameState
var _previous_mode: PlayMode.Mode
var _state: GameState
var _rejections: int = 0


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_previous_mode = PlayMode.current_mode
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	CommandProcessor.reset()
	AdvanceActivationStepCommand.register()
	_rejections = 0


func after_each() -> void:
	CommandProcessor.reset()
	GameManager.current_game_state = _previous_state
	PlayMode.set_mode(_previous_mode)


func test_counter_i_and_j_reject_all_ship_consumption_steps_direct_and_json() \
		-> void:
	for kind: String in ["counter_i", "counter_j"]:
		for step_id: String in ["maneuver_step", "attack_step",
				"activation_done"]:
			for json_command: bool in [false, true]:
				_reset_state(kind, step_id != "attack_step")
				_assert_rejected(_command(0, 0, step_id, json_command))


func test_counter_inspection_matching_id_cannot_cross_ship_or_source() -> void:
	for kind: String in ["counter_i", "counter_j"]:
		for json_command: bool in [false, true]:
			_reset_state(kind)
			_assert_rejected(_command(0, 1, "maneuver_step", json_command))
			_assert_rejected(_command(1, 0, "maneuver_step", json_command))
			var stale: GameCommand = _command(
					0, 0, "maneuver_step", json_command)
			stale.payload["completed_attack_inspection_id"] = \
					"completed:attack:wrong"
			_assert_rejected(stale)


func test_ordinary_ship_inspection_consumes_only_maneuver_direct_and_json() \
		-> void:
	for json_command: bool in [false, true]:
		_reset_state("ordinary")
		_assert_rejected(_command(0, 0, "attack_step", json_command))
		_assert_rejected(_command(0, 0, "activation_done", json_command))
		_assert_rejected(_command(1, 0, "maneuver_step", json_command))
		_assert_rejected(_command(0, 1, "maneuver_step", json_command))
		var command: GameCommand = _command(
				0, 0, "maneuver_step", json_command)
		var payload_before: Dictionary = command.payload.duplicate(true)
		var inspection_id: String = \
				_state.completed_attack_inspection.inspection_id()
		assert_eq(command.validate(_state), "")
		assert_false(CommandProcessor.submit(command).is_empty())
		assert_eq(command.payload, payload_before)
		assert_null(_state.completed_attack_inspection)
		assert_false(_state.get_ship(0, 0).attack_step_active)
		assert_eq(_state.get_ship(0, 0).maneuver_opportunity_disposition,
				ShipInstance.ACTIVATION_DISPOSITION_OPEN)
		assert_eq(CommandProcessor.get_command_count(), 1)
		assert_eq(CommandProcessor.get_history()[0].payload.get(
				"completed_attack_inspection_id"), inspection_id)


func _assert_rejected(command: GameCommand) -> void:
	assert_not_null(command)
	if command == null:
		return
	var before: Dictionary = _state.serialize()
	var flow: Dictionary = _state.interaction_flow.serialize()
	var inspection: Dictionary = \
			_state.completed_attack_inspection.serialize()
	var payload: Dictionary = command.payload.duplicate(true)
	var history: int = CommandProcessor.get_command_count()
	var sequence: int = CommandProcessor.get_next_sequence()
	var queue: int = CommandProcessor.get_pending_observer_followup_count()
	assert_true(CommandProcessor.submit(command).is_empty())
	_rejections += 1
	assert_engine_error(_rejections)
	assert_eq(_state.serialize(), before)
	assert_eq(_state.interaction_flow.serialize(), flow)
	assert_eq(_state.completed_attack_inspection.serialize(), inspection)
	assert_eq(command.payload, payload)
	assert_eq(CommandProcessor.get_command_count(), history)
	assert_eq(CommandProcessor.get_next_sequence(), sequence)
	assert_eq(CommandProcessor.get_pending_observer_followup_count(), queue)


func _command(player: int, ship_index: int, step_id: String,
		json_command: bool) -> GameCommand:
	var command := AdvanceActivationStepCommand.new(player, {
		"ship_index": ship_index,
		"step_id": step_id,
		"ship_activation_identity": ACTIVATION_ID,
		"completed_attack_inspection_id":
				_state.completed_attack_inspection.inspection_id(),
	})
	if not json_command:
		return command
	return GameCommand.deserialize(JSON.parse_string(
			JSON.stringify(command.serialize())) as Dictionary)


func _reset_state(kind: String, attack_step_active: bool = true) -> void:
	CommandProcessor.reset()
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	assert_true(_state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_two_human()))
	var ship_data := ShipData.new()
	ship_data.hull = 5
	ship_data.max_speed = 2
	ship_data.command_value = 2
	ship_data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	ship_data.defense_tokens = ["brace", "redirect"]
	ship_data.navigation_chart = [[1], [1, 1]]
	for player: int in [0, 1]:
		for index: int in [0, 1]:
			var ship: ShipInstance = ShipInstance.create_from_data(
					"inspection_ship", ship_data, 2, player)
			_state.get_player_state(player).ships.append(ship)
	var active: ShipInstance = _state.get_ship(0, 0)
	assert_true(active.establish_ship_activation(ACTIVATION_ID))
	if attack_step_active:
		active.begin_attack_step()
		active.commit_attack(int(Constants.HullZone.FRONT), 1,
				CurrentAttackState.KIND_SHIP, 0)
		active.commit_attack(int(Constants.HullZone.LEFT), 1,
				CurrentAttackState.KIND_SHIP, 0)
	for player: int in [0, 1]:
		var squadron := SquadronInstance.create_from_data(
				"x_wing_squadron",
				AssetLoader.load_squadron_data("x_wing_squadron"), player)
		_state.get_player_state(player).squadrons.append(squadron)
	var principals: Array[String] = \
			_state.get_distinct_controlling_principal_ids(
					MatchPlayerControlBinding.KIND_HUMAN)
	var counter: bool = kind != "ordinary"
	var inspection: CompletedAttackInspection = \
			CompletedAttackInspection.deserialize({
				"inspection_id": "completed:attack:inspection-test",
				"source_attack_id": "attack:inspection-test",
				"attacker": {"kind": CurrentAttackState.KIND_SQUADRON
						if counter else CurrentAttackState.KIND_SHIP,
					"player": 1 if kind == "counter_j" else 0,
					"index": 0, "zone": -1 if counter else 0},
				"defender": {"kind": CurrentAttackState.KIND_SQUADRON
						if counter else CurrentAttackState.KIND_SHIP,
					"player": 0 if kind == "counter_j" else 1,
					"index": 0, "zone": -1 if counter else 0},
				"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER
						if kind == "counter_j" else
						SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
				"dice_results": [],
				"outcome": {"target_kind": CurrentAttackState.KIND_SQUADRON,
					"requested_hull_damage": 0, "actual_hull_damage": 0,
					"post_resolution_hull": 3, "destroyed": false}
					if counter else
					{"target_kind": CurrentAttackState.KIND_SHIP,
					"affected_zone": 0, "final_damage": 0,
					"shield_absorbed": 0, "post_resolution_shields": 3,
					"hull_damage": 0, "destroyed": false},
				"required_principal_ids": principals,
				"received_principal_ids": principals,
				"counter_disposition": CurrentAttackState.COUNTER_ACCEPTED
						if kind == "counter_i" else
						CurrentAttackState.COUNTER_UNDECIDED,
			})
	assert_not_null(inspection)
	assert_true(_state.install_completed_attack_inspection(inspection))
	GameManager.current_game_state = _state

## Focused BUG-031 canonical Move-decline transaction regressions.
extends GutTest


const ACTIVATION_ID := "squadron-activation:bug-031"
const SHIP_ACTIVATION_ID := "ship-activation:bug-031"

var _saved_state: GameState
var _saved_active: bool
var _saved_submitter: CommandSubmitter


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager._submitter
	CommandProcessor.reset()
	GameManager.current_game_state = _make_state()
	GameManager.is_game_active = true
	GameManager.set_command_submitter(LocalCommandSubmitter.new())


func after_each() -> void:
	CommandProcessor.reset()
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)


func test_decline_consumes_inspection_and_records_one_terminal_completion() -> void:
	var state: GameState = GameManager.current_game_state
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var original := Vector2(squadron.pos_x, squadron.pos_y)
	var inspection: CompletedAttackInspection = _satisfied_inspection(state)
	assert_true(state.install_completed_attack_inspection(inspection))
	var result: Dictionary = CommandProcessor.submit(
			DeclineSquadronMoveCommand.new(0, _payload(inspection.inspection_id())))
	assert_eq(result.get("move_disposition", ""),
			SquadronInstance.MOVE_ACTION_DECLINED)
	assert_eq(_history_types().slice(0, 2), [
		DeclineSquadronMoveCommand.TYPE,
		CompleteSquadronActivationCommand.TYPE,
	])
	assert_eq(_history_types().count(DeclineSquadronMoveCommand.TYPE), 1)
	assert_eq(_history_types().count(
			CompleteSquadronActivationCommand.TYPE), 1)
	assert_false(state.has_completed_attack_inspection())
	assert_true(squadron.activated_this_round)
	assert_eq(squadron.move_action_disposition,
			SquadronInstance.MOVE_ACTION_DECLINED)
	assert_eq(Vector2(squadron.pos_x, squadron.pos_y), original,
			"Decline must never be represented by a movement mutation.")
	assert_eq(state.get_ship(0, 0).squadron_command_activations_committed, 1)


func test_stale_duplicate_and_wrong_player_declines_are_atomic() -> void:
	var state: GameState = GameManager.current_game_state
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var inspection: CompletedAttackInspection = _satisfied_inspection(state)
	assert_true(state.install_completed_attack_inspection(inspection))
	var stale: Dictionary = _payload("completed:stale")
	var stale_command := DeclineSquadronMoveCommand.new(0, stale)
	assert_ne(CommandProcessor.preflight(stale_command, state), "")
	assert_eq(squadron.move_action_disposition,
			SquadronInstance.MOVE_ACTION_AVAILABLE)
	assert_true(state.has_completed_attack_inspection())
	assert_eq(CommandProcessor.get_command_count(), 0)
	var wrong_player: Dictionary = _payload(inspection.inspection_id())
	var wrong_command := DeclineSquadronMoveCommand.new(1, wrong_player)
	assert_ne(wrong_command.validate(state), "")
	assert_eq(squadron.move_action_disposition,
			SquadronInstance.MOVE_ACTION_AVAILABLE)
	assert_true(state.has_completed_attack_inspection())
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_false(CommandProcessor.submit(
			DeclineSquadronMoveCommand.new(
					0, _payload(inspection.inspection_id()))).is_empty())
	assert_ne(DeclineSquadronMoveCommand.new(
			0, _payload("")).validate(state), "")
	assert_eq(_history_types().count(DeclineSquadronMoveCommand.TYPE), 1)


func test_declined_state_save_roundtrip_and_recorded_replay_converge() -> void:
	var initial: Dictionary = GameManager.current_game_state.serialize()
	assert_false(CommandProcessor.submit(
			DeclineSquadronMoveCommand.new(0, _payload(""))).is_empty())
	var authority: Dictionary = GameManager.current_game_state.serialize()
	var history: Array[Dictionary] = CommandProcessor.serialize_history()
	var restored: GameState = GameState.deserialize(authority)
	assert_not_null(restored)
	assert_eq(restored.get_squadron(0, 0).move_action_disposition,
			SquadronInstance.MOVE_ACTION_DECLINED)

	var replay_state: GameState = GameState.deserialize(initial)
	assert_not_null(replay_state)
	GameManager.current_game_state = replay_state
	CommandProcessor.reset()
	CommandProcessor.replay_commands(history)
	assert_eq(CanonicalJson.hash(replay_state.serialize()),
			CanonicalJson.hash(authority))
	assert_eq(CommandProcessor.get_command_count(), history.size())


func test_decline_leaves_remaining_attack_without_synthesizing_completion() -> void:
	var state: GameState = GameManager.current_game_state
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	squadron.attack_action_disposition = SquadronInstance.ATTACK_ACTION_AVAILABLE
	assert_false(CommandProcessor.submit(
			DeclineSquadronMoveCommand.new(0, _payload(""))).is_empty())
	assert_eq(_history_types(), [DeclineSquadronMoveCommand.TYPE])
	assert_false(squadron.activated_this_round)
	assert_true(squadron.has_remaining_attack_action(false))


func _make_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	var ship_key := "victory_ii_class_star_destroyer"
	var ship_data: ShipData = AssetLoader.load_ship_data(ship_key)
	var ship := ShipInstance.create_from_data(ship_key, ship_data, 1, 0)
	ship.roster_entry_id = "bug-031-ship-0"
	state.get_player_state(0).ships.append(ship)
	var dials: Array[int] = []
	for _index: int in range(ship_data.command_value):
		dials.append(Constants.CommandType.SQUADRON)
	ship.command_dial_stack.assign_dials(dials, 1)
	ship.command_dial_stack.reveal_top()
	assert_true(ship.establish_ship_activation(SHIP_ACTIVATION_ID))
	assert_true(ship.open_squadron_command_opportunity(SHIP_ACTIVATION_ID))

	for owner: int in [0, 1]:
		var squadron_key: String = "x_wing_squadron" \
				if owner == 0 else "tie_fighter_squadron"
		var squadron_data: SquadronData = \
				AssetLoader.load_squadron_data(squadron_key)
		var squadron := SquadronInstance.create_from_data(
				squadron_key, squadron_data, owner)
		squadron.roster_entry_id = "bug-031-squadron-%d" % owner
		squadron.pos_x = 0.25 + 0.5 * owner
		squadron.pos_y = 0.5
		state.get_player_state(owner).squadrons.append(squadron)
	var active: SquadronInstance = state.get_squadron(0, 0)
	assert_true(active.initialize_activation_action_state(
			ACTIVATION_ID,
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			0, 0))
	assert_true(ship.commit_squadron_command_activation(SHIP_ACTIVATION_ID))
	assert_true(active.commit_attack_action_begun(ACTIVATION_ID, false))
	return state


func _payload(inspection_id: String) -> Dictionary:
	return {
		"squadron_index": 0,
		"activation_id": ACTIVATION_ID,
		"activation_context":
				SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
		"completed_attack_inspection_id": inspection_id,
		"ship_activation_identity": SHIP_ACTIVATION_ID,
	}


func _satisfied_inspection(state: GameState) -> CompletedAttackInspection:
	var principal_id: String = state.principal_id_for_player(0)
	return CompletedAttackInspection.deserialize({
		"inspection_id": "completed:bug-031-attack",
		"source_attack_id": "bug-031-attack",
		"attacker": {"kind": "squadron", "player": 0, "index": 0,
			"zone": -1},
		"defender": {"kind": "squadron", "player": 1, "index": 0,
			"zone": -1},
		"attack_kind": "squadron_vs_squadron",
		"dice_results": [],
		"outcome": {"target_kind": "squadron", "destroyed": false,
			"requested_hull_damage": 0, "actual_hull_damage": 0,
			"post_resolution_hull": state.get_squadron(1, 0).current_hull},
		"required_principal_ids": [principal_id],
		"received_principal_ids": [principal_id],
	})


func _history_types() -> Array[String]:
	var result: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		result.append(command.command_type)
	return result

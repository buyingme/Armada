## Terminal scoring and presentation derive from an accepted canonical result.
extends GutTest


var _ended: Array[Dictionary] = []


func before_each() -> void:
	CommandProcessor.reset()
	_ended.clear()
	EventBus.game_ended.connect(_on_game_ended)


func after_each() -> void:
	EventBus.game_ended.disconnect(_on_game_ended)
	CommandProcessor.reset()
	GameManager.is_game_active = false
	GameManager.current_game_state = null


func test_all_ships_destroyed_ends_game_immediately() -> void:
	var state: GameState = _start_match(50, 60)
	state.get_ship(0, 0).mark_destroyed()
	assert_eq(state.detected_terminal_reason(), "elimination")
	assert_eq(_ended.size(), 0,
			"Destruction alone does not let presentation decide the outcome.")
	_commit_and_project(state)
	assert_eq(_ended.size(), 1)
	assert_eq(_ended[0]["winner_index"], 1)
	assert_eq(_ended[0]["reason"], "elimination")


func test_squadrons_alone_do_not_prevent_elimination() -> void:
	var state: GameState = _start_match(50, 60)
	var squadron := SquadronInstance.new()
	squadron.squadron_data = SquadronData.new()
	squadron.squadron_data.hull = 3
	squadron.current_hull = 3
	squadron.owner_player = 0
	state.get_player_state(0).squadrons.append(squadron)
	state.get_ship(0, 0).mark_destroyed()
	_commit_and_project(state)
	assert_eq(_ended[0]["reason"], "elimination")
	assert_eq(_ended[0]["winner_index"], 1)


func test_partial_destruction_game_continues() -> void:
	var state: GameState = _start_match(50, 60)
	state.get_player_state(0).ships.append(_ship(70, 4, 0, "survivor"))
	state.get_ship(0, 0).mark_destroyed()
	assert_eq(state.detected_terminal_reason(), "")
	assert_ne(CompleteMatchCommand.new(0, {}).validate(state), "")
	assert_true(GameManager.is_game_active)
	assert_true(_ended.is_empty())


func test_elimination_scores_computed() -> void:
	var state: GameState = _start_match(50, 60)
	var squadron := SquadronInstance.new()
	squadron.squadron_data = SquadronData.new()
	squadron.squadron_data.point_cost = 30
	squadron.squadron_data.hull = 3
	squadron.current_hull = 0
	squadron.owner_player = 1
	state.get_player_state(1).squadrons.append(squadron)
	state.get_ship(0, 0).mark_destroyed()
	_commit_and_project(state)
	assert_eq(_ended[0]["scores"], [30, 50])


func test_mutual_destruction_handled() -> void:
	var state: GameState = _start_match(50, 60)
	state.get_ship(0, 0).mark_destroyed()
	state.get_ship(1, 0).mark_destroyed()
	_commit_and_project(state)
	assert_eq(_ended[0]["reason"], "mutual_destruction")
	assert_eq(_ended[0]["winner_index"], 0)
	assert_eq(_ended[0]["scores"], [60, 50])


func test_round6_scoring_determines_winner() -> void:
	var state: GameState = _start_match(50, 73)
	state.get_player_state(1).ships.append(_ship(1, 4, 1, "survivor"))
	state.get_ship(1, 0).mark_destroyed()
	state.current_round = Constants.MAX_ROUNDS
	state.current_phase = Constants.GamePhase.STATUS
	state.final_status_cleanup_round = state.current_round
	assert_eq(state.detected_terminal_reason(), "round_6")
	_commit_and_project(state)
	assert_eq(_ended[0]["reason"], "round_6")
	assert_eq(_ended[0]["scores"], [73, 0])
	assert_eq(_ended[0]["winner_index"], 0)


func _start_match(cost_zero: int, cost_one: int) -> GameState:
	GameManager.start_new_game({
		"match_player_control_binding": MatchPlayerControlBinding \
				.create_hot_seat_human().serialize(),
	})
	var state: GameState = GameManager.current_game_state
	state.get_player_state(0).ships.append(_ship(cost_zero, 4, 0, "zero"))
	state.get_player_state(1).ships.append(_ship(cost_one, 4, 1, "one"))
	return state


func _ship(cost: int, hull: int, owner: int,
		roster_id: String) -> ShipInstance:
	var data := ShipData.new()
	data.point_cost = cost
	data.hull = hull
	var ship := ShipInstance.create_from_data(
			"terminal:%s" % roster_id, data, 1, owner)
	ship.roster_entry_id = roster_id
	return ship


func _commit_and_project(state: GameState) -> void:
	var command := CompleteMatchCommand.new(state.initiative_player, {})
	command.sequence = 100
	assert_eq(command.validate(state), "")
	assert_false(command.execute(state).is_empty())
	CommandProcessor.reset()
	GameManager.end_game()
	assert_false(GameManager.is_game_active)
	assert_eq(_ended, [state.terminal_match_result])


func _on_game_ended(details: Dictionary) -> void:
	_ended.append(details.duplicate(true))

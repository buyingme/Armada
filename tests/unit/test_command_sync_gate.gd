## Unit tests for CommandSyncGate — G4.4 Command Phase Sync Gate.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _gate: CommandSyncGate


func before_each() -> void:
	_gate = CommandSyncGate.new()


func _make_cmd_data(player: int, ship: int) -> Dictionary:
	return {"player_index": player, "command_type": "assign_dials",
			"payload": {"ship_index": ship, "commands": [0]}}


func _make_result(ship: int) -> Dictionary:
	return {"success": true, "ship_index": ship}


# ---------------------------------------------------------------------------
# §1  Activation lifecycle
# ---------------------------------------------------------------------------

func test_new_gate_is_inactive() -> void:
	assert_false(_gate.is_active(), "New gate is inactive")


func test_activate_makes_gate_active() -> void:
	_gate.activate()
	assert_true(_gate.is_active(), "Gate is active after activate()")


func test_deactivate_makes_gate_inactive() -> void:
	_gate.activate()
	_gate.deactivate()
	assert_false(_gate.is_active(), "Gate is inactive after deactivate()")


func test_activate_resets_state() -> void:
	_gate.activate()
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.mark_ready(0)
	_gate.activate()
	assert_eq(_gate.get_held_count(), 0, "Held results cleared on re-activate")
	assert_false(_gate.is_player_ready(0), "Player 0 not ready after re-activate")
	assert_false(_gate.is_player_ready(1), "Player 1 not ready after re-activate")


# ---------------------------------------------------------------------------
# §2  Holding results
# ---------------------------------------------------------------------------

func test_hold_adds_to_held_count() -> void:
	_gate.activate()
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	assert_eq(_gate.get_held_count(), 1, "One result held")


func test_hold_multiple_results() -> void:
	_gate.activate()
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.hold(_make_cmd_data(0, 1), _make_result(1))
	_gate.hold(_make_cmd_data(1, 0), _make_result(0))
	assert_eq(_gate.get_held_count(), 3, "Three results held")


# ---------------------------------------------------------------------------
# §3  Player readiness
# ---------------------------------------------------------------------------

func test_player_not_ready_by_default() -> void:
	_gate.activate()
	assert_false(_gate.is_player_ready(0), "Player 0 not ready by default")
	assert_false(_gate.is_player_ready(1), "Player 1 not ready by default")


func test_mark_ready_sets_player_ready() -> void:
	_gate.activate()
	_gate.mark_ready(0)
	assert_true(_gate.is_player_ready(0), "Player 0 marked ready")
	assert_false(_gate.is_player_ready(1), "Player 1 still not ready")


func test_mark_ready_invalid_index_no_crash() -> void:
	_gate.activate()
	_gate.mark_ready(-1)
	_gate.mark_ready(2)
	assert_false(_gate.is_player_ready(0), "No side-effect from invalid index")


# ---------------------------------------------------------------------------
# §4  Gate opening
# ---------------------------------------------------------------------------

func test_gate_not_open_when_inactive() -> void:
	assert_false(_gate.is_open(), "Inactive gate is not open")


func test_gate_not_open_with_one_player_ready() -> void:
	_gate.activate()
	_gate.mark_ready(0)
	assert_false(_gate.is_open(), "Gate not open with only player 0 ready")


func test_gate_opens_when_both_players_ready() -> void:
	_gate.activate()
	_gate.mark_ready(0)
	_gate.mark_ready(1)
	assert_true(_gate.is_open(), "Gate opens when both ready")


func test_gate_opens_regardless_of_order() -> void:
	_gate.activate()
	_gate.mark_ready(1)
	_gate.mark_ready(0)
	assert_true(_gate.is_open(), "Gate opens regardless of mark order")


# ---------------------------------------------------------------------------
# §5  Releasing held results
# ---------------------------------------------------------------------------

func test_release_returns_all_held_results_in_order() -> void:
	_gate.activate()
	var cmd0: Dictionary = _make_cmd_data(0, 0)
	var res0: Dictionary = _make_result(0)
	var cmd1: Dictionary = _make_cmd_data(0, 1)
	var res1: Dictionary = _make_result(1)
	var cmd2: Dictionary = _make_cmd_data(1, 0)
	var res2: Dictionary = _make_result(0)
	_gate.hold(cmd0, res0)
	_gate.hold(cmd1, res1)
	_gate.hold(cmd2, res2)
	_gate.mark_ready(0)
	_gate.mark_ready(1)
	var released: Array[Dictionary] = _gate.release()
	assert_eq(released.size(), 3, "All three results released")
	assert_eq(released[0]["command_data"], cmd0, "First result matches")
	assert_eq(released[1]["command_data"], cmd1, "Second result matches")
	assert_eq(released[2]["command_data"], cmd2, "Third result matches")


func test_release_deactivates_gate() -> void:
	_gate.activate()
	_gate.mark_ready(0)
	_gate.mark_ready(1)
	_gate.release()
	assert_false(_gate.is_active(), "Gate deactivated after release")


func test_release_clears_held_results() -> void:
	_gate.activate()
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.mark_ready(0)
	_gate.mark_ready(1)
	_gate.release()
	assert_eq(_gate.get_held_count(), 0, "No held results after release")


func test_release_returns_empty_when_nothing_held() -> void:
	_gate.activate()
	_gate.mark_ready(0)
	_gate.mark_ready(1)
	var released: Array[Dictionary] = _gate.release()
	assert_eq(released.size(), 0, "No results when nothing held")


# ---------------------------------------------------------------------------
# §6  Full scenario: two players, multiple ships
# ---------------------------------------------------------------------------

func test_full_scenario_two_players_three_ships() -> void:
	_gate.activate()
	# Player 0 has 2 ships
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.hold(_make_cmd_data(0, 1), _make_result(1))
	_gate.mark_ready(0)
	assert_false(_gate.is_open(), "Gate not open — player 1 pending")
	# Player 1 has 1 ship
	_gate.hold(_make_cmd_data(1, 0), _make_result(0))
	_gate.mark_ready(1)
	assert_true(_gate.is_open(), "Gate opens after player 1 ready")
	var released: Array[Dictionary] = _gate.release()
	assert_eq(released.size(), 3, "All three commands released")
	assert_false(_gate.is_active(), "Gate deactivated after release")


func test_full_scenario_player_1_finishes_first() -> void:
	_gate.activate()
	# Player 1 submits first
	_gate.hold(_make_cmd_data(1, 0), _make_result(0))
	_gate.mark_ready(1)
	assert_false(_gate.is_open(), "Gate not open — player 0 pending")
	# Player 0 submits after
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.mark_ready(0)
	assert_true(_gate.is_open(), "Gate opens")
	var released: Array[Dictionary] = _gate.release()
	assert_eq(released.size(), 2, "Both commands released")


# ---------------------------------------------------------------------------
# §7  Deactivate clears everything
# ---------------------------------------------------------------------------

func test_deactivate_clears_held_and_readiness() -> void:
	_gate.activate()
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.mark_ready(0)
	_gate.deactivate()
	assert_eq(_gate.get_held_count(), 0, "Held cleared")
	assert_false(_gate.is_player_ready(0), "Player 0 no longer ready")
	assert_false(_gate.is_player_ready(1), "Player 1 no longer ready")
	assert_false(_gate.is_open(), "Gate not open")


# ---------------------------------------------------------------------------
# §8  Edge: re-activation mid-flight
# ---------------------------------------------------------------------------

func test_reactivate_during_active_resets_cleanly() -> void:
	_gate.activate()
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.mark_ready(0)
	# Re-activate (e.g. round 2)
	_gate.activate()
	assert_false(_gate.is_player_ready(0), "Player 0 reset")
	assert_eq(_gate.get_held_count(), 0, "Held reset")
	# Normal flow continues
	_gate.hold(_make_cmd_data(0, 0), _make_result(0))
	_gate.hold(_make_cmd_data(1, 0), _make_result(0))
	_gate.mark_ready(0)
	_gate.mark_ready(1)
	assert_true(_gate.is_open(), "Gate opens after re-activation")
	assert_eq(_gate.release().size(), 2, "Correct held count")

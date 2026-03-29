## Test: Elimination Check — Integration
##
## Integration tests verifying that GameManager correctly ends the game
## when all of a player's ships are destroyed, and that scoring is computed.
## Rules Reference: GF-004, WN-001, GO-004.
extends GutTest


var _game_ended: bool = false
var _game_ended_details: Dictionary = {}


func before_each() -> void:
	_game_ended = false
	_game_ended_details = {}
	EventBus.game_ended.connect(_on_game_ended)


func after_each() -> void:
	if EventBus.game_ended.is_connected(_on_game_ended):
		EventBus.game_ended.disconnect(_on_game_ended)
	GameManager.is_game_active = false
	GameManager.current_game_state = null


func _on_game_ended(details: Dictionary) -> void:
	_game_ended = true
	_game_ended_details = details


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a stub ship token Node2D with a get_ship_instance() method.
func _make_ship_token(instance: ShipInstance) -> Node2D:
	var token: Node2D = Node2D.new()
	token.set_meta("ship_instance", instance)
	# Attach a getter script-style via a lambda isn't possible for typed
	# method calls from GDScript, so we use metadata + override approach.
	# Instead, create a real ShipToken stub using a script.
	token.set_script(_StubShipToken)
	token.set_meta("ship_instance", instance)
	add_child_autofree(token)
	return token


## Minimal stub that satisfies get_ship_instance().
var _StubShipToken: GDScript = GDScript.new()


func before_all() -> void:
	_StubShipToken = GDScript.new()
	_StubShipToken.source_code = """
extends Node2D

func get_ship_instance() -> RefCounted:
	return get_meta("ship_instance")
"""
	_StubShipToken.reload()


## Creates a minimal ShipInstance.
func _make_ship(cost: int, hull: int, owner: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.point_cost = cost
	data.hull = hull
	var si: ShipInstance = ShipInstance.new()
	si.ship_data = data
	si.current_hull = hull
	si.owner_player = owner
	return si


## Destroys a ship by filling it with facedown damage cards.
func _destroy_ship(si: ShipInstance) -> void:
	for i: int in range(si.ship_data.hull - si.facedown_damage.size()):
		si.facedown_damage.append(RefCounted.new())


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_all_ships_destroyed_ends_game_immediately() -> void:
	# Arrange — player 0 has one ship; player 1 has one ship.
	GameManager.start_new_game()
	var si0: ShipInstance = _make_ship(50, 4, 0)
	var si1: ShipInstance = _make_ship(60, 4, 1)
	GameManager.current_game_state.player_states[0].ships.append(si0)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Destroy player 0's only ship.
	_destroy_ship(si0)
	assert_true(si0.is_destroyed(), "Ship 0 should be destroyed")
	# Act — emit ship_destroyed signal (simulating attack_executor).
	var token: Node2D = _make_ship_token(si0)
	EventBus.ship_destroyed.emit(token)
	# Assert — game ended with player 1 winning.
	assert_true(_game_ended, "Game should end when all ships of a player destroyed")
	assert_eq(_game_ended_details.get("winner_index"), 1,
			"Opponent should win")
	assert_eq(_game_ended_details.get("reason"), "elimination",
			"Reason should be elimination")


func test_squadrons_alone_do_not_prevent_elimination() -> void:
	# Arrange — player 0 has one ship (destroyed) + one squadron (alive).
	GameManager.start_new_game()
	var si0: ShipInstance = _make_ship(50, 4, 0)
	_destroy_ship(si0)
	var sq0: SquadronInstance = SquadronInstance.new()
	sq0.squadron_data = SquadronData.new()
	sq0.squadron_data.hull = 3
	sq0.current_hull = 3
	sq0.owner_player = 0
	GameManager.current_game_state.player_states[0].ships.append(si0)
	GameManager.current_game_state.player_states[0].squadrons.append(sq0)
	var si1: ShipInstance = _make_ship(60, 4, 1)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Act
	var token: Node2D = _make_ship_token(si0)
	EventBus.ship_destroyed.emit(token)
	# Assert
	assert_true(_game_ended,
			"Game should still end — squadrons don't prevent elimination")


func test_partial_destruction_game_continues() -> void:
	# Arrange — player 0 has two ships, only one destroyed.
	GameManager.start_new_game()
	var si0a: ShipInstance = _make_ship(50, 4, 0)
	var si0b: ShipInstance = _make_ship(60, 4, 0)
	_destroy_ship(si0a)
	GameManager.current_game_state.player_states[0].ships.append(si0a)
	GameManager.current_game_state.player_states[0].ships.append(si0b)
	# Act
	var token: Node2D = _make_ship_token(si0a)
	EventBus.ship_destroyed.emit(token)
	# Assert
	assert_false(_game_ended,
			"Game should NOT end — player 0 still has a ship")
	assert_true(GameManager.is_game_active, "Game should remain active")


func test_elimination_scores_computed() -> void:
	# Arrange — player 0 eliminated. Player 0 had destroyed a 30-point
	# enemy squadron before dying.
	GameManager.start_new_game()
	var si0: ShipInstance = _make_ship(50, 4, 0)
	_destroy_ship(si0)
	GameManager.current_game_state.player_states[0].ships.append(si0)
	var si1: ShipInstance = _make_ship(60, 4, 1)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Player 1 lost a squadron.
	var sq1: SquadronInstance = SquadronInstance.new()
	sq1.squadron_data = SquadronData.new()
	sq1.squadron_data.point_cost = 30
	sq1.squadron_data.hull = 3
	sq1.current_hull = 0 # destroyed
	sq1.owner_player = 1
	GameManager.current_game_state.player_states[1].squadrons.append(sq1)
	# Act
	var token: Node2D = _make_ship_token(si0)
	EventBus.ship_destroyed.emit(token)
	# Assert — scores should be computed.
	assert_true(_game_ended, "Game should end")
	var scores: Array = _game_ended_details.get("scores", [])
	assert_eq(scores[0], 30, "Player 0 scored enemy destroyed squadron (30)")
	assert_eq(scores[1], 50, "Player 1 scored eliminated enemy ship (50)")


func test_mutual_destruction_handled() -> void:
	# Arrange — both players have exactly 1 ship, both destroyed.
	GameManager.start_new_game()
	var si0: ShipInstance = _make_ship(50, 4, 0)
	var si1: ShipInstance = _make_ship(60, 4, 1)
	_destroy_ship(si0)
	_destroy_ship(si1)
	GameManager.current_game_state.player_states[0].ships.append(si0)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Act — ship destroyed triggers elimination check.
	var token: Node2D = _make_ship_token(si0)
	EventBus.ship_destroyed.emit(token)
	# Assert
	assert_true(_game_ended, "Game should end on mutual destruction")
	assert_eq(_game_ended_details.get("reason"), "mutual_destruction",
			"Reason should be mutual_destruction")
	# Player 0 scores 60, player 1 scores 50 → player 0 wins.
	assert_eq(_game_ended_details.get("winner_index"), 0,
			"Higher scorer wins mutual destruction")


func test_round6_scoring_determines_winner() -> void:
	# Arrange — play through 6 rounds with some destroyed units.
	GameManager.start_new_game()
	var si0: ShipInstance = _make_ship(50, 4, 0)
	var si1: ShipInstance = _make_ship(73, 4, 1)
	_destroy_ship(si1) # Player 1's ship destroyed.
	GameManager.current_game_state.player_states[0].ships.append(si0)
	GameManager.current_game_state.player_states[1].ships.append(si1)
	# Fast-forward to round 6 end.
	for round_num: int in range(6):
		if GameManager.is_game_active:
			GameManager.advance_phase() # → SHIP
		if GameManager.is_game_active:
			GameManager.advance_phase() # → cascade → COMMAND (next round)
	# Assert
	assert_true(_game_ended, "Game should end after round 6")
	assert_eq(_game_ended_details.get("reason"), "round_6",
			"Reason should be round_6")
	assert_eq(_game_ended_details.get("scores", [])[0], 73,
			"Player 0 scored enemy destroyed ship (73)")
	assert_eq(_game_ended_details.get("scores", [])[1], 0,
			"Player 1 scored nothing")
	assert_eq(_game_ended_details.get("winner_index"), 0,
			"Player 0 should win with higher score")

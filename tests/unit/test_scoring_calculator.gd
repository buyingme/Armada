## Test: Scoring Calculator
##
## Unit tests for ScoringCalculator — fleet-point scoring and winner
## determination logic.
## Rules Reference: "Scoring", RRG p.15; "Winning and Losing", RRG p.21;
## WN-001–004.
extends GutTest


var _calc: ScoringCalculator = null


func before_each() -> void:
	_calc = ScoringCalculator.new()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a minimal GameState with two players and the given ship/squadron
## configurations.  Each entry in [param p0_ships] / [param p1_ships] is a
## Dictionary with keys "cost" (int) and "destroyed" (bool).
## Same for squadron arrays but with "cost" and "destroyed".
func _make_state(
		p0_ships: Array = [],
		p1_ships: Array = [],
		p0_squads: Array = [],
		p1_squads: Array = [],
		initiative: int = 0) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.initiative_player = initiative
	# Player 0 ships.
	for cfg: Dictionary in p0_ships:
		var si: ShipInstance = _make_ship(cfg.get("cost", 0),
				cfg.get("destroyed", false), 0)
		state.player_states[0].ships.append(si)
	# Player 1 ships.
	for cfg: Dictionary in p1_ships:
		var si: ShipInstance = _make_ship(cfg.get("cost", 0),
				cfg.get("destroyed", false), 1)
		state.player_states[1].ships.append(si)
	# Player 0 squadrons.
	for cfg: Dictionary in p0_squads:
		var sq: SquadronInstance = _make_squadron(cfg.get("cost", 0),
				cfg.get("destroyed", false), 0)
		state.player_states[0].squadrons.append(sq)
	# Player 1 squadrons.
	for cfg: Dictionary in p1_squads:
		var sq: SquadronInstance = _make_squadron(cfg.get("cost", 0),
				cfg.get("destroyed", false), 1)
		state.player_states[1].squadrons.append(sq)
	return state


## Creates a minimal ShipInstance with the given point cost and destruction
## state.  Uses a stub ShipData.
func _make_ship(cost: int, destroyed: bool, owner: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.point_cost = cost
	data.hull = 4
	var si: ShipInstance = ShipInstance.new()
	si.ship_data = data
	si.current_hull = data.hull
	si.owner_player = owner
	if destroyed:
		# Deal enough facedown damage to destroy.
		for i: int in range(data.hull):
			si.facedown_damage.append(RefCounted.new())
	return si


## Creates a minimal SquadronInstance with the given point cost and
## destruction state.
func _make_squadron(
		cost: int, destroyed: bool, owner: int) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.point_cost = cost
	data.hull = 3
	var sq: SquadronInstance = SquadronInstance.new()
	sq.squadron_data = data
	sq.current_hull = data.hull
	sq.owner_player = owner
	if destroyed:
		sq.current_hull = 0
	return sq


# ---------------------------------------------------------------------------
# calculate_score tests
# ---------------------------------------------------------------------------

func test_score_destroyed_enemy_ship() -> void:
	# Arrange — player 1 has one ship (cost 73), destroyed.
	var state: GameState = _make_state(
			[], [{"cost": 73, "destroyed": true}])
	# Act — player 0 scores.
	var score: int = _calc.calculate_score(0, state)
	# Assert
	assert_eq(score, 73, "Should score the destroyed enemy ship's cost")


func test_score_destroyed_enemy_squadron() -> void:
	# Arrange — player 1 has one squadron (cost 12), destroyed.
	var state: GameState = _make_state(
			[], [], [], [{"cost": 12, "destroyed": true}])
	# Act
	var score: int = _calc.calculate_score(0, state)
	# Assert
	assert_eq(score, 12, "Should score the destroyed enemy squadron's cost")


func test_score_mixed_destroyed() -> void:
	# Arrange — player 1 has 1 destroyed ship (57) + 1 destroyed squad (11)
	# + 1 alive ship (44) + 1 alive squad (12).
	var state: GameState = _make_state(
			[],
			[{"cost": 57, "destroyed": true}, {"cost": 44, "destroyed": false}],
			[],
			[{"cost": 11, "destroyed": true}, {"cost": 12, "destroyed": false}])
	# Act
	var score: int = _calc.calculate_score(0, state)
	# Assert
	assert_eq(score, 68,
			"Should sum only destroyed enemy ships + squadrons (57+11)")


func test_score_no_destroyed_returns_zero() -> void:
	# Arrange — all units alive.
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": false}],
			[{"cost": 60, "destroyed": false}])
	# Act
	var score: int = _calc.calculate_score(0, state)
	# Assert
	assert_eq(score, 0, "No destroyed enemies → score 0")


func test_score_symmetric() -> void:
	# Arrange — each player destroyed one enemy ship.
	var state: GameState = _make_state(
			[{"cost": 30, "destroyed": true}],
			[{"cost": 50, "destroyed": true}])
	# Act
	var score_0: int = _calc.calculate_score(0, state)
	var score_1: int = _calc.calculate_score(1, state)
	# Assert
	assert_eq(score_0, 50, "Player 0 scores player 1's destroyed ship")
	assert_eq(score_1, 30, "Player 1 scores player 0's destroyed ship")


# ---------------------------------------------------------------------------
# is_fleet_eliminated tests
# ---------------------------------------------------------------------------

func test_all_ships_destroyed_is_eliminated() -> void:
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": true}], [])
	assert_true(_calc.is_fleet_eliminated(0, state),
			"All ships destroyed → eliminated")


func test_squadrons_alone_no_elimination() -> void:
	# All ships destroyed, but squadrons remain.
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": true}], [],
			[{"cost": 12, "destroyed": false}], [])
	assert_true(_calc.is_fleet_eliminated(0, state),
			"Surviving squadrons alone do not prevent elimination")


func test_partial_destruction_not_eliminated() -> void:
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": true},
			 {"cost": 60, "destroyed": false}], [])
	assert_false(_calc.is_fleet_eliminated(0, state),
			"At least one ship alive → not eliminated")


func test_no_ships_not_eliminated() -> void:
	# Edge case: player has no ships at all (shouldn't happen, but defensive).
	var state: GameState = _make_state([], [])
	assert_false(_calc.is_fleet_eliminated(0, state),
			"Empty fleet is not considered eliminated")


# ---------------------------------------------------------------------------
# determine_winner tests
# ---------------------------------------------------------------------------

func test_elimination_winner_is_opponent() -> void:
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": true}],
			[{"cost": 60, "destroyed": false}])
	var result: Dictionary = _calc.determine_winner(state, "elimination", 0)
	assert_eq(result["winner_index"], 1,
			"Opponent of eliminated player wins")
	assert_eq(result["reason"], "elimination",
			"Reason should be elimination")


func test_round6_higher_score_wins() -> void:
	# Player 0 destroyed more of player 1's fleet.
	var state: GameState = _make_state(
			[{"cost": 30, "destroyed": false}],
			[{"cost": 60, "destroyed": true}])
	var result: Dictionary = _calc.determine_winner(state, "round_6")
	assert_eq(result["winner_index"], 0,
			"Higher score wins after round 6")
	assert_eq(result["scores"][0], 60, "Player 0 scored 60")
	assert_eq(result["scores"][1], 0, "Player 1 scored 0")


func test_tiebreaker_second_player_wins() -> void:
	# Both players scored equally. Initiative player is 0, so second is 1.
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": true}],
			[{"cost": 50, "destroyed": true}],
			[], [], 0)
	var result: Dictionary = _calc.determine_winner(state, "round_6")
	assert_eq(result["winner_index"], 1,
			"Tied scores → second player (non-initiative) wins (WN-004)")


func test_mutual_destruction_higher_score_wins() -> void:
	# Both fleets wiped. Player 0's fleet was worth more.
	var state: GameState = _make_state(
			[{"cost": 30, "destroyed": true}],
			[{"cost": 60, "destroyed": true}],
			[{"cost": 10, "destroyed": true}],
			[{"cost": 5, "destroyed": true}])
	# Player 0 scores: 60 (ship) + 5 (squad) = 65.
	# Player 1 scores: 30 (ship) + 10 (squad) = 40.
	var result: Dictionary = _calc.determine_winner(
			state, "mutual_destruction")
	assert_eq(result["winner_index"], 0,
			"Higher scorer wins mutual destruction")
	assert_eq(result["scores"][0], 65, "Player 0 scored 65")
	assert_eq(result["scores"][1], 40, "Player 1 scored 40")


func test_mutual_destruction_tie_second_player_wins() -> void:
	# Both fleets wiped, equal scores.
	var state: GameState = _make_state(
			[{"cost": 50, "destroyed": true}],
			[{"cost": 50, "destroyed": true}],
			[], [], 0)
	var result: Dictionary = _calc.determine_winner(
			state, "mutual_destruction")
	assert_eq(result["winner_index"], 1,
			"Tied mutual destruction → second player wins")

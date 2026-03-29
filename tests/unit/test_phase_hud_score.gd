## Test: Phase HUD Score Display
##
## Verifies that the phase HUD label correctly includes live scores
## for both players alongside round and phase information.
## The HUD format is: "Round N — Phase  |  Rebel: X  |  Imperial: Y"
## Requirements: GF-001–004, UI-003.
extends GutTest


var _scoring: ScoringCalculator = null


func before_each() -> void:
	_scoring = ScoringCalculator.new()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Re-creates the HUD text formatting logic from game_board._update_phase_hud()
## so we can unit-test the format string without the full scene tree.
func _format_hud_text(
		round_num: int,
		phase_name: String,
		state: GameState) -> String:
	var base_text: String = ""
	if round_num > 0:
		base_text = "Round %d — %s" % [round_num, phase_name]
	else:
		base_text = phase_name
	if state != null:
		var rebel_score: int = _scoring.calculate_score(0, state)
		var imperial_score: int = _scoring.calculate_score(1, state)
		base_text += "  |  Rebel: %d  |  Imperial: %d" % [
				rebel_score, imperial_score]
	return base_text


## Creates a minimal GameState with optional destroyed ships.
func _make_state(
		p0_ships: Array = [],
		p1_ships: Array = []) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	for cfg: Dictionary in p0_ships:
		var si: ShipInstance = _make_ship(
				cfg.get("cost", 0), cfg.get("destroyed", false), 0)
		state.player_states[0].ships.append(si)
	for cfg: Dictionary in p1_ships:
		var si: ShipInstance = _make_ship(
				cfg.get("cost", 0), cfg.get("destroyed", false), 1)
		state.player_states[1].ships.append(si)
	return state


## Creates a minimal ShipInstance with the given point cost and state.
func _make_ship(cost: int, destroyed: bool, owner: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.point_cost = cost
	data.hull = 4
	var si: ShipInstance = ShipInstance.new()
	si.ship_data = data
	si.current_hull = data.hull
	si.owner_player = owner
	if destroyed:
		for i: int in range(data.hull):
			si.facedown_damage.append(RefCounted.new())
	return si


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## Verifies the HUD shows zero scores when no ships are destroyed.
func test_hud_shows_zero_scores_no_destruction() -> void:
	# Arrange.
	var state: GameState = _make_state(
			[{"cost": 50}], [{"cost": 60}])
	# Act.
	var text: String = _format_hud_text(2, "Ship Phase", state)
	# Assert.
	assert_eq(text, "Round 2 — Ship Phase  |  Rebel: 0  |  Imperial: 0",
			"HUD should show zero scores when no ships destroyed")


## Verifies the HUD shows the correct score when a ship is destroyed.
func test_hud_shows_score_after_destruction() -> void:
	# Arrange — Imperial ship (cost 73) destroyed.
	var state: GameState = _make_state(
			[{"cost": 50}],
			[{"cost": 73, "destroyed": true}])
	# Act.
	var text: String = _format_hud_text(3, "Ship Phase", state)
	# Assert.
	assert_eq(text, "Round 3 — Ship Phase  |  Rebel: 73  |  Imperial: 0",
			"Rebel score should reflect destroyed Imperial ship cost")


## Verifies both players can have non-zero scores simultaneously.
func test_hud_shows_both_player_scores() -> void:
	# Arrange — Rebel ship (cost 40) destroyed, Imperial ship (cost 55) also.
	var state: GameState = _make_state(
			[{"cost": 40, "destroyed": true}],
			[{"cost": 55, "destroyed": true}])
	# Act.
	var text: String = _format_hud_text(4, "Squadron Phase", state)
	# Assert.
	assert_eq(text,
			"Round 4 — Squadron Phase  |  Rebel: 55  |  Imperial: 40",
			"Both factions should show enemy fleet points scored")


## Verifies the setup phase (round 0) shows only the phase name and scores.
func test_hud_setup_phase_format() -> void:
	# Arrange.
	var state: GameState = _make_state()
	# Act.
	var text: String = _format_hud_text(0, "Setup", state)
	# Assert.
	assert_eq(text, "Setup  |  Rebel: 0  |  Imperial: 0",
			"Setup phase should omit 'Round 0' prefix")


## Verifies the HUD falls back to base text when game state is null.
func test_hud_no_state_omits_scores() -> void:
	# Act.
	var text: String = _format_hud_text(1, "Command Phase", null)
	# Assert.
	assert_eq(text, "Round 1 — Command Phase",
			"HUD should omit score suffix when state is null")

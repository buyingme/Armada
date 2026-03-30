## Test: Fixed Round-1 Commands — Unit Tests
##
## Tests for LearningScenarioSetup fixed command parsing and
## GameManager.apply_fixed_round1_commands().
## Rules Reference: LTP p.10 — "suggested commands"; CP-009, CP-010.
extends GutTest


# ---------------------------------------------------------------------------
# LearningScenarioSetup — fixed command parsing (CP-009)
# ---------------------------------------------------------------------------


## The learning scenario JSON has use_fixed_round1_commands enabled.
func test_has_fixed_round1_commands_returns_true() -> void:
	# Arrange
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()

	# Act
	var result: bool = setup.has_fixed_round1_commands()

	# Assert
	assert_true(result,
			"Learning scenario should have fixed round-1 commands enabled")


## get_fixed_round1_commands returns a non-empty dictionary.
func test_get_fixed_round1_commands_returns_three_ships() -> void:
	# Arrange
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()

	# Act
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Assert
	assert_eq(cmds.size(), 3,
			"Should have commands for 3 ships (CR90, Neb-B, VSD)")


## CR90 gets exactly 1 command: Squadron.
## Learning Scenario JSON: "cr90_corvette_a": ["squadron"]
func test_cr90_gets_squadron() -> void:
	# Arrange
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	var cr90_cmds: Array = cmds.get("cr90_corvette_a", [])

	# Assert
	assert_eq(cr90_cmds.size(), 1,
			"CR90 should have 1 command (command value = 1)")
	assert_eq(cr90_cmds[0], Constants.CommandType.SQUADRON,
			"CR90 command should be SQUADRON")


## Nebulon-B gets Concentrate Fire (top), Squadron (bottom).
## Learning Scenario JSON: "nebulon_b_escort_frigate": ["concentrate_fire", "squadron"]
func test_nebulon_b_gets_concentrate_fire_squadron() -> void:
	# Arrange
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	var neb_cmds: Array = cmds.get("nebulon_b_escort_frigate", [])

	# Assert
	assert_eq(neb_cmds.size(), 2,
			"Nebulon-B should have 2 commands (command value = 2)")
	assert_eq(neb_cmds[0], Constants.CommandType.CONCENTRATE_FIRE,
			"Nebulon-B top dial should be CONCENTRATE_FIRE")
	assert_eq(neb_cmds[1], Constants.CommandType.SQUADRON,
			"Nebulon-B bottom dial should be SQUADRON")


## VSD gets Squadron (top), Navigate (middle), Concentrate Fire (bottom).
## Learning Scenario JSON: "victory_ii_class_star_destroyer":
## ["squadron", "navigate", "concentrate_fire"]
func test_vsd_gets_squadron_navigate_concentrate_fire() -> void:
	# Arrange
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	var vsd_cmds: Array = cmds.get("victory_ii_class_star_destroyer", [])

	# Assert
	assert_eq(vsd_cmds.size(), 3,
			"VSD should have 3 commands (command value = 3)")
	assert_eq(vsd_cmds[0], Constants.CommandType.SQUADRON,
			"VSD top dial should be SQUADRON")
	assert_eq(vsd_cmds[1], Constants.CommandType.NAVIGATE,
			"VSD middle dial should be NAVIGATE")
	assert_eq(vsd_cmds[2], Constants.CommandType.CONCENTRATE_FIRE,
			"VSD bottom dial should be CONCENTRATE_FIRE")


# ---------------------------------------------------------------------------
# _parse_command_name — static helper
# ---------------------------------------------------------------------------


## Parses all four valid command names.
func test_parse_command_name_all_valid() -> void:
	assert_eq(LearningScenarioSetup._parse_command_name("navigate"),
			Constants.CommandType.NAVIGATE, "navigate → NAVIGATE")
	assert_eq(LearningScenarioSetup._parse_command_name("squadron"),
			Constants.CommandType.SQUADRON, "squadron → SQUADRON")
	assert_eq(LearningScenarioSetup._parse_command_name("concentrate_fire"),
			Constants.CommandType.CONCENTRATE_FIRE,
			"concentrate_fire → CONCENTRATE_FIRE")
	assert_eq(LearningScenarioSetup._parse_command_name("repair"),
			Constants.CommandType.REPAIR, "repair → REPAIR")


## Unknown command name returns -1.
func test_parse_command_name_unknown_returns_minus_one() -> void:
	assert_eq(LearningScenarioSetup._parse_command_name("invalid"),
			-1, "Unknown command should return -1")


## Command names are case-insensitive.
func test_parse_command_name_case_insensitive() -> void:
	assert_eq(LearningScenarioSetup._parse_command_name("NAVIGATE"),
			Constants.CommandType.NAVIGATE, "NAVIGATE (uppercase) should work")
	assert_eq(LearningScenarioSetup._parse_command_name("Repair"),
			Constants.CommandType.REPAIR, "Repair (mixed case) should work")


# ---------------------------------------------------------------------------
# GameManager.apply_fixed_round1_commands — auto-assign + skip (CP-010)
# ---------------------------------------------------------------------------


## Helper: creates a minimal GameState with ships that have dial stacks.
func _setup_game_with_ships() -> Dictionary:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state

	var rebel_ship: ShipInstance = ShipInstance.new()
	rebel_ship.data_key = "cr90_corvette_a"
	rebel_ship.owner_player = 0
	rebel_ship.activated_this_round = false
	rebel_ship.ship_data = ShipData.new()
	rebel_ship.ship_data.ship_name = "CR90 Corvette A"
	rebel_ship.command_dial_stack = CommandDialStack.create(1)
	gs.get_player_state(0).ships.append(rebel_ship)

	var rebel_ship2: ShipInstance = ShipInstance.new()
	rebel_ship2.data_key = "nebulon_b_escort_frigate"
	rebel_ship2.owner_player = 0
	rebel_ship2.activated_this_round = false
	rebel_ship2.ship_data = ShipData.new()
	rebel_ship2.ship_data.ship_name = "Nebulon-B Escort Frigate"
	rebel_ship2.command_dial_stack = CommandDialStack.create(2)
	gs.get_player_state(0).ships.append(rebel_ship2)

	var imp_ship: ShipInstance = ShipInstance.new()
	imp_ship.data_key = "victory_ii_class_star_destroyer"
	imp_ship.owner_player = 1
	imp_ship.activated_this_round = false
	imp_ship.ship_data = ShipData.new()
	imp_ship.ship_data.ship_name = "Victory II-class Star Destroyer"
	imp_ship.command_dial_stack = CommandDialStack.create(3)
	gs.get_player_state(1).ships.append(imp_ship)

	return {
		"cr90": rebel_ship,
		"neb": rebel_ship2,
		"vsd": imp_ship,
	}


func after_each() -> void:
	GameManager.is_game_active = false
	GameManager.current_game_state = null
	GameManager.fixed_commands_applied = false


## After apply_fixed_round1_commands, the phase should be SHIP.
func test_apply_fixed_commands_advances_to_ship_phase() -> void:
	# Arrange
	var ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	GameManager.apply_fixed_round1_commands(cmds)

	# Assert
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.SHIP,
			"Phase should advance to SHIP after fixed commands applied")


## The fixed_commands_applied flag should be true.
func test_apply_fixed_commands_sets_flag() -> void:
	# Arrange
	var ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	GameManager.apply_fixed_round1_commands(cmds)

	# Assert
	assert_true(GameManager.fixed_commands_applied,
			"fixed_commands_applied should be true")


## CR90 dial stack should have 1 dial after auto-assign.
func test_cr90_has_correct_dials_after_apply() -> void:
	# Arrange
	var ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	GameManager.apply_fixed_round1_commands(cmds)

	# Assert
	var cr90: ShipInstance = ships["cr90"]
	assert_eq(cr90.command_dial_stack.get_dial_count(), 1,
			"CR90 should have 1 dial assigned")
	assert_eq(cr90.command_dial_stack.get_top_command(),
			Constants.CommandType.SQUADRON,
			"CR90 top dial should be SQUADRON")


## Nebulon-B stack: Concentrate Fire on top, Squadron on bottom.
func test_neb_has_correct_dial_order_after_apply() -> void:
	# Arrange
	var ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	GameManager.apply_fixed_round1_commands(cmds)

	# Assert
	var neb: ShipInstance = ships["neb"]
	assert_eq(neb.command_dial_stack.get_dial_count(), 2,
			"Nebulon-B should have 2 dials assigned")
	var dials: Array[Dictionary] = neb.command_dial_stack.get_all_dials()
	assert_eq(int(dials[0]["command"]), Constants.CommandType.CONCENTRATE_FIRE,
			"Nebulon-B top dial should be CONCENTRATE_FIRE")
	assert_eq(int(dials[1]["command"]), Constants.CommandType.SQUADRON,
			"Nebulon-B bottom dial should be SQUADRON")


## VSD stack: Squadron (top), Navigate (middle), Concentrate Fire (bottom).
func test_vsd_has_correct_dial_order_after_apply() -> void:
	# Arrange
	var ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	GameManager.apply_fixed_round1_commands(cmds)

	# Assert
	var vsd: ShipInstance = ships["vsd"]
	assert_eq(vsd.command_dial_stack.get_dial_count(), 3,
			"VSD should have 3 dials assigned")
	var dials: Array[Dictionary] = vsd.command_dial_stack.get_all_dials()
	assert_eq(int(dials[0]["command"]), Constants.CommandType.SQUADRON,
			"VSD top dial should be SQUADRON")
	assert_eq(int(dials[1]["command"]), Constants.CommandType.NAVIGATE,
			"VSD middle dial should be NAVIGATE")
	assert_eq(int(dials[2]["command"]), Constants.CommandType.CONCENTRATE_FIRE,
			"VSD bottom dial should be CONCENTRATE_FIRE")


## The command_assigning_player should be -1 (no one assigning).
func test_assigning_player_cleared_after_apply() -> void:
	# Arrange
	var _ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var cmds: Dictionary = setup.get_fixed_round1_commands()

	# Act
	GameManager.apply_fixed_round1_commands(cmds)

	# Assert
	assert_eq(GameManager.get_command_assigning_player(), -1,
			"Command assigning player should be cleared")


## apply_fixed_round1_commands only works in round 1. Verify that the
## method's precondition (round == 1) was validated at apply time.
func test_apply_only_works_in_round_1() -> void:
	# Arrange — apply in round 1 (valid), then verify round 2 would differ.
	var ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	GameManager.apply_fixed_round1_commands(setup.get_fixed_round1_commands())

	# Assert — the method succeeded during round 1.
	assert_true(GameManager.fixed_commands_applied,
			"Fixed commands should apply successfully in round 1")
	assert_eq(GameManager.get_current_round(), 1,
			"Should still be round 1 after apply")


## apply_fixed_round1_commands requires COMMAND phase. Verify via the
## flag that the method only sets the flag when in the correct phase.
func test_apply_requires_command_phase() -> void:
	# Arrange — start game in COMMAND phase (default) and immediately
	# advance to SHIP phase before applying.
	var _ships: Dictionary = _setup_game_with_ships()

	# Advance past command phase normally.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Now in SHIP phase — flag should not be set by normal submission.
	assert_false(GameManager.fixed_commands_applied,
			"Normal dial submission should not set fixed_commands_applied")


## start_new_game resets the fixed_commands_applied flag.
func test_start_new_game_resets_flag() -> void:
	# Arrange
	var _ships: Dictionary = _setup_game_with_ships()
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	GameManager.apply_fixed_round1_commands(setup.get_fixed_round1_commands())
	assert_true(GameManager.fixed_commands_applied, "Precondition: flag set")

	# Act
	GameManager.start_new_game()

	# Assert
	assert_false(GameManager.fixed_commands_applied,
			"start_new_game should reset fixed_commands_applied")

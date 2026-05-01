## Tests for G2 Tier 2 attack command subclasses.
##
## Covers: RollDiceCommand, SpendDefenseTokenCommand,
## SelectRedirectZoneCommand, SkipAttackCommand.
## Each command is tested for validate (happy + rejection), execute,
## and serialize/deserialize roundtrip.
extends GutTest


var _state: GameState


## Creates a minimal ShipData with defense tokens and shields.
func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace", "redirect", "evade"]
	data.navigation_chart = [[1], [1, 1]]
	return data


## Creates a ShipInstance and adds it to the given player's fleet.
## Returns the ship index.
func _add_ship(player: int) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	# Register command types.
	RollDiceCommand.register()
	SpendDefenseTokenCommand.register()
	SelectRedirectZoneCommand.register()
	SkipAttackCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("roll_dice")
	GameCommand._registry.erase("spend_defense_token")
	GameCommand._registry.erase("select_redirect_zone")
	GameCommand._registry.erase("skip_attack")


# ======================================================================
# RollDiceCommand
# ======================================================================

func test_roll_dice_validate_ok() -> void:
	var cmd := RollDiceCommand.new(0, {
		"dice_pool": {"red": 2, "blue": 1},
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid dice pool in Ship Phase.")


func test_roll_dice_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := RollDiceCommand.new(0, {
		"dice_pool": {"red": 1},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")


func test_roll_dice_validate_ok_squadron_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := RollDiceCommand.new(0, {
		"dice_pool": {"blue": 1},
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid dice pool in Squadron Phase.")


func test_roll_dice_validate_empty_pool() -> void:
	var cmd := RollDiceCommand.new(0, {
		"dice_pool": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject empty dice pool.")


func test_roll_dice_validate_no_pool_key() -> void:
	var cmd := RollDiceCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing dice_pool key.")


func test_roll_dice_execute_returns_results() -> void:
	var cmd := RollDiceCommand.new(0, {
		"dice_pool": {"red": 1, "blue": 2},
	})
	var result: Dictionary = cmd.execute(_state)
	var results: Array = result.get("dice_results", [])
	assert_eq(results.size(), 3,
			"Should return 3 dice results (1 red + 2 blue).")
	for r: Dictionary in results:
		assert_has(r, "color", "Each result should have 'color'.")
		assert_has(r, "face", "Each result should have 'face'.")


func test_roll_dice_execute_deterministic_with_rng() -> void:
	_state.rng = GameRng.new(42)
	var cmd1 := RollDiceCommand.new(0, {
		"dice_pool": {"red": 2, "black": 1},
	})
	var result1: Dictionary = cmd1.execute(_state)
	# Re-create state with same seed.
	_state.rng = GameRng.new(42)
	var cmd2 := RollDiceCommand.new(0, {
		"dice_pool": {"red": 2, "black": 1},
	})
	var result2: Dictionary = cmd2.execute(_state)
	assert_eq(result1["dice_results"].size(), result2["dice_results"].size(),
			"Both rolls should have same count.")
	for i: int in range(result1["dice_results"].size()):
		assert_eq(result1["dice_results"][i]["face"],
				result2["dice_results"][i]["face"],
				"Dice face %d should be identical with same seed." % i)


func test_roll_dice_serialize_roundtrip() -> void:
	var cmd := RollDiceCommand.new(0, {
		"dice_pool": {"red": 3},
	})
	cmd.sequence = 10
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "roll_dice",
			"Restored type should match.")
	assert_eq(restored.player_index, 0,
			"Restored player should match.")
	assert_eq(restored.sequence, 10,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("dice_pool", {}), {"red": 3},
			"Restored dice_pool should match.")


# ======================================================================
# SpendDefenseTokenCommand
# ======================================================================

func test_spend_defense_token_validate_ok_exhaust() -> void:
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept exhausting a READY token.")


func test_spend_defense_token_validate_ok_discard() -> void:
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "discard",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept discarding a READY token.")


func test_spend_defense_token_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")


func test_spend_defense_token_validate_ok_squadron_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept spending defense token in Squadron Phase.")


func test_spend_defense_token_validate_bad_ship() -> void:
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": 99,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_spend_defense_token_validate_bad_token_index() -> void:
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 99,
		"spend_method": "exhaust",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject out-of-range token index.")


func test_spend_defense_token_validate_already_discarded() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.DISCARDED
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject already-discarded token.")


func test_spend_defense_token_validate_invalid_method() -> void:
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "invalid",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid spend method.")


func test_spend_defense_token_execute_exhaust() -> void:
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	var result: Dictionary = cmd.execute(_state)
	var ship: ShipInstance = _state.get_ship(1, idx)
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Token should be EXHAUSTED after exhaust.")
	assert_eq(result.get("spend_method", ""), "exhaust",
			"Result should report exhaust method.")
	assert_eq(result.get("token_type", -1),
			Constants.DefenseToken.BRACE,
			"Result should report correct token type.")


func test_spend_defense_token_execute_discard() -> void:
	var idx: int = _add_ship(1)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 1,
		"spend_method": "discard",
	})
	var result: Dictionary = cmd.execute(_state)
	var ship: ShipInstance = _state.get_ship(1, idx)
	assert_eq(ship.defense_tokens[1]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Token should be DISCARDED after discard.")
	assert_eq(result.get("spend_method", ""), "discard",
			"Result should report discard method.")
	assert_eq(result.get("token_type", -1),
			Constants.DefenseToken.REDIRECT,
			"Result should report correct token type.")


func test_spend_defense_token_execute_exhaust_already_exhausted() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.defense_tokens[2]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": idx,
		"token_index": 2,
		"spend_method": "exhaust",
	})
	# Exhausting an already-exhausted token is a no-op in ShipInstance;
	# the token stays EXHAUSTED.
	cmd.execute(_state)
	assert_eq(ship.defense_tokens[2]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Token should remain EXHAUSTED.")


func test_spend_defense_token_serialize_roundtrip() -> void:
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 2,
		"spend_method": "discard",
	})
	cmd.sequence = 7
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "spend_defense_token",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match.")
	assert_eq(restored.sequence, 7,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("spend_method", ""), "discard",
			"Restored spend_method should match.")


# ======================================================================
# SelectRedirectZoneCommand
# ======================================================================

func test_redirect_zone_validate_ok() -> void:
	var idx: int = _add_ship(1)
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.LEFT,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid redirect zone selection.")


func test_redirect_zone_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(1)
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.FRONT,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")


func test_redirect_zone_validate_ok_squadron_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_ship(1)
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.LEFT,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept redirect zone in Squadron Phase.")


func test_redirect_zone_validate_bad_ship() -> void:
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": 99,
		"zone": Constants.HullZone.LEFT,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_redirect_zone_validate_bad_zone() -> void:
	var idx: int = _add_ship(1)
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": - 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid hull zone.")


func test_redirect_zone_execute_reduces_shields() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	assert_eq(int(ship.current_shields.get("LEFT", 0)), 2,
			"LEFT shields should start at 2.")
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.LEFT,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("shields_reduced", 0), 1,
			"Should reduce 1 shield.")
	assert_eq(result.get("new_shields", -1), 1,
			"LEFT shields should be 1 after redirect.")
	assert_eq(int(ship.current_shields.get("LEFT", 0)), 1,
			"Ship current_shields should reflect reduction.")


func test_redirect_zone_execute_at_zero_shields() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.current_shields["REAR"] = 0
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.REAR,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("shields_reduced", -1), 0,
			"Should reduce 0 when shields already at 0.")
	assert_eq(result.get("new_shields", -1), 0,
			"Shields should remain at 0.")


func test_redirect_zone_execute_multiple_redirects() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	assert_eq(int(ship.current_shields.get("RIGHT", 0)), 2,
			"RIGHT shields should start at 2.")
	# First redirect.
	var cmd1 := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.RIGHT,
	})
	cmd1.execute(_state)
	# Second redirect.
	var cmd2 := SelectRedirectZoneCommand.new(1, {
		"ship_index": idx,
		"zone": Constants.HullZone.RIGHT,
	})
	var result: Dictionary = cmd2.execute(_state)
	assert_eq(result.get("new_shields", -1), 0,
			"RIGHT shields should be 0 after two redirects.")


func test_redirect_zone_serialize_roundtrip() -> void:
	var cmd := SelectRedirectZoneCommand.new(1, {
		"ship_index": 0,
		"zone": Constants.HullZone.RIGHT,
	})
	cmd.sequence = 3
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "select_redirect_zone",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match.")
	assert_eq(restored.sequence, 3,
			"Restored sequence should match.")


# ======================================================================
# SkipAttackCommand
# ======================================================================

func test_skip_attack_validate_ok() -> void:
	var cmd := SkipAttackCommand.new(0, {"reason": "voluntary"})
	assert_eq(cmd.validate(_state), "",
			"Should accept skip in Ship Phase.")


func test_skip_attack_validate_ok_no_reason() -> void:
	var cmd := SkipAttackCommand.new(0, {})
	assert_eq(cmd.validate(_state), "",
			"Should accept skip with no explicit reason.")


func test_skip_attack_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := SkipAttackCommand.new(0, {"reason": "voluntary"})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")


func test_skip_attack_validate_ok_squadron_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := SkipAttackCommand.new(0, {"reason": "voluntary"})
	assert_eq(cmd.validate(_state), "",
			"Should accept skip in Squadron Phase.")


func test_skip_attack_execute_returns_skip() -> void:
	var cmd := SkipAttackCommand.new(0, {"reason": "no_targets"})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("skipped", false),
			"Execute should return skipped=true.")
	assert_eq(result.get("reason", ""), "no_targets",
			"Execute should return the skip reason.")


func test_skip_attack_execute_default_reason() -> void:
	var cmd := SkipAttackCommand.new(0, {})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("reason", ""), "voluntary",
			"Default reason should be 'voluntary'.")


func test_skip_attack_serialize_roundtrip() -> void:
	var cmd := SkipAttackCommand.new(0, {"reason": "squadron_done"})
	cmd.sequence = 15
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "skip_attack",
			"Restored type should match.")
	assert_eq(restored.player_index, 0,
			"Restored player should match.")
	assert_eq(restored.sequence, 15,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("reason", ""), "squadron_done",
			"Restored reason should match.")


# ======================================================================
# CommitDefenseCommand (Phase I6b-3 R2)
# ======================================================================

func test_commit_defense_validate_ok_empty() -> void:
	var idx: int = _add_ship(1)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": idx,
		"selected_indices": [],
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept empty selection (= spend nothing).")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_validate_ok_with_indices() -> void:
	var idx: int = _add_ship(1)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": idx,
		"selected_indices": [0, 2],
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid token indices.")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	var idx: int = _add_ship(1)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": idx,
		"selected_indices": [],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_validate_bad_ship() -> void:
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": 99,
		"selected_indices": [],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_validate_bad_token_index() -> void:
	var idx: int = _add_ship(1)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": idx,
		"selected_indices": [0, 99],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject out-of-range token index.")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_execute_echoes_indices() -> void:
	var idx: int = _add_ship(1)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": idx,
		"selected_indices": [0, 2],
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("ship_index", -1), idx,
			"Result should echo ship_index.")
	var echoed: Array = result.get("selected_indices", []) as Array
	assert_eq(echoed.size(), 2,
			"Result should echo two selected indices.")
	assert_eq(int(echoed[0]), 0,
			"Result should preserve order of indices.")
	assert_eq(int(echoed[1]), 2,
			"Result should preserve order of indices.")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_serialize_roundtrip() -> void:
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [1, 0, 2],
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "commit_defense",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match defender.")
	assert_eq(restored.sequence, 42,
			"Restored sequence should match.")
	var indices: Array = restored.payload.get(
			"selected_indices", []) as Array
	assert_eq(indices.size(), 3,
			"Restored selected_indices should preserve length.")
	GameCommand._registry.erase("commit_defense")


# ======================================================================
# SelectEvadeDieCommand (Phase I6b-3 R3)
# ======================================================================

func test_select_evade_die_validate_ok() -> void:
	var idx: int = _add_ship(1)
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"ship_index": idx,
		"die_index": 2,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid ship + die index.")
	GameCommand._registry.erase("select_evade_die")


func test_select_evade_die_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	var idx: int = _add_ship(1)
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"ship_index": idx,
		"die_index": 0,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")
	GameCommand._registry.erase("select_evade_die")


func test_select_evade_die_validate_bad_ship() -> void:
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"ship_index": 99,
		"die_index": 0,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")
	GameCommand._registry.erase("select_evade_die")


func test_select_evade_die_validate_bad_die_index() -> void:
	var idx: int = _add_ship(1)
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"ship_index": idx,
		"die_index": - 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject negative die index.")
	GameCommand._registry.erase("select_evade_die")


func test_select_evade_die_execute_echoes_index() -> void:
	var idx: int = _add_ship(1)
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"ship_index": idx,
		"die_index": 3,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(int(result.get("ship_index", -1)), idx,
			"Result should echo ship_index.")
	assert_eq(int(result.get("die_index", -1)), 3,
			"Result should echo die_index.")
	GameCommand._registry.erase("select_evade_die")


func test_select_evade_die_serialize_roundtrip() -> void:
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"ship_index": 0,
		"die_index": 4,
	})
	cmd.sequence = 99
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "select_evade_die",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match defender.")
	assert_eq(restored.sequence, 99,
			"Restored sequence should match.")
	assert_eq(int(restored.payload.get("die_index", -1)), 4,
			"Restored die_index should match.")
	GameCommand._registry.erase("select_evade_die")


# ======================================================================
# RedirectDoneCommand (Phase I6b-3 R4)
# ======================================================================

func test_redirect_done_validate_ok() -> void:
	var idx: int = _add_ship(1)
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {"ship_index": idx})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid ship in Ship Phase.")
	GameCommand._registry.erase("redirect_done")


func test_redirect_done_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	var idx: int = _add_ship(1)
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")
	GameCommand._registry.erase("redirect_done")


func test_redirect_done_validate_bad_ship() -> void:
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {"ship_index": 99})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")
	GameCommand._registry.erase("redirect_done")


func test_redirect_done_execute_echoes_ship_index() -> void:
	var idx: int = _add_ship(1)
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(int(result.get("ship_index", -1)), idx,
			"Result should echo ship_index.")
	GameCommand._registry.erase("redirect_done")


func test_redirect_done_serialize_roundtrip() -> void:
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {"ship_index": 0})
	cmd.sequence = 77
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "redirect_done",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match defender.")
	assert_eq(restored.sequence, 77,
			"Restored sequence should match.")
	GameCommand._registry.erase("redirect_done")

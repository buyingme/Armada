## Tests for G2 Tier 2 attack command subclasses.
##
## Covers: RollDiceCommand, SpendDefenseTokenCommand,
## SelectRedirectZoneCommand, SkipAttackCommand.
## Each command is tested for validate (happy + rejection), execute,
## and serialize/deserialize roundtrip.
extends GutTest


const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")


var _state: GameState
var _remote_log_path: String = "user://logs/_test_remote_command_effects.log"


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
	GameLogger.disable_file_logging()
	_remove_remote_log()
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
	GameLogger.disable_file_logging()
	_remove_remote_log()


# ======================================================================
# RollDiceCommand
# ======================================================================

func test_roll_dice_validate_ok() -> void:
	_install_roll_attack({"RED": 2, "BLUE": 1})
	var cmd := RollDiceCommand.new(0, {
		"attack_id": _attack_id(),
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
	_install_roll_attack({"BLUE": 1})
	var cmd := RollDiceCommand.new(0, {
		"attack_id": _attack_id(),
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
	_install_roll_attack({"RED": 1, "BLUE": 2})
	var cmd := RollDiceCommand.new(0, {
		"attack_id": _attack_id(),
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
	_install_roll_attack({"RED": 2, "BLACK": 1})
	var cmd1 := RollDiceCommand.new(0, {
		"attack_id": _attack_id(),
	})
	var result1: Dictionary = cmd1.execute(_state)
	# Re-create state with same seed.
	_state.rng = GameRng.new(42)
	_install_roll_attack({"RED": 2, "BLACK": 1})
	var cmd2 := RollDiceCommand.new(0, {
		"attack_id": _attack_id(),
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
	_install_defense_attack(idx, [0])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 0,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
		"spend_method": "exhaust",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept exhausting a READY token.")


func test_spend_defense_token_validate_ok_discard() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [0])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 0,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
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
	_install_defense_attack(idx, [0])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 0,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
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


func test_spend_defense_token_rejects_out_of_order_commit() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [2, 0])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 0,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
		"spend_method": "exhaust",
	})
	assert_ne(cmd.validate(_state), "",
			"Only the next unresolved committed token may be spent.")


func test_spend_defense_token_requires_discard_for_exhausted_token() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_install_defense_attack(idx, [0])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 0,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
		"spend_method": "exhaust",
	})
	assert_ne(cmd.validate(_state), "",
			"An exhausted token's authoritative spend method is discard.")


func test_spend_defense_token_execute_exhaust() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [0])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 0,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
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
	_install_defense_attack(idx, [1])
	var cmd := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"expected_token_type": int(Constants.DefenseToken.REDIRECT),
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
	_install_defense_attack(idx, [1])
	var cmd := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"zone": Constants.HullZone.LEFT,
		"expected_shields": 2,
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
	_install_defense_attack(idx, [1])
	var cmd := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"zone": Constants.HullZone.LEFT,
		"expected_shields": 2,
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
	_install_defense_attack(idx, [1])
	assert_eq(int(ship.current_shields.get("LEFT", 0)), 2,
			"LEFT shields should start at 2.")
	var cmd := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"zone": Constants.HullZone.LEFT,
		"expected_shields": 2,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("shields_reduced", 0), 1,
			"Should reduce 1 shield.")
	assert_eq(result.get("new_shields", -1), 1,
			"LEFT shields should be 1 after redirect.")
	assert_eq(int(ship.current_shields.get("LEFT", 0)), 1,
			"Ship current_shields should reflect reduction.")


func test_redirect_zone_validate_rejects_zero_shields() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.current_shields["REAR"] = 0
	_install_defense_attack(idx, [1], Constants.HullZone.LEFT)
	var cmd := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"zone": Constants.HullZone.REAR,
		"expected_shields": 0,
	})
	assert_ne(cmd.validate(_state), "",
			"Redirect cannot select a hull zone with no shields.")


func test_redirect_zone_execute_multiple_redirects() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	_install_defense_attack(idx, [1])
	assert_eq(int(ship.current_shields.get("RIGHT", 0)), 2,
			"RIGHT shields should start at 2.")
	# First redirect.
	var cmd1 := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"zone": Constants.HullZone.RIGHT,
		"expected_shields": 2,
	})
	cmd1.execute(_state)
	# Second redirect.
	var cmd2 := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
		"zone": Constants.HullZone.RIGHT,
		"expected_shields": 1,
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
	var cmd := SkipAttackCommand.new(0, {
		"reason": "squadron_done",
		"ship_index": 2,
	})
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
	assert_eq(restored.payload.get("ship_index", -1), 2,
			"Stable Step 6 attacker identity should round-trip.")


func test_squadron_done_skip_closes_iteration_and_retains_second_attack() -> void:
	var ship_index: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, ship_index)
	ship.begin_attack_step()
	ship.commit_attack(Constants.HullZone.FRONT, 1,
			CurrentAttackState.KIND_SQUADRON, 0)
	var cmd := SkipAttackCommand.new(0, {
		"reason": "squadron_done",
		"ship_index": ship_index,
	})
	assert_eq(cmd.validate(_state), "")
	var result: Dictionary = cmd.execute(_state)

	assert_eq(result.get("continuation", ""),
			CompleteAttackCommand.CONTINUATION_NORMAL_ATTACK)
	assert_eq(ship.anti_squadron_attack_zone, -1)
	assert_true(ship.anti_squadron_target_history.is_empty())
	assert_eq(ship.committed_attack_count, 1)
	assert_eq(ship.used_attack_hull_zones,
			[int(Constants.HullZone.FRONT)])


func test_squadron_done_skip_requires_authoritative_iteration_identity() -> void:
	var ship_index: int = _add_ship(0)
	var cmd := SkipAttackCommand.new(0, {
		"reason": "squadron_done",
		"ship_index": ship_index,
	})
	assert_ne(cmd.validate(_state), "")


func test_active_skip_no_longer_accepts_flow_replaced_reason() -> void:
	assert_false(SkipAttackCommand.TERMINAL_REASONS.has("flow_replaced"))


# ======================================================================
# CommitDefenseCommand (Phase I6b-3 R2)
# ======================================================================

func test_commit_defense_validate_ok_empty() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [], Constants.HullZone.FRONT,
			CurrentAttackState.DEFENSE_PENDING)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"selected_indices": [],
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept empty selection (= spend nothing).")
	GameCommand._registry.erase("commit_defense")


func test_commit_defense_validate_ok_with_indices() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [], Constants.HullZone.FRONT,
			CurrentAttackState.DEFENSE_PENDING)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"selected_indices": [2, 0],
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


func test_commit_defense_rejects_speed_zero_selection() -> void:
	var idx: int = _add_ship(1)
	_state.get_ship(1, idx).current_speed = 0
	_install_defense_attack(idx, [], Constants.HullZone.FRONT,
			CurrentAttackState.DEFENSE_PENDING)
	var cmd := CommitDefenseCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"selected_indices": [0],
	})
	assert_ne(cmd.validate(_state), "",
			"A speed-0 defender cannot commit token spends.")


func test_commit_defense_rejects_duplicate_token_type() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.defense_tokens.append({
		"type": int(Constants.DefenseToken.BRACE),
		"state": int(Constants.DefenseTokenState.READY),
	})
	_install_defense_attack(idx, [], Constants.HullZone.FRONT,
			CurrentAttackState.DEFENSE_PENDING)
	var cmd := CommitDefenseCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"selected_indices": [0, 3],
	})
	assert_ne(cmd.validate(_state), "",
			"Only one defense token of a type may be committed.")


func test_commit_defense_execute_echoes_indices() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [], Constants.HullZone.FRONT,
			CurrentAttackState.DEFENSE_PENDING)
	CommitDefenseCommand.register()
	var cmd := CommitDefenseCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"selected_indices": [2, 0],
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("ship_index", -1), idx,
			"Result should echo ship_index.")
	var echoed: Array = result.get("selected_indices", []) as Array
	assert_eq(echoed.size(), 2,
			"Result should echo two selected indices.")
	assert_eq(int(echoed[0]), 2,
			"Result should preserve canonical order of indices.")
	assert_eq(int(echoed[1]), 0,
			"Result should preserve canonical order of indices.")
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
	_install_defense_attack(idx, [2])
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 2,
		"die_index": 2,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.HIT),
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
	_install_defense_attack(idx, [2])
	SelectEvadeDieCommand.register()
	var cmd := SelectEvadeDieCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 2,
		"die_index": 3,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.HIT),
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


func test_remote_select_evade_die_effect_is_handled_noop() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [2])
	var cmd := SelectEvadeDieCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 2,
		"die_index": 3,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.HIT),
	})
	var content: String = _capture_remote_effect_log(
			cmd, cmd.execute(_state))
	assert_false(content.contains(
			"Unhandled remote command type: select_evade_die"),
			"select_evade_die should not fall through to unhandled remote warning.")


# ======================================================================
# RedirectDoneCommand (Phase I6b-3 R4)
# ======================================================================

func test_redirect_done_validate_ok() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [1])
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
	})
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
	_install_defense_attack(idx, [1])
	RedirectDoneCommand.register()
	var cmd := RedirectDoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
	})
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


func test_remote_redirect_done_effect_is_handled_noop() -> void:
	var idx: int = _add_ship(1)
	_install_defense_attack(idx, [1])
	var cmd := RedirectDoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": idx,
		"token_index": 1,
	})
	var content: String = _capture_remote_effect_log(
			cmd, cmd.execute(_state))
	assert_false(content.contains(
			"Unhandled remote command type: redirect_done"),
			"redirect_done should not fall through to unhandled remote warning.")


func _capture_remote_effect_log(cmd: GameCommand, result: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute("user://logs")
	_remove_remote_log()
	var previous_log_level: int = GameLogger.min_level
	var previous_file_level: int = GameLogger.min_file_level
	GameLogger.disable_file_logging()
	GameLogger.min_level = GameLogger.Level.ERROR + 1
	GameLogger.min_file_level = GameLogger.Level.DEBUG
	assert_true(GameLogger.enable_file_logging(_remote_log_path),
			"Remote command-effect log capture should enable file logging.")
	GameManager._handle_remote_command_effects(cmd, result)
	GameLogger.disable_file_logging()
	GameLogger.min_level = previous_log_level
	GameLogger.min_file_level = previous_file_level
	if not FileAccess.file_exists(_remote_log_path):
		return ""
	return FileAccess.get_file_as_string(_remote_log_path)


func _remove_remote_log() -> void:
	if FileAccess.file_exists(_remote_log_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
				_remote_log_path))


func _install_roll_attack(pool: Dictionary) -> void:
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(_state, {
		"dice_pool": pool,
	}), "Roll fixture should install a pre-roll current attack.")


func _install_defense_attack(defender_index: int,
		committed: Array[int],
		defender_zone: int = Constants.HullZone.FRONT,
		defense_stage: String = CurrentAttackState.DEFENSE_RESOLVING) -> void:
	var dice_results: Array[Dictionary] = []
	for _index: int in range(5):
		dice_results.append({
			"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT),
		})
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(_state, {
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defender_player": 1,
		"defender_index": defender_index,
		"defender_zone": defender_zone,
		"dice_results": dice_results,
		"defense_stage": defense_stage,
		"committed_defense_tokens": committed,
	}), "Defense fixture should install canonical attack state.")


func _attack_id() -> String:
	return _state.current_attack_state.attack_id

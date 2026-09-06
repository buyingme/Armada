## Unit tests for StateFilter — G4.3 Information Hiding.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers — build minimal serialised snapshots
# ---------------------------------------------------------------------------

func _make_dial(command: int, round_num: int, state: String) -> Dictionary:
	return {"command": command, "round": round_num, "state": state}


func _make_ship(owner: int, hidden_dials: int = 0, revealed_dials: int = 0,
		facedown: int = 0, faceup: int = 0) -> Dictionary:
	var data_key := "cr90_corvette_a"
	var ship_data: ShipData = AssetLoader.load_ship_data(data_key)
	var instance: ShipInstance = ShipInstance.create_from_data(
			data_key, ship_data, 2, owner)
	instance.roster_entry_id = "ship-%d" % owner
	instance.pos_x = 0.5
	instance.pos_y = 0.3
	instance.rotation_deg = 90.0
	var dials: Array[Dictionary] = []
	for i: int in hidden_dials:
		dials.append(_make_dial(i % 4, 1, CommandDialStack.STATE_HIDDEN))
	for i: int in revealed_dials:
		dials.append(_make_dial(i % 4, 1, CommandDialStack.STATE_REVEALED))

	var fd_cards: Array[Dictionary] = []
	for i: int in facedown:
		fd_cards.append({"trait_type": "structural", "title": "Structural Damage",
				"is_faceup": false, "effect_text": "", "timing": "", "effect_id": ""})
	var fu_cards: Array[Dictionary] = []
	for i: int in faceup:
		fu_cards.append({"trait_type": "crew", "title": "Injured Crew",
				"is_faceup": true, "effect_text": "effect", "timing": "", "effect_id": ""})

	var result: Dictionary = instance.serialize()
	result["facedown_damage"] = fd_cards
	result["faceup_damage"] = fu_cards
	result["command_dial_stack"] = {
			"command_value": 1,
			"dials": dials,
			"spent_history": [],
	}
	return result


func _make_squadron(owner: int) -> Dictionary:
	var key := "x_wing_squadron"
	var instance: SquadronInstance = SquadronInstance.create_from_data(
			key, AssetLoader.load_squadron_data(key), owner)
	instance.roster_entry_id = "squadron-%d" % owner
	instance.pos_x = 0.6
	instance.pos_y = 0.4
	return instance.serialize()


func _make_player_state(player_index: int, ships: Array[Dictionary] = [],
		squads: Array[Dictionary] = []) -> Dictionary:
	return {
		"player_index": player_index,
		"faction": 0,
		"fleet_points": 400,
		"score": 0,
		"ships": ships,
		"squadrons": squads,
	}


func _make_game_state(p0_ships: Array[Dictionary] = [],
		p1_ships: Array[Dictionary] = [],
		draw_pile_size: int = 33, discard_size: int = 0) -> Dictionary:
	var draw: Array[Dictionary] = []
	for i: int in draw_pile_size:
		draw.append({"trait_type": "structural", "title": "Structural Damage",
				"is_faceup": false, "effect_text": "", "timing": "", "effect_id": ""})
	var discard: Array[Dictionary] = []
	for i: int in discard_size:
		discard.append({"trait_type": "crew", "title": "Injured Crew",
				"is_faceup": true, "effect_text": "effect", "timing": "", "effect_id": ""})
	var state := GameState.new()
	state.rng = GameRng.new(42)
	state.initialize()
	state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human())
	state.current_round = 1
	state.current_phase = Constants.GamePhase.COMMAND
	var result: Dictionary = state.serialize()
	result["player_states"] = [
		_make_player_state(0, p0_ships),
		_make_player_state(1, p1_ships),
	]
	result["damage_deck"] = {"draw_pile": draw, "discard_pile": discard}
	return result


# ---------------------------------------------------------------------------
# §1  RNG stripping
# ---------------------------------------------------------------------------

func test_filter_strips_rng_for_player_0() -> void:
	var state: Dictionary = _make_game_state()
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	assert_false(filtered.has("rng"), "Filtered state must not contain RNG")


func test_filter_strips_rng_for_player_1() -> void:
	var state: Dictionary = _make_game_state()
	var filtered: Dictionary = StateFilter.filter_for_player(state, 1)
	assert_false(filtered.has("rng"), "Filtered state must not contain RNG")


# ---------------------------------------------------------------------------
# §2  Damage deck filtering
# ---------------------------------------------------------------------------

func test_filter_replaces_draw_pile_with_count() -> void:
	var state: Dictionary = _make_game_state([], [], 33, 2)
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	assert_false(filtered.has("damage_deck"), "authority deck must be stripped")
	var ledger: Dictionary = filtered["passive_damage_ledger"]
	assert_eq(ledger["draw_count"], 33, "draw_count must equal original draw_pile size")


func test_filter_preserves_discard_pile() -> void:
	var state: Dictionary = _make_game_state([], [], 30, 3)
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var ledger: Dictionary = filtered["passive_damage_ledger"]
	assert_eq(ledger["discard_pile"].size(), 3, "discard_pile must be kept")


func test_filter_handles_empty_damage_deck() -> void:
	var state: Dictionary = _make_game_state()
	state["damage_deck"] = {}
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	assert_true(filtered.is_empty(), "Malformed authority deck must reject")


# ---------------------------------------------------------------------------
# §3  Owner's state is preserved fully
# ---------------------------------------------------------------------------

func test_filter_hides_own_facedown_damage_and_preserves_own_dials() -> void:
	var ship: Dictionary = _make_ship(0, 2, 1, 3, 1)
	var state: Dictionary = _make_game_state([ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var own_ship: Dictionary = filtered["player_states"][0]["ships"][0]
	assert_false(own_ship.has("facedown_damage"), "Owner must not see facedown identities")
	assert_eq(own_ship["facedown_count"], 3, "Owner sees only facedown count")
	var dials: Array = own_ship["command_dial_stack"]["dials"]
	assert_eq(dials.size(), 3, "Owner sees all dials")
	for dial: Dictionary in dials:
		assert_true(dial.has("command"), "Owner's dials keep command field")


func test_filter_preserves_own_squadrons() -> void:
	var state: Dictionary = _make_game_state()
	state["player_states"][0]["squadrons"] = [_make_squadron(0)]
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var squads: Array = filtered["player_states"][0]["squadrons"]
	assert_eq(squads.size(), 1, "Own squadrons preserved")


# ---------------------------------------------------------------------------
# §4  Opponent's hidden dials are stripped
# ---------------------------------------------------------------------------

func test_filter_strips_opponent_hidden_dial_commands() -> void:
	var ship: Dictionary = _make_ship(1, 2, 1)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	var dials: Array = opp_ship["command_dial_stack"]["dials"]
	for dial: Dictionary in dials:
		if dial["state"] == CommandDialStack.STATE_HIDDEN:
			assert_false(dial.has("command"),
					"Opponent's hidden dial must not contain command")
			assert_true(dial.has("round"), "Hidden dial keeps round")


func test_filter_keeps_opponent_revealed_dial_commands() -> void:
	var ship: Dictionary = _make_ship(1, 0, 2)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	var dials: Array = opp_ship["command_dial_stack"]["dials"]
	for dial: Dictionary in dials:
		assert_true(dial.has("command"),
				"Opponent's revealed dial must keep command")


func test_filter_keeps_dial_metadata_for_hidden() -> void:
	var ship: Dictionary = _make_ship(1, 1, 0)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var dial: Dictionary = filtered["player_states"][1]["ships"][0]["command_dial_stack"]["dials"][0]
	assert_eq(dial["state"], CommandDialStack.STATE_HIDDEN, "state field preserved")
	assert_true(dial.has("round"), "round field preserved")


# ---------------------------------------------------------------------------
# §5  Opponent's facedown damage → count only
# ---------------------------------------------------------------------------

func test_filter_replaces_opponent_facedown_with_count() -> void:
	var ship: Dictionary = _make_ship(1, 0, 0, 4, 1)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	assert_false(opp_ship.has("facedown_damage"),
			"Opponent facedown_damage must be removed")
	assert_eq(opp_ship["facedown_count"], 4,
			"facedown_count must equal original facedown_damage size")


func test_filter_keeps_opponent_faceup_damage() -> void:
	var ship: Dictionary = _make_ship(1, 0, 0, 0, 2)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	assert_true(opp_ship.has("faceup_damage"), "faceup_damage must be kept")
	assert_eq(opp_ship["faceup_damage"].size(), 2, "All faceup cards visible")


# ---------------------------------------------------------------------------
# §6  Public fields pass through
# ---------------------------------------------------------------------------

func test_filter_preserves_opponent_public_fields() -> void:
	var ship: Dictionary = _make_ship(1)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	assert_eq(opp_ship["current_hull"], 4, "Hull is public")
	assert_eq(opp_ship["current_speed"], 2, "Speed is public")
	assert_eq(opp_ship["pos_x"], 0.5, "Position is public")
	assert_eq(opp_ship["data_key"], "cr90_corvette_a", "Data key is public")
	assert_eq(opp_ship["activated_this_round"], false, "Activation is public")


func test_debug_public_result_projection_keeps_transform_and_faceup_card_only() -> void:
	var ship: Dictionary = _make_ship(1, 0, 0, 2, 1)
	ship["pos_x"] = 0.73
	ship["pos_y"] = 0.21
	ship["rotation_deg"] = 135.0
	var state: Dictionary = _make_game_state([], [ship], 31, 2)
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opponent: Dictionary = filtered["player_states"][1]["ships"][0]
	var ledger: Dictionary = filtered["passive_damage_ledger"]
	assert_eq(opponent["pos_x"], 0.73)
	assert_eq(opponent["rotation_deg"], 135.0)
	assert_eq(opponent["faceup_damage"].size(), 1)
	assert_eq(opponent["facedown_count"], 2)
	assert_eq(ledger["draw_count"], 31)
	assert_eq(ledger["discard_pile"].size(), 2)
	assert_false(filtered.has("damage_deck"))
	assert_false(filtered.has("rng"))


func test_filter_preserves_round_and_phase() -> void:
	var state: Dictionary = _make_game_state()
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	assert_eq(filtered["current_round"], 1, "Round preserved")
	assert_eq(filtered["current_phase"], 1, "Phase preserved")
	assert_eq(filtered["initiative_player"], 0, "Initiative preserved")


func test_filter_preserves_opponent_squadrons() -> void:
	var state: Dictionary = _make_game_state()
	state["player_states"][1]["squadrons"] = [_make_squadron(1)]
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var squads: Array = filtered["player_states"][1]["squadrons"]
	assert_eq(squads.size(), 1, "Opponent squadrons pass through")
	assert_eq(squads[0]["data_key"], "x_wing_squadron", "Squadron data intact")


# ---------------------------------------------------------------------------
# §7  Original state is not mutated (deep copy safety)
# ---------------------------------------------------------------------------

func test_filter_does_not_mutate_original_state() -> void:
	var ship: Dictionary = _make_ship(1, 2, 0, 3, 0)
	var state: Dictionary = _make_game_state([], [ship])
	var _filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	# Original must still have rng and full data
	assert_true(state.has("rng"), "Original keeps rng")
	assert_true(state["damage_deck"].has("draw_pile"), "Original keeps draw_pile")
	var orig_ship: Dictionary = state["player_states"][1]["ships"][0]
	assert_true(orig_ship.has("facedown_damage"), "Original keeps facedown_damage")
	assert_eq(orig_ship["facedown_damage"].size(), 3, "Original facedown cards intact")
	var orig_dials: Array = orig_ship["command_dial_stack"]["dials"]
	for dial: Dictionary in orig_dials:
		assert_true(dial.has("command"), "Original dials keep command")


# ---------------------------------------------------------------------------
# §8  Symmetry — player 1 filtering hides player 0's secrets
# ---------------------------------------------------------------------------

func test_filter_hides_player_0_secrets_from_player_1() -> void:
	var p0_ship: Dictionary = _make_ship(0, 3, 0, 5, 0)
	var state: Dictionary = _make_game_state([p0_ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 1)
	var opp_ship: Dictionary = filtered["player_states"][0]["ships"][0]
	assert_false(opp_ship.has("facedown_damage"),
			"Player 1 must not see Player 0's facedown_damage")
	assert_eq(opp_ship["facedown_count"], 5,
			"Player 1 sees facedown_count for Player 0's ship")
	for dial: Dictionary in opp_ship["command_dial_stack"]["dials"]:
		assert_false(dial.has("command"),
				"Player 1 must not see Player 0's hidden commands")


# ---------------------------------------------------------------------------
# §9  Secret canary — property-based exhaustive test
# ---------------------------------------------------------------------------

func test_canary_rng_seed_never_appears_in_filtered_output() -> void:
	var state: Dictionary = _make_game_state()
	state["rng"]["initial_seed"] = 123456789
	state["rng"]["state"] = 987654321
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var json: String = JSON.stringify(filtered)
	assert_false(json.contains("123456789"),
			"RNG seed canary must not appear in filtered JSON")
	assert_false(json.contains("987654321"),
			"RNG state canary must not appear in filtered JSON")


func test_canary_draw_pile_card_never_in_filtered_output() -> void:
	var state: Dictionary = _make_game_state([], [], 1)
	state["damage_deck"]["draw_pile"][0]["title"] = "CANARY_SECRET_CARD"
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var json: String = JSON.stringify(filtered)
	assert_false(json.contains("CANARY_SECRET_CARD"),
			"Draw pile card title must not appear in filtered JSON")


func test_canary_opponent_facedown_card_never_in_filtered_output() -> void:
	var ship: Dictionary = _make_ship(1, 0, 0, 1, 0)
	ship["facedown_damage"][0]["title"] = "CANARY_HIDDEN_DAMAGE"
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var json: String = JSON.stringify(filtered)
	assert_false(json.contains("CANARY_HIDDEN_DAMAGE"),
			"Opponent facedown card title must not appear in filtered JSON")


func test_canary_opponent_hidden_command_never_in_filtered_output() -> void:
	# Use a very specific command value as canary
	var ship: Dictionary = _make_ship(1, 1, 0)
	ship["command_dial_stack"]["dials"][0]["command"] = 777
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var json: String = JSON.stringify(filtered)
	assert_false(json.contains("777"),
			"Opponent hidden dial command must not appear in filtered JSON")


# ---------------------------------------------------------------------------
# §10  Edge cases
# ---------------------------------------------------------------------------

func test_filter_with_no_ships_or_squadrons() -> void:
	var state: Dictionary = _make_game_state()
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	assert_eq(filtered["player_states"][0]["ships"].size(), 0, "No ships is fine")
	assert_eq(filtered["player_states"][1]["ships"].size(), 0, "No ships is fine")


func test_filter_with_empty_dial_stack() -> void:
	var ship: Dictionary = _make_ship(1)
	ship["command_dial_stack"] = {}
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	assert_true(opp_ship["command_dial_stack"].is_empty(),
			"Empty dial stack passes through as empty")


func test_filter_with_zero_facedown_damage() -> void:
	var ship: Dictionary = _make_ship(1, 0, 0, 0, 0)
	var state: Dictionary = _make_game_state([], [ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	var opp_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	assert_eq(opp_ship["facedown_count"], 0,
			"Zero facedown damage produces facedown_count=0")
	assert_false(opp_ship.has("facedown_damage"),
			"facedown_damage key removed even when empty")


func test_filter_multiple_ships_mixed_owners() -> void:
	var own_ship: Dictionary = _make_ship(0, 2, 0, 3, 0)
	var opp_ship: Dictionary = _make_ship(1, 1, 0, 2, 1)
	var state: Dictionary = _make_game_state([own_ship], [opp_ship])
	var filtered: Dictionary = StateFilter.filter_for_player(state, 0)
	# Both ships hide facedown identities; only own dials remain visible.
	var my_ship: Dictionary = filtered["player_states"][0]["ships"][0]
	assert_false(my_ship.has("facedown_damage"), "Own ship facedown identities are stripped")
	assert_eq(my_ship["facedown_count"], 3)
	# Opponent ship: filtered
	var their_ship: Dictionary = filtered["player_states"][1]["ships"][0]
	assert_false(their_ship.has("facedown_damage"), "Opponent facedown stripped")
	assert_eq(their_ship["facedown_count"], 2, "Opponent facedown_count correct")


func test_checked_filter_rejects_blank_ship_identity_with_diagnostic() -> void:
	var ship: Dictionary = _make_ship(0)
	ship["roster_entry_id"] = ""
	var result: Dictionary = StateFilter.filter_for_player_checked(
			_make_game_state([ship]), 0)
	assert_false(bool(result.get(StateFilter.KEY_OK, true)))
	assert_true(str(result.get(StateFilter.KEY_REASON, "")).contains(
			"blank roster_entry_id"))
	assert_eq(result.get(StateFilter.KEY_STATE, {}), {},
			"A rejected filter operation must expose no transmissible snapshot")


func test_checked_filter_rejects_duplicate_ship_identity_with_diagnostic() -> void:
	var first: Dictionary = _make_ship(0)
	var second: Dictionary = _make_ship(0)
	var result: Dictionary = StateFilter.filter_for_player_checked(
			_make_game_state([first, second]), 1)
	assert_false(bool(result.get(StateFilter.KEY_OK, true)))
	assert_true(str(result.get(StateFilter.KEY_REASON, "")).contains(
			"duplicate ship roster_entry_id"))
	assert_eq(result.get(StateFilter.KEY_STATE, {}), {})


func test_production_learning_scenario_filters_with_stable_ship_ids() -> void:
	var state := GameState.new()
	state.rng = GameRng.new(42042)
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_two_human()))
	LearningScenarioPreparer.prepare_game_state(
			LearningScenarioSetup.new(), state)
	assert_eq(state.stable_ship_identity_error(), "")
	for viewer: int in range(Constants.PLAYER_COUNT):
		var result: Dictionary = StateFilter.filter_for_player_checked(
				state.serialize(), viewer)
		assert_true(bool(result.get(StateFilter.KEY_OK, false)))
		assert_not_null(GameState.deserialize_passive_network(
				result.get(StateFilter.KEY_STATE, {}) as Dictionary))

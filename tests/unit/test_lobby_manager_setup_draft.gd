## Test: LobbyManager Setup Draft
##
## Focused tests for host-authoritative setup draft state.
extends GutTest


var _previous_lobby: LobbyState = null
var _previous_role: NetworkManager.Role = NetworkManager.Role.NONE


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby
	_previous_role = NetworkManager.role
	NetworkManager.role = NetworkManager.Role.SERVER
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.MATCH_STANDARD_400_ID
	lobby.players = [
		{"peer_id": 1, "display_name": "Host", "player_index": 0, "ready": false},
		{"peer_id": 2, "display_name": "Client", "player_index": 1, "ready": false},
	]
	lobby.setup_draft = LobbyManager._setup_draft_for_match_type(lobby.scenario)
	LobbyManager.current_lobby = lobby


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby
	NetworkManager.role = _previous_role


func test_apply_setup_roster_data_with_two_valid_rosters_enters_fleets_ready() -> void:
	LobbyManager._apply_setup_roster_data(0, _create_rebel_roster().serialize())
	LobbyManager._apply_setup_roster_data(1, _create_imperial_roster().serialize())
	var state: Dictionary = _setup_state()
	var status: Dictionary = state.get(LobbyManager.SETUP_KEY_VALIDATION_STATUS, {}) as Dictionary

	assert_eq(str(state.get(LobbyManager.SETUP_KEY_PHASE, "")),
			LobbyManager.SETUP_PHASE_FLEETS_READY,
			"Two valid roster submissions should make the lobby fleet draft startable.")
	assert_true(bool(status.get("ok", false)),
			"Valid lobby roster submissions should pass fleet-only validation.")
	assert_true(LobbyManager.can_start_setup_match(),
			"The host should be able to start setup once both fleets are valid.")
	assert_eq(_objective_candidates().size(), 0,
			"The lobby draft should not expose objective choices before game start.")
	assert_eq(str(_player_entry(0).get("display_name", "")), "Host",
			"Setup draft player entries should preserve the host display name.")
	assert_eq(str(_player_entry(1).get("display_name", "")), "Client",
			"Setup draft player entries should preserve the client display name.")


func test_apply_setup_roster_data_with_blank_player_name_rejects_draft() -> void:
	_set_player_display_name(0, "")
	LobbyManager._apply_setup_roster_data(0, _create_rebel_roster().serialize())
	LobbyManager._apply_setup_roster_data(1, _create_imperial_roster().serialize())
	var status: Dictionary = _setup_state().get(
			LobbyManager.SETUP_KEY_VALIDATION_STATUS, {}) as Dictionary
	var messages: Array = status.get("messages", []) as Array

	assert_false(bool(status.get("ok", true)),
			"Blank player names should reject the fleet-selection draft.")
	assert_true(messages.has(LobbyManager.VALIDATION_MESSAGE_NAMES_BLANK),
			"Blank player names should use the accepted validation message.")


func test_apply_setup_roster_data_with_duplicate_player_names_rejects_draft() -> void:
	_set_player_display_name(0, "Alex")
	_set_player_display_name(1, "Alex")
	LobbyManager._apply_setup_roster_data(0, _create_rebel_roster().serialize())
	LobbyManager._apply_setup_roster_data(1, _create_imperial_roster().serialize())
	var status: Dictionary = _setup_state().get(
			LobbyManager.SETUP_KEY_VALIDATION_STATUS, {}) as Dictionary
	var messages: Array = status.get("messages", []) as Array

	assert_false(bool(status.get("ok", true)),
			"Duplicate player names should reject the fleet-selection draft.")
	assert_true(messages.has(LobbyManager.VALIDATION_MESSAGE_NAMES_DIFFERENT),
			"Duplicate player names should use the accepted validation message.")


func test_apply_setup_roster_data_with_same_faction_uses_accepted_message() -> void:
	LobbyManager._apply_setup_roster_data(0, _create_rebel_roster().serialize())
	LobbyManager._apply_setup_roster_data(1, _create_rebel_roster().serialize())
	var status: Dictionary = _setup_state().get(
			LobbyManager.SETUP_KEY_VALIDATION_STATUS, {}) as Dictionary
	var messages: Array = status.get("messages", []) as Array

	assert_true(messages.has(LobbyManager.VALIDATION_MESSAGE_FACTIONS_DIFFERENT),
			"Same-faction fleets should use the accepted validation message.")


func test_prepare_setup_draft_for_start_enters_initiative_confirmation() -> void:
	_seed_valid_rosters()

	var draft: FleetSetupPackage = LobbyManager._prepare_setup_draft_for_start()
	var state: Dictionary = draft.setup_state
	var confirmations: Dictionary = LobbyManager._initiative_confirmations(state)

	assert_eq(str(state.get(LobbyManager.SETUP_KEY_PHASE, "")),
			LobbyManager.SETUP_PHASE_INITIATIVE_CONFIRMATION,
			"Starting the setup match should move the draft to initiative confirmation.")
	assert_between(int(state.get("resolved_first_player", -1)), 0, 1,
			"The post-start draft should resolve a valid first player.")
	assert_false(bool(confirmations.get("0", false)),
			"Player 1 should still need to confirm initiative.")
	assert_false(bool(confirmations.get("1", false)),
			"Player 2 should still need to confirm initiative.")
	assert_eq(_objective_candidates().size(), 0,
			"Objective candidates should wait until both initiative confirmations.")


func test_resolve_initiative_state_tied_points_sets_random_tie_break_chooser() -> void:
	var state: Dictionary = LobbyManager._default_setup_state()
	LobbyManager._resolve_initiative_state([
		_create_rebel_roster(),
		_create_rebel_roster(),
	], state)
	var chooser: int = int(state.get(LobbyManager.SETUP_KEY_INITIATIVE_CHOOSER, -1))
	var tie_break_chooser: int = int(state.get(
			LobbyManager.SETUP_KEY_INITIATIVE_TIE_BREAK_CHOOSER, -1))

	assert_true(bool(state.get(LobbyManager.SETUP_KEY_INITIATIVE_TIED, false)),
			"Equal fleet totals should mark the initiative state as tied.")
	assert_between(chooser, 0, 1,
			"Tied fleet totals should assign a valid chooser.")
	assert_eq(tie_break_chooser, chooser,
			"The random tie-break chooser should become the initiative chooser.")
	assert_eq(int(state.get("resolved_first_player", -1)), chooser,
			"Tied initiative should default first-player selection to the chooser until changed.")


func test_apply_first_player_choice_tied_state_rejects_wrong_player() -> void:
	_seed_valid_rosters()
	var draft: FleetSetupPackage = LobbyManager._prepare_setup_draft_for_start()
	var state: Dictionary = draft.setup_state
	state[LobbyManager.SETUP_KEY_INITIATIVE_TIED] = true
	state[LobbyManager.SETUP_KEY_INITIATIVE_RANDOM] = true
	state[LobbyManager.SETUP_KEY_INITIATIVE_CHOOSER] = 1
	state[LobbyManager.SETUP_KEY_INITIATIVE_TIE_BREAK_CHOOSER] = 1
	state["resolved_first_player"] = 1
	draft.setup_state = state
	LobbyManager.current_lobby.setup_draft = draft.serialize()

	LobbyManager._apply_first_player_choice(0, 0)

	assert_eq(int(_setup_state().get("resolved_first_player", -1)), 1,
			"Only the random tie-break chooser should be able to choose first player on ties.")

	LobbyManager._apply_first_player_choice(1, 0)

	assert_eq(int(_setup_state().get("resolved_first_player", -1)), 0,
			"The random tie-break chooser should be able to choose either player as first.")


func test_apply_initiative_confirmation_from_both_players_enters_objective_selection() -> void:
	_seed_valid_rosters()
	LobbyManager._prepare_setup_draft_for_start()

	LobbyManager._apply_initiative_confirmation(0)
	LobbyManager._apply_initiative_confirmation(1)
	var state: Dictionary = _setup_state()

	assert_eq(str(state.get(LobbyManager.SETUP_KEY_PHASE, "")),
			LobbyManager.SETUP_PHASE_OBJECTIVE_SELECTION,
			"Both initiative confirmations should reveal objective selection.")
	assert_eq(_objective_candidates().size(), 3,
			"Objective selection should show the second player's three objectives.")


func test_apply_objective_confirmation_locks_choice_and_waits_for_opponent() -> void:
	_seed_objective_selection()
	var chooser: int = int(_setup_state().get("resolved_first_player", -1))
	var objective_key: String = str((_objective_candidates()[0] as Dictionary).get("data_key", ""))
	LobbyManager._apply_objective_confirmation(chooser, objective_key)
	var state: Dictionary = _setup_state()
	var confirmations: Dictionary = LobbyManager._confirmations(state)

	assert_true(bool(state.get(LobbyManager.SETUP_KEY_OBJECTIVE_CHOICE_LOCKED, false)),
			"The choosing player's confirmation should lock the selected objective.")
	assert_eq(str(state.get(LobbyManager.SETUP_KEY_SELECTED_OBJECTIVE_KEY, "")),
			objective_key,
			"The locked lobby draft should preserve the selected objective key.")
	assert_eq(str(state.get(LobbyManager.SETUP_KEY_PHASE, "")),
			LobbyManager.SETUP_PHASE_OBJECTIVE_CONFIRMATION,
			"After the first confirmation, the lobby draft should wait for the opponent acknowledgement.")
	assert_true(bool(confirmations.get(str(chooser), false)),
			"The choosing player should count as already confirmed.")
	assert_false(bool(confirmations.get(str(1 - chooser), false)),
			"The opposing player should still need to confirm the locked objective.")


func test_apply_objective_confirmation_from_opponent_marks_ready_to_start() -> void:
	_seed_objective_selection()
	var chooser: int = int(_setup_state().get("resolved_first_player", -1))
	var objective_key: String = str((_objective_candidates()[0] as Dictionary).get("data_key", ""))
	LobbyManager._apply_objective_confirmation(chooser, objective_key)
	LobbyManager._apply_objective_confirmation(1 - chooser, "")
	var state: Dictionary = _setup_state()
	var selected_objective: Dictionary = LobbyManager.current_lobby.setup_draft.get(
			"selected_objective", {}) as Dictionary

	assert_eq(str(state.get(LobbyManager.SETUP_KEY_PHASE, "")),
			LobbyManager.SETUP_PHASE_READY_TO_START,
			"Both players confirming the objective should make the setup draft startable.")
	assert_eq(str(selected_objective.get("data_key", "")), objective_key,
			"The ready-to-start lobby draft should keep the chosen objective payload.")
	assert_false(LobbyManager.can_start_setup_match(),
			"Lobby start gating should not depend on post-start objective confirmation.")


func _setup_state() -> Dictionary:
	return (LobbyManager.current_lobby.setup_draft.get("setup_state", {}) as Dictionary).duplicate(true)


func _objective_candidates() -> Array:
	return _setup_state().get(LobbyManager.SETUP_KEY_OBJECTIVE_CANDIDATES, []) as Array


func _player_entry(player_index: int) -> Dictionary:
	var players: Array = LobbyManager.current_lobby.setup_draft.get("players", []) as Array
	for raw_player: Variant in players:
		if raw_player is Dictionary \
				and int((raw_player as Dictionary).get("player_index", -1)) == player_index:
			return raw_player as Dictionary
	return {}


func _set_player_display_name(player_index: int, display_name: String) -> void:
	for player: Dictionary in LobbyManager.current_lobby.players:
		if int(player.get("player_index", -1)) != player_index:
			continue
		player["display_name"] = display_name
		return


func _seed_valid_rosters() -> void:
	LobbyManager._apply_setup_roster_data(0, _create_rebel_roster().serialize())
	LobbyManager._apply_setup_roster_data(1, _create_imperial_roster().serialize())


func _seed_objective_selection() -> void:
	_seed_valid_rosters()
	LobbyManager._prepare_setup_draft_for_start()
	LobbyManager._apply_initiative_confirmation(0)
	LobbyManager._apply_initiative_confirmation(1)


func _create_rebel_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create("rebel-fleet", "Rebel Setup Fleet", "REBEL_ALLIANCE")
	roster.point_format = {"id": FleetBuilderOptions.FORMAT_STANDARD_400, "limit": 400}
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = _create_ship("rebel-ship-1", "cr90_corvette_a")
	_add_upgrade(ship, "rebel-cmd", "general_dodonna", "COMMANDER")
	roster.add_ship(ship)
	roster.add_squadron(_create_squadron("rebel-squadron-1", "x_wing_squadron"))
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	roster.set_objectives(objectives)
	return roster


func _create_imperial_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(
			"imperial-fleet", "Imperial Setup Fleet", "GALACTIC_EMPIRE")
	roster.point_format = {"id": FleetBuilderOptions.FORMAT_STANDARD_400, "limit": 400}
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = _create_ship(
			"imperial-ship-1", "victory_ii_class_star_destroyer")
	_add_upgrade(ship, "imperial-cmd", "grand_moff_tarkin", "COMMANDER")
	roster.add_ship(ship)
	roster.add_squadron(_create_squadron("imperial-squadron-1", "tie_fighter_squadron"))
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_opening_salvo")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fleet_ambush")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_minefields")
	roster.set_objectives(objectives)
	return roster


func _create_ship(entry_id: String, data_key: String) -> FleetShipEntry:
	var ship_entry: FleetShipEntry = FleetShipEntry.new()
	ship_entry.entry_id = entry_id
	ship_entry.data_key = data_key
	return ship_entry


func _create_squadron(entry_id: String, data_key: String) -> FleetSquadronEntry:
	var squadron_entry: FleetSquadronEntry = FleetSquadronEntry.new()
	squadron_entry.entry_id = entry_id
	squadron_entry.data_key = data_key
	return squadron_entry


func _add_upgrade(ship_entry: FleetShipEntry, upgrade_id: String,
		upgrade_key: String, slot: String) -> void:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = upgrade_id
	assignment.data_key = upgrade_key
	assignment.slot = slot
	ship_entry.add_upgrade(assignment)

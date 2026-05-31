## Fleet Setup Package Builder
##
## Builds deterministic setup packages from validated fleet rosters. The builder
## embeds roster payloads so network peers and replays do not need local library files.
class_name FleetSetupPackageBuilder
extends RefCounted


const DEFAULT_SCENARIO_ID: String = "standard_3x6"
const PEER_HOST: String = "HOST"
const PEER_CLIENT: String = "CLIENT"
const RULE_FIRST_PLAYER: String = "setup.first_player"
const RULE_LIBRARY_LOAD: String = "setup.library.load"
const RULE_OBJECTIVE_CHOICE: String = "setup.objective.choice"
const RULE_PLAYER_COUNT: String = "setup.player.count"
const RULE_POINT_FORMAT: String = "setup.point_format"

var _validator: FleetValidator


func _init(p_validator: FleetValidator = null) -> void:
	_validator = p_validator if p_validator != null else FleetValidator.new()


## Builds a match-ready setup package from rosters already mapped to player indices.
func build_from_rosters(player_zero_roster: FleetRoster,
		player_one_roster: FleetRoster, first_player: int,
		selected_objective_key: String,
		scenario_id: String = DEFAULT_SCENARIO_ID) -> Dictionary:
	var rosters: Array[FleetRoster] = [player_zero_roster, player_one_roster]
	var validation: SetupValidationResult = _validate_build_inputs(
			rosters, first_player, selected_objective_key)
	if not validation.is_valid():
		return _build_result(false, null, validation)
	return _build_result(true, _create_package(
			rosters, first_player, selected_objective_key, scenario_id), validation)


## Loads two local fleet ids and expands them into an embedded setup package.
func build_from_library(library_manager: FleetLibraryManager,
		player_fleet_ids: Array[String], first_player: int,
		selected_objective_key: String,
		scenario_id: String = DEFAULT_SCENARIO_ID) -> Dictionary:
	var validation: SetupValidationResult = _validate_library_inputs(
			library_manager, player_fleet_ids)
	if not validation.is_valid():
		return _build_result(false, null, validation)
	var rosters: Array[FleetRoster] = _load_library_rosters(
			library_manager, player_fleet_ids, validation)
	if not validation.is_valid():
		return _build_result(false, null, validation)
	return build_from_rosters(rosters[0], rosters[1], first_player,
		selected_objective_key, scenario_id)


## Builds a package from host/client rosters using [param host_player_index].
func build_from_peer_rosters(host_roster: FleetRoster, client_roster: FleetRoster,
		host_player_index: int, first_player: int, selected_objective_key: String,
		scenario_id: String = DEFAULT_SCENARIO_ID) -> Dictionary:
	var validation: SetupValidationResult = SetupValidationResult.new()
	if not _player_index_valid(host_player_index):
		validation.add_error(RULE_FIRST_PLAYER, "Host player index is out of range.", [], [])
		return _build_result(false, null, validation)
	var rosters: Array[FleetRoster] = [null, null]
	rosters[host_player_index] = host_roster
	rosters[_other_player(host_player_index)] = client_roster
	return build_from_rosters(rosters[0], rosters[1], first_player,
		selected_objective_key, scenario_id)


## Returns the setup package player index for a transport peer role.
static func player_index_for_peer_role(peer_role: String, host_player_index: int) -> int:
	if not _player_index_valid_static(host_player_index):
		return -1
	match peer_role.to_upper():
		PEER_HOST:
			return host_player_index
		PEER_CLIENT:
			return _other_player_static(host_player_index)
		_:
			return -1


## Determines first player from fleet points.
## Rules Reference: "Setup", first player selection, RRG 1.5.0.
static func determine_first_player(player_zero_roster: FleetRoster,
		player_one_roster: FleetRoster, tie_breaker: Callable = Callable()) -> int:
	var player_zero_points: int = _fleet_total_points(player_zero_roster)
	var player_one_points: int = _fleet_total_points(player_one_roster)
	if player_zero_points < player_one_points:
		return 0
	if player_one_points < player_zero_points:
		return 1
	return _tie_breaker_player(tie_breaker)


func _validate_build_inputs(rosters: Array[FleetRoster], first_player: int,
		selected_objective_key: String) -> SetupValidationResult:
	var validation: SetupValidationResult = SetupValidationResult.new()
	_validate_first_player(first_player, validation)
	_validate_rosters(rosters, validation)
	_validate_point_format(rosters, validation)
	_validate_objective_choice(rosters, first_player, selected_objective_key, validation)
	return validation


func _validate_first_player(first_player: int, validation: SetupValidationResult) -> void:
	if not _player_index_valid(first_player):
		validation.add_error(RULE_FIRST_PLAYER, "First player is out of range.", [], [])


func _validate_rosters(rosters: Array[FleetRoster], validation: SetupValidationResult) -> void:
	if rosters.size() != Constants.PLAYER_COUNT:
		validation.add_error(RULE_PLAYER_COUNT, "Setup requires exactly two rosters.", [], [])
		return
	for player_index: int in range(Constants.PLAYER_COUNT):
		var roster: FleetRoster = rosters[player_index]
		if roster == null:
			validation.add_error(SetupValidationResult.RULE_ROSTER_MISSING,
				"Player %d roster is missing." % player_index, ["players/%d" % player_index], [])
			continue
		validation.add_fleet_validation(player_index, _validator.validate(roster))


func _validate_point_format(rosters: Array[FleetRoster],
		validation: SetupValidationResult) -> void:
	if rosters.size() != Constants.PLAYER_COUNT or rosters[0] == null or rosters[1] == null:
		return
	if CanonicalJson.stringify(rosters[0].point_format) == CanonicalJson.stringify(rosters[1].point_format):
		return
	validation.add_error(RULE_POINT_FORMAT,
		"Both setup rosters must use the same point format.", ["point_format"], [])


func _validate_objective_choice(rosters: Array[FleetRoster], first_player: int,
		selected_objective_key: String, validation: SetupValidationResult) -> void:
	if selected_objective_key.strip_edges().is_empty():
		validation.add_error(RULE_OBJECTIVE_CHOICE, "Selected objective is required.", [], [])
		return
	if not _player_index_valid(first_player) or rosters.size() != Constants.PLAYER_COUNT:
		return
	var owner_player: int = _other_player(first_player)
	if rosters[owner_player] == null:
		return
	if not _roster_has_objective(rosters[owner_player], selected_objective_key):
		validation.add_error(RULE_OBJECTIVE_CHOICE,
			"Selected objective must come from the second player's objective cards.",
			["selected_objective"], [])
	if AssetLoader.load_objective_data(selected_objective_key) == null:
		validation.add_error(RULE_OBJECTIVE_CHOICE,
			"Selected objective '%s' could not be loaded." % selected_objective_key,
			["selected_objective"], [])


func _create_package(rosters: Array[FleetRoster], first_player: int,
		selected_objective_key: String, scenario_id: String) -> FleetSetupPackage:
	var objective_data: ObjectiveData = AssetLoader.load_objective_data(selected_objective_key)
	var owner_player: int = _other_player(first_player)
	var package: FleetSetupPackage = FleetSetupPackage.new()
	package.scenario_id = scenario_id
	package.first_player = first_player
	package.point_format = rosters[0].point_format.duplicate(true)
	package.map = rosters[first_player].map.duplicate(true)
	package.players = [_player_entry(0, rosters[0]), _player_entry(1, rosters[1])]
	package.selected_objective = _selected_objective_payload(
			objective_data, owner_player, first_player)
	package.setup_state = _objective_setup_state(objective_data)
	return package


func _player_entry(player_index: int, roster: FleetRoster) -> Dictionary:
	return {
		"player_index": player_index,
		"faction": roster.faction,
		"roster": roster.serialize(),
	}


func _selected_objective_payload(objective_data: ObjectiveData,
		owner_player: int, chosen_by_player: int) -> Dictionary:
	return {
		"data_key": objective_data.data_key,
		"category": objective_data.category,
		"objective_name": objective_data.objective_name,
		"owner_player": owner_player,
		"chosen_by_player": chosen_by_player,
	}


func _objective_setup_state(objective_data: ObjectiveData) -> Dictionary:
	var effects: Array[Dictionary] = _copy_dict_array(objective_data.setup_effects)
	var setup_state: Dictionary = {
		"objective_key": objective_data.data_key,
		"category": objective_data.category,
		"setup_effects": effects,
		"setup_steps": _setup_steps(effects),
		"runtime_state_requirements": _copy_string_array(
				objective_data.runtime_state_requirements),
		"objective_ships": [],
		"objective_tokens": _objective_token_state(objective_data),
		"set_aside_units": [],
		"deployment_overrides": [],
	}
	for effect: Dictionary in effects:
		_add_effect_scaffold(setup_state, effect)
	return setup_state


func _setup_steps(effects: Array[Dictionary]) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for index: int in range(effects.size()):
		var effect: Dictionary = effects[index]
		steps.append({
			"step_id": "%02d_%s" % [index + 1, str(effect.get("kind", "setup"))],
			"kind": str(effect.get("kind", "")),
			"controller": str(effect.get("controller", "")),
			"status": "PENDING",
			"effect": effect.duplicate(true),
		})
	return steps


func _objective_token_state(objective_data: ObjectiveData) -> Dictionary:
	var token_state: Dictionary = objective_data.objective_tokens.duplicate(true)
	token_state["placements"] = []
	token_state["assignments"] = []
	token_state["removed_tokens"] = []
	token_state["placement_steps"] = []
	return token_state


func _add_effect_scaffold(setup_state: Dictionary, effect: Dictionary) -> void:
	match str(effect.get("kind", "")):
		"choose_objective_ship_pair":
			_add_objective_ship_scaffold(setup_state, effect)
		"assign_objective_tokens":
			_add_token_assignment_scaffold(setup_state, effect)
		"place_objective_tokens":
			_add_token_placement_scaffold(setup_state, effect)
		"place_objective_tokens_alternating":
			_add_token_placement_scaffold(setup_state, effect)
		"set_aside_units":
			_add_set_aside_scaffold(setup_state, effect)
		"deployment_order_override":
			_add_deployment_override_scaffold(setup_state, effect)
		"deployment_zone_override":
			_add_deployment_override_scaffold(setup_state, effect)


func _add_objective_ship_scaffold(setup_state: Dictionary, effect: Dictionary) -> void:
	var requirements: Array = setup_state.get("objective_ships", []) as Array
	requirements.append({
		"controller": str(effect.get("controller", "")),
		"targets": _copy_string_array(effect.get("targets", [])),
		"count_per_target": int(effect.get("count_per_target", 0)),
		"selections": {},
	})
	setup_state["objective_ships"] = requirements


func _add_token_assignment_scaffold(setup_state: Dictionary, effect: Dictionary) -> void:
	var token_state: Dictionary = setup_state.get("objective_tokens", {}) as Dictionary
	var assignments: Array = token_state.get("assignments", []) as Array
	assignments.append({"effect": effect.duplicate(true), "assigned_to": []})
	token_state["assignments"] = assignments
	setup_state["objective_tokens"] = token_state


func _add_token_placement_scaffold(setup_state: Dictionary, effect: Dictionary) -> void:
	var token_state: Dictionary = setup_state.get("objective_tokens", {}) as Dictionary
	var placement_steps: Array = token_state.get("placement_steps", []) as Array
	placement_steps.append({"effect": effect.duplicate(true), "placements": []})
	token_state["placement_steps"] = placement_steps
	setup_state["objective_tokens"] = token_state


func _add_set_aside_scaffold(setup_state: Dictionary, effect: Dictionary) -> void:
	var set_aside: Array = setup_state.get("set_aside_units", []) as Array
	set_aside.append({"effect": effect.duplicate(true), "units": []})
	setup_state["set_aside_units"] = set_aside


func _add_deployment_override_scaffold(setup_state: Dictionary, effect: Dictionary) -> void:
	var overrides: Array = setup_state.get("deployment_overrides", []) as Array
	overrides.append(effect.duplicate(true))
	setup_state["deployment_overrides"] = overrides


func _validate_library_inputs(library_manager: FleetLibraryManager,
		player_fleet_ids: Array[String]) -> SetupValidationResult:
	var validation: SetupValidationResult = SetupValidationResult.new()
	if library_manager == null:
		validation.add_error(RULE_LIBRARY_LOAD, "Fleet library manager is required.", [], [])
	if player_fleet_ids.size() != Constants.PLAYER_COUNT:
		validation.add_error(RULE_PLAYER_COUNT, "Setup requires two fleet ids.", [], [])
	return validation


func _load_library_rosters(library_manager: FleetLibraryManager,
		player_fleet_ids: Array[String], validation: SetupValidationResult) -> Array[FleetRoster]:
	var rosters: Array[FleetRoster] = []
	for player_index: int in range(player_fleet_ids.size()):
		var load_result: Dictionary = library_manager.load_roster(player_fleet_ids[player_index])
		if not bool(load_result.get("ok", false)):
			validation.add_error(RULE_LIBRARY_LOAD, str(load_result.get("message", "")),
				["players/%d/fleet_id" % player_index], [])
			continue
		rosters.append(load_result.get("roster") as FleetRoster)
	return rosters


func _roster_has_objective(roster: FleetRoster, objective_key: String) -> bool:
	for category: String in FleetObjectiveSelection.categories():
		if roster.objectives.get_objective(category) == objective_key:
			return true
	return false


func _build_result(ok: bool, package: FleetSetupPackage,
		validation: SetupValidationResult) -> Dictionary:
	return {"ok": ok, "package": package, "validation": validation}


func _other_player(player_index: int) -> int:
	return _other_player_static(player_index)


func _player_index_valid(player_index: int) -> bool:
	return _player_index_valid_static(player_index)


static func _other_player_static(player_index: int) -> int:
	return 1 - player_index


static func _player_index_valid_static(player_index: int) -> bool:
	return player_index >= 0 and player_index < Constants.PLAYER_COUNT


static func _fleet_total_points(roster: FleetRoster) -> int:
	return int(FleetRosterSummary.calculate(roster).get(
			FleetRosterSummary.KEY_TOTAL_POINTS, 0))


static func _tie_breaker_player(tie_breaker: Callable) -> int:
	if tie_breaker.is_valid():
		return clampi(int(tie_breaker.call()), 0, Constants.PLAYER_COUNT - 1)
	return randi_range(0, Constants.PLAYER_COUNT - 1)


static func _copy_dict_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


static func _copy_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for raw_value: Variant in values as Array:
		result.append(str(raw_value))
	return result

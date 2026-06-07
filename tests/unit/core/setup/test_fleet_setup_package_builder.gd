## Test: FleetSetupPackageBuilder
##
## Unit tests for FB11 setup-package construction from validated fleet rosters.
extends GutTest


var _library_manager_script: GDScript = preload(
		"res://src/core/fleet/fleet_library_manager.gd")

var _builder: FleetSetupPackageBuilder
var _manager: FleetLibraryManager
var _original_library_dir: String = ""
var _test_library_dir: String = "user://test_fleet_setup_package_builder"


func before_each() -> void:
	_original_library_dir = _library_manager_script.LIBRARY_DIR
	_library_manager_script.LIBRARY_DIR = _test_library_dir
	_cleanup_test_dir()
	_builder = FleetSetupPackageBuilder.new()
	_manager = FleetLibraryManager.new()


func after_each() -> void:
	_cleanup_test_dir()
	_library_manager_script.LIBRARY_DIR = _original_library_dir


func test_build_from_rosters_valid_creates_match_ready_package_expected() -> void:
	var result: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 0, "obj_ass_opening_salvo")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage

	assert_true(result.get("ok", false), "Valid rosters should produce a setup package")
	assert_eq(package.players.size(), 2, "Package should embed both rosters")
	assert_eq(package.selected_objective.get("owner_player", -1), 1,
		"Selected objective should belong to the second player")
	assert_eq(package.selected_objective.get("chosen_by_player", -1), 0,
		"First player should be recorded as the objective chooser")
	assert_eq(package.map.get("filename", ""), FleetBuilderOptions.DEFAULT_MAP_3X6,
		"Setup package should use the first player's roster map")
	assert_false(package.canonical_hash().is_empty(), "Package hash should be available")


func test_build_from_rosters_uses_first_player_map_expected() -> void:
	var rebel: FleetRoster = _create_rebel_roster()
	var imperial: FleetRoster = _create_imperial_roster()
	rebel.map = FleetBuilderOptions.map_payload("map_3x6_azure_v4.jpg")
	imperial.map = FleetBuilderOptions.map_payload("map_3x6_hoth_v4.jpg")

	var result: Dictionary = _builder.build_from_rosters(
		rebel, imperial, 1, "obj_ass_most_wanted")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage

	assert_true(result.get("ok", false), "Valid rosters should produce a setup package")
	assert_eq(package.map.get("filename", ""), "map_3x6_hoth_v4.jpg",
		"The first player's roster map should drive the setup package map")


func test_build_from_rosters_first_player_and_hash_stable_expected() -> void:
	var first: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 1, "obj_ass_most_wanted")
	var second: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 1, "obj_ass_most_wanted")
	var package: FleetSetupPackage = first.get("package") as FleetSetupPackage
	var second_package: FleetSetupPackage = second.get("package") as FleetSetupPackage
	var restored: FleetSetupPackage = FleetSetupPackage.deserialize(package.serialize())

	assert_eq(restored.first_player, 1,
		"Setup package serialization should preserve first-player selection")
	assert_eq(restored.canonical_hash(), package.canonical_hash(),
		"Canonical hash should survive setup package serialization")
	assert_eq(package.canonical_hash(), second_package.canonical_hash(),
		"Equivalent setup builds should produce a stable canonical hash")


func test_determine_first_player_chooser_lower_fleet_points_expected() -> void:
	var chooser: int = FleetSetupPackageBuilder.determine_first_player_chooser(
			_create_imperial_roster(), _create_rebel_roster())

	assert_eq(chooser, 1,
		"The lower-point fleet should choose which player is first")


func test_determine_first_player_chooser_tie_uses_tie_breaker_expected() -> void:
	var chooser: int = FleetSetupPackageBuilder.determine_first_player_chooser(
			_create_rebel_roster(), _create_rebel_roster(), func() -> int: return 1)

	assert_eq(chooser, 1,
		"Tied fleet totals should use the supplied 50/50 chooser result")


func test_build_from_rosters_invalid_fleet_rejected_expected() -> void:
	var invalid_roster: FleetRoster = _create_rebel_roster()
	invalid_roster.get_ship("rebel-ship-1").upgrades.clear()

	var result: Dictionary = _builder.build_from_rosters(
		invalid_roster, _create_imperial_roster(), 0, "obj_ass_opening_salvo")
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false), "Invalid rosters should not start setup")
	assert_true(_has_error(validation, FleetValidator.RULE_COMMANDER_COUNT),
		"Fleet validation errors should be carried into setup validation")


func test_build_from_rosters_same_faction_rejected_expected() -> void:
	var result: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_rebel_roster(), 0, "obj_ass_most_wanted")
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false),
		"Setup should reject fleets that share the same faction")
	assert_true(_has_error(validation, FleetSetupPackageBuilder.RULE_FLEET_FACTION),
		"Setup validation should report same-faction fleet selections")


func test_build_from_rosters_rejects_first_player_objective_expected() -> void:
	var result: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 0, "obj_ass_most_wanted")
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false),
		"First player should only choose from the second player's objectives")
	assert_true(_has_error(validation, FleetSetupPackageBuilder.RULE_OBJECTIVE_CHOICE),
		"Objective ownership mismatch should be reported")


func test_build_from_rosters_extracts_objective_ship_setup_state_expected() -> void:
	var result: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 1, "obj_ass_most_wanted")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage
	var objective_ships: Array = package.setup_state.get("objective_ships", []) as Array

	assert_true(result.get("ok", false), "Most Wanted package should build")
	assert_eq(objective_ships.size(), 1,
		"Most Wanted should scaffold objective ship requirements")
	assert_eq((objective_ships[0] as Dictionary).get("targets", []),
		["own_ship", "first_player_ship"],
		"Objective ship scaffold should preserve target requirements")


func test_build_from_rosters_extracts_set_aside_setup_state_expected() -> void:
	var rebel: FleetRoster = _create_rebel_roster()
	rebel.objectives.set_objective(
		FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_hyperspace_assault")

	var result: Dictionary = _builder.build_from_rosters(
		rebel, _create_imperial_roster(), 1, "obj_def_hyperspace_assault")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage
	var set_aside: Array = package.setup_state.get("set_aside_units", []) as Array
	var token_state: Dictionary = package.setup_state.get("objective_tokens", {}) as Dictionary

	assert_true(result.get("ok", false), "Hyperspace Assault package should build")
	assert_eq(set_aside.size(), 1, "Set-aside objective should scaffold set-aside units")
	assert_eq((token_state.get("placement_steps", []) as Array).size(), 1,
		"Set-aside objective token placement should be represented")


func test_build_from_rosters_extracts_deployment_override_expected() -> void:
	var rebel: FleetRoster = _create_rebel_roster()
	rebel.objectives.set_objective(
		FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_superior_positions")

	var result: Dictionary = _builder.build_from_rosters(
		rebel, _create_imperial_roster(), 1, "obj_nav_superior_positions")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage
	var overrides: Array = package.setup_state.get("deployment_overrides", []) as Array

	assert_true(result.get("ok", false), "Superior Positions package should build")
	assert_eq(overrides.size(), 1,
		"Deployment-order objectives should scaffold deployment overrides")
	assert_eq((overrides[0] as Dictionary).get("kind", ""), "deployment_order_override",
		"Deployment override scaffold should preserve effect kind")


func test_build_from_library_expands_local_ids_expected() -> void:
	_manager.save_roster(_create_rebel_roster())
	_manager.save_roster(_create_imperial_roster())

	var result: Dictionary = _builder.build_from_library(
		_manager, ["rebel-fleet", "imperial-fleet"], 0, "obj_ass_opening_salvo")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage
	var player: Dictionary = package.players[1]
	var roster: Dictionary = player.get("roster", {}) as Dictionary

	assert_true(result.get("ok", false), "Library fleet ids should expand to embedded rosters")
	assert_eq(roster.get("fleet_id", ""), "imperial-fleet",
		"Expanded package should embed the loaded roster payload")


func test_build_from_library_legacy_missing_map_defaults_expected() -> void:
	_write_legacy_rebel_record_without_map()
	var imperial: FleetRoster = _create_imperial_roster()
	imperial.point_format = {"id": FleetBuilderOptions.FORMAT_CORE_SET_180, "limit": 180}
	imperial.map = FleetBuilderOptions.default_map_for_point_format(imperial.point_format)
	_manager.save_roster(imperial)

	var result: Dictionary = _builder.build_from_library(
		_manager, ["legacy-rebel-fleet", "imperial-fleet"], 0, "obj_ass_opening_salvo")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage

	assert_true(result.get("ok", false),
		"Legacy rosters without serialized maps should still build setup packages")
	assert_eq(package.map.get("filename", ""), FleetBuilderOptions.DEFAULT_MAP_3X3,
		"Missing legacy maps should default from the roster point format")


func test_build_from_draft_rejects_selected_point_format_mismatch_expected() -> void:
	_manager.save_roster(_create_rebel_roster())
	_manager.save_roster(_create_imperial_roster())
	var draft: FleetSetupPackage = SetupMatchOptions.create_setup_package_draft(
			SetupMatchOptions.MATCH_CORE_SET_180)

	var result: Dictionary = _builder.build_from_draft(
			_manager, ["rebel-fleet", "imperial-fleet"], 0, "obj_ass_opening_salvo", draft)
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false),
		"Setup draft should reject fleets that do not match the selected match type")
	assert_true(_has_error(validation, FleetSetupPackageBuilder.RULE_SELECTED_POINT_FORMAT),
		"Draft validation should report point-format mismatches against the selected match type")


func test_build_from_peer_rosters_hash_matches_player_indexed_package_expected() -> void:
	var direct: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 0, "obj_ass_opening_salvo")
	var peer: Dictionary = _builder.build_from_peer_rosters(
		_create_imperial_roster(), _create_rebel_roster(), 1, 0, "obj_ass_opening_salvo")

	var direct_package: FleetSetupPackage = direct.get("package") as FleetSetupPackage
	var peer_package: FleetSetupPackage = peer.get("package") as FleetSetupPackage
	assert_eq(direct_package.canonical_hash(), peer_package.canonical_hash(),
		"Host/client roster mapping should produce the same canonical package hash")
	assert_eq(FleetSetupPackageBuilder.player_index_for_peer_role("client", 1), 0,
		"Peer role mapping should keep transport identity outside setup JSON")


func test_build_from_peer_rosters_for_draft_preserves_display_names_expected() -> void:
	var draft: FleetSetupPackage = SetupMatchOptions.create_setup_package_draft(
			SetupMatchOptions.MATCH_STANDARD_400)
	draft.players = [
		{"player_index": 0, "display_name": "Luke"},
		{"player_index": 1, "display_name": "Darth"},
	]

	var result: Dictionary = _builder.build_from_peer_rosters_for_draft(
			_create_imperial_roster(), _create_rebel_roster(), 1, 0,
			"obj_ass_opening_salvo", draft)
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage

	assert_true(result.get("ok", false),
		"Draft-backed peer-roster builds should still produce a setup package.")
	assert_eq(str(package.players[0].get("display_name", "")), "Luke",
		"Finalized peer packages should preserve player 0's draft display name.")
	assert_eq(str(package.players[1].get("display_name", "")), "Darth",
		"Finalized peer packages should preserve player 1's draft display name.")
	assert_eq(package.validate_basic().size(), 0,
		"Finalized peer packages should remain bootstrap-valid after preserving display names.")


func test_build_from_rosters_round_trip_preserves_setup_state_expected() -> void:
	var result: Dictionary = _builder.build_from_rosters(
		_create_rebel_roster(), _create_imperial_roster(), 1, "obj_ass_most_wanted")
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage

	var restored: FleetSetupPackage = FleetSetupPackage.deserialize(package.serialize())

	assert_eq(restored.setup_state, package.setup_state,
		"Setup package serialization should preserve objective setup state")
	assert_eq(restored.selected_objective, package.selected_objective,
		"Setup package serialization should preserve objective ownership")


func _create_rebel_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(
		"rebel-fleet", "Rebel Setup Fleet", "REBEL_ALLIANCE")
	roster.point_format = _point_format()
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = _create_ship("rebel-ship-1", "cr90_corvette_a")
	_add_upgrade(ship, "rebel-cmd", "general_dodonna", "OFFICER")
	roster.add_ship(ship)
	roster.add_squadron(_create_squadron("rebel-squadron-1", "x_wing_squadron"))
	_set_rebel_objectives(roster)
	return roster


func _create_imperial_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(
		"imperial-fleet", "Imperial Setup Fleet", "GALACTIC_EMPIRE")
	roster.point_format = _point_format()
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = _create_ship(
		"imperial-ship-1", "victory_ii_class_star_destroyer")
	_add_upgrade(ship, "imperial-cmd", "grand_moff_tarkin", "OFFICER")
	roster.add_ship(ship)
	roster.add_squadron(_create_squadron("imperial-squadron-1", "tie_fighter_squadron"))
	_set_imperial_objectives(roster)
	return roster


func _set_rebel_objectives(roster: FleetRoster) -> void:
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	roster.set_objectives(objectives)


func _set_imperial_objectives(roster: FleetRoster) -> void:
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_opening_salvo")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fleet_ambush")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_minefields")
	roster.set_objectives(objectives)


func _write_legacy_rebel_record_without_map() -> void:
	var roster: FleetRoster = _create_rebel_roster()
	roster.fleet_id = "legacy-rebel-fleet"
	roster.point_format = {"id": FleetBuilderOptions.FORMAT_CORE_SET_180, "limit": 180}
	var roster_payload: Dictionary = roster.serialize()
	roster_payload.erase("map")
	var record: Dictionary = {
		"active_version_id": "v0001",
		"faction": roster.faction,
		"fleet_id": roster.fleet_id,
		"format_version": FleetLibraryManager.RECORD_FORMAT_VERSION,
		"kind": FleetLibraryManager.RECORD_KIND,
		"name": roster.name,
		"versions": [ {
			"canonical_hash": CanonicalJson.hash(roster_payload),
			"roster": roster_payload,
			"source": "legacy",
			"version_id": "v0001",
		}],
	}
	DirAccess.make_dir_recursive_absolute(_test_library_dir)
	var file: FileAccess = FileAccess.open("%s/%s.json" % [_test_library_dir, roster.fleet_id],
			FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()


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


func _point_format() -> Dictionary:
	return {"id": "STANDARD_400", "limit": 400}


func _has_error(validation: SetupValidationResult, rule_id: String) -> bool:
	for issue: Dictionary in validation.errors:
		if str(issue.get("rule_id", "")) == rule_id:
			return true
	return false


func _cleanup_test_dir() -> void:
	if not DirAccess.dir_exists_absolute(_test_library_dir):
		return
	var dir: DirAccess = DirAccess.open(_test_library_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir():
			DirAccess.remove_absolute("%s/%s" % [_test_library_dir, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(_test_library_dir)

## Test: FleetSetupPackage
##
## Unit tests for the FB2.5 setup-package shell and canonical hash contract.
extends GutTest


func test_deserialize_serialize_round_trip_expected() -> void:
	var package: FleetSetupPackage = FleetSetupPackage.deserialize(_create_package_data())
	var serialized: Dictionary = package.serialize()
	assert_eq(serialized.get("kind", ""), FleetSetupPackage.KIND, "Should keep package kind")
	assert_eq(serialized.get("scenario_id", ""), "standard_3x6", "Should keep scenario id")
	assert_eq((serialized.get("map", {}) as Dictionary).get("filename", ""),
		"map_3x6_distant-planet_v4.jpg", "Should keep setup map")
	assert_eq((serialized.get("players", []) as Array).size(), 2,
		"Should keep embedded player roster entries")
	assert_eq((serialized.get("setup_state", {}) as Dictionary).get("objective_key", ""),
		"obj_ass_opening_salvo", "Should keep setup-state scaffolding")


func test_validate_basic_accepts_complete_shell_expected() -> void:
	var package: FleetSetupPackage = FleetSetupPackage.deserialize(_create_package_data())
	assert_eq(package.validate_basic().size(), 0,
		"Complete setup package shell should pass basic validation")


func test_validate_basic_reports_missing_roster_expected() -> void:
	var data: Dictionary = _create_package_data()
	data["players"] = [{"player_index": 0}, {"player_index": 1, "roster": {}}]
	var package: FleetSetupPackage = FleetSetupPackage.deserialize(data)
	assert_true(package.validate_basic().size() > 0,
		"Player entries without embedded rosters should be rejected")


func test_canonical_hash_ignores_local_library_metadata_expected() -> void:
	var first: FleetSetupPackage = FleetSetupPackage.deserialize(_create_package_data())
	var changed_data: Dictionary = _create_package_data()
	changed_data["players"][0]["roster"]["created_at"] = "2030-01-01T00:00:00Z"
	changed_data["players"][0]["roster"]["future_sync"]["revision"] = 99
	var second: FleetSetupPackage = FleetSetupPackage.deserialize(changed_data)
	assert_eq(first.canonical_hash(), second.canonical_hash(),
		"Canonical setup hash should ignore local-only roster metadata")


func test_canonical_hash_changes_for_gameplay_roster_change_expected() -> void:
	var first: FleetSetupPackage = FleetSetupPackage.deserialize(_create_package_data())
	var changed_data: Dictionary = _create_package_data()
	changed_data["players"][0]["roster"]["ships"][0]["data_key"] = "cr90_corvette_b"
	var second: FleetSetupPackage = FleetSetupPackage.deserialize(changed_data)
	assert_ne(first.canonical_hash(), second.canonical_hash(),
		"Canonical setup hash should change when roster gameplay data changes")


func test_to_hashed_dict_includes_package_hash_expected() -> void:
	var package: FleetSetupPackage = FleetSetupPackage.deserialize(_create_package_data())
	var hashed: Dictionary = package.to_hashed_dict()
	assert_eq(hashed.get("package_hash", ""), package.canonical_hash(),
		"Hashed setup dictionary should include the canonical package hash")


func _create_package_data() -> Dictionary:
	return {
		"format_version": 1,
		"kind": "fleet_setup_package",
		"scenario_id": "standard_3x6",
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": _map_payload(),
		"first_player": 0,
		"players": [_create_player_entry(0), _create_player_entry(1)],
		"selected_objective": {},
		"obstacles": [],
		"deployments": [],
		"setup_state": {"objective_key": "obj_ass_opening_salvo"},
	}


func _create_player_entry(player_index: int) -> Dictionary:
	return {
		"player_index": player_index,
		"faction": "REBEL_ALLIANCE" if player_index == 0 else "GALACTIC_EMPIRE",
		"roster": _create_roster(player_index),
	}


func _create_roster(player_index: int) -> Dictionary:
	var ship_key: String = "cr90_corvette_a" if player_index == 0 else \
			"victory_ii_class_star_destroyer"
	return {
		"format_version": 1,
		"kind": "fleet_roster",
		"fleet_id": "local-%d" % player_index,
		"name": "Roster %d" % player_index,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"created_at": "2026-05-26T00:00:00Z",
		"updated_at": "2026-05-26T00:00:00Z",
		"source": "local",
		"future_sync": {"owner_id": "", "remote_id": "", "revision": 0},
		"map": _map_payload(),
		"ships": [{"entry_id": "ship-%d" % player_index, "data_key": ship_key}],
		"squadrons": [],
		"objectives": {},
	}


func _map_payload() -> Dictionary:
	return FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg")
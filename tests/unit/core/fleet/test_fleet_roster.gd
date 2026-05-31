## Test: FleetRoster
##
## Unit tests for editable fleet roster APIs and deterministic serialization.
extends GutTest


func test_create_identity_fields_expected() -> void:
	var roster: FleetRoster = FleetRoster.create("fleet-1", "Opening Fleet", "REBEL_ALLIANCE")

	assert_eq(roster.fleet_id, "fleet-1", "Create should set fleet id")
	assert_eq(roster.name, "Opening Fleet", "Create should set display name")
	assert_eq(roster.description, "", "Create should default description empty")
	assert_eq(roster.faction, "REBEL_ALLIANCE", "Create should set faction")


func test_add_ship_valid_entry_expected() -> void:
	var roster: FleetRoster = FleetRoster.create("fleet-1", "Fleet", "REBEL_ALLIANCE")
	var ship: FleetShipEntry = _create_ship("ship-1", "cr90_corvette_a")

	var added: bool = roster.add_ship(ship)

	assert_true(added, "Valid ship should be added")
	assert_eq(roster.get_ship("ship-1"), ship, "Added ship should be retrievable")
	assert_true(roster.has_entry_id("ship-1"), "Roster should report used ship id")


func test_add_ship_duplicate_entry_id_rejected_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	roster.add_ship(_create_ship("entry-1", "cr90_corvette_a"))

	var added: bool = roster.add_ship(_create_ship("entry-1", "nebulon_b_support_refit"))

	assert_false(added, "Duplicate ship entry id should be rejected")
	assert_eq(roster.ships.size(), 1, "Duplicate ship should not be stored")


func test_update_ship_existing_entry_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	roster.add_ship(_create_ship("ship-1", "cr90_corvette_a"))
	var updated_ship: FleetShipEntry = _create_ship("ship-1", "nebulon_b_support_refit")

	var updated: bool = roster.update_ship(updated_ship)

	assert_true(updated, "Existing ship should be updated")
	assert_eq(roster.get_ship("ship-1").data_key, "nebulon_b_support_refit",
		"Updated ship should replace data key")


func test_remove_ship_existing_entry_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	roster.add_ship(_create_ship("ship-1", "cr90_corvette_a"))

	var removed: bool = roster.remove_ship("ship-1")

	assert_true(removed, "Existing ship should be removed")
	assert_null(roster.get_ship("ship-1"), "Removed ship should not be retrievable")


func test_add_squadron_valid_entry_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	var squadron: FleetSquadronEntry = _create_squadron("squad-1", "x_wing_squadron")

	var added: bool = roster.add_squadron(squadron)

	assert_true(added, "Valid squadron should be added")
	assert_eq(roster.get_squadron("squad-1"), squadron, "Added squadron should be retrievable")
	assert_true(roster.has_entry_id("squad-1"), "Roster should report used squadron id")


func test_add_squadron_duplicate_ship_id_rejected_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	roster.add_ship(_create_ship("entry-1", "cr90_corvette_a"))

	var added: bool = roster.add_squadron(_create_squadron("entry-1", "x_wing_squadron"))

	assert_false(added, "Squadron id should not duplicate a ship id")
	assert_true(roster.squadrons.is_empty(), "Duplicate squadron should not be stored")


func test_update_squadron_existing_entry_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	roster.add_squadron(_create_squadron("squad-1", "x_wing_squadron"))
	var updated_squadron: FleetSquadronEntry = _create_squadron("squad-1", "x_wing_luke_skywalker")

	var updated: bool = roster.update_squadron(updated_squadron)

	assert_true(updated, "Existing squadron should be updated")
	assert_eq(roster.get_squadron("squad-1").data_key, "x_wing_luke_skywalker",
		"Updated squadron should replace data key")


func test_remove_squadron_existing_entry_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	roster.add_squadron(_create_squadron("squad-1", "x_wing_squadron"))

	var removed: bool = roster.remove_squadron("squad-1")

	assert_true(removed, "Existing squadron should be removed")
	assert_null(roster.get_squadron("squad-1"), "Removed squadron should not be retrievable")


func test_set_objectives_copies_selection_expected() -> void:
	var roster: FleetRoster = FleetRoster.new()
	var selection: FleetObjectiveSelection = _create_objectives()

	roster.set_objectives(selection)
	selection.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "changed")

	assert_eq(roster.objectives.assault_objective_key, "obj_ass_most_wanted",
		"Roster should own a serialized copy of objective selection")


func test_serialize_populated_roster_orders_entries_expected() -> void:
	var roster: FleetRoster = _create_populated_roster()

	var serialized: Dictionary = roster.serialize()
	var ships: Array = serialized.get("ships", []) as Array
	var squadrons: Array = serialized.get("squadrons", []) as Array

	assert_eq(ships[0].get("entry_id", ""), "ship-a", "Ships should be sorted by id")
	assert_eq(squadrons[0].get("entry_id", ""), "squad-a", "Squadrons should be sorted by id")
	assert_eq((serialized.get("objectives", {}) as Dictionary).get("assault", ""),
		"obj_ass_most_wanted", "Serialized roster should include objectives")
	assert_eq((serialized.get("map", {}) as Dictionary).get("filename", ""),
		FleetBuilderOptions.DEFAULT_MAP_3X3, "Serialized roster should include map")


func test_deserialize_missing_fields_uses_defaults_expected() -> void:
	var roster: FleetRoster = FleetRoster.deserialize({})

	assert_eq(roster.format_version, FleetRoster.FORMAT_VERSION, "Missing version should default")
	assert_eq(roster.kind, FleetRoster.KIND, "Missing kind should default")
	assert_eq(roster.source, "local", "Missing source should default to local")
	assert_true(roster.map.is_empty(), "Missing map should default empty")
	assert_true(roster.ships.is_empty(), "Missing ships should default empty")
	assert_true(roster.squadrons.is_empty(), "Missing squadrons should default empty")


func test_deserialize_duplicate_entry_ids_keeps_first_expected() -> void:
	var roster: FleetRoster = FleetRoster.deserialize({
		"ships": [
			{"entry_id": "entry-1", "data_key": "cr90_corvette_a"},
			{"entry_id": "entry-1", "data_key": "nebulon_b_support_refit"},
		],
		"squadrons": [{"entry_id": "entry-1", "data_key": "x_wing_squadron"}],
	})

	assert_eq(roster.ships.size(), 1, "Duplicate ship ids should be ignored")
	assert_true(roster.squadrons.is_empty(), "Squadron duplicating ship id should be ignored")
	assert_eq(roster.get_ship("entry-1").data_key, "cr90_corvette_a",
		"First duplicate entry should be kept")


func test_deserialize_serialize_round_trip_expected() -> void:
	var source: Dictionary = _create_populated_roster().serialize()

	var roster: FleetRoster = FleetRoster.deserialize(source)

	assert_eq(roster.serialize(), source, "Roster should round-trip through serialized data")


func test_canonical_hash_entry_order_stable_expected() -> void:
	var first: FleetRoster = _create_populated_roster()
	var second: FleetRoster = _create_populated_roster_reversed()

	assert_eq(first.canonical_hash(), second.canonical_hash(),
		"Canonical roster hash should ignore mutable insertion order")


func _create_ship(entry_id: String, data_key: String) -> FleetShipEntry:
	var ship: FleetShipEntry = FleetShipEntry.new()
	ship.entry_id = entry_id
	ship.data_key = data_key
	return ship


func _create_squadron(entry_id: String, data_key: String) -> FleetSquadronEntry:
	var squadron: FleetSquadronEntry = FleetSquadronEntry.new()
	squadron.entry_id = entry_id
	squadron.data_key = data_key
	return squadron


func _create_objectives() -> FleetObjectiveSelection:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.new()
	selection.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	selection.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	selection.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	return selection


func _create_populated_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create("fleet-1", "Opening Fleet", "REBEL_ALLIANCE")
	roster.point_format = {"id": "CORE_SET_180", "limit": 180}
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	roster.description = "A compact Core Set test fleet."
	roster.created_at = "2026-05-27T00:00:00Z"
	roster.updated_at = "2026-05-27T00:00:00Z"
	roster.future_sync = {"owner_id": "", "remote_id": "", "revision": 0}
	roster.add_ship(_create_ship("ship-b", "nebulon_b_support_refit"))
	roster.add_ship(_create_ship("ship-a", "cr90_corvette_a"))
	roster.add_squadron(_create_squadron("squad-b", "x_wing_luke_skywalker"))
	roster.add_squadron(_create_squadron("squad-a", "x_wing_squadron"))
	roster.set_objectives(_create_objectives())
	return roster


func _create_populated_roster_reversed() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create("fleet-1", "Opening Fleet", "REBEL_ALLIANCE")
	roster.point_format = {"limit": 180, "id": "CORE_SET_180"}
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	roster.description = "A compact Core Set test fleet."
	roster.created_at = "2026-05-27T00:00:00Z"
	roster.updated_at = "2026-05-27T00:00:00Z"
	roster.future_sync = {"revision": 0, "remote_id": "", "owner_id": ""}
	roster.add_squadron(_create_squadron("squad-a", "x_wing_squadron"))
	roster.add_squadron(_create_squadron("squad-b", "x_wing_luke_skywalker"))
	roster.add_ship(_create_ship("ship-a", "cr90_corvette_a"))
	roster.add_ship(_create_ship("ship-b", "nebulon_b_support_refit"))
	roster.set_objectives(_create_objectives())
	return roster

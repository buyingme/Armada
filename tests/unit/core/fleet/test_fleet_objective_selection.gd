## Test: FleetObjectiveSelection
##
## Unit tests for editable objective selection payloads.
extends GutTest


func test_set_objective_valid_category_expected() -> void:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.new()

	var accepted: bool = selection.set_objective(
			FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")

	assert_true(accepted, "Known objective category should be accepted")
	assert_eq(selection.assault_objective_key, "obj_ass_most_wanted",
		"Assault objective should be stored")


func test_set_objective_unknown_category_rejected_expected() -> void:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.new()

	var accepted: bool = selection.set_objective("CAMPAIGN", "objective_key")

	assert_false(accepted, "Unknown objective category should be rejected")
	assert_eq(selection.get_objective("CAMPAIGN"), "", "Unknown category should read empty")


func test_get_objective_each_category_expected() -> void:
	var selection: FleetObjectiveSelection = _create_complete_selection()

	assert_eq(selection.get_objective(FleetObjectiveSelection.CATEGORY_ASSAULT),
		"obj_ass_most_wanted", "Should read Assault objective")
	assert_eq(selection.get_objective(FleetObjectiveSelection.CATEGORY_DEFENSE),
		"obj_def_fire_lanes", "Should read Defense objective")
	assert_eq(selection.get_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION),
		"obj_nav_intel_sweep", "Should read Navigation objective")


func test_is_complete_all_categories_selected_expected() -> void:
	var selection: FleetObjectiveSelection = _create_complete_selection()

	assert_true(selection.is_complete(), "Three selected objectives should be complete")


func test_is_complete_missing_category_false_expected() -> void:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.new()
	selection.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")

	assert_false(selection.is_complete(), "Missing categories should be incomplete")


func test_serialize_complete_selection_expected() -> void:
	var selection: FleetObjectiveSelection = _create_complete_selection()

	var serialized: Dictionary = selection.serialize()

	assert_eq(serialized.get("assault", ""), "obj_ass_most_wanted",
		"Serialized data should include Assault objective")
	assert_eq(serialized.get("defense", ""), "obj_def_fire_lanes",
		"Serialized data should include Defense objective")
	assert_eq(serialized.get("navigation", ""), "obj_nav_intel_sweep",
		"Serialized data should include Navigation objective")


func test_deserialize_accepts_category_keys_expected() -> void:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.deserialize({
		"ASSAULT": "obj_ass_opening_salvo",
		"DEFENSE": "obj_def_contested_outpost",
		"NAVIGATION": "obj_nav_minefields",
	})

	assert_eq(selection.assault_objective_key, "obj_ass_opening_salvo",
		"Deserializer should accept category keys")
	assert_true(selection.is_complete(), "Category-key data should be complete")


func test_deserialize_serialize_round_trip_expected() -> void:
	var source: Dictionary = {
		"assault": "obj_ass_precision_strike",
		"defense": "obj_def_fleet_ambush",
		"navigation": "obj_nav_superior_positions",
	}

	var selection: FleetObjectiveSelection = FleetObjectiveSelection.deserialize(source)

	assert_eq(selection.serialize(), source, "Objective selection should round-trip")


func _create_complete_selection() -> FleetObjectiveSelection:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.new()
	selection.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	selection.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	selection.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	return selection

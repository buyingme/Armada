## Setup Match Options
##
## Read-only provider for New Game match-type choices shared by local setup,
## network lobby state, and setup-package draft initialization.
class_name SetupMatchOptions
extends RefCounted


const MATCH_STANDARD_400: String = "standard_400"
const MATCH_INTERMEDIATE_300: String = "intermediate_300"
const MATCH_CORE_SET_180: String = "core_set_180"
const MATCH_LEARNING_SCENARIO: String = "learning_scenario"
const MATCH_DEBUG_SCENARIO: String = "debug_scenario"
const MATCH_LEARNING_LEGACY: String = "learning"
const SCENARIO_STANDARD_3X6: String = "standard_3x6"
const LABEL_STANDARD_400: String = "Standard 400"
const LABEL_INTERMEDIATE_300: String = "Intermediate 300"
const LABEL_CORE_SET_180: String = "Core Set 180"
const LABEL_LEARNING_SCENARIO: String = "Learning Scenario"
const LABEL_DEBUG_SCENARIO: String = "Debug Scenario"
const KIND_SETUP: String = "setup"
const KIND_SCENARIO: String = "scenario"


## Returns the local and network New Game choices in display order.
static func get_options() -> Array[Dictionary]:
	return [
		_setup_option(LABEL_STANDARD_400, MATCH_STANDARD_400,
				FleetBuilderOptions.FORMAT_STANDARD_400, FleetValidator.DEFAULT_POINT_LIMIT),
		_setup_option(LABEL_INTERMEDIATE_300, MATCH_INTERMEDIATE_300,
				FleetBuilderOptions.FORMAT_CUSTOM, FleetBuilderOptions.CUSTOM_POINT_LIMIT),
		_setup_option(LABEL_CORE_SET_180, MATCH_CORE_SET_180,
				FleetBuilderOptions.FORMAT_CORE_SET_180,
				FleetBuilderOptions.CORE_SET_POINT_LIMIT),
		_scenario_option(LABEL_LEARNING_SCENARIO, MATCH_LEARNING_SCENARIO),
		_scenario_option(LABEL_DEBUG_SCENARIO, MATCH_DEBUG_SCENARIO),
	]


## Returns the canonical match-type id for current and legacy labels/ids.
static func normalize_match_type_id(raw_match_type: String) -> String:
	var candidate: String = raw_match_type.strip_edges()
	match candidate:
		MATCH_STANDARD_400, LABEL_STANDARD_400:
			return MATCH_STANDARD_400
		MATCH_INTERMEDIATE_300, LABEL_INTERMEDIATE_300, "Custom 300":
			return MATCH_INTERMEDIATE_300
		MATCH_CORE_SET_180, LABEL_CORE_SET_180:
			return MATCH_CORE_SET_180
		MATCH_DEBUG_SCENARIO, LABEL_DEBUG_SCENARIO:
			return MATCH_DEBUG_SCENARIO
		MATCH_LEARNING_SCENARIO, LABEL_LEARNING_SCENARIO, MATCH_LEARNING_LEGACY:
			return MATCH_LEARNING_SCENARIO
		_:
			return MATCH_LEARNING_SCENARIO


## Returns true when [param match_type_id] starts the setup-package flow.
static func is_setup_match_type(match_type_id: String) -> bool:
	return not point_format_for_match_type(match_type_id).is_empty()


## Returns true when [param match_type_id] maps directly to a fixed scenario.
static func is_scenario_match_type(match_type_id: String) -> bool:
	return scenario_id_for_match_type(match_type_id) != ""


## Returns the fixed scenario id for learning/debug choices, or empty.
static func scenario_id_for_match_type(match_type_id: String) -> String:
	var normalized: String = normalize_match_type_id(match_type_id)
	match normalized:
		MATCH_LEARNING_SCENARIO, MATCH_DEBUG_SCENARIO:
			return normalized
		_:
			return ""


## Returns the point-format payload for 400/300/180 setup choices.
static func point_format_for_match_type(match_type_id: String) -> Dictionary:
	var normalized: String = normalize_match_type_id(match_type_id)
	for option: Dictionary in get_options():
		if str(option.get("id", "")) == normalized:
			return (option.get("point_format", {}) as Dictionary).duplicate(true)
	return {}


## Builds the empty setup-package draft for a selected fleet-setup match type.
static func create_setup_package_draft(match_type_id: String) -> FleetSetupPackage:
	var package: FleetSetupPackage = FleetSetupPackage.new()
	var normalized_match_type: String = normalize_match_type_id(match_type_id)
	var point_format: Dictionary = point_format_for_match_type(match_type_id)
	if point_format.is_empty():
		return package
	package.scenario_id = SCENARIO_STANDARD_3X6
	package.point_format = point_format
	package.map = FleetBuilderOptions.default_map_for_point_format(point_format)
	package.setup_state = {
		"match_type": normalized_match_type,
		"selected_fleet_ids": ["", ""],
		"selected_objective_key": "",
		"validation_status": {
			"ok": false,
			"error_count": 0,
			"warning_count": 0,
			"package_hash": "",
		},
	}
	return package


## Returns the display label for a match-type id.
static func label_for_match_type(match_type_id: String) -> String:
	var normalized: String = normalize_match_type_id(match_type_id)
	for option: Dictionary in get_options():
		if str(option.get("id", "")) == normalized:
			return str(option.get("label", ""))
	return LABEL_LEARNING_SCENARIO


static func _setup_option(label_text: String, id: String,
		format_id: String, limit: int) -> Dictionary:
	return {
		"label": label_text,
		"id": id,
		"kind": KIND_SETUP,
		"point_format": {"id": format_id, "limit": limit, "custom_label": label_text},
	}


static func _scenario_option(label_text: String, id: String) -> Dictionary:
	return {
		"label": label_text,
		"id": id,
		"kind": KIND_SCENARIO,
		"scenario_id": id,
	}

## Setup Validation Result
##
## JSON-safe validation container for pre-game setup package construction.
## It can carry package-level issues and fleet-validator issues with player paths.
class_name SetupValidationResult
extends RefCounted


const SEVERITY_ERROR: String = "ERROR"
const SEVERITY_WARNING: String = "WARNING"
const RULE_ROSTER_MISSING: String = "setup.roster.missing"

## Deterministically ordered setup validation errors.
var errors: Array[Dictionary] = []

## Deterministically ordered setup validation warnings.
var warnings: Array[Dictionary] = []


## Adds a setup validation error.
func add_error(rule_id: String, message: String,
		affected_paths: Array[String] = [], source_refs: Array[String] = []) -> void:
	errors.append(_create_issue(SEVERITY_ERROR, rule_id, message,
			affected_paths, source_refs))


## Adds a setup validation warning.
func add_warning(rule_id: String, message: String,
		affected_paths: Array[String] = [], source_refs: Array[String] = []) -> void:
	warnings.append(_create_issue(SEVERITY_WARNING, rule_id, message,
			affected_paths, source_refs))


## Copies fleet-validation issues into this setup result for [param player_index].
func add_fleet_validation(player_index: int, result: FleetValidationResult) -> void:
	if result == null:
		add_error(RULE_ROSTER_MISSING, "Player %d roster is missing." % player_index,
			[_player_roster_path(player_index)], [])
		return
	for issue: Dictionary in result.errors:
		add_error(str(issue.get("rule_id", "")),
			_prefixed_message(player_index, issue), _affected_paths(player_index, issue),
			_source_refs(issue))
	for issue: Dictionary in result.warnings:
		add_warning(str(issue.get("rule_id", "")),
			_prefixed_message(player_index, issue), _affected_paths(player_index, issue),
			_source_refs(issue))


## Returns true when no setup errors are present.
func is_valid() -> bool:
	return errors.is_empty()


## Serializes this validation result to a JSON-safe dictionary.
func serialize() -> Dictionary:
	return {
		"errors": _copy_dict_array(errors),
		"warnings": _copy_dict_array(warnings),
	}


## Deserializes a setup validation result from JSON-safe data.
static func deserialize(data: Dictionary) -> SetupValidationResult:
	var result: SetupValidationResult = SetupValidationResult.new()
	result.errors = _read_dict_array(data.get("errors", []))
	result.warnings = _read_dict_array(data.get("warnings", []))
	return result


static func _create_issue(severity: String, rule_id: String, message: String,
		affected_paths: Array[String], source_refs: Array[String]) -> Dictionary:
	return {
		"severity": severity,
		"rule_id": rule_id,
		"message": message,
		"affected_paths": affected_paths.duplicate(),
		"source_refs": source_refs.duplicate(),
	}


static func _prefixed_message(player_index: int, issue: Dictionary) -> String:
	return "Player %d roster: %s" % [player_index, str(issue.get("message", ""))]


static func _affected_paths(player_index: int, issue: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	for raw_id: Variant in issue.get("affected_entry_ids", []):
		paths.append("%s/entries/%s" % [_player_roster_path(player_index), str(raw_id)])
	if paths.is_empty():
		paths.append(_player_roster_path(player_index))
	return paths


static func _source_refs(issue: Dictionary) -> Array[String]:
	var refs: Array[String] = []
	for raw_ref: Variant in issue.get("source_refs", []):
		refs.append(str(raw_ref))
	return refs


static func _player_roster_path(player_index: int) -> String:
	return "players/%d/roster" % player_index


static func _copy_dict_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


static func _read_dict_array(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result

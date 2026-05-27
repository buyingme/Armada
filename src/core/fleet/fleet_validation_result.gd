## Fleet Validation Result
##
## JSON-safe container for fleet-builder validation errors and warnings.
## Validation rules are added in later slices; this class defines the payload.
class_name FleetValidationResult
extends RefCounted


const SEVERITY_ERROR: String = "ERROR"
const SEVERITY_WARNING: String = "WARNING"

## Deterministically ordered validation errors.
var errors: Array[Dictionary] = []

## Deterministically ordered validation warnings.
var warnings: Array[Dictionary] = []


## Adds a validation error issue.
func add_error(rule_id: String, message: String,
		affected_entry_ids: Array[String] = [],
		source_refs: Array[String] = []) -> void:
	errors.append(_create_issue(SEVERITY_ERROR, rule_id, message,
			affected_entry_ids, source_refs))


## Adds a validation warning issue.
func add_warning(rule_id: String, message: String,
		affected_entry_ids: Array[String] = [],
		source_refs: Array[String] = []) -> void:
	warnings.append(_create_issue(SEVERITY_WARNING, rule_id, message,
			affected_entry_ids, source_refs))


## Returns true when no validation errors are present.
func is_valid() -> bool:
	return errors.is_empty()


## Serializes validation issues to a JSON-safe dictionary.
func serialize() -> Dictionary:
	return {
		"errors": _copy_dict_array(errors),
		"warnings": _copy_dict_array(warnings),
	}


## Deserializes validation issues from JSON-safe data.
static func deserialize(data: Dictionary) -> FleetValidationResult:
	var result: FleetValidationResult = FleetValidationResult.new()
	result.errors = _read_dict_array(data.get("errors", []))
	result.warnings = _read_dict_array(data.get("warnings", []))
	return result


static func _create_issue(severity: String, rule_id: String, message: String,
		affected_entry_ids: Array[String], source_refs: Array[String]) -> Dictionary:
	return {
		"severity": severity,
		"rule_id": rule_id,
		"message": message,
		"affected_entry_ids": affected_entry_ids.duplicate(),
		"source_refs": source_refs.duplicate(),
	}


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

## Test: FleetValidationResult
##
## Unit tests for structured fleet validation issue payloads.
extends GutTest


func test_add_error_records_issue_expected() -> void:
	var result: FleetValidationResult = FleetValidationResult.new()

	result.add_error("fleet.points.limit", "Fleet is over the point limit.", ["ship-1"],
		["Rules Reference: Fleet Building"])

	assert_false(result.is_valid(), "A result with errors should be invalid")
	assert_eq(result.errors.size(), 1, "Should store one error")
	assert_eq(result.errors[0].get("severity", ""), FleetValidationResult.SEVERITY_ERROR,
		"Error issue should carry error severity")


func test_add_warning_records_issue_expected() -> void:
	var result: FleetValidationResult = FleetValidationResult.new()

	result.add_warning("fleet.rules.pending", "Some card rules are not integrated.")

	assert_true(result.is_valid(), "Warnings alone should keep the roster valid")
	assert_eq(result.warnings.size(), 1, "Should store one warning")
	assert_eq(result.warnings[0].get("severity", ""), FleetValidationResult.SEVERITY_WARNING,
		"Warning issue should carry warning severity")


func test_serialize_deep_copies_issue_arrays_expected() -> void:
	var result: FleetValidationResult = FleetValidationResult.new()
	result.add_error("fleet.unique", "Duplicate unique card.", ["ship-1"], [])

	var serialized: Dictionary = result.serialize()
	var errors: Array = serialized.get("errors", []) as Array
	errors[0]["message"] = "Changed outside result."

	assert_eq(result.errors[0].get("message", ""), "Duplicate unique card.",
		"Serialized issue data should not alias result state")


func test_deserialize_serialize_round_trip_expected() -> void:
	var source: Dictionary = {
		"errors": [{
			"severity": "ERROR",
			"rule_id": "fleet.commander.required",
			"message": "A fleet needs one commander.",
			"affected_entry_ids": [],
			"source_refs": ["Rules Reference: Fleet Building"],
		}],
		"warnings": [],
	}

	var result: FleetValidationResult = FleetValidationResult.deserialize(source)

	assert_eq(result.serialize(), source, "Validation result should round-trip")


func test_deserialize_missing_fields_uses_defaults_expected() -> void:
	var result: FleetValidationResult = FleetValidationResult.deserialize({})

	assert_true(result.errors.is_empty(), "Missing errors should default empty")
	assert_true(result.warnings.is_empty(), "Missing warnings should default empty")
	assert_true(result.is_valid(), "Empty validation result should be valid")

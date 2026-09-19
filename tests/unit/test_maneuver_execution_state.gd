extends GutTest


const ACTIVATION_ID := "ship-activation:42"
const EXECUTION_ID := "maneuver:7"

var _ship: ShipInstance


func before_each() -> void:
	_ship = ShipInstance.new()
	assert_true(_ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(_ship.open_maneuver_opportunity(ACTIVATION_ID))


func test_commit_creates_exact_private_execution_record() -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true, _committed_result(),
			{"kind": "none"}))
	assert_true(_ship.has_active_maneuver_execution())
	assert_eq(_ship.active_maneuver_execution_snapshot(), {
		"maneuver_execution_id": EXECUTION_ID,
		"ship_activation_identity": ACTIVATION_ID,
		"navigate_speed_changed": true,
		"final_transform_applied": false,
		"committed_result": _committed_result(),
		"obstacle_resolution_order": [],
		"ship_collision": {"kind": "none"},
	})
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)


func test_commit_rejects_stale_duplicate_and_bad_collision_without_mutation() -> void:
	var before: Dictionary = _ship.ship_activation_boundary_snapshot()
	assert_false(_ship.commit_maneuver_execution(
			"stale", EXECUTION_ID, false, _committed_result(),
			{"kind": "none"}))
	assert_eq(_ship.ship_activation_boundary_snapshot(), before)
	assert_false(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, _committed_result(),
			{"kind": "closest_ship", "target_owner_player": 1}))
	assert_eq(_ship.ship_activation_boundary_snapshot(), before)
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, _committed_result(),
			{"kind": "none"}))
	var committed: Dictionary = _ship.ship_activation_boundary_snapshot()
	assert_false(_ship.commit_maneuver_execution(
			ACTIVATION_ID, "maneuver:8", true, _committed_result(),
			{"kind": "none"}))
	assert_eq(_ship.ship_activation_boundary_snapshot(), committed)


func test_closest_collision_requires_exact_derived_key() -> void:
	var collision: Dictionary = {
		"kind": "closest_ship",
		"target_owner_player": 1,
		"target_ship_index": 3,
		"exact_once_key": "collision:%s:%s:1:3" % [
			ACTIVATION_ID, EXECUTION_ID],
		"damage_resolved": false,
	}
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, _committed_result(), collision))
	assert_false(_ship.mark_maneuver_ship_collision_damage_resolved(
			ACTIVATION_ID, EXECUTION_ID, "wrong"))
	assert_true(_ship.mark_maneuver_ship_collision_damage_resolved(
			ACTIVATION_ID, EXECUTION_ID, collision["exact_once_key"]))
	assert_true(bool(_ship.active_maneuver_execution_snapshot()[
			"ship_collision"]["damage_resolved"]))
	assert_false(_ship.mark_maneuver_ship_collision_damage_resolved(
			ACTIVATION_ID, EXECUTION_ID, collision["exact_once_key"]))


func test_obstacle_order_is_identity_bound_unique_and_immutable() -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, _committed_result(),
			{"kind": "none"}))
	assert_false(_ship.commit_maneuver_obstacle_order(
			ACTIVATION_ID, EXECUTION_ID, ["obstacle:1", "obstacle:1"]))
	assert_true(_ship.commit_maneuver_obstacle_order(
			ACTIVATION_ID, EXECUTION_ID, ["obstacle:2", "obstacle:1"]))
	assert_false(_ship.commit_maneuver_obstacle_order(
			ACTIVATION_ID, EXECUTION_ID, ["obstacle:1", "obstacle:2"]))
	assert_eq(_ship.active_maneuver_execution_snapshot()[
			"obstacle_resolution_order"], ["obstacle:2", "obstacle:1"])


func test_normal_completion_requires_fresh_positive_proof() -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, _committed_result(),
			{"kind": "none"}))
	assert_false(_ship.complete_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false))
	assert_true(_ship.has_active_maneuver_execution())
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)
	assert_false(_ship.complete_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true),
			"Normal completion cannot precede final-transform application.")
	assert_false(_ship.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	assert_true(_ship.complete_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true))
	assert_false(_ship.has_active_maneuver_execution())
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_CONSUMED)
	assert_false(_ship.complete_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true))


func test_destruction_clears_execution_without_consumed_state() -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, _committed_result(),
			{"kind": "none"}))
	_ship.mark_destroyed()
	assert_false(_ship.has_active_ship_activation())
	assert_false(_ship.has_active_maneuver_execution())
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_INACTIVE)
	assert_true(_ship.validate_ship_activation_boundary())


func test_boundary_snapshot_restores_execution_atomically() -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true, _committed_result(),
			{"kind": "none"}))
	var before: Dictionary = _ship.ship_activation_boundary_snapshot()
	assert_true(_ship.clear_maneuver_execution_exceptionally(
			ACTIVATION_ID, EXECUTION_ID))
	assert_true(_ship.restore_ship_activation_boundary(before))
	assert_eq(_ship.ship_activation_boundary_snapshot(), before)


func test_save7_maneuver_and_purpose_records_are_strict() -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true, _committed_result(),
			{"kind": "none"}))
	assert_true(_ship.serialize().has("active_maneuver_execution"))
	var future: Dictionary = _ship.serialize_maneuver_execution_for_save7()
	assert_eq(future.keys(), ["active_maneuver_execution",
			"active_asteroid_resolution", "active_debris_resolution",
			"active_station_resolution"])

	var restored := ShipInstance.new()
	assert_true(restored.establish_ship_activation(ACTIVATION_ID))
	assert_true(restored.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(restored.install_maneuver_execution_for_save7(
			future))
	assert_eq(restored.active_maneuver_execution_snapshot(),
			_ship.active_maneuver_execution_snapshot())

	var invalid: Dictionary = future.duplicate(true)
	invalid["unexpected"] = true
	var snapshot: Dictionary = restored.ship_activation_boundary_snapshot()
	assert_false(restored.install_maneuver_execution_for_save7(invalid))
	assert_eq(restored.ship_activation_boundary_snapshot(), snapshot)


func test_record_rejects_install_without_matching_open_owner() -> void:
	var record: Dictionary = {
		"maneuver_execution_id": EXECUTION_ID,
		"ship_activation_identity": ACTIVATION_ID,
		"navigate_speed_changed": false,
		"final_transform_applied": false,
		"committed_result": _committed_result(),
		"obstacle_resolution_order": [],
		"ship_collision": {"kind": "none"},
	}
	var inactive := ShipInstance.new()
	assert_false(inactive.install_maneuver_execution_for_save7({
		"active_maneuver_execution": record,
		"active_asteroid_resolution": {},
		"active_debris_resolution": {},
		"active_station_resolution": {},
	}))
	assert_false(inactive.has_active_maneuver_execution())


func _committed_result() -> Dictionary:
	return {
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
		"pos_x": 0.25,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
	}

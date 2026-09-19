extends GutTest


func test_protocol7_candidate_routes_deserialize_to_purpose_specific_commands() -> void:
	var expected: Dictionary = {
		"execute_maneuver": CandidateExecuteManeuverCommand,
		"apply_maneuver_transform": CandidateApplyManeuverTransformCommand,
		"complete_maneuver": CandidateCompleteManeuverCommand,
		"commit_maneuver_obstacle_order": CandidateCommitManeuverObstacleOrderCommand,
		"resolve_ship_collision_damage": CandidateResolveShipCollisionDamageCommand,
		"resolve_thruster_fissure": CandidateResolveThrusterFissureCommand,
		"resolve_damaged_controls": CandidateResolveDamagedControlsCommand,
		"resolve_asteroid_overlap": CandidateResolveAsteroidOverlapCommand,
		"resolve_debris_overlap": CandidateResolveDebrisOverlapCommand,
		"resolve_station_overlap": CandidateResolveStationOverlapCommand,
		"resolve_ruptured_engine": CandidateResolveRupturedEngineCommand,
		"resolve_damage": CandidateResolveDamageCommand,
		"resolve_immediate_effect": CandidateResolveImmediateEffectCommand,
		"debug_deal_damage": CandidateDebugDealDamageCommand,
		"start_displacement": CandidateStartDisplacementCommand,
		"commit_displacement": CandidateCommitDisplacementCommand,
	}
	for command_type: String in expected:
		var command: GameCommand = GameCommand.deserialize({
			"type": command_type, "player": 0, "sequence": 7,
			"payload": {},
		})
		assert_not_null(command, command_type)
		if command != null:
			assert_true(is_instance_of(command, expected[command_type]),
					command_type)


func test_coordinated_compatibility_versions_are_active_together() -> void:
	assert_eq(SaveGameMetadata.CURRENT_VERSION, 7)
	assert_eq(GameReplay.FORMAT_VERSION, 10)
	assert_eq(NetworkManager.PROTOCOL_VERSION, 7)
	assert_eq(GameCommand.APPLICATION_CONTRACT_VERSION, 2)
	assert_eq(PassiveDamageLedger.SCHEMA_VERSION, 1)


func test_protocol7_command_envelope_restores_only_declared_integer_fields() -> void:
	var obstacle_order: GameCommand = GameCommand.deserialize({
		"type": "commit_maneuver_obstacle_order", "player": 0.0,
		"sequence": 4.0, "payload": {
			"owner_player": 0.0, "ship_index": 1.0,
			"ship_activation_identity": "activation:4",
			"maneuver_execution_id": "maneuver:4",
			"obstacle_ids": ["obstacle:0", "obstacle:1"],
		},
	})
	assert_not_null(obstacle_order)
	assert_eq(obstacle_order.payload["owner_player"], 0)
	assert_eq(obstacle_order.payload["ship_index"], 1)
	assert_eq(obstacle_order.payload["obstacle_ids"],
			["obstacle:0", "obstacle:1"])

	var displacement: GameCommand = GameCommand.deserialize({
		"type": "commit_displacement", "player": 1.0, "sequence": 5.0,
		"payload": {
			"owner_player": 0.0, "ship_index": 2.0,
			"ship_activation_identity": "activation:4",
			"maneuver_execution_id": "maneuver:4",
			"placements": [{"owner": 1.0, "squadron_index": 3.0,
				"pos_x": 0.25, "pos_y": 0.5}],
			"excluded_squadrons": [
				{"owner": 1.0, "squadron_index": 4.0}],
		},
	})
	assert_not_null(displacement)
	assert_eq(displacement.payload["owner_player"], 0)
	assert_eq(displacement.payload["ship_index"], 2)
	assert_eq(displacement.payload["placements"][0]["owner"], 1)
	assert_eq(displacement.payload["placements"][0]["squadron_index"], 3)
	assert_eq(displacement.payload["excluded_squadrons"][0]["owner"], 1)
	assert_eq(displacement.payload["excluded_squadrons"][0][
			"squadron_index"], 4)

	var shield_failure: GameCommand = GameCommand.deserialize({
		"type": "resolve_immediate_effect", "player": 1.0,
		"sequence": 6.0, "payload": {
			"owner_player": 0.0, "ship_index": 0.0,
			"public_card_ref": "faceup:1:0",
			"immediate_resolution_id": "immediate:faceup:1:0",
			"enclosing_kind": "attack", "attack_id": "attack:1",
			"shield_zones": ["front", "left"],
		},
	})
	assert_not_null(shield_failure)
	assert_eq(shield_failure.payload["shield_zones"], ["front", "left"])

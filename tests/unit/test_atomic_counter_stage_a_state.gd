## Stage A: canonical Counter disposition, inspection witness, and reconstruction.
extends GutTest


const AttackFixture: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")


func test_counter_disposition_exact_schema_and_json() -> void:
	var state := CurrentAttackState.new()
	var inactive: Dictionary = state.serialize()
	assert_eq(inactive["counter_disposition"], "")
	assert_true(state.load_from_serialized(
			JSON.parse_string(JSON.stringify(inactive))))
	var missing: Dictionary = inactive.duplicate(true)
	missing.erase("counter_disposition")
	assert_false(state.load_from_serialized(missing))
	var invalid: Dictionary = inactive.duplicate(true)
	invalid["counter_disposition"] = CurrentAttackState.COUNTER_ACCEPTED
	assert_false(state.load_from_serialized(invalid))
	var parent: GameState = _resolved_parent(1)
	assert_not_null(parent)
	if parent == null:
		return
	for disposition: String in [CurrentAttackState.COUNTER_ACCEPTED,
			CurrentAttackState.COUNTER_DECLINED]:
		var decided: CurrentAttackState = parent.current_attack_state.with_patch(
				{"counter_disposition": disposition})
		assert_not_null(decided)
		if decided == null:
			continue
		var restored := CurrentAttackState.new()
		assert_true(restored.load_from_serialized(
				JSON.parse_string(JSON.stringify(decided.serialize()))))
		assert_eq(restored.serialize(), decided.serialize())
		assert_eq(restored.counter_disposition, disposition)
	var early: CurrentAttackState = AttackFixture.install(_empty_state(), {
		"attacker_kind": "squadron", "defender_kind": "squadron",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
	})
	assert_not_null(early)
	if early != null:
		assert_null(early.with_patch({"counter_disposition":
				CurrentAttackState.COUNTER_ACCEPTED}))


func test_pending_and_decided_reconstruction_checks_source_and_damage() -> void:
	for requested: int in [0, 1, 5]:
		var state: GameState = _resolved_parent(requested)
		assert_not_null(state)
		if state == null:
			continue
		var base: Dictionary = state.serialize()
		assert_not_null(_roundtrip(base), "Before publication remains recoverable.")
		state.interaction_flow = _counter_flow(requested)
		var pending: Dictionary = state.serialize()
		var restored: GameState = _roundtrip(pending)
		assert_not_null(restored)
		if restored != null:
			assert_eq(restored.interaction_flow.serialize(),
					state.interaction_flow.serialize())
			assert_eq(restored.current_attack_state.serialize(),
					state.current_attack_state.serialize())
			assert_eq(CanonicalJson.hash(restored.serialize()),
					CanonicalJson.hash(state.serialize()))
		var filtered: Dictionary = StateFilter.filter_for_player_checked(
				state.serialize(), 1)
		assert_true(bool(filtered.get(StateFilter.KEY_OK, false)))
		if bool(filtered.get(StateFilter.KEY_OK, false)):
			var direct_passive: GameState = GameState.deserialize_passive_network(
					filtered[StateFilter.KEY_STATE] as Dictionary)
			assert_not_null(direct_passive)
			if direct_passive != null:
				assert_eq(direct_passive.current_attack_state.serialize(),
						state.current_attack_state.serialize())
		var wrong_source: Dictionary = pending.duplicate(true)
		wrong_source["interaction_flow"]["payload"]["attack_id"] = "attack:stale"
		assert_null(_roundtrip(wrong_source))
		var wrong_damage: Dictionary = pending.duplicate(true)
		wrong_damage["interaction_flow"]["payload"]["final_damage"] = requested + 1
		assert_null(_roundtrip(wrong_damage))
		var malformed: Dictionary = pending.duplicate(true)
		malformed["current_attack_state"]["resolved_outcome"][
				"requested_hull_damage"] = "1"
		assert_null(_roundtrip(malformed))
		for bad: Variant in [-1, 0.5, INF, NAN, null]:
			var bad_outcome: Dictionary = pending.duplicate(true)
			bad_outcome["current_attack_state"]["resolved_outcome"][
					"requested_hull_damage"] = bad
			assert_null(GameState.deserialize(bad_outcome))
			var bad_publication: Dictionary = pending.duplicate(true)
			bad_publication["interaction_flow"]["payload"][
					"final_damage"] = bad
			assert_null(GameState.deserialize(bad_publication))
		var decided_hashes: Dictionary = {}
		for disposition: String in [CurrentAttackState.COUNTER_ACCEPTED,
				CurrentAttackState.COUNTER_DECLINED]:
			var decided: Dictionary = pending.duplicate(true)
			decided["current_attack_state"]["counter_disposition"] = disposition
			decided["interaction_flow"]["payload"]["counter_choice_accepted"] = \
					disposition == CurrentAttackState.COUNTER_ACCEPTED
			var restored_decided: GameState = _roundtrip(decided)
			assert_not_null(restored_decided)
			if restored_decided != null:
				decided_hashes[disposition] = CanonicalJson.hash(
						restored_decided.serialize())
				assert_eq(CanonicalJson.hash(restored_decided.serialize()),
						CanonicalJson.hash(decided))
			decided["interaction_flow"]["payload"].erase(
					"counter_choice_accepted")
			assert_null(_roundtrip(decided))
		assert_ne(decided_hashes.get(CurrentAttackState.COUNTER_ACCEPTED),
				decided_hashes.get(CurrentAttackState.COUNTER_DECLINED))
		var invalid_pool: Dictionary = pending.duplicate(true)
		invalid_pool["interaction_flow"]["payload"]["counter_dice_pool"] = \
				{"BLUE": 1}
		assert_null(_roundtrip(invalid_pool))
		var invalid_role: Dictionary = pending.duplicate(true)
		invalid_role["interaction_flow"]["payload"][
				"counter_target_player"] = 1
		assert_null(_roundtrip(invalid_role))
		var invalid_retained: Dictionary = pending.duplicate(true)
		invalid_retained["interaction_flow"]["payload"][
				"attacker_player"] = 1
		assert_null(_roundtrip(invalid_retained))
		var invalid_controller: Dictionary = pending.duplicate(true)
		invalid_controller["interaction_flow"]["controller_player"] = 0
		assert_null(_roundtrip(invalid_controller))
		var invalid_available: Dictionary = pending.duplicate(true)
		invalid_available["interaction_flow"]["payload"][
				"counter_attack_available"] = false
		assert_null(_roundtrip(invalid_available))


func test_legitimate_inspection_witness_is_immutable_and_json_exact() -> void:
	var state: GameState = _resolved_parent(1)
	assert_not_null(state)
	if state == null:
		return
	var parent: CurrentAttackState = state.current_attack_state.with_patch(
			{"counter_disposition": CurrentAttackState.COUNTER_ACCEPTED})
	var required: Array[String] = [state.principal_id_for_player(0)]
	var inspection: CompletedAttackInspection = \
			CompletedAttackInspection.create_from_attack(parent,
					parent.resolved_outcome, required)
	assert_not_null(inspection)
	if inspection == null:
		return
	assert_eq(inspection.counter_disposition(),
			CurrentAttackState.COUNTER_ACCEPTED)
	var raw: Dictionary = inspection.serialize()
	var restored: CompletedAttackInspection = \
			CompletedAttackInspection.deserialize(
					JSON.parse_string(JSON.stringify(raw)))
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.serialize(), raw)
		var acknowledged: CompletedAttackInspection = \
				restored.acknowledged_by(required[0])
		assert_not_null(acknowledged)
		if acknowledged != null:
			assert_eq(acknowledged.counter_disposition(),
					CurrentAttackState.COUNTER_ACCEPTED)
	raw.erase("counter_disposition")
	assert_null(CompletedAttackInspection.deserialize(raw))
	var inactive := CurrentAttackState.inactive()
	assert_true(state.set_current_attack_state(inactive))
	assert_true(state.install_completed_attack_inspection(inspection))
	state.interaction_flow = _counter_flow(1)
	state.interaction_flow.payload["counter_choice_accepted"] = true
	var reconstructed: GameState = _roundtrip(state.serialize())
	assert_not_null(reconstructed)
	if reconstructed != null:
		assert_eq(CanonicalJson.hash(reconstructed.serialize()),
				CanonicalJson.hash(state.serialize()))
	var invalid: Dictionary = state.serialize()
	invalid["completed_attack_inspection"]["counter_disposition"] = \
			CurrentAttackState.COUNTER_DECLINED
	assert_null(_roundtrip(invalid))
	var declined: Dictionary = state.serialize()
	declined["completed_attack_inspection"]["counter_disposition"] = \
			CurrentAttackState.COUNTER_DECLINED
	declined["interaction_flow"] = InteractionFlow.new().serialize()
	var reconstructed_decline: GameState = _roundtrip(declined)
	assert_not_null(reconstructed_decline)
	if reconstructed_decline != null:
		assert_eq(CanonicalJson.hash(reconstructed_decline.serialize()),
				CanonicalJson.hash(declined))
		assert_ne(CanonicalJson.hash(reconstructed_decline.serialize()),
				CanonicalJson.hash(state.serialize()))
	var lost_witness: Dictionary = declined.duplicate(true)
	lost_witness["completed_attack_inspection"]["counter_disposition"] = ""
	assert_null(_roundtrip(lost_witness))
	var stale_source: Dictionary = state.serialize()
	stale_source["completed_attack_inspection"]["source_attack_id"] = \
			"attack:72"
	stale_source["completed_attack_inspection"]["inspection_id"] = \
			"completed:attack:72"
	assert_null(_roundtrip(stale_source))


func _empty_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human())
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck
	return state


func _resolved_parent(requested: int) -> GameState:
	var state: GameState = _empty_state()
	var counter := SquadronInstance.create_from_data(
			"tie_interceptor_squadron",
			AssetLoader.load_squadron_data("tie_interceptor_squadron"), 1)
	counter.roster_entry_id = "stage-a-counter"
	if requested >= 3:
		counter.mark_destroyed()
	state.get_player_state(1).squadrons.append(counter)
	var parent: CurrentAttackState = AttackFixture.install(state, {
		"attack_id": "attack:71", "attacker_kind": "squadron",
		"defender_kind": "squadron",
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"resolved_outcome": {"target_kind": "squadron",
			"requested_hull_damage": requested,
			"actual_hull_damage": mini(requested, 3),
			"post_resolution_hull": maxi(0, 3 - requested),
			"destroyed": requested >= 3},
	})
	return state if parent != null else null


func _counter_flow(final_damage: int) -> InteractionFlow:
	return InteractionFlow.make(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			1, Constants.Visibility.ALL, {
				"attack_id": "attack:71",
				"counter_attack_available": true,
				"counter_controller_player": 1,
				"counter_attacker_player": 1,
				"counter_attacker_squadron_index": 0,
				"counter_target_player": 0,
				"counter_target_squadron_index": 0,
				"counter_dice_pool": {"BLUE": 2},
				"final_damage": final_damage,
			})


func _roundtrip(raw: Dictionary) -> GameState:
	var parsed: Variant = JSON.parse_string(JSON.stringify(raw))
	return GameState.deserialize(parsed as Dictionary)


func test_version_gates_reject_obsolete_formats() -> void:
	assert_eq(SaveGameMetadata.CURRENT_VERSION, 11)
	assert_eq(NetworkManager.PROTOCOL_VERSION, 12)
	assert_eq(GameReplay.FORMAT_VERSION, 13)
	var metadata := SaveGameMetadata.new()
	metadata.save_format_version = 10
	assert_eq(metadata.validate().get("reason"), "version_unsupported")
	var replay := GameReplay.new()
	replay.capture_header("stage_a", 1, [0, 1], 0, 0,
			MatchPlayerControlBinding.create_hot_seat_human().serialize())
	assert_not_null(GameReplay.deserialize(replay.serialize()))
	var obsolete: Dictionary = replay.serialize()
	obsolete["header"]["format_version"] = 12
	assert_null(GameReplay.deserialize(obsolete))

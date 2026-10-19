## Stage C: one ordered, owner-derived Counter publication after damage.
extends GutTest


const PROCESSOR: GDScript = preload("res://src/autoload/command_processor.gd")
const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

var _previous_state: GameState
var _state: GameState
var _processor: Node
var _observed_boundaries: Array[Dictionary] = []


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_state = _damage_state([Constants.DiceFace.HIT], 3)
	GameManager.current_game_state = _state
	_processor = PROCESSOR.new()
	add_child_autofree(_processor)
	_processor.command_executed.connect(_record_boundary)
	_observed_boundaries.clear()


func after_each() -> void:
	GameManager.current_game_state = _previous_state


func test_damage_commits_before_one_complete_publication_for_three_totals() -> void:
	for specimen: Dictionary in [
			{"faces": [Constants.DiceFace.BLANK], "hull": 3,
				"requested": 0, "actual": 0},
			{"faces": [Constants.DiceFace.HIT], "hull": 3,
				"requested": 1, "actual": 1},
			{"faces": [Constants.DiceFace.HIT, Constants.DiceFace.HIT],
				"hull": 1, "requested": 2, "actual": 1},
	]:
		_state = _damage_state(specimen["faces"], specimen["hull"])
		GameManager.current_game_state = _state
		_processor.reset()
		_observed_boundaries.clear()
		var before: Dictionary = _state.interaction_flow.serialize()
		var result: Dictionary = _processor.submit(
				ResolveDamageCommand.new(0, {"attack_id": "attack:71"}))
		assert_false(result.is_empty(), str(specimen))
		assert_eq(_processor.get_command_count(), 2, str(specimen))
		assert_eq(_processor.get_history()[0].command_type, "resolve_damage")
		assert_eq(_processor.get_history()[1].command_type,
				"publish_attack_flow")
		assert_eq(_observed_boundaries.size(), 2, str(specimen))
		assert_eq(_observed_boundaries[0]["command"], "resolve_damage")
		assert_ne(_observed_boundaries[0]["step"],
				Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
		assert_eq(_observed_boundaries[1]["command"],
				"publish_attack_flow")
		assert_eq(_observed_boundaries[1]["step"],
				Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
		var publication: GameCommand = _processor.get_history()[1]
		assert_eq(publication.sequence, 1)
		assert_eq(publication.payload["source_attack_id"], "attack:71")
		assert_eq(publication.payload["flow_payload"]["final_damage"],
				specimen["requested"])
		assert_eq(_state.current_attack_state.resolved_outcome[
				"actual_hull_damage"], specimen["actual"])
		assert_eq(_state.interaction_flow.step_id,
				Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
		assert_eq(_state.interaction_flow.controller_player, 1)
		assert_eq(typeof(_state.interaction_flow.payload["final_damage"]),
				TYPE_INT)
		assert_ne(_state.interaction_flow.serialize(), before)
		var restored: GameState = GameState.deserialize(
				JSON.parse_string(JSON.stringify(_state.serialize())) as Dictionary)
		assert_not_null(restored, str(specimen))
		if restored != null:
			assert_eq(CanonicalJson.hash(restored.serialize()),
					CanonicalJson.hash(_state.serialize()), str(specimen))


func test_lost_publication_is_derived_once_from_reconstructed_owners() -> void:
	var damage := ResolveDamageCommand.new(0, {"attack_id": "attack:71"})
	assert_eq(damage.validate(_state), "")
	assert_false(damage.execute(_state).is_empty())
	var before: Dictionary = _state.interaction_flow.serialize()
	var restored: GameState = GameState.deserialize(
			JSON.parse_string(JSON.stringify(_state.serialize())) as Dictionary)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.interaction_flow.serialize(), before)
	var publication: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_resolved_attack(restored)
	assert_not_null(publication)
	if publication == null:
		return
	assert_eq(publication.command_type, "publish_attack_flow")
	assert_eq(publication.validate(restored), "")
	assert_false(publication.execute(restored).is_empty())
	assert_null(CurrentAttackContinuation \
			.derive_reconstructed_resolved_attack(restored))
	assert_eq(restored.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE)


func test_bad_canonical_requested_damage_never_publishes_or_mutates() -> void:
	var damage := ResolveDamageCommand.new(0, {"attack_id": "attack:71"})
	assert_false(damage.execute(_state).is_empty())
	var attack: CurrentAttackState = _state._current_attack_state
	var expected: int = int(attack.resolved_outcome["requested_hull_damage"])
	for invalid: Variant in ["1", 1.5, -1, INF]:
		# Corrupt only the test's in-memory owner to exercise the producer's
		# fail-closed boundary; normal owner installation rejects/normalizes it.
		attack._data["resolved_outcome"]["requested_hull_damage"] = invalid
		var before: Dictionary = _state.serialize()
		assert_null(CurrentAttackContinuation \
				.derive_reconstructed_resolved_attack(_state), str(invalid))
		assert_eq(_state.serialize(), before)
		assert_eq(_processor.get_command_count(), 0)
		attack._data["resolved_outcome"]["requested_hull_damage"] = expected


func test_host_player_route_rejects_counter_publication_without_mutation() -> void:
	var damage := ResolveDamageCommand.new(0, {"attack_id": "attack:71"})
	assert_false(damage.execute(_state).is_empty())
	var publication: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_resolved_attack(_state)
	assert_not_null(publication)
	if publication == null:
		return
	var direct: GameCommand = publication
	var decoded: GameCommand = GameCommand.deserialize(
			JSON.parse_string(JSON.stringify(publication.serialize())) as Dictionary)
	assert_not_null(decoded)
	var submitter := NetworkHostCommandSubmitter.new()
	for candidate: GameCommand in [direct, decoded]:
		if candidate == null:
			continue
		assert_true(PublishAttackFlowCommand.is_counter_step_submission(
				candidate))
		var before: Dictionary = _state.serialize()
		var followups_before: int = _processor \
				.get_pending_observer_followup_count()
		assert_true(submitter.submit(candidate).is_empty())
		assert_eq(_state.serialize(), before)
		assert_eq(_processor.get_command_count(), 0)
		assert_eq(_processor.get_next_sequence(), 0)
		assert_eq(_processor.get_pending_observer_followup_count(),
				followups_before)
	assert_eq(publication.validate(_state), "")


func _record_boundary(command: GameCommand, _result: Dictionary) -> void:
	_observed_boundaries.append({
		"command": command.command_type,
		"step": _state.interaction_flow.step_id,
	})


func _damage_state(faces: Array, remaining_hull: int) -> GameState:
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
	var counter := SquadronInstance.create_from_data(
			"tie_interceptor_squadron",
			AssetLoader.load_squadron_data("tie_interceptor_squadron"), 1)
	counter.roster_entry_id = "stage-c-counter"
	counter.current_hull = remaining_hull
	state.get_player_state(1).squadrons.append(counter)
	var dice: Array = []
	for face: Variant in faces:
		dice.append({"color": int(Constants.DiceColor.RED),
			"face": int(face)})
	assert_not_null(ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:71", "attacker_kind": "squadron",
		"defender_kind": "squadron",
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"dice_pool": {"RED": faces.size()},
		"dice_results": dice,
	}))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"attack_id": "attack:71"})
	return state

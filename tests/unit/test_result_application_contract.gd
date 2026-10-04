extends GutTest


const CF_PRODUCTION: GDScript = preload(
		"res://tests/fixtures/bug071_production_attack_builder.gd")
const CF_DIAL_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_dial_command.gd")

var _saved_state: GameState


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	var state := GameState.new()
	state.initialize()
	GameManager.current_game_state = state
	CommandProcessor.reset()


func after_each() -> void:
	CommandProcessor.reset()
	RuleRegistry.clear()
	GameManager.current_game_state = _saved_state


func _envelope(application: Dictionary = {}) -> Dictionary:
	return {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": "fixture_result",
		"application_contract_version": GameCommand.APPLICATION_CONTRACT_VERSION,
		"viewer_player": 1,
		"application_result": application,
		"presentation_result": {},
		"maneuver_consequence_view": {},
	}


func _command(sequence: int = 0) -> FixtureResultCommand:
	var command := FixtureResultCommand.new()
	command.sequence = sequence
	return command


func test_present_empty_application_result_commits_once() -> void:
	var command := _command()
	assert_eq(CommandProcessor.submit_mirror(command, _envelope(), 1),
			{"applied": true})
	assert_eq(GameManager.current_game_state.current_round, 1)
	assert_eq(CommandProcessor.get_next_sequence(), 1)
	assert_eq(CommandProcessor.get_command_count(), 1)


func test_missing_application_result_is_not_empty_application_result() -> void:
	var envelope := _envelope()
	envelope.erase("application_result")
	assert_eq(CommandProcessor.submit_mirror(_command(), envelope, 1), {})
	assert_eq(GameManager.current_game_state.current_round, 0)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_engine_error(1)


func test_wrong_binding_and_unknown_envelope_fields_fail_closed() -> void:
	for patch: Dictionary in [
		{"application_contract": "wrong"},
		{"application_contract_version": GameCommand.APPLICATION_CONTRACT_VERSION + 1},
		{"viewer_player": 0},
		{"protocol_version": NetworkManager.PROTOCOL_VERSION - 1},
		{"unknown": true},
		{"maneuver_consequence_view": "missing"},
	]:
		var envelope := _envelope()
		envelope.merge(patch, true)
		assert_eq(CommandProcessor.submit_mirror(_command(), envelope, 1), {})
		assert_eq(GameManager.current_game_state.current_round, 0)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_engine_error(6)


func test_malformed_application_result_does_not_mutate_or_record() -> void:
	assert_eq(CommandProcessor.submit_mirror(
			_command(), _envelope({"forbidden": true}), 1), {})
	assert_eq(GameManager.current_game_state.current_round, 0)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_engine_error(1)


func test_real_cf_dial_result_applies_without_passive_rng_for_both_roles() -> void:
	for attacker_player: int in [0, 1]:
		var context: Dictionary = CF_PRODUCTION.committed_dial(attacker_player)
		assert_false(context.is_empty())
		if context.is_empty():
			continue
		var authority: GameState = context["state"] as GameState
		var before: Dictionary = authority.serialize()
		var sequence: int = int(context["command_sequence"])
		var command: GameCommand = CF_DIAL_USE.new(
				attacker_player, context["dial_payload"])
		var result: Dictionary = CommandProcessor.submit_deferred_followups(
				command)
		assert_false(result.is_empty())
		var envelope: Dictionary = NetworkManager._build_result_envelope(
				command, result, attacker_player)
		var passive: GameState = GameState.deserialize_passive_network(
				StateFilter.filter_for_player(before, attacker_player))
		assert_not_null(passive)
		if passive == null:
			continue
		assert_null(passive.rng)
		GameManager.current_game_state = passive
		CommandProcessor.reset()
		assert_true(CommandProcessor.restore_next_sequence(sequence))
		var mirrored: GameCommand = GameCommand.deserialize(command.serialize())
		assert_not_null(mirrored)
		assert_false(CommandProcessor.submit_mirror(
				mirrored, envelope, attacker_player).is_empty())
		assert_eq(passive.current_attack_state.dice_results,
				authority.current_attack_state.dice_results)
		assert_eq(passive.current_attack_state.dice_pool,
				authority.current_attack_state.dice_pool)
		assert_eq(passive.current_attack_state.cf_dial_resolution,
				CurrentAttackState.RESOLUTION_USED)
		assert_eq(CommandProcessor.get_next_sequence(), sequence + 1)


func test_real_cf_dial_bad_results_reject_atomically_then_valid_recovers() -> void:
	var context: Dictionary = CF_PRODUCTION.committed_dial(1)
	assert_false(context.is_empty())
	if context.is_empty():
		return
	var authority: GameState = context["state"] as GameState
	var before: Dictionary = authority.serialize()
	var sequence: int = int(context["command_sequence"])
	var command: GameCommand = CF_DIAL_USE.new(1, context["dial_payload"])
	var result: Dictionary = CommandProcessor.submit_deferred_followups(command)
	assert_false(result.is_empty())
	var valid: Dictionary = NetworkManager._build_result_envelope(
			command, result, 1)
	var passive: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(before, 1))
	assert_not_null(passive)
	if passive == null:
		return
	GameManager.current_game_state = passive
	for bad_patch: Dictionary in [
		{"application_result": {}},
		{"application_result": {"new_face": "hit"}},
		{"application_result": {"new_face": 999}},
		{"application_contract": "wrong"},
		{"application_contract_version": 3},
		{"viewer_player": 0},
	]:
		CommandProcessor.reset()
		assert_true(CommandProcessor.restore_next_sequence(sequence))
		var invalid: Dictionary = valid.duplicate(true)
		invalid.merge(bad_patch, true)
		var before_reject: Dictionary = passive.serialize()
		assert_eq(CommandProcessor.submit_mirror(
				GameCommand.deserialize(command.serialize()), invalid, 1), {})
		assert_eq(passive.serialize(), before_reject)
		assert_eq(CommandProcessor.get_next_sequence(), sequence)
		assert_eq(CommandProcessor.get_command_count(), 0)
	var missing: Dictionary = valid.duplicate(true)
	missing.erase("application_result")
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(sequence))
	assert_eq(CommandProcessor.submit_mirror(
			GameCommand.deserialize(command.serialize()), missing, 1), {})
	assert_eq(passive.serialize(), StateFilter.filter_for_player(before, 1))
	for bad_payload: Dictionary in [
		{"attack_id": "attack:stale"},
		{"ship_activation_identity": "ship-activation:stale"},
		{"round": 2},
		{"lifecycle_id": "attack_modify:stale"},
		{"color": "GREEN"},
		{"runtime_source_id": "wrong:source"},
	]:
		var forged_payload: Dictionary = command.payload.duplicate(true)
		forged_payload.merge(bad_payload, true)
		var forged: GameCommand = CF_DIAL_USE.new(1, forged_payload)
		forged.sequence = sequence
		assert_eq(CommandProcessor.submit_mirror(forged, valid, 1), {})
		assert_eq(passive.serialize(), StateFilter.filter_for_player(before, 1))
		assert_eq(CommandProcessor.get_next_sequence(), sequence)
	var wrong_player: GameCommand = CF_DIAL_USE.new(0,
			command.payload.duplicate(true))
	wrong_player.sequence = sequence
	assert_eq(CommandProcessor.submit_mirror(wrong_player, valid, 1), {})
	assert_eq(passive.serialize(), StateFilter.filter_for_player(before, 1))
	assert_false(CommandProcessor.submit_mirror(
			GameCommand.deserialize(command.serialize()), valid, 1).is_empty())
	assert_eq(passive.current_attack_state.dice_results,
			authority.current_attack_state.dice_results)
	assert_eq(CommandProcessor.get_next_sequence(), sequence + 1)
	var after_success: Dictionary = passive.serialize()
	assert_eq(CommandProcessor.submit_mirror(
			GameCommand.deserialize(command.serialize()), valid, 1), {})
	assert_eq(passive.serialize(), after_success)
	assert_eq(CommandProcessor.get_next_sequence(), sequence + 1)
	assert_engine_error(15)


class FixtureResultCommand extends GameCommand:
	func _init() -> void:
		super._init(0, "debug_deal_damage", {})

	func application_contract_id() -> String:
		return "fixture_result"

	func execute(_game_state: GameState) -> Dictionary:
		return {"authority_only": true}

	func execute_with_application_result(game_state: GameState,
			application_result: Dictionary) -> Dictionary:
		if not application_result.is_empty():
			return {}
		game_state.current_round += 1
		return {"applied": true}

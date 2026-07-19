## Focused Slice 4 tests for static candidates and fresh opportunities.
extends GutTest


const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")
const COMMANDS: GDScript = preload(
		"res://tests/fixtures/timing_window_command_fixtures.gd")
const FIXTURE_RULE: GDScript = preload(
		"res://tests/fixtures/timing_window_participant_fixture.gd")
const INVALID_RULE: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")

var _state: GameState = null
var _saved_command_registry: Dictionary = {}


func before_each() -> void:
	_saved_command_registry = GameCommand._registry.duplicate()
	COMMANDS.register()
	RuleRegistry.clear()
	FIXTURE_RULE.reset_calls()
	_state = GameState.new()
	_state.initialize()
	assert_true(ORCHESTRATOR.open_window(
			_state, DEFINITIONS.ATTACK_MODIFY, 3, _context()).get(
					ORCHESTRATOR.KEY_OK, false),
			"Fixture lifecycle should open for participant tests.")


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_command_registry


func test_registry_lookup_is_static_and_deterministic() -> void:
	_register("z-diagnostic")
	_register("a-diagnostic")
	var query: Dictionary = RuleRegistry.timing_window_participants_for(
			DEFINITIONS.ATTACK_MODIFY)
	var candidates: Array = query.get("candidates", [])

	assert_true(query.get("ok", false),
			"Valid static participant lookup should succeed.")
	assert_eq(candidates.size(), 2,
			"Registry should retain static candidate declarations.")
	assert_eq((candidates[0] as Dictionary).get(
			RuleRegistry.PARTICIPANT_KEY_DIAGNOSTIC_ID), "a-diagnostic",
			"Static candidates should have deterministic diagnostic order.")
	assert_false((candidates[0] as Dictionary).has("runtime_source_id"),
			"RuleRegistry must not store runtime sources.")


func test_absent_runtime_source_yields_no_opportunity() -> void:
	_register()
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)
	assert_true(result.get(ORCHESTRATOR.KEY_OK, false),
			"An absent runtime source should not be an error.")
	assert_eq(result.get(ORCHESTRATOR.KEY_OPPORTUNITIES), [],
			"Absent authoritative sources should derive no opportunity.")


func test_duplicate_static_candidate_suppresses_before_derivation() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_register()
	_register()
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)

	assert_true(result.get(ORCHESTRATOR.KEY_OK, false),
			"Duplicate static paths should suppress deterministically.")
	assert_eq((result.get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).size(), 1,
			"Duplicate static candidates should not duplicate opportunities.")
	assert_eq(FIXTURE_RULE.enumeration_calls, 2,
			"Each registered descriptor should enumerate once.")
	assert_eq(FIXTURE_RULE.derivation_calls, 1,
			"Duplicate capability/source candidates should derive once.")


func test_invalid_registration_fails_closed_for_participant_key() -> void:
	var descriptor: Dictionary = _descriptor("invalid")
	descriptor[RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT] = INVALID_RULE
	assert_false(RuleRegistry.register_timing_window_participant(descriptor),
			"Descriptor without required rule operations should reject.")
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)
	assert_false(result.get(ORCHESTRATOR.KEY_OK, true),
			"Invalid registration should block continuation evaluation.")


func test_enumeration_and_derivation_failures_fail_closed() -> void:
	_register()
	_state.objectives[FIXTURE_RULE.FAIL_ENUMERATION_KEY] = true
	assert_false(ORCHESTRATOR.derive_current_opportunities(_state).get(
			ORCHESTRATOR.KEY_OK, true),
			"Enumeration errors should not be treated as no opportunities.")
	_state.objectives.erase(FIXTURE_RULE.FAIL_ENUMERATION_KEY)
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_state.objectives[FIXTURE_RULE.FAIL_DERIVATION_KEY] = true
	assert_false(ORCHESTRATOR.derive_current_opportunities(_state).get(
			ORCHESTRATOR.KEY_OK, true),
			"Derivation errors should not be treated as no opportunities.")


func test_canonical_identity_contains_all_authoritative_components() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_register()
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)
	var opportunity: Dictionary = (result.get(
			ORCHESTRATOR.KEY_OPPORTUNITIES) as Array)[0]
	var identity: String = str(opportunity.get(OPPORTUNITY.KEY_ID, ""))

	assert_true(identity.contains(FIXTURE_RULE.CAPABILITY_ID),
			"Canonical identity should include capability identity.")
	assert_true(identity.contains(FIXTURE_RULE.SOURCE_OWNER_KIND),
			"Canonical identity should include source-owner kind.")
	assert_true(identity.contains("source-1"),
			"Canonical identity should include runtime-source identity.")
	assert_true(identity.contains(FIXTURE_RULE.SEMANTIC_KEY),
			"Canonical identity should include semantic opportunity key.")
	assert_false(identity.contains("uuid"),
			"Canonical identity should not introduce synthetic UUID authority.")


func test_duplicate_derived_identity_fails_closed() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_state.objectives[FIXTURE_RULE.DUPLICATE_KEY] = true
	_register()
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)
	assert_false(result.get(ORCHESTRATOR.KEY_OK, true),
			"Duplicate derived identity should fail rather than merge or choose.")


func test_rederivation_reads_current_authoritative_fixture_state() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_register()
	var before: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)
	_state.objectives[FIXTURE_RULE.RESOLVED_KEY] = {"source-1": true}
	var after: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)

	assert_eq((before.get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).size(), 1,
			"Unresolved source should derive one opportunity.")
	assert_eq(after.get(ORCHESTRATOR.KEY_OPPORTUNITIES), [],
			"Fresh derivation should observe authoritative resolution state.")


func test_ordering_is_deterministic_without_selecting_for_player() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-z", "source-a"]
	_register()
	var opportunities: Array = ORCHESTRATOR.derive_current_opportunities(
			_state).get(ORCHESTRATOR.KEY_OPPORTUNITIES)

	assert_eq((opportunities[0] as Dictionary).get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID), "source-a",
			"Presentation order should be deterministic by canonical identity.")
	assert_eq((opportunities[1] as Dictionary).get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID), "source-z",
			"All player-selectable opportunities should remain present.")
	for raw: Variant in opportunities:
		var opportunity: Dictionary = raw as Dictionary
		assert_false((opportunity.get(OPPORTUNITY.KEY_USE_INTENT) as Dictionary).is_empty(),
				"Optional blocker should expose a replayable use intent.")
		assert_false((opportunity.get(OPPORTUNITY.KEY_DECLINE_INTENT) as Dictionary).is_empty(),
				"Optional blocker should expose an explicit decline intent.")


func test_unknown_use_command_intent_fails_closed() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_state.objectives[FIXTURE_RULE.USE_COMMAND_TYPE_KEY] = "reroll_attack_dye"
	_register()

	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)

	assert_false(result.get(ORCHESTRATOR.KEY_OK, true),
			"An unknown use command type must not become an opportunity.")


func test_unknown_decline_command_intent_fails_closed() -> void:
	_state.objectives[FIXTURE_RULE.SOURCES_KEY] = ["source-1"]
	_state.objectives[FIXTURE_RULE.DECLINE_COMMAND_TYPE_KEY] = \
			"skip_attack_modifer"
	_register()

	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)

	assert_false(result.get(ORCHESTRATOR.KEY_OK, true),
			"An unknown decline command type must not become an opportunity.")


func _register(diagnostic_id: String = "fixture") -> void:
	assert_true(RuleRegistry.register_timing_window_participant(
			_descriptor(diagnostic_id)),
			"Fixture participant should register through existing RuleRegistry.")


func _descriptor(diagnostic_id: String) -> Dictionary:
	return {
		RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID: FIXTURE_RULE.CAPABILITY_ID,
		RuleRegistry.PARTICIPANT_KEY_WINDOW: DEFINITIONS.ATTACK_MODIFY,
		RuleRegistry.PARTICIPANT_KEY_SOURCE_OWNER_KIND:
				FIXTURE_RULE.SOURCE_OWNER_KIND,
		RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT: FIXTURE_RULE,
		RuleRegistry.PARTICIPANT_KEY_DIAGNOSTIC_ID: diagnostic_id,
	}


func _context() -> Dictionary:
	return {
		TimingWindowState.CONTINUATION_KEY_ID: "confirm_attack_dice",
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID: "fixture-attack",
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}

## Focused Slice 2 tests for immutable timing-window policy ownership.
extends GutTest


const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const FORBIDDEN_DYNAMIC_KEYS: Array[String] = [
	"controller_player",
	"current_player",
	"opportunities",
	"participants",
	"runtime_sources",
	"legality",
	"visibility",
	"payload",
	"dice",
	"rule_state",
]


func test_attack_modify_definition_contains_only_accepted_static_policy() -> void:
	var definition: Dictionary = DEFINITIONS.get_definition(
			DEFINITIONS.ATTACK_MODIFY)

	assert_eq(definition.get(DEFINITIONS.KEY_TIMING_WINDOW_ID),
			DEFINITIONS.ATTACK_MODIFY,
			"Attack Modify should use the canonical timing-window identity.")
	assert_eq(definition.get(DEFINITIONS.KEY_LIFECYCLE_STAGE),
			DEFINITIONS.ATTACK_MODIFY,
			"Attack Modify should use the accepted lifecycle stage.")
	assert_eq(definition.get(DEFINITIONS.KEY_CONTROLLER_POLICY),
			DEFINITIONS.CONTROLLER_FIXED_ATTACKER,
			"Attack Modify should use fixed attacker control policy.")
	assert_eq(definition.get(DEFINITIONS.KEY_PARTICIPANT_KEY),
			DEFINITIONS.ATTACK_MODIFY,
			"Attack Modify should use the canonical participant index key.")
	assert_eq(definition.get(DEFINITIONS.KEY_CONTINUATION_COMMAND_TYPE),
			"confirm_attack_dice",
			"Attack Modify should map to its replayable continuation.")
	assert_eq(definition.get(DEFINITIONS.KEY_CANCELLATION_COMMAND_TYPES),
			["skip_attack"],
			"Attack cancellation should use the existing semantic command path.")
	for key: String in FORBIDDEN_DYNAMIC_KEYS:
		assert_false(definition.has(key),
				"Static definitions must not contain runtime key '%s'." % key)


func test_unknown_definition_fails_closed() -> void:
	assert_false(DEFINITIONS.has_definition("unknown_window"),
			"Unknown timing-window identities should not be accepted.")
	assert_eq(DEFINITIONS.get_definition("unknown_window"), {},
			"Unknown timing-window lookup should return no policy.")


func test_returned_definition_cannot_mutate_canonical_table() -> void:
	var definition: Dictionary = DEFINITIONS.get_definition(
			DEFINITIONS.ATTACK_MODIFY)
	definition[DEFINITIONS.KEY_PARTICIPANT_KEY] = "mutated"
	var cancellation_types: Array = definition[
			DEFINITIONS.KEY_CANCELLATION_COMMAND_TYPES]
	cancellation_types.append("mutated_cancel")

	var canonical: Dictionary = DEFINITIONS.get_definition(
			DEFINITIONS.ATTACK_MODIFY)
	assert_eq(canonical.get(DEFINITIONS.KEY_PARTICIPANT_KEY),
			DEFINITIONS.ATTACK_MODIFY,
			"Definition lookup should isolate top-level mutation.")
	assert_eq(canonical.get(DEFINITIONS.KEY_CANCELLATION_COMMAND_TYPES),
			["skip_attack"],
			"Definition lookup should isolate nested mutation.")


func test_attack_modify_is_the_only_shared_definition() -> void:
	assert_eq(DEFINITIONS.all_timing_window_ids(), [DEFINITIONS.ATTACK_MODIFY],
			"Slice 2 should establish exactly one shared static definition.")


func test_flow_spec_remains_non_authoritative_for_timing_policy() -> void:
	var spec: Dictionary = FlowSpec.get_spec(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY)
	assert_false(spec.has(DEFINITIONS.KEY_PARTICIPANT_KEY),
			"FlowSpec must not own timing-window participant policy.")
	assert_false(spec.has(DEFINITIONS.KEY_CONTINUATION_COMMAND_TYPE),
			"FlowSpec must not own timing-window continuation policy.")

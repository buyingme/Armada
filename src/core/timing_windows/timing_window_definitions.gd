## Immutable static policy for shared timing-window lifecycles.
##
## Runtime eligibility, controller identity, opportunities, and mutation are
## intentionally absent. The TimingWindowOrchestrator consumes deep copies of
## these definitions and remains the lifecycle owner.
class_name TimingWindowDefinitions
extends RefCounted


const ATTACK_MODIFY: String = "attack_modify"

const KEY_TIMING_WINDOW_ID: String = "timing_window_id"
const KEY_LIFECYCLE_STAGE: String = "lifecycle_stage"
const KEY_CONTROLLER_POLICY: String = "controller_policy"
const KEY_PARTICIPANT_KEY: String = "participant_key"
const KEY_CONTINUATION_COMMAND_TYPE: String = "continuation_command_type"
const KEY_NORMAL_COMPLETION: String = "normal_completion"
const KEY_CANCELLATION_COMMAND_TYPES: String = "cancellation_command_types"
const KEY_REPLACEMENT_POLICY: String = "replacement_policy"
const KEY_CLOSE_AND_OPEN_POLICY: String = "close_and_open_policy"

const CONTROLLER_FIXED_ATTACKER: String = "fixed_attacker"
const COMPLETION_SUCCESSFUL_CONTINUATION: String = \
		"successful_continuation_only"
const REPLACEMENT_PROHIBITED: String = "prohibited"
const CLOSE_AND_OPEN_AFTER_TERMINAL: String = "after_completion_or_cancellation"

const _DEFINITIONS: Dictionary = {
	ATTACK_MODIFY: {
		KEY_TIMING_WINDOW_ID: ATTACK_MODIFY,
		KEY_LIFECYCLE_STAGE: ATTACK_MODIFY,
		KEY_CONTROLLER_POLICY: CONTROLLER_FIXED_ATTACKER,
		KEY_PARTICIPANT_KEY: ATTACK_MODIFY,
		KEY_CONTINUATION_COMMAND_TYPE: "confirm_attack_dice",
		KEY_NORMAL_COMPLETION: COMPLETION_SUCCESSFUL_CONTINUATION,
		KEY_CANCELLATION_COMMAND_TYPES: ["skip_attack"],
		KEY_REPLACEMENT_POLICY: REPLACEMENT_PROHIBITED,
		KEY_CLOSE_AND_OPEN_POLICY: CLOSE_AND_OPEN_AFTER_TERMINAL,
	},
}


## Returns a deep copy so callers cannot mutate the canonical table.
static func get_definition(timing_window_id: String) -> Dictionary:
	var definition: Dictionary = _DEFINITIONS.get(timing_window_id, {})
	return definition.duplicate(true)


static func has_definition(timing_window_id: String) -> bool:
	return _DEFINITIONS.has(timing_window_id)


static func all_timing_window_ids() -> Array[String]:
	var identities: Array[String] = []
	for raw_identity: Variant in _DEFINITIONS.keys():
		identities.append(str(raw_identity))
	identities.sort()
	return identities

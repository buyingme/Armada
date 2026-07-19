## Shared timing-window lifecycle coordinator.
##
## This stateless module owns lifecycle transitions, blocker evaluation, and
## continuation coordination against the TimingWindowState stored by GameState.
## It never stores opportunities, rule state, or command queues.
class_name TimingWindowOrchestrator
extends RefCounted


const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const TIMING_WINDOW_STATE: GDScript = preload(
		"res://src/core/state/timing_window_state.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")

const MODE_LIVE_AUTHORITY: String = "live_authority"
const MODE_NETWORK_MIRROR: String = "network_mirror"
const MODE_REPLAY: String = "replay"
const MODE_RECONSTRUCTION: String = "reconstruction"

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_OPPORTUNITIES: String = "opportunities"
const KEY_CONTINUATION: String = "continuation"
const KEY_REDERIVED: String = "rederived"

const COMMAND_KEY_TIMING_WINDOW_ID: String = "timing_window_id"
const COMMAND_KEY_LIFECYCLE_ID: String = "lifecycle_id"
const COMMAND_KEY_SOURCE_ID: String = "source_id"
const COMMAND_KEY_SOURCE_TYPE: String = "source_type"


## Opens a known window with identity derived from the accepted command sequence.
static func open_window(game_state: GameState,
		timing_window_id: String,
		opening_command_sequence: int,
		continuation_context: Dictionary) -> Dictionary:
	if game_state == null or game_state.timing_window_state == null:
		return _failure("Missing authoritative timing-window state.")
	if game_state.timing_window_state.active:
		return _failure("A timing window is already active.")
	if opening_command_sequence < 0:
		return _failure("Opening command sequence must be non-negative.")
	var definition: Dictionary = DEFINITIONS.get_definition(timing_window_id)
	if definition.is_empty():
		return _failure("Unknown timing-window definition: %s." % timing_window_id)
	var context_reason: String = _validate_open_context(
			definition, continuation_context)
	if not context_reason.is_empty():
		return _failure(context_reason)
	var controller: int = int(continuation_context.get(
			TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER, -1))
	var lifecycle_id: String = "%s:%d" % [
		timing_window_id, opening_command_sequence]
	var next_state = TIMING_WINDOW_STATE.new()
	if not next_state.configure_active(
			timing_window_id,
			str(definition.get(DEFINITIONS.KEY_LIFECYCLE_STAGE, "")),
			lifecycle_id,
			controller,
			continuation_context,
			TimingWindowState.STATUS_OPEN):
		return _failure("Timing-window lifecycle state is invalid.")
	if not game_state.set_timing_window_state(next_state):
		return _failure("Timing-window lifecycle state could not be installed.")
	return {
		KEY_OK: true,
		KEY_REASON: "",
		COMMAND_KEY_LIFECYCLE_ID: lifecycle_id,
	}


## Cancels one matching active lifecycle. Rule-owned cleanup remains command-owned.
static func cancel_window(game_state: GameState,
		lifecycle_id: String) -> Dictionary:
	var reason: String = _matching_active_lifecycle_reason(game_state, lifecycle_id)
	if not reason.is_empty():
		return _failure(reason)
	return _install_inactive(game_state, "cancelled")


## Explicit replacement is rejected when the active definition prohibits it.
static func replace_window(game_state: GameState,
		lifecycle_id: String,
		next_timing_window_id: String,
		opening_command_sequence: int,
		continuation_context: Dictionary) -> Dictionary:
	var reason: String = _matching_active_lifecycle_reason(game_state, lifecycle_id)
	if not reason.is_empty():
		return _failure(reason)
	var current_definition: Dictionary = DEFINITIONS.get_definition(
			game_state.timing_window_state.timing_window_id)
	if str(current_definition.get(DEFINITIONS.KEY_REPLACEMENT_POLICY, "")) \
			== DEFINITIONS.REPLACEMENT_PROHIBITED:
		return _failure("Active timing-window definition prohibits replacement.")
	var inactive_result: Dictionary = _install_inactive(game_state, "replaced")
	if not bool(inactive_result.get(KEY_OK, false)):
		return inactive_result
	return open_window(game_state, next_timing_window_id,
			opening_command_sequence, continuation_context)


## Closes only a matching lifecycle already waiting on its continuation.
static func close_after_continuation(game_state: GameState,
		lifecycle_id: String) -> Dictionary:
	var reason: String = _matching_active_lifecycle_reason(game_state, lifecycle_id)
	if not reason.is_empty():
		return _failure(reason)
	if game_state.timing_window_state.status != TimingWindowState.STATUS_CLOSING:
		return _failure("Timing window is not awaiting continuation.")
	return _install_inactive(game_state, "closed")


## Re-derives after one accepted command and returns at most one continuation.
static func process_successful_command(game_state: GameState,
		command: GameCommand,
		_result: Dictionary,
		execution_mode: String) -> Dictionary:
	if not _is_valid_execution_mode(execution_mode):
		return _failure("Unknown timing-window execution mode.")
	if game_state == null or game_state.timing_window_state == null \
			or not game_state.timing_window_state.active:
		return _success_without_continuation(false)
	if _is_matching_continuation(game_state, command):
		var close_result: Dictionary = close_after_continuation(
				game_state, game_state.timing_window_state.lifecycle_id)
		close_result[KEY_REDERIVED] = false
		close_result[KEY_CONTINUATION] = null
		return close_result
	var derivation: Dictionary = derive_current_opportunities(game_state)
	return _apply_derivation_result(
			game_state, derivation, execution_mode)


## A rejected continuation preserves the active closing lifecycle and queues no retry.
static func process_rejected_command(game_state: GameState,
		command: GameCommand,
		execution_mode: String) -> Dictionary:
	if game_state == null or game_state.timing_window_state == null \
			or not game_state.timing_window_state.active:
		return _success_without_continuation(false)
	if not _is_matching_continuation(game_state, command):
		return _success_without_continuation(false)
	var derivation: Dictionary = derive_current_opportunities(game_state)
	return {
		KEY_OK: bool(derivation.get(KEY_OK, false)),
		KEY_REASON: str(derivation.get(KEY_REASON, "")),
		KEY_OPPORTUNITIES: derivation.get(KEY_OPPORTUNITIES, []),
		KEY_CONTINUATION: null,
		KEY_REDERIVED: true,
		"execution_mode": execution_mode,
	}


## Reconciles derived state after reconstruction without synthesizing commands.
static func reconcile(game_state: GameState,
		execution_mode: String = MODE_RECONSTRUCTION) -> Dictionary:
	if execution_mode != MODE_RECONSTRUCTION \
			and execution_mode != MODE_NETWORK_MIRROR \
			and execution_mode != MODE_REPLAY:
		return _failure("Reconciliation requires a passive execution mode.")
	var validation: Dictionary = validate_reconstructed_state(game_state)
	if not bool(validation.get(KEY_OK, false)):
		return validation
	if not game_state.timing_window_state.active:
		return _success_without_continuation(false)
	return _apply_derivation_result(
			game_state, derive_current_opportunities(game_state), execution_mode)


## Validates the authoritative owners needed to resume one reconstructed
## lifecycle. It never derives choices, repairs owners, or creates commands.
static func validate_reconstructed_state(game_state: GameState) -> Dictionary:
	if game_state == null or game_state.timing_window_state == null:
		return _failure("Missing authoritative timing-window state.")
	var timing_state: TimingWindowState = game_state.timing_window_state
	if not timing_state.active:
		return _success_without_continuation(false)
	var definition: Dictionary = DEFINITIONS.get_definition(
			timing_state.timing_window_id)
	if definition.is_empty():
		return _failure("Active timing window has no static definition.")
	if timing_state.lifecycle_stage != str(definition.get(
			DEFINITIONS.KEY_LIFECYCLE_STAGE, "")):
		return _failure("Timing-window lifecycle stage conflicts with static policy.")
	var context: Dictionary = timing_state.continuation_context
	var context_reason: String = _validate_open_context(definition, context)
	if not context_reason.is_empty():
		return _failure(context_reason)
	if timing_state.controller_player != int(context.get(
			TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER, -1)):
		return _failure("Timing-window controller conflicts with continuation owner.")
	if not _has_canonical_lifecycle_identity(timing_state):
		return _failure("Timing-window lifecycle identity is inconsistent.")
	if timing_state.timing_window_id == DEFINITIONS.ATTACK_MODIFY:
		var attack_reason: String = _attack_modify_context_reason(
				game_state, timing_state)
		if not attack_reason.is_empty():
			return _failure(attack_reason)
	return _success_without_continuation(false)


static func derive_current_opportunities(game_state: GameState) -> Dictionary:
	if game_state == null or game_state.timing_window_state == null:
		return _failure("Missing authoritative timing-window state.")
	if not game_state.timing_window_state.active:
		return {
			KEY_OK: true,
			KEY_REASON: "",
			KEY_OPPORTUNITIES: [],
		}
	var definition: Dictionary = DEFINITIONS.get_definition(
			game_state.timing_window_state.timing_window_id)
	if definition.is_empty():
		return _failure("Active timing window has no static definition.")
	var participant_key: String = str(definition.get(
			DEFINITIONS.KEY_PARTICIPANT_KEY, ""))
	var query: Dictionary = RuleRegistry.timing_window_participants_for(
			participant_key)
	if not bool(query.get(KEY_OK, false)):
		return _failure(str(query.get(KEY_REASON,
				"Timing-window participant lookup failed.")))
	var source_candidates: Array[Dictionary] = []
	for descriptor: Dictionary in query.get("candidates", []):
		var enumeration: Variant = _enumerate_sources(
				descriptor, game_state, game_state.timing_window_state)
		if not enumeration is Array:
			return _failure("Timing-window source enumeration failed.")
		for raw_source: Variant in enumeration as Array:
			var source: Dictionary = _validated_source(descriptor, raw_source)
			if source.is_empty():
				return _failure("Timing-window source identity is invalid.")
			source_candidates.append({
				"descriptor": descriptor,
				"source": source,
			})
	source_candidates.sort_custom(_source_candidate_before)
	var seen_candidates: Dictionary = {}
	var seen_opportunities: Dictionary = {}
	var opportunities: Array[Dictionary] = []
	for candidate: Dictionary in source_candidates:
		var descriptor: Dictionary = candidate.get("descriptor") as Dictionary
		var source: Dictionary = candidate.get("source") as Dictionary
		var candidate_identity: String = _candidate_identity(descriptor, source)
		if seen_candidates.has(candidate_identity):
			continue
		seen_candidates[candidate_identity] = true
		var derived: Variant = _derive_for_source(
				descriptor, source, game_state, game_state.timing_window_state)
		if not derived is Array:
			return _failure("Timing-window opportunity derivation failed.")
		for raw_opportunity: Variant in derived as Array:
			if not raw_opportunity is Dictionary:
				return _failure("Timing-window opportunity is not structured data.")
			var opportunity: Dictionary = OPPORTUNITY.validate_canonical(
					raw_opportunity as Dictionary)
			if opportunity.is_empty() \
					or not _opportunity_matches_candidate(
						opportunity, descriptor, source):
				return _failure("Timing-window opportunity identity is invalid.")
			var opportunity_id: String = str(opportunity.get(
					OPPORTUNITY.KEY_ID, ""))
			if seen_opportunities.has(opportunity_id):
				return _failure("Duplicate timing-window opportunity identity.")
			seen_opportunities[opportunity_id] = true
			opportunities.append(opportunity)
	opportunities.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get(OPPORTUNITY.KEY_ID, "")) \
				< str(right.get(OPPORTUNITY.KEY_ID, "")))
	return {KEY_OK: true, KEY_REASON: "", KEY_OPPORTUNITIES: opportunities}


static func _enumerate_sources(descriptor: Dictionary,
		game_state: GameState,
		timing_state: TimingWindowState) -> Variant:
	var rule_script: GDScript = descriptor.get(
			RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT) as GDScript
	if rule_script == null:
		return null
	return rule_script.call(
			RuleRegistry.SOURCE_ENUMERATION_METHOD, game_state, timing_state)


static func _derive_for_source(descriptor: Dictionary,
		source: Dictionary,
		game_state: GameState,
		timing_state: TimingWindowState) -> Variant:
	var rule_script: GDScript = descriptor.get(
			RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT) as GDScript
	if rule_script == null:
		return null
	return rule_script.call(
			RuleRegistry.OPPORTUNITY_DERIVATION_METHOD,
			game_state,
			timing_state,
			str(source.get(OPPORTUNITY.KEY_SOURCE_OWNER_KIND, "")),
			str(source.get(OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, "")))


static func _validated_source(descriptor: Dictionary,
		raw_source: Variant) -> Dictionary:
	if not raw_source is Dictionary:
		return {}
	var source: Dictionary = raw_source as Dictionary
	if source.size() != 2:
		return {}
	for key: String in [
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID,
	]:
		if typeof(source.get(key)) != TYPE_STRING \
				or str(source.get(key, "")).is_empty():
			return {}
	if str(source.get(OPPORTUNITY.KEY_SOURCE_OWNER_KIND, "")) \
			!= str(descriptor.get(
					RuleRegistry.PARTICIPANT_KEY_SOURCE_OWNER_KIND, "")):
		return {}
	return source.duplicate(true)


static func _candidate_identity(descriptor: Dictionary,
		source: Dictionary) -> String:
	return JSON.stringify([
		str(descriptor.get(RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID, "")),
		str(source.get(OPPORTUNITY.KEY_SOURCE_OWNER_KIND, "")),
		str(source.get(OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, "")),
	])


static func _source_candidate_before(left: Dictionary,
		right: Dictionary) -> bool:
	return _candidate_identity(
			left.get("descriptor") as Dictionary,
			left.get("source") as Dictionary) \
			< _candidate_identity(
				right.get("descriptor") as Dictionary,
				right.get("source") as Dictionary)


static func _opportunity_matches_candidate(opportunity: Dictionary,
		descriptor: Dictionary,
		source: Dictionary) -> bool:
	return str(opportunity.get(OPPORTUNITY.KEY_CAPABILITY_ID, "")) \
			== str(descriptor.get(
					RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID, "")) \
			and str(opportunity.get(OPPORTUNITY.KEY_SOURCE_OWNER_KIND, "")) \
					== str(source.get(
							OPPORTUNITY.KEY_SOURCE_OWNER_KIND, "")) \
			and str(opportunity.get(OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, "")) \
					== str(source.get(
							OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, ""))


## Internal deterministic state transition used by the Slice 3 core tests.
static func _apply_derivation_result(game_state: GameState,
		derivation: Dictionary,
		execution_mode: String) -> Dictionary:
	if not bool(derivation.get(KEY_OK, false)):
		return {
			KEY_OK: false,
			KEY_REASON: str(derivation.get(KEY_REASON,
					"Timing-window opportunity derivation failed.")),
			KEY_OPPORTUNITIES: [],
			KEY_CONTINUATION: null,
			KEY_REDERIVED: true,
		}
	var opportunities: Array = derivation.get(KEY_OPPORTUNITIES, []) as Array
	if _has_blocking_opportunity(opportunities):
		if game_state.timing_window_state.status == TimingWindowState.STATUS_CLOSING:
			if not _set_active_status(game_state, TimingWindowState.STATUS_OPEN):
				return _failure("Could not restore blocked lifecycle to open.")
		return {
			KEY_OK: true,
			KEY_REASON: "",
			KEY_OPPORTUNITIES: opportunities.duplicate(true),
			KEY_CONTINUATION: null,
			KEY_REDERIVED: true,
		}
	if game_state.timing_window_state.status == TimingWindowState.STATUS_CLOSING:
		return {
			KEY_OK: true,
			KEY_REASON: "",
			KEY_OPPORTUNITIES: opportunities.duplicate(true),
			KEY_CONTINUATION: null,
			KEY_REDERIVED: true,
		}
	var continuation: GameCommand = null
	if execution_mode == MODE_LIVE_AUTHORITY:
		continuation = _build_continuation_command(game_state)
		if continuation == null:
			return _failure("Timing-window continuation could not be constructed.")
	if not _set_active_status(game_state, TimingWindowState.STATUS_CLOSING):
		return _failure("Could not mark timing window as closing.")
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_OPPORTUNITIES: opportunities.duplicate(true),
		KEY_CONTINUATION: continuation,
		KEY_REDERIVED: true,
	}


static func _build_continuation_command(game_state: GameState) -> GameCommand:
	var timing_state: TimingWindowState = game_state.timing_window_state
	var definition: Dictionary = DEFINITIONS.get_definition(
			timing_state.timing_window_id)
	var command_type: String = str(definition.get(
			DEFINITIONS.KEY_CONTINUATION_COMMAND_TYPE, ""))
	if command_type.is_empty():
		return null
	var context: Dictionary = timing_state.continuation_context
	var payload: Dictionary = {
		COMMAND_KEY_TIMING_WINDOW_ID: timing_state.timing_window_id,
		COMMAND_KEY_LIFECYCLE_ID: timing_state.lifecycle_id,
		COMMAND_KEY_SOURCE_ID: context.get(
			TimingWindowState.CONTINUATION_KEY_SOURCE_ID, ""),
		COMMAND_KEY_SOURCE_TYPE: context.get(
			TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE, ""),
	}
	return GameCommand.deserialize({
		"type": command_type,
		"player": int(context.get(
				TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER,
				timing_state.controller_player)),
		"sequence": -1,
		"payload": payload,
	})


static func _is_matching_continuation(game_state: GameState,
		command: GameCommand) -> bool:
	if command == null:
		return false
	var timing_state: TimingWindowState = game_state.timing_window_state
	var definition: Dictionary = DEFINITIONS.get_definition(
			timing_state.timing_window_id)
	if command.command_type != str(definition.get(
			DEFINITIONS.KEY_CONTINUATION_COMMAND_TYPE, "")):
		return false
	return str(command.payload.get(COMMAND_KEY_LIFECYCLE_ID, "")) \
			== timing_state.lifecycle_id


static func _set_active_status(game_state: GameState, status: String) -> bool:
	var current: TimingWindowState = game_state.timing_window_state
	var replacement = TIMING_WINDOW_STATE.new()
	if not replacement.configure_active(
			current.timing_window_id,
			current.lifecycle_stage,
			current.lifecycle_id,
			current.controller_player,
			current.continuation_context,
			status):
		return false
	return game_state.set_timing_window_state(replacement)


static func _install_inactive(game_state: GameState,
		_terminal_reason: String) -> Dictionary:
	var inactive = TIMING_WINDOW_STATE.new()
	if not game_state.set_timing_window_state(inactive):
		return _failure("Could not clear timing-window lifecycle state.")
	return {KEY_OK: true, KEY_REASON: ""}


static func _matching_active_lifecycle_reason(game_state: GameState,
		lifecycle_id: String) -> String:
	if game_state == null or game_state.timing_window_state == null:
		return "Missing authoritative timing-window state."
	if not game_state.timing_window_state.active:
		return "No timing window is active."
	if lifecycle_id.is_empty() \
			or game_state.timing_window_state.lifecycle_id != lifecycle_id:
		return "Stale timing-window lifecycle identity."
	return ""


static func _validate_open_context(definition: Dictionary,
		context: Dictionary) -> String:
	var required_string_keys: Array[String] = [
		TimingWindowState.CONTINUATION_KEY_ID,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT,
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID,
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE,
	]
	for key: String in required_string_keys:
		if typeof(context.get(key)) != TYPE_STRING \
				or str(context.get(key, "")).is_empty():
			return "Continuation context is missing %s." % key
	if str(context.get(TimingWindowState.CONTINUATION_KEY_ID, "")) \
			!= str(definition.get(
					DEFINITIONS.KEY_CONTINUATION_COMMAND_TYPE, "")):
		return "Continuation context does not match static policy."
	var owner: Variant = context.get(
			TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER)
	if typeof(owner) != TYPE_INT \
			or int(owner) < 0 or int(owner) >= Constants.PLAYER_COUNT:
		return "Continuation owner player is invalid."
	return ""


static func _has_canonical_lifecycle_identity(
		timing_state: TimingWindowState) -> bool:
	var prefix: String = "%s:" % timing_state.timing_window_id
	if not timing_state.lifecycle_id.begins_with(prefix):
		return false
	var sequence_text: String = timing_state.lifecycle_id.substr(prefix.length())
	if not sequence_text.is_valid_int():
		return false
	var sequence: int = sequence_text.to_int()
	return sequence >= 0 and str(sequence) == sequence_text


static func _attack_modify_context_reason(game_state: GameState,
		timing_state: TimingWindowState) -> String:
	var context: Dictionary = timing_state.continuation_context
	if str(context.get(TimingWindowState.CONTINUATION_KEY_RESUME_POINT, "")) \
			!= "attack_after_modify" \
			or str(context.get(
					TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE, "")) \
					!= "current_attack":
		return "Attack Modify continuation context is inconsistent."
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Attack Modify lifecycle is outside an attack phase."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
		return "Attack Modify lifecycle conflicts with the enclosing flow."
	if flow.controller_player != timing_state.controller_player:
		return "Attack Modify controller conflicts with the enclosing flow."
	return ""


static func _has_blocking_opportunity(opportunities: Array) -> bool:
	for raw_opportunity: Variant in opportunities:
		if raw_opportunity is Dictionary \
				and bool((raw_opportunity as Dictionary).get("blocking", false)):
			return true
	return false


static func _is_valid_execution_mode(execution_mode: String) -> bool:
	return execution_mode in [
		MODE_LIVE_AUTHORITY,
		MODE_NETWORK_MIRROR,
		MODE_REPLAY,
		MODE_RECONSTRUCTION,
	]


static func _success_without_continuation(rederived: bool) -> Dictionary:
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_OPPORTUNITIES: [],
		KEY_CONTINUATION: null,
		KEY_REDERIVED: rederived,
	}


static func _failure(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
		KEY_OPPORTUNITIES: [],
		KEY_CONTINUATION: null,
		KEY_REDERIVED: false,
	}

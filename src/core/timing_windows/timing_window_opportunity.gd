## Canonical validation and identity helper for derived timing opportunities.
##
## Opportunities are plain Dictionaries created fresh on every derivation pass.
## This helper owns no lifecycle, registry, eligibility, or mutable state.
class_name TimingWindowOpportunity
extends RefCounted


const KEY_ID: String = "opportunity_id"
const KEY_CAPABILITY_ID: String = "capability_id"
const KEY_SOURCE_OWNER_KIND: String = "source_owner_kind"
const KEY_RUNTIME_SOURCE_ID: String = "runtime_source_id"
const KEY_SEMANTIC_KEY: String = "semantic_key"
const KEY_CONTROLLER_PLAYER: String = "controller_player"
const KEY_RESOLUTION_KIND: String = "resolution_kind"
const KEY_BLOCKING: String = "blocking"
const KEY_USE_INTENT: String = "use_intent"
const KEY_DECLINE_INTENT: String = "decline_intent"

const INTENT_KEY_COMMAND_TYPE: String = "command_type"
const INTENT_KEY_PLAYER: String = "player_index"
const INTENT_KEY_PAYLOAD: String = "payload"

const RESOLUTION_OPTIONAL: String = "optional"
const RESOLUTION_REQUIRED_CHOICE: String = "required_choice"

const _INPUT_KEYS: Array[String] = [
	KEY_CAPABILITY_ID,
	KEY_SOURCE_OWNER_KIND,
	KEY_RUNTIME_SOURCE_ID,
	KEY_SEMANTIC_KEY,
	KEY_CONTROLLER_PLAYER,
	KEY_RESOLUTION_KIND,
	KEY_BLOCKING,
	KEY_USE_INTENT,
	KEY_DECLINE_INTENT,
]


## Returns one normalized canonical record, or an empty Dictionary on failure.
static func create(raw: Dictionary) -> Dictionary:
	if not _has_only_input_keys(raw):
		return {}
	for key: String in [
		KEY_CAPABILITY_ID,
		KEY_SOURCE_OWNER_KIND,
		KEY_RUNTIME_SOURCE_ID,
		KEY_SEMANTIC_KEY,
	]:
		if typeof(raw.get(key)) != TYPE_STRING or str(raw.get(key, "")).is_empty():
			return {}
	var controller: Variant = raw.get(KEY_CONTROLLER_PLAYER)
	if typeof(controller) != TYPE_INT \
			or int(controller) < 0 or int(controller) >= Constants.PLAYER_COUNT:
		return {}
	var resolution_kind: Variant = raw.get(KEY_RESOLUTION_KIND)
	if typeof(resolution_kind) != TYPE_STRING \
			or not [RESOLUTION_OPTIONAL, RESOLUTION_REQUIRED_CHOICE].has(
					str(resolution_kind)):
		return {}
	if typeof(raw.get(KEY_BLOCKING)) != TYPE_BOOL:
		return {}
	var use_intent: Dictionary = _normalized_intent(
			raw.get(KEY_USE_INTENT), int(controller))
	if use_intent.is_empty():
		return {}
	var decline_intent: Dictionary = {}
	var raw_decline: Variant = raw.get(KEY_DECLINE_INTENT, {})
	if raw_decline is Dictionary and not (raw_decline as Dictionary).is_empty():
		decline_intent = _normalized_intent(raw_decline, int(controller))
		if decline_intent.is_empty():
			return {}
	if str(resolution_kind) == RESOLUTION_OPTIONAL \
			and bool(raw.get(KEY_BLOCKING, false)) \
			and decline_intent.is_empty():
		return {}
	var normalized: Dictionary = {
		KEY_CAPABILITY_ID: str(raw[KEY_CAPABILITY_ID]),
		KEY_SOURCE_OWNER_KIND: str(raw[KEY_SOURCE_OWNER_KIND]),
		KEY_RUNTIME_SOURCE_ID: str(raw[KEY_RUNTIME_SOURCE_ID]),
		KEY_SEMANTIC_KEY: str(raw[KEY_SEMANTIC_KEY]),
		KEY_CONTROLLER_PLAYER: int(controller),
		KEY_RESOLUTION_KIND: str(resolution_kind),
		KEY_BLOCKING: bool(raw[KEY_BLOCKING]),
		KEY_USE_INTENT: use_intent,
		KEY_DECLINE_INTENT: decline_intent,
	}
	normalized[KEY_ID] = canonical_identity(normalized)
	return normalized


## Validates an already canonical record and returns an isolated copy.
static func validate_canonical(raw: Dictionary) -> Dictionary:
	var input: Dictionary = raw.duplicate(true)
	var claimed_identity: String = str(input.get(KEY_ID, ""))
	input.erase(KEY_ID)
	var normalized: Dictionary = create(input)
	if normalized.is_empty() or claimed_identity != normalized.get(KEY_ID, ""):
		return {}
	return normalized


## Identity is the four accepted semantic components, never a generated UUID.
static func canonical_identity(opportunity: Dictionary) -> String:
	return JSON.stringify([
		str(opportunity.get(KEY_CAPABILITY_ID, "")),
		str(opportunity.get(KEY_SOURCE_OWNER_KIND, "")),
		str(opportunity.get(KEY_RUNTIME_SOURCE_ID, "")),
		str(opportunity.get(KEY_SEMANTIC_KEY, "")),
	])


static func _has_only_input_keys(raw: Dictionary) -> bool:
	for raw_key: Variant in raw.keys():
		if typeof(raw_key) != TYPE_STRING \
				or not _INPUT_KEYS.has(str(raw_key)):
			return false
	return true


static func _normalized_intent(raw: Variant,
		expected_player: int) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var intent: Dictionary = raw as Dictionary
	for raw_key: Variant in intent.keys():
		if typeof(raw_key) != TYPE_STRING \
				or not [INTENT_KEY_COMMAND_TYPE,
					INTENT_KEY_PLAYER, INTENT_KEY_PAYLOAD].has(str(raw_key)):
			return {}
	if typeof(intent.get(INTENT_KEY_COMMAND_TYPE)) != TYPE_STRING \
			or str(intent.get(INTENT_KEY_COMMAND_TYPE, "")).is_empty():
		return {}
	if not GameCommand.is_type_registered(str(intent.get(
			INTENT_KEY_COMMAND_TYPE, ""))):
		return {}
	if typeof(intent.get(INTENT_KEY_PLAYER)) != TYPE_INT \
			or int(intent.get(INTENT_KEY_PLAYER, -1)) != expected_player:
		return {}
	if not intent.get(INTENT_KEY_PAYLOAD) is Dictionary:
		return {}
	var payload: Dictionary = intent.get(INTENT_KEY_PAYLOAD) as Dictionary
	for key: String in ["lifecycle_id", "source_owner_kind",
			"runtime_source_id", "semantic_key"]:
		if typeof(payload.get(key)) != TYPE_STRING \
				or str(payload.get(key, "")).is_empty():
			return {}
	return {
		INTENT_KEY_COMMAND_TYPE: str(intent[INTENT_KEY_COMMAND_TYPE]),
		INTENT_KEY_PLAYER: expected_player,
		INTENT_KEY_PAYLOAD: payload.duplicate(true),
	}

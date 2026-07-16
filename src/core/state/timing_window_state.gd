## TimingWindowState
##
## Authoritative lifecycle state for one timing window.
## Slice 1 stores lifecycle identity only; opportunities, rule state,
## projection payloads, and command payloads are intentionally excluded.
class_name TimingWindowState
extends RefCounted


const STATUS_INACTIVE: String = "inactive"
const STATUS_OPEN: String = "open"
const STATUS_CLOSING: String = "closing"
const STATUS_CANCELLED: String = "cancelled"
const STATUS_REPLACED: String = "replaced"

const SERIALIZED_KEY_ACTIVE: String = "active"
const SERIALIZED_KEY_WINDOW_ID: String = "timing_window_id"
const SERIALIZED_KEY_STAGE: String = "lifecycle_stage"
const SERIALIZED_KEY_LIFECYCLE_ID: String = "lifecycle_id"
const SERIALIZED_KEY_CONTROLLER: String = "controller_player"
const SERIALIZED_KEY_CONTINUATION: String = "continuation_context"
const SERIALIZED_KEY_STATUS: String = "status"

const CONTINUATION_KEY_ID: String = "continuation_id"
const CONTINUATION_KEY_RESUME_POINT: String = "resume_point"
const CONTINUATION_KEY_SOURCE_ID: String = "source_id"
const CONTINUATION_KEY_SOURCE_TYPE: String = "source_type"
const CONTINUATION_KEY_OWNER_PLAYER: String = "owner_player"

const _VALID_STATUSES: Array[String] = [
	STATUS_INACTIVE,
	STATUS_OPEN,
	STATUS_CLOSING,
	STATUS_CANCELLED,
	STATUS_REPLACED,
]

const _SUPPORTED_KEYS: Array[String] = [
	SERIALIZED_KEY_ACTIVE,
	SERIALIZED_KEY_WINDOW_ID,
	SERIALIZED_KEY_STAGE,
	SERIALIZED_KEY_LIFECYCLE_ID,
	SERIALIZED_KEY_CONTROLLER,
	SERIALIZED_KEY_CONTINUATION,
	SERIALIZED_KEY_STATUS,
]

const _FORBIDDEN_KEYS: Array[String] = [
	"opportunities",
	"participants",
	"participant_list",
	"rule_registry",
	"projection",
	"ui",
	"modal",
	"payload",
	"cached_legality",
	"visibility",
	"visibility_results",
	"continuation_command",
	"continuation_payload",
	"rule_state",
	"card_state",
	"use_guards",
	"decline_guards",
	"dice",
	"dice_results",
	"tokens",
	"token_results",
	"static_definition",
]

const _SUPPORTED_CONTINUATION_KEYS: Array[String] = [
	CONTINUATION_KEY_ID,
	CONTINUATION_KEY_RESUME_POINT,
	CONTINUATION_KEY_SOURCE_ID,
	CONTINUATION_KEY_SOURCE_TYPE,
	CONTINUATION_KEY_OWNER_PLAYER,
]

var _active: bool = false
var _timing_window_id: String = ""
var _lifecycle_stage: String = ""
var _lifecycle_id: String = ""
var _controller_player: int = -1
var _continuation_context: Dictionary = {}
var _status: String = STATUS_INACTIVE


var active: bool:
	get:
		return _active


var timing_window_id: String:
	get:
		return _timing_window_id


var lifecycle_stage: String:
	get:
		return _lifecycle_stage


var lifecycle_id: String:
	get:
		return _lifecycle_id


var controller_player: int:
	get:
		return _controller_player


var continuation_context: Dictionary:
	get:
		return _continuation_context.duplicate(true)


var status: String:
	get:
		return _status


func configure_active(
		window_id: String,
		stage: String,
		id: String,
		controller: int = -1,
		continuation: Dictionary = {},
		window_status: String = STATUS_OPEN) -> bool:
	var data: Dictionary = {
		SERIALIZED_KEY_ACTIVE: true,
		SERIALIZED_KEY_WINDOW_ID: window_id,
		SERIALIZED_KEY_STAGE: stage,
		SERIALIZED_KEY_LIFECYCLE_ID: id,
		SERIALIZED_KEY_CONTROLLER: controller,
		SERIALIZED_KEY_CONTINUATION: continuation.duplicate(true),
		SERIALIZED_KEY_STATUS: window_status,
	}
	var validated: Dictionary = _validated_serialized_data(data)
	if validated.is_empty():
		return false
	_apply_serialized(validated)
	return true


func serialize() -> Dictionary:
	var data: Dictionary = {
		SERIALIZED_KEY_ACTIVE: _active,
		SERIALIZED_KEY_WINDOW_ID: _timing_window_id,
		SERIALIZED_KEY_STAGE: _lifecycle_stage,
		SERIALIZED_KEY_LIFECYCLE_ID: _lifecycle_id,
		SERIALIZED_KEY_CONTROLLER: _controller_player,
		SERIALIZED_KEY_CONTINUATION: _continuation_context.duplicate(true),
		SERIALIZED_KEY_STATUS: _status,
	}
	var validated: Dictionary = _validated_serialized_data(data)
	if validated.is_empty():
		push_error("Invalid TimingWindowState sanitized during serialization.")
		return _inactive_serialized_data()
	return validated


func load_from_serialized(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var data: Dictionary = _validated_serialized_data(raw as Dictionary)
	if data.is_empty():
		return false
	_apply_serialized(data)
	return true


func equals(other) -> bool:
	if other == null:
		return false
	return serialize() == other.serialize()


func is_inactive() -> bool:
	return not _active and _status == STATUS_INACTIVE


func is_valid() -> bool:
	return not _validated_serialized_data(_current_serialized_data()).is_empty()


static func _validated_serialized_data(raw_data: Dictionary) -> Dictionary:
	var data: Dictionary = raw_data.duplicate(true)
	if not _contains_only_supported_keys(data):
		return {}
	if not data.has(SERIALIZED_KEY_ACTIVE):
		return {}
	var active_value: Variant = data[SERIALIZED_KEY_ACTIVE]
	if typeof(active_value) != TYPE_BOOL:
		return {}

	var window_id_value: Variant = _optional_string(
			data, SERIALIZED_KEY_WINDOW_ID, "")
	var stage_value: Variant = _optional_string(data, SERIALIZED_KEY_STAGE, "")
	var lifecycle_id_value: Variant = _optional_string(
			data, SERIALIZED_KEY_LIFECYCLE_ID, "")
	var status_value: Variant = _optional_string(
			data, SERIALIZED_KEY_STATUS, STATUS_INACTIVE)
	var controller_value: Variant = _optional_int(
			data, SERIALIZED_KEY_CONTROLLER, -1)
	if window_id_value == null \
			or stage_value == null \
			or lifecycle_id_value == null \
			or status_value == null \
			or controller_value == null:
		return {}
	if not _VALID_STATUSES.has(status_value):
		return {}
	if not _is_valid_controller(int(controller_value)):
		return {}

	var continuation_value: Variant = data.get(
			SERIALIZED_KEY_CONTINUATION, {})
	if not continuation_value is Dictionary:
		return {}
	var continuation: Variant = _normalized_continuation_context(
			continuation_value as Dictionary)
	if continuation == null:
		return {}

	var normalized: Dictionary = {
		SERIALIZED_KEY_ACTIVE: bool(active_value),
		SERIALIZED_KEY_WINDOW_ID: String(window_id_value),
		SERIALIZED_KEY_STAGE: String(stage_value),
		SERIALIZED_KEY_LIFECYCLE_ID: String(lifecycle_id_value),
		SERIALIZED_KEY_CONTROLLER: int(controller_value),
		SERIALIZED_KEY_CONTINUATION: continuation as Dictionary,
		SERIALIZED_KEY_STATUS: String(status_value),
	}
	if not _has_consistent_serialized_semantics(normalized):
		return {}
	return normalized


func _apply_serialized(data: Dictionary) -> void:
	_active = bool(data[SERIALIZED_KEY_ACTIVE])
	_timing_window_id = String(data[SERIALIZED_KEY_WINDOW_ID])
	_lifecycle_stage = String(data[SERIALIZED_KEY_STAGE])
	_lifecycle_id = String(data[SERIALIZED_KEY_LIFECYCLE_ID])
	_controller_player = int(data[SERIALIZED_KEY_CONTROLLER])
	var continuation: Dictionary = data[SERIALIZED_KEY_CONTINUATION]
	_continuation_context = continuation.duplicate(true)
	_status = String(data[SERIALIZED_KEY_STATUS])


func _current_serialized_data() -> Dictionary:
	return {
		SERIALIZED_KEY_ACTIVE: _active,
		SERIALIZED_KEY_WINDOW_ID: _timing_window_id,
		SERIALIZED_KEY_STAGE: _lifecycle_stage,
		SERIALIZED_KEY_LIFECYCLE_ID: _lifecycle_id,
		SERIALIZED_KEY_CONTROLLER: _controller_player,
		SERIALIZED_KEY_CONTINUATION: _continuation_context.duplicate(true),
		SERIALIZED_KEY_STATUS: _status,
	}


static func _contains_only_supported_keys(data: Dictionary) -> bool:
	for key: Variant in data.keys():
		if typeof(key) != TYPE_STRING:
			return false
		var key_string: String = String(key)
		if _FORBIDDEN_KEYS.has(key_string):
			return false
		if not _SUPPORTED_KEYS.has(key_string):
			return false
	return true


static func _optional_string(
		data: Dictionary, key: String, default_value: String) -> Variant:
	if not data.has(key):
		return default_value
	var raw: Variant = data[key]
	if typeof(raw) != TYPE_STRING:
		return null
	return String(raw)


static func _optional_int(
		data: Dictionary, key: String, default_value: int) -> Variant:
	if not data.has(key):
		return default_value
	var raw: Variant = data[key]
	if typeof(raw) == TYPE_INT:
		return int(raw)
	if typeof(raw) == TYPE_FLOAT \
			and is_finite(float(raw)) \
			and float(raw) == floor(float(raw)):
		return int(raw)
	return null


static func _is_valid_controller(value: int) -> bool:
	return value == -1 or (value >= 0 and value < Constants.PLAYER_COUNT)


static func _normalized_continuation_context(context: Dictionary) -> Variant:
	var normalized: Dictionary = {}
	for key: Variant in context.keys():
		if typeof(key) != TYPE_STRING:
			return null
		var key_string: String = String(key)
		if not _SUPPORTED_CONTINUATION_KEYS.has(key_string):
			return null
		var value: Variant = context[key]
		if key_string == CONTINUATION_KEY_OWNER_PLAYER:
			if typeof(value) != TYPE_INT or not _is_valid_controller(int(value)):
				return null
			normalized[key_string] = int(value)
			continue
		if typeof(value) != TYPE_STRING or String(value).is_empty():
			return null
		normalized[key_string] = String(value)
	return normalized


static func _has_consistent_serialized_semantics(data: Dictionary) -> bool:
	if bool(data[SERIALIZED_KEY_ACTIVE]):
		return not String(data[SERIALIZED_KEY_WINDOW_ID]).is_empty() \
				and not String(data[SERIALIZED_KEY_STAGE]).is_empty() \
				and not String(data[SERIALIZED_KEY_LIFECYCLE_ID]).is_empty() \
				and [STATUS_OPEN, STATUS_CLOSING].has(
						String(data[SERIALIZED_KEY_STATUS]))
	return String(data[SERIALIZED_KEY_WINDOW_ID]).is_empty() \
			and String(data[SERIALIZED_KEY_STAGE]).is_empty() \
			and String(data[SERIALIZED_KEY_LIFECYCLE_ID]).is_empty() \
			and int(data[SERIALIZED_KEY_CONTROLLER]) == -1 \
			and (data[SERIALIZED_KEY_CONTINUATION] as Dictionary).is_empty() \
			and String(data[SERIALIZED_KEY_STATUS]) == STATUS_INACTIVE


static func _inactive_serialized_data() -> Dictionary:
	return {
		SERIALIZED_KEY_ACTIVE: false,
		SERIALIZED_KEY_WINDOW_ID: "",
		SERIALIZED_KEY_STAGE: "",
		SERIALIZED_KEY_LIFECYCLE_ID: "",
		SERIALIZED_KEY_CONTROLLER: -1,
		SERIALIZED_KEY_CONTINUATION: {},
		SERIALIZED_KEY_STATUS: STATUS_INACTIVE,
	}

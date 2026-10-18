## Declared integer policy for publish_attack_flow.flow_payload only.
## Validation is pure; canonical_copy changes only a deep copy.
class_name AttackPublicationPayloadIntegers
extends RefCounted


const MAX_FLOW_INTEGER: int = 2147483647
const MAX_JSON_INTEGER: int = 9007199254740991
const DIRECT_FIELDS: Array[String] = [
	"attacker_player", "attacker_ship_index", "attacker_squadron_index",
	"attacker_zone", "controller_player", "defender_index",
	"defender_player", "defender_ship_index", "defender_speed",
	"defender_squadron_index", "ship_target_attacks_this_round",
	"accuracy_count", "spendable_accuracy_count", "chooser_player",
	"final_damage", "modified_damage", "redirect_remaining",
	"pending_card_index", "pending_ship_index",
	"pending_ship_owner_player", "swarm_controller_player",
	"counter_controller_player", "counter_attacker_player",
	"counter_attacker_squadron_index", "counter_target_player",
	"counter_target_squadron_index", "target_ship_index",
	"target_squadron_index",
]
const INTEGER_ARRAYS: Array[String] = [
	"locked_tokens", "blocked_defense_token_indices",
	"ecm_authorized_indices", "redirect_adjacent_zones",
	"spent_defense_token_types", "swarm_die_indices",
]
const PLAYER_FIELDS: Array[String] = [
	"attacker_player", "chooser_player", "pending_ship_owner_player",
	"counter_attacker_player", "counter_target_player",
]
const OPTIONAL_PLAYER_FIELDS: Array[String] = [
	"controller_player", "defender_player", "swarm_controller_player",
	"counter_controller_player",
]
const OPTIONAL_INDEX_FIELDS: Array[String] = [
	"attacker_ship_index", "attacker_squadron_index", "attacker_zone",
	"defender_index", "defender_ship_index", "defender_speed",
	"defender_squadron_index", "defender_zone", "pending_card_index",
	"pending_ship_index", "target_ship_index", "target_squadron_index",
]


static func validate(raw: Variant) -> String:
	if not raw is Dictionary:
		return "Attack-flow publication requires a Dictionary flow payload."
	return _visit(raw as Dictionary, false)


static func canonical_copy(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var copy: Dictionary = (raw as Dictionary).duplicate(true)
	if not _visit(copy, true).is_empty():
		return null
	return copy


static func _visit(data: Dictionary, convert: bool) -> String:
	for key: String in DIRECT_FIELDS:
		var reason: String = _field(data, key, convert)
		if not reason.is_empty():
			return reason
	var mixed_reason: String = _field(data, "defender_zone", convert, true)
	if not mixed_reason.is_empty():
		return mixed_reason
	for key: String in INTEGER_ARRAYS:
		var reason: String = _array(data, key, convert)
		if not reason.is_empty():
			return reason
	for key: String in ["dice_pool", "counter_dice_pool"]:
		var reason: String = _dictionary(data, key, convert)
		if not reason.is_empty():
			return reason
	for key: String in ["dice_results", "defense_tokens"]:
		var fields: Array[String] = []
		if key == "dice_results":
			fields = ["color", "face"]
		else:
			fields = ["type", "state"]
		var reason: String = _structured_array(data, key, fields,
				key == "dice_results", convert)
		if not reason.is_empty():
			return reason
	for key: String in ["pending_die_removal", "ecm_choice", "choice_info"]:
		var fields: Array[String] = []
		match key:
			"pending_die_removal":
				fields = ["controller_player"]
			"ecm_choice":
				fields = ["defender_player", "defender_ship_index"]
			"choice_info":
				fields = ["max_selections"]
		var reason: String = _nested(data, key, fields, convert)
		if not reason.is_empty():
			return reason
	if data.has("ecm_choice"):
		return _array(data["ecm_choice"] as Dictionary,
				"eligible_token_indices", convert)
	return ""


static func _field(data: Dictionary, key: String, convert: bool,
		mixed_string: bool = false, dictionary_value: bool = false) -> String:
	if not data.has(key):
		return ""
	var raw: Variant = data[key]
	if mixed_string and typeof(raw) == TYPE_STRING:
		return ""
	var minimum: int = 0
	var maximum: int = MAX_FLOW_INTEGER
	if dictionary_value:
		minimum = -MAX_JSON_INTEGER
		maximum = MAX_JSON_INTEGER
	elif OPTIONAL_PLAYER_FIELDS.has(key):
		minimum = -1
		maximum = Constants.PLAYER_COUNT - 1
	elif PLAYER_FIELDS.has(key):
		maximum = Constants.PLAYER_COUNT - 1
	elif OPTIONAL_INDEX_FIELDS.has(key):
		minimum = -1
	if typeof(raw) == TYPE_INT:
		if int(raw) < minimum or int(raw) > maximum:
			return "Invalid attack-flow integer field: %s." % key
		return ""
	if typeof(raw) != TYPE_FLOAT:
		return "Invalid attack-flow integer field: %s." % key
	var value: float = float(raw)
	if not is_finite(value) or value != floor(value) \
			or absf(value) > float(MAX_JSON_INTEGER) \
			or value < float(minimum) or value > float(maximum):
		return "Invalid attack-flow integer field: %s." % key
	if convert:
		data[key] = int(value)
	return ""


static func _array(data: Dictionary, key: String, convert: bool) -> String:
	if not data.has(key):
		return ""
	if not data[key] is Array:
		return "Invalid attack-flow integer array: %s." % key
	var values: Array = data[key] as Array
	for index: int in range(values.size()):
		var holder: Dictionary = {"value": values[index]}
		var reason: String = _field(holder, "value", convert)
		if not reason.is_empty():
			return "Invalid attack-flow integer array: %s[%d]." % [key, index]
		if convert:
			values[index] = holder["value"]
	return ""


static func _dictionary(data: Dictionary, key: String, convert: bool) -> String:
	if not data.has(key):
		return ""
	if not data[key] is Dictionary:
		return "Invalid attack-flow integer dictionary: %s." % key
	var values: Dictionary = data[key] as Dictionary
	for member: Variant in values.keys():
		var holder: Dictionary = {"value": values[member]}
		var reason: String = _field(holder, "value", convert, false, true)
		if not reason.is_empty():
			return "Invalid attack-flow integer dictionary: %s." % key
		if convert:
			values[member] = holder["value"]
	return ""


static func _structured_array(data: Dictionary, key: String,
		fields: Array[String], mixed_string: bool, convert: bool) -> String:
	if not data.has(key):
		return ""
	if not data[key] is Array:
		return "Invalid attack-flow structured array: %s." % key
	for entry: Variant in data[key] as Array:
		if not entry is Dictionary:
			return "Invalid attack-flow structured array: %s." % key
		for field: String in fields:
			var reason: String = _field(entry as Dictionary, field,
					convert, mixed_string)
			if not reason.is_empty():
				return reason
	return ""


static func _nested(data: Dictionary, key: String,
		fields: Array[String], convert: bool) -> String:
	if not data.has(key):
		return ""
	if not data[key] is Dictionary:
		return "Invalid attack-flow nested dictionary: %s." % key
	for field: String in fields:
		var reason: String = _field(data[key] as Dictionary, field, convert)
		if not reason.is_empty():
			return reason
	return ""

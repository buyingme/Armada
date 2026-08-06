## GameCommand
##
## Abstract base class for all player-initiated game actions.
## Each command encapsulates a single atomic state change that can be
## serialized for network transmission, recorded for replay, and
## (optionally) undone.
##
## Subclasses override [method execute] to apply the action to the game
## state and return a result dictionary.
##
## Usage:
## [codeblock]
## var cmd := RollDiceCommand.new(0, {"pool": pool_dict})
## CommandProcessor.submit(cmd)
## [/codeblock]
##
## Rules Reference: architectural decision — all game-changing player
## actions must be serializable for multiplayer and replay.
class_name GameCommand
extends RefCounted


## Command payload fields whose canonical contract is integer-valued.
##
## Godot's JSON parser returns JSON numbers as floats.  Replay and network
## reconstruction therefore restore only the fields explicitly listed here;
## legitimate floating-point payloads such as normalized positions and
## rotations are intentionally absent.
const _INTEGER_PAYLOAD_FIELDS: Dictionary = {
	"activate_ship": ["ship_index"],
	"activate_squadron": ["squadron_index"],
	"advance_activation_step": ["ship_index"],
	"advance_phase": ["next_phase"],
	"assign_dials": ["ship_index"],
	"begin_attack": [
		"attacker_player", "attacker_index", "attacker_zone",
		"defender_player", "defender_index", "defender_zone",
	],
	"commit_defense": ["ship_index"],
	"commit_setup_deployment": ["owner_player", "speed"],
	"complete_squadron_activation": ["squadron_index"],
	"convert_dial_to_token": ["ship_index"],
	"counter_choice": [
		"counter_attacker_player", "counter_attacker_squadron_index",
		"counter_target_player", "counter_target_squadron_index",
	],
	"debug_deal_damage": ["owner_player", "ship_index"],
	"destroy_unit": ["owner_player", "ship_index"],
	"discard_token": ["ship_index", "token_type"],
	"end_activation": ["ship_index"],
	"execute_maneuver": [
		"ship_index", "speed", "yaw_bonus_joint", "speed_delta",
	],
	"move_squadron": ["squadron_index"],
	"overlap_damage": ["ship_index", "other_owner", "other_ship_index"],
	"persistent_effect_damage": ["owner_player", "ship_index"],
	"publish_attack_flow": [
		"step_id", "controller_player", "attacker_player",
		"defender_player", "chooser_player",
	],
	"redirect_done": ["ship_index", "token_index"],
	"repair_action": ["owner_player", "ship_index", "card_index"],
	"reroll_attack_die": ["die_index", "expected_color", "expected_face"],
	"resolve_damage": [
		"actual_damage", "hull_damage", "owner_player", "shield_damage",
		"ship_index", "squadron_index",
	],
	"resolve_immediate_effect": ["owner_player", "ship_index", "card_index"],
	"reveal_dial": ["ship_index"],
	"select_evade_die": [
		"ship_index", "die_index", "expected_color", "expected_face",
		"token_index",
	],
	"select_redirect_zone": [
		"ship_index", "zone", "expected_shields", "token_index",
	],
	"set_speed": ["ship_index", "new_speed"],
	"spend_defense_token": [
		"ship_index", "token_index", "expected_token_type",
	],
	"spend_dial": ["ship_index"],
	"spend_token": ["ship_index", "token_type"],
	"start_displacement": ["ship_index", "controller_player"],
	"tarkin_choice": ["command"],
	"use_concentrate_fire_token_reroll": [
		"die_index", "expected_color", "expected_face",
	],
	"use_h9": [
		"die_index", "expected_color", "expected_face", "target_face",
	],
}

## Integer arrays have their entries restored independently.  An integral
## float is accepted only at this declared integer boundary.
const _INTEGER_ARRAY_PAYLOAD_FIELDS: Dictionary = {
	"assign_dials": ["commands"],
	"commit_accuracy": ["locked_tokens"],
	"commit_defense": ["selected_indices"],
	"execute_maneuver": ["yaw_clicks"],
}

## Structured array entries that mix integer identity with legitimate floats.
const _NESTED_INTEGER_PAYLOAD_FIELDS: Dictionary = {
	"commit_displacement": {
		"placements": ["owner", "squadron_index"],
	},
	"start_displacement": {
		"displaced_squadrons": ["owner", "squadron_index"],
	},
}

## Largest integer that can be represented exactly by a JSON-decoded IEEE-754
## double.  Larger exact integers require an explicit string representation at
## their owning serialization boundary.
const _MAX_SAFE_JSON_INTEGER: float = 9007199254740991.0


## The player who issued this command (0 or 1).
var player_index: int = 0

## Machine-readable type string (e.g. "assign_dials", "roll_dice").
## Populated automatically by each subclass.
var command_type: String = ""

## Arbitrary payload carrying command-specific data.
var payload: Dictionary = {}

## Server-assigned sequence number (set by [CommandProcessor]).
var sequence: int = -1


## Creates a command.
## [param p_player] — player index (0 or 1).
## [param p_type] — command type string.
## [param p_payload] — command-specific data dictionary.
func _init(p_player: int = 0, p_type: String = "",
		p_payload: Dictionary = {}) -> void:
	player_index = p_player
	command_type = p_type
	payload = p_payload


## Executes the command against the given [param game_state].
## Returns a result dictionary whose shape depends on the subclass.
## Subclasses **must** override this method.
func execute(_game_state: GameState) -> Dictionary:
	push_warning("GameCommand.execute() called on base class — "
			+"override in subclass '%s'." % command_type)
	return {}


## Validates whether this command is legal in the current game state.
## Returns an empty string if valid, or an error message if not.
## Subclasses should override for command-specific validation.
func validate(game_state: GameState) -> String:
	if game_state == null:
		return "No active game state."
	return ""


## Serializes the command to a dictionary suitable for JSON encoding
## or network transmission.
func serialize() -> Dictionary:
	return {
		"type": command_type,
		"player": player_index,
		"sequence": sequence,
		"payload": payload,
	}


## Deserializes a command from a dictionary.
## Dispatches to the correct subclass via the command registry.
## Returns null if the type or canonical numeric payload shape is invalid.
static func deserialize(data: Dictionary) -> GameCommand:
	var canonical: Dictionary = canonicalize_serialized(data)
	if canonical.is_empty():
		return null
	var cmd_type: String = canonical.get("type", "")
	var player: int = int(canonical.get("player", 0))
	var seq: int = int(canonical.get("sequence", -1))
	var cmd_payload: Dictionary = canonical.get("payload", {}) as Dictionary
	var cmd: GameCommand = _create_by_type(cmd_type, player, cmd_payload)
	if cmd:
		cmd.sequence = seq
	return cmd


## Restores the canonical command envelope and declared integer payload fields.
## This is shared by replay loading and normal command reconstruction so disk,
## mirror, and live command factories receive the same semantic types.
static func canonicalize_serialized(data: Dictionary) -> Dictionary:
	var command_type_value: Variant = data.get("type", "")
	if typeof(command_type_value) != TYPE_STRING \
			or str(command_type_value).is_empty():
		return {}
	var player_value: Variant = _canonical_integer(data.get("player", 0))
	var sequence_value: Variant = _canonical_integer(data.get("sequence", -1))
	var raw_payload: Variant = data.get("payload", {})
	if player_value == null or sequence_value == null \
			or not raw_payload is Dictionary:
		return {}
	var canonical_payload: Variant = _canonicalize_payload(
			str(command_type_value), raw_payload as Dictionary)
	if canonical_payload == null:
		return {}
	return {
		"type": str(command_type_value),
		"player": int(player_value),
		"sequence": int(sequence_value),
		"payload": canonical_payload,
	}


static func _canonicalize_payload(command_type_value: String,
		raw_payload: Dictionary) -> Variant:
	var result: Dictionary = raw_payload.duplicate(true)
	for field: String in _string_array(
			_INTEGER_PAYLOAD_FIELDS.get(command_type_value, [])):
		if result.has(field) and not _canonicalize_integer_field(result, field):
			return null
	for field: String in _string_array(
			_INTEGER_ARRAY_PAYLOAD_FIELDS.get(command_type_value, [])):
		if result.has(field) and not _canonicalize_integer_array(result, field):
			return null
	var nested_schema: Dictionary = _NESTED_INTEGER_PAYLOAD_FIELDS.get(
			command_type_value, {}) as Dictionary
	for array_field: Variant in nested_schema:
		var field_name: String = str(array_field)
		if result.has(field_name) and not _canonicalize_nested_integer_array(
				result, field_name,
				_string_array(nested_schema.get(array_field, []))):
			return null
	if not _canonicalize_structured_payload(command_type_value, result):
		return null
	return result


static func _canonicalize_structured_payload(command_type_value: String,
		values: Dictionary) -> bool:
	if command_type_value == "roll_dice" and values.has("dice_pool"):
		return _canonicalize_integer_dictionary(values, "dice_pool")
	if command_type_value != "publish_attack_flow" \
			or not values.has("flow_payload"):
		return true
	var raw_flow_payload: Variant = values.get("flow_payload")
	if not raw_flow_payload is Dictionary:
		return false
	var flow_payload: Dictionary = \
			(raw_flow_payload as Dictionary).duplicate(true)
	# This legacy projection has a few accepted string variants (for example
	# defender_zone="front" and dice face="hit").  Restore only numeric values
	# at the explicitly integer-capable fields and preserve those strings.
	for field: String in [
			"attacker_player", "attacker_ship_index",
			"attacker_squadron_index", "attacker_zone", "chooser_player",
			"controller_player", "defender_player", "defender_ship_index",
			"defender_speed", "defender_zone", "final_damage",
			"modified_damage", "redirect_remaining", "target_ship_index",
			"target_squadron_index"]:
		if flow_payload.has(field) \
				and not _canonicalize_integer_if_numeric(flow_payload, field):
			return false
	if flow_payload.has("locked_tokens") \
			and not _canonicalize_integer_array(flow_payload, "locked_tokens"):
		return false
	if flow_payload.has("defense_tokens") \
			and not _canonicalize_nested_integer_array(
					flow_payload, "defense_tokens", ["type", "state"]):
		return false
	if flow_payload.has("dice_results") \
			and not _canonicalize_mixed_nested_integer_array(
					flow_payload, "dice_results", ["color", "face"]):
		return false
	if flow_payload.has("dice_pool") \
			and not _canonicalize_integer_dictionary(flow_payload, "dice_pool"):
		return false
	values["flow_payload"] = flow_payload
	return true


static func _canonicalize_integer_field(values: Dictionary,
		field: String) -> bool:
	var canonical: Variant = _canonical_integer(values.get(field))
	if canonical == null:
		return false
	values[field] = canonical
	return true


static func _canonicalize_integer_if_numeric(values: Dictionary,
		field: String) -> bool:
	var raw: Variant = values.get(field)
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return true
	return _canonicalize_integer_field(values, field)


static func _canonicalize_integer_array(values: Dictionary,
		field: String) -> bool:
	var raw: Variant = values.get(field)
	if not raw is Array:
		return false
	var canonical_values: Array = (raw as Array).duplicate()
	for index: int in range(canonical_values.size()):
		var canonical: Variant = _canonical_integer(canonical_values[index])
		if canonical == null:
			return false
		canonical_values[index] = canonical
	values[field] = canonical_values
	return true


static func _canonicalize_integer_dictionary(values: Dictionary,
		field: String) -> bool:
	var raw: Variant = values.get(field)
	if not raw is Dictionary:
		return false
	var canonical_values: Dictionary = (raw as Dictionary).duplicate(true)
	for key: Variant in canonical_values:
		var canonical: Variant = _canonical_integer(canonical_values.get(key))
		if canonical == null:
			return false
		canonical_values[key] = canonical
	values[field] = canonical_values
	return true


static func _canonicalize_nested_integer_array(values: Dictionary,
		array_field: String, integer_fields: Array[String]) -> bool:
	var raw: Variant = values.get(array_field)
	if not raw is Array:
		return false
	var canonical_entries: Array = []
	for raw_entry: Variant in raw as Array:
		if not raw_entry is Dictionary:
			return false
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		for field: String in integer_fields:
			if entry.has(field) and not _canonicalize_integer_field(entry, field):
				return false
		canonical_entries.append(entry)
	values[array_field] = canonical_entries
	return true


static func _canonicalize_mixed_nested_integer_array(values: Dictionary,
		array_field: String, integer_fields: Array[String]) -> bool:
	var raw: Variant = values.get(array_field)
	if not raw is Array:
		return false
	var canonical_entries: Array = []
	for raw_entry: Variant in raw as Array:
		if not raw_entry is Dictionary:
			return false
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		for field: String in integer_fields:
			if entry.has(field) \
					and not _canonicalize_integer_if_numeric(entry, field):
				return false
		canonical_entries.append(entry)
	values[array_field] = canonical_entries
	return true


static func _canonical_integer(raw: Variant) -> Variant:
	if typeof(raw) == TYPE_INT:
		return int(raw)
	if typeof(raw) != TYPE_FLOAT:
		return null
	var value: float = float(raw)
	if not is_finite(value) or value != floor(value) \
			or absf(value) > _MAX_SAFE_JSON_INTEGER:
		return null
	return int(value)


static func _string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for value: Variant in raw as Array:
			result.append(str(value))
	return result


## Returns a human-readable description of the command for logging.
func describe() -> String:
	return "[%s] player=%d seq=%d" % [command_type, player_index,
			sequence]


# ---------------------------------------------------------------------------
# Registry — maps type strings to factory callables
# ---------------------------------------------------------------------------

## Registry mapping command_type strings to factory [Callable]s.
## Each callable signature: func(player: int, payload: Dictionary) -> GameCommand
static var _registry: Dictionary = {}


## Registers a command type with its factory callable.
## Call this from each concrete command's class body or from
## [CommandProcessor._ready].
static func register_type(type_name: String,
		factory: Callable) -> void:
	_registry[type_name] = factory


static func _clear_registry_for_shutdown() -> void:
	_registry.clear()


## Returns sorted command type names currently registered with the factory.
static func registered_types() -> Array[String]:
	var types: Array[String] = []
	for type_name: Variant in _registry.keys():
		types.append(str(type_name))
	types.sort()
	return types


## Returns whether [param type_name] resolves through the canonical command
## registry. Timing-window projections use this without creating another
## command catalogue.
static func is_type_registered(type_name: String) -> bool:
	return not type_name.is_empty() and _registry.has(type_name)


## Creates a command by type name via the registry.
## Returns null if the type is not registered.
static func _create_by_type(type_name: String, player: int,
		cmd_payload: Dictionary) -> GameCommand:
	if _registry.has(type_name):
		var factory: Callable = _registry[type_name]
		return factory.call(player, cmd_payload)
	push_warning("Unknown command type: '%s'" % type_name)
	return null

## InteractionFlow
##
## Authoritative description of the active interactive UI state.
## Held inside [GameState.interaction_flow]; mutated only inside
## [GameCommand.execute()].  Travels with [GameState] across the network
## (via [code]command_result[/code]) and across save/load (via
## [code]GameState.serialize()[/code]).
##
## Replaces the legacy parallel RPC interaction-state channel
## (G4.6.6 T1a).  See [code]docs/refactoring_phase_i_plan.md[/code].
##
## Rules: see [code].skills/architecture_patterns.md[/code] §5 and
## [code].skills/serialization_and_commands.md[/code] §1–§2.
class_name InteractionFlow
extends RefCounted


const _COUNTER_PLAYER_IDENTITY_FIELDS: Array[String] = [
	"counter_attacker_player", "counter_target_player",
]
const _COUNTER_SQUADRON_IDENTITY_FIELDS: Array[String] = [
	"counter_attacker_squadron_index", "counter_target_squadron_index",
]
const _MAX_COUNTER_SQUADRON_INDEX: int = 2147483647
const _MAX_JSON_INTEGER: int = 9007199254740991
const _MAX_FLOW_INTEGER: int = 2147483647

# Only production-declared payload members are reconstructed. Attack uses one
# cumulative schema at every reachable step because its FSM retains patches.
const _STEP_INTEGER_FIELDS: Dictionary = {
	Constants.InteractionStep.NONE: ["active_player"],
	Constants.InteractionStep.SELECT_DIALS: ["active_player"],
	Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS: ["active_player"],
	Constants.InteractionStep.WAIT_FOR_SHIP_SELECT: ["active_player"],
	Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT: [
		"active_player", "squadron_index"],
	Constants.InteractionStep.GAME_OVER_STEP: ["active_player"],
	Constants.InteractionStep.ACTIVATION_MODAL_OPEN: ["ship_index"],
	Constants.InteractionStep.REVEAL_DIAL: ["ship_index"],
	Constants.InteractionStep.SPEND_DIAL: ["ship_index"],
	Constants.InteractionStep.REPAIR_STEP: ["ship_index"],
	Constants.InteractionStep.ATTACK_STEP: ["ship_index"],
	Constants.InteractionStep.MANEUVER_STEP: ["ship_index"],
	Constants.InteractionStep.ACTIVATION_DONE: ["ship_index"],
	Constants.InteractionStep.SQUADRON_STEP: ["ship_index", "squadron_index"],
	Constants.InteractionStep.ACTION_CHOICE: ["ship_index", "squadron_index"],
	Constants.InteractionStep.SQUAD_MOVE: ["ship_index", "squadron_index"],
	Constants.InteractionStep.SQUAD_ATTACK: ["ship_index", "squadron_index"],
	Constants.InteractionStep.TARKIN_COMMAND_CHOICE: [
		"owner_player", "source_ship_index"],
	Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT: [
		"first_player", "controller_player", "obstacle_count"],
	Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT: [
		"first_player", "controller_player"],
	Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT: [
		"first_player", "controller_player"],
	Constants.InteractionStep.SETUP_REVIEW: ["first_player"],
}
const _FLOW_STEPS: Dictionary = {
	Constants.InteractionFlow.NONE: [Constants.InteractionStep.NONE],
	Constants.InteractionFlow.COMMAND_PHASE: [
		Constants.InteractionStep.SELECT_DIALS,
		Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS],
	Constants.InteractionFlow.SHIP_ACTIVATION: [
		Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
		Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
		Constants.InteractionStep.REVEAL_DIAL,
		Constants.InteractionStep.SPEND_DIAL,
		Constants.InteractionStep.REPAIR_STEP,
		Constants.InteractionStep.ATTACK_STEP,
		Constants.InteractionStep.MANEUVER_STEP,
		Constants.InteractionStep.ACTIVATION_DONE,
		Constants.InteractionStep.SQUADRON_STEP,
		Constants.InteractionStep.TARKIN_COMMAND_CHOICE],
	Constants.InteractionFlow.SQUADRON_ACTIVATION: [
		Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
		Constants.InteractionStep.ACTION_CHOICE,
		Constants.InteractionStep.SQUAD_MOVE,
		Constants.InteractionStep.SQUAD_ATTACK],
	Constants.InteractionFlow.SETUP: [
		Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT,
		Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
		Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT,
		Constants.InteractionStep.SETUP_REVIEW],
	Constants.InteractionFlow.GAME_OVER: [
		Constants.InteractionStep.GAME_OVER_STEP],
}
const _ATTACK_STEPS: Array[int] = [
	Constants.InteractionStep.ATTACK_DECLARE,
	Constants.InteractionStep.ATTACK_ROLL,
	Constants.InteractionStep.ATTACK_MODIFY,
	Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
	Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
	Constants.InteractionStep.ATTACK_CRITICAL_CHOICE,
	Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
]
const _ATTACK_INTEGER_FIELDS: Array[String] = [
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
const _ATTACK_INTEGER_ARRAYS: Array[String] = [
	"locked_tokens", "blocked_defense_token_indices",
	"ecm_authorized_indices", "redirect_adjacent_zones",
	"spent_defense_token_types", "swarm_die_indices",
]
const _PLAYER_FIELDS: Array[String] = [
	"active_player", "owner_player", "first_player", "attacker_player",
	"chooser_player", "pending_ship_owner_player",
	"counter_attacker_player", "counter_target_player",
	"source_owner_player",
]
const _OPTIONAL_PLAYER_FIELDS: Array[String] = [
	"controller_player", "defender_player", "swarm_controller_player",
	"counter_controller_player",
]
const _OPTIONAL_INDEX_FIELDS: Array[String] = [
	"attacker_ship_index", "attacker_squadron_index", "attacker_zone",
	"defender_index", "defender_ship_index", "defender_speed",
	"defender_squadron_index", "defender_zone", "pending_card_index",
	"pending_ship_index", "target_ship_index", "target_squadron_index",
]


# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## High-level flow currently active.
var flow_type: Constants.InteractionFlow = Constants.InteractionFlow.NONE

## Specific step within the active flow.
var step_id: Constants.InteractionStep = Constants.InteractionStep.NONE

## Player index (0 or 1) that holds authority over this interaction window.
## −1 means the server controls the transition (no player input expected).
var controller_player: int = -1

## Visibility scope of [member payload].  Filtered by [StateFilter] before
## a snapshot leaves the server.
var visible_to: Constants.Visibility = Constants.Visibility.ALL

## Optional step-specific data (e.g. ship_index, attack_id, available
## defense tokens).  JSON-safe plain types only — no Vector2, Color, or
## pixel values.  See [code].skills/serialization_and_commands.md[/code]
## §2.2.
var payload: Dictionary = {}


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Constructs a flow descriptor with all fields set.
## Convenience for [GameCommand.execute()] mutation sites.
static func make(
		flow_type: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		controller_player: int,
		visible_to: Constants.Visibility = Constants.Visibility.ALL,
		payload: Dictionary = {}) -> InteractionFlow:
	var f: InteractionFlow = InteractionFlow.new()
	f.flow_type = flow_type
	f.step_id = step_id
	f.controller_player = controller_player
	f.visible_to = visible_to
	f.payload = payload.duplicate(true)
	return f


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialises this flow to a JSON-safe Dictionary.
## Enums are stored as int per the serialization contract.
func serialize() -> Dictionary:
	return {
		"flow_type": int(flow_type),
		"step_id": int(step_id),
		"controller_player": controller_player,
		"visible_to": int(visible_to),
		"payload": payload.duplicate(true),
	}


## Reconstructs an [InteractionFlow] from a serialised Dictionary.
## Uses [code].get(key, default)[/code] throughout for forward compatibility.
static func deserialize(data: Dictionary) -> InteractionFlow:
	var f: InteractionFlow = InteractionFlow.new()
	f.flow_type = (int(data.get("flow_type", 0))) as Constants.InteractionFlow
	f.step_id = (int(data.get("step_id", 0))) as Constants.InteractionStep
	f.controller_player = int(data.get("controller_player", -1))
	f.visible_to = (int(data.get("visible_to", 0))) as Constants.Visibility
	var raw_payload: Variant = data.get("payload", {})
	if raw_payload is Dictionary:
		f.payload = (raw_payload as Dictionary).duplicate(true)
		if not _normalize_declared_payload(f):
			return null
		if f.flow_type == Constants.InteractionFlow.SQUADRON_DISPLACEMENT \
				and not f.payload.is_empty():
			for key: String in ["owner_player", "ship_index"]:
				if not _normalize_displacement_identity(f.payload, key):
					return null
			var entries: Variant = f.payload.get("displaced_squadrons")
			if not entries is Array:
				return null
			for raw_entry: Variant in entries as Array:
				if not raw_entry is Dictionary:
					return null
				for key: String in ["owner", "squadron_index"]:
					if not _normalize_displacement_identity(
							raw_entry as Dictionary, key):
						return null
	else:
		if f.flow_type == Constants.InteractionFlow.ATTACK \
				and f.step_id \
						== Constants.InteractionStep.ATTACK_COUNTER_CHOICE:
			return null
		f.payload = {}
	return f


static func _normalize_declared_payload(flow: InteractionFlow) -> bool:
	var data: Dictionary = flow.payload
	var flow_id: int = int(flow.flow_type)
	var step: int = int(flow.step_id)
	if flow_id == Constants.InteractionFlow.ATTACK \
			and _ATTACK_STEPS.has(step):
		if not _normalize_integer_fields(data, _ATTACK_INTEGER_FIELDS) \
				or not _normalize_mixed_field(data, "defender_zone"):
			return false
		for key: String in _ATTACK_INTEGER_ARRAYS:
			if data.has(key) and not _normalize_integer_array(data, key):
				return false
		for key: String in ["dice_pool", "counter_dice_pool"]:
			if data.has(key) and not _normalize_integer_dictionary(data, key):
				return false
		if not _normalize_structured_array(data, "dice_results",
				["color", "face"], true) \
				or not _normalize_structured_array(data, "defense_tokens",
				["type", "state"], false):
			return false
		if not _normalize_nested_fields(data, "pending_die_removal",
				["controller_player"]) \
				or not _normalize_nested_fields(data, "ecm_choice",
				["defender_player", "defender_ship_index"]) \
				or not _normalize_nested_fields(data, "choice_info",
				["max_selections"]):
			return false
		if data.has("ecm_choice") \
				and not _normalize_integer_array(
					data["ecm_choice"] as Dictionary,
					"eligible_token_indices", true):
			return false
		if step == Constants.InteractionStep.ATTACK_COUNTER_CHOICE:
			return _normalize_counter_participant_identity(data)
		return true
	if flow_id == Constants.InteractionFlow.STATUS_CLEANUP \
			and step == Constants.InteractionStep.STATUS_CLEANUP_STEP:
		return _normalize_structured_array(data, "ecm_ready_cost_choices",
				["owner_player", "ship_index"], false) \
				and _normalize_structured_array(data, "optional_status_rules",
					["owner_player", "ship_index"], false)
	if _FLOW_STEPS.has(flow_id) \
			and (step in (_FLOW_STEPS[flow_id] as Array)):
		if not _normalize_integer_fields(data,
				_STEP_INTEGER_FIELDS.get(step, [])):
			return false
		if flow_id == Constants.InteractionFlow.SHIP_ACTIVATION \
				and step == Constants.InteractionStep.TARKIN_COMMAND_CHOICE \
				and data.has("available_commands") \
				and not _normalize_integer_array(data, "available_commands"):
			return false
		if flow_id == Constants.InteractionFlow.SETUP \
				and step in [
					Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
					Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT]:
			return _normalize_nested_fields(data, "deployment_pick",
					["owner_player", "required_count"])
	return true


static func _normalize_integer_fields(data: Dictionary, fields: Array) -> bool:
	for key: String in fields:
		if data.has(key) and not _normalize_integer_field(data, key):
			return false
	return true


static func _normalize_integer_field(data: Dictionary, key: String,
		mixed_string: bool = false, dictionary_value: bool = false) -> bool:
	var raw: Variant = data[key]
	if mixed_string and typeof(raw) == TYPE_STRING:
		return true
	var minimum: int = 0
	var maximum: int = _MAX_FLOW_INTEGER
	if dictionary_value:
		minimum = -_MAX_JSON_INTEGER
		maximum = _MAX_JSON_INTEGER
	elif _OPTIONAL_PLAYER_FIELDS.has(key):
		minimum = -1
		maximum = Constants.PLAYER_COUNT - 1
	elif _PLAYER_FIELDS.has(key):
		maximum = Constants.PLAYER_COUNT - 1
	elif _OPTIONAL_INDEX_FIELDS.has(key):
		minimum = -1
	if typeof(raw) == TYPE_INT:
		var value: int = int(raw)
		if value < minimum or value > maximum:
			return false
		return true
	if typeof(raw) != TYPE_FLOAT:
		return false
	var decoded: float = float(raw)
	if not is_finite(decoded) or decoded != floor(decoded) \
			or absf(decoded) > float(_MAX_JSON_INTEGER) \
			or decoded < float(minimum) or decoded > float(maximum):
		return false
	data[key] = int(decoded)
	return true


static func _normalize_mixed_field(data: Dictionary, key: String) -> bool:
	return not data.has(key) or _normalize_integer_field(data, key, true)


static func _normalize_integer_array(data: Dictionary, key: String,
		optional: bool = false) -> bool:
	if not data.has(key):
		return optional
	if not data[key] is Array:
		return false
	var values: Array = data[key] as Array
	for index: int in range(values.size()):
		var holder: Dictionary = {"value": values[index]}
		if not _normalize_integer_field(holder, "value"):
			return false
		values[index] = holder["value"]
	return true


static func _normalize_integer_dictionary(data: Dictionary,
		key: String) -> bool:
	if not data[key] is Dictionary:
		return false
	var values: Dictionary = data[key] as Dictionary
	for member: Variant in values.keys():
		var holder: Dictionary = {"value": values[member]}
		if not _normalize_integer_field(holder, "value", false, true):
			return false
		values[member] = holder["value"]
	return true


static func _normalize_nested_fields(data: Dictionary, key: String,
		fields: Array[String]) -> bool:
	if not data.has(key):
		return true
	if not data[key] is Dictionary:
		return false
	return _normalize_integer_fields(data[key] as Dictionary, fields)


static func _normalize_structured_array(data: Dictionary, key: String,
		fields: Array[String], mixed_string: bool) -> bool:
	if not data.has(key):
		return true
	if not data[key] is Array:
		return false
	for entry: Variant in data[key] as Array:
		if not entry is Dictionary:
			return false
		for field: String in fields:
			if (entry as Dictionary).has(field) \
					and not _normalize_integer_field(
						entry as Dictionary, field, mixed_string):
				return false
	return true


static func _normalize_counter_participant_identity(
		data: Dictionary) -> bool:
	for key: String in _COUNTER_PLAYER_IDENTITY_FIELDS:
		if not _normalize_counter_identity_field(
				data, key, Constants.PLAYER_COUNT - 1):
			return false
	for key: String in _COUNTER_SQUADRON_IDENTITY_FIELDS:
		if not _normalize_counter_identity_field(
				data, key, _MAX_COUNTER_SQUADRON_INDEX):
			return false
	return true


static func _normalize_counter_identity_field(data: Dictionary,
		key: String, maximum: int) -> bool:
	if not data.has(key):
		return false
	var raw: Variant = data[key]
	var value: int
	if typeof(raw) == TYPE_INT:
		value = int(raw)
	elif typeof(raw) == TYPE_FLOAT:
		var decoded: float = float(raw)
		if not is_finite(decoded) or decoded != floor(decoded) \
				or decoded < 0.0 or decoded > float(maximum):
			return false
		value = int(decoded)
	else:
		return false
	if value < 0 or value > maximum:
		return false
	data[key] = value
	return true


static func _normalize_displacement_identity(data: Dictionary,
		key: String) -> bool:
	var value: Variant = data.get(key)
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT and is_finite(value) \
			and value == floor(value) and absf(value) <= 2147483647.0:
		data[key] = int(value)
		return true
	return false


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns [code]true[/code] when [param player_index] is the player who
## must act on this interaction window.
func is_actor(player_index: int) -> bool:
	return controller_player == player_index


## Returns a fresh empty flow (NONE/NONE/-1/ALL/{}).
## Use as the default when [GameState] is reset.
static func empty() -> InteractionFlow:
	return InteractionFlow.new()


## Equality by all five fields.  Used by I2's invariant test.
func equals(other: InteractionFlow) -> bool:
	if other == null:
		return false
	if flow_type != other.flow_type:
		return false
	if step_id != other.step_id:
		return false
	if controller_player != other.controller_player:
		return false
	if visible_to != other.visible_to:
		return false
	return _payloads_equal(payload, other.payload)


static func _payloads_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k):
			return false
		if a[k] != b[k]:
			return false
	return true

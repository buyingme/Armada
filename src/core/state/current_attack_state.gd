## Canonical authoritative state for one individual attack.
##
## The state is value-like: callers receive copies of composite values and all
## mutation is installed through GameState after a complete replacement passes
## validation.
class_name CurrentAttackState
extends RefCounted


const STAGE_INACTIVE: String = "inactive"
const STAGE_PRE_ROLL: String = "pre_roll"
const STAGE_ATTACK_MODIFY: String = "attack_modify"
const STAGE_ACCURACY: String = "accuracy"
const STAGE_DEFENSE: String = "defense"
const STAGE_DAMAGE: String = "damage"
const STAGE_RESOLVED: String = "resolved"

const RESOLUTION_UNAVAILABLE: String = "unavailable"
const RESOLUTION_PENDING: String = "pending"
const RESOLUTION_USED: String = "used"
const RESOLUTION_DECLINED: String = "declined"

const DEFENSE_PENDING: String = "pending"
const DEFENSE_COMMITTED: String = "committed"
const DEFENSE_RESOLVING: String = "resolving"
const DEFENSE_COMPLETE: String = "complete"

const DAMAGE_PENDING: String = "pending"
const DAMAGE_RESOLVED: String = "resolved"

const KIND_SHIP: String = "ship"
const KIND_SQUADRON: String = "squadron"

const _STAGES: Array[String] = [
	STAGE_INACTIVE,
	STAGE_PRE_ROLL,
	STAGE_ATTACK_MODIFY,
	STAGE_ACCURACY,
	STAGE_DEFENSE,
	STAGE_DAMAGE,
	STAGE_RESOLVED,
]
const _RESOLUTIONS: Array[String] = [
	RESOLUTION_UNAVAILABLE,
	RESOLUTION_PENDING,
	RESOLUTION_USED,
	RESOLUTION_DECLINED,
]
const _DEFENSE_STAGES: Array[String] = [
	DEFENSE_PENDING,
	DEFENSE_COMMITTED,
	DEFENSE_RESOLVING,
	DEFENSE_COMPLETE,
]
const _DAMAGE_STAGES: Array[String] = [DAMAGE_PENDING, DAMAGE_RESOLVED]
const _KINDS: Array[String] = [KIND_SHIP, KIND_SQUADRON]
const _POOL_KEYS: Array[String] = ["RED", "BLUE", "BLACK"]

const _KEYS: Array[String] = [
	"active",
	"attack_id",
	"stage",
	"attacker_player",
	"attacker_kind",
	"attacker_index",
	"attacker_zone",
	"defender_player",
	"defender_kind",
	"defender_index",
	"defender_zone",
	"attack_kind",
	"range_band",
	"obstructed",
	"obstruction_resolved",
	"resolved_pool_choices",
	"dice_pool",
	"dice_results",
	"cf_dial_resolution",
	"cf_token_resolution",
	"accuracy_locked_tokens",
	"accuracy_complete",
	"defense_stage",
	"committed_defense_tokens",
	"resolved_defense_effects",
	"pending_evade",
	"redirect_allocations",
	"damage_stage",
	"resolved_outcome",
]

var _data: Dictionary = _inactive_data()

var active: bool:
	get:
		return bool(_data["active"])
var attack_id: String:
	get:
		return str(_data["attack_id"])
var stage: String:
	get:
		return str(_data["stage"])
var attacker_player: int:
	get:
		return int(_data["attacker_player"])
var attacker_kind: String:
	get:
		return str(_data["attacker_kind"])
var attacker_index: int:
	get:
		return int(_data["attacker_index"])
var attacker_zone: int:
	get:
		return int(_data["attacker_zone"])
var defender_player: int:
	get:
		return int(_data["defender_player"])
var defender_kind: String:
	get:
		return str(_data["defender_kind"])
var defender_index: int:
	get:
		return int(_data["defender_index"])
var defender_zone: int:
	get:
		return int(_data["defender_zone"])
var attack_kind: String:
	get:
		return str(_data["attack_kind"])
var range_band: String:
	get:
		return str(_data["range_band"])
var obstructed: bool:
	get:
		return bool(_data["obstructed"])
var obstruction_resolved: bool:
	get:
		return bool(_data["obstruction_resolved"])
var resolved_pool_choices: Array[String]:
	get:
		return _string_array(_data["resolved_pool_choices"] as Array)
var dice_pool: Dictionary:
	get:
		return (_data["dice_pool"] as Dictionary).duplicate(true)
var dice_results: Array[Dictionary]:
	get:
		return _dictionary_array(_data["dice_results"] as Array)
var cf_dial_resolution: String:
	get:
		return str(_data["cf_dial_resolution"])
var cf_token_resolution: String:
	get:
		return str(_data["cf_token_resolution"])
var accuracy_locked_tokens: Array[int]:
	get:
		return _int_array(_data["accuracy_locked_tokens"] as Array)
var accuracy_complete: bool:
	get:
		return bool(_data["accuracy_complete"])
var defense_stage: String:
	get:
		return str(_data["defense_stage"])
var committed_defense_tokens: Array[int]:
	get:
		return _int_array(_data["committed_defense_tokens"] as Array)
var resolved_defense_effects: Array[Dictionary]:
	get:
		return _dictionary_array(_data["resolved_defense_effects"] as Array)
var pending_evade: Dictionary:
	get:
		return (_data["pending_evade"] as Dictionary).duplicate(true)
var redirect_allocations: Array[Dictionary]:
	get:
		return _dictionary_array(_data["redirect_allocations"] as Array)
var damage_stage: String:
	get:
		return str(_data["damage_stage"])
var resolved_outcome: Dictionary:
	get:
		return (_data["resolved_outcome"] as Dictionary).duplicate(true)


func configure_active(id: String, values: Dictionary) -> bool:
	var candidate: Dictionary = _inactive_data()
	candidate["active"] = true
	candidate["attack_id"] = id
	candidate["stage"] = STAGE_PRE_ROLL
	for key: Variant in values.keys():
		candidate[key] = values[key]
	var normalized: Dictionary = _validated_data(candidate)
	if normalized.is_empty():
		return false
	_data = normalized
	return true


func with_patch(patch: Dictionary) -> CurrentAttackState:
	var candidate: Dictionary = serialize()
	for key: Variant in patch.keys():
		candidate[key] = patch[key]
	var replacement := CurrentAttackState.new()
	if not replacement.load_from_serialized(candidate):
		return null
	return replacement


func serialize() -> Dictionary:
	return _data.duplicate(true)


func load_from_serialized(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var normalized: Dictionary = _validated_data(raw as Dictionary)
	if normalized.is_empty():
		return false
	_data = normalized
	return true


func is_valid() -> bool:
	return not _validated_data(_data).is_empty()


func is_inactive() -> bool:
	return not active and stage == STAGE_INACTIVE


func derive_damage(game_state: GameState) -> int:
	if not active:
		return 0
	var base_damage: int = Dice.calculate_damage(dice_results)
	if attacker_kind == KIND_SQUADRON or defender_kind == KIND_SQUADRON:
		base_damage = Dice.calculate_damage_vs_squadron(dice_results)
	var context := EffectContext.new()
	context.attacker = _entity_for(
			game_state, attacker_kind, attacker_player, attacker_index)
	context.defender = _entity_for(
			game_state, defender_kind, defender_player, defender_index)
	context.dice_results = dice_results
	context.damage_total = base_damage
	context = RuleSurface.apply_modifiers(
			context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_ATTACK_DAMAGE)
	var damage: int = context.damage_total
	for effect: Dictionary in resolved_defense_effects:
		match int(effect.get("token_type", -1)):
			Constants.DefenseToken.SCATTER:
				damage = 0
			Constants.DefenseToken.BRACE:
				damage = ceili(float(damage) / 2.0)
	var redirected: int = 0
	for allocation: Dictionary in redirect_allocations:
		redirected += int(allocation.get("amount", 0))
	return maxi(0, damage - redirected)


static func inactive() -> CurrentAttackState:
	return CurrentAttackState.new()


static func _validated_data(raw: Dictionary) -> Dictionary:
	if raw.size() != _KEYS.size():
		return {}
	for key: Variant in raw.keys():
		if typeof(key) != TYPE_STRING or not _KEYS.has(str(key)):
			return {}
	if typeof(raw.get("active")) != TYPE_BOOL:
		return {}
	var normalized: Dictionary = _inactive_data()
	for key: String in _KEYS:
		normalized[key] = raw[key]
	for key: String in ["attacker_player", "attacker_index", "attacker_zone",
			"defender_player", "defender_index", "defender_zone"]:
		var integral: Variant = _normalized_integral(normalized[key])
		if integral == null:
			return {}
		normalized[key] = integral
	if not bool(normalized["active"]):
		return _inactive_data() if normalized == _inactive_data() else {}
	if not _validate_active_scalars(normalized):
		return {}
	var pool: Variant = _validated_pool(normalized["dice_pool"])
	var pool_choices: Variant = _validated_unique_strings(
			normalized["resolved_pool_choices"])
	var dice: Variant = _validated_dice(normalized["dice_results"])
	var locks: Variant = _validated_unique_ints(normalized["accuracy_locked_tokens"])
	var committed: Variant = _validated_unique_ints(
			normalized["committed_defense_tokens"])
	var effects: Variant = _validated_effects(normalized["resolved_defense_effects"])
	var evade: Variant = _validated_evade(normalized["pending_evade"])
	var redirects: Variant = _validated_redirects(normalized["redirect_allocations"])
	var outcome: Variant = _validated_resolved_outcome(
			normalized["resolved_outcome"])
	if pool == null or pool_choices == null or dice == null \
			or locks == null or committed == null \
			or effects == null or evade == null or redirects == null \
			or outcome == null:
		return {}
	normalized["dice_pool"] = pool
	normalized["resolved_pool_choices"] = pool_choices
	normalized["dice_results"] = dice
	normalized["accuracy_locked_tokens"] = locks
	normalized["committed_defense_tokens"] = committed
	normalized["resolved_defense_effects"] = effects
	normalized["pending_evade"] = evade
	normalized["redirect_allocations"] = redirects
	normalized["resolved_outcome"] = outcome
	if not _validate_stage_semantics(normalized):
		return {}
	return normalized.duplicate(true)


static func _validate_active_scalars(data: Dictionary) -> bool:
	for key: String in ["attack_id", "stage", "attacker_kind", "defender_kind",
			"attack_kind", "range_band", "cf_dial_resolution",
			"cf_token_resolution", "defense_stage", "damage_stage"]:
		if typeof(data[key]) != TYPE_STRING:
			return false
	for key: String in ["attacker_player", "attacker_index", "attacker_zone",
			"defender_player", "defender_index", "defender_zone"]:
		if typeof(data[key]) != TYPE_INT:
			return false
	for key: String in ["obstructed", "obstruction_resolved", "accuracy_complete"]:
		if typeof(data[key]) != TYPE_BOOL:
			return false
	if not _is_attack_id(str(data["attack_id"])) \
			or not _STAGES.has(str(data["stage"])) \
			or str(data["stage"]) == STAGE_INACTIVE:
		return false
	if not _KINDS.has(str(data["attacker_kind"])) \
			or not _KINDS.has(str(data["defender_kind"])):
		return false
	if not _valid_player(int(data["attacker_player"])) \
			or not _valid_player(int(data["defender_player"])) \
			or int(data["attacker_index"]) < 0 \
			or int(data["defender_index"]) < 0:
		return false
	if not _valid_zone_for_kind(str(data["attacker_kind"]), int(data["attacker_zone"])) \
			or not _valid_zone_for_kind(str(data["defender_kind"]), int(data["defender_zone"])):
		return false
	return not str(data["attack_kind"]).is_empty() \
			and not str(data["range_band"]).is_empty() \
			and _RESOLUTIONS.has(str(data["cf_dial_resolution"])) \
			and _RESOLUTIONS.has(str(data["cf_token_resolution"])) \
			and _DEFENSE_STAGES.has(str(data["defense_stage"])) \
			and _DAMAGE_STAGES.has(str(data["damage_stage"]))


static func _validate_stage_semantics(data: Dictionary) -> bool:
	var stage_value: String = str(data["stage"])
	var dice: Array = data["dice_results"] as Array
	# ResolveDamageCommand owns the only accepted transition from completed
	# defense directly to STAGE_RESOLVED. There is no command-owned writer for
	# an intermediate damage stage, so serialized/runtime reconstruction must
	# reject that otherwise unresumable semantic state.
	if stage_value == STAGE_DAMAGE:
		return false
	if stage_value == STAGE_PRE_ROLL and not dice.is_empty():
		return false
	if stage_value in [STAGE_ATTACK_MODIFY, STAGE_ACCURACY] and dice.is_empty():
		return false
	if stage_value != STAGE_PRE_ROLL \
			and str(data["cf_dial_resolution"]) == RESOLUTION_PENDING:
		return false
	if stage_value not in [STAGE_PRE_ROLL, STAGE_ATTACK_MODIFY] \
			and str(data["cf_token_resolution"]) == RESOLUTION_PENDING:
		return false
	if stage_value in [STAGE_DEFENSE, STAGE_DAMAGE, STAGE_RESOLVED] \
			and not bool(data["accuracy_complete"]):
		return false
	if not (data["pending_evade"] as Dictionary).is_empty() \
			and stage_value != STAGE_DEFENSE:
		return false
	if stage_value == STAGE_RESOLVED \
			and str(data["damage_stage"]) != DAMAGE_RESOLVED:
		return false
	if str(data["damage_stage"]) == DAMAGE_RESOLVED \
			and stage_value != STAGE_RESOLVED:
		return false
	if stage_value == STAGE_RESOLVED \
			and (data["resolved_outcome"] as Dictionary).is_empty():
		return false
	if stage_value != STAGE_RESOLVED \
			and not (data["resolved_outcome"] as Dictionary).is_empty():
		return false
	return true


static func _validated_pool(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var result: Dictionary = {}
	var total: int = 0
	for key: String in _POOL_KEYS:
		if not (raw as Dictionary).has(key):
			continue
		var value: Variant = (raw as Dictionary)[key]
		var integral: Variant = _normalized_integral(value)
		if integral == null or int(integral) < 0:
			return null
		if int(integral) > 0:
			result[key] = int(integral)
			total += int(integral)
	for raw_key: Variant in (raw as Dictionary).keys():
		if typeof(raw_key) != TYPE_STRING or not _POOL_KEYS.has(str(raw_key)):
			return null
	return result if total > 0 else null


static func _validated_dice(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var result: Array[Dictionary] = []
	for entry: Variant in raw as Array:
		if not entry is Dictionary or (entry as Dictionary).size() != 2:
			return null
		var color: Variant = (entry as Dictionary).get("color")
		var face: Variant = (entry as Dictionary).get("face")
		var normalized_color: Variant = _normalized_integral(color)
		var normalized_face: Variant = _normalized_integral(face)
		if normalized_color == null or normalized_face == null \
				or int(normalized_color) < int(Constants.DiceColor.RED) \
				or int(normalized_color) > int(Constants.DiceColor.BLACK) \
				or int(normalized_face) < int(Constants.DiceFace.BLANK) \
				or int(normalized_face) > int(Constants.DiceFace.HIT_HIT):
			return null
		result.append({
			"color": int(normalized_color),
			"face": int(normalized_face),
		})
	return result


static func _validated_unique_ints(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var result: Array[int] = []
	for value: Variant in raw as Array:
		var integral: Variant = _normalized_integral(value)
		if integral == null or int(integral) < 0 \
				or result.has(int(integral)):
			return null
		result.append(int(integral))
	return result


static func _validated_unique_strings(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var result: Array[String] = []
	for value: Variant in raw as Array:
		if typeof(value) != TYPE_STRING or str(value).is_empty() \
				or result.has(str(value)):
			return null
		result.append(str(value))
	return result


static func _validated_effects(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var result: Array[Dictionary] = []
	var seen_indices: Dictionary = {}
	for entry: Variant in raw as Array:
		if not entry is Dictionary or (entry as Dictionary).size() != 2:
			return null
		var token_index: Variant = (entry as Dictionary).get("token_index")
		var token_type: Variant = (entry as Dictionary).get("token_type")
		var normalized_index: Variant = _normalized_integral(token_index)
		var normalized_type: Variant = _normalized_integral(token_type)
		if normalized_index == null or int(normalized_index) < 0 \
				or seen_indices.has(int(normalized_index)) \
				or normalized_type == null \
				or int(normalized_type) < int(Constants.DefenseToken.EVADE) \
				or int(normalized_type) > int(Constants.DefenseToken.SALVO):
			return null
		seen_indices[int(normalized_index)] = true
		result.append({
			"token_index": int(normalized_index),
			"token_type": int(normalized_type),
		})
	return result


static func _validated_evade(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var evade: Dictionary = raw as Dictionary
	if evade.is_empty():
		return {}
	if evade.size() != 3:
		return null
	var index: Variant = evade.get("die_index")
	var color: Variant = evade.get("expected_color")
	var face: Variant = evade.get("expected_face")
	var normalized_index: Variant = _normalized_integral(index)
	var normalized_color: Variant = _normalized_integral(color)
	var normalized_face: Variant = _normalized_integral(face)
	if normalized_index == null or int(normalized_index) < 0 \
			or normalized_color == null or normalized_face == null:
		return null
	return {
		"die_index": int(normalized_index),
		"expected_color": int(normalized_color),
		"expected_face": int(normalized_face),
	}


static func _validated_redirects(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var result: Array[Dictionary] = []
	for entry: Variant in raw as Array:
		if not entry is Dictionary or (entry as Dictionary).size() != 2:
			return null
		var zone: Variant = (entry as Dictionary).get("zone")
		var amount: Variant = (entry as Dictionary).get("amount")
		var normalized_zone: Variant = _normalized_integral(zone)
		var normalized_amount: Variant = _normalized_integral(amount)
		if normalized_zone == null \
				or int(normalized_zone) < int(Constants.HullZone.FRONT) \
				or int(normalized_zone) > int(Constants.HullZone.REAR) \
				or normalized_amount == null or int(normalized_amount) <= 0:
			return null
		result.append({
			"zone": int(normalized_zone),
			"amount": int(normalized_amount),
		})
	return result


static func _validated_resolved_outcome(raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return null
	return (raw as Dictionary).duplicate(true)


static func _normalized_integral(raw: Variant) -> Variant:
	if typeof(raw) == TYPE_INT:
		return int(raw)
	if typeof(raw) == TYPE_FLOAT \
			and is_finite(float(raw)) \
			and float(raw) == floor(float(raw)):
		return int(raw)
	return null


static func _is_attack_id(value: String) -> bool:
	if not value.begins_with("attack:"):
		return false
	var sequence_text: String = value.trim_prefix("attack:")
	return sequence_text.is_valid_int() and sequence_text.to_int() >= 0 \
			and str(sequence_text.to_int()) == sequence_text


static func _valid_player(value: int) -> bool:
	return value >= 0 and value < Constants.PLAYER_COUNT


static func _valid_zone_for_kind(kind: String, zone: int) -> bool:
	if kind == KIND_SQUADRON:
		return zone == -1
	return zone >= int(Constants.HullZone.FRONT) \
			and zone <= int(Constants.HullZone.REAR)


static func _entity_for(game_state: GameState, kind: String,
		owner: int, index: int) -> RefCounted:
	if game_state == null:
		return null
	if kind == KIND_SHIP:
		return game_state.get_ship(owner, index)
	return game_state.get_squadron(owner, index)


static func _inactive_data() -> Dictionary:
	return {
		"active": false,
		"attack_id": "",
		"stage": STAGE_INACTIVE,
		"attacker_player": -1,
		"attacker_kind": "",
		"attacker_index": -1,
		"attacker_zone": -1,
		"defender_player": -1,
		"defender_kind": "",
		"defender_index": -1,
		"defender_zone": -1,
		"attack_kind": "",
		"range_band": "",
		"obstructed": false,
		"obstruction_resolved": false,
		"resolved_pool_choices": [],
		"dice_pool": {},
		"dice_results": [],
		"cf_dial_resolution": RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": RESOLUTION_UNAVAILABLE,
		"accuracy_locked_tokens": [],
		"accuracy_complete": false,
		"defense_stage": DEFENSE_PENDING,
		"committed_defense_tokens": [],
		"resolved_defense_effects": [],
		"pending_evade": {},
		"redirect_allocations": [],
		"damage_stage": DAMAGE_PENDING,
		"resolved_outcome": {},
	}


static func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		result.append(int(value))
	return result


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result


static func _dictionary_array(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in values:
		result.append((value as Dictionary).duplicate(true))
	return result

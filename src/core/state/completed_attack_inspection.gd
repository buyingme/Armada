## Immutable canonical evidence for one completed attack awaiting release.
class_name CompletedAttackInspection
extends RefCounted


const _KEYS: Array[String] = [
	"inspection_id", "source_attack_id", "attacker", "defender",
	"attack_kind", "dice_results", "outcome", "required_principal_ids",
	"received_principal_ids",
]
const _REFERENCE_KEYS: Array[String] = ["kind", "player", "index", "zone"]

var _data: Dictionary = {}


static func create_from_attack(attack: CurrentAttackState, outcome: Dictionary,
		required_ids: Array[String]) -> CompletedAttackInspection:
	if attack == null or not attack.active or outcome.is_empty():
		return null
	return deserialize({
		"inspection_id": "completed:%s" % attack.attack_id,
		"source_attack_id": attack.attack_id,
		"attacker": _reference(attack.attacker_kind, attack.attacker_player,
				attack.attacker_index, attack.attacker_zone),
		"defender": _reference(attack.defender_kind, attack.defender_player,
				attack.defender_index, attack.defender_zone),
		"attack_kind": attack.attack_kind,
		"dice_results": attack.dice_results,
		"outcome": outcome.duplicate(true),
		"required_principal_ids": required_ids.duplicate(),
		"received_principal_ids": [],
	})


static func deserialize(raw: Dictionary) -> CompletedAttackInspection:
	if not _has_exact_keys(raw, _KEYS):
		return null
	var inspection_id: Variant = raw.get("inspection_id")
	var source_attack_id: Variant = raw.get("source_attack_id")
	var attack_kind: Variant = raw.get("attack_kind")
	var attacker: Variant = _validated_reference(raw.get("attacker"))
	var defender: Variant = _validated_reference(raw.get("defender"))
	var dice: Variant = _validated_dice(raw.get("dice_results"))
	var outcome: Variant = _validated_outcome(raw.get("outcome"), defender)
	var required: Variant = _validated_sorted_unique_strings(
			raw.get("required_principal_ids"), true)
	var received: Variant = _validated_sorted_unique_strings(
			raw.get("received_principal_ids"), false)
	if not (inspection_id is String) or not (source_attack_id is String) \
			or not (attack_kind is String) or str(attack_kind).is_empty() \
			or attacker == null or defender == null or dice == null \
			or outcome == null or required == null or received == null:
		return null
	if str(inspection_id) != "completed:%s" % str(source_attack_id) \
			or str(source_attack_id).is_empty():
		return null
	for principal_id: String in received as Array[String]:
		if not (required as Array[String]).has(principal_id):
			return null
	var result := CompletedAttackInspection.new()
	result._data = {
		"inspection_id": str(inspection_id),
		"source_attack_id": str(source_attack_id),
		"attacker": (attacker as Dictionary).duplicate(true),
		"defender": (defender as Dictionary).duplicate(true),
		"attack_kind": str(attack_kind),
		"dice_results": (dice as Array).duplicate(true),
		"outcome": (outcome as Dictionary).duplicate(true),
		"required_principal_ids": (required as Array).duplicate(),
		"received_principal_ids": (received as Array).duplicate(),
	}
	return result


func serialize() -> Dictionary:
	return _data.duplicate(true)


func is_valid() -> bool:
	return deserialize(serialize()) != null


func inspection_id() -> String:
	return str(_data.get("inspection_id", ""))


func source_attack_id() -> String:
	return str(_data.get("source_attack_id", ""))


func is_satisfied() -> bool:
	return _data.get("required_principal_ids", []) \
			== _data.get("received_principal_ids", [])


func has_received(principal_id: String) -> bool:
	return (_data.get("received_principal_ids", []) as Array).has(principal_id)


func required_principal_ids() -> Array[String]:
	return _string_array(_data.get("required_principal_ids", []))


func received_principal_ids() -> Array[String]:
	return _string_array(_data.get("received_principal_ids", []))


func acknowledged_by(principal_id: String) -> CompletedAttackInspection:
	if principal_id.is_empty() or has_received(principal_id) \
			or not (required_principal_ids().has(principal_id)):
		return null
	var replacement: Dictionary = serialize()
	var received: Array = replacement["received_principal_ids"] as Array
	received.append(principal_id)
	received.sort()
	replacement["received_principal_ids"] = received
	return deserialize(replacement)


static func _reference(kind: String, player: int, index: int, zone: int) -> Dictionary:
	return {"kind": kind, "player": player, "index": index, "zone": zone}


static func _validated_reference(raw: Variant) -> Variant:
	if not (raw is Dictionary) \
			or not _has_exact_keys(raw as Dictionary, _REFERENCE_KEYS):
		return null
	var value: Dictionary = raw as Dictionary
	if not (value.get("kind") is String) \
			or str(value.get("kind")) not in ["ship", "squadron"] \
			or _integer_value(value.get("player")) == null \
			or _integer_value(value.get("index")) == null \
			or _integer_value(value.get("zone")) == null:
		return null
	var player: int = int(_integer_value(value.get("player")))
	var index: int = int(_integer_value(value.get("index")))
	var zone: int = int(_integer_value(value.get("zone")))
	if player < 0 or player >= Constants.PLAYER_COUNT or index < 0:
		return null
	if str(value["kind"]) == "squadron" and zone != -1:
		return null
	if str(value["kind"]) == "ship" \
			and (zone < int(Constants.HullZone.FRONT) \
			or zone > int(Constants.HullZone.REAR)):
		return null
	return {"kind": str(value["kind"]), "player": player, "index": index,
		"zone": zone}


static func _validated_dice(raw: Variant) -> Variant:
	if not (raw is Array):
		return null
	var result: Array[Dictionary] = []
	for entry: Variant in raw as Array:
		if not (entry is Dictionary) or (entry as Dictionary).size() != 2 \
			or _integer_value((entry as Dictionary).get("color")) == null \
			or _integer_value((entry as Dictionary).get("face")) == null:
			return null
		result.append({"color": _integer_value((entry as Dictionary).get("color")),
			"face": _integer_value((entry as Dictionary).get("face"))})
	return result


static func _validated_outcome(raw: Variant, defender: Variant) -> Variant:
	if not (raw is Dictionary) or defender == null:
		return null
	var kind: String = str((defender as Dictionary).get("kind", ""))
	var keys: Array[String] = ["target_kind", "destroyed"]
	if kind == "ship":
		keys.append_array(["affected_zone", "final_damage", "shield_absorbed",
				"post_resolution_shields", "hull_damage"])
	else:
		keys.append_array(["requested_hull_damage", "actual_hull_damage",
				"post_resolution_hull"])
	var outcome: Dictionary = raw as Dictionary
	if not _has_exact_keys(outcome, keys) \
			or str(outcome.get("target_kind", "")) != kind \
			or typeof(outcome.get("destroyed")) != TYPE_BOOL:
		return null
	var normalized: Dictionary = {"target_kind": kind,
		"destroyed": bool(outcome.get("destroyed", false))}
	for key: String in keys:
		if key in ["target_kind", "destroyed"]:
			continue
		var value: Variant = _integer_value(outcome.get(key))
		if value == null or int(value) < 0:
			return null
		normalized[key] = int(value)
	return normalized


static func _validated_sorted_unique_strings(raw: Variant,
		require_non_empty: bool) -> Variant:
	if not (raw is Array):
		return null
	var result: Array[String] = []
	for value: Variant in raw as Array:
		if not (value is String) or str(value).is_empty() or result.has(value):
			return null
		result.append(value as String)
	var sorted: Array[String] = result.duplicate()
	sorted.sort()
	if result != sorted or (require_non_empty and result.is_empty()):
		return null
	return result


static func _string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for value: Variant in raw as Array:
			result.append(str(value))
	return result


static func _integer_value(raw: Variant) -> Variant:
	if typeof(raw) == TYPE_INT:
		return raw
	if typeof(raw) == TYPE_FLOAT \
			and is_equal_approx(float(raw), round(float(raw))):
		return int(raw)
	return null


static func _has_exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true

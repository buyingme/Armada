## Immutable public evidence for one newly dealt faceup damage card.
class_name FaceupDamageInspection
extends RefCounted


const KEYS: Array[String] = [
	"inspection_id", "owner_player", "ship_index", "roster_entry_id",
	"public_card", "required_principal_ids", "received_principal_ids",
]

var _data: Dictionary = {}


static func public_card_from_addition(addition: Dictionary) -> Dictionary:
	var card: Dictionary = {}
	for key: String in ["public_card_ref", "trait_type", "title", "is_faceup",
			"effect_text", "timing", "effect_id"]:
		if not addition.has(key):
			return {}
		card[key] = addition[key]
	return card if DamageCard.deserialize_public_faceup(card) != null else {}


static func create(owner_player: int, ship_index: int, roster_entry_id: String,
		public_card: Dictionary, required_ids: Array[String]) -> FaceupDamageInspection:
	return deserialize({
		"inspection_id": "faceup-inspection:%s" % str(public_card.get(
				"public_card_ref", "")),
		"owner_player": owner_player,
		"ship_index": ship_index,
		"roster_entry_id": roster_entry_id,
		"public_card": public_card.duplicate(true),
		"required_principal_ids": required_ids.duplicate(),
		"received_principal_ids": [],
	})


static func deserialize(raw: Dictionary) -> FaceupDamageInspection:
	if not _exact(raw, KEYS) or typeof(raw.get("inspection_id")) != TYPE_STRING \
			or not _is_exact_json_integer(raw.get("owner_player")) \
			or int(raw["owner_player"]) not in [0, 1] \
			or not _is_exact_json_integer(raw.get("ship_index")) \
			or int(raw["ship_index"]) < 0 \
			or typeof(raw.get("roster_entry_id")) != TYPE_STRING \
			or str(raw["roster_entry_id"]).is_empty() \
			or not raw.get("public_card") is Dictionary:
		return null
	var card: DamageCard = DamageCard.deserialize_public_faceup(
			raw["public_card"] as Dictionary)
	if card == null or str(raw["inspection_id"]) \
			!= "faceup-inspection:%s" % card.public_card_ref:
		return null
	var required: Array[String] = _sorted_unique(raw.get("required_principal_ids"))
	var received: Array[String] = _sorted_unique(raw.get("received_principal_ids"))
	if required.is_empty() or required.size() > 2 \
			or not raw["required_principal_ids"] is Array \
			or not raw["received_principal_ids"] is Array \
			or required.size() != (raw["required_principal_ids"] as Array).size() \
			or received.size() != (raw["received_principal_ids"] as Array).size():
		return null
	for principal_id: String in received:
		if not required.has(principal_id):
			return null
	var result := FaceupDamageInspection.new()
	result._data = raw.duplicate(true)
	result._data["owner_player"] = int(raw["owner_player"])
	result._data["ship_index"] = int(raw["ship_index"])
	return result


static func _is_exact_json_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] \
			and is_finite(float(value)) \
			and float(value) == float(int(value))


func serialize() -> Dictionary:
	return _data.duplicate(true)


func inspection_id() -> String:
	return str(_data.get("inspection_id", ""))


func required_principal_ids() -> Array[String]:
	return _sorted_unique(_data.get("required_principal_ids"))


func received_principal_ids() -> Array[String]:
	return _sorted_unique(_data.get("received_principal_ids"))


func has_received(principal_id: String) -> bool:
	return received_principal_ids().has(principal_id)


func acknowledged_by(principal_id: String) -> FaceupDamageInspection:
	if not required_principal_ids().has(principal_id) or has_received(principal_id):
		return null
	var replacement: Dictionary = serialize()
	var received: Array = replacement["received_principal_ids"] as Array
	received.append(principal_id)
	received.sort()
	return deserialize(replacement)


func is_satisfied() -> bool:
	return required_principal_ids() == received_principal_ids()


static func _sorted_unique(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not raw is Array:
		return result
	for value: Variant in raw as Array:
		if typeof(value) != TYPE_STRING or str(value).is_empty() \
				or result.has(str(value)):
			return []
		result.append(str(value))
	var sorted: Array[String] = result.duplicate()
	sorted.sort()
	return result if sorted == result else []


static func _exact(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true

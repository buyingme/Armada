## Immutable, match-scoped mapping from gameplay players to principals.
class_name MatchPlayerControlBinding
extends RefCounted


const KIND_HUMAN: String = "HUMAN"
const KIND_AUTOMATED: String = "AUTOMATED"

const _TOP_LEVEL_KEYS: Array[String] = ["principals", "player_principal_ids"]
const _RECORD_KEYS: Array[String] = ["principal_id", "kind"]

var _principal_records: Array[Dictionary] = []
var _player_principal_ids: Array[String] = []


static func create_new(principal_kinds: Array[String],
		player_principal_indexes: Array[int]) -> MatchPlayerControlBinding:
	if player_principal_indexes.size() != Constants.PLAYER_COUNT \
			or principal_kinds.is_empty():
		return null
	for kind: String in principal_kinds:
		if not _is_supported_kind(kind):
			return null
	for principal_index: int in player_principal_indexes:
		if principal_index < 0 or principal_index >= principal_kinds.size():
			return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var records: Array[Dictionary] = []
	var ids: Array[String] = []
	for kind: String in principal_kinds:
		var principal_id: String = _new_principal_id(rng)
		while ids.has(principal_id):
			principal_id = _new_principal_id(rng)
		ids.append(principal_id)
		records.append({"principal_id": principal_id, "kind": kind})
	var mapping: Array[String] = []
	for principal_index: int in player_principal_indexes:
		mapping.append(ids[principal_index])
	return deserialize({
		"principals": records,
		"player_principal_ids": mapping,
	})


static func create_hot_seat_human() -> MatchPlayerControlBinding:
	return create_new([KIND_HUMAN], [0, 0])


static func create_two_human() -> MatchPlayerControlBinding:
	return create_new([KIND_HUMAN, KIND_HUMAN], [0, 1])


static func deserialize(data: Dictionary) -> MatchPlayerControlBinding:
	if not _has_exact_keys(data, _TOP_LEVEL_KEYS):
		return null
	var raw_records: Variant = data.get("principals")
	var raw_mapping: Variant = data.get("player_principal_ids")
	if not (raw_records is Array) or not (raw_mapping is Array):
		return null
	if (raw_mapping as Array).size() != Constants.PLAYER_COUNT:
		return null
	var records: Array[Dictionary] = []
	var known_ids: Dictionary = {}
	for raw_record: Variant in raw_records as Array:
		if not (raw_record is Dictionary):
			return null
		var record: Dictionary = raw_record as Dictionary
		if not _has_exact_keys(record, _RECORD_KEYS):
			return null
		var principal_id: Variant = record.get("principal_id")
		var kind: Variant = record.get("kind")
		if not (principal_id is String) or not (kind is String) \
				or not _is_canonical_principal_id(principal_id as String) \
				or not _is_supported_kind(kind as String) \
				or known_ids.has(principal_id):
			return null
		known_ids[principal_id] = true
		records.append({"principal_id": principal_id, "kind": kind})
	if records.is_empty():
		return null
	var mapping: Array[String] = []
	var referenced: Dictionary = {}
	for raw_id: Variant in raw_mapping as Array:
		if not (raw_id is String):
			return null
		var mapped_id: String = raw_id as String
		if not _is_canonical_principal_id(mapped_id) or not known_ids.has(mapped_id):
			return null
		mapping.append(mapped_id)
		referenced[mapped_id] = true
	if referenced.size() != known_ids.size():
		return null
	return _from_canonical(records, mapping)


func serialize() -> Dictionary:
	var principals: Array[Dictionary] = []
	for record: Dictionary in _principal_records:
		principals.append(record.duplicate(true))
	return {
		"principals": principals,
		"player_principal_ids": _player_principal_ids.duplicate(),
	}


func is_valid() -> bool:
	return deserialize(serialize()) != null


func principal_id_for_player(player_index: int) -> String:
	if player_index < 0 or player_index >= _player_principal_ids.size():
		return ""
	return _player_principal_ids[player_index]


func principal_kind(principal_id: String) -> String:
	for record: Dictionary in _principal_records:
		if record.get("principal_id", "") == principal_id:
			return str(record.get("kind", ""))
	return ""


func controls_player(principal_id: String, player_index: int) -> bool:
	return not principal_id.is_empty() \
			and principal_id == principal_id_for_player(player_index)


func distinct_principal_ids(kind: String = "") -> Array[String]:
	var ids: Array[String] = []
	for record: Dictionary in _principal_records:
		if kind.is_empty() or record.get("kind", "") == kind:
			ids.append(str(record.get("principal_id", "")))
	ids.sort()
	return ids


func equals(other: MatchPlayerControlBinding) -> bool:
	return other != null and serialize() == other.serialize()


static func _from_canonical(records: Array[Dictionary], mapping: Array[String]) \
		-> MatchPlayerControlBinding:
	var candidate := MatchPlayerControlBinding.new()
	candidate._principal_records = records.duplicate(true)
	candidate._principal_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["principal_id"]) < str(b["principal_id"]))
	candidate._player_principal_ids = mapping.duplicate()
	return candidate


static func _new_principal_id(rng: RandomNumberGenerator) -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for index: int in range(16):
		bytes[index] = rng.randi() & 0xFF
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "mp-%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6],
		bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12],
		bytes[13], bytes[14], bytes[15]]


static func _is_supported_kind(kind: String) -> bool:
	return kind == KIND_HUMAN or kind == KIND_AUTOMATED


static func _is_canonical_principal_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^mp-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	return regex.search(value) != null


static func _has_exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true

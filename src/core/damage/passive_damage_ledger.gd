## Damage-specific canonical state for a passive Network peer.
##
## It deliberately stores only aggregate hidden counts and identities that are
## already public.  It is never used by a local authority or replay.
class_name PassiveDamageLedger
extends RefCounted


const SCHEMA_VERSION: int = 1
const _FIELDS: Array[String] = [
	"schema_version", "draw_count", "discard_pile", "facedown_counts",
]
const _CARD_FIELDS: Array[String] = [
	"trait_type", "title", "is_faceup", "effect_text", "timing", "effect_id",
]

var draw_count: int = 0
var discard_pile: Array[DamageCard] = []
var facedown_counts: Dictionary = {}


static func ship_key(owner_player: int, roster_entry_id: String) -> String:
	return "%d:%s" % [owner_player, roster_entry_id]


static func deserialize(data: Dictionary,
		expected_ship_keys: Array[String] = []) -> PassiveDamageLedger:
	if not _has_exact_fields(data, _FIELDS):
		return null
	if typeof(data.get("schema_version")) != TYPE_INT \
			or int(data.get("schema_version")) != SCHEMA_VERSION:
		return null
	if typeof(data.get("draw_count")) != TYPE_INT \
			or int(data.get("draw_count")) < 0:
		return null
	var raw_discard: Variant = data.get("discard_pile")
	var raw_counts: Variant = data.get("facedown_counts")
	if not raw_discard is Array or not raw_counts is Dictionary:
		return null
	var ledger := PassiveDamageLedger.new()
	ledger.draw_count = int(data["draw_count"])
	for raw_card: Variant in raw_discard as Array:
		if not raw_card is Dictionary \
				or not _has_exact_fields(raw_card as Dictionary, _CARD_FIELDS) \
				or not _has_canonical_card_types(raw_card as Dictionary):
			return null
		ledger.discard_pile.append(DamageCard.deserialize(raw_card as Dictionary))
	for raw_key: Variant in (raw_counts as Dictionary):
		if typeof(raw_key) != TYPE_STRING:
			return null
		var raw_value: Variant = (raw_counts as Dictionary).get(raw_key)
		if typeof(raw_value) != TYPE_INT or int(raw_value) < 0:
			return null
		ledger.facedown_counts[str(raw_key)] = int(raw_value)
	if not expected_ship_keys.is_empty():
		var sorted_expected: Array[String] = expected_ship_keys.duplicate()
		sorted_expected.sort()
		var actual: Array[String] = []
		for key: Variant in ledger.facedown_counts.keys():
			actual.append(str(key))
		actual.sort()
		if actual != sorted_expected:
			return null
	return ledger


func serialize() -> Dictionary:
	var public_discard: Array[Dictionary] = []
	for card: DamageCard in discard_pile:
		public_discard.append(card.serialize())
	return {
		"schema_version": SCHEMA_VERSION,
		"draw_count": draw_count,
		"discard_pile": public_discard,
		"facedown_counts": facedown_counts.duplicate(true),
	}


func duplicate_ledger() -> PassiveDamageLedger:
	return deserialize(serialize())


func get_facedown_count(key: String) -> int:
	return int(facedown_counts.get(key, -1))


func can_consume_hidden_draws(count: int) -> bool:
	return count >= 0 and draw_count + discard_pile.size() >= count


func consume_hidden_draws(count: int) -> bool:
	if not can_consume_hidden_draws(count):
		return false
	var remaining: int = count
	while remaining > 0:
		if draw_count == 0:
			draw_count = discard_pile.size()
			discard_pile.clear()
		draw_count -= 1
		remaining -= 1
	return true


func increment_facedown(key: String, count: int = 1) -> bool:
	if not facedown_counts.has(key) or count < 0:
		return false
	facedown_counts[key] = int(facedown_counts[key]) + count
	return true


func decrement_facedown(key: String, count: int = 1) -> bool:
	if not facedown_counts.has(key) or count < 0 \
			or int(facedown_counts[key]) < count:
		return false
	facedown_counts[key] = int(facedown_counts[key]) - count
	return true


func append_public_discard(card: DamageCard) -> bool:
	if card == null:
		return false
	discard_pile.append(card)
	return true


func clear_facedown(key: String) -> int:
	if not facedown_counts.has(key):
		return -1
	var count: int = int(facedown_counts[key])
	facedown_counts[key] = 0
	return count


func public_discard_contains(card: DamageCard) -> bool:
	if card == null:
		return false
	var serialized: Dictionary = card.serialize()
	for candidate: DamageCard in discard_pile:
		if candidate.serialize() == serialized:
			return true
	return false


static func deserialize_public_card(data: Dictionary,
		require_faceup: bool = false) -> DamageCard:
	if not _has_exact_fields(data, _CARD_FIELDS) \
			or not _has_canonical_card_types(data):
		return null
	var card: DamageCard = DamageCard.deserialize(data)
	if require_faceup and not card.is_faceup:
		return null
	return card


static func _has_exact_fields(data: Dictionary, fields: Array[String]) -> bool:
	if data.size() != fields.size():
		return false
	for field: String in fields:
		if not data.has(field):
			return false
	return true


static func _has_canonical_card_types(data: Dictionary) -> bool:
	return typeof(data.get("trait_type")) == TYPE_STRING \
			and typeof(data.get("title")) == TYPE_STRING \
			and typeof(data.get("is_faceup")) == TYPE_BOOL \
			and typeof(data.get("effect_text")) == TYPE_STRING \
			and typeof(data.get("timing")) == TYPE_STRING \
			and typeof(data.get("effect_id")) == TYPE_STRING

## Exact protocol-7 public damage result validation/application helpers.
## This utility never draws, shuffles, or creates authority physical identity.
class_name CandidateDamageApplication
extends RefCounted


const DAMAGE_KEYS: Array[String] = [
	"owner_player", "ship_index", "shield_changes", "facedown_delta",
	"faceup_additions", "faceup_removals", "public_discards",
	"new_hull", "destroyed",
]
const PUBLIC_CARD_KEYS: Array[String] = [
	"public_card_ref", "trait_type", "title", "is_faceup",
	"effect_text", "timing", "effect_id",
]


static func is_exact_damage_application(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value as Dictionary
	if not _has_exact_keys(data, DAMAGE_KEYS) \
			or typeof(data["owner_player"]) != TYPE_INT \
			or int(data["owner_player"]) not in [0, 1] \
			or typeof(data["ship_index"]) != TYPE_INT \
			or int(data["ship_index"]) < 0 \
			or typeof(data["facedown_delta"]) != TYPE_INT \
			or int(data["facedown_delta"]) < -1 \
			or typeof(data["new_hull"]) != TYPE_INT \
			or typeof(data["destroyed"]) != TYPE_BOOL:
		return false
	for key: String in [
		"shield_changes", "faceup_additions", "faceup_removals",
		"public_discards"]:
		if not data[key] is Array:
			return false
	var zones: Dictionary = {}
	for raw_change: Variant in data["shield_changes"]:
		if not raw_change is Dictionary:
			return false
		var change: Dictionary = raw_change as Dictionary
		if not _has_exact_keys(change, ["zone", "new_shields"]) \
				or typeof(change["zone"]) != TYPE_STRING \
				or str(change["zone"]).is_empty() \
				or zones.has(str(change["zone"])) \
				or typeof(change["new_shields"]) != TYPE_INT \
				or int(change["new_shields"]) < 0:
			return false
		zones[str(change["zone"])] = true
	var refs: Dictionary = {}
	for raw_addition: Variant in data["faceup_additions"]:
		if not is_public_faceup_addition(raw_addition):
			return false
		var reference: String = str((raw_addition as Dictionary)[
				"public_card_ref"])
		if refs.has(reference):
			return false
		refs[reference] = true
	for raw_ref: Variant in data["faceup_removals"]:
		if typeof(raw_ref) != TYPE_STRING or str(raw_ref).is_empty() \
				or refs.has(str(raw_ref)):
			return false
		refs[str(raw_ref)] = true
	for raw_discard: Variant in data["public_discards"]:
		if not raw_discard is Dictionary \
				or not _is_public_damage_card(raw_discard as Dictionary):
			return false
	return true


static func is_public_faceup_addition(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value as Dictionary
	var keys: Array[String] = PUBLIC_CARD_KEYS.duplicate()
	keys.append("immediate_obligation")
	var obligation: String = str(data.get("immediate_obligation", ""))
	if obligation == "open":
		keys.append_array(["immediate_resolution_id", "actor_player"])
	if not _has_exact_keys(data, keys) \
			or not _public_faceup_fields_are_valid(data):
		return false
	if obligation == "none":
		return str(data["timing"]) == "persistent"
	if obligation != "open" \
			or str(data["timing"]) not in [
				"immediate", "immediate_persistent"] \
			or typeof(data["immediate_resolution_id"]) != TYPE_STRING \
			or str(data["immediate_resolution_id"]) \
					!= "immediate:%s" % str(data["public_card_ref"]) \
			or typeof(data["actor_player"]) != TYPE_INT \
			or int(data["actor_player"]) not in [-1, 0, 1]:
		return false
	return true


static func install_public_addition(ship: ShipInstance, addition: Dictionary,
		enclosure: Dictionary) -> bool:
	if ship == null or not ship.is_passive_damage_bound() \
			or not is_public_faceup_addition(addition) \
			or ship.faceup_card_for_public_ref(
					str(addition["public_card_ref"])) != null:
		return false
	var card_data: Dictionary = {}
	for key: String in PUBLIC_CARD_KEYS:
		card_data[key] = addition[key]
	var card: DamageCard = DamageCard.deserialize_public_faceup(card_data)
	if card == null:
		return false
	ship.add_faceup_damage(card)
	if str(addition["immediate_obligation"]) == "none":
		return true
	var record: Dictionary = {
		"immediate_resolution_id": addition["immediate_resolution_id"],
		"public_card_ref": addition["public_card_ref"],
		"effect_id": addition["effect_id"],
		"actor_player": addition["actor_player"],
		"enclosing_kind": enclosure.get("enclosing_kind", ""),
	}
	match str(record["enclosing_kind"]):
		"attack":
			record["attack_id"] = enclosure.get("attack_id", "")
		"debug":
			record["debug_application_id"] = enclosure.get(
					"debug_application_id", "")
		"maneuver":
			for key: String in [
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id"]:
				record[key] = enclosure.get(key, "")
		_:
			ship.faceup_damage.erase(card)
			return false
	if not ship.establish_filtered_immediate_resolution(record):
		ship.faceup_damage.erase(card)
		return false
	return true


static func _public_faceup_fields_are_valid(data: Dictionary) -> bool:
	return typeof(data["public_card_ref"]) == TYPE_STRING \
			and not str(data["public_card_ref"]).is_empty() \
			and typeof(data["trait_type"]) == TYPE_STRING \
			and typeof(data["title"]) == TYPE_STRING \
			and data["is_faceup"] == true \
			and typeof(data["effect_text"]) == TYPE_STRING \
			and typeof(data["timing"]) == TYPE_STRING \
			and typeof(data["effect_id"]) == TYPE_STRING


static func _is_public_damage_card(data: Dictionary) -> bool:
	var fields: Array[String] = PUBLIC_CARD_KEYS.duplicate()
	fields.erase("public_card_ref")
	if not _has_exact_keys(data, fields):
		return false
	return typeof(data["trait_type"]) == TYPE_STRING \
			and typeof(data["title"]) == TYPE_STRING \
			and typeof(data["is_faceup"]) == TYPE_BOOL \
			and typeof(data["effect_text"]) == TYPE_STRING \
			and typeof(data["timing"]) == TYPE_STRING \
			and typeof(data["effect_id"]) == TYPE_STRING


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true

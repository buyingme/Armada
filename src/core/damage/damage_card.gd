## DamageCard
##
## Represents a single damage card in the 52-card damage deck.
## Each card has a trait ("Ship" or "Crew"), a title, effect text, timing
## category, and an effect identifier used by immediate resolvers and rules.
##
## Timing categories:
##   "persistent"          — effect remains active while faceup
##   "immediate"           — resolved on deal, then flipped facedown
##   "immediate_persistent" — immediate action on deal, stays faceup with
##                            an ongoing restriction (Life Support Failure)
##
## Rules Reference: DM-005, DM-006, DM-009.
class_name DamageCard
extends RefCounted


## The trait of this damage card: "Ship" or "Crew".
## Rules Reference: DM-009.
var trait_type: String = ""

## The title/name of this damage card.
var title: String = ""

## Whether this card is faceup (critical hit) or facedown.
## Rules Reference: DM-005 (faceup), DM-006 (facedown).
var is_faceup: bool = false

## Human-readable effect description.
## Rules Reference: DM-005 — faceup cards have effects.
var effect_text: String = ""

## Timing category: "persistent", "immediate", or "immediate_persistent".
var timing: String = ""

## Identifier used by command resolvers and RuleRegistry rules.
var effect_id: String = ""

## Dormant save-7 authority identity. It is assigned once during candidate
## deck construction and remains private across every physical location.
var physical_card_id: String = ""

## One assignment-scoped public faceup occurrence. It exists only while this
## physical card is faceup on a ship and is erased before concealment.
var public_card_ref: String = ""

## Purpose-specific exact-once evidence for the three persistent Maneuver
## cards. Only the matching effect may publish its key in save 7.
var last_thruster_fissure_execution_id: String = ""
var last_damaged_controls_execution_id: String = ""
var last_ruptured_engine_execution_id: String = ""


## Creates a DamageCard with the given trait and title.
static func create(card_trait: String, card_title: String) -> DamageCard:
	var card: DamageCard = DamageCard.new()
	card.trait_type = card_trait
	card.title = card_title
	return card


## Creates a fully-populated DamageCard from a JSON data dictionary.
## Expected keys: "trait", "title", "effect_text", "timing", "effect_id".
static func from_data(data: Dictionary) -> DamageCard:
	var card: DamageCard = DamageCard.new()
	card.trait_type = data.get("trait", "")
	card.title = data.get("title", "")
	card.effect_text = data.get("effect_text", "")
	card.timing = data.get("timing", "")
	card.effect_id = data.get("effect_id", "")
	return card


## Flips this card faceup.  Called when dealt as a critical hit.
## Rules Reference: DM-005.
func flip_faceup() -> void:
	is_faceup = true


## Flips this card facedown.  Called when an immediate effect resolves
## or when a repair/effect flips it.
## Rules Reference: DM-006.
func flip_facedown() -> void:
	is_faceup = false
	public_card_ref = ""


## Returns true if this card has a persistent effect (stays faceup).
func is_persistent() -> bool:
	return timing == "persistent" or timing == "immediate_persistent"


## Returns true if this card has an immediate effect (resolves on deal).
func is_immediate() -> bool:
	return timing == "immediate" or timing == "immediate_persistent"


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------


## Serializes this damage card to a dictionary suitable for JSON persistence.
## Captures all mutable and identity fields needed for round-trip restore.
func serialize() -> Dictionary:
	return {
		"trait_type": trait_type,
		"title": title,
		"is_faceup": is_faceup,
		"effect_text": effect_text,
		"timing": timing,
		"effect_id": effect_id,
	}


## Strict dormant save-7 authority shape. Current save-6 callers continue to
## use serialize() and therefore publish none of these candidate fields.
func serialize_for_save7(location: String) -> Dictionary:
	if not validate_candidate_identity_for_location(location):
		return {}
	var data: Dictionary = serialize()
	data["physical_card_id"] = physical_card_id
	if is_faceup:
		data["public_card_ref"] = public_card_ref
	match effect_id:
		"thruster_fissure":
			data["last_thruster_fissure_execution_id"] = \
					last_thruster_fissure_execution_id
		"damaged_controls":
			data["last_damaged_controls_execution_id"] = \
					last_damaged_controls_execution_id
		"ruptured_engine":
			data["last_ruptured_engine_execution_id"] = \
					last_ruptured_engine_execution_id
	return data


func validate_candidate_identity_for_location(location: String) -> bool:
	if physical_card_id.is_empty() \
			or not physical_card_id.begins_with("damage:") \
			or location not in ["draw", "discard", "ship"]:
		return false
	if location != "ship" and (is_faceup or not public_card_ref.is_empty()):
		return false
	if is_faceup != not public_card_ref.is_empty():
		return false
	if effect_id != "thruster_fissure" \
			and not last_thruster_fissure_execution_id.is_empty():
		return false
	if effect_id != "damaged_controls" \
			and not last_damaged_controls_execution_id.is_empty():
		return false
	if effect_id != "ruptured_engine" \
			and not last_ruptured_engine_execution_id.is_empty():
		return false
	return true


func public_damage_card() -> Dictionary:
	return serialize()


func public_faceup_damage_card() -> Dictionary:
	if not is_faceup or public_card_ref.is_empty():
		return {}
	var data: Dictionary = serialize()
	data["public_card_ref"] = public_card_ref
	return data


## Restores a DamageCard from a serialized dictionary.
## Preserves the [member is_faceup] state (unlike [method from_data] which
## always creates facedown cards).
static func deserialize(data: Dictionary) -> DamageCard:
	var card: DamageCard = DamageCard.new()
	card.trait_type = data.get("trait_type", "")
	card.title = data.get("title", "")
	card.is_faceup = data.get("is_faceup", false) as bool
	card.effect_text = data.get("effect_text", "")
	card.timing = data.get("timing", "")
	card.effect_id = data.get("effect_id", "")
	return card


## Restores the exact filtered public faceup value. This never creates an
## authority physical identity and is therefore legal only on a passive ship.
static func deserialize_public_faceup(data: Dictionary) -> DamageCard:
	var expected: Array[String] = [
		"public_card_ref", "trait_type", "title", "is_faceup",
		"effect_text", "timing", "effect_id",
	]
	if not _has_exact_keys(data, expected) \
			or typeof(data.get("public_card_ref")) != TYPE_STRING \
			or str(data["public_card_ref"]).is_empty() \
			or typeof(data.get("trait_type")) != TYPE_STRING \
			or typeof(data.get("title")) != TYPE_STRING \
			or data.get("is_faceup") != true \
			or typeof(data.get("effect_text")) != TYPE_STRING \
			or typeof(data.get("timing")) != TYPE_STRING \
			or str(data["timing"]) not in [
				"persistent", "immediate", "immediate_persistent"] \
			or typeof(data.get("effect_id")) != TYPE_STRING:
		return null
	var card: DamageCard = deserialize(data)
	card.public_card_ref = str(data["public_card_ref"])
	return card


static func deserialize_for_save7(data: Dictionary,
		location: String) -> DamageCard:
	var allowed: Array[String] = [
		"trait_type", "title", "is_faceup", "effect_text", "timing",
		"effect_id", "physical_card_id",
	]
	if bool(data.get("is_faceup", false)):
		allowed.append("public_card_ref")
	var effect: String = str(data.get("effect_id", ""))
	var marker_key: String = _candidate_marker_key(effect)
	if not marker_key.is_empty():
		allowed.append(marker_key)
	if not _has_exact_keys(data, allowed):
		return null
	var card: DamageCard = deserialize(data)
	card.physical_card_id = str(data["physical_card_id"])
	card.public_card_ref = str(data.get("public_card_ref", ""))
	match effect:
		"thruster_fissure":
			card.last_thruster_fissure_execution_id = str(data[marker_key])
		"damaged_controls":
			card.last_damaged_controls_execution_id = str(data[marker_key])
		"ruptured_engine":
			card.last_ruptured_engine_execution_id = str(data[marker_key])
	if not card.validate_candidate_identity_for_location(location):
		return null
	return card


static func _candidate_marker_key(effect: String) -> String:
	match effect:
		"thruster_fissure":
			return "last_thruster_fissure_execution_id"
		"damaged_controls":
			return "last_damaged_controls_execution_id"
		"ruptured_engine":
			return "last_ruptured_engine_execution_id"
	return ""


static func _has_exact_keys(data: Dictionary,
		allowed: Array[String]) -> bool:
	if data.size() != allowed.size():
		return false
	for key: String in allowed:
		if not data.has(key):
			return false
	return true

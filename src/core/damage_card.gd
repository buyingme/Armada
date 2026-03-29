## DamageCard
##
## Represents a single damage card in the 52-card damage deck.
## Each card has a trait ("Ship" or "Crew"), a title, effect text, timing
## category, and an effect identifier for the EffectFactory.
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

## Identifier used by EffectFactory to look up the concrete GameEffect class.
var effect_id: String = ""


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


## Returns true if this card has a persistent effect (stays faceup).
func is_persistent() -> bool:
	return timing == "persistent" or timing == "immediate_persistent"


## Returns true if this card has an immediate effect (resolves on deal).
func is_immediate() -> bool:
	return timing == "immediate" or timing == "immediate_persistent"

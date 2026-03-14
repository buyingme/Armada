## DamageCard
##
## Represents a single damage card in the 52-card damage deck.
## Each card has a trait ("Ship" or "Crew") and a title.
## In the MVP, critical effects are not resolved — only the standard critical
## effect is used (RRG "Damage"). The trait is tracked for future use (DM-009).
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


## Creates a DamageCard with the given trait and title.
static func create(card_trait: String, card_title: String) -> DamageCard:
	var card: DamageCard = DamageCard.new()
	card.trait_type = card_trait
	card.title = card_title
	return card

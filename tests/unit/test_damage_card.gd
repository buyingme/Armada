## Test: DamageCard
##
## Unit tests for DamageCard — single card in the damage deck.
## Rules Reference: DM-005, DM-006, DM-009.
extends GutTest


func test_create_sets_trait_type() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	assert_eq(card.trait_type, "Ship",
			"trait_type should be 'Ship'")


func test_create_sets_title() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Injured Crew")
	assert_eq(card.title, "Injured Crew",
			"title should match creation arg")


func test_create_defaults_facedown() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	assert_false(card.is_faceup,
			"New card should be facedown by default")


func test_can_flip_faceup() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Crit")
	card.is_faceup = true
	assert_true(card.is_faceup,
			"Card should be flippable to faceup (DM-005)")

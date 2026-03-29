## Test: DamageCard
##
## Unit tests for DamageCard — damage card data model.
## Rules Reference: DM-005, DM-006, DM-009.
extends GutTest


# --- Factory: create() ---

func test_create_sets_trait_type() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	assert_eq(card.trait_type, "Ship",
			"create() should set trait_type")


func test_create_sets_title() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Injured Crew")
	assert_eq(card.title, "Injured Crew",
			"create() should set title")


func test_create_defaults_facedown() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	assert_false(card.is_faceup,
			"Newly created card should be facedown")


func test_create_defaults_empty_effect_fields() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	assert_eq(card.effect_text, "",
			"create() should leave effect_text empty")
	assert_eq(card.timing, "",
			"create() should leave timing empty")
	assert_eq(card.effect_id, "",
			"create() should leave effect_id empty")


# --- Factory: from_data() ---

func test_from_data_sets_all_fields() -> void:
	var data: Dictionary = {
		"trait": "Ship",
		"title": "Structural Damage",
		"count": 2,
		"timing": "persistent",
		"effect_text": "Reduce hull by 1.",
		"effect_id": "structural_damage",
	}
	var card: DamageCard = DamageCard.from_data(data)
	assert_eq(card.trait_type, "Ship",
			"from_data() should set trait_type from 'trait' key")
	assert_eq(card.title, "Structural Damage",
			"from_data() should set title")
	assert_eq(card.timing, "persistent",
			"from_data() should set timing")
	assert_eq(card.effect_text, "Reduce hull by 1.",
			"from_data() should set effect_text")
	assert_eq(card.effect_id, "structural_damage",
			"from_data() should set effect_id")


func test_from_data_defaults_facedown() -> void:
	var data: Dictionary = {"trait": "Crew", "title": "Test"}
	var card: DamageCard = DamageCard.from_data(data)
	assert_false(card.is_faceup,
			"from_data() card should default to facedown")


func test_from_data_handles_missing_keys() -> void:
	var data: Dictionary = {}
	var card: DamageCard = DamageCard.from_data(data)
	assert_eq(card.trait_type, "",
			"Missing 'trait' should default to empty string")
	assert_eq(card.title, "",
			"Missing 'title' should default to empty string")
	assert_eq(card.effect_text, "",
			"Missing 'effect_text' should default to empty string")
	assert_eq(card.timing, "",
			"Missing 'timing' should default to empty string")
	assert_eq(card.effect_id, "",
			"Missing 'effect_id' should default to empty string")


# --- Flip methods ---

func test_flip_faceup() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	assert_false(card.is_faceup, "Should start facedown")
	card.flip_faceup()
	assert_true(card.is_faceup,
			"flip_faceup() should set is_faceup to true (DM-005)")


func test_flip_facedown() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.flip_faceup()
	card.flip_facedown()
	assert_false(card.is_faceup,
			"flip_facedown() should set is_faceup to false (DM-006)")


func test_flip_faceup_idempotent() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.flip_faceup()
	card.flip_faceup()
	assert_true(card.is_faceup,
			"Flipping faceup twice should still be faceup")


func test_flip_facedown_idempotent() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.flip_facedown()
	assert_false(card.is_faceup,
			"Flipping facedown when already facedown should remain facedown")


# --- Timing helpers ---

func test_is_persistent_for_persistent() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.timing = "persistent"
	assert_true(card.is_persistent(),
			"'persistent' timing should be persistent")


func test_is_persistent_for_immediate_persistent() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Test")
	card.timing = "immediate_persistent"
	assert_true(card.is_persistent(),
			"'immediate_persistent' timing should be persistent")


func test_is_persistent_for_immediate() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.timing = "immediate"
	assert_false(card.is_persistent(),
			"'immediate' timing should not be persistent")


func test_is_immediate_for_immediate() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.timing = "immediate"
	assert_true(card.is_immediate(),
			"'immediate' timing should be immediate")


func test_is_immediate_for_immediate_persistent() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Test")
	card.timing = "immediate_persistent"
	assert_true(card.is_immediate(),
			"'immediate_persistent' timing should be immediate")


func test_is_immediate_for_persistent() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.timing = "persistent"
	assert_false(card.is_immediate(),
			"'persistent' timing should not be immediate")


# --- Integration: deck cards have full data ---

func test_deck_cards_have_effect_data() -> void:
	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	var card: DamageCard = deck.draw_card()
	assert_ne(card.effect_id, "",
			"Cards from initialised deck should have an effect_id")
	assert_ne(card.effect_text, "",
			"Cards from initialised deck should have effect_text")
	assert_ne(card.timing, "",
			"Cards from initialised deck should have timing")


func test_deck_cards_have_valid_timing() -> void:
	var valid_timings: Array[String] = [
		"persistent", "immediate", "immediate_persistent"
	]
	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	for i: int in range(DamageDeck.DECK_SIZE):
		var card: DamageCard = deck.draw_card()
		assert_has(valid_timings, card.timing,
				"Card '%s' should have a valid timing value" % card.title)

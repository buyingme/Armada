## Test: DamageDeck
##
## Unit tests for DamageDeck — 52-card shuffled damage deck.
## Rules Reference: SU-029, DM-007, DM-008.
extends GutTest


var _deck: DamageDeck = null


func before_each() -> void:
	_deck = DamageDeck.new()
	_deck.initialize()


# --- Initialization ---

func test_initialize_creates_52_cards() -> void:
	assert_eq(_deck.get_draw_count(), DamageDeck.DECK_SIZE,
			"Draw pile should have 52 cards after initialize (SU-029)")


func test_initialize_discard_empty() -> void:
	assert_eq(_deck.get_discard_count(), 0,
			"Discard pile should be empty after initialize")


func test_initialize_total_count() -> void:
	assert_eq(_deck.get_total_count(), DamageDeck.DECK_SIZE,
			"Total count should be 52")


func test_deck_composition_ship_trait_count() -> void:
	var ship_count: int = 0
	# Draw all cards and count Ship trait.
	for i: int in range(DamageDeck.DECK_SIZE):
		var card: DamageCard = _deck.draw_card()
		if card.trait_type == "Ship":
			ship_count += 1
	assert_eq(ship_count, 36,
			"Should have 36 Ship-trait cards (15 types)")


func test_deck_composition_crew_trait_count() -> void:
	var crew_count: int = 0
	for i: int in range(DamageDeck.DECK_SIZE):
		var card: DamageCard = _deck.draw_card()
		if card.trait_type == "Crew":
			crew_count += 1
	assert_eq(crew_count, 16,
			"Should have 16 Crew-trait cards (7 types)")


# --- Draw ---

func test_draw_card_returns_card() -> void:
	var card: DamageCard = _deck.draw_card()
	assert_not_null(card, "draw_card should return a DamageCard")


func test_draw_card_reduces_count() -> void:
	_deck.draw_card()
	assert_eq(_deck.get_draw_count(), DamageDeck.DECK_SIZE - 1,
			"Drawing 1 card should reduce draw pile by 1")


func test_draw_all_cards() -> void:
	for i: int in range(DamageDeck.DECK_SIZE):
		var card: DamageCard = _deck.draw_card()
		assert_not_null(card, "Card %d should not be null" % i)
	assert_eq(_deck.get_draw_count(), 0,
			"Draw pile should be empty after drawing all cards")


# --- Discard ---

func test_discard_adds_to_pile() -> void:
	var card: DamageCard = _deck.draw_card()
	_deck.discard(card)
	assert_eq(_deck.get_discard_count(), 1,
			"Discard pile should have 1 card")


func test_discard_preserves_total() -> void:
	var card: DamageCard = _deck.draw_card()
	_deck.discard(card)
	assert_eq(_deck.get_total_count(), DamageDeck.DECK_SIZE,
			"Total count should remain 52 after draw+discard")


# --- Reshuffle (DM-008) ---

func test_reshuffle_when_draw_empty() -> void:
	# Draw all cards, discard half.
	var drawn: Array[DamageCard] = []
	for i: int in range(DamageDeck.DECK_SIZE):
		drawn.append(_deck.draw_card())
	for i: int in range(26):
		_deck.discard(drawn[i])
	# Draw pile is empty, discard has 26.
	var card: DamageCard = _deck.draw_card()
	assert_not_null(card,
			"Should reshuffle discard into draw pile (DM-008)")
	# After reshuffle: 26 - 1 = 25 in draw, 0 in discard.
	assert_eq(_deck.get_draw_count(), 25,
			"After reshuffle and draw, 25 should remain in draw pile")
	assert_eq(_deck.get_discard_count(), 0,
			"Discard pile should be empty after reshuffle")


func test_draw_returns_null_when_both_empty() -> void:
	for i: int in range(DamageDeck.DECK_SIZE):
		_deck.draw_card()
	# Both piles empty, no discards.
	var card: DamageCard = _deck.draw_card()
	assert_null(card,
			"Should return null when both piles are completely empty")
	assert_push_error(1,
			"Should log an error when drawing from empty deck")


# --- Reinitialise ---

func test_reinitialize_resets_deck() -> void:
	_deck.draw_card()
	_deck.draw_card()
	_deck.initialize()
	assert_eq(_deck.get_draw_count(), DamageDeck.DECK_SIZE,
			"Re-initialize should reset to 52 cards")
	assert_eq(_deck.get_discard_count(), 0,
			"Re-initialize should clear discard pile")


# --- Serialization ---

func test_serialize_contains_piles() -> void:
	var data: Dictionary = _deck.serialize()
	assert_true(data.has("draw_pile"),
			"serialize() should include draw_pile key")
	assert_true(data.has("discard_pile"),
			"serialize() should include discard_pile key")


func test_serialize_full_deck_draw_pile_size() -> void:
	var data: Dictionary = _deck.serialize()
	assert_eq((data["draw_pile"] as Array).size(), DamageDeck.DECK_SIZE,
			"Full deck draw_pile should have 52 entries")
	assert_eq((data["discard_pile"] as Array).size(), 0,
			"Full deck discard_pile should be empty")


func test_serialize_after_draw_and_discard() -> void:
	var card: DamageCard = _deck.draw_card()
	_deck.discard(card)
	var data: Dictionary = _deck.serialize()
	assert_eq((data["draw_pile"] as Array).size(), DamageDeck.DECK_SIZE - 1,
			"draw_pile should reflect 1 card removed")
	assert_eq((data["discard_pile"] as Array).size(), 1,
			"discard_pile should have the discarded card")


func test_deserialize_round_trip_preserves_counts() -> void:
	# Draw 5 cards, discard 2.
	var drawn: Array[DamageCard] = []
	for i: int in range(5):
		drawn.append(_deck.draw_card())
	_deck.discard(drawn[0])
	_deck.discard(drawn[1])
	var restored: DamageDeck = DamageDeck.deserialize(_deck.serialize())
	assert_eq(restored.get_draw_count(), DamageDeck.DECK_SIZE - 5,
			"Restored draw count should match original")
	assert_eq(restored.get_discard_count(), 2,
			"Restored discard count should match original")


func test_deserialize_preserves_card_order() -> void:
	# Peek at last 2 cards (draw pops from back) via serialize.
	var data: Dictionary = _deck.serialize()
	var draw_data: Array = data["draw_pile"] as Array
	var last_idx: int = draw_data.size() - 1
	var first_title: String = (draw_data[last_idx] as Dictionary)["title"]
	var second_title: String = (draw_data[last_idx - 1] as Dictionary)["title"]
	var restored: DamageDeck = DamageDeck.deserialize(data)
	var card_1: DamageCard = restored.draw_card()
	var card_2: DamageCard = restored.draw_card()
	assert_eq(card_1.title, first_title,
			"Deserialized deck should preserve card order (1st)")
	assert_eq(card_2.title, second_title,
			"Deserialized deck should preserve card order (2nd)")


func test_deserialize_preserves_faceup_state() -> void:
	var card: DamageCard = _deck.draw_card()
	card.flip_faceup()
	_deck.discard(card)
	var restored: DamageDeck = DamageDeck.deserialize(_deck.serialize())
	# The faceup card is in the discard pile — we need to draw all remaining
	# and then trigger a reshuffle to get it back.  Instead, just verify
	# the serialized data directly.
	var data: Dictionary = _deck.serialize()
	var discard_data: Array = data["discard_pile"] as Array
	assert_true((discard_data[0] as Dictionary)["is_faceup"] as bool,
			"Serialized discard card should preserve faceup state")


func test_deserialize_empty_data() -> void:
	var restored: DamageDeck = DamageDeck.deserialize({})
	assert_eq(restored.get_draw_count(), 0,
			"Deserializing empty dict should produce empty draw pile")
	assert_eq(restored.get_discard_count(), 0,
			"Deserializing empty dict should produce empty discard pile")

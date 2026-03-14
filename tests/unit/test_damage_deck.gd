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
	assert_eq(ship_count, 28,
			"Should have 28 Ship-trait cards (7 types × 4)")


func test_deck_composition_crew_trait_count() -> void:
	var crew_count: int = 0
	for i: int in range(DamageDeck.DECK_SIZE):
		var card: DamageCard = _deck.draw_card()
		if card.trait_type == "Crew":
			crew_count += 1
	assert_eq(crew_count, 24,
			"Should have 24 Crew-trait cards (6 types × 4)")


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

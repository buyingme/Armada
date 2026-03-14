## DamageDeck
##
## A shuffled 52-card damage deck for the Armada game.
## Provides draw and discard operations. When the draw pile is empty,
## the discard pile is automatically shuffled to form a new deck (DM-008).
##
## The standard Armada damage deck has 52 cards:
##   7 unique critical effects × 4 copies each = 28 cards with Ship trait
##   6 unique critical effects × 4 copies each = 24 cards with Crew trait
## Total: 52 cards.
##
## In the MVP, only the trait is tracked. Actual critical effect text is
## stored for future phases.
##
## Rules Reference: SU-029, DM-007, DM-008, DM-009.
class_name DamageDeck
extends RefCounted


## The standard deck composition: {title: {trait: String, count: int}}.
## 7 Ship-trait cards × 4 copies = 28 Ship cards.
## 6 Crew-trait cards × 4 copies = 24 Crew cards.
## Total = 52.
## Rules Reference: RRG "Damage Cards".
const DECK_COMPOSITION: Array[Dictionary] = [
	{"title": "Blinded Gunners", "trait": "Ship", "count": 4},
	{"title": "Damaged Controls", "trait": "Ship", "count": 4},
	{"title": "Damaged Munitions", "trait": "Ship", "count": 4},
	{"title": "Disengaged Fire Control", "trait": "Ship", "count": 4},
	{"title": "Projector Failure", "trait": "Ship", "count": 4},
	{"title": "Ruptured Engine", "trait": "Ship", "count": 4},
	{"title": "Structural Damage", "trait": "Ship", "count": 4},
	{"title": "Compartment Fire", "trait": "Crew", "count": 4},
	{"title": "Crew Panic", "trait": "Crew", "count": 4},
	{"title": "Damaged Sensors", "trait": "Crew", "count": 4},
	{"title": "Injured Crew", "trait": "Crew", "count": 4},
	{"title": "Life Support Failure", "trait": "Crew", "count": 4},
	{"title": "Overheated Reactor", "trait": "Crew", "count": 4},
]

## Total number of cards in a standard damage deck.
const DECK_SIZE: int = 52

## Logger for this system.
var _log: GameLogger = GameLogger.new("DamageDeck")

## The draw pile (top of array = top of deck).
var _draw_pile: Array[DamageCard] = []

## The discard pile.
var _discard_pile: Array[DamageCard] = []


## Builds and shuffles a standard 52-card damage deck.
## Rules Reference: SU-029 — the damage deck is shuffled and placed facedown.
func initialize() -> void:
	_draw_pile.clear()
	_discard_pile.clear()
	for entry: Dictionary in DECK_COMPOSITION:
		for i: int in range(int(entry["count"])):
			var card: DamageCard = DamageCard.create(
					entry["trait"], entry["title"])
			_draw_pile.append(card)
	_shuffle_draw_pile()
	_log.info("Damage deck initialised: %d cards" % _draw_pile.size())


## Draws the top card from the deck.
## If the draw pile is empty, reshuffles the discard pile first (DM-008).
## Returns null if both piles are empty (should not happen in normal play).
## Rules Reference: DM-007 — cards dealt one at a time; DM-008.
func draw_card() -> DamageCard:
	if _draw_pile.is_empty():
		_reshuffle_discard()
	if _draw_pile.is_empty():
		_log.error("No damage cards remaining in draw or discard pile!")
		return null
	return _draw_pile.pop_back()


## Adds a card to the discard pile.
## Used when damage cards are removed from a ship (e.g. by repair).
func discard(card: DamageCard) -> void:
	_discard_pile.append(card)


## Returns the number of cards remaining in the draw pile.
func get_draw_count() -> int:
	return _draw_pile.size()


## Returns the number of cards in the discard pile.
func get_discard_count() -> int:
	return _discard_pile.size()


## Returns the total cards across both piles (should always be 52 minus
## those assigned to ships).
func get_total_count() -> int:
	return _draw_pile.size() + _discard_pile.size()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Fisher-Yates shuffle of the draw pile.
func _shuffle_draw_pile() -> void:
	_draw_pile.shuffle()


## Moves all discard pile cards into the draw pile and reshuffles.
## Rules Reference: DM-008.
func _reshuffle_discard() -> void:
	if _discard_pile.is_empty():
		return
	_log.info("Reshuffling %d discarded damage cards into draw pile" %
			_discard_pile.size())
	_draw_pile.append_array(_discard_pile)
	_discard_pile.clear()
	_shuffle_draw_pile()

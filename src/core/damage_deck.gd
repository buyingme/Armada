## DamageDeck
##
## A shuffled 52-card damage deck for the Armada game.
## Provides draw and discard operations. When the draw pile is empty,
## the discard pile is automatically shuffled to form a new deck (DM-008).
##
## The standard Armada damage deck has 52 cards:
##   15 unique critical effects with Ship trait (36 cards total)
##    7 unique critical effects with Crew trait (16 cards total)
## Card data is loaded from Resources/Game_Components/damage_cards.json.
##
## Rules Reference: SU-029, DM-007, DM-008, DM-009.
class_name DamageDeck
extends RefCounted


## Path to the authoritative damage-card data JSON.
const DATA_FILE: String = "damage_cards.json"

## Total number of cards in a standard damage deck.
const DECK_SIZE: int = 52

## Logger for this system.
var _log: GameLogger = GameLogger.new("DamageDeck")

## The draw pile (top of array = top of deck).
var _draw_pile: Array[DamageCard] = []

## The discard pile.
var _discard_pile: Array[DamageCard] = []


## Builds and shuffles a standard 52-card damage deck.
## Card data is loaded from the JSON data file via AssetLoader.
## Rules Reference: SU-029 — the damage deck is shuffled and placed facedown.
func initialize() -> void:
	_draw_pile.clear()
	_discard_pile.clear()

	var data: Dictionary = AssetLoader.load_json("", DATA_FILE)
	if data.is_empty() or not data.has("cards"):
		_log.error("Failed to load damage card data from %s" % DATA_FILE)
		return

	var cards_array: Array = data["cards"]
	for entry: Dictionary in cards_array:
		var count: int = int(entry.get("count", 0))
		for i: int in range(count):
			var card: DamageCard = DamageCard.from_data(entry)
			_draw_pile.append(card)

	if _draw_pile.size() != DECK_SIZE:
		_log.warning("Damage deck has %d cards, expected %d" % [
				_draw_pile.size(), DECK_SIZE])

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

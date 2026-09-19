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

## Optional seeded RNG. When set, shuffle uses deterministic ordering.
var _rng: GameRng = null


## Sets the [GameRng] instance used for shuffling.
## Call before [method initialize] to get a deterministic deck order.
func set_rng(rng: GameRng) -> void:
	_rng = rng


## Builds and shuffles a standard 52-card damage deck.
## Card data is loaded from the JSON data file via AssetLoader.
## Rules Reference: SU-029 — the damage deck is shuffled and placed facedown.
func initialize() -> void:
	# Save 7 is now the only live authority representation. Physical identity
	# is assigned at deck construction even for callers that use the historical
	# initializer name.
	_initialize_cards(true)


## Dormant save-7 construction path. Physical identities are assigned in
## construction order before the first shuffle and never regenerated.
func initialize_for_save7() -> void:
	_initialize_cards(true)


func _initialize_cards(assign_physical_identities: bool) -> void:
	_draw_pile.clear()
	_discard_pile.clear()

	var data: Dictionary = AssetLoader.load_json("", DATA_FILE)
	if data.is_empty() or not data.has("cards"):
		_log.error("Failed to load damage card data from %s" % DATA_FILE)
		return

	var cards_array: Array = data["cards"]
	var construction_ordinal: int = 0
	for entry: Dictionary in cards_array:
		var count: int = int(entry.get("count", 0))
		for i: int in range(count):
			var card: DamageCard = DamageCard.from_data(entry)
			if assign_physical_identities:
				card.physical_card_id = "damage:%d" % construction_ordinal
			_draw_pile.append(card)
			construction_ordinal += 1

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


## Returns whether the current draw pile contains a card with [param effect_id].
## This intentionally does not consult the discard pile or reshuffle it: debug
## selection is a narrow authoritative setup operation, not an ordinary draw.
func has_debug_draw_card_effect_id(effect_id: String) -> bool:
	if effect_id.is_empty():
		return false
	for index: int in range(_draw_pile.size() - 1, -1, -1):
		if _draw_pile[index].effect_id == effect_id:
			return true
	return false


## Removes and returns the top-most matching card from the current draw pile.
## Remaining draw order and the discard pile are deliberately untouched.
func take_debug_draw_card_by_effect_id(effect_id: String) -> DamageCard:
	if effect_id.is_empty():
		return null
	for index: int in range(_draw_pile.size() - 1, -1, -1):
		if _draw_pile[index].effect_id == effect_id:
			var card: DamageCard = _draw_pile[index]
			_draw_pile.remove_at(index)
			return card
	return null


## Adds a card to the discard pile.
## Used when damage cards are removed from a ship (e.g. by repair).
func discard(card: DamageCard) -> void:
	if card != null and not card.physical_card_id.is_empty():
		card.flip_facedown()
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
## Uses [member _rng] when available; otherwise falls back to
## [method Array.shuffle] (global RNG).
func _shuffle_draw_pile() -> void:
	if _rng:
		_rng.shuffle(_draw_pile)
	else:
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


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------


## Serializes the deck state (draw pile order + discard pile order).
## Cards currently assigned to ships are NOT included — they are serialized
## with their owning ShipInstance.
func serialize() -> Dictionary:
	var draw: Array[Dictionary] = []
	for card: DamageCard in _draw_pile:
		draw.append(card.serialize())
	var discard: Array[Dictionary] = []
	for card: DamageCard in _discard_pile:
		discard.append(card.serialize())
	return {
		"draw_pile": draw,
		"discard_pile": discard,
	}


## Strict dormant save-7 deck shape.
func serialize_for_save7() -> Dictionary:
	var draw: Array[Dictionary] = []
	for card: DamageCard in _draw_pile:
		var data: Dictionary = card.serialize_for_save7("draw")
		if data.is_empty():
			return {}
		draw.append(data)
	var discard: Array[Dictionary] = []
	for card: DamageCard in _discard_pile:
		var data: Dictionary = card.serialize_for_save7("discard")
		if data.is_empty():
			return {}
		discard.append(data)
	return {"draw_pile": draw, "discard_pile": discard}


## Read-only identity/location entries for the aggregate save-7 validator.
func candidate_identity_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: DamageCard in _draw_pile:
		result.append({"physical_card_id": card.physical_card_id,
			"location": "draw", "card": card})
	for card: DamageCard in _discard_pile:
		result.append({"physical_card_id": card.physical_card_id,
			"location": "discard", "card": card})
	return result


## Restores a DamageDeck from a serialized dictionary.
## Preserves exact card order (no shuffle).
static func deserialize(data: Dictionary) -> DamageDeck:
	var deck: DamageDeck = DamageDeck.new()
	for card_data: Variant in data.get("draw_pile", []):
		deck._draw_pile.append(DamageCard.deserialize(
				card_data as Dictionary))
	for card_data: Variant in data.get("discard_pile", []):
		deck._discard_pile.append(DamageCard.deserialize(
				card_data as Dictionary))
	return deck


static func deserialize_for_save7(data: Dictionary) -> DamageDeck:
	if data.size() != 2 or not data.has("draw_pile") \
			or not data.has("discard_pile") \
			or not (data["draw_pile"] is Array) \
			or not (data["discard_pile"] is Array):
		return null
	var deck: DamageDeck = DamageDeck.new()
	var identities: Dictionary = {}
	for raw: Variant in data["draw_pile"]:
		if not (raw is Dictionary):
			return null
		var card: DamageCard = DamageCard.deserialize_for_save7(
				raw as Dictionary, "draw")
		if card == null or identities.has(card.physical_card_id):
			return null
		identities[card.physical_card_id] = true
		deck._draw_pile.append(card)
	for raw: Variant in data["discard_pile"]:
		if not (raw is Dictionary):
			return null
		var card: DamageCard = DamageCard.deserialize_for_save7(
				raw as Dictionary, "discard")
		if card == null or identities.has(card.physical_card_id):
			return null
		identities[card.physical_card_id] = true
		deck._discard_pile.append(card)
	return deck

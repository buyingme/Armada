## PersistentEffectDamageCommand
##
## Deals one facedown damage card to a ship as a consequence of a
## persistent damage-card effect (Ruptured Engine, Damaged Controls,
## Thruster Fissure, or Crew Panic).
##
## The card is pre-drawn by the presentation layer and serialized into
## the payload so the command is deterministic on replay.
##
## Payload:
##   [code]owner_player[/code] — int — ship owner index
##   [code]ship_index[/code]   — int — index in the player's fleet
##   [code]effect_id[/code]    — String — which persistent effect triggered
##   [code]card_data[/code]    — Dictionary — serialized DamageCard, or
##   [code]draw_from_deck[/code] — bool — draw deterministically in execute()
##
## Rules Reference: "Ruptured Engine", "Damaged Controls",
## "Thruster Fissure", "Crew Panic" card texts.
class_name PersistentEffectDamageCommand
extends GameCommand


## Valid persistent-damage-dealing effect ids.
const VALID_EFFECTS: Array[String] = [
	"ruptured_engine",
	"damaged_controls",
	"thruster_fissure",
	"crew_panic",
]


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("persistent_effect_damage", func(
			player: int, pl: Dictionary) -> GameCommand:
		return PersistentEffectDamageCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "persistent_effect_damage", p_payload)


## Validates that the ship exists and card data is provided.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var effect_id: String = str(payload.get("effect_id", ""))
	if effect_id not in VALID_EFFECTS:
		return "Unknown persistent effect: '%s'." % effect_id
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	if ship == null:
		return "Ship not found."
	if _has_card_payload():
		return ""
	if bool(payload.get("draw_from_deck", false)):
		return _validate_damage_deck(game_state)
	return "Missing card_data."


## Deals one facedown damage card, checks for destruction.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	var card: DamageCard = _damage_card_for_payload(game_state)
	if card == null:
		return {}
	card.is_faceup = false
	ship.add_facedown_damage(card)
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	var destroyed: bool = ship.is_destroyed()
	if destroyed:
		ship.mark_destroyed()
	return {
		"effect_id": payload.get("effect_id", ""),
		"owner_player": owner,
		"ship_index": idx,
		"cards_added": 1,
		"card_title": card.title,
		"card_data": card.serialize(),
		"new_hull": new_hull,
		"destroyed": destroyed,
	}


func _has_card_payload() -> bool:
	var raw_card: Variant = payload.get("card_data", {})
	return raw_card is Dictionary and not (raw_card as Dictionary).is_empty()


func _validate_damage_deck(game_state: GameState) -> String:
	if game_state.damage_deck == null:
		return "Missing damage deck."
	if game_state.damage_deck.get_total_count() <= 0:
		return "Damage deck is empty."
	return ""


func _damage_card_for_payload(game_state: GameState) -> DamageCard:
	if _has_card_payload():
		return DamageCard.deserialize(payload.get("card_data", {}))
	if bool(payload.get("draw_from_deck", false)) and game_state.damage_deck:
		return game_state.damage_deck.draw_card()
	return null

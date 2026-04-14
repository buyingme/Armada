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
##   [code]card_data[/code]    — Dictionary — serialized DamageCard
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
	if payload.get("card_data", {}).is_empty():
		return "Missing card_data."
	return ""


## Deals one facedown damage card, checks for destruction.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	var card: DamageCard = DamageCard.deserialize(
			payload.get("card_data", {}))
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
		"new_hull": new_hull,
		"destroyed": destroyed,
	}

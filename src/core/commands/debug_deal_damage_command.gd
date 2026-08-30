## DebugDealDamageCommand
##
## Deals one selected real damage card faceup to a ship via the debug tool.
## The command alone removes the top-most matching card from the authoritative
## current draw pile; presentation supplies only the requested effect id.
##
## Payload:
##   "owner_player" — player index owning the target ship
##   "ship_index"   — index into the player's ships array
##   "effect_id"    — chosen damage card effect ID
##
## DBG-050 — debug damage dealing.
class_name DebugDealDamageCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("debug_deal_damage",
			func(player: int, pl: Dictionary) -> GameCommand:
		return DebugDealDamageCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "debug_deal_damage", p_payload)


## Validates that the debug damage command is legal.
## No phase restriction — debug tool works in any phase.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var owner: int = payload.get("owner_player", -1)
	if owner < 0 or owner >= Constants.PLAYER_COUNT:
		return "Invalid owner_player."
	var ship_index: int = payload.get("ship_index", -1)
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	if ship == null:
		return "Ship not found."
	if payload.get("effect_id", "") == "":
		return "Missing effect_id."
	if game_state.damage_deck == null:
		return "Damage deck not available."
	if not game_state.damage_deck.has_debug_draw_card_effect_id(
			str(payload.get("effect_id", ""))):
		return "Requested damage card is unavailable in the draw pile."
	return ""


## Adds the faceup damage card to the ship and registers a persistent
## effect when applicable.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = payload.get("owner_player", 0)
	var ship_index: int = payload.get("ship_index", 0)
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var effect_id: String = payload.get("effect_id", "")
	if ship == null or game_state.damage_deck == null:
		return {}
	var card: DamageCard = game_state.damage_deck.take_debug_draw_card_by_effect_id(
			effect_id)
	if card == null:
		return {}
	card.is_faceup = true
	ship.add_faceup_damage(card)
	var card_index: int = ship.faceup_damage.size() - 1
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	return {
		"effect_id": effect_id,
		"owner_player": owner,
		"ship_index": ship_index,
		"card_index": card_index,
		"card_title": card.title,
		"persistent_registered": false,
		"new_hull": new_hull,
	}

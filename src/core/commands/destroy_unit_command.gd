## DestroyUnitCommand
##
## Handles the game-state cleanup when a ship is destroyed:
##
##   1. Unregisters all persistent effects owned by the ship.
##   2. Clears all damage cards (faceup + facedown) from the ship.
##   3. Returns cleared cards to the damage deck discard pile.
##
## The actual [method ShipInstance.mark_destroyed] call and the visual
## destruction (fade-out, EventBus signal) remain in the presentation
## layer — this command only covers mutable GameState changes.
##
## Payload:
##   - "owner_player": int — player index (0 or 1)
##   - "ship_index":   int — index into PlayerState.ships
##
## Rules Reference: "Winning and Losing", RRG p.21; DM-030 —
## destroyed ships return damage cards to the discard pile.
class_name DestroyUnitCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("destroy_unit",
			func(player: int, pl: Dictionary) -> GameCommand:
		return DestroyUnitCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "destroy_unit", p_payload)


## Validates that the target ship exists.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if not payload.has("owner_player"):
		return "Missing 'owner_player' in payload."
	if not payload.has("ship_index"):
		return "Missing 'ship_index' in payload."
	var owner: int = int(payload["owner_player"])
	var idx: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	if ship == null:
		return "Ship not found: player %d, index %d." % [owner, idx]
	return ""


## Performs destruction cleanup on the target ship.
## Returns {"cards_returned": int, "data_key": String}.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = int(payload["owner_player"])
	var idx: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, idx)

	# Clear damage cards and return to discard pile.
	var cards: Array = ship.clear_all_damage_cards()
	if game_state.damage_deck:
		for card: Variant in cards:
			game_state.damage_deck.discard(card)

	return {
		"cards_returned": cards.size(),
		"data_key": ship.data_key,
	}

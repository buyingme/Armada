## RepairActionCommand
##
## Routes all Engineering (Repair) mutations through the command system
## for replay and multiplayer safety.  Three action types are supported:
##
## **move_shields** — Transfer 1 shield between hull zones (1 eng pt).
##   Payload: [code]action_type[/code], [code]owner_player[/code],
##   [code]ship_index[/code], [code]from_zone[/code], [code]to_zone[/code].
##
## **recover_shields** — Restore 1 shield to a hull zone (2 eng pts).
##   Payload: [code]action_type[/code], [code]owner_player[/code],
##   [code]ship_index[/code], [code]zone[/code].
##
## **repair_hull** — Discard a damage card from the ship (3 eng pts).
##   Payload: [code]action_type[/code], [code]owner_player[/code],
##   [code]ship_index[/code], [code]card_is_faceup[/code],
##   [code]card_index[/code].
##
## The [RepairResolver] pre-validates affordability and effect hooks,
## then delegates the actual [GameState] mutation to this command.
## Point tracking remains in the resolver (transient session state).
##
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
class_name RepairActionCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("repair_action", func(player: int,
			pl: Dictionary) -> GameCommand:
		return RepairActionCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "repair_action", p_payload)


## Validates that the repair action is legal in the current game state.
## Only allowed during the Ship Phase (repairs happen during activation).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var action: String = payload.get("action_type", "") as String
	match action:
		"move_shields":
			return _validate_move_shields(game_state)
		"recover_shields":
			return _validate_recover_shields(game_state)
		"repair_hull":
			return _validate_repair_hull(game_state)
		_:
			return "Unknown repair action_type: '%s'." % action


## Executes the repair action — mutates [GameState]-owned objects.
func execute(game_state: GameState) -> Dictionary:
	var action: String = payload.get("action_type", "") as String
	match action:
		"move_shields":
			return _execute_move_shields(game_state)
		"recover_shields":
			return _execute_recover_shields(game_state)
		"repair_hull":
			return _execute_repair_hull(game_state)
		_:
			return {"error": "Unknown repair action_type."}


# ---------------------------------------------------------------------------
# Validate helpers
# ---------------------------------------------------------------------------

func _validate_move_shields(game_state: GameState) -> String:
	var ship: ShipInstance = _find_ship(game_state)
	if ship == null:
		return "Ship not found."
	var from_z: String = payload.get("from_zone", "") as String
	var to_z: String = payload.get("to_zone", "") as String
	if from_z == to_z:
		return "Source and target zones are the same."
	if not ship.current_shields.has(from_z):
		return "Invalid source zone: '%s'." % from_z
	if not ship.current_shields.has(to_z):
		return "Invalid target zone: '%s'." % to_z
	if int(ship.current_shields.get(from_z, 0)) <= 0:
		return "Source zone '%s' has no shields." % from_z
	if int(ship.current_shields.get(to_z, 0)) >= ship.get_max_shields(to_z):
		return "Target zone '%s' already at max shields." % to_z
	return ""


func _validate_recover_shields(game_state: GameState) -> String:
	var ship: ShipInstance = _find_ship(game_state)
	if ship == null:
		return "Ship not found."
	var zone: String = payload.get("zone", "") as String
	if not ship.current_shields.has(zone):
		return "Invalid zone: '%s'." % zone
	if int(ship.current_shields.get(zone, 0)) >= ship.get_max_shields(zone):
		return "Zone '%s' already at max shields." % zone
	return ""


func _validate_repair_hull(game_state: GameState) -> String:
	var ship: ShipInstance = _find_ship(game_state)
	if ship == null:
		return "Ship not found."
	var is_faceup: bool = payload.get("card_is_faceup", false) as bool
	var card_idx: int = payload.get("card_index", -1) as int
	var arr: Array = ship.faceup_damage if is_faceup else ship.facedown_damage
	if card_idx < 0 or card_idx >= arr.size():
		return "Invalid card index %d (array size %d)." % [card_idx, arr.size()]
	return ""


# ---------------------------------------------------------------------------
# Execute helpers
# ---------------------------------------------------------------------------

func _execute_move_shields(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = _find_ship(game_state)
	var from_z: String = payload.get("from_zone", "") as String
	var to_z: String = payload.get("to_zone", "") as String
	ship.reduce_shields(from_z, 1)
	ship.restore_shields(to_z, 1)
	return {
		"action_type": "move_shields",
		"from_zone": from_z,
		"to_zone": to_z,
		"from_shields": int(ship.current_shields.get(from_z, 0)),
		"to_shields": int(ship.current_shields.get(to_z, 0)),
	}


func _execute_recover_shields(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = _find_ship(game_state)
	var zone: String = payload.get("zone", "") as String
	ship.restore_shields(zone, 1)
	return {
		"action_type": "recover_shields",
		"zone": zone,
		"new_shields": int(ship.current_shields.get(zone, 0)),
	}


func _execute_repair_hull(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = _find_ship(game_state)
	var is_faceup: bool = payload.get("card_is_faceup", false) as bool
	var card_idx: int = payload.get("card_index", -1) as int
	var arr: Array = ship.faceup_damage if is_faceup else ship.facedown_damage
	var card: DamageCard = arr[card_idx]
	ship.remove_damage_card(card)
	if game_state.damage_deck:
		game_state.damage_deck.discard(card)
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	return {
		"action_type": "repair_hull",
		"card_title": card.title,
		"card_is_faceup": is_faceup,
		"new_hull": new_hull,
	}


# ---------------------------------------------------------------------------
# Private — lookup
# ---------------------------------------------------------------------------

## Finds the ship referenced by payload's owner_player + ship_index.
func _find_ship(game_state: GameState) -> ShipInstance:
	var owner: int = payload.get("owner_player", -1) as int
	var idx: int = payload.get("ship_index", -1) as int
	if owner < 0 or owner >= game_state.player_states.size():
		return null
	var ps: PlayerState = game_state.get_player_state(owner)
	if ps == null or idx < 0 or idx >= ps.ships.size():
		return null
	return ps.ships[idx]

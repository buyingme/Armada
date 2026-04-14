## SetSpeedCommand
##
## Atomically sets a ship's current speed during the Navigate step of
## the Ship Phase.  The presentation layer (ManeuverToolScene /
## ShipActivationState) handles budget tracking and validation;
## this command owns the [code]ShipInstance.current_speed[/code] mutation
## so replay and network peers stay in sync.
##
## Payload:
##   [code]ship_index[/code]  — int — index in the player's fleet
##   [code]new_speed[/code]   — int — target speed (already budget-validated)
##
## Rules Reference: "Speed", p.12; NAV-002–NAV-005.
class_name SetSpeedCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("set_speed", func(
			player: int, pl: Dictionary) -> GameCommand:
		return SetSpeedCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "set_speed", p_payload)


## Validates that the speed change is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	if not payload.has("ship_index"):
		return "Missing ship_index."
	if not payload.has("new_speed"):
		return "Missing new_speed."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	var new_speed: int = int(payload.get("new_speed", -1))
	if new_speed < 0 or new_speed > ship.ship_data.max_speed:
		return "Speed %d out of bounds [0, %d]." % [
				new_speed, ship.ship_data.max_speed]
	return ""


## Sets the ship's speed and returns the old and new values.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var old_speed: int = ship.current_speed
	var new_speed: int = int(payload.get("new_speed", -1))
	ship.set_speed(new_speed)
	return {
		"ship_index": payload.get("ship_index", -1),
		"old_speed": old_speed,
		"new_speed": ship.current_speed,
	}

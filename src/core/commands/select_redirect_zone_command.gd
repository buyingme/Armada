## SelectRedirectZoneCommand
##
## Redirects one point of damage to an adjacent hull zone during the
## Spend Defense Tokens step of the attack sequence.
##
## Payload:
##   "ship_index" — index of the defending ship in the player's fleet.
##   "zone"       — [Constants.HullZone] int value of the target zone.
##
## Rules Reference: "Redirect", p.12 —
## "The defender chooses one of its hull zones adjacent to the defending
##  hull zone and suffers one or more damage on that zone."
class_name SelectRedirectZoneCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("select_redirect_zone", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SelectRedirectZoneCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "select_redirect_zone", p_payload)


## Validates that the redirect selection is legal.
## Whether redirect is actually available (token spent, remaining redirects)
## is validated by [AttackExecutor] before submitting.
## Allowed in both Ship and Squadron phases (redirect applies to all attacks).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	var zone: int = payload.get("zone", -1)
	if zone < 0 or zone > Constants.HullZone.REAR:
		return "Invalid hull zone."
	return ""


## Reduces shields in the selected hull zone by 1.
## Returns {"zone": int, "zone_name": String, "shields_reduced": int,
## "new_shields": int, "ship_index": int}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var zone: int = payload.get("zone", 0)
	var zone_str: String = Constants.hull_zone_to_string(
			zone as Constants.HullZone)
	var reduced: int = ship.reduce_shields(zone_str, 1)
	var new_shields: int = int(ship.current_shields.get(zone_str, 0))
	return {
		"zone": zone,
		"zone_name": zone_str,
		"shields_reduced": reduced,
		"new_shields": new_shields,
		"ship_index": payload.get("ship_index", -1),
	}

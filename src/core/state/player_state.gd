## Player State
##
## Represents all state data for a single player in an Armada game.
## Includes fleet composition, score, and token tracking.
class_name PlayerState
extends RefCounted


## The player index (0 or 1).
var player_index: int = 0

## The player's faction.
var faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE

## The total fleet point cost.
var fleet_points: int = 0

## The player's current score (victory points).
var score: int = 0

## The ships in this player's fleet (array of ship references).
var ships: Array = []

## The squadrons in this player's fleet.
var squadrons: Array = []

## The player's remaining command tokens.
var command_tokens: Array = []


## Serializes the player state to a dictionary.
## Includes ships and squadrons if present.
func serialize() -> Dictionary:
	var ships_data: Array[Dictionary] = []
	for ship: Variant in ships:
		if ship is ShipInstance:
			ships_data.append((ship as ShipInstance).serialize())
	var squads_data: Array[Dictionary] = []
	for squad: Variant in squadrons:
		if squad is SquadronInstance:
			squads_data.append((squad as SquadronInstance).serialize())
	return {
		"player_index": player_index,
		"faction": int(faction),
		"fleet_points": fleet_points,
		"score": score,
		"ships": ships_data,
		"squadrons": squads_data,
	}


## Deserializes a player state from a dictionary.
## Restores scalar fields and rebuilds the ship/squadron arrays from
## their serialized sub-dictionaries via [AssetLoader] template look-ups
## (Phase J2). Ships/squadrons whose [code]data_key[/code] cannot be
## resolved are skipped and a warning is pushed.
static func deserialize(data: Dictionary) -> PlayerState:
	var state := PlayerState.new()
	state.player_index = data.get("player_index", 0)
	state.faction = int(data.get("faction", 0)) as Constants.Faction
	state.fleet_points = data.get("fleet_points", 0)
	state.score = data.get("score", 0)
	for ship_data: Variant in data.get("ships", []):
		var sd: Dictionary = ship_data as Dictionary
		var key: String = sd.get("data_key", "") as String
		if key.is_empty():
			continue
		var template: ShipData = AssetLoader.load_ship_data(key)
		if template == null:
			push_warning("PlayerState.deserialize: ship template not found for '%s'" % key)
			continue
		state.ships.append(ShipInstance.deserialize(sd, template))
	for squad_data: Variant in data.get("squadrons", []):
		var sd: Dictionary = squad_data as Dictionary
		var key: String = sd.get("data_key", "") as String
		if key.is_empty():
			continue
		var template: SquadronData = AssetLoader.load_squadron_data(key)
		if template == null:
			push_warning("PlayerState.deserialize: squadron template not found for '%s'" % key)
			continue
		state.squadrons.append(SquadronInstance.deserialize(sd, template))
	return state

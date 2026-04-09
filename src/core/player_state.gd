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
## Ship and squadron instances require their static data templates, so
## deserialization populates only scalar fields. The caller must
## reconstruct ship/squadron arrays separately using the "ships" and
## "squadrons" sub-arrays and the appropriate template look-ups.
static func deserialize(data: Dictionary) -> PlayerState:
	var state := PlayerState.new()
	state.player_index = data.get("player_index", 0)
	state.faction = int(data.get("faction", 0)) as Constants.Faction
	state.fleet_points = data.get("fleet_points", 0)
	state.score = data.get("score", 0)
	return state

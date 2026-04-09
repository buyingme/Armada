## Game State
##
## Represents the complete state of an Armada game at any point in time.
## Holds all mutable game data: round number, phase, player states, etc.
## Designed to be serializable for save/load functionality.
class_name GameState
extends RefCounted


## The current round number (1-based, max defined by Constants.MAX_ROUNDS).
var current_round: int = 0

## The current game phase.
var current_phase: Constants.GamePhase = Constants.GamePhase.SETUP

## Player states indexed by player number (0 and 1).
var player_states: Array[PlayerState] = []

## The initiative player index (0 or 1).
var initiative_player: int = 0

## The selected objective cards for this game.
var objectives: Dictionary = {}

## Central registry for all active gameplay effects (keywords, upgrades, etc.).
## Created on [method initialize]; lives here so it travels with the game state.
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
var effect_registry: EffectRegistry = null

## The shared damage deck for this game.
## Set by the scenario setup code; used by RepairResolver and destruction cleanup.
## Rules Reference: DM-001 — shared 52-card deck.
var damage_deck: DamageDeck = null


## Initializes a new game state with default values.
func initialize() -> void:
	current_round = 0
	current_phase = Constants.GamePhase.SETUP
	initiative_player = 0
	effect_registry = EffectRegistry.new()
	player_states.clear()
	for i in range(Constants.PLAYER_COUNT):
		var ps := PlayerState.new()
		ps.player_index = i
		player_states.append(ps)


## Returns the state for the given player index.
func get_player_state(player_index: int) -> PlayerState:
	if player_index >= 0 and player_index < player_states.size():
		return player_states[player_index]
	push_error("Invalid player index: %d" % player_index)
	return null


## Returns the state for the player who has initiative.
func get_initiative_player_state() -> PlayerState:
	return get_player_state(initiative_player)


## Returns the state for the player who does not have initiative.
func get_non_initiative_player_state() -> PlayerState:
	return get_player_state(1 - initiative_player)


## Serializes the game state to a dictionary for saving.
func serialize() -> Dictionary:
	var data := {
		"current_round": current_round,
		"current_phase": int(current_phase),
		"initiative_player": initiative_player,
		"player_states": [],
		"damage_deck": damage_deck.serialize() if damage_deck else {},
	}
	for ps in player_states:
		data["player_states"].append(ps.serialize())
	return data


## Deserializes a game state from a saved dictionary.
## Ship/squadron reconstruction inside each PlayerState is left to the
## caller because it requires template look-ups (ShipData / SquadronData).
static func deserialize(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.current_round = data.get("current_round", 0)
	state.current_phase = int(data.get("current_phase", 0)) as Constants.GamePhase
	state.initiative_player = data.get("initiative_player", 0)
	for ps_data in data.get("player_states", []):
		state.player_states.append(PlayerState.deserialize(ps_data))
	var deck_data: Dictionary = data.get("damage_deck", {})
	if not deck_data.is_empty():
		state.damage_deck = DamageDeck.deserialize(deck_data)
	return state

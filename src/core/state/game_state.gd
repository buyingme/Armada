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

## The shared damage deck for this game.
## Set by the scenario setup code; used by RepairResolver and destruction cleanup.
## Rules Reference: DM-001 — shared 52-card deck.
var damage_deck: DamageDeck = null

## Seeded random-number generator shared across all game mechanics.
## Ensures deterministic replay when the same seed is used.
var rng: GameRng = null

## Active interactive UI flow (Phase I).
## Mutated only inside [GameCommand.execute()].  Always non-null after
## [method initialize].  See [code]docs/refactoring_phase_i_plan.md[/code].
var interaction_flow: InteractionFlow = InteractionFlow.new()

## Per-round count of ship-targeting attacks performed by each ship.
## Keys are `round:owner_player:ship_index`; values are ints.
## Used by Coolant Discharge and serialized for save/replay determinism.
var ship_target_attack_counts: Dictionary = {}


## Initializes a new game state with default values.
func initialize() -> void:
	current_round = 0
	current_phase = Constants.GamePhase.SETUP
	initiative_player = 0
	if rng == null:
		rng = GameRng.new()
	interaction_flow = InteractionFlow.new()
	ship_target_attack_counts.clear()
	player_states.clear()
	for player_index: int in range(Constants.PLAYER_COUNT):
		var ps := PlayerState.new()
		ps.player_index = player_index
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


## Returns the ship at [param ship_index] in [param player_index]'s fleet,
## or null if out of range.
func get_ship(player_index: int, ship_index: int) -> ShipInstance:
	var ps: PlayerState = get_player_state(player_index)
	if ps == null:
		return null
	if ship_index < 0 or ship_index >= ps.ships.size():
		return null
	return ps.ships[ship_index] as ShipInstance


## Returns the index of [param ship] in its owner's fleet, or -1.
func find_ship_index(ship: ShipInstance) -> int:
	var ps: PlayerState = get_player_state(ship.owner_player)
	if ps == null:
		return -1
	return ps.ships.find(ship)


## Returns the index of [param squadron] in its owner's fleet, or -1.
func find_squadron_index(squadron: SquadronInstance) -> int:
	var ps: PlayerState = get_player_state(squadron.owner_player)
	if ps == null:
		return -1
	return ps.squadrons.find(squadron)


## Returns the squadron at [param squadron_index] in
## [param player_index]'s fleet, or null if out of range.
func get_squadron(player_index: int,
		squadron_index: int) -> SquadronInstance:
	var ps: PlayerState = get_player_state(player_index)
	if ps == null:
		return null
	if squadron_index < 0 or squadron_index >= ps.squadrons.size():
		return null
	return ps.squadrons[squadron_index] as SquadronInstance


## Records one ship-targeting attack for [param ship] in the current round.
func record_ship_target_attack(ship: ShipInstance) -> void:
	var key: String = _ship_target_attack_key(ship)
	if key == "":
		return
	ship_target_attack_counts[key] = get_ship_target_attack_count(ship) + 1


## Returns how many ship-targeting attacks [param ship] made this round.
func get_ship_target_attack_count(ship: ShipInstance) -> int:
	var key: String = _ship_target_attack_key(ship)
	if key == "":
		return 0
	return int(ship_target_attack_counts.get(key, 0))


func _ship_target_attack_key(ship: ShipInstance) -> String:
	if ship == null:
		return ""
	var ship_index: int = find_ship_index(ship)
	if ship_index < 0:
		return ""
	return _ship_target_attack_key_for(
			current_round, ship.owner_player, ship_index)


static func _ship_target_attack_key_for(round_number: int,
		owner_player: int, ship_index: int) -> String:
	return "%d:%d:%d" % [round_number, owner_player, ship_index]


## Serializes the game state to a dictionary for saving.
func serialize() -> Dictionary:
	var data := {
		"current_round": current_round,
		"current_phase": int(current_phase),
		"initiative_player": initiative_player,
		"player_states": [],
		"damage_deck": damage_deck.serialize() if damage_deck else {},
		"rng": rng.serialize() if rng else {},
		"interaction_flow": interaction_flow.serialize() if interaction_flow else {},
		"ship_target_attack_counts": ship_target_attack_counts.duplicate(true),
	}
	for player_state: PlayerState in player_states:
		data["player_states"].append(player_state.serialize())
	return data


## Deserializes a game state from a saved dictionary.
## Ship/squadron reconstruction inside each PlayerState is left to the
## caller because it requires template look-ups (ShipData / SquadronData).
static func deserialize(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.current_round = data.get("current_round", 0)
	state.current_phase = int(data.get("current_phase", 0)) as Constants.GamePhase
	state.initiative_player = data.get("initiative_player", 0)
	for player_state_data: Variant in data.get("player_states", []):
		state.player_states.append(PlayerState.deserialize(player_state_data))
	state.ship_target_attack_counts = _deserialize_attack_counts(
			data.get("ship_target_attack_counts", {}))
	var deck_data: Dictionary = data.get("damage_deck", {})
	if not deck_data.is_empty():
		state.damage_deck = DamageDeck.deserialize(deck_data)
	var rng_data: Dictionary = data.get("rng", {})
	if not rng_data.is_empty():
		state.rng = GameRng.deserialize(rng_data)
	var flow_data: Dictionary = data.get("interaction_flow", {})
	if not flow_data.is_empty():
		state.interaction_flow = InteractionFlow.deserialize(flow_data)
	else:
		state.interaction_flow = InteractionFlow.new()
	return state


static func _deserialize_attack_counts(raw_counts: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if not raw_counts is Dictionary:
		return counts
	var saved_counts: Dictionary = raw_counts as Dictionary
	for raw_key: Variant in saved_counts.keys():
		counts[str(raw_key)] = int(saved_counts[raw_key])
	return counts

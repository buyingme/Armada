## Filters serialized GameState to remove hidden information for a specific player.
##
## Used by the server before sending state to clients.  Each player receives
## a view of the game that omits secrets belonging to the opponent, the RNG,
## and the damage deck draw order.
##
## Information Hiding rules (G4 Network Plan §1.4):
## - RNG seed/state: server-only, never sent to any client
## - Damage deck draw pile: server-only; clients see draw_count only
## - Damage deck discard pile: public (faceup cards)
## - Facedown command dials: owning player sees command type; opponent sees count only
## - Facedown damage cards: owning player sees card data; opponent sees count only
## - All other fields: public
class_name StateFilter
extends RefCounted


## Returns a filtered deep-copy of [param state_data] safe for [param player_index].
## The original dictionary is never mutated.
static func filter_for_player(state_data: Dictionary, player_index: int) -> Dictionary:
	var filtered: Dictionary = state_data.duplicate(true)

	# 1. Strip RNG — server-only
	filtered.erase("rng")

	# 2. Filter damage deck — strip draw pile, keep discard
	var deck_data: Dictionary = filtered.get("damage_deck", {})
	if not deck_data.is_empty():
		filtered["damage_deck"] = _filter_damage_deck(deck_data)

	# 3. Filter each player state — strip opponent's secrets
	var player_states: Array = filtered.get("player_states", [])
	for i: int in player_states.size():
		var ps: Dictionary = player_states[i]
		var is_owner: bool = (ps.get("player_index", -1) == player_index)
		player_states[i] = _filter_player_state(ps, is_owner)

	return filtered


## Replaces draw_pile with draw_count; keeps discard_pile intact.
static func _filter_damage_deck(deck_data: Dictionary) -> Dictionary:
	return {
		"draw_count": (deck_data.get("draw_pile", []) as Array).size(),
		"discard_pile": deck_data.get("discard_pile", []),
	}


## Owner sees everything; opponent's ships get filtered.
static func _filter_player_state(ps_data: Dictionary, is_owner: bool) -> Dictionary:
	if is_owner:
		return ps_data
	var filtered: Dictionary = ps_data.duplicate(true)
	var ships: Array = filtered.get("ships", [])
	for i: int in ships.size():
		ships[i] = _filter_opponent_ship(ships[i])
	return filtered


## Strips hidden information from an opponent's ship:
## - facedown_damage → facedown_count (int)
## - command_dial_stack hidden dials → command field removed
static func _filter_opponent_ship(ship_data: Dictionary) -> Dictionary:
	var filtered: Dictionary = ship_data.duplicate(true)

	# Facedown damage: replace card array with count
	var facedown: Array = filtered.get("facedown_damage", [])
	filtered["facedown_count"] = facedown.size()
	filtered.erase("facedown_damage")

	# Command dial stack: strip hidden dial commands
	var dial_data: Dictionary = filtered.get("command_dial_stack", {})
	if not dial_data.is_empty():
		filtered["command_dial_stack"] = _filter_opponent_dials(dial_data)

	return filtered


## Strips the command type from hidden dials; revealed/spent dials pass through.
static func _filter_opponent_dials(dial_data: Dictionary) -> Dictionary:
	var filtered: Dictionary = dial_data.duplicate(true)
	var dials: Array = filtered.get("dials", [])
	for i: int in dials.size():
		var dial: Dictionary = dials[i]
		if dial.get("state", "") == CommandDialStack.STATE_HIDDEN:
			dials[i] = {"round": dial.get("round", 0), "state": CommandDialStack.STATE_HIDDEN}
	return filtered

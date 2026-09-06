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


const KEY_OK: String = "ok"
const KEY_STATE: String = "state"
const KEY_REASON: String = "reason"


## Returns a filtered deep-copy of [param state_data] safe for [param player_index].
## The original dictionary is never mutated.
static func filter_for_player(state_data: Dictionary, player_index: int) -> Dictionary:
	var result: Dictionary = filter_for_player_checked(state_data, player_index)
	if not bool(result.get(KEY_OK, false)):
		return {}
	return (result.get(KEY_STATE, {}) as Dictionary).duplicate(true)


## Fail-closed production boundary with a clear local diagnostic. Callers must
## inspect `ok` before sending the returned state; a failed result never carries
## a transmissible snapshot.
static func filter_for_player_checked(
		state_data: Dictionary, player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
		return _failure("Network state filtering requires a valid viewer player.")
	if state_data.has("passive_damage_ledger") \
			or not state_data.has("damage_deck") \
			or not state_data.has("rng"):
		return _failure("Network state filtering requires a full-authority representation.")
	var authority: GameState = GameState.deserialize(state_data)
	if authority == null or not authority.validate_for_full_authority_installation():
		return _failure("Network state filtering rejected an invalid authority state.")
	var identity_error: String = authority.stable_ship_identity_error()
	if not identity_error.is_empty():
		return _failure(identity_error)
	var filtered: Dictionary = authority.serialize()

	# 1. Strip RNG — server-only
	filtered.erase("rng")

	# 2. Replace the full deck and all facedown identities with one ledger.
	var deck_data: Dictionary = filtered.get("damage_deck", {})
	if deck_data.is_empty() or not deck_data.get("draw_pile", []) is Array \
			or not deck_data.get("discard_pile", []) is Array:
		return _failure("Network state filtering rejected an invalid damage deck.")
	var counts: Dictionary = {}
	var seen_keys: Dictionary = {}

	# 3. Filter each player state — strip opponent's secrets
	var player_states: Array = filtered.get("player_states", [])
	for i: int in player_states.size():
		var ps: Dictionary = player_states[i]
		var is_owner: bool = (ps.get("player_index", -1) == player_index)
		var player_id: int = int(ps.get("player_index", -1))
		var ships: Array = ps.get("ships", [])
		for ship_index: int in ships.size():
			var ship: Dictionary = ships[ship_index]
			var roster_id: String = str(ship.get("roster_entry_id", ""))
			var key: String = PassiveDamageLedger.ship_key(player_id, roster_id)
			if roster_id.is_empty() or seen_keys.has(key) \
					or not ship.get("facedown_damage", []) is Array:
				return _failure("Network state filtering rejected unstable ship damage identity.")
			seen_keys[key] = true
			counts[key] = (ship.get("facedown_damage", []) as Array).size()
		player_states[i] = _filter_player_state(ps, is_owner)
	filtered.erase("damage_deck")
	filtered["passive_damage_ledger"] = {
		"schema_version": PassiveDamageLedger.SCHEMA_VERSION,
		"draw_count": (deck_data.get("draw_pile", []) as Array).size(),
		"discard_pile": (deck_data.get("discard_pile", []) as Array).duplicate(true),
		"facedown_counts": counts,
	}

	# 4. Filter interaction_flow — strip payload when not visible to viewer
	var flow_data: Dictionary = filtered.get("interaction_flow", {})
	if not flow_data.is_empty():
		filtered["interaction_flow"] = _filter_interaction_flow(
				flow_data, player_index)

	return {KEY_OK: true, KEY_STATE: filtered, KEY_REASON: ""}


static func _failure(reason: String) -> Dictionary:
	return {KEY_OK: false, KEY_STATE: {}, KEY_REASON: reason}


## Replaces draw_pile with draw_count; keeps discard_pile intact.
## Owner sees everything; opponent's ships get filtered.
static func _filter_player_state(ps_data: Dictionary, is_owner: bool) -> Dictionary:
	var filtered: Dictionary = ps_data.duplicate(true)
	var ships: Array = filtered.get("ships", [])
	for i: int in ships.size():
		ships[i] = _filter_ship(ships[i])
	if not is_owner:
		var dial_filtered: Array = filtered.get("ships", [])
		for i: int in dial_filtered.size():
			var ship: Dictionary = dial_filtered[i]
			var dial_data: Dictionary = ship.get("command_dial_stack", {})
			if not dial_data.is_empty():
				ship["command_dial_stack"] = _filter_opponent_dials(dial_data)
	return filtered


## Strips hidden information from an opponent's ship:
## - facedown_damage → facedown_count (int)
## - command_dial_stack hidden dials → command field removed
static func _filter_ship(ship_data: Dictionary) -> Dictionary:
	var filtered: Dictionary = ship_data.duplicate(true)

	# Facedown damage: replace card array with count
	var facedown: Array = filtered.get("facedown_damage", [])
	filtered["facedown_count"] = facedown.size()
	filtered.erase("facedown_damage")

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


## Filters [member InteractionFlow] for [param player_index].
##
## Strips [code]payload[/code] when [code]visible_to == OWNER[/code] and the
## viewer is not the controller.  Public flows (visible_to == ALL) pass through.
## See [code].skills/architecture_patterns.md[/code] §5.
static func _filter_interaction_flow(flow_data: Dictionary,
		player_index: int) -> Dictionary:
	var filtered: Dictionary = flow_data.duplicate(true)
	var visible_to: int = int(filtered.get("visible_to", 0))
	var controller: int = int(filtered.get("controller_player", -1))
	if visible_to == int(Constants.Visibility.OWNER) and controller != player_index:
		filtered["payload"] = {}
	return filtered

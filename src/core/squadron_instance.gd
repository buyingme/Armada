## SquadronInstance
##
## Runtime state for a single squadron during a game. Tracks mutable values:
## current hull (hit points remaining), activation status, and engagement.
##
## Created from a [SquadronData] template at game start.
##
## Rules Reference: "Squadron Components", p.3; SU-024–025.
class_name SquadronInstance
extends RefCounted


## The data-key used to look up the squadron's static data and token PNG.
var data_key: String = ""

## The static template this instance was created from.
var squadron_data: SquadronData = null

## Current hull hit points remaining. Starts at [SquadronData.hull].
## Rules Reference: SU-024 — squadron disks set to maximum hull points.
var current_hull: int = 0

## Whether this squadron has been activated this round.
## Rules Reference: SU-025 — activation sliders display the blue (unactivated) side.
var activated_this_round: bool = false

## Whether this squadron is currently engaged (adjacent to enemy squadron).
## Rules Reference: "Engagement", p.4 — engaged squadrons cannot move.
var is_engaged: bool = false

## The player index that controls this squadron (0 or 1).
var owner_player: int = 0

## Permanent destruction flag. Once set via [method mark_destroyed], the
## squadron remains destroyed even if hull is later manipulated.
## Rules Reference: "Squadrons", p.14.
var _destroyed: bool = false

## Defense tokens with their current states (for unique squadrons).
## Array of dictionaries: {"type": Constants.DefenseToken, "state": Constants.DefenseTokenState}
var defense_tokens: Array[Dictionary] = []


## Creates a SquadronInstance from a [SquadronData] template and a data key.
## Hull starts at max. Activation starts unactivated.
## [param key] — the snake_case identifier (e.g. "x_wing_squadron").
## [param data] — the static squadron data template.
## [param player] — the owning player index.
## Rules Reference: SU-024–025.
static func create_from_data(
		key: String, data: SquadronData,
		player: int) -> SquadronInstance:
	var inst: SquadronInstance = SquadronInstance.new()
	inst.data_key = key
	inst.squadron_data = data
	inst.current_hull = data.hull
	inst.owner_player = player
	inst._init_defense_tokens(data)
	return inst


## Returns true if this squadron is destroyed (hull <= 0 or
## [method mark_destroyed] was called).
func is_destroyed() -> bool:
	return _destroyed or current_hull <= 0


## Permanently marks this squadron as destroyed.
## Rules Reference: "Squadrons", p.14.
func mark_destroyed() -> void:
	_destroyed = true


## Suffers [amount] damage, reducing hull. Returns actual damage dealt.
## Rules Reference: squadrons have no shields, damage goes directly to hull.
func suffer_damage(amount: int) -> int:
	var actual: int = mini(amount, current_hull)
	current_hull -= actual
	return actual


## Resets the activated flag for a new round.
func reset_activation() -> void:
	activated_this_round = false


## Returns the number of non-discarded defense tokens.
func get_active_token_count() -> int:
	var count: int = 0
	for token: Dictionary in defense_tokens:
		if token["state"] != Constants.DefenseTokenState.DISCARDED:
			count += 1
	return count


## Readies all non-discarded defense tokens (Status Phase).
## Rules Reference: "Status Phase", p.6.
func ready_defense_tokens() -> void:
	for token: Dictionary in defense_tokens:
		if token["state"] == Constants.DefenseTokenState.EXHAUSTED:
			token["state"] = Constants.DefenseTokenState.READY


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Initialises defense tokens from squadron data (unique squadrons only).
func _init_defense_tokens(data: SquadronData) -> void:
	defense_tokens = []
	for token_name: Variant in data.defense_tokens:
		var token_type: Constants.DefenseToken = _parse_defense_token(
				str(token_name))
		defense_tokens.append({
			"type": token_type,
			"state": Constants.DefenseTokenState.READY,
		})


## Parses a defense token string name into the enum value.
static func _parse_defense_token(name: String) -> Constants.DefenseToken:
	match name.to_upper():
		"EVADE":
			return Constants.DefenseToken.EVADE
		"REDIRECT":
			return Constants.DefenseToken.REDIRECT
		"BRACE":
			return Constants.DefenseToken.BRACE
		"SCATTER":
			return Constants.DefenseToken.SCATTER
		"CONTAIN":
			return Constants.DefenseToken.CONTAIN
		"SALVO":
			return Constants.DefenseToken.SALVO
		_:
			push_error("SquadronInstance: unknown defense token '%s'" % name)
			return Constants.DefenseToken.EVADE

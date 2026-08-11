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


const ACTIVATION_CONTEXT_INACTIVE: String = ""
const ACTIVATION_CONTEXT_SQUADRON_PHASE: String = "squadron_phase"
const ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND: String = \
		"ship_squadron_command"

const ATTACK_ACTION_INACTIVE: String = ""
const ATTACK_ACTION_AVAILABLE: String = "available"
const ATTACK_ACTION_BEGUN: String = "begun"
const ATTACK_ACTION_DECLINED: String = "declined"


## The data-key used to look up the squadron's static data and token PNG.
var data_key: String = ""

## Stable roster-local entry id used by setup/deployment package mappings.
var roster_entry_id: String = ""

## The static template this instance was created from.
var squadron_data: SquadronData = null

## Fleet-point value represented by this runtime squadron.
var fleet_points: int = 0

## Current hull hit points remaining. Starts at [SquadronData.hull].
## Rules Reference: SU-024 — squadron disks set to maximum hull points.
var current_hull: int = 0

## Whether this squadron has been activated this round.
## Rules Reference: SU-025 — activation sliders display the blue (unactivated) side.
var activated_this_round: bool = false

## Behavior-inert owner-local action history for one retained activation.
## These fields intentionally remain outside serialization and live commands
## until the authoritative declaration cutover.
var activation_id: String = ""
var activation_context: String = ACTIVATION_CONTEXT_INACTIVE
var commanding_ship_player: int = -1
var commanding_ship_index: int = -1
var move_action_committed: bool = false
var attack_action_disposition: String = ATTACK_ACTION_INACTIVE

## Whether this squadron is currently engaged (adjacent to enemy squadron).
## Rules Reference: "Engagement", p.4 — engaged squadrons cannot move.
var is_engaged: bool = false

## The player index that controls this squadron (0 or 1).
var owner_player: int = 0

## Normalised X position on the play area (0.0 = left, 1.0 = right).
## Matches the coordinate system of [code]learning_scenario.json[/code]
## and [TokenPlacement]. Updated by [MoveSquadronCommand].
var pos_x: float = 0.0

## Normalised Y position on the play area (0.0 = top, 1.0 = bottom).
var pos_y: float = 0.0

## Rotation in degrees (0 = facing up / -Y, 180 = facing down / +Y).
## Matches the [code]rotation_deg[/code] key in scenario JSON.
var rotation_deg: float = 0.0

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
	inst.fleet_points = data.point_cost
	inst.current_hull = data.hull
	inst.owner_player = player
	inst._init_defense_tokens(data)
	return inst


## Returns the normalised position as a [Vector2].
## Matches [method TokenPlacement.get_normalised_position].
func get_normalised_position() -> Vector2:
	return Vector2(pos_x, pos_y)


## Returns the pixel position within a play area of the given dimensions.
## [param play_area_size] — Vector2(width_px, height_px).
## Matches [method TokenPlacement.get_pixel_position].
func get_pixel_position(play_area_size: Vector2) -> Vector2:
	return get_normalised_position() * play_area_size


## Returns the rotation in radians (for Node2D.rotation).
func get_rotation_rad() -> float:
	return deg_to_rad(rotation_deg)


## Returns true if this squadron is destroyed (hull <= 0 or
## [method mark_destroyed] was called).
## A squadron without data (used in tests) is never considered destroyed
## by the hull check — only the explicit [code]_destroyed[/code] flag
## applies.
func is_destroyed() -> bool:
	if _destroyed:
		return true
	if squadron_data == null:
		return false
	return current_hull <= 0


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


## Returns whether retained canonical action history exists.
func has_activation_action_state() -> bool:
	return not activation_id.is_empty()


## Initializes one owner-local action history without consulting flow or UI.
func initialize_activation_action_state(identity: String, context: String,
		ship_player: int = -1, ship_index: int = -1) -> bool:
	if not is_activation_action_state_valid() or has_activation_action_state():
		return false
	if not _activation_action_values_are_valid(
			identity, context, ship_player, ship_index,
			false, ATTACK_ACTION_AVAILABLE):
		return false
	activation_id = identity
	activation_context = context
	commanding_ship_player = ship_player
	commanding_ship_index = ship_index
	move_action_committed = false
	attack_action_disposition = ATTACK_ACTION_AVAILABLE
	return true


## Validates the complete owner-local activation/action representation.
func is_activation_action_state_valid() -> bool:
	return _activation_action_values_are_valid(
			activation_id, activation_context,
			commanding_ship_player, commanding_ship_index,
			move_action_committed, attack_action_disposition)


## Commits movement once for the matching retained activation identity.
func commit_move_action(
		expected_activation_id: String, is_rogue: bool) -> bool:
	if not _matches_activation_action(expected_activation_id) \
			or not has_remaining_move_action(is_rogue):
		return false
	move_action_committed = true
	return true


## Commits accepted Begin to the available attack disposition.
func commit_attack_action_begun(
		expected_activation_id: String, is_rogue: bool) -> bool:
	return _commit_attack_action_disposition(
			expected_activation_id, is_rogue, ATTACK_ACTION_BEGUN)


## Commits accepted declaration Skip to the available attack disposition.
func commit_attack_action_declined(
		expected_activation_id: String, is_rogue: bool) -> bool:
	return _commit_attack_action_disposition(
			expected_activation_id, is_rogue, ATTACK_ACTION_DECLINED)


## Derives movement availability from owner facts plus the caller-supplied
## Rogue/static-rule input. No remaining-action fact is stored.
func has_remaining_move_action(is_rogue: bool) -> bool:
	if not is_activation_action_state_valid() \
			or not has_activation_action_state() \
			or activated_this_round \
			or move_action_committed:
		return false
	if activation_context == ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return true
	return is_rogue or attack_action_disposition == ATTACK_ACTION_AVAILABLE


## Derives attack availability from owner facts plus the caller-supplied
## Rogue/static-rule input. No remaining-action fact is stored.
func has_remaining_attack_action(is_rogue: bool) -> bool:
	if not is_activation_action_state_valid() \
			or not has_activation_action_state() \
			or activated_this_round \
			or attack_action_disposition != ATTACK_ACTION_AVAILABLE:
		return false
	if activation_context == ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return true
	return is_rogue or not move_action_committed


## Returns whether the retained action sequence has no action remaining.
func is_activation_action_complete(is_rogue: bool) -> bool:
	return has_activation_action_state() \
			and is_activation_action_state_valid() \
			and not has_remaining_move_action(is_rogue) \
			and not has_remaining_attack_action(is_rogue)


## Returns a JSON-safe snapshot for later atomic command rollback.
func activation_action_state_snapshot() -> Dictionary:
	return {
		"activation_id": activation_id,
		"activation_context": activation_context,
		"commanding_ship_player": commanding_ship_player,
		"commanding_ship_index": commanding_ship_index,
		"move_action_committed": move_action_committed,
		"attack_action_disposition": attack_action_disposition,
	}


## Restores a snapshot produced by [method activation_action_state_snapshot].
func restore_activation_action_state(snapshot: Dictionary) -> bool:
	for key: String in [
			"activation_id", "activation_context",
			"commanding_ship_player", "commanding_ship_index",
			"move_action_committed", "attack_action_disposition"]:
		if not snapshot.has(key):
			return false
	var identity: String = str(snapshot["activation_id"])
	var context: String = str(snapshot["activation_context"])
	var ship_player: int = int(snapshot["commanding_ship_player"])
	var ship_index: int = int(snapshot["commanding_ship_index"])
	var move_committed: bool = bool(snapshot["move_action_committed"])
	var attack_disposition: String = str(snapshot["attack_action_disposition"])
	if not _activation_action_values_are_valid(
			identity, context, ship_player, ship_index,
			move_committed, attack_disposition):
		return false
	activation_id = identity
	activation_context = context
	commanding_ship_player = ship_player
	commanding_ship_index = ship_index
	move_action_committed = move_committed
	attack_action_disposition = attack_disposition
	return true


## Clears only the new action-history substrate at its accepted reset boundary.
func reset_activation_action_state() -> void:
	activation_id = ""
	activation_context = ACTIVATION_CONTEXT_INACTIVE
	commanding_ship_player = -1
	commanding_ship_index = -1
	move_action_committed = false
	attack_action_disposition = ATTACK_ACTION_INACTIVE


## Returns the number of non-discarded defense tokens.
func get_active_token_count() -> int:
	var count: int = 0
	for token: Dictionary in defense_tokens:
		if token["state"] != Constants.DefenseTokenState.DISCARDED:
			count += 1
	return count


## Exhausts one ready defense token.
func exhaust_defense_token(index: int) -> void:
	if index < 0 or index >= defense_tokens.size():
		return
	if defense_tokens[index]["state"] == Constants.DefenseTokenState.READY:
		defense_tokens[index]["state"] = Constants.DefenseTokenState.EXHAUSTED


## Discards one defense token permanently.
func discard_defense_token(index: int) -> void:
	if index < 0 or index >= defense_tokens.size():
		return
	defense_tokens[index]["state"] = Constants.DefenseTokenState.DISCARDED


## Readies all non-discarded defense tokens (Status Phase).
## Rules Reference: "Status Phase", p.6.
func ready_defense_tokens() -> void:
	for token: Dictionary in defense_tokens:
		if token["state"] == Constants.DefenseTokenState.EXHAUSTED:
			token["state"] = Constants.DefenseTokenState.READY


func _commit_attack_action_disposition(
		expected_activation_id: String, is_rogue: bool,
		disposition: String) -> bool:
	if not _matches_activation_action(expected_activation_id) \
			or not has_remaining_attack_action(is_rogue):
		return false
	if disposition != ATTACK_ACTION_BEGUN \
			and disposition != ATTACK_ACTION_DECLINED:
		return false
	attack_action_disposition = disposition
	return true


func _matches_activation_action(expected_activation_id: String) -> bool:
	return not expected_activation_id.is_empty() \
			and activation_id == expected_activation_id \
			and is_activation_action_state_valid()


static func _activation_action_values_are_valid(identity: String,
		context: String, ship_player: int, ship_index: int,
		move_committed: bool, attack_disposition: String) -> bool:
	if identity.is_empty():
		return context == ACTIVATION_CONTEXT_INACTIVE \
				and ship_player == -1 \
				and ship_index == -1 \
				and not move_committed \
				and attack_disposition == ATTACK_ACTION_INACTIVE
	if context != ACTIVATION_CONTEXT_SQUADRON_PHASE \
			and context != ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return false
	if attack_disposition != ATTACK_ACTION_AVAILABLE \
			and attack_disposition != ATTACK_ACTION_BEGUN \
			and attack_disposition != ATTACK_ACTION_DECLINED:
		return false
	if context == ACTIVATION_CONTEXT_SQUADRON_PHASE:
		return ship_player == -1 and ship_index == -1
	return ship_player >= 0 \
			and ship_player < Constants.PLAYER_COUNT \
			and ship_index >= 0


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


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------


## Serializes this squadron's mutable runtime state to a dictionary.
## The static template ([member squadron_data]) is identified by
## [member data_key] and must be re-loaded on deserialization.
func serialize() -> Dictionary:
	var tokens: Array[Dictionary] = []
	for token: Dictionary in defense_tokens:
		tokens.append({
			"type": int(token["type"]),
			"state": int(token["state"]),
		})
	return {
		"data_key": data_key,
		"roster_entry_id": roster_entry_id,
		"fleet_points": fleet_points,
		"current_hull": current_hull,
		"activated_this_round": activated_this_round,
		"is_engaged": is_engaged,
		"owner_player": owner_player,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
		"destroyed": _destroyed,
		"defense_tokens": tokens,
	}


## Restores a SquadronInstance from a serialized dictionary.
## [param data] — the dictionary produced by [method serialize].
## [param squad_data_ref] — the static [SquadronData] template.
##     The caller must look up the template via [code]data["data_key"][/code].
static func deserialize(
		data: Dictionary,
		squad_data_ref: SquadronData) -> SquadronInstance:
	var inst: SquadronInstance = SquadronInstance.new()
	inst.data_key = data.get("data_key", "") as String
	inst.roster_entry_id = data.get("roster_entry_id", "") as String
	inst.fleet_points = int(data.get("fleet_points", 0))
	inst.squadron_data = squad_data_ref
	inst.current_hull = int(data.get("current_hull", 0))
	inst.activated_this_round = data.get(
			"activated_this_round", false) as bool
	inst.is_engaged = data.get("is_engaged", false) as bool
	inst.owner_player = int(data.get("owner_player", 0))
	inst.pos_x = float(data.get("pos_x", 0.0))
	inst.pos_y = float(data.get("pos_y", 0.0))
	inst.rotation_deg = float(data.get("rotation_deg", 0.0))
	inst._destroyed = data.get("destroyed", false) as bool
	for t: Variant in data.get("defense_tokens", []):
		var td: Dictionary = t as Dictionary
		inst.defense_tokens.append({
			"type": int(td["type"]) as Constants.DefenseToken,
			"state": int(td["state"]) as Constants.DefenseTokenState,
		})
	return inst

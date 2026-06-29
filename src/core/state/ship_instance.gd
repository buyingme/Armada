## ShipInstance
##
## Runtime state for a single ship during a game. Tracks mutable values that
## change during play: current shields per hull zone, current hull (remaining
## hit points), current speed, defense token states, command dial stack, and
## assigned damage cards.
##
## Created from a [ShipData] template at game start. The template's max values
## become the initial current values.
##
## Rules Reference: "Ship Components", p.3; SU-021–026; DM-001–003.
class_name ShipInstance
extends RefCounted


const RUNTIME_UPGRADE_REQUIRED_FIELDS: Array[String] = [
	"runtime_upgrade_id",
	"data_key",
	"owner_player_id",
	"source_ship_ref",
	"source_roster_entry_id",
	"source_assignment_id",
	"slot",
	"slot_index",
	"card_state",
	"trigger_guards",
	"rule_state",
]
const RUNTIME_UPGRADE_IDENTITY_FIELDS: Array[String] = [
	"runtime_upgrade_id",
	"data_key",
	"source_ship_ref",
	"source_roster_entry_id",
	"source_assignment_id",
]
const RUNTIME_UPGRADE_CARD_STATE_FIELDS: Array[String] = [
	"exhausted",
	"discarded",
	"disabled",
	"readied",
]

## The data-key used to look up the ship's static data and token PNG.
var data_key: String = ""

## Stable roster-local entry id used by setup/deployment package mappings.
var roster_entry_id: String = ""

## The static template this instance was created from.
var ship_data: ShipData = null

## Fleet-point value represented by this runtime ship, including assigned upgrades.
var fleet_points: int = 0

## Current shield values per hull zone. Initialised to max from [ShipData].
## Rules Reference: SU-022 — shields start at maximum.
var current_shields: Dictionary = {}

## Current hull hit points remaining. Starts at [ShipData.hull].
## When damage cards >= hull, the ship is destroyed (DM-003).
var current_hull: int = 0

## Current speed. In the Learning Scenario all ships start at speed 2 (SU-021).
## Rules Reference: SU-021, "Speed", p.12.
var current_speed: int = 0

## Normalised X position on the play area (0.0 = left, 1.0 = right).
## Matches the coordinate system of [code]learning_scenario.json[/code]
## and [TokenPlacement]. Updated by [ExecuteManeuverCommand].
var pos_x: float = 0.0

## Normalised Y position on the play area (0.0 = top, 1.0 = bottom).
var pos_y: float = 0.0

## Rotation in degrees (0 = facing up / -Y, 180 = facing down / +Y).
## Matches the [code]rotation_deg[/code] key in scenario JSON.
var rotation_deg: float = 0.0

## Defense tokens with their current states.
## Array of dictionaries: {"type": Constants.DefenseToken, "state": Constants.DefenseTokenState}
## Rules Reference: SU-026 — all tokens start READY.
var defense_tokens: Array[Dictionary] = []

## Facedown damage cards assigned to this ship. Each entry is a DamageCard.
## Rules Reference: DM-002, DM-006.
var facedown_damage: Array = []

## Faceup damage cards assigned to this ship. Each entry is a DamageCard.
## Rules Reference: DM-005.
var faceup_damage: Array = []

## Whether this ship has been activated this round.
## Rules Reference: SP-001 — each ship activates once per round.
var activated_this_round: bool = false

## The player index that controls this ship (0 or 1).
var owner_player: int = 0

## Permanent destruction flag. Once set via [method mark_destroyed], the ship
## remains destroyed even after damage cards are returned to the deck.
## Rules Reference: DM-003 — ship destroyed when damage cards >= hull.
var _destroyed: bool = false

## The command dial stack for this ship.
## Rules Reference: CP-001–007 — command dials per ship.
var command_dial_stack: CommandDialStack = null

## Command tokens held by this ship.
## Rules Reference: CM-004–006 — command token management.
var command_tokens: CommandTokenManager = null

## Runtime upgrade instances owned by this ship after setup.
## Static upgrade data is referenced by data_key; full catalog data is not copied.
var runtime_upgrades: Array[Dictionary] = []


## Creates a ShipInstance from a [ShipData] template and a data key.
## Shields start at max, hull starts at max, speed starts at [initial_speed]
## (Learning Scenario: 2), defense tokens start READY.
## [param key] — the snake_case identifier (e.g. "cr90_corvette_a").
## [param data] — the static ship data template.
## [param initial_speed] — the starting speed (SU-021: 2 for Learning Scenario).
## [param player] — the owning player index.
## Rules Reference: SU-021–026.
static func create_from_data(
		key: String, data: ShipData, initial_speed: int,
		player: int) -> ShipInstance:
	var inst: ShipInstance = ShipInstance.new()
	inst.data_key = key
	inst.ship_data = data
	inst.fleet_points = data.point_cost
	inst.current_hull = data.hull
	inst.current_speed = initial_speed
	inst.owner_player = player
	inst._init_shields(data)
	inst._init_defense_tokens(data)
	inst.command_dial_stack = CommandDialStack.create(data.command_value)
	inst.command_tokens = CommandTokenManager.create(data.command_value)
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


## Returns the total number of damage cards (facedown + faceup).
## Rules Reference: DM-003 — ship destroyed when total >= hull.
func get_total_damage() -> int:
	return facedown_damage.size() + faceup_damage.size()


## Returns the remaining hull points (max hull minus damage cards dealt).
## This is the computed "current hull" value; prefer this over the [current_hull]
## field which is only set at creation.
## Rules Reference: "Damage", p.4 — ship destroyed when cards >= hull.
func get_remaining_hull() -> int:
	return ship_data.hull - get_total_damage()


## Returns true if this ship is destroyed (damage >= hull value or
## [method mark_destroyed] was called).
## Rules Reference: DM-003.
func is_destroyed() -> bool:
	if _destroyed:
		return true
	if ship_data == null or ship_data.hull <= 0:
		return false
	return get_total_damage() >= ship_data.hull


## Permanently marks this ship as destroyed. Call this before emitting the
## [code]ship_destroyed[/code] signal so that handlers (scoring, elimination)
## always see a consistent state — even after [method clear_all_damage_cards]
## returns the cards to the deck.
## Rules Reference: DM-003.
func mark_destroyed() -> void:
	_destroyed = true


## Returns true if the ship has full hull (zero damage cards) and all
## shields are at their maximum values.  Used by the repair-skip logic to
## avoid showing an empty RepairPanel.
## Rules Reference: CM-030 — engineering command has no effect when there
## is nothing to repair.
func is_fully_healthy() -> bool:
	if get_total_damage() > 0:
		return false
	for zone: String in current_shields:
		if int(current_shields[zone]) < get_max_shields(zone):
			return false
	return true


## Returns the maximum shield value for the given hull zone from the template.
func get_max_shields(zone: String) -> int:
	return int(ship_data.shields.get(zone, 0))


## Reduces shields in the given hull zone by [amount], clamped to 0.
## Returns the actual amount reduced (may be less than requested).
## Rules Reference: DM-002 — shields absorb damage first.
func reduce_shields(zone: String, amount: int) -> int:
	var current: int = int(current_shields.get(zone, 0))
	var reduction: int = mini(current, amount)
	current_shields[zone] = current - reduction
	return reduction


## Adds a facedown damage card to this ship.
## Rules Reference: DM-002, DM-006, DM-007.
func add_facedown_damage(card: RefCounted) -> void:
	facedown_damage.append(card)


## Adds a faceup damage card (critical) to this ship.
## Rules Reference: DM-005.
func add_faceup_damage(card: RefCounted) -> void:
	faceup_damage.append(card)


## Removes a specific damage card from this ship's damage arrays.
## Searches faceup first, then facedown. Returns true if the card was found
## and removed. The caller is responsible for discarding the card back to
## the DamageDeck.
## Rules Reference: CM-035 — repair hull discards a damage card.
func remove_damage_card(card: RefCounted) -> bool:
	var idx: int = faceup_damage.find(card)
	if idx >= 0:
		faceup_damage.remove_at(idx)
		return true
	idx = facedown_damage.find(card)
	if idx >= 0:
		facedown_damage.remove_at(idx)
		return true
	return false


## Removes and returns ALL damage cards (facedown + faceup) from this ship.
## Used during destruction cleanup to return cards to the discard pile.
## Rules Reference: DM-030 — destroyed ships return their cards.
func clear_all_damage_cards() -> Array:
	var cards: Array = []
	cards.append_array(facedown_damage)
	cards.append_array(faceup_damage)
	facedown_damage.clear()
	faceup_damage.clear()
	return cards


## Restores shields in the given hull zone by [amount], clamped to max.
## Returns the actual amount restored.
## Rules Reference: "Engineering", repair shields.
func restore_shields(zone: String, amount: int) -> int:
	var current: int = int(current_shields.get(zone, 0))
	var max_val: int = get_max_shields(zone)
	var restoration: int = mini(amount, max_val - current)
	current_shields[zone] = current + restoration
	return restoration


## Sets the current speed, clamped to [0, max_speed].
## Rules Reference: "Speed", p.12 — speed cannot exceed max or go below 0.
func set_speed(new_speed: int) -> void:
	current_speed = clampi(new_speed, 0, ship_data.max_speed)


## Spends (exhausts) the defense token at the given index.
## Rules Reference: DT-001 — spending flips from READY to EXHAUSTED.
func exhaust_defense_token(index: int) -> void:
	if index < 0 or index >= defense_tokens.size():
		return
	if defense_tokens[index]["state"] == Constants.DefenseTokenState.READY:
		defense_tokens[index]["state"] = Constants.DefenseTokenState.EXHAUSTED


## Discards the defense token at the given index.
## Rules Reference: DT-002 — discarding removes it from play.
func discard_defense_token(index: int) -> void:
	if index < 0 or index >= defense_tokens.size():
		return
	defense_tokens[index]["state"] = Constants.DefenseTokenState.DISCARDED


## Readies all non-discarded defense tokens (Status Phase).
## Rules Reference: "Status Phase", p.6 — ready all exhausted tokens.
func ready_defense_tokens() -> void:
	for token: Dictionary in defense_tokens:
		if token["state"] == Constants.DefenseTokenState.EXHAUSTED:
			token["state"] = Constants.DefenseTokenState.READY


## Adds one equipped upgrade as a runtime upgrade instance on this ship.
## Returns the serialized runtime instance dictionary that was attached.
func add_runtime_upgrade(data_key_value: String, source_assignment_id: String,
		slot: String, slot_index: int) -> Dictionary:
	var runtime_upgrade: Dictionary = _build_runtime_upgrade_instance(
			owner_player, roster_entry_id, data_key_value,
			source_assignment_id, slot, slot_index)
	runtime_upgrades.append(runtime_upgrade)
	return runtime_upgrade


## Returns the runtime upgrade with [param runtime_upgrade_id], or an empty dictionary.
func get_runtime_upgrade(runtime_upgrade_id: String) -> Dictionary:
	var found: Dictionary = {}
	for runtime_upgrade: Dictionary in runtime_upgrades:
		if str(runtime_upgrade.get("runtime_upgrade_id", "")) != runtime_upgrade_id:
			continue
		if not found.is_empty():
			push_error("Duplicate runtime upgrade id: %s" % runtime_upgrade_id)
			return {}
		found = runtime_upgrade
	return found


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


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Initialises current_shields from the ship data template.
## Rules Reference: SU-022 — shields start at maximum.
func _init_shields(data: ShipData) -> void:
	current_shields = {}
	for zone: String in data.shields:
		current_shields[zone] = int(data.shields[zone])


## Initialises defense tokens from the ship data template, all READY.
## Rules Reference: SU-026 — all defense tokens start in READY state.
func _init_defense_tokens(data: ShipData) -> void:
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
			push_error("ShipInstance: unknown defense token '%s'" % name)
			return Constants.DefenseToken.EVADE


static func _build_runtime_upgrade_instance(owner_player_id: int,
		source_roster_entry_id: String, upgrade_data_key: String,
		source_assignment_id: String, slot: String, slot_index: int) -> Dictionary:
	var source_ship_ref: String = _source_ship_ref(
			owner_player_id, source_roster_entry_id)
	return {
		"runtime_upgrade_id": "%s:upgrade:%s" % [source_ship_ref, source_assignment_id],
		"data_key": upgrade_data_key,
		"owner_player_id": owner_player_id,
		"source_ship_ref": source_ship_ref,
		"source_roster_entry_id": source_roster_entry_id,
		"source_assignment_id": source_assignment_id,
		"slot": slot,
		"slot_index": slot_index,
		"card_state": _default_runtime_upgrade_card_state(),
		"trigger_guards": {},
		"rule_state": {},
	}


static func _source_ship_ref(owner_player_id: int, source_roster_entry_id: String) -> String:
	return "%d:ship:%s" % [owner_player_id, source_roster_entry_id]


static func _default_runtime_upgrade_card_state() -> Dictionary:
	return {
		"exhausted": false,
		"discarded": false,
		"disabled": false,
		"readied": true,
	}


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------


## Serializes this ship's mutable runtime state to a dictionary.
## The static template data ([member ship_data]) is identified by
## [member data_key] and must be re-loaded on deserialization.
func serialize() -> Dictionary:
	return {
		"data_key": data_key,
		"roster_entry_id": roster_entry_id,
		"fleet_points": fleet_points,
		"current_shields": current_shields.duplicate(),
		"current_hull": current_hull,
		"current_speed": current_speed,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
		"defense_tokens": _serialize_defense_tokens(),
		"facedown_damage": _serialize_damage_cards(facedown_damage),
		"faceup_damage": _serialize_damage_cards(faceup_damage),
		"activated_this_round": activated_this_round,
		"owner_player": owner_player,
		"destroyed": _destroyed,
		"command_dial_stack": command_dial_stack.serialize() \
				if command_dial_stack else {},
		"command_tokens": command_tokens.serialize() \
				if command_tokens else {},
		"runtime_upgrades": _serialize_runtime_upgrades(),
	}


## Restores a ShipInstance from a serialized dictionary.
## [param data] — the dictionary produced by [method serialize].
## [param ship_data_ref] — the static [ShipData] template for this ship.
##     The caller must look up the template via [code]data["data_key"][/code].
static func deserialize(
		data: Dictionary, ship_data_ref: ShipData) -> ShipInstance:
	var inst: ShipInstance = ShipInstance.new()
	inst.data_key = data.get("data_key", "") as String
	inst.roster_entry_id = data.get("roster_entry_id", "") as String
	inst.fleet_points = int(data.get("fleet_points", 0))
	inst.ship_data = ship_data_ref
	# JSON round-trips coerce ints to floats; force int back so the
	# UI ([ShipToken] hull/shield labels) renders "1" rather than "1.0".
	inst.current_shields = {}
	var shields_raw: Dictionary = data.get(
			"current_shields", {}) as Dictionary
	for zone: Variant in shields_raw:
		inst.current_shields[zone] = int(shields_raw[zone])
	inst.current_hull = int(data.get("current_hull", 0))
	inst.current_speed = int(data.get("current_speed", 0))
	inst.pos_x = float(data.get("pos_x", 0.0))
	inst.pos_y = float(data.get("pos_y", 0.0))
	inst.rotation_deg = float(data.get("rotation_deg", 0.0))
	inst.activated_this_round = data.get(
			"activated_this_round", false) as bool
	inst.owner_player = int(data.get("owner_player", 0))
	inst._destroyed = data.get("destroyed", false) as bool
	inst.runtime_upgrades = _deserialize_runtime_upgrades(
			data.get("runtime_upgrades", []))
	# Defense tokens
	for t: Variant in data.get("defense_tokens", []):
		var td: Dictionary = t as Dictionary
		inst.defense_tokens.append({
			"type": int(td["type"]) as Constants.DefenseToken,
			"state": int(td["state"]) as Constants.DefenseTokenState,
		})
	# Damage cards
	for cd: Variant in data.get("facedown_damage", []):
		inst.facedown_damage.append(DamageCard.deserialize(
				cd as Dictionary))
	for cd: Variant in data.get("faceup_damage", []):
		inst.faceup_damage.append(DamageCard.deserialize(
				cd as Dictionary))
	# Sub-components
	var cds_data: Dictionary = data.get("command_dial_stack", {})
	inst.command_dial_stack = CommandDialStack.deserialize(cds_data) \
			if not cds_data.is_empty() else null
	var ctm_data: Dictionary = data.get("command_tokens", {})
	inst.command_tokens = CommandTokenManager.deserialize(ctm_data) \
			if not ctm_data.is_empty() else null
	return inst


func _serialize_defense_tokens() -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	for token: Dictionary in defense_tokens:
		tokens.append({
			"type": int(token["type"]),
			"state": int(token["state"]),
		})
	return tokens


func _serialize_damage_cards(cards: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: Variant in cards:
		result.append((card as DamageCard).serialize())
	return result


func _serialize_runtime_upgrades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for runtime_upgrade: Dictionary in runtime_upgrades:
		result.append(runtime_upgrade.duplicate(true))
	return result


static func _deserialize_runtime_upgrades(raw_upgrades: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_upgrades is Array:
		return result
	for raw_upgrade: Variant in raw_upgrades as Array:
		if raw_upgrade is Dictionary:
			var runtime_upgrade: Dictionary = _runtime_upgrade_from_data(
					raw_upgrade as Dictionary)
			if not runtime_upgrade.is_empty():
				result.append(runtime_upgrade)
	return result


static func _runtime_upgrade_from_data(raw_upgrade: Dictionary) -> Dictionary:
	var missing_fields: Array[String] = _missing_runtime_upgrade_fields(raw_upgrade)
	if not missing_fields.is_empty():
		push_error("Invalid runtime upgrade missing fields: %s" % str(missing_fields))
		return {}
	if _has_empty_runtime_upgrade_identity(raw_upgrade):
		push_error("Invalid runtime upgrade identity: %s" % str(raw_upgrade))
		return {}
	var upgrade_data_key: String = str(raw_upgrade["data_key"])
	if AssetLoader.load_upgrade_data(upgrade_data_key) == null:
		push_error("Invalid runtime upgrade data_key: %s" % upgrade_data_key)
		return {}
	var card_state: Dictionary = _runtime_upgrade_card_state_from_data(
			raw_upgrade["card_state"])
	if card_state.is_empty():
		return {}
	return {
		"runtime_upgrade_id": str(raw_upgrade["runtime_upgrade_id"]),
		"data_key": upgrade_data_key,
		"owner_player_id": int(raw_upgrade["owner_player_id"]),
		"source_ship_ref": str(raw_upgrade["source_ship_ref"]),
		"source_roster_entry_id": str(raw_upgrade["source_roster_entry_id"]),
		"source_assignment_id": str(raw_upgrade["source_assignment_id"]),
		"slot": str(raw_upgrade["slot"]),
		"slot_index": raw_upgrade["slot_index"] \
				if raw_upgrade["slot_index"] == null \
				else int(raw_upgrade["slot_index"]),
		"card_state": card_state,
		"trigger_guards": _read_runtime_upgrade_dict(
				raw_upgrade["trigger_guards"]),
		"rule_state": _read_runtime_upgrade_dict(raw_upgrade["rule_state"]),
	}


static func _runtime_upgrade_card_state_from_data(raw_card_state: Variant) -> Dictionary:
	var source: Dictionary = _read_runtime_upgrade_dict(raw_card_state)
	var missing_fields: Array[String] = _missing_runtime_upgrade_card_state_fields(
			source)
	if not missing_fields.is_empty():
		push_error("Invalid runtime upgrade card_state missing fields: %s"
				% str(missing_fields))
		return {}
	var card_state: Dictionary = {
		"exhausted": bool(source["exhausted"]),
		"discarded": bool(source["discarded"]),
		"disabled": bool(source["disabled"]),
		"readied": bool(source["readied"]),
	}
	if not _runtime_upgrade_card_state_consistent(card_state):
		push_error("Invalid runtime upgrade card_state: %s" % str(card_state))
		return {}
	return card_state


static func _runtime_upgrade_card_state_consistent(card_state: Dictionary) -> bool:
	var exhausted: bool = bool(card_state.get("exhausted", false))
	var discarded: bool = bool(card_state.get("discarded", false))
	var disabled: bool = bool(card_state.get("disabled", false))
	var readied: bool = bool(card_state.get("readied", false))
	if readied and exhausted:
		return false
	if discarded and (readied or exhausted):
		return false
	if disabled and (readied or exhausted or discarded):
		return false
	return true


static func _missing_runtime_upgrade_fields(raw_upgrade: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for field: String in RUNTIME_UPGRADE_REQUIRED_FIELDS:
		if not raw_upgrade.has(field):
			missing.append(field)
	return missing


static func _has_empty_runtime_upgrade_identity(raw_upgrade: Dictionary) -> bool:
	for field: String in RUNTIME_UPGRADE_IDENTITY_FIELDS:
		if str(raw_upgrade[field]).is_empty():
			return true
	return false


static func _missing_runtime_upgrade_card_state_fields(
		card_state: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for field: String in RUNTIME_UPGRADE_CARD_STATE_FIELDS:
		if not card_state.has(field):
			missing.append(field)
	return missing


static func _read_runtime_upgrade_dict(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)
	return {}

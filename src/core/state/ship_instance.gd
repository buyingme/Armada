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

const ACTIVATION_DISPOSITION_INACTIVE: String = ""
const ACTIVATION_DISPOSITION_UNREACHED: String = "UNREACHED"
const ACTIVATION_DISPOSITION_OPEN: String = "OPEN"
const ACTIVATION_DISPOSITION_CONSUMED: String = "CONSUMED"

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

## Non-serializing link used only by passive Network states.
var _passive_damage_ledger: PassiveDamageLedger = null
var _passive_damage_key: String = ""

## Faceup damage cards assigned to this ship. Each entry is a DamageCard.
## Rules Reference: DM-005.
var faceup_damage: Array = []

## Whether this ship has been activated this round.
## Rules Reference: SP-001 — each ship activates once per round.
var activated_this_round: bool = false

## Authoritative ADR-006 owner-local ship-activation boundary.
## Purpose-specific commands establish and advance these serialized facts.
var ship_activation_identity: String = ""
var squadron_command_opportunity_disposition: String = \
		ACTIVATION_DISPOSITION_INACTIVE
var maneuver_opportunity_disposition: String = \
		ACTIVATION_DISPOSITION_INACTIVE
var squadron_command_activations_committed: int = 0

## Narrow ADR-006 Maneuver commitment record. The dictionary is private so
## callers can only mutate it through the identity-bound owner operations
## below. An empty dictionary represents no committed Maneuver execution.
var _active_maneuver_execution: Dictionary = {}

## Narrow ADR-014 unresolved immediate faceup-card obligation. The record is
## private and references one physical card already owned in faceup_damage.
var _active_immediate_resolution: Dictionary = {}

## Purpose-specific obstacle owners. These are deliberately separate values;
## there is no generic obstacle work record or continuation queue.
var _active_asteroid_resolution: Dictionary = {}
var _active_debris_resolution: Dictionary = {}
var _active_station_resolution: Dictionary = {}

## Authoritative, activation-local progress for this ship's Attack step.
## BeginAttackCommand commits these facts; scene attack state only projects them.
var attack_step_active: bool = false
var committed_attack_count: int = 0
var used_attack_hull_zones: Array[int] = []
var anti_squadron_attack_zone: int = -1
var anti_squadron_target_history: Array[Dictionary] = []

var _attack_progress_log: GameLogger = GameLogger.new("ShipAttackProgress")

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
	return get_facedown_damage_count() + faceup_damage.size()


func get_facedown_damage_count() -> int:
	if _passive_damage_ledger != null:
		return maxi(0, _passive_damage_ledger.get_facedown_count(
				_passive_damage_key))
	return facedown_damage.size()


func bind_passive_damage_ledger(ledger: PassiveDamageLedger, key: String) -> bool:
	if ledger == null or ledger.get_facedown_count(key) < 0 \
			or not facedown_damage.is_empty():
		return false
	_passive_damage_ledger = ledger
	_passive_damage_key = key
	return true


func is_passive_damage_bound() -> bool:
	return _passive_damage_ledger != null


func passive_damage_key() -> String:
	return _passive_damage_key


func increment_passive_facedown_damage(count: int = 1) -> bool:
	return _passive_damage_ledger != null \
			and _passive_damage_ledger.increment_facedown(
					_passive_damage_key, count)


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


## True only after the accepted destruction transition has finalized. Damage
## assignment may temporarily reach the hull threshold while its atomic source
## transaction installs, then immediately terminates, an ADR-014 obligation.
func has_finalized_destruction() -> bool:
	return _destroyed


## Permanently marks this ship as destroyed. Call this before emitting the
## [code]ship_destroyed[/code] signal so that handlers (scoring, elimination)
## always see a consistent state — even after [method clear_all_damage_cards]
## returns the cards to the deck.
## Rules Reference: DM-003.
func mark_destroyed() -> void:
	if has_active_ship_activation():
		_reset_ship_activation_boundary_values()
	_active_immediate_resolution.clear()
	_clear_active_obstacle_resolutions()
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
	if is_passive_damage_bound():
		push_error("Concrete facedown cards are unavailable on a passive ship.")
		return
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
	if _active_immediate_resolution_references(card):
		return false
	if is_passive_damage_bound():
		var public_idx: int = faceup_damage.find(card)
		if public_idx < 0:
			return false
		faceup_damage.remove_at(public_idx)
		return true
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
	if is_passive_damage_bound():
		return []
	var cards: Array = []
	cards.append_array(facedown_damage)
	cards.append_array(faceup_damage)
	facedown_damage.clear()
	faceup_damage.clear()
	_active_immediate_resolution.clear()
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


## Returns whether this ship owns an active ADR-006 activation identity.
func has_active_ship_activation() -> bool:
	return not ship_activation_identity.is_empty()


## Validates the complete owner-local ADR-006 representation.
func validate_ship_activation_boundary() -> bool:
	return _ship_activation_boundary_values_are_valid(
			ship_activation_identity,
			squadron_command_opportunity_disposition,
			maneuver_opportunity_disposition,
			squadron_command_activations_committed,
			_destroyed) and _active_maneuver_execution_is_valid(
				_active_maneuver_execution) \
			and _obstacle_resolution_records_are_valid_for(
				_active_maneuver_execution, _active_asteroid_resolution,
				_active_debris_resolution, _active_station_resolution)


## Installation-level aggregate check. Atomic Asteroid assignment briefly
## establishes ADR-014 before its purpose-specific return record, so this
## invariant is checked only after the enclosing transaction is complete.
func validate_maneuver_immediate_nesting() -> bool:
	return _nested_maneuver_immediate_state_is_valid()


## Establishes one stable activation identity with inactive opportunities.
func establish_ship_activation(identity: String) -> bool:
	if identity.is_empty() \
			or not validate_ship_activation_boundary() \
			or has_active_ship_activation() \
			or _destroyed:
		return false
	ship_activation_identity = identity
	squadron_command_opportunity_disposition = \
			ACTIVATION_DISPOSITION_UNREACHED
	maneuver_opportunity_disposition = ACTIVATION_DISPOSITION_UNREACHED
	squadron_command_activations_committed = 0
	return true


## Opens the Squadron-command opportunity from UNREACHED.
func open_squadron_command_opportunity(
		expected_activation_identity: String) -> bool:
	if not _matches_ship_activation(expected_activation_identity) \
			or squadron_command_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_UNREACHED:
		return false
	squadron_command_opportunity_disposition = ACTIVATION_DISPOSITION_OPEN
	return true


## Consumes an already-open Squadron-command opportunity.
func consume_open_squadron_command_opportunity(
		expected_activation_identity: String) -> bool:
	if not _matches_ship_activation(expected_activation_identity) \
			or squadron_command_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_OPEN:
		return false
	squadron_command_opportunity_disposition = ACTIVATION_DISPOSITION_CONSUMED
	return true


## Performs the accepted caller-validated UNREACHED -> CONSUMED bypass.
func consume_unreached_squadron_command_opportunity(
		expected_activation_identity: String,
		caller_validated_bypass: bool) -> bool:
	if not caller_validated_bypass \
			or not _matches_ship_activation(expected_activation_identity) \
			or squadron_command_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_UNREACHED:
		return false
	squadron_command_opportunity_disposition = ACTIVATION_DISPOSITION_CONSUMED
	return true


## Opens the mandatory Maneuver opportunity from UNREACHED.
func open_maneuver_opportunity(
		expected_activation_identity: String) -> bool:
	if not _matches_ship_activation(expected_activation_identity) \
			or maneuver_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_UNREACHED:
		return false
	maneuver_opportunity_disposition = ACTIVATION_DISPOSITION_OPEN
	return true


## Records normal Maneuver execution through OPEN -> CONSUMED only.
func consume_open_maneuver_opportunity(
		expected_activation_identity: String) -> bool:
	# The accepted Maneuver path retires a committed execution and consumes the
	# opportunity together through complete_maneuver_execution().
	if not _active_maneuver_execution.is_empty():
		return false
	if not _matches_ship_activation(expected_activation_identity) \
			or maneuver_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_OPEN:
		return false
	maneuver_opportunity_disposition = ACTIVATION_DISPOSITION_CONSUMED
	return true


## Returns whether this ship owns one committed Maneuver execution.
func has_active_maneuver_execution() -> bool:
	return not _active_maneuver_execution.is_empty()


## Returns a deep copy; callers never receive the writable owner value.
func active_maneuver_execution_snapshot() -> Dictionary:
	return _active_maneuver_execution.duplicate(true)


func active_asteroid_resolution_snapshot() -> Dictionary:
	return _active_asteroid_resolution.duplicate(true)


func active_debris_resolution_snapshot() -> Dictionary:
	return _active_debris_resolution.duplicate(true)


func active_station_resolution_snapshot() -> Dictionary:
	return _active_station_resolution.duplicate(true)


func has_active_obstacle_resolution() -> bool:
	return not _active_asteroid_resolution.is_empty() \
			or not _active_debris_resolution.is_empty() \
			or not _active_station_resolution.is_empty()


func open_asteroid_resolution(expected_activation_identity: String,
		execution_id: String, obstacle_id: String,
		immediate_resolution_id: String) -> bool:
	if has_active_obstacle_resolution() \
			or not _matches_maneuver_execution(
					expected_activation_identity, execution_id) \
			or obstacle_id.is_empty() or immediate_resolution_id.is_empty():
		return false
	_active_asteroid_resolution = {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"obstacle_id": obstacle_id,
		"immediate_resolution_id": immediate_resolution_id,
		"disposition": "OPEN",
	}
	return true


func complete_asteroid_resolution(expected_activation_identity: String,
		execution_id: String, obstacle_id: String,
		immediate_resolution_id: String) -> bool:
	if _active_asteroid_resolution != {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"obstacle_id": obstacle_id,
		"immediate_resolution_id": immediate_resolution_id,
		"disposition": "OPEN",
	} or has_active_immediate_resolution():
		return false
	_active_asteroid_resolution.clear()
	return true


func open_debris_resolution(expected_activation_identity: String,
		execution_id: String, obstacle_id: String,
		controller_player: int) -> bool:
	if has_active_obstacle_resolution() \
			or not _matches_maneuver_execution(
					expected_activation_identity, execution_id) \
			or obstacle_id.is_empty() or controller_player not in [0, 1]:
		return false
	_active_debris_resolution = {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"obstacle_id": obstacle_id,
		"controller_player": controller_player,
		"disposition": "OPEN",
	}
	return true


func complete_debris_resolution(expected_activation_identity: String,
		execution_id: String, obstacle_id: String,
		controller_player: int) -> bool:
	if _active_debris_resolution != {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"obstacle_id": obstacle_id,
		"controller_player": controller_player,
		"disposition": "OPEN",
	}:
		return false
	_active_debris_resolution.clear()
	return true


func open_station_resolution(expected_activation_identity: String,
		execution_id: String, obstacle_id: String,
		controller_player: int) -> bool:
	if has_active_obstacle_resolution() \
			or not _matches_maneuver_execution(
					expected_activation_identity, execution_id) \
			or obstacle_id.is_empty() or controller_player not in [0, 1]:
		return false
	_active_station_resolution = {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"obstacle_id": obstacle_id,
		"controller_player": controller_player,
		"disposition": "OPEN",
	}
	return true


func complete_station_resolution(expected_activation_identity: String,
		execution_id: String, obstacle_id: String,
		controller_player: int) -> bool:
	if _active_station_resolution != {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"obstacle_id": obstacle_id,
		"controller_player": controller_player,
		"disposition": "OPEN",
	}:
		return false
	_active_station_resolution.clear()
	return true


func clear_active_obstacle_resolutions_exceptionally() -> void:
	_clear_active_obstacle_resolutions()


func _clear_active_obstacle_resolutions() -> void:
	_active_asteroid_resolution.clear()
	_active_debris_resolution.clear()
	_active_station_resolution.clear()


## Atomically establishes the narrow execution identity/evidence after the
## caller has authoritatively derived the final Maneuver result.
func commit_maneuver_execution(expected_activation_identity: String,
		execution_id: String, navigate_speed_changed: bool,
		committed_result: Dictionary, ship_collision: Dictionary) -> bool:
	if not _matches_ship_activation(expected_activation_identity) \
			or maneuver_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_OPEN \
			or has_active_maneuver_execution() \
			or execution_id.is_empty():
		return false
	var candidate: Dictionary = {
		"maneuver_execution_id": execution_id,
		"ship_activation_identity": expected_activation_identity,
		"navigate_speed_changed": navigate_speed_changed,
		"final_transform_applied": false,
		"committed_result": committed_result.duplicate(true),
		"obstacle_resolution_order": [],
		"ship_collision": ship_collision.duplicate(true),
	}
	if not _active_maneuver_execution_is_valid(candidate):
		return false
	_active_maneuver_execution = candidate
	return true


## Applies the recorded final board transform once after the evaluator has
## proved that no post-commitment/pre-movement obligation remains.
func apply_maneuver_final_transform(expected_activation_identity: String,
		execution_id: String) -> Dictionary:
	if not _matches_maneuver_execution(
			expected_activation_identity, execution_id) \
			or bool(_active_maneuver_execution.get(
					"final_transform_applied", false)):
		return {}
	var committed: Variant = _active_maneuver_execution.get("committed_result")
	if not committed is Dictionary \
			or not _maneuver_committed_result_is_valid(committed as Dictionary):
		return {}
	var result: Dictionary = (committed as Dictionary).duplicate(true)
	pos_x = float(result["pos_x"])
	pos_y = float(result["pos_y"])
	rotation_deg = float(result["rotation_deg"])
	_active_maneuver_execution.erase("committed_result")
	_active_maneuver_execution["final_transform_applied"] = true
	if not _active_maneuver_execution_is_valid(
			_active_maneuver_execution):
		return {}
	return result


## Stores the one accepted cross-obstacle order. Empty is retained for the
## no-choice case; a non-empty accepted order is immutable.
func commit_maneuver_obstacle_order(expected_activation_identity: String,
		execution_id: String, obstacle_ids: Array[String]) -> bool:
	if not _matches_maneuver_execution(
			expected_activation_identity, execution_id):
		return false
	var current: Array = _active_maneuver_execution.get(
			"obstacle_resolution_order", []) as Array
	if not current.is_empty():
		return false
	var seen: Dictionary = {}
	for obstacle_id: String in obstacle_ids:
		if obstacle_id.is_empty() or seen.has(obstacle_id):
			return false
		seen[obstacle_id] = true
	_active_maneuver_execution["obstacle_resolution_order"] = \
			obstacle_ids.duplicate()
	return true


## Advances only the immutable collision branch's exact-once resolved bit.
func mark_maneuver_ship_collision_damage_resolved(
		expected_activation_identity: String, execution_id: String,
		exact_once_key: String) -> bool:
	if not _matches_maneuver_execution(
			expected_activation_identity, execution_id):
		return false
	var collision: Dictionary = _active_maneuver_execution.get(
			"ship_collision", {}) as Dictionary
	if str(collision.get("kind", "")) != "closest_ship" \
			or bool(collision.get("damage_resolved", false)) \
			or str(collision.get("exact_once_key", "")) != exact_once_key:
		return false
	collision = collision.duplicate(true)
	collision["damage_resolved"] = true
	_active_maneuver_execution["ship_collision"] = collision
	return true


## Performs the accepted normal OPEN+record -> CONSUMED+no-record transition
## only after the authority evaluator supplies a fresh positive proof.
func complete_maneuver_execution(expected_activation_identity: String,
		execution_id: String, no_mandatory_work: bool) -> bool:
	if not no_mandatory_work or not _matches_maneuver_execution(
			expected_activation_identity, execution_id) \
			or not bool(_active_maneuver_execution.get(
					"final_transform_applied", false)) \
			or has_active_obstacle_resolution():
		return false
	maneuver_opportunity_disposition = ACTIVATION_DISPOSITION_CONSUMED
	_active_maneuver_execution.clear()
	return validate_ship_activation_boundary()


## Exceptional cleanup never fabricates a consumed Maneuver opportunity.
func clear_maneuver_execution_exceptionally(
		expected_activation_identity: String,
		execution_id: String) -> bool:
	if not _matches_maneuver_execution(
			expected_activation_identity, execution_id):
		return false
	_active_maneuver_execution.clear()
	return true


## Dormant save-7 helper. Current save-6 serialization does not call it.
func serialize_maneuver_execution_for_save7() -> Dictionary:
	return {
		"active_maneuver_execution":
				_active_maneuver_execution.duplicate(true),
		"active_asteroid_resolution":
				_active_asteroid_resolution.duplicate(true),
		"active_debris_resolution":
				_active_debris_resolution.duplicate(true),
		"active_station_resolution":
				_active_station_resolution.duplicate(true),
	}


## Dormant strict save-7 installer. The raw value is either absent (null) or
## the exact record schema; current save-6 deserialization does not call it.
func install_maneuver_execution_for_save7(raw_value: Variant) -> bool:
	if raw_value == null:
		_active_maneuver_execution.clear()
		_clear_active_obstacle_resolutions()
		return validate_ship_activation_boundary()
	if not raw_value is Dictionary or (raw_value as Dictionary).size() != 4:
		return false
	var data: Dictionary = raw_value as Dictionary
	for key: String in ["active_maneuver_execution",
			"active_asteroid_resolution", "active_debris_resolution",
			"active_station_resolution"]:
		if not data.has(key) or not data[key] is Dictionary:
			return false
	var candidate: Dictionary = (data["active_maneuver_execution"] \
			as Dictionary).duplicate(true)
	var asteroid: Dictionary = (data["active_asteroid_resolution"] \
			as Dictionary).duplicate(true)
	var debris: Dictionary = (data["active_debris_resolution"] \
			as Dictionary).duplicate(true)
	var station: Dictionary = (data["active_station_resolution"] \
			as Dictionary).duplicate(true)
	if not _active_maneuver_execution_is_valid(candidate) \
			or not _obstacle_resolution_records_are_valid_for(
					candidate, asteroid, debris, station):
		return false
	_active_maneuver_execution = candidate
	_active_asteroid_resolution = asteroid
	_active_debris_resolution = debris
	_active_station_resolution = station
	return validate_ship_activation_boundary()


## Returns whether this ship owns one unresolved ADR-014 obligation.
func has_active_immediate_resolution() -> bool:
	return not _active_immediate_resolution.is_empty()


func active_immediate_resolution_snapshot() -> Dictionary:
	return _active_immediate_resolution.duplicate(true)


func faceup_card_for_public_ref(reference: String) -> DamageCard:
	return _faceup_card_by_public_ref(reference)


## Establishes one already-derived exact obligation referencing a faceup card
## physically owned by this ship. No card object is copied into the record.
func establish_immediate_resolution(record: Dictionary) -> bool:
	if is_passive_damage_bound() or has_finalized_destruction() \
			or has_active_immediate_resolution():
		return false
	var candidate: Dictionary = record.duplicate(true)
	if not _active_immediate_resolution_is_valid(candidate):
		return false
	_active_immediate_resolution = candidate
	return true


## Installs the exact viewer-filtered obligation. It is bound to the public
## occurrence only and deliberately cannot carry physical or exact-once ids.
func establish_filtered_immediate_resolution(record: Dictionary) -> bool:
	if not is_passive_damage_bound() or has_finalized_destruction() \
			or has_active_immediate_resolution():
		return false
	var candidate: Dictionary = record.duplicate(true)
	if not _filtered_immediate_resolution_is_valid(candidate):
		return false
	_active_immediate_resolution = candidate
	return true


## Resolves the matching occurrence exactly once. Immediate-persistent cards
## may retain their public faceup source; every other immediate source is
## concealed and loses its occurrence reference atomically.
func retire_immediate_resolution(immediate_resolution_id: String,
		public_card_ref: String, source_disposition: String) -> bool:
	if source_disposition not in ["faceup", "facedown"] \
			or str(_active_immediate_resolution.get(
					"immediate_resolution_id", "")) != immediate_resolution_id \
			or str(_active_immediate_resolution.get(
					"public_card_ref", "")) != public_card_ref:
		return false
	var card: DamageCard = _faceup_card_by_public_ref(public_card_ref)
	if card == null \
			or card.physical_card_id != str(_active_immediate_resolution.get(
					"physical_card_id", "")):
		return false
	if source_disposition == "facedown":
		var source_index: int = faceup_damage.find(card)
		if source_index < 0:
			return false
		faceup_damage.remove_at(source_index)
		card.flip_facedown()
		facedown_damage.append(card)
	_active_immediate_resolution.clear()
	return true


## Passive counterpart to authority retirement. The public occurrence is
## removed on concealment and no correlation is retained in facedown state.
func retire_filtered_immediate_resolution(immediate_resolution_id: String,
		public_card_ref: String, source_disposition: String) -> bool:
	if not is_passive_damage_bound() \
			or source_disposition not in ["faceup", "facedown"] \
			or str(_active_immediate_resolution.get(
					"immediate_resolution_id", "")) != immediate_resolution_id \
			or str(_active_immediate_resolution.get(
					"public_card_ref", "")) != public_card_ref \
			or not _filtered_immediate_resolution_is_valid(
					_active_immediate_resolution):
		return false
	var card: DamageCard = _faceup_card_by_public_ref(public_card_ref)
	if card == null:
		return false
	if source_disposition == "facedown":
		faceup_damage.erase(card)
	_active_immediate_resolution.clear()
	return true


## Exceptional termination is absence, never fabricated resolution.
func clear_immediate_resolution_exceptionally() -> void:
	_active_immediate_resolution.clear()


## Dormant strict save-7 branch. Current save-6 output remains unchanged.
func serialize_immediate_resolution_for_save7() -> Dictionary:
	if _active_immediate_resolution.is_empty():
		return {}
	if not _active_immediate_resolution_is_valid(
			_active_immediate_resolution):
		return {}
	return {"active_immediate_resolution":
			_active_immediate_resolution.duplicate(true)}


func install_immediate_resolution_for_save7(raw_value: Variant) -> bool:
	if raw_value == null:
		_active_immediate_resolution.clear()
		return true
	if not raw_value is Dictionary:
		return false
	var candidate: Dictionary = (raw_value as Dictionary).duplicate(true)
	if not _active_immediate_resolution_is_valid(candidate):
		return false
	_active_immediate_resolution = candidate
	return true


## Dormant protocol-7 filtered-state validation. The live protocol-6
## installation path does not call this before the coordinated cutover.
func validate_filtered_damage_state_for_protocol7() -> bool:
	if not is_passive_damage_bound() or not facedown_damage.is_empty():
		return false
	var refs: Dictionary = {}
	for raw_card: Variant in faceup_damage:
		if not raw_card is DamageCard:
			return false
		var card: DamageCard = raw_card as DamageCard
		if not card.is_faceup or not card.physical_card_id.is_empty() \
				or card.public_card_ref.is_empty() \
				or refs.has(card.public_card_ref) \
				or card.public_faceup_damage_card().size() != 7:
			return false
		refs[card.public_card_ref] = true
	return _active_immediate_resolution.is_empty() \
			or _filtered_immediate_resolution_is_valid(
					_active_immediate_resolution)


func serialize_filtered_damage_state_for_protocol7() -> Dictionary:
	if not validate_filtered_damage_state_for_protocol7():
		return {}
	var faceup: Array[Dictionary] = []
	for card: DamageCard in faceup_damage:
		faceup.append(card.public_faceup_damage_card())
	return {
		"facedown_count": get_facedown_damage_count(),
		"faceup_damage": faceup,
		"active_immediate_resolution":
				_active_immediate_resolution.duplicate(true),
	}


## Read-only entries for aggregate physical-location validation.
func candidate_damage_identity_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: DamageCard in facedown_damage:
		result.append({"physical_card_id": card.physical_card_id,
			"location": "ship", "card": card})
	for card: DamageCard in faceup_damage:
		result.append({"physical_card_id": card.physical_card_id,
			"location": "ship", "card": card})
	return result


func validate_damage_state_for_save7() -> bool:
	for card: DamageCard in facedown_damage:
		if not card.validate_candidate_identity_for_location("ship") \
				or card.is_faceup:
			return false
	for card: DamageCard in faceup_damage:
		if not card.validate_candidate_identity_for_location("ship") \
				or not card.is_faceup:
			return false
	return _active_immediate_resolution.is_empty() \
			or _active_immediate_resolution_is_valid(
					_active_immediate_resolution)


func serialize_damage_state_for_save7() -> Dictionary:
	if not validate_damage_state_for_save7():
		return {}
	var facedown: Array[Dictionary] = []
	for card: DamageCard in facedown_damage:
		facedown.append(card.serialize_for_save7("ship"))
	var faceup: Array[Dictionary] = []
	for card: DamageCard in faceup_damage:
		faceup.append(card.serialize_for_save7("ship"))
	return {
		"facedown_damage": facedown,
		"faceup_damage": faceup,
		"active_immediate_resolution":
				_active_immediate_resolution.duplicate(true),
	}


func install_damage_state_for_save7(data: Dictionary) -> bool:
	if data.size() != 3 or not data.has("facedown_damage") \
			or not data.has("faceup_damage") \
			or not data.has("active_immediate_resolution") \
			or not (data["facedown_damage"] is Array) \
			or not (data["faceup_damage"] is Array) \
			or not (data["active_immediate_resolution"] is Dictionary):
		return false
	var new_facedown: Array = []
	var new_faceup: Array = []
	var seen: Dictionary = {}
	for raw: Variant in data["facedown_damage"]:
		if not raw is Dictionary:
			return false
		var card: DamageCard = DamageCard.deserialize_for_save7(
				raw as Dictionary, "ship")
		if card == null or card.is_faceup \
				or seen.has(card.physical_card_id):
			return false
		seen[card.physical_card_id] = true
		new_facedown.append(card)
	for raw: Variant in data["faceup_damage"]:
		if not raw is Dictionary:
			return false
		var card: DamageCard = DamageCard.deserialize_for_save7(
				raw as Dictionary, "ship")
		if card == null or not card.is_faceup \
				or seen.has(card.physical_card_id):
			return false
		seen[card.physical_card_id] = true
		new_faceup.append(card)
	var old_facedown: Array = facedown_damage
	var old_faceup: Array = faceup_damage
	var old_record: Dictionary = _active_immediate_resolution
	facedown_damage = new_facedown
	faceup_damage = new_faceup
	_active_immediate_resolution.clear()
	var record: Dictionary = data["active_immediate_resolution"] as Dictionary
	if not record.is_empty() and not install_immediate_resolution_for_save7(
			record):
		facedown_damage = old_facedown
		faceup_damage = old_faceup
		_active_immediate_resolution = old_record
		return false
	if not validate_damage_state_for_save7():
		facedown_damage = old_facedown
		faceup_damage = old_faceup
		_active_immediate_resolution = old_record
		return false
	return true


func _faceup_card_by_public_ref(reference: String) -> DamageCard:
	var found: DamageCard = null
	for card: DamageCard in faceup_damage:
		if card.public_card_ref != reference:
			continue
		if found != null:
			return null
		found = card
	return found


func _active_immediate_resolution_references(card: RefCounted) -> bool:
	if not card is DamageCard or not has_active_immediate_resolution():
		return false
	if is_passive_damage_bound():
		return (card as DamageCard).public_card_ref == str(
				_active_immediate_resolution.get("public_card_ref", ""))
	return (card as DamageCard).physical_card_id == str(
			_active_immediate_resolution.get("physical_card_id", ""))


func _active_immediate_resolution_is_valid(record: Dictionary) -> bool:
	if is_passive_damage_bound():
		return _filtered_immediate_resolution_is_valid(record)
	var base_keys: Array[String] = [
		"immediate_resolution_id", "public_card_ref", "physical_card_id",
		"effect_id", "actor_player", "exact_once_key", "enclosing_kind",
	]
	var enclosing_kind: String = str(record.get("enclosing_kind", ""))
	match enclosing_kind:
		"attack":
			base_keys.append("attack_id")
		"maneuver":
			base_keys.append_array([
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id",
			])
		"debug":
			base_keys.append("debug_application_id")
		_:
			return false
	if record.size() != base_keys.size():
		return false
	for key: String in base_keys:
		if not record.has(key):
			return false
	for key: String in [
		"immediate_resolution_id", "public_card_ref", "physical_card_id",
		"effect_id", "exact_once_key"]:
		if typeof(record[key]) != TYPE_STRING or str(record[key]).is_empty():
			return false
	if typeof(record["actor_player"]) != TYPE_INT \
			or int(record["actor_player"]) not in [-1, 0, 1]:
		return false
	var card: DamageCard = _faceup_card_by_public_ref(
			str(record["public_card_ref"]))
	if card == null or card.physical_card_id != str(record["physical_card_id"]) \
			or card.effect_id != str(record["effect_id"]):
		return false
	if str(record["immediate_resolution_id"]) \
			!= "immediate:%s" % str(record["public_card_ref"]):
		return false
	match enclosing_kind:
		"attack":
			var attack_id: String = str(record["attack_id"])
			if attack_id.is_empty() or str(record["exact_once_key"]) \
					!= "immediate:attack:%s:%s" % [
						attack_id, card.physical_card_id]:
				return false
		"maneuver":
			var activation_id: String = str(record["ship_activation_identity"])
			var execution_id: String = str(record["maneuver_execution_id"])
			if str(record["maneuver_source_kind"]) != "asteroid" \
					or str(record["maneuver_source_id"]).is_empty() \
					or not _matches_maneuver_execution(
							activation_id, execution_id) \
					or str(record["exact_once_key"]) \
							!= "immediate:maneuver:%s:%s:%s" % [
								activation_id, execution_id,
								card.physical_card_id]:
				return false
		"debug":
			var debug_id: String = str(record["debug_application_id"])
			if debug_id.is_empty() or str(record["exact_once_key"]) \
					!= "immediate:debug:%s:%s" % [
						debug_id, card.physical_card_id]:
				return false
	return true


func _filtered_immediate_resolution_is_valid(record: Dictionary) -> bool:
	var base_keys: Array[String] = [
		"immediate_resolution_id", "public_card_ref", "effect_id",
		"actor_player", "enclosing_kind",
	]
	var enclosing_kind: String = str(record.get("enclosing_kind", ""))
	match enclosing_kind:
		"attack":
			base_keys.append("attack_id")
		"maneuver":
			base_keys.append_array([
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id",
			])
		"debug":
			base_keys.append("debug_application_id")
		_:
			return false
	if record.size() != base_keys.size():
		return false
	for key: String in base_keys:
		if not record.has(key):
			return false
	for key: String in [
		"immediate_resolution_id", "public_card_ref", "effect_id"]:
		if typeof(record[key]) != TYPE_STRING or str(record[key]).is_empty():
			return false
	if record.has("physical_card_id") or record.has("exact_once_key") \
			or typeof(record["actor_player"]) != TYPE_INT \
			or int(record["actor_player"]) not in [-1, 0, 1]:
		return false
	var card: DamageCard = _faceup_card_by_public_ref(
			str(record["public_card_ref"]))
	if card == null or card.effect_id != str(record["effect_id"]) \
			or not card.physical_card_id.is_empty() \
			or str(record["immediate_resolution_id"]) \
					!= "immediate:%s" % str(record["public_card_ref"]):
		return false
	match enclosing_kind:
		"attack":
			return not str(record["attack_id"]).is_empty()
		"maneuver":
			return str(record["maneuver_source_kind"]) == "asteroid" \
					and not str(record["ship_activation_identity"]).is_empty() \
					and not str(record["maneuver_execution_id"]).is_empty() \
					and not str(record["maneuver_source_id"]).is_empty()
		"debug":
			return not str(record["debug_application_id"]).is_empty()
	return false


## Commits one commanded-squadron activation while the opportunity is OPEN.
func commit_squadron_command_activation(
		expected_activation_identity: String) -> bool:
	if not _matches_ship_activation(expected_activation_identity) \
			or squadron_command_opportunity_disposition \
					!= ACTIVATION_DISPOSITION_OPEN:
		return false
	squadron_command_activations_committed += 1
	return true


## Returns whether normal completion may clear the surviving activation.
func can_complete_ship_activation_normally(
		expected_activation_identity: String) -> bool:
	return _matches_ship_activation(expected_activation_identity) \
			and squadron_command_opportunity_disposition \
					== ACTIVATION_DISPOSITION_CONSUMED \
			and maneuver_opportunity_disposition \
					== ACTIVATION_DISPOSITION_CONSUMED


## Clears the boundary only after both normal-completion obligations pass.
func complete_ship_activation_boundary_normally(
		expected_activation_identity: String) -> bool:
	if not can_complete_ship_activation_normally(
			expected_activation_identity):
		return false
	_reset_ship_activation_boundary_values()
	return true


## Clears an exceptional terminal boundary without fabricating Maneuver use.
func clear_ship_activation_boundary_exceptionally(
		expected_activation_identity: String) -> bool:
	if expected_activation_identity.is_empty() \
			or ship_activation_identity != expected_activation_identity:
		return false
	_reset_ship_activation_boundary_values()
	return true


## Defensive owner-local reset for the accepted round-cleanup boundary.
func reset_ship_activation_boundary() -> void:
	_reset_ship_activation_boundary_values()


## Returns a JSON-safe snapshot for later atomic command rollback.
func ship_activation_boundary_snapshot() -> Dictionary:
	return {
		"ship_activation_identity": ship_activation_identity,
		"squadron_command_opportunity_disposition":
				squadron_command_opportunity_disposition,
		"maneuver_opportunity_disposition": maneuver_opportunity_disposition,
		"squadron_command_activations_committed":
				squadron_command_activations_committed,
		"active_maneuver_execution":
				_active_maneuver_execution.duplicate(true),
		"active_asteroid_resolution":
				_active_asteroid_resolution.duplicate(true),
		"active_debris_resolution":
				_active_debris_resolution.duplicate(true),
		"active_station_resolution":
				_active_station_resolution.duplicate(true),
	}


## Restores a snapshot produced by [method ship_activation_boundary_snapshot].
func restore_ship_activation_boundary(snapshot: Dictionary) -> bool:
	for key: String in [
			"ship_activation_identity",
			"squadron_command_opportunity_disposition",
			"maneuver_opportunity_disposition",
			"squadron_command_activations_committed",
			"active_maneuver_execution", "active_asteroid_resolution",
			"active_debris_resolution", "active_station_resolution"]:
		if not snapshot.has(key):
			return false
	var identity: String = str(snapshot["ship_activation_identity"])
	var squadron_disposition: String = str(
			snapshot["squadron_command_opportunity_disposition"])
	var maneuver_disposition: String = str(
			snapshot["maneuver_opportunity_disposition"])
	var committed: int = int(
			snapshot["squadron_command_activations_committed"])
	var execution: Variant = snapshot["active_maneuver_execution"]
	var asteroid: Variant = snapshot["active_asteroid_resolution"]
	var debris: Variant = snapshot["active_debris_resolution"]
	var station: Variant = snapshot["active_station_resolution"]
	if not execution is Dictionary or not asteroid is Dictionary \
			or not debris is Dictionary or not station is Dictionary:
		return false
	if not _ship_activation_boundary_values_are_valid(
			identity, squadron_disposition, maneuver_disposition,
			committed, _destroyed) \
			or not _active_maneuver_execution_is_valid_for(
					execution as Dictionary, identity,
					maneuver_disposition, _destroyed) \
			or not _obstacle_resolution_records_are_valid_for(
					execution as Dictionary, asteroid as Dictionary,
					debris as Dictionary, station as Dictionary):
		return false
	ship_activation_identity = identity
	squadron_command_opportunity_disposition = squadron_disposition
	maneuver_opportunity_disposition = maneuver_disposition
	squadron_command_activations_committed = committed
	_active_maneuver_execution = (execution as Dictionary).duplicate(true)
	_active_asteroid_resolution = (asteroid as Dictionary).duplicate(true)
	_active_debris_resolution = (debris as Dictionary).duplicate(true)
	_active_station_resolution = (station as Dictionary).duplicate(true)
	return true


## Opens this ship's Attack step. Repeated projection of the same step is
## idempotent and cannot erase already-committed attack progress.
func begin_attack_step() -> void:
	if attack_step_active:
		return
	attack_step_active = true
	committed_attack_count = 0
	used_attack_hull_zones.clear()
	anti_squadron_attack_zone = -1
	anti_squadron_target_history.clear()
	_log_attack_progress("begin_attack_step")


## Closes this ship's Attack step without discarding its activation history.
func end_attack_step() -> void:
	attack_step_active = false
	end_anti_squadron_attack()
	_log_attack_progress("end_attack_step")


## Validates the active, activation-local progress affected by one standard
## ship Begin. The command boundary rejects an inactive owner before calling.
func validate_attack_commit(attacker_zone: int, defender_player: int,
		defender_kind: String, defender_index: int) -> String:
	if not attack_step_active:
		return ""
	if anti_squadron_attack_zone >= 0:
		if attacker_zone != anti_squadron_attack_zone:
			return "Anti-squadron continuation must use the same attacking hull zone."
		if defender_kind != CurrentAttackState.KIND_SQUADRON:
			return "Anti-squadron continuation must target a squadron."
		if has_anti_squadron_target(defender_player, defender_index):
			return "Squadron was already targeted during this attack."
		return ""
	if committed_attack_count >= 2:
		return "Ship has already committed two attacks this activation."
	if attacker_zone in used_attack_hull_zones:
		return "Attacking hull zone was already used this activation."
	return ""


## Commits one accepted standard ship Begin exactly once to this owner.
func commit_attack(attacker_zone: int, defender_player: int,
		defender_kind: String, defender_index: int) -> void:
	if not attack_step_active:
		return
	if anti_squadron_attack_zone >= 0:
		anti_squadron_target_history.append(
				_make_squadron_target_ref(defender_player, defender_index))
		_log_attack_progress("commit_attack_step6")
		return
	committed_attack_count += 1
	used_attack_hull_zones.append(attacker_zone)
	if defender_kind == CurrentAttackState.KIND_SQUADRON:
		anti_squadron_attack_zone = attacker_zone
		anti_squadron_target_history = [
			_make_squadron_target_ref(defender_player, defender_index),
		]
	else:
		end_anti_squadron_attack()
	_log_attack_progress("commit_attack")


## Returns whether one squadron is already in the current Step 6 history.
func has_anti_squadron_target(owner: int, index: int) -> bool:
	for target: Dictionary in anti_squadron_target_history:
		if int(target.get("owner", -1)) == owner \
				and int(target.get("index", -1)) == index:
			return true
	return false


## Ends the current Step 6 iteration while retaining the committed normal
## attack and its used hull zone.
func end_anti_squadron_attack() -> void:
	var changed: bool = anti_squadron_attack_zone >= 0 \
			or not anti_squadron_target_history.is_empty()
	anti_squadron_attack_zone = -1
	anti_squadron_target_history.clear()
	if changed:
		_log_attack_progress("end_anti_squadron_attack")


## Returns a JSON-safe snapshot used for atomic command rollback.
func attack_progress_snapshot() -> Dictionary:
	return {
		"attack_step_active": attack_step_active,
		"committed_attack_count": committed_attack_count,
		"used_attack_hull_zones": used_attack_hull_zones.duplicate(),
		"anti_squadron_attack_zone": anti_squadron_attack_zone,
		"anti_squadron_target_history":
				anti_squadron_target_history.duplicate(true),
	}


## Restores a snapshot produced by [method attack_progress_snapshot].
func restore_attack_progress(snapshot: Dictionary) -> void:
	attack_step_active = bool(snapshot.get("attack_step_active", false))
	committed_attack_count = int(snapshot.get("committed_attack_count", 0))
	used_attack_hull_zones.clear()
	for zone: Variant in snapshot.get("used_attack_hull_zones", []):
		used_attack_hull_zones.append(int(zone))
	anti_squadron_attack_zone = int(snapshot.get(
			"anti_squadron_attack_zone", -1))
	anti_squadron_target_history.clear()
	for target: Variant in snapshot.get("anti_squadron_target_history", []):
		if target is Dictionary:
			var target_data: Dictionary = target as Dictionary
			anti_squadron_target_history.append(_make_squadron_target_ref(
					int(target_data.get("owner", -1)),
					int(target_data.get("index", -1))))
	_log_attack_progress("restore_attack_progress")


## Resets activation-local state for a new round.
func reset_activation() -> void:
	activated_this_round = false
	attack_step_active = false
	committed_attack_count = 0
	used_attack_hull_zones.clear()
	end_anti_squadron_attack()
	reset_ship_activation_boundary()
	_log_attack_progress("reset_activation")


func _log_attack_progress(transition: String) -> void:
	_attack_progress_log.debug("%s ship=%s owner=%d progress=%s" % [
		transition,
		data_key,
		owner_player,
		JSON.stringify(attack_progress_snapshot()),
	])


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


static func _make_squadron_target_ref(owner: int, index: int) -> Dictionary:
	return {"owner": owner, "index": index}


func _matches_ship_activation(expected_activation_identity: String) -> bool:
	return not expected_activation_identity.is_empty() \
			and ship_activation_identity == expected_activation_identity \
			and validate_ship_activation_boundary()


func _reset_ship_activation_boundary_values() -> void:
	ship_activation_identity = ""
	squadron_command_opportunity_disposition = \
			ACTIVATION_DISPOSITION_INACTIVE
	maneuver_opportunity_disposition = ACTIVATION_DISPOSITION_INACTIVE
	squadron_command_activations_committed = 0
	_active_maneuver_execution.clear()
	_clear_active_obstacle_resolutions()


func _matches_maneuver_execution(expected_activation_identity: String,
		execution_id: String) -> bool:
	return not execution_id.is_empty() \
			and _matches_ship_activation(expected_activation_identity) \
			and maneuver_opportunity_disposition \
					== ACTIVATION_DISPOSITION_OPEN \
			and str(_active_maneuver_execution.get(
					"maneuver_execution_id", "")) == execution_id \
			and str(_active_maneuver_execution.get(
					"ship_activation_identity", "")) \
					== expected_activation_identity


func _active_maneuver_execution_is_valid(execution: Dictionary) -> bool:
	return _active_maneuver_execution_is_valid_for(
			execution, ship_activation_identity,
			maneuver_opportunity_disposition, _destroyed)


static func _active_maneuver_execution_is_valid_for(execution: Dictionary,
		activation_identity: String, maneuver_disposition: String,
		destroyed: bool) -> bool:
	if execution.is_empty():
		return true
	var expected_fields: Array[String] = [
		"maneuver_execution_id", "ship_activation_identity",
		"navigate_speed_changed", "final_transform_applied",
		"obstacle_resolution_order",
		"ship_collision",
	]
	var transform_applied: Variant = execution.get("final_transform_applied")
	if typeof(transform_applied) != TYPE_BOOL:
		return false
	var requires_committed_result: bool = not bool(transform_applied)
	var expected_size: int = expected_fields.size() + (
			1 if requires_committed_result else 0)
	if execution.size() != expected_size \
			or execution.has("committed_result") != requires_committed_result:
		return false
	for field: String in expected_fields:
		if not execution.has(field):
			return false
	if destroyed or activation_identity.is_empty() \
			or maneuver_disposition != ACTIVATION_DISPOSITION_OPEN \
			or str(execution["maneuver_execution_id"]).is_empty() \
			or str(execution["ship_activation_identity"]) \
					!= activation_identity \
			or typeof(execution["navigate_speed_changed"]) != TYPE_BOOL \
			or not execution["obstacle_resolution_order"] is Array \
			or not execution["ship_collision"] is Dictionary:
		return false
	if requires_committed_result and not (
			execution["committed_result"] is Dictionary) \
			or (requires_committed_result and not
					_maneuver_committed_result_is_valid(
						execution["committed_result"] as Dictionary)):
		return false
	var seen_obstacles: Dictionary = {}
	for raw_obstacle: Variant in execution["obstacle_resolution_order"] as Array:
		if typeof(raw_obstacle) != TYPE_STRING:
			return false
		var obstacle_id: String = raw_obstacle as String
		if obstacle_id.is_empty() or seen_obstacles.has(obstacle_id):
			return false
		seen_obstacles[obstacle_id] = true
	return _maneuver_ship_collision_is_valid(
			execution["ship_collision"] as Dictionary,
			activation_identity, str(execution["maneuver_execution_id"]))


static func _obstacle_resolution_records_are_valid_for(execution: Dictionary,
		asteroid: Dictionary, debris: Dictionary,
		station: Dictionary) -> bool:
	var populated: int = int(not asteroid.is_empty()) \
			+ int(not debris.is_empty()) + int(not station.is_empty())
	if populated > 1:
		return false
	if populated == 0:
		return true
	if execution.is_empty() \
			or not bool(execution.get("final_transform_applied", false)):
		return false
	var activation_id: String = str(execution.get(
			"ship_activation_identity", ""))
	var execution_id: String = str(execution.get(
			"maneuver_execution_id", ""))
	if not asteroid.is_empty():
		return _exact_string_record(asteroid, [
			"maneuver_execution_id", "ship_activation_identity",
			"obstacle_id", "immediate_resolution_id", "disposition"]) \
			and asteroid["maneuver_execution_id"] == execution_id \
			and asteroid["ship_activation_identity"] == activation_id \
			and asteroid["disposition"] == "OPEN"
	var record: Dictionary = debris if not debris.is_empty() else station
	return record.size() == 5 \
			and typeof(record.get("maneuver_execution_id")) == TYPE_STRING \
			and record["maneuver_execution_id"] == execution_id \
			and typeof(record.get("ship_activation_identity")) == TYPE_STRING \
			and record["ship_activation_identity"] == activation_id \
			and typeof(record.get("obstacle_id")) == TYPE_STRING \
			and not str(record["obstacle_id"]).is_empty() \
			and typeof(record.get("controller_player")) == TYPE_INT \
			and int(record["controller_player"]) in [0, 1] \
			and record.get("disposition") == "OPEN"


## Cross-validates the only legal nested Maneuver immediate obligation.
## Asteroid owns the return binding while ADR-014 owns the physical card and
## immediate-effect identity; neither record may survive without the other.
func _nested_maneuver_immediate_state_is_valid() -> bool:
	var immediate_kind: String = str(_active_immediate_resolution.get(
			"enclosing_kind", ""))
	if _active_asteroid_resolution.is_empty():
		return immediate_kind != "maneuver"
	if immediate_kind != "maneuver":
		return false
	return str(_active_asteroid_resolution.get(
			"immediate_resolution_id", "")) \
			== str(_active_immediate_resolution.get(
					"immediate_resolution_id", "")) \
			and str(_active_asteroid_resolution.get("obstacle_id", "")) \
					== str(_active_immediate_resolution.get(
							"maneuver_source_id", "")) \
			and str(_active_asteroid_resolution.get(
					"maneuver_execution_id", "")) \
					== str(_active_immediate_resolution.get(
							"maneuver_execution_id", "")) \
			and str(_active_asteroid_resolution.get(
					"ship_activation_identity", "")) \
					== str(_active_immediate_resolution.get(
							"ship_activation_identity", ""))


static func _exact_string_record(record: Dictionary,
		fields: Array[String]) -> bool:
	if record.size() != fields.size():
		return false
	for field: String in fields:
		if typeof(record.get(field)) != TYPE_STRING \
				or str(record[field]).is_empty():
			return false
	return true


static func _maneuver_committed_result_is_valid(result: Dictionary) -> bool:
	var fields: Array[String] = [
		"yaw_clicks", "yaw_bonus_joint", "pos_x", "pos_y", "rotation_deg",
	]
	if result.size() != fields.size():
		return false
	for field: String in fields:
		if not result.has(field):
			return false
	if not result["yaw_clicks"] is Array \
			or typeof(result["yaw_bonus_joint"]) != TYPE_INT:
		return false
	for raw_click: Variant in result["yaw_clicks"] as Array:
		if typeof(raw_click) != TYPE_INT:
			return false
	for field: String in ["pos_x", "pos_y", "rotation_deg"]:
		if typeof(result[field]) != TYPE_FLOAT \
				or not is_finite(float(result[field])):
			return false
	return true


static func _maneuver_ship_collision_is_valid(collision: Dictionary,
		activation_identity: String, execution_id: String) -> bool:
	var kind: String = str(collision.get("kind", ""))
	if kind == "none":
		return collision.size() == 1
	if kind != "closest_ship":
		return false
	var fields: Array[String] = [
		"kind", "target_owner_player", "target_ship_index",
		"exact_once_key", "damage_resolved",
	]
	if collision.size() != fields.size():
		return false
	for field: String in fields:
		if not collision.has(field):
			return false
	if typeof(collision["target_owner_player"]) != TYPE_INT \
			or typeof(collision["target_ship_index"]) != TYPE_INT \
			or typeof(collision["damage_resolved"]) != TYPE_BOOL:
		return false
	var target_owner: int = int(collision["target_owner_player"])
	var target_index: int = int(collision["target_ship_index"])
	if target_owner < 0 or target_owner > 1 or target_index < 0:
		return false
	return str(collision["exact_once_key"]) == \
			"collision:%s:%s:%d:%d" % [activation_identity,
				execution_id, target_owner, target_index]


static func _ship_activation_boundary_values_are_valid(identity: String,
		squadron_disposition: String, maneuver_disposition: String,
		committed: int, destroyed: bool) -> bool:
	if identity.is_empty():
		return squadron_disposition == ACTIVATION_DISPOSITION_INACTIVE \
				and maneuver_disposition == ACTIVATION_DISPOSITION_INACTIVE \
				and committed == 0
	if destroyed or committed < 0:
		return false
	var valid_dispositions: Array[String] = [
		ACTIVATION_DISPOSITION_UNREACHED,
		ACTIVATION_DISPOSITION_OPEN,
		ACTIVATION_DISPOSITION_CONSUMED,
	]
	if squadron_disposition not in valid_dispositions \
			or maneuver_disposition not in valid_dispositions:
		return false
	# A positive commitment proves the opportunity was opened. It may remain
	# after the opportunity is later consumed, but it is invalid while UNREACHED.
	return committed == 0 \
			or squadron_disposition != ACTIVATION_DISPOSITION_UNREACHED


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
	var data: Dictionary = {
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
		"faceup_damage": [],
		"active_immediate_resolution":
				_active_immediate_resolution.duplicate(true),
		"active_maneuver_execution":
				_active_maneuver_execution.duplicate(true),
		"active_asteroid_resolution":
				_active_asteroid_resolution.duplicate(true),
		"active_debris_resolution":
				_active_debris_resolution.duplicate(true),
		"active_station_resolution":
				_active_station_resolution.duplicate(true),
		"activated_this_round": activated_this_round,
		"attack_step_active": attack_step_active,
		"committed_attack_count": committed_attack_count,
		"used_attack_hull_zones": used_attack_hull_zones.duplicate(),
		"anti_squadron_attack_zone": anti_squadron_attack_zone,
		"anti_squadron_target_history":
				anti_squadron_target_history.duplicate(true),
		"ship_activation_identity": ship_activation_identity,
		"squadron_command_opportunity_disposition":
				squadron_command_opportunity_disposition,
		"maneuver_opportunity_disposition": maneuver_opportunity_disposition,
		"squadron_command_activations_committed":
				squadron_command_activations_committed,
		"owner_player": owner_player,
		"destroyed": _destroyed,
		"command_dial_stack": command_dial_stack.serialize() \
				if command_dial_stack else {},
		"command_tokens": command_tokens.serialize() \
				if command_tokens else {},
		"runtime_upgrades": _serialize_runtime_upgrades(),
	}
	if is_passive_damage_bound():
		for card: DamageCard in faceup_damage:
			data["faceup_damage"].append(card.public_faceup_damage_card())
		data["facedown_count"] = get_facedown_damage_count()
	else:
		for card: DamageCard in faceup_damage:
			data["faceup_damage"].append(card.serialize_for_save7("ship"))
		data["facedown_damage"] = []
		for card: DamageCard in facedown_damage:
			data["facedown_damage"].append(card.serialize_for_save7("ship"))
	return data


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
	inst.attack_step_active = bool(data.get("attack_step_active", false))
	inst.committed_attack_count = int(data.get("committed_attack_count", 0))
	for zone: Variant in data.get("used_attack_hull_zones", []):
		inst.used_attack_hull_zones.append(int(zone))
	inst.anti_squadron_attack_zone = int(data.get(
			"anti_squadron_attack_zone", -1))
	for target: Variant in data.get("anti_squadron_target_history", []):
		if target is Dictionary:
			var target_data: Dictionary = target as Dictionary
			inst.anti_squadron_target_history.append(
					_make_squadron_target_ref(
							int(target_data.get("owner", -1)),
								int(target_data.get("index", -1))))
	inst.ship_activation_identity = str(data.get(
			"ship_activation_identity", ""))
	inst.squadron_command_opportunity_disposition = str(data.get(
			"squadron_command_opportunity_disposition",
			ACTIVATION_DISPOSITION_INACTIVE))
	inst.maneuver_opportunity_disposition = str(data.get(
			"maneuver_opportunity_disposition",
			ACTIVATION_DISPOSITION_INACTIVE))
	inst.squadron_command_activations_committed = int(data.get(
			"squadron_command_activations_committed", 0))
	inst.owner_player = int(data.get("owner_player", 0))
	inst._log_attack_progress("deserialize")
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
	var passive: bool = data.has("facedown_count")
	if not passive:
		for cd: Variant in data.get("facedown_damage", []):
			if not cd is Dictionary: return null
			var card := DamageCard.deserialize_for_save7(cd as Dictionary,"ship")
			if card == null or card.is_faceup: return null
			inst.facedown_damage.append(card)
	for cd: Variant in data.get("faceup_damage", []):
		if not cd is Dictionary: return null
		var card: DamageCard = DamageCard.deserialize_public_faceup(cd as Dictionary) if passive else DamageCard.deserialize_for_save7(cd as Dictionary,"ship")
		if card == null or not card.is_faceup: return null
		inst.faceup_damage.append(card)
	var immediate: Variant = data.get("active_immediate_resolution", {})
	if not immediate is Dictionary: return null
	inst._active_immediate_resolution = (immediate as Dictionary).duplicate(true)
	var maneuver_data := {
		"active_maneuver_execution": data.get("active_maneuver_execution", {}),
		"active_asteroid_resolution": data.get("active_asteroid_resolution", {}),
		"active_debris_resolution": data.get("active_debris_resolution", {}),
		"active_station_resolution": data.get("active_station_resolution", {}),
	}
	if not inst.install_maneuver_execution_for_save7(maneuver_data): return null
	if passive:
		if not inst._active_immediate_resolution.is_empty() \
				and not inst._filtered_immediate_resolution_is_valid(
						inst._active_immediate_resolution): return null
	elif not inst.validate_damage_state_for_save7(): return null
	if not inst.validate_maneuver_immediate_nesting(): return null
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

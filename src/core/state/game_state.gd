## Game State
##
## Represents the complete state of an Armada game at any point in time.
## Holds all mutable game data: round number, phase, player states, etc.
## Designed to be serializable for save/load functionality.
class_name GameState
extends RefCounted


const TIMING_WINDOW_STATE: GDScript = preload(
		"res://src/core/state/timing_window_state.gd")
const TIMING_WINDOW_ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const CURRENT_ATTACK_STATE: GDScript = preload(
		"res://src/core/state/current_attack_state.gd")

const SQUADRON_PHASE_CONTROLLER_INACTIVE: int = -1

## The current round number (1-based, max defined by Constants.MAX_ROUNDS).
var current_round: int = 0

## The current game phase.
var current_phase: Constants.GamePhase = Constants.GamePhase.SETUP

## Player states indexed by player number (0 and 1).
var player_states: Array[PlayerState] = []

## The initiative player index (0 or 1).
var initiative_player: int = 0

## Canonical Squadron Phase turn progress.
var squadron_phase_controller_player: int = SQUADRON_PHASE_CONTROLLER_INACTIVE
var squadron_phase_activations_committed: int = 0

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

## Authoritative timing-window lifecycle state.
## Slice 1 stores lifecycle identity only. InteractionFlow remains a
## non-authoritative legacy/presentation surface for timing-window lifecycle.
var _timing_window_state: TimingWindowState = null

var timing_window_state: TimingWindowState:
	get:
		return _timing_window_state

## Canonical authoritative state for one individual attack.
var _current_attack_state: CurrentAttackState = null

var current_attack_state: CurrentAttackState:
	get:
		return _clone_current_attack_state(_current_attack_state)

## Per-round count of ship-targeting attacks performed by each ship.
## Keys are `round:owner_player:ship_index`; values are ints.
## Used by Coolant Discharge and serialized for save/replay determinism.
var ship_target_attack_counts: Dictionary = {}


func _init() -> void:
	_timing_window_state = _new_timing_window_state()
	_current_attack_state = _new_current_attack_state()


## Initializes a new game state with default values.
func initialize() -> void:
	current_round = 0
	current_phase = Constants.GamePhase.SETUP
	initiative_player = 0
	squadron_phase_controller_player = SQUADRON_PHASE_CONTROLLER_INACTIVE
	squadron_phase_activations_committed = 0
	if rng == null:
		rng = GameRng.new()
	interaction_flow = InteractionFlow.new()
	_timing_window_state = _new_timing_window_state()
	_current_attack_state = _new_current_attack_state()
	objectives.clear()
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


## Returns whether the owner-local Squadron Phase progress is active.
func has_squadron_phase_controller() -> bool:
	return squadron_phase_controller_player \
			!= SQUADRON_PHASE_CONTROLLER_INACTIVE


## Validates the owner-local Squadron Phase controller/count state.
func validate_squadron_phase_progress() -> bool:
	return _squadron_phase_progress_values_are_valid(
			squadron_phase_controller_player,
			squadron_phase_activations_committed)


## Returns a JSON-safe snapshot for later atomic command rollback.
func squadron_phase_progress_snapshot() -> Dictionary:
	return {
		"squadron_phase_controller_player": squadron_phase_controller_player,
		"squadron_phase_activations_committed":
				squadron_phase_activations_committed,
	}


## Restores a snapshot produced by [method squadron_phase_progress_snapshot].
func restore_squadron_phase_progress(snapshot: Dictionary) -> bool:
	if not snapshot.has("squadron_phase_controller_player") \
			or not snapshot.has("squadron_phase_activations_committed"):
		return false
	var controller: int = int(snapshot["squadron_phase_controller_player"])
	var committed: int = int(snapshot["squadron_phase_activations_committed"])
	if not _squadron_phase_progress_values_are_valid(controller, committed):
		return false
	squadron_phase_controller_player = controller
	squadron_phase_activations_committed = committed
	return true


## Initializes the canonical Squadron Phase controller/count at phase entry.
func initialize_squadron_phase_progress(controller: int) -> bool:
	if current_phase != Constants.GamePhase.SQUADRON \
			or controller < 0 or controller >= Constants.PLAYER_COUNT:
		return false
	squadron_phase_controller_player = controller
	squadron_phase_activations_committed = 0
	return validate_squadron_phase_progress()


## Clears the canonical Squadron Phase controller/count at phase exit.
func clear_squadron_phase_progress() -> void:
	squadron_phase_controller_player = SQUADRON_PHASE_CONTROLLER_INACTIVE
	squadron_phase_activations_committed = 0


## Commits one completed Squadron Phase activation and derives the next
## controller from canonical round eligibility. The caller owns rollback of
## this owner-local mutation together with the completing SquadronInstance.
func commit_squadron_phase_activation(controller: int) -> Dictionary:
	if current_phase != Constants.GamePhase.SQUADRON \
			or controller != squadron_phase_controller_player \
			or squadron_phase_activations_committed \
					>= Constants.SQUADRONS_PER_ACTIVATION:
		return {}
	squadron_phase_activations_committed += 1
	var same_has: bool = has_unactivated_squadrons(controller)
	var other: int = Constants.PLAYER_COUNT - 1 - controller
	var other_has: bool = has_unactivated_squadrons(other)
	var phase_complete: bool = false
	if squadron_phase_activations_committed \
			< Constants.SQUADRONS_PER_ACTIVATION and same_has:
		pass
	elif other_has:
		squadron_phase_controller_player = other
		squadron_phase_activations_committed = 0
	elif same_has:
		# The opponent auto-passes; the same player begins a fresh turn.
		squadron_phase_activations_committed = 0
	else:
		clear_squadron_phase_progress()
		phase_complete = true
	if not validate_squadron_phase_progress():
		return {}
	return {
		"controller_player": squadron_phase_controller_player,
		"activations_committed": squadron_phase_activations_committed,
		"phase_complete": phase_complete,
	}


## Returns whether a player controls at least one surviving unactivated
## squadron. This is the canonical eligibility input for phase handoff.
func has_unactivated_squadrons(player_index: int) -> bool:
	if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
		return false
	var player_state: PlayerState = get_player_state(player_index)
	if player_state == null:
		return false
	for raw_squadron: Variant in player_state.squadrons:
		if raw_squadron is SquadronInstance:
			var squadron: SquadronInstance = raw_squadron as SquadronInstance
			if not squadron.is_destroyed() \
					and not squadron.activated_this_round:
				return true
	return false


## Returns the unique active (not yet round-complete) squadron activation, or
## null when none exists. Invalid duplicate states are rejected separately by
## [method validate_declaration_adjacent_state].
func get_active_squadron_activation() -> SquadronInstance:
	var active: SquadronInstance = null
	for player_state: PlayerState in player_states:
		if player_state == null:
			continue
		for raw_squadron: Variant in player_state.squadrons:
			if not (raw_squadron is SquadronInstance):
				continue
			var squadron: SquadronInstance = raw_squadron as SquadronInstance
			if not squadron.has_activation_action_state() \
					or squadron.activated_this_round:
				continue
			if active != null:
				return null
			active = squadron
	return active


## Validates every TWI-003 owner and the cross-owner references/uniqueness
## required before save, reconnect, replay, or mirror state is installed.
func validate_declaration_adjacent_state() -> bool:
	if not validate_squadron_phase_progress() \
			or not validate_ship_activation_identity_aggregate():
		return false
	var active_squadron: SquadronInstance = null
	for player_state: PlayerState in player_states:
		if player_state == null:
			continue
		for raw_squadron: Variant in player_state.squadrons:
			if not (raw_squadron is SquadronInstance):
				return false
			var squadron: SquadronInstance = raw_squadron as SquadronInstance
			if not squadron.is_activation_action_state_valid():
				return false
			if squadron.activation_context \
					== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
				var commanding_ship: ShipInstance = get_ship(
						squadron.commanding_ship_player,
						squadron.commanding_ship_index)
				if commanding_ship == null \
						or squadron.commanding_ship_player != squadron.owner_player:
					return false
			if not squadron.has_activation_action_state() \
					or squadron.activated_this_round:
				continue
			if active_squadron != null:
				return false
			active_squadron = squadron
			if squadron.activation_context \
					== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
				if current_phase != Constants.GamePhase.SQUADRON \
						or squadron.owner_player \
								!= squadron_phase_controller_player \
						or squadron_phase_activations_committed \
								>= Constants.SQUADRONS_PER_ACTIVATION:
					return false
			else:
				var active_ship: ShipInstance = get_ship(
						squadron.commanding_ship_player,
						squadron.commanding_ship_index)
				var command_capacity: int = \
						SquadronCommandResolver.authoritative_capacity(active_ship)
				if current_phase != Constants.GamePhase.SHIP \
						or active_ship == null \
						or not active_ship.has_active_ship_activation() \
						or active_ship.squadron_command_opportunity_disposition \
								!= ShipInstance.ACTIVATION_DISPOSITION_OPEN \
						or active_ship.squadron_command_activations_committed <= 0 \
						or active_ship.squadron_command_activations_committed \
								> command_capacity:
					return false
	var attack: CurrentAttackState = _current_attack_state
	if attack != null and attack.active \
			and attack.attack_kind \
					== SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD:
		if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
			var attacker_ship: ShipInstance = get_ship(
					attack.attacker_player, attack.attacker_index)
			if attacker_ship == null \
					or not attacker_ship.has_active_ship_activation() \
					or not attacker_ship.attack_step_active:
				return false
		elif attack.attacker_kind == CurrentAttackState.KIND_SQUADRON:
			var attacker_squadron: SquadronInstance = get_squadron(
					attack.attacker_player, attack.attacker_index)
			if attacker_squadron == null \
					or attacker_squadron != active_squadron \
					or attacker_squadron.attack_action_disposition \
							!= SquadronInstance.ATTACK_ACTION_BEGUN:
				return false
	return true


## Read-only aggregate validation for the ADR-006 cross-fleet uniqueness rule.
## ShipInstance remains the sole writable owner of each activation identity.
func validate_ship_activation_identity_aggregate() -> bool:
	var active_count: int = 0
	for player_state: PlayerState in player_states:
		if player_state == null:
			continue
		for ship: ShipInstance in player_state.ships:
			if ship == null:
				continue
			if not ship.validate_ship_activation_boundary():
				return false
			if ship.has_active_ship_activation():
				active_count += 1
				if active_count > 1:
					return false
	return true


## Returns the unique ship carrying the active ADR-006 boundary, or null.
## Callers must treat a null result as inactive or invalid; this method never
## reconstructs authority from presentation state.
func get_active_ship_activation() -> ShipInstance:
	var active_ship: ShipInstance = null
	for player_state: PlayerState in player_states:
		if player_state == null:
			continue
		for raw_ship: Variant in player_state.ships:
			if not (raw_ship is ShipInstance):
				continue
			var ship: ShipInstance = raw_ship as ShipInstance
			if not ship.has_active_ship_activation():
				continue
			if active_ship != null:
				return null
			active_ship = ship
	return active_ship


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
		"squadron_phase_controller_player":
				squadron_phase_controller_player,
		"squadron_phase_activations_committed":
				squadron_phase_activations_committed,
		"objectives": objectives.duplicate(true),
		"player_states": [],
		"damage_deck": damage_deck.serialize() if damage_deck else {},
		"rng": rng.serialize() if rng else {},
		"interaction_flow": interaction_flow.serialize() if interaction_flow else {},
		"timing_window_state": _timing_window_state.serialize()
					if _timing_window_state else _new_timing_window_state().serialize(),
		"current_attack_state": _current_attack_state.serialize()
					if _current_attack_state else _new_current_attack_state().serialize(),
		"ship_target_attack_counts": ship_target_attack_counts.duplicate(true),
	}
	for player_state: PlayerState in player_states:
		data["player_states"].append(player_state.serialize())
	return data


## Deserializes a game state from a saved dictionary.
## Ship/squadron reconstruction inside each PlayerState is left to the
## caller because it requires template look-ups (ShipData / SquadronData).
static func deserialize(data: Dictionary) -> GameState:
	if not _serialized_declaration_fields_are_complete(data):
		return null
	var state := GameState.new()
	state.current_round = data.get("current_round", 0)
	state.current_phase = int(data.get("current_phase", 0)) as Constants.GamePhase
	state.initiative_player = data.get("initiative_player", 0)
	state.squadron_phase_controller_player = int(
			data["squadron_phase_controller_player"])
	state.squadron_phase_activations_committed = int(
			data["squadron_phase_activations_committed"])
	var objective_data: Variant = data.get("objectives", {})
	if objective_data is Dictionary:
		state.objectives = (objective_data as Dictionary).duplicate(true)
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
	var had_current_attack_state: bool = data.has("current_attack_state")
	if had_current_attack_state:
		var current_attack = _new_current_attack_state()
		if not current_attack.load_from_serialized(data.get("current_attack_state")):
			return null
		state._current_attack_state = current_attack
	else:
		state._current_attack_state = _new_current_attack_state()
	if state.interaction_flow != null \
			and state.interaction_flow.flow_type == Constants.InteractionFlow.ATTACK \
			and not state._current_attack_state.active:
		return null
	if data.has("timing_window_state"):
		var timing_state = _new_timing_window_state()
		if not timing_state.load_from_serialized(
				data.get("timing_window_state")):
			return null
		state._timing_window_state = timing_state
	else:
		state._timing_window_state = _new_timing_window_state()
	if not state.validate_current_attack_references():
		return null
	if not state.validate_declaration_adjacent_state():
		return null
	if not bool(TIMING_WINDOW_ORCHESTRATOR.validate_reconstructed_state(
			state).get(TIMING_WINDOW_ORCHESTRATOR.KEY_OK, false)):
		return null
	var h9_rule: GDScript = load(
			"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd") \
			as GDScript
	if h9_rule == null \
			or not str(h9_rule.call(
					"validate_reconstructed_state", state)).is_empty():
		return null
	return state


static func _serialized_declaration_fields_are_complete(
		data: Dictionary) -> bool:
	if not data.has("squadron_phase_controller_player") \
			or not data.has("squadron_phase_activations_committed"):
		return false
	var raw_players: Variant = data.get("player_states", [])
	if not (raw_players is Array):
		return false
	for raw_player: Variant in raw_players as Array:
		if not (raw_player is Dictionary):
			return false
		var player_data: Dictionary = raw_player as Dictionary
		for raw_ship: Variant in player_data.get("ships", []):
			if not (raw_ship is Dictionary):
				return false
			for key: String in [
					"ship_activation_identity",
					"squadron_command_opportunity_disposition",
					"maneuver_opportunity_disposition",
					"squadron_command_activations_committed"]:
				if not (raw_ship as Dictionary).has(key):
					return false
		for raw_squadron: Variant in player_data.get("squadrons", []):
			if not (raw_squadron is Dictionary):
				return false
			for key: String in [
					"activation_id", "activation_context",
					"commanding_ship_player", "commanding_ship_index",
					"move_action_committed",
					"attack_action_disposition"]:
				if not (raw_squadron as Dictionary).has(key):
					return false
	return true


func set_timing_window_state(value: TimingWindowState) -> bool:
	if value == null or not value.is_valid():
		return false
	var replacement: TimingWindowState = _new_timing_window_state()
	if not replacement.load_from_serialized(value.serialize()):
		return false
	_timing_window_state = replacement
	return true


func set_current_attack_state(value: CurrentAttackState) -> bool:
	if value == null or not value.is_valid():
		return false
	var replacement: CurrentAttackState = _new_current_attack_state()
	if not replacement.load_from_serialized(value.serialize()):
		return false
	if not _validate_current_attack_references_for(replacement):
		return false
	_current_attack_state = replacement
	return true


func validate_current_attack_references() -> bool:
	return _validate_current_attack_references_for(_current_attack_state)


func _validate_current_attack_references_for(value: CurrentAttackState) -> bool:
	if value == null or not value.is_valid():
		return false
	if not value.active:
		return true
	if current_phase != Constants.GamePhase.SHIP \
			and current_phase != Constants.GamePhase.SQUADRON:
		return false
	if not _current_attack_entity_exists(
			value.attacker_kind, value.attacker_player, value.attacker_index):
		return false
	if not _current_attack_entity_exists(
			value.defender_kind, value.defender_player, value.defender_index):
		return false
	var defender: RefCounted = _current_attack_entity(
			value.defender_kind, value.defender_player, value.defender_index)
	if defender == null:
		return false
	var defense_tokens: Array = defender.get("defense_tokens") as Array
	for token_index: int in value.accuracy_locked_tokens:
		if token_index < 0 or token_index >= defense_tokens.size():
			return false
	for token_index: int in value.committed_defense_tokens:
		if token_index < 0 or token_index >= defense_tokens.size():
			return false
	for effect: Dictionary in value.resolved_defense_effects:
		var token_index: int = int(effect.get("token_index", -1))
		if not value.committed_defense_tokens.has(token_index) \
				or token_index < 0 or token_index >= defense_tokens.size() \
				or int(effect.get("token_type", -1)) \
						!= int((defense_tokens[token_index] as Dictionary).get(
								"type", -1)):
			return false
	var evade: Dictionary = value.pending_evade
	if not evade.is_empty():
		var die_index: int = int(evade.get("die_index", -1))
		var dice: Array[Dictionary] = value.dice_results
		if die_index < 0 or die_index >= dice.size():
			return false
		var die: Dictionary = dice[die_index]
		if int(evade.get("expected_color", -1)) != int(die.get("color", -2)) \
				or int(evade.get("expected_face", -1)) != int(die.get("face", -2)):
			return false
	return true


func _current_attack_entity_exists(kind: String, owner: int, index: int) -> bool:
	return _current_attack_entity(kind, owner, index) != null


func _current_attack_entity(kind: String, owner: int, index: int) -> RefCounted:
	if kind == CurrentAttackState.KIND_SHIP:
		return get_ship(owner, index)
	if kind == CurrentAttackState.KIND_SQUADRON:
		return get_squadron(owner, index)
	return null


static func _new_timing_window_state():
	return TIMING_WINDOW_STATE.new()


static func _new_current_attack_state():
	return CURRENT_ATTACK_STATE.new()


static func _clone_current_attack_state(value: CurrentAttackState):
	var clone = _new_current_attack_state()
	if value != null:
		clone.load_from_serialized(value.serialize())
	return clone


static func _deserialize_attack_counts(raw_counts: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if not raw_counts is Dictionary:
		return counts
	var saved_counts: Dictionary = raw_counts as Dictionary
	for raw_key: Variant in saved_counts.keys():
		counts[str(raw_key)] = int(saved_counts[raw_key])
	return counts


func _squadron_phase_progress_values_are_valid(
		controller: int, committed: int) -> bool:
	if committed < 0 or committed > Constants.SQUADRONS_PER_ACTIVATION:
		return false
	if controller == SQUADRON_PHASE_CONTROLLER_INACTIVE:
		return committed == 0
	if controller < 0 or controller >= Constants.PLAYER_COUNT:
		return false
	return current_phase == Constants.GamePhase.SQUADRON

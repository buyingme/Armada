## Fleet Setup Bootstrapper
##
## Converts a match-ready [FleetSetupPackage] into an initialized [GameState]
## before gameplay commands begin. This keeps fleet setup bootstrap scene-tree
## independent and lets hot-seat, network, replay, and save/load paths consume
## the same package payload.
class_name FleetSetupBootstrapper
extends RefCounted


const KEY_OBSTACLES: String = "obstacles"
const KEY_MAP: String = "map"
const KEY_POINT_FORMAT: String = "point_format"
const KEY_SELECTED_OBJECTIVE: String = "selected_objective"
const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"
const KEY_SETUP_STATE: String = "setup_state"
const RULE_RUNTIME_RESULT: String = "setup.bootstrap.runtime"


## Builds an initialized [GameState] from [param package].
## [param config] may include [code]"rng_seed"[/code] for deterministic decks.
## Rules Reference: "Setup", steps 1-6, RRG p.16; DM-007 setup shuffle.
static func build_game_state(
		package: FleetSetupPackage,
		config: Dictionary = {}) -> Dictionary:
	var runtime: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var validation: SetupValidationResult = _runtime_validation(runtime)
	if validation == null:
		validation = SetupValidationResult.new()
		validation.add_error(RULE_RUNTIME_RESULT,
				"Runtime setup conversion did not return validation data.", [], [])
		return _build_result(false, null, validation, "")
	if not bool(runtime.get("ok", false)):
		return _build_result(false, null, validation, "")
	var state: GameState = _create_initialized_state(config)
	_attach_package_runtime(state, package, runtime)
	_attach_setup_payload(state, package)
	_initialize_damage_deck(state)
	return _build_result(true, state, validation, package.canonical_hash())


static func _create_initialized_state(config: Dictionary) -> GameState:
	var state: GameState = GameState.new()
	var seed_value: int = int(config.get("rng_seed", 0))
	if seed_value != 0:
		state.rng = GameRng.new(seed_value)
	state.initialize()
	return state


static func _attach_package_runtime(
		state: GameState,
		package: FleetSetupPackage,
		runtime: Dictionary) -> void:
	state.player_states = _read_player_states(runtime.get("player_states", []))
	state.initiative_player = package.first_player


static func _attach_setup_payload(
		state: GameState,
		package: FleetSetupPackage) -> void:
	state.objectives = {
		KEY_SELECTED_OBJECTIVE: package.selected_objective.duplicate(true),
		KEY_SETUP_STATE: package.setup_state.duplicate(true),
		KEY_OBSTACLES: _copy_dict_array(package.obstacles),
		KEY_MAP: package.map.duplicate(true),
		KEY_POINT_FORMAT: package.point_format.duplicate(true),
		KEY_SETUP_PACKAGE_HASH: package.canonical_hash(),
	}


static func _initialize_damage_deck(state: GameState) -> void:
	var deck: DamageDeck = DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck


static func _runtime_validation(runtime: Dictionary) -> SetupValidationResult:
	var validation_variant: Variant = runtime.get("validation", null)
	if validation_variant is SetupValidationResult:
		return validation_variant as SetupValidationResult
	return null


static func _read_player_states(raw_states: Variant) -> Array[PlayerState]:
	var states: Array[PlayerState] = []
	if not raw_states is Array:
		return states
	for raw_state: Variant in raw_states as Array:
		if raw_state is PlayerState:
			states.append(raw_state as PlayerState)
	return states


static func _copy_dict_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


static func _build_result(ok: bool, state: GameState,
		validation: SetupValidationResult, package_hash: String) -> Dictionary:
	return {
		"ok": ok,
		"state": state,
		"validation": validation,
		"package_hash": package_hash,
	}
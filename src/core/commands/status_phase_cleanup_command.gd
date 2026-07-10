## StatusPhaseCleanupCommand
##
## Performs all end-of-round state changes during the Status Phase:
##
##   1. Ready all exhausted defense tokens (ships + squadrons).
##   2. Reset activation flags on all surviving units.
##   3. Clear spent-dial history on ship command stacks.
##
## The Compartment Fire damage card may block token readying for individual
## ships — this is resolved through RuleRegistry status-cleanup modifiers.
##
## Payload:  (none required — fully deterministic from GameState)
##
## Rules Reference: "Status Phase", p.6; ST-001, ST-004;
## "Compartment Fire" card text (blocks readying).
class_name StatusPhaseCleanupCommand
extends GameCommand


const TARGET_DEFENSE_TOKEN_READYING: String = "defense_token_readying"
const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("status_phase_cleanup",
			func(player: int, pl: Dictionary) -> GameCommand:
		return StatusPhaseCleanupCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "status_phase_cleanup", p_payload)


## Must be in STATUS phase.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.STATUS:
		return "Status phase cleanup can only run during STATUS phase."
	return ""


## Performs cleanup across all players' fleets.
## Returns {"ships_readied": int, "ships_blocked": Array[String],
##          "squadrons_readied": int, "activations_reset": int}.
func execute(game_state: GameState) -> Dictionary:
	var result: Dictionary = {
		"ships_readied": 0,
		"ships_blocked": [] as Array[String],
		"squadrons_readied": 0,
		"activations_reset": 0,
	}

	for i: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = game_state.get_player_state(i)
		if ps == null:
			continue
		_cleanup_ships(game_state, ps, result)
		_cleanup_squadrons(ps, result)
	ECM_SCRIPT.clear_stale_status_ready_cost_window_state(game_state)
	_enter_status_ready_cost_flow(game_state, result)

	return result


func _enter_status_ready_cost_flow(game_state: GameState,
		result: Dictionary) -> void:
	var payload: Dictionary = ECM_SCRIPT.decorate_status_ready_cost_payload(
			game_state, {"status_phase_cleanup_complete": true})
	result["optional_status_rules"] = payload.get("optional_status_rules", [])
	result[ECM_SCRIPT.READY_COST_AFFORDANCE_KEY] = payload.get(
			ECM_SCRIPT.READY_COST_AFFORDANCE_KEY, [])
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP,
			game_state,
			{},
			Constants.Visibility.ALL,
			payload)


## Process ships for one player.  Mutates [param result] counters.
func _cleanup_ships(game_state: GameState, ps: PlayerState,
		result: Dictionary) -> void:
	for s: Variant in ps.ships:
		if not (s is ShipInstance):
			continue
		var si: ShipInstance = s as ShipInstance
		if si.is_destroyed():
			continue
		if _is_token_ready_blocked(game_state, si):
			result["ships_blocked"].append(si.data_key)
		else:
			si.ready_defense_tokens()
			result["ships_readied"] += 1
		si.reset_activation()
		if si.command_dial_stack != null:
			si.command_dial_stack.clear_spent_history()
		result["activations_reset"] += 1


## Process squadrons for one player.  Mutates [param result] counters.
func _cleanup_squadrons(ps: PlayerState,
		result: Dictionary) -> void:
	for sq: Variant in ps.squadrons:
		if not (sq is SquadronInstance):
			continue
		var sqi: SquadronInstance = sq as SquadronInstance
		if sqi.is_destroyed():
			continue
		sqi.ready_defense_tokens()
		sqi.reset_activation()
		result["squadrons_readied"] += 1
		result["activations_reset"] += 1


## Returns true if a status-cleanup rule cancels readying for [param ship].
func _is_token_ready_blocked(game_state: GameState,
		ship: ShipInstance) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx = _apply_rule_ready_modifiers(ctx)
	return ctx.cancelled


func _apply_rule_ready_modifiers(ctx: EffectContext) -> EffectContext:
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(Constants.InteractionFlow.STATUS_CLEANUP),
			int(Constants.InteractionStep.STATUS_CLEANUP_STEP),
			TARGET_DEFENSE_TOKEN_READYING)
	for hook: FlowHook in hooks:
		if not hook.callback.is_valid():
			continue
		var raw: Variant = hook.callback.call(ctx)
		if raw is EffectContext:
			ctx = raw as EffectContext
	return ctx

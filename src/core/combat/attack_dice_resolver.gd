## AttackDiceResolver
##
## Pure-computation helper that resolves armament, dice pools, Concentrate
## Fire detection, obstruction removal, gather-dice hooks, damage
## calculation, and damage-card attack-blocking checks.
##
## Every public method is stateless: callers pass a [CombatParticipants]
## bundle (and optionally an [EffectRegistry]) so the resolver never
## stores mutable references.  UI side-effects (panel updates, tooltips)
## stay in [AttackExecutor].
##
## Extracted from AttackExecutor as part of refactoring step F4b.
## Rules Reference: "Attack", Steps 2–3, pp.2–3.
class_name AttackDiceResolver
extends RefCounted


# ---------------------------------------------------------------------------
# Armament resolution
# ---------------------------------------------------------------------------

## Resolves the attacker's armament dictionary for the given combatant pair.
## For ship attackers targeting a squadron, returns anti-squadron armament.
## For ship attackers targeting a ship, returns the zone's battery armament.
## For squadron attackers, returns battery or anti-squadron armament from
## [SquadronData].
## Rules Reference: "Attack", Step 2, p.2; "Squadron Attacks", RRG p.19.
func resolve_armament(parts: CombatParticipants) -> Dictionary:
	# Ship attacker.
	if parts.atk_ship:
		var ship_data: ShipData = parts.atk_ship.get_ship_data()
		if ship_data == null:
			return {}
		if parts.def_squad:
			return ship_data.anti_squadron_armament
		var zone_key: String = CombatParticipants.ZONE_NAMES.get(
				parts.atk_zone, "FRONT")
		return ship_data.battery_armament.get(zone_key, {})
	# Squadron attacker.
	if parts.atk_squad:
		var inst: SquadronInstance = \
				parts.atk_squad.get_squadron_instance()
		if inst == null or inst.squadron_data == null:
			return {}
		if parts.def_squad:
			return inst.squadron_data.anti_squadron_armament
		return inst.squadron_data.battery_armament
	return {}


## Computes the string-keyed dice pool for the given armament and range
## band.  Delegates to [DicePool.get_attack_pool].
## Rules Reference: "Attack", Step 2, p.2.
func compute_pool(armament: Dictionary, range_band: String) -> Dictionary:
	return DicePool.get_attack_pool(armament, range_band)


## Convenience: resolves armament and formats the pool as a UI string.
## Returns e.g. "2 red, 1 blue" or "0 dice".
## Requirements: AE-PNL-002.
func compute_dice_text(
		parts: CombatParticipants, range_band: String) -> String:
	if not parts.atk_ship and not parts.atk_squad:
		return "0 dice"
	var armament: Dictionary = resolve_armament(parts)
	return DicePool.format_attack_pool(armament, range_band)


## Convenience: resolves armament and returns the pool dict.
func compute_pool_for_parts(
		parts: CombatParticipants, range_band: String) -> Dictionary:
	if not parts.atk_ship and not parts.atk_squad:
		return {}
	var armament: Dictionary = resolve_armament(parts)
	return DicePool.get_attack_pool(armament, range_band)


# ---------------------------------------------------------------------------
# Gather-dice hook
# ---------------------------------------------------------------------------

## Applies the ATTACK_GATHER_DICE effect hook to [param pool], returning
## the (possibly modified) pool.  The hook may add or remove dice.
## [param registry] may be [code]null[/code] — in that case only static
## [RuleRegistry] dice-pool modifiers for the supplied FlowSpec pair run.
## With an empty [RuleRegistry], the pool is returned unchanged.
## Rules Reference: "Attack", Step 2, p.2 (effects that add dice).
func apply_gather_hook(
		pool: Dictionary,
		registry: EffectRegistry,
		parts: CombatParticipants,
		flow_id: Constants.InteractionFlow = Constants.InteractionFlow.ATTACK,
		step_id: Constants.InteractionStep = \
				Constants.InteractionStep.ATTACK_ROLL) -> Dictionary:
	return apply_gather_context(pool, registry, parts, flow_id, step_id).dice_pool


## Applies gather-dice hooks and returns the full context so callers can read
## rule metadata, such as mandatory pre-roll die-choice payloads.
## Rules Reference: "Attack", Step 2, p.2 (effects before rolling dice).
func apply_gather_context(
		pool: Dictionary,
		registry: EffectRegistry,
		parts: CombatParticipants,
		flow_id: Constants.InteractionFlow = Constants.InteractionFlow.ATTACK,
		step_id: Constants.InteractionStep = \
				Constants.InteractionStep.ATTACK_ROLL) -> EffectContext:
	var ctx: EffectContext = _make_gather_context(pool, parts)
	if registry != null:
		ctx = registry.resolve_hook(&"ATTACK_GATHER_DICE", ctx)
	ctx = _apply_rule_pool_modifiers(ctx, flow_id, step_id)
	return ctx


## Applies one selected RuleRegistry dice-pool modifier to [param pool].
## Used when an earlier gather pass exposed a mandatory player choice and the
## presentation layer now supplies the chosen JSON-safe metadata.
func apply_rule_pool_modifier(
		pool: Dictionary,
		parts: CombatParticipants,
		rule_id: String,
		metadata: Dictionary,
		flow_id: Constants.InteractionFlow = Constants.InteractionFlow.ATTACK,
		step_id: Constants.InteractionStep = \
				Constants.InteractionStep.ATTACK_ROLL) -> EffectContext:
	var ctx: EffectContext = _make_gather_context(pool, parts)
	ctx.metadata = metadata.duplicate(true)
	return _apply_selected_rule_pool_modifier(ctx, rule_id, flow_id, step_id)


func _make_gather_context(pool: Dictionary,
		parts: CombatParticipants) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.dice_pool = pool
	if parts.atk_ship and parts.atk_ship is ShipToken:
		ctx.attacker = (parts.atk_ship as ShipToken).get_ship_instance()
	if parts.def_squad:
		ctx.defender = parts.def_squad.get_squadron_instance()
	elif parts.def_ship and parts.def_ship is ShipToken:
		ctx.defender = (parts.def_ship as ShipToken).get_ship_instance()
	return ctx


func _apply_rule_pool_modifiers(ctx: EffectContext,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep) -> EffectContext:
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(flow_id), int(step_id), "dice_pool")
	for hook: FlowHook in hooks:
		if hook.callback.is_valid():
			var raw: Variant = hook.callback.call(ctx)
			if raw is EffectContext:
				ctx = raw as EffectContext
	return ctx


func _apply_selected_rule_pool_modifier(ctx: EffectContext,
		rule_id: String,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep) -> EffectContext:
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(flow_id), int(step_id), "dice_pool")
	for hook: FlowHook in hooks:
		if hook.rule_id != rule_id or not hook.callback.is_valid():
			continue
		var raw: Variant = hook.callback.call(ctx)
		if raw is EffectContext:
			ctx = raw as EffectContext
	return ctx


# ---------------------------------------------------------------------------
# Attack-blocked check
# ---------------------------------------------------------------------------

## Checks whether a damage card rule or remaining legacy effect blocks this
## attack. Builds an attack-target context with obstruction and attack count.
## Returns [code]true[/code] when a rule blocker fires or any legacy effect sets
## [code]cancelled[/code].
## [param registry] may be [code]null[/code]; RuleRegistry blockers still run.
## Rules Reference: RRG "Damage Cards", p.4; "Coolant Discharge",
## "Depowered Armament", "Disengaged Fire Control".
func is_blocked_by_damage(
		registry: EffectRegistry,
		parts: CombatParticipants,
		obstructed: bool,
		attack_count: int) -> bool:
	var ctx: EffectContext = _build_attack_target_context(
			parts, obstructed, attack_count, "")
	return _is_attack_target_blocked(ctx, registry)


## Overload that also accepts a range band string for the attack.
func is_blocked_by_damage_at_range(
		registry: EffectRegistry,
		parts: CombatParticipants,
		obstructed: bool,
		attack_count: int,
		range_band: String) -> bool:
	var ctx: EffectContext = _build_attack_target_context(
			parts, obstructed, attack_count, range_band)
	return _is_attack_target_blocked(ctx, registry)


func _build_attack_target_context(parts: CombatParticipants,
		obstructed: bool,
		attack_count: int,
		range_band: String) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	if parts.atk_ship and parts.atk_ship is ShipToken:
		ctx.attacker = (parts.atk_ship as ShipToken).get_ship_instance()
	elif parts.atk_squad:
		ctx.attacker = parts.atk_squad.get_squadron_instance()
	ctx.range_band = range_band
	ctx.set_meta_value("is_obstructed", obstructed)
	ctx.set_meta_value("ship_attacks_this_round", attack_count)
	return ctx


func _is_attack_target_blocked(ctx: EffectContext,
		registry: EffectRegistry) -> bool:
	if RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			RuleSurface.TARGET_ATTACK_TARGET):
		return true
	if registry == null:
		return false
	ctx = registry.resolve_hook(&"ATTACK_VALIDATE_TARGET", ctx)
	return ctx.cancelled


# ---------------------------------------------------------------------------
# Concentrate Fire detection
# ---------------------------------------------------------------------------

## Returns which colour keys are available for the CF dial extra die.
## Only colours already in [param pool] with count > 0 may be chosen.
## Requirements: AE-CF-003.
## Rules Reference: "Concentrate Fire", p.3.
func get_cf_dial_colours(pool: Dictionary) -> Array[String]:
	var colours: Array[String] = []
	for key: String in pool:
		if int(pool[key]) > 0:
			colours.append(key)
	return colours


## Checks whether [param ship_token] has a revealed Concentrate Fire
## command dial.
## Requirements: AE-CF-001.
func has_cf_dial(ship_token: ShipToken) -> bool:
	if ship_token == null:
		return false
	var inst: ShipInstance = ship_token.get_ship_instance()
	if inst == null or inst.command_dial_stack == null:
		return false
	var dial: Dictionary = inst.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		return false
	return (dial.get("command", -1) as int) == (
			Constants.CommandType.CONCENTRATE_FIRE as int)


## Checks whether [param ship_token] has a Concentrate Fire command token.
## Requirements: AE-CF-010.
func has_cf_token(ship_token: ShipToken) -> bool:
	if ship_token == null:
		return false
	var inst: ShipInstance = ship_token.get_ship_instance()
	if inst == null or inst.command_tokens == null:
		return false
	return inst.command_tokens.has_token(
			Constants.CommandType.CONCENTRATE_FIRE)


# ---------------------------------------------------------------------------
# Obstruction die removal
# ---------------------------------------------------------------------------

## Removes one die of the given [param colour_key] from [param pool] and
## returns the modified pool.  If the colour's count reaches zero, the
## key is erased.
## Requirements: AE-OBS-001, AE-OBS-002.
## Rules Reference: "Obstructed", RRG v1.5.0, p.10.
func remove_obstruction_die(
		pool: Dictionary, colour_key: String) -> Dictionary:
	var result: Dictionary = pool.duplicate()
	var current: int = int(result.get(colour_key, 0))
	if current > 0:
		result[colour_key] = current - 1
		if result[colour_key] <= 0:
			result.erase(colour_key)
	return result


# ---------------------------------------------------------------------------
# Damage calculation
# ---------------------------------------------------------------------------

## Calculates the damage total from rolled dice [param results].
## When either combatant is a squadron, critical icons do not add damage.
## Optionally resolves the ATTACK_CALC_DAMAGE hook via [param registry].
## [param registry] may be [code]null[/code] — base damage only.
## Rules Reference: "Dice Icons", p.5 — critical adds damage only when
## both attacker and defender are ships.
func calc_damage(
		results: Array[Dictionary],
		parts: CombatParticipants,
		registry: EffectRegistry) -> int:
	var base_damage: int
	# Critical icons only add damage when BOTH combatants are ships.
	if parts.def_squad != null or parts.atk_squad != null:
		base_damage = Dice.calculate_damage_vs_squadron(results)
	else:
		base_damage = Dice.calculate_damage(results)
	# Resolve ATTACK_CALC_DAMAGE hook for keyword effects (e.g. Bomber).
	if registry != null:
		var ctx: EffectContext = EffectContext.new()
		ctx.dice_results = results
		ctx.damage_total = base_damage
		# Determine attacker/defender RefCounted references.
		if parts.atk_ship and parts.atk_ship is ShipToken:
			ctx.attacker = (
					parts.atk_ship as ShipToken).get_ship_instance()
		if parts.atk_squad:
			ctx.attacker = parts.atk_squad.get_squadron_instance()
		if parts.def_squad:
			ctx.defender = parts.def_squad.get_squadron_instance()
		elif parts.def_ship and parts.def_ship is ShipToken:
			ctx.defender = (
					parts.def_ship as ShipToken).get_ship_instance()
		ctx = registry.resolve_hook(&"ATTACK_CALC_DAMAGE", ctx)
		return ctx.damage_total
	return base_damage

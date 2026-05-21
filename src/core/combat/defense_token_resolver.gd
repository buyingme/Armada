## DefenseTokenResolver
##
## Pure-computation helper for defense token spending logic during the
## Spend Defense Tokens step of an attack (Step 4).
##
## Every public method is stateless: callers pass the defender's
## [ShipInstance], the current attack state (locked tokens, spent tokens,
## redirect remaining, etc.) and optionally an [EffectRegistry] so the
## resolver never stores mutable references.  UI side-effects (panel
## updates, button disabling, camera rotation) stay in [AttackExecutor].
##
## Extracted from AttackExecutor as part of refactoring step F4c.
## Rules Reference: "Defense Tokens", p.5; individual token entries.
class_name DefenseTokenResolver
extends RefCounted

const ConstantsScript := preload("res://src/autoload/constants.gd")


## Canonical defense token resolution order.
## Rules Reference: "Defense Tokens", p.5 — effects resolve in a
## fixed sequence: Scatter (cancel) → Evade (dice mod) → Brace
## (halve total) → Redirect (distribute) → Contain (prevent crit).
const DEFENSE_RESOLVE_ORDER: Dictionary = {
	Constants.DefenseToken.SCATTER: 0,
	Constants.DefenseToken.EVADE: 1,
	Constants.DefenseToken.BRACE: 2,
	Constants.DefenseToken.REDIRECT: 3,
	Constants.DefenseToken.CONTAIN: 4,
}


# ---------------------------------------------------------------------------
# Token availability checks
# ---------------------------------------------------------------------------


## Counts non-discarded defense tokens on a ship instance.
## Used by the accuracy step to decide whether to enter the sub-step.
## Rules Reference: "Accuracy", RRG v1.5.0, p.2.
func count_lockable_tokens(def_inst: ShipInstance) -> int:
	var lockable: int = 0
	for token: Dictionary in def_inst.defense_tokens:
		if token["state"] != Constants.DefenseTokenState.DISCARDED:
			lockable += 1
	return lockable


## Returns true if the defender has spendable tokens and speed > 0.
## Rules Reference: "Defense Tokens", bullet 4, p.5 —
## "If the defender's speed is 0, he cannot spend any defense tokens."
func can_spend_tokens(def_inst: ShipInstance,
		locked_tokens: Array[int],
		effect_registry: EffectRegistry,
		def_zone: int) -> bool:
	var spendable: int = count_spendable_tokens(
			def_inst, locked_tokens, effect_registry, def_zone)
	if spendable == 0:
		return false
	if def_inst.current_speed == 0:
		return false
	return true


## Returns the number of spendable (non-discarded, non-locked, not
## blocked by RuleRegistry defense-token blockers) tokens.
## Rules Reference: "Defense Tokens", p.5; "Faulty Countermeasures".
func count_spendable_tokens(def_inst: ShipInstance,
		locked_tokens: Array[int],
		effect_registry: EffectRegistry,
		def_zone: int) -> int:
	var count: int = 0
	for i: int in range(def_inst.defense_tokens.size()):
		if i in locked_tokens:
			continue
		var token: Dictionary = def_inst.defense_tokens[i]
		var state: Constants.DefenseTokenState = (
				token["state"] as Constants.DefenseTokenState)
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		if is_token_blocked_by_effect(
				def_inst, token, effect_registry, def_zone):
			continue
		count += 1
	return count


## Returns true if the token at the given index can be spent.
## Checks discard state, one-per-type limit, accuracy locks, and
## RuleRegistry defense-token blockers.
## Rules Reference: "Defense Tokens", p.5; "Faulty Countermeasures".
func is_token_spendable(token_index: int, token: Dictionary,
		spent_tokens: Dictionary, locked_tokens: Array[int],
		def_inst: ShipInstance, effect_registry: EffectRegistry,
		def_zone: int) -> bool:
	var token_type: Constants.DefenseToken = (
			token["type"] as Constants.DefenseToken)
	var token_state: Constants.DefenseTokenState = (
			token["state"] as Constants.DefenseTokenState)
	if token_state == Constants.DefenseTokenState.DISCARDED:
		return false
	if spent_tokens.has(token_type):
		return false
	if token_index in locked_tokens:
		return false
	if is_token_blocked_by_effect(
			def_inst, token, effect_registry, def_zone):
		return false
	return true


## Returns true if a RuleRegistry blocker prevents spending this token.
## Rules Reference: "Faulty Countermeasures"; "Capacitor Failure".
func is_token_blocked_by_effect(inst: ShipInstance,
		token: Dictionary, _registry: EffectRegistry,
		def_zone: int) -> bool:
	if inst == null:
		return false
	var ctx: EffectContext = _make_defense_token_context(
			inst, token, def_zone)
	return RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			RuleSurface.TARGET_DEFENSE_TOKEN_SPEND)


func _make_defense_token_context(inst: ShipInstance,
		token: Dictionary,
		def_zone: int) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.defender = inst
	ctx.defending_zone = def_zone
	var token_type: Constants.DefenseToken = (
			token["type"] as Constants.DefenseToken)
	var token_state: Constants.DefenseTokenState = (
			token["state"] as Constants.DefenseTokenState)
	ctx.set_meta_value("token_type", token_type)
	ctx.set_meta_value("token_state", token_state)
	_add_defending_zone_shields(ctx, inst, def_zone)
	return ctx


func _add_defending_zone_shields(ctx: EffectContext,
		inst: ShipInstance,
		def_zone: int) -> void:
	if def_zone < 0:
		return
	var zone_key: String = ConstantsScript.hull_zone_to_string(
			def_zone as Constants.HullZone)
	if zone_key == "" or not inst.current_shields.has(zone_key):
		return
	ctx.set_meta_value("target_zone_shields",
			int(inst.current_shields[zone_key]))


# ---------------------------------------------------------------------------
# Spend method resolution
# ---------------------------------------------------------------------------


## Resolves the actual spend method: exhausted tokens must be discarded.
## Returns "discard" if the token is already exhausted, otherwise
## pass-through of [param spend_method].
func resolve_spend_method(spend_method: String,
		token: Dictionary) -> String:
	var token_state: Constants.DefenseTokenState = (
			token["state"] as Constants.DefenseTokenState)
	if token_state == Constants.DefenseTokenState.EXHAUSTED:
		return "discard"
	return spend_method


# ---------------------------------------------------------------------------
# Token effect computations
# ---------------------------------------------------------------------------


## Applies the Scatter defense token effect: cancels all damage.
## Returns the new damage total (always 0).
## Rules Reference: "Scatter", p.11.
func apply_scatter(_damage: int) -> int:
	return 0


## Applies the Brace defense token effect: halves damage (rounds up).
## Returns the new damage total.
## Rules Reference: "Brace", RRG v1.5.0, p.3.
func apply_brace(damage: int) -> int:
	if damage <= 0:
		return 0
	return ceili(float(damage) / 2.0)


## Applies an evade die removal at long range.
## Returns a dictionary with "dice_results" (Array) and "damage" (int).
## The caller should use these to update the attack state.
## Rules Reference: "Evade", RRG v1.5.0, p.5.
func apply_evade_remove(die_index: int,
		dice_results: Array[Dictionary],
		parts: CombatParticipants,
		effect_registry: EffectRegistry) -> Dictionary:
	var results: Array[Dictionary] = dice_results.duplicate(true)
	if die_index < 0 or die_index >= results.size():
		return {"dice_results": results, "damage": Dice.calculate_damage(results)}
	results.remove_at(die_index)
	var damage: int = _calc_damage(results, parts, effect_registry)
	return {"dice_results": results, "damage": damage}


## Applies an evade die reroll at medium/close range.
## Returns a dictionary with "dice_results" (Array), "damage" (int),
## and "new_face" (Constants.DiceFace).
## Rules Reference: "Evade", RRG v1.5.0, p.5.
func apply_evade_reroll(die_index: int,
		dice_results: Array[Dictionary],
		parts: CombatParticipants,
		effect_registry: EffectRegistry) -> Dictionary:
	var results: Array[Dictionary] = dice_results.duplicate(true)
	if die_index < 0 or die_index >= results.size():
		return {
			"dice_results": results,
			"damage": Dice.calculate_damage(results),
			"new_face": Constants.DiceFace.BLANK,
		}
	var color: Constants.DiceColor = (
			results[die_index]["color"] as Constants.DiceColor)
	var new_face: Constants.DiceFace = Dice.roll_die(color)
	results[die_index]["face"] = new_face
	var damage: int = _calc_damage(results, parts, effect_registry)
	return {
		"dice_results": results,
		"damage": damage,
		"new_face": new_face,
	}


# ---------------------------------------------------------------------------
# Redirect helpers
# ---------------------------------------------------------------------------


## Returns true if one point of damage can be redirected to the given
## hull zone (zone has shields > 0 and redirect budget > 0).
## Does NOT mutate game state — the caller applies the change.
## Rules Reference: "Redirect", p.11.
func can_redirect_to_zone(zone_enum: Constants.HullZone,
		def_inst: ShipInstance,
		redirect_remaining: int) -> bool:
	var zone_str: String = ConstantsScript.hull_zone_to_string(zone_enum)
	var zone_shields: int = int(
			def_inst.current_shields.get(zone_str, 0))
	if zone_shields <= 0:
		return false
	if redirect_remaining <= 0:
		return false
	return true


## Returns true if the redirect sub-step can continue: remaining
## redirect budget > 0 and at least one adjacent zone has shields.
## Rules Reference: "Redirect", p.11.
func can_redirect_continue(redirect_remaining: int,
		def_zone: Constants.HullZone,
		def_inst: ShipInstance) -> bool:
	if redirect_remaining <= 0:
		return false
	var adjacent: Array = ConstantsScript.get_adjacent_hull_zones(
			def_zone)
	for adj_zone: Variant in adjacent:
		var adj_str: String = ConstantsScript.hull_zone_to_string(
				adj_zone as Constants.HullZone)
		if int(def_inst.current_shields.get(adj_str, 0)) > 0:
			return true
	return false


# ---------------------------------------------------------------------------
# Canonical sort
# ---------------------------------------------------------------------------


## Sorts token indices into canonical RRG resolution order.
## Rules Reference: "Defense Tokens", p.5 — Scatter → Evade → Brace →
## Redirect → Contain.
func sort_tokens_canonical(indices: Array[int],
		defense_tokens: Array) -> Array[int]:
	var sorted: Array[int] = indices.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var type_a: Constants.DefenseToken = (
				defense_tokens[a]["type"] as Constants.DefenseToken)
		var type_b: Constants.DefenseToken = (
				defense_tokens[b]["type"] as Constants.DefenseToken)
		return DEFENSE_RESOLVE_ORDER.get(type_a, 99) < \
				DEFENSE_RESOLVE_ORDER.get(type_b, 99)
	)
	return sorted


## Returns the button index for a given token type in the current attack.
## Finds the first matching token that was already spent.
func get_token_button_index(token_type: Constants.DefenseToken,
		defense_tokens: Array,
		spent_tokens: Dictionary) -> int:
	for i: int in range(defense_tokens.size()):
		if defense_tokens[i]["type"] == token_type:
			if spent_tokens.has(token_type):
				return i
	return -1


# ---------------------------------------------------------------------------
# Critical / faceup damage
# ---------------------------------------------------------------------------


## Determines if the first damage card should be dealt faceup (critical).
## Returns true if any dice show a critical face and Contain was not
## used, unless blocked by an ATTACK_RESOLVE_CRITICAL effect.
## Rules Reference: "Critical Effect", RRG v1.5.0, p.4.
func determine_first_card_faceup(dice_results: Array[Dictionary],
		contain_used: bool, registry: EffectRegistry,
		attacker: ShipInstance) -> bool:
	var has_crit: bool = Dice.has_any_critical(dice_results)
	var faceup: bool = (has_crit and not contain_used)
	if not faceup:
		return false
	if registry == null:
		return faceup
	var crit_ctx: EffectContext = EffectContext.new()
	if attacker != null:
		crit_ctx.attacker = attacker
	crit_ctx.critical_allowed = true
	crit_ctx = registry.resolve_hook(
			&"ATTACK_RESOLVE_CRITICAL", crit_ctx)
	if not crit_ctx.critical_allowed:
		return false
	return true


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


## Calculates damage, delegating to [Dice.calculate_damage] for simple
## pool-only calculation.  The caller should use the full hook-aware path
## via [AttackDiceResolver.calc_damage] when the [EffectRegistry] matters,
## but for evade rerolls/removals, basic damage is sufficient.
func _calc_damage(results: Array[Dictionary],
		_parts: CombatParticipants,
		_registry: EffectRegistry) -> int:
	return Dice.calculate_damage(results)

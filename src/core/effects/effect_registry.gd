## EffectRegistry
##
## Central registry that collects all active [GameEffect] instances and
## resolves them in order at each hook point.
##
## Resolution order (per ET-002/ET-003):
##   1. First player's effects (player_priority == 0)
##   2. Second player's effects (player_priority == 1)
##   Within each player group the player chooses order; for automated
##   resolution we use registration order as a stable fallback.
##
## The registry lives on [GameState] for runtime hook resolution, but is not
## serialized.  Load paths rebuild it from authoritative serialized entities.
##
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
class_name EffectRegistry
extends RefCounted


## All registered effects, keyed by hook StringName → Array[GameEffect].
var _effects: Dictionary = {}

## Flat list of all effects (for iteration / cleanup).
var _all_effects: Array[GameEffect] = []


## Registers [param effect] for all hooks it declares.
func register(effect: GameEffect) -> void:
	if effect in _all_effects:
		return
	_all_effects.append(effect)
	for hook: StringName in effect.get_hooks():
		if not _effects.has(hook):
			_effects[hook] = []
		(_effects[hook] as Array).append(effect)


## Unregisters [param effect] from all hooks.
func unregister(effect: GameEffect) -> void:
	_all_effects.erase(effect)
	for hook: StringName in effect.get_hooks():
		if _effects.has(hook):
			(_effects[hook] as Array).erase(effect)


## Resolves all effects registered for [param hook], passing them
## [param context] in player-priority then registration order.
## Returns the (mutated) context for convenience.
func resolve_hook(hook: StringName, context: EffectContext) -> EffectContext:
	context.hook = hook
	if not _effects.has(hook):
		return context
	var sorted: Array[GameEffect] = _sort_by_priority(
			_effects[hook] as Array)
	for effect: GameEffect in sorted:
		if effect.should_trigger(context):
			effect.resolve(context)
	return context


## Returns all effects registered for [param hook].
func get_effects_for_hook(hook: StringName) -> Array[GameEffect]:
	if not _effects.has(hook):
		return []
	var result: Array[GameEffect] = []
	for e: Variant in _effects[hook]:
		result.append(e as GameEffect)
	return result


## Returns every registered effect.
func get_all_effects() -> Array[GameEffect]:
	return _all_effects.duplicate()


## Removes all effects owned by [param entity].
func unregister_by_owner(entity: RefCounted) -> void:
	var to_remove: Array[GameEffect] = []
	for effect: GameEffect in _all_effects:
		if effect.owner == entity:
			to_remove.append(effect)
	for effect: GameEffect in to_remove:
		unregister(effect)


## Clears every registered effect (game reset).
func clear() -> void:
	_effects.clear()
	_all_effects.clear()


## Returns the count of all registered effects.
func get_effect_count() -> int:
	return _all_effects.size()


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Sorts effects by player_priority (first player resolves first),
## preserving registration order within the same priority.
func _sort_by_priority(effects: Array) -> Array[GameEffect]:
	var result: Array[GameEffect] = []
	# First player (priority 0), then second player (priority 1).
	for prio: int in [0, 1]:
		for e: Variant in effects:
			var ge: GameEffect = e as GameEffect
			if ge.player_priority == prio:
				result.append(ge)
	# Append any effects with unexpected priority values.
	for e: Variant in effects:
		var ge: GameEffect = e as GameEffect
		if ge.player_priority != 0 and ge.player_priority != 1:
			result.append(ge)
	return result

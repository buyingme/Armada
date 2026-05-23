## ManeuverRuleResolver
##
## Core adapter for maneuver rule surfaces. Scene and tool code call this
## helper instead of resolving legacy movement hooks directly; remaining
## legacy damage cards are still applied here until their RuleRegistry slices.
class_name ManeuverRuleResolver
extends RefCounted


const LEGACY_HOOK_MANEUVER_YAW: StringName = &"MANEUVER_DETERMINE_YAWS"
const LEGACY_HOOK_AFTER_MANEUVER: StringName = &"AFTER_MANEUVER_EXECUTE"
const LEGACY_HOOK_SPEED_CHANGE: StringName = &"ON_SPEED_CHANGE"
const EFFECT_RUPTURED_ENGINE: String = "ruptured_engine"
const EFFECT_DAMAGED_CONTROLS: String = "damaged_controls"
const EFFECT_THRUSTER_FISSURE: String = "thruster_fissure"


## Applies RuleRegistry and legacy maneuver-yaw modifiers to a nav chart copy.
## Rules Reference: Damage Card "Thrust Control Malfunction".
static func apply_yaw_modifiers(nav_chart: Array,
		ship: ShipInstance,
		game_state: GameState) -> Array:
	var result: Array = nav_chart.duplicate(true)
	if ship == null:
		return result
	for speed_index: int in range(result.size()):
		result[speed_index] = _resolve_yaw_row(
				result, speed_index, ship, game_state)
	return result


## Resolves legacy post-maneuver damage-card effects and returns the effect id.
## Rules Reference: Damage Cards "Ruptured Engine" and "Damaged Controls".
static func resolve_after_maneuver_effect_id(game_state: GameState,
		ship: ShipInstance,
		damage_deck: DamageDeck,
		maneuver_result: Dictionary,
		did_overlap: bool) -> String:
	if ship == null:
		return ""
	var context: EffectContext = _build_after_maneuver_context(
			ship, damage_deck, maneuver_result, did_overlap)
	context = _resolve_legacy_hook(game_state, LEGACY_HOOK_AFTER_MANEUVER,
			context)
	return _persistent_effect_id(context)


## Resolves legacy speed-change damage-card effects and returns the effect id.
## Rules Reference: Damage Card "Thruster Fissure".
static func resolve_speed_change_effect_id(game_state: GameState,
		ship: ShipInstance,
		damage_deck: DamageDeck) -> String:
	if ship == null:
		return ""
	var context: EffectContext = EffectContext.new()
	context.set_meta_value("ship", ship)
	context.set_meta_value("damage_deck", damage_deck)
	context = _resolve_legacy_hook(game_state, LEGACY_HOOK_SPEED_CHANGE,
			context)
	return _persistent_effect_id(context)


## Previews maneuver damage-card effects without mutating game state.
## Rules Reference: Damage Cards "Ruptured Engine", "Damaged Controls",
## and "Thruster Fissure".
static func preview_maneuver_damage_effect_ids(game_state: GameState,
		ship: ShipInstance,
		damage_deck: DamageDeck,
		maneuver_speed: int,
		did_overlap: bool,
		did_change_speed: bool) -> Array[String]:
	var effect_ids: Array[String] = []
	var maneuver_result: Dictionary = {"speed": maneuver_speed}
	_append_effect_id(effect_ids, resolve_after_maneuver_effect_id(
			game_state, ship, damage_deck, maneuver_result, did_overlap))
	if did_change_speed:
		_append_effect_id(effect_ids, resolve_speed_change_effect_id(
				game_state, ship, damage_deck))
	return effect_ids


static func _resolve_yaw_row(nav_chart: Array,
		speed_index: int,
		ship: ShipInstance,
		game_state: GameState) -> Array:
	var row_variant: Variant = nav_chart[speed_index]
	if not row_variant is Array:
		return []
	var yaw_values: Array = (row_variant as Array).duplicate()
	var context: EffectContext = _build_yaw_context(
			ship, speed_index + 1, yaw_values)
	context = RuleSurface.apply_modifiers(context,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.TARGET_MANEUVER_YAW)
	context = _resolve_legacy_hook(game_state, LEGACY_HOOK_MANEUVER_YAW,
			context)
	return _yaw_values_from_context(context, yaw_values)


static func _build_yaw_context(ship: ShipInstance,
		speed: int,
		yaw_values: Array) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.set_meta_value("ship", ship)
	context.set_meta_value("speed", speed)
	context.set_meta_value("yaw_values", yaw_values)
	return context


static func _build_after_maneuver_context(ship: ShipInstance,
		damage_deck: DamageDeck,
		maneuver_result: Dictionary,
		did_overlap: bool) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.set_meta_value("ship", ship)
	context.set_meta_value("ship_speed", _maneuver_speed(ship, maneuver_result))
	context.set_meta_value("did_overlap", did_overlap)
	context.set_meta_value("damage_deck", damage_deck)
	return context


static func _maneuver_speed(ship: ShipInstance,
		maneuver_result: Dictionary) -> int:
	if maneuver_result.has("speed"):
		return int(maneuver_result.get("speed", 0))
	return ship.current_speed


static func _resolve_legacy_hook(game_state: GameState,
		hook_name: StringName,
		context: EffectContext) -> EffectContext:
	if game_state == null or game_state.effect_registry == null:
		return context
	return game_state.effect_registry.resolve_hook(hook_name, context)


static func _yaw_values_from_context(context: EffectContext,
		fallback: Array) -> Array:
	var raw_values: Variant = context.get_meta_value("yaw_values", fallback)
	if raw_values is Array:
		return raw_values as Array
	return fallback


static func _persistent_effect_id(context: EffectContext) -> String:
	if not bool(context.get_meta_value("extra_damage_dealt", false)):
		return ""
	return str(context.get_meta_value("persistent_effect_id", ""))


static func _append_effect_id(effect_ids: Array[String],
		effect_id: String) -> void:
	if effect_id == "" or effect_ids.has(effect_id):
		return
	effect_ids.append(effect_id)

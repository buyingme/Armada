## ManeuverRuleResolver
##
## Core adapter for maneuver rule surfaces. Scene and tool code call this
## helper instead of resolving scene-local movement damage hooks directly.
class_name ManeuverRuleResolver
extends RefCounted


const EFFECT_RUPTURED_ENGINE: String = "ruptured_engine"
const EFFECT_DAMAGED_CONTROLS: String = "damaged_controls"
const EFFECT_THRUSTER_FISSURE: String = "thruster_fissure"


## Applies RuleRegistry maneuver-yaw modifiers to a nav chart copy.
## Rules Reference: Damage Card "Thrust Control Malfunction".
static func apply_yaw_modifiers(nav_chart: Array,
		ship: ShipInstance,
		_game_state: GameState) -> Array:
	var result: Array = nav_chart.duplicate(true)
	if ship == null:
		return result
	for speed_index: int in range(result.size()):
		result[speed_index] = _resolve_yaw_row(result, speed_index, ship)
	return result


## Resolves post-maneuver damage-card preview ids from faceup damage state.
## Rules Reference: Damage Cards "Ruptured Engine" and "Damaged Controls".
static func resolve_after_maneuver_effect_id(_game_state: GameState,
		ship: ShipInstance,
		_damage_deck: DamageDeck,
		maneuver_result: Dictionary,
		did_overlap: bool) -> String:
	if ship == null:
		return ""
	var effect_ids: Array[String] = _effect_ids_after_maneuver(
			ship, _maneuver_speed(ship, maneuver_result), did_overlap)
	if effect_ids.is_empty():
		return ""
	return effect_ids[0]


## Resolves speed-change damage-card preview ids from faceup damage state.
## Rules Reference: Damage Card "Thruster Fissure".
static func resolve_speed_change_effect_id(_game_state: GameState,
		ship: ShipInstance,
		_damage_deck: DamageDeck) -> String:
	if ship == null:
		return ""
	if _has_faceup_effect(ship, EFFECT_THRUSTER_FISSURE):
		return EFFECT_THRUSTER_FISSURE
	return ""


## Previews maneuver damage-card effects without mutating game state.
## Rules Reference: Damage Cards "Ruptured Engine", "Damaged Controls",
## and "Thruster Fissure".
static func preview_maneuver_damage_effect_ids(_game_state: GameState,
		ship: ShipInstance,
		_damage_deck: DamageDeck,
		maneuver_speed: int,
		did_overlap: bool,
		did_change_speed: bool) -> Array[String]:
	var effect_ids: Array[String] = _effect_ids_after_maneuver(
			ship, maneuver_speed, did_overlap)
	if did_change_speed:
		_append_effect_id(effect_ids,
				resolve_speed_change_effect_id(null, ship, null))
	return effect_ids


static func _resolve_yaw_row(nav_chart: Array,
		speed_index: int,
		ship: ShipInstance) -> Array:
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
	return _yaw_values_from_context(context, yaw_values)


static func _build_yaw_context(ship: ShipInstance,
		speed: int,
		yaw_values: Array) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.set_meta_value("ship", ship)
	context.set_meta_value("speed", speed)
	context.set_meta_value("yaw_values", yaw_values)
	return context


static func _maneuver_speed(ship: ShipInstance,
		maneuver_result: Dictionary) -> int:
	if maneuver_result.has("speed"):
		return int(maneuver_result.get("speed", 0))
	return ship.current_speed


static func _yaw_values_from_context(context: EffectContext,
		fallback: Array) -> Array:
	var raw_values: Variant = context.get_meta_value("yaw_values", fallback)
	if raw_values is Array:
		return raw_values as Array
	return fallback


static func _effect_ids_after_maneuver(ship: ShipInstance,
		maneuver_speed: int,
		did_overlap: bool) -> Array[String]:
	var effect_ids: Array[String] = []
	if _has_faceup_effect(ship, EFFECT_RUPTURED_ENGINE) and maneuver_speed > 1:
		_append_effect_id(effect_ids, EFFECT_RUPTURED_ENGINE)
	if _has_faceup_effect(ship, EFFECT_DAMAGED_CONTROLS) and did_overlap:
		_append_effect_id(effect_ids, EFFECT_DAMAGED_CONTROLS)
	return effect_ids


static func _has_faceup_effect(ship: ShipInstance, effect_id: String) -> bool:
	if ship == null:
		return false
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == effect_id:
			return true
	return false


static func _append_effect_id(effect_ids: Array[String],
		effect_id: String) -> void:
	if effect_id == "" or effect_ids.has(effect_id):
		return
	effect_ids.append(effect_id)

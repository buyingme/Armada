## SquadronKeywordRuleHelper
##
## Shared no-behaviour-change predicates and JSON-safe metadata conventions
## for Phase N squadron keyword rules.
## Rules Reference: RRG "Squadron Keywords", p.12.
class_name SquadronKeywordRuleHelper
extends RefCounted


const KEYWORD_HEAVY: String = "Heavy"
const KEYWORD_ESCORT: String = "Escort"
const KEYWORD_COUNTER: String = "Counter"
const KEYWORD_BOMBER: String = "Bomber"
const KEYWORD_SWARM: String = "Swarm"

const ATTACK_KIND_STANDARD: String = "standard"
const ATTACK_KIND_COUNTER: String = "counter"

const PAYLOAD_ATTACK_KIND: String = "attack_kind"
const PAYLOAD_ATTACKER_POS: String = "attacker_pos"
const PAYLOAD_TARGET_POS: String = "target_pos"
const PAYLOAD_ALL_SQUADRONS: String = "all_squadrons"
const META_OBSTRUCTION_BODIES: String = "obstruction_bodies"
const PAYLOAD_TARGET_INDEX: String = "target_index"
const PAYLOAD_BLOCKED: String = "blocked"
const PAYLOAD_REASON: String = "reason"
const PAYLOAD_RULE_IDS: String = "rule_ids"
const AFFORDANCE_ATTACK_MODIFIERS: String = "attack_modifier_affordances"
const AFFORDANCE_COUNTER_ATTACK: String = "counter_attack_affordance"
const AFFORDANCE_RULE_ID: String = "rule_id"
const AFFORDANCE_CONTROLLER_PLAYER: String = "controller_player"
const AFFORDANCE_AVAILABLE_DIE_INDICES: String = "available_die_indices"
const AFFORDANCE_PROMPT: String = "prompt"
const AFFORDANCE_OPTIONAL: String = "optional"
const AFFORDANCE_DICE_POOL: String = "dice_pool"


## Returns true when [param squadron] has [param keyword_name].
static func has_keyword(squadron: SquadronInstance, keyword_name: String) -> bool:
	if squadron == null or squadron.squadron_data == null:
		return false
	var wanted_name: String = _normalise_keyword_name(keyword_name)
	for keyword_var: Variant in squadron.squadron_data.keywords:
		var keyword: Dictionary = _keyword_dictionary(keyword_var)
		if _normalise_keyword_name(str(keyword.get("name", ""))) == wanted_name:
			return true
	return false


## Returns a keyword's numeric value, or 0 when absent or valueless.
static func get_keyword_value(squadron: SquadronInstance, keyword_name: String) -> int:
	if squadron == null or squadron.squadron_data == null:
		return 0
	var wanted_name: String = _normalise_keyword_name(keyword_name)
	for keyword_var: Variant in squadron.squadron_data.keywords:
		var keyword: Dictionary = _keyword_dictionary(keyword_var)
		if _normalise_keyword_name(str(keyword.get("name", ""))) == wanted_name:
			return int(keyword.get("value", 0))
	return 0


## Returns the canonical attack kind from a flow payload dictionary.
static func attack_kind_from_payload(payload: Dictionary) -> String:
	var attack_kind: String = str(
			payload.get(PAYLOAD_ATTACK_KIND, ATTACK_KIND_STANDARD)).to_lower()
	if attack_kind == ATTACK_KIND_COUNTER:
		return ATTACK_KIND_COUNTER
	return ATTACK_KIND_STANDARD


## Returns the canonical attack kind stored on an [EffectContext].
static func attack_kind_from_context(context: EffectContext) -> String:
	if context == null:
		return ATTACK_KIND_STANDARD
	return attack_kind_from_payload(context.metadata)


## Returns true when the payload describes a Counter attack.
static func is_counter_attack_payload(payload: Dictionary) -> bool:
	return attack_kind_from_payload(payload) == ATTACK_KIND_COUNTER


## Returns true when the context describes a Counter attack.
static func is_counter_attack_context(context: EffectContext) -> bool:
	return attack_kind_from_context(context) == ATTACK_KIND_COUNTER


## Builds JSON-safe attack-kind metadata for interaction payloads.
static func make_attack_kind_payload(attack_kind: String) -> Dictionary:
	return {PAYLOAD_ATTACK_KIND: attack_kind_from_payload(
			{PAYLOAD_ATTACK_KIND: attack_kind})}


## Returns engaged enemies without Heavy.
## Rules Reference: RRG "Engagement" — obstructed squadrons are not engaged.
static func non_heavy_engaged_enemies(squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> Array[SquadronInstance]:
	var enemies: Array[SquadronInstance] = EngagementResolver.get_engaged_enemies(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles)
	var non_heavy: Array[SquadronInstance] = []
	for enemy: SquadronInstance in enemies:
		if not has_keyword(enemy, KEYWORD_HEAVY):
			non_heavy.append(enemy)
	return non_heavy


## Returns true when at least one engaging enemy lacks Heavy.
static func is_engaged_by_non_heavy(squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	return not non_heavy_engaged_enemies(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles).is_empty()


## Returns true when engagement permits [param squadron] to move.
## Rules Reference: RRG "Squadron Keywords", Heavy — "You do not
## prevent engaged squadrons from attacking ships or moving."
static func can_move_with_heavy_rule(squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	return not is_engaged_by_non_heavy(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles)


## Returns true when engagement permits [param squadron] to attack ships.
## Heavy enemies do not create the ship-target restriction.
static func can_attack_ship_with_heavy_rule(squadron: SquadronInstance,
		squadron_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	return can_move_with_heavy_rule(
			squadron, squadron_pos, all_squadrons,
			obstruction_bodies, obstacles)


## Returns true when [param target] is specifically engaged with [param squadron].
static func is_engaged_with_target(squadron: SquadronInstance,
		squadron_pos: Vector2,
		target: SquadronInstance,
		target_pos: Vector2,
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	if squadron == null or target == null:
		return false
	var target_only: Array[Dictionary] = [
		{"instance": target, "position": target_pos},
	]
	return EngagementResolver.get_engaged_enemies(
			squadron, squadron_pos, target_only,
			obstruction_bodies, obstacles).has(target)


## Returns true when Escort prevents attacking [param target].
## Counter attacks are exempt from Escort targeting restrictions.
static func is_escort_target_blocked(attacker: SquadronInstance,
		attacker_pos: Vector2,
		target: SquadronInstance,
		_target_pos: Vector2,
		all_squadrons: Array[Dictionary],
		attack_kind: String,
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	if attack_kind_from_payload({PAYLOAD_ATTACK_KIND: attack_kind}) \
			== ATTACK_KIND_COUNTER:
		return false
	if attacker == null or target == null:
		return false
	if has_keyword(target, KEYWORD_ESCORT):
		return false
	return _is_engaged_with_enemy_escort(
			attacker, attacker_pos, all_squadrons,
			obstruction_bodies, obstacles)


## Returns true when Swarm can reroll one attack die for this attack.
static func is_swarm_eligible(attacker: SquadronInstance,
		_attacker_pos: Vector2,
		target: SquadronInstance,
		target_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array = [],
		obstacles: Array = []) -> bool:
	if not has_keyword(attacker, KEYWORD_SWARM):
		return false
	return _target_engaged_with_other_squadron(
			attacker, target, target_pos, all_squadrons,
			obstruction_bodies, obstacles)


## Builds squadron position entries from serialized [GameState] data.
static func positions_from_state(game_state: GameState) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	if game_state == null:
		return positions
	var play_area_size: Vector2 = _play_area_size_for_positions()
	for player_state: PlayerState in game_state.player_states:
		_append_player_squadron_positions(
				positions, player_state, play_area_size)
	return positions


## Returns the serialized pixel position for [param squadron].
static func position_from_state(squadron: SquadronInstance) -> Vector2:
	if squadron == null:
		return Vector2.ZERO
	return squadron.get_pixel_position(_play_area_size_for_positions())


## Builds JSON-safe target legality metadata for future blockers/UI projection.
static func make_target_legality_payload(target_index: int,
		blocked: bool,
		reason: String,
		rule_ids: Array[String]) -> Dictionary:
	return {
		PAYLOAD_TARGET_INDEX: target_index,
		PAYLOAD_BLOCKED: blocked,
		PAYLOAD_REASON: reason,
		PAYLOAD_RULE_IDS: rule_ids.duplicate(),
	}


## Builds a JSON-safe optional attack-modifier affordance payload.
static func make_optional_modifier_affordance(rule_id: String,
		controller_player: int,
		available_die_indices: Array[int],
		prompt: String) -> Dictionary:
	var affordance: Dictionary = {
		AFFORDANCE_RULE_ID: rule_id,
		AFFORDANCE_CONTROLLER_PLAYER: controller_player,
		AFFORDANCE_AVAILABLE_DIE_INDICES: available_die_indices.duplicate(),
		AFFORDANCE_PROMPT: prompt,
		AFFORDANCE_OPTIONAL: true,
	}
	return {AFFORDANCE_ATTACK_MODIFIERS: [affordance]}


## Builds a JSON-safe optional Counter attack affordance payload.
static func make_counter_attack_affordance(rule_id: String,
		controller_player: int,
		dice_pool: Dictionary,
		prompt: String) -> Dictionary:
	return {AFFORDANCE_COUNTER_ATTACK: {
		AFFORDANCE_RULE_ID: rule_id,
		AFFORDANCE_CONTROLLER_PLAYER: controller_player,
		AFFORDANCE_DICE_POOL: dice_pool.duplicate(true),
		AFFORDANCE_PROMPT: prompt,
		AFFORDANCE_OPTIONAL: true,
	}}


static func _is_engaged_with_enemy_escort(attacker: SquadronInstance,
		attacker_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array,
		obstacles: Array) -> bool:
	var engaged: Array[SquadronInstance] = EngagementResolver.get_engaged_enemies(
			attacker, attacker_pos, all_squadrons,
			obstruction_bodies, obstacles)
	for enemy: SquadronInstance in engaged:
		if has_keyword(enemy, KEYWORD_ESCORT):
			return true
	return false


static func _target_engaged_with_other_squadron(attacker: SquadronInstance,
		target: SquadronInstance,
		target_pos: Vector2,
		all_squadrons: Array[Dictionary],
		obstruction_bodies: Array,
		obstacles: Array) -> bool:
	for entry: Dictionary in all_squadrons:
		var other: SquadronInstance = entry["instance"] as SquadronInstance
		if _is_swarm_partner(attacker, target, other, target_pos,
				entry, obstruction_bodies, obstacles):
			return true
	return false


static func _is_swarm_partner(attacker: SquadronInstance,
		target: SquadronInstance,
		other: SquadronInstance,
		target_pos: Vector2,
		entry: Dictionary,
		obstruction_bodies: Array,
		obstacles: Array) -> bool:
	if other == null or other == attacker or other == target:
		return false
	if other.owner_player != attacker.owner_player or other.is_destroyed():
		return false
	var other_pos: Vector2 = entry["position"] as Vector2
	return is_engaged_with_target(other, other_pos, target, target_pos,
			obstruction_bodies, obstacles)


static func _append_player_squadron_positions(target: Array[Dictionary],
		player_state: PlayerState,
		play_area_size: Vector2) -> void:
	if player_state == null:
		return
	for squadron_var: Variant in player_state.squadrons:
		var squadron: SquadronInstance = squadron_var as SquadronInstance
		if squadron == null:
			continue
		target.append({
			"instance": squadron,
			"position": squadron.get_pixel_position(play_area_size),
		})


static func _play_area_size_for_positions() -> Vector2:
	if GameScale.play_area_size_px.x > 0.0 and GameScale.play_area_size_px.y > 0.0:
		return GameScale.play_area_size_px
	return Vector2(1000.0, 1000.0)


static func _normalise_keyword_name(keyword_name: String) -> String:
	return keyword_name.strip_edges().to_lower()


static func _keyword_dictionary(keyword_var: Variant) -> Dictionary:
	if keyword_var is Dictionary:
		return keyword_var as Dictionary
	return {}

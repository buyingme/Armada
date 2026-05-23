## AttackFlowExecutor
##
## Pure helper for constructing attack-flow payload dictionaries used by
## [AttackExecutor] when publishing [InteractionFlow] snapshots.
##
## Phase K14a extraction step: move serializable payload construction out
## of scene-layer orchestration while preserving existing runtime behavior.
class_name AttackFlowExecutor
extends RefCounted


const _DEFENSE_RESOLVE_ORDER: Dictionary = {
	Constants.DefenseToken.SCATTER: 0,
	Constants.DefenseToken.EVADE: 1,
	Constants.DefenseToken.BRACE: 2,
	Constants.DefenseToken.REDIRECT: 3,
	Constants.DefenseToken.CONTAIN: 4,
}


## Initializes ship-attack execution state on the shared AttackState.
func init_ship_exec_state(state: AttackState,
		ship_token: ShipToken) -> void:
	state.exec_mode = true
	state.squad_exec_mode = false
	state.exec_ship_token = ship_token
	state.exec_squad_token = null
	state.fired_zones.clear()
	state.current_attack = 0
	state.reset_dice()
	state.cf_dial_used = false
	state.cf_token_used = false
	state.attacked_squads.clear()


## Initializes squadron-attack execution state on the shared AttackState.
func init_squadron_exec_state(state: AttackState,
		squadron_token: SquadronToken) -> void:
	state.exec_mode = true
	state.squad_exec_mode = true
	state.exec_squad_token = squadron_token
	state.exec_ship_token = null
	state.fired_zones.clear()
	state.current_attack = 0
	state.reset_dice()
	state.cf_dial_used = false
	state.cf_token_used = false
	state.attacked_squads.clear()
	var inst: SquadronInstance = squadron_token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	state.attacker_ship = null
	state.attacker_zone = -1
	state.attacker_squadron = squadron_token
	state.attacker_name = squad_name
	state.attacker_zone_name = ""


## Extracts typed dice-result dictionaries from a roll payload.
func extract_roll_results(roll_result: Dictionary) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var raw: Array = roll_result.get("dice_results", [])
	for entry: Variant in raw:
		if entry is Dictionary:
			parsed.append(entry as Dictionary)
	return parsed


## Resets per-attack defense sub-state at the confirm boundary.
func reset_for_confirm(state: AttackState, damage: int) -> void:
	state.locked_tokens.clear()
	state.spent_tokens.clear()
	state.defense_commit_queue.clear()
	state.modified_damage = damage
	state.scatter_used = false
	state.redirect_remaining = 0
	state.redirect_zone = -1
	state.contain_used = false
	state.brace_used = false
	state.redirect_step = false
	state.evade_step = false


## Builds the DEFENSE_TOKENS payload patch for interaction flow.
func build_defense_payload(state: AttackState,
		def_inst: ShipInstance,
		gs: GameState,
		defense_resolver: DefenseTokenResolver = null,
		effect_registry: EffectRegistry = null) -> Dictionary:
	var defender_ship_index: int = gs.find_ship_index(def_inst) if gs else -1
	return {
		"blocked_defense_token_indices": build_blocked_defense_token_indices(
				state, def_inst, defense_resolver, effect_registry),
		"locked_tokens": state.locked_tokens.duplicate(true),
		"modified_damage": state.modified_damage,
		"dice_results": state.dice_results.duplicate(true),
		"defender_player": def_inst.owner_player,
		"defender_ship_index": defender_ship_index,
		"defender_speed": def_inst.current_speed,
		"defender_zone": state.defender_zone,
		"defense_tokens": def_inst.defense_tokens.duplicate(true),
	}


## Returns token indices blocked by persistent defense-token effects.
## Rules Reference: "Faulty Countermeasures"; "Capacitor Failure".
func build_blocked_defense_token_indices(state: AttackState,
		def_inst: ShipInstance,
		defense_resolver: DefenseTokenResolver,
		effect_registry: EffectRegistry) -> Array[int]:
	var blocked: Array[int] = []
	if state == null or def_inst == null or defense_resolver == null:
		return blocked
	for i: int in range(def_inst.defense_tokens.size()):
		var token: Dictionary = def_inst.defense_tokens[i]
		var token_state: Constants.DefenseTokenState = (
				token["state"] as Constants.DefenseTokenState)
		if token_state == Constants.DefenseTokenState.DISCARDED:
			continue
		if defense_resolver.is_token_blocked_by_effect(
				def_inst, token, effect_registry, state.defender_zone):
			blocked.append(i)
	return blocked


## Sorts selected defense token indices into canonical RRG resolve order.
func sort_defense_tokens_canonical(selected: Array[int],
		defense_tokens: Array[Dictionary]) -> Array[int]:
	var sorted: Array[int] = selected.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var key_a: int = _token_sort_key(a, defense_tokens)
		var key_b: int = _token_sort_key(b, defense_tokens)
		return key_a < key_b
	)
	return sorted


## Initializes state for defense commit processing.
## Returns true when there are queued tokens to process.
func begin_defense_commit(state: AttackState,
		selected: Array[int]) -> bool:
	if selected.is_empty():
		state.defense_step = false
		state.defense_commit_queue.clear()
		return false
	state.defense_commit_queue = selected.duplicate()
	return true


## Polls the next queued defense-token index.
## Returns has_token=false when the queue is empty and ends defense step.
func poll_next_defense_commit(state: AttackState) -> Dictionary:
	if state.defense_commit_queue.is_empty():
		state.defense_step = false
		return {
			"has_token": false,
			"token_index": - 1,
		}
	var token_index: int = int(state.defense_commit_queue.pop_front())
	return {
		"has_token": true,
		"token_index": token_index,
	}


## Counts faceup cards in serialized damage-card data.
func count_faceup_cards(card_data: Array) -> int:
	var count: int = 0
	for cd: Variant in card_data:
		if (cd as Dictionary).get("is_faceup", false):
			count += 1
	return count


## Determines if the first dealt damage card should be faceup.
func determine_first_card_faceup(state: AttackState,
		defense_resolver: DefenseTokenResolver,
		effect_registry: EffectRegistry) -> bool:
	var attacker: RefCounted = null
	var defender: RefCounted = null
	if state.attacker_ship is ShipToken:
		attacker = (
				state.attacker_ship as ShipToken).get_ship_instance()
	elif state.attacker_squadron is SquadronToken:
		attacker = (
				state.attacker_squadron as SquadronToken).get_squadron_instance()
	if state.defender_ship is ShipToken:
		defender = (
				state.defender_ship as ShipToken).get_ship_instance()
	return defense_resolver.determine_first_card_faceup(
			state.dice_results, state.contain_used,
			effect_registry, attacker, defender)


## Builds the ship-damage summary string for UI display.
func build_damage_summary(damage_dealer: DamageDealer,
		def_inst: ShipInstance,
		def_zone_str: String,
		shield_absorbed: int,
		cards_dealt: int,
		faceup_card_name: String) -> String:
	var hull_remaining: int = damage_dealer.calculate_hull_remaining(
			def_inst.ship_data.hull, def_inst.get_total_damage())
	return damage_dealer.build_damage_summary(
			def_zone_str, shield_absorbed, cards_dealt,
			faceup_card_name, hull_remaining, def_inst.ship_data.hull)


## Returns true if redirect can continue from current attack state.
func can_continue_redirect(state: AttackState,
		def_inst: ShipInstance,
		defense_resolver: DefenseTokenResolver) -> bool:
	var def_zone: Constants.HullZone = (
			state.defender_zone as Constants.HullZone)
	return defense_resolver.can_redirect_continue(
			state.redirect_remaining, def_zone, def_inst)


func _token_sort_key(token_index: int,
		defense_tokens: Array[Dictionary]) -> int:
	if token_index < 0 or token_index >= defense_tokens.size():
		return 999
	var token: Dictionary = defense_tokens[token_index]
	var token_type: int = int(token.get("type", -1))
	return int(_DEFENSE_RESOLVE_ORDER.get(token_type, 999))


## Returns a payload patch that clears target/defense/dice fields between
## consecutive attacks so mirror UI panels do not retain stale state.
func build_clear_target_patch() -> Dictionary:
	return {
		"defender_name": "",
		"defender_zone": - 1,
		"defender_player": - 1,
		"defender_ship_index": - 1,
		"target_kind": "",
		"target_ship_index": - 1,
		"target_squadron_index": - 1,
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND:
				SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": "",
		"modified_damage": 0,
		"final_damage": 0,
		"locked_tokens": [],
		"defense_tokens": [],
		"dice_pool": {},
		"dice_results": [],
		"evade_active": false,
		"evade_range_band": "",
		"redirect_active": false,
		"redirect_adjacent_zones": [],
		"redirect_remaining": 0,
	}


## Builds attacker/target identity fields for interaction-flow payloads.
## All values are plain ints/strings for serialization safety.
func compute_attack_identity_patch(state: AttackState,
		gs: GameState) -> Dictionary:
	var patch: Dictionary = {
		"attacker_name": state.attacker_name,
		"attacker_zone": int(state.attacker_zone),
		"attacker_zone_name": state.attacker_zone_name,
		"defender_name": state.defender_name,
		"defender_zone": int(state.defender_zone),
	}
	patch.merge(SquadronKeywordRuleHelper.make_attack_kind_payload(
			state.attack_kind), true)
	if gs == null:
		return patch
	if state.attacker_ship != null:
		var atk_inst: ShipInstance = state.attacker_ship.get_ship_instance()
		patch["attacker_kind"] = "ship"
		patch["attacker_ship_index"] = gs.find_ship_index(atk_inst)
		if atk_inst != null:
			patch["attacker_player"] = atk_inst.owner_player
	elif state.attacker_squadron != null:
		var atk_sq: SquadronInstance = \
				state.attacker_squadron.get_squadron_instance()
		patch["attacker_kind"] = "squadron"
		patch["attacker_squadron_index"] = gs.find_squadron_index(atk_sq)
		if atk_sq != null:
			patch["attacker_player"] = atk_sq.owner_player
	if state.defender_ship != null:
		var def_inst: ShipInstance = state.defender_ship.get_ship_instance()
		patch["target_kind"] = "ship"
		patch["target_ship_index"] = gs.find_ship_index(def_inst)
		if def_inst != null:
			patch["defender_player"] = def_inst.owner_player
	elif state.defender_squadron != null:
		var def_sq: SquadronInstance = \
				state.defender_squadron.get_squadron_instance()
		patch["target_kind"] = "squadron"
		patch["target_squadron_index"] = gs.find_squadron_index(def_sq)
		if def_sq != null:
			patch["defender_player"] = def_sq.owner_player
	return patch


## Prepares a faceup damage card for post-processing.
## Returns a descriptor indicating what needs to happen: persistent effect
## registration and immediate effect deferral.
## Does NOT mutate any state — callers decide what to do with the result.
##
## Returns Dictionary:
##   "should_register_persistent": bool — card needs persistent effect registered
##   "has_immediate": bool — card has immediate effect (may need deferral)
##   "card_title": String — card name for logging/deferred tracking
func prepare_faceup_card(card: DamageCard,
		damage_dealer: DamageDealer) -> Dictionary:
	var should_register: bool = damage_dealer.should_register_persistent(card)
	var has_immediate: bool = damage_dealer.has_immediate_effect(card)
	return {
		"should_register_persistent": should_register,
		"has_immediate": has_immediate,
		"card_title": card.title,
	}


## Determines the immediate-effect resolution path for a faceup card.
## Returns a descriptor indicating whether to auto-resolve, defer, or skip.
##
## Returns Dictionary:
##   "should_process": bool — card has an immediate effect
##   "should_defer": bool — requires player choice (defer for modal)
##   "choice_info": Dictionary — choice descriptor (empty if auto-resolve)
##   "card_id": String — effect_id for auto-resolve routing
func decide_immediate_effect_flow(card: DamageCard,
		ship: ShipInstance,
		immediate_resolver: ImmediateEffectResolver) -> Dictionary:
	# Quick check: not an immediate effect card.
	if not ImmediateEffectResolver.is_immediate(card):
		return {
			"should_process": false,
			"should_defer": false,
			"choice_info": {},
			"card_id": "",
		}
	# Get choice info; if empty, auto-resolve; if non-empty, defer.
	var choice_info: Dictionary = immediate_resolver.get_required_choice(
			card, ship)
	var should_defer: bool = not choice_info.is_empty()
	return {
		"should_process": true,
		"should_defer": should_defer,
		"choice_info": choice_info,
		"card_id": card.effect_id,
	}

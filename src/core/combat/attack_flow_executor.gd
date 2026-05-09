## AttackFlowExecutor
##
## Pure helper for constructing attack-flow payload dictionaries used by
## [AttackExecutor] when publishing [InteractionFlow] snapshots.
##
## Phase K14a extraction step: move serializable payload construction out
## of scene-layer orchestration while preserving existing runtime behavior.
class_name AttackFlowExecutor
extends RefCounted


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
		gs: GameState) -> Dictionary:
	var defender_ship_index: int = gs.find_ship_index(def_inst) if gs else -1
	return {
		"locked_tokens": state.locked_tokens.duplicate(true),
		"modified_damage": state.modified_damage,
		"defender_player": def_inst.owner_player,
		"defender_ship_index": defender_ship_index,
		"defender_speed": def_inst.current_speed,
		"defender_zone": state.defender_zone,
		"defense_tokens": def_inst.defense_tokens.duplicate(true),
	}


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
	elif state.defender_squadron != null:
		var def_sq: SquadronInstance = \
				state.defender_squadron.get_squadron_instance()
		patch["target_kind"] = "squadron"
		patch["target_squadron_index"] = gs.find_squadron_index(def_sq)
	return patch
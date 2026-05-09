## AttackFlowExecutor
##
## Pure helper for constructing attack-flow payload dictionaries used by
## [AttackExecutor] when publishing [InteractionFlow] snapshots.
##
## Phase K14a extraction step: move serializable payload construction out
## of scene-layer orchestration while preserving existing runtime behavior.
class_name AttackFlowExecutor
extends RefCounted


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
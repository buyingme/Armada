## Dormant protocol-7 CAP-OBS-001 authority/application boundary.
class_name CandidateResolveAsteroidOverlapCommand
extends GameCommand

const APPLICATION: GDScript = preload("res://src/core/damage/candidate_damage_application.gd")
const IMMEDIATE: GDScript = preload("res://src/core/damage/immediate_damage_authority.gd")
const OVERLAP: GDScript = preload("res://src/core/geometry/obstacle_overlap_authority.gd")
const KEYS: Array[String] = ["owner_player", "ship_index", "ship_activation_identity", "maneuver_execution_id", "obstacle_id"]

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_asteroid_overlap", p_payload)

func application_contract_id() -> String: return command_type
func application_contract_version() -> int: return 3

func validate(game_state: GameState) -> String:
	var base := super.validate(game_state)
	if not base.is_empty(): return base
	if not _exact(payload, KEYS) or typeof(payload["owner_player"]) != TYPE_INT or typeof(payload["ship_index"]) != TYPE_INT:
		return "Invalid asteroid payload."
	var owner := int(payload["owner_player"])
	var ship := game_state.get_ship(owner, int(payload["ship_index"]))
	if player_index != owner or ship == null or ship.is_destroyed():
		return "Invalid asteroid actor or target."
	if ship.has_active_obstacle_resolution() or ship.has_active_immediate_resolution():
		return "Another obstacle or immediate obligation is active."
	if ship.matching_satisfied_obstacle_pre_effect(
			str(payload["obstacle_id"]), "asteroid").is_empty():
		return "Asteroid pre-effect notice is not acknowledged."
	if game_state.faceup_damage_inspection != null:
		return "Another faceup inspection is pending."
	var execution := ship.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity", "")) != str(payload["ship_activation_identity"]) or str(execution.get("maneuver_execution_id", "")) != str(payload["maneuver_execution_id"]) or not bool(execution.get("final_transform_applied", false)):
		return "Stale asteroid execution."
	var expected := _next(game_state, owner, int(payload["ship_index"]))
	if expected.is_empty() or str(expected["obstacle_id"]) != str(payload["obstacle_id"]) or str(expected["obstacle_type"]) != "asteroid":
		return "Asteroid is not the next unresolved overlap."
	if game_state.passive_damage_ledger != null:
		if not ship.is_passive_damage_bound() \
				or not game_state.passive_damage_ledger.can_consume_hidden_draws(1):
			return "Passive asteroid damage is unavailable."
	elif game_state.damage_deck == null \
			or game_state.damage_deck.get_total_count() <= 0 \
			or not game_state.validate_damage_state_for_save7():
		return "Damage authority cannot deal the asteroid card."
	return ""

func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty(): return {}
	var owner := int(payload["owner_player"]); var index := int(payload["ship_index"])
	var ship := game_state.get_ship(owner, index)
	var deck_before := game_state.damage_deck.serialize_for_save7()
	var damage_before := ship.serialize_damage_state_for_save7()
	var boundary_before: Dictionary = ship.ship_activation_boundary_snapshot()
	var occurrence: Dictionary = ship.matching_satisfied_obstacle_pre_effect(
			str(payload["obstacle_id"]), "asteroid")
	var card := game_state.damage_deck.draw_card()
	if card == null or card.physical_card_id.is_empty(): return {}
	card.flip_faceup(); ship.add_faceup_damage(card)
	var enclosure := {"enclosing_kind":"maneuver", "ship_activation_identity":payload["ship_activation_identity"], "maneuver_execution_id":payload["maneuver_execution_id"], "maneuver_source_kind":"asteroid", "maneuver_source_id":payload["obstacle_id"]}
	var addition: Dictionary = IMMEDIATE.bind_assigned_faceup(game_state, owner, index, card, sequence, 0, enclosure)
	if addition.is_empty():
		_restore(game_state, ship, deck_before, damage_before,
				boundary_before); return {}
	var immediate_id := str(addition.get("immediate_resolution_id", ""))
	var inspection: FaceupDamageInspection = FaceupDamageInspection.create(
			owner, index, ship.roster_entry_id,
			FaceupDamageInspection.public_card_from_addition(addition),
			game_state.required_faceup_inspection_principals())
	if inspection == null:
		_restore(game_state, ship, deck_before, damage_before,
				boundary_before); return {}
	var destroyed: bool = ship.is_destroyed()
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	var interrupted: bool = destroyed and ship.has_active_ship_activation()
	if not destroyed and not immediate_id.is_empty():
		if not ship.open_asteroid_resolution(str(payload["ship_activation_identity"]), str(payload["maneuver_execution_id"]), str(payload["obstacle_id"]), immediate_id):
			_restore(game_state, ship, deck_before, damage_before,
					boundary_before); return {}
		if not ship.validate_maneuver_immediate_nesting():
			_restore(game_state, ship, deck_before, damage_before,
					boundary_before); return {}
		if not ship.consume_satisfied_obstacle_pre_effect(
				str(occurrence["occurrence_id"]), str(payload["obstacle_id"])):
			_restore(game_state, ship, deck_before, damage_before,
					boundary_before); return {}
	elif not destroyed:
		if not ship.consume_satisfied_obstacle_pre_effect(
				str(occurrence["occurrence_id"]), str(payload["obstacle_id"])) \
				or not ship.open_asteroid_completion_outstanding(
					occurrence, inspection.inspection_id()):
			_restore(game_state, ship, deck_before, damage_before,
					boundary_before); return {}
	if not game_state.install_faceup_damage_inspection(inspection):
		_restore(game_state, ship, deck_before, damage_before,
				boundary_before); return {}
	if destroyed:
		ship.mark_destroyed()
	var cleanup: Dictionary = DestroyUnitCommand.cleanup_in_source(
			game_state, owner, index, interrupted) if destroyed else {}
	var result := payload.duplicate(true)
	result["immediate_resolution_id"] = immediate_id
	result["faceup_damage_inspection"] = inspection.serialize()
	result["destruction_cleanup"] = cleanup
	result["asteroid_completion_outstanding"] = \
			ship.asteroid_completion_outstanding_snapshot()
	result["damage_application"] = {"owner_player":owner,"ship_index":index,"shield_changes":[],"facedown_delta":0,"faceup_additions":[addition],"faceup_removals":[],"public_discards":[],"new_hull":new_hull,"destroyed":destroyed}
	return result

func project_application_result(result: Dictionary, viewer_player: int) -> Dictionary:
	return result.duplicate(true) if viewer_player in [0,1] and _result_valid(result) else {}

func execute_with_application_result(game_state: GameState, result: Dictionary) -> Dictionary:
	if not _result_valid(result) or game_state.passive_damage_ledger == null or not validate(game_state).is_empty(): return {}
	for key in KEYS:
		if result[key] != payload[key]: return {}
	var ship := game_state.get_ship(int(payload["owner_player"]), int(payload["ship_index"]))
	var damage: Dictionary = result["damage_application"]
	var inspection_data: Dictionary = result["faceup_damage_inspection"] as Dictionary
	var inspection: FaceupDamageInspection = FaceupDamageInspection.deserialize(inspection_data)
	var occurrence: Dictionary = ship.matching_satisfied_obstacle_pre_effect(
			str(payload["obstacle_id"]), "asteroid")
	var outstanding: Dictionary = result[
			"asteroid_completion_outstanding"] as Dictionary
	var destroyed: bool = bool(damage["destroyed"])
	var interrupted: bool = destroyed and ship.has_active_ship_activation()
	var cleanup: Dictionary = result["destruction_cleanup"] as Dictionary
	var next_controller: int = DestroyUnitCommand.next_controller_after_source(
			game_state, int(payload["owner_player"]), [{"owner_player":
				int(payload["owner_player"]), "ship_index":
				int(payload["ship_index"])}]) if interrupted else -1
	var expected_new_hull: int = ship.ship_data.hull \
			- ship.get_total_damage() - 1
	if damage["facedown_delta"] != 0 \
			or (damage["faceup_additions"] as Array).size() != 1 \
			or int(damage["new_hull"]) != expected_new_hull \
			or bool(damage["destroyed"]) != (expected_new_hull <= 0) \
			or inspection == null \
			or int(inspection_data["owner_player"]) != int(payload["owner_player"]) \
			or int(inspection_data["ship_index"]) != int(payload["ship_index"]) \
			or str(inspection_data["roster_entry_id"]) != ship.roster_entry_id \
			or inspection_data["public_card"] != FaceupDamageInspection \
					.public_card_from_addition(damage["faceup_additions"][0] as Dictionary) \
			or inspection.required_principal_ids() \
					!= game_state.required_faceup_inspection_principals() \
			or game_state.faceup_damage_inspection != null \
			or occurrence.is_empty() \
			or (not destroyed and str(result["immediate_resolution_id"]).is_empty() \
				and outstanding != {
					"ship_activation_identity": payload["ship_activation_identity"],
					"maneuver_execution_id": payload["maneuver_execution_id"],
					"ordered_ordinal": occurrence["ordered_ordinal"],
					"occurrence_id": occurrence["occurrence_id"],
					"obstacle_id": payload["obstacle_id"],
					"inspection_id": inspection.inspection_id(),
					"inspection_released": false,
				}) \
			or ((destroyed or not str(result["immediate_resolution_id"]).is_empty()) \
				and not outstanding.is_empty()) \
			or (destroyed and not DestroyUnitCommand.prevalidate_source_cleanup(
					cleanup, ship.get_facedown_damage_count(), interrupted,
					next_controller)) \
			or (not destroyed and not cleanup.is_empty()) \
			or not game_state.passive_damage_ledger.can_consume_hidden_draws(1): return {}
	var enclosure := {"enclosing_kind":"maneuver", "ship_activation_identity":payload["ship_activation_identity"], "maneuver_execution_id":payload["maneuver_execution_id"], "maneuver_source_kind":"asteroid", "maneuver_source_id":payload["obstacle_id"]}
	if not APPLICATION.install_public_addition(ship, damage["faceup_additions"][0], enclosure): return {}
	game_state.passive_damage_ledger.consume_hidden_draws(1)
	if not game_state.install_faceup_damage_inspection(inspection): return {}
	var immediate_id := str(result["immediate_resolution_id"])
	if destroyed:
		ship.mark_destroyed()
		if not DestroyUnitCommand.install_cleanup_in_source(game_state,
				int(payload["owner_player"]), int(payload["ship_index"]),
				interrupted, cleanup): return {}
	elif not immediate_id.is_empty():
		if not ship.open_asteroid_resolution(str(payload["ship_activation_identity"]), str(payload["maneuver_execution_id"]), str(payload["obstacle_id"]), immediate_id): return {}
		if not ship.validate_maneuver_immediate_nesting(): return {}
		if not ship.consume_satisfied_obstacle_pre_effect(
				str(occurrence["occurrence_id"]), str(payload["obstacle_id"])): return {}
	else:
		if not ship.consume_satisfied_obstacle_pre_effect(
				str(occurrence["occurrence_id"]), str(payload["obstacle_id"])) \
				or not ship.open_asteroid_completion_outstanding(
					occurrence, inspection.inspection_id()): return {}
	return result.duplicate(true)

func _next(game_state: GameState, owner: int, index: int) -> Dictionary:
	var ship := game_state.get_ship(owner, index); var execution := ship.active_maneuver_execution_snapshot(); var by_id := {}
	for item in OVERLAP.unresolved_overlaps(game_state, owner, index, str(execution.get("maneuver_execution_id", ""))): by_id[str(item["obstacle_id"])] = item
	for raw in execution.get("obstacle_resolution_order", []):
		if by_id.has(str(raw)): return by_id[str(raw)]
	return {}

static func _restore(game_state: GameState, ship: ShipInstance, deck: Dictionary, damage: Dictionary, boundary: Dictionary) -> void:
	game_state.damage_deck = DamageDeck.deserialize_for_save7(deck)
	if game_state.damage_deck != null and game_state.rng != null: game_state.damage_deck.set_rng(game_state.rng)
	ship.install_damage_state_for_save7(damage)
	ship.restore_ship_activation_boundary(boundary)

static func _result_valid(result: Dictionary) -> bool:
	var keys := KEYS.duplicate(); keys.append_array(["immediate_resolution_id","damage_application","faceup_damage_inspection","destruction_cleanup","asteroid_completion_outstanding"])
	return _exact(result, keys) and typeof(result["immediate_resolution_id"]) == TYPE_STRING and result["faceup_damage_inspection"] is Dictionary and result["destruction_cleanup"] is Dictionary and result["asteroid_completion_outstanding"] is Dictionary and APPLICATION.is_exact_damage_application(result["damage_application"])

static func _exact(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

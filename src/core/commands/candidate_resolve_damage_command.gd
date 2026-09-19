## Dormant protocol-7 Attack damage candidate for the changed ship branch.
## Squadron damage retains its existing contract outside this candidate slice.
class_name CandidateResolveDamageCommand
extends ResolveDamageCommand


const ASSIGNMENT: GDScript = preload(
		"res://src/core/damage/immediate_damage_authority.gd")
const APPLICATION: GDScript = preload(
		"res://src/core/damage/candidate_damage_application.gd")

var _drew_immediate_candidate: bool = false


func drew_immediate_faceup_card() -> bool:
	return _drew_immediate_candidate


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, p_payload)


func application_contract_version() -> int:
	return 2


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	if viewer_player not in [0, 1]:
		return {}
	if authority_result.get("target_type") == "squadron":
		return {}
	return authority_result.duplicate(true) \
			if _application_result_is_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	_drew_immediate_candidate = false
	if game_state == null:
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack != null \
			and attack.defender_kind == CurrentAttackState.KIND_SQUADRON:
		return super.execute_with_application_result(
				game_state, application_result)
	if not _application_result_is_valid(application_result) \
			or game_state.passive_damage_ledger == null:
		return {}
	var base: String = validate(game_state)
	if not base.is_empty():
		return {}
	attack = game_state.current_attack_state
	if attack.defender_kind != CurrentAttackState.KIND_SHIP \
			or str(application_result["attack_id"]) != attack.attack_id \
			or str(application_result["target_kind"]) != "ship" \
			or int(application_result["owner_player"]) \
					!= attack.defender_player \
			or int(application_result["ship_index"]) \
					!= attack.defender_index:
		return {}
	var ship: ShipInstance = game_state.get_ship(
			attack.defender_player, attack.defender_index)
	var damage_application: Dictionary = application_result[
			"damage_application"] as Dictionary
	if not _passive_damage_matches_prestate(
			game_state, attack, ship, damage_application):
		return {}
	var zone: String = Constants.hull_zone_to_string(
			attack.defender_zone as Constants.HullZone)
	var damage: int = attack.derive_damage(game_state)
	var shield_damage: int = mini(
			int(ship.current_shields[zone]), damage)
	var draws: int = damage - shield_damage
	var replacement: CurrentAttackState = _resolved_ship_attack(
			game_state, attack, ship, zone, damage, shield_damage, draws)
	if replacement == null:
		return {}
	var additions: Array = damage_application["faceup_additions"] as Array
	_drew_immediate_candidate = not additions.is_empty() \
			and str((additions[0] as Dictionary).get(
					"immediate_obligation", "none")) == "open"
	if not additions.is_empty() and not APPLICATION.install_public_addition(
			ship, additions[0] as Dictionary,
			{"enclosing_kind": "attack", "attack_id": attack.attack_id}):
		return {}
	# Every later operation was prevalidated and is non-fallible.
	game_state.passive_damage_ledger.consume_hidden_draws(draws)
	game_state.passive_damage_ledger.increment_facedown(
			ship.passive_damage_key(), int(damage_application["facedown_delta"]))
	for raw_change: Variant in damage_application["shield_changes"]:
		var change: Dictionary = raw_change as Dictionary
		ship.current_shields[str(change["zone"])] = int(change["new_shields"])
	game_state.set_current_attack_state(replacement)
	if bool(damage_application["destroyed"]):
		ship.mark_destroyed()
	return application_result.duplicate(true)


func validate(game_state: GameState) -> String:
	if payload.size() != 1 or not payload.has("attack_id") \
			or typeof(payload["attack_id"]) != TYPE_STRING \
			or str(payload["attack_id"]).is_empty():
		return "Invalid resolve_damage v2 intent."
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		if game_state.passive_damage_ledger != null:
			if not game_state.validate_for_passive_network_installation():
				return "Candidate passive damage state is invalid."
		elif not game_state.validate_damage_state_for_save7():
			return "Candidate damage identity state is invalid."
	return ""


func execute(game_state: GameState) -> Dictionary:
	_drew_immediate_candidate = false
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack.defender_kind != CurrentAttackState.KIND_SHIP:
		return super.execute(game_state)
	var owner: int = attack.defender_player
	var ship_index: int = attack.defender_index
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var zone: String = Constants.hull_zone_to_string(
			attack.defender_zone as Constants.HullZone)
	var damage: int = attack.derive_damage(game_state)
	var shield_damage: int = mini(
			int(ship.current_shields.get(zone, 0)), damage)
	var draw_count: int = damage - shield_damage
	var deck_before: Dictionary = game_state.damage_deck.serialize_for_save7() \
			if draw_count > 0 else {}
	var ship_before: Dictionary = ship.serialize_damage_state_for_save7()
	var attack_before: CurrentAttackState = attack
	var additions: Array[Dictionary] = []
	var facedown_added: int = 0
	for ordinal: int in range(draw_count):
		var card: DamageCard = game_state.damage_deck.draw_card()
		if card == null or card.physical_card_id.is_empty():
			_restore(game_state, ship, attack_before, deck_before, ship_before)
			return {}
		if ordinal == 0 and _first_card_faceup(game_state, attack):
			card.flip_faceup()
			ship.add_faceup_damage(card)
			var addition: Dictionary = ASSIGNMENT.bind_assigned_faceup(
					game_state, owner, ship_index, card, sequence, ordinal,
					{"enclosing_kind": "attack", "attack_id": attack.attack_id})
			if addition.is_empty():
				_restore(game_state, ship, attack_before, deck_before, ship_before)
				return {}
			additions.append(addition)
			_drew_immediate_candidate = str(addition.get(
					"immediate_obligation", "none")) == "open"
		else:
			card.flip_facedown()
			ship.add_facedown_damage(card)
			facedown_added += 1
	var replacement: CurrentAttackState = attack.with_patch({
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"damage_stage": CurrentAttackState.DAMAGE_RESOLVED,
		"resolved_outcome": {
			"target_kind": CurrentAttackState.KIND_SHIP,
			"affected_zone": int(attack.defender_zone),
			"final_damage": damage,
			"shield_absorbed": shield_damage,
			"post_resolution_shields":
					int(ship.current_shields.get(zone, 0)) - shield_damage,
			"hull_damage": draw_count,
			"destroyed": ship.get_total_damage() >= ship.ship_data.hull,
		},
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		_restore(game_state, ship, attack_before, deck_before, ship_before)
		return {}
	ship.reduce_shields(zone, shield_damage)
	var destroyed: bool = ship.is_destroyed()
	if destroyed:
		ship.mark_destroyed()
	return {
		"attack_id": attack.attack_id,
		"target_kind": "ship",
		"owner_player": owner,
		"ship_index": ship_index,
		"damage_application": {
			"owner_player": owner,
			"ship_index": ship_index,
			"shield_changes": [{"zone": zone,
				"new_shields": int(ship.current_shields[zone])}] \
					if shield_damage > 0 else [],
			"facedown_delta": facedown_added,
			"faceup_additions": additions,
			"faceup_removals": [],
			"public_discards": [],
			"new_hull": ship.ship_data.hull - ship.get_total_damage(),
			"destroyed": destroyed,
		},
	}


static func _restore(game_state: GameState, ship: ShipInstance,
		attack: CurrentAttackState, deck: Dictionary,
		ship_damage: Dictionary) -> void:
	if not deck.is_empty():
		game_state.damage_deck = DamageDeck.deserialize_for_save7(deck)
		if game_state.damage_deck != null and game_state.rng != null:
			game_state.damage_deck.set_rng(game_state.rng)
	ship.install_damage_state_for_save7(ship_damage)
	game_state.set_current_attack_state(attack)


static func _application_result_is_valid(result: Dictionary) -> bool:
	return _has_exact_keys(result, [
		"attack_id", "target_kind", "owner_player", "ship_index",
		"damage_application"]) \
			and typeof(result.get("attack_id")) == TYPE_STRING \
			and not str(result["attack_id"]).is_empty() \
			and result.get("target_kind") == "ship" \
			and typeof(result.get("owner_player")) == TYPE_INT \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and APPLICATION.is_exact_damage_application(
					result.get("damage_application"))


func _passive_damage_matches_prestate(game_state: GameState,
		attack: CurrentAttackState, ship: ShipInstance,
		application: Dictionary) -> bool:
	if ship == null or ship.is_destroyed() \
			or ship.has_active_immediate_resolution() \
			or int(application["owner_player"]) != attack.defender_player \
			or int(application["ship_index"]) != attack.defender_index:
		return false
	var zone: String = Constants.hull_zone_to_string(
			attack.defender_zone as Constants.HullZone)
	var damage: int = attack.derive_damage(game_state)
	var shield_damage: int = mini(
			int(ship.current_shields[zone]), damage)
	var draws: int = damage - shield_damage
	var additions: Array = application["faceup_additions"] as Array
	var faceup_count: int = 1 if draws > 0 \
			and _first_card_faceup(game_state, attack) else 0
	if additions.size() != faceup_count \
			or int(application["facedown_delta"]) != draws - faceup_count \
			or not (application["faceup_removals"] as Array).is_empty() \
			or not (application["public_discards"] as Array).is_empty() \
			or not game_state.passive_damage_ledger.can_consume_hidden_draws(
					draws):
		return false
	var changes: Array = application["shield_changes"] as Array
	if changes.size() != (1 if shield_damage > 0 else 0):
		return false
	if shield_damage > 0 and changes[0] != {
		"zone": zone,
		"new_shields": int(ship.current_shields[zone]) - shield_damage,
	}:
		return false
	if faceup_count == 1:
		var addition: Dictionary = additions[0] as Dictionary
		if str(addition["public_card_ref"]) != "faceup:%d:0" % sequence:
			return false
	var expected_hull: int = ship.ship_data.hull \
			- ship.get_total_damage() - draws
	return int(application["new_hull"]) == expected_hull \
			and bool(application["destroyed"]) == (expected_hull <= 0)


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true

## Dormant protocol-7 ordinary ship-collision damage candidate.
## It consumes only immutable evidence from the active Maneuver execution.
class_name CandidateResolveShipCollisionDamageCommand
extends GameCommand


const APPLICATION: GDScript = preload(
		"res://src/core/damage/candidate_damage_application.gd")
const EXACT_KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id", "target_owner_player", "target_ship_index",
	"exact_once_key",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_ship_collision_damage", p_payload)


func application_contract_id() -> String:
	return "resolve_ship_collision_damage"


func application_contract_version() -> int:
	return 2


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, EXACT_KEYS):
		return "Invalid collision-damage payload shape."
	for key: String in [
			"owner_player", "ship_index", "target_owner_player",
			"target_ship_index"]:
		if typeof(payload[key]) != TYPE_INT:
			return "Invalid collision-damage target types."
	for key: String in [
			"ship_activation_identity", "maneuver_execution_id",
			"exact_once_key"]:
		if typeof(payload[key]) != TYPE_STRING or str(payload[key]).is_empty():
			return "Invalid collision-damage identity types."
	var owner: int = int(payload["owner_player"])
	if player_index != owner:
		return "Wrong authority-derived Maneuver owner."
	var moving: ShipInstance = game_state.get_ship(
			owner, int(payload["ship_index"]))
	var target: ShipInstance = game_state.get_ship(
			int(payload["target_owner_player"]),
			int(payload["target_ship_index"]))
	if moving == null or target == null \
			or moving == target \
			or moving.is_destroyed() or target.is_destroyed():
		return "Collision target is unavailable."
	var execution: Dictionary = moving.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity", "")) \
			!= str(payload["ship_activation_identity"]) \
			or str(execution.get("maneuver_execution_id", "")) \
			!= str(payload["maneuver_execution_id"]) \
			or not bool(execution.get("final_transform_applied", false)):
		return "Collision damage is outside the matching moved execution."
	var collision: Dictionary = execution.get("ship_collision", {})
	if str(collision.get("kind", "")) != "closest_ship" \
			or bool(collision.get("damage_resolved", false)) \
			or int(collision.get("target_owner_player", -1)) \
					!= int(payload["target_owner_player"]) \
			or int(collision.get("target_ship_index", -1)) \
					!= int(payload["target_ship_index"]) \
			or str(collision.get("exact_once_key", "")) \
					!= str(payload["exact_once_key"]):
		return "Collision evidence mismatch or already resolved."
	if game_state.passive_damage_ledger != null:
		if not game_state.passive_damage_ledger.can_consume_hidden_draws(2):
			return "Passive damage ledger lacks two draws."
	elif game_state.damage_deck == null \
			or game_state.damage_deck.get_total_count() < 2:
		return "Damage deck lacks two physical cards."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty() \
			or game_state.passive_damage_ledger != null:
		return {}
	var moving: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	var target: ShipInstance = game_state.get_ship(
			int(payload["target_owner_player"]),
			int(payload["target_ship_index"]))
	var deck_before: Dictionary = game_state.damage_deck.serialize_for_save7()
	var moving_before: Dictionary = moving.serialize_damage_state_for_save7()
	var target_before: Dictionary = target.serialize_damage_state_for_save7()
	var boundary_before: Dictionary = moving.ship_activation_boundary_snapshot()
	var first: DamageCard = game_state.damage_deck.draw_card()
	var second: DamageCard = game_state.damage_deck.draw_card()
	if first == null or second == null \
			or first.physical_card_id.is_empty() \
			or second.physical_card_id.is_empty():
		_restore(game_state, moving, target, deck_before,
				moving_before, target_before, boundary_before)
		return {}
	first.flip_facedown()
	second.flip_facedown()
	moving.add_facedown_damage(first)
	target.add_facedown_damage(second)
	if not moving.mark_maneuver_ship_collision_damage_resolved(
			str(payload["ship_activation_identity"]),
			str(payload["maneuver_execution_id"]),
			str(payload["exact_once_key"])):
		_restore(game_state, moving, target, deck_before,
				moving_before, target_before, boundary_before)
		return {}
	var moving_damage: Dictionary = _damage_application(
			moving, int(payload["owner_player"]), int(payload["ship_index"]))
	var target_damage: Dictionary = _damage_application(
			target, int(payload["target_owner_player"]),
			int(payload["target_ship_index"]))
	if moving.is_destroyed():
		moving.mark_destroyed()
	if target.is_destroyed():
		target.mark_destroyed()
	var result: Dictionary = payload.duplicate(true)
	result["moving_damage_application"] = moving_damage
	result["target_damage_application"] = target_damage
	result["collision_damage_resolved"] = true
	return result


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	if viewer_player not in [0, 1] \
			or not _result_is_valid(authority_result):
		return {}
	return authority_result.duplicate(true)


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_is_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	for key: String in EXACT_KEYS:
		if application_result[key] != payload[key]:
			return {}
	var ledger: PassiveDamageLedger = game_state.passive_damage_ledger
	var moving: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	var target: ShipInstance = game_state.get_ship(
			int(payload["target_owner_player"]),
			int(payload["target_ship_index"]))
	if ledger == null \
			or not _passive_application_matches(
					moving, target, application_result) \
			or not ledger.consume_hidden_draws(2) \
			or not ledger.increment_facedown(moving.passive_damage_key()) \
			or not ledger.increment_facedown(target.passive_damage_key()) \
			or not moving.mark_maneuver_ship_collision_damage_resolved(
					str(payload["ship_activation_identity"]),
					str(payload["maneuver_execution_id"]),
					str(payload["exact_once_key"])):
		return {}
	if bool(application_result["moving_damage_application"]["destroyed"]):
		moving.mark_destroyed()
	if bool(application_result["target_damage_application"]["destroyed"]):
		target.mark_destroyed()
	return application_result.duplicate(true)


static func _passive_application_matches(moving: ShipInstance,
		target: ShipInstance, result: Dictionary) -> bool:
	var moving_damage: Dictionary = result["moving_damage_application"]
	var target_damage: Dictionary = result["target_damage_application"]
	return _ordinary_facedown_matches(moving, moving_damage,
			int(result["owner_player"]), int(result["ship_index"])) \
			and _ordinary_facedown_matches(target, target_damage,
					int(result["target_owner_player"]),
					int(result["target_ship_index"]))


static func _ordinary_facedown_matches(ship: ShipInstance,
		application: Dictionary, owner: int, ship_index: int) -> bool:
	var expected_hull: int = ship.ship_data.hull - ship.get_total_damage() - 1
	return int(application["owner_player"]) == owner \
			and int(application["ship_index"]) == ship_index \
			and (application["shield_changes"] as Array).is_empty() \
			and int(application["facedown_delta"]) == 1 \
			and (application["faceup_additions"] as Array).is_empty() \
			and (application["faceup_removals"] as Array).is_empty() \
			and (application["public_discards"] as Array).is_empty() \
			and int(application["new_hull"]) == expected_hull \
			and bool(application["destroyed"]) == (expected_hull <= 0)


static func _damage_application(ship: ShipInstance, owner: int,
		ship_index: int) -> Dictionary:
	return {
		"owner_player": owner,
		"ship_index": ship_index,
		"shield_changes": [],
		"facedown_delta": 1,
		"faceup_additions": [],
		"faceup_removals": [],
		"public_discards": [],
		"new_hull": ship.ship_data.hull - ship.get_total_damage(),
		"destroyed": ship.is_destroyed(),
	}


static func _result_is_valid(result: Dictionary) -> bool:
	var keys: Array[String] = EXACT_KEYS.duplicate()
	keys.append_array([
		"moving_damage_application", "target_damage_application",
		"collision_damage_resolved",
	])
	if not _has_exact_keys(result, keys) \
			or result.get("collision_damage_resolved") != true \
			or typeof(result.get("owner_player")) != TYPE_INT \
			or int(result["owner_player"]) not in [0, 1] \
			or typeof(result.get("ship_index")) != TYPE_INT \
			or int(result["ship_index"]) < 0 \
			or typeof(result.get("target_owner_player")) != TYPE_INT \
			or int(result["target_owner_player"]) not in [0, 1] \
			or typeof(result.get("target_ship_index")) != TYPE_INT \
			or int(result["target_ship_index"]) < 0 \
			or not _nonempty_string_fields(result, [
				"ship_activation_identity", "maneuver_execution_id",
				"exact_once_key"]):
		return false
	for key: String in [
			"moving_damage_application", "target_damage_application"]:
		if not APPLICATION.is_exact_damage_application(result[key]):
			return false
	return true


static func _nonempty_string_fields(value: Dictionary,
		fields: Array[String]) -> bool:
	for field: String in fields:
		if typeof(value.get(field)) != TYPE_STRING \
				or str(value[field]).is_empty():
			return false
	return true


static func _restore(game_state: GameState, moving: ShipInstance,
		target: ShipInstance, deck: Dictionary, moving_damage: Dictionary,
		target_damage: Dictionary, moving_boundary: Dictionary) -> void:
	game_state.damage_deck = DamageDeck.deserialize_for_save7(deck)
	if game_state.damage_deck != null and game_state.rng != null:
		game_state.damage_deck.set_rng(game_state.rng)
	moving.install_damage_state_for_save7(moving_damage)
	target.install_damage_state_for_save7(target_damage)
	moving.restore_ship_activation_boundary(moving_boundary)


static func _has_exact_keys(value: Dictionary,
		expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true

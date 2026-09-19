## Dormant protocol-7 ship/approved-obstacle branches for CAP-DMG-002.
class_name CandidateResolveDamagedControlsCommand
extends GameCommand


const APPLICATION: GDScript = preload(
		"res://src/core/damage/candidate_damage_application.gd")
const SHIP_PAYLOAD_KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id", "public_card_ref", "overlap_kind",
]
const OBSTACLE_PAYLOAD_KEYS: Array[String] = [
	"owner_player", "ship_index", "ship_activation_identity",
	"maneuver_execution_id", "public_card_ref", "overlap_kind",
	"obstacle_id",
]
const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_damaged_controls", p_payload)


func application_contract_id() -> String:
	return "resolve_damaged_controls"


func application_contract_version() -> int:
	return 2


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] \
					and _application_result_is_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if game_state == null or game_state.passive_damage_ledger == null \
			or not _application_result_is_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	for key: String in _payload_keys():
		if application_result[key] != payload.get(key):
			return {}
	var ship: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(payload["public_card_ref"])) if ship != null else null
	var damage: Dictionary = application_result["damage_application"]
	var expected_hull: int = ship.ship_data.hull \
			- ship.get_total_damage() - 1 if ship != null else 0
	if ship == null or ship.is_destroyed() or card == null \
			or card.effect_id != "damaged_controls" \
			or card.last_damaged_controls_execution_id \
					== str(payload["maneuver_execution_id"]) \
			or int(damage["owner_player"]) != int(payload["owner_player"]) \
			or int(damage["ship_index"]) != int(payload["ship_index"]) \
			or int(damage["facedown_delta"]) != 1 \
			or not (damage["shield_changes"] as Array).is_empty() \
			or not (damage["faceup_additions"] as Array).is_empty() \
			or not (damage["faceup_removals"] as Array).is_empty() \
			or not (damage["public_discards"] as Array).is_empty() \
			or int(damage["new_hull"]) != expected_hull \
			or bool(damage["destroyed"]) != (expected_hull <= 0) \
			or not game_state.passive_damage_ledger.can_consume_hidden_draws(1):
		return {}
	game_state.passive_damage_ledger.consume_hidden_draws(1)
	if not ship.increment_passive_facedown_damage(1):
		return {}
	card.last_damaged_controls_execution_id = str(
			payload["maneuver_execution_id"])
	if bool(damage["destroyed"]):
		ship.mark_destroyed()
	return application_result.duplicate(true)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	var overlap_kind: String = str(payload.get("overlap_kind", ""))
	var expected_keys: Array[String] = SHIP_PAYLOAD_KEYS \
			if overlap_kind == "ship" else OBSTACLE_PAYLOAD_KEYS
	if overlap_kind not in ["ship", "obstacle"] \
			or not _has_exact_keys(payload, expected_keys) \
			or typeof(payload.get("owner_player")) != TYPE_INT \
			or typeof(payload.get("ship_index")) != TYPE_INT:
		return "Invalid Damaged Controls overlap branch."
	for key: String in [
		"ship_activation_identity", "maneuver_execution_id",
		"public_card_ref"]:
		if typeof(payload.get(key)) != TYPE_STRING \
				or str(payload[key]).is_empty():
			return "Invalid Damaged Controls identity."
	var owner: int = int(payload["owner_player"])
	if player_index != owner:
		return "Damaged Controls is authority-generated for the moving owner."
	var ship: ShipInstance = game_state.get_ship(
			owner, int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return "Damaged Controls ship is unavailable."
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	var collision: Dictionary = execution.get("ship_collision", {}) \
			as Dictionary
	if str(execution.get("ship_activation_identity", "")) \
			!= str(payload["ship_activation_identity"]) \
			or str(execution.get("maneuver_execution_id", "")) \
			!= str(payload["maneuver_execution_id"]) \
			or not bool(execution.get("final_transform_applied", false)):
		return "Maneuver evidence is not at the effect boundary."
	if overlap_kind == "ship" and (
			str(collision.get("kind", "")) != "closest_ship" \
			or not bool(collision.get("damage_resolved", false))):
		return "Ship-collision evidence is not at the effect boundary."
	if overlap_kind == "obstacle":
		if str(collision.get("kind", "")) == "closest_ship" \
				or str(payload.get("obstacle_id", "")).is_empty():
			return "Obstacle Damaged Controls follows only obstacle overlap."
		var found: bool = false
		for obstacle: Dictionary in OVERLAP.unresolved_overlaps(
				game_state, owner, int(payload["ship_index"]),
				str(payload["maneuver_execution_id"])):
			if str(obstacle["obstacle_id"]) == str(payload["obstacle_id"]):
				found = true
				break
		if not found:
			return "Obstacle overlap identity is stale."
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(payload["public_card_ref"]))
	if card == null or card.effect_id != "damaged_controls" \
			or not card.is_faceup \
			or card.last_damaged_controls_execution_id \
					== str(payload["maneuver_execution_id"]):
		return "Damaged Controls occurrence is stale or inapplicable."
	if game_state.passive_damage_ledger != null:
		if not ship.is_passive_damage_bound() \
				or not game_state.passive_damage_ledger \
						.can_consume_hidden_draws(1):
			return "Passive damage authority cannot supply the required card."
	elif game_state.damage_deck == null \
			or not game_state.validate_damage_state_for_save7() \
			or game_state.damage_deck.get_total_count() < 1:
		return "Damage authority cannot supply the required card."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var owner: int = int(payload["owner_player"])
	var ship_index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var deck_before: Dictionary = game_state.damage_deck.serialize_for_save7()
	var ship_before: Dictionary = ship.serialize_damage_state_for_save7()
	var source: DamageCard = ship.faceup_card_for_public_ref(
			str(payload["public_card_ref"]))
	var card: DamageCard = game_state.damage_deck.draw_card()
	if card == null or card.physical_card_id.is_empty():
		_restore(game_state, ship, deck_before, ship_before)
		return {}
	card.flip_facedown()
	ship.add_facedown_damage(card)
	source.last_damaged_controls_execution_id = str(
			payload["maneuver_execution_id"])
	if ship.is_destroyed():
		ship.mark_destroyed()
	if not ship.is_destroyed() and not game_state.validate_damage_state_for_save7():
		_restore(game_state, ship, deck_before, ship_before)
		return {}
	var result: Dictionary = payload.duplicate(true)
	result["damage_application"] = {
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
	return result


static func _restore(game_state: GameState, ship: ShipInstance,
		deck: Dictionary, damage: Dictionary) -> void:
	game_state.damage_deck = DamageDeck.deserialize_for_save7(deck)
	if game_state.damage_deck != null and game_state.rng != null:
		game_state.damage_deck.set_rng(game_state.rng)
	ship.install_damage_state_for_save7(damage)


static func _application_result_is_valid(result: Dictionary) -> bool:
	var kind: String = str(result.get("overlap_kind", ""))
	if kind not in ["ship", "obstacle"]:
		return false
	var keys: Array[String] = (SHIP_PAYLOAD_KEYS if kind == "ship" \
			else OBSTACLE_PAYLOAD_KEYS).duplicate()
	keys.append("damage_application")
	return _has_exact_keys(result, keys) \
			and typeof(result.get("owner_player")) == TYPE_INT \
			and int(result["owner_player"]) in [0, 1] \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and int(result["ship_index"]) >= 0 \
			and _nonempty_string_fields(result, [
				"ship_activation_identity", "maneuver_execution_id",
				"public_card_ref"]) \
			and (kind == "ship" or not str(result.get(
					"obstacle_id", "")).is_empty()) \
			and APPLICATION.is_exact_damage_application(
					result.get("damage_application"))


func _payload_keys() -> Array[String]:
	return SHIP_PAYLOAD_KEYS if str(payload.get("overlap_kind", "")) == "ship" \
			else OBSTACLE_PAYLOAD_KEYS


static func _nonempty_string_fields(value: Dictionary,
		fields: Array[String]) -> bool:
	for field: String in fields:
		if typeof(value.get(field)) != TYPE_STRING \
				or str(value[field]).is_empty():
			return false
	return true


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true

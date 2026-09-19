## Dormant protocol-7 Thruster Fissure resolution candidate.
## Direct-tested only until the coordinated WP6 cutover.
class_name CandidateResolveThrusterFissureCommand
extends GameCommand


const APPLICATION: GDScript = preload(
		"res://src/core/damage/candidate_damage_application.gd")
const EXACT_KEYS: Array[String] = [
	"owner_player",
	"ship_index",
	"ship_activation_identity",
	"maneuver_execution_id",
	"public_card_ref",
	"hull_zone",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_thruster_fissure", p_payload)


func application_contract_id() -> String:
	return "resolve_thruster_fissure"


func application_contract_version() -> int:
	return 2


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, EXACT_KEYS):
		return "Invalid resolve_thruster_fissure payload shape."
	if typeof(payload["owner_player"]) != TYPE_INT \
			or typeof(payload["ship_index"]) != TYPE_INT:
		return "Invalid Thruster Fissure target types."
	for key: String in [
			"ship_activation_identity", "maneuver_execution_id",
			"public_card_ref", "hull_zone"]:
		if typeof(payload[key]) != TYPE_STRING or str(payload[key]).is_empty():
			return "Invalid Thruster Fissure identity types."
	var owner: int = int(payload["owner_player"])
	if player_index != owner:
		return "Only the affected ship owner resolves Thruster Fissure."
	var ship: ShipInstance = game_state.get_ship(
			owner, int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return "Affected ship is unavailable."
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity", "")) \
			!= str(payload["ship_activation_identity"]) \
			or str(execution.get("maneuver_execution_id", "")) \
			!= str(payload["maneuver_execution_id"]) \
			or bool(execution.get("final_transform_applied", false)) \
			or not bool(execution.get("navigate_speed_changed", false)):
		return "No matching pre-movement speed-change execution."
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(payload["public_card_ref"]))
	if card == null or not card.is_faceup \
			or card.effect_id != "thruster_fissure" \
			or card.last_thruster_fissure_execution_id \
					== str(payload["maneuver_execution_id"]):
		return "Thruster Fissure source is not applicable."
	var zone: String = str(payload["hull_zone"])
	if not ship.current_shields.has(zone):
		return "Invalid hull zone."
	if int(ship.current_shields[zone]) <= 0:
		if game_state.passive_damage_ledger != null:
			if not game_state.passive_damage_ledger \
					.can_consume_hidden_draws(1):
				return "Passive damage ledger lacks the required draw."
		elif game_state.damage_deck == null \
				or game_state.damage_deck.get_total_count() <= 0:
			return "No physical damage card is available."
	if game_state.passive_damage_ledger == null:
		if not game_state.validate_damage_state_for_save7():
			return "Damage authority identity state is invalid."
	elif not ship.is_passive_damage_bound():
		return "Passive damage owner is not bound."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var owner: int = int(payload["owner_player"])
	var ship_index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(payload["public_card_ref"]))
	var zone: String = str(payload["hull_zone"])
	var previous_shields: int = int(ship.current_shields[zone])
	var previous_facedown: int = ship.get_facedown_damage_count()
	if ship.reduce_shields(zone, 1) == 0:
		var drawn: DamageCard = game_state.damage_deck.draw_card()
		if drawn == null or drawn.physical_card_id.is_empty():
			ship.current_shields[zone] = previous_shields
			return {}
		drawn.flip_facedown()
		ship.add_facedown_damage(drawn)
	card.last_thruster_fissure_execution_id = \
			str(payload["maneuver_execution_id"])
	if ship.get_total_damage() >= ship.ship_data.hull:
		ship.mark_destroyed()
	var shield_changes: Array[Dictionary] = []
	if int(ship.current_shields.get(zone, 0)) != previous_shields:
		shield_changes.append({
			"zone": zone,
			"new_shields": int(ship.current_shields[zone]),
		})
	var result: Dictionary = payload.duplicate(true)
	result["damage_application"] = {
		"owner_player": owner,
		"ship_index": ship_index,
		"shield_changes": shield_changes,
		"facedown_delta": ship.get_facedown_damage_count() - previous_facedown,
		"faceup_additions": [],
		"faceup_removals": [],
		"public_discards": [],
		"new_hull": ship.ship_data.hull - ship.get_total_damage(),
		"destroyed": ship.is_destroyed(),
	}
	return result


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	if viewer_player not in [0, 1] \
			or not _application_result_is_valid(authority_result):
		return {}
	return authority_result.duplicate(true)


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _application_result_is_valid(application_result) \
			or game_state == null \
			or game_state.passive_damage_ledger == null \
			or not validate(game_state).is_empty():
		return {}
	for key: String in EXACT_KEYS:
		if application_result[key] != payload.get(key):
			return {}
	var ship: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return {}
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(payload["public_card_ref"]))
	if card == null or card.effect_id != "thruster_fissure" \
			or card.last_thruster_fissure_execution_id \
					== str(payload["maneuver_execution_id"]):
		return {}
	var damage: Dictionary = application_result["damage_application"]
	var prior_shields: int = int(ship.current_shields[
			str(payload["hull_zone"])])
	var expected_delta: int = 0 if prior_shields > 0 else 1
	var changes: Array = damage["shield_changes"] as Array
	var expected_hull: int = ship.ship_data.hull \
			- ship.get_total_damage() - expected_delta
	if int(damage["owner_player"]) != int(payload["owner_player"]) \
			or int(damage["ship_index"]) != int(payload["ship_index"]) \
			or int(damage["facedown_delta"]) != expected_delta \
			or changes.size() != (1 if prior_shields > 0 else 0) \
			or (prior_shields > 0 and changes[0] != {
				"zone": payload["hull_zone"],
				"new_shields": prior_shields - 1,
			}) \
			or not (damage["faceup_additions"] as Array).is_empty() \
			or not (damage["faceup_removals"] as Array).is_empty() \
			or not (damage["public_discards"] as Array).is_empty() \
			or int(damage["new_hull"]) != expected_hull \
			or bool(damage["destroyed"]) != (expected_hull <= 0) \
			or (expected_delta > 0 and (game_state.passive_damage_ledger == null \
				or not game_state.passive_damage_ledger.can_consume_hidden_draws(1))):
		return {}
	for change: Dictionary in damage["shield_changes"]:
		var zone: String = str(change.get("zone", ""))
		if not ship.current_shields.has(zone):
			return {}
		ship.current_shields[zone] = int(change["new_shields"])
	var delta: int = int(damage["facedown_delta"])
	if delta > 0:
		game_state.passive_damage_ledger.consume_hidden_draws(1)
		if not ship.increment_passive_facedown_damage(delta):
			return {}
	card.last_thruster_fissure_execution_id = \
			str(payload["maneuver_execution_id"])
	if bool(damage["destroyed"]):
		ship.mark_destroyed()
	return application_result.duplicate(true)


static func _application_result_is_valid(result: Dictionary) -> bool:
	var keys: Array[String] = EXACT_KEYS.duplicate()
	keys.append("damage_application")
	if not _has_exact_keys(result, keys) \
			or not APPLICATION.is_exact_damage_application(
					result["damage_application"]):
		return false
	return typeof(result.get("owner_player")) == TYPE_INT \
			and int(result["owner_player"]) in [0, 1] \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and int(result["ship_index"]) >= 0 \
			and _nonempty_string_fields(result, [
				"ship_activation_identity", "maneuver_execution_id",
				"public_card_ref", "hull_zone"])


static func _nonempty_string_fields(value: Dictionary,
		fields: Array[String]) -> bool:
	for field: String in fields:
		if typeof(value.get(field)) != TYPE_STRING \
				or str(value[field]).is_empty():
			return false
	return true


static func _has_exact_keys(value: Dictionary,
		expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true

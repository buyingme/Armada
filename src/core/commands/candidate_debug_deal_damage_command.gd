## Dormant protocol-7 authoritative debug damage-assignment candidate.
class_name CandidateDebugDealDamageCommand
extends GameCommand


const AUTHORITY: GDScript = preload(
		"res://src/core/damage/immediate_damage_authority.gd")
const APPLICATION: GDScript = preload(
		"res://src/core/damage/candidate_damage_application.gd")
const PAYLOAD_KEYS: Array[String] = [
	"owner_player", "ship_index", "effect_id",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "debug_deal_damage", p_payload)


func application_contract_id() -> String:
	return "debug_deal_damage"


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
	var owner: int = int(payload["owner_player"])
	var ship_index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var damage: Dictionary = application_result["damage_application"] \
			as Dictionary
	var additions: Array = damage["faceup_additions"] as Array
	if str(application_result["debug_application_id"]) \
			!= "debug:%d" % sequence \
			or int(application_result["owner_player"]) != owner \
			or int(application_result["ship_index"]) != ship_index \
			or int(damage["owner_player"]) != owner \
			or int(damage["ship_index"]) != ship_index \
			or additions.size() != 1 \
			or str((additions[0] as Dictionary)["effect_id"]) \
					!= str(payload["effect_id"]) \
			or str((additions[0] as Dictionary)["public_card_ref"]) \
					!= "faceup:%d:0" % sequence \
			or int(damage["facedown_delta"]) != 0 \
			or not (damage["shield_changes"] as Array).is_empty() \
			or not (damage["faceup_removals"] as Array).is_empty() \
			or not (damage["public_discards"] as Array).is_empty() \
			or int(damage["new_hull"]) \
					!= ship.ship_data.hull - ship.get_total_damage() - 1 \
			or bool(damage["destroyed"]) \
					!= (ship.ship_data.hull - ship.get_total_damage() - 1 <= 0) \
			or not game_state.passive_damage_ledger.can_consume_hidden_draws(1):
		return {}
	if not APPLICATION.install_public_addition(ship,
			additions[0] as Dictionary, {
				"enclosing_kind": "debug",
				"debug_application_id": application_result[
						"debug_application_id"],
			}):
		return {}
	game_state.passive_damage_ledger.consume_hidden_draws(1)
	if bool(damage["destroyed"]):
		ship.mark_destroyed()
	return application_result.duplicate(true)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, PAYLOAD_KEYS) \
			or typeof(payload["owner_player"]) != TYPE_INT \
			or typeof(payload["ship_index"]) != TYPE_INT \
			or typeof(payload["effect_id"]) != TYPE_STRING:
		return "Invalid debug_deal_damage intent."
	var ship: ShipInstance = game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))
	if ship == null or ship.is_destroyed():
		return "Ship not found or destroyed."
	if ship.has_active_immediate_resolution():
		return "Ship already has an immediate obligation."
	if game_state.passive_damage_ledger != null:
		if not game_state.validate_for_passive_network_installation() \
				or not game_state.passive_damage_ledger.can_consume_hidden_draws(1):
			return "Passive debug damage state is invalid."
	else:
		if game_state.damage_deck == null \
				or not game_state.validate_damage_state_for_save7() \
				or not game_state.damage_deck.has_debug_draw_card_effect_id(
						str(payload["effect_id"])):
			return "Requested physical damage card is unavailable."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var owner: int = int(payload["owner_player"])
	var ship_index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var deck_before: Dictionary = game_state.damage_deck.serialize_for_save7()
	var ship_before: Dictionary = ship.serialize_damage_state_for_save7()
	var card: DamageCard = game_state.damage_deck \
			.take_debug_draw_card_by_effect_id(str(payload["effect_id"]))
	if card == null:
		return {}
	card.flip_faceup()
	ship.add_faceup_damage(card)
	var debug_id: String = "debug:%d" % sequence
	var addition: Dictionary = AUTHORITY.bind_assigned_faceup(
			game_state, owner, ship_index, card, sequence, 0,
			{"enclosing_kind": "debug", "debug_application_id": debug_id})
	if addition.is_empty():
		game_state.damage_deck = DamageDeck.deserialize_for_save7(deck_before)
		ship.install_damage_state_for_save7(ship_before)
		return {}
	var destroyed: bool = ship.is_destroyed()
	if destroyed:
		# Assignment established the matching obligation first; accepted
		# destruction now terminates it and any enclosing ship state atomically.
		ship.mark_destroyed()
	return {
		"debug_application_id": debug_id,
		"owner_player": owner,
		"ship_index": ship_index,
		"damage_application": {
			"owner_player": owner,
			"ship_index": ship_index,
			"shield_changes": [],
			"facedown_delta": 0,
			"faceup_additions": [addition],
			"faceup_removals": [],
			"public_discards": [],
			"new_hull": ship.ship_data.hull - ship.get_total_damage(),
			"destroyed": destroyed,
		},
	}


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true


static func _application_result_is_valid(result: Dictionary) -> bool:
	return _has_exact_keys(result, [
		"debug_application_id", "owner_player", "ship_index",
		"damage_application"]) \
			and typeof(result.get("debug_application_id")) == TYPE_STRING \
			and not str(result["debug_application_id"]).is_empty() \
			and typeof(result.get("owner_player")) == TYPE_INT \
			and typeof(result.get("ship_index")) == TYPE_INT \
			and APPLICATION.is_exact_damage_application(
					result.get("damage_application"))

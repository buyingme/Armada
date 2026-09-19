## Dormant ADR-014 physical assignment and obligation boundary.
##
## Candidate commands call this directly in tests before WP6. It is not
## registered, routed, serialized by save 6, or exposed to passive peers.
class_name ImmediateDamageAuthority
extends RefCounted


static func assign_drawn_faceup(game_state: GameState, owner_player: int,
		ship_index: int, assignment_sequence: int, draw_ordinal: int,
		enclosure: Dictionary, actor_player: int) -> Dictionary:
	if game_state == null or game_state.damage_deck == null \
			or assignment_sequence < 0 or draw_ordinal < 0 \
			or not game_state.validate_damage_state_for_save7():
		return {}
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	if ship == null or ship.is_destroyed() \
			or ship.has_active_immediate_resolution():
		return {}
	var deck_before: Dictionary = game_state.damage_deck.serialize_for_save7()
	var ship_before: Dictionary = ship.serialize_damage_state_for_save7()
	if deck_before.is_empty() or ship_before.is_empty():
		return {}
	var card: DamageCard = game_state.damage_deck.draw_card()
	if card == null or card.physical_card_id.is_empty():
		_restore(game_state, ship, deck_before, ship_before)
		return {}
	var public_ref: String = "faceup:%d:%d" % [
		assignment_sequence, draw_ordinal]
	card.flip_faceup()
	card.public_card_ref = public_ref
	ship.add_faceup_damage(card)
	var record: Dictionary = {}
	if card.is_immediate():
		if actor_player != derive_actor_player(ship, card):
			_restore(game_state, ship, deck_before, ship_before)
			return {}
		record = build_immediate_record(
				ship, card, enclosure, actor_player)
		if record.is_empty() or not ship.establish_immediate_resolution(record):
			_restore(game_state, ship, deck_before, ship_before)
			return {}
	if not game_state.validate_damage_state_for_save7():
		_restore(game_state, ship, deck_before, ship_before)
		return {}
	var addition: Dictionary = _public_faceup_addition(card, record)
	if ship.is_destroyed():
		ship.mark_destroyed()
	return addition


## Binds a physical card already transferred by a purpose-specific atomic
## source transaction (Attack, debug, or later Asteroid). The source remains
## responsible for rolling its wider transaction back if this returns empty.
static func bind_assigned_faceup(game_state: GameState, owner_player: int,
		ship_index: int, card: DamageCard, assignment_sequence: int,
		draw_ordinal: int, enclosure: Dictionary) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index) \
			if game_state != null else null
	if ship == null or card == null or ship.has_finalized_destruction() \
			or assignment_sequence < 0 or draw_ordinal < 0 \
			or card.physical_card_id.is_empty() or not card.is_faceup \
			or not card.public_card_ref.is_empty() \
			or ship.faceup_damage.count(card) != 1 \
			or ship.has_active_immediate_resolution():
		return {}
	var public_ref: String = "faceup:%d:%d" % [
		assignment_sequence, draw_ordinal]
	card.public_card_ref = public_ref
	var record: Dictionary = {}
	if card.is_immediate():
		var actor: int = derive_actor_player(ship, card)
		record = build_immediate_record(ship, card, enclosure, actor)
		if record.is_empty() or not ship.establish_immediate_resolution(record):
			card.public_card_ref = ""
			return {}
	if not game_state.validate_damage_state_for_save7():
		ship.clear_immediate_resolution_exceptionally()
		card.public_card_ref = ""
		return {}
	return _public_faceup_addition(card, record)


static func derive_actor_player(ship: ShipInstance,
		card: DamageCard) -> int:
	if ship == null or card == null:
		return -2
	match card.effect_id:
		"structural_damage", "life_support_failure":
			return -1
		"projector_misaligned":
			var maximum: int = 0
			var count: int = 0
			for zone: String in ship.current_shields:
				var value: int = int(ship.current_shields[zone])
				if value > maximum:
					maximum = value
					count = 1
				elif value == maximum and value > 0:
					count += 1
			return ship.owner_player if count > 1 else -1
		"injured_crew":
			var available: int = 0
			for token: Dictionary in ship.defense_tokens:
				if int(token.get("state", -1)) \
						!= int(Constants.DefenseTokenState.DISCARDED):
					available += 1
			return ship.owner_player if available > 1 else -1
		"shield_failure":
			return 1 - ship.owner_player
		"comm_noise":
			var speed_available: bool = ship.current_speed > 0
			var dial_available: bool = ship.command_dial_stack != null \
					and ship.command_dial_stack.get_hidden_count() > 0
			return 1 - ship.owner_player if dial_available else (
					-1 if speed_available else -1)
	return -1


static func build_immediate_record(ship: ShipInstance, card: DamageCard,
		enclosure: Dictionary, actor_player: int) -> Dictionary:
	if ship == null or card == null or not card.is_faceup \
			or card.public_card_ref.is_empty() \
			or card.physical_card_id.is_empty() \
			or actor_player not in [-1, 0, 1]:
		return {}
	var public_ref: String = card.public_card_ref
	var record: Dictionary = {
		"immediate_resolution_id": "immediate:%s" % public_ref,
		"public_card_ref": public_ref,
		"physical_card_id": card.physical_card_id,
		"effect_id": card.effect_id,
		"actor_player": actor_player,
		"exact_once_key": "",
		"enclosing_kind": str(enclosure.get("enclosing_kind", "")),
	}
	match record["enclosing_kind"]:
		"attack":
			if not _has_exact_keys(enclosure,
					["enclosing_kind", "attack_id"]):
				return {}
			var attack_id: String = str(enclosure["attack_id"])
			if attack_id.is_empty():
				return {}
			record["attack_id"] = attack_id
			record["exact_once_key"] = "immediate:attack:%s:%s" % [
				attack_id, card.physical_card_id]
		"maneuver":
			var expected: Array[String] = [
				"enclosing_kind", "ship_activation_identity",
				"maneuver_execution_id", "maneuver_source_kind",
				"maneuver_source_id",
			]
			if not _has_exact_keys(enclosure, expected) \
					or str(enclosure["maneuver_source_kind"]) != "asteroid":
				return {}
			var activation_id: String = str(
					enclosure["ship_activation_identity"])
			var execution_id: String = str(enclosure["maneuver_execution_id"])
			var source_id: String = str(enclosure["maneuver_source_id"])
			if activation_id.is_empty() or execution_id.is_empty() \
					or source_id.is_empty():
				return {}
			record["ship_activation_identity"] = activation_id
			record["maneuver_execution_id"] = execution_id
			record["maneuver_source_kind"] = "asteroid"
			record["maneuver_source_id"] = source_id
			record["exact_once_key"] = \
					"immediate:maneuver:%s:%s:%s" % [
						activation_id, execution_id, card.physical_card_id]
		"debug":
			if not _has_exact_keys(enclosure,
					["enclosing_kind", "debug_application_id"]):
				return {}
			var debug_id: String = str(enclosure["debug_application_id"])
			if debug_id.is_empty():
				return {}
			record["debug_application_id"] = debug_id
			record["exact_once_key"] = "immediate:debug:%s:%s" % [
				debug_id, card.physical_card_id]
		_:
			return {}
	return record


static func empty_damage_application(ship: ShipInstance, owner_player: int,
		ship_index: int) -> Dictionary:
	return {
		"owner_player": owner_player,
		"ship_index": ship_index,
		"shield_changes": [],
		"facedown_delta": 0,
		"faceup_additions": [],
		"faceup_removals": [],
		"public_discards": [],
		"new_hull": ship.ship_data.hull - ship.get_total_damage(),
		"destroyed": ship.is_destroyed(),
	}


static func _public_faceup_addition(card: DamageCard,
		record: Dictionary) -> Dictionary:
	var result: Dictionary = card.public_faceup_damage_card()
	if record.is_empty():
		result["immediate_obligation"] = "none"
		return result
	result["immediate_obligation"] = "open"
	result["immediate_resolution_id"] = record["immediate_resolution_id"]
	result["actor_player"] = record["actor_player"]
	return result


static func _restore(game_state: GameState, ship: ShipInstance,
		deck_before: Dictionary, ship_before: Dictionary) -> void:
	game_state.damage_deck = DamageDeck.deserialize_for_save7(deck_before)
	if game_state.damage_deck != null and game_state.rng != null:
		game_state.damage_deck.set_rng(game_state.rng)
	ship.install_damage_state_for_save7(ship_before)


static func _has_exact_keys(value: Dictionary,
		expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true

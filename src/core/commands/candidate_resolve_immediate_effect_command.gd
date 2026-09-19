## Dormant protocol-7 immediate faceup damage resolution candidate.
## Direct-tested only until WP6 activates the coordinated contract-2 route.
class_name CandidateResolveImmediateEffectCommand
extends GameCommand


const VALID_EFFECTS: Array[String] = [
	"structural_damage",
	"projector_misaligned",
	"life_support_failure",
	"injured_crew",
	"shield_failure",
	"comm_noise",
]
const BASE_KEYS: Array[String] = [
	"owner_player",
	"ship_index",
	"public_card_ref",
	"immediate_resolution_id",
	"enclosing_kind",
]
const APPLICATION: GDScript = preload(
		"res://src/core/damage/candidate_damage_application.gd")


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_immediate_effect", p_payload)


func application_contract_id() -> String:
	return "resolve_immediate_effect"


func application_contract_version() -> int:
	return 2


func validate_exact_semantic_payload() -> String:
	# The protocol-7 shape is a closed, state-derived union: enclosure identity
	# and the one legal choice branch depend on the bound immediate record.
	# validate() below constructs that exact key set and rejects every alias or
	# extra field, so the retired contract-1 static field list must not preempt it.
	return ""


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	if viewer_player not in [0, 1] \
			or not _application_result_shape_is_valid(authority_result):
		return {}
	var projected: Dictionary = authority_result.duplicate(true)
	# In the two-player rules model the damaged owner and canonical opponent
	# are exactly the two authorized viewers of a replacement they own/chose.
	return projected


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if game_state == null or game_state.passive_damage_ledger == null \
			or not _application_result_shape_is_valid(application_result):
		return {}
	for key: String in BASE_KEYS:
		if str(application_result.get(key, "")) != str(payload.get(key, "")):
			return {}
	var ship: ShipInstance = _ship(game_state)
	if ship == null or not ship.is_passive_damage_bound():
		return {}
	var damage: Dictionary = application_result["damage_application"] \
			as Dictionary
	var effect: String = str(application_result["effect_id"])
	var effect_result: Dictionary = application_result["effect_result"] \
			as Dictionary
	if int(damage["owner_player"]) != int(payload["owner_player"]) \
			or int(damage["ship_index"]) != int(payload["ship_index"]) \
			or int(damage["new_hull"]) \
					!= ship.ship_data.hull - ship.get_total_damage() \
						- int(damage["facedown_delta"]) \
						+ (damage["faceup_removals"] as Array).size() \
			or bool(damage["destroyed"]) \
					!= (int(damage["new_hull"]) <= 0):
		return {}
	var source_disposition: String = str(
			application_result["source_disposition"])
	if source_disposition != ("faceup" \
			if effect == "life_support_failure" else "facedown"):
		return {}
	var expected_removals: Array = [payload["public_card_ref"]] \
			if source_disposition == "facedown" else []
	if damage["faceup_removals"] != expected_removals \
			or not (damage["faceup_additions"] as Array).is_empty() \
			or not (damage["public_discards"] as Array).is_empty():
		return {}
	var hidden_draws: int = 0
	if effect == "structural_damage" \
			and bool(effect_result["additional_card_dealt"]):
		hidden_draws = 1
	if not game_state.passive_damage_ledger.can_consume_hidden_draws(
			hidden_draws) \
			or not _passive_effect_matches(
					ship, effect, effect_result, damage, hidden_draws):
		return {}
	if not ship.retire_filtered_immediate_resolution(
			str(payload["immediate_resolution_id"]),
			str(payload["public_card_ref"]), source_disposition):
		return {}
	if str(payload["enclosing_kind"]) == "maneuver" \
			and not ship.complete_asteroid_resolution(
					str(payload["ship_activation_identity"]),
					str(payload["maneuver_execution_id"]),
					str(payload["maneuver_source_id"]),
					str(payload["immediate_resolution_id"])):
		return {}
	if str(payload["enclosing_kind"]) == "maneuver":
		game_state.mark_obstacle_resolved_for_maneuver(
				str(payload["maneuver_source_id"]),
				str(payload["maneuver_execution_id"]))
	_apply_passive_effect(ship, effect, effect_result, damage)
	game_state.passive_damage_ledger.consume_hidden_draws(hidden_draws)
	var delta: int = int(damage["facedown_delta"])
	if delta > 0 and not ship.increment_passive_facedown_damage(delta):
		return {}
	if bool(damage["destroyed"]):
		ship.mark_destroyed()
	elif str(payload["enclosing_kind"]) == "maneuver" \
			and not ObstacleOverlapAuthority.open_next_purpose_resolution(
					game_state, int(payload["owner_player"]),
					int(payload["ship_index"])):
		return {}
	return application_result.duplicate(true)


static func _passive_effect_matches(ship: ShipInstance, effect: String,
		effect_result: Dictionary, damage: Dictionary,
		hidden_draws: int) -> bool:
	var expected_disposition: String = "faceup" \
			if effect == "life_support_failure" else "facedown"
	var expected_delta: int = 0 if expected_disposition == "faceup" \
			else 1 + hidden_draws
	if int(damage["facedown_delta"]) != expected_delta:
		return false
	var expected_changes: Array[Dictionary] = []
	match effect:
		"structural_damage":
			if hidden_draws != (1 if bool(effect_result[
					"additional_card_dealt"]) else 0):
				return false
		"projector_misaligned":
			var options: Dictionary = _projector_options(ship)
			var zones: Array = options["zones"] as Array
			var zone: String = str(effect_result["zone"])
			if (zones.is_empty() and not zone.is_empty()) \
					or (not zones.is_empty() and zone not in zones):
				return false
			var lost: int = int(ship.current_shields.get(zone, 0)) \
					if not zone.is_empty() else 0
			if int(effect_result["shields_lost"]) != lost:
				return false
			if lost > 0:
				expected_changes.append({"zone": zone, "new_shields": 0})
		"life_support_failure":
			var had_tokens: bool = ship.command_tokens != null \
					and ship.command_tokens.get_token_count() > 0
			if bool(effect_result["tokens_cleared"]) != had_tokens:
				return false
		"injured_crew":
			var available: Array[int] = _available_defense_tokens(ship)
			var selected: int = int(effect_result["defense_token_index"])
			if available.is_empty():
				if selected != -1:
					return false
			elif available.size() == 1:
				if selected != available[0]:
					return false
			elif selected not in available:
				return false
		"shield_failure":
			var zones: Array = effect_result["shield_zones"] as Array
			if not _validate_shield_zones(ship, zones).is_empty():
				return false
			for raw_zone: Variant in zones:
				var zone: String = str(raw_zone)
				var prior: int = int(ship.current_shields[zone])
				if prior > 0:
					expected_changes.append({
						"zone": zone, "new_shields": prior - 1})
		"comm_noise":
			var speed_available: bool = ship.current_speed > 0
			var dial_available: bool = ship.command_dial_stack != null \
					and ship.command_dial_stack.get_hidden_count() > 0
			match str(effect_result["comm_noise_action"]):
				"speed":
					if not speed_available \
							or int(effect_result["new_speed"]) \
									!= ship.current_speed - 1:
						return false
				"dial":
					if not dial_available:
						return false
				"none":
					if speed_available or dial_available:
						return false
				_:
					return false
		_:
			return false
	return _same_shield_changes(
			damage["shield_changes"] as Array, expected_changes)


static func _apply_passive_effect(ship: ShipInstance, effect: String,
		effect_result: Dictionary, damage: Dictionary) -> void:
	for raw_change: Variant in damage["shield_changes"]:
		var change: Dictionary = raw_change as Dictionary
		ship.current_shields[str(change["zone"])] = int(change["new_shields"])
	match effect:
		"life_support_failure":
			if ship.command_tokens != null:
				ship.command_tokens.clear()
		"injured_crew":
			var selected: int = int(effect_result["defense_token_index"])
			if selected >= 0:
				ship.discard_defense_token(selected)
		"comm_noise":
			match str(effect_result["comm_noise_action"]):
				"speed":
					ship.current_speed = int(effect_result["new_speed"])
				"dial":
					if effect_result.has("replacement_command"):
						ship.command_dial_stack.replace_top_command(
								int(effect_result["replacement_command"]))


static func _same_shield_changes(actual: Array,
		expected: Array[Dictionary]) -> bool:
	if actual.size() != expected.size():
		return false
	var by_zone: Dictionary = {}
	for raw: Variant in actual:
		if not raw is Dictionary:
			return false
		var change: Dictionary = raw as Dictionary
		by_zone[str(change.get("zone", ""))] = change.get("new_shields")
	for change: Dictionary in expected:
		if by_zone.get(str(change["zone"])) != change["new_shields"]:
			return false
	return true


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	var record: Dictionary = _record(game_state)
	if record.is_empty():
		return "No matching immediate resolution."
	var exact_keys: Array[String] = BASE_KEYS.duplicate()
	match str(record["enclosing_kind"]):
		"attack":
			exact_keys.append("attack_id")
		"maneuver":
			exact_keys.append_array([
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id",
			])
		"debug":
			exact_keys.append("debug_application_id")
		_:
			return "Invalid enclosing kind."
	var ship: ShipInstance = _ship(game_state)
	if str(record["enclosing_kind"]) == "maneuver":
		var asteroid: Dictionary = ship.active_asteroid_resolution_snapshot()
		if asteroid != {
			"maneuver_execution_id": record["maneuver_execution_id"],
			"ship_activation_identity": record["ship_activation_identity"],
			"obstacle_id": record["maneuver_source_id"],
			"immediate_resolution_id": record["immediate_resolution_id"],
			"disposition": "OPEN",
		}:
			return "Maneuver immediate obligation has no matching Asteroid enclosure."
	var effect: String = str(record["effect_id"])
	if effect not in VALID_EFFECTS:
		return "Unsupported immediate effect."
	var actor: int = int(record["actor_player"])
	if player_index != (int(payload["owner_player"]) if actor == -1 else actor):
		return "Wrong immediate-effect actor."
	for key: String in exact_keys:
		if not payload.has(key):
			return "Immediate identity or enclosure mismatch."
		if key in ["owner_player", "ship_index"]:
			continue
		if str(payload[key]) != str(record.get(key, "")):
			return "Immediate identity or enclosure mismatch."
	match effect:
		"structural_damage", "life_support_failure":
			pass
		"projector_misaligned":
			var projector: Dictionary = _projector_options(ship)
			if (projector["zones"] as Array).size() > 1:
				exact_keys.append("projector_zone")
				if typeof(payload.get("projector_zone")) != TYPE_STRING \
						or str(payload["projector_zone"]) \
							not in projector["zones"]:
					return "Invalid Projector Misaligned choice."
		"injured_crew":
			var tokens: Array[int] = _available_defense_tokens(ship)
			if tokens.size() > 1:
				exact_keys.append("defense_token_index")
				if typeof(payload.get("defense_token_index")) != TYPE_INT \
						or int(payload["defense_token_index"]) not in tokens:
					return "Invalid Injured Crew choice."
		"shield_failure":
			exact_keys.append("shield_zones")
			var shield_error: String = _validate_shield_zones(ship,
					payload.get("shield_zones"))
			if not shield_error.is_empty():
				return shield_error
		"comm_noise":
			var comm_error: String = _validate_comm_noise(
					ship, payload, exact_keys)
			if not comm_error.is_empty():
				return comm_error
	if not _has_exact_keys(payload, exact_keys):
		return "Invalid resolve_immediate_effect payload shape."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = _ship(game_state)
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	var card: DamageCard = ship.faceup_card_for_public_ref(
			str(record["public_card_ref"]))
	var effect: String = str(record["effect_id"])
	var state_before: Dictionary = _snapshot(game_state, ship)
	var faceup_ref: String = card.public_card_ref
	var effect_result: Dictionary = {}
	var source_disposition: String = "facedown"
	match effect:
		"structural_damage":
			effect_result = _resolve_structural(game_state, ship)
		"projector_misaligned":
			effect_result = _resolve_projector(ship)
		"life_support_failure":
			effect_result = _resolve_life_support(ship)
			source_disposition = "faceup"
		"injured_crew":
			effect_result = _resolve_injured(ship)
		"shield_failure":
			effect_result = _resolve_shield(ship)
		"comm_noise":
			effect_result = _resolve_comm_noise(ship)
	if effect_result.is_empty() \
			or not ship.retire_immediate_resolution(
					str(record["immediate_resolution_id"]), faceup_ref,
					source_disposition):
		_restore(game_state, ship, state_before)
		return {}
	if str(record["enclosing_kind"]) == "maneuver" \
			and not ship.complete_asteroid_resolution(
					str(record["ship_activation_identity"]),
					str(record["maneuver_execution_id"]),
					str(record["maneuver_source_id"]),
					str(record["immediate_resolution_id"])):
		_restore(game_state, ship, state_before)
		return {}
	if str(record["enclosing_kind"]) == "maneuver":
		game_state.mark_obstacle_resolved_for_maneuver(
				str(record["maneuver_source_id"]),
				str(record["maneuver_execution_id"]))
	if ship.get_total_damage() >= ship.ship_data.hull:
		ship.mark_destroyed()
	elif str(record["enclosing_kind"]) == "maneuver" \
			and not ObstacleOverlapAuthority.open_next_purpose_resolution(
					game_state, int(payload["owner_player"]),
					int(payload["ship_index"])):
		_restore(game_state, ship, state_before)
		return {}
	var damage_application: Dictionary = _damage_application(
			ship, int(payload["owner_player"]), int(payload["ship_index"]),
			state_before, faceup_ref, source_disposition)
	var result: Dictionary = {}
	for key: String in BASE_KEYS:
		result[key] = payload[key]
	match str(record["enclosing_kind"]):
		"attack":
			result["attack_id"] = record["attack_id"]
		"maneuver":
			for key: String in [
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id"]:
				result[key] = record[key]
		"debug":
			result["debug_application_id"] = record["debug_application_id"]
	result["effect_id"] = effect
	result["source_disposition"] = source_disposition
	result["obligation_retired"] = true
	result["damage_application"] = damage_application
	result["effect_result"] = effect_result
	return result


func _resolve_structural(game_state: GameState,
		ship: ShipInstance) -> Dictionary:
	var additional_card_dealt: bool = false
	var extra: DamageCard = game_state.damage_deck.draw_card() \
			if game_state.damage_deck.get_total_count() > 0 else null
	if extra != null:
		if extra.physical_card_id.is_empty():
			return {}
		extra.flip_facedown()
		ship.add_facedown_damage(extra)
		additional_card_dealt = true
	return {"additional_card_dealt": additional_card_dealt}


func _resolve_projector(ship: ShipInstance) -> Dictionary:
	var options: Dictionary = _projector_options(ship)
	var zones: Array = options["zones"] as Array
	var zone: String = ""
	if zones.size() == 1:
		zone = str(zones[0])
	elif zones.size() > 1:
		zone = str(payload["projector_zone"])
	var lost: int = int(ship.current_shields.get(zone, 0))
	if not zone.is_empty():
		ship.reduce_shields(zone, lost)
	return {"zone": zone, "shields_lost": lost}


func _resolve_life_support(ship: ShipInstance) -> Dictionary:
	var cleared: bool = ship.command_tokens != null \
			and ship.command_tokens.get_token_count() > 0
	if ship.command_tokens != null:
		ship.command_tokens.clear()
	return {"tokens_cleared": cleared}


func _resolve_injured(ship: ShipInstance) -> Dictionary:
	var available: Array[int] = _available_defense_tokens(ship)
	var index: int = -1
	if available.size() == 1:
		index = available[0]
	elif available.size() > 1:
		index = int(payload["defense_token_index"])
	if index >= 0:
		ship.discard_defense_token(index)
	return {"defense_token_index": index}


func _resolve_shield(ship: ShipInstance) -> Dictionary:
	var zones: Array = (payload["shield_zones"] as Array).duplicate()
	for raw_zone: Variant in zones:
		var zone: String = str(raw_zone)
		ship.reduce_shields(zone, 1)
	return {"shield_zones": zones}


func _resolve_comm_noise(ship: ShipInstance) -> Dictionary:
	var action: String = str(payload["comm_noise_action"])
	match action:
		"speed":
			ship.set_speed(ship.current_speed - 1)
			return {"comm_noise_action": "speed",
				"new_speed": ship.current_speed}
		"dial":
			var replacement: int = int(payload["replacement_command"])
			if not ship.command_dial_stack.replace_top_command(replacement):
				return {}
			return {"comm_noise_action": "dial", "dial_changed": true,
				"replacement_command": replacement}
		"none":
			return {"comm_noise_action": "none"}
	return {}


func _record(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = _ship(game_state)
	if ship == null or ship.is_destroyed():
		return {}
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	if record.is_empty() or typeof(payload.get("owner_player")) != TYPE_INT \
			or typeof(payload.get("ship_index")) != TYPE_INT \
			or typeof(payload.get("public_card_ref")) != TYPE_STRING \
			or typeof(payload.get("immediate_resolution_id")) != TYPE_STRING \
			or typeof(payload.get("enclosing_kind")) != TYPE_STRING:
		return {}
	return record


func _ship(game_state: GameState) -> ShipInstance:
	if game_state == null \
			or typeof(payload.get("owner_player")) != TYPE_INT \
			or typeof(payload.get("ship_index")) != TYPE_INT:
		return null
	return game_state.get_ship(
			int(payload["owner_player"]), int(payload["ship_index"]))


static func _projector_options(ship: ShipInstance) -> Dictionary:
	var maximum: int = 0
	var zones: Array[String] = []
	for zone: String in ship.current_shields:
		var value: int = int(ship.current_shields[zone])
		if value > maximum:
			maximum = value
			zones = [zone]
		elif value == maximum and value > 0:
			zones.append(zone)
	return {"maximum": maximum, "zones": zones}


static func _available_defense_tokens(ship: ShipInstance) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(ship.defense_tokens.size()):
		if int(ship.defense_tokens[index].get("state", -1)) \
				!= int(Constants.DefenseTokenState.DISCARDED):
			result.append(index)
	return result


static func _validate_shield_zones(ship: ShipInstance,
		raw_zones: Variant) -> String:
	if not raw_zones is Array:
		return "Shield Failure requires shield_zones."
	var zones: Array = raw_zones as Array
	if zones.size() > 2:
		return "Shield Failure accepts at most two zones."
	var seen: Dictionary = {}
	for raw_zone: Variant in zones:
		if typeof(raw_zone) != TYPE_STRING \
				or not ship.current_shields.has(str(raw_zone)) \
				or seen.has(str(raw_zone)):
			return "Shield Failure zones must be distinct current zones."
		seen[str(raw_zone)] = true
	return ""


static func _validate_comm_noise(ship: ShipInstance, data: Dictionary,
		exact_keys: Array[String]) -> String:
	var speed_available: bool = ship.current_speed > 0
	var dial_available: bool = ship.command_dial_stack != null \
			and ship.command_dial_stack.get_hidden_count() > 0
	exact_keys.append("comm_noise_action")
	if typeof(data.get("comm_noise_action")) != TYPE_STRING:
		return "Comm Noise requires an action."
	var action: String = str(data["comm_noise_action"])
	if speed_available and dial_available:
		if action not in ["speed", "dial"]:
			return "Comm Noise action is unavailable."
	elif speed_available:
		if action != "speed":
			return "Sole Comm Noise speed action is mandatory."
	elif dial_available:
		if action != "dial":
			return "Sole Comm Noise dial action is mandatory."
	elif action != "none":
		return "Comm Noise has no available mutation."
	if action == "dial":
		exact_keys.append("replacement_command")
		if typeof(data.get("replacement_command")) != TYPE_INT \
				or int(data["replacement_command"]) not in [0, 1, 2, 3]:
			return "Invalid Comm Noise replacement command."
	return ""


static func _snapshot(game_state: GameState,
		ship: ShipInstance) -> Dictionary:
	return {
		"deck": game_state.damage_deck.serialize_for_save7(),
		"ship_damage": ship.serialize_damage_state_for_save7(),
		"shields": ship.current_shields.duplicate(true),
		"defense_tokens": ship.defense_tokens.duplicate(true),
		"command_tokens": ship.command_tokens.serialize(),
		"command_dials": ship.command_dial_stack.serialize(),
		"current_speed": ship.current_speed,
		"destroyed": ship.is_destroyed(),
	}


static func _restore(game_state: GameState, ship: ShipInstance,
		snapshot: Dictionary) -> void:
	game_state.damage_deck = DamageDeck.deserialize_for_save7(
			snapshot["deck"] as Dictionary)
	if game_state.damage_deck != null and game_state.rng != null:
		game_state.damage_deck.set_rng(game_state.rng)
	ship.install_damage_state_for_save7(
			snapshot["ship_damage"] as Dictionary)
	ship.current_shields = (snapshot["shields"] as Dictionary).duplicate(true)
	ship.defense_tokens = (snapshot["defense_tokens"] as Array).duplicate(true)
	ship.command_tokens = CommandTokenManager.deserialize(
			snapshot["command_tokens"] as Dictionary)
	ship.command_dial_stack = CommandDialStack.deserialize(
			snapshot["command_dials"] as Dictionary)
	ship.current_speed = int(snapshot["current_speed"])


static func _damage_application(ship: ShipInstance, owner_player: int,
		ship_index: int, snapshot: Dictionary, public_ref: String,
		source_disposition: String) -> Dictionary:
	var prior_damage: Dictionary = snapshot["ship_damage"] as Dictionary
	var previous_facedown: int = (prior_damage["facedown_damage"] as Array).size()
	var shield_changes: Array[Dictionary] = []
	var previous_shields: Dictionary = snapshot["shields"] as Dictionary
	for zone: String in ship.current_shields:
		if int(ship.current_shields[zone]) != int(previous_shields.get(zone, -1)):
			shield_changes.append({"zone": zone,
				"new_shields": int(ship.current_shields[zone])})
	return {
		"owner_player": owner_player,
		"ship_index": ship_index,
		"shield_changes": shield_changes,
		"facedown_delta": ship.get_facedown_damage_count() - previous_facedown,
		"faceup_additions": [],
		"faceup_removals": [public_ref] \
				if source_disposition == "facedown" else [],
		"public_discards": [],
		"new_hull": ship.ship_data.hull - ship.get_total_damage(),
		"destroyed": ship.is_destroyed(),
	}


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true


static func _application_result_shape_is_valid(result: Dictionary) -> bool:
	var common: Array[String] = BASE_KEYS.duplicate()
	match str(result.get("enclosing_kind", "")):
		"attack":
			common.append("attack_id")
		"maneuver":
			common.append_array([
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id"])
		"debug":
			common.append("debug_application_id")
		_:
			return false
	common.append_array([
		"effect_id", "source_disposition", "obligation_retired",
		"damage_application", "effect_result"])
	if not _has_exact_keys(result, common) \
			or str(result.get("effect_id", "")) not in VALID_EFFECTS \
			or str(result.get("source_disposition", "")) \
				not in ["faceup", "facedown"] \
			or result.get("obligation_retired") != true \
			or not APPLICATION.is_exact_damage_application(
					result.get("damage_application")) \
			or not result.get("effect_result") is Dictionary:
		return false
	var damage: Dictionary = result["damage_application"] as Dictionary
	if int(damage["facedown_delta"]) < 0:
		return false
	var effect: String = str(result["effect_id"])
	var effect_result: Dictionary = result["effect_result"] as Dictionary
	match effect:
		"structural_damage":
			return _has_exact_keys(effect_result,
					["additional_card_dealt"]) \
					and typeof(effect_result["additional_card_dealt"]) \
							== TYPE_BOOL \
					and str(result["source_disposition"]) == "facedown"
		"projector_misaligned":
			return _has_exact_keys(effect_result, ["zone", "shields_lost"]) \
					and typeof(effect_result["zone"]) == TYPE_STRING \
					and typeof(effect_result["shields_lost"]) == TYPE_INT \
					and str(result["source_disposition"]) == "facedown"
		"life_support_failure":
			return _has_exact_keys(effect_result, ["tokens_cleared"]) \
					and typeof(effect_result["tokens_cleared"]) == TYPE_BOOL \
					and str(result["source_disposition"]) == "faceup"
		"injured_crew":
			return _has_exact_keys(effect_result,
					["defense_token_index"]) \
					and typeof(effect_result["defense_token_index"]) == TYPE_INT \
					and str(result["source_disposition"]) == "facedown"
		"shield_failure":
			return _has_exact_keys(effect_result, ["shield_zones"]) \
					and effect_result["shield_zones"] is Array \
					and str(result["source_disposition"]) == "facedown"
		"comm_noise":
			return _comm_noise_effect_result_is_valid(effect_result) \
					and str(result["source_disposition"]) == "facedown"
	return false


static func _comm_noise_effect_result_is_valid(result: Dictionary) -> bool:
	match str(result.get("comm_noise_action", "")):
		"speed":
			return _has_exact_keys(result,
					["comm_noise_action", "new_speed"]) \
					and typeof(result["new_speed"]) == TYPE_INT
		"dial":
			if result.size() not in [2, 3] \
					or result.get("dial_changed") != true:
				return false
			if result.size() == 2:
				return _has_exact_keys(result,
						["comm_noise_action", "dial_changed"])
			return _has_exact_keys(result, [
				"comm_noise_action", "dial_changed", "replacement_command"]) \
					and typeof(result["replacement_command"]) == TYPE_INT \
					and int(result["replacement_command"]) in [0, 1, 2, 3]
		"none":
			return _has_exact_keys(result, ["comm_noise_action"])
	return false

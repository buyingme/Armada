## ElectronicCountermeasures
##
## Narrow CAP-ECM-001 helper for attack-time ECM behavior. ECM is
## command-owned: this helper only centralizes source lookup, availability,
## and runtime-upgrade rule_state bookkeeping.
class_name ElectronicCountermeasures
extends RefCounted


const DATA_KEY: String = "electronic_countermeasures"
const RULE_ID: String = "upgrade.electronic_countermeasures"
const AFFORDANCE_KEY: String = "ecm_choice"
const READY_COST_AFFORDANCE_KEY: String = "ecm_ready_cost_choices"
const RULE_STATE_PENDING_AUTHORIZATION: String = "pending_ecm_authorization"
const RULE_STATE_DECLINED_ATTACK: String = "declined_ecm_attack"
const RULE_STATE_STATUS_READY_COST: String = "status_ready_cost"
const PENDING_SELECTED_TOKEN_INDEX: String = "selected_token_index"

static var _rule_instance: RefCounted = null


static func register() -> void:
	if _rule_instance == null:
		_rule_instance = load(
				"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd").new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.enabler(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
				RuleSurface.TARGET_DEFENSE_TOKEN_SPEND,
				Callable(_rule_instance, "project_ecm_choice")),
		FlowHook.enabler(RULE_ID,
				Constants.InteractionFlow.STATUS_CLEANUP,
				Constants.InteractionStep.STATUS_CLEANUP_STEP,
				"status_ready_upgrade_card",
				Callable(_rule_instance, "project_status_ready_cost")),
	])


func project_ecm_choice(state: GameState,
		flow: InteractionFlow,
		_viewer_player: int) -> Dictionary:
	var choice: Dictionary = choice_payload(state, flow)
	if choice.is_empty():
		return {}
	return {AFFORDANCE_KEY: choice}


func project_status_ready_cost(state: GameState,
		_flow: InteractionFlow,
		_viewer_player: int) -> Dictionary:
	var choices: Array[Dictionary] = status_ready_cost_choices(state)
	if choices.is_empty():
		return {}
	return {
		READY_COST_AFFORDANCE_KEY: choices,
		"optional_status_rules": choices,
	}


static func choice_payload(game_state: GameState,
		flow: InteractionFlow) -> Dictionary:
	var source: Dictionary = find_available_source(game_state, flow)
	if source.is_empty():
		return {}
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	return {
		"runtime_upgrade_id": str(runtime_upgrade.get("runtime_upgrade_id", "")),
		"source_data_key": DATA_KEY,
		"defender_player": int(source.get("owner_player", -1)),
		"defender_ship_index": int(source.get("ship_index", -1)),
		"source_ship_ref": str(runtime_upgrade.get("source_ship_ref", "")),
		"eligible_token_indices": eligible_token_indices(
				game_state, flow, source),
		"prompt": "Use Electronic Countermeasures?",
		"accepted_command": "use_ecm",
		"decline_command": "decline_ecm",
	}


static func find_available_source(game_state: GameState,
		flow: InteractionFlow) -> Dictionary:
	var source: Dictionary = find_defender_source(game_state, flow)
	if source.is_empty():
		return {}
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	if not _runtime_upgrade_ready(runtime_upgrade):
		return {}
	if has_pending_authorization(runtime_upgrade):
		return {}
	if has_declined_current_attack(runtime_upgrade, flow):
		return {}
	if eligible_token_indices(game_state, flow, source).is_empty():
		return {}
	return source


static func find_defender_source(game_state: GameState,
		flow: InteractionFlow) -> Dictionary:
	if game_state == null or not _is_defense_step(flow):
		return {}
	var defender_player: int = int(flow.payload.get("defender_player", -1))
	var defender_ship_index: int = int(
			flow.payload.get("defender_ship_index", -1))
	if defender_player < 0 or defender_player >= game_state.player_states.size() \
			or defender_ship_index < 0:
		return {}
	var ship: ShipInstance = game_state.get_ship(
			defender_player, defender_ship_index)
	if ship == null or ship.is_destroyed():
		return {}
	for runtime_upgrade: Dictionary in ship.runtime_upgrades:
		if _runtime_upgrade_active(runtime_upgrade):
			return {
				"ship": ship,
				"ship_index": defender_ship_index,
				"owner_player": defender_player,
				"runtime_upgrade": runtime_upgrade,
			}
	return {}


static func find_active_source_by_id(game_state: GameState,
		runtime_upgrade_id: String) -> Dictionary:
	if game_state == null or runtime_upgrade_id.is_empty():
		return {}
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_index: int in range(player_state.ships.size()):
			var ship: ShipInstance = player_state.ships[ship_index] \
					as ShipInstance
			if ship == null or ship.is_destroyed():
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("runtime_upgrade_id", "")) \
						!= runtime_upgrade_id:
					continue
				if _runtime_upgrade_active(runtime_upgrade):
					return {
						"ship": ship,
						"ship_index": ship_index,
						"owner_player": player_index,
						"runtime_upgrade": runtime_upgrade,
					}
	return {}


static func eligible_token_indices(game_state: GameState,
		flow: InteractionFlow,
		source: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if game_state == null or not _is_defense_step(flow):
		return result
	var ship: ShipInstance = source.get("ship", null)
	if ship == null or ship.current_speed == 0:
		return result
	var locked: Array[int] = _int_array(flow.payload.get("locked_tokens", []))
	var spent_types: Array[int] = _int_array(
			flow.payload.get("spent_defense_token_types", []))
	var defender_zone: int = int(flow.payload.get("defender_zone", -1))
	for token_index: int in locked:
		if _token_otherwise_spendable(
				ship, token_index, spent_types, defender_zone):
			result.append(token_index)
	return result


static func validate_use(game_state: GameState,
		player_index: int,
		runtime_upgrade_id: String) -> String:
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Electronic Countermeasures can only be used during an attack."
	var flow: InteractionFlow = game_state.interaction_flow
	if not _is_defense_step(flow):
		return "Electronic Countermeasures is not available now."
	var source: Dictionary = find_available_source(game_state, flow)
	if source.is_empty():
		return "Electronic Countermeasures has no legal effect."
	return _validate_source_player_and_id(
			source, player_index, runtime_upgrade_id)


static func validate_decline(game_state: GameState,
		player_index: int,
		runtime_upgrade_id: String) -> String:
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Electronic Countermeasures can only be declined during an attack."
	var flow: InteractionFlow = game_state.interaction_flow
	if not _is_defense_step(flow):
		return "Electronic Countermeasures is not available now."
	var source: Dictionary = find_available_source(game_state, flow)
	if source.is_empty():
		return "Electronic Countermeasures has no legal effect."
	return _validate_source_player_and_id(
			source, player_index, runtime_upgrade_id)


static func use_ecm(game_state: GameState,
		runtime_upgrade: Dictionary) -> Dictionary:
	var flow: InteractionFlow = game_state.interaction_flow
	var source: Dictionary = find_defender_source(game_state, flow)
	var eligible: Array[int] = eligible_token_indices(game_state, flow, source)
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	card_state["exhausted"] = true
	card_state["readied"] = false
	runtime_upgrade["card_state"] = card_state
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	rule_state.erase(RULE_STATE_DECLINED_ATTACK)
	rule_state[RULE_STATE_PENDING_AUTHORIZATION] = _authorization_payload(
			game_state, flow, runtime_upgrade, eligible)
	runtime_upgrade["rule_state"] = rule_state
	flow.payload.erase(AFFORDANCE_KEY)
	flow.payload["ecm_authorized_indices"] = authorized_token_indices(
			game_state, flow)
	return rule_state[RULE_STATE_PENDING_AUTHORIZATION].duplicate(true)


static func decline_ecm(game_state: GameState,
		runtime_upgrade: Dictionary) -> Dictionary:
	var flow: InteractionFlow = game_state.interaction_flow
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	rule_state.erase(RULE_STATE_PENDING_AUTHORIZATION)
	rule_state[RULE_STATE_DECLINED_ATTACK] = _attack_scope_from_flow(
			game_state, flow)
	runtime_upgrade["rule_state"] = rule_state
	flow.payload.erase("ecm_pending_authorization")
	flow.payload.erase("ecm_authorized_indices")
	flow.payload.erase(AFFORDANCE_KEY)
	return rule_state[RULE_STATE_DECLINED_ATTACK].duplicate(true)


static func validate_authorized_token_selection(game_state: GameState,
		ship: ShipInstance,
		ship_index: int,
		selected_indices: Array) -> String:
	if game_state == null or game_state.interaction_flow == null:
		return ""
	var locked_count: int = 0
	var locked: Array[int] = _int_array(
			game_state.interaction_flow.payload.get("locked_tokens", []))
	var source: Dictionary = find_defender_source(
			game_state, game_state.interaction_flow)
	var pending: Dictionary = {}
	if not source.is_empty():
		pending = pending_authorization(source.get("runtime_upgrade", {}))
	for raw_idx: Variant in selected_indices:
		var idx: int = int(raw_idx)
		if locked.has(idx):
			locked_count += 1
			if locked_count > 1:
				return "Electronic Countermeasures can authorize only one " \
						+ "Accuracy-targeted token."
		var ecm_error: String = validate_authorized_token_spend(
				game_state, ship, ship_index, idx)
		if ecm_error != "":
			return ecm_error
	if not pending.is_empty() \
			and _authorization_matches_current_attack(
					pending, game_state, game_state.interaction_flow) \
			and locked_count == 0:
		return "Electronic Countermeasures requires one Accuracy-targeted " \
				+ "token selection."
	return ""


static func validate_authorized_token_spend(game_state: GameState,
		ship: ShipInstance,
		ship_index: int,
		token_index: int) -> String:
	var flow: InteractionFlow = game_state.interaction_flow
	if not _is_defense_step(flow):
		return ""
	var locked: Array[int] = _int_array(flow.payload.get("locked_tokens", []))
	if not locked.has(token_index):
		return ""
	var source: Dictionary = find_defender_source(game_state, flow)
	if source.is_empty():
		return "Accuracy-targeted token requires Electronic Countermeasures."
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var pending: Dictionary = pending_authorization(runtime_upgrade)
	if pending.is_empty():
		return "Accuracy-targeted token requires Electronic Countermeasures."
	if ship == null or ship != source.get("ship", null) \
			or int(source.get("ship_index", -1)) != ship_index:
		return "Electronic Countermeasures authorization is for another ship."
	if not _authorization_matches_current_attack(pending, game_state, flow):
		return "Electronic Countermeasures authorization is stale."
	var eligible: Array[int] = _int_array(
			pending.get("eligible_token_indices", []))
	if not eligible.has(token_index):
		return "Token is not covered by Electronic Countermeasures."
	var selected_token_index: int = int(pending.get(
			PENDING_SELECTED_TOKEN_INDEX, -1))
	if selected_token_index >= 0 and selected_token_index != token_index:
		return "Token was not selected for Electronic Countermeasures."
	if not _token_otherwise_spendable(ship, token_index,
			_int_array(flow.payload.get("spent_defense_token_types", [])),
			int(flow.payload.get("defender_zone", -1))):
		return "Token cannot be spent with Electronic Countermeasures."
	return ""


static func commit_authorized_token_selection(game_state: GameState,
		ship_index: int,
		selected_indices: Array) -> Dictionary:
	if game_state == null or game_state.interaction_flow == null:
		return {}
	var source: Dictionary = find_defender_source(
			game_state, game_state.interaction_flow)
	if source.is_empty() or int(source.get("ship_index", -1)) != ship_index:
		return {}
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var pending: Dictionary = pending_authorization(runtime_upgrade)
	if pending.is_empty() or not _authorization_matches_current_attack(
			pending, game_state, game_state.interaction_flow):
		return {}
	var chosen: int = _selected_locked_token_index(
			game_state.interaction_flow, selected_indices)
	if chosen < 0:
		return {}
	pending[PENDING_SELECTED_TOKEN_INDEX] = chosen
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get(
			"rule_state", {}))
	rule_state[RULE_STATE_PENDING_AUTHORIZATION] = pending
	runtime_upgrade["rule_state"] = rule_state
	game_state.interaction_flow.payload["ecm_authorized_indices"] = [chosen]
	return pending.duplicate(true)


static func consume_authorization_for_spend(game_state: GameState,
		ship: ShipInstance,
		token_index: int) -> String:
	var flow: InteractionFlow = game_state.interaction_flow
	if not _is_defense_step(flow) or ship == null:
		return ""
	var locked: Array[int] = _int_array(flow.payload.get("locked_tokens", []))
	if not locked.has(token_index):
		return ""
	var source: Dictionary = find_defender_source(game_state, flow)
	if source.is_empty():
		return ""
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	clear_pending_authorization(runtime_upgrade)
	flow.payload.erase("ecm_pending_authorization")
	flow.payload.erase("ecm_authorized_indices")
	flow.payload.erase(AFFORDANCE_KEY)
	return str(runtime_upgrade.get("runtime_upgrade_id", ""))


static func is_token_otherwise_spendable(ship: ShipInstance,
		token_index: int,
		spent_types: Array[int],
		defender_zone: int) -> bool:
	return _token_otherwise_spendable(
			ship, token_index, spent_types, defender_zone)


static func clear_window_state(game_state: GameState) -> Array[String]:
	var cleared: Array[String] = []
	if game_state == null:
		return cleared
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_var: Variant in player_state.ships:
			var ship: ShipInstance = ship_var as ShipInstance
			if ship == null:
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
					continue
				var rule_state: Dictionary = _dict_from(
						runtime_upgrade.get("rule_state", {}))
				if rule_state.has(RULE_STATE_PENDING_AUTHORIZATION) \
						or rule_state.has(RULE_STATE_DECLINED_ATTACK):
					rule_state.erase(RULE_STATE_PENDING_AUTHORIZATION)
					rule_state.erase(RULE_STATE_DECLINED_ATTACK)
					runtime_upgrade["rule_state"] = rule_state
					cleared.append(str(runtime_upgrade.get(
							"runtime_upgrade_id", "")))
	return cleared


static func has_pending_authorization(runtime_upgrade: Dictionary) -> bool:
	return not pending_authorization(runtime_upgrade).is_empty()


static func pending_authorization(runtime_upgrade: Dictionary) -> Dictionary:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	return _dict_from(rule_state.get(RULE_STATE_PENDING_AUTHORIZATION, {}))


static func authorized_token_indices(game_state: GameState,
		flow: InteractionFlow) -> Array[int]:
	var result: Array[int] = []
	var source: Dictionary = find_defender_source(game_state, flow)
	if source.is_empty():
		return result
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var pending: Dictionary = pending_authorization(runtime_upgrade)
	if pending.is_empty():
		return result
	if not _authorization_matches_current_attack(pending, game_state, flow):
		return result
	var eligible: Array[int] = _int_array(
			pending.get("eligible_token_indices", []))
	var selected_token_index: int = int(pending.get(
			PENDING_SELECTED_TOKEN_INDEX, -1))
	var ship: ShipInstance = source.get("ship", null)
	for token_index: int in eligible:
		if selected_token_index >= 0 and token_index != selected_token_index:
			continue
		if _token_otherwise_spendable(ship, token_index,
				_int_array(flow.payload.get("spent_defense_token_types", [])),
				int(flow.payload.get("defender_zone", -1))):
			result.append(token_index)
	return result


static func decorate_projection_payload(game_state: GameState,
		payload: Dictionary) -> Dictionary:
	var clean: Dictionary = payload.duplicate(true)
	clean.erase("ecm_pending_authorization")
	var flow: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			int(clean.get("defender_player", -1)),
			Constants.Visibility.ALL,
			clean)
	var choice: Dictionary = choice_payload(game_state, flow)
	if choice.is_empty():
		clean[AFFORDANCE_KEY] = {}
	else:
		clean[AFFORDANCE_KEY] = choice
	var authorized: Array[int] = authorized_token_indices(game_state, flow)
	if authorized.is_empty():
		clean["ecm_authorized_indices"] = []
	else:
		clean["ecm_authorized_indices"] = authorized
	return clean


static func decorate_status_ready_cost_payload(game_state: GameState,
		payload: Dictionary = {}) -> Dictionary:
	var clean: Dictionary = payload.duplicate(true)
	var choices: Array[Dictionary] = status_ready_cost_choices(game_state)
	clean[READY_COST_AFFORDANCE_KEY] = choices
	clean["optional_status_rules"] = choices
	return clean


static func status_ready_cost_choices(game_state: GameState) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not _is_status_ready_cost_window(game_state):
		return choices
	for source: Dictionary in _status_ready_cost_sources(game_state):
		choices.append(_status_ready_cost_choice_payload(source))
	return choices


static func has_unresolved_status_ready_cost_choices(
		game_state: GameState) -> bool:
	return not status_ready_cost_choices(game_state).is_empty()


static func validate_status_ready_cost(game_state: GameState,
		player_index: int,
		runtime_upgrade_id: String) -> String:
	var source_result: Dictionary = _validate_status_ready_cost_source(
			game_state, player_index, runtime_upgrade_id)
	if not source_result.get("reason", "").is_empty():
		return str(source_result.get("reason", ""))
	var source: Dictionary = source_result.get("source", {})
	var ship: ShipInstance = source.get("ship", null)
	if ship == null or ship.command_tokens == null \
			or not ship.command_tokens.has_token(Constants.CommandType.REPAIR):
		return "Electronic Countermeasures ready cost requires a Repair token."
	return ""


static func validate_decline_status_ready_cost(game_state: GameState,
		player_index: int,
		runtime_upgrade_id: String) -> String:
	var source_result: Dictionary = _validate_status_ready_cost_source(
			game_state, player_index, runtime_upgrade_id)
	if not source_result.get("reason", "").is_empty():
		return str(source_result.get("reason", ""))
	var source: Dictionary = source_result.get("source", {})
	var ship: ShipInstance = source.get("ship", null)
	if ship == null or ship.command_tokens == null \
			or not ship.command_tokens.has_token(Constants.CommandType.REPAIR):
		return "Electronic Countermeasures ready cost is not available."
	return ""


static func ready_status_cost(game_state: GameState,
		runtime_upgrade_id: String) -> Dictionary:
	var source: Dictionary = _status_ready_cost_source_by_id(
			game_state, runtime_upgrade_id)
	var ship: ShipInstance = source.get("ship", null)
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var spent: bool = ship.command_tokens.spend_token(Constants.CommandType.REPAIR)
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	card_state["exhausted"] = false
	card_state["readied"] = true
	runtime_upgrade["card_state"] = card_state
	var guard: Dictionary = _status_ready_cost_guard(
			game_state, source, "ready")
	guard["spent_token"] = int(Constants.CommandType.REPAIR)
	_write_status_ready_cost_guard(runtime_upgrade, guard)
	_refresh_status_ready_cost_projection(game_state)
	return {
		"runtime_upgrade_id": runtime_upgrade_id,
		"owner_player": int(source.get("owner_player", -1)),
		"ship_index": int(source.get("ship_index", -1)),
		"spent_token": int(Constants.CommandType.REPAIR),
		"token_spent": spent,
		"readied": true,
		"status_ready_cost": guard,
	}


static func decline_status_ready_cost(game_state: GameState,
		runtime_upgrade_id: String) -> Dictionary:
	var source: Dictionary = _status_ready_cost_source_by_id(
			game_state, runtime_upgrade_id)
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var guard: Dictionary = _status_ready_cost_guard(
			game_state, source, "declined")
	_write_status_ready_cost_guard(runtime_upgrade, guard)
	_refresh_status_ready_cost_projection(game_state)
	return {
		"runtime_upgrade_id": runtime_upgrade_id,
		"owner_player": int(source.get("owner_player", -1)),
		"ship_index": int(source.get("ship_index", -1)),
		"declined": true,
		"status_ready_cost": guard,
	}


static func status_ready_cost_guard(runtime_upgrade: Dictionary) -> Dictionary:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	return _dict_from(rule_state.get(RULE_STATE_STATUS_READY_COST, {}))


static func clear_status_ready_cost_window_state(
		game_state: GameState) -> Array[String]:
	var cleared: Array[String] = []
	if game_state == null:
		return cleared
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_var: Variant in player_state.ships:
			var ship: ShipInstance = ship_var as ShipInstance
			if ship == null:
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
					continue
				var rule_state: Dictionary = _dict_from(
						runtime_upgrade.get("rule_state", {}))
				if rule_state.has(RULE_STATE_STATUS_READY_COST):
					rule_state.erase(RULE_STATE_STATUS_READY_COST)
					runtime_upgrade["rule_state"] = rule_state
					cleared.append(str(runtime_upgrade.get(
							"runtime_upgrade_id", "")))
	if game_state.interaction_flow != null:
		game_state.interaction_flow.payload.erase(READY_COST_AFFORDANCE_KEY)
		game_state.interaction_flow.payload.erase("optional_status_rules")
	return cleared


static func clear_stale_status_ready_cost_window_state(
		game_state: GameState) -> Array[String]:
	var cleared: Array[String] = []
	if game_state == null:
		return cleared
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_var: Variant in player_state.ships:
			var ship: ShipInstance = ship_var as ShipInstance
			if ship == null:
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
					continue
				var guard: Dictionary = status_ready_cost_guard(runtime_upgrade)
				if guard.is_empty():
					continue
				if int(guard.get("round", -1)) == game_state.current_round:
					continue
				var rule_state: Dictionary = _dict_from(
						runtime_upgrade.get("rule_state", {}))
				rule_state.erase(RULE_STATE_STATUS_READY_COST)
				runtime_upgrade["rule_state"] = rule_state
				cleared.append(str(runtime_upgrade.get(
						"runtime_upgrade_id", "")))
	return cleared


static func clear_pending_authorization(runtime_upgrade: Dictionary) -> void:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	rule_state.erase(RULE_STATE_PENDING_AUTHORIZATION)
	runtime_upgrade["rule_state"] = rule_state


static func has_declined_current_attack(runtime_upgrade: Dictionary,
		flow: InteractionFlow) -> bool:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	var declined: Dictionary = _dict_from(
			rule_state.get(RULE_STATE_DECLINED_ATTACK, {}))
	if declined.is_empty():
		return false
	return _scope_matches_flow(declined, flow)


static func _validate_source_player_and_id(source: Dictionary,
		player_index: int,
		runtime_upgrade_id: String) -> String:
	if int(source.get("owner_player", -1)) != player_index:
		return "Only the defender may choose Electronic Countermeasures."
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	if str(runtime_upgrade.get("runtime_upgrade_id", "")) != runtime_upgrade_id:
		return "Electronic Countermeasures source mismatch."
	return ""


static func _authorization_payload(game_state: GameState,
		flow: InteractionFlow,
		runtime_upgrade: Dictionary,
		eligible: Array[int]) -> Dictionary:
	return {
		"runtime_upgrade_id": str(runtime_upgrade.get("runtime_upgrade_id", "")),
		"round": game_state.current_round,
		"defender_player": int(flow.payload.get("defender_player", -1)),
			"defender_ship_index": int(flow.payload.get("defender_ship_index", -1)),
			"defender_zone": int(flow.payload.get("defender_zone", -1)),
			"eligible_token_indices": eligible.duplicate(),
			PENDING_SELECTED_TOKEN_INDEX: -1,
			"attack_scope": _attack_scope_from_flow(game_state, flow),
	}


static func _authorization_matches_current_attack(
		pending: Dictionary,
		game_state: GameState,
		flow: InteractionFlow) -> bool:
	if int(pending.get("round", -1)) != game_state.current_round:
		return false
	var scope: Dictionary = _dict_from(pending.get("attack_scope", {}))
	return _scope_matches_flow(scope, flow)


static func _attack_scope_from_flow(game_state: GameState,
		flow: InteractionFlow) -> Dictionary:
	var payload: Dictionary = flow.payload if flow != null else {}
	return {
		"round": game_state.current_round if game_state != null else -1,
		"attacker_player": int(payload.get("attacker_player", -1)),
		"attacker_ship_index": int(payload.get("attacker_ship_index", -1)),
		"attacker_squadron_index": int(payload.get(
				"attacker_squadron_index", -1)),
		"defender_player": int(payload.get("defender_player", -1)),
		"defender_ship_index": int(payload.get("defender_ship_index", -1)),
		"defender_zone": int(payload.get("defender_zone", -1)),
	}


static func _scope_matches_flow(scope: Dictionary,
		flow: InteractionFlow) -> bool:
	if flow == null:
		return false
	var current: Dictionary = _attack_scope_from_flow(null, flow)
	for key: String in ["attacker_player", "attacker_ship_index",
			"attacker_squadron_index", "defender_player",
			"defender_ship_index", "defender_zone"]:
		if int(scope.get(key, -1)) != int(current.get(key, -1)):
			return false
	return true


static func _token_otherwise_spendable(ship: ShipInstance,
		token_index: int,
		spent_types: Array[int],
		defender_zone: int) -> bool:
	if ship == null or ship.current_speed == 0:
		return false
	if token_index < 0 or token_index >= ship.defense_tokens.size():
		return false
	var token: Dictionary = ship.defense_tokens[token_index]
	var state: Constants.DefenseTokenState = (
			token.get("state", Constants.DefenseTokenState.READY)
			as Constants.DefenseTokenState)
	if state == Constants.DefenseTokenState.DISCARDED:
		return false
	var token_type: int = int(token.get("type", -1))
	if spent_types.has(token_type):
		return false
	var resolver: DefenseTokenResolver = DefenseTokenResolver.new()
	return not resolver.is_token_blocked_by_effect(
			ship, token, defender_zone)


static func _runtime_upgrade_ready(runtime_upgrade: Dictionary) -> bool:
	if not _runtime_upgrade_active(runtime_upgrade):
		return false
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	return bool(card_state.get("readied", false)) \
			and not bool(card_state.get("exhausted", false))


static func _status_ready_cost_sources(game_state: GameState) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if game_state == null:
		return sources
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_index: int in range(player_state.ships.size()):
			var ship: ShipInstance = player_state.ships[ship_index] \
					as ShipInstance
			if ship == null or ship.is_destroyed():
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if _is_status_ready_cost_available(
						game_state, ship, runtime_upgrade):
					sources.append({
						"ship": ship,
						"ship_index": ship_index,
						"owner_player": player_index,
						"runtime_upgrade": runtime_upgrade,
					})
	return sources


static func _status_ready_cost_source_by_id(game_state: GameState,
		runtime_upgrade_id: String) -> Dictionary:
	for source: Dictionary in _status_ready_cost_sources(game_state):
		var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
		if str(runtime_upgrade.get("runtime_upgrade_id", "")) \
				== runtime_upgrade_id:
			return source
	return {}


static func _find_status_ready_cost_source_by_id(game_state: GameState,
		runtime_upgrade_id: String) -> Dictionary:
	if game_state == null or runtime_upgrade_id.is_empty():
		return {}
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_index: int in range(player_state.ships.size()):
			var ship: ShipInstance = player_state.ships[ship_index] \
					as ShipInstance
			if ship == null or ship.is_destroyed():
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("runtime_upgrade_id", "")) \
						== runtime_upgrade_id:
					return {
						"ship": ship,
						"ship_index": ship_index,
						"owner_player": player_index,
						"runtime_upgrade": runtime_upgrade,
					}
	return {}


static func _validate_status_ready_cost_source(game_state: GameState,
		player_index: int,
		runtime_upgrade_id: String) -> Dictionary:
	if game_state == null:
		return {"reason": "No active game state."}
	if not _is_status_ready_cost_window(game_state):
		return {"reason": "Electronic Countermeasures ready cost is not available now."}
	if runtime_upgrade_id.is_empty():
		return {"reason": "Missing Electronic Countermeasures source."}
	var source: Dictionary = _find_status_ready_cost_source_by_id(
			game_state, runtime_upgrade_id)
	if source.is_empty():
		return {"reason": "Electronic Countermeasures source not found."}
	if int(source.get("owner_player", -1)) != player_index:
		return {"reason": "Only the ECM owner may resolve the ready cost."}
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
		return {"reason": "Electronic Countermeasures source mismatch."}
	if not _runtime_upgrade_active(runtime_upgrade):
		return {"reason": "Electronic Countermeasures is not active."}
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	if bool(card_state.get("readied", false)) \
			or not bool(card_state.get("exhausted", false)):
		return {"reason": "Electronic Countermeasures is already ready."}
	if _has_status_ready_cost_guard_for_current_window(
			game_state, runtime_upgrade):
		return {"reason": "Electronic Countermeasures ready cost already resolved."}
	return {"source": source, "reason": ""}


static func _is_status_ready_cost_available(game_state: GameState,
		ship: ShipInstance,
		runtime_upgrade: Dictionary) -> bool:
	if not _runtime_upgrade_active(runtime_upgrade):
		return false
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	if bool(card_state.get("readied", false)) \
			or not bool(card_state.get("exhausted", false)):
		return false
	if _has_status_ready_cost_guard_for_current_window(
			game_state, runtime_upgrade):
		return false
	return ship.command_tokens != null \
			and ship.command_tokens.has_token(Constants.CommandType.REPAIR)


static func _has_status_ready_cost_guard_for_current_window(
		game_state: GameState,
		runtime_upgrade: Dictionary) -> bool:
	var guard: Dictionary = status_ready_cost_guard(runtime_upgrade)
	if guard.is_empty():
		return false
	return int(guard.get("round", -1)) == game_state.current_round


static func _status_ready_cost_choice_payload(source: Dictionary) -> Dictionary:
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	return {
		"rule_id": "%s.status_ready_cost" % RULE_ID,
		"runtime_upgrade_id": str(runtime_upgrade.get("runtime_upgrade_id", "")),
		"source_data_key": DATA_KEY,
		"owner_player": int(source.get("owner_player", -1)),
		"ship_index": int(source.get("ship_index", -1)),
		"source_ship_ref": str(runtime_upgrade.get("source_ship_ref", "")),
		"prompt": "Spend 1 Repair token to ready Electronic Countermeasures?",
		"accepted_command": "ready_ecm",
		"decline_command": "decline_ecm_ready",
	}


static func _status_ready_cost_guard(game_state: GameState,
		source: Dictionary,
		status: String) -> Dictionary:
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	return {
		"runtime_upgrade_id": str(runtime_upgrade.get("runtime_upgrade_id", "")),
		"round": game_state.current_round,
		"owner_player": int(source.get("owner_player", -1)),
		"ship_index": int(source.get("ship_index", -1)),
		"source_ship_ref": str(runtime_upgrade.get("source_ship_ref", "")),
		"status": status,
	}


static func _write_status_ready_cost_guard(runtime_upgrade: Dictionary,
		guard: Dictionary) -> void:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	rule_state[RULE_STATE_STATUS_READY_COST] = guard.duplicate(true)
	runtime_upgrade["rule_state"] = rule_state


static func _refresh_status_ready_cost_projection(game_state: GameState) -> void:
	if game_state == null or game_state.interaction_flow == null:
		return
	if game_state.interaction_flow.flow_type \
			!= Constants.InteractionFlow.STATUS_CLEANUP:
		return
	if game_state.interaction_flow.step_id \
			!= Constants.InteractionStep.STATUS_CLEANUP_STEP:
		return
	game_state.interaction_flow.payload = decorate_status_ready_cost_payload(
			game_state, game_state.interaction_flow.payload)


static func _is_status_ready_cost_window(game_state: GameState) -> bool:
	if game_state == null or game_state.current_phase != Constants.GamePhase.STATUS:
		return false
	var flow: InteractionFlow = game_state.interaction_flow
	return flow != null \
			and flow.flow_type == Constants.InteractionFlow.STATUS_CLEANUP \
			and flow.step_id == Constants.InteractionStep.STATUS_CLEANUP_STEP


static func _runtime_upgrade_active(runtime_upgrade: Dictionary) -> bool:
	if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
		return false
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	return not bool(card_state.get("discarded", false)) \
			and not bool(card_state.get("disabled", false))


static func _is_defense_step(flow: InteractionFlow) -> bool:
	return flow != null \
			and flow.flow_type == Constants.InteractionFlow.ATTACK \
			and flow.step_id == Constants.InteractionStep.ATTACK_DEFENSE_TOKENS


static func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is Array:
		return result
	for entry: Variant in value as Array:
		result.append(int(entry))
	return result


static func _selected_locked_token_index(flow: InteractionFlow,
		selected_indices: Array) -> int:
	var locked: Array[int] = _int_array(flow.payload.get("locked_tokens", []))
	for raw_idx: Variant in selected_indices:
		var idx: int = int(raw_idx)
		if locked.has(idx):
			return idx
	return -1


static func _dict_from(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

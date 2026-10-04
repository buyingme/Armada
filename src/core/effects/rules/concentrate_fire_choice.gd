## Post-roll ship Concentrate Fire commitment opportunity.
class_name ConcentrateFireChoiceRule
extends RefCounted


const CAPABILITY_ID: String = "ship_command.concentrate_fire"
const SOURCE_OWNER_KIND: String = "ship_command"
const SEMANTIC_KEY: String = "concentrate_fire_advance_choice"
const DIAL_SEMANTIC_KEY: String = "concentrate_fire_dial_addition"
const COMMAND_TYPE: String = "choose_concentrate_fire"


static func register() -> void:
	RuleRegistry.register_timing_window_participant({
		RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID: CAPABILITY_ID,
		RuleRegistry.PARTICIPANT_KEY_WINDOW:
				TimingWindowDefinitions.ATTACK_MODIFY,
		RuleRegistry.PARTICIPANT_KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT: load(
				"res://src/core/effects/rules/concentrate_fire_choice.gd"),
		RuleRegistry.PARTICIPANT_KEY_DIAGNOSTIC_ID:
				"concentrate-fire-advance-choice",
	})


static func enumerate_timing_window_sources(game_state: GameState,
		timing_state: TimingWindowState) -> Variant:
	var source: Dictionary = pending_source(game_state, timing_state)
	if source.is_empty():
		return []
	return [{
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID:
				str(source["runtime_source_id"]),
	}]


static func derive_timing_window_opportunities(game_state: GameState,
		timing_state: TimingWindowState, source_owner_kind: String,
		runtime_source_id: String) -> Variant:
	var source: Dictionary = pending_source(game_state, timing_state)
	if source.is_empty() or source_owner_kind != SOURCE_OWNER_KIND \
			or runtime_source_id != str(source["runtime_source_id"]):
		return []
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack.cf_dial_resolution == CurrentAttackState.RESOLUTION_PENDING:
		var colours: Array[String] = _pool_colours(attack.dice_pool)
		if colours.is_empty():
			return null
		var dial_opportunity: Dictionary = TimingWindowOpportunity.create({
			TimingWindowOpportunity.KEY_CAPABILITY_ID: CAPABILITY_ID,
			TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
			TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID: runtime_source_id,
			TimingWindowOpportunity.KEY_SEMANTIC_KEY: DIAL_SEMANTIC_KEY,
			TimingWindowOpportunity.KEY_CONTROLLER_PLAYER:
					timing_state.controller_player,
			TimingWindowOpportunity.KEY_RESOLUTION_KIND:
					TimingWindowOpportunity.RESOLUTION_OPTIONAL,
			TimingWindowOpportunity.KEY_BLOCKING: true,
			TimingWindowOpportunity.KEY_USE_INTENT: _dial_intent(
					source, timing_state, colours[0]),
			TimingWindowOpportunity.KEY_DECLINE_INTENT: _dial_intent(
					source, timing_state, ""),
		})
		return [dial_opportunity] if not dial_opportunity.is_empty() else null
	var ship: ShipInstance = source["ship"] as ShipInstance
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial() \
			if ship.command_dial_stack != null else {}
	var first_choice: String = CurrentAttackState.CF_CHOICE_DIAL \
			if int(revealed.get("command", -1)) \
				== int(Constants.CommandType.CONCENTRATE_FIRE) \
			else CurrentAttackState.CF_CHOICE_TOKEN
	var intent: Dictionary = _intent(source, timing_state, first_choice)
	var decline: Dictionary = _intent(source, timing_state,
			CurrentAttackState.CF_CHOICE_NEITHER)
	var opportunity: Dictionary = TimingWindowOpportunity.create({
		TimingWindowOpportunity.KEY_CAPABILITY_ID: CAPABILITY_ID,
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID: runtime_source_id,
		TimingWindowOpportunity.KEY_SEMANTIC_KEY: SEMANTIC_KEY,
		TimingWindowOpportunity.KEY_CONTROLLER_PLAYER:
				timing_state.controller_player,
		TimingWindowOpportunity.KEY_RESOLUTION_KIND:
				TimingWindowOpportunity.RESOLUTION_OPTIONAL,
		TimingWindowOpportunity.KEY_BLOCKING: true,
		TimingWindowOpportunity.KEY_USE_INTENT: intent,
		TimingWindowOpportunity.KEY_DECLINE_INTENT: decline,
	})
	return [opportunity] if not opportunity.is_empty() else null


static func project_timing_window_opportunity(game_state: GameState,
		timing_state: TimingWindowState, opportunity: Dictionary,
		_viewer_player: int) -> Dictionary:
	if str(opportunity.get(TimingWindowOpportunity.KEY_CAPABILITY_ID, "")) \
			!= CAPABILITY_ID:
		return {}
	var source: Dictionary = pending_source(game_state, timing_state)
	if source.is_empty():
		return {}
	if str(opportunity.get(TimingWindowOpportunity.KEY_SEMANTIC_KEY, "")) \
			== DIAL_SEMANTIC_KEY:
		var dial_choices: Array[Dictionary] = []
		for color: String in _pool_colours(
				game_state.current_attack_state.dice_pool):
			dial_choices.append({"label": "Add %s die" % color.to_lower(),
				"intent": _dial_intent(source, timing_state, color)})
		return {"visible": true, "source_visible": true,
			"display_key": "command.concentrate_fire_dial",
			"use_choices": dial_choices}
	var ship: ShipInstance = source["ship"] as ShipInstance
	var dial: Dictionary = ship.command_dial_stack.get_revealed_dial() \
			if ship.command_dial_stack != null else {}
	var has_dial: bool = not dial.is_empty() \
			and int(dial.get("command", -1)) \
				== int(Constants.CommandType.CONCENTRATE_FIRE)
	var has_token: bool = ship.command_tokens != null \
			and ship.command_tokens.has_token(
				Constants.CommandType.CONCENTRATE_FIRE)
	var choices: Array[Dictionary] = []
	if has_dial:
		choices.append({"label": "Dial",
			"intent": _intent(source, timing_state,
				CurrentAttackState.CF_CHOICE_DIAL)})
	if has_token:
		choices.append({"label": "Token",
			"intent": _intent(source, timing_state,
				CurrentAttackState.CF_CHOICE_TOKEN)})
	if has_dial and has_token:
		choices.append({"label": "Dial + Token",
			"intent": _intent(source, timing_state,
				CurrentAttackState.CF_CHOICE_BOTH)})
	if choices.is_empty():
		return {}
	return {"visible": true, "source_visible": true,
		"display_key": "concentrate_fire",
		"use_choices": choices}


static func pending_source(game_state: GameState,
		timing_state: TimingWindowState) -> Dictionary:
	if game_state == null or timing_state == null \
			or not timing_state.active \
			or timing_state.timing_window_id \
				!= TimingWindowDefinitions.ATTACK_MODIFY:
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or (attack.cf_choice != CurrentAttackState.RESOLUTION_PENDING \
				and attack.cf_dial_resolution \
					!= CurrentAttackState.RESOLUTION_PENDING) \
			or timing_state.controller_player != attack.attacker_player \
			or str(timing_state.continuation_context.get(
				TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
				!= attack.attack_id:
		return {}
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if ship == null:
		return {}
	if attack.cf_choice == CurrentAttackState.RESOLUTION_PENDING \
			and ship.concentrate_fire_resolved_round == game_state.current_round:
		return {}
	if attack.cf_dial_resolution == CurrentAttackState.RESOLUTION_PENDING \
			and (attack.cf_choice_round != game_state.current_round \
				or ship.concentrate_fire_resolved_round \
					!= game_state.current_round \
				or attack.cf_choice_lifecycle_id != timing_state.lifecycle_id \
				or attack.cf_choice_activation_id \
					!= ship.ship_activation_identity):
		return {}
	return {"ship": ship, "attack_id": attack.attack_id,
		"round": game_state.current_round,
		"runtime_source_id": "%d:ship:%d:concentrate_fire_choice" % [
			attack.attacker_player, attack.attacker_index]}


static func _intent(source: Dictionary, timing_state: TimingWindowState,
		choice: String) -> Dictionary:
	var ship: ShipInstance = source["ship"] as ShipInstance
	return {TimingWindowOpportunity.INTENT_KEY_COMMAND_TYPE: COMMAND_TYPE,
		TimingWindowOpportunity.INTENT_KEY_PLAYER:
				timing_state.controller_player,
		TimingWindowOpportunity.INTENT_KEY_PAYLOAD: {
			"attack_id": str(source["attack_id"]),
			"choice": choice,
			"source_owner_kind": SOURCE_OWNER_KIND,
			"runtime_source_id": str(source["runtime_source_id"]),
			"semantic_key": SEMANTIC_KEY,
			"ship_activation_identity": ship.ship_activation_identity,
			"round": int(source["round"]),
			"timing_window_id": timing_state.timing_window_id,
			"lifecycle_id": timing_state.lifecycle_id,
		}}


static func _dial_intent(source: Dictionary,
		timing_state: TimingWindowState, color: String) -> Dictionary:
	var ship: ShipInstance = source["ship"] as ShipInstance
	var values: Dictionary = {
		"attack_id": str(source["attack_id"]),
		"source_owner_kind": SOURCE_OWNER_KIND,
		"runtime_source_id": str(source["runtime_source_id"]),
		"semantic_key": DIAL_SEMANTIC_KEY,
		"ship_activation_identity": ship.ship_activation_identity,
		"round": int(source["round"]),
		"timing_window_id": timing_state.timing_window_id,
		"lifecycle_id": timing_state.lifecycle_id,
	}
	if not color.is_empty():
		values["color"] = color
	return {TimingWindowOpportunity.INTENT_KEY_COMMAND_TYPE:
			"use_concentrate_fire_dial" if not color.is_empty() \
			else "decline_concentrate_fire_dial",
		TimingWindowOpportunity.INTENT_KEY_PLAYER:
				timing_state.controller_player,
		TimingWindowOpportunity.INTENT_KEY_PAYLOAD: values}


static func _pool_colours(pool: Dictionary) -> Array[String]:
	var colours: Array[String] = []
	for color: String in [DicePool.RED_KEY, DicePool.BLUE_KEY,
			DicePool.BLACK_KEY]:
		if int(pool.get(color, 0)) > 0:
			colours.append(color)
	return colours

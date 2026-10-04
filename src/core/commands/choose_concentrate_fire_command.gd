## Commits one post-roll Concentrate Fire resource choice atomically.
class_name ChooseConcentrateFireCommand
extends GameCommand


const TYPE: String = "choose_concentrate_fire"
const SCRIPT_PATH: String = \
		"res://src/core/commands/choose_concentrate_fire_command.gd"
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_choice.gd")


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		var command_script: GDScript = load(SCRIPT_PATH) as GDScript
		return command_script.new(player, pl))


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	var attack: CurrentAttackState = game_state.current_attack_state
	var timing: TimingWindowState = game_state.timing_window_state
	var flow: InteractionFlow = game_state.interaction_flow
	if attack == null or not attack.active \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or attack.cf_choice != CurrentAttackState.RESOLUTION_PENDING \
			or str(payload.get("attack_id", "")) != attack.attack_id:
		return "Concentrate Fire choice is not pending for this ship attack."
	if player_index != attack.attacker_player \
			or flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
		return "Concentrate Fire choice has the wrong controller or flow."
	if timing == null or not timing.active \
			or timing.status != TimingWindowState.STATUS_OPEN \
			or timing.timing_window_id != TimingWindowDefinitions.ATTACK_MODIFY \
			or str(payload.get("timing_window_id", "")) \
				!= timing.timing_window_id \
			or str(payload.get("lifecycle_id", "")) != timing.lifecycle_id \
			or timing.controller_player != player_index \
			or str(timing.continuation_context.get(
				TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
				!= attack.attack_id:
		return "Concentrate Fire choice has a stale timing lifecycle."
	var expected_source: String = "%d:ship:%d:concentrate_fire_choice" % [
		attack.attacker_player, attack.attacker_index]
	if str(payload.get("source_owner_kind", "")) != CF_RULE.SOURCE_OWNER_KIND \
			or str(payload.get("runtime_source_id", "")) != expected_source \
			or str(payload.get("semantic_key", "")) != CF_RULE.SEMANTIC_KEY:
		return "Concentrate Fire choice has a stale source identity."
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if ship == null or not ship.has_active_ship_activation() \
			or ship.ship_activation_identity \
				!= str(payload.get("ship_activation_identity", "")) \
			or int(payload.get("round", -1)) != game_state.current_round \
			or ship.concentrate_fire_resolved_round == game_state.current_round:
		return "Concentrate Fire choice has a stale ship or round identity."
	var choice: String = str(payload.get("choice", ""))
	if choice not in [CurrentAttackState.CF_CHOICE_DIAL,
			CurrentAttackState.CF_CHOICE_TOKEN,
			CurrentAttackState.CF_CHOICE_BOTH,
			CurrentAttackState.CF_CHOICE_NEITHER]:
		return "Invalid Concentrate Fire choice."
	if choice in [CurrentAttackState.CF_CHOICE_DIAL,
			CurrentAttackState.CF_CHOICE_BOTH]:
		var dial: Dictionary = ship.command_dial_stack.get_revealed_dial() \
				if ship.command_dial_stack != null else {}
		if dial.is_empty() or int(dial.get("command", -1)) \
				!= int(Constants.CommandType.CONCENTRATE_FIRE):
			return "No revealed Concentrate Fire dial is available."
	if choice in [CurrentAttackState.CF_CHOICE_TOKEN,
			CurrentAttackState.CF_CHOICE_BOTH] \
			and (ship.command_tokens == null \
				or not ship.command_tokens.has_token(
					Constants.CommandType.CONCENTRATE_FIRE)):
		return "No Concentrate Fire token is available."
	return ""


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	var choice: String = str(payload["choice"])
	var selected: bool = choice != CurrentAttackState.CF_CHOICE_NEITHER
	var dial_selected: bool = choice in [CurrentAttackState.CF_CHOICE_DIAL,
			CurrentAttackState.CF_CHOICE_BOTH]
	var token_selected: bool = choice in [CurrentAttackState.CF_CHOICE_TOKEN,
			CurrentAttackState.CF_CHOICE_BOTH]
	var replacement: CurrentAttackState = attack.with_patch({
		"cf_choice": choice,
		"cf_choice_round": game_state.current_round if selected else -1,
		"cf_choice_lifecycle_id": str(payload["lifecycle_id"])
				if selected else "",
		"cf_choice_activation_id": ship.ship_activation_identity
				if selected else "",
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_PENDING
				if dial_selected else CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_PENDING
				if token_selected else CurrentAttackState.RESOLUTION_UNAVAILABLE,
	})
	if replacement == null:
		return {}
	var dial_before: Dictionary = ship.command_dial_stack.serialize() \
			if ship.command_dial_stack != null else {}
	var token_before: Dictionary = ship.command_tokens.serialize() \
			if ship.command_tokens != null else {}
	var marker_before: int = ship.concentrate_fire_resolved_round
	if not game_state.set_current_attack_state(replacement):
		return {}
	if dial_selected and ship.command_dial_stack.spend_revealed().is_empty():
		_rollback(game_state, attack, ship, dial_before, token_before, marker_before)
		return {}
	if token_selected and not ship.command_tokens.spend_token(
			Constants.CommandType.CONCENTRATE_FIRE):
		_rollback(game_state, attack, ship, dial_before, token_before, marker_before)
		return {}
	if selected:
		ship.concentrate_fire_resolved_round = game_state.current_round
	return {"attack_id": attack.attack_id, "choice": choice,
		"dial_spent": dial_selected, "token_spent": token_selected,
		"round": game_state.current_round}


func _rollback(game_state: GameState, attack: CurrentAttackState,
		ship: ShipInstance, dial_before: Dictionary,
		token_before: Dictionary, marker_before: int) -> void:
	ship.command_dial_stack = CommandDialStack.deserialize(dial_before) \
			if not dial_before.is_empty() else null
	ship.command_tokens = CommandTokenManager.deserialize(token_before) \
			if not token_before.is_empty() else null
	ship.concentrate_fire_resolved_round = marker_before
	game_state.set_current_attack_state(attack)

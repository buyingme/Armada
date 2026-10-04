## Builds a post-Roll CF commitment through real submitted attack commands.
## Callers may choose a legal resource branch, then exercise result delivery.
class_name Bug071ProductionAttackBuilder
extends RefCounted


const CHOICE_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_choice.gd")
const TOKEN_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const CHOICE_COMMAND: GDScript = preload(
		"res://src/core/commands/choose_concentrate_fire_command.gd")
const DIAL_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_dial_command.gd")
const DIAL_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_dial_command.gd")
const TOKEN_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const TOKEN_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")


static func committed_dial(attacker_player: int = 1,
		choice: String = CurrentAttackState.CF_CHOICE_DIAL) -> Dictionary:
	if choice not in [CurrentAttackState.CF_CHOICE_DIAL,
			CurrentAttackState.CF_CHOICE_BOTH]:
		return {}
	return committed_choice(attacker_player, choice)


static func committed_choice(attacker_player: int = 1,
		choice: String = CurrentAttackState.CF_CHOICE_BOTH) -> Dictionary:
	if attacker_player not in [0, 1] or choice not in [
			CurrentAttackState.CF_CHOICE_DIAL,
			CurrentAttackState.CF_CHOICE_TOKEN,
			CurrentAttackState.CF_CHOICE_BOTH,
			CurrentAttackState.CF_CHOICE_NEITHER]:
		return {}
	var built: Dictionary = pending_choice(attacker_player)
	if built.is_empty():
		return {}
	var state: GameState = built["state"]
	var initial_state: Dictionary = built["initial_state"]
	var attack_id: String = state.current_attack_state.attack_id
	var projected: Dictionary = UIProjector.project(
			state, attacker_player).timing_window
	var chosen_payload: Dictionary = {}
	for opportunity: Dictionary in projected.get("opportunities", []):
		if str(opportunity.get("semantic_key", "")) \
				!= CHOICE_RULE.SEMANTIC_KEY:
			continue
		if choice == CurrentAttackState.CF_CHOICE_NEITHER:
			chosen_payload = (opportunity.get("decline_intent", {}) \
				as Dictionary).get("payload", {})
			break
		for option: Dictionary in opportunity.get("use_choices", []):
			var proposed: Dictionary = (option.get("intent", {}) \
				as Dictionary).get("payload", {})
			if str(proposed.get("choice", "")) == choice:
				chosen_payload = proposed
	if chosen_payload.is_empty() or CommandProcessor.submit_deferred_followups(
			CHOICE_COMMAND.new(attacker_player, chosen_payload)).is_empty():
		return {}
	var dial_payload: Dictionary = {}
	projected = UIProjector.project(state, attacker_player).timing_window
	for opportunity: Dictionary in projected.get("opportunities", []):
		if str(opportunity.get("semantic_key", "")) \
				!= CHOICE_RULE.DIAL_SEMANTIC_KEY:
			continue
		var options: Array = opportunity.get("use_choices", [])
		if not options.is_empty():
			dial_payload = ((options[0] as Dictionary).get("intent", {}) \
					as Dictionary).get("payload", {})
	if dial_payload.is_empty() and choice in [
			CurrentAttackState.CF_CHOICE_DIAL,
			CurrentAttackState.CF_CHOICE_BOTH]:
		return {}
	return {"state": state, "initial_state": initial_state,
		"dial_payload": dial_payload,
		"attacker_player": attacker_player,
		"command_sequence": CommandProcessor.get_next_sequence()}


static func pending_choice(attacker_player: int = 1,
		has_dial: bool = true, has_token: bool = true) -> Dictionary:
	if attacker_player not in [0, 1]:
		return {}
	RuleRegistry.clear()
	CHOICE_RULE.register()
	TOKEN_RULE.register()
	ActivateShipCommand.register()
	AdvanceActivationStepCommand.register()
	BeginAttackCommand.register()
	RollDiceCommand.register()
	CHOICE_COMMAND.register()
	DIAL_USE.register()
	DIAL_DECLINE.register()
	TOKEN_USE.register()
	TOKEN_DECLINE.register()
	ConfirmAttackDiceCommand.register()
	var state := GameState.new()
	state.initialize()
	if not state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()):
		return {}
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = attacker_player
	state.rng = GameRng.new(81171)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	var defender_player: int = 1 - attacker_player
	state.get_player_state(attacker_player).faction = \
			Constants.Faction.GALACTIC_EMPIRE
	state.get_player_state(defender_player).faction = \
			Constants.Faction.REBEL_ALLIANCE
	var attacker_key: String = "victory_ii_class_star_destroyer"
	var attacker := ShipInstance.create_from_data(attacker_key,
			AssetLoader.load_ship_data(attacker_key), 2, attacker_player)
	attacker.roster_entry_id = "bug071-production-attacker"
	attacker.pos_x = 0.5
	attacker.pos_y = 0.42
	attacker.rotation_deg = 180.0
	var dials: Array[int] = []
	for _index: int in range(attacker.command_dial_stack.get_dials_needed()):
		dials.append(Constants.CommandType.CONCENTRATE_FIRE \
				if has_dial else Constants.CommandType.NAVIGATE)
	if not attacker.command_dial_stack.assign_dials(dials, 1):
		return {}
	if has_token and not attacker.command_tokens.add_token(
				Constants.CommandType.CONCENTRATE_FIRE):
		return {}
	state.get_player_state(attacker_player).ships.append(attacker)
	var defender_key: String = "cr90_corvette_a"
	var defender := ShipInstance.create_from_data(defender_key,
			AssetLoader.load_ship_data(defender_key), 2, defender_player)
	defender.roster_entry_id = "bug071-production-defender"
	defender.pos_x = 0.5
	defender.pos_y = 0.58
	defender.rotation_deg = 0.0
	state.get_player_state(defender_player).ships.append(defender)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			attacker_player, Constants.Visibility.ALL, {})
	var initial_state: Dictionary = state.serialize()
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	if CommandProcessor.submit_deferred_followups(
			ActivateShipCommand.new(attacker_player,
					{"ship_index": 0})).is_empty():
		return {}
	if CommandProcessor.submit_deferred_followups(
			AdvanceActivationStepCommand.new(attacker_player, {
				"ship_index": 0,
				"step_id": "attack_step",
				"ship_activation_identity": attacker.ship_activation_identity,
			})).is_empty():
		return {}
	var candidate: Dictionary = {}
	for entry: Dictionary in TargetingListBuilder \
			.authoritative_ship_target_entries(state, attacker_player, 0):
		if str(entry.get("target_kind", "")) \
				== CurrentAttackState.KIND_SHIP:
			candidate = entry
			break
	if candidate.is_empty():
		return {}
	if CommandProcessor.submit_deferred_followups(
			BeginAttackCommand.new(attacker_player, {
				"attacker_player": attacker_player,
				"attacker_kind": CurrentAttackState.KIND_SHIP,
				"attacker_index": 0,
				"attacker_zone": int(candidate["attacker_zone"]),
				"defender_player": defender_player,
				"defender_kind": CurrentAttackState.KIND_SHIP,
				"defender_index": int(candidate["target_index"]),
				"defender_zone": int(candidate["target_zone"]),
				"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
				"range_band": str(candidate["range_band"]),
				"obstructed": bool(candidate["obstructed"]),
				"ship_activation_identity": attacker.ship_activation_identity,
			})).is_empty():
		return {}
	var attack_id: String = state.current_attack_state.attack_id
	if CommandProcessor.submit_deferred_followups(RollDiceCommand.new(
			attacker_player, {"attack_id": attack_id})).is_empty():
		return {}
	return {"state": state, "initial_state": initial_state,
		"attacker_player": attacker_player,
		"command_sequence": CommandProcessor.get_next_sequence()}

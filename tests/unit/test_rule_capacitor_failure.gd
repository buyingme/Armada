## Test: Capacitor Failure Rule
##
## Verifies the Phase M12 multi-hook RuleRegistry migration for the
## Capacitor Failure damage card.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const SHIP_KEY_CR90: String = "cr90_corvette_a"
const ATTACKER_PLAYER: int = 0
const DEFENDER_PLAYER: int = 1
const SHIP_INDEX: int = 0

var _processor: Node = null
var _state: GameState = null
var _saved_registry: Dictionary = {}
var _previous_state: GameState = null
var _rejected_reasons: Array[String] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_previous_state = GameManager.current_game_state
	RuleRegistry.clear()
	CapacitorFailure.register()
	CommitDefenseCommand.register()
	SpendDefenseTokenCommand.register()
	SelectRedirectZoneCommand.register()
	RepairActionCommand.register()
	_state = _make_attack_state()
	GameManager.current_game_state = _state
	_rejected_reasons.clear()
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)
	_processor.command_rejected.connect(_on_command_rejected)


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _previous_state
	_rejected_reasons.clear()


func test_register_adds_defense_and_repair_hooks() -> void:
	var spend_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			CapacitorFailure.COMMAND_SPEND_DEFENSE_TOKEN)
	var repair_hooks: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			CapacitorFailure.COMMAND_REPAIR_ACTION)
	var defense_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			CapacitorFailure.TARGET_DEFENSE_TOKEN_SPEND)
	var repair_blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			CapacitorFailure.TARGET_REPAIR_SHIELD)
	assert_eq(spend_hooks.size(), 1,
			"Capacitor Failure should validate defense token commands.")
	assert_eq(repair_hooks.size(), 1,
			"Capacitor Failure should validate repair shield commands.")
	assert_eq(defense_blockers.size(), 1,
			"Capacitor Failure should expose defense-token blocker metadata.")
	assert_eq(repair_blockers.size(), 1,
			"Capacitor Failure should expose repair-shield blocker metadata.")
	assert_eq(RuleRegistry.registered_hook_count(), 4,
			"Capacitor Failure should register four hooks in one rule file.")


func test_defense_blocker_blocks_redirect_when_defending_zone_empty() -> void:
	var ship: ShipInstance = _defender_ship()
	_add_capacitor_failure(ship)
	ship.current_shields["FRONT"] = 0
	var blocked: Array[int] = _blocked_defense_indices(ship)
	var redirect_index: int = _redirect_token_index(ship)
	assert_true(blocked.has(redirect_index),
			"Defense UI payload should block Redirect at zero shields.")


func test_defense_blocker_allows_redirect_when_defending_zone_shielded() -> void:
	var ship: ShipInstance = _defender_ship()
	_add_capacitor_failure(ship)
	ship.current_shields["FRONT"] = 1
	var blocked: Array[int] = _blocked_defense_indices(ship)
	assert_false(blocked.has(_redirect_token_index(ship)),
			"Redirect should remain available while the defending zone has shields.")


func test_spend_redirect_rejected_when_defending_zone_empty() -> void:
	var ship: ShipInstance = _defender_ship()
	_add_capacitor_failure(ship)
	ship.current_shields["FRONT"] = 0
	var result: Dictionary = _processor.submit(
			_make_spend_command(_redirect_token_index(ship)))
	assert_true(result.is_empty(),
			"SpendDefenseTokenCommand should reject blocked Redirect tokens.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected Redirect spend should not enter command history.")
	assert_true(_rejected_reasons[0].contains("Capacitor Failure"),
			"Rejection reason should identify the damage card.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_commit_redirect_rejected_when_defending_zone_empty() -> void:
	var ship: ShipInstance = _defender_ship()
	_add_capacitor_failure(ship)
	ship.current_shields["FRONT"] = 0
	var result: Dictionary = _processor.submit(
			_make_commit_command([_redirect_token_index(ship)]))
	assert_true(result.is_empty(),
			"CommitDefenseCommand should reject selected blocked Redirect tokens.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected defense commit should not enter command history.")
	assert_engine_error(1,
			"CommandProcessor should warn for the commit validator rejection.")


func test_redirect_zone_command_rejected_when_defending_zone_empty() -> void:
	var ship: ShipInstance = _defender_ship()
	_add_capacitor_failure(ship)
	ship.current_shields["FRONT"] = 0
	var cmd := SelectRedirectZoneCommand.new(DEFENDER_PLAYER, {
		"ship_index": SHIP_INDEX,
		"zone": Constants.HullZone.LEFT,
	})
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Redirect zone selection should be protected even if submitted directly.")
	assert_engine_error(1,
			"CommandProcessor should warn for the redirect-zone validator rejection.")


func test_spend_redirect_allowed_without_damage_card() -> void:
	var ship: ShipInstance = _defender_ship()
	ship.current_shields["FRONT"] = 0
	var result: Dictionary = _processor.submit(
			_make_spend_command(_redirect_token_index(ship)))
	assert_false(result.is_empty(),
			"Redirect should be spendable at zero shields without Capacitor Failure.")
	assert_eq(_processor.get_command_count(), 1,
			"Allowed spend should enter command history.")


func test_repair_resolver_blocks_recover_and_move_to_empty_zone() -> void:
	var ship: ShipInstance = _repair_ship_with_capacitor_failure()
	ship.current_shields["FRONT"] = 0
	ship.current_shields["LEFT"] = 1
	var resolver: RepairResolver = RepairResolver.create(
			ship, _state.damage_deck)
	assert_false(resolver.can_recover_shields_on("FRONT"),
			"Repair UI should hide recovery for zero-shield Capacitor zones.")
	assert_false(resolver.can_move_shields_between("LEFT", "FRONT"),
			"Repair UI should hide move-shield actions into zero-shield zones.")
	assert_true(resolver.can_recover_shields_on("LEFT"),
			"Other damaged shield zones should remain repairable.")


func test_repair_recover_command_rejected_for_empty_zone() -> void:
	var ship: ShipInstance = _repair_ship_with_capacitor_failure()
	ship.current_shields["FRONT"] = 0
	var result: Dictionary = _processor.submit(_make_recover_command("FRONT"))
	assert_true(result.is_empty(),
			"RepairActionCommand should reject recovery into a zero-shield zone.")
	assert_eq(int(ship.current_shields.get("FRONT", -1)), 0,
			"Rejected recovery should leave shields unchanged.")
	assert_engine_error(1,
			"CommandProcessor should warn for the repair validator rejection.")


func test_repair_move_command_rejected_for_empty_target_zone() -> void:
	var ship: ShipInstance = _repair_ship_with_capacitor_failure()
	ship.current_shields["FRONT"] = 0
	ship.current_shields["LEFT"] = 1
	var result: Dictionary = _processor.submit(
			_make_move_command("LEFT", "FRONT"))
	assert_true(result.is_empty(),
			"RepairActionCommand should reject moving shields into zero-shield zones.")
	assert_eq(int(ship.current_shields.get("FRONT", -1)), 0,
			"Rejected move should leave target shields unchanged.")
	assert_engine_error(1,
			"CommandProcessor should warn for the repair validator rejection.")


func test_repair_recover_allowed_after_capacitor_failure_repaired() -> void:
	var ship: ShipInstance = _repair_ship_with_capacitor_failure()
	ship.current_shields["FRONT"] = 0
	ship.faceup_damage.clear()
	var result: Dictionary = _processor.submit(_make_recover_command("FRONT"))
	assert_false(result.is_empty(),
			"Removing Capacitor Failure should allow shield recovery again.")
	assert_eq(int(ship.current_shields.get("FRONT", -1)), 1,
			"Allowed recovery should restore one shield.")


func test_save_load_rebuild_has_no_legacy_effect_but_rule_rejects() -> void:
	var ship: ShipInstance = _defender_ship()
	_add_capacitor_failure(ship)
	ship.current_shields["FRONT"] = 0
	var restored: GameState = GameState.deserialize(_state.serialize())
	GameManager.current_game_state = restored
	var restored_ship: ShipInstance = restored.get_ship(
			DEFENDER_PLAYER, SHIP_INDEX)
	var result: Dictionary = _processor.submit(
			_make_spend_command(_redirect_token_index(restored_ship)))
	assert_true(result.is_empty(),
			"RuleRegistry should still reject after save/load rebuild.")
	assert_engine_error(1,
			"CommandProcessor should warn for the restored-state rejection.")


func _on_command_rejected(_command: GameCommand, reason: String) -> void:
	_rejected_reasons.append(reason)


func _make_attack_state() -> GameState:
	var state: GameState = _base_state()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			DEFENDER_PLAYER,
			Constants.Visibility.ALL,
			_defense_payload())
	state.get_player_state(ATTACKER_PLAYER).ships.append(
			_make_ship(ATTACKER_PLAYER))
	state.get_player_state(DEFENDER_PLAYER).ships.append(
			_make_ship(DEFENDER_PLAYER))
	return state


func _base_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	return state


func _defense_payload() -> Dictionary:
	return {
		"defender_player": DEFENDER_PLAYER,
		"defender_ship_index": SHIP_INDEX,
		"defender_zone": int(Constants.HullZone.FRONT),
	}


func _make_repair_flow() -> void:
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			ATTACKER_PLAYER,
			Constants.Visibility.ALL,
			{})


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _defender_ship() -> ShipInstance:
	return _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)


func _repair_ship_with_capacitor_failure() -> ShipInstance:
	_make_repair_flow()
	var ship: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	ship.command_dial_stack.assign_dials([Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()
	_add_capacitor_failure(ship)
	return ship


func _add_capacitor_failure(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Capacitor Failure")
	card.effect_id = CapacitorFailure.EFFECT_ID
	card.effect_text = "If a hull zone has no remaining shields, you cannot " \
			+"recover shields in it nor move shields to it. If that hull " \
			+"zone is defending, you cannot spend Redirect tokens."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


func _redirect_token_index(ship: ShipInstance) -> int:
	for token_index: int in range(ship.defense_tokens.size()):
		var token: Dictionary = ship.defense_tokens[token_index]
		if int(token.get("type", -1)) == Constants.DefenseToken.REDIRECT:
			return token_index
	return -1


func _blocked_defense_indices(ship: ShipInstance) -> Array[int]:
	var state: AttackState = AttackState.new()
	state.defender_zone = int(Constants.HullZone.FRONT)
	var resolver: DefenseTokenResolver = DefenseTokenResolver.new()
	var flow_executor: AttackFlowExecutor = AttackFlowExecutor.new()
	return flow_executor.build_blocked_defense_token_indices(
			state, ship, resolver)


func _make_spend_command(token_index: int) -> SpendDefenseTokenCommand:
	return SpendDefenseTokenCommand.new(DEFENDER_PLAYER, {
		"ship_index": SHIP_INDEX,
		"token_index": token_index,
		"spend_method": "exhaust",
	})


func _make_commit_command(selected_indices: Array[int]) -> CommitDefenseCommand:
	var payload_indices: Array = []
	for idx: int in selected_indices:
		payload_indices.append(idx)
	return CommitDefenseCommand.new(DEFENDER_PLAYER, {
		"ship_index": SHIP_INDEX,
		"selected_indices": payload_indices,
	})


func _make_recover_command(zone: String) -> RepairActionCommand:
	return RepairActionCommand.new(ATTACKER_PLAYER, {
		"action_type": CapacitorFailure.ACTION_RECOVER_SHIELDS,
		"owner_player": ATTACKER_PLAYER,
		"ship_index": SHIP_INDEX,
		"zone": zone,
	})


func _make_move_command(from_zone: String, to_zone: String) -> RepairActionCommand:
	return RepairActionCommand.new(ATTACKER_PLAYER, {
		"action_type": CapacitorFailure.ACTION_MOVE_SHIELDS,
		"owner_player": ATTACKER_PLAYER,
		"ship_index": SHIP_INDEX,
		"from_zone": from_zone,
		"to_zone": to_zone,
	})

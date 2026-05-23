## Test: Coolant Discharge Rule
##
## Verifies the Phase N7 RuleRegistry ship-target blocker and replay-safe
## per-round attack counting for the Coolant Discharge damage card.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const SHIP_KEY_CR90: String = "cr90_corvette_a"
const ATTACKER_PLAYER: int = 0
const DEFENDER_PLAYER: int = 1
const SHIP_INDEX: int = 0

var _processor: Node = null
var _state: GameState = null
var _resolver: AttackDiceResolver = null
var _saved_registry: Dictionary = {}
var _previous_state: GameState = null


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_previous_state = GameManager.current_game_state
	RuleRegistry.clear()
	CoolantDischarge.register()
	PublishAttackFlowCommand.register()
	RollDiceCommand.register()
	_state = _make_state()
	_resolver = AttackDiceResolver.new()
	GameManager.current_game_state = _state
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _previous_state


func test_register_adds_attack_target_blocker_and_validator() -> void:
	var blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			RuleSurface.TARGET_ATTACK_TARGET)
	var validators: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			CoolantDischarge.COMMAND_PUBLISH_ATTACK_FLOW)
	assert_eq(blockers.size(), 1,
			"Coolant Discharge should expose target-blocker metadata.")
	assert_eq(validators.size(), 1,
			"Coolant Discharge should guard direct attack-flow publishes.")
	assert_eq(RuleRegistry.registered_hook_count(), 2,
			"Coolant Discharge should register two hooks.")


func test_blocker_blocks_second_ship_target_for_ship_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	assert_true(_attack_target_blocked(attacker, "ship", 1),
			"Second ship-targeting attack should be blocked this round.")


func test_blocker_allows_first_ship_target_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	assert_false(_attack_target_blocked(attacker, "ship", 0),
			"First ship-targeting attack should remain legal.")


func test_blocker_allows_second_squadron_target_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	assert_false(_attack_target_blocked(attacker, "squadron", 1),
			"Coolant Discharge only limits attacks against ships.")


func test_roll_dice_command_records_ship_target_attack() -> void:
	var attacker: ShipInstance = _attacker_ship()
	assert_eq(_state.get_ship_target_attack_count(attacker), 0,
			"Precondition: no ship-targeting attacks recorded.")
	_make_roll_command("ship").execute(_state)
	assert_eq(_state.get_ship_target_attack_count(attacker), 1,
			"RollDiceCommand should record a ship-targeting attack.")


func test_roll_dice_command_ignores_squadron_targets() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_make_roll_command("squadron").execute(_state)
	assert_eq(_state.get_ship_target_attack_count(attacker), 0,
			"Squadron targets should not count against Coolant Discharge.")


func test_ship_target_count_is_per_round() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_state.record_ship_target_attack(attacker)
	_state.current_round = 2
	assert_eq(_state.get_ship_target_attack_count(attacker), 0,
			"A new round should read a fresh ship-target attack count.")


func test_attack_dice_resolver_uses_rule_without_legacy_registry() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	var parts: CombatParticipants = CombatParticipants.create(
			_make_ship_token(attacker), Constants.HullZone.FRONT, null,
			_make_ship_token(_defender_ship()), Constants.HullZone.FRONT, null)
	var blocked: bool = _resolver.is_blocked_by_damage_at_range(
			null, parts, false, 1, Constants.RANGE_BAND_CLOSE)
	assert_true(blocked,
			"AttackDiceResolver should consume the Coolant target blocker.")


func test_publish_attack_flow_validator_rejects_second_ship_target() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	_state.record_ship_target_attack(attacker)
	var result: Dictionary = _processor.submit(_make_publish_command("ship"))
	assert_true(result.is_empty(),
			"Direct publish should reject a second ship target this round.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected publish should not enter command history.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_publish_attack_flow_validator_allows_squadron_target() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	_state.record_ship_target_attack(attacker)
	var result: Dictionary = _processor.submit(_make_publish_command("squadron"))
	assert_false(result.is_empty(),
			"Squadron target publishes should remain legal.")
	assert_eq(_processor.get_command_count(), 1,
			"Allowed publish should enter command history.")


func test_blocker_applies_after_save_load_without_legacy_effect() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_coolant_discharge(attacker)
	_state.record_ship_target_attack(attacker)
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_attacker: ShipInstance = restored.get_ship(
			ATTACKER_PLAYER, SHIP_INDEX)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Coolant Discharge should not rebuild a legacy effect.")
	assert_eq(restored.get_ship_target_attack_count(restored_attacker), 1,
			"Ship-target attack counts should survive save/load.")
	assert_true(_attack_target_blocked(restored_attacker, "ship", 1),
			"RuleRegistry blocker should still apply after save/load rebuild.")


func _attack_target_blocked(attacker: ShipInstance,
		target_kind: String,
		attack_count: int) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = attacker
	ctx.set_meta_value("target_kind", target_kind)
	ctx.set_meta_value("ship_target_attacks_this_round", attack_count)
	return RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			RuleSurface.TARGET_ATTACK_TARGET)


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			ATTACKER_PLAYER)
	state.get_player_state(ATTACKER_PLAYER).ships.append(
			_make_ship(ATTACKER_PLAYER))
	state.get_player_state(DEFENDER_PLAYER).ships.append(
			_make_ship(DEFENDER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _make_ship_token(instance: ShipInstance) -> ShipToken:
	var token: ShipToken = ShipToken.new()
	token._placement = TokenPlacement.new(
			SHIP_KEY_CR90, true, Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.5, 0.0, Constants.ShipSize.SMALL)
	token._half_w = 30.0
	token._half_l = 50.0
	token._ship_data = instance.ship_data
	token._ship_instance = instance
	add_child_autofree(token)
	return token


func _make_roll_command(target_kind: String) -> RollDiceCommand:
	return RollDiceCommand.new(ATTACKER_PLAYER, {
		"dice_pool": {"RED": 1},
		"attacker_kind": "ship",
		"attacker_player": ATTACKER_PLAYER,
		"attacker_ship_index": SHIP_INDEX,
		"target_kind": target_kind,
	})


func _make_publish_command(target_kind: String) -> PublishAttackFlowCommand:
	return PublishAttackFlowCommand.new(ATTACKER_PLAYER, {
		"step_id": int(Constants.InteractionStep.ATTACK_ROLL),
		"controller_player": ATTACKER_PLAYER,
		"flow_payload": _attack_payload(target_kind),
		"final": false,
	})


func _attack_payload(target_kind: String) -> Dictionary:
	return {
		"attacker_kind": "ship",
		"attacker_player": ATTACKER_PLAYER,
		"attacker_ship_index": SHIP_INDEX,
		"target_kind": target_kind,
		"target_ship_index": SHIP_INDEX,
	}


func _attacker_ship() -> ShipInstance:
	return _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)


func _defender_ship() -> ShipInstance:
	return _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)


func _add_coolant_discharge(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Coolant Discharge")
	card.effect_id = CoolantDischarge.EFFECT_ID
	card.effect_text = "You can only perform 1 attack against a ship each round."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card

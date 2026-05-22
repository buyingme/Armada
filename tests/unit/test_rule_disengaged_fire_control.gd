## Test: Disengaged Fire Control Rule
##
## Verifies the Phase N6 RuleRegistry attack-target blocker for the
## Disengaged Fire Control damage card.
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
	DisengagedFireControl.register()
	PublishAttackFlowCommand.register()
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
			DisengagedFireControl.COMMAND_PUBLISH_ATTACK_FLOW)
	assert_eq(blockers.size(), 1,
			"Disengaged Fire Control should expose target-blocker metadata.")
	assert_eq(validators.size(), 1,
			"Disengaged Fire Control should guard direct attack-flow publishes.")
	assert_eq(RuleRegistry.registered_hook_count(), 2,
			"Disengaged Fire Control should register two hooks.")


func test_blocker_blocks_obstructed_target_for_ship_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_disengaged_fire_control(attacker)
	assert_true(_attack_target_blocked(attacker, true),
			"Obstructed attacks should be blocked for the damaged ship.")


func test_blocker_allows_unobstructed_target_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_disengaged_fire_control(attacker)
	assert_false(_attack_target_blocked(attacker, false),
			"Unobstructed attacks should remain legal.")


func test_blocker_allows_obstructed_target_without_card() -> void:
	assert_false(_attack_target_blocked(_attacker_ship(), true),
			"Ships without the damage card should keep obstructed attacks.")


func test_attack_dice_resolver_uses_rule_without_legacy_registry() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_disengaged_fire_control(attacker)
	var parts: CombatParticipants = CombatParticipants.create(
			_make_ship_token(attacker), Constants.HullZone.FRONT, null,
			_make_ship_token(_defender_ship()), Constants.HullZone.FRONT, null)
	var blocked: bool = _resolver.is_blocked_by_damage_at_range(
			null, parts, true, 0, Constants.RANGE_BAND_MEDIUM)
	assert_true(blocked,
			"AttackDiceResolver should consume RuleRegistry target blockers.")


func test_publish_attack_flow_validator_rejects_obstructed_target() -> void:
	_add_disengaged_fire_control(_attacker_ship())
	var result: Dictionary = _processor.submit(_make_publish_command(true))
	assert_true(result.is_empty(),
			"Direct attack-flow publish should reject obstructed targets.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected publish should not enter command history.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_publish_attack_flow_validator_allows_unobstructed_target() -> void:
	_add_disengaged_fire_control(_attacker_ship())
	var result: Dictionary = _processor.submit(_make_publish_command(false))
	assert_false(result.is_empty(),
			"Unobstructed attack-flow publishes should remain legal.")
	assert_eq(_processor.get_command_count(), 1,
			"Allowed publish should enter command history.")


func test_blocker_applies_after_save_load_without_legacy_effect() -> void:
	_add_disengaged_fire_control(_attacker_ship())
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_attacker: ShipInstance = restored.get_ship(
			ATTACKER_PLAYER, SHIP_INDEX)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Disengaged Fire Control should not rebuild a legacy effect.")
	assert_true(_attack_target_blocked(restored_attacker, true),
			"RuleRegistry blocker should still apply after save/load rebuild.")


func _attack_target_blocked(attacker: ShipInstance, obstructed: bool) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = attacker
	ctx.set_meta_value("is_obstructed", obstructed)
	ctx.set_meta_value("target_kind", "ship")
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


func _make_publish_command(obstructed: bool) -> PublishAttackFlowCommand:
	return PublishAttackFlowCommand.new(ATTACKER_PLAYER, {
		"step_id": int(Constants.InteractionStep.ATTACK_ROLL),
		"controller_player": ATTACKER_PLAYER,
		"flow_payload": _attack_payload(obstructed),
		"final": false,
	})


func _attack_payload(obstructed: bool) -> Dictionary:
	return {
		"attacker_kind": "ship",
		"attacker_player": ATTACKER_PLAYER,
		"attacker_ship_index": SHIP_INDEX,
		"target_kind": "ship",
		"target_ship_index": SHIP_INDEX,
		"is_obstructed": obstructed,
	}


func _attacker_ship() -> ShipInstance:
	return _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)


func _defender_ship() -> ShipInstance:
	return _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)


func _add_disengaged_fire_control(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Disengaged Fire Control")
	card.effect_id = DisengagedFireControl.EFFECT_ID
	card.effect_text = "You cannot attack obstructed targets."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card
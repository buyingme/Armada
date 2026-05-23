## Test: Blinded Gunners Rule
##
## Verifies the Phase N8 RuleRegistry accuracy-spend blocker for the
## Blinded Gunners damage card.
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
	BlindedGunners.register()
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


func test_register_adds_accuracy_blocker_and_validator() -> void:
	var blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			RuleSurface.TARGET_ACCURACY_SPEND)
	var validators: Array[FlowHook] = RuleRegistry.validators_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			BlindedGunners.COMMAND_PUBLISH_ATTACK_FLOW)
	assert_eq(blockers.size(), 1,
			"Blinded Gunners should expose accuracy blocker metadata.")
	assert_eq(validators.size(), 1,
			"Blinded Gunners should guard direct locked-token publishes.")
	assert_eq(RuleRegistry.registered_hook_count(), 2,
			"Blinded Gunners should register two hooks.")


func test_blocker_blocks_accuracy_spend_for_ship_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_blinded_gunners(attacker)
	assert_true(_accuracy_spend_blocked(attacker),
			"Blinded Gunners should block accuracy spending for its ship.")


func test_blocker_allows_accuracy_spend_without_card() -> void:
	assert_false(_accuracy_spend_blocked(_attacker_ship()),
			"Ships without Blinded Gunners should spend accuracy normally.")


func test_resolver_returns_zero_spendable_accuracy_without_legacy_registry() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_blinded_gunners(attacker)
	var parts: CombatParticipants = CombatParticipants.create(
			_make_ship_token(attacker), Constants.HullZone.FRONT, null,
			_make_ship_token(_defender_ship()), Constants.HullZone.FRONT, null)
	var result: Dictionary = _resolver.resolve_accuracy_spend(
			_accuracy_results(), parts, null)
	assert_eq(int(result.get("accuracy_count", 0)), 2,
			"The raw accuracy count should remain visible in payload metadata.")
	assert_eq(int(result.get("spendable_accuracy_count", 0)), 0,
			"No accuracy icons should be spendable while Blinded Gunners is active.")
	assert_true(bool(result.get("blocked", false)),
			"Resolver should report that accuracy spending was blocked.")


func test_publish_attack_flow_validator_rejects_locked_tokens() -> void:
	_add_blinded_gunners(_attacker_ship())
	var result: Dictionary = _processor.submit(_make_publish_command([0]))
	assert_true(result.is_empty(),
			"Direct publish should reject accuracy-locked tokens.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected publish should not enter command history.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_publish_attack_flow_validator_allows_empty_locked_tokens() -> void:
	_add_blinded_gunners(_attacker_ship())
	var result: Dictionary = _processor.submit(_make_publish_command([]))
	assert_false(result.is_empty(),
			"Empty locked-token payloads should remain legal.")
	assert_eq(_processor.get_command_count(), 1,
			"Allowed publish should enter command history.")


func test_blocker_applies_after_save_load_without_legacy_effect() -> void:
	_add_blinded_gunners(_attacker_ship())
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_attacker: ShipInstance = restored.get_ship(
			ATTACKER_PLAYER, SHIP_INDEX)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Blinded Gunners should not rebuild a legacy effect.")
	assert_true(_accuracy_spend_blocked(restored_attacker),
			"RuleRegistry blocker should still apply after save/load rebuild.")


func _accuracy_spend_blocked(attacker: ShipInstance) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = attacker
	return RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			RuleSurface.TARGET_ACCURACY_SPEND)


func _accuracy_results() -> Array[Dictionary]:
	return [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.ACCURACY},
	]


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			DEFENDER_PLAYER)
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


func _make_publish_command(locked_tokens: Array[int]) -> PublishAttackFlowCommand:
	return PublishAttackFlowCommand.new(ATTACKER_PLAYER, {
		"step_id": int(Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE),
		"controller_player": DEFENDER_PLAYER,
		"flow_payload": _defense_payload(locked_tokens),
		"final": false,
	})


func _defense_payload(locked_tokens: Array[int]) -> Dictionary:
	return {
		"attacker_kind": "ship",
		"attacker_player": ATTACKER_PLAYER,
		"attacker_ship_index": SHIP_INDEX,
		"target_kind": "ship",
		"target_ship_index": SHIP_INDEX,
		"locked_tokens": locked_tokens.duplicate(),
	}


func _attacker_ship() -> ShipInstance:
	return _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)


func _defender_ship() -> ShipInstance:
	return _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)


func _add_blinded_gunners(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Crew", "Blinded Gunners")
	card.effect_id = BlindedGunners.EFFECT_ID
	card.effect_text = "While attacking, you cannot spend accuracy icons."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card

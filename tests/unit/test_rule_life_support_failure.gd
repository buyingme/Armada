## Test: Life Support Failure Rule
##
## Verifies the Phase N4 RuleRegistry command-token gain blockers for the
## persistent restriction on Life Support Failure.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const SHIP_KEY_CR90: String = "cr90_corvette_a"
const OWNER_PLAYER: int = 0
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
	LifeSupportFailure.register()
	ConvertDialToTokenCommand.register()
	_state = _make_state()
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


func test_register_adds_token_gain_hooks_for_conversion_steps() -> void:
	assert_eq(_validator_count(Constants.InteractionStep.WAIT_FOR_SHIP_SELECT), 1,
			"Life Support Failure should validate pre-activation conversion.")
	assert_eq(_validator_count(Constants.InteractionStep.ACTIVATION_MODAL_OPEN), 1,
			"Life Support Failure should validate modal conversion.")
	assert_eq(_validator_count(Constants.InteractionStep.SPEND_DIAL), 1,
			"Life Support Failure should validate spend-dial conversion.")
	assert_eq(_blocker_count(Constants.InteractionStep.ACTIVATION_MODAL_OPEN), 1,
			"Life Support Failure should expose token-gain blocker metadata.")
	assert_eq(RuleRegistry.registered_hook_count(), 6,
			"Life Support Failure should register validators and blockers.")


func test_blocker_blocks_command_token_gain_for_ship_with_card() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_life_support_failure(ship)
	assert_true(_token_gain_blocked(ship),
			"Command-token gain should be blocked by Life Support Failure.")


func test_blocker_allows_ship_without_card() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	assert_false(_token_gain_blocked(ship),
			"Ships without Life Support Failure should gain command tokens.")


func test_convert_dial_to_token_rejected_by_validator() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_life_support_failure(ship)
	var result: Dictionary = _processor.submit(_make_convert_command())
	assert_true(result.is_empty(),
			"CommandProcessor should reject command-token gain before execute.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected token gain should not enter command history.")
	assert_eq(ship.command_dial_stack.get_hidden_count(), 1,
			"Rejected preflight should leave the hidden dial untouched.")
	assert_true(_rejected_reasons[0].contains("Life Support Failure"),
			"Rejection reason should identify the damage card.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_convert_dial_to_token_execute_blocks_without_legacy_registry() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_life_support_failure(ship)
	var result: Dictionary = _make_convert_command().execute(_state)
	assert_true(result.get("token_blocked", false),
			"Direct command execution should still consult RuleRegistry blockers.")
	assert_eq(ship.command_tokens.get_token_count(), 0,
			"Blocked execution should not add a command token.")


func test_convert_dial_to_token_allows_ship_without_card() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	var result: Dictionary = _make_convert_command().execute(_state)
	assert_true(result.get("token_added", false),
			"Ships without Life Support Failure should gain the converted token.")
	assert_eq(ship.command_tokens.get_token_count(), 1,
			"Allowed conversion should add one command token.")


func test_blocker_applies_after_save_load_without_legacy_effect() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_life_support_failure(ship)
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	GameManager.current_game_state = restored
	var restored_ship: ShipInstance = restored.get_ship(OWNER_PLAYER, SHIP_INDEX)
	var result: Dictionary = _make_convert_command().execute(restored)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Life Support Failure should not rebuild a legacy token-gain effect.")
	assert_true(result.get("token_blocked", false),
			"RuleRegistry blocker should still apply after save/load rebuild.")
	assert_eq(restored_ship.command_tokens.get_token_count(), 0,
			"Restored blocked execution should not add command tokens.")


func _validator_count(step_id: Constants.InteractionStep) -> int:
	return RuleRegistry.validators_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_id,
			LifeSupportFailure.COMMAND_CONVERT_DIAL_TO_TOKEN).size()


func _blocker_count(step_id: Constants.InteractionStep) -> int:
	return RuleRegistry.blockers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_id,
			LifeSupportFailure.TARGET_COMMAND_TOKEN_GAIN).size()


func _token_gain_blocked(ship: ShipInstance) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	return RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			LifeSupportFailure.TARGET_COMMAND_TOKEN_GAIN)


func _on_command_rejected(_command: GameCommand, reason: String) -> void:
	_rejected_reasons.append(reason)


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			OWNER_PLAYER)
	state.get_player_state(OWNER_PLAYER).ships.append(_make_ship(OWNER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	var ship: ShipInstance = ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)
	ship.command_dial_stack.assign_dials([Constants.CommandType.NAVIGATE], 1)
	return ship


func _make_convert_command() -> ConvertDialToTokenCommand:
	return ConvertDialToTokenCommand.new(OWNER_PLAYER, {"ship_index": SHIP_INDEX})


func _add_life_support_failure(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Crew", "Life Support Failure")
	card.effect_id = LifeSupportFailure.EFFECT_ID
	card.effect_text = "Discard all of your command tokens. You cannot have " \
			+"any command tokens."
	card.timing = "immediate_persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card

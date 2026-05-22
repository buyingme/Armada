## Life Support Failure
##
## Static rule hooks for the persistent restriction on the Life Support
## Failure damage card. The immediate discard remains in the immediate effect
## resolver; this rule blocks later command-token gain from serialized damage
## state.
## Rules Reference: Damage Card "Life Support Failure" — "Discard all of
## your command tokens. You cannot have any command tokens."
class_name LifeSupportFailure
extends RefCounted


const RULE_ID: String = "damage_card.life_support_failure"
const EFFECT_ID: String = "life_support_failure"
const COMMAND_CONVERT_DIAL_TO_TOKEN: String = "convert_dial_to_token"
const TARGET_COMMAND_TOKEN_GAIN: String = "command_token_gain"
const REJECTION_REASON: String = \
		"Life Support Failure: this ship cannot gain command tokens."

static var _rule_instance: LifeSupportFailure = null


## Registers validators and blockers for all command-dial token-gain steps.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = LifeSupportFailure.new()
	RuleRegistry.register_rule(RULE_ID, _token_gain_hooks())


## Returns whether a command-token gain command is legal for this rule.
func validate_token_gain_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var ship: ShipInstance = _get_command_ship(game_state, command)
	if ship == null or not _has_life_support_failure(ship):
		return _allow()
	return _deny(REJECTION_REASON)


## Returns blocker metadata for command-token gain UI/command helpers.
## [param context] must carry `metadata.ship`.
func block_command_token_gain(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var ship: ShipInstance = context.get_meta_value("ship", null) as ShipInstance
	if ship == null or not _has_life_support_failure(ship):
		return _not_blocked()
	return _blocked(REJECTION_REASON)


static func _token_gain_hooks() -> Array[FlowHook]:
	var hooks: Array[FlowHook] = []
	_append_token_gain_hooks(hooks, Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	_append_token_gain_hooks(hooks, Constants.InteractionStep.ACTIVATION_MODAL_OPEN)
	_append_token_gain_hooks(hooks, Constants.InteractionStep.SPEND_DIAL)
	return hooks


static func _append_token_gain_hooks(hooks: Array[FlowHook],
		step_id: Constants.InteractionStep) -> void:
	hooks.append(FlowHook.validator(RULE_ID,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_id,
			COMMAND_CONVERT_DIAL_TO_TOKEN,
			Callable(_rule_instance, "validate_token_gain_command")))
	hooks.append(FlowHook.blocker(RULE_ID,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_id,
			TARGET_COMMAND_TOKEN_GAIN,
			Callable(_rule_instance, "block_command_token_gain")))


func _get_command_ship(game_state: GameState,
		command: GameCommand) -> ShipInstance:
	var ship_index: int = int(command.payload.get("ship_index", -1))
	return game_state.get_ship(command.player_index, ship_index)


func _has_life_support_failure(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == EFFECT_ID:
			return true
	return false


func _allow() -> Dictionary:
	return {"allowed": true, "reason": ""}


func _deny(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}


func _blocked(reason: String) -> Dictionary:
	return {"blocked": true, "reason": reason}


func _not_blocked() -> Dictionary:
	return {"blocked": false, "reason": ""}

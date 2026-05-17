## Faulty Countermeasures
##
## Static rule hook for the Faulty Countermeasures damage card.
## Rules Reference: Damage Card "Faulty Countermeasures" —
## "You cannot spend exhausted defense tokens."
class_name FaultyCountermeasures
extends RefCounted


const RULE_ID: String = "damage_card.faulty_countermeasures"
const EFFECT_ID: String = "faulty_countermeasures"
const COMMAND_COMMIT_DEFENSE: String = "commit_defense"
const COMMAND_SPEND_DEFENSE_TOKEN: String = "spend_defense_token"
const REJECTION_REASON: String = \
		"Faulty Countermeasures: exhausted defense tokens cannot be spent."

static var _rule_instance: FaultyCountermeasures = null


## Registers the command-time defense-token validator hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = FaultyCountermeasures.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
				FlowHook.ANY,
				Callable(_rule_instance, "validate_defense_token_command")),
	])


## Returns whether a defense-token command is legal for this rule.
## Invalid payloads are allowed through so command-specific validation can
## produce the canonical rejection reason.
func validate_defense_token_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	match command.command_type:
		COMMAND_SPEND_DEFENSE_TOKEN:
			return _validate_spend_command(game_state, command)
		COMMAND_COMMIT_DEFENSE:
			return _validate_commit_command(game_state, command)
		_:
			return _allow()


func _validate_spend_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	var ship: ShipInstance = _get_command_ship(game_state, command)
	if ship == null:
		return _allow()
	var token_index: int = int(command.payload.get("token_index", -1))
	return _validate_token_index(ship, token_index)


func _validate_commit_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	var ship: ShipInstance = _get_command_ship(game_state, command)
	if ship == null:
		return _allow()
	var selected: Array = command.payload.get("selected_indices", []) as Array
	for raw_index: Variant in selected:
		var result: Dictionary = _validate_token_index(ship, int(raw_index))
		if not bool(result.get("allowed", true)):
			return result
	return _allow()


func _validate_token_index(ship: ShipInstance,
		token_index: int) -> Dictionary:
	if not _has_token(ship, token_index):
		return _allow()
	if not _has_faulty_countermeasures(ship):
		return _allow()
	if _token_is_exhausted(ship, token_index):
		return {"allowed": false, "reason": REJECTION_REASON}
	return _allow()


func _get_command_ship(game_state: GameState,
		command: GameCommand) -> ShipInstance:
	var ship_index: int = int(command.payload.get("ship_index", -1))
	return game_state.get_ship(command.player_index, ship_index)


func _has_token(ship: ShipInstance, token_index: int) -> bool:
	return token_index >= 0 and token_index < ship.defense_tokens.size()


func _has_faulty_countermeasures(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.effect_id == EFFECT_ID:
			return true
	return false


func _token_is_exhausted(ship: ShipInstance, token_index: int) -> bool:
	var token: Dictionary = ship.defense_tokens[token_index]
	var token_state: Constants.DefenseTokenState = \
			token["state"] as Constants.DefenseTokenState
	return token_state == Constants.DefenseTokenState.EXHAUSTED


func _allow() -> Dictionary:
	return {"allowed": true, "reason": ""}
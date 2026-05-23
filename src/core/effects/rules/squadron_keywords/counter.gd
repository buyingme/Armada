## Counter Keyword
##
## Static projection hook for the Counter X squadron keyword.
## Rules Reference: RRG "Squadron Keywords" — "After a squadron performs
## a non-counter attack against you, you may attack that squadron with an
## anti-squadron armament of blue dice equal to X, even if you are destroyed."
class_name CounterKeyword
extends RefCounted


const RULE_ID: String = "squadron_keyword.counter"
const COMMAND_ROLL_DICE: String = "roll_dice"
const COMMAND_COUNTER_CHOICE: String = "counter_choice"
const PAYLOAD_AVAILABLE: String = "counter_attack_available"
const PAYLOAD_CONTROLLER_PLAYER: String = "counter_controller_player"
const PAYLOAD_DICE_POOL: String = "counter_dice_pool"
const PROMPT: String = "Counter"
const REJECTION_REASON: String = \
		"Counter: roll must use the locked Counter dice pool."

static var _rule_instance: CounterKeyword = null


## Registers the Counter attack projection affordance hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = CounterKeyword.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_ROLL,
				COMMAND_ROLL_DICE,
				Callable(_rule_instance, "validate_counter_roll")),
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
				COMMAND_COUNTER_CHOICE,
				Callable(_rule_instance, "validate_counter_choice")),
		FlowHook.enabler(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
				RuleSurface.TARGET_ATTACK_MODIFIER_AFFORDANCE,
				Callable(_rule_instance, "project_counter_affordance")),
	])


## Returns whether a defending squadron may resolve Counter after this attack.
## Rules Reference: RRG "Squadron Keywords" — Counter triggers after a
## squadron performs a non-Counter attack against the defender; damage is not
## a condition.
static func is_counter_trigger_available(attack_kind: String,
		attacker: SquadronInstance,
		defender: SquadronInstance) -> bool:
	if _is_counter_attack_kind(attack_kind):
		return false
	if attacker == null or defender == null:
		return false
	return SquadronKeywordRuleHelper.get_keyword_value(
			defender, SquadronKeywordRuleHelper.KEYWORD_COUNTER) > 0


## Validates Counter roll commands against the locked attack-flow payload.
## Rules Reference: RRG "Squadron Keywords" — Counter rolls blue dice
## equal to the keyword value against the triggering squadron.
func validate_counter_roll(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = _flow_payload(game_state)
	var command_counter: bool = \
			SquadronKeywordRuleHelper.is_counter_attack_payload(command.payload)
	var flow_counter: bool = \
			SquadronKeywordRuleHelper.is_counter_attack_payload(flow_payload)
	if not command_counter and not flow_counter:
		return _allow()
	if not command_counter or not flow_counter:
		return _deny(REJECTION_REASON)
	if command.player_index != int(flow_payload.get("attacker_player", -1)):
		return _deny(REJECTION_REASON)
	if not _matching_roll_identity(flow_payload, command.payload):
		return _deny(REJECTION_REASON)
	var expected_pool: Dictionary = _expected_counter_pool(
			_counter_attacker(game_state, flow_payload))
	if expected_pool.is_empty():
		return _deny(REJECTION_REASON)
	if not _pool_matches(command.payload.get("dice_pool", {}), expected_pool):
		return _deny(REJECTION_REASON)
	if not _pool_matches(flow_payload.get("dice_pool", {}), expected_pool):
		return _deny(REJECTION_REASON)
	return _allow()


## Validates the optional Counter choice marker against the published flow.
## Rules Reference: RRG "Squadron Keywords" — Counter may be accepted or
## skipped only by the squadron owner with the pending Counter attack.
func validate_counter_choice(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = _flow_payload(game_state)
	if not bool(flow_payload.get(PAYLOAD_AVAILABLE, false)):
		return _deny("Counter: no Counter choice is pending.")
	var controller: int = int(flow_payload.get(PAYLOAD_CONTROLLER_PLAYER, -1))
	if command.player_index != controller:
		return _deny("Counter: choice belongs to the Counter squadron owner.")
	if not bool(command.payload.get("accepted", false)):
		return _allow()
	return _validate_accepted_counter_choice(game_state, flow_payload, command)


## Projects a Counter choice when the flow payload says one is pending.
func project_counter_affordance(_state: GameState,
		flow: InteractionFlow,
		viewer_player: int) -> Dictionary:
	if flow == null or not bool(flow.payload.get(PAYLOAD_AVAILABLE, false)):
		return {}
	var controller: int = int(flow.payload.get(PAYLOAD_CONTROLLER_PLAYER, -1))
	if viewer_player >= 0 and viewer_player != controller:
		return {}
	return SquadronKeywordRuleHelper.make_counter_attack_affordance(
			RULE_ID, controller,
			flow.payload.get(PAYLOAD_DICE_POOL, {}), PROMPT)


func _flow_payload(game_state: GameState) -> Dictionary:
	if game_state.interaction_flow == null:
		return {}
	return game_state.interaction_flow.payload


func _matching_roll_identity(flow_payload: Dictionary,
		command_payload: Dictionary) -> bool:
	if str(flow_payload.get("attacker_kind", "")) != "squadron":
		return false
	if str(flow_payload.get("target_kind", "")) != "squadron":
		return false
	if str(command_payload.get("attacker_kind", "")) != "squadron":
		return false
	if str(command_payload.get("target_kind", "")) != "squadron":
		return false
	var keys: Array[String] = ["attacker_player", "attacker_squadron_index",
			"defender_player", "target_squadron_index"]
	for key: String in keys:
		if int(command_payload.get(key, -999)) \
				!= int(flow_payload.get(key, -999)):
			return false
	return true


func _counter_attacker(game_state: GameState,
		flow_payload: Dictionary) -> SquadronInstance:
	var owner: int = int(flow_payload.get("attacker_player", -1))
	var squadron_index: int = int(
			flow_payload.get("attacker_squadron_index", -1))
	return game_state.get_squadron(owner, squadron_index)


func _counter_choice_attacker(game_state: GameState,
		flow_payload: Dictionary) -> SquadronInstance:
	var owner: int = int(flow_payload.get("counter_attacker_player", -1))
	var squadron_index: int = int(flow_payload.get(
			"counter_attacker_squadron_index", -1))
	return game_state.get_squadron(owner, squadron_index)


func _validate_accepted_counter_choice(game_state: GameState,
		flow_payload: Dictionary,
		command: GameCommand) -> Dictionary:
	var attacker: SquadronInstance = _counter_choice_attacker(
			game_state, flow_payload)
	var expected_pool: Dictionary = _expected_counter_pool(attacker)
	if expected_pool.is_empty():
		return _deny("Counter: squadron has no Counter dice.")
	if not _pool_matches(flow_payload.get(PAYLOAD_DICE_POOL, {}), expected_pool):
		return _deny(REJECTION_REASON)
	if not _pool_matches(command.payload.get(PAYLOAD_DICE_POOL, {}), expected_pool):
		return _deny(REJECTION_REASON)
	return _allow()


func _expected_counter_pool(attacker: SquadronInstance) -> Dictionary:
	var dice_count: int = SquadronKeywordRuleHelper.get_keyword_value(
			attacker, SquadronKeywordRuleHelper.KEYWORD_COUNTER)
	if dice_count <= 0:
		return {}
	return {"BLUE": dice_count}


static func _is_counter_attack_kind(attack_kind: String) -> bool:
	return SquadronKeywordRuleHelper.attack_kind_from_payload({
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND: attack_kind,
	}) == SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER


func _pool_matches(raw_pool: Variant, expected_pool: Dictionary) -> bool:
	return _normalised_pool(raw_pool) == expected_pool


func _normalised_pool(raw_pool: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw_pool is Dictionary:
		return result
	var pool: Dictionary = raw_pool as Dictionary
	for key: Variant in pool.keys():
		var colour_key: String = str(key).to_upper()
		var count: int = int(pool[key])
		if count > 0:
			result[colour_key] = count
	return result


func _allow() -> Dictionary:
	return {"allowed": true, "reason": ""}


func _deny(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}

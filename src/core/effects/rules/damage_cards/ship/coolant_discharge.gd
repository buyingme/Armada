## Coolant Discharge
##
## Static rule hook for the Coolant Discharge damage card.
## Rules Reference: Damage Card "Coolant Discharge" — "You can only
## perform 1 attack against a ship each round."
class_name CoolantDischarge
extends RefCounted


const RULE_ID: String = "damage_card.coolant_discharge"
const EFFECT_ID: String = "coolant_discharge"
const COMMAND_PUBLISH_ATTACK_FLOW: String = "publish_attack_flow"
const REJECTION_REASON: String = \
		"Coolant Discharge: this ship already attacked a ship this round."

static var _rule_instance: CoolantDischarge = null


## Registers ship-target blocker and publish-flow safety validator hooks.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = CoolantDischarge.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				RuleSurface.TARGET_ATTACK_TARGET,
				Callable(_rule_instance, "block_attack_target")),
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				COMMAND_PUBLISH_ATTACK_FLOW,
				Callable(_rule_instance, "validate_attack_flow_publish")),
	])


## Returns blocker metadata when a damaged ship has already attacked a ship.
## [param context] must carry `attacker`, target identity, and attack count.
func block_attack_target(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var attacker: ShipInstance = context.attacker as ShipInstance
	if attacker == null or not _has_coolant_discharge(attacker):
		return _not_blocked()
	if not _target_is_ship(context):
		return _not_blocked()
	if _ship_target_attack_count(context) >= 1:
		return _blocked(REJECTION_REASON)
	return _not_blocked()


## Rejects direct attack-flow publications for blocked ship targets.
func validate_attack_flow_publish(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = command.payload.get("flow_payload", {})
	if str(flow_payload.get("target_kind", "")) != "ship":
		return _allow()
	var attacker: ShipInstance = _published_attacker(game_state, flow_payload)
	if attacker == null or not _has_coolant_discharge(attacker):
		return _allow()
	if game_state.get_ship_target_attack_count(attacker) < 1:
		return _allow()
	return _deny(REJECTION_REASON)


func _target_is_ship(context: EffectContext) -> bool:
	if context.defender is ShipInstance:
		return true
	return str(context.get_meta_value("target_kind", "")) == "ship"


func _ship_target_attack_count(context: EffectContext) -> int:
	var direct: Variant = context.get_meta_value(
			"ship_target_attacks_this_round", null)
	if direct != null:
		return int(direct)
	return int(context.get_meta_value("ship_attacks_this_round", 0))


func _published_attacker(game_state: GameState,
		flow_payload: Dictionary) -> ShipInstance:
	if str(flow_payload.get("attacker_kind", "")) != "ship":
		return null
	var owner: int = int(flow_payload.get("attacker_player", -1))
	var ship_index: int = int(flow_payload.get("attacker_ship_index", -1))
	return game_state.get_ship(owner, ship_index)


func _has_coolant_discharge(ship: ShipInstance) -> bool:
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

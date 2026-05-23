## Blinded Gunners
##
## Static rule hook for the Blinded Gunners damage card.
## Rules Reference: Damage Card "Blinded Gunners" — "While attacking,
## you cannot spend accuracy icons."
class_name BlindedGunners
extends RefCounted


const RULE_ID: String = "damage_card.blinded_gunners"
const EFFECT_ID: String = "blinded_gunners"
const COMMAND_PUBLISH_ATTACK_FLOW: String = "publish_attack_flow"
const REJECTION_REASON: String = \
		"Blinded Gunners: this ship cannot spend accuracy icons."

static var _rule_instance: BlindedGunners = null


## Registers accuracy-spend blocker and publish-flow safety validator hooks.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = BlindedGunners.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_MODIFY,
				RuleSurface.TARGET_ACCURACY_SPEND,
				Callable(_rule_instance, "block_accuracy_spend")),
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
				COMMAND_PUBLISH_ATTACK_FLOW,
				Callable(_rule_instance, "validate_attack_flow_publish")),
	])


## Returns blocker metadata when the attacker cannot spend accuracy icons.
func block_accuracy_spend(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var attacker: ShipInstance = context.attacker as ShipInstance
	if attacker != null and _has_blinded_gunners(attacker):
		return _blocked(REJECTION_REASON)
	return _not_blocked()


## Rejects direct defense-step payloads that publish accuracy-locked tokens.
func validate_attack_flow_publish(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = command.payload.get("flow_payload", {})
	if _locked_tokens(flow_payload).is_empty():
		return _allow()
	var attacker: ShipInstance = _published_attacker(game_state, flow_payload)
	if attacker == null or not _has_blinded_gunners(attacker):
		return _allow()
	return _deny(REJECTION_REASON)


func _locked_tokens(flow_payload: Dictionary) -> Array:
	var raw_tokens: Variant = flow_payload.get("locked_tokens", [])
	if raw_tokens is Array:
		return raw_tokens as Array
	return []


func _published_attacker(game_state: GameState,
		flow_payload: Dictionary) -> ShipInstance:
	if str(flow_payload.get("attacker_kind", "")) != "ship":
		return null
	var owner: int = int(flow_payload.get("attacker_player", -1))
	var ship_index: int = int(flow_payload.get("attacker_ship_index", -1))
	return game_state.get_ship(owner, ship_index)


func _has_blinded_gunners(ship: ShipInstance) -> bool:
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

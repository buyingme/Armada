## Depowered Armament
##
## Static rule hook for the Depowered Armament damage card.
## Rules Reference: Damage Card "Depowered Armament" — "You cannot attack
## at long range."
class_name DepoweredArmament
extends RefCounted


const RULE_ID: String = "damage_card.depowered_armament"
const EFFECT_ID: String = "depowered_armament"
const COMMAND_PUBLISH_ATTACK_FLOW: String = "publish_attack_flow"
const TARGET_ATTACK_TARGET: String = "attack_target"
const REJECTION_REASON: String = \
		"Depowered Armament: this ship cannot attack at long range."

static var _rule_instance: DepoweredArmament = null


## Registers attack-target blocker and publish-flow safety validator hooks.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = DepoweredArmament.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				TARGET_ATTACK_TARGET,
				Callable(_rule_instance, "block_attack_target")),
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				COMMAND_PUBLISH_ATTACK_FLOW,
				Callable(_rule_instance, "validate_attack_flow_publish")),
	])


## Returns blocker metadata for attack-target eligibility.
## [param context] must carry `attacker` and `range_band`.
func block_attack_target(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var attacker: ShipInstance = context.attacker as ShipInstance
	if attacker == null or not _has_depowered_armament(attacker):
		return _not_blocked()
	if context.range_band == Constants.RANGE_BAND_LONG:
		return _blocked(REJECTION_REASON)
	return _not_blocked()


## Rejects direct attack-flow publications for long-range blocked targets.
func validate_attack_flow_publish(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = command.payload.get("flow_payload", {})
	if str(flow_payload.get("range_band", "")) != Constants.RANGE_BAND_LONG:
		return _allow()
	var attacker: ShipInstance = _published_attacker(game_state, flow_payload)
	if attacker == null or not _has_depowered_armament(attacker):
		return _allow()
	return _deny(REJECTION_REASON)


func _published_attacker(game_state: GameState,
		flow_payload: Dictionary) -> ShipInstance:
	if str(flow_payload.get("attacker_kind", "")) != "ship":
		return null
	var owner: int = int(flow_payload.get("attacker_player", -1))
	var ship_index: int = int(flow_payload.get("attacker_ship_index", -1))
	return game_state.get_ship(owner, ship_index)


func _has_depowered_armament(ship: ShipInstance) -> bool:
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

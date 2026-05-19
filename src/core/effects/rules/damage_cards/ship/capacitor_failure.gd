## Capacitor Failure
##
## Static rule hooks for the Capacitor Failure damage card.
## Rules Reference: Damage Card "Capacitor Failure" — "If a hull zone has
## no remaining shields, you cannot recover shields in it nor move shields to
## it. If that hull zone is defending, you cannot spend Redirect tokens."
class_name CapacitorFailure
extends RefCounted


const ConstantsScript := preload("res://src/autoload/constants.gd")
const RULE_ID: String = "damage_card.capacitor_failure"
const EFFECT_ID: String = "capacitor_failure"
const COMMAND_COMMIT_DEFENSE: String = "commit_defense"
const COMMAND_SPEND_DEFENSE_TOKEN: String = "spend_defense_token"
const COMMAND_SELECT_REDIRECT_ZONE: String = "select_redirect_zone"
const COMMAND_REPAIR_ACTION: String = "repair_action"
const ACTION_MOVE_SHIELDS: String = "move_shields"
const ACTION_RECOVER_SHIELDS: String = "recover_shields"
const TARGET_DEFENSE_TOKEN_SPEND: String = "defense_token_spend"
const TARGET_REPAIR_SHIELD: String = "repair_shield"
const REJECTION_REASON_REDIRECT: String = \
		"Capacitor Failure: Redirect tokens cannot be spent while the " \
		+ "defending hull zone has no shields."
const REJECTION_REASON_REPAIR: String = \
		"Capacitor Failure: shields cannot be recovered or moved to a hull " \
		+ "zone with no shields."

static var _rule_instance: CapacitorFailure = null


## Registers command validators and UI/blocker helpers for this multi-hook rule.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = CapacitorFailure.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
				FlowHook.ANY,
				Callable(_rule_instance, "validate_defense_command")),
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
				TARGET_DEFENSE_TOKEN_SPEND,
				Callable(_rule_instance, "block_defense_token")),
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.REPAIR_STEP,
				COMMAND_REPAIR_ACTION,
				Callable(_rule_instance, "validate_repair_action")),
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.REPAIR_STEP,
				TARGET_REPAIR_SHIELD,
				Callable(_rule_instance, "block_repair_shield")),
	])


## Validates attack defense commands against the Redirect restriction.
## Invalid payloads are allowed through so command-specific validation can
## produce the canonical rejection reason.
func validate_defense_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	match command.command_type:
		COMMAND_SPEND_DEFENSE_TOKEN:
			return _validate_spend_command(game_state, command)
		COMMAND_COMMIT_DEFENSE:
			return _validate_commit_command(game_state, command)
		COMMAND_SELECT_REDIRECT_ZONE:
			return _validate_redirect_zone_command(game_state, command)
		_:
			return _allow()


## Validates repair commands against the no-shield recovery/move restriction.
## Invalid payloads are allowed through so command-specific validation remains
## the source of canonical payload errors.
func validate_repair_action(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var ship: ShipInstance = _get_repair_ship(game_state, command)
	if ship == null or not _has_capacitor_failure(ship):
		return _allow()
	var target_zone: String = _repair_target_zone(command)
	if target_zone.is_empty() or not ship.current_shields.has(target_zone):
		return _allow()
	if int(ship.current_shields.get(target_zone, 0)) <= 0:
		return _deny(REJECTION_REASON_REPAIR)
	return _allow()


## Returns blocker metadata for defense-token UI eligibility.
## [param context] must carry `defender`, `metadata.token_type`, and the
## defending zone's current `metadata.target_zone_shields` value.
func block_defense_token(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var ship: ShipInstance = context.defender as ShipInstance
	if ship == null or not _has_capacitor_failure(ship):
		return _not_blocked()
	var token_type: int = int(context.get_meta_value("token_type", -1))
	if token_type != Constants.DefenseToken.REDIRECT:
		return _not_blocked()
	var zone_shields: int = int(context.get_meta_value(
			"target_zone_shields", 1))
	if zone_shields <= 0:
		return _blocked(REJECTION_REASON_REDIRECT)
	return _not_blocked()


## Returns blocker metadata for repair shield-action UI eligibility.
## [param context] must carry `metadata.ship` and the target zone's current
## `metadata.target_zone_shields` value.
func block_repair_shield(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var ship: ShipInstance = context.get_meta_value("ship", null) as ShipInstance
	if ship == null or not _has_capacitor_failure(ship):
		return _not_blocked()
	var zone_shields: int = int(context.get_meta_value(
			"target_zone_shields", 1))
	if zone_shields <= 0:
		return _blocked(REJECTION_REASON_REPAIR)
	return _not_blocked()


func _validate_spend_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	var ship: ShipInstance = _get_command_ship(game_state, command)
	if ship == null:
		return _allow()
	var token_index: int = int(command.payload.get("token_index", -1))
	return _validate_token_index(game_state, ship, token_index)


func _validate_commit_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	var ship: ShipInstance = _get_command_ship(game_state, command)
	if ship == null:
		return _allow()
	var selected: Array = command.payload.get("selected_indices", []) as Array
	for raw_index: Variant in selected:
		var result: Dictionary = _validate_token_index(
				game_state, ship, int(raw_index))
		if not bool(result.get("allowed", true)):
			return result
	return _allow()


func _validate_redirect_zone_command(game_state: GameState,
		command: GameCommand) -> Dictionary:
	var ship: ShipInstance = _get_command_ship(game_state, command)
	if ship == null or not _has_capacitor_failure(ship):
		return _allow()
	if _defending_zone_has_no_shields(game_state, ship):
		return _deny(REJECTION_REASON_REDIRECT)
	return _allow()


func _validate_token_index(game_state: GameState,
		ship: ShipInstance,
		token_index: int) -> Dictionary:
	if not _has_token(ship, token_index):
		return _allow()
	if not _has_capacitor_failure(ship):
		return _allow()
	if _token_type(ship, token_index) != Constants.DefenseToken.REDIRECT:
		return _allow()
	if _defending_zone_has_no_shields(game_state, ship):
		return _deny(REJECTION_REASON_REDIRECT)
	return _allow()


func _get_command_ship(game_state: GameState,
		command: GameCommand) -> ShipInstance:
	var ship_index: int = int(command.payload.get("ship_index", -1))
	return game_state.get_ship(command.player_index, ship_index)


func _get_repair_ship(game_state: GameState,
		command: GameCommand) -> ShipInstance:
	var owner: int = int(command.payload.get("owner_player", -1))
	var ship_index: int = int(command.payload.get("ship_index", -1))
	return game_state.get_ship(owner, ship_index)


func _repair_target_zone(command: GameCommand) -> String:
	var action: String = command.payload.get("action_type", "") as String
	match action:
		ACTION_MOVE_SHIELDS:
			return command.payload.get("to_zone", "") as String
		ACTION_RECOVER_SHIELDS:
			return command.payload.get("zone", "") as String
		_:
			return ""


func _defending_zone_has_no_shields(game_state: GameState,
		ship: ShipInstance) -> bool:
	var zone: int = _defending_zone(game_state, ship)
	if zone < 0:
		return false
	var zone_key: String = ConstantsScript.hull_zone_to_string(
			zone as Constants.HullZone)
	return int(ship.current_shields.get(zone_key, 1)) <= 0


func _defending_zone(game_state: GameState,
		ship: ShipInstance) -> int:
	if game_state.interaction_flow == null:
		return -1
	var payload: Dictionary = game_state.interaction_flow.payload
	if not _flow_targets_ship(game_state, ship, payload):
		return -1
	return int(payload.get("defender_zone", -1))


func _flow_targets_ship(game_state: GameState,
		ship: ShipInstance,
		payload: Dictionary) -> bool:
	if not payload.has("defender_player") \
			or not payload.has("defender_ship_index"):
		return true
	var defender_player: int = int(payload.get("defender_player", -1))
	var defender_index: int = int(payload.get("defender_ship_index", -1))
	return defender_player == ship.owner_player \
			and defender_index == game_state.find_ship_index(ship)


func _has_token(ship: ShipInstance, token_index: int) -> bool:
	return token_index >= 0 and token_index < ship.defense_tokens.size()


func _token_type(ship: ShipInstance, token_index: int) -> int:
	return int((ship.defense_tokens[token_index] as Dictionary).get("type", -1))


func _has_capacitor_failure(ship: ShipInstance) -> bool:
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
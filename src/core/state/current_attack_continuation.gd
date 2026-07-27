## Derives deterministic current-attack follow-ups from authoritative state.
##
## This stateless helper is invoked only from CommandProcessor's existing
## post-success/deferred-follow-up seam. It never reads scene state,
## InteractionFlow, network ownership, or presentation-local references.
class_name CurrentAttackContinuation
extends RefCounted


const MODE_LIVE_AUTHORITY: String = "live_authority"
const MODE_NETWORK_MIRROR: String = "network_mirror"
const MODE_REPLAY: String = "replay"
const MODE_RECONSTRUCTION: String = "reconstruction"

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_CONTINUATION: String = "continuation"


## Returns no command or exactly one deterministic semantic follow-up.
## Passive modes inspect the same accepted state but never synthesize commands.
static func process_successful_command(game_state: GameState,
		command: GameCommand,
		result: Dictionary,
		execution_mode: String) -> Dictionary:
	if execution_mode not in [
		MODE_LIVE_AUTHORITY,
		MODE_NETWORK_MIRROR,
		MODE_REPLAY,
		MODE_RECONSTRUCTION,
	]:
		return _failure("Unknown current-attack execution mode.")
	if game_state == null or command == null:
		return _success()
	var continuation: GameCommand = _derive_followup(
			game_state, command, result)
	if execution_mode != MODE_LIVE_AUTHORITY:
		continuation = null
	return _success(continuation)


static func _derive_followup(game_state: GameState,
		command: GameCommand,
		result: Dictionary) -> GameCommand:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return null
	if command.command_type in [
		"commit_accuracy",
		"commit_defense",
		"spend_defense_token",
		"select_evade_die",
		"select_redirect_zone",
		"redirect_done",
	]:
		return _derive_defense_followup(
				game_state, attack, command, result)
	if command.command_type == "resolve_damage":
		if not _post_damage_decision_pending(game_state, attack, result):
			return _build_complete_attack(attack)
	if command.command_type in ["resolve_immediate_effect", "counter_choice"] \
			and attack.stage == CurrentAttackState.STAGE_RESOLVED:
		return _build_complete_attack(attack)
	return null


static func _derive_defense_followup(game_state: GameState,
		attack: CurrentAttackState,
		command: GameCommand,
		result: Dictionary) -> GameCommand:
	match command.command_type:
		"commit_accuracy":
			if attack.stage == CurrentAttackState.STAGE_DEFENSE \
					and attack.defense_stage \
							== CurrentAttackState.DEFENSE_COMPLETE:
				return _build_resolve_damage(attack)
		"commit_defense":
			return _build_next_defense_or_damage(game_state, attack)
		"spend_defense_token":
			var token_type: int = int(result.get("token_type", -1))
			if token_type not in [
				Constants.DefenseToken.EVADE,
				Constants.DefenseToken.REDIRECT,
			]:
				return _build_next_defense_or_damage(game_state, attack)
		"select_evade_die", "redirect_done":
			return _build_next_defense_or_damage(game_state, attack)
		"select_redirect_zone":
			if bool(result.get("redirect_complete", false)):
				return _build_next_defense_or_damage(game_state, attack)
	return null


static func _build_next_defense_or_damage(game_state: GameState,
		attack: CurrentAttackState) -> GameCommand:
	if attack.stage != CurrentAttackState.STAGE_DEFENSE:
		return null
	if attack.defense_stage == CurrentAttackState.DEFENSE_COMPLETE:
		return _build_resolve_damage(attack)
	if attack.defense_stage != CurrentAttackState.DEFENSE_RESOLVING:
		return null
	var token_index: int = _next_unresolved_token(attack)
	if token_index < 0:
		return null
	var defender: RefCounted = _defender(game_state, attack)
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	if token_index >= tokens.size():
		return null
	var token: Dictionary = tokens[token_index]
	var resolver := DefenseTokenResolver.new()
	var spend_method: String = resolver.resolve_spend_method(
			"exhaust", token)
	return SpendDefenseTokenCommand.new(attack.defender_player, {
		"attack_id": attack.attack_id,
		"defender_kind": attack.defender_kind,
		"defender_index": attack.defender_index,
		"ship_index": attack.defender_index \
				if attack.defender_kind == CurrentAttackState.KIND_SHIP else -1,
		"token_index": token_index,
		"expected_token_type": int(token.get("type", -1)),
		"spend_method": spend_method,
	})


static func _build_resolve_damage(
		attack: CurrentAttackState) -> GameCommand:
	return ResolveDamageCommand.new(attack.attacker_player, {
		"attack_id": attack.attack_id,
	})


static func _build_complete_attack(
		attack: CurrentAttackState) -> GameCommand:
	return CompleteAttackCommand.new(attack.attacker_player, {
		"attack_id": attack.attack_id,
	})


static func _post_damage_decision_pending(game_state: GameState,
		attack: CurrentAttackState,
		result: Dictionary) -> bool:
	if _counter_decision_pending(game_state, attack):
		return true
	for raw_card: Variant in result.get("damage_cards", []) as Array:
		if not raw_card is Dictionary:
			continue
		var card: DamageCard = DamageCard.deserialize(raw_card as Dictionary)
		if card != null and card.is_faceup and card.is_immediate():
			return true
	return false


static func _counter_decision_pending(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	if attack.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or attack.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return false
	return CounterKeyword.is_counter_trigger_available(
			attack.attack_kind,
			game_state.get_squadron(
					attack.attacker_player, attack.attacker_index),
			game_state.get_squadron(
					attack.defender_player, attack.defender_index))


static func _next_unresolved_token(attack: CurrentAttackState) -> int:
	var resolved: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in attack.committed_defense_tokens:
		if not resolved.has(token_index):
			return token_index
	return -1


static func _defender(game_state: GameState,
		attack: CurrentAttackState) -> RefCounted:
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(
				attack.defender_player, attack.defender_index)
	return game_state.get_squadron(
			attack.defender_player, attack.defender_index)


static func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


static func _success(
		continuation: GameCommand = null) -> Dictionary:
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_CONTINUATION: continuation,
	}


static func _failure(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
		KEY_CONTINUATION: null,
	}

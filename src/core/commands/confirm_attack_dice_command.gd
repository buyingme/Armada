## ConfirmAttackDiceCommand
##
## Commits canonical attack dice after optional attack modifiers are final.
##
## Rules Reference: RRG "Attack", Steps 3-5, p.2.
class_name ConfirmAttackDiceCommand
extends GameCommand


const TYPE: String = "confirm_attack_dice"
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return ConfirmAttackDiceCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates that the attack controller may confirm the current dice result.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	var payload_attack_id: String = str(payload.get("attack_id",
			payload.get(TimingWindowOrchestrator.COMMAND_KEY_SOURCE_ID, "")))
	if attack.attack_id != payload_attack_id:
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY:
		return "Current attack is not in Attack Modify."
	if player_index != attack.attacker_player:
		return "Attack dice confirmation belongs to player %d." \
				% attack.attacker_player
	if attack.dice_results.is_empty():
		return "No attack dice results to confirm."
	if attack.cf_token_resolution == CurrentAttackState.RESOLUTION_PENDING:
		return "Concentrate Fire token choice is unresolved."
	if game_state.timing_window_state.active:
		return _validate_active_continuation(game_state, attack)
	return _validate_inactive_direct_context(attack)


## Echoes the attack identity for the attack pipeline reaction.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var replacement: CurrentAttackState = attack.with_patch({
		"stage": CurrentAttackState.STAGE_ACCURACY,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	var cleared: Array[String] = H9_RULE.clear_attack_guards(
			game_state, attack.attack_id)
	return {
		"attack_id": attack.attack_id,
		"dice_results": attack.dice_results,
		"h9_cleared_runtime_upgrade_ids": cleared,
	}


func _validate_inactive_direct_context(attack: CurrentAttackState) -> String:
	if attack.attacker_kind != CurrentAttackState.KIND_SQUADRON:
		return "Ship Attack Modify requires a matching active timing lifecycle."
	for key: String in [
		TimingWindowOrchestrator.COMMAND_KEY_TIMING_WINDOW_ID,
		TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID,
		TimingWindowOrchestrator.COMMAND_KEY_SOURCE_ID,
		TimingWindowOrchestrator.COMMAND_KEY_SOURCE_TYPE,
	]:
		if payload.has(key):
			return "Inactive confirmation cannot carry timing lifecycle context."
	return ""


func _validate_active_continuation(game_state: GameState,
		attack: CurrentAttackState) -> String:
	var timing: TimingWindowState = game_state.timing_window_state
	if timing.status != TimingWindowState.STATUS_CLOSING:
		return "Timing lifecycle is not awaiting continuation."
	if timing.timing_window_id != TimingWindowDefinitions.ATTACK_MODIFY \
			or str(payload.get(
					TimingWindowOrchestrator.COMMAND_KEY_TIMING_WINDOW_ID, "")) \
					!= timing.timing_window_id:
		return "Timing-window type does not match Attack Modify."
	if str(payload.get(TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID, "")) \
			!= timing.lifecycle_id:
		return "Stale timing-window lifecycle identity."
	if str(payload.get(TimingWindowOrchestrator.COMMAND_KEY_SOURCE_ID, "")) \
			!= attack.attack_id \
			or str(payload.get(
					TimingWindowOrchestrator.COMMAND_KEY_SOURCE_TYPE, "")) \
					!= "current_attack":
		return "Timing continuation source does not match the current attack."
	var context: Dictionary = timing.continuation_context
	if str(context.get(TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
			!= attack.attack_id \
			or int(context.get(
					TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER, -1)) \
					!= attack.attacker_player \
			or timing.controller_player != attack.attacker_player:
		return "Timing continuation context conflicts with the current attack."
	return ""

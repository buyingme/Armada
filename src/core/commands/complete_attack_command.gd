## Completes and retires one resolved individual attack.
class_name CompleteAttackCommand
extends GameCommand

const TYPE: String = "complete_attack"
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return CompleteAttackCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_RESOLVED \
			or attack.damage_stage != CurrentAttackState.DAMAGE_RESOLVED:
		return "Current attack has not resolved damage."
	if player_index != attack.attacker_player:
		return "Attack completion belongs to the attacker."
	if game_state.timing_window_state.active:
		return "Cannot complete while a timing window is active."
	return ""

func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var attack_id: String = attack.attack_id
	if not game_state.set_current_attack_state(CurrentAttackState.inactive()):
		return {}
	var cleared: Array[String] = ECM_SCRIPT.clear_attack_state(
			game_state, attack_id)
	return {
		"attack_id": attack_id,
		"completed": true,
		"ecm_cleared_runtime_upgrade_ids": cleared,
	}

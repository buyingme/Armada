## Completes and retires one resolved individual attack.
class_name CompleteAttackCommand
extends GameCommand

const TYPE: String = "complete_attack"
const CONTINUATION_SQUADRON: String = "squadron_target"
const CONTINUATION_NORMAL_ATTACK: String = "normal_attack"
const CONTINUATION_ATTACK_STEP_COMPLETE: String = "attack_step_complete"
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")

var _log: GameLogger = GameLogger.new("CompleteAttackCommand")

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
	var ship: ShipInstance = _tracked_attacker_ship(game_state, attack)
	if ship != null:
		_log.debug("Complete before retiring individual attack: %s" %
				JSON.stringify(ship.attack_progress_snapshot()))
	var exhaust_squadron_iteration: bool = ship != null \
			and ship.anti_squadron_attack_zone >= 0 \
			and not _has_remaining_squadron_target(game_state, attack, ship)
	if not game_state.set_current_attack_state(CurrentAttackState.inactive()):
		return {}
	if exhaust_squadron_iteration:
		ship.end_anti_squadron_attack()
	var cleared: Array[String] = ECM_SCRIPT.clear_attack_state(
			game_state, attack_id)
	var result: Dictionary = {
		"attack_id": attack_id,
		"completed": true,
		"ecm_cleared_runtime_upgrade_ids": cleared,
	}
	if ship != null:
		result["continuation"] = _derive_ship_continuation(ship)
		_log.debug("Complete continuation=%s progress=%s" % [
			str(result["continuation"]),
			JSON.stringify(ship.attack_progress_snapshot()),
		])
	return result


func _tracked_attacker_ship(game_state: GameState,
		attack: CurrentAttackState) -> ShipInstance:
	if attack.attack_kind != SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP:
		return null
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	return ship if ship != null and ship.attack_step_active else null


func _has_remaining_squadron_target(game_state: GameState,
		attack: CurrentAttackState, ship: ShipInstance) -> bool:
	if attack.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return false
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(
					game_state, attack.attacker_player, attack.attacker_index):
		if int(candidate.get("attacker_zone", -1)) \
				!= ship.anti_squadron_attack_zone \
				or str(candidate.get("target_kind", "")) \
						!= CurrentAttackState.KIND_SQUADRON:
			continue
		var target_owner: int = int(candidate.get("target_owner", -1))
		var target_index: int = int(candidate.get("target_index", -1))
		var squadron: SquadronInstance = game_state.get_squadron(
				target_owner, target_index)
		if squadron == null or squadron.is_destroyed() \
				or ship.has_anti_squadron_target(target_owner, target_index):
			continue
		return true
	return false


func _derive_ship_continuation(ship: ShipInstance) -> String:
	if ship.anti_squadron_attack_zone >= 0:
		return CONTINUATION_SQUADRON
	if ship.committed_attack_count < 2:
		return CONTINUATION_NORMAL_ATTACK
	return CONTINUATION_ATTACK_STEP_COMPLETE

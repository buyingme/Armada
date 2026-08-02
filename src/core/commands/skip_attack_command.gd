## SkipAttackCommand
##
## Records that the active player chose to skip (pass on) an attack
## or an attack sub-step during the Ship Phase.
## This is a flow-control command — it performs no state mutation but
## is recorded so replays faithfully reproduce the player's choices.
##
## Payload:
##   "reason" — optional human-readable reason for the skip
##              (e.g. "no_targets", "voluntary", "squadron_done").
##   "ship_index" — required stable attacker identity for "squadron_done".
##
## Rules Reference: "Attack", p.2 —
## "A ship can perform up to two attacks during its activation."
class_name SkipAttackCommand
extends GameCommand


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const TERMINAL_REASONS: Array[String] = [
	"cancelled",
	"flow_terminated",
]


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("skip_attack", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SkipAttackCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "skip_attack", p_payload)


## Validates that skipping is legal.
## Allowed in both Ship and Squadron phases (squadrons may skip attacks).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var attack: CurrentAttackState = game_state.current_attack_state
	if not attack.active:
		if str(payload.get("reason", "")) == "squadron_done":
			var ship: ShipInstance = _squadron_iteration_ship(game_state)
			if ship == null:
				return "No active anti-squadron continuation."
		return ""
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if player_index != attack.attacker_player:
		return "Attack cancellation belongs to the attacker."
	if not TERMINAL_REASONS.has(str(payload.get("reason", ""))):
		return "Invalid active-attack terminal reason."
	if game_state.timing_window_state.active:
		var context: Dictionary = game_state.timing_window_state.continuation_context
		if str(context.get(TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
				!= attack.attack_id \
				or str(payload.get(
						TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID, "")) \
						!= game_state.timing_window_state.lifecycle_id:
			return "Timing lifecycle does not match the current attack."
	return ""


## Retires an active cancelled attack, or records a non-attack skip.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var attack_id: String = attack.attack_id
	var cleared: Array[String] = []
	var continuation: String = ""
	if attack.active:
		if not game_state.set_current_attack_state(CurrentAttackState.inactive()):
			return {}
		if game_state.timing_window_state.active:
			var cancelled: Dictionary = TimingWindowOrchestrator.cancel_window(
					game_state, game_state.timing_window_state.lifecycle_id)
			if not bool(cancelled.get(TimingWindowOrchestrator.KEY_OK, false)):
				game_state.set_current_attack_state(attack)
				return {}
		cleared = ECM_SCRIPT.clear_attack_state(game_state, attack_id)
	elif str(payload.get("reason", "")) == "squadron_done":
		var ship: ShipInstance = _squadron_iteration_ship(game_state)
		if ship == null:
			return {}
		ship.end_anti_squadron_attack()
		continuation = CompleteAttackCommand.CONTINUATION_NORMAL_ATTACK \
				if ship.committed_attack_count < 2 \
				else CompleteAttackCommand.CONTINUATION_ATTACK_STEP_COMPLETE
	var result: Dictionary = {
		"attack_id": attack_id,
		"skipped": true,
		"reason": payload.get("reason", "voluntary"),
		"ecm_cleared_runtime_upgrade_ids": cleared,
	}
	if not continuation.is_empty():
		result["continuation"] = continuation
	return result


func _squadron_iteration_ship(game_state: GameState) -> ShipInstance:
	if typeof(payload.get("ship_index")) != TYPE_INT:
		return null
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload.get("ship_index", -1)))
	if ship == null or not ship.attack_step_active \
			or ship.anti_squadron_attack_zone < 0:
		return null
	return ship

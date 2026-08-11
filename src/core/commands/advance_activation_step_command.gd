## AdvanceActivationStepCommand
##
## Records a ship-activation step transition in network mode so both peers can
## mirror modal progress from authoritative command results.
##
## This command coordinates the canonical enclosing activation step and its
## activation-local ship state for replay/network parity.
##
## Payload:
##   "ship_index" - index of the activating ship in the player's fleet.
##   "step_id" - canonical interaction step identifier (e.g. "repair_step").
##
## Rules Reference: G4 Network Plan §G4.6.6 T1a C9b.
class_name AdvanceActivationStepCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")

var _log: GameLogger = GameLogger.new("AdvanceActivationStepCommand")


const _ALLOWED_STEP_IDS: Array[String] = [
	"squadron_step",
	"repair_step",
	"attack_step",
	"maneuver_step",
	"activation_done",
]


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("advance_activation_step", func(player: int,
			pl: Dictionary) -> GameCommand:
		return AdvanceActivationStepCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "advance_activation_step", p_payload)


## Validates that activation-step progression is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.is_destroyed():
		return "Ship is destroyed."
	if ship.activated_this_round:
		return "Ship already activated this round."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	var identity: String = str(payload.get("ship_activation_identity", ""))
	if identity.is_empty() or identity != ship.ship_activation_identity:
		return "Stale or missing ship activation identity."
	var step_id: String = payload.get("step_id", "")
	if not (step_id in _ALLOWED_STEP_IDS):
		return "Invalid step_id."
	if step_id == "squadron_step":
		if ship.squadron_command_opportunity_disposition \
				!= ShipInstance.ACTIVATION_DISPOSITION_UNREACHED:
			return "Squadron-command opportunity was already reached."
		if SquadronCommandResolver.authoritative_capacity(ship) <= 0:
			return "No Squadron-command opportunity is available."
	elif step_id == "repair_step":
		if ship.squadron_command_opportunity_disposition \
				not in [ShipInstance.ACTIVATION_DISPOSITION_UNREACHED,
						ShipInstance.ACTIVATION_DISPOSITION_OPEN]:
			return "Squadron-command opportunity is already consumed."
		if game_state.get_active_squadron_activation() != null:
			return "A commanded squadron activation is still active."
	elif step_id == "attack_step":
		if ship.attack_step_active:
			return "Ship Attack-step opportunity is already active."
	elif step_id == "maneuver_step":
		if not ship.attack_step_active:
			return "Ship Attack-step opportunity is not active."
		if game_state.current_attack_state.active:
			return "A current attack is still active."
		if ship.maneuver_opportunity_disposition \
				!= ShipInstance.ACTIVATION_DISPOSITION_UNREACHED:
			return "Maneuver opportunity was already reached."
	return ""


## Advances one authoritative, purpose-specific ship-activation opportunity.
func execute(game_state: GameState) -> Dictionary:
	var step_id_str: String = payload.get("step_id", "")
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload.get("ship_index", -1)))
	if ship == null:
		return {}
	var identity: String = str(payload.get("ship_activation_identity", ""))
	var boundary_before: Dictionary = ship.ship_activation_boundary_snapshot()
	var progress_before: Dictionary = ship.attack_progress_snapshot() \
			if ship != null else {}
	var transition_ok: bool = true
	match step_id_str:
		"squadron_step":
			transition_ok = ship.open_squadron_command_opportunity(identity)
		"repair_step":
			if ship.squadron_command_opportunity_disposition \
					== ShipInstance.ACTIVATION_DISPOSITION_OPEN:
				transition_ok = ship.consume_open_squadron_command_opportunity(
						identity)
			else:
				# Reaching Repair directly is the existing semantic pass/unavailable
				# boundary for an unexercised Squadron command.
				transition_ok = ship.consume_unreached_squadron_command_opportunity(
						identity, true)
		"attack_step":
			ship.begin_attack_step()
		"maneuver_step":
			ship.end_attack_step()
			if ship.maneuver_opportunity_disposition \
					== ShipInstance.ACTIVATION_DISPOSITION_UNREACHED:
				transition_ok = ship.open_maneuver_opportunity(identity)
		"activation_done":
			ship.end_attack_step()
	if not transition_ok or not game_state.validate_declaration_adjacent_state():
		ship.restore_ship_activation_boundary(boundary_before)
		ship.restore_attack_progress(progress_before)
		return {}
	var step_enum: int = int(Constants.LEGACY_STEP_ID_MAP.get(
			step_id_str, Constants.InteractionStep.NONE))
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_enum as Constants.InteractionStep,
			game_state,
			{"active_player": player_index},
			Constants.Visibility.ALL,
			{"ship_index": payload.get("ship_index", -1),
				"ship_activation_identity": identity})
	if step_id_str in ["attack_step", "maneuver_step", "activation_done"]:
		_log.debug(("Activation transition '%s': progress %s -> %s; " \
				+ "projected step=%s") % [
			step_id_str,
			JSON.stringify(progress_before),
			JSON.stringify(ship.attack_progress_snapshot()) \
					if ship != null else "{}",
			str(game_state.interaction_flow.step_id),
		])
	return {
		"ship_index": payload.get("ship_index", -1),
		"step_id": step_id_str,
		"ship_activation_identity": identity,
	}

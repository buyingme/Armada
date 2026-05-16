## AdvanceActivationStepCommand
##
## Records a ship-activation step transition in network mode so both peers can
## mirror modal progress from authoritative command results.
##
## This command does not mutate [GameState] directly; it is a flow-control
## command used for replay/network timeline parity.
##
## Payload:
##   "ship_index" - index of the activating ship in the player's fleet.
##   "step_id" - canonical interaction step identifier (e.g. "repair_step").
##
## Rules Reference: G4 Network Plan §G4.6.6 T1a C9b.
class_name AdvanceActivationStepCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


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
	var step_id: String = payload.get("step_id", "")
	if not (step_id in _ALLOWED_STEP_IDS):
		return "Invalid step_id."
	return ""


## Flow-control no-op execution.
func execute(game_state: GameState) -> Dictionary:
	var step_id_str: String = payload.get("step_id", "")
	var step_enum: int = int(Constants.LEGACY_STEP_ID_MAP.get(
			step_id_str, Constants.InteractionStep.NONE))
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_enum as Constants.InteractionStep,
			game_state,
			{"active_player": player_index},
			Constants.Visibility.ALL,
			{"ship_index": payload.get("ship_index", -1)})
	return {
		"ship_index": payload.get("ship_index", -1),
		"step_id": step_id_str,
	}

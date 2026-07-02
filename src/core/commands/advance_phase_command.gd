## AdvancePhaseCommand
##
## Advances the game to the next phase within the current round.
## Mutates [member GameState.current_phase] to the next value in the
## strict phase order: COMMAND → SHIP → SQUADRON → STATUS.
##
## Does **not** handle the STATUS → COMMAND wrap-around (new round);
## that is handled by [StartRoundCommand].
##
## Payload:
##   "next_phase" — int value of the target [Constants.GamePhase].
##
## Rules Reference: "Game Round", GF-002 — strict phase order.
class_name AdvancePhaseCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")
const TARKIN_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("advance_phase", func(player: int,
			pl: Dictionary) -> GameCommand:
		return AdvancePhaseCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "advance_phase", p_payload)


## Validates that advancing the phase is legal.
## The target phase must be the next in sequence and must not wrap to
## COMMAND (that requires [StartRoundCommand]).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var target: int = payload.get("next_phase", -1)
	if target < 0:
		return "Missing next_phase."
	# STATUS → COMMAND is a new-round transition, not a phase advance.
	if game_state.current_phase == Constants.GamePhase.STATUS:
		return "Cannot advance from STATUS — use StartRoundCommand."
	var expected: int = _expected_next(game_state.current_phase)
	if target != expected:
		return "Phase %d is not the expected next phase (%d)." % [
				target, expected]
	return ""


## Sets [member GameState.current_phase] to the target phase.
## Returns {"previous_phase": int, "new_phase": int}.
func execute(game_state: GameState) -> Dictionary:
	var prev: int = int(game_state.current_phase)
	var target: int = payload.get("next_phase", prev)
	game_state.current_phase = target as Constants.GamePhase
	match target:
		Constants.GamePhase.SHIP:
			_enter_ship_phase_flow(game_state)
		Constants.GamePhase.SQUADRON:
			game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
					Constants.InteractionFlow.SQUADRON_ACTIVATION,
					Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
					game_state,
					{"active_player": game_state.initiative_player},
					Constants.Visibility.ALL)
	return {"previous_phase": prev, "new_phase": target}


static func _enter_ship_phase_flow(game_state: GameState) -> void:
	var tarkin_source: Dictionary = TARKIN_SCRIPT.find_prompt_source(game_state)
	if not tarkin_source.is_empty():
		game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
				game_state,
				{"controller_player": int(tarkin_source.get("owner_player", -1))},
				Constants.Visibility.ALL,
				TARKIN_SCRIPT.prompt_payload(tarkin_source))
		return
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			game_state,
			{"active_player": game_state.initiative_player},
			Constants.Visibility.ALL)


## Returns the expected next phase for a given current phase.
static func _expected_next(current: Constants.GamePhase) -> int:
	match current:
		Constants.GamePhase.COMMAND:
			return int(Constants.GamePhase.SHIP)
		Constants.GamePhase.SHIP:
			return int(Constants.GamePhase.SQUADRON)
		Constants.GamePhase.SQUADRON:
			return int(Constants.GamePhase.STATUS)
		_:
			return -1

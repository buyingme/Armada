## CompleteSquadronActivationCommand
##
## Marker command for a squadron activation that finishes without a movement
## command. This covers Squadron Phase activations and ship-phase Squadron
## command activations. It replaces the old zero-distance move_squadron sync
## marker, which is not legal for engaged squadrons under Heavy rules.
##
## Rules Reference: RRG "Squadron Phase", p.12 — each player activates up
## to two unactivated squadrons.
## Rules Reference: RRG "Commands", p.4 — Squadron command.
class_name CompleteSquadronActivationCommand
extends GameCommand


const TYPE: String = "complete_squadron_activation"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return CompleteSquadronActivationCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates the referenced squadron can be marked complete this turn.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if not _is_legal_phase(game_state.current_phase):
		return "Not in Squadron or Ship Phase."
	var squadron: SquadronInstance = _get_squadron(game_state)
	if squadron == null:
		return "Squadron not found."
	return ""


## Marks the squadron activated and echoes its identity.
func execute(game_state: GameState) -> Dictionary:
	var squadron: SquadronInstance = _get_squadron(game_state)
	if squadron != null:
		squadron.activated_this_round = true
	return {"squadron_index": int(payload.get("squadron_index", -1))}


func _is_legal_phase(phase: Constants.GamePhase) -> bool:
	return phase == Constants.GamePhase.SQUADRON \
			or phase == Constants.GamePhase.SHIP


func _get_squadron(game_state: GameState) -> SquadronInstance:
	var player_state: PlayerState = game_state.get_player_state(player_index)
	if player_state == null:
		return null
	var index: int = int(payload.get("squadron_index", -1))
	if index < 0 or index >= player_state.squadrons.size():
		return null
	return player_state.squadrons[index] as SquadronInstance

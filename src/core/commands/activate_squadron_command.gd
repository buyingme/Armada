## ActivateSquadronCommand
##
## Sets a squadron as the currently activating unit during the Squadron Phase.
## Wraps [method GameManager.activate_squadron] as a serializable command.
##
## Payload:
##   "squadron_index" — index of the squadron in the player's fleet array.
##
## Rules Reference: "Squadron Phase", SQ-003 — activate a squadron.
class_name ActivateSquadronCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("activate_squadron", func(
			player: int, pl: Dictionary) -> GameCommand:
		return ActivateSquadronCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "activate_squadron", p_payload)


## Validates that squadron activation is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Not in Squadron Phase."
	var sq: SquadronInstance = _get_squadron(game_state)
	if sq == null:
		return "Squadron not found."
	if sq.is_destroyed():
		return "Squadron is destroyed."
	if sq.activated_this_round:
		return "Squadron already activated this round."
	return ""


## Marks the squadron as the activating unit.
## Returns {"squadron_index": int}.
func execute(game_state: GameState) -> Dictionary:
	# The command only validates and records — the presentation layer
	# sets GameManager._activating_squadron when the signal fires.
	return {"squadron_index": payload.get("squadron_index", -1)}


## Returns the squadron instance from the payload, or null.
func _get_squadron(game_state: GameState) -> SquadronInstance:
	var ps: PlayerState = game_state.get_player_state(player_index)
	if ps == null:
		return null
	var idx: int = payload.get("squadron_index", -1)
	if idx < 0 or idx >= ps.squadrons.size():
		return null
	return ps.squadrons[idx] as SquadronInstance

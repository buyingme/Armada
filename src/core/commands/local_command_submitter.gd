## Local command submitter — in-process, zero-latency.
##
## Delegates directly to [CommandProcessor.submit] with no serialization
## or network round-trip.  Used for hot-seat and single-player modes.
##
## G4 Network Plan: §1.5 — CommandSubmitter Strategy
class_name LocalCommandSubmitter
extends CommandSubmitter

var _match_principal_id: String = ""


func _init(match_principal_id: String = "") -> void:
	_match_principal_id = match_principal_id


## Submits the command directly to [CommandProcessor].
## Returns the execution result, or [code]{}[/code] on validation failure.
func submit(command: GameCommand) -> Dictionary:
	if GameManager.current_game_state != null \
			and GameManager.current_game_state.has_valid_match_player_control_binding() \
			and not GameManager.current_game_state.principal_controls_player(
				_match_principal_id, command.player_index):
		return {}
	return CommandProcessor.submit(command)


func submit_authoritative(command: GameCommand) -> Dictionary:
	return CommandProcessor.submit(command)


func submit_replay(command: GameCommand) -> Dictionary:
	return CommandProcessor.submit_replay(command)

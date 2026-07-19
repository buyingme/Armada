## Network host command submitter — local execution + broadcast.
##
## Used on the host (server + player) in network mode.  Executes commands
## synchronously via [CommandProcessor] (like [LocalCommandSubmitter]) and
## then broadcasts the result to all connected clients via
## [NetworkManager.handle_host_command].
##
## Returns the execution result immediately so callers in [GameManager]
## work identically to hot-seat mode.
##
## G4 Network Plan: §G4.6.5.1 — submitter swap on game start.
class_name NetworkHostCommandSubmitter
extends CommandSubmitter


## Logger for this system.
var _log: GameLogger = GameLogger.new("NetworkHostCommandSubmitter")


## Executes the command locally and broadcasts the result to clients.
## Returns the execution result (non-empty on success).
func submit(command: GameCommand) -> Dictionary:
	var result: Dictionary = CommandProcessor.submit_deferred_followups(command)
	if result.is_empty():
		_log.warn("Command [%s] rejected by validation." %
				command.command_type)
		return result
	NetworkManager.handle_host_command(command, result)
	return result


func submit_replay(command: GameCommand) -> Dictionary:
	var result: Dictionary = CommandProcessor.submit_replay_deferred_followups(
			command)
	if result.is_empty():
		_log.warn("Replay command [%s] rejected by validation." %
				command.command_type)
		return result
	NetworkManager.handle_host_command(command, result)
	return result

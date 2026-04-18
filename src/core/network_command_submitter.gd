## Network command submitter — serialize + RPC to dedicated server.
##
## Serializes the [GameCommand] and sends it to the server via
## [NetworkManager].  Returns [code]{}[/code] immediately — the client
## waits for a [code]command_result[/code] RPC from the server before
## updating its local state.
##
## G4 Network Plan: §1.5 — CommandSubmitter Strategy, §1.3.1 Client Update
class_name NetworkCommandSubmitter
extends CommandSubmitter


## True while waiting for the server's [code]command_result[/code] response.
var _awaiting: bool = false

## Logger for this system.
var _log: GameLogger = GameLogger.new("NetworkCommandSubmitter")


## Serializes and sends the command to the server.
## Always returns [code]{}[/code] — result arrives asynchronously via RPC.
func submit(command: GameCommand) -> Dictionary:
	if _awaiting:
		_log.warn("Already awaiting server response — dropping command [%s]." %
				command.command_type)
		return {}
	var data: Dictionary = command.serialize()
	NetworkManager.send_command_to_server(data)
	_awaiting = true
	return {}


## Returns [code]true[/code] when waiting for the server's response.
func is_awaiting_response() -> bool:
	return _awaiting


## Clears the awaiting flag.  Called by [GameManager] when the server's
## [code]command_result[/code] RPC is received.
func clear_awaiting() -> void:
	_awaiting = false

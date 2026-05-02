## Network command submitter — serialize + RPC to dedicated server.
##
## Serializes the [GameCommand] and sends it to the server via
## [NetworkManager].  Returns [code]{"awaiting_remote": true}[/code]
## immediately — the client waits for a [code]command_result[/code] RPC
## from the server before updating its local state.  The sentinel lets
## callers distinguish "forwarded to server, awaiting broadcast" from
## the truly-empty [code]{}[/code] that [LocalCommandSubmitter] /
## [NetworkHostCommandSubmitter] return on validation rejection.
##
## G4 Network Plan: §1.5 — CommandSubmitter Strategy, §1.3.1 Client Update
class_name NetworkCommandSubmitter
extends CommandSubmitter


## Sentinel value returned by [method submit] when the command was
## forwarded to the server and the local peer is now awaiting the
## authoritative broadcast.  Phase I6e-3.
const AWAITING_REMOTE_RESULT: Dictionary = {"awaiting_remote": true}


## True while waiting for the server's [code]command_result[/code] response.
var _awaiting: bool = false

## FIFO queue of serialized commands waiting for send while a response is
## in-flight. Prevents loss of rapid follow-up commands in network mode.
var _pending_payloads: Array[Dictionary] = []

## Logger for this system.
var _log: GameLogger = GameLogger.new("NetworkCommandSubmitter")


## Serializes and sends the command to the server.
## Always returns [constant AWAITING_REMOTE_RESULT] — real result arrives
## asynchronously via RPC.
func submit(command: GameCommand) -> Dictionary:
	var data: Dictionary = command.serialize()
	if _awaiting:
		_pending_payloads.append(data)
		_log.info("Awaiting response — queued command [%s] (%d pending)." %
				[command.command_type, _pending_payloads.size()])
		return AWAITING_REMOTE_RESULT.duplicate()
	_send_payload(data)
	return AWAITING_REMOTE_RESULT.duplicate()


## Returns [code]true[/code] when waiting for the server's response.
func is_awaiting_response() -> bool:
	return _awaiting


## Clears the awaiting flag.  Called by [GameManager] when the server's
## [code]command_result[/code] RPC is received.
func clear_awaiting() -> void:
	_awaiting = false
	_flush_next_pending()


## Sends one serialized command and marks this submitter as awaiting.
func _send_payload(payload: Dictionary) -> void:
	NetworkManager.send_command_to_server(payload)
	_awaiting = true


## Sends the next queued command, if any.
func _flush_next_pending() -> void:
	if _pending_payloads.is_empty():
		return
	var next_payload: Dictionary = _pending_payloads.pop_front()
	_send_payload(next_payload)

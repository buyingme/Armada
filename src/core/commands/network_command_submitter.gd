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

## Number of commands sent to the server whose authoritative result has not
## arrived yet. Normally this is 0 or 1; command-phase dial assignments may
## have several in flight because the sync gate intentionally holds results.
var _in_flight_count: int = 0

## Command type currently allowed to hold the awaiting slot.
var _awaiting_command_type: String = ""

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
		if _can_send_while_awaiting(command):
			_send_payload(data)
			_log.info("Awaiting held dial result - sent command [%s] (%d in flight)." %
					[command.command_type, _in_flight_count])
			return AWAITING_REMOTE_RESULT.duplicate()
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
	if _in_flight_count > 0:
		_in_flight_count -= 1
	if _in_flight_count > 0:
		return
	_awaiting = false
	_awaiting_command_type = ""
	_flush_next_pending()


## Sends one serialized command and marks this submitter as awaiting.
func _send_payload(payload: Dictionary) -> void:
	NetworkManager.send_command_to_server(payload)
	_awaiting = true
	_in_flight_count += 1
	_awaiting_command_type = str(payload.get("type", ""))


## Sends the next queued command, if any.
func _flush_next_pending() -> void:
	if _pending_payloads.is_empty():
		return
	var next_payload: Dictionary = _pending_payloads.pop_front()
	_send_payload(next_payload)


func _can_send_while_awaiting(command: GameCommand) -> bool:
	if command.command_type != "assign_dials":
		return false
	if _awaiting_command_type != "assign_dials":
		return false
	return _is_command_phase_dial_assignment_context()


func _is_command_phase_dial_assignment_context() -> bool:
	var state: GameState = GameManager.current_game_state if GameManager else null
	if state == null:
		return false
	if state.current_phase != Constants.GamePhase.COMMAND:
		return false
	if state.interaction_flow == null:
		return false
	if state.interaction_flow.flow_type != Constants.InteractionFlow.COMMAND_PHASE:
		return false
	return state.interaction_flow.step_id in [
		Constants.InteractionStep.SELECT_DIALS,
		Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS,
	]

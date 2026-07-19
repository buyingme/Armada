## Strategy interface for command submission.
##
## Abstracts how a [GameCommand] reaches the authority for validation and
## execution.  Concrete implementations:
## - [LocalCommandSubmitter] — in-process, calls [CommandProcessor] directly.
## - [NetworkCommandSubmitter] — serialize + RPC to dedicated server.
##
## G4 Network Plan: §1.5 — CommandSubmitter Strategy
class_name CommandSubmitter
extends RefCounted


## Submits a command for validation and execution.
## Returns the result dictionary (local) or [code]{}[/code] (network, async).
func submit(command: GameCommand) -> Dictionary:
	return {}


## Submits a replay-recorded command with its authoritative sequence intact.
func submit_replay(command: GameCommand) -> Dictionary:
	return submit(command)


## Returns [code]true[/code] when waiting for server confirmation (network only).
func is_awaiting_response() -> bool:
	return false

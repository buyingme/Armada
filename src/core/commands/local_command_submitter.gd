## Local command submitter — in-process, zero-latency.
##
## Delegates directly to [CommandProcessor.submit] with no serialization
## or network round-trip.  Used for hot-seat and single-player modes.
##
## G4 Network Plan: §1.5 — CommandSubmitter Strategy
class_name LocalCommandSubmitter
extends CommandSubmitter


## Submits the command directly to [CommandProcessor].
## Returns the execution result, or [code]{}[/code] on validation failure.
func submit(command: GameCommand) -> Dictionary:
	return CommandProcessor.submit(command)


func submit_replay(command: GameCommand) -> Dictionary:
	return CommandProcessor.submit_replay(command)

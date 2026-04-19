## Server-side sync gate for the Command Phase.
##
## During the Command Phase both players assign dials simultaneously.
## The server executes each [AssignDialCommand] immediately (to keep
## its authoritative [GameState] up-to-date) but **holds back** the
## broadcast until both players have finished assigning all their dials.
## Once the gate opens, all held results are released in order.
##
## Usage (inside NetworkManager):
## [codeblock]
## if gate.is_active():
##     gate.hold(cmd_data, result, player_index)
##     if _all_dials_assigned(player_index):
##         gate.mark_ready(player_index)
##     if gate.is_open():
##         for entry in gate.release():
##             _broadcast(entry)
## [/codeblock]
##
## G4 Network Plan: §3 — G4.4 Command Phase Sync Gate
class_name CommandSyncGate
extends RefCounted


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Whether the gate is currently collecting dial commands.
var _active: bool = false

## Per-player "all dials submitted" flags.
var _player_ready: Array[bool] = [false, false]

## Held command results awaiting release.
## Each entry: [code]{"command_data": Dictionary, "result": Dictionary}[/code].
var _held: Array[Dictionary] = []


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Activates the gate.  Called at the start of the Command Phase.
func activate() -> void:
	_active = true
	_player_ready = [false, false]
	_held.clear()


## Deactivates the gate and discards any held data.
## Called when leaving the Command Phase or on error.
func deactivate() -> void:
	_active = false
	_player_ready = [false, false]
	_held.clear()


## Returns [code]true[/code] when the gate is actively collecting.
func is_active() -> bool:
	return _active


## Stores a command result to be broadcast later.
func hold(command_data: Dictionary, result: Dictionary) -> void:
	_held.append({"command_data": command_data, "result": result})


## Marks a player as having submitted all their dials.
func mark_ready(player_index: int) -> void:
	if player_index >= 0 and player_index < _player_ready.size():
		_player_ready[player_index] = true


## Returns [code]true[/code] when the gate should open (both players ready).
func is_open() -> bool:
	if not _active:
		return false
	for ready: bool in _player_ready:
		if not ready:
			return false
	return true


## Returns all held results and resets the gate.
## The caller is responsible for broadcasting each entry.
func release() -> Array[Dictionary]:
	var results: Array[Dictionary] = _held.duplicate()
	deactivate()
	return results


## Returns the number of currently held results.
func get_held_count() -> int:
	return _held.size()


## Returns [code]true[/code] if the given player has been marked ready.
func is_player_ready(player_index: int) -> bool:
	if player_index < 0 or player_index >= _player_ready.size():
		return false
	return _player_ready[player_index]

## CommandDialStack
##
## Manages the ordered stack of command dials for a single ship.
## Tracks facedown (hidden) dials, the currently revealed dial, and
## spent dials with their round history.
##
## During the Command Phase, new dials are added to the bottom of the stack
## (CP-004). During Ship Phase activation, the top dial is revealed (SP-010).
## After activation the revealed dial is spent (placed faceup as activation
## marker) or converted to a command token (SP-011).
##
## Rules Reference: "Command Dials", p.4; CP-001–007; SP-010–012.
class_name CommandDialStack
extends RefCounted


## A single dial entry: command type + round assigned + state.
## States: "hidden", "revealed", "spent".
const STATE_HIDDEN: String = "hidden"
const STATE_REVEALED: String = "revealed"
const STATE_SPENT: String = "spent"

## The command value (max stack depth) for this ship.
## Rules Reference: CP-002 — dials equal to command value.
var command_value: int = 0

## Ordered array of dial dictionaries.
## Each entry: {"command": Constants.CommandType, "round": int, "state": String}
## Index 0 = top of stack (next to be revealed).
var _dials: Array[Dictionary] = []

## History of all spent dials (for the Command Dial Order modal).
## Each entry: {"command": Constants.CommandType, "round": int}
var _spent_history: Array[Dictionary] = []

var _log: GameLogger = GameLogger.new("CommandDialStack")


## Creates a CommandDialStack for a ship with the given command value.
## [param cmd_value] — the ship's command value (e.g. 1, 2, or 3).
static func create(cmd_value: int) -> CommandDialStack:
	var stack: CommandDialStack = CommandDialStack.new()
	stack.command_value = cmd_value
	return stack


## Returns the number of hidden (facedown) dials in the stack.
func get_hidden_count() -> int:
	var count: int = 0
	for dial: Dictionary in _dials:
		if dial["state"] == STATE_HIDDEN:
			count += 1
	return count


## Returns the total number of dials (hidden + revealed, not spent).
func get_dial_count() -> int:
	return _dials.size()


## Returns how many new dials are needed for the given round.
## Round 1: need command_value dials total.
## Rounds 2+: need exactly 1 new dial (CP-003, CP-004).
func get_dials_needed(current_round: int) -> int:
	if current_round == 1:
		return command_value
	return 1


## Returns all dials (shallow copy) for inspection.
func get_all_dials() -> Array[Dictionary]:
	return _dials.duplicate()


## Returns the top dial (index 0) without removing it, or an empty dict.
func peek_top() -> Dictionary:
	if _dials.is_empty():
		return {}
	return _dials[0]


## Returns the command type of the top dial, or -1 if empty.
func get_top_command() -> int:
	if _dials.is_empty():
		return -1
	return int(_dials[0]["command"])


## Assigns new dials during the Command Phase.
## In round 1, [param commands] must contain exactly [command_value] entries.
## In rounds 2+, [param commands] must contain exactly 1 entry.
## New dials are placed at the BOTTOM of the stack (under existing dials).
## Rules Reference: CP-003, CP-004.
## [param commands] — array of Constants.CommandType values.
## [param current_round] — the current round number.
## Returns true if assignment was valid, false if rejected.
func assign_dials(commands: Array, current_round: int) -> bool:
	var needed: int = get_dials_needed(current_round)
	if commands.size() != needed:
		_log.warn("Expected %d dials, got %d" % [needed, commands.size()])
		return false

	for cmd: Variant in commands:
		var dial: Dictionary = {
			"command": int(cmd),
			"round": current_round,
			"state": STATE_HIDDEN,
		}
		_dials.append(dial)

	return true


## Reveals the top dial (Ship Phase activation, step 1).
## Changes the top dial's state from "hidden" to "revealed".
## Rules Reference: SP-010 — reveal top facedown dial.
## Returns the revealed dial dictionary, or empty dict if stack is empty.
func reveal_top() -> Dictionary:
	if _dials.is_empty():
		_log.warn("Cannot reveal — stack is empty")
		return {}
	if _dials[0]["state"] != STATE_HIDDEN:
		_log.warn("Top dial is already %s" % _dials[0]["state"])
		return {}
	_dials[0]["state"] = STATE_REVEALED
	return _dials[0]


## Spends (discards) the top revealed dial after activation.
## Moves it to spent history and removes it from the active stack.
## Rules Reference: CM-007 — after activation, dial is discarded.
## Returns the spent dial dictionary, or empty dict if nothing to spend.
func spend_revealed() -> Dictionary:
	if _dials.is_empty():
		return {}
	if _dials[0]["state"] != STATE_REVEALED:
		_log.warn("Top dial is not revealed — state is %s" % _dials[0]["state"])
		return {}
	var dial: Dictionary = _dials.pop_front()
	_spent_history.append({
		"command": dial["command"],
		"round": dial["round"],
	})
	return dial


## Returns the currently revealed dial (if any) without removing it.
func get_revealed_dial() -> Dictionary:
	if _dials.is_empty():
		return {}
	if _dials[0]["state"] == STATE_REVEALED:
		return _dials[0]
	return {}


## Returns the full spent history for the Command Dial Order modal.
## Each entry: {"command": Constants.CommandType, "round": int}.
func get_spent_history() -> Array[Dictionary]:
	return _spent_history.duplicate()


## Clears the spent dial history. Called at the start of a new round so the
## spent activation marker from the previous round is removed.
## Rules Reference: The spent dial is an "activation marker" for the current
## round only; it should not persist into the next round's display.
func clear_spent_history() -> void:
	_spent_history.clear()


## Returns all dial info needed for the card panel display.
## Result: {"hidden_dials": Array[CommandType], "top_command": int,
##          "revealed": Dictionary or empty, "spent_this_round": Dictionary or empty}
func get_display_state() -> Dictionary:
	var hidden_commands: Array[int] = []
	var top_cmd: int = -1
	var revealed: Dictionary = {}

	for i: int in range(_dials.size()):
		var dial: Dictionary = _dials[i]
		if dial["state"] == STATE_HIDDEN:
			hidden_commands.append(int(dial["command"]))
			if top_cmd == -1:
				top_cmd = int(dial["command"])
		elif dial["state"] == STATE_REVEALED:
			revealed = dial

	# The most recent spent dial (activation marker for current round).
	var spent_marker: Dictionary = {}
	if not _spent_history.is_empty():
		spent_marker = _spent_history[-1]

	return {
		"hidden_dials": hidden_commands,
		"top_command": top_cmd,
		"revealed": revealed,
		"spent_marker": spent_marker,
	}


## Clears the stack entirely (used when a ship is destroyed).
func clear() -> void:
	_dials.clear()


## Serializes the stack state.
func serialize() -> Dictionary:
	return {
		"command_value": command_value,
		"dials": _dials.duplicate(),
		"spent_history": _spent_history.duplicate(),
	}


## Deserializes from a dictionary.
static func deserialize(data: Dictionary) -> CommandDialStack:
	var stack: CommandDialStack = CommandDialStack.new()
	stack.command_value = int(data.get("command_value", 0))
	for d: Variant in data.get("dials", []):
		stack._dials.append(d as Dictionary)
	for s: Variant in data.get("spent_history", []):
		stack._spent_history.append(s as Dictionary)
	return stack

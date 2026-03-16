## CommandTokenManager
##
## Manages command tokens for a single ship. Enforces the rules:
## - A ship cannot have more tokens than its command value (CM-004).
## - A ship cannot have duplicate command tokens (CM-005).
## - A command token can be spent in the same round it was gained (CM-006).
##
## Rules Reference: "Command Tokens", p.4; CM-004–006.
class_name CommandTokenManager
extends RefCounted


## Maximum number of command tokens this ship can hold (= command value).
## Rules Reference: CM-004.
var max_tokens: int = 0

## Current command tokens. Array of Constants.CommandType values.
var _tokens: Array[int] = []

var _log: GameLogger = GameLogger.new("CommandTokenManager")


## Creates a CommandTokenManager for a ship with the given command value.
static func create(cmd_value: int) -> CommandTokenManager:
	var mgr: CommandTokenManager = CommandTokenManager.new()
	mgr.max_tokens = cmd_value
	return mgr


## Returns the number of command tokens held.
func get_token_count() -> int:
	return _tokens.size()


## Returns a copy of the current tokens.
func get_tokens() -> Array[int]:
	return _tokens.duplicate()


## Returns true if the ship holds a token of the given type.
func has_token(command: Constants.CommandType) -> bool:
	return int(command) in _tokens


## Attempts to add a command token. Returns true if added, false if rejected.
## Rejects if: duplicate type (CM-005) or would exceed max (CM-004).
## Rules Reference: CM-004, CM-005.
func add_token(command: Constants.CommandType) -> bool:
	if has_token(command):
		_log.info("Duplicate token rejected: %s" % command)
		return false
	if _tokens.size() >= max_tokens:
		_log.info("Token overflow — must discard one first (CM-004)")
		return false
	_tokens.append(int(command))
	return true


## Attempts to add a token, forcing discard of an existing one if at capacity.
## [param command] — the new token type.
## [param discard_type] — the token type to discard if at capacity.
## Returns {"added": bool, "discarded": int (-1 if none)}.
## Rules Reference: CM-004.
func add_token_with_discard(command: Constants.CommandType,
		discard_type: Constants.CommandType) -> Dictionary:
	if has_token(command):
		return {"added": false, "discarded": - 1}

	var discarded: int = -1
	if _tokens.size() >= max_tokens:
		if not has_token(discard_type):
			return {"added": false, "discarded": - 1}
		remove_token(discard_type)
		discarded = int(discard_type)

	_tokens.append(int(command))
	return {"added": true, "discarded": discarded}


## Removes and returns a token of the given type. Returns true if removed.
func remove_token(command: Constants.CommandType) -> bool:
	var idx: int = _tokens.find(int(command))
	if idx == -1:
		return false
	_tokens.remove_at(idx)
	return true


## Spends a command token of the given type. Alias for remove_token.
## Rules Reference: CM-001 — spend token to resolve command.
func spend_token(command: Constants.CommandType) -> bool:
	return remove_token(command)


## Clears all tokens (used when a ship is destroyed).
func clear() -> void:
	_tokens.clear()


## Serializes the token state.
func serialize() -> Dictionary:
	return {
		"max_tokens": max_tokens,
		"tokens": _tokens.duplicate(),
	}


## Deserializes from a dictionary.
static func deserialize(data: Dictionary) -> CommandTokenManager:
	var mgr: CommandTokenManager = CommandTokenManager.new()
	mgr.max_tokens = int(data.get("max_tokens", 0))
	for t: Variant in data.get("tokens", []):
		mgr._tokens.append(int(t))
	return mgr

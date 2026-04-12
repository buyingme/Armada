## GameCommand
##
## Abstract base class for all player-initiated game actions.
## Each command encapsulates a single atomic state change that can be
## serialized for network transmission, recorded for replay, and
## (optionally) undone.
##
## Subclasses override [method execute] to apply the action to the game
## state and return a result dictionary.
##
## Usage:
## [codeblock]
## var cmd := RollDiceCommand.new(0, {"pool": pool_dict})
## CommandProcessor.submit(cmd)
## [/codeblock]
##
## Rules Reference: architectural decision — all game-changing player
## actions must be serializable for multiplayer and replay.
class_name GameCommand
extends RefCounted


## The player who issued this command (0 or 1).
var player_index: int = 0

## Machine-readable type string (e.g. "assign_dials", "roll_dice").
## Populated automatically by each subclass.
var command_type: String = ""

## Arbitrary payload carrying command-specific data.
var payload: Dictionary = {}

## Server-assigned sequence number (set by [CommandProcessor]).
var sequence: int = -1


## Creates a command.
## [param p_player] — player index (0 or 1).
## [param p_type] — command type string.
## [param p_payload] — command-specific data dictionary.
func _init(p_player: int = 0, p_type: String = "",
		p_payload: Dictionary = {}) -> void:
	player_index = p_player
	command_type = p_type
	payload = p_payload


## Executes the command against the given [param game_state].
## Returns a result dictionary whose shape depends on the subclass.
## Subclasses **must** override this method.
func execute(game_state: GameState) -> Dictionary:
	push_warning("GameCommand.execute() called on base class — "
			+"override in subclass '%s'." % command_type)
	return {}


## Validates whether this command is legal in the current game state.
## Returns an empty string if valid, or an error message if not.
## Subclasses should override for command-specific validation.
func validate(game_state: GameState) -> String:
	if game_state == null:
		return "No active game state."
	return ""


## Serializes the command to a dictionary suitable for JSON encoding
## or network transmission.
func serialize() -> Dictionary:
	return {
		"type": command_type,
		"player": player_index,
		"sequence": sequence,
		"payload": payload,
	}


## Deserializes a command from a dictionary.
## Dispatches to the correct subclass via the command registry.
## Returns null if the type is unknown.
static func deserialize(data: Dictionary) -> GameCommand:
	var cmd_type: String = data.get("type", "")
	var player: int = data.get("player", 0)
	var seq: int = data.get("sequence", -1)
	var cmd_payload: Dictionary = data.get("payload", {})
	var cmd: GameCommand = _create_by_type(cmd_type, player, cmd_payload)
	if cmd:
		cmd.sequence = seq
	return cmd


## Returns a human-readable description of the command for logging.
func describe() -> String:
	return "[%s] player=%d seq=%d" % [command_type, player_index,
			sequence]


# ---------------------------------------------------------------------------
# Registry — maps type strings to factory callables
# ---------------------------------------------------------------------------

## Registry mapping command_type strings to factory [Callable]s.
## Each callable signature: func(player: int, payload: Dictionary) -> GameCommand
static var _registry: Dictionary = {}


## Registers a command type with its factory callable.
## Call this from each concrete command's class body or from
## [CommandProcessor._ready].
static func register_type(type_name: String,
		factory: Callable) -> void:
	_registry[type_name] = factory


## Creates a command by type name via the registry.
## Returns null if the type is not registered.
static func _create_by_type(type_name: String, player: int,
		cmd_payload: Dictionary) -> GameCommand:
	if _registry.has(type_name):
		var factory: Callable = _registry[type_name]
		return factory.call(player, cmd_payload)
	push_warning("Unknown command type: '%s'" % type_name)
	return null

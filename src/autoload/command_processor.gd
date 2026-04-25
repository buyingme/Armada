## CommandProcessor
##
## Central autoload that validates, executes, records, and distributes
## all player-initiated game actions ([GameCommand] instances).
##
## Every game-mutating action flows through [method submit]:
## [codeblock]
## CommandProcessor.submit(my_command)
## [/codeblock]
##
## The processor:
## 1. Validates the command ([method GameCommand.validate]).
## 2. Assigns a monotonically increasing sequence number.
## 3. Executes the command ([method GameCommand.execute]).
## 4. Records the command in the history for replay / undo.
## 5. Emits [signal command_executed] so the presentation layer can
##    react (UI updates, sound effects, network broadcast, etc.).
##
## In multiplayer (future), only the host runs [method execute];
## clients receive authoritative results via [signal command_executed].
extends Node


## Emitted after a command has been successfully validated and executed.
signal command_executed(command: GameCommand, result: Dictionary)

## Emitted when a command fails validation.
signal command_rejected(command: GameCommand, reason: String)

## Monotonically increasing sequence counter.
var _next_sequence: int = 0

## Ordered history of all executed commands (for replay).
var _history: Array[GameCommand] = []

## Logger for this system.
var _log: GameLogger = GameLogger.new("CommandProcessor")

## True during [method replay_commands] or reconnection replay.
## When set, [signal command_executed] is suppressed so the presentation
## layer does not react to replayed commands.
## G4 Network Plan: §3 — G4.2.6
var is_replaying: bool = false


## Registers all concrete command types on startup.
func _ready() -> void:
	AssignDialCommand.register()
	ActivateShipCommand.register()
	EndActivationCommand.register()
	ConvertDialToTokenCommand.register()
	ActivateSquadronCommand.register()
	SpendTokenCommand.register()
	SpendDialCommand.register()
	# Tier 2 — attack commands.
	RollDiceCommand.register()
	SpendDefenseTokenCommand.register()
	SelectRedirectZoneCommand.register()
	SkipAttackCommand.register()
	# Tier 3 — movement commands.
	MoveSquadronCommand.register()
	ExecuteManeuverCommand.register()
	# Tier 4 — game flow commands.
	AdvancePhaseCommand.register()
	StartRoundCommand.register()
	# Tier 5 — status phase + destruction cleanup.
	StatusPhaseCleanupCommand.register()
	DestroyUnitCommand.register()
	# Tier 6 — damage resolution.
	ResolveDamageCommand.register()
	# Tier 7 — repair actions.
	RepairActionCommand.register()
	# Tier 8 — immediate damage card effects.
	ResolveImmediateEffectCommand.register()
	# Tier 9 — overlap, speed, persistent effects.
	SetSpeedCommand.register()
	OverlapDamageCommand.register()
	PersistentEffectDamageCommand.register()
	# Tier 10 — UI state: token discard, dial reveal/unreveal.
	DiscardTokenCommand.register()
	RevealDialCommand.register()
	AdvanceActivationStepCommand.register()
	# Tier 11 — debug-only commands.
	DebugDealDamageCommand.register()
	_log.info("Registered %d command types." % GameCommand._registry.size())


## Submits a command for validation and execution.
## Returns the result dictionary from [method GameCommand.execute],
## or an empty dictionary if validation fails.
func submit(command: GameCommand) -> Dictionary:
	var game_state: GameState = _get_game_state()
	# --- Validate ---
	var reason: String = command.validate(game_state)
	if reason != "":
		_log.warn("Command rejected [%s]: %s" % [
				command.command_type, reason])
		command_rejected.emit(command, reason)
		return {}
	# --- Sequence ---
	command.sequence = _next_sequence
	_next_sequence += 1
	# --- Execute ---
	var result: Dictionary = command.execute(game_state)
	_log.info("Executed [%s] seq=%d player=%d." % [
			command.command_type, command.sequence,
			command.player_index])
	# --- Record ---
	_history.append(command)
	# --- Notify ---
	if not is_replaying:
		command_executed.emit(command, result)
	return result


## Returns the complete ordered history of executed commands.
func get_history() -> Array[GameCommand]:
	return _history


## Returns the number of commands executed so far.
func get_command_count() -> int:
	return _history.size()


## Clears history and resets the sequence counter.
## Called at game start / new game.
func reset() -> void:
	_history.clear()
	_next_sequence = 0
	_log.info("Command history reset.")


## Serializes the full command history for save / replay.
func serialize_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd: GameCommand in _history:
		result.append(cmd.serialize())
	return result


## Creates a [GameReplay] capturing the current session's header and
## command history.  The header is populated from [GameManager]'s
## current game state (RNG seed, factions, scenario ID).
## Returns [code]null[/code] if no game state is available.
func create_replay() -> GameReplay:
	var game_state: GameState = _get_game_state()
	if game_state == null:
		_log.warn("create_replay: no active game state.")
		return null
	var replay := GameReplay.new()
	var rng_seed: int = 0
	if game_state.rng:
		rng_seed = game_state.rng.initial_seed
	var factions: Array = []
	for i: int in range(game_state.player_states.size()):
		var ps: PlayerState = game_state.get_player_state(i)
		factions.append(ps.faction if ps else Constants.Faction.REBEL_ALLIANCE)
	replay.capture_header(
			GameManager.get_scenario_id(),
			rng_seed,
			factions,
			game_state.initiative_player)
	replay.set_commands(serialize_history())
	return replay


## Replays a list of serialized commands against the given game state.
## Used for save-game loading and deterministic replay.
## Suppresses [signal command_executed] during replay.
func replay_commands(commands: Array[Dictionary]) -> void:
	is_replaying = true
	for cmd_data: Dictionary in commands:
		var cmd: GameCommand = GameCommand.deserialize(cmd_data)
		if cmd == null:
			_log.warn("Skipping unknown command: %s" %
					cmd_data.get("type", "?"))
			continue
		submit(cmd)
	is_replaying = false


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns the current [GameState] from [GameManager].
func _get_game_state() -> GameState:
	if GameManager and GameManager.current_game_state:
		return GameManager.current_game_state
	return null

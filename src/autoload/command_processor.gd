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
## 1. Checks the command's declared Phase M applicability surface.
## 2. Runs static [RuleRegistry] validator hooks for the active flow step.
## 3. Validates the command ([method GameCommand.validate]).
## 4. Assigns a monotonically increasing sequence number.
## 5. Executes the command ([method GameCommand.execute]).
## 6. Records the command in the history for replay / undo.
## 7. Collects [RuleRegistry] observer follow-ups into a deferred queue.
## 8. Emits [signal command_executed] so the presentation layer can
##    react (UI updates, sound effects, network broadcast, etc.).
## 9. Drains observer follow-ups through the active authority path.
##
## In multiplayer (future), only the host runs [method execute];
## clients receive authoritative results via [signal command_executed].
extends Node


const CommitSetupObstacleCommand = preload(
		"res://src/core/commands/commit_setup_obstacle_command.gd")
const CommitSetupDeploymentCommand = preload(
		"res://src/core/commands/commit_setup_deployment_command.gd")


const COMMAND_APPLICABILITY_SCRIPT: GDScript = \
		preload("res://src/core/commands/command_applicability.gd")


## Emitted after a command has been successfully validated and executed.
signal command_executed(command: GameCommand, result: Dictionary)

## Emitted when a command fails validation.
signal command_rejected(command: GameCommand, reason: String)

## Monotonically increasing sequence counter.
var _next_sequence: int = 0

## Ordered history of all executed commands (for replay).
var _history: Array[GameCommand] = []

## Observer-generated follow-up commands waiting for deferred submission.
var _observer_followups: Array[GameCommand] = []

## Guards observer callbacks from submitting synchronously while collecting.
var _is_collecting_observer_followups: bool = false

## Prevents nested drains from re-entering the FIFO loop.
var _is_draining_observer_followups: bool = false

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
	CompleteSquadronActivationCommand.register()
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
	CommitSetupObstacleCommand.register()
	CommitSetupDeploymentCommand.register()
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
	# Tier 12 — interaction-flow synchronisation (Phase I6b-3).
	PublishAttackFlowCommand.register()
	# Tier 13 — defender authority (Phase I6b-3 R2/R3/R4).
	CommitDefenseCommand.register()
	SelectEvadeDieCommand.register()
	RedirectDoneCommand.register()
	RerollAttackDieCommand.register()
	SkipAttackModifierCommand.register()
	ConfirmAttackDiceCommand.register()
	CounterChoiceCommand.register()
	# Tier 14 — squadron-displacement authority (Phase I6b-4).
	StartDisplacementCommand.register()
	CommitDisplacementCommand.register()
	# CAP-UPG-001 - Grand Moff Tarkin command-token choice.
	TarkinChoiceCommand.register()
	_log.info("Registered %d command types." % GameCommand._registry.size())


func _exit_tree() -> void:
	GameCommand._clear_registry_for_shutdown()


## Submits a command for validation and execution.
## Returns the result dictionary from [method GameCommand.execute],
## or an empty dictionary if validation fails.
func submit(command: GameCommand) -> Dictionary:
	return _submit(command, true, true)


## Submits an authoritative command while leaving observer follow-ups queued.
## Network authorities use this so they can broadcast the triggering command
## before draining follow-ups through their submitter/broadcast path.
func submit_deferred_followups(command: GameCommand) -> Dictionary:
	return _submit(command, false, true)


## Applies an already-authoritative network mirror command locally.
## The command still emits [signal command_executed] for UI projection, but
## observer follow-ups are suppressed so passive peers do not synthesize
## duplicate commands.
func submit_mirror(command: GameCommand) -> Dictionary:
	return _submit(command, true, false)


## Runs command preflight checks before command-specific validation.
## Returns an empty string when the command may continue, otherwise the
## rejection reason that should be emitted to callers.
func preflight(command: GameCommand, game_state: GameState) -> String:
	var applicability: Dictionary = _check_applicability(command, game_state)
	if not bool(applicability.get(
			COMMAND_APPLICABILITY_SCRIPT.KEY_ALLOWED, false)):
		return str(applicability.get(
				COMMAND_APPLICABILITY_SCRIPT.KEY_REASON, ""))
	return _check_rule_validators(command, game_state)


## Drains observer follow-up commands in FIFO order.
## [param submitter] may route commands through a network-aware submitter;
## when omitted, follow-ups use [method submit] directly.
func drain_observer_followups(submitter: Callable = Callable()) -> void:
	if _is_draining_observer_followups:
		return
	_is_draining_observer_followups = true
	while not _observer_followups.is_empty():
		var followup: GameCommand = \
				_observer_followups.pop_front() as GameCommand
		_submit_followup(followup, submitter)
	_is_draining_observer_followups = false


## Returns the number of observer follow-up commands still queued.
func get_pending_observer_followup_count() -> int:
	return _observer_followups.size()


func _submit(command: GameCommand,
		drain_followups: bool,
		collect_observers: bool) -> Dictionary:
	if _is_collecting_observer_followups:
		return _reject_command(command,
				"Observer hooks must return follow-up commands instead of "
				+"submitting.")
	var game_state: GameState = _get_game_state()
	var flow_snapshot: InteractionFlow = _snapshot_flow(game_state)
	var preflight_reason: String = preflight(command, game_state)
	if preflight_reason != "":
		return _reject_command(command, preflight_reason)
	var reason: String = command.validate(game_state)
	if reason != "":
		return _reject_command(command, reason)
	var result: Dictionary = _execute_and_record(command, game_state)
	if not is_replaying:
		if collect_observers:
			_collect_observer_followups(
					command, result, game_state, flow_snapshot)
		command_executed.emit(command, result)
		if drain_followups:
			drain_observer_followups()
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
	_observer_followups.clear()
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


func _check_applicability(command: GameCommand,
		game_state: GameState) -> Dictionary:
	if game_state == null:
		return {
			COMMAND_APPLICABILITY_SCRIPT.KEY_ALLOWED: false,
			COMMAND_APPLICABILITY_SCRIPT.KEY_REASON: "No active game state.",
		}
	return COMMAND_APPLICABILITY_SCRIPT.check_command(
			command.command_type,
			game_state.current_phase,
			game_state.interaction_flow)


func _snapshot_flow(game_state: GameState) -> InteractionFlow:
	if game_state == null or game_state.interaction_flow == null:
		return InteractionFlow.empty()
	var flow: InteractionFlow = game_state.interaction_flow
	return InteractionFlow.make(
			flow.flow_type,
			flow.step_id,
			flow.controller_player,
			flow.visible_to,
			flow.payload)


func _execute_and_record(command: GameCommand,
		game_state: GameState) -> Dictionary:
	command.sequence = _next_sequence
	_next_sequence += 1
	var result: Dictionary = command.execute(game_state)
	_log.info("Executed [%s] seq=%d player=%d." % [
			command.command_type, command.sequence,
			command.player_index])
	_history.append(command)
	return result


func _check_rule_validators(command: GameCommand,
		game_state: GameState) -> String:
	if game_state == null or game_state.interaction_flow == null:
		return ""
	var flow: InteractionFlow = game_state.interaction_flow
	var hooks: Array[FlowHook] = RuleRegistry.validators_for(
			int(flow.flow_type), int(flow.step_id), command.command_type)
	for hook: FlowHook in hooks:
		var reason: String = _run_validator_hook(hook, game_state, command)
		if reason != "":
			return reason
	return ""


func _run_validator_hook(hook: FlowHook,
		game_state: GameState,
		command: GameCommand) -> String:
	if hook == null or not hook.callback.is_valid():
		return ""
	var raw: Variant = hook.callback.call(game_state, command)
	if not (raw is Dictionary):
		return ""
	var result: Dictionary = raw as Dictionary
	if bool(result.get("allowed", true)):
		return ""
	var fallback: String = "Rule %s rejected command." % hook.rule_id
	return str(result.get("reason", fallback))


func _collect_observer_followups(command: GameCommand,
		result: Dictionary,
		game_state: GameState,
		flow_snapshot: InteractionFlow) -> void:
	if game_state == null or flow_snapshot == null:
		return
	var hooks: Array[FlowHook] = RuleRegistry.observers_for(
			int(flow_snapshot.flow_type), int(flow_snapshot.step_id),
			command.command_type)
	if hooks.is_empty():
		return
	_is_collecting_observer_followups = true
	for hook: FlowHook in hooks:
		_enqueue_observer_result(hook, game_state, command, result)
	_is_collecting_observer_followups = false


func _enqueue_observer_result(hook: FlowHook,
		game_state: GameState,
		command: GameCommand,
		result: Dictionary) -> void:
	if hook == null or not hook.callback.is_valid():
		return
	var raw: Variant = hook.callback.call(game_state, command, result)
	if raw is Array:
		for item: Variant in (raw as Array):
			_enqueue_observer_item(hook, item)
		return
	_enqueue_observer_item(hook, raw)


func _enqueue_observer_item(hook: FlowHook, item: Variant) -> void:
	if item == null:
		return
	if item is GameCommand:
		_observer_followups.append(item as GameCommand)
		return
	if item is Dictionary:
		var command: GameCommand = GameCommand.deserialize(item as Dictionary)
		if command != null:
			_observer_followups.append(command)
		return
	_log.warn("Observer rule [%s] returned unsupported follow-up." % hook.rule_id)


func _submit_followup(followup: GameCommand, submitter: Callable) -> void:
	if followup == null:
		return
	if submitter.is_valid():
		submitter.call(followup)
		return
	submit(followup)


func _reject_command(command: GameCommand, reason: String) -> Dictionary:
	_log.warn("Command rejected [%s]: %s" % [
			command.command_type, reason])
	command_rejected.emit(command, reason)
	return {}

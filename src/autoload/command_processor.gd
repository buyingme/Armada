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


const DEBUG_REPOSITION_COMMAND_SCRIPT: GDScript = preload(
		"res://src/core/commands/debug_reposition_command.gd")

const CommitSetupObstacleCommand = preload(
		"res://src/core/commands/commit_setup_obstacle_command.gd")
const CommitSetupDeploymentCommand = preload(
		"res://src/core/commands/commit_setup_deployment_command.gd")
const UseECMCommandScript: GDScript = preload(
		"res://src/core/commands/use_ecm_command.gd")
const DeclineECMCommandScript: GDScript = preload(
		"res://src/core/commands/decline_ecm_command.gd")
const ReadyECMCommandScript: GDScript = preload(
		"res://src/core/commands/ready_ecm_command.gd")
const DeclineECMReadyCommandScript: GDScript = preload(
		"res://src/core/commands/decline_ecm_ready_command.gd")
const UseConcentrateFireTokenRerollCommandScript: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const DeclineConcentrateFireTokenRerollCommandScript: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")
const ChooseConcentrateFireCommandScript: GDScript = preload(
		"res://src/core/commands/choose_concentrate_fire_command.gd")
const UseH9CommandScript: GDScript = preload(
		"res://src/core/commands/use_h9_command.gd")
const DeclineH9CommandScript: GDScript = preload(
		"res://src/core/commands/decline_h9_command.gd")


const COMMAND_APPLICABILITY_SCRIPT: GDScript = \
		preload("res://src/core/commands/command_applicability.gd")
const TIMING_WINDOW_ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const CURRENT_ATTACK_CONTINUATION: GDScript = preload(
		"res://src/core/state/current_attack_continuation.gd")


## Emitted after a command has been successfully validated and executed.
signal command_executed(command: GameCommand, result: Dictionary)

## Emitted when a command fails validation.
signal command_rejected(command: GameCommand, reason: String)

## Monotonically increasing sequence counter.
var _next_sequence: int = 0

## Ordered history of all executed commands (for replay).
var _history: Array[GameCommand] = []

## Frozen at the accepted live command boundary and retained only until that
## sequence has been distributed to both authorized viewers.
var _frozen_maneuver_consequence_views: Dictionary = {}

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
	BeginAttackCommand.register()
	ResolveAttackPoolChoiceCommand.register()
	ChooseConcentrateFireCommandScript.register()
	UseConcentrateFireDialCommand.register()
	DeclineConcentrateFireDialCommand.register()
	RollDiceCommand.register()
	CommitAccuracyCommand.register()
	SpendDefenseTokenCommand.register()
	SelectRedirectZoneCommand.register()
	SkipAttackCommand.register()
	CompleteAttackCommand.register()
	AcknowledgeAttackResultCommand.register()
	AcknowledgeFaceupDamageCommand.register()
	AcknowledgeObstaclePreEffectCommand.register()
	CompleteAsteroidOverlapCommand.register()
	CompleteMatchCommand.register()
	# Tier 3 — movement commands.
	MoveSquadronCommand.register()
	DeclineSquadronMoveCommand.register()
	GameCommand.register_type("execute_maneuver", func(player: int,
			payload: Dictionary) -> GameCommand:
		return CandidateExecuteManeuverCommand.new(player, payload))
	for registration: Dictionary in [
		{"type":"apply_maneuver_transform","script":CandidateApplyManeuverTransformCommand},
		{"type":"complete_maneuver","script":CandidateCompleteManeuverCommand},
		{"type":"commit_maneuver_obstacle_order","script":CandidateCommitManeuverObstacleOrderCommand},
		{"type":"resolve_ship_collision_damage","script":CandidateResolveShipCollisionDamageCommand},
		{"type":"resolve_thruster_fissure","script":CandidateResolveThrusterFissureCommand},
		{"type":"resolve_damaged_controls","script":CandidateResolveDamagedControlsCommand},
		{"type":"resolve_asteroid_overlap","script":CandidateResolveAsteroidOverlapCommand},
		{"type":"resolve_debris_overlap","script":CandidateResolveDebrisOverlapCommand},
		{"type":"resolve_station_overlap","script":CandidateResolveStationOverlapCommand},
		{"type":"resolve_ruptured_engine","script":CandidateResolveRupturedEngineCommand},
	]:
		var command_script: GDScript = registration["script"]
		GameCommand.register_type(str(registration["type"]), func(player: int,
				payload: Dictionary) -> GameCommand:
			return command_script.new(player, payload))
	# Tier 4 — game flow commands.
	AdvancePhaseCommand.register()
	StartRoundCommand.register()
	CommitSetupObstacleCommand.register()
	CommitSetupDeploymentCommand.register()
	# Tier 5 — status phase + destruction cleanup.
	StatusPhaseCleanupCommand.register()
	DestroyUnitCommand.register()
	# Tier 6 — damage resolution.
	GameCommand.register_type("resolve_damage", func(player: int,
			payload: Dictionary) -> GameCommand:
		return CandidateResolveDamageCommand.new(player, payload))
	# Tier 7 — repair actions.
	RepairActionCommand.register()
	# Tier 8 — immediate damage card effects.
	GameCommand.register_type("resolve_immediate_effect", func(player: int,
			payload: Dictionary) -> GameCommand:
		return CandidateResolveImmediateEffectCommand.new(player, payload))
	# Tier 9 — overlap, speed, persistent effects.
	SetSpeedCommand.register()
	OverlapDamageCommand.register()
	PersistentEffectDamageCommand.register()
	# Tier 10 — UI state: token discard, dial reveal/unreveal.
	DiscardTokenCommand.register()
	RevealDialCommand.register()
	AdvanceActivationStepCommand.register()
	# Tier 11 — debug-only commands.
	GameCommand.register_type("debug_reposition", func(player: int,
			payload: Dictionary) -> GameCommand:
		return DEBUG_REPOSITION_COMMAND_SCRIPT.new(player, payload))
	GameCommand.register_type("debug_deal_damage", func(player: int,
			payload: Dictionary) -> GameCommand:
		return CandidateDebugDealDamageCommand.new(player, payload))
	# Tier 12 — interaction-flow synchronisation (Phase I6b-3).
	PublishAttackFlowCommand.register()
	# Tier 13 — defender authority (Phase I6b-3 R2/R3/R4).
	CommitDefenseCommand.register()
	SelectEvadeDieCommand.register()
	RedirectDoneCommand.register()
	RerollAttackDieCommand.register()
	SkipAttackModifierCommand.register()
	UseConcentrateFireTokenRerollCommandScript.register()
	DeclineConcentrateFireTokenRerollCommandScript.register()
	UseH9CommandScript.register()
	DeclineH9CommandScript.register()
	ConfirmAttackDiceCommand.register()
	CounterChoiceCommand.register()
	# Tier 14 — squadron-displacement authority (Phase I6b-4).
	GameCommand.register_type("start_displacement", func(player: int,
			payload: Dictionary) -> GameCommand:
		return CandidateStartDisplacementCommand.new(player, payload))
	GameCommand.register_type("commit_displacement", func(player: int,
			payload: Dictionary) -> GameCommand:
		return CandidateCommitDisplacementCommand.new(player, payload))
	# CAP-UPG-001 - Grand Moff Tarkin command-token choice.
	TarkinChoiceCommand.register()
	# CAP-ECM-001 - Electronic Countermeasures defense-token override.
	UseECMCommandScript.register()
	DeclineECMCommandScript.register()
	# CAP-ECM-001 - Electronic Countermeasures Status Phase ready cost.
	ReadyECMCommandScript.register()
	DeclineECMReadyCommandScript.register()
	_log.info("Registered %d command types." % GameCommand._registry.size())


func _exit_tree() -> void:
	# Only the process-wide autoload owns the process-wide registry. Temporary
	# processors used by focused verification must not erase live factories.
	if get_node_or_null("/root/CommandProcessor") == self:
		GameCommand._clear_registry_for_shutdown()


## Submits a command for validation and execution.
## Returns the result dictionary from [method GameCommand.execute],
## or an empty dictionary if validation fails.
func submit(command: GameCommand) -> Dictionary:
	return _submit(command, true, true,
			TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY)


## Submits an authoritative command while leaving observer follow-ups queued.
## Network authorities use this so they can broadcast the triggering command
## before draining follow-ups through their submitter/broadcast path.
func submit_deferred_followups(command: GameCommand) -> Dictionary:
	return _submit(command, false, true,
			TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY)


## Applies an already-authoritative network mirror command locally.
## The command still emits [signal command_executed] for UI projection, but
## observer follow-ups are suppressed so passive peers do not synthesize
## duplicate commands.
func submit_mirror(command: GameCommand, result_envelope: Dictionary = {},
		expected_viewer: int = -1) -> Dictionary:
	return _submit(command, true, false,
			TIMING_WINDOW_ORCHESTRATOR.MODE_NETWORK_MIRROR,
			result_envelope, expected_viewer)


## Applies one recorded replay command while preserving its sequence.
func submit_replay(command: GameCommand) -> Dictionary:
	return _submit(command, true, false,
			TIMING_WINDOW_ORCHESTRATOR.MODE_REPLAY)


## Replay-mode authority submission with deferred follow-up draining.
func submit_replay_deferred_followups(command: GameCommand) -> Dictionary:
	return _submit(command, false, false,
			TIMING_WINDOW_ORCHESTRATOR.MODE_REPLAY)


## Runs command preflight checks before command-specific validation.
## Returns an empty string when the command may continue, otherwise the
## rejection reason that should be emitted to callers.
func preflight(command: GameCommand, game_state: GameState) -> String:
	var terminal_reason: String = _check_terminal_admission(
			command, game_state)
	if not terminal_reason.is_empty():
		return terminal_reason
	var faceup_reason: String = _check_faceup_damage_inspection(
			command, game_state)
	if not faceup_reason.is_empty():
		return faceup_reason
	var obstacle_reason: String = _check_obstacle_pre_effect(
			command, game_state)
	if not obstacle_reason.is_empty():
		return obstacle_reason
	var inspection_reason: String = _check_completed_attack_inspection(
			command, game_state)
	if inspection_reason != "":
		return inspection_reason
	var applicability: Dictionary = _check_applicability(command, game_state)
	if not bool(applicability.get(
			COMMAND_APPLICABILITY_SCRIPT.KEY_ALLOWED, false)):
		return str(applicability.get(
				COMMAND_APPLICABILITY_SCRIPT.KEY_REASON, ""))
	return _check_rule_validators(command, game_state)


func _check_terminal_admission(command: GameCommand,
		game_state: GameState) -> String:
	if command == null or game_state == null:
		return ""
	if not game_state.terminal_match_result.is_empty():
		return "The match result is terminal."
	if game_state.detected_terminal_reason().is_empty():
		return ""
	if command.command_type in [
		AcknowledgeFaceupDamageCommand.TYPE,
		AcknowledgeAttackResultCommand.TYPE,
		"resolve_immediate_effect", CompleteAttackCommand.TYPE,
		"ready_ecm", "decline_ecm_ready", CompleteMatchCommand.TYPE,
	]:
		return ""
	return "Terminal cleanup is pending; ordinary gameplay is closed."


func _check_faceup_damage_inspection(command: GameCommand,
		game_state: GameState) -> String:
	if command == null or game_state == null \
			or game_state.faceup_damage_inspection == null:
		return ""
	if command.command_type == AcknowledgeFaceupDamageCommand.TYPE:
		return ""
	return "Faceup damage-card acknowledgment is outstanding."


func _check_obstacle_pre_effect(command: GameCommand,
		game_state: GameState) -> String:
	if command == null or game_state == null:
		return ""
	var ship: ShipInstance = game_state.get_active_ship_activation()
	if ship == null:
		return ""
	var record: Dictionary = ship.pending_obstacle_pre_effect_snapshot()
	if record.is_empty():
		return ""
	if command.command_type == AcknowledgeObstaclePreEffectCommand.TYPE:
		return ""
	if record["received_principal_ids"] != record["required_principal_ids"]:
		return "Obstacle pre-effect acknowledgment is outstanding."
	var expected_type: String = "resolve_%s_overlap" % str(
			record["obstacle_type"])
	if command.command_type != expected_type \
			or command.payload.get("obstacle_id") != record["obstacle_id"]:
		return "Acknowledged obstacle consequence is outstanding."
	return ""


func _check_completed_attack_inspection(command: GameCommand,
		game_state: GameState) -> String:
	if command == null or game_state == null:
		return ""
	var inspection: CompletedAttackInspection = game_state.completed_attack_inspection
	if inspection == null:
		return ""
	if command.command_type == AcknowledgeAttackResultCommand.TYPE:
		return ""
	if not inspection.is_satisfied():
		return "Completed attack result acknowledgement is outstanding."
	if command.command_type == CompleteMatchCommand.TYPE \
			and not game_state.detected_terminal_reason().is_empty():
		return ""
	if command.command_type not in [
		"begin_attack", "skip_attack", "move_squadron",
		DeclineSquadronMoveCommand.TYPE,
		"complete_squadron_activation", "advance_activation_step",
	]:
		return "Completed attack inspection blocks unrelated progression."
	return game_state.validate_completed_attack_inspection_consumer(
			str(command.payload.get("completed_attack_inspection_id", "")))


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
		collect_observers: bool,
		execution_mode: String,
		result_envelope: Dictionary = {},
		expected_viewer: int = -1) -> Dictionary:
	if _is_collecting_observer_followups:
		return _reject_command(command,
				"Observer hooks must return follow-up commands instead of "
				+"submitting.")
	var game_state: GameState = _get_game_state()
	var sequence_reason: String = _validate_sequence_for_mode(
			command, execution_mode)
	if sequence_reason != "":
		return _reject_command(command, sequence_reason, game_state, execution_mode)
	# Only BUG-042 result-aware command classes participate in the strict live
	# semantic schema. Test/local commands may intentionally reuse a registered
	# type name without opting into that wire contract.
	if not command.application_contract_id().is_empty():
		var schema_reason: String = command.validate_exact_semantic_payload()
		if not schema_reason.is_empty():
			return _reject_command(command, schema_reason, game_state, execution_mode)
	var application_result: Dictionary = {}
	var consequence_replacement: Dictionary = {}
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_NETWORK_MIRROR:
		var envelope_validation: Dictionary = _validate_result_envelope(
				command, result_envelope, expected_viewer)
		if not bool(envelope_validation.get("ok", false)):
			return _reject_command(command, str(envelope_validation.get(
					"reason", "Invalid result envelope.")), game_state,
					execution_mode)
		application_result = envelope_validation.get(
			"application_result", {}) as Dictionary
		consequence_replacement = envelope_validation.get(
				"maneuver_consequence_view", {}) as Dictionary
	var flow_snapshot: InteractionFlow = _snapshot_flow(game_state)
	var preflight_reason: String = preflight(command, game_state)
	if preflight_reason != "":
		return _reject_command(command, preflight_reason, game_state, execution_mode)
	var reason: String = command.validate(game_state)
	if reason != "":
		return _reject_command(command, reason, game_state, execution_mode)
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_NETWORK_MIRROR:
		var consequence_error: String = ManeuverConsequenceProjection \
				.pre_mutation_error(game_state, command,
						application_result, consequence_replacement)
		if not consequence_error.is_empty():
			return _reject_command(command, consequence_error,
					game_state, execution_mode)
	var result: Dictionary = _execute_and_record(
			command, game_state, execution_mode, application_result,
			consequence_replacement)
	var execution_failure: String = _execution_failure_reason(result)
	if not execution_failure.is_empty():
		return _reject_command(
				command, execution_failure, game_state, execution_mode)
	if collect_observers \
			and execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			and not is_replaying:
			_collect_observer_followups(
					command, result, game_state, flow_snapshot)
	_enqueue_post_success_continuation(
			game_state, command, result, execution_mode)
	if not is_replaying:
		command_executed.emit(command, result)
		if drain_followups \
				and execution_mode \
						== TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY:
			drain_observer_followups()
	return result


func _enqueue_post_success_continuation(game_state: GameState,
		command: GameCommand,
		result: Dictionary,
		execution_mode: String) -> void:
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			and game_state != null and command != null \
			and command.command_type != CompleteMatchCommand.TYPE \
			and game_state.terminal_match_result.is_empty() \
			and game_state.terminal_result_ready():
		_observer_followups.append(CompleteMatchCommand.new(
				game_state.initiative_player, {}))
		return
	var timing: GameCommand = _timing_continuation(
			game_state, command, result, execution_mode)
	var attack: GameCommand = _attack_continuation(
			game_state, command, result, execution_mode)
	var faceup_immediate: GameCommand = \
			_faceup_automatic_immediate_continuation(
				game_state, command, result, execution_mode)
	var commanded_squadron: GameCommand = \
		_commanded_squadron_completion_continuation(
				game_state, command, execution_mode)
	var declined_move_completion: GameCommand = \
		_declined_move_completion_continuation(
				game_state, command, execution_mode)
	var ship_phase_termination: GameCommand = \
			_ship_phase_termination_continuation(
				game_state, command, result, execution_mode)
	var maneuver: GameCommand = _maneuver_execution_continuation(
			game_state, command, execution_mode)
	var continuation_count: int = int(timing != null) + int(attack != null) \
			+ int(faceup_immediate != null) \
			+ int(commanded_squadron != null) \
			+ int(declined_move_completion != null) \
			+ int(ship_phase_termination != null) + int(maneuver != null)
	if continuation_count > 1:
		_log.warn("Conflicting post-success continuations after [%s]." %
			command.command_type)
	elif timing != null:
		_observer_followups.append(timing)
	elif attack != null:
		_observer_followups.append(attack)
	elif faceup_immediate != null:
		_observer_followups.append(faceup_immediate)
	elif commanded_squadron != null:
		_observer_followups.append(commanded_squadron)
	elif declined_move_completion != null:
		_observer_followups.append(declined_move_completion)
	elif ship_phase_termination != null:
		_observer_followups.append(ship_phase_termination)
	elif maneuver != null:
		_observer_followups.append(maneuver)


## Resumes only a matching choice-less Attack or debug immediate obligation
## after the independent faceup inspection releases. Maneuver remains with its
## existing evaluator; a player choice remains with the source UI.
func _faceup_automatic_immediate_continuation(game_state: GameState,
		command: GameCommand, result: Dictionary,
		execution_mode: String) -> GameCommand:
	if execution_mode != TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			or command == null or game_state == null \
			or command.command_type != AcknowledgeFaceupDamageCommand.TYPE \
			or not bool(result.get("released", false)):
		return null
	var public_ref: String = str(result.get("inspection_id", "")) \
			.trim_prefix("faceup-inspection:")
	return _auto_immediate_for_public_ref(game_state, public_ref)


## Re-derives a released choice-less obligation after full state installation.
## It records no acknowledgment and passive peers never call it.
func derive_reconstructed_faceup_automatic_immediate(
		game_state: GameState) -> GameCommand:
	if game_state == null or game_state.faceup_damage_inspection != null \
			or not game_state.terminal_match_result.is_empty():
		return null
	var candidate: GameCommand = null
	for player: PlayerState in game_state.player_states:
		for ship: ShipInstance in player.ships:
			var record: Dictionary = ship.active_immediate_resolution_snapshot()
			if record.is_empty() or str(record.get("enclosing_kind", "")) \
					not in ["attack", "debug"]:
				continue
			var next: GameCommand = _auto_immediate_for_public_ref(
					game_state, str(record.get("public_card_ref", "")))
			if next == null:
				continue
			if candidate != null:
				return null
			candidate = next
	return candidate


func _auto_immediate_for_public_ref(game_state: GameState,
		public_ref: String) -> GameCommand:
	for owner: int in range(game_state.player_states.size()):
		var player: PlayerState = game_state.get_player_state(owner)
		for index: int in range(player.ships.size()):
			var ship: ShipInstance = game_state.get_ship(owner, index)
			var record: Dictionary = ship.active_immediate_resolution_snapshot()
			if record.get("public_card_ref") != public_ref \
					or str(record.get("enclosing_kind", "")) \
							not in ["attack", "debug"]:
				continue
			var card: DamageCard = ship.faceup_card_for_public_ref(public_ref)
			if card == null or not ImmediateEffectResolver.new() \
					.get_required_choice(card, ship).is_empty():
				return null
			var payload: Dictionary = {
				"owner_player": owner, "ship_index": index,
				"public_card_ref": public_ref,
				"immediate_resolution_id": record["immediate_resolution_id"],
				"enclosing_kind": record["enclosing_kind"],
			}
			if record["enclosing_kind"] == "attack":
				payload["attack_id"] = record["attack_id"]
			else:
				payload["debug_application_id"] = record[
						"debug_application_id"]
			if card.effect_id == "comm_noise":
				payload["comm_noise_action"] = "speed" \
						if ship.current_speed > 0 else "none"
			elif card.effect_id == "shield_failure":
				payload["shield_zones"] = []
			var actor: int = int(record.get("actor_player", -1))
			return CandidateResolveImmediateEffectCommand.new(
				owner if actor == -1 else actor, payload)
	return null


## Purpose-specific ADR-006 re-evaluation. It creates no persisted route or
## generic pending-work structure and never runs on passive/replay peers.
func _maneuver_execution_continuation(game_state: GameState,
		command: GameCommand, execution_mode: String) -> GameCommand:
	if execution_mode != TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			or command == null or game_state == null \
			or command.command_type not in [
				"execute_maneuver", "apply_maneuver_transform",
				"commit_displacement", "resolve_ship_collision_damage",
				"resolve_thruster_fissure", "resolve_damaged_controls",
				"commit_maneuver_obstacle_order", "resolve_asteroid_overlap",
				AcknowledgeObstaclePreEffectCommand.TYPE,
				AcknowledgeFaceupDamageCommand.TYPE,
				CompleteAsteroidOverlapCommand.TYPE,
				"resolve_immediate_effect", "resolve_debris_overlap",
				"resolve_station_overlap", "resolve_ruptured_engine",
			]:
		return null
	var owner: int = int(command.payload.get("owner_player",
			command.player_index))
	var ship_index: int = int(command.payload.get("ship_index", -1))
	if command.command_type in [AcknowledgeObstaclePreEffectCommand.TYPE,
			AcknowledgeFaceupDamageCommand.TYPE]:
		var active: ShipInstance = game_state.get_active_ship_activation()
		if active == null:
			return null
		owner = active.owner_player
		ship_index = game_state.find_ship_index(active)
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	if ship == null or ship.is_destroyed() \
			or not ship.has_active_maneuver_execution():
		return null
	var action: Dictionary = ManeuverExecutionEvaluator.next_action(
			game_state, owner, ship_index)
	if str(action.get("kind", "")) != "command":
		return null
	var command_type: String = str(action.get("command_type", ""))
	var payload: Variant = action.get("payload")
	var actor: Variant = action.get("player_index")
	if command_type.is_empty() or not payload is Dictionary \
			or typeof(actor) != TYPE_INT:
		return null
	return GameCommand._create_by_type(
			command_type, int(actor), payload as Dictionary)


## Preserves the existing phase-transition owner when accepted destruction
## cleanup ends the final legal Ship Phase activation. AdvancePhaseCommand
## remains the only command that advances phase and is recorded afterward.
func _ship_phase_termination_continuation(game_state: GameState,
		command: GameCommand, result: Dictionary,
		execution_mode: String) -> GameCommand:
	if execution_mode != TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			or command == null \
			or not bool(result.get("ship_phase_turn_terminated", false)) \
			or game_state == null \
			or game_state.current_phase != Constants.GamePhase.SHIP \
			or _has_unactivated_ship(game_state):
		return null
	return AdvancePhaseCommand.new(command.player_index, {
		"next_phase": Constants.GamePhase.SQUADRON,
	})


func _has_unactivated_ship(game_state: GameState) -> bool:
	for player_state: PlayerState in game_state.player_states:
		if player_state == null:
			continue
		for raw_ship: Variant in player_state.ships:
			if raw_ship is ShipInstance:
				var ship: ShipInstance = raw_ship as ShipInstance
				if not ship.is_destroyed() and not ship.activated_this_round:
					return true
	return false


## Bounded CON-007 composed-return seam for a completed ship-commanded
## Squadron activation.  GameManager derives only the canonical terminal
## result; this processor remains the sole live-authority submitter.
func _commanded_squadron_completion_continuation(game_state: GameState,
		command: GameCommand,
		execution_mode: String) -> GameCommand:
	if execution_mode != TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			or command == null \
			or command.command_type != CompleteSquadronActivationCommand.TYPE \
			or str(command.payload.get("activation_context", "")) \
					!= SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return null
	return GameManager.derive_commanded_squadron_terminal_transition(
			game_state, command)


## Re-evaluates the same canonical activation after an accepted explicit Move
## decline. Only live authority records the existing terminal command.
func _declined_move_completion_continuation(game_state: GameState,
		command: GameCommand,
		execution_mode: String) -> GameCommand:
	if execution_mode != TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY \
			or command == null \
			or command.command_type != DeclineSquadronMoveCommand.TYPE \
			or game_state == null:
		return null
	var squadron: SquadronInstance = game_state.get_squadron(
			command.player_index,
			int(command.payload.get("squadron_index", -1)))
	if squadron == null \
			or squadron.move_action_disposition \
					!= SquadronInstance.MOVE_ACTION_DECLINED \
			or not game_state.is_squadron_activation_action_complete(squadron):
		return null
	var payload: Dictionary = {
		"squadron_index": int(command.payload.get("squadron_index", -1)),
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
		"completed_attack_inspection_id": "",
	}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		payload["commanding_ship_player"] = squadron.commanding_ship_player
		payload["commanding_ship_index"] = squadron.commanding_ship_index
		payload["ship_activation_identity"] = str(command.payload.get(
				"ship_activation_identity", ""))
	return CompleteSquadronActivationCommand.new(command.player_index, payload)


func _timing_continuation(game_state: GameState,
		command: GameCommand,
		result: Dictionary,
		execution_mode: String) -> GameCommand:
	var processed: Dictionary = TIMING_WINDOW_ORCHESTRATOR \
			.process_successful_command(
					game_state, command, result, execution_mode)
	if not bool(processed.get(TIMING_WINDOW_ORCHESTRATOR.KEY_OK, false)):
		_log.warn("Timing-window orchestration failed after [%s]: %s" % [
			command.command_type,
			str(processed.get(
					TIMING_WINDOW_ORCHESTRATOR.KEY_REASON,
					"unknown failure")),
		])
	return processed.get(
			TIMING_WINDOW_ORCHESTRATOR.KEY_CONTINUATION) as GameCommand


func _attack_continuation(game_state: GameState,
		command: GameCommand,
		result: Dictionary,
		execution_mode: String) -> GameCommand:
	var processed: Dictionary = CURRENT_ATTACK_CONTINUATION \
			.process_successful_command(
					game_state, command, result, execution_mode)
	if not bool(processed.get(CURRENT_ATTACK_CONTINUATION.KEY_OK, false)):
		_log.warn("Current-attack continuation failed after [%s]: %s" % [
			command.command_type,
			str(processed.get(
					CURRENT_ATTACK_CONTINUATION.KEY_REASON,
					"unknown failure")),
		])
	return processed.get(
			CURRENT_ATTACK_CONTINUATION.KEY_CONTINUATION) as GameCommand


## Returns the complete ordered history of executed commands.
func get_history() -> Array[GameCommand]:
	return _history


## Returns the number of commands executed so far.
func get_command_count() -> int:
	return _history.size()


## Returns the sole next-command sequence cursor.
func get_next_sequence() -> int:
	return _next_sequence


## Restores the sole cursor at an accepted reconstruction boundary.
func restore_next_sequence(next_sequence: int) -> bool:
	if next_sequence < 0:
		return false
	if not _history.is_empty() \
			and next_sequence != _history[-1].sequence + 1:
		return false
	_next_sequence = next_sequence
	return true


## Clears history and resets the sequence counter.
## Called at game start / new game.
func reset() -> void:
	_history.clear()
	_frozen_maneuver_consequence_views.clear()
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
	if not game_state.has_valid_match_player_control_binding():
		_log.warn("create_replay: active game state has no valid principal binding.")
		return null
	# Production currently has a reconstruction seam only for full-history
	# replay capture. A non-zero history start requires an accepted canonical
	# initial state paired with the cursor; do not emit an unpaired artifact.
	if (_history.is_empty() and _next_sequence > 0) \
			or (not _history.is_empty() and _history[0].sequence != 0):
		_log.warn("create_replay: reconstructed-state capture is unsupported " \
				+ "without a paired initial GameState.")
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
			game_state.initiative_player,
			0,
			game_state.serialize().get("match_player_control_binding", {}))
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
		submit_replay(cmd)
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
		game_state.interaction_flow,
		game_state)


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
		game_state: GameState,
		execution_mode: String,
		application_result: Dictionary = {},
		consequence_replacement: Dictionary = {}) -> Dictionary:
	var allocated_live_sequence: bool = execution_mode \
			== TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY
	if allocated_live_sequence:
		command.sequence = _next_sequence
	var result: Dictionary
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_NETWORK_MIRROR \
			and not command.application_contract_id().is_empty():
		result = command.execute_with_application_result(
				game_state, application_result)
	else:
		result = command.execute(game_state)
	if not _execution_failure_reason(result).is_empty():
		if allocated_live_sequence:
			command.sequence = -1
		return result
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_NETWORK_MIRROR:
		_install_validated_maneuver_consequence_view(
				game_state, consequence_replacement)
	elif allocated_live_sequence and PlayMode.is_network() \
			and NetworkManager.is_server():
		var frozen: Dictionary = ManeuverConsequenceProjection \
				.capture_authority(game_state)
		assert(ManeuverConsequenceProjection.is_closed_replacement(frozen))
		assert(ManeuverConsequenceProjection.public_state_error(
				game_state, frozen).is_empty())
		_frozen_maneuver_consequence_views[command.sequence] = \
				frozen.duplicate(true)
	_log.info("Executed [%s] seq=%d player=%d." % [
			command.command_type, command.sequence,
			command.player_index])
	_history.append(command)
	_next_sequence += 1
	return result


func frozen_maneuver_consequence_view(sequence: int) -> Dictionary:
	var frozen: Variant = _frozen_maneuver_consequence_views.get(sequence)
	return (frozen as Dictionary).duplicate(true) \
			if frozen is Dictionary else {}


func release_frozen_maneuver_consequence_view(sequence: int) -> void:
	_frozen_maneuver_consequence_views.erase(sequence)


func _install_validated_maneuver_consequence_view(
		state: GameState, replacement: Dictionary) -> void:
	if replacement.is_empty():
		for player: PlayerState in state.player_states:
			for ship: ShipInstance in player.ships:
				if ship != null:
					ship.clear_passive_maneuver_consequence_view()
		return
	var ship: ShipInstance = state.get_ship(
			int(replacement["owner_player"]), int(replacement["ship_index"]))
	assert(ship != null and ship.has_active_maneuver_execution())
	ship.install_validated_passive_maneuver_consequence_view(
			replacement["consequence_view"] as Dictionary)


func _validate_result_envelope(command: GameCommand, envelope: Dictionary,
		expected_viewer: int) -> Dictionary:
	var fields: Array[String] = [
		"protocol_version", "application_contract",
		"application_contract_version", "viewer_player",
		"application_result", "presentation_result",
		"maneuver_consequence_view",
	]
	if envelope.size() != fields.size():
		return {"ok": false, "reason": "Malformed result envelope."}
	for field: String in fields:
		if not envelope.has(field):
			return {"ok": false, "reason": "Malformed result envelope."}
	if typeof(envelope.get("protocol_version")) != TYPE_INT \
			or int(envelope.get("protocol_version")) != NetworkManager.PROTOCOL_VERSION:
		return {"ok": false, "reason": "Result protocol version mismatch."}
	if typeof(envelope.get("viewer_player")) != TYPE_INT \
			or expected_viewer < 0 \
			or int(envelope.get("viewer_player")) != expected_viewer:
		return {"ok": false, "reason": "Result viewer mismatch."}
	if not envelope.get("application_result") is Dictionary \
			or not envelope.get("presentation_result") is Dictionary \
			or not envelope.get("maneuver_consequence_view") is Dictionary \
			or not ManeuverConsequenceProjection.is_closed_replacement(
					envelope["maneuver_consequence_view"] as Dictionary):
		return {"ok": false, "reason": "Malformed result payload."}
	var expected_contract: String = command.application_contract_id()
	var received_contract: String = str(envelope.get("application_contract", ""))
	if expected_contract.is_empty():
		if received_contract != "none" \
				or int(envelope.get("application_contract_version", -1)) != 0 \
				or not (envelope.get("application_result") as Dictionary).is_empty():
			return {"ok": false, "reason": "Unexpected application result."}
	else:
		if received_contract != expected_contract \
				or typeof(envelope.get("application_contract_version")) != TYPE_INT \
				or int(envelope.get("application_contract_version")) \
						!= command.application_contract_version():
			return {"ok": false, "reason": "Application contract mismatch."}
	return {
		"ok": true,
		"application_result": (envelope.get("application_result") as Dictionary),
		"maneuver_consequence_view": (
				envelope.get("maneuver_consequence_view") as Dictionary),
	}


func _execution_failure_reason(result: Dictionary) -> String:
	if result.is_empty():
		return "Command execution returned no result."
	for key: String in ["ok", "success", "accepted"]:
		if result.has(key) and typeof(result.get(key)) == TYPE_BOOL \
				and not bool(result.get(key)):
			return str(result.get(
					"reason", "Command execution reported failure."))
	return ""


func _validate_sequence_for_mode(command: GameCommand,
		execution_mode: String) -> String:
	if command == null:
		return "Command is null."
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY:
		if command.sequence != -1:
			return "Live command must not claim an authoritative sequence."
		return ""
	if execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_NETWORK_MIRROR \
			or execution_mode == TIMING_WINDOW_ORCHESTRATOR.MODE_REPLAY:
		if command.sequence < 0:
			return "Mirrored or replayed command requires a sequence."
		if command.sequence != _next_sequence:
			return "Expected command sequence %d, received %d." % [
				_next_sequence, command.sequence]
		return ""
	return "Unknown command execution mode."


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


func _reject_command(command: GameCommand,
		reason: String,
		game_state: GameState = null,
		execution_mode: String = TIMING_WINDOW_ORCHESTRATOR.MODE_LIVE_AUTHORITY
		) -> Dictionary:
	TIMING_WINDOW_ORCHESTRATOR.process_rejected_command(
			game_state, command, execution_mode)
	_log.warn("Command rejected [%s]: %s" % [
			command.command_type, reason])
	command_rejected.emit(command, reason)
	return {}

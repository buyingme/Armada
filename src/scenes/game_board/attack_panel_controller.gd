## AttackPanelController
##
## Owns the projection-driven attack-panel UI on the game board: the
## read-only [AttackPanelMirror] sync for the non-attacker peer, the
## attacker-side defender-response routing
## ([code]commit_defense[/code], [code]select_evade_die[/code],
## [code]select_redirect_zone[/code], [code]redirect_done[/code],
## [code]resolve_immediate_effect[/code]) into [AttackExecutor], and the
## Attack Simulator toolbar / keyboard toggle.
##
## Extracted from [GameBoard] in refactoring Phase K9 per
## [code]docs/refactoring_phase_k_plan.md[/code].
##
## Cross-controller dependencies are injected in [method initialize].
##
## Rules Reference: "Attack", p.2.
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
class_name AttackPanelController
extends Node


# ---------------------------------------------------------------------------
# Injected references (shared with GameBoard)
# ---------------------------------------------------------------------------

var _attack_executor: AttackExecutor = null
var _panel_mgr: UIPanelManager = null
var _target_selector: TargetSelector = null
var _activation_ctx: ActivationContext = null
var _timing_window_submit_fn: Callable = Callable()


## Initialises the controller with the references it needs to drive the
## attack panel mirror, the attack-executor defender pipeline, and the
## Attack Simulator toggle.
func initialize(
		attack_executor: AttackExecutor,
		panel_mgr: UIPanelManager,
		target_selector: TargetSelector,
		activation_ctx: ActivationContext = null) -> void:
	_attack_executor = attack_executor
	_panel_mgr = panel_mgr
	_target_selector = target_selector
	_activation_ctx = activation_ctx
	EventBus.attack_simulator_requested.connect(
			_on_attack_simulator_requested)


# ---------------------------------------------------------------------------
# Projection-driven defender response routing (Phase I6b-3)
# ---------------------------------------------------------------------------

## Drives the attacker peer's [AttackExecutor] in response to broadcast
## defender commands.  Called from
## [code]GameBoard._on_command_executed_project_ui[/code] for every
## executed [GameCommand].
##
## In hot-seat the attacker peer is also the submitter, so this runs
## right after submission completes.  In network play the defender peer
## submitted the command and the attacker peer's executor reacts here.
func react_to_command(command: GameCommand, result: Dictionary) -> void:
	if command == null:
		return
	if command.command_type == AcknowledgeAttackResultCommand.TYPE:
		_recover_satisfied_ship_attack_presentation()
		return
	if _is_post_attack_presentation_recovery_command(command):
		if not _owns_active_canonical_attack():
			_attack_executor.deactivate_primary_presentation()
		return
	if command.command_type == "skip_attack" \
			and str(command.payload.get("reason", "")) == "squadron_done":
		if not _owns_active_canonical_attack():
			_attack_executor.deactivate_primary_presentation()
		# Let the command processor finish its bounded enclosing-owner
		# re-evaluation first.  If that derives no command, the canonical normal
		# declaration is recoverable through the existing projection seam.
		call_deferred("_recover_post_squadron_done_ship_attack_presentation")
		return
	if not _is_attack_pipeline_command(command):
		return
	_project_terminal_mirror_result(command, result)
	if _attack_executor == null:
		return
	if not _owns_active_canonical_attack() \
			and not _owns_terminal_attack_reaction(command):
		_attack_executor.deactivate_primary_presentation()
		return
	if not _attack_executor.is_in_exec_mode():
		return
	if command.command_type == "begin_attack":
		_attack_executor.apply_begin_attack_result(result)
		return
	if command.command_type == "resolve_attack_pool_choice":
		if str(result.get("choice_kind", "")) \
				== ResolveAttackPoolChoiceCommand.REASON_OBSTRUCTION:
			_attack_executor.apply_obstruction_choice_result(result)
		else:
			_attack_executor.apply_attack_pool_choice_result(result)
		return
	if command.command_type in ["use_concentrate_fire_dial",
			"decline_concentrate_fire_dial"]:
		_attack_executor.apply_concentrate_fire_dial_result(result)
		return
	if command.command_type == "commit_accuracy":
		_attack_executor.apply_accuracy_result(result)
		return
	# Phase I6b-3 R2: [CommitDefenseCommand] — drive the attacker peer
	# through the spend pipeline.
	if command.command_type == "commit_defense":
		var indices_raw: Array = result.get(
				"selected_indices", []) as Array
		var indices: Array[int] = []
		for raw_idx: Variant in indices_raw:
			indices.append(int(raw_idx))
		_attack_executor.apply_defender_commit(indices)
		return
	if command.command_type == "spend_defense_token":
		_attack_executor.apply_defense_token_result(result)
		return
	# Phase I6b-3 R3: [SelectEvadeDieCommand] — drive the attacker peer
	# through the remove-die / reroll-die pipeline.
	if command.command_type == "select_evade_die":
		var die_index: int = int(result.get("die_index", -1))
		if die_index >= 0:
			_attack_executor.apply_defender_evade_die(die_index)
		return
	# Phase I6b-3 R4: [SelectRedirectZoneCommand] — drive the attacker
	# peer through the redirect bookkeeping (decrement remaining +
	# modified_damage, continuation, next-commit).
	if command.command_type == "select_redirect_zone":
		var redirect_zone: int = int(result.get("zone", -1))
		if redirect_zone >= 0:
			_attack_executor.apply_defender_redirect_zone(redirect_zone)
		return
	# Phase I6b-3 R4: [RedirectDoneCommand] — end the redirect sub-step
	# early on the attacker peer.
	if command.command_type == "redirect_done":
		_attack_executor.apply_defender_redirect_done()
		return
	# Phase I6b-3 R5 / L2: [ResolveImmediateEffectCommand] cleanup is
	# idempotent when no pending choice exists, so both hot-seat and network
	# consume the same command-executed reaction.
	if command.command_type == "resolve_immediate_effect":
		_attack_executor.apply_remote_immediate_choice(result)
		return
	if command.command_type == "counter_choice":
		_attack_executor.apply_counter_choice_result(result)
		return
	if command.command_type == "roll_dice":
		_attack_executor.apply_roll_result(command, result)
		return
	if command.command_type == "reroll_attack_die":
		_attack_executor.apply_remote_counter_reroll_result(command, result)
		return
	if command.command_type == "skip_attack_modifier":
		_attack_executor.apply_remote_attack_modifier_skip(command, result)
		return
	if command.command_type == "confirm_attack_dice":
		_attack_executor.apply_remote_attack_confirm(command, result)
		return
	if command.command_type == "resolve_damage":
		_attack_executor.apply_damage_result(result)
		return
	if command.command_type == "complete_attack":
		_attack_executor.apply_complete_attack_result(result)
		return
	if command.command_type == "skip_attack":
		_attack_executor.apply_skip_attack_result(result)


func _project_terminal_mirror_result(
		command: GameCommand, result: Dictionary) -> void:
	if _panel_mgr == null or _panel_mgr.attack_panel_mirror == null:
		return
	if command.command_type == "resolve_damage":
		_panel_mgr.attack_panel_mirror.apply_damage_result(result)
	elif command.command_type == "complete_attack":
		_panel_mgr.attack_panel_mirror.show_resolved_result()


## Routes a targeted authoritative rejection back to the transient declaration
## coordinator. No projection or modal transition is synthesized.
func react_to_command_rejection(
		command: GameCommand, reason: String) -> void:
	if command == null or _attack_executor == null:
		return
	if command.command_type not in ["begin_attack", "skip_attack"]:
		return
	if not _attack_executor.is_in_exec_mode():
		return
	_attack_executor.apply_declaration_command_rejection(command, reason)


# ---------------------------------------------------------------------------
# Attack panel mirror (Phase I6b-3)
# ---------------------------------------------------------------------------

## Opens or closes the [AttackPanelMirror] on the non-attacker peer based on
## canonical attack ownership and the authoritative [InteractionFlow].
##
## The same [AttackSimPanel] UI is rendered on the non-attacker peer from a
## derived flow payload whose dice are refreshed from CurrentAttackState. Only
## defender-owned command inputs are connected on that mirror.
##
## The mirror is the sole interactive attack presentation when the
## authenticated local player differs from
## [member CurrentAttackState.attacker_player]. The primary executor is
## deactivated before the mirror is opened.
##
## Hot-seat is filtered out by the network-peer guard at the call site in
## [ModalRouter].
func sync_mirror_from_flow(
		flow: InteractionFlow,
		attack_dice_results: Array[Dictionary] = []) -> void:
	if _panel_mgr == null or _panel_mgr.attack_panel_mirror == null:
		return
	if _panel_mgr.attack_panel_mirror.is_awaiting_result_acknowledgement():
		return
	var is_attack: bool = (flow != null
			and flow.flow_type == Constants.InteractionFlow.ATTACK)
	if not is_attack:
		_panel_mgr.attack_panel_mirror.close()
		return
	if not _has_active_canonical_attack():
		if _owns_pre_begin_ship_attack_presentation(flow) \
				or (_attack_executor != null \
						and _attack_executor.owns_authoritative_ship_attack_presentation()):
			_panel_mgr.attack_panel_mirror.close()
			return
		if _attack_executor != null:
			_attack_executor.deactivate_primary_presentation()
		_panel_mgr.attack_panel_mirror.close()
		return
	if _owns_active_canonical_attack():
		_panel_mgr.attack_panel_mirror.close()
		return
	if _attack_executor != null:
		_attack_executor.deactivate_primary_presentation()
	var projected_payload: Dictionary = flow.payload.duplicate(true)
	projected_payload["dice_results"] = attack_dice_results.duplicate(true)
	_panel_mgr.attack_panel_mirror.apply_flow(
			projected_payload, int(flow.step_id))


## Refreshes the attacker-owned panel from canonical CurrentAttackState before
## any newly-derived timing-window choice becomes actionable. The executor's
## scene state remains a one-way presentation cache.
func sync_current_attack_dice_projection(
		_attack_dice_results: Array[Dictionary]) -> void:
	if _attack_executor == null or not _owns_active_canonical_attack():
		return
	_attack_executor.refresh_current_attack_dice_projection()


func _owns_active_canonical_attack() -> bool:
	if not _has_active_canonical_attack():
		return false
	var attack: CurrentAttackState = \
			GameManager.current_game_state.current_attack_state
	var local: int = NetworkManager.get_local_player_index()
	return local < 0 or local == attack.attacker_player


func _has_active_canonical_attack() -> bool:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return false
	var attack: CurrentAttackState = game_state.current_attack_state
	return attack != null and attack.active


## Returns whether this peer owns the transient ship target-selection
## presentation before BeginAttack creates canonical CurrentAttackState.
## This gates presentation lifecycle only; semantic command authority remains
## on authoritative command validation.
func _owns_pre_begin_ship_attack_presentation(
		flow: InteractionFlow) -> bool:
	if flow == null \
			or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_DECLARE:
		return false
	if _activation_ctx == null or not _activation_ctx.is_active():
		return false
	var activation: ShipActivationState = \
			_activation_ctx.ship_activation_state
	if activation == null \
			or not activation.is_at_step(ShipActivationState.Step.ATTACK):
		return false
	var token: ShipToken = _activation_ctx.activating_ship_token
	var ship: ShipInstance = token.get_ship_instance() \
			if token != null else null
	if ship == null or activation.get_ship() != ship:
		return false
	if GameManager.get_activating_ship() != ship \
			or GameManager.get_active_player() != ship.owner_player:
		return false
	var local: int = NetworkManager.get_local_player_index()
	return local >= 0 \
			and local == ship.owner_player \
			and flow.controller_player == ship.owner_player


func _owns_terminal_attack_reaction(command: GameCommand) -> bool:
	if command.command_type not in ["complete_attack", "skip_attack"]:
		return false
	var local: int = NetworkManager.get_local_player_index()
	return local < 0 or local == command.player_index


func _is_attack_pipeline_command(command: GameCommand) -> bool:
	return command.command_type in [
		"begin_attack", "resolve_attack_pool_choice",
		"use_concentrate_fire_dial", "decline_concentrate_fire_dial",
		"commit_accuracy", "commit_defense", "spend_defense_token",
		"select_evade_die", "select_redirect_zone", "redirect_done",
		"resolve_immediate_effect", "counter_choice", "roll_dice",
		"reroll_attack_die", "skip_attack_modifier", "confirm_attack_dice",
		"resolve_damage", "complete_attack", "skip_attack",
	]


## These existing consumer commands have already performed any authorised
## semantic continuation.  Their result may only clear the retired attack
## presentation; it must not submit or infer further gameplay progression.
func _is_post_attack_presentation_recovery_command(command: GameCommand) -> bool:
	return command.command_type in [
		CompleteSquadronActivationCommand.TYPE,
		"advance_activation_step",
	]


## A normal ship attack with another legal declaration has a derived-only
## CON-007 release.  Reuse the existing canonical-state projection recovery
## after the final acknowledgement; no command is selected or submitted here.
func _recover_satisfied_ship_attack_presentation() -> void:
	if _attack_executor == null or _target_selector == null:
		return
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	var inspection: CompletedAttackInspection = \
			game_state.completed_attack_inspection
	if inspection == null or not inspection.is_satisfied():
		return
	_attack_executor.resume_inactive_ship_attack_continuation(
				Callable(_target_selector, "ship_token_for_instance"))


## `squadron_done` consumes its inspection as the anti-squadron child closes.
## After the existing command seam has re-evaluated the enclosing owner, a
## remaining normal Ship Attack is a derived-only live decision.  This method
## projects it without deciding legality or submitting a command.
func _recover_post_squadron_done_ship_attack_presentation() -> void:
	if _attack_executor == null or _target_selector == null:
		return
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack != null and attack.active:
		return
	_attack_executor.resume_inactive_ship_attack_continuation(
				Callable(_target_selector, "ship_token_for_instance"))


## Closes the read-only [AttackPanelMirror] if it exists.
func close_mirror() -> void:
	if _panel_mgr == null or _panel_mgr.attack_panel_mirror == null:
		return
	_panel_mgr.attack_panel_mirror.close()


## Applies one fresh viewer-specific timing-window projection to the existing
## attack-panel composition. The panel retains only transient projected intent;
## authoritative legality and lifecycle remain command-side.
func sync_timing_window_projection(
		timing_window: Dictionary,
		submit_fn: Callable) -> void:
	_timing_window_submit_fn = submit_fn
	var primary_panel: AttackSimPanel = _target_selector.get_panel() \
			if _target_selector != null else null
	var mirror_panel: AttackSimPanel = null
	if _panel_mgr != null and _panel_mgr.attack_panel_mirror != null:
		mirror_panel = _panel_mgr.attack_panel_mirror.get_panel()
	_hide_timing_projection(primary_panel)
	if mirror_panel != primary_panel:
		_hide_timing_projection(mirror_panel)
	if timing_window.is_empty():
		return
	var interactive: bool = bool(timing_window.get("is_interactive", false))
	var panel: AttackSimPanel = null
	if _has_active_canonical_attack():
		panel = primary_panel if _owns_active_canonical_attack() else mirror_panel
	else:
		panel = primary_panel if interactive else mirror_panel
	if panel == null:
		panel = mirror_panel if mirror_panel != null else primary_panel
	if panel == null:
		return
	_connect_timing_panel(panel)
	panel.show_timing_window_opportunities(
			timing_window.get("opportunities", []) as Array,
			interactive)


func _hide_timing_projection(panel: AttackSimPanel) -> void:
	if panel != null:
		panel.hide_timing_window_opportunities()


func _connect_timing_panel(panel: AttackSimPanel) -> void:
	var use_callable: Callable = Callable(self, "_on_timing_window_use")
	if not panel.timing_window_use_requested.is_connected(use_callable):
		panel.timing_window_use_requested.connect(use_callable)
	var decline_callable: Callable = Callable(self, "_on_timing_window_decline")
	if not panel.timing_window_decline_requested.is_connected(decline_callable):
		panel.timing_window_decline_requested.connect(decline_callable)


func _on_timing_window_use(intent: Dictionary) -> void:
	_submit_timing_window_intent(intent)


func _on_timing_window_decline(intent: Dictionary) -> void:
	_submit_timing_window_intent(intent)


func _submit_timing_window_intent(intent: Dictionary) -> void:
	if _timing_window_submit_fn.is_valid():
		_timing_window_submit_fn.call(intent.duplicate(true))


# ---------------------------------------------------------------------------
# Attack Simulator toolbar / keyboard toggle
# ---------------------------------------------------------------------------

## Delegates the Attack Simulator toolbar / keyboard toggle to the
## [TargetSelector].
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
func _on_attack_simulator_requested() -> void:
	if _target_selector:
		_target_selector.on_simulator_requested()

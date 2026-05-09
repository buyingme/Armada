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


## Initialises the controller with the references it needs to drive the
## attack panel mirror, the attack-executor defender pipeline, and the
## Attack Simulator toggle.
func initialize(
		attack_executor: AttackExecutor,
		panel_mgr: UIPanelManager,
		target_selector: TargetSelector) -> void:
	_attack_executor = attack_executor
	_panel_mgr = panel_mgr
	_target_selector = target_selector
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
	if _attack_executor == null or not _attack_executor.is_in_exec_mode():
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
	# Phase I6b-3 R5: [ResolveImmediateEffectCommand] — when the chooser
	# was the remote peer, the local (attacker) executor still owns the
	# post-modal cleanup + finalize.  Hot-seat skips this branch
	# (chooser modal runs in-process).
	# Phase K allow-list: session-mode dispatcher (plan §3.1a) — there
	# is no "remote peer" concept in hot-seat by definition.
	if command.command_type == "resolve_immediate_effect" \
			and PlayMode.is_network():
		_attack_executor.apply_remote_immediate_choice(result)


# ---------------------------------------------------------------------------
# Read-only attack panel mirror (Phase I6b-3 R1b)
# ---------------------------------------------------------------------------

## Opens or closes the read-only [AttackPanelMirror] on the non-attacker
## peer based on the authoritative [InteractionFlow].
##
## The same [AttackSimPanel] UI is rendered on the passive peer,
## populated entirely from [member InteractionFlow.payload].  Input
## signals are NEVER connected on the mirror — the panel is
## informational.  Defender-driven input (defense-token toggle, evade
## target, redirect zone) is migrated to commands separately.
##
## The mirror is shown when:
##   * [code]flow.flow_type == Constants.InteractionFlow.ATTACK[/code]
##   * the local viewer is **not** the attacker
##     (either the published [code]attacker_player[/code] differs from
##     [param local], or — defensively — the local executor is not in
##     exec mode).
##
## Hot-seat is filtered out by the [code]is_network()[/code] guard at
## the call site in [GameBoard].
func sync_mirror_from_flow(flow: InteractionFlow, local: int) -> void:
	if _panel_mgr == null or _panel_mgr.attack_panel_mirror == null:
		return
	var is_attack: bool = (flow != null
			and flow.flow_type == Constants.InteractionFlow.ATTACK)
	if not is_attack:
		_panel_mgr.attack_panel_mirror.close()
		return
	var attacker_player: int = int(
			flow.payload.get("attacker_player", -1))
	var local_is_attacker: bool = (
			attacker_player >= 0 and attacker_player == local)
	# Defensive fall-back when the identity patch hasn't been applied yet
	# (very early in the flow): treat the local executor's exec-mode as
	# the source of truth.
	if attacker_player < 0 and _attack_executor != null \
			and _attack_executor.is_in_exec_mode():
		local_is_attacker = true
	if local_is_attacker:
		_panel_mgr.attack_panel_mirror.close()
		return
	_panel_mgr.attack_panel_mirror.apply_flow(
			flow.payload, int(flow.step_id))


# ---------------------------------------------------------------------------
# Attack Simulator toolbar / keyboard toggle
# ---------------------------------------------------------------------------

## Delegates the Attack Simulator toolbar / keyboard toggle to the
## [TargetSelector].
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005.
func _on_attack_simulator_requested() -> void:
	if _target_selector:
		_target_selector.on_simulator_requested()

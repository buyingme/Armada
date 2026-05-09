## ShipActivationController
##
## Owns the ship-activation modal lifecycle, dial-drop entry points, the
## Crew Panic [code]BEFORE_REVEAL_DIAL[/code] choice modal, the activation-
## sequence button, and the projection-driven open/close + step-sync helpers.
##
## Extracted from [GameBoard] in refactoring Phase K8a per
## [code]docs/refactoring_phase_k_plan.md[/code]. Maneuver execution and
## overlap resolution remain on [GameBoard] and will move in K8b.
##
## Cross-controller dependencies (game_board utility helpers, panels,
## damage deck, dial drag controller) are injected as references and
## [Callable]s in [method initialize].
##
## Rules Reference: "Ship Activation", p.16; "Crew Panic" card text.
class_name ShipActivationController
extends Node


# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------

var _log: GameLogger = GameLogger.new("ShipActivation")


# ---------------------------------------------------------------------------
# Owned state (Crew Panic)
# ---------------------------------------------------------------------------

## Ship instance for the pending Crew Panic choice (stored independently of
## the drag controller's state because no drag is active during the modal).
var _pending_crew_panic_ship: ShipInstance = null

## Pending ship key for the Crew Panic choice callback.
var _pending_crew_panic_ship_key: String = ""

## Lazily created OpponentChoiceModal for the Crew Panic prompt.
var _crew_panic_modal: OpponentChoiceModal = null


# ---------------------------------------------------------------------------
# Injected references (shared with GameBoard)
# ---------------------------------------------------------------------------

var _activation_ctx: ActivationContext = null
var _panel_mgr: UIPanelManager = null
var _attack_executor: AttackExecutor = null
var _squadron_phase_controller: SquadronPhaseController = null
var _damage_deck: DamageDeck = null
var _dial_drag_controller: DialDragController = null


# ---------------------------------------------------------------------------
# Callables back into GameBoard
# ---------------------------------------------------------------------------

## (ship: ShipInstance) -> ShipToken
var _find_ship_token_for_instance: Callable = Callable()

## (token: Variant) -> bool
var _has_repair_resources: Callable = Callable()

## (token: Variant) -> bool
var _has_squadron_resources: Callable = Callable()

## (token: Variant) -> bool
var _is_squadron_token_only: Callable = Callable()

## (ship: ShipInstance, persistent_effect_id: String) -> void
var _submit_persistent_damage: Callable = Callable()

## (result: Dictionary) -> bool
var _is_pending_remote_result: Callable = Callable()

## () -> bool
var _is_local_squadron_modal_controller: Callable = Callable()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores all injected references and connects EventBus + DialDragController
## signals. Must be called once after the controller is added to the scene
## tree, before any activation flow begins.
##
## [param dial_drag_controller] is wired by the caller AFTER this call by
## connecting [signal DialDragController.ship_activated] /
## [signal DialDragController.token_converted] to
## [method on_dial_ship_activated] / [method on_dial_token_converted].
func initialize(
		activation_ctx: ActivationContext,
		panel_mgr: UIPanelManager,
		attack_executor: AttackExecutor,
		squadron_phase_controller: SquadronPhaseController,
		damage_deck: DamageDeck,
		dial_drag_controller: DialDragController,
		find_ship_token_for_instance: Callable,
		has_repair_resources: Callable,
		has_squadron_resources: Callable,
		is_squadron_token_only: Callable,
		submit_persistent_damage: Callable,
		is_pending_remote_result: Callable,
		is_local_squadron_modal_controller: Callable) -> void:
	_activation_ctx = activation_ctx
	_panel_mgr = panel_mgr
	_attack_executor = attack_executor
	_squadron_phase_controller = squadron_phase_controller
	_damage_deck = damage_deck
	_dial_drag_controller = dial_drag_controller
	_find_ship_token_for_instance = find_ship_token_for_instance
	_has_repair_resources = has_repair_resources
	_has_squadron_resources = has_squadron_resources
	_is_squadron_token_only = is_squadron_token_only
	_submit_persistent_damage = submit_persistent_damage
	_is_pending_remote_result = is_pending_remote_result
	_is_local_squadron_modal_controller = is_local_squadron_modal_controller
	_connect_signals()
	# Activation modal "modal_closed" signal moved here from
	# game_board._connect_panel_signals.  The other activation modal
	# signals (maneuver_step_entered, attack_step_entered, ...) stay on
	# GameBoard until the K8b extraction.
	if _panel_mgr != null and _panel_mgr.activation_modal != null:
		_panel_mgr.activation_modal.modal_closed.connect(
				_on_activation_modal_closed)


## DialDragController signal callback.  Called when the player drops the
## dial on the owning ship token.  Sets up activation state and shows the
## activation-sequence button.
## Requirements: UI-024, UI-025, SP-010, ACT-007, FLOW-002.
func on_dial_ship_activated(token: ShipToken, ship: ShipInstance) -> void:
	GameManager.activate_ship(ship)
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		token.show_revealed_dial(cmd)
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)
	show_activation_sequence_button()
	_log.info("Ship activated via dial drop: '%s'." % ship.data_key)


## DialDragController signal callback.  Called when the player drops the
## dial on the owning ship's card-panel entry.  Converts the dial to a
## command token.
## Rules Reference: "Command Dials", p.3 — "spend the command dial to gain
## a command token of the same type."
## Requirements: UI-028, SP-011, CM-004–006.
func on_dial_token_converted(ship: ShipInstance) -> void:
	# Set up activation context BEFORE submitting the command so that the
	# activation_modal_open interaction-state callback (which fires
	# synchronously via call_local RPC inside NetworkHostCommandSubmitter)
	# can find the context.
	var token: ShipToken = _find_ship_token_for_instance.call(ship) as ShipToken
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar:
		_panel_mgr.activation_sidebar.highlight_active(ship)

	var result: Dictionary = GameManager.activate_ship_as_token(ship)

	# Network mode: modal lifecycle is driven by interaction-state updates.
	# activation_modal_open  → open_modal_from_interaction_state()
	# wait_for_ship_select   → close_modal_from_interaction_state()
	# No need to show the sequence button or open the modal here.
	if bool(_is_pending_remote_result.call(result)):
		_log.info("Ship activated via card drop (token convert): '%s' " \
				% [ship.data_key if ship else "?"] \
				+"(awaiting server result).")
		return

	var needs_discard: bool = result.get("needs_discard", false)
	if needs_discard:
		# Delay activation sequence button until the discard is resolved.
		if not EventBus.token_discarded.is_connected(
				_on_token_discard_resolved):
			EventBus.token_discarded.connect(
					_on_token_discard_resolved, CONNECT_ONE_SHOT)
	elif not PlayMode.is_network():
		# Hot-seat: show the sequence button; network uses interaction state.
		# Phase K allow-list: session-mode dispatcher (plan §3.1a, §3.1d).
		# Hot-seat opens the sequence button locally; network drives it
		# via the projected interaction flow.  Converging is a Phase L
		# candidate.
		show_activation_sequence_button()

	var cmd_name: String = ""
	if not result.is_empty():
		cmd_name = Constants.CommandType.keys()[result["command"]]
	_log.info("Ship activated via card drop (token convert): '%s' (%s, added=%s, discard=%s)." % [
			ship.data_key if ship else "?", cmd_name,
			str(result.get("token_added", false)),
			str(needs_discard)])


## Checks if BEFORE_REVEAL_DIAL effects need to fire (Crew Panic).
## Called from [DialDragController] via callable BEFORE the drag begins.
## Returns true if a modal was shown (drag will start — or not — in the
## callback).
## Rules Reference: "Crew Panic" card text — "Before you reveal a command
## dial, you must either suffer 1 damage or discard that dial.  If you
## discard it, do not reveal a dial this round."
func check_crew_panic_before_drag(ship: ShipInstance) -> bool:
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry == null:
		return false
	if ship == null:
		return false
	var effects: Array[GameEffect] = registry.get_effects_for_hook(
			&"BEFORE_REVEAL_DIAL")
	var has_crew_panic: bool = false
	for eff: GameEffect in effects:
		if eff is DamageCardEffect:
			var dce: DamageCardEffect = eff as DamageCardEffect
			if dce.effect_id == "crew_panic" and dce.owner == ship:
				has_crew_panic = true
				break
	if not has_crew_panic:
		return false
	# Store ship independently — no drag is active yet.
	_pending_crew_panic_ship = ship
	_pending_crew_panic_ship_key = ship.data_key
	var choice_info: Dictionary = {
		"choice_type": "crew_panic",
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"card_title": "Crew Panic",
		"effect_text": "Before you reveal a command dial, you must either "
				+"suffer 1 damage or discard that dial. If you discard it, "
				+"do not reveal a dial this round.",
		"options": [
			{"id": "discard_card", "label": "Discard command dial",
					"available": true},
			{"id": "suffer_damage", "label": "Suffer 1 facedown damage",
					"available": true},
		],
	}
	_ensure_crew_panic_modal()
	if not _crew_panic_modal.choice_confirmed.is_connected(
			_on_crew_panic_choice):
		_crew_panic_modal.choice_confirmed.connect(
				_on_crew_panic_choice, CONNECT_ONE_SHOT)
	_crew_panic_modal.open(choice_info)
	_log.info("Crew Panic — showing choice modal for %s." % ship.data_key)
	return true


## Hides all Phase 5b UI elements (activation button, modal). Called from
## [code]GameBoard._on_phase_changed[/code].
func hide_phase5b_ui() -> void:
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.close_and_clear()
	if _activation_ctx.activating_ship_token:
		_activation_ctx.activating_ship_token.hide_revealed_dial()
	_activation_ctx.clear()


## Shows the "Show Activation Sequence" button at bottom-centre.
## Replaces the old direct "End Activation" after dial reveal.
## Requirements: ACT-007, FLOW-002.
func show_activation_sequence_button() -> void:
	if _panel_mgr.show_activation_button == null:
		return
	_panel_mgr.show_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.show_activation_button.update_position(vp_size)


## Shows and positions the End Activation button. Called from K8b
## leftovers (currently unused — kept for future re-introduction).
func show_end_activation_button() -> void:
	if _panel_mgr.end_activation_button == null:
		return
	_panel_mgr.end_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.end_activation_button.update_position(vp_size)


## Applies dynamic skip/interactable flags and opens the activation modal.
## Public so K8b leftovers (squadron-step skipped, repair done, attack
## exec completed/cancelled, sequence requested, end-of-maneuver) can
## still call it.
func configure_and_open_activation_modal() -> void:
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return
	if _activation_ctx.ship_activation_state == null:
		return
	_panel_mgr.activation_modal.set_squadron_skippable(
			not bool(_has_squadron_resources.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_squadron_token_only(
			bool(_is_squadron_token_only.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_repair_skippable(
			not bool(_has_repair_resources.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_attack_skippable(
			not _attack_executor.has_any_attack_target(
					_activation_ctx.activating_ship_token))
	update_activation_modal_interactivity()
	_panel_mgr.activation_modal.open(_activation_ctx.ship_activation_state)


## Applies current controller authority to activation and squadron modals.
func update_activation_modal_interactivity() -> void:
	var ship_is_controller: bool = _is_local_activation_modal_controller()
	if _panel_mgr != null and _panel_mgr.activation_modal != null:
		_panel_mgr.activation_modal.set_interactable(ship_is_controller)
	if _squadron_phase_controller != null:
		var sq_is_controller: bool = bool(
				_is_local_squadron_modal_controller.call())
		_squadron_phase_controller.set_modal_interactable(sq_is_controller)


## Applies authoritative ship-activation step snapshots from the
## [GameState.interaction_flow] domain field.
## This keeps modal checkmarks synchronized across peers even when local UI
## flows differ.
func sync_activation_step_from_flow(flow: InteractionFlow) -> void:
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return
	if _activation_ctx.ship_activation_state == null:
		return
	var target_step: int = -1
	match flow.step_id:
		Constants.InteractionStep.SQUADRON_STEP:
			target_step = ShipActivationState.Step.SQUADRON
		Constants.InteractionStep.REPAIR_STEP:
			target_step = ShipActivationState.Step.REPAIR
		Constants.InteractionStep.ATTACK_STEP:
			target_step = ShipActivationState.Step.ATTACK
		Constants.InteractionStep.MANEUVER_STEP:
			target_step = ShipActivationState.Step.MANEUVER
		Constants.InteractionStep.ACTIVATION_DONE:
			target_step = ShipActivationState.Step.DONE
		_:
			return
	_activation_ctx.ship_activation_state.set_current_step(
			target_step as ShipActivationState.Step)
	if _panel_mgr.activation_modal and _panel_mgr.activation_modal.is_open():
		_panel_mgr.activation_modal.refresh()


## Submits an authoritative activation-step transition marker in network mode.
func submit_network_activation_step(step_id: String) -> void:
	# Phase K allow-list: session-mode dispatcher (plan §3.1a).  This
	# helper is network-only by name and purpose — it submits an
	# `advance_activation_step` command so the remote peer can sync
	# its `ShipActivationState`.  Hot-seat has no remote peer.
	if not PlayMode.is_network() or _activation_ctx.ship_activation_state == null:
		return
	var ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	if ship == null:
		return
	GameManager.submit_advance_activation_step(ship, step_id)


## Opens the activation modal in response to an authoritative
## interaction-state update (step_id == "activation_modal_open").
## The controller peer runs the full flow with auto-skip; the passive peer
## gets a mirror view with no auto-skip so the first step is held until the
## next interaction-state update advances it.
##
## If the activating ship has overflow command tokens (more tokens than its
## command value), the modal open is deferred until [signal
## EventBus.token_discarded] fires.  Mirrors the hot-seat gating in
## [method on_dial_token_converted].
## Rules Reference: "Command Tokens", p.4 — overflow discard.
func open_modal_from_interaction_state() -> void:
	if _activation_ctx.ship_activation_state == null:
		return
	if _has_pending_token_overflow_discard():
		if not EventBus.token_discarded.is_connected(
				_on_overflow_discard_open_modal):
			EventBus.token_discarded.connect(
					_on_overflow_discard_open_modal, CONNECT_ONE_SHOT)
		_log.info("Activation modal open deferred — pending command-token " \
				+"overflow discard.")
		return
	var is_controller: bool = _is_local_activation_modal_controller()
	if is_controller:
		configure_and_open_activation_modal()
	else:
		_open_activation_modal_mirror()
	# Always show the "Show Activation Sequence" button so both peers can
	# re-open the modal if they close it manually.
	show_activation_sequence_button()


## Closes the activation modal and cleans up activation state in response to
## an authoritative interaction-state update (step_id == "wait_for_ship_select").
## Safe to call even if the modal is already closed (idempotent).
func close_modal_from_interaction_state() -> void:
	_on_board_activation_ended()


# ---------------------------------------------------------------------------
# Internal helpers — modal lifecycle
# ---------------------------------------------------------------------------

## Returns true if the activating ship currently holds more command tokens
## than its command value, requiring a discard before the activation modal
## may open.
func _has_pending_token_overflow_discard() -> bool:
	if _activation_ctx.ship_activation_state == null:
		return false
	var ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	if ship == null or ship.command_tokens == null:
		return false
	return ship.command_tokens.get_token_count() \
			> ship.command_tokens.max_tokens


## One-shot listener: re-runs the modal open after an overflow discard.
func _on_overflow_discard_open_modal(_ship: RefCounted,
		_discarded: int) -> void:
	open_modal_from_interaction_state()
	_log.info("Overflow discard resolved — opening activation modal.")


## Opens the activation modal without running auto-skip.
## Used for the passive (non-controller) peer who mirrors the active
## player's activation sequence and must not advance steps locally.
func _open_activation_modal_mirror() -> void:
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return
	if _activation_ctx.ship_activation_state == null:
		return
	_panel_mgr.activation_modal.set_squadron_skippable(
			not bool(_has_squadron_resources.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_squadron_token_only(
			bool(_is_squadron_token_only.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_repair_skippable(
			not bool(_has_repair_resources.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_attack_skippable(
			not _attack_executor.has_any_attack_target(
					_activation_ctx.activating_ship_token))
	update_activation_modal_interactivity()
	_panel_mgr.activation_modal.open_mirror(
			_activation_ctx.ship_activation_state)


## Returns whether the local player may interact with ActivationModal
## controls.
##
## Phase I6d: routes through [UIProjector] so hot-seat and network share
## the same authority projection.  In hot-seat the local viewer is always
## the active player, so [member UIIntent.is_interactive] is [code]true[/code]
## whenever a flow is active.  Pre-flow (game start, between rounds), falls
## back to [code]active_player == local[/code] which preserves the prior
## permissive behaviour.
func _is_local_activation_modal_controller() -> bool:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return true
	var local: int = _local_viewer()
	var flow: InteractionFlow = gs.interaction_flow
	if flow == null or flow.flow_type == Constants.InteractionFlow.NONE:
		return GameManager.get_active_player() == local
	return flow.controller_player == local


## Returns the player index whose perspective is shown locally on this
## peer.  Mirror of [code]GameBoard._local_viewer[/code]; duplicated to
## avoid an extra Callable injection.
func _local_viewer() -> int:
	var idx: int = NetworkManager.get_local_player_index()
	if idx < 0:
		return GameManager.get_active_player()
	return idx


# ---------------------------------------------------------------------------
# Internal handlers — EventBus + DialDragController callbacks
# ---------------------------------------------------------------------------

## Subscribes to EventBus signals owned by this controller.
func _connect_signals() -> void:
	# Activation lifecycle.
	EventBus.activation_ended.connect(_on_board_activation_ended)
	# Network passive-peer modal mirroring (C7/C8).
	if not EventBus.ship_activated_remotely.is_connected(
			_on_remote_ship_activated):
		EventBus.ship_activated_remotely.connect(_on_remote_ship_activated)


## Opens the activation modal as a read-only observer on the passive peer.
## Called when the opponent activates a ship in network mode (either via
## dial-to-ship-token [ActivateShipCommand] or dial-to-card-panel
## [ConvertDialToTokenCommand]).  Sets up [member _activation_ctx] and
## opens the mirror modal so the passive peer sees the same activation
## sequence.  G4.6.6 T1a C7.
##
## Phase I6a: also opens the mirror modal here.  Because
## [code]gs.interaction_flow.step_id[/code] already equals
## [code]ACTIVATION_MODAL_OPEN[/code] at this point (set inside the
## command's [code]execute()[/code]) [code]open_mirror[/code] does
## not auto-skip, so no flashing occurs.
func _on_remote_ship_activated(ship: ShipInstance) -> void:
	if ship == null:
		return
	var token: ShipToken = _find_ship_token_for_instance.call(ship) as ShipToken
	if token == null:
		_log.warn("_on_remote_ship_activated: token not found for ship %s"
				% ship.data_key)
		return
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)
	open_modal_from_interaction_state()


## Called when End Activation is pressed — cleans up the dial sprite on
## the board, activation modal, and resets activation visual state.
## Requirements: UI-026, FLOW-002.
func _on_board_activation_ended() -> void:
	if _activation_ctx.activating_ship_token:
		_activation_ctx.activating_ship_token.hide_revealed_dial()
	_activation_ctx.clear()
	_panel_mgr.end_activation_button.hide_button()
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.close_and_clear()
	_squadron_phase_controller.hide_ui()
	if _panel_mgr.activation_sidebar:
		_panel_mgr.activation_sidebar.clear_active()
		_panel_mgr.activation_sidebar.refresh()
	# Maneuver/range tool dismissal stays on GameBoard for K8a — emitted
	# via EventBus so GameBoard handles cleanup.  Placeholder: emit
	# directly here once K8b lands.  For now we rely on GameBoard's own
	# subscription to EventBus.activation_ended (which the call below
	# triggers via the same signal — no, this method *is* the handler).
	# Instead: call the same EventBus signals the original code used.
	EventBus.maneuver_tool_dismissed.emit()
	EventBus.range_overlay_dismissed.emit()
	# Re-enable simulation tool buttons.
	if _panel_mgr.action_toolbar:
		_panel_mgr.action_toolbar.set_tool_buttons_disabled(false)


## Called when the activation modal is dismissed (Escape or ✕ Close).
## Re-shows the "Show Activation Sequence" button so the player can
## reopen, unless the attack panel is currently active (same screen
## position).
func _on_activation_modal_closed() -> void:
	_log.info("Activation modal dismissed by player.")
	if _activation_ctx.ship_activation_state == null \
			or _panel_mgr.show_activation_button == null:
		return
	# Do not show the button while the attack executor is active —
	# both occupy the same bottom-centre position.
	if _attack_executor and _attack_executor.is_in_exec_mode():
		return
	# Do not show the button while the squadron command modal is active.
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_modal_visible() \
			and _squadron_phase_controller.is_command_mode():
		return
	_panel_mgr.show_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.show_activation_button.update_position(vp_size)


# ---------------------------------------------------------------------------
# Internal handlers — Crew Panic
# ---------------------------------------------------------------------------

## Finishes activation when Crew Panic discarded the dial.
## The revealed dial is spent (moved to the discarded pile) and the ship
## activates without any command available this round.  No drag is active
## — the ship is passed directly from the callback.
## Rules Reference: "Crew Panic" — "discard that dial … do not reveal a
## dial this round."
func _finish_crew_panic_dial_discarded(
		ship: ShipInstance, ship_key: String) -> void:
	# Spend the already-revealed dial so it moves to the discarded pile.
	if ship and ship.command_dial_stack:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty():
			GameManager.submit_spend_dial(ship, "spend")
		else:
			GameManager.submit_spend_dial(ship, "discard")
	GameManager.force_activate_ship(ship)
	var act_token: ShipToken = _find_ship_token_for_instance.call(ship) as ShipToken
	_activation_ctx.set_active(act_token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)
	show_activation_sequence_button()
	_log.info("Ship activated (dial discarded by Crew Panic): '%s'."
			% ship_key)


## Callback when the player makes their Crew Panic choice.
## No drag is active — the ship is stored in [member _pending_crew_panic_ship].
## On "discard dial": spend the revealed dial, activate ship without command.
## On "suffer damage": resolve the hook, then start the dial drag.
func _on_crew_panic_choice(selection: Dictionary) -> void:
	var ship: ShipInstance = _pending_crew_panic_ship
	var ship_key: String = _pending_crew_panic_ship_key
	_pending_crew_panic_ship = null
	_pending_crew_panic_ship_key = ""
	if ship == null:
		_log.error("Crew Panic choice callback but no pending ship!")
		return
	var chose_discard: bool = str(selection.get("id", "")) == "discard_card"
	# Resolve the BEFORE_REVEAL_DIAL hook with the player's choice.
	var dial_discarded: bool = false
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry:
		var ctx: EffectContext = EffectContext.new()
		ctx.set_meta_value("ship", ship)
		ctx.set_meta_value("damage_deck", _damage_deck)
		ctx.set_meta_value("dial_discarded", chose_discard)
		ctx.set_meta_value("effect_registry", registry)
		registry.resolve_hook(&"BEFORE_REVEAL_DIAL", ctx)
		dial_discarded = ctx.get_meta_value(
				"crew_panic_dial_discarded", false) as bool
		if ctx.get_meta_value("extra_damage_dealt", false) as bool:
			_submit_persistent_damage.call(ship,
					str(ctx.get_meta_value("persistent_effect_id", "")))
	if dial_discarded:
		_finish_crew_panic_dial_discarded(ship, ship_key)
	else:
		# Player chose to suffer damage — resume the normal drag flow.
		_dial_drag_controller.start_dial_drag(ship)


## Lazily creates the Crew Panic choice modal.
func _ensure_crew_panic_modal() -> void:
	if _crew_panic_modal != null:
		return
	_crew_panic_modal = OpponentChoiceModal.new()
	_crew_panic_modal.name = "CrewPanicModal"
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CrewPanicModalLayer"
	layer.layer = 95
	add_child(layer)
	layer.add_child(_crew_panic_modal)


## Called (one-shot) when the player resolves a token overflow discard.
## Shows the activation sequence button now that the token count is legal.
func _on_token_discard_resolved(_ship: RefCounted, _discarded: int) -> void:
	show_activation_sequence_button()
	_log.info("Token discard resolved — showing activation sequence button.")

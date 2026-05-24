## ShipActivationController
##
## Owns the ship-activation modal lifecycle, dial-drop entry points, the
## Crew Panic pre-reveal choice modal, the activation-sequence button, and
## the projection-driven open/close + step-sync helpers.
##
## Extracted from [GameBoard] in refactoring Phase K8a (modal lifecycle,
## dial-drop entry, Crew Panic) and K8b (activation step routing,
## maneuver execute, ship–ship overlap resolution) per
## [code]docs/refactoring_phase_k_plan.md[/code].
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

## Transient guard for projected Repair auto-advance command submission.
var _repair_auto_advance_pending: bool = false

## Transient guard for projected no-target Attack auto-advance submission.
var _attack_auto_advance_pending: bool = false


# ---------------------------------------------------------------------------
# Injected references (shared with GameBoard)
# ---------------------------------------------------------------------------

var _activation_ctx: ActivationContext = null
var _panel_mgr: UIPanelManager = null
var _attack_executor: AttackExecutor = null
var _squadron_phase_controller: SquadronPhaseController = null
var _damage_deck: DamageDeck = null
var _dial_drag_controller: DialDragController = null
var _maneuver_tool_controller: ManeuverToolController = null
var _displacement_controller: DisplacementController = null


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

## (ship: ShipInstance, persistent_effect_id: String) -> Dictionary
var _submit_persistent_damage: Callable = Callable()

## (result: Dictionary) -> bool
var _is_pending_remote_result: Callable = Callable()

## () -> bool
var _is_local_squadron_modal_controller: Callable = Callable()

## () -> Array[ShipToken]
var _get_ship_tokens: Callable = Callable()

## () -> Array[SquadronToken]
var _get_squadron_tokens: Callable = Callable()

## () -> void — dismiss the activation maneuver tool with Navigate preview reset.
var _dismiss_maneuver_tool_with_preview: Callable = Callable()


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
		maneuver_tool_controller: ManeuverToolController,
		displacement_controller: DisplacementController,
		find_ship_token_for_instance: Callable,
		has_repair_resources: Callable,
		has_squadron_resources: Callable,
		is_squadron_token_only: Callable,
		submit_persistent_damage: Callable,
		is_pending_remote_result: Callable,
		is_local_squadron_modal_controller: Callable,
		get_ship_tokens: Callable,
		get_squadron_tokens: Callable,
		dismiss_maneuver_tool_with_preview: Callable) -> void:
	_activation_ctx = activation_ctx
	_panel_mgr = panel_mgr
	_attack_executor = attack_executor
	_squadron_phase_controller = squadron_phase_controller
	_damage_deck = damage_deck
	_dial_drag_controller = dial_drag_controller
	_maneuver_tool_controller = maneuver_tool_controller
	_displacement_controller = displacement_controller
	_find_ship_token_for_instance = find_ship_token_for_instance
	_has_repair_resources = has_repair_resources
	_has_squadron_resources = has_squadron_resources
	_is_squadron_token_only = is_squadron_token_only
	_submit_persistent_damage = submit_persistent_damage
	_is_pending_remote_result = is_pending_remote_result
	_is_local_squadron_modal_controller = is_local_squadron_modal_controller
	_get_ship_tokens = get_ship_tokens
	_get_squadron_tokens = get_squadron_tokens
	_dismiss_maneuver_tool_with_preview = dismiss_maneuver_tool_with_preview
	_connect_signals()
	_connect_panel_signals()


## Connects activation-modal, repair-panel, show-activation-button,
## attack-executor, squadron-phase-controller, and displacement-controller
## signals to the controller's internal handlers.  Called from
## [method initialize] so the GameBoard does not need to know about them.
func _connect_panel_signals() -> void:
	if _panel_mgr != null and _panel_mgr.activation_modal != null:
		var modal: ActivationModal = _panel_mgr.activation_modal
		modal.modal_closed.connect(_on_activation_modal_closed)
		modal.maneuver_step_entered.connect(_on_maneuver_step_entered)
		modal.maneuver_commit_requested.connect(_on_execute_maneuver)
		modal.attack_step_entered.connect(_on_attack_step_entered)
		modal.repair_step_entered.connect(_on_repair_step_entered)
		modal.squadron_step_entered.connect(_on_squadron_step_entered)
		modal.squadron_step_skipped.connect(_on_squadron_step_skipped)
		modal.end_activation_requested.connect(_on_activation_end_requested)
	if _panel_mgr != null and _panel_mgr.repair_panel != null:
		_panel_mgr.repair_panel.repair_done.connect(_on_repair_done)
		_panel_mgr.repair_panel.repair_skipped.connect(_on_repair_done)
	if _panel_mgr != null and _panel_mgr.show_activation_button != null:
		_panel_mgr.show_activation_button.activation_sequence_requested.connect(
				_on_activation_sequence_requested)
	if _attack_executor != null:
		_attack_executor.attack_exec_completed.connect(
				_on_attack_exec_completed)
		_attack_executor.attack_exec_cancelled.connect(
				_on_attack_exec_cancelled)
	if _squadron_phase_controller != null:
		_squadron_phase_controller.squadron_command_done.connect(
				_on_squadron_command_done)
	if _displacement_controller != null:
		_displacement_controller.displacement_completed.connect(
				show_end_activation_after_maneuver)


## DialDragController signal callback.  Called when the player drops the
## dial on the owning ship token.  Sets up activation context before the
## command executes so [ModalRouter] can open from the projected flow.
## Requirements: UI-024, UI-025, SP-010, ACT-007, FLOW-002.
func on_dial_ship_activated(token: ShipToken, ship: ShipInstance) -> void:
	_prepare_activation_context(token, ship)
	var result: Dictionary = GameManager.activate_ship(ship)
	if result.is_empty():
		_clear_activation_context_after_rejection()
		return
	if bool(_is_pending_remote_result.call(result)):
		_log.info("Ship activation submitted for '%s' (awaiting server result)." \
				% [ship.data_key if ship else "?"])
		return
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		token.show_revealed_dial(cmd)
	if _activation_ctx.ship_activation_state != null:
		_activation_ctx.ship_activation_state.refresh_navigate_availability()
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
	_prepare_activation_context(token, ship)

	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	if result.is_empty():
		_clear_activation_context_after_rejection()
		return

	# Modal lifecycle is driven by interaction-state updates in every mode.
	# activation_modal_open  → open_modal_from_interaction_state()
	# wait_for_ship_select   → close_modal_from_interaction_state()
	# No need to open the modal directly here.
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

	var cmd_name: String = ""
	if not result.is_empty():
		cmd_name = Constants.CommandType.keys()[result["command"]]
	_log.info("Ship activated via card drop (token convert): '%s' (%s, added=%s, discard=%s)." % [
			ship.data_key if ship else "?", cmd_name,
			str(result.get("token_added", false)),
			str(needs_discard)])


## Checks whether Crew Panic must interrupt a hidden-dial reveal.
## Called by [ShipCardPanel] through a generic pre-reveal callback before
## [method GameManager.submit_reveal_dial] runs.
## Rules Reference: "Crew Panic" card text — "Before you reveal a command
## dial, you must either suffer 1 damage or discard that dial.  If you
## discard it, do not reveal a dial this round."
func check_crew_panic_before_reveal(ship: ShipInstance) -> bool:
	var choice_info: Dictionary = _crew_panic_choice_for_ship(ship)
	if choice_info.is_empty():
		return false
	_pending_crew_panic_ship = ship
	_pending_crew_panic_ship_key = ship.data_key
	_open_crew_panic_choice(choice_info)
	_log.info("Crew Panic — showing pre-reveal choice for %s." % ship.data_key)
	return true


func _crew_panic_choice_for_ship(ship: ShipInstance) -> Dictionary:
	var game_state: GameState = GameManager.current_game_state
	if ship == null or game_state == null:
		return {}
	var ship_index: int = game_state.find_ship_index(ship)
	if ship_index < 0:
		return {}
	var intent: UIProjector.UIIntent = UIProjector.project(
			game_state, _local_viewer())
	var raw_payload: Variant = intent.affordances.get(
			CrewPanic.AFFORDANCE_KEY, {})
	if not raw_payload is Dictionary:
		return {}
	return _crew_panic_choice_from_payload(
			raw_payload as Dictionary, ship.owner_player, ship_index)


func _crew_panic_choice_from_payload(payload: Dictionary,
		owner_player: int,
		ship_index: int) -> Dictionary:
	var ships: Array = payload.get("ships", [])
	for ship_var: Variant in ships:
		if not ship_var is Dictionary:
			continue
		var ship_choice: Dictionary = ship_var as Dictionary
		if _matches_crew_panic_choice(ship_choice, owner_player, ship_index):
			var info: Variant = ship_choice.get("choice_info", {})
			if info is Dictionary:
				var choice_info: Dictionary = info as Dictionary
				return choice_info.duplicate(true)
			return {}
	return {}


func _matches_crew_panic_choice(choice: Dictionary,
		owner_player: int,
		ship_index: int) -> bool:
	return int(choice.get("owner_player", -1)) == owner_player \
			and int(choice.get("ship_index", -1)) == ship_index


func _open_crew_panic_choice(choice_info: Dictionary) -> void:
	_ensure_crew_panic_modal()
	if not _crew_panic_modal.choice_confirmed.is_connected(
			_on_crew_panic_choice):
		_crew_panic_modal.choice_confirmed.connect(
				_on_crew_panic_choice, CONNECT_ONE_SHOT)
	_crew_panic_modal.open(choice_info)


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


## Applies the projected activation-sequence button affordance.
func apply_activation_sequence_affordance(is_available: bool) -> void:
	if _panel_mgr == null or _panel_mgr.show_activation_button == null:
		return
	if not is_available or _activation_ctx.ship_activation_state == null:
		_panel_mgr.show_activation_button.hide_button()
		return
	if _is_activation_sequence_button_suppressed():
		_panel_mgr.show_activation_button.hide_button()
		return
	show_activation_sequence_button()


func _prepare_activation_context(token: ShipToken,
		ship: ShipInstance) -> void:
	_activation_ctx.set_active(token, ShipActivationState.create(ship))
	if _panel_mgr.activation_sidebar and ship:
		_panel_mgr.activation_sidebar.highlight_active(ship)


func _clear_activation_context_after_rejection() -> void:
	_activation_ctx.clear()
	if _panel_mgr.activation_sidebar:
		_panel_mgr.activation_sidebar.clear_active()
		_panel_mgr.activation_sidebar.refresh()


## Shows and positions the End Activation button. Called from K8b
## leftovers (currently unused — kept for future re-introduction).
func show_end_activation_button() -> void:
	if _panel_mgr.end_activation_button == null:
		return
	_panel_mgr.end_activation_button.show_button()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel_mgr.end_activation_button.update_position(vp_size)


## Applies dynamic skip/interactable flags and opens the activation modal.
## Called by [method open_modal_from_interaction_state] for the controller
## peer after [ModalRouter] projects an activation lifecycle command.
func configure_and_open_activation_modal() -> void:
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return
	if _activation_ctx.ship_activation_state == null:
		return
	if is_command_squadron_modal_active():
		ensure_activation_modal_hidden_for_squadron_command()
		return
	var has_squadron_resources: bool = bool(_has_squadron_resources.call(
			_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_squadron_skippable(
			not has_squadron_resources)
	_panel_mgr.activation_modal.set_squadron_skip_allowed(
			has_squadron_resources)
	_panel_mgr.activation_modal.set_repair_skippable(
			not bool(_has_repair_resources.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_attack_skippable(
			not _attack_executor.has_any_attack_target(
					_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_attack_skippable_check(
			_compute_attack_skippable_now)
	update_activation_modal_interactivity()
	_panel_mgr.activation_modal.open(_activation_ctx.ship_activation_state)


## Re-evaluates "no valid attack targets" using fresh state.
## Bound to [method ActivationModal.set_attack_skippable_check] so the
## modal can confirm immediately before auto-skipping the ATTACK step
## that no targets exist — guards against the snapshot taken at modal-
## open being stale by the time the auto-skip fires.
## Returns [code]true[/code] when the attack should still be skipped.
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
func _compute_attack_skippable_now() -> bool:
	if _attack_executor == null:
		return false
	if _activation_ctx == null:
		return false
	var token: ShipToken = _activation_ctx.activating_ship_token
	if token == null:
		return false
	return not _attack_executor.has_any_attack_target(token)


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
	_queue_unavailable_repair_auto_advance(flow)
	_queue_unavailable_attack_auto_advance(flow)


## Submits an authoritative activation-step transition marker in every mode.
func submit_activation_step(step_id: String) -> void:
	if _activation_ctx.ship_activation_state == null:
		return
	var ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	if ship == null:
		return
	GameManager.submit_advance_activation_step(ship, step_id)


## Defers projected Repair skips so follow-up commands preserve network order.
func _queue_unavailable_repair_auto_advance(flow: InteractionFlow) -> void:
	if flow.step_id != Constants.InteractionStep.REPAIR_STEP:
		_repair_auto_advance_pending = false
		return
	if _repair_auto_advance_pending:
		return
	if not _should_auto_advance_unavailable_repair(flow):
		return
	_repair_auto_advance_pending = true
	call_deferred("_auto_advance_unavailable_repair_if_current")


func _auto_advance_unavailable_repair_if_current() -> void:
	_repair_auto_advance_pending = false
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null:
		return
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return
	if flow.step_id != Constants.InteractionStep.REPAIR_STEP:
		return
	if not _should_auto_advance_unavailable_repair(flow):
		return
	_log.info("No repair available in projected Repair step — auto-advancing.")
	_on_repair_done()


## Defers no-target Attack skips so the authoritative flow advances by command.
func _queue_unavailable_attack_auto_advance(flow: InteractionFlow) -> void:
	if flow.step_id != Constants.InteractionStep.ATTACK_STEP:
		_attack_auto_advance_pending = false
		return
	if _attack_auto_advance_pending:
		return
	if not _should_auto_advance_unavailable_attack(flow):
		return
	_attack_auto_advance_pending = true
	call_deferred("_auto_advance_unavailable_attack_if_current")


func _auto_advance_unavailable_attack_if_current() -> void:
	_attack_auto_advance_pending = false
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null:
		return
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return
	if flow.step_id != Constants.InteractionStep.ATTACK_STEP:
		return
	if not _should_auto_advance_unavailable_attack(flow):
		return
	_log.info("No attack targets in projected Attack step — auto-advancing.")
	_advance_activation_to_maneuver()


func _should_auto_advance_unavailable_repair(flow: InteractionFlow) -> bool:
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return false
	if not _is_local_activation_modal_controller():
		return false
	if _activation_ctx.activating_ship_token == null:
		return false
	if not _has_repair_resources.is_valid():
		return false
	if bool(_has_repair_resources.call(_activation_ctx.activating_ship_token)):
		return false
	var ship: ShipInstance = _current_activating_ship()
	if ship == null or flow.controller_player != ship.owner_player:
		return false
	var flow_ship_index: int = int(flow.payload.get("ship_index", -1))
	if flow_ship_index < 0:
		return false
	return flow_ship_index == _current_activating_ship_index(ship)


func _should_auto_advance_unavailable_attack(flow: InteractionFlow) -> bool:
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return false
	if not _is_local_activation_modal_controller():
		return false
	if not _compute_attack_skippable_now():
		return false
	var ship: ShipInstance = _current_activating_ship()
	if ship == null or flow.controller_player != ship.owner_player:
		return false
	var flow_ship_index: int = int(flow.payload.get("ship_index", -1))
	if flow_ship_index < 0:
		return false
	return flow_ship_index == _current_activating_ship_index(ship)


func _current_activating_ship() -> ShipInstance:
	if _activation_ctx.ship_activation_state == null:
		return null
	return _activation_ctx.ship_activation_state.get_ship()


func _current_activating_ship_index(ship: ShipInstance) -> int:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null or ship == null:
		return -1
	return game_state.find_ship_index(ship)


## Opens the activation modal in response to an authoritative
## interaction-state update for the current ship-activation step.
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
	apply_activation_sequence_affordance(
			_is_activation_sequence_affordance_projected())


## Opens the command-mode squadron modal from the authoritative
## ship-activation [code]squadron_step[/code] projection.
func open_squadron_command_from_interaction_state() -> void:
	var ship_token: ShipToken = _activation_ctx.activating_ship_token
	if _activation_ctx.ship_activation_state == null or ship_token == null:
		return
	var ship: ShipInstance = ship_token.get_ship_instance()
	if ship == null:
		return
	var resolver: SquadronCommandResolver = _create_squadron_command_resolver(
			ship, ship_token)
	if resolver.is_empty():
		_advance_unavailable_squadron_command()
		return
	if not _has_eligible_squadron_in_range(ship, resolver):
		_complete_unavailable_squadron_command(ship, resolver)
		return
	_hide_activation_ui_for_squadron_command()
	_squadron_phase_controller.open_for_command(resolver, ship_token)


## Returns true when the ship activation modal is already visible.
func is_activation_modal_open() -> bool:
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return false
	return _panel_mgr.activation_modal.is_open()


## Returns true when the command-mode squadron modal is currently visible.
## While this is true, the ship activation modal must remain hidden to
## avoid overlapping stacked modals.
func is_command_squadron_modal_active() -> bool:
	if _squadron_phase_controller == null:
		return false
	return _squadron_phase_controller.is_modal_visible() \
			and _squadron_phase_controller.is_command_mode()


## Hides the ship activation modal while command-mode squadron flow is active.
## Safe to call repeatedly; no-op when already hidden.
func ensure_activation_modal_hidden_for_squadron_command() -> void:
	if not is_command_squadron_modal_active():
		return
	if _panel_mgr == null or _panel_mgr.activation_modal == null:
		return
	if _panel_mgr.activation_modal.visible:
		_panel_mgr.activation_modal.close()


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
	var has_squadron_resources: bool = bool(_has_squadron_resources.call(
			_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_squadron_skippable(
			not has_squadron_resources)
	_panel_mgr.activation_modal.set_squadron_skip_allowed(
			has_squadron_resources)
	_panel_mgr.activation_modal.set_repair_skippable(
			not bool(_has_repair_resources.call(
					_activation_ctx.activating_ship_token)))
	_panel_mgr.activation_modal.set_attack_skippable(
			not _attack_executor.has_any_attack_target(
					_activation_ctx.activating_ship_token))
	_panel_mgr.activation_modal.set_attack_skippable_check(
			_compute_attack_skippable_now)
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
## The hidden dial is discarded and the ship activates without any command
## available this round. No reveal occurs.
## Rules Reference: "Crew Panic" — "discard that dial … do not reveal a
## dial this round."
func _finish_crew_panic_dial_discarded(
		ship: ShipInstance, ship_key: String) -> void:
	if not _discard_crew_panic_dial(ship):
		_log.error("Crew Panic discard selected but no dial was available.")
		return
	var act_token: ShipToken = _find_ship_token_for_instance.call(ship) as ShipToken
	_prepare_activation_context(act_token, ship)
	var result: Dictionary = GameManager.activate_ship_without_command(
			ship, CrewPanic.EFFECT_ID)
	if result.is_empty():
		_clear_activation_context_after_rejection()
		return
	if bool(_is_pending_remote_result.call(result)):
		_log.info("Crew Panic activation submitted for '%s'." % ship_key)
		return
	if _activation_ctx.ship_activation_state != null:
		_activation_ctx.ship_activation_state.refresh_navigate_availability()
	_log.info("Ship activated (dial discarded by Crew Panic): '%s'."
			% ship_key)


## Callback when the player makes their Crew Panic choice.
## No drag is active — the ship is stored in [member _pending_crew_panic_ship].
## On "discard dial": discard the hidden dial and activate without command.
## On "suffer damage": resolve the damage, then reveal the dial normally.
func _on_crew_panic_choice(selection: Dictionary) -> void:
	var ship: ShipInstance = _pending_crew_panic_ship
	var ship_key: String = _pending_crew_panic_ship_key
	_pending_crew_panic_ship = null
	_pending_crew_panic_ship_key = ""
	if ship == null:
		_log.error("Crew Panic choice callback but no pending ship!")
		return
	match str(selection.get("id", "")):
		CrewPanic.OPTION_DISCARD_DIAL:
			_finish_crew_panic_dial_discarded(ship, ship_key)
		CrewPanic.OPTION_SUFFER_DAMAGE:
			_resolve_crew_panic_damage_then_reveal(ship, ship_key)
		_:
			_log.warn("Unknown Crew Panic choice for '%s'." % ship_key)


func _discard_crew_panic_dial(ship: ShipInstance) -> bool:
	if ship == null or ship.command_dial_stack == null:
		return false
	if not ship.command_dial_stack.get_revealed_dial().is_empty():
		GameManager.submit_spend_dial(ship, "spend")
		return true
	if ship.command_dial_stack.get_hidden_count() > 0:
		GameManager.submit_spend_dial(ship, "discard")
		return true
	return false


func _resolve_crew_panic_damage_then_reveal(
		ship: ShipInstance,
		ship_key: String) -> void:
	var result: Dictionary = _submit_crew_panic_damage(ship)
	if bool(result.get("destroyed", false)):
		_log.info("Crew Panic destroyed '%s' before reveal." % ship_key)
		return
	GameManager.submit_reveal_dial(ship)
	_log.info("Crew Panic damage resolved; revealed dial for '%s'." % ship_key)


func _submit_crew_panic_damage(ship: ShipInstance) -> Dictionary:
	var raw_result: Variant = _submit_persistent_damage.call(
			ship, CrewPanic.EFFECT_ID)
	if raw_result is Dictionary:
		return raw_result as Dictionary
	return {}


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
	apply_activation_sequence_affordance(
			_is_activation_sequence_affordance_projected())
	_log.info("Token discard resolved — showing activation sequence button.")


# ---------------------------------------------------------------------------
# K8b: Activation step routing (Phase 5b)
# ---------------------------------------------------------------------------

## Called when the player presses "Execute Attack ►" in the activation modal.
## Sets up the attack execution flow: shows the range overlay for the
## activated ship, opens the info panel, and enters hull-zone selection mode.
## Requirements: AE-FLOW-001, AE-ACT-001.
func _on_attack_step_entered() -> void:
	_log.info("Attack step entered — delegating to AttackExecutor.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot start attack — no activation state or token.")
		return
	# Hide the "Show Activation Sequence" button while the attack panel
	# is on-screen — both occupy the same bottom-centre position.
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _attack_executor:
		_attack_executor.start_ship_attack(_activation_ctx.activating_ship_token)


## Called when the player presses "Execute Repair ►" in the activation modal.
## Creates a RepairResolver and opens the RepairPanel.
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
func _on_repair_step_entered() -> void:
	_log.info("Repair step entered — opening RepairPanel.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot start repair — no activation state or token.")
		return
	var ship: ShipInstance = _activation_ctx.activating_ship_token.get_ship_instance()
	if ship == null:
		return
	var resolver: RepairResolver = RepairResolver.create(
			ship, _damage_deck)
	if resolver.is_empty():
		_log.info("No engineering points — auto-advancing repair step.")
		_on_repair_done()
		return
	if not resolver.has_any_repair_target():
		_log.info("Ship at full strength — nothing to repair. "
				+"Consuming dial/token and auto-advancing.")
		var token_result: Dictionary = resolver.finalize()
		_submit_resolver_spends(ship, token_result)
		_on_repair_done()
		return
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.repair_panel:
		_panel_mgr.repair_panel.open(resolver, ship)
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		_panel_mgr.repair_panel.centre_on_screen(vp_size)


## Called when the player presses "Execute Squadron ►" in the activation modal.
## Publishes the authoritative squadron-step marker; [ModalRouter] opens
## the command-mode SquadronActivationModal from the projected result.
## Rules Reference: RRG "Commands" p.4 — Squadron; CM-020–CM-022.
func _on_squadron_step_entered() -> void:
	_log.info("Squadron step entered — starting squadron command flow.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot start squadron command — no activation state.")
		return
	submit_activation_step("squadron_step")


func _create_squadron_command_resolver(ship: ShipInstance,
		ship_token: ShipToken) -> SquadronCommandResolver:
	return SquadronCommandResolver.create(
			ship, ship_token.global_position, ship_token.global_rotation,
			ship_token.get_half_width(), ship_token.get_half_length())


func _advance_unavailable_squadron_command() -> void:
	if not _is_local_activation_modal_controller():
		return
	_log.info("No squadron activations available — auto-advancing.")
	_on_squadron_command_done()


func _complete_unavailable_squadron_command(ship: ShipInstance,
		resolver: SquadronCommandResolver) -> void:
	if not _is_local_activation_modal_controller():
		return
	_log.info("No friendly squadrons in range — consuming resources "
			+"and auto-advancing.")
	var token_result: Dictionary = resolver.finalize()
	_submit_resolver_spends(ship, token_result)
	_on_squadron_command_done()


func _hide_activation_ui_for_squadron_command() -> void:
	if _panel_mgr.show_activation_button:
		_panel_mgr.show_activation_button.hide_button()
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.close()


func _is_activation_sequence_button_suppressed() -> bool:
	if _has_pending_token_overflow_discard():
		return true
	if _attack_executor != null and _attack_executor.is_in_exec_mode():
		return true
	return is_command_squadron_modal_active()


func _is_activation_sequence_affordance_projected() -> bool:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return false
	var intent: UIProjector.UIIntent = UIProjector.project(
			game_state, _local_viewer())
	return bool(intent.affordances.get("activation_sequence_button", false))


## Returns true if at least one friendly non-activated squadron is within
## range of the ship's squadron command resolver.
func _has_eligible_squadron_in_range(ship: ShipInstance,
		resolver: SquadronCommandResolver) -> bool:
	var tokens: Array[SquadronToken] = _get_squadron_tokens.call()
	for sq_token: SquadronToken in tokens:
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and not sq_inst.is_destroyed() \
				and sq_inst.owner_player == ship.owner_player \
				and resolver.is_squadron_in_range(sq_token.global_position):
			return true
	return false


## Called when the player presses "Skip" on the squadron step (token only).
## Advances the activation step without entering the squadron command flow.
## Rules Reference: "Commands" p.4 — spending a command token is optional.
func _on_squadron_step_skipped() -> void:
	_log.info("Squadron step skipped by player (token not spent).")
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	submit_activation_step("repair_step")


## Called when the squadron command flow is complete (all activations used
## or the player finishes early).
## Finalizes the resolver (spends dial/token), advances the activation
## step, and submits the projection marker that re-opens the activation modal.
## Rules Reference: CM-020.
func _on_squadron_command_done() -> void:
	_log.info("Squadron command done — advancing activation step.")
	_squadron_phase_controller.dismiss_cmd_range_overlay()
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	submit_activation_step("repair_step")


## Submits [SpendDialCommand] and/or [SpendTokenCommand] based on a
## resolver's return dictionary.
## [param ship] — the ship that resolved the command.
## [param result] — the dictionary returned by [code]finalize()[/code] or
## [code]mark_maneuver_executed()[/code]; may contain [code]"dial_spent"[/code]
## and/or [code]"token_type"[/code].
func _submit_resolver_spends(ship: ShipInstance,
		result: Dictionary) -> void:
	if result.get("dial_spent", false):
		GameManager.submit_spend_dial(ship)
	if result.has("token_type"):
		GameManager.submit_spend_token(ship, result["token_type"])


## Called when the repair panel finishes (Done or Skip pressed).
## Advances activation state and submits the next projected activation step.
func _on_repair_done() -> void:
	_log.info("Repair done — advancing activation step.")
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	submit_activation_step("attack_step")


## Called when the attack execution step is fully complete.
## Advances activation state and submits the next projected activation step.
## Routes to the squadron modal when a squadron attack just completed.
## Requirements: AE-FLOW-003, AE-CONF-002, SQA-ATK-003.
func _on_attack_exec_completed() -> void:
	_log.info("Attack exec completed — advancing activation step.")
	# Phase 7b: squadron attack completed — route to squadron modal.
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_in_attacking_state():
		_squadron_phase_controller.notify_attack_completed()
		return
	_advance_activation_to_maneuver()


func _advance_activation_to_maneuver() -> void:
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step()
	submit_activation_step("maneuver_step")


## Called when the player cancels attack execution (Escape).
## Re-opens the activation modal without advancing.
## Routes to the squadron modal when a squadron attack was cancelled.
## Requirements: AE-FLOW-004, SQA-ATK-005.
func _on_attack_exec_cancelled() -> void:
	_log.info("Attack exec cancelled — returning to activation modal.")
	# Phase 7b: squadron attack cancelled — route to squadron modal.
	if _squadron_phase_controller \
			and _squadron_phase_controller.is_in_attacking_state():
		_squadron_phase_controller.notify_attack_cancelled()
		return
	open_modal_from_interaction_state()


## Called when the player presses "Show Activation Sequence".
## Opens the activation modal from the current interaction-state projection.
## Requirements: ACT-001, ACT-007.
func _on_activation_sequence_requested() -> void:
	_log.info("Activation sequence requested.")
	if _activation_ctx.ship_activation_state == null:
		_log.info("No activation state — cannot open modal.")
		return
	open_modal_from_interaction_state()


# ---------------------------------------------------------------------------
# K8b: Maneuver execute + overlap resolution (Phase 5b)
# ---------------------------------------------------------------------------

## Called when the activation modal reaches the Execute Maneuver step.
## Shows the maneuver tool on the activating ship and the Execute Maneuver
## button. For speed 0, skips the tool and executes immediately.
## Requirements: FLOW-003, AC-5b-03, EXE-004.
func _on_maneuver_step_entered() -> void:
	_log.info("Maneuver step entered.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		_log.info("Cannot show maneuver tool — state=%s, token=%s." % [
				str(_activation_ctx.ship_activation_state != null),
				str(_activation_ctx.activating_ship_token != null)])
		return
	# Re-resolve Navigate availability now that any dial→token conversion
	# command has fully executed.  Without this, a ship activated via the
	# token-convert path keeps the stale "dial revealed" snapshot taken in
	# `on_dial_token_converted` (which set up the activation context
	# before the convert command ran), incorrectly granting the +1 yaw
	# bonus to a token-only spend.
	# Rules Reference: NAV-002, NAV-006 — yaw bonus is a dial-only effect.
	_activation_ctx.ship_activation_state.refresh_navigate_availability()
	var ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	# Speed 0: no tool, ship stays in place, maneuver counts as executed.
	if ship.current_speed == 0:
		_log.info("Speed 0 — executing maneuver without tool.")
		var token_result: Dictionary = _activation_ctx.ship_activation_state.mark_maneuver_executed()
		_submit_resolver_spends(ship, token_result)
		EventBus.ship_moved.emit(_activation_ctx.activating_ship_token)
		show_end_activation_after_maneuver()
		return
	_show_activation_maneuver_tool()
	# Disable the simulation maneuver button while activation tool is active.
	if _panel_mgr.action_toolbar:
		_panel_mgr.action_toolbar.set_tool_buttons_disabled(true)
	# Yaw bonus (Navigate dial) is applied interactively when the player
	# clicks a joint beyond its base limit — not auto-assigned to joint 0.
	# Modal's embedded Execute button is already visible — no extra button needed.

# TODO(refactor): extract maneuver damage warnings with the maneuver tool cluster.
## Shows the activation maneuver tool and starts damage-preview updates.
func _show_activation_maneuver_tool() -> void:
	_maneuver_tool_controller.show_activation_tool(
			_activation_ctx.activating_ship_token,
			_activation_ctx.ship_activation_state)
	var scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if scene != null and not scene.maneuver_preview_changed.is_connected(
			_update_maneuver_damage_hint):
		scene.maneuver_preview_changed.connect(_update_maneuver_damage_hint)
	_update_maneuver_damage_hint()


## Refreshes the warning for damage-card effects caused by the previewed move.
func _update_maneuver_damage_hint() -> void:
	if _panel_mgr.activation_modal == null:
		return
	_panel_mgr.activation_modal.set_maneuver_warning_message(
			_build_maneuver_damage_hint())


func _clear_maneuver_damage_hint() -> void:
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.set_maneuver_warning_message("")


func _build_maneuver_damage_hint() -> String:
	var ship: ShipInstance = _active_maneuver_ship()
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if ship == null or mt_scene == null:
		return ""
	var effect_ids: Array[String] = _preview_maneuver_damage_effect_ids(
			ship, mt_scene)
	if effect_ids.is_empty():
		return ""
	return "Committing this maneuver will trigger damage from %s." % \
			_format_effect_names(ship, effect_ids)


func _preview_maneuver_damage_effect_ids(ship: ShipInstance,
		mt_scene: ManeuverToolScene) -> Array[String]:
	var tool_state: ManeuverToolState = mt_scene.get_state()
	var did_overlap: bool = _preview_damaged_controls_overlap(ship)
	return ManeuverRuleResolver.preview_maneuver_damage_effect_ids(
			GameManager.current_game_state, ship, _damage_deck,
			tool_state.get_simulated_speed(), did_overlap,
			_activation_ctx.ship_activation_state.get_total_speed_change() != 0)


func _preview_damaged_controls_overlap(ship: ShipInstance) -> bool:
	if not _ship_has_faceup_effect(
			ship, ManeuverRuleResolver.EFFECT_DAMAGED_CONTROLS):
		return false
	var overlap_result: OverlapResolver.ShipShipResult = \
			_preview_maneuver_overlap_result()
	return overlap_result != null and (
			overlap_result.overlaps or overlap_result.stayed_in_place)


func _ship_has_faceup_effect(ship: ShipInstance, effect_id: String) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == effect_id:
			return true
	return false


func _active_maneuver_ship() -> ShipInstance:
	if _activation_ctx.ship_activation_state == null:
		return null
	return _activation_ctx.ship_activation_state.get_ship()


func _format_effect_names(ship: ShipInstance,
		effect_ids: Array[String]) -> String:
	var names: Array[String] = []
	for effect_id: String in effect_ids:
		names.append(_effect_title_for_id(ship, effect_id))
	if names.size() == 1:
		return names[0]
	var prefix: Array[String] = []
	for index: int in range(names.size() - 1):
		prefix.append(names[index])
	return "%s and %s" % [", ".join(prefix), names[names.size() - 1]]


func _effect_title_for_id(ship: ShipInstance, effect_id: String) -> String:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.effect_id == effect_id and not card.title.is_empty():
			return card.title
	match effect_id:
		ManeuverRuleResolver.EFFECT_RUPTURED_ENGINE:
			return "Ruptured Engine"
		ManeuverRuleResolver.EFFECT_DAMAGED_CONTROLS:
			return "Damaged Controls"
		ManeuverRuleResolver.EFFECT_THRUSTER_FISSURE:
			return "Thruster Fissure"
		_:
			return effect_id.capitalize()


## Called when the player commits the maneuver (modal "Commit ►" button).
## Snaps the ship to the final transform, resolves ship–ship and
## ship–squadron overlaps, then ends the activation.
## Requirements: EXE-001, EXE-002, AC-5b-08, AC-5b-09, AC-5b-12, AC-5b-13,
##     OV-001–004, OV-010–013.
func _on_execute_maneuver() -> void:
	_log.info("Execute maneuver requested.")
	if _activation_ctx.ship_activation_state == null or _activation_ctx.activating_ship_token == null:
		return
	if _maneuver_tool_controller.get_scene() == null:
		return
	# Capture the pre-move transform so we can revert on command rejection.
	# Without this, a host-side validation failure (e.g. yaw clicks exceeding
	# the nav chart) would leave the host's visuals advanced while the
	# authoritative GameState and any remote peer stayed at the old position.
	var pre_move_xform: Transform2D = Transform2D(
			_activation_ctx.activating_ship_token.global_rotation,
			_activation_ctx.activating_ship_token.global_position)
	var final_xform: Transform2D = _resolve_maneuver_overlaps_ex()
	_activation_ctx.activating_ship_token.global_position = final_xform.origin
	_activation_ctx.activating_ship_token.global_rotation = final_xform.get_rotation()
	# Ship–squadron overlap resolution (OV-001–004).
	var ship_size: Constants.ShipSize = _activation_ctx.activating_ship_token.get_ship_size()
	var moved_ship_base: ShipBase = ShipBase.new(ship_size, final_xform)
	var displaced: Array[SquadronToken] = _find_displaced_squadrons(
			moved_ship_base)
	var token_result: Dictionary = _activation_ctx.ship_activation_state.mark_maneuver_executed()
	var maneuver_ship: ShipInstance = _activation_ctx.ship_activation_state.get_ship()
	_submit_resolver_spends(maneuver_ship, token_result)

	# Record the maneuver via command for replay determinism.
	var mt_scene_ref: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	var maneuver_submitted: bool = false
	var maneuver_result: Dictionary = {}
	if mt_scene_ref:
		var tool_st: ManeuverToolState = mt_scene_ref.get_state()
		# Use the current simulated speed (after +/- changes), not the
		# setup speed captured when the tool was first opened.
		var spd: int = tool_st.get_simulated_speed()
		var all_clicks: Array[int] = tool_st.get_joint_clicks()
		# Slice to active joints only (joint_count == speed).
		var active_clicks: Array = []
		for i: int in range(mini(spd, all_clicks.size())):
			active_clicks.append(all_clicks[i])
		var bonus_joint: int = tool_st.get_yaw_bonus_joint()
		var pa: Vector2 = GameScale.play_area_size_px
		if pa.x > 0.0 and pa.y > 0.0:
			var norm_x: float = final_xform.origin.x / pa.x
			var norm_y: float = final_xform.origin.y / pa.y
			var rot_deg: float = rad_to_deg(final_xform.get_rotation())
			maneuver_submitted = true
			maneuver_result = GameManager.submit_execute_maneuver(
					maneuver_ship, spd, active_clicks,
					norm_x, norm_y, rot_deg, bonus_joint,
					_activation_ctx.last_maneuver_overlapped,
					_activation_ctx.ship_activation_state.get_total_speed_change())
	# If the command was rejected (empty Dictionary), revert the local
	# visual snap so the host stays consistent with the authoritative
	# GameState (and with any remote peer, which never received a
	# broadcast).  Allow player to retry by re-showing the maneuver tool.
	# Rules Reference: MV-001–015.
	if maneuver_submitted and maneuver_result.is_empty():
		_log.error("ExecuteManeuverCommand rejected — maneuver invalid.")
		_activation_ctx.activating_ship_token.global_position = pre_move_xform.origin
		_activation_ctx.activating_ship_token.global_rotation = pre_move_xform.get_rotation()
		# Re-show the maneuver tool so the player can adjust and retry.
		# This prevents the activation from becoming stuck.
		_maneuver_tool_controller.dismiss(null)
		if _activation_ctx.activating_ship_token and _activation_ctx.ship_activation_state:
			_show_activation_maneuver_tool()
			TooltipManager.show_text(
					"Maneuver validation failed. Adjust and try again.",
					Vector2.INF, 3.0, true)
			_log.info("Maneuver tool re-shown for retry after validation failure.")
		return

	# RuleRegistry observers enqueue any maneuver damage follow-up commands.
	# Rules Reference: "Ruptured Engine", "Damaged Controls", "Thruster Fissure".
	_clear_maneuver_damage_hint()
	EventBus.ship_moved.emit(_activation_ctx.activating_ship_token)
	_dismiss_maneuver_tool_with_preview.call()
	if displaced.size() > 0:
		# Phase L4: publish the authoritative displacement flow only.
		# ModalRouter opens the modal from the projected
		# SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE intent in every mode.
		# Rules Reference: RRG "Overlapping", p.8 — the player who is
		# NOT moving the ship places the overlapped squadrons, regardless
		# of who owns them.
		var displaced_instances: Array = []
		for sq_token: SquadronToken in displaced:
			var inst: SquadronInstance = sq_token.get_squadron_instance()
			if inst == null:
				continue
			displaced_instances.append(inst)
		var placing_player: int = 1 - maneuver_ship.owner_player
		GameManager.submit_start_displacement(maneuver_ship,
				placing_player, displaced_instances)
	else:
		show_end_activation_after_maneuver()
	_log.info("Ship snapped to final position.")


## Computes the final transform after ship–ship overlap resolution.
## Applies overlap damage if a collision occurred.
## Sets [member _activation_ctx].last_maneuver_overlapped for maneuver rules.
## Requirements: OV-010–013.
func _resolve_maneuver_overlaps_ex() -> Transform2D:
	var result: OverlapResolver.ShipShipResult = _preview_maneuver_overlap_result()
	if result == null:
		return Transform2D(
				_activation_ctx.activating_ship_token.global_rotation,
				_activation_ctx.activating_ship_token.global_position)
	_activation_ctx.last_maneuver_overlapped = result.overlaps or result.stayed_in_place
	if _activation_ctx.last_maneuver_overlapped:
		_apply_overlap_damage(result)
	else:
		if _panel_mgr.activation_modal:
			_panel_mgr.activation_modal.set_collision_message("")
	return result.final_transform


## Previews ship-overlap resolution for the current maneuver tool state.
func _preview_maneuver_overlap_result() -> OverlapResolver.ShipShipResult:
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if mt_scene == null:
		return null
	var tool_state: ManeuverToolState = mt_scene.get_state()
	var attach: Dictionary = mt_scene._compute_attachment()
	var start_pos: Vector2 = attach["position"]
	var start_rot: float = attach["rotation"]
	var ghost_side: String = tool_state.compute_ghost_side()
	var original_xform: Transform2D = Transform2D(
			_activation_ctx.activating_ship_token.global_rotation,
			_activation_ctx.activating_ship_token.global_position)
	var ship_size: Constants.ShipSize = _activation_ctx.activating_ship_token.get_ship_size()
	var other_bases: Array = _build_other_ship_bases(_activation_ctx.activating_ship_token)
	var resolver: OverlapResolver = OverlapResolver.new()
	var result: OverlapResolver.ShipShipResult = (
			resolver.check_ship_ship_overlap(
					tool_state, start_pos, start_rot, ghost_side,
					ship_size, other_bases, original_xform))
	return result


## Shows the activation modal at the DONE step so the player can review
## all completed steps and deliberately end their activation.
## Replaces the previous auto-end behaviour (activation_ended was emitted
## immediately after maneuver).
## Requirements: AC-5b-11, FLOW-002.
##
## Public so [GameBoard._resume_after_remote_displacement] and the
## [DisplacementController.displacement_completed] signal can call it.
func show_end_activation_after_maneuver() -> void:
	# Update state to reflect completion.
	if _activation_ctx.ship_activation_state:
		_activation_ctx.ship_activation_state.advance_step() ## MANEUVER → DONE
	submit_activation_step("activation_done")


## Called when the player presses "End Activation ►" in the modal.
## Emits activation_ended so GameManager spends the dial, marks the ship
## activated, and advances the turn.
## Rules Reference: RRG "Ship Activation" p.16 — activation ends.
func _on_activation_end_requested() -> void:
	_log.info("Player ended activation via End Activation button.")
	EventBus.activation_ended.emit()


# ---------------------------------------------------------------------------
# K8b: Overlap resolution helpers (Phase 5b-2 — OV-001–013)
# ---------------------------------------------------------------------------

## Builds an Array of [ShipBase] for every ship on the board except
## [param exclude].  Used for ship–ship overlap checks.
func _build_other_ship_bases(exclude: ShipToken) -> Array:
	var bases: Array = []
	for token: ShipToken in _get_ship_tokens.call():
		if token == exclude:
			continue
		var inst: ShipInstance = token.get_ship_instance()
		if inst and inst.is_destroyed():
			continue
		var xform: Transform2D = Transform2D(
				token.global_rotation, token.global_position)
		bases.append(ShipBase.new(token.get_ship_size(), xform))
	return bases


## Deals one facedown damage card to both the moving ship and the
## closest overlapping ship after an overlap resolution.
## Rules Reference: RRG "Overlapping", p.8 — OV-011.
func _apply_overlap_damage(result: OverlapResolver.ShipShipResult) -> void:
	var moving_inst: ShipInstance = (
			_activation_ctx.activating_ship_token.get_ship_instance())
	# Identify the overlapped ship token.  Index references the
	# "other ships" list built by [method _build_other_ship_bases]
	# (skips the activating ship and any destroyed ships in iteration
	# order).  A null lookup here is a logic bug — never silently fall
	# back to the moving ship, which would alias the command and deal
	# 2 damage to the moving ship instead of 1+1 across both.
	var other_token: ShipToken = _get_other_ship_token(
			result.overlapped_ship_index)
	if other_token == null:
		_log.error(("Overlap damage: could not resolve overlapped" +
				" ship token at index %d (moving=%s). Aborting" +
				" damage to avoid aliasing.") % [
				result.overlapped_ship_index,
				moving_inst.ship_data.ship_name])
		return
	var other_inst: ShipInstance = other_token.get_ship_instance()
	if other_inst == null:
		_log.error(("Overlap damage: overlapped token '%s' has no" +
				" ShipInstance (moving=%s). Aborting damage.") % [
				other_token.name,
				moving_inst.ship_data.ship_name])
		return
	# Build toast text.
	var toast_parts: Array[String] = []
	if result.stayed_in_place:
		toast_parts.append(
				"⚠ Collision detected! Ship stays in place (speed 0).")
	else:
		toast_parts.append(
				"⚠ Collision detected! Speed temporarily reduced to %d (was %d)."
				% [result.final_speed, result.original_speed])
	# Pre-draw cards from the damage deck.
	if _damage_deck == null:
		_log.error("No damage deck — cannot deal overlap damage.")
		return
	var m_card: DamageCard = _damage_deck.draw_card()
	if m_card == null:
		_log.error("Damage deck empty — cannot deal overlap damage.")
		return
	var o_card: DamageCard = _damage_deck.draw_card()
	if o_card == null:
		_log.error("Damage deck empty after first draw — cannot " +
				"deal overlap damage to overlapped ship.")
		return
	_log.info(("Overlap damage: moving='%s' overlapped='%s'" +
			" (other_index=%d).") % [
			moving_inst.ship_data.ship_name,
			other_inst.ship_data.ship_name,
			result.overlapped_ship_index])
	# Submit command with pre-drawn cards.
	var cmd_result: Dictionary = GameManager.submit_overlap_damage(
			moving_inst,
			other_inst,
			m_card.serialize(),
			o_card.serialize())
	if cmd_result.is_empty():
		_log.error("OverlapDamageCommand rejected.")
		return
	# Emit signals for the moving ship.
	_emit_overlap_signals(moving_inst,
			_activation_ctx.activating_ship_token, cmd_result,
			"moving_hull", "moving_destroyed")
	toast_parts.append("%s takes 1 damage."
			% moving_inst.ship_data.ship_name)
	# Emit signals for the overlapped ship.
	_emit_overlap_signals(other_inst, other_token, cmd_result,
			"other_hull", "other_destroyed")
	toast_parts.append("%s takes 1 damage."
			% other_inst.ship_data.ship_name)
	# Show collision info inside the activation modal so it's unmissable.
	if _panel_mgr.activation_modal:
		_panel_mgr.activation_modal.set_collision_message("\n".join(toast_parts))
	_log.info("Overlap damage applied: %s" % " | ".join(toast_parts))


## Emits EventBus signals for one side of an overlap damage result.
func _emit_overlap_signals(inst: ShipInstance, token: ShipToken,
		cmd_result: Dictionary, hull_key: String,
		destroyed_key: String) -> void:
	EventBus.damage_card_dealt.emit(inst, null, false)
	var new_hull: int = int(cmd_result.get(hull_key, 0))
	EventBus.ship_hull_changed.emit(inst, new_hull)
	EventBus.ship_damaged.emit(token, 1, Constants.HullZone.FRONT)
	if cmd_result.get(destroyed_key, false) as bool:
		_log.info("Ship destroyed by overlap: %s" % inst.data_key)
		EventBus.ship_destroyed.emit(token)
		_fade_out_destroyed_token(token)


## Fades out a destroyed ship token (visual only).
func _fade_out_destroyed_token(token: Node2D) -> void:
	if token == null:
		return
	var tween: Tween = token.create_tween()
	tween.tween_property(token, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		token.visible = false
		token.modulate.a = 1.0
	)


## Returns the [ShipToken] corresponding to an index among the "other"
## ships (excluding the active ship, matching _build_other_ship_bases order).
func _get_other_ship_token(index: int) -> ShipToken:
	if index < 0:
		return null
	var idx: int = 0
	for token: ShipToken in _get_ship_tokens.call():
		if token == _activation_ctx.activating_ship_token:
			continue
		var inst: ShipInstance = token.get_ship_instance()
		if inst and inst.is_destroyed():
			continue
		if idx == index:
			return token
		idx += 1
	return null


## Finds all squadron tokens whose bases overlap the given ship base.
## Returns the list of displaced [SquadronToken] nodes.
## Rules Reference: RRG "Overlapping", p.8 — OV-001.
func _find_displaced_squadrons(ship_base: ShipBase) -> Array[SquadronToken]:
	var displaced: Array[SquadronToken] = []
	for sq_token: SquadronToken in _get_squadron_tokens.call():
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.is_destroyed():
			continue
		var sq_base: SquadronBase = SquadronBase.new(
				sq_token.global_position, sq_token.get_radius_px())
		if sq_base.overlaps_ship(ship_base):
			displaced.append(sq_token)
	return displaced

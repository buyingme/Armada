## Manages the Squadron Phase activation flow and squadron command mode.
##
## Owns the [SquadronActivationModal], [ShowSquadronModalButton],
## [SquadronMoveOverlay], squadron command range overlay, and all
## movement/attack delegation logic.  Extracted from game_board.gd as
## part of refactoring phase C7.
##
## Cross-cluster dependencies (attack executor, activation button) are
## injected as [Callable]s at [method initialize].
class_name SquadronPhaseController
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the squadron command step finishes during ship activation.
## game_board connects this to advance the activation modal.
signal squadron_command_done

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Squadron Activation Modal (bottom-centre, guides through squadron actions).
## Requirements: SQA-001–013.
var _squadron_modal: SquadronActivationModal = null

## "Show Squadron Modal" button (appears when modal is dismissed).
## Requirements: SQA-011, SQA-013.
var _show_squadron_modal_button: ShowSquadronModalButton = null

## Move overlay (movement + armament range circles) shown on squadron select.
## Requirements: SQM-001, SQM-002.
var _squadron_move_overlay: SquadronMoveOverlay = null

## Range overlay (arc-based) shown during squadron command selection.
## Reuses the same RangeOverlayScene as the R-button and attack flow.
## Requirements: CM-020.
var _squad_cmd_range_overlay: RangeOverlayScene = null

## Saved original position of the moving squadron (for revert on cancel).
var _squadron_move_original_pos: Vector2 = Vector2.ZERO

## Maximum movement distance in pixels for the currently moving squadron.
var _squadron_move_max_dist: float = 0.0

## How many squadron activations have been completed this turn.
## Reset in [method begin_activation_flow].
var _squadron_activation_count: int = 0

## Token container — overlays are added here.
var _token_container: Node2D = null

## Callable: get_squadron_tokens() -> Array[SquadronToken]
var _get_squadron_tokens: Callable

## Callable: start_squadron_attack(token: SquadronToken) -> void
var _start_squadron_attack: Callable

## Callable: show_activation_button_for_command_mode() -> void
## Called when the squadron command modal is dismissed to re-show the
## activation sequence button.
var _show_activation_button: Callable

## Callable: move_squadron_token(token, desired, side, top_y, bottom_y, enforce)
var _move_squadron_token: Callable

## Callable: highlight_active(instance: Variant) -> void
## Highlights the given unit in the activation sidebar.
var _highlight_active: Callable

## Logger instance.
var _log: GameLogger = GameLogger.new("SquadronPhaseController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores shared references.  Must be called once from game_board._ready().
func initialize(
		token_container: Node2D,
		get_squadron_tokens: Callable,
		start_squadron_attack: Callable,
		show_activation_button: Callable,
		move_squadron_token: Callable,
		highlight_active: Callable = Callable(),
) -> void:
	_token_container = token_container
	_get_squadron_tokens = get_squadron_tokens
	_start_squadron_attack = start_squadron_attack
	_show_activation_button = show_activation_button
	_move_squadron_token = move_squadron_token
	_highlight_active = highlight_active


## Creates and wires the squadron modal + reopen button.
## Called from game_board's turn-management UI creation.
## [param layer] — the CanvasLayer that hosts the modal.
## [param register_resizable] — Callable(widget, method, only_visible).
func create_ui(layer: CanvasLayer, register_resizable: Callable) -> void:
	_squadron_modal = SquadronActivationModal.new()
	_squadron_modal.name = "SquadronActivationModal"
	_squadron_modal.move_requested.connect(_on_squadron_move_requested)
	_squadron_modal.move_commit_requested.connect(
			_on_squadron_move_commit)
	_squadron_modal.attack_requested.connect(
			_on_squadron_attack_requested)
	_squadron_modal.activation_done.connect(
			_on_squadron_activation_done)
	_squadron_modal.command_done.connect(_on_squadron_command_done)
	_squadron_modal.modal_closed.connect(
			_on_squadron_modal_closed)
	layer.add_child(_squadron_modal)

	_show_squadron_modal_button = ShowSquadronModalButton.new()
	_show_squadron_modal_button.name = "ShowSquadronModalButton"
	_show_squadron_modal_button.squadron_modal_requested.connect(
			_on_show_squadron_modal_requested)
	layer.add_child(_show_squadron_modal_button)
	register_resizable.call(
			_show_squadron_modal_button, &"update_position", false)


## Returns the [SquadronActivationModal] instance (for external signal
## connections, e.g. activation modal's squadron_selected).
func get_modal() -> SquadronActivationModal:
	return _squadron_modal


## Returns [code]true[/code] when the modal is in command mode.
func is_command_mode() -> bool:
	return _squadron_modal != null and _squadron_modal.is_command_mode()


## Returns [code]true[/code] when the modal is visible.
func is_modal_visible() -> bool:
	return _squadron_modal != null and _squadron_modal.visible


## Returns [code]true[/code] when the modal is in the ATTACKING state
## (a squadron attack is in-flight).
func is_in_attacking_state() -> bool:
	return _squadron_modal != null \
			and _squadron_modal.get_state() \
			== SquadronActivationModal.State.ATTACKING


## Attempts to handle a squadron token click through the modal.
## Returns [code]true[/code] if the click was consumed.
func try_handle_squadron_click(token: SquadronToken) -> bool:
	if _squadron_modal == null or not _squadron_modal.visible:
		return false
	if _squadron_modal.handle_squadron_click(token):
		_on_squadron_selected_in_modal(token)
		return true
	return false


## Starts the squadron activation flow for the current player.
## Called after the handoff overlay is dismissed.
## Requirements: SQA-001, SQA-TM-001.
func begin_activation_flow() -> void:
	_squadron_activation_count = 0
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	EngagementResolver.update_engagement_flags(all_squads)
	if _squadron_modal:
		_squadron_modal.open_for_turn(1, Constants.SQUADRONS_PER_ACTIVATION)
	_log.info("Squadron activation flow started for player %d." %
			GameManager.active_player)


## Opens the squadron modal in command mode for the given ship.
## Called from the activation flow's squadron step.
## Requirements: CM-020–CM-022.
func open_for_command(
		resolver: SquadronCommandResolver,
		ship_token: ShipToken,
) -> void:
	_show_squad_cmd_range_overlay(ship_token)
	if _squadron_modal:
		_squadron_modal.open_for_command(resolver, ship_token)


## Hides all Squadron Phase UI (modal, reopen button, overlay).
func hide_ui() -> void:
	if _squadron_modal:
		_squadron_modal.close_modal()
	if _show_squadron_modal_button:
		_show_squadron_modal_button.hide_button()
	_remove_squadron_overlay()


## Dismisses the squadron command range band overlay.
## Called when the command step finishes.
func dismiss_cmd_range_overlay() -> void:
	if _squad_cmd_range_overlay:
		_squad_cmd_range_overlay.queue_free()
		_squad_cmd_range_overlay = null


## Notifies the modal that a squadron attack completed.
func notify_attack_completed() -> void:
	if _squadron_modal:
		_squadron_modal.notify_attack_completed()


## Notifies the modal that a squadron attack was cancelled.
func notify_attack_cancelled() -> void:
	if _squadron_modal:
		_squadron_modal.notify_attack_cancelled()


## Handles board input during squadron movement (called from _input).
## Returns [code]true[/code] if the event was consumed.
## Requirements: SQM-003, SQM-004, SQM-005.
func handle_move_input(event: InputEvent) -> bool:
	if _squadron_modal == null or not _squadron_modal.visible:
		return false
	var modal_state: SquadronActivationModal.State = \
			_squadron_modal.get_state()
	if modal_state != SquadronActivationModal.State.MOVING:
		return false
	var token: SquadronToken = _squadron_modal.get_selected_token()
	if token == null:
		return false
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			token.global_position = _squadron_move_original_pos
			if _squadron_move_overlay:
				_squadron_move_overlay.reset_tracking()
			_squadron_modal.cancel_move()
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_commit_squadron_placement(token)
			get_viewport().set_input_as_handled()
			return true
	return false


## Moves the currently-moving squadron token to follow the mouse each frame.
## Called from game_board._process().
## Requirements: SQM-003.
func process_squadron_movement() -> void:
	if _squadron_modal == null or not _squadron_modal.visible:
		return
	if _squadron_modal.get_state() != SquadronActivationModal.State.MOVING:
		return
	var token: SquadronToken = _squadron_modal.get_selected_token()
	if token == null:
		return
	var desired: Vector2 = _token_container.get_global_mouse_position()
	var offset: Vector2 = desired - _squadron_move_original_pos
	if offset.length() > _squadron_move_max_dist:
		desired = _squadron_move_original_pos + \
				offset.normalized() * _squadron_move_max_dist
	var side: float = GameScale.play_area_side_px
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	_move_squadron_token.call(token, desired, side, top_y, bottom_y, false)
	var post_offset: Vector2 = token.global_position - \
			_squadron_move_original_pos
	if post_offset.length() > _squadron_move_max_dist:
		token.global_position = _squadron_move_original_pos + \
				post_offset.normalized() * _squadron_move_max_dist
	if _squadron_move_overlay:
		_squadron_move_overlay.update_tracking_position(
				token.global_position)


# ---------------------------------------------------------------------------
# Internal callbacks
# ---------------------------------------------------------------------------

## Called after the squadron modal accepts a squadron click.
## Requirements: SQM-001, SQM-002.
func _on_squadron_selected_in_modal(token: SquadronToken) -> void:
	_remove_squadron_overlay()
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance == null:
		return
	if _highlight_active.is_valid():
		_highlight_active.call(instance)
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	# Refresh engagement flags from live positions — a squadron may have
	# been destroyed during a prior activation this turn, leaving the
	# cached is_engaged flag stale (Bug H).
	EngagementResolver.update_engagement_flags(all_squads)
	var can_move: bool = EngagementResolver.can_squadron_move(
			instance, token.global_position, all_squads)
	var has_targets: bool = _squadron_has_valid_targets(
			instance, token, all_squads)
	var faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE
	if instance.squadron_data:
		faction = instance.squadron_data.faction
	var speed: int = 3
	if instance.squadron_data:
		speed = instance.squadron_data.speed
	_squadron_move_max_dist = SquadronMover._get_max_move_distance(speed)
	_squadron_move_overlay = SquadronMoveOverlay.new()
	_squadron_move_overlay.name = "SquadronMoveOverlay"
	_token_container.add_child(_squadron_move_overlay)
	_token_container.move_child(_squadron_move_overlay, 0)
	_squadron_move_overlay.setup(
			token.global_position, speed, can_move, faction,
			token.get_radius_px())
	_squadron_modal.set_action_availability(can_move, has_targets)
	_log.info("Squadron overlay shown for %s (can_move=%s, targets=%s)." % [
			instance.data_key, str(can_move), str(has_targets)])


## Called when the modal emits move_requested.
## Requirements: SQM-003.
func _on_squadron_move_requested(token: SquadronToken) -> void:
	_squadron_move_original_pos = token.global_position
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance and instance.squadron_data:
		_squadron_move_max_dist = SquadronMover._get_max_move_distance(
				instance.squadron_data.speed)
	_log.info("Squadron move started — token follows mouse.")


## Called when the modal emits move_commit_requested.
## Requirements: SQM-006, SQM-007.
func _on_squadron_move_commit(token: SquadronToken) -> void:
	_remove_squadron_overlay()
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	EngagementResolver.update_engagement_flags(all_squads)
	EventBus.squadron_moved.emit(token)
	_log.info("Squadron move committed — engagement updated.")


## Called when the modal emits attack_requested.
## Requirements: SQA-ATK-001.
func _on_squadron_attack_requested(token: SquadronToken) -> void:
	_start_squadron_attack.call(token)
	var key: String = "?"
	var inst: SquadronInstance = token.get_squadron_instance()
	if inst:
		key = inst.data_key
	_log.info("Squadron attack requested for %s." % key)


## Called when a single squadron activation is done.
## Requirements: SQA-TM-002, SQA-TM-003, SQA-013.
func _on_squadron_activation_done(instance: SquadronInstance) -> void:
	var token: SquadronToken = _find_squadron_token_for_instance(instance)
	if token:
		token.set_activated_visual(true)
	EventBus.squadron_activation_ended.emit(instance)
	_remove_squadron_overlay()
	if _squadron_modal and _squadron_modal.is_command_mode():
		instance.activated_this_round = true
		_log.info("Command-mode activation done: %s" % instance.data_key)
		return
	_squadron_activation_count += 1
	_log.info("Squadron activation done: %s (%d of %d)" % [
			instance.data_key, _squadron_activation_count,
			Constants.SQUADRONS_PER_ACTIVATION])
	if GameManager.get_current_phase() != Constants.GamePhase.SQUADRON:
		_log.info("Phase already advanced past SQUADRON — skip re-open.")
		return
	if _squadron_activation_count < Constants.SQUADRONS_PER_ACTIVATION:
		var next_num: int = _squadron_activation_count + 1
		if _squadron_modal:
			_squadron_modal.open_for_turn(
					next_num, Constants.SQUADRONS_PER_ACTIVATION)
	else:
		_log.info("All squadron activations done for player %d." %
				GameManager.active_player)
		hide_ui()


## Called when the squadron modal is dismissed by the player.
## Requirements: SQA-011.
func _on_squadron_modal_closed() -> void:
	if _squadron_modal and _squadron_modal.is_command_mode():
		_log.info("Squadron command modal dismissed — show activation "
				+ "button.")
		_show_activation_button.call()
		return
	if _show_squadron_modal_button:
		_show_squadron_modal_button.show_button()
		_show_squadron_modal_button.update_position(
				get_viewport().get_visible_rect().size)
	_log.info("Squadron modal closed — button shown.")


## Called when the player presses the ShowSquadronModalButton.
## Requirements: SQA-013.
func _on_show_squadron_modal_requested() -> void:
	if _show_squadron_modal_button:
		_show_squadron_modal_button.hide_button()
	if _squadron_modal:
		_squadron_modal.visible = true
	_log.info("Squadron modal re-opened via button.")


## Called when the squadron command flow is complete.
## Emits [signal squadron_command_done] for game_board to advance
## the activation step.
## Requirements: CM-020.
func _on_squadron_command_done() -> void:
	_log.info("Squadron command done — signalling game_board.")
	dismiss_cmd_range_overlay()
	squadron_command_done.emit()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Shows the squadron command range overlay on the given ship.
func _show_squad_cmd_range_overlay(ship_token: ShipToken) -> void:
	dismiss_cmd_range_overlay()
	_squad_cmd_range_overlay = RangeOverlayScene.new()
	_squad_cmd_range_overlay.name = "SquadCmdRangeOverlay"
	_token_container.add_child(_squad_cmd_range_overlay)
	_token_container.move_child(_squad_cmd_range_overlay, 0)
	_squad_cmd_range_overlay.setup(ship_token)
	_log.info("Squadron command range overlay displayed.")


## Commits the squadron's current position after a click during MOVING.
## Requirements: SQM-004, SQM-005.
func _commit_squadron_placement(token: SquadronToken) -> void:
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance == null:
		return
	var all_squads: Array[Dictionary] = _build_all_squadron_positions()
	var bases: Array[ShipBase] = _build_ship_bases()
	var error: String = SquadronMover.validate_move(
			instance, _squadron_move_original_pos, token.global_position,
			all_squads, bases)
	if error.is_empty():
		_on_squadron_move_commit(token)
		var updated_squads: Array[Dictionary] = \
				_build_all_squadron_positions()
		var new_has_targets: bool = _squadron_has_valid_targets(
				instance, token, updated_squads)
		_squadron_modal.set_action_availability(false, new_has_targets)
		_squadron_modal.notify_move_completed()
		_log.info("Squadron placed at %s." % str(token.global_position))
	else:
		_squadron_modal.notify_move_preview_failed(error)
		_log.info("Squadron placement invalid: %s" % error)


## Removes the squadron movement overlay if present.
func _remove_squadron_overlay() -> void:
	if _squadron_move_overlay:
		_squadron_move_overlay.queue_free()
		_squadron_move_overlay = null


## Finds the [SquadronToken] on the board bound to the given instance.
func _find_squadron_token_for_instance(
		instance: SquadronInstance) -> SquadronToken:
	for child: Node in _token_container.get_children():
		if child is SquadronToken:
			var st: SquadronToken = child as SquadronToken
			if st.get_squadron_instance() == instance:
				return st
	return null


## Builds an array of {"instance": …, "position": …} for all non-destroyed
## squadrons on the board.
func _build_all_squadron_positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child: Node in _token_container.get_children():
		if child is SquadronToken:
			var st: SquadronToken = child as SquadronToken
			var inst: SquadronInstance = st.get_squadron_instance()
			if inst and not inst.is_destroyed():
				result.append({
					"instance": inst,
					"position": st.global_position,
				})
	return result


## Builds an array of [ShipBase] for all ships on the board.
func _build_ship_bases() -> Array[ShipBase]:
	var result: Array[ShipBase] = []
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var ship: ShipToken = child as ShipToken
			var inst: ShipInstance = ship.get_ship_instance()
			if inst and inst.ship_data:
				var xform: Transform2D = Transform2D(
						ship.global_rotation, ship.global_position)
				result.append(ShipBase.new(
						inst.ship_data.ship_size, xform))
	return result


## Returns true if the squadron has at least one valid attack target.
## When engaged, only engaged enemy squadrons count as valid targets.
## Engagement is computed freshly from live positions to avoid stale flags.
## Rules Reference: "Squadron Attacks", RRG p.19; "Engagement" p.4.
func _squadron_has_valid_targets(
		instance: SquadronInstance,
		token: SquadronToken,
		all_squads: Array[Dictionary]) -> bool:
	var engaged: bool = EngagementResolver.is_engaged(
			instance, token.global_position, all_squads)
	if engaged:
		return _any_enemy_squadron_in_range(instance, token, all_squads)
	if _any_enemy_squadron_in_range(instance, token, all_squads):
		return true
	return _any_enemy_ship_in_range(instance, token)


## Returns true if any enemy squadron is within distance 1 of [param token].
func _any_enemy_squadron_in_range(
		instance: SquadronInstance,
		token: SquadronToken,
		all_squads: Array[Dictionary]) -> bool:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist1_px: float = EngagementResolver._get_distance_1_px()
	var pos: Vector2 = token.global_position
	for entry: Dictionary in all_squads:
		var other: SquadronInstance = entry["instance"] as SquadronInstance
		if other == instance or other.owner_player == instance.owner_player:
			continue
		if other.is_destroyed():
			continue
		var edge_dist: float = pos.distance_to(
				entry["position"] as Vector2) - radius * 2.0
		if edge_dist <= dist1_px:
			return true
	return false


## Returns true if any enemy ship is within distance 1 of [param token].
## Uses proper polyline edge-to-circle distance via RangeFinder to handle
## rectangular ship bases correctly at all approach angles.
## Rules Reference: RRG "Range and Distance" p.14 — "measure from the
## closest point of the first object to the closest point of the second."
func _any_enemy_ship_in_range(
		instance: SquadronInstance,
		token: SquadronToken) -> bool:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var dist1_px: float = EngagementResolver._get_distance_1_px()
	var pos: Vector2 = token.global_position
	for child: Node in _token_container.get_children():
		if not child is ShipToken:
			continue
		var ship: ShipToken = child as ShipToken
		var ship_inst: ShipInstance = ship.get_ship_instance()
		if ship_inst == null or \
				ship_inst.owner_player == instance.owner_player:
			continue
		if _ship_in_distance_1(pos, radius, ship, dist1_px):
			return true
	return false


## Returns true if any hull-zone edge of [param ship] is within
## [param dist1_px] of the squadron circle at [param pos]/[param radius].
func _ship_in_distance_1(pos: Vector2, radius: float,
		ship: ShipToken, dist1_px: float) -> bool:
	var hw: float = ship.get_half_width()
	var hl: float = ship.get_half_length()
	var rot: float = ship.global_rotation
	var sp: Vector2 = ship.global_position
	for zone_val: int in Constants.HullZone.values():
		var zone: Constants.HullZone = zone_val as Constants.HullZone
		var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				sp, rot, hw, hl, zone)
		var result: Dictionary = RangeFinder.measure_range_squad_to_ship(
				pos, radius, edge)
		if result["distance"] <= dist1_px:
			return true
	return false

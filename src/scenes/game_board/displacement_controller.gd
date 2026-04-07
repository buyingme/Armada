## Controls the squadron displacement flow after a ship maneuver causes
## ship–squadron overlap.
##
## Extracted from [GameBoard] as part of refactoring Phase C1.
## Owns all displacement state and UI (modal, mouse-follow, validation).
## Communicates back to [GameBoard] via the [signal displacement_completed]
## signal.
##
## Rules Reference: RRG "Overlapping", p.8 — OV-001–004.
class_name DisplacementController
extends Node2D


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when all displaced squadrons have been placed and the camera
## has returned to the active player.  GameBoard resumes the activation
## flow (shows End Activation button).
signal displacement_completed


# ---------------------------------------------------------------------------
# Dependencies (injected via initialize)
# ---------------------------------------------------------------------------

## Logger instance.
var _log: GameLogger = GameLogger.new("Displacement")

## Camera reference — used for rotating to opponent / back.
var _camera: BoardCamera = null

## Callable returning Array[SquadronToken] from GameBoard.
var _get_squadron_tokens: Callable

## Callable returning Array[ShipToken] from GameBoard.
var _get_ship_tokens: Callable

## Reference to ShowActivationButton — hidden during displacement.
var _show_activation_button: ShowActivationButton = null

## Reference to ActivationModal — closed during displacement.
var _activation_modal: ActivationModal = null


# ---------------------------------------------------------------------------
# Displacement state (owned by this controller)
# ---------------------------------------------------------------------------

## Queue of displaced squadron tokens awaiting placement by the opponent.
var _displacement_queue: Array[SquadronToken] = []

## The ship base that displaced the squadrons (for touch-validation).
var _displacement_ship_base: ShipBase = null

## Index into [member _displacement_queue] for the next squadron to place.
var _displacement_index: int = 0

## True while a displaced squadron follows the mouse (snap-to-edge mode).
var _displacement_moving: bool = false

## Displacement modal panel (squadron checklist + commit).
var _displacement_modal: DisplacementModal = null

## CanvasLayer for the displacement modal.
var _displacement_modal_layer: CanvasLayer = null


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Injects shared references from [GameBoard].
## [param camera] — board camera for perspective rotation.
## [param get_squadron_tokens] — Callable returning Array[SquadronToken].
## [param get_ship_tokens] — Callable returning Array[ShipToken].
## [param show_activation_button] — button hidden during displacement.
## [param activation_modal] — modal closed during displacement.
func initialize(camera: BoardCamera,
		get_squadron_tokens: Callable,
		get_ship_tokens: Callable,
		show_activation_button: ShowActivationButton,
		activation_modal: ActivationModal) -> void:
	_camera = camera
	_get_squadron_tokens = get_squadron_tokens
	_get_ship_tokens = get_ship_tokens
	_show_activation_button = show_activation_button
	_activation_modal = activation_modal


## Returns true when a displaced squadron is following the mouse.
func is_displacement_active() -> bool:
	return _displacement_moving


## Starts the squadron displacement flow.  Hides the "Show Activation
## Sequence" button, flips the camera to the opposing player, then
## presents a modal for placing each displaced squadron.
## Rules Reference: RRG "Overlapping", p.8 — OV-002, OV-003.
func start(displaced: Array[SquadronToken],
		ship_base: ShipBase) -> void:
	_displacement_queue = displaced.duplicate()
	_displacement_ship_base = ship_base
	_displacement_index = 0
	_displacement_moving = false
	# Disable input on displaced squadron tokens so their _unhandled_input
	# doesn't consume clicks meant for the displacement lock action.
	for sq: SquadronToken in displaced:
		sq.set_process_unhandled_input(false)
	# Hide the activation sequence button during displacement.
	if _show_activation_button:
		_show_activation_button.hide_button()
	if _activation_modal and _activation_modal.is_open():
		_activation_modal.close()
	_log.info("Starting squadron displacement: %d squadron(s)."
			% displaced.size())
	# Flip camera to the opposing player.
	var opponent: int = 1 - GameManager.get_active_player()
	_camera.rotate_to_player(opponent)
	# Wait for the rotation to finish before prompting.
	if not EventBus.perspective_change_complete.is_connected(
			_on_camera_ready):
		EventBus.perspective_change_complete.connect(
				_on_camera_ready, CONNECT_ONE_SHOT)


## Called by [GameBoard._unhandled_input] when left-click occurs during
## displacement.  Locks the current squadron at its snapped position.
func handle_lock_click() -> void:
	_lock_displacement_position()


# ---------------------------------------------------------------------------
# Godot callbacks
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_move_displaced_squadron_to_mouse()


# ---------------------------------------------------------------------------
# Internal — camera rotation callbacks
# ---------------------------------------------------------------------------

## Called once the camera finishes rotating to the opponent's view.
func _on_camera_ready() -> void:
	_create_displacement_modal()
	_select_displacement_squadron(_displacement_modal.get_first_unchecked())


## Called when the camera returns to the active player after displacement.
## Fires [signal displacement_completed] so GameBoard can resume.
func _on_camera_returned() -> void:
	displacement_completed.emit()


# ---------------------------------------------------------------------------
# Internal — squadron selection & movement
# ---------------------------------------------------------------------------

## Selects a squadron for placement: auto-places it at the nearest ship
## edge and enters mouse-follow mode.  Updates the modal to highlight
## the active row.
func _select_displacement_squadron(index: int) -> void:
	if index < 0 or index >= _displacement_queue.size():
		return
	_displacement_index = index
	var sq_token: SquadronToken = _displacement_queue[index]
	var sq_radius: float = sq_token.get_radius_px()
	# Auto-place at the nearest ship edge from the old position.
	var snap_pos: Vector2 = OverlapResolver.snap_to_ship_edge(
			sq_token.global_position, sq_radius, _displacement_ship_base)
	sq_token.global_position = snap_pos
	sq_token.visible = true
	_displacement_moving = true
	if _displacement_modal:
		_displacement_modal.set_active(index)
	var sq_name: String = _get_squadron_display_name(sq_token)
	_log.info("Displacement: auto-placed %s at %s — mouse-follow active."
			% [sq_name, str(snap_pos)])


## Each frame, snaps the current displaced squadron to the ship edge
## at the closest point to the mouse cursor.  Tints the token red when
## the proposed position overlaps another squadron or ship.
func _move_displaced_squadron_to_mouse() -> void:
	if not _displacement_moving:
		return
	if _displacement_index >= _displacement_queue.size():
		return
	var sq_token: SquadronToken = _displacement_queue[_displacement_index]
	var mouse_pos: Vector2 = get_global_mouse_position()
	var sq_radius: float = sq_token.get_radius_px()
	var snap_pos: Vector2 = OverlapResolver.snap_to_ship_edge(
			mouse_pos, sq_radius, _displacement_ship_base)
	sq_token.global_position = snap_pos
	# Visual overlap feedback: tint red if placement is invalid.
	var other_squads: Array = _build_displacement_other_squads(sq_token)
	var other_ships: Array = _build_all_ship_bases()
	var resolver: OverlapResolver = OverlapResolver.new()
	var err_msg: String = resolver.validate_squadron_placement(
			snap_pos, sq_radius, _displacement_ship_base,
			other_ships, other_squads)
	if err_msg != "":
		sq_token.modulate = Color(1.0, 0.4, 0.4)
	else:
		sq_token.modulate = Color.WHITE


# ---------------------------------------------------------------------------
# Internal — lock & commit
# ---------------------------------------------------------------------------

## Called on left-click during displacement: locks the squadron at its
## current snapped position and checks it in the modal.  Auto-selects
## the next unchecked squadron if one exists.
## Rejects the click if the position overlaps another squadron or ship.
## Rules Reference: RRG "Overlapping", p.8 — OV-002; SM-003.
func _lock_displacement_position() -> void:
	var sq_token: SquadronToken = _displacement_queue[_displacement_index]
	var sq_radius: float = sq_token.get_radius_px()
	var sq_pos: Vector2 = sq_token.global_position
	# Validate placement against all other squadrons and ships.
	var other_squads: Array = _build_displacement_other_squads(sq_token)
	var other_ships: Array = _build_all_ship_bases()
	var resolver: OverlapResolver = OverlapResolver.new()
	var err_msg: String = resolver.validate_squadron_placement(
			sq_pos, sq_radius, _displacement_ship_base,
			other_ships, other_squads)
	if err_msg != "":
		_log.warn("Displacement placement rejected: %s" % err_msg)
		return
	_displacement_moving = false
	sq_token.modulate = Color.WHITE
	var sq_name: String = _get_squadron_display_name(sq_token)
	_log.info("Displacement: %s locked at %s."
			% [sq_name, str(sq_token.global_position)])
	# Check in modal.
	if _displacement_modal:
		_displacement_modal.check_squadron(_displacement_index)
		# Auto-select the next unchecked squadron.
		var next: int = _displacement_modal.get_first_unchecked()
		if next >= 0:
			_select_displacement_squadron(next)


## Called when the modal emits squadron_selected (row click on unchecked).
func _on_row_selected(index: int) -> void:
	_select_displacement_squadron(index)


## Called when the modal emits squadron_unchecked (row click on checked).
## Un-checks the squadron and re-enters mouse-follow for repositioning.
func _on_row_unchecked(index: int) -> void:
	_displacement_index = index
	_displacement_moving = true
	if _displacement_modal:
		_displacement_modal.uncheck_squadron(index)
	var sq_name: String = _get_squadron_display_name(
			_displacement_queue[index])
	_log.info("Displacement: %s unchecked for repositioning." % sq_name)


## Called when the modal emits placement_committed (all checked, commit).
func _on_committed() -> void:
	_log.info("Displacement commit pressed — all squadrons placed.")
	_finish_displacement()


## Finishes the displacement flow: removes modal, flips camera back,
## and ends the activation (triggering normal turn transition + banner).
func _finish_displacement() -> void:
	_displacement_moving = false
	# Re-enable input on displaced squadron tokens and reset tint.
	for sq: SquadronToken in _displacement_queue:
		sq.set_process_unhandled_input(true)
		sq.modulate = Color.WHITE
	_displacement_queue.clear()
	_displacement_ship_base = null
	_remove_displacement_modal()
	TooltipManager.hide_tooltip()
	_log.info("All displaced squadrons placed — flipping camera back.")
	# Flip camera back to the active player.
	var active: int = GameManager.get_active_player()
	_camera.rotate_to_player(active)
	if not EventBus.perspective_change_complete.is_connected(
			_on_camera_returned):
		EventBus.perspective_change_complete.connect(
				_on_camera_returned, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------------------
# Internal — helpers
# ---------------------------------------------------------------------------

## Builds an Array of [SquadronBase] for every squadron that is NOT
## the currently-moving displaced squadron.  This includes:
## - All non-displaced squadrons on the board.
## - Displaced squadrons that have already been placed (checked).
## Used by displacement validation to prevent squadron-squadron overlap.
## Rules Reference: SM-003 — squadrons cannot overlap each other.
func _build_displacement_other_squads(
		exclude_token: SquadronToken) -> Array:
	var bases: Array = []
	# All non-displaced board squadrons.
	for sq_token: SquadronToken in _get_squadron_tokens.call():
		if sq_token == exclude_token:
			continue
		if _displacement_queue.has(sq_token):
			continue
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.is_destroyed():
			continue
		bases.append(SquadronBase.new(
				sq_token.global_position, sq_token.get_radius_px()))
	# Already-placed displaced squadrons (checked in the modal).
	if _displacement_modal:
		var checked: Array[bool] = _displacement_modal.get_checked_states()
		for i: int in range(_displacement_queue.size()):
			if _displacement_queue[i] == exclude_token:
				continue
			if i < checked.size() and checked[i]:
				var sq: SquadronToken = _displacement_queue[i]
				bases.append(SquadronBase.new(
						sq.global_position, sq.get_radius_px()))
	return bases


## Builds an Array of [ShipBase] for every non-destroyed ship on the board.
## Used by displacement validation to prevent squadron-ship overlap.
func _build_all_ship_bases() -> Array:
	var bases: Array = []
	for token: ShipToken in _get_ship_tokens.call():
		var inst: ShipInstance = token.get_ship_instance()
		if inst and inst.is_destroyed():
			continue
		var xform: Transform2D = Transform2D(
				token.global_rotation, token.global_position)
		bases.append(ShipBase.new(token.get_ship_size(), xform))
	return bases


## Returns a display-friendly name for a squadron token.
func _get_squadron_display_name(sq_token: SquadronToken) -> String:
	var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
	if sq_inst and sq_inst.squadron_data:
		return sq_inst.squadron_data.squadron_name
	return "Squadron"


# ---------------------------------------------------------------------------
# Internal — modal lifecycle
# ---------------------------------------------------------------------------

## Creates the displacement modal on a CanvasLayer and wires its signals.
func _create_displacement_modal() -> void:
	if _displacement_modal_layer != null:
		return
	_displacement_modal_layer = CanvasLayer.new()
	_displacement_modal_layer.name = "DisplacementModalLayer"
	_displacement_modal_layer.layer = 96
	add_child(_displacement_modal_layer)

	_displacement_modal = DisplacementModal.new()
	_displacement_modal.name = "DisplacementModal"
	# Build the names list from the queue.
	var names: Array[String] = []
	for sq_token: SquadronToken in _displacement_queue:
		names.append(_get_squadron_display_name(sq_token))
	_displacement_modal.squadron_selected.connect(_on_row_selected)
	_displacement_modal.squadron_unchecked.connect(_on_row_unchecked)
	_displacement_modal.placement_committed.connect(_on_committed)
	_displacement_modal_layer.add_child(_displacement_modal)
	_displacement_modal.open(names)


## Removes the displacement modal and its CanvasLayer.
func _remove_displacement_modal() -> void:
	if _displacement_modal:
		_displacement_modal.close_and_clear()
	if _displacement_modal_layer:
		_displacement_modal_layer.queue_free()
		_displacement_modal_layer = null
		_displacement_modal = null

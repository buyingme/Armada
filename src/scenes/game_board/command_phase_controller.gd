## Controls the Command Phase dial-assignment flow.
##
## Extracted from [GameBoard] as part of refactoring Phase C3.
## Owns the [CommandDialPicker], [CommandDialOrderModal], and the
## ship queue that drives the picker sequence.  Communicates back
## to [GameBoard] via [signal phase_complete] so the HUD can update.
##
## Rules Reference: "Command Phase", p.3 — CP-001.
## Requirements: TF-002.
class_name CommandPhaseController
extends Node


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the Command Phase completes (all ships assigned).
## GameBoard connects this to update the phase HUD.
signal phase_complete


# ---------------------------------------------------------------------------
# Dependencies (injected via initialize)
# ---------------------------------------------------------------------------

## Logger instance.
var _log: GameLogger = GameLogger.new("CmdPhase")


# ---------------------------------------------------------------------------
# Owned state
# ---------------------------------------------------------------------------

## Queue of ships still awaiting dial assignment.
## Populated at the start of each Command Phase, drained as each picker
## is confirmed.  Initiative player's ships come first.
var _ships_needing_dials: Array[ShipInstance] = []

## Command Dial Picker modal (shared, one at a time).
var _command_dial_picker: CommandDialPicker = null

## Command Dial Order Modal (shared, one at a time).
var _command_dial_order_modal: CommandDialOrderModal = null


# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Creates the UI and connects EventBus signals.
## Must be called once after the controller is added to the scene tree.
func initialize() -> void:
	_create_command_phase_ui()
	EventBus.command_picker_requested.connect(_on_command_picker_requested)
	EventBus.command_picker_confirmed.connect(_on_picker_confirmed)
	EventBus.command_dial_order_requested.connect(
			_on_command_dial_order_requested)
	EventBus.command_phase_complete.connect(_on_command_phase_complete)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Builds the ordered queue of ships needing dials and opens the first
## picker.  In hot-seat mode, only queues ships for the currently
## assigning player; in network mode, queues both (initiative first).
## Rules Reference: CP-001 — all ships must be assigned dials.
## Requirements: TF-002 — initiative player assigns first in hot-seat.
func begin_command_dial_flow() -> void:
	_ships_needing_dials.clear()
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var _current_round: int = gs.current_round
	var assigning: int = GameManager.get_command_assigning_player()

	var player_order: Array[int] = _build_player_order(gs, assigning)

	for pi: int in player_order:
		_enqueue_ships_for_player(gs, pi)
	_log.info("Command Phase: %d ships need dials (player %d)." % [
			_ships_needing_dials.size(), assigning])
	_advance_picker_queue()


# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

## Called when the player explicitly requests the picker for a ship
## (e.g. from the card panel).  Opens the picker.
func _on_command_picker_requested(
		ship_ref: RefCounted, current_round: int) -> void:
	if ship_ref is ShipInstance:
		_command_dial_picker.open(
				ship_ref as ShipInstance, current_round)
		_command_dial_picker.centre_on_screen(
				get_viewport().get_visible_rect().size)


## Called when the picker confirms dials for a ship.
## Removes the ship from the queue and advances to the next ship.
## GameManager handles the actual dial assignment and auto-submit.
func _on_picker_confirmed(
		ship_ref: RefCounted, _commands: Array) -> void:
	if ship_ref is ShipInstance:
		var idx: int = _ships_needing_dials.find(
				ship_ref as ShipInstance)
		if idx >= 0:
			_ships_needing_dials.remove_at(idx)
	_advance_picker_queue()


## Called when a ship's dial order is requested (from card panel click).
## Opens the [CommandDialOrderModal].
func _on_command_dial_order_requested(ship_ref: RefCounted) -> void:
	if ship_ref is ShipInstance:
		_command_dial_order_modal.open(ship_ref as ShipInstance)
		_command_dial_order_modal.centre_on_screen(
				get_viewport().get_visible_rect().size)


## Called when the Command Phase completes (both players submitted).
## Clears the queue, hides any still-open picker, and notifies GameBoard.
##
## I5b-5: in network mode, [CommandDialPicker] may have been opened
## speculatively by [method GameBoard._on_active_player_changed]
## right before the host broadcasts pre-assigned (fixed) round-1 dials
## via [code]apply_fixed_round1_commands[/code].  The remote-mirror
## handlers complete the dial assignment without ever calling
## [signal command_picker_confirmed], leaving the picker visible into
## Ship Phase — where pressing Confirm submits an out-of-phase
## [AssignDialCommand] that the server rejects with "Not in Command
## Phase."  Closing the picker on phase complete prevents that.
func _on_command_phase_complete() -> void:
	_ships_needing_dials.clear()
	if _command_dial_picker != null and _command_dial_picker.is_open():
		_command_dial_picker.close()
	_log.info("Command Phase complete — advancing to Ship Phase.")
	phase_complete.emit()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Opens the picker for the next ship in the queue, or does nothing
## if the queue is empty (GameManager handles auto-submit).
func _advance_picker_queue() -> void:
	if _ships_needing_dials.is_empty():
		return
	var ship: ShipInstance = _ships_needing_dials[0]
	var current_round: int = GameManager.get_current_round()
	_command_dial_picker.open(ship, current_round)
	_command_dial_picker.centre_on_screen(
			get_viewport().get_visible_rect().size)


## Builds the player order array based on hot-seat vs. network mode.
## Phase K3: branches on [code]NetworkManager.get_local_player_index()[/code]
## (which returns [code]-1[/code] outside a network session) instead of
## reading [code]PlayMode[/code] directly.  This is the same conceptual
## axis — "am I in a network session?" — but expressed in terms of the
## value that actually determines the queue contents.
func _build_player_order(
		gs: GameState, assigning: int) -> Array[int]:
	var order: Array[int] = []
	var local: int = NetworkManager.get_local_player_index()
	if local >= 0:
		# Network: each peer only assigns dials for their own ships.
		order.append(local)
	elif assigning >= 0:
		# Hot-seat: only the currently-assigning player's ships.
		order.append(assigning)
	else:
		# Fallback (e.g. test setup with no active session): both
		# players, initiative first.
		order.append(gs.initiative_player)
		order.append(1 - gs.initiative_player)
	return order


## Enqueues non-destroyed ships that still need dials for [param player].
func _enqueue_ships_for_player(gs: GameState, player: int) -> void:
	var ps: PlayerState = gs.get_player_state(player)
	if ps == null:
		return
	for s: Variant in ps.ships:
		if s is ShipInstance:
			var si: ShipInstance = s as ShipInstance
			if si.is_destroyed():
				continue
			if si.command_dial_stack == null:
				continue
			var needed: int = si.command_dial_stack.get_dials_needed()
			if needed > 0:
				_ships_needing_dials.append(si)


## Instantiates the [CommandDialPicker] and [CommandDialOrderModal] on a
## CanvasLayer above the card panels so they overlay everything.
func _create_command_phase_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CommandPhaseUILayer"
	layer.layer = 60
	add_child(layer)

	_command_dial_picker = CommandDialPicker.new()
	_command_dial_picker.name = "CommandDialPicker"
	_command_dial_picker.visible = false
	layer.add_child(_command_dial_picker)

	_command_dial_order_modal = CommandDialOrderModal.new()
	_command_dial_order_modal.name = "CommandDialOrderModal"
	_command_dial_order_modal.visible = false
	layer.add_child(_command_dial_order_modal)

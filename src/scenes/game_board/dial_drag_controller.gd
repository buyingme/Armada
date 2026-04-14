## Controls the command-dial drag-and-drop flow for ship activation.
##
## Extracted from [GameBoard] as part of refactoring Phase C2.
## Owns all drag state and the floating preview UI.  Communicates
## outcomes back to [GameBoard] via [signal ship_activated] and
## [signal token_converted].
##
## Requirements: UI-024, UI-027, UI-028.
## Rules Reference: "Command Dials", p.3.
class_name DialDragController
extends Node2D


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the dial is dropped on the owning ship token (full command).
## GameBoard connects this to run [method GameManager.activate_ship] and
## set up the activation state.
signal ship_activated(token: ShipToken, ship: ShipInstance)

## Emitted when the dial is dropped on the owning ship's card-panel entry
## (convert to command token).  GameBoard connects this to run
## [method GameManager.activate_ship_as_token] and finish activation.
signal token_converted(ship: ShipInstance)


# ---------------------------------------------------------------------------
# Dependencies (injected via initialize)
# ---------------------------------------------------------------------------

## Logger instance.
var _log: GameLogger = GameLogger.new("DialDrag")

## Callable(world_pos: Vector2) -> ShipToken — resolves a world position
## to the ship token whose base contains it, or null.
var _find_ship_token_at_fn: Callable

## Callable(screen_pos: Vector2) -> ShipInstance — resolves a screen
## position to the ShipInstance whose card-panel entry contains it, or null.
var _find_card_panel_hit_fn: Callable

## Callable(ship: ShipInstance) -> bool — returns true when the Crew-Panic
## "BEFORE_REVEAL_DIAL" hook intercepts the drag (modal shown; the drag
## will start — or not — from the modal callback).
var _check_crew_panic_fn: Callable

## The TurnManagementLayer CanvasLayer that hosts the floating preview.
var _tm_layer: CanvasLayer = null


# ---------------------------------------------------------------------------
# Drag state (owned by this controller)
# ---------------------------------------------------------------------------

## Whether a command-dial drag is currently in progress.
var _drag_active: bool = false

## The ShipInstance whose dial is being dragged.
var _drag_ship_instance: ShipInstance = null

## Floating preview Control shown during drag (on TurnManagement layer).
var _drag_preview: Control = null


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Map from CommandType to icon filename for the drag preview.
const CMD_DRAG_ICON_FILES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}


# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Injects all external dependencies.  Must be called once after the
## controller is added to the scene tree.
## [param find_ship_token_at] — Callable(Vector2) -> ShipToken
## [param find_card_panel_hit] — Callable(Vector2) -> ShipInstance
## [param check_crew_panic] — Callable(ShipInstance) -> bool
## [param tm_layer] — TurnManagementLayer CanvasLayer
func initialize(
		find_ship_token_at: Callable,
		find_card_panel_hit: Callable,
		check_crew_panic: Callable,
		tm_layer: CanvasLayer,
) -> void:
	_find_ship_token_at_fn = find_ship_token_at
	_find_card_panel_hit_fn = find_card_panel_hit
	_check_crew_panic_fn = check_crew_panic
	_tm_layer = tm_layer
	EventBus.dial_drag_started.connect(_on_dial_drag_started)


# ---------------------------------------------------------------------------
# Process / Input
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _drag_active and _drag_preview:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		_drag_preview.position = mouse - _drag_preview.size * 0.5


func _input(event: InputEvent) -> void:
	if not _drag_active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_handle_drag_release()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true while a command-dial drag is in progress.
func is_drag_active() -> bool:
	return _drag_active


## Starts the command-dial drag for [param ship].
## Public so that the Crew-Panic callback in GameBoard can resume the drag
## after the modal is dismissed.
func start_dial_drag(ship: ShipInstance) -> void:
	_drag_active = true
	_drag_ship_instance = ship
	# Dial is already revealed — read the command type for the preview icon.
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	var cmd: int = int(revealed.get("command", 0)) \
			if not revealed.is_empty() else -1
	_create_drag_preview(cmd)
	TooltipManager.show_text(
			"Drag to ship for full command effect\n"
			+"Drag to ship card for command token")
	_log.info("Dial drag started for '%s' (command: %d)." % [
			ship.data_key, cmd])


# ---------------------------------------------------------------------------
# EventBus handler
# ---------------------------------------------------------------------------

## Called when the player clicks on an already-revealed command dial in the
## card panel (second click of the two-step flow).  The dial was revealed by
## the first click in ShipCardPanel._handle_dial_stack_click().
## If Crew Panic is active, the modal is shown BEFORE the drag starts.
## Requirements: UI-024, UI-027.
func _on_dial_drag_started(ship_ref: RefCounted) -> void:
	if not ship_ref is ShipInstance:
		_log.info("dial_drag_started ignored — ship_ref is not ShipInstance.")
		return
	if _drag_active:
		_log.info("dial_drag_started ignored — drag already active.")
		return
	var ship: ShipInstance = ship_ref as ShipInstance
	# BEFORE_REVEAL_DIAL hook — Crew Panic must fire before the drag.
	# Rules Reference: "Crew Panic" — "Before you reveal a command dial …"
	if _check_crew_panic_fn.call(ship):
		return # Modal shown; drag will start (or not) in the callback.
	start_dial_drag(ship)


# ---------------------------------------------------------------------------
# Drag preview
# ---------------------------------------------------------------------------

## Creates a semi-transparent floating dial preview on the TurnManagement
## layer.  Shows the dial background with the revealed command icon
## composited on top when [param cmd] is valid, otherwise the hidden dial
## back.  The preview matches the dial size used on the card panel.
func _create_drag_preview(cmd: int = -1) -> void:
	var dial_w: float = GameScale.card_panel_dial_width_px
	var dial_h: float = GameScale.card_panel_dial_height_px

	_drag_preview = Control.new()
	_drag_preview.custom_minimum_size = Vector2(dial_w, dial_h)
	_drag_preview.size = Vector2(dial_w, dial_h)
	_drag_preview.modulate.a = 0.75
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_add_dial_bg_rect(_drag_preview, dial_w, dial_h)
	_add_dial_icon_rect(_drag_preview, cmd, dial_w, dial_h)

	if _tm_layer:
		_tm_layer.add_child(_drag_preview)


## Adds the dial background texture to the preview container.
func _add_dial_bg_rect(container: Control, w: float, h: float) -> void:
	var bg_tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", "cmd_dial_hidden.png")
	if bg_tex == null:
		return
	var bg_rect: TextureRect = TextureRect.new()
	bg_rect.texture = bg_tex
	bg_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.custom_minimum_size = Vector2(w, h)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg_rect)


## Adds the command icon texture on top of the dial background.
func _add_dial_icon_rect(container: Control, cmd: int,
		dial_w: float, dial_h: float) -> void:
	var icon_file: String = CMD_DRAG_ICON_FILES.get(cmd, "")
	if icon_file.is_empty():
		return
	var icon_tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", icon_file)
	if icon_tex == null:
		return
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = icon_tex
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_size: float = dial_h * 0.7
	var icon_offset: float = (dial_h - icon_size) * 0.5
	icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_rect.position = Vector2(
			(dial_w - icon_size) * 0.5, icon_offset)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon_rect)


# ---------------------------------------------------------------------------
# Drop handling
# ---------------------------------------------------------------------------

## Handles mouse button release during dial drag.
## First checks if the mouse is over the dragged ship's card panel entry
## (convert to token).  Falls back to checking ship tokens on the board
## (keep for full effect).  Otherwise cancels the drag.
## Requirements: UI-024, UI-028.
func _handle_drag_release() -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()

	# Check card panel drop first (convert to command token).
	var card_hit: ShipInstance = _find_card_panel_hit_fn.call(screen_pos)
	if card_hit and card_hit == _drag_ship_instance:
		var ship: ShipInstance = _drag_ship_instance
		SfxManager.play_sfx("droid_sound_long")
		_clean_up_drag()
		token_converted.emit(ship)
		return

	# Check board ship token drop (keep dial for full command effect).
	var world_pos: Vector2 = get_global_mouse_position()
	var target_token: ShipToken = _find_ship_token_at_fn.call(world_pos)

	if target_token and _is_valid_drop_target(target_token):
		var ship: ShipInstance = _drag_ship_instance
		SfxManager.play_sfx("droid_sound_long")
		_clean_up_drag()
		ship_activated.emit(target_token, ship)
	else:
		_cancel_drag()


## Returns true if [param token] is a valid drop target for the current drag.
## The token must be bound to the same ShipInstance being dragged, and the
## ship must not already be activated.
func _is_valid_drop_target(token: ShipToken) -> bool:
	if _drag_ship_instance == null:
		return false
	if token.get_ship_instance() != _drag_ship_instance:
		return false
	if _drag_ship_instance.activated_this_round:
		return false
	return true


## Cancels the current dial drag (invalid drop target or no target).
## Unreveals the dial so it returns to the hidden state.
func _cancel_drag() -> void:
	_log.info("Dial drag cancelled.")
	# Unreveal the dial before cleaning up (which clears _drag_ship_instance).
	if _drag_ship_instance:
		GameManager.submit_unreveal_dial(_drag_ship_instance)
	_clean_up_drag()
	EventBus.dial_drag_cancelled.emit()


## Cleans up drag state and removes the floating preview and help text.
func _clean_up_drag() -> void:
	_drag_active = false
	_drag_ship_instance = null
	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null
	TooltipManager.hide_tooltip()

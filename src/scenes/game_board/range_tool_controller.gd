## Manages the range overlay lifecycle: selection mode, creation, and dismissal.
##
## Owns the "select ship for range overlay" flag and the live
## [RangeOverlayScene] instance.  Extracted from game_board.gd as part of
## refactoring phase C6.
class_name RangeToolController
extends Node

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Whether we are in "select ship for range overlay" mode.
var _selecting: bool = false

## Active RangeOverlayScene instance (null when not displayed).
var _scene: RangeOverlayScene = null

## Token container — new RangeOverlayScene nodes are added here.
var _token_container: Node2D = null

## Logger instance.
var _log: GameLogger = GameLogger.new("RangeToolController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores the token container reference.
## [param container] — the Node2D that holds all tokens and overlay scenes.
func initialize(container: Node2D) -> void:
	_token_container = container


## Returns [code]true[/code] when the player must click a ship to show the
## overlay (selection mode).
func is_selecting() -> bool:
	return _selecting


## Returns the live [RangeOverlayScene] instance, or [code]null[/code].
func get_scene() -> RangeOverlayScene:
	return _scene


## Enters ship-selection mode.  The next ship click should call
## [method show_overlay].
## Requirements: RO-001, RO-002.
func start_selection() -> void:
	_selecting = true
	TooltipManager.show_text("Select a ship", Vector2.INF, 0.0, true)
	_log.info("Range overlay: ship selection mode active.")


## Cancels ship selection mode without showing the overlay.
func cancel_selection() -> void:
	_selecting = false
	TooltipManager.hide_tooltip()
	_log.info("Range overlay selection cancelled.")


## Shows the range overlay attached to [param token].
## Requirements: RO-003, RO-004, RO-005, RO-006.
func show_overlay(token: ShipToken) -> void:
	_selecting = false
	TooltipManager.hide_tooltip()
	if _scene:
		_scene.queue_free()
	_scene = RangeOverlayScene.new()
	_scene.name = "RangeOverlayScene"
	_token_container.add_child(_scene)
	# Move to index 0 so it draws above the map but behind all tokens.
	_token_container.move_child(_scene, 0)
	_scene.setup(token)
	_log.info("Range overlay displayed on ship.")


## Dismisses the range overlay and exits selection mode.
## Requirements: RO-007.
func dismiss() -> void:
	_selecting = false
	TooltipManager.hide_tooltip()
	if _scene:
		_scene.queue_free()
		_scene = null
	_log.info("Range overlay dismissed.")


## Checks if an Escape key press should dismiss the range overlay.
## Returns [code]true[/code] if the event was consumed.
func handle_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _scene:
		dismiss()
		get_viewport().set_input_as_handled()
		return true
	if _selecting:
		cancel_selection()
		get_viewport().set_input_as_handled()
		return true
	return false

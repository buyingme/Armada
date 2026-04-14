## Manages the maneuver tool lifecycle: selection mode, creation, and dismissal.
##
## Owns the "select ship for maneuver tool" flag and the live
## [ManeuverToolScene] instance.  Extracted from game_board.gd as part of
## refactoring phase C5.
class_name ManeuverToolController
extends Node

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Whether we are in "select ship for maneuver tool" mode.
var _selecting: bool = false

## Active ManeuverToolScene instance (null when not displayed).
var _scene: ManeuverToolScene = null

## Token container — new ManeuverToolScene nodes are added here.
var _token_container: Node2D = null

## Logger instance.
var _log: GameLogger = GameLogger.new("ManeuverToolController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores the token container reference.
## [param container] — the Node2D that holds all tokens and the maneuver tool.
func initialize(container: Node2D) -> void:
	_token_container = container


## Returns [code]true[/code] when the player must click a ship to attach the
## tool (simulation mode).
func is_selecting() -> bool:
	return _selecting


## Returns the live [ManeuverToolScene] instance, or [code]null[/code].
## Used by the activation flow to read tool state for maneuver execution.
func get_scene() -> ManeuverToolScene:
	return _scene


## Enters ship-selection mode (simulation).  The next ship click should call
## [method show_tool].
## Requirements: MT-U-002, MT-U-003.
func start_selection() -> void:
	_selecting = true
	TooltipManager.show_text("Select a ship", Vector2.INF, 0.0, true)
	_log.info("Maneuver tool: ship selection mode active.")


## Cancels ship selection mode without showing the tool.
func cancel_selection() -> void:
	_selecting = false
	TooltipManager.hide_tooltip()
	_log.info("Maneuver tool selection cancelled.")


## Creates a simulation-mode maneuver tool attached to [param token].
## Requirements: MT-U-004, MT-G-005, AC-08.
func show_tool(token: ShipToken) -> void:
	_selecting = false
	TooltipManager.hide_tooltip()
	if _scene:
		_scene.queue_free()
	_scene = ManeuverToolScene.new()
	_scene.name = "ManeuverToolScene"
	_token_container.add_child(_scene)
	_scene.setup(token)
	_log.info("Maneuver tool displayed on ship.")


## Creates an activation-mode maneuver tool attached to [param token].
## Called from the maneuver step of the ship activation sequence.
## Requirements: FLOW-003, AC-5b-03, EXE-004.
func show_activation_tool(
		token: ShipToken, activation_state: ShipActivationState,
		persistent_damage_handler: Callable = Callable()
) -> void:
	dismiss(null)
	_scene = ManeuverToolScene.new()
	_scene.name = "ManeuverToolScene"
	_token_container.add_child(_scene)
	_scene.setup(token)
	_scene.set_activation_mode(activation_state, persistent_damage_handler)


## Dismisses the maneuver tool and exits selection mode.
## If an activation ship is provided, clears the navigate-token spend preview.
## Requirements: MT-U-005, MT-U-006, AC-15.
func dismiss(activation_ship: ShipInstance) -> void:
	_selecting = false
	TooltipManager.hide_tooltip()
	# Clear Navigate token spend preview overlay.
	if activation_ship:
		EventBus.navigate_token_spend_preview.emit(activation_ship, false)
	if _scene:
		_scene.queue_free()
		_scene = null
	_log.info("Maneuver tool dismissed.")


## Checks if an Escape key press should dismiss the maneuver tool.
## Returns [code]true[/code] if the event was consumed.
func handle_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _scene:
		dismiss(null)
		get_viewport().set_input_as_handled()
		return true
	if _selecting:
		cancel_selection()
		get_viewport().set_input_as_handled()
		return true
	return false

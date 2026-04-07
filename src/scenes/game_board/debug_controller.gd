## Manages debug-mode UI overlays and interactions on the game board.
##
## Owns the deployment zone overlay, the DEBUG HUD label, the debug help
## panel, and the scenario saver.  Extracted from game_board.gd as part of
## refactoring phase C4.
class_name DebugController
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

# (none — debug controller does not need outward signals)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Deployment zone overlay (visible in debug mode only).
var _deploy_overlay: DeploymentZoneOverlay = null

## Debug HUD label (shows "DEBUG" in top-left corner).
var _debug_label: Label = null

## Debug help panel showing all keyboard shortcuts.
var _debug_help_panel: DebugHelpPanel = null

## Tracks whether the currently dragged token was inside its deployment zone
## on the previous frame, so the toast fires only on crossing (DBG-033).
var _was_in_deploy_zone: bool = true

## Scenario saver utility.
var _scenario_saver: ScenarioSaver = ScenarioSaver.new()

## Reference to the game board node (needed as parent for the overlay).
var _board: Node2D = null

## Callable that returns Array[ShipToken] — avoids direct dependency on
## game_board's internals.
var _get_ship_tokens: Callable

## Callable that returns Array[SquadronToken].
var _get_squadron_tokens: Callable

## Logger instance.
var _log: GameLogger = GameLogger.new("DebugController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Creates debug UI elements and connects DebugMode signals.
## [param board] — the game-board Node2D (parent for the deploy overlay).
## [param get_ships] — callable returning Array[ShipToken].
## [param get_squads] — callable returning Array[SquadronToken].
func initialize(board: Node2D, get_ships: Callable, get_squads: Callable) -> void:
	_board = board
	_get_ship_tokens = get_ships
	_get_squadron_tokens = get_squads

	_create_deploy_overlay()
	_create_debug_hud()
	_connect_signals()
	_update_debug_visibility()


## Handles left-click in debug mode: clicks on empty space deselect.
## DBG-010 — left-click empty space deselects.
func handle_debug_click(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# If we have a selection and clicked empty space, deselect.
	# Token clicks are handled by token _input → token_clicked signal first.
	# If input reaches here, no token was hit.
	if DebugMode.has_selection():
		DebugMode.deselect_token()
		get_viewport().set_input_as_handled()


## Checks if a dragged token just crossed outside its deployment zone and
## shows a one-shot toast warning.  Resets when the token re-enters.
## DBG-033 — advisory toast on zone crossing in debug mode.
func check_zone_crossing_toast(
		token: Node2D, _top_y: float, _bottom_y: float
) -> void:
	var faction: Constants.Faction = Constants.Faction.GALACTIC_EMPIRE
	var token_name: String = token.name
	if token is ShipToken:
		faction = (token as ShipToken).get_faction()
		var data: ShipData = (token as ShipToken).get_ship_data()
		if data != null:
			token_name = data.ship_name
	elif token is SquadronToken:
		faction = (token as SquadronToken).get_faction()
		token_name = token.name
	var in_zone: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			token.position.y, faction)
	if _was_in_deploy_zone and not in_zone:
		TooltipManager.show_text(
				"%s is outside deployment zone" % token_name,
				Vector2.INF, 3.0)
	_was_in_deploy_zone = in_zone


## Resets zone-crossing tracking so the next move starts fresh.
## Called when a new token is selected.
func reset_zone_tracking() -> void:
	_was_in_deploy_zone = true


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Creates the deployment zone overlay (initially hidden).
func _create_deploy_overlay() -> void:
	_deploy_overlay = DeploymentZoneOverlay.new()
	_deploy_overlay.name = "DeploymentZoneOverlay"
	_deploy_overlay.visible = false
	_board.add_child(_deploy_overlay)


## Creates the debug-mode HUD on a CanvasLayer (label + help panel).
func _create_debug_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DebugHUDLayer"
	layer.layer = 100
	_board.add_child(layer)

	_debug_label = Label.new()
	_debug_label.text = "DEBUG"
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.position = Vector2(10, 10)
	_debug_label.visible = false
	layer.add_child(_debug_label)

	_debug_help_panel = DebugHelpPanel.new()
	_debug_help_panel.name = "DebugHelpPanel"
	_debug_help_panel.position = Vector2(10, 44)
	_debug_help_panel.visible = false
	layer.add_child(_debug_help_panel)


## Connects DebugMode signals.
func _connect_signals() -> void:
	DebugMode.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugMode.save_positions_requested.connect(_on_save_positions)


## Updates visibility of debug-only UI elements.
func _on_debug_mode_changed(_enabled: bool) -> void:
	_update_debug_visibility()


## Toggles debug-specific overlays.
func _update_debug_visibility() -> void:
	var on: bool = DebugMode.enabled
	if _deploy_overlay:
		_deploy_overlay.visible = on
	if _debug_label:
		_debug_label.visible = on
	if _debug_help_panel:
		_debug_help_panel.visible = on


## Saves all token positions to the learning scenario JSON.
## DBG-040, DBG-041
func _on_save_positions() -> void:
	var success: bool = _scenario_saver.save_positions(
			"scenarios/", "learning_scenario.json",
			_get_ship_tokens.call(), _get_squadron_tokens.call(),
			GameScale.play_area_side_px)
	if success:
		_log.info("Token positions saved successfully.")
	else:
		_log.error("Failed to save token positions.")

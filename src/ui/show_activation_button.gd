## ShowActivationButton
##
## Button displayed at bottom-centre after a command dial is revealed and
## assigned. Pressing it opens the Activation Modal.
## Does NOT auto-dismiss — stays visible until pressed.
##
## Requirements: ACT-007, FLOW-002, AC-5b-01.
class_name ShowActivationButton
extends Button


## Emitted when the player presses the button.
signal activation_sequence_requested()

## Logger.
var _log: GameLogger = GameLogger.new("ShowActBtn")


func _init() -> void:
	text = "Show Activation Sequence"
	custom_minimum_size = Vector2(240, 44)
	visible = false
	pressed.connect(_on_pressed)


## Shows the button for the active player.
func show_button() -> void:
	visible = true
	disabled = false


## Hides the button.
func hide_button() -> void:
	visible = false


## Positions the button at the bottom-centre of the viewport.
## [param viewport_size] — the current viewport dimensions.
func update_position(viewport_size: Vector2) -> void:
	position = Vector2(
			(viewport_size.x - size.x) * 0.5,
			viewport_size.y - size.y - 24)


func _on_pressed() -> void:
	_log.info("Show Activation Sequence pressed.")
	hide_button()
	activation_sequence_requested.emit()

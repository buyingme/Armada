## ShowSquadronModalButton
##
## Button displayed at bottom-centre when the Squadron Activation Modal
## has been dismissed.  Pressing it re-opens the modal.
## Analogous to [ShowActivationButton] for the Ship Phase.
##
## Requirements: SQA-011, SQA-013.
class_name ShowSquadronModalButton
extends Button


## Emitted when the player presses the button.
signal squadron_modal_requested()

## Logger.
var _log: GameLogger = GameLogger.new("ShowSqBtn")


func _init() -> void:
	text = "Show Squadron Modal"
	custom_minimum_size = Vector2(240, 44)
	visible = false
	pressed.connect(_on_pressed)


## Shows the button.
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
	_log.info("Show Squadron Modal pressed.")
	SfxManager.play_sfx("droid_sound")
	hide_button()
	squadron_modal_requested.emit()

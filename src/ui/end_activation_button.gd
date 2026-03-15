## EndActivationButton
##
## Button displayed during Ship and Squadron Phases that the active player
## presses to signal they have finished their current activation.
## Emits [signal EventBus.activation_ended] when pressed.
##
## Requirements: TF-005, TF-011.
class_name EndActivationButton
extends Button


## Logger.
var _log: GameLogger = GameLogger.new("EndActivation")


func _init() -> void:
	text = "End Activation"
	custom_minimum_size = Vector2(180, 44)
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
	_log.info("End Activation pressed.")
	EventBus.activation_ended.emit()

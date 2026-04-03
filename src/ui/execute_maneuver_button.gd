## ExecuteManeuverButton
##
## Button displayed at bottom-centre during the Execute Maneuver step.
## Pressing it commits the ship's movement.
##
## Requirements: EXE-001, AC-5b-08.
class_name ExecuteManeuverButton
extends Button


## Logger.
var _log: GameLogger = GameLogger.new("ExecMnvBtn")


func _init() -> void:
	text = "Execute Maneuver"
	custom_minimum_size = Vector2(200, 44)
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
	_log.info("Execute Maneuver pressed.")
	SfxManager.play_sfx("star_destroyer_flyby")
	hide_button()
	EventBus.execute_maneuver_requested.emit()

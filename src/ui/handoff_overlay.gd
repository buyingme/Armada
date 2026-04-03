## HandoffOverlay
##
## Full-screen overlay displayed during hot-seat player transitions.
## Covers the entire screen to prevent the incoming player from seeing
## the previous player's secret information (e.g. command dials).
##
## Shows which player should take control, the current phase name,
## and a "Ready" button that must be clicked to proceed.
##
## Requirements: HO-001, HO-002, HO-003.
class_name HandoffOverlay
extends ColorRect


## Player names for display. Index matches player index (0 = Rebel, 1 = Imperial).
const PLAYER_NAMES: Array[String] = ["Rebel Player", "Imperial Player"]

## Background colour (opaque dark overlay).
const OVERLAY_COLOR: Color = Color(0.05, 0.05, 0.15, 0.95)

## The title label showing "[Player] — Your Turn".
var _title_label: Label = null

## The phase label showing the current phase name.
var _phase_label: Label = null

## The "Ready" button.
var _ready_button: Button = null

## Logger.
var _log: GameLogger = GameLogger.new("HandoffOverlay")


func _init() -> void:
	color = OVERLAY_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_build_ui()


## Shows the overlay for the given player and phase.
## [param player_index] — the player who should take control.
## [param phase_name] — human-readable name of the current phase.
func show_handoff(player_index: int, phase_name: String) -> void:
	var player_name: String = ""
	if player_index >= 0 and player_index < PLAYER_NAMES.size():
		player_name = PLAYER_NAMES[player_index]
	else:
		player_name = "Player %d" % player_index
	_title_label.text = "%s — Your Turn" % player_name
	_phase_label.text = phase_name
	visible = true
	_log.info("Handoff overlay shown for player %d (%s)." % [
			player_index, phase_name])


## Hides the overlay.
func dismiss() -> void:
	visible = false


## Positions the overlay to cover the full viewport.
## [param viewport_size] — the current viewport dimensions.
func update_size(viewport_size: Vector2) -> void:
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size
	_centre_content(viewport_size)


## Builds the UI elements (labels + button).
func _build_ui() -> void:
	# Container centred in the overlay.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	vbox.name = "ContentVBox"
	add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_title_label.name = "TitleLabel"
	vbox.add_child(_title_label)

	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 22)
	_phase_label.add_theme_color_override("font_color",
			Color(0.7, 0.7, 0.8))
	_phase_label.name = "PhaseLabel"
	vbox.add_child(_phase_label)

	_ready_button = Button.new()
	_ready_button.text = "Ready"
	_ready_button.custom_minimum_size = Vector2(180, 50)
	_ready_button.name = "ReadyButton"
	_ready_button.pressed.connect(_on_ready_pressed)
	# Centre the button.
	var btn_container: CenterContainer = CenterContainer.new()
	btn_container.add_child(_ready_button)
	vbox.add_child(btn_container)


## Centres the content VBox within the overlay.
func _centre_content(viewport_size: Vector2) -> void:
	var vbox: VBoxContainer = get_node_or_null("ContentVBox")
	if vbox == null:
		return
	var vbox_size: Vector2 = Vector2(400, 200)
	vbox.position = (viewport_size - vbox_size) * 0.5
	vbox.size = vbox_size


## Called when the "Ready" button is pressed.
func _on_ready_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	dismiss()
	EventBus.handoff_accepted.emit()

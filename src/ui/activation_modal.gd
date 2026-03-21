## ActivationModal
##
## Persistent panel that guides the player through the five sub-steps
## of a ship's activation: Reveal → Squadron → Repair → Attack → Maneuver.
## Steps 2–4 show "Not yet implemented" badges in Phase 5b.
##
## The modal opens when the player presses the "Show Activation Sequence"
## button (ACT-007). It closes when "End Activation" is pressed after the
## Execute Maneuver step completes.
##
## Rules Reference: RRG "Ship Activation" p.16, "Commands" p.3.
## Requirements: ACT-001–004, ACT-007, AC-5b-01–02, AC-5b-14.
class_name ActivationModal
extends PanelContainer


## Emitted when the player requests to execute the maneuver step.
signal maneuver_step_entered()

## Emitted when the modal wants to auto-skip to maneuver (all placeholders done).
signal ready_for_maneuver()

## Width of the modal panel.
const MODAL_WIDTH: float = 280.0

## Step names for display.
const STEP_NAMES: Array[String] = [
	"1. Reveal Command Dial",
	"2. Squadron Command",
	"3. Repair Command",
	"4. Attack",
	"5. Execute Maneuver",
]

## Which steps are placeholders (not yet implemented) in Phase 5b.
const PLACEHOLDER_STEPS: Array[int] = [1, 2, 3]  ## indices into STEP_NAMES

## Logger.
var _log: GameLogger = GameLogger.new("ActivationModal")

## The activation state being tracked.
var _activation_state: ShipActivationState = null

## Container for step rows.
var _step_container: VBoxContainer = null

## Array of step row Controls.
var _step_rows: Array[PanelContainer] = []

## Title label.
var _title_label: Label = null

## The revealed command label.
var _command_label: Label = null

## Token info label.
var _token_label: Label = null

## Whether auto-skip is currently running.
var _auto_skipping: bool = false


func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(MODAL_WIDTH, 0)


## Opens the modal for the given activation state.
## [param state] — the ShipActivationState tracking this activation.
func open(state: ShipActivationState) -> void:
	_activation_state = state
	_build_ui()
	_update_step_display()
	visible = true
	_log.info("Activation modal opened.")
	# Auto-advance past Reveal (already done by Phase 4c).
	if state.get_current_step() == ShipActivationState.Step.REVEAL:
		state.advance_step()
		_start_auto_skip()


## Closes and clears the modal.
func close() -> void:
	visible = false
	_activation_state = null
	_clear_ui()
	_log.info("Activation modal closed.")


## Returns true if the modal is currently open.
func is_open() -> bool:
	return visible and _activation_state != null


## Updates the visual display to match current step.
func refresh() -> void:
	_update_step_display()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------


## Builds the full modal UI from scratch.
func _build_ui() -> void:
	_clear_ui()

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title.
	_title_label = Label.new()
	_title_label.text = "Ship Activation"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings: LabelSettings = LabelSettings.new()
	title_settings.font_size = 16
	_title_label.label_settings = title_settings
	vbox.add_child(_title_label)

	# Command info.
	_command_label = Label.new()
	_command_label.text = ""
	_command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_command_label)

	# Token info.
	_token_label = Label.new()
	_token_label.text = ""
	_token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var token_settings: LabelSettings = LabelSettings.new()
	token_settings.font_size = 12
	_token_label.label_settings = token_settings
	vbox.add_child(_token_label)

	# Separator.
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Step rows.
	_step_container = VBoxContainer.new()
	_step_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_step_container)

	_step_rows.clear()
	for i: int in range(STEP_NAMES.size()):
		var row: PanelContainer = _create_step_row(i)
		_step_container.add_child(row)
		_step_rows.append(row)

	_update_command_info()


## Creates a single step row.
func _create_step_row(step_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var lbl: Label = Label.new()
	lbl.text = STEP_NAMES[step_index]
	lbl.name = "StepLabel"
	hbox.add_child(lbl)

	# Spacer.
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Status label (shows badge or checkmark).
	var status: Label = Label.new()
	status.name = "StatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(status)

	return panel


## Clears all children from the modal.
func _clear_ui() -> void:
	for child: Node in get_children():
		child.queue_free()
	_step_rows.clear()
	_step_container = null
	_title_label = null
	_command_label = null
	_token_label = null


# ---------------------------------------------------------------------------
# Step display updates
# ---------------------------------------------------------------------------


## Updates visual state of all step rows based on current activation step.
func _update_step_display() -> void:
	if _activation_state == null:
		return
	var current: int = int(_activation_state.get_current_step())
	# Steps map: REVEAL=0, SQUADRON=1, REPAIR=2, ATTACK=3, MANEUVER=4, DONE=5
	for i: int in range(_step_rows.size()):
		var row: PanelContainer = _step_rows[i]
		var status_label: Label = row.get_node("HBoxContainer/StatusLabel") \
				if row.get_child_count() > 0 else null
		if status_label == null:
			# Find it by name traversal.
			status_label = _find_status_label(row)
		if status_label == null:
			continue
		var step_val: int = i  # 0=REVEAL, 1=SQUADRON, ...
		if step_val < current:
			# Past step — completed.
			status_label.text = "✓"
			status_label.modulate = Color(0.4, 0.9, 0.4)
			row.modulate = Color(0.6, 0.6, 0.6)
		elif step_val == current:
			# Current step — active.
			status_label.text = "►"
			status_label.modulate = Color.WHITE
			row.modulate = Color.WHITE
			if i in PLACEHOLDER_STEPS:
				status_label.text = "Not yet implemented"
				status_label.modulate = Color(0.9, 0.7, 0.3)
		else:
			# Future step — dimmed.
			status_label.text = ""
			row.modulate = Color(0.5, 0.5, 0.5)


## Finds the StatusLabel in a step row by name.
func _find_status_label(row: PanelContainer) -> Label:
	for child: Node in row.get_children():
		if child is HBoxContainer:
			for sub: Node in child.get_children():
				if sub.name == "StatusLabel" and sub is Label:
					return sub as Label
	return null


## Updates the command and token info labels.
func _update_command_info() -> void:
	if _activation_state == null or _activation_state.get_ship() == null:
		return
	var ship: ShipInstance = _activation_state.get_ship()

	# Revealed dial command.
	var revealed: Dictionary = {}
	if ship.command_dial_stack:
		revealed = ship.command_dial_stack.get_revealed_dial()
	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		var cmd_name: String = Constants.CommandType.keys()[cmd]
		_command_label.text = "Dial: %s" % cmd_name
	else:
		_command_label.text = "Dial: (spent)"

	# Command tokens.
	if ship.command_tokens:
		var tokens: Array[int] = ship.command_tokens.get_tokens()
		if tokens.is_empty():
			_token_label.text = "Tokens: none"
		else:
			var names: Array[String] = []
			for t: int in tokens:
				names.append(Constants.CommandType.keys()[t])
			_token_label.text = "Tokens: %s" % ", ".join(names)
	else:
		_token_label.text = "Tokens: none"


# ---------------------------------------------------------------------------
# Auto-skip placeholder steps
# ---------------------------------------------------------------------------


## Starts auto-skipping placeholder steps (Squadron, Repair, Attack).
## Uses a short timer between each skip so the player can see the progression.
func _start_auto_skip() -> void:
	_auto_skipping = true
	_try_auto_skip_next()


## Attempts to auto-skip the current step if it's a placeholder.
## Uses call_deferred to avoid processing in the same frame.
func _try_auto_skip_next() -> void:
	if not _auto_skipping or _activation_state == null:
		return
	var current: int = int(_activation_state.get_current_step())
	# Steps 1,2,3 (SQUADRON, REPAIR, ATTACK) are placeholders.
	if current in [ShipActivationState.Step.SQUADRON,
			ShipActivationState.Step.REPAIR,
			ShipActivationState.Step.ATTACK]:
		_update_step_display()
		# Use a short delay via a timer (0.3s) for visual feedback.
		var timer: SceneTreeTimer = get_tree().create_timer(0.3)
		timer.timeout.connect(_auto_skip_current)
	else:
		_auto_skipping = false
		_update_step_display()
		if current == ShipActivationState.Step.MANEUVER:
			_log.info("Auto-skip complete — entering maneuver step.")
			maneuver_step_entered.emit()


## Auto-skips the current placeholder step.
func _auto_skip_current() -> void:
	if _activation_state == null:
		return
	_activation_state.skip_step()
	_try_auto_skip_next()


# ---------------------------------------------------------------------------
# Positioning
# ---------------------------------------------------------------------------


## Positions the modal on the right side of the viewport.
## [param viewport_size] — the current viewport dimensions.
func update_position(viewport_size: Vector2) -> void:
	var margin: float = 16.0
	position = Vector2(
			viewport_size.x - MODAL_WIDTH - margin,
			margin)

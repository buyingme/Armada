## ActivationModal
##
## Centred panel that guides the player through the five sub-steps
## of a ship's activation: Reveal → Squadron → Repair → Attack → Maneuver.
## Steps 2–3 show "Not yet implemented" badges (placeholder).
## Step 4 (Attack) shows an actionable "Execute Attack" button.
## Step 5 (Execute Maneuver) shows an actionable "Execute" button.
##
## Styled identically to CommandDialPicker / CommandDialOrderModal
## (see .skills/ui_styling.md).
##
## Dismissable via Escape key or the "✕ Close" button. Closing the modal
## does NOT cancel the activation — it merely hides the panel. The player
## can re-open it via "Show Activation Sequence".
##
## Rules Reference: RRG "Ship Activation" p.16, "Commands" p.3.
## Requirements: ACT-001–004, ACT-007, AC-5b-01–02, AC-5b-14, AE-ACT-001.
class_name ActivationModal
extends PanelContainer


## Emitted when the player clicks "Execute ►" — shows the maneuver tool.
signal maneuver_step_entered()

## Emitted when the player clicks "Commit ►" — snaps ship to final position.
signal maneuver_commit_requested()

## Emitted when the player clicks "Execute Attack ►" — starts attack flow.
## Requirements: AE-ACT-001.
signal attack_step_entered()

## Emitted when the player clicks "Execute Repair ►" — starts repair flow.
signal repair_step_entered()

## Emitted when the player clicks "Execute Squadron ►" — starts squadron command.
## Requirements: CM-020.
signal squadron_step_entered()

## Emitted when the player chooses to skip the squadron step (token only).
## Rules Reference: "Commands" p.4 — spending a command token is optional.
signal squadron_step_skipped()

## Emitted when the modal wants to auto-skip to maneuver (all placeholders done).
signal ready_for_maneuver()

## Emitted when the player presses the close / dismiss button.
signal modal_closed()

## Panel width cap — matches AttackSimPanel proportions.
const MODAL_MAX_WIDTH: float = 360.0
## Panel width fraction of viewport width.
const MODAL_WIDTH_FRACTION: float = 0.35

## Step names for display.
const STEP_NAMES: Array[String] = [
	"1. Reveal Command Dial",
	"2. Squadron Command",
	"3. Repair Command",
	"4. Attack",
	"5. Execute Maneuver",
]

## Which steps are placeholders (not yet implemented).
const PLACEHOLDER_STEPS: Array[int] = [] ## Formerly [1]; squadron step is now actionable

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

## "Execute" button inside the maneuver step row.
var _execute_button: Button = null

## "Execute Attack" button inside the attack step row.
## Requirements: AE-ACT-001.
var _attack_button: Button = null

## "Execute Repair" button inside the repair step row.
var _repair_button: Button = null

## "Execute Squadron" button inside the squadron step row.
## Requirements: CM-020.
var _squadron_button: Button = null

## "Skip" button inside the squadron step (shown when token-only).
var _squadron_skip_button: Button = null

## Whether auto-skip is currently running.
var _auto_skipping: bool = false

## When true the Attack step is auto-skipped (no valid targets).
## Set by the game board via [method set_attack_skippable] before opening.
var _skip_attack: bool = false

## When true the Repair step is auto-skipped (no dial or token).
## Set by the game board via [method set_repair_skippable] before opening.
var _skip_repair: bool = false

## When true the Squadron step is auto-skipped (no squadron dial or token).
## Set by the game board via [method set_squadron_skippable] before opening.
var _skip_squadron: bool = false

## When true the ship has a Squadron token but no matching dial.
## The player may choose to skip (not spend the token).
## Rules Reference: "Commands" p.4 — command tokens are optional.
var _squadron_token_only: bool = false

## True once the maneuver tool has been shown (Execute pressed once).
## Second press commits the maneuver.
var _maneuver_tool_shown: bool = false


func _init() -> void:
	visible = false
	_apply_anchor_position()


## Marks the Attack step as skippable (no valid targets).
## Call this before [method open] so the auto-skip chain includes Attack.
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
func set_attack_skippable(skip: bool) -> void:
	_skip_attack = skip


## Marks the Repair step as skippable (no repair dial or token).
## Call this before [method open] so the auto-skip chain includes Repair.
## Rules Reference: "Engineering", p.4 — only available with dial or token.
func set_repair_skippable(skip: bool) -> void:
	_skip_repair = skip


## Marks the Squadron step as skippable (no squadron dial or token).
## Call this before [method open] so the auto-skip chain includes Squadron.
## Rules Reference: "Commands", p.4 — squadron command needs dial or token.
func set_squadron_skippable(skip: bool) -> void:
	_skip_squadron = skip


## Marks whether the ship only has a Squadron token (no dial).
## When true a "Skip" button is shown alongside "Execute Squadron".
## Rules Reference: "Commands" p.4 — spending a command token is optional.
func set_squadron_token_only(token_only: bool) -> void:
	_squadron_token_only = token_only


## Opens the modal for the given activation state.
## [param state] — the ShipActivationState tracking this activation.
func open(state: ShipActivationState) -> void:
	_activation_state = state
	_build_ui()
	_update_step_display()
	visible = true
	# Grab focus so Escape key works immediately.
	set_process_unhandled_input(true)
	_log.info("Activation modal opened.")
	# Auto-advance past Reveal (already done by Phase 4c).
	if state.get_current_step() == ShipActivationState.Step.REVEAL:
		state.advance_step()
		_start_auto_skip()
	# Re-opened at Squadron with no dial/token — auto-skip the step.
	elif (_skip_squadron
			and state.get_current_step() == ShipActivationState.Step.SQUADRON):
		_start_auto_skip()
	# Re-opened at Repair with no dial/token — auto-skip the step.
	elif (_skip_repair
			and state.get_current_step() == ShipActivationState.Step.REPAIR):
		_start_auto_skip()
	# Re-opened at Attack with no targets — auto-skip the step.
	elif (_skip_attack
			and state.get_current_step() == ShipActivationState.Step.ATTACK):
		_start_auto_skip()


## Closes and hides the modal. Does NOT cancel the activation.
func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	_log.info("Activation modal closed.")


## Hard-close: clears the activation state too (used when activation ends).
func close_and_clear() -> void:
	visible = false
	_activation_state = null
	_maneuver_tool_shown = false
	_clear_ui()
	set_process_unhandled_input(false)
	_log.info("Activation modal closed and cleared.")


## Returns true if the modal is currently open.
func is_open() -> bool:
	return visible and _activation_state != null


## Updates the visual display to match current step.
func refresh() -> void:
	_update_step_display()


## Escape key dismisses the modal.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
			modal_closed.emit()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------


## Sets bottom-centre anchoring once — must not be called from _build_ui
## to avoid Godot offset recalculation on repeated anchor writes.
func _apply_anchor_position() -> void:
	var vp: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp = get_viewport().get_visible_rect().size
	var panel_w: float = minf(MODAL_MAX_WIDTH, vp.x * MODAL_WIDTH_FRACTION)
	custom_minimum_size = Vector2(panel_w, 0.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	offset_top = -40.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## Builds the full modal UI from scratch.
## Positioned at bottom-centre, matching AttackSimPanel layout.
## (see .skills/ui_styling.md §1, §3, §4).
func _build_ui() -> void:
	_clear_ui()
	# First zero the cached size (prevents the PanelContainer from
	# retaining its old expanded height from a previous activation).
	# This shifts offsets as a side-effect, so we immediately re-pin
	# them to the canonical -40 values afterwards.
	size = Vector2.ZERO
	offset_top = -40.0
	offset_bottom = -40.0

	# Panel style — identical to AttackSimPanel / CommandDialPicker.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	# Explicit min-width prevents autowrap labels from reporting a huge
	# minimum height before the PanelContainer propagates its width.
	var _margin_h: float = 32.0 # 16 px content-margin on each side
	vbox.custom_minimum_size.x = maxf(
			custom_minimum_size.x - _margin_h, 100.0)
	add_child(vbox)

	# Title — ship name.
	_title_label = Label.new()
	var ship_name: String = ""
	if _activation_state and _activation_state.get_ship() and \
			_activation_state.get_ship().ship_data:
		ship_name = _activation_state.get_ship().ship_data.ship_name
	_title_label.text = "Ship Activation — %s" % ship_name
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
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
	_token_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_token_label)

	# Separator.
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Step rows.
	_step_container = VBoxContainer.new()
	_step_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_step_container)

	_step_rows.clear()
	_execute_button = null
	for i: int in range(STEP_NAMES.size()):
		var row: PanelContainer = _create_step_row(i)
		_step_container.add_child(row)
		_step_rows.append(row)

	# Separator before close hint.
	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	# Close button row.
	var close_container: HBoxContainer = HBoxContainer.new()
	close_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var close_btn: Button = Button.new()
	close_btn.text = "✕ Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(_on_close_pressed)
	close_container.add_child(close_btn)
	vbox.add_child(close_container)

	# Dismiss hint.
	var hint: Label = Label.new()
	hint.text = "Press Escape to dismiss"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)

	_update_command_info()


## Creates a single step row.
## Step 5 (index 4, Execute Maneuver) gets an embedded action button.
func _create_step_row(step_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	# Apply row style.
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
	row_style.border_color = Color(0.2, 0.25, 0.35, 0.4)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", row_style)

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

	# For step 5 (Execute Maneuver): add an actionable button.
	if step_index == 4:
		_execute_button = Button.new()
		_execute_button.text = "Execute Maneuver ►"
		_execute_button.custom_minimum_size = Vector2(130, 28)
		_execute_button.visible = false
		_execute_button.pressed.connect(_on_execute_pressed)
		hbox.add_child(_execute_button)

	# For step 4 (Attack): add "Execute Attack" button.
	if step_index == 3:
		_attack_button = Button.new()
		_attack_button.text = "Execute Attack ►"
		_attack_button.custom_minimum_size = Vector2(130, 28)
		_attack_button.visible = false
		_attack_button.pressed.connect(_on_attack_pressed)
		hbox.add_child(_attack_button)

	# For step 3 (Repair): add "Execute Repair" button.
	if step_index == 2:
		_repair_button = Button.new()
		_repair_button.text = "Execute Repair ►"
		_repair_button.custom_minimum_size = Vector2(130, 28)
		_repair_button.visible = false
		_repair_button.pressed.connect(_on_repair_pressed)
		hbox.add_child(_repair_button)

	# For step 2 (Squadron): add "Execute Squadron" button and optional skip.
	if step_index == 1:
		_squadron_button = Button.new()
		_squadron_button.text = "Execute Squadron ►"
		_squadron_button.custom_minimum_size = Vector2(140, 28)
		_squadron_button.visible = false
		_squadron_button.pressed.connect(_on_squadron_pressed)
		hbox.add_child(_squadron_button)
		_squadron_skip_button = Button.new()
		_squadron_skip_button.text = "Skip"
		_squadron_skip_button.custom_minimum_size = Vector2(60, 28)
		_squadron_skip_button.visible = false
		_squadron_skip_button.pressed.connect(_on_squadron_skip_pressed)
		hbox.add_child(_squadron_skip_button)

	# Status label (shows badge or checkmark).
	var status: Label = Label.new()
	status.name = "StatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(status)

	return panel


## Clears all children from the modal.
## Uses remove_child() before queue_free() so old children are excluded
## from PanelContainer's minimum-size computation immediately.
func _clear_ui() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_step_rows.clear()
	_step_container = null
	_title_label = null
	_command_label = null
	_token_label = null
	_execute_button = null
	_attack_button = null
	_repair_button = null
	_squadron_button = null
	_squadron_skip_button = null


# ---------------------------------------------------------------------------
# Step display updates
# ---------------------------------------------------------------------------


## Updates visual state of all step rows based on current activation step.
## Applies row StyleBoxFlat colours per state (see .skills/ui_styling.md §2).
func _update_step_display() -> void:
	if _activation_state == null:
		return
	var current: int = int(_activation_state.get_current_step())
	# Steps map: REVEAL=0, SQUADRON=1, REPAIR=2, ATTACK=3, MANEUVER=4, DONE=5
	for i: int in range(_step_rows.size()):
		var row: PanelContainer = _step_rows[i]
		var status_label: Label = _find_status_label(row)
		if status_label == null:
			continue

		var row_style: StyleBoxFlat = StyleBoxFlat.new()
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(4)

		var step_val: int = i # 0=REVEAL, 1=SQUADRON, ...
		if step_val < current:
			# Past step — completed.
			row_style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
			row_style.border_color = Color(0.3, 0.35, 0.45, 0.6)
			row.add_theme_stylebox_override("panel", row_style)
			status_label.text = "✓"
			status_label.modulate = Color(0.4, 0.9, 0.4)
			row.modulate = Color.WHITE
		elif step_val == current:
			# Current step — active.
			row_style.bg_color = Color(0.18, 0.22, 0.32, 1.0)
			row_style.border_color = Color(0.5, 0.6, 0.8, 1.0)
			row.add_theme_stylebox_override("panel", row_style)
			row.modulate = Color.WHITE
			if i in PLACEHOLDER_STEPS:
				status_label.text = "Not yet implemented"
				status_label.modulate = Color(0.9, 0.7, 0.3)
			elif i == 1:
				# Squadron step — show button or "No squadron available" badge.
				if _skip_squadron:
					status_label.text = "No squadron available"
					status_label.modulate = Color(0.9, 0.7, 0.3)
				else:
					status_label.text = ""
					if _squadron_button:
						_squadron_button.visible = true
						_squadron_button.disabled = false
					if _squadron_skip_button:
						_squadron_skip_button.visible = _squadron_token_only
						_squadron_skip_button.disabled = false
			elif i == 2:
				# Repair step — show button or "No dial/token" badge.
				if _skip_repair:
					status_label.text = "No repair available"
					status_label.modulate = Color(0.9, 0.7, 0.3)
				else:
					status_label.text = ""
					if _repair_button:
						_repair_button.visible = true
						_repair_button.disabled = false
			elif i == 3:
				# Attack step — show button or "No targets" badge.
				if _skip_attack:
					status_label.text = "No targets"
					status_label.modulate = Color(0.9, 0.7, 0.3)
				else:
					status_label.text = ""
					if _attack_button:
						_attack_button.visible = true
						_attack_button.disabled = false
			elif i == 4:
				# Execute Maneuver step — show the action button.
				status_label.text = ""
				if _execute_button:
					_execute_button.visible = true
					_execute_button.disabled = false
					if _maneuver_tool_shown:
						_execute_button.text = "Commit Maneuver ►"
					else:
						_execute_button.text = "Execute Maneuver ►"
			else:
				status_label.text = "►"
				status_label.modulate = Color.WHITE
		else:
			# Future step — dimmed.
			row_style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
			row_style.border_color = Color(0.2, 0.25, 0.35, 0.4)
			row.add_theme_stylebox_override("panel", row_style)
			status_label.text = ""
			row.modulate = Color(0.5, 0.5, 0.5)
			if i == 4 and _execute_button:
				_execute_button.visible = false
			if i == 3 and _attack_button:
				_attack_button.visible = false
			if i == 2 and _repair_button:
				_repair_button.visible = false
			if i == 1 and _squadron_button:
				_squadron_button.visible = false
		if i == 1 and _squadron_skip_button:
				_squadron_skip_button.visible = false


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
# Button callbacks
# ---------------------------------------------------------------------------


## Called when the Execute / Commit button on step 5 is pressed.
## First click: emits [signal maneuver_step_entered] to show the tool.
## Second click: emits [signal maneuver_commit_requested] to snap the ship.
func _on_execute_pressed() -> void:
	if not _maneuver_tool_shown:
		# Phase 1 — show the maneuver tool and close the modal.
		_log.info("Execute maneuver pressed — showing tool.")
		_maneuver_tool_shown = true
		if _execute_button:
			_execute_button.text = "Commit Maneuver ►"
		maneuver_step_entered.emit()
		# Close so the player can see the maneuver tool underneath.
		close()
		modal_closed.emit()
	else:
		# Phase 2 — commit the maneuver (snap ship).
		_log.info("Commit maneuver pressed — snapping ship.")
		if _execute_button:
			_execute_button.disabled = true
		maneuver_commit_requested.emit()
		close()
		modal_closed.emit()


## Called when the "Execute Attack ►" button is pressed.
## Emits [signal attack_step_entered] and closes the modal so the player
## can interact with the board.
## Requirements: AE-ACT-001.
func _on_attack_pressed() -> void:
	_log.info("Execute Attack pressed — starting attack flow.")
	attack_step_entered.emit()
	close()
	modal_closed.emit()


## Called when the "Execute Squadron ►" button is pressed.
## Emits [signal squadron_step_entered] and closes the modal.
func _on_squadron_pressed() -> void:
	_log.info("Execute Squadron pressed — starting squadron command flow.")
	squadron_step_entered.emit()
	close()
	modal_closed.emit()


## Called when the "Skip" button next to Squadron is pressed.
## Emits [signal squadron_step_skipped] to advance without spending.
## Rules Reference: "Commands" p.4 — command tokens are optional.
func _on_squadron_skip_pressed() -> void:
	_log.info("Squadron step skipped by player (token only).")
	squadron_step_skipped.emit()
	close()
	modal_closed.emit()


## Called when the "Execute Repair ►" button is pressed.
## Emits [signal repair_step_entered] and closes the modal.
func _on_repair_pressed() -> void:
	_log.info("Execute Repair pressed — starting repair flow.")
	repair_step_entered.emit()
	close()
	modal_closed.emit()


## Called when the "✕ Close" button is pressed.
func _on_close_pressed() -> void:
	close()
	modal_closed.emit()


# ---------------------------------------------------------------------------
# Auto-skip placeholder steps
# ---------------------------------------------------------------------------


## Starts auto-skipping placeholder steps (Squadron, Repair, Attack).
## Uses a short timer between each skip so the player can see the progression.
func _start_auto_skip() -> void:
	_auto_skipping = true
	_try_auto_skip_next()


## Attempts to auto-skip the current step if it's a placeholder or
## a skippable step (no resources or no targets).
## Uses call_deferred to avoid processing in the same frame.
func _try_auto_skip_next() -> void:
	if not _auto_skipping or _activation_state == null:
		return
	var current: int = int(_activation_state.get_current_step())
	# Step 1 (SQUADRON) is skipped when _skip_squadron is true.
	# Step 2 (REPAIR) is skipped when _skip_repair is true.
	# Step 3 (ATTACK) is skipped when _skip_attack is true.
	if _skip_squadron and current == ShipActivationState.Step.SQUADRON:
		_update_step_display()
		var timer: SceneTreeTimer = get_tree().create_timer(0.3)
		timer.timeout.connect(_auto_skip_current)
	elif _skip_repair and current == ShipActivationState.Step.REPAIR:
		_update_step_display()
		var timer: SceneTreeTimer = get_tree().create_timer(0.3)
		timer.timeout.connect(_auto_skip_current)
	elif _skip_attack and current == ShipActivationState.Step.ATTACK:
		_update_step_display()
		var timer: SceneTreeTimer = get_tree().create_timer(0.3)
		timer.timeout.connect(_auto_skip_current)
	else:
		_auto_skipping = false
		_update_step_display()
		if current == ShipActivationState.Step.SQUADRON:
			_log.info("Auto-skip complete — squadron step active. " +
					"Player must press Execute Squadron.")
		elif current == ShipActivationState.Step.ATTACK:
			_log.info("Auto-skip complete — attack step active. " +
					"Player must press Execute Attack.")
		elif current == ShipActivationState.Step.MANEUVER:
			_log.info("Auto-skip complete — maneuver step active. " +
					"Player must press Execute.")


## Auto-skips the current placeholder step.
func _auto_skip_current() -> void:
	if _activation_state == null:
		return
	_activation_state.skip_step()
	_try_auto_skip_next()


# ---------------------------------------------------------------------------
# Positioning
# ---------------------------------------------------------------------------


## Updates the bottom-centre anchored position for the given viewport size.
## Matches AttackSimPanel positioning.
func centre_on_screen(viewport_size: Vector2) -> void:
	var panel_w: float = minf(MODAL_MAX_WIDTH,
			viewport_size.x * MODAL_WIDTH_FRACTION)
	custom_minimum_size = Vector2(panel_w, 0.0)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5

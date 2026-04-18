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

## Emitted when the player presses "End Activation ►" after all steps complete.
## The game board uses this to emit EventBus.activation_ended.
signal end_activation_requested()

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

## "End Activation ►" button shown when all steps are complete (DONE).
var _end_activation_button: Button = null

## Label showing collision/overlap info (between step rows and End button).
var _collision_label: Label = null

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
	_log_offsets("_init")


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
	_log_offsets("open:before_build")
	_build_ui()
	_log_offsets("open:after_build")
	_update_step_display()
	_log_offsets("open:after_step_display")
	visible = true
	_request_deferred_layout()
	_log_offsets("open:after_visible+deferred_queued")
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
## Schedules a deferred layout reset because toggling button visibility
## inside [method _update_step_display] changes the panel's minimum size.
func refresh() -> void:
	_update_step_display()
	if visible:
		_request_deferred_layout()
		_log_offsets("refresh")


## Logs current offset/size values for drift diagnostics.
## Remove once the left-drift issue is confirmed fixed.
func _log_offsets(tag: String) -> void:
	_log.info("[OFFSETS] %s: L=%.1f R=%.1f T=%.1f B=%.1f sz=(%d,%d) pos=(%d,%d) anchors=(%.2f,%.2f,%.2f,%.2f)" % [
			tag, offset_left, offset_right, offset_top, offset_bottom,
			int(size.x), int(size.y), int(position.x), int(position.y),
			anchor_left, anchor_top, anchor_right, anchor_bottom])


## Sets the collision/overlap message shown between the step rows and
## the End Activation button.  Pass an empty string to hide.
## Called by the game board after overlap resolution.
func set_collision_message(text: String) -> void:
	if _collision_label == null:
		return
	if text.is_empty():
		_collision_label.visible = false
		_collision_label.text = ""
	else:
		_collision_label.text = text
		_collision_label.visible = true
	if visible:
		_request_deferred_layout()


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
## (see .skills/ui_styling.md §1, §3, §4, §10).
func _build_ui() -> void:
	_clear_ui()
	_log_offsets("_build_ui:after_clear")
	# §10 anchor reset: zero stale cached HEIGHT only.  Using size.y = 0
	# instead of size = Vector2.ZERO prevents Godot from recalculating
	# horizontal offsets when the panel shrinks from content-inflated
	# width back to custom_minimum_size — which caused leftward drift.
	# Horizontal offsets are set once in _init() via _apply_anchor_position().
	size.y = 0
	_log_offsets("_build_ui:after_size_y_zero")
	offset_top = -40.0
	offset_bottom = -40.0
	_log_offsets("_build_ui:after_repin_vert")
	_build_panel_style()
	var vbox: VBoxContainer = _build_content_container()
	vbox.add_child(_build_header_labels())
	vbox.add_child(HSeparator.new())
	vbox.add_child(_build_step_section())
	vbox.add_child(_build_collision_label())
	vbox.add_child(_build_end_activation_section())
	vbox.add_child(HSeparator.new())
	vbox.add_child(_build_footer())
	_update_command_info()


## Creates and applies the standard modal panel StyleBox.
func _build_panel_style() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style())


## Creates the main VBoxContainer for all panel content.
func _build_content_container() -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	var _margin_h: float = 32.0 # 16 px content-margin on each side
	vbox.custom_minimum_size.x = maxf(
			custom_minimum_size.x - _margin_h, 100.0)
	add_child(vbox)
	return vbox


## Creates the title, command info, and token info labels.
func _build_header_labels() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)
	_title_label = Label.new()
	var ship_name: String = ""
	if _activation_state and _activation_state.get_ship() and \
			_activation_state.get_ship().ship_data:
		ship_name = _activation_state.get_ship().ship_data.ship_name
	_title_label.text = "Ship Activation — %s" % ship_name
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	section.add_child(_title_label)
	_command_label = Label.new()
	_command_label.text = ""
	_command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(_command_label)
	_token_label = Label.new()
	_token_label.text = ""
	_token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_token_label.add_theme_font_size_override("font_size", 12)
	section.add_child(_token_label)
	return section


## Creates the step rows container and populates all 5 step rows.
func _build_step_section() -> VBoxContainer:
	_step_container = VBoxContainer.new()
	_step_container.add_theme_constant_override("separation", 4)
	_step_rows.clear()
	_execute_button = null
	for i: int in range(STEP_NAMES.size()):
		var row: PanelContainer = _create_step_row(i)
		_step_container.add_child(row)
		_step_rows.append(row)
	return _step_container


## Creates the collision info label (shown on overlap/collision).
func _build_collision_label() -> Label:
	_collision_label = Label.new()
	_collision_label.name = "CollisionLabel"
	_collision_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collision_label.add_theme_font_size_override("font_size", 13)
	_collision_label.add_theme_color_override("font_color",
			Color(1.0, 0.75, 0.3))
	_collision_label.visible = false
	return _collision_label


## Creates the "End Activation ►" button section.
func _build_end_activation_section() -> HBoxContainer:
	var end_container: HBoxContainer = HBoxContainer.new()
	end_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_activation_button = Button.new()
	_end_activation_button.text = "End Activation ►"
	_end_activation_button.custom_minimum_size = Vector2(200, 40)
	_end_activation_button.visible = false
	_end_activation_button.pressed.connect(_on_end_activation_pressed)
	end_container.add_child(_end_activation_button)
	return end_container


## Creates the Close button and Escape hint at the bottom.
func _build_footer() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)
	var close_container: HBoxContainer = HBoxContainer.new()
	close_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var close_btn: Button = Button.new()
	close_btn.text = "✕ Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(_on_close_pressed)
	close_container.add_child(close_btn)
	section.add_child(close_container)
	var hint: Label = UIStyleHelper.create_dismiss_hint(
			"Press Escape to dismiss")
	section.add_child(hint)
	return section


## Creates a single step row.
## Step 5 (index 4, Execute Maneuver) gets an embedded action button.
func _create_step_row(step_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
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
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	_add_step_action_buttons(step_index, hbox)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(status)
	return panel


## Adds step-specific action buttons to the step row HBox.
func _add_step_action_buttons(step_index: int, hbox: HBoxContainer) -> void:
	match step_index:
		4:
			_execute_button = _create_action_button(
					"Execute Maneuver ►", Vector2(130, 28),
					_on_execute_pressed)
			hbox.add_child(_execute_button)
		3:
			_attack_button = _create_action_button(
					"Execute Attack ►", Vector2(130, 28),
					_on_attack_pressed)
			hbox.add_child(_attack_button)
		2:
			_repair_button = _create_action_button(
					"Execute Repair ►", Vector2(130, 28),
					_on_repair_pressed)
			hbox.add_child(_repair_button)
		1:
			_squadron_button = _create_action_button(
					"Execute Squadron ►", Vector2(140, 28),
					_on_squadron_pressed)
			hbox.add_child(_squadron_button)
			_squadron_skip_button = _create_action_button(
					"Skip", Vector2(60, 28),
					_on_squadron_skip_pressed)
			hbox.add_child(_squadron_skip_button)


## Creates a hidden action button with the given text, size, and callback.
func _create_action_button(text: String, min_size: Vector2,
		callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.visible = false
	btn.pressed.connect(callback)
	return btn


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
	_end_activation_button = null
	_collision_label = null


# ---------------------------------------------------------------------------
# Step display updates
# ---------------------------------------------------------------------------


## Updates visual state of all step rows based on current activation step.
## Applies row StyleBoxFlat colours per state (see .skills/ui_styling.md §2).
func _update_step_display() -> void:
	if _activation_state == null:
		return
	var current: int = int(_activation_state.get_current_step())
	for i: int in range(_step_rows.size()):
		var row: PanelContainer = _step_rows[i]
		var status_label: Label = _find_status_label(row)
		if status_label == null:
			continue
		if i < current:
			_style_past_step(row, status_label)
		elif i == current:
			_style_current_step(i, row, status_label)
		else:
			_style_future_step(i, row, status_label)
	_update_end_activation_visibility(current)


## Applies completed-step styling (green checkmark, muted background).
func _style_past_step(row: PanelContainer, status_label: Label) -> void:
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	row_style.border_color = Color(0.3, 0.35, 0.45, 0.6)
	row.add_theme_stylebox_override("panel", row_style)
	status_label.text = "✓"
	status_label.modulate = Color(0.4, 0.9, 0.4)
	row.modulate = Color.WHITE


## Applies active-step styling and shows the relevant action buttons.
func _style_current_step(i: int, row: PanelContainer,
		status_label: Label) -> void:
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.bg_color = Color(0.18, 0.22, 0.32, 1.0)
	row_style.border_color = Color(0.5, 0.6, 0.8, 1.0)
	row.add_theme_stylebox_override("panel", row_style)
	row.modulate = Color.WHITE
	if i in PLACEHOLDER_STEPS:
		status_label.text = "Not yet implemented"
		status_label.modulate = Color(0.9, 0.7, 0.3)
		return
	match i:
		1:
			_style_current_squadron_step(status_label)
		2:
			_style_current_repair_step(status_label)
		3:
			_style_current_attack_step(status_label)
		4:
			_style_current_maneuver_step(status_label)
		_:
			status_label.text = "►"
			status_label.modulate = Color.WHITE


## Configures the Squadron step when it is the current step.
func _style_current_squadron_step(status_label: Label) -> void:
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


## Configures the Repair step when it is the current step.
func _style_current_repair_step(status_label: Label) -> void:
	if _skip_repair:
		status_label.text = "No repair available"
		status_label.modulate = Color(0.9, 0.7, 0.3)
	else:
		status_label.text = ""
		if _repair_button:
			_repair_button.visible = true
			_repair_button.disabled = false


## Configures the Attack step when it is the current step.
func _style_current_attack_step(status_label: Label) -> void:
	if _skip_attack:
		status_label.text = "No targets"
		status_label.modulate = Color(0.9, 0.7, 0.3)
	else:
		status_label.text = ""
		if _attack_button:
			_attack_button.visible = true
			_attack_button.disabled = false


## Configures the Maneuver step when it is the current step.
func _style_current_maneuver_step(status_label: Label) -> void:
	status_label.text = ""
	if _execute_button:
		_execute_button.visible = true
		_execute_button.disabled = false
		if _maneuver_tool_shown:
			_execute_button.text = "Commit Maneuver ►"
		else:
			_execute_button.text = "Execute Maneuver ►"


## Applies future-step styling (dimmed, buttons hidden).
func _style_future_step(i: int, row: PanelContainer,
		status_label: Label) -> void:
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
	row_style.border_color = Color(0.2, 0.25, 0.35, 0.4)
	row.add_theme_stylebox_override("panel", row_style)
	status_label.text = ""
	row.modulate = Color(0.5, 0.5, 0.5)
	_hide_step_buttons(i)


## Hides action buttons for a future (not-yet-reached) step.
func _hide_step_buttons(i: int) -> void:
	match i:
		4:
			if _execute_button:
				_execute_button.visible = false
		3:
			if _attack_button:
				_attack_button.visible = false
		2:
			if _repair_button:
				_repair_button.visible = false
		1:
			if _squadron_button:
				_squadron_button.visible = false
			if _squadron_skip_button:
				_squadron_skip_button.visible = false


## Shows/hides the End Activation button based on step progress.
func _update_end_activation_visibility(current: int) -> void:
	if _end_activation_button:
		var is_done: bool = (current >= int(ShipActivationState.Step.DONE))
		_end_activation_button.visible = is_done
		_end_activation_button.disabled = false


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
		# Phase 1 — show the maneuver tool.  The modal stays open so the
		# player can see "Commit Maneuver ►" while setting the course.
		_log.info("Execute maneuver pressed — showing tool.")
		SfxManager.play_sfx("droid_sound_long")
		_maneuver_tool_shown = true
		if _execute_button:
			_execute_button.text = "Commit Maneuver ►"
		maneuver_step_entered.emit()
	else:
		# Phase 2 — commit the maneuver (snap ship).
		# The modal stays open — it will update to DONE step with the
		# "End Activation ►" button once the game board finishes.
		_log.info("Commit maneuver pressed — snapping ship.")
		SfxManager.play_sfx("star_destroyer_flyby")
		if _execute_button:
			_execute_button.disabled = true
		maneuver_commit_requested.emit()


## Called when the "Execute Attack ►" button is pressed.
## Emits [signal attack_step_entered] and closes the modal so the player
## can interact with the board.
## Requirements: AE-ACT-001.
func _on_attack_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_log.info("Execute Attack pressed — starting attack flow.")
	attack_step_entered.emit()
	close()
	modal_closed.emit()


## Called when the "Execute Squadron ►" button is pressed.
## Emits [signal squadron_step_entered] and closes the modal.
func _on_squadron_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_log.info("Execute Squadron pressed — starting squadron command flow.")
	squadron_step_entered.emit()
	close()
	modal_closed.emit()


## Called when the "Skip" button next to Squadron is pressed.
## Emits [signal squadron_step_skipped] to advance without spending.
## The modal stays open — the game board will re-open it at the next step.
## Rules Reference: "Commands" p.4 — command tokens are optional.
func _on_squadron_skip_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	_log.info("Squadron step skipped by player (token only).")
	squadron_step_skipped.emit()


## Called when the "Execute Repair ►" button is pressed.
## Emits [signal repair_step_entered] and closes the modal.
func _on_repair_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_log.info("Execute Repair pressed — starting repair flow.")
	repair_step_entered.emit()
	close()
	modal_closed.emit()


## Called when the "✕ Close" button is pressed.
func _on_close_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	close()
	modal_closed.emit()


## Called when the "End Activation ►" button is pressed.
## Emits [signal end_activation_requested] so the game board can end the
## current activation and pass the turn to the other player.
## Rules Reference: RRG "Ship Activation" p.16 — activation ends after
## all five steps are complete.
func _on_end_activation_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	_log.info("End Activation pressed — requesting activation end.")
	end_activation_requested.emit()
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
## Called only from the viewport-resize handler.  Re-runs the full anchor
## setup (the single source of truth for all offsets) and then schedules
## a deferred vertical reset to handle stale cached size.
func centre_on_screen(_viewport_size: Vector2) -> void:
	_log_offsets("centre_on_screen:before")
	_apply_anchor_position()
	_request_deferred_layout()
	_log_offsets("centre_on_screen:after")


## Schedules a deferred layout reset so Godot's layout pass completes
## before we re-pin the control offsets.  Without this, adding children
## in [method _build_ui] causes Godot to recalculate offsets on the next
## frame, drifting the panel left.  Mirrors AttackSimPanel §10 pattern.
func _request_deferred_layout() -> void:
	call_deferred("_deferred_layout_reset")


## Resets size + vertical offsets on the next frame so the panel shrinks
## to fit only its visible children.  Horizontal offsets are never touched
## here — they are set once in [method _apply_anchor_position] (§10).
func _deferred_layout_reset() -> void:
	_log_offsets("_deferred:before")
	size.y = 0
	offset_top = -40.0
	offset_bottom = -40.0
	_log_offsets("_deferred:after")

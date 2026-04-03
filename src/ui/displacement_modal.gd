## DisplacementModal
##
## Modal panel that guides the opposing player through squadron displacement.
## Lists all displaced squadrons with check/uncheck status.  The opponent
## places each squadron via mouse-follow snap-to-edge, then locks it with a
## click.  Clicking a checked row un-checks it and re-enters mouse-follow.
## A "Commit Placement ►" button becomes enabled once ALL rows are checked.
##
## Styled identically to ActivationModal / CommandDialPicker
## (see .skills/ui_styling.md §1–§9).
##
## Rules Reference: RRG "Overlapping", p.8 — OV-002, OV-003.
class_name DisplacementModal
extends PanelContainer


## Emitted when the player clicks "Commit Placement ►".
signal placement_committed()

## Emitted when a squadron row is selected (clicked while unchecked,
## or auto-selected).  [param index] is the queue index.
signal squadron_selected(index: int)

## Emitted when a checked row is clicked to reposition.
## [param index] is the queue index that was un-checked.
signal squadron_unchecked(index: int)

## Panel width cap — matches ActivationModal proportions.
const MODAL_MAX_WIDTH: float = 340.0
## Panel width fraction of viewport width.
const MODAL_WIDTH_FRACTION: float = 0.30

## Logger.
var _log: GameLogger = GameLogger.new("DisplacementModal")

## Squadron display names (parallel array to queue).
var _squadron_names: Array[String] = []

## Checked state per squadron (parallel array).
var _checked: Array[bool] = []

## Index of the squadron currently being placed (-1 = none).
var _active_index: int = -1

## VBox that holds the squadron rows.
var _row_container: VBoxContainer = null

## Array of row PanelContainers.
var _rows: Array[PanelContainer] = []

## Row labels (for text updates).
var _row_labels: Array[Label] = []

## Row status icons (parallel to _rows).
var _row_icons: Array[Label] = []

## The commit button.
var _commit_button: Button = null

## Title label.
var _title_label: Label = null

## The main content VBox (for _clear_content).
var _content: VBoxContainer = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_anchor_position()


## Opens the modal with the given squadron names.
## [param names] — display names for each displaced squadron.
func open(names: Array[String]) -> void:
	_squadron_names = names.duplicate()
	_checked.clear()
	_checked.resize(names.size())
	_checked.fill(false)
	_active_index = -1
	_build_ui()
	visible = true
	_request_deferred_layout()
	_log.info("Displacement modal opened with %d squadron(s)." % names.size())


## Closes and hides the modal.
func close_modal() -> void:
	visible = false
	_log.info("Displacement modal closed.")


## Hard-close: clears content too.
func close_and_clear() -> void:
	visible = false
	_clear_content()
	_squadron_names.clear()
	_checked.clear()
	_active_index = -1


## Checks the squadron at [param index] and updates the row display.
## If all squadrons are now checked, enables the commit button.
func check_squadron(index: int) -> void:
	if index < 0 or index >= _checked.size():
		return
	_checked[index] = true
	_active_index = -1
	_update_row_display(index)
	_update_commit_button()
	_log.info("Squadron %d (%s) checked." % [index, _squadron_names[index]])


## Un-checks the squadron at [param index] and disables the commit button.
func uncheck_squadron(index: int) -> void:
	if index < 0 or index >= _checked.size():
		return
	_checked[index] = false
	_active_index = index
	_update_row_display(index)
	_update_commit_button()
	_log.info("Squadron %d (%s) unchecked." % [index, _squadron_names[index]])


## Highlights the row at [param index] as the currently active placement.
func set_active(index: int) -> void:
	_active_index = index
	for i: int in range(_rows.size()):
		_update_row_display(i)


## Returns the index of the first unchecked squadron, or -1 if all checked.
func get_first_unchecked() -> int:
	for i: int in range(_checked.size()):
		if not _checked[i]:
			return i
	return -1


## Returns true if all squadrons are checked.
func all_checked() -> bool:
	for c: bool in _checked:
		if not c:
			return false
	return true


## Returns the checked state array (read-only copy).
func get_checked_states() -> Array[bool]:
	return _checked.duplicate()


# ---------------------------------------------------------------------------
# Anchor / layout
# ---------------------------------------------------------------------------


## Sets centre-screen positioning once.
func _apply_anchor_position() -> void:
	var vp: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp = get_viewport().get_visible_rect().size
	var panel_w: float = minf(MODAL_MAX_WIDTH, vp.x * MODAL_WIDTH_FRACTION)
	custom_minimum_size = Vector2(panel_w, 0.0)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	offset_top = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


## Schedules a one-frame-deferred layout reset.
## Needed because hidden children inflate the PanelContainer during
## synchronous add_child(); Godot only excludes them in the deferred
## layout pass — which is not auto-scheduled on panel reuse.
func _request_deferred_layout() -> void:
	call_deferred("_deferred_layout_reset")


func _deferred_layout_reset() -> void:
	size = Vector2.ZERO
	offset_top = 0.0
	offset_bottom = 0.0


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------


## Removes old content.
func _clear_content() -> void:
	if _content:
		remove_child(_content)
		_content.queue_free()
		_content = null
	_rows.clear()
	_row_labels.clear()
	_row_icons.clear()
	_row_container = null
	_commit_button = null
	_title_label = null


## Builds the full modal UI from scratch.
func _build_ui() -> void:
	_clear_content()
	size = Vector2.ZERO
	offset_top = 0.0
	offset_bottom = 0.0

	# Panel style — standard modal (ui_styling.md §1).
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	var margin_h: float = 32.0
	_content.custom_minimum_size.x = maxf(
			custom_minimum_size.x - margin_h, 100.0)
	add_child(_content)

	# Title.
	_title_label = Label.new()
	_title_label.text = "Squadron Displacement"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	_content.add_child(_title_label)

	# Instruction.
	var info_label: Label = Label.new()
	info_label.text = "Place each squadron in base contact with the ship."
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(info_label)

	# Separator.
	_content.add_child(HSeparator.new())

	# Squadron rows.
	_row_container = VBoxContainer.new()
	_row_container.add_theme_constant_override("separation", 4)
	_content.add_child(_row_container)

	_rows.clear()
	_row_labels.clear()
	_row_icons.clear()
	for i: int in range(_squadron_names.size()):
		var row: PanelContainer = _create_row(i)
		_row_container.add_child(row)
		_rows.append(row)

	# Separator before commit.
	_content.add_child(HSeparator.new())

	# Commit button row.
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_commit_button = Button.new()
	_commit_button.text = "Commit Placement ►"
	_commit_button.custom_minimum_size = Vector2(200, 44)
	_commit_button.disabled = true
	_commit_button.pressed.connect(_on_commit_pressed)
	btn_container.add_child(_commit_button)
	_content.add_child(btn_container)


## Creates a single squadron row with status icon and label.
func _create_row(index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Apply row style.
	var row_style: StyleBoxFlat = _create_row_style_future()
	panel.add_theme_stylebox_override("panel", row_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Status icon (checkmark or circle).
	var icon_label: Label = Label.new()
	icon_label.name = "StatusIcon"
	icon_label.text = "○"
	icon_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(icon_label)
	_row_icons.append(icon_label)

	# Squadron name.
	var name_label: Label = Label.new()
	name_label.text = _squadron_names[index]
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	_row_labels.append(name_label)

	# Connect click.
	panel.gui_input.connect(_on_row_input.bind(index))

	return panel


# ---------------------------------------------------------------------------
# Row styling
# ---------------------------------------------------------------------------


## Row style: future / dimmed (unchecked, not active).
func _create_row_style_future() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.12, 0.6)
	s.border_color = Color(0.2, 0.25, 0.35, 0.4)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


## Row style: active (currently being placed).
func _create_row_style_active() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.22, 0.32, 1.0)
	s.border_color = Color(0.5, 0.6, 0.8, 1.0)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


## Row style: checked / completed.
func _create_row_style_checked() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	s.border_color = Color(0.3, 0.35, 0.45, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s


## Updates the visual display of a single row.
func _update_row_display(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var panel: PanelContainer = _rows[index]
	var icon: Label = _row_icons[index] if index < _row_icons.size() else null
	if _checked[index]:
		panel.add_theme_stylebox_override("panel", _create_row_style_checked())
		if icon:
			icon.text = "✓"
			icon.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	elif index == _active_index:
		panel.add_theme_stylebox_override("panel", _create_row_style_active())
		if icon:
			icon.text = "►"
			icon.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	else:
		panel.add_theme_stylebox_override("panel", _create_row_style_future())
		if icon:
			icon.text = "○"
			icon.remove_theme_color_override("font_color")


## Updates the commit button enabled state.
func _update_commit_button() -> void:
	if _commit_button:
		_commit_button.disabled = not all_checked()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------


## Handles clicks on a squadron row.
func _on_row_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# Consume the event so it doesn't propagate to the game board.
	accept_event()
	if _checked[index]:
		# Already placed — un-check and reposition.
		squadron_unchecked.emit(index)
	else:
		# Select this squadron for placement.
		squadron_selected.emit(index)


## Commit button pressed.
func _on_commit_pressed() -> void:
	if not all_checked():
		return
	SfxManager.play_sfx("droid_sound")
	_log.info("Commit Placement pressed — all squadrons placed.")
	placement_committed.emit()

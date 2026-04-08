## OpponentChoiceModal
##
## Generic modal for presenting damage card immediate-effect choices.
## Supports both single-select (radio) and multi-select (checkbox) modes.
## Used for Shield Failure (opponent picks up to 2 zones), Injured Crew
## (owner picks 1 defense token to discard), and Comm Noise (opponent
## picks speed reduction or dial change).
##
## Styled per .skills/ui_styling.md §1–§10 (anchor reset pattern).
##
## Requirements: DM-011, DM-010–015.
class_name OpponentChoiceModal
extends PanelContainer


## Emitted when the player confirms their selection.
## [param selection] — Dictionary matching the card's expected format:
##   Shield Failure: {"zones": Array[String]}
##   Injured Crew / Comm Noise: {"id": String}
signal choice_confirmed(selection: Dictionary)


## Panel width cap — matches other modal proportions.
const MODAL_MAX_WIDTH: float = 400.0
## Panel width fraction of viewport width.
const MODAL_WIDTH_FRACTION: float = 0.35

## Logger.
var _log: GameLogger = GameLogger.new("OpponentChoiceModal")

## The choice descriptor from ImmediateEffectResolver.get_required_choice().
var _choice_info: Dictionary = {}

## Whether multi-select is enabled (Shield Failure).
var _multi_select: bool = false

## Maximum number of selections in multi-select mode.
var _max_selections: int = 1

## Currently selected option IDs.
var _selected_ids: Array[String] = []

## The main content VBox.
var _content: VBoxContainer = null

## Option buttons (parallel to _choice_info.options).
var _option_buttons: Array[Button] = []

## Confirm button.
var _confirm_button: Button = null

## Title label.
var _title_label: Label = null

## Effect text label.
var _effect_label: Label = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_anchor_position()


## Opens the modal with the given choice descriptor.
## [param choice_info] — from ImmediateEffectResolver.get_required_choice().
func open(choice_info: Dictionary) -> void:
	_choice_info = choice_info
	_multi_select = choice_info.get("multi_select", false)
	_max_selections = int(choice_info.get("max_selections", 1))
	_selected_ids.clear()
	_build_ui()
	visible = true
	_request_deferred_layout()
	_log.info("OpponentChoiceModal opened: %s (chooser=%s, multi=%s)." % [
			choice_info.get("card_title", "?"),
			choice_info.get("chooser", "?"),
			str(_multi_select)])


## Closes and hides the modal.
func close_modal() -> void:
	visible = false
	_log.info("OpponentChoiceModal closed.")


## Hard-close: clears content too.
func close_and_clear() -> void:
	visible = false
	_clear_content()
	_choice_info = {}
	_selected_ids.clear()


# ---------------------------------------------------------------------------
# Anchor / layout (§10 pattern)
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
	_option_buttons.clear()
	_confirm_button = null
	_title_label = null
	_effect_label = null


## Builds the full modal UI from the choice descriptor.
func _build_ui() -> void:
	_clear_content()
	size = Vector2.ZERO
	offset_top = 0.0
	offset_bottom = 0.0
	_apply_panel_style()
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.name = "ContentVBox"
	add_child(_content)
	_content.add_child(_build_header_section())
	_content.add_child(HSeparator.new())
	_content.add_child(_build_option_buttons())
	_content.add_child(_build_confirm_section())
	_update_confirm_state()


## Applies the standard modal panel style.
func _apply_panel_style() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style())


## Creates title, effect text, and chooser labels.
func _build_header_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	_title_label = Label.new()
	_title_label.text = _choice_info.get("card_title", "Damage Card Effect")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color",
			Color(0.9, 0.85, 0.6))
	section.add_child(_title_label)
	_effect_label = Label.new()
	_effect_label.text = _choice_info.get("effect_text", "")
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.add_theme_font_size_override("font_size", 14)
	_effect_label.add_theme_color_override("font_color",
			Color(0.7, 0.7, 0.8))
	section.add_child(_effect_label)
	var chooser: String = _choice_info.get("chooser", "opponent")
	var chooser_label: Label = Label.new()
	chooser_label.text = "Ship owner chooses:" if chooser == "owner" \
			else "Opponent chooses:"
	chooser_label.add_theme_font_size_override("font_size", 16)
	chooser_label.add_theme_color_override("font_color",
			Color(0.4, 0.7, 1.0))
	section.add_child(chooser_label)
	return section


## Creates option toggle buttons and optional multi-select hint.
func _build_option_buttons() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var options: Array = _choice_info.get("options", [])
	_option_buttons.clear()
	for i: int in range(options.size()):
		var opt: Dictionary = options[i]
		var btn: Button = Button.new()
		btn.text = opt.get("label", "Option %d" % i)
		btn.custom_minimum_size = Vector2(0, 24)
		btn.toggle_mode = true
		btn.disabled = not opt.get("available", true)
		btn.pressed.connect(_on_option_pressed.bind(i))
		btn.add_theme_font_size_override("font_size", 14)
		_option_buttons.append(btn)
		section.add_child(btn)
	if _multi_select:
		var hint: Label = Label.new()
		hint.text = "(Select up to %d — or none)" % _max_selections
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(hint)
	return section


## Creates the separator and centred Confirm button.
func _build_confirm_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(HSeparator.new())
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(200, 44)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	btn_container.add_child(_confirm_button)
	section.add_child(btn_container)
	return section


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------


## Handles an option button press.
func _on_option_pressed(index: int) -> void:
	var options: Array = _choice_info.get("options", [])
	if index < 0 or index >= options.size():
		return
	var opt_id: String = options[index].get("id", "")

	if _multi_select:
		# Toggle the selection.
		var btn: Button = _option_buttons[index]
		if btn.button_pressed:
			if _selected_ids.size() >= _max_selections:
				# At max — unpress this button.
				btn.button_pressed = false
				return
			if not _selected_ids.has(opt_id):
				_selected_ids.append(opt_id)
		else:
			_selected_ids.erase(opt_id)
	else:
		# Single-select: deselect all others.
		_selected_ids.clear()
		_selected_ids.append(opt_id)
		for i: int in range(_option_buttons.size()):
			if i != index:
				_option_buttons[i].button_pressed = false
			else:
				_option_buttons[i].button_pressed = true

	_update_confirm_state()


## Updates the confirm button enabled state.
func _update_confirm_state() -> void:
	if _confirm_button == null:
		return
	if _multi_select:
		# Shield Failure: 0 is valid ("may choose"), so always enabled.
		_confirm_button.disabled = false
	else:
		# Single-select: must have exactly 1 selection.
		_confirm_button.disabled = _selected_ids.is_empty()


## Handles the confirm button press.
func _on_confirm_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	var choice_type: String = _choice_info.get("choice_type", "")
	var selection: Dictionary = {}

	if choice_type == ImmediateEffectResolver.CHOICE_SHIELD_FAILURE:
		# Multi-select: return zones array.
		selection = {"zones": _selected_ids.duplicate()}
	elif not _selected_ids.is_empty():
		# Single-select: return id.
		selection = {"id": _selected_ids[0]}
	else:
		_log.warn("Confirm pressed with no selection.")
		return

	_log.info("Choice confirmed: %s → %s" % [choice_type, str(selection)])
	close_modal()
	choice_confirmed.emit(selection)


## Handles Escape key to close (non-destructive — no confirm emitted).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			# For damage card choices, Escape should NOT dismiss — the player
			# must make a choice. Do nothing.
			accept_event()

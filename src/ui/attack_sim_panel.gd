## AttackSimPanel
##
## Screen-space info panel for the Attack Simulator and the real attack
## execution step.  Shows step-by-step prompts guiding the player through
## the attack sequence.
## Phase 6a: attacker declaration.  Phase 6a-2: target selection + LOS result.
## Phase 6a-3: range band display alongside LOS result.
## Phase 6b-1: dice count display and "Done" button for attack execution.
## Phase 6b-2: CF dial, dice rolling, CF token reroll, Confirm, Skip Attack.
##
## Built as a PanelContainer following the project's standard modal styling.
## Dismissed by Escape, re-pressing "A", or programmatically via [method close].
##
## Requirements: AS-PNL-001–003, AS-PNL-010–011, AS-RNG-014, AE-PNL-001–003,
## AE-CF-001–005, AE-CF-010–014, AE-DICE-001–004, AE-CONF-001–002,
## AE-2HZ-001–005, AE-SKIP-001–003.
## Rules Reference: "Attack", Step 1, p.2; "Line of Sight", p.10;
## "Attack Range", p.3; "Concentrate Fire", p.3.
class_name AttackSimPanel
extends PanelContainer


## Emitted when the player presses the "Done" button (sim mode only).
## Requirements: AE-PNL-003.
signal attack_done_pressed()

## Emitted when the player selects a colour for the CF dial extra die.
## Requirements: AE-CF-003.
signal cf_dial_colour_selected(colour_key: String)

## Emitted when the player skips the CF dial.
## Requirements: AE-CF-005.
signal cf_dial_skipped()

## Emitted when the player presses "Roll Dice".
## Requirements: AE-DICE-001.
signal roll_dice_pressed()

## Emitted when the player confirms a die reroll (CF token).
## Requirements: AE-CF-011.
signal cf_token_reroll_requested(die_index: int)

## Emitted when the player skips the CF token reroll.
## Requirements: AE-CF-013.
signal cf_token_reroll_skipped()

## Emitted when the player presses "Confirm" to finalise the attack.
## Requirements: AE-CONF-001.
signal confirm_pressed()

## Emitted when the player presses "Skip Attack".
## Requirements: AE-SKIP-001.
signal skip_attack_pressed()


## Logger.
var _log: GameLogger = GameLogger.new("AttackSimPanel")

## Title label at the top of the panel.
var _title_label: Label = null

## Body label showing the current prompt.
var _body_label: Label = null

## The VBox holding all content.
var _content: VBoxContainer = null

## Dice count label — visible only in attack execution mode.
## Requirements: AE-PNL-001.
var _dice_count_label: Label = null

## "Done" button — visible only in sim mode.
## Requirements: AE-PNL-003.
var _done_button: Button = null

## --- Phase 6b-2 UI elements ---

## CF dial section container (label + colour buttons + skip).
var _cf_dial_container: VBoxContainer = null
## HBox holding the colour buttons for CF dial.
var _cf_dial_buttons: HBoxContainer = null
## Skip button for the CF dial section.
var _cf_dial_skip_button: Button = null
## "Roll Dice" button.
var _roll_button: Button = null
## HBox holding die face TextureRects.
var _dice_container: HBoxContainer = null
## CF token reroll section container.
var _cf_token_container: VBoxContainer = null
## HBox holding the Reroll + Skip buttons for CF token.
var _cf_token_buttons: HBoxContainer = null
## "Reroll" button inside CF token section.
var _cf_token_reroll_button: Button = null
## "Skip" button inside CF token section.
var _cf_token_skip_button: Button = null
## "Confirm" button — finalises the attack.
var _confirm_button: Button = null
## "Skip Attack" button — skips the entire attack.
var _skip_attack_button: Button = null

## Array of TextureRects showing die face images.
var _dice_textures: Array[TextureRect] = []
## Index of the die selected for reroll (-1 = none).
var _selected_reroll_index: int = -1
## Size of each die image in the row (pixels).
const _DIE_IMAGE_SIZE: float = 32.0

## Whether this panel is in attack execution mode (shows dice count + Done).
var _attack_execution_mode: bool = false

## Initial prompt shown when the panel first appears.
## Requirements: AS-PNL-002.
const INITIAL_PROMPT: String = "Select a hull zone or squadron as the attacker."


func _init() -> void:
	name = "AttackSimPanel"
	visible = false


## Builds the panel UI and makes it visible with the initial prompt.
## Requirements: AS-PNL-001, AS-PNL-002.
func show_initial() -> void:
	_build_ui()
	_set_prompt("Attack Simulator", INITIAL_PROMPT)
	visible = true


## Builds the panel UI in attack execution mode with initial hull zone prompt.
## Requirements: AE-PNL-001.
func show_initial_attack_exec(ship_name: String) -> void:
	_attack_execution_mode = true
	_build_ui()
	_set_prompt("%s — Attack" % ship_name,
			"Select attacking hull zone.")
	visible = true


## Updates the panel to show attacker confirmation for a hull zone.
## [param ship_name] — display name of the selected ship.
## [param zone_name] — hull zone string (e.g. "FRONT").
## Requirements: AS-VIS-004, AS-PNL-010.
func show_hull_zone_selected(ship_name: String, zone_name: String) -> void:
	var title: String = "Attacking: %s — %s arc" % [ship_name, zone_name]
	var body: String = "Select a target."
	_set_prompt(title, body)


## Updates the panel to show attacker confirmation for a squadron.
## [param squad_name] — display name of the selected squadron.
## Requirements: AS-VIS-011, AS-PNL-010.
func show_squadron_selected(squad_name: String) -> void:
	var title: String = "Attacking: %s" % squad_name
	var body: String = "Select a target."
	_set_prompt(title, body)


## Updates the panel to show the attacker → target pair, LOS result,
## and range band.
## [param atk_name] — display name of the attacking ship/squadron.
## [param atk_zone] — hull zone string or empty for squadrons.
## [param def_name] — display name of the defending ship/squadron.
## [param def_zone] — hull zone string or empty for squadrons.
## [param los_text] — LOS result string (e.g. "Clear", "Obstructed by X", "Blocked").
## [param range_band] — range band string ("close", "medium", "long", "beyond")
##     or empty to omit the range part.
## Requirements: AS-PNL-011, AS-RNG-014.
func show_target_selected(atk_name: String, atk_zone: String,
		def_name: String, def_zone: String, los_text: String,
		range_band: String = "") -> void:
	var atk_part: String = atk_name
	if atk_zone != "":
		atk_part = "%s — %s" % [atk_name, atk_zone]
	var def_part: String = def_name
	if def_zone != "":
		def_part = "%s — %s" % [def_name, def_zone]
	var title: String = "%s → %s" % [atk_part, def_part]
	var body: String = "LOS: %s" % los_text
	if range_band != "":
		var display_band: String = range_band.capitalize()
		body = "LOS: %s · Range: %s" % [los_text, display_band]
	_set_prompt(title, body)


## Shows the dice pool count label.  Only effective in attack execution mode.
## [param dice_text] — formatted string like "2 red, 1 blue".
## Requirements: AE-PNL-002.
func show_dice_count(dice_text: String) -> void:
	if _dice_count_label:
		_dice_count_label.text = "Dice: %s" % dice_text
		_dice_count_label.visible = true
	# Done button only in sim mode; attack execution uses Confirm flow.
	if _done_button and not _attack_execution_mode:
		_done_button.visible = true


## Hides the dice count label and Done button (e.g. when target is deselected).
## Also hides all Phase 6b-2 UI sections.
func hide_dice_count() -> void:
	if _dice_count_label:
		_dice_count_label.visible = false
	if _done_button:
		_done_button.visible = false
	hide_cf_dial_section()
	hide_roll_button()
	hide_dice_results()
	hide_cf_token_section()
	hide_confirm_button()
	hide_skip_attack_button()


## Returns the current dice count text (for testing).
func get_dice_count_text() -> String:
	if _dice_count_label:
		return _dice_count_label.text
	return ""


## Hides and clears the panel.
## Requirements: AS-PNL-003.
func close() -> void:
	visible = false
	_attack_execution_mode = false
	_clear_content()


## Returns the current title text (for testing).
func get_title_text() -> String:
	if _title_label:
		return _title_label.text
	return ""


## Returns the current body text (for testing).
func get_body_text() -> String:
	if _body_label:
		return _body_label.text
	return ""


# =========================================================================
# UI Construction
# =========================================================================

## Builds the panel structure and applies standard modal styling.
func _build_ui() -> void:
	_clear_content()
	# Panel style (standard modal).
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	# Sizing.
	var vp: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp = get_viewport().get_visible_rect().size
	var panel_w: float = minf(360.0, vp.x * 0.35)
	custom_minimum_size = Vector2(panel_w, 0.0)
	# Position: bottom-centre, above the toolbar.
	anchors_preset = Control.PRESET_CENTER_BOTTOM
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -panel_w * 0.5
	offset_right = panel_w * 0.5
	offset_top = -120.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Content container.
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	# Title label.
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_title_label)
	# Body label.
	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_body_label)
	# Dice count label (attack execution mode only, hidden initially).
	_dice_count_label = Label.new()
	_dice_count_label.add_theme_font_size_override("font_size", 14)
	_dice_count_label.add_theme_color_override("font_color",
			Color(0.6, 0.85, 1.0))
	_dice_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_count_label.visible = false
	_content.add_child(_dice_count_label)
	# Done button (sim mode only, hidden initially).
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.custom_minimum_size = Vector2(80.0, 32.0)
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done_button.visible = false
	_done_button.pressed.connect(_on_done_pressed)
	_content.add_child(_done_button)
	# --- Phase 6b-2 UI elements (hidden by default) ---
	# CF dial section: label + colour buttons + skip.
	_cf_dial_container = VBoxContainer.new()
	_cf_dial_container.add_theme_constant_override("separation", 4)
	_cf_dial_container.visible = false
	_content.add_child(_cf_dial_container)
	var cf_dial_label: Label = Label.new()
	cf_dial_label.text = "CF Dial — add 1 die:"
	cf_dial_label.add_theme_font_size_override("font_size", 13)
	cf_dial_label.add_theme_color_override("font_color",
			Color(1.0, 0.8, 0.3))
	cf_dial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cf_dial_container.add_child(cf_dial_label)
	_cf_dial_buttons = HBoxContainer.new()
	_cf_dial_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_cf_dial_buttons.add_theme_constant_override("separation", 6)
	_cf_dial_container.add_child(_cf_dial_buttons)
	_cf_dial_skip_button = Button.new()
	_cf_dial_skip_button.text = "Skip"
	_cf_dial_skip_button.custom_minimum_size = Vector2(60.0, 28.0)
	_cf_dial_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cf_dial_skip_button.pressed.connect(_on_cf_dial_skip)
	_cf_dial_container.add_child(_cf_dial_skip_button)
	# Roll Dice button.
	_roll_button = Button.new()
	_roll_button.text = "Roll Dice"
	_roll_button.custom_minimum_size = Vector2(100.0, 32.0)
	_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_button.visible = false
	_roll_button.pressed.connect(_on_roll_pressed)
	_content.add_child(_roll_button)
	# Dice results container (TextureRect images).
	_dice_container = HBoxContainer.new()
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_container.add_theme_constant_override("separation", 4)
	_dice_container.visible = false
	_content.add_child(_dice_container)
	# CF token reroll section: label + reroll/skip buttons.
	_cf_token_container = VBoxContainer.new()
	_cf_token_container.add_theme_constant_override("separation", 4)
	_cf_token_container.visible = false
	_content.add_child(_cf_token_container)
	var cf_token_label: Label = Label.new()
	cf_token_label.text = "CF Token — select a die to reroll:"
	cf_token_label.add_theme_font_size_override("font_size", 13)
	cf_token_label.add_theme_color_override("font_color",
			Color(1.0, 0.8, 0.3))
	cf_token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cf_token_container.add_child(cf_token_label)
	_cf_token_buttons = HBoxContainer.new()
	_cf_token_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_cf_token_buttons.add_theme_constant_override("separation", 6)
	_cf_token_container.add_child(_cf_token_buttons)
	_cf_token_reroll_button = Button.new()
	_cf_token_reroll_button.text = "Reroll"
	_cf_token_reroll_button.custom_minimum_size = Vector2(80.0, 28.0)
	_cf_token_reroll_button.disabled = true
	_cf_token_reroll_button.pressed.connect(_on_cf_token_reroll)
	_cf_token_buttons.add_child(_cf_token_reroll_button)
	_cf_token_skip_button = Button.new()
	_cf_token_skip_button.text = "Skip"
	_cf_token_skip_button.custom_minimum_size = Vector2(60.0, 28.0)
	_cf_token_skip_button.pressed.connect(_on_cf_token_skip)
	_cf_token_buttons.add_child(_cf_token_skip_button)
	# Confirm button.
	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(100.0, 32.0)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_button.visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_content.add_child(_confirm_button)
	# Skip Attack button.
	_skip_attack_button = Button.new()
	_skip_attack_button.text = "Skip Attack"
	_skip_attack_button.custom_minimum_size = Vector2(100.0, 28.0)
	_skip_attack_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_attack_button.visible = false
	_skip_attack_button.pressed.connect(_on_skip_attack_pressed)
	_content.add_child(_skip_attack_button)


## Updates the title and body text.
func _set_prompt(title: String, body: String) -> void:
	if _title_label:
		_title_label.text = title
	if _body_label:
		_body_label.text = body


## Removes all content children.
func _clear_content() -> void:
	if _content:
		_content.queue_free()
		_content = null
		_title_label = null
		_body_label = null
		_dice_count_label = null
		_done_button = null
		_cf_dial_container = null
		_cf_dial_buttons = null
		_cf_dial_skip_button = null
		_roll_button = null
		_dice_container = null
		_cf_token_container = null
		_cf_token_buttons = null
		_cf_token_reroll_button = null
		_cf_token_skip_button = null
		_confirm_button = null
		_skip_attack_button = null
		_dice_textures.clear()
		_selected_reroll_index = -1


## Called when the Done button is pressed (sim mode).
func _on_done_pressed() -> void:
	attack_done_pressed.emit()


# =========================================================================
# Phase 6b-2 — Concentrate Fire Dial
# =========================================================================

## Display colour names for CF dial buttons.
const _CF_COLOUR_DISPLAY: Dictionary = {
	"RED": "Red", "BLUE": "Blue", "BLACK": "Black",
}

## Tint colours for CF dial buttons.
const _CF_COLOUR_TINTS: Dictionary = {
	"RED": Color(0.9, 0.2, 0.2),
	"BLUE": Color(0.2, 0.4, 0.9),
	"BLACK": Color(0.5, 0.5, 0.5),
}


## Shows the Concentrate Fire dial section with colour buttons.
## [param available_colours] — colour keys ("RED", "BLUE", "BLACK") the
##     player may choose from (range-filtered).
## Requirements: AE-CF-001, AE-CF-003.
func show_cf_dial_section(available_colours: Array[String]) -> void:
	if _cf_dial_container == null or _cf_dial_buttons == null:
		return
	# Clear previous buttons.
	for child: Node in _cf_dial_buttons.get_children():
		child.queue_free()
	# Build colour buttons.
	for colour_key: String in available_colours:
		var btn: Button = Button.new()
		btn.text = _CF_COLOUR_DISPLAY.get(colour_key, colour_key)
		btn.custom_minimum_size = Vector2(60.0, 28.0)
		btn.add_theme_color_override("font_color",
				_CF_COLOUR_TINTS.get(colour_key, Color.WHITE))
		btn.pressed.connect(_on_cf_dial_colour.bind(colour_key))
		_cf_dial_buttons.add_child(btn)
	_cf_dial_container.visible = true


## Hides the Concentrate Fire dial section.
func hide_cf_dial_section() -> void:
	if _cf_dial_container:
		_cf_dial_container.visible = false


func _on_cf_dial_colour(colour_key: String) -> void:
	cf_dial_colour_selected.emit(colour_key)


func _on_cf_dial_skip() -> void:
	cf_dial_skipped.emit()


# =========================================================================
# Phase 6b-2 — Dice Rolling
# =========================================================================

## Shows the "Roll Dice" button.
## Requirements: AE-DICE-001.
func show_roll_button() -> void:
	if _roll_button:
		_roll_button.visible = true


## Hides the "Roll Dice" button.
func hide_roll_button() -> void:
	if _roll_button:
		_roll_button.visible = false


## Shows the dice roll results as PNG images.
## [param results] — Array of {color: DiceColor, face: DiceFace}.
## Requirements: AE-DICE-002.
func show_dice_results(results: Array[Dictionary]) -> void:
	if _dice_container == null:
		return
	_clear_dice_images()
	_dice_textures.clear()
	_selected_reroll_index = -1
	for i: int in range(results.size()):
		var result: Dictionary = results[i]
		var color: Constants.DiceColor = (
				result["color"] as Constants.DiceColor)
		var face: Constants.DiceFace = (
				result["face"] as Constants.DiceFace)
		var tex_rect: TextureRect = _create_die_image(color, face, i)
		_dice_container.add_child(tex_rect)
		_dice_textures.append(tex_rect)
	_dice_container.visible = true


## Updates a single die image after a reroll.
## [param die_index] — index in the results array.
## [param new_result] — {color: DiceColor, face: DiceFace}.
## Requirements: AE-CF-014.
func update_die_result(die_index: int, new_result: Dictionary) -> void:
	if die_index < 0 or die_index >= _dice_textures.size():
		return
	var color: Constants.DiceColor = (
			new_result["color"] as Constants.DiceColor)
	var face: Constants.DiceFace = (
			new_result["face"] as Constants.DiceFace)
	var path: String = Dice.get_face_image_path(color, face)
	var tex: Texture2D = load(path) as Texture2D
	if tex and _dice_textures[die_index]:
		_dice_textures[die_index].texture = tex
	_selected_reroll_index = -1
	_clear_die_selection_highlights()


## Hides dice result images.
func hide_dice_results() -> void:
	if _dice_container:
		_clear_dice_images()
		_dice_container.visible = false
	_dice_textures.clear()


func _on_roll_pressed() -> void:
	roll_dice_pressed.emit()


# =========================================================================
# Phase 6b-2 — CF Token Reroll
# =========================================================================

## Shows the CF token reroll section.  Die images become clickable.
## Requirements: AE-CF-010.
func show_cf_token_section() -> void:
	if _cf_token_container == null:
		return
	_selected_reroll_index = -1
	_cf_token_container.visible = true
	if _cf_token_reroll_button:
		_cf_token_reroll_button.disabled = true
	_set_dice_clickable(true)


## Hides the CF token reroll section.
func hide_cf_token_section() -> void:
	if _cf_token_container:
		_cf_token_container.visible = false
	_set_dice_clickable(false)
	_selected_reroll_index = -1
	_clear_die_selection_highlights()


## Returns the currently selected reroll die index (for testing).
func get_selected_reroll_index() -> int:
	return _selected_reroll_index


func _on_cf_token_reroll() -> void:
	if _selected_reroll_index >= 0:
		cf_token_reroll_requested.emit(_selected_reroll_index)


func _on_cf_token_skip() -> void:
	cf_token_reroll_skipped.emit()


# =========================================================================
# Phase 6b-2 — Confirm / Skip Attack
# =========================================================================

## Shows the "Confirm" button.
## Requirements: AE-CONF-001.
func show_confirm_button() -> void:
	if _confirm_button:
		_confirm_button.visible = true


## Hides the "Confirm" button.
func hide_confirm_button() -> void:
	if _confirm_button:
		_confirm_button.visible = false


## Shows the "Skip Attack" button.
## Requirements: AE-SKIP-001.
func show_skip_attack_button() -> void:
	if _skip_attack_button:
		_skip_attack_button.visible = true


## Hides the "Skip Attack" button.
func hide_skip_attack_button() -> void:
	if _skip_attack_button:
		_skip_attack_button.visible = false


func _on_confirm_pressed() -> void:
	confirm_pressed.emit()


func _on_skip_attack_pressed() -> void:
	skip_attack_pressed.emit()


# =========================================================================
# Die Image Helpers
# =========================================================================

## Creates a TextureRect for a single die face image.
func _create_die_image(color: Constants.DiceColor,
		face: Constants.DiceFace, index: int) -> TextureRect:
	var path: String = Dice.get_face_image_path(color, face)
	var tex: Texture2D = load(path) as Texture2D
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(_DIE_IMAGE_SIZE, _DIE_IMAGE_SIZE)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("die_index", index)
	return rect


## Clears all die image children from the container.
func _clear_dice_images() -> void:
	if _dice_container:
		for child: Node in _dice_container.get_children():
			child.queue_free()


## Enables or disables click handling on die images.
func _set_dice_clickable(clickable: bool) -> void:
	for tex_rect: TextureRect in _dice_textures:
		if tex_rect == null:
			continue
		if clickable:
			if not tex_rect.gui_input.is_connected(_on_die_clicked):
				tex_rect.gui_input.connect(
						_on_die_clicked.bind(tex_rect))
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			if tex_rect.gui_input.is_connected(_on_die_clicked):
				tex_rect.gui_input.disconnect(
						_on_die_clicked.bind(tex_rect))
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called when a die image is clicked during reroll selection.
func _on_die_clicked(event: InputEvent,
		tex_rect: TextureRect) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = tex_rect.get_meta("die_index", -1)
	if index < 0:
		return
	_selected_reroll_index = index
	_clear_die_selection_highlights()
	tex_rect.modulate = Color(1.0, 1.0, 0.5, 1.0)
	if _cf_token_reroll_button:
		_cf_token_reroll_button.disabled = false


## Resets all die images to default modulate.
func _clear_die_selection_highlights() -> void:
	for tex_rect: TextureRect in _dice_textures:
		if tex_rect:
			tex_rect.modulate = Color.WHITE

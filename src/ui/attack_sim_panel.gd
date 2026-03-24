## AttackSimPanel
##
## Screen-space info panel for the Attack Simulator.
## Shows step-by-step prompts guiding the player through the attack sequence.
## Phase 6a: attacker declaration.  Phase 6a-2: target selection + LOS result.
## Phase 6a-3: range band display alongside LOS result.
##
## Built as a PanelContainer following the project's standard modal styling.
## Dismissed by Escape, re-pressing "A", or programmatically via [method close].
##
## Requirements: AS-PNL-001–003, AS-PNL-010–011, AS-RNG-014.
## Rules Reference: "Attack", Step 1, p.2; "Line of Sight", p.10;
## "Attack Range", p.3.
class_name AttackSimPanel
extends PanelContainer


## Logger.
var _log: GameLogger = GameLogger.new("AttackSimPanel")

## Title label at the top of the panel.
var _title_label: Label = null

## Body label showing the current prompt.
var _body_label: Label = null

## The VBox holding all content.
var _content: VBoxContainer = null

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


## Hides and clears the panel.
## Requirements: AS-PNL-003.
func close() -> void:
	visible = false
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

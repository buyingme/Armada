## TargetingListModal
##
## Read-only modal panel showing all valid attack targets and incoming threats
## for the active player's fleet.  Opened via the "T" button.
##
## Built as a PanelContainer following the project's standard modal styling.
## Scrollable when content exceeds viewport height.
## Dismissed by Escape or re-pressing "T".
##
## Requirements: TL-UI-001–006, TL-LIST-005–007.
class_name TargetingListModal
extends PanelContainer


## Logger.
var _log: GameLogger = GameLogger.new("TargetingListModal")

## The scroll container holding the content.
var _scroll: ScrollContainer = null

## The VBox holding all sections.
var _content: VBoxContainer = null


func _init() -> void:
	name = "TargetingListModal"
	visible = false
	_apply_anchor_position()


## Builds and displays the targeting list content.
## [param build_result] — TargetingListBuilder.BuildResult.
func show_results(build_result: TargetingListBuilder.BuildResult) -> void:
	_build_ui(build_result)
	visible = true


## Hides and clears the modal.
func close() -> void:
	visible = false
	if _scroll:
		_scroll.queue_free()
		_scroll = null
		_content = null


## Sets bottom-centre anchoring once — called from _init to avoid
## Godot offset recalculation on repeated anchor writes.
func _apply_anchor_position() -> void:
	var panel_w: float = 520.0
	custom_minimum_size = Vector2(panel_w, 0.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	offset_top = -40.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## Handles Escape key to dismiss.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


# =========================================================================
# UI Construction
# =========================================================================

## Builds the entire modal UI from the targeting results.
func _build_ui(build_result: TargetingListBuilder.BuildResult) -> void:
	_clear_old_content()
	_apply_panel_style()
	var vp: Vector2 = _get_viewport_size()
	_setup_scroll_and_content(vp)
	_content.add_child(_build_targeting_sections(build_result))
	_add_dimmed_label("Press Escape or T to close")


## Clears old children and resets anchor offsets.
func _clear_old_content() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_scroll = null
	_content = null
	size = Vector2.ZERO
	offset_top = -40.0
	offset_bottom = -40.0


## Applies the standard modal panel style.
func _apply_panel_style() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style())


## Returns the effective viewport size for layout calculations.
func _get_viewport_size() -> Vector2:
	var vp: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp = get_viewport().get_visible_rect().size
	return vp


## Creates the scroll container, content VBox, and title.
func _setup_scroll_and_content(vp: Vector2) -> void:
	var panel_w: float = minf(520.0, vp.x * 0.45)
	var max_h: float = minf(vp.y * 0.8, 600.0)
	custom_minimum_size = Vector2(panel_w, 0.0)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, max_h)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	var title: Label = Label.new()
	title.text = "Targeting List"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)


## Iterates ship and squadron results, building sections.
func _build_targeting_sections(
		build_result: TargetingListBuilder.BuildResult) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)
	var has_content: bool = false
	for result: Variant in build_result.ship_results:
		var r: TargetingListBuilder.ShipTargetingResult = \
				result as TargetingListBuilder.ShipTargetingResult
		section.add_child(_build_ship_section(r))
		has_content = true
	for sq_result: Variant in build_result.squad_results:
		var sr: TargetingListBuilder.SquadTargetingResult = \
				sq_result as TargetingListBuilder.SquadTargetingResult
		section.add_child(_build_squad_section(sr))
		has_content = true
	if not has_content:
		section.add_child(_create_dimmed_label(
				"— No ships or squadrons to display —"))
	return section


## Creates one ship section (outgoing + incoming).
func _build_ship_section(
		result: TargetingListBuilder.ShipTargetingResult) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	_add_section_header_to(section, result.ship_name, Color(0.9, 0.85, 0.6))
	_add_outgoing_targets_to(section, result.outgoing)
	_add_incoming_threats_to(section, result.incoming)
	return section


## Adds a target line showing attacking and (if applicable) defending hull zone.
## For ship targets with [member has_target_zone]: shows "Name FRONT→REAR at ..."
## For squadron targets: shows "Name in range of ARC arc ..."
## Requirements: TL-LIST-006, TL-LIST-013, TL-UI-006, AC-TL-37.
func _add_target_line_to(parent: VBoxContainer,
		entry: TargetingListBuilder.TargetEntry) -> void:
	var text: String = _format_target_text(entry)
	if entry.obstructed:
		text += " — obstructed"
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", _range_colour(
			entry.range_band, entry.obstructed))
	parent.add_child(label)


## Formats the target text string for a TargetEntry.
func _format_target_text(
		entry: TargetingListBuilder.TargetEntry) -> String:
	var dice_str: String = RangeFinder.format_dice(entry.dice)
	if entry.has_target_zone:
		var arcs: String = "%s→%s" % [
				_hz_display(entry.arc), _hz_display(entry.target_zone)]
		if entry.range_band == "in range":
			return "    %s %s in range (%s)" % [
					entry.target_name, arcs, dice_str]
		return "    %s %s at %s range (%s)" % [
				entry.target_name, arcs, entry.range_band, dice_str]
	if entry.range_band == "in range":
		return "    %s in range of %s arc (%s)" % [
				entry.target_name, _hz_display(entry.arc), dice_str]
	return "    %s at %s range of %s arc (%s)" % [
			entry.target_name, entry.range_band,
			_hz_display(entry.arc), dice_str]


## Adds a threat line to the given parent container.
## Requirements: TL-LIST-007.
func _add_threat_line_to(parent: VBoxContainer,
		threat: TargetingListBuilder.ThreatEntry) -> void:
	var text: String
	if threat.range_band == "in range":
		text = "    %s is in range" % threat.enemy_name
	else:
		text = "    %s is at %s range of %s's %s arc" % [
			threat.friendly_name,
			threat.range_band,
			threat.enemy_name,
			_hz_display(threat.arc),
		]
	if threat.obstructed:
		text += " — obstructed"
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", _range_colour(
			threat.range_band, threat.obstructed))
	parent.add_child(label)


## Creates one squadron section (outgoing + incoming).
## Requirements: TL-LIST-011, TL-LIST-012, AC-TL-36.
func _build_squad_section(
		result: TargetingListBuilder.SquadTargetingResult) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	_add_section_header_to(
			section, result.squad_name + " (squadron)", Color(0.6, 0.9, 0.7))
	_add_outgoing_targets_to(section, result.outgoing)
	_add_incoming_threats_to(section, result.incoming)
	return section


## Adds a coloured section header label with a separator to the parent.
func _add_section_header_to(parent: VBoxContainer,
		text: String, colour: Color) -> void:
	var header: Label = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", colour)
	parent.add_child(header)
	parent.add_child(HSeparator.new())


## Adds outgoing target entries with a sub-header to the parent.
func _add_outgoing_targets_to(parent: VBoxContainer,
		outgoing: Array) -> void:
	var out_header: Label = Label.new()
	out_header.text = "  Outgoing targets:"
	out_header.add_theme_font_size_override("font_size", 13)
	out_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	parent.add_child(out_header)
	if outgoing.is_empty():
		parent.add_child(_create_dimmed_label(
				"    — No targets in range —"))
		return
	for entry: Variant in outgoing:
		var te: TargetingListBuilder.TargetEntry = \
				entry as TargetingListBuilder.TargetEntry
		_add_target_line_to(parent, te)


## Adds incoming threat entries with a sub-header to the parent.
func _add_incoming_threats_to(parent: VBoxContainer,
		incoming: Array) -> void:
	var in_header: Label = Label.new()
	in_header.text = "  Incoming threats:"
	in_header.add_theme_font_size_override("font_size", 13)
	in_header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	parent.add_child(in_header)
	if incoming.is_empty():
		parent.add_child(_create_dimmed_label(
				"    — No incoming threats —"))
		return
	for threat: Variant in incoming:
		var te: TargetingListBuilder.ThreatEntry = \
				threat as TargetingListBuilder.ThreatEntry
		_add_threat_line_to(parent, te)


## Creates a dimmed hint/placeholder label (returns without adding).
func _create_dimmed_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return label


## Adds a dimmed hint/placeholder label to _content.
func _add_dimmed_label(text: String) -> void:
	_content.add_child(_create_dimmed_label(text))


## Returns display name for a hull zone.
func _hz_display(zone: Constants.HullZone) -> String:
	match zone:
		Constants.HullZone.FRONT:
			return "FRONT"
		Constants.HullZone.LEFT:
			return "LEFT"
		Constants.HullZone.RIGHT:
			return "RIGHT"
		Constants.HullZone.REAR:
			return "REAR"
		_:
			return "?"


## Returns text colour for a range band.
## Requirements: TL-UI-006.
func _range_colour(band: String, is_obstructed: bool) -> Color:
	if is_obstructed:
		return Color(0.95, 0.7, 0.3) # orange
	match band:
		Constants.RANGE_BAND_CLOSE, "in range":
			return Color(0.8, 0.8, 0.8) # grey/white
		Constants.RANGE_BAND_MEDIUM:
			return Color(0.5, 0.7, 1.0) # blue
		Constants.RANGE_BAND_LONG:
			return Color(1.0, 0.5, 0.5) # red
		_:
			return Color(0.6, 0.6, 0.6)

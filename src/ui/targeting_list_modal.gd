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
	# Clear old content — remove + queue_free all children so stale nodes
	# don't inflate the PanelContainer's minimum size.
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_scroll = null
	_content = null
	# Panel style (standard modal).
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	# Sizing.
	var vp: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp = get_viewport().get_visible_rect().size
	var panel_w: float = minf(520.0, vp.x * 0.45)
	var panel_h: float = minf(vp.y * 0.8, 600.0)
	custom_minimum_size = Vector2(panel_w, panel_h)
	size = custom_minimum_size
	# Update bottom-centre anchor widths.
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	# Margin container.
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	# Scroll container.
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)
	# Content.
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	# Title.
	var title: Label = Label.new()
	title.text = "Targeting List"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	# Ship sections.
	var has_content: bool = false
	for result: Variant in build_result.ship_results:
		var r: TargetingListBuilder.ShipTargetingResult = \
				result as TargetingListBuilder.ShipTargetingResult
		_build_ship_section(r)
		has_content = true
	# Squadron sections (AC-TL-36: after ship sections).
	for sq_result: Variant in build_result.squad_results:
		var sr: TargetingListBuilder.SquadTargetingResult = \
				sq_result as TargetingListBuilder.SquadTargetingResult
		_build_squad_section(sr)
		has_content = true
	if not has_content:
		_add_dimmed_label("— No ships or squadrons to display —")
	# Hint.
	_add_dimmed_label("Press Escape or T to close")


## Builds one ship section (outgoing + incoming).
func _build_ship_section(
		result: TargetingListBuilder.ShipTargetingResult) -> void:
	# Ship header.
	var header: Label = Label.new()
	header.text = result.ship_name
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_content.add_child(header)
	# Separator.
	var sep: HSeparator = HSeparator.new()
	_content.add_child(sep)
	# Outgoing targets.
	var out_header: Label = Label.new()
	out_header.text = "  Outgoing targets:"
	out_header.add_theme_font_size_override("font_size", 13)
	out_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_content.add_child(out_header)
	if result.outgoing.is_empty():
		_add_dimmed_label("    — No targets in range —")
	else:
		for entry: Variant in result.outgoing:
			var te: TargetingListBuilder.TargetEntry = \
					entry as TargetingListBuilder.TargetEntry
			_add_target_line(te)
	# Incoming threats.
	var in_header: Label = Label.new()
	in_header.text = "  Incoming threats:"
	in_header.add_theme_font_size_override("font_size", 13)
	in_header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	_content.add_child(in_header)
	if result.incoming.is_empty():
		_add_dimmed_label("    — No incoming threats —")
	else:
		for threat: Variant in result.incoming:
			var te: TargetingListBuilder.ThreatEntry = \
					threat as TargetingListBuilder.ThreatEntry
			_add_threat_line(te)


## Adds a target line showing attacking and (if applicable) defending hull zone.
## For ship targets with [member has_target_zone]: shows "Name FRONT→REAR at ..."
## For squadron targets: shows "Name in range of ARC arc ..."
## Requirements: TL-LIST-006, TL-LIST-013, TL-UI-006, AC-TL-37.
func _add_target_line(entry: TargetingListBuilder.TargetEntry) -> void:
	var text: String
	if entry.has_target_zone:
		# Ship → ship: show attacking arc → defending hull zone.
		if entry.range_band == "in range":
			text = "    %s %s→%s in range (%s)" % [
				entry.target_name,
				_hz_display(entry.arc),
				_hz_display(entry.target_zone),
				RangeFinder.format_dice(entry.dice),
			]
		else:
			text = "    %s %s→%s at %s range (%s)" % [
				entry.target_name,
				_hz_display(entry.arc),
				_hz_display(entry.target_zone),
				entry.range_band,
				RangeFinder.format_dice(entry.dice),
			]
	elif entry.range_band == "in range":
		text = "    %s in range of %s arc (%s)" % [
			entry.target_name,
			_hz_display(entry.arc),
			RangeFinder.format_dice(entry.dice),
		]
	else:
		text = "    %s at %s range of %s arc (%s)" % [
			entry.target_name,
			entry.range_band,
			_hz_display(entry.arc),
			RangeFinder.format_dice(entry.dice),
		]
	if entry.obstructed:
		text += " — obstructed"
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	# Colour coding (TL-UI-006).
	label.add_theme_color_override("font_color", _range_colour(
			entry.range_band, entry.obstructed))
	_content.add_child(label)


## Adds a threat line: "<Friendly> is at <range> range of <Enemy>'s <ARC> arc"
## For squadron threats where range_band == "in range", uses
## "<Enemy> is in range" instead.
## Requirements: TL-LIST-007.
func _add_threat_line(threat: TargetingListBuilder.ThreatEntry) -> void:
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
	_content.add_child(label)


## Builds one squadron section (outgoing + incoming).
## Requirements: TL-LIST-011, TL-LIST-012, AC-TL-36.
func _build_squad_section(
		result: TargetingListBuilder.SquadTargetingResult) -> void:
	# Squadron header (different colour from ships).
	var header: Label = Label.new()
	header.text = result.squad_name + " (squadron)"
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	_content.add_child(header)
	# Separator.
	var sep: HSeparator = HSeparator.new()
	_content.add_child(sep)
	# Outgoing targets.
	var out_header: Label = Label.new()
	out_header.text = "  Outgoing targets:"
	out_header.add_theme_font_size_override("font_size", 13)
	out_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_content.add_child(out_header)
	if result.outgoing.is_empty():
		_add_dimmed_label("    — No targets in range —")
	else:
		for entry: Variant in result.outgoing:
			var te: TargetingListBuilder.TargetEntry = \
					entry as TargetingListBuilder.TargetEntry
			_add_target_line(te)
	# Incoming threats.
	var in_header: Label = Label.new()
	in_header.text = "  Incoming threats:"
	in_header.add_theme_font_size_override("font_size", 13)
	in_header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	_content.add_child(in_header)
	if result.incoming.is_empty():
		_add_dimmed_label("    — No incoming threats —")
	else:
		for threat: Variant in result.incoming:
			var te: TargetingListBuilder.ThreatEntry = \
					threat as TargetingListBuilder.ThreatEntry
			_add_threat_line(te)


## Adds a dimmed hint/placeholder label.
func _add_dimmed_label(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_content.add_child(label)


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

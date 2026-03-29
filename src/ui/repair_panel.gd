## RepairPanel
##
## Modal panel for the Repair (Engineering) command during ship activation.
## Guides the player through spending engineering points on three repair
## operations: move shields, recover shields, and discard damage cards.
##
## Uses the [RepairResolver] for validation and application. The panel
## shows available operations, remaining points, and action buttons.
##
## Styled identically to AttackSimPanel / ActivationModal
## (see .skills/ui_styling.md).
##
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
class_name RepairPanel
extends PanelContainer


## Emitted when the player finishes the repair command (Done pressed).
signal repair_done()

## Emitted when the player skips the repair command entirely.
signal repair_skipped()


## Panel width cap — matches AttackSimPanel proportions.
const MODAL_MAX_WIDTH: float = 400.0
## Panel width fraction of viewport width.
const MODAL_WIDTH_FRACTION: float = 0.38


## The RepairResolver driving this panel's logic.
var _resolver: RepairResolver = null

## Ship being repaired.
var _ship: ShipInstance = null

## Logger for this system.
var _log: GameLogger = GameLogger.new("RepairPanel")

## UI references.
var _title_label: Label = null
var _points_label: Label = null
var _actions_container: VBoxContainer = null
var _done_button: Button = null
var _skip_button: Button = null

## Zone names for display.
const ZONE_KEYS: Array[String] = ["FRONT", "LEFT", "RIGHT", "REAR"]


func _init() -> void:
	visible = false
	_apply_anchor_position()


## Opens the repair panel for the given ship with a pre-built resolver.
## [param resolver] — the RepairResolver with points already calculated.
## [param ship] — the ShipInstance being repaired.
func open(resolver: RepairResolver, ship: ShipInstance) -> void:
	_resolver = resolver
	_ship = ship
	_build_ui()
	_refresh_actions()
	visible = true
	set_process_unhandled_input(true)
	_log.info("Repair panel opened: %d points available." %
			resolver.get_total_points())


## Closes and hides the panel.
func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	_log.info("Repair panel closed.")


## Returns true if the panel is open.
func is_open() -> bool:
	return visible and _resolver != null


## Escape key dismisses the panel (same as Done).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_done_pressed()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------


## Sets bottom-centre anchoring once.
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


## Builds the full modal UI.
func _build_ui() -> void:
	_clear_ui()
	size = Vector2.ZERO
	offset_top = -40.0
	offset_bottom = -40.0

	# Panel style.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var margin_h: float = 32.0
	vbox.custom_minimum_size.x = maxf(
			custom_minimum_size.x - margin_h, 100.0)
	add_child(vbox)

	# Title.
	_title_label = Label.new()
	var ship_name: String = ""
	if _ship and _ship.ship_data:
		ship_name = _ship.ship_data.ship_name
	_title_label.text = "Repair — %s" % ship_name
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	# Points display.
	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_points_label)

	# Separator.
	vbox.add_child(HSeparator.new())

	# Actions container.
	_actions_container = VBoxContainer.new()
	_actions_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_actions_container)

	# Separator before buttons.
	vbox.add_child(HSeparator.new())

	# Button row.
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)

	_skip_button = Button.new()
	_skip_button.text = "Skip Repair"
	_skip_button.custom_minimum_size = Vector2(110, 32)
	_skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_skip_button)

	_done_button = Button.new()
	_done_button.text = "Done ►"
	_done_button.custom_minimum_size = Vector2(110, 32)
	_done_button.pressed.connect(_on_done_pressed)
	btn_row.add_child(_done_button)

	vbox.add_child(btn_row)

	# Dismiss hint.
	var hint: Label = Label.new()
	hint.text = "Press Escape to finish"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)


## Clears all children from the panel.
func _clear_ui() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_title_label = null
	_points_label = null
	_actions_container = null
	_done_button = null
	_skip_button = null


# ---------------------------------------------------------------------------
# Action display
# ---------------------------------------------------------------------------


## Refreshes the available repair actions based on remaining points.
func _refresh_actions() -> void:
	if _resolver == null:
		return
	_points_label.text = "Engineering Points: %d / %d" % [
			_resolver.get_remaining_points(), _resolver.get_total_points()]
	# Clear action rows.
	for child: Node in _actions_container.get_children():
		_actions_container.remove_child(child)
		child.queue_free()
	# Section: Move Shields (1 pt).
	if _resolver.can_move_shields():
		_add_section_label("Move Shield (1 pt)")
		_add_move_shield_buttons()
	# Section: Recover Shields (2 pts).
	if _resolver.can_recover_shields():
		_add_section_label("Recover Shield (2 pts)")
		_add_recover_shield_buttons()
	# Section: Repair Hull (3 pts).
	if _resolver.can_repair_hull():
		_add_section_label("Discard Damage Card (3 pts)")
		_add_repair_hull_buttons()
	# No actions available.
	if _actions_container.get_child_count() == 0:
		var lbl: Label = Label.new()
		lbl.text = "No repair actions available."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_actions_container.add_child(lbl)
	# Update done button.
	_done_button.disabled = false
	# Hide skip if points were already spent.
	_skip_button.visible = (_resolver.get_points_spent() == 0)


## Adds a section header label.
func _add_section_label(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_actions_container.add_child(lbl)


## Adds buttons for each valid move-shields pair.
func _add_move_shield_buttons() -> void:
	for from_z: String in ZONE_KEYS:
		for to_z: String in ZONE_KEYS:
			if _resolver.can_move_shields_between(from_z, to_z):
				var btn: Button = Button.new()
				var from_s: int = int(_ship.current_shields.get(from_z, 0))
				var to_s: int = int(_ship.current_shields.get(to_z, 0))
				var to_max: int = _ship.get_max_shields(to_z)
				btn.text = "%s (%d) → %s (%d/%d)" % [
						from_z, from_s, to_z, to_s, to_max]
				btn.custom_minimum_size = Vector2(0, 28)
				btn.pressed.connect(
						_on_move_shields.bind(from_z, to_z))
				_actions_container.add_child(btn)


## Adds buttons for each valid recover-shields zone.
func _add_recover_shield_buttons() -> void:
	for zone: String in ZONE_KEYS:
		if _resolver.can_recover_shields_on(zone):
			var btn: Button = Button.new()
			var cur: int = int(_ship.current_shields.get(zone, 0))
			var mx: int = _ship.get_max_shields(zone)
			btn.text = "%s (%d/%d)" % [zone, cur, mx]
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_recover_shield.bind(zone))
			_actions_container.add_child(btn)


## Adds buttons for damage cards that can be discarded.
func _add_repair_hull_buttons() -> void:
	for card: Variant in _ship.faceup_damage:
		if card is DamageCard:
			var dc: DamageCard = card as DamageCard
			var btn: Button = Button.new()
			btn.text = "▲ %s (faceup)" % dc.title
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_repair_card.bind(dc))
			_actions_container.add_child(btn)
	for card: Variant in _ship.facedown_damage:
		if card is DamageCard:
			var dc: DamageCard = card as DamageCard
			var btn: Button = Button.new()
			btn.text = "▼ Damage Card (facedown)"
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_repair_card.bind(dc))
			_actions_container.add_child(btn)


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------


## Called when a move-shields button is pressed.
func _on_move_shields(from_zone: String, to_zone: String) -> void:
	if _resolver == null:
		return
	var ok: bool = _resolver.move_shields(from_zone, to_zone)
	if ok:
		_log.info("Moved shield %s → %s." % [from_zone, to_zone])
		_refresh_actions()


## Called when a recover-shields button is pressed.
func _on_recover_shield(zone: String) -> void:
	if _resolver == null:
		return
	var ok: bool = _resolver.recover_shields(zone)
	if ok:
		_log.info("Recovered shield on %s." % zone)
		_refresh_actions()


## Called when a repair-card button is pressed.
func _on_repair_card(card: DamageCard) -> void:
	if _resolver == null:
		return
	var ok: bool = _resolver.repair_hull(card)
	if ok:
		_log.info("Repaired card: %s." % card.title)
		_refresh_actions()


## Called when Done is pressed — finalizes and emits signal.
func _on_done_pressed() -> void:
	if _resolver:
		_resolver.finalize()
	close()
	repair_done.emit()


## Called when Skip is pressed — no points spent, but finalize anyway.
func _on_skip_pressed() -> void:
	# Don't finalize — skip means don't spend resources.
	close()
	repair_skipped.emit()


## Updates the bottom-centre anchored position for the given viewport size.
func centre_on_screen(viewport_size: Vector2) -> void:
	var panel_w: float = minf(MODAL_MAX_WIDTH,
			viewport_size.x * MODAL_WIDTH_FRACTION)
	custom_minimum_size = Vector2(panel_w, 0.0)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5

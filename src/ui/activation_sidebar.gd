## ActivationSidebar
##
## Vertical panel showing the activation status of all ships and squadrons
## grouped by faction. Displayed on the lower-left screen edge during the
## Ship Phase and Squadron Phase. Starts collapsed (only 20 px visible);
## click to expand / collapse. Auto-updates when ships or squadrons are
## activated or destroyed.
##
## Provides at-a-glance visibility into:
##   - Which units have activated this round (dimmed grey).
##   - Which units are still available (faction colour).
##   - Initiative player (★ marker).
##
## Requirements: UI-014.
class_name ActivationSidebar
extends PanelContainer


## Panel maximum width.
const SIDEBAR_MAX_WIDTH: float = 260.0

## How many pixels of the right edge remain visible when collapsed.
const PEEK_WIDTH: float = 20.0

## Slide animation duration in seconds.
const SLIDE_DURATION: float = 0.25

## Margin from the bottom of the viewport.
const BOTTOM_MARGIN: float = 12.0

## Panel background colour.
const PANEL_BG: Color = Color(0.1, 0.1, 0.16, 0.9)

## Panel border colour.
const PANEL_BORDER: Color = Color(0.3, 0.4, 0.6, 0.8)

## Activated unit text colour (dimmed).
const ACTIVATED_COLOR: Color = Color(0.4, 0.4, 0.4)

## Rebel unactivated colour (orange-gold, matches ship token outline).
const REBEL_COLOR: Color = Color(0.95, 0.72, 0.25)

## Imperial unactivated colour (grey-green, matches ship token outline).
const IMPERIAL_COLOR: Color = Color(0.50, 0.75, 0.55)

## Highlight colour for the currently-activating unit (bright white).
const ACTIVE_HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0)

## Prefix shown before the currently-activating unit's name.
const ACTIVE_PREFIX: String = "\u25b6 "

## Destroyed unit text colour.
const DESTROYED_COLOR: Color = Color(0.5, 0.2, 0.2)

## Initiative marker.
const INITIATIVE_MARKER: String = " ★"

## Logger.
var _log: GameLogger = GameLogger.new("ActivationSidebar")

## Main content container.
var _content: VBoxContainer = null

## Per-faction section containers.
var _rebel_section: VBoxContainer = null
var _imperial_section: VBoxContainer = null

## Faction headers (for initiative marker update).
var _rebel_header: Label = null
var _imperial_header: Label = null

## Ship/squadron entry labels keyed by instance reference.
var _entries: Dictionary = {}

## Currently highlighted (active) instance, or null.
var _active_instance: Variant = null

## Original label text before the active prefix was prepended.
var _active_original_text: String = ""

## Current initiative player index.
var _initiative_player: int = 0

## Whether the panel is expanded (fully visible) or collapsed.
var _expanded: bool = false

## Current cached viewport size for positioning.
var _viewport_size: Vector2 = Vector2(1920, 1080)

## Active slide tween (auto-killed on node free).
var _slide_tween: Tween = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SIDEBAR_MAX_WIDTH, 0)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	add_child(_content)




## Populates the sidebar with ships and squadrons from both players.
## [param game_state] — the current GameState.
func populate(game_state: Variant) -> void:
	_clear()
	if game_state == null:
		return
	_initiative_player = game_state.initiative_player
	# Build player sections in initiative order.
	var first: int = _initiative_player
	var second: int = 1 - first
	_build_player_section(game_state, first, true)
	_build_player_section(game_state, second, false)
	_expanded = false
	visible = true
	# Start collapsed — position will be set after layout.
	call_deferred("_snap_to_collapsed")
	_log.info("Sidebar populated with %d entries." % _entries.size())


## Updates cached viewport size and re-positions the panel.
## [param viewport_size] — the current viewport size.
func update_position(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	if _expanded:
		position = _expanded_pos()
	else:
		position = _collapsed_pos()


## Handles click to toggle expanded / collapsed state.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_toggle_expanded()
			accept_event()


## Refreshes visibility of all entries based on current activation state.
func refresh() -> void:
	for inst: Variant in _entries.keys():
		_update_entry(inst)


## Connects to EventBus signals for live updates.
func connect_signals() -> void:
	if not EventBus.ship_activated.is_connected(_on_ship_activated):
		EventBus.ship_activated.connect(_on_ship_activated)
	if not EventBus.activation_ended.is_connected(_on_activation_ended):
		EventBus.activation_ended.connect(_on_activation_ended)
	if not EventBus.ship_destroyed.is_connected(_on_ship_destroyed):
		EventBus.ship_destroyed.connect(_on_ship_destroyed)
	if not EventBus.squadron_activated.is_connected(
			_on_squadron_activated):
		EventBus.squadron_activated.connect(_on_squadron_activated)
	if not EventBus.squadron_destroyed.is_connected(
			_on_squadron_destroyed):
		EventBus.squadron_destroyed.connect(_on_squadron_destroyed)
	if not EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.connect(_on_phase_changed)


## Disconnects EventBus signals.
func disconnect_signals() -> void:
	if EventBus.ship_activated.is_connected(_on_ship_activated):
		EventBus.ship_activated.disconnect(_on_ship_activated)
	if EventBus.activation_ended.is_connected(_on_activation_ended):
		EventBus.activation_ended.disconnect(_on_activation_ended)
	if EventBus.ship_destroyed.is_connected(_on_ship_destroyed):
		EventBus.ship_destroyed.disconnect(_on_ship_destroyed)
	if EventBus.squadron_activated.is_connected(
			_on_squadron_activated):
		EventBus.squadron_activated.disconnect(_on_squadron_activated)
	if EventBus.squadron_destroyed.is_connected(
			_on_squadron_destroyed):
		EventBus.squadron_destroyed.disconnect(_on_squadron_destroyed)
	if EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.disconnect(_on_phase_changed)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


## Builds one player's section (ships + squadrons).
func _build_player_section(game_state: Variant, player_idx: int,
		has_initiative: bool) -> void:
	var ps: Variant = game_state.get_player_state(player_idx)
	if ps == null:
		return
	var faction_name: String = _faction_name(ps.faction)
	var header: Label = Label.new()
	var init_str: String = INITIATIVE_MARKER if has_initiative else ""
	header.text = "%s%s" % [faction_name, init_str]
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color",
			Color(0.8, 0.75, 0.5))
	_content.add_child(header)
	if ps.faction == Constants.Faction.REBEL_ALLIANCE:
		_rebel_section = VBoxContainer.new()
		_rebel_header = header
		_content.add_child(_rebel_section)
	else:
		_imperial_section = VBoxContainer.new()
		_imperial_header = header
		_content.add_child(_imperial_section)
	var section: VBoxContainer = _rebel_section \
			if ps.faction == Constants.Faction.REBEL_ALLIANCE \
			else _imperial_section
	# Ships.
	for ship: Variant in ps.ships:
		_add_entry(section, ship, true, ps.faction)
	# Squadrons.
	for sq: Variant in ps.squadrons:
		_add_entry(section, sq, false, ps.faction)
	# Separator between factions.
	var sep: HSeparator = HSeparator.new()
	_content.add_child(sep)


## Adds a single ship or squadron entry.
func _add_entry(section: VBoxContainer, instance: Variant,
		is_ship: bool, faction: Constants.Faction) -> void:
	var lbl: Label = Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	var unit_name: String = _get_unit_name(instance, is_ship)
	var prefix: String = "⬤ " if is_ship else "◆ "
	lbl.text = prefix + unit_name
	var active_color: Color = _faction_active_color(faction)
	lbl.add_theme_color_override("font_color", active_color)
	section.add_child(lbl)
	_entries[instance] = {
		"label": lbl, "is_ship": is_ship, "faction": faction}
	_update_entry(instance)


## Returns a display name for the given unit instance.
func _get_unit_name(instance: Variant, is_ship: bool) -> String:
	if is_ship and instance.ship_data:
		return instance.ship_data.ship_name
	if not is_ship and instance.squadron_data:
		return instance.squadron_data.squadron_name
	return "Unknown"


## Highlights the currently-activating unit with a ▶ prefix and bright colour.
## [param instance] — the ShipInstance or SquadronInstance being activated.
func highlight_active(instance: Variant) -> void:
	clear_active()
	if not _entries.has(instance):
		return
	_active_instance = instance
	var entry: Dictionary = _entries[instance]
	var lbl: Label = entry["label"]
	_active_original_text = lbl.text
	lbl.text = ACTIVE_PREFIX + _active_original_text
	lbl.add_theme_color_override("font_color", ACTIVE_HIGHLIGHT_COLOR)


## Clears any active highlight, restoring original text and colour.
func clear_active() -> void:
	if _active_instance == null:
		return
	if _entries.has(_active_instance):
		var entry: Dictionary = _entries[_active_instance]
		var lbl: Label = entry["label"]
		lbl.text = _active_original_text
		_update_entry(_active_instance)
	_active_instance = null
	_active_original_text = ""


## Updates the colour of an entry based on its activation/destruction state.
func _update_entry(instance: Variant) -> void:
	if not _entries.has(instance):
		return
	var entry: Dictionary = _entries[instance]
	var lbl: Label = entry["label"]
	var faction: Constants.Faction = entry.get(
			"faction", Constants.Faction.REBEL_ALLIANCE)
	if instance.is_destroyed():
		lbl.add_theme_color_override("font_color", DESTROYED_COLOR)
		lbl.text = lbl.text.replace("⬤", "✕").replace("◆", "✕")
	elif instance.activated_this_round:
		lbl.add_theme_color_override("font_color", ACTIVATED_COLOR)
	else:
		lbl.add_theme_color_override("font_color",
				_faction_active_color(faction))


## Clears all entries and sections.
func _clear() -> void:
	_entries.clear()
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rebel_section = null
	_imperial_section = null
	_rebel_header = null
	_imperial_header = null


## Returns the faction display name.
func _faction_name(faction: Constants.Faction) -> String:
	match faction:
		Constants.Faction.REBEL_ALLIANCE:
			return "Rebel Alliance"
		Constants.Faction.GALACTIC_EMPIRE:
			return "Galactic Empire"
		_:
			return "Unknown"


## Returns the active (unactivated) colour for the given faction.
func _faction_active_color(faction: Constants.Faction) -> Color:
	match faction:
		Constants.Faction.REBEL_ALLIANCE:
			return REBEL_COLOR
		Constants.Faction.GALACTIC_EMPIRE:
			return IMPERIAL_COLOR
		_:
			return REBEL_COLOR


## Returns the panel position when fully expanded (left edge at x=0).
func _expanded_pos() -> Vector2:
	return Vector2(0.0, _viewport_size.y - size.y - BOTTOM_MARGIN)


## Returns the panel position when collapsed (only PEEK_WIDTH visible).
func _collapsed_pos() -> Vector2:
	return Vector2(-(size.x - PEEK_WIDTH),
			_viewport_size.y - size.y - BOTTOM_MARGIN)


## Instantly snaps to the collapsed position (used on first populate).
func _snap_to_collapsed() -> void:
	_expanded = false
	position = _collapsed_pos()


## Toggles between expanded and collapsed with a slide animation.
func _toggle_expanded() -> void:
	_expanded = not _expanded
	var target: Vector2 = _expanded_pos() if _expanded \
			else _collapsed_pos()
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_property(self, "position", target,
			SLIDE_DURATION).set_trans(
			Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------


## Called when a ship node is activated (token).
func _on_ship_activated(ship_node: Node) -> void:
	# Find the ShipInstance from the token.
	if ship_node.has_method("get_ship_instance"):
		var inst: Variant = ship_node.get_ship_instance()
		if inst:
			_update_entry(inst)


## Called when an activation ends (any unit).
func _on_activation_ended() -> void:
	refresh()


## Called when a ship is destroyed.
func _on_ship_destroyed(ship_node: Node) -> void:
	if ship_node.has_method("get_ship_instance"):
		var inst: Variant = ship_node.get_ship_instance()
		if inst:
			_update_entry(inst)


## Called when a squadron is activated.
func _on_squadron_activated(sq_node: Node) -> void:
	if sq_node.has_method("get_squadron_instance"):
		var inst: Variant = sq_node.get_squadron_instance()
		if inst:
			_update_entry(inst)


## Called when a squadron is destroyed.
func _on_squadron_destroyed(sq_node: Node) -> void:
	if sq_node.has_method("get_squadron_instance"):
		var inst: Variant = sq_node.get_squadron_instance()
		if inst:
			_update_entry(inst)


## Show/hide based on game phase.
func _on_phase_changed(new_phase: Constants.GamePhase) -> void:
	match new_phase:
		Constants.GamePhase.SHIP, \
		Constants.GamePhase.SQUADRON:
			visible = true
			refresh()
		_:
			visible = false

## DefenseMirrorPanel
##
## Read-only mirror panel shown on the **defender's** peer in network mode
## while the authoritative attack flow is at
## [code]InteractionStep.ATTACK_DEFENSE_TOKENS[/code].
##
## In network mode the attacker's peer drives the existing [AttackSimPanel]
## (owned by [TargetSelector]/[AttackExecutor]).  The defender's peer has
## no [AttackExecutor] running its UI, so it currently sees nothing while
## being asked to act — see open topic NW-006 / I6b followups.
##
## Slice A of I6b-3 introduces a minimal **read-only** view fed entirely
## from [GameState.interaction_flow.payload] via [UIProjector].  It shows
## the defender ship name, hit zone, modified damage, and the count of
## currently locked tokens.  No buttons, no interactivity — interactivity
## arrives in slices C–E.
##
## Hot-seat is **not** affected: the attacker peer does not project a
## defense modal kind for itself, and hot-seat keeps using the existing
## [AttackSimPanel] defense section.
##
## Plan: [code]docs/refactoring_phase_i_plan.md[/code] §I6b followups,
## slice A.
class_name DefenseMirrorPanel
extends PanelContainer


## Panel width cap — matches AttackSimPanel proportions.
const MODAL_MAX_WIDTH: float = 400.0
## Panel width fraction of viewport width.
const MODAL_WIDTH_FRACTION: float = 0.38

## Hull-zone index → display name mapping (mirrors AttackExecutor).
const _ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}


# ---------------------------------------------------------------------------
# UI references
# ---------------------------------------------------------------------------

var _title_label: Label = null
var _info_label: Label = null
var _damage_label: Label = null
var _tokens_label: Label = null

## Logger for this system.
var _log: GameLogger = GameLogger.new("DefenseMirrorPanel")


func _init() -> void:
	visible = false
	_apply_anchor_position()


## Opens the read-only mirror with the supplied display data.
##
## [param ship_name] — display name of the defender ship (resolved by
##     [code]game_board[/code] from [code]payload.defender_ship_index[/code]).
## [param zone] — hit zone enum value
##     ([enum Constants.HullZone]); raw int from the payload is accepted.
## [param modified_damage] — final damage after attack-side modification.
## [param locked_count] — number of accuracy-locked defense tokens.
func open(ship_name: String, zone: int, modified_damage: int,
		locked_count: int) -> void:
	if _title_label == null:
		_build_ui()
	var zone_text: String = _ZONE_NAMES.get(zone, "?") as String
	_title_label.text = "Incoming attack — %s" % ship_name
	_info_label.text = "Hit zone: %s" % zone_text
	_damage_label.text = "Modified damage: %d" % modified_damage
	if locked_count > 0:
		_tokens_label.text = "Accuracy-locked tokens: %d" % locked_count
		_tokens_label.visible = true
	else:
		_tokens_label.visible = false
	visible = true
	_log.info("Defense mirror opened: ship=%s, zone=%s, dmg=%d, locked=%d." % [
			ship_name, zone_text, modified_damage, locked_count])


## Closes / hides the panel.  Idempotent.
func close() -> void:
	if not visible:
		return
	visible = false
	_log.info("Defense mirror closed.")


## Returns true if the panel is currently displayed.
func is_open() -> bool:
	return visible


## Repositions the panel for a new viewport size.  Called by
## [UIPanelManager.register_resizable].
func centre_on_screen(_vp_size: Vector2) -> void:
	_apply_anchor_position()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------


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


func _build_ui() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style())
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	_title_label = UIStyleHelper.create_title_label("",
			UIStyleHelper.GOLD_TITLE)
	vbox.add_child(_title_label)
	_info_label = UIStyleHelper.create_section_label("",
			UIStyleHelper.FONT_BODY, UIStyleHelper.BODY_TEXT)
	vbox.add_child(_info_label)
	_damage_label = UIStyleHelper.create_section_label("",
			UIStyleHelper.FONT_BODY, UIStyleHelper.BLUE_ACCENT)
	vbox.add_child(_damage_label)
	_tokens_label = UIStyleHelper.create_section_label("",
			UIStyleHelper.FONT_SUBTITLE, UIStyleHelper.DIMMED_HINT)
	_tokens_label.visible = false
	vbox.add_child(_tokens_label)
	vbox.add_child(UIStyleHelper.create_dismiss_hint(
			"Waiting for your defense actions…"))

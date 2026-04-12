## TargetingListController
##
## Owns the targeting list modal lifecycle: building data from board tokens,
## opening/closing the [TargetingListModal], and consuming Escape to dismiss.
##
## Extracted from game_board.gd as part of refactoring phase F5c.
## Requirements: TL-UI-001, TL-UI-003, TL-UI-004, TL-LIST-001–010.
class_name TargetingListController
extends Node

# ---------------------------------------------------------------------------
# Dependencies (injected via initialize)
# ---------------------------------------------------------------------------

## Callable returning Array[ShipToken] — board's ship token accessor.
var _get_ship_tokens: Callable

## Callable returning Array[SquadronToken] — board's squadron token accessor.
var _get_squad_tokens: Callable

## ManeuverToolController — needed for ghost ship info.
var _maneuver_tool_controller: ManeuverToolController = null

## UIPanelManager — owns the lazy targeting_list_modal reference.
var _panel_mgr: UIPanelManager = null

## The parent node to which the CanvasLayer is added.
var _layer_parent: Node = null

## Logger instance.
var _log: GameLogger = GameLogger.new("TargetingListController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores references needed by the controller.
## [param get_ship_tokens_fn] — callable returning Array[ShipToken].
## [param get_squad_tokens_fn] — callable returning Array[SquadronToken].
## [param maneuver_ctrl] — ManeuverToolController for ghost info.
## [param panel_mgr] — UIPanelManager for modal storage.
## [param parent] — Node to attach the CanvasLayer to.
func initialize(
		get_ship_tokens_fn: Callable,
		get_squad_tokens_fn: Callable,
		maneuver_ctrl: ManeuverToolController,
		panel_mgr: UIPanelManager,
		parent: Node) -> void:
	_get_ship_tokens = get_ship_tokens_fn
	_get_squad_tokens = get_squad_tokens_fn
	_maneuver_tool_controller = maneuver_ctrl
	_panel_mgr = panel_mgr
	_layer_parent = parent


## Handles the "Targeting List" button press.
## Toggle behaviour: if the modal is visible, close it. Otherwise open it.
## Requirements: TL-UI-001, TL-UI-003, TL-UI-004.
func on_targeting_list_requested() -> void:
	if _panel_mgr.targeting_list_modal and _panel_mgr.targeting_list_modal.visible:
		dismiss()
		return
	_show_targeting_list()


## Closes the targeting list modal.
func dismiss() -> void:
	if _panel_mgr.targeting_list_modal:
		_panel_mgr.targeting_list_modal.close()
	_log.info("Targeting list dismissed.")


## Checks if an Escape key press should dismiss the targeting list.
## Returns true if the event was consumed.
func handle_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _panel_mgr.targeting_list_modal and _panel_mgr.targeting_list_modal.visible:
		dismiss()
		get_viewport().set_input_as_handled()
		return true
	return false


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds the targeting data and opens the modal.
func _show_targeting_list() -> void:
	dismiss()
	var ships_info: Array = _collect_ship_infos()
	var squads_info: Array = _collect_squad_infos()
	var active_player: int = GameManager.get_active_player()
	var ghost: TargetingListBuilder.ShipInfo = _collect_ghost_info()
	var build_result: TargetingListBuilder.BuildResult = TargetingListBuilder.build(
			ships_info, squads_info, active_player, ghost)
	# Create the modal on a CanvasLayer so it's always on top.
	if _panel_mgr.targeting_list_modal == null:
		_panel_mgr.targeting_list_modal = TargetingListModal.new()
		# Add on a CanvasLayer for screen-space display.
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "TargetingListLayer"
		layer.layer = 90
		_layer_parent.add_child(layer)
		layer.add_child(_panel_mgr.targeting_list_modal)
	_panel_mgr.targeting_list_modal.show_results(build_result)
	_log.info("Targeting list opened.")


## Collects ShipInfo data from all ship tokens on the board.
func _collect_ship_infos() -> Array:
	var infos: Array = []
	var tokens: Array[ShipToken] = _get_ship_tokens.call()
	for token: ShipToken in tokens:
		var info: TargetingListBuilder.ShipInfo = TargetingListBuilder.ShipInfo.new()
		var inst: ShipInstance = token.get_ship_instance()
		info.ship_name = token.get_ship_data().ship_name if token.get_ship_data() else "Unknown"
		info.data_key = inst.data_key if inst else ""
		info.owner_player = inst.owner_player if inst else 0
		info.pos = token.global_position
		info.rot = token.global_rotation
		info.half_w = token.get_half_width()
		info.half_l = token.get_half_length()
		info.arc_pts = token.get_firing_arc_world_points()
		info.los_pts = token.get_los_origins_world()
		var sd: ShipData = token.get_ship_data()
		if sd:
			info.battery_armament = sd.battery_armament
			info.anti_squadron_armament = sd.anti_squadron_armament
		infos.append(info)
	return infos


## Collects SquadInfo data from all squadron tokens on the board.
## Requirements: TL-LIST-010.
func _collect_squad_infos() -> Array:
	var infos: Array = []
	var tokens: Array[SquadronToken] = _get_squad_tokens.call()
	for token: SquadronToken in tokens:
		var info: TargetingListBuilder.SquadInfo = TargetingListBuilder.SquadInfo.new()
		var inst: SquadronInstance = token.get_squadron_instance()
		if inst and inst.squadron_data:
			info.squad_name = inst.squadron_data.squadron_name
			info.battery_armament = inst.squadron_data.battery_armament
			info.anti_squadron_armament = inst.squadron_data.anti_squadron_armament
		else:
			info.squad_name = "Squadron"
		info.owner_player = inst.owner_player if inst else 0
		info.pos = token.global_position
		info.radius = token.get_radius_px()
		infos.append(info)
	return infos


## Collects ghost ship info from the maneuver tool if active.
## Returns null if no ghost is present.
## Requirements: TL-LIST-004.
func _collect_ghost_info() -> TargetingListBuilder.ShipInfo:
	var mt_scene: ManeuverToolScene = _maneuver_tool_controller.get_scene()
	if mt_scene == null:
		return null
	if not mt_scene.has_method("get_ghost_transform"):
		return null
	var ghost_data: Dictionary = mt_scene.get_ghost_transform()
	if ghost_data.is_empty():
		return null
	var info: TargetingListBuilder.ShipInfo = TargetingListBuilder.ShipInfo.new()
	info.ship_name = ghost_data.get("ship_name", "Ghost")
	info.data_key = ghost_data.get("data_key", "")
	info.owner_player = ghost_data.get("owner_player", 0)
	info.pos = ghost_data.get("position", Vector2.ZERO)
	info.rot = ghost_data.get("rotation", 0.0)
	info.half_w = ghost_data.get("half_w", 0.0)
	info.half_l = ghost_data.get("half_l", 0.0)
	info.arc_pts = ghost_data.get("arc_pts", {})
	info.los_pts = ghost_data.get("los_pts", {})
	info.battery_armament = ghost_data.get("battery_armament", {})
	info.anti_squadron_armament = ghost_data.get("anti_squadron_armament", {})
	return info

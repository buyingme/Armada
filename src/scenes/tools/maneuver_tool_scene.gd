## ManeuverToolScene
##
## Visual representation of the maneuver tool on the game board.
## Renders segment sprites at positions computed by ManeuverToolState,
## handles joint click interaction, and displays a ghost ship preview.
##
## Rules Reference: RRG "Maneuver Tool" p.10, "Ship Movement" p.16–17.
## Requirements: MT-G-001–008, MT-U-005, AC-04–09.
class_name ManeuverToolScene
extends Node2D


## Click detection radius around joint positions (in game pixels).
const JOINT_CLICK_RADIUS: float = 24.0

## Click detection radius for speed +/- buttons (in game pixels).
const SPEED_BUTTON_RADIUS: float = 12.0

## Speed button circle display radius (in game pixels).
const SPEED_BUTTON_DRAW_RADIUS: float = 10.0

## Ghost ship preview transparency.
const GHOST_ALPHA: float = 0.35

## Font size for the speed label on the ghost, in source-PNG pixels.
## Matches ShipToken.LABEL_FONT_SIZE_PNG_PX.
const LABEL_FONT_SIZE_PNG_PX: int = 13

## Logger.
var _log: GameLogger = GameLogger.new("ManeuverTool")

## Core model tracking joint angles and speed.
var _state: ManeuverToolState = null

## Reference to the attached ship token.
var _ship_token: ShipToken = null

## Which side the tool is attached to ("left" or "right").
var _side: String = "left"

## Sprites for each of the 5 segments.
var _segment_sprites: Array[Sprite2D] = []

## Ghost ship preview sprite.
var _ghost_sprite: Sprite2D = null

## Node2D overlay that draws speed +/- buttons on the end segment.
## Requirements: MT-S-001, AC-19, AC-25.
var _speed_button_layer: Node2D = null

## Node2D overlay that draws the speed label on the ghost.
## Requirements: MT-S-005, AC-23.
var _ghost_label_layer: Node2D = null

## Bold font for the speed label on the ghost and button labels.
var _label_font: Font = null

## Cached textures per segment type.
var _textures: Dictionary = {}

## Whether the tool is in activation mode (real speed changes) vs simulation.
## Requirements: NAV-008, FLOW-003, AC-5b-04.
var _activation_mode: bool = false

## The ShipActivationState driving Navigate budgets in activation mode.
## Only set when _activation_mode is true.
var _activation_state: ShipActivationState = null

## Node2D overlay that draws yaw bonus "N" badges on joints.
## Requirements: NAV-006, EXE-005.
var _yaw_badge_layer: Node2D = null

## Range overlay shown on the ghost preview (null when hidden).
var _ghost_range_overlay: RangeOverlayScene = null

## Whether the ghost range overlay is currently requested.
var _ghost_overlay_active: bool = false

## Whether the ghost is showing a collision (BLOCKED) indicator.
var _ghost_blocked: bool = false

## Label node for the "BLOCKED" collision indicator on the ghost.
var _blocked_label: Label = null


## Initialises the tool for a specific ship token.
## [param ship_token] — the ship to attach the tool to.
## [param side] — "left" or "right" side of the ship base.
func setup(ship_token: ShipToken, side: String = "left") -> void:
	_ship_token = ship_token
	_side = side
	_state = ManeuverToolState.new()
	var instance: ShipInstance = ship_token.get_ship_instance()
	var speed: int = 2
	var nav_chart: Array = [[2], [1, 2]]
	var max_speed: int = 2
	var ship_size: Constants.ShipSize = ship_token.get_ship_size()
	if instance:
		speed = instance.current_speed
		var ship_data: ShipData = ship_token.get_ship_data()
		if ship_data:
			nav_chart = ship_data.navigation_chart.duplicate(true)
			max_speed = ship_data.max_speed
	# MANEUVER_DETERMINE_YAWS hook — Thrust Control Malfunction reduces
	# last joint yaw by 1 at each speed level.
	# Rules Reference: "Thrust Control Malfunction" card text.
	nav_chart = _apply_yaw_hooks(nav_chart, instance)
	_state.setup(speed, nav_chart, ship_size, max_speed)
	_load_textures()
	_create_sprites()
	_update_visual()


## Enables activation mode — speed +/- buttons write to ShipInstance,
## gated by Navigate command availability via the activation state.
## [param activation_state] — the ShipActivationState for this activation.
## Requirements: NAV-008, FLOW-003, AC-5b-04.
func set_activation_mode(activation_state: ShipActivationState) -> void:
	_activation_mode = true
	_activation_state = activation_state
	# Apply yaw bonus from activation state, if any.
	var yaw_joint: int = activation_state.get_yaw_bonus_joint()
	if yaw_joint >= 0:
		_state.set_yaw_bonus_joint(yaw_joint)
	_update_visual()
	_log.info("Activation mode enabled.")


## Returns true if the tool is in activation mode.
func is_activation_mode() -> bool:
	return _activation_mode


## Returns the ManeuverToolState for external queries.
func get_state() -> ManeuverToolState:
	return _state


## Refreshes the visual representation after state changes.
func refresh() -> void:
	_update_visual()


## Applies the MANEUVER_DETERMINE_YAWS hook to each speed level of
## the nav chart, allowing damage cards (e.g. Thrust Control Malfunction)
## to reduce yaw values.  Returns the (possibly modified) nav chart.
## Rules Reference: "Thrust Control Malfunction" card text.
func _apply_yaw_hooks(nav_chart: Array,
		ship: ShipInstance) -> Array:
	if ship == null:
		return nav_chart
	var registry: EffectRegistry = null
	if GameManager.current_game_state:
		registry = GameManager.current_game_state.effect_registry
	if registry == null:
		return nav_chart
	for speed_idx: int in range(nav_chart.size()):
		var yaw_arr: Array = (nav_chart[speed_idx] as Array).duplicate()
		var ctx: EffectContext = EffectContext.new()
		ctx.set_meta_value("ship", ship)
		ctx.set_meta_value("yaw_values", yaw_arr)
		ctx = registry.resolve_hook(&"MANEUVER_DETERMINE_YAWS", ctx)
		nav_chart[speed_idx] = ctx.get_meta_value("yaw_values", yaw_arr)
	return nav_chart



# ------------------------------------------------------------------
# Texture and sprite creation
# ------------------------------------------------------------------

## Loads segment textures from the tools/ asset folder.
func _load_textures() -> void:
	var cfg: Dictionary = GameScale.maneuver_tool_config
	for key: String in ["root", "segment", "segment_end"]:
		var section: Dictionary = cfg.get(key, {})
		var img: String = String(section.get("image", ""))
		if not img.is_empty():
			_textures[key] = AssetLoader.load_texture("tools/", img)


## Creates all child nodes: segment sprites, ghost preview, overlay layers.
func _create_sprites() -> void:
	_create_segment_sprites()
	_create_ghost_sprite()
	_create_overlay_layers()
	_create_blocked_label()
	var sf: SystemFont = SystemFont.new()
	sf.font_weight = 700
	_label_font = sf


## Creates the 5 segment sprites used to render the maneuver tool pieces.
func _create_segment_sprites() -> void:
	for i: int in range(ManeuverToolState.TOTAL_SEGMENTS):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = false
		sprite.name = "Segment_%d" % i
		sprite.visible = false
		add_child(sprite)
		_segment_sprites.append(sprite)


## Creates the semi-transparent ghost ship preview sprite.
func _create_ghost_sprite() -> void:
	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.name = "GhostPreview"
	_ghost_sprite.modulate = Color(1, 1, 1, GHOST_ALPHA)
	_ghost_sprite.visible = false
	add_child(_ghost_sprite)


## Creates Node2D draw layers for speed buttons, ghost label, and yaw badges.
func _create_overlay_layers() -> void:
	_speed_button_layer = Node2D.new()
	_speed_button_layer.name = "SpeedButtons"
	_speed_button_layer.draw.connect(_on_speed_button_draw)
	_speed_button_layer.visible = false
	add_child(_speed_button_layer)
	_ghost_label_layer = Node2D.new()
	_ghost_label_layer.name = "GhostSpeedLabel"
	_ghost_label_layer.draw.connect(_on_ghost_label_draw)
	_ghost_label_layer.visible = false
	add_child(_ghost_label_layer)
	_yaw_badge_layer = Node2D.new()
	_yaw_badge_layer.name = "YawBadges"
	_yaw_badge_layer.draw.connect(_on_yaw_badge_draw)
	_yaw_badge_layer.visible = false
	add_child(_yaw_badge_layer)


## Creates the "BLOCKED" collision indicator label on the ghost.
func _create_blocked_label() -> void:
	_blocked_label = Label.new()
	_blocked_label.name = "BlockedLabel"
	_blocked_label.text = "BLOCKED"
	_blocked_label.add_theme_font_size_override("font_size", 18)
	_blocked_label.add_theme_color_override("font_color",
			Color(1.0, 0.2, 0.2))
	_blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blocked_label.visible = false
	add_child(_blocked_label)


# ------------------------------------------------------------------
# Visual update
# ------------------------------------------------------------------

## Returns the universal sprite scale for all maneuver tool segment PNGs.
## All types share a single factor so contact widths and proportions match.
## Requirements: MT-D-003, AC-09.
func _get_sprite_scale(_seg_type: String) -> float:
	return ManeuverToolState.get_tool_scale()


## Computes the tool's attachment point on the ship in world space.
## Uses the computed alignment side so root and ghost switch together.
## Returns {"position": Vector2, "rotation": float}.
## Rules Reference: MT-G-005, MT-A-004.
func _compute_attachment() -> Dictionary:
	var side: String = "left"
	if _state:
		side = _state.compute_ghost_side()
	var half_w: float = _ship_token.get_half_width()
	var half_l: float = _ship_token.get_half_length()
	var ship_pos: Vector2 = _ship_token.global_position
	var ship_rot: float = _ship_token.global_rotation
	var root_cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"root", {})
	var entry: Vector2 = root_cfg.get("entry_intersection", Vector2.ZERO)
	var seg_scale: float = _get_sprite_scale("root")
	var contact: Vector2 = root_cfg.get("contact_right", Vector2.ZERO)
	var corner_local: Vector2 = Vector2(-half_w, -half_l)
	if side == "right":
		contact = root_cfg.get("contact_left", Vector2.ZERO)
		corner_local = Vector2(half_w, -half_l)
	var offset: Vector2 = (entry - contact) * seg_scale
	var entry_local: Vector2 = corner_local + offset
	var entry_world: Vector2 = ship_pos + entry_local.rotated(ship_rot)
	return {"position": entry_world, "rotation": ship_rot}


## Updates all segment sprites and the ghost preview.
func _update_visual() -> void:
	if _state == null or _ship_token == null:
		return
	var attach: Dictionary = _compute_attachment()
	var start_pos: Vector2 = attach["position"]
	var start_rot: float = attach["rotation"]
	var chain: Dictionary = _state.compute_segment_transforms(
			start_pos, start_rot)
	var segs: Array = chain["segments"]
	var joints: Array = chain["joints"]
	_log_chain(segs, joints)
	_update_segments(segs)
	_update_speed_buttons(segs)
	_update_ghost(start_pos, start_rot)
	_update_yaw_badges(joints)


## Logs the full transform chain for debugging segment alignment.
func _log_chain(segs: Array, joints: Array) -> void:
	var s: float = ManeuverToolState.get_tool_scale()
	_log.info("=== Maneuver Tool Chain (speed %d, scale %.4f) ===" % [
			_state.get_speed(), s])
	var active: int = _state.get_active_segment_count()
	for i: int in range(active):
		_log_segment(i, segs[i] as Transform2D, s)
	for j: int in range(joints.size()):
		var jpos: Vector2 = joints[j] as Vector2
		_log.info("  Joint %d  world=(%.1f, %.1f)" % [
				j, jpos.x, jpos.y])
	_log.info("=== End Chain ===")


## Logs a single segment's entry/exit/contact world positions.
func _log_segment(i: int, xform: Transform2D, s: float) -> void:
	var seg_type: String = _state.get_segment_type(i)
	var cfg: Dictionary = GameScale.maneuver_tool_config.get(
			seg_type, {})
	var entry_px: Vector2 = cfg.get("entry_intersection",
			Vector2.ZERO) as Vector2
	var exit_px: Vector2 = cfg.get("exit_intersection",
			Vector2.ZERO) as Vector2
	var rot: float = xform.get_rotation()
	var entry_world: Vector2 = xform.origin
	_log.info(
			"  [%d] %s  entry_px=%s  exit_px=%s" % [
			i, seg_type, entry_px, exit_px])
	_log.info(
			"       entry_world=(%.1f, %.1f)  rot=%.2f°" % [
			entry_world.x, entry_world.y, rad_to_deg(rot)])
	_log_segment_exit(cfg, entry_px, entry_world, rot, s)
	_log_segment_contacts(cfg, entry_px, entry_world, rot, s)


## Logs the exit-world position for a segment, if available.
func _log_segment_exit(cfg: Dictionary, entry_px: Vector2,
		entry_world: Vector2, rot: float, s: float) -> void:
	if not cfg.has("exit_intersection"):
		_log.info("       (no exit — end segment)")
		return
	var exit_px: Vector2 = cfg["exit_intersection"] as Vector2
	var local_exit: Vector2 = (exit_px - entry_px) * s
	var exit_world: Vector2 = entry_world + local_exit.rotated(rot)
	_log.info(
			"       exit_world=(%.1f, %.1f)" % [
			exit_world.x, exit_world.y])


## Logs the contact-left and contact-right world positions for a segment.
func _log_segment_contacts(cfg: Dictionary, entry_px: Vector2,
		entry_world: Vector2, rot: float, s: float) -> void:
	var cl: Vector2 = cfg.get("contact_left",
			Vector2.ZERO) as Vector2
	var cr: Vector2 = cfg.get("contact_right",
			Vector2.ZERO) as Vector2
	var cl_world: Vector2 = entry_world + (
			(cl - entry_px) * s).rotated(rot)
	var cr_world: Vector2 = entry_world + (
			(cr - entry_px) * s).rotated(rot)
	_log.info(
			"       contact_L_world=(%.1f, %.1f)  contact_R_world=(%.1f, %.1f)" % [
			cl_world.x, cl_world.y, cr_world.x, cr_world.y])


## Positions and configures each active segment sprite.
func _update_segments(segs: Array) -> void:
	var active: int = _state.get_active_segment_count()
	for i: int in range(ManeuverToolState.TOTAL_SEGMENTS):
		var sprite: Sprite2D = _segment_sprites[i]
		if i >= active or i >= segs.size():
			sprite.visible = false
			continue
		sprite.visible = true
		var seg_type: String = _state.get_segment_type(i)
		var tex: Texture2D = _textures.get(seg_type) as Texture2D
		if tex:
			sprite.texture = tex
		var cfg: Dictionary = GameScale.maneuver_tool_config.get(
				seg_type, {})
		var entry_px: Vector2 = cfg.get("entry_intersection",
				Vector2.ZERO) as Vector2
		sprite.offset = - entry_px
		var s: float = _get_sprite_scale(seg_type)
		sprite.scale = Vector2(s, s)
		var xform: Transform2D = segs[i] as Transform2D
		sprite.global_position = xform.origin
		sprite.global_rotation = xform.get_rotation()


## Updates the ghost ship preview at the projected final position.
## Uses compute_ghost_side() for dynamic alignment (MT-A-002).
## Requirements: MT-G-007, MT-A-001–004, AC-07, AC-17, AC-18.
func _update_ghost(start_pos: Vector2, start_rot: float) -> void:
	if _ghost_sprite == null or _state.get_simulated_speed() <= 0:
		if _ghost_sprite:
			_ghost_sprite.visible = false
		return
	var ghost_side: String = _state.compute_ghost_side()
	var final_xform: Transform2D = _state.compute_final_transform(
			start_pos, start_rot, ghost_side)
	_ghost_sprite.global_position = final_xform.origin
	_ghost_sprite.global_rotation = final_xform.get_rotation()
	_ghost_sprite.visible = true
	_setup_ghost_texture()
	_update_ghost_speed_label(final_xform)
	_update_blocked_label(final_xform)
	# Keep the ghost range overlay in sync when joints change.
	if _ghost_overlay_active:
		_create_or_update_ghost_overlay()


## Loads and scales the ghost ship texture to match the ship token.
func _setup_ghost_texture() -> void:
	if _ghost_sprite.texture != null:
		return
	var data_key: String = _ship_token.get_meta("data_key", "")
	if data_key.is_empty():
		return
	var tex: Texture2D = AssetLoader.load_texture(
			"ships/", data_key + "_token.png")
	if tex == null:
		return
	_ghost_sprite.texture = tex
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
	_ghost_sprite.scale = GameScale.get_base_sprite_scale(
			_ship_token.get_ship_size(), tex_size)


## Sets whether the ghost shows a "BLOCKED" collision indicator.
## Call from the board when overlap detection determines the ghost position
## would collide with another ship.
## [param blocked] — true to show, false to hide.
## Requirements: UI-010.
func set_collision_preview(blocked: bool) -> void:
	_ghost_blocked = blocked
	if _blocked_label:
		_blocked_label.visible = blocked and _ghost_sprite \
				and _ghost_sprite.visible


## Positions the "BLOCKED" label above the ghost sprite centre.
func _update_blocked_label(final_xform: Transform2D) -> void:
	if _blocked_label == null:
		return
	_blocked_label.visible = _ghost_blocked
	if not _ghost_blocked:
		return
	_blocked_label.global_position = final_xform.origin + Vector2(
			-40.0, -60.0)
	_blocked_label.global_rotation = 0.0


## Toggles the range overlay on the ghost preview.
## Returns true if the overlay is now visible, false if dismissed.
func toggle_ghost_range_overlay() -> bool:
	_ghost_overlay_active = not _ghost_overlay_active
	if _ghost_overlay_active:
		_create_or_update_ghost_overlay()
	else:
		_remove_ghost_overlay()
	return _ghost_overlay_active


## Dismisses the ghost range overlay if active.
func dismiss_ghost_range_overlay() -> void:
	_ghost_overlay_active = false
	_remove_ghost_overlay()


## Returns true if the ghost range overlay is currently visible.
func has_ghost_range_overlay() -> bool:
	return _ghost_range_overlay != null


## Returns a Dictionary describing the ghost's current transform and ship data.
## Used by the targeting list to compute hypothetical targeting from the ghost
## position.  Returns an empty dictionary if no ghost is visible.
## Requirements: TL-LIST-004.
func get_ghost_transform() -> Dictionary:
	if _ghost_sprite == null or not _ghost_sprite.visible:
		return {}
	var ship_data: ShipData = _ship_token.get_ship_data()
	if ship_data == null:
		return {}
	var inst: ShipInstance = _ship_token.get_ship_instance()
	var ghost_pos: Vector2 = _ghost_sprite.global_position
	var ghost_rot: float = _ghost_sprite.global_rotation
	var arc_pts: Dictionary = _map_points_to_world(
			ship_data.firing_arc_boundaries, ghost_pos, ghost_rot, false)
	var los_pts: Dictionary = _map_points_to_world(
			ship_data.line_of_sight_origins, ghost_pos, ghost_rot, true)
	return {
		"ship_name": ship_data.ship_name,
		"data_key": _ship_token.get_meta("data_key", ""),
		"owner_player": inst.owner_player if inst else 0,
		"position": ghost_pos,
		"rotation": ghost_rot,
		"half_w": _ship_token.get_half_width(),
		"half_l": _ship_token.get_half_length(),
		"arc_pts": arc_pts,
		"los_pts": los_pts,
		"battery_armament": ship_data.battery_armament,
		"anti_squadron_armament": ship_data.anti_squadron_armament,
	}


## Maps a dictionary of png-space coordinates to world-space positions
## relative to the ghost sprite.  If [param skip_underscore] is true,
## keys starting with "_" are omitted.
func _map_points_to_world(source: Dictionary, ghost_pos: Vector2,
		ghost_rot: float, skip_underscore: bool) -> Dictionary:
	var result: Dictionary = {}
	if source.is_empty() or _ghost_sprite.texture == null:
		return result
	var tex_w: float = float(_ghost_sprite.texture.get_width())
	var tex_h: float = float(_ghost_sprite.texture.get_height())
	var sp_scale: Vector2 = _ghost_sprite.scale
	for key: String in source:
		if skip_underscore and key.begins_with("_"):
			continue
		var png_coord: Vector2 = source[key]
		var local: Vector2 = (png_coord - Vector2(tex_w, tex_h) * 0.5) * sp_scale
		result[key] = ghost_pos + local.rotated(ghost_rot)
	return result


## Creates or repositions the range overlay on the ghost preview.
func _create_or_update_ghost_overlay() -> void:
	if _ghost_sprite == null or not _ghost_sprite.visible:
		_remove_ghost_overlay()
		return
	var ship_data: ShipData = _ship_token.get_ship_data()
	if ship_data == null:
		return
	if _ghost_range_overlay == null:
		_ghost_range_overlay = RangeOverlayScene.new()
		_ghost_range_overlay.name = "GhostRangeOverlay"
		add_child(_ghost_range_overlay)
		# Move to index 0 so it renders below the ghost sprite and tool.
		move_child(_ghost_range_overlay, 0)
		_ghost_range_overlay.setup_at_transform(
				ship_data, _ghost_sprite.global_position,
				_ghost_sprite.global_rotation)
	else:
		_ghost_range_overlay.update_transform(
				_ghost_sprite.global_position,
				_ghost_sprite.global_rotation)


## Removes the ghost range overlay node.
func _remove_ghost_overlay() -> void:
	if _ghost_range_overlay != null:
		_ghost_range_overlay.queue_free()
		_ghost_range_overlay = null


# ------------------------------------------------------------------
# Input handling — joint clicks
# ------------------------------------------------------------------

## Handles mouse clicks near joint positions and speed buttons.
## Left click = port (left) on joints, or speed +/- on buttons.
## Right click = starboard (right) on joints.
## Rules Reference: MT-G-003, MT-S-001, AC-05, AC-20.
func _input(event: InputEvent) -> void:
	if not visible or _state == null:
		return
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if _try_speed_button_click():
			get_viewport().set_input_as_handled()
			return
	if mb.button_index != MOUSE_BUTTON_LEFT \
			and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_try_joint_click(mb)


## Checks if a click is near an active joint and applies it.
func _try_joint_click(mb: InputEventMouseButton) -> void:
	var click_pos: Vector2 = get_global_mouse_position()
	var attach: Dictionary = _compute_attachment()
	var chain: Dictionary = _state.compute_segment_transforms(
			attach["position"], attach["rotation"])
	var joints: Array = chain["joints"]
	for j: int in range(joints.size()):
		var joint_pos: Vector2 = joints[j] as Vector2
		if click_pos.distance_to(joint_pos) > JOINT_CLICK_RADIUS:
			continue
		var applied: bool = false
		if mb.button_index == MOUSE_BUTTON_LEFT:
			applied = _state.click_joint_left(j)
		else:
			applied = _state.click_joint_right(j)
		# If the click was rejected, try applying/moving the yaw bonus.
		if not applied:
			applied = _try_apply_yaw_bonus_for(j, mb.button_index)
		if applied:
			_update_visual()
			_log.info("Joint %d clicked %s → %d" % [
					j, "left" if mb.button_index == MOUSE_BUTTON_LEFT \
					else "right", _state.get_joint_clicks()[j]])
		get_viewport().set_input_as_handled()
		return


## Attempts to apply or move the Navigate yaw bonus to [param joint_index]
## so that a previously rejected click can succeed.
## Returns true if the bonus was applied and the click went through.
## Rules Reference: "Navigate" — increase 1 yaw value by 1 at any joint.
## Requirements: NAV-002, NAV-006, EXE-005.
func _try_apply_yaw_bonus_for(joint_index: int,
		button: MouseButton) -> bool:
	if not _activation_mode or _activation_state == null:
		return false
	var current_bonus: int = _activation_state.get_yaw_bonus_joint()
	# Bonus is already on this joint — the click genuinely exceeds limits.
	if current_bonus == joint_index:
		return false
	# If the bonus is on a different joint, remove it first.
	if current_bonus >= 0:
		_activation_state.remove_yaw_bonus()
		_state.clear_yaw_bonus()
		_state.clamp_joints()
	# Apply the bonus to the requested joint.
	if not _activation_state.has_yaw_bonus():
		return false
	_activation_state.apply_yaw_bonus(joint_index)
	_state.set_yaw_bonus_joint(joint_index)
	# Retry the click with the increased limit.
	if button == MOUSE_BUTTON_LEFT:
		return _state.click_joint_left(joint_index)
	return _state.click_joint_right(joint_index)


# ------------------------------------------------------------------
# Speed buttons on end segment  (Phase 5a+)
# ------------------------------------------------------------------


## Positions the speed button overlay at the end segment's transform.
## Requirements: MT-S-001, AC-19.
func _update_speed_buttons(segs: Array) -> void:
	if _speed_button_layer == null:
		return
	var active: int = _state.get_active_segment_count()
	if active < 2 or segs.size() < active:
		_speed_button_layer.visible = false
		return
	var last_idx: int = active - 1
	var last_seg: Transform2D = segs[last_idx] as Transform2D
	_speed_button_layer.global_position = last_seg.origin
	_speed_button_layer.global_rotation = last_seg.get_rotation()
	_speed_button_layer.visible = true
	_speed_button_layer.queue_redraw()


## Draws the speed +/- circle buttons on the end segment overlay.
## Requirements: MT-S-001, AC-19, AC-25.
func _on_speed_button_draw() -> void:
	if _state == null or _label_font == null:
		return
	var seg_cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"segment_end", {})
	var entry_px: Vector2 = seg_cfg.get("entry_intersection",
			Vector2.ZERO) as Vector2
	var s: float = _get_sprite_scale("segment_end")
	var btn_minus_px: Vector2 = seg_cfg.get(
			"speed_reduction_button", Vector2.ZERO) as Vector2
	var btn_plus_px: Vector2 = seg_cfg.get(
			"speed_increase_button", Vector2.ZERO) as Vector2
	var minus_local: Vector2 = (btn_minus_px - entry_px) * s
	var plus_local: Vector2 = (btn_plus_px - entry_px) * s
	var font_size: int = maxi(1, roundi(16.0 * s))
	_draw_circle_button(minus_local, "-", font_size)
	_draw_circle_button(plus_local, "+", font_size)


## Draws a single circular button with centred [param label] text at
## [param local_pos] on the speed button layer.
func _draw_circle_button(local_pos: Vector2, label: String,
		font_size: int) -> void:
	var bg_color: Color = Color(0.15, 0.15, 0.18, 0.85)
	_speed_button_layer.draw_circle(local_pos,
			SPEED_BUTTON_DRAW_RADIUS, bg_color)
	var ascent: float = _label_font.get_ascent(font_size)
	var descent: float = _label_font.get_descent(font_size)
	var text_h: float = ascent + descent
	var text_size: Vector2 = _label_font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_speed_button_layer.draw_string(_label_font, Vector2(
			local_pos.x - text_size.x * 0.5,
			local_pos.y + text_h * 0.5 - descent),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Returns the world positions of the speed − and + buttons.
## Returns {"minus": Vector2, "plus": Vector2}.
func _get_speed_button_world_positions() -> Dictionary:
	if _speed_button_layer == null or not _speed_button_layer.visible:
		return {}
	var seg_cfg: Dictionary = GameScale.maneuver_tool_config.get(
			"segment_end", {})
	var entry_px: Vector2 = seg_cfg.get("entry_intersection",
			Vector2.ZERO) as Vector2
	var s: float = _get_sprite_scale("segment_end")
	var rot: float = _speed_button_layer.global_rotation
	var origin: Vector2 = _speed_button_layer.global_position
	var btn_minus_px: Vector2 = seg_cfg.get(
			"speed_reduction_button", Vector2.ZERO) as Vector2
	var btn_plus_px: Vector2 = seg_cfg.get(
			"speed_increase_button", Vector2.ZERO) as Vector2
	var minus_world: Vector2 = origin + (
			(btn_minus_px - entry_px) * s).rotated(rot)
	var plus_world: Vector2 = origin + (
			(btn_plus_px - entry_px) * s).rotated(rot)
	return {"minus": minus_world, "plus": plus_world}


## Checks if the mouse click hits a speed button and applies it.
## In activation mode, speed changes write to ShipInstance via Navigate budget.
## In simulation mode, speed changes are preview-only (simulated_speed).
## Returns true if a speed button was clicked.
## Requirements: MT-S-001, NAV-008, AC-20, AC-21, AC-5b-04–07.
func _try_speed_button_click() -> bool:
	var positions: Dictionary = _get_speed_button_world_positions()
	if positions.is_empty():
		return false
	var click_pos: Vector2 = get_global_mouse_position()
	if click_pos.distance_to(positions["minus"]) <= SPEED_BUTTON_RADIUS:
		_handle_speed_change(-1)
		return true
	if click_pos.distance_to(positions["plus"]) <= SPEED_BUTTON_RADIUS:
		_handle_speed_change(1)
		return true
	return false


## Applies a speed change, using either activation or simulation mode.
## [param delta] — +1 or -1.
func _handle_speed_change(delta: int) -> void:
	if _activation_mode and _activation_state:
		var applied: bool = _activation_state.apply_speed_change(delta)
		if applied:
			# Submit command to mutate ShipInstance.current_speed.
			var ship: ShipInstance = _activation_state.get_ship()
			var target_speed: int = ship.current_speed + delta
			var result: Dictionary = GameManager.submit_set_speed(
					ship, target_speed)
			if result.is_empty():
				_log.info("SetSpeedCommand rejected for speed %d." %
						target_speed)
				return
			# Sync the tool state to the new actual speed.
			_state.set_simulated_speed(ship.current_speed)
			_update_visual()
			_log.info("Activation speed %+d → %d" % [
					delta, ship.current_speed])
			EventBus.ship_speed_changed.emit(ship, ship.current_speed)
			EventBus.navigate_token_spend_preview.emit(
					ship,
					_activation_state.is_using_token_for_speed())
	else:
		var old_speed: int = _state.get_simulated_speed()
		_state.set_simulated_speed(old_speed + delta)
		if _state.get_simulated_speed() != old_speed:
			_update_visual()
			_log.info("Speed %s → %d" % [
					"+" if delta > 0 else "−",
					_state.get_simulated_speed()])


# ------------------------------------------------------------------
# Ghost speed label  (Phase 5a+)
# ------------------------------------------------------------------


## Positions the ghost speed label overlay at the ghost's transform
## and triggers a redraw.
## Requirements: MT-S-005, AC-23.
func _update_ghost_speed_label(ghost_xform: Transform2D) -> void:
	if _ghost_label_layer == null:
		return
	_ghost_label_layer.global_position = ghost_xform.origin
	_ghost_label_layer.global_rotation = ghost_xform.get_rotation()
	_ghost_label_layer.visible = true
	_ghost_label_layer.queue_redraw()


## Draws the simulated speed value on the ghost at the ship's speed
## label position. Mirrors ShipToken._draw_label_on() for consistency.
## Requirements: MT-S-005, AC-23.
func _on_ghost_label_draw() -> void:
	if _state == null or _label_font == null or _ship_token == null:
		return
	var label_info: Dictionary = _compute_ghost_label_layout()
	if label_info.is_empty():
		return
	var text: String = str(_state.get_simulated_speed())
	var font_size: int = label_info["font_size"] as int
	var local_pos: Vector2 = label_info["local_pos"] as Vector2
	var text_size: Vector2 = _label_font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var draw_pos: Vector2 = Vector2(
			local_pos.x - text_size.x * 0.5,
			local_pos.y + text_size.y * 0.25)
	_ghost_label_layer.draw_string(_label_font, draw_pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Computes the local draw position and font size for the ghost speed label.
## Returns an empty Dictionary if the required data is unavailable.
func _compute_ghost_label_layout() -> Dictionary:
	var ship_data: ShipData = _ship_token.get_ship_data()
	if ship_data == null:
		return {}
	var offsets: Dictionary = ship_data.token_label_offsets
	if not offsets.has("speed"):
		return {}
	var base_offset: Vector2 = offsets["speed"] as Vector2
	var base_region: Vector2 = GameScale.get_base_region(
			_state.get_ship_size())
	if base_region.x <= 0.0 or base_region.y <= 0.0:
		return {}
	var tex_size: Vector2 = Vector2.ZERO
	if _ghost_sprite and _ghost_sprite.texture:
		tex_size = Vector2(_ghost_sprite.texture.get_width(),
				_ghost_sprite.texture.get_height())
	var sprite_scale: Vector2 = GameScale.get_base_sprite_scale(
			_state.get_ship_size(), tex_size)
	var from_center: Vector2 = base_offset - base_region * 0.5
	var local_pos: Vector2 = from_center * sprite_scale
	var avg_scale: float = (sprite_scale.x + sprite_scale.y) * 0.5
	var font_size: int = maxi(1, roundi(
			float(LABEL_FONT_SIZE_PNG_PX) * avg_scale))
	return {"local_pos": local_pos, "font_size": font_size}


# ------------------------------------------------------------------
# Yaw bonus badges  (Phase 5b)
# ------------------------------------------------------------------

## Cached joint positions for yaw badge drawing.
var _cached_joints: Array = []


## Positions the yaw badge layer and triggers a redraw.
## Requirements: NAV-006, EXE-005.
func _update_yaw_badges(joints: Array) -> void:
	_cached_joints = joints
	if _yaw_badge_layer == null:
		return
	if _state == null or _state.get_yaw_bonus_joint() < 0:
		_yaw_badge_layer.visible = false
		return
	_yaw_badge_layer.global_position = Vector2.ZERO
	_yaw_badge_layer.global_rotation = 0.0
	_yaw_badge_layer.visible = true
	_yaw_badge_layer.queue_redraw()


## Draws an "N" badge at the joint with the yaw bonus.
## Requirements: NAV-006, EXE-005.
func _on_yaw_badge_draw() -> void:
	if _state == null or _label_font == null:
		return
	var bonus_joint: int = _state.get_yaw_bonus_joint()
	if bonus_joint < 0 or bonus_joint >= _cached_joints.size():
		return
	var joint_pos: Vector2 = _cached_joints[bonus_joint] as Vector2
	var badge_radius: float = 8.0
	var bg_color: Color = Color(0.2, 0.6, 0.9, 0.85)
	_yaw_badge_layer.draw_circle(joint_pos, badge_radius, bg_color)
	var font_size: int = 10
	var text: String = "N"
	var text_size: Vector2 = _label_font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var draw_pos: Vector2 = Vector2(
			joint_pos.x - text_size.x * 0.5,
			joint_pos.y + text_size.y * 0.25)
	_yaw_badge_layer.draw_string(_label_font, draw_pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

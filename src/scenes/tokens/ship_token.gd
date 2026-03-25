## ShipToken
##
## Visual representation of a ship on the game board.
## Displays the ship token PNG centred on the physical base, draws the base
## rectangle outline with hull zone dividing lines, and renders shield / hull /
## speed values at positions defined in the ship JSON. Hosts the optional
## firing arc overlay.
##
## Defense tokens are **not** shown on the board token; they are displayed
## next to the ship card in a side panel (UI-016, UI-017).
##
## Usage:
##   var token: ShipToken = SHIP_TOKEN_SCENE.instantiate()
##   token.setup(placement)
##   token_container.add_child(token)
##
## Rules Reference: "Ship Tokens", p.3; GC-002, GC-003; UI-011.
class_name ShipToken
extends Node2D


## Emitted when this token is clicked.
signal token_clicked(token: ShipToken)

## Colour for the base outline (Rebel = orange-gold, Imperial = grey-green).
const REBEL_COLOUR: Color = Color(0.95, 0.72, 0.25)
const IMPERIAL_COLOUR: Color = Color(0.50, 0.75, 0.55)
## Hull zone dividing line colour.
const ZONE_LINE_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.45)
## Base outline width in pixels.
const OUTLINE_WIDTH_PX: float = 2.0
## Font size for value labels in source-PNG pixels.
const LABEL_FONT_SIZE_PNG_PX: int = 13

## Placement data assigned during [method setup].
var _placement: TokenPlacement = null
## Half-width of the ship base in pixels (from GameScale).
var _half_w: float = 0.0
## Half-length of the ship base in pixels (from GameScale).
var _half_l: float = 0.0
## Sprite node that displays the ship token PNG.
var _sprite: Sprite2D = null
## Arc overlay child node.
var _arc_overlay: FiringArcOverlay = null
## Ship data loaded from JSON (holds shields, hull, speed, label offsets).
var _ship_data: ShipData = null
## Runtime game-state instance (optional, set via [method bind_instance]).
## When set, labels read current values from here instead of from _ship_data.
var _ship_instance: ShipInstance = null
## Sprite scale factor (maps source-PNG base-region pixels → local game pixels).
var _sprite_scale: Vector2 = Vector2.ONE
## Base region size in source-PNG pixels (measured bounding box of the base).
var _base_region: Vector2 = Vector2.ZERO
## Bold font used for value labels.
var _label_font: Font = null
## Child node that draws value labels on top of the sprite.
var _label_layer: Node2D = null
## Node2D showing the composite revealed command dial behind the ship base
## (Phase 4c). Contains a background Sprite2D + icon Sprite2D.
## Requirements: UI-025.
var _revealed_dial_sprite: Node2D = null

## Map from [Constants.CommandType] enum to icon filename for board display.
const CMD_BOARD_ICON_FILES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}


## Configures this token from a [TokenPlacement].
## Call once after adding to the scene tree.
## [param placement] must represent a ship (is_ship == true).
func setup(placement: TokenPlacement) -> void:
	_placement = placement
	set_meta("data_key", placement.data_key)
	var base_size: Vector2 = GameScale.get_base_size(placement.ship_size)
	_half_w = base_size.x * 0.5
	_half_l = base_size.y * 0.5
	position = placement.get_pixel_position(GameScale.play_area_side_px)
	rotation = placement.rotation_rad
	_ship_data = AssetLoader.load_ship_data(placement.data_key)
	_label_font = _create_bold_font()
	_create_sprite(placement)
	_create_label_layer()
	_create_arc_overlay()
	queue_redraw()


## Binds a [ShipInstance] to this token so labels show current game values.
## Connects EventBus signals to trigger label redraws when state changes.
## [param instance] — the runtime ship state object.
func bind_instance(instance: ShipInstance) -> void:
	_ship_instance = instance
	EventBus.ship_shields_changed.connect(_on_state_changed)
	EventBus.ship_hull_changed.connect(_on_state_changed_hull)
	EventBus.ship_speed_changed.connect(_on_state_changed_speed)
	_refresh_labels()


## Returns the bound [ShipInstance] or null.
func get_ship_instance() -> ShipInstance:
	return _ship_instance


## Toggles the firing arc overlay visibility.
## Rules Reference: UI-011 — player may show/hide firing arcs.
func toggle_arc_overlay() -> void:
	if _arc_overlay:
		_arc_overlay.visible = not _arc_overlay.visible


## Returns true if the firing arc overlay is currently visible.
func is_arc_overlay_visible() -> bool:
	return _arc_overlay != null and _arc_overlay.visible


## Returns the faction this token belongs to.
func get_faction() -> Constants.Faction:
	if _placement:
		return _placement.faction
	return Constants.Faction.REBEL_ALLIANCE


## Returns the ship size enum value for this token.
func get_ship_size() -> Constants.ShipSize:
	if _placement:
		return _placement.ship_size
	return Constants.ShipSize.SMALL


## Returns the half-width of the base in pixels.
func get_half_width() -> float:
	return _half_w


## Returns the half-length of the base in pixels.
func get_half_length() -> float:
	return _half_l


## Returns the loaded [ShipData] or null if not yet set up.
func get_ship_data() -> ShipData:
	return _ship_data


## Converts a pixel coordinate in full-PNG space (from top-left) to world space.
## Used for firing_arc_boundaries and line_of_sight_origins.
func png_to_world(png_coord: Vector2) -> Vector2:
	return to_global(png_to_local(png_coord))


## Converts a pixel coordinate in full-PNG space (from top-left) to local space.
## The sprite is centred on the node origin, so local = (px - centre) * scale.
func png_to_local(png_coord: Vector2) -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return Vector2.ZERO
	var tex_w: float = float(_sprite.texture.get_width())
	var tex_h: float = float(_sprite.texture.get_height())
	return (png_coord - Vector2(tex_w, tex_h) * 0.5) * _sprite_scale


## Returns firing arc boundary points converted to world space.
## Result keys match ShipData.firing_arc_boundaries (e.g. "inner_point_front_left").
## Returns an empty dictionary if the ship data has no boundary data.
func get_firing_arc_world_points() -> Dictionary:
	if not _ship_data or _ship_data.firing_arc_boundaries.is_empty():
		return {}
	var result: Dictionary = {}
	for key: String in _ship_data.firing_arc_boundaries:
		result[key] = png_to_world(_ship_data.firing_arc_boundaries[key])
	return result


## Returns line-of-sight origins converted to world space.
## Result keys: "FRONT", "LEFT", "RIGHT", "REAR".
func get_los_origins_world() -> Dictionary:
	if not _ship_data or _ship_data.line_of_sight_origins.is_empty():
		return {}
	var result: Dictionary = {}
	for key: String in _ship_data.line_of_sight_origins:
		result[key] = png_to_world(_ship_data.line_of_sight_origins[key])
	return result


## Returns true if [param world_pos] falls inside the base rectangle.
func is_point_in_base(world_pos: Vector2) -> bool:
	return _is_point_in_base(world_pos)


## Determines which hull zone a world-space point falls into.
## Returns Constants.HullZone.FRONT / LEFT / RIGHT / REAR based on the
## ship's local-space third-division geometry.
## Returns -1 if the point is outside the base.
## Rules Reference: "Hull Zones", p.4.
## Requirements: AS-SEL-001.
func get_hull_zone_at(world_pos: Vector2) -> int:
	if not _is_point_in_base(world_pos):
		return -1
	var local_pos: Vector2 = to_local(world_pos)
	var third: float = _half_l * 2.0 / 3.0
	var front_y: float = -_half_l + third
	var rear_y: float = _half_l - third
	if local_pos.y < front_y:
		return Constants.HullZone.FRONT
	if local_pos.y > rear_y:
		return Constants.HullZone.REAR
	if local_pos.x < 0.0:
		return Constants.HullZone.LEFT
	return Constants.HullZone.RIGHT


## Shows the revealed command dial behind the ship base on the board.
## The dial is a composite: hidden dial background + command icon on top.
## Positioned 1 cm (in game space) aft of the base edge.
## Requirements: UI-025.
## [param command_type] — the Constants.CommandType value of the revealed dial.
func show_revealed_dial(command_type: int) -> void:
	hide_revealed_dial()
	var icon_filename: String = CMD_BOARD_ICON_FILES.get(command_type, "")
	if icon_filename.is_empty():
		return
	var bg_tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", "cmd_dial_hidden.png")
	var icon_tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", icon_filename)
	if bg_tex == null:
		return

	## Container Node2D holds background sprite + icon sprite.
	_revealed_dial_sprite = Node2D.new()

	## Scale the dial to game-scale size (~30 mm physical diameter).
	## Rules Reference: physical command dial is ~30 mm.
	## ruler_length_px / 305 mm per foot × 30 mm ≈ 70.8 px at 720px ruler.
	var dial_game_px: float = GameScale.ruler_length_px * (30.0 / 305.0)

	# Background sprite (facedown dial graphic).
	var bg_sprite: Sprite2D = Sprite2D.new()
	bg_sprite.texture = bg_tex
	var bg_max: float = maxf(float(bg_tex.get_width()),
			float(bg_tex.get_height()))
	if bg_max > 0.0:
		var s: float = dial_game_px / bg_max
		bg_sprite.scale = Vector2(s, s)
	_revealed_dial_sprite.add_child(bg_sprite)

	# Command icon sprite on top (slightly smaller to fit inside dial).
	if icon_tex != null:
		var icon_sprite: Sprite2D = Sprite2D.new()
		icon_sprite.texture = icon_tex
		var icon_max: float = maxf(float(icon_tex.get_width()),
				float(icon_tex.get_height()))
		var icon_dial_px: float = dial_game_px * 0.75
		if icon_max > 0.0:
			var si: float = icon_dial_px / icon_max
			icon_sprite.scale = Vector2(si, si)
		_revealed_dial_sprite.add_child(icon_sprite)

	## Position: 1 cm behind the aft edge of the base.
	## Aft direction = positive Y in local space (nose points toward -Y).
	var one_cm_px: float = GameScale.ruler_length_px / 30.48
	var dial_half_h: float = dial_game_px * 0.5
	_revealed_dial_sprite.position = Vector2(
			0.0, _half_l + one_cm_px + dial_half_h)

	add_child(_revealed_dial_sprite)


## Hides and removes the revealed command dial sprite from the board.
## Requirements: UI-026.
func hide_revealed_dial() -> void:
	if _revealed_dial_sprite != null:
		remove_child(_revealed_dial_sprite)
		_revealed_dial_sprite.queue_free()
		_revealed_dial_sprite = null


## Returns the local-space position for a label offset key,
## or Vector2.ZERO if the key is missing or data is not loaded.
func get_label_local_position(key: String) -> Vector2:
	if not _ship_data or _ship_data.token_label_offsets.is_empty():
		return Vector2.ZERO
	if not _ship_data.token_label_offsets.has(key):
		return Vector2.ZERO
	if _base_region.x <= 0.0 or _base_region.y <= 0.0:
		return Vector2.ZERO
	return _base_offset_to_local(_ship_data.token_label_offsets[key])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _is_point_in_base(get_global_mouse_position()):
				token_clicked.emit(self )
				get_viewport().set_input_as_handled()


func _draw() -> void:
	if _half_w <= 0.0 or _half_l <= 0.0:
		return
	var colour: Color = _get_faction_colour()
	_draw_base_outline(colour)
	_draw_zone_lines()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Selects the outline colour based on the token's faction.
func _get_faction_colour() -> Color:
	if _placement and _placement.faction == Constants.Faction.GALACTIC_EMPIRE:
		return IMPERIAL_COLOUR
	return REBEL_COLOUR


## Draws the rectangular base outline in local space.
func _draw_base_outline(colour: Color) -> void:
	var rect: Rect2 = Rect2(-_half_w, -_half_l, _half_w * 2.0, _half_l * 2.0)
	draw_rect(rect, colour, false, OUTLINE_WIDTH_PX)


## Draws hull zone dividing lines (one horizontal pair bounding the middle third).
## Rules Reference: "Hull Zones", p.4; GC-003.
func _draw_zone_lines() -> void:
	var third: float = _half_l * 2.0 / 3.0
	var front_y: float = - _half_l + third # boundary between FRONT and sides
	var rear_y: float = _half_l - third # boundary between sides and REAR
	draw_line(Vector2(-_half_w, front_y), Vector2(_half_w, front_y),
			ZONE_LINE_COLOUR, 1.0)
	draw_line(Vector2(-_half_w, rear_y), Vector2(_half_w, rear_y),
			ZONE_LINE_COLOUR, 1.0)
	draw_line(Vector2(0.0, front_y), Vector2(0.0, rear_y),
			ZONE_LINE_COLOUR, 1.0)


## Creates and adds the Sprite2D child that shows the token PNG.
func _create_sprite(placement: TokenPlacement) -> void:
	_sprite = Sprite2D.new()
	var subfolder: String = "ships/" if placement.is_ship else "squadrons/"
	var filename: String = placement.data_key + "_token.png"
	var tex: Texture2D = AssetLoader.load_texture(subfolder, filename)
	if tex:
		_sprite.texture = tex
		_scale_sprite_to_base(tex)
	add_child(_sprite)


## Scales [_sprite] so the base region in the source PNG aligns with the
## game-scale bounding box. Uses per-axis scaling via [GameScale].
## Also caches the base region and sprite scale for label positioning.
func _scale_sprite_to_base(tex: Texture2D) -> void:
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	if _placement:
		_sprite.scale = GameScale.get_base_sprite_scale(
				_placement.ship_size, tex_size)
		_base_region = GameScale.get_base_region(_placement.ship_size)
	else:
		var target: Vector2 = Vector2(_half_w * 2.0, _half_l * 2.0)
		var sf: float = minf(target.x / tex_size.x, target.y / tex_size.y)
		_sprite.scale = Vector2(sf, sf)
	_sprite_scale = _sprite.scale


## Creates the FiringArcOverlay child (initially hidden).
## Passes the real arc boundary data from ship JSON so the overlay
## draws the actual zone geometry instead of hardcoded 45° wedges.
func _create_arc_overlay() -> void:
	_arc_overlay = FiringArcOverlay.new()
	_arc_overlay.visible = false
	add_child(_arc_overlay)
	_update_arc_overlay_boundaries()


## Feeds the local-space arc boundary points from the ship JSON to the overlay.
func _update_arc_overlay_boundaries() -> void:
	if not _arc_overlay or not _ship_data:
		return
	if _ship_data.firing_arc_boundaries.is_empty():
		return
	var local_pts: Dictionary = {}
	for key: String in _ship_data.firing_arc_boundaries:
		local_pts[key] = png_to_local(_ship_data.firing_arc_boundaries[key])
	_arc_overlay.set_arc_boundaries(local_pts)


## Returns true if [world_pos] falls inside the base rectangle (local space check).
func _is_point_in_base(world_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(world_pos)
	return (absf(local_pos.x) <= _half_w) and (absf(local_pos.y) <= _half_l)


## Creates a bold SystemFont for value labels.
func _create_bold_font() -> Font:
	var sf: SystemFont = SystemFont.new()
	sf.font_weight = 700
	return sf


## Creates a child Node2D that draws the value labels on top of the sprite.
## Added as a child after the sprite so it renders in front.
func _create_label_layer() -> void:
	if not _ship_data or _ship_data.token_label_offsets.is_empty():
		return
	if _base_region.x <= 0.0 or _base_region.y <= 0.0:
		return
	_label_layer = Node2D.new()
	_label_layer.draw.connect(_on_label_layer_draw)
	add_child(_label_layer)
	_label_layer.queue_redraw()


## Called when the label layer child needs to redraw.
## Draws shield, hull, and speed values at positions defined in the ship JSON.
## When a [ShipInstance] is bound, reads current values from it; otherwise
## falls back to the static template values.
## Rules Reference: shield / hull / speed values shown on ship token artwork.
func _on_label_layer_draw() -> void:
	if not _ship_data or not _label_font:
		return
	var font_size: int = _get_scaled_font_size()
	var offsets: Dictionary = _ship_data.token_label_offsets
	if _ship_instance:
		_draw_label_on(offsets, "shield_front",
				str(_ship_instance.current_shields.get("FRONT", 0)), font_size)
		_draw_label_on(offsets, "shield_left",
				str(_ship_instance.current_shields.get("LEFT", 0)), font_size)
		_draw_label_on(offsets, "shield_right",
				str(_ship_instance.current_shields.get("RIGHT", 0)), font_size)
		_draw_label_on(offsets, "shield_rear",
				str(_ship_instance.current_shields.get("REAR", 0)), font_size)
		_draw_label_on(offsets, "hull",
				str(_ship_instance.current_hull), font_size)
		_draw_label_on(offsets, "speed",
				str(_ship_instance.current_speed), font_size)
	else:
		_draw_label_on(offsets, "shield_front",
				str(int(_ship_data.shields.get("FRONT", 0))), font_size)
		_draw_label_on(offsets, "shield_left",
				str(int(_ship_data.shields.get("LEFT", 0))), font_size)
		_draw_label_on(offsets, "shield_right",
				str(int(_ship_data.shields.get("RIGHT", 0))), font_size)
		_draw_label_on(offsets, "shield_rear",
				str(int(_ship_data.shields.get("REAR", 0))), font_size)
		_draw_label_on(offsets, "hull",
				str(int(_ship_data.hull)), font_size)
		_draw_label_on(offsets, "speed",
				str(int(_ship_data.max_speed)), font_size)


## Draws a single centred value label at the specified offset key.
## Drawing happens on the [_label_layer] child node's canvas.
func _draw_label_on(offsets: Dictionary, key: String, text: String,
		font_size: int) -> void:
	if not offsets.has(key):
		return
	var local_pos: Vector2 = _base_offset_to_local(offsets[key])
	var text_size: Vector2 = _label_font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var draw_pos: Vector2 = Vector2(
			local_pos.x - text_size.x * 0.5,
			local_pos.y + text_size.y * 0.25)
	_label_layer.draw_string(_label_font, draw_pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Converts a base-bounding-box pixel offset to local Node2D space.
## [param base_offset] — pixel position measured from the top-left corner
## of the base region (not the full PNG), in source-PNG pixel scale.
## The sprite_scale maps base-region pixels to game pixels,
## so: local = (base_offset - base_region_center) * sprite_scale.
func _base_offset_to_local(base_offset: Vector2) -> Vector2:
	var from_center: Vector2 = base_offset - _base_region * 0.5
	return from_center * _sprite_scale


## Returns the font size in local pixels, scaled from PNG pixel space.
func _get_scaled_font_size() -> int:
	var avg_scale: float = (_sprite_scale.x + _sprite_scale.y) * 0.5
	return maxi(1, roundi(float(LABEL_FONT_SIZE_PNG_PX) * avg_scale))


## Triggers a redraw of the label layer to update displayed values.
func _refresh_labels() -> void:
	if _label_layer:
		_label_layer.queue_redraw()


## EventBus callback: shields changed on a ship instance.
## Only redraws if the signal refers to *this* token's instance.
func _on_state_changed(inst: RefCounted, _zone: String,
		_new_value: int) -> void:
	if inst == _ship_instance:
		_refresh_labels()


## EventBus callback: hull changed on a ship instance.
func _on_state_changed_hull(inst: RefCounted, _new_hull: int) -> void:
	if inst == _ship_instance:
		_refresh_labels()


## EventBus callback: speed changed on a ship instance.
func _on_state_changed_speed(inst: RefCounted, _new_speed: int) -> void:
	if inst == _ship_instance:
		_refresh_labels()

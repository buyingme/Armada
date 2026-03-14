## ShipToken
##
## Visual representation of a ship on the game board.
## Displays the ship token PNG centred on the physical base, draws the base
## rectangle outline with hull zone dividing lines, and hosts the optional
## firing arc overlay.
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
	_create_sprite(placement)
	_create_arc_overlay()
	queue_redraw()


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


func _input(event: InputEvent) -> void:
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
func _scale_sprite_to_base(tex: Texture2D) -> void:
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	if _placement:
		_sprite.scale = GameScale.get_base_sprite_scale(
				_placement.ship_size, tex_size)
	else:
		var target: Vector2 = Vector2(_half_w * 2.0, _half_l * 2.0)
		var sf: float = minf(target.x / tex_size.x, target.y / tex_size.y)
		_sprite.scale = Vector2(sf, sf)


## Creates the FiringArcOverlay child (initially hidden).
func _create_arc_overlay() -> void:
	_arc_overlay = FiringArcOverlay.new()
	_arc_overlay.visible = false
	add_child(_arc_overlay)


## Returns true if [world_pos] falls inside the base rectangle (local space check).
func _is_point_in_base(world_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(world_pos)
	return (absf(local_pos.x) <= _half_w) and (absf(local_pos.y) <= _half_l)

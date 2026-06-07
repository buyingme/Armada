## SetupObstacleToken
##
## Visual obstacle token used during setup-package placement. It renders the
## obstacle catalog art and supports click selection for repositioning before
## round one begins.
class_name SetupObstacleToken
extends Node2D


## Emitted when the token is clicked.
signal token_clicked(token: SetupObstacleToken)

const OUTLINE_COLOUR: Color = Color(0.72, 0.88, 1.0, 0.7)
const OUTLINE_WIDTH_PX: float = 2.0
const TARGET_SIZE_FACTOR: float = 1.35

var _data_key: String = ""
var _half_extents: Vector2 = Vector2.ONE * 24.0
var _click_enabled: bool = true
var _outline_colour: Color = OUTLINE_COLOUR
var _sprite: Sprite2D = null


## Configures the token from normalized setup data.
func setup(data_key: String,
		pos_x: float, pos_y: float,
		rotation_deg: float = 0.0) -> void:
	_data_key = data_key.strip_edges()
	position = Vector2(pos_x, pos_y) * GameScale.play_area_size_px
	rotation = deg_to_rad(rotation_deg)
	if _sprite == null:
		_create_sprite()
	_update_art()
	reset_outline_colour()
	queue_redraw()


## Returns the obstacle catalog key represented by this token.
func get_data_key() -> String:
	return _data_key


## Returns the token half extents in pixels for drag clamping.
func get_half_extents() -> Vector2:
	return _half_extents


## Enables or disables click handling for this token.
func set_click_enabled(enabled: bool) -> void:
	_click_enabled = enabled


## Sets the preview outline colour used by setup legality feedback.
func set_outline_colour(colour: Color) -> void:
	_outline_colour = colour
	queue_redraw()


## Restores the default outline colour.
func reset_outline_colour() -> void:
	set_outline_colour(OUTLINE_COLOUR)


## Applies a new normalized transform to the token.
func set_normalized_transform(pos_x: float,
		pos_y: float, rotation_deg: float) -> void:
	position = Vector2(pos_x, pos_y) * GameScale.play_area_size_px
	rotation = deg_to_rad(rotation_deg)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _click_enabled or not visible or not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _contains_point(to_local(get_global_mouse_position())):
		token_clicked.emit(self )
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(-_half_extents, _half_extents * 2.0),
			_outline_colour, false, OUTLINE_WIDTH_PX)


func _create_sprite() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)


func _update_art() -> void:
	var obstacle_data: ObstacleData = AssetLoader.load_obstacle_data(_data_key)
	if obstacle_data == null:
		return
	var texture: Texture2D = AssetLoader.load_texture(
			"obstacles/", obstacle_data.token_image)
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.scale = _sprite_scale(texture)
	_update_half_extents(texture)


func _sprite_scale(texture: Texture2D) -> Vector2:
	var longest_side: float = maxf(texture.get_width(), texture.get_height())
	if longest_side <= 0.0:
		return Vector2.ONE
	var target_size: float = maxf(
			GameScale.squadron_base_diameter_px * TARGET_SIZE_FACTOR, 56.0)
	return Vector2.ONE * (target_size / longest_side)


func _update_half_extents(texture: Texture2D) -> void:
	var size: Vector2 = Vector2(texture.get_width(), texture.get_height()) * _sprite.scale
	_half_extents = size * 0.5


func _contains_point(local_pos: Vector2) -> bool:
	return absf(local_pos.x) <= _half_extents.x \
			and absf(local_pos.y) <= _half_extents.y

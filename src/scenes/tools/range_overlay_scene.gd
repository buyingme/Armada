## RangeOverlayScene
##
## Displays a pre-rendered range-band overlay image for one ship.
## Added as a child of the token container on the game board, positioned
## at the ship's world coordinates with the ship's rotation.  Renders
## above the map but below all tokens (first child in container).
##
## The overlay PNG contains baked arc boundary lines and range bands
## (close / medium / long).  It is stored at the same pixel density as the
## range ruler, so Sprite2D scale = 1.0 maps overlay pixels to game pixels.
##
## Requirements: RO-003, RO-006, RO-DATA-03.
## Rules Reference: "Firing Arcs", p.3; "Range and Distance", p.10.
class_name RangeOverlayScene
extends Node2D


## The Sprite2D that displays the overlay texture.
var _sprite: Sprite2D = null


## Initialises the overlay for [param token].
## Loads the overlay texture, positions/rotates to match the ship, and
## sets z-order below all tokens.
func setup(token: ShipToken) -> void:
	var ship_data: ShipData = token.get_ship_data()
	if ship_data == null:
		return
	setup_at_transform(ship_data, token.global_position, token.global_rotation)


## Initialises the overlay from explicit ship data, position, and rotation.
## Use this when there is no ShipToken (e.g. the maneuver tool ghost).
func setup_at_transform(ship_data: ShipData, pos: Vector2,
		rot: float) -> void:
	if ship_data.range_overlay_image.is_empty():
		return

	var tex: Texture2D = AssetLoader.load_texture(
			"ships/", ship_data.range_overlay_image)
	if tex == null:
		return

	# Position the overlay at the given world position and rotation.
	position = pos
	rotation = rot

	# Create the sprite centred on the origin.
	# The overlay PNG has the ship centre at image centre (origin_px),
	# and Sprite2D.centered = true aligns image centre to node origin.
	# If origin_px deviates from image centre, apply an offset.
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true

	var img_center: Vector2 = Vector2(
			float(tex.get_width()) * 0.5,
			float(tex.get_height()) * 0.5)
	var origin: Vector2 = ship_data.range_overlay_origin_px
	var delta: Vector2 = img_center - origin
	if delta.length() > 0.5:
		_sprite.offset = delta

	add_child(_sprite)


## Updates the overlay position and rotation (e.g. when the ghost moves).
func update_transform(pos: Vector2, rot: float) -> void:
	position = pos
	rotation = rot

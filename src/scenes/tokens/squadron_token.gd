## SquadronToken
##
## Visual representation of a squadron on the game board.
## Displays the squadron token PNG centred on the circular base and draws the
## circular base outline.
##
## Usage:
##   var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate()
##   token.setup(placement)
##   token_container.add_child(token)
##
## Rules Reference: "Squadron Tokens", p.3; GC-004; SM-001/003.
class_name SquadronToken
extends Node2D


## Emitted when this token is clicked.
signal token_clicked(token: SquadronToken)

## Number of segments used to draw the circular base outline.
const CIRCLE_SEGMENTS: int = 32
## Base outline width in pixels.
const OUTLINE_WIDTH_PX: float = 2.0
## Rebel squadron colour.
const REBEL_COLOUR: Color = Color(0.95, 0.72, 0.25)
## Imperial squadron colour.
const IMPERIAL_COLOUR: Color = Color(0.50, 0.75, 0.55)

## Placement data set during [method setup].
var _placement: TokenPlacement = null
## Base radius in pixels (half of squadron_base_diameter_px from GameScale).
var _radius_px: float = 0.0
## The sprite showing the squadron token PNG.
var _sprite: Sprite2D = null


## Configures this token from a [TokenPlacement].
## Call once after adding to the scene tree.
## [param placement] must represent a squadron (is_ship == false).
func setup(placement: TokenPlacement) -> void:
	_placement = placement
	set_meta("data_key", placement.data_key)
	_radius_px = GameScale.squadron_base_diameter_px * 0.5
	position = placement.get_pixel_position(GameScale.play_area_side_px)
	rotation = placement.rotation_rad
	_create_sprite(placement)
	queue_redraw()


## Returns the faction this squadron belongs to.
func get_faction() -> Constants.Faction:
	if _placement:
		return _placement.faction
	return Constants.Faction.REBEL_ALLIANCE


## Returns the base radius in pixels.
func get_radius_px() -> float:
	return _radius_px


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = to_local(get_global_mouse_position())
			if local_pos.length() <= _radius_px:
				token_clicked.emit(self )
				get_viewport().set_input_as_handled()


func _draw() -> void:
	if _radius_px <= 0.0:
		return
	var colour: Color = _get_faction_colour()
	draw_arc(Vector2.ZERO, _radius_px, 0.0, TAU, CIRCLE_SEGMENTS, colour,
			OUTLINE_WIDTH_PX, true)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns the outline colour for this squadron's faction.
func _get_faction_colour() -> Color:
	if _placement and _placement.faction == Constants.Faction.GALACTIC_EMPIRE:
		return IMPERIAL_COLOUR
	return REBEL_COLOUR


## Creates the Sprite2D child for the squadron token image.
func _create_sprite(placement: TokenPlacement) -> void:
	_sprite = Sprite2D.new()
	var filename: String = placement.data_key + "_token.png"
	var tex: Texture2D = AssetLoader.load_texture("squadrons/", filename)
	if tex:
		_sprite.texture = tex
		_scale_sprite_to_base(tex)
	add_child(_sprite)


## Scales [_sprite] so the base region in the source PNG aligns with the
## game-scale circular base. Uses [GameScale] measured base region.
func _scale_sprite_to_base(tex: Texture2D) -> void:
	var tex_size: Vector2 = Vector2(float(tex.get_width()), float(tex.get_height()))
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	_sprite.scale = GameScale.get_squadron_sprite_scale(tex_size)

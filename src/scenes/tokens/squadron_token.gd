## SquadronToken
##
## Visual representation of a squadron on the game board.
## Composites two sprite layers: a shared circular base (squad_base.png) and
## the per-squadron token artwork drawn on top. The base determines the
## game-scale circle used for range measurement and overlap detection.
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
## Shared base image filename.
const BASE_IMAGE_FILENAME: String = "squad_base.png"

## Placement data set during [method setup].
var _placement: TokenPlacement = null
## Base radius in pixels (half of squadron_base_diameter_px from GameScale).
var _radius_px: float = 0.0
## The sprite showing the shared circular base PNG.
var _base_sprite: Sprite2D = null
## The sprite showing the per-squadron token artwork PNG.
var _token_sprite: Sprite2D = null
## Runtime game-state instance (optional, set via [method bind_instance]).
var _squadron_instance: SquadronInstance = null


## Configures this token from a [TokenPlacement].
## Call once after adding to the scene tree.
## [param placement] must represent a squadron (is_ship == false).
func setup(placement: TokenPlacement) -> void:
	_placement = placement
	set_meta("data_key", placement.data_key)
	_radius_px = GameScale.squadron_base_diameter_px * 0.5
	position = placement.get_pixel_position(GameScale.play_area_size_px)
	rotation = placement.rotation_rad
	_create_base_sprite()
	_create_token_sprite(placement)
	queue_redraw()


## Returns the faction this squadron belongs to.
func get_faction() -> Constants.Faction:
	if _placement:
		return _placement.faction
	return Constants.Faction.REBEL_ALLIANCE


## Returns the base radius in pixels.
func get_radius_px() -> float:
	return _radius_px


## Binds a [SquadronInstance] to this token for runtime game state tracking.
## [param instance] — the runtime squadron state object.
func bind_instance(instance: SquadronInstance) -> void:
	_squadron_instance = instance


## Returns the bound [SquadronInstance] or null.
func get_squadron_instance() -> SquadronInstance:
	return _squadron_instance


## Dims or restores the token to indicate activation status.
## [param activated] — true to dim (alpha ~0.4), false to restore.
## Requirements: SQA-TM-004.
func set_activated_visual(activated: bool) -> void:
	if activated:
		modulate.a = 0.4
	else:
		modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _squadron_instance and _squadron_instance.is_destroyed():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = to_local(get_global_mouse_position())
			if local_pos.length() <= _radius_px:
				token_clicked.emit(self)
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


## Creates the Sprite2D child for the shared circular base image.
## Scaled to match the game-scale base diameter.
func _create_base_sprite() -> void:
	_base_sprite = Sprite2D.new()
	var tex: Texture2D = AssetLoader.load_texture("squadrons/", BASE_IMAGE_FILENAME)
	if tex:
		_base_sprite.texture = tex
		var tex_size: Vector2 = Vector2(
				float(tex.get_width()), float(tex.get_height()))
		_base_sprite.scale = GameScale.get_squadron_sprite_scale(tex_size)
	add_child(_base_sprite)


## Creates the Sprite2D child for the per-squadron token artwork image.
## Scaled to fit within the game-scale base circle (largest dimension
## maps to the base diameter).
func _create_token_sprite(placement: TokenPlacement) -> void:
	_token_sprite = Sprite2D.new()
	var filename: String = placement.data_key + "_token.png"
	var tex: Texture2D = AssetLoader.load_texture("squadrons/", filename)
	if tex:
		_token_sprite.texture = tex
		var tex_size: Vector2 = Vector2(
				float(tex.get_width()), float(tex.get_height()))
		_token_sprite.scale = GameScale.get_squadron_token_sprite_scale(tex_size)
	add_child(_token_sprite)

## DefenseTokenDisplay
##
## Renders a row of defense token sprites near a ship token.
## Reads token types and states from a bound [ShipInstance] and displays
## the appropriate ready/exhausted PNG. Discarded tokens are hidden.
##
## Usage: added as a child of [ShipToken] via [method ShipToken.bind_instance].
## Position is set relative to the ship base (below the rear edge).
##
## Rules Reference: GC-011, UI-006 — defense token display.
class_name DefenseTokenDisplay
extends Node2D


## Horizontal gap between token sprites (in local/game pixels).
const TOKEN_GAP_PX: float = 2.0

## Target height for each token sprite in local game pixels.
const TOKEN_DISPLAY_HEIGHT_PX: float = 12.0

## Map from [Constants.DefenseToken] enum to filename stem.
const TOKEN_FILENAMES: Dictionary = {
	Constants.DefenseToken.EVADE: "token_evade",
	Constants.DefenseToken.REDIRECT: "token_redirect",
	Constants.DefenseToken.BRACE: "token_brace",
	Constants.DefenseToken.SCATTER: "token_scatter",
	Constants.DefenseToken.CONTAIN: "token_contain",
	Constants.DefenseToken.SALVO: "token_salvo",
}

## Cached textures: {filename_stem: {state_suffix: Texture2D}}.
var _tex_cache: Dictionary = {}

## The defense tokens to display: Array of {type, state} dictionaries.
var _tokens: Array[Dictionary] = []

## Sprite children for each token position.
var _sprites: Array[Sprite2D] = []


## Updates the displayed tokens from an array of {type, state} dicts.
## Call this whenever defense token state changes.
func update_tokens(tokens: Array[Dictionary]) -> void:
	_tokens = tokens
	_rebuild_sprites()


## Loads (or returns cached) the texture for a given token type and state.
func _get_texture(token_type: Constants.DefenseToken,
		token_state: Constants.DefenseTokenState) -> Texture2D:
	var stem: String = TOKEN_FILENAMES.get(token_type, "")
	if stem.is_empty():
		return null
	var suffix: String = "ready"
	if token_state == Constants.DefenseTokenState.EXHAUSTED:
		suffix = "exhausted"
	var cache_key: String = stem + "_" + suffix
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var filename: String = "%s_%s.png" % [stem, suffix]
	var tex: Texture2D = AssetLoader.load_texture("defense_tokens/", filename)
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Removes old sprites and creates new ones for the current token list.
func _rebuild_sprites() -> void:
	for s: Sprite2D in _sprites:
		s.queue_free()
	_sprites.clear()
	var visible_count: int = _count_visible_tokens()
	if visible_count == 0:
		return
	var first_tex: Texture2D = _get_first_visible_texture()
	if first_tex == null:
		return
	var layout: Dictionary = _compute_layout(first_tex, visible_count)
	_create_token_sprites(layout)


## Counts non-discarded tokens.
func _count_visible_tokens() -> int:
	var count: int = 0
	for t: Dictionary in _tokens:
		var state: int = int(t.get("state", 0))
		if state != Constants.DefenseTokenState.DISCARDED:
			count += 1
	return count


## Computes layout parameters for token sprite positioning.
func _compute_layout(first_tex: Texture2D, visible_count: int) -> Dictionary:
	var src_w: float = float(first_tex.get_width())
	var src_h: float = float(first_tex.get_height())
	var scale_factor: float = TOKEN_DISPLAY_HEIGHT_PX / src_h if src_h > 0 else 1.0
	var token_w: float = src_w * scale_factor
	var total_w: float = token_w * visible_count + TOKEN_GAP_PX * (visible_count - 1)
	var x_start: float = - total_w * 0.5 + token_w * 0.5
	return {
		"scale_factor": scale_factor,
		"token_w": token_w,
		"x_start": x_start,
	}


## Creates positioned Sprite2D children for each visible token.
func _create_token_sprites(layout: Dictionary) -> void:
	var scale_factor: float = layout["scale_factor"]
	var token_w: float = layout["token_w"]
	var x_start: float = layout["x_start"]
	var idx: int = 0
	for t: Dictionary in _tokens:
		var state: int = int(t.get("state", 0))
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		var token_type: Constants.DefenseToken = t.get(
				"type", Constants.DefenseToken.EVADE) as Constants.DefenseToken
		var token_state: Constants.DefenseTokenState = state as Constants.DefenseTokenState
		var tex: Texture2D = _get_texture(token_type, token_state)
		if tex == null:
			idx += 1
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.position = Vector2(
				x_start + idx * (token_w + TOKEN_GAP_PX), 0.0)
		add_child(sprite)
		_sprites.append(sprite)
		idx += 1


## Returns the first visible token's texture (for sizing calculations).
func _get_first_visible_texture() -> Texture2D:
	for t: Dictionary in _tokens:
		var state: int = int(t.get("state", 0))
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		var token_type: Constants.DefenseToken = t.get(
				"type", Constants.DefenseToken.EVADE) as Constants.DefenseToken
		var token_state: Constants.DefenseTokenState = state as Constants.DefenseTokenState
		return _get_texture(token_type, token_state)
	return null

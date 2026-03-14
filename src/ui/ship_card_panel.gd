## ShipCardPanel
##
## Displays ship cards and their defense tokens in a vertical side panel
## outside the play area. One panel per faction: Rebel cards on the left,
## Imperial cards on the right.
##
## Each ship entry is a horizontal row:
##   - A vertical column of defense token sprites (left of the card)
##   - The ship card PNG (loaded from ships/<key>_card.png)
##
## Rebel panels align to the left screen edge + top.
## Imperial panels align to the right screen edge + top.
##
## Left-clicking a ship card entry toggles a magnified view (2.5× by default,
## configurable via scale_config.json → card_panel.magnify_factor).
##
## All display sizes are read from [GameScale] (loaded from scale_config.json).
## The panel lives on a CanvasLayer so it stays fixed on screen regardless
## of camera pan/zoom.
##
## Rules Reference: SU-026 — defense tokens placed next to ship card.
## Requirements: GC-005, GC-011, UI-006, UI-016, UI-017, UI-018.
class_name ShipCardPanel
extends VBoxContainer


## Map from [Constants.DefenseToken] enum to filename stem.
const TOKEN_FILENAMES: Dictionary = {
	Constants.DefenseToken.EVADE: "token_evade",
	Constants.DefenseToken.REDIRECT: "token_redirect",
	Constants.DefenseToken.BRACE: "token_brace",
	Constants.DefenseToken.SCATTER: "token_scatter",
	Constants.DefenseToken.CONTAIN: "token_contain",
	Constants.DefenseToken.SALVO: "token_salvo",
}

## The faction this panel represents.
var _faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE

## Whether this panel is on the left (Rebel) or right (Imperial) side.
var _is_left_side: bool = true

## Array of {instance: ShipInstance, container: HBoxContainer,
##           token_col: VBoxContainer, magnified: bool}.
var _entries: Array[Dictionary] = []

## Cached textures: {cache_key: Texture2D}.
var _tex_cache: Dictionary = {}


## Creates a ShipCardPanel for the given faction.
## [param faction] — Rebel or Imperial.
## [param left_side] — true for left-side placement (Rebel), false for right.
func setup(faction: Constants.Faction, left_side: bool) -> void:
	_faction = faction
	_is_left_side = left_side
	add_theme_constant_override("separation",
			int(GameScale.card_panel_entry_gap_px))


## Returns the faction this panel displays.
func get_faction() -> Constants.Faction:
	return _faction


## Returns the number of ship entries in this panel.
func get_entry_count() -> int:
	return _entries.size()


## Adds a ship entry to the panel.
## Layout: [token_column | card_image] in a horizontal row.
## [param instance] — the runtime ship state object.
func add_ship_entry(instance: ShipInstance) -> void:
	var card_h: float = GameScale.card_panel_card_height_px
	var card_w: float = GameScale.card_panel_card_width_px
	var token_h: float = GameScale.card_panel_token_height_px
	var token_gap: float = GameScale.card_panel_token_gap_px

	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation",
			int(token_gap))

	# Create defense token column (left of the card).
	var token_col: VBoxContainer = VBoxContainer.new()
	token_col.add_theme_constant_override("separation", int(token_gap))
	token_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_populate_token_column(token_col, instance.defense_tokens, token_h)
	entry_container.add_child(token_col)

	# Load and display ship card image.
	var card_texture: Texture2D = _load_card_texture(instance.data_key)
	if card_texture:
		var card_rect: TextureRect = TextureRect.new()
		card_rect.texture = card_texture
		card_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_rect.custom_minimum_size = Vector2(card_w, card_h)
		entry_container.add_child(card_rect)
	else:
		var log: GameLogger = GameLogger.new("ShipCardPanel")
		log.info("No card texture found for '%s'" % instance.data_key)

	# Make the entry clickable for magnify toggle.
	entry_container.mouse_filter = Control.MOUSE_FILTER_STOP
	entry_container.gui_input.connect(
			_on_entry_gui_input.bind(_entries.size()))

	add_child(entry_container)
	_entries.append({
		"instance": instance,
		"container": entry_container,
		"token_col": token_col,
		"magnified": false,
	})

	# Listen for defense token state changes via EventBus.
	if not EventBus.ship_defense_token_changed.is_connected(
			_on_defense_tokens_changed):
		EventBus.ship_defense_token_changed.connect(
				_on_defense_tokens_changed)


## Positions this panel on the correct side of the screen.
## Computes size from entry data directly (bypassing Godot's deferred
## minimum-size cache, which returns stale values for right-aligned panels).
## [param viewport_size] — the viewport dimensions.
func update_position(viewport_size: Vector2) -> void:
	var pad: float = GameScale.card_panel_edge_padding_px
	var top: float = GameScale.card_panel_top_padding_px
	var panel_size: Vector2 = _compute_panel_size()
	# Set both custom_minimum_size and size to override any stale
	# cached minimum the VBoxContainer might hold from a previous
	# magnified state.
	custom_minimum_size = panel_size
	size = panel_size
	if _is_left_side:
		position = Vector2(pad, top)
	else:
		position = Vector2(viewport_size.x - panel_size.x - pad, top)


## Computes the actual panel size by reading custom_minimum_size directly
## from each TextureRect child.  This avoids relying on
## get_combined_minimum_size() whose cache can be stale after resizing
## nested grandchildren in the same frame.
func _compute_panel_size() -> Vector2:
	var max_w: float = 0.0
	var total_h: float = 0.0
	var entry_gap: float = GameScale.card_panel_entry_gap_px
	var token_gap: float = GameScale.card_panel_token_gap_px

	for i: int in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		var factor: float = (
				GameScale.card_panel_magnify_factor
				if entry["magnified"] else 1.0)
		var card_w: float = GameScale.card_panel_card_width_px * factor
		var card_h: float = GameScale.card_panel_card_height_px * factor

		# Token column width = widest token TextureRect.
		var col: VBoxContainer = entry["token_col"]
		var col_w: float = 0.0
		for child: Node in col.get_children():
			if child is TextureRect:
				col_w = maxf(col_w, child.custom_minimum_size.x)

		var entry_w: float = col_w + token_gap + card_w
		max_w = maxf(max_w, entry_w)
		total_h += card_h
		if i > 0:
			total_h += entry_gap

	return Vector2(max_w, total_h)


## Handles left-click on a ship card entry to toggle magnify.
## Requirements: UI-018.
func _on_entry_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if index < 0 or index >= _entries.size():
		return
	_toggle_magnify(index)


## Toggles between normal and magnified size for the entry at [param index].
## Rules Reference: UI-018 — left-click toggles 2.5× magnification.
func _toggle_magnify(index: int) -> void:
	var entry: Dictionary = _entries[index]
	var magnified: bool = entry["magnified"]
	var factor: float = GameScale.card_panel_magnify_factor
	var container: HBoxContainer = entry["container"]

	if magnified:
		# Restore normal size.
		_apply_entry_size(container, 1.0)
		entry["magnified"] = false
	else:
		# Apply magnified size.
		_apply_entry_size(container, factor)
		entry["magnified"] = true

	# Recalculate panel layout.
	var vp_size: Vector2 = Vector2.ZERO
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	update_position(vp_size)


## Sets the minimum size of all children in an entry container to
## their base size multiplied by [param scale_factor].
func _apply_entry_size(container: HBoxContainer,
		scale_factor: float) -> void:
	var card_h: float = GameScale.card_panel_card_height_px * scale_factor
	var card_w: float = GameScale.card_panel_card_width_px * scale_factor
	var token_h: float = GameScale.card_panel_token_height_px * scale_factor

	for child: Node in container.get_children():
		if child is TextureRect:
			var rect: TextureRect = child as TextureRect
			rect.custom_minimum_size = Vector2(card_w, card_h)
		elif child is VBoxContainer:
			var col: VBoxContainer = child as VBoxContainer
			for token_child: Node in col.get_children():
				if token_child is TextureRect:
					var tr: TextureRect = token_child as TextureRect
					var tex: Texture2D = tr.texture
					if tex:
						var t_aspect: float = (
								float(tex.get_width())
								/ maxf(float(tex.get_height()), 1.0))
						var tw: float = token_h * t_aspect
						tr.custom_minimum_size = Vector2(tw, token_h)


## EventBus callback: a ship's defense token state changed.
## Updates the matching token column if the instance belongs to this panel.
func _on_defense_tokens_changed(inst: RefCounted) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			var col: VBoxContainer = entry["token_col"]
			var si: ShipInstance = entry["instance"]
			var token_h: float = GameScale.card_panel_token_height_px
			if entry["magnified"]:
				token_h *= GameScale.card_panel_magnify_factor
			_populate_token_column(col, si.defense_tokens, token_h)
			break


## Fills a token column container with TextureRect sprites stacked vertically.
## Clears existing children first.
## [param token_h] — the display height for each token sprite.
func _populate_token_column(col: VBoxContainer,
		tokens: Array[Dictionary], token_h: float) -> void:
	for child: Node in col.get_children():
		child.queue_free()
	for t: Dictionary in tokens:
		var state: int = int(t.get("state", 0))
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		var token_type: Constants.DefenseToken = t.get(
				"type", Constants.DefenseToken.EVADE) as Constants.DefenseToken
		var token_state: Constants.DefenseTokenState = (
				state as Constants.DefenseTokenState)
		var tex: Texture2D = _get_token_texture(token_type, token_state)
		if tex == null:
			continue
		var rect: TextureRect = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var t_aspect: float = (
				float(tex.get_width())
				/ maxf(float(tex.get_height()), 1.0))
		var token_w: float = token_h * t_aspect
		rect.custom_minimum_size = Vector2(token_w, token_h)
		col.add_child(rect)


## Loads (or returns cached) the texture for a given token type and state.
func _get_token_texture(token_type: Constants.DefenseToken,
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


## Loads the ship card texture from the ships/ asset folder.
## Convention: card filename is <data_key>_card.png.
func _load_card_texture(data_key: String) -> Texture2D:
	var filename: String = "%s_card.png" % data_key
	return AssetLoader.load_texture("ships/", filename)

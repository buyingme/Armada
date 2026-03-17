## ShipCardPanel
##
## Displays ship cards, defense tokens, command dial stacks, and command tokens
## in a vertical side panel outside the play area. One panel per faction:
## Rebel cards on the left, Imperial cards on the right.
##
## Each ship entry is a horizontal row:
##   - Left column: defense token sprites + command dial stack (below)
##   - Centre: the ship card PNG (loaded from ships/<key>_card.png)
##   - Right column: command token sprites
##
## Rebel panels align to the left screen edge + top.
## Imperial panels align to the right screen edge + top.
##
## Left-clicking a ship card entry toggles a magnified view (configurable via
## scale_config.json → card_panel.magnify_factor).
##
## All display sizes are read from [GameScale] (loaded from scale_config.json).
## The panel lives on a CanvasLayer so it stays fixed on screen regardless
## of camera pan/zoom.
##
## Rules Reference: SU-026 — defense tokens placed next to ship card.
## Requirements: GC-005, GC-008, GC-011, GC-018, UI-006, UI-016–023.
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

## Map from [Constants.CommandType] enum to icon filename.
const CMD_ICON_FILENAMES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}

## Filename for the hidden (facedown) dial background.
const CMD_DIAL_HIDDEN_FILE: String = "cmd_dial_hidden.png"

## The faction this panel represents.
var _faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE

## Whether this panel is on the left (Rebel) or right (Imperial) side.
var _is_left_side: bool = true

## Array of entry dictionaries. Each entry:
## {instance: ShipInstance, container: HBoxContainer,
##  left_col: VBoxContainer, token_col: VBoxContainer,
##  dial_container: Control, cmd_token_col: VBoxContainer, magnified: bool}
var _entries: Array[Dictionary] = []

## Cached textures: {cache_key: Texture2D}.
var _tex_cache: Dictionary = {}

## The player index viewing this panel (for dial order modal access control).
var _viewer_player: int = -1


## Creates a ShipCardPanel for the given faction.
## [param faction] — Rebel or Imperial.
## [param left_side] — true for left-side placement (Rebel), false for right.
## [param viewer] — the player index viewing this panel (for opponent restriction).
func setup(faction: Constants.Faction, left_side: bool,
		viewer: int = -1) -> void:
	_faction = faction
	_is_left_side = left_side
	_viewer_player = viewer
	add_theme_constant_override("separation",
			int(GameScale.card_panel_entry_gap_px))


## Returns the faction this panel displays.
func get_faction() -> Constants.Faction:
	return _faction


## Returns whether this panel is on the left side.
func is_left_side() -> bool:
	return _is_left_side


## Moves this panel to the given side (left or right).
## Call [method update_position] afterwards to reposition.
## Requirements: BP-003 — active player's cards always on the left.
## [param left_side] — true to place on the left, false for right.
func set_side(left_side: bool) -> void:
	_is_left_side = left_side


## Updates the viewer player index.
## When set, the dial order modal can only be opened for ships owned
## by this player; opponent dials remain hidden.
## [param player_index] — the player index who is currently viewing.
## Requirements: UI-023 — cannot view opponent's unrevealed dials.
func set_viewer_player(player_index: int) -> void:
	_viewer_player = player_index


## Returns the number of ship entries in this panel.
func get_entry_count() -> int:
	return _entries.size()


## Adds a ship entry to the panel.
## Layout: [left_col(tokens + dial_stack) | card_image | cmd_token_col].
## [param instance] — the runtime ship state object.
func add_ship_entry(instance: ShipInstance) -> void:
	var card_h: float = GameScale.card_panel_card_height_px
	var card_w: float = GameScale.card_panel_card_width_px
	var token_h: float = GameScale.card_panel_token_height_px
	var token_gap: float = GameScale.card_panel_token_gap_px

	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation",
			int(token_gap))

	# --- Left column: defense tokens + command dial stack ---
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", int(token_gap))
	left_col.alignment = BoxContainer.ALIGNMENT_BEGIN

	var token_col: VBoxContainer = VBoxContainer.new()
	token_col.add_theme_constant_override("separation", int(token_gap))
	token_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_populate_token_column(token_col, instance.defense_tokens, token_h)
	left_col.add_child(token_col)

	var dial_container: VBoxContainer = VBoxContainer.new()
	dial_container.add_theme_constant_override("separation", 0)
	_populate_dial_stack(dial_container, instance, 1.0)
	left_col.add_child(dial_container)

	entry_container.add_child(left_col)

	# --- Centre: ship card image ---
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

	# --- Right column: command tokens ---
	var cmd_token_col: VBoxContainer = VBoxContainer.new()
	cmd_token_col.add_theme_constant_override("separation", int(token_gap))
	cmd_token_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_populate_cmd_token_column(cmd_token_col, instance, 1.0)
	entry_container.add_child(cmd_token_col)

	# Make the entry clickable for magnify toggle.
	entry_container.mouse_filter = Control.MOUSE_FILTER_STOP
	entry_container.gui_input.connect(
			_on_entry_gui_input.bind(_entries.size()))

	add_child(entry_container)
	_entries.append({
		"instance": instance,
		"container": entry_container,
		"left_col": left_col,
		"token_col": token_col,
		"dial_container": dial_container,
		"cmd_token_col": cmd_token_col,
		"magnified": false,
	})

	_connect_eventbus_signals()


## Positions this panel on the correct side of the screen.
## Computes size from entry data directly (bypassing Godot's deferred
## minimum-size cache, which returns stale values for right-aligned panels).
## [param viewport_size] — the viewport dimensions.
func update_position(viewport_size: Vector2) -> void:
	var pad: float = GameScale.card_panel_edge_padding_px
	var top: float = GameScale.card_panel_top_padding_px
	var panel_size: Vector2 = _compute_panel_size()
	custom_minimum_size = panel_size
	size = panel_size
	if _is_left_side:
		position = Vector2(pad, top)
	else:
		position = Vector2(viewport_size.x - panel_size.x - pad, top)


## Computes the actual panel size by reading custom_minimum_size directly
## from each child. Avoids relying on stale cached minimums.
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

		# Left column width = max of token column and dial container.
		var col: VBoxContainer = entry["token_col"]
		var col_w: float = 0.0
		for child: Node in col.get_children():
			if child is TextureRect:
				col_w = maxf(col_w, child.custom_minimum_size.x)
		# Dial stack is vertical — its width equals one dial width.
		var dial_cont: VBoxContainer = entry["dial_container"]
		var dial_w_: float = GameScale.card_panel_dial_width_px * factor
		col_w = maxf(col_w, dial_w_)

		# Right column width = command token column.
		var cmd_col: VBoxContainer = entry["cmd_token_col"]
		var cmd_col_w: float = 0.0
		for child: Node in cmd_col.get_children():
			if child is TextureRect:
				cmd_col_w = maxf(cmd_col_w, child.custom_minimum_size.x)

		var entry_w: float = col_w + token_gap + card_w
		if cmd_col_w > 0.0:
			entry_w += token_gap + cmd_col_w
		max_w = maxf(max_w, entry_w)
		total_h += card_h
		if i > 0:
			total_h += entry_gap

	return Vector2(max_w, total_h)


## Handles left-click on a ship card entry to toggle magnify.
## Also handles click on dial stack area for dial order modal.
## Requirements: UI-018, UI-022, UI-023.
func _on_entry_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if index < 0 or index >= _entries.size():
		return

	var entry: Dictionary = _entries[index]
	var dial_cont: VBoxContainer = entry["dial_container"] as VBoxContainer

	# Check if click is within the dial container area (dial order modal).
	if _is_click_in_dial_area(mb, dial_cont):
		_handle_dial_stack_click(entry)
		return

	_toggle_magnify(index)


## Returns true if the mouse event lands inside the dial container's rect.
func _is_click_in_dial_area(mb: InputEventMouseButton,
		dial_cont: VBoxContainer) -> bool:
	if dial_cont.get_child_count() == 0:
		return false
	var dial_rect: Rect2 = dial_cont.get_global_rect()
	return dial_rect.has_point(mb.global_position)


## Handles click on a ship's dial stack. Opens dial order modal for own ships,
## or starts a dial drag during Ship Phase for eligible ships.
## Rules Reference: UI-022 — click own stack to open dial order.
## Rules Reference: UI-023 — cannot view opponent's unrevealed dials.
## Rules Reference: UI-024 — drag topmost dial to activate during Ship Phase.
func _handle_dial_stack_click(entry: Dictionary) -> void:
	var instance: ShipInstance = entry["instance"]
	# Only allow viewing own ship's dials.
	if _viewer_player >= 0 and instance.owner_player != _viewer_player:
		return

	# During Ship Phase: if this ship can be activated, start dial drag.
	if _can_start_dial_drag(instance):
		EventBus.dial_drag_started.emit(instance)
		return

	EventBus.command_dial_order_requested.emit(instance)


## Returns true if a dial drag can be started for this ship.
## Conditions: Ship Phase, ship owned by active player, not activated,
## has hidden dials, and no other ship is currently being activated.
## Requirements: UI-024.
func _can_start_dial_drag(instance: ShipInstance) -> bool:
	if GameManager.get_current_phase() != Constants.GamePhase.SHIP:
		return false
	if instance.owner_player != GameManager.get_active_player():
		return false
	if instance.activated_this_round:
		return false
	if instance.command_dial_stack == null:
		return false
	if instance.command_dial_stack.get_hidden_count() == 0:
		return false
	if GameManager.get_activating_ship() != null:
		return false
	return true


## Toggles between normal and magnified size for the entry at [param index].
## Rules Reference: UI-018 — left-click toggles magnification.
func _toggle_magnify(index: int) -> void:
	var entry: Dictionary = _entries[index]
	var magnified: bool = entry["magnified"]
	var factor: float = GameScale.card_panel_magnify_factor
	var container: HBoxContainer = entry["container"]

	if magnified:
		_apply_entry_size(entry, 1.0)
		entry["magnified"] = false
	else:
		_apply_entry_size(entry, factor)
		entry["magnified"] = true

	var vp_size: Vector2 = Vector2.ZERO
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	update_position(vp_size)


## Sets the minimum size of all children in an entry to their base size
## multiplied by [param scale_factor].
func _apply_entry_size(entry: Dictionary,
		scale_factor: float) -> void:
	var card_h: float = GameScale.card_panel_card_height_px * scale_factor
	var card_w: float = GameScale.card_panel_card_width_px * scale_factor
	var token_h: float = GameScale.card_panel_token_height_px * scale_factor
	var container: HBoxContainer = entry["container"]

	for child: Node in container.get_children():
		if child is TextureRect:
			# Card image.
			var rect: TextureRect = child as TextureRect
			rect.custom_minimum_size = Vector2(card_w, card_h)
		elif child is VBoxContainer:
			_scale_vbox_textures(child as VBoxContainer, token_h)

	# Re-populate dial stack at new scale.
	var dial_cont: VBoxContainer = entry["dial_container"]
	var instance: ShipInstance = entry["instance"]
	_populate_dial_stack(dial_cont, instance, scale_factor)

	# Re-populate command token column at new scale.
	var cmd_col: VBoxContainer = entry["cmd_token_col"]
	_populate_cmd_token_column(cmd_col, instance, scale_factor)


## Scales all TextureRect children in a VBoxContainer to a given height.
func _scale_vbox_textures(col: VBoxContainer, token_h: float) -> void:
	for child: Node in col.get_children():
		if child is VBoxContainer:
			_scale_vbox_textures(child as VBoxContainer, token_h)
		elif child is TextureRect:
			var tr: TextureRect = child as TextureRect
			var tex: Texture2D = tr.texture
			if tex:
				var t_aspect: float = (
						float(tex.get_width())
						/ maxf(float(tex.get_height()), 1.0))
				var tw: float = token_h * t_aspect
				tr.custom_minimum_size = Vector2(tw, token_h)


# ---------------------------------------------------------------------------
# EventBus connections
# ---------------------------------------------------------------------------

## Connects EventBus signals (idempotent).
func _connect_eventbus_signals() -> void:
	if not EventBus.ship_defense_token_changed.is_connected(
			_on_defense_tokens_changed):
		EventBus.ship_defense_token_changed.connect(
				_on_defense_tokens_changed)
	if not EventBus.command_dials_changed.is_connected(
			_on_command_dials_changed):
		EventBus.command_dials_changed.connect(
				_on_command_dials_changed)
	if not EventBus.command_tokens_changed.is_connected(
			_on_command_tokens_changed):
		EventBus.command_tokens_changed.connect(
				_on_command_tokens_changed)


## EventBus callback: a ship's defense token state changed.
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


## EventBus callback: a ship's command dials changed.
func _on_command_dials_changed(inst: RefCounted) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			var factor: float = (
					GameScale.card_panel_magnify_factor
					if entry["magnified"] else 1.0)
			_populate_dial_stack(
					entry["dial_container"], inst as ShipInstance, factor)
			_refresh_panel_position()
			break


## EventBus callback: a ship's command tokens changed.
func _on_command_tokens_changed(inst: RefCounted) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			var factor: float = (
					GameScale.card_panel_magnify_factor
					if entry["magnified"] else 1.0)
			_populate_cmd_token_column(
					entry["cmd_token_col"], inst as ShipInstance, factor)
			_refresh_panel_position()
			break


## Re-computes panel position after a content change.
func _refresh_panel_position() -> void:
	var vp_size: Vector2 = Vector2.ZERO
	if is_inside_tree():
		vp_size = get_viewport().get_visible_rect().size
	update_position(vp_size)


## Returns the pixel height occupied by a vertical dial stack container.
## Overlapping dials with negative separation must be accounted for.
func _compute_dial_stack_height(
		dial_cont: VBoxContainer, scale_factor: float) -> float:
	var n: int = dial_cont.get_child_count()
	if n == 0:
		return 0.0
	var dial_h: float = GameScale.card_panel_dial_height_px * scale_factor
	var off: float = GameScale.card_panel_dial_stack_offset_px * scale_factor
	# Each extra dial overlaps: visible = dial_h - offset, first = full height.
	return dial_h + maxf(0.0, float(n - 1) * (dial_h - off))


# ---------------------------------------------------------------------------
# Populate helpers
# ---------------------------------------------------------------------------

## Fills a token column container with defense token TextureRect sprites.
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


## Populates the command dial stack display as a vertical column.
## All hidden dials use cmd_dial_hidden.png. A revealed dial (during Ship
## Phase) shows its command icon composited on the hidden background.
## A spent dial (activation marker) is shown below the active stack with a
## 0.5 cm gap (approximately 12 px at standard screen scale).
## [param container] — the VBoxContainer to populate.
## [param instance] — the ShipInstance whose dials to display.
## [param scale_factor] — current magnification factor.
## Rules Reference: UI-019, UI-020, UI-026; GC-008.
func _populate_dial_stack(container: VBoxContainer,
		instance: ShipInstance, scale_factor: float) -> void:
	for child: Node in container.get_children():
		child.queue_free()

	if instance.command_dial_stack == null:
		container.custom_minimum_size = Vector2.ZERO
		return

	var display: Dictionary = instance.command_dial_stack.get_display_state()
	var hidden_dials: Array = display.get("hidden_dials", [])
	var revealed: Dictionary = display.get("revealed", {})
	var spent_marker: Dictionary = display.get("spent_marker", {})

	var dial_h: float = GameScale.card_panel_dial_height_px * scale_factor
	var dial_w: float = GameScale.card_panel_dial_width_px * scale_factor
	var offset: int = int(GameScale.card_panel_dial_stack_offset_px
			* scale_factor)

	# Use a zero-spacing outer container so we can control the gap between
	# the active stack and the spent dial precisely.
	container.add_theme_constant_override("separation", 0)

	# --- Active dial stack (hidden only) with negative overlap ---
	# The revealed dial is not rendered in the stack — it is already visible
	# on the board token after the player drags it for activation.
	var active_stack: VBoxContainer = VBoxContainer.new()
	active_stack.add_theme_constant_override("separation", -offset)

	# Render hidden dials — ALL use cmd_dial_hidden.png (facedown).
	# Rules Reference: CP-006 — dials are facedown.
	for i: int in range(hidden_dials.size()):
		var rect: Control = _create_dial_rect(
				0, false, dial_w, dial_h)
		active_stack.add_child(rect)

	container.add_child(active_stack)

	# --- Spent dial (activation marker) — below stack with ~0.5 cm gap ---
	if not spent_marker.is_empty():
		var spent_gap_px: float = 12.0 * scale_factor
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, spent_gap_px)
		container.add_child(spacer)
		var spent_rect: Control = _create_dial_rect(
				int(spent_marker.get("command", 0)), true, dial_w, dial_h)
		spent_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(spent_rect)


## Creates a Control for a single command dial.
## When [param show_icon] is false, returns a [TextureRect] with the hidden
## dial background. When true, returns a container that composites the dial
## background with the command icon on top (centred).
## [param cmd] — Constants.CommandType value.
## [param show_icon] — true to composite the command icon on top.
## [param w] — display width. [param h] — display height.
func _create_dial_rect(cmd: int, show_icon: bool,
		w: float, h: float) -> Control:
	if not show_icon:
		var bg_tex: Texture2D = _get_dial_hidden_texture()
		var rect: TextureRect = TextureRect.new()
		if bg_tex:
			rect.texture = bg_tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(w, h)
		return rect

	# Composite: dial background + command icon on top.
	var panel: Control = Control.new()
	panel.custom_minimum_size = Vector2(w, h)

	var bg_tex: Texture2D = _get_dial_hidden_texture()
	if bg_tex:
		var bg_rect: TextureRect = TextureRect.new()
		bg_rect.texture = bg_tex
		bg_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_rect.custom_minimum_size = Vector2(w, h)
		panel.add_child(bg_rect)

	var icon_tex: Texture2D = _get_cmd_icon_texture(cmd)
	if icon_tex:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_size: float = h * 0.7
		var icon_offset: float = (h - icon_size) * 0.5
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.position = Vector2((w - icon_size) * 0.5, icon_offset)
		panel.add_child(icon_rect)

	return panel


## Populates the command token column on the right of the ship card.
## [param col] — the VBoxContainer to populate.
## [param instance] — the ShipInstance whose tokens to display.
## [param scale_factor] — current magnification factor.
## Rules Reference: GC-018.
func _populate_cmd_token_column(col: VBoxContainer,
		instance: ShipInstance, scale_factor: float) -> void:
	for child: Node in col.get_children():
		child.queue_free()

	if instance.command_tokens == null:
		return

	var tokens: Array[int] = instance.command_tokens.get_tokens()
	var cmd_h: float = GameScale.card_panel_cmd_token_height_px * scale_factor

	for cmd: int in tokens:
		var tex: Texture2D = _get_cmd_icon_texture(cmd)
		if tex == null:
			continue
		var rect: TextureRect = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var t_aspect: float = (
				float(tex.get_width())
				/ maxf(float(tex.get_height()), 1.0))
		var tw: float = cmd_h * t_aspect
		rect.custom_minimum_size = Vector2(tw, cmd_h)
		col.add_child(rect)


# ---------------------------------------------------------------------------
# Texture loading
# ---------------------------------------------------------------------------

## Loads (or returns cached) the texture for a defense token type and state.
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


## Loads (or returns cached) a command icon texture.
func _get_cmd_icon_texture(cmd: int) -> Texture2D:
	var filename: String = CMD_ICON_FILENAMES.get(cmd, "")
	if filename.is_empty():
		return null
	var cache_key: String = "cmd_icon_%d" % cmd
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var tex: Texture2D = AssetLoader.load_texture("command_tokens/", filename)
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Loads (or returns cached) the hidden dial background texture.
func _get_dial_hidden_texture() -> Texture2D:
	var cache_key: String = "dial_hidden"
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", CMD_DIAL_HIDDEN_FILE)
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Returns the [ShipInstance] whose card entry contains [param screen_pos],
## or null if the position is outside all entries.
## Used by the dial drag-and-drop system to detect a card panel drop target.
## Requirements: UI-028 — drag to card converts dial to command token.
func get_ship_instance_at_screen_pos(screen_pos: Vector2) -> ShipInstance:
	for entry: Dictionary in _entries:
		var container: HBoxContainer = entry["container"] as HBoxContainer
		if container and container.get_global_rect().has_point(screen_pos):
			return entry["instance"] as ShipInstance
	return null


## Loads the ship card texture from the ships/ asset folder.
## Convention: card filename is <data_key>_card.png.
func _load_card_texture(data_key: String) -> Texture2D:
	var filename: String = "%s_card.png" % data_key
	return AssetLoader.load_texture("ships/", filename)

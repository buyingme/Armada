## Constructs UI elements for a single ship-card-panel entry row.
##
## Builds the left column (defense tokens + command dial stack), the card
## image, and the command-token column.  Provides populate helpers that
## rebuild individual sub-columns at a given scale factor.
##
## Does **not** own the entry dictionary or wire EventBus signals — the
## owning [ShipCardPanel] handles registration and coordination.
##
## Extracted from [ShipCardPanel] in refactoring Phase D3.
class_name ShipCardEntryBuilder
extends RefCounted


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


## Shared texture cache (same Dictionary reference as ShipCardPanel).
var _tex_cache: Dictionary

## Logger instance.
var _log: GameLogger = GameLogger.new("ShipCardEntryBuilder")


## Creates an entry builder that shares [param tex_cache] with the panel.
func _init(tex_cache: Dictionary) -> void:
	_tex_cache = tex_cache


# ── Column construction ──────────────────────────────────────────────

## Builds the left column: defense tokens, dial gap, and dial stack.
##
## Returns a dictionary with keys [code]left_col[/code],
## [code]token_col[/code], [code]dial_gap[/code], and
## [code]dial_container[/code].  The caller is responsible for wiring
## [code]dial_container.gui_input[/code] to its own handler.
func build_left_column(instance: ShipInstance,
		token_gap: float) -> Dictionary:
	var token_h: float = GameScale.card_panel_token_height_px
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 0)
	left_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	var token_col: VBoxContainer = VBoxContainer.new()
	token_col.add_theme_constant_override("separation", int(token_gap))
	token_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	populate_token_column(token_col, instance.defense_tokens, token_h)
	left_col.add_child(token_col)
	var dial_gap: Control = Control.new()
	dial_gap.custom_minimum_size = Vector2(
			0, GameScale.card_panel_dial_top_gap_px)
	dial_gap.mouse_filter = Control.MOUSE_FILTER_PASS
	left_col.add_child(dial_gap)
	var dial_container: VBoxContainer = VBoxContainer.new()
	dial_container.add_theme_constant_override("separation", 0)
	populate_dial_stack(dial_container, instance, 1.0)
	left_col.add_child(dial_container)
	left_col.mouse_filter = Control.MOUSE_FILTER_PASS
	token_col.mouse_filter = Control.MOUSE_FILTER_PASS
	dial_container.mouse_filter = Control.MOUSE_FILTER_STOP
	return {"left_col": left_col, "token_col": token_col,
			"dial_gap": dial_gap, "dial_container": dial_container}


## Creates the ship card image TextureRect (or null if not found).
func build_card_image(instance: ShipInstance) -> Control:
	var card_h: float = GameScale.card_panel_card_height_px
	var card_w: float = GameScale.card_panel_card_width_px
	var card_texture: Texture2D = load_card_texture(instance.data_key)
	if card_texture:
		var card_rect: TextureRect = TextureRect.new()
		card_rect.texture = card_texture
		card_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_rect.custom_minimum_size = Vector2(card_w, card_h)
		card_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		return card_rect
	_log.info("No card texture found for '%s'" % instance.data_key)
	return null


## Creates an empty VBoxContainer column with standard spacing.
func build_column(token_gap: float) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", int(token_gap))
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	return col


# ── Resize / rescale ─────────────────────────────────────────────────

## Resizes all non-damage children in an entry to their base size
## multiplied by [param scale_factor].
##
## The caller must separately refresh the damage column via
## [DamageCardDisplay.populate_damage_cards].
func apply_entry_size(entry: Dictionary,
		scale_factor: float) -> void:
	var card_h: float = GameScale.card_panel_card_height_px * scale_factor
	var card_w: float = GameScale.card_panel_card_width_px * scale_factor
	var token_h: float = GameScale.card_panel_token_height_px * scale_factor
	var container: HBoxContainer = entry["container"]

	for child: Node in container.get_children():
		if child is TextureRect:
			var rect: TextureRect = child as TextureRect
			rect.custom_minimum_size = Vector2(card_w, card_h)
		elif child is VBoxContainer:
			_scale_vbox_textures(child as VBoxContainer, token_h)

	var dial_cont: VBoxContainer = entry["dial_container"]
	var instance: ShipInstance = entry["instance"]
	populate_dial_stack(dial_cont, instance, scale_factor)

	var gap_ctrl: Control = entry["dial_gap"] as Control
	gap_ctrl.custom_minimum_size = Vector2(
			0, GameScale.card_panel_dial_top_gap_px * scale_factor)

	var cmd_col: VBoxContainer = entry["cmd_token_col"]
	populate_cmd_token_column(cmd_col, instance, scale_factor)


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


# ── Populate helpers ─────────────────────────────────────────────────

## Fills a token column with defense token TextureRect sprites.
## Clears existing children first.
func populate_token_column(col: VBoxContainer,
		tokens: Array[Dictionary], token_h: float) -> void:
	for child: Node in col.get_children():
		col.remove_child(child)
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
	set_children_mouse_pass(col)


## Populates the command dial stack display as a vertical column.
## Rules Reference: UI-019, UI-020, UI-026; GC-008.
func populate_dial_stack(container: VBoxContainer,
		instance: ShipInstance, scale_factor: float) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
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

	container.add_theme_constant_override("separation", 0)

	var stack_h: float = _build_active_dial_stack(
			container, revealed, hidden_dials, dial_w, dial_h, offset)

	var total_container_h: float = stack_h + _build_spent_marker_section(
			container, spent_marker, scale_factor, dial_w, dial_h)

	container.custom_minimum_size = Vector2(dial_w, total_container_h)
	set_children_mouse_pass(container)


## Builds the active (revealed + hidden) dial stack and adds it to
## [param container].  Returns the computed stack height.
func _build_active_dial_stack(container: VBoxContainer,
		revealed: Dictionary, hidden_dials: Array,
		dial_w: float, dial_h: float, offset: int) -> float:
	var active_stack: VBoxContainer = VBoxContainer.new()
	active_stack.add_theme_constant_override("separation", -offset)
	active_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		active_stack.add_child(_create_dial_rect(cmd, true, dial_w, dial_h))

	for i: int in range(hidden_dials.size()):
		active_stack.add_child(_create_dial_rect(0, false, dial_w, dial_h))

	var child_count: int = active_stack.get_child_count()
	for i: int in range(child_count):
		active_stack.get_child(i).z_index = child_count - i

	var total_dials: int = (0 if revealed.is_empty() else 1) + hidden_dials.size()
	var stack_h: float = 0.0
	if total_dials > 0:
		stack_h = dial_h + maxf(0, total_dials - 1) * (dial_h - float(offset))
	active_stack.custom_minimum_size = Vector2(dial_w, stack_h)

	container.add_child(active_stack)
	return stack_h


## Adds the spent-dial activation marker below the active stack with a
## ~0.5 cm gap.  Returns the additional height consumed (0 if no marker).
func _build_spent_marker_section(container: VBoxContainer,
		spent_marker: Dictionary, scale_factor: float,
		dial_w: float, dial_h: float) -> float:
	if spent_marker.is_empty():
		return 0.0
	var spent_gap_px: float = 12.0 * scale_factor
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, spent_gap_px)
	container.add_child(spacer)
	var spent_rect: Control = _create_dial_rect(
			int(spent_marker.get("command", 0)), true, dial_w, dial_h)
	spent_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(spent_rect)
	return spent_gap_px + dial_h


## Creates a Control for a single command dial.
func _create_dial_rect(cmd: int, show_icon: bool,
		w: float, h: float) -> Control:
	if not show_icon:
		return _create_hidden_dial_rect(w, h)
	return _create_revealed_dial_rect(cmd, w, h)


## Creates a facedown dial TextureRect.
func _create_hidden_dial_rect(w: float, h: float) -> TextureRect:
	var bg_tex: Texture2D = _get_dial_hidden_texture()
	var rect: TextureRect = TextureRect.new()
	if bg_tex:
		rect.texture = bg_tex
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(w, h)
	return rect


## Creates a revealed dial: background + command icon composited.
func _create_revealed_dial_rect(cmd: int,
		w: float, h: float) -> Control:
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
## Rules Reference: GC-018.
func populate_cmd_token_column(col: VBoxContainer,
		instance: ShipInstance, scale_factor: float) -> void:
	for child: Node in col.get_children():
		col.remove_child(child)
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
	set_children_mouse_pass(col)


# ── Measurement helpers ──────────────────────────────────────────────

## Computes the total width of a single ship entry row.
func compute_entry_width(entry: Dictionary, factor: float,
		token_gap: float, card_w: float) -> float:
	var col: VBoxContainer = entry["token_col"]
	var col_w: float = max_child_width(col)
	var dial_w_: float = GameScale.card_panel_dial_width_px * factor
	col_w = maxf(col_w, dial_w_)

	var cmd_col: VBoxContainer = entry["cmd_token_col"]
	var cmd_col_w: float = max_child_width(cmd_col)

	var dmg_col: VBoxContainer = entry.get(
			"damage_col", null) as VBoxContainer
	var dmg_col_w: float = 0.0
	if dmg_col:
		dmg_col_w = max_child_width_control(dmg_col)

	var entry_w: float = col_w + token_gap + card_w
	if cmd_col_w > 0.0:
		entry_w += token_gap + cmd_col_w
	if dmg_col_w > 0.0:
		entry_w += token_gap + dmg_col_w
	return entry_w


## Returns the maximum [member custom_minimum_size].x among [TextureRect]
## children of [param container].
func max_child_width(container: Control) -> float:
	var w: float = 0.0
	for child: Node in container.get_children():
		if child is TextureRect:
			w = maxf(w, child.custom_minimum_size.x)
	return w


## Returns the maximum [member custom_minimum_size].x among [Control]
## children of [param container].
func max_child_width_control(container: Control) -> float:
	var w: float = 0.0
	for child: Node in container.get_children():
		if child is Control:
			w = maxf(w, child.custom_minimum_size.x)
	return w


# ── Texture loading ──────────────────────────────────────────────────

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


## Loads the ship card texture from the ships/ asset folder.
func load_card_texture(data_key: String) -> Texture2D:
	var filename: String = "%s_card.png" % data_key
	return AssetLoader.load_texture("ships/", filename)


# ── Shared utility ───────────────────────────────────────────────────

## Recursively sets [code]mouse_filter = MOUSE_FILTER_PASS[/code] on every
## [Control] descendant of [param parent].
static func set_children_mouse_pass(parent: Control) -> void:
	for child: Node in parent.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
			ShipCardEntryBuilder.set_children_mouse_pass(child as Control)

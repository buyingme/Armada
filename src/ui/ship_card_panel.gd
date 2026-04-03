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
## Requirements: GC-005, GC-008, GC-011, GC-018, UI-002, UI-006, UI-016–023.
class_name ShipCardPanel
extends VBoxContainer


## Emitted when the player right-clicks a ship card entry to view the
## full card artwork.
## [param data_key] — the ship's data key (e.g. "cr90_corvette_a").
## [param ship_name] — the ship's display name.
## Requirements: UI-002.
signal card_detail_requested(data_key: String, ship_name: String)

## Emitted when the player clicks a damage card thumbnail to view
## the full damage card artwork in the card detail overlay.
## [param effect_id] — the damage card's effect_id (e.g. "structural_damage").
## [param card_title] — the card's display title.
signal damage_detail_requested(effect_id: String, card_title: String)

## Emitted when the player clicks a damage card to view ALL damage on the
## ship in the [DamageSummaryOverlay].
## [param ship_instance] — the ShipInstance whose damage should be shown.
signal damage_overview_requested(ship_instance: RefCounted)


## Height of damage card thumbnails in the side panel (pixels at 1× scale).
const DAMAGE_CARD_HEIGHT_PX: float = 28.0

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

## The [ShipInstance] currently in token-discard mode, or null.
## When set, the player must click one of the ship's command tokens to discard.
var _discard_mode_ship: ShipInstance = null

## Cached textures: {cache_key: Texture2D}.
var _tex_cache: Dictionary = {}

## The player index viewing this panel (for dial order modal access control).
var _viewer_player: int = -1

## Logger.
var _log: GameLogger = GameLogger.new("ShipCardPanel")


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
	left_col.add_theme_constant_override("separation", 0)
	left_col.alignment = BoxContainer.ALIGNMENT_BEGIN

	var token_col: VBoxContainer = VBoxContainer.new()
	token_col.add_theme_constant_override("separation", int(token_gap))
	token_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_populate_token_column(token_col, instance.defense_tokens, token_h)
	left_col.add_child(token_col)

	# Configurable gap between defense tokens and command dial stack.
	var dial_gap: Control = Control.new()
	dial_gap.custom_minimum_size = Vector2(
			0, GameScale.card_panel_dial_top_gap_px)
	dial_gap.mouse_filter = Control.MOUSE_FILTER_PASS
	left_col.add_child(dial_gap)

	var dial_container: VBoxContainer = VBoxContainer.new()
	dial_container.add_theme_constant_override("separation", 0)
	_populate_dial_stack(dial_container, instance, 1.0)
	left_col.add_child(dial_container)

	# --- Mouse filter setup ---
	# Child containers default to MOUSE_FILTER_STOP in Godot 4, which
	# silently consumes clicks before they reach entry_container.  Set all
	# non-dial containers to PASS so clicks propagate up for magnify.
	# The dial_container keeps STOP and has its own gui_input handler.
	left_col.mouse_filter = Control.MOUSE_FILTER_PASS
	token_col.mouse_filter = Control.MOUSE_FILTER_PASS

	# Dial container captures clicks directly for the two-step activation
	# flow and the dial-order modal — bypasses coordinate comparison.
	dial_container.mouse_filter = Control.MOUSE_FILTER_STOP
	dial_container.gui_input.connect(
			_on_dial_container_gui_input.bind(_entries.size()))

	entry_container.add_child(left_col)

	# --- Centre: ship card image ---
	var card_texture: Texture2D = _load_card_texture(instance.data_key)
	if card_texture:
		var card_rect: TextureRect = TextureRect.new()
		card_rect.texture = card_texture
		card_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_rect.custom_minimum_size = Vector2(card_w, card_h)
		card_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		entry_container.add_child(card_rect)
	else:
		var log: GameLogger = GameLogger.new("ShipCardPanel")
		log.info("No card texture found for '%s'" % instance.data_key)

	# --- Right column: command tokens ---
	var cmd_token_col: VBoxContainer = VBoxContainer.new()
	cmd_token_col.add_theme_constant_override("separation", int(token_gap))
	cmd_token_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	cmd_token_col.mouse_filter = Control.MOUSE_FILTER_PASS
	_populate_cmd_token_column(cmd_token_col, instance, 1.0)
	entry_container.add_child(cmd_token_col)

	# --- Far-right column: damage cards (faceup thumbnails + facedown badge) ---
	var damage_col: VBoxContainer = VBoxContainer.new()
	damage_col.add_theme_constant_override("separation", int(token_gap))
	damage_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	damage_col.mouse_filter = Control.MOUSE_FILTER_PASS
	_populate_damage_cards(damage_col, instance, 1.0)
	entry_container.add_child(damage_col)

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
		"dial_gap": dial_gap,
		"dial_container": dial_container,
		"cmd_token_col": cmd_token_col,
		"damage_col": damage_col,
		"magnified": false,
	})

	_connect_eventbus_signals()
	_register_hover_tooltips(_entries.back())


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

		# Damage column width.
		var dmg_col: VBoxContainer = entry.get(
				"damage_col", null) as VBoxContainer
		var dmg_col_w: float = 0.0
		if dmg_col:
			for child: Node in dmg_col.get_children():
				if child is Control:
					dmg_col_w = maxf(
							dmg_col_w, child.custom_minimum_size.x)

		var entry_w: float = col_w + token_gap + card_w
		if cmd_col_w > 0.0:
			entry_w += token_gap + cmd_col_w
		if dmg_col_w > 0.0:
			entry_w += token_gap + dmg_col_w
		max_w = maxf(max_w, entry_w)
		total_h += card_h
		if i > 0:
			total_h += entry_gap

	return Vector2(max_w, total_h)


## Handles left-click on a ship card entry to toggle magnify, and
## right-click to request the full card detail overlay.
## Dial clicks are routed to [method _on_dial_container_gui_input] instead.
## Blocked during discard mode to prevent the token column from being
## repopulated (which would wipe out the clickable discard UI).
## Requirements: UI-002, UI-018.
func _on_entry_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if index < 0 or index >= _entries.size():
		return
	# Right-click → show card detail overlay (UI-002).
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		var entry: Dictionary = _entries[index]
		var inst: ShipInstance = entry["instance"]
		card_detail_requested.emit(inst.data_key,
				inst.ship_data.ship_name)
		accept_event()
		return
	# Left-click → toggle magnify.
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# Block magnify while a discard choice is pending.
	if _discard_mode_ship != null:
		_log.info("Magnify blocked — token discard pending.")
		return
	_toggle_magnify(index)


## Handles left-click on a ship's dial container.
## Godot routes clicks to this handler via the dial_container's own
## [code]gui_input[/code] connection (MOUSE_FILTER_STOP).  This avoids
## manual coordinate comparisons that fail when global_position and
## get_global_rect() use different coordinate spaces (CanvasLayer +
## canvas_items stretch mode).
## Blocked during discard mode to prevent new activations.
## Requirements: UI-022, UI-023.
func _on_dial_container_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if index < 0 or index >= _entries.size():
		return
	# Block dial interaction while a discard choice is pending.
	if _discard_mode_ship != null:
		_log.info("Dial click blocked — token discard pending.")
		return
	_handle_dial_stack_click(_entries[index])


## Handles click on a ship's dial stack. During Ship Phase this implements
## a two-step activation flow:
##   1. First click: reveal the top dial (face-up on the stack).
##   2. Second click: start the drag with the already-revealed dial.
## Outside Ship Phase, opens the dial order modal.
## Rules Reference: UI-022 — click own stack to open dial order.
## Rules Reference: UI-023 — cannot view opponent's unrevealed dials.
## Rules Reference: UI-024 — drag topmost dial to activate during Ship Phase.
func _handle_dial_stack_click(entry: Dictionary) -> void:
	var instance: ShipInstance = entry["instance"]
	# Only allow viewing own ship's dials.
	if _viewer_player >= 0 and instance.owner_player != _viewer_player:
		_log.info("Dial click ignored — viewer %d, owner %d." \
				% [_viewer_player, instance.owner_player])
		return

	# Ship Phase two-step: (1) click reveals dial, (2) click starts drag.
	if _is_ship_phase_eligible(instance):
		var revealed: Dictionary = instance.command_dial_stack \
				.get_revealed_dial()
		if not revealed.is_empty():
			# Step 2: dial already revealed → start drag.
			_log.info("Dial step 2 — emitting drag_started for '%s'." \
					% instance.data_key)
			EventBus.dial_drag_started.emit(instance)
			return
		if instance.command_dial_stack.get_hidden_count() > 0:
			# Unreveal any other ship's dial first (player changed their mind).
			_unreveal_other_ships(instance)
			# Step 1: reveal the top dial (stays on stack).
			_log.info("Dial step 1 — revealing top for '%s'." \
					% instance.data_key)
			instance.command_dial_stack.reveal_top()
			EventBus.command_dials_changed.emit(instance)
			return
		_log.info("Dial click on '%s' — eligible but no revealed/hidden dials." \
				% instance.data_key)
	else:
		_log.info("Dial click on '%s' — not eligible (phase=%d, active=%d, " \
				% [instance.data_key,
					int(GameManager.get_current_phase()),
					GameManager.get_active_player()]
				+"activated=%s, stack=%s, activating=%s)." \
				% [str(instance.activated_this_round),
					str(instance.command_dial_stack != null),
					str(GameManager.get_activating_ship() != null)])

	EventBus.command_dial_order_requested.emit(instance)


## Returns true if the ship is eligible for Ship Phase activation.
## Used by the two-step reveal-then-drag flow. Does NOT check whether
## hidden dials remain (the revealed dial counts as available).
## Requirements: UI-024.
func _is_ship_phase_eligible(instance: ShipInstance) -> bool:
	if GameManager.get_current_phase() != Constants.GamePhase.SHIP:
		return false
	if instance.owner_player != GameManager.get_active_player():
		return false
	if instance.activated_this_round:
		return false
	if instance.command_dial_stack == null:
		return false
	if GameManager.get_activating_ship() != null:
		return false
	return true


## Unreveals any other ship's revealed dial before starting step 1 on a
## different ship (player changed their mind).
func _unreveal_other_ships(current: ShipInstance) -> void:
	for entry: Dictionary in _entries:
		var inst: ShipInstance = entry["instance"]
		if inst == current:
			continue
		if inst.command_dial_stack == null:
			continue
		var rev: Dictionary = inst.command_dial_stack.get_revealed_dial()
		if not rev.is_empty():
			inst.command_dial_stack.unreveal_top()
			_log.info("Unrevealed stale dial on '%s'." % inst.data_key)
			EventBus.command_dials_changed.emit(inst)


## Returns true if a dial drag can be started for this ship.
## Conditions: Ship Phase, ship owned by active player, not activated,
## has hidden dials, and no other ship is currently being activated.
## Requirements: UI-024.
func _can_start_dial_drag(instance: ShipInstance) -> bool:
	if not _is_ship_phase_eligible(instance):
		return false
	if instance.command_dial_stack.get_hidden_count() == 0:
		return false
	return true


# ------------------------------------------------------------------
# Hover tooltip callbacks (TT-080–086)
# ------------------------------------------------------------------

## Registers the dial_container and entry_container of [param entry]
## with [TooltipManager] for context-sensitive hover hints.
## Requirements: TT-012, TT-080–086.
func _register_hover_tooltips(entry: Dictionary) -> void:
	var tm: Node = get_node_or_null("/root/TooltipManager")
	if tm == null:
		return
	var dial_cont: Control = entry["dial_container"] as Control
	var entry_cont: Control = entry["container"] as Control
	tm.register(dial_cont, _dial_tooltip_text.bind(entry))
	tm.register(entry_cont, _card_tooltip_text.bind(entry))


## Returns tooltip text for the command dial stack area.
## Evaluates current game state to decide which hint to show.
## Requirements: TT-080–084.
func _dial_tooltip_text(entry: Dictionary) -> String:
	# TT-084 — suppress during discard mode.
	if _discard_mode_ship != null:
		return ""
	var instance: ShipInstance = entry["instance"]
	# TT-083 — suppress for opponent’s ships.
	if _viewer_player >= 0 and instance.owner_player != _viewer_player:
		return ""
	# TT-080 / TT-081 — Ship Phase activation context.
	if _is_ship_phase_eligible(instance):
		var revealed: Dictionary = instance.command_dial_stack \
				.get_revealed_dial()
		if not revealed.is_empty():
			# TT-081: dial already revealed → drag instructions.
			return "Drag to ship for full command\nDrag to card for command token"
		if instance.command_dial_stack.get_hidden_count() > 0:
			# TT-080: unrevealed dials → click to reveal.
			return "Click to reveal dial\nand activate ship"
	# TT-082 — fallthrough: not eligible or not Ship Phase.
	return "Click to show\ncommand stack order"


## Returns tooltip text for the ship card entry area (magnify toggle).
## Requirements: TT-085–086.
func _card_tooltip_text(entry: Dictionary) -> String:
	# TT-086 — suppress during discard mode.
	if _discard_mode_ship != null:
		return ""
	# TT-085 — magnify affordance.
	return "Click to magnify"


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

	# Scale the token-to-dial spacer.
	var gap_ctrl: Control = entry["dial_gap"] as Control
	gap_ctrl.custom_minimum_size = Vector2(
			0, GameScale.card_panel_dial_top_gap_px * scale_factor)

	# Re-populate command token column at new scale.
	var cmd_col: VBoxContainer = entry["cmd_token_col"]
	_populate_cmd_token_column(cmd_col, instance, scale_factor)

	# Re-populate damage card column at new scale.
	var dmg_col: VBoxContainer = entry.get(
			"damage_col", null) as VBoxContainer
	if dmg_col:
		_populate_damage_cards(dmg_col, instance, scale_factor)


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
	if not EventBus.token_discard_required.is_connected(
			_on_token_discard_required):
		EventBus.token_discard_required.connect(
				_on_token_discard_required)
	if not EventBus.duplicate_token_discarded.is_connected(
			_on_duplicate_token_discarded):
		EventBus.duplicate_token_discarded.connect(
				_on_duplicate_token_discarded)
	if not EventBus.navigate_token_spend_preview.is_connected(
			_on_navigate_token_spend_preview):
		EventBus.navigate_token_spend_preview.connect(
				_on_navigate_token_spend_preview)
	if not EventBus.damage_card_dealt.is_connected(
			_on_damage_cards_changed):
		EventBus.damage_card_dealt.connect(_on_damage_cards_changed)
	if not EventBus.damage_card_flipped.is_connected(
			_on_damage_cards_changed):
		EventBus.damage_card_flipped.connect(_on_damage_cards_changed)
	if not EventBus.repair_card_discarded.is_connected(
			_on_damage_card_repaired):
		EventBus.repair_card_discarded.connect(_on_damage_card_repaired)


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


## EventBus callback: Navigate token spend preview changed.
## Applies or removes a reddish overlay on the Navigate command token.
## Requirements: NAV-007, AC-5b-07.
func _on_navigate_token_spend_preview(inst: RefCounted, would_spend: bool) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] != inst:
			continue
		var col: VBoxContainer = entry["cmd_token_col"] as VBoxContainer
		var ship: ShipInstance = entry["instance"] as ShipInstance
		if ship == null or ship.command_tokens == null:
			break
		var tokens: Array[int] = ship.command_tokens.get_tokens()
		# Find the Navigate token's TextureRect in the column.
		var nav_index: int = -1
		for i: int in range(tokens.size()):
			if tokens[i] == Constants.CommandType.NAVIGATE:
				nav_index = i
				break
		if nav_index < 0 or nav_index >= col.get_child_count():
			break
		var rect: Control = col.get_child(nav_index)
		if would_spend:
			rect.modulate = Color(1.0, 0.4, 0.4, 0.85)
		else:
			rect.modulate = Color.WHITE
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
# Token Discard Mode
# ---------------------------------------------------------------------------


## Returns whether this panel is currently waiting for a discard click.
func is_in_discard_mode() -> bool:
	return _discard_mode_ship != null


## EventBus callback: a ship needs to discard a command token (overflow).
func _on_token_discard_required(inst: RefCounted) -> void:
	# Only enter discard mode if this panel owns the ship.
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			_enter_discard_mode(entry)
			break


## EventBus callback: a duplicate token was auto-discarded.
## Shows a brief notification near the ship's command-token column.
func _on_duplicate_token_discarded(inst: RefCounted, token_type: int) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			_show_duplicate_toast(entry, token_type)
			break


## Shows a brief "Duplicate discarded" tooltip that auto-hides after 2 seconds.
## Migrated from ad-hoc Label to TooltipManager (TT-053).
func _show_duplicate_toast(entry: Dictionary, token_type: int) -> void:
	var cmd_name: String = Constants.CommandType.keys()[token_type]
	var text: String = "Duplicate\n%s\ndiscarded" % cmd_name.to_lower().capitalize()
	var tm: Node = Engine.get_singleton("TooltipManager") if Engine.has_singleton("TooltipManager") else get_node_or_null("/root/TooltipManager")
	if tm:
		tm.show_text(text, Vector2.INF, 2.0)
	_log.info("Showing duplicate discard toast for %s (%s)" % [
			(entry["instance"] as ShipInstance).data_key, cmd_name])


## Puts the command-token column of [param entry] into discard mode.
## Each token becomes clickable (MOUSE_FILTER_STOP) and a prompt is shown
## via the TooltipManager.
func _enter_discard_mode(entry: Dictionary) -> void:
	var ship: ShipInstance = entry["instance"] as ShipInstance
	_discard_mode_ship = ship

	var col: VBoxContainer = entry["cmd_token_col"] as VBoxContainer

	# Show discard prompt via TooltipManager (TT-053).
	# force=true because the discard prompt is essential gameplay instruction.
	var tm: Node = Engine.get_singleton("TooltipManager") if Engine.has_singleton("TooltipManager") else get_node_or_null("/root/TooltipManager")
	if tm:
		tm.show_text("Discard\na token", Vector2.INF, 0.0, true)

	# Make each token TextureRect clickable.
	for child: Node in col.get_children():
		if child is TextureRect:
			var tex_rect: TextureRect = child as TextureRect
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			tex_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			tex_rect.modulate = Color(1.0, 0.8, 0.8)
			if not tex_rect.gui_input.is_connected(_on_discard_token_click):
				tex_rect.gui_input.connect(
						_on_discard_token_click.bind(tex_rect))

	_log.info("Entered discard mode for %s" % ship.data_key)


## Exits discard mode and restores normal token display.
func _exit_discard_mode() -> void:
	if _discard_mode_ship == null:
		return

	for entry: Dictionary in _entries:
		if entry["instance"] == _discard_mode_ship:
			var col: VBoxContainer = entry["cmd_token_col"] as VBoxContainer
			# Hide the tooltip prompt (TT-053).
			var tm: Node = Engine.get_singleton("TooltipManager") if Engine.has_singleton("TooltipManager") else get_node_or_null("/root/TooltipManager")
			if tm:
				tm.hide_tooltip()
			# Restore normal mouse behaviour on tokens.
			for child: Node in col.get_children():
				if child is TextureRect:
					var tex_rect: TextureRect = child as TextureRect
					tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
					tex_rect.mouse_default_cursor_shape = Control.CURSOR_ARROW
					tex_rect.modulate = Color.WHITE
					if tex_rect.gui_input.is_connected(
							_on_discard_token_click):
						tex_rect.gui_input.disconnect(
								_on_discard_token_click)
			break

	_log.info("Exited discard mode for %s" % _discard_mode_ship.data_key)
	_discard_mode_ship = null


## Handles a click on a token TextureRect while in discard mode.
## Determines which command type the clicked token represents, removes it,
## and emits the appropriate EventBus signals.
func _on_discard_token_click(event: InputEvent,
		tex_rect: TextureRect) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _discard_mode_ship == null:
		return

	# Determine the command type from the token's index in the column.
	var col: VBoxContainer = tex_rect.get_parent() as VBoxContainer
	if col == null:
		return
	# The first child may be the DiscardPrompt label — skip it.
	var token_index: int = -1
	var idx: int = 0
	for child: Node in col.get_children():
		if child is TextureRect:
			if child == tex_rect:
				token_index = idx
				break
			idx += 1

	var tokens: Array[int] = _discard_mode_ship.command_tokens.get_tokens()
	if token_index < 0 or token_index >= tokens.size():
		_log.warn("Discard click — invalid token index %d" % token_index)
		return

	var cmd_type: int = tokens[token_index]
	_discard_mode_ship.command_tokens.remove_token(cmd_type)
	_log.info("Player discarded token %d from %s" % [
			cmd_type, _discard_mode_ship.data_key])

	var ship_ref: ShipInstance = _discard_mode_ship
	_exit_discard_mode()

	EventBus.command_tokens_changed.emit(ship_ref)
	EventBus.token_discarded.emit(ship_ref, cmd_type)


# ---------------------------------------------------------------------------
# Populate helpers
# ---------------------------------------------------------------------------


## Recursively sets [code]mouse_filter = MOUSE_FILTER_PASS[/code] on every
## [Control] descendant of [param parent].  This ensures dynamically created
## children (TextureRect, VBoxContainer, plain Control) do not silently
## consume clicks (Godot 4 defaults to MOUSE_FILTER_STOP).
func _set_children_mouse_pass(parent: Control) -> void:
	for child: Node in parent.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
			_set_children_mouse_pass(child as Control)


## Fills a token column container with defense token TextureRect sprites.
## Clears existing children first.
## [param token_h] — the display height for each token sprite.
func _populate_token_column(col: VBoxContainer,
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
	_set_children_mouse_pass(col)


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

	# Use a zero-spacing outer container so we can control the gap between
	# the active stack and the spent dial precisely.
	container.add_theme_constant_override("separation", 0)

	# --- Active dial stack with negative overlap ---
	# Revealed dial (if any) is shown face-up on top; hidden dials below.
	var active_stack: VBoxContainer = VBoxContainer.new()
	active_stack.add_theme_constant_override("separation", -offset)
	# Centre the stack within the parent (which may be wider than dial_w
	# when defence tokens are wider).  SIZE_SHRINK_CENTER keeps it at
	# custom_minimum_size width and centres horizontally.
	active_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Show the revealed dial face-up on top of the stack (two-step flow).
	if not revealed.is_empty():
		var cmd: int = int(revealed.get("command", 0))
		var rect: Control = _create_dial_rect(cmd, true, dial_w, dial_h)
		active_stack.add_child(rect)

	# Render hidden dials — ALL use cmd_dial_hidden.png (facedown).
	# Rules Reference: CP-006 — dials are facedown.
	for i: int in range(hidden_dials.size()):
		var rect: Control = _create_dial_rect(
				0, false, dial_w, dial_h)
		active_stack.add_child(rect)

	# In a VBoxContainer with negative separation, later children draw on
	# top of earlier ones.  We want the first child (top of the physical
	# stack) to appear in front, so give it the highest z_index.
	var child_count: int = active_stack.get_child_count()
	for i: int in range(child_count):
		active_stack.get_child(i).z_index = child_count - i

	# Set the active stack's minimum size so Containers allocate correct
	# space.  Do NOT set .size — that overrides the parent Container's
	# layout-managed width (which may be wider than dial_w when defense
	# tokens are wider) and causes the stack to jump left on reveal.
	var total_dials: int = (0 if revealed.is_empty() else 1) + hidden_dials.size()
	var stack_h: float = 0.0
	if total_dials > 0:
		stack_h = dial_h + maxf(0, total_dials - 1) * (dial_h - float(offset))
	active_stack.custom_minimum_size = Vector2(dial_w, stack_h)

	container.add_child(active_stack)

	# --- Spent dial (activation marker) — below stack with ~0.5 cm gap ---
	var total_container_h: float = stack_h
	if not spent_marker.is_empty():
		var spent_gap_px: float = 12.0 * scale_factor
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, spent_gap_px)
		container.add_child(spacer)
		var spent_rect: Control = _create_dial_rect(
				int(spent_marker.get("command", 0)), true, dial_w, dial_h)
		spent_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(spent_rect)
		total_container_h += spent_gap_px + dial_h

	# Set minimum size so parent Containers allocate correct space.
	# Do NOT set .size — see active_stack comment above.
	container.custom_minimum_size = Vector2(dial_w, total_container_h)

	# Let clicks on children propagate up to dial_container's gui_input.
	_set_children_mouse_pass(container)


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
	_set_children_mouse_pass(col)


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


# ---------------------------------------------------------------------------
# Damage card column
# ---------------------------------------------------------------------------

## Loads (or returns cached) the texture for a faceup damage card.
## File naming convention: damage_<effect_id>.png
func _get_damage_card_texture(effect_id: String) -> Texture2D:
	var cache_key: String = "dmg_" + effect_id
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var filename: String = "damage_%s.png" % effect_id
	var tex: Texture2D = AssetLoader.load_texture(
			"damage_deck/", filename)
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Loads (or returns cached) the damage card back texture.
func _get_damage_back_texture() -> Texture2D:
	var cache_key: String = "dmg_back"
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var tex: Texture2D = AssetLoader.load_texture(
			"damage_deck/", "damage_back.png")
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Rebuilds the damage card column for a ship entry.
## Shows one thumbnail per faceup card (right-clickable for detail)
## and a single card-back badge with ×N count for facedown cards.
## [param col] — the VBoxContainer to populate.
## [param instance] — the ShipInstance whose damage to display.
## [param scale_factor] — current magnify scale (1.0 or magnify_factor).
func _populate_damage_cards(col: VBoxContainer,
		instance: ShipInstance, scale_factor: float) -> void:
	for child: Node in col.get_children():
		col.remove_child(child)
		child.queue_free()

	var dmg_h: float = DAMAGE_CARD_HEIGHT_PX * scale_factor
	var faceup: Array = instance.faceup_damage
	var facedown_count: int = instance.facedown_damage.size()
	_log.info("Populating damage col for '%s': %d faceup, %d facedown"
			% [instance.ship_data.ship_name, faceup.size(),
				facedown_count])

	# -- Faceup card thumbnails --
	for card: RefCounted in faceup:
		var tex: Texture2D = _get_damage_card_texture(card.effect_id)
		if tex == null:
			continue
		var rect: TextureRect = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var t_aspect: float = (
				float(tex.get_width())
				/ maxf(float(tex.get_height()), 1.0))
		var tw: float = dmg_h * t_aspect
		rect.custom_minimum_size = Vector2(tw, dmg_h)
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		rect.tooltip_text = card.title
		rect.gui_input.connect(
				_on_damage_card_click.bind(card, instance))
		col.add_child(rect)

	# -- Facedown counter badge --
	var bw: float = 0.0
	if facedown_count > 0:
		var badge: HBoxContainer = HBoxContainer.new()
		badge.add_theme_constant_override("separation", 2)

		var back_tex: Texture2D = _get_damage_back_texture()
		if back_tex:
			var back_rect: TextureRect = TextureRect.new()
			back_rect.texture = back_tex
			back_rect.expand_mode = (
					TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL)
			back_rect.stretch_mode = (
					TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
			var b_aspect: float = (
					float(back_tex.get_width())
					/ maxf(float(back_tex.get_height()), 1.0))
			bw = dmg_h * b_aspect
			back_rect.custom_minimum_size = Vector2(bw, dmg_h)
			badge.add_child(back_rect)

		var label: Label = Label.new()
		label.text = "×%d" % facedown_count
		var font_sz: int = int(dmg_h * 0.55)
		label.add_theme_font_size_override("font_size", font_sz)
		label.add_theme_color_override(
				"font_color", Color.WHITE)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(label)

		# Compute badge minimum width so _compute_panel_size() can
		# account for the full damage column (prevents ×N clipping).
		var badge_w: float = bw + 2.0 + font_sz * 1.5
		badge.custom_minimum_size = Vector2(badge_w, dmg_h)
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.gui_input.connect(
				_on_facedown_badge_click.bind(instance))
		col.add_child(badge)

	# Set badge and its children to PASS so clicks propagate up.
	# Faceup TextureRects already have MOUSE_FILTER_STOP set above;
	# we must NOT call _set_children_mouse_pass(col) here because it
	# would wipe their STOP and break right-click capture.
	for child: Node in col.get_children():
		if child is HBoxContainer:
			# Badge children (TextureRect + Label) should be PASS so
			# the click goes to the badge's own gui_input handler.
			_set_children_mouse_pass(child as Control)


## Handles click on a faceup damage card thumbnail to open the
## card detail overlay showing the full damage card art.
## Both left-click and right-click trigger the overlay.
## Rules Reference: "Damage Cards" — players may inspect faceup cards.
func _on_damage_card_click(event: InputEvent,
		card: RefCounted, ship_instance: RefCounted) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT \
			and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_log.info("Damage overview requested for '%s' via card '%s'."
			% [ship_instance.ship_data.ship_name, card.title])
	damage_overview_requested.emit(ship_instance)
	# Stop propagation so the entry container does not also fire
	# its own card_detail_requested for the ship card or toggle magnify.
	get_viewport().set_input_as_handled()


## Handles click on the facedown damage badge to show all damage cards
## on the ship in the [DamageSummaryOverlay].
func _on_facedown_badge_click(event: InputEvent,
		ship_instance: RefCounted) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT \
			and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	_log.info("Damage overview requested for '%s' via facedown badge."
			% ship_instance.ship_data.ship_name)
	damage_overview_requested.emit(ship_instance)
	get_viewport().set_input_as_handled()


## Called when a damage card is dealt or flipped — refreshes the
## damage column for the affected ship entry.
## [param ship_instance] — the ShipInstance that changed.
## [param _card] — the DamageCard (unused).
## [param _is_faceup] — faceup state (unused).
func _on_damage_cards_changed(ship_instance: RefCounted,
		_card: RefCounted, _is_faceup: bool) -> void:
	_refresh_damage_for_ship(ship_instance)


## Called when a damage card is repaired/discarded — refreshes the
## damage column for the affected ship entry.
## [param ship_instance] — the ShipInstance that changed.
## [param _card] — the DamageCard that was discarded (unused).
func _on_damage_card_repaired(ship_instance: RefCounted,
		_card: RefCounted) -> void:
	_refresh_damage_for_ship(ship_instance)


## Internal helper — finds the matching entry for [param ship_instance]
## and rebuilds its damage column at the current scale.
func _refresh_damage_for_ship(ship_instance: RefCounted) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == ship_instance:
			var inst: ShipInstance = entry["instance"] as ShipInstance
			_log.info("Refreshing damage column for '%s' "
					% inst.ship_data.ship_name
					+"(faceup=%d, facedown=%d)"
					% [inst.faceup_damage.size(),
						inst.facedown_damage.size()])
			var scale_factor: float = (
					GameScale.card_panel_magnify_factor
					if entry["magnified"] else 1.0)
			_populate_damage_cards(
					entry["damage_col"] as VBoxContainer,
					entry["instance"] as ShipInstance,
					scale_factor)
			_refresh_panel_position()
			return

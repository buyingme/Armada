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

## Emitted when the player clicks a damage card to view ALL damage on the
## ship in the [DamageSummaryOverlay].
## [param ship_instance] — the ShipInstance whose damage should be shown.
signal damage_overview_requested(ship_instance: RefCounted)


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

## Entry builder delegate (refactoring Phase D3).
var _builder: ShipCardEntryBuilder

## Damage card display delegate (refactoring Phase D3).
var _damage_display: DamageCardDisplay


## Creates a ShipCardPanel for the given faction.
## [param faction] — Rebel or Imperial.
## [param left_side] — true for left-side placement (Rebel), false for right.
## [param viewer] — the player index viewing this panel (for opponent restriction).
func setup(faction: Constants.Faction, left_side: bool,
		viewer: int = -1) -> void:
	_faction = faction
	_is_left_side = left_side
	_viewer_player = viewer
	_builder = ShipCardEntryBuilder.new(_tex_cache)
	_damage_display = DamageCardDisplay.new(_tex_cache, self)
	_damage_display.damage_overview_requested.connect(
			_on_damage_overview_from_display)
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
	var token_gap: float = GameScale.card_panel_token_gap_px
	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation",
			int(token_gap))
	var left: Dictionary = _build_left_column(instance, token_gap)
	entry_container.add_child(left["left_col"])
	var card_image: Control = _build_card_image(instance)
	if card_image:
		entry_container.add_child(card_image)
	var cmd_token_col: VBoxContainer = _build_right_column(
			instance, token_gap, "cmd_token")
	entry_container.add_child(cmd_token_col)
	var damage_col: VBoxContainer = _build_right_column(
			instance, token_gap, "damage")
	entry_container.add_child(damage_col)
	_register_entry(entry_container, instance, left, cmd_token_col,
			damage_col)


## Builds the left column: defense tokens, dial gap, and dial stack.
## Delegates to [ShipCardEntryBuilder] and wires the dial gui_input.
func _build_left_column(instance: ShipInstance,
		token_gap: float) -> Dictionary:
	var result: Dictionary = _builder.build_left_column(instance, token_gap)
	result["dial_container"].gui_input.connect(
			_on_dial_container_gui_input.bind(_entries.size()))
	return result


## Creates the ship card image TextureRect (or null if no texture found).
## Delegates to [ShipCardEntryBuilder].
func _build_card_image(instance: ShipInstance) -> Control:
	return _builder.build_card_image(instance)


## Builds a right-side column (command tokens or damage cards).
## Delegates to [ShipCardEntryBuilder] for structure, then populates.
func _build_right_column(instance: ShipInstance,
		token_gap: float, kind: String) -> VBoxContainer:
	var col: VBoxContainer = _builder.build_column(token_gap)
	if kind == "cmd_token":
		_builder.populate_cmd_token_column(col, instance, 1.0)
	else:
		_damage_display.populate_damage_cards(col, instance, 1.0)
	return col


## Registers a fully-built entry in the _entries array and wires signals.
func _register_entry(entry_container: HBoxContainer,
		instance: ShipInstance, left: Dictionary,
		cmd_token_col: VBoxContainer,
		damage_col: VBoxContainer) -> void:
	entry_container.mouse_filter = Control.MOUSE_FILTER_STOP
	entry_container.gui_input.connect(
			_on_entry_gui_input.bind(_entries.size()))
	add_child(entry_container)
	_entries.append({
		"instance": instance,
		"container": entry_container,
		"left_col": left["left_col"],
		"token_col": left["token_col"],
		"dial_gap": left["dial_gap"],
		"dial_container": left["dial_container"],
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
		var entry_w: float = _compute_entry_width(
				entry, factor, token_gap, card_w)
		max_w = maxf(max_w, entry_w)
		total_h += card_h
		if i > 0:
			total_h += entry_gap

	return Vector2(max_w, total_h)


## Computes the total width of a single ship entry row, summing the left
## token/dial column, the card, the command-token column, and the damage
## column (if present).  Delegates to [ShipCardEntryBuilder].
func _compute_entry_width(entry: Dictionary, factor: float,
		token_gap: float, card_w: float) -> float:
	return _builder.compute_entry_width(entry, factor, token_gap, card_w)


## Returns the maximum [member custom_minimum_size].x among [TextureRect]
## children of [param container].  Delegates to [ShipCardEntryBuilder].
func _max_child_width(container: Control) -> float:
	return _builder.max_child_width(container)


## Returns the maximum [member custom_minimum_size].x among [Control]
## children of [param container].  Delegates to [ShipCardEntryBuilder].
func _max_child_width_control(container: Control) -> float:
	return _builder.max_child_width_control(container)


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
	if _viewer_player >= 0 and instance.owner_player != _viewer_player:
		_log.info("Dial click ignored — viewer %d, owner %d." \
				% [_viewer_player, instance.owner_player])
		return
	if _try_ship_phase_activation(instance):
		return
	if not _is_ship_phase_eligible(instance):
		_log_ineligible_dial_click(instance)
	EventBus.command_dial_order_requested.emit(instance)


## Attempts the two-step Ship Phase dial flow (reveal, then drag).
## Returns true if the click was handled.
func _try_ship_phase_activation(instance: ShipInstance) -> bool:
	if not _is_ship_phase_eligible(instance):
		return false
	var revealed: Dictionary = instance.command_dial_stack \
			.get_revealed_dial()
	if not revealed.is_empty():
		_log.info("Dial step 2 — emitting drag_started for '%s'." \
				% instance.data_key)
		EventBus.dial_drag_started.emit(instance)
		return true
	if instance.command_dial_stack.get_hidden_count() > 0:
		_unreveal_other_ships(instance)
		_log.info("Dial step 1 — revealing top for '%s'." \
				% instance.data_key)
		instance.command_dial_stack.reveal_top()
		EventBus.command_dials_changed.emit(instance)
		return true
	_log.info("Dial click on '%s' — eligible but no revealed/hidden dials." \
			% instance.data_key)
	return false


## Logs detailed diagnostics for an ineligible dial click.
func _log_ineligible_dial_click(instance: ShipInstance) -> void:
	_log.info("Dial click on '%s' — not eligible (phase=%d, active=%d, " \
			% [instance.data_key,
				int(GameManager.get_current_phase()),
				GameManager.get_active_player()]
			+"activated=%s, stack=%s, activating=%s)." \
			% [str(instance.activated_this_round),
				str(instance.command_dial_stack != null),
				str(GameManager.get_activating_ship() != null)])


## Returns true if the ship is eligible for Ship Phase activation.
## Used by the two-step reveal-then-drag flow. Does NOT check whether
## hidden dials remain (the revealed dial counts as available).
## Requirements: UI-024.
func _is_ship_phase_eligible(instance: ShipInstance) -> bool:
	if instance.is_destroyed():
		return false
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
## multiplied by [param scale_factor].  Delegates to helpers.
func _apply_entry_size(entry: Dictionary,
		scale_factor: float) -> void:
	_builder.apply_entry_size(entry, scale_factor)
	# Re-populate damage card column at new scale.
	var dmg_col: VBoxContainer = entry.get(
			"damage_col", null) as VBoxContainer
	if dmg_col:
		_damage_display.populate_damage_cards(dmg_col,
				entry["instance"] as ShipInstance, scale_factor)


# ---------------------------------------------------------------------------
# EventBus connections
# ---------------------------------------------------------------------------

## Connects EventBus signals (idempotent).
func _connect_eventbus_signals() -> void:
	_safe_connect(EventBus.ship_defense_token_changed,
			_on_defense_tokens_changed)
	_safe_connect(EventBus.command_dials_changed,
			_on_command_dials_changed)
	_safe_connect(EventBus.command_tokens_changed,
			_on_command_tokens_changed)
	_safe_connect(EventBus.token_discard_required,
			_on_token_discard_required)
	_safe_connect(EventBus.duplicate_token_discarded,
			_on_duplicate_token_discarded)
	_safe_connect(EventBus.navigate_token_spend_preview,
			_on_navigate_token_spend_preview)
	_safe_connect(EventBus.damage_card_dealt,
			_on_damage_cards_changed)
	_safe_connect(EventBus.damage_card_flipped,
			_on_damage_cards_changed)
	_safe_connect(EventBus.repair_card_discarded,
			_on_damage_card_repaired)
	_safe_connect(EventBus.ship_destroyed,
			_on_ship_destroyed)


## Connects a signal to a callback if not already connected.
func _safe_connect(sig: Signal, callback: Callable) -> void:
	if not sig.is_connected(callback):
		sig.connect(callback)


## EventBus callback: a ship is destroyed — ghost the entire card entry.
## Dims the row to 35 % opacity, overlays a red "DESTROYED" label,
## and blocks further interaction (magnify, dial clicks, discard clicks).
## Rules Reference: "Destroyed Ships and Squadrons", RRG p.7 —
## "All ship and upgrade cards belonging to destroyed ships are inactive."
func _on_ship_destroyed(ship_node: Node) -> void:
	if not ship_node.has_method("get_ship_instance"):
		return
	var inst: ShipInstance = ship_node.get_ship_instance()
	if inst == null:
		return
	for entry: Dictionary in _entries:
		if entry["instance"] != inst:
			continue
		_ghost_entry(entry)
		break


## Applies the ghost (destroyed) visual to a single card-panel entry.
## Dims the entire row and overlays a "DESTROYED" banner.
func _ghost_entry(entry: Dictionary) -> void:
	var container: HBoxContainer = entry["container"]
	# Skip if already ghosted.
	if entry.get("ghosted", false):
		return
	entry["ghosted"] = true
	# Dim the entire entry.
	container.modulate = Color(1.0, 1.0, 1.0, 0.35)
	# Block all mouse interaction.
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in container.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Overlay a red "DESTROYED" label.
	var lbl: Label = Label.new()
	lbl.text = "DESTROYED"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(lbl)
	_log.info("Ghosted card panel entry for '%s'."
			% (entry["instance"] as ShipInstance).data_key)


## EventBus callback: a ship's defense token state changed.
func _on_defense_tokens_changed(inst: RefCounted) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			var col: VBoxContainer = entry["token_col"]
			var si: ShipInstance = entry["instance"]
			var token_h: float = GameScale.card_panel_token_height_px
			if entry["magnified"]:
				token_h *= GameScale.card_panel_magnify_factor
			_builder.populate_token_column(col, si.defense_tokens, token_h)
			break


## EventBus callback: a ship's command dials changed.
func _on_command_dials_changed(inst: RefCounted) -> void:
	for entry: Dictionary in _entries:
		if entry["instance"] == inst:
			var factor: float = (
					GameScale.card_panel_magnify_factor
					if entry["magnified"] else 1.0)
			_builder.populate_dial_stack(
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
			_builder.populate_cmd_token_column(
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

	var token_index: int = _find_token_index_in_column(tex_rect)
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


## Finds the zero-based token index of [param tex_rect] among the
## [TextureRect] children of its parent column. Returns -1 if not found.
## The first child may be a DiscardPrompt label — non-TextureRect children
## are skipped.
func _find_token_index_in_column(tex_rect: TextureRect) -> int:
	var col: VBoxContainer = tex_rect.get_parent() as VBoxContainer
	if col == null:
		return -1
	var idx: int = 0
	for child: Node in col.get_children():
		if child is TextureRect:
			if child == tex_rect:
				return idx
			idx += 1
	return -1


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

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


## Bridge: relays [DamageCardDisplay.damage_overview_requested] to the
## panel's own [signal damage_overview_requested].
func _on_damage_overview_from_display(ship_instance: RefCounted) -> void:
	damage_overview_requested.emit(ship_instance)


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
			_damage_display.populate_damage_cards(
					entry["damage_col"] as VBoxContainer,
					entry["instance"] as ShipInstance,
					scale_factor)
			_refresh_panel_position()
			return

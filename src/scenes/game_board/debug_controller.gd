## Manages debug-mode UI overlays and interactions on the game board.
##
## Owns the deployment zone overlay, the DEBUG HUD label, the debug help
## panel, and the scenario saver.  Extracted from game_board.gd as part of
## refactoring phase C4.
class_name DebugController
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

# (none — debug controller does not need outward signals)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Deployment zone overlay (visible in debug mode only).
var _deploy_overlay: DeploymentZoneOverlay = null

## Debug HUD label (shows "DEBUG" in top-left corner).
var _debug_label: Label = null

## Debug help panel showing all keyboard shortcuts.
var _debug_help_panel: DebugHelpPanel = null

## Tracks whether the currently dragged token was inside its deployment zone
## on the previous frame, so the toast fires only on crossing (DBG-033).
var _was_in_deploy_zone: bool = true

## Scenario saver utility.
var _scenario_saver: ScenarioSaver = ScenarioSaver.new()

## Reference to the game board node (needed as parent for the overlay).
var _board: Node2D = null

## Callable that returns Array[ShipToken] — avoids direct dependency on
## game_board's internals.
var _get_ship_tokens: Callable

## Callable that returns Array[SquadronToken].
var _get_squadron_tokens: Callable

## Logger instance.
var _log: GameLogger = GameLogger.new("DebugController")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Creates debug UI elements and connects DebugMode signals.
## [param board] — the game-board Node2D (parent for the deploy overlay).
## [param get_ships] — callable returning Array[ShipToken].
## [param get_squads] — callable returning Array[SquadronToken].
func initialize(board: Node2D, get_ships: Callable, get_squads: Callable) -> void:
	_board = board
	_get_ship_tokens = get_ships
	_get_squadron_tokens = get_squads

	_create_deploy_overlay()
	_create_debug_hud()
	_connect_signals()
	_update_debug_visibility()


## Handles left-click in debug mode: clicks on empty space deselect.
## DBG-010 — left-click empty space deselects.
func handle_debug_click(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# If we have a selection and clicked empty space, deselect.
	# Token clicks are handled by token _input → token_clicked signal first.
	# If input reaches here, no token was hit.
	if DebugMode.has_selection():
		DebugMode.deselect_token()
		get_viewport().set_input_as_handled()


## Checks if a dragged token just crossed outside its deployment zone and
## shows a one-shot toast warning.  Resets when the token re-enters.
## DBG-033 — advisory toast on zone crossing in debug mode.
func check_zone_crossing_toast(
		token: Node2D, _top_y: float, _bottom_y: float
) -> void:
	var faction: Constants.Faction = Constants.Faction.GALACTIC_EMPIRE
	var token_name: String = token.name
	if token is ShipToken:
		faction = (token as ShipToken).get_faction()
		var data: ShipData = (token as ShipToken).get_ship_data()
		if data != null:
			token_name = data.ship_name
	elif token is SquadronToken:
		faction = (token as SquadronToken).get_faction()
		token_name = token.name
	var in_zone: bool = DeploymentZoneOverlay.is_in_deploy_zone(
			token.position.y, faction)
	if _was_in_deploy_zone and not in_zone:
		TooltipManager.show_text(
				"%s is outside deployment zone" % token_name,
				Vector2.INF, 3.0)
	_was_in_deploy_zone = in_zone


## Resets zone-crossing tracking so the next move starts fresh.
## Called when a new token is selected.
func reset_zone_tracking() -> void:
	_was_in_deploy_zone = true


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Creates the deployment zone overlay (initially hidden).
func _create_deploy_overlay() -> void:
	_deploy_overlay = DeploymentZoneOverlay.new()
	_deploy_overlay.name = "DeploymentZoneOverlay"
	_deploy_overlay.visible = false
	_board.add_child(_deploy_overlay)


## Creates the debug-mode HUD on a CanvasLayer (label + help panel).
func _create_debug_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DebugHUDLayer"
	layer.layer = 100
	_board.add_child(layer)

	_debug_label = Label.new()
	_debug_label.text = "DEBUG"
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.position = Vector2(10, 10)
	_debug_label.visible = false
	layer.add_child(_debug_label)

	_debug_help_panel = DebugHelpPanel.new()
	_debug_help_panel.name = "DebugHelpPanel"
	_debug_help_panel.position = Vector2(10, 44)
	_debug_help_panel.visible = false
	layer.add_child(_debug_help_panel)


## Connects DebugMode signals.
func _connect_signals() -> void:
	DebugMode.debug_mode_changed.connect(_on_debug_mode_changed)
	DebugMode.save_positions_requested.connect(_on_save_positions)


## Updates visibility of debug-only UI elements.
func _on_debug_mode_changed(_enabled: bool) -> void:
	_update_debug_visibility()


## Toggles debug-specific overlays.
func _update_debug_visibility() -> void:
	var on: bool = DebugMode.enabled
	if _deploy_overlay:
		_deploy_overlay.visible = on
	if _debug_label:
		_debug_label.visible = on
	if _debug_help_panel:
		_debug_help_panel.visible = on


## Saves all token positions to the learning scenario JSON.
## DBG-040, DBG-041
func _on_save_positions() -> void:
	var success: bool = _scenario_saver.save_positions(
			"scenarios/", "learning_scenario.json",
			_get_ship_tokens.call(), _get_squadron_tokens.call(),
			GameScale.play_area_size_px)
	if success:
		_log.info("Token positions saved successfully.")
	else:
		_log.error("Failed to save token positions.")


# ---------------------------------------------------------------------------
# Debug Damage Dealing (Shift+D) — DBG-050, DBG-051, DBG-052
# Extracted from game_board.gd as part of refactoring phase K10.
# ---------------------------------------------------------------------------

## Path to the authoritative damage-card data JSON.
const DEBUG_DAMAGE_CARDS_FILE: String = "damage_cards.json"

## Lazily populated catalogue of unique damage-card definitions loaded from
## [member DEBUG_DAMAGE_CARDS_FILE].  Each entry has the keys
## `effect_id`, `title`, `trait`, `timing`, and `effect_text` — exactly the
## schema produced by `Resources/Game_Components/damage_cards.json`, which
## is the single source of truth for damage-card metadata.
var _debug_damage_cards: Array[Dictionary] = []


## Returns the cached damage-card catalogue, loading it lazily on first
## access.  The catalogue contains one entry per unique `effect_id` from
## `damage_cards.json` (count is ignored — the debug picker shows each
## card type once).
func _get_debug_damage_cards() -> Array[Dictionary]:
	if not _debug_damage_cards.is_empty():
		return _debug_damage_cards
	var data: Dictionary = AssetLoader.load_json("", DEBUG_DAMAGE_CARDS_FILE)
	if data.is_empty() or not data.has("cards"):
		_log.error("Failed to load debug damage card data from %s" %
				DEBUG_DAMAGE_CARDS_FILE)
		return _debug_damage_cards
	for entry: Dictionary in data["cards"] as Array:
		_debug_damage_cards.append({
			"effect_id": str(entry.get("effect_id", "")),
			"title": str(entry.get("title", "")),
			"trait": str(entry.get("trait", "Ship")),
			"timing": str(entry.get("timing", "persistent")),
			"effect_text": str(entry.get("effect_text", "")),
		})
	return _debug_damage_cards

## Tracks "click a ship to deal faceup damage" mode (Shift+D).
var _debug_damage_targeting: bool = false

## Lazily created OpponentChoiceModal for the debug damage card picker.
var _debug_damage_modal: OpponentChoiceModal = null

## The ShipToken that was clicked during debug damage targeting.
var _debug_damage_target_token: ShipToken = null

## Tracks immediate-effect choice flow when a debug-dealt card requires it.
var _debug_immediate_card: DamageCard = null

## The ShipInstance the immediate-effect card was dealt to.
var _debug_immediate_ship: ShipInstance = null

## Damage deck, populated by [method set_damage_deck] once the deck is
## constructed during scenario / loaded-state spawn.
var _damage_deck: DamageDeck = null


## Provides the live damage deck once the scenario / loaded state has
## constructed it.  Mirrors [AttackExecutor.set_damage_deck].
func set_damage_deck(deck: DamageDeck) -> void:
	_damage_deck = deck


## Returns whether Shift+D targeting mode is currently active.
## Read by game_board's [code]_on_token_clicked[/code] to route the click.
func is_damage_targeting() -> bool:
	return _debug_damage_targeting


## Handles Shift+D (enter targeting) and Escape (cancel targeting).
## Returns true if the event was consumed.
func try_handle_input(event: InputEvent) -> bool:
	if _handle_debug_damage_escape(event):
		return true
	if _handle_debug_damage_shortcut(event):
		return true
	return false


## Reactor for the [DebugDealDamageCommand] broadcast / execution.
## Called from game_board's command-executed projection.
func react_to_command(cmd: GameCommand, result: Dictionary) -> void:
	if cmd == null or cmd.command_type != "debug_deal_damage":
		return
	_react_debug_deal_damage(cmd, result)


## Opens the damage card picker for [param token] when the player clicks
## a ship while in Shift+D targeting mode.
func open_damage_modal_for_token(token: ShipToken) -> void:
	_open_debug_damage_modal(token)


# ---------------------------------------------------------------------------
# Private helpers — debug damage dealing
# ---------------------------------------------------------------------------

## Handles Shift+D to enter debug damage targeting mode.
## Returns true if the event was consumed.
func _handle_debug_damage_shortcut(event: InputEvent) -> bool:
	if not DebugMode.enabled:
		return false
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode != KEY_D or not key_event.shift_pressed:
		return false
	_debug_damage_targeting = true
	TooltipManager.show_text(
			"Click a ship to deal faceup damage", Vector2.INF, 0.0, true)
	_log.info("Debug damage targeting mode entered (Shift+D).")
	get_viewport().set_input_as_handled()
	return true


## Handles Escape to cancel debug damage targeting mode.
## Returns true if the event was consumed.
func _handle_debug_damage_escape(event: InputEvent) -> bool:
	if not _debug_damage_targeting:
		return false
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	_cancel_debug_damage_targeting()
	get_viewport().set_input_as_handled()
	return true


## Cancels debug damage targeting mode and hides the tooltip.
func _cancel_debug_damage_targeting() -> void:
	_debug_damage_targeting = false
	_debug_damage_target_token = null
	TooltipManager.hide_tooltip()
	_log.info("Debug damage targeting cancelled.")


## Opens the damage card picker modal for the clicked ship.
func _open_debug_damage_modal(token: ShipToken) -> void:
	_debug_damage_targeting = false
	_debug_damage_target_token = token
	TooltipManager.hide_tooltip()
	_ensure_debug_damage_modal()
	var options: Array[Dictionary] = []
	for entry: Dictionary in _get_debug_damage_cards():
		options.append({
			"id": entry["effect_id"] as String,
			"label": "%s (%s)" % [entry["title"], entry["trait"]],
			"available": true,
		})
	var choice_info: Dictionary = {
		"card_title": "Debug: Deal Faceup Damage",
		"effect_text": "Choose a damage card to deal faceup.",
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"options": options,
	}
	_debug_damage_modal.open(choice_info)
	_log.info("Debug damage modal opened for '%s'." %
			token.get_ship_instance().ship_data.ship_name)


## Lazily creates the debug damage modal on a CanvasLayer.
func _ensure_debug_damage_modal() -> void:
	if _debug_damage_modal != null:
		return
	_debug_damage_modal = OpponentChoiceModal.new()
	_debug_damage_modal.name = "DebugDamageModal"
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DebugDamageModalLayer"
	layer.layer = 120
	add_child(layer)
	layer.add_child(_debug_damage_modal)
	_debug_damage_modal.choice_confirmed.connect(
			_on_debug_damage_card_chosen)


## Callback when the player picks a damage card from the debug modal.
func _on_debug_damage_card_chosen(selection: Dictionary) -> void:
	_debug_damage_modal.close_and_clear()
	var chosen_id: String = str(selection.get("id", ""))
	if chosen_id.is_empty():
		_log.warn("Debug damage: no card selected.")
		return
	if _debug_damage_target_token == null:
		_log.warn("Debug damage: no target ship.")
		return
	var ship: ShipInstance = _debug_damage_target_token.get_ship_instance()
	if ship == null:
		_log.warn("Debug damage: target has no ShipInstance.")
		return
	_debug_deal_faceup_card(ship, chosen_id)
	_debug_damage_target_token = null


## Draws a card from the damage deck, overrides its identity, and deals
## it faceup to the ship with the full pipeline.
## DBG-050 — debug damage dealing.
func _debug_deal_faceup_card(ship: ShipInstance,
		effect_id: String) -> void:
	if _damage_deck == null:
		TooltipManager.show_text("Damage deck not available", Vector2.INF, 3.0)
		return
	var card: DamageCard = _damage_deck.draw_card()
	if card == null:
		TooltipManager.show_text("Damage deck empty", Vector2.INF, 3.0)
		_log.warn("Debug damage: deck empty.")
		return
	# Look up the card definition from the single source of truth
	# (damage_cards.json).  All identity fields — title, trait, timing,
	# effect_text — come from the data file rather than being hardcoded.
	var def: Dictionary = {}
	for entry: Dictionary in _get_debug_damage_cards():
		if entry["effect_id"] as String == effect_id:
			def = entry
			break
	if def.is_empty():
		_log.warn("Debug damage: unknown effect_id '%s'." % effect_id)
		return
	# Override card identity from the data definition.
	card.effect_id = effect_id
	card.title = def["title"] as String
	card.timing = def["timing"] as String
	card.trait_type = def["trait"] as String
	card.effect_text = def["effect_text"] as String
	card.is_faceup = true
	# Submit through command for replay / multiplayer safety.  All
	# post-submit work (visual emit, immediate-effect chain, tooltip,
	# success log) runs from game_board's command-executed projection
	# via [method react_to_command] so hot-seat, host, and client peers
	# share a single visual-update path.
	var result: Dictionary = GameManager.submit_debug_deal_damage(
			ship, card.serialize(), effect_id)
	if result.is_empty():
		# Hot-seat: empty == validation rejection.  In network mode
		# [NetworkCommandSubmitter] always returns its
		# [code]awaiting_remote[/code] sentinel and the result arrives
		# via the broadcast.
		_log.warn("Debug damage: command rejected.")


## Reactor for the [DebugDealDamageCommand] broadcast / execution.
## Emits visual signals on every peer (so the [ShipCardPanel] / hull
## display refresh on host, client, and hot-seat) and — only on the
## originating peer — chains the immediate-effect resolution and shows
## the floating tooltip.
##
## DBG-050.
func _react_debug_deal_damage(cmd: GameCommand,
		result: Dictionary) -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var owner_player: int = int(cmd.payload.get("owner_player", -1))
	var ship_index: int = int(cmd.payload.get("ship_index", -1))
	var ship: ShipInstance = gs.get_ship(owner_player, ship_index)
	if ship == null or ship.faceup_damage.is_empty():
		return
	var dealt_card: DamageCard = ship.faceup_damage.back()
	var title: String = str(result.get("card_title", dealt_card.title))
	var effect_id: String = str(cmd.payload.get("effect_id", ""))
	_log.info("Debug: dealt faceup '%s' [%s] to %s." % [
			title, effect_id, ship.ship_data.ship_name])
	if result.get("persistent_registered", false):
		_log.info("Debug: persistent effect registered for '%s'." % title)
	# Visual signals — fire on every peer so card panel and hull readout
	# refresh consistently.
	EventBus.damage_card_flipped.emit(ship, dealt_card, true)
	EventBus.damage_card_dealt.emit(ship, dealt_card, true)
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	EventBus.ship_hull_changed.emit(ship, new_hull)
	# Tooltip on the originator (operator who pressed Shift+D) so they
	# get visible feedback regardless of which ship they targeted.
	# Hot-seat: viewer is the active player (matches cmd.player_index for
	# self-submitted debug commands).  Network: viewer is the local peer.
	if cmd.player_index == _local_viewer():
		TooltipManager.show_text(
				"Dealt: %s" % title, Vector2.INF, 2.5)
	# Immediate-effect chain runs on the **chooser** peer.  The chooser
	# is determined by the card text.  Auto-resolve cards (no choice
	# required) run on the ship-owner peer so dial / shield / hull
	# mutations route through the authoritative submitter once.
	# Hot-seat: both peers are local so the chain always runs (via
	# [method _can_act_as]).
	if ImmediateEffectResolver.is_immediate(dealt_card):
		var chooser_player: int = _resolve_debug_chooser_player(
				dealt_card, ship)
		if _can_act_as(chooser_player):
			_resolve_debug_immediate_effect(dealt_card, ship)


## Returns the player index that should drive the immediate-effect
## modal for [param card] dealt via the debug tool.
func _resolve_debug_chooser_player(card: DamageCard,
		ship: ShipInstance) -> int:
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var choice_info: Dictionary = resolver.get_required_choice(card, ship)
	var chooser: String = str(choice_info.get("chooser", "owner"))
	if chooser == "opponent":
		return 1 - ship.owner_player
	return ship.owner_player


## Resolves an immediate damage card effect dealt via the debug tool.
## Auto-resolve cards resolve instantly; choice cards open a second
## modal for the player to make their selection.
func _resolve_debug_immediate_effect(card: DamageCard,
		ship: ShipInstance) -> void:
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var choice_info: Dictionary = resolver.get_required_choice(card, ship)
	if choice_info.is_empty():
		var extra_card_data: Dictionary = {}
		if card.effect_id == "structural_damage" and _damage_deck:
			var extra: DamageCard = _damage_deck.draw_card()
			if extra:
				extra_card_data = extra.serialize()
		var result: Dictionary = GameManager.submit_resolve_immediate_effect(
				ship, card, {}, extra_card_data)
		if not result.is_empty():
			_emit_debug_immediate_signals(card, ship, result)
			_log.info("Debug: immediate effect auto-resolved for '%s'." %
					card.title)
	else:
		# Choice needed — open a second modal using the same debug modal.
		_debug_immediate_card = card
		_debug_immediate_ship = ship
		_ensure_debug_damage_modal()
		_debug_damage_modal.choice_confirmed.disconnect(
				_on_debug_damage_card_chosen)
		_debug_damage_modal.choice_confirmed.connect(
				_on_debug_immediate_choice_confirmed)
		_debug_damage_modal.open(choice_info)
		_log.info("Debug: choice modal opened for immediate '%s'." %
				card.title)


## Callback when the player confirms their immediate-effect choice
## (e.g. Injured Crew token, Shield Failure zones, Comm Noise action).
func _on_debug_immediate_choice_confirmed(selection: Dictionary) -> void:
	_debug_damage_modal.close_and_clear()
	# Reconnect the normal handler.
	_debug_damage_modal.choice_confirmed.disconnect(
			_on_debug_immediate_choice_confirmed)
	_debug_damage_modal.choice_confirmed.connect(
			_on_debug_damage_card_chosen)
	if _debug_immediate_card == null or _debug_immediate_ship == null:
		return
	var extra_card_data: Dictionary = {}
	if _debug_immediate_card.effect_id == "structural_damage" and _damage_deck:
		var extra: DamageCard = _damage_deck.draw_card()
		if extra:
			extra_card_data = extra.serialize()
	var result: Dictionary = GameManager.submit_resolve_immediate_effect(
			_debug_immediate_ship, _debug_immediate_card,
			selection, extra_card_data)
	if not result.is_empty():
		_emit_debug_immediate_signals(
				_debug_immediate_card, _debug_immediate_ship, result)
		_log.info("Debug: immediate effect resolved for '%s'." %
				_debug_immediate_card.title)
	_debug_immediate_card = null
	_debug_immediate_ship = null


## Emits EventBus signals after a debug immediate effect command executes.
## Thin wrapper around [ImmediateEffectSignals.emit] so the debug route
## and the regular attack route share one visual emit path.
func _emit_debug_immediate_signals(card: DamageCard,
		ship: ShipInstance, result: Dictionary) -> void:
	ImmediateEffectSignals.emit(card, ship, result)


## Returns the local player index (network) or active player (hot-seat).
## Mirrors game_board.gd's [code]_local_viewer[/code] helper.
func _local_viewer() -> int:
	var idx: int = NetworkManager.get_local_player_index()
	if idx < 0:
		return GameManager.get_active_player()
	return idx


## Returns whether this peer may act for [param player_index].
## In network mode only the matching peer acts; in hot-seat both players
## are local.  Mirrors game_board.gd's [code]_can_act_as[/code] helper.
func _can_act_as(player_index: int) -> bool:
	var idx: int = NetworkManager.get_local_player_index()
	return idx < 0 or idx == player_index

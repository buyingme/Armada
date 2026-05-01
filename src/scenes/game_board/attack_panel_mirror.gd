## Read-only mirror of the [AttackSimPanel] shown on the non-attacker
## peer in network play.
##
## Phase I6b-3 R1b: opens the same `AttackSimPanel` UI on the passive
## peer, populated entirely from `interaction_flow.payload`.  Input
## signals are intentionally [b]not[/b] connected — the mirror is
## strictly informational at this slice.  Subsequent slices (R2–R5)
## will turn defender-driven sub-steps interactive on the defender peer
## via dedicated commands.
##
## Lifecycle:
##  * [method setup] is called once by [UIPanelManager] with a
##    dedicated [CanvasLayer]; the panel is created hidden.
##  * [method apply_flow] is called from
##    [GameBoard._on_command_executed_project_ui] for every
##    `command_executed` while the local peer is the non-attacker.  It
##    opens the panel on first call and updates the prompt.
##  * [method close] hides the panel when the attack flow ends.
##
## Hot-seat invariant: this class is only ever instantiated and called
## while [code]PlayMode.is_network()[/code] is true (gated in
## [GameBoard]).  The mirror has no effect on the attacker peer.
class_name AttackPanelMirror
extends RefCounted


## The owned [AttackSimPanel] instance.  Created in [method setup].
var _panel: AttackSimPanel = null

## True once [method apply_flow] has been called for the current attack
## flow and the panel has been opened.  Reset by [method close].
var _is_open: bool = false

## Cached display string of the last applied modal_kind so we only call
## the (relatively expensive) `_set_prompt` flavour when it actually
## changes.
var _last_modal_kind: int = -1

## Last published `defender_name` from `interaction_flow.payload`.
## Tracks transitions from "have target" to "no target" (between
## consecutive attacks under the 2-hull-zone rule or in the Step 6
## squadron loop) so the mirror reverts to the initial-attack prompt
## without rebuilding the panel on every snapshot.
var _last_defender_name: String = ""

## Phase I6b-3 R2: true once the interactive defense section has been
## populated for the current attack and the panel signals are
## connected.  Reset on [method close] and on the next
## attack identity (handled by the cleared-target transition).
var _defense_section_active: bool = false

## Phase I6b-3 R2: true once the panel's `defense_tokens_done` signal
## has been wired up to [method _on_defense_tokens_done].  Tracked
## independently so [method close] can disconnect cleanly.
var _defense_signal_connected: bool = false

## Phase I6b-3 R1b follow-up: cache of the last `dice_pool` we rendered
## via [code]show_dice_count[/code] so we only refresh on change.
## Reset on [method close] and on the next-attack transition.
var _last_dice_pool_text: String = ""

## Phase I6b-3 R1b follow-up / R3 follow-up: cache of the last
## rendered `dice_results` payload so we re-render the dice strip
## whenever its contents change (size **or** any die's face).  The
## R3 evade reroll mutates a single die in place — keeping a size-
## only cache would skip the redraw and the defender peer would not
## see the rerolled face.
var _last_dice_results_payload: Array = []

## Phase I6b-3 R3: true once the interactive evade die-selection
## section has been opened for the current attack and the
## [code]evade_die_confirmed[/code] signal has been wired up.  Reset
## on [method close] and when the host clears the
## [code]evade_active[/code] payload flag.
var _evade_section_active: bool = false

## Phase I6b-3 R3 follow-up: cache of the last [code]modified_damage[/code]
## value rendered in the defense section so we can refresh the panel's
## damage readout when an evade reroll / remove updates it mid-flight.
var _last_modified_damage: int = -1

## Phase I6b-3 R3: true once the panel's [code]evade_die_confirmed[/code]
## signal has been connected to [method _on_evade_die_confirmed].
var _evade_signal_connected: bool = false

## Logger.
var _log: GameLogger = GameLogger.new("AttackPanelMirror")


## Maps [enum Constants.HullZone] to display strings.  Mirrors the
## table inside [DefenseMirrorPanel].
const _ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}


## Creates the [AttackSimPanel] instance and adds it as a child of
## [param layer].  Must be called once before [method apply_flow].
func setup(layer: CanvasLayer) -> void:
	if _panel != null:
		return
	_panel = AttackSimPanel.new()
	_panel.name = "AttackPanelMirror"
	layer.add_child(_panel)
	_panel.visible = false


## Returns the underlying panel — for tests only.  Production code
## should not connect signals on this panel.
func get_panel() -> AttackSimPanel:
	return _panel


## Returns true if the mirror panel is currently open.
func is_open() -> bool:
	return _is_open and _panel != null and _panel.visible


## Opens (if needed) and refreshes the mirror panel from the published
## attack-flow payload.
##
## [param payload] — the dictionary stored on
## [member InteractionFlow.payload], populated by
## [AttackExecutor._compute_attack_identity_patch] and the per-step
## patches.
## [param step_id] — current [enum Constants.InteractionStep] value
## (passed verbatim from [member InteractionFlow.step_id]); used to
## decide when to render the interactive defense section in R2.
func apply_flow(payload: Dictionary, step_id: int) -> void:
	if _panel == null:
		return
	# First call for this attack flow — open the panel with the
	# appropriate "initial" prompt based on attacker kind.
	var attacker_kind: String = String(
			payload.get("attacker_kind", "ship"))
	var attacker_name: String = String(
			payload.get("attacker_name", ""))
	if not _is_open:
		if attacker_kind == "squadron":
			_panel.show_initial_squadron_exec(attacker_name)
		else:
			_panel.show_initial_attack_exec(attacker_name)
		_is_open = true
		_last_modal_kind = -1
	# Refresh the target line whenever a defender is published.  Cheap
	# enough to call on every command_executed; AttackSimPanel just
	# updates two Labels.
	var def_name: String = String(payload.get("defender_name", ""))
	if def_name != "":
		var atk_name: String = String(payload.get("attacker_name", ""))
		var atk_zone: int = int(payload.get("attacker_zone", -1))
		var atk_zone_name: String = String(
				payload.get("attacker_zone_name", _zone_label(atk_zone)))
		var def_zone: int = int(payload.get("defender_zone", -1))
		var def_zone_name: String = _zone_label(def_zone)
		var range_band: String = String(payload.get("range_band", ""))
		_panel.show_target_selected(
				atk_name, atk_zone_name, def_name, def_zone_name,
				"", range_band)
	else:
		# Phase I6b-3 R1b follow-up: between consecutive attacks the
		# host clears the defender identity (see
		# [method AttackExecutor._publish_clear_target_patch]).  Mirror
		# the host's "Select target" prompt so the title drops the
		# previous target.  Only rebuild on the transition edge —
		# otherwise every command_executed would rebuild the panel.
		if _last_defender_name != "":
			if attacker_kind == "squadron":
				_panel.show_initial_squadron_exec(attacker_name)
			else:
				_panel.show_initial_attack_exec(attacker_name)
			# Phase I6b-3 R2: between consecutive attacks, the previous
			# attack's defense section is no longer relevant — drop the
			# "section active" flag so the next attack's DEFENSE_TOKENS
			# step opens a fresh interactive section.  Disconnecting
			# the signal is safe to defer to [method close]; we just
			# reset the flag so [_apply_defense_section] re-runs.
			_defense_section_active = false
			# Phase I6b-3 R3: also reset the evade-section flag so the
			# next attack's [code]evade_active[/code] payload edge
			# re-opens [code]show_evade_die_selection[/code] cleanly.
			_evade_section_active = false
			# Phase I6b-3 R1b follow-up: drop the dice caches so the
			# next attack's pool / roll snapshot triggers a fresh
			# render even if the formatted text happens to match.
			# Also hide the previous attack's dice strip + count so
			# they don't linger between attacks (squadron loop or
			# two-hull-zone rule).
			_last_dice_pool_text = ""
			_last_dice_results_payload = []
			_last_modified_damage = -1
			if _panel.has_method("hide_dice_count"):
				_panel.hide_dice_count()
	_last_defender_name = def_name
	# Phase I6b-3 R2 follow-up: when we leave the DEFENSE_TOKENS step,
	# tear down the interactive section and clear the active flag so
	# the next attack's DEFENSE_TOKENS snapshot triggers a fresh
	# [code]show_defense_section[/code] rather than reusing stale UI.
	if _defense_section_active \
			and step_id != Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
		if _panel.has_method("hide_defense_section"):
			_panel.hide_defense_section()
		_defense_section_active = false
	_last_modal_kind = step_id
	# Phase I6b-3 R1b follow-up: render dice pool / dice results from
	# the published payload so the passive peer's mirror shows the
	# attacker's dice and roll outcome.
	_apply_dice_sections(payload)
	# Phase I6b-3 R2: render the interactive defense section once we
	# enter the DEFENSE_TOKENS sub-step.  Idempotent — only populated
	# on the transition edge.
	_apply_defense_section(payload, step_id)
	# Phase I6b-3 R3: render the interactive evade die-selection
	# section when the attacker peer flips `evade_active` to true.
	_apply_evade_section(payload)
	# Phase I6b-3 R3 follow-up: refresh the defense-section damage
	# readout when an evade-die selection mutates `modified_damage`.
	_apply_modified_damage_update(payload)


## Renders the dice-pool count label and the rolled-dice strip from
## the published [param payload].  Idempotent: only refreshes when the
## formatted pool text or the rolled-dice array length changes, so it
## is safe to call on every [signal CommandProcessor.command_executed].
##
## Reads:
##   * [code]dice_pool[/code] — Dictionary[colour_key → int] published
##     by [code]AttackExecutor._compute_attack_identity_patch[/code]
##     during DECLARE.
##   * [code]dice_results[/code] — Array[Dictionary] published by
##     [code]AttackExecutor[/code] right after the roll.
##
## Phase I6b-3 R1b follow-up.
func _apply_dice_sections(payload: Dictionary) -> void:
	if _panel == null:
		return
	var pool_raw: Variant = payload.get("dice_pool", null)
	if pool_raw is Dictionary and not (pool_raw as Dictionary).is_empty():
		var dice_text: String = DicePool.format_pool(pool_raw as Dictionary)
		if dice_text != _last_dice_pool_text:
			_panel.show_dice_count(dice_text)
			_last_dice_pool_text = dice_text
	var results_raw: Variant = payload.get("dice_results", null)
	if results_raw is Array:
		var results_arr: Array = results_raw as Array
		if results_arr != _last_dice_results_payload:
			var typed: Array[Dictionary] = []
			for entry: Variant in results_arr:
				typed.append(entry as Dictionary)
			if typed.is_empty():
				_panel.hide_dice_results()
			else:
				_panel.show_dice_results(typed)
			_last_dice_results_payload = results_arr.duplicate(true)


## Populates the interactive defense-token section on the defender
## peer's mirror panel.  Idempotent — only runs once per attack flow
## (when [param step_id] first equals
## [constant Constants.InteractionStep.ATTACK_DEFENSE_TOKENS]).
##
## Reads the defender's defense-token snapshot, locked-token list,
## modified damage and current speed from [param payload] (published
## by [AttackExecutor._attack_exec_start_defense]).  Connects the
## panel's [code]defense_tokens_done[/code] signal to this mirror's
## handler so that pressing [i]Commit Defense[/i] submits a
## [CommitDefenseCommand] from the defender peer.
##
## Phase I6b-3 R2 — closes NW-006.
func _apply_defense_section(payload: Dictionary,
		step_id: int) -> void:
	if _panel == null:
		return
	if step_id != Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
		return
	if _defense_section_active:
		return
	var tokens_raw: Array = payload.get("defense_tokens", []) as Array
	# Bug-fix: the host emits two snapshots when entering DEFENSE_TOKENS
	# — first the FSM-advance with the previous payload (no tokens),
	# then the patch carrying `defense_tokens`.  Defer population until
	# the tokens actually arrive; otherwise we'd render a panel with no
	# buttons and lock it via `_defense_section_active`.
	if tokens_raw.is_empty():
		return
	var tokens: Array[Dictionary] = []
	for entry: Variant in tokens_raw:
		tokens.append(entry as Dictionary)
	var locked_raw: Array = payload.get("locked_tokens", []) as Array
	var locked: Array[int] = []
	for raw_idx: Variant in locked_raw:
		locked.append(int(raw_idx))
	var modified_damage: int = int(payload.get("modified_damage", 0))
	var defender_speed: int = int(payload.get("defender_speed", 1))
	_panel.show_defense_section(
			tokens, locked, modified_damage, defender_speed)
	_last_modified_damage = modified_damage
	if not _defense_signal_connected:
		_panel.defense_tokens_done.connect(_on_defense_tokens_done)
		_defense_signal_connected = true
	_defense_section_active = true


## Renders the interactive evade die-selection section when the
## attacker peer flips [code]evade_active[/code] to true in
## [member InteractionFlow.payload].  Idempotent: only opens once per
## evade sub-step (edge-triggered by [member _evade_section_active])
## and tears down when the attacker clears the flag.
##
## Phase I6b-3 R3 — defender-controlled evade die selection.
func _apply_evade_section(payload: Dictionary) -> void:
	if _panel == null:
		return
	var active: bool = bool(payload.get("evade_active", false))
	if active and not _evade_section_active:
		var range_band: String = String(
				payload.get("evade_range_band", ""))
		if range_band.is_empty():
			return
		_panel.show_evade_die_selection(range_band)
		if not _evade_signal_connected:
			_panel.evade_die_confirmed.connect(_on_evade_die_confirmed)
			_evade_signal_connected = true
		_evade_section_active = true
	elif not active and _evade_section_active:
		if _panel.has_method("hide_evade_die_selection"):
			_panel.hide_evade_die_selection()
		_evade_section_active = false


## Refreshes the defense-section damage readout from the published
## [param payload].  Called every [method apply_flow] so an evade-die
## selection that mutates [code]modified_damage[/code] (Phase I6b-3 R3)
## is reflected on the defender peer's mirror.  Idempotent — only
## redraws when the value changes.
func _apply_modified_damage_update(payload: Dictionary) -> void:
	if _panel == null:
		return
	if not _defense_section_active:
		return
	if not payload.has("modified_damage"):
		return
	var damage: int = int(payload.get("modified_damage", 0))
	if damage == _last_modified_damage:
		return
	_last_modified_damage = damage
	if _panel.has_method("update_defense_damage"):
		_panel.update_defense_damage(damage)


## Submits a [SelectEvadeDieCommand] from the defender peer when the
## player clicks a die in the evade die-selection section.  The
## attacker peer's [AttackExecutor] reacts to the broadcast via
## [signal CommandProcessor.command_executed] and runs the
## remove-die / reroll-die pipeline.
##
## Phase I6b-3 R3.
func _on_evade_die_confirmed(die_index: int) -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var def_player: int = -1
	var def_index: int = -1
	var flow: InteractionFlow = gs.interaction_flow
	if flow:
		def_player = int(flow.payload.get("defender_player", -1))
		def_index = int(flow.payload.get("defender_ship_index", -1))
	if def_player < 0 or def_index < 0:
		_log.warn("Evade-die submit with no defender identity — ignoring.")
		return
	var def_inst: ShipInstance = gs.get_ship(def_player, def_index)
	if def_inst == null:
		_log.warn("Evade-die submit: ship %d/%d not found." %
				[def_player, def_index])
		return
	GameManager.submit_select_evade_die(def_inst, die_index)


## Submits a [CommitDefenseCommand] from the defender peer.
## Reads the selected token indices off the panel and routes them
## through [GameManager.submit_commit_defense].  The attacker peer's
## [AttackExecutor] reacts to the broadcast via
## [signal CommandProcessor.command_executed] and runs the spend
## pipeline.
func _on_defense_tokens_done() -> void:
	if _panel == null:
		return
	var selected: Array[int] = _panel.get_defense_selected_indices()
	_panel.disable_all_defense_buttons()
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var def_player: int = -1
	var def_index: int = -1
	var flow: InteractionFlow = gs.interaction_flow
	if flow:
		def_player = int(flow.payload.get("defender_player", -1))
		def_index = int(flow.payload.get("defender_ship_index", -1))
	if def_player < 0 or def_index < 0:
		_log.warn("Defense commit with no defender identity — ignoring.")
		return
	var def_inst: ShipInstance = gs.get_ship(def_player, def_index)
	if def_inst == null:
		_log.warn("Defense commit: ship %d/%d not found." %
				[def_player, def_index])
		return
	GameManager.submit_commit_defense(def_inst, selected)


## Hides the mirror panel.  Idempotent.
func close() -> void:
	if _panel == null:
		return
	if _defense_signal_connected:
		if _panel.defense_tokens_done.is_connected(_on_defense_tokens_done):
			_panel.defense_tokens_done.disconnect(_on_defense_tokens_done)
		_defense_signal_connected = false
	if _evade_signal_connected:
		if _panel.evade_die_confirmed.is_connected(_on_evade_die_confirmed):
			_panel.evade_die_confirmed.disconnect(_on_evade_die_confirmed)
		_evade_signal_connected = false
	if _panel.visible:
		_panel.close()
	_is_open = false
	_last_modal_kind = -1
	_last_defender_name = ""
	_defense_section_active = false
	_evade_section_active = false
	_last_dice_pool_text = ""
	_last_dice_results_payload = []
	_last_modified_damage = -1


## Returns a display string for the given [enum Constants.HullZone]
## value, or empty string for non-ship targets / unknown zones.
func _zone_label(zone: int) -> String:
	if zone < 0:
		return ""
	return String(_ZONE_NAMES.get(zone, ""))

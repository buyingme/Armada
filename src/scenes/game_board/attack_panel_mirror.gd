## Projected mirror/controller surface for [AttackSimPanel] in network play.
##
## Phase I6b-3 R1b: opens the same `AttackSimPanel` UI on the passive
## peer, populated entirely from `interaction_flow.payload`. Later slices
## made defender/non-active-player choices command-backed here: defense
## tokens, Evade, Redirect, critical-choice, and Counter attack choices.
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

var _ecm_signal_connected: bool = false

var _last_ecm_payload_key: String = ""

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

## Phase I6b-3 R4: true once the interactive redirect zone-selection
## section has been opened for the current attack and the
## [code]redirect_zone_selected[/code] / [code]redirect_done_pressed[/code]
## signals have been wired up.  Reset on [method close] and when the
## host clears the [code]redirect_active[/code] payload flag.
var _redirect_section_active: bool = false

## Phase I6b-3 R4: cache of the last published [code]redirect_remaining[/code]
## value so the mirror only refreshes the panel's remaining-budget
## label when it actually changes.
var _last_redirect_remaining: int = -1

## Phase I6b-3 R4: true once the panel's redirect signals have been
## connected.  Tracked independently so [method close] can disconnect
## cleanly.
var _redirect_signal_connected: bool = false

## True while the Counter choice buttons are open for the projected
## Counter controller.
var _counter_section_active: bool = false

## True once Counter accept/skip signals are connected on the mirror panel.
var _counter_signal_connected: bool = false

## True once the remote roll button signal is connected.
var _roll_signal_connected: bool = false

## True while the remote Swarm reroll section is open.
var _swarm_section_active: bool = false

## True once remote Swarm reroll/skip signals are connected.
var _swarm_signal_connected: bool = false

## True once the remote dice-confirm signal is connected.
var _confirm_signal_connected: bool = false

## Phase I6b-3 R5: lazily-created modal shown on the chooser peer when
## a damage card with a player choice is dealt.  Owned and parented to
## [member _modal_layer] (created in [method setup]).
var _choice_modal: OpponentChoiceModal = null

## Phase I6b-3 R5: dedicated [CanvasLayer] for the chooser modal.
## Layer 95 so it renders above the mirror's panel (layer 90) and the
## damage-summary overlay (layer 85), matching the attacker-peer
## modal's z-order.
var _modal_layer: CanvasLayer = null

## Phase I6b-3 R5: true once the chooser modal has been opened for
## the current critical-choice sub-step and its
## [code]choice_confirmed[/code] signal has been wired up.  Reset on
## confirm and on [method close].
var _choice_modal_active: bool = false

## Logger.
var _log: GameLogger = GameLogger.new("AttackPanelMirror")


## Maps [enum Constants.HullZone] to display strings.
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
	# Phase I6b-3 R5: dedicated CanvasLayer for the chooser modal at
	# layer 95 (above the mirror's panel at 90 and the damage-summary
	# overlay at 85).  Modal itself is lazily created on first use.
	if _modal_layer == null and layer.get_parent() != null:
		_modal_layer = CanvasLayer.new()
		_modal_layer.name = "AttackPanelMirrorChoiceModalLayer"
		_modal_layer.layer = 95
		layer.get_parent().add_child(_modal_layer)


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
			# Phase I6b-3 R4: also reset the redirect-section flag and
			# its cached budget so the next attack's `redirect_active`
			# edge re-opens [code]show_redirect_section[/code] cleanly.
			_redirect_section_active = false
			_last_redirect_remaining = -1
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
	_apply_counter_choice_section(payload, step_id)
	_apply_remote_roll_section(payload, step_id)
	_apply_remote_swarm_section(payload, step_id)
	_apply_remote_confirm_section(payload, step_id)
	# Phase I6b-3 R2: render the interactive defense section once we
	# enter the DEFENSE_TOKENS sub-step.  Idempotent — only populated
	# on the transition edge.
	_apply_defense_section(payload, step_id)
	# Phase I6b-3 R3: render the interactive evade die-selection
	# section when the attacker peer flips `evade_active` to true.
	_apply_evade_section(payload)
	# Phase I6b-3 R4: render the interactive redirect zone-selection
	# section when the attacker peer flips `redirect_active` to true.
	_apply_redirect_section(payload)
	# Phase I6b-3 R5: open the chooser modal when the critical-choice
	# sub-step is entered and the local peer is the chooser.
	_apply_critical_choice_modal(payload, step_id)
	# Phase I6b-3 R3 follow-up: refresh the defense-section damage
	# readout when an evade-die selection mutates `modified_damage`.
	_apply_modified_damage_update(payload)
	_refresh_defense_ecm_state(payload, step_id)


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
	var blocked_raw: Array = payload.get(
			"blocked_defense_token_indices", []) as Array
	var blocked: Array[int] = []
	for raw_idx: Variant in blocked_raw:
		blocked.append(int(raw_idx))
	var modified_damage: int = int(payload.get("modified_damage", 0))
	var defender_speed: int = int(payload.get("defender_speed", 1))
	var ecm_choice: Dictionary = _dict_payload(payload, "ecm_choice")
	_panel.show_defense_section(
			tokens, locked, modified_damage, defender_speed,
			{"blocked_indices": blocked,
					"ecm_choice": ecm_choice,
					"ecm_authorized_indices": _int_array(
							payload.get("ecm_authorized_indices", []))})
	_last_modified_damage = modified_damage
	_last_ecm_payload_key = _ecm_payload_key(payload)
	if not _defense_signal_connected:
		_panel.defense_tokens_done.connect(_on_defense_tokens_done)
		_defense_signal_connected = true
	if not _ecm_signal_connected:
		_panel.ecm_use_requested.connect(_on_ecm_use_requested)
		_panel.ecm_decline_requested.connect(_on_ecm_decline_requested)
		_ecm_signal_connected = true
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


func _refresh_defense_ecm_state(payload: Dictionary,
		step_id: int) -> void:
	if _panel == null or not _defense_section_active:
		return
	if step_id != Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
		return
	var key: String = _ecm_payload_key(payload)
	if key == _last_ecm_payload_key:
		return
	_defense_section_active = false
	_apply_defense_section(payload, step_id)


func _apply_counter_choice_section(payload: Dictionary,
		step_id: int) -> void:
	if _panel == null:
		return
	var active: bool = step_id == Constants.InteractionStep.ATTACK_COUNTER_CHOICE \
			and _is_local_counter_controller(payload)
	if active and not _counter_section_active:
		_panel.show_counter_section()
		_connect_counter_signals()
		_counter_section_active = true
	elif not active and _counter_section_active:
		_panel.hide_counter_section()
		_counter_section_active = false


func _apply_remote_roll_section(payload: Dictionary,
		step_id: int) -> void:
	if _panel == null:
		return
	var active: bool = step_id == Constants.InteractionStep.ATTACK_ROLL \
			and _is_local_attacker(payload) and _is_counter_attack(payload) \
			and not _has_dice_results(payload)
	if active:
		_panel.show_roll_button()
		_connect_roll_signal()
	elif _roll_signal_connected:
		_panel.hide_roll_button()


func _apply_remote_swarm_section(payload: Dictionary,
		step_id: int) -> void:
	if _panel == null:
		return
	var active: bool = step_id == Constants.InteractionStep.ATTACK_MODIFY \
			and _is_local_attacker(payload) \
			and bool(payload.get(SwarmKeyword.PAYLOAD_AVAILABLE, false))
	if active and not _swarm_section_active:
		_panel.show_swarm_reroll_section()
		_connect_swarm_signals()
		_swarm_section_active = true
	elif not active and _swarm_section_active:
		_panel.hide_cf_token_section()
		_swarm_section_active = false


func _apply_remote_confirm_section(payload: Dictionary,
		step_id: int) -> void:
	if _panel == null:
		return
	var active: bool = step_id == Constants.InteractionStep.ATTACK_MODIFY \
			and _is_local_attacker(payload) and _has_dice_results(payload) \
			and not bool(payload.get(SwarmKeyword.PAYLOAD_AVAILABLE, false))
	if active:
		_panel.show_confirm_button()
		_connect_confirm_signal()
	elif _confirm_signal_connected:
		_panel.hide_confirm_button()


func _connect_counter_signals() -> void:
	if _counter_signal_connected or _panel == null:
		return
	_panel.counter_attack_requested.connect(_on_counter_attack_requested)
	_panel.counter_attack_skipped.connect(_on_counter_attack_skipped)
	_counter_signal_connected = true


func _connect_roll_signal() -> void:
	if _roll_signal_connected or _panel == null:
		return
	_panel.roll_dice_pressed.connect(_on_roll_dice_pressed)
	_roll_signal_connected = true


func _connect_swarm_signals() -> void:
	if _swarm_signal_connected or _panel == null:
		return
	_panel.cf_token_reroll_requested.connect(_on_swarm_reroll_requested)
	_panel.cf_token_reroll_skipped.connect(_on_swarm_reroll_skipped)
	_swarm_signal_connected = true


func _connect_confirm_signal() -> void:
	if _confirm_signal_connected or _panel == null:
		return
	_panel.confirm_pressed.connect(_on_confirm_attack_dice)
	_confirm_signal_connected = true


func _is_local_counter_controller(payload: Dictionary) -> bool:
	var local: int = NetworkManager.get_local_player_index()
	if local < 0:
		return false
	return local == int(payload.get(CounterKeyword.PAYLOAD_CONTROLLER_PLAYER, -1))


func _is_local_attacker(payload: Dictionary) -> bool:
	var local: int = NetworkManager.get_local_player_index()
	if local < 0:
		return false
	return local == int(payload.get("attacker_player", -1))


func _is_counter_attack(payload: Dictionary) -> bool:
	return SquadronKeywordRuleHelper.attack_kind_from_payload(payload) \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER


func _has_dice_results(payload: Dictionary) -> bool:
	return (payload.get("dice_results", []) as Array).size() > 0


func _current_flow_payload() -> Dictionary:
	var gs: GameState = GameManager.current_game_state
	if gs == null or gs.interaction_flow == null:
		return {}
	return gs.interaction_flow.payload.duplicate(true)


func _attack_context_from_payload(payload: Dictionary) -> Dictionary:
	var context: Dictionary = {}
	var keys: Array[String] = ["attacker_kind", "attacker_player",
			"attacker_ship_index", "attacker_squadron_index", "target_kind",
			"target_ship_index", "target_squadron_index", "defender_player",
			"defender_zone", SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND]
	for key: String in keys:
		if payload.has(key):
			context[key] = payload[key]
	return context


func _dice_results_from_payload(payload: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry: Variant in (payload.get("dice_results", []) as Array):
		results.append(entry as Dictionary)
	return results


func _on_counter_attack_requested() -> void:
	_submit_counter_choice(true)


func _on_counter_attack_skipped() -> void:
	_submit_counter_choice(false)


func _submit_counter_choice(accepted: bool) -> void:
	var payload: Dictionary = _current_flow_payload()
	var controller: int = int(payload.get(
			CounterKeyword.PAYLOAD_CONTROLLER_PLAYER, -1))
	if controller < 0:
		return
	GameManager.submit_counter_choice(controller, accepted, payload)


func _on_roll_dice_pressed() -> void:
	var payload: Dictionary = _current_flow_payload()
	var dice_pool: Dictionary = payload.get("dice_pool", {}) as Dictionary
	var attacker: int = int(payload.get("attacker_player", -1))
	if attacker < 0 or dice_pool.is_empty():
		_log.warn("Counter roll submit without attacker/dice payload.")
		return
	GameManager.submit_roll_dice(attacker, dice_pool,
			_attack_context_from_payload(payload))
	_panel.hide_roll_button()


func _on_swarm_reroll_requested(die_index: int) -> void:
	var payload: Dictionary = _current_flow_payload()
	var attacker: int = int(payload.get("attacker_player", -1))
	if attacker < 0:
		return
	GameManager.submit_reroll_attack_die(attacker, die_index,
			_dice_results_from_payload(payload), SwarmKeyword.RULE_ID)


func _on_swarm_reroll_skipped() -> void:
	var payload: Dictionary = _current_flow_payload()
	var attacker: int = int(payload.get("attacker_player", -1))
	if attacker < 0:
		return
	GameManager.submit_skip_attack_modifier(attacker,
			SwarmKeyword.RULE_ID, _attack_context_from_payload(payload))


func _on_confirm_attack_dice() -> void:
	var payload: Dictionary = _current_flow_payload()
	var attacker: int = int(payload.get("attacker_player", -1))
	if attacker < 0:
		return
	GameManager.submit_confirm_attack_dice(attacker,
			_attack_context_from_payload(payload))


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


## Renders the interactive redirect zone-selection section when the
## attacker peer flips [code]redirect_active[/code] to true in
## [member InteractionFlow.payload].  Idempotent: only opens once per
## redirect sub-step (edge-triggered by
## [member _redirect_section_active]) and tears down when the attacker
## clears the flag.  Refreshes the remaining-budget label whenever
## [code]redirect_remaining[/code] changes.
##
## Phase I6b-3 R4 — defender-controlled redirect zone selection.
func _apply_redirect_section(payload: Dictionary) -> void:
	if _panel == null:
		return
	var active: bool = bool(payload.get("redirect_active", false))
	if active and not _redirect_section_active:
		var zones_raw: Array = payload.get(
				"redirect_adjacent_zones", []) as Array
		var zones: Array = []
		for zn: Variant in zones_raw:
			zones.append(int(zn))
		var remaining: int = int(payload.get("redirect_remaining", 0))
		_panel.show_redirect_section(zones, remaining)
		_last_redirect_remaining = remaining
		if not _redirect_signal_connected:
			_panel.redirect_zone_selected.connect(
					_on_redirect_zone_confirmed)
			_panel.redirect_done_pressed.connect(
					_on_redirect_done_confirmed)
			_redirect_signal_connected = true
		_redirect_section_active = true
	elif active and _redirect_section_active:
		# Remaining budget changed mid-flight — refresh the label only.
		var remaining: int = int(payload.get("redirect_remaining", 0))
		if remaining != _last_redirect_remaining:
			if _panel.has_method("update_redirect_remaining"):
				_panel.update_redirect_remaining(remaining)
			_last_redirect_remaining = remaining
	elif not active and _redirect_section_active:
		if _panel.has_method("hide_redirect_section"):
			_panel.hide_redirect_section()
		_redirect_section_active = false
		_last_redirect_remaining = -1


## Submits a [SelectRedirectZoneCommand] from the defender peer when
## the player picks an adjacent hull zone in the redirect section.
## The attacker peer's [AttackExecutor] reacts to the broadcast via
## [signal CommandProcessor.command_executed] and runs the redirect
## bookkeeping pipeline.
##
## Phase I6b-3 R4.
func _on_redirect_zone_confirmed(zone: int) -> void:
	var def_inst: ShipInstance = _resolve_defender_for_submit(
			"Redirect zone")
	if def_inst == null:
		return
	GameManager.submit_select_redirect_zone(def_inst, zone)


## Submits a [RedirectDoneCommand] from the defender peer when the
## player presses [i]Done Redirecting[/i].  Phase I6b-3 R4.
func _on_redirect_done_confirmed() -> void:
	var def_inst: ShipInstance = _resolve_defender_for_submit(
			"Redirect done")
	if def_inst == null:
		return
	GameManager.submit_redirect_done(def_inst)


## Reads the defender [ShipInstance] off the published interaction
## flow.  Returns null and logs a warning if the identity is missing
## or the ship cannot be resolved.  Used by R3/R4 mirror submitters.
func _resolve_defender_for_submit(label: String) -> ShipInstance:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return null
	var flow: InteractionFlow = gs.interaction_flow
	if flow == null:
		return null
	var def_player: int = int(flow.payload.get("defender_player", -1))
	var def_index: int = int(flow.payload.get(
			"defender_ship_index", -1))
	if def_player < 0 or def_index < 0:
		_log.warn("%s submit with no defender identity — ignoring."
				% label)
		return null
	var def_inst: ShipInstance = gs.get_ship(def_player, def_index)
	if def_inst == null:
		_log.warn("%s submit: ship %d/%d not found." %
				[label, def_player, def_index])
		return null
	return def_inst


## Phase I6b-3 R5 — opens the [OpponentChoiceModal] on the chooser's
## peer when the attacker peer publishes a critical-choice sub-step
## with [code]chooser_player == local[/code].  The chooser interacts
## locally; on confirm a [ResolveImmediateEffectCommand] is submitted
## with the ship and card reconstructed from the published payload.
##
## Idempotent: the modal is only opened once per critical-choice
## sub-step; transitioning out of [code]ATTACK_CRITICAL_CHOICE[/code]
## or closing the mirror tears it down.
func _apply_critical_choice_modal(payload: Dictionary,
		step_id: int) -> void:
	var entering: bool = (
			step_id == Constants.InteractionStep.ATTACK_CRITICAL_CHOICE)
	if not entering:
		if _choice_modal_active and _choice_modal != null:
			_choice_modal.close_and_clear()
			_choice_modal_active = false
		return
	if _choice_modal_active:
		return
	var local: int = NetworkManager.get_local_player_index()
	var chooser_player: int = int(
			payload.get("chooser_player", -1))
	if chooser_player < 0 or chooser_player != local:
		return
	# Defensive: don't open the modal if this peer is also the
	# attacker (the local AttackExecutor handles that path).
	if _attacker_is_local(payload, local):
		return
	var choice_info_raw: Variant = payload.get("choice_info", {})
	if not (choice_info_raw is Dictionary):
		_log.warn("Critical-choice modal: missing choice_info; "
				+"skipping open.")
		return
	_ensure_choice_modal()
	if _choice_modal == null:
		_log.warn("Critical-choice modal: failed to instantiate.")
		return
	if not _choice_modal.choice_confirmed.is_connected(
			_on_choice_confirmed):
		_choice_modal.choice_confirmed.connect(
				_on_choice_confirmed, CONNECT_ONE_SHOT)
	_choice_modal.open(choice_info_raw as Dictionary)
	_choice_modal_active = true
	_log.info("Critical-choice modal opened on chooser peer "
			+"(player %d, card='%s')."
			% [local, String(payload.get("card_title", "?"))])


## Returns true when the local peer is the attacker for the published
## attack flow — i.e. the local [AttackExecutor] owns the
## critical-choice modal and the mirror should stay out of the way.
func _attacker_is_local(payload: Dictionary, local: int) -> bool:
	var attacker_player: int = int(
			payload.get("attacker_player", -1))
	return attacker_player >= 0 and attacker_player == local


## Lazily creates the [OpponentChoiceModal] on the dedicated
## [member _modal_layer].  No-op if already created.
func _ensure_choice_modal() -> void:
	if _choice_modal != null or _modal_layer == null:
		return
	_choice_modal = OpponentChoiceModal.new()
	_choice_modal.name = "AttackPanelMirrorChoiceModal"
	_modal_layer.add_child(_choice_modal)


## Submits a [ResolveImmediateEffectCommand] from the chooser peer
## when the player confirms a selection in the chooser modal.  The
## attacker peer's [AttackExecutor] reacts to the broadcast via
## [signal CommandProcessor.command_executed] and finalises the attack.
func _on_choice_confirmed(selection: Dictionary) -> void:
	_choice_modal_active = false
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var flow: InteractionFlow = gs.interaction_flow
	if flow == null:
		return
	var owner_player: int = int(
			flow.payload.get("pending_ship_owner_player", -1))
	var ship_index: int = int(
			flow.payload.get("pending_ship_index", -1))
	var card_index: int = int(
			flow.payload.get("pending_card_index", -1))
	if owner_player < 0 or ship_index < 0 or card_index < 0:
		_log.warn("Choice confirmed with incomplete payload — "
				+"owner=%d ship=%d card=%d."
				% [owner_player, ship_index, card_index])
		return
	var ship: ShipInstance = gs.get_ship(owner_player, ship_index)
	if ship == null:
		_log.warn("Choice confirmed: ship %d/%d not found."
				% [owner_player, ship_index])
		return
	if card_index < 0 or card_index >= ship.faceup_damage.size():
		_log.warn("Choice confirmed: card_index %d out of range "
				+"(faceup=%d)."
				% [card_index, ship.faceup_damage.size()])
		return
	var card: DamageCard = ship.faceup_damage[card_index]
	if card == null:
		_log.warn("Choice confirmed: card at index %d is null."
				% card_index)
		return
	GameManager.submit_resolve_immediate_effect(
			ship, card, selection, {})
	_log.info("Choice submitted: card='%s' selection=%s."
			% [card.title, str(selection)])


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
	var result: Dictionary = GameManager.submit_commit_defense(def_inst, selected)
	if result.is_empty():
		_log.warn("Defense commit command rejected — controls remain enabled.")
		return
	_panel.disable_all_defense_buttons()


func _on_ecm_use_requested(runtime_upgrade_id: String) -> void:
	var def_inst: ShipInstance = _current_defender_ship()
	if def_inst == null:
		return
	var result: Dictionary = GameManager.submit_use_ecm(
			def_inst, runtime_upgrade_id)
	if result.is_empty():
		_log.warn("Electronic Countermeasures use rejected.")


func _on_ecm_decline_requested(runtime_upgrade_id: String) -> void:
	var def_inst: ShipInstance = _current_defender_ship()
	if def_inst == null:
		return
	var result: Dictionary = GameManager.submit_decline_ecm(
			def_inst, runtime_upgrade_id)
	if result.is_empty():
		_log.warn("Electronic Countermeasures decline rejected.")


func _current_defender_ship() -> ShipInstance:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return null
	var flow: InteractionFlow = gs.interaction_flow
	if flow == null:
		return null
	var def_player: int = int(flow.payload.get("defender_player", -1))
	var def_index: int = int(flow.payload.get("defender_ship_index", -1))
	if def_player < 0 or def_index < 0:
		return null
	return gs.get_ship(def_player, def_index)


## Hides the mirror panel.  Idempotent.
func close() -> void:
	if _panel == null:
		return
	if _defense_signal_connected:
		if _panel.defense_tokens_done.is_connected(_on_defense_tokens_done):
			_panel.defense_tokens_done.disconnect(_on_defense_tokens_done)
		_defense_signal_connected = false
	if _ecm_signal_connected:
		if _panel.ecm_use_requested.is_connected(_on_ecm_use_requested):
			_panel.ecm_use_requested.disconnect(_on_ecm_use_requested)
		if _panel.ecm_decline_requested.is_connected(_on_ecm_decline_requested):
			_panel.ecm_decline_requested.disconnect(_on_ecm_decline_requested)
		_ecm_signal_connected = false
	if _evade_signal_connected:
		if _panel.evade_die_confirmed.is_connected(_on_evade_die_confirmed):
			_panel.evade_die_confirmed.disconnect(_on_evade_die_confirmed)
		_evade_signal_connected = false
	if _redirect_signal_connected:
		if _panel.redirect_zone_selected.is_connected(
				_on_redirect_zone_confirmed):
			_panel.redirect_zone_selected.disconnect(
					_on_redirect_zone_confirmed)
		if _panel.redirect_done_pressed.is_connected(
				_on_redirect_done_confirmed):
			_panel.redirect_done_pressed.disconnect(
					_on_redirect_done_confirmed)
		_redirect_signal_connected = false
	if _counter_signal_connected:
		if _panel.counter_attack_requested.is_connected(
				_on_counter_attack_requested):
			_panel.counter_attack_requested.disconnect(
					_on_counter_attack_requested)
		if _panel.counter_attack_skipped.is_connected(
				_on_counter_attack_skipped):
			_panel.counter_attack_skipped.disconnect(
					_on_counter_attack_skipped)
		_counter_signal_connected = false
	if _roll_signal_connected:
		if _panel.roll_dice_pressed.is_connected(_on_roll_dice_pressed):
			_panel.roll_dice_pressed.disconnect(_on_roll_dice_pressed)
		_roll_signal_connected = false
	if _swarm_signal_connected:
		if _panel.cf_token_reroll_requested.is_connected(
				_on_swarm_reroll_requested):
			_panel.cf_token_reroll_requested.disconnect(
					_on_swarm_reroll_requested)
		if _panel.cf_token_reroll_skipped.is_connected(
				_on_swarm_reroll_skipped):
			_panel.cf_token_reroll_skipped.disconnect(
					_on_swarm_reroll_skipped)
		_swarm_signal_connected = false
	if _confirm_signal_connected:
		if _panel.confirm_pressed.is_connected(_on_confirm_attack_dice):
			_panel.confirm_pressed.disconnect(_on_confirm_attack_dice)
		_confirm_signal_connected = false
	# Phase I6b-3 R5: tear down the chooser modal if still active.
	if _choice_modal != null and _choice_modal_active:
		if _choice_modal.choice_confirmed.is_connected(
				_on_choice_confirmed):
			_choice_modal.choice_confirmed.disconnect(
					_on_choice_confirmed)
		_choice_modal.close_and_clear()
	_choice_modal_active = false
	if _panel.visible:
		_panel.close()
	_is_open = false
	_last_modal_kind = -1
	_last_defender_name = ""
	_defense_section_active = false
	_evade_section_active = false
	_redirect_section_active = false
	_counter_section_active = false
	_swarm_section_active = false
	_last_redirect_remaining = -1
	_last_dice_pool_text = ""
	_last_dice_results_payload = []
	_last_modified_damage = -1
	_last_ecm_payload_key = ""


func _dict_payload(payload: Dictionary, key: String) -> Dictionary:
	var raw: Variant = payload.get(key, {})
	if raw is Dictionary:
		return raw as Dictionary
	return {}


func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is Array:
		return result
	for raw: Variant in value as Array:
		result.append(int(raw))
	return result


func _ecm_payload_key(payload: Dictionary) -> String:
	return "%s|%s" % [
		JSON.stringify(payload.get("ecm_choice", {})),
		JSON.stringify(payload.get("ecm_authorized_indices", [])),
	]


## Returns a display string for the given [enum Constants.HullZone]
## value, or empty string for non-ship targets / unknown zones.
func _zone_label(zone: int) -> String:
	if zone < 0:
		return ""
	return String(_ZONE_NAMES.get(zone, ""))

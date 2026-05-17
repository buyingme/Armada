## Unit tests for [AttackPanelMirror].
##
## Phase I6b-3 R1b — read-only mirror of [AttackSimPanel] on the
## non-attacker peer in network mode.  The mirror is populated entirely
## from [member InteractionFlow.payload]; no input signals are
## connected.
extends GutTest


var _mirror: AttackPanelMirror = null
var _layer: CanvasLayer = null


func before_each() -> void:
	_mirror = AttackPanelMirror.new()
	_layer = CanvasLayer.new()
	add_child_autofree(_layer)
	_mirror.setup(_layer)


func test_setup_creates_panel_hidden() -> void:
	var panel: AttackSimPanel = _mirror.get_panel()
	assert_not_null(panel,
			"setup() should create the AttackSimPanel instance.")
	assert_false(panel.visible,
			"Mirror panel should be hidden after setup().")
	assert_false(_mirror.is_open(),
			"is_open() should be false initially.")


func test_setup_is_idempotent() -> void:
	var first: AttackSimPanel = _mirror.get_panel()
	_mirror.setup(_layer)
	assert_same(first, _mirror.get_panel(),
			"setup() called twice should not replace the panel.")


func test_apply_flow_opens_panel_for_ship_attacker() -> void:
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"attacker_zone": Constants.HullZone.FRONT,
		"attacker_zone_name": "FRONT",
	}
	_mirror.apply_flow(payload, Constants.ModalKind.NONE)
	assert_true(_mirror.is_open(),
			"Mirror should be open after first apply_flow().")
	assert_true(_mirror.get_panel().visible,
			"Underlying AttackSimPanel should be visible.")


func test_apply_flow_opens_panel_for_squadron_attacker() -> void:
	var payload: Dictionary = {
		"attacker_kind": "squadron",
		"attacker_name": "Howlrunner",
	}
	_mirror.apply_flow(payload, Constants.ModalKind.NONE)
	assert_true(_mirror.is_open(),
			"Mirror should be open for squadron attacker.")
	# Squadron attackers go straight to "Select a target." prompt
	# (AttackSimPanel.show_initial_squadron_exec).
	assert_string_contains(_mirror.get_panel().get_title_text(),
			"Howlrunner",
			"Squadron attacker name should appear in the title.")


func test_apply_flow_renders_target_when_defender_published() -> void:
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"attacker_zone": Constants.HullZone.FRONT,
		"attacker_zone_name": "FRONT",
		"defender_name": "CR90A",
		"defender_zone": Constants.HullZone.LEFT,
		"range_band": "medium",
	}
	_mirror.apply_flow(payload, Constants.ModalKind.NONE)
	var title: String = _mirror.get_panel().get_title_text()
	assert_string_contains(title, "Demolisher",
			"Title should show the attacker name.")
	assert_string_contains(title, "CR90A",
			"Title should show the defender name.")
	assert_string_contains(_mirror.get_panel().get_body_text(),
			"Medium",
			"Body should show the capitalised range band.")


func test_apply_flow_skips_target_line_when_no_defender() -> void:
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
	}
	_mirror.apply_flow(payload, Constants.ModalKind.NONE)
	# Initial prompt should remain ("Select attacking hull zone.").
	assert_string_contains(_mirror.get_panel().get_body_text(),
			"hull zone",
			"Body should remain on the initial-attack prompt when no "
			+"defender is published yet.")


func test_apply_flow_updates_dice_results_after_reroll_payload() -> void:
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"dice_results": [ {
			"color": Constants.DiceColor.RED,
			"face": Constants.DiceFace.BLANK,
		}],
	}
	_mirror.apply_flow(payload, Constants.InteractionStep.ATTACK_MODIFY)
	var updated_payload: Dictionary = payload.duplicate(true)
	updated_payload["dice_results"] = [ {
		"color": Constants.DiceColor.RED,
		"face": Constants.DiceFace.HIT,
	}]

	_mirror.apply_flow(updated_payload,
			Constants.InteractionStep.ATTACK_MODIFY)

	var cached: Array = _mirror._last_dice_results_payload
	var first_die: Dictionary = cached[0] as Dictionary
	assert_eq(int(first_die.get("face", -1)), int(Constants.DiceFace.HIT),
			"Mirror should cache and render the rerolled die face.")
	assert_eq(_mirror.get_panel()._dice_textures.size(), 1,
			"Mirror should keep a visible die texture after rerendering.")


func test_close_hides_panel() -> void:
	_mirror.apply_flow({
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
	}, Constants.ModalKind.NONE)
	_mirror.close()
	assert_false(_mirror.is_open(),
			"is_open() should be false after close().")
	assert_false(_mirror.get_panel().visible,
			"Underlying panel should be hidden after close().")


func test_close_is_idempotent() -> void:
	_mirror.close()
	_mirror.close()
	assert_false(_mirror.is_open(),
			"Repeated close() should remain in the closed state.")


func test_apply_flow_after_close_reopens() -> void:
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
	}
	_mirror.apply_flow(payload, Constants.ModalKind.NONE)
	_mirror.close()
	_mirror.apply_flow(payload, Constants.ModalKind.NONE)
	assert_true(_mirror.is_open(),
			"apply_flow() after close() should reopen the panel.")


func test_no_signal_connections_on_panel() -> void:
	# R1b invariant: at modal_kind=NONE (informational) the mirror
	# panel must NOT have any input signals connected.  Defender-driven
	# signals are wired at DEFENSE_TOKENS in R2 only — see
	# test_defense_done_connected_at_defense_tokens.
	var panel: AttackSimPanel = _mirror.get_panel()
	assert_eq(panel.roll_dice_pressed.get_connections().size(), 0,
			"roll_dice_pressed must not be connected on the mirror.")
	assert_eq(panel.defense_token_selected.get_connections().size(), 0,
			"defense_token_selected must not be connected on the mirror.")
	assert_eq(panel.confirm_pressed.get_connections().size(), 0,
			"confirm_pressed must not be connected on the mirror.")
	assert_eq(panel.skip_attack_pressed.get_connections().size(), 0,
			"skip_attack_pressed must not be connected on the mirror.")
	assert_eq(panel.defense_tokens_done.get_connections().size(), 0,
			"defense_tokens_done must not be connected before "
			+"DEFENSE_TOKENS step.")
	# Phase I6b-3 R3: evade_die_confirmed is wired only when the
	# attacker peer flips evade_active in the payload.
	assert_eq(panel.evade_die_confirmed.get_connections().size(), 0,
			"evade_die_confirmed must not be connected before "
			+"evade_active flag is set.")
	# Phase I6b-3 R4: redirect_zone_selected and redirect_done_pressed
	# are wired only when the attacker peer flips redirect_active.
	assert_eq(panel.redirect_zone_selected.get_connections().size(), 0,
			"redirect_zone_selected must not be connected before "
			+"redirect_active flag is set.")
	assert_eq(panel.redirect_done_pressed.get_connections().size(), 0,
			"redirect_done_pressed must not be connected before "
			+"redirect_active flag is set.")


func test_defense_done_connected_at_defense_tokens() -> void:
	# Phase I6b-3 R2: when step_id transitions to
	# ATTACK_DEFENSE_TOKENS, the mirror connects the
	# defense_tokens_done signal so pressing Commit submits a
	# CommitDefenseCommand from the defender peer.  Other input
	# signals (roll_dice, confirm, skip_attack, defense_token_selected)
	# remain disconnected — those still belong to the attacker peer.
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"defender_name": "CR90",
		"defender_player": 1,
		"defender_ship_index": 0,
		"defender_speed": 2,
		"defender_zone": Constants.HullZone.FRONT,
		"modified_damage": 3,
		"locked_tokens": [],
		"defense_tokens": [
			{"type": Constants.DefenseToken.BRACE,
			"state": Constants.DefenseTokenState.READY},
		],
	}
	_mirror.apply_flow(payload,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	var panel: AttackSimPanel = _mirror.get_panel()
	assert_eq(panel.defense_tokens_done.get_connections().size(), 1,
			"defense_tokens_done must be connected during "
			+"DEFENSE_TOKENS sub-step.")
	assert_eq(panel.roll_dice_pressed.get_connections().size(), 0,
			"roll_dice_pressed must remain disconnected on the mirror.")
	assert_eq(panel.confirm_pressed.get_connections().size(), 0,
			"confirm_pressed must remain disconnected on the mirror.")
	# After close(), the connection is dropped.
	_mirror.close()
	assert_eq(panel.defense_tokens_done.get_connections().size(), 0,
			"defense_tokens_done must be disconnected after close().")


func test_apply_flow_disables_blocked_defense_tokens() -> void:
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"defender_name": "CR90",
		"defender_player": 1,
		"defender_ship_index": 0,
		"defender_speed": 2,
		"defender_zone": Constants.HullZone.FRONT,
		"modified_damage": 3,
		"locked_tokens": [],
		"blocked_defense_token_indices": [0],
		"defense_tokens": [
			{"type": Constants.DefenseToken.BRACE,
			"state": Constants.DefenseTokenState.EXHAUSTED},
			{"type": Constants.DefenseToken.EVADE,
			"state": Constants.DefenseTokenState.READY},
		],
	}
	_mirror.apply_flow(payload,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	var first_btn: Button = (
			_mirror.get_panel()._defense_token_buttons.get_child(0) as Button)
	assert_true(first_btn.disabled,
			"Mirror should disable payload-blocked defense tokens.")
	assert_true("[BLOCKED]" in first_btn.text,
			"Mirror blocked button should show a blocked label.")


func test_evade_section_opens_when_evade_active_flag_set() -> void:
	# Phase I6b-3 R3: when the attacker peer publishes
	# `evade_active=true` (with a non-empty `evade_range_band`) into
	# the payload, the mirror opens the interactive die-selection
	# section and connects `evade_die_confirmed` so clicks submit a
	# SelectEvadeDieCommand from the defender peer.  Lowering
	# `evade_active` to false hides the section and disconnects.
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"defender_name": "CR90",
		"defender_player": 1,
		"defender_ship_index": 0,
		"defender_zone": Constants.HullZone.FRONT,
		"evade_active": true,
		"evade_range_band": "long",
	}
	_mirror.apply_flow(payload,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	var panel: AttackSimPanel = _mirror.get_panel()
	assert_eq(panel.evade_die_confirmed.get_connections().size(), 1,
			"evade_die_confirmed must be connected while "
			+"evade_active is true.")
	# Lowering the flag hides the section and disconnects the signal.
	var off_payload: Dictionary = payload.duplicate(true)
	off_payload["evade_active"] = false
	off_payload["evade_range_band"] = ""
	_mirror.apply_flow(off_payload,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	# The signal connection persists across apply_flow() calls — only
	# close() clears it (matches defense_tokens_done invariant).  The
	# section flag, however, is reset so a future re-activation
	# triggers a fresh open.
	assert_false(_mirror._evade_section_active,
			"Evade-section flag must reset when evade_active is false.")
	_mirror.close()
	assert_eq(panel.evade_die_confirmed.get_connections().size(), 0,
			"evade_die_confirmed must be disconnected after close().")


func test_redirect_section_opens_when_redirect_active_flag_set() -> void:
	# Phase I6b-3 R4: when the attacker peer publishes
	# `redirect_active=true` (with a non-empty `redirect_adjacent_zones`
	# array and a positive `redirect_remaining`) into the payload, the
	# mirror opens the interactive zone-selection section and connects
	# `redirect_zone_selected` + `redirect_done_pressed` so clicks
	# submit a SelectRedirectZoneCommand / RedirectDoneCommand from
	# the defender peer.  Lowering `redirect_active` resets the flag
	# so future re-activation triggers a fresh open; close() drops the
	# signal connections.
	var payload: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"defender_name": "CR90",
		"defender_player": 1,
		"defender_ship_index": 0,
		"defender_zone": Constants.HullZone.FRONT,
		"redirect_active": true,
		"redirect_adjacent_zones": [
			Constants.HullZone.LEFT, Constants.HullZone.RIGHT],
		"redirect_remaining": 2,
	}
	_mirror.apply_flow(payload,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	var panel: AttackSimPanel = _mirror.get_panel()
	assert_eq(panel.redirect_zone_selected.get_connections().size(), 1,
			"redirect_zone_selected must be connected while "
			+"redirect_active is true.")
	assert_eq(panel.redirect_done_pressed.get_connections().size(), 1,
			"redirect_done_pressed must be connected while "
			+"redirect_active is true.")
	# Lowering the flag hides the section but leaves the signal
	# connections (they're cleared in close()).  The section flag is
	# reset so a future re-activation triggers a fresh open.
	var off_payload: Dictionary = payload.duplicate(true)
	off_payload["redirect_active"] = false
	off_payload["redirect_adjacent_zones"] = []
	off_payload["redirect_remaining"] = 0
	_mirror.apply_flow(off_payload,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	assert_false(_mirror._redirect_section_active,
			"Redirect-section flag must reset when "
			+"redirect_active is false.")
	_mirror.close()
	assert_eq(panel.redirect_zone_selected.get_connections().size(), 0,
			"redirect_zone_selected must be disconnected after close().")
	assert_eq(panel.redirect_done_pressed.get_connections().size(), 0,
			"redirect_done_pressed must be disconnected after close().")


func test_clearing_defender_drops_target_title() -> void:
	# Phase I6b-3 R1b follow-up: between consecutive attacks the host
	# clears the defender identity in the payload.  The mirror must
	# revert to the initial-attack prompt instead of leaving the stale
	# "→ <previous target>" title visible.
	var with_target: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"attacker_zone": Constants.HullZone.FRONT,
		"attacker_zone_name": "FRONT",
		"defender_name": "TIE A",
		"defender_zone": - 1,
		"range_band": "close",
	}
	_mirror.apply_flow(with_target, Constants.ModalKind.NONE)
	assert_string_contains(_mirror.get_panel().get_title_text(),
			"TIE A",
			"Title should show the first target before the clear "
			+"patch arrives.")
	# Host publishes the clear-target patch between attacks.
	var without_target: Dictionary = {
		"attacker_kind": "ship",
		"attacker_name": "Demolisher",
		"defender_name": "",
	}
	_mirror.apply_flow(without_target, Constants.ModalKind.NONE)
	var title: String = _mirror.get_panel().get_title_text()
	assert_false(title.contains("TIE A"),
			"Cleared defender should remove the previous target name "
			+"from the title.")
	assert_string_contains(_mirror.get_panel().get_body_text(),
			"hull zone",
			"Body should revert to the initial-attack prompt.")

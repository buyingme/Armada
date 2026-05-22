## Unit tests for AttackSimPanel
##
## Covers: AS-PNL-001, AS-PNL-002, AS-PNL-003, AS-VIS-004, AS-VIS-011,
## AS-PNL-010, AS-PNL-011, AS-RNG-014.
extends GutTest


var _panel: AttackSimPanel = null


func before_each() -> void:
	_panel = AttackSimPanel.new()
	add_child_autofree(_panel)


func test_initial_state_hidden() -> void:
	assert_false(_panel.visible,
			"Panel should be hidden initially.")


func test_show_initial_makes_visible() -> void:
	_panel.show_initial()
	assert_true(_panel.visible,
			"Panel should be visible after show_initial().")


func test_show_initial_title_text() -> void:
	_panel.show_initial()
	assert_eq(_panel.get_title_text(), "Attack Simulator",
			"Title should say 'Attack Simulator'.")


func test_show_initial_body_text() -> void:
	_panel.show_initial()
	assert_eq(_panel.get_body_text(), AttackSimPanel.INITIAL_PROMPT,
			"Body should show the initial prompt.")


func test_close_hides_panel() -> void:
	_panel.show_initial()
	_panel.close()
	assert_false(_panel.visible,
			"Panel should be hidden after close().")


func test_show_hull_zone_selected_updates_title() -> void:
	_panel.show_initial()
	_panel.show_hull_zone_selected("CR90 Corvette A", "FRONT")
	assert_eq(_panel.get_title_text(),
			"Attacking: CR90 Corvette A — FRONT arc",
			"Title should show ship name and zone.")


func test_show_hull_zone_selected_updates_body() -> void:
	_panel.show_initial()
	_panel.show_hull_zone_selected("CR90 Corvette A", "FRONT")
	assert_eq(_panel.get_body_text(), "Select a target.",
			"Body should prompt target selection.")


func test_show_squadron_selected_updates_title() -> void:
	_panel.show_initial()
	_panel.show_squadron_selected("X-wing Alpha")
	assert_eq(_panel.get_title_text(),
			"Attacking: X-wing Alpha",
			"Title should show squadron name.")


func test_show_squadron_selected_updates_body() -> void:
	_panel.show_initial()
	_panel.show_squadron_selected("X-wing Alpha")
	assert_eq(_panel.get_body_text(), "Select a target.",
			"Body should prompt target selection.")


func test_show_target_selected_title_ship_to_ship() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90 Corvette A", "FRONT", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_title_text(),
			"CR90 Corvette A \u2014 FRONT \u2192 VSD \u2014 LEFT",
			"Title should show attacker → target with zones.")


func test_show_target_selected_body_clear() -> void:
	_panel.show_initial()
	_panel.show_target_selected("CR90", "FRONT", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_body_text(), "LOS: Clear",
			"Body should show LOS result.")


func test_show_target_selected_body_obstructed() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Obstructed by Nebulon-B")
	assert_eq(_panel.get_body_text(), "LOS: Obstructed by Nebulon-B",
			"Body should show obstructed result.")


func test_show_target_selected_body_blocked() -> void:
	_panel.show_initial()
	_panel.show_target_selected("CR90", "FRONT", "VSD", "LEFT", "Blocked")
	assert_eq(_panel.get_body_text(), "LOS: Blocked",
			"Body should show blocked result.")


func test_show_target_selected_squadron_attacker() -> void:
	_panel.show_initial()
	_panel.show_target_selected("X-wing Alpha", "", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_title_text(),
			"X-wing Alpha \u2192 VSD \u2014 LEFT",
			"Squadron attacker should omit zone in title.")


func test_show_target_selected_squadron_target() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "TIE Fighter Alpha", "", "Clear")
	assert_eq(_panel.get_title_text(),
			"CR90 \u2014 FRONT \u2192 TIE Fighter Alpha",
			"Squadron target should omit zone in title.")


func test_show_target_selected_both_squadrons() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"X-wing Alpha", "", "TIE Fighter Alpha", "", "Clear")
	assert_eq(_panel.get_title_text(),
			"X-wing Alpha \u2192 TIE Fighter Alpha",
			"Both squadrons should omit zones in title.")


# =========================================================================
# Range band display in body  (AS-RNG-014)
# =========================================================================

func test_show_target_selected_body_with_close_range() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Clear", "close")
	assert_eq(_panel.get_body_text(),
			"LOS: Clear \u00b7 Range: Close",
			"Body should include range band when provided.")


func test_show_target_selected_body_with_medium_range() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Obstructed", "medium")
	assert_eq(_panel.get_body_text(),
			"LOS: Obstructed \u00b7 Range: Medium",
			"Body should show medium range.")


func test_show_target_selected_body_with_long_range() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Clear", "long")
	assert_eq(_panel.get_body_text(),
			"LOS: Clear \u00b7 Range: Long",
			"Body should show long range.")


func test_show_target_selected_body_with_beyond_range() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Clear", "beyond")
	assert_eq(_panel.get_body_text(),
			"LOS: Clear \u00b7 Range: Beyond",
			"Body should show beyond range.")


func test_show_target_selected_body_no_range_band_omits_range() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_body_text(), "LOS: Clear",
			"Body should omit range when range_band is empty.")


func test_show_target_selected_body_empty_string_range_omits_range() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Clear", "")
	assert_eq(_panel.get_body_text(), "LOS: Clear",
			"Explicit empty string should also omit range.")


# ── Phase 6b-2: CF Dial Section ─────────────────────────────────────

func test_show_cf_dial_section_makes_container_visible() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	var colours: Array[String] = ["RED", "BLUE"]
	_panel.show_cf_dial_section(colours)
	# If the container is visible, the section was shown.
	assert_true(_panel._cf_dial_container.visible,
			"CF dial container should be visible.")


func test_hide_cf_dial_section_hides_container() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_cf_dial_section(["RED"] as Array[String])
	_panel.hide_cf_dial_section()
	assert_false(_panel._cf_dial_container.visible,
			"CF dial container should be hidden after hide.")


func test_cf_dial_colour_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel.show_cf_dial_section(["RED"] as Array[String])
	# Simulate the callback directly.
	_panel._on_cf_dial_colour("RED")
	assert_signal_emitted(_panel, "cf_dial_colour_selected",
			"cf_dial_colour_selected should be emitted.")


func test_cf_dial_skip_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel._on_cf_dial_skip()
	assert_signal_emitted(_panel, "cf_dial_skipped",
			"cf_dial_skipped should be emitted.")


# ── Phase 6b-2: Pre-roll Die Choice ─────────────────────────────────

func test_show_attack_pool_die_choice_sets_label_and_buttons() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_attack_pool_die_choice(DamagedMunitions.RULE_ID,
			DamagedMunitions.CHOICE_TITLE,
			["RED", "BLACK"] as Array[String])
	assert_true(_panel._obstruction_container.visible,
			"Shared die-choice container should be visible.")
	assert_eq(_panel._obstruction_label.text, DamagedMunitions.CHOICE_TITLE,
			"Shared die-choice label should show the supplied rule title.")
	assert_eq(_panel._obstruction_buttons.get_child_count(), 2,
			"Shared die-choice section should build one button per colour.")


func test_attack_pool_die_choice_signal_emits_reason_and_colour() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel.show_attack_pool_die_choice(DamagedMunitions.RULE_ID,
			DamagedMunitions.CHOICE_TITLE, ["BLUE"] as Array[String])
	_panel._on_obstruction_colour("BLUE")
	assert_signal_emitted(_panel, "attack_pool_die_selected",
			"Generic die-choice signal should emit for rule prompts.")
	var params: Array = get_signal_parameters(_panel,
			"attack_pool_die_selected")
	assert_eq(params, [DamagedMunitions.RULE_ID, "BLUE"],
			"Generic die-choice signal should include reason id and colour.")
	assert_signal_not_emitted(_panel, "obstruction_die_selected",
			"Rule prompts should not emit the obstruction-specific signal.")


func test_obstruction_die_choice_keeps_legacy_signal() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel.show_obstruction_die_choice(["RED"] as Array[String])
	_panel._on_obstruction_colour("RED")
	assert_signal_emitted(_panel, "obstruction_die_selected",
			"Obstruction prompt should still emit obstruction-specific signal.")


# ── Phase 6b-2: Roll Dice ───────────────────────────────────────────

func test_show_roll_button_makes_visible() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_roll_button()
	assert_true(_panel._roll_button.visible,
			"Roll button should be visible.")


func test_hide_roll_button_hides() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_roll_button()
	_panel.hide_roll_button()
	assert_false(_panel._roll_button.visible,
			"Roll button should be hidden.")


func test_roll_dice_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel._on_roll_pressed()
	assert_signal_emitted(_panel, "roll_dice_pressed",
			"roll_dice_pressed should be emitted.")


func test_show_dice_results_creates_textures() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY},
	]
	_panel.show_dice_results(results)
	assert_eq(_panel._dice_textures.size(), 2,
			"Should create 2 TextureRects.")
	assert_true(_panel._dice_container.visible,
			"Dice container should be visible.")


func test_hide_dice_results_clears_textures() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
	]
	_panel.show_dice_results(results)
	_panel.hide_dice_results()
	assert_eq(_panel._dice_textures.size(), 0,
			"Dice textures should be cleared.")
	assert_false(_panel._dice_container.visible,
			"Dice container should be hidden.")


# ── Phase 6b-2: CF Token Reroll ─────────────────────────────────────

func test_show_cf_token_section_makes_visible() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_cf_token_section()
	assert_true(_panel._cf_token_container.visible,
			"CF token container should be visible.")


func test_hide_cf_token_section_hides() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_cf_token_section()
	_panel.hide_cf_token_section()
	assert_false(_panel._cf_token_container.visible,
			"CF token container should be hidden.")


func test_cf_token_reroll_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel._selected_reroll_index = 1
	_panel._on_cf_token_reroll()
	assert_signal_emitted(_panel, "cf_token_reroll_requested",
			"cf_token_reroll_requested should be emitted.")


func test_cf_token_skip_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel._on_cf_token_skip()
	assert_signal_emitted(_panel, "cf_token_reroll_skipped",
			"cf_token_reroll_skipped should be emitted.")


# ── Phase 6b-2: Confirm / Skip Attack ───────────────────────────────

func test_show_confirm_button_makes_visible() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_confirm_button()
	assert_true(_panel._confirm_button.visible,
			"Confirm button should be visible.")


func test_hide_confirm_button_hides() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_confirm_button()
	_panel.hide_confirm_button()
	assert_false(_panel._confirm_button.visible,
			"Confirm button should be hidden.")


func test_confirm_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel._on_confirm_pressed()
	assert_signal_emitted(_panel, "confirm_pressed",
			"confirm_pressed should be emitted.")


func test_show_skip_attack_button_makes_visible() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_skip_attack_button()
	assert_true(_panel._skip_attack_button.visible,
			"Skip Attack button should be visible.")


func test_skip_attack_signal_emitted() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	watch_signals(_panel)
	_panel._on_skip_attack_pressed()
	# Signal is deferred until the player confirms Yes.
	assert_signal_not_emitted(_panel, "skip_attack_pressed",
			"skip_attack_pressed should not emit before confirmation.")
	_panel._on_skip_confirm_yes()
	assert_signal_emitted(_panel, "skip_attack_pressed",
			"skip_attack_pressed should be emitted after Yes.")


# ── Phase 6b-2: show_dice_count exec mode no Done button ────────────

func test_show_dice_count_exec_mode_hides_done_button() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_dice_count("2 red, 1 blue")
	assert_false(_panel._done_button.visible,
			"Done button should not show in attack execution mode.")


func test_show_attack_blocked_skip_keeps_skip_available() -> void:
	_panel.show_initial_attack_exec("Test Ship")
	_panel.show_skip_attack_button()
	_panel.show_target_selected("Attacker", "FRONT",
			"Defender", "FRONT", "Clear", "long")
	_panel.show_dice_count("2 red")
	_panel.show_attack_blocked_skip(
			"Attack blocked by damage card. Select another target or skip.")
	assert_true(_panel._skip_attack_button.visible,
			"Blocked attacks should leave Skip Attack available.")
	assert_false(_panel._dice_count_label.visible,
			"Blocked attacks should hide the stale dice count.")
	assert_eq(_panel.get_body_text(),
			"Attack blocked by damage card. Select another target or skip.",
			"Blocked attacks should explain that the player can skip.")


func test_show_dice_count_sim_mode_shows_done_button() -> void:
	_panel.show_initial()
	_panel.show_dice_count("2 red")
	assert_true(_panel._done_button.visible,
			"Done button should show in sim mode.")


# =========================================================================
# Phase 6b-3 — show_select_next_squadron
# =========================================================================

func test_show_select_next_squadron_title() -> void:
	_panel.show_initial()
	_panel.show_select_next_squadron("CR90 Corvette A", "FRONT")
	assert_eq(_panel.get_title_text(),
			"CR90 Corvette A — FRONT arc",
			"Title should show ship and zone for next squadron prompt.")


func test_show_select_next_squadron_body() -> void:
	_panel.show_initial()
	_panel.show_select_next_squadron("CR90 Corvette A", "FRONT")
	assert_eq(_panel.get_body_text(),
			"Select next squadron in arc, or Skip.",
			"Body should prompt for next squadron or skip.")


# =========================================================================
# Skip Attack Button — Visibility at Attack Start
# =========================================================================

func test_skip_attack_button_hidden_initially() -> void:
	_panel.show_initial()
	assert_false(_panel._skip_attack_button.visible,
			"Skip Attack should be hidden initially.")


func test_skip_attack_button_visible_after_show() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	assert_true(_panel._skip_attack_button.visible,
			"Skip Attack should be visible after show_skip_attack_button.")


func test_skip_attack_button_hidden_after_hide() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	_panel.hide_skip_attack_button()
	assert_false(_panel._skip_attack_button.visible,
			"Skip Attack should be hidden after hide_skip_attack_button.")


# =========================================================================
# Skip Attack Confirmation Prompt
# =========================================================================


func test_skip_confirm_hidden_initially() -> void:
	_panel.show_initial()
	assert_false(_panel._skip_confirm_container.visible,
			"Skip confirmation should be hidden initially.")


func test_skip_confirm_shown_on_skip_press() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	_panel._on_skip_attack_pressed()
	assert_true(_panel._skip_confirm_container.visible,
			"Skip confirmation should appear after pressing Skip Attack.")
	assert_false(_panel._skip_attack_button.visible,
			"Skip Attack button should be hidden during confirmation.")


func test_skip_confirm_yes_emits_signal() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	watch_signals(_panel)
	_panel._on_skip_attack_pressed()
	_panel._on_skip_confirm_yes()
	assert_signal_emitted(_panel, "skip_attack_pressed",
			"Confirming Yes should emit skip_attack_pressed.")


func test_skip_confirm_no_restores_button() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	_panel._on_skip_attack_pressed()
	_panel._on_skip_confirm_no()
	assert_false(_panel._skip_confirm_container.visible,
			"Confirmation should hide after pressing No.")
	assert_true(_panel._skip_attack_button.visible,
			"Skip Attack button should reappear after pressing No.")


func test_skip_confirm_no_does_not_emit() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	watch_signals(_panel)
	_panel._on_skip_attack_pressed()
	_panel._on_skip_confirm_no()
	assert_signal_not_emitted(_panel, "skip_attack_pressed",
			"Pressing No should not emit skip_attack_pressed.")


func test_show_skip_resets_pending_confirm() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	_panel._on_skip_attack_pressed()
	# Re-showing skip should dismiss the confirmation.
	_panel.show_skip_attack_button()
	assert_false(_panel._skip_confirm_container.visible,
			"show_skip_attack_button should dismiss pending confirmation.")
	assert_true(_panel._skip_attack_button.visible,
			"Skip Attack button should be visible after re-show.")


func test_hide_skip_also_hides_confirm() -> void:
	_panel.show_initial()
	_panel.show_skip_attack_button()
	_panel._on_skip_attack_pressed()
	_panel.hide_skip_attack_button()
	assert_false(_panel._skip_confirm_container.visible,
			"hide_skip_attack_button should also hide confirmation.")

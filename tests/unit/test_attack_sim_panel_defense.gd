## Test: AttackSimPanel — Phase 6c UI sections.
##
## Tests for accuracy spending section, defense token section, redirect
## section, and damage info display.
## Requirements: AE-ACC-001–008, AE-DEF-001–016, AE-DMG-001.
extends GutTest


var _panel: AttackSimPanel = null


func before_each() -> void:
	_panel = AttackSimPanel.new()
	add_child_autofree(_panel)
	_panel.show_initial()


# =========================================================================
# Accuracy Section
# =========================================================================

func test_show_accuracy_section_visible() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 1)
	assert_true(_panel._accuracy_container.visible,
			"Accuracy container should be visible")


func test_show_accuracy_section_creates_buttons() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 2)
	assert_eq(_panel._accuracy_token_buttons.get_child_count(), 2,
			"Should create 2 token buttons")


func test_show_accuracy_section_skips_discarded() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.DISCARDED},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 1)
	assert_eq(_panel._accuracy_token_buttons.get_child_count(), 1,
			"Should skip discarded tokens")


func test_hide_accuracy_section_hides() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 1)
	_panel.hide_accuracy_section()
	assert_false(_panel._accuracy_container.visible,
			"Accuracy container should be hidden")


func test_accuracy_lock_toggle_adds_index() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 2)
	# Simulate pressing token 0.
	_panel._on_accuracy_token_pressed(0)
	var locked: Array[int] = _panel.get_accuracy_locked_indices()
	assert_true(0 in locked, "Token 0 should be locked after press")


func test_accuracy_lock_toggle_removes_on_second_press() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 1)
	_panel._on_accuracy_token_pressed(0)
	_panel._on_accuracy_token_pressed(0)
	var locked: Array[int] = _panel.get_accuracy_locked_indices()
	assert_false(0 in locked, "Token 0 should be unlocked after second press")


func test_accuracy_budget_limits_locks() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_accuracy_section(tokens, 1)
	_panel._on_accuracy_token_pressed(0)
	_panel._on_accuracy_token_pressed(1)
	var locked: Array[int] = _panel.get_accuracy_locked_indices()
	assert_eq(locked.size(), 1,
			"Budget of 1 should limit to 1 locked token")


# =========================================================================
# Defense Section
# =========================================================================

func test_show_defense_section_visible() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	var locked: Array[int] = []
	_panel.show_defense_section(tokens, locked, 3, 2)
	assert_true(_panel._defense_container.visible,
			"Defense container should be visible")


func test_show_defense_section_speed_zero_message() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 0)
	assert_true("Speed 0" in _panel._defense_info_label.text,
			"Speed 0 message should appear")


func test_show_defense_section_locked_tokens_disabled() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	var locked: Array[int] = [0]
	_panel.show_defense_section(tokens, locked, 3, 2)
	# The first button should be disabled (locked).
	var first_btn: Button = (
			_panel._defense_token_buttons.get_child(0) as Button)
	assert_true(first_btn.disabled,
			"Locked token button should be disabled")


func test_show_defense_section_blocked_tokens_disabled() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.EXHAUSTED},
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	var blocked: Array[int] = [0]
	_panel.show_defense_section(tokens, [], 3, 2,
			{"blocked_indices": blocked})
	var first_btn: Button = (
			_panel._defense_token_buttons.get_child(0) as Button)
	assert_true(first_btn.disabled,
			"Blocked token button should be disabled")
	assert_true("[BLOCKED]" in first_btn.text,
			"Blocked token button should explain its disabled state")
	_panel._on_defense_token_pressed(0)
	assert_true(_panel.get_defense_selected_indices().is_empty(),
			"Blocked token should not enter selected indices")


func test_hide_defense_section_hides() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	_panel.hide_defense_section()
	assert_false(_panel._defense_container.visible,
			"Defense container should be hidden")


func test_update_defense_damage_updates_label() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 5, 2)
	_panel.update_defense_damage(3)
	assert_true("3" in _panel._defense_info_label.text,
			"Damage label should show updated damage")


# =========================================================================
# Defense Toggle / Deselect / Commit
# =========================================================================

func test_defense_token_toggle_selects() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 4, 2)
	_panel._on_defense_token_pressed(0)
	var selected: Array[int] = _panel.get_defense_selected_indices()
	assert_true(0 in selected,
			"Token 0 should be selected after first press")


func test_defense_token_toggle_deselects() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 4, 2)
	_panel._on_defense_token_pressed(0)
	_panel._on_defense_token_pressed(0)
	var selected: Array[int] = _panel.get_defense_selected_indices()
	assert_false(0 in selected,
			"Token 0 should be deselected after second press")


func test_defense_token_highlight_on_select() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	_panel._on_defense_token_pressed(0)
	var btn: Button = _panel._defense_token_buttons.get_child(0) as Button
	assert_eq(btn.modulate, Color(0.3, 1.0, 0.3, 1.0),
			"Selected button should have green modulate")
	assert_true(btn.text.ends_with("✓"),
			"Selected button text should end with checkmark")


func test_defense_token_highlight_removed_on_deselect() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	_panel._on_defense_token_pressed(0)
	_panel._on_defense_token_pressed(0)
	var btn: Button = _panel._defense_token_buttons.get_child(0) as Button
	assert_eq(btn.modulate, Color.WHITE,
			"Deselected ready token should have white modulate")
	assert_false(btn.text.ends_with("✓"),
			"Deselected button text should not have checkmark")


func test_defense_token_exhausted_restores_orange_on_deselect() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.EXHAUSTED},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	_panel._on_defense_token_pressed(0)
	_panel._on_defense_token_pressed(0)
	var btn: Button = _panel._defense_token_buttons.get_child(0) as Button
	assert_eq(btn.modulate, Color(1.0, 0.7, 0.3, 1.0),
			"Deselected exhausted token should restore orange modulate")


func test_defense_one_per_type_deselects_previous() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.REDIRECT,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.REDIRECT,
				"state": Constants.DefenseTokenState.EXHAUSTED},
	]
	_panel.show_defense_section(tokens, [], 4, 2)
	_panel._on_defense_token_pressed(0)
	_panel._on_defense_token_pressed(1)
	var selected: Array[int] = _panel.get_defense_selected_indices()
	assert_false(0 in selected,
			"First Redirect should be deselected when second is selected")
	assert_true(1 in selected,
			"Second Redirect should be selected")


func test_defense_different_types_both_selected() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 5, 2)
	_panel._on_defense_token_pressed(0)
	_panel._on_defense_token_pressed(1)
	var selected: Array[int] = _panel.get_defense_selected_indices()
	assert_eq(selected.size(), 2,
			"Two tokens of different types should both be selected")


func test_defense_get_selected_returns_empty_initially() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 4, 2)
	var selected: Array[int] = _panel.get_defense_selected_indices()
	assert_eq(selected.size(), 0,
			"No tokens should be selected initially")


func test_defense_show_section_clears_prior_selection() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 4, 2)
	_panel._on_defense_token_pressed(0)
	# Re-show section — selection should reset.
	_panel.show_defense_section(tokens, [], 4, 2)
	var selected: Array[int] = _panel.get_defense_selected_indices()
	assert_eq(selected.size(), 0,
			"Prior selection should be cleared on re-show")


func test_defense_disable_all_buttons_disables() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 4, 2)
	_panel.disable_all_defense_buttons()
	for child: Node in _panel._defense_token_buttons.get_children():
		var btn: Button = child as Button
		if btn:
			assert_true(btn.disabled,
					"All buttons should be disabled after disable_all")


func test_defense_disable_all_hides_commit_button() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	_panel.disable_all_defense_buttons()
	assert_false(_panel._defense_done_button.visible,
			"Commit button should be hidden after disable_all")


func test_defense_commit_button_text() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	assert_eq(_panel._defense_done_button.text, "Commit Defense",
			"Done button should read 'Commit Defense'")


func test_defense_done_emits_signal() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	watch_signals(_panel)
	_panel._on_defense_done()
	assert_signal_emitted(_panel, "defense_tokens_done",
			"defense_tokens_done should be emitted on commit press")


func test_redirect_done_emits_signal() -> void:
	var zones: Array = [Constants.HullZone.LEFT]
	_panel.show_redirect_section(zones, 1)
	watch_signals(_panel)
	_panel._on_redirect_done_pressed()
	assert_signal_emitted(_panel, "redirect_done_pressed",
			"redirect_done_pressed should be emitted")


# =========================================================================
# Redirect Section
# =========================================================================

func test_show_redirect_section_visible() -> void:
	var zones: Array = [Constants.HullZone.LEFT, Constants.HullZone.RIGHT]
	_panel.show_redirect_section(zones, 2)
	assert_true(_panel._redirect_container.visible,
			"Redirect container should be visible")


func test_show_redirect_section_creates_zone_buttons() -> void:
	var zones: Array = [Constants.HullZone.LEFT, Constants.HullZone.RIGHT]
	_panel.show_redirect_section(zones, 2)
	assert_eq(_panel._redirect_zone_buttons.get_child_count(), 2,
			"Should create 2 zone buttons")


func test_hide_redirect_section_hides() -> void:
	var zones: Array = [Constants.HullZone.LEFT]
	_panel.show_redirect_section(zones, 1)
	_panel.hide_redirect_section()
	assert_false(_panel._redirect_container.visible,
			"Redirect container should be hidden")


# =========================================================================
# Damage Info
# =========================================================================

func test_show_damage_info_visible() -> void:
	_panel.show_damage_info("FRONT: 2 shield, 3 cards")
	assert_true(_panel._damage_info_container.visible,
			"Damage info should be visible")


func test_show_damage_info_text() -> void:
	_panel.show_damage_info("Test damage text")
	assert_eq(_panel._damage_info_label.text, "Test damage text",
			"Damage info should show the given text")


func test_hide_damage_info_hides() -> void:
	_panel.show_damage_info("Test")
	_panel.hide_damage_info()
	assert_false(_panel._damage_info_container.visible,
			"Damage info should be hidden")


# =========================================================================
# Evade Die Selection
# =========================================================================

func test_show_evade_die_selection_enables_evade_mode() -> void:
	# Build dice first so clickable dice exist.
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.HIT},
	]
	_panel.show_dice_results(dice)
	_panel.show_evade_die_selection(Constants.RANGE_BAND_LONG)
	assert_true(_panel._evade_mode,
			"Evade mode should be true after show_evade_die_selection")


func test_show_evade_die_selection_long_range_prompt() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
	]
	_panel.show_dice_results(dice)
	_panel.show_evade_die_selection(Constants.RANGE_BAND_LONG)
	assert_true("remove" in _panel._defense_info_label.text,
			"Long range evade prompt should mention 'remove'")


func test_show_evade_die_selection_medium_range_prompt() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 3, 2)
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
	]
	_panel.show_dice_results(dice)
	_panel.show_evade_die_selection(Constants.RANGE_BAND_MEDIUM)
	assert_true("reroll" in _panel._defense_info_label.text,
			"Medium range evade prompt should mention 'reroll'")


func test_hide_evade_die_selection_clears_mode() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
	]
	_panel.show_dice_results(dice)
	_panel.show_evade_die_selection(Constants.RANGE_BAND_LONG)
	_panel.hide_evade_die_selection()
	assert_false(_panel._evade_mode,
			"Evade mode should be false after hide")


func test_evade_die_click_emits_signal() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY},
	]
	_panel.show_dice_results(dice)
	_panel.show_evade_die_selection(Constants.RANGE_BAND_LONG)
	# Watch for signal.
	watch_signals(_panel)
	# Simulate clicking die 0.
	if _panel._dice_textures.size() > 0:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.pressed = true
		event.button_index = MOUSE_BUTTON_LEFT
		_panel._on_die_clicked(event, _panel._dice_textures[0])
	assert_signal_emitted(_panel, "evade_die_confirmed",
			"evade_die_confirmed should be emitted on die click")


# =========================================================================
# Brace Pending Indicator
# =========================================================================

func test_update_defense_damage_brace_pending_shows_indicator() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 6, 2)
	_panel.update_defense_damage(6, true)
	assert_true("Brace pending" in _panel._defense_info_label.text,
			"Brace pending indicator should appear")
	assert_true("3" in _panel._defense_info_label.text,
			"Braced damage preview (3) should appear")


func test_update_defense_damage_no_brace_no_indicator() -> void:
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
	]
	_panel.show_defense_section(tokens, [], 6, 2)
	_panel.update_defense_damage(4)
	assert_false("Brace" in _panel._defense_info_label.text,
			"No brace indicator without brace_pending")

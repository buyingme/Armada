## Unit tests for the Attack Simulator button on ActionToolbar.
##
## Covers: AS-ACT-001 — "A" button exists, emits signal, disabled with other tools.
extends GutTest


var _toolbar: ActionToolbar = null


func before_each() -> void:
	_toolbar = ActionToolbar.new()
	add_child_autofree(_toolbar)
	_toolbar.setup_buttons()


func test_attack_sim_button_exists() -> void:
	assert_not_null(_toolbar._attack_sim_btn,
			"Attack simulator button should exist after setup.")


func test_attack_sim_button_text_is_a() -> void:
	assert_eq(_toolbar._attack_sim_btn.text, "A",
			"Attack simulator button should display 'A'.")


func test_attack_sim_button_tooltip() -> void:
	assert_eq(_toolbar._attack_sim_btn.tooltip_text, "Attack Simulator",
			"Attack simulator button tooltip should be 'Attack Simulator'.")


func test_set_tool_buttons_disabled_disables_attack_sim() -> void:
	_toolbar.set_tool_buttons_disabled(true)
	assert_true(_toolbar._attack_sim_btn.disabled,
			"Attack simulator button should be disabled.")


func test_set_tool_buttons_disabled_enables_attack_sim() -> void:
	_toolbar.set_tool_buttons_disabled(true)
	_toolbar.set_tool_buttons_disabled(false)
	assert_false(_toolbar._attack_sim_btn.disabled,
			"Attack simulator button should be re-enabled.")

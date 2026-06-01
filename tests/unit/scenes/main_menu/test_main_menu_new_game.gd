## Test: Main Menu New Game
##
## Focused UI tests for the FB14A local New Game choice window.
extends GutTest


const MAIN_MENU_SCRIPT: GDScript = preload("res://src/scenes/main_menu/main_menu.gd")
const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")
var _menu: Variant = null


func before_each() -> void:
	GameManager.consume_next_scenario_id("")
	GameManager.consume_next_setup_match_type(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)
	_menu = MAIN_MENU_SCRIPT.new()
	_menu.transition_on_new_game_choice = false


func after_each() -> void:
	GameManager.consume_next_scenario_id("")
	GameManager.consume_next_setup_match_type(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)
	if _menu != null:
		_menu.free()
	_menu = null


func test_new_game_dialog_contains_five_match_choices_expected() -> void:
	var dialog: PanelContainer = _menu._build_scenario_dialog()
	var labels: Array[String] = _button_labels(dialog)

	assert_true(labels.has(SETUP_MATCH_OPTIONS_SCRIPT.LABEL_STANDARD_400),
			"New Game dialog should include Standard 400.")
	assert_true(labels.has(SETUP_MATCH_OPTIONS_SCRIPT.LABEL_INTERMEDIATE_300),
			"New Game dialog should include Intermediate 300.")
	assert_true(labels.has(SETUP_MATCH_OPTIONS_SCRIPT.LABEL_CORE_SET_180),
			"New Game dialog should include Core Set 180.")
	assert_true(labels.has(SETUP_MATCH_OPTIONS_SCRIPT.LABEL_LEARNING_SCENARIO),
			"New Game dialog should include Learning Scenario.")
	assert_true(labels.has(SETUP_MATCH_OPTIONS_SCRIPT.LABEL_DEBUG_SCENARIO),
			"New Game dialog should include Debug Scenario.")
	dialog.free()


func test_new_game_setup_choice_stores_pending_match_type_expected() -> void:
	_menu._on_new_game_choice_pressed(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_INTERMEDIATE_300)
	var match_type_id: String = GameManager.consume_next_setup_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)

	assert_eq(match_type_id, SETUP_MATCH_OPTIONS_SCRIPT.MATCH_INTERMEDIATE_300,
			"Intermediate 300 should be handed to setup flow.")


func test_new_game_learning_choice_stores_scenario_id_expected() -> void:
	_menu._on_new_game_choice_pressed(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_SCENARIO)
	var scenario_id: String = GameManager.consume_next_scenario_id("")

	assert_eq(scenario_id, SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_SCENARIO,
			"Learning Scenario should keep the fixed scenario start path.")


func _button_labels(root: Node) -> Array[String]:
	var labels: Array[String] = []
	for child: Node in root.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null:
			labels.append(button.text)
	return labels

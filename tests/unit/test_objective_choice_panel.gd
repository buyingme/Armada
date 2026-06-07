## Test: ObjectiveChoicePanel
##
## Focused regression coverage for objective-card selection and locked styling.
extends GutTest


const OBJECTIVE_PANEL_SCRIPT: GDScript = preload(
		"res://src/ui/objective_choice_panel.gd")

var _panel: Control = null


func before_each() -> void:
	_panel = OBJECTIVE_PANEL_SCRIPT.new()
	add_child_autofree(_panel)


func test_choose_objective_updates_visible_selected_style_expected() -> void:
	_panel.configure(_selection_payload())
	_panel.choose_objective("obj_ass_opening_salvo")
	var button: Button = _button_for("obj_ass_opening_salvo")
	var style: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat

	assert_false(button.flat,
			"Objective cards should use styled button rendering so selection highlights stay visible.")
	assert_eq(style.border_color, UIStyleHelper.BLUE_ACCENT,
			"Choosing an objective should apply the selected highlight border.")


func test_configure_with_locked_choice_dims_other_cards_expected() -> void:
	_panel.configure(_locked_payload("obj_ass_opening_salvo"))
	var chosen_button: Button = _button_for("obj_ass_opening_salvo")
	var chosen_style: StyleBoxFlat = chosen_button.get_theme_stylebox("normal") as StyleBoxFlat
	var dimmed_button: Button = _button_for("obj_def_fleet_ambush")

	assert_eq(chosen_style.border_color, Color(0.4, 0.9, 0.4),
			"Locked objective should keep the confirmed highlight border.")
	assert_eq(dimmed_button.modulate, Color(0.45, 0.45, 0.45, 0.85),
			"Unchosen objectives should grey out once the choice is locked.")


func _selection_payload() -> Dictionary:
	return {
		"heading": "Objective Choice",
		"subtitle": "Select one objective.",
		"objectives": _objectives(),
		"confirmed_key": "",
		"selection_locked": false,
		"can_select": true,
		"can_confirm": false,
		"status_text": "Choose an objective.",
	}


func _locked_payload(objective_key: String) -> Dictionary:
	var payload: Dictionary = _selection_payload()
	payload["confirmed_key"] = objective_key
	payload["selection_locked"] = true
	payload["can_select"] = false
	payload["can_confirm"] = true
	return payload


func _objectives() -> Array[Dictionary]:
	return [
		{
			"data_key": "obj_ass_opening_salvo",
			"category": FleetObjectiveSelection.CATEGORY_ASSAULT,
			"objective_name": "Opening Salvo",
		},
		{
			"data_key": "obj_def_fleet_ambush",
			"category": FleetObjectiveSelection.CATEGORY_DEFENSE,
			"objective_name": "Fleet Ambush",
		},
	]


func _button_for(objective_key: String) -> Button:
	return _panel._card_buttons[objective_key] as Button
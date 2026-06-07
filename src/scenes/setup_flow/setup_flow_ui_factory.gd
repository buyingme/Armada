## Setup Flow UI Factory
##
## Small presentation helpers for the local setup-package confirmation screen.
## Keeps SetupFlowScene focused on selection state and package handoff.
class_name SetupFlowUiFactory
extends RefCounted


## Creates the setup-flow background fill.
static func build_background() -> ColorRect:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.04, 0.05, 0.08, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return background


## Creates the centered setup-flow modal panel.
static func build_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "SetupFlowPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UIStyleHelper.create_modal_panel_style(0.0))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	return panel


## Adds a labelled option row to [param parent].
static func build_option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 28)
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(360, 32)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	parent.add_child(row)
	return option


## Adds a labelled segmented-button row to [param parent].
static func build_segmented_row(
		parent: VBoxContainer,
		label_text: String,
		button_texts: Array) -> Array[Button]:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 28)
	row.add_child(label)
	var buttons_box: HBoxContainer = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 8)
	buttons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(buttons_box)
	parent.add_child(row)
	return _build_segmented_buttons(buttons_box, button_texts)


static func _build_segmented_buttons(
		parent: HBoxContainer,
		button_texts: Array) -> Array[Button]:
	var buttons: Array[Button] = []
	var group: ButtonGroup = ButtonGroup.new()
	for raw_text: Variant in button_texts:
		var button: Button = Button.new()
		button.text = str(raw_text)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(176, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(button)
		buttons.append(button)
	return buttons


## Adds a labelled text-input row to [param parent].
static func build_text_row(parent: VBoxContainer, label_text: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 28)
	row.add_child(label)
	var input: LineEdit = LineEdit.new()
	input.custom_minimum_size = Vector2(360, 32)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	parent.add_child(row)
	return input


## Creates a standard setup-flow action button.
static func build_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 36)
	return button


## Returns display text for a local fleet summary row.
static func fleet_label(summary: Dictionary) -> String:
	var limit: int = int((summary.get("point_format", {}) as Dictionary).get("limit", 0))
	return "%s (%s, %d)" % [
		str(summary.get("name", summary.get("fleet_id", ""))),
		str(summary.get("faction", "")),
		limit,
	]


## Returns display text for an objective choice row.
static func objective_label(category: String, objective_key: String) -> String:
	var data: ObjectiveData = AssetLoader.load_objective_data(objective_key)
	var objective_name: String = objective_key
	if data != null:
		objective_name = data.objective_name
	return "%s - %s" % [category.capitalize(), objective_name]


## Returns compact package summary text for the confirmation panel.
static func package_summary(package: FleetSetupPackage) -> String:
	var map_label: String = str(package.map.get("label", package.map.get("filename", "")))
	var objective_name: String = str(package.selected_objective.get("objective_name", ""))
	return "Map: %s | First Player: %s | Objective: %s" % [
		map_label,
		player_display_name(package.players, package.first_player),
		objective_name,
	]


## Returns the display name for [param player_index] from setup package players.
static func player_display_name(players: Array[Dictionary], player_index: int) -> String:
	for player: Dictionary in players:
		if int(player.get("player_index", -1)) != player_index:
			continue
		var display_name: String = str(player.get("display_name", "")).strip_edges()
		if not display_name.is_empty():
			return display_name
		return "Fleet %d" % (player_index + 1)
	return "Fleet %d" % (player_index + 1)


## Returns the selected option metadata as a string.
static func selected_option_metadata(option: OptionButton) -> String:
	if option == null or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


## Returns both selected fleet ids in player-index order.
static func selected_fleet_ids(player_zero: OptionButton, player_one: OptionButton) -> Array[String]:
	return [selected_option_metadata(player_zero), selected_option_metadata(player_one)]


## Returns true when selections are sufficient to attempt package construction.
static func selection_complete(fleet_ids: Array[String], objective_key: String) -> bool:
	var has_two_players: bool = fleet_ids.size() == Constants.PLAYER_COUNT
	var has_player_zero: bool = has_two_players and not fleet_ids[0].is_empty()
	var has_player_one: bool = has_two_players and not fleet_ids[1].is_empty()
	return has_player_zero and has_player_one \
			and fleet_ids[0] != fleet_ids[1] \
			and not objective_key.strip_edges().is_empty()


## Returns the opposite two-player setup index.
static func other_player(player_index: int) -> int:
	return 1 if player_index == 0 else 0

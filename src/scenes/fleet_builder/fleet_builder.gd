## Fleet Builder Scene
##
## Local-first fleet-builder MVP. The scene renders catalog, roster,
## validation, and rules-reference data from core services without owning
## construction legality or PlayMode-specific behavior.
class_name FleetBuilderScene
extends Control


signal return_to_menu_requested

const MAIN_MENU_PATH: String = "res://src/scenes/main_menu/main_menu.tscn"
const CARD_ART_MIN_SIZE: Vector2 = Vector2(300, 420)
const STATUS_PANEL_MIN_SIZE: Vector2 = Vector2(0, 36)
const CATALOG_PANEL_MIN_SIZE: Vector2 = Vector2(300, 0)
const CATALOG_TABS_MIN_SIZE: Vector2 = Vector2(280, 0)
const ROSTER_PANEL_MIN_SIZE: Vector2 = Vector2(320, 0)
const REFERENCE_PANEL_MIN_SIZE: Vector2 = Vector2(340, 0)
const REFERENCE_TABS_MIN_SIZE: Vector2 = Vector2(320, 0)
const COMPONENT_RULES_LIST_MIN_SIZE: Vector2 = Vector2(0, 96)
const COMPONENT_RULES_TEXT_MIN_SIZE: Vector2 = Vector2(0, 150)
const VALIDATION_LIST_MIN_SIZE: Vector2 = Vector2(0, 128)
const OBJECTIVE_VIEW_BUTTON_SIZE: Vector2 = Vector2(72, 32)

var _catalog: FleetCatalog = FleetCatalog.new()
var _validator: FleetValidator = FleetValidator.new()
var _library_manager: FleetLibraryManager = FleetLibraryManager.new()
var _roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()
var _catalog_entries: Array[Dictionary] = []
var _selected_component_entry: Dictionary = {}
var _ship_counter: int = 0
var _squadron_counter: int = 0
var _upgrade_counter: int = 0

var _name_input: LineEdit
var _faction_option: OptionButton
var _format_option: OptionButton
var _points_label: Label
var _status_label: Label
var _catalog_type_option: OptionButton
var _catalog_upgrade_type_option: OptionButton
var _catalog_search_input: LineEdit
var _catalog_list: ItemList
var _ship_list: ItemList
var _upgrade_ship_option: OptionButton
var _upgrade_list: ItemList
var _squadron_list: ItemList
var _validation_list: ItemList
var _rules_list: ItemList
var _component_rules_list: ItemList
var _component_rules_text: RichTextLabel
var _rules_search_input: LineEdit
var _rules_category_option: OptionButton
var _rules_status_option: OptionButton
var _rules_text: RichTextLabel
var _card_art_rect: TextureRect
var _card_art_placeholder_label: Label
var _library_panel: FleetLibraryPanel
var _objective_options: Dictionary = {}
var _map_option: OptionButton


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_refresh_all()


## Returns the active editable roster. Intended for focused UI tests.
func current_roster() -> FleetRoster:
	return _roster


func _build_ui() -> void:
	add_child(_build_background())
	var margin: MarginContainer = _build_root_margin()
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	layout.add_child(_build_header())
	layout.add_child(_build_status_strip())
	layout.add_child(_build_main_area())


func _build_background() -> ColorRect:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.04, 0.05, 0.08, 1.0)
	background.set_anchors_preset(PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return background


func _build_root_margin() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	return margin


func _build_header() -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(_build_title_block())
	_name_input = _build_name_input()
	header.add_child(_name_input)
	_faction_option = _build_faction_option()
	header.add_child(_faction_option)
	_format_option = _build_format_option()
	header.add_child(_format_option)
	var back_button: Button = _create_action_button("Main Menu")
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	return header


func _build_title_block() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(180, 0)
	var title: Label = UIStyleHelper.create_title_label("Fleet Builder", UIStyleHelper.GOLD_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var subtitle: Label = UIStyleHelper.create_section_label("Local Draft", UIStyleHelper.FONT_HINT,
			UIStyleHelper.DIMMED_HINT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(subtitle)
	return box


func _build_name_input() -> LineEdit:
	var input: LineEdit = LineEdit.new()
	input.custom_minimum_size = Vector2(220, 36)
	input.text_changed.connect(_on_name_changed)
	return input


func _build_faction_option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(190, 36)
	for faction: String in FleetBuilderOptions.available_factions(_catalog):
		_add_option(option, _display_key(faction), faction)
	option.item_selected.connect(_on_faction_selected)
	return option


func _build_format_option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(160, 36)
	for format: Dictionary in FleetBuilderOptions.available_point_formats():
		_add_option(option, str(format.get("label", "")), format)
	option.item_selected.connect(_on_format_selected)
	return option


func _build_status_strip() -> PanelContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_points_label = _create_body_label("")
	_status_label = _create_body_label("")
	row.add_child(_points_label)
	row.add_child(_status_label)
	return _compact_status_panel(row)


func _build_main_area() -> HBoxContainer:
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	body.add_child(_build_fleet_data_panel())
	body.add_child(_build_roster_panel())
	body.add_child(_build_side_panel())
	return body


func _build_fleet_data_panel() -> PanelContainer:
	var tabs: TabContainer = TabContainer.new()
	tabs.name = "FleetDataTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = CATALOG_TABS_MIN_SIZE
	tabs.add_child(_build_catalog_tab())
	tabs.add_child(_build_library_tab())
	return _section_panel("Fleet Data", tabs, CATALOG_PANEL_MIN_SIZE)


func _build_catalog_tab() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Catalog"
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_catalog_type_option = _build_catalog_type_option()
	_catalog_upgrade_type_option = _build_upgrade_type_option()
	_catalog_search_input = _build_catalog_search_input()
	_catalog_list = _build_catalog_list()
	box.add_child(_catalog_type_option)
	box.add_child(_catalog_upgrade_type_option)
	box.add_child(_catalog_search_input)
	box.add_child(_catalog_list)
	box.add_child(_build_catalog_buttons())
	return box


func _build_catalog_type_option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	_add_option(option, "Ships", FleetCatalog.COMPONENT_SHIP)
	_add_option(option, "Squadrons", FleetCatalog.COMPONENT_SQUADRON)
	_add_option(option, "Upgrades", FleetCatalog.COMPONENT_UPGRADE)
	option.item_selected.connect(_on_catalog_filter_selected)
	return option


func _build_upgrade_type_option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size.y = 36
	_add_option(option, "All upgrade types", "")
	for group: Dictionary in FleetBuilderOptions.upgrade_type_groups(_catalog):
		_add_disabled_option(option, str(group.get("group", "")))
		for raw_type: Variant in group.get("types", []):
			var upgrade_type: String = str(raw_type)
			_add_option(option, _display_key(upgrade_type), upgrade_type)
	option.visible = false
	option.item_selected.connect(_on_upgrade_type_filter_selected)
	return option


func _build_catalog_search_input() -> LineEdit:
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = "Search"
	input.custom_minimum_size.y = 36
	input.text_changed.connect(_on_catalog_search_changed)
	return input


func _build_catalog_list() -> ItemList:
	var list: ItemList = ItemList.new()
	list.name = "CatalogList"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 420)
	list.item_selected.connect(_on_catalog_item_selected)
	list.item_clicked.connect(_on_catalog_item_clicked)
	return list


func _build_catalog_buttons() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_button_row(["Add Component"], [_on_add_component_pressed]))
	return box


func _build_roster_panel() -> PanelContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_ship_list = _build_roster_list("ShipList", 130)
	_upgrade_ship_option = OptionButton.new()
	_upgrade_ship_option.item_selected.connect(_on_upgrade_ship_selected)
	_upgrade_list = _build_roster_list("UpgradeList", 92)
	_squadron_list = _build_roster_list("SquadronList", 100)
	box.add_child(_labeled_control("Ships", _ship_list))
	box.add_child(_button_row(["Remove Ship"], [_on_remove_ship_pressed]))
	box.add_child(_labeled_control("Upgrade Ship", _upgrade_ship_option))
	box.add_child(_labeled_control("Upgrades", _upgrade_list))
	box.add_child(_button_row(["Remove Upgrade"], [_on_remove_upgrade_pressed]))
	box.add_child(_labeled_control("Squadrons", _squadron_list))
	box.add_child(_button_row(["Remove Squadron"], [_on_remove_squadron_pressed]))
	box.add_child(_build_objective_selectors())
	box.add_child(_build_map_selector())
	return _section_panel("Roster", box, ROSTER_PANEL_MIN_SIZE)


func _build_roster_list(node_name: String, height: int) -> ItemList:
	var list: ItemList = ItemList.new()
	list.name = node_name
	list.custom_minimum_size = Vector2(0, height)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match node_name:
		"ShipList":
			list.item_selected.connect(_on_ship_selected)
			list.item_clicked.connect(_on_ship_item_clicked)
		"UpgradeList":
			list.item_selected.connect(_on_upgrade_selected)
			list.item_clicked.connect(_on_upgrade_item_clicked)
		"SquadronList":
			list.item_selected.connect(_on_squadron_selected)
			list.item_clicked.connect(_on_squadron_item_clicked)
	return list


func _build_objective_selectors() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_create_body_label("Objectives"))
	for category: String in FleetBuilderOptions.objective_categories():
		var option: OptionButton = OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_populate_objective_option(option, category)
		option.item_selected.connect(_on_objective_selected.bind(category))
		_objective_options[category] = option
		box.add_child(_build_objective_row(category, option))
	return box


func _build_objective_row(category: String, option: OptionButton) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(option)
	var view_button: Button = Button.new()
	view_button.text = "View"
	view_button.custom_minimum_size = OBJECTIVE_VIEW_BUTTON_SIZE
	view_button.pressed.connect(_on_objective_view_pressed.bind(category))
	row.add_child(view_button)
	return row


func _build_map_selector() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_create_body_label("Map"))
	_map_option = OptionButton.new()
	_map_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_option.item_selected.connect(_on_map_selected)
	box.add_child(_map_option)
	return box


func _build_side_panel() -> PanelContainer:
	var tabs: TabContainer = TabContainer.new()
	tabs.name = "ReferenceTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = REFERENCE_TABS_MIN_SIZE
	tabs.add_child(_build_standard_tab())
	tabs.add_child(_build_rules_tab())
	tabs.add_child(_build_card_art_tab())
	return _section_panel("Reference", tabs, REFERENCE_PANEL_MIN_SIZE)


func _build_standard_tab() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Standard"
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_component_rules_list = ItemList.new()
	_component_rules_list.custom_minimum_size = COMPONENT_RULES_LIST_MIN_SIZE
	_component_rules_list.item_selected.connect(_on_component_rule_selected)
	_component_rules_text = RichTextLabel.new()
	_component_rules_text.custom_minimum_size = COMPONENT_RULES_TEXT_MIN_SIZE
	_component_rules_text.fit_content = false
	_component_rules_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_validation_list = ItemList.new()
	_validation_list.name = "ValidationList"
	_validation_list.custom_minimum_size = VALIDATION_LIST_MIN_SIZE
	_validation_list.size_flags_vertical = Control.SIZE_FILL
	box.add_child(_labeled_control("Validation", _validation_list))
	box.add_child(HSeparator.new())
	box.add_child(_labeled_control("Selected Component Rules", _component_rules_list))
	box.add_child(_component_rules_text)
	return box


func _build_library_tab() -> FleetLibraryPanel:
	_library_panel = FleetLibraryPanel.new()
	_library_panel.name = "Fleets"
	_library_panel.initialize(_library_manager, Callable(self , "current_roster"))
	_library_panel.roster_loaded.connect(_on_library_roster_loaded)
	return _library_panel


func _build_rules_tab() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Rules"
	box.add_theme_constant_override("separation", 8)
	_rules_search_input = _build_rules_search_input()
	_rules_category_option = _build_rules_category_option()
	_rules_status_option = _build_rules_status_option()
	_rules_list = ItemList.new()
	_rules_list.custom_minimum_size = Vector2(0, 150)
	_rules_list.item_selected.connect(_on_rules_item_selected)
	_rules_text = RichTextLabel.new()
	_rules_text.bbcode_enabled = false
	_rules_text.fit_content = false
	_rules_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_rules_search_input)
	box.add_child(_build_rules_filter_row())
	box.add_child(_labeled_control("All Rules", _rules_list))
	box.add_child(_rules_text)
	return box


func _build_card_art_tab() -> Control:
	var panel: Control = Control.new()
	panel.name = "Card Art"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_art_rect = TextureRect.new()
	_card_art_rect.name = "CardArtRect"
	_card_art_rect.custom_minimum_size = CARD_ART_MIN_SIZE
	_card_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_card_art_anchors(_card_art_rect)
	panel.add_child(_card_art_rect)
	panel.add_child(_build_card_art_placeholder())
	return panel


func _build_card_art_placeholder() -> CenterContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	_card_art_placeholder_label = _create_body_label("No card art selected")
	_card_art_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_card_art_placeholder_label)
	return center


func _build_rules_search_input() -> LineEdit:
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = "Search rules"
	input.custom_minimum_size.y = 36
	input.text_changed.connect(_on_rules_search_changed)
	return input


func _build_rules_filter_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_rules_category_option)
	row.add_child(_rules_status_option)
	return row


func _build_rules_category_option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_option(option, "All categories", "")
	for category: String in FleetBuilderOptions.rule_categories(_catalog):
		_add_option(option, _display_key(category), category)
	option.item_selected.connect(_on_rules_filter_selected)
	return option


func _build_rules_status_option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_option(option, "All statuses", "")
	for status: String in FleetBuilderOptions.rule_statuses(_catalog):
		_add_option(option, _display_key(status), status)
	option.item_selected.connect(_on_rules_filter_selected)
	return option


func _section_panel(title_text: String, content: Control,
		minimum_size: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "%sPanel" % title_text.replace(" ", "")
	panel.custom_minimum_size = minimum_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyleHelper.create_modal_panel_style(0.0))
	var margin: MarginContainer = _panel_margin()
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(UIStyleHelper.create_title_label(title_text, UIStyleHelper.GOLD_TITLE))
	box.add_child(content)
	return panel


func _compact_status_panel(content: Control) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "StatusPanel"
	panel.custom_minimum_size = STATUS_PANEL_MIN_SIZE
	panel.add_theme_stylebox_override("panel", UIStyleHelper.create_modal_panel_style(0.0))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	margin.add_child(content)
	return panel


func _panel_margin() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	return margin


func _labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label: Label = _create_body_label(label_text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(label)
	box.add_child(control)
	return box


func _button_row(labels: Array[String], callbacks: Array[Callable]) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for index: int in range(labels.size()):
		var button: Button = _create_action_button(labels[index])
		button.pressed.connect(callbacks[index])
		row.add_child(button)
	return row


func _create_action_button(label_text: String) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(120, 36)
	return button


func _create_body_label(text: String) -> Label:
	return UIStyleHelper.create_section_label(text, UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)


func _refresh_all() -> void:
	_refresh_header()
	_refresh_catalog()
	_refresh_roster_lists()
	_refresh_status()
	_refresh_validation()
	_refresh_rules_reference()


func _refresh_header() -> void:
	_name_input.text = _roster.name
	_select_option_metadata(_faction_option, _roster.faction)
	_select_point_format()


func _refresh_status() -> void:
	var summary: Dictionary = FleetRosterSummary.calculate(_roster)
	_points_label.text = "Points %d/%d | Ships %d | Squadrons %d | Upgrades %d" % [
		int(summary.get(FleetRosterSummary.KEY_TOTAL_POINTS, 0)),
		int(summary.get(FleetRosterSummary.KEY_POINT_LIMIT, 0)),
		int(summary.get(FleetRosterSummary.KEY_SHIP_POINTS, 0)),
		int(summary.get(FleetRosterSummary.KEY_SQUADRON_POINTS, 0)),
		int(summary.get(FleetRosterSummary.KEY_UPGRADE_POINTS, 0)),
	]


func _refresh_validation() -> void:
	_validation_list.clear()
	var result: FleetValidationResult = _validator.validate(_roster)
	if result.is_valid():
		_validation_list.add_item("Valid fleet")
		_status_label.text = "Valid"
		return
	_status_label.text = "%d issue(s)" % result.errors.size()
	for issue: Dictionary in result.errors:
		_validation_list.add_item("%s: %s" % [issue.get("rule_id", ""), issue.get("message", "")])


func _refresh_catalog() -> void:
	_catalog_list.clear()
	_catalog_entries = _catalog.query_components(_catalog_filters())
	for entry: Dictionary in _catalog_entries:
		var index: int = _catalog_list.add_item(_catalog_entry_label(entry))
		_catalog_list.set_item_metadata(index, entry)
	if not _catalog_entries.is_empty():
		_catalog_list.select(0)
		_select_component(_catalog_entries[0])
	else:
		_select_component({})


func _refresh_roster_lists() -> void:
	_refresh_ship_list()
	_refresh_upgrade_ship_option()
	_refresh_upgrade_list()
	_refresh_squadron_list()
	_refresh_objective_options()
	_refresh_map_options()


func _refresh_ship_list() -> void:
	_ship_list.clear()
	for ship_entry: FleetShipEntry in _roster.ships:
		var index: int = _ship_list.add_item(_ship_label(ship_entry))
		_ship_list.set_item_metadata(index, ship_entry.entry_id)


func _refresh_upgrade_ship_option() -> void:
	var selected_id: String = _selected_upgrade_ship_id()
	_upgrade_ship_option.clear()
	for ship_entry: FleetShipEntry in _roster.ships:
		_add_option(_upgrade_ship_option, _ship_label(ship_entry), ship_entry.entry_id)
	_select_option_metadata(_upgrade_ship_option, selected_id)


func _refresh_upgrade_list() -> void:
	_upgrade_list.clear()
	var ship_entry: FleetShipEntry = _roster.get_ship(_selected_upgrade_ship_id())
	if ship_entry == null:
		return
	for assignment: FleetUpgradeAssignment in ship_entry.upgrades:
		var index: int = _upgrade_list.add_item(_upgrade_label(assignment))
		_upgrade_list.set_item_metadata(index, assignment.entry_id)


func _refresh_squadron_list() -> void:
	_squadron_list.clear()
	for squadron_entry: FleetSquadronEntry in _roster.squadrons:
		var index: int = _squadron_list.add_item(_squadron_label(squadron_entry))
		_squadron_list.set_item_metadata(index, squadron_entry.entry_id)


func _refresh_objective_options() -> void:
	for category: String in FleetBuilderOptions.objective_categories():
		var option: OptionButton = _objective_options.get(category, null)
		if option != null:
			_select_option_metadata(option, _roster.objectives.get_objective(category))


func _refresh_map_options() -> void:
	if _map_option == null:
		return
	var maps: Array[Dictionary] = FleetBuilderOptions.available_maps_for_point_format(
			_roster.point_format)
	_ensure_roster_map_allowed(maps)
	_map_option.clear()
	for payload: Dictionary in maps:
		_add_option(_map_option, str(payload.get("label", "")), payload)
	_select_map_filename(_roster_map_filename())


func _refresh_rules_reference() -> void:
	_rules_list.clear()
	var entries: Array[Dictionary] = _catalog.query_components(_rules_filters())
	for entry: Dictionary in entries:
		var rule: RuleReferenceData = entry.get("resource", null)
		var index: int = _rules_list.add_item(_rule_label(rule))
		_rules_list.set_item_metadata(index, rule)
	if not entries.is_empty():
		_rules_list.select(0)
		_set_rule_text(entries[0].get("resource", null))
	else:
		_rules_text.text = ""


func _refresh_component_rules(entry: Dictionary) -> void:
	_component_rules_list.clear()
	_component_rules_text.text = ""
	if entry.is_empty():
		_component_rules_text.text = "No component selected."
		return
	_add_component_card_rule(entry)
	for rule: RuleReferenceData in _catalog.get_rules_for_component(entry):
		var index: int = _component_rules_list.add_item(_rule_label(rule))
		_component_rules_list.set_item_metadata(index, rule)
	if _component_rules_list.item_count > 0:
		_component_rules_list.select(0)
		_set_component_rule_metadata_text(_component_rules_list.get_item_metadata(0))
	else:
		_component_rules_text.text = "No linked rules for the selected component."


func _refresh_card_art(entry: Dictionary) -> void:
	if _card_art_rect == null:
		return
	var texture: Texture2D = _card_texture_for_entry(entry)
	_card_art_rect.texture = texture
	_card_art_rect.visible = texture != null
	_card_art_placeholder_label.visible = texture == null


func _catalog_filters() -> Dictionary:
	var filters: Dictionary = {
		"component_types": [_selected_catalog_type()],
		"faction": _roster.faction,
		"text": _catalog_search_input.text,
	}
	if _selected_catalog_type() == FleetCatalog.COMPONENT_UPGRADE:
		var upgrade_type: String = _selected_upgrade_type_filter()
		if not upgrade_type.is_empty():
			filters["upgrade_type"] = upgrade_type
	return filters


func _rules_filters() -> Dictionary:
	var filters: Dictionary = {"component_types": [FleetCatalog.COMPONENT_RULE_REFERENCE]}
	filters["text"] = _rules_search_input.text
	var category: String = _selected_option_metadata(_rules_category_option)
	var status: String = _selected_option_metadata(_rules_status_option)
	if not category.is_empty():
		filters["rules_category"] = category
	if not status.is_empty():
		filters["implementation_status"] = status
	return filters


func _populate_objective_option(option: OptionButton, category: String) -> void:
	_add_option(option, "%s objective" % _display_key(category), "")
	for key: String in AssetLoader.list_objective_keys():
		var objective: ObjectiveData = AssetLoader.load_objective_data(key)
		if objective != null and objective.category == category:
			_add_option(option, objective.objective_name, key)


func _on_name_changed(new_text: String) -> void:
	_roster.name = new_text.strip_edges()


func _on_faction_selected(index: int) -> void:
	_roster.faction = str(_faction_option.get_item_metadata(index))
	_refresh_all()


func _on_format_selected(index: int) -> void:
	var format: Dictionary = _format_option.get_item_metadata(index) as Dictionary
	_roster.point_format = {
		"id": str(format.get("id", "CUSTOM")),
		"limit": int(format.get("limit", FleetValidator.DEFAULT_POINT_LIMIT)),
		"custom_label": "",
	}
	_roster.map = FleetBuilderOptions.default_map_for_point_format(_roster.point_format)
	_refresh_all()


func _on_catalog_filter_selected(_index: int) -> void:
	_refresh_upgrade_type_visibility()
	_refresh_catalog()


func _on_upgrade_type_filter_selected(_index: int) -> void:
	_refresh_catalog()


func _on_catalog_search_changed(_new_text: String) -> void:
	_refresh_catalog()


func _on_catalog_item_selected(index: int) -> void:
	_activate_catalog_selection(index)


func _on_catalog_item_clicked(index: int, _at_position: Vector2,
		_mouse_button_index: int) -> void:
	_catalog_list.select(index)
	_activate_catalog_selection(index)


func _on_ship_selected(index: int) -> void:
	_activate_ship_selection(index)


func _on_ship_item_clicked(index: int, _at_position: Vector2,
		_mouse_button_index: int) -> void:
	_ship_list.select(index)
	_activate_ship_selection(index)


func _activate_ship_selection(index: int) -> void:
	_deselect_inactive_component_lists(_ship_list)
	var entry_id: String = str(_ship_list.get_item_metadata(index))
	_select_option_metadata(_upgrade_ship_option, entry_id)
	_refresh_upgrade_list()
	var ship_entry: FleetShipEntry = _roster.get_ship(entry_id)
	if ship_entry != null:
		_select_roster_component(FleetCatalog.COMPONENT_SHIP, ship_entry.data_key)


func _on_upgrade_selected(index: int) -> void:
	_activate_upgrade_selection(index)


func _on_upgrade_item_clicked(index: int, _at_position: Vector2,
		_mouse_button_index: int) -> void:
	_upgrade_list.select(index)
	_activate_upgrade_selection(index)


func _activate_upgrade_selection(_index: int) -> void:
	_deselect_inactive_component_lists(_upgrade_list)
	var assignment: FleetUpgradeAssignment = _selected_upgrade_assignment()
	if assignment != null:
		_select_roster_component(FleetCatalog.COMPONENT_UPGRADE, assignment.data_key)


func _on_squadron_selected(index: int) -> void:
	_activate_squadron_selection(index)


func _on_squadron_item_clicked(index: int, _at_position: Vector2,
		_mouse_button_index: int) -> void:
	_squadron_list.select(index)
	_activate_squadron_selection(index)


func _activate_squadron_selection(index: int) -> void:
	_deselect_inactive_component_lists(_squadron_list)
	var entry_id: String = str(_squadron_list.get_item_metadata(index))
	var squadron_entry: FleetSquadronEntry = _roster.get_squadron(entry_id)
	if squadron_entry != null:
		_select_roster_component(FleetCatalog.COMPONENT_SQUADRON, squadron_entry.data_key)


func _on_upgrade_ship_selected(_index: int) -> void:
	_refresh_upgrade_list()


func _on_objective_selected(index: int, category: String) -> void:
	var option: OptionButton = _objective_options.get(category, null)
	if option == null:
		return
	var data_key: String = str(option.get_item_metadata(index))
	_roster.objectives.set_objective(category, data_key)
	_select_objective_component(data_key)
	_refresh_after_mutation()


func _on_objective_view_pressed(category: String) -> void:
	var option: OptionButton = _objective_options.get(category, null)
	if option == null:
		return
	_select_objective_component(_selected_option_metadata(option))


func _on_map_selected(index: int) -> void:
	if _map_option == null:
		return
	var payload: Dictionary = _map_option.get_item_metadata(index) as Dictionary
	_roster.map = payload.duplicate(true)
	_refresh_after_mutation()


func _on_rules_item_selected(index: int) -> void:
	_set_rule_text(_rules_list.get_item_metadata(index) as RuleReferenceData)


func _on_component_rule_selected(index: int) -> void:
	_set_component_rule_metadata_text(_component_rules_list.get_item_metadata(index))


func _on_rules_search_changed(_new_text: String) -> void:
	_refresh_rules_reference()


func _on_rules_filter_selected(_index: int) -> void:
	_refresh_rules_reference()


func _on_add_component_pressed() -> void:
	var entry: Dictionary = _selected_catalog_entry()
	match str(entry.get("component_type", "")):
		FleetCatalog.COMPONENT_SHIP:
			_add_selected_ship(entry)
		FleetCatalog.COMPONENT_SQUADRON:
			_add_selected_squadron(entry)
		FleetCatalog.COMPONENT_UPGRADE:
			_add_selected_upgrade(entry)
		_:
			return
	_refresh_after_mutation()


func _add_selected_ship(entry: Dictionary) -> void:
	_ship_counter += 1
	FleetRosterDraftHelper.add_ship(_roster, str(entry.get("data_key", "")), "ship-%d" % _ship_counter)


func _add_selected_squadron(entry: Dictionary) -> void:
	_squadron_counter += 1
	FleetRosterDraftHelper.add_squadron(_roster, str(entry.get("data_key", "")),
			"squadron-%d" % _squadron_counter)


func _add_selected_upgrade(entry: Dictionary) -> void:
	_upgrade_counter += 1
	var added: bool = FleetRosterDraftHelper.add_upgrade(_roster,
			_selected_upgrade_ship_id(), str(entry.get("data_key", "")),
			"upgrade-%d" % _upgrade_counter)
	_status_label.text = "Upgrade added" if added else "No open matching slot"


func _on_remove_ship_pressed() -> void:
	_roster.remove_ship(_selected_item_metadata(_ship_list))
	_refresh_after_mutation()


func _on_remove_upgrade_pressed() -> void:
	var ship_entry: FleetShipEntry = _roster.get_ship(_selected_upgrade_ship_id())
	if ship_entry != null:
		ship_entry.remove_upgrade(_selected_item_metadata(_upgrade_list))
	_refresh_after_mutation()


func _on_remove_squadron_pressed() -> void:
	_roster.remove_squadron(_selected_item_metadata(_squadron_list))
	_refresh_after_mutation()


func _on_library_roster_loaded(roster: FleetRoster) -> void:
	if roster == null:
		return
	_roster = roster
	_rebuild_entry_counters()
	_refresh_all()
	_select_first_objective_component()
	if _library_panel != null:
		_library_panel.sync_current_roster_fields()


func _on_back_pressed() -> void:
	return_to_menu_requested.emit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _refresh_after_mutation() -> void:
	_refresh_roster_lists()
	_refresh_status()
	_refresh_validation()


func _select_objective_component(data_key: String) -> void:
	_deselect_inactive_component_lists(null)
	_select_roster_component(FleetCatalog.COMPONENT_OBJECTIVE, data_key)


func _select_first_objective_component() -> void:
	for category: String in FleetBuilderOptions.objective_categories():
		var data_key: String = _roster.objectives.get_objective(category)
		if not data_key.is_empty():
			_select_objective_component(data_key)
			return


func _rebuild_entry_counters() -> void:
	_ship_counter = _max_entry_suffix(_ship_entry_ids(), "ship-")
	_squadron_counter = _max_entry_suffix(_squadron_entry_ids(), "squadron-")
	_upgrade_counter = _max_entry_suffix(_upgrade_entry_ids(), "upgrade-")


func _ship_entry_ids() -> Array[String]:
	var entry_ids: Array[String] = []
	for ship_entry: FleetShipEntry in _roster.ships:
		entry_ids.append(ship_entry.entry_id)
	return entry_ids


func _squadron_entry_ids() -> Array[String]:
	var entry_ids: Array[String] = []
	for squadron_entry: FleetSquadronEntry in _roster.squadrons:
		entry_ids.append(squadron_entry.entry_id)
	return entry_ids


func _upgrade_entry_ids() -> Array[String]:
	var entry_ids: Array[String] = []
	for ship_entry: FleetShipEntry in _roster.ships:
		for assignment: FleetUpgradeAssignment in ship_entry.upgrades:
			entry_ids.append(assignment.entry_id)
	return entry_ids


func _max_entry_suffix(entry_ids: Array[String], prefix: String) -> int:
	var max_value: int = entry_ids.size()
	for entry_id: String in entry_ids:
		if not entry_id.begins_with(prefix):
			continue
		var suffix: String = entry_id.substr(prefix.length())
		if suffix.is_valid_int():
			max_value = max(max_value, int(suffix))
	return max_value


func _selected_catalog_entry() -> Dictionary:
	var selected: PackedInt32Array = _catalog_list.get_selected_items()
	if selected.is_empty():
		return {}
	return _catalog_list.get_item_metadata(selected[0]) as Dictionary


func _selected_catalog_type() -> String:
	var selected: String = _selected_option_metadata(_catalog_type_option)
	return FleetCatalog.COMPONENT_SHIP if selected.is_empty() else selected


func _selected_upgrade_type_filter() -> String:
	return _selected_option_metadata(_catalog_upgrade_type_option)


func _selected_upgrade_ship_id() -> String:
	var selected: int = _upgrade_ship_option.selected
	if selected < 0:
		return ""
	return str(_upgrade_ship_option.get_item_metadata(selected))


func _selected_item_metadata(list: ItemList) -> String:
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.is_empty():
		return ""
	return str(list.get_item_metadata(selected[0]))


func _selected_upgrade_assignment() -> FleetUpgradeAssignment:
	var ship_entry: FleetShipEntry = _roster.get_ship(_selected_upgrade_ship_id())
	if ship_entry == null:
		return null
	var assignment_id: String = _selected_item_metadata(_upgrade_list)
	for assignment: FleetUpgradeAssignment in ship_entry.upgrades:
		if assignment.entry_id == assignment_id:
			return assignment
	return null


func _select_component(entry: Dictionary) -> void:
	_selected_component_entry = entry
	_refresh_component_rules(entry)
	_refresh_card_art(entry)


func _activate_catalog_selection(index: int) -> void:
	_deselect_inactive_component_lists(_catalog_list)
	_select_component(_catalog_list.get_item_metadata(index) as Dictionary)


func _select_roster_component(component_type: String, data_key: String) -> void:
	if data_key.is_empty():
		_select_component({})
		return
	_select_component(_catalog_entry_for_component(component_type, data_key))


func _catalog_entry_for_component(component_type: String, data_key: String) -> Dictionary:
	var entries: Array[Dictionary] = _catalog.query_components({"component_types": [component_type]})
	for entry: Dictionary in entries:
		if str(entry.get("data_key", "")) == data_key:
			return entry
	return {}


func _deselect_inactive_component_lists(active_list: ItemList) -> void:
	_deselect_list_if_inactive(_catalog_list, active_list)
	_deselect_list_if_inactive(_ship_list, active_list)
	_deselect_list_if_inactive(_upgrade_list, active_list)
	_deselect_list_if_inactive(_squadron_list, active_list)


func _deselect_list_if_inactive(list: ItemList, active_list: ItemList) -> void:
	if list != null and list != active_list:
		list.deselect_all()


func _catalog_entry_label(entry: Dictionary) -> String:
	var points: int = int(entry.get("point_cost", -1))
	if points >= 0:
		return "%s (%d)" % [entry.get("display_name", ""), points]
	return str(entry.get("display_name", ""))


func _ship_label(entry: FleetShipEntry) -> String:
	var data: ShipData = AssetLoader.load_ship_data(entry.data_key)
	var name_text: String = data.ship_name if data != null else entry.data_key
	return "%s [%d upgrades]" % [name_text, entry.upgrades.size()]


func _squadron_label(entry: FleetSquadronEntry) -> String:
	var data: SquadronData = AssetLoader.load_squadron_data(entry.data_key)
	return data.squadron_name if data != null else entry.data_key


func _upgrade_label(assignment: FleetUpgradeAssignment) -> String:
	var data: UpgradeData = AssetLoader.load_upgrade_data(assignment.data_key)
	var name_text: String = data.upgrade_name if data != null else assignment.data_key
	return "%s - %s[%d]" % [name_text, assignment.slot, assignment.slot_index]


func _rule_label(rule: RuleReferenceData) -> String:
	if rule == null:
		return ""
	return "%s - %s" % [rule.display_name, rule.implementation_status]


func _set_rule_text(rule: RuleReferenceData) -> void:
	if rule == null:
		_rules_text.text = ""
		return
	_rules_text.text = "%s\n\n%s\n\n%s" % [rule.display_name, rule.summary, rule.rules_text]


func _set_component_rule_text(rule: RuleReferenceData) -> void:
	if rule == null:
		_component_rules_text.text = ""
		return
	_component_rules_text.text = "%s\n\n%s\n\n%s" % [
		rule.display_name,
		rule.summary,
		rule.rules_text,
	]


func _set_component_rule_metadata_text(metadata: Variant) -> void:
	if metadata is RuleReferenceData:
		_set_component_rule_text(metadata as RuleReferenceData)
	elif metadata is Dictionary:
		_component_rules_text.text = str((metadata as Dictionary).get("text", ""))
	else:
		_component_rules_text.text = ""


func _select_point_format() -> void:
	for index: int in range(_format_option.item_count):
		var format: Dictionary = _format_option.get_item_metadata(index) as Dictionary
		if int(format.get("limit", 0)) == int(_roster.point_format.get("limit", 0)):
			_format_option.select(index)
			return


func _select_option_metadata(option: OptionButton, metadata: String) -> void:
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index)) == metadata:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)


func _ensure_roster_map_allowed(maps: Array[Dictionary]) -> void:
	if _map_filename_allowed(_roster_map_filename(), maps):
		return
	_roster.map = FleetBuilderOptions.default_map_for_point_format(_roster.point_format)


func _map_filename_allowed(filename: String, maps: Array[Dictionary]) -> bool:
	for payload: Dictionary in maps:
		if str(payload.get("filename", "")) == filename:
			return true
	return false


func _select_map_filename(filename: String) -> void:
	for index: int in range(_map_option.item_count):
		var payload: Dictionary = _map_option.get_item_metadata(index) as Dictionary
		if str(payload.get("filename", "")) == filename:
			_map_option.select(index)
			return
	if _map_option.item_count > 0:
		_map_option.select(0)


func _roster_map_filename() -> String:
	return str(_roster.map.get("filename", ""))


func _add_option(option: OptionButton, label_text: String, metadata: Variant) -> void:
	option.add_item(label_text)
	option.set_item_metadata(option.item_count - 1, metadata)


func _add_disabled_option(option: OptionButton, label_text: String) -> void:
	option.add_item(label_text)
	var index: int = option.item_count - 1
	option.set_item_metadata(index, "")
	option.set_item_disabled(index, true)


func _selected_option_metadata(option: OptionButton) -> String:
	if option == null or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


func _refresh_upgrade_type_visibility() -> void:
	var is_upgrade_catalog: bool = _selected_catalog_type() == FleetCatalog.COMPONENT_UPGRADE
	_catalog_upgrade_type_option.visible = is_upgrade_catalog
	if not is_upgrade_catalog:
		_catalog_upgrade_type_option.select(0)


# TODO(refactor): extract selected-component reference/card-art presentation.
func _add_component_card_rule(entry: Dictionary) -> void:
	var payload: Dictionary = _component_card_rule_payload(entry)
	if payload.is_empty():
		return
	var index: int = _component_rules_list.add_item(str(payload.get("label", "Card Text")))
	_component_rules_list.set_item_metadata(index, payload)


func _component_card_rule_payload(entry: Dictionary) -> Dictionary:
	var resource: Variant = entry.get("resource", null)
	match str(entry.get("component_type", "")):
		FleetCatalog.COMPONENT_UPGRADE:
			return _upgrade_rule_payload(resource as UpgradeData)
		FleetCatalog.COMPONENT_SQUADRON:
			return _squadron_rule_payload(resource as SquadronData)
		FleetCatalog.COMPONENT_OBJECTIVE:
			return _objective_rule_payload(resource as ObjectiveData)
		_:
			return {}


func _upgrade_rule_payload(data: UpgradeData) -> Dictionary:
	if data == null or data.effect_text.is_empty():
		return {}
	var lines: Array[String] = [data.upgrade_name, "", data.effect_text]
	_append_text_section(lines, "Timing", data.timing_notes)
	_append_text_section(lines, "Errata", data.errata)
	_append_text_section(lines, "Clarifications", data.clarifications)
	_append_status_section(lines, data.rules_integration)
	return _card_rule_payload("Card Text", lines)


func _squadron_rule_payload(data: SquadronData) -> Dictionary:
	if data == null or data.ability_text.is_empty():
		return {}
	var lines: Array[String] = [data.squadron_name, "", data.ability_text]
	_append_status_section(lines, data.rules_integration)
	return _card_rule_payload("Card Text", lines)


func _objective_rule_payload(data: ObjectiveData) -> Dictionary:
	if data == null:
		return {}
	var lines: Array[String] = [data.objective_name]
	_append_named_text(lines, "Setup", data.setup_text)
	_append_named_text(lines, "Special Rule", data.special_rule_text)
	_append_named_text(lines, "End Of Round", data.end_of_round_text)
	_append_named_text(lines, "End Of Game", data.end_of_game_text)
	_append_text_section(lines, "Clarifications", data.clarifications)
	_append_status_section(lines, data.rules_integration)
	return _card_rule_payload("Card Text", lines)


func _card_rule_payload(label_text: String, lines: Array[String]) -> Dictionary:
	return {"label": label_text, "text": "\n".join(lines)}


func _append_named_text(lines: Array[String], label_text: String, text: String) -> void:
	if text.strip_edges().is_empty():
		return
	lines.append("")
	lines.append("%s: %s" % [label_text, text])


func _append_text_section(lines: Array[String], label_text: String, values: Array) -> void:
	if values.is_empty():
		return
	lines.append("")
	lines.append("%s:" % label_text)
	for raw_value: Variant in values:
		lines.append("- %s" % str(raw_value))


func _append_status_section(lines: Array[String], integration: Dictionary) -> void:
	var status: String = str(integration.get("status", ""))
	if status.is_empty():
		return
	_append_named_text(lines, "Implementation Status", _display_key(status))


func _card_texture_for_entry(entry: Dictionary) -> Texture2D:
	var resource: Variant = entry.get("resource", null)
	match str(entry.get("component_type", "")):
		FleetCatalog.COMPONENT_SHIP:
			return _ship_card_texture(resource as ShipData)
		FleetCatalog.COMPONENT_SQUADRON:
			return _squadron_card_texture(resource as SquadronData)
		FleetCatalog.COMPONENT_UPGRADE:
			return _upgrade_card_texture(resource as UpgradeData)
		FleetCatalog.COMPONENT_OBJECTIVE:
			return _objective_card_texture(resource as ObjectiveData)
		_:
			return null


func _ship_card_texture(data: ShipData) -> Texture2D:
	if data == null:
		return null
	return AssetLoader.load_texture(AssetLoader.SHIP_FOLDER, data.card_image)


func _squadron_card_texture(data: SquadronData) -> Texture2D:
	if data == null:
		return null
	return AssetLoader.load_texture(AssetLoader.SQUADRON_FOLDER, data.card_image)


func _upgrade_card_texture(data: UpgradeData) -> Texture2D:
	if data == null:
		return null
	return _load_nested_texture(AssetLoader.UPGRADE_FOLDER, data.card_image)


func _objective_card_texture(data: ObjectiveData) -> Texture2D:
	if data == null:
		return null
	return AssetLoader.load_texture(AssetLoader.OBJECTIVE_FOLDER, data.card_image)


func _load_nested_texture(subfolder: String, filename: String) -> Texture2D:
	if filename.is_empty():
		return null
	var relative_path: String = _find_asset_path(subfolder, filename)
	if relative_path.is_empty():
		return null
	return AssetLoader.load_texture("", relative_path)


func _find_asset_path(subfolder: String, filename: String) -> String:
	var dir: DirAccess = DirAccess.open(AssetLoader.BASE_PATH + subfolder)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		var found_path: String = _find_asset_entry_path(dir, subfolder, entry_name, filename)
		if not found_path.is_empty():
			dir.list_dir_end()
			return found_path
		entry_name = dir.get_next()
	dir.list_dir_end()
	return ""


func _find_asset_entry_path(dir: DirAccess, subfolder: String,
		entry_name: String, filename: String) -> String:
	if entry_name.begins_with("."):
		return ""
	var relative_path: String = subfolder + entry_name
	if dir.current_is_dir():
		return _find_asset_path(relative_path + "/", filename)
	if entry_name == filename:
		return relative_path
	return ""


func _set_card_art_anchors(rect: TextureRect) -> void:
	rect.anchor_left = 0.05
	rect.anchor_top = 0.05
	rect.anchor_right = 0.95
	rect.anchor_bottom = 0.95
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0


func _display_key(value: String) -> String:
	return value.capitalize().replace("_", " ")

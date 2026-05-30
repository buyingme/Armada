## Test: FleetBuilderScene
##
## Focused UI tests for the FB9 fleet-builder scene MVP.
extends GutTest


const MainMenuScript: GDScript = preload("res://src/scenes/main_menu/main_menu.gd")

var _scene: FleetBuilderScene = null


func before_each() -> void:
	_scene = FleetBuilderScene.new()
	add_child(_scene)


func after_each() -> void:
	_free_node(_scene)
	_scene = null


func test_ready_builds_required_sections_expected() -> void:
	assert_not_null(_find_button(_scene, "Add Component"), "Add Component button should exist")
	assert_null(_find_button(_scene, "Set Objective"), "Catalog should not include Set Objective")
	assert_not_null(_scene.find_child("Standard", true, false), "Reference should include Standard tab")
	assert_not_null(_scene.find_child("Card Art", true, false), "Reference should include Card Art tab")
	assert_true(_scene._catalog_list.item_count > 0, "Catalog should populate on ready")
	assert_true(_scene._rules_list.item_count > 0, "Rules reference should populate on ready")


func test_section_panels_use_standard_modal_style_expected() -> void:
	var panel: PanelContainer = _scene.find_child("CatalogPanel", true, false) as PanelContainer
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

	assert_not_null(style, "Fleet builder panels should use StyleBoxFlat styling")
	assert_eq(style.bg_color, UIStyleHelper.MODAL_BG,
		"Fleet builder panels should use the shared modal background")
	assert_eq(style.border_color, UIStyleHelper.MODAL_BORDER,
		"Fleet builder panels should use the shared modal border")


func test_catalog_search_filters_visible_entries_expected() -> void:
	_select_catalog_type(FleetCatalog.COMPONENT_SHIP)
	_scene._catalog_search_input.text = "cr90"

	_scene._on_catalog_search_changed("cr90")

	assert_true(_scene._catalog_list.item_count > 0, "CR90 search should return entries")
	assert_true(_scene._catalog_list.get_item_text(0).to_lower().contains("cr90"),
		"First filtered catalog entry should mention CR90")


func test_catalog_excludes_objectives_and_rules_expected() -> void:
	for index: int in range(_scene._catalog_type_option.item_count):
		var metadata: String = str(_scene._catalog_type_option.get_item_metadata(index))
		assert_ne(metadata, FleetCatalog.COMPONENT_OBJECTIVE,
			"Objectives should be edited only in the roster objective selectors")
		assert_ne(metadata, FleetCatalog.COMPONENT_RULE_REFERENCE,
			"Rules should live in the reference section instead of the catalog")


func test_header_options_use_core_provider_expected() -> void:
	assert_eq(_scene._format_option.item_count,
		FleetBuilderOptions.available_point_formats().size(),
		"Point-format option count should come from FleetBuilderOptions")
	assert_eq(_scene._faction_option.item_count,
		FleetBuilderOptions.available_factions(FleetCatalog.new()).size(),
		"Faction option count should come from FleetBuilderOptions")


func test_upgrade_type_filter_groups_and_filters_expected() -> void:
	_select_catalog_type(FleetCatalog.COMPONENT_UPGRADE)
	assert_true(_scene._catalog_upgrade_type_option.visible,
		"Upgrade type filter should show only for upgrade catalog")
	assert_true(_scene._catalog_upgrade_type_option.is_item_disabled(1),
		"First upgrade type group header should be disabled")

	_select_upgrade_type("TURBOLASERS")

	assert_true(_scene._catalog_list.item_count > 0, "Turbolasers filter should find entries")
	for index: int in range(_scene._catalog_list.item_count):
		var entry: Dictionary = _scene._catalog_list.get_item_metadata(index) as Dictionary
		assert_eq(str(entry.get("upgrade_type", "")), "TURBOLASERS",
			"Filtered upgrade catalog should only show Turbolasers")


func test_add_and_remove_roster_components_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "cr90_corvette_a")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_SQUADRON, "x_wing_squadron")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "general_dodonna")
	_scene._on_add_component_pressed()
	_select_objective_key(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")

	assert_eq(_scene.current_roster().ships.size(), 1, "One ship should be added")
	assert_eq(_scene.current_roster().squadrons.size(), 1, "One squadron should be added")
	assert_eq(_scene.current_roster().ships[0].upgrades.size(), 1,
		"One upgrade should be assigned to the selected ship")
	assert_eq(_scene.current_roster().objectives.assault_objective_key,
		"obj_ass_most_wanted", "Assault objective should be selected")

	_scene._ship_list.select(0)
	_scene._on_remove_ship_pressed()
	assert_true(_scene.current_roster().ships.is_empty(), "Selected ship should be removable")


func test_validation_panel_renders_core_errors_expected() -> void:
	assert_true(_scene._validation_list.item_count > 0,
		"Initial draft should render validation issues")
	assert_true(_scene._validation_list.get_item_text(0).contains("fleet."),
		"Validation list should render core rule ids")


func test_rules_reference_selection_updates_text_expected() -> void:
	_select_rule_key("squadron_keyword.bomber")

	assert_true(_scene._rules_text.text.contains("Bomber"),
		"Selecting Bomber should show rule text")
	assert_true(_scene._rules_text.text.contains("critical"),
		"Bomber rules text should include its damage reminder")


func test_rules_reference_search_filters_expected() -> void:
	_scene._rules_search_input.text = "bomber"

	_scene._on_rules_search_changed("bomber")

	assert_eq(_scene._rules_list.item_count, 1, "Bomber search should narrow rules list")
	assert_true(_scene._rules_text.text.contains("Bomber"),
		"Filtered rules reference should show the selected rule text")


func test_catalog_selection_updates_component_rule_and_card_art_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")

	assert_true(_scene._component_rules_text.text.contains("additional engineering point"),
		"Selecting Redemption should show its title card text")
	assert_not_null(_scene._card_art_rect.texture,
		"Selecting Redemption should load its card art")
	assert_almost_eq(_scene._card_art_rect.anchor_left, 0.05, 0.001,
		"Card art should leave a 5 percent left margin")
	assert_almost_eq(_scene._card_art_rect.anchor_right, 0.95, 0.001,
		"Card art should leave a 5 percent right margin")


func test_roster_upgrade_selection_updates_component_rule_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "nebulon_b_support_refit")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")
	_scene._on_add_component_pressed()

	_scene._upgrade_list.select(0)
	_scene._on_upgrade_selected(0)

	assert_true(_scene._component_rules_text.text.contains("Redemption"),
		"Roster upgrade selection should update selected component rules")
	assert_not_null(_scene._card_art_rect.texture,
		"Roster upgrade selection should update selected component card art")


func test_roster_squadron_selection_updates_component_rule_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SQUADRON, "x_wing_luke_skywalker")
	_scene._on_add_component_pressed()

	_scene._squadron_list.select(0)
	_scene._on_squadron_selected(0)

	assert_true(_scene._component_rules_text.text.contains("no shields"),
		"Roster squadron selection should show named squadron card text")
	assert_not_null(_scene._card_art_rect.texture,
		"Roster squadron selection should update selected component card art")


func test_roster_click_after_catalog_selection_clears_catalog_expected() -> void:
	_add_roster_ship_and_squadron()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")
	assert_true(_scene._component_rules_text.text.contains("Redemption"),
		"Arrange should leave Redemption active in the catalog")

	_scene._squadron_list.select(0)
	_scene._on_squadron_item_clicked(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")), "x_wing_squadron",
		"Clicking a roster squadron should make it the active component")
	assert_true(_scene._catalog_list.get_selected_items().is_empty(),
		"Catalog selection should clear when roster component is activated")
	assert_true(_scene._component_rules_text.text.contains("Bomber"),
		"Roster squadron click should refresh selected component rules")


func test_roster_ship_click_after_catalog_selection_updates_art_expected() -> void:
	_add_roster_ship_and_squadron()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")

	_scene._ship_list.select(0)
	_scene._on_ship_item_clicked(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")),
		"nebulon_b_support_refit", "Clicking a roster ship should make it active")
	assert_true(_scene._catalog_list.get_selected_items().is_empty(),
		"Catalog selection should clear when roster ship is activated")
	assert_not_null(_scene._card_art_rect.texture,
		"Roster ship click should refresh selected component card art")


func test_main_menu_includes_fleet_builder_button_expected() -> void:
	var menu: Control = MainMenuScript.new()
	add_child(menu)

	assert_not_null(_find_button(menu, "Fleet Builder"),
		"Main menu should expose the Fleet Builder entry")

	_free_node(menu)


func _select_catalog_key(component_type: String, data_key: String) -> void:
	_select_catalog_type(component_type)
	for index: int in range(_scene._catalog_list.item_count):
		var entry: Dictionary = _scene._catalog_list.get_item_metadata(index) as Dictionary
		if str(entry.get("data_key", "")) == data_key:
			_scene._catalog_list.select(index)
			_scene._on_catalog_item_selected(index)
			return
	fail_test("Catalog key not found: %s" % data_key)


func _select_catalog_type(component_type: String) -> void:
	for index: int in range(_scene._catalog_type_option.item_count):
		if str(_scene._catalog_type_option.get_item_metadata(index)) == component_type:
			_scene._catalog_type_option.select(index)
			_scene._on_catalog_filter_selected(index)
			return
	fail_test("Catalog type not found: %s" % component_type)


func _select_upgrade_type(upgrade_type: String) -> void:
	for index: int in range(_scene._catalog_upgrade_type_option.item_count):
		if str(_scene._catalog_upgrade_type_option.get_item_metadata(index)) == upgrade_type:
			_scene._catalog_upgrade_type_option.select(index)
			_scene._on_upgrade_type_filter_selected(index)
			return
	fail_test("Upgrade type not found: %s" % upgrade_type)


func _select_objective_key(category: String, data_key: String) -> void:
	var option: OptionButton = _scene._objective_options.get(category, null)
	assert_not_null(option, "Objective option should exist for %s" % category)
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index)) == data_key:
			option.select(index)
			_scene._on_objective_selected(index, category)
			return
	fail_test("Objective key not found: %s" % data_key)


func _select_rule_key(data_key: String) -> void:
	for index: int in range(_scene._rules_list.item_count):
		var rule: RuleReferenceData = _scene._rules_list.get_item_metadata(index) as RuleReferenceData
		if rule != null and rule.data_key == data_key:
			_scene._rules_list.select(index)
			_scene._on_rules_item_selected(index)
			return
	fail_test("Rule key not found: %s" % data_key)


func _add_roster_ship_and_squadron() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "nebulon_b_support_refit")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_SQUADRON, "x_wing_squadron")
	_scene._on_add_component_pressed()


func _find_button(root: Node, label_text: String) -> Button:
	for child: Node in root.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == label_text:
			return button
	return null


func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()

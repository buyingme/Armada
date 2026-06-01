## Setup Flow Scene
##
## Hot-seat setup-package confirmation screen. Loads two local rosters,
## resolves the initiative chooser, chooses first player/objective, then hands
## a validated package to GameManager for the setup-package board path.
class_name SetupFlowScene
extends Control


## Emitted when a validated setup package is confirmed.
signal setup_confirmed(package: FleetSetupPackage)

## Emitted when the user returns to the main menu.
signal setup_cancelled

const GAME_BOARD_PATH: String = "res://src/scenes/game_board/game_board.tscn"
const MAIN_MENU_PATH: String = "res://src/scenes/main_menu/main_menu.tscn"
const PLAYER_ZERO: int = 0
const PLAYER_ONE: int = 1
const UiFactory: GDScript = preload("res://src/scenes/setup_flow/setup_flow_ui_factory.gd")

## Test hook: when false, confirmation stores the package but does not change scene.
var transition_on_confirm: bool = true

var _library_manager: FleetLibraryManager = null
var _builder: FleetSetupPackageBuilder = null
var _tie_breaker: Callable = Callable()
var _initiative_chooser: int = PLAYER_ZERO
var _resolved_first_player: int = PLAYER_ZERO
var _fleet_options: Array[Dictionary] = []
var _current_package: FleetSetupPackage = null
var _player_zero_option: OptionButton
var _player_one_option: OptionButton
var _first_player_option: OptionButton
var _objective_option: OptionButton
var _summary_label: Label
var _hash_label: Label
var _status_label: Label
var _validation_list: ItemList
var _confirm_button: Button


## Injects dependencies for tests or alternate setup hosts.
func initialize(library_manager: FleetLibraryManager,
		builder: FleetSetupPackageBuilder = null,
		tie_breaker: Callable = Callable()) -> void:
	_library_manager = library_manager
	_builder = builder if builder != null else FleetSetupPackageBuilder.new()
	_tie_breaker = tie_breaker


## Returns the currently validated package, or null when selection is invalid.
func current_package() -> FleetSetupPackage:
	return _current_package


func _ready() -> void:
	if _library_manager == null:
		_library_manager = FleetLibraryManager.new()
	if _builder == null:
		_builder = FleetSetupPackageBuilder.new()
	_build_ui()
	_refresh_fleets()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	add_child(UiFactory.build_background())
	var panel: PanelContainer = UiFactory.build_panel()
	add_child(panel)
	var content: VBoxContainer = _build_content()
	(panel.get_child(0) as MarginContainer).add_child(content)


func _build_content() -> VBoxContainer:
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.add_child(UIStyleHelper.create_title_label("Fleet Setup", UIStyleHelper.GOLD_TITLE))
	content.add_child(HSeparator.new())
	content.add_child(_build_roster_rows())
	content.add_child(_build_choice_rows())
	content.add_child(_build_summary_section())
	content.add_child(_build_buttons())
	return content


func _build_roster_rows() -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	_player_zero_option = UiFactory.build_option_row(rows, "Player 1 Fleet")
	_player_one_option = UiFactory.build_option_row(rows, "Player 2 Fleet")
	_player_zero_option.item_selected.connect(_on_fleet_selected)
	_player_one_option.item_selected.connect(_on_fleet_selected)
	return rows


func _build_choice_rows() -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	_first_player_option = UiFactory.build_option_row(rows, "First Player")
	_first_player_option.add_item("Player 1")
	_first_player_option.set_item_metadata(0, PLAYER_ZERO)
	_first_player_option.add_item("Player 2")
	_first_player_option.set_item_metadata(1, PLAYER_ONE)
	_first_player_option.disabled = true
	_first_player_option.item_selected.connect(_on_first_player_selected)
	_objective_option = UiFactory.build_option_row(rows, "Objective")
	_objective_option.item_selected.connect(_on_objective_selected)
	return rows


func _build_summary_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = "PackageSummary"
	section.add_theme_constant_override("separation", 6)
	_summary_label = UIStyleHelper.create_section_label("No package", UIStyleHelper.FONT_BODY)
	_hash_label = UIStyleHelper.create_section_label("", UIStyleHelper.FONT_HINT,
			UIStyleHelper.DIMMED_HINT)
	_status_label = UIStyleHelper.create_section_label("", UIStyleHelper.FONT_SUBTITLE)
	_validation_list = ItemList.new()
	_validation_list.custom_minimum_size = Vector2(480, 96)
	section.add_child(_summary_label)
	section.add_child(_hash_label)
	section.add_child(_status_label)
	section.add_child(_validation_list)
	return section


func _build_buttons() -> HBoxContainer:
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_confirm_button = UiFactory.build_button("Confirm")
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)
	var cancel_button: Button = UiFactory.build_button("Cancel")
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)
	return buttons


func _refresh_fleets() -> void:
	_fleet_options = _library_manager.list_fleets()
	_populate_fleet_option(_player_zero_option, 0)
	_populate_fleet_option(_player_one_option, mini(1, _fleet_options.size() - 1))
	_resolve_first_player()
	_refresh_objectives()


func _populate_fleet_option(option: OptionButton, selected_index: int) -> void:
	option.clear()
	if _fleet_options.is_empty():
		option.add_item("No saved fleets")
		option.set_item_metadata(0, "")
		option.disabled = true
		return
	option.disabled = false
	for summary: Dictionary in _fleet_options:
		option.add_item(UiFactory.fleet_label(summary))
		option.set_item_metadata(option.get_item_count() - 1, str(summary.get("fleet_id", "")))
	option.select(clampi(selected_index, 0, option.get_item_count() - 1))


func _refresh_objectives() -> void:
	_objective_option.clear()
	var owner_roster: FleetRoster = _load_objective_owner_roster()
	if owner_roster == null:
		_set_empty_objective_option()
		_rebuild_package()
		return
	_add_objective_options(owner_roster)
	_rebuild_package()


func _set_empty_objective_option() -> void:
	_objective_option.add_item("No objectives")
	_objective_option.set_item_metadata(0, "")
	_objective_option.disabled = true


func _add_objective_options(roster: FleetRoster) -> void:
	_objective_option.disabled = false
	for category: String in FleetObjectiveSelection.categories():
		var key: String = roster.objectives.get_objective(category)
		if key.strip_edges().is_empty():
			continue
		_objective_option.add_item(UiFactory.objective_label(category, key))
		_objective_option.set_item_metadata(_objective_option.get_item_count() - 1, key)
	if _objective_option.get_item_count() == 0:
		_set_empty_objective_option()


func _load_objective_owner_roster() -> FleetRoster:
	var owner_player: int = UiFactory.other_player(_resolved_first_player)
	var fleet_ids: Array[String] = _selected_fleet_ids()
	if owner_player < 0 or fleet_ids[owner_player].is_empty():
		return null
	var result: Dictionary = _library_manager.load_roster(fleet_ids[owner_player])
	if not bool(result.get("ok", false)):
		return null
	return result.get("roster") as FleetRoster


func _rebuild_package() -> void:
	_current_package = null
	_validation_list.clear()
	var fleet_ids: Array[String] = _selected_fleet_ids()
	var objective_key: String = _selected_objective_key()
	if not UiFactory.selection_complete(fleet_ids, objective_key):
		_show_invalid_state("Select two fleets and an objective.")
		return
	var result: Dictionary = _builder.build_from_library(_library_manager, fleet_ids,
			_resolved_first_player, objective_key)
	_show_build_result(result)


func _resolve_first_player() -> void:
	var rosters: Array[FleetRoster] = _selected_rosters()
	if rosters.size() != Constants.PLAYER_COUNT:
		_initiative_chooser = PLAYER_ZERO
		_resolved_first_player = PLAYER_ZERO
		_first_player_option.select(_resolved_first_player)
		_first_player_option.disabled = true
		return
	_initiative_chooser = FleetSetupPackageBuilder.determine_first_player_chooser(
			rosters[0], rosters[1], _tie_breaker)
	_resolved_first_player = _initiative_chooser
	_first_player_option.select(_resolved_first_player)
	_first_player_option.disabled = false


func _selected_rosters() -> Array[FleetRoster]:
	var rosters: Array[FleetRoster] = []
	for fleet_id: String in _selected_fleet_ids():
		var result: Dictionary = _library_manager.load_roster(fleet_id)
		if not bool(result.get("ok", false)):
			return []
		rosters.append(result.get("roster") as FleetRoster)
	return rosters


func _show_build_result(result: Dictionary) -> void:
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult
	if not bool(result.get("ok", false)):
		_show_validation(validation)
		return
	_current_package = result.get("package") as FleetSetupPackage
	_confirm_button.disabled = false
	_summary_label.text = UiFactory.package_summary(_current_package)
	_hash_label.text = "Hash: %s" % _current_package.canonical_hash()
	_status_label.text = "Package ready"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))


func _show_validation(validation: SetupValidationResult) -> void:
	_show_invalid_state("Package rejected")
	if validation == null:
		return
	for issue: Dictionary in validation.errors:
		_validation_list.add_item(str(issue.get("message", "Setup error")))
	for issue: Dictionary in validation.warnings:
		_validation_list.add_item(str(issue.get("message", "Setup warning")))


func _show_invalid_state(message: String) -> void:
	_confirm_button.disabled = true
	_summary_label.text = "No package"
	_hash_label.text = ""
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", UIStyleHelper.ERROR_RED)


func _selected_fleet_ids() -> Array[String]:
	return UiFactory.selected_fleet_ids(_player_zero_option, _player_one_option)


func _selected_objective_key() -> String:
	return _selected_option_metadata(_objective_option)


func _selected_option_metadata(option: OptionButton) -> String:
	return UiFactory.selected_option_metadata(option)


func _on_fleet_selected(_index: int) -> void:
	_resolve_first_player()
	_refresh_objectives()


func _on_objective_selected(_index: int) -> void:
	_rebuild_package()


func _on_first_player_selected(index: int) -> void:
	_resolved_first_player = int(_first_player_option.get_item_metadata(index))
	_refresh_objectives()


func _on_confirm_pressed() -> void:
	if _current_package == null:
		return
	GameManager.set_next_setup_package(_current_package)
	setup_confirmed.emit(_current_package)
	if transition_on_confirm:
		get_tree().change_scene_to_file(GAME_BOARD_PATH)


func _on_cancel_pressed() -> void:
	setup_cancelled.emit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

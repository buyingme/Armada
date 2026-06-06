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
const OBJECTIVE_CHOICE_PANEL_SCRIPT: GDScript = preload(
		"res://src/ui/objective_choice_panel.gd")
const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")

## Test hook: when false, confirmation stores the package but does not change scene.
var transition_on_confirm: bool = true

var _library_manager: FleetLibraryManager = null
var _builder: FleetSetupPackageBuilder = null
var _tie_breaker: Callable = Callable()
var _initiative_chooser: int = PLAYER_ZERO
var _resolved_first_player: int = PLAYER_ZERO
var _match_type_id: String = "standard_400"
var _package_draft: FleetSetupPackage = null
var _fleet_options: Array[Dictionary] = []
var _current_package: FleetSetupPackage = null
var _confirmed_objective_key: String = ""
var _is_network_setup: bool = false
var _initiative_confirmed: bool = false
var _initiative_random: bool = false
var _network_transitioned: bool = false
var _roster_rows: VBoxContainer
var _player_zero_option: OptionButton
var _player_one_option: OptionButton
var _first_player_option: OptionButton
var _objective_panel: Control
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


## Returns the setup-package draft for the selected New Game match type.
func current_package_draft() -> FleetSetupPackage:
	return _package_draft


func _ready() -> void:
	if _library_manager == null:
		_library_manager = FleetLibraryManager.new()
	if _builder == null:
		_builder = FleetSetupPackageBuilder.new()
	_initialize_match_type()
	_build_ui()
	if _is_network_setup:
		_connect_network_setup_signals()
		_refresh_network_setup()
	else:
		_refresh_fleets()


func _initialize_match_type() -> void:
	var config: Dictionary = NetworkManager.get_pending_game_config()
	var package_data: Dictionary = config.get("setup_package", {}) as Dictionary
	if not package_data.is_empty():
		_package_draft = FleetSetupPackage.deserialize(package_data)
		_match_type_id = str(_package_draft.setup_state.get(
				"match_type", SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400))
		_is_network_setup = true
		return
	_match_type_id = GameManager.consume_next_setup_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)
	_package_draft = SETUP_MATCH_OPTIONS_SCRIPT.create_setup_package_draft(_match_type_id)


func _connect_network_setup_signals() -> void:
	if not LobbyManager.lobby_updated.is_connected(_on_network_lobby_updated):
		LobbyManager.lobby_updated.connect(_on_network_lobby_updated)


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
	content.add_child(UIStyleHelper.create_title_label(
			"Fleet Setup - %s" % SETUP_MATCH_OPTIONS_SCRIPT.label_for_match_type(_match_type_id),
			UIStyleHelper.GOLD_TITLE))
	content.add_child(HSeparator.new())
	_roster_rows = _build_roster_rows()
	_roster_rows.visible = not _is_network_setup
	content.add_child(_roster_rows)
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
	_objective_panel = OBJECTIVE_CHOICE_PANEL_SCRIPT.new()
	_objective_panel.objective_confirmed.connect(_on_objective_confirmed)
	_objective_panel.confirmation_acknowledged.connect(_on_objective_acknowledged)
	rows.add_child(_objective_panel)
	return rows


func _on_network_lobby_updated(_data: Dictionary) -> void:
	_refresh_network_setup()


func _refresh_network_setup() -> void:
	var draft: FleetSetupPackage = _network_setup_draft()
	if draft == null:
		_show_network_wait_state("Waiting for setup data from host.")
		return
	_package_draft = draft
	_current_package = draft
	var state: Dictionary = draft.setup_state
	var phase: String = str(state.get(LobbyManager.SETUP_KEY_PHASE, ""))
	_update_network_first_player_option(state)
	_summary_label.text = _network_initiative_summary(draft, state)
	_hash_label.text = ""
	_validation_list.clear()
	if phase == LobbyManager.SETUP_PHASE_INITIATIVE_CONFIRMATION:
		_configure_network_initiative(state)
	elif phase == LobbyManager.SETUP_PHASE_OBJECTIVE_SELECTION \
			or phase == LobbyManager.SETUP_PHASE_OBJECTIVE_CONFIRMATION:
		_configure_network_objective(state)
	elif phase == LobbyManager.SETUP_PHASE_READY_TO_START:
		_configure_network_objective(state)
		_transition_network_setup_to_board(draft)
	else:
		_show_network_wait_state("Waiting for both fleets before initiative.")


func _network_setup_draft() -> FleetSetupPackage:
	if LobbyManager.current_lobby != null and not LobbyManager.current_lobby.setup_draft.is_empty():
		return FleetSetupPackage.deserialize(LobbyManager.current_lobby.setup_draft)
	var config: Dictionary = NetworkManager.get_pending_game_config()
	var package_data: Dictionary = config.get("setup_package", {}) as Dictionary
	if package_data.is_empty():
		return null
	return FleetSetupPackage.deserialize(package_data)


func _show_network_wait_state(message: String) -> void:
	_objective_panel.visible = false
	_confirm_button.text = "Confirm Initiative"
	_confirm_button.disabled = true
	_summary_label.text = message
	_hash_label.text = ""
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", UIStyleHelper.DIMMED_HINT)


func _update_network_first_player_option(state: Dictionary) -> void:
	var first_player: int = int(state.get("resolved_first_player", PLAYER_ZERO))
	if first_player >= PLAYER_ZERO and first_player <= PLAYER_ONE:
		_first_player_option.select(first_player)
	var local_player: int = LobbyManager.local_setup_player_index()
	var chooser: int = int(state.get(LobbyManager.SETUP_KEY_INITIATIVE_CHOOSER, -1))
	var can_choose: bool = local_player == chooser \
			and not bool(state.get(LobbyManager.SETUP_KEY_INITIATIVE_TIED, false)) \
			and str(state.get(LobbyManager.SETUP_KEY_PHASE, "")) \
					== LobbyManager.SETUP_PHASE_INITIATIVE_CONFIRMATION
	_first_player_option.disabled = not can_choose


func _configure_network_initiative(state: Dictionary) -> void:
	_objective_panel.visible = false
	_confirm_button.visible = true
	_confirm_button.text = "Confirm Initiative"
	var confirmations: Dictionary = state.get(
			LobbyManager.SETUP_KEY_INITIATIVE_CONFIRMATIONS, {}) as Dictionary
	_confirm_button.disabled = bool(confirmations.get(
			str(LobbyManager.local_setup_player_index()), false))
	_status_label.text = "Confirm initiative before objective selection."
	_status_label.add_theme_color_override("font_color", UIStyleHelper.BODY_TEXT)


func _configure_network_objective(state: Dictionary) -> void:
	_confirm_button.visible = false
	var local_player: int = LobbyManager.local_setup_player_index()
	var first_player: int = int(state.get("resolved_first_player", -1))
	var confirmations: Dictionary = state.get(
			LobbyManager.SETUP_KEY_OBJECTIVE_CONFIRMATIONS, {}) as Dictionary
	var phase: String = str(state.get(LobbyManager.SETUP_KEY_PHASE, ""))
	_objective_panel.visible = true
	_objective_panel.configure({
		"heading": "Objective Choice",
		"subtitle": "First Player chooses one of the second player's objectives.",
		"objectives": state.get(LobbyManager.SETUP_KEY_OBJECTIVE_CANDIDATES, []),
		"confirmed_key": str(state.get(LobbyManager.SETUP_KEY_SELECTED_OBJECTIVE_KEY, "")),
		"selection_locked": bool(state.get(LobbyManager.SETUP_KEY_OBJECTIVE_CHOICE_LOCKED, false)),
		"can_select": phase == LobbyManager.SETUP_PHASE_OBJECTIVE_SELECTION \
				and local_player == first_player,
		"can_confirm": phase == LobbyManager.SETUP_PHASE_OBJECTIVE_CONFIRMATION \
				and not bool(confirmations.get(str(local_player), false)),
		"status_text": _network_objective_status_text(state),
		"selection_button_text": "Confirm Objective",
		"locked_button_text": "Confirmed" \
				if bool(confirmations.get(str(local_player), false)) else "Confirm",
	})
	_status_label.text = _network_objective_status_text(state)
	_status_label.add_theme_color_override("font_color", UIStyleHelper.BODY_TEXT)


func _network_objective_status_text(state: Dictionary) -> String:
	match str(state.get(LobbyManager.SETUP_KEY_PHASE, "")):
		LobbyManager.SETUP_PHASE_OBJECTIVE_SELECTION:
			return "First Player chooses one of the second player's objectives."
		LobbyManager.SETUP_PHASE_OBJECTIVE_CONFIRMATION:
			return "Review the locked objective and confirm it."
		LobbyManager.SETUP_PHASE_READY_TO_START:
			return "Objective confirmed. Loading setup board."
		_:
			return "Waiting for objective selection."


func _network_initiative_summary(draft: FleetSetupPackage, state: Dictionary) -> String:
	var rosters: Array[FleetRoster] = _network_rosters(draft)
	if rosters.size() != Constants.PLAYER_COUNT:
		return "Waiting for fleet setup."
	var points: Array = state.get(LobbyManager.SETUP_KEY_PLAYER_POINTS, []) as Array
	if points.size() != Constants.PLAYER_COUNT:
		points = [_fleet_points(rosters[0]), _fleet_points(rosters[1])]
	var first_player: int = int(state.get("resolved_first_player", PLAYER_ZERO))
	var method_text: String = "random selection" \
			if bool(state.get(LobbyManager.SETUP_KEY_INITIATIVE_RANDOM, false)) \
			else "%s chose" % _network_player_name(
					int(state.get(LobbyManager.SETUP_KEY_INITIATIVE_CHOOSER, PLAYER_ZERO)))
	return "%s: %s (%d)\n%s: %s (%d)\nFirst Player: %s by %s" % [
			_network_player_name(PLAYER_ZERO), rosters[0].name, int(points[0]),
			_network_player_name(PLAYER_ONE), rosters[1].name, int(points[1]),
			_network_player_name(first_player), method_text]


func _network_rosters(draft: FleetSetupPackage) -> Array[FleetRoster]:
	var rosters: Array[FleetRoster] = []
	rosters.resize(Constants.PLAYER_COUNT)
	for entry: Dictionary in draft.players:
		var player_index: int = int(entry.get("player_index", -1))
		if player_index < PLAYER_ZERO or player_index > PLAYER_ONE:
			continue
		rosters[player_index] = FleetRoster.deserialize(entry.get("roster", {}) as Dictionary)
	if rosters[0] == null or rosters[1] == null:
		return []
	return rosters


func _network_player_name(player_index: int) -> String:
	if LobbyManager.current_lobby == null:
		return "Player %d" % (player_index + 1)
	for player: Dictionary in LobbyManager.current_lobby.players:
		if int(player.get("player_index", -1)) == player_index:
			return str(player.get("display_name", "Player %d" % (player_index + 1)))
	return "Player %d" % (player_index + 1)


func _transition_network_setup_to_board(draft: FleetSetupPackage) -> void:
	if _network_transitioned:
		return
	_network_transitioned = true
	GameManager.set_next_setup_package(draft)
	setup_confirmed.emit(draft)
	if transition_on_confirm:
		get_tree().change_scene_to_file(GAME_BOARD_PATH)


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
	var selected_ids: Array[String] = _selected_fleet_ids()
	_fleet_options = _matching_fleet_options()
	_populate_fleet_option(_player_zero_option, selected_ids[0], 0)
	_populate_fleet_option(_player_one_option, selected_ids[1], mini(1, _fleet_options.size() - 1))
	_sync_package_draft_state()
	_resolve_first_player()
	_refresh_objectives()


func _matching_fleet_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for summary: Dictionary in _library_manager.list_fleets():
		var point_format: Dictionary = summary.get("point_format", {}) as Dictionary
		if FleetBuilderOptions.point_formats_match(point_format, _package_draft.point_format):
			options.append(summary)
	return options


func _populate_fleet_option(option: OptionButton,
		selected_fleet_id: String, selected_index: int) -> void:
	option.clear()
	if _fleet_options.is_empty():
		option.add_item("No saved fleets for %s" %
				SETUP_MATCH_OPTIONS_SCRIPT.label_for_match_type(_match_type_id))
		option.set_item_metadata(0, "")
		option.disabled = true
		return
	option.disabled = false
	for summary: Dictionary in _fleet_options:
		option.add_item(UiFactory.fleet_label(summary))
		option.set_item_metadata(option.get_item_count() - 1, str(summary.get("fleet_id", "")))
	for option_index: int in range(option.get_item_count()):
		if str(option.get_item_metadata(option_index)) == selected_fleet_id:
			option.select(option_index)
			return
	option.select(clampi(selected_index, 0, option.get_item_count() - 1))


func _refresh_objectives() -> void:
	var rosters: Array[FleetRoster] = _selected_rosters()
	if not _initiative_confirmed:
		_show_initiative_stage(rosters)
		return
	var owner_roster: FleetRoster = _load_objective_owner_roster()
	if owner_roster == null:
		_confirmed_objective_key = ""
		_configure_objective_panel([], false, "Select two fleets to preview objectives.")
		_rebuild_package()
		return
	var objectives: Array[Dictionary] = _objective_entries(owner_roster)
	if not _objective_key_present(objectives, _confirmed_objective_key):
		_confirmed_objective_key = ""
	_configure_objective_panel(objectives, false,
			"Choose one of the second player's objectives and confirm it.")
	_rebuild_package()


func _objective_entries(roster: FleetRoster) -> Array[Dictionary]:
	var objectives: Array[Dictionary] = []
	for category: String in FleetObjectiveSelection.categories():
		var key: String = roster.objectives.get_objective(category)
		if key.strip_edges().is_empty():
			continue
		var data: ObjectiveData = AssetLoader.load_objective_data(key)
		objectives.append({
			"data_key": key,
			"category": category,
			"objective_name": key if data == null else data.objective_name,
		})
	return objectives


func _configure_objective_panel(objectives: Array[Dictionary],
		selection_locked: bool, status_text: String) -> void:
	if _objective_panel == null:
		return
	_objective_panel.visible = true
	var subtitle: String = "Second Player presents three objectives. First Player chooses one."
	_objective_panel.configure({
		"heading": "Objective Choice",
		"subtitle": subtitle,
		"objectives": objectives,
		"confirmed_key": _confirmed_objective_key,
		"selection_locked": selection_locked,
		"can_select": not selection_locked and not objectives.is_empty(),
		"can_confirm": false,
		"status_text": status_text,
		"selection_button_text": "Confirm Objective",
	})


func _objective_key_present(objectives: Array[Dictionary], objective_key: String) -> bool:
	for objective: Dictionary in objectives:
		if str(objective.get("data_key", "")) == objective_key:
			return true
	return false


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
	_confirm_button.text = "Start Setup"
	var fleet_ids: Array[String] = _selected_fleet_ids()
	var objective_key: String = _selected_objective_key()
	if not UiFactory.selection_complete(fleet_ids, objective_key):
		_show_invalid_state("Select two fleets and an objective.")
		return
	var result: Dictionary = _builder.build_from_library(_library_manager, fleet_ids,
			_resolved_first_player, objective_key) if _package_draft == null \
			else _builder.build_from_draft(_library_manager, fleet_ids,
					_resolved_first_player, objective_key, _package_draft)
	_show_build_result(result)


func _resolve_first_player() -> void:
	var rosters: Array[FleetRoster] = _selected_rosters()
	if rosters.size() != Constants.PLAYER_COUNT:
		_initiative_chooser = PLAYER_ZERO
		_resolved_first_player = PLAYER_ZERO
		_initiative_random = false
		_first_player_option.select(_resolved_first_player)
		_first_player_option.disabled = true
		return
	var player_zero_points: int = _fleet_points(rosters[0])
	var player_one_points: int = _fleet_points(rosters[1])
	_initiative_random = player_zero_points == player_one_points
	if _initiative_random:
		_initiative_chooser = -1
		_resolved_first_player = _random_first_player()
		_first_player_option.select(_resolved_first_player)
		_first_player_option.disabled = true
		return
	_initiative_chooser = PLAYER_ZERO if player_zero_points < player_one_points else PLAYER_ONE
	_resolved_first_player = _initiative_chooser
	_first_player_option.select(_resolved_first_player)
	_first_player_option.disabled = false


func _show_initiative_stage(rosters: Array[FleetRoster]) -> void:
	_current_package = null
	_validation_list.clear()
	_objective_panel.visible = false
	_confirm_button.text = "Confirm Initiative"
	_confirm_button.disabled = rosters.size() != Constants.PLAYER_COUNT
	_summary_label.text = _initiative_summary_text(rosters)
	_hash_label.text = ""
	_status_label.text = "Confirm initiative before choosing objectives."
	_status_label.add_theme_color_override("font_color", UIStyleHelper.BODY_TEXT)
	_sync_package_draft_state()


func _initiative_summary_text(rosters: Array[FleetRoster]) -> String:
	if rosters.size() != Constants.PLAYER_COUNT:
		return "Select two fleets before initiative."
	var points: Array[int] = [_fleet_points(rosters[0]), _fleet_points(rosters[1])]
	var chooser_text: String = "random selection" if _initiative_random \
			else "Player %d chooses" % (_initiative_chooser + 1)
	return "Player 1: %s (%d)\nPlayer 2: %s (%d)\nFirst Player: Player %d by %s" % [
			rosters[0].name, points[0], rosters[1].name, points[1],
			_resolved_first_player + 1, chooser_text]


func _fleet_points(roster: FleetRoster) -> int:
	return int(FleetRosterSummary.calculate(roster).get(
			FleetRosterSummary.KEY_TOTAL_POINTS, 0))


func _random_first_player() -> int:
	if _tie_breaker.is_valid():
		return clampi(int(_tie_breaker.call()), PLAYER_ZERO, PLAYER_ONE)
	return randi_range(PLAYER_ZERO, PLAYER_ONE)


func _selected_rosters() -> Array[FleetRoster]:
	var rosters: Array[FleetRoster] = []
	for fleet_id: String in _selected_fleet_ids():
		var result: Dictionary = _library_manager.load_roster(fleet_id)
		if not bool(result.get("ok", false)):
			return []
		rosters.append(result.get("roster") as FleetRoster)
	return rosters


func _show_build_result(result: Dictionary) -> void:
	_sync_package_draft_state()
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult
	if not bool(result.get("ok", false)):
		_show_validation(validation)
		return
	_current_package = result.get("package") as FleetSetupPackage
	_package_draft.players = _current_package.players.duplicate(true)
	_package_draft.point_format = _current_package.point_format.duplicate(true)
	_package_draft.map = _current_package.map.duplicate(true)
	_package_draft.first_player = _current_package.first_player
	_package_draft.selected_objective = _current_package.selected_objective.duplicate(true)
	_set_draft_validation_status(true, validation, _current_package.canonical_hash())
	_confirm_button.disabled = false
	_confirm_button.text = "Start Setup"
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
	_set_draft_validation_status(false, validation)


func _show_invalid_state(message: String) -> void:
	_sync_package_draft_state()
	_confirm_button.disabled = true
	_summary_label.text = "No package"
	_hash_label.text = ""
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", UIStyleHelper.ERROR_RED)
	_set_draft_validation_status(false, null)


func _selected_fleet_ids() -> Array[String]:
	return UiFactory.selected_fleet_ids(_player_zero_option, _player_one_option)


func _selected_objective_key() -> String:
	return _confirmed_objective_key


func _on_fleet_selected(_index: int) -> void:
	_confirmed_objective_key = ""
	_initiative_confirmed = false
	_sync_package_draft_state()
	_resolve_first_player()
	_refresh_objectives()



func _on_objective_confirmed(objective_key: String) -> void:
	if _is_network_setup:
		LobbyManager.confirm_setup_objective(objective_key)
		return
	_confirmed_objective_key = objective_key
	var owner_roster: FleetRoster = _load_objective_owner_roster()
	var objectives: Array[Dictionary] = [] if owner_roster == null else _objective_entries(owner_roster)
	_configure_objective_panel(objectives, true,
			"Objective locked. Review the chosen card, then confirm the setup package.")
	_rebuild_package()


func _on_objective_acknowledged() -> void:
	if _is_network_setup:
		LobbyManager.confirm_setup_objective()


func _on_first_player_selected(index: int) -> void:
	if _is_network_setup:
		LobbyManager.submit_first_player_choice(
				int(_first_player_option.get_item_metadata(index)))
		return
	_resolved_first_player = int(_first_player_option.get_item_metadata(index))
	_confirmed_objective_key = ""
	_initiative_confirmed = false
	_sync_package_draft_state()
	_refresh_objectives()


func _sync_package_draft_state() -> void:
	if _package_draft == null:
		return
	_package_draft.setup_state["selected_fleet_ids"] = _selected_fleet_ids()
	_package_draft.setup_state["selected_objective_key"] = _selected_objective_key()
	_package_draft.setup_state["objective_choice_locked"] = not _confirmed_objective_key.is_empty()
	_package_draft.setup_state["resolved_first_player"] = _resolved_first_player
	_package_draft.setup_state["initiative_confirmed"] = _initiative_confirmed
	_package_draft.setup_state["initiative_random_selection"] = _initiative_random
	_package_draft.players = _draft_player_entries(_selected_fleet_ids())


func _draft_player_entries(fleet_ids: Array[String]) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for player_index: int in range(fleet_ids.size()):
		var fleet_id: String = fleet_ids[player_index]
		if fleet_id.is_empty():
			continue
		var result: Dictionary = _library_manager.load_roster(fleet_id)
		if not bool(result.get("ok", false)):
			continue
		var roster: FleetRoster = result.get("roster") as FleetRoster
		players.append({
			"player_index": player_index,
			"faction": roster.faction,
			"roster": roster.serialize(),
		})
	return players


func _set_draft_validation_status(ok: bool, validation: SetupValidationResult,
		package_hash: String = "") -> void:
	if _package_draft == null:
		return
	_package_draft.setup_state["validation_status"] = {
		"ok": ok,
		"error_count": 0 if validation == null else validation.errors.size(),
		"warning_count": 0 if validation == null else validation.warnings.size(),
		"package_hash": package_hash,
	}


func _on_confirm_pressed() -> void:
	if _is_network_setup:
		LobbyManager.confirm_initiative_screen()
		return
	if not _initiative_confirmed:
		_initiative_confirmed = true
		_first_player_option.disabled = true
		_refresh_objectives()
		return
	if _current_package == null:
		return
	GameManager.set_next_setup_package(_current_package)
	setup_confirmed.emit(_current_package)
	if transition_on_confirm:
		get_tree().change_scene_to_file(GAME_BOARD_PATH)


func _on_cancel_pressed() -> void:
	setup_cancelled.emit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

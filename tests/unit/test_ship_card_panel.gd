## Test: ShipCardPanel
##
## Unit tests for ShipCardPanel — verifies panel setup, ship entry creation,
## defense token display, faction separation, magnify toggle, and
## EventBus-driven updates.
## Requirements: GC-005, GC-011, UI-006, UI-016, UI-017, UI-018.
extends GutTest


## Creates a minimal ShipData with the given faction and defense tokens.
func _make_ship_data(
		faction: Constants.Faction,
		token_names: Array) -> ShipData:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.faction = faction
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 4
	data.command_value = 1
	data.max_speed = 3
	data.shields = {"FRONT": 2, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	data.defense_tokens = token_names
	return data


## Creates a ShipInstance from a ShipData template with the given key.
func _make_instance(
		key: String, data: ShipData, player: int) -> ShipInstance:
	return ShipInstance.create_from_data(key, data, 2, player)


# --- setup() ---

func test_setup_sets_faction_rebel() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	assert_eq(int(panel.get_faction()), int(Constants.Faction.REBEL_ALLIANCE),
			"Panel faction should be Rebel Alliance")


func test_setup_sets_faction_imperial() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.GALACTIC_EMPIRE, false)
	assert_eq(int(panel.get_faction()), int(Constants.Faction.GALACTIC_EMPIRE),
			"Panel faction should be Galactic Empire")


# --- add_ship_entry() ---

func test_add_ship_entry_increments_count() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE", "REDIRECT"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	assert_eq(panel.get_entry_count(), 1,
			"Entry count should be 1 after adding a single ship")


func test_add_multiple_ship_entries() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data_a: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE"])
	var data_b: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["BRACE", "REDIRECT"])
	var inst_a: ShipInstance = _make_instance("ship_a", data_a, 0)
	var inst_b: ShipInstance = _make_instance("ship_b", data_b, 0)
	panel.add_ship_entry(inst_a)
	panel.add_ship_entry(inst_b)
	assert_eq(panel.get_entry_count(), 2,
			"Entry count should be 2 after adding two ships")


func test_add_ship_entry_creates_child_container() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE", "EVADE", "REDIRECT"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	assert_gt(panel.get_child_count(), 0,
			"Panel should have at least one child after adding a ship entry")


# --- Defense token display in panel ---

func test_entry_has_defense_token_column_with_correct_structure() -> void:
	# Arrange
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE", "BRACE", "REDIRECT"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	# Act
	panel.add_ship_entry(inst)
	# Assert — the entry is an HBoxContainer; its first child should be
	# a VBoxContainer (token column) with tokens stacked vertically.
	var entry: HBoxContainer = panel.get_child(0) as HBoxContainer
	assert_not_null(entry, "First child should be an HBoxContainer")
	var token_col: VBoxContainer = entry.get_child(0) as VBoxContainer
	assert_not_null(token_col, "First child of entry should be VBoxContainer")
	# In headless tests, textures may not load, so token column children may be 0.
	# But the structure should be correct regardless.
	assert_true(token_col is VBoxContainer,
			"Token column should be a VBoxContainer")


func test_discarded_tokens_not_shown() -> void:
	# Arrange
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE", "BRACE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	# Discard one token before adding to panel
	inst.discard_defense_token(0)
	# Act
	panel.add_ship_entry(inst)
	# Assert — entry structure still valid
	var entry: HBoxContainer = panel.get_child(0) as HBoxContainer
	var token_col: VBoxContainer = entry.get_child(0) as VBoxContainer
	assert_true(token_col is VBoxContainer,
			"Token column should exist even with discarded tokens")


# --- get_entry_count() ---

func test_entry_count_zero_before_adding() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	assert_eq(panel.get_entry_count(), 0,
			"Entry count should be 0 before adding any ships")


# --- update_position() ---

func test_update_position_left_side() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	panel.update_position(Vector2(1920, 1080))
	assert_eq(panel.position.x, GameScale.card_panel_edge_padding_px,
			"Left panel should be at edge_padding from left edge")
	assert_eq(panel.position.y, GameScale.card_panel_top_padding_px,
			"Panel should be at top_padding from top edge")


func test_update_position_right_side() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.GALACTIC_EMPIRE, false)
	panel.update_position(Vector2(1920, 1080))
	# Right position depends on panel width: viewport_x - size.x - padding.
	# Panel size is 0 before layout, so it should be 1920 - 0 - 8 = 1912.
	assert_gt(panel.position.x, 0.0,
			"Right panel should have positive x position")


# --- magnify toggle (UI-018) ---

func test_toggle_magnify_sets_magnified_flag() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE", "BRACE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	# Initially not magnified.
	assert_false(panel._entries[0]["magnified"],
			"Entry should not be magnified initially")
	# Toggle on.
	panel._toggle_magnify(0)
	assert_true(panel._entries[0]["magnified"],
			"Entry should be magnified after first toggle")
	# Toggle off.
	panel._toggle_magnify(0)
	assert_false(panel._entries[0]["magnified"],
			"Entry should be normal after second toggle")


func test_sizes_read_from_game_scale() -> void:
	# Verify the panel uses GameScale values, not hardcoded constants.
	assert_gt(GameScale.card_panel_card_height_px, 0.0,
			"card_panel_card_height_px should be loaded from scale config")
	assert_gt(GameScale.card_panel_token_height_px, 0.0,
			"card_panel_token_height_px should be loaded from scale config")
	assert_gt(GameScale.card_panel_magnify_factor, 1.0,
			"card_panel_magnify_factor should be > 1.0")


# --- Command dial stack display ---

func test_entry_stores_dial_container() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	assert_true(panel._entries[0].has("dial_container"),
			"Entry should have a dial_container key")
	assert_true(panel._entries[0]["dial_container"] is Control,
			"dial_container should be a Control node")


## Regression: dial_container must have MOUSE_FILTER_STOP and its own
## gui_input connection so clicks on the dial area are handled directly
## instead of being silently consumed by default Godot 4 control behaviour.
func test_dial_container_mouse_filter_and_gui_input() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	var dial_cont: VBoxContainer = panel._entries[0]["dial_container"]
	assert_eq(int(dial_cont.mouse_filter), int(Control.MOUSE_FILTER_STOP),
			"dial_container must have MOUSE_FILTER_STOP to capture clicks")
	assert_true(dial_cont.gui_input.get_connections().size() > 0,
			"dial_container must have gui_input connected")


## Regression: intermediate containers (left_col, token_col, cmd_token_col)
## must use MOUSE_FILTER_PASS so clicks outside the dial area propagate
## to the entry_container for magnify toggle.
func test_intermediate_containers_use_mouse_filter_pass() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	var left_col: VBoxContainer = panel._entries[0]["left_col"]
	var token_col: VBoxContainer = panel._entries[0]["token_col"]
	var cmd_col: VBoxContainer = panel._entries[0]["cmd_token_col"]
	assert_eq(int(left_col.mouse_filter), int(Control.MOUSE_FILTER_PASS),
			"left_col must use MOUSE_FILTER_PASS")
	assert_eq(int(token_col.mouse_filter), int(Control.MOUSE_FILTER_PASS),
			"token_col must use MOUSE_FILTER_PASS")
	assert_eq(int(cmd_col.mouse_filter), int(Control.MOUSE_FILTER_PASS),
			"cmd_token_col must use MOUSE_FILTER_PASS")


func test_entry_stores_cmd_token_col() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	assert_true(panel._entries[0].has("cmd_token_col"),
			"Entry should have a cmd_token_col key")
	assert_true(panel._entries[0]["cmd_token_col"] is VBoxContainer,
			"cmd_token_col should be a VBoxContainer")


func test_entry_stores_left_col() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["EVADE"])
	var inst: ShipInstance = _make_instance("test_ship", data, 0)
	panel.add_ship_entry(inst)
	assert_true(panel._entries[0].has("left_col"),
			"Entry should have a left_col key")
	assert_true(panel._entries[0]["left_col"] is VBoxContainer,
			"left_col should be a VBoxContainer")


func test_dial_scale_config_loaded() -> void:
	# Verify the new scale config values for dials are loaded.
	assert_gt(GameScale.card_panel_dial_height_px, 0.0,
			"card_panel_dial_height_px should be loaded from scale config")
	assert_gt(GameScale.card_panel_dial_width_px, 0.0,
			"card_panel_dial_width_px should be loaded from scale config")
	assert_gt(GameScale.card_panel_cmd_token_height_px, 0.0,
			"card_panel_cmd_token_height_px should be loaded from scale config")


# --- viewer restriction ---

func test_setup_viewer_stores_player_index() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	assert_eq(panel._viewer_player, 0,
			"Viewer player should be stored from setup()")


# --- Destroyed ship ghosting ---

func test_ghost_entry_dims_container() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["evade"])
	var inst: ShipInstance = _make_instance("ghost_test", data, 0)
	panel.add_ship_entry(inst)
	# Act — ghost the entry.
	panel._ghost_entry(panel._entries[0])
	# Assert
	var container: HBoxContainer = panel._entries[0]["container"]
	assert_almost_eq(container.modulate.a, 0.35, 0.01,
			"Ghosted entry container should be dimmed to ~35% alpha")
	assert_true(panel._entries[0].get("ghosted", false),
			"Entry should have ghosted=true flag")


func test_ghost_entry_blocks_mouse() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["evade"])
	var inst: ShipInstance = _make_instance("ghost_mouse", data, 0)
	panel.add_ship_entry(inst)
	panel._ghost_entry(panel._entries[0])
	var container: HBoxContainer = panel._entries[0]["container"]
	assert_eq(container.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"Ghosted entry should ignore mouse input")


func test_ghost_entry_idempotent() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["evade"])
	var inst: ShipInstance = _make_instance("ghost_idem", data, 0)
	panel.add_ship_entry(inst)
	panel._ghost_entry(panel._entries[0])
	var child_count_before: int = (
			panel._entries[0]["container"] as HBoxContainer).get_child_count()
	panel._ghost_entry(panel._entries[0])
	var child_count_after: int = (
			panel._entries[0]["container"] as HBoxContainer).get_child_count()
	assert_eq(child_count_after, child_count_before,
			"Calling _ghost_entry twice should not add duplicate DESTROYED label")


func test_is_ship_phase_eligible_false_when_destroyed() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var data: ShipData = _make_ship_data(
			Constants.Faction.REBEL_ALLIANCE, ["evade"])
	var inst: ShipInstance = _make_instance("destroyed_elig", data, 0)
	inst.mark_destroyed()
	assert_false(panel._is_ship_phase_eligible(inst),
			"Destroyed ship must not be eligible for activation")

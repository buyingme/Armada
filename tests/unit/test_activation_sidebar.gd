## Unit tests for ActivationSidebar authoritative projection updates.
extends GutTest


var _sidebar: ActivationSidebar = null
var _saved_game_state: GameState = null
var _saved_activating_ship: ShipInstance = null
var _saved_activating_squadron: SquadronInstance = null


func before_each() -> void:
	_sidebar = ActivationSidebar.new()
	_sidebar.name = "TestActivationSidebar"
	add_child(_sidebar)
	_saved_game_state = GameManager.current_game_state
	_saved_activating_ship = GameManager.get_activating_ship()
	_saved_activating_squadron = GameManager.get_activating_squadron()


func after_each() -> void:
	GameManager.current_game_state = _saved_game_state
	GameManager._activating_ship = _saved_activating_ship
	GameManager._activating_squadron = _saved_activating_squadron
	_free_node(_sidebar)
	_sidebar = null


func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _make_state_with_units() -> Dictionary:
	var state: GameState = GameState.new()
	state.initialize()
	state.initiative_player = 0
	var rebel_ps: PlayerState = state.get_player_state(0)
	var imperial_ps: PlayerState = state.get_player_state(1)
	rebel_ps.faction = Constants.Faction.REBEL_ALLIANCE
	imperial_ps.faction = Constants.Faction.GALACTIC_EMPIRE

	var rebel_ship: ShipInstance = ShipInstance.new()
	rebel_ship.owner_player = 0
	rebel_ps.ships.append(rebel_ship)

	var imperial_squad: SquadronInstance = SquadronInstance.new()
	imperial_squad.owner_player = 1
	imperial_ps.squadrons.append(imperial_squad)

	return {
		"state": state,
		"rebel_ship": rebel_ship,
		"imperial_squad": imperial_squad,
	}


func test_refresh_from_authoritative_state_populates_when_empty() -> void:
	# Arrange
	var data: Dictionary = _make_state_with_units()
	var state: GameState = data["state"]
	# Act
	_sidebar.refresh_from_authoritative_state(state)
	# Assert
	assert_eq(_sidebar._entries.size(), 2,
			"Sidebar should build entries from authoritative state when empty.")


func test_refresh_from_authoritative_state_rebuilds_when_unit_count_changes() -> void:
	# Arrange
	var data: Dictionary = _make_state_with_units()
	var state: GameState = data["state"]
	_sidebar.populate(state)
	var imperial_ps: PlayerState = state.get_player_state(1)
	var extra_ship: ShipInstance = ShipInstance.new()
	extra_ship.owner_player = 1
	imperial_ps.ships.append(extra_ship)
	# Act
	_sidebar.refresh_from_authoritative_state(state)
	# Assert
	assert_eq(_sidebar._entries.size(), 3,
			"Sidebar should rebuild entries when authoritative unit count changes.")


func test_refresh_from_authoritative_state_highlights_game_manager_active_unit() -> void:
	# Arrange
	var data: Dictionary = _make_state_with_units()
	var state: GameState = data["state"]
	var rebel_ship: ShipInstance = data["rebel_ship"]
	GameManager.current_game_state = state
	GameManager._activating_ship = rebel_ship
	GameManager._activating_squadron = null
	_sidebar.populate(state)
	# Act
	_sidebar.refresh_from_authoritative_state(state)
	# Assert
	var entry: Dictionary = _sidebar._entries[rebel_ship]
	var lbl: Label = entry["label"]
	assert_true(lbl.text.begins_with(ActivationSidebar.ACTIVE_PREFIX),
			"Active ship should be highlighted from authoritative GameManager state.")

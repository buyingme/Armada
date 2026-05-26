## Learning Scenario Preparer
##
## Scene-independent setup helper for converting LearningScenarioSetup data into
## runtime instances registered inside a GameState.
class_name LearningScenarioPreparer
extends RefCounted


## Creates scenario instances, seeds normalized positions, and registers them in
## [param game_state]. The returned dictionary contains typed `ships` and
## `squadrons` arrays for presentation binding.
## Rules Reference: "Learning Scenario Setup", steps 4 and 9, p.5-6.
static func prepare_game_state(
	setup: LearningScenarioSetup,
	game_state: GameState
) -> Dictionary:
	if setup == null or game_state == null:
		return {"ships": [], "squadrons": []}
	game_state.damage_deck = setup.get_damage_deck(game_state.rng)
	var ships: Array[ShipInstance] = setup.create_ship_instances()
	var squadrons: Array[SquadronInstance] = setup.create_squadron_instances()
	_seed_instance_positions(setup, ships, squadrons)
	_register_instances(game_state, ships, squadrons)
	return {"ships": ships, "squadrons": squadrons}


static func _seed_instance_positions(
	setup: LearningScenarioSetup,
	ships: Array[ShipInstance],
	squadrons: Array[SquadronInstance]
) -> void:
	_seed_ship_positions(setup.get_ship_placements(), ships)
	_seed_squadron_positions(setup.get_squadron_placements(), squadrons)


static func _seed_ship_positions(
	placements: Array[TokenPlacement],
	ships: Array[ShipInstance]
) -> void:
	for index: int in range(min(placements.size(), ships.size())):
		ships[index].pos_x = placements[index].pos_x
		ships[index].pos_y = placements[index].pos_y
		ships[index].rotation_deg = rad_to_deg(placements[index].rotation_rad)


static func _seed_squadron_positions(
	placements: Array[TokenPlacement],
	squadrons: Array[SquadronInstance]
) -> void:
	for index: int in range(min(placements.size(), squadrons.size())):
		squadrons[index].pos_x = placements[index].pos_x
		squadrons[index].pos_y = placements[index].pos_y
		squadrons[index].rotation_deg = rad_to_deg(placements[index].rotation_rad)


static func _register_instances(
	game_state: GameState,
	ships: Array[ShipInstance],
	squadrons: Array[SquadronInstance]
) -> void:
	_prepare_player_states(game_state)
	for ship: ShipInstance in ships:
		game_state.get_player_state(ship.owner_player).ships.append(ship)
	for squadron: SquadronInstance in squadrons:
		game_state.get_player_state(squadron.owner_player).squadrons.append(squadron)


static func _prepare_player_states(game_state: GameState) -> void:
	game_state.initiative_player = LearningScenarioSetup.REBEL_PLAYER
	var rebel_state: PlayerState = game_state.get_player_state(
			LearningScenarioSetup.REBEL_PLAYER)
	var imperial_state: PlayerState = game_state.get_player_state(
			LearningScenarioSetup.IMPERIAL_PLAYER)
	rebel_state.faction = Constants.Faction.REBEL_ALLIANCE
	imperial_state.faction = Constants.Faction.GALACTIC_EMPIRE
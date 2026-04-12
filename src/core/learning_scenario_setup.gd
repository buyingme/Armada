## LearningScenarioSetup
##
## Loads Learning Scenario token placements from
## Resources/Game_Components/scenarios/learning_scenario.json.
## Faction and ship size are resolved from the individual card JSON files
## (ships/<key>.json, squadrons/<key>.json) — never hardcoded in GDScript.
##
## Also creates [ShipInstance] / [SquadronInstance] runtime objects and
## populates [PlayerState] arrays, the shared [DamageDeck], and assigns
## factions to player states.
##
## Rules Reference: "Learning Scenario Setup", steps 4 and 9, p.5–6.
## SU-010–030; DM-007.
class_name LearningScenarioSetup
extends RefCounted


## Subfolder and filename for the scenario placement data.
## Rules Reference: Resources/Game_Components/scenarios/learning_scenario.json
const SCENARIO_SUBFOLDER: String = "scenarios/"
const SCENARIO_FILENAME: String = "learning_scenario.json"

## Learning Scenario initial speed for all ships (SU-021).
## Rules Reference: "Learning Scenario Setup", step 4, p.5:
## "Set all speed dials to '2'."
const LEARNING_SCENARIO_SPEED: int = 2

## Player indices — Rebel has initiative (SU-020).
## Rules Reference: "Learning Scenario Setup", step 1, p.5:
## "The Rebel player has initiative."
const REBEL_PLAYER: int = 0
const IMPERIAL_PLAYER: int = 1

## Cached scenario data dictionary loaded once from JSON.
var _data: Dictionary = {}

## The shared damage deck, initialised once.
var _damage_deck: DamageDeck = null


## Loads the scenario JSON into the internal cache.
## Called implicitly by the accessor methods; safe to call multiple times.
func _ensure_loaded() -> void:
	if not _data.is_empty():
		return
	_data = AssetLoader.load_json(SCENARIO_SUBFOLDER, SCENARIO_FILENAME)
	if _data.is_empty():
		push_error("LearningScenarioSetup: could not load %s" % SCENARIO_FILENAME)


## Returns the map image filename declared in the scenario JSON
## (e.g. "map_3x3_distant_planet_v3.jpg"), or an empty string if none.
## The file is expected inside Resources/Game_Components/maps/.
func get_map_image_filename() -> String:
	_ensure_loaded()
	return _data.get("map_image", "") as String


## Returns the complete list of token placements for the Learning Scenario.
## Imperial tokens occupy the top deployment zone (pos_y < 0.40);
## Rebel tokens occupy the bottom zone (pos_y > 0.60).
##
## Rules Reference: "Learning Scenario Setup", step 9; diagram p.6.
func get_all_placements() -> Array[TokenPlacement]:
	_ensure_loaded()
	if _data.is_empty():
		return []
	var result: Array[TokenPlacement] = []
	var tokens: Array = _data.get("tokens", [])
	for entry: Variant in tokens:
		var p: TokenPlacement = _placement_from_entry(entry as Dictionary)
		if p != null:
			result.append(p)
	return result


## Returns only ship token placements (is_ship == true).
func get_ship_placements() -> Array[TokenPlacement]:
	var result: Array[TokenPlacement] = []
	for p: TokenPlacement in get_all_placements():
		if p.is_ship:
			result.append(p)
	return result


## Returns only squadron token placements (is_ship == false).
func get_squadron_placements() -> Array[TokenPlacement]:
	var result: Array[TokenPlacement] = []
	for p: TokenPlacement in get_all_placements():
		if not p.is_ship:
			result.append(p)
	return result


## Returns the total number of tokens placed in the Learning Scenario.
func get_token_count() -> int:
	return get_all_placements().size()


## Returns the shared [DamageDeck] (initialised on first call).
## If [param rng] is provided, ensures deterministic shuffle order.
## Rules Reference: SU-029 — the damage deck is shuffled at setup.
func get_damage_deck(rng: GameRng = null) -> DamageDeck:
	if _damage_deck == null:
		_damage_deck = DamageDeck.new()
		if rng:
			_damage_deck.set_rng(rng)
		_damage_deck.initialize()
	return _damage_deck


## Returns true if the scenario has fixed round-1 commands configured
## and the toggle is enabled.
## Rules Reference: LTP p.10 — "suggested commands"; CP-009.
func has_fixed_round1_commands() -> bool:
	_ensure_loaded()
	return _data.get("use_fixed_round1_commands", false) as bool


## Returns the fixed round-1 command assignments as a Dictionary mapping
## ship data_key → Array[int] of Constants.CommandType values.
## The first element is the top of the stack (revealed first).
## Returns an empty Dictionary if the feature is disabled or data is missing.
## Rules Reference: LTP p.10 — "last command listed is on the bottom";
## CP-009.
func get_fixed_round1_commands() -> Dictionary:
	_ensure_loaded()
	if not has_fixed_round1_commands():
		return {}
	var raw: Variant = _data.get("fixed_round1_commands", {})
	if not raw is Dictionary:
		return {}
	var result: Dictionary = {}
	for key: Variant in (raw as Dictionary):
		var cmd_names: Variant = (raw as Dictionary)[key]
		if not cmd_names is Array:
			push_error("LearningScenarioSetup: fixed_round1_commands[%s] is not an Array" % str(key))
			continue
		var typed_cmds: Array[int] = []
		for name: Variant in (cmd_names as Array):
			var cmd: int = _parse_command_name(str(name))
			if cmd < 0:
				push_error("LearningScenarioSetup: unknown command '%s' for ship '%s'" % [str(name), str(key)])
				continue
			typed_cmds.append(cmd)
		if typed_cmds.size() > 0:
			result[str(key)] = typed_cmds
	return result


## Populates a [GameState] with the Learning Scenario starting state.
## Creates [ShipInstance] / [SquadronInstance] objects, assigns them to
## the correct [PlayerState], sets factions, and initialises the damage deck.
## [param game_state] — an already-initialised GameState with 2 player states.
## Rules Reference: SU-010–030; LTP p.5–6.
func populate_game_state(game_state: GameState) -> void:
	_ensure_loaded()
	# Rebel: player 0, Empire: player 1 (SU-020).
	game_state.initiative_player = REBEL_PLAYER
	var rebel_state: PlayerState = game_state.get_player_state(REBEL_PLAYER)
	var imperial_state: PlayerState = game_state.get_player_state(IMPERIAL_PLAYER)
	rebel_state.faction = Constants.Faction.REBEL_ALLIANCE
	imperial_state.faction = Constants.Faction.GALACTIC_EMPIRE
	var tokens: Array = _data.get("tokens", [])
	for entry: Variant in tokens:
		var d: Dictionary = entry as Dictionary
		var key: String = d.get("key", "")
		var is_ship: bool = (d.get("type", "ship") == "ship")
		if is_ship:
			_create_ship_instance(key, rebel_state, imperial_state)
		else:
			_create_squadron_instance(key, rebel_state, imperial_state)


## Creates [ShipInstance] objects for all ship placements.
## Returns an Array mapping data_key → ShipInstance, keyed by placement order.
func create_ship_instances() -> Array[ShipInstance]:
	_ensure_loaded()
	var result: Array[ShipInstance] = []
	var tokens: Array = _data.get("tokens", [])
	for entry: Variant in tokens:
		var d: Dictionary = entry as Dictionary
		if d.get("type", "ship") != "ship":
			continue
		var key: String = d.get("key", "")
		var ship_data: ShipData = AssetLoader.load_ship_data(key)
		if ship_data == null:
			push_error("LearningScenarioSetup: missing ship data for '%s'" % key)
			continue
		var player: int = _player_for_faction(ship_data.faction)
		var inst: ShipInstance = ShipInstance.create_from_data(
				key, ship_data, LEARNING_SCENARIO_SPEED, player)
		result.append(inst)
	return result


## Creates [SquadronInstance] objects for all squadron placements.
func create_squadron_instances() -> Array[SquadronInstance]:
	_ensure_loaded()
	var result: Array[SquadronInstance] = []
	var tokens: Array = _data.get("tokens", [])
	for entry: Variant in tokens:
		var d: Dictionary = entry as Dictionary
		if d.get("type", "ship") == "ship":
			continue
		var key: String = d.get("key", "")
		var squad_data: SquadronData = AssetLoader.load_squadron_data(key)
		if squad_data == null:
			push_error("LearningScenarioSetup: missing squadron data '%s'" % key)
			continue
		var player: int = _player_for_faction(squad_data.faction)
		var inst: SquadronInstance = SquadronInstance.create_from_data(
				key, squad_data, player)
		result.append(inst)
	return result


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds a TokenPlacement from one JSON token entry.
## Faction and ship size are resolved from the card data JSON.
## Returns null and pushes an error if the card data cannot be found.
## Rules Reference: Resources/Game_Components/card_data_schema.json
func _placement_from_entry(entry: Dictionary) -> TokenPlacement:
	var key: String = entry.get("key", "")
	var is_ship: bool = (entry.get("type", "ship") == "ship")
	var pos_x: float = float(entry.get("pos_x", 0.5))
	var pos_y: float = float(entry.get("pos_y", 0.5))
	var rot_rad: float = deg_to_rad(float(entry.get("rotation_deg", 0.0)))
	if is_ship:
		return _make_ship_placement(key, pos_x, pos_y, rot_rad)
	return _make_squadron_placement(key, pos_x, pos_y, rot_rad)


## Builds a ship TokenPlacement, reading faction and ship_size from card JSON.
func _make_ship_placement(
		key: String, pos_x: float, pos_y: float, rot_rad: float
) -> TokenPlacement:
	var ship_data: ShipData = AssetLoader.load_ship_data(key)
	if ship_data == null:
		push_error("LearningScenarioSetup: missing ship data for '%s'" % key)
		return null
	return TokenPlacement.new(
			key, true, ship_data.faction, pos_x, pos_y, rot_rad, ship_data.ship_size)


## Builds a squadron TokenPlacement, reading faction from card JSON.
func _make_squadron_placement(
		key: String, pos_x: float, pos_y: float, rot_rad: float
) -> TokenPlacement:
	var squad_data: SquadronData = AssetLoader.load_squadron_data(key)
	if squad_data == null:
		push_error("LearningScenarioSetup: missing squadron data for '%s'" % key)
		return null
	return TokenPlacement.new(key, false, squad_data.faction, pos_x, pos_y, rot_rad)


## Returns the player index for a given faction.
## Rebel → 0 (initiative), Imperial → 1. SU-020.
func _player_for_faction(faction: Constants.Faction) -> int:
	if faction == Constants.Faction.GALACTIC_EMPIRE:
		return IMPERIAL_PLAYER
	return REBEL_PLAYER


## Converts a lowercase command name string to its Constants.CommandType value.
## Returns -1 for unknown names.
## Valid names: "navigate", "squadron", "concentrate_fire", "repair".
static func _parse_command_name(command_name: String) -> int:
	match command_name.to_lower().strip_edges():
		"navigate":
			return Constants.CommandType.NAVIGATE
		"squadron":
			return Constants.CommandType.SQUADRON
		"concentrate_fire":
			return Constants.CommandType.CONCENTRATE_FIRE
		"repair":
			return Constants.CommandType.REPAIR
		_:
			return -1


## Creates a ShipInstance and adds it to the correct PlayerState.
func _create_ship_instance(
		key: String, rebel_state: PlayerState,
		imperial_state: PlayerState) -> void:
	var ship_data: ShipData = AssetLoader.load_ship_data(key)
	if ship_data == null:
		push_error("LearningScenarioSetup: missing ship data for '%s'" % key)
		return
	var player: int = _player_for_faction(ship_data.faction)
	var inst: ShipInstance = ShipInstance.create_from_data(
			key, ship_data, LEARNING_SCENARIO_SPEED, player)
	if player == REBEL_PLAYER:
		rebel_state.ships.append(inst)
	else:
		imperial_state.ships.append(inst)


## Creates a SquadronInstance and adds it to the correct PlayerState.
func _create_squadron_instance(
		key: String, rebel_state: PlayerState,
		imperial_state: PlayerState) -> void:
	var squad_data: SquadronData = AssetLoader.load_squadron_data(key)
	if squad_data == null:
		push_error("LearningScenarioSetup: missing squadron data for '%s'" % key)
		return
	var player: int = _player_for_faction(squad_data.faction)
	var inst: SquadronInstance = SquadronInstance.create_from_data(
			key, squad_data, player)
	if player == REBEL_PLAYER:
		rebel_state.squadrons.append(inst)
	else:
		imperial_state.squadrons.append(inst)

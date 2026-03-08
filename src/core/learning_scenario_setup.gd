## LearningScenarioSetup
##
## Loads Learning Scenario token placements from
## Resources/Game_Components/scenarios/learning_scenario.json.
## Faction and ship size are resolved from the individual card JSON files
## (ships/<key>.json, squadrons/<key>.json) — never hardcoded in GDScript.
##
## Rules Reference: "Learning Scenario Setup", steps 4 and 9, p.5–6.
class_name LearningScenarioSetup
extends RefCounted


## Subfolder and filename for the scenario placement data.
## Rules Reference: Resources/Game_Components/scenarios/learning_scenario.json
const SCENARIO_SUBFOLDER: String = "scenarios/"
const SCENARIO_FILENAME: String = "learning_scenario.json"


## Returns the complete list of token placements for the Learning Scenario.
## Imperial tokens occupy the top deployment zone (pos_y < 0.40);
## Rebel tokens occupy the bottom zone (pos_y > 0.60).
##
## Rules Reference: "Learning Scenario Setup", step 9; diagram p.6.
func get_all_placements() -> Array[TokenPlacement]:
	var data: Dictionary = AssetLoader.load_json(SCENARIO_SUBFOLDER, SCENARIO_FILENAME)
	if data.is_empty():
		push_error("LearningScenarioSetup: could not load %s" % SCENARIO_FILENAME)
		return []
	var result: Array[TokenPlacement] = []
	var tokens: Array = data.get("tokens", [])
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

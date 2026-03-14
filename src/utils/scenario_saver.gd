## ScenarioSaver
##
## Writes token positions back to a scenario JSON file in the normalised
## coordinate format used by LearningScenarioSetup.
##
## Requirements: DBG-040, DBG-041
class_name ScenarioSaver
extends RefCounted


## Base path for game component assets (matches AssetLoader).
const BASE_PATH: String = "res://Resources/Game_Components/"

## Logger instance.
var _log: GameLogger = GameLogger.new("ScenarioSaver")


## Saves all token positions to the specified scenario JSON file.
## [param subfolder] — e.g. "scenarios/"
## [param filename] — e.g. "learning_scenario.json"
## [param ship_tokens] — Array of ShipToken nodes.
## [param squadron_tokens] — Array of SquadronToken nodes.
## [param play_area_side] — play area side in pixels (for normalisation).
## Returns true on success.
func save_positions(
		subfolder: String,
		filename: String,
		ship_tokens: Array,
		squadron_tokens: Array,
		play_area_side: float
) -> bool:
	if play_area_side <= 0.0:
		_log.error("Cannot save: play_area_side is zero")
		return false

	# Load existing JSON to preserve metadata (_comment, _source, etc.).
	var path: String = BASE_PATH + subfolder + filename
	var existing: Dictionary = _load_existing(path)

	# Build updated token array.
	var tokens_array: Array = []
	for token: Variant in ship_tokens:
		var ship: ShipToken = token as ShipToken
		if ship == null:
			continue
		tokens_array.append(_ship_to_dict(ship, play_area_side))

	for token: Variant in squadron_tokens:
		var squad: SquadronToken = token as SquadronToken
		if squad == null:
			continue
		tokens_array.append(_squadron_to_dict(squad, play_area_side))

	existing["tokens"] = tokens_array

	# Write to disk.
	return _write_json(path, existing)


## Converts a ShipToken to a placement dictionary.
func _ship_to_dict(token: ShipToken, side: float) -> Dictionary:
	var norm_x: float = snapped(token.position.x / side, 0.001)
	var norm_y: float = snapped(token.position.y / side, 0.001)
	var rot_deg: float = snapped(rad_to_deg(token.rotation), 0.1)
	return {
		"key": _get_data_key(token),
		"type": "ship",
		"pos_x": norm_x,
		"pos_y": norm_y,
		"rotation_deg": rot_deg,
	}


## Converts a SquadronToken to a placement dictionary.
func _squadron_to_dict(token: SquadronToken, side: float) -> Dictionary:
	var norm_x: float = snapped(token.position.x / side, 0.001)
	var norm_y: float = snapped(token.position.y / side, 0.001)
	var rot_deg: float = snapped(rad_to_deg(token.rotation), 0.1)
	return {
		"key": _get_data_key(token),
		"type": "squadron",
		"pos_x": norm_x,
		"pos_y": norm_y,
		"rotation_deg": rot_deg,
	}


## Extracts the data_key from a token's name. Tokens are named by their
## data_key during spawn (set by setup()). If the placement stored the key,
## we read it from the name. Fallback: parse from the node name.
func _get_data_key(token: Node2D) -> String:
	# ShipToken and SquadronToken both store _placement which has data_key.
	# Since _placement is private, we extract from node name which may include
	# a numeric suffix added by Godot. Strip @NNN suffix if present.
	if token.has_meta("data_key"):
		return token.get_meta("data_key") as String
	# Fallback — should not happen if tokens are set up correctly.
	return token.name.split("@")[0]


## Loads existing JSON to preserve non-token fields.
func _load_existing(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"scenario_name": "Saved Scenario", "tokens": []}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"scenario_name": "Saved Scenario", "tokens": []}
	var json_text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		return {"scenario_name": "Saved Scenario", "tokens": []}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {"scenario_name": "Saved Scenario", "tokens": []}


## Writes a dictionary as formatted JSON to disk.
func _write_json(path: String, data: Dictionary) -> bool:
	var json_text: String = JSON.stringify(data, "    ")
	# Use the global path for writing (res:// works in editor/debug builds).
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_log.error("Failed to open %s for writing" % path)
		return false
	file.store_string(json_text)
	file.store_string("\n")
	file.close()
	_log.info("Saved token positions to %s" % path)
	return true

## Asset Loader
##
## Validates and loads game component assets from the Resources/Game_Components/
## directory. Reports missing files so problems surface at startup rather than
## mid-game.
##
## Each asset category defines a list of expected filenames. The loader checks
## that every expected file exists and can be loaded by Godot's resource system.
class_name AssetLoader
extends RefCounted


## Base path for all game component assets.
const BASE_PATH: String = "res://Resources/Game_Components/"

## Logger instance.
var _log: GameLogger = GameLogger.new("AssetLoader")


## Result of a validation run.
class ValidationResult:
	extends RefCounted
	var found: Array[String] = []
	var missing: Array[String] = []

	var is_valid: bool:
		get:
			return missing.is_empty()

	var total_expected: int:
		get:
			return found.size() + missing.size()


## Defines each asset category with its subfolder and expected files.
## Categories marked optional = true only produce warnings, not errors.
const ASSET_MANIFEST: Array[Dictionary] = [
	{
		"category": "ships",
		"path": "ships/",
		"files": [
			"cr90_corvette_a.json",
			"cr90_corvette_a_card.png",
			"cr90_corvette_a_token.png",
			"cr90_corvette_b.json",
			"cr90_corvette_b_card.png",
			"nebulon_b_escort_frigate.json",
			"nebulon_b_escort_frigate_card.png",
			"nebulon_b_escort_frigate_token.png",
			"nebulon_b_support_refit.json",
			"nebulon_b_support_refit_card.png",
			"victory_i_class_star_destroyer.json",
			"victory_i_class_star_destroyer_card.png",
			"victory_ii_class_star_destroyer.json",
			"victory_ii_class_star_destroyer_card.png",
			"victory_ii_class_star_destroyer_token.png",
		],
		"optional": false,
	},
	{
		"category": "squadrons",
		"path": "squadrons/",
		"files": [
			"x_wing_squadron.json",
			"x_wing_squadron_card.png",
			"x_wing_squadron_token.png",
			"tie_fighter_squadron.json",
			"tie_fighter_squadron_card.png",
			"tie_fighter_squadron_token.png",
			"squad_base.png",
			"squad_base_buttons.png",
			"squad_outline.png",
			"squad_tab_blue.png",
			"squad_tab_orange.png",
		],
		"optional": false,
	},
	{
		"category": "dice",
		"path": "dice/",
		"files": [
			"die_red_blank.png",
			"die_red_hit.png",
			"die_red_hit_hit.png",
			"die_red_crit.png",
			"die_red_accuracy.png",
			"die_blue_hit.png",
			"die_blue_crit.png",
			"die_blue_accuracy.png",
			"die_black_blank.png",
			"die_black_hit.png",
			"die_black_crit.png",
			"die_black_hit_crit.png",
		],
		"optional": true,
	},
	{
		"category": "defense_tokens",
		"path": "defense_tokens/",
		"files": [
			"token_brace_ready.png",
			"token_brace_exhausted.png",
			"token_contain_ready.png",
			"token_contain_exhausted.png",
			"token_evade_ready.png",
			"token_evade_exhausted.png",
			"token_redirect_ready.png",
			"token_redirect_exhausted.png",
			"token_scatter_ready.png",
			"token_scatter_exhausted.png",
		],
		"optional": true,
	},
	{
		"category": "command_tokens",
		"path": "command_tokens/",
		"files": [
			"cmd_concentrate_fire.png",
			"cmd_navigate.png",
			"cmd_repair.png",
			"cmd_squadron.png",
		],
		"optional": true,
	},
	{
		"category": "maps",
		"path": "maps/",
		"files": [
			"map_3x3_azure_v3.jpg",
			"map_3x3_bluegreen_rift_v3.jpg",
			"map_3x3_distant_planet_v3.jpg",
			"map_3x3_purple_nebula_v3.jpg",
		],
		"optional": false,
	},
	{
		"category": "tools",
		"path": "tools/",
		"files": [
			"range_ruler_range.png",
			"range_ruler_distance.png",
		],
		"optional": false,
	},
	{
		"category": "scenarios",
		"path": "scenarios/",
		"files": [
			"learning_scenario.json",
		],
		"optional": false,
	},
	{
		"category": "scale",
		"path": "scale/",
		"files": [
			"scale_config.json",
		],
		"optional": false,
	},
]


## Validates all asset categories and returns a dictionary of category → result.
static func validate_all() -> Dictionary:
	var results: Dictionary = {}
	var log := GameLogger.new("AssetLoader")

	for manifest: Dictionary in ASSET_MANIFEST:
		var category: String = manifest["category"]
		var folder: String = manifest["path"]
		var files: Array = manifest["files"]
		var optional: bool = manifest.get("optional", false)

		var result := ValidationResult.new()
		for filename: String in files:
			var full_path: String = BASE_PATH + folder + filename
			if ResourceLoader.exists(full_path):
				result.found.append(filename)
			else:
				result.missing.append(filename)

		results[category] = result

		if result.is_valid:
			log.info("%s: all %d assets found" % [category, result.total_expected])
		elif optional:
			log.warn("%s: %d/%d missing (optional) — %s" % [
				category, result.missing.size(), result.total_expected,
				", ".join(result.missing)])
		else:
			log.error("%s: %d/%d MISSING — %s" % [
				category, result.missing.size(), result.total_expected,
				", ".join(result.missing)])

	return results


## Validates a single asset category by name. Returns null if category unknown.
static func validate_category(category_name: String) -> ValidationResult:
	for manifest: Dictionary in ASSET_MANIFEST:
		if manifest["category"] == category_name:
			var result := ValidationResult.new()
			var folder: String = manifest["path"]
			var files: Array = manifest["files"]
			for filename: String in files:
				var full_path: String = BASE_PATH + folder + filename
				if ResourceLoader.exists(full_path):
					result.found.append(filename)
				else:
					result.missing.append(filename)
			return result
	return null


## Loads a texture asset and returns it (or null on failure).
static func load_texture(subfolder: String, filename: String) -> Texture2D:
	var path: String = BASE_PATH + subfolder + filename
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


## Loads and parses a ship JSON data file into a [ShipData] resource.
## [param key] is the snake_case ship identifier (e.g. "cr90_corvette_a").
## Returns null if the file cannot be found or parsed.
static func load_ship_data(key: String) -> ShipData:
	var data: Dictionary = load_json("ships/", key + ".json")
	if data.is_empty():
		return null
	return ShipData.from_dict(data)


## Loads and parses a squadron JSON data file into a [SquadronData] resource.
## [param key] is the snake_case squadron identifier (e.g. "x_wing_squadron").
## Returns null if the file cannot be found or parsed.
static func load_squadron_data(key: String) -> SquadronData:
	var data: Dictionary = load_json("squadrons/", key + ".json")
	if data.is_empty():
		return null
	return SquadronData.from_dict(data)


## Loads a JSON asset and returns the parsed data as a Dictionary (or empty).
static func load_json(subfolder: String, filename: String) -> Dictionary:
	var path: String = BASE_PATH + subfolder + filename
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		return {}

	if json.data is Dictionary:
		return json.data as Dictionary
	return {}

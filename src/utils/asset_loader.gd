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
const SHIP_FOLDER: String = "ships/"
const SQUADRON_FOLDER: String = "squadrons/"
const UPGRADE_FOLDER: String = "upgrades/"
const OBJECTIVE_FOLDER: String = "objectives/"
const OBSTACLE_FOLDER: String = "obstacles/"
const RULE_FOLDER: String = "rules/"
const MAP_FOLDER: String = "maps/"
const JSON_EXTENSION: String = ".json"

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
			"map_3x6_azure_v4.jpg",
			"map_3x6_black_v4.jpg",
			"map_3x6_bluegreen-rift_v4.jpg",
			"map_3x6_coruscant_v4.jpg",
			"map_3x6_death-star2_v4.jpg",
			"map_3x6_death-star_v4.jpg",
			"map_3x6_distant-planet_v4.jpg",
			"map_3x6_felucia_v4.jpg",
			"map_3x6_galactic-backdrop_v4.jpg",
			"map_3x6_ghostly_geonosis_v4.jpg",
			"map_3x6_high-orbit_v4.jpg",
			"map_3x6_hoth_v4.jpg",
			"map_3x6_planet-and-moon_v4.jpg",
			"map_3x6_purple-nebula_v4.jpg",
			"map_3x6_scarif_shieldgate_v4.jpg",
			"map_3x6_shadow-dimension_v4.jpg",
			"map_3x6_singularity_v4.jpg",
			"map_3x6_starkiller_v4.jpg",
			"map_3x6_tlj_v4.jpg",
			"map_3x6_yavin4_v4.jpg",
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
			"debug_scenario.json",
			"learning_scenario.json",
			"standard_3x6.json"
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
	var logger := GameLogger.new("AssetLoader")

	for manifest: Dictionary in ASSET_MANIFEST:
		var category: String = manifest["category"]
		var folder: String = manifest["path"]
		var files: Array = manifest["files"]
		var optional: bool = manifest.get("optional", false)

		var result := ValidationResult.new()
		for filename: String in files:
			var full_path: String = BASE_PATH + folder + filename
			if _asset_exists(full_path, filename):
				result.found.append(filename)
			else:
				result.missing.append(filename)

		results[category] = result

		if result.is_valid:
			logger.info("%s: all %d assets found" % [category, result.total_expected])
		elif optional:
			logger.warn("%s: %d/%d missing (optional) — %s" % [
				category, result.missing.size(), result.total_expected,
				", ".join(result.missing)])
		else:
			logger.error("%s: %d/%d MISSING — %s" % [
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
				if _asset_exists(full_path, filename):
					result.found.append(filename)
				else:
					result.missing.append(filename)
			return result
	return null


## Loads a texture asset and returns it (or null on failure).
## Falls back to [method Image.load_from_file] for textures that have not
## been imported by the Godot editor yet (e.g. newly-added map images).
static func load_texture(subfolder: String, filename: String) -> Texture2D:
	var path: String = BASE_PATH + subfolder + filename
	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
	if _is_texture_filename(filename) and FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	return null


## Returns available map image filenames discovered from the maps folder.
static func list_map_filenames() -> Array[String]:
	var filenames: Array[String] = []
	var dir: DirAccess = DirAccess.open(BASE_PATH + MAP_FOLDER)
	if dir == null:
		return filenames
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir() and _is_texture_filename(entry_name):
			filenames.append(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	filenames.sort()
	return filenames


## Loads and parses a ship JSON data file into a [ShipData] resource.
## [param key] is the snake_case ship identifier (e.g. "cr90_corvette_a").
## Returns null if the file cannot be found or parsed.
static func load_ship_data(key: String) -> ShipData:
	var data: Dictionary = load_json(SHIP_FOLDER, key + JSON_EXTENSION)
	if data.is_empty():
		return null
	return ShipData.from_dict(data)


## Loads and parses a squadron JSON data file into a [SquadronData] resource.
## [param key] is the snake_case squadron identifier (e.g. "x_wing_squadron").
## Returns null if the file cannot be found or parsed.
static func load_squadron_data(key: String) -> SquadronData:
	var data: Dictionary = load_json(SQUADRON_FOLDER, key + JSON_EXTENSION)
	if data.is_empty():
		return null
	return SquadronData.from_dict(data)


## Returns all ship card data keys discovered in the catalog.
static func list_ship_keys() -> Array[String]:
	return _list_catalog_keys(SHIP_FOLDER, false)


## Returns all squadron card data keys discovered in the catalog.
static func list_squadron_keys() -> Array[String]:
	return _list_catalog_keys(SQUADRON_FOLDER, false)


## Returns all upgrade card data keys discovered in nested upgrade folders.
static func list_upgrade_keys() -> Array[String]:
	return _list_catalog_keys(UPGRADE_FOLDER, true)


## Returns all objective card data keys discovered in the catalog.
static func list_objective_keys() -> Array[String]:
	return _list_catalog_keys(OBJECTIVE_FOLDER, false)


## Returns all obstacle component data keys discovered in the catalog.
static func list_obstacle_keys() -> Array[String]:
	return _list_catalog_keys(OBSTACLE_FOLDER, false)


## Returns all rules-reference data keys discovered in the catalog.
static func list_rule_reference_keys() -> Array[String]:
	return _list_catalog_keys(RULE_FOLDER, false)


## Loads and parses an upgrade JSON data file into an UpgradeData resource.
static func load_upgrade_data(key: String) -> UpgradeData:
	var data: Dictionary = _load_catalog_record(UPGRADE_FOLDER, key, true)
	if data.is_empty():
		return null
	return UpgradeData.from_dict(data)


## Loads and parses an objective JSON data file into an ObjectiveData resource.
static func load_objective_data(key: String) -> ObjectiveData:
	var data: Dictionary = _load_catalog_record(OBJECTIVE_FOLDER, key, false)
	if data.is_empty():
		return null
	return ObjectiveData.from_dict(data)


## Loads and parses an obstacle JSON data file into an ObstacleData resource.
static func load_obstacle_data(key: String) -> ObstacleData:
	var data: Dictionary = _load_catalog_record(OBSTACLE_FOLDER, key, false)
	if data.is_empty():
		return null
	return ObstacleData.from_dict(data)


## Loads and parses a rules-reference JSON file into a RuleReferenceData resource.
static func load_rule_reference_data(key: String) -> RuleReferenceData:
	var data: Dictionary = _load_catalog_record(RULE_FOLDER, key, false)
	if data.is_empty():
		return null
	return RuleReferenceData.from_dict(data)


## Loads a JSON asset and returns the parsed data as a Dictionary (or empty).
static func load_json(subfolder: String, filename: String) -> Dictionary:
	return _load_json_at_path(BASE_PATH + subfolder + filename)


static func _asset_exists(path: String, filename: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return _is_texture_filename(filename) and FileAccess.file_exists(path)


static func _is_texture_filename(filename: String) -> bool:
	var lower: String = filename.to_lower()
	return lower.ends_with(".png") \
			or lower.ends_with(".jpg") \
			or lower.ends_with(".jpeg") \
			or lower.ends_with(".webp")


static func _load_catalog_record(subfolder: String, key: String, recursive: bool) -> Dictionary:
	for relative_path: String in _list_json_paths(subfolder, recursive):
		var data: Dictionary = _load_json_relative(relative_path)
		if data.is_empty():
			continue
		if _catalog_record_matches(data, relative_path, key):
			return data
	return {}


static func _list_catalog_keys(subfolder: String, recursive: bool) -> Array[String]:
	var keys: Array[String] = []
	for relative_path: String in _list_json_paths(subfolder, recursive):
		var data: Dictionary = _load_json_relative(relative_path)
		if data.is_empty():
			continue
		keys.append(str(data.get("data_key", _file_stem(relative_path))))
	keys.sort()
	return keys


static func _catalog_record_matches(data: Dictionary, relative_path: String, key: String) -> bool:
	if str(data.get("data_key", "")) == key:
		return true
	return _file_stem(relative_path) == key


static func _load_json_relative(relative_path: String) -> Dictionary:
	return _load_json_at_path(BASE_PATH + relative_path)


static func _load_json_at_path(path: String) -> Dictionary:
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


static func _list_json_paths(subfolder: String, recursive: bool) -> Array[String]:
	var paths: Array[String] = []
	_collect_json_paths(subfolder, recursive, paths)
	paths.sort()
	return paths


static func _collect_json_paths(subfolder: String, recursive: bool, paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(BASE_PATH + subfolder)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		_collect_json_entry(dir, subfolder, entry_name, recursive, paths)
		entry_name = dir.get_next()
	dir.list_dir_end()


static func _collect_json_entry(
	dir: DirAccess,
	subfolder: String,
	entry_name: String,
	recursive: bool,
	paths: Array[String]
) -> void:
	if entry_name.begins_with("."):
		return
	var relative_path: String = subfolder + entry_name
	if dir.current_is_dir():
		if recursive:
			_collect_json_paths(relative_path + "/", recursive, paths)
	elif entry_name.ends_with(JSON_EXTENSION):
		paths.append(relative_path)


static func _file_stem(relative_path: String) -> String:
	return relative_path.get_file().get_basename()

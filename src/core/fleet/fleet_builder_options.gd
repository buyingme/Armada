## Fleet Builder Options
##
## Read-only provider for fleet-builder option sets that are derived from core
## rules or catalog metadata rather than owned by presentation code.
class_name FleetBuilderOptions
extends RefCounted


const FORMAT_CORE_SET_180: String = "CORE_SET_180"
const FORMAT_STANDARD_400: String = "STANDARD_400"
const FORMAT_CUSTOM: String = "CUSTOM"
const CORE_SET_POINT_LIMIT: int = 180
const CUSTOM_POINT_LIMIT: int = 300
const MAP_GRID_3X3: String = "3x3"
const MAP_GRID_3X6: String = "3x6"
const MAP_PREFIX_3X3: String = "map_3x3"
const MAP_PREFIX_3X6: String = "map_3x6"
const DEFAULT_MAP_3X3: String = "map_3x3_distant_planet_v3.jpg"
const DEFAULT_MAP_3X6: String = "map_3x6_distant-planet_v4.jpg"

const UPGRADE_TYPE_GROUPS: Array[Dictionary] = [
	{"group": "Command", "types": ["COMMANDER", "OFFICER"]},
	{"group": "Teams", "types": ["WEAPONS_TEAM", "SUPPORT_TEAM"]},
	{"group": "Weapons", "types": ["ORDNANCE", "ION_CANNONS", "TURBOLASERS"]},
	{"group": "Retrofits", "types": ["DEFENSIVE_RETROFIT", "OFFENSIVE_RETROFIT"]},
	{"group": "Titles", "types": ["TITLE"]},
]
const RULE_STATUS_ORDER: Array[String] = [
	"INTEGRATED",
	"PARTIAL",
	"NOT_INTEGRATED",
]
const FACTION_ORDER: Array[Constants.Faction] = [
	Constants.Faction.REBEL_ALLIANCE,
	Constants.Faction.GALACTIC_EMPIRE,
	Constants.Faction.GALACTIC_REPUBLIC,
	Constants.Faction.SEPARATIST_ALLIANCE,
]


## Returns point-format choices supported by the local fleet-builder flow.
## Rules Reference: Fleet Building, recommended Core Set 180 and Standard 400.
static func available_point_formats() -> Array[Dictionary]:
	return [
		_point_format("Core Set 180", FORMAT_CORE_SET_180, CORE_SET_POINT_LIMIT),
		_point_format("Standard 400", FORMAT_STANDARD_400, FleetValidator.DEFAULT_POINT_LIMIT),
		_point_format("Custom 300", FORMAT_CUSTOM, CUSTOM_POINT_LIMIT),
	]


## Returns the default serialized point-format payload for a new local draft.
static func default_point_format() -> Dictionary:
	return _format_payload(FORMAT_CORE_SET_180, CORE_SET_POINT_LIMIT, "")


## Returns true when both payloads describe the same fleet match format.
## Ignores presentation-only fields such as custom labels.
static func point_formats_match(left: Dictionary, right: Dictionary) -> bool:
	var left_id: String = str(left.get("id", "")).strip_edges().to_upper()
	var right_id: String = str(right.get("id", "")).strip_edges().to_upper()
	var left_limit: int = int(left.get("limit", 0))
	var right_limit: int = int(right.get("limit", 0))
	if left_id.is_empty() or right_id.is_empty():
		return false
	return left_id == right_id and left_limit == right_limit


## Returns map choices allowed for the given point format.
## Rules Reference: "Play Area", RRG 1.5.0; "Setup Area", RRG 1.5.0.
static func available_maps_for_point_format(point_format: Dictionary) -> Array[Dictionary]:
	return available_maps(required_map_grid_for_point_format(point_format))


## Returns all discovered map choices, optionally filtered by 3x3 or 3x6 grid.
static func available_maps(required_grid: String = "") -> Array[Dictionary]:
	var maps: Array[Dictionary] = []
	for filename: String in AssetLoader.list_map_filenames():
		var grid: String = map_grid_for_filename(filename)
		if grid.is_empty():
			continue
		if not required_grid.is_empty() and grid != required_grid:
			continue
		maps.append(_map_payload(filename, grid))
	maps.sort_custom(_map_before)
	return maps


## Returns the default map payload for the point-format's required map size.
static func default_map_for_point_format(point_format: Dictionary) -> Dictionary:
	var required_grid: String = required_map_grid_for_point_format(point_format)
	var default_filename: String = _default_filename_for_grid(required_grid)
	var payload: Dictionary = map_payload(default_filename)
	if not payload.is_empty():
		return payload
	var maps: Array[Dictionary] = available_maps(required_grid)
	return maps[0].duplicate(true) if not maps.is_empty() else {}


## Returns the validated map payload for [param filename], or an empty dictionary.
static func map_payload(filename: String) -> Dictionary:
	var clean_filename: String = filename.strip_edges()
	var grid: String = map_grid_for_filename(clean_filename)
	if clean_filename.is_empty() or grid.is_empty():
		return {}
	if not AssetLoader.list_map_filenames().has(clean_filename):
		return {}
	return _map_payload(clean_filename, grid)


## Derives the map grid from the filename prefix.
static func map_grid_for_filename(filename: String) -> String:
	if filename.begins_with(MAP_PREFIX_3X3):
		return MAP_GRID_3X3
	if filename.begins_with(MAP_PREFIX_3X6):
		return MAP_GRID_3X6
	return ""


## Returns the required map grid for a point format, or empty for unknown custom limits.
static func required_map_grid_for_point_format(point_format: Dictionary) -> String:
	return required_map_grid_for_point_limit(int(point_format.get("limit", 0)))


## Returns the required map grid for point limits with explicit play-area rules.
static func required_map_grid_for_point_limit(point_limit: int) -> String:
	match point_limit:
		CORE_SET_POINT_LIMIT:
			return MAP_GRID_3X3
		CUSTOM_POINT_LIMIT, FleetValidator.DEFAULT_POINT_LIMIT:
			return MAP_GRID_3X6
		_:
			return ""


## Returns the default faction key for a new local draft.
static func default_faction(catalog: FleetCatalog = null) -> String:
	var factions: Array[String] = available_factions(catalog)
	if factions.is_empty():
		return _faction_name(Constants.Faction.REBEL_ALLIANCE)
	return factions[0]


## Returns faction keys currently represented by ship or squadron catalog data.
static func available_factions(catalog: FleetCatalog = null) -> Array[String]:
	var faction_set: Dictionary = {}
	var entries: Array[Dictionary] = _catalog_or_new(catalog).query_components({
		"component_types": [FleetCatalog.COMPONENT_SHIP, FleetCatalog.COMPONENT_SQUADRON],
	})
	for entry: Dictionary in entries:
		_add_entry_factions(faction_set, entry)
	return _sorted_faction_keys(faction_set)


## Returns objective categories in roster validation and display order.
static func objective_categories() -> Array[String]:
	return FleetObjectiveSelection.categories()


## Returns upgrade-type display groups containing only catalog-present types.
static func upgrade_type_groups(catalog: FleetCatalog = null) -> Array[Dictionary]:
	var available_types: Array[String] = _available_upgrade_types(catalog)
	var assigned_types: Dictionary = {}
	var groups: Array[Dictionary] = []
	for group: Dictionary in UPGRADE_TYPE_GROUPS:
		_add_upgrade_group(groups, assigned_types, group, available_types)
	_add_other_upgrade_group(groups, assigned_types, available_types)
	return groups


## Returns rule categories currently present in the rules-reference catalog.
static func rule_categories(catalog: FleetCatalog = null) -> Array[String]:
	return _distinct_rule_field(catalog, "rules_category")


## Returns implementation statuses currently present in rules-reference records.
static func rule_statuses(catalog: FleetCatalog = null) -> Array[String]:
	var statuses: Array[String] = _distinct_rule_field(catalog, "implementation_status")
	statuses.sort_custom(_status_before)
	return statuses


static func _point_format(label_text: String, id: String, limit: int) -> Dictionary:
	var payload: Dictionary = _format_payload(id, limit, "")
	payload["label"] = label_text
	return payload


static func _format_payload(id: String, limit: int, custom_label: String) -> Dictionary:
	return {"id": id, "limit": limit, "custom_label": custom_label}


static func _map_payload(filename: String, grid: String) -> Dictionary:
	return {"filename": filename, "grid": grid, "label": _map_label(filename, grid)}


static func _map_label(filename: String, grid: String) -> String:
	var stem: String = filename.get_basename()
	var prefix: String = "map_%s_" % grid
	var label_key: String = stem.substr(prefix.length()) if stem.begins_with(prefix) else stem
	var version_index: int = label_key.rfind("_v")
	if version_index >= 0:
		label_key = label_key.substr(0, version_index)
	return "%s %s" % [grid, _title_from_key(label_key)]


static func _title_from_key(value: String) -> String:
	var words: Array[String] = []
	for raw_word: String in value.replace("-", "_").split("_", false):
		words.append(raw_word.capitalize())
	return " ".join(words)


static func _default_filename_for_grid(grid: String) -> String:
	match grid:
		MAP_GRID_3X3:
			return DEFAULT_MAP_3X3
		MAP_GRID_3X6:
			return DEFAULT_MAP_3X6
		_:
			return DEFAULT_MAP_3X3


static func _map_before(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("label", "")) < str(right.get("label", ""))


static func _catalog_or_new(catalog: FleetCatalog) -> FleetCatalog:
	return FleetCatalog.new() if catalog == null else catalog


static func _add_entry_factions(faction_set: Dictionary, entry: Dictionary) -> void:
	for raw_faction: Variant in entry.get("factions", []):
		var faction: String = str(raw_faction)
		if not faction.is_empty():
			faction_set[faction] = true


static func _sorted_faction_keys(faction_set: Dictionary) -> Array[String]:
	var factions: Array[String] = []
	for raw_faction: Variant in faction_set.keys():
		factions.append(str(raw_faction))
	if factions.is_empty():
		factions.append(_faction_name(Constants.Faction.REBEL_ALLIANCE))
	factions.sort_custom(_faction_before)
	return factions


static func _available_upgrade_types(catalog: FleetCatalog) -> Array[String]:
	var type_set: Dictionary = {}
	var entries: Array[Dictionary] = _catalog_or_new(catalog).query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
	})
	for entry: Dictionary in entries:
		var upgrade_type: String = str(entry.get("upgrade_type", ""))
		if not upgrade_type.is_empty():
			type_set[upgrade_type] = true
	return _sorted_string_keys(type_set)


static func _add_upgrade_group(groups: Array[Dictionary], assigned_types: Dictionary,
		group: Dictionary, available_types: Array[String]) -> void:
	var group_types: Array[String] = []
	for raw_type: Variant in group.get("types", []):
		var upgrade_type: String = str(raw_type)
		if available_types.has(upgrade_type):
			group_types.append(upgrade_type)
			assigned_types[upgrade_type] = true
	if not group_types.is_empty():
		groups.append({"group": str(group.get("group", "")), "types": group_types})


static func _add_other_upgrade_group(groups: Array[Dictionary], assigned_types: Dictionary,
		available_types: Array[String]) -> void:
	var other_types: Array[String] = []
	for upgrade_type: String in available_types:
		if not assigned_types.has(upgrade_type):
			other_types.append(upgrade_type)
	if not other_types.is_empty():
		groups.append({"group": "Other", "types": other_types})


static func _distinct_rule_field(catalog: FleetCatalog, field_name: String) -> Array[String]:
	var value_set: Dictionary = {}
	var entries: Array[Dictionary] = _catalog_or_new(catalog).query_components({
		"component_types": [FleetCatalog.COMPONENT_RULE_REFERENCE],
	})
	for entry: Dictionary in entries:
		var value: String = str(entry.get(field_name, ""))
		if not value.is_empty():
			value_set[value] = true
	return _sorted_string_keys(value_set)


static func _sorted_string_keys(value_set: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for raw_value: Variant in value_set.keys():
		values.append(str(raw_value))
	values.sort()
	return values


static func _faction_before(left: String, right: String) -> bool:
	var left_index: int = _faction_order_index(left)
	var right_index: int = _faction_order_index(right)
	if left_index != right_index:
		return left_index < right_index
	return left < right


static func _status_before(left: String, right: String) -> bool:
	var left_index: int = _status_order_index(left)
	var right_index: int = _status_order_index(right)
	if left_index != right_index:
		return left_index < right_index
	return left < right


static func _status_order_index(value: String) -> int:
	var index: int = RULE_STATUS_ORDER.find(value)
	return RULE_STATUS_ORDER.size() if index < 0 else index


static func _faction_order_index(value: String) -> int:
	for index: int in range(FACTION_ORDER.size()):
		if _faction_name(FACTION_ORDER[index]) == value:
			return index
	return FACTION_ORDER.size()


static func _faction_name(faction: Constants.Faction) -> String:
	match faction:
		Constants.Faction.REBEL_ALLIANCE:
			return "REBEL_ALLIANCE"
		Constants.Faction.GALACTIC_EMPIRE:
			return "GALACTIC_EMPIRE"
		Constants.Faction.GALACTIC_REPUBLIC:
			return "GALACTIC_REPUBLIC"
		Constants.Faction.SEPARATIST_ALLIANCE:
			return "SEPARATIST_ALLIANCE"
		_:
			return ""
## Fleet Catalog
##
## Read-only query helper over static component catalog records.
## Provides deterministic filtering for fleet-builder UI and validator slices.
class_name FleetCatalog
extends RefCounted


const COMPONENT_SHIP: String = "SHIP"
const COMPONENT_SQUADRON: String = "SQUADRON"
const COMPONENT_UPGRADE: String = "UPGRADE"
const COMPONENT_OBJECTIVE: String = "OBJECTIVE"
const COMPONENT_OBSTACLE: String = "OBSTACLE"
const COMPONENT_RULE_REFERENCE: String = "RULE_REFERENCE"

const COMPONENT_TYPES: Array[String] = [
	COMPONENT_SHIP,
	COMPONENT_SQUADRON,
	COMPONENT_UPGRADE,
	COMPONENT_OBJECTIVE,
	COMPONENT_OBSTACLE,
	COMPONENT_RULE_REFERENCE,
]

var _component_entries: Array[Dictionary] = []
var _rules_by_id: Dictionary = {}
var _is_loaded: bool = false


## Returns catalog entries matching [param filters], sorted deterministically.
## Filters: component_types, faction, min_point_cost, max_point_cost,
## upgrade_type, wave, expansion, keyword, rules_category,
## implementation_status, text, and tag.
func query_components(filters: Dictionary = {}) -> Array[Dictionary]:
	_ensure_loaded()
	var results: Array[Dictionary] = []
	for entry: Dictionary in _component_entries:
		if _matches_filters(entry, filters):
			results.append(_copy_entry(entry))
	results.sort_custom(_entry_before)
	return results


## Returns rule-reference records linked from a component entry.
## When [param include_generic] is false, only COMPONENT_SPECIFIC rules remain.
func get_rules_for_component(component_entry: Dictionary,
		include_generic: bool = true) -> Array[RuleReferenceData]:
	_ensure_loaded()
	var result: Array[RuleReferenceData] = []
	for raw_id: Variant in component_entry.get("rules_reference_ids", []):
		var rule: RuleReferenceData = _rules_by_id.get(str(raw_id), null)
		if rule == null:
			continue
		if not include_generic and rule.scope == "GENERIC":
			continue
		result.append(rule)
	result.sort_custom(_rule_before)
	return result


## Returns all rule references in [param category], optionally by status.
func get_rules_by_category(category: String,
		implementation_status: String = "") -> Array[RuleReferenceData]:
	_ensure_loaded()
	var needle_category: String = category.to_upper()
	var needle_status: String = implementation_status.to_upper()
	var results: Array[RuleReferenceData] = []
	for rule: RuleReferenceData in _rules_by_id.values():
		if not _matches_rule_category(rule, needle_category):
			continue
		if not _matches_rule_status(rule, needle_status):
			continue
		results.append(rule)
	results.sort_custom(_rule_before)
	return results


func _ensure_loaded() -> void:
	if _is_loaded:
		return
	_component_entries.clear()
	_rules_by_id.clear()
	_load_rule_entries()
	_load_ship_entries()
	_load_squadron_entries()
	_load_upgrade_entries()
	_load_objective_entries()
	_load_obstacle_entries()
	_is_loaded = true


func _matches_filters(entry: Dictionary, filters: Dictionary) -> bool:
	return _matches_component_type(entry, filters) \
			and _matches_faction(entry, filters) \
			and _matches_point_cost(entry, filters) \
			and _matches_upgrade_type(entry, filters) \
			and _matches_wave(entry, filters) \
			and _matches_expansion(entry, filters) \
			and _matches_keyword(entry, filters) \
			and _matches_rules_category(entry, filters) \
			and _matches_implementation_status(entry, filters) \
			and _matches_text(entry, filters) \
			and _matches_tag(entry, filters)


func _matches_component_type(entry: Dictionary, filters: Dictionary) -> bool:
	var raw_types: Variant = filters.get("component_types", [])
	if not raw_types is Array or (raw_types as Array).is_empty():
		return true
	for raw_type: Variant in raw_types as Array:
		if entry.get("component_type", "") == str(raw_type).to_upper():
			return true
	return false


func _matches_faction(entry: Dictionary, filters: Dictionary) -> bool:
	var faction: String = str(filters.get("faction", "")).to_upper()
	if faction.is_empty():
		return true
	var factions: Array = entry.get("factions", [])
	if factions.is_empty():
		return _unrestricted_component_matches_faction(str(entry.get("component_type", "")))
	for raw_faction: Variant in factions:
		if str(raw_faction).to_upper() == faction:
			return true
	return false


func _matches_point_cost(entry: Dictionary, filters: Dictionary) -> bool:
	var min_points: int = int(filters.get("min_point_cost", -1))
	var max_points: int = int(filters.get("max_point_cost", -1))
	var points: int = int(entry.get("point_cost", -1))
	if min_points >= 0 and (points < 0 or points < min_points):
		return false
	if max_points >= 0 and (points < 0 or points > max_points):
		return false
	return true


func _matches_upgrade_type(entry: Dictionary, filters: Dictionary) -> bool:
	var upgrade_type: String = str(filters.get("upgrade_type", "")).to_upper()
	if upgrade_type.is_empty():
		return true
	return str(entry.get("upgrade_type", "")).to_upper() == upgrade_type


func _matches_wave(entry: Dictionary, filters: Dictionary) -> bool:
	if not filters.has("wave"):
		return true
	return int(entry.get("wave", -1)) == int(filters.get("wave", -2))


func _matches_expansion(entry: Dictionary, filters: Dictionary) -> bool:
	var expansion: String = str(filters.get("expansion", "")).to_lower()
	if expansion.is_empty():
		return true
	return str(entry.get("expansion", "")).to_lower() == expansion


func _matches_keyword(entry: Dictionary, filters: Dictionary) -> bool:
	var keyword: String = str(filters.get("keyword", "")).to_lower()
	if keyword.is_empty():
		return true
	var keywords: Array = entry.get("keywords", [])
	for raw_keyword: Variant in keywords:
		if str(raw_keyword).to_lower() == keyword:
			return true
	return false


func _matches_rules_category(entry: Dictionary, filters: Dictionary) -> bool:
	var category: String = str(filters.get("rules_category", "")).to_upper()
	if category.is_empty():
		return true
	if str(entry.get("component_type", "")) == COMPONENT_RULE_REFERENCE:
		return str(entry.get("rules_category", "")).to_upper() == category
	for rule_id: Variant in entry.get("rules_reference_ids", []):
		var rule: RuleReferenceData = _rules_by_id.get(str(rule_id), null)
		if rule != null and str(rule.category).to_upper() == category:
			return true
	return false


func _matches_implementation_status(entry: Dictionary, filters: Dictionary) -> bool:
	var status: String = str(filters.get("implementation_status", "")).to_upper()
	if status.is_empty():
		return true
	if str(entry.get("component_type", "")) == COMPONENT_RULE_REFERENCE:
		return str(entry.get("implementation_status", "")).to_upper() == status
	return str(entry.get("rules_integration_status", "")).to_upper() == status


func _matches_text(entry: Dictionary, filters: Dictionary) -> bool:
	var text: String = str(filters.get("text", "")).strip_edges().to_lower()
	if text.is_empty():
		return true
	var blob: String = str(entry.get("search_blob", "")).to_lower()
	return blob.contains(text)


func _matches_tag(entry: Dictionary, filters: Dictionary) -> bool:
	var tag: String = str(filters.get("tag", "")).to_lower()
	if tag.is_empty():
		return true
	for raw_tag: Variant in entry.get("search_tags", []):
		if str(raw_tag).to_lower() == tag:
			return true
	return false


func _load_rule_entries() -> void:
	for key: String in AssetLoader.list_rule_reference_keys():
		var data: RuleReferenceData = AssetLoader.load_rule_reference_data(key)
		if data == null:
			continue
		_rules_by_id[data.data_key] = data
		_component_entries.append(_rule_entry_from_data(data))


func _load_ship_entries() -> void:
	for key: String in AssetLoader.list_ship_keys():
		var record: Dictionary = _load_catalog_record(AssetLoader.SHIP_FOLDER, key, false)
		var data: ShipData = AssetLoader.load_ship_data(key)
		if data != null:
			_component_entries.append(_ship_entry_from_data(key, record, data))


func _load_squadron_entries() -> void:
	for key: String in AssetLoader.list_squadron_keys():
		var record: Dictionary = _load_catalog_record(AssetLoader.SQUADRON_FOLDER, key, false)
		var data: SquadronData = AssetLoader.load_squadron_data(key)
		if data != null:
			_component_entries.append(_squadron_entry_from_data(key, record, data))


func _load_upgrade_entries() -> void:
	for key: String in AssetLoader.list_upgrade_keys():
		var data: UpgradeData = AssetLoader.load_upgrade_data(key)
		if data != null:
			_component_entries.append(_upgrade_entry_from_data(data))


func _load_objective_entries() -> void:
	for key: String in AssetLoader.list_objective_keys():
		var data: ObjectiveData = AssetLoader.load_objective_data(key)
		if data != null:
			_component_entries.append(_objective_entry_from_data(data))


func _load_obstacle_entries() -> void:
	for key: String in AssetLoader.list_obstacle_keys():
		var data: ObstacleData = AssetLoader.load_obstacle_data(key)
		if data != null:
			_component_entries.append(_obstacle_entry_from_data(data))


func _ship_entry_from_data(key: String, record: Dictionary, data: ShipData) -> Dictionary:
	var search_tags: Array = record.get("search_tags", [])
	return _create_entry({
		"component_type": COMPONENT_SHIP,
		"data_key": key,
		"display_name": data.ship_name,
		"faction": _faction_to_string(data.faction),
		"factions": [_faction_to_string(data.faction)],
		"point_cost": data.point_cost,
		"wave": int(record.get("wave", -1)),
		"expansion": str(record.get("expansion", "")),
		"keywords": [],
		"upgrade_type": "",
		"rules_category": "",
		"rules_reference_ids": record.get("rules_reference_ids", []),
		"rules_integration_status": _rules_status(record),
		"implementation_status": "",
		"search_tags": search_tags,
		"summary_text": str(record.get("class_specifics", "")),
		"resource": data,
	})


func _squadron_entry_from_data(key: String,
		record: Dictionary, data: SquadronData) -> Dictionary:
	var keywords: Array[String] = _extract_squadron_keywords(data)
	var search_tags: Array = record.get("search_tags", [])
	return _create_entry({
		"component_type": COMPONENT_SQUADRON,
		"data_key": key,
		"display_name": data.squadron_name,
		"faction": _faction_to_string(data.faction),
		"factions": [_faction_to_string(data.faction)],
		"point_cost": data.point_cost,
		"wave": int(record.get("wave", -1)),
		"expansion": str(record.get("expansion", "")),
		"keywords": keywords,
		"upgrade_type": "",
		"rules_category": "",
		"rules_reference_ids": record.get("rules_reference_ids", []),
		"rules_integration_status": _rules_status(record),
		"implementation_status": "",
		"search_tags": search_tags,
		"summary_text": data.ability_text,
		"resource": data,
	})


func _upgrade_entry_from_data(data: UpgradeData) -> Dictionary:
	return _create_entry({
		"component_type": COMPONENT_UPGRADE,
		"data_key": data.data_key,
		"display_name": data.upgrade_name,
		"faction": _faction_restriction_to_string(data.faction_restriction),
		"factions": _faction_restrictions_to_strings(data.faction_restriction),
		"point_cost": data.point_cost,
		"wave": data.wave,
		"expansion": data.expansion,
		"keywords": [],
		"upgrade_type": data.upgrade_type,
		"rules_category": "",
		"rules_reference_ids": data.rules_reference_ids,
		"rules_integration_status": str(data.rules_integration.get("status", "NOT_INTEGRATED")),
		"implementation_status": "",
		"search_tags": data.search_tags,
		"summary_text": data.effect_text,
		"resource": data,
	})


func _objective_entry_from_data(data: ObjectiveData) -> Dictionary:
	var summary: String = "%s %s" % [data.setup_text, data.special_rule_text]
	return _create_entry({
		"component_type": COMPONENT_OBJECTIVE,
		"data_key": data.data_key,
		"display_name": data.objective_name,
		"faction": "",
		"factions": [],
		"point_cost": -1,
		"wave": data.wave,
		"expansion": data.expansion,
		"keywords": [data.category],
		"upgrade_type": "",
		"rules_category": "",
		"rules_reference_ids": data.rules_reference_ids,
		"rules_integration_status": str(data.rules_integration.get("status", "NOT_INTEGRATED")),
		"implementation_status": "",
		"search_tags": data.search_tags,
		"summary_text": summary,
		"resource": data,
	})


func _obstacle_entry_from_data(data: ObstacleData) -> Dictionary:
	return _create_entry({
		"component_type": COMPONENT_OBSTACLE,
		"data_key": data.data_key,
		"display_name": data.obstacle_name,
		"faction": "",
		"factions": [],
		"point_cost": -1,
		"wave": data.wave,
		"expansion": data.expansion,
		"keywords": [data.obstacle_type],
		"upgrade_type": "",
		"rules_category": "",
		"rules_reference_ids": data.rules_reference_ids,
		"rules_integration_status": str(data.rules_integration.get("status", "NOT_INTEGRATED")),
		"implementation_status": "",
		"search_tags": data.search_tags,
		"summary_text": "",
		"resource": data,
	})


func _rule_entry_from_data(data: RuleReferenceData) -> Dictionary:
	return _create_entry({
		"component_type": COMPONENT_RULE_REFERENCE,
		"data_key": data.data_key,
		"display_name": data.display_name,
		"faction": "",
		"factions": [],
		"point_cost": -1,
		"wave": -1,
		"expansion": "",
		"keywords": [data.scope],
		"upgrade_type": "",
		"rules_category": data.category,
		"rules_reference_ids": [data.data_key],
		"rules_integration_status": "",
		"implementation_status": data.implementation_status,
		"search_tags": data.search_tags,
		"summary_text": "%s %s" % [data.summary, data.rules_text],
		"resource": data,
	})


func _create_entry(fields: Dictionary) -> Dictionary:
	var search_tags: Array[String] = []
	for raw_tag: Variant in fields.get("search_tags", []):
		search_tags.append(str(raw_tag))
	var keywords: Array[String] = []
	for raw_keyword: Variant in fields.get("keywords", []):
		keywords.append(str(raw_keyword))
	var factions: Array[String] = []
	for raw_faction: Variant in fields.get("factions", []):
		factions.append(str(raw_faction))
	var blob_parts: Array[String] = [
		str(fields.get("data_key", "")),
		str(fields.get("display_name", "")),
		str(fields.get("summary_text", "")),
	]
	blob_parts.append_array(search_tags)
	blob_parts.append_array(keywords)
	blob_parts.append_array(factions)
	fields["search_tags"] = search_tags
	fields["keywords"] = keywords
	fields["factions"] = factions
	fields["search_blob"] = " ".join(blob_parts).strip_edges()
	return fields


func _load_catalog_record(subfolder: String, key: String, recursive: bool) -> Dictionary:
	for relative_path: String in _list_json_paths(subfolder, recursive):
		var data: Dictionary = AssetLoader.load_json("", relative_path)
		if data.is_empty():
			continue
		if str(data.get("data_key", "")) == key:
			return data
		if relative_path.get_file().get_basename() == key:
			return data
	return {}


func _list_json_paths(subfolder: String, recursive: bool) -> Array[String]:
	var paths: Array[String] = []
	_collect_json_paths(subfolder, recursive, paths)
	paths.sort()
	return paths


func _collect_json_paths(subfolder: String,
		recursive: bool, paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(AssetLoader.BASE_PATH + subfolder)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		_collect_json_entry(dir, subfolder, entry_name, recursive, paths)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _collect_json_entry(dir: DirAccess, subfolder: String,
		entry_name: String, recursive: bool, paths: Array[String]) -> void:
	if entry_name.begins_with("."):
		return
	var relative_path: String = subfolder + entry_name
	if dir.current_is_dir():
		if recursive:
			_collect_json_paths(relative_path + "/", recursive, paths)
	elif entry_name.ends_with(".json"):
		paths.append(relative_path)


static func _entry_before(left: Dictionary, right: Dictionary) -> bool:
	var left_type: String = str(left.get("component_type", ""))
	var right_type: String = str(right.get("component_type", ""))
	if left_type != right_type:
		return left_type < right_type
	return str(left.get("data_key", "")) < str(right.get("data_key", ""))


static func _rule_before(left: RuleReferenceData, right: RuleReferenceData) -> bool:
	return left.data_key < right.data_key


static func _faction_to_string(faction: Constants.Faction) -> String:
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


static func _extract_squadron_keywords(data: SquadronData) -> Array[String]:
	var keywords: Array[String] = []
	for keyword_data: Dictionary in data.keywords:
		keywords.append(str(keyword_data.get("name", "")))
	return keywords


static func _faction_restriction_to_string(factions: Array) -> String:
	if factions.is_empty():
		return ""
	return _faction_to_string(factions[0] as Constants.Faction)


static func _faction_restrictions_to_strings(factions: Array) -> Array[String]:
	var result: Array[String] = []
	for faction: Variant in factions:
		result.append(_faction_to_string(faction as Constants.Faction))
	return result


static func _unrestricted_component_matches_faction(component_type: String) -> bool:
	return component_type == COMPONENT_UPGRADE \
			or component_type == COMPONENT_OBJECTIVE \
			or component_type == COMPONENT_OBSTACLE \
			or component_type == COMPONENT_RULE_REFERENCE


static func _rules_status(record: Dictionary) -> String:
	var integration: Dictionary = record.get("rules_integration", {})
	return str(integration.get("status", "NOT_INTEGRATED"))


static func _copy_entry(entry: Dictionary) -> Dictionary:
	var copy: Dictionary = entry.duplicate(true)
	copy["resource"] = entry.get("resource", null)
	return copy


static func _matches_rule_category(rule: RuleReferenceData, category: String) -> bool:
	if category.is_empty():
		return true
	return str(rule.category).to_upper() == category


static func _matches_rule_status(rule: RuleReferenceData, status: String) -> bool:
	if status.is_empty():
		return true
	return str(rule.implementation_status).to_upper() == status

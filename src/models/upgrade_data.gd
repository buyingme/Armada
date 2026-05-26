## Upgrade Data
##
## Resource that defines the static data for an upgrade card.
class_name UpgradeData
extends Resource


## Stable catalog key for this upgrade.
@export var data_key: String = ""

## Static record kind from the component catalog.
@export var kind: String = "upgrade_card"

## The display name of the upgrade.
@export var upgrade_name: String = ""

## The upgrade type/slot, such as COMMANDER, TITLE, or OFFICER.
@export var upgrade_type: String = ""

## The point cost of this upgrade.
@export var point_cost: int = 0

## Armada release wave. Core Set content is wave 0.
@export var wave: int = 0

## Source expansion or product key.
@export var expansion: String = ""

## Product keys that contain this upgrade.
@export var available_through: Array[String] = []

## Card art filename in the upgrade folder.
@export var card_image: String = ""

## Whether this is a unique upgrade.
@export var is_unique: bool = false

## Unique-name group used by fleet validation.
@export var unique_group: String = ""

## The faction restriction, if any. Empty means any faction.
@export var faction_restriction: Array = []

## The ship size restriction, if any. Empty means any size.
@export var size_restriction: Array = []

## Ship class restriction keys. Empty means any ship class.
@export var ship_class_restriction: Array[String] = []

## Ship data key restrictions. Empty means any ship of the matching slot.
@export var ship_data_key_restriction: Array[String] = []

## The text description of the upgrade's effect.
@export var effect_text: String = ""

## Timing notes from local source records.
@export var timing_notes: Array = []

## Errata notes from local source records.
@export var errata: Array = []

## Clarification notes from local source records.
@export var clarifications: Array = []

## Whether this upgrade can be exhausted.
@export var is_exhaustible: bool = false

## Modification flag for upgrades that use the Modification restriction.
@export var is_modification: bool = false

## Linked rules-reference record ids.
@export var rules_reference_ids: Array[String] = []

## RuleRegistry implementation status metadata.
@export var rules_integration: Dictionary = {}

## Rule hook surface metadata used by future integration slices.
@export var rule_surfaces: Array[Dictionary] = []

## Runtime state needs once this upgrade's gameplay rule is implemented.
@export var runtime_state_requirements: Array[String] = []

## Search/filter tags for the fleet builder catalog.
@export var search_tags: Array[String] = []

## Local source references used to verify this record.
@export var source_refs: Array[String] = []


## Creates UpgradeData from the static component catalog JSON shape.
## Rules Reference: Resources/Game_Components/card_data_schema.json
static func from_dict(data: Dictionary) -> UpgradeData:
	var upgrade_data: UpgradeData = UpgradeData.new()
	upgrade_data._load_identity(data)
	upgrade_data._load_restrictions(data)
	upgrade_data._load_rules_metadata(data)
	upgrade_data.effect_text = str(data.get("effect_text", ""))
	upgrade_data.timing_notes = data.get("timing_notes", [])
	upgrade_data.errata = data.get("errata", [])
	upgrade_data.clarifications = data.get("clarifications", [])
	upgrade_data.is_exhaustible = bool(data.get("is_exhaustible", false))
	upgrade_data.is_modification = bool(data.get("is_modification", false))
	return upgrade_data


func _load_identity(data: Dictionary) -> void:
	data_key = str(data.get("data_key", ""))
	kind = str(data.get("kind", "upgrade_card"))
	upgrade_name = str(data.get("upgrade_name", ""))
	upgrade_type = str(data.get("upgrade_type", ""))
	point_cost = int(data.get("point_cost", 0))
	wave = int(data.get("wave", 0))
	expansion = str(data.get("expansion", ""))
	available_through.assign(data.get("available_through", []))
	card_image = str(data.get("card_image", ""))
	is_unique = bool(data.get("is_unique", false))
	unique_group = str(data.get("unique_group", ""))


func _load_restrictions(data: Dictionary) -> void:
	faction_restriction = _parse_faction_array(data.get("faction_restriction", []))
	size_restriction = _parse_ship_size_array(data.get("size_restriction", []))
	ship_class_restriction.assign(data.get("ship_class_restriction", []))
	ship_data_key_restriction.assign(data.get("ship_data_key_restriction", []))


func _load_rules_metadata(data: Dictionary) -> void:
	rules_reference_ids.assign(data.get("rules_reference_ids", []))
	rules_integration = data.get("rules_integration", {})
	rule_surfaces.assign(data.get("rule_surfaces", []))
	runtime_state_requirements.assign(data.get("runtime_state_requirements", []))
	search_tags.assign(data.get("search_tags", []))
	source_refs.assign(data.get("source_refs", []))


static func _parse_faction_array(values: Array) -> Array:
	var result: Array = []
	for raw_value: Variant in values:
		result.append(_parse_faction(str(raw_value)))
	return result


static func _parse_ship_size_array(values: Array) -> Array:
	var result: Array = []
	for raw_value: Variant in values:
		result.append(_parse_ship_size(str(raw_value)))
	return result


static func _parse_faction(value: String) -> Constants.Faction:
	match value.to_upper():
		"REBEL_ALLIANCE":
			return Constants.Faction.REBEL_ALLIANCE
		"GALACTIC_EMPIRE":
			return Constants.Faction.GALACTIC_EMPIRE
		"GALACTIC_REPUBLIC":
			return Constants.Faction.GALACTIC_REPUBLIC
		"SEPARATIST_ALLIANCE":
			return Constants.Faction.SEPARATIST_ALLIANCE
		_:
			push_error("UpgradeData: unknown faction '%s'" % value)
			return Constants.Faction.REBEL_ALLIANCE


static func _parse_ship_size(value: String) -> Constants.ShipSize:
	match value.to_upper():
		"SMALL":
			return Constants.ShipSize.SMALL
		"MEDIUM":
			return Constants.ShipSize.MEDIUM
		"LARGE":
			return Constants.ShipSize.LARGE
		_:
			push_error("UpgradeData: unknown ship size '%s'" % value)
			return Constants.ShipSize.SMALL

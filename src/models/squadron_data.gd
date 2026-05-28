## Squadron Data
##
## Resource that defines the static data for a squadron type.
## Keywords are stored as structured dictionaries: {"name": String, "value": int (optional)}
## This allows keywords with numeric values (Counter 2, Snipe 3) to be handled generically.
class_name SquadronData
extends Resource


## Stable catalog key for this squadron.
@export var data_key: String = ""

## Static record kind from the component catalog.
@export var kind: String = "squadron_card"

## Armada release wave. Core Set content is wave 0.
@export var wave: int = 0

## Source expansion or product key.
@export var expansion: String = ""

## Product keys that contain this squadron.
@export var available_through: Array[String] = []

## Card art filename in squadrons/.
@export var card_image: String = ""

## Token art filename in squadrons/.
@export var token_image: String = ""

## Local text source path for this squadron's extracted rules/card facts.
@export var rules_source: String = ""

## Squadron family key shared by generic and ace variants.
@export var squadron_family: String = ""

## Known ace variant keys for catalog browsing.
@export var ace_variants: Array[String] = []

## Linked rules-reference record ids.
@export var rules_reference_ids: Array[String] = []

## RuleRegistry implementation status metadata.
@export var rules_integration: Dictionary = {}

## Rule hook surface metadata used by future integration slices.
@export var rule_surfaces: Array[Dictionary] = []

## Runtime state needs once this squadron's gameplay rule is implemented.
@export var runtime_state_requirements: Array[String] = []

## Search/filter tags for the fleet builder catalog.
@export var search_tags: Array[String] = []

## Local source references used to verify this record.
@export var source_refs: Array[String] = []

## The display name of the squadron.
@export var squadron_name: String = ""

## The faction this squadron belongs to.
@export var faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE

## The point cost of this squadron.
@export var point_cost: int = 0

## The hull value.
@export var hull: int = 0

## The speed value.
@export var speed: int = 0

## Anti-squadron armament: {DiceColor: int}
@export var anti_squadron_armament: Dictionary = {}

## Battery armament (for attacking ships): {DiceColor: int}
@export var battery_armament: Dictionary = {}

## Keyword abilities as structured data.
## Each entry: {"name": "Bomber"} or {"name": "Counter", "value": 2}
@export var keywords: Array[Dictionary] = []

## Reminder text for each keyword, keyed by keyword name.
## Displayed to the player on the in-game card view.
@export var keyword_reminder_text: Dictionary = {}

## Special ability text for unique squadrons (beyond standard keywords).
## Empty string for generic squadrons.
@export var ability_text: String = ""

## Whether this is a unique (named) squadron.
@export var is_unique: bool = false

## Unique-name group used by fleet-building validation.
@export var unique_group: String = ""

## The defense tokens available (for unique squadrons).
@export var defense_tokens: Array = []


## --- Helper Methods ---

## Returns true if this squadron has the given keyword.
func has_keyword(keyword_name: String) -> bool:
	for kw: Dictionary in keywords:
		if kw.get("name", "") == keyword_name:
			return true
	return false


## Returns the numeric value of a keyword, or 0 if not found / no value.
func get_keyword_value(keyword_name: String) -> int:
	for kw: Dictionary in keywords:
		if kw.get("name", "") == keyword_name:
			return kw.get("value", 0) as int
	return 0


## Creates a SquadronData from a raw JSON dictionary keyed by the field names in
## card_data_schema.json. The faction string ("REBEL_ALLIANCE", etc.) is parsed
## into its typed enum equivalent.
## Rules Reference: Resources/Game_Components/card_data_schema.json
static func from_dict(data: Dictionary) -> SquadronData:
	var s: SquadronData = SquadronData.new()
	s._load_catalog_metadata(data)
	s.squadron_name = data.get("squadron_name", "")
	s.faction = _parse_faction(data.get("faction", "REBEL_ALLIANCE"))
	s.point_cost = int(data.get("point_cost", 0))
	s.hull = int(data.get("hull", 0))
	s.speed = int(data.get("speed", 0))
	s.anti_squadron_armament = data.get("anti_squadron_armament", {})
	s.battery_armament = data.get("battery_armament", {})
	var raw_kw: Array = data.get("keywords", [])
	s.keywords.assign(raw_kw)
	s.keyword_reminder_text = data.get("keyword_reminder_text", {})
	s.ability_text = data.get("ability_text", "")
	s.is_unique = bool(data.get("is_unique", false))
	s.unique_group = str(data.get("unique_group", ""))
	s.defense_tokens = data.get("defense_tokens", [])
	return s


func _load_catalog_metadata(data: Dictionary) -> void:
	data_key = str(data.get("data_key", ""))
	kind = str(data.get("kind", "squadron_card"))
	wave = int(data.get("wave", 0))
	expansion = str(data.get("expansion", ""))
	available_through.assign(data.get("available_through", []))
	card_image = str(data.get("card_image", ""))
	token_image = str(data.get("token_image", ""))
	rules_source = str(data.get("rules_source", ""))
	squadron_family = str(data.get("squadron_family", ""))
	ace_variants.assign(data.get("ace_variants", []))
	rules_reference_ids.assign(data.get("rules_reference_ids", []))
	rules_integration = data.get("rules_integration", {})
	rule_surfaces.assign(data.get("rule_surfaces", []))
	runtime_state_requirements.assign(data.get("runtime_state_requirements", []))
	search_tags.assign(data.get("search_tags", []))
	source_refs.assign(data.get("source_refs", []))


## Parses a faction JSON string into the Faction enum.
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
			push_error("SquadronData: unknown faction '%s' — defaulting to REBEL_ALLIANCE" % value)
			return Constants.Faction.REBEL_ALLIANCE

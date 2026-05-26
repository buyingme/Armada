## Objective Data
##
## Resource that defines static catalog data for an objective card.
class_name ObjectiveData
extends Resource


## Stable catalog key for this objective.
@export var data_key: String = ""

## Static record kind from the component catalog.
@export var kind: String = "objective_card"

## Objective display name.
@export var objective_name: String = ""

## Objective category: ASSAULT, DEFENSE, or NAVIGATION.
@export var category: String = ""

## Armada release wave. Core Set content is wave 0.
@export var wave: int = 0

## Source expansion or product key.
@export var expansion: String = ""

## Product keys that contain this objective.
@export var available_through: Array[String] = []

## Card art filename in objectives/.
@export var card_image: String = ""

## Optional alternate image filenames.
@export var alternate_images: Array[String] = []

## Victory token value, or null when the card has no fixed value.
var victory_token_points: Variant = null

## Whether this objective is suitable for Core Set task-force play.
@export var task_force_recommended: bool = false

## Setup text from the objective card/source note.
@export var setup_text: String = ""

## Special rule text from the objective card/source note.
@export var special_rule_text: String = ""

## End-of-round scoring text.
@export var end_of_round_text: String = ""

## End-of-game scoring text.
@export var end_of_game_text: String = ""

## Timing notes from local source records.
@export var timing_notes: Array = []

## Errata notes from local source records.
@export var errata: Array = []

## Clarification notes from local source records.
@export var clarifications: Array = []

## JSON-safe setup effect descriptors for future setup slices.
@export var setup_effects: Array[Dictionary] = []

## Linked rules-reference record ids.
@export var rules_reference_ids: Array[String] = []

## RuleRegistry implementation status metadata.
@export var rules_integration: Dictionary = {}

## Rule hook surface metadata used by future integration slices.
@export var rule_surfaces: Array[Dictionary] = []

## Objective token metadata.
@export var objective_tokens: Dictionary = {}

## Runtime state needs once this objective's gameplay rule is implemented.
@export var runtime_state_requirements: Array[String] = []

## Search/filter tags for the fleet builder catalog.
@export var search_tags: Array[String] = []

## Local source references used to verify this record.
@export var source_refs: Array[String] = []


## Creates ObjectiveData from the static component catalog JSON shape.
## Rules Reference: Resources/Game_Components/card_data_schema.json
static func from_dict(data: Dictionary) -> ObjectiveData:
	var objective_data: ObjectiveData = ObjectiveData.new()
	objective_data._load_identity(data)
	objective_data._load_text(data)
	objective_data._load_rules_metadata(data)
	objective_data.victory_token_points = data.get("victory_token_points", null)
	objective_data.task_force_recommended = bool(data.get("task_force_recommended", false))
	objective_data.objective_tokens = data.get("objective_tokens", {})
	objective_data.setup_effects.assign(data.get("setup_effects", []))
	return objective_data


func _load_identity(data: Dictionary) -> void:
	data_key = str(data.get("data_key", ""))
	kind = str(data.get("kind", "objective_card"))
	objective_name = str(data.get("objective_name", ""))
	category = str(data.get("category", ""))
	wave = int(data.get("wave", 0))
	expansion = str(data.get("expansion", ""))
	available_through.assign(data.get("available_through", []))
	card_image = str(data.get("card_image", ""))
	alternate_images.assign(data.get("alternate_images", []))


func _load_text(data: Dictionary) -> void:
	setup_text = str(data.get("setup_text", ""))
	special_rule_text = str(data.get("special_rule_text", ""))
	end_of_round_text = str(data.get("end_of_round_text", ""))
	end_of_game_text = str(data.get("end_of_game_text", ""))
	timing_notes = data.get("timing_notes", [])
	errata = data.get("errata", [])
	clarifications = data.get("clarifications", [])


func _load_rules_metadata(data: Dictionary) -> void:
	rules_reference_ids.assign(data.get("rules_reference_ids", []))
	rules_integration = data.get("rules_integration", {})
	rule_surfaces.assign(data.get("rule_surfaces", []))
	runtime_state_requirements.assign(data.get("runtime_state_requirements", []))
	search_tags.assign(data.get("search_tags", []))
	source_refs.assign(data.get("source_refs", []))

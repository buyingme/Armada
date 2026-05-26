## Obstacle Data
##
## Resource that defines static catalog data for an obstacle or setup token.
class_name ObstacleData
extends Resource


## Stable catalog key for this obstacle.
@export var data_key: String = ""

## Static record kind from the component catalog.
@export var kind: String = "obstacle_component"

## Obstacle display name.
@export var obstacle_name: String = ""

## Obstacle type, such as ASTEROID, DEBRIS, STATION, or OBJECTIVE_TOKEN.
@export var obstacle_type: String = ""

## Token art filename in obstacles/.
@export var token_image: String = ""

## Armada release wave. Core Set content is wave 0.
@export var wave: int = 0

## Source expansion or product key.
@export var expansion: String = ""

## Product keys that contain this obstacle.
@export var available_through: Array[String] = []

## Setup placement constraints expressed as schema strings.
@export var setup_constraints: Array[String] = []

## Future shape metadata for deployment and overlap validators.
@export var shape_metadata: Dictionary = {}

## Linked rules-reference record ids.
@export var rules_reference_ids: Array[String] = []

## RuleRegistry implementation status metadata.
@export var rules_integration: Dictionary = {}

## Search/filter tags for the fleet builder catalog.
@export var search_tags: Array[String] = []

## Local source references used to verify this record.
@export var source_refs: Array[String] = []


## Creates ObstacleData from the static component catalog JSON shape.
## Rules Reference: Resources/Game_Components/card_data_schema.json
static func from_dict(data: Dictionary) -> ObstacleData:
	var obstacle_data: ObstacleData = ObstacleData.new()
	obstacle_data.data_key = str(data.get("data_key", ""))
	obstacle_data.kind = str(data.get("kind", "obstacle_component"))
	obstacle_data.obstacle_name = str(data.get("obstacle_name", ""))
	obstacle_data.obstacle_type = str(data.get("obstacle_type", ""))
	obstacle_data.token_image = str(data.get("token_image", ""))
	obstacle_data.wave = int(data.get("wave", 0))
	obstacle_data.expansion = str(data.get("expansion", ""))
	obstacle_data.available_through.assign(data.get("available_through", []))
	obstacle_data.setup_constraints.assign(data.get("setup_constraints", []))
	obstacle_data.shape_metadata = data.get("shape_metadata", {})
	obstacle_data._load_metadata(data)
	return obstacle_data


func _load_metadata(data: Dictionary) -> void:
	rules_reference_ids.assign(data.get("rules_reference_ids", []))
	rules_integration = data.get("rules_integration", {})
	search_tags.assign(data.get("search_tags", []))
	source_refs.assign(data.get("source_refs", []))

## Rule Reference Data
##
## Resource that defines static display/search metadata for a rules reference.
class_name RuleReferenceData
extends Resource


## Stable catalog key for this rules reference.
@export var data_key: String = ""

## Static record kind from the component catalog.
@export var kind: String = "rules_reference"

## Rule scope: GENERIC or COMPONENT_SPECIFIC.
@export var scope: String = ""

## Display name for the rule reference.
@export var display_name: String = ""

## Rule category, such as SQUADRON_KEYWORD.
@export var category: String = ""

## Full local rules text used by the fleet-builder rules browser.
@export var rules_text: String = ""

## Short display/search summary.
@export var summary: String = ""

## Search/filter tags for the fleet builder catalog.
@export var search_tags: Array[String] = []

## Local source references used to verify this record.
@export var source_refs: Array[String] = []

## Matching RuleRegistry ids for live implementations.
@export var implemented_rule_ids: Array[String] = []

## Implementation status shown in the rules browser.
@export var implementation_status: String = "NOT_INTEGRATED"


## Creates RuleReferenceData from the static component catalog JSON shape.
## Rules Reference: Resources/Game_Components/card_data_schema.json
static func from_dict(data: Dictionary) -> RuleReferenceData:
	var rule_data: RuleReferenceData = RuleReferenceData.new()
	rule_data.data_key = str(data.get("data_key", ""))
	rule_data.kind = str(data.get("kind", "rules_reference"))
	rule_data.scope = str(data.get("scope", ""))
	rule_data.display_name = str(data.get("display_name", ""))
	rule_data.category = str(data.get("category", ""))
	rule_data.rules_text = str(data.get("rules_text", ""))
	rule_data.summary = str(data.get("summary", ""))
	rule_data.search_tags.assign(data.get("search_tags", []))
	rule_data.source_refs.assign(data.get("source_refs", []))
	rule_data.implemented_rule_ids.assign(data.get("implemented_rule_ids", []))
	rule_data.implementation_status = str(data.get("implementation_status", "NOT_INTEGRATED"))
	return rule_data
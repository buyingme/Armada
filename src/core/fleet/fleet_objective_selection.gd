## Fleet Objective Selection
##
## Editable selection of one Assault, one Defense, and one Navigation objective.
## Detailed objective legality is validated in later fleet-validator slices.
class_name FleetObjectiveSelection
extends RefCounted


const CATEGORY_ASSAULT: String = "ASSAULT"
const CATEGORY_DEFENSE: String = "DEFENSE"
const CATEGORY_NAVIGATION: String = "NAVIGATION"
const CATEGORIES: Array[String] = [
	CATEGORY_ASSAULT,
	CATEGORY_DEFENSE,
	CATEGORY_NAVIGATION,
]

## Selected Assault objective data key.
var assault_objective_key: String = ""

## Selected Defense objective data key.
var defense_objective_key: String = ""

## Selected Navigation objective data key.
var navigation_objective_key: String = ""


## Sets the selected objective key for [param category].
func set_objective(category: String, objective_key: String) -> bool:
	match category:
		CATEGORY_ASSAULT:
			assault_objective_key = objective_key
			return true
		CATEGORY_DEFENSE:
			defense_objective_key = objective_key
			return true
		CATEGORY_NAVIGATION:
			navigation_objective_key = objective_key
			return true
		_:
			return false


## Returns the selected objective key for [param category], or an empty string.
func get_objective(category: String) -> String:
	match category:
		CATEGORY_ASSAULT:
			return assault_objective_key
		CATEGORY_DEFENSE:
			return defense_objective_key
		CATEGORY_NAVIGATION:
			return navigation_objective_key
		_:
			return ""


## Returns true when all three objective categories have a selected key.
func is_complete() -> bool:
	return not assault_objective_key.is_empty() \
			and not defense_objective_key.is_empty() \
			and not navigation_objective_key.is_empty()


## Returns objective categories in fleet-building validation order.
static func categories() -> Array[String]:
	var categories_list: Array[String] = []
	categories_list.assign(CATEGORIES)
	return categories_list


## Serializes this objective selection to a JSON-safe dictionary.
func serialize() -> Dictionary:
	return {
		"assault": assault_objective_key,
		"defense": defense_objective_key,
		"navigation": navigation_objective_key,
	}


## Deserializes objective selection data, accepting lower-case or category keys.
static func deserialize(data: Dictionary) -> FleetObjectiveSelection:
	var selection: FleetObjectiveSelection = FleetObjectiveSelection.new()
	selection.assault_objective_key = str(data.get("assault", data.get(CATEGORY_ASSAULT, "")))
	selection.defense_objective_key = str(data.get("defense", data.get(CATEGORY_DEFENSE, "")))
	selection.navigation_objective_key = str(data.get("navigation", data.get(CATEGORY_NAVIGATION, "")))
	return selection

## Fleet Library List Presenter
##
## Populates fleet and version ItemLists for FleetLibraryPanel.
class_name FleetLibraryListPresenter
extends RefCounted


## Populates saved fleet summaries and returns the selected fleet id.
func populate_fleets(list: ItemList, summaries: Array[Dictionary],
		previous_id: String) -> String:
	list.clear()
	var selected_id: String = ""
	for summary: Dictionary in summaries:
		var fleet_id: String = str(summary.get("fleet_id", ""))
		var index: int = list.add_item(_fleet_summary_label(summary))
		list.set_item_metadata(index, summary)
		if fleet_id == previous_id:
			list.select(index)
			selected_id = fleet_id
	if selected_id.is_empty() and list.item_count > 0:
		list.select(0)
		selected_id = fleet_id_at(list, 0)
	return selected_id


## Populates version summaries and returns the selected active version id.
func populate_versions(list: ItemList, result: Dictionary) -> String:
	list.clear()
	var active_id: String = str(result.get("active_version_id", ""))
	var selected_id: String = ""
	for raw_version: Variant in result.get("versions", []):
		if raw_version is Dictionary:
			selected_id = _add_version(list, raw_version as Dictionary, active_id, selected_id)
	return selected_id


## Returns the fleet id from a saved-fleet list row.
func fleet_id_at(list: ItemList, index: int) -> String:
	var summary: Dictionary = fleet_summary_at(list, index)
	return str(summary.get("fleet_id", ""))


## Returns the saved-fleet summary metadata for a row.
func fleet_summary_at(list: ItemList, index: int) -> Dictionary:
	if index < 0 or index >= list.item_count:
		return {}
	return list.get_item_metadata(index) as Dictionary


## Returns the version id from a version list row.
func version_id_at(list: ItemList, index: int) -> String:
	if index < 0 or index >= list.item_count:
		return ""
	var version: Dictionary = list.get_item_metadata(index) as Dictionary
	return str(version.get("version_id", ""))


func _add_version(list: ItemList, version: Dictionary,
		active_id: String, selected_id: String) -> String:
	var version_id: String = str(version.get("version_id", ""))
	var index: int = list.add_item(_version_label(version, active_id))
	list.set_item_metadata(index, version)
	if version_id == active_id:
		list.select(index)
		return version_id
	return selected_id


func _fleet_summary_label(summary: Dictionary) -> String:
	return "%s (%s) %s" % [
		str(summary.get("name", "")),
		_display_key(str(summary.get("faction", ""))),
		str(summary.get("active_version_id", "")),
	]


func _version_label(version: Dictionary, active_id: String) -> String:
	var marker: String = "*" if str(version.get("version_id", "")) == active_id else " "
	var label_text: String = "%s %s %s" % [marker, str(version.get("version_id", "")),
			str(version.get("source", ""))]
	var restored_from: String = str(version.get("restored_from", ""))
	if not restored_from.is_empty():
		label_text += " from %s" % restored_from
	return label_text


func _display_key(value: String) -> String:
	return value.capitalize().replace("_", " ")

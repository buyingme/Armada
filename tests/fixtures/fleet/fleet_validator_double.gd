## FleetValidatorDouble
##
## Test-only FleetValidator variant that allows ShipData and UpgradeData
## overrides for deterministic unit scenarios.
extends FleetValidator


var _ship_overrides: Dictionary = {}
var _ship_class_overrides: Dictionary = {}
var _squadron_overrides: Dictionary = {}
var _upgrade_overrides: Dictionary = {}


func add_ship_override(data_key: String, ship_data: ShipData) -> void:
	_ship_overrides[data_key] = ship_data


func add_ship_class_override(data_key: String, ship_class: String) -> void:
	_ship_class_overrides[data_key] = ship_class


func add_squadron_override(data_key: String, squadron_data: SquadronData) -> void:
	_squadron_overrides[data_key] = squadron_data


func add_upgrade_override(data_key: String, upgrade_data: UpgradeData) -> void:
	_upgrade_overrides[data_key] = upgrade_data


func _load_ship(data_key: String) -> ShipData:
	if _ship_overrides.has(data_key):
		return _ship_overrides[data_key]
	return super._load_ship(data_key)


func _ship_class(data_key: String) -> String:
	if _ship_class_overrides.has(data_key):
		return _ship_class_overrides[data_key]
	return super._ship_class(data_key)


func _load_squadron(data_key: String) -> SquadronData:
	if _squadron_overrides.has(data_key):
		return _squadron_overrides[data_key]
	return super._load_squadron(data_key)


func _load_upgrade(data_key: String) -> UpgradeData:
	if _upgrade_overrides.has(data_key):
		return _upgrade_overrides[data_key]
	return super._load_upgrade(data_key)

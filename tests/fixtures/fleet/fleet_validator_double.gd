## FleetValidatorDouble
##
## Test-only FleetValidator variant that allows ShipData and UpgradeData
## overrides for deterministic unit scenarios.
extends FleetValidator


var _ship_overrides: Dictionary = {}
var _upgrade_overrides: Dictionary = {}


func add_ship_override(data_key: String, ship_data: ShipData) -> void:
	_ship_overrides[data_key] = ship_data


func add_upgrade_override(data_key: String, upgrade_data: UpgradeData) -> void:
	_upgrade_overrides[data_key] = upgrade_data


func _load_ship(data_key: String) -> ShipData:
	if _ship_overrides.has(data_key):
		return _ship_overrides[data_key]
	return super._load_ship(data_key)


func _load_upgrade(data_key: String) -> UpgradeData:
	if _upgrade_overrides.has(data_key):
		return _upgrade_overrides[data_key]
	return super._load_upgrade(data_key)

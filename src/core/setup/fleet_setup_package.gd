## Fleet Setup Package
##
## Serializable shell for match-ready fleet setup payloads. It embeds rosters
## directly so hot-seat, network, replay, and bootstrap paths can agree on a
## deterministic package hash without reading local fleet-library files.
class_name FleetSetupPackage
extends RefCounted


const FORMAT_VERSION: int = 1
const KIND: String = "fleet_setup_package"
const HASH_IGNORED_KEYS: Array[String] = [
	"package_hash",
	"created_at",
	"updated_at",
	"future_sync",
	"source",
]

## Serialized format version for forward-compatible setup package changes.
var format_version: int = FORMAT_VERSION

## Static payload kind discriminator.
var kind: String = KIND

## Scenario key used by the board/bootstrap path.
var scenario_id: String = ""

## Point-format metadata, for example {"id": "STANDARD_400", "limit": 400}.
var point_format: Dictionary = {}

## Map metadata chosen from the first player's roster.
var map: Dictionary = {}

## Player index with initiative.
var first_player: int = 0

## Player setup entries. Each entry embeds a full roster dictionary.
var players: Array[Dictionary] = []

## Selected objective metadata, if objective selection has been completed.
var selected_objective: Dictionary = {}

## Normalized obstacle placements.
var obstacles: Array[Dictionary] = []

## Normalized ship and squadron deployment placements.
var deployments: Array[Dictionary] = []

## JSON-safe objective/setup scaffolding derived before runtime bootstrap.
var setup_state: Dictionary = {}


## Serializes this setup package to a JSON-safe dictionary.
func serialize() -> Dictionary:
	return {
		"format_version": format_version,
		"kind": kind,
		"scenario_id": scenario_id,
		"point_format": point_format.duplicate(true),
		"map": map.duplicate(true),
		"first_player": first_player,
		"players": _copy_dict_array(players),
		"selected_objective": selected_objective.duplicate(true),
		"obstacles": _copy_dict_array(obstacles),
		"deployments": _copy_dict_array(deployments),
		"setup_state": setup_state.duplicate(true),
	}


## Deserializes a setup package shell from JSON-safe data.
static func deserialize(data: Dictionary) -> FleetSetupPackage:
	var package: FleetSetupPackage = FleetSetupPackage.new()
	package.format_version = int(data.get("format_version", FORMAT_VERSION))
	package.kind = str(data.get("kind", KIND))
	package.scenario_id = str(data.get("scenario_id", ""))
	package.point_format = data.get("point_format", {})
	package.map = data.get("map", {})
	package.first_player = int(data.get("first_player", 0))
	package.players = _read_dict_array(data.get("players", []))
	package.selected_objective = data.get("selected_objective", {})
	package.obstacles = _read_dict_array(data.get("obstacles", []))
	package.deployments = _read_dict_array(data.get("deployments", []))
	package.setup_state = data.get("setup_state", {})
	return package


## Returns validation messages for the minimal setup-package shell contract.
func validate_basic() -> Array[String]:
	var errors: Array[String] = []
	if kind != KIND:
		errors.append("Setup package kind must be '%s'." % KIND)
	if scenario_id.strip_edges().is_empty():
		errors.append("Setup package scenario_id is required.")
	if map.is_empty():
		errors.append("Setup package map is required.")
	if first_player < 0 or first_player >= Constants.PLAYER_COUNT:
		errors.append("Setup package first_player is out of range.")
	_validate_players(errors)
	return errors


## Computes the deterministic canonical hash for gameplay-relevant payload data.
func canonical_hash() -> String:
	return CanonicalJson.hash(_hash_payload())


## Returns the serialized package plus its canonical hash.
func to_hashed_dict() -> Dictionary:
	var data: Dictionary = serialize()
	data["package_hash"] = canonical_hash()
	return data


func _validate_players(errors: Array[String]) -> void:
	if players.size() != Constants.PLAYER_COUNT:
		errors.append("Setup package must include two player entries.")
	for player_entry: Dictionary in players:
		if not player_entry.has("player_index"):
			errors.append("Player entry is missing player_index.")
		var roster_data: Variant = player_entry.get("roster", {})
		if not roster_data is Dictionary or (roster_data as Dictionary).is_empty():
			errors.append("Player entry is missing embedded roster data.")


func _hash_payload() -> Dictionary:
	return _strip_hash_ignored(serialize()) as Dictionary


static func _strip_hash_ignored(value: Variant) -> Variant:
	if value is Dictionary:
		return _strip_hash_ignored_dictionary(value as Dictionary)
	if value is Array:
		return _strip_hash_ignored_array(value as Array)
	return value


static func _strip_hash_ignored_dictionary(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in value.keys():
		if HASH_IGNORED_KEYS.has(str(key)):
			continue
		result[key] = _strip_hash_ignored(value[key])
	return result


static func _strip_hash_ignored_array(value: Array) -> Array:
	var result: Array = []
	for item: Variant in value:
		result.append(_strip_hash_ignored(item))
	return result


static func _copy_dict_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


static func _read_dict_array(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result
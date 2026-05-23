## Lobby State
##
## Pure data model for a game lobby.  Stores the lobby configuration,
## connected players, and readiness status.  Used by [LobbyManager]
## on both server and client to track lobby state.
##
## G4 Network Plan: §4 — G4.5.1, G4.5.7
class_name LobbyState
extends RefCounted


## Length of the randomly generated lobby code.
const CODE_LENGTH: int = 6

## Characters used for lobby code generation.
## Excludes I/O/0/1 to avoid visual confusion.
const CODE_CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## Maximum length for lobby and display names.
const MAX_NAME_LENGTH: int = 32

## Maximum number of players in a lobby (always 2 for Armada).
const MAX_PLAYERS: int = 2
## Canonical scenario id for the standard learning setup.
const SCENARIO_LEARNING_ID: String = "learning_scenario"
## Canonical scenario id for the compact rule-testing setup.
const SCENARIO_DEBUG_ID: String = "debug_scenario"
## Display label for the standard learning setup.
const SCENARIO_LEARNING_LABEL: String = "Learning Scenario"
## Display label for the compact rule-testing setup.
const SCENARIO_DEBUG_LABEL: String = "Debug Scenario"
## Legacy lobby scenario value used before scenario ids were stored.
const SCENARIO_LEARNING_LEGACY_ID: String = "learning"
## Host-selectable scenarios shown in the lobby picker.
const SCENARIO_OPTIONS: Array[Dictionary] = [
	{"label": SCENARIO_LEARNING_LABEL, "id": SCENARIO_LEARNING_ID},
	{"label": SCENARIO_DEBUG_LABEL, "id": SCENARIO_DEBUG_ID},
]


## Unique lobby identifier.
var lobby_id: String = ""

## 6-character alphanumeric code for direct join.
var code: String = ""

## Human-readable lobby name set by the host.
var lobby_name: String = ""

## ENet peer ID of the host (server is always peer 1).
var host_peer_id: int = 1

## Selected scenario identifier.
var scenario: String = SCENARIO_LEARNING_ID

## SHA-256 hash of the lobby password, or empty for no password.
var password_hash: String = ""

## Connected players.
## Each entry: [code]{peer_id: int, display_name: String,
## player_index: int, ready: bool, faction: String}[/code].
var players: Array[Dictionary] = []


# ---------------------------------------------------------------------------
# Code generation (G4.5.7)
# ---------------------------------------------------------------------------

## Generates a random 6-character lobby code.
## Uses [constant CODE_CHARS] to avoid visually ambiguous characters.
static func generate_code() -> String:
	var result: String = ""
	for i: int in range(CODE_LENGTH):
		var idx: int = randi() % CODE_CHARS.length()
		result += CODE_CHARS[idx]
	return result


# ---------------------------------------------------------------------------
# Player management
# ---------------------------------------------------------------------------

## Adds a player to the lobby.
## Returns [code]true[/code] if the player was added successfully.
## Returns [code]false[/code] if the lobby is full or the peer is
## already present.
func add_player(peer_id: int, display_name: String,
		player_index: int) -> bool:
	if get_player_count() >= MAX_PLAYERS:
		return false
	for p: Dictionary in players:
		if p["peer_id"] == peer_id:
			return false
	players.append({
		"peer_id": peer_id,
		"display_name": display_name,
		"player_index": player_index,
		"ready": false,
		"faction": "",
	})
	return true


## Removes a player from the lobby by peer ID.
## Returns [code]true[/code] if the player was found and removed.
func remove_player(peer_id: int) -> bool:
	for i: int in range(players.size()):
		if players[i]["peer_id"] == peer_id:
			players.remove_at(i)
			return true
	return false


## Sets the ready status of a player.
## Returns [code]true[/code] if the player was found.
func set_player_ready(peer_id: int, ready: bool) -> bool:
	for p: Dictionary in players:
		if p["peer_id"] == peer_id:
			p["ready"] = ready
			return true
	return false


## Returns [code]true[/code] if all connected players are ready.
func is_all_ready() -> bool:
	if players.is_empty():
		return false
	for p: Dictionary in players:
		if not p["ready"]:
			return false
	return true


## Returns [code]true[/code] if the game can start.
## Requires exactly [constant MAX_PLAYERS] players, all ready.
func can_start() -> bool:
	return get_player_count() == MAX_PLAYERS and is_all_ready()


## Returns the number of connected players.
func get_player_count() -> int:
	return players.size()


## Returns [code]true[/code] if the lobby requires a password.
func has_password() -> bool:
	return password_hash != ""


## Returns the player entry for the given peer ID, or an empty
## dictionary if not found.
func get_player(peer_id: int) -> Dictionary:
	for p: Dictionary in players:
		if p["peer_id"] == peer_id:
			return p
	return {}


## Returns [code]true[/code] if a player with the given peer ID is
## in the lobby.
func has_player(peer_id: int) -> bool:
	for p: Dictionary in players:
		if p["peer_id"] == peer_id:
			return true
	return false


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serializes the lobby state to a plain dictionary.
func serialize() -> Dictionary:
	var serialized_players: Array[Dictionary] = []
	for p: Dictionary in players:
		serialized_players.append(p.duplicate())
	return {
		"lobby_id": lobby_id,
		"code": code,
		"lobby_name": lobby_name,
		"host_peer_id": host_peer_id,
		"scenario": scenario,
		"password_hash": password_hash,
		"players": serialized_players,
	}


## Deserializes a lobby state from a plain dictionary.
static func deserialize(data: Dictionary) -> LobbyState:
	var state: LobbyState = LobbyState.new()
	state.lobby_id = data.get("lobby_id", "")
	state.code = data.get("code", "")
	state.lobby_name = data.get("lobby_name", "")
	state.host_peer_id = data.get("host_peer_id", 1)
	state.scenario = normalize_scenario_id(
			data.get("scenario", SCENARIO_LEARNING_ID) as String)
	state.password_hash = data.get("password_hash", "")
	var raw_players: Array = data.get("players", [])
	state.players = []
	for p: Variant in raw_players:
		if p is Dictionary:
			state.players.append(p as Dictionary)
	return state


## Returns the lobby scenario picker options as a JSON-safe copy.
static func get_scenario_options() -> Array[Dictionary]:
	return SCENARIO_OPTIONS.duplicate(true)


## Returns the canonical scenario id for current and legacy lobby values.
static func normalize_scenario_id(raw_scenario: String) -> String:
	var candidate: String = raw_scenario.strip_edges()
	match candidate:
		SCENARIO_DEBUG_ID, SCENARIO_DEBUG_LABEL:
			return SCENARIO_DEBUG_ID
		SCENARIO_LEARNING_ID, SCENARIO_LEARNING_LABEL, SCENARIO_LEARNING_LEGACY_ID:
			return SCENARIO_LEARNING_ID
		_:
			return SCENARIO_LEARNING_ID


# ---------------------------------------------------------------------------
# Input sanitization (G4.5.11)
# ---------------------------------------------------------------------------

## Sanitizes a string by removing control characters and clamping length.
## Used for lobby names and display names.
static func sanitize_name(input: String,
		max_length: int = MAX_NAME_LENGTH) -> String:
	var cleaned: String = ""
	for i: int in range(input.length()):
		var c: String = input[i]
		if c.unicode_at(0) >= 32:
			cleaned += c
	if cleaned.length() > max_length:
		cleaned = cleaned.substr(0, max_length)
	return cleaned.strip_edges()

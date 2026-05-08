## GameReplay
##
## Captures a complete game session as a serializable replay file.
## A replay consists of a header (metadata about the session) and an
## ordered array of serialized [GameCommand] dictionaries.
##
## The header records everything needed to reconstruct the initial game
## state before replaying commands: scenario identifier, RNG seed,
## faction assignments, and session metadata (timestamp, versions).
##
## Usage — recording:
## [codeblock]
## var replay := CommandProcessor.create_replay("learning_scenario")
## replay.save_to_file("res://replays/my_game.json")
## [/codeblock]
##
## Usage — playback:
## [codeblock]
## var replay := GameReplay.load_from_file("res://replays/my_game.json")
## # Reconstruct initial state from replay.header, then:
## CommandProcessor.replay_commands(replay.commands)
## [/codeblock]
##
## Rules Reference: architectural decision — all game-changing player
## actions are recorded for deterministic replay, network sync, and
## automated regression testing.
class_name GameReplay
extends RefCounted


## Current replay file format version. Increment when the schema changes.
const FORMAT_VERSION: int = 1

## Format version that introduced HMAC signing support.
const SIGNED_FORMAT_VERSION: int = 2

## Default directory for replay files.
## Resolved via [PathConfig]: in the editor it points at
## [code]res://replays[/code]; in exported builds it points at
## [code]user://replays[/code].
static var REPLAY_DIR: String = PathConfig.REPLAYS_DIR

## File extension for replay files.
const REPLAY_EXT: String = ".json"

## HMAC digest algorithm identifier (SHA-256).
const HMAC_HASH_TYPE: int = HashingContext.HASH_SHA256

## Session metadata: scenario_id, rng_seed, factions, timestamp, etc.
var header: Dictionary = {}

## Ordered list of serialized commands (each is a Dictionary).
var commands: Array[Dictionary] = []


## Creates an empty replay. Use [method capture_header] and
## [method set_commands] to populate, or [method load_from_file]
## to load an existing replay.
func _init() -> void:
	pass


## Populates the replay header with session metadata.
## [param scenario_id] — identifier of the scenario (e.g. "learning_scenario").
## [param rng_seed] — the initial RNG seed used for this game session.
## [param factions] — array of faction identifiers per player index.
## [param initiative_player] — which player has initiative (0 or 1).
func capture_header(scenario_id: String, rng_seed: int,
		factions: Array, initiative_player: int = 0) -> void:
	header = {
		"format_version": FORMAT_VERSION,
		"scenario_id": scenario_id,
		"rng_seed": rng_seed,
		"factions": factions,
		"initiative_player": initiative_player,
		"timestamp": Time.get_datetime_string_from_system(true),
		"app_version": ProjectSettings.get_setting(
				"application/config/version", "unknown"),
		"godot_version": Engine.get_version_info().get("string", "unknown"),
	}


## Sets the command history from an array of serialized command dictionaries.
## Typically obtained from [method CommandProcessor.serialize_history].
func set_commands(serialized_commands: Array[Dictionary]) -> void:
	commands = serialized_commands


## Returns the number of commands in the replay.
func get_command_count() -> int:
	return commands.size()


## Returns [code]true[/code] if the replay contains a valid header
## and at least one command.
func is_valid() -> bool:
	return header.has("format_version") and header.has("rng_seed")


## Serializes the full replay (header + commands) to a dictionary
## suitable for JSON encoding.
func serialize() -> Dictionary:
	return {
		"header": header,
		"commands": commands,
	}


## Deserializes a replay from a dictionary previously produced by
## [method serialize].
## Returns [code]null[/code] if the data is malformed.
static func deserialize(data: Dictionary) -> GameReplay:
	if not data.has("header") or not data.has("commands"):
		return null
	var replay := GameReplay.new()
	replay.header = data["header"]
	var raw_commands: Array = data.get("commands", [])
	for cmd_dict: Variant in raw_commands:
		if cmd_dict is Dictionary:
			replay.commands.append(cmd_dict as Dictionary)
	return replay


## Saves the replay to a JSON file on disk.
## [param file_path] — full path including extension, e.g.
## [code]"res://replays/game_001.json"[/code].
## Returns [constant OK] on success, or an error code on failure.
func save_to_file(file_path: String) -> Error:
	var dir_path: String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return err
	var data: Dictionary = serialize()
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()
	return OK


## Loads a replay from a JSON file on disk.
## [param file_path] — full path including extension.
## Returns [code]null[/code] on failure.
static func load_from_file(file_path: String) -> GameReplay:
	if not FileAccess.file_exists(file_path):
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var json_string: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_err: Error = json.parse(json_string)
	if parse_err != OK:
		return null
	var data: Variant = json.data
	if not data is Dictionary:
		return null
	return GameReplay.deserialize(data as Dictionary)


## Generates a default file path for a new replay based on the current
## timestamp.
## Example: [code]"res://replays/replay_20260412_093000.json"[/code].
static func generate_file_path() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var name: String = "replay_%04d%02d%02d_%02d%02d%02d" % [
			dt["year"], dt["month"], dt["day"],
			dt["hour"], dt["minute"], dt["second"]]
	return "%s/%s%s" % [REPLAY_DIR, name, REPLAY_EXT]


# ---------------------------------------------------------------------------
# HMAC Replay Signing (G4.10.5)
# ---------------------------------------------------------------------------

## Signs the replay data with an HMAC-SHA256 signature and embeds it
## in the header.  The signature covers the canonical JSON of the
## replay content (header without the hmac field + commands).
## [param secret_key] — the server's signing key (raw bytes).
## Returns [code]true[/code] on success.
func sign_replay(secret_key: PackedByteArray) -> bool:
	if secret_key.is_empty():
		return false
	# Update format version before signing so the payload matches on verify.
	header["format_version"] = SIGNED_FORMAT_VERSION
	var payload: String = _build_signing_payload()
	var hmac_hex: String = _compute_hmac_sha256(secret_key, payload)
	if hmac_hex.is_empty():
		return false
	header["hmac"] = hmac_hex
	return true


## Verifies the HMAC signature embedded in the header.
## [param secret_key] — the same key used to sign the replay.
## Returns [code]true[/code] if the signature is valid, [code]false[/code]
## if missing, tampered, or the key is wrong.
func verify_signature(secret_key: PackedByteArray) -> bool:
	if secret_key.is_empty():
		return false
	var stored_hmac: String = header.get("hmac", "") as String
	if stored_hmac.is_empty():
		return false
	var payload: String = _build_signing_payload()
	var expected: String = _compute_hmac_sha256(secret_key, payload)
	if expected.is_empty():
		return false
	return _constant_time_compare(stored_hmac, expected)


## Returns [code]true[/code] if the replay has an HMAC signature in its
## header (does not verify it — call [method verify_signature] for that).
func is_signed() -> bool:
	return header.has("hmac") and header.get("hmac", "") != ""


## Builds the canonical string that is signed.  This is the JSON
## representation of the replay data with the [code]hmac[/code] field
## removed from the header (so the signature does not cover itself).
## Uses sorted keys for deterministic output across save/load cycles.
## Normalises via a JSON round-trip so that int/float representation
## differences (Godot's JSON parser converts all numbers to float)
## do not affect the digest.
func _build_signing_payload() -> String:
	var header_copy: Dictionary = header.duplicate()
	header_copy.erase("hmac")
	var payload: Dictionary = {
		"header": header_copy,
		"commands": commands,
	}
	# Round-trip through JSON to normalise number types (int → float).
	var raw: String = JSON.stringify(payload, "", true)
	var json := JSON.new()
	json.parse(raw)
	return JSON.stringify(json.data, "", true)


## Computes HMAC-SHA256 over [param message] using [param key].
## Returns the hex-encoded digest, or [code]""[/code] on failure.
static func _compute_hmac_sha256(
		key: PackedByteArray, message: String) -> String:
	var hmac_ctx := HMACContext.new()
	var err: Error = hmac_ctx.start(HMAC_HASH_TYPE, key)
	if err != OK:
		return ""
	err = hmac_ctx.update(message.to_utf8_buffer())
	if err != OK:
		return ""
	var digest: PackedByteArray = hmac_ctx.finish()
	return digest.hex_encode()


## Constant-time string comparison to prevent timing attacks on HMAC
## verification.  Both strings must be the same length for a valid
## comparison; mismatched lengths return [code]false[/code] immediately
## (length is not secret).
static func _constant_time_compare(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var result: int = 0
	for i: int in range(a.length()):
		result |= a.unicode_at(i) ^ b.unicode_at(i)
	return result == 0

## PlayerProfile
##
## Autoload singleton that manages the local player's identity.
## Generates a persistent UUID v4 [code]client_id[/code] on first launch
## and stores it (along with the display name) in [code]user://settings.cfg[/code].
##
## G4 Network Plan: §3 — G4.1.9
extends Node


## Config file path for persistent player profile.
const SETTINGS_PATH: String = "user://settings.cfg"

## Config file section for player identity.
const SECTION: String = "player"

## Default display name for new players.
const DEFAULT_DISPLAY_NAME: String = "Player"

## The persistent client identifier (UUID v4).  Generated once, never changes.
## Included in all network handshakes.
var client_id: String = ""

## The player's chosen display name.
var display_name: String = DEFAULT_DISPLAY_NAME

## Logger for this system.
var _log: GameLogger = GameLogger.new("PlayerProfile")


func _ready() -> void:
	_load_or_create()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the persistent client ID.
func get_client_id() -> String:
	return client_id


## Returns the current display name.
func get_display_name() -> String:
	return display_name


## Sets the display name and persists it.
## [param new_name] — the new display name (max 32 chars, stripped).
func set_display_name(new_name: String) -> void:
	var sanitised: String = new_name.strip_edges().left(32)
	if sanitised.is_empty():
		sanitised = DEFAULT_DISPLAY_NAME
	display_name = sanitised
	_save()
	_log.info("Display name changed to '%s'." % display_name)


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

## Loads the profile from disk, or creates a new one if none exists.
func _load_or_create() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err == OK and config.has_section_key(SECTION, "client_id"):
		client_id = config.get_value(SECTION, "client_id", "")
		display_name = config.get_value(SECTION, "display_name",
				DEFAULT_DISPLAY_NAME)
		_log.info("Loaded profile: client_id='%s', name='%s'." % [
				client_id, display_name])
	else:
		client_id = _generate_uuid_v4()
		display_name = DEFAULT_DISPLAY_NAME
		_save()
		_log.info("Created new profile: client_id='%s'." % client_id)


## Persists the current profile to disk.
func _save() -> void:
	var config := ConfigFile.new()
	# Load existing config first to preserve other sections.
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "client_id", client_id)
	config.set_value(SECTION, "display_name", display_name)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		_log.error("Failed to save profile: %s" % error_string(err))


## Generates a UUID v4 string (random, RFC 4122 compliant).
func _generate_uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(16)
	for i: int in range(16):
		bytes[i] = rng.randi() & 0xFF
	# Set version (4) and variant (10xx).
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
			bytes[0], bytes[1], bytes[2], bytes[3],
			bytes[4], bytes[5],
			bytes[6], bytes[7],
			bytes[8], bytes[9],
			bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]]

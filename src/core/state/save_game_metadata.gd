## SaveGameMetadata
##
## Header schema for save-game files (Phase J1).  Wraps a [Dictionary]
## with typed accessors, validation and serialisation, plus helpers for
## building the default save-name template and the human-readable phase
## label used in the UI.
##
## A complete save file on disk has the structure:
## [codeblock]
## {
##   "header": { ... fields below ..., "hmac": "<hex>" },
##   "state":  { ... GameState.serialize() output ... }
## }
## [/codeblock]
##
## Fields:
##   - [code]save_format_version: int[/code] — schema version (currently 1).
##   - [code]scenario_id: String[/code] — the scenario JSON key (e.g.
##     [code]"learning_scenario"[/code]).
##   - [code]scenario_name: String[/code] — human-readable scenario name
##     read from the scenario JSON's [code]scenario_name[/code] field.
##   - [code]game_mode: String[/code] — [code]"hot_seat"[/code] or
##     [code]"network"[/code].
##   - [code]round: int[/code] — value of [member GameState.current_round].
##   - [code]phase: String[/code] — phase enum name (Command/Ship/...).
##   - [code]created_at: String[/code] — ISO-8601 UTC timestamp.
##   - [code]app_version: String[/code] — engine version string.
##   - [code]display_name: String[/code] — user-visible save name.
##
## Rules Reference: Phase J1 — save game header schema.
class_name SaveGameMetadata
extends RefCounted


## Current header schema version.  Bump on any breaking change to the
## header or to [method GameState.serialize] / [method GameState.deserialize].
const CURRENT_VERSION: int = 1

## Allowed values for [member game_mode].
const MODE_HOT_SEAT: String = "hot_seat"
const MODE_NETWORK: String = "network"

## Maximum length of [member display_name].  Enforced at validation time.
const MAX_DISPLAY_NAME_LEN: int = 64


var save_format_version: int = CURRENT_VERSION
var scenario_id: String = ""
var scenario_name: String = ""
var game_mode: String = MODE_HOT_SEAT
var current_round: int = 0
var phase: String = ""
var created_at: String = ""
var app_version: String = ""
var display_name: String = ""


## Builds a default save-name template of the form
## [code]{scenario_name}_{game_mode_camel}_R{round}_{phase}[/code].
## Example: [code]"Learning Scenario_HotSeat_R2_Ship"[/code] → after
## scenario-name sanitisation, [code]"LearningScenario_HotSeat_R2_Ship"[/code].
static func build_default_name(
		scenario_name_arg: String,
		game_mode_arg: String,
		round_arg: int,
		phase_arg: String) -> String:
	var clean_scenario: String = _strip_non_filename(scenario_name_arg)
	var mode_label: String = "HotSeat" if game_mode_arg == MODE_HOT_SEAT \
			else "Network"
	return "%s_%s_R%d_%s" % [clean_scenario, mode_label, round_arg, phase_arg]


## Returns the human-readable label for a [enum Constants.GamePhase] value.
## Used in the default-name template and the load-game list.
static func phase_label(game_phase: Constants.GamePhase) -> String:
	match game_phase:
		Constants.GamePhase.SETUP:
			return "Setup"
		Constants.GamePhase.COMMAND:
			return "Command"
		Constants.GamePhase.SHIP:
			return "Ship"
		Constants.GamePhase.SQUADRON:
			return "Squadron"
		Constants.GamePhase.STATUS:
			return "Status"
	return "Unknown"


## Serialises the header to a plain dictionary (JSON-safe).
func to_dict() -> Dictionary:
	return {
		"save_format_version": save_format_version,
		"scenario_id": scenario_id,
		"scenario_name": scenario_name,
		"game_mode": game_mode,
		"round": current_round,
		"phase": phase,
		"created_at": created_at,
		"app_version": app_version,
		"display_name": display_name,
	}


## Reconstructs a [SaveGameMetadata] from a dictionary.  Missing fields
## fall back to safe defaults; the version check is performed by
## [method validate], not here.
static func from_dict(data: Dictionary) -> SaveGameMetadata:
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.save_format_version = int(data.get("save_format_version", 0))
	meta.scenario_id = String(data.get("scenario_id", ""))
	meta.scenario_name = String(data.get("scenario_name", ""))
	meta.game_mode = String(data.get("game_mode", MODE_HOT_SEAT))
	meta.current_round = int(data.get("round", 0))
	meta.phase = String(data.get("phase", ""))
	meta.created_at = String(data.get("created_at", ""))
	meta.app_version = String(data.get("app_version", ""))
	meta.display_name = String(data.get("display_name", ""))
	return meta


## Validates the header.  Returns a result dictionary
## [code]{"ok": bool, "reason": String}[/code].
## Reasons returned on failure:
##   - [code]"version_unsupported"[/code] — wrong [member save_format_version].
##   - [code]"scenario_missing"[/code] — empty [member scenario_id].
##   - [code]"mode_invalid"[/code] — not [code]hot_seat[/code] or
##     [code]network[/code].
##   - [code]"display_name_invalid"[/code] — empty, too long, or contains
##     a path separator.
func validate() -> Dictionary:
	if save_format_version != CURRENT_VERSION:
		return {
			"ok": false,
			"reason": "version_unsupported",
		}
	if scenario_id.is_empty():
		return {"ok": false, "reason": "scenario_missing"}
	if game_mode != MODE_HOT_SEAT and game_mode != MODE_NETWORK:
		return {"ok": false, "reason": "mode_invalid"}
	if not is_display_name_valid(display_name):
		return {"ok": false, "reason": "display_name_invalid"}
	return {"ok": true, "reason": ""}


## Returns [code]true[/code] iff [param name] is a non-empty string of at
## most [constant MAX_DISPLAY_NAME_LEN] characters and contains no
## filesystem path separators or other unsafe characters.
static func is_display_name_valid(name: String) -> bool:
	if name.is_empty():
		return false
	if name.length() > MAX_DISPLAY_NAME_LEN:
		return false
	# Disallow path separators and characters that confuse the filesystem.
	var banned: String = "/\\:*?\"<>|"
	for i: int in range(banned.length()):
		var ch: String = banned.substr(i, 1)
		if name.contains(ch):
			return false
	# Also reject leading/trailing whitespace and the special names.
	if name.strip_edges() != name:
		return false
	if name == "." or name == "..":
		return false
	return true


## Strips characters that are unsafe in filenames (path separators,
## whitespace) from [param value] for use in the default-name template.
static func _strip_non_filename(value: String) -> String:
	var out: String = ""
	for i: int in range(value.length()):
		var ch: String = value.substr(i, 1)
		var unicode: int = ch.unicode_at(0)
		var is_alnum: bool = (
			(unicode >= 0x30 and unicode <= 0x39) or
			(unicode >= 0x41 and unicode <= 0x5A) or
			(unicode >= 0x61 and unicode <= 0x7A))
		if is_alnum:
			out += ch
	return out

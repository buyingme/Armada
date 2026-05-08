## PathConfig
##
## Centralised resolver for writeable directories (saves, replays,
## logs, annotations).  Keeps two profiles:
##
## * In the editor (and on any build that responds true to
##   [code]OS.has_feature("editor")[/code]) the directories live under
##   [code]res://[/code] so they sit inside the project folder and
##   stay visible to the IDE, the agent's tools, and git.
## * In an exported / packaged build [code]res://[/code] is read-only
##   (the .pck inside the .app), so paths flip to [code]user://[/code]
##   automatically.  On macOS that resolves to
##   [code]~/Library/Application Support/Armada/[/code] when the
##   custom user dir is set in [code]project.godot[/code], or to the
##   generic Godot app_userdata folder otherwise.
##
## All values are static, evaluated once when the script is first
## loaded.  Consumers should reference them as
## [code]PathConfig.SAVES_DIR[/code] etc., never hardcode the strings.
class_name PathConfig
extends RefCounted


## Whether writeable directories should live inside the project folder.
## True in the editor, false in any exported build.
static var USE_PROJECT_PATHS: bool = OS.has_feature("editor")

## Root directory for user save games.
static var SAVES_DIR: String = ("res://saves" if USE_PROJECT_PATHS
		else "user://saves")

## Root directory for replay files.
static var REPLAYS_DIR: String = ("res://replays" if USE_PROJECT_PATHS
		else "user://replays")

## Root directory for game log files.
static var LOGS_DIR: String = ("res://logs" if USE_PROJECT_PATHS
		else "user://logs")

## Sub-directory for debug annotation snapshots (under [member SAVES_DIR]).
static var ANNOTATIONS_DIR: String = SAVES_DIR + "/annotations"

## Per-install signing key file used by [SaveGameManager] to HMAC-sign
## save headers.  Lives next to the saves it protects.
static var SIGNING_KEY_FILE: String = SAVES_DIR + "/.signing_key"


## Returns the absolute filesystem path of the
## [code]user://[/code] folder, suitable for showing in UI when a
## player asks where their saves and logs are stored.
static func user_data_abs_path() -> String:
	return ProjectSettings.globalize_path("user://")

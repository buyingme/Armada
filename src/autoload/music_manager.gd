## Music Manager
##
## Singleton that handles background music playback with crossfade transitions,
## shuffled in-game playlist, destruction overrides, and victory music.
##
## During gameplay the 12 in-game tracks ([code]in_game_1[/code] …
## [code]in_game_12[/code]) are shuffled into a random playlist. When a track
## finishes, the next one crossfades in automatically. After all 12 have
## played the list is reshuffled and playback continues.
##
## Capital-ship destruction temporarily overrides the playlist for a
## configurable duration, then the playlist resumes.
##
## Requirements: MUS-001 … MUS-010.
extends Node


## Path to the central sound configuration file (shared with SfxManager).
const CONFIG_PATH: String = "res://Resources/Sound/sound_config.json"

var _log: GameLogger = GameLogger.new("MusicManager")

## Preloaded music streams keyed by config name.
var _streams: Dictionary = {}

## Per-track linear volume (0.0–1.0) keyed by config name.
var _volumes: Dictionary = {}

## Crossfade duration in seconds (from config).
var _fade_duration: float = 3.0

## Duration in seconds for a destruction-override track (from config).
var _destruction_override_duration: float = 60.0

## Two AudioStreamPlayers used for crossfading.
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null

## Which player is currently audible (true = A, false = B).
var _a_is_current: bool = true

## Key of the currently playing track (empty = silence).
var _current_track_key: String = ""

## True while a destruction override is active (prevents playlist advance).
var _override_active: bool = false

## Timer for destruction override expiry.
var _override_timer: SceneTreeTimer = null

## Number of in-game tracks (loaded from config, default 12).
var _in_game_track_count: int = 12

## Shuffled playlist of in-game track keys for the current cycle.
var _playlist: Array[String] = []

## Index of the currently playing track within [member _playlist].
var _playlist_index: int = -1

## True while music is paused by the user.
var _paused: bool = false

## User-controlled volume multiplier (0.0–1.0). Applied on top of per-track
## volumes from the config file. 1.0 = full config volume, 0.0 = muted.
var _volume_multiplier: float = 1.0

## Step size for volume +/− buttons (10%).
const VOLUME_STEP: float = 0.1


func _ready() -> void:
	_load_config()
	_create_players()
	_connect_signals()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Plays the track identified by [param key]. Crossfades from the current
## track to the new one. If [param key] is already playing, does nothing.
## Requirements: MUS-002, MUS-003.
func play(key: String) -> void:
	if key == _current_track_key:
		return
	if not _streams.has(key):
		_log.warn("Unknown music key: %s" % key)
		return
	_crossfade_to(key)


## Stops all music with a fade-out.
func stop() -> void:
	_current_track_key = ""
	_override_active = false
	var current: AudioStreamPlayer = _get_current_player()
	if current.playing:
		_fade_out(current)


## Toggles between paused and playing. When pausing, the current player is
## set to stream-paused; when resuming it continues from the same position.
## Requirements: MUS-011.
func toggle_pause() -> void:
	_paused = not _paused
	var current: AudioStreamPlayer = _get_current_player()
	current.stream_paused = _paused
	_log.info("Music %s." % ("paused" if _paused else "resumed"))


## Returns [code]true[/code] when music is currently paused.
func is_paused() -> bool:
	return _paused


## Skips to the next track in the shuffled playlist with a crossfade.
## If currently in a destruction override, the override is cancelled.
## Requirements: MUS-012.
func skip_to_next() -> void:
	_override_active = false
	if _paused:
		_paused = false
		var current: AudioStreamPlayer = _get_current_player()
		current.stream_paused = false
	_advance_playlist()
	_log.info("Skipped to next track.")


## Returns the current music volume as a percentage (0–100).
func get_volume_percent() -> int:
	return roundi(_volume_multiplier * 100.0)


## Sets the music volume to [param percent] (clamped 0–100). Applies
## immediately to the currently audible player.
## Requirements: MUS-013.
func set_volume_percent(percent: int) -> void:
	_volume_multiplier = clampf(float(percent) / 100.0, 0.0, 1.0)
	var current: AudioStreamPlayer = _get_current_player()
	var track_vol: float = _volumes.get(_current_track_key, 1.0)
	current.volume_db = linear_to_db(track_vol * _volume_multiplier)
	_log.info("Music volume: %d%%." % get_volume_percent())


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## When a ship is destroyed, determine if it's a capital ship and trigger an
## override track for the opposing faction.
## Requirements: MUS-006, MUS-007.
func _on_ship_destroyed(ship_node: Node) -> void:
	if not ship_node or not ship_node.has_method("get_ship_instance"):
		return
	var instance: ShipInstance = ship_node.get_ship_instance()
	if instance == null or instance.ship_data == null:
		return

	# Determine override track based on destroyed ship's faction.
	var destroyed_faction: Constants.Faction = instance.ship_data.faction
	var override_key: String = ""
	match destroyed_faction:
		Constants.Faction.REBEL_ALLIANCE:
			# Rebel ship destroyed → Imperial March (Empire celebrates).
			override_key = "imperial_march"
		Constants.Faction.GALACTIC_EMPIRE:
			# Imperial ship destroyed → Rebel Theme (Rebels celebrate).
			override_key = "rebel_theme"
		_:
			return

	_start_destruction_override(override_key)


# ---------------------------------------------------------------------------
# Shuffled playlist
# ---------------------------------------------------------------------------

## Builds (or reshuffles) the in-game playlist and resets the index.
func _build_playlist() -> void:
	_playlist.clear()
	for i: int in range(1, _in_game_track_count + 1):
		var key: String = "in_game_%d" % i
		if _streams.has(key):
			_playlist.append(key)
	_playlist.shuffle()
	_playlist_index = -1
	_log.info("Playlist shuffled: %d tracks." % _playlist.size())


## Advances to the next track in the playlist. Reshuffles when exhausted.
func _advance_playlist() -> void:
	if _override_active:
		return
	if _playlist.is_empty():
		_build_playlist()
	_playlist_index += 1
	if _playlist_index >= _playlist.size():
		_build_playlist()
		_playlist_index = 0
	var key: String = _playlist[_playlist_index]
	_crossfade_to(key)


## On game_ended, play the winner's faction theme.
## Requirements: MUS-008.
func _on_game_ended(details: Dictionary) -> void:
	_override_active = false
	var winner_index: int = details.get("winner_index", 0)
	# Player 0 = Rebel, Player 1 = Imperial.
	if winner_index == 1:
		play("imperial_march")
	else:
		play("rebel_theme")


## On game_started, shuffle the in-game playlist and start the first track.
## Requirements: MUS-005 — randomised in-game music.
func _on_game_started() -> void:
	_override_active = false
	_build_playlist()
	_advance_playlist()


# ---------------------------------------------------------------------------
# Destruction override
# ---------------------------------------------------------------------------

## Starts a timed destruction override: plays [param key] for the configured
## duration, then resumes the shuffled playlist.
func _start_destruction_override(key: String) -> void:
	_override_active = true
	play(key)
	# Cancel any previous override timer.
	if _override_timer != null and _override_timer.timeout.is_connected(
			_on_override_expired):
		_override_timer.timeout.disconnect(_on_override_expired)
	_override_timer = get_tree().create_timer(_destruction_override_duration)
	_override_timer.timeout.connect(_on_override_expired)


## Called when the destruction override timer expires — resume the playlist.
func _on_override_expired() -> void:
	_override_active = false
	_advance_playlist()


# ---------------------------------------------------------------------------
# Crossfade helpers
# ---------------------------------------------------------------------------

## Crossfade from the current player to the other, loading [param key].
func _crossfade_to(key: String) -> void:
	var outgoing: AudioStreamPlayer = _get_current_player()
	var incoming: AudioStreamPlayer = _get_other_player()

	# Prepare incoming player.
	incoming.stream = _streams[key]
	var track_vol: float = _volumes.get(key, 1.0)
	incoming.volume_db = linear_to_db(track_vol * _volume_multiplier)
	incoming.play()

	# Fade out outgoing.
	if outgoing.playing:
		_fade_out(outgoing)

	# Swap which player is "current."
	_a_is_current = not _a_is_current
	_current_track_key = key


## Fades [param player] to silence over the configured duration via a Tween.
func _fade_out(player: AudioStreamPlayer) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, _fade_duration)
	tween.tween_callback(player.stop)


## Returns the AudioStreamPlayer that is currently audible.
func _get_current_player() -> AudioStreamPlayer:
	return _player_a if _a_is_current else _player_b


## Returns the AudioStreamPlayer that is not currently audible.
func _get_other_player() -> AudioStreamPlayer:
	return _player_b if _a_is_current else _player_a


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

## Creates the two AudioStreamPlayers used for crossfading.
## Connects the [code]finished[/code] signal so playlist tracks auto-advance.
func _create_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = "Master"
	_player_a.finished.connect(_on_player_finished)
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = "Master"
	_player_b.finished.connect(_on_player_finished)
	add_child(_player_b)


## Connects to EventBus signals that drive music changes.
func _connect_signals() -> void:
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.game_ended.connect(_on_game_ended)
	EventBus.game_started.connect(_on_game_started)


## Called when an AudioStreamPlayer finishes its stream (non-looping tracks).
## Advances the playlist if the finished player is the current one and the
## track that ended was an in-game playlist track.
func _on_player_finished() -> void:
	if _current_track_key.begins_with("in_game_"):
		_advance_playlist()


## Loads and parses the music section of sound_config.json.
func _load_config() -> void:
	var json_text: String = FileAccess.get_file_as_string(CONFIG_PATH)
	if json_text.is_empty():
		_log.error("Failed to load sound config from %s" % CONFIG_PATH)
		return

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		_log.error("Failed to parse sound config: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data

	# --- In-game track count (how many in_game_N entries to expect) ---
	_in_game_track_count = int(data.get("in_game_track_count", 12))

	# --- Music entries ---
	if data.has("music"):
		var music_section: Dictionary = data["music"]
		for key: String in music_section.keys():
			var entry: Dictionary = music_section[key]
			var path: String = entry.get("path", "")
			if path.is_empty():
				continue
			var stream: AudioStream = load(path)
			if stream == null:
				_log.warn("Could not load music stream: %s" % path)
				continue
			# In-game playlist tracks do NOT loop — the finished signal
			# advances to the next track. Menu/override/victory tracks loop.
			var is_playlist_track: bool = key.begins_with("in_game_")
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = not is_playlist_track
			elif stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = not is_playlist_track
			_streams[key] = stream
			_volumes[key] = float(entry.get("volume", 1.0))

	# --- Global settings ---
	_fade_duration = float(data.get("music_fade_duration_s", 3.0))
	_destruction_override_duration = float(
			data.get("destruction_override_duration_s", 60.0))

	_log.info("Loaded %d music tracks. Fade: %.1fs, override: %.0fs."
			% [_streams.size(), _fade_duration, _destruction_override_duration])

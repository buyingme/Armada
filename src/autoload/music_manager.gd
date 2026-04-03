## Music Manager
##
## Singleton that handles background music playback with crossfade transitions,
## score-based in-game track switching, destruction overrides, and victory music.
##
## Track selection logic during gameplay:
##   - Scores tied → draw_in_game
##   - Imperial leads → imperial_lead_in_game
##   - Rebel leads → rebel_lead_in_game
## Capital-ship destruction temporarily overrides the track for a configurable
## duration, then the score-based track resumes.
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

## True while a destruction override is active (prevents score-based switching).
var _override_active: bool = false

## Timer for destruction override expiry.
var _override_timer: SceneTreeTimer = null

## Scoring calculator for score-based music.
var _scoring: ScoringCalculator = ScoringCalculator.new()


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


## Recalculate scores and switch in-game track when a squadron is destroyed.
func _on_squadron_destroyed(_squadron_node: Node) -> void:
	_update_score_music()


## Recalculate scores and switch in-game track when any score-relevant event
## occurs (shield/hull changes eventually lead here through destruction signals).
func _update_score_music() -> void:
	if _override_active:
		return
	var state: GameState = GameManager.current_game_state
	if state == null:
		return

	var score_0: int = _scoring.calculate_score(0, state)
	var score_1: int = _scoring.calculate_score(1, state)

	var track_key: String = ""
	if score_0 == score_1:
		track_key = "draw_in_game"
	elif score_1 > score_0:
		# Player 1 (Imperial) leads.
		track_key = "imperial_lead_in_game"
	else:
		# Player 0 (Rebel) leads.
		track_key = "rebel_lead_in_game"

	play(track_key)


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


## On game_started, start the draw (neutral) in-game track.
## Requirements: MUS-005 — game starts at 0-0 (tied).
func _on_game_started() -> void:
	_override_active = false
	play("draw_in_game")


# ---------------------------------------------------------------------------
# Destruction override
# ---------------------------------------------------------------------------

## Starts a timed destruction override: plays [param key] for the configured
## duration, then resumes score-based music.
func _start_destruction_override(key: String) -> void:
	_override_active = true
	play(key)
	# Cancel any previous override timer.
	if _override_timer != null and _override_timer.timeout.is_connected(
			_on_override_expired):
		_override_timer.timeout.disconnect(_on_override_expired)
	_override_timer = get_tree().create_timer(_destruction_override_duration)
	_override_timer.timeout.connect(_on_override_expired)


## Called when the destruction override timer expires — resume score logic.
func _on_override_expired() -> void:
	_override_active = false
	_update_score_music()


# ---------------------------------------------------------------------------
# Crossfade helpers
# ---------------------------------------------------------------------------

## Crossfade from the current player to the other, loading [param key].
func _crossfade_to(key: String) -> void:
	var outgoing: AudioStreamPlayer = _get_current_player()
	var incoming: AudioStreamPlayer = _get_other_player()

	# Prepare incoming player.
	incoming.stream = _streams[key]
	incoming.volume_db = linear_to_db(_volumes.get(key, 1.0))
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
func _create_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = "Master"
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = "Master"
	add_child(_player_b)


## Connects to EventBus signals that drive music changes.
func _connect_signals() -> void:
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.squadron_destroyed.connect(_on_squadron_destroyed)
	EventBus.game_ended.connect(_on_game_ended)
	EventBus.game_started.connect(_on_game_started)


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
			_streams[key] = stream
			_volumes[key] = float(entry.get("volume", 1.0))

	# --- Global settings ---
	_fade_duration = float(data.get("music_fade_duration_s", 3.0))
	_destruction_override_duration = float(
			data.get("destruction_override_duration_s", 60.0))

	_log.info("Loaded %d music tracks. Fade: %.1fs, override: %.0fs."
			% [_streams.size(), _fade_duration, _destruction_override_duration])

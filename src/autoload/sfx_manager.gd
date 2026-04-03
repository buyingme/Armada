## SFX Manager
##
## Singleton that handles all sound-effect playback.
## Loads sound assets and per-clip volumes from sound_config.json.
## Provides fire-and-forget `play_sfx()` for one-shots and
## `play_rhythmic()` for multi-burst patterns (e.g. squadron shooting).
##
## Requirements: SFX-001 … SFX-010.
extends Node


## Path to the central sound configuration file.
const CONFIG_PATH: String = "res://Resources/Sound/sound_config.json"

## Maximum number of simultaneous SFX voices (pooled AudioStreamPlayers).
const POOL_SIZE: int = 8

var _log: GameLogger = GameLogger.new("SfxManager")

## Preloaded streams keyed by their config name (e.g. "droid_sound").
var _streams: Dictionary = {}

## Per-clip linear volume (0.0–1.0) keyed by config name.
var _volumes: Dictionary = {}

## Rhythm arrays keyed by rhythm name (e.g. "rebel_squadron_rhythm_ms").
var _rhythms: Dictionary = {}

## Last-known shield values keyed by "<ship_id>:<zone>".
## Used to detect shield decreases for SFX.
var _shield_cache: Dictionary = {}

## Pool of reusable AudioStreamPlayer nodes.
var _pool: Array[AudioStreamPlayer] = []

## Index of the next player to use (round-robin).
var _pool_index: int = 0


func _ready() -> void:
	_load_config()
	_create_pool()
	_connect_signals()


## Plays a single SFX clip identified by [param key] (must match a key in
## sound_config.json → sfx).
func play_sfx(key: String) -> void:
	if not _streams.has(key):
		_log.warn("Unknown SFX key: %s" % key)
		return
	var player: AudioStreamPlayer = _acquire_player()
	player.stream = _streams[key]
	player.volume_db = linear_to_db(_volumes.get(key, 1.0))
	player.play()


## Plays a rhythmic burst of the same clip, separated by the intervals defined
## in the rhythm array.  The first shot plays immediately; subsequent shots
## follow after each interval in [param rhythm_key] (an array of pause
## durations in ms stored in sound_config.json → sfx_rhythms).
func play_rhythmic(sfx_key: String, rhythm_key: String) -> void:
	if not _streams.has(sfx_key):
		_log.warn("Unknown SFX key for rhythmic play: %s" % sfx_key)
		return
	if not _rhythms.has(rhythm_key):
		_log.warn("Unknown rhythm key: %s" % rhythm_key)
		return

	var intervals: Array = _rhythms[rhythm_key]
	# First shot is immediate.
	play_sfx(sfx_key)
	# Schedule remaining shots via one-shot timers.
	var cumulative_ms: float = 0.0
	for i: int in range(intervals.size()):
		cumulative_ms += float(intervals[i])
		var timer: SceneTreeTimer = get_tree().create_timer(cumulative_ms / 1000.0)
		timer.timeout.connect(play_sfx.bind(sfx_key))


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Loads and parses sound_config.json, pre-loading all SFX streams.
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

	# --- SFX entries ---
	if data.has("sfx"):
		var sfx_section: Dictionary = data["sfx"]
		for key: String in sfx_section.keys():
			var entry: Dictionary = sfx_section[key]
			var path: String = entry.get("path", "")
			if path.is_empty():
				continue
			var stream: AudioStream = load(path)
			if stream == null:
				_log.warn("Could not load SFX stream: %s" % path)
				continue
			_streams[key] = stream
			_volumes[key] = float(entry.get("volume", 1.0))

	# --- Rhythm arrays ---
	if data.has("sfx_rhythms"):
		var rhythm_section: Dictionary = data["sfx_rhythms"]
		for key: String in rhythm_section.keys():
			if key.begins_with("_"):
				continue
			_rhythms[key] = rhythm_section[key]

	_log.info("Loaded %d SFX streams, %d rhythms." % [_streams.size(), _rhythms.size()])


## Creates the pool of AudioStreamPlayer nodes.
func _create_pool() -> void:
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


## Returns the next available player from the pool (round-robin).
func _acquire_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return player


## Connects to EventBus signals that trigger automatic SFX.
func _connect_signals() -> void:
	EventBus.squadron_moved.connect(_on_squadron_moved)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.squadron_destroyed.connect(_on_squadron_destroyed)
	EventBus.squadron_hull_changed.connect(_on_squadron_hull_changed)
	EventBus.damage_card_dealt.connect(_on_damage_card_dealt)
	EventBus.ship_shields_changed.connect(_on_ship_shields_changed)


## Plays a faction-appropriate flyby sound when a squadron moves.
## Requirements: SFX-008, SFX-009.
func _on_squadron_moved(token: Node) -> void:
	if not token or not token.has_method("get_squadron_instance"):
		return
	var inst: SquadronInstance = token.get_squadron_instance()
	if inst == null or inst.squadron_data == null:
		play_sfx("x_wing_flyby")
		return
	match inst.squadron_data.faction:
		Constants.Faction.GALACTIC_EMPIRE:
			play_sfx("tie_flyby")
		_:
			play_sfx("x_wing_flyby")


## Plays the ship-destroyed SFX when a ship is eliminated.
## Requirements: SFX-011.
func _on_ship_destroyed(_ship: Node) -> void:
	play_sfx("ship_destroyed")


## Plays the squadron hull-damage SFX when a squadron takes damage.
## Requirements: SFX-012.
func _on_squadron_hull_changed(_squadron_instance: RefCounted, _new_hull: int) -> void:
	play_sfx("squad_hull_damage")


## Plays the squadron hull-damage SFX when a squadron is destroyed.
## Requirements: SFX-012.
func _on_squadron_destroyed(_squadron: Node) -> void:
	play_sfx("squad_hull_damage")


## Plays the ship hull-damage SFX when a damage card is dealt to a ship.
## Requirements: SFX-013.
func _on_damage_card_dealt(
		_ship_instance: RefCounted,
		_card: RefCounted,
		_is_faceup: bool,
) -> void:
	play_sfx("ship_hull_damage")


## Plays the shield-deflect SFX when a ship's shields decrease.
## Compares against a cached value to distinguish hits from repairs.
## Requirements: SFX-014.
func _on_ship_shields_changed(
		ship_instance: RefCounted,
		zone: String,
		new_value: int,
) -> void:
	var key: String = "%s:%s" % [str(ship_instance.get_instance_id()), zone]
	var old_value: int = _shield_cache.get(key, new_value + 1) as int
	_shield_cache[key] = new_value
	if new_value < old_value:
		play_sfx("shield_deflect")

## Game Scale
##
## Establishes the pixel-to-game-unit scale for the entire application.
## All physical measurements derive from the range ruler's total pixel length.
##
## The range ruler in the physical game is 1 foot (305 mm). The play area for
## the Learning Scenario is 3' × 3'. Component sizes are defined as ratios of
## the ruler length, using real-world millimetre measurements from the physical
## game pieces.
##
## Rules Reference: "Setup", p.11 — play area dimensions and ruler usage.
extends Node


## Path to the JSON file containing user-measured pixel calibration data.
const SCALE_CONFIG_PATH: String = "res://Resources/Game_Components/scale/scale_config.json"

## Real-world ruler length in millimetres (1 foot).
const RULER_MM: float = 305.0

## Real-world base dimensions in millimetres.
## Rules Reference: "Ship Bases", p.12
const SMALL_BASE_WIDTH_MM: float = 43.0
const SMALL_BASE_LENGTH_MM: float = 71.0
const MEDIUM_BASE_WIDTH_MM: float = 63.0
const MEDIUM_BASE_LENGTH_MM: float = 102.0
const LARGE_BASE_WIDTH_MM: float = 77.5
const LARGE_BASE_LENGTH_MM: float = 129.0
const SQUADRON_BASE_DIAMETER_MM: float = 41.0

## Number of maneuver tool segments.
const MANEUVER_SEGMENTS: int = 5

## Play area multiplier (Learning Scenario = 3 ruler lengths per side).
const PLAY_AREA_RULER_MULTIPLIER: float = 3.0

## Logger for this system.
var _log: GameLogger = GameLogger.new("GameScale")

# --- Pixel values (set by _load_scale_config) ---

## Total range ruler length in pixels — the master scale reference.
var ruler_length_px: float = 0.0

## Range band boundaries in pixels (measured from ruler start).
var range_close_px: float = 0.0
var range_medium_px: float = 0.0
var range_long_px: float = 0.0

## Distance band boundaries in pixels (5 bands, measured from ruler start).
var distance_bands_px: Array[float] = []

## Play area side length in pixels (ruler × multiplier).
var play_area_side_px: float = 0.0

## Ship base dimensions in pixels.
var small_base_width_px: float = 0.0
var small_base_length_px: float = 0.0
var medium_base_width_px: float = 0.0
var medium_base_length_px: float = 0.0
var large_base_width_px: float = 0.0
var large_base_length_px: float = 0.0

## Squadron base diameter in pixels.
var squadron_base_diameter_px: float = 0.0

## Maneuver tool segment length in pixels.
var maneuver_segment_px: float = 0.0

## Source-PNG base region sizes (measured pixel spans of the base boundary
## within each token image). Used to compute per-axis sprite scale factors so
## the artwork aligns exactly with the game-scale bounding boxes.
var small_base_region_width_px: float = 0.0
var small_base_region_length_px: float = 0.0
var medium_base_region_width_px: float = 0.0
var medium_base_region_length_px: float = 0.0
var squadron_base_region_diameter_px: float = 0.0

## Whether scale data was loaded and computed successfully.
var is_initialised: bool = false


func _ready() -> void:
	_load_scale_config()


## Loads scale_config.json and computes all derived pixel values.
func _load_scale_config() -> void:
	var config: Dictionary = _read_config_file()
	if config.is_empty():
		_log.warn("Scale config not loaded — using zero values")
		return

	ruler_length_px = float(config.get("ruler_total_length_px", 0))
	if ruler_length_px <= 0.0:
		_log.error("ruler_total_length_px must be > 0, got %s" % ruler_length_px)
		return

	# Range bands (from measured pixel boundaries).
	var bands: Dictionary = config.get("range_bands", {})
	range_close_px = float(bands.get("close", {}).get("max_px", 0))
	range_medium_px = float(bands.get("medium", {}).get("max_px", 0))
	range_long_px = float(bands.get("long", {}).get("max_px", 0))

	# Distance bands.
	var raw_distances: Array = config.get("distance_bands_px", [])
	distance_bands_px.clear()
	for d: Variant in raw_distances:
		distance_bands_px.append(float(d))

	# Derived values.
	play_area_side_px = ruler_length_px * PLAY_AREA_RULER_MULTIPLIER

	small_base_width_px = _mm_to_px(SMALL_BASE_WIDTH_MM)
	small_base_length_px = _mm_to_px(SMALL_BASE_LENGTH_MM)
	medium_base_width_px = _mm_to_px(MEDIUM_BASE_WIDTH_MM)
	medium_base_length_px = _mm_to_px(MEDIUM_BASE_LENGTH_MM)
	large_base_width_px = _mm_to_px(LARGE_BASE_WIDTH_MM)
	large_base_length_px = _mm_to_px(LARGE_BASE_LENGTH_MM)
	squadron_base_diameter_px = _mm_to_px(SQUADRON_BASE_DIAMETER_MM)

	maneuver_segment_px = ruler_length_px / float(MANEUVER_SEGMENTS)

	# Base graphics (measured base region in source PNGs).
	var bg: Dictionary = config.get("base_graphics", {})
	var small_bg: Dictionary = bg.get("small_ship", {})
	small_base_region_width_px = float(small_bg.get("base_region_width_px", 0))
	small_base_region_length_px = float(small_bg.get("base_region_length_px", 0))
	var medium_bg: Dictionary = bg.get("medium_ship", {})
	medium_base_region_width_px = float(medium_bg.get("base_region_width_px", 0))
	medium_base_region_length_px = float(medium_bg.get("base_region_length_px", 0))
	var squad_bg: Dictionary = bg.get("squadron_base", {})
	squadron_base_region_diameter_px = float(squad_bg.get("base_region_diameter_px", 0))

	is_initialised = true
	_log.info("Scale initialised — ruler %s px, play area %s px" % [
		ruler_length_px, play_area_side_px])


## Converts a real-world millimetre value to pixels using the ruler scale.
func _mm_to_px(mm: float) -> float:
	return ruler_length_px * (mm / RULER_MM)


## Returns the base size in pixels as a Vector2 for the given ship size.
## Width is the X axis, length is the Y axis (ship nose points toward -Y).
## Rules Reference: "Ship Bases", p.12
func get_base_size(ship_size: Constants.ShipSize) -> Vector2:
	match ship_size:
		Constants.ShipSize.SMALL:
			return Vector2(small_base_width_px, small_base_length_px)
		Constants.ShipSize.MEDIUM:
			return Vector2(medium_base_width_px, medium_base_length_px)
		Constants.ShipSize.LARGE:
			return Vector2(large_base_width_px, large_base_length_px)
		_:
			_log.error("Base size not defined for ship size %s" % ship_size)
			return Vector2.ZERO


## Returns the range band name for a given pixel distance.
## Rules Reference: "Range and Distance", p.10
func get_range_band(distance_px: float) -> String:
	if distance_px <= range_close_px:
		return "close"
	elif distance_px <= range_medium_px:
		return "medium"
	elif distance_px <= range_long_px:
		return "long"
	else:
		return "beyond"


## Returns the distance band (1-5) for a given pixel distance, or 0 if beyond.
## Rules Reference: "Range and Distance", p.10
func get_distance_band(distance_px: float) -> int:
	for i: int in range(distance_bands_px.size()):
		if distance_px <= distance_bands_px[i]:
			return i + 1
	return 0


## Re-initialises scale from a config dictionary (useful for testing).
func initialise_from_dict(config: Dictionary) -> void:
	ruler_length_px = float(config.get("ruler_total_length_px", 0))
	if ruler_length_px <= 0.0:
		return

	var bands: Dictionary = config.get("range_bands", {})
	range_close_px = float(bands.get("close", {}).get("max_px", 0))
	range_medium_px = float(bands.get("medium", {}).get("max_px", 0))
	range_long_px = float(bands.get("long", {}).get("max_px", 0))

	var raw_distances: Array = config.get("distance_bands_px", [])
	distance_bands_px.clear()
	for d: Variant in raw_distances:
		distance_bands_px.append(float(d))

	play_area_side_px = ruler_length_px * PLAY_AREA_RULER_MULTIPLIER
	small_base_width_px = _mm_to_px(SMALL_BASE_WIDTH_MM)
	small_base_length_px = _mm_to_px(SMALL_BASE_LENGTH_MM)
	medium_base_width_px = _mm_to_px(MEDIUM_BASE_WIDTH_MM)
	medium_base_length_px = _mm_to_px(MEDIUM_BASE_LENGTH_MM)
	large_base_width_px = _mm_to_px(LARGE_BASE_WIDTH_MM)
	large_base_length_px = _mm_to_px(LARGE_BASE_LENGTH_MM)
	squadron_base_diameter_px = _mm_to_px(SQUADRON_BASE_DIAMETER_MM)
	maneuver_segment_px = ruler_length_px / float(MANEUVER_SEGMENTS)

	# Base graphics (from dict — mirrors _load_scale_config logic).
	var bg: Dictionary = config.get("base_graphics", {})
	var small_bg: Dictionary = bg.get("small_ship", {})
	small_base_region_width_px = float(small_bg.get("base_region_width_px", 0))
	small_base_region_length_px = float(small_bg.get("base_region_length_px", 0))
	var medium_bg: Dictionary = bg.get("medium_ship", {})
	medium_base_region_width_px = float(medium_bg.get("base_region_width_px", 0))
	medium_base_region_length_px = float(medium_bg.get("base_region_length_px", 0))
	var squad_bg: Dictionary = bg.get("squadron_base", {})
	squadron_base_region_diameter_px = float(squad_bg.get("base_region_diameter_px", 0))

	is_initialised = true


# --- Private helpers ---

## Reads and parses the JSON config file.
func _read_config_file() -> Dictionary:
	if not FileAccess.file_exists(SCALE_CONFIG_PATH):
		_log.error("Scale config file not found: %s" % SCALE_CONFIG_PATH)
		return {}

	var file: FileAccess = FileAccess.open(SCALE_CONFIG_PATH, FileAccess.READ)
	if not file:
		_log.error("Failed to open scale config: %s" % SCALE_CONFIG_PATH)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		_log.error("JSON parse error in scale config: %s" % json.get_error_message())
		return {}

	if json.data is Dictionary:
		return json.data as Dictionary

	_log.error("Scale config root must be a JSON object")
	return {}


## Returns the per-axis sprite scale for a ship base so the measured base
## region in the source PNG maps exactly to the game-scale base size.
## If base_graphics data is missing, falls back to uniform fit-to-box scaling
## using the raw texture size.
## [param ship_size] — the ship's size class.
## [param tex_size] — the raw pixel size of the ship token texture.
func get_base_sprite_scale(ship_size: Constants.ShipSize, tex_size: Vector2) -> Vector2:
	var target: Vector2 = get_base_size(ship_size)
	if target.x <= 0.0 or target.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var region: Vector2 = _get_base_region(ship_size)
	if region.x <= 0.0 or region.y <= 0.0:
		# Fallback: uniform scale (legacy behaviour).
		var sf: float = minf(target.x / tex_size.x, target.y / tex_size.y)
		return Vector2(sf, sf)
	# Per-axis: scale so that [region] pixels in the source map to [target].
	var sx: float = target.x / region.x
	var sy: float = target.y / region.y
	return Vector2(sx, sy)


## Returns the per-axis sprite scale for a squadron base so the measured base
## region in the source PNG maps exactly to the game-scale diameter.
## [param tex_size] — the raw pixel size of the squadron token texture.
func get_squadron_sprite_scale(tex_size: Vector2) -> Vector2:
	var target_d: float = squadron_base_diameter_px
	if target_d <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var region_d: float = squadron_base_region_diameter_px
	if region_d <= 0.0:
		# Fallback: uniform scale (legacy behaviour).
		var sf: float = target_d / maxf(tex_size.x, tex_size.y)
		return Vector2(sf, sf)
	# Uniform scale using measured base region diameter.
	var sf: float = target_d / region_d
	return Vector2(sf, sf)


## Returns the source-PNG base region size for the given ship size.
func _get_base_region(ship_size: Constants.ShipSize) -> Vector2:
	match ship_size:
		Constants.ShipSize.SMALL:
			return Vector2(small_base_region_width_px, small_base_region_length_px)
		Constants.ShipSize.MEDIUM:
			return Vector2(medium_base_region_width_px, medium_base_region_length_px)
		_:
			# Large base region not yet measured — return zero to trigger fallback.
			return Vector2.ZERO

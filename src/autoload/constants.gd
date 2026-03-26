## Game Constants
##
## Global constants used throughout the Armada game.
## This autoload provides centralized access to all game-wide constant values.
extends Node


## --- Game Rules ---

## Maximum number of game rounds
const MAX_ROUNDS: int = 6

## Maximum fleet point value
const MAX_FLEET_POINTS: int = 400

## Number of players
const PLAYER_COUNT: int = 2

## --- Distance Constants ---
## Pixel values are resolved at runtime by GameScale autoload.
## These string keys match the range band names used in scale_config.json.

const RANGE_BAND_CLOSE: String = "close"
const RANGE_BAND_MEDIUM: String = "medium"
const RANGE_BAND_LONG: String = "long"
const RANGE_BAND_BEYOND: String = "beyond"

## --- Asset Paths ---

const GAME_COMPONENTS_PATH: String = "res://Resources/Game_Components/"
const SHIPS_PATH: String = "res://Resources/Game_Components/ships/"
const SQUADRONS_PATH: String = "res://Resources/Game_Components/squadrons/"
const DICE_PATH: String = "res://Resources/Game_Components/dice/"
const DEFENSE_TOKENS_PATH: String = "res://Resources/Game_Components/defense_tokens/"
const COMMAND_TOKENS_PATH: String = "res://Resources/Game_Components/command_tokens/"
const MAPS_PATH: String = "res://Resources/Game_Components/maps/"
const TOOLS_PATH: String = "res://Resources/Game_Components/tools/"
const SCALE_PATH: String = "res://Resources/Game_Components/scale/"

## --- Physical Dimensions ---
## All physical measurements (mm) are now in scale_config.json.
## Access derived pixel values via the GameScale autoload.

## --- Command Types ---

enum CommandType {
	NAVIGATE,
	SQUADRON,
	CONCENTRATE_FIRE,
	REPAIR,
}

## --- Defense Token Types ---

enum DefenseToken {
	EVADE,
	REDIRECT,
	BRACE,
	SCATTER,
	CONTAIN,
	SALVO,
}

## --- Defense Token States ---

enum DefenseTokenState {
	READY, ## Green - available to use
	EXHAUSTED, ## Red - flipped, must be readied before reuse
	DISCARDED, ## Removed from play for this game
}

## --- Hull Zones ---

enum HullZone {
	FRONT,
	LEFT,
	RIGHT,
	REAR,
}

## --- Ship Sizes ---

enum ShipSize {
	SMALL,
	MEDIUM,
	LARGE,
	HUGE,
}

## --- Dice Colors ---

enum DiceColor {
	RED,
	BLUE,
	BLACK,
}

## --- Dice Faces ---

enum DiceFace {
	BLANK,
	HIT,
	CRITICAL,
	HIT_CRITICAL,
	ACCURACY,
	HIT_HIT,
}

## --- Faction ---

enum Faction {
	REBEL_ALLIANCE,
	GALACTIC_EMPIRE,
	GALACTIC_REPUBLIC,
	SEPARATIST_ALLIANCE,
}

## --- Game Phases ---

enum GamePhase {
	SETUP,
	COMMAND,
	SHIP,
	SQUADRON,
	STATUS,
}

## --- Speed Limits ---

const MAX_SPEED_SMALL: int = 4
const MAX_SPEED_MEDIUM: int = 3
const MAX_SPEED_LARGE: int = 3
const MAX_SPEED_HUGE: int = 2

## --- Command Values by Ship Size ---

const COMMAND_VALUE_SMALL: int = 1
const COMMAND_VALUE_MEDIUM: int = 2
const COMMAND_VALUE_LARGE: int = 3


## Returns the maximum speed for a given ship size.
static func get_max_speed(ship_size: ShipSize) -> int:
	match ship_size:
		ShipSize.SMALL:
			return MAX_SPEED_SMALL
		ShipSize.MEDIUM:
			return MAX_SPEED_MEDIUM
		ShipSize.LARGE:
			return MAX_SPEED_LARGE
		ShipSize.HUGE:
			return MAX_SPEED_HUGE
		_:
			push_error("Unknown ship size: %s" % ship_size)
			return 0


## Hull zone adjacency table.  Two hull zones are adjacent if they share a
## hull-zone line (the boundary between zones on the base).
## Rules Reference: "Hull Zones", p.8 — "adjacent hull zones share a hull
## zone line."
## FRONT↔LEFT, FRONT↔RIGHT, REAR↔LEFT, REAR↔RIGHT.
## FRONT is NOT adjacent to REAR; LEFT is NOT adjacent to RIGHT.
const ADJACENT_HULL_ZONES: Dictionary = {
	HullZone.FRONT: [HullZone.LEFT, HullZone.RIGHT],
	HullZone.LEFT: [HullZone.FRONT, HullZone.REAR],
	HullZone.RIGHT: [HullZone.FRONT, HullZone.REAR],
	HullZone.REAR: [HullZone.LEFT, HullZone.RIGHT],
}


## Returns the hull zones adjacent to [param zone].
## Requirements: AE-DEF-012.
## Rules Reference: "Hull Zones", p.8.
static func get_adjacent_hull_zones(zone: HullZone) -> Array:
	return ADJACENT_HULL_ZONES.get(zone, [])


## Returns the string key ("FRONT", "LEFT", etc.) for a HullZone enum value.
static func hull_zone_to_string(zone: HullZone) -> String:
	match zone:
		HullZone.FRONT:
			return "FRONT"
		HullZone.LEFT:
			return "LEFT"
		HullZone.RIGHT:
			return "RIGHT"
		HullZone.REAR:
			return "REAR"
		_:
			return "FRONT"


## Returns the HullZone enum for a string key ("FRONT", "LEFT", etc.).
static func string_to_hull_zone(zone_str: String) -> HullZone:
	match zone_str.to_upper():
		"FRONT":
			return HullZone.FRONT
		"LEFT":
			return HullZone.LEFT
		"RIGHT":
			return HullZone.RIGHT
		"REAR":
			return HullZone.REAR
		_:
			return HullZone.FRONT


## Defense token type to display name.
const DEFENSE_TOKEN_NAMES: Dictionary = {
	DefenseToken.EVADE: "Evade",
	DefenseToken.REDIRECT: "Redirect",
	DefenseToken.BRACE: "Brace",
	DefenseToken.SCATTER: "Scatter",
	DefenseToken.CONTAIN: "Contain",
	DefenseToken.SALVO: "Salvo",
}

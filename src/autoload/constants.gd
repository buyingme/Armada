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
## Real-world measurements in millimetres, used by GameScale to compute pixels.

const RULER_LENGTH_MM: float = 305.0
const SMALL_BASE_WIDTH_MM: float = 43.0
const SMALL_BASE_LENGTH_MM: float = 71.0
const MEDIUM_BASE_WIDTH_MM: float = 63.0
const MEDIUM_BASE_LENGTH_MM: float = 102.0
const SQUADRON_BASE_DIAMETER_MM: float = 41.0

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

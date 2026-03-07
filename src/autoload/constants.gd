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
## Distance bands in game units (to be calibrated with visual scale)

const DISTANCE_CLOSE: float = 1.0
const DISTANCE_MEDIUM: float = 2.0
const DISTANCE_LONG: float = 3.0

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
	READY,       ## Green - available to use
	EXHAUSTED,   ## Red - flipped, must be readied before reuse
	DISCARDED,   ## Removed from play for this game
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

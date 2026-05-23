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

## Number of squadrons a player activates per turn in the Squadron Phase.
## Rules Reference: "Squadron Phase", RRG p.12; SQ-002.
const SQUADRONS_PER_ACTIVATION: int = 2

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

## --- Command Applicability Scopes (Phase M) ---
##
## Declares the coarse surface where a command may run before command-specific
## validation handles payload and rule details.
enum CommandScope {
	GLOBAL,
	PHASE,
	FLOW_STEP,
}

## --- Interaction Flow (Phase I) ---
##
## Identifies the high-level interactive UI flow currently active.
## Held inside [GameState.interaction_flow]; mutated only by [GameCommand].
## See docs/refactoring_phase_i_plan.md.
enum InteractionFlow {
	NONE,
	COMMAND_PHASE,
	SHIP_ACTIVATION,
	SQUADRON_ACTIVATION,
	ATTACK,
	STATUS_CLEANUP,
	GAME_OVER,
	# Phase I6b-4 — squadron displacement after ship maneuver overlap.
	# Controller is the non-moving player (opposing the maneuvering ship).
	# Rules Reference: RRG "Overlapping", p.8 — OV-002.
	SQUADRON_DISPLACEMENT,
}

## Identifies the specific step within the active [enum InteractionFlow].
## Names mirror the legacy interaction-state string ids one-to-one so the
## I2 invariant test can compare the two paths key-by-key.
enum InteractionStep {
	NONE,
	# Command Phase
	SELECT_DIALS,
	WAIT_FOR_OPPONENT_DIALS,
	# Ship Activation
	WAIT_FOR_SHIP_SELECT,
	ACTIVATION_MODAL_OPEN,
	REVEAL_DIAL,
	SPEND_DIAL,
	MANEUVER_STEP,
	# Ship-activation sub-step markers (set by AdvanceActivationStepCommand).
	SQUADRON_STEP,
	REPAIR_STEP,
	ATTACK_STEP,
	ACTIVATION_DONE,
	# Squadron Phase
	WAIT_FOR_SQUAD_SELECT,
	ACTION_CHOICE,
	SQUAD_MOVE,
	SQUAD_ATTACK,
	# Attack (Phase I3 — populated by AttackFlowFSM)
	ATTACK_DECLARE,
	ATTACK_ROLL,
	ATTACK_MODIFY,
	ATTACK_DEFENSE_TOKENS,
	ATTACK_RESOLVE_DAMAGE,
	ATTACK_CRITICAL_CHOICE,
	# Status / Game Over
	STATUS_CLEANUP_STEP,
	GAME_OVER_STEP,
	# Phase I6b-4 — Squadron Displacement.
	DISPLACEMENT_PLACE,
	# Phase N — Counter choice appended to avoid shifting legacy enum values.
	ATTACK_COUNTER_CHOICE,
}

## Visibility scope of an [InteractionFlow] payload.
enum Visibility {
	ALL,
	OWNER,
	SPECTATOR,
}

## Semantic controller roles for a [FlowSpec] entry.
## [InteractionFlow] stores the resolved player index; FlowSpec stores the
## rule meaning that lets producers derive that index consistently.
enum ControllerRole {
	NONE,
	ACTIVE_PLAYER,
	OPPOSING_PLAYER,
	ATTACKER,
	DEFENDER_OR_ATTACKER,
	PAYLOAD_CONTROLLER,
	EITHER_PLAYER,
	SYSTEM,
}

## Identifies which modal/panel the local viewer's UI should currently
## display.  Computed by [UIProjector] from
## [member GameState.interaction_flow] so the presentation layer can render
## the correct modal without branching on [code]PlayMode.is_network()[/code].
##
## Phase I6b — added with attack-flow projection.
enum ModalKind {
	NONE,
	COMMAND_DIALS,
	ACTIVATION,
	SQUADRON,
	ATTACK_DECLARE,
	ATTACK_ROLL,
	ATTACK_MODIFY,
	ATTACK_DEFENSE_TOKENS,
	ATTACK_RESOLVE_DAMAGE,
	ATTACK_CRITICAL_CHOICE,
	STATUS_CLEANUP,
	GAME_OVER,
	# Phase I6b-4 — squadron displacement after ship-squadron overlap.
	DISPLACEMENT,
	# Phase N — Counter choice appended to avoid shifting legacy modal values.
	ATTACK_COUNTER_CHOICE,
}

## Mapping from legacy interaction-state flow-type strings to
## [enum InteractionFlow] values.  Used by the I2 invariant test to assert
## that the new path matches the old one one-to-one.  Removed in Phase I6.
const LEGACY_FLOW_TYPE_MAP: Dictionary = {
	"": InteractionFlow.NONE,
	"command_phase": InteractionFlow.COMMAND_PHASE,
	"ship_activation": InteractionFlow.SHIP_ACTIVATION,
	"squadron_phase": InteractionFlow.SQUADRON_ACTIVATION,
	"attack": InteractionFlow.ATTACK,
	"status_cleanup": InteractionFlow.STATUS_CLEANUP,
	"game_over": InteractionFlow.GAME_OVER,
}

## Mapping from legacy step-id strings to [enum InteractionStep] values.
## See [const LEGACY_FLOW_TYPE_MAP].
const LEGACY_STEP_ID_MAP: Dictionary = {
	"": InteractionStep.NONE,
	"select_dials": InteractionStep.SELECT_DIALS,
	"wait_for_opponent_dials": InteractionStep.WAIT_FOR_OPPONENT_DIALS,
	"wait_for_ship_select": InteractionStep.WAIT_FOR_SHIP_SELECT,
	"activation_modal_open": InteractionStep.ACTIVATION_MODAL_OPEN,
	"reveal_dial": InteractionStep.REVEAL_DIAL,
	"spend_dial": InteractionStep.SPEND_DIAL,
	"maneuver_step": InteractionStep.MANEUVER_STEP,
	"squadron_step": InteractionStep.SQUADRON_STEP,
	"repair_step": InteractionStep.REPAIR_STEP,
	"attack_step": InteractionStep.ATTACK_STEP,
	"activation_done": InteractionStep.ACTIVATION_DONE,
	"wait_for_squad_select": InteractionStep.WAIT_FOR_SQUAD_SELECT,
	"action_choice": InteractionStep.ACTION_CHOICE,
	"squad_move": InteractionStep.SQUAD_MOVE,
	"squad_attack": InteractionStep.SQUAD_ATTACK,
	"attack_declare": InteractionStep.ATTACK_DECLARE,
	"attack_roll": InteractionStep.ATTACK_ROLL,
	"attack_modify": InteractionStep.ATTACK_MODIFY,
	"attack_defense_tokens": InteractionStep.ATTACK_DEFENSE_TOKENS,
	"attack_resolve_damage": InteractionStep.ATTACK_RESOLVE_DAMAGE,
	"attack_counter_choice": InteractionStep.ATTACK_COUNTER_CHOICE,
	"attack_critical_choice": InteractionStep.ATTACK_CRITICAL_CHOICE,
	"status_cleanup": InteractionStep.STATUS_CLEANUP_STEP,
	"game_over": InteractionStep.GAME_OVER_STEP,
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

## --- Repair (Engineering) Command Costs ---
## Rules Reference: RRG "Engineering", p.4; CM-033–CM-035.

## Cost to move 1 shield between adjacent zones (reduce source, increase target).
const REPAIR_MOVE_SHIELDS_COST: int = 1

## Cost to recover 1 shield point on any hull zone.
const REPAIR_RECOVER_SHIELDS_COST: int = 2

## Cost to discard 1 faceup or facedown damage card.
const REPAIR_HULL_COST: int = 3


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

## EffectContext
##
## Mutable data bag passed through the effect hook pipeline.
## Each hook point populates the context with relevant data; effects
## read and mutate fields to modify game behaviour.
##
## The context is created fresh for each hook invocation and discarded
## afterwards — it carries no persistent state.
##
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
class_name EffectContext
extends RefCounted


## Metadata key for a pending pre-roll die-removal rule id.
const META_PENDING_DIE_REMOVAL_RULE_ID: String = "pending_die_removal_rule_id"
## Metadata key for the pending pre-roll die-removal prompt title.
const META_PENDING_DIE_REMOVAL_TITLE: String = "pending_die_removal_title"
## Metadata key for available pre-roll die-removal colour choices.
const META_AVAILABLE_DIE_COLOURS: String = "available_die_colours"
## Metadata key carrying the player's selected die colour.
const META_CHOSEN_DIE_COLOUR: String = "chosen_die_colour"
## Metadata key recording which die colour a rule removed.
const META_REMOVED_DIE_COLOUR: String = "removed_die_color"


## The hook that is currently being resolved (e.g. &"ATTACK_CALC_DAMAGE").
var hook: StringName = &""

## --- Participants ---

## Attacking unit (ShipInstance or SquadronInstance), or null.
var attacker: RefCounted = null

## Defending unit (ShipInstance or SquadronInstance), or null.
var defender: RefCounted = null

## Hull zone of the attacker (-1 when not applicable / squadron).
var attacking_zone: int = -1

## Hull zone of the defender (-1 when not applicable / squadron).
var defending_zone: int = -1

## --- Dice ---

## Dice pool before rolling.  Keys are Constants.DiceColor, values are int
## counts.  Effects on ATTACK_GATHER_DICE may add or remove dice.
var dice_pool: Dictionary = {}

## Rolled dice results — Array of {"color": DiceColor, "face": DiceFace}.
## Effects on ATTACK_MODIFY_DICE_* may reroll, add, or remove entries.
var dice_results: Array[Dictionary] = []

## --- Damage ---

## Running damage total.  Effects on ATTACK_CALC_DAMAGE may adjust this.
var damage_total: int = 0

## Whether the standard critical effect is allowed.
## The Contain token sets this to false.
var critical_allowed: bool = true

## Whether this is the first damage card being dealt (for crit faceup).
var is_first_damage_card: bool = false

## --- Range ---

## Range band string ("close", "medium", "long", "beyond") for the attack.
var range_band: String = ""

## --- Cancellation ---

## When set to true by an effect, the current action is blocked.
## For example, Escort sets this when an attacker tries to pick a
## non-Escort engaged target.
var cancelled: bool = false

## --- Squadron-specific ---

## Whether the squadron is allowed to move (engagement may block).
var can_move: bool = true

## Whether the squadron must attack an engaged target (Escort constraint).
var must_attack_engaged: bool = false

## The squadron whose activation is being resolved (SquadronInstance).
var activating_squadron: RefCounted = null

## --- Metadata ---

## Free-form dictionary for effects to communicate extra data.
## Example: {"redirect_max": 1} for Xi7 Turbolasers.
var metadata: Dictionary = {}


## Convenience: set a metadata key.
func set_meta_value(key: String, value: Variant) -> void:
	metadata[key] = value


## Convenience: read a metadata key with a default.
func get_meta_value(key: String, default: Variant = null) -> Variant:
	return metadata.get(key, default)

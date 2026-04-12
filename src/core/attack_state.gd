## AttackState
##
## Shared [RefCounted] context that holds mutable state for the current
## attack flow — analogous to [ActivationContext] for ship activations.
##
## [b]F5a[/b] creates this class; [b]F5b[/b] migrates [AttackExecutor]
## member variables here.  Controllers and sub-systems receive a reference
## once (via [code]initialize()[/code]) instead of passing variables on
## every call.
##
## Rules Reference: "Attack", Steps 1–6, pp. 2–3.
class_name AttackState
extends RefCounted


# ---------------------------------------------------------------------------
# Execution mode
# ---------------------------------------------------------------------------

## Whether the current session is an actual attack execution
## (from the activation modal) rather than the free-form simulator.
## Rules Reference: "Attack", Step 1, p. 2.
## Requirements: AE-FLOW-001.
var exec_mode: bool = false

## Whether the executor is in squadron attack execution mode (Squadron Phase).
## When true, the attacker is a squadron (not a ship hull zone).
## Requirements: SQA-ATK-001.
var squad_exec_mode: bool = false

## The [ShipToken] being activated, whose hull zones are the only valid
## attacker choices during attack execution.
## Requirements: AE-FLOW-002.
var exec_ship_token: ShipToken = null

## The [SquadronToken] being activated for attack (Squadron Phase only).
var exec_squad_token: SquadronToken = null


# ---------------------------------------------------------------------------
# Attacker identity
# ---------------------------------------------------------------------------

## The attacking ship token ([code]null[/code] if attacker is a squadron).
var attacker_ship: ShipToken = null

## The attacking hull zone (only valid when [member attacker_ship] is set).
var attacker_zone: int = -1

## The attacking squadron token ([code]null[/code] if attacker is a ship).
var attacker_squadron: SquadronToken = null

## Attacker display name (cached for panel text).
var attacker_name: String = ""

## Attacker zone display name (empty for squadrons).
var attacker_zone_name: String = ""


# ---------------------------------------------------------------------------
# Defender identity
# ---------------------------------------------------------------------------

## The defending ship token ([code]null[/code] if target is a squadron).
var defender_ship: ShipToken = null

## The defending hull zone (only valid when [member defender_ship] is set).
var defender_zone: int = -1

## The defending squadron token ([code]null[/code] if target is a squadron).
var defender_squadron: SquadronToken = null

## Defender display name (cached for panel text).
var defender_name: String = ""

## Defender zone display name (empty for squadrons).
var defender_zone_name: String = ""


# ---------------------------------------------------------------------------
# Attack tracking
# ---------------------------------------------------------------------------

## Hull zones already attacked from during this activation.
## Requirements: AE-2HZ-001.
var fired_zones: Array[int] = []

## Which attack number we are on (0 = first, 1 = second).
## Requirements: AE-2HZ-004.
var current_attack: int = 0

## Squadrons already targeted during the current hull zone's anti-squadron
## attack loop.
## Rules Reference: "Attack", Step 6 — each squadron may be targeted once.
## Requirements: AE-SQ-001.
var attacked_squads: Array[SquadronToken] = []


# ---------------------------------------------------------------------------
# Dice state
# ---------------------------------------------------------------------------

## Dice roll results for the current attack.
## Requirements: AE-DICE-003.
var dice_results: Array[Dictionary] = []

## String-keyed dice pool for the current attack.
## Requirements: AE-DICE-001.
var dice_pool: Dictionary = {}

## Range band of the current attack target.
var range_band: String = ""

## Whether the CF dial has already been used during this activation's attacks.
var cf_dial_used: bool = false

## Whether the CF token has already been used during this activation's attacks.
var cf_token_used: bool = false


# ---------------------------------------------------------------------------
# Accuracy & Defense
# ---------------------------------------------------------------------------

## Indices of defender defense tokens locked by accuracy icons.
## Requirements: AE-ACC-001–008.
var locked_tokens: Array[int] = []

## Whether we are in the accuracy spending sub-step.
var accuracy_step: bool = false

## Whether we are in the defense token spending sub-step.
var defense_step: bool = false

## Defense tokens spent this attack, keyed by [constant Constants.DefenseToken].
## Requirements: AE-DEF-001–016.
var spent_tokens: Dictionary = {}

## Queue of defense token indices being processed during commit.
var defense_commit_queue: Array[int] = []

## Current damage total after defense modifications (brace etc.).
var modified_damage: int = 0

## Whether Scatter was spent this attack (cancels all dice).
var scatter_used: bool = false

## How many damage points must still be redirected (Redirect token).
## Requirements: AE-DEF-011–013.
var redirect_remaining: int = 0

## The hull zone selected for redirect ([constant Constants.HullZone] or −1).
var redirect_zone: int = -1

## Whether the Contain token was spent (prevents standard critical).
## Requirements: AE-DEF-014.
var contain_used: bool = false

## Whether the Brace token was spent this attack.
## Requirements: AE-DEF-010.
var brace_used: bool = false

## Whether we are in the redirect zone click sub-step.
var redirect_step: bool = false

## Whether we are in the evade die-selection sub-step.
var evade_step: bool = false

## Whether the current attack is obstructed.
## Rules Reference: "Obstructed", RRG v1.5.0, p. 10.
## Requirements: AE-OBS-001.
var obstructed: bool = false

## Whether we are in the obstruction die-removal sub-step.
var obstruction_step: bool = false


# ---------------------------------------------------------------------------
# Deferred damage resolution
# ---------------------------------------------------------------------------

## True when the DamageSummaryOverlay is visible and we are waiting for the
## player to dismiss it before resolving immediate card effects.
var awaiting_damage_summary: bool = false

## Faceup card whose immediate effect is deferred until the summary overlay
## is dismissed.
var deferred_immediate_card: DamageCard = null

## Ship instance associated with [member deferred_immediate_card].
var deferred_immediate_ship: ShipInstance = null


# ===========================================================================
# Queries
# ===========================================================================

## Returns [code]true[/code] when an attack execution is in progress.
func is_exec_active() -> bool:
	return exec_mode


## Returns [code]true[/code] when the attacker is a squadron.
func is_squad_attack() -> bool:
	return squad_exec_mode


## Returns [code]true[/code] when an attacker has been selected.
func has_attacker() -> bool:
	return attacker_ship != null or attacker_squadron != null


## Returns [code]true[/code] when a defender has been selected.
func has_defender() -> bool:
	return defender_ship != null or defender_squadron != null


# ===========================================================================
# Lifecycle
# ===========================================================================

## Clears attacker identity fields.
func clear_attacker() -> void:
	attacker_ship = null
	attacker_zone = -1
	attacker_squadron = null
	attacker_name = ""
	attacker_zone_name = ""


## Clears defender identity fields.
func clear_defender() -> void:
	defender_ship = null
	defender_zone = -1
	defender_squadron = null
	defender_name = ""
	defender_zone_name = ""


## Resets dice pool, results, and range band.
func reset_dice() -> void:
	dice_results.clear()
	dice_pool.clear()
	range_band = ""


## Resets the deferred-damage sub-state.
func reset_deferred_damage() -> void:
	awaiting_damage_summary = false
	deferred_immediate_card = null
	deferred_immediate_ship = null


## Partial reset between consecutive attacks within one activation.
## Clears defender identity, dice, and per-attack squad tracking but
## preserves attacker, fired zones, CF usage, and attack counter — those
## span the whole activation.
func reset_for_next_attack() -> void:
	clear_defender()
	reset_dice()
	attacked_squads.clear()


## Full reset — returns every field to its default value.
## Call when an attack flow ends (completion, cancellation, or error).
func clear_all() -> void:
	# Execution mode
	exec_mode = false
	squad_exec_mode = false
	exec_ship_token = null
	exec_squad_token = null
	# Attacker / defender
	clear_attacker()
	clear_defender()
	# Attack tracking
	fired_zones.clear()
	current_attack = 0
	attacked_squads.clear()
	# Dice
	reset_dice()
	cf_dial_used = false
	cf_token_used = false
	# Accuracy & defense
	locked_tokens.clear()
	accuracy_step = false
	defense_step = false
	spent_tokens.clear()
	defense_commit_queue.clear()
	modified_damage = 0
	scatter_used = false
	redirect_remaining = 0
	redirect_zone = -1
	contain_used = false
	brace_used = false
	redirect_step = false
	evade_step = false
	obstructed = false
	obstruction_step = false
	# Deferred damage
	reset_deferred_damage()

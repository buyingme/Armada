## DefenseTokenResolver
##
## Resolves defense token effects during Step 4 of the attack sequence.
## Pure core logic — extends RefCounted, no scene-tree dependency.
##
## Each method applies a specific defense token effect to the attack dice
## pool and/or sets flags that affect damage resolution in Step 5.
##
## Rules Reference: "Defense Tokens", pp. 4–5; "Attack", Step 4.
## Requirements: ATK-S4-001–009.
class_name DefenseTokenResolver
extends RefCounted


## Whether a Brace token was spent (halves damage in Step 5).
var brace_active: bool = false

## Whether a Contain token was spent (blocks standard critical).
var contain_active: bool = false

## The hull zone chosen for Redirect damage shifting (-1 = none).
## Uses Constants.HullZone enum value.
var redirect_zone: int = -1

## Maximum shields that can be redirected (redirect zone's current shields).
var redirect_max_shields: int = 0

## Indices of defense tokens locked by accuracy spending.
var accuracy_locked_indices: Array[int] = []

var _log: GameLogger = GameLogger.new("DefenseTokenResolver")


## Resets all state for a new attack.
func reset() -> void:
	brace_active = false
	contain_active = false
	redirect_zone = -1
	redirect_max_shields = 0
	accuracy_locked_indices.clear()


## Locks a defense token at the given index (from accuracy spending).
## A locked token cannot be spent during this attack.
## Requirements: ATK-S3-002.
func lock_token(index: int) -> void:
	if index not in accuracy_locked_indices:
		accuracy_locked_indices.append(index)
		_log.info("Defense token locked at index %d." % index)


## Returns true if the token at the given index is locked.
func is_token_locked(index: int) -> bool:
	return index in accuracy_locked_indices


## Returns true if the defender can spend defense tokens.
## Speed-0 ships cannot spend tokens.
## Rules Reference: "Defense Tokens" — "If the defender's speed is '0'."
## Requirements: ATK-S4-008.
static func can_defender_spend_tokens(defender_speed: int) -> bool:
	return defender_speed > 0


## Returns the list of spendable token indices for the defender.
## Excludes locked (accuracy) and discarded tokens.
## [param tokens] — Array of { "type": DefenseToken, "state": DefenseTokenState }.
## [param defender_speed] — the defender's current speed.
func get_spendable_tokens(
		tokens: Array[Dictionary],
		defender_speed: int) -> Array[int]:
	if not can_defender_spend_tokens(defender_speed):
		return []
	var result: Array[int] = []
	for i: int in range(tokens.size()):
		if is_token_locked(i):
			continue
		var state: Constants.DefenseTokenState = \
				tokens[i]["state"] as Constants.DefenseTokenState
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		result.append(i)
	return result


## Resolves spending an Evade defense token.
## At long range: cancel 1 die. At medium/close: reroll 1 die.
## [param pool] — the AttackDicePool.
## [param range_band] — "close", "medium", or "long".
## [param die_index] — the defender-chosen die to affect.
## Returns true if the effect was applied.
## Rules Reference: "Defense Tokens" — Evade.
## Requirements: ATK-S4-002.
func resolve_evade(pool: AttackDicePool, range_band: String,
		die_index: int) -> bool:
	if pool.get_results().is_empty():
		return false
	if die_index < 0 or die_index >= pool.get_results().size():
		return false
	if range_band == Constants.RANGE_BAND_LONG:
		pool.remove_die(die_index)
		_log.info("Evade: cancelled die at index %d (long range)." %
				die_index)
		return true
	else:
		pool.reroll_die(die_index)
		_log.info("Evade: rerolled die at index %d (%s range)." %
				[die_index, range_band])
		return true


## Marks Brace as active. Effect applied during damage resolution.
## Rules Reference: "Defense Tokens" — Brace.
## Requirements: ATK-S4-003.
func activate_brace() -> void:
	brace_active = true
	_log.info("Brace activated.")


## Resolves Scatter — cancels all dice in the pool.
## Rules Reference: "Defense Tokens" — Scatter.
## Requirements: ATK-S4-004.
func resolve_scatter(pool: AttackDicePool) -> void:
	pool.cancel_all()
	_log.info("Scatter: all dice cancelled.")


## Activates Redirect to the given adjacent hull zone.
## [param zone] — the Constants.HullZone to redirect damage to.
## [param max_shields] — current shields in that zone.
## Rules Reference: "Defense Tokens" — Redirect.
## Requirements: ATK-S4-005.
func activate_redirect(zone: Constants.HullZone,
		max_shields: int) -> void:
	redirect_zone = int(zone)
	redirect_max_shields = max_shields
	_log.info("Redirect activated to zone %s (max shields=%d)." %
			[Constants.HullZone.keys()[zone], max_shields])


## Marks Contain as active. Blocks standard critical effect.
## Rules Reference: "Defense Tokens" — Contain.
## Requirements: ATK-S4-006.
func activate_contain() -> void:
	contain_active = true
	_log.info("Contain activated.")


## Applies the state change to a defense token when spent.
## Ready → Exhausted; Exhausted → Discarded.
## [param ship] — the ShipInstance or SquadronInstance owning the token.
## [param token_index] — the index in the defense_tokens array.
## Rules Reference: "Defense Tokens" — spending rules.
static func spend_token(ship: RefCounted, token_index: int) -> void:
	var tokens: Array[Dictionary] = ship.defense_tokens
	if token_index < 0 or token_index >= tokens.size():
		return
	var state: Constants.DefenseTokenState = \
			tokens[token_index]["state"] as Constants.DefenseTokenState
	match state:
		Constants.DefenseTokenState.READY:
			ship.exhaust_defense_token(token_index)
		Constants.DefenseTokenState.EXHAUSTED:
			ship.discard_defense_token(token_index)


## Applies Brace to a damage total — halves, rounded up.
## Returns the modified total.
## Rules Reference: "Defense Tokens" — Brace.
func apply_brace(damage: int) -> int:
	if not brace_active:
		return damage
	var result: int = ceili(float(damage) / 2.0)
	_log.info("Brace applied: %d → %d." % [damage, result])
	return result


## Returns true if Redirect is active.
func is_redirect_active() -> bool:
	return redirect_zone >= 0


## Returns the adjacent zone and maximum shields for Redirect.
func get_redirect_info() -> Dictionary:
	return {
		"zone": redirect_zone,
		"max_shields": redirect_max_shields,
	}

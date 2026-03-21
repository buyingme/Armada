## ShipActivationState
##
## Tracks a single ship's activation progress through the five sub-steps
## defined by the rules: Reveal → Squadron → Repair → Attack → Maneuver → Done.
## Pure core logic — extends RefCounted, no scene-tree dependency.
##
## Also manages Navigate command resources (speed budget, yaw bonus)
## available during the Execute Maneuver step.
##
## Rules Reference: RRG "Ship Activation" p.16, "Commands" p.3, "Navigate" p.3.
## Requirements: ACT-002, FLOW-004, NAV-001–008, AC-5b-01.
class_name ShipActivationState
extends RefCounted


## Activation sub-steps in order.
enum Step {
	REVEAL,
	SQUADRON,
	REPAIR,
	ATTACK,
	MANEUVER,
	DONE,
}

## The ship being activated.
var _ship: ShipInstance = null

## Current activation step.
var _current_step: Step = Step.REVEAL

## Set of CommandType values already resolved this activation.
## Prevents double-spending (CM-002).
var _resolved_commands: Dictionary = {}

## Whether a Navigate dial is available (not yet spent this activation).
var _has_navigate_dial: bool = false

## Whether a Navigate token is available (not yet spent this activation).
var _has_navigate_token: bool = false

## Speed change budget remaining from Navigate dial (0 or 1).
var _dial_speed_budget: int = 0

## Speed change budget remaining from Navigate token (0 or 1).
var _token_speed_budget: int = 0

## Whether the yaw bonus from the Navigate dial is still available.
var _yaw_bonus_available: bool = false

## Joint index that received the yaw bonus, or -1 if none.
var _yaw_bonus_joint: int = -1

## Original speed at the start of maneuver (before Navigate changes).
var _original_speed: int = 0

## Total speed change applied so far during this maneuver step.
var _total_speed_change: int = 0

## Whether the maneuver has been executed (committed).
var _maneuver_executed: bool = false

var _log: GameLogger = GameLogger.new("ShipActivationState")


## Creates a new activation state for the given ship.
## Determines Navigate resource availability from the ship's revealed dial
## and command tokens.
## [param ship] — the ShipInstance being activated.
static func create(ship: ShipInstance) -> ShipActivationState:
	var state: ShipActivationState = ShipActivationState.new()
	state._ship = ship
	state._current_step = Step.REVEAL
	state._original_speed = ship.current_speed
	state._resolve_navigate_availability(ship)
	return state


## Returns the current activation step.
func get_current_step() -> Step:
	return _current_step


## Returns the ship being activated.
func get_ship() -> ShipInstance:
	return _ship


## Returns true if the given step is the current step.
func is_at_step(step: Step) -> bool:
	return _current_step == step


## Returns true if activation is complete (step == DONE).
func is_done() -> bool:
	return _current_step == Step.DONE


## Returns true if the maneuver has been committed.
func is_maneuver_executed() -> bool:
	return _maneuver_executed


## Advances to the next step in the activation sequence.
## Returns the new step, or Step.DONE if already done.
func advance_step() -> Step:
	if _current_step == Step.DONE:
		return Step.DONE
	_current_step = int(_current_step) + 1 as Step
	_log.info("Advanced to step: %s" % Step.keys()[_current_step])
	return _current_step


## Skips the current step and advances to the next.
## Alias for advance_step(); used for clarity in placeholder steps.
func skip_step() -> Step:
	return advance_step()


## Marks a command type as resolved for this activation.
## Returns false if already resolved (CM-002).
## Rules Reference: CM-002 — each command resolved at most once per activation.
func mark_command_resolved(command: Constants.CommandType) -> bool:
	if is_command_resolved(command):
		_log.info("Command %s already resolved this activation." %
				Constants.CommandType.keys()[command])
		return false
	_resolved_commands[int(command)] = true
	return true


## Returns true if the given command has already been resolved.
func is_command_resolved(command: Constants.CommandType) -> bool:
	return _resolved_commands.has(int(command))


# ---------------------------------------------------------------------------
# Navigate command — speed changes
# ---------------------------------------------------------------------------


## Returns true if the ship has any Navigate resource (dial or token)
## that has not yet been spent during this maneuver.
## Rules Reference: NAV-001, NAV-008.
func can_change_speed() -> bool:
	return _dial_speed_budget > 0 or _token_speed_budget > 0


## Returns the maximum speed increase still available.
func get_max_speed_increase() -> int:
	return _dial_speed_budget + _token_speed_budget


## Returns the maximum speed decrease still available.
func get_max_speed_decrease() -> int:
	return _dial_speed_budget + _token_speed_budget


## Returns true if a Navigate dial is available (not yet spent).
func has_navigate_dial() -> bool:
	return _has_navigate_dial


## Returns true if a Navigate token is available (not yet spent).
func has_navigate_token() -> bool:
	return _has_navigate_token


## Returns the remaining dial speed budget (0 or 1).
func get_dial_speed_budget() -> int:
	return _dial_speed_budget


## Returns the remaining token speed budget (0 or 1).
func get_token_speed_budget() -> int:
	return _token_speed_budget


## Returns the total speed change applied so far.
func get_total_speed_change() -> int:
	return _total_speed_change


## Returns the original speed before any Navigate changes.
func get_original_speed() -> int:
	return _original_speed


## Returns true if the speed change required only a token (no dial budget used).
## Used for the reddish highlight on the token (NAV-007).
func is_token_only_spend() -> bool:
	if _total_speed_change == 0:
		return false
	return not _has_navigate_dial or _dial_speed_budget == 0 and \
			_token_speed_budget < (_dial_speed_budget + _token_speed_budget)


## Attempts to apply a speed change of +1 or -1 to the ship.
## Consumes Navigate dial budget first, then token budget.
## Enforces speed bounds [0, max_speed].
## Returns true if the change was applied.
## Rules Reference: NAV-002, NAV-003, NAV-004, NAV-005, NAV-008.
func apply_speed_change(delta: int) -> bool:
	if delta == 0:
		return false
	if not can_change_speed():
		_log.info("No Navigate budget remaining for speed change.")
		return false
	var new_speed: int = _ship.current_speed + delta
	if new_speed < 0 or new_speed > _ship.ship_data.max_speed:
		_log.info("Speed change %+d would exceed bounds [0, %d]." %
				[delta, _ship.ship_data.max_speed])
		return false
	# Consume budget: dial first (higher value), then token.
	if delta > 0:
		_consume_budget_for_increase()
	else:
		_consume_budget_for_decrease()
	_ship.set_speed(new_speed)
	_total_speed_change += delta
	_log.info("Speed changed by %+d → %d (dial_budget=%d, token_budget=%d)" %
			[delta, _ship.current_speed, _dial_speed_budget, _token_speed_budget])
	return true


## Returns true if we are currently using token-only for speed changes.
## This is the case when the dial budget is 0 but token budget was used.
func is_using_token_for_speed() -> bool:
	if _total_speed_change == 0:
		return false
	# If we had a dial and still have dial budget, we haven't used token-only.
	# If dial budget is consumed and total change > dial contribution, token was used.
	var original_dial: int = 1 if _has_navigate_dial else 0
	var dial_used: int = original_dial - _dial_speed_budget
	return absi(_total_speed_change) > dial_used


# ---------------------------------------------------------------------------
# Navigate command — yaw bonus
# ---------------------------------------------------------------------------


## Returns true if a yaw bonus is available (Navigate dial not yet used for yaw).
## Rules Reference: NAV-002, NAV-006.
func has_yaw_bonus() -> bool:
	return _yaw_bonus_available


## Applies the +1 yaw bonus to the specified joint.
## Can only be called once per activation (the bonus is consumed).
## Returns true if applied.
## Rules Reference: NAV-002, NAV-006.
func apply_yaw_bonus(joint_index: int) -> bool:
	if not _yaw_bonus_available:
		_log.info("No yaw bonus available.")
		return false
	_yaw_bonus_available = false
	_yaw_bonus_joint = joint_index
	_log.info("Yaw bonus applied to joint %d." % joint_index)
	return true


## Removes the yaw bonus (e.g. player changes their mind). Re-enables it.
func remove_yaw_bonus() -> void:
	if _yaw_bonus_joint >= 0:
		_yaw_bonus_joint = -1
		_yaw_bonus_available = _has_navigate_dial
		_log.info("Yaw bonus removed and re-enabled.")


## Returns the joint index that has the yaw bonus, or -1 if none.
func get_yaw_bonus_joint() -> int:
	return _yaw_bonus_joint


# ---------------------------------------------------------------------------
# Maneuver execution
# ---------------------------------------------------------------------------


## Marks the maneuver as executed (committed).
## After this, the activation can proceed to "End Activation".
## Rules Reference: EXE-001.
func mark_maneuver_executed() -> void:
	_maneuver_executed = true
	if not is_command_resolved(Constants.CommandType.NAVIGATE):
		if _has_navigate_dial or _total_speed_change != 0:
			mark_command_resolved(Constants.CommandType.NAVIGATE)
	_log.info("Maneuver executed.")


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


## Determines Navigate resource availability from the ship's state.
## Called once at creation time.
func _resolve_navigate_availability(ship: ShipInstance) -> void:
	_has_navigate_dial = false
	_has_navigate_token = false
	_dial_speed_budget = 0
	_token_speed_budget = 0
	_yaw_bonus_available = false
	# Check revealed dial.
	if ship.command_dial_stack:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) == Constants.CommandType.NAVIGATE:
			_has_navigate_dial = true
			_dial_speed_budget = 1
			_yaw_bonus_available = true
	# Check command tokens.
	if ship.command_tokens and \
			ship.command_tokens.has_token(Constants.CommandType.NAVIGATE):
		_has_navigate_token = true
		_token_speed_budget = 1
	_log.info("Navigate availability: dial=%s, token=%s, yaw=%s" %
			[str(_has_navigate_dial), str(_has_navigate_token),
			str(_yaw_bonus_available)])


## Consumes one unit of speed budget for an increase (+1).
## Prefers dial budget first.
func _consume_budget_for_increase() -> void:
	if _dial_speed_budget > 0:
		_dial_speed_budget -= 1
	elif _token_speed_budget > 0:
		_token_speed_budget -= 1


## Consumes one unit of speed budget for a decrease (-1).
## Prefers dial budget first.
func _consume_budget_for_decrease() -> void:
	if _dial_speed_budget > 0:
		_dial_speed_budget -= 1
	elif _token_speed_budget > 0:
		_token_speed_budget -= 1

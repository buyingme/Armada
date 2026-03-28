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

## Initial dial speed budget (set once, never decremented).
var _initial_dial_budget: int = 0

## Initial token speed budget (set once, never decremented).
var _initial_token_budget: int = 0

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
## that has not yet been fully committed during this maneuver.
## Speed changes are reversible before commit, so budget is computed
## from the absolute total change vs the maximum available.
## Rules Reference: NAV-001, NAV-008.
func can_change_speed() -> bool:
	var max_budget: int = _initial_dial_budget + _initial_token_budget
	return absi(_total_speed_change) < max_budget or _total_speed_change != 0


## Returns the maximum speed increase still available.
func get_max_speed_increase() -> int:
	var max_budget: int = _initial_dial_budget + _initial_token_budget
	if _total_speed_change >= 0:
		return max_budget - _total_speed_change
	# Currently decreased — can swing all the way back plus budget.
	return max_budget + absi(_total_speed_change)


## Returns the maximum speed decrease still available.
func get_max_speed_decrease() -> int:
	var max_budget: int = _initial_dial_budget + _initial_token_budget
	if _total_speed_change <= 0:
		return max_budget + _total_speed_change # _total is negative
	# Currently increased — can swing all the way back plus budget.
	return max_budget + _total_speed_change


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


## Returns true if the speed change required only a token (no dial available).
## Used for the reddish highlight on the token (NAV-007).
func is_token_only_spend() -> bool:
	if _total_speed_change == 0:
		return false
	# Token-only when there's no dial, or the change exceeds dial capacity.
	return _initial_dial_budget == 0


## Attempts to apply a speed change of +1 or -1 to the ship.
## Speed changes are reversible before commit: clicking +1 then -1
## returns to the original speed with full budget restored.
## Enforces speed bounds [0, max_speed] and total budget.
## Returns true if the change was applied.
## Rules Reference: NAV-002, NAV-003, NAV-004, NAV-005, NAV-008.
func apply_speed_change(delta: int) -> bool:
	if delta == 0:
		return false
	var new_total: int = _total_speed_change + delta
	var max_budget: int = _initial_dial_budget + _initial_token_budget
	if absi(new_total) > max_budget:
		_log.info("Speed change %+d would exceed budget (|%d| > %d)." %
				[delta, new_total, max_budget])
		return false
	var new_speed: int = _original_speed + new_total
	if new_speed < 0 or new_speed > _ship.ship_data.max_speed:
		_log.info("Speed change %+d would exceed bounds [0, %d]." %
				[delta, _ship.ship_data.max_speed])
		return false
	_ship.set_speed(new_speed)
	_total_speed_change = new_total
	_recompute_budgets()
	_log.info("Speed changed by %+d → %d (total_change=%+d, dial_budget=%d, token_budget=%d)" %
			[delta, _ship.current_speed, _total_speed_change,
			_dial_speed_budget, _token_speed_budget])
	return true


## Returns true if we are currently using the token for speed changes.
## This is the case when |total_change| exceeds the initial dial budget.
func is_using_token_for_speed() -> bool:
	if _total_speed_change == 0:
		return false
	return absi(_total_speed_change) > _initial_dial_budget


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
## If speed changes consumed the Navigate token, the token is removed
## from the ship's CommandTokenManager and the UI is notified.
## After this, the activation can proceed to "End Activation".
## Rules Reference: EXE-001, NAV-003, NAV-005, CM-001.
func mark_maneuver_executed() -> void:
	_maneuver_executed = true
	# Spend the Navigate command token if it was consumed for speed changes.
	if is_using_token_for_speed() and _ship and _ship.command_tokens:
		_ship.command_tokens.spend_token(Constants.CommandType.NAVIGATE)
		_has_navigate_token = false
		EventBus.command_tokens_changed.emit(_ship)
		_log.info("Navigate token spent on speed change.")
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
	_initial_dial_budget = 0
	_initial_token_budget = 0
	_yaw_bonus_available = false
	# Check revealed dial.
	if ship.command_dial_stack:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) == Constants.CommandType.NAVIGATE:
			_has_navigate_dial = true
			_dial_speed_budget = 1
			_initial_dial_budget = 1
			_yaw_bonus_available = true
	# Check command tokens.
	if ship.command_tokens and \
			ship.command_tokens.has_token(Constants.CommandType.NAVIGATE):
		_has_navigate_token = true
		_token_speed_budget = 1
		_initial_token_budget = 1
	_log.info("Navigate availability: dial=%s, token=%s, yaw=%s" %
			[str(_has_navigate_dial), str(_has_navigate_token),
			str(_yaw_bonus_available)])


## Recomputes dial/token budgets based on the current total speed change.
## Dial budget is consumed first; token is consumed only when
## |total_change| exceeds the initial dial budget.
func _recompute_budgets() -> void:
	var abs_change: int = absi(_total_speed_change)
	# Dial consumed first.
	var dial_used: int = mini(abs_change, _initial_dial_budget)
	_dial_speed_budget = _initial_dial_budget - dial_used
	# Token consumed for the remainder.
	var token_used: int = mini(abs_change - dial_used, _initial_token_budget)
	_token_speed_budget = _initial_token_budget - token_used

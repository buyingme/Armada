## ActivationContext
##
## Lightweight RefCounted that holds the shared activation state for the
## currently-activating ship.  Replaces the pair of member variables
## [code]_activating_ship_token[/code] and [code]_ship_activation_state[/code]
## that were scattered across [code]game_board.gd[/code].
##
## Controllers that need activation state receive a reference to this
## context once via [code]initialize()[/code] instead of being passed
## separate arguments on every call.
##
## Rules Reference: "Ship Phase", p. 5 — "The ship performs each step of
## its activation in order."
class_name ActivationContext
extends RefCounted


## Emitted when the active ship changes (set or cleared).
signal activation_changed


## The [ShipToken] scene node currently being activated.
## [code]null[/code] when no ship is activating.
var activating_ship_token: ShipToken = null

## The [ShipActivationState] tracker for the current activation.
## [code]null[/code] when no ship is activating.
var ship_activation_state: ShipActivationState = null

## Whether the last committed maneuver resulted in a ship–ship overlap.
## Set by the maneuver overlap resolver and consumed by migrated maneuver
## damage-card rule observers.
var last_maneuver_overlapped: bool = false


## Returns [code]true[/code] when a ship activation is in progress.
func is_active() -> bool:
	return activating_ship_token != null and ship_activation_state != null


## Begins a new activation — stores the token and creates the matching
## [ShipActivationState].
## [param token] — the ship token being activated.
## [param state] — the pre-built [ShipActivationState] for this activation.
func set_active(token: ShipToken, state: ShipActivationState) -> void:
	activating_ship_token = token
	ship_activation_state = state
	last_maneuver_overlapped = false
	activation_changed.emit()


## Ends the current activation — clears all fields.
func clear() -> void:
	activating_ship_token = null
	ship_activation_state = null
	last_maneuver_overlapped = false
	activation_changed.emit()

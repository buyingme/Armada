## SquadronCommandResolver
##
## Pure-logic resolver for the Squadron command during ship activation.
## Determines how many friendly squadrons the ship can activate based on
## its revealed command dial and/or Squadron command token, then tracks
## activation usage and spends the resources on finalize.
##
## Squadrons must be at close–medium range of the ship to be eligible.
## Each activated squadron can move **and** attack in either order.
## Squadrons are chosen and activated one at a time.
##
## Follows the RepairResolver pattern: created during ship activation,
## provides budget queries, and commits resource spending on finalize().
##
## Rules Reference: RRG "Commands", p.4 — Squadron command.
## Requirements: CM-020, CM-021, CM-022.
class_name SquadronCommandResolver
extends RefCounted


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The ship issuing the squadron command.
var _ship: ShipInstance = null

## World-space position of the commanding ship (for range checks).
var _ship_position: Vector2 = Vector2.ZERO

## Whether a Squadron dial is available.
var _has_dial: bool = false

## Whether a Squadron token is available.
var _has_token: bool = false

## Maximum number of squadron activations allowed.
var _max_activations: int = 0

## Number of activations consumed so far.
var _activations_used: int = 0

## Logger for this system.
var _log: GameLogger = GameLogger.new("SqCmdResolver")


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Creates a SquadronCommandResolver for the given ship.
## Examines the ship's revealed dial and command tokens to determine
## available squadron activations.
## [param ship] — the ShipInstance issuing the command.
## [param ship_pos] — world-space position of the ship token.
## Rules Reference: CM-020, CM-021, CM-022.
static func create(ship: ShipInstance,
		ship_pos: Vector2) -> SquadronCommandResolver:
	var resolver: SquadronCommandResolver = SquadronCommandResolver.new()
	resolver._ship = ship
	resolver._ship_position = ship_pos
	resolver._resolve_availability(ship)
	return resolver


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns the maximum number of squadron activations.
func get_max_activations() -> int:
	return _max_activations


## Returns the number of activations remaining.
func get_remaining_activations() -> int:
	return _max_activations - _activations_used


## Returns the number of activations consumed.
func get_activations_used() -> int:
	return _activations_used


## Returns true if a Squadron dial contributes activations.
func has_dial() -> bool:
	return _has_dial


## Returns true if a Squadron token contributes activations.
func has_token() -> bool:
	return _has_token


## Returns true if no dial or token is available (nothing to spend).
func is_empty() -> bool:
	return _max_activations == 0


## Returns true if all activations have been used.
func is_done() -> bool:
	return _activations_used >= _max_activations


## Returns the commanding ship instance.
func get_ship() -> ShipInstance:
	return _ship


## Returns the commanding ship's world position.
func get_ship_position() -> Vector2:
	return _ship_position


# ---------------------------------------------------------------------------
# Range check
# ---------------------------------------------------------------------------

## Returns true if a squadron at [param squad_pos] is within
## close–medium range of the commanding ship.
## Uses centre-to-centre distance minus half the ship's longest dimension
## and squadon radius as an approximation of edge-to-edge distance.
## The threshold is [code]GameScale.range_medium_px[/code].
## Rules Reference: CM-021 — "at close–medium range of the ship".
func is_squadron_in_range(squad_pos: Vector2) -> bool:
	var medium_px: float = GameScale.range_medium_px
	if medium_px <= 0.0:
		# Fallback if scale not loaded.
		_log.warn("range_medium_px is 0 — allowing all squadrons.")
		return true
	# Approximate edge-to-edge: centre distance minus half of ship's base
	# dimension and squadron radius.
	var ship_half: float = _get_ship_half_length()
	var squad_radius: float = GameScale.squadron_base_diameter_px * 0.5
	var centre_dist: float = _ship_position.distance_to(squad_pos)
	var edge_dist: float = maxf(0.0,
			centre_dist - ship_half - squad_radius)
	return edge_dist <= medium_px


# ---------------------------------------------------------------------------
# Activation tracking
# ---------------------------------------------------------------------------

## Consumes one activation slot.  Returns true if successful.
func use_activation() -> bool:
	if is_done():
		_log.info("Cannot use activation — all %d used." % _max_activations)
		return false
	_activations_used += 1
	_log.info("Activation used: %d / %d." % [
			_activations_used, _max_activations])
	return true


# ---------------------------------------------------------------------------
# Finalize
# ---------------------------------------------------------------------------

## Spends the dial and/or token that were used.
## The dial is always consumed if available (even if 0 activations used).
## The token is consumed only if the dial alone didn't cover all activations,
## or if no dial was available.
## Should be called when the squadron command step finishes.
## Rules Reference: RRG "Commands" — spending rules.
func finalize() -> void:
	# Spend the dial (always consumed if present).
	if _has_dial and _ship.command_dial_stack:
		_ship.command_dial_stack.spend_revealed()
		EventBus.command_dials_changed.emit(_ship)
	# Spend the token if it contributed activations.
	if _has_token:
		if _ship.command_tokens:
			_ship.command_tokens.spend_token(
					Constants.CommandType.SQUADRON)
			EventBus.command_tokens_changed.emit(_ship)
	_log.info(("Squadron command finalized: %d / %d activations used. "
			+"Dial spent=%s, token spent=%s.") % [
			_activations_used, _max_activations,
			str(_has_dial), str(_has_token)])


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Examines the ship's revealed dial and tokens for Squadron resources.
## Dial grants [squadron_value] activations; token grants +1.
## Rules Reference: CM-021, CM-022.
func _resolve_availability(ship: ShipInstance) -> void:
	_has_dial = false
	_has_token = false
	_max_activations = 0

	if ship.command_dial_stack:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) \
				== Constants.CommandType.SQUADRON:
			_has_dial = true
			_max_activations = ship.ship_data.squadron_value

	if ship.command_tokens and \
			ship.command_tokens.has_token(Constants.CommandType.SQUADRON):
		_has_token = true
		_max_activations += 1

	_log.info(("Squadron command availability: dial=%s (sq_val=%d), "
			+"token=%s, max_activations=%d.") % [
			str(_has_dial),
			ship.ship_data.squadron_value if ship.ship_data else 0,
			str(_has_token), _max_activations])


## Returns half the ship's longest base dimension for range approximation.
func _get_ship_half_length() -> float:
	if _ship == null or _ship.ship_data == null:
		return 0.0
	match _ship.ship_data.ship_size:
		Constants.ShipSize.SMALL:
			return GameScale.small_base_length_px * 0.5
		Constants.ShipSize.MEDIUM:
			return GameScale.medium_base_length_px * 0.5
		Constants.ShipSize.LARGE:
			return GameScale.large_base_length_px * 0.5
		_:
			return GameScale.small_base_length_px * 0.5

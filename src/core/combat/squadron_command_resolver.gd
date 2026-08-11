## SquadronCommandResolver
##
## Pure-logic resolver for the Squadron command during ship activation.
## Determines how many friendly squadrons the ship can activate based on
## its revealed command dial and/or Squadron command token. Budget is always
## projected from the canonical ShipInstance; accepted activation commands
## commit the use count, while finalize only reports resource spending.
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

## World-space rotation of the commanding ship in radians.
var _ship_rotation: float = 0.0

## Half-width of the commanding ship's base (pixels).
var _ship_half_width: float = 0.0

## Half-length of the commanding ship's base (pixels).
var _ship_half_length: float = 0.0

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
## [param ship_rot] — world-space rotation of the ship token (radians).
## [param half_w] — half-width of the ship base (pixels).
## [param half_l] — half-length of the ship base (pixels).
## Rules Reference: CM-020, CM-021, CM-022.
static func create(ship: ShipInstance,
		ship_pos: Vector2,
		ship_rot: float,
		half_w: float,
		half_l: float) -> SquadronCommandResolver:
	var resolver: SquadronCommandResolver = SquadronCommandResolver.new()
	resolver._ship = ship
	resolver._ship_position = ship_pos
	resolver._ship_rotation = ship_rot
	resolver._ship_half_width = half_w
	resolver._ship_half_length = half_l
	return resolver


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns the maximum number of squadron activations.
func get_max_activations() -> int:
	return authoritative_capacity(_ship)


## Returns the number of activations remaining.
func get_remaining_activations() -> int:
	return maxi(0, get_max_activations() - get_activations_used())


## Returns the number of activations consumed.
func get_activations_used() -> int:
	return _ship.squadron_command_activations_committed \
			if _ship != null and _ship.has_active_ship_activation() else 0


## Returns true if a Squadron dial contributes activations.
func has_dial() -> bool:
	return _has_squadron_dial(_ship)


## Returns true if a Squadron token contributes activations.
func has_token() -> bool:
	return _has_squadron_token(_ship)


## Returns true if no dial or token is available (nothing to spend).
func is_empty() -> bool:
	return get_max_activations() == 0


## Returns true if all activations have been used.
func is_done() -> bool:
	return get_activations_used() >= get_max_activations()


## Returns the commanding ship instance.
func get_ship() -> ShipInstance:
	return _ship


## Returns the commanding ship's world position.
func get_ship_position() -> Vector2:
	return _ship_position


## Returns the commanding ship's world rotation (radians).
func get_ship_rotation() -> float:
	return _ship_rotation


## Returns the commanding ship's base half-width (pixels).
func get_ship_half_width() -> float:
	return _ship_half_width


## Returns the commanding ship's base half-length (pixels).
func get_ship_half_length() -> float:
	return _ship_half_length


# ---------------------------------------------------------------------------
# Range check
# ---------------------------------------------------------------------------

## Returns true if a squadron at [param squad_pos] is within
## close–medium range of the commanding ship.
## Uses [code]RangeFinder.measure_range_squad_to_ship()[/code] per hull zone
## for accurate polyline edge-to-circle distance measurement.
## The threshold is [code]GameScale.range_medium_px[/code].
## Rules Reference: CM-021 — "at close–medium range of the ship".
func is_squadron_in_range(squad_pos: Vector2) -> bool:
	var medium_px: float = GameScale.range_medium_px
	if medium_px <= 0.0:
		_log.warn("range_medium_px is unavailable — range check fails closed.")
		return false
	var squad_radius: float = GameScale.squadron_base_diameter_px * 0.5
	for zone_val: int in Constants.HullZone.values():
		var zone: Constants.HullZone = zone_val as Constants.HullZone
		var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				_ship_position, _ship_rotation,
				_ship_half_width, _ship_half_length, zone)
		var result: Dictionary = RangeFinder.measure_range_squad_to_ship(
				squad_pos, squad_radius, edge)
		if result["distance"] <= medium_px:
			return true
	return false


# ---------------------------------------------------------------------------
# Canonical query helpers
# ---------------------------------------------------------------------------

## Re-derives current capacity from the ship's live dial, token, and static
## Squadron value. Capacity is intentionally never stored.
static func authoritative_capacity(ship: ShipInstance) -> int:
	if ship == null or ship.ship_data == null:
		return 0
	var capacity: int = ship.ship_data.squadron_value \
			if _has_squadron_dial(ship) else 0
	if _has_squadron_token(ship):
		capacity += 1
	return capacity


## Canonical model-space range query used by ActivateSquadronCommand. It uses
## the same hull-edge-to-squadron-circle measurement as the scene adapter.
static func is_squadron_in_authoritative_range(
		ship: ShipInstance, squadron: SquadronInstance) -> bool:
	if ship == null or squadron == null or ship.ship_data == null:
		return false
	var play_area: Vector2 = GameScale.play_area_size_px
	if play_area.x <= 0.0 or play_area.y <= 0.0 \
			or GameScale.range_medium_px <= 0.0:
		return false
	var base_size: Vector2 = GameScale.get_base_size(ship.ship_data.ship_size)
	var ship_pos: Vector2 = ship.get_pixel_position(play_area)
	var squadron_pos: Vector2 = squadron.get_pixel_position(play_area)
	var squadron_radius: float = GameScale.squadron_base_diameter_px * 0.5
	for zone_value: int in Constants.HullZone.values():
		var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				ship_pos, ship.get_rotation_rad(),
				base_size.x * 0.5, base_size.y * 0.5,
				zone_value as Constants.HullZone)
		var measured: Dictionary = RangeFinder.measure_range_squad_to_ship(
				squadron_pos, squadron_radius, edge)
		if float(measured.get("distance", INF)) <= GameScale.range_medium_px:
			return true
	return false


# ---------------------------------------------------------------------------
# Finalize
# ---------------------------------------------------------------------------

## Spends the dial and/or token that were used.
## The dial is always consumed if available (even if 0 activations used).
## The token is consumed only if at least one activation was used
## (i.e. the player actually chose to spend it).
## Should be called when the squadron command step finishes.
## Rules Reference: RRG "Commands" — spending rules.
func finalize() -> Dictionary:
	# If no activations were used and there's no dial, don't spend anything.
	# The player chose not to use the token.
	var activations_used: int = get_activations_used()
	var max_activations: int = get_max_activations()
	var dial_available: bool = has_dial()
	var token_available: bool = has_token()
	var spent_anything: bool = activations_used > 0
	var result: Dictionary = {}
	# Report the dial spend — caller must submit SpendDialCommand.
	if dial_available and _ship.command_dial_stack:
		result["dial_spent"] = true
		spent_anything = true
	# Report the token spend — caller must submit SpendTokenCommand.
	if token_available and spent_anything:
		result["token_type"] = int(Constants.CommandType.SQUADRON)
	_log.info(("Squadron command finalized: %d / %d activations used. "
			+"Dial spent=%s, token spent=%s.") % [
			activations_used, max_activations,
			str(dial_available), str(token_available)])
	return result


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _has_squadron_dial(ship: ShipInstance) -> bool:
	if ship == null or ship.command_dial_stack == null:
		return false
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	return not revealed.is_empty() \
			and int(revealed.get("command", -1)) \
					== int(Constants.CommandType.SQUADRON)


static func _has_squadron_token(ship: ShipInstance) -> bool:
	return ship != null and ship.command_tokens != null \
			and ship.command_tokens.has_token(Constants.CommandType.SQUADRON)

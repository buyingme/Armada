## RepairResolver
##
## Pure-logic resolver for the Engineering (Repair) command.
## Calculates engineering points from revealed dial and/or command token,
## then validates and applies repair effects: move shields, recover shields,
## and discard damage cards.
##
## Follows the Navigate pattern: created during ship activation, tracks
## point budgets, provides can_*/apply_* method pairs, and commits resource
## spending on finalize.
##
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
class_name RepairResolver
extends RefCounted


## The ship being repaired.
var _ship: ShipInstance = null

## The damage deck (needed to discard repaired cards back into it).
var _damage_deck: DamageDeck = null

## Whether a Repair dial is available.
var _has_repair_dial: bool = false

## Whether a Repair token is available.
var _has_repair_token: bool = false

## Total engineering points available this resolution.
var _total_points: int = 0

## Engineering points remaining to spend.
var _remaining_points: int = 0

## Points contributed by the dial (for tracking which resources to spend).
var _dial_points: int = 0

## Points contributed by the token.
var _token_points: int = 0

## Logger for this system.
var _log: GameLogger = GameLogger.new("RepairResolver")

## Optional EffectRegistry for hook resolution (Power Failure,
## Capacitor Failure, persistent effect unregistration).
var _effect_registry: EffectRegistry = null


## Creates a RepairResolver for the given ship.
## Examines the ship's revealed dial and command tokens to determine
## available engineering points.
## [param ship] — the ShipInstance being repaired.
## [param deck] — the shared DamageDeck for discarding cards.
## [param registry] — optional EffectRegistry for damage card hooks.
## Rules Reference: CM-031, CM-032.
static func create(ship: ShipInstance, deck: DamageDeck,
		registry: EffectRegistry = null) -> RepairResolver:
	var resolver: RepairResolver = RepairResolver.new()
	resolver._ship = ship
	resolver._damage_deck = deck
	resolver._effect_registry = registry
	resolver._resolve_availability(ship)
	return resolver


## Returns the total engineering points available.
func get_total_points() -> int:
	return _total_points


## Returns the remaining engineering points.
func get_remaining_points() -> int:
	return _remaining_points


## Returns the number of points already spent.
func get_points_spent() -> int:
	return _total_points - _remaining_points


## Returns true if a Repair dial contributes points.
func has_repair_dial() -> bool:
	return _has_repair_dial


## Returns true if a Repair token contributes points.
func has_repair_token() -> bool:
	return _has_repair_token


## Returns true if no engineering points are available at all.
func is_empty() -> bool:
	return _total_points == 0


## Returns true if the ship has at least one repairable condition:
## damage cards to discard, or shields below maximum in any zone.
## When false the RepairPanel has nothing to offer, so the step can be
## skipped even when engineering points are available.
## Rules Reference: CM-033, CM-034, CM-035.
func has_any_repair_target() -> bool:
	if _ship == null:
		return false
	if _ship.get_total_damage() > 0:
		return true
	for zone: String in _ship.current_shields:
		if int(_ship.current_shields[zone]) < _ship.get_max_shields(zone):
			return true
	return false


# ---------------------------------------------------------------------------
# Move Shields — 1 engineering point (CM-033)
# ---------------------------------------------------------------------------


## Returns true if the player can afford to move shields.
## Rules Reference: CM-033 — costs 1 engineering point.
func can_move_shields() -> bool:
	return _remaining_points >= Constants.REPAIR_MOVE_SHIELDS_COST


## Returns true if a specific move-shields action is valid:
## from_zone must have >=1 shield, to_zone must be below max, and
## zones must be different.
## [param from_zone] — source hull zone key (e.g. "FRONT").
## [param to_zone] — destination hull zone key.
## Rules Reference: CM-033.
func can_move_shields_between(from_zone: String, to_zone: String) -> bool:
	if not can_move_shields():
		return false
	if from_zone == to_zone:
		return false
	var source_shields: int = int(_ship.current_shields.get(from_zone, 0))
	if source_shields <= 0:
		return false
	var target_shields: int = int(_ship.current_shields.get(to_zone, 0))
	var target_max: int = _ship.get_max_shields(to_zone)
	if target_shields >= target_max:
		return false
	return true


## Moves 1 shield from [param from_zone] to [param to_zone].
## Returns true if successful.
## Rules Reference: CM-033 — reduce one zone by 1, increase another by 1.
func move_shields(from_zone: String, to_zone: String) -> bool:
	if not can_move_shields_between(from_zone, to_zone):
		_log.info("Cannot move shields from %s to %s." % [from_zone, to_zone])
		return false
	_ship.reduce_shields(from_zone, 1)
	_ship.restore_shields(to_zone, 1)
	_remaining_points -= Constants.REPAIR_MOVE_SHIELDS_COST
	EventBus.ship_shields_changed.emit(
			_ship, from_zone,
			int(_ship.current_shields.get(from_zone, 0)))
	EventBus.ship_shields_changed.emit(
			_ship, to_zone,
			int(_ship.current_shields.get(to_zone, 0)))
	EventBus.repair_shields_moved.emit(_ship, from_zone, to_zone)
	_log.info("Moved 1 shield %s → %s (remaining pts: %d)" % [
			from_zone, to_zone, _remaining_points])
	return true


# ---------------------------------------------------------------------------
# Recover Shields — 2 engineering points (CM-034)
# ---------------------------------------------------------------------------


## Returns true if the player can afford to recover a shield.
## Rules Reference: CM-034 — costs 2 engineering points.
func can_recover_shields() -> bool:
	return _remaining_points >= Constants.REPAIR_RECOVER_SHIELDS_COST


## Returns true if a specific zone can receive a recovered shield
## (not already at max).
## [param zone] — hull zone key.
## Rules Reference: CM-034.
func can_recover_shields_on(zone: String) -> bool:
	if not can_recover_shields():
		return false
	var current: int = int(_ship.current_shields.get(zone, 0))
	var max_val: int = _ship.get_max_shields(zone)
	return current < max_val


## Recovers 1 shield on [param zone].
## Returns true if successful.
## Rules Reference: CM-034 — recover 1 shield on any hull zone.
func recover_shields(zone: String) -> bool:
	if not can_recover_shields_on(zone):
		_log.info("Cannot recover shield on %s." % zone)
		return false
	_ship.restore_shields(zone, 1)
	_remaining_points -= Constants.REPAIR_RECOVER_SHIELDS_COST
	EventBus.ship_shields_changed.emit(
			_ship, zone,
			int(_ship.current_shields.get(zone, 0)))
	EventBus.repair_shields_recovered.emit(_ship, zone)
	_log.info("Recovered 1 shield on %s (remaining pts: %d)" % [
			zone, _remaining_points])
	return true


# ---------------------------------------------------------------------------
# Repair Hull — 3 engineering points (CM-035)
# ---------------------------------------------------------------------------


## Returns true if the player can afford to discard a damage card.
## Rules Reference: CM-035 — costs 3 engineering points.
func can_repair_hull() -> bool:
	if _remaining_points < Constants.REPAIR_HULL_COST:
		return false
	return _ship.get_total_damage() > 0


## Returns true if the specific card can be discarded.
## The card must be on the ship (in faceup or facedown damage).
## [param card] — the DamageCard to check.
## Rules Reference: CM-035.
func can_repair_card(card: DamageCard) -> bool:
	if _remaining_points < Constants.REPAIR_HULL_COST:
		return false
	return _ship.faceup_damage.has(card) or _ship.facedown_damage.has(card)


## Discards [param card] from the ship and returns it to the damage deck.
## Unregisters any persistent effect tied to this card.
## Returns true if successful.
## Rules Reference: CM-035 — choose and discard one faceup or facedown card.
func repair_hull(card: DamageCard) -> bool:
	if not can_repair_card(card):
		_log.info("Cannot repair card '%s'." % card.title)
		return false
	# Unregister persistent effect before removing the card.
	if card.is_faceup and _effect_registry:
		DamageCardEffectFactory.unregister_effect(card, _effect_registry)
	var removed: bool = _ship.remove_damage_card(card)
	if not removed:
		_log.error("Failed to remove card '%s' from ship." % card.title)
		return false
	if _damage_deck:
		_damage_deck.discard(card)
	_remaining_points -= Constants.REPAIR_HULL_COST
	EventBus.repair_card_discarded.emit(_ship, card)
	_log.info("Repaired card '%s' (remaining pts: %d)" % [
			card.title, _remaining_points])
	return true


# ---------------------------------------------------------------------------
# Finalize — commit resource spending
# ---------------------------------------------------------------------------


## Finalizes the repair command: spends the dial and/or token.
## Should be called when the player confirms the repair resolution.
## Unspent points are lost (CM-037).
## Rules Reference: CM-037.
func finalize() -> void:
	var spent: int = get_points_spent()
	# Spend the dial (always consumed if available, even if 0 points used).
	if _has_repair_dial and _ship.command_dial_stack:
		_ship.command_dial_stack.spend_revealed()
		EventBus.command_dials_changed.emit(_ship)
	# Spend the token only if token points were actually needed.
	if _has_repair_token and spent > _dial_points:
		if _ship.command_tokens:
			_ship.command_tokens.spend_token(Constants.CommandType.REPAIR)
			EventBus.command_tokens_changed.emit(_ship)
	EventBus.repair_command_resolved.emit(_ship, spent)
	_log.info("Repair finalized: %d/%d points spent." % [spent, _total_points])


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


## Examines the ship's revealed dial and tokens for Repair resources.
## Dial grants full engineering_value; token grants ceil(eng_value / 2).
## Rules Reference: CM-031, CM-032.
func _resolve_availability(ship: ShipInstance) -> void:
	_has_repair_dial = false
	_has_repair_token = false
	_dial_points = 0
	_token_points = 0

	if ship.command_dial_stack:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		if not revealed.is_empty() and \
				int(revealed.get("command", -1)) == Constants.CommandType.REPAIR:
			_has_repair_dial = true
			_dial_points = ship.ship_data.engineering_value

	if ship.command_tokens and \
			ship.command_tokens.has_token(Constants.CommandType.REPAIR):
		_has_repair_token = true
		_token_points = ceili(
				float(ship.ship_data.engineering_value) / 2.0)

	_total_points = _dial_points + _token_points
	_remaining_points = _total_points

	# Hook: CALC_ENGINEERING_VALUE — Power Failure halves engineering.
	if _effect_registry and _total_points > 0:
		var eng_ctx: EffectContext = EffectContext.new()
		eng_ctx.set_meta_value("ship", _ship)
		eng_ctx.set_meta_value("engineering_value", _total_points)
		eng_ctx = _effect_registry.resolve_hook(
				&"CALC_ENGINEERING_VALUE", eng_ctx)
		var modified: int = int(eng_ctx.get_meta_value(
				"engineering_value", _total_points))
		if modified != _total_points:
			_log.info("Engineering value modified: %d → %d (damage effect)"
					% [_total_points, modified])
			_total_points = modified
			_remaining_points = _total_points

	_log.info("Repair availability: dial=%s(%d pts), token=%s(%d pts), total=%d" %
			[str(_has_repair_dial), _dial_points,
			str(_has_repair_token), _token_points, _total_points])

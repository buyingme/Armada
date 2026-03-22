## DamageResolver
##
## Resolves damage from an attack (Step 5): standard critical effect,
## damage totalling with Brace, shield absorption, damage cards, and
## destruction checks.
##
## Pure core logic — extends RefCounted, no scene-tree dependency.
##
## Rules Reference: "Attack", Step 5; "Damage"; "Critical Effects";
## "Destroyed Ships and Squadrons".
## Requirements: ATK-S5-001–006.
class_name DamageResolver
extends RefCounted


## Result of a damage resolution.
class DamageResult:
	extends RefCounted
	## Total raw damage before any modifications.
	var raw_damage: int = 0
	## Total damage after Brace.
	var final_damage: int = 0
	## Shields lost on the defending hull zone.
	var shields_lost_defending: int = 0
	## Shields lost on the redirect zone (if any).
	var shields_lost_redirect: int = 0
	## Number of facedown damage cards dealt.
	var facedown_cards: int = 0
	## Whether the standard critical effect triggered (first card faceup).
	var standard_crit_triggered: bool = false
	## Whether the defender was destroyed.
	var destroyed: bool = false
	## The redirect hull zone used (-1 if none).
	var redirect_zone: int = -1


var _log: GameLogger = GameLogger.new("DamageResolver")


## Resolves damage from a ship-vs-ship attack.
## [param pool] — the AttackDicePool with rolled results.
## [param defense] — the DefenseTokenResolver with active effects.
## [param defender] — the defending ShipInstance.
## [param defending_zone] — the defending hull zone.
## Returns a DamageResult.
## Rules Reference: "Attack", Step 5; "Damage".
## Requirements: ATK-S5-001–005.
func resolve_ship_damage(
		pool: AttackDicePool,
		defense: DefenseTokenResolver,
		defender: ShipInstance,
		defending_zone: Constants.HullZone) -> DamageResult:
	var result: DamageResult = DamageResult.new()

	# Calculate raw damage (hits + crits for ship targets).
	result.raw_damage = pool.calculate_ship_damage()

	# Apply Brace.
	result.final_damage = defense.apply_brace(result.raw_damage)

	if result.final_damage <= 0:
		_log.info("No damage to resolve.")
		return result

	# Determine redirect.
	var redirect_shields: int = 0
	var redirect_zone_enum: Constants.HullZone = Constants.HullZone.FRONT
	if defense.is_redirect_active():
		var info: Dictionary = defense.get_redirect_info()
		result.redirect_zone = info["zone"]
		redirect_zone_enum = info["zone"] as Constants.HullZone
		redirect_shields = info["max_shields"]

	# Standard critical effect check.
	var can_crit: bool = pool.has_critical() and not defense.contain_active
	var first_card_faceup: bool = false

	# Apply damage one point at a time.
	var remaining: int = result.final_damage
	var zone_str: String = Constants.HullZone.keys()[defending_zone]
	var redirect_zone_str: String = ""
	if result.redirect_zone >= 0:
		redirect_zone_str = Constants.HullZone.keys()[
				result.redirect_zone]

	# Redirect: absorb damage on redirect zone shields first.
	if redirect_shields > 0 and remaining > 0:
		var redirect_absorb: int = mini(remaining, redirect_shields)
		var actual: int = defender.reduce_shields(
				redirect_zone_str, redirect_absorb)
		result.shields_lost_redirect = actual
		remaining -= actual
		EventBus.ship_shields_changed.emit(
				defender, redirect_zone_str,
				int(defender.current_shields.get(redirect_zone_str, 0)))

	# Remaining damage hits the defending hull zone's shields first.
	if remaining > 0:
		var shield_absorb: int = defender.reduce_shields(
				zone_str, remaining)
		result.shields_lost_defending = shield_absorb
		remaining -= shield_absorb
		EventBus.ship_shields_changed.emit(
				defender, zone_str,
				int(defender.current_shields.get(zone_str, 0)))

	# Each remaining point becomes a damage card.
	if remaining > 0:
		# Standard crit: first card dealt is faceup.
		if can_crit and not first_card_faceup:
			# Use a placeholder RefCounted for damage cards.
			var crit_card: RefCounted = RefCounted.new()
			defender.add_faceup_damage(crit_card)
			result.standard_crit_triggered = true
			first_card_faceup = true
			remaining -= 1
			result.facedown_cards += 0  # This was a faceup card.
		# Deal remaining as facedown.
		for _i: int in range(remaining):
			var card: RefCounted = RefCounted.new()
			defender.add_facedown_damage(card)
			result.facedown_cards += 1

	# Update hull.
	var new_hull: int = defender.ship_data.hull - \
			defender.get_total_damage()
	EventBus.ship_hull_changed.emit(defender, new_hull)

	# Destruction check.
	if defender.is_destroyed():
		result.destroyed = true
		_log.info("Defender destroyed!")

	_log.info(("Ship damage resolved: raw=%d, final=%d, shields_def=%d, " +
			"shields_redir=%d, cards=%d, crit=%s, destroyed=%s") %
			[result.raw_damage, result.final_damage,
			result.shields_lost_defending, result.shields_lost_redirect,
			result.facedown_cards, str(result.standard_crit_triggered),
			str(result.destroyed)])
	return result


## Resolves damage from a ship-vs-squadron attack.
## [param pool] — the AttackDicePool with rolled results.
## [param defense] — the DefenseTokenResolver with active effects.
## [param defender] — the defending SquadronInstance.
## Returns a DamageResult.
## Rules Reference: "Attack", Step 5 — squadron damage = hits only.
## Requirements: ATK-S5-004.
func resolve_squadron_damage(
		pool: AttackDicePool,
		defense: DefenseTokenResolver,
		defender: RefCounted) -> DamageResult:
	var result: DamageResult = DamageResult.new()

	# Calculate raw damage (hits only for squadron targets).
	result.raw_damage = pool.calculate_squadron_damage()

	# Apply Brace.
	result.final_damage = defense.apply_brace(result.raw_damage)

	if result.final_damage <= 0:
		_log.info("No damage to squadron.")
		return result

	# Apply damage to squadron hull.
	defender.current_hull = maxi(0,
			defender.current_hull - result.final_damage)
	EventBus.squadron_hull_changed.emit(defender, defender.current_hull)

	# Destruction check.
	if defender.current_hull <= 0:
		result.destroyed = true
		_log.info("Squadron destroyed!")

	_log.info("Squadron damage resolved: raw=%d, final=%d, destroyed=%s" %
			[result.raw_damage, result.final_damage,
			str(result.destroyed)])
	return result

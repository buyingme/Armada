## CombatParticipants
##
## Lightweight, immutable-by-convention data class that bundles the attacker
## and defender identity for a single attack interaction.  Created once per
## attacker/target selection and shared across all resolver classes
## ([AttackTargetResolver], future AttackDiceResolver, etc.).
##
## Display-name strings stay in [AttackExecutor] — they are UI concerns.
##
## Rules Reference: "Attack", Steps 1–2, pp.2–3.
class_name CombatParticipants
extends RefCounted


## Human-readable zone names used by LOS endpoint lookup and logging.
const ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}


# ---------------------------------------------------------------------------
# Attacker
# ---------------------------------------------------------------------------

## The attacking ship token, or [code]null[/code] when the attacker is a
## squadron.
var atk_ship: ShipToken = null

## The attacking hull zone ([enum Constants.HullZone]).  Only meaningful
## when [member atk_ship] is set; [code]-1[/code] for squadron attackers.
var atk_zone: int = -1

## The attacking squadron token, or [code]null[/code] when the attacker
## is a ship.
var atk_squad: SquadronToken = null


# ---------------------------------------------------------------------------
# Defender
# ---------------------------------------------------------------------------

## The defending ship token, or [code]null[/code] when the target is a
## squadron.
var def_ship: ShipToken = null

## The defending hull zone ([enum Constants.HullZone]).  Only meaningful
## when [member def_ship] is set; [code]-1[/code] for squadron targets.
var def_zone: int = -1

## The defending squadron token, or [code]null[/code] when the target
## is a ship.
var def_squad: SquadronToken = null


# ---------------------------------------------------------------------------
# Convenience queries
# ---------------------------------------------------------------------------

## Returns [code]true[/code] when the attacker is a ship hull zone.
func atk_is_ship() -> bool:
	return atk_ship != null


## Returns [code]true[/code] when the attacker is a squadron.
func atk_is_squadron() -> bool:
	return atk_squad != null


## Returns [code]true[/code] when the defender is a ship hull zone.
func def_is_ship() -> bool:
	return def_ship != null


## Returns [code]true[/code] when the defender is a squadron.
func def_is_squadron() -> bool:
	return def_squad != null


## Returns the attacker's faction.  Falls back to
## [constant Constants.Faction.REBEL_ALLIANCE] if neither token is set.
func get_atk_faction() -> int:
	if atk_ship:
		return atk_ship.get_faction()
	if atk_squad:
		return atk_squad.get_faction()
	return Constants.Faction.REBEL_ALLIANCE


## Returns the defender's faction.  Falls back to
## [constant Constants.Faction.GALACTIC_EMPIRE] if neither token is set.
func get_def_faction() -> int:
	if def_ship:
		return def_ship.get_faction()
	if def_squad:
		return def_squad.get_faction()
	return Constants.Faction.GALACTIC_EMPIRE


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Creates a fully-populated [CombatParticipants] instance.
static func create(
		p_atk_ship: ShipToken,
		p_atk_zone: int,
		p_atk_squad: SquadronToken,
		p_def_ship: ShipToken,
		p_def_zone: int,
		p_def_squad: SquadronToken) -> CombatParticipants:
	var p: CombatParticipants = CombatParticipants.new()
	p.atk_ship = p_atk_ship
	p.atk_zone = p_atk_zone
	p.atk_squad = p_atk_squad
	p.def_ship = p_def_ship
	p.def_zone = p_def_zone
	p.def_squad = p_def_squad
	return p


## Creates an attacker-only instance (no defender yet).
static func create_attacker_only(
		p_atk_ship: ShipToken,
		p_atk_zone: int,
		p_atk_squad: SquadronToken) -> CombatParticipants:
	var p: CombatParticipants = CombatParticipants.new()
	p.atk_ship = p_atk_ship
	p.atk_zone = p_atk_zone
	p.atk_squad = p_atk_squad
	return p

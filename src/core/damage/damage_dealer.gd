## DamageDealer
##
## Pure-computation helper for damage resolution during the attack
## sequence (Step 5 — "Resolve Damage"). Owns no scene-tree state;
## the [AttackExecutor] orchestrates side effects (EventBus, panels,
## deck draws) using the results returned here.
##
## Extracted from [AttackExecutor] as part of refactoring phase F4d.
##
## Covers:
##   - Final damage calculation (scatter reduction)
##   - Shield absorption calculation
##   - Hull tracking and destruction checks
##   - Ship / squadron damage planning
##   - Damage summary string building
##   - Card dealing decisions (faceup / facedown, persistent, immediate)
##   - Chooser player index for immediate-effect modals
##
## Rules Reference: "Damage", p.4 — "Damage is applied one point at a
## time. Each point reduces one shield, or one damage card is dealt."
class_name DamageDealer
extends RefCounted


# ---------------------------------------------------------------------------
# Final damage
# ---------------------------------------------------------------------------


## Returns the final damage total after accounting for Scatter.
## If scatter was used, damage is reduced to 0.
## Rules Reference: "Scatter", p.14 — "The attack is cancelled."
func calculate_final_damage(modified_damage: int,
		scatter_used: bool) -> int:
	if scatter_used:
		return 0
	return maxi(modified_damage, 0)


# ---------------------------------------------------------------------------
# Shield absorption
# ---------------------------------------------------------------------------


## Returns how many points of damage the shields in the given zone can
## absorb. The result is clamped to [param available_shields].
## Rules Reference: "Damage", p.4 — "Each point of damage reduces one
## shield."
func calculate_shield_absorption(available_shields: int,
		damage: int) -> int:
	return mini(available_shields, maxi(damage, 0))


# ---------------------------------------------------------------------------
# Hull tracking
# ---------------------------------------------------------------------------


## Returns the remaining hull after subtracting total damage from the
## hull value. Can go negative if damage exceeds hull.
## Rules Reference: "Damage", p.4 — ship destroyed when cards >= hull.
func calculate_hull_remaining(hull: int, total_damage: int) -> int:
	return hull - total_damage


## Returns true if the ship should be considered destroyed.
## Rules Reference: DM-003 — destroyed when total damage cards >= hull.
func is_ship_destroyed(hull: int, total_damage: int) -> bool:
	return total_damage >= hull


## Returns true if a squadron is destroyed (hull <= 0).
## Rules Reference: "Squadrons", p.14.
func is_squadron_destroyed(current_hull: int) -> bool:
	return current_hull <= 0


# ---------------------------------------------------------------------------
# Damage planning — ship
# ---------------------------------------------------------------------------


## Computes the full damage resolution plan for a ship attack.
## Returns a dictionary with all computed values that the caller uses
## to execute side effects (shield reduction, card dealing, events).
##
## Keys:
##   "final_damage"     : int — damage after scatter
##   "shield_absorbed"  : int — shields consumed
##   "cards_to_deal"    : int — remaining damage → cards
##   "hull_remaining"   : int — hull after all cards are dealt
##   "is_destroyed"     : bool — ship destroyed?
##
## Rules Reference: "Damage", p.4.
func plan_ship_damage(modified_damage: int, scatter_used: bool,
		available_shields: int, hull: int,
		existing_damage: int) -> Dictionary:
	var final_damage: int = calculate_final_damage(
			modified_damage, scatter_used)
	var shield_absorbed: int = calculate_shield_absorption(
			available_shields, final_damage)
	var cards_to_deal: int = final_damage - shield_absorbed
	var new_total_damage: int = existing_damage + cards_to_deal
	var hull_remaining: int = calculate_hull_remaining(
			hull, new_total_damage)
	var destroyed: bool = is_ship_destroyed(hull, new_total_damage)
	return {
		"final_damage": final_damage,
		"shield_absorbed": shield_absorbed,
		"cards_to_deal": cards_to_deal,
		"hull_remaining": hull_remaining,
		"is_destroyed": destroyed,
	}


# ---------------------------------------------------------------------------
# Damage planning — squadron
# ---------------------------------------------------------------------------


## Computes the damage plan for a squadron (no shields).
## Returns a dictionary with computed values.
##
## Keys:
##   "actual_damage"  : int — clamped to current hull
##   "new_hull"       : int — hull after damage
##   "max_hull"       : int — maximum hull (for display)
##   "is_destroyed"   : bool — squadron destroyed?
##
## Rules Reference: "Squadrons", p.14 — damage goes directly to hull.
func plan_squadron_damage(damage: int, current_hull: int,
		max_hull: int) -> Dictionary:
	var actual_damage: int = mini(maxi(damage, 0), current_hull)
	var new_hull: int = current_hull - actual_damage
	return {
		"actual_damage": actual_damage,
		"new_hull": new_hull,
		"max_hull": max_hull,
		"is_destroyed": is_squadron_destroyed(new_hull),
	}


# ---------------------------------------------------------------------------
# Damage summary strings
# ---------------------------------------------------------------------------


## Builds the human-readable damage summary for the attack panel.
## Rules Reference: display-only, no game rule citation.
func build_damage_summary(zone_str: String, shield_absorbed: int,
		cards_dealt: int, faceup_card_name: String,
		hull_remaining: int, hull_total: int) -> String:
	var summary: String = "%s: %d shield, %d card(s)" % [
			zone_str, shield_absorbed, cards_dealt]
	if faceup_card_name != "":
		summary += " — CRIT: %s" % faceup_card_name
	summary += " | Hull %d/%d" % [hull_remaining, hull_total]
	return summary


## Builds the squadron damage info string for the attack panel.
func build_squadron_damage_info(actual_damage: int,
		current_hull: int, max_hull: int) -> String:
	return "Squadron: %d damage → Hull %d/%d" % [
			actual_damage, current_hull, max_hull]


## Returns the "no damage" info string.
func build_no_damage_info() -> String:
	return "No damage dealt."


# ---------------------------------------------------------------------------
# Card dealing decisions
# ---------------------------------------------------------------------------


## Returns true if the card at the given index in the dealing loop
## should be dealt faceup (standard critical).
## Only the first card (index 0) can be faceup, and only when the
## attack produced a critical result and Contain was not spent.
## Rules Reference: "Damage", p.4 — "The first card is dealt faceup
## if the attack included a critical result."
func should_deal_faceup(card_index: int,
		first_card_faceup: bool) -> bool:
	return card_index == 0 and first_card_faceup


## Returns true if a faceup damage card still has a legacy persistent effect
## that should be registered with the EffectRegistry.
## Delegates to [DamageCardEffectFactory.is_persistent].
## Rules Reference: DM-005 — persistent effects remain while faceup.
func should_register_persistent(card: DamageCard) -> bool:
	return DamageCardEffectFactory.is_persistent(card)


## Returns true if a damage card has an immediate effect that the
## caller should defer for resolution after the dealing loop.
## Delegates to [ImmediateEffectResolver.is_immediate].
## Rules Reference: DM-005 — immediate effects resolve on deal.
func has_immediate_effect(card: DamageCard) -> bool:
	return ImmediateEffectResolver.is_immediate(card)


# ---------------------------------------------------------------------------
# Chooser player index
# ---------------------------------------------------------------------------


## Returns the player index for the given chooser role.
## "owner" means the defender (ship owner), "opponent" means the
## attacker. Returns the opposite player index for "opponent".
## Rules Reference: DM-011 — some immediate effects let the opponent
## choose.
func get_chooser_player_index(chooser: String,
		defender_owner: int) -> int:
	if chooser == "owner":
		return defender_owner
	# "opponent" = the other player.
	return 1 - defender_owner

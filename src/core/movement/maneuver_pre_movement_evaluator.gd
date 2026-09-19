## Pure purpose-specific re-evaluation for post-commitment/pre-movement work.
## It owns no queue or stage state; applicability is re-derived from canonical
## card instances and the active Maneuver execution each time.
class_name ManeuverPreMovementEvaluator
extends RefCounted


static func unresolved_thruster_fissures(ship: ShipInstance) -> Array[String]:
	var result: Array[String] = []
	if ship == null or ship.is_destroyed():
		return result
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	var execution_id: String = str(execution.get("maneuver_execution_id", ""))
	if execution_id.is_empty() \
			or bool(execution.get("final_transform_applied", false)) \
			or not bool(execution.get("navigate_speed_changed", false)):
		return result
	for raw_card: Variant in ship.faceup_damage:
		if not raw_card is DamageCard:
			continue
		var card: DamageCard = raw_card as DamageCard
		if card.is_faceup and card.effect_id == "thruster_fissure" \
				and not card.public_card_ref.is_empty() \
				and card.last_thruster_fissure_execution_id != execution_id:
			result.append(card.public_card_ref)
	return result


static func has_mandatory_work(ship: ShipInstance) -> bool:
	return ship != null and (ship.has_active_immediate_resolution() \
			or not unresolved_thruster_fissures(ship).is_empty())

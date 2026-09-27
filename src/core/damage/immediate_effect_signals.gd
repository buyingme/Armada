## ImmediateEffectSignals
##
## Stateless utility that emits the [EventBus] signals appropriate for
## each immediate damage-card effect after a
## [ResolveImmediateEffectCommand] has executed.
##
## Used by:
##   - [AttackExecutor] (attacker peer in attack flow)
##   - [GameManager._handle_remote_immediate_effect] (passive peer mirror)
##   - [GameBoard] (debug damage tool)
##
## Centralising here ensures every peer fires the same per-`effect_id`
## visuals (damage card flip, hull / shield / speed / dial / token
## refresh) regardless of which code path triggered the resolution.
class_name ImmediateEffectSignals
extends RefCounted


## Emits the visual signals for a resolved immediate damage-card effect.
## [param card] — the damage card that was resolved (now facedown).
## [param ship] — the ship whose card resolved.
## [param result] — the [GameCommand.execute] result dictionary.
static func emit(card: DamageCard, ship: ShipInstance,
		result: Dictionary) -> void:
	if ship == null or card == null:
		return
	var eid: String = result.get("effect_id", "") as String
	var effect: Dictionary = result.get("effect_result", {}) as Dictionary
	var damage: Dictionary = result.get("damage_application", {}) as Dictionary
	match eid:
		"structural_damage":
			EventBus.damage_card_flipped.emit(ship, card, false)
		"projector_misaligned":
			for raw_change: Variant in damage.get("shield_changes", []):
				var change: Dictionary = raw_change as Dictionary
				EventBus.ship_shields_changed.emit(ship,
						str(change.get("zone", "")),
						int(change.get("new_shields", 0)))
			EventBus.damage_card_flipped.emit(ship, card, false)
		"life_support_failure":
			EventBus.command_tokens_changed.emit(ship)
		"injured_crew":
			EventBus.ship_defense_token_changed.emit(ship)
			EventBus.damage_card_flipped.emit(ship, card, false)
		"shield_failure":
			var changes: Array = damage.get("shield_changes", [])
			for sc: Variant in changes:
				var d: Dictionary = sc as Dictionary
				EventBus.ship_shields_changed.emit(
						ship, d.get("zone", ""),
						int(d.get("new_shields", 0)))
			EventBus.damage_card_flipped.emit(ship, card, false)
		"comm_noise":
			var action: String = str(effect.get("comm_noise_action", ""))
			if action == "speed":
				EventBus.ship_speed_changed.emit(
						ship, int(effect.get("new_speed", 0)))
			elif action == "dial":
				EventBus.command_dials_changed.emit(ship)
			EventBus.damage_card_flipped.emit(ship, card, false)

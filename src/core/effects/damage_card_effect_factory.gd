## DamageCardEffectFactory
##
## Creates and registers [DamageCardEffect] instances in the [EffectRegistry]
## when a persistent damage card is dealt faceup, and unregisters them when
## the card is repaired (discarded) or the ship is destroyed.
##
## Rules Reference: RRG "Damage Cards", p.4; "Effect Use and Timing" p.5.
class_name DamageCardEffectFactory
extends RefCounted


## Effect IDs that should still be registered as legacy persistent effects.
## Migrated RuleRegistry cards are intentionally omitted from this list.
const PERSISTENT_EFFECT_IDS: Array[String] = []


## Returns true if the given card should have a persistent effect registered.
static func is_persistent(card: DamageCard) -> bool:
	return card.effect_id in PERSISTENT_EFFECT_IDS


## Creates and registers a [DamageCardEffect] for the given faceup card.
## [param card] — the DamageCard that was dealt faceup.
## [param ship] — the [ShipInstance] that received the card.
## [param registry] — the game's [EffectRegistry].
## [param initiative_player] — index of the player with initiative (for priority).
## Returns the created effect, or null if the card has no persistent effect.
static func register_effect(
		card: DamageCard,
		ship: ShipInstance,
		registry: EffectRegistry,
		initiative_player: int = 0) -> DamageCardEffect:
	if not is_persistent(card):
		return null
	var effect: DamageCardEffect = DamageCardEffect.new()
	effect.effect_id = card.effect_id
	effect.source_id = card.effect_id
	effect.damage_card = card
	effect.owner = ship
	effect.is_optional = false
	# Player priority: 0 = initiative, 1 = non-initiative.
	effect.player_priority = 0 if ship.owner_player == initiative_player else 1
	registry.register(effect)
	return effect


## Unregisters the effect associated with a specific damage card.
## Searches by matching [member DamageCardEffect.damage_card].
## [param card] — the DamageCard being discarded/repaired.
## [param registry] — the game's [EffectRegistry].
## Returns true if an effect was found and unregistered.
static func unregister_effect(
		card: DamageCard,
		registry: EffectRegistry) -> bool:
	for effect: GameEffect in registry.get_all_effects():
		if effect is DamageCardEffect:
			var dce: DamageCardEffect = effect as DamageCardEffect
			if dce.damage_card == card:
				registry.unregister(dce)
				return true
	return false

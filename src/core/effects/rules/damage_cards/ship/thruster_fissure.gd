## Thruster Fissure
##
## Public identifiers for the Thruster Fissure damage card.
## Rules Reference: Damage Card "Thruster Fissure" — "When you change your
## speed by 1 or more, suffer 1 damage." FAQ: Admiral Konstantine's external
## speed change does not trigger this effect.
class_name ThrusterFissure
extends RefCounted


const RULE_ID: String = "damage_card.thruster_fissure"
const EFFECT_ID: String = "thruster_fissure"

## The legacy raw execute_maneuver observer was retired by WP6. Maneuver-owned
## candidate commands now derive applicability and exact-once identity.

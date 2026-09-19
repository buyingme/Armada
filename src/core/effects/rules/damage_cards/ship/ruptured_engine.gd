## Ruptured Engine
##
## Public identifiers for the Ruptured Engine damage card.
## Rules Reference: Damage Card "Ruptured Engine" — "After you execute a
## maneuver, if the speed on your speed dial is greater than 1, suffer 1 damage."
class_name RupturedEngine
extends RefCounted


const RULE_ID: String = "damage_card.ruptured_engine"
const EFFECT_ID: String = "ruptured_engine"

## The legacy raw execute_maneuver observer was retired by WP6. The final
## consequence command re-derives survival, speed, and still-faceup state.

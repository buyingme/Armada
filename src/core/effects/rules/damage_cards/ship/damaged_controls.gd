## Damaged Controls
##
## Public identifiers for the Damaged Controls damage card.
## Rules Reference: Damage Card "Damaged Controls" — "When you overlap a
## ship or obstacle, deal 1 facedown damage card to your ship." FAQ: resolves
## during the Move Ship step while executing a maneuver.
class_name DamagedControls
extends RefCounted


const RULE_ID: String = "damage_card.damaged_controls"
const EFFECT_ID: String = "damaged_controls"

## The legacy caller-supplied did_overlap observer was retired by WP6.
## Authoritative ship/obstacle facts now feed the purpose-specific command.

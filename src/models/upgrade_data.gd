## Upgrade Data
##
## Resource that defines the static data for an upgrade card.
class_name UpgradeData
extends Resource


## The display name of the upgrade.
@export var upgrade_name: String = ""

## The upgrade type/slot (e.g., "Commander", "Title", "Officer", etc.)
@export var upgrade_type: String = ""

## The point cost of this upgrade.
@export var point_cost: int = 0

## Whether this is a unique upgrade (only one per fleet).
@export var is_unique: bool = false

## The faction restriction, if any. Empty means any faction.
@export var faction_restriction: Array = []

## The ship size restriction, if any. Empty means any size.
@export var size_restriction: Array = []

## The text description of the upgrade's effect.
@export var effect_text: String = ""

## Whether this upgrade has been exhausted (for exhaustible upgrades).
@export var is_exhaustible: bool = false

## Modification flag — some upgrades are "Modification" type.
@export var is_modification: bool = false

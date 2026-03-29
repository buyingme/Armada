## GameEffect
##
## Base class for all rule-modifying effects in the game.  Every keyword,
## upgrade card, damage card, and objective card that alters game rules
## is represented as a concrete subclass of GameEffect.
##
## An effect declares which hook points it responds to via [method get_hooks],
## checks applicability via [method should_trigger], and mutates the
## [EffectContext] in [method resolve].
##
## Effects are registered in the [EffectRegistry] at game start (or when a
## card enters play) and unregistered when destroyed / discarded.
##
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
class_name GameEffect
extends RefCounted


## Source categories for effects — used for ordering and identification.
enum EffectSource {
	KEYWORD, ## Squadron keyword (Bomber, Escort, Swarm, …)
	UPGRADE_CARD, ## Ship upgrade card (Title, Commander, Turbolaser, …)
	DAMAGE_CARD, ## Faceup damage card effect
	OBJECTIVE, ## Objective card rule modification
	DEFENSE_TOKEN, ## Defense token effect (future: Salvo, Contain, …)
}


## The category of card / rule that produced this effect.
var source_type: EffectSource = EffectSource.KEYWORD

## Identifier for the source (e.g. "bomber", "xi7_turbolasers").
var source_id: String = ""

## The game entity this effect is attached to (ShipInstance or
## SquadronInstance).  Null for global effects (objectives).
var owner: RefCounted = null

## Whether the player may choose not to use this effect.
## Upgrade-card effects default to optional (ET-004); keyword and damage-
## card effects default to mandatory.
var is_optional: bool = false

## Player priority for simultaneous timing resolution.
## First player (initiative) = 0, second player = 1.
## Rules Reference: ET-002 — first player resolves first.
var player_priority: int = 0


## Returns the hook point names this effect responds to.
## Subclasses must override this.
func get_hooks() -> Array[StringName]:
	return []


## Returns true if this effect should fire for the given [param context].
## Subclasses may override to add conditional checks.
func should_trigger(context: EffectContext) -> bool:
	# Suppress unused-parameter warning — base implementation is intentionally
	# a no-op that subclasses override.
	if context == null:
		return false
	return true


## Mutates [param context] to apply this effect's rule change.
## Subclasses must override this.
func resolve(context: EffectContext) -> void:
	# Suppress unused-parameter warning — base implementation is intentionally
	# a no-op that subclasses override.
	if context == null:
		return

# UX-008 — Obstacle overlap effects lack clear pre-resolution context

Category: High
Area: Obstacle Overlap / Gameplay Feedback
Layer: Command Flow

## Problem

When a ship overlaps an obstacle, the resulting interaction or effect is not always introduced clearly enough for the players to understand why the following gameplay event occurs.

Obstacle resolution may currently proceed directly into a modal, damage-card result, or other obstacle effect. Although the individual interaction may be functional, its context can be unclear.

Before an obstacle effect is resolved, the game should explicitly inform the players that the ship overlapped the specific obstacle and that this overlap triggers the corresponding rule/effect.

This notification should occur before the consequence of the obstacle is applied or presented.

For example:

- Asteroid overlap: notify the players that the ship overlapped an asteroid and that the asteroid rule is now being resolved before the resulting damage card is dealt/presented.
- Other obstacles: notify the players that the relevant obstacle was overlapped and identify the resulting rule/effect before that effect or its associated interaction begins.

The purpose is not to require the player to make an additional gameplay decision. It is to establish clear context for the gameplay event that follows.

In network play, both players should acknowledge this contextual notification before obstacle resolution proceeds.

## Impact

Without explicit context, players may see a modal, damage card, or other gameplay effect without immediately understanding what triggered it.

This makes obstacle resolution harder to follow, particularly when several interactions or effects occur in sequence.

The problem is more significant in network play because one player's screen may progress into an effect before the other player has understood the preceding event.

A synchronized contextual notification would make the causal sequence explicit:

Obstacle overlap → triggered rule/effect → resulting interaction or consequence → continuation.

## Evidence

Observed behavior:

- Obstacle overlap can lead directly into the resulting effect or interaction.
- The following modal or result does not always make its triggering context sufficiently clear.
- Players therefore may need to infer that the event was caused by the preceding obstacle overlap.

Known example:

Asteroid overlap can proceed into the resulting damage-card handling without first clearly communicating that the asteroid overlap triggered that result.

Other obstacle types should be reviewed for the same UX problem.

## Investigation hint

Identify all obstacle-overlap resolution paths and determine how the game currently transitions from detecting/resolving an overlap into the obstacle-specific effect.

The intended player-facing sequence is:

1. The obstacle overlap is established by authoritative gameplay.
2. Players are informed which obstacle was overlapped and which rule/effect is about to resolve.
3. Required players acknowledge the notification.
4. The obstacle-specific effect resolves.
5. Any subsequent interaction or result presentation occurs.
6. Normal enclosing gameplay flow resumes after all required interactions are complete.

In network play, both players should receive and acknowledge the contextual notification before step 4 begins.

Do not implement this by making UI-local state authoritative for obstacle resolution or continuation.

Investigate whether an existing interaction/acknowledgement mechanism can represent the notification while preserving authoritative continuation and decision-equivalent recovery.

The notification text should identify at minimum:

- the obstacle involved;
- that the obstacle was overlapped; and
- the rule/effect that is about to resolve.

The exact wording and presentation can be refined during implementation.

The intended invariant is:

> Before an obstacle-overlap effect resolves, the players are clearly informed that the obstacle overlap triggered that effect and are given the required opportunity to acknowledge that information.

## Resolution

Improvement:

Not yet implemented.

Target behavior: introduce a clear pre-resolution obstacle notification so players understand the cause and upcoming consequence before an obstacle effect is resolved.

Verification:

- Asteroid overlap produces a contextual notification before its damage effect resolves.
- Other obstacle types produce equivalent contextual notification before their respective effects resolve.
- The notification clearly identifies the obstacle and upcoming rule/effect.
- In Hot-Seat, the notification appears at the correct point in obstacle resolution.
- In Network play, both host and client receive the notification.
- In Network play, obstacle resolution does not proceed until both required acknowledgements have occurred.
- Acknowledgement itself does not alter the underlying obstacle result.
- After acknowledgement, the existing authoritative obstacle effect resolves normally.
- Subsequent interactions occur in their correct order.
- If an asteroid results in a face-up damage card, UX-006 face-up-damage presentation occurs after the obstacle notification and resulting damage operation, rather than replacing the obstacle notification.
- Normal maneuver/overlap continuation resumes correctly after all resulting interactions are complete.
- Save/load, reconnect, replay, and recovery implications of the acknowledgement boundary are investigated before implementation.

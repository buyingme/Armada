# UX-006 — Face-up damage cards are not consistently presented for acknowledgement

Category: High
Area: Damage Card Presentation / Gameplay Feedback
Layer: Command Flow

## Problem

Face-up damage cards are not presented consistently across all gameplay paths that deal them.

During the normal attack flow, when a face-up damage card is dealt, the damage card is displayed in a close-up presentation. This makes the result clearly visible to the players before gameplay continues and is the desired behavior.

Other gameplay paths that deal face-up damage cards do not consistently provide the same presentation. For example, when a ship overlaps an asteroid and receives a face-up damage card, the card may only appear next to the ship card without being shown in close-up.

This makes important gameplay results easy to miss and makes it difficult for players to understand which face-up damage card was just dealt and what effect it introduces.

The presentation of a face-up damage card should not depend on the gameplay path that caused the card to be dealt.

Whenever a face-up damage card is dealt:

- the newly dealt face-up damage card should be presented clearly in close-up;
- the presentation should occur for both players in network play, including host and client;
- both players should have an opportunity to inspect and acknowledge the result;
- gameplay should resume only after the required acknowledgements have been received;
- the behavior should be consistent regardless of whether the damage originated from an attack, obstacle overlap, or another gameplay effect.

The existing normal-attack face-up damage presentation represents the desired player experience.

## Impact

Players can currently miss face-up damage cards dealt outside the normal attack flow.

This is especially problematic because face-up damage cards can introduce ongoing or immediate gameplay effects. A card being correctly added to canonical game state is not sufficient player feedback if the players can easily overlook that the card was dealt.

In network play, inconsistent presentation may also result in one player noticing a newly dealt card while the other player does not.

A consistent acknowledgement step would make dealing a face-up damage card an explicit and observable gameplay event before play continues.

## Evidence

Known example:

- Normal attack damage: face-up damage card is shown in close-up as desired.
- Asteroid overlap damage: face-up damage card may only appear next to the affected ship card without the equivalent close-up presentation.

Other sources of face-up damage have not yet been exhaustively checked and should be considered during investigation.

## Investigation hint

Use the existing normal-attack face-up damage presentation as the reference behavior.

Identify all authoritative gameplay paths that can result in a face-up damage card being dealt and determine whether they converge on a common result/presentation path or currently trigger presentation through source-specific logic.

Investigate separately:

- creation/application of the face-up damage result;
- projection of the newly dealt card to each player;
- close-up presentation;
- acknowledgement state;
- network synchronization of acknowledgements;
- continuation of the enclosing gameplay flow after acknowledgement.

Do not assume that the existing attack-specific implementation is the correct architectural owner for the generalized behavior.

The intended invariant is player-facing:

> Whenever gameplay deals a face-up damage card, the resulting card is presented to the relevant players and acknowledged before gameplay continues.

The implementation should preserve authoritative gameplay state and avoid making UI-local state responsible for determining whether gameplay may continue.

## Resolution

Improvement:

Not yet implemented.

Target behavior: provide one consistent face-up-damage presentation and acknowledgement experience for all gameplay paths that deal face-up damage cards, including synchronized host/client handling in network play.

Verification:

- Face-up damage dealt during a normal attack still produces the existing desired close-up behavior.
- Face-up damage caused by asteroid overlap produces the same required close-up presentation.
- Other identified face-up-damage sources use the same player-facing behavior.
- In network play, both host and client receive the required presentation.
- Gameplay does not continue until the required acknowledgements have occurred.
- Acknowledgement by only one network participant does not prematurely resume gameplay.
- After acknowledgement is complete, the enclosing gameplay flow resumes correctly.
- Face-down damage behavior is unchanged unless separately required.
- Save/load, reconnect, replay, and recovery implications are investigated before implementation if acknowledgement represents a live gameplay decision or continuation boundary.

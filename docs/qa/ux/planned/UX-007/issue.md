# UX-007 — Ship card command-token display can become stale after token use or discard

Category: High
Area: Ship Card / Command Token Projection
Layer: Projection

## Problem

The command-token display on ship cards is not always updated immediately when command tokens are used or discarded.

The authoritative gameplay state appears to process the token use or discard correctly, but in some circumstances the corresponding ship card continues to display the previous token state.

As a result, the visible ship card can temporarily become inconsistent with the actual game state.

This behavior has been observed after the recent implementation work concerning Speed 0 and obstacle rules. The relationship to those changes is currently only a regression suspicion and has not yet been established as the cause.

Expected behavior:

Whenever authoritative gameplay state changes the command tokens owned by a ship, the ship-card projection should reflect the resulting token state without requiring an unrelated later action, refresh, or state transition.

This should apply regardless of why the token was:

- spent;
- discarded;
- removed by a rule or gameplay effect; or
- otherwise changed through an authoritative gameplay operation.

## Impact

The ship card is an important player-facing representation of the ship's current state.

If command tokens remain visually present after they have already been spent or discarded, the player may incorrectly believe that the token remains available.

The problem is particularly misleading because gameplay state and visible UI state can disagree.

If the underlying canonical state is correct, this represents a projection/update regression rather than a command-token rules failure.

If investigation shows that canonical command-token state is also incorrect, the issue should be reclassified or an associated BUG issue should be created.

## Evidence

Observed behavior:

- A command token is used or discarded.
- Gameplay proceeds as though the token operation occurred.
- In some circumstances, the ship card still displays the token.
- The UI therefore does not immediately reflect the apparent authoritative game state.

The issue has been noticed after the recent Speed 0 and obstacle-rule implementation.

The exact triggering paths and affected command-token operations have not yet been exhaustively identified.

## Investigation hint

First establish whether the problem is:

1. canonical state not being updated correctly; or
2. canonical state being correct but the ship-card projection not refreshing correctly.

Do not repair the symptom by introducing UI-local token mutations.

Trace affected token operations from the authoritative gameplay mutation through the normal projection/update path to the ship card.

Compare working and failing token-use/discard paths and determine whether they converge on the same canonical mutation and projection mechanism.

Pay particular attention to recently changed Speed 0 and obstacle-related flows only as possible regression sources; do not assume those changes are causal without evidence.

Also investigate whether the stale display:

- occurs in Hot-Seat, Network, or both;
- occurs on host, client, or both;
- corrects itself after a later unrelated state update;
- depends on the reason the token was spent or discarded;
- affects all command-token types or only particular tokens;
- is limited to ship-card projection or appears in other UI representations of the same state.

The intended invariant is:

> A ship's displayed command tokens are a projection of authoritative gameplay state and must not remain stale after authoritative token state changes.

## Resolution

Improvement:

Not yet implemented.

Target behavior: whenever authoritative command-token state changes, all relevant ship-card projections update to represent the resulting canonical state consistently.

Verification:

- Spending a command token immediately removes or updates it on the affected ship card.
- Discarding a command token immediately removes or updates it on the affected ship card.
- Token changes caused by identified rule/effect paths produce the same projection behavior.
- The visible token state agrees with canonical gameplay state.
- No UI-local mutation is required to keep the ship card synchronized.
- Hot-Seat behavior is verified.
- Network host behavior is verified.
- Network client behavior is verified.
- A later unrelated action or refresh is not required to correct the display.
- Existing command-token gameplay behavior remains unchanged unless investigation identifies a separate canonical-state defect.
- Regression coverage is added for the specific failing path once the cause is identified.

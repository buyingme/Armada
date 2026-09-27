# UX-012 — Obstacle resolution-order choices use unclear numeric obstacle identifiers

Category: Polish
Area: Obstacle Overlap / Resolution Order
Layer: Projection

## Problem

When a ship overlaps multiple obstacles simultaneously, the owner of the ship is correctly asked to choose the order in which the obstacle effects are resolved.

This decision is desired behavior and should remain unchanged.

However, the current UI describes the alternatives using numbered obstacles, for example:

- Resolve obstacle 1, then obstacle 2
- Resolve obstacle 2, then obstacle 1

This does not communicate which obstacle type each number represents.

The player therefore cannot immediately determine which resolution order corresponds to the desired gameplay sequence.

The choices should instead identify the obstacle types directly.

For example, if an Asteroid and a Station are overlapped, the choices should be presented conceptually as:

- Asteroid → Station
- Station → Asteroid

If two obstacles of the same type are overlapped, numbering them does not provide useful gameplay information when their obstacle effects are equivalent.

For example, two overlapping Asteroids may simply be represented as:

- Asteroid → Asteroid

The UI should communicate the order of the relevant obstacle effects rather than expose arbitrary internal obstacle numbering.

## Impact

The existing resolution-order decision is mechanically correct but unnecessarily difficult to understand.

A player choosing between "obstacle 1 → obstacle 2" and "obstacle 2 → obstacle 1" must determine which numbered obstacle corresponds to which obstacle type before making a meaningful decision.

Displaying obstacle types directly makes the gameplay consequence of each choice immediately understandable.

This is especially important when different obstacle types have different effects and therefore resolution order matters.

## Evidence

Observed behavior:

When a ship overlaps two obstacles, the ship owner is correctly prompted to choose their resolution order.

The current choices identify the obstacles numerically, such as:

- obstacle 1 → obstacle 2;
- obstacle 2 → obstacle 1.

The numbering does not communicate the obstacle types involved.

Expected presentation examples:

Asteroid + Station:

- Asteroid → Station
- Station → Asteroid

Station + another different obstacle type:

- Station → [Obstacle Type]
- [Obstacle Type] → Station

Two Asteroids:

- Asteroid → Asteroid

For obstacles with equivalent effects, numeric differentiation provides no additional useful gameplay information.

## Investigation hint

Preserve the existing authoritative rule that the owner of the affected ship chooses the obstacle resolution order.

This issue concerns how the existing legal alternatives are projected to the player, not a change to obstacle-resolution authority or rules.

Identify where the current numeric labels are generated and determine whether the UI already has access to the canonical obstacle type associated with each resolution-order entry.

The displayed alternatives should derive their labels from the actual obstacle types involved rather than from their position or internal numeric identifier.

Do not make presentation text authoritative for the selected order. The underlying selection must continue to identify the correct canonical obstacles/resolution entries regardless of their displayed labels.

### Same-type obstacles

Do not introduce numbering solely to distinguish obstacles of the same type when that distinction has no gameplay consequence for the resolution-order decision.

For example:

Asteroid → Asteroid

is preferable to:

Asteroid 1 → Asteroid 2

when both Asteroids resolve the same obstacle effect and their individual identity is irrelevant to the player's choice.

If investigation identifies obstacle types or future rules where two obstacles of the same type can produce materially different effects, that case should be handled separately rather than introducing unnecessary numbering to all obstacle-order choices.

The intended invariant is:

> Obstacle resolution-order choices describe the gameplay-relevant obstacle types/effects in their actual resolution order rather than exposing arbitrary numeric obstacle identifiers.

## Resolution

Improvement:

Not yet implemented.

Target behavior: retain the existing obstacle resolution-order decision while replacing unclear numeric obstacle labels with gameplay-relevant obstacle-type names.

Verification:

- Overlap an Asteroid and a Station.
- The available choices identify them as `Asteroid → Station` and `Station → Asteroid`.
- Selecting either option resolves the obstacles in the corresponding authoritative order.
- Overlap two Asteroids.
- The UI does not introduce meaningless numeric differentiation solely for presentation.
- Same-type obstacle resolution remains mechanically correct.
- Other combinations of different obstacle types display their corresponding type names.
- The owner of the affected ship remains the player who chooses the resolution order.
- The change does not alter obstacle-overlap detection.
- The change does not alter the legal resolution-order alternatives.
- The change does not alter obstacle effects.
- Presentation labels are derived from canonical obstacle information rather than becoming authoritative identifiers themselves.
- Hot-Seat behavior is verified.
- Network host behavior is verified.
- Network client behavior is verified.

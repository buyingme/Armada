# UX-009 — Damage cards remain displayed after ship destruction

Category: High
Area: Ship Destruction / Damage Cards
Layer: Projection

## Problem

When a ship is destroyed, its damage cards can remain visible next to the ship card after destruction has completed.

This leaves UI elements belonging to a destroyed ship visible even though those damage cards are no longer associated with an active ship.

The intended behavior is that damage cards belonging to a destroyed ship are moved to the damage-card discard pile as part of ship destruction.

The discard pile does not currently need to be displayed by the UI, but it should exist as part of authoritative game state and correctly contain discarded damage cards.

Once the cards have been moved to the discard pile, the UI should update accordingly so that the destroyed ship's damage cards are no longer displayed next to its ship card.

## Impact

Leaving damage cards visible after ship destruction makes the UI inconsistent with the completed destruction state.

It can also obscure a deeper state-lifecycle problem if the cards are merely hidden by the UI while remaining associated with the destroyed ship.

Damage-card cleanup should therefore not be implemented as presentation-only removal. The underlying card state should represent that the cards have been discarded.

This is important for maintaining a reliable authoritative game state for subsequent gameplay, save/load, replay, network synchronization, and future rules that may inspect or interact with discarded damage cards.

## Evidence

Observed behavior:

- A ship receives damage cards.
- The ship is subsequently destroyed.
- Ship destruction completes.
- Damage cards belonging to the destroyed ship remain displayed next to its ship card.

Expected behavior:

- destruction removes the damage cards from the destroyed ship;
- those cards transition to the damage-card discard pile;
- the ship-card projection updates;
- the destroyed ship's damage cards are no longer displayed.

The current state of the underlying damage-card ownership/discard data after ship destruction has not yet been verified.

## Investigation hint

Investigate the complete damage-card lifecycle during ship destruction before changing the UI.

Establish whether the current problem is:

1. the cards remain canonically associated with the destroyed ship;
2. the cards are already moved/discarded canonically but the UI projection remains stale; or
3. both canonical cleanup and projection update are incomplete.

Determine the existing authoritative representation of:

- the damage deck;
- damage cards assigned to ships;
- face-up and face-down damage cards;
- discarded damage cards;
- ship destruction and cleanup.

If a canonical damage-card discard pile already exists, ship destruction should use that existing ownership/lifecycle mechanism.

If no authoritative discard-pile representation currently exists, do not substitute UI-local removal for the missing gameplay state. Treat the missing lifecycle representation as an implementation requirement that must be resolved consistently with existing damage-card architecture.

The intended authoritative transition is conceptually:

Damage card assigned to ship → ship destroyed → damage card transferred to discard pile → projection updates.

The UI should derive the disappearance of the cards from the resulting authoritative state rather than independently deleting or hiding them.

The intended invariant is:

> After ship destruction completes, no damage card remains assigned to the destroyed ship; its former damage cards belong to the authoritative damage-card discard pile and are no longer projected next to that ship.

## Resolution

Improvement:

Not yet implemented.

Target behavior: ship destruction performs authoritative cleanup of the destroyed ship's damage cards by moving them to the damage-card discard pile, after which the UI reflects the resulting state.

Verification:

- Destroy a ship with face-down damage cards.
- Destroy a ship with face-up damage cards.
- Destroy a ship with a mixture of face-up and face-down damage cards.
- After destruction, no former damage card remains assigned to the destroyed ship.
- All former damage cards are represented in the authoritative discard pile.
- The discarded cards are no longer displayed next to the destroyed ship card.
- No presentation-only deletion or hiding is used as a substitute for canonical card cleanup.
- Hot-Seat projection updates correctly.
- Network host projection updates correctly.
- Network client projection updates correctly.
- Save/load preserves the post-destruction damage-card state.
- Replay reproduces the same authoritative destruction and card-discard result.
- Existing damage-card effects and destruction behavior are not otherwise changed.
- Existing damage-deck/discard behavior is reused where available rather than introducing a parallel card-lifecycle mechanism.

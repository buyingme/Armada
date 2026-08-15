# UX-005 Completed Attack Result Inspection — Project Owner Decisions

Status: Owner Decisions
Date: 2026-08-15

## Purpose

This document records Project Owner decisions required to resolve the
architecture stop encountered while implementing UX-005.

It is decision input for the architecture document governing completed attack
result inspection and acknowledgement.

It is not itself an ADR, contract, or implementation specification.

## Decisions

### OD-001 — Result inspection is an authoritative continuation barrier

A completely resolved attack enters a result-inspection barrier before
enclosing gameplay may continue.

The attack and all damage are already fully resolved before this barrier.

Gameplay may not continue until all required acknowledgements have been
received.

### OD-002 — Purpose-specific concept only

Do not introduce a generic acknowledgement framework, generic continuation
barrier, voting system, or general interaction FSM.

The architecture introduces only the concept necessary for completed attack
result inspection.

### OD-003 — Canonical owner

GameState owns one purpose-specific canonical completed-attack inspection
state.

It is separate from:

- CurrentAttackState;
- TimingWindowState;
- InteractionFlow;
- scene/modal presentation state.

CurrentAttackState still retires normally when the attack completes.

### OD-004 — Minimal canonical state

The completed-attack inspection state contains only irreducible information
needed to reconstruct and authorize the inspection barrier.

It may contain:

- stable completed-attack inspection identity;
- immutable attacker/defender/attack-kind identity;
- minimal final attack-result snapshot required for deterministic
  reconstruction;
- required acknowledgements;
- received acknowledgements.

It must not store:

- button visibility;
- panel geometry;
- arbitrary UI state;
- InteractionFlow state;
- generic current step;
- unrelated activation continuation state.

### OD-005 — Required acknowledgement set

The required acknowledgement set is mode-dependent.

Hot-Seat:

- exactly one acknowledgement.

Two-human Network:

- both human players acknowledge independently.

The required set should derive from accepted session/play-mode authority rather
than permanently hard-coding player 0 and player 1.

A future bot does not require human-style result acknowledgement unless later
design explicitly requires it.

### OD-006 — Replayable acknowledgement command

Introduce one narrow replayable semantic command:

`AcknowledgeAttackResultCommand`

The command records acknowledgement of the currently pending completed attack
result by the valid/authenticated player.

It must not:

- resolve or repeat the attack;
- apply damage;
- modify dice;
- alter CurrentAttackState;
- directly perform the next gameplay step.

### OD-007 — Continuation ownership

The final required acknowledgement releases the existing completed-attack
continuation.

It must not create another continuation architecture.

After the acknowledgement barrier becomes satisfied, the existing
ShipInstance/SquadronInstance-derived continuation resumes exactly once through
the accepted continuation path.

### OD-008 — Persistence

A pending completed-attack inspection is canonical durable state and must
survive save/load.

Loading must reconstruct:

- the completed result;
- received acknowledgements;
- outstanding acknowledgements;
- the result presentation;
- the blocked continuation.

### OD-009 — Replay

Acknowledgements are replayable semantic events because they change
authoritative continuation eligibility.

Replay must reproduce the same acknowledgement barrier and release ordering.

Replay must not synthesize acknowledgements merely to advance.

### OD-010 — Reconnect

Reconnect reconstructs the canonical pending inspection state.

Already received acknowledgements remain received.

Missing acknowledgements remain required.

Gameplay remains blocked until the outstanding acknowledgements have been
received.

### OD-011 — Per-player Network presentation

In Network mode, a player may dismiss their own local result presentation after
their acknowledgement has been accepted.

The other player's result remains visible until that player acknowledges.

The authoritative barrier remains active until the complete required
acknowledgement set has been received.

### OD-012 — Hot-Seat behavior

Hot-Seat uses the same canonical completed-attack inspection concept.

Exactly one accepted acknowledgement releases continuation.

### OD-013 — Visibility

The existence and acknowledgement status of a completed-attack inspection are
not hidden gameplay information.

Both network peers may know which required acknowledgements have been received.

Presentation may decide how prominently to display this information.

### OD-014 — No automatic timeout

The legacy automatic final-result continuation timer must not bypass the
completed-attack inspection barrier.

No timeout automatically acknowledges or releases a required result.

### OD-015 — Explicit exclusions

The architecture must not make any of the following canonical:

- button visibility;
- panel geometry;
- generic UI lifecycle state;
- generic current-step state;
- InteractionFlow state.

The decision must not introduce a generic acknowledgement framework or generic
gameplay FSM.

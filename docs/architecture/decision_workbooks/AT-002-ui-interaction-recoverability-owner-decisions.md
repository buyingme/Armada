# AT-002 UI Interaction Recoverability — Owner Decisions

**Status:** Project Owner decisions
**Related task:** AT-002
**Related boundary:** BC-003
**Date:** 2026-08-20
**Purpose:** Preserve the Project Owner decisions and rationale that define the intended gameplay-interaction recoverability principle before normative architecture is drafted.

## 1. Context

AT-002 AS-IS discovery identified that active-gameplay UI recovery is not uniform.

The Ship Phase / Ship Activation decomposition classified current interaction recovery as:

- **R1 — Reconstructible:** presentation can be derived from canonical/accepted interaction state.
- **R2 — Conditionally reconstructible:** additional scene/controller reconstruction is required.
- **R3 — Callback/path dependent:** the visible/actionable interaction materially depends on the command/callback path that reached the state.

The purpose of the following decisions is not to prescribe a UI implementation or require persistence of UI state.

The purpose is to establish what gameplay-decision information must remain recoverable so equivalent authoritative gameplay situations cannot produce different or missing actionable interactions merely because they were reached through different UI/controller paths.

## 2. Considered recoverability approaches

Three broad approaches were considered.

### A. Persistence-bound recovery

Guarantee decision reconstruction only where save/load, replay, reconnect, or similar persistence/distribution requirements already demand it.

**Assessment:** Rejected.

**Rationale:** This leaves ordinary UI rebuild, Hot-Seat handoff, and equivalent callback paths able to depend on historical controller/UI state. It therefore preserves the class of UI reliability problem that motivated AT-002.

### B. Decision-equivalent recovery

Whenever authoritative gameplay represents a live player decision, sufficient information must be available to reconstruct an equivalent actionable interaction independently of the UI/controller/callback path.

Visual and uncommitted presentation state may remain transient.

**Assessment:** Selected.

**Rationale:** This addresses path-dependent UI failures without creating a second gameplay authority or requiring general persistence of presentation state.

### C. Serialized interaction-routing checkpoints

Persist an explicit generic routing checkpoint for every live gameplay decision.

**Assessment:** Rejected as the general requirement.

**Rationale:** Although this could provide strong restoration guarantees, it creates unnecessary state and risks duplicating purpose-specific canonical ownership or evolving into a generic gameplay/activation FSM.

The selected requirement concerns recoverable **decision semantics**, not a prescribed serialization mechanism.

## 3. Owner Decision D1 — Decision-equivalent recovery

**Decision:** Accepted.

Every live gameplay decision must be recoverable independently of the UI, controller, or callback history that produced the current authoritative gameplay situation.

Recovery must provide enough information to reconstruct an equivalent actionable interaction.

### Rationale

Equivalent authoritative gameplay situations should not produce different, missing, or incorrectly actionable UI merely because they were reached through different execution paths.

The requirement concerns gameplay decisions rather than exact UI restoration.

## 4. Owner Decision D2 — Mandatory and optional decisions

**Decision:** Accepted.

The recoverability guarantee applies to both mandatory and optional gameplay decisions.

For an optional opportunity, the system must be able to recover:

- that the opportunity exists;
- who controls it;
- its legal choices or authoritative source of legality;
- how it is used or declined;
- when the opportunity is complete.

### Rationale

Optional gameplay opportunities are genuine gameplay decisions. Excluding them would create a major exception through which path-dependent interaction behavior could remain.

## 5. Owner Decision D3 — Authoritative legality

**Decision:** Accepted.

A recoverable gameplay decision must provide either:

- its legal choices; or
- a deterministic authoritative gameplay source from which those choices can be derived.

Presentation or controller code must not independently determine gameplay legality.

### Rationale

Different controllers must not develop separate interpretations of which gameplay actions are legal.

Human UI, Network UI, reconstruction paths, and future bots should consume the same gameplay legality.

## 6. Owner Decision D4 — Recover the decision, not transient work

**Decision:** Accepted.

Uncommitted presentation manipulation does not need to survive reconstruction.

Examples that may remain transient include:

- hover state;
- camera position;
- animations;
- drag state;
- uncommitted target preview;
- uncommitted maneuver geometry or preview;
- other purely local visual working state.

After reconstruction, the player may receive the same gameplay decision again without restoration of unfinished UI manipulation.

### Rationale

The architectural requirement is reliable gameplay continuation, not persistence of presentation implementation details.

The intended boundary is:

**Committed authoritative gameplay → Recoverable gameplay decision → Disposable / replaceable presentation**

## 7. Owner Decision D5 — Controller independence

**Decision:** Accepted.

Supported gameplay controllers must consume semantically equivalent recoverable decision information.

This applies, where relevant, to:

- Hot-Seat;
- Network;
- reconnect/reconstruction;
- save/load continuation;
- equivalent execution/controller paths;
- future bot/controller substitution.

Controllers may present or execute decisions differently, but no controller should receive privileged alternative gameplay semantics.

### Rationale

The gameplay decision belongs to the game rather than to a particular human UI implementation.

Controller independence also establishes a suitable foundation for future bot-controlled players without requiring bots to interpret human UI state.

## 8. Owner Decision D6 — Informational UI exclusion

**Decision:** Accepted.

Purely informational UI is not covered by the gameplay-decision recoverability requirement.

Specific informational UI may receive separate UX requirements where appropriate.

### Rationale

Information display does not become durable gameplay interaction state merely because it relates to gameplay.

Extending the principle to all UI would unnecessarily turn this architecture decision into a general UI-persistence requirement.

## 9. Resulting Owner principle

The Project Owner therefore selects **Decision-Equivalent Recovery** as the intended architecture principle.

The conceptual relationship is:

**Authoritative gameplay state → Recoverable gameplay decision semantics → Replaceable presentation/controller**

Recoverable gameplay decision semantics include, where applicable:

- decision/opportunity existence;
- whether the decision is mandatory or optional;
- controlling player/controller;
- legal choices or authoritative legality source;
- use, decline, commit, and completion semantics.

A correct implementation must not depend on historical UI callbacks, modal lifetime, timers, or controller-local state as the sole source of a live gameplay decision.

This principle does **not** require:

- persistence of every modal;
- persistence of camera or animation state;
- persistence of hover, drag, or selection state;
- persistence of uncommitted previews;
- serialization of every UI state;
- a generic interaction FSM;
- a generic ship-activation FSM;
- `InteractionFlow` or presentation becoming gameplay authority.

## 10. Migration posture

These decisions establish intended TO-BE architecture direction.

They do not by themselves require immediate repository-wide migration.

Existing AT-002 AS-IS findings, including R2 and R3 classifications, should be evaluated against the principle in later bounded gap analysis.

An R2 interaction is not automatically defective merely because scene/controller reconstruction is necessary.

The relevant architecture problem is when the **gameplay decision semantics themselves** cannot be reconstructed without relying on the historical UI/controller/callback path.

## 11. Next architecture step

Use these Owner decisions together with the preserved AT-002 AS-IS discovery evidence to create the smallest appropriate normative architecture artifact.

That task should determine the correct normative home under repository document-authority rules and must preserve existing accepted architecture decisions rather than reopening them.

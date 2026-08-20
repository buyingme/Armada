# ADR-010: Gameplay Interaction Decision-Equivalent Recovery

Status: Accepted

ADR-ID: ADR-010
Title: Gameplay Interaction Decision-Equivalent Recovery

Accepted by: Project Owner

Accepted date: 2026-08-20

Decision owner: Project Owner

Decision source:

- `docs/architecture/decision_workbooks/AT-002-ui-interaction-recoverability-owner-decisions.md`

Supporting AS-IS evidence:

- `docs/architecture/discovery/AT-002-active-gameplay-interaction-map.md`
- `docs/architecture/discovery/AT-002-ship-activation-interaction-map.md`

Related:

- AT-002
- BC-003
- BC-010
- ADR-001
- ADR-006
- ADR-007
- CON-001
- CON-006
- CON-007

Supersedes:
None

Superseded by:
None

## 1. Context and scope

The AT-002 discovery evidence identifies active-gameplay interactions whose
presentation recovery varies by path. In particular, an equivalent
authoritative gameplay situation can currently yield a reconstructible,
conditionally reconstructible, or callback/path-dependent interaction surface.

The Project Owner selected a narrow TO-BE architectural principle: gameplay
decision semantics, rather than a particular modal or presentation state, must
be recoverable independently of the UI, controller, or callback history that
reached the authoritative state.

This ADR establishes that principle. It does not define individual modals,
screen composition, controller architecture, a generic interaction framework,
or immediate migration work.

`docs/game_flow.md` is historical comparison evidence only and is not
normative for this decision.

## 2. Decision

Armada SHALL provide **Decision-Equivalent Recovery** for every live gameplay
decision.

The required conceptual boundary is:

```text
Authoritative gameplay state
  → recoverable gameplay decision semantics
  → replaceable/transient presentation and controller behavior
```

For a live gameplay decision, recovery from the current authoritative
gameplay situation SHALL provide, as applicable:

1. whether the decision or opportunity exists;
2. whether it is mandatory or optional;
3. the gameplay actor entitled to act, including the controlling player or supported automated controller;
4. the legal choices, or the deterministic authoritative source from which
   those choices are derived; and
5. the use, decline, commit, and completion semantics needed to continue
   gameplay correctly.

Equivalent authoritative gameplay situations SHALL yield equivalent actionable
decision semantics regardless of the UI, controller, callback, timer, scene,
transport, or reconstruction path that reached them.

## 3. Ownership and non-authority

This ADR does not create a new canonical gameplay-state owner.

Existing accepted owners retain their responsibilities, including
`CurrentAttackState` under ADR-001 and ship-activation facts on `ShipInstance`
under ADR-006. Replayable commands and existing accepted semantic transitions
remain the sole mutation surfaces for their respective gameplay facts.

`InteractionFlow`, `FlowSpec`, `UIProjector`, state filtering, scene
controllers, modal routers, timers, panels, local controller caches, and
presentation callbacks may carry, derive, route, or render decision semantics.
They SHALL NOT become an alternative authority for gameplay legality,
opportunity existence, controller entitlement, completion, or semantic
mutation.

Legal choices may be carried as derived interaction data or derived at
reconstruction time from their existing authoritative gameplay owners. UI or
controller-specific logic SHALL NOT independently determine gameplay legality.

## 4. Recovery scope

Decision-Equivalent Recovery applies where a supported runtime must expose or
execute a live gameplay decision, including as relevant:

- ordinary UI or scene rebuild;
- Hot-Seat handoff;
- Network mirror and reconnect reconstruction;
- save/load continuation;
- equivalent execution or controller paths; and
- future supported bot substitution.

Replay SHALL continue to apply accepted semantic commands in authoritative
history order. It need not reconstruct a human interaction surface unless an
interactive replay mode permits further gameplay input. In that case, the same
decision-equivalent rule applies.

Supported controllers may present or execute a decision differently, but they
shall consume semantically equivalent recoverable decision information. No
controller receives privileged alternative gameplay semantics.

## 5. Presentation boundary

This ADR requires recovery of gameplay decision semantics, not exact visual
restoration.

The following may remain transient, disposable, or locally rebuilt:

- hover and selection highlighting;
- camera position;
- animation state;
- drag state;
- uncommitted target preview;
- uncommitted maneuver geometry or preview; and
- other purely local visual working state.

After reconstruction, a player may receive the same gameplay decision without
restoring unfinished presentation manipulation. Purely informational UI is out
of scope unless another accepted requirement explicitly governs it.

## 6. Architectural invariants

1. A live gameplay decision is never authoritative solely because a modal,
   route, scene node, callback, timer, or controller-local cache says it is.
2. A supported recovery path shall not infer gameplay decision semantics from
   historical presentation behavior when those semantics are required to make
   gameplay actionable.
3. Optional opportunities are gameplay decisions and receive the same
   recoverability guarantee as mandatory decisions.
4. A missing transient presentation artifact shall not remove, create, consume,
   complete, or alter a live gameplay decision.
5. Reconstructing a decision shall not duplicate canonical state, create a
   second gameplay authority, or reverse-synchronize presentation state into a
   canonical owner.
6. Equivalent authoritative state shall not produce missing, different, or
   incorrectly actionable gameplay interaction merely because it was reached
   through a different supported path.

## 7. Relationship to existing authority

| Existing authority | Relationship to ADR-010 |
| --- | --- |
| ADR-001 / CON-001 | `CurrentAttackState`, replayable semantic attack mutation, and non-authoritative projection remain unchanged. ADR-010 requires recoverable attack decision semantics only from those accepted owners and their derived interaction data. |
| ADR-006 | Ship activation identity, purpose-specific opportunities, and committed count remain the only accepted ship-activation canonical facts. ADR-010 does not require a generic current-step field or ship-activation FSM. |
| CON-006 | Accepted Begin/Skip decision and reconstruction requirements remain governing implementation obligations. ADR-010 extends the architectural recovery principle without changing declaration ownership or mutation. |
| ADR-007 / CON-007 | Completed-attack inspection and release remain purpose-specific canonical boundaries. Presentation cannot acknowledge, release, or progress gameplay; it may derive the corresponding decision/waiting state. |

No existing accepted authority is amended or reopened by this ADR.

## 8. Migration posture

This decision establishes TO-BE architecture. It does not require immediate
repository-wide migration or prescribe a serialization mechanism.

The AT-002 R1/R2/R3 classifications remain AS-IS evidence for later bounded
gap analysis:

- R1 may already satisfy the principle.
- R2 is not defective merely because scene/controller reconstruction is
  required; it is sufficient when gameplay decision semantics are recoverable.
- R3 requires later examination only where historical path dependence is the
  sole source of live gameplay decision semantics.

Later implementation work must select the narrowest existing canonical owner
and semantic transition for the affected decision. If satisfying the principle
would require a new gameplay owner, a generic serialized interaction FSM, or a
new general UI/controller framework, that work shall stop for a separate
architecture decision.

## 9. Non-goals

This ADR does not define or require:

- individual modals, layouts, panels, animations, or camera behavior;
- persistence of every modal, UI state, preview, hover, drag, selection, or
  local visual state;
- redesign of `InteractionFlow`;
- a generic interaction, UI, controller, bot, or presentation framework;
- a generic serialized interaction or ship-activation FSM;
- production implementation, migration sequencing, test design, or a
  repository-wide remediation program; or
- any change to the AS-IS discovery evidence or `docs/game_flow.md`.

## 10. Owner-decision traceability

| Owner decision | ADR result |
| --- | --- |
| D1 — Decision-equivalent recovery | Sections 2, 4, and 6 require equivalent actionable semantics from equivalent authoritative state. |
| D2 — Mandatory and optional decisions | Sections 2 and 6 apply the guarantee to both mandatory and optional opportunities. |
| D3 — Authoritative legality | Sections 2 and 3 require legal choices or a deterministic accepted source and prohibit UI/controller legality. |
| D4 — Recover decision, not transient work | Section 5 preserves disposable presentation and uncommitted work. |
| D5 — Controller independence | Section 4 requires semantic equivalence across supported controllers and recovery paths. |
| D6 — Informational UI exclusion | Section 5 excludes purely informational UI. |

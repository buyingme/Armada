# ADR-006: Canonical Ship-Activation Boundary Ownership

Status: Accepted

ADR-ID: ADR-006
Title: Canonical Ship-Activation Boundary Ownership

Accepted by: Project Owner

Accepted date: 2026-08-10

Supersedes:
None

Superseded by:
None

Related:
- ADR-001
- ADR-003
- ADR-004
- ADR-005
- CON-001
- CON-003
- CON-004
- CON-005
- CON-006
- TEST-003
- TWI-001
- TWI-002
- TWI-003
- MA-ATTACK-002
- AT-001
- AT-002
- AT-019
- BC-001
- BC-003

Inputs:
- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/requirements/mvp_learning_scenario.md`
- `docs/architecture/implementation_workbooks/TWI-001-timing-window-state-implementation-workbook.md`
- `docs/architecture/implementation_workbooks/TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md`
- `docs/architecture/implementation_workbooks/TWI-002-implementation-audit.md`
- `docs/architecture/implementation_workbooks/TWI-003-authoritative-current-attack-state-implementation-workbook.md`
- `docs/architecture/migration_assessments/MA-ATTACK-002-post-stabilization-con-006-compliance.md`
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- Current committed ship-activation state, command, reset, destruction, flow,
  and presentation implementation inspected for this decision
- TWI-003 Entry Gate failure evidence from the preceding prerequisite analysis

## Draft Note

This ADR is a proposal for Project Owner review. It has no accepted authority
until it is accepted under the repository document-authority model.

It resolves only the canonical ownership boundary that is missing from the
TWI-003 Entry Gate. It does not authorize implementation, amend TWI-003, or
rerun that gate.

## 1. Context

CON-006 requires ship Attack declaration and a valid no-active-attack Skip to
bind to an accepted enclosing ship-activation owner. TWI-003 also requires a
durable owner for the active ship's Squadron-command opportunity and for the
post-Skip Maneuver opportunity. Its Entry Gate could not identify those owners
in accepted architecture.

The current implementation provides useful but incomplete evidence:

- `ShipInstance` already owns serialized, activation-local ship facts,
  including Attack-step activity, attack counts, and target history, and its
  activation reset clears those facts.
- `GameState` aggregates the fleets and owns phase, current-attack, and
  timing-window state, but it does not own the ship-local activation facts.
- activation entry, step advance, Skip, commanded-squadron activation,
  Maneuver execution, activation completion, destruction, and round cleanup
  already have semantic command or cleanup boundaries at which the required
  facts can be mutated.
- `InteractionFlow`, `ShipActivationState`, scene controllers, modal state,
  and `SquadronCommandResolver` counters are transient, reconstructable, or
  presentation-facing and cannot safely own replayable gameplay progress.

The gameplay requirements SP-001 and TF-003 establish alternating activation
of one ship at a time. The current committed activation-entry paths also reject
entry while a ship is already being activated. Together these are sufficient
to establish a cross-fleet uniqueness invariant at stable semantic command
boundaries.

The missing architecture can therefore be supplied without a general
ship-activation state machine and without a new top-level gameplay owner.

## 2. Decision Drivers

The decision must:

- give CON-006 and TWI-003 one canonical enclosing ship-activation boundary;
- preserve existing entity-local ownership and avoid duplicate writable state;
- survive save/load, replay, network mirroring, reconnect, and rollback;
- reject commands or choices from an obsolete activation;
- distinguish the two rule-significant opportunities without encoding every
  ship-activation step;
- derive capacity and presentation wherever durable storage is unnecessary;
- remain independent of scene, UI, transport, and controller mode; and
- remain explicit and narrow enough for later incremental language migration
  without requiring such a migration.

## 3. Decision

### 3.1 Canonical Owner

The active ship's existing `ShipInstance` is the canonical owner of the
minimum activation-local boundary defined by this ADR.

That boundary owns exactly these authoritative concepts:

1. a stable current ship-activation identity;
2. a Squadron-command opportunity disposition for that activation;
3. a Maneuver opportunity disposition for that activation; and
4. the count of Squadron-command squadron activations committed during that
   activation's Squadron-command opportunity.

`GameState` remains the aggregate root through which ship instances are
serialized and cross-entity invariants can be validated. It SHALL NOT become a
second writable owner of these activation-local facts.

The architecture requires the stable identity to be assigned by the accepted
semantic ship-activation entry transition. It does not require a particular
field name or bind identity generation to today's command class names. An
implementation may use the accepted entry command's deterministic sequence
identity when that representation satisfies uniqueness, serialization, replay,
and stale-intent validation requirements.

### 3.2 Purpose-Specific Opportunity Dispositions

The Squadron-command and Maneuver dispositions are independent,
purpose-specific facts. Their lifecycle semantics differ where the applicable
rules impose different obligations.

The Squadron-command disposition has this monotonic lifecycle while its
activation identity exists:

`UNREACHED -> OPEN -> CONSUMED`

An accepted semantic transition MAY move the Squadron-command disposition
directly from `UNREACHED` to `CONSUMED` when the opportunity is legitimately
unavailable, passed, or otherwise canonically not exercised under the
applicable rules.

For a surviving normal ship activation, the Maneuver opportunity is mandatory
and has this lifecycle:

`UNREACHED -> OPEN -> CONSUMED`

Normal Maneuver execution changes the Maneuver disposition from `OPEN` to
`CONSUMED`. The Maneuver disposition SHALL NOT move directly from `UNREACHED`
to `CONSUMED` merely to advance or complete a surviving normal activation.

An accepted exceptional terminal transition, including destruction of the
active ship, MAY terminate the activation identity and clear its dispositions
without first changing Maneuver to `CONSUMED`. That cleanup does not represent
or fabricate Maneuver execution.

Neither disposition SHALL move backward or reopen within the same activation
identity. `OPEN` means the corresponding opportunity is the currently
exercisable canonical opportunity, subject to all other current rule and
resource validation. For Squadron-command, `CONSUMED` means the opportunity
was exercised, declined, passed, unavailable, or otherwise closed by an
accepted semantic transition. For Maneuver, `CONSUMED` means the mandatory
Maneuver was executed and resolved by an accepted semantic transition,
including a legal speed-zero or no-movement result.

The dispositions do not encode Reveal Command, Repair, Attack, Done, or the
complete ordering of ship-activation steps. They say only whether two specific
rule-significant opportunities have not yet been reached, are open, or have
been closed.

### 3.3 Activation-Local Committed Count

The committed Squadron-command activation count belongs to the same
`ShipInstance` and active activation identity as the Squadron-command
disposition.

It starts at zero for a newly established activation. It increments exactly
once when an accepted semantic commanded-squadron activation commits a squadron
to this ship's currently `OPEN` Squadron-command opportunity. Selection,
preview, modal display, or resolver bookkeeping SHALL NOT increment it.

The count is stored because accepted command commitments must survive
reconstruction. Squadron-command capacity and remaining activations are not
stored by this boundary. They are derived at validation time from the current
authoritative command dial, token, static ship value, accepted rule state, the
opportunity disposition, and the committed count.

### 3.4 Aggregate Uniqueness

At every stable semantic command boundary, zero or one `ShipInstance` across
the complete canonical `GameState` may have an active ship-activation identity.

A destroyed ship SHALL NOT retain an active ship-activation identity. A
semantic transaction that destroys the active ship SHALL terminate that
identity and its dormant activation-local opportunity state atomically with the
destruction result.

Owner-local validation is required for each ship instance. Aggregate
installation and cross-owner validation SHALL additionally reject canonical
state containing more than one active ship-activation identity.

This uniqueness decision is limited to the enclosing active ship activation.
It does not define the wider Ship Phase turn-selection or controller
architecture that remains open under BC-001 and BC-003.

### 3.5 Stored and Derived State

The following are stored authoritative facts on the active `ShipInstance`:

- stable ship-activation identity;
- Squadron-command opportunity disposition;
- Maneuver opportunity disposition; and
- Squadron-command activations committed for that identity.

The following remain derived or non-authoritative:

- the current presentation step;
- Squadron-command capacity;
- remaining Squadron-command activations;
- controller implementation or controller mode;
- the active ship's owner/player, derived from the uniquely active ship and its
  existing ownership facts;
- the active ship reference at aggregate scope, derived by locating the unique
  ship with an active identity;
- UI route;
- modal state;
- post-Skip presentation route;
- `InteractionFlow` routing payloads;
- `ShipActivationState` step and navigation state; and
- `SquadronCommandResolver` capacity and used-count caches.

Derived or presentation state is one-way projection. It SHALL NOT establish,
open, consume, close, reset, or reverse-synchronize any canonical fact defined
by this ADR.

### 3.6 This Is Not a General Activation FSM

This model stores one scope identity, two independent purpose-specific
dispositions, and one committed-use count because those exact facts are needed
for deterministic rule validation and reconstruction.

It does not store a generic current step, a predecessor graph, a transition
table for all activation steps, or a general continuation queue. Existing
Attack-step facts retain their existing owner and semantics. Reveal Command,
Repair, Attack, Maneuver ordering, and activation completion remain governed by
their accepted semantic transitions and game rules rather than by a new
serialized finite-state machine.

## 4. Invariants

The canonical model SHALL enforce these invariants:

1. An activation identity exists only while its ship activation is active.
2. At a stable semantic command boundary, at most one ship across both fleets
   has an active ship-activation identity.
3. A destroyed ship has no active ship-activation identity.
4. Both opportunity dispositions and the committed count are scoped to, and
   invalid without, their matching active activation identity.
5. A newly established identity initializes both dispositions to `UNREACHED`
   and the committed count to zero.
6. Each disposition is monotonic for one identity and never returns to an
   earlier value.
7. The committed count is non-negative and increments exactly once per accepted
   commanded-squadron activation commitment.
8. A committed count greater than zero requires that the Squadron-command
   opportunity was opened for that activation; no new commitment is legal
   unless that disposition is `OPEN`.
9. A new commitment is legal only when the committed count is below capacity
   derived from current authoritative resources and accepted rules.
10. Capacity changes do not rewrite the committed count. If current derived
    capacity no longer admits another activation, the next commitment rejects.
11. A command operating on activation-local progression SHALL be bound to the
    expected stable activation identity, either directly in its semantic input
    or through an accepted canonical enclosing reference. It SHALL reject
    before mutation when that identity is absent or does not match, and SHALL
    NOT substitute whichever activation happens to be current.
12. Presentation, scene, modal, route, resolver, and controller caches cannot
    satisfy or change these invariants.
13. A surviving normal ship activation SHALL NOT complete while its Maneuver
    disposition is `UNREACHED` or `OPEN`. Normal completion requires both the
    Squadron-command and Maneuver dispositions to be `CONSUMED`.
14. Normal activation completion atomically removes the identity and clears the
    two dispositions and committed count to their no-activation representation.
15. An accepted exceptional terminal transition, including active-ship
    destruction, MAY atomically remove the identity and clear the dispositions
    and committed count without changing Maneuver to `CONSUMED` solely to
    satisfy the normal-completion invariant. It SHALL NOT fabricate Maneuver
    execution.
16. Round-boundary cleanup defensively removes stale activation-local state but
    is not the normal progression mechanism for completing an activation.
17. Save/load, replay, network mirroring, and reconnect reconstruct the same
    identity, dispositions, and count before presentation is derived.

## 5. Semantic Transition Responsibilities

The responsibilities below are architectural transition responsibilities.
Current command paths are implementation evidence, not part of the identity of
the decision.

| Semantic transition | Canonical responsibility | Current implementation evidence |
| --- | --- | --- |
| Begin ship activation | After complete entry validation, establish a fresh stable identity on the selected ship and initialize both dispositions and the count. Reject if any ship already has an active identity. | The accepted activation-entry paths currently represented by `ActivateShipCommand` and `ConvertDialToTokenCommand`. |
| Enter executable Squadron-command opportunity | Atomically change the matching ship's Squadron disposition from `UNREACHED` to `OPEN` when current command and rules make the opportunity executable. | The existing semantic activation-step advance path represented by `AdvanceActivationStepCommand`. |
| Leave, pass, or close Squadron-command opportunity | Change the matching Squadron disposition from `OPEN` to `CONSUMED` after the opportunity is exercised, declined, passed, or otherwise closed. It MAY instead change directly from `UNREACHED` to `CONSUMED` only when the opportunity is legitimately unavailable, passed, or otherwise canonically not exercised under the applicable rules. Never reopen it for that identity. | The existing semantic transition leaving the Squadron-command boundary. |
| Commit commanded-squadron activation | Validate the matching ship activation identity, `OPEN` disposition, commanding-ship reference, eligibility, and freshly derived capacity; then increment the committed count exactly once in the same accepted transaction that establishes the commanded squadron activation. | The command-context path represented by `ActivateSquadronCommand`. |
| Open Maneuver after valid no-active-attack Skip | In the accepted Skip transaction, consume the applicable Attack declaration opportunity under CON-006 and change the matching Maneuver disposition from `UNREACHED` to `OPEN`. | The no-active-attack branch represented by `SkipAttackCommand`. |
| Open Maneuver after normal Attack completion | When the accepted ship Attack boundary is complete, change the matching Maneuver disposition from `UNREACHED` to `OPEN`. | The existing semantic transition from completed ship attacks to Maneuver, currently routed through activation-step advancement. |
| Resolve or consume Maneuver | Validate the matching activation identity and `OPEN` disposition, commit the legal maneuver result, including a legal no-movement or speed-zero result, and change the Maneuver disposition from `OPEN` to `CONSUMED`. It SHALL NOT use `UNREACHED` to `CONSUMED` as normal progression. | The semantic maneuver execution path represented by `ExecuteManeuverCommand`; any current scene-only speed-zero completion is a migration risk, not an alternative owner. |
| Complete surviving normal ship activation | Require both dispositions to be `CONSUMED`; in particular, reject completion while Maneuver is `UNREACHED` or `OPEN`. Then perform existing activation completion effects and atomically remove the identity and activation-boundary facts. | The normal activation completion path represented by `EndActivationCommand`. |
| Exceptionally terminate ship activation, including active-ship destruction | As part of an accepted exceptional terminal transaction, atomically terminate the active identity and clear its activation-boundary facts. Do not change Maneuver to `CONSUMED` solely for termination and do not fabricate Maneuver execution. | Existing damage, overlap, destroy, `ShipInstance` destruction, and other accepted exceptional terminal paths require convergence on this responsibility during implementation refinement. |
| Round-boundary defensive cleanup | Clear any stale activation identity and associated facts while preserving the rule-defined round reset behavior. It SHALL reject or report impossible multi-owner state rather than choose an owner from presentation state. | Existing status cleanup and `ShipInstance` activation reset paths. |

These responsibilities fit existing semantic command and cleanup boundaries.
This ADR does not require or authorize a new semantic command type. If later
Entry Gate evidence proves an existing transition cannot own one of these
mutations atomically, implementation SHALL stop for architecture review rather
than invent a command or presentation owner.

## 6. Persistence, Reconstruction, and Atomicity

### 6.1 Serialization and Save/Load

The four authoritative concepts serialize exactly once under their owning
`ShipInstance` within the canonical `GameState` aggregate.

Load validates each owner-local representation and then validates cross-fleet
uniqueness before installing canonical state or deriving presentation. Missing,
malformed, stale, destroyed-owner, or multiply active representations fail
according to the accepted compatibility policy; presentation state SHALL NOT
repair them.

This ADR assigns no save or replay format number and requires no separate
pre-TWI-003 format migration. TWI-003 retains responsibility for its planned
compatibility cutover after this ADR is accepted and the Entry Gate is rerun.

### 6.2 Replay

Replay applies the same accepted semantic transitions in recorded order. The
activation-entry transition deterministically establishes the same identity,
and later commands validate that identity before changing dispositions or the
count. Replay SHALL NOT infer canonical activation progress from routes,
modals, resolver counters, or scenes.

### 6.3 Network Host and Mirror

The authoritative host and mirrors execute or install the same ordered
semantic results and retain the same activation identity and owner-local facts.
Transport, local UI state, and controller location do not alter ownership or
transition semantics. A mirror does not synthesize progress from a displayed
step.

### 6.4 Reconnect

Reconnect installs and validates canonical `GameState`, including the owning
ship's activation-local facts, before reconstructing controller routing, UI
route, modal state, remaining capacity, or post-Skip presentation.

### 6.5 Snapshot and Rollback

A command that may change the activation boundary SHALL validate all
participating owners before mutation, snapshot the complete affected
`ShipInstance` boundary and every adjacent authoritative owner in the same
transaction, apply mutations, cross-validate, and restore all snapshots on
failure.

Partial mutation of identity, either disposition, the committed count,
`CurrentAttackState`, timing-window state, squadron action state, or destruction
state is invalid. Rollback SHALL restore the previous identity and all facts
scoped to it exactly.

## 7. Controller Independence

Canonical ship-activation progression is identical whether the accepted acting
controller is a local human, a remote human, or a future automated controller.

Each mode submits the same accepted semantic intents, validates against the
same canonical owners, and receives results from the same mutation path.
Controller mode, transport location, scene ownership, and modal lifetime are
not gameplay authority.

This consequence does not decide general Hot-Seat, Network, Bot, turn-order, or
controller architecture.

## 8. C# Posture

The activation boundary defined here is explicit, deterministic, serializable,
scene-independent, and narrow. Those properties are compatible with the
roadmap's incremental C# direction and AI Development Principle 9.

The decision is language-independent. It neither requires C# nor defines a C#
migration plan, sequencing, API, or broader language architecture.

## 9. Relationship to Existing Authority

### 9.1 ADR-001 and CON-001

ADR-001 and CON-001 remain the sole authority for canonical
`CurrentAttackState` and attack transition ownership. This ADR adds no second
current-attack state and does not copy attack lifecycle into the ship activation
identity or opportunity dispositions. The enclosing activation boundary is an
adjacent owner that applicable attack commands validate and mutate atomically
under existing attack obligations.

### 9.2 ADR-003 and CON-003

Rule applicability, validation, execution, projection, and Rule Capability
Package traceability remain governed by ADR-003 and CON-003. This ADR owns
activation-local progression facts, not rule truth, a generic rule engine, or
rule-specific mutable state.

### 9.3 ADR-004 and CON-004

Runtime upgrade instances retain their accepted mutable state and trigger-guard
ownership. No upgrade fact moves to the activation boundary, and no activation
fact moves to an upgrade instance.

### 9.4 ADR-005 and CON-005

`TimingWindowState` and the Timing Window Orchestrator retain timing-window
lifecycle and continuation ownership. This ADR creates no timing window, rule
opportunity queue, timing continuation, or duplicate timing state.

### 9.5 CON-006

This ADR concretizes the missing "canonical enclosing ship-activation state"
required by CON-006 for the Ship Activation Attack declaration opportunity and
for a valid no-active-attack Skip result. Skip can now validate the stable
activation identity and atomically open the owner-local Maneuver opportunity
without making `InteractionFlow` or a presentation step authoritative.

CON-006 continues to own Begin/Skip declaration lifecycle, validation,
atomicity, and projection obligations. This ADR does not redefine them.

### 9.6 TEST-003

TEST-003 remains the verification contract for accepted timing-window behavior.
It does not own ship-activation state. Implementations must preserve its replay,
network, reconstruction, visibility, and derived-projection expectations where
timing windows interact with adjacent activation state.

### 9.7 TWI-003

This ADR provides canonical answers to TWI-003's two failed Entry Gate owner
prerequisites:

- the active ship's Squadron-command opportunity is the Squadron disposition
  on that ship's stable activation boundary; and
- the post-Skip Maneuver opportunity is the Maneuver disposition on that same
  boundary.

It also confirms the same owner for TWI-003's activation-local committed
Squadron-command activation count.

After this ADR is accepted:

1. TWI-003 must be refined to reference the accepted activation ownership;
2. its Entry Gate assumptions for the two missing owners can be corrected;
3. implementation remains allocated to TWI-003's appropriate existing slices
   and compatibility cutover; and
4. the TWI-003 Entry Gate must be rerun before Slice 1 is authorized.

Acceptance of this ADR alone does not authorize TWI-003 implementation.

## 10. Consequences and Tradeoffs

Positive consequences:

- required ship-activation facts have one entity-local canonical owner;
- stale activation intent can be rejected deterministically;
- save/load, replay, mirrors, reconnect, and rollback no longer depend on scene
  or resolver lifetime for these facts;
- capacity remains responsive to current authoritative resources and rules; and
- the decision adds only the progression facts required by CON-006 and TWI-003.

Tradeoffs:

- aggregate validation must scan both fleets to enforce active-identity
  uniqueness;
- all accepted semantic paths that enter, advance, terminate, destroy, or reset
  an active ship must converge on the same owner-local lifecycle operations;
- commands touching adjacent attack, squadron, destruction, or timing owners
  must snapshot and roll back a wider atomic boundary; and
- current presentation-owned or cached progression paths must be removed as
  authority during the later authorized implementation.

## 11. Current Migration Risks

No material conflict with accepted architecture was found. The current
implementation nevertheless contains migration risks that TWI-003 refinement
and its rerun Entry Gate must inventory:

- `InteractionFlow` and presentation-step terminology can be mistaken for
  canonical progress despite accepted projection boundaries;
- the current no-active-attack Skip path does not yet durably open Maneuver;
- a speed-zero Maneuver path may complete through scene logic instead of the
  accepted semantic maneuver transaction;
- destruction paths do not yet share one active-activation cleanup behavior;
- activation-step advancement is not yet consistently scoped by a stable
  activation identity; and
- `SquadronCommandResolver` still contains transient capacity/use counters that
  must not remain semantic authority.

These are implementation gaps, not reasons to create a second owner or a
general activation FSM. If later evidence requires a general current step, a
new top-level owner, a new semantic command type, or a format cutover outside
TWI-003, work must stop for a new architecture decision.

The broader Ship Phase activation-selection and controller questions under
BC-001 and BC-003 remain outside this ADR.

## 12. Alternatives Considered

### 12.1 `GameState` as Direct Owner

Rejected. It would duplicate ship-local activation facts already colocated on
`ShipInstance` and create a second writable source requiring synchronization.
`GameState` remains the aggregate and cross-owner validator.

### 12.2 `InteractionFlow`, `ShipActivationState`, Scene, Modal, or Controller

Rejected. These surfaces are derived, transient, reconstructable, or tied to a
particular presentation/controller lifetime. They cannot provide deterministic
save/load, replay, mirror, reconnect, or rollback authority.

### 12.3 `SquadronCommandResolver` Counters

Rejected. Resolver capacity and use caches are recreatable adapter state and
would freeze or duplicate facts that must be derived from current resources and
canonical commitments.

### 12.4 General Serialized Ship-Activation FSM

Rejected. CON-006 and TWI-003 require only a stable scope plus two
purpose-specific opportunity lifecycles. A generic step field and predecessor
graph would decide broader activation architecture without evidence or owner
approval.

### 12.5 New Top-Level Decision Manager or Queue

Rejected. The required facts have a natural existing entity-local owner and
existing semantic transition boundaries. A generic manager or queue would add
unrelated authority and continuation semantics.

## 13. Explicit Non-Goals

This ADR does not introduce or authorize:

- a general ship-activation FSM;
- a generic `current_activation_step`;
- a generic DecisionManager or decision queue;
- a bot framework;
- network transport redesign;
- new timing-window ownership;
- duplicate `CurrentAttackState` or `TimingWindowState` authority;
- `GameState` as a second writable owner of activation-local facts;
- `InteractionFlow`, `ShipActivationState`, `SquadronCommandResolver`, scene,
  controller, modal, or route state as gameplay authority;
- reverse synchronization from presentation to canonical state;
- a new semantic command type;
- new save or replay versions or a separate pre-TWI-003 compatibility cutover;
- C# implementation or a broad C# migration;
- general Hot-Seat, Network, Bot, controller, or turn architecture;
- changes to accepted rule, upgrade, current-attack, or timing-window ownership;
  or
- unrelated gameplay refactoring.

## 14. Owner Questions

None are required to make this Draft reviewable.

Cross-fleet uniqueness is supported by SP-001 and TF-003, which require players
to alternate activation of one ship, and by the committed implementation's
single-active-ship entry guards. The Draft therefore records the invariant
rather than deferring it as an implementation question.

The Project Owner must still accept, reject, or request revision of this Draft
through the normal architecture-governance process.

# ADR-006: Canonical Ship-Activation Boundary Ownership

Status: Accepted

ADR-ID: ADR-006
Title: Canonical Ship-Activation Boundary Ownership

Accepted by: Project Owner

Accepted date: 2026-08-10

Accepted refinement date: 2026-09-09

Supersedes:
None

Superseded by:
None

Related:
- ADR-001
- ADR-003
- ADR-004
- ADR-005
- ADR-010
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
- `docs/requirements/gameplay_interactions/ship_activation_interaction.md`
- `Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md`
- `docs/architecture/implementation_workbooks/TWI-001-timing-window-state-implementation-workbook.md`
- `docs/architecture/implementation_workbooks/TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md`
- `docs/architecture/implementation_workbooks/TWI-002-implementation-audit.md`
- `docs/architecture/implementation_workbooks/TWI-003-authoritative-current-attack-state-implementation-workbook.md`
- `docs/architecture/migration_assessments/MA-ATTACK-002-post-stabilization-con-006-compliance.md`
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md`
- `docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- Current committed ship-activation state, command, reset, destruction, flow,
  and presentation implementation inspected for this decision
- TWI-003 Entry Gate failure evidence from the preceding prerequisite analysis

## Accepted Posture

This accepted ADR resolves the canonical ownership boundary that was missing
from the TWI-003 Entry Gate. The 2026-09-09 refinement additionally defines the
minimum activation-scoped ownership needed to distinguish an uncommitted
Maneuver from one that has committed and is still resolving mandatory
consequences. It does not itself authorize implementation, amend TWI-003, or
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
- distinguish transient Maneuver exploration from one actual committed
  Maneuver whose mandatory consequences are still resolving;
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
   activation's Squadron-command opportunity; and
5. at most one active Maneuver execution record for that activation.

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

Committing a Maneuver leaves the Maneuver disposition `OPEN`. Only completion
of that committed Maneuver, including all of its mandatory consequences,
changes the disposition from `OPEN` to `CONSUMED`. The Maneuver disposition
SHALL NOT move directly from `UNREACHED` to `CONSUMED` merely to advance or
complete a surviving normal activation.

An accepted exceptional terminal transition, including destruction of the
active ship, MAY terminate the activation identity and clear its dispositions
without first changing Maneuver to `CONSUMED`. That cleanup does not represent
or fabricate Maneuver execution.

Neither disposition SHALL move backward or reopen within the same activation
identity. For Squadron-command, `OPEN` means the opportunity is currently
exercisable, subject to all other current rule and resource validation, and
`CONSUMED` means it was exercised, declined, passed, unavailable, or otherwise
closed by an accepted semantic transition. For Maneuver, `OPEN` without an
active Maneuver execution record means no Maneuver has committed and the
opportunity is currently exercisable. `OPEN` with the matching record means
one Maneuver has committed and its mandatory consequences are still resolving;
it does not permit another commitment. For Maneuver, `CONSUMED` means the
mandatory Maneuver and all of its mandatory consequences completed through an
accepted semantic transition, including a legal speed-zero or no-translation
result, and no active Maneuver execution record remains.

The dispositions do not encode Reveal Command, Repair, Attack, Done, or the
complete ordering of ship-activation steps. They say only whether two specific
rule-significant opportunities have not yet been reached, are open, or have
been closed.

### 3.3 Active Maneuver Execution Record

Before Maneuver commitment, Navigate speed and yaw choices, maneuver-tool
geometry, and candidate destination are transient and non-authoritative.
Exploration SHALL NOT change `ShipInstance.current_speed`, consume a Navigate
dial or token, or establish an authoritative Maneuver result.

The accepted Maneuver commitment transition SHALL atomically select and consume
the applicable Navigate source or sources, apply the resulting canonical speed,
establish the committed Maneuver result, and create one active Maneuver
execution record scoped to the matching activation identity. Failure rejects
the whole commitment without mutation. Commitment leaves the Maneuver
disposition `OPEN`.

The record represents one actual committed Maneuver execution. It MAY retain
only the stable execution identity and rule-significant committed facts or
completion evidence that cannot be safely derived from existing canonical
owners. This MAY include stable identity for a selected Navigate source only
when that identity is non-derivable and required for authoritative recovery or
validation. It SHALL NOT duplicate canonical resource state, consumed-resource
ownership, canonical speed, ship transform, damage, squadron positions,
obstacle or rule-package state, or any other fact already owned authoritatively
elsewhere.

Purpose-specific owners of nested mandatory consequences SHALL bind their work
to the matching activation and Maneuver execution identities. When such work
commits, authority-side control returns to the active Maneuver boundary for
re-evaluation. That return is a composed semantic responsibility, not a stored
generic continuation, callback, route, interaction-flow fact, or work queue.
For mandatory squadron displacement, each affected `SquadronInstance` retains
ownership of its canonical position; the purpose-specific authoritative
displacement transition owns completion of the required placements before
returning to the Maneuver boundary.

The applicable Rules Reference Guide and integrated Rule Capability Packages
govern consequence ordering. Where they do not uniquely determine the relative
order between mandatory squadron displacement and post-execution obstacle
effects, mandatory squadron displacement completes first and obstacle effects
resolve second. Ship-overlap resolution and its damage complete before the
executed-Maneuver boundary. When multiple obstacle effects apply, their order
may be chosen freely as provided by the Rules Reference Guide. This ADR does
not assign the actor who makes that choice; any such assignment is an Armada
Owner interpretation unless another accepted rule source establishes it. An
explicit Rules Reference Guide or integrated Rule Capability Package ordering
takes precedence over this narrow fallback.

Only after all mandatory consequences of the matching execution have completed
MAY an accepted completion transition atomically change Maneuver from `OPEN`
to `CONSUMED` and retire the record. Completion is exact-once: absence of the
matching active record, a non-`OPEN` disposition, an identity mismatch, or any
outstanding mandatory consequence rejects before mutation.

### 3.4 Activation-Local Committed Count

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

### 3.5 Aggregate Uniqueness

At every stable semantic command boundary, zero or one `ShipInstance` across
the complete canonical `GameState` may have an active ship-activation identity.

A destroyed ship SHALL NOT retain an active ship-activation identity. A
semantic transaction that destroys the active ship SHALL terminate that
identity and clear its activation-local opportunity state, committed count,
and any active Maneuver execution record atomically with the destruction
result. Once the activation identity is gone, this ADR assigns no independent
post-destruction meaning to its former Maneuver disposition. Cleanup SHALL NOT
fabricate Maneuver completion. Purpose-specific nested consequence state that
is valid only within that activation and execution SHALL be terminated or
cleared by its accepted owner in the same transaction and SHALL NOT return to a
nonexistent Maneuver boundary.

Owner-local validation is required for each ship instance. Aggregate
installation and cross-owner validation SHALL additionally reject canonical
state containing more than one active ship-activation identity.

This uniqueness decision is limited to the enclosing active ship activation.
It does not define the wider Ship Phase turn-selection or controller
architecture that remains open under BC-001 and BC-003.

### 3.6 Stored and Derived State

The following are stored authoritative facts on the active `ShipInstance`:

- stable ship-activation identity;
- Squadron-command opportunity disposition;
- Maneuver opportunity disposition;
- Squadron-command activations committed for that identity; and
- the optional active Maneuver execution record described in Section 3.3.

The following remain derived or non-authoritative:

- the current presentation step;
- uncommitted Navigate speed or yaw choices, maneuver-tool geometry, and
  candidate destination;
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

### 3.7 This Is Not a General Activation FSM

This model stores one scope identity, two independent purpose-specific
dispositions, one committed-use count, and at most one purpose-specific record
for an actual committed Maneuver because those exact facts are needed for
deterministic rule validation and reconstruction.

It does not store a generic current step, a predecessor graph, a transition
table for all activation steps, a generic Maneuver phase enum, or a general
continuation queue. The presence of the Maneuver record distinguishes one
committed execution from transient exploration; it does not model unrelated
activation steps or arbitrary pending work. Existing Attack-step facts retain
their existing owner and semantics. Reveal Command, Repair, Attack, Maneuver
ordering, and activation completion remain governed by their accepted semantic
transitions and game rules rather than by a new serialized finite-state
machine.

## 4. Invariants

The canonical model SHALL enforce these invariants:

1. An activation identity exists only while its ship activation is active.
2. At a stable semantic command boundary, at most one ship across both fleets
   has an active ship-activation identity.
3. A destroyed ship has no active ship-activation identity.
4. Both opportunity dispositions, the committed count, and any active
   Maneuver execution record are scoped to, and invalid without, their matching
   active activation identity.
5. A newly established identity initializes both dispositions to `UNREACHED`
   and the committed count to zero, with no active Maneuver execution record.
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
13. Maneuver commitment requires the matching identity, Maneuver `OPEN`, and no
    active Maneuver execution record. The accepted transaction atomically
    consumes the selected Navigate source or sources, applies the resulting
    canonical speed and committed result, and establishes one matching record,
    or changes none of them.
14. An active Maneuver execution record requires Maneuver `OPEN` and prevents a
    second Maneuver commitment for the same activation identity.
15. Maneuver completion requires the matching identity and execution record,
    Maneuver `OPEN`, and no outstanding mandatory consequence. The accepted
    transition changes Maneuver to `CONSUMED` and retires the record atomically
    and exactly once.
16. A surviving normal ship activation SHALL NOT complete while its Maneuver
    disposition is `UNREACHED` or `OPEN`, or while a Maneuver execution record
    remains. Normal completion requires both opportunity dispositions to be
    `CONSUMED`.
17. Normal activation completion atomically removes the identity and clears the
    two dispositions, committed count, and Maneuver execution record to their
    no-activation representation.
18. An accepted exceptional terminal transition, including active-ship
    destruction, MAY atomically remove the identity and clear the dispositions,
    committed count, Maneuver execution record, and nested consequence state
    that is invalid without that execution, without changing Maneuver to
    `CONSUMED` solely to satisfy the normal-completion invariant. It SHALL NOT
    fabricate Maneuver execution or completion.
19. A nested mandatory-consequence transition binds to the matching activation
    and Maneuver execution identities, mutates its purpose-specific canonical
    owner, and returns authority-side to the active Maneuver boundary for
    re-evaluation. Presentation or callback completion cannot satisfy this
    invariant.
20. Round-boundary cleanup defensively removes stale activation-local state but
    is not the normal progression mechanism for completing an activation.
21. Save/load, replay, network mirroring, and reconnect reconstruct the same
    identity, dispositions, count, active Maneuver execution record, and
    purpose-specific nested consequence state before presentation is derived.

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
| Commit Maneuver | Validate the matching activation identity, Maneuver `OPEN`, no active execution record, and the selected legal committed result. Atomically consume the selected Navigate source or sources, apply the resulting canonical speed and committed result, and establish the matching active Maneuver execution record. Leave Maneuver `OPEN`. | The semantic maneuver execution path represented by `ExecuteManeuverCommand`; current separate speed-change, resource-spend, or scene-only speed-zero paths are migration evidence, not alternative owners or boundaries. |
| Resolve a nested mandatory Maneuver consequence | Validate the matching activation and Maneuver execution identities, update the purpose-specific canonical consequence owner, and return authority-side to the active Maneuver boundary for re-evaluation. | Existing overlap, damage, squadron-displacement, obstacle, and rule-capability paths are implementation evidence that must converge on this composed responsibility; scene callbacks and `InteractionFlow` are not completion owners. |
| Complete Maneuver | Validate the matching activation and Maneuver execution identities, Maneuver `OPEN`, and that no mandatory consequence remains. Atomically change Maneuver to `CONSUMED` and retire the record exactly once. It SHALL NOT use `UNREACHED` to `CONSUMED` as normal progression. | The current `ExecuteManeuverCommand` path is evidence for authoritative execution, but any consumption before mandatory consequence completion is a migration risk rather than normative behavior. |
| Complete surviving normal ship activation | Require both dispositions to be `CONSUMED`; in particular, reject completion while Maneuver is `UNREACHED` or `OPEN`. Then perform existing activation completion effects and atomically remove the identity and activation-boundary facts. | The normal activation completion path represented by `EndActivationCommand`. |
| Exceptionally terminate ship activation, including active-ship destruction | As part of an accepted exceptional terminal transaction, atomically terminate the active identity and clear its activation-boundary facts, including any active Maneuver execution record, plus purpose-specific nested consequence state that is invalid without that execution. Do not return to a nonexistent Maneuver boundary, change Maneuver to `CONSUMED` solely for termination, or fabricate Maneuver execution or completion. | Existing damage, overlap, destroy, `ShipInstance` destruction, and other accepted exceptional terminal paths require convergence on this responsibility during implementation refinement. |
| Round-boundary defensive cleanup | Clear any stale activation identity and associated facts while preserving the rule-defined round reset behavior. It SHALL reject or report impossible multi-owner state rather than choose an owner from presentation state. | Existing status cleanup and `ShipInstance` activation reset paths. |

These responsibilities fit existing semantic command and cleanup boundaries.
This ADR does not require or authorize a new semantic command type. If later
Entry Gate evidence proves an existing transition cannot own one of these
mutations atomically, implementation SHALL stop for architecture review rather
than invent a command or presentation owner.

## 6. Persistence, Reconstruction, and Atomicity

### 6.1 Serialization and Save/Load

The activation identity, two opportunity dispositions, committed count, and
optional active Maneuver execution record serialize exactly once under their
owning `ShipInstance` within the canonical `GameState` aggregate. The record
contains only facts permitted by Section 3.3; nested consequences remain with
their accepted purpose-specific canonical owners.

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
and later transitions validate that identity before changing dispositions, the
count, the active Maneuver execution record, or nested consequence state.
Replay SHALL reproduce the accepted Maneuver commitment, nested consequences,
and exact-once completion; it SHALL NOT infer canonical activation progress
from routes, modals, resolver counters, callbacks, or scenes.

### 6.3 Network Host and Mirror

The authoritative host executes and retains the authoritative owner-local
facts. Passive peers install or project the same viewer-authorized canonical
semantics through the purpose-specific filtered or passive representations
permitted by accepted Network architecture; they need not receive
authority-private representation. Transport, local UI state, and controller
location do not alter ownership or transition semantics. A mirror passively
applies or projects accepted results and does not originate Maneuver
commitment, consequence completion, or progress from a displayed step.

### 6.4 Reconnect

Reconnect installs and validates canonical `GameState`, including the owning
ship's activation-local facts and any purpose-specific nested consequence
state, before reconstructing controller routing, UI route, modal state,
remaining capacity, Maneuver interaction, or post-Skip presentation. Recovery
therefore presents a decision-equivalent pending consequence or completes the
Maneuver only when the authoritative facts permit it.

### 6.5 Snapshot and Rollback

A command that may change the activation boundary SHALL validate all
participating owners before mutation, snapshot the complete affected
`ShipInstance` boundary and every adjacent authoritative owner in the same
transaction, apply mutations, cross-validate, and restore all snapshots on
failure.

Partial mutation of identity, either disposition, the committed count, the
active Maneuver execution record, committed speed or result, selected Navigate
resources, `CurrentAttackState`, timing-window state, squadron position or
action state, obstacle consequence state, or destruction state is invalid.
Rollback SHALL restore the previous identity and all facts scoped to it
exactly.

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
- a committed Maneuver remains distinguishable from transient exploration and
  recoverable until every mandatory consequence completes;
- capacity remains responsive to current authoritative resources and rules;
  and
- the decision adds only the narrow activation-local facts required by the
  accepted responsibilities in scope.

Tradeoffs:

- aggregate validation must scan both fleets to enforce active-identity
  uniqueness;
- all accepted semantic paths that enter, advance, terminate, destroy, or reset
  an active ship must converge on the same owner-local lifecycle operations;
- commands touching adjacent attack, squadron, destruction, or timing owners
  must snapshot and roll back a wider atomic boundary;
- Maneuver commitment and completion are distinct authoritative boundaries,
  with purpose-specific nested consequence owners participating between them;
  and
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
- current maneuver execution may consume the Maneuver opportunity before
  mandatory squadron displacement or obstacle consequences complete;
- Navigate speed/resource changes and candidate geometry may currently cross
  the authoritative boundary before Maneuver commitment;
- obstacle-overlap detection and effects may not yet participate completely in
  authoritative Maneuver completion;
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
purpose-specific opportunity lifecycles, while Maneuver recovery additionally
requires the identity and minimal non-derivable facts of at most one actual
committed execution. A generic step field, Maneuver phase enum, and predecessor
graph would decide broader activation architecture without evidence or owner
approval.

### 12.5 New Top-Level Decision Manager or Queue

Rejected. The required facts have a natural existing entity-local owner and
existing semantic transition boundaries. A generic manager or queue would add
unrelated authority and continuation semantics.

### 12.6 Derivation Without an Active Maneuver Execution Record

Rejected. Maneuver `OPEN`, canonical speed, ship transform, resource state, and
overlap geometry cannot in every case distinguish uncommitted exploration from
a committed speed-zero or no-translation result, nor prove that a persistent
overlap consequence has already resolved. Replaying command history is not a
substitute for canonical save/load or reconnect state. The narrow record is the
minimum fact that closes that recovery and exact-once ambiguity.

## 13. Explicit Non-Goals

This ADR does not introduce or authorize:

- a general ship-activation FSM;
- a generic `current_activation_step`;
- a generic DecisionManager or decision queue;
- a generic Maneuver FSM, continuation stack, callback owner, or work queue;
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

None remain for this refinement.

Cross-fleet uniqueness is supported by SP-001 and TF-003, which require players
to alternate activation of one ship, and by the committed implementation's
single-active-ship entry guards. This ADR therefore records the invariant
rather than deferring it as an implementation question.

The Project Owner accepted the active Maneuver execution ownership and narrow
otherwise-unspecified overlap-order interpretation recorded by the 2026-09-09
refinement.

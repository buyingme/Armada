# ADR-007: Purpose-Specific Completed-Attack Result Inspection Lifecycle

Status: Accepted

ADR-ID: ADR-007
Title: Purpose-Specific Completed-Attack Result Inspection Lifecycle

Accepted by: Project Owner

Accepted date: 2026-08-15

Decision owner: Project Owner

Decision source:
- `docs/architecture/implementation_workbooks/UX-005-completed-attack-inspection-owner-decisions.md`

Supersedes:
None

Superseded by:
None

Related:
- UX-005
- ADR-001
- ADR-005
- ADR-006
- CON-001
- CON-005
- CON-006
- TWI-003
- TEST-003
- AT-001
- AT-002
- AT-008
- AT-009
- BC-001
- BC-003
- BC-007
- BC-008
- BC-009
- BC-010
- RG-001
- RG-002
- RG-003
- RG-004
- RG-013
- RG-014

Inputs:
- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/implementation_workbooks/UX-005-completed-attack-inspection-owner-decisions.md`
- `docs/qa/ux/verify/UX-005/issue-Allow-player-to-inspect-anti-squadron-attack-result-before-continuing.md`
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/adr/ADR-006-canonical-ship-activation-boundary-ownership.md`
- `docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md`
- `docs/architecture/implementation_workbooks/TWI-003-authoritative-current-attack-state-implementation-workbook.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`

## Draft Note

This ADR records the narrow architecture decision selected by the Project Owner
for UX-005. It has no accepted authority until the Project Owner accepts it
under the repository document-authority model.

It authorizes no implementation by itself. A later implementation workbook
must translate the accepted decision into a cutover, compatibility allocation,
and verification plan.

## 1. Context

UX-005 requires a complete resolved attack result to remain inspectable until
the required human viewers explicitly acknowledge it. The attack and all
damage are already resolved at that point, but enclosing gameplay must not
continue while a required acknowledgement is outstanding.

The previous local presentation implementation cannot own that barrier. A
scene flag, modal lifetime, timer, `InteractionFlow` route, or local network
mirror cannot survive all save/load and reconnect paths, cannot reproduce the
same replay order, and cannot prevent another peer or authoritative execution
path from continuing gameplay.

The barrier also cannot remain in `CurrentAttackState`. ADR-001 and CON-001
define that state as authority for one active attack and require successful
completion to retire it. Completed-result inspection starts only after the
attack and its damage are complete. Keeping the attack active for presentation
would blur attack legality, stale-command rejection, cleanup, and downstream
continuation.

The barrier is not a timing window. It derives no rule opportunities, provides
no use/decline ordering, owns no timing point, and does not recalculate rule
eligibility. Treating it as `TimingWindowState` would broaden ADR-005 and
CON-005 beyond rule timing-window lifecycle and would compete with their
existing continuation authority.

The missing boundary is therefore one purpose-specific canonical lifecycle
between completed attack retirement and the already-existing continuation
derived from authoritative `ShipInstance` or `SquadronInstance` state.

## 2. Decision

`GameState` SHALL own zero or one canonical pending completed-attack result
inspection.

For each applicable UX-005 attack result:

1. the attack, including all damage, resolves through its existing accepted
   command and state owners;
2. the terminal attack transaction retires `CurrentAttackState` normally and
   establishes the completed-attack inspection before enclosing gameplay can
   continue;
3. gameplay remains blocked while any required acknowledgement is outstanding;
4. each acknowledgement is submitted through
   `AcknowledgeAttackResultCommand`; and
5. once all required acknowledgements are received, the existing
   `ShipInstance`- or `SquadronInstance`-derived continuation becomes eligible
   and executes exactly once through its accepted path.

This is one purpose-specific lifecycle. It is not a generic acknowledgement
framework, continuation-barrier abstraction, voting system, interaction/gameplay
FSM, or canonical presentation lifecycle.

## 3. Ownership

### 3.1 Canonical Lifecycle Owner

`GameState` is the sole authoritative owner of the pending completed-attack
inspection and its acknowledgement sets. No second writable representation is
permitted.

The existing terminal attack transaction owns creation of the pending
inspection at the completed-attack boundary. This coordination does not move
attack resolution, dice mutation, damage application, or current-attack
retirement out of their existing command and state owners.

`AcknowledgeAttackResultCommand` is the sole replayable mutation surface for
received acknowledgements.

The existing enclosing continuation path remains the owner of the next
gameplay transition. It consumes the satisfied inspection as a precondition;
the inspection does not own or describe the continuation itself.

### 3.2 Non-Owners

`TimingWindowState`, the Timing Window Orchestrator, `InteractionFlow`,
`FlowSpec`, `UIProjector`, `StateFilter`, scene controllers, modal routers,
panels, timers, and local UI flags SHALL NOT own, satisfy, clear, or bypass the
inspection barrier.

Projection and presentation may derive visibility, controls, waiting state,
and local dismissal from canonical inspection state. Those derived values do
not authorize acknowledgement or continuation.

## 4. State Boundary

### 4.1 Minimal Canonical Content

The pending completed-attack inspection SHALL contain only:

- stable deterministic inspection identity;
- stable attacker identity, defender identity, and attack-kind identity;
- the minimal immutable final result snapshot required to reconstruct the
  same completed result after `CurrentAttackState` has retired;
- the immutable set of required acknowledgement principals; and
- the set of received acknowledgement principals.

The inspection identity SHALL distinguish the pending result from every
earlier or later completed attack and SHALL be sufficient for stale-command
rejection across save/load, replay, networking, and reconnect. This ADR does
not prescribe its concrete representation.

The final result snapshot SHALL be sufficient to reconstruct the applicable
final dice/result and already-applied ship shield/hull or squadron hull damage
outcome. An individual snapshot fact is permitted only when it is JSON-safe,
belongs to the completed result, is required to reconstruct that result, and
cannot be reliably re-derived from another accepted canonical owner at
reconstruction time.

The snapshot is immutable historical result evidence. It SHALL NOT become a
second writable copy of entity health, attack state, or damage state and SHALL
NOT be used to reapply or validate gameplay effects.

### 4.2 Required And Received Semantics

At the completed-attack boundary, the required set is derived once from the
accepted session/play-mode and human-participant authority. When an inspection
is created, that set SHALL remain stable for the inspection identity and SHALL
NOT be derived from visible buttons, connected UI nodes, peer presence, or
local presentation state.

If that accepted derivation produces an empty required set, no
completed-attack inspection is created. Implementation SHALL NOT create an
empty pending inspection, synthesize bot acknowledgements, or invent fake
human principals merely to satisfy a non-empty invariant. This future-facing
rule does not define general bot, controller, or session architecture.

The received set:

- starts empty;
- contains only principals in the required set;
- grows by exactly one principal for each accepted acknowledgement; and
- never removes or replaces a received principal while the inspection exists.

Outstanding acknowledgements are derived as `required - received`. The
inspection is satisfied if and only if `received == required`.

Satisfaction is a derived condition, not a generic lifecycle step. A satisfied
inspection MAY remain canonical until the existing continuation transaction
successfully consumes it. No separate generic barrier status, current-step
field, or continuation descriptor is authorized.

### 4.3 Prohibited State

The canonical inspection SHALL NOT contain:

- button visibility or enabled state;
- panel geometry, layout, animation, or modal state;
- arbitrary UI or scene lifecycle state;
- `InteractionFlow` state or routing payloads;
- a generic current step or interaction state;
- timing-window identity, opportunities, or lifecycle state;
- mutable attack or damage state;
- a continuation command object, generic continuation token, queue, or
  descriptor; or
- unrelated ship-activation or squadron-activation progress.

## 5. Command Semantics

`AcknowledgeAttackResultCommand` is one narrow replayable semantic command. It
records that the authenticated or otherwise authoritatively validated
submitting human principal acknowledges the currently pending inspection.

The command SHALL carry or derive enough stable identity to bind its intent to
one inspection. Immediately before mutation it SHALL validate:

- that a pending inspection exists;
- that the submitted inspection identity matches it;
- that the submitting principal is authenticated or otherwise authorized by
  the accepted command-submission authority;
- that the principal belongs to the required set;
- that the principal has not already acknowledged; and
- that command order and enclosing authoritative state still permit the
  acknowledgement.

An accepted command adds only that principal to the received set and records
the command once in authoritative history. A rejected, stale, duplicate,
wrong-principal, missing-inspection, or out-of-order command mutates nothing,
records no accepted acknowledgement, and releases no continuation.

`AcknowledgeAttackResultCommand` SHALL NOT:

- resolve, repeat, cancel, replace, or complete an attack;
- roll, modify, confirm, or otherwise mutate dice;
- calculate, apply, repeat, reveal, or repair damage;
- create, restore, or mutate `CurrentAttackState`;
- mutate `TimingWindowState` or resolve a timing opportunity;
- select or directly perform the next gameplay step;
- accept caller-provided required/received sets or a result snapshot as
  authority; or
- act as a generic acknowledgement or voting command.

## 6. Continuation Semantics

The completed-attack inspection is an authoritative precondition for the
existing completed-attack continuation. While it exists and is not satisfied,
no scene callback, timer, command-result handler, peer, replay helper, or
enclosing controller may advance gameplay past that completed attack.

Acceptance of the final required acknowledgement changes only canonical
acknowledgement state. It releases eligibility for the existing continuation;
it does not make `AcknowledgeAttackResultCommand` the owner of the next
gameplay mutation.

The accepted continuation path SHALL:

1. derive the correct next transition from the existing authoritative
   `ShipInstance` or `SquadronInstance` state;
2. validate that the matching inspection exists and is satisfied;
3. perform the same continuation mutation that would otherwise follow a
   completed attack;
4. retire the matching inspection as part of the successful continuation
   transaction; and
5. reject a second release for the same inspection identity.

The inspection SHALL store no copy of whether the next result is another ship
attack, Maneuver availability, remaining squadron movement/action, squadron
completion, or another enclosing route. Those facts and their transition
semantics remain on their accepted owners.

If the existing continuation fails validation or execution, the satisfied
inspection remains canonical, no partial next step is exposed, and another
acknowledgement is not required. Recovery re-evaluates the same satisfied
purpose-specific inspection and existing continuation path. It SHALL NOT invent
a fallback continuation or a new continuation architecture.

Exactly-once release means that one inspection identity can be consumed by at
most one accepted continuation transaction. Duplicate callbacks, mirrored
results, replay application, reconnect reconstruction, or presentation
teardown cannot consume it again.

No timeout may acknowledge a result, satisfy the inspection, consume it, or
release continuation. The legacy automatic final-result continuation timer
must be removed from authority at implementation cutover.

## 7. Hot-Seat And Network Semantics

### 7.1 Hot-Seat

Hot-Seat uses the same canonical inspection and command protocol as other
modes. The required set contains exactly one human acknowledgement principal
derived from accepted Hot-Seat session/play-mode authority.

One accepted `AcknowledgeAttackResultCommand` satisfies the inspection and
releases the existing continuation. A local presentation flag cannot substitute
for that command.

### 7.2 Two-Human Network

For a two-human Network session, the required set contains both participating
human player principals derived from accepted session authority. It SHALL NOT
be permanently hard-coded as player 0 and player 1.

Each human submits an independent `AcknowledgeAttackResultCommand` through the
authoritative network command path. The authoritative host validates and
orders the command; mirrors apply accepted results in authoritative sequence.
Clients SHALL NOT optimistically mutate received acknowledgements or release
continuation.

After one acknowledgement is accepted:

- that player's local result presentation may be dismissed;
- the other player's complete result and acknowledgement action remain
  available; and
- authoritative gameplay remains blocked.

Only the complete required set releases continuation.

A future bot or automated controller is not a required human acknowledgement
principal unless a later explicit design decision says otherwise. This ADR
does not define bot behavior or general controller architecture.

## 8. Persistence, Replay, And Reconnect

### 8.1 Save And Load

The pending inspection is durable canonical `GameState` and SHALL serialize
exactly once with that owner.

Saving and loading while it is pending SHALL preserve or reconstruct:

- inspection identity;
- attacker, defender, and attack-kind references;
- the immutable minimal result snapshot;
- required acknowledgements;
- received acknowledgements;
- outstanding acknowledgements;
- the complete derived result presentation; and
- the blocked or satisfied-but-not-yet-consumed continuation condition.

Canonical inspection state SHALL be installed and validated before projection,
interaction routing, acknowledgement affordances, or continuation evaluation.
Load SHALL NOT reconstruct acknowledgement from a modal, route, timer, or
client-local flag.

### 8.2 Replay

Accepted acknowledgements are semantic replay events because they change
authoritative continuation eligibility. Replay SHALL apply them in
authoritative command-history order and reproduce the same pending, partially
acknowledged, satisfied, and released ordering.

Replay SHALL NOT synthesize an acknowledgement to advance, omit a required
acknowledgement, or infer acknowledgement from absent presentation. Replay and
mirror execution SHALL also avoid independently resubmitting a continuation
already represented by the authoritative command/result protocol.

The same completed-attack transaction that creates the inspection in live play
creates it under replay. The same existing continuation path consumes it after
the recorded required acknowledgements are satisfied.

### 8.3 Reconnect

Reconnect SHALL install the authoritative pending inspection before deriving
presentation or accepting another command.

Already received acknowledgements remain received. Missing acknowledgements
remain outstanding. A player whose acknowledgement was accepted may receive a
dismissed or waiting presentation derived from that fact; another required
player still receives the complete result and acknowledgement affordance.

Gameplay remains blocked while any acknowledgement is outstanding. If the
inspection was already satisfied but its existing continuation had not yet
committed, reconnect re-evaluates that same continuation eligibility without
synthesizing another acknowledgement or permitting duplicate release.

## 9. Visibility And Filtering

The existence, identity, required set, received set, and outstanding status of
a completed-attack inspection are not hidden gameplay information between the
two participating Network peers.

State filtering SHALL preserve enough canonical information for both peers to
reconstruct the same barrier and complete resolved result. Projection MAY vary
prominence, waiting treatment, and whether an already-acknowledged player's
local panel remains open. Such presentation differences do not change
canonical state.

Visibility does not grant command authority. Only a required, authoritatively
validated principal may acknowledge, even when another peer can see that the
acknowledgement is outstanding or received.

This decision does not broaden visibility of unrelated hidden information.
Any information outside the minimal completed result remains governed by its
existing visibility authority.

## 10. Validation And Invariants

Conforming implementations SHALL preserve these invariants:

1. At most one completed-attack inspection is pending in `GameState`.
2. A pending inspection represents an attack whose resolution and damage are
   complete and whose `CurrentAttackState` has retired.
3. Creation of the inspection and retirement of the matching current attack
   expose no state in which enclosing continuation may overtake the barrier.
4. The result snapshot is immutable and cannot apply gameplay effects.
5. Every created inspection has a non-empty, mode-correct, immutable required
   set derived from accepted session/play-mode authority; an accepted empty-set
   derivation creates no inspection.
6. The received set is a monotonic subset of the required set.
7. Satisfaction is exactly `received == required`.
8. One accepted acknowledgement adds exactly one previously outstanding
   required principal.
9. Stale, duplicate, wrong-principal, missing-inspection, and out-of-order
   acknowledgements reject before mutation.
10. No continuation occurs while an acknowledgement is outstanding.
11. The final acknowledgement releases only the existing continuation and does
    not directly perform its gameplay mutation.
12. One inspection identity is consumed by at most one accepted continuation.
13. Save/load, replay, mirrors, and reconnect preserve the same identity,
    acknowledgement sets, continuation eligibility, and release order.
14. Projection, filtering, scenes, modals, routes, timers, and local flags
    cannot satisfy or bypass the barrier.
15. No timeout or replay-only synthetic acknowledgement advances gameplay.

Validation failure SHALL preserve every participating authoritative owner,
surface a deterministic rejection or diagnostic, and fail closed.

## 11. Non-Goals And Prohibited Interpretations

This ADR does not introduce or authorize:

- a generic acknowledgement framework or acknowledgement registry;
- a generic continuation barrier, continuation queue, or decision manager;
- a generic interaction or gameplay FSM;
- generic current-step or activation-step state;
- canonical presentation, panel, modal, or button state;
- `InteractionFlow` as gameplay or continuation authority;
- `TimingWindowState` as completed-result inspection authority;
- a timing-window opportunity for acknowledging a result;
- replay-only synthetic acknowledgement;
- automatic acknowledgement, or timeout-based release while an
  acknowledgement remains outstanding;
- a compatibility bridge, dual write, fallback, or legacy execution mode;
- a new attack, damage, activation, controller, transport, or bot architecture;
- a copy of enclosing continuation state in the inspection;
- changes to attack/damage resolution semantics;
- changes to `CurrentAttackState` membership or retirement semantics;
- changes to ADR-006 ship-activation ownership; or
- changes to the existing continuation behavior after the barrier releases.

## 12. Consequences

Positive consequences:

- UX-005 continuation is deterministic across Hot-Seat, Network, save/load,
  replay, and reconnect;
- completed attack results can remain available after `CurrentAttackState`
  retires without keeping an attack artificially active;
- both Network humans can acknowledge independently without granting a client
  local continuation authority;
- the existing Ship/Squadron continuation remains the only next-step
  architecture; and
- stale and duplicate acknowledgement or release attempts can be rejected by
  stable identity.

Tradeoffs:

- `GameState` gains one additional purpose-specific durable boundary;
- attack completion, command registration, serialization, filtering, replay,
  network mirroring, reconnect, and the existing continuation seam require one
  coordinated semantic cutover;
- canonical state and command history change, requiring explicit compatibility
  review and likely artifact-version allocation; and
- a satisfied inspection may remain present until the existing continuation
  commits, so projection must distinguish outstanding acknowledgement from
  waiting for release without inventing a canonical presentation step.

## 13. Implementation Obligations

After acceptance and before semantic implementation begins, a follow-up
implementation workbook Entry Gate SHALL establish both of these evidence
proofs.

Human-principal source proof:

- identify the existing accepted source from which required human
  acknowledgement principals will be derived;
- prove that source is authoritative for each supported play mode;
- prove that Hot-Seat derives exactly one required human acknowledgement
  principal and two-human Network derives both participating human principals;
  and
- prove that derivation does not depend on UI controls, currently connected
  peers, local controller objects, or permanently hard-coded player indices.

If no accepted authoritative human-principal source exists, implementation
SHALL stop for architecture clarification. It SHALL NOT solve that absence by
storing general play mode, connection or session objects, controller identity,
or generic participant state in `GameState`. Only the immutable,
inspection-scoped required-principal set may be stored after it has been
validly derived.

Continuation-release proof:

For every applicable ship and squadron attack context, the Entry Gate SHALL
identify and prove:

1. the existing replayable semantic transaction that performs the next
   gameplay mutation after the inspection barrier releases;
2. the existing authoritative release or submission seam that invokes or
   enables that transaction after live acknowledgement satisfaction, load of
   satisfied-but-unconsumed inspection state, and reconnect of
   satisfied-but-unconsumed inspection state;
3. that live Network execution originates semantic continuation only from the
   authoritative side;
4. that passive mirrors do not synthesize continuation;
5. that replay does not auto-submit or synthesize live continuation in
   addition to the recorded replay command stream; and
6. that inspection consumption remains atomic and exactly once with that
   existing continuation transaction.

If any applicable context lacks those existing mappings, requires a new
continuation owner, or requires a second continuation architecture,
implementation SHALL stop for architecture clarification. These are evidence
obligations for the existing continuation seams claimed by this ADR; they do
not specify or authorize new continuation mechanics.

After those Entry Gate proofs pass, the follow-up implementation workbook
SHALL:

- map the exact existing attack-completion transaction that atomically creates
  the inspection after damage and retires `CurrentAttackState`;
- define the minimal JSON-safe result snapshot from concrete existing result
  data without duplicating live entity or attack authority;
- implement required-principal derivation only from the authoritative source
  proven by the Entry Gate;
- register `AcknowledgeAttackResultCommand` through applicability,
  serialization, replay, network mirror, and concrete validation paths;
- bind each applicable ship and squadron completion only to the existing
  `ShipInstance`- or `SquadronInstance`-derived continuation proven by the Entry
  Gate, without storing a continuation descriptor in the inspection;
- make successful continuation consume the satisfied inspection atomically
  and reject duplicate release;
- remove timeout and local-flag continuation authority at the semantic cutover;
- reconstruct projection from canonical state for local play, mirrors, load,
  and reconnect;
- provide production-path evidence for ship-to-ship, ship-to-squadron,
  anti-squadron, and applicable squadron attacks;
- verify Hot-Seat one-acknowledgement and Network two-human independent
  acknowledgement behavior, including partial acknowledgement;
- verify save/load, replay, network ordering/filtering, reconnect, stale and
  duplicate rejection, exact-once continuation, atomic failure, and no
  attack/damage repetition; and
- preserve every neighboring CON-001, CON-005, CON-006, ADR-006, TWI-003, and
  applicable TEST-003 invariant.

Implementation SHALL stop for architecture clarification if either Entry Gate
proof fails. Failure is not permission for local invention. Implementation
SHALL also stop for Project Owner guidance if it requires a generic framework,
a new continuation owner, a second canonical owner, a general step, a
compatibility bridge, or a change to existing attack, timing-window, or
activation ownership.

## 14. Compatibility Implications

The canonical pending inspection changes `GameState` serialization and the
semantic continuation boundary. `SaveGameMetadata.CURRENT_VERSION` remains the
only save-format compatibility owner. The implementation workbook must decide
whether prior saves can be accepted as semantically equivalent, require one
deterministic migration, or must be rejected fail-closed. Missing inspection
state SHALL NOT be inferred from legacy presentation, `InteractionFlow`, scene,
modal, timer, or command-result data.

The new replayable acknowledgement and required release ordering change replay
semantics. A legacy replay that completes an attack without the now-required
acknowledgements cannot be advanced by synthesizing them. The implementation
workbook must therefore define the replay compatibility cutover through
`GameReplay.FORMAT_VERSION` and its accepted signed alias, including rejection
before incompatible command application where required.

TWI-003 allocated its concrete save and replay values only for the TWI-003
cutover. It does not allocate values for UX-005 and explicitly prohibits
automatic version selection. This ADR therefore assigns no save or replay
version number. A later UX-005 implementation workbook must inspect the actual
current allocations, choose any required new values without collision, and
bind them atomically to the semantic cutover. No compatibility bridge or
parallel legacy execution mode is authorized.

Reconnect remains an authoritative state-reconstruction path, not a separate
durable artifact format. Mixed-semantic network sessions and stale snapshots
must fail according to existing authoritative session and reconstruction
policy rather than infer acknowledgement or continuation.

## 15. Relationship To Existing ADRs And Contracts

### 15.1 ADR-001 And CON-001

ADR-001 and CON-001 remain authoritative for active `CurrentAttackState`,
semantic attack mutation, terminal retirement, stable current-attack identity,
atomicity, and non-authoritative projection.

This ADR adds an adjacent post-completion owner. The inspection is distinct
because the attack no longer exists as an active attack, damage is already
committed, and the only pending semantic fact is whether completed-result
inspection still blocks continuation. The terminal attack transaction may
coordinate creation of this adjacent owner without moving or duplicating
current-attack facts.

### 15.2 ADR-005 And CON-005

ADR-005 and CON-005 retain exclusive timing-window lifecycle, opportunity
re-derivation, and timing continuation authority. Completed-result
acknowledgement is not a timing opportunity and does not participate in their
use/decline or participant-discovery protocol.

Any attack-scoped timing window must already have reached its accepted terminal
condition before a completed attack enters this inspection. This ADR neither
closes a timing window nor changes its continuation mapping.

### 15.3 ADR-006

ADR-006 remains authoritative for `ShipInstance`-owned activation identity,
Squadron-command and Maneuver dispositions, and committed Squadron-command
activation count. The inspection stores none of those facts.

For a completed ship attack, the barrier prevents the next enclosing gameplay
progression even when the accepted attack-completion transaction has already
committed adjacent ADR-006 facts. Acknowledgement never mutates those facts.
After release, the same accepted continuation derives and performs the next
ship-activation transition exactly once from the owning `ShipInstance`.

### 15.4 CON-006

CON-006 ends at accepted attack entry or no-active declaration Skip and
explicitly excludes behavior after accepted Begin, active-attack completion,
damage, and post-completion target iteration. This ADR does not change Preview,
Begin, declaration Skip, or declaration ownership. It governs the later
completed-result boundary only.

### 15.5 TWI-003

TWI-003 remains the accepted implementation specification for its declaration
migration and protected neighboring continuation. It intentionally excludes
active attack completion and post-Begin changes, so it does not authorize
UX-005 implementation.

After this ADR is accepted, a separate UX-005 implementation workbook must
integrate the new barrier without rewriting TWI-003 ownership, declaration,
or continuation outcomes. Its existing concrete compatibility allocations
cannot be reused or extended by inference.

### 15.6 TEST-003

TEST-003 remains the verification authority for interactive rule timing
windows. This ADR does not classify result acknowledgement as a timing-window
capability and does not broaden TEST-003.

Where a neighboring timing window interacts with attack completion, UX-005
verification must preserve TEST-003 command ordering, reconstruction,
networking, visibility, and no-overtaking evidence. A follow-up verification
artifact should define the additional purpose-specific inspection evidence
rather than restating TEST-003.

## 16. Owner Decision Traceability

| Owner Decision | ADR sections |
| --- | --- |
| OD-001 — authoritative continuation barrier | Sections 1, 2, 6, and 10 |
| OD-002 — purpose-specific concept only | Sections 2, 4.3, and 11 |
| OD-003 — `GameState` owner, separate boundaries | Sections 1, 2, 3, and 15 |
| OD-004 — minimal canonical state | Section 4 |
| OD-005 — mode-dependent required set | Sections 4.2 and 7 |
| OD-006 — replayable acknowledgement command | Sections 5 and 8.2 |
| OD-007 — existing exact-once continuation | Sections 3.1 and 6 |
| OD-008 — persistence | Sections 8.1 and 14 |
| OD-009 — replay | Sections 5, 8.2, and 14 |
| OD-010 — reconnect | Section 8.3 |
| OD-011 — per-player Network presentation | Sections 7.2, 8.3, and 9 |
| OD-012 — Hot-Seat behavior | Section 7.1 |
| OD-013 — visibility | Section 9 |
| OD-014 — no automatic timeout | Sections 6, 10, and 11 |
| OD-015 — explicit exclusions | Sections 4.3 and 11 |

## 17. Open Questions

OD-001 through OD-015 resolve ownership and product semantics. No further
Project Owner product decision is currently required to make this Draft
reviewable.

Semantic implementation is nevertheless conditional on the Section 13 Entry
Gate proving both the authoritative human-principal source and every applicable
existing continuation-release mapping. Failure to prove either dependency is
an architecture stop, not permission for local invention. This evidence
condition does not reopen or weaken the resolved Owner decisions.

One implementation allocation remains intentionally unresolved: the concrete
save and replay version values and the exact accept/migrate/reject disposition
for pre-cutover artifacts. Existing authority makes the compatibility owners
unambiguous but does not allocate UX-005 values. The follow-up implementation
workbook must make that collision-checked allocation before implementation;
this does not block Project Owner review of the architectural decision.

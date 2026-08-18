# UX-005 Post-Attack Continuation Ownership — Draft Decision Workbook

Status: Draft decision workbook
Date: 2026-08-18
Decision owner: Project Owner
Related: UX-005, ADR-007, ADR-001, ADR-006, CON-001, CON-006, MA-ATTACK-001, MATCH-001

## 1. Purpose and Decision Boundary

ADR-007 Entry Gate A is now evidenced by MATCH-001. Entry Gate B does not
pass: the repository has authoritative attack completion, but does not yet
have one proven authoritative, replayable release path for every applicable
post-completion gameplay transition. In particular, `AttackExecutor` result
acknowledgement and callback paths still decide or submit some progression.

This workbook asks the Project Owner for six narrow decisions needed to choose
that ownership. It is decision preparation only; it is not an ADR, Contract,
implementation workbook, API design, test plan, or authorization to implement
UX-005.

The recommended direction is to retain the existing entity-local progress
owners and existing command families, and to use the existing authoritative
command-processing follow-up seam as the sole live-authority release seam.
It must select only the already-applicable semantic transaction for a branch;
it must not create a generic continuation framework or store a continuation
descriptor in the ADR-007 inspection.

## 2. Authority and Minimum Evidence Inspected

### Accepted authority

- `DOCUMENT_AUTHORITY.md` and `CODEX_WORKFLOW.md` establish this as
  uncertain/high-risk architecture work and require an Owner decision when
  accepted authority does not resolve the missing continuation mapping.
- ADR-001 / CON-001 require replayable commands to own semantic attack
  mutation, require terminal retirement of `CurrentAttackState`, and prohibit
  scene, projection, route, modal, and UI state from becoming another gameplay
  owner.
- ADR-006 assigns ship-activation identity, Squadron-command and Maneuver
  opportunity dispositions, and committed Squadron-command count to the
  active `ShipInstance`. Its transition matrix names
  `AdvanceActivationStepCommand`, `ActivateSquadronCommand`,
  `ExecuteManeuverCommand`, and `EndActivationCommand` as existing semantic
  boundaries.
- CON-006 assigns ship attack-step progress to `ShipInstance`, squadron action
  and attack history to `SquadronInstance`, and command order to
  `CommandProcessor`. It expressly excludes active-attack completion and
  post-completion target iteration, so it does not decide this release seam.
- ADR-007 requires the inspection to be created at terminal attack retirement,
  releases only the existing `ShipInstance`- or `SquadronInstance`-derived
  continuation, requires exactly-once consumption with that transaction, and
  makes failure of the continuation-release proof an architecture stop. It
  forbids a generic continuation framework, new continuation owner, second
  canonical owner, or a continuation descriptor in inspection state.
- MATCH-001 is empirical implementation evidence only for this decision. It
  establishes the durable principal source required for Gate A and records
  that its avoidable cost came mainly from discovering affected test/fixture
  seams too late; it supplies no continuation architecture or numeric estimate.

### Current implementation evidence

| Seam | Observed ownership and consequence |
| --- | --- |
| `CompleteAttackCommand` | Validates resolved damage and retires `CurrentAttackState`; clears attack-scoped ECM/H9 runtime state; for a standard ship attacker, derives a result-only continuation label and ends an anti-squadron iteration only when no authoritative candidate remains. It does not perform the resulting ship activation, squadron activation completion, or release after result acknowledgement. |
| `ShipInstance` | Serializes `attack_step_active`, committed normal attack count, used hull zones, anti-squadron zone, and anti-squadron target history. `BeginAttackCommand` commits those facts atomically; `CompleteAttackCommand` may exhaust the anti-squadron iteration. These are canonical ship progress facts. |
| `SquadronInstance` | Serializes activation identity/context, move commitment, and attack-action disposition. `BeginAttackCommand` atomically marks an available squadron attack as begun. These are canonical squadron progress facts. |
| Existing transactions | `AdvanceActivationStepCommand` performs the ship Attack-to-Maneuver transition; `SkipAttackCommand` has an authoritative `squadron_done` branch for ending an anti-squadron iteration; `CompleteSquadronActivationCommand` completes a squadron when its canonical actions are exhausted. `ActivateShipCommand`, `ActivateSquadronCommand`, `ExecuteManeuverCommand`, and `EndActivationCommand` retain their existing activation boundaries. |
| `AttackExecutor` and callbacks | After local result confirmation, the scene decides whether to prepare another normal attack, prepare another anti-squadron target, end an anti-squadron loop, emit `attack_exec_completed`, or notify the squadron modal. The ship controller then submits the maneuver-step transition; the squadron modal/controller later submits activation completion. This is the Gate B gap. |
| `CommandProcessor` / `CurrentAttackContinuation` | The processor already has one post-success deferred-follow-up seam. `CurrentAttackContinuation` uses it only while `CurrentAttackState` remains active and synthesizes follow-ups only in live-authority mode; replay and passive mirrors do not synthesize them. It therefore supplies relevant release-seam evidence, but does not currently cover retired attacks or ADR-007 inspection. |
| Persistence and distribution | `GameState` serializes canonical entity state and active attack state; `CommandProcessor` records accepted ordered commands; replay validates command sequence; Network submits to the authoritative side and mirrors accepted commands. MA-ATTACK-001 found strong active-attack persistence/replay evidence but no complete authoritative enclosing-progress/release proof. `StateFilter`/reconnect evidence remains reconstruction-oriented rather than a production continuation RPC. |

Current code is evidence of reality, not authority to preserve scene ownership.

## 3. Context Differences That Matter

| Context | Canonical progress owner(s) | What follows a completed individual attack | Material difference |
| --- | --- | --- | --- |
| Normal ship attack | Activating `ShipInstance`; aggregate validation in `GameState` | A second normal declaration may remain derived from committed count and used zones; otherwise the existing ship Attack-to-Maneuver transition is required. | A normal second-attack opportunity can be a derived availability, not necessarily a new durable progress mutation. |
| Ship anti-squadron attack | Same `ShipInstance` | The same locked hull zone may iterate eligible untargeted squadrons; when iteration ends, normal ship-attack availability or Attack-to-Maneuver follows. | The loop has separate canonical target history and an explicit existing `squadron_done` command branch. It cannot be treated as merely another normal ship attack. |
| Squadron attack in Squadron Phase | Activating `SquadronInstance` plus canonical squadron-phase progress in `GameState` | A remaining Rogue movement action may remain; otherwise the existing squadron-completion/turn-control transition follows. | Completion can change phase counters/controller and is not a ship activation transition. |
| Squadron attack under a Ship Squadron command | Activating `SquadronInstance` plus commanding `ShipInstance` | A remaining squadron movement action may remain; otherwise the existing squadron completion returns to the open ship Squadron-command opportunity. | The same squadron fact is validated against the commanding ship identity/opportunity; it must not be collapsed into Squadron Phase completion. |

The contexts share the ADR-007 barrier and the need for exact-once release,
but do not share one durable continuation fact or one next transaction.

## 4. Rating Key

Ratings are relative and qualitative: High is favorable; Medium is mixed; Low
is unfavorable. `Effort/risk` and `total efficiency` rate lower expected total
implementation/review/rework cost, not a fabricated credit estimate.

Abbreviations: **AC** architectural correctness; **ER** implementation effort
and migration risk; **DR** replay/Network/save-load determinism; **XO**
exact-once suitability; **SC** scalability for future rules, multiple attacks,
and anti-squadron attacks; **Bot** future bot compatibility; **FR** Codex
first-time-right reliability; **TE** expected total token/credit efficiency.

## 5. Owner Decisions

### PAC-OD-001 — Who owns semantic post-attack progression?

| Option | AC | ER | DR | XO | SC | Bot | FR | TE | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. Extend `CompleteAttackCommand` to own all post-completion progression | Low | Medium | Medium | Medium | Low | Medium | Low | Low | Eliminated |
| B. Add a new standalone post-attack continuation transaction | Low | Low | High | High | Medium | High | Medium | Low | Eliminated under ADR-007 |
| C. Existing applicable activation/action transition command owns each semantic branch; non-mutating next availability remains derived | High | High | High | High | High | High | High | High | Recommended |

**Recommendation:** C.

**Decision requested:** Confirm that `CompleteAttackCommand` remains the
terminal active-attack transaction only. A subsequent gameplay mutation is
owned by the already-applicable transaction for the canonical owner: ship
activation transition, anti-squadron iteration close, or squadron activation
completion. A branch with no gameplay mutation only re-derives the next legal
availability after the inspection releases.

**Decisive trade-off:** Option C leaves context-specific command selection
visible, but preserves ADR-007's existing-continuation rule and avoids making
one terminal attack command or a new generic command understand every future
activation branch. Option A would merge retirement with distinct enclosing
owners. Option B is technically deterministic but contradicts ADR-007's
requirement to use the existing continuation path and prohibition on a new
continuation owner; it would require an ADR change before use.

### PAC-OD-002 — Combined terminal completion or separate continuation?

| Option | AC | ER | DR | XO | SC | Bot | FR | TE | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. One combined completion-and-continuation transaction | Low | Medium | Medium | Medium | Low | Medium | Low | Low | Eliminated |
| B. Terminal completion creates the ADR-007 inspection; a later existing branch transaction consumes satisfied inspection atomically when it mutates gameplay | High | High | High | High | High | High | High | High | Recommended |
| C. Acknowledgement directly performs the next gameplay mutation | Low | High | Low | Low | Medium | Medium | Low | Low | Eliminated |

**Recommendation:** B.

**Decision requested:** Confirm a two-boundary semantic model: terminal
completion retires the attack and establishes inspection; after satisfaction,
the existing branch transaction consumes that exact inspection atomically with
its own mutation. The acknowledgement command only changes inspection
satisfaction and never performs the next gameplay mutation.

**Decisive trade-off:** A superficially reduces command count but violates the
completed-result barrier and couples different owner lifecycles. B creates a
clear exact-once key without copying continuation state. C conflicts directly
with ADR-007 command semantics and makes reconnect/replay release ordering
depend on acknowledgement delivery.

### PAC-OD-003 — Common release convention or one common continuation transaction?

| Option | AC | ER | DR | XO | SC | Bot | FR | TE | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. One generic ship/squadron continuation transaction or framework | Low | Low | Medium | Medium | Medium | Medium | Low | Low | Eliminated |
| B. One narrow authoritative release convention, selecting distinct existing transactions/derived availability by canonical context | High | High | High | High | High | High | High | High | Recommended |
| C. Independent scene-specific release paths for each context | Low | Medium | Low | Low | Low | Medium | Low | Low | Eliminated |

**Recommendation:** B.

**Decision requested:** Treat the shared concept as only “satisfied inspection
permits one context-validated release.” It has no generic continuation object,
queue, descriptor, or state machine. The concrete command remains the
existing context command, and a no-mutation branch remains a derived route.

**Decisive trade-off:** This shares the safety invariant without falsely
equating normal ship, anti-squadron, Squadron Phase, and commanded-squadron
rules. It is the smallest commonality that supports multiple attacks and later
rule branches without spreading scene authority.

### PAC-OD-004 — Which canonical objects own the progress facts?

| Option | AC | ER | DR | XO | SC | Bot | FR | TE | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. Put post-attack progress or a continuation descriptor in pending inspection / `GameState` | Low | Low | Medium | Medium | Low | Medium | Low | Low | Eliminated |
| B. Preserve `ShipInstance` and `SquadronInstance` ownership; `GameState` aggregates/serializes and owns only the inspection | High | High | High | High | High | High | High | High | Recommended |
| C. Retain `AttackExecutor`, modal, or `InteractionFlow` as owner of progress | Low | High | Low | Low | Low | Low | Low | Low | Eliminated |

**Recommendation:** B.

**Decision requested:** Confirm these facts remain exactly where accepted
architecture already places them:

- `ShipInstance`: attack-step activity, normal count, hull-zone use,
  anti-squadron iteration/history, activation identity, and relevant
  Squadron-command/Maneuver dispositions.
- `SquadronInstance`: activation identity/context and action/attack history.
- `GameState`: aggregate validation, phase/squadron-phase progress, command
  ordering context, and the purpose-specific ADR-007 inspection only.
- `CurrentAttackState`: no post-completion progress after terminal retirement.

**Decisive trade-off:** Existing entity owners require contextual lookup at
release, but that is deterministic and avoids a writable duplicate. Storing a
descriptor or owner-local facts in inspection would conflict with ADR-007 and
make a historical result state a second activation owner.

### PAC-OD-005 — What is the authoritative ADR-007 release seam?

| Option | AC | ER | DR | XO | SC | Bot | FR | TE | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. `AttackExecutor`/modal callbacks submit or infer continuation after local acknowledgement | Low | High | Low | Low | Low | Low | Low | Low | Eliminated |
| B. The existing `CommandProcessor` post-success deferred-follow-up seam is the sole live-authority release seam; it selects only the existing applicable transaction from canonical state and inspection identity | High | Medium | High | High | High | High | High | High | Recommended |
| C. Save/load, reconnect, replay, or passive mirrors independently synthesize release commands | Low | Medium | Low | Low | Medium | Medium | Low | Low | Eliminated |

**Recommendation:** B.

**Decision requested:** Confirm the existing command-processing seam, not a
scene/controller, owns evaluation of satisfied inspection for live authority.
It must be conditional on canonical state and the inspection identity; passive
Network mirrors do not synthesize it; replay replays its recorded command in
history rather than producing another live follow-up; and reconstruction only
re-evaluates eligibility through the same authoritative release policy.

**Decisive trade-off:** This reuses the repository's existing live-only versus
mirror/replay separation. It requires a carefully bounded extension of an
existing command-processing seam, but avoids a second coordinator, local race,
or save/load/reconnect exception. It is a prerequisite decision, not detailed
API or implementation design.

### PAC-OD-006 — Future-proofing horizon

| Option | AC | ER | DR | XO | SC | Bot | FR | TE | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. Generalize now for arbitrary effects, bots, and all future continuation kinds | Low | Low | Medium | Medium | High | Medium | Low | Low | Eliminated |
| B. Cover current supported standard ship/squadron contexts, including multiple normal and anti-squadron attacks; require an explicit mapping decision for a new semantic context | High | High | High | High | High | High | High | High | Recommended |
| C. Cover only the UX-005 anti-squadron path | Low | Medium | Low | Medium | Low | Medium | Low | Low | Eliminated |

**Recommendation:** B.

**Decision requested:** Set the horizon to the currently supported standard
ship and squadron attack contexts listed in section 3. This includes future
human/automated principal combinations structurally supported by MATCH-001,
but does not define bot decisions or acknowledgements. A new reaction,
rule-granted attack, or materially different continuation must first prove an
existing entity owner and semantic transaction; otherwise it returns for an
Owner decision.

**Decisive trade-off:** This is broad enough to avoid a second migration for
ordinary multiple and anti-squadron attacks, while avoiding speculative generic
infrastructure. MATCH-001's evidence favors this explicit seam inventory over
premature abstraction because it reduces late discovery of fixture and path
differences without inventing numeric savings.

## 6. Provisional Decision Summary for Owner Review

If the Owner accepts all recommendations, the resulting narrow direction is:

1. `CompleteAttackCommand` completes and retires the individual attack; it
   does not become the owner of enclosing activation progression.
2. The ADR-007 inspection separates terminal completion from a later release.
3. `ShipInstance` and `SquadronInstance` retain their accepted progress facts.
4. Existing branch transactions own any subsequent gameplay mutation:
   `AdvanceActivationStepCommand`, `SkipAttackCommand`'s existing
   anti-squadron close branch, and `CompleteSquadronActivationCommand`, as
   applicable. A branch with only another legal choice is derived, not stored.
5. The existing command-processing follow-up seam is the only proposed
   live-authority release evaluator; it does not become a generic framework or
   a new gameplay-state owner.
6. Passive mirrors and replay do not synthesize extra release; save/load and
   reconnect reconstruct canonical state and use the same release policy.

## 7. Conflicts, Preconditions, and Non-Goals

### No authority conflict found

Accepted architecture does not determine the concrete Gate B mapping because
ADR-007 expressly makes its absence an architecture stop. It does determine
the boundaries that rule out Options PAC-OD-001A, PAC-OD-001B,
PAC-OD-002A/C, PAC-OD-003A/C, PAC-OD-004A/C, and PAC-OD-005A/C.

### Preconditions before UX-005 implementation may proceed

- Project Owner selects this narrow continuation-ownership direction.
- A subsequent UX-005 implementation workbook proves each branch mapping,
  including the no-mutation derived-availability branches, against current
  code and artifact compatibility owners.
- The workbook proves one live-authority release, no passive-mirror synthesis,
  replay command-history-only behavior, and atomic exact-once inspection
  consumption for every applicable context.
- If a context cannot use an existing semantic transaction without a new
  continuation owner, ADR-007 requires another architecture stop rather than
  local invention.

### Explicit non-goals

This workbook does not design UX-005 acknowledgement presentation, inspection
state shape, bot behavior, a generic controller/continuation architecture,
APIs, file changes, implementation sequence, or tests. It does not amend
ADR-007, ADR-006, CON-001, or CON-006.

## 8. Project Owner Decisions

Decision date: 2026-08-18
Decision owner: Project Owner

The Project Owner reviewed PAC-OD-001 through PAC-OD-006, including their
architectural consequences, expected implementation cost, scalability,
determinism, implementation risk, and future compatibility.

The recommended direction is accepted as recorded below.

These decisions select the architectural direction required to resolve the
ADR-007 Entry Gate B prerequisite. They do not authorize UX-005 implementation
and do not replace the subsequent ADR, verification, or implementation-planning
steps required by repository workflow.

### PAC-OD-001 — Semantic post-attack progression ownership

**Decision: Option C accepted.**

The existing applicable activation/action transition transaction owns each
semantic post-attack progression branch. `CompleteAttackCommand` remains the
terminal transaction for the individual attack and does not become the owner
of enclosing activation progression.

Where post-attack state permits another legal choice without requiring an
authoritative gameplay mutation, that availability is derived from canonical
state rather than stored as a continuation fact.

**Rationale**

This preserves the existing semantic ownership boundaries and avoids making
`CompleteAttackCommand` understand ship activation, anti-squadron iteration,
Squadron Phase, commanded-squadron, and future progression semantics.

It has the best expected balance of implementation cost, architectural
correctness, replay/Network determinism, scalability, and first-time-right
implementation reliability. It also avoids introducing another continuation
abstraction or semantic owner.

**Risk controls**

- Do not extend `CompleteAttackCommand` into a universal continuation owner.
- Do not introduce a generic post-attack continuation command merely to make
  different branches look uniform.
- Every mutating branch must identify an already-applicable authoritative
  semantic transaction.
- A branch that requires no mutation must remain derived rather than create
  new durable continuation state.
- If a future context has no valid existing owner/transaction, stop for an
  architecture decision rather than extending this decision by analogy.


### PAC-OD-002 — Terminal completion and continuation boundary

**Decision: Option B accepted.**

Terminal attack completion and subsequent gameplay continuation are separate
semantic boundaries.

`CompleteAttackCommand` retires the individual attack and establishes the
completed-result inspection required by ADR-007. After acknowledgement
satisfaction, the applicable existing branch transaction may consume that
inspection atomically with its gameplay mutation.

`AcknowledgeAttackResultCommand` changes acknowledgement/satisfaction state
only. It does not perform the subsequent gameplay transition.

**Rationale**

The separation preserves the completed-result inspection barrier required by
ADR-007 while giving the eventual continuation transaction a clear exact-once
boundary.

This is preferable to reducing command count by combining unrelated lifecycle
transitions. The additional boundary is justified by stronger replay,
save/load, reconnect, Network, and future automated-controller behavior.

**Risk controls**

- Acknowledgement must never directly become gameplay progression.
- Completion must not progress beyond the inspection barrier.
- Consumption and the corresponding mutating continuation must be atomic.
- A satisfied-but-unconsumed inspection must remain reconstructable.
- Replay must not synthesize an additional continuation after replaying the
  recorded continuation transaction.
- Network acknowledgement ordering must not determine gameplay semantics
  independently of canonical inspection state.


### PAC-OD-003 — Shared release convention versus generic continuation

**Decision: Option B accepted.**

All supported contexts share one narrow release convention:

> A satisfied completed-attack inspection permits exactly one
> context-validated release.

This shared convention does not imply a shared continuation transaction,
continuation object, queue, descriptor, state machine, or framework.

The concrete semantic transaction remains specific to the canonical gameplay
context.

**Rationale**

Normal ship attacks, ship anti-squadron attacks, Squadron Phase attacks, and
ship-commanded squadron attacks share an exact-once release requirement but
do not share one canonical progression model.

Sharing the safety invariant while preserving context-specific transactions
provides most of the scalability benefit of a common architecture without the
cost and risk of premature generic infrastructure.

**Risk controls**

- Standardize the release invariant, not the underlying gameplay semantics.
- Do not create a generic continuation descriptor in inspection state.
- Do not create a continuation queue or generic continuation FSM.
- Do not force different gameplay contexts through one transaction solely for
  architectural symmetry.
- New contexts must explicitly establish their canonical owner and semantic
  transaction before using this release convention.


### PAC-OD-004 — Canonical ownership of progress facts

**Decision: Option B accepted.**

Existing canonical ownership is preserved.

- `ShipInstance` retains ship attack-step, activation, normal-attack,
  hull-zone, anti-squadron iteration/history, and relevant Squadron-command /
  Maneuver progress assigned to it by accepted architecture.
- `SquadronInstance` retains squadron activation/context and action/attack
  progress assigned to it by accepted architecture.
- `GameState` retains aggregate validation/state and owns the purpose-specific
  ADR-007 completed-attack inspection.
- `CurrentAttackState` does not retain post-completion progression after
  terminal retirement.

**Rationale**

These objects already contain the authoritative facts from which the correct
post-attack continuation can be derived. Duplicating those facts in inspection
state would create competing ownership and synchronization risk.

Preserving existing ownership minimizes implementation migration while also
providing the strongest long-term model for replay, save/load, Network,
automated controllers, and future attack rules.

**Risk controls**

- The completed-result inspection must not become an activation-progress
  owner.
- Do not copy a continuation descriptor or duplicate entity progress into the
  inspection.
- Scene/UI/controller state must not regain semantic ownership.
- Release decisions must be derived from canonical entity/GameState facts.
- `CurrentAttackState` must remain terminally retired after completion.


### PAC-OD-005 — Authoritative release seam

**Decision: Option B accepted.**

The existing `CommandProcessor` post-success deferred-follow-up seam is the
selected sole live-authority release evaluation seam.

It may determine from canonical state and the completed-attack inspection
whether an already-defined semantic continuation transaction is eligible for
release.

It does not become a new gameplay-state owner or generic continuation
orchestrator.

Passive Network mirrors do not synthesize release transactions. Replay uses
recorded accepted command history rather than generating another live
follow-up. Reconstruction must preserve canonical state and use the same
authoritative release policy rather than establish an independent release
path.

**Rationale**

The repository already has a command-processing seam that distinguishes live
authoritative follow-up from replay and passive mirroring. Extending that seam
narrowly is preferable to introducing another coordinator or retaining
scene-owned continuation decisions.

This decision therefore reuses existing infrastructure while establishing one
authoritative release point suitable for exact-once behavior.

**Risk controls**

This decision must be implemented particularly narrowly.

- `CommandProcessor` may evaluate release eligibility; it must not own the
  underlying continuation semantics.
- It must select only an already-defined applicable semantic transaction.
- Do not introduce generic continuation state into `CommandProcessor`.
- Do not turn the follow-up mechanism into a general gameplay orchestration
  framework.
- Scene/UI/modal callbacks must not independently submit the same semantic
  continuation.
- Passive Network mirrors must never synthesize it.
- Replay must not synthesize it when the accepted transaction already exists
  in recorded history.
- Save/load and reconnect must not introduce alternative release authorities.
- Exact-once behavior must be demonstrated before ADR-007 Entry Gate B can
  pass.


### PAC-OD-006 — Future-proofing horizon

**Decision: Option B accepted.**

The architecture must cover all currently supported standard ship and squadron
attack contexts, including:

- normal ship attacks;
- multiple normal ship attacks;
- ship anti-squadron attacks and target iteration;
- Squadron Phase squadron attacks;
- ship-commanded squadron attacks;
- HUMAN/AUTOMATED and AUTOMATED/AUTOMATED principal structures where these
  existing gameplay semantics are used.

This decision does not define bot planning, bot acknowledgement policy, or a
generic future continuation architecture.

A new reaction, rule-granted attack, or materially different continuation
context must prove that the existing ownership and transaction model applies.
If it does not, the architecture must stop for a new decision.

**Rationale**

Solving only the immediate UX-005 path would reduce short-term implementation
effort but would create substantial migration risk for ordinary existing
attack variants and future automated play.

Conversely, generalizing now for arbitrary future effects would introduce
speculative infrastructure and unnecessary implementation and review cost.

The selected horizon covers known semantic variation while deliberately
avoiding premature abstraction.

**Risk controls**

- Cover known standard contexts completely rather than implementing only the
  currently visible UX path.
- Do not use bot compatibility as justification for a generic controller or
  continuation framework.
- Do not generalize from current attacks to arbitrary future reaction/effect
  systems without evidence.
- A materially new semantic context requires explicit mapping to an existing
  canonical owner and transaction.
- Failure to establish that mapping is an architecture stop, not permission
  for local invention.


## 9. Accepted Direction

Taken together, PAC-OD-001 through PAC-OD-006 establish the following
direction:

1. `CompleteAttackCommand` owns terminal completion of the individual attack,
   not enclosing activation progression.
2. Completed-result inspection forms a real semantic barrier between attack
   completion and subsequent gameplay progression.
3. Existing `ShipInstance` and `SquadronInstance` progress ownership remains
   authoritative.
4. Existing context-specific semantic transactions perform subsequent
   gameplay mutations.
5. Non-mutating next opportunities are derived from canonical state rather
   than stored as continuation state.
6. The existing `CommandProcessor` deferred-follow-up seam is the sole
   live-authority evaluator for satisfied-inspection release.
7. The shared abstraction is the exact-once release invariant only; no generic
   continuation object, queue, command, FSM, or framework is authorized.
8. Replay and passive Network mirrors do not synthesize additional release
   transactions.
9. The design must cover all currently supported standard ship and squadron
   attack contexts, including multiple and anti-squadron attacks.
10. New materially different semantic contexts must prove compatibility with
    this ownership model or return for an architecture decision.

These decisions resolve the Project Owner direction requested by this workbook.
They do not by themselves pass ADR-007 Entry Gate B. The required authoritative
and replayable transaction mapping and exact-once release proof must still be
established through the subsequent architecture artifact and targeted
verification.

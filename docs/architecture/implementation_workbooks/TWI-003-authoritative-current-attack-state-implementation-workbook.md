# TWI-003: Authoritative CurrentAttackState Implementation Workbook

Status: Accepted historical implementation record — production cutover present;
historical closure evidence incomplete

Purpose: Historical Implementation Workbook
Accepted by: Project Owner
Accepted date: 2026-08-03
Reconciled date: 2026-09-10

TWI-003 records the historical authoritative attack-declaration migration. Its
behavior-inert substrate and semantic cutover are present in the current
production lineage. This reconciliation does not claim that the original final
baseline renewal and Owner manual acceptance were completed: repository
evidence for those closure activities was not found.

No slice, gate, compatibility number, or Maneuver-adjacent instruction in this
workbook is a current implementation instruction. The declaration architecture
remains authoritative where later accepted authority has not superseded it.
[BUG-043](BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md)
alone owns the current Maneuver execution-record, commitment, consequence,
completion, recovery, and compatibility cutover.

Source: MA-ATTACK-002 -- Post-Stabilization CON-006 Compliance Assessment

Implementation boundary: supported attack declaration from an authoritative
declaration opportunity through one accepted `BeginAttackCommand` or one
accepted no-active declaration `SkipAttackCommand`

## 1. Authority And Workbook Role

TWI-003 is the implementation counterpart to
[MA-ATTACK-002](../migration_assessments/MA-ATTACK-002-post-stabilization-con-006-compliance.md).
It translated that accepted repository evidence into the deterministic
implementation specification used for the historical cutover. It does not
reassess the repository, create architecture, or authorize a new implementation
run now.

The binding authorities are:

- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
  for one `GameState`-owned `CurrentAttackState`, replayable semantic mutation,
  and one-way Model C-S projection;
- [ADR-003](../adr/ADR-003-rule-and-validation-surfaces.md) and
  [CON-003](../contracts/CON-003-rule-capability-contract.md) for rule,
  resolver, applicability, and validation responsibilities;
- [ADR-004](../adr/ADR-004-upgrade-runtime-ownership.md) and
  [CON-004](../contracts/CON-004-upgrade-runtime-contract.md) for existing
  runtime-upgrade ownership;
- [ADR-005](../adr/ADR-005-timing-window-ownership-and-continuation.md) and
  [CON-005](../contracts/CON-005-timing-window-implementation-contract.md) for
  timing-window lifecycle and continuation ownership;
- [ADR-006](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md)
  for the `ShipInstance`-owned declaration-adjacent ship-activation identity,
  Squadron-command and Maneuver opportunity dispositions, committed
  Squadron-command activation count, active Maneuver execution record, and
  normal/exceptional terminal invariants;
- [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md),
  the accepted
  [Ship Activation interaction requirements](../../requirements/gameplay_interactions/ship_activation_interaction.md),
  the accepted
  [Ship Activation Owner decisions](../../requirements/gameplay_interactions/ship_activation_interaction_owner_decisions.md),
  and the accepted
  [Ship Maneuver interaction requirements](../../requirements/gameplay_interactions/ship_maneuver_interaction.md)
  for decision-equivalent recovery and the refined Maneuver commitment,
  consequence, completion, Network, and reconstruction semantics;
- [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
  for current-attack membership, atomicity, serialization, reconstruction,
  replay, networking, and projection;
- [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md) as
  the binding declaration-lifecycle contract;
- [TEST-003](../tests/TEST-003-interactive-rule-timing-window-verification.md)
  for applicable timing-window evidence categories; and
- MA-ATTACK-002 for the accepted implementation baseline, remaining outcomes,
  bug disposition, and verification gaps.

[TWI-001](TWI-001-timing-window-state-implementation-workbook.md) and
[TWI-002](TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md)
provide predecessor implementation and documentation conventions. They do not
override the authorities above. TWI-003 historically executed after the
TWI-002 production-activation compatibility checkpoint described in Section 8.
The reconciled
[BUG-043 workbook](BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md)
is the active bounded implementation specification for current Maneuver
changes. It is not a dependency of an unexecuted TWI-003 slice and TWI-003 does
not allocate or duplicate any part of that cutover.

The completed TWI-003 Architecture Audit Report supplied for this refinement is
review evidence. Its BLOCKING, HIGH, and MEDIUM findings are resolved by this
workbook as summarized in Section 16.

This document remains:

- a historical implementation workbook and audit trail;
- subordinate to accepted ADRs and Contracts;
- accepted by the Project Owner as recorded in the authoritative header; and
- the record of the declaration migration that produced the current lineage.

It is not:

- an ADR, Contract, TEST document, Migration Assessment, or CAP;
- an authority for changing accepted ownership;
- a general ship-activation finite-state-machine specification;
- a post-Begin attack-resolution specification; or
- the historical assessment named MA-ATTACK-001.

If this workbook and an accepted authority conflict, the accepted authority
wins and Section 14 applies.

### 1.1 2026-09-10 Maneuver Reconciliation

This reconciliation preserves TWI-003's accepted attack-declaration scope. It
does not turn TWI-003 into the implementation workbook for the complete Ship
Maneuver interaction. Embedded instructions have the following disposition:

| Previous instruction | Disposition | Reconciled instruction |
| --- | --- | --- |
| Attack declaration, Preview/Begin parity, no-active Skip, BUG-005, and squadron action cutover | **Implemented historical allocation; still valid where not superseded** | Current production contains the owner fields and semantic integration introduced by commits `440b670` and `7cfa47b`; accepted declaration authority continues to govern. |
| ADR-006 comprised four activation-local facts | **Historically implemented, then superseded for current Maneuver work** | The four declaration-adjacent facts remain valid production history. Amended ADR-006 now adds at most one matching active Maneuver execution record, whose implementation belongs only to BUG-043. |
| Maneuver execution directly performed `OPEN -> CONSUMED` | **Superseded** | Commitment creates the active execution and leaves Maneuver `OPEN`; only exact-once completion after all mandatory consequences consumes it and retires the record. |
| TWI-003 should add/serialize or implement the current Maneuver execution/consequence flow | **Obsolete** | TWI-003 owns none of that work. BUG-043 owns the current record, serialization, interaction, overlap, Navigate, consequence, recovery, and compatibility cutover. |
| Transient UI/controller state is non-authoritative and reconstruction derives from canonical state | **Still valid; refined by later authority** | Current Maneuver recovery must distinguish uncommitted `OPEN`, committed-but-`OPEN`, and completed `CONSUMED`, including purpose-specific nested consequence state and viewer-authorized passive Network representation. BUG-043 supplies the executable allocation. |

Where a TWI-003 step touches Maneuver only as an adjacent activation boundary,
the accepted Maneuver requirements govern. No lifecycle enum, generic FSM,
stack, queue, callback owner, or general continuation mechanism is authorized.

### 1.2 Current Repository Posture

Read Sections 2 through 16 as the retained specification and evidence plan for
the 2026-08 migration, not as instructions to rerun it:

| Evidence | Current posture |
| --- | --- |
| Commit `440b670` | TWI-003 behavior-inert `GameState`, `ShipInstance`, and `SquadronInstance` substrate was implemented. |
| Commit `7cfa47b` | TWI-003 declaration/squadron semantic cutover, save 3, and replay 5 were implemented. |
| Current production | Declaration owners, commands, validation, serialization, reconstruction, Network projection/application, and focused tests retain that lineage. Current versions are save 6, replay 9, and Network protocol 6. |
| Historical closure | The original workbook still recorded baseline-renewal and Owner manual verification work after the semantic checkpoint. No repository evidence reviewed here proves those activities complete, so they remain historical closure evidence debt rather than production implementation work. |
| Current Maneuver work | Later accepted authority supersedes conflicting historical Maneuver assumptions. BUG-043 alone owns the current cutover. |

Accordingly, imperative language below describes the accepted historical
cutover at its then-current baseline. It SHALL NOT be used to revert current
versions, recreate dormant slices, or select current Maneuver architecture.

## 2. Scope, Preserved Baseline, And Exclusions

### 2.1 Included Outcome

The implementation SHALL complete the MA-ATTACK-002 declaration migration for:

- ship attacks during the Ship Activation Attack Step;
- non-Rogue Squadron Phase attacks;
- Rogue Squadron Phase attacks;
- attacks by squadrons activated through a ship's Squadron command;
- ship-to-ship, ship-to-squadron, squadron-to-ship, and
  squadron-to-squadron declaration pairings;
- the authoritative enclosing declaration opportunity and controller in each
  supported context;
- complete `BeginAttackCommand` validation and atomic adjacent-owner mutation;
- the complete no-active declaration Skip effect matrix;
- authoritative squadron action progress and ship Squadron-command use count;
- Preview/Begin behavioral parity;
- BUG-005 distance-1 eligibility for outgoing squadron attacks;
- derived routing and projection after accepted Begin or Skip;
- automatic no-target handling through an accepted Skip result;
- serialization, save/load, replay, networking, reconnect, and projection of
  the accepted Begin/Skip result;
- cutover compatibility and rollback evidence; and
- the complete CON-006 and applicable TEST-003 verification matrix.

The semantic boundary begins only when canonical state already establishes an
available declaration opportunity and controller, `CurrentAttackState` is
inactive, and no target candidate exists. It ends at exactly one of:

- accepted Begin with one complete valid active `CurrentAttackState` and every
  applicable adjacent owner committed atomically; or
- accepted no-active declaration Skip with the opportunity and required
  enclosing progress committed atomically, `CurrentAttackState` inactive, and
  the next route derivable from the resulting authoritative state.

### 2.2 Preserved Stabilization Baseline

The following accepted MA-ATTACK-002 outcomes are regression baselines, not
work to reimplement:

- `GameState` owns one canonical `CurrentAttackState`;
- `TargetSelector` owns one transient declaration candidate;
- legal selection creates Preview without submitting a semantic command;
- Preview replacement remains transient;
- deselection submits no command and clears no valid attacker context;
- an illegal selection preserves an existing legal Preview;
- declaration Confirm is distinct from later attack-dice confirmation;
- one Confirm submits one Begin for the final complete candidate;
- `Begin -> Skip(flow_replaced) -> Begin` is absent from replacement history;
- only one declaration command may be pending;
- rejected local or network Begin/Skip restores or preserves interaction when
  the authoritative opportunity still exists;
- `ShipInstance.attack_step_active`, `committed_attack_count`,
  `used_attack_hull_zones`, `anti_squadron_attack_zone`, and
  `anti_squadron_target_history` remain authoritative ship activation-local
  progress;
- standard ship Begin fails closed without `attack_step_active` and commits
  ship progress atomically with `CurrentAttackState`;
- BUG-002 Step 6 and second-normal-attack continuation remain passing;
- active and inactive ship continuation reconstruction remains passing; and
- accepted replay and host/client stabilization behavior remains passing.

Slice 2 may adapt consumers of these facts to the completed declaration model,
but SHALL NOT replace their owners or alter their accepted semantics.

### 2.3 Explicit Exclusions

The implementation SHALL NOT change:

- active attack completion, cancellation, cleanup, or replacement;
- any behavior after successful Begin except one-way consumption of the
  accepted Begin result needed to enter the existing attack lifecycle;
- attack resolution, dice, Concentrate Fire, Attack Modify, Accuracy, defense,
  critical, damage, Counter, or target-iteration behavior;
- BUG-002 Step 6 or second-normal-attack implementation;
- BUG-003 post-commit Skip behavior;
- BUG-004 Tarkin projection behavior;
- attack simulator or analysis-only authorization;
- timing-window lifecycle, orchestration, opportunity, or continuation
  architecture;
- runtime-rule or runtime-upgrade ownership;
- general phase, turn, ship activation, or squadron activation architecture;
- general replay, networking, transport, or save/load cleanup;
- the network bootstrap defect unless its separate investigation proves a
  direct declaration-state dependency;
- unrelated UI layout, styling, animation, or presentation cleanup;
- baseline fixture values before semantic traces and state-shape changes are
  accepted; or
- any ADR, Contract, TEST document, CAP, Migration Assessment, bug record,
  TWI-001, or TWI-002.

`CompleteAttackCommand`, attack-resolution callbacks, active
`SkipAttackCommand` branches, and post-completion continuation are neighboring
implementation context only. They SHALL NOT be changed to satisfy CON-006.

`CompleteSquadronActivationCommand` is an adjacent one-way consumer at the
enclosing-action boundary. It may validate and consume canonical squadron
action history when invoked through its already-existing closure path after
movement or an active attack. Its invocation and ordering after an active
attack SHALL remain unchanged. Declaration Skip SHALL commit its complete
context row inside `SkipAttackCommand`; it SHALL NOT synthesize a later
`CompleteSquadronActivationCommand`. The completion command SHALL NOT complete
an active attack, decide attack resolution, change post-Begin ordering, or
create continuation.

### 2.4 Bug Disposition

The workbook preserves MA-ATTACK-002 exactly:

| Record | Disposition in TWI-003 |
| --- | --- |
| BUG-005 | Mandatory declaration-compliance scope. Correct outgoing squadron-to-ship and squadron-to-squadron eligibility to distance 1. |
| BUG-002 | Regression evidence only for Step 6, the second normal attack, save/load, replay, reconnect, and host/client progression. |
| BUG-003 | Excluded because it concerns active/post-Begin Skip. |
| BUG-004 | Excluded as unrelated Tarkin projection. |
| BUG-001 / NOTE-001 | Final production network save/load verification prerequisite only, unless its independent investigation proves a direct declaration-state dependency. |

MA-ATTACK-001 remains the historical baseline and is not modified or
superseded by implementation instructions in this workbook.

## 3. Fixed Architecture And Ownership

### 3.1 Authoritative Owners

The implementation SHALL preserve these owners:

| Fact | Accepted owner or responsibility surface | Permitted TWI-003 action |
| --- | --- | --- |
| Current phase, round, controller, turn, and phase progress | Canonical serialized `GameState` phase/turn state | Add only irreducible declaration-adjacent progress to the existing owner; do not create a phase object. |
| Ship declaration opportunity and attack progress | Existing serialized `ShipInstance` activation-local attack state together with the ADR-006 activation boundary on that same `ShipInstance` | Preserve existing attack fields; bind Begin/Skip to the matching stable ship-activation identity and purpose-specific dispositions. |
| Squadron activation and action progress | Existing serialized `SquadronInstance` and accepted enclosing activation state | Add the minimum irreducible action history to `SquadronInstance`; derive availability. |
| Declaration-adjacent ship-activation boundary | Active ship's `ShipInstance`, as the sole writable ADR-006 owner | **Historical TWI-003 allocation:** the stable identity, two opportunity dispositions, and committed Squadron-command count were introduced by the completed slices. **Current Maneuver allocation:** BUG-043 alone adds the optional active execution record and its integration. |
| Cross-fleet active ship-activation uniqueness | Canonical `GameState` aggregate over its fleets | Validate zero or one active ship identity at stable semantic command boundaries; do not make `GameState` a second writable owner. |
| Ship Squadron-command use progress | Same ADR-006 `ShipInstance` activation-local boundary | Store committed use count scoped to the active identity; derive capacity and remaining activations from current authoritative resources and rules. |
| Current attack | `GameState.current_attack_state` | Begin installs one complete state; no enclosing progress is copied into it. |
| Attacker/defender entity facts | Existing `ShipInstance` or `SquadronInstance` | Reference by stable owner/index/kind; do not duplicate entity facts. |
| Hull-zone identity/static facts | Existing ship runtime/static surfaces | Store only accepted stable current-attack references. |
| Geometry, arc, range, LOS, obstruction, pool | Existing deterministic mechanic resolver surfaces | Derive before Begin; commit only CON-001 member facts at Begin. |
| Rule-specific legality and mutable rule state | ADR-003/CON-003 rule owners | Query accepted surfaces; mutate only if an accepted rule explicitly requires it. |
| Runtime upgrade state | ADR-004/CON-004 runtime-upgrade instance | No ownership change. |
| Timing lifecycle | `GameState.timing_window_state` and Timing Window Orchestrator | Ordinary declaration Preview/Begin/Skip does not synthesize or clean it. |
| Command order and accepted decision | `CommandProcessor` and existing replayable command infrastructure | Accepted Begin/Skip records once; mirrors and replay preserve order. |
| Transient candidate and pending state | `TargetSelector`, coordinated by `AttackExecutor` and presentation | Remain local, transient, non-serialized, and non-authoritative. |
| Route and viewer payload | `InteractionFlow`, `FlowSpec`, `UIProjector`, `StateFilter` | Derive after canonical mutation; never authorize gameplay. |

CON-006-AUTH-003 is mandatory. If an implementation baseline has no accepted
authoritative owner for a durable fact required by the table, and the fact
cannot be derived, implementation SHALL stop for Project Owner guidance. It
SHALL NOT add a field merely because a scene or `InteractionFlow` currently
contains a convenient value.

ADR-006 was the accepted authorization for TWI-003's four declaration-adjacent
owner-local concepts on `ShipInstance`. The amended fifth concept, the optional
active Maneuver execution record, post-dates that cutover and belongs to
BUG-043. Its present absence is not unfinished TWI-003 work.

### 3.2 Non-Owners

The following remain non-authoritative:

- `AttackExecutor` and all attack scene state;
- `ShipActivationState`, `ShipActivationController`, and
  `SquadronPhaseController`;
- `GameBoard`, `GameManager`, `ModalRouter`, panels, controllers, and modals;
- `SquadronCommandResolver` counters and cached capacity;
- `TargetSelector` candidate/Preview records;
- `InteractionFlow`, `FlowSpec`, and payloads;
- `UIProjector` and `StateFilter` output;
- overlays, labels, affordances, animations, and scene lifecycle;
- derived targeting lists and rejection presentation; and
- save/load or reconnect reconstruction helpers.

They may query, project, route, or coordinate accepted results. They SHALL NOT
create, consume, reset, repair, or infer a declaration opportunity.

The ADR-006 owner and transitions are controller-independent: the same
canonical boundary applies to a local human, remote human, or future automated
controller. This workbook remains language-independent. Its explicit fields
and semantic seams may be migration-friendly, but it requires neither C# nor a
C# migration.

### 3.3 Prohibited Shapes

The implementation SHALL NOT introduce:

- a declaration-state object or serialized declaration-opportunity record;
- a general serialized ship activation FSM or general predecessor policy;
- a generic Maneuver lifecycle enum, phase enum, stack, queue, callback, or
  continuation owner;
- `current_step` or another general activation-step state;
- `activation_step_id` or another stored copy of every ship activation step;
- a stored `squadron_step_active` duplicate;
- a serialized/frozen `squadron_command_capacity` snapshot;
- a second current-attack, target candidate, action-history, or command-budget
  owner;
- UI-owned or scene-owned gameplay progression;
- scene-to-model reverse synchronization;
- transient Preview, pending, modal, or route data in canonical state;
- a compatibility dual-write, feature flag, legacy execution mode, temporary
  bridge, or permanent migration adapter;
- a new timing-window, rule, upgrade, replay, network, or transport architecture;
- a command per internal UI/FSM edge; or
- fallback initialization inside Begin when the enclosing opportunity is
  absent.

This workbook specifies only declaration-adjacent facts already bound by
CON-006. It does not define the legal predecessor graph for Squadron, Repair,
Attack, Maneuver, or activation completion.

## 4. Required End-State Behavior

### 4.1 Declaration Lifecycle

For every supported context the production route SHALL be:

1. canonical state establishes one declaration opportunity and controller;
2. `CurrentAttackState` is inactive;
3. `TargetSelector` may create, replace, clear, or preserve one transient
   candidate using current authoritative facts;
4. Preview submits no command and writes no canonical owner;
5. Confirm constructs stable intent from the current complete candidate and
   submits exactly one `BeginAttackCommand`;
6. Begin re-evaluates all gameplay legality and transaction preconditions;
7. accepted Begin atomically commits every participating accepted owner and
   one complete `CurrentAttackState`;
8. rejected Begin changes no authoritative owner and presentation either
   restores interaction or routes from changed authoritative state;
9. alternatively, Skip may be submitted with or without Preview;
10. accepted no-active Skip atomically consumes the declaration opportunity on
    existing enclosing owners while leaving `CurrentAttackState` inactive;
11. rejected Skip changes no authoritative owner; and
12. routing/projection responds only to the accepted authoritative result.

No pre-confirm replacement command exists. No route or modal teardown is a
semantic transition.

### 4.2 Preview And Begin Parity

Preview and Begin SHALL use equivalent gameplay semantics for identical
authoritative state and intent. Equivalent semantics means the same result for:

- attacker and defender identity/kind/ownership;
- current phase, controller, enclosing opportunity, and action availability;
- hull-zone validity and use history;
- firing arc;
- range or distance legality;
- LOS and obstruction;
- engagement, Escort, Heavy, and other keyword restrictions;
- friendly, self, and same-entity prohibition;
- already-targeted and attack-history restrictions;
- accepted rule blockers/modifiers/costs; and
- deterministic attack pool.

Begin SHALL re-evaluate legality immediately before mutation. It may also
reject for transaction-only conditions such as stale command sequence,
concurrency, or a newly active `CurrentAttackState`. Those rejections are not
Preview/Begin gameplay disagreement.

Ship Preview SHALL stop relying on a scene-only geometry outcome when Begin
uses reconstructed authoritative model facts. Both boundaries may use different
adapters only if tests prove behavioral equivalence for identical inputs and no
scene value authorizes Begin.

### 4.3 BUG-005 Mandatory Outcome

`TargetingListBuilder` SHALL preserve its accepted edge-to-edge measurements
and change only outgoing squadron eligibility classification:

- squadron-to-ship is legal only when the measured distance band is 1;
- squadron-to-squadron is legal only when the measured distance band is 1;
- the production source is `GameScale.get_distance_band(distance)`, backed by
  `GameScale.distance_bands_px`;
- `GameScale.get_range_band(distance)` and `range_close_px` remain distinct
  range-ruler semantics and SHALL NOT authorize an outgoing squadron attack;
- a target greater than distance 1 but still within close range is rejected;
- Preview and Begin consume the same corrected targeting result; and
- committed range-band facts required by `CurrentAttackState` remain governed
  by existing attack-entry semantics rather than redefining distance 1 as
  close range.

This is a shared resolver correction, not a UI, presentation, or
Preview/Begin-disagreement workaround.

### 4.4 Begin Atomic Outcome

Accepted Begin SHALL, after all validation and deterministic calculation:

1. allocate or derive the existing deterministic current-attack identity;
2. install one complete CON-001-valid `CurrentAttackState`;
3. consume the declaration opportunity exactly once on its existing owner;
4. mark ship hull-zone/attack history exactly once where the ship context
   requires it;
5. mark squadron attack use exactly once where a squadron is the attacker;
6. commit any applicable existing already-targeted or accepted rule-owner fact;
7. record the command exactly once; and
8. expose the result to one-way routing, projection, replay, and mirroring.

All involved owners SHALL be validated before mutation, snapshotted, mutated,
cross-validated, and restored together on failure. A partial adjacent-owner
write or partially initialized `CurrentAttackState` SHALL never be observable.

Begin SHALL fail closed when the enclosing declaration opportunity is absent.
It SHALL NOT call an initializer to create the missing opportunity, infer it
from `InteractionFlow`, repair progress, submit Skip, or fall back to scene
state.

Begin SHALL NOT roll dice or perform any post-Begin behavior.

### 4.5 No-Active Declaration Skip Outcome

All four CON-006 Skip rows SHALL be implemented by the existing
`SkipAttackCommand` type while active/post-Begin branches remain unchanged:

| Context | Required authoritative result | Required derived route |
| --- | --- | --- |
| Ship Activation Attack Step | Consume the current ship declaration opportunity, preserve hull-zone and target history, leave `CurrentAttackState` inactive, and change the matching ADR-006 Maneuver disposition from `UNREACHED` to `OPEN`. | Ship Activation Maneuver route derived from the owning `ShipInstance` boundary. |
| Non-Rogue Squadron Phase | Record attack decline, complete the squadron activation without a target, update the existing phase turn/count owners, and leave `CurrentAttackState` inactive. | Next squadron selection, handoff, or phase transition. |
| Rogue Squadron Phase | Record attack decline, preserve independently available movement, and complete only when no action remains. | Action choice when movement remains; otherwise normal completion route. |
| Ship-phase Squadron command | Record attack decline, preserve independently available movement, preserve/advance authoritative command use progress, and leave `CurrentAttackState` inactive. | Movement, next commanded squadron, or existing Repair boundary. |

Every row SHALL work with and without Preview. Skip SHALL not create target,
hull-zone use, target history, current attack, timing lifecycle, active attack
cleanup, or rule mutation not explicitly assigned by an accepted rule.

Automatic no-target handling SHALL submit the same context-specific Skip and
wait for acceptance. Rejection leaves the opportunity and interaction
available; scene teardown SHALL not advance gameplay.

### 4.6 Post-Begin Boundary

The cutover may change only the one-way handoff from accepted Begin to existing
attack presentation. Existing downstream consumers may read the canonical
result instead of stale scene state. The cutover SHALL NOT change:

- when or how an individual attack completes;
- `CompleteAttackCommand` validation, mutation, retirement, or continuation;
- active Skip/cancellation/replacement behavior;
- Step 6 target iteration;
- second-normal-attack continuation;
- attack resolution ordering;
- attack submission after completion; or
- scene teardown after the active attack.

If satisfying a declaration criterion requires changing any item above,
Section 14 applies.

### 4.7 ADR-006 Ship-Activation Boundary Semantics — Historical Integration

This section records the boundary rules against which the historical
declaration cutover must continue to be interpreted. TWI-003 implemented the
declaration-adjacent identity, dispositions, and committed count. Later
Maneuver refinements below are superseding constraints, not unperformed
TWI-003 implementation allocations:

- the stable ship-activation identity is assigned by the accepted semantic
  ship-activation entry transition and remains unchanged until a normal or
  exceptional terminal transition clears the boundary;
- the Squadron-command opportunity follows
  `UNREACHED -> OPEN -> CONSUMED`, and an accepted semantic transition MAY use
  `UNREACHED -> CONSUMED` only when the opportunity is legitimately
  unavailable, passed, or otherwise canonically not exercised under the
  applicable rules;
- for a surviving normal activation, Maneuver follows
  `UNREACHED -> OPEN -> CONSUMED`; `OPEN` without an active execution record
  means transient/uncommitted exploration, `OPEN` with the matching record
  means one committed Maneuver whose mandatory consequences remain in
  resolution, and `CONSUMED` requires no active record;
- commitment atomically derives and consumes required Navigate resources,
  applies the committed speed and course, creates the matching active execution
  record, and leaves Maneuver `OPEN`; only final completion after all
  still-applicable mandatory consequences performs `OPEN -> CONSUMED` and
  retires the record;
- normal completion requires both opportunity dispositions to be `CONSUMED`
  before clearing the activation boundary; and
- an accepted exceptional terminal transition, including active-ship
  destruction, MAY clear the identity, both dispositions, committed count,
  active execution, and invalidated nested consequence state without changing
  Maneuver to `CONSUMED` merely to terminate the activation.

These are two purpose-specific opportunity dispositions, not a generic ship
step, predecessor graph, `current_step`, or activation FSM. No new semantic
command type is authorized merely to maintain them.

## 5. Authoritative Field Classification

This is the complete CON-006-AUTH-001 classification for fields TWI-003 may
read, add, or retire. Each fact has exactly one category.

### 5.1 Existing Authoritative Stored Facts

| Field or state | Owner | TWI-003 treatment |
| --- | --- | --- |
| `current_round` | `GameState` | Read for activation identity/reset validation; unchanged. |
| `current_phase` | `GameState` | Read for applicability and context; existing phase commands remain owner. |
| `initiative_player` | `GameState` | Read when Squadron Phase controller state initializes; unchanged. |
| `current_attack_state` | `GameState` | Preserve sole current-attack owner; Begin installs atomically; Skip leaves inactive. |
| `timing_window_state` | `GameState` | Preserve sole timing lifecycle owner; ordinary declaration does not synthesize it. |
| `activated_this_round` | `ShipInstance` | Preserve round eligibility/completion fact. |
| `attack_step_active` | `ShipInstance` | Preserve existing authoritative Attack-step opportunity; initialize only at the accepted existing activation transition. |
| `committed_attack_count` | `ShipInstance` | Preserve existing Begin/continuation semantics. |
| `used_attack_hull_zones` | `ShipInstance` | Preserve existing Begin/continuation semantics. |
| `anti_squadron_attack_zone` | `ShipInstance` | Preserve BUG-002 neighboring continuation semantics. |
| `anti_squadron_target_history` | `ShipInstance` | Preserve BUG-002 neighboring continuation semantics. |
| `activated_this_round` | `SquadronInstance` | Preserve round-level completion; reset at existing round boundary. |
| entity position, ownership, status, hull zones, command dials/tokens | Existing entity owners | Read/reference only except existing commands retain their assigned mutations. |
| runtime rule state | Existing CON-003 owner | No ownership change. |
| runtime upgrade state | Existing CON-004 runtime instance | No ownership change. |

`attack_step_active` is not a general activation-step identifier. TWI-003 SHALL
not make it one or require it to encode Repair, Maneuver, Squadron, or Done.

### 5.2 New Irreducible Authoritative Stored Facts

These facts are permitted only on the listed existing accepted owners. Use the
listed field names unless Entry Gate evidence proves that an existing accepted
field already has exactly the same meaning; in that case reuse the existing
field and record the mapping rather than adding an alias.

| Required fact | Existing owner | Meaning and invariant |
| --- | --- | --- |
| `squadron_phase_controller_player` | `GameState` phase/turn state | Player currently entitled to activate a squadron; valid only in Squadron Phase; initialized from initiative and changed only by the accepted activation-completion transaction. |
| `squadron_phase_activations_committed` | `GameState` phase/turn state | Count from zero through the rules-defined per-turn maximum; reset on handoff and phase entry/exit. |
| `activation_id` | `SquadronInstance` action state | Stable identity derived from accepted `ActivateSquadronCommand.sequence`; unique and unchanged for that activation. |
| `activation_context` | `SquadronInstance` action state | Exactly `squadron_phase` or `ship_squadron_command`; inactive sentinel when no retained activation history exists. |
| `commanding_ship_player` and `commanding_ship_index` | `SquadronInstance` action state | Complete owner/index pair present only in ship-command context; validates the enclosing command owner. |
| `move_action_committed` | `SquadronInstance` action state | Boolean written once by accepted movement mutation; never inferred from scene position change. |
| `attack_action_disposition` | `SquadronInstance` action state | `available`, `begun`, or `declined`; accepted Begin changes available to begun, accepted Skip changes available to declined, and neither returns to available before round reset. |
| Stable ship-activation identity (`ship_activation_identity`) | ADR-006 activation-local boundary on `ShipInstance` | Stable identity assigned by the accepted semantic ship-activation entry transition; unchanged for the activation and cleared only by accepted normal, exceptional, or defensive cleanup. The implementation may follow repository-private naming, but SHALL preserve this semantic identity rather than bind architecture to a current command name. |
| Squadron-command opportunity disposition (`squadron_command_opportunity_disposition`) | Same ADR-006 activation-local boundary on `ShipInstance` | `UNREACHED`, `OPEN`, or `CONSUMED`, scoped to the stable identity. It follows `UNREACHED -> OPEN -> CONSUMED`, with direct `UNREACHED -> CONSUMED` only when legitimately unavailable, passed, or otherwise canonically not exercised. |
| Maneuver opportunity disposition (`maneuver_opportunity_disposition`) | Same ADR-006 activation-local boundary on `ShipInstance` | `UNREACHED`, `OPEN`, or `CONSUMED`, scoped to the stable identity. Commitment leaves it `OPEN`; exact-once completion after all mandatory consequences performs `OPEN -> CONSUMED`. Neither `UNREACHED` nor `OPEN` permits normal activation completion. |
| `squadron_command_activations_committed` | Same ADR-006 activation-local boundary on `ShipInstance` | Count of accepted commanded-squadron activations for the matching active identity and `OPEN` opportunity; incremented exactly once by accepted activation commitment and cleared with that boundary. |
| Optional active Maneuver execution record | Same ADR-006 activation-local boundary on `ShipInstance` | **Not a TWI-003 field.** Amended ADR-006 requires it; BUG-043 alone allocates its exact schema, serialization, recovery, creation, mutation, and retirement. |

These fields contain irreducible history needed for duplicate rejection,
save/load, replay, reconnect, and derivation. They SHALL be JSON-safe,
validated, serialized only from their listed owner, and absent from
`CurrentAttackState`.

### 5.3 Derived Facts -- Not Serialized As New Authority

| Fact | Derivation source |
| --- | --- |
| Declaration opportunity exists | Canonical phase/context, entity eligibility, existing attack/action progress, and accepted rule state. |
| Current Squadron Phase active squadron | Unique active/incomplete `SquadronInstance` activation identity in Squadron Phase context. |
| Squadron activation is active | Valid retained activation identity/context plus incomplete `activated_this_round` in the current canonical round/reset epoch. |
| Squadron movement remains | Context, `move committed`, attack disposition, Rogue/static rule facts, and completion state. |
| Squadron attack remains | Attack disposition equals available and all enclosing/rule eligibility remains valid. |
| Squadron activation complete | Context-specific action dispositions plus `activated_this_round`. |
| Ship is in its Squadron command opportunity | Matching active ADR-006 identity plus Squadron-command disposition `OPEN`, with current resource and rule validation. |
| Squadron-command capacity | Current authoritative ship dial/token/static squadron value and accepted command/rule semantics at validation time. |
| Squadron-command remaining activations | Derived capacity minus stored committed count, constrained by current authoritative resource and eligibility state. |
| Ship post-Skip Maneuver availability | Matching active ADR-006 identity plus Maneuver disposition `OPEN`; a valid no-active ship declaration Skip performs the authoritative `UNREACHED -> OPEN` transition. |
| Maneuver commitment/completion state | `OPEN` plus absence/presence of the matching active execution record, or `CONSUMED` plus no active record, under ADR-006 and SMI-041. |
| Remaining Maneuver consequences | Matching active execution plus purpose-specific canonical consequence owners; re-evaluated after each accepted consequence. |
| Phase handoff or next selection | Canonical controller/count plus remaining eligible squadrons. |
| Preview candidate, legality explanation, geometry, pool preview | Fresh resolver query from canonical state. |
| Post-Begin/post-Skip route | Resulting canonical owners through existing flow policy/projector. |
| Viewer affordance | Canonical state plus visibility rules. |

Capacity SHALL NOT be frozen at Squadron-step entry. It SHALL be re-derived
from current authoritative owners whenever an accepted command validates it.
No derived fact in this table gains a new serialized field.

### 5.4 Transient Or Presentation Facts

The following may exist only as replaceable non-authoritative data:

- target candidate and Preview details;
- candidate rejection feedback;
- declaration pending flag and retained intent;
- modal action selection and temporary button state;
- scene token references and node lifecycle;
- selector indexes and cached targeting entries;
- `SquadronCommandResolver._max_activations` and `_activations_used` after they
  become read-only projections of canonical state;
- `GameManager.active_player`, `_activating_squadron`, and
  `_squadrons_activated_this_turn` as one-way caches during transition;
- `InteractionFlow` and payload;
- overlays, highlights, tooltips, and labels; and
- uncommitted Navigate speed/yaw choices, maneuver-tool geometry, candidate
  destination, and advisory overlap or play-area warnings; and
- viewer affordances and presentation projections derived from an accepted
  viewer-authorized passive Network representation.

None serialize as gameplay authority or write back into canonical owners.

### 5.5 Prohibited Duplicate Fields

The implementation SHALL NOT add or preserve as a second writable fact:

| Prohibited field/shape | Reason |
| --- | --- |
| `activation_step_id` spanning all ship steps | General ship activation FSM and predecessor policy are outside the accepted declaration scope. |
| new stored `squadron_step_active` | Duplicates the accepted purpose-specific Squadron-command disposition and encourages a generic step mirror. |
| `current_step` or general activation-stage enum | ADR-006 authorizes only stable identity, two purpose-specific dispositions, one committed count, and at most one purpose-specific active Maneuver execution record; it does not authorize a general activation FSM. |
| generic Maneuver lifecycle/phase enum, stack, queue, callback, or continuation record | The purpose-specific active execution record plus its consequence owners supply the required distinction without general workflow infrastructure. |
| new stored `squadron_command_capacity` | Capacity is derived from current authoritative resources and rules; freezing it is not authorized. |
| new stored `activation_progress_active` | Active state is derivable from identity/context/completion and would duplicate them. |
| new stored `activation_round` | Current/reset epoch and unique activation identity provide the required validation; no authority requires a second round copy. |
| active squadron owner/index on `GameState` | Derivable from the unique squadron activation identity and would duplicate entity-local action state. |
| declaration opportunity object/boolean | Derived binding under CON-006, not a new owner. |
| Preview or pending data in `GameState` | Transient and explicitly excluded from canonical serialization. |
| action history copied into `CurrentAttackState` | Belongs to the existing adjacent owner. |
| route step used as enclosing authority | `InteractionFlow` is a derived routing representation. |

If direct repository evidence proves that one proposed irreducible field is
already represented by an accepted stored fact, reuse that exact fact and do
not add the listed field. Record the reuse in the implementation report and
retain the same acceptance criterion.

## 6. Identity, Mutation, And Reset Rules

### 6.1 Stable Identity

- Existing command infrastructure supplies authoritative command sequence.
- The ship-activation identity is assigned by the accepted semantic
  ship-activation entry transition. Current repository command paths may be
  named in implementation evidence, but their identifiers are not the
  architecture concept.
- The same ship-activation identity scopes both historically implemented
  ADR-006 dispositions and the committed Squadron-command activation count.
  Amended ADR-006 also binds BUG-043's later active Maneuver execution record
  to that identity.
- Accepted `ActivateSquadronCommand.sequence` supplies the squadron activation
  identity; local, host, mirror, replay, save/load, and reconnect preserve it.
- Begin uses the existing CON-001 current-attack identity mechanism unchanged.
- Stable entity references use owner/index/kind and hull-zone identifiers.
- Ship-command squadron context additionally carries the commanding ship
  owner/index and matching activation context.
- A stale, missing, reused, contradictory, or wrong-context identity rejects
  before mutation.
- Preview may carry claims for parity/tamper comparison, but payload facts do
  not become authoritative by being submitted.

### 6.2 Owner-Local Mutation

Every command SHALL:

1. validate base command applicability and sequence;
2. locate all stable entity/context owners;
3. validate the canonical enclosing opportunity and controller;
4. re-derive gameplay legality and applicable capacity;
5. calculate the complete transaction result;
6. snapshot every owner it may mutate;
7. apply owner-local mutations;
8. validate cross-owner invariants;
9. restore every snapshot on failure; and
10. expose an accepted result only after the entire transaction succeeds.

Scene callbacks occur only after acceptance. A command SHALL not return an
accepted-looking result after partial mutation.

### 6.3 Reset Boundaries

Only existing replayable semantic transitions may initialize, advance, consume,
or reset TWI-003 state:

- `AdvancePhaseCommand` initializes Squadron Phase controller/count on entry
  and clears phase-local values on exit;
- the accepted squadron activation-completion transaction updates the
  Squadron Phase count/controller and retains squadron action history until
  the existing round reset;
- `ActivateSquadronCommand` initializes one squadron activation identity,
  context, action availability, and commanding-ship reference where applicable;
- `MoveSquadronCommand` commits movement exactly once;
- Begin commits attack disposition to begun;
- declaration Skip commits attack disposition to declined;
- `CompleteSquadronActivationCommand` marks the activation complete at its
  existing enclosing-action boundary;
- `StatusPhaseCleanupCommand` and existing entity round-reset operations clear
  retained squadron action history and dormant phase/command progress;
- accepted semantic ship-activation entry initializes one fresh ADR-006
  identity, both opportunity dispositions to `UNREACHED`, and the committed
  count to zero;
- the existing semantic transition into an executable Squadron-command
  opportunity changes its disposition from `UNREACHED` to `OPEN`;
- the existing semantic transition leaving, passing, or closing that
  opportunity changes `OPEN` to `CONSUMED`, or uses
  `UNREACHED -> CONSUMED` only for a legitimately unavailable, passed, or
  otherwise canonically unexercised opportunity;
- command-context `ActivateSquadronCommand` increments the matching ship's
  committed count exactly once while the Squadron-command disposition is
  `OPEN`;
- `AdvanceActivationStepCommand` remains the sole existing owner of
  `ShipInstance.begin_attack_step()` initialization and also owns only those
  ADR-006 opportunity mutations already assigned to its semantic transition;
- accepted no-active ship declaration Skip opens Maneuver with
  `UNREACHED -> OPEN` in the same atomic transaction;
- the existing normal Attack-completion transition opens Maneuver with
  `UNREACHED -> OPEN` without otherwise changing protected post-Begin behavior;
- current Maneuver execution, consequence, completion, and exceptional cleanup
  obey amended ADR-006 and the accepted requirements, but their concrete
  mutations and evidence are allocated only by BUG-043;
- surviving normal activation completion requires both dispositions to be
  `CONSUMED`, then clears the ADR-006 boundary atomically;
- accepted destruction or another exceptional terminal transition clears the
  ADR-006 boundary and invalidated nested consequence state without
  fabricating Maneuver execution, consumption, return, or End Activation; and
- defensive round cleanup clears stale activation-boundary facts and reports
  impossible aggregate uniqueness rather than choosing an owner from
  presentation state.

Load, replay initialization, reconnect, scene creation/destruction,
projection, modal close, and `GameManager` cache reconstruction SHALL NOT reset,
consume, or repair these facts.

No new general ship-step transition or predecessor validation is authorized by
this section.

## 7. Repository Seams And Risks

This table is the complete file-impact and seam-risk inventory. A file not
listed SHALL remain unchanged unless the Entry Gate proves it is the existing
accepted owner or an already-covered test is physically located elsewhere; in
that case the implementation report SHALL identify the exact substitute before
editing.

| Seam and expected files | Required change | Risk | Detection/control |
| --- | --- | --- | --- |
| Canonical phase state: `src/core/state/game_state.gd` | Add only irreducible Squadron Phase controller/count, invariant validation, and later Slice 2 serialization. | High: duplicates `GameManager.active_player`. | Structural write search plus save/load and phase-turn tests prove one writer. |
| Squadron action owner: `src/core/state/squadron_instance.gd` | Add identity, context, commanding-ship reference, move fact, attack disposition, validation/snapshot/reset, and later serialization. | High: modal-local action state may continue writing. | Write inventory and scene-destruction/reconstruction tests. |
| Ship activation boundary: `src/core/state/ship_instance.gd` | **Historical:** preserve BUG-002 fields and add the identity, two dispositions, and committed Squadron-command count. **Current Maneuver:** BUG-043 alone allocates the optional execution record and related invariants. | High: accidental BUG-002 reset, duplicate capacity, premature Maneuver consumption, or generic step state. | Historical field classification and protected regressions; current Maneuver evidence belongs to BUG-043. |
| Aggregate ship-activation validation: `src/core/state/game_state.gd` | Validate zero or one active ADR-006 identity across both fleets without becoming a writable owner. | High: duplicate `GameState` activation state. | Cross-fleet owner and write searches plus invalid reconstruction tests. |
| Current attack: `src/core/state/current_attack_state.gd` | Normally unchanged; only existing validation/reference use is allowed. | High: enclosing state copied into current attack. | Membership and serialization shape tests. |
| Phase entry/exit: `src/core/commands/advance_phase_command.gd`, `src/core/commands/status_phase_cleanup_command.gd` | Initialize/clear the new phase/action progress only within existing transactions. | Medium: scene still controls turn. | Command sequence and save/load phase tests. |
| Ship activation entry: current semantic paths represented by `src/core/commands/activate_ship_command.gd` and `convert_dial_to_token_command.gd` | Establish the stable identity and inactive ADR-006 defaults after complete entry validation. | High: identity initialization differs by controller route or creates two active owners. | Entry Gate seam map and local/host/mirror/replay identity tests. |
| Ship step transition: `src/core/commands/advance_activation_step_command.gd` | Preserve sole `begin_attack_step()` initialization; own only its assigned Squadron opening/closure and normal Attack-to-Maneuver opening mutations, never a general FSM. | High: a purpose-specific disposition becomes generic step progression. | Entry Gate seam map and structural search for all activation-boundary writes. |
| Squadron activation/action: `src/core/commands/activate_squadron_command.gd`, `move_squadron_command.gd`, `complete_squadron_activation_command.gd` | Validate context/controller/identity, commit action history, and coordinate existing enclosing count/closure. | High: command-mode and phase-mode behavior diverge; post-Begin completion ordering drifts. | Context matrix and explicit post-Begin regression oracles. |
| Declaration commands: `src/core/commands/begin_attack_command.gd`, `skip_attack_command.gd` | Complete context validation and atomic mutation; preserve active/out-of-scope branches. | High: partial owner mutation or fallback initialization. | Failure injection, snapshots, command history, and active-branch regression. |
| Maneuver and terminal paths | **Historical:** retain only the declaration transition that opens Maneuver and valid terminal invariants. **Current:** no TWI-003 implementation allocation; BUG-043 owns the complete Maneuver cutover. | High: treating this row as a second Maneuver plan. | Current Maneuver verification belongs only to BUG-043. |
| Applicability/policy: `src/core/commands/command_applicability.gd`, `src/core/state/flow_spec.gd` | Make broad phase policy agree with concrete opportunity/controller validation. | Medium: flow becomes authority. | Direct submission tests with misleading/missing flow payloads. |
| Declaration resolver: `src/core/combat/targeting_list_builder.gd`, `src/core/combat/attack_target_resolver.gd`, `src/autoload/game_scale.gd`, accepted rule surfaces | Establish Preview/Begin parity and BUG-005 distance-1 classification; do not change edge measurement. | High: range and distance remain conflated. | Production-scale inside/outside distance-1 tests including the close-only interval. |
| Squadron-command adapter: `src/core/combat/squadron_command_resolver.gd` | Read capacity/use from authoritative owners; stop owning `_max_activations`/`_activations_used` semantically. | High: hidden mutable budget survives. | Search all reads/writes; destroy/recreate resolver mid-step. |
| Selector/executor: `src/scenes/game_board/target_selector.gd`, `attack_executor.gd` | Preserve Preview/Confirm/pending; consume accepted results one-way. | High: scene cache authorizes or consumes. | Preview command-cursor, rejection, and scene-recreation tests. |
| Activation controllers/modals: `src/scenes/game_board/ship_activation_controller.gd`, `squadron_phase_controller.gd`, `src/ui/combat/squadron_activation_modal.gd`, `src/scenes/game_board/modal_router.gd` | Replace gameplay writes/counters with queries and result-driven presentation. | High: scene lifecycle owns progress. | Direct command/replay plus teardown/reopen tests. |
| Application routing: `src/autoload/game_manager.gd`, `src/scenes/game_board/game_board.gd`, `src/core/state/interaction_flow.gd` | Derive controller/route from canonical owners; keep caches one-way. | High: load currently trusts route/controller payloads. | Reconstruction with absent/stale route and canonical-state assertions. |
| Projection/filtering: `src/core/network/ui_projector.gd`, `src/core/network/state_filter.gd` | Project new canonical state without authorizing commands. | Medium: filter drops required state or client synthesizes. | Viewer, host/client hash, reconnect, and direct-invalid-command tests. |
| Save/load: `src/core/state/save_game_metadata.gd`, `src/autoload/save_game_manager.gd` | **Historical:** TWI-003 activated its fields with version 3 in Slice 2. Current production is version 6; this is not a cutover instruction. | High: misreading a historical allocation as current. | Historical compatibility evidence only; current Maneuver allocation belongs to BUG-043. |
| Replay: `src/core/commands/game_replay.gd`, `src/autoload/replay_driver.gd`, command registrations | **Historical:** TWI-003 activated format 5 in Slice 2. Current production is format 9; this is not a cutover instruction. | High: legacy reinterpretation. | Historical sequence evidence only; current Maneuver allocation and fixture policy belong to BUG-043. |
| Network submission/result: `src/autoload/command_processor.gd`, `src/autoload/network_manager.gd`, `src/autoload/game_manager.gd` | Reuse existing host authority and mirror ordering; add no transport architecture. | High: client local writes or result overtaking. | Host/client canonical equality and rejected-command ordering tests. |
| Core state/command tests: `tests/unit/test_game_state.gd`, `test_ship_instance.gd`, `test_squadron_instance.gd`, `test_squadron_phase.gd`, `test_attack_commands.gd`, `test_command_applicability.gd`, `test_flow_spec.gd`, `test_squadron_command_resolver.gd` | Add owner, atomicity, context, policy, and protected regression evidence. | Medium: tests call helpers instead of production routes. | Contract matrix requires production command entry points. |
| Resolver tests: `tests/unit/test_targeting_list_builder.gd` and existing parity tests | Add real distinct distance/range thresholds and all pairing/context parity. | High: fixture collapses distance 1 and close. | Assert 181/292-style distinct bands from production configuration semantics. |
| Durability/distribution tests: `tests/unit/test_save_game_metadata.gd`, `test_save_game_manager.gd`, `test_save_load_round_trip.gd`, `test_game_replay.gd`, `test_state_filter.gd`, `test_ui_projector.gd`, `test_network_command_result_ordering.gd`, `tests/integration/test_network_transport.gd`, `test_reconnection_mid_attack.gd` | Prove exact compatibility, canonical reconstruction, filtering, mirror order, and no synthesis. | High: direct-boundary tests overclaim production paths. | Separate unit, protocol, transport, and final production evidence. |
| Protected regressions: `tests/integration/test_current_attack_shared_protocol.gd`, `test_current_attack_production_resume.gd`, `test_squadron_attack_target_recovery.gd`, existing Preview/Confirm tests | Remain passing without changing expected post-Begin semantics. | High: shared executor changes BUG-002. | Run unchanged tests and compare semantic command traces. |
| Baselines: `tests/fixtures/baseline_traces/replay_hot_seat_solo.json`, `replay_network.json` | Remain unchanged during implementation unless separately authorized after accepted trace review. | Medium: fixture update hides drift. | Baseline trace diff reviewed before any later maintenance. |

`src/core/effects/rule_registry.gd`, runtime upgrade implementations,
Timing Window Orchestrator code, attack-resolution commands, and architecture
documents were considered and SHALL remain unchanged unless an applicable
existing declaration rule already has a directly assigned CON-003 validation
surface. No new rule or timing participant is created.

## 8. Historical Compatibility Record — Not Current Instructions

At the time TWI-003 ran, TWI-002 supplied save version 2 and replay format 4.
TWI-003's behavior-inert Slice 1 preserved those values; its semantic Slice 2
advanced them to save version 3 and replay format 5. The loaders rejected the
immediately preceding formats rather than inferring or migrating missing
declaration state. Network reconnect remained a same-semantic-build canonical
snapshot path and TWI-003 allocated no Network protocol bump.

Those allocations are historical facts only. Current production emits:

- `SaveGameMetadata.CURRENT_VERSION = 6`;
- `GameReplay.FORMAT_VERSION = 9`, with the signed alias equal to 9; and
- `NetworkManager.PROTOCOL_VERSION = 6`.

No current implementation may restore, reuse, or treat the historical values
2/3 or 4/5 as an entry condition or next-version instruction. TWI-003 owns no
future compatibility change. BUG-043 independently evaluates and owns every
save, replay, and Network compatibility change required by the current
Maneuver cutover.

## 9. Historical Entry Gate Record — Not Executable

The Entry Gate was not an implementation slice. It authorized no semantic or
production edit. It is retained to explain the evidence required before the
historical cutover; it must not be rerun against today's version constants or
used to reopen the completed slices.

### 9.1 Required Read-Only Record

Before Slice 1, record in the implementation report:

- current revision and worktree status;
- all pre-existing changes that must be preserved;
- exact save and replay format constants;
- evidence that the TWI-002 production-activation checkpoint is present;
- historical evidence available at that time for adjacent Maneuver behavior;
  later BUG-043 work is outside this gate and never shares a TWI-003 cutover;
- evidence that ADR-006 is Accepted and identifies `ShipInstance` as the sole
  writable owner of its five activation-local concepts;
- every production write to the fields in Section 5;
- every live submission of Begin, no-active Skip, squadron activation,
  squadron movement, squadron completion, phase advance, ship-step advance,
  and round cleanup;
- the existing semantic command boundaries for ship-activation identity
  initialization, Squadron opportunity opening/consumption, commanded-squadron
  commitment, Maneuver opening/commitment/consequence/completion, normal
  activation completion, exceptional destruction/termination, and defensive
  round cleanup;
- evidence that no conflicting canonical activation-boundary owner exists;
- evidence that Slice 1 can introduce the ADR-006 owner-local substrate with
  inactive defaults and zero live production integration;
- exact tests protecting Preview/Confirm, Begin rejection, Skip rejection,
  BUG-002 Step 6, second normal attack, save/load, replay, network, and
  reconnect; and
- any unrelated failing or changed evidence already present.

Repository searches SHALL cover, at minimum:

- all writes to `attack_step_active`, `committed_attack_count`,
  `used_attack_hull_zones`, `anti_squadron_attack_zone`,
  `anti_squadron_target_history`, and both `activated_this_round` fields;
- `GameManager.active_player`, `_activating_squadron`, and
  `_squadrons_activated_this_turn`;
- `SquadronCommandResolver._max_activations` and `_activations_used`;
- every `InteractionFlow` controller/step read used for command authorization;
- all `CurrentAttackState` installs/retirements;
- every `GameState.serialize()`/deserialize, save metadata, replay format,
  filter, projector, load, and reconnect entry; and
- the two BUG-005 outgoing-target collection paths.

This inventory is implementation seam confirmation, not another Migration
Assessment. It SHALL not change MA-ATTACK-002 classifications.

The Entry Gate verifies accepted ownership and executable semantic seams. It
SHALL NOT require the ADR-006 fields, production mutations, serialization, or
cutover behavior to exist before the slices assigned to implement them.

The gate may run already-existing passing tests, but it SHALL add no test,
disabled test, expected-failure test, or retained-for-later test. The baseline
must be clean for TWI-003 production files; any unrelated pre-existing change
must be identified, non-overlapping, and preserved.

### 9.2 Historical Entry Gate Criteria

The unchecked form is retained as historical procedure, not a current to-do
list. In particular, the compatibility assertions below describe the former
pre-cutover baseline and are superseded by Section 8.

- [ ] The required startup and authority documents were read.
- [ ] The TWI-003 production baseline is clean; unrelated non-overlapping
  worktree changes are recorded and protected.
- [ ] TWI-002 production activation is present and passing at its accepted gate.
- [ ] Later BUG-043 work is outside this historical gate and is not sequenced
  with TWI-003.
- [ ] ADR-006 is Accepted.
- [ ] `ShipInstance` is the accepted sole writable owner of the historical
  stable identity, two dispositions, and committed Squadron-command count;
  `GameState` is aggregate validator only. The later optional execution record
  is a BUG-043 allocation, not a historical gate criterion.
- [ ] Historical pre-cutover save version was exactly 2; this is not a current
  version assertion.
- [ ] Historical pre-cutover replay format was exactly 4; this is not a
  current version assertion.
- [ ] Each irreducible fact in Section 5.2 maps to its listed accepted owner,
  whether or not the Slice 1 field has already been introduced.
- [ ] Existing semantic command boundaries needed to implement every ADR-006
  mutation in Sections 6.3 and 7 are identified.
- [ ] No conflicting canonical owner for the ADR-006 boundary exists.
- [ ] Slice 1 can introduce the ADR-006 owner-local substrate behavior-inertly,
  without a live reference or production serialization.
- [ ] No required durable declaration fact lacks an accepted owner.
- [ ] Existing command paths can mutate all required owners atomically without
  introducing a new semantic command type solely for TWI-003.
- [ ] Protected baseline tests and semantic command oracles are identified.
- [ ] No implementation edit has occurred.

Failure of any criterion invokes the single stop list in Section 14.

## 10. Historical Slice 1 -- Behavior-Inert Canonical Substrate

### 10.1 Classification And Objective

Slice 1 was the behavior-inert implementation slice recorded by commit
`440b670`. It prepared owner-local data
invariants without changing live gameplay, command policy, projection,
serialization, replay, networking, save/load, or reconnect behavior.

Its objective is narrowly mechanical:

- declare the irreducible fields in Section 5.2 on their existing owners;
- provide owner-local initialization, validation, snapshot, restore, query,
  and reset operations for those fields;
- prove those operations directly with unit tests; and
- leave every production command and route on the pre-cutover semantics.

The repository before and after Slice 1 SHALL accept, reject, serialize,
project, replay, and route the same live interactions with the same semantic
command order.

### 10.2 Permitted Production Changes

Only these production changes are permitted:

1. `GameState` may declare inactive/default Squadron Phase controller and
   activation-count fields plus owner-local invariant and snapshot operations,
   and may add a read-only aggregate validator for zero or one active ADR-006
   ship identity across both fleets.
2. `SquadronInstance` may declare inactive/default activation identity,
   context, commanding-ship reference, movement-use, and attack-disposition
   fields plus owner-local invariant, snapshot, restore, remaining-action, and
   reset operations.
3. `ShipInstance` may declare the inactive/default historical ADR-006 stable
   ship-activation identity, Squadron-command opportunity disposition,
   Maneuver opportunity disposition, and committed Squadron-command activation
   count, plus their owner-local invariant, snapshot, restore, query,
   transition-guard, normal-completion eligibility, exceptional-clear, and
   reset operations. The active Maneuver execution record was not part of this
   slice and is not retroactively allocated here.
4. Existing clone/test builders may initialize the same inactive defaults only
   when required for direct owner tests.

All new values SHALL default to an inactive state that grants no opportunity,
action, controller, or command budget. Direct state-owner tests may invoke the
new methods. No production call site may do so in this slice.

### 10.3 Prohibited Slice 1 Changes

Slice 1 SHALL NOT:

- modify any gameplay command;
- register or add a semantic command;
- connect a new field to a production call site;
- change `CommandApplicability` or `FlowSpec`;
- change `TargetingListBuilder`, including BUG-005 behavior;
- change Preview, Confirm, Begin, Skip, automatic no-target behavior, or
  accepted/rejected routing;
- change a scene, modal, controller, `GameManager`, or projector;
- change `GameState.serialize()`, `SquadronInstance.serialize()`,
  `ShipInstance.serialize()`, deserialization, `StateFilter`, or reconnect;
- change save version 2 or replay format 4;
- emit new fields into a save, replay, state mirror, or hash;
- add complete command logic that is merely unreachable;
- add default readers that silently change live decisions;
- add an unused policy branch, feature flag, compatibility bridge, or
  production adapter;
- modify any post-Begin behavior; or
- update baseline fixtures.

The boundary is mechanical: fields and owner-local pure operations exist,
direct unit tests exercise them, and a structural search proves there are zero
live production references outside their owner definitions and direct tests.

### 10.4 Owner-Local Invariants

The direct owner tests SHALL prove at least:

#### `GameState`

- inactive defaults are outside Squadron Phase control;
- controller is either player 0, player 1, or the inactive sentinel;
- committed count is non-negative and no greater than the accepted per-turn
  limit;
- inactive phase state cannot expose a controller or committed count;
- snapshot/restore is exact and deep enough for atomic failure rollback; and
- no route or `GameManager` field is consulted;
- zero or one ship across both fleets may have an active ADR-006 identity; and
- aggregate validation reads the owning `ShipInstance` facts but cannot mutate
  or duplicate them on `GameState`.

#### `SquadronInstance`

- inactive defaults grant neither movement nor attack;
- an initialized identity is stable and non-empty;
- context is exactly one supported value while retained history exists;
- commanding ship reference is complete only in ship-command context and
  absent otherwise;
- move commitment is one-way until reset;
- attack disposition changes from available to exactly begun or declined and
  never changes back before reset;
- non-Rogue completion, Rogue remaining movement, and commanded-squadron
  remaining movement are derived from fields and static/rule inputs;
- completion does not fabricate a target or current attack;
- snapshot/restore is exact; and
- round reset returns every new field to its inactive default without changing
  unrelated squadron state.

#### `ShipInstance`

- no active ship-activation identity has the no-activation representation for
  either disposition or committed count;
- a newly established identity initializes both dispositions to `UNREACHED`
  and committed count to zero;
- the stable identity scopes both dispositions and the count and does not
  change during the activation;
- Squadron-command permits `UNREACHED -> OPEN -> CONSUMED`, and permits direct
  `UNREACHED -> CONSUMED` only through a caller-validated semantic transition
  for a legitimately unavailable, passed, or otherwise canonically
  unexercised opportunity;
- Maneuver historically permits `UNREACHED -> OPEN -> CONSUMED` and normal
  progression has no `UNREACHED -> CONSUMED` operation; current commitment and
  completion invariants are tested under BUG-043;
- invalid historical boundary combinations reject, including a disposition
  without the matching identity;
- normal-completion eligibility is false while Maneuver is `UNREACHED` or
  `OPEN`, and requires both dispositions to be `CONSUMED`;
- exceptional clear removes the identity and resets both dispositions and the
  count without first fabricating normal progression;
- committed command activation count is non-negative and a positive count
  requires the matching active identity and `OPEN` Squadron opportunity;
- the count itself does not assert that a Squadron command opportunity is
  `OPEN`;
- remaining capacity is not stored;
- owner snapshot/restore leaves all BUG-002 fields exact;
- reset of new command progress does not reset
  `committed_attack_count`, `used_attack_hull_zones`,
  `anti_squadron_attack_zone`, or `anti_squadron_target_history` at an
  unauthorized boundary; and
- no general activation step or predecessor field exists.

### 10.5 Slice 1 File Boundary

Expected production files:

- `src/core/state/game_state.gd`;
- `src/core/state/squadron_instance.gd`; and
- `src/core/state/ship_instance.gd`.

Expected direct tests:

- `tests/unit/test_game_state.gd`;
- `tests/unit/test_squadron_instance.gd`; and
- `tests/unit/test_ship_instance.gd`.

No other production file belongs in Slice 1. If an owner-local invariant
cannot be prepared inside these existing owners without a live integration
change, Section 14 applies.

### 10.6 Slice 1 Checkpoint

- [ ] Only the three state-owner files and their direct tests changed.
- [ ] Every new field is classified as new irreducible stored state in Section
  5.2.
- [ ] No field from Sections 5.3 through 5.5 was stored.
- [ ] New fields have inactive defaults and validate deterministically.
- [ ] ADR-006 normal-completion and exceptional-clear owner operations remain
  semantically distinct in direct tests.
- [ ] Snapshot/restore and reset tests pass.
- [ ] BUG-002 ship progress remains byte-for-byte equivalent through its
  existing snapshot/serialization tests.
- [ ] Structural search finds zero live production references to every new
  field or method outside the three owner files.
- [ ] No serializer emits a new field.
- [ ] Save version remains exactly 2.
- [ ] Replay format remains exactly 4.
- [ ] No command, policy, resolver, projection, scene, or route changed.
- [ ] Focused state-owner tests pass.
- [ ] Existing Preview/Confirm, attack-command, save/load, replay, and BUG-002
  focused tests pass with unchanged semantic command oracles.
- [ ] `git diff --check` passes.

The safe intermediate state is fully pre-cutover production behavior with
unused inactive owner-local substrate. Failure invokes Section 14. Only a
passing checkpoint permits Slice 2.

## 11. Historical Slice 2 -- Complete Authoritative Declaration Cutover

This semantic cutover is present in the production lineage through commit
`7cfa47b`. The retained instructions below document its intended atomic scope;
they do not authorize a second cutover. Any later text concerning Maneuver is
constrained by current accepted authority and allocated only by BUG-043.

### 11.1 Classification And Objective

Slice 2 is the only Semantic Slice. It is one indivisible cutover across live
local play, authoritative host execution, client mirroring, projection,
serialization, save/load, replay, reconnect, and tests.

Its objective is to activate the complete Section 4 behavior, remove every
superseded gameplay write in the same slice, and leave exactly one semantic
model. No context may cut over independently.

### 11.2 Preconditions

- The Entry Gate and Slice 1 checkpoint pass.
- ADR-006 remains Accepted, `ShipInstance` remains its sole writable owner, and
  the existing semantic transition paths required by Sections 6.3 and 7 are
  recorded.
- Save version remains exactly 2 and replay format remains exactly 4.
- Every live call site in Section 7 is identified.
- Every required focused and regression test has an exact test-file home.
- No compatibility dual-write or fallback is required.

### 11.3 Activate Canonical Serialization First Within The Atomic Change

As part of the same unmerged cutover change:

- connect the Section 5.2 fields to their existing owner serializers,
  deserializers, validators, clones, snapshots, filters, and projectors;
- serialize the ADR-006 boundary only on its owning `ShipInstance`, while
  `GameState` performs aggregate/cross-fleet validation without storing a
  second writable copy;
- require complete cross-owner validity before state installation;
- retain no Preview, pending, modal, resolver, or route authority;
- advance the compatibility constants exactly as specified in Section 8; and
- keep the cutover unavailable for merge or release until every later item in
  this slice is complete.

This ordering is an editing discipline inside one atomic slice, not an
intermediate supported runtime. No build exposing new serialized semantics
without the complete command cutover is acceptable.

### 11.4 Enclosing Opportunity And Controller Cutover

#### Squadron Phase

`AdvancePhaseCommand` entering Squadron Phase SHALL initialize the canonical
Squadron Phase controller to `initiative_player` and the committed activation
count to zero. Leaving Squadron Phase SHALL clear both values to inactive
defaults in the same existing phase transaction.

`ActivateSquadronCommand` SHALL validate:

- Squadron Phase is current;
- submitting player equals canonical Squadron Phase controller;
- no other squadron activation is currently active;
- selected squadron exists, is controlled, is not destroyed, and is not
  activated this round;
- count and remaining eligibility permit another activation; and
- command sequence can provide one fresh activation identity.

Acceptance initializes the squadron action state atomically. It does not begin
an attack, choose an action, or store a Preview.

`CompleteSquadronActivationCommand`, when invoked at its existing
Squadron-Phase closure boundary after movement or an active attack, SHALL
atomically:

- validate the matching activation identity/controller/context;
- mark the squadron activated for the round;
- increment the phase committed count once;
- derive whether the same player may select another squadron;
- otherwise reset count and hand control to the other player, auto-pass, or
  enable the existing phase transition from canonical eligibility; and
- publish only the derived result after acceptance.

`GameManager._activating_squadron`, `active_player`, and
`_squadrons_activated_this_turn` SHALL cease to authorize or mutate that
progress. They may mirror accepted results until removable without changing
behavior.

#### Ship Activation Attack Step

`AdvanceActivationStepCommand` SHALL remain the sole production path that
calls `ShipInstance.begin_attack_step()`. Begin SHALL not initialize the step.

Ship declaration Preview, Begin, and Skip SHALL validate
`attack_step_active` together with the matching stable ADR-006 ship-activation
identity. `InteractionFlow == ATTACK_STEP` alone SHALL never establish the
opportunity.

Accepted ship declaration Skip SHALL mutate only the declaration-adjacent
facts assigned by CON-006: consume the active ship Attack-step opportunity and
change the matching Maneuver disposition from `UNREACHED` to `OPEN`. It SHALL
preserve hull-zone use and target history and leave `CurrentAttackState`
inactive. TWI-003 SHALL not define how any other ship activation step precedes
or follows another.

#### Ship-Phase Squadron Command

The matching ADR-006 identity and Squadron-command disposition `OPEN` SHALL
establish the opportunity; controller and capacity are re-derived for every
validation from the active ship, current ship dial/token/static squadron value,
and accepted rule facts. The existing transition into the executable
opportunity changes `UNREACHED -> OPEN`. The existing transition leaving,
passing, or closing it changes `OPEN -> CONSUMED`, or uses direct
`UNREACHED -> CONSUMED` only when the opportunity is legitimately unavailable,
passed, or otherwise canonically not exercised under the applicable rules.
It never reopens for the same identity.

`ActivateSquadronCommand` in command context SHALL validate:

- Ship Phase and the accepted active Squadron-command opportunity;
- commanding ship stable identity and controller;
- current authoritative dial/token/rule-derived capacity;
- stored committed count is below that capacity;
- selected squadron range and ownership eligibility;
- selected squadron is not already active or activated this round; and
- a fresh activation identity.

Acceptance atomically initializes the squadron action state and increments the
commanding ship's activation-local committed count once while the matching
Squadron-command opportunity is `OPEN`. Merely selecting or replacing a modal
candidate consumes no count. Capacity and remaining activations remain derived;
capacity SHALL NOT be stored.

`SquadronCommandResolver` SHALL become a read-only adapter over those owners.
Its cached `_max_activations` and `_activations_used` SHALL not authorize,
consume, serialize, restore, or repair budget. Existing dial/token spend
commands retain their accepted ownership and order.

When a commanded squadron closes, `CompleteSquadronActivationCommand` may
validate and close its action state. Existing coordinating code derives
remaining movement, another squadron activation, or the existing Repair
boundary from canonical state. It SHALL not change any active attack's
completion or post-Begin ordering.

#### Historical ADR-006 Entry And Adjacent Maneuver Boundary

The historical cutover assigned the declaration-adjacent ADR-006 mutations to
existing semantic transitions and added no boundary-maintenance command:

- accepted semantic ship-activation entry establishes one fresh identity and
  initializes both dispositions to `UNREACHED` and the committed count to zero;
- accepted no-active ship declaration Skip performs Maneuver
  `UNREACHED -> OPEN` in the Skip transaction;
- the existing transition after normal Attack completion performs Maneuver
  `UNREACHED -> OPEN` without changing `CompleteAttackCommand`, attack
  resolution, continuation, or post-Begin ordering;
- current Maneuver commitment, execution, consequences, completion, and
  recovery are not TWI-003 allocations; BUG-043 supplies their concrete
  commands, record fields, owners, evaluators, serialization, Network behavior,
  compatibility changes, and verification;
- normal activation completion rejects Maneuver `UNREACHED` and `OPEN`,
  requires both dispositions `CONSUMED`, and then clears the boundary;
- accepted active-ship destruction or another exceptional terminal transaction
  clears the boundary and invalidated nested consequence state without
  fabricating Maneuver consumption, return, or End Activation; and
- defensive round cleanup clears stale boundary facts and rejects or reports
  impossible aggregate uniqueness.

TWI-003 SHALL NOT implement or redesign the complete Maneuver interaction. The
accepted current requirements—including transient pre-commit exploration,
atomic Navigate derivation/consumption, speed-zero execution, consequence
ordering, and actual-final-position play-area destruction—supersede any
conflicting historical assumption here and are intentionally not duplicated.

If an existing semantic transition boundary required by this list cannot be
identified, or atomic rollback cannot cover its adjacent owners, Section 14
applies. This integration does not authorize changes to the gameplay meaning or
ordering of any protected post-Begin transition.

### 11.5 Squadron Action Cutover

For both squadron contexts:

- accepted activation creates `attack disposition = available` and
  `move committed = false`;
- `MoveSquadronCommand` validates the matching identity/context/controller and
  commits movement exactly once with position mutation;
- non-Rogue Squadron Phase reports no remaining action after its one committed
  move or accepted Begin; active-attack completion and later activation closure
  remain on their existing path;
- Rogue and commanded squadron contexts derive independent remaining movement
  and attack opportunities;
- accepted Begin changes attack disposition from available to begun in the
  same transaction as current-attack installation;
- accepted no-active Skip changes attack disposition from available to
  declined;
- rejected, duplicate, stale, wrong-controller, wrong-context, or reordered
  actions change no owner;
- completion retains action history until the existing round reset so replay,
  load, and reconnect reject reuse; and
- scene/modal recreation derives remaining actions without restoring Preview.

The implementation SHALL use the accepted Rules Reference and existing rule
surfaces for non-Rogue/Rogue action eligibility. It SHALL not create a new
action-policy owner.

### 11.6 Resolver, Preview, And BUG-005 Cutover

In one shared production query boundary:

- rebuild declaration facts from canonical `GameState` and stable entity
  references;
- apply accepted mechanic and rule surfaces;
- return deterministic eligible target entries and rejection categories;
- make ship and squadron Preview consume those semantics;
- make Begin immediately re-run those semantics from command intent;
- compare any Preview-derived claimed range/obstruction/pool values with the
  re-derived result and reject tampering;
- preserve transient replacement, deselection, illegal-selection behavior,
  explicit Confirm, and pending gating; and
- change the two outgoing squadron collectors from close-range eligibility to
  distance-band-1 eligibility while preserving edge-to-edge distance
  measurement.

Required BUG-005 boundary tests use production-distinct scales:

| Pairing | Distance | Expected Preview | Expected Begin |
| --- | --- | --- | --- |
| Squadron -> squadron | immediately inside distance 1 | legal | accepted when all other facts remain legal |
| Squadron -> squadron | immediately outside distance 1 but inside close range | illegal | rejected for range/distance legality |
| Squadron -> ship hull zone | immediately inside distance 1 | legal | accepted when all other facts remain legal |
| Squadron -> ship hull zone | immediately outside distance 1 but inside close range | illegal | rejected for range/distance legality |

The tests SHALL assert that distance 1 and close range are unequal in the
fixture. They SHALL not move the target beyond both thresholds, because that
would not prove BUG-005.

### 11.7 Begin Cutover By Context

| Context | Begin validates and commits in addition to `CurrentAttackState` |
| --- | --- |
| Ship attack | Existing Attack-step opportunity, controller, hull zone, remaining normal/anti-squadron legality, and existing ship attack history; commit existing ship progress exactly once. |
| Non-Rogue Squadron Phase | Matching activation identity/context/controller and available attack disposition; commit begun so no additional action remains, while active-attack completion and activation closure retain their existing order. |
| Rogue Squadron Phase | Matching activation and available attack disposition; commit begun while preserving unused movement. |
| Ship-command squadron | Matching squadron activation plus commanding ship opportunity/reference/budget; commit begun while preserving unused movement and already committed command slot. |

Every context also validates every applicable CON-006-BEGIN-002 fact,
`CommandApplicability`, `FlowSpec`, rule validation, current-attack inactivity,
and sequence/order. The transaction follows Section 4.4.

The existing accepted ship Begin transaction is extended only where necessary
to share legality and projection with the other supported contexts. Its BUG-002
progress mutation and rollback semantics SHALL not change.

### 11.8 Skip Cutover By Context

Implement the Section 4.5 matrix within the no-active declaration branch of
`SkipAttackCommand`.

Before mutation every row validates:

- `CurrentAttackState` is inactive;
- context is one supported CON-006 context;
- controller, stable owner references, and command sequence match;
- the enclosing declaration opportunity still exists;
- action/step history still makes attack available; and
- Preview presence is ignored for legality and effects.

The command snapshots every participating owner, commits the exact row, and
restores all owners on any validation/invariant failure.

Do not alter branches for:

- active current-attack cancellation;
- `flow_replaced` or `flow_terminated` after Begin;
- `squadron_done` or other post-Begin/sub-step behavior;
- BUG-002 anti-squadron continuation; or
- any unsupported analysis/simulator context.

Automatic no-target code SHALL submit the supported no-active branch and wait
for an accepted result. It SHALL not close the modal, increment a counter,
advance a step, or mark a squadron activated before acceptance.

### 11.9 Applicability And Flow Cutover

`CommandApplicability`, applicable `FlowSpec` policy, rule validation, and
concrete command validation SHALL agree:

- broad phase membership is insufficient;
- a visible modal or route is insufficient;
- a missing/misleading `InteractionFlow` payload cannot authorize;
- canonical context/controller/opportunity is required;
- accepted Begin makes declaration routing terminal and derives the existing
  attack route from canonical current attack;
- accepted Skip derives exactly the context row's next route;
- rejected commands preserve or reconstruct declaration interaction only when
  canonical opportunity remains; and
- non-controller projection may be read-only without changing authority.

Flow publication occurs after the canonical transaction. It is not part of
gameplay validation and cannot be written first.

### 11.10 Persistence, Replay, Network, And Reconnect Cutover

#### Canonical serialization and save/load

- New Section 5.2 fields serialize only on their existing owners.
- The historical Slice 2 serialized the stable ship-activation identity, both
  dispositions, and committed count on the owning `ShipInstance`.
- The later optional active Maneuver execution record and purpose-specific
  consequence state are not TWI-003 serialization allocations; BUG-043 owns
  their exact current save/load and recovery contract.
- Preview, replacement, deselection, rejection, pending, modal, and route cache
  state remain absent.
- Cross-owner invariants validate before installation.
- Historical reconstruction rejects an active identity whose dispositions or
  count is invalid and rejects a `GameState` aggregate containing more than one
  active ship identity; it does not repair from route, controller, or scene
  state. BUG-043 owns current active-execution relationship validation.
- A pre-Begin save contains the canonical opportunity but no Preview.
- A post-Begin save contains the complete current attack and committed adjacent
  owner state.
- A post-Skip save contains inactive current attack and the exact enclosing
  Skip result.
- Load derives route/action availability only after canonical installation.

#### Replay

- History records accepted semantic commands only.
- Preview/Replace/Deselect/Confirm gesture/pending state remain absent.
- Accepted Begin or Skip appears once in authoritative order.
- Replay validates format before command deserialization/application.
- Replay reconstructs initial canonical owners, then applies recorded commands;
  it does not synthesize activation, Begin, Skip, completion, or route repair.
- Duplicate, stale, reordered, or invalid commands reject consistently.

#### Networking and reconnect

- Only the authoritative host executes and accepts/rejects gameplay commands.
- Clients may Preview locally but SHALL not synthesize semantic commands or
  mutate canonical progress optimistically.
- Mirrored results preserve accepted command identity/order and the
  viewer-authorized canonical semantics required by the recipient. Passive
  peers need not own an identical authority-private representation and do not
  originate player decisions or automatic authoritative follow-up commands.
- State filtering preserves the recipient's canonical or canonically
  represented decision semantics while viewer affordances remain derived.
- Reconnect installs a validated host snapshot before projection/routing.
- Client-local Preview is not restored.
- Reconnect before Begin, after Begin, and after each Skip row derives the same
  opportunity/route as local and replay execution.
- Reconnect/save/load with Maneuver `OPEN` distinguishes absent active
  execution (fresh transient exploration from canonical speed) from matching
  active execution (resume unresolved mandatory consequences); `CONSUMED`
  reconstructs with no active execution.

No transport, RPC, session, or mixed-version architecture is added.

### 11.11 Legacy Authority Retirement In The Same Cutover

Before Slice 2 can pass, retire every superseded semantic write:

- scene/controller writes to `activated_this_round` or action completion;
- `GameManager` writes to Squadron Phase controller/count used as authority;
- `SquadronCommandResolver.use_activation()` as the budget owner;
- modal counters that consume command activations;
- modal/scene teardown that consumes a declaration or activation;
- `InteractionFlow` reads that authorize Begin/Skip or reconstruct canonical
  progress;
- cached Preview/range values used instead of Begin revalidation;
- automatic no-target teardown before accepted Skip;
- optimistic client mutation of declaration progress;
- post-load repair from scene, modal, resolver, or route payload; and
- any `InteractionFlow`, `ShipActivationState`, scene/controller, modal,
  resolver cache/counter, presentation route, `squadron_step_active`,
  `activation_step_id`, `current_step`, or general activation FSM authority for
  TWI-003's ADR-006 identity, dispositions, or count; and
- obsolete comments describing no-active Skip as universally non-mutating or
  scene teardown as semantic completion.

Retirement means delete the write or convert it to a one-way read/projection.
Do not leave a disabled branch, dual-write, bridge, fallback, or compatibility
mode.

### 11.12 Slice 2 Checkpoint

- [ ] Every supported context has one canonical opportunity/controller.
- [ ] Every Section 5.2 field is live, serialized, validated, and written only
  by its existing accepted command owner.
- [ ] The historical four-concept ADR-006 boundary is serialized only on
  `ShipInstance`, and `GameState` owns only aggregate/cross-fleet validation.
  The later fifth concept is outside this checkpoint and belongs to BUG-043.
- [ ] Stable ship-activation identity is assigned once by accepted semantic
  entry and remains unchanged until accepted terminal cleanup.
- [ ] Squadron-command follows its accepted lifecycle, including only the
  rule-permitted direct `UNREACHED -> CONSUMED` bypass.
- [ ] Current Maneuver commitment/completion is outside this historical
  checkpoint; BUG-043 alone requires `OPEN` with a matching active execution
  until exact-once completion performs `OPEN -> CONSUMED` after
  all mandatory consequences resolve; normal activation completion rejects
  Maneuver `UNREACHED` and `OPEN`.
- [ ] Exceptional termination clears the boundary without fabricating
  Maneuver consumption.
- [ ] Every derived/transient/prohibited fact remains non-authoritative.
- [ ] Preview/Begin gameplay parity passes for all pairings and contexts.
- [ ] BUG-005 inside/outside distance-1 evidence passes with distinct close
  range.
- [ ] Confirm still submits exactly one Begin for the final candidate.
- [ ] Begin fails closed without the enclosing opportunity.
- [ ] Begin commits all participating owners atomically and rolls all back on
  injected failure.
- [ ] All four no-active Skip rows pass with and without Preview.
- [ ] Automatic no-target progression occurs only after accepted Skip.
- [ ] Active/post-Begin Skip and Complete paths are unchanged.
- [ ] `CompleteSquadronActivationCommand` ordering after active attacks is
  unchanged.
- [ ] No scene, modal, resolver, `GameManager`, flow, projector, or client is a
  semantic owner.
- [ ] Save version is exactly 3 and version 2 rejects before body installation.
- [ ] Replay format and signed alias are exactly 5 and format 4 rejects before
  command deserialization/application.
- [ ] Save/load, replay, host/client mirror, filtering, reconnect, and
  projection reproduce every Begin/Skip outcome.
- [ ] Preview/Confirm and BUG-002 regression oracles remain unchanged.
- [ ] No architecture, authority, bug, Migration Assessment, or predecessor
  workbook changed.
- [ ] Focused, full regression, baseline trace, lint, and diff gates pass.

Failure invokes Section 14. There is no supported partially cut-over state.

## 12. Rollback Posture

Before Slice 2 semantic activation, Slice 1 may be reverted normally because
its substrate is behavior-inert and emits no new artifact format.

After Slice 2 activation:

- rollback means reverting the entire semantic cutover, not selected contexts;
- save version 3 and replay format 5 artifacts SHALL not be loaded or replayed
  by the pre-cutover implementation;
- post-cutover artifacts SHALL not be rewritten as version 2 or format 4;
- no old/new dual execution mode, reverse migration, field inference, or
  compatibility fallback is permitted;
- an unaccepted cutover is rolled back as one unit and its generated test
  artifacts are discarded; and
- an accepted cutover may be rolled back only with an explicit compatible
  deployment/data posture outside this workbook.

This uses existing compatibility owners. It creates no new rollback framework.

## 13. Verification And Exit Gate

The Exit Gate is not an implementation slice. It evaluates the completed
Slice 2 result and produces the implementation handoff.

### 13.1 Automated Evidence

The implementation SHALL run focused tests after each edited seam, then the
repository gates after the complete cutover:

```bash
./scripts/run_tests.sh
./scripts/run_baseline_traces.sh --all
bash scripts/lint_phase_k.sh
git diff --check
```

If the repository documents a more specific accepted invocation at execution
time, use it in addition to, not instead of, the gates above.

Evidence SHALL use production state owners, production commands, production
serialization, production filtering/projectors, and production network/replay
entry points. Helper-only tests do not satisfy an integration row.

Required command-sequence oracles include:

#### Confirmed declaration

1. transient selection/replacement creates no semantic history entry;
2. Confirm submits one Begin;
3. accepted Begin is recorded once;
4. no replacement Skip appears; and
5. later post-Begin history remains the existing protected sequence.

#### Declaration Skip

1. zero or more transient Preview interactions create no history entry;
2. one no-active Skip is submitted;
3. accepted Skip is recorded once;
4. the exact enclosing owners change once; and
5. the next route is projected without an extra completion or advancement
   command synthesized by scene teardown.

#### Rejected semantic command

1. command is submitted with stale/invalid controller, opportunity, identity,
   target, range, or order;
2. no participating owner changes;
3. no accepted semantic result/history entry is created;
4. no fallback command is synthesized; and
5. interaction is retained only if the canonical opportunity remains.

### 13.2 Required Automated Matrix

Automated evidence SHALL cover:

- all four attacker/defender pairings;
- ship, non-Rogue Squadron Phase, Rogue Squadron Phase, and ship-command
  squadron contexts;
- Preview creation, A -> B -> C replacement, deselection, illegal-selection
  preservation, Confirm, pending, accepted Begin, and rejected Begin;
- Skip with Preview and without Preview for every context row;
- wrong-controller, missing-opportunity, stale identity, duplicate sequence,
  reordered command, and injected atomic failure;
- automatic no-target accepted and rejected Skip;
- phase handoff, Rogue remaining movement, commanded-squadron remaining
  movement, another command activation, and Repair derivation;
- stable ship-activation identity initialization through each accepted entry
  route and unchanged identity through the activation;
- Squadron-command `UNREACHED -> OPEN -> CONSUMED` and each applicable-rules
  case that legitimately uses direct `UNREACHED -> CONSUMED`;
- no-active ship declaration Skip and normal Attack completion each opening
  Maneuver with `UNREACHED -> OPEN`;
- Maneuver commitment producing `OPEN` plus one matching active execution,
  the distinct RRG executed-maneuver event, mandatory consequence recovery and
  re-evaluation, and final exact-once completion producing `CONSUMED` with no
  active execution;
- speed-zero commitment executing without ordinary movement while retaining
  applicable consequence and destruction semantics;
- actual-final-position play-area destruction after ship-overlap
  placement/reduction, never destruction from the transient plotted preview;
- active-ship destruction and other accepted exceptional terminal coverage
  clearing the boundary without a fabricated Maneuver execution/consumption;
- equivalent canonical ownership and results for local human, remote human,
  replay/mirror, and controller-independent direct command paths;
- BUG-005 both outgoing pairings immediately inside and immediately outside
  distance 1 while still inside close range;
- pre-Begin, post-Begin, and every post-Skip save/load state;
- the same replay command order and canonical end state;
- hot-seat, host authority, client mirror, viewer filtering, reconnect, and
  scene recreation, including viewer-authorized passive representations that
  need not duplicate authority-private state;
- applicable timing-window inactivity/ownership boundaries under TEST-003;
- unchanged Preview/Confirm stabilization; and
- unchanged BUG-002 Step 6 and second-normal-attack behavior, including
  save/load, replay, host/client, and reconnect evidence.

### 13.3 Owner Manual-Test Checklist

After automated gates pass, provide a build for concise manual verification:

- ship-to-ship declaration: Preview, replace target/zone, Confirm, and resolve
  using the existing post-Begin path;
- ship-to-squadron declaration: Preview and Confirm;
- ship declaration Skip with no Preview and with Preview, reaching Maneuver;
- non-Rogue Squadron Phase attack Begin and Skip;
- Rogue attack-before-move Skip/Begin with movement still available;
- Rogue move-before-attack Skip/Begin with correct completion;
- ship-command squadron attack-before-move and move-before-attack;
- ship-command Skip with movement remaining, another commanded squadron, and
  transition to Repair when exhausted;
- squadron-to-squadron and squadron-to-ship target immediately inside distance
  1 accepted;
- both targets immediately outside distance 1 but inside close range rejected;
- rejected Begin and rejected Skip leave the declaration interactive;
- automatic no-target behavior advances only after accepted Skip;
- BUG-002 Victory Step 6 continuation against another eligible squadron;
- BUG-002 second normal attack from another legal hull zone;
- save/load before Begin, after Begin, and after each Skip outcome;
- host/client Confirm and Skip with equal canonical result; and
- reconnect before Begin, after Begin, and after Skip without restored Preview.

Manual presentation observations do not replace canonical state, command
history, or automated evidence.

### 13.4 Final Production-Verification Prerequisite

BUG-001 / NOTE-001 remains independent. Before final production network
save/load acceptance, its investigation must establish that loaded network
games restore session mode, host/client roles, authoritative submission,
mirrored results, replay recording, and relevant session metadata.

If it proves only a bootstrap/logging issue, TWI-003 architecture and semantic
scope remain unchanged and the missing production evidence is run after that
independent repair. If it proves a direct declaration-state dependency,
Section 14 applies before expanding this workbook.

### 13.5 Exit Gate Criteria

- [ ] Both implementation slices passed in order.
- [ ] The Section 15 acceptance matrix is fully mapped to exact automated
  evidence.
- [ ] All focused and full automated gates pass.
- [ ] Baseline traces have no unexplained semantic command drift.
- [ ] Structural searches find one writer per declaration fact.
- [ ] Structural searches find no prohibited field or legacy authority.
- [ ] Save/replay exact-version tests pass.
- [ ] Manual-test build and checklist are ready for the Owner.
- [ ] The implementation report lists files changed, tests, command oracles,
  artifact versions, and any independent production-verification hold.
- [ ] No out-of-scope file changed.

The implementation is ready for Owner manual testing when all criteria except
the separately identified BUG-001 production-network item pass. Final
production network save/load acceptance remains held until that prerequisite is
resolved.

## 14. Single Mandatory Stop List

Implementation SHALL stop, preserve the current passing checkpoint, and report
the exact evidence when any of the following occurs:

- TWI-002 production activation is incomplete;
- reconciled BUG-043 is incomplete and cannot be safely sequenced before or
  atomically with Slice 2 while the production baseline still uses pre-commit
  canonical SetSpeed mutation or direct execution-to-consumption;
- pre-cutover save/replay constants are not exactly 2 and 4;
- a required durable fact has no existing accepted owner and cannot be derived;
- ADR-006 is not Accepted, no longer assigns the five-concept boundary solely to
  `ShipInstance`, or conflicts with another accepted authority;
- a conflicting canonical owner of the ADR-006 activation boundary exists;
- an existing semantic transition boundary required by Sections 6.3, 7, or
  11.4 cannot be identified;
- implementation would require `activation_step_id`, a general ship activation
  FSM, `current_step`, generic step progression, a generic Maneuver lifecycle
  enum/stack/queue/continuation owner, or new predecessor policy;
- TWI-003 declaration work would require implementing or redesigning the
  complete Navigate, movement, overlap, consequence, or play-area-destruction
  behavior rather than preserving the accepted adjacent boundary;
- implementation would require storing a derived field, freezing
  Squadron-command capacity, or duplicating an owner;
- Slice 1 would need a live production reference, serializer, command, policy,
  projection, or resolver change;
- Slice 2 cannot cut over all supported contexts and distribution modes as one
  semantic model;
- atomic Begin or Skip rollback cannot restore every participating owner;
- Preview and Begin cannot share equivalent accepted gameplay semantics;
- BUG-005 cannot be corrected without changing accepted edge measurement or
  range/distance authority;
- declaration work would require changing active attack completion,
  cancellation, replacement, Step 6, second-attack continuation, or other
  post-Begin ordering;
- `CompleteSquadronActivationCommand` would have to change when an active attack
  completes rather than only consume the existing closure result;
- a scene, modal, resolver cache, `GameManager`, flow payload, projector, or
  client would remain a gameplay owner;
- a compatibility layer, dual-write, fallback, artifact reinterpretation, new
  transport, or automatic version allocation would be required;
- an accepted ADR, Contract, TEST document, or MA-ATTACK-002 outcome conflicts
  with the planned edit;
- a checkpoint, required automated category, or protected regression fails and
  cannot be corrected inside the current slice; or
- BUG-001 proves a direct declaration-state dependency not already represented
  by accepted authority.

No stop may be bypassed with UI state, `InteractionFlow`, scene teardown,
synthetic commands, default initialization, test-only production branches, or
fixture regeneration.

## 15. Contract-ID Binary Acceptance Matrix

Each row is binary. “Pass” means the implementation report names exact tests
and all named evidence passes. Missing, deferred, manual-only, or helper-only
evidence is Fail unless the row explicitly calls for Owner manual testing.

| Authority IDs | Required implementation outcome | Pass condition |
| --- | --- | --- |
| CON-006-LIFE-001--004 | Declaration starts with inactive current attack and one transient candidate at most. | Canonical state/cursor unchanged by Preview, replacement, deselection, and illegal selection. |
| CON-006-LIFE-005--008 | Begin/Skip pending is at most one and rejection is non-mutating. | Local and network concurrent/rejected tests preserve owners and interaction. |
| CON-006-LIFE-009--012 | Begin/Skip commit atomically; scene destruction and replacement are non-semantic. | Atomic failure and scene-recreation tests pass; no replacement Skip in history. |
| CON-006-AUTH-001--004 | Every fact maps to one accepted owner; caches remain derived. | Section 5 mapping matches production writes; prohibited-field searches are empty. |
| CON-006-PREV-001--005 | Preview is derived, complete, transient, and command-free. | All pairings/contexts project current facts with no canonical/history mutation. |
| CON-006-REPLACE-001--004 | Replacement is one transient overwrite. | A -> B -> C yields only C and no semantic command. |
| CON-006-DESELECT-001--004 | Deselect removes only target candidate and disables Confirm. | Attacker context remains; no owner/history changes. |
| CON-006-ILLEGAL-001--005 | Illegal attempts reject deterministically and preserve legal Preview. | Rejection-category and candidate-preservation tests pass. |
| CON-006-PARITY-001--007 | Preview and Begin agree on gameplay legality; Begin revalidates. | Shared parity matrix passes; transaction-only rejections are classified separately. |
| CON-006-CONFIRM-001--006 | One complete candidate is required; one Confirm submits one Begin; pending is transient. | Cursor/history and pending tests pass locally and on network. |
| CON-006-BEGIN-001--004 | Begin validates every applicable authority-matrix fact and policy surface. | Direct command tests reject missing route-independent facts and misleading UI/flow. |
| CON-006-BEGIN-005--010 | Begin is one atomic transaction, consumes once, and performs no resolution. | Owner snapshots, complete current attack, one history entry, and unchanged roll/resolution state. |
| CON-006-BEGIN-011--012 | Failed Begin changes nothing and never fabricates opportunity. | Failure injection and changed-opportunity routing tests pass. |
| CON-006-SKIP-001--007 | No-active Skip is persisted, exactly once, Preview-independent, atomic, and limited. | With/without Preview and failure tests pass for every row. |
| CON-006-SKIP-008--011 | Active/unsupported/stale Skip is outside or rejects without declaration mutation. | Protected active Skip behavior and direct invalid submissions remain unchanged. |
| CON-006 section 11.2 | Exact ship, non-Rogue, Rogue, and command-squadron effects. | State, route, replay, persistence, and duplicate-rejection assertions pass per row. |
| CON-006-FLOW-001--012 | Routing remains available, then derives from accepted Begin/Skip; UI owns nothing. | Missing/stale flow payload cannot authorize; rejection/acceptance projection tests pass. |
| CON-006-DET-001--007 | Equivalent authoritative inputs/order produce equivalent accepted results; no inference or repair. | Local, host, viewer-authorized mirror, replay, save/load, and reconnect semantic/command oracles agree without requiring identical authority-private representation. |
| CON-006-SER-001--006 | Only accepted Begin/Skip results serialize; Preview never does. | Pre-Begin, post-Begin, and all post-Skip round trips pass. |
| CON-006-RECON-001--005 | Reconstruction restores canonical opportunity/result before routing. | Save/load and reconnect matrix passes without Preview or scene authority. |
| CON-006-COMPAT-001--006 | Compatibility is fail-closed and never creates a second owner/mode. | Version 2 save rejects under version 3 before installation; invalid cross-owner state rejects. |
| CON-006-REPLAY-001--007 | Replay records accepted commands only and reproduces exact end state. | Format 4 rejects under format 5 before application; format 5 sequence/state matrix passes. |
| CON-006-NET-001--008 | Host authority and mirrors apply the same accepted order; clients do not synthesize. | Host/client canonical equality, rejection, pending, and filtering tests pass. |
| CON-006-RECONNECT-001--004 | Reconnect restores canonical pre/Begin/Skip state and no local Preview. | Production reconstruction/filter tests pass for all supported contexts. |
| CON-006-MIG-001--002 | Slice 1 is behavior-inert. | Zero live references, unchanged formats, unchanged command traces, and direct owner tests pass. |
| CON-006-MIG-003--006 | Slice 2 is an explicit complete semantic cutover with one owner. | All contexts/modes cut over together and all legacy writes are retired. |
| CON-006-MIG-007--011 | Rollback/compatibility are explicit and no temporary flow remains. | Section 12 posture is evidenced; searches find no bridge or dual-write. |
| CON-006-TEST-001--012 | Every applicable obligation has production-representative evidence. | This matrix maps to exact passing tests and the live-route suite. |
| ADR-001; CON-001 lifecycle/membership/atomicity | One complete canonical current attack; adjacent facts remain referenced owners. | Begin/rollback/membership tests pass and no enclosing fact is copied into current attack. |
| ADR-003; CON-003 | Rule and resolver responsibilities remain on accepted surfaces. | Applicability/rule/query agreement tests pass; no CAP status or rule owner changes. |
| ADR-004; CON-004 | Runtime-upgrade ownership is unchanged. | Structural diff and existing runtime-upgrade tests show no migration. |
| ADR-005; CON-005; TEST-003 | Ordinary declaration does not synthesize timing lifecycle or continuation. | Applicable ownership, reconstruction, replay, network, projection, and visibility tests pass. |
| ADR-006; ADR-010; SAI-060--065; SMI-001--091 | TWI-003 historically integrated the identity, dispositions, and committed count. Later Maneuver execution-record and consequence semantics remain binding but belong only to BUG-043. | Historical declaration owner/write evidence remains valid; BUG-043 owns current Maneuver lifecycle, recovery, Network, speed-zero, destruction, and no-generic-FSM evidence. |
| MA-ATTACK-002 BUG-005 outcome | Outgoing squadron declaration enforces distance 1, not close range. | Both pairings pass inside/outside tests with distinct production thresholds through Preview and Begin. |
| MA-ATTACK-002 completed baseline | Preview/Confirm and BUG-002 behavior is preserved. | Protected regression files pass with unchanged post-Begin semantic command oracles. |
| MA-ATTACK-002 exclusions | BUG-003, BUG-004, active completion, and unrelated cleanup are unchanged. | Diff scope and protected tests show no excluded behavior change. |

## 16. Historical Audit Closure And Current Status

### 16.1 BLOCKING Finding Closure

| Audit finding | Closure |
| --- | --- |
| The original workbook invented a complete serialized ship activation FSM and predecessor policy. | The historical cutover prohibited `activation_step_id`, `current_step`, and general step policy and implemented four purpose-specific activation-boundary concepts. Amended ADR-006's fifth concept is allocated only by BUG-043 without generic lifecycle infrastructure. |
| The pre-ADR-006 Entry Gate required pre-existing canonical owners for post-Skip Maneuver and the active Squadron-command opportunity and therefore stopped when those fields were absent. | Accepted ADR-006 supplied the `ShipInstance` owner used by the historical slices. Current Maneuver record ownership is separately fixed by amended ADR-006 and allocated by BUG-043. |
| The original save 1 -> 2 and replay 3 -> 4 allocation collided with accepted TWI-002. | The historical cutover correctly used pre-cutover 2/4 and emitted 3/5. Section 8 clearly marks those values historical and records the current 6/9/6 baseline. |

Every historical BLOCKING audit finding was resolved in the specification used
for the production cutover. No current Entry Gate run is authorized.

### 16.2 HIGH Finding Closure

| Audit finding | Closure |
| --- | --- |
| Proposed fields mixed stored, derived, transient, and duplicate facts. | Section 5 classifies every TWI-003 field exactly once; `attack_step_active` remains existing stored state, while `activation_step_id`, `squadron_step_active`, serialized capacity, `activation_progress_active`, and `activation_round` are not added. |
| Capacity was frozen at step entry without authority. | Sections 5.3 and 11.4 require capacity to be re-derived from current accepted resource/rule owners. Only committed use count is stored. |
| Multiple preparation slices permitted ambiguous dormant production logic. | Section 10 is the only behavior-inert slice and allows only owner fields/pure operations with zero live references; no dormant command, policy, resolver, serializer, or projection code is permitted. |
| The semantic cutover and cleanup were split. | Section 11 is the only semantic slice and includes all live integration, compatibility activation, and legacy authority retirement. |
| Post-Begin scope and `CompleteSquadronActivationCommand` were ambiguous. | Sections 2.3, 4.6, 7, 11.4, 11.8, and 14 permit only enclosing-action closure consumption and prohibit changes to active completion, ordering, continuation, and submission. |
| Internal references were broken or pointed to obsolete section numbers. | All internal references now target Sections 2, 4, 5, 7--16, and all authority/predecessor links use paths valid from this workbook directory. |

Every HIGH audit finding is resolved.

### 16.3 MEDIUM Finding Closure

| Audit finding | Closure |
| --- | --- |
| The former Slice 1 was baseline work rather than an implementation boundary. | Section 9 makes baseline/authority proof an Entry Gate, explicitly not a slice. |
| Expected-failure and preparation language made behavior-inert state unclear. | Section 10 defines the exact permitted files, methods, zero-live-reference rule, unchanged artifact formats, and binary checkpoint. |
| A separate legacy-retirement slice added no coherent semantic boundary. | Legacy retirement is Section 11.11 inside the one semantic cutover; Section 13 is an Exit Gate, not a slice. |
| The workbook was repetitive and too long. | The structure is reduced to one authority summary, one scope/exclusion boundary, one field classification, one seam-risk table, one compatibility allocation, one rollback posture, one stop list, two slices, two gates, and one contract-ID acceptance matrix. |

Every MEDIUM audit finding is resolved.

### 16.4 Historical Execution Record

The accepted sequence was Entry Gate, behavior-inert Slice 1, its checkpoint,
atomic semantic Slice 2, its checkpoint, and Exit Gate. Commits `440b670` and
`7cfa47b` demonstrate that the two implementation slices entered the current
production lineage. This sequence is retained for auditability and SHALL NOT be
run again.

### 16.5 Current Status Verdict

TWI-003 is **not an active implementation workbook**. Its implemented
declaration architecture remains authoritative where not superseded. Its
historical compatibility allocations are not current cutover instructions.

The original post-checkpoint baseline renewal and Owner manual verification
cannot be confirmed from the repository evidence reviewed for this
reconciliation. They remain independent historical closure evidence debt; they
do not authorize production changes and they do not block BUG-043's bounded
Maneuver work.

TWI-003 owns no current Maneuver record, transaction, consequence, recovery,
version, fixture, or verification allocation. BUG-043 alone owns that current
semantic cutover. No new architecture decision or Owner decision is required
to interpret TWI-003's present status.

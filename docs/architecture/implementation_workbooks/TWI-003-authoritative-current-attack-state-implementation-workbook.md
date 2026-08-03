# TWI-003: Authoritative CurrentAttackState Implementation Workbook

Status: Accepted

Purpose: Implementation Workbook
Accepted by: Project Owner
Accepted date: 2026-08-03

TWI-003 is the accepted implementation specification for the remaining authoritative attack-declaration migration, subject to its Entry Gate, stop conditions, and the authority of the referenced ADRs, Contracts, Migration Assessment, and TEST documents.

Source: MA-ATTACK-002 -- Post-Stabilization CON-006 Compliance Assessment

Implementation boundary: supported attack declaration from an authoritative
declaration opportunity through one accepted `BeginAttackCommand` or one
accepted no-active declaration `SkipAttackCommand`

## 1. Authority And Workbook Role

TWI-003 is the implementation counterpart to
[MA-ATTACK-002](../migration_assessments/MA-ATTACK-002-post-stabilization-con-006-compliance.md).
It translates that accepted repository evidence into one deterministic
implementation specification. It does not reassess the repository, create
architecture, or authorize implementation by itself.

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
override the authorities above. TWI-003 executes only after the TWI-002
production-activation compatibility checkpoint described in Section 8.

The completed TWI-003 Architecture Audit Report supplied for this refinement is
review evidence. Its BLOCKING, HIGH, and MEDIUM findings are resolved by this
workbook as summarized in Section 16.

This document remains:

- an implementation workbook;
- subordinate to accepted ADRs and Contracts;
- Draft pending Project Owner review; and
- the sole implementation specification for the migration once accepted.

It is not:

- an ADR, Contract, TEST document, Migration Assessment, or CAP;
- an authority for changing accepted ownership;
- a general ship-activation finite-state-machine specification;
- a post-Begin attack-resolution specification; or
- the historical assessment named MA-ATTACK-001.

If this workbook and an accepted authority conflict, the accepted authority
wins and Section 14 applies.

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
| Ship declaration opportunity and attack progress | Existing serialized `ShipInstance` activation-local state together with the accepted canonical enclosing ship-activation state | Preserve existing attack fields; bind Begin/Skip to the accepted enclosing owner discovered at Entry Gate. |
| Squadron activation and action progress | Existing serialized `SquadronInstance` and accepted enclosing activation state | Add the minimum irreducible action history to `SquadronInstance`; derive availability. |
| Ship Squadron-command use progress | Existing `ShipInstance` activation-local/Squadron-command responsibility surface | Store committed use count only; derive capacity from existing authoritative resources and rules. |
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

### 3.2 Non-Owners

The following remain non-authoritative:

- `AttackExecutor` and all attack scene state;
- `ShipActivationController` and `SquadronPhaseController`;
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

### 3.3 Prohibited Shapes

The implementation SHALL NOT introduce:

- a declaration-state object or serialized declaration-opportunity record;
- a general serialized ship activation FSM or general predecessor policy;
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
| Ship Activation Attack Step | Consume the current ship declaration opportunity, preserve hull-zone and target history, leave `CurrentAttackState` inactive, and move authoritative enclosing progress to the existing Maneuver boundary. | Ship Activation Maneuver route derived from the accepted owner. |
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
| `squadron_command_activations_committed` | `ShipInstance` activation-local Squadron-command state | Count of accepted commanded-squadron activations for the active command opportunity; incremented exactly once by accepted activation commitment and cleared at the accepted enclosing reset boundary. |

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
| Ship is in its Squadron command opportunity | Existing accepted canonical enclosing ship-activation/Squadron-command owner identified at Entry Gate. |
| Squadron-command capacity | Current authoritative ship dial/token/static squadron value and accepted command/rule semantics at validation time. |
| Squadron-command remaining activations | Derived capacity minus stored committed count, constrained by current authoritative resource and eligibility state. |
| Ship post-Skip Maneuver availability | Existing accepted canonical enclosing ship-activation owner identified at Entry Gate. |
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
- filtered/projected network payloads.

None serialize as gameplay authority or write back into canonical owners.

### 5.5 Prohibited Duplicate Fields

The implementation SHALL NOT add or preserve as a second writable fact:

| Prohibited field/shape | Reason |
| --- | --- |
| `activation_step_id` spanning all ship steps | General ship activation FSM and predecessor policy are outside the accepted declaration scope. |
| new stored `squadron_step_active` | Duplicates the accepted enclosing ship/Squadron-command state. |
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

Only existing replayable semantic transitions may reset TWI-003 state:

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
- `AdvanceActivationStepCommand` remains the sole existing owner of
  `ShipInstance.begin_attack_step()` initialization; and
- the accepted existing enclosing ship-activation owner performs any required
  declaration-adjacent ship step mutation.

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
| Ship command progress: `src/core/state/ship_instance.gd` | Preserve BUG-002 fields; add committed Squadron-command use count only if Entry Gate confirms the accepted owner. | High: accidental BUG-002 reset or duplicate capacity. | Field classification search and full BUG-002 regression suite. |
| Current attack: `src/core/state/current_attack_state.gd` | Normally unchanged; only existing validation/reference use is allowed. | High: enclosing state copied into current attack. | Membership and serialization shape tests. |
| Phase entry/exit: `src/core/commands/advance_phase_command.gd`, `src/core/commands/status_phase_cleanup_command.gd` | Initialize/clear the new phase/action progress only within existing transactions. | Medium: scene still controls turn. | Command sequence and save/load phase tests. |
| Ship step entry: `src/core/commands/advance_activation_step_command.gd` | Preserve sole `begin_attack_step()` initialization; integrate only with an accepted existing enclosing owner, never add a general FSM. | Blocking if owner absent. | Entry Gate owner map; structural search for all ship-step writes. |
| Squadron activation/action: `src/core/commands/activate_squadron_command.gd`, `move_squadron_command.gd`, `complete_squadron_activation_command.gd` | Validate context/controller/identity, commit action history, and coordinate existing enclosing count/closure. | High: command-mode and phase-mode behavior diverge; post-Begin completion ordering drifts. | Context matrix and explicit post-Begin regression oracles. |
| Declaration commands: `src/core/commands/begin_attack_command.gd`, `skip_attack_command.gd` | Complete context validation and atomic mutation; preserve active/out-of-scope branches. | High: partial owner mutation or fallback initialization. | Failure injection, snapshots, command history, and active-branch regression. |
| Applicability/policy: `src/core/commands/command_applicability.gd`, `src/core/state/flow_spec.gd` | Make broad phase policy agree with concrete opportunity/controller validation. | Medium: flow becomes authority. | Direct submission tests with misleading/missing flow payloads. |
| Declaration resolver: `src/core/combat/targeting_list_builder.gd`, `src/core/combat/attack_target_resolver.gd`, `src/autoload/game_scale.gd`, accepted rule surfaces | Establish Preview/Begin parity and BUG-005 distance-1 classification; do not change edge measurement. | High: range and distance remain conflated. | Production-scale inside/outside distance-1 tests including the close-only interval. |
| Squadron-command adapter: `src/core/combat/squadron_command_resolver.gd` | Read capacity/use from authoritative owners; stop owning `_max_activations`/`_activations_used` semantically. | High: hidden mutable budget survives. | Search all reads/writes; destroy/recreate resolver mid-step. |
| Selector/executor: `src/scenes/game_board/target_selector.gd`, `attack_executor.gd` | Preserve Preview/Confirm/pending; consume accepted results one-way. | High: scene cache authorizes or consumes. | Preview command-cursor, rejection, and scene-recreation tests. |
| Activation controllers/modals: `src/scenes/game_board/ship_activation_controller.gd`, `squadron_phase_controller.gd`, `src/ui/combat/squadron_activation_modal.gd`, `src/scenes/game_board/modal_router.gd` | Replace gameplay writes/counters with queries and result-driven presentation. | High: scene lifecycle owns progress. | Direct command/replay plus teardown/reopen tests. |
| Application routing: `src/autoload/game_manager.gd`, `src/scenes/game_board/game_board.gd`, `src/core/state/interaction_flow.gd` | Derive controller/route from canonical owners; keep caches one-way. | High: load currently trusts route/controller payloads. | Reconstruction with absent/stale route and canonical-state assertions. |
| Projection/filtering: `src/core/network/ui_projector.gd`, `src/core/network/state_filter.gd` | Project new canonical state without authorizing commands. | Medium: filter drops required state or client synthesizes. | Viewer, host/client hash, reconnect, and direct-invalid-command tests. |
| Save/load: `src/core/state/save_game_metadata.gd`, `src/autoload/save_game_manager.gd` | Activate new fields and version 3 only in Slice 2. | High: collision with TWI-002 or partial reconstruction. | Exact pre-cutover version check, unsupported-version rejection, round-trip matrix. |
| Replay: `src/core/commands/game_replay.gd`, `src/autoload/replay_driver.gd`, command registrations | Activate format 5 only in Slice 2; preserve semantic command order and no Preview records. | High: collision or legacy reinterpretation. | Exact format gate before command application and sequence oracle. |
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

## 8. Execution Dependency And Compatibility Allocation

TWI-002 has accepted production-activation allocations:

- `SaveGameMetadata.CURRENT_VERSION`: 1 -> 2; and
- `GameReplay.FORMAT_VERSION`: 3 -> 4, with the signed format alias following
  the same semantic format.

TWI-003 therefore has this fixed execution dependency:

1. TWI-002 production activation is implemented and its compatibility gate has
   passed.
2. Immediately before TWI-003 Slice 1 begins, the repository emits save
   version 2 and replay format 4.
3. Slice 1 preserves version 2 and format 4.
4. TWI-003 Slice 2 atomically advances save version 2 -> 3 and replay format
   4 -> 5 with the declaration semantic cutover.
5. Save version 3 and replay format 5 are the sole post-TWI-003 formats.

The implementer SHALL inspect the actual constants and focused compatibility
tests immediately before Slice 1 and again immediately before Slice 2. The
expected pre-cutover values are exactly 2 and 4. If either actual value differs,
or TWI-002 production activation is incomplete, Section 14 applies. The
implementer SHALL NOT select another value automatically, reuse a value,
reinterpret an artifact, or edit TWI-002.

No TWI-003 version change occurs in Slice 1. Slice 1 fields remain at inactive
defaults and are not connected to production serialization until Slice 2.

At Slice 2, `SaveGameMetadata.CURRENT_VERSION` becomes 3. The existing save
loader accepts version 3 and rejects version 2 as unsupported before installing
the body. It does not infer missing declaration-adjacent state or migrate a
version-2 body.

At the same cutover, `GameReplay.FORMAT_VERSION` becomes 5 and the signed
format constant remains the accepted alias of that same value. Replay loading
accepts format 5 only and rejects format 4 before command deserialization or
application. It does not relabel or reinterpret format-4 history.

Reconnect remains a same-semantic-build snapshot path rather than a durable
artifact-format migration. A stale or contradictory cross-cutover snapshot
fails canonical validation before projection or routing. No mixed
pre-cutover/post-cutover network session is supported.

## 9. Entry Gate -- Authority And Baseline Proof

The Entry Gate is not an implementation slice. It authorizes no semantic or
production edit.

### 9.1 Required Read-Only Record

Before Slice 1, record in the implementation report:

- current revision and worktree status;
- all pre-existing changes that must be preserved;
- exact save and replay format constants;
- evidence that the TWI-002 production-activation checkpoint is present;
- every production write to the fields in Section 5;
- every live submission of Begin, no-active Skip, squadron activation,
  squadron movement, squadron completion, phase advance, ship-step advance,
  and round cleanup;
- the concrete accepted owner of the ship post-Skip Maneuver fact;
- the concrete accepted owner of the active ship Squadron-command opportunity;
- the existing command path that mutates each owner;
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

The gate may run already-existing passing tests, but it SHALL add no test,
disabled test, expected-failure test, or retained-for-later test. The baseline
must be clean for TWI-003 production files; any unrelated pre-existing change
must be identified, non-overlapping, and preserved.

### 9.2 Entry Gate Criteria

- [ ] The required startup and authority documents were read.
- [ ] The TWI-003 production baseline is clean; unrelated non-overlapping
  worktree changes are recorded and protected.
- [ ] TWI-002 production activation is present and passing at its accepted gate.
- [ ] Save version is exactly 2.
- [ ] Replay format is exactly 4 and signed format is the accepted alias.
- [ ] Each irreducible fact in Section 5.2 maps to the listed existing owner.
- [ ] The existing accepted ship owner for post-Skip Maneuver is identified.
- [ ] The existing accepted owner for the ship Squadron-command opportunity is
  identified.
- [ ] No required durable declaration fact lacks an accepted owner.
- [ ] Existing command paths can mutate all required owners atomically without
  introducing a new semantic command type solely for TWI-003.
- [ ] Protected baseline tests and semantic command oracles are identified.
- [ ] No implementation edit has occurred.

Failure of any criterion invokes the single stop list in Section 14.

## 10. Slice 1 -- Behavior-Inert Canonical Substrate

### 10.1 Classification And Objective

Slice 1 is the only Implementation Slice. It prepares owner-local data
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
   activation-count fields plus owner-local invariant and snapshot operations.
2. `SquadronInstance` may declare inactive/default activation identity,
   context, commanding-ship reference, movement-use, and attack-disposition
   fields plus owner-local invariant, snapshot, restore, remaining-action, and
   reset operations.
3. `ShipInstance` may declare an inactive/default committed
   Squadron-command activation count plus owner-local invariant, snapshot,
   restore, and reset operations.
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
- no route or `GameManager` field is consulted.

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

- committed command activation count is non-negative;
- the count itself does not assert that a Squadron command step is active;
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

## 11. Slice 2 -- Complete Authoritative Declaration Cutover

### 11.1 Classification And Objective

Slice 2 is the only Semantic Slice. It is one indivisible cutover across live
local play, authoritative host execution, client mirroring, projection,
serialization, save/load, replay, reconnect, and tests.

Its objective is to activate the complete Section 4 behavior, remove every
superseded gameplay write in the same slice, and leave exactly one semantic
model. No context may cut over independently.

### 11.2 Preconditions

- The Entry Gate and Slice 1 checkpoint pass.
- The accepted owners for ship post-Skip Maneuver and the active ship
  Squadron-command opportunity are recorded.
- Save version remains exactly 2 and replay format remains exactly 4.
- Every live call site in Section 7 is identified.
- Every required focused and regression test has an exact test-file home.
- No compatibility dual-write or fallback is required.

### 11.3 Activate Canonical Serialization First Within The Atomic Change

As part of the same unmerged cutover change:

- connect the Section 5.2 fields to their existing owner serializers,
  deserializers, validators, clones, snapshots, filters, and projectors;
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
`attack_step_active` together with the accepted canonical enclosing
ship-activation owner identified at Entry Gate. `InteractionFlow == ATTACK_STEP`
alone SHALL never establish the opportunity.

Accepted ship declaration Skip SHALL mutate only the declaration-adjacent
facts assigned by CON-006: consume the active ship Attack-step opportunity and
move the accepted enclosing owner to its existing Maneuver boundary. It SHALL
preserve hull-zone use and target history and leave `CurrentAttackState`
inactive. TWI-003 SHALL not define how any other ship activation step precedes
or follows another.

#### Ship-Phase Squadron Command

The accepted existing ship Squadron-command owner identified at Entry Gate
SHALL establish the opportunity and controller. Capacity is re-derived for
every validation from current ship dial/token/static squadron value and
accepted rule facts.

`ActivateSquadronCommand` in command context SHALL validate:

- Ship Phase and the accepted active Squadron-command opportunity;
- commanding ship stable identity and controller;
- current authoritative dial/token/rule-derived capacity;
- stored committed count is below that capacity;
- selected squadron range and ownership eligibility;
- selected squadron is not already active or activated this round; and
- a fresh activation identity.

Acceptance atomically initializes the squadron action state and increments the
commanding ship's committed activation count once. Merely selecting or
replacing a modal candidate consumes no count.

`SquadronCommandResolver` SHALL become a read-only adapter over those owners.
Its cached `_max_activations` and `_activations_used` SHALL not authorize,
consume, serialize, restore, or repair budget. Existing dial/token spend
commands retain their accepted ownership and order.

When a commanded squadron closes, `CompleteSquadronActivationCommand` may
validate and close its action state. Existing coordinating code derives
remaining movement, another squadron activation, or the existing Repair
boundary from canonical state. It SHALL not change any active attack's
completion or post-Begin ordering.

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
- Preview, replacement, deselection, rejection, pending, modal, and route cache
  state remain absent.
- Cross-owner invariants validate before installation.
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
- Mirrored results preserve host command identity/order and canonical fields.
- State filtering preserves all gameplay facts required by the recipient while
  viewer affordances remain derived.
- Reconnect installs a validated host snapshot before projection/routing.
- Client-local Preview is not restored.
- Reconnect before Begin, after Begin, and after each Skip row derives the same
  opportunity/route as local and replay execution.

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
- obsolete comments describing no-active Skip as universally non-mutating or
  scene teardown as semantic completion.

Retirement means delete the write or convert it to a one-way read/projection.
Do not leave a disabled branch, dual-write, bridge, fallback, or compatibility
mode.

### 11.12 Slice 2 Checkpoint

- [ ] Every supported context has one canonical opportunity/controller.
- [ ] Every Section 5.2 field is live, serialized, validated, and written only
  by its existing accepted command owner.
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
- BUG-005 both outgoing pairings immediately inside and immediately outside
  distance 1 while still inside close range;
- pre-Begin, post-Begin, and every post-Skip save/load state;
- the same replay command order and canonical end state;
- hot-seat, host authority, client mirror, viewer filtering, reconnect, and
  scene recreation;
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
- pre-cutover save/replay constants are not exactly 2 and 4;
- a required durable fact has no existing accepted owner and cannot be derived;
- the accepted canonical owner of ship post-Skip Maneuver cannot be identified;
- the accepted canonical owner of the active ship Squadron-command opportunity
  cannot be identified;
- implementation would require `activation_step_id`, a general ship activation
  FSM, or new predecessor policy;
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
| CON-006-DET-001--007 | Identical inputs/order produce identical results; no inference or repair. | Local, host, mirror, replay, save/load, and reconnect state/command oracles agree. |
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
| MA-ATTACK-002 BUG-005 outcome | Outgoing squadron declaration enforces distance 1, not close range. | Both pairings pass inside/outside tests with distinct production thresholds through Preview and Begin. |
| MA-ATTACK-002 completed baseline | Preview/Confirm and BUG-002 behavior is preserved. | Protected regression files pass with unchanged post-Begin semantic command oracles. |
| MA-ATTACK-002 exclusions | BUG-003, BUG-004, active completion, and unrelated cleanup are unchanged. | Diff scope and protected tests show no excluded behavior change. |

## 16. Audit Closure And Implementation Readiness

### 16.1 BLOCKING Finding Closure

| Audit finding | Closure |
| --- | --- |
| The original workbook invented a complete serialized ship activation FSM and predecessor policy. | Sections 2.3, 3.3, 5.3, 5.5, 6.3, 9, 11.4, and 14 remove `activation_step_id`, prohibit general step policy, limit work to declaration-adjacent facts, and require CON-006-AUTH-003 stop if the existing post-Skip or Squadron-command owner is absent. |
| The original save 1 -> 2 and replay 3 -> 4 allocation collided with accepted TWI-002. | Section 8 makes TWI-002 production activation an execution dependency, requires exact pre-cutover values 2/4, allocates TWI-003 values 3/5, and stops on any mismatch instead of guessing. |

Every BLOCKING audit finding is resolved in the specification. The actual
repository must still satisfy the Entry Gate before implementation can begin.

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

### 16.4 Deterministic Execution Summary

The only permitted execution sequence is:

1. pass the Entry Gate without edits;
2. implement Slice 1 owner-local substrate;
3. pass the Slice 1 checkpoint;
4. implement Slice 2 as one complete semantic cutover;
5. pass the Slice 2 checkpoint;
6. pass the Exit Gate and prepare Owner manual testing; and
7. hold only final production network save/load acceptance if the independent
   BUG-001 prerequisite remains unresolved.

There are exactly two implementation slices. Entry Gate and Exit Gate are not
slices.

### 16.5 Readiness Verdict

TWI-003 is implementation-ready as a deterministic Draft specification only
after Project Owner acceptance and only when the Entry Gate passes.

At the repository baseline reviewed for this refinement, two entry facts must
be demonstrated rather than assumed:

- TWI-002 production activation must supply save version 2 and replay format 4;
  and
- the existing accepted canonical owners for ship post-Skip Maneuver and the
  active ship Squadron-command opportunity must be identifiable.

If those facts are absent, CON-006-AUTH-003 requires a stop for Project Owner
guidance. The implementer may not solve that stop by restoring the removed
general activation FSM or by treating `InteractionFlow` as authoritative.

Subject to that gate, no other architecture or contract-shaping decision is
left to the implementer. Private helper names and exact placement of a test in
an already-listed test file may follow repository conventions only when the
owner, behavior, artifact allocation, scope, and binary evidence remain exactly
as specified here.

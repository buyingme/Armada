# ODR-002-CON-007 Composed-Return Convergence Contract Refinement Workbook

**Status:** Accepted decision execution workbook
**Decision basis:** Accepted ODR-002, applying accepted ODR-001
**Target:** Minimal additive refinement of accepted CON-007
**Contract-edit authorization:** Contract refinement only; no production implementation is authorized by this workbook.

Accepted by: Project Owner
Accepted date: 2026-08-22

## 1. Purpose and accepted architectural basis

This workbook is the execution specification for a future, surgical edit to
`CON-007-post-attack-continuation-release-contract.md`. It translates the
accepted ODR-002 refinement direction into contract-edit instructions. It does
not amend CON-007 until the Owner accepts the resulting contract change.

The refinement makes CON-007 the first explicit, narrow adopter of the
ODR-001 composed-return convergence principle at the post-Attack release
boundary. Its required observable result is that a post-Attack release does
not leave gameplay at an unresolved intermediate child completion. Evaluation
must continue through the applicable existing purpose-specific owners until it
reaches a stable outcome.

The accepted architectural basis, in applicable authority order, is:

- CON-007, whose completed-result inspection, exact-once release, supported
  contexts, and CommandProcessor seam remain the governing contract boundary;
- CON-006, which retains attack-declaration ownership and `BeginAttackCommand`
  / `SkipAttackCommand` semantics;
- ADR-001, which retains `GameState` / `CurrentAttackState` ownership and
  replayable-command semantic mutation;
- ADR-007, which retains purpose-specific completed-result inspection and the
  existing enclosing continuation path as owner of the next transition;
- ADR-010 and Ship Activation requirements SAI-001 and SAI-050, which require
  recoverable decision-equivalent continuation semantics and leave the
  enclosing Attack opportunity to determine a further declaration or finish;
- accepted ODR-001, which establishes composed-return convergence without a
  central continuation mechanism; and
- accepted ODR-002, which directs this minimal CON-007 adoption.

The bounded outcome is a contract that requires convergence after an authorized
post-Attack release while preserving the existing owners, commands, canonical
state, and distribution boundaries.

## 2. Exact CON-007 edit surface

The future contract edit SHALL change only the following CON-007 locations.
Section 6 is intentionally not an edit target: its exact-once and failure
semantics remain normative without relaxation.

| CON-007 location | Required additive refinement | Must not change |
| --- | --- | --- |
| Header / related-authority metadata | Add traceability to ODR-001 and accepted ODR-002. | CON-007 status, scope as post-Attack continuation, and existing related authority. |
| Section 1, Purpose And Scope | State that CON-007 explicitly adopts composed-return convergence only for post-Attack release. | The supported contexts and exclusion of attack declaration / active-attack ownership. |
| Section 2, Terms And Semantic Boundary | Define child completion, enclosing completion, applicable enclosing purpose-specific owner, and stable outcome; clarify that release consumption alone is not enclosing completion. | Completed-result inspection meaning and acknowledgement-satisfaction boundary. |
| Section 3, Ownership And Release Convention | Add the convergence obligation and parent re-evaluation rule as new additive normative clauses. | `ShipInstance`, `SquadronInstance`, `GameState`, and `CurrentAttackState` ownership; at-most-one release; derived-only choices. |
| Section 4, Supported Context Mapping | Add a convergence-result column or adjacent explanatory text identifying the applicable enclosing owner boundary for each existing row. | The four supported contexts, their existing canonical facts, and their existing transactions. No new context is added. |
| Section 5, Sole Live-Authority Release Seam | Add a bounded post-success evaluation rule allowing the existing seam to continue evaluation through already-applicable existing transactions. | The seam remains evaluator/coordinator only, not a gameplay owner or generic framework. |
| Section 7, Replay, Network, Save/Load, And Reconnect | Make convergence evaluation subject to the current authoritative-history, live-authority, and reconstruction restrictions. | Replay ordering, passive-mirror prohibition, and non-persistence of derived opportunities. |
| Section 8, Entry Gate B Evidence Boundary | Require convergence-based evidence and stable-outcome assertions for every current Section 4 context and distribution mode. | Existing four-context seam trace and exact-once evidence requirements. |
| Section 9, Explicit Non-Goals | Add explicit exclusions for generic continuation architecture, new commands/state, production implementation, and BUG-035 repair. | Existing non-goals. |
| Section 10, Traceability | Map ODR-001 and ODR-002 to the added clauses. | Existing PAC-OD traceability. |

No other CON-007 section, contract, ADR, requirement, production file, or test
file is in scope for this workbook.

## 3. Required normative additions

The contract edit SHALL add obligations with the following meanings. Final
clause identifiers may be allocated beside the existing CON-007 groups, but
their normative content SHALL not be weakened.

### 3.1 Composed-return convergence adoption

CON-007 SHALL state that, after a satisfied completed-result inspection is
released by an authorized existing consumer, it adopts the ODR-001
composed-return convergence principle at the post-Attack boundary. The
principle is an outcome requirement, not a new implementation mechanism or
repository-wide adoption.

### 3.2 Child completion is not enclosing completion

CON-007 SHALL state that completion or termination of a child interaction,
including consumption of a completed-result inspection by its authorized
consumer, is not by itself completion of the enclosing gameplay interaction
hierarchy. `SkipAttackCommand(reason: squadron_done)` remains child iteration
termination only; it neither decides Ship Attack continuation nor advances a
ship directly to Maneuver.

### 3.3 Parent re-evaluation through existing owners

After an authorized release consumer terminates or changes a child
interaction, evaluation SHALL re-derive canonical eligibility through every
applicable enclosing purpose-specific owner boundary. Existing commands and
accepted transitions SHALL perform any required mutation. The contract SHALL
name no new owner and SHALL not infer a universal parent chain.

For the existing Section 4 contexts, the explanatory mapping SHALL preserve
these ownership directions:

- anti-squadron iteration return is re-evaluated by the enclosing Ship Attack
  opportunity, which may expose another declaration, complete its Attack
  boundary, or permit the existing Maneuver transition as applicable;
- Squadron Activation return is re-evaluated by its existing Squadron
  Activation owner; and
- commanded Squadron Activation return is re-evaluated by the existing
  Squadron Command owner, then by its existing enclosing ship-activation path
  when that opportunity is exhausted.

These are contract verification directions, not a transfer of Ship Attack,
Ship Activation, Squadron Activation, Squadron Command, or Squadron Phase
rules into CON-007.

### 3.4 Stable outcome

CON-007 SHALL define convergence as reaching one of these outcomes:

1. a legal gameplay decision requiring controller input is live and
   recoverable from authoritative state; or
2. authoritative gameplay is in a state requiring no further immediate
   authoritative transition.

A state SHALL NOT count as stable when accepted gameplay rules require another
immediate automatic transition. A consumed inspection, executed consumer,
closed modal, restored UI, or isolated intermediate mutation is insufficient
on its own.

### 3.5 Bounded CommandProcessor seam

CON-007 SHALL refine the existing CommandProcessor post-success seam to allow
it to derive that further enclosing evaluation is required and select or invoke
only an already-applicable existing purpose-specific semantic transaction. It
MAY continue such evaluation until the stable outcome above is reached.

The seam SHALL NOT own parent semantics, completion criteria, progression
policy, a hierarchy model, or canonical continuation state. It SHALL NOT
create a continuation command, queue, descriptor, FSM, manager, or controller.

## 4. Semantics preserved without change

The future edit SHALL state or retain these invariants without reinterpretation:

- **Completed-result inspection ownership:** `GameState` remains the sole
  canonical owner of the purpose-specific inspection. `CurrentAttackState`
  remains retired after terminal attack completion; no inspection gains an
  enclosing-progress or continuation-description role.
- **At-most-one release:** one satisfied inspection remains eligible for at
  most one accepted mutating release consumer, with atomic consumption and its
  existing owner mutation. A derived-only choice still creates no consumer.
- **Purpose-specific commands:** required mutation remains in the already
  applicable existing semantic transaction. No generic post-Attack or
  continuation command is authorized.
- **Attack declaration ownership:** CON-006 retains declaration, selected
  `BeginAttackCommand`, and `SkipAttackCommand` ownership. CON-007 does not
  turn re-evaluation into declaration selection or UI-owned progression.
- **Presentation non-authority:** UI, modal, callback, timer, controller, and
  routing state may present a recovered live decision but cannot establish,
  consume, or advance it.

## 5. Verification impact and contract acceptance evidence

The CON-007 Section 8 refinement SHALL require convergence-based acceptance,
not merely proof of local release events. For every existing Section 4 context,
evidence SHALL prove the terminal hierarchy outcome is either a recoverable
live legal decision or a stable authoritative state with no immediate required
transition.

Each focused trace SHALL include, as applicable:

1. terminal attack completion and completed-result inspection satisfaction;
2. the existing authorized consumer and its at-most-one atomic consumption, or
   a derived-only next opportunity with no synthetic command;
3. re-evaluation by the applicable existing enclosing purpose-specific owner;
4. the final stable-outcome assertion, rather than an assertion limited to
   inspection consumption, command execution, modal closure, UI restoration,
   or an intermediate mutation; and
5. decision-equivalent recovery of any live outcome under SAI-001, ADR-010,
   and SAI-050.

The four current context rows remain the minimum acceptance matrix:

| Context | Required convergence assertion |
| --- | --- |
| Normal ship attack | A further legal declaration is recoverable, or the existing Ship Attack boundary reaches its valid stable result, including existing Maneuver progression where immediately required. |
| Ship anti-squadron iteration | A remaining legal squadron declaration is recoverable; otherwise the existing `squadron_done` consumer ends only the iteration and the enclosing Ship Attack is re-evaluated to its stable result. |
| Squadron Phase squadron attack | The existing Squadron Activation owner exposes the next recoverable action or completes through its accepted existing path to a stable result. |
| Ship-commanded squadron attack | The existing Squadron Command owner exposes another legal commanded-squadron choice or finishes through its existing commanding-ship path to a stable result. |

The refined Section 7 and Section 8 evidence SHALL also preserve these current
boundaries:

- replay applies accepted commands in authoritative history order and does not
  synthesize convergence transactions;
- only live authority may derive and submit an automatic existing transaction;
  passive network mirrors apply ordered results and do not independently
  converge;
- save/load and reconnect install and validate canonical inspection and owner
  state before the same bounded evaluation; and
- derived live decisions are re-derived from canonical state and are neither
  persisted nor transmitted as continuation descriptors.

## 6. Explicit exclusions and stop conditions

This workbook and the resulting CON-007 edit do not authorize:

- a generic continuation architecture, owner, manager, framework, queue, FSM,
  hierarchy stack, descriptor, or canonical continuation state;
- new commands, APIs, command families, or state;
- production implementation, production-code edits, test implementation, or
  migration execution;
- changes to CON-006 attack declaration, ADR-001 attack ownership, ADR-007
  inspection ownership, ADR-010 recovery scope, or Ship Activation ownership;
- automatic adoption by other interaction families; or
- a BUG-035 fix. BUG-035 remains deferred until a later implementation task is
  authorized against the refined accepted contract.

Stop the contract-edit task and request an Owner decision before changing
CON-007 if any of the following is true:

1. the proposed wording must expand CON-007 ownership into Ship Activation,
   Ship Attack, Squadron Activation, Squadron Command, Squadron Phase, or
   another purpose-specific rule owner;
2. convergence cannot be expressed through an already-existing accepted
   architecture component and semantic transaction;
3. a new canonical state owner or continuation fact is needed; or
4. ODR-002 and the accepted authorities do not resolve the interpretation
   needed for a precise clause.

## 7. Execution sequence and acceptance boundary

1. Edit only CON-007 at the locations enumerated in Section 2.
2. Add the Section 3 normative content as minimal additive wording, retaining
   all existing identifiers and semantics unless a new adjacent identifier is
   necessary.
3. Check each new clause against Section 4 preserved invariants and Section 6
   exclusions.
4. Update only CON-007 traceability for ODR-001 and ODR-002.
5. Review the contract diff for scope: no production, test, requirement, ADR,
   CON-006, or unrelated-contract change is permitted.
6. Obtain Owner acceptance for the resulting CON-007 refinement before any
   implementation workbook or BUG-035 repair proceeds.

This draft records no unresolved Owner decision. The listed stop conditions are
mandatory future escalation gates, not presently triggered by the accepted
ODR-002 direction.

## 8. Authority documents used

- `AGENTS.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/decision_workbooks/ODR-001-composed-return-convergence-principle.md`
- `docs/architecture/decision_workbooks/ODR-002-CON-007-composed-return-convergence-refinement-proposal.md`
- `docs/architecture/contracts/CON-007-post-attack-continuation-release-contract.md`
- `docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md`
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md`
- `docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md`
- `docs/requirements/gameplay_interactions/ship_activation_interaction.md`,
  especially SAI-001 and SAI-050.

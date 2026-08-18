# CON-007: Post-Attack Continuation Release Contract

Contract ID: CON-007
Title: Post-Attack Continuation Release Contract
Status: Accepted
Derived From: ADR-007 and PAC-OD-001 through PAC-OD-006
Related ADRs: ADR-001, ADR-006, ADR-007
Related Contracts: CON-001, CON-006
Related Evidence: MA-ATTACK-001

Accepted by: Project Owner
Accepted date: 2026-08-18
Supersedes: None
Superseded by: None

## Draft Note

This Contract translates the accepted Project Owner direction recorded in
`UX-005-post-attack-continuation-ownership-workbook.md` into the narrow
implementation obligations needed for ADR-007 Entry Gate B. Until the Project
Owner accepts this Contract, it is not normative implementation authority.

The Owner decisions resolve the intended ownership model. They do not establish
the per-context implementation proof required for Entry Gate B and do not
authorize UX-005 implementation. ADR-007 remains the architecture authority;
this Contract neither amends it nor introduces a new lifecycle, command family,
or canonical owner.

## 1. Purpose And Scope

CON-007 governs the semantic boundary after an individual attack has completed
and before enclosing gameplay may progress. It applies to the standard attack
contexts already in scope of CON-006:

- normal ship attacks, including multiple normal attacks;
- ship anti-squadron attacks and their target iteration;
- squadron attacks during the Squadron Phase; and
- squadron attacks commanded during a Ship Phase Squadron command.

It governs only the release of the ADR-007 completed-result inspection and the
existing context-specific progression that follows it. Attack declaration is
governed by CON-006; active attack lifecycle and mutation are governed by
ADR-001 and CON-001; ship activation facts are governed by ADR-006.

## 2. Terms And Semantic Boundary

**Terminal attack completion** is the accepted terminal transaction for one
resolved individual attack. It retires `CurrentAttackState` and establishes the
ADR-007 completed-result inspection. It is not enclosing activation or action
progression.

**Completed-result inspection** is the purpose-specific canonical ADR-007
barrier after terminal attack completion. It records no enclosing-progress
facts and is pending until acknowledgement satisfaction.

**Acknowledgement satisfaction** is the state in which the inspection's
authoritatively required acknowledgements have all been accepted. It changes
only inspection eligibility; it is not a gameplay progression transaction.

**Release** is one evaluation of a satisfied inspection against the canonical
context. Its result is either an already-defined applicable semantic
transaction or a derived non-mutating next opportunity. It is not a generic
continuation object or state machine.

**Subsequent gameplay progression** is the context-specific semantic mutation
after release, if one is required. It remains owned by its existing canonical
owner and transaction.

CON-007-BOUNDARY-001: `CompleteAttackCommand` SHALL remain terminal attack
completion. It SHALL NOT own enclosing ship activation, squadron activation,
Squadron-command progression, or a general post-attack continuation.

CON-007-BOUNDARY-002: `AcknowledgeAttackResultCommand` SHALL mutate only the
ADR-007 inspection acknowledgement/satisfaction state. It SHALL NOT select,
submit, or perform subsequent gameplay progression.

CON-007-BOUNDARY-003: A completed-result inspection SHALL block subsequent
gameplay progression until it is satisfied. Satisfaction makes release
eligible; it does not itself consume the inspection.

## 3. Ownership And Release Convention

CON-007-OWN-001: `ShipInstance` SHALL retain its accepted ship activation,
attack-step, normal-attack, hull-zone, anti-squadron iteration/history, and
relevant Squadron-command progress ownership. `SquadronInstance` SHALL retain
its accepted activation context and action/attack progress ownership.

CON-007-OWN-002: `GameState` SHALL own only the ADR-007 completed-result
inspection at this boundary, in addition to its existing aggregate and phase
responsibilities. The inspection SHALL NOT store a continuation descriptor,
the next route, derived opportunity, or a duplicate of ShipInstance or
SquadronInstance progress.

CON-007-OWN-003: `CurrentAttackState` SHALL remain terminally retired after
terminal attack completion and SHALL NOT retain post-completion progression.

CON-007-RELEASE-001: The shared convention is limited to this invariant: a
satisfied inspection permits at most one context-validated release. It SHALL
NOT introduce a generic continuation command, descriptor, queue, FSM,
controller, or second canonical owner.

CON-007-RELEASE-002: A release SHALL re-derive its eligibility from the
canonical state at evaluation time. A branch that only exposes another legal
choice SHALL remain derived and SHALL NOT create durable continuation state.

CON-007-RELEASE-003: When release requires gameplay mutation, it SHALL select
only the already-applicable context-specific semantic transaction. It SHALL
NOT substitute a generic post-attack transaction or make a scene, modal,
timer, `InteractionFlow`, or presentation callback a progression owner.

## 4. Supported Context Mapping

The following is a conceptual mapping to existing continuation paths. It does
not prescribe APIs, payloads, field layouts, or serialization schemas.

| Context | Canonical facts used at release | Existing continuation path | Derived, non-mutating outcome |
| --- | --- | --- | --- |
| Normal ship attack | Activating `ShipInstance` attack-step facts, committed normal-attack count, and used hull zones | When the ship Attack boundary is complete, the existing `AdvanceActivationStepCommand` ship Attack-to-Maneuver transition | A further legal normal declaration remains a canonical-state-derived opportunity. |
| Ship anti-squadron attack / iteration | The same `ShipInstance`'s locked anti-squadron zone and canonical target history, together with current target eligibility | The existing `SkipAttackCommand` `squadron_done` branch closes an exhausted iteration; the existing ship Attack-to-Maneuver transition remains applicable when the Attack boundary is then complete | An eligible untargeted squadron remains a derived next target opportunity; post-iteration normal-attack availability remains derived where legal. |
| Squadron Phase squadron attack | `SquadronInstance` activation/action history and canonical Squadron Phase progress in `GameState` | The existing `CompleteSquadronActivationCommand` completes an exhausted squadron activation and applies its existing phase/turn-control consequence | A remaining independent squadron movement action, including the applicable Rogue case, remains derived. |
| Ship-commanded squadron attack | `SquadronInstance` activation/action history plus the commanding `ShipInstance`'s activation identity, open Squadron-command opportunity, and committed count | The existing `CompleteSquadronActivationCommand` completes the commanded squadron; the existing Squadron-command path continues from the commanding ship, and its existing activation-step path proceeds when that opportunity is exhausted | A remaining commanded-squadron movement action or another eligible Squadron-command choice remains derived. |

CON-007-CONTEXT-001: The mapping above SHALL be proven separately for every
supported context. Similarity between contexts SHALL NOT be used to infer a
missing transaction, canonical owner, or release path.

CON-007-CONTEXT-002: A materially new reaction, rule-granted attack, or other
context with different progression semantics SHALL first prove an existing
canonical owner and existing semantic transaction. If it cannot, implementation
SHALL stop for architecture clarification; it SHALL NOT extend this Contract by
analogy or introduce generic infrastructure.

## 5. Sole Live-Authority Release Seam

CON-007-SEAM-001: The existing `CommandProcessor` post-success deferred-
follow-up seam is the sole live-authority evaluator for satisfied-inspection
release. It MAY evaluate canonical eligibility and select one already-defined
semantic transaction from the inspection identity and current canonical state.

CON-007-SEAM-002: That seam SHALL NOT become a generic continuation owner,
gameplay-flow owner, state machine, queue, or framework. It SHALL NOT own the
underlying context semantics, cache a continuation descriptor, or alter the
canonical progress owners.

CON-007-SEAM-003: Scene, modal, controller, timer, result handler, and
presentation callbacks SHALL NOT independently evaluate or submit the same
post-completion transaction. They may only project canonical inspection and
accepted command results.

CON-007-SEAM-004: The release evaluator SHALL select no transaction where
canonical state provides only a non-mutating next opportunity. It SHALL not
manufacture a no-op command solely to represent that opportunity.

## 6. Exact-Once And Failure Semantics

CON-007-XO-001: One inspection identity SHALL be consumed by at most one
accepted mutating continuation transaction.

CON-007-XO-002: A mutating continuation SHALL validate the matching satisfied
inspection and consume it atomically with its own canonical gameplay mutation.
No state in which the mutation commits but the inspection remains consumable,
or the inspection is consumed without the mutation, is permitted.

CON-007-XO-003: A duplicate callback, command result, mirror delivery, replay
application, load/reconnect reconstruction, or presentation teardown SHALL
NOT release or consume the same inspection again.

CON-007-XO-004: If the selected continuation fails validation or execution,
the satisfied inspection SHALL remain canonical and unconsumed. Recovery SHALL
re-evaluate the same canonical context through the same seam; it SHALL NOT
request another acknowledgement, partially progress gameplay, or synthesize a
fallback transaction.

## 7. Replay, Network, Save/Load, And Reconnect

CON-007-DIST-001: Replay SHALL apply accepted acknowledgement and continuation
commands in authoritative history order. Replay SHALL NOT independently
synthesize release or submit a live follow-up in addition to the recorded
continuation transaction.

CON-007-DIST-002: In Network play, only the authoritative side may originate a
release transaction through the CommandProcessor seam. Passive mirrors SHALL
apply accepted ordered commands and SHALL NOT synthesize release from local
inspection, presentation, or timing.

CON-007-DIST-003: Save/load and reconnect SHALL install and validate canonical
inspection and canonical owner state before projection or release evaluation.
A satisfied-but-unconsumed inspection may be re-evaluated only through the
same authoritative release policy; reconstruction SHALL NOT create an
independent continuation authority or duplicate mutation.

CON-007-DIST-004: Non-mutating next opportunities SHALL be re-derived from
canonical state after replay, mirror application, load, and reconnect. They
SHALL NOT be persisted or transmitted as continuation descriptors.

## 8. Entry Gate B Evidence Boundary

The architecture direction in PAC-OD-001 through PAC-OD-006 is resolved and
is ready for this Contract's Owner acceptance. ADR-007 Entry Gate B remains
unproven until focused implementation evidence demonstrates, for each row in
Section 4:

1. the exact existing semantic transaction for any required mutation;
2. use of the CommandProcessor post-success seam as the sole live-authority
   release evaluator after acknowledgement, satisfied-inspection load, and
   satisfied-inspection reconnect;
3. no passive-mirror synthesis and replay history-only behavior;
4. atomic inspection consumption with the selected mutation; and
5. duplicate rejection and unchanged satisfied inspection on continuation
   failure.

MA-ATTACK-001 and current code are implementation evidence only. They do not
establish this proof and do not override the accepted ADRs or this Contract
after acceptance.

The smallest targeted Gate B verification after Contract acceptance is one
four-context seam trace: for each Section 4 context, follow a satisfied
inspection through the `CommandProcessor` post-success seam in live-authority,
replay, passive-mirror, and satisfied-state reconstruction modes. The trace
must identify the concrete existing transaction or derived-only outcome and
show exactly-once atomic consumption where a transaction mutates gameplay. A
single unmapped context, independent synthesis path, or non-atomic consumption
is a Gate B failure and an architecture stop under ADR-007.

## 9. Explicit Non-Goals

CON-007 does not:

- design acknowledgement presentation or bot behavior;
- define APIs, field names, file placement, payload shapes, or serialization
  schemas;
- create a UX-005 implementation workbook or authorize implementation;
- revise attack declaration, timing-window, active-attack, ship activation, or
  squadron ownership; or
- define a generic continuation framework, queue, descriptor, FSM, controller,
  or new canonical owner.

## 10. Traceability

| Owner direction | Contract sections |
| --- | --- |
| PAC-OD-001 — existing semantic progression owner | Sections 2–4 |
| PAC-OD-002 — separate terminal completion and continuation | Sections 2 and 6 |
| PAC-OD-003 — narrow common release convention | Sections 3 and 5 |
| PAC-OD-004 — preserved canonical owners | Sections 3 and 4 |
| PAC-OD-005 — CommandProcessor sole live seam | Sections 5 and 7 |
| PAC-OD-006 — supported contexts and architecture stop | Sections 4 and 8 |

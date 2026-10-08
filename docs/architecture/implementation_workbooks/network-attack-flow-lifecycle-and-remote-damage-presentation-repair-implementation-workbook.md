# Network Attack-Flow Lifecycle And Remote Damage-Presentation Repair Implementation Workbook

Status: **Draft — ready for independent audit; not accepted; implementation is not authorized**

Purpose: define one coordinated, bounded production repair package for the two
distinct defects established by the
[Network mapping-1 diagnosis](../evidence/network-mapping-1-stale-attack-flow-diagnosis.md):

1. a High-severity stale `PublishAttackFlowCommand` lifecycle-validation defect;
2. a Medium-severity remote ship-damage presentation/result-shape defect.

This workbook preserves separate root causes, repair seams, tests, and
completion criteria. Coordination exists only because both defects are exposed
by the same remote-attacker Network role mapping and must converge in the same
two-mapping acceptance run.

## 1. Classification, Authority, And Entry Status

Classification: **Bounded Architecture / bounded cross-cutting production
repair**.

The relevant ownership and failure behavior are already decided. Binding
authority, in precedence order, is:

1. accepted [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
   and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
   for canonical current-attack ownership, lifecycle identity, stale-command
   rejection, atomic failure, derived flow, replay, and Network mirroring;
2. accepted [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md)
   for completed-result inspection consumption and release into the enclosing
   activation;
3. accepted [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md)
   for separation of endpoint, principal, and canonical player side during
   fresh resume and reassociation; and
4. accepted [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md)
   for authority-resolved Network result application and the prohibition on
   presentation or transport becoming a canonical mutation owner.

The diagnosis is implementation evidence. It fixes the first invalid command,
the origin of `-1`, the role-mapping asymmetry, and the absence of RNG/save
causality. This workbook does not reopen those findings or authorize broad
discovery.

Entry status: no unresolved architecture choice is known. Implementation may
begin only after independent audit and Project Owner acceptance of this
workbook. Until then, this document authorizes no production or test changes.

## 2. Fixed Defect Boundaries And Required Outcomes

### 2.1 Defect A — stale non-final attack-flow publication

Fixed finding: a remote attacker's scene creates a valid non-final attack-flow
snapshot while the matching canonical attack is active. Network FIFO delay can
deliver it after `CompleteAttackCommand`, completed-result acknowledgement, and
`AdvanceActivationStepCommand` have retired the attack and consumed its
inspection. `PublishAttackFlowCommand.validate()` currently accepts the stale
snapshot and `execute()` writes an ATTACK flow into a state with no active
attack and no completed inspection.

Required outcome:

- every non-final attack-flow publication validates immediately against the
  current canonical `CurrentAttackState` lifecycle;
- absence of an active attack, missing or malformed snapshot attack identity,
  or mismatch with the active canonical `attack_id` rejects as stale before
  mutation;
- rejection leaves canonical state, interaction flow, command history,
  command cursor, follow-up generation, and success presentation unchanged;
- a valid live publication for the matching active attack remains accepted;
- terminal/final flow clearing remains bounded to the attack flow it is
  permitted to clear and cannot erase a later non-attack flow or an active
  replacement attack; and
- queue timing, coalescing, cancellation, or flushing is not the correctness
  mechanism.

This repair enforces existing authority. It does not make
`InteractionFlow`, `AttackFlowFSM`, `AttackExecutor`, or Network submission
state a new attack/continuation owner.

### 2.2 Defect B — remote ship-damage presentation target identity

Fixed finding: for a remote-authored `resolve_damage` application-contract
command, the host may derive presentation from
`CurrentAttackState.resolved_outcome`. That outcome intentionally omits
duplicate defender identity. The ship branch nevertheless calls a helper that
defaults absent `owner_player` and `ship_index` to `-1`, producing
`get_player_state(-1)` and skipping required ship presentation. The analogous
squadron branch already resolves missing presentation identity from the
matching active canonical attack.

Required outcome:

- a complete authority-result presentation dictionary continues to resolve
  its explicitly identified ship;
- when the presentation dictionary intentionally omits ship identity, the
  handler derives the defender from the still-active canonical
  `CurrentAttackState` only after matching the command's `attack_id` and
  confirming `defender_kind == ship`;
- the resolved canonical `ShipInstance` drives the existing defense-token,
  shield, hull, damage-card, summary, destruction, and elimination
  presentation signals;
- missing, stale, mismatched, inactive, wrong-kind, or out-of-range canonical
  context fails presentation closed without selecting another ship, emitting
  success presentation for another target, or mutating canonical state; and
- no path treats `-1`, command submitter identity, host/client role, endpoint,
  principal, active player, or UI state as substitute defender identity.

The repair must not duplicate defender identity into
`resolved_outcome`, `CurrentAttackState`, command history, or transport merely
for presentation. Existing canonical defender identity is sufficient.

## 3. Authoritative Invariants

### 3.1 Attack-flow lifecycle and identity

1. `GameState.current_attack_state` is the sole current-attack lifecycle and
   identity authority.
2. A non-final flow snapshot is a derived mirror of exactly one active attack;
   its `flow_payload.attack_id` must be a non-empty exact match for the active
   canonical `attack_id` at validation time.
3. A snapshot created for an earlier completed, cancelled, or replaced attack
   is stale even if it was valid when queued.
4. `controller_player`, `attacker_player`, `defender_player`, flow step, scene
   state, projection visibility, command sequence acceptance, or possession of
   a queued payload does not substitute for lifecycle identity.
5. Rejection is atomic under CON-001: no `interaction_flow` write, cursor or
   history advancement, follow-up, or success projection.
6. Final clearing may clear only the applicable existing ATTACK flow after its
   canonical attack has terminally retired. It must reject if a current attack
   is active or the authority has already moved to a non-ATTACK flow. It must
   not clear maneuver, activation, setup, timing, or another later flow.
7. `FlowSpec`, registered rule validation, and existing principal/player
   admission remain additional gates. The new lifecycle predicate cannot
   weaken or replace them.
8. Existing deserialization and StateFilter fail-closed behavior remains
   unchanged. Aligning the live full-authority validator with the same relation
   is optional defense in depth only if focused terminal/cancellation tests
   prove that no valid inter-command state relies on the present difference;
   it cannot replace command validation.

### 3.2 Remote damage presentation identity

1. `ResolveDamageCommand` remains the sole canonical damage-mutation owner.
2. The accepted canonical attack owns stable defender player, kind, and index
   for the active damage transaction.
3. `resolved_outcome` remains an outcome, not a second target-identity owner.
4. `GameManager` presentation code may read the matching canonical attack to
   resolve a `ShipInstance`; it may not write canonical attack or ship state.
5. Explicit result identity, when present, must be complete and resolve
   exactly. An incomplete or invalid explicit identity must not silently fall
   through to a different target.
6. Identity-free presentation fallback is allowed only for the known
   application-contract shape and only while the exact matching canonical
   attack is active and targets a ship.
7. Presentation failure is not a gameplay rollback and must not synthesize a
   replacement result, target, or command.
8. Endpoint/principal/player association remains unchanged; the defect is not
   a reassociation or authorization defect.

## 4. Authorized Production Scope

### 4.1 Defect A production seam

| Surface | Authorized bounded change |
| --- | --- |
| `src/core/commands/publish_attack_flow_command.gd` | Replace “always valid” behavior with explicit non-final active-lifecycle and exact `attack_id` validation; validate bounded final clearing against current canonical lifecycle/flow; preserve existing rule validators and execution behavior for accepted snapshots. |
| `src/core/state/game_state.gd` | Verification surface by default. A matching live-validator guard is authorized only if focused terminal, cancellation, Counter, and completed-inspection evidence proves it rejects no valid inter-command state. It is optional defense in depth, not a completion requirement. |
| Command rejection/result plumbing | Verification only. A production change is authorized only if focused evidence shows the existing standard rejection path fails to preserve cursor/history/state for this command; broad rejection redesign is excluded. |
| `NetworkCommandSubmitter`, `AttackExecutor`, `AttackFlowFSM` | Verification surfaces only. Queue pruning/coalescing may not substitute for command validation. Changes here require a stop unless they are a separately justified, optional cleanup accepted after the core repair passes. |

The implementation should use the existing `flow_payload.attack_id`; no new
command field is expected. If valid final publications cannot be made lifecycle
safe without adding serialized identity or changing their schema, stop for
independent compatibility review rather than silently expanding the payload.

### 4.2 Defect B production seam

| Surface | Authorized bounded change |
| --- | --- |
| `src/autoload/game_manager.gd` | Add the ship analogue of the existing active-attack squadron lookup, or equivalently factor a narrow shared canonical target lookup. Require matching command `attack_id`, active attack, ship defender kind, and valid canonical player/index before returning the `ShipInstance`. Use it only for the intentionally identity-free remote damage-presentation path. |
| `_find_ship_from_damage_result()` | Retain exact lookup for complete explicit result identity. It must validate key presence/range before calling `get_player_state`; it must not default missing identity into a lookup. Guarding the log alone is not completion. |
| `_handle_remote_resolve_damage()` | Select complete explicit identity when present; otherwise invoke the matching-active-attack ship fallback. Preserve existing canonical-state-derived presentation signals. |
| Resolve-damage command/result contract | Verification only. No canonical mutation, command-result, or transported-result change is expected or authorized. |

### 4.3 Authorized test and evidence scope

Focused unit, integration, two-process Network acceptance, save/load boundary,
reconnect/reassociation, and replay non-regression tests may be added or
updated only to establish Sections 7–9. Diagnostic logs may be strengthened
only where required to distinguish stale rejection from projection failure;
they must not become a correctness dependency.

Implementation evidence may update this workbook's status only through the
normal audit/Owner process. It may add a separate repair evidence report after
implementation. Existing replay fixtures, RNG baselines, hashes, and GGS
artifacts are not test-authoring surfaces for this package.

## 5. Explicit Exclusions And STOP Conditions

This workbook does not authorize:

- queue timing, queue deletion, coalescing, or client-side cancellation as the
  stale-command correctness boundary;
- a new attack, continuation, inspection-release, result, event, projection,
  or Network command framework;
- moving current-attack authority into `InteractionFlow`, scene FSM state,
  `AttackExecutor`, `GameManager`, command submitters, transport, or UI;
- weakening `GameState.deserialize()`, full-authority validation,
  `StateFilter`, or Network filtering so the invalid combination is accepted;
- treating a valid endpoint/principal association as proof that a stale attack
  command is semantically applicable;
- defaulting or mapping `-1` to either player, suppressing the error without
  resolving the correct ship, or using active player/host/client role as target
  identity;
- adding duplicate defender identity to canonical attack outcome solely for
  presentation;
- changing damage ownership or replaying damage in presentation code;
- changing Network protocol, save format, replay format, RPC envelope,
  command-result schema, or command history representation;
- renewing, transforming, relabeling, or patching replay fixtures;
- changing exact-RNG serialization, RNG stream/authority, save-version policy,
  RNG baselines, or state hashes; or
- continuing GGS-001 Gate 2.

STOP and return to independent audit/Owner review if implementation appears to
require any excluded change, if accepted valid publications lack usable
canonical attack identity, if historical replay contains now-rejected
semantically valid publications, or if either defect cannot be repaired without
a serialized schema/version change.

## 6. Implementation Slices And Gates

### Slice A — stale-publication command validation

1. Add a narrow payload/lifecycle predicate to
   `PublishAttackFlowCommand.validate()` after base validation.
2. For `final == false`, require:
   - a present valid `GameState` and active `CurrentAttackState`;
   - a non-empty string `flow_payload.attack_id`;
   - exact equality with the active canonical `attack_id`; and
   - preservation of every existing rule/FlowSpec validation result.
3. For `final == true`, preserve the production terminal publication only when
   no current attack is active and the current authority flow is the applicable
   ATTACK flow. Reject once authority has moved to another flow or a replacement
   attack is active.
4. Prove execution is unreachable on rejection and accepted snapshots retain
   existing projection behavior.
5. Keep the existing deserialization and StateFilter invariant unchanged. Add
   a live-validator equivalent only if the Section 4 safety condition is
   independently established.

Gate A passes only when stale/missing/mismatched publications reject without
any canonical or ordering mutation, every required valid live step remains
accepted, and StateFilter receives only reconstructable authority.

### Slice B — canonical ship target for remote damage presentation

1. Keep complete explicit-result lookup exact and fail closed on incomplete
   explicit identity.
2. Add the narrow ship fallback matching the existing squadron pattern:
   current attack exists and is active; command `attack_id` matches; defender
   kind is ship; canonical defender player/index resolves exactly.
3. Route the identity-free `resolved_outcome` presentation shape through that
   canonical fallback before emitting existing ship presentation events.
4. Do not mutate state, enrich persisted outcome, or modify the transported
   result contract.
5. Prove stale/wrong-kind/missing context selects no ship and produces no
   `Invalid player index: -1` lookup.

Gate B passes only when both explicit-result and identity-free application-
contract shapes project the correct canonical ship, invalid contexts fail
closed, and no canonical state or result schema changes.

### Slice C — coordinated Network verification

1. Run both role mappings through the same deterministic production sequence.
2. Force or select a deterministic facedown-only ship-damage outcome for the
   remote-attacker mapping so no faceup-inspection delay accidentally masks
   stale publication timing.
3. Hold/queue at least one non-final resolve-damage attack-flow snapshot until
   after attack completion, completed-result acknowledgement, inspection
   consumption, and activation advance.
4. Prove the delayed snapshot is rejected, state/history/cursor remain at the
   post-advance values, repair/maneuver continuation remains usable, final
   filtering succeeds, and host/client passive projections converge.
5. In the same remote-attacker path, prove ship presentation resolves the
   canonical defender and no player `-1` diagnostic occurs.
6. Run the host-attacker mapping as the valid-publication/local-presentation
   control and confirm unchanged completion/convergence.

Gate C passes only when mappings 0 and 1 both complete, valid publications are
not over-rejected, the diagnosed stale publication is rejected at command
validation, and neither final projection nor remote ship presentation fails.

## 7. Required Regression Matrix

| Area | Mapping / boundary | Required evidence |
| --- | --- | --- |
| Non-final command validation | In-memory authority | Matching active `attack_id` accepts; missing id, malformed id, no active attack, completed/cancelled attack id, and different replacement id reject. |
| Final publication validation | In-memory authority | Valid terminal ATTACK clearing accepts; delayed final after maneuver/non-ATTACK flow and final while a replacement attack is active reject without clearing current flow. |
| Atomic rejection | CommandProcessor production path | Serialized state/hash, `interaction_flow`, current attack, completed inspection, history length, next sequence/cursor, follow-ups, and success signals are unchanged after rejection. |
| Valid live flow coverage | Ship and squadron attack paths | Representative Declare, Roll, Modify, Defense, Resolve Damage, Critical/Counter where applicable, and terminal clearing publications for the matching lifecycle remain accepted. |
| Deserialize/filter invariant | Full authority | Accepted command states round-trip; deliberately impossible ATTACK-flow/no-attack/no-inspection state continues to fail deserialization/filtering; `StateFilter` remains unchanged and succeeds after stale rejection. If the optional live-validator guard is added, it must reject the impossible state without rejecting valid terminal/cancellation intermediates. |
| Explicit ship result | Remote presentation helper | Complete valid `owner_player`/`ship_index` resolves exactly; wrong owner/index and incomplete explicit identity resolve nothing. |
| Identity-free ship result | Remote-authored application contract | Matching active ship attack resolves canonical defender and emits existing presentation for that ship; stale id, inactive attack, squadron defender, and missing attack context emit no ship success projection. |
| Network mapping 0 | Host attacker / client defender | Real attack uses valid live publications, damage presentation, completion, acknowledgement, activation continuation, final filtering, and convergence without behavior change. |
| Network mapping 1 | Client attacker / host defender | Facedown-only real damage path; host canonical ship presentation; delayed non-final publication after inspection consumption rejects; later repair/maneuver and final projection converge; no `-1`. |
| Reconnect/reassociation | Both side assignments | Reconstructed active attack accepts only its matching live publication; post-terminal stale publication rejects after reconnect; endpoint/principal assignment remains unchanged. |
| Save/load | Active and post-terminal boundary | Existing active attack identity round-trips and accepts matching publication; loaded post-terminal state does not resurrect flow and rejects the retired attack id. No new save fields. |
| Replay | Existing production replay | Valid recorded publications replay unchanged and retain command order/final canonical result; stale-command rejection uses existing semantics and no fixture or format changes. |
| Serialization | Command round trip | Existing `publish_attack_flow` payload, including nested `attack_id`, round-trips with no new field; resolve-damage command/result shapes remain unchanged. |
| Queue independence | Network submitter integration | The same stale payload rejects whether delivered immediately after retirement or after FIFO delay; optional queue behavior cannot determine correctness. |

The mapping-1 facedown-only case is mandatory and may not be replaced by a
faceup-damage path whose extra acknowledgement gates happen to drain or reject
the queue earlier.

## 8. Compatibility And Version Consequences

Expected consequence: **no format or protocol version change**.

- **Command serialization:** unchanged. Non-final validation consumes the
  existing nested `flow_payload.attack_id`; no new payload member is expected.
- **Network protocol:** remains the repository's current protocol version
  (presently 10). No RPC or result-envelope field is added.
- **Save format:** remains whatever current version is owned by the paused
  exact-RNG repair; this package does not increment, reinterpret, migrate, or
  otherwise modify it.
- **Replay format:** remains 11. Existing replay commands and fixtures remain
  byte-for-byte unchanged.
- **Canonical `GameState` schema:** unchanged. The live validator becomes
  consistent with an invariant already enforced by deserialization.
- **Damage command/result contract:** unchanged. Presentation derives existing
  canonical defender identity locally rather than transporting or persisting a
  duplicate.
- **Principal/reassociation data:** unchanged. No binding, assignment, or
  endpoint association field changes.

Behavior changes only for invalid/stale command admission and the previously
broken identity-free presentation path. Valid authoritative histories should
retain their canonical state and hashes. If a valid supported save, replay, or
live flow requires acceptance of a command this workbook classifies as stale,
or if any serialized shape must change, implementation must stop for an
explicit compatibility decision.

No replay fixture renewal is expected or authorized. If unexpected replay
format or fixture divergence occurs, follow the manual Owner-recorded capture
policy in [CODEX_WORKFLOW](../CODEX_WORKFLOW.md); do not generate, patch,
transform, or relabel fixtures.

## 9. Verification And Evidence Requirements

Minimum automated evidence:

1. focused `PublishAttackFlowCommand` validation/execution tests;
2. focused `CommandProcessor` stale-rejection atomicity tests;
3. focused `GameState` full-authority invariant and StateFilter non-regression;
4. focused remote ship-damage presentation tests covering explicit and
   identity-free shapes;
5. `NetworkCommandSubmitter` FIFO/delayed-delivery integration evidence that
   demonstrates timing independence;
6. current-attack shared-protocol coverage for both attacker/defender role
   topologies;
7. save/load and replay non-regression at the exact affected lifecycle
   boundaries;
8. reconnect/reassociation coverage with both explicit side assignments;
9. real two-process Network acceptance for mapping 0 and the mandatory
   facedown-only mapping 1 sequence; and
10. `git diff --check`, applicable static checks, and a final changed-file and
    version audit.

The retained evidence must identify:

- accepted and rejected command payload identities;
- the current canonical attack/inspection/flow before and after each stale
  rejection;
- command history and cursor before and after rejection;
- the canonical ship identity used for remote presentation;
- absence of any `Invalid player index: -1` diagnostic;
- mapping number, endpoint/principal/player assignment, attacker and defender;
- whether faceup inspection occurred (the mandatory mapping-1 canary must say
  no);
- post-damage acknowledgement and activation-advance order;
- final filtering and host/client convergence results; and
- unchanged save, replay, Network, command, and result versions/schemas.

Instrumentation used to establish ordering must be removed before handoff.
Tests must assert production outcomes rather than parse incidental log timing
as the primary oracle.

## 10. Completion Criteria

This repair package is complete only when:

1. Defect A's stale non-final publication is rejected at the command
   validation boundary before mutation in both direct and delayed delivery;
2. matching live publications and valid terminal clearing still work across
   representative ship and squadron attack stages;
3. stale publication no longer creates the impossible ATTACK-flow/no-attack/
   no-inspection combination, while existing reconstruction and StateFilter
   fail-closed behavior remains intact;
4. Defect B resolves the correct canonical ship for identity-free remote
   damage presentation without any `-1` lookup or duplicate identity owner;
5. invalid presentation context fails closed without canonical mutation or
   another target's presentation;
6. both Network role mappings pass, including the facedown-only remote-attacker
   stale-publication sequence, later gameplay continuation, final filtering,
   and passive convergence;
7. save/load, reconnect/reassociation, replay, serialization, and existing
   attack/damage protocol regressions pass with no schema/version change;
8. no queue behavior is required for correctness and no new lifecycle or
   continuation owner exists;
9. the exact-RNG implementation and its baselines/hashes remain untouched by
   this package; and
10. an independent completion audit finds no unresolved required evidence or
    scope escape.

## 11. Relationship To The Paused Exact-RNG Repair

The RNG serialization repair remains paused before baseline/hash promotion.
This coordinated package is a separate production repair for defects that the
exact repaired stream **EXPOSED** but did not cause.

During this package:

- do not change RNG serialization, save-version policy, Gate 1 assertions,
  replay inputs, baseline candidates, or committed hashes;
- the current exact-RNG worktree may be used only as the known mapping-1
  acceptance environment, with its existing changes preserved;
- also retain an RNG/save-independent stale-command regression so correctness
  is not coupled to that worktree or one random outcome; and
- GGS-001 Gate 2 remains unauthorized.

After this package is implemented, independently audited, and both Network
mappings pass, the exact-RNG repair may resume at its bounded cross-boundary
verification step. Baseline/hash promotion remains a separate Owner-controlled
action under its accepted workbook. This workbook does not authorize it.

## 12. Remaining Owner Decisions And Stop Gates

No new gameplay, attack-ownership, Network-role, presentation-ownership,
save/replay, or protocol decision is presently required.

Remaining Owner actions are:

1. assign defect tracking identifiers if desired;
2. accept, revise, or reject this workbook after independent audit;
3. authorize implementation only after acceptance;
4. separately decide any compatibility change if an audit or implementation
   stop gate discovers one; and
5. retain separate authority over exact-RNG baseline/hash promotion and any
   later GGS-001 Gate 2 continuation.

Implementation must stop if it cannot preserve valid final publication without
a schema change, if existing supported replay encodes a semantically valid
case rejected by the new predicate, if canonical ship identity is unavailable
at the remote presentation seam, or if passing verification would require
changing the paused RNG repair or its baselines.

## 13. Estimated Size, Risk, And Audit Readiness

Estimated production size: **Small** — two mandatory production owners
(`PublishAttackFlowCommand` and `GameManager`), with an optional narrow
`GameState` defense-in-depth guard only if its safety gate passes. No new
subsystem or format is expected.

Estimated verification size: **Medium** — focused command/presentation tests,
two role mappings, delayed delivery, reconnect, save/load/replay boundaries,
and a real two-process facedown-only acceptance canary.

Risk:

- Defect A implementation risk: **Medium–High**, because over-broad validation
  could reject legitimate flow publication, terminal clearing, Counter,
  squadron, reconnect, or replay sequences.
- Defect B implementation risk: **Low–Medium**, because the seam is
  presentation-only but must select exactly the canonical ship and preserve
  all existing signals.
- Coordinated package risk: **Medium–High**, dominated by distributed ordering
  and regression breadth rather than code volume.

Readiness: **ready for independent workbook audit**. The audit should challenge
the non-final and final lifecycle predicates, verify that no queue behavior is
promoted to authority, verify the explicit-result versus identity-free ship
lookup distinction, confirm both role mappings and the facedown-only canary,
and confirm that every save/replay/Network/RNG version and baseline remains
unchanged. Owner acceptance is still required before implementation.

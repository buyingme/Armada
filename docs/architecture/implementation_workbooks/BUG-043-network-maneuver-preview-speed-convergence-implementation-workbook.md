# BUG-043: Network Maneuver Preview Speed Convergence Implementation Workbook

Status: Accepted

Accepted by: Project Owner
Accepted date: 2026-09-07

Purpose: define the smallest architecture-preserving repair for the corrected
BUG-043 Network defect. An accepted canonical speed change must converge with
the active transient maneuver preview before a maneuver can be submitted. This
Draft does not authorize production changes until accepted through repository
governance.

## 1. Classification, Authority, And Outcome

Classification: **Bounded Architecture**. Existing accepted architecture
already separates canonical ship state and replayable commands from disposable
maneuver presentation. No Owner architecture decision is required by the
currently established evidence.

Binding authority and requirements:

1. accepted ADR-006 canonical Ship Activation and maneuver-opportunity
   ownership;
2. accepted ADR-010 decision-equivalent recovery and its explicit treatment of
   uncommitted maneuver geometry/preview as transient and locally rebuilt;
3. accepted ADR-003 responsibility boundaries: state owns active state,
   commands own submitted mutation and final legality, Network owns ordered
   synchronization, and controllers own presentation consumption;
4. MVP requirements MV-003, MV-004, MV-006, MV-011, MV-020, and MV-022 for
   maneuver geometry and the ship's current speed; and
5. the corrected BUG-043 issue, captured log/replay, targeted provenance probe,
   and current production paths as implementation evidence.

Required outcome:

- accepted canonical speed is the only speed used to derive an actionable
  maneuver preview and its subsequent maneuver payload;
- asynchronous Network submission is not mistaken for canonical acceptance;
- authority and passive peers project the same accepted speed; and
- no durable state, command vocabulary, or generic synchronization mechanism is
  added.

## 2. Fixed Ownership Model

| Responsibility | Existing owner | Workbook rule |
| --- | --- | --- |
| Canonical ship speed | `ShipInstance.current_speed` | Remains the sole durable speed source. |
| Normal Navigate speed mutation | `SetSpeedCommand.execute()` via `ShipInstance.set_speed()` | Remains command-owned and recorded once. |
| Command ordering and passive application | `CommandProcessor` plus `GameManager._apply_network_command_result()` | Accepted ordered result application is the client convergence boundary. |
| Local Navigate budget/intention | activation-local `ShipActivationState` | Remains transient activation working state; it cannot overwrite canonical speed. |
| Maneuver geometry and displayed speed | `ManeuverToolState` inside `ManeuverToolScene` | Remains transient, disposable, and derived from the matching canonical ship. |
| Maneuver submission | `ShipActivationController` reading the live maneuver tool | Must not construct an actionable payload from preview speed stale against canonical speed. |
| Save/load/reconnect | existing canonical `GameState` serialization/filter/install and scene reconstruction | Persist/install canonical speed only; rebuild preview if the maneuver decision is live. |

Other command-owned speed effects remain outside this defect unless focused
implementation evidence proves they use the same broken SetSpeed acceptance
path. They must not be regressed or consolidated into a new speed framework.

Every activation-scoped pending request, accepted-result refresh, rejection
recovery, or preview invalidation in this workbook SHALL match both:

1. ship identity, using the canonical command owner/index resolved to the same
   `ShipInstance`; and
2. the active `ShipInstance.ship_activation_identity` captured when the speed
   request was submitted.

Ship identity alone is insufficient. A delayed accepted or rejected result may
clear its own stale pending record, but it SHALL NOT refresh, invalidate, reset,
or otherwise mutate a replacement/reconstructed activation or maneuver tool.

## 3. Confirmed Failure And Exact Repair Seam

### 3.1 Host-authored synchronous path

`NetworkHostCommandSubmitter.submit()` executes `SetSpeedCommand` synchronously.
On success, `ManeuverToolScene._handle_speed_change()` can read the newly
committed `ShipInstance.current_speed`, update preview, and publish the existing
speed presentation signal. This path already has an accepted value available,
but must use the same post-acceptance invariant as the client path.

### 3.2 Client-authored asynchronous path

The current client sequence is:

```text
speed-button input
-> ShipActivationState records transient delta
-> NetworkCommandSubmitter returns awaiting_remote
-> ManeuverToolScene treats sentinel as success and reads old canonical speed
-> ordered accepted result later updates ShipInstance.current_speed
-> GameManager remote effect for set_speed is pass
-> live ManeuverToolState remains stale
-> ShipActivationController may submit stale preview speed
```

The exact convergence seam is immediately after successful ordered
`SetSpeedCommand` application on a Network peer and before the submission gate
is released for later actions. `GameManager._handle_remote_command_effects()`
currently has a purpose-specific `set_speed` branch that performs no work. That
branch is the existing narrow result-projection hook; it must derive the
matching canonical ship and publish/invoke the existing purpose-specific speed
refresh.

The active `ManeuverToolScene` or its existing controller must consume that
accepted refresh only when both the canonical ship identity and active ship
activation identity match the transient pending request. It must set its
simulated speed from canonical state or invalidate/rebuild the preview from
canonical state before it remains actionable. Preview must never write back to
`ShipInstance`.

## 4. Scope And Exclusions

In scope:

- result-aware handling of synchronous success versus `awaiting_remote` in the
  maneuver speed-control path;
- purpose-specific `set_speed` handling after accepted ordered Network result
  application;
- canonical-to-token and canonical-to-active-maneuver-preview refresh for the
  matching ship;
- a narrow pre-submission stale-preview guard/invalidation at the existing
  `ShipActivationController` maneuver boundary;
- rejection recovery sufficient to prevent stale local working state remaining
  actionable; and
- focused host/client Network, reconstruction, and lifecycle regressions.

Explicit exclusions:

- changes to `ShipInstance.current_speed` ownership or SetSpeed mutation;
- Status Phase, End Activation, StartRound, or scenario-default correction;
- generic UI synchronization, observable-state, pending-command, action, or
  reconstruction frameworks;
- durable maneuver-preview state;
- command schema, Network protocol, save version, or replay-format changes;
- unrelated immediate speed effects unless needed only for non-regression; and
- BUG-046 architecture or behavior.

## 5. Implementation Slices

### Slice A — Submission-state distinction

1. In the existing maneuver speed-control operation, distinguish synchronous
   accepted success from the `awaiting_remote` sentinel.
2. Do not publish the old `ShipInstance.current_speed` as though it were the
   accepted result on a Network client.
3. Pending local preview may represent the submitted target only as transient,
   non-authoritative working state. Before applying the local delta, retain a
   narrow pre-submit snapshot of the existing activation-local speed delta,
   derived budgets, preview speed, and commit eligibility. Key that pending
   record to both canonical ship identity and the active
   `ship_activation_identity`; it is replaceable by matching acceptance,
   matching rejection, or reconstruction.
4. While that SetSpeed submission is pending, block another speed submission
   and maneuver commit for the same activation. Do not enqueue a later command
   calculated from a canonical value that has not yet accepted the first one.
5. Preserve the existing reversible `ShipActivationState` Navigate delta and
   budget semantics; do not add a second budget owner.

### Slice B — Accepted result convergence

1. Replace the purpose-specific remote `set_speed: pass` behavior with a
   canonical-state-derived presentation refresh after successful ordered
   command application.
2. Resolve the ship by the accepted command owner/index, then use its committed
   `current_speed`; do not trust a preview cache or unaccepted requested value.
3. Refresh the existing ship-token speed presentation through the established
   speed-change surface.
4. If the matching activation maneuver tool is live, update its simulated speed
   and legal geometry from canonical state or invalidate/rebuild it. This
   activation-scoped operation requires both the pending ship identity and its
   captured activation identity to match the current canonical ship/activation.
   Preserve yaw choices only when they remain legal under the accepted speed
   chart; otherwise use existing clamping/rebuild behavior.
5. Apply the same invariant after host-authored synchronous acceptance without
   double mutation or duplicate command submission.

### Slice C — Stale maneuver submission guard

1. Move/evaluate the guard at the entry to the existing
   `ShipActivationController._on_execute_maneuver()` commit path, before any
   maneuver commit-like or irreversible effect. Resolve the current canonical
   ship and require both its ship identity and active activation identity to
   match the live maneuver tool/activation, then compare
   `ManeuverToolState.simulated_speed` with `ShipInstance.current_speed`.
2. The guard SHALL run before all of the following:
   - token snap or final visual placement;
   - overlap calculation that drives resolution or any overlap resolution;
   - `ShipActivationState.mark_maneuver_executed()` or equivalent maneuver-
     executed mutation;
   - resolver-spend or other maneuver side-effect submission;
   - maneuver-opportunity consumption or closure; and
   - `ExecuteManeuverCommand` construction/submission or any authoritative
     maneuver commit.
3. If either identity or speed does not match, do not commit and perform none of
   the effects in item 2. Keep the canonical maneuver opportunity open and
   recoverable. Refresh, invalidate, or re-derive only the matching transient
   preview from canonical state, then require a new deliberate commit action.
4. Do not repair the mismatch by assigning preview speed into the ship,
   silently rewriting an already-constructed command, or adding a generic
   transaction/rollback framework. Correct ordering makes rollback unnecessary.
5. Do not change `ExecuteManeuverCommand` schema or replay semantics in this
   workbook. Any evidence that final command validation itself must change
   triggers the compatibility STOP in Section 6.

### Slice D — Rejection and reconstruction

1. `ShipActivationController`, as the existing owner of the active ship
   maneuver interaction, SHALL consume the existing
   `GameManager.network_command_rejected` signal for the purpose-specific
   `set_speed` case and route matching recovery to its live
   `ManeuverToolScene`/`ShipActivationState`. Do not leave recovery to a generic
   rejection listener or introduce a generic rejection framework.
2. The controller SHALL accept that rejection for activation-scoped recovery
   only when the rejected command's player/ship index resolves to the pending
   canonical ship and the pending captured `ship_activation_identity` still
   equals the current active ship activation identity. A delayed rejection for
   an older identity clears only its stale pending record and SHALL NOT mutate a
   replacement activation or tool.
3. On a matching rejection, canonical `ShipInstance.current_speed` remains
   unchanged and authoritative. Before re-enabling input, the controller SHALL:
   - clear the matching pending SetSpeed record;
   - restore/re-derive the activation-local pending speed delta and its derived
     Navigate budgets from the retained pre-submit transient state;
   - set or rebuild the matching maneuver preview/tool speed from the unchanged
     canonical ship speed and re-clamp legal geometry;
   - refresh the existing token/speed indication from that canonical value;
     and
   - reopen maneuver commit eligibility only after identity and speed match.
4. Matching recovery SHALL mutate only the still-current activation/tool
   instance identified by both identities. It SHALL NOT mutate a replacement or
   reconstructed activation/tool instance and SHALL NOT manufacture canonical
   state.
5. Save/load and reconnect must continue to install canonical speed through
   existing state owners. If a live maneuver decision is reconstructed, create
   a fresh maneuver tool from that installed speed; never serialize
   `ManeuverToolState`.
6. Replay continues to apply recorded semantic commands. No interactive preview
   reconstruction is required unless normal gameplay input is resumed, at
   which point ADR-010 re-derivation applies.

## 6. Gates And STOP Conditions

Implementation may begin only after this workbook is accepted.

STOP and return for Owner direction if implementation appears to require:

1. any conflict with an accepted ADR or contract, a new canonical owner, a
   change to an accepted authority boundary, or a new Owner architecture
   decision;
2. a new canonical speed owner or reverse synchronization from preview to
   canonical state;
3. durable serialization/filtering of `ManeuverToolState` or other preview
   fields;
4. a generic UI synchronization or pending-command architecture;
5. changes to SetSpeed or ExecuteManeuver payload schemas, Network protocol,
   save version, or replay format;
6. changing `ExecuteManeuverCommand` validation in a way that rejects committed
   historical replay evidence; or
7. work in BUG-046 or another activation commitment boundary.

In every such case, STOP rather than infer, improvise, or normalize new
semantics from current implementation convenience.

If a replay-format or fixture change unexpectedly becomes necessary, STOP at
the compatibility boundary. The Owner must decide the format policy, and any
required replay fixture must be captured manually through the real application
under repository governance; it must not be generated or rewritten.

## 7. Focused Regression Requirements

### Canonical and local boundaries

- Accepted `SetSpeedCommand` changes canonical `ShipInstance.current_speed`
  exactly once and returns the accepted old/new values.
- Maneuver, End Activation, Status cleanup, and StartRound do not overwrite the
  accepted speed.
- Host synchronous success refreshes the active maneuver preview to the
  accepted canonical speed.
- A failed/rejected command leaves canonical speed unchanged and cannot leave a
  stale actionable preview.

### Client-authored Network path

- Before acceptance, `awaiting_remote` is not treated as canonical success and
  the old canonical speed is not published as the accepted new value.
- While acceptance is pending, a rapid second speed input and maneuver commit
  cannot enqueue payloads derived from the pre-acceptance canonical value.
- After ordered accepted result application, the client canonical ship, ship
  token, and matching active maneuver preview converge to the accepted speed.
- Reversible changes such as `2 -> 1 -> 2` converge after each acceptance.
- The subsequent maneuver payload uses speed 2 in that sequence, never stale
  preview speed 1.
- Result acceptance/rejection for an unrelated ship or an earlier activation
  identity cannot refresh, reset, or invalidate the current replacement
  preview/activation or consume its maneuver opportunity.

### Host-authored Network path

- Host-authored `2 -> 1` and `2 -> 1 -> 2` changes produce the same canonical
  and preview outcomes as the client-authored path.
- The passive client applies the accepted speed in order and refreshes its ship
  presentation without originating another command.
- The following host-authored maneuver payload matches canonical speed.

### Save/load, reconnect, and replay boundaries

- Existing save/load round trip preserves canonical speed; no preview field is
  serialized.
- Reconnect installs canonical speed and, when returning to a live maneuver
  decision, constructs preview from that speed before enabling commit.
- Existing replay applies recorded SetSpeed history and remains format-
  compatible; no fixture change is expected.

## 8. Verification And Acceptance

Use the existing focused seams below. Add only the listed BUG-043 cases; do not
expand into a broad presentation, Network, persistence, or activation suite.

| Existing focused seam | Required use / minimum BUG-043 addition |
| --- | --- |
| `tests/unit/test_p6_commands.gd` | Retain existing SetSpeed execution, bounds, and serialization coverage. Add no case unless implementation changes that command, which is not expected. |
| `tests/unit/test_ship_activation_state.gd` | Retain reversible speed-delta/budget and serialization coverage. Add only a narrow pre-submit snapshot/rejection-restoration case if that transient operation is added here. |
| `tests/integration/test_ship_activation.gd` | Add the pre-commit stale-preview guard case. Assert identity/speed mismatch causes no token snap/final placement, overlap resolution, maneuver-executed mutation, resolver spend, opportunity consumption, or maneuver submission, and leaves the opportunity open. Cover the normal matching commit as the control. |
| `tests/unit/test_network_command_result_ordering.gd` | Add purpose-specific SetSpeed acceptance/rejection cases: matching ship plus activation identity converges; unrelated ship or stale activation identity cannot touch the current tool; rejection restores the four transient surfaces in Slice D; the next maneuver uses canonical speed. Cover client-authored flow here and retain ordering/gate assertions. |
| existing ManeuverToolScene-focused seam, or the narrowest current scene test file if none exists | Add only synchronous host acceptance, `awaiting_remote` distinction, accepted canonical preview refresh, and matching rejection re-derivation. Do not create a generic UI synchronization test harness. |
| `tests/unit/test_save_load_round_trip.gd` and `tests/unit/test_state_filter.gd` | Retain canonical `current_speed` round-trip/filter coverage and assert no maneuver-preview field is persisted. Add a case only if the existing assertions do not cover those facts. |
| `tests/integration/test_network_resume_and_reassociation.gd` and `tests/acceptance/network_resume/` | Add or extend only the live-maneuver reconstruction case needed to prove a replacement preview is derived from installed canonical speed and delayed old-activation results cannot mutate it. |
| `tests/unit/test_game_replay.gd`, existing maneuver/cleanup/StartRound suites | Run unchanged as compatibility and lifecycle regressions. No new replay fixture or round-transition case is required. |

The minimum new BUG-043 behavior set is therefore:

1. matching accepted SetSpeed result converges canonical ship and matching
   preview for host- and client-authored paths;
2. pending/rejected client SetSpeed restores the same matched activation's
   delta, budgets, preview, indication, and commit gate from canonical state;
3. stale ship/activation identity results cannot mutate a replacement tool;
4. stale-preview commit is stopped before every effect named in Slice C; and
5. reconnect re-derives a fresh preview from installed canonical speed.

Run one real two-process Network acceptance scenario for each authoring side:

1. open the activation maneuver tool at speed 2;
2. submit and accept speed 1, verifying canonical and preview speed 1 on the
   authoring peer and accepted ship presentation on the passive peer;
3. reverse and accept speed 2, verifying preview and canonical speed 2;
4. commit the maneuver and capture evidence that its payload speed is 2;
5. complete activation and round transition, verifying canonical speed remains
   2; and
6. reconnect during a fresh run with the maneuver opportunity still live and
   verify the rebuilt preview starts from installed canonical speed.

Retain command sequence, authoring principal, accepted canonical value, preview
value, and maneuver payload value in the acceptance evidence.

This workbook is complete only when focused and real Network evidence proves
both authoring paths, all compatibility versions remain unchanged, and no
transient preview becomes a gameplay authority.

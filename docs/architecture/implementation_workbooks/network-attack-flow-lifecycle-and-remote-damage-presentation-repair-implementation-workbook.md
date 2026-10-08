# Network Attack-Flow Lifecycle And Remote Damage-Presentation Repair Implementation Workbook

Status: Owner Accepted — 2026-10-08

Purpose: define one coordinated, bounded production repair package for two
distinct defects:

1. **Defect A — High severity:** delayed `PublishAttackFlowCommand` traffic can
   reinstall flow for a retired attack because publication commands do not
   carry and validate their canonical source lifecycle identity.
2. **Defect B — Medium severity:** identity-free remote ship-damage
   presentation falls through to player `-1` and lacks the result-shape
   normalization needed to emit complete ship presentation.

Primary evidence:

- [Network mapping-1 stale attack-flow diagnosis](../evidence/network-mapping-1-stale-attack-flow-diagnosis.md)
- [Preserved independent adversarial audit](../evidence/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-workbook-audit.md)
- [Preserved targeted closure audit](../evidence/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-workbook-closure-audit.md)

The preserved closure record contains the original BLOCKED review and the
second targeted **PASS WITH REQUIRED REFINEMENTS** result. This narrow third
refinement leaves the closed terminal blocker and all other closed findings
closed, and addresses only Counter inspection release plus the concrete
`GameBoard` reconstruction entrypoint in Section 3. It does not implement
either repair.

## 1. Classification, Authority, And Entry Status

Classification: **Bounded Architecture / bounded cross-cutting production
repair with explicit Network and replay compatibility cutovers**.

Binding authority, in precedence order:

1. accepted [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
   and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
   for canonical current-attack ownership, lifecycle identity, stale-command
   rejection, atomic failure, derived flow, replay, and Network mirroring;
2. accepted [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md)
   for completed-result inspection release into existing enclosing owners;
3. accepted [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md)
   for endpoint/principal/player-side separation during resume and
   reassociation; and
4. accepted [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md)
   for command-owned result application and the prohibition on presentation
   or transport becoming a canonical mutation owner.

### 1.1 Owner decisions incorporated

The Project Owner has decided:

1. **Inter-attack publications:** after one attack retires and before the next
   `BeginAttackCommand` succeeds, do not invent or extend an attack identity.
   Suppress noncanonical ATTACK-flow publications and present target selection
   transiently from the already-authoritative enclosing activation/gameplay
   route.
2. **Compatibility cutover:** save format remains 10; Network protocol advances
   10 → 11; replay format advances 11 → 12. Do not add compatibility machinery
   solely to preserve development-era Network/replay publication commands that
   lack source identity. Affected replay fixtures must be manually recorded by
   the Owner.

### 1.2 Authority check for the inter-attack decision

The Owner decision is compatible with accepted architecture:

- ADR-001 Sections 2.1 and 2.6 and CON-001-LIFE-018, VAL-005, BOUND-005,
  BOUND-006, and MIG-005 make `CurrentAttackState` authoritative and attack
  flow/scene mirrors derived. Suppressing a mirror when no attack lifecycle
  exists follows those obligations.
- CON-007 releases a completed attack into its existing context-specific
  enclosing owner. It does not create an attack identity for target selection
  before a later Begin succeeds.
- Production already owns between-attack eligibility in enclosing Ship or
  Squadron activation/gameplay state and presents the attacker’s next-target
  choice through `TargetSelector` and the attack panel. Current
  `_attack_exec_prepare_next_squadron()` and
  `_attack_exec_prepare_next_attack()` additionally write/publish an ATTACK
  flow after the previous `CurrentAttackState` is inactive; those are the
  noncanonical operations to remove, not an authority to preserve.
- The Counter path has two distinct states. The parent attack's canonical,
  source-scoped `ATTACK_COUNTER_CHOICE` projection remains authoritative
  projection for validating the accepted choice and child Begin. Only the
  child Counter attack's premature pre-Begin scene/FSM write is transient and
  suppressed. Parent completion/inspection satisfaction releases child Begin
  through the existing authoritative continuation surface; a child-source
  ATTACK publication begins only after that Begin installs its new
  `CurrentAttackState`.

No accepted contract requires an ATTACK `InteractionFlow` while no canonical
attack is active. No new continuation or lifecycle owner is needed. If
implementation evidence contradicts this conclusion, stop rather than invent
state.

Entry status: implementation may begin only after a targeted independent
closure audit and Project Owner acceptance. This revised draft authorizes no
production, test, fixture, version, or baseline change by itself.

## 2. Fixed Defect Boundaries And Required Outcomes

### 2.1 Defect A — lifecycle-scoped attack-flow publication

The repair must establish a command-owned source identity that is captured
from canonical state when the publication is created, transported with the
command, and validated immediately before mutation.

Required outcome:

- Every applicable post-Begin publication carries a required top-level
  `source_attack_id` copied from the exact canonical
  `CurrentAttackState.attack_id` at command creation.
- The producer also places that same identity in the published ATTACK-flow
  payload so the installed projection identifies its source.
- `PublishAttackFlowCommand.validate()` never supplies a missing identity from
  whichever attack happens to be active when a queued command executes.
- Non-final publication requires an active canonical attack whose identity
  exactly equals `source_attack_id`.
- Fresh Ship, fresh Squadron, Counter, and reconstructed/resumed attack paths
  all use the same producer and identity rule after Begin is accepted.
- Fresh Ship/Squadron and child Counter pre-Begin target selection, plus
  between-attacks target selection, publish no new canonical ATTACK flow and
  no `PublishAttackFlowCommand`. This does not erase the accepted parent
  attack's `ATTACK_COUNTER_CHOICE` projection during Counter handoff.
- Ordinary terminal clearing preserves the retiring source identity and
  creates the final command from the accepted retiring transaction's
  pre-mutation ATTACK projection. It queues that command on the existing
  `CommandProcessor` post-success/observer-follow-up seam; Network distributes
  the triggering result before draining and distributing the final command.
- A parent attack whose accepted `ATTACK_COUNTER_CHOICE` is required by child
  Counter Begin deliberately has no ordinary terminal clear at retirement.
  Its projection survives completed-inspection installation and satisfaction
  until the authoritative continuation surface queues accepted child Begin and
  a child-source publication replaces it.
- A terminal clear applies only when the currently installed ATTACK projection
  carries that exact source identity and no active replacement attack exists.
- Missing, malformed, retired, mismatched, duplicated, delayed, or out-of-order
  source identity rejects before mutation and leaves authority/order unchanged.
- FIFO timing, queue pruning, coalescing, or cancellation is never the
  correctness mechanism.

### 2.2 Defect B — exact target derivation and outcome normalization

The repair must distinguish complete explicit result identity from the known
identity-free `resolved_outcome` shape and fully normalize the latter for the
existing presentation handler.

Required outcome:

- When either `owner_player` or `ship_index` is present, both must be present,
  exact integers, in range, and resolve the identified canonical ship. Partial,
  mistyped, invalid, or out-of-range explicit identity fails; it never falls
  back.
- Canonical fallback is eligible only when both explicit identity fields are
  absent, `target_kind == "ship"`, the command is `resolve_damage`, and the
  active canonical attack exactly matches the command `attack_id` and targets
  a ship.
- After fallback resolves the ship, a narrow identity-free normalization maps:
  - `affected_zone` → canonical hull-zone string used as `hull_zone`;
  - `post_resolution_shields` → `new_shields`;
  - `hull_damage` → the card/hull refresh count;
  - `shield_absorbed`, `final_damage`, and `destroyed` to their existing
    presentation meanings.
- Normalization validates the recognized shape and reconciles it with the
  already-mutated canonical `ShipInstance`; it does not replay damage.
- Hull/card presentation refresh reads the canonical ship's faceup/facedown
  state rather than requiring card identities in `resolved_outcome`.
- Shield-only, facedown hull, faceup/inspection, and lethal outcomes emit the
  complete existing presentation signals for the correct ship.
- No path treats `-1`, endpoint, principal, host/client role, active player,
  command submitter, or UI state as target identity.

The two defects retain separate roots: Defect A is command lifecycle admission;
Defect B is presentation identity/result-shape consumption. Fixing one is not
evidence for the other.

## 3. Independent Audit Dispositions

### 3.1 Blockers

| Audit blocker | Revised disposition |
| --- | --- |
| Required `attack_id` is absent from current legitimate publications | **Resolved in specification.** Sections 2.1, 4.1, and 6 require the central producer to add top-level `source_attack_id` and the same installed-flow source identity at command creation. Fresh Ship, Squadron, Counter, and reconstructed paths are explicit. Execution-time lookup is prohibited. |
| Current inter-attack publications have no active attack | **Resolved by Owner decision.** Sections 1.2, 4.1, 5, 6, and 8 suppress the publication and direct canonical ATTACK-flow write. Target selection remains transient and derives from the existing enclosing activation/gameplay route. No identity or owner is invented. |
| Terminal clears carry no source attack identity | **Resolved in specification.** Sections 2.1, 4.1, 6, and 8 require source capture from the accepted retiring transaction's pre-mutation projection, a final command carrying that source, and comparison with the installed ATTACK projection source. The command uses the existing deferred follow-up seam and is omitted for an accepted parent Counter handoff. A delayed clear cannot clear a newer attack. |
| Compatibility claims contradicted repository evidence | **Resolved by Owner cutover.** Sections 1.1, 9, and 10 fix save 10, Network protocol 11, replay format 12, no missing-identity compatibility path, and Owner-manual replacement recording for affected replay fixtures. |

### 3.2 Required refinements

| Audit refinement | Revised disposition |
| --- | --- |
| Normalize identity-free ship result shape | **Resolved in specification.** Sections 2.2, 4.2, 7, and 8 define the narrow field mapping, canonical card refresh, and shield-only/facedown/faceup/lethal evidence. |
| Make fallback eligibility exact | **Resolved in specification.** Fallback is allowed only when both explicit identity fields are absent. Any partial or invalid explicit identity fails without fallback. |
| Keep optional broad full-state validator off by default | **Resolved.** Section 4.3 places `GameState` live-validator expansion outside this repair. Existing deserialize/StateFilter fail-closed behavior remains unchanged. |
| Expand regression matrix around producer and terminal semantics | **Resolved in specification.** Section 8 covers producer-time capture, fresh/reconstructed paths, inter-attack suppression, source-scoped terminal clear, exact result shapes, both role mappings, protocol 11, replay 12, and manual fixtures. |

### 3.3 Optional audit improvements

- Implementations may distinguish malformed, stale-active, retired-source, and
  mismatched-final diagnostics, but logs are not a correctness oracle.
- Ship and Squadron canonical target lookup may share a narrow read-only helper
  only if it remains a lookup utility and creates no identity, result, or
  continuation framework.

No original-audit blocker or required refinement is deferred.

### 3.4 Targeted closure-audit dispositions

| Closure finding | Second-refinement disposition |
| --- | --- |
| Terminal publication is blocked by `CompletedAttackInspection` | **Resolved in specification.** Sections 4.1 and 6.4 add one exact admission predicate: only a `final == true` publication whose `source_attack_id` equals both the installed ATTACK projection source and `CompletedAttackInspection.source_attack_id()` may pass while that inspection exists. The exception applies before the unsatisfied-inspection rejection but does not admit a non-final, mismatched, malformed, duplicate, or unrelated command. The same exact terminal predicate is admitted through terminal-match cleanup preflight when applicable. |
| Host terminal publication can execute/broadcast reentrantly | **Resolved in specification.** Sections 4.1 and 6.5 require derivation through `CommandProcessor`'s existing post-success/observer-follow-up queue. `submit_deferred_followups()` completes the trigger; `NetworkManager` distributes its result; only then `_drain_server_observer_followups()` submits and distributes the terminal command. `command_executed` presentation callbacks may not submit it. |
| Generic parent clear erases Counter replacement authority | **Resolved in specification.** Sections 5.1, 6.2, 6.4, and 8 preserve the parent-source `ATTACK_COUNTER_CHOICE` after accepted choice and parent retirement. Child Begin validates that projection, installs a new child source, and its first publication replaces the parent projection. No parent clear is queued for this handoff; any delayed parent clear rejects against the active child source. |
| Counter distinction was too broad | **Resolved in specification.** Parent Counter-choice publication is canonical and retained; only the child Counter's premature pre-Begin ATTACK write/publication is suppressed. No Counter continuation owner is added. |
| Inter-attack presentation consumers were unnamed | **Resolved in specification.** Sections 4.1 and 5.2 authorize the existing `UIProjector` → `ModalRouter` → `AttackPanelController` reconstruction route and `AttackExecutor.resume_inactive_ship_attack_continuation()` renderer. The route derives a transient local-selection/remote-waiting intent from existing Ship activation facts without writing ATTACK flow. Live, save/load, and reconnect use the same route. |

No targeted closure finding requires a new architecture mechanism. The
ordering seam and reconstruction consumers named above already exist in
production; the repair only narrows how they are used. No targeted-closure
blocker or required refinement from that first closure audit is deferred.

### 3.5 Second targeted closure-audit dispositions

The preserved second result is **PASS WITH REQUIRED REFINEMENTS**.

| Second-closure finding | Third-refinement disposition |
| --- | --- |
| Terminal-publication blocker | **CLOSED and not reopened.** Sections 6.4–6.5 retain the already-approved exact terminal admission and existing deferred Network ordering without substantive change. |
| Counter child entry after inspection | **Resolved in specification.** Sections 4.1, 5.1, 6.6, 8, and 11 require the existing `CurrentAttackContinuation` inspection-release evaluator to derive the already-accepted child Counter Begin only after exact-ID inspection satisfaction. Live authority queues it through the existing `CommandProcessor` follow-up seam; passive Network mirrors and replay synthesize nothing. |
| Actual `GameBoard` reconstruction entrypoint | **Resolved in specification.** Sections 4.1, 5.2, 8, and 11 restrict the early board resume to active attacks and route inactive inter-attack reconstruction through `_command_router_adapter.reconstruct_presentation()` only after router/viewer setup. Save/load and reconnect must test the real ready/reload entrypoint. |

Neither refinement creates a new owner or serialized field. No second-closure
required refinement is deferred.

## 4. Authorized Production Scope

### 4.1 Defect A — producer, consumer, and lifecycle choreography

| Surface | Authorized bounded change |
| --- | --- |
| `src/autoload/game_manager.gd` central `submit_publish_attack_flow()` producer | Create protocol-11/replay-12 command payloads with required `source_attack_id`. For an applicable non-final post-Begin publication, snapshot the currently active canonical `CurrentAttackState.attack_id` once when constructing the command; copy it into the outgoing flow payload. Accept an explicitly preserved terminal source only for final clearing. Refuse/suppress no-active non-final publication. |
| `src/autoload/game_manager.gd` reconstructed inspection release | When the existing reconstructed release evaluator returns the automatic accepted-Counter child Begin, submit it through the existing `submit_authoritative()` route, as with other authority-derived attack continuations, so host principal ownership of the child attacker is irrelevant. Do not broaden authoritative submission for player choices or ordinary inspection consumers. |
| `src/autoload/command_processor.gd` | Add a narrow terminal-publication derivation to the existing post-success/observer-follow-up queue. It may derive only from an accepted attack-retiring command and its pre-execution ATTACK `flow_snapshot`; it copies that matching source into a final command, does not look up a later attack, and is independent of presentation callbacks. Add the exact completed-inspection and terminal-cleanup preflight exception in Section 6.4. Omit the terminal follow-up when an accepted parent `ATTACK_COUNTER_CHOICE` must survive for child Counter Begin. After the exact final acknowledgement satisfies that inspection, invoke the existing `CurrentAttackContinuation` evaluation and enqueue its child Begin through the same authoritative post-success queue. Live authority alone derives it; Network mirrors and replay do not. This is use of the existing ordered follow-up seam, not a new queue or lifecycle owner. |
| `src/core/state/current_attack_continuation.gd` | Extend the existing completed-inspection release branch narrowly for an accepted Counter handoff. Require a satisfied inspection whose `source_attack_id` matches the installed parent-source `ATTACK_COUNTER_CHOICE`, require `counter_choice_accepted == true`, validate the recorded child participant identities against canonical Squadron state/targeting, and return exactly one `BeginAttackCommand` carrying the exact `completed_attack_inspection_id` plus the existing Counter declaration fields. It remains a stateless evaluator and submits nothing. Replay/passive modes retain the existing no-synthesis rule. |
| `src/scenes/game_board/attack_executor.gd` | Route fresh Ship, Squadron, Counter, and reconstructed post-Begin publications through the central producer. Preserve the parent-source `ATTACK_COUNTER_CHOICE` through accepted choice, parent retirement, and inspection satisfaction. Suppress only the child Counter's premature pre-Begin live ATTACK write/publication. Remove semantic reliance on `apply_complete_attack_result()`/`command_executed` reentrantly submitting the child Begin. The accepted authoritative child Begin result may only rebuild/rebind child presentation from canonical state and trigger the already-authorized post-Begin source-scoped projection path; it must not submit a second Begin or publish before the Begin result's required Network ordering. Remove/suppress direct live-`GameState` ATTACK-flow restart/patch publication between attacks. Do not submit terminal publication from `command_executed`; scene/FSM cleanup observes command-owned clearing and performs no second canonical clear. Make inactive ship-continuation reconstruction render from canonical activation facts without assigning `GameState.interaction_flow`. |
| `src/core/commands/publish_attack_flow_command.gd` | Require exact new payload schema and source identity. Validate non-final source against active canonical attack. Validate final source against the currently installed ATTACK projection's source and absence of active replacement. Reject before mutation on every mismatch. Accepted execution remains projection-only. |
| `src/core/combat/attack_flow_fsm.gd` | Narrow cleanup choreography is authorized so scene/FSM reset can occur after command-owned authoritative clearing without `end()` first clearing live `GameState`. It must not own, derive, validate, or queue lifecycle identity. |
| `src/core/combat/attack_flow_executor.gd` | Verification only. Presentation identity patches need not become an authority source; the central producer supplies canonical source identity. |
| `src/core/commands/game_command.gd` | Update exact/canonical command-payload handling only as required for the new string `source_attack_id` schema. No generic command-schema framework. |
| `src/core/network/ui_projector.gd` | Before the current NONE-flow early return, derive a transient inter-attack selection/waiting intent from the unique active Ship activation and its existing attack-progress facts. The intent may identify the existing continuation kind/controller for rendering, but is not persisted, serialized, validated as gameplay, or exposed as ATTACK flow. |
| `src/scenes/game_board/modal_router.gd` | Route the derived inter-attack intent on ordinary live reprojection and `reconstruct_presentation()`: local controller goes to the established attack-panel reconstruction seam; a noncontroller receives passive waiting presentation. Do not synthesize or submit a command. |
| `src/scenes/game_board/attack_panel_controller.gd` | Consume the derived intent through the existing inactive ship-attack reconstruction methods. Render local next-squadron/next-hull-zone selection or remote waiting/closed controls without installing ATTACK flow and without selecting gameplay progression. |
| `src/scenes/game_board/game_board.gd` | Restrict `_resume_active_attack_from_state()` and its early ready-sequence branch to a genuinely active `CurrentAttackState`. Do not call inactive direct attack reconstruction before the command router exists. After `_create_command_router_adapter()`, signal/viewer setup, phase/active-player projection, and declaration-adjacent restoration, include inactive canonical inter-attack decisions in the existing `_command_router_adapter.reconstruct_presentation()` pass. Preserve result/inspection precedence and invoke reconstructed authoritative continuation release only after presentation reconstruction. |
| `src/autoload/network_manager.gd` | Advance `PROTOCOL_VERSION` 10 → 11 and retain strict handshake mismatch rejection. Preserve the existing `submit_deferred_followups()` → trigger distribution → `_drain_server_observer_followups()` order for both remote-authored and host-authored commands; terminal publication must use that order. No protocol-10 adapter. |
| `src/core/commands/game_replay.gd` | Advance `FORMAT_VERSION` and `SIGNED_FORMAT_VERSION` 11 → 12 and retain strict current-format loading. No replay-11 publication backfill or migration. |

The source identity is command intent/applicability data, not a second attack
owner. It is copied from canonical authority at creation and cannot change if
delivery is delayed.

### 4.2 Defect B — canonical lookup and narrow normalization

| Surface | Authorized bounded change |
| --- | --- |
| `src/autoload/game_manager.gd` explicit ship lookup | Require both explicit identity fields together and validate types/ranges before any player lookup. Never call `get_player_state(-1)`. Never fall back from partial or invalid explicit identity. |
| `src/autoload/game_manager.gd` active-attack fallback | Add the ship analogue of the existing Squadron fallback, requiring both explicit fields absent, recognized identity-free ship shape, matching active command/attack identity, and ship defender kind. |
| `src/autoload/game_manager.gd` result normalization | Add a narrow identity-free ship-outcome normalization step mapping the fields in Section 2.2 and refreshing card/summary state from the canonical `ShipInstance`. Preserve existing signal ownership and order where behavior is already correct. |
| Resolve-damage command, canonical outcome, and result envelope | Verification only. No canonical damage mutation, `resolved_outcome`, application-result, transport-result, or command-result schema change is expected or authorized. |

### 4.3 Explicitly outside production scope

The broad `GameState.validate_for_full_authority_installation()` alignment from
the first draft is **not part of this repair**. It may be considered only in a
separate evidence-backed task proving safety across fresh attacks,
between-attack selection, completed inspection, cancellation, Counter
replacement, terminal completion, direct host scene writes, save/load, replay,
and reconnect. Existing deserialize and StateFilter fail-closed checks remain
unchanged here.

## 5. Inter-Attack And Counter Behavior

### 5.1 Counter is a replacement handoff, not the ordinary inter-attack gap

Counter has this exact lifecycle:

1. parent attack source **P** is active;
2. the parent publishes canonical `ATTACK_COUNTER_CHOICE` carrying **P**;
3. `CounterChoiceCommand(accepted == true)` validates and marks that same
   parent-source projection accepted;
4. existing `CurrentAttackContinuation` derives parent
   `CompleteAttackCommand`; the ordinary authoritative follow-up queue executes
   and distributes it;
5. parent completion installs `CompletedAttackInspection(I)` and retires
   `CurrentAttackState(P)`, but the accepted parent-source projection remains
   installed and no terminal clear for **P** is queued;
6. while inspection **I** is unsatisfied, no child Begin is derived or
   submitted. Scene `command_executed` handling may retain/reconcile transient
   presentation, but it does not author the child attack;
7. each acknowledgement carries **I**. Only the acknowledgement that makes
   inspection **I** satisfied reaches the existing authoritative
   `CurrentAttackContinuation` inspection-release branch;
8. that evaluator verifies inspection source **P**, the installed
   parent-source `ATTACK_COUNTER_CHOICE`, its accepted flag, and the canonical
   child Squadron identities. It returns exactly one child
   `BeginAttackCommand` with `completed_attack_inspection_id == I` and the
   existing Counter declaration payload;
9. `CommandProcessor` queues that Begin through its existing post-success
   follow-up mechanism. On Network authority, the final acknowledgement result
   is distributed before the queued Begin executes/distributes. The server
   authors this authoritative follow-up regardless of which endpoint controls
   the child Counter attacker;
10. child Begin revalidates exact inspection **I** and the accepted parent
   projection, atomically consumes **I**, and installs child source **C**;
11. only after accepted child Begin and its required Network result ordering
   does the central producer snapshot **C** and publish the child's first
   projection, replacing parent projection **P**; presentation reaction may
   rebuild the child panel but cannot resubmit Begin; and
12. any delayed or manually delivered terminal clear for **P** now rejects
   unchanged because child **C** is active and/or the installed ATTACK source
   is **C**.

Declined Counter follows ordinary parent completion/terminal behavior after the
choice result removes the pending child handoff. This distinction adds no
Counter continuation owner: `CounterChoiceCommand`, the parent projection, and
`BeginAttackCommand` retain their existing validation roles, while the existing
stateless `CurrentAttackContinuation` surface performs its normal authoritative
post-inspection derivation.

### 5.2 Ordinary inter-attack presentation and reconstruction

For next-squadron and second-hull-zone selection after the previous attack
retires and before a new Begin succeeds:

1. no active `CurrentAttackState` exists and no attack identity is extended;
2. `AttackExecutor` may reset local scene/FSM selection state without passing
   live `GameState` to an ATTACK transition;
3. `_publish_clear_target_patch()` and `restart_for_next_attack(game_state)`
   must not write or publish a no-active canonical ATTACK flow;
4. no `PublishAttackFlowCommand` is submitted and command history/cursor do not
   advance for target-selection presentation;
5. existing `ShipInstance` facts—active activation identity,
   `attack_step_active`, committed attack count, used hull zones,
   anti-squadron zone and target history—plus existing target legality are the
   sole source for the transient decision;
6. `UIProjector.project()` derives a viewer-specific inter-attack intent before
   its NONE-flow early return. The intent is presentation data only: it does
   not set `flow_type == ATTACK`, install an `InteractionFlow`, or survive as a
   durable owner;
7. `ModalRouter` passes that intent to `AttackPanelController`. For the
   controlling viewer, the controller reuses
   `AttackExecutor.resume_inactive_ship_attack_continuation()` and the existing
   `TargetSelector`/attack panel renderer. That method must stop assigning a
   synthesized ATTACK flow. For the noncontrolling viewer, the router/projector
   shows passive waiting and keeps attack inputs/mirror noninteractive;
8. successful `BeginAttackCommand` creates the next attack identity; only then
   may the first source-scoped ATTACK publication be created; and
9. `GameBoard._finalize_ready_sequence()` calls its early active-attack resume
   only when `CurrentAttackState.active == true`; inactive canonical state does
   not enter `resume_inactive_ship_attack_continuation()` before router setup;
10. after `_create_command_router_adapter()`, signal wiring, local viewer
   identity availability, phase/active-player projection, and
   declaration-adjacent restoration, `GameBoard` includes the inactive
   inter-attack condition in its existing
   `_command_router_adapter.reconstruct_presentation()` pass; and
11. live command-result reprojection, save/load reconstruction, and reconnect
   reconstruction then all enter through the same
   `UIProjector` → `ModalRouter` → `AttackPanelController` route and produce the
   same local-selection versus remote-waiting result without a canonical
   ATTACK-flow write.

The transient intent may reuse existing continuation labels for rendering; it
is not a serialized continuation record and cannot authorize Begin or Skip.
If the existing canonical Ship activation facts and target legality cannot
deterministically produce one controller/decision, implementation stops. This
workbook does not authorize a new durable between-attacks state, continuation
descriptor, or generic lifecycle.

## 6. Publication Identity And Terminal-Clear Model

### 6.1 Command schema for protocol 11 / replay 12

Every `publish_attack_flow` command has the exact semantic payload:

```text
step_id: int
controller_player: int
flow_payload: Dictionary
final: bool
source_attack_id: String
```

For a non-final command, `source_attack_id` is non-empty and
`flow_payload.attack_id` must equal it. For a final command, the flow payload
may be empty, but `source_attack_id` remains required.

Missing, extra where exact-schema enforcement applies, mistyped, malformed, or
noncanonical source identity rejects. A protocol-11 or replay-12 command may
not infer, default, or reconstruct it from execution-time state.

### 6.2 Producer-time capture

- **Fresh Ship:** after accepted Begin installs the attack, the first Declare
  patch and all later publications snapshot that active identity.
- **Fresh Squadron:** same rule after accepted Begin; pre-Begin target selection
  remains transient.
- **Counter:** the parent attack's `ATTACK_COUNTER_CHOICE` publications retain
  the parent identity. After accepted choice, that projection survives parent
  retirement. Only the child Counter's scene setup is transient; after child
  Begin validates the parent projection and installs the child attack, the
  first child publication snapshots the child identity and replaces it.
- **Reconstructed/resumed attack:** the reconstructed active canonical attack
  supplies the source at each newly created publication. Existing projected
  identity must agree; disagreement rejects locally rather than being repaired.

The producer captures once into the serialized command. Command execution
compares that captured value; it never replaces it with a later active attack.
For terminal publication, `CommandProcessor` copies the retiring source from
the accepted command and matching pre-execution ATTACK `flow_snapshot` into the
queued final command before any presentation cleanup can reset its FSM. No
scene-retained identity is authoritative or needed, and a later Begin captures
its own new id.

### 6.3 Non-final validation

A non-final publication accepts only when:

1. `source_attack_id` is structurally valid;
2. canonical `CurrentAttackState` exists and is active;
3. its `attack_id` exactly equals `source_attack_id`;
4. `flow_payload.attack_id` exactly equals `source_attack_id`;
5. existing command applicability, player/principal admission, FlowSpec, and
   registered rule validation also pass; and
6. execution can install a reconstructable derived ATTACK flow.

Failure uses the existing atomic rejection path: no flow/state mutation,
history/cursor advancement, follow-up, or success presentation.

### 6.4 Exact terminal derivation and admission

The existing `CommandProcessor._submit()` pre-execution `flow_snapshot` and
post-success follow-up queue provide the bounded terminal seam. After an
accepted command retires source **S**, a narrow derivation may enqueue a final
`PublishAttackFlowCommand` only when all of these creation facts hold:

1. the pre-execution projection is ATTACK and carries source **S**;
2. the accepted retiring command/result identifies the same **S**;
3. post-execution `CurrentAttackState` is inactive;
4. the same source-scoped ATTACK projection remains installed; and
5. it is not the accepted-parent-Counter handoff described in Section 5.1,
   identified exactly by the parent `ATTACK_COUNTER_CHOICE` projection with
   `counter_choice_accepted == true`.

The final command copies **S** and the retiring command's attacker player at
that point. It is not created or submitted by
`AttackExecutor`, `ModalRouter`, `AttackPanelController`, or any
`command_executed` callback. `AttackFlowFSM.end()` must not clear live
`GameState` first; later scene/FSM cleanup resets only transient state.
When the same accepted transaction also derives an existing semantic follow-up
(including terminal-match completion), the final projection command is queued
first so it validates against the still-installed source **S**; the semantic
follow-up retains its existing owner and follows in the same FIFO drain. The
Counter exception remains the only handoff that intentionally omits this
ordinary final command.

The exact final-command validation/admission predicate is:

1. command type is `publish_attack_flow`, `final` is exactly `true`, and
   `source_attack_id` is a structurally valid non-empty string;
2. no canonical current attack is active;
3. authoritative `interaction_flow.flow_type == ATTACK`;
4. installed `interaction_flow.payload.attack_id` exactly equals
   `source_attack_id`;
5. no newer/replacement attack or non-ATTACK enclosing flow owns authority;
6. when `CompletedAttackInspection` exists, its
   `source_attack_id()` exactly equals the command source and its recorded
   attacker player equals the final command's player; and
7. the installed projection's attacker identity agrees with that player, and
   existing command/player/schema/rule checks otherwise pass.

`CommandProcessor._check_completed_attack_inspection()` evaluates this exact
matching-final exception before its unsatisfied-inspection rejection. It does
not allow a non-final publication, another command type, a partial/malformed
payload, or a source mismatch. If terminal-match cleanup preflight would
otherwise reject the same command, `_check_terminal_admission()` admits only
this same exact matching-final predicate; it gains no general
`publish_attack_flow` whitelist.

Accepted execution clears only that matching ATTACK projection. If authority
is already NONE/non-ATTACK, the derivation omits the redundant clear or the
command rejects without mutation. If child Counter or another attack is
active, or a newer ATTACK source is installed, the older clear rejects. A
duplicate clear also rejects unchanged.

### 6.5 Network and replay ordering

Terminal publication uses the existing deferred-follow-up order:

```text
accepted retiring command
→ CommandProcessor.submit_deferred_followups() completes it and queues final S
→ NetworkManager completes server-side distribution/broadcast dispatch of the
  retiring command result
→ NetworkManager._drain_server_observer_followups()
→ final S validates, executes, and is distributed/broadcast
```

This is already the production order for both remote-authored commands and
`NetworkHostCommandSubmitter`/`handle_host_command()`. The implementation may
add the narrow terminal derivation to the existing queue, but may not add a
generic queue, defer by timer/call-deferred, or rely on coalescing/cancellation.
In non-Network live authority, the same queue drains after the triggering
command completes. Replay does not synthesize the follow-up: format-12 history
contains the recorded terminal command immediately after its trigger, and
`submit_replay` validates/applies that sequence without live observer
derivation.

### 6.6 Authoritative Counter inspection release

`CurrentAttackContinuation` is the existing authoritative attack-continuation
surface. Its Counter inspection-release branch may return a child Begin only
when all of the following hold simultaneously:

1. `CompletedAttackInspection` exists and `is_satisfied()` is true;
2. its exact `inspection_id()` is copied to
   `BeginAttackCommand.payload.completed_attack_inspection_id`;
3. its `source_attack_id()` equals the installed ATTACK projection's
   `payload.attack_id`;
4. that projection is exactly `ATTACK_COUNTER_CHOICE` with
   `counter_choice_accepted == true`;
5. its four recorded Counter participant fields identify two existing,
   non-destroyed canonical Squadrons in the accepted reversed attacker/target
   roles; and
6. the existing authoritative Counter target/range/rule checks can produce the
   ordinary `BeginAttackCommand` payload without scene state.

The returned command uses the child Counter attacker as `player_index`, but
live Network authorship remains server-authoritative. `CommandProcessor`
invokes this evaluator after the successful acknowledgement, queues the result,
and `NetworkManager` distributes the acknowledgement before draining the Begin.
The client controlling that child attacker neither authors nor resubmits it.

An unsatisfied, stale-ID, wrong-source, unaccepted, malformed, destroyed, or
illegal participant state returns no continuation and consumes nothing. The
evaluator remains stateless and returns at most one existing command type. It
does not store a continuation, mutate authority, or submit work.

Replay execution mode derives no child command. Format-12 history records the
explicit `BeginAttackCommand` with the exact inspection ID after the final
acknowledgement; replay validates, consumes the inspection, and installs the
recorded child source in that order. Reconstruction on live authority may use
the existing reconstructed-inspection-release entrypoint to evaluate the same
durable facts once. If it returns this automatic Counter Begin, that entrypoint
uses the existing authoritative submitter rather than host-principal
submission; passive reconnect peers synthesize nothing.

## 7. Remote Ship-Damage Presentation Normalization

### 7.1 Exact identity branching

For a ship result:

- **Neither identity field present:** fallback is considered only for a
  `resolve_damage` command with `target_kind == "ship"` and the complete
  recognized identity-free outcome shape.
- **Exactly one identity field present:** fail presentation closed; no fallback.
- **Both present:** require exact integer types, valid player/index ranges, and
  exact canonical ship resolution; any failure ends the branch with no
  fallback.

Fallback then requires an active canonical attack whose `attack_id` matches the
command payload and whose defender kind is ship. The ship is resolved from that
attack's canonical defender player/index.

### 7.2 Narrow outcome normalization

For the eligible identity-free branch only:

1. validate `affected_zone` as a legal ship hull-zone enum and derive the
   canonical zone string;
2. validate `post_resolution_shields`, `shield_absorbed`, `hull_damage`, and
   `final_damage` as nonnegative integral outcome values;
3. validate `destroyed` as a boolean and require consistency with the already
   applied canonical ship state;
4. construct only the local presentation view expected by the existing
   handler: `hull_zone`, `new_shields`, card/hull refresh count,
   `shield_absorbed`, `final_damage`, and `destroyed`;
5. emit shield refresh from the normalized zone/current canonical shields;
6. when `hull_damage > 0`, refresh hull and damage-card/summary presentation
   from the canonical ship's current faceup/facedown collections; and
7. for lethal state, emit the existing zero-hull/destruction presentation and
   elimination check.

This normalization is local presentation data. It is neither persisted nor
transported and does not mutate the ship, attack, damage deck, inspection, or
command result.

### 7.3 Required outcome shapes

- **Shield-only:** correct shield zone/value refresh; no false hull/card event.
- **Facedown hull:** correct hull decrement plus canonical damage-card column
  and summary refresh.
- **Faceup/inspection:** correct hull/card/summary refresh including the
  canonical faceup collection; existing faceup inspection remains owned by its
  accepted state/command path.
- **Lethal:** all applicable shield/card refresh plus hull zero, destruction
  presentation, and elimination check for the exact canonical defender.

## 8. Required Regression Matrix

| Area | Required evidence |
| --- | --- |
| Central producer schema | Protocol-11/replay-12 commands contain exact `source_attack_id`; non-final installed flow payload contains the same id; serialization round-trip preserves both. |
| Capture timing | Queue a command for attack A, install/retire or replace with attack B before delivery, and prove the serialized command still carries A and rejects; no execution-time identity substitution. |
| Fresh Ship publication | No pre-Begin publication; accepted Begin produces first source-scoped Declare publication; representative Roll, Modify, Defense, Resolve Damage, and valid terminal paths retain the same id. |
| Fresh Squadron publication | Same post-Begin identity proof for Squadron attack; pre-Begin target selection remains transient. |
| Counter parent publication | Parent source **P** publishes `ATTACK_COUNTER_CHOICE`; accepted choice remains source-scoped to **P**; parent completion installs inspection **I**; retirement preserves the accepted projection, queues no parent terminal clear, and derives no child Begin while **I** is unsatisfied. |
| Counter inspection release and child replacement | Run the exact sequence **P** → `ATTACK_COUNTER_CHOICE` → accepted choice → parent completion/retirement → unsatisfied inspection **I** → exact-ID acknowledgements → **I** satisfied → `CurrentAttackContinuation` returns child Begin carrying **I** → authoritative queue orders final acknowledgement distribution before Begin → Begin consumes **I** and installs **C** → after Begin result ordering, first child publication replaces **P** → delayed parent clear rejects without mutation. Prove wrong/stale inspection ID, premature derivation, duplicate derivation, scene reentrant Begin submission, and publication-before-Begin-result do not occur. |
| Counter Network role mappings | Run the full inspection-release sequence with host controlling the child Counter attacker and with client controlling it. In both cases the server-side live-authority evaluator authors/queues Begin, command `player_index` remains the canonical child attacker, broadcast order is identical, and passive peers synthesize nothing. |
| Counter replay | Owner-recorded format-12 history contains final exact-ID acknowledgement followed by explicit child `BeginAttackCommand`; replay derives no continuation, validates/consumes **I**, installs **C**, applies child replacement, and rejects delayed parent clear. |
| Reconstructed attack | Save/load and reconnect reconstruct active canonical identity; newly created publications carry it; a conflicting scene/projection identity rejects rather than being repaired. |
| Inter-attack next-squadron | After retirement, clear-target/restart publication and direct ATTACK write are suppressed; `UIProjector` derives controller/waiting from canonical Ship attack progress; `ModalRouter`/`AttackPanelController` render local selection versus remote waiting; no command/history/cursor change occurs; next Begin creates a new id. Prove live play plus save/load and reconnect through the actual `GameBoard._ready()`/`_finalize_ready_sequence()` path. Assert the early active-resume branch does not call direct inactive reconstruction and the post-router `reconstruct_presentation()` call does. |
| Inter-attack second hull zone | Same no-ATTACK-write, real-GameBoard-entrypoint, and local-selection/remote-waiting proof for the two-hull-zone path in live play, save/load, and reconnect. Assert `interaction_flow` remains the legitimate enclosing non-ATTACK flow or NONE throughout. |
| Non-final stale rejection | Missing, malformed, retired, mismatched, duplicate, delayed, and out-of-order source ids reject before mutation; state/hash/flow/history/cursor/follow-ups/success signals remain unchanged. |
| Valid terminal clear | An accepted retiring command with matching pre-execution ATTACK source queues the final command while that projection remains installed; accepted execution clears exactly once, then scene/FSM cleanup performs no direct canonical clear. |
| Completed-inspection terminal admission | With an unsatisfied and with a satisfied `CompletedAttackInspection`, the exact matching final publication is admitted and clears its source. Non-final, wrong-source, malformed, and unrelated commands remain blocked; rejection is atomic. Cover terminal-match preflight when applicable. |
| Network terminal order | For remote-authored and host-authored triggers, instrument command/result order: retiring command executes and its server-side Network distribution/broadcast dispatch completes before the queued final command executes or dispatches. Prove no `command_executed` reentrant submission and, on the existing reliable ordered channel, no peer applies final-before-trigger. |
| Replay terminal order | Owner-recorded format-12 replay contains trigger then exact matching final publication; replay applies both through ordinary validation, including completed inspection, without synthesizing live observer follow-ups. Reversed, missing-source, or mismatched final input rejects. |
| Delayed/mismatched terminal clear | Old clear cannot clear a newer ATTACK flow; clear against NONE/non-ATTACK is omitted or rejects; duplicate clear is unchanged failure. |
| Queue independence | Direct post-retirement delivery and FIFO-delayed delivery of the same stale payload both reject identically; queue pruning/coalescing is unnecessary. |
| State filtering | After stale rejection, full authority round-trips and `StateFilter` succeeds. Existing invalid-state filtering remains fail closed and unchanged. |
| Explicit ship identity | Both fields valid resolves exact ship. One field only, wrong type, wrong player/index, or out-of-range value fails with no fallback and no `-1` lookup. |
| Identity-free fallback | Both fields absent plus recognized ship outcome and matching active attack resolves exact defender. Missing/malformed shape, stale id, inactive attack, or Squadron kind fails. |
| Shield-only normalization | Correct shield signal/zone/value; no false card/hull refresh. |
| Facedown hull normalization | Correct hull signal, canonical damage-card refresh, and summary. |
| Faceup/inspection normalization | Correct hull/card/summary signals while canonical inspection ownership and acknowledgement remain unchanged. |
| Lethal normalization | Correct defender receives card/shield refresh, hull zero/destruction presentation, and elimination check; no unrelated ship event. |
| Network mapping 0 | Host attacker/client defender: valid source-scoped publications, local damage path, terminal queue/distribution order, completed-inspection admission, full Counter exact-ID authoritative inspection release, real-GameBoard inter-attack local/waiting reconstruction, filtering, and convergence pass under protocol 11. |
| Network mapping 1 | Client attacker/host defender: deterministic facedown-only damage; canonical ship normalization; delayed non-final publication crosses completion/acknowledgement/inspection consumption/activation advance and rejects; terminal queue/distribution order, full Counter exact-ID authoritative inspection release, real-GameBoard inter-attack local/waiting reconstruction, repair/maneuver, final filtering, and convergence pass; no `-1`. |
| Mapping role reversal for result shapes | At least shield-only and hull-damage cases run with remote attacker in each endpoint/player assignment needed to prove presentation does not derive identity from role. Faceup and lethal may be distributed across mappings if both remote-result application and exact target evidence are retained. |
| Reassociation | Both explicit side assignments reconstruct the same canonical player/attack identities; source validation and result fallback do not use endpoint/principal role. |
| Save format 10 | Active and between-attacks saves retain existing schema and reconstruct legal next decisions; no publication source is added to save state. |
| Protocol 11 | 11↔11 handshake and command flow pass; 10↔11 mismatch rejects at handshake; protocol-11 missing-source publication rejects with no compatibility default. |
| Replay format 12 | Format-12 source-scoped publications replay in order; format 11 rejects under existing strict boundary; format-12 missing-source publication rejects; no migration/backfill. |
| Manual fixtures | Owner-recorded format-12 committed replay inputs pass signature/schema checks and applicable baseline verification; provenance and capture conditions are recorded. |

The mapping-1 facedown-only case is mandatory and cannot be replaced by a
faceup path whose additional inspection gates accidentally drain the queue.

## 9. Compatibility And Version Consequences

### 9.1 Fixed versions

| Boundary | Required result |
| --- | --- |
| Save | **Remain at format 10.** No new save field, decoder, migration, or reinterpretation. |
| Network | **Advance protocol 10 → 11.** The required `source_attack_id` changes publication command wire semantics. Strict handshake mismatch rejection remains the compatibility boundary. |
| Replay | **Advance format 11 → 12.** `SIGNED_FORMAT_VERSION` advances with `FORMAT_VERSION`. Format 12 records the required source identity; format 11 is not backfilled. |

### 9.2 Command and state consequences

- `publish_attack_flow` gains required serialized command intent
  `source_attack_id`; applicable non-final flow payloads carry the same source
  for projection/terminal matching.
- No `CurrentAttackState`, `GameState`, save, damage outcome, principal binding,
  or damage-result schema changes.
- Counter inspection release reuses the existing
  `completed_attack_inspection_id` field on `BeginAttackCommand`; it adds no
  command field or serialized continuation record.
- `GameBoard` reconstruction changes call order only and adds no persisted or
  transported presentation state.
- No protocol-10 command adapter, replay-11 migration, missing-id fallback, or
  best-effort inference is authorized.
- Valid protocol-11/replay-12 commands missing source identity fail closed.
- Trace format changes only if its existing schema actually changes; replay
  format advancement alone does not authorize a trace-schema version change.

## 10. Manual Replay Fixture Boundary

Current committed replay inventory contains:

- `tests/fixtures/baseline_traces/replay_network.json`, which contains affected
  publication commands and must be manually re-recorded as format 12; and
- `tests/fixtures/baseline_traces/replay_hot_seat_solo.json`, which must also be
  manually re-recorded as format 12 because the strict global replay cutover
  rejects format 11 even though Hot-Seat does not normally publish Network
  attack-flow commands.

The Project Owner must record both replacement replay inputs through the real
application/gameplay path after implementation reaches the fixture-capture
gate. The Network recording must use protocol 11 and exercise valid post-Begin
source-scoped publication plus terminal clearing. Capture provenance, mode,
versions, scenario, and relevant attack identities must be retained.

Codex must stop at that boundary. Codex may not generate, synthesize,
transform, reconstruct, patch, header-edit, re-sign, or automatically
regenerate either replay fixture. No old publication command may be decorated
with a fabricated source identity.

After Owner recording, Codex may inspect and validate the supplied fixtures and
run the repository's normal candidate/review workflow for derived evidence.
Any affected committed Hot-Seat trace or state-hash promotion remains
Owner-reviewed. The exact-RNG repair's pending baseline/hash promotion is not
authorized by this workbook and must not be silently combined with replay-12
fixture integration. If the two workflows cannot be reviewed independently,
stop for an explicit combined Owner sequencing decision.

## 11. Implementation Sequence And Gates

### Slice 1 — source-producing command schema

- Add `source_attack_id` to the exact command contract.
- Update the central producer to snapshot canonical source at creation.
- Cover fresh Ship, Squadron, Counter, and reconstructed paths.
- Add protocol 11 and replay 12 constants/tests.

Gate: serialized commands retain their creation source across delayed delivery;
valid post-Begin publications accept; missing/mismatched source rejects.

### Slice 2 — inter-attack and terminal choreography

- Preserve the parent-source Counter-choice projection through accepted choice,
  parent retirement, unsatisfied inspection, and child Begin; suppress only the
  child's premature pre-Begin ATTACK write/publication.
- Extend the existing `CurrentAttackContinuation` inspection-release branch to
  derive the exact-ID child Counter Begin after satisfaction; let
  `CommandProcessor` queue it on live authority, and remove semantic child
  entry from scene `command_executed` reaction.
- Suppress no-active ATTACK writes/publications in ordinary next-squadron and
  next-hull-zone paths.
- Extend the existing `UIProjector`/`ModalRouter`/`AttackPanelController`
  reconstruction route to derive local selection versus remote waiting from
  canonical Ship activation facts in live play, save/load, and reconnect.
- Restrict `GameBoard`'s pre-router resume to active attacks and invoke the
  router reconstruction path for inactive inter-attack decisions only after
  router/viewer setup.
- Derive ordinary source-scoped terminal clear in `CommandProcessor`'s existing
  post-success follow-up queue, admit its exact source through completed-
  inspection/terminal preflight, distribute the trigger before draining the
  final command, and perform scene/FSM cleanup without a second live-flow clear.

Gate: inter-attack decisions remain usable/reconstructable with no invented
attack; the parent Counter projection survives unsatisfied inspection; exact-ID
satisfaction authoritatively queues one child Begin in both Network mappings;
replay synthesizes none; real `GameBoard` save/load/reconnect reconstruction
uses the router path; valid terminal publication remains admissible and ordered
after trigger distribution; a delayed parent/ordinary clear cannot affect
newer flow.

### Slice 3 — remote ship normalization

- Implement exact explicit-identity branching.
- Add matching-active-attack fallback only when both fields are absent.
- Normalize identity-free outcome and refresh presentation from canonical ship.

Gate: shield-only, facedown, faceup/inspection, and lethal tests pass with exact
ship identity and no `-1` lookup.

### Slice 4 — distributed and persistence verification

- Run both mapping scenarios and the facedown-only timing canary.
- Run save-10, reconnect/reassociation, protocol-11, replay-12, command
  serialization, filtering, and existing attack/damage protocol suites.
- Confirm no RNG, save schema, principal, damage-result, or StateFilter change.

Gate: automated verification passes and no unexplained divergence remains.

### Slice 5 — manual fixture capture and final verification

- Stop for Owner recording of the two format-12 replay fixtures.
- After the Owner supplies them, validate signatures/schema/provenance and run
  applicable replay/baseline verification without promoting the paused exact-
  RNG hash under this authority.

Gate: Owner-recorded replay-12 inputs pass and any derived evidence promotion
has separate Owner review.

## 12. Explicit Exclusions And STOP Conditions

This workbook does not authorize:

- a new attack, continuation, between-attacks, result, projection, or generic
  lifecycle owner;
- using queue behavior as semantic correctness;
- submitting terminal publication synchronously or reentrantly from a
  `command_executed` presentation callback;
- extending the retired attack identity across target selection;
- installing a no-active canonical ATTACK flow;
- clearing the accepted parent `ATTACK_COUNTER_CHOICE` before child Counter
  Begin validates and replaces it;
- deriving or submitting child Counter Begin from a scene
  `command_executed` callback, a client endpoint, or an unsatisfied inspection;
- reconstructing inactive inter-attack presentation directly in `GameBoard`
  before its command-router adapter and viewer identity are available;
- execution-time inference of missing source identity;
- clearing a newer ATTACK flow with an older terminal command;
- changing broad `GameState` live validation or weakening deserialization,
  StateFilter, or filtering;
- defaulting, suppressing, mapping, or special-casing player `-1` instead of
  resolving exact canonical ship identity;
- adding defender identity to canonical outcome solely for presentation;
- replaying or mutating damage in presentation code;
- a save-format change from 10;
- a protocol-10 adapter, replay-11 migration/backfill, or fixture transformation;
- Codex-generated replay recording;
- exact-RNG serialization, baseline/hash, or Gate 1 changes; or
- GGS-001 Gate 2.

STOP for Owner/architecture review if the existing enclosing route cannot
represent inter-attack waiting/selection without new durable state; if the
existing CommandProcessor/NetworkManager follow-up order cannot make valid
terminal clearing source-scoped and post-distribution without a new mechanism;
if `CurrentAttackContinuation` cannot derive child Counter Begin with the
existing Begin payload and inspection ID; if real `GameBoard` reconstruction
cannot use the existing router after setup;
if canonical ship identity or outcome fields are unavailable at the
presentation seam; if a save-schema or damage-result change becomes necessary;
or if fixture integration would require combining unauthorized exact-RNG
baseline promotion.

## 13. Completion Criteria And Evidence Handoff

The package is complete only when:

1. all four audit blockers and all required refinements remain fully disposed;
2. source identity is captured at creation for every applicable fresh Ship,
   Squadron, Counter, and reconstructed publication;
3. stale non-final and final commands reject atomically without canonical or
   ordering mutation;
4. no-active inter-attack publication/direct ATTACK write remains, while the
   existing reconstruction route gives the controller selection and the other
   viewer waiting in live play, save/load, and reconnect through the real
   post-router `GameBoard` entrypoint;
5. parent Counter-choice projection survives accepted choice and retirement
   plus unsatisfied inspection; exact-ID satisfaction causes the existing
   authoritative continuation evaluator to queue one child Begin in both
   Network mappings; child-source publication replaces it; replay uses only its
   explicit recorded Begin;
6. ordinary terminal clear is exact-source scoped, passes only its narrow
   completed-inspection/terminal admission, executes/broadcasts after the
   triggering result distribution, and cannot clear a newer attack;
7. remote explicit identity/fallback branching is exact and every required
   outcome shape emits complete presentation for the correct ship;
8. both role mappings, facedown-only timing, save/load, reconnect/reassociation,
   filtering, and continuation converge;
9. save 10, protocol 11, and replay 12 are verified with no unauthorized
   compatibility path;
10. Owner-recorded format-12 replay fixtures pass the required verification;
11. production/test/evidence changes contain no broad validator, queue-owned
    correctness, new owner, RNG change, or unauthorized baseline promotion;
12. instrumentation is removed and `git diff --check`, applicable static
    checks, focused suites, and changed-file/version audit pass; and
13. an independent completion audit reports no blocker or missing evidence.

The implementation evidence must record source ids at creation/application,
inter-attack command-history absence and viewer-specific reconstruction,
the `GameBoard` ready/reload route used, Counter parent/inspection/child ids and
authority/queue/broadcast order, terminal source comparisons and
trigger/final distribution order, rejection atomicity, normalized ship/result
fields and emitted signals, mapping/principal/player assignments,
acknowledgement/advance order, filtering/convergence, version boundaries,
fixture provenance, and every changed file.

## 14. Relationship To The Paused Exact-RNG Repair

The exact-RNG serialization repair remains paused before baseline/hash
promotion. These defects were **EXPOSED**, not caused, by the repaired stream.

This package may use the current worktree as the known mapping-1 acceptance
environment, but it must preserve all exact-RNG changes and may not promote or
replace their baselines/hashes. It must also retain RNG/save-independent stale-
command evidence.

After this production repair is implemented, independently audited, verified
under both mappings, and its manual replay-12 boundary is satisfied, the
exact-RNG task may resume at its bounded cross-boundary verification step.
Baseline/hash promotion remains separately Owner-controlled. GGS-001 Gate 2
remains unauthorized.

## 15. Remaining Owner Actions, Size, Risk, And Audit Readiness

No genuinely new gameplay, schema, or architecture decision is presently
known. Remaining Owner actions are:

1. accept, revise, or reject this workbook after targeted closure audit;
2. authorize implementation after acceptance;
3. manually record the required format-12 Hot-Seat and Network replay fixtures
   at the implementation capture gate;
4. separately review any derived replay baseline candidates and the paused
   exact-RNG baseline/hash promotion; and
5. separately authorize any later GGS-001 Gate 2 work.

Estimated production size: **Medium** across the central producer,
CommandProcessor terminal derivation/admission, Network ordering preservation,
the existing `CurrentAttackContinuation` Counter release branch,
AttackExecutor choreography, `GameBoard` ready ordering, the existing
inter-attack projection consumers, command validation, GameManager
presentation, and two version constants.
Estimated verification size: **Medium–Large** because four attack
entry/reconstruction paths, exact-ID Counter inspection release, real-GameBoard
inter-attack live/persistence states, terminal ordering, four damage shapes,
both role mappings, and manual fixture capture are required.

Risk: **Medium–High**. The source-identity rule is narrow, but over-broad
suppression, completed-inspection admission, or terminal derivation could break
legitimate Ship, Squadron, Counter, terminal, reconstructed, Network-order, or
replay behavior. Inter-attack projection must remain derived-only. Defect B
remains Low–Medium risk if normalization stays presentation-only.

Readiness: **ready for final targeted closure audit**. The audit should treat
the terminal blocker and other preserved findings as closed, and verify only
the exact-ID authoritative Counter inspection-release sequence plus the real
post-router `GameBoard` reconstruction entrypoint, along with consistency of
the unchanged save 10 / protocol 11 / replay 12 cutovers, manual fixture
boundary, and separation from the paused exact-RNG baseline and GGS-001 Gate 2.

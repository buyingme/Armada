# UX-005: Completed-Attack Result Inspection Implementation Workbook

Status: Accepted

Purpose: implementation workbook

Created date: 2026-08-18
Accepted by: Project Owner
Accepted date: 2026-08-18

Scope: one coherent UX-005 semantic cutover. This workbook implements the
accepted ADR-007/CON-007 completed-result inspection lifecycle. It does not
amend accepted architecture, introduce a generic continuation or
acknowledgement mechanism, or change attack, timing-window, declaration, or
activation ownership.

## 1. Authority, Boundary, And Outcome

Normative implementation authority, in precedence order, is:

- [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md)
  and [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md);
- [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md),
  [CON-005](../contracts/CON-005-timing-window-implementation-contract.md), and
  [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md);
- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md),
  [ADR-005](../adr/ADR-005-timing-window-ownership-and-continuation.md),
  [ADR-006](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md),
  and [ADR-008](../adr/ADR-008-durable-match-lifetime-player-principal-binding.md);
- accepted [MATCH-001](MATCH-001-player-principal-binding-implementation-workbook.md),
  [TWI-003](TWI-003-authoritative-current-attack-state-implementation-workbook.md),
  and [TEST-003](../tests/TEST-003-interactive-rule-timing-window-verification.md).

The outcome is one `GameState`-owned, zero-or-one pending completed-attack
inspection. `CompleteAttackCommand` creates it after damage is resolved while
retiring the active attack. `AcknowledgeAttackResultCommand` adds exactly one
validated HUMAN principal to its received set. The existing context-specific
command path, never the acknowledgement command or UI, consumes a satisfied
inspection atomically with its own next mutation. A context that only exposes a
next choice retains the satisfied inspection until that existing choice command
is accepted; it does not create a no-op or generic continuation command.

This is the sole UX-005 implementation specification. The Owner decision
records and ADR/contract remain architecture authority; the older
`UX-005-post-attack-continuation-ownership-workbook.md` is decision evidence,
not a parallel execution plan.

### Concrete seam inventory

| Area | Current concrete seam | UX-005 change boundary |
| --- | --- | --- |
| Canonical match and principals | `src/core/state/game_state.gd`: `serialize()`, `deserialize()`, `validate_for_live_installation()`, `get_distinct_controlling_principal_ids()` | Add the one inspection child and validate it before live publication/reconstruction; derive HUMAN IDs only through the existing query. |
| Attack outcome and terminal retirement | `src/core/commands/resolve_damage_command.gd`, `src/core/commands/complete_attack_command.gd`: `execute()` | Preserve minimal resolved outcome while the attack is active; atomically transfer it to inspection while retiring the attack. |
| Command path and release seam | `src/autoload/command_processor.gd`: `_ready()`, `preflight()`, `_enqueue_post_success_continuation()`, `submit*()` | Register/guard acknowledgement and add only inspection-aware evaluation to the existing deferred post-success seam. |
| Existing continuation owners | `begin_attack_command.gd`, `skip_attack_command.gd`, `move_squadron_command.gd`, `complete_squadron_activation_command.gd`, `advance_activation_step_command.gd` | Add matching satisfied-inspection validation/atomic consumption only to the relevant accepted existing transaction. |
| Submission and distribution | `src/autoload/game_manager.gd`, `src/core/commands/*_command_submitter.gd`, `src/autoload/network_manager.gd`: `_submit_command_to_server()`, `_submit_observer_followup_from_server()`, `_drain_server_observer_followups()` | Add the acknowledgement facade and reuse principal authorization, ordered authoritative broadcast, and mirror application; do not add RPC authority. |
| Projection and local legacy behavior | `src/core/network/ui_projector.gd`, `src/core/network/state_filter.gd`, `src/scenes/game_board/modal_router.gd`, `attack_executor.gd`, `attack_panel_mirror.gd` | Project canonical result/ack state and remove timer/local-release behavior. |
| Durability and artifacts | `src/autoload/save_game_manager.gd`, `src/core/state/save_game_metadata.gd`, `src/core/commands/game_replay.gd`, `src/autoload/replay_driver.gd`, `src/autoload/network_manager.gd` | Apply the strict save/replay/protocol allocation in Section 7. |
| Existing proof surfaces | `tests/integration/test_current_attack_production_resume.gd`, `test_current_attack_shared_protocol.gd`, `tests/unit/test_command_atomic_failure.gd`, attack panel/mirror, state filter, save, replay, and Network tests | Extend these production-representative suites; add focused inspection/acknowledgement cases rather than a parallel harness. |

## 2. ADR-007 Entry Gate Re-evaluation

### Gate A — canonical human-principal source: PASS

| Required proof | Concrete evidence | Result |
| --- | --- | --- |
| Accepted source | ADR-008 makes `GameState` the sole owner of the immutable match-player-control binding. MATCH-001 implemented it in `src/core/state/game_state.gd` as `_match_player_control_binding`, with `get_distinct_controlling_principal_ids(kind)`. | Pass |
| Correct derivation | `MatchPlayerControlBinding.distinct_principal_ids(HUMAN)` is an immutable, sorted distinct-principal query. MATCH-001 specifies one HUMAN mapped to both players for Hot-Seat and two distinct HUMAN principals for two-human Network. | Pass |
| No transient authority | The binding serializes with `GameState`, is installed before live publication and reconstruction, and is independent of peer, lobby, display-name, controller, `PlayMode`, and player-index identity. Network peers hold only a transient association validated against the binding. | Pass |
| Empty HUMAN case | ADR-008/MATCH-001 permit HUMAN/AUTOMATED and zero-HUMAN bindings. UX-005 creates no inspection when the distinct HUMAN result is empty; it does not synthesize an acknowledgement. | Pass |

UX-005 shall derive required principals exactly once at terminal completion:

```gdscript
game_state.get_distinct_controlling_principal_ids(
    MatchPlayerControlBinding.KIND_HUMAN)
```

The resulting values, not gameplay-player indices, UI viewers, peer membership,
controller state, or `NetworkManager` associations, become the immutable
required set.

### Gate B — continuation-release readiness: PASS

The corrected ADR-007 Section 13 gate asks whether accepted owners, existing
semantic transactions, transaction boundaries, and a release seam permit
implementation. It does **not** require inspection-aware consumption,
acknowledgement, or exact-once release to pre-exist; those are this workbook's
implementation and verification obligations.

`CommandProcessor._enqueue_post_success_continuation()` in
`src/autoload/command_processor.gd` is the existing sole deferred post-success
seam. It passes command/result and canonical state to
`CurrentAttackContinuation.process_successful_command()`, distinguishes live
authority, network mirror, and replay, and queues a follow-up only on live
authority. Network authority broadcasts accepted commands before draining
follow-ups; clients apply ordered results through `submit_mirror()`. Replay
applies recorded commands through `submit_replay()` and does not drain live
follow-ups. This is CON-007-SEAM-001's concrete seam.

| CON-007 context | Existing owner facts and transaction boundary | Existing next mutation / derived-only release | Gate finding |
| --- | --- | --- | --- |
| Normal ship attack | `ShipInstance` owns attack-step facts, count, zones, and activation identity. `BeginAttackCommand`, `SkipAttackCommand`, and `AdvanceActivationStepCommand` validate them. | A second normal declaration is derived; selected `BeginAttackCommand` or declaration `SkipAttackCommand` is the next mutation. When Attack is complete, `AdvanceActivationStepCommand(maneuver_step)` is the existing mutation. | Pass |
| Ship anti-squadron iteration | The same `ShipInstance` owns locked zone and target history. `CompleteAttackCommand` determines exhaustion; `SkipAttackCommand(squadron_done)` is the accepted exhausted-iteration path. | A target is a derived declaration opportunity and selected `BeginAttackCommand` is the next mutation. Exhaustion uses existing Skip, then normal declaration or ship transition remains derived. | Pass |
| Squadron Phase squadron attack | `SquadronInstance` owns action history; `GameState` owns phase controller/count. Existing move and complete commands validate those owners. | Remaining movement, including Rogue, is derived and uses `MoveSquadronCommand`. An exhausted action uses `CompleteSquadronActivationCommand` with existing phase consequence. | Pass |
| Ship-commanded squadron attack | `SquadronInstance` owns action history; commanding `ShipInstance` owns activation identity, open command opportunity, and committed count. | Derived remaining move uses existing move. Exhausted action uses `CompleteSquadronActivationCommand`; the existing commanding-ship route exposes the next choice/step. | Pass |

All rows have an accepted owner and existing replayable transaction with an
atomic validate/execute boundary that can couple inspection consumption to its
own mutation. No row needs a new owner, a second continuation architecture, or
a generic descriptor. Gate B therefore passes.

#### Gate B four-context seam trace

The following is the implementation trace required for each CON-007 row. The
release seam is always `CommandProcessor._enqueue_post_success_continuation()`
through `CurrentAttackContinuation.process_successful_command()`. The
inspection identity is not stored in a continuation descriptor: the evaluator
reads the canonical inspection identity and derives the optional
`completed_attack_inspection_id` payload on the selected existing command.

| Context | Authoritative consumer transaction | Identity, validation, and atomic consumption | Derived-only outcome | Live / replay / mirror / reconstruction |
| --- | --- | --- | --- | --- |
| Normal ship attack | `AdvanceActivationStepCommand(maneuver_step)` at the completed ship Attack boundary; `BeginAttackCommand` or declaration `SkipAttackCommand` only when a further normal declaration is actually selected. | Lookup the sole `GameState` inspection by identity; the command validates exact identity, satisfied status, matching `ShipInstance` activation/attack facts, and legal step. Its existing owner mutation and inspection consumption commit in one transaction. Stale, wrong, duplicate, or missing IDs reject without mutation. | A further legal normal declaration remains derived and emits no continuation command. | Live authority queues at most one selected command after the acknowledgement result is broadcast. Replay applies only the recorded command. Mirror applies ordered broadcasts and queues nothing. Load/reconnect installs the inspection first, then evaluates once through the same seam. |
| Ship anti-squadron iteration | `SkipAttackCommand(squadron_done)` when the locked target iteration is exhausted; otherwise the selected `BeginAttackCommand` is the next mutation. | Derive identity from canonical inspection plus the owning ship's locked zone/target history; validate exact ID, satisfaction, exhaustion/target eligibility, and command context before atomically mutating the ship and consuming the inspection. | An eligible untargeted squadron, later normal attack, or ship transition is derived only; no no-op continuation is created. | Same four-mode policy as the normal ship row; replay/mirror never synthesize the selected mutation, and reconstruction cannot enqueue before validated installation. |
| Squadron Phase squadron attack | `MoveSquadronCommand` when movement remains; `CompleteSquadronActivationCommand` when the squadron action is exhausted. | Derive identity from the inspection and canonical `SquadronInstance` action history plus `GameState` phase progress; validate exact ID, satisfaction, activation identity, and the selected command's current owner facts. Commit movement/completion and inspection consumption atomically; reject stale, wrong, duplicate, or missing IDs unchanged. | Remaining movement, including Rogue eligibility, is derived without a command when no mutating transaction is required. | Live-only selection; replay consumes only recorded commands; mirror applies only accepted ordered commands; reconstruction installs and validates before one release evaluation. |
| Ship-commanded squadron attack | `MoveSquadronCommand` when commanded movement remains; otherwise `CompleteSquadronActivationCommand`, followed by the existing commanding-ship route. | Derive identity from the inspection, squadron action history, and commanding ship activation identity/open command opportunity/committed count. Validate exact ID, satisfaction, and all three owner contexts before atomically applying the existing mutation and consuming the inspection. Failure, stale, wrong, duplicate, and missing identity leave the inspection satisfied and unconsumed. | A remaining commanded-squadron move or another Squadron-command choice is derived only. | Live authority may queue one existing transaction after ordered acknowledgement broadcast. Replay and mirror are history/result application only. Save/load/reconnect validate the installed inspection and owner state before release evaluation and suppress duplicate queued follow-ups. |

This trace is the Gate B implementation-readiness proof. It does not authorize
new context owners, generic commands, descriptors, queues, or FSM state.

## 3. Canonical State And Terminal Snapshot

### 3.1 `GameState` ownership

Add `src/core/state/completed_attack_inspection.gd` as a narrow immutable value
object, following `match_player_control_binding.gd` and
`current_attack_state.gd`. `GameState` gets one private
`_completed_attack_inspection`, copied query, strict install/acknowledge/consume
helpers, serialization/deserialization, and cross-owner validation.

It must enforce: zero or one value; no active `CurrentAttackState` alongside
an inspection; non-empty unique required IDs; received IDs as a monotonic
subset; stable identity; copied data; and only a satisfied inspection can be
consumed. It may retain a satisfied inspection until the existing consumer
transaction succeeds. It contains no status enum, current step, queue,
continuation descriptor, timer, modal, `InteractionFlow`, or activation facts.

### 3.2 Identity and immutable result snapshot

Use `completed:<attack.attack_id>` as identity. `attack_id` is already a
deterministic command-sequence-derived lifecycle identity in
`BeginAttackCommand`; the typed prefix prevents accidental conflation with an
active attack. It remains stable through save/load, mirror, reconnect
reconstruction, and replay.

Serialize only:

- inspection/source attack identity;
- attacker and defender `{kind, player, index, zone}` references and
  `attack_kind` copied from the terminal attack;
- final `dice_results` copied from the terminal attack;
- tagged immutable resolved outcome; and
- sorted `required_principal_ids` and `received_principal_ids`.

The minimal outcome is presentation-safe historical evidence:

- ship: target reference/kind, affected zone, final attack damage, shield
  absorbed, post-resolution shields in that zone, cards/hull damage count, and
  destroyed flag;
- squadron: target reference/kind, requested/actual hull damage, post-resolution
  hull, and destroyed flag.

Do not store damage cards/deck state, mutable health, display names, attack
pool, controller/peer identity, or re-applicable damage data. The value never
validates or reapplies gameplay effects.

`ResolveDamageCommand` is the concrete source of these outcome facts today.
Extend its successful active-attack replacement to retain only this JSON-safe
result evidence until terminal completion. That temporary fact satisfies
CON-001 membership: it is attack-specific and required to form the adjacent
immutable snapshot after retirement, not a second entity-health owner.
`CompleteAttackCommand` copies it to the inspection and retires it with the
active attack. Existing immediate-effect command paths remain unchanged.

### 3.3 Terminal creation

Modify `CompleteAttackCommand.execute()` as one rollback-safe transaction:

1. validate resolved damage, no timing window, matching attack identity, and
   no existing inspection;
2. copy terminal attack/outcome evidence and derive the sorted HUMAN set once;
3. build/validate an inspection only when that set is non-empty;
4. retain current anti-squadron exhaustion and rule-cleanup behavior;
5. atomically install inspection (if any), retire `CurrentAttackState`, and
   commit existing adjacent owner changes; and
6. restore current attack, inspection absence, and affected ship snapshot on
   any failure; return `{}` and record no command.

An empty HUMAN derivation retires normally and creates no inspection. No state
may expose a retired attack with overtaken continuation, or an inspection while
its source active attack remains present.

## 4. Acknowledge Command And Blocking Policy

Add `src/core/commands/acknowledge_attack_result_command.gd`, register it in
`CommandProcessor._ready()`, declare it in `CommandApplicability` for Ship and
Squadron phases, and add derived `FlowSpec` affordance only where applicable.
Its exact payload is `{ "inspection_id": String }`; `player_index` remains the
existing envelope gameplay-side identity.

The accepted submission boundary supplies the authoritative principal:

- Hot-Seat `LocalCommandSubmitter` is associated with the sole HUMAN;
- host-local and remote Network submission already resolve the host-held
  principal association through `NetworkManager`; and
- replay applies recorded history, never a live principal claim.

`AcknowledgeAttackResultCommand.validate()` derives the candidate principal as
`game_state.principal_id_for_player(player_index)`. The existing submitters
must first have proved that the physical local/remote sender controls that
gameplay player (`LocalCommandSubmitter`, `NetworkHostCommandSubmitter`, or
the server's `NetworkManager._submit_command_to_server()` check). Thus the
command carries no principal claim, and a replay validates the recorded player
against the reconstructed binding. Do not serialize a peer, credential, local
controller, or caller principal as command authority. Validation requires
pending inspection, exact identity, authorised HUMAN principal, membership in
required, absence from received, and legal order/phase. Execute adds exactly
that principal. It never selects, queues, executes, or consumes continuation;
changes attack/damage or timing state; or accepts a caller-provided
snapshot/set.

Add one purpose-specific inspection guard in `CommandProcessor.preflight()` (or
its invoked narrow helper): while acknowledgement is outstanding, reject every
gameplay-progression command except matching acknowledgement. After
satisfaction, reject unrelated progression and permit only a re-derived
existing context transaction from Section 5. This is not a generic framework.

## 5. Release And Exact-Once Consumption

Extend the existing `CurrentAttackContinuation` helper with an
inspection-specific branch called through the existing CommandProcessor seam;
do not create a new orchestrator. It runs only on live authority, reads one
canonical inspection/current owner state, does nothing absent or outstanding,
re-derives the CON-007 row, queues at most one existing deterministic mutation,
and returns no command when the next state is merely a derived opportunity.

For every permitted existing consumer transaction, add optional
`completed_attack_inspection_id`. When present it must name the current
satisfied inspection and match that command's re-derived context. The command
snapshots owner/inspection state, performs its existing mutation, and consumes
the inspection only after successful validation/execution; rejection restores
both. A command without this condition cannot overtake a pending inspection.
This identity binds consumption to the existing mutation, not to a descriptor.

| Release situation | Existing consumer transaction | Derived-only result |
| --- | --- | --- |
| Ship Attack boundary complete | `AdvanceActivationStepCommand(maneuver_step)` | None; queue only in live post-success seam. |
| Normal ship / anti-squadron target remains | Selected `BeginAttackCommand`; declaration `SkipAttackCommand` when chosen | Legal target/choice route is re-derived, never stored. |
| Anti-squadron iteration exhausts without another resolved result | `SkipAttackCommand(squadron_done)` | Subsequent normal/Maneuver eligibility stays derived. |
| Squadron movement remains | `MoveSquadronCommand` | Move opportunity is re-derived, including Rogue. |
| Squadron action exhausted | `CompleteSquadronActivationCommand` | Existing phase/controller or commanding-ship result stays derived. |

Network authority broadcasts the acknowledgement before draining a selected
follow-up; `NetworkManager._submit_observer_followup_from_server()` continues
to broadcast the queued existing command. Client mirrors run the same helper in
mirror mode and receive no follow-up. Replay records acknowledgement and
eventual continuation in order and never asks the live release evaluator to
synthesize a command.

On consumer validation/execution failure, the satisfied inspection remains
canonical and unconsumed with no partial mutation. Duplicate callback, mirror
delivery, replay application, load reconstruction, or panel teardown cannot
consume or release it again.

### 5.1 Exact-once consumer contract

Every mutating consumer listed above shall carry the selected inspection
identity in `completed_attack_inspection_id`; a derived-only branch carries no
identity and creates no command. The consumer shall:

1. look up the canonical inspection by that identity immediately before
   validation/execution;
2. require exact identity match, satisfaction, and the context-specific owner
   facts shown in the trace;
3. reject stale, wrong-context, duplicate, missing, or already-consumed
   identities before changing any owner;
4. commit its existing gameplay mutation and inspection consumption as one
   rollback-safe transaction; and
5. leave the inspection satisfied and unconsumed if validation or execution
   fails, so the same seam can retry from canonical state.

The verification set must include a duplicate callback, a stale queued
follow-up after reconstruction, and a second delivery of the same mirror or
replay command. Each must prove no second mutation and no second consumption.

## 6. Projection, Persistence, And Legacy Retirement

`UIProjector` and `StateFilter` must project/preserve the inspection to both
Network peers. Existence, identity, acknowledgement sets, final dice, and the
permitted outcome are public between participating humans; existing hidden
card/deck filtering stays unchanged. `ModalRouter`, `AttackPanelController`,
`AttackPanelMirror`, and `AttackExecutor` derive complete result plus
`Acknowledge Result` for an outstanding local HUMAN, dismissed/waiting state
for a received local HUMAN, and no affordance for non-required/zero-HUMAN
viewers.

Remove from semantic authority in the same cutover:

- `AttackExecutor._attack_exec_finalize_after_delay()` and its 1.2-second
  timer;
- `_awaiting_result_acknowledgement` / `_pending_finalize_after_completion` as
  lifecycle/release authority in `AttackExecutor`; and
- `AttackPanelMirror._awaiting_result_acknowledgement` and its confirmation
  callback as local acknowledgement/continuation authority.

They may disappear or remain derived presentation state, but cannot submit
completion, finalization, declaration, squadron completion, or activation
progression. The visible button submits the new command; no timer fallback.

`GameState.serialize()`/`deserialize()` serialize one inspection and validate
it before live installation, projection, routing, or release. The existing
filtered reconstruction path `serialize -> StateFilter.filter_for_player ->
deserialize` must preserve it. Reconnect uses that same installation order; it
does not change ADR-008/MATCH-001 replacement-peer entitlement stops.

`GameReplay` records accepted `acknowledge_attack_result` commands. Replay
creates inspection from the recorded terminal `complete_attack`, then applies
only recorded acknowledgement/continuation commands. It does not synthesize
acknowledgement or continuation. Passive mirrors apply only ordered accepted
broadcasts through `submit_mirror()` and do not optimistically mutate state.

Installation ordering is strict for save/load, filtered reconstruction, and
reconnect: deserialize and validate the complete `GameState`, including owner
state and pending or satisfied inspection; install that state; rebuild the
projection; and only then invoke the release seam once. Reconstruction never
drains a stale pre-reconstruction follow-up queue. Any queued follow-up whose
inspection identity is absent, stale, already consumed, or not satisfied is
discarded/rejected without mutation. A satisfied-but-unconsumed inspection is
therefore durable and retryable, but cannot produce a duplicate continuation.

`SaveGameManager.can_save_now()` must be verified explicitly for both a
pending inspection and a satisfied-but-unconsumed inspection. The result state
is safe to save only when the existing safe-point rules permit it; the
inspection must not be treated as UI/timer state or silently dropped.

### 6.1 Fixture and test migration inventory

Before implementation, inventory and migrate every affected construction seam
to shared helpers/factories rather than patching tests individually:

| Construction seam | Required migration obligation | Preserve intentionally invalid cases |
| --- | --- | --- |
| `GameState` fixtures/builders | Establish the accepted `MatchPlayerControlBinding` by default and add shared pending/satisfied inspection builders. | Keep explicit missing/invalid binding and missing inspection cases for validation tests. |
| `CurrentAttackState` fixtures/builders | Ensure active, resolved, and terminal fixtures can supply the minimal resolved-outcome evidence needed by `CompleteAttackCommand`. | Keep malformed, stale, and active-plus-inspection combinations for rejection tests. |
| Shared attack/protocol fixtures | Update Hot-Seat, two-human Network, replay, and mirror builders to construct the same canonical state and inspection serialization. | Retain cross-mode mismatch and filtered-state rejection fixtures. |
| Atomic-failure/rejection builders | Add fault injection around terminal creation, each consumer transaction, duplicate acknowledgement, and stale follow-up handling. | Preserve tests proving no history/cursor/owner mutation on failure. |
| Save/load/reconnect fixtures | Add pending and satisfied-but-unconsumed round trips, filtered reconstruction, reconnect with partial acknowledgements, and stale-queue cases. | Preserve unsupported-version, malformed-body, and missing-inspection rejection fixtures. |
| Network/replay fixtures | Add acknowledgement ordering, protocol mismatch, mirror non-synthesis, replay history-only, and both two-human principals. | Preserve unknown-command, wrong-player, and invalid-sequence rejection fixtures. |

The inventory is complete only when direct `GameState.new()`/`initialize()`
builders, `current_attack_state_fixture.gd`, shared attack/protocol helpers,
atomic-failure helpers, save/load/reconnect fixtures, and baseline replay/network
fixtures have each been classified as valid canonical setup or intentional
invalid setup. Existing MATCH-001-style late fixture migration is not
acceptable.

## 7. Compatibility And Fixture Allocation

Inspected current values are `SaveGameMetadata.CURRENT_VERSION == 4`,
`GameReplay.FORMAT_VERSION == 6` (including signed alias), and
`NetworkManager.PROTOCOL_VERSION == 2`. No source or accepted workbook assigns
their next values. Allocate them atomically:

| Owner | Current | UX-005 | Disposition |
| --- | ---: | ---: | --- |
| `SaveGameMetadata.CURRENT_VERSION` | 4 | 5 | New v5 saves require inspection state. Reject v4 before body installation; never infer from UI/timer/flow. |
| `GameReplay.FORMAT_VERSION` / signed alias | 6 | 7 | New format carries acknowledgement semantics. Reject v6 before command application; never synthesize missing acknowledgement. |
| `NetworkManager.PROTOCOL_VERSION` | 2 | 3 | Required: UX-005 adds the serialized `acknowledge_attack_result` command type and its inspection-identity payload to the accepted command stream/broadcast vocabulary. A protocol-2 peer cannot deserialize/validate that command or reproduce the canonical acknowledgement barrier and would otherwise diverge. Strict handshake rejects mixed semantic peers before play. |
| `BaselineTrace.FORMAT_VERSION` | 1 | 1 unless trace schema changes | Replay/history changes alone do not alter trace-record schema. |

There is no compatibility reader, dual write, fallback, automatic migration,
or parallel legacy continuation. Rollback after activation reverts the whole
cutover; v5 saves and format-7 replays are never relabelled for earlier code.

Rerecord `tests/fixtures/baseline_traces/replay_hot_seat_solo.json` and
`tests/fixtures/baseline_traces/replay_network.json` from valid UX-005 play.
Generate candidate traces; review added acknowledgement/release order and state
hashes; promote only accepted canonical artifacts under the Replay Baseline
Workflow. Preserve old fixtures in version control; do not edit headers,
sequences, or payloads to fake migration.

## 8. Execution And Verification Gate

Execute in one semantic cutover after optional behavior-inert value substrate:

1. Add inspection value, `GameState` validation, and resolved-outcome transfer.
2. Add atomic terminal creation/no-overtake guard.
3. Add/register acknowledgement command, submission-principal resolution,
   applicability, serialization, replay, broadcast/mirror classification.
4. Add narrow CommandProcessor release evaluation and atomic consumption to
   every listed existing consumer command.
5. Replace panel-local authority with projection/submission and retire timer.
6. Activate persistence/filter/replay/reconnect/protocol versions and migrate
   baseline fixtures.

Focused evidence must cover:

- immutable inspection validation, Hot-Seat one HUMAN, Network two HUMAN,
  partial/final acknowledgement, zero-HUMAN no-create, and all rejection cases;
- atomic create/retire/rollback, snapshot immutability, and no repeated attack
  or damage for ship and squadron results;
- all four CON-007 contexts, derived-only outcomes, automatic mutation,
  exact-once consumption, consumer failure preserving satisfied inspection;
- live-authority-only follow-up, broadcast order, mirror non-synthesis,
  history-only replay, and reconstruction through the same seam;
- complete Hot-Seat/Network result presentation, independent dismissal, no
  timer advancement, save/load, filtering, reconnect reconstruction, v5/v7
  round trips, strict v4/v6 rejection, and protocol mismatch;
- ADR-001/CON-001, ADR-005/CON-005/TEST-003, ADR-006/CON-006, TWI-003,
  MATCH-001, current-attack shared protocol, and attack-panel resume regression.

Run focused unit/integration suites, protected current-attack/timing-window/
network/replay/save suites, `./scripts/run_tests.sh`,
`./scripts/run_baseline_traces.sh --all` after fixture promotion, repository
lint/architecture checks, `git diff --check`, and structural searches proving
no result timer/local flag/scene callback submits progression or mutates the
inspection. The targeted UX-005 verification must additionally prove: the
four-context Gate B trace; protocol-2 handshake rejection against protocol 3;
the complete fixture inventory; installation-before-release ordering for
pending and satisfied inspections; duplicate callback and stale queued
follow-up rejection; atomic consumer failure preservation; and
`can_save_now()` behavior for pending and satisfied-but-unconsumed inspections.
UX-005 is ready for final manual Hot-Seat and two-human Network verification
only after those checks pass.

## 9. Stop Conditions And Exclusions

Stop for architecture clarification if any supported context needs a new
continuation owner, generic command/descriptor/queue/FSM, second canonical
owner, or a transaction boundary that cannot atomically couple consumption;
if the accepted MATCH-001 source/authorisation is unavailable; if a
replacement-peer entitlement is needed; if a timer/UI/peer/player-index/name
would be used as authority; if an accepted authority conflicts; or if the
current compatibility owners differ from Section 7.

Excluded: generic acknowledgement/continuation/interaction frameworks; bots or
session/controller redesign; timing-window participation; new attack/damage
rules; legacy artifact reinterpretation; automatic acknowledgement; and
presentation-owned gameplay. No new Project Owner decision is required: the
accepted authorities make this plan deterministic. The existing reconnect
entitlement stop remains out of scope.

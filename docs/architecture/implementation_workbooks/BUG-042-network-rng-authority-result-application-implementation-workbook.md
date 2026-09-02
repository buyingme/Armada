# BUG-042: Live Network RNG Authority And Result Application Implementation Workbook

Status: Draft — STOP GATE TRIGGERED. Not implementation-authorizing. Hidden damage-deck/facedown-count passive reconstruction model must be resolved before refinement and acceptance; this workbook does not itself authorize implementation

Purpose: repair BUG-042 by implementing accepted ADR-012 and the accepted
CON-001 RNG amendment. This is a bounded execution specification, not a new
RNG, replay, filtering, save, or Network architecture decision. No production
code or tests are changed by this workbook.

## 1. Classification, Authority, And Entry Result

Classification: **Bounded Architecture**. The Owner selected the live RNG
model in accepted ADR-012, and the accepted CON-001 amendment makes its
attack-command obligations testable. The remaining work is a contained
translation of that authority into the existing result transport, command
processor, filtered reconstruction, and four direct RNG-command seams.

Binding authority, in precedence order:

- accepted [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md), especially NET-001--011, REPLAY-001--004, FAIL-001--002, and TEST-001--012;
- accepted [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md), especially Sections 2--4 and 7;
- accepted ADR-001 / CON-001 command ownership and atomic semantic-attack
  transaction requirements;
- accepted ADR-008, ADR-011, and MATCH-003 only for their retained Network
  authority, filtered reconstruction, admission, and assignment boundaries;
- the BUG-042 issue and preserved BUG-042 architecture investigation as
  implementation evidence, not as architecture authority; and
- current production code and focused tests named below.

This workbook consumes the settled Owner decision. It SHALL NOT reconsider
shared resumable client RNG, alter `StateFilter`'s RNG removal, or treat the
historical BUG-011 normal-live shared-seed implication as current authority.

### 1.1 Fixed execution contexts

| Context | Required execution model | Explicitly not permitted |
| --- | --- | --- |
| Local authoritative / Hot-Seat | The complete `GameState.rng` exists and authoritative commands consume it. | A Network-result-only path or changed replay behavior. |
| Live Network authority | The host/server alone holds and advances live RNG, then atomically commits the realized result through the semantic command. | Sending seed/current RNG state, future-stream information, or delegating random generation. |
| Passive live Network mirror (fresh, resumed, reconnected) | The filtered state may have `rng == null`; the same command transaction validates and applies its viewer-authorized authority result. | Constructing, restoring, advancing, or using a live RNG; calculating a replacement outcome. |
| Authority save/load | The full saved RNG state restores before later authoritative execution. | Continuing authority execution with absent/invalid RNG. |
| Replay | The accepted replay seed plus ordered semantic command history reconstruct and re-execute RNG consumption. | Persisting/reading live result payloads as replay decisions or using passive-result mode. |

Non-command RNG consumers remain outside the command-result mechanism. Setup
damage-deck initialization and any accepted setup/bootstrap resolver continue
to reach passive peers only through their existing, appropriately filtered
state-publication/synchronization surface. This workbook does not turn them
into commands or create a generic result service.

### 1.2 Entry result

| Gate | Result | Evidence / implication |
| --- | --- | --- |
| Live authority choice | PASS | ADR-012 requires authority-only live RNG and passive validated application. |
| Passive filtered state | PASS | `StateFilter` removes `rng`; `GameState.deserialize()` intentionally permits absent RNG. |
| Ordered result seam | PASS WITH BOUNDED CHANGE | `GameManager` buffers by command sequence, but currently calls `submit_mirror(cmd)` without `result`. |
| Command ownership / atomicity | PASS WITH BOUNDED CHANGE | `CommandProcessor` already validates, executes, records, advances cursor, emits, and suppresses mirror follow-ups; it needs a result-aware mirror execution mode. |
| Direct RNG consumer inventory | PASS | Four commands directly dereference `GameState.rng`: Roll Dice, ordinary reroll, Concentrate Fire token reroll, and Select Evade Die. |
| Authority save/load and replay | PASS AS PRESERVED BOUNDARIES | Save serialization includes RNG and replay remains seed plus command history; both require regression proof, not redesign. |
| Fresh live bootstrap privacy | FAIL / REQUIRED SLICE | Normal Network configuration broadcasts `rng_seed` and independently initializes client RNG. This conflicts with ADR-012 even before resume. |

**Overall entry result: PASS FOR DRAFT WORKBOOK REVIEW.** Implementation may
start only after this workbook is accepted and no Section 10 stop gate is
triggered.

## 2. Root Seam And Selected Transaction Strategy

The failing production chain is:

```text
authority save/load preserves RNG
-> StateFilter removes RNG for passive resume/reconnect
-> GameState.deserialize() installs rng == null on passive peer
-> ordered Network result reaches GameManager
-> GameManager calls CommandProcessor.submit_mirror(command) without result
-> normal command execute() dereferences GameState.rng
-> mirror rejects; cursor and queue stop fail-closed
```

The selected smallest strategy is **a result-aware execution mode of the
existing command transaction**, not a new mutation owner:

```text
authority: validate command + execute with live RNG + atomically commit
           -> serialized semantic command + transient viewer-authorized result
passive: ordered envelope + filtered canonical pre-state + result
           -> CommandProcessor result-aware mirror submission
           -> command validates command/pre-state/result, applies same canonical mutation
           -> record history and advance cursor once
           -> only then emit successful presentation effects
replay: semantic command history + replay seed -> normal authoritative command execution
```

The processor remains responsible for ordering, preflight, validation,
history, cursor, signal timing, and mirror follow-up suppression. Each command
remains responsible for its semantic validation, structural result validation,
and atomic canonical mutation. `GameManager`, `NetworkManager`, transport,
projection, scenes, modals, and UI SHALL NOT write a random outcome into
canonical state.

The concrete API names are intentionally implementation-local. The required
behavior is a narrowly typed/identified authoritative-result input accepted
only by passive mirror execution. It SHALL NOT become a generic
"apply-result" mutation API usable by arbitrary commands or callers.

## 3. Affected RNG Consumer Inventory And Result Contracts

All four commands below are live-Network authority-only RNG consumers. Their
normal authoritative `execute()` continues to generate from `GameState.rng`.
Their passive execution validates and consumes the transported result instead.
For every contract below, command sequence, command type/player/payload,
current attack lifecycle identity, phase/stage, selected current pre-state,
and existing authorization/legality remain validated by the normal command
and processor surfaces before mutation.

No result may contain the live seed, current/resumable RNG state, draw order,
unrealized future output, or unrelated secret. Result fields must be filtered
per receiver whenever existing visibility rules require it. If a required
canonical mutation cannot be applied from facts authorized to a given viewer,
stop under Section 10 rather than disclose a hidden fact or locally calculate
it.

| Command | Authority-only random action | Passive contract: minimum validated result facts and canonical mutation |
| --- | --- | --- |
| `RollDiceCommand` | Roll the canonical pre-roll dice pool. | `attack_id`; complete ordered `dice_results`. Validate result count/color against the filtered canonical pool and each face/color schema; validate exact active attack and pre-roll stage. Atomically install results, transition to attack-modify, and perform the existing deterministic ship-target recording. |
| `RerollAttackDieCommand` | Reroll selected Swarm attack die. | `attack_id`, `die_index`, `old_result`, `new_result`, complete resulting `dice_results`, and `source_rule_id`. Validate selected pre-state exactly matches `old_result`, index/source legality, replacement color equals old color, face schema, and complete array consistency. Atomically replace only that canonical die result. |
| `UseConcentrateFireTokenRerollCommand` | Reroll selected die and spend the accepted Concentrate Fire token. | `attack_id`, stable attacking/runtime source identity, semantic key, used resolution, die index, old/new result, and complete resulting dice. Validate the existing Concentrate Fire context/cost identity, selected pre-state, old/new color/face and complete array. Atomically replace the die, set token resolution used, and spend the same canonical token with rollback on any failure. |
| `SelectEvadeDieCommand` | At medium/close, reroll the selected die; at long range, remove it without a draw. | `attack_id`, defender identity, token index, die index, old/new result form, and complete resulting dice. Validate existing defender/token/pending-effect state and exact old die. Long range requires an empty/no replacement result and array equal to removal; medium/close requires same-color valid replacement face and array equal to replacement. Atomically update dice, pending evade, resolved effect, and defense stage. Passive application never accesses RNG in either branch. |

The command result is a transient application input, not durable state. The
canonical post-command dice/effects/tokens become durable only because the
command commits them. Existing presentation-only result consumers continue
only after successful passive canonical application; they must not provide the
source of canonical outcome data.

### 3.1 Future consumer rule

Any future command that consumes `GameState.rng` in live Network play SHALL
add its own explicit result contract, structural/semantic validation, passive
application, and fresh/resume/reconnect/order/replay evidence before it is
integrated. This requirement does not authorize a framework abstraction.

### 3.2 Non-command classification evidence

The implementation must inventory the present non-command references before
handoff and record their context, without changing their ownership:

| Present surface | Classification and required proof |
| --- | --- |
| `FleetSetupBootstrapper` / damage-deck initialization | Authority/setup consumer. Authority initializes; passive fresh peer receives only the resulting filtered canonical state (including the existing redacted deck surface), not RNG or a command result. |
| `LearningScenarioPreparer` and board scenario setup | Existing setup publication consumer. Prove it is not invoked as passive live random execution; if it is, route its realized state through its already accepted filtered bootstrap/publication path, not a new command result. |
| Replay/bootstrap seed handling | Replay-only reconstruction input. Preserve its accepted seed handling and prove it is not reused to seed a normal passive live peer. |

## 4. Authorized Production Scope And Boundaries

| Path | Authorized bounded change |
| --- | --- |
| `src/autoload/command_processor.gd` | Add the narrowly result-aware passive mirror execution mode. It must route the result into the applicable command before canonical mutation, retain existing sequence/preflight/validation/history/cursor/signal ownership, suppress passive follow-up generation, and fail before success effects when result validation fails. Normal authority and replay modes remain RNG-executing. |
| `src/autoload/game_manager.gd` | Pass the ordered, buffered result into the processor mirror transaction and call presentation handling only after success. Preserve queue buffering and stale/duplicate behavior; failed application leaves the pending entry/cursors unchanged. Add only the context-specific installation checks required to distinguish authority/replay RNG necessity from intentional passive no-RNG installation. |
| `src/autoload/network_manager.gd` | Preserve the existing command/result envelope and ordered transport; remove normal-live fresh client seed delivery/installation. Use a narrow fresh-bootstrap path that sends the client an appropriately filtered authoritative initial state and cursor/binding through existing reconstruction/publication responsibilities. No seed, current RNG, draw order, or broad protocol/session redesign. |
| `src/autoload/lobby_manager.gd` | Coordinate normal fresh Network start so host authoritative construction/publication precedes passive filtered installation; retain current principal association/admission semantics and replay-specific bootstrap as separate paths. |
| `src/core/commands/roll_dice_command.gd` | Implement the Section 3 result contract and atomic passive result application; retain normal authority/replay RNG execution. |
| `src/core/commands/reroll_attack_die_command.gd` | Implement the Section 3 result contract and atomic passive result application; retain normal authority/replay RNG execution. |
| `src/core/commands/use_concentrate_fire_token_reroll_command.gd` | Implement the Section 3 result contract, including cost/token atomicity and rollback; retain normal authority/replay RNG execution. |
| `src/core/commands/select_evade_die_command.gd` | Implement the Section 3 result contract for both long-range removal and medium/close reroll. Remove the unnecessary live-RNG dereference on the non-reroll branch without changing gameplay semantics. |

Expected supporting-only production review: `src/core/network/state_filter.gd`,
`src/core/state/game_state.gd`, `src/core/setup/fleet_setup_bootstrapper.gd`,
`src/core/setup/learning_scenario_preparer.gd`, replay bootstrap paths, and
existing Network fresh/resume/reconnect RPC callers. They are evidence and
regression surfaces unless a listed authorized caller needs a narrow wiring
change. `StateFilter`'s RNG removal itself is not an authorized change.

Not authorized:

- generic command-result/result-event infrastructure or a second canonical
  mutation path;
- replay result history, replay format/seed-policy redesign, or replacing
  seed-plus-command-history execution;
- broad `StateFilter`, `GameState`, save ownership/schema, damage-deck, or
  filtered-state redesign;
- Network principal, assignment, reconnect, admission, protocol, or session
  architecture beyond the bounded fresh bootstrap/result semantics above;
- UI/projection/scene-owned mutation or presentation-driven random outcome;
- changes to current-attack ownership/lifecycle, Rule Capability Packages,
  unrelated RNG consumers, or BUG-035 behavior/workbook; and
- synthetic full-state client fixtures offered as a substitute for production
  filtered-state evidence.

## 5. Implementation Slices

Each slice is independently reviewable and must leave the listed preserved
contexts passing before the next begins. Do not ship a partially converted
command catalog or an intermediate fresh Network path that still shares live
RNG.

### Slice 1 — Result-aware passive command transaction

Implement the processor/manager seam so an ordered passive result reaches the
command before execution and outcome validation precedes all mutation, history,
cursor, follow-up, and presentation success effects. Preserve normal
authority, local, and replay execution modes. Add an explicit failure channel
that makes missing/malformed/inapplicable result rejection observable without
advancing ordering.

Exit evidence: result-aware unit tests prove command identity/sequence,
preflight, command validation, failure atomicity, exact-once history/cursor,
no passive follow-up, and no presentation-on-rejection. Existing non-RNG
mirrored commands still use their current semantics unchanged.

### Slice 2 — Four command contracts and atomic passive application

Implement the four Section 3 contracts one command at a time. Reuse each
command's existing canonical setters and rollback behavior; do not let a
transport/helper write dice, token, defense, or current-attack state. Cover
all result fields, stale pre-state, malformed data, wrong identities, and
exactly one accepted application.

Exit evidence: each command works authority -> passive filtered mirror without
RNG, while the same serialized command works replay from seed without result.
All failure variants preserve canonical state, history, cursor, follow-up
queue, and success presentation.

### Slice 3 — Fresh Network privacy-conforming bootstrap

Replace normal live Network shared-seed client construction with host
authoritative construction plus a filtered initial passive installation. Keep
the established replay-only Network seed bootstrap separate. Reuse the
existing filtered reconstruction/cursor/binding validation and publication
responsibilities where possible; do not merge fresh match assignment with
resume/reconnect policy.

Exit evidence: a fresh passive peer has no live RNG and no hidden deck order,
yet receives sufficient filtered canonical state for the first accepted
authority result; the host retains full RNG and save/replay remain unchanged.

### Slice 4 — Production-path integration, security, and regression handoff

Exercise fresh, filtered fresh-session resume, confirmed reconnect, ordering,
save/load continuity, replay, and result privacy through real production
paths. Extend the existing process-isolated Network-resume harness when it
can carry these scenarios; do not replace it with an in-memory mirror.

Exit evidence: Section 6 matrix passes, manual QA is recorded, no result/RNG
data leaks, and all repository checks in Section 9 pass.

## 6. Required Regression Matrix

The following is minimum mandatory evidence. All host/client comparisons use
the accepted public/filtered canonical projection or deterministic accepted
hash, not full host/client serialization, because secrets intentionally differ.

| Area | Production-path proof and assertions |
| --- | --- |
| Fresh live Network play | Through the real fresh lobby/bootstrap path with separate host/client memory, prove passive bootstrap has `rng == null`, no seed/current state, and no hidden damage-deck draw order. Authority performs Roll Dice then a reroll; passive applies both results, histories/cursors advance once each, and the authorized canonical attack view converges. |
| Fresh-session filtered resume | Use a real saved authority state after prior RNG consumption. Pass the actual `StateFilter` resume snapshot (`rng == null`) through the assignment/staging/install/ACK path. Execute at least two sequential RNG commands; no fallback RNG or queue stall, and history/cursor advance exactly twice. |
| Confirmed reconnect | Use the production confirmed-disconnect, explicit assignment, filtered snapshot, installation ACK, and admission path. Do not reload host state/cursor. First and second post-reconnect random results apply once and converge; reconnecting peer receives no RNG state. |
| Ordering and exact once | Send prerequisite/random/later result envelopes out of order plus a duplicate through the existing ordered-result receiver. Buffer until contiguous; apply each accepted transaction once. Missing, malformed, stale, duplicate, wrong-command, wrong-identity, wrong-pre-state, and inconsistent-result variants fail closed: no mutation/history/cursor/follow-up/presentation and no later sequence bypass. |
| Command contracts | Direct contract tests for Roll Dice; ordinary Swarm reroll; Concentrate Fire token reroll including token cost/rollback; and Select Evade at medium/close reroll and long-range removal. Assert permitted result fields, result shape/semantic checks, no RNG access on passive, and unchanged authority/replay behavior. |
| Authority save/load continuity | Compare uninterrupted host execution with a host save/load fork across at least two later RNG commands. Outcomes, canonical authority state, history/order, and final RNG state match. A separately filtered passive fork applies those results without RNG. |
| Replay | Persist only replay seed plus semantic command history containing at least Roll Dice and a reroll. Replay does not receive live results, deterministically regenerates outcomes, and exactly reproduces authority canonical state/history/cursor. |
| Information hiding | Inspect fresh configuration/bootstrap payloads, filtered snapshots, command envelopes, result payloads, logs/assertions, and client state. Live seed/current state, future stream, hidden draw order, and unrelated RNG-coupled secret are absent. Assert result fields are no more than the receiving viewer's authorized realized facts. |
| Non-command consumers | Prove damage-deck/setup effects reach passive peer through filtered state publication rather than command result handling. Establish with execution tracing or focused integration evidence that learning-scenario/setup paths do not invoke live passive RNG. |
| Existing boundaries | Hot-Seat retains RNG execution; authority saves retain RNG; replay bootstrap retains replay-seed behavior; existing StateFilter unit expectations remain; MATCH-003 fresh resume/reconnect assignment, admission, and filtering suites remain passing. |

Required automated evidence paths (new focused tests may be placed adjacent to
these established seams):

| Path | Required coverage |
| --- | --- |
| `tests/unit/test_network_command_result_ordering.gd` | Result-aware ordered buffering, duplicate/stale/malformed fail-closed behavior, no cursor/history/presentation advance after rejection. |
| `tests/unit/test_attack_commands.gd` | Roll Dice and Select Evade result contracts, authority/replay preservation, both Evade range branches. |
| `tests/unit/test_concentrate_fire_timing_window.gd` | Concentrate Fire token reroll result contract, cost/rollback, timing-window preservation. |
| Existing Swarm/rule command tests or a focused sibling | `RerollAttackDieCommand` result contract and source legality. Preserve Rule Capability evidence; shared protocol does not replace it. |
| `tests/unit/test_state_filter.gd` | Continue asserting that filtered passive views contain no RNG. |
| `tests/integration/test_current_attack_shared_protocol.gd` and `tests/integration/test_current_attack_production_resume.gd` | Command-owned protocol, filtered reconstruction, save/load, mirror/replay distinction, and all four direct RNG consumers with real filtered pre-state. |
| `tests/integration/test_reconnection_mid_attack.gd` and Network-resume integration suite | Production filtered resume/reconnect path, identity/cursor, no host reload, post-reconnect result application. |
| `tests/integration/test_network_transport.gd` plus `tests/acceptance/network_resume/*` and `scripts/run_network_resume_acceptance.sh` | Separate-process ENet fresh/resume/reconnect, bootstrap/privacy, ordered result, and machine-readable evidence. Update protocol only if exact transport compatibility evidence proves a cutover is required; otherwise do not invent one. |
| Replay/save tests (`test_game_replay`, `test_replay_driver`, `test_save_game_manager`, relevant shared protocol tests) | Seed-plus-history replay and authority save/load RNG continuity with no persisted live results. |

Synthetic full-state host/client mirrors may support focused command unit tests,
but do not satisfy fresh/resume/reconnect acceptance by themselves.

## 7. Manual QA

Use separate real host and client processes/builds with isolated user roots;
capture build/commit, protocol version if changed, assigned sides, command
sequences, state/cursor observations, and redacted logs. Do not record or
print seeds/current RNG state as evidence.

1. Start a normal fresh Network match. Verify the client has a playable
filtered board but no RNG/deck-order disclosure. Resolve an attack roll and
then a reroll; both peers show the same authorized dice and next decision.
2. Save after at least one RNG consumer, close the match, and use the normal
fresh-session resume/side-assignment path. Confirm the staged client snapshot
has no RNG. After publication, resolve two consecutive RNG actions and verify
no stalled pending-result queue, duplicate modal, or cursor mismatch.
3. During an eligible attack decision, disconnect the passive client, follow
the confirmed-loss reconnect path, and reconnect/assign a new endpoint. Verify
host state/cursor do not reload, client has no RNG, and two subsequent random
results apply exactly once.
4. Exercise long-range Evade removal and medium/close Evade reroll, ordinary
Swarm reroll, and Concentrate Fire token reroll as available. Verify result
visibility follows current viewer permissions and no user interface performs
an independent mutation.
5. Export/replay a match containing multiple RNG commands. Confirm replay
works without recorded network results and reaches the authoritative outcome.
6. Inspect network diagnostics/payload capture at the approved redacted level:
no normal-live seed/current RNG, hidden draw order, future draw, or unrelated
secret is present in client bootstrap, resume/reconnect snapshot, command, or
result traffic.

## 8. Acceptance Criteria

BUG-042 is ready to close only when all are true:

1. Live Network authority is the only live RNG owner/advancer; no passive
   fresh, resumed, or reconnected peer receives, creates, restores, or uses it.
2. Every current direct RNG command has an explicit Section 3 result contract
   and applies viewer-authorized realized output inside its command transaction.
3. Result validation completes before mutation/history/cursor/follow-up/success
   presentation; any invalid/inapplicable result fails closed exactly as
   ADR-012 and CON-001-NET-011 require.
4. Host/mirror converge on authorized canonical results in sequence order and
   each accepted result has exactly one canonical application/history entry/
   cursor advance.
5. Fresh bootstrap, filtered resume, and reconnect use real production paths,
   preserve information hiding, and permit subsequent RNG commands without
   synthetic state or fallback RNG.
6. Authority save/load preserves and restores its RNG stream; replay remains
   deterministic seed-plus-command-history execution with no live result log.
7. Non-command RNG consumers remain on existing filtered publication/
   synchronization surfaces and do not acquire generic result handling.
8. All Section 6 automated evidence, Section 7 manual QA, existing applicable
   regression suites, repository quality checks, and scoped diff review pass.
9. BUG-035 remains untouched and independently verifiable; no BUG-042 change
   is credited as BUG-035 reconstruction/convergence work.

## 9. Verification Before Handoff

Implementation must run the focused unit/integration tests named in Section 6,
the process-isolated Network acceptance runner, relevant replay/save/filter/
current-attack/timing-window/rule suites, `./scripts/run_tests.sh`,
`./scripts/run_baseline_traces.sh --all`, `./scripts/lint_phase_k.sh`,
`./scripts/quality_check.sh`, `git diff --check`, and final scoped diff/
worktree review.

The handoff record must include:

- the four-command consumer inventory and result-contract evidence;
- production fresh/resume/reconnect trace identifiers showing filtered
  `rng == null` passive installation and successful later application;
- authority save/load and replay comparison results;
- result/bootstrapping privacy inspection evidence with secrets redacted;
- exact-once/ordering rejection evidence; and
- confirmation that no persistent result-history, `StateFilter` redesign,
  generic result mutation path, replay redesign, save ownership change, or
  BUG-035 change entered the diff.

## 10. Implementation Stop Gates

Stop and request Project Owner direction rather than improvise if any discovery
requires:

- sharing, reconstructing, or seeding a passive live peer with live RNG,
  current state, future stream, or hidden draw order;
- changing replay seed-plus-command-history semantics, replay file schema,
  replay seed policy, or persisting live result payloads as replay history;
- changing `StateFilter`'s accepted RNG boundary, broader filtering policy,
  `GameState` ownership, save ownership/schema, damage-deck ownership, or
  Network principal/assignment/admission architecture;
- placing canonical random outcome mutation in transport, `GameManager`,
  projection, scene, modal, or UI code, or creating a generic result/mutation
  framework;
- a command result that cannot be structurally and semantically validated from
  the command, authoritative order, accepted filtered pre-state, and
  viewer-authorized fields, including required result fields that would leak
  hidden information;
- a need to invent a fresh bootstrap publication order, new authoritative
  owner, or broad protocol/session redesign not resolvable by the existing
  host construction and filtered publication seams;
- loss of authority save/load continuity, deterministic replay, command
  atomicity, exact-once behavior, or accepted rule-capability/timing-window
  evidence; or
- production/test scope materially beyond Sections 3--6 or any BUG-035
  reconstruction, routing, or convergence change.

Current stop-gate status: **clear for this Draft specification.** No unresolved
Owner architecture decision is known. The stale "Draft" wording retained in
the accepted ADR-012/CON-001 document templates is administrative text that
conflicts with their stated accepted status and 2026-09-01 acceptance/update;
it is not a reason to reopen the Owner's settled RNG decision. If repository
governance requires correcting that wording, do so as a separate documentation
action rather than changing this workbook's architecture.

## 11. Targeted Consistency Check

Drafting checked this workbook against the accepted ADR-012 decision,
CON-001's accepted RNG amendment, the BUG-042 issue/investigation, and current
implementation evidence:

| Check | Result |
| --- | --- |
| Authority-only live RNG; passive result application | Consistent. The workbook prohibits passive RNG and locates outcome application inside the command transaction. |
| Command ownership, atomicity, order, and fail-closed semantics | Consistent. The proposed processor seam preserves existing ownership and makes result validation precede mutation/history/cursor/presentation. |
| Four direct command consumers | Consistent with current code inventory: Roll Dice, attack reroll, Concentrate Fire token reroll, Select Evade Die. |
| Fresh/bootstrap versus resume/reconnect | Consistent with ADR-012: both passive paths are filtered/no-RNG; current shared-seed fresh bootstrap is identified as required repair, not preserved behavior. |
| Replay and authority save/load | Consistent. Normal/replay authority paths retain RNG; live results remain transient and excluded from history/replay. |
| Information hiding and non-command consumers | Consistent. `StateFilter` removal and filtered setup publication are preserved; no generic result mechanism is introduced. |
| Current implementation seam | Consistent. `NetworkManager` transports `result`; `GameManager` orders it but calls result-blind `submit_mirror`; direct commands dereference RNG; this explains the issue without assuming a new owner. |
| Scope separation | Consistent. BUG-035 is expressly excluded; MATCH-003 is consumed only for retained filtered resume/reconnect boundaries. |

No unresolved Owner decision was found. This Draft is **ready for independent
workbook audit**. Audit must verify the result-field contracts against actual
visibility permissions and fresh-bootstrap wiring before Owner acceptance; a
discovered unresolved permission/owner conflict invokes Section 10 rather than
authorizing invention.

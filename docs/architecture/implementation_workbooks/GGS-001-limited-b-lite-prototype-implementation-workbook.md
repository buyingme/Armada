# GGS-001: Limited B-Lite Prototype Implementation Workbook

Status: Draft

Purpose: Economically falsifiable implementation workbook for one experimental
Golden Gameplay Sample (GGS) B-lite vertical slice

Implementation status: Not started

Implementation authorization: None. This revised Draft must be independently
audited and accepted by the Project Owner before implementation begins.

Decision input: Project Owner direction recorded on 2026-10-06. The direction
authorizes revision of this Draft and fixes the experiment constraints in §2.
It does not mark this workbook Owner-accepted.

Primary evidence:

- [GGS-001 decision workbook](../decision_workbooks/GGS-001-golden-gameplay-ui-assurance-decision-workbook.md)
- [GGS-001 adversarial repository audit](../evidence/GGS-001-adversarial-repository-audit.md)
- [Independent B-lite workbook adversarial audit](../evidence/GGS-001-b-lite-prototype-workbook-adversarial-audit.md)

## 1. Revised Verdict And Purpose

The independent audit verdict is **PASS WITH REQUIRED REFINEMENTS**
([audit §1](../evidence/GGS-001-b-lite-prototype-workbook-adversarial-audit.md#L1)).
The underlying B-lite concept remains sound: serialized authoritative S0, an
exact cursor, ordinary commands, replay-mode execution, and a final canonical
digest reuse existing Armada authority rather than creating another gameplay
engine.

The previous Draft was too broad and spent too much before testing its highest
risk. This revision replaces the two-family/Large plan with one maneuver-family
experiment whose work through the first genuine Owner-recorded Candidate must
remain a **Medium-sized work package**.

The experiment tests this narrower hypothesis:

> A genuine Owner-recorded maneuver obstacle-order sequence can provide a
> practical verification or diagnosis advantage over the nearest focused test
> without substantial fixture engineering, duplicate authority, or permanent
> infrastructure.

Technical feasibility is necessary but insufficient. The first Candidate must
show a clearly observable marginal advantage in at least one of these forms:

1. reproduce meaningful production gameplay with materially less synthetic
   setup than the nearest focused test;
2. localize a regression or first divergence more effectively; or
3. provide reusable executable evidence that is cheaper to understand or rerun
   during later feature work.

If no material marginal advantage is observed, the default outcome is **STOP**.

## 2. Fixed Owner Decisions

The following decisions are inputs and are not reopened by implementation:

1. Proceed with the limited B-lite experiment.
2. All work through the first genuine Candidate is one Medium-sized package. If
   evidence indicates Large effort is required, stop and return to the Owner.
3. The only initial S0 boundary is
   `maneuver_obstacle_order_choice_v1`.
4. Candidate capture is a lightweight extension of genuine Owner gameplay, not
   fixture engineering.
5. Diagnostic comparison uses the same controlled disposable defect in shared
   production behavior for both GGS and the nearest focused test.
6. Concentrate Fire is not part of the initial experiment. It is only a
   preferred positive-control second family after a favorable first-candidate
   result and explicit Owner authorization.
7. Prototype-specific machinery is isolated and removable. No new production
   autoload or permanent runtime dependency is permitted.
8. Candidate scope uses a planned approximate command budget plus a small
   margin. No gameplay or compatibility contract contains a universal fixed
   command-count limit.
9. The experimental envelope has its own explicit version. App, save, replay,
   command, and network versions are advisory provenance only.
10. Only explicitly authorized genuine Owner gameplay may create a Candidate.
    Synthetic machinery-test data is never a Candidate.
11. The runner must directly call
    `GameManager.start_new_game_from_state()`, `GameCommand.deserialize()`, and
    `CommandProcessor.submit_replay()`.
12. Initial diagnostics are limited to command identity, immediate rejection
    reason, actual per-command canonical digests where useful, and final
    expected-versus-actual digest.
13. The obstacle-order S0 proof is a hard falsification gate before any GGS
    schema, parser, runner, recorder, or Candidate infrastructure.
14. Completion of a gate never authorizes crossing the next Owner gate
    automatically.

Still deferred:

- pre-board Setup authority; and
- the eventual full-replay start boundary.

Those decisions do not block this experiment and must not be inferred here.

## 3. Authority And Architecture Guards

Repository document authority remains governed by
[DOCUMENT_AUTHORITY.md](../DOCUMENT_AUTHORITY.md). This workbook is
implementation planning only after Owner acceptance. Existing accepted ADRs,
Contracts, gameplay state, command validation, deterministic RNG, recovery and
fixture policy remain authoritative.

The experiment must preserve these guards:

- canonical gameplay authority remains outside GGS and presentation;
- the GGS envelope stores captured authority; it does not describe or compute
  gameplay rules;
- UI reconstructs decisions from canonical state and does not supply missing
  gameplay facts;
- commands are re-executed, not replaced by persisted result envelopes;
- rejected or malformed data fails closed;
- no accepted expectation is silently regenerated;
- no existing replay, save, app, command or network version is changed merely
  for this experiment; and
- no existing implementation is made normative merely because it exists.

If a gate requires new gameplay authority, canonical state added solely for
GGS, a parallel reconstruction/execution path, or substantial production
architecture changes, the result is STOP/return-to-Owner—not permission to
expand scope.

## 4. Scope

### 4.1 Included Through The First Candidate

Only the following work is in scope:

1. baseline and economic-measurement preparation;
2. an exact feasibility proof for
   `maneuver_obstacle_order_choice_v1` using existing production authority;
3. after that proof and an Owner checkpoint, one experimental versioned
   envelope;
4. serialized canonical S0 and exact initial cursor;
5. one short ordered stream of ordinary serialized commands;
6. strict fresh-process execution;
7. direct production state installation and replay-mode command submission;
8. one expected final canonical digest;
9. minimal diagnostics listed in §2;
10. minimal bounded Debug Start/Stop capture;
11. one explicitly authorized, genuine Owner-recorded maneuver Candidate;
12. 10/10 fresh-process reliability unless Gate 0 records a better bounded
    criterion supported by repository evidence;
13. comparison with the nearest focused test; and
14. the economic/diagnostic Owner gate.

### 4.2 Explicitly Excluded

The initial experiment excludes:

- Concentrate Fire implementation or any second family;
- `maneuver_obstacle_pre_effect_ack_v1` as an allowlisted boundary;
- generic recursive structural hashes, state trees or structural diffs;
- accepted intermediate checkpoints;
- family/all discovery;
- broad catalogue or lifecycle machinery;
- compatibility migrations;
- a browser, sample browser, pause or step debugger;
- UIC bootstrap;
- UIP catalogue work;
- UIF;
- visual golden testing;
- Setup authority, replay or refactoring;
- full-replay redesign;
- arbitrary S0;
- a general declarative gameplay/state DSL;
- broad historical backfill;
- permanent GGS governance;
- CI integration or a Definition-of-Done mandate;
- automatic Candidate generation, regeneration, promotion or supersession;
- speculative save/replay/app/network/command version changes; and
- any gameplay-rule change made to satisfy the experiment.

The acknowledgement boundary may remain a future research candidate, but it
requires its own exact proof. The independent audit found that its evaluator
does not return the acting principal demanded by the old Draft and that the
cited tests do not cover the exact boundary
([audit blocking findings](../evidence/GGS-001-b-lite-prototype-workbook-adversarial-audit.md#L9)).

## 5. Repository Basis And Mandatory Reuse

### 5.1 Existing Authority To Reuse

| Concern | Existing evidence | Required posture |
|---|---|---|
| Canonical S0 | `GameState.serialize()` includes players, flow, attack/timing lifecycles, inspections, deck, binding and RNG ([game_state.gd](../../../src/core/state/game_state.gd#L1044)) | Reuse unchanged |
| Reconstruction | `GameState.deserialize()` validates canonical references and lifecycles ([game_state.gd](../../../src/core/state/game_state.gd#L1169)) | Reuse unchanged |
| Live installation | `start_new_game_from_state()` validates, reconciles timing, resets singletons, restores the cursor and publishes normal game start ([game_manager.gd](../../../src/autoload/game_manager.gd#L459)) | Runner must call directly |
| Command parsing | `GameCommand.deserialize()` uses the registered normal command types | Runner must call directly |
| Replay execution | `submit_replay()` enters the common submission path while preserving recorded sequence ([command_processor.gd](../../../src/autoload/command_processor.gd#L246)) | Runner must call directly |
| Common validation | `_submit()` performs sequence, schema, preflight, command validation, execution and history recording ([command_processor.gd](../../../src/autoload/command_processor.gd#L379)) | Never clone |
| Cursor | The sole cursor is exposed and restored by `CommandProcessor` ([command_processor.gd](../../../src/autoload/command_processor.gd#L743)) | Record exact value |
| RNG | Initial seed and current internal state are serialized ([game_rng.gd](../../../src/core/state/game_rng.gd#L60)) | Preserve and compare |
| Decision recovery | `ManeuverExecutionEvaluator.next_action()` derives obstacle-order choice from canonical overlaps and maneuver identity ([maneuver_execution_evaluator.gd](../../../src/core/movement/maneuver_execution_evaluator.gd#L113)) | Boundary signature source |
| Production board | Existing tests reconstruct the same obstacle-order decision without submitting gameplay ([test_bug_043_stabilization_projection_recovery.gd](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L66)) | Extend as exact proof |
| Canonical digest | `CanonicalJson.hash()` hashes sorted-key JSON ([canonical_json.gd](../../../src/utils/canonical_json.gd#L18)) | Reuse unchanged |

### 5.2 Mechanisms Not To Reuse Wholesale

`GameReplay` remains a full-session scenario/bootstrap artifact without paired
arbitrary S0. `ReplayDriver` remains scenario-coupled and normally logs a
rejection rather than failing immediately
([replay_driver.gd](../../../src/autoload/replay_driver.gd#L114),
[replay_driver.gd](../../../src/autoload/replay_driver.gd#L504)). The experiment
uses a dedicated thin runner, not a fork or generalization of that orchestration.

`CommandProcessor.replay_commands()` is also unsuitable because it skips an
unknown command and continues
([command_processor.gd](../../../src/autoload/command_processor.gd#L826)). The
thin runner deserializes and submits exactly one command at a time and exits on
the first failure.

### 5.3 Mandatory Stop On Cloning

Stop and return to the Owner if clean direct reuse requires:

- a GGS-specific installer instead of `start_new_game_from_state()`;
- a GGS command parser instead of `GameCommand.deserialize()`;
- direct concrete-command `execute()` calls instead of `submit_replay()`;
- duplicated maneuver/obstacle legality;
- GGS-authored continuation commands;
- persisted transport results; or
- repair of invalid S0 or command history.

## 6. The Only Initial S0 Boundary

### 6.1 Boundary ID

The initial allowlist contains exactly:

```text
maneuver_obstacle_order_choice_v1
```

No fallback such as “any state that validates” exists.

### 6.2 Canonical Boundary Contract

The boundary is after the maneuver's authoritative final transform is committed
and before the owner chooses the order of two or more unresolved overlapping
obstacles.

The proof must establish:

- full-authority Hot-Seat state;
- Ship phase and Ship Activation/Maneuver interaction flow;
- exactly one active ship activation;
- one matching open maneuver execution with stable activation and execution
  identities;
- final maneuver transform applied;
- no unresolved displacement, collision or damaged-controls obligation with
  higher priority than obstacle ordering;
- at least two canonical unresolved overlaps;
- no previously committed obstacle resolution order;
- stable obstacle IDs, types, placement order and overlap option order;
- no pending obstacle pre-effect, active obstacle resolution, immediate damage
  resolution, faceup-damage inspection or asteroid completion;
- `ManeuverExecutionEvaluator.next_action()` returns `kind == decision`,
  `command_type == commit_maneuver_obstacle_order`, the ship owner as actor,
  matching activation/execution identities, and the same obstacle options;
- the production board presents the same actionable ordering choice;
- reconstruction submits no command and does not advance history/cursor; and
- the first selected order command validates against those same identities and
  options.

The evaluator explicitly returns a decision only when multiple unresolved
overlaps exist
([maneuver_execution_evaluator.gd](../../../src/core/movement/maneuver_execution_evaluator.gd#L130)).
Existing production reconstruction and save/install tests include the
`obstacle_order` case
([test_bug_043_stabilization_projection_recovery.gd](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L66),
[test_bug_043_stabilization_projection_recovery.gd](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L145)).

### 6.3 Exact Gate 1 Proof

Before any GGS infrastructure exists, one focused feasibility test must:

1. reach the exact boundary through existing production-authoritative setup and
   command paths rather than assigning the target decision facts after capture;
2. record the current non-negative command cursor in memory;
3. serialize S0 to JSON, parse it, and call `GameState.deserialize()`;
4. prove the reconstructed state's activation identity, maneuver execution ID,
   obstacle identities/options, deck order, RNG initial seed and RNG current
   state equal the source;
5. call `GameManager.start_new_game_from_state()` directly with the recorded
   cursor;
6. prove history is empty and the cursor is unchanged;
7. derive and compare the exact canonical decision signature before and after
   roundtrip;
8. instantiate normal production board composition and prove the ordering
   choice is actionable and identical;
9. prove board reconstruction automatically submits no semantic command;
10. serialize the selected first normal command in memory;
11. deserialize it through `GameCommand.deserialize()`;
12. execute it through `CommandProcessor.submit_replay()`; and
13. prove the command is accepted with the expected cursor/history transition.

This test data is a feasibility specimen, not a Candidate and not expected
gameplay evidence.

### 6.4 Hard Falsification Conditions

Gate 1 fails and returns to the Owner if the proof requires:

- new gameplay authority;
- canonical state added solely for GGS;
- scene/process-owned gameplay facts;
- a parallel installer or reconstruction path;
- a GGS-specific command or legality rule;
- substantive changes to production gameplay architecture;
- a second boundary to make the first usable; or
- effort that makes the through-first-Candidate package Large.

Passing Gate 1 establishes only that this boundary is technically safe. It does
not prove GGS value and does not itself start Gate 2; the Owner reviews the Gate
1 evidence and explicitly authorizes the minimal vertical slice.

## 7. Candidate Authority Versus Test Specimens

### 7.1 Genuine Candidate

A genuine Candidate requires all of:

- an explicit Owner instruction naming the recording;
- genuine Owner gameplay or gameplay the Owner personally validates;
- capture from the allowlisted live boundary;
- ordinary accepted authoritative commands;
- provenance recording the Owner instruction and recording session; and
- create-new storage in the dedicated Candidate directory.

Capture writes only `Candidate`. The prototype has no promotion, acceptance,
supersession, regeneration or update command. Accepted expected gameplay remains
Owner-controlled outside this experimental machinery.

Codex must not create, synthesize, reconstruct, regenerate, replace, silently
update, or promote a Candidate. Changed behavior must never be made green by
mechanically regenerating expected outcomes.

### 7.2 Synthetic Test Specimen

Codex may create synthetic parser/schema/runner/rejection specimens for
machinery tests. Every such object must be explicitly tagged
`synthetic_test_specimen` and is ordinary test data. It must never:

- use `Candidate` status or Owner provenance;
- be stored in the Candidate directory;
- be cited as gameplay evidence;
- be promoted or renamed into a Candidate;
- supply the first repository-stored runnable Candidate; or
- be retained as an accepted expected gameplay outcome.

Prefer in-memory or temporary-directory specimens. A fresh-process machinery
test may write a tagged specimen to a temporary path and must remove it through
normal test cleanup. Normal Candidate execution rejects the specimen tag; any
test-only execution mode must be explicit and unavailable as a capture or
promotion path.

### 7.3 First Stored Runnable Evidence

Before Gate 3, no repository-stored runnable GGS file may claim Candidate
status. The first repository-stored runnable Candidate must come from the
explicitly authorized Owner recording in Gate 3.

## 8. Minimal Experimental Envelope

The envelope is implemented only after Gate 1 passes and the Owner authorizes
Gate 2.

### 8.1 Version And Fields

The root identifies its own experimental contract:

```text
artifact_kind: "armada_experimental_ggs"
ggs_format_version: 1
evidence_class: "owner_candidate"
```

The minimal owner-Candidate envelope contains:

```text
artifact_kind
ggs_format_version
evidence_class
candidate_metadata
diagnostic_provenance
scenario_id
initial_state
initial_command_sequence
commands
expected_final_digest
```

`candidate_metadata` contains only sample ID, title, `Candidate` status,
boundary ID, recording timestamp and explicit Owner-recording provenance.

`diagnostic_provenance` may record app, save, replay, command/network protocol
versions and source revision. Those values explain the environment but do not
determine GGS validity. GGS validity depends on its own format version plus
successful state/command parsing, installation and execution.

`scenario_id` is the required production reconstruction input passed to
`GameManager.start_new_game_from_state()`. It is not a proxy compatibility
version and must identify the scenario in which the Owner reached S0.

`initial_state` is one canonical `GameState.serialize()` result.
`initial_command_sequence` is an exact non-negative cursor. `commands` is a
non-empty contiguous sequence of canonical normal commands. The final digest is
`CanonicalJson.hash(final_state.serialize())`.

No expected final state, result envelope, rule semantics, structural tree,
semantic checkpoint list or compatibility migration data is stored.

### 8.2 Strict Failure

The parser/runner fails immediately on:

- unknown GGS kind or GGS format version;
- missing, unknown or wrong-typed required fields;
- wrong evidence class for the selected execution mode;
- invalid provenance/status/boundary;
- malformed S0 or final digest;
- fractional, negative or noncontiguous cursor/sequence values;
- unknown/noncanonical command serialization;
- failed state reconstruction or live installation;
- boundary mismatch;
- command deserialization, preflight, validation or execution rejection; or
- final digest mismatch.

A separate non-semantic implementation safety ceiling may reject a pathological
artifact by byte size, nesting or command count. That ceiling is defensive
resource protection only. It is not stored as gameplay architecture, a sample
promise, or GGS compatibility policy.

### 8.3 Minimal Diagnostics

Initial output contains only:

- Candidate ID and boundary;
- failing command index, sequence, type and player;
- immediate parse/installation/rejection reason;
- actual canonical digest after each command when diagnostic logging is enabled;
- expected and actual final canonical digest; and
- process exit status.

The envelope does not store expected per-command state or a recursive structural
hash/diff tree. For controlled comparison, a clean run's actual digest log may
be compared with the disposable-defect run to identify the first changed
command. Richer diagnostics require later evidence and explicit Owner
authorization.

## 9. Thin Fresh-Process Runner

For one explicitly named Owner Candidate, the runner must:

1. start a fresh Godot process;
2. parse the strict experimental envelope;
3. deserialize S0 with `GameState.deserialize()`;
4. set the fixed Hot-Seat experiment mode and call
   `GameManager.start_new_game_from_state()` directly with S0, the recorded
   `scenario_id` and the exact recorded cursor;
5. recheck the allowlisted obstacle-order boundary and empty history;
6. deserialize one command at a time with `GameCommand.deserialize()`;
7. call `CommandProcessor.submit_replay()` for each command;
8. stop immediately on the first failure;
9. optionally print the actual post-command canonical digest;
10. compare the final canonical digest; and
11. exit nonzero on any failure.

The runner must not call concrete `execute()` directly, clone production
installation, repair data, infer commands, replay result envelopes, reuse the
full `ReplayDriver`, continue after rejection, or write/update a Candidate.

Fresh-process execution avoids proving only that a singleton happened to be
restored correctly inside a long-lived test process, as recommended by the
independent audit
([audit optional improvements](../evidence/GGS-001-b-lite-prototype-workbook-adversarial-audit.md#L55)).

## 10. First Candidate Plan And Capture Budget

### 10.1 Planned Sequence

The Owner reaches a genuine two-or-more-obstacle ordering choice during normal
testing/gameplay and explicitly starts capture at
`maneuver_obstacle_order_choice_v1`. Capture ends at the first stable
post-consequence maneuver/activation decision.

Existing focused evidence shows an ordinary asteroid chain of six commands:
order commitment, pre-effect acknowledgement, obstacle resolution, faceup
acknowledgement, obstacle completion and maneuver completion
([test_candidate_obstacle_consequences.gd](../../../tests/unit/test_candidate_obstacle_consequences.gd#L222)).
Because genuine gameplay may open an additional consequence, the first sample
plan expects approximately five to eight commands with a small working margin
through ten.

This is a planning and economic-review range, not a parser limit. Actual command
count is measured. Reaching beyond the margin pauses the recording evaluation
for Owner review rather than silently broadening the sample. The defensive
resource ceiling in §8.2 remains unrelated.

### 10.2 Minimal Start/Stop Capture

Capture is editor/debug-only and held by the existing Debug-mode owner. No new
autoload is added. It may add one lazy-loaded Start/Stop action and existing
toast/confirmation style to `DebugMode`.

Start must:

1. require explicit Owner-authorized sample metadata;
2. match exactly the allowlisted boundary;
3. rerun the Gate 1 canonical decision proof;
4. store S0, exact cursor, history index and provenance in memory; and
5. begin observing successfully executed normal commands.

Stop must:

1. require the same live session;
2. slice accepted serialized history from the start index;
3. verify contiguous sequences from the recorded cursor;
4. record actual command count and final digest;
5. show the Owner a summary including retries/manual intervention;
6. require explicit confirmation; and
7. create a new Candidate file only if the target does not exist.

Cancel discards in-memory capture state only. Capture never submits, edits,
reorders, invents or repairs gameplay. Any substantial manual state
construction, JSON editing, command-history reconstruction or repeated attempt
is recorded as negative economic evidence and pauses expansion for Owner review.

## 11. Economically Falsifiable Gate Sequence

Every gate ends in an explicit evidence review. No later gate starts merely
because a test passed.

### Gate 0 — Baseline And Economic Preparation

No GGS code or artifact is created.

Required work:

1. record the nearest focused-test baseline;
2. record existing production replay/manual evidence relevant to maneuver
   obstacle consequences;
3. define measurement fields in §12;
4. record the expected file/removability inventory in §15;
5. define the shared disposable production defect planned for Gate 4;
6. record the package estimate and remaining Medium budget;
7. set the Owner thresholds marked `Owner-set before Gate 1` in §12.2; and
8. create only the measurement evidence document planned in §15.4.

Primary focused comparison:

- the constructed six-command exact-state test
  ([test_candidate_obstacle_consequences.gd](../../../tests/unit/test_candidate_obstacle_consequences.gd#L222));
- plus the boundary/actionability and save-install evidence
  ([test_bug_043_stabilization_projection_recovery.gd](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L66)).

Gate 0 stops if comparison criteria cannot be made fair, the expected package
already appears Large, or the Owner declines the measurement thresholds.

**Owner checkpoint:** approve the recorded thresholds, defect plan and remaining
Medium budget before Gate 1.

### Gate 1 — S0 Boundary Feasibility

Implement only the focused proof in §6.3. Do not implement a GGS envelope,
parser, runner, capture service, Candidate file or Candidate directory.

Gate 1 passes only if every §6.3 assertion succeeds using existing production
authority and the Gate remains within the Medium package. The result is a
technical feasibility measurement, not a Candidate.

Gate 1 fails under any §6.4 condition.

**Owner checkpoint:** review proof evidence and actual Gate 0–1 cost. Explicitly
authorize or reject Gate 2. A passing test alone does not continue the task.

### Gate 2 — Minimal One-Family Vertical Slice

Only after Gate 1 and Owner authorization, implement:

- the minimal Version 1 envelope;
- one allowlisted boundary validator;
- the strict fresh-process runner;
- direct production installation and replay submission;
- final digest and minimal diagnostic output;
- bounded Start/Stop capture; and
- machinery tests using only synthetic test specimens.

Do not implement CF, another boundary, structural diagnostics, filters,
catalogues, migrations, browser/step UI, CI or governance.

Gate 2 stops before Candidate recording if actual plus forecast work through
Gate 3 would exceed Medium, capture requires fixture engineering, or any direct
production reuse seam needs duplication.

**Owner checkpoint:** review vertical-slice cost, isolation and capture dry-run
using non-Candidate temporary specimens. Explicitly authorize or reject the
first genuine recording.

### Gate 3 — First Genuine Owner Candidate

The Owner explicitly authorizes and performs or personally validates the
recording described in §10. The first repository-stored Candidate is created
here, never earlier.

Record:

- Owner preparation and active recording time;
- attempts, cancellations and manual intervention;
- actual command count and artifact size;
- duplicated authoritative information classification;
- fresh-process execution time; and
- 10/10 fresh-process reliability, unless Gate 0 approved a better bounded
  evidence criterion.

Gate 3 stops if Candidate preparation becomes fixture engineering, repeated
attempts or manual history/JSON repair are needed, execution is not stable, or
the Medium package cap is threatened.

**Owner checkpoint:** authorize only Gate 4 comparison. Do not add a second
family.

### Gate 4 — Economic And Diagnostic Evaluation

Use the same controlled disposable defect in shared production behavior for the
nearest focused test and the GGS Candidate. Never corrupt only the GGS artifact
to claim a comparative advantage.

Measure:

- first useful failure evidence from each path;
- whether each path identifies the correct divergence/root-cause class;
- time to the correct file/function and root-cause class;
- whether the first diagnosis is correct;
- whether a fix is identified within the Owner-set cap;
- focused-test versus GGS setup, rerun and interpretation effort;
- maintenance/duplicate burden observed so far; and
- break-even reasoning from measured prototype cost and plausible reuse.

The controlled defect is reverted after measurement, and both baseline paths
must pass again. GGS may add value by locating the first divergence across a
real sequence even if the focused test remains better at naming the exact
assertion/function.

An intentional accepted gameplay-behavior change is not required before an
earlier STOP or NARROW decision. Maintenance/churn evidence is recorded when it
naturally exists. A deliberate behavior-change exercise requires separate
Owner authorization after the first economic gate.

**Owner decision:** STOP, NARROW or PROCEED experimentally under §17.

## 12. Measurement And Economic Decision Design

### 12.1 Evidence Classification

Every recorded value is labelled:

- **Measured:** observed during this experiment;
- **Estimated:** forecast with basis and uncertainty; or
- **Owner judgment:** qualitative decision that cannot be reduced honestly to a
  repository metric.

Do not convert missing history into invented precision.

### 12.2 Predeclared Gate Values

Gate 0 records these before implementation proceeds:

| Decision field | Predeclared rule |
|---|---|
| Implementation package | Fixed: no larger than Medium through first Candidate |
| Scope cap | One boundary, one family, one Candidate, isolated files in §15 |
| Maximum Owner preparation/recording effort | Owner-set before Gate 1 |
| Maximum recording attempts/manual interventions | Owner-set before Gate 1 |
| Diagnostic comparison time cap | Owner-set before Gate 1 |
| Required comparative benefit | At least one §1 advantage must be observed and judged material by the Owner |
| Break-even evaluation horizon | Owner-set plausible number/range of future reruns or diagnoses |
| Reliability | Proposed 10/10 fresh-process executions; change only with recorded evidence and Owner approval |

The unset values are genuine remaining Owner decisions, not implementation
discretion. Gate 0 cannot close until they are recorded.

### 12.3 Implementation And Tooling Cost

For each gate record, where available:

- active engineering effort;
- elapsed effort;
- Codex/credit usage;
- files added, removed and modified;
- lines added/removed;
- review and rework;
- debugging effort;
- focused and convergence verification effort;
- forecast remaining effort to first Candidate; and
- categorical Small/Medium/Large reassessment.

If actual plus forecast cost becomes Large, stop before further work and return
to the Owner.

### 12.4 Owner Capture Economics

Record separately:

- time to prepare/reach the boundary through normal gameplay;
- metadata/start effort;
- active recorded gameplay time;
- stop/review/storage effort;
- number of attempts, cancellations and retries;
- every manual intervention or debug action;
- whether any state, JSON or history was hand-constructed or repaired;
- total Owner active and elapsed time; and
- Owner judgment on whether this was a lightweight extension of normal testing.

Substantial manual construction, JSON editing, history reconstruction or
repeated attempts count strongly against GGS and trigger Owner review.

### 12.5 Artifact And Execution Measurements

Record:

- actual command count against the planned range;
- total artifact bytes and bytes by S0/commands/metadata;
- which fields duplicate authoritative information versus reference/provenance;
- fresh-process success count;
- startup, reconstruction, command and total wall time where useful;
- final digest stability;
- actual per-command digest log size when enabled; and
- any sensitivity to harmless/non-semantic serialization changes observed
  during normal work.

No generic churn experiment is required before an earlier STOP/NARROW. If
non-semantic churn evidence becomes available, record it rather than adapting
the Candidate automatically.

### 12.6 Focused-Test Comparison

For the nearest focused test record:

- how its S0 is constructed and how much is synthetic;
- setup code/fixture complexity;
- assertions and diagnostic specificity;
- runtime and rerun effort;
- maintenance characteristics;
- whether it can be reused outside its test body; and
- what, if anything, the Owner-recorded Candidate adds.

The Candidate succeeds economically only if it demonstrates at least one
material §1 advantage. Merely reproducing the same pass/fail result is not
enough.

### 12.7 Break-Even Reasoning

Use ranges, not false precision:

```text
measured prototype cost
+ measured Owner recording cost
+ estimated maintenance/removal cost
versus
plausible number of future reruns/diagnoses
× measured or estimated saving per use
```

If per-use saving is not positive or the plausible reuse range cannot amortize
the measured cost, STOP is the default. NARROW is available when break-even is
credible only for a recognizable high-risk sequence class. PROCEED
experimentally requires evidence that a second family could test broader value.

## 13. Controlled Defect Comparison

Gate 0 must identify one small, reversible defect in shared maneuver/obstacle
production behavior that both the focused test and Candidate execute. The
defect must:

- live outside GGS-specific code and the artifact;
- affect the same authoritative command/recovery path in both comparisons;
- be applied only on a disposable measurement branch/worktree;
- have a predicted root-cause class recorded before running either path;
- avoid altering either expected test data or Candidate data; and
- be reverted immediately after measurement.

Permissible examples include a temporary error in obstacle-order admission or
the shared transition after order commitment. The exact defect is chosen and
recorded at Gate 0 only after confirming both paths exercise it.

Compare from the same starting information and with the same time cap. Record
whether the focused test reaches the exact assertion faster and whether GGS
more clearly identifies the first command/digest divergence across the genuine
sequence. Neither result is predetermined.

Parser rejection specimens remain valid machinery tests, but they are not the
economic diagnostic comparison.

## 14. Verification Plan

### 14.1 Gate 1 Boundary Verification

Verify every item in §6.3, including:

- JSON roundtrip;
- `GameState.deserialize()`;
- direct `start_new_game_from_state()` installation;
- exact non-zero cursor restoration;
- activation/execution/obstacle identity preservation;
- deck order and RNG state preservation;
- identical canonical decision signature;
- actionable production board reconstruction;
- no automatically submitted gameplay; and
- first command accepted through deserialize plus replay submission.

### 14.2 Gate 2 Machinery Verification

Using only tagged synthetic test specimens in memory or temporary storage:

- strict own-format parsing;
- wrong/missing/unknown field/type rejection;
- malformed state/cursor/sequence/command/digest rejection;
- Candidate-directory rejection of synthetic specimens;
- direct installer use;
- immediate command rejection with index/identity/reason;
- actual optional per-command digests;
- final expected/actual digest;
- capture start/stop/cancel and create-new-only behavior;
- no overwrite/regenerate/promote path; and
- pathological resource-ceiling behavior without making it compatibility.

### 14.3 Gate 3 Candidate Verification

- explicit Owner authorization/provenance;
- allowlisted boundary only;
- no manual JSON/history construction;
- fresh-process execution;
- 10/10 identical final digest;
- measured command count/artifact size/runtime; and
- Candidate remains unchanged after every run.

### 14.4 Regression And Convergence

Run focused checks after the gate that touches them. Before Gate 4 decision,
run:

1. new experimental focused tests;
2. nearest maneuver reconstruction/save-install tests;
3. obstacle consequence/replay tests;
4. replay-driver focused tests;
5. relevant save/load/cursor tests;
6. hot-seat baseline replay if shared replay/command behavior was modified; and
7. one full canonical repository suite at integrated convergence.

Network convergence remains conditional on touching network filtering,
submission or result-envelope behavior. The intended prototype should not
modify those paths.

The disposable defect must first produce comparable failures, then be reverted,
after which both paths and relevant convergence tests pass cleanly.

## 15. Experimental Removability Inventory

Names are fixed planning boundaries. Implementation may refine a filename only
at the Gate 2 Owner checkpoint without expanding responsibility.

### 15.1 Expected Prototype-Only Files

| Planned path | Purpose | STOP disposition |
|---|---|---|
| `tests/experimental/ggs/test_maneuver_obstacle_order_s0_feasibility.gd` | Gate 1 boundary proof | Delete unless Owner retains it as generally useful production-recovery evidence |
| `src/ui/debug/experimental_ggs/experimental_ggs_envelope.gd` | Strict experimental envelope | Delete |
| `src/ui/debug/experimental_ggs/experimental_ggs_boundary.gd` | One allowlisted boundary validator | Delete |
| `src/ui/debug/experimental_ggs/experimental_ggs_capture.gd` | Debug-held Start/Stop capture | Delete |
| `tests/experimental/ggs/experimental_ggs_runner.gd` | Thin fresh-process runner | Delete |
| `tests/experimental/ggs/test_experimental_ggs_envelope.gd` | Parser/specimen tests | Delete |
| `tests/experimental/ggs/test_experimental_ggs_runner.gd` | Runner/rejection tests | Delete |
| `tests/experimental/ggs/test_experimental_ggs_capture.gd` | Capture safety tests | Delete |
| `tests/fixtures/experimental_ggs/owner_candidates/<sample-id>.json` | First genuine Candidate | Delete on STOP unless Owner explicitly retains it as historical evidence; never rewrite |

No synthetic JSON specimen is planned for repository storage. Tests use memory
or temporary paths.

### 15.2 Minimal Existing-File Modification

The only expected existing runtime-file modification is a small lazy integration
in [debug_mode.gd](../../../src/autoload/debug_mode.gd#L55) to invoke Start/Stop
capture while Debug mode is enabled. It must not contain gameplay rules, parser
logic or persistent state.

No change is expected in:

- `project.godot` autoloads or version;
- `GameManager`;
- `CommandProcessor`;
- `GameCommand`;
- maneuver/obstacle gameplay code;
- save/replay/network formats; or
- existing accepted fixtures.

If another existing production file requires more than a minimal debug-only
hook, stop and reassess the Medium package and removability before editing.

### 15.3 No New Production Autoload Or Dependency

Prototype classes are lazy-loaded under the experimental Debug namespace or
invoked by the test runner. Normal gameplay must not load them when capture is
inactive. No production autoload, service locator registration, startup
registration or permanent runtime dependency is permitted.

### 15.4 Evidence That Survives STOP

The planned measurement record is:

```text
docs/architecture/evidence/GGS-001-b-lite-prototype-measurements.md
```

It survives STOP because it records cost, results, cleanup and the Owner
decision. The independent audits and this workbook also remain as decision
provenance. A generally useful Gate 1 recovery test may survive only by explicit
Owner instruction after removing GGS-specific naming/assumptions if necessary.

### 15.5 STOP Cleanup Checkpoint

On STOP:

1. delete every prototype-only source/test file in §15.1;
2. remove the DebugMode integration exactly;
3. delete Candidate artifacts unless the Owner explicitly retains immutable
   historical evidence;
4. remove empty experimental directories;
5. confirm no autoload, input, project/version or runtime dependency remains;
6. run the focused regression tests affected by cleanup;
7. preserve the measurement evidence and Owner STOP decision; and
8. record any explicitly retained generally useful piece and why it is no
   longer prototype machinery.

Quarantine is allowed only when the Owner explicitly requests it and names the
destination/purpose. Silent abandoned experimental code is not an acceptable
STOP result.

## 16. Compatibility And Versioning

The envelope has only its own `ggs_format_version`. Version 1 is strict and has
no migration framework.

App, save, replay, command and network versions may be captured as diagnostic
provenance. Inequality alone does not invalidate a Candidate. Failure of the
GGS format, state reconstruction, command deserialization, production
installation or execution does.

Do not change `GameReplay.FORMAT_VERSION`, `SaveGameMetadata.CURRENT_VERSION`,
the app version, network protocol or any command contract speculatively. If the
prototype actually requires such a change, it has escaped scope and stops.

## 17. Owner Outcomes After Gate 4

### STOP

Select STOP when there is no meaningful marginal value, economics are poor,
capture becomes fixture engineering, reconstruction is unreliable, special
infrastructure is disproportionate, or the package threatens Large effort.

Apply §15.5 cleanup. Preserve evidence and the STOP decision.

### NARROW

Select NARROW when the Candidate demonstrates value only for a recognizable
class of complex/regression-prone sequences. Continue only inside that class
and only after a new explicit Owner authorization. NARROW does not automatically
retain all prototype code or authorize another sample.

### PROCEED Experimentally

Select PROCEED experimentally when the first Candidate demonstrates promising
general value sufficient to consider a second-family experiment. Concentrate
Fire is the preferred positive control, but it still requires a separate Owner
authorization and scoped follow-up task.

PROCEED experimentally does not authorize:

- permanent GGS architecture or governance;
- broad backfill;
- CI or Definition-of-Done requirements;
- UIC/UIP/UIF integration;
- Setup/full-replay work;
- arbitrary S0; or
- automatic Candidate acceptance or regeneration.

## 18. Effort Bound And Work-Package Assessment

| Gate/work | Expected size before evidence | Dominant risk |
|---|---:|---|
| Gate 0 baseline/economic setup | Small | Fair comparison and Owner thresholds |
| Gate 1 exact boundary proof | Small–Medium | Production-reached actionability without missing scene facts |
| Gate 2 minimal vertical slice | Medium | Strict fresh-process runner and lightweight removable capture |
| Gate 3 Owner recording/reliability | Small implementation; measured Owner effort | Natural reach and no fixture engineering |
| Gate 4 comparison/economic analysis | Small–Medium | Comparable shared defect and honest attribution |

These are not additive permission for a Large program. Gates 0–3 together must
remain one Medium package. At each checkpoint, actual cost plus forecast
remaining cost is reassessed. If it indicates Large, stop before more work and
return to the Owner.

Gate 4 may complete the bounded evaluation only after the Candidate exists; it
does not authorize broad tooling. Any second family is a separate estimate and
decision.

## 19. Independent Audit Refinement Closure

| Required refinement | Revised disposition |
|---|---|
| Prove boundary before schema/tooling | Gate 1 precedes all GGS infrastructure |
| Unsupported acknowledgement boundary | Removed from initial allowlist; documented only as future research |
| One harder falsification family first | Obstacle-order maneuver family only |
| Direct production installation | Runner must call `start_new_game_from_state()` directly |
| Normal command parsing/execution | Runner must call `GameCommand.deserialize()` and `submit_replay()` |
| Thin dedicated runner | Isolated fresh-process runner; no wholesale `ReplayDriver` reuse |
| Defer structural tree/diff | Explicitly excluded from initial experiment |
| Defer CF/second family | Requires favorable Gate 4 result and separate Owner authorization |
| Defer filters/migrations/browser/CI/governance | Explicitly excluded |
| Remove synthetic Candidate contradiction | Tagged test specimens are non-Candidates; first stored Candidate is Owner-recorded |
| Measure tooling cost | Gate-by-gate engineering, credit, diff, review, debugging and convergence ledger |
| Predeclare economics | Gate 0 cannot close until Owner thresholds are recorded |
| Same controlled defect | Gate 4 uses one shared production defect for both paths |
| Define localization | Correct file/function, root-cause class, first-report correctness and capped time |
| Break-even reasoning | Measured cost compared with plausible reuse savings as ranges |
| Non-semantic churn | Record when evidence exists; never silently update Candidate |
| Earlier STOP/NARROW without behavior-change exercise | Explicitly permitted |
| Remove universal command limit | Per-sample plan/margin plus non-semantic safety ceiling |
| Advisory compatibility metadata | Proxy versions do not determine validity; no migration framework |
| Explicit removability | Enumerated files, one minimal existing hook, no new autoload, exact STOP cleanup |
| Medium to first Candidate | Hard package cap and return-to-Owner condition at every gate |

## 20. Completion Criteria

The experiment reaches the Owner decision only when:

1. Gate 0 has recorded baselines, measurement definitions and Owner-set
   thresholds.
2. Gate 1 has passed every exact boundary proof without new gameplay authority
   or substantial production changes.
3. The Owner has explicitly authorized Gate 2 after reviewing actual cost.
4. Gate 2 remains isolated/removable and uses only direct production seams.
5. The Owner has explicitly authorized the first Candidate recording.
6. The first stored Candidate comes from genuine Owner gameplay.
7. Gate 3 measurements and fresh-process reliability are complete.
8. The Owner has explicitly authorized Gate 4.
9. The same controlled shared production defect has been compared and reverted.
10. Practical marginal value and break-even reasoning are recorded without
    false precision.
11. Actual plus forecast effort through the Candidate never exceeded Medium.
12. No second family, structural diagnostics, migration, catalogue, CI or
    permanent governance work was absorbed.
13. The Owner selects STOP, NARROW or PROCEED experimentally.

Technical success without practical marginal value produces STOP by default.

## 21. Remaining Owner Decisions

Before implementation:

1. accept, revise or reject this revised one-family Draft;
2. at Gate 0, set maximum Owner preparation/recording effort;
3. set maximum attempts/manual interventions;
4. set the diagnostic comparison time cap and plausible break-even horizon; and
5. approve the exact controlled-defect plan and Gate 1 start.

During the experiment:

6. review Gate 1 and explicitly authorize or reject Gate 2;
7. review Gate 2 and explicitly authorize or reject the first Candidate
   recording;
8. explicitly perform or validate the gameplay;
9. explicitly authorize Gate 4; and
10. select STOP, NARROW or PROCEED experimentally.

No Owner decision is needed now for CF, Setup authority, full-replay boundary,
UIC/UIP/UIF, compatibility migrations, CI/DoD, permanent governance or accepted
sample lifecycle. Those remain deferred or out of scope.

## 22. Recommended Next Task After Acceptance

If the Owner accepts this workbook, the next task is **Gate 0 only**: collect the
focused-test/replay/manual baseline, measurement ledger, exact
disposable-defect plan and removability confirmation. Gate 0 cannot close until
the Owner-set thresholds are recorded.

Gate 0 must return its evidence to the Owner. It must not begin the Gate 1 test
automatically. No GGS source, schema, runner, capture code, Candidate directory
or artifact is created by that task.

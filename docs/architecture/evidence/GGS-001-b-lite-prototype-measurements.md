# GGS-001 B-Lite Prototype Measurements

Status: **Gate 1 hard falsification failed — Owner review required**

Evidence date: 2026-10-06

Owner decisions recorded: 2026-10-07

Gate 0 Owner-accepted: 2026-10-07

Source revision: `39d12ff3ee93cacb3f4faa0d0ca48fcaa7a69633`

This is the measurement record authorized by
[the accepted GGS-001 implementation workbook](../implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md).
Gate 0 created no GGS code, artifact, Candidate, fixture, or directory and made
no gameplay change. The Owner-set values are now recorded below. Gate 1 remains
unauthorized until the Owner explicitly approves proceeding after this Gate 0
evidence review.

## 1. Nearest Focused-Test Baseline

The primary comparison remains the constructed six-command exact-state test in
[`test_candidate_obstacle_consequences.gd`](../../../tests/unit/test_candidate_obstacle_consequences.gd#L222),
supplemented by production-board actionability and save/install recovery in
[`test_bug_043_stabilization_projection_recovery.gd`](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L66).

| Field | Classification | Gate 0 baseline |
|---|---|---|
| S0 construction | Measured | Directly code-constructed with `_fixture()`: phase, binding, deck, ship, activation, maneuver execution, final transform and obstacle are assigned through state/domain APIs. It does not reach S0 through genuine gameplay. |
| Sequence | Measured | Six accepted semantic commands: order commitment, pre-effect acknowledgement, asteroid resolution, faceup acknowledgement, asteroid completion and maneuver completion. |
| Roundtrip/oracle | Measured | Commands are serialized through `GameReplay`, deserialized, replay-submitted against a second constructed state, then the complete serialized final states are compared. RNG is restored explicitly. |
| Setup complexity | Measured | The test body is 43 source lines (lines 222–264) and depends on shared construction helpers in the 1,156-line test file. The helper surface is reusable within that test script, not an external gameplay artifact. |
| Diagnostic specificity | Measured | Individual submission assertions and exact history-type equality localize a rejected command; final full-state equality detects convergence drift. It does not identify a canonical first-digest divergence. |
| Reuse outside test | Measured | No. The constructed specimen and helpers are embedded in the test script. |
| Baseline execution | Measured | `test_candidate_obstacle_consequences.gd`: 18/18 tests, 614 assertions, GUT 1.167 s, process wall time 4.01 s. |
| Board/recovery execution | Measured | `test_bug_043_stabilization_projection_recovery.gd`: 18/18 tests, 1,495 assertions, GUT 3.703 s, process wall time 6.97 s. Its obstacle-order case reconstructs an actionable production board without semantic submission, and its recovery matrix includes `obstacle_order`. |
| Rerun effort | Estimated | One existing single-file command per baseline file; no manual preparation. Interpretation is assertion/rejection-log driven. |
| Maintenance | Owner judgment pending comparison | Strong and local for rule assertions, but the state is synthetic and the sequence is not a reusable Owner-captured gameplay artifact. |

## 2. Existing Production Replay And Manual Evidence

The recorded Network replay is the closest existing production evidence. It is
a 267-command replay-11 fixture with five obstacle-order commitments, one
asteroid resolution, two debris resolutions and three station resolutions. It
contains complete order/acknowledgement/consequence chains, including a
multi-obstacle debris-to-station chain. The accepted audit identifies these as
recorded production commands and distinguishes them from the constructed
focused test. See the first chain in
[`replay_network.json`](../../../tests/fixtures/baseline_traces/replay_network.json#L304)
and the [audit assessment](GGS-001-b-lite-prototype-workbook-adversarial-audit.md#L68).

The current Hot-Seat replay is a genuine long-horizon baseline but contains no
`commit_maneuver_obstacle_order` command, so it is not a direct comparison for
this family. The earlier repository audit already verified its command trace
and final-state hash; Gate 0 did not redundantly rerun it. The repository replay
workflow records that fixture capture is manual and promotion is Owner-reviewed
([replay workflow](../../development/REPLAY_BASELINE_WORKFLOW.md#L139)). No
separate, scoped manual observation for the exact two-or-more-obstacle S0 was
found or claimed. Gate 1 must therefore prove the exact boundary rather than
treat adjacent replay evidence as sufficient.

## 3. Predeclared Measurement Fields And Economic Criteria

Every future value will be labelled **Measured**, **Estimated**, or **Owner
judgment**. Missing values remain unset; they are not converted into estimates.

### Gate cost ledger

Record for each gate: active and elapsed effort; Codex/credit usage when
available; files and lines added/removed/modified; review, rework and debugging;
focused and convergence verification effort; remaining forecast to the first
Candidate; and categorical Small/Medium/Large reassessment.

### Owner capture economics

Record preparation/reach time, metadata/start effort, active recording time,
stop/review/storage effort, attempts/cancellations/retries, every manual or
debug intervention, any state/JSON/history construction or repair, total Owner
active and elapsed time, and the Owner's lightweight-extension judgment.

### Artifact and execution

Record command count against the planned approximately 5–8 commands with a
working margin through 10; total artifact bytes and bytes for S0, commands and
metadata; duplicated authority versus references/provenance; fresh-process
success count; startup/reconstruction/command/total wall time where useful;
final digest stability; optional digest-log size; and naturally observed
non-semantic serialization sensitivity.

### Diagnostic comparison and break-even

For each path record first useful failure evidence, correct divergence/root-
cause class, time to the correct file/function and class, first-diagnosis
correctness, whether a fix is identified within the Owner cap, and setup/rerun/
interpretation effort. Compare measured prototype plus Owner recording plus
estimated maintenance/removal cost against the Owner-set plausible reuse range
times measured or estimated saving per use. Non-positive savings or failure to
amortize defaults to STOP. At least one workbook §1 advantage must be observed
and judged material by the Owner; equal pass/fail behavior alone is insufficient.

### Owner-set values recorded before Gate 1

| Decision | Classification | Recorded value |
|---|---|---|
| Maximum Owner preparation/recording effort | Owner judgment | Target at or below 10 minutes. Time spent simply playing to reach S0 is measured separately. More than 20 minutes requires Owner review before retrying or adding tooling. Manual artifact/state reconstruction remains negative evidence. |
| Maximum recording attempts/manual interventions | Owner judgment | Target: first usable Candidate in one attempt. Maximum: two attempts. A third attempt requires Owner review. Manual editing of JSON, command history, canonical state, IDs, RNG state or the resulting Candidate counts as a failed recording workflow. |
| Diagnostic comparison time cap | Owner judgment | Maximum 15 minutes per path under equivalent starting conditions. Stop when the production defect/root-cause class is localized sufficiently to identify the correct repair area. Failure is recorded as `>15 min / not localized`. |
| Break-even evaluation horizon | Owner judgment | Additional GGS creation and maintenance cost must plausibly break even within three relevant future uses. Gate 4 may estimate this from measured creation, maintenance, rerun and diagnostic effort. |
| Reliability | Fixed baseline | 10/10 fresh-process executions. Gate 0 found no better bounded repository criterion, so the workbook proposal is unchanged. |
| Package/scope cap | Owner approved | Medium, near its upper bound, through one boundary, one family and the first Candidate. If actual plus forecast effort crosses into Large before the genuine Owner-recorded Candidate, STOP and return to the Owner. |
| Required comparative benefit | Fixed plus Owner judgment | At least one workbook §1 advantage, judged material by the Owner. |

These decisions close the Gate 0 quantitative-threshold requirement. They do
not authorize Gate 1.

## 4. Controlled Disposable Defect Plan

The Owner approved this plan on 2026-10-07. No defect was introduced at Gate 0.

- **Seam:** the shared production admission check in
  [`CandidateCommitManeuverObstacleOrderCommand.validate()`](../../../src/core/commands/candidate_commit_maneuver_obstacle_order_command.gd#L26).
- **Disposable change:** on a dedicated disposable measurement branch/worktree,
  invert the `final_transform_applied` admission polarity so a valid
  post-transform obstacle-order command is rejected as stale/already committed.
  Make no other change.
- **Why both paths execute it:** the focused six-command test submits this
  production command first, and the planned genuine Candidate begins at the
  same boundary with the same normal command. The check precedes obstacle-count
  handling, so the focused test's one-obstacle specimen and the Candidate's
  required two-or-more-obstacle choice receive the same injected fault.
- **Predicted root-cause class:** obstacle-order command admission/validation;
  specifically, incorrect final-transform boundary polarity in
  `CandidateCommitManeuverObstacleOrderCommand.validate()`.
- **Predicted focused evidence:** first submission returns empty with
  `Obstacle order is stale or already committed`, failing the line-230
  submission assertion before later history/final-state checks.
- **Predicted GGS evidence:** command index 0, its recorded sequence/type/player,
  and the same immediate rejection reason; no command executes and no expected
  artifact data changes.
- **Fair comparison:** start both diagnoses with only the ordinary failing
  command identity, immediate output and the same Owner-set time cap. Record
  time to the correct file/function and root-cause class, first-diagnosis
  correctness and fix identification. Do not reveal the seam to the diagnosing
  run.
- **Safety:** apply only after a clean baseline on a disposable branch/worktree;
  never alter Candidate/focused expected data; revert immediately after Gate 4;
  rerun both clean paths and relevant convergence checks.

## 5. Removability Inventory

Expected prototype-only paths, unchanged from the accepted workbook:

| Planned path | Purpose | STOP disposition |
|---|---|---|
| `tests/experimental/ggs/test_maneuver_obstacle_order_s0_feasibility.gd` | Gate 1 proof | Delete unless Owner explicitly retains a generalized recovery test |
| `src/ui/debug/experimental_ggs/experimental_ggs_envelope.gd` | Strict envelope | Delete |
| `src/ui/debug/experimental_ggs/experimental_ggs_boundary.gd` | One boundary validator | Delete |
| `src/ui/debug/experimental_ggs/experimental_ggs_capture.gd` | Debug Start/Stop capture | Delete |
| `tests/experimental/ggs/experimental_ggs_runner.gd` | Fresh-process runner | Delete |
| `tests/experimental/ggs/test_experimental_ggs_envelope.gd` | Parser/specimen tests | Delete |
| `tests/experimental/ggs/test_experimental_ggs_runner.gd` | Runner/rejection tests | Delete |
| `tests/experimental/ggs/test_experimental_ggs_capture.gd` | Capture safety tests | Delete |
| `tests/fixtures/experimental_ggs/owner_candidates/<sample-id>.json` | First genuine Candidate | Delete on STOP unless Owner explicitly retains immutable historical evidence |

Only a minimal lazy Debug-mode hook in `src/autoload/debug_mode.gd` is expected
later. No autoload, production dependency, version change, gameplay file,
existing fixture, or repository-stored synthetic specimen is planned. Requiring
another production-file change beyond that small hook triggers reassessment
before editing.

## 6. Gate 0 Cost And Remaining Forecast

| Field | Classification | Result |
|---|---|---|
| Active/elapsed Gate 0 effort | Measured with limitation | One Codex execution session. Session-wide active and elapsed timers were not exposed; no precision is invented. Direct verification process wall time was 10.98 s. |
| Codex/credit usage | Unavailable | Not exposed to this execution; left unset. |
| Files/lines | Measured | One evidence file added: 200 lines (approximately 14.7 KB); no production, test, fixture or Candidate file changed. |
| Review/rework/debugging | Measured | No rework or debugging. Evidence review covered the accepted workbook, both primary comparison tests, the command validator, accepted audits and existing replay corpus. |
| Gate 0 size | Estimated | Small. |
| Remaining through first Candidate | Estimated and Owner approved | Gate 1 Small–Medium; Gate 2 Medium; Gate 3 small implementation plus measured Owner effort. Combined actual plus forecast is approved as Medium near its upper bound. There is no repository-defined numeric Medium unit, so no numeric remainder is invented. |
| Stop reassessment | Owner judgment | No evidence yet makes the package Large. Any Gate 1 need for new authority/parallel paths, or Gate 2 forecast that pushes the combined package to Large, stops the experiment. |

## 7. Gate 0 Verification And Verdict

Performed:

1. Confirmed a clean starting worktree and absence of the planned measurement file.
2. Inspected the two primary focused comparisons and shared production validator.
3. Counted the relevant recorded Network replay commands and confirmed the Hot-Seat replay has no obstacle-order commitment.
4. Ran the focused consequence file: 18/18 tests and 614 assertions passed.
5. Ran the production reconstruction/save-install file: 18/18 tests and 1,495 assertions passed.
6. Confirmed no GGS code/artifact/Candidate/fixture/directory or gameplay change was created.
7. Performed closing diff and whitespace checks after writing this evidence record.
8. After recording the Owner decisions on 2026-10-07, reran both focused files
   at the unchanged source revision: 18/18 tests and 614 assertions passed for
   the consequence file; 18/18 tests and 1,495 assertions passed for the
   production reconstruction/save-install file.

**Verdict: PASS — READY FOR OWNER REVIEW.** The comparison is fair, all required
quantitative thresholds are recorded, the controlled-defect plan and remaining
Medium budget are Owner-approved, and no stop condition was reached. Gate 1 was
not started and remains unauthorized pending explicit Owner approval.

## 8. Gate 1 Exact-Boundary Falsification

Gate 1 was authorized and executed on 2026-10-07 at the same source revision.
Only the workbook-planned feasibility test was added:
[`test_maneuver_obstacle_order_s0_feasibility.gd`](../../../tests/experimental/ggs/test_maneuver_obstacle_order_s0_feasibility.gd).
No GGS schema, parser, runner, recorder, Candidate, fixture, production state or
production path was added or changed.

### Boundary and passing evidence

The test installs a valid pre-maneuver full-authority Hot-Seat state at command
cursor 40. Two production obstacles are already placed at the ship's canonical
position. It submits the ordinary `execute_maneuver` command for a legal
speed-zero maneuver. The shared `CommandProcessor` executes sequence 40 and
derives `apply_maneuver_transform` at sequence 41, then stops naturally at the
two-obstacle player decision. No target decision fact is assigned after command
execution.

The following Gate 1 evidence passed:

- Ship phase and Ship Activation/Maneuver flow; one active ship activation and
  one matching open maneuver execution.
- Final transform applied, no collision/displacement/Damaged Controls priority,
  exactly two stable unresolved overlaps, no committed order, and no pending
  pre-effect, obstacle/immediate resolution, faceup inspection or asteroid
  completion.
- Evaluator decision identity, actor, activation/execution IDs, obstacle IDs,
  obstacle types, placement order and option order survived JSON parsing and
  `GameState.deserialize()`.
- Damage-deck order and RNG initial seed survived.
- Direct `GameManager.start_new_game_from_state()` restored the exact non-zero
  cursor 42 with empty history.
- Normal `GameBoard` reconstruction exposed the same two order permutations,
  submitted no semantic command and left cursor/history unchanged. No
  scene/process-owned gameplay dependency was found.
- The selected normal order command serialized, deserialized through
  `GameCommand.deserialize()`, validated, and was accepted through
  `CommandProcessor.submit_replay()` at sequence 42. History became one command
  and the cursor became 43.

### Hard falsification

The required exact RNG-current-state proof failed. Before JSON, the canonical
RNG state was the 64-bit integer `5975857563556095516`. Godot's JSON parser
returned that field as a floating-point value; after `GameState.deserialize()`
the restored RNG state was `5975857563556096000`. The feasibility test therefore
failed its exact equality assertion while all other assertions passed.

This is not a GGS test-fixture problem. Satisfying the workbook would require a
production canonical serialization/deserialization change (for example, a
lossless representation for the 64-bit RNG state) and corresponding assessment
of save/replay/network compatibility. Gate 1 does not authorize that repair,
and introducing a GGS-only representation would violate the workbook. The
implementation stopped without attempting either change.

### Gate 1 cost and forecast

| Field | Classification | Result |
|---|---|---|
| Active/elapsed effort | Measured with limitation | One Codex Gate 1 execution session; session-wide timers and credit usage were unavailable. |
| Files/lines | Measured | One planned feasibility test added, 331 lines / approximately 12.5 KB. No production or fixture file changed. |
| Review/rework/debugging | Measured | Narrow trace of the production maneuver continuation and board reconstruction seams; one initial test execution and one assertion-message/type clarification after the falsification surfaced. |
| Focused verification | Measured | The dedicated Gate 1 file executed 98 assertions in 0.723 s: 97 passed and only the exact RNG-current-state equality assertion failed. |
| Gate 1 size | Estimated | Small actual effort. |
| Remaining forecast | Estimated | Gate 2 and Gate 3 are paused. The previously approved Medium forecast cannot absorb an unapproved production canonical-state/compatibility repair. Scope and package size must be reassessed by the Owner before any continuation. |

### Gate 1 verdict

**STOP RECOMMENDED.** The maneuver obstacle-order decision itself is
production-reconstructible and actionable, and the first command replays
successfully, but the workbook requires exact current RNG preservation through
JSON. That hard requirement is falsified by the existing production
serialization seam. Gate 2 is not authorized.

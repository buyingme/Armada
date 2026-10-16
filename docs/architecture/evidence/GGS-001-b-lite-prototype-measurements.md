# GGS-001 B-Lite Prototype Measurements

Status: **Gate 1 Owner accepted; Gate 2 authorized, then stopped at final-digest falsification — Owner review required**

Evidence date: 2026-10-06

Owner decisions recorded: 2026-10-07

Gate 0 Owner-accepted: 2026-10-07

Source revision: `39d12ff3ee93cacb3f4faa0d0ca48fcaa7a69633`

Gate 1 reassessment: 2026-10-15 at revision
`5bb9c510cba9e341e84df97004653481b42d7948`

Gate 1 Owner acceptance and Gate 2 authorization: 2026-10-15

This is the measurement record authorized by
[the accepted GGS-001 implementation workbook](../implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md).
Gate 0 created no GGS code, artifact, Candidate, fixture, or directory and made
no gameplay change. The Owner-set values are recorded below. The original Gate
1 failure and stop recommendation remain preserved in §8; §9 records the later
reassessment. §10 records the subsequently authorized Gate 2 attempt and stop.

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

## 9. Gate 1 Evidence Reconciliation — 2026-10-15

### Resolution of the historical failure

The §8 failure was an exact production JSON serialization defect, not a failed
maneuver boundary. The separately Owner-accepted
[exact authoritative RNG repair workbook](../implementation_workbooks/exact-authoritative-rng-save-serialization-repair-implementation-workbook.md#L1)
required canonical decimal strings for both authoritative RNG fields. Its
[Owner stop-gate resolution](../implementation_workbooks/exact-authoritative-rng-save-serialization-repair-implementation-workbook.md#L485)
authorized only a test assertion correction from the obsolete numeric JSON
shape to that representation, while retaining exact value equality. Current
`GameRng.serialize()` emits decimal strings and `GameRng.deserialize()` checks
and restores their exact signed-int64 values
([implementation](../../../src/core/state/game_rng.gd#L71)). The original
`5975857563556095516` to `5975857563556096000` loss remains the historical
observed failure; it is not reclassified as a passing result.

The unchanged substantive Gate 1 feasibility test was run in a fresh headless
Godot process at the reassessment revision. Result: **1/1 test passed, 101/101
assertions, GUT 0.742 s, process wall time 3.98 s**. The prior §8 result was
97/98 assertions; the current test includes the Owner-authorized string-shape
assertions as well as exact restored seed and current-state equality. This is
one feasibility run, not the later Gate 3 requirement of 10/10 Candidate runs.

### Exact boundary and proof reconciliation

The passing test covers every accepted workbook §6.2 boundary condition and
§6.3 proof step
([workbook](../implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md#L231),
[test](../../../tests/experimental/ggs/test_maneuver_obstacle_order_s0_feasibility.gd#L62)):

| Required proof | Current passing evidence |
|---|---|
| Reach the one allowlisted decision through production authority; capture its cursor | A full-authority Hot-Seat state submits ordinary `execute_maneuver` at 40; the normal processor derives `apply_maneuver_transform` at 41 and stops at the two-obstacle order choice. The in-memory S0 cursor is 42. Target decision facts are not assigned after execution. |
| Match the canonical boundary | Ship Activation/Maneuver flow, one active activation and matching maneuver execution, final transform, two stable unresolved overlaps, exact actor and obstacle options, and absence of higher-priority or pending consequence obligations are asserted before and after reconstruction. |
| Preserve S0 through JSON and production deserialization | `GameState.serialize()` → `JSON.stringify()` → `JSON.parse_string()` → `GameState.deserialize()` retains activation/execution and obstacle identities/options, damage-deck order, and exact RNG seed and current state. Both RNG fields remain canonical decimal strings across JSON. |
| Restore live state and decision without invented gameplay | Direct `GameManager.start_new_game_from_state()` restores cursor 42 with empty history. The evaluator's canonical decision signature matches before and after roundtrip and after installation. |
| Reconstruct actionable production UI without committing | Normal `GameBoard` reconstruction presents both order permutations to the owner; it submits no semantic command and leaves cursor/history unchanged. |
| Replay the first normal choice | The selected command is serialized, JSON-parsed, deserialized through `GameCommand.deserialize()`, validated, and accepted by `CommandProcessor.submit_replay()` at 42. History has exactly that command and the cursor advances to 43. |

No §6.4 hard-falsification condition is observed. The proof uses the existing
production state, board, installer, command and replay submission seams. The
separate RNG repair was not introduced as GGS-only state or a parallel path.
This remains a constructed feasibility specimen, not genuine Owner gameplay,
a GGS Candidate, or proof of economic value.

### Actual-plus-forecast Medium reassessment

| Field | Classification | Reassessed result |
|---|---|---|
| Gate 0 and original Gate 1 | Measured / historical estimate | Gate 0 completed as Small evidence work; §8 records one planned 331-line feasibility test, one execution and a narrow clarification, assessed Small at the time. No GGS schema, runner, recorder or Candidate was built. |
| Separate RNG repair | Scope classification | Cross-cutting production repair authorized and verified under its own workbook, with its own save/replay/Network and baseline obligations. Its cost is real project cost, but it is not additional prototype machinery or an unapproved expansion of the GGS Medium package. No numerical effort or credit usage is inferred here. |
| Gate 1 reassessment | Measured with limitation | One focused proof rerun, source/workbook comparison and this evidence reconciliation; process wall time 3.98 s. Session-wide active/elapsed engineering time and credit usage are unavailable. No production, test, fixture or Candidate edit is part of this reassessment. |
| Remaining through first Candidate | Estimated | The accepted Gate 2 one-family removable slice remains Medium; Gate 3 adds small implementation and measured Owner recording effort. With Gate 0, Gate 1 and this reconciliation, actual plus forecast remains **Medium near its upper bound** on current evidence, without an invented numeric remainder. Reassess at the Gate 2 checkpoint and stop before expansion if the forecast becomes Large. |

The Gate 0 Owner thresholds remain unchanged: one boundary/family/Candidate and
Medium package cap; target at most 10 minutes Owner preparation/recording
(more than 20 minutes requires review), at most two attempts, 15 minutes per
diagnostic path, break-even within three relevant uses, and 10/10 fresh-process
Candidate executions. None of the capture, reliability, diagnosis or break-even
thresholds can be evaluated from Gate 1 alone.

### Gate 1 checkpoint and recommendation

**GO to the Owner checkpoint; do not start Gate 2 automatically.** The exact
technical feasibility proof now passes and the current actual-plus-forecast
assessment does not establish a Large GGS package. No further Gate 1 technical
acceptance gap is identified. Remaining risks are unmeasured Owner capture
effort, Candidate reliability, marginal diagnostic value against the nearest
focused test, and whether later work can stay within Medium. Those belong to
the later workbook gates rather than a new Gate 1 mechanism.

The precise pending decision is for the Project Owner to review this repaired
Gate 1 proof and Gate 0–1 actual-plus-forecast cost, then **explicitly authorize
or reject Gate 2's isolated, single-family minimal vertical slice** under the
accepted Medium cap. A passing test, the separate RNG repair, BUG-074 closure,
and this recommendation do not supply that authorization. The first genuine
Owner Candidate and any further gate each require their own later checkpoint.

## 10. Authorized Gate 2 Attempt And Stop — 2026-10-15

The Project Owner accepted the repaired Gate 1 proof and authorized only the
bounded Gate 2 B-lite vertical slice. That authorization did not include a
production canonical-state repair, a different final-digest contract, or the
first Owner Candidate. Work began from revision
`5bb9c510cba9e341e84df97004653481b42d7948` with no Candidate or fixture
created or changed.

### Observed final-digest falsification

A tagged `synthetic_test_specimen` exercised the one allowlisted maneuver
obstacle-order S0 boundary. The attempted strict runner installed JSON-rebuilt
S0 through `GameManager.start_new_game_from_state()`, rechecked the canonical
decision, deserialized the first normal order command, and successfully
submitted it through `CommandProcessor.submit_replay()` at cursor 42. History
and cursor advanced as expected. The final canonical digest nevertheless
disagreed with the same command executed from the original live S0.

The first directly observed state difference was
`interaction_flow.payload.ship_index`: the live final state serialized integer
`0`, while the JSON-reconstructed/replayed final state serialized floating
`0.0`. Godot parses the JSON number as a float; for Ship Activation/Maneuver,
[`InteractionFlow.deserialize()`](../../../src/core/state/interaction_flow.gd#L92)
duplicates the payload without restoring that field's integer type. The order
command does not rewrite the field. `CanonicalJson.hash()` therefore hashes
different canonical JSON. This is a concrete representation divergence, not a
rejected maneuver command or RNG loss. Other differences were not exhaustively
classified after the first sufficient falsification.

The accepted [prototype workbook](../implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md#L388)
requires the expected digest of the genuine live final `GameState.serialize()`
and direct production reconstruction. A GGS-only normalization of S0 or final
state, or hashing a rewritten expected state, would create a parallel canonical
representation and obscure this failure. A production deserialization repair
would touch the authoritative save/replay/Network representation outside Gate
2's permitted files and requires separate authority and verification. No such
change was made.

### Verification and cost ledger

| Field | Classification | Gate 2 attempt result |
|---|---|---|
| Prototype work | Measured | One Codex implementation session constructed three isolated experimental source files, a thin runner plus startup wrapper, three machinery-test files, and a small lazy DebugMode hook. Approximately 940 experimental lines were attempted before STOP; all Gate 2 code and the hook were then removed. Only this evidence record remains changed. |
| Focused machinery verification | Measured | Strict envelope tests: 2/2 passed, 15 assertions. Capture safety tests: 2/2 passed, 8 assertions. Synthetic runner tests: 0/3 passed, 36/42 assertions; the valid in-process and fresh-process runs both reached accepted first-command execution but failed the final digest. The rejection-path test also needed an expected-warning assertion and did not pass. These were temporary machinery specimens, never Candidate evidence. |
| Effort and rework | Measured with limitation | One session included implementation, a startup-order adjustment for the Godot CLI, a temporary-path correction for the write probe, diagnostic comparison, and STOP cleanup. Session-wide active/elapsed engineering timers and Codex/credit usage were unavailable; no precise total is invented. Individual focused runs took approximately 2.6–4.8 s process wall time. |
| Actual plus forecast | Estimated | Gate 0–1 remained Medium near its upper bound before this attempt. Gate 2 now needs an unapproved cross-cutting canonical-state decision/repair and renewed verification before a trustworthy first Candidate. The remaining work cannot be certified within the Owner-approved Medium cap on present evidence. No Gate 3 recording estimate or benefit claim is substituted for the missing repair decision. |

**Gate 2 verdict: STOP and return to the Owner.** The attempted vertical slice
is not ready for its recording checkpoint. The exact unresolved decision is
whether to authorize a separate bounded production normalization of the Ship
Activation/Maneuver payload (with save/replay/Network and digest impact
assessed), revise the accepted GGS final-digest design, or stop the experiment.
Codex cannot select one of those materially different representation contracts
under Gate 2 authority. If the Owner chooses a continuation, the complete
actual-plus-forecast Medium package must be reassessed before work resumes.

The planned STOP cleanup was applied: no GGS envelope, runner, recorder, Debug
hook, Candidate directory/file, synthetic fixture, new autoload, or changed
replay/save/Network version remains. The accepted Gate 1 test and historical
measurement evidence are retained. After cleanup, the focused Gate 1 proof
passed again: 1/1 test, 101 assertions. The separate Owner checkpoint before
any genuine recording remains mandatory.

# GGS-001: Limited B-Lite Prototype Implementation Workbook

Status: Draft

Purpose: Implementation workbook for an experimental Golden Gameplay Sample
(GGS) B-lite prototype

Implementation status: Not started

Implementation authorization: None. This Draft must be reviewed and accepted by
the Project Owner before implementation begins.

Decision input: Project Owner direction recorded on 2026-10-06. That direction
authorizes preparation of this Draft and fixes the prototype policy listed in
§2. It does not mark this workbook Owner-accepted.

Primary evidence:

- [GGS-001 decision workbook](../decision_workbooks/GGS-001-golden-gameplay-ui-assurance-decision-workbook.md)
- [GGS-001 adversarial repository audit](../evidence/GGS-001-adversarial-repository-audit.md)

## 1. Purpose And Hypothesis

This workbook defines the smallest implementation experiment that can test the
repository audit's recommendation to proceed with a limited GGS B-lite
prototype. It is not a permanent GGS architecture, an ADR, a fixture catalogue,
or an assurance-governance change.

The prototype tests this hypothesis:

> For selected high-risk, multi-command gameplay compositions, a genuine
> Owner-recorded serialized canonical state, its command cursor, a short stream
> of normal authoritative commands, and a canonical result oracle reduce total
> regression-verification, manual-QA, and diagnosis/convergence cost enough to
> justify maintaining the artifact in addition to focused tests.

The prototype must demonstrate that value against Armada's existing focused
tests and full replay. It must not assume that a new fixture is valuable merely
because it can be executed.

The repository already proves much of the technical mechanism. A focused replay
test reconstructs serialized state, executes real commands, and obtains exact
final state and RNG equality
([test_replay_driver.gd](../../../tests/unit/test_replay_driver.gd#L20)). The
audit therefore recommends generalizing that capability rather than building a
new gameplay engine
([audit §2](../evidence/GGS-001-adversarial-repository-audit.md#L95)).

## 2. Fixed Owner Decisions

The following decisions are inputs to this Draft and are not reopened here:

1. Proceed with a limited GGS B-lite prototype.
2. Initial S0 support is limited to explicitly whitelisted decision boundaries.
3. Accepted GGS authority belongs only to the Project Owner. Codex may create or
   record a Candidate only when explicitly instructed. Codex must never
   establish, regenerate, replace, or silently update accepted expected
   gameplay behavior.
4. A bounded UIC bootstrap/reconciliation pilot will proceed separately.
5. UIP may proceed separately only as a narrow semantic-pattern catalogue, not
   as a generic UI component framework.
6. Historical coverage/backfill is risk-based and opportunistic.
7. GGS, UIC, UIP, and UIF are not Definition-of-Done requirements. Permanent
   governance may be reconsidered only after measured prototype value.

The Owner has deliberately deferred:

- the pre-board Setup authority model; and
- the eventual full-replay start boundary.

Those deferred decisions do not block this prototype. They must not be inferred
or resolved by implementation.

## 3. Authority And Interpretation

Repository document authority remains governed by
[DOCUMENT_AUTHORITY.md](../DOCUMENT_AUTHORITY.md). The accepted architecture and
contracts continue to own gameplay authority, deterministic command behavior,
reconstruction, RNG, and UI/controller boundaries.

This workbook is planning authority only after Owner acceptance. It does not:

- change gameplay rules;
- make an experimental GGS sample authoritative;
- elevate current implementation into normative architecture;
- authorize accepted fixture creation or regeneration;
- change any accepted ADR, Contract, capability package, or TEST document; or
- resolve any deferred Setup decision.

Where this workbook names an implementation seam, the accepted authority and
the behavior of the normal command path remain controlling. If implementation
would require alternate gameplay semantics, a general continuation engine, a
new Setup authority, or a second canonical state model, implementation stops.

## 4. Prototype Scope

### 4.1 Included

The prototype includes exactly:

1. one experimental, strictly parsed, versioned GGS envelope;
2. one serialized full-authority canonical S0;
3. one initial authoritative command cursor;
4. one short, contiguous, ordered stream of normal serialized authoritative
   commands;
5. strict headless execution through `GameCommand.deserialize()` and the
   existing `CommandProcessor.submit_replay()` path;
6. immediate failure on artifact parsing, S0 reconstruction, boundary
   validation, cursor restoration, command deserialization, command validation,
   or command rejection;
7. one expected final canonical digest;
8. mechanically derived, non-semantic diagnostic hashes sufficient to identify
   the first differing command and useful final-state structural paths;
9. the two initial S0 boundary allowlist entries in §9;
10. proof that each allowed S0 reconstructs into an actionable,
    decision-equivalent production state;
11. minimal Debug-only Start/Stop capture support for two genuine,
    Owner-recorded experimental Candidate samples;
12. execution of one explicitly named sample;
13. family/all filtering only if the conditional rule in §12.5 is satisfied;
14. focused verification and one bounded convergence pass; and
15. the measurement record and post-prototype Owner decision gate in §17.

The first implementation is full-authority Hot-Seat only. Network result
transport and passive filtered state are existing comparison evidence, not GGS
artifact inputs. The commands still execute through the same replay-mode
authority path used by production reconstruction.

### 4.2 Explicitly Out Of Scope

The following are prohibited in this workbook:

- permanent GGS architecture or governance;
- broad or arbitrary-S0 support;
- general scenario construction or a GGS state DSL;
- a full Debug sample browser;
- pause/step UI;
- extensive accepted intermediate checkpoints;
- broad GGS catalogue or lifecycle tooling;
- automatic generation or regeneration of accepted samples;
- exhaustive historical GGS backfill;
- UIC or UIP implementation;
- UIF;
- screenshot or visual regression testing;
- Setup authority changes;
- Setup Review repair;
- Setup speed-preview repair;
- pre-board Setup replay;
- full-match replay redesign;
- Definition-of-Done changes;
- a new command protocol;
- a parallel gameplay executor;
- transport-result replay; and
- any gameplay-rule change introduced merely to make a sample pass.

The separate UIC/UIP experiment tests a different maintenance and traceability
hypothesis. It must not be absorbed into this implementation task.

## 5. Repository Evidence And Reuse Boundary

### 5.1 Observed Reusable Infrastructure

| Concern | Existing evidence | Prototype posture |
|---|---|---|
| Canonical S0 | `GameState.serialize()` includes flow, timing, current attack, inspections, deck, binding, players and RNG ([game_state.gd](../../../src/core/state/game_state.gd#L1044)) | Reuse unchanged |
| Reconstruction | `GameState.deserialize()` reconstructs and validates canonical references and lifecycles ([game_state.gd](../../../src/core/state/game_state.gd#L1169)) | Reuse unchanged |
| Live-install validation | Full-authority validation requires RNG, deck, binding and lifecycle invariants ([game_state.gd](../../../src/core/state/game_state.gd#L452)) | Reuse; never weaken |
| State installation | `start_new_game_from_state()` validates, reconciles timing, restores the cursor, and publishes normal game start ([game_manager.gd](../../../src/autoload/game_manager.gd#L445)) | Reuse semantics; isolate headless side effects |
| RNG | `GameRng` serializes both initial seed and current state ([game_rng.gd](../../../src/core/state/game_rng.gd#L60)) | Reuse inside S0 and final digest |
| Command registry | Startup registers normal attack and maneuver consequence commands ([command_processor.gd](../../../src/autoload/command_processor.gd#L98)) | Reuse unchanged |
| Command execution | `_submit()` performs sequence, semantic-schema, preflight, command validation, execution and recording ([command_processor.gd](../../../src/autoload/command_processor.gd#L379)) | Reuse unchanged |
| Replay submission | `submit_replay()` preserves recorded sequence and enters the common submission path ([command_processor.gd](../../../src/autoload/command_processor.gd#L246)) | Required runner path |
| Cursor | `get_next_sequence()` and `restore_next_sequence()` expose the sole cursor ([command_processor.gd](../../../src/autoload/command_processor.gd#L743)) | Reuse unchanged |
| History | `serialize_history()` returns normal serialized authoritative commands ([command_processor.gd](../../../src/autoload/command_processor.gd#L779)) | Slice from the capture start index |
| Timing recovery | Timing reconstruction validates current-attack source, stage and controller identity ([timing_window_orchestrator.gd](../../../src/core/timing_windows/timing_window_orchestrator.gd#L534)) | Reuse unchanged |
| Maneuver recovery | `ManeuverExecutionEvaluator.next_action()` derives the next legal action without storing a second workflow ([maneuver_execution_evaluator.gd](../../../src/core/movement/maneuver_execution_evaluator.gd#L15)) | Reuse as boundary proof |
| Canonical hash | `CanonicalJson` performs sorted-key JSON and SHA-256 hashing ([canonical_json.gd](../../../src/utils/canonical_json.gd#L9)) | Reuse unchanged |
| Debug capture precedent | Debug annotation already serializes live state, and replay saving already exposes a bounded debug affordance ([debug_mode.gd](../../../src/autoload/debug_mode.gd#L55), [debug_mode.gd](../../../src/autoload/debug_mode.gd#L117)) | Reuse interaction style, not whole-session replay schema |

### 5.2 Existing Mechanisms That Must Not Be Reused Wholesale

1. `GameReplay` is a full-session scenario/bootstrap artifact. Its Version 11
   header does not carry arbitrary S0 even though it carries cursor metadata
   ([game_replay.gd](../../../src/core/commands/game_replay.gd#L31),
   [game_replay.gd](../../../src/core/commands/game_replay.gd#L63)).
2. `CommandProcessor.create_replay()` correctly rejects a non-zero history
   start without a paired initial state
   ([command_processor.gd](../../../src/autoload/command_processor.gd#L787)).
   The GGS envelope supplies that missing pair; it must not weaken normal replay.
3. `ReplayDriver` assumes scenario bootstrap and normally logs rejection rather
   than failing at the first rejected command
   ([replay_driver.gd](../../../src/autoload/replay_driver.gd#L114),
   [replay_driver.gd](../../../src/autoload/replay_driver.gd#L504)).
4. `CommandProcessor.replay_commands()` skips an unknown command and continues
   ([command_processor.gd](../../../src/autoload/command_processor.gd#L826)).
   The GGS runner must instead fail immediately and identify the command.
5. Save-game safe-point policy is a product policy, not the GGS S0 policy. An S0
   is permitted only by the allowlist and proof obligations in §9.
6. `BaselineTrace` provides useful hash precedent, but its existing record is
   not the new envelope or diagnostic schema. The audit found its per-command
   information too coarse for GGS first-divergence diagnosis
   ([audit §2](../evidence/GGS-001-adversarial-repository-audit.md#L68)).

### 5.3 New Prototype Seams

Only these new seams are justified:

- a strict experimental GGS envelope parser/serializer;
- an explicit two-entry boundary allowlist and family-specific validators;
- a dedicated strict headless runner that delegates gameplay to existing
  reconstruction and command paths;
- a generic mechanical diagnostic-digest helper;
- a bounded capture session held by Debug mode; and
- focused tests and a measurement record.

No new gameplay command, rule, RNG, recovery model, state DSL, or canonical
state type is justified.

## 6. Experimental Artifact Contract

### 6.1 Identity And Version Namespace

The root object must contain:

```text
artifact_kind: "armada_golden_gameplay_sample"
ggs_format_version: 1
```

The GGS format requires its own namespace because its semantic identity is
different from both a full `GameReplay` and a save file. It pairs arbitrary
whitelisted S0 with a cursor and a short command suffix, while `GameReplay`
Version 11 reconstructs from scenario/bootstrap data.

Creating `ggs_format_version = 1` does not require a cutover of:

- `GameReplay.FORMAT_VERSION`, currently 11
  ([game_replay.gd](../../../src/core/commands/game_replay.gd#L31));
- `SaveGameMetadata.CURRENT_VERSION`, currently 9
  ([save_game_metadata.gd](../../../src/core/state/save_game_metadata.gd#L37));
  or
- the app version, currently `0.1.0`
  ([project.godot](../../../project.godot#L15)).

None of those versions may be incremented merely because a separate
experimental artifact is introduced. If implementation changes an existing
serialized contract, it has escaped this workbook and must stop for the normal
compatibility decision.

### 6.2 Required Fields

The strict Version 1 envelope contains only:

```text
artifact_kind
ggs_format_version
sample
compatibility
initial_state
initial_command_sequence
commands
expected_final_digest
diagnostics
```

`sample` contains:

```text
sample_id
title
status
capability_family
s0_boundary_id
related_authority
recorded_at_utc
recording_method
```

`compatibility` records the app, save, and replay format versions observed at
capture time. Those values are compatibility evidence; they do not turn the GGS
into a save or `GameReplay` artifact.

`initial_state` is exactly one `GameState.serialize()` dictionary.
`initial_command_sequence` is an exact non-negative JSON integer. `commands` is
a non-empty, short array of canonical serialized `GameCommand` dictionaries
whose sequences are contiguous from that cursor.

`expected_final_digest` is `CanonicalJson.hash(final_state.serialize())`.

The Version 1 parser rejects:

- an unknown artifact kind or version;
- missing or unknown root fields;
- wrong JSON types;
- fractional or negative integer identity/cursor values;
- an empty command stream;
- more than 12 commands;
- unknown or noncanonical commands;
- noncontiguous command sequences;
- any status other than `Candidate`, or an unknown capability family or S0
  boundary;
- malformed SHA-256 digests;
- incompatible diagnostic list lengths; and
- any full-authority S0 that cannot be reconstructed and validated.

Twelve commands is a prototype guardrail, not a permanent GGS rule. Raising it
requires measurement evidence and Owner review rather than silent relaxation.

### 6.3 Candidate Status And Owner Authority

Minimal status metadata is necessary to prevent experimental output from being
mistaken for accepted behavior. It is not a lifecycle-management system.

- Capture can write only `Candidate`.
- The experimental Version 1 parser accepts only `Candidate`. It does not
  implement `Valid` or `Superseded` states.
- A Candidate may be executed only when the caller names it explicitly and the
  runner reports its Candidate status prominently.
- No implementation command may promote, regenerate, supersede, or overwrite a
  sample.
- If the Owner later accepts or supersedes a sample, representation of that act
  requires a separately reviewed follow-up; it is not inferred by this parser.
- A string claiming that the Owner accepted an artifact would not prove Owner
  authority. Acceptance remains a human review/version-control act.
- Codex may capture or record a Candidate only when the Owner explicitly asks it
  to do so and the Owner manually performs or validates the gameplay.

The capture path uses a create-new-file operation and fails if the target sample
ID already exists. It never updates a sample in place.

## 7. Diagnostics Without A Second Expected-State Model

### 7.1 Normative Oracle

The only normative gameplay-result oracle in Version 1 is
`expected_final_digest`. The serialized S0 and normal commands are inputs, not a
second rule description. The prototype stores no expected final `GameState`, no
hand-authored semantic result object, and no duplicate command effects.

### 7.2 Diagnostic-Only Data

`diagnostics` may contain only mechanically derived hashes:

1. `post_command_digests`: one full canonical state digest after each accepted
   command in the captured stream; and
2. `final_structure_digests`: generic canonical hashes for container paths in
   the final serialized `GameState`, produced recursively by one schema-agnostic
   helper with a bounded depth/entry limit.

These hashes are generated from genuine captured execution. They are not
manually curated checkpoints and are not independent expected gameplay state.
They have two diagnostic purposes:

- report the earliest command after which actual state differs from capture;
- report the smallest available final canonical container paths whose hashes
  differ, including `rng` when it is the first differing path.

The runner's pass/fail result remains the final digest. A diagnostic-only
intermediate mismatch is reported even if later commands converge, but it does
not silently become an additional accepted semantic contract.

The diagnostic report must include:

- sample ID and status;
- S0 boundary ID;
- command index, sequence, type and player;
- parse/reconstruction/validation/rejection reason, when applicable;
- expected and actual final digest;
- first differing post-command digest index, when available; and
- a bounded list of differing structural paths, never a dump of sensitive or
  enormous state values.

The measurement gate must count artifact size and hash churn. If the diagnostic
data creates material duplicate maintenance burden, it is reduced or removed;
the project must not preserve it merely because it is technically possible.

## 8. Strict Headless Runner

### 8.1 Required Sequence

For one explicitly named artifact, the runner must:

1. read JSON and apply the exact Version 1 schema;
2. require `Candidate` status plus an explicit Candidate-execution flag, and
   print that status prominently;
3. reconstruct S0 with `GameState.deserialize()`;
4. assert canonical roundtrip equality by hashing the input S0 and the
   reconstructed `serialize()` output;
5. run `validate_for_live_installation()` and timing reconciliation;
6. evaluate the allowlisted boundary validator and its decision-equivalence
   signature;
7. install state using `GameManager.start_new_game_from_state()` semantics with
   the recorded cursor;
8. confirm the command history is empty and the cursor equals
   `initial_command_sequence`;
9. deserialize one command at a time with `GameCommand.deserialize()`;
10. submit each through `CommandProcessor.submit_replay()`; never call a
    concrete command's `execute()` directly;
11. fail immediately if deserialization, sequence admission, preflight,
    validation, or execution rejects;
12. compute actual post-command digests for diagnostics;
13. compare the final canonical digest; and
14. emit one concise machine-readable result plus a human-readable failure.

The runner must restore any singleton/autoload state it changes when used inside
a test process. The standalone headless process must exit nonzero on any failure.

### 8.2 Forbidden Shortcuts

The runner must not:

- bypass `CommandProcessor`;
- assign command results directly;
- load transport result envelopes as authoritative outcomes;
- reconstruct through the full scenario-coupled `ReplayDriver`;
- continue after a malformed/rejected command;
- repair an invalid S0;
- infer a missing command;
- skip an unknown command;
- update an expected digest; or
- write to any sample artifact.

ADR-012 requires deterministic command re-execution rather than replaying
transport outcomes
([ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md#L174)).

## 9. Initial S0 Boundary Allowlist

The Version 1 allowlist contains exactly two IDs. No fallback such as "any state
that passes live-install validation" is permitted.

### 9.1 `attack_modify_cf_resource_choice_v1`

This boundary is immediately after a ship attack's dice roll has opened the
canonical `ATTACK_MODIFY` timing window and before the player commits the
Concentrate Fire resource choice.

The validator must prove all of the following:

- full-authority Hot-Seat state with valid RNG, deck and principal binding;
- Ship or Squadron phase as permitted by the current attack, with a live
  standard ship attack;
- `CurrentAttackState.stage == ATTACK_MODIFY`;
- active `TimingWindowState` is the production Attack Modify lifecycle;
- timing lifecycle source, controller and attack identity agree;
- the attacker has the captured Concentrate Fire resources;
- `UIProjector`/timing opportunity derivation exposes the same blocking
  Concentrate Fire resource choice, actor, lifecycle identity and command type
  before and after roundtrip;
- no completed-attack or faceup-damage inspection owns the next input;
- no transient die hover/selection or panel-local preview is required; and
- the first recorded command is a legal Concentrate Fire choice command for the
  derived actor/lifecycle.

Existing production evidence reconstructs the committed dial choice into an
actionable board and preserves state, RNG, history and cursor on stale-command
rejection
([test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd#L1466)).
Save/load evidence also restores the cursor before resuming Attack Modify
([test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd#L2661)).

### 9.2 `maneuver_obstacle_pre_effect_ack_v1`

This boundary is after an accepted maneuver transform and committed obstacle
resolution order have opened a canonical obstacle pre-effect acknowledgement,
but before any required principal has acknowledged that occurrence.

The validator must prove all of the following:

- full-authority Hot-Seat state with valid RNG, deck and principal binding;
- one live ship activation and one active maneuver execution with stable
  activation/execution identities;
- the final maneuver transform is already committed;
- obstacle order is canonical and the current obstacle is unresolved;
- exactly one pending obstacle pre-effect occurrence owns the next player input;
- its required/received principal sets, occurrence ID, obstacle ID and maneuver
  identity are valid;
- `ManeuverExecutionEvaluator.next_action()` returns the same acknowledgement
  command type, payload identity and acting principal before and after
  roundtrip;
- normal board reconstruction presents the same actionable acknowledgement and
  submits no semantic work during reconstruction;
- no maneuver-tool drag, ruler preview, displacement drag, or modal-local
  selection is required; and
- the first recorded command acknowledges the derived occurrence.

Production-composition evidence already proves live and reconstructed maneuver
decisions are equivalent and reconstruction submits no semantic command
([test_bug_043_stabilization_projection_recovery.gd](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L66)).
Existing focused replay evidence executes obstacle ordering, acknowledgement,
asteroid resolution, faceup acknowledgement, completion and maneuver completion
and reaches exact final serialized state
([test_candidate_obstacle_consequences.gd](../../../tests/unit/test_candidate_obstacle_consequences.gd#L222)).

### 9.3 Boundary Proof Is Required, Not Assumed

For each allowlist entry, acceptance requires three independent proofs:

1. **Canonical proof:** deserialize, reserialize, validate, reconcile, preserve
   cursor and preserve exact canonical/RNG digest.
2. **Decision proof:** the family-specific authoritative evaluator/projector
   returns the same actor, decision identity, command type and identity-bearing
   payload before and after reconstruction.
3. **Production-resume proof:** normal board composition reconstructs the same
   actionable control for the entitled player, a passive/non-entitled view is
   non-actionable where applicable, and reconstruction itself submits no
   semantic command.

Passing `validate_for_live_installation()` alone is insufficient. The audit
found that Armada still has scene/process state and therefore arbitrary S0 is
unproven
([audit §2](../evidence/GGS-001-adversarial-repository-audit.md#L95)).

If either family fails any proof, remove that boundary from the prototype. Do
not broaden the validator or copy presentation state into S0 to make it pass.

### 9.4 Explicit Rejections

The allowlist rejects at least:

- pre-board Setup and all unresolved Setup authority states;
- board Setup for this prototype;
- uncommitted maneuver or deployment previews;
- active ruler, drag, hover, die-selection, or panel-local choice state;
- passive filtered Network state;
- result-transport envelopes;
- current-attack states outside the exact CF choice boundary;
- maneuver consequences outside the exact pre-effect acknowledgement boundary;
- terminal or inconsistent inspection lifecycles;
- states with a missing/invalid RNG, deck or principal binding; and
- states whose next authoritative action cannot be re-derived uniquely.

## 10. Experimental Capability Families And Samples

### 10.1 Sample A — Concentrate Fire Attack-Modify Composition

The Owner plays a genuine attack to the post-roll Concentrate Fire resource
choice and starts capture at `attack_modify_cf_resource_choice_v1`. The short
captured suffix should include a meaningful multi-command branch such as:

- choose both dial and token;
- choose and roll the dial-added die;
- use or decline the token reroll based on the genuine Owner decision; and
- reach the next stable canonical attack decision or continuation within the
  12-command limit.

The workbook does not prescribe the dice, target, outcome, payload IDs, or final
digest. Those arise only from Owner gameplay.

This family is representative because it crosses:

- a canonical current attack;
- a shared timing lifecycle and projected opportunities;
- multiple normal commands;
- RNG consumption;
- resource ownership and use/decline semantics;
- recovery into actionable production UI; and
- a capability that also appears in the 546-command full replay
  ([replay_hot_seat_solo.json](../../../tests/fixtures/baseline_traces/replay_hot_seat_solo.json#L2500)).

It therefore tests whether a short GGS localizes failures more cheaply than both
the nearest focused integration tests and full-match replay.

### 10.2 Sample B — Maneuver Obstacle Consequence Recovery

The Owner performs a genuine maneuver that reaches an obstacle pre-effect
acknowledgement and starts capture at
`maneuver_obstacle_pre_effect_ack_v1`. Prefer an asteroid consequence that
exercises the genuine damage deck/RNG and recovery chain. The suffix may include:

- obstacle pre-effect acknowledgement;
- authoritative obstacle resolution;
- faceup-damage acknowledgement when genuinely produced;
- any genuinely opened immediate resolution;
- obstacle completion; and
- return to the next stable maneuver/activation decision within the command
  limit.

The workbook does not prescribe which damage card is drawn or synthesize a
particular consequence.

This family is materially different from Sample A. It exercises maneuver
identity, purpose-specific recovery, acknowledgement gates, obstacle authority,
damage/deck state, possible RNG, and return to ship activation. Existing code
derives these transitions through `ManeuverExecutionEvaluator`, not through the
attack timing-window path
([maneuver_execution_evaluator.gd](../../../src/core/movement/maneuver_execution_evaluator.gd#L31)).

### 10.3 Why Easier Examples Are Rejected

A single calculation or one-command mutation would be easier to capture but
would not test the value hypothesis. Existing unit and command tests already
diagnose those cases well. The audit concludes that GGS has highest marginal
value for multi-command interactions, recovery paths and capability composition
([audit §2](../evidence/GGS-001-adversarial-repository-audit.md#L97)).

## 11. Minimal Bounded Capture

### 11.1 Entry And Exit

Capture is available only in editor/debug mode and only while Debug mode is
enabled. It adds one small Start/Stop affordance following the existing debug
shortcut/toast style. `Shift+G` is the proposed binding because the current
Debug-mode switch handles `Ctrl+S`, `Shift+A`, and `Shift+R`
([debug_mode.gd](../../../src/autoload/debug_mode.gd#L55)); implementation must
still check the complete input map before assigning it.

Start must:

1. require a new sample ID, title and one of the two capability families;
2. evaluate the live state against the two allowlist validators;
3. require exactly one matching boundary;
4. run the full canonical and decision proof;
5. store S0, cursor, history index and the initial RNG digest in memory;
6. begin listening only to successfully executed authoritative commands; and
7. show a visible `Candidate capture active` indication.

Stop must:

1. require the same live match/session and an active capture;
2. slice the normal serialized command history from the start index;
3. require contiguous sequences beginning at the captured cursor;
4. require 1–12 accepted commands and no observed rejection;
5. verify the observed per-command digest count matches the command slice;
6. compute final digest and bounded diagnostic hashes;
7. present a summary to the Owner; and
8. create one new `Candidate` artifact only after explicit confirmation.

Cancel discards only in-memory capture data. It does not undo gameplay.

### 11.2 Capture Safety

Capture must fail closed if:

- the state is not allowlisted;
- canonical roundtrip or actionability proof fails;
- history/cursor changes between validation and start;
- a command rejects;
- the process changes match/session;
- the command count exceeds 12;
- the target file exists; or
- writing or read-back parsing fails.

The capture service observes commands; it does not submit, edit, reorder, infer,
or repair them. It must read back its new file through the strict parser and
compare its S0, commands and expected digest before reporting success.

### 11.3 Provenance Rule

The Owner must manually perform or validate all gameplay in each experimental
sample. Debug commands are permitted only when they are already accepted
authoritative/canonical mechanisms and the Owner explicitly chooses them; they
must be recorded in provenance. Synthetic state builders and hand-authored
command histories are prohibited for Candidate creation.

Codex may assist with the capture only after an explicit Owner instruction for
that Candidate. Codex may not choose the gameplay, regenerate a failing sample,
or replace an expected digest to satisfy a test.

## 12. Implementation Slices And Stop Points

### 12.1 Slice 0 — Technical Baseline And Measurement Harness

Objective: record the current comparison baselines before adding GGS code.

Required outputs:

- focused execution time and diagnostic shape for the nearest test in each
  family;
- hot-seat full replay time and diagnostic shape for Sample A's capability;
- current artifact sizes and current commands exercised;
- a measurement record template containing every §16 field; and
- confirmation that the existing focused tests and hot-seat replay pass.

Stop if either selected family's existing evidence already provides the same
Owner provenance, execution locality and failure localization at lower total
cost; record that evidence for the gate rather than forcing implementation.

### 12.2 Slice 1 — Envelope, Parser And Diagnostic Hashes

Objective: implement only the Version 1 data contract and pure diagnostic hash
helper.

Likely change surfaces:

- one new RefCounted GGS artifact/parser near the existing replay artifact;
- one schema-agnostic diagnostic hash helper; and
- unit tests for exact parsing, canonicalization and diagnostics.

Checkpoint:

- all malformed/unknown/incompatible inputs fail closed;
- normal `GameReplay` and save parsing remain unchanged; and
- no gameplay state is installed or command executed by this slice.

### 12.3 Slice 2 — S0 Allowlist And Boundary Proofs

Objective: implement exactly the two validators in §9.

The implementation should compose existing `GameState`, timing projection,
`UIProjector`, and `ManeuverExecutionEvaluator` results. It must not reproduce
their rules in a GGS-specific decision engine.

Checkpoint:

- both allowed boundary families pass all three proof layers;
- representative neighboring states are rejected;
- production reconstruction is decision-equivalent; and
- no sample or fixture exists yet.

This is the first mandatory stop/go gate. If safe reconstruction cannot be
demonstrated without copying scene state or adding family-specific gameplay
semantics, outcome A (STOP) is available before capture work.

### 12.4 Slice 3 — Strict One-Sample Headless Runner

Objective: execute an in-memory test artifact, then one explicitly named file,
through the strict sequence in §8.

Checkpoint:

- cursor, command path, RNG, rejection behavior, digest and diagnostics pass
  focused tests;
- negative tests mutate only in-memory test data and never rewrite a fixture;
- existing save/replay behavior remains unchanged; and
- no Owner sample has yet been requested.

### 12.5 Slice 4 — Optional Cheap Selection Surface

The required interface is one explicit sample path. Add `--family` and/or
`--all` only if all of the following are true:

- implementation is a pure directory enumeration plus already-parsed metadata;
- no registry, catalogue, discovery database, lifecycle service or new CI job is
  needed;
- the change is Small;
- individual-sample diagnostics are unchanged; and
- it does not delay capture or measurement.

Otherwise defer both filters. Even if added, `--all` is not a Definition-of-Done
or CI requirement during the prototype.

### 12.6 Slice 5 — Minimal Capture

Objective: implement §11 only after the Slice 2 and 3 gates pass.

Likely change surfaces:

- one bounded capture-session helper;
- the existing `DebugMode` shortcut/toast integration;
- a minimal metadata/confirmation surface; and
- focused capture tests using disposable temporary paths.

Checkpoint:

- capture can write only create-new Candidate artifacts;
- capture cannot run outside the allowlist;
- no accepted or existing file can be overwritten; and
- no fixture is created during automated tests.

### 12.7 Slice 6 — Owner-Recorded Candidates

This slice requires explicit Owner participation and a fresh instruction for
each Candidate.

1. Owner reaches and validates Sample A's genuine gameplay boundary.
2. Capture writes a new Sample A Candidate.
3. Owner reaches and validates Sample B's genuine gameplay boundary.
4. Capture writes a new Sample B Candidate.
5. Each new file is reviewed as Candidate and run individually.

Implementation may not manufacture a missing family by calling a test fixture
builder. If genuine gameplay cannot reach a stable allowlisted boundary at
reasonable cost, that is negative prototype evidence.

### 12.8 Slice 7 — Measurement And Owner Gate

Objective: collect §16 evidence, perform the bounded maintenance exercise, and
present outcomes A/B/C without presuming C.

No permanent ADR, catalogue, bulk fixture set, CI mandate, or governance change
may begin before the Owner selects a gate outcome.

## 13. Verification Matrix

| Concern | Focused verification |
|---|---|
| Strict parsing | Exact root/nested fields and types; unknown kind/version/field; missing field; malformed digest; fractional/negative cursor; empty/oversized commands; noncanonical command; noncontiguous sequence |
| S0 roundtrip | Parse JSON, deserialize S0, reserialize, compare canonical hash and required full-authority identities |
| S0 reconstruction | `validate_for_live_installation`, timing reconciliation, empty history, exact restored cursor |
| Command cursor | Zero and non-zero allowed cursors; first command equals cursor; gap/duplicate/stale sequence rejects immediately |
| Authoritative execution | Every command passes `GameCommand.deserialize` and `CommandProcessor.submit_replay`; direct `execute()` is prohibited in runner tests |
| RNG preservation | Initial RNG seed/state survives roundtrip; non-RNG branch does not advance it; RNG-consuming branch reaches captured state; final digest includes RNG |
| Immediate rejection | In-memory bad command/payload/lifecycle causes nonzero exit at that index and no later command executes |
| Rejection atomicity | State, RNG, history and cursor remain unchanged after the rejected command, following existing production expectations ([test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd#L1499)) |
| Final digest | Exact pass; mismatch fails with expected/actual digest |
| First divergence | In-memory diagnostic mutation reports earliest differing post-command index/type/sequence |
| Structural diagnosis | Final mismatch identifies bounded differing canonical paths and identifies `rng` separately when applicable |
| Allowed boundary A | All §9.1 predicates plus production-board decision equivalence |
| Allowed boundary B | All §9.2 predicates plus production-board decision equivalence |
| Rejected boundaries | Neighboring attack/maneuver stages, transient previews, Setup, passive state, missing identities/RNG/deck/binding |
| Capture | Start/stop/cancel, history slice, same-session guard, rejection abort, max command guard, create-new only, read-back validation |
| Provenance | Capture emits Candidate only; no promotion/regeneration/update API; runner visibly reports Candidate |
| Existing replay | Current Version 11 parser/driver tests remain unchanged and passing |
| Existing save/load | Current Version 9 save/load and cursor/reconstruction tests remain passing |

### 13.1 Nearest Focused Comparisons

Sample A must be compared with:

- `test_real_cf_dial_history_round_trips_json_factory_and_driver`
  ([test_replay_driver.gd](../../../tests/unit/test_replay_driver.gd#L20)); and
- the production committed-dial and partially resolved recovery tests
  ([test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd#L1466)).

Sample B must be compared with:

- `test_nonfixture_replay_preserves_obstacle_faceup_and_f1_order`
  ([test_candidate_obstacle_consequences.gd](../../../tests/unit/test_candidate_obstacle_consequences.gd#L222)); and
- live/reconstructed maneuver decision equivalence
  ([test_bug_043_stabilization_projection_recovery.gd](../../../tests/integration/test_bug_043_stabilization_projection_recovery.gd#L66)).

The comparison asks what GGS adds, not whether it can repeat the same assertions.

### 13.2 Broader Convergence

Run broader convergence once after the integrated prototype, not after every
slice:

1. all new GGS-focused unit/integration tests;
2. the existing replay-driver tests;
3. the relevant current-attack production-resume tests;
4. the relevant maneuver stabilization/obstacle consequence tests;
5. focused save/load and cursor restoration tests;
6. the hot-seat baseline replay; and
7. the repository's full canonical test suite once before the Owner gate.

Network replay/resume convergence is conditional. It is required only if
implementation changes shared command submission, timing/recovery behavior,
network filtering, result envelopes, or existing replay code. The intended
prototype should call those seams without modifying them.

## 14. Compatibility And Regression Posture

The GGS parser is strict-current-version only. No migration framework is part of
the prototype. A future incompatible GGS change would create a new
`ggs_format_version` only after an explicit compatibility decision.

The captured compatibility block allows the runner to explain likely mismatch,
but it must not silently migrate S0, commands or expected hashes. If current
`GameState` cannot read a Version 1 sample after an intentional accepted
serialization change, the Owner decides whether to:

- retain it only as historical evidence;
- manually replay and validate a new Candidate;
- explicitly accept a migration; or
- stop maintaining GGS.

The implementation must not bump or change save, replay, app, network, or
command versions speculatively. Existing replay/save fixtures remain governed
by their existing policies and scripts.

## 15. Work Packages And Effort

| Work package | Estimate | Dominant cost/risk |
|---|---:|---|
| WP0 baseline and measurement template | Small | Comparable timing and diagnostic observations |
| WP1 Version 1 envelope and strict parser | Small–Medium | Exact schema, JSON integer handling, compatibility reporting |
| WP2 generic digest diagnostics | Medium | Useful paths without storing another expected state model |
| WP3 two-entry S0 allowlist | Medium–Large | Proving actionability rather than only serializability |
| WP4 strict one-sample headless runner | Medium | Autoload isolation, immediate rejection, continuation/cursor behavior |
| WP5 optional family/all filters | Small or deferred | Avoiding catalogue/registry scope |
| WP6 bounded Debug Start/Stop capture | Medium | Command/digest observation, same-session guard, create-new safety |
| WP7 Owner recording of two Candidates | Small implementation; variable Owner time | Naturally reaching stable, representative states |
| WP8 focused and broader convergence | Medium | Shared autoload/reconstruction regression risk |
| WP9 maintenance exercise and decision evidence | Medium elapsed effort | Requires a genuine Owner-accepted behavior-change context |

Overall estimate: **Large** for the full two-family prototype through the Owner
gate, composed of bounded work packages. The dominant risk is safe,
decision-equivalent S0 reconstruction. Command serialization, RNG persistence
and canonical hashing are not the dominant implementation costs because those
mechanisms already exist.

This estimate excludes all out-of-scope permanent governance, Setup, UIC/UIP,
UIF, broad catalogue and browser work.

## 16. Measurement Plan

Measurements are recorded per sample and in aggregate. Raw values must be kept;
do not replace them with only a subjective verdict.

### 16.1 Owner Recording Effort

Record separately:

- time to reach the S0 naturally;
- time to enter metadata and start capture;
- time from Start to Stop;
- review/read-back time;
- number and reason for cancelled or repeated attempts;
- any debug assistance used;
- any manual artifact editing, which should be zero; and
- total Owner elapsed and active effort.

An unusually difficult-to-reach boundary counts against GGS even if execution is
fast.

### 16.2 Execution Cost

For each Candidate, record:

- command count and artifact byte size;
- runner startup, reconstruction, command execution and total wall time;
- ten fresh-process runs and their success rate;
- median and slowest total time; and
- diagnostic-hash time/size overhead.

Run the nearest focused test under the same environment. For Sample A, also run
the hot-seat full replay under the same environment because that replay contains
Concentrate Fire commands. Full replay is not an equivalent Sample B oracle, so
record it as not applicable unless the current full fixture genuinely exercises
the selected obstacle chain.

### 16.3 Diagnostic Localization Quality

Use disposable in-memory negative variants, never modified Candidate files:

1. one command rejection at a known index;
2. one post-command state/digest divergence; and
3. one malformed S0/boundary mismatch.

Record:

- whether the first runner invocation identifies the correct failure class;
- whether it names command index, sequence, type, player and reason;
- whether structural paths narrow the affected canonical subsystem;
- time for a maintainer/Codex to identify the nearest responsible source and
  focused test; and
- the equivalent effort using the nearest focused test and full replay where
  applicable.

### 16.4 Reconstruction Reliability

Each sample must:

- pass 10/10 fresh-process runs;
- preserve S0 roundtrip digest and initial RNG state every time;
- derive the same decision signature on every reconstruction;
- execute from the recorded non-zero cursor where applicable; and
- produce the same final digest every time.

Any intermittent reconstruction/actionability failure is a prototype failure,
not a reason to add retries.

### 16.5 Intentional Behavior-Change Maintenance Exercise

The prototype must measure one intentional, explicitly Owner-accepted behavior
change affecting a pilot family. Prefer a real accepted change that occurs
during the evaluation period.

If none occurs, the Owner may explicitly authorize a disposable evaluation
branch with one narrowly described intended change. The Owner must exercise and
validate the changed gameplay and record a new Candidate; Codex must not
regenerate the old artifact. The disposable branch and Candidate must not be
presented as accepted production behavior unless separately approved.

Record:

- time to understand the old sample failure;
- focused-test maintenance time;
- Owner time to replay and validate the new behavior;
- time to create and review a replacement Candidate;
- lines/bytes changed in diagnostic metadata versus genuine gameplay inputs;
- whether old and new provenance remain clear; and
- whether any manual expected-state editing was required.

If the Owner does not authorize a real or controlled change, the final gate must
record this criterion as unresolved; it cannot be silently marked passed.

### 16.6 Duplicate-Specification Burden

For each sample, classify every maintained artifact field as:

- genuine captured input;
- mechanically derived diagnostic data;
- provenance/reference metadata; or
- duplicated semantic expectation.

The last category should be empty. Measure artifact churn after the intentional
change and compare it with the focused test. If maintaining per-command or
structural hashes causes large unrelated churn, count that against the
prototype and remove those diagnostics before considering permanent design.

## 17. Post-Prototype Owner Decision Gate

Before this gate, the evidence package must contain:

- technical proof results for both allowlisted boundaries;
- two genuine Owner-recorded Candidate reports, or an explicit failure to
  record one;
- all §16 measurements;
- nearest-focused-test comparisons;
- Sample A full-replay comparison;
- the intentional-change maintenance result or an explicit unresolved entry;
- replay/save regression evidence; and
- documented artifact size/churn and duplicate-burden assessment.

The Project Owner chooses exactly one outcome.

### Outcome A — STOP

Choose STOP if any of the following is true:

- an allowlisted boundary cannot be made reliably decision-equivalent without
  copying scene/process state or creating alternate gameplay semantics;
- fresh-process reconstruction is not deterministic;
- Owner capture effort is disproportionate to the saved verification effort;
- diagnostics do not materially improve on focused tests;
- maintenance requires silent regeneration or manual expected-state editing;
- duplicate artifact churn is material; or
- neither family demonstrates net value over existing focused tests.

STOP means remove or quarantine experimental tooling as directed by the Owner;
it does not weaken existing focused tests or full replay.

### Outcome B — NARROW

Choose NARROW if the runner is reliable and at least one family demonstrates
clear value, but value is confined to selected high-risk compositions or the
other family is too costly. Retain only explicitly approved families/samples and
keep adoption opportunistic. Do not create general governance or DoD mandates.

### Outcome C — PROCEED

Choose PROCEED only if:

- both boundary families reconstruct reliably;
- short samples are materially faster or more local than full replay where
  applicable;
- diagnostics materially improve localization over the nearest focused tests;
- Owner recording and intentional-change maintenance are acceptable;
- no second semantic expected-state model is required; and
- measured total maintenance burden supports further investment.

PROCEED authorizes design of permanent GGS architecture/governance only after a
separate Owner decision. It does not itself accept Version 1 as permanent,
promote Candidates, mandate GGS in Definition of Done, or authorize broad
backfill.

No numeric score automatically selects C. The evidence must be presented with
negative and unresolved results visible.

## 18. Risks And Mandatory Stops

| Risk | Control / stop condition |
|---|---|
| Synthetic sample history | Owner performs/validates gameplay; capture only observes normal history |
| Arbitrary S0 becomes de facto supported | Exact two-ID allowlist; no fallback validator |
| Candidate mistaken for accepted behavior | Candidate-only capture, explicit runner warning, Owner-only promotion outside tooling |
| Silent expected update | Create-new only; no overwrite/regenerate command |
| Alternate gameplay path | Runner delegates to `GameState` and `CommandProcessor.submit_replay()` |
| Scene state copied into S0 | Fail boundary proof and stop that family |
| Diagnostic hashes become second specification | Mechanical hashes only; measure churn; final digest remains normative |
| Full replay/save regression | No existing version cutover; focused regression plus bounded convergence |
| Capture UI grows into browser/tooling | One Start/Stop affordance and minimal metadata only |
| Setup scope leaks into prototype | Reject all Setup S0; keep deferred work separate |
| UIC/UIP scope leaks into prototype | References only; no catalogue implementation |
| Controlled change is mistaken for accepted behavior | Requires explicit Owner instruction, disposable branch labeling and separate acceptance |

Implementation stops and returns to the Owner if:

- either validator needs an unresolved authority decision;
- exact replay-mode semantics cannot execute a captured normal command stream;
- a required production recovery path depends on unserialized state;
- compatibility requires changing an existing version/contract;
- capture cannot guarantee create-new-only behavior;
- a proposed fix changes gameplay rules; or
- the prototype cannot collect the required measurements without expanding into
  a permanent framework.

## 19. Completion Criteria For This Workbook's Prototype

The implementation experiment is complete only when:

1. Slices 0–5 pass their checkpoints.
2. Both allowlisted boundaries have canonical, decision and production-resume
   proof, or one has failed and that failure is recorded.
3. The Owner has explicitly instructed and manually performed/validated each
   Candidate recording attempted.
4. At least one named Candidate executes successfully through the strict
   headless runner.
5. Every verification concern in §13 has a recorded result.
6. Every measurement in §16 has a value or an explicit unresolved reason.
7. Existing replay/save behavior has no regression.
8. No accepted sample has been synthesized, regenerated, replaced or silently
   updated.
9. No UIC/UIP/UIF/Setup/DoD work has been absorbed.
10. The Owner has selected A, B or C.

Passing the technical tests does not by itself prove the cost-saving hypothesis.
The Owner gate is part of completion.

## 20. Remaining Owner Actions And Deferred Decisions

Before implementation:

- review and accept, revise, or reject this Draft, including the two exact S0
  allowlist entries and the 12-command prototype guardrail.

During the experiment:

- explicitly instruct each Candidate capture;
- manually perform or validate the gameplay;
- identify/accept the behavior change used for the maintenance exercise, or
  record that criterion as unresolved; and
- select STOP, NARROW, or PROCEED from the evidence.

Still deliberately deferred and not blockers for this prototype:

- pre-board Setup authority; and
- eventual full-replay start boundary.

No other architecture Owner decision is presently required. If implementation
reveals one, it must stop rather than silently resolve it.

## 21. Recommended Next Task After Workbook Acceptance

If the Owner accepts this workbook, the next task should implement **Slices 0–3
only**: baseline measurements, Version 1 parser/diagnostics, the two boundary
proofs, and the strict one-sample runner. It must stop at the Slice 3 gate before
adding capture or creating any Candidate.

Only after that technical gate passes should a separate explicitly authorized
task add minimal capture and schedule the two Owner gameplay sessions.

The UIC/UIP reconciliation pilot and Setup context/evidence work remain separate
tasks. No ADR or permanent GGS governance artifact should be created until the
post-prototype Owner gate selects PROCEED.

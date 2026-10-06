## 1. Executive verdict

**PASS WITH REQUIRED REFINEMENTS.**

The B-lite concept is architecturally sound: serialized authoritative S0, an exact cursor, ordinary commands, deterministic replay-mode execution, and a canonical final oracle all align with accepted ownership and recovery architecture. `GameState` already serializes the necessary aggregate, `CommandProcessor.submit_replay()` uses the normal validation/execution path, and replay is required to re-execute semantic commands rather than persisted outcomes. [GameState serialization](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:1044), [replay submission](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:246), [ADR-012](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md:174).

The Draft itself is not ready for Owner acceptance. It is not yet the smallest experiment, one S0 contract is not supported by the cited evidence, the initial slice ordering spends substantially before the first useful falsification gate, and the measurement plan cannot objectively establish economic value as written.

## 2. Blocking findings

These block acceptance of the current Draft, not the underlying prototype concept.

1. **`maneuver_obstacle_pre_effect_ack_v1` cannot satisfy its stated decision signature.** The Draft requires `ManeuverExecutionEvaluator.next_action()` to return an acting principal, but the evaluator returns only an acknowledgement kind, command type, occurrence payload, and record. The controller later chooses a player index from process-local `local_viewer` and canonical principal membership. [Draft requirement](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:478), [evaluator result](/Users/Katharina/godot/Armada/src/core/movement/maneuver_execution_evaluator.gd:31), [controller mapping](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1174). The signature must be redefined around canonical required/received principal sets, or the boundary must change.

2. **The claimed maneuver production-resume evidence does not cover the chosen boundary.** The cited decision-equivalence test covers obstacle order, debris, station, and immediate-effect choices—not pre-effect acknowledgement. The save/reconnect cases likewise omit pre-effect acknowledgement. [Decision cases](/Users/Katharina/godot/Armada/tests/integration/test_bug_043_stabilization_projection_recovery.gd:66), [recovery cases](/Users/Katharina/godot/Armada/tests/integration/test_bug_043_stabilization_projection_recovery.gd:145). The obstacle replay test begins from a constructed `_fixture`, not a genuine production-reached S0. [Constructed replay](/Users/Katharina/godot/Armada/tests/unit/test_candidate_obstacle_consequences.gd:222), [fixture construction](/Users/Katharina/godot/Armada/tests/unit/test_candidate_obstacle_consequences.gd:823).

3. **The slice order spends on generalized tooling before retiring the highest-risk assumption.** Strict format/parser and generic structural diagnostics precede boundary proof, even though the Draft itself says decision-equivalent S0 is the dominant Medium–Large risk. [Slices 1–2](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:679), [effort table](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:863). This is economically inverted.

4. **Slice 3 conflicts with Candidate authority.** It calls for executing “one explicitly named file” before any Owner sample has been requested, while the parser accepts only `Candidate` and the Draft prohibits Candidate creation except from explicitly authorized Owner gameplay. [Slice 3](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:715), [Candidate policy](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:309), [Owner capture occurs later](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:761). No repository-stored or transient synthetic object should masquerade as a Candidate.

## 3. Required refinements

### Experiment and runner architecture

- Put exact boundary proof before the envelope/parser and generic diagnostics.
- Require the runner to call `GameManager.start_new_game_from_state()` directly in a fresh process. “Reuse semantics” must not become a cloned installer; that method owns validation, reconciliation, cursor restoration, singleton reset, and normal game-start publication. [Installation path](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:459).
- Keep a dedicated thin runner; reusing `ReplayDriver` wholesale would inherit scenario bootstrap and non-fatal rejection behavior. [ReplayDriver bootstrap](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd:114), [rejection logging](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd:504).
- Delegate every command to `GameCommand.deserialize()` and `submit_replay()`. The common submission path already performs sequence, schema, preflight, validation, execution, recording, and continuation handling. [Submission path](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:379).
- Defer the generic recursive structural-hash tree. It is mechanically generated, but it is still a second opaque representation of expected final-state structure and is estimated as a Medium work package. Initial proof needs a final digest, immediate rejection details, and—if localization must be tested—only per-command digests. [Diagnostic proposal](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:331), [WP2](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:869).
- Make experimental removal concrete: one test/debug namespace, no new production autoload, an enumerated file list, and a deletion/quarantine checkpoint if STOP. The current “remove or quarantine as directed” is insufficiently specific. [STOP posture](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:1023).

### Scope control

Defer until a first sample demonstrates value:

- generic structural diagnostics;
- family/all discovery;
- compatibility migration policy beyond strict rejection/advisory reporting;
- a second family;
- the intentional-change exercise;
- any catalogue, browser, CI mandate, or permanent lifecycle/governance.

Those are permanent GGS architecture or recorder/catalogue concerns, not prerequisites for initial falsification. The original decision workbook itself placed the minimal capture/execution vertical slice before checkpoints and advanced diagnostics. [Minimal Stage 3](/Users/Katharina/godot/Armada/docs/architecture/decision_workbooks/GGS-001-golden-gameplay-ui-assurance-decision-workbook.md:802), [diagnostics Stage 4](/Users/Katharina/godot/Armada/docs/architecture/decision_workbooks/GGS-001-golden-gameplay-ui-assurance-decision-workbook.md:817).

UIC, UIP, UIF, Setup, full replay redesign, and permanent governance are correctly excluded. [Draft exclusions](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:129).

Essential omissions are:

- a non-Candidate policy for all synthetic parser/test specimens;
- predeclared economic thresholds;
- measured implementation/tooling cost;
- an explicit removability inventory;
- exact storage/naming boundaries separating experimental Candidates from ordinary test fixtures.

## 4. Optional improvements

- Treat Concentrate Fire as a **positive control**, not the main falsifier.
- Run each sample in a fresh process instead of restoring many autoloads inside one test process.
- Keep `--family` and `--all` deferred; the Draft already makes them conditional. [Conditional filters](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:728).
- Make app/save/replay compatibility values advisory. They are proxies, not the contracts directly consumed by the sample.
- Prefer the earlier maneuver obstacle-order decision boundary if the exact acknowledgement proof is not immediately available.

## 5. Assessment of each selected capability family

| Family | Assessment | Verdict |
|---|---|---|
| Post-roll Concentrate Fire | It crosses current attack, timing opportunity derivation, resources, multiple commands, RNG, and actionable UI. It is nevertheless strongly biased toward success: there are extensive real-board menu cases, exact open-choice recovery, committed-dial recovery, a short JSON/replay roundtrip test, and multiple full replay occurrences. [UI matrix](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:1067), [exact open-choice recovery](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:1361), [short replay test](/Users/Katharina/godot/Armada/tests/unit/test_replay_driver.gd:20), [full replay occurrence](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_hot_seat_solo.json:2478). It tests substrate feasibility well but offers weak marginal economic evidence because the nearest focused tests are already excellent. | **Retain only as a positive control or second sample. Do not let it dominate the GO decision.** |
| Maneuver obstacle recovery | It is materially different: activation/execution identities, canonical overlap ordering, acknowledgement gates, deck state, purpose-specific consequences, and return to activation. This is the stronger falsification family. However, its exact selected boundary lacks focused production-resume proof. Existing six-command exact-state replay is constructed, while recorded production reach is visible primarily in the Network replay. [Six-command chain](/Users/Katharina/godot/Armada/tests/unit/test_candidate_obstacle_consequences.gd:222), [recorded production commands](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_network.json:304). | **Use first, but only after narrowing or proving its S0 boundary.** |

The families are sufficiently different. No third family is currently justified more cheaply. The stronger cheaper falsification is to run the maneuver family first and use its already-tested **obstacle-order decision** boundary: existing real-board reconstruction and save/install evidence explicitly cover that state. [Obstacle-order projection](/Users/Katharina/godot/Armada/tests/integration/test_bug_043_stabilization_projection_recovery.gd:66), [save/install case](/Users/Katharina/godot/Armada/tests/integration/test_bug_043_stabilization_projection_recovery.gd:145).

One correction: an ordinary asteroid draw primarily exercises serialized deck order, not post-S0 RNG. `draw_card()` only advances RNG if the draw pile is empty and the discard pile must be reshuffled. [DamageDeck draw](/Users/Katharina/godot/Armada/src/core/damage/damage_deck.gd:86). Concentrate Fire remains the clearer RNG-consuming family.

## 6. Assessment of each S0 boundary

### `attack_modify_cf_resource_choice_v1`

**Canonical conditions**

The allowlist should require:

- full-authority Hot-Seat state;
- **Ship phase**, not “Ship or Squadron phase”;
- an active standard ship attack with an active ship activation and attack step;
- non-empty rolled dice and `ATTACK_MODIFY` stage;
- an active, `OPEN` Attack Modify timing lifecycle whose source, controller, lifecycle ID, and attack ID agree;
- `InteractionFlow == ATTACK/ATTACK_MODIFY`;
- `cf_choice == pending`, dial/token sub-resolutions unavailable, at least one genuine dial/token choice, and CF not already resolved this round;
- no completed-attack or faceup-damage inspection;
- a first command whose actor, lifecycle, source, attack, activation, round, and resource choice all match the derived intent.

These conditions follow the CF source and command validators. [CF pending source](/Users/Katharina/godot/Armada/src/core/effects/rules/concentrate_fire_choice.gd:140), [choice validation](/Users/Katharina/godot/Armada/src/core/commands/choose_concentrate_fire_command.gd:24), [attack-state invariants](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:381).

**Assessment**

- Production can reach it: rolling dice creates Attack Modify state and makes the choice pending when a ship has a CF dial or token. [Roll transition](/Users/Katharina/godot/Armada/src/core/commands/roll_dice_command.gd:113).
- Serialization contains current attack, timing lifecycle, flow, ship resources, binding, deck, and RNG. [GameState fields](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:1044).
- The transient resource submenu is not authoritative; the exact recovery test deliberately discards it and reconstructs the same actionable “Concentrate Fire” opportunity. [Recovery behavior](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:1380). This is consistent with ADR-010’s disposable presentation boundary. [ADR-010](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md:129).
- RNG is sufficient because both initial seed and current state are serialized. [GameRng](/Users/Katharina/godot/Armada/src/core/state/game_rng.gd:70).
- The timing lifecycle identity is serialized, and the external cursor can be restored exactly. [Timing serialization](/Users/Katharina/godot/Armada/src/core/state/timing_window_state.gd:152), [cursor](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:753).

**Verdict:** conditionally allowlistable, but the Draft cites adjacent committed-dial and generic cursor tests instead of the stronger exact open-choice test. Add one focused proof that starts from a production-reached exact S0, JSON-roundtrips it, installs the recorded non-zero cursor, derives the identical intent, submits the captured first command through replay mode, and confirms no command was synthesized during reconstruction.

### `maneuver_obstacle_pre_effect_ack_v1`

**Canonical conditions**

Require:

- full-authority Hot-Seat, Ship phase, Ship Activation/Maneuver flow;
- exactly one active ship activation and matching open maneuver execution;
- final transform committed;
- immutable canonical obstacle order with the current obstacle still unresolved;
- exactly one pre-effect record, with empty received principals;
- occurrence, activation, execution, ordinal, obstacle, obstacle type, effect, and required-principal identities all valid;
- no asteroid completion outstanding, faceup inspection, active obstacle/immediate resolution, or other higher-priority continuation;
- the evaluator returns the matching acknowledgement occurrence;
- the presentation layer maps an entitled local viewer to a player index without creating gameplay authority;
- the first command validates against the same occurrence and principal.

The record itself is thoroughly serialized and validated. [Pre-effect creation](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:788), [record validation](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:1816), [ship serialization](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:2095).

**Assessment**

- Production reach is credible: the recorded Network replay contains order commitment followed by pre-effect acknowledgements and consequence resolution. [Network sequence](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_network.json:304).
- GameState contains the necessary authoritative activation, execution, obstacle, binding, deck, and RNG information.
- UI state is not required for legality, but `local_viewer` is required to choose an actionable player index. That is acceptable presentation behavior, provided the boundary signature compares canonical principal entitlement rather than demanding that the evaluator return an actor it does not return. [Controller projection](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1162).
- Command identity is stable: the command contains the occurrence ID, and command validation maps its player index to a canonical principal. [Acknowledgement validation](/Users/Katharina/godot/Armada/src/core/commands/acknowledge_obstacle_pre_effect_command.gd:27).
- Existing tests do not prove exact Hot-Seat JSON roundtrip, cursor preservation, board reconstruction, entitled-view mapping, non-entitled behavior, and first-command replay from this precise state.

**Verdict:** **reject as presently allowlisted**. Keep it as a candidate pending an exact focused proof. If rapid risk retirement is preferred, replace it with `maneuver_obstacle_order_choice_v1`, which already has focused real-board and save/install reconstruction evidence.

## 7. Verdict on the 12-command guardrail

**Change it: remove 12 from the artifact-format contract and derive the capture budget from each approved sample plan.**

The limit is arbitrary. The demonstrated ordinary asteroid chain is six commands, including completion. [Exact command list](/Users/Katharina/godot/Armada/tests/unit/test_candidate_obstacle_consequences.gd:240). The shown Hot-Seat CF branch is only choice, dial use, and continuation commands around the selected boundary. [CF replay](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_hot_seat_solo.json:2486). Nothing derives 12 from either sample.

A fixed parser limit also hides useful negative evidence: if genuine gameplay needs more commands to reach a stable endpoint, that counts against GGS economics. Use:

- a per-capture planned command budget plus a small explicit margin;
- a separate implementation resource ceiling to reject pathological files;
- recorded actual command count as a measurement.

Do not make a convenience ceiling part of permanent GGS compatibility or require Owner review merely to change an otherwise non-semantic parser constant. [Current proposal](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:290).

## 8. Prototype cost assessment and cheaper viable alternative

The **Large** estimate is credible for the Draft’s full scope, but disproportionate before the first economic gate. Dominant costs are:

- two decision-equivalent boundary proofs: Medium–Large;
- generic structural diagnostics: Medium;
- isolated runner and autoload handling: Medium;
- Debug capture and confirmation UI: Medium;
- broader convergence: Medium;
- intentional behavior-change exercise: Medium elapsed effort.

The Draft’s own estimates identify those costs. [Work packages](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:863).

### Cheaper viable experiment

1. **Boundary feasibility gate:** prove the harder maneuver boundary first, without a GGS format, parser, diagnostics tree, or capture UI.
2. **One-family vertical slice:** implement only minimal strict envelope fields, final digest, optional per-command digests, direct production installation, replay submission, minimal Start/Stop capture, and one explicitly authorized Owner-recorded maneuver Candidate.
3. **Economic gate:** compare that Candidate against the closest focused test before adding CF, structural-path hashes, filters, or maintenance tooling.
4. **Second-family gate:** add CF as a positive control only if the first sample demonstrates residual value or produces a justified NARROW hypothesis.
5. **Maintenance gate:** perform the intentional-change exercise only before PROCEED, not before an earlier STOP/NARROW decision.

This preserves architectural correctness: canonical S0, cursor, ordinary commands, production validation, deterministic RNG, final oracle, and Owner provenance remain mandatory.

## 9. Assessment of Slices 0–3 and recommended first stop gate

Slices 0–3 are **not** the minimum useful proof.

- Slice 0 is useful.
- Slice 1 prematurely implements parser and generic diagnostics.
- Slice 2 should come before Slice 1 and should begin with the harder boundary only.
- Slice 3 without an Owner-recorded sample mostly repeats the already-proven technical mechanism in `test_replay_driver`; it cannot answer recording cost, provenance, maintenance, or marginal diagnosis value. [Existing mechanism proof](/Users/Katharina/godot/Armada/tests/unit/test_replay_driver.gd:20).

### Recommended gates

**First stop gate — before any GGS schema code**

Continue only if the chosen maneuver boundary:

- survives JSON roundtrip and live installation;
- preserves cursor, activation/execution/occurrence identities, deck, and RNG;
- derives the same canonical decision;
- reconstructs an actionable production board without submitting work;
- executes the same first command through replay mode;
- needs no scene/process-owned gameplay fact.

**Second stop gate — after one genuine Owner sample**

Continue to a second family only if:

- capture succeeds within the predeclared Owner-time budget;
- fresh-process execution is 10/10;
- the sample provides measurable locality or diagnosis benefit over its nearest focused test;
- artifact maintenance does not already outweigh that benefit.

Completion of an earlier slice is not authorization to continue.

## 10. Assessment of measurement design

The Draft covers most relevant categories, but it cannot yet support an objective STOP/NARROW/PROCEED decision.

Required corrections:

- **Measure implementation/tooling cost.** Record active engineering time, elapsed time, files/lines added, review/rework, debugging, and convergence time per slice. Current measurements start with Owner recording and omit the cost being amortized.
- **Predeclare thresholds.** “Materially improve,” “acceptable,” and “disproportionate” are not decision criteria. The Owner should set maximum prototype budget, maximum per-sample recording/maintenance effort, and required comparative benefit before implementation. [Current qualitative gate](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:1010).
- **Use comparable faults.** Mutating a GGS command or digest tests parser diagnostics and favors GGS. Diagnosis comparison should use the same temporary defect in shared production code and time both the closest focused test and GGS from the same starting information. [Current negative variants](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:924).
- **Define localization success.** Measure time to the correct file/function and root-cause class, whether the first report was correct, and whether a fix was identified within a fixed cap.
- **Measure break-even.** Compare build plus recording plus maintenance cost against expected repeated verification/diagnosis savings.
- **Measure non-semantic churn.** Include an intentionally harmless serialization/order change, not only a gameplay change, because mechanically derived hash trees may churn without behavioral value.
- **Separate unresolved maintenance evidence.** Lack of an intentional accepted behavior change may prevent PROCEED, but it should not prevent an earlier STOP or NARROW result.

The 10 fresh-process runs, Owner capture timings, closest-test comparison, full replay comparison where applicable, reconstruction checks, and duplicate-field classification are otherwise appropriate. [Measurement plan](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:887).

## 11. Compatibility/versioning assessment

The Draft correctly avoids save, replay, app, network, and command-version changes. A distinct experimental GGS format does not require changing replay Version 11 or save Version 9. [Version posture](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:235).

Refinement: app/save/replay versions should be diagnostic metadata only. A harmless app-version increment must not invalidate a Candidate when the actual S0 and command contracts remain readable. The GGS parser should fail on its own format incompatibility or failed state/command reconstruction, not on proxy version inequality.

Regression strategy is proportionate: focused checks after each slice and one full canonical suite at integrated convergence, not after every stage. [Broader convergence](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:825). Network convergence should remain conditional on touching shared paths.

## 12. Fixture-authority assessment

The Owner-controlled policy is generally strong:

- capture writes Candidate only;
- no overwrite/regeneration/promotion API;
- genuine Owner gameplay is required;
- expected digests derive from observed execution;
- acceptance and supersession remain explicit human/version-control acts. [Candidate authority](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:309), [provenance rule](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/GGS-001-limited-b-lite-prototype-implementation-workbook.md:648).

The Slice 3 named-file contradiction must be removed. Before the first Owner capture:

- parser tests may use ordinary in-memory schema specimens that are explicitly not Candidates;
- capture safety may use temporary paths and rejection cases;
- no successful repository fixture or accepted-runner happy-path file may claim `Candidate`;
- the first real runnable Candidate must be produced by an explicitly instructed Owner session.

Expected behavior must never be regenerated to make verification pass. A changed behavior requires a new Owner-validated Candidate; the old artifact remains unchanged.

## 13. Exact Owner decisions that remain

Before implementation:

1. Accept or reject the revised one-family-first experiment and its maximum implementation budget.
2. Choose the maneuver S0:
   - require exact proof of `maneuver_obstacle_pre_effect_ack_v1`; or
   - use the better-supported `maneuver_obstacle_order_choice_v1`.
3. Set the economic thresholds for capture effort, maintenance effort, localization benefit, and break-even.

During evaluation:

4. Explicitly authorize each Candidate capture and personally perform or validate its gameplay.
5. Authorize a controlled disposable behavior-change exercise only if no real accepted change occurs.
6. Choose STOP, NARROW, or PROCEED from the measured evidence.

No Owner decision is needed on save/replay version changes, Setup authority, UIC/UIP/UIF, replay redesign, or permanent GGS governance for this experiment. Those remain out of scope or deferred.

## 14. Final recommendation

**Revise and re-audit.**

Required before acceptance:

- move boundary proof ahead of parser/diagnostic work;
- reject or repair the maneuver acknowledgement boundary contract;
- eliminate synthetic Candidate risk;
- replace the fixed 12-command format limit;
- reduce the first experiment to one maneuver-family vertical slice;
- defer generic structural diagnostics and the CF positive control;
- add tooling-cost measurement, comparable fault experiments, and predeclared thresholds;
- specify direct production installation and experimental removal boundaries.

No repository files were modified, and no implementation or fixture generation was performed.

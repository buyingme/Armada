# GGS-001 adversarial repository audit

No production code, fixtures, or documentation were changed. Evidence labels:

- **Observed (O):** directly demonstrated by repository code, accepted authority, or executed tests.
- **Inferred (I):** strongly supported, but not yet proven across the full repository.
- **Unresolved (U):** requires Owner direction or further bounded evidence.

Verification performed during this audit:

- `test_replay_driver.gd`: 15/15 passed.
- `test_setup_placement_controller.gd`: 16/16 passed.
- `test_setup_flow_scene.gd`: 14/14 passed.
- Hot-seat baseline replay: command trace and final-state hash both matched.

## 1. Executive verdict

| Area | Feasibility | Expected value | Verdict |
|---|---:|---:|---|
| GGS Approach B as originally described | Medium | High | Narrow before proceeding |
| Minimal serialized-S0 GGS runner | High | High | Proceed as a limited prototype |
| Full recording/browser/step/debug experience | Medium | Medium | Defer until the runner proves value |
| UIC | High | High | Proceed as a compact, reference-oriented catalogue |
| UIP | Medium | Medium | Proceed narrowly; catalogue 6–8 semantics, not widgets |
| UIF | Medium-Low initially | Potentially High for selected flows | Pilot only after UIC/GGS |
| Full Setup replay | Low without authority changes | High eventually | Separate workstream |
| Combined architecture | High if incremental | Low if introduced as a large governance system | Proceed conditionally |

Direct conclusions:

- **GGS Approach B should proceed**, but as a **B-lite hybrid**: serialized canonical S0, command cursor, short normal replay commands, and canonical verification. Do not start with the full Debug browser, stepping UI, lifecycle catalogue, or broad checkpoint system.
- **UIC should proceed.** Existing FlowSpec, command registration, projectors, controllers, capability packages, and tests provide a strong bootstrap source.
- **UIP should proceed narrowly.** Recurrent semantics exist, but reusable code is less extensive than the workbook hypothesizes.
- **Setup should remain part of the same assurance initiative but be a separate implementation workstream.** Board placement can later use the GGS substrate; pre-board Setup cannot yet.
- **The expected long-term savings justify a limited investment**, not a big-bang implementation.
- **Recommended order:** minimal GGS runner proof and compact UIC reconciliation in parallel; Setup context work separately; checkpoints and recording UX only after the runner proves useful; UIF last.
- **Next artifact:** an Owner-approved, bounded implementation workbook for a test-only serialized-S0 GGS prototype. Separately execute the already-roadmapped Setup context pack.
- Genuine Owner decisions are listed in section 16.

The decisive repository finding is that Armada already possesses most of the authoritative execution substrate, but not the safe arbitrary-boundary capture and sample-governance layer. A focused test already demonstrates S0 plus a short command stream reproducing canonical state and RNG exactly: [test_replay_driver.gd](/Users/Katharina/godot/Armada/tests/unit/test_replay_driver.gd:20).

---

## 2. Current replay architecture

### What exists

**O — Complete-session artifact.** `GameReplay` stores a scenario/bootstrap header and an ordered command stream. The header contains scenario, initial RNG seed, factions, initiative, initial sequence and principal binding, but no serialized S0: [game_replay.gd](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:63).

**O — Strict artifact parsing.** Replay deserialization checks format version, exact integer values, binding validity, command canonicalization, and contiguous sequences: [game_replay.gd](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:119).

**O — Mature command substrate.** Startup currently registers 73 command types. Submission runs sequence checks, preflight, concrete validation, execution, history recording and continuation handling: [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:98), [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:379).

**O — Existing replay explicitly rejects arbitrary history cutover.** A non-zero reconstructed cursor cannot be written without a paired initial `GameState`: [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:787). This is exactly the seam GGS Approach B needs.

**O — Full canonical state representation.** `GameState.serialize()` includes players, interaction flow, timing-window state, current attack, inspection lifecycles, damage deck, principal binding and full RNG state: [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:1044).

**O — Strong reconstruction validation.** Deserialization checks bindings, damage/deck identities, attack references, timing state and multiple lifecycle invariants: [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:1169).

**O — Full RNG state is already serializable.** `GameRng` records both initial seed and current internal state: [game_rng.gd](/Users/Katharina/godot/Armada/src/core/state/game_rng.gd:60). This fits ADR-012’s requirement that authority save/load restore current RNG state: [ADR-012](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md:174).

**O — A canonical hash primitive exists.** `CanonicalJson.hash()` performs sorted-key JSON serialization and SHA-256 hashing: [canonical_json.gd](/Users/Katharina/godot/Armada/src/utils/canonical_json.gd:9).

**O — A state installation seam exists.** `GameManager.start_new_game_from_state()` validates a state, reconciles timing state, restores the command cursor and emits the normal game-start signal: [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:445).

**O — Current ReplayDriver is full-game/scenario-coupled.** It reconstructs by scenario and seed, assumes auto-submitted bootstrap commands, and then follows a global command cursor: [replay_driver.gd](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd:125), [replay_driver.gd](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd:288).

**O — Baseline diagnostics are coarse.** Per command, the trace records command type and interaction-flow coordinates. Only the final canonical state receives a full hash: [baseline_trace.gd](/Users/Katharina/godot/Armada/src/autoload/baseline_trace.gd:248), [baseline_trace.gd](/Users/Katharina/godot/Armada/src/autoload/baseline_trace.gd:165).

**O — Command rejection is not a first-divergence failure.** ReplayDriver logs rejections and normally waits for a timeout or another observed command: [replay_driver.gd](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd:504). That behavior is reasonable for duplicate auto-flow events but wrong for a precise GGS runner.

**O — Existing fixture is long-horizon and post-setup.** The hot-seat replay starts at `start_round`, contains 546 commands, and reconstructs the learning scenario rather than an arbitrary S0: [replay_hot_seat_solo.json](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_hot_seat_solo.json:1), [replay_hot_seat_solo.json](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_hot_seat_solo.json:5857).

### Reuse assessment for Approach B

| Substrate | Reuse |
|---|---|
| `GameState` serialization/deserialization | Reuse substantially unchanged |
| `GameRng` state | Reuse unchanged inside S0 |
| Command classes, registry and JSON normalization | Reuse unchanged |
| Command sequence validation and history | Reuse with a restored initial cursor |
| Normal authoritative command execution | Reuse unchanged |
| Timing-window reconciliation | Reuse unchanged |
| Canonical JSON/hash | Reuse unchanged |
| `start_new_game_from_state()` concepts | Reuse, but isolate test-runner side effects |
| `GameReplay` artifact schema | Do not extend blindly; use a distinct GGS envelope or explicitly versioned subtype |
| ReplayDriver full-game loop | Reuse helpers only; its scenario bootstrap and auto-prefix assumptions do not fit GGS |
| BaselineTrace | Reuse canonical hash logic, not its current record as the GGS checkpoint schema |
| Save-game UI/safe-point policy | Do not reuse as the GGS boundary policy |
| Debug annotation state capture | Reuse the capture concept; it already writes serialized state: [debug_mode.gd](/Users/Katharina/godot/Armada/src/autoload/debug_mode.gd:117) |
| Debug replay saving | Reuse command history, but it currently saves the whole session: [debug_mode.gd](/Users/Katharina/godot/Armada/src/autoload/debug_mode.gd:77) |

**Verdict:** Approach B can reuse most authoritative runtime mechanics. It cannot reuse the current replay artifact, ReplayDriver orchestration, or save-point policy unchanged.

### Adversarial findings

- **O:** Focused integration tests already provide excellent diagnostics for many capabilities. GGS adds little for single-command calculations already expressed cleanly in unit/contract tests.
- **O:** The existing replay-driver test is effectively a code-constructed GGS proof: explicit initial serialized state, seven real commands, final-state equality, and RNG equality. Therefore the cheapest architecture is to generalize this capability rather than build a new testing framework.
- **I:** GGS provides highest marginal value for multi-command interactions, recovery paths and regression-prone capability compositions—not every command.
- **U:** Arbitrary serialized S0 is not proven actionable. `validate_for_live_installation()` verifies important invariants, but Armada still has non-serialized process/controller state and scene-owned workflow state: [current_state_architecture_maps.md](/Users/Katharina/godot/Armada/docs/current_state_architecture_maps.md:300). Initial GGS must use whitelisted decision boundaries.

---

## 3. Setup Phase gap

Setup is not one homogeneous boundary.

### Pre-board Setup

**O — State representation exists.** `FleetSetupPackage` is JSON-safe and contains embedded players/rosters, first player, objective, placements and setup state: [fleet_setup_package.gd](/Users/Katharina/godot/Armada/src/core/setup/fleet_setup_package.gd:20).

**O — Deterministic bootstrap exists.** `FleetSetupBootstrapper` converts a package into a validated `GameState`, installs binding/RNG/deck state and records a canonical package hash: [fleet_setup_bootstrapper.gd](/Users/Katharina/godot/Armada/src/core/setup/fleet_setup_bootstrapper.gd:21).

**O — Player choices are not commands.** Local initiative/objective confirmation mutates scene fields and the setup-package draft directly: [setup_flow.gd](/Users/Katharina/godot/Armada/src/scenes/setup_flow/setup_flow.gd:668), [setup_flow.gd](/Users/Katharina/godot/Armada/src/scenes/setup_flow/setup_flow.gd:701). Network Setup performs similar mutations in `LobbyManager`: [lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:901).

**O — Tie-breaking uses global randomness.** Local, lobby and builder fallback paths use `randi_range`, not `GameState.rng`: [setup_flow.gd](/Users/Katharina/godot/Armada/src/scenes/setup_flow/setup_flow.gd:512), [lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:1147), [fleet_setup_package_builder.gd](/Users/Katharina/godot/Armada/src/core/setup/fleet_setup_package_builder.gd:494).

Therefore match/fleet selection, initiative selection/confirmation, objective choice/acknowledgement and tied-initiative RNG cannot be reproduced by current command replay.

### Board Setup

**O — Obstacle and deployment decisions are commands.** They validate normalized payloads, mutate canonical Setup state and derive the next Setup flow: [commit_setup_obstacle_command.gd](/Users/Katharina/godot/Armada/src/core/commands/commit_setup_obstacle_command.gd:39), [commit_setup_deployment_command.gd](/Users/Katharina/godot/Armada/src/core/commands/commit_setup_deployment_command.gd:38).

**O — Setup flow is reconstructable for obstacle/deployment/review.** `SetupInteractionFlowResolver` derives those steps from canonical state: [setup_interaction_flow_resolver.gd](/Users/Katharina/godot/Armada/src/core/setup/setup_interaction_flow_resolver.gd:42).

**O — Save UI excludes Setup.** `SaveGameManager.can_save_now()` returns “Cannot save during setup”: [save_game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:321). This is a product save policy, not proof that serialized Setup state is unusable for GGS.

### Confirmed Setup Review defect

The accepted Setup contract requires JSON-safe readiness and both players pressing `ready to start`: [setup_flow.md](/Users/Katharina/godot/Armada/docs/setup_flow.md:153).

The implementation instead:

- derives review with controller `-1` and no readiness payload: [setup_interaction_flow_resolver.gd](/Users/Katharina/godot/Armada/src/core/setup/setup_interaction_flow_resolver.gd:123);
- presents one `Start Round` button: [setup_placement_modal.gd](/Users/Katharina/godot/Armada/src/ui/setup/setup_placement_modal.gd:236);
- enables it based only on obstacle/deployment completeness: [setup_placement_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/setup_placement_controller.gd:686);
- lets `StartRoundCommand` mark Setup complete for the submitting player without requiring two readiness decisions: [start_round_command.gd](/Users/Katharina/godot/Armada/src/core/commands/start_round_command.gd:87).

This is **O — a confirmed contract non-conformance**, not an Owner decision unless the Owner wishes to revise the accepted contract.

### Additional presentation-owned Setup state

**O:** Selecting deployment speed writes directly to `ShipInstance.current_speed` during preview, before the deployment command commits: [setup_placement_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/setup_placement_controller.gd:334). Cancellation attempts to restore it, but this is still a direct mutation of canonical data during a supposedly transient preview. It conflicts with the accepted principle that preview state is transient and speed becomes durable only through contracted state/command mutation: [setup_flow.md](/Users/Katharina/godot/Armada/docs/setup_flow.md:42).

### Recommended Setup repair scope

1. Complete the already-planned Setup context pack `AT-010` and contract/test mapping `AT-016`: [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md:210).
2. Repair Setup Review readiness against the accepted contract.
3. Eliminate preview mutation of canonical ship speed.
4. Decide the authority model for pre-board Setup:
   - authoritative Setup commands/session events; or
   - a separate deterministic Setup decision log that produces `FleetSetupPackage`.
5. Move tied-initiative randomness under an accepted deterministic authority.
6. Add board-Setup GGS only after the general runner works.
7. Add pre-board/full-Setup replay only after steps 2–5.

**Conclusion:** Setup belongs in the assurance initiative, but incorporating it into the initial GGS prototype would distort the prototype and conceal whether GGS itself is cost-effective.

---

## 4. Current UI architecture

The dominant production path is:

`UI/controller → GameManager/submitter → CommandProcessor → GameState → UIProjector → ModalRouter/controllers → panel`

This path is recorded in the current-state map: [current_state_architecture_maps.md](/Users/Katharina/godot/Armada/docs/current_state_architecture_maps.md:212).

### Strong reusable mechanisms

**O — FlowSpec.** There are 32 registered flow-step rows, each carrying controller role, modal type, allowed commands and transitions. Examples cover command planning, activation, squadron, attack, status and board Setup: [flow_spec.gd](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd:16).

**O — UI projection.** `UIProjector` converts canonical/filtered state into viewer-specific modal, controller, payload and affordance intent: [ui_projector.gd](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:123).

**O — Timing opportunities.** Timing-window opportunities are derived from canonical state and rule participants, then projected with interactive/non-interactive ownership: [ui_projector.gd](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:456).

**O — Projection routing.** `ModalRouter` reacts after command execution and reconstructs the appropriate modal surface: [modal_router.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/modal_router.gd:1).

**O — Intent-to-command adapter.** `CommandRouterAdapter` and focused controllers convert projected intents into normal registered commands.

### Hybrid and incomplete mechanisms

**O — Attack remains a migration gap.** `AttackExecutor`, `AttackFlowFSM` and panel controllers retain scene workflow state and locally patch/publish attack flow. The repository already records this as an accepted migration concern, not normative architecture: [current_state_architecture_maps.md](/Users/Katharina/godot/Armada/docs/current_state_architecture_maps.md:328), [REALITY_GAP_REGISTER.md](/Users/Katharina/godot/Armada/docs/REALITY_GAP_REGISTER.md:91).

**O — Setup pre-board paths bypass the command spine.** Their durable output is a serialized package draft, but decision ownership and randomness are split between setup scene and lobby manager.

**O — Panels still contain substantial workflow state.** Activation and squadron modals hold preview/pending/action state locally. This is legitimate for transient presentation, but makes arbitrary-S0 actionability dependent on reconstruction quality.

**Authority constraint:** Existing code must not be canonized where it conflicts with accepted ADRs. Current-attack facts and semantic mutation remain command-owned and UI non-authoritative: [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md:53). All live decisions must be decision-equivalently recoverable from authoritative state: [ADR-010](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md:60).

---

## 5. Candidate UIC inventory

### Estimated size

- 73 registered commands.
- 32 FlowSpec rows.
- Several commands are automatic continuations, synchronization markers, debug actions or internal consequences rather than independent player-facing decisions.
- Several FlowSpec rows contain multiple semantic decisions.

**Estimated catalogue:** approximately **40–55 UIC entries**, subject to reconciliation. The number should not be equated with either command count or panel count.

### Representative forward inventory

| Candidate capability family | Decision and command surface | Production UI | Likely pattern | Evidence status |
|---|---|---|---|---|
| Match/fleet selection | Serialized `FleetSetupPackage` draft; no command | Setup flow/lobby | Visible selection + validation + confirmation | **O implementation; U authority boundary** |
| Initiative | Choose first player; both acknowledge; no command | Setup flow/lobby | Controller-specific choice + dual acknowledgement | **O implementation; missing replay surface** |
| Objective choice | Select, lock, acknowledge; no command | `ObjectiveChoicePanel` | Visible card choice + commitment + acknowledgement | **O** |
| Obstacle placement | `commit_setup_obstacle` | Setup placement controller/modal | Preview/drop/rotate/confirm/cancel | **O** |
| Deployment | `commit_setup_deployment` | Setup placement controller/modal | Visual placement + speed + commitment | **O**, with preview mutation concern |
| Setup review | Contract requires two ready decisions; current UI submits `start_round` once | Setup placement modal | Dual readiness | **O missing capability/command** |
| Command planning | `assign_dials` | Command dial picker/order modal | Ordered hidden selection + confirm | **O** |
| Ship activation | Select ship, reveal/convert/spend, advance/skip/end | Ship cards + `ActivationModal` | Staged workflow modal | **O** |
| Squadron activation | Activate, move/decline, attack/skip, complete | `SquadronActivationModal` | Select → preview/act → commit/decline | **O** |
| Attack declaration | `begin_attack` or `skip_attack` | Targeting/attack presentation | Visual target choice + commitment | **O**, scene-hybrid concern |
| Dice and CF/H9 choices | roll, use/decline, parameter selection, confirm | `AttackSimPanel` timing rows | Optional Use/Decline + visual parameter choice | **O** |
| Defense | accuracy, token spend, ECM, evade die, redirect, commit defense | Attack panel/mirror | Visible choice + constrained multi-step commit | **O** |
| Damage/immediate effect | resolve damage, choose card consequence, acknowledge | `OpponentChoiceModal`, inspection modal | Single/multi-choice or acknowledgement | **O** |
| Maneuver | select course, commit transform, obstacle order/consequences | Maneuver tools + `OpponentChoiceModal` | Preview/commit + order/choice | **O** |
| Squadron displacement | `commit_displacement` | `DisplacementModal` | Opponent-controlled placement + commit | **O** |
| Repair | `repair_action` variants | Activation/repair interaction | Resource allocation + commit | **O** |
| Tarkin | `tarkin_choice` use/decline | `TarkinChoiceModal` | Optional discrete choice | **O; CAP integrated** |
| ECM Status ready cost | `ready_ecm` / `decline_ecm_ready` | `ECMReadyCostModal` | Optional Use/Decline | **O implementation; capability package still Draft** |
| Attack/faceup result inspection | acknowledgement commands | Dedicated inspection panels | Required acknowledgement/wait state | **O** |

`CAP-UPG-001` is the only inspected package marked Integrated: [CAP-UPG-001](/Users/Katharina/godot/Armada/docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md:1). Other implemented-looking packages such as ECM and CF remain Draft and must not be presented as accepted merely because code and tests exist: [CAP-ECM-001](/Users/Katharina/godot/Armada/docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md:1), [CAP-CF-001](/Users/Katharina/godot/Armada/docs/architecture/rule_capability_packages/CAP-CF-001-concentrate-fire-attack-effects.md:1).

---

## 6. Candidate UIP inventory

Only genuinely recurring interaction semantics should become initial UIP entries.

| Candidate pattern | Existing reuse | Assessment |
|---|---|---|
| Optional decision: Use / Decline | Generic timing-window rows in `AttackSimPanel`; separate Tarkin and ECM modals | Strong semantic recurrence; partial code reuse |
| Discrete single/multi-choice | `OpponentChoiceModal` is reused for damage effects and maneuver consequences: [ship_activation_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1201) | Strongest existing reusable component |
| Visual object choice | Dice selection, board target selection, ship/squadron selection | Strong semantic recurrence; object-specific rendering limits component reuse |
| Preview → validate → explicit commit/cancel | Setup placement, maneuver, squadron movement, displacement | Strong pattern; implementations remain domain-specific |
| Ordered resolution choice | Obstacle permutations presented through `OpponentChoiceModal`: [ship_activation_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1253) | Useful and already mapped to generic choice UI |
| Required acknowledgement / passive waiting | Attack result, faceup damage, obstacle pre-effect | Strong cross-mode semantic pattern |
| Controller/passive projection | `UIIntent.is_interactive`, `open_mirror`, `set_interactable` | Important architectural pattern; duplicated across modal implementations |
| Staged workflow modal | Ship activation, squadron activation, attack | Common UX shape but too behavior-specific for a generic base component today |

UIP should document:

- semantic purpose;
- controller/passive behavior;
- reversible versus committed boundary;
- command/intention expectations;
- accessibility/input expectations;
- reusable implementation, if one exists.

It should not copy scene trees, colors, widget hierarchy, payload schemas or command validation rules.

---

## 7. Bidirectional traceability findings

### Representative reverse traces

**O — Tarkin**

`TarkinChoiceModal choice/decline → ModalRouter → tarkin_choice → timing/upgrade authority → CAP-UPG-001`

Evidence: [tarkin_choice_modal.gd](/Users/Katharina/godot/Armada/src/ui/upgrades/tarkin_choice_modal.gd:40), [modal_router.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/modal_router.gd:287).

**O — Maneuver consequence**

`OpponentChoiceModal → purpose-specific command payload → normal submitter → command validation/execution → canonical ship/maneuver state`

Evidence: [ship_activation_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1344).

**O — Timing-window choice**

`AttackSimPanel projected row → use/decline intent → AttackPanelController → command adapter → registered command → TimingWindowState/rule authority`

Evidence: [attack_panel_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_panel_controller.gd:422).

**O — Setup initiative/objective**

`Setup UI → scene or LobbyManager direct draft mutation → FleetSetupPackage → bootstrap → GameState`

There is no command/history link for the decision itself.

### Gap findings

| Finding | Type | Classification |
|---|---|---|
| Setup Review lacks contracted two-player readiness state and command | Missing UI/decision surface | **Confirmed defect** |
| Tied Setup initiative uses global RNG and is absent from replay | Replay/authority gap | **Architecture concern** |
| Local/network pre-board Setup duplicate decision-state transitions | Duplicated interaction/authority | **Architecture concern** |
| Setup speed preview mutates canonical `ShipInstance` before command | Presentation-owned gameplay state | **Confirmed contract non-conformance** |
| Attack scene workflow still patches/publishes flow around command-owned state | Presentation/authority hybrid | **Known migration concern** |
| Full replay starts at `start_round`, after scenario/setup construction | Coverage gap | **Test gap** |
| Current replay records all commands, including internal/automatic/debug commands | Catalogue hazard | **Documentation/modeling concern** |
| Most rule capability packages are Draft despite production-looking code/tests | Authority/status mismatch | **Documentation gap; do not infer acceptance** |
| Tarkin, ECM and timing-window choices use different optional-decision UI implementations | Equivalent semantics, inconsistent implementation | **Reuse opportunity, not automatically a defect** |
| Preview/commit workflows are implemented separately for setup, maneuver, squadron and displacement | Duplicate semantics | **UIP opportunity; generic component not yet justified** |
| Debug help advertises F5/F8 quicksave/quickload, but no matching input handlers were found | Orphan UI text | **Confirmed non-gameplay UI defect**: [debug_help_panel.gd](/Users/Katharina/godot/Armada/src/ui/debug/debug_help_panel.gd:92) |
| Debug Ctrl+S signal remains, but the handler only advises using authoritative reposition | Obsolete debug interaction | **Confirmed dead/legacy path**: [debug_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/debug_controller.gd:184) |
| `ScenarioSaver` still exists but production debug saving has been superseded | Orphan mechanism | **Cleanup candidate, not GGS reuse**: [scenario_saver.gd](/Users/Katharina/godot/Armada/src/utils/scenario_saver.gd:1) |

No broad set of player-authored gameplay commands without production UI was proven in this audit beyond Setup Review. An exhaustive generated command-to-UI diff is still required before claiming completeness.

---

## 8. Existing test coverage mapping

| Assurance layer | Existing evidence | Assessment |
|---|---|---|
| Unit calculations/models | Command, resolver, rule, state and UI component tests | Extensive |
| Command/contract tests | `test_attack_commands`, movement, repair, Setup commands, applicability, atomic failure | Extensive |
| Projection/UI intent | `test_ui_projector`, `test_modal_router`, timing projection, panels | Strong but not equivalent to player-driven UIF |
| Production composition | Current attack shared protocol/resume, timing shared protocol, network resume, stabilization recovery | Strong for recent architecture-sensitive areas |
| GGS-like short executable sample | `test_replay_driver` uses serialized S0 plus short real command history and asserts state/RNG equality | Strong proof of feasibility |
| Full-game replay | Hot-seat trace + committed final hash; network host/client final-hash equality | Existing and passing |
| Setup | Package/builder/bootstrap/scene/controller tests | Good components; no deterministic complete Setup replay |
| UI Flow | No general production-input automation layer | Absent |
| Visual regression | No selected visual-golden layer | Absent by design |
| Manual Owner QA | Bug/workbook/manual evidence | Valuable but expensive and distributed |

Representative evidence:

- Replay roundtrip and exact RNG equality: [test_replay_driver.gd](/Users/Katharina/godot/Armada/tests/unit/test_replay_driver.gd:20).
- Production active-attack reconstruction: [test_current_attack_production_resume.gd](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:1).
- Shared timing-window protocol explicitly avoids making a capability claim: [test_timing_window_shared_protocol.gd](/Users/Katharina/godot/Armada/tests/integration/test_timing_window_shared_protocol.gd:1).
- Full replay harness and current oracle policy: [run_baseline_traces.sh](/Users/Katharina/godot/Armada/scripts/run_baseline_traces.sh:1).

Adversarial conclusion: GGS must not duplicate focused tests. It should cover short, meaningful, multi-command authoritative examples whose maintenance or diagnosis is materially worse in existing code-built tests or full-match replay.

---

## 9. Option comparison

| Option | Advantages | Problems | Verdict |
|---|---|---|---|
| A — Short current replay fixtures | Lowest implementation cost; existing CLI and artifacts | No paired S0; scenario/bootstrap coupling; sequence-zero assumption; auto-prefix behavior; weak checkpoints | Insufficient as the target |
| B — Full proposed GGS | Best provenance, locality and diagnostics | Recorder, safe boundaries, lifecycle, checkpoints, browser and governance create substantial scope | Preferred concept, too large initially |
| C — Declarative scenario construction | Human-readable setup; potentially composable | High synthetic-state risk; duplicates constructors and gameplay semantics; grows a second setup language | Reject as general GGS architecture |
| Hybrid B-lite | Serialized real S0 + cursor + short normal commands + final canonical digest; optional later checkpoints | Needs new envelope and safe-boundary policy | Recommended |
| Focused tests only | Already effective and highly diagnostic | Code-built states may be synthetic; no Owner-captured executable artifact/provenance; poor reuse for manual debugging | Retain, but not sufficient alone |

Option C remains useful only where an already-authoritative declarative object exists, such as `FleetSetupPackage`. It should be treated as a legitimate bootstrap input for Setup, not expanded into a universal GGS state DSL.

---

## 10. Maintenance analysis

### UIC

UIC is valuable if it is a compact index over existing authority, not a second specification.

A useful row needs only:

- stable UIC ID and semantic name;
- authority/capability/requirement references;
- authoritative decision and command types;
- production UI owner and supported modes;
- UIP IDs;
- representative test/GGS/UIF references;
- evidence/status: Observed, Inferred, Unresolved, accepted gap.

It should not copy:

- command payload schemas;
- detailed rule semantics;
- modal text;
- transition logic already in FlowSpec;
- test procedures;
- capability package content.

FlowSpec and the command registry can generate much of the discovery report. Manual review remains necessary because:

- commands are not one-to-one with decisions;
- some decisions have multiple commands;
- automatic and debug commands are not UICs;
- Setup decisions are not commands;
- Draft capability packages are not accepted authority.

### UIP

UIP maintenance is justified for approximately 6–8 stable semantic patterns. It becomes wasteful if it tries to describe every modal or enforce inheritance among domain-specific panels.

The initial UIP should reference existing reusable components and explicitly distinguish:

- reusable semantic pattern;
- reusable code component;
- domain-specific implementation of the pattern.

### GGS lifecycle

Keep identity, status, provenance, format compatibility and expected digest in the sample artifact or a single adjacent manifest. Acceptance/supersession should be explicit in version control. Do not maintain a separate narrative document per sample.

---

## 11. Recommended target architecture

### Minimal GGS artifact

A versioned GGS envelope containing:

- stable sample ID and title;
- lifecycle state and Owner acceptance provenance;
- related capability/requirement references;
- serialized full-authority S0;
- initial command sequence cursor;
- short ordered serialized command list;
- expected final canonical digest;
- format/app compatibility metadata.

Do not persist transport result envelopes as replay decisions. ADR-012 requires replay to remain deterministic command re-execution: [ADR-012](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md:174).

### Minimal runner

1. Parse and schema-validate the sample.
2. Deserialize S0.
3. Run live-install and timing/recovery validation.
4. Restore the command cursor.
5. Submit each command through replay mode.
6. Fail immediately on deserialization, validation or execution rejection.
7. After every command, optionally compute an actual digest for diagnostics.
8. Compare the final canonical digest.
9. Report the first divergent/rejected command and a structural state diff.
10. Support one sample, one capability family and all samples through filters.

### Safe S0 policy

Do not initially promise arbitrary S0. Permit only whitelisted boundaries that pass:

- serialization roundtrip;
- `validate_for_live_installation`;
- timing/current-attack reconstruction checks;
- command cursor/lifecycle identity validation;
- decision-equivalent projection/actionability checks;
- focused production-resume evidence for that boundary family.

The initial pilot should avoid uncommitted scene previews.

### Checkpoints

Phase one needs only final digest plus per-command actual diagnostic hashes. If the pilot shows final-state failures remain costly, add selected accepted checkpoints.

Avoid manually maintaining repeated full `GameState` snapshots. Prefer:

- canonical digest after selected commands;
- automatically generated structural diff on failure;
- a few capability-specific semantic assertions only where they add explanatory value.

RNG need not be a separate manually maintained representation because full RNG state is already included in canonical state. Report it separately when it is the first differing field.

### Recording

Recording should eventually:

- capture S0 and cursor at Start;
- remember the history index;
- slice accepted commands at Stop;
- compute candidate expected outputs;
- require explicit Owner review before Valid status.

The first cost/benefit prototype does not need a browser, pause/step UI or broad Debug-state authoring. Existing canonical debug operations are limited to reposition and damage assignment: [debug_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/debug_controller.gd:365), [debug_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/debug_controller.gd:510).

---

## 12. Incremental implementation plan

The workbook’s UIC-first, then complete recorder-first ordering is broader than necessary. Use three coordinated tracks.

### Track A — Prove GGS value

1. Owner approves the narrow experiment and S0 policy.
2. Create a test-only B-lite artifact parser/runner.
3. Add immediate rejection/failure reporting and final canonical comparison.
4. Add only the minimal capture hook needed for one or two Owner-recorded experimental samples.
5. Select:
   - one short timing/attack interaction already supported by production-resume evidence;
   - one different multi-command/recovery family.
6. Measure:
   - sample recording time;
   - execution time;
   - failure-localization time;
   - maintenance after one intentional behavior change;
   - comparison with the closest focused test and full replay.
7. Stop or narrow further if the samples add no material diagnostic or maintenance value.
8. Add checkpoints only if the measurements justify them.
9. Add browser/load/step only after automatic execution proves useful.
10. Add CI family/all execution after sample count warrants it.

### Track B — Prove UIC/UIP maintenance value

1. Generate a candidate evidence report from FlowSpec, command registration and test references.
2. Manually reconcile 10–15 high-risk capabilities, not the whole historical surface.
3. Record confirmed gaps and Draft/Integrated distinctions.
4. Accept a compact UIC baseline only if one capability change can update it cheaply.
5. Create the initial 6–8 UIP entries from proven recurrent semantics.
6. Expand opportunistically when gameplay changes touch an existing capability.
7. Do not introduce UIC/UIP into Definition of Done until this workflow proves low-cost.

### Track C — Setup separately

1. Execute `AT-010` Setup Flow Context Pack.
2. Execute `AT-016` Setup Contract Test Mapping.
3. Repair Setup Review readiness and preview-owned speed.
4. Obtain an Owner decision on pre-board Setup authority and replay boundary.
5. Make tied-initiative RNG deterministic under that authority.
6. Add board-Setup GGS.
7. Extend full replay before Setup only after pre-board decisions have an authoritative replayable record.

### UIF

Run one production-UI pilot only after UIC identifies a high-value target. Concentrate Fire is a plausible candidate because it crosses projected timing opportunities, visual die choice, multiple commands and Hot-Seat/Network presentation. Do not start screenshot testing in the pilot.

---

## 13. Effort assessment

| Work package | Estimate | Dominant cost/risk |
|---|---:|---|
| Minimal GGS schema/parser | Small–Medium | Versioning and strict validation |
| Headless serialized-S0 runner | Medium | Correct state installation and isolation from full-game bootstrap |
| Safe-boundary validator/allowlist | Medium–Large | Decision-equivalent recovery and scene/process state |
| Immediate command rejection and structural diff diagnostics | Medium | Useful diffing without a second state model |
| Minimal bounded Start/Stop capture | Medium | Cursor/history slicing and genuine provenance |
| Two Owner-recorded experimental samples | Small after tooling | Finding naturally reachable, stable situations |
| Intermediate accepted checkpoints | Medium | Avoiding redundant expected-state representations |
| Manual load/replay | Medium | Board/presentation reconstruction |
| Pause/step/browser UI | Medium–Large | Scene orchestration and UX |
| One/family/all CLI and CI integration | Small–Medium | Filtering, failure output and runtime |
| Candidate UIC evidence extractor/report | Medium | Mapping commands to semantic decisions |
| Reconciled initial UIC baseline | Medium | Authority/status review |
| Initial narrow UIP | Small | Semantic naming and references |
| UIF production-input pilot | Large | Stable input targeting, async modal state and cross-mode behavior |
| Setup context/test mapping | Medium | Distributed state across setup scene, lobby, package and board |
| Setup Review repair | Medium | Two-controller Hot-Seat/Network semantics |
| Pre-board Setup replay authority | Large | New decision surface, ordering, RNG and lobby integration |
| Full replay beginning before Setup | Very Large | Cross-scene lifecycle, Hot-Seat/Network and deterministic handoff |

The dominant overall risks are safe S0 reconstruction, Setup’s split authority, and production UI automation—not command serialization or canonical hashing.

---

## 14. Cost/benefit conclusion

**Yes, the expected long-term savings justify the investment—conditionally.**

The repository supports that conclusion because:

- the hardest semantic machinery already exists;
- a short serialized-state command replay has already been demonstrated in a passing focused test;
- current full replay runs 546 commands for one long-horizon sentinel;
- existing architecture gaps make traceability and diagnosis genuinely expensive;
- FlowSpec and UI projection substantially reduce UIC bootstrapping cost.

The investment does **not** justify:

- mandatory GGS for trivial or single-command behavior;
- a full Debug sample browser before runner proof;
- an exhaustive historical backfill;
- a catalogue that copies rule or flow semantics;
- a generic declarative scenario language;
- folding full Setup replay into the first GGS slice;
- making GGS/UIC/UIP/UIF immediate Definition-of-Done requirements.

Expected benefit by mechanism:

- **GGS:** high regression-localization and convergence benefit for short multi-command capabilities.
- **UIC:** high completeness and impact-analysis benefit.
- **UIP:** moderate consistency/reuse benefit.
- **UIF:** high benefit only for a small risk-selected set.
- **Setup replay:** high eventual benefit, but too expensive to use as proof of the initial architecture.

---

## 15. Risks and failure modes

| Risk | Consequence | Control |
|---|---|---|
| Accepted sample silently regenerated | Regressions become new expected behavior | Owner-only acceptance/supersession; immutable review history |
| Arbitrary invalid S0 | False failures or synthetic gameplay | Boundary allowlist and reconstruction/actionability validation |
| Fixture drift after harmless serialization changes | High maintenance noise | Versioned migration policy; structural comparison scoped only where accepted |
| Catalogue drift | False completeness claims | Generate evidence, keep accepted catalogue compact, CI-check references where practical |
| Duplicate specifications | Contradictory rule/UI truth | UIC/UIP store references and mappings, not semantics |
| Over-testing | Slower development and duplicated assertions | GGS only for meaningful multi-command capabilities |
| Synthetic declarative states | Tests pass situations production cannot reach | Owner-recorded live S0 provenance |
| Recorder preparation becomes expensive | Manual QA cost moves into sample authoring | Sparse samples; natural gameplay plus accepted debug commands only |
| Scene-owned state omitted from S0 | State loads but cannot continue correctly | Decision-equivalent recovery checks and boundary-family resume tests |
| ReplayDriver reused wholesale | Scenario-prefix and rejection behavior obscure failures | Dedicated narrow GGS runner |
| Checkpoint overproduction | Large brittle artifacts | Add only selected digests after pilot evidence |
| Setup included too early | Prototype cost dominated by unrelated authority changes | Separate Setup track |
| UIC treats every command as a capability | Bloated misleading catalogue | Semantic reconciliation; exclude automatic/debug/sync commands |
| Draft capability package treated as accepted | Existing code becomes accidental architecture | Preserve package status and Owner gates |
| UIF coupled to nodes/layout | Brittle automation | Target stable semantic/input surfaces after UIP/UIC |

---

## 16. Owner decisions required

Only these choices remain genuinely unresolved:

1. **Authorize the limited GGS B-lite prototype or stop after discovery.**
2. **Choose the initial S0 policy:** only explicitly whitelisted decision boundaries, or a broader “any live-install-valid state” policy. The audit recommends the whitelist.
3. **Choose sample acceptance authority and lifecycle:** who may mark a sample Valid, and who may supersede it after intentional behavior change.
4. **Choose the pre-board Setup authority model:** replayable commands/session events versus another explicit deterministic decision log.
5. **Choose the eventual full-replay start boundary:** before match/fleet selection, after fleets but before initiative, or at installed setup package.
6. **Approve UIC as a compact authoritative mapping and designate its source-of-truth relationship to FlowSpec, capability packages and requirements.**
7. **Approve UIP as a small semantic-pattern index rather than a component framework.**
8. **Choose historical backfill policy:** risk-based/opportunistic is recommended.
9. **Choose when, if ever, GGS/UIC/UIP/UIF consideration enters Definition of Done.** Not before measured prototype value.

These do not require Owner reinterpretation:

- Setup Review currently violates the accepted contract.
- Setup speed preview currently mutates canonical state before command commitment.
- most inspected capability packages remain Draft;
- current full replay does not exercise Setup decisions.

---

## 17. Recommended next artifact

Proceed with a **limited prototype**, not an ADR yet.

The next artifact should be an Owner-approved implementation workbook titled along the lines of:

> Minimal Serialized-S0 Golden Gameplay Sample Prototype

Its scope should be restricted to:

- a versioned experimental GGS envelope;
- S0 plus cursor;
- normal serialized commands;
- strict headless execution;
- immediate rejection reporting;
- final canonical digest and structural diff;
- a boundary allowlist;
- one or two Owner-recorded experimental samples;
- explicit measurements and a stop/continue decision gate.

Do not include browser UI, step controls, general scenario construction, UIF, Setup authority changes or Definition-of-Done governance.

In parallel, create the already-roadmapped **Setup Flow Context Pack (`AT-010`)**, followed by **Setup Contract Test Mapping (`AT-016`)**. UIC/UIP should be a separate compact reconciliation task seeded from generated repository evidence.

An ADR becomes appropriate only if the prototype demonstrates favorable cost/benefit and the project is ready to commit to permanent artifact ownership, lifecycle and governance.

# Refactoring Phases L & M — Unified Flow Authority and Rule Registry

> **Status:** READY-TO-START — 2026-05-11 (drafted 2026-05-10; refreshed 2026-05-11 after K14 closure and the 2026-05-10/11 bug-batch postmortem).
> **Predecessors:** Phase K — K0 through K14g committed (last: `33e697f`); the deferred §3.1d hot-seat-modal-lifecycle work is now Phase L's scope. Slices K15–K19 are orthogonal and may interleave (see §7.1).
> **Go-conditions (verified 2026-05-11):**
>   - K12 `CommandRouterAdapter` committed (`e17ff05`).
>   - K14 `AttackFlowExecutor` complete (K14a `454fd0e` → K14g `33e697f`).
>   - `bash scripts/lint_phase_k.sh` exits `0` (11 allow-listed sites — the L target floor is ≤ 4).
>   - GUT baseline: 144 scripts / 2 917 tests / 5 521 asserts / 0 failures.
>   - No `interaction_flow` schema change pending. No save-format change pending.
> **Successor:** Resumes G4.7 (Spectator), G4.8 (Reconnection runtime), G4.9 (Turn Timers), then Phase 10c.
> **Cross-refs:** [docs/implementation_plan.md](implementation_plan.md), [docs/refactoring_phase_k_plan.md](refactoring_phase_k_plan.md) §3.1d, [.skills/serialization_and_commands.md](../.skills/serialization_and_commands.md), [.skills/architecture_patterns.md](../.skills/architecture_patterns.md).

---

## 0. Why this plan exists

Four persistent symptoms keep recurring even after Phases A–K. The fourth is
new evidence from the 2026-05-10/11 bug-batch (annotations
`20260510_*` / commit `c673ef0`) and directly reinforces the LM thesis.

1. **Mode divergence.** Hot-seat and network mode share the command path
   (Phase G), the domain layer (Phases A–F), and the interaction-flow
   primitive (Phase I), yet still diverge in the *runtime modal
   lifecycle*. Phase K §3.1d makes this explicit: hot-seat opens modals
   via direct callbacks (`_show_activation_sequence_button`,
   `_displacement_controller.start()`, `ShipActivationController`
   direct calls) while network opens the same modals via
   `UIProjector.project()` reading `interaction_flow`. **Two control
   paths for one game = a permanent source of divergence bugs.**
2. **Rule placement is implicit.** Game rules (defense token spend
   eligibility, ready-token gating, dial-pop side effects, damage card
   immediate effects, keyword interactions) are scattered across
   resolvers, executors, controllers, and command `validate()`/`execute()`
   methods. Adding a new card/keyword/upgrade requires hunting for the
   right insertion site and editing many files. There is no single
   inventory of "what rules apply at step X."
3. **Authoritative flow state is partially enforced.** `interaction_flow`
   is the source of truth for *what step we are in*, but the *list of
   commands legal in that step* lives implicitly in each command's
   `validate()`. Two peers can hold the same `interaction_flow.step_id`
   yet still drift on activation flags, mirror lifecycle, or
   skipped-move bookkeeping (the 2026-05-10 squadron-phase desync
   was exactly this shape — see [memories/repo/squadron-activation-sync.md](#)).
4. **`controller_player` is computed ad-hoc at every producer.**
   The 2026-05-11 displacement bug (annotation `20260510_170352`,
   fixed in `c673ef0`) set `controller_player` to the squadron's
   owner instead of the non-moving player; the regression was
   invisible whenever ship-owner == squadron-owner. Per RRG
   "Overlapping", p.8 the controller is *always* the opponent of
   the maneuvering ship's owner. The defect was structural: there is
   no central declaration `DISPLACEMENT_PLACE → OPPOSING_PLAYER`, so
   every command producer must (and may) re-derive it. The same
   shape produced the brace-canonical-sort regression
   (annotation-batch defect 2 — click order overrode the RRG
   resolution order because the order lived in three different
   call sites) and the activation-modal stale-snapshot defect
   (defect 1 — a scene-side cached `is_attack_skippable` flag
   diverged from the live `interaction_flow.step_id`). Each was a
   *one-source-of-truth* failure, not a logic failure.

The through-line: **the engine needs one declarative table that says
"in step X the controller is Y, the visible modals are Z, and the
legal commands are W," consulted by every producer and projector.**
Phase M (FlowSpec) is exactly that table; Phase L is the prerequisite
that removes the second modal-lifecycle path so the table only has
one consumer per concern.

Phases L and M close all three with the *minimum* structural change
that does the job. They keep the existing serialisation contract,
existing command system, existing test harness, and existing modal
classes. Nothing forks. Nothing parallel-channels.

---

## 1. The verdict: yes, this approach is the way, with one explicit boundary

I considered four alternatives before recommending this plan:

| Alternative | Verdict | Reason |
|---|---|---|
| Pure natural-language flow doc (no runtime spec) | Rejected | Will rot the moment a fix lands without doc update. No enforcement. |
| Embed rule list inside FlowSpec (FlowSpec owns rules) | Rejected | Every new card forces an edit to the central spec. Merge-conflict factory. Doesn't match the open-ended nature of the rule set. |
| External state-machine library (XState-style) | Rejected | Heavy for a 144-script GDScript codebase. The bespoke skeleton we already have (`InteractionFlow`) covers 90% of state-machine value. |
| **Hybrid: FlowSpec skeleton (stable) + RuleRegistry (open-ended), inverted ownership (rules self-register to flows)** | **Recommended** | Matches how the domain actually evolves. Cleanly separates the rare-change skeleton from the frequent-change rule content. Composes with `interaction_flow` and `UIProjector` already in production. |

The boundary that must be enforced: **FlowSpec owns *which steps exist*
and *who controls them*. Rules can only attach hooks to existing steps;
they cannot invent new steps.** Inventing a new step is a deliberate
two-file change (FlowSpec + the rule), not a side effect of adding a
card.

---

## 2. Goals & Non-Goals

### 2.1 Goals (quantified)

| ID | Target |
|----|--------|
| L-G1 | Zero modal-authority code paths that branch on `PlayMode` or `NetworkManager.get_local_player_index() >= 0` for **lifecycle** decisions (open/close/mirror). Camera-ownership branches stay (intrinsic deployment-mode property). |
| L-G2 | Hot-seat opens, mirrors, and closes every gameplay modal (Activation, Squadron, Displacement, Attack, Immediate-Choice, Repair) via the same `EventBus.command_executed → UIProjector.project → modal lifecycle` chain that network already uses. |
| L-G3 | Phase K's `scripts/lint_phase_k.sh` allow-list shrinks from 11 sites to ≤ 4 (only intrinsic deployment-mode dispatchers — save-dialog disable, lobby-only flow). |
| M-G1 | Single `FlowSpec` registry covers every `(flow_id, step_id)` pair that `interaction_flow` can hold. Parity test fails CI if `UIProjector` projects an unknown pair. |
| M-G2 | Every `GameCommand` subclass declares its `applicable_steps` (set of `(flow_id, step_id)` pairs). Parity test fails CI if a `validate()` is reached for a command type whose declared steps don't include the current step. |
| M-G3 | At least 6 representative rules (1 keyword, 2 damage cards, 1 defense-token rule, 1 status-phase rule, 1 attack-modifier rule) migrated to `RuleRegistry` self-registration. Adding the 7th is documented as a one-file change. |
| M-G4 | Determinism: hook execution order across peers is byte-identical (priority + lexicographic rule_id tie-break). Replay test asserts hook order. |
| LM-G1 | Test baseline maintained: 0 failing tests at every commit; `godot --headless --import` clean; `bash scripts/lint_phase_k.sh` exits 0. |
| LM-G2 | All sliced commits keep the manual-test gate (per `.skills/copilot_instructions.md`). |
| LM-G3 | No save-format version bump. No new RPC channels. No new EventBus signals beyond what Phase L's modal-projection migration intrinsically requires. |

### 2.2 Non-Goals

- **No new gameplay features** during L or M. Bug fixes that fall out of the unification are in scope; feature additions are not.
- **No migration of every keyword** to the registry. Migrate only those touched by L/M-G3. Older keywords stay where they are until next-touch.
- **No replacement of `GameCommand`.** Commands stay as today; they gain a static `applicable_steps()` declaration and consult `RuleRegistry` from `validate()` and `execute()`.
- **No replacement of `UIProjector`.** It gains a dependency on `FlowSpec` for modal-visibility lookup and stays the single projection function.
- **No CI/CD setup.** Same as Phase K.
- **No file-format migration.** `interaction_flow` JSON shape unchanged.

---

## 3. Architecture

### 3.1 Three layers, three responsibilities

```
+--------------------------------------------------------------+
|  Layer 1: Natural-language master document                   |
|  docs/game_flow.md                                           |
|  One block per (flow, step). Cites Rules Reference.          |
|  Designed to be read by a human without reading code.        |
+--------------------------------------------------------------+
                        |  generated/parity-checked
                        v
+--------------------------------------------------------------+
|  Layer 2: FlowSpec (structured machine spec)                 |
|  src/core/state/flow_spec.gd  [RefCounted, autoload-bound]   |
|  Skeleton: which (flow, step) pairs exist, who controls,     |
|  which modals are visible, allowed command types,            |
|  transitions. STABLE; rare changes.                          |
+--------------------------------------------------------------+
                        |  consulted by
                        v
+----------------------+----------------+---------------------+
|  CommandProcessor    |  UIProjector   |  RuleRegistry       |
|  (validate, execute) |  (modal proj.) |  (hook lookup)      |
+----------------------+----------------+---------------------+
                                                |  populated by
                                                v
+--------------------------------------------------------------+
|  Layer 3: Rules (self-registering)                           |
|  src/core/effects/rules/<rule_name>.gd                       |
|  Each rule's static register() returns FlowHook[].           |
|  OPEN-ENDED; one file per card/keyword/upgrade.              |
+--------------------------------------------------------------+
```

### 3.2 FlowSpec entries (stable skeleton)

```gdscript
## src/core/state/flow_spec.gd
class_name FlowSpec
extends RefCounted

## Returns the spec for a given (flow_id, step_id) pair, or null
## if the pair is not registered.  Phase M-G1: every pair that
## InteractionFlow can hold MUST be in the registry.
##
## Spec Dictionary keys:
##   "controller_role": Constants.ControllerRole
##       (ACTIVE_PLAYER | OPPONENT | DEFENDER | SQUADRON_OWNER | EITHER)
##   "modals":          Array[Constants.ModalKind] visible in this step
##   "allowed_commands": Array[String] command_type strings legal here
##   "transitions":     Dictionary[String, String]
##       command_type -> next step_id (or "*" for "any step")
##   "rule_citation":   String  ("RR p.4 Step 4")
static func get_spec(flow_id: int, step_id: int) -> Dictionary:
    return _SPEC.get([flow_id, step_id], {})
```

The `_SPEC` table is a literal `const Dictionary` — no dynamic
mutation. Tests can iterate it.

### 3.3 RuleRegistry entries (open-ended content)

```gdscript
## src/core/effects/rule_registry.gd
class_name RuleRegistry
extends RefCounted

## A FlowHook ties one predicate to one (flow_id, step_id).
## Kind drives how/when the engine consults it:
##   VALIDATOR — pre-execute veto on a command. Returns
##               {"allowed": bool, "reason": String}.
##   MODIFIER  — mutates a transient context dict (dice pool, damage
##               total, ready set). Pure-functional preferred.
##   OBSERVER  — reacts after a command commits. May submit follow-up
##               commands via the normal submitter; never mutates
##               GameState directly.
##   BLOCKER   — gates a step transition ("can we leave this step?").
##   ENABLER   — exposes optional UI affordances at this step
##               (an upgrade button, a re-roll choice).

## Rules call register_rule() at autoload time.  Order of calls is
## irrelevant; hooks are sorted by (priority DESC, rule_id ASC) before
## execution to guarantee determinism across peers.
static func register_rule(rule_id: String, hooks: Array[FlowHook]) -> void:
    ...

## Engine API:
static func validators_for(flow_id: int, step_id: int,
        command_type: String) -> Array[FlowHook]: ...
static func modifiers_for(flow_id: int, step_id: int,
        context_key: String) -> Array[FlowHook]: ...
static func observers_for(flow_id: int, step_id: int,
        command_type: String) -> Array[FlowHook]: ...
```

A rule file (one card/keyword = one file):

```gdscript
## src/core/effects/rules/faulty_countermeasures.gd
##
## Rules Reference: damage card "Faulty Countermeasures",
## "You cannot spend exhausted defense tokens." (RRG p.12)
class_name FaultyCountermeasures
extends RefCounted

const RULE_ID := "damage_card.faulty_countermeasures"

static func register() -> void:
    RuleRegistry.register_rule(RULE_ID, [
        FlowHook.new(
            flow_id    = Constants.InteractionFlow.SHIP_ATTACK,
            step_id    = Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
            kind       = FlowHook.Kind.VALIDATOR,
            priority   = 100,
            applies_to = "spend_defense_token",
            predicate  = Callable(FaultyCountermeasures, "_validate_spend")),
    ])

## Returns {"allowed": bool, "reason": String}.
static func _validate_spend(state: GameState, cmd: GameCommand) -> Dictionary:
    var defender: ShipInstance = _resolve_defender(state)
    if defender == null or not _has_card(defender):
        return {"allowed": true, "reason": ""}
    var token_idx: int = cmd.payload.get("token_index", -1)
    if token_idx < 0:
        return {"allowed": true, "reason": ""}
    if defender.defense_tokens[token_idx].state == \
            Constants.DefenseTokenState.EXHAUSTED:
        return {"allowed": false,
                "reason": "Faulty Countermeasures: cannot spend exhausted tokens."}
    return {"allowed": true, "reason": ""}
```

Rule registration entry point (`autoload/rule_bootstrap.gd`) does
nothing but call every rule's static `register()`. Adding a new card
adds one entry to that file plus one file under
`src/core/effects/rules/`.

### 3.4 How this collapses mode divergence

Hot-seat and network become *byte-identical* on the modal-lifecycle
path:

```
GameCommand.execute() writes interaction_flow into GameState
       │
       ▼
EventBus.command_executed (both peers, both modes)
       │
       ▼
UIProjector.project(state, local_player) consults FlowSpec
       │     for { controller_role, modals, allowed_commands }
       ▼
ModalRouter opens / closes / mirrors / sets-interactable
       │     based purely on UIIntent — no mode branches
       ▼
Player input emits a command → CommandSubmitter → loop
```

The only remaining mode-aware code is at autoload boundaries:
- `PlayMode.is_network()` to choose the submitter strategy.
- `PlayMode.seat_controls_camera()` (Phase K1) for camera ownership.
- `NetworkManager.is_server()` for command-result broadcast.

None of these touch modal lifecycle, rule application, or interaction-flow
mutation.

---

## 4. Phase L — Hot-Seat Modal Unification

> Phase L makes hot-seat use the same modal-lifecycle pipeline as
> network. It is a prerequisite for Phase M; FlowSpec/RuleRegistry on
> top of two diverging lifecycles would only entrench the divergence.

### 4.1 Slice plan

> Post-K8/K10/K11/K12/K13 the modal-open call sites moved out of
> [game_board.gd](../src/scenes/game_board/game_board.gd) (now 1 464 LOC,
> under the K-G2 target of 2 000) into focused controllers. The slice
> targets below reference the *current* owners (file + symbol), not the
> historical `game_board.gd:NNNN` line numbers the 2026-05-10 draft used.
> The lint allow-list currently reports **11 sites**; the L target floor
> is **≤ 4**.

| Slice | Scope | Risk | LOC delta | MT? |
|------:|---|---|---:|:---:|
| **L0** | Audit snapshot. Inventory every direct-callback modal open/close in `src/scenes/game_board/` and `src/ui/` (start from the lint allow-list as the seed). Catalogue each as one of: lifecycle (must migrate), affordance (sequence button etc., needs a network-side equivalent or explicit suppression), or pure local UX (tooltip, banner — out of scope). Outcome: append `docs/modal_classification.md` §L-Inventory with line-cited table covering at minimum [`ship_activation_controller.gd`](../src/scenes/game_board/ship_activation_controller.gd) (activation + sequence-button), [`displacement_controller.gd`](../src/scenes/game_board/displacement_controller.gd) (`start()`), [`command_router_adapter.gd`](../src/scenes/game_board/command_router_adapter.gd) (current network projection routes), and the `_on_active_player_changed` content fork in [`game_board.gd`](../src/scenes/game_board/game_board.gd). **No code changes.** | trivial | 0 | no |
| **L0.5** | **Baseline trace harness.** Reuse the existing `saves/annotations/` system as the oracle backbone: annotations already capture `(seq, command_type, flow.flow_type, flow.step_id, flow.controller_player)` per `command_executed`. Add a tiny logging-mode-gated subscriber under [`src/autoload/`](../src/autoload/) that, given the same scenario, writes a canonicalised JSONL projection of those fields to `PathConfig.LOGS_DIR/baseline_trace_<mode>_<role>.jsonl`. Run a fixed scenario (Learning Scenario rounds 1–2) in hot-seat, network host, and network client; commit the three traces under `tests/fixtures/baseline_traces/` as the regression oracle for L1–L5. New unit test `test_baseline_trace_format.gd` validates the JSONL schema. Each L slice ends by re-running the scenario and `diff`-ing against the oracle; non-trivial divergence blocks the slice. **No production code paths change.** | low | +120 / 0 | no |
| **L1** | Introduce `ModalRouter` ([`src/scenes/game_board/modal_router.gd`](../src/scenes/game_board/modal_router.gd), Node). Single subscriber to `EventBus.command_executed` that calls `UIProjector.project()` and dispatches to modal controllers via a typed `UIIntent`. Extract the network-side dispatch currently living in [`command_router_adapter.gd`](../src/scenes/game_board/command_router_adapter.gd) into the new router (the adapter becomes the network composition root). Hot-seat path still uses direct callbacks at this slice — `ModalRouter` runs in both modes but only network exercises its dispatch surface today. | medium | +250 / 0 | yes |
| **L2** | Migrate **Activation modal** lifecycle to projection in hot-seat. Producer side: the dial-drop / activation entry stops calling `ShipActivationController.configure_and_open_activation_modal()` directly; instead the responsible `GameCommand.execute()` writes the `SHIP_ACTIVATION` step into `interaction_flow`, and `ModalRouter` opens the modal. Defect-anchor: closes the same source-of-truth class as bug 1 (activation-modal stale snapshot, `c673ef0`) — the projector recomputes `is_attack_skippable` on every command so the cached-callable workaround can later be removed. Removes the §3.1a `_on_command_executed_project_ui` modal-lifecycle dispatcher allow-list site in [`game_board.gd`](../src/scenes/game_board/game_board.gd). | high | +50 / −80 | yes |
| **L3** | Migrate **Squadron-command activation modal** lifecycle (sequence button + squadron command modal) to projection. The hot-seat-only "sequence button" affordance becomes an `ENABLER` hook surfaced through `UIIntent.affordances`. Removes the §3.1a sequence-button-origin allow-list site (now owned by `ShipActivationController._show_activation_sequence_button`). | high | +60 / −80 | yes |
| **L4** | Migrate **Displacement modal** lifecycle to projection in hot-seat. [`displacement_controller.gd`](../src/scenes/game_board/displacement_controller.gd) `start()` becomes an effect of `SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE`, opened by `ModalRouter`. Defect-anchor: closes the same source-of-truth class as bug 4 (`c673ef0`, RRG "Overlapping", p.8): once both modes consume `interaction_flow.controller_player`, no producer can derive it ad-hoc — `controller_player = 1 - maneuver_ship.owner_player` becomes the only path. Removes the §3.1a displacement-modal-origin allow-list site. | medium | +40 / −60 | yes |
| **L5** | Migrate **`_on_active_player_changed` content fork** (the line-889 dispatcher in [`game_board.gd`](../src/scenes/game_board/game_board.gd), `_dispatch_active_player_change_dispatcher` after K13) to a single path: build the same overlay objects on both modes, then style them via `UIIntent` (`needs_handoff_overlay` vs. `needs_waiting_overlay`). Removes the last big lifecycle allow-list branch. | high | +70 / −110 | yes |
| **L6** | Lint tightening: update `scripts/lint_phase_k.sh` allow-list from the current **11** sites to the post-L floor of **≤ 4** (save dialog, load dialog ×2, lobby room). Update [.github/copilot-instructions.md](../.github/copilot-instructions.md) §7 Phase K bullet to document the new floor and reword the (Phase I) negative rules as enduring constraints. | low | +10 / −30 | no |
| **L7** | Manual-test sweep: hot-seat full-game playthrough (round 1 + round 2) with every modal lifecycle observed. Same playthrough on network host + client. Compare logs side-by-side: every modal open/close should be triggered by the *same* `command_executed` sequence with the *same* projector intent on both peers and both modes. Augment with the annotation-system diff for the displacement, activation-attack-skip, and brace cases (the three lifecycle-anchored defects from `c673ef0`) so the L migration is regression-tested against the bugs that motivated it. | trivial (test only) | 0 | yes |

### 4.1a L0.5 trace-regeneration automation (proposal — REVISED v2)

**Status:** proposal — awaiting approval. Implements real two-process
network replay because debugging network behaviour has been the
single biggest cost source so far; the regression gate must cover
network mode end-to-end.

**Goal.** A single shell command that:
  1. Boots Learning Scenario rounds 1–2 deterministically in
     hot-seat **and** in network (host + client),
  2. Drives every command through the real production pipeline
     (validation, networking, broadcast, command-executed signal),
  3. Writes one `baseline_trace_<mode>_<role>.jsonl` per peer,
  4. Diffs each trace against the committed fixture and reports
     non-trivial divergence with the offending `(seq, step_id)` row.

**Why this is feasible.** Investigation of the existing
infrastructure shows the network plumbing is already complete:

  - [`scripts/run_network_test.sh`](../scripts/run_network_test.sh)
    already orchestrates a localhost server + 1 or 2 clients with
    `--logging` and `--port` flags. Process lifecycle, port
    management, and cleanup are solved.
  - [`server_main.gd`](../src/autoload/server_main.gd) already
    accepts `--server --port <n> --scenario <id>` and auto-hosts via
    `NetworkManager.host()` at boot. The headless server path is a
    production code path, not test scaffolding.
  - `TestNetworkHarness` already exists for in-process peer fakes,
    used by `test_network_transport.gd`.
  - `GameReplay` serialises every command with its authoring
    `player_index` already, so a peer can self-filter to "play only
    my own commands" without extra metadata.

The missing piece is a deterministic *input driver* that consumes a
replay file and submits each command at the right moment from the
right peer. That is the only new production-adjacent code this
slice adds.

#### 4.1a.1 Design

##### CLI surface

```
# Hot-seat (single process):
godot --headless --replay <path> --baseline-output <jsonl>

# Network (orchestrated by run_baseline_traces.sh):
godot --headless --server --port 7350 --replay <path> \
      --baseline-output <jsonl>
godot --headless --connect 127.0.0.1:7350 --replay <path> \
      --baseline-output <jsonl>  # client peer
```

`--replay`, `--connect`, and `--baseline-output` are new flags
parsed in a small `ReplayDriver` autoload (new file:
[`src/autoload/replay_driver.gd`](../src/autoload/replay_driver.gd)).

##### `ReplayDriver` autoload — production code, opt-in

  - Inert when `--replay` is absent (every non-driver session,
    including all hand-played games, sees zero behaviour change).
  - When present:
      1. Loads + verifies the replay file (`GameReplay.load_from_file`
         already exists; HMAC check reused).
      2. Forces `LoggingMode.enabled = true` and calls
         `BaselineTrace._maybe_enable()`.
      3. Subscribes to `EventBus.game_started`. On signal, kicks the
         step loop.
      4. **Step loop** (one tick per `process_frame`):
         - Look at the next replay command not yet applied.
         - Decide whether to submit it from this peer:
            - **Hot-seat**: always submit (every command is local).
            - **Network**: submit iff
              `command.player_index ==
               NetworkManager.get_local_player_index()`. The other
              peer's commands arrive via the real broadcast pipeline
              and are observed by the same loop (driver waits for
              `command_executed` with the expected `sequence` before
              advancing).
         - After submit, wait for `CommandProcessor.command_executed`
           to fire with the expected `sequence`. This is the natural
           sync barrier — both peers reach the same flow state
           before either submits its next command.
         - Hard timeout per command (5 s default, configurable via
           `--replay-step-timeout`): if no `command_executed` arrives,
           emit a structured error and exit non-zero.
      5. On last command applied, flush `BaselineTrace`, exit 0.

  - Defensive: refuses to submit any command whose
    `player_index` does not match the local peer in network mode
    (the broadcast pipeline would reject it anyway, but failing fast
    in the driver gives a clear error).

##### `BaselineTrace` — already in place

Already writes per-peer `baseline_trace_<mode>_<role>.jsonl` to
`PathConfig.LOGS_DIR`. No changes needed.

##### Orchestration script

`scripts/run_baseline_traces.sh` — new shell script. Modelled on
[`run_network_test.sh`](../scripts/run_network_test.sh). For each
fixture:
  1. Hot-seat: launch one Godot process with `--replay
     hot_seat_solo.json --baseline-output <tmp>/hot_seat_solo.jsonl`.
     Wait for exit. `diff` against fixture.
  2. Network: launch headless server (`--server --replay
     network_host.json --baseline-output <tmp>/network_host.jsonl`)
     and headless client (`--connect 127.0.0.1:7350 --replay
     network_client.json --baseline-output
     <tmp>/network_client.jsonl`). Wait for both to exit. `diff`
     each against its fixture.
  3. Exit 0 if all diffs are empty; print unified diff and exit 1
     otherwise.

##### GUT integration test

`tests/integration/test_baseline_trace_regression.gd` — runs the
**hot-seat** path in-process (single GUT process can't spawn ENet
sessions reliably). Network path stays a shell-script gate run
locally and (later) in CI.

#### 4.1a.2 The two fundamental network challenges, addressed

**Challenge A — separate replay file per peer.**

In hot-seat one process originates every command, so one replay
file covers it. In network, the host originates only its own
commands; the client originates its own. *But* the existing
`GameReplay.serialize()` records the full sequence from the
**server**'s history (commands are funnelled through the server in
G4 design — see
[`src/utils/path_config.gd`](../src/utils/path_config.gd) and the
G4 plan in `docs/old/g4_network_plan.md`). So the same replay file
works for both peers: each one filters by `player_index` to decide
what to submit.

This is verified empirically by the already-captured hot-seat
replay (`tests/fixtures/baseline_traces/replay_hot_seat_solo.json`)
which has `"player": 0|1` on every command — the filter key is
already there.

**Challenge B — ordering and WAIT-state divergence.**

Network mode's `WAIT_FOR_OPPONENT_DIALS` (and analogous waits)
genuinely change the post-execute flow state on each peer. That is
captured by writing **separate** fixtures per role:
`baseline_trace_network_host.jsonl` and
`baseline_trace_network_client.jsonl`. The diff is per-peer. A
host-side bug where the WAIT step is missed shows up as a diff
against the host fixture even if the client fixture is unchanged.

The sync barrier (waiting for `command_executed` with the expected
`sequence` before submitting the next own-command) ensures
deterministic ordering across peers. Without this barrier, two
client `assign_dials` could race a host `assign_dials` and produce
inconsistent traces. With it, each peer advances only after the
previous command has been globally committed.

#### 4.1a.3 Risks and mitigations

| Risk | Mitigation |
|---|---|
| `--replay` flag accidentally activated in a production user session | Flag is parsed only if explicitly passed; absent from every export preset; documented in `docs/setup_network_game.md`. `ReplayDriver._ready` early-returns when the flag is absent. |
| Network process startup race (client connects before server is listening) | Mirror `run_network_test.sh`'s existing `sleep 1` between server-spawn and client-spawn. Client retries connect for up to 5 s; if it fails, exit non-zero with a clear message. Both are already proven patterns in the existing script. |
| ENet localhost flakiness on CI | Run the shell-script gate locally before every L slice. Skip it in CI initially (only the GUT in-process hot-seat test runs in CI). Promote to CI in L7 once stability is established. |
| Per-command 5 s timeout too aggressive for some commands (e.g. squadron move animations) | The timeout measures *engine* sync, not *animation* completion — `command_executed` fires synchronously inside `CommandProcessor.submit`. Animations finish later but are not observed by the trace. 5 s is generous for engine sync. Bumpable per-test via `--replay-step-timeout`. |
| Two peers reach `game_started` at different physics frames → step loop reads stale `interaction_flow` | The sync barrier (`command_executed` with expected `sequence`) makes the loop strictly synchronous. The driver never advances on its own clock; it advances only on observed broadcast. |
| Capturing the initial network replay pair requires manual interaction (hands on keyboard for two windows) | Yes — one-time cost. From there on, all regression checks are headless. Capturing the hot-seat replay was already a one-time cost (already paid). |
| Adding a new autoload (`ReplayDriver`) violates the §6 enforcement rule? | Autoload count goes from N to N+1. The rule is "minimise autoloads"; this one is justified because `BaselineTrace` is also already an autoload and the driver must run before `EventBus.game_started`. Documented in §11 risks register. |

#### 4.1a.4 Cost summary

| Item | LOC delta | MT? |
|---|---:|:---:|
| `src/autoload/replay_driver.gd` (production opt-in driver) | +220 / 0 | no |
| Register `ReplayDriver` in `project.godot` | +1 / 0 | no |
| CLI flags `--replay`, `--connect`, `--baseline-output`, `--replay-step-timeout` | +30 / 0 | no |
| `scripts/run_baseline_traces.sh` orchestration | +120 / 0 | no |
| `tests/integration/test_baseline_trace_regression.gd` (in-process hot-seat path) | +80 / 0 | no |
| `tests/unit/test_replay_driver.gd` (filter logic, sync-barrier semantics) | +60 / 0 | no |
| **Total** | **+511 / 0** | **no** |

Lands as three commits on the L0.5 branch:

  1. `feat(observability): L0.5b ReplayDriver autoload (hot-seat
     execution)` — driver + unit tests + integration test. Hot-seat
     fully automated.
  2. `feat(observability): L0.5c network replay path` — `--connect`
     flag + `run_baseline_traces.sh` + capture initial network
     fixture pairs.
  3. `docs(plan): L0.5 automation outcome` — update §1 baseline,
     promote the GUT integration test to the post-slice
     regression-gate description in §4.1.

**Sequencing requirement: capture network fixtures once, manually,
before commit 2.** The user runs `./scripts/run_network_test.sh
--logging`, plays Learning Scenario rounds 1–2 once. The resulting
`replays/replay_*.json` is committed as `replay_network_host.json`
(the server's view contains both peers' commands), and the
two `logs/baseline_trace_network_{host,client}.jsonl` files are
committed as the per-peer fixtures. From that point on,
`run_baseline_traces.sh` regenerates them headlessly.

#### 4.1a.5 Decision points for approval

1. **Real two-process network automation is required.** (User
   indicated this is non-negotiable: "make sure it works in network
   and hot seat" / "network debugging was the biggest effort up to
   now".)
2. **`ReplayDriver` is a production autoload, opt-in via `--replay`
   CLI flag.** Inert in every non-driver session. Alternative would
   be a separate test-only entry point, which means duplicating the
   boot sequence — rejected as more fragile.
3. **Sync barrier is `command_executed` per expected `sequence`.**
   Alternative would be wall-clock pacing, which would be flaky on
   loaded CI. Rejected.
4. **Network fixtures captured manually once.** Alternative is a
   bootstrap mode that records as it goes, which is more code for
   a one-time event. Rejected.
5. **Shell-script gate runs locally; CI runs the hot-seat GUT
   integration test only.** Promote network to CI in L7 once
   stability is observed.

If any of 1–5 is rejected, name the variant and I revise. Otherwise
I implement in the three commits above.

### 4.2 Acceptance criteria for closing Phase L

1. `bash scripts/lint_phase_k.sh` shows ≤ 4 allow-listed sites, none of them in `src/scenes/game_board/` for modal lifecycle (down from the current 11).
2. A `match`-style audit of the modal-open call sites shows each modal type opens through `ModalRouter` exclusively, with no direct calls remaining.
3. Test baseline: ≥ 144 scripts / ≥ 2 917 tests / 0 failures (current baseline preserved or grown).
4. Manual test L7 confirms identical modal lifecycle traces between hot-seat and network, including regression coverage for `c673ef0`'s three lifecycle-anchored defects (displacement controller, activation-modal stale snapshot, brace canonical sort).

---

## 5. Phase M — Flow Authority and Rule Registry

> Phase M sits on top of L. It introduces FlowSpec as the canonical
> step registry and RuleRegistry as the rule-extension surface, then
> migrates a representative slice of existing rules.

### 5.1 Slice plan

| Slice | Scope | Risk | LOC delta | MT? |
|------:|---|---|---:|:---:|
| **M0** | Author the **natural-language master document** [docs/game_flow.md](game_flow.md). One block per `(flow_id, step_id)` pair currently emitted by `interaction_flow`. Each block: controller role, allowed commands, visible modals, citations, transitions. Use the inventory from L0 + the existing `tests/unit/test_ui_projector.gd` cases as ground truth. **No code changes.** | low | +0 (docs) | no |
| **M0.5** | **Model-fitness review.** With `docs/game_flow.md` complete, do a deliberate reread asking three questions per (flow, step) block: (a) does `InteractionFlow.flow_type / step_id / controller_player / payload` carry every piece of information the prose requires? (b) are any two prose blocks describing what is logically the same step under different names (model duplication)? (c) does any prose block describe behaviour the current `GameCommand` set cannot express? Outcome: a short `docs/game_flow.md` §0 "Model fitness" subsection with the answers. If all three are clean (expected), proceed to M1. If any answer reveals a genuine model defect, stop and convert that defect into a separate, scoped slice before M1 — do **not** absorb model changes into M1's spec encoding. **Worked example to include in the review (do not skip):** the 2026-05-11 displacement bug (`c673ef0`) — RRG "Overlapping", p.8: *"the player who is NOT moving the ship places the overlapped squadrons, regardless of who owns them."* The producer in [`start_displacement_command.gd`](../src/core/commands/start_displacement_command.gd) had to invent `controller_player = 1 - maneuver_ship.owner_player` because no central declaration pinned that mapping. M0.5 confirms that `controller_role` is a *first-class column* of every FlowSpec entry (with enum values `ACTIVE_PLAYER`, `OPPOSING_PLAYER`, `DEFENDER`, `ATTACKER`, …) so M1's `_SPEC` table makes the bug syntactically unrepresentable. **No code changes.** | trivial | +0 (docs) | no |
| **M1** | Add [src/core/state/flow_spec.gd](../src/core/state/flow_spec.gd) (RefCounted) with a frozen `_SPEC` table that translates `docs/game_flow.md` into machine form. Add `tests/unit/test_flow_spec.gd`: every `(flow_id, step_id)` produced by any test in `tests/unit/test_ui_projector.gd` must be present in `_SPEC`. | low | +200 / 0 | no |
| **M2** | Wire `UIProjector.project()` to consult `FlowSpec.get_spec(...)` for `controller_role` and `modals`. Today's hard-coded modal mapping in `UIProjector` becomes a lookup. Identical output asserted by `test_ui_projector.gd` (no test changes expected). | medium | +80 / −120 | yes |
| **M3** | **Parity gate I:** add a unit test that, for every command type currently registered with `GameCommand.register_type(...)`, asserts a static `applicable_steps()` declaration exists. Fail with a clear error listing missing commands. Then add the declarations command-by-command in this slice. No behaviour change yet. | low | +120 / 0 | no |
| **M4** | **Parity gate II:** `CommandProcessor.submit()` consults `FlowSpec.allowed_commands(state.flow, state.step)` before calling `cmd.validate()`. Mismatch → reject with a structured `{allowed: false, reason: "command X not allowed in step Y"}`. Run replay suite + manual test to catch missed declarations from M3. | medium | +30 / 0 | yes |
| **M5** | Add [src/core/effects/rule_registry.gd](../src/core/effects/rule_registry.gd) and [src/core/effects/flow_hook.gd](../src/core/effects/flow_hook.gd). Add `autoload/rule_bootstrap.gd` that calls every registered rule's static `register()`. **Empty registry** at this slice — registry behaves identically to today. Test: `RuleRegistry.validators_for(...)` returns `[]` for every step until rules migrate. | low | +180 / 0 | no |
| **M6** | `CommandProcessor.preflight()`: after FlowSpec allow-list passes, run `RuleRegistry.validators_for(flow, step, cmd.command_type)` in priority order; first denial wins. `AttackResolver.modify_dice_pool()`: consult `RuleRegistry.modifiers_for(flow, step, "dice_pool")`. `CommandProcessor.notify_observers()`: after execute, call `RuleRegistry.observers_for(...)`. **Empty registry** keeps behaviour identical. | medium | +120 / 0 | no |
| **M7** | Migrate **rule 1: Faulty Countermeasures** (defense-token spend validator). Single file, single VALIDATOR hook. Existing logic in `AttackExecutor` removed. Test: `tests/unit/test_rule_faulty_countermeasures.gd`. | low | +90 / −40 | yes |
| **M8** | Migrate **rule 2: Compartment Fire** (defense-token ready blocker in Status Phase). Demonstrates a STATUS-phase MODIFIER + multi-flow registration in one file. | low | +90 / −40 | yes |
| **M9** | Migrate **rule 3: Damaged Munitions** (attack-pool dice removal modifier). Demonstrates an `ATTACK_ROLL` MODIFIER hook. | low | +90 / −40 | yes |
| **M10** | Migrate **rule 4: Point-Defense Failure** (squadron-attack-only modifier). Demonstrates a flow-conditional predicate. | low | +90 / −40 | yes |
| **M11** | Migrate **rule 5: Crew Panic** (BEFORE_REVEAL_DIAL choice modal as ENABLER). Demonstrates surfacing optional UI affordances through `UIIntent.affordances` populated by ENABLER hooks. | medium | +120 / −80 | yes |
| **M12** | Migrate **rule 6: Capacitor Failure** (no shields → no recover, no redirect). Demonstrates a multi-hook rule: VALIDATOR on `recover_shields`, BLOCKER on redirect step. Documents the "one rule, multiple hooks" pattern. | medium | +110 / −60 | yes |
| **M13** | **Determinism guard:** add `tests/integration/test_rule_order_replay.gd`. Run a replay scenario that triggers ≥ 3 hooks in the same step on both peers (host + client harness), serialise hook execution order, assert byte-identical sequences. | low | +120 / 0 | no |
| **M14** | **Coverage tool:** `scripts/dump_flow_coverage.gd` — given a `(flow, step)`, prints all FlowSpec metadata + every registered rule. Used as a debugging aid; runs in `--headless`. | low | +80 / 0 | no |
| **M15** | Update `docs/implementation_plan.md` §1 baseline + §2 phase status + §4 open topics. Update [.github/copilot-instructions.md](../.github/copilot-instructions.md) "Non-Negotiable Rules" with rule §12 "New rules go through `RuleRegistry`". Update `.skills/architecture_patterns.md` with a Layer-3 (rules) section. | trivial | +0 (docs) | no |

### 5.2 Acceptance criteria for closing Phase M

1. `tests/unit/test_flow_spec.gd` covers 100% of `(flow_id, step_id)` pairs that appear in `tests/unit/test_ui_projector.gd`. New pair → CI fails.
2. Every `GameCommand` subclass declares `applicable_steps()`. Static parity test enforces this.
3. `CommandProcessor.submit()` rejects a command whose declared steps don't include the current step. Tested.
4. `RuleRegistry` contains the 6 migrated rules. Adding a 7th is reproducibly a one-file change (write rule + add to bootstrap list).
5. Determinism replay test green.
6. Test baseline: ≥ 144 scripts, all green; `bash scripts/lint_phase_k.sh` exits 0.

---

## 6. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| L2/L3/L5 hot-seat modal migration breaks observable UX (timing, animations) | Medium | High | Each slice gated by manual test L7-style comparison. Incremental: one modal type at a time. Snapshot test of `UIIntent` per scenario step keeps regressions tight. |
| Hot-seat affordances (sequence button) don't have a clean network equivalent | Medium | Medium | L3 explicitly migrates affordances through `UIIntent.affordances`. If a true asymmetry remains, document it as an `affordance_kind` value with a clear semantic, not a `PlayMode` branch. |
| FlowSpec entries drift from runtime (someone adds a step without updating the spec) | Medium | High | M1 parity test fails CI on unknown pairs. M3/M4 parity tests fail on unknown commands. Two safety nets. |
| Rule self-registration ordering causes peer divergence | Low | Critical | M5 + M13 enforce sort order `(priority DESC, rule_id ASC)` and a determinism replay test. Static rule list — no dynamic registration after autoload. |
| Existing keyword effects break during M7–M12 migration | Medium | High | One rule per slice; existing tests retained; new test added for migrated rule. Old in-resolver code removed only after the new path is proven by the new test. |
| Save format break | Low | Critical | `interaction_flow` JSON shape unchanged; FlowSpec is computed-only; RuleRegistry hooks reference `step_id` which is already serialised. Pin save format version. |
| Replay break | Low | Critical | Replay determinism gated by M13. Run full replay corpus in CI on every M slice. |
| Scope creep ("while we're at it, let's redesign…") | High | Medium | Slice list is fixed. Every additional change must land as a separate phase (Phase N candidate). |
| Stale line/LOC references inside this plan (drafted 2026-05-10 against `game_board.gd` \u2248 3 055 LOC; file is now 1 464 LOC after K8/K10/K11/K12/K13) | Medium | Low | L0 re-derives every coordinate when writing the `modal_classification.md` \u00a7L-Inventory. Treat the \u00a74.1 slice descriptions as role-based (file + symbol + lint-allow-list entry), never as `:NNNN` line addresses. |
| New producer adds a `controller_player` ad-hoc instead of consulting FlowSpec (the 2026-05-11 displacement defect class) | Medium | High | M0.5 lands `FlowSpec.controller_role(flow_id, step_id) \u2192 ControllerRole` and a parity test that fails CI when any `GameCommand.execute()` writes `interaction_flow.controller_player` without going through the spec. Worked example pinned in \u00a75.1 M0/M0.5. |

---

## 7. How this aligns with existing plans

### 7.1 Phase K dependency (narrow)

Phase L does **not** require all of Phase K to be finished. §3.1d is
the *deferred* modal-lifecycle item — Phase K explicitly does not
address it; Phase L does. So "K closure" is the wrong gate.

What Phase L actually needs from K:

1. **K12 (`CommandRouterAdapter`) committed.** ✅ Done (`e17ff05`) — this is
   the single `EventBus.command_executed → UIProjector.project`
   subscription point that L1's `ModalRouter` extends.
2. **K7 lint script in place and green.** ✅ Done — `scripts/lint_phase_k.sh`
   currently reports `0 violations (11 allow-listed branches)`. L tightens
   the allow-list; it cannot tighten what does not exist.
3. **K14 (`AttackFlowExecutor`) committed.** ✅ Done (K14a `454fd0e` →
   K14g `33e697f`). Pure attack-flow payload construction, defense-commit
   canonical ordering, faceup/immediate-effect decision, and
   redirect-continuation now live in [`src/core/combat/attack_flow_executor.gd`](../src/core/combat/attack_flow_executor.gd)
   with isolated unit coverage in [`tests/unit/test_attack_flow_executor.gd`](../tests/unit/test_attack_flow_executor.gd).

Slices K15–K19 are **orthogonal** to Phase L's modal-lifecycle scope:

| Slice | Scope | Current size | Overlaps with L? |
|---|---|---:|:---:|
| K15 | `attack_executor.gd` function-size / nesting cleanup | 2 385 LOC | No |
| K16 | Extract `NetworkPhaseSync` from `game_manager.gd` | 2 272 LOC | No |
| K17 | Extract `GameCommandSubmitterRouter` from `game_manager.gd` | (with K16) | No |
| K18 | Extract `CheckpointStore` + `SaveGameSerializer` from `save_game_manager.gd` | 1 061 LOC | No |
| K19 | Lint finalisation + arc42 component diagram | docs only | No |

Post-K snapshot (2026-05-11) used as the L starting point:

| File | LOC | K target | Status |
|---|---:|---:|:---:|
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1 464 | ≤ 2 000 | ✅ under |
| [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) | 2 385 | ≤ 1 500 | ⏳ K15 |
| [game_manager.gd](../src/autoload/game_manager.gd) | 2 272 | ≤ 1 500 | ⏳ K16/K17 |
| [save_game_manager.gd](../src/autoload/save_game_manager.gd) | 1 061 | (K18 split) | ⏳ K18 |
| [command_router_adapter.gd](../src/scenes/game_board/command_router_adapter.gd) | 269 | new | ✅ |
| [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | 1 393 | new | ✅ |

These may **interleave with Phase L slices**. Recommended order:

1. K14 done ✅ — L is now unblocked on the modal-lifecycle side.
2. Start L0 (audit, no code) — can run in parallel with K15/K16.
3. L1 lands as the next code-bearing commit on the L track.
4. K16/K17/K18 may slot between L slices opportunistically; they touch
   autoload-internal code that L does not restructure.
5. K19 + L6 (lint tightening) can be paired as one finalisation commit
   when both phases reach their lint floor.

The hard sequencing constraint is just: **don't change the modal-lifecycle
contract while K is still moving the surrounding scaffolding.** K14 was
the last K slice that did that; K15–K19 are internal to controllers /
autoloads and don't touch the lifecycle path.

### 7.2 Phase G4 unblocking

Phases G4.7 (Spectator), G4.8 (Reconnection runtime), and G4.9 (Turn
Timers) are currently gated on Phase K. They become *easier* on top of
L+M because:

- **Spectator** is a third "viewer" with no controller role. With
  FlowSpec describing controller resolution, spectator is just
  `local_player == -2` and `controller_role` never matches. No new
  branches.
- **Reconnection** acceptance test (Phase I7) already runs as a pure
  function chain. M2 makes `UIProjector.project()` consult FlowSpec,
  which strengthens the reconnection contract: any step a peer
  reconnects into is renderable iff `FlowSpec.get_spec(...)` returns
  non-empty. CI fails on missing pairs.
- **Turn Timers** are a `BLOCKER` hook on every step that has a
  controller — perfect fit for Layer 3 without touching Layer 1 or 2.

### 7.3 Phase J save subsystem

`SaveGameMetadata` and per-mode checkpoints (J5.5) keep working
unchanged. `interaction_flow` is the only piece of UI state in saves;
it stays. `RuleRegistry` is computed-only, never serialised.

### 7.4 Mode-divergence audit

After Phase L closes, the only mode-aware lines outside `src/autoload/`
are:

- 4 allow-listed deployment-mode dispatchers (save dialogs, lobby).
- `ModalRouter` consulting `PlayMode.seat_controls_camera()` for
  per-modal camera behaviour.

After Phase M closes, every gameplay-rule decision is in the registry,
discoverable in seconds, and tested in isolation. Adding a new card is
a single-file change.

---

## 8. Quick-start guide for executing this plan

### Before starting Phase L

1. Confirm K12 (`e17ff05`) + K14g (`33e697f`) committed and
   `bash scripts/lint_phase_k.sh` exits `0`. ✅ verified 2026-05-11.
   (K15–K19 may still be open — they do not block L; see §7.1.)
2. Confirm GUT baseline (144 / 2 917 / 5 521 / 0). ✅ verified 2026-05-11.
3. Pull a clean branch `phase-l/audit`.
4. Write the L0 audit (no code). Seed it from the current 11-site lint
   allow-list and the [`docs/modal_classification.md`](modal_classification.md)
   inventory.
5. Get user sign-off on the audit before L1.

### During each Phase L/M slice

1. Implement the slice in a tight commit.
2. Run:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
   bash scripts/lint_phase_k.sh
   ```
3. Confirm: 0 failures, baseline scripts present, lint = 0 violations.
4. Run the slice's manual test if marked `MT? = yes`.
5. Update `docs/implementation_plan.md` §1 baseline + §2 status.
6. Commit with conventional-commit message (`refactor(flow):` or `feat(rule):`).

### Closing Phase L

1. All L acceptance criteria met (§4.2).
2. Update `.github/copilot-instructions.md` § "Non-Negotiable Rules" with the new lint floor.
3. Archive this section's L slices into `docs/old/refactoring_phase_l_plan.md`.

### Closing Phase M

1. All M acceptance criteria met (§5.2).
2. Add rule §12 "New rules go through `RuleRegistry`" to `.github/copilot-instructions.md`.
3. Add a §3 (Layer 3 — Rules) block to `.skills/architecture_patterns.md`.
4. Archive M slices into `docs/old/refactoring_phase_m_plan.md`.
5. Resume G4.7.

---

## 9. What this plan does NOT promise

- It does not eliminate every bug. Bugs *inside* a rule (wrong
  predicate, wrong priority) are still possible. The plan's promise is
  that *those bugs are local to one file and one test*.
- It does not improve performance. The hook lookup is O(rules-at-step),
  trivially fast for this domain.
- It does not change the player-visible game. Only the internal
  pathways change.
- It does not lock the rule format forever. If a future rule needs a
  hook kind not in §3.3, add it to `FlowHook.Kind` — that is a
  deliberate, reviewed change.

---

## 10. Final assessment

The proposed approach matches the actual shape of the problem domain:

1. The **flow skeleton is stable** (Star Wars Armada rules-reference defined). FlowSpec + Layer 1 doc captures it once, enforces it forever.
2. The **rule set is open-ended** (every card is potentially a rule). Self-registration through RuleRegistry isolates each rule to one file.
3. The **divergence between hot-seat and network is structural, not accidental**. Phase L removes the structural difference; Phase M removes the implicit-rule-placement that hides bugs in both modes.
4. The **2026-05-11 bug-batch (`c673ef0`) confirmed the symptoms predicted by §0** — three out of four defects were *source-of-truth* failures (displacement `controller_player`, activation-modal stale snapshot, brace canonical-sort drift), not logic failures. The LM design eliminates the structural cause of all three.

This plan is *bounded* (concrete slice list, concrete LOC budget,
concrete acceptance gates), *aligned* (Phase K go-conditions met as of
2026-05-11, unblocks G4.7+), and *minimally invasive* (no save format
break, no new RPC, no new EventBus channel, no replacement of existing
primitives).

**Verdict: safe to begin Phase L now.** L0 (audit) can start immediately;
L1 (the first code-bearing slice) can start whenever the audit is
approved. Slices K15–K19 may proceed in parallel and do not block L.

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

### 4.1a L0.5 trace-regeneration automation (proposal — REVISED)

**Status:** proposal — awaiting approval. Lands as commits on the L0.5
slice before L1 starts.

**Goal.** Make the `tests/fixtures/baseline_traces/` oracle regenerable
without a 20-minute manual playthrough per L slice. Manual MT for
L1–L7 still happens (per `.skills/copilot_instructions.md`); this is
the **fast pre-MT check** that catches obvious regressions in seconds.

**Honest scope: traces are mode-dependent.** Empirical confirmation
from the committed hot-seat fixture: during dial assignment
(seq 1–3) `flow_step_id = NONE` because hot-seat players take turns.
In network mode the same `assign_dials` commands would post-execute
with `flow_step_id = WAIT_FOR_OPPONENT_DIALS` because peers genuinely
wait on each other. The `interaction_flow` projection therefore
differs by mode, and a single-process replay with a `PlayMode` flag
flip cannot reproduce the network trace faithfully.

This forces a two-tier design.

#### Tier 1 — hot-seat replay automation (this slice, ~150 LOC)

Implementable today, deterministic, runs in a GUT integration test.

**Pieces:**

1. **`CommandProcessor.replay_commands(commands, emit_signals: bool =
   false)`** — new optional parameter. When `true` the existing
   `if not is_replaying` guard around `command_executed.emit` is
   bypassed (only the *replay* path opts in; the *save-load* path
   continues to suppress). Default `false` keeps every existing call
   site unchanged.

2. **`scripts/replay_to_trace.gd`** — headless Godot CLI. Flags:
   `--replay <path> --output <trace.jsonl>`. Always runs in
   `PlayMode.HOT_SEAT`. Sequence:
     1. Boot the scenario named in the replay header.
     2. Force `LoggingMode.enabled = true`; call
        `BaselineTrace._maybe_enable()` so the trace file opens at
        `<output>`.
     3. `CommandProcessor.replay_commands(replay.commands,
        emit_signals=true)`.
     4. Flush, exit 0.

3. **`tests/integration/test_baseline_trace_regression.gd`** — GUT
   integration test. Loads
   [`replay_hot_seat_solo.json`](../tests/fixtures/baseline_traces/replay_hot_seat_solo.json),
   runs the same mechanism in-process against a temp trace file,
   diffs against
   [`baseline_trace_hot_seat_solo.jsonl`](../tests/fixtures/baseline_traces/baseline_trace_hot_seat_solo.jsonl).
   Failure message includes the offending `(seq, step_id)` row.

**What Tier 1 actually catches.** Most L-phase regressions are
modal-lifecycle bugs that surface identically in both modes (e.g.
wrong `controller_player`, missing `flow_type` transition, modal
opened twice). These all show up in the hot-seat trace. So Tier 1 is
a high-signal cheap regression gate even though it does not exercise
the network path.

**What Tier 1 does NOT catch.**

  - WAIT-state divergences specific to network mode.
  - Authority-check bugs that only fire when `NetworkManager.is_host()`
    returns true.
  - Replication-timing bugs (e.g. `commit_displacement` arriving after
    a follow-up `advance_activation_step`, like the I6b-4d fix in
    commit `2935336`).

These remain covered by manual MT during L1–L7, which is already
required by the slice plan.

#### Tier 2 — network replay automation (deferred, ~300 LOC if needed)

Not part of this proposal. Sketched here so its absence is explicit.

A real network regression check requires either:

  (a) Two headless Godot processes wired together via the existing
      ENet transport, both with `--logging`, driven by a shared
      shell script that ensures deterministic input timing. Each
      process produces its own trace; both are diffed.

  (b) An in-process two-`SceneTree` harness using
      `MultiplayerAPI.multiplayer_peer = OfflineMultiplayerPeer.new()`
      style fakes that capture the RPC send/receive boundary. Same
      output: two trace streams, two diffs.

Either is substantial (process orchestration, port management, flake
mitigation) and not justified until a network-only regression
escapes Tier 1 + manual MT. **Deferred to Phase M or beyond.**

#### Network coverage during Phase L

  - **Tier 1 runs on every L slice** as a pre-MT gate.
  - **Manual MT continues to be required** for L1, L2, L4, L5, L7
    (the slices flagged `MT? yes` in §4.1). Each MT explicitly
    includes a hot-seat run AND a network host+client run.
  - **L7 final sweep** captures fresh `replay_network_host.json` +
    `baseline_trace_network_host.jsonl` (and the client counterparts)
    and commits them as evidence-only fixtures alongside the
    automated hot-seat oracle. These four files document the
    post-Phase-L network behaviour as a regression baseline for
    Phase M, even though no automated diff runs against them yet.

#### Cost summary

| Item | LOC delta | MT? |
|---|---:|:---:|
| `CommandProcessor` parameter | +5 / 0 | no |
| `scripts/replay_to_trace.gd` | +80 / 0 | no |
| `tests/integration/test_baseline_trace_regression.gd` | +60 / 0 | no |
| Subscriber-safety audit (verify no production subscriber misbehaves when `command_executed` emits during replay) | +0 / 0 (analysis) | no |
| **Tier 1 total** | **+145 / 0** | **no** |

Lands as commit `feat(observability): L0.5b replay-to-trace
automation (hot-seat tier)`.

#### Decision points for approval

1. **Two-tier scope is acceptable** — automating only hot-seat now,
   keeping network as manual MT until/unless escapes happen.
2. **Tier 1 mechanism is acceptable** — adding the `emit_signals`
   parameter to `replay_commands` rather than (a) bypassing
   validation or (b) building a separate replay path.
3. **L7 produces evidence-only network fixtures** — committed but
   not diffed automatically.

If 1 is rejected (you want network automation now), the slice
expands to Tier 2 (~+450 LOC total, MT yes, defer L1 by one slice).
If 2 or 3 is rejected, name the variant and I revise.

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

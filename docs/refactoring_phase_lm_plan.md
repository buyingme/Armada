# Refactoring Phases L & M — Unified Flow Authority and Rule Registry

> **Status:** IN PROGRESS - 2026-05-14. L0, L0.5, and L1 are complete; L2 is the next code-bearing slice.
> **Predecessors:** Phase K is complete. The deferred hot-seat modal-lifecycle work from Phase K §3.1d is now Phase L's scope.
> **Go-conditions (verified 2026-05-14):**
>   - K12 `CommandRouterAdapter` committed (`e17ff05`).
>   - K14 `AttackFlowExecutor` complete (K14a `454fd0e` -> K14g `33e697f`).
>   - L0 audit exists in [docs/modal_classification.md](modal_classification.md) §L-Inventory.
>   - L0.5 replay gate committed (`d752ffd`): `bash scripts/run_baseline_traces.sh --all` passes hot-seat trace/hash and real network host/client state-hash equality.
>   - `bash scripts/lint_phase_k.sh` exits `0` (10 allow-listed branches after L1; the L target floor is <= 4 after L6).
>   - GUT baseline: 147 scripts / 2 936 tests / 5 571 asserts / 0 failures. Godot 4.5.1 currently aborts after the green summary with `recursive_mutex lock failed` / exit 134; track separately from test failures.
>   - No `interaction_flow` schema change pending. No save-format change pending.
> **Successor:** Resumes G4.7 (Spectator), G4.8 (Reconnection runtime), G4.9 (Turn Timers), then Phase 10c.
> **Cross-refs:** [docs/implementation_plan.md](implementation_plan.md), [docs/refactoring_phase_k_plan.md](refactoring_phase_k_plan.md) §3.1d, [.skills/serialization_and_commands.md](../.skills/serialization_and_commands.md), [.skills/architecture_patterns.md](../.skills/architecture_patterns.md).

---

## 0. Why this plan exists

Five persistent symptoms keep recurring even after Phases A-K. The fourth is
evidence from the 2026-05-10/11 bug-batch (annotations `20260510_*` /
commit `c673ef0`); the fifth is evidence from the loaded Blinded Gunners bug
fixed in `d752ffd`. Together they directly reinforce the LM thesis.

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
   was exactly this shape and is now represented in the L0 inventory).
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
5. **Transient rule registries are easy to forget after load.**
   The 2026-05-13 loaded-save bug (annotation `20260513_230813_001`,
   fixed in `d752ffd`) showed a Nebulon-B with faceup Blinded Gunners
   displayed correctly but still spending accuracy icons. The serialized
   state had `faceup_damage`; the transient `GameState.effect_registry`
   was empty after `deserialize()`. The fix rebuilt runtime effects from
   serialized entities in `GameManager.start_new_game_from_state()` and
   registered persistent faceup damage-card effects inside
   `ResolveDamageCommand.execute()`. Phase M must preserve that invariant:
   static rule definitions are not enough; active rule instances must be
   rebuilt or resolved from authoritative serialized entities.

The through-line: **the engine needs one declarative table that says
"in step X the controller is Y, the visible modals are Z, and the
legal commands are W," plus one explicit runtime rule-rebuild contract,
consulted by every producer and projector.**
Phase M (FlowSpec) is exactly that table; Phase L is the prerequisite
that removes the second modal-lifecycle path so the table only has
one consumer per concern.

Phases L and M close these failure classes with the *minimum* structural change
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
| External state-machine library (XState-style) | Rejected | Heavy for a 146-script GDScript codebase. The bespoke skeleton we already have (`InteractionFlow`) covers 90% of state-machine value. |
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
| L-G3 | Phase K's `scripts/lint_phase_k.sh` allow-list shrinks from 11 branches to <= 4 by L6. L6 explicitly moves the ship-activation network RPC guard out of scene/controller code and collapses duplicate load-dialog branches into one helper if needed. |
| M-G1 | Single `FlowSpec` registry covers every `(flow_id, step_id)` pair that `interaction_flow` can hold. Parity test fails CI if `UIProjector` projects an unknown pair. |
| M-G2 | Every `GameCommand` subclass declares an applicability scope: `GLOBAL`, `PHASE`, or `FLOW_STEP`. Flow-step commands declare `(flow_id, step_id)` pairs; phase/global commands declare the phase/system surface they belong to. Parity tests fail CI on missing declarations. |
| M-G3 | At least 6 representative rules (1 keyword, 2 damage cards, 1 defense-token rule, 1 status-phase rule, 1 attack-modifier rule) migrated to `RuleRegistry` self-registration or explicitly mapped through the legacy `EffectRegistry` bridge. Adding the 7th is documented as a one-file change. |
| M-G4 | Determinism: hook execution order across peers is byte-identical (priority + lexicographic rule_id tie-break). Replay test asserts hook order. |
| LM-G1 | Test baseline maintained: >= 147 scripts / >= 2 936 tests / >= 5 571 asserts / 0 failures at every code-bearing commit; `godot --headless --import` clean when new scripts are added; `bash scripts/lint_phase_k.sh` exits 0; `bash scripts/run_baseline_traces.sh --all` passes for modal/network/replay/command-submission/rule-observer changes. |
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
##       (ACTIVE_PLAYER | OPPOSING_PLAYER | DEFENDER | ATTACKER | EITHER)
##   "modals":          Array[Constants.ModalKind] visible in this step
##   "allowed_commands": Array[String] flow-step command_type strings legal here
##   "transitions":     Dictionary[String, String]
##       command_type -> next step_id (or "*" for "any step")
##   "rule_citation":   String  ("RR p.4 Step 4")
static func get_spec(flow_id: int, step_id: int) -> Dictionary:
    return _SPEC.get([flow_id, step_id], {})
```

The `_SPEC` table is a literal `const Dictionary` — no dynamic
mutation. Tests can iterate it.

### 3.2.1 Command applicability scopes

Not every command belongs to a modal/interaction step. Phase M must not
accidentally make phase/system commands illegal merely because
`interaction_flow` is empty. M0.7 therefore defines the command scope model
before M3 adds declarations:

| Scope | Meaning | Examples |
|---|---|---|
| `FLOW_STEP` | Legal only during explicit `(flow_id, step_id)` pairs from `FlowSpec`. | attack roll, commit defense, redirect, displacement commit |
| `PHASE` | Legal during a game phase regardless of modal flow. | assign dial, advance phase, status cleanup, repair action when no modal owns it yet |
| `GLOBAL` | Harness/system/debug command that is not gated by the current flow. Still runs normal `validate()`. | start round, replay publish snapshot, debug damage |

M4's `CommandProcessor` gate consults `FlowSpec.allowed_commands(...)` only
for `FLOW_STEP` commands. `PHASE` and `GLOBAL` commands get their own small
allow-list declarations so the parity test still covers them.

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
##   OBSERVER  — reacts after a command commits. May enqueue follow-up
##               commands through a deferred submit boundary; never mutates
##               GameState directly and never submits synchronously from
##               inside command_executed.
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

### 3.4 EffectRegistry / RuleRegistry boundary

Phase M does **not** delete or bypass the existing `EffectRegistry` in one
stroke. The current registry stores active runtime effect instances attached
to concrete entities (squadrons, ships, faceup damage cards). It is transient:
`GameState.deserialize()` creates it empty, and
`EffectFactory.rebuild_runtime_effects()` repopulates it from serialized
entities. That contract remains non-negotiable throughout M.

`RuleRegistry` is the static rule-definition catalogue: it tells the engine
which hook kinds exist for each flow/step/command surface and how to order
them. It must not become a second serialized state store. A migrated rule must
derive active status from authoritative `GameState` entities, or from a
documented bridge over active `EffectRegistry` instances while the old effect
path still exists.

Migration rule for M7-M12:
- If a rule is still implemented by `DamageCardEffect` / keyword effects, keep
   `EffectFactory.rebuild_runtime_effects()` registering that legacy effect.
- If a rule moves to `RuleRegistry`, its predicate must locate the active card,
   squadron keyword, upgrade, or token state from `GameState` each time, or use
   a typed active-effect handle rebuilt by `EffectFactory` after load.
- Repair, discard, destruction, and command-dealt faceup damage must continue
   to update active runtime hooks at the same command/state mutation boundary
   that changes the serialized entity state.
- The loaded Blinded Gunners regression is the acceptance example: a state that
   serializes `faceup_damage.effect_id == "blinded_gunners"` must block accuracy
   spending immediately after deserialize + install, in hot-seat, network, and
   replay.

### 3.5 How this collapses mode divergence

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
> The lint allow-list currently reports **10 branches** after L1; the L target floor
> is **<= 4** after L6.

| Slice | Scope | Risk | LOC delta | MT? |
|------:|---|---|---:|:---:|
| **L0** | **Complete.** Audit snapshot exists in [docs/modal_classification.md](modal_classification.md) §L-Inventory. It inventories the lint allow-list, direct callback modal opens, session-mode dispatchers, and the direct displacement co-anchor that lint cannot see. Future L slices update that inventory only when a slice closes or a target moves. | trivial | 0 | no |
| **L0.5** | **Complete.** Replay regression harness is committed: hot-seat diffs `baseline_trace_hot_seat_solo.jsonl` and `baseline_state_hash_hot_seat_solo.txt`; network runs a real two-process ENet host/client replay and gates on host/client final-state-hash equality. Per-peer network JSONL and hashes remain diagnostic only. `ReplayDriver` suppresses live auto `publish_attack_flow` snapshots during replay because the replay file already contains captured `PublishAttackFlowCommand` entries. Each L/M slice that touches modal/network/replay/command-submission flow must run `bash scripts/run_baseline_traces.sh --all`. | low | done | no |
| **L1** | **Complete.** Introduced `ModalRouter` ([`src/scenes/game_board/modal_router.gd`](../src/scenes/game_board/modal_router.gd), Node) as the single `CommandProcessor.command_executed` subscriber for projection-driven HUD, modal, and mirror routing. [`command_router_adapter.gd`](../src/scenes/game_board/command_router_adapter.gd) is now the composition root and delegates non-modal command reactions into the router. The former adapter `PlayMode.is_network()` branch was removed, dropping the lint allow-list from 11 to 10. Hot-seat still keeps direct lifecycle callbacks for the L2-L5 surfaces. | medium | done | yes |
| **L2** | Migrate **Activation modal** lifecycle to projection in hot-seat. Producer side: the dial-drop / activation entry stops calling `ShipActivationController.configure_and_open_activation_modal()` directly; instead the responsible `GameCommand.execute()` writes the `SHIP_ACTIVATION` step into `interaction_flow`, and `ModalRouter` opens the modal. Defect-anchor: closes the same source-of-truth class as bug 1 (activation-modal stale snapshot, `c673ef0`) — the projector recomputes `is_attack_skippable` on every command so the cached-callable workaround can later be removed. Removes the §3.1a `_on_command_executed_project_ui` modal-lifecycle dispatcher allow-list site in [`game_board.gd`](../src/scenes/game_board/game_board.gd). | high | +50 / −80 | yes |
| **L3** | Migrate **Squadron-command activation modal** lifecycle (sequence button + squadron command modal) to projection. The hot-seat-only "sequence button" affordance becomes an `ENABLER` hook surfaced through `UIIntent.affordances`. Removes the §3.1a sequence-button-origin allow-list site (now owned by `ShipActivationController._show_activation_sequence_button`). | high | +60 / −80 | yes |
| **L4** | Migrate **Displacement modal** lifecycle to projection in hot-seat. [`displacement_controller.gd`](../src/scenes/game_board/displacement_controller.gd) `start()` becomes an effect of `SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE`, opened by `ModalRouter`. Defect-anchor: closes the same source-of-truth class as bug 4 (`c673ef0`, RRG "Overlapping", p.8): once both modes consume `interaction_flow.controller_player`, no producer can derive it ad-hoc — `controller_player = 1 - maneuver_ship.owner_player` becomes the only path. Removes the §3.1a displacement-modal-origin allow-list site. | medium | +40 / −60 | yes |
| **L5** | Migrate **`_on_active_player_changed` content fork** (the line-889 dispatcher in [`game_board.gd`](../src/scenes/game_board/game_board.gd), `_dispatch_active_player_change_dispatcher` after K13) to a single path: build the same overlay objects on both modes, then style them via `UIIntent` (`needs_handoff_overlay` vs. `needs_waiting_overlay`). Removes the last big lifecycle allow-list branch. | high | +70 / −110 | yes |
| **L6** | Lint tightening: update `scripts/lint_phase_k.sh` allow-list from the current **11** branches to the post-L floor of **<= 4**. This slice explicitly (a) moves `ShipActivationController.submit_network_activation_step()`'s network-only guard into a network submitter/autoload helper or removes the branch by routing through the normal submitter, and (b) collapses the two load-dialog `PlayMode.is_network()` checks into one helper if they still count as two lint hits. Update [.github/copilot-instructions.md](../.github/copilot-instructions.md) §7 Phase K bullet to document the new floor and reword the Phase I negative rules as enduring constraints. | low | +30 / −40 | no |
| **L7** | Manual-test sweep: hot-seat full-game playthrough (round 1 + round 2) with every modal lifecycle observed. Same playthrough on network host + client. Use `bash scripts/run_baseline_traces.sh --all` as the automated pre-flight, then compare logs/UI behaviour side-by-side: modal open/close should be projected from the intended `interaction_flow` state on both peers and both modes, but exact network command-trace equality across separate runs is not required until the transport has a deterministic pump. Augment with the annotation-system diff for the displacement, activation-attack-skip, and brace cases (the three lifecycle-anchored defects from `c673ef0`) so the L migration is regression-tested against the bugs that motivated it. | trivial (test only) | 0 | yes |

### 4.1a L0.5 replay-regression automation (implemented — REVISED v3)

**Status:** implemented 2026-05-13.  The approved approach was revised
after real two-process runs showed that network command traces and even
full final-state hashes are timing-dependent across separate executions.
They are, however, peer-consistent within a run.  The implemented gate is
therefore:

1. **Hot-seat committed oracle:** JSONL trace diff + committed final-state
   hash diff.
2. **Network peer-equivalence oracle:** real ENet host/client replay, with
   host and client required to produce identical final-state hashes in the
   same run.  Per-peer JSONL traces remain diagnostic artifacts only.
3. **Manual L7/MT coverage:** still required for visual/modal semantics and
   for comparing intended projector behaviour across hot-seat and network.

Do not add a committed network command-trace or network final-state-hash
fixture until a deterministic network command pump exists.  A flapping
network hash fixture is worse than no fixture: it burns time on valid packet
timing differences and hides the useful invariant, which is peer equality.

**Original design note (superseded where it conflicts with the status
above).** Implements real two-process
network replay because debugging network behaviour has been the
single biggest cost source so far; the regression gate must cover
network mode end-to-end.

**Goal.** A single shell command that:
  1. Boots Learning Scenario rounds 1–2 deterministically in
     hot-seat **and** in network (host + client),
  2. Drives every command through the real production pipeline
     (validation, networking, broadcast, command-executed signal),
  3. Writes one `baseline_trace_<mode>_<role>.jsonl` per peer plus a
     sibling `.state_hash` file,
  4. Diffs hot-seat outputs against committed fixtures and checks
     network host/client state-hash equality.

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

Writes per-peer `baseline_trace_<mode>_<role>.jsonl` to
`PathConfig.LOGS_DIR` and, under `ReplayDriver`, writes a sibling
`.state_hash` file derived from canonical `GameState.serialize()` JSON.
Hot-seat traces are committed oracles; network traces are diagnostics.

##### Orchestration script

`scripts/run_baseline_traces.sh` — new shell script. Modelled on
[`run_network_test.sh`](../scripts/run_network_test.sh). For each
fixture:
  1. Hot-seat: launch one Godot process with `--replay
     hot_seat_solo.json --baseline-output <tmp>/hot_seat_solo.jsonl`.
     Wait for exit. `diff` against fixture.
  2. Network: launch headless server and client against the same captured
     `replay_network.json` stream. Each peer submits only commands authored
     by its local player; the peer receives the other player's commands
     through the real network/broadcast path. Wait for both to exit, then
     compare `network_host.state_hash` and `network_client.state_hash` for
     equality.
  3. Exit 0 if all diffs are empty; print unified diff and exit 1
     otherwise.

##### Tests and shell gate

GUT unit tests validate canonical trace/hash formatting and the replay-driver
control logic where it can be tested in-process. The real hot-seat and ENet
network replay is intentionally exercised by `scripts/run_baseline_traces.sh`:
spawning full Godot processes from GUT was rejected because it duplicates the
shell orchestration and is less faithful to the deployed boot path.

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

Network mode's `WAIT_FOR_OPPONENT_DIALS` (and analogous waits) can
genuinely change intermediate post-execute flow state on each peer, and
real ENet timing can choose different valid interleavings across separate
runs.  The harness therefore does not commit per-role network JSONL
fixtures.  Instead, each network run writes per-peer diagnostic traces and
checks the durable invariant: host and client must end that same run with
the same canonical serialized state hash.

The sync barrier is sufficient to keep peers synchronized, but not
sufficient to make the *entire network command stream* reproducible
across separate process runs.  Real ENet timing can still choose a
different valid interleaving between broadcast echoes, client-originated
commands, and post-command auto-flow.  The implemented harness therefore
checks the invariant we can trust today: both peers end a run with the
same canonical serialized state.

#### 4.1a.3 Risks and mitigations

| Risk | Mitigation |
|---|---|
| `--replay` flag accidentally activated in a production user session | Flag is parsed only if explicitly passed; absent from every export preset; documented in `docs/setup_network_game.md`. `ReplayDriver._ready` early-returns when the flag is absent. |
| Network process startup race (client connects before server is listening) | Mirror `run_network_test.sh`'s existing `sleep 1` between server-spawn and client-spawn. Client retries connect for up to 5 s; if it fails, exit non-zero with a clear message. Both are already proven patterns in the existing script. |
| ENet localhost command ordering varies across runs | Do not diff network JSONL or committed network state hashes. Gate network on host/client final-state-hash equality within the same run; keep JSONL as diagnostics. |
| ENet localhost flakiness on CI | Run the shell-script gate locally before every L/M slice. Skip it in CI initially (only the GUT in-process hot-seat test runs in CI). Promote to CI only after the transport is deterministic enough for repeated headless runs. |
| Per-command 5 s timeout too aggressive for some commands (e.g. squadron move animations) | The timeout measures *engine* sync, not *animation* completion — `command_executed` fires synchronously inside `CommandProcessor.submit`. Animations finish later but are not observed by the trace. 5 s is generous for engine sync. Bumpable per-test via `--replay-step-timeout`. |
| Two peers reach `game_started` at different physics frames → step loop reads stale `interaction_flow` | The sync barrier (`command_executed` with expected `sequence`) makes the loop strictly synchronous. The driver never advances on its own clock; it advances only on observed broadcast. |
| Capturing the initial network replay pair requires manual interaction (hands on keyboard for two windows) | Yes — one-time cost. From there on, all regression checks are headless. Capturing the hot-seat replay was already a one-time cost (already paid). |
| Adding a new autoload (`ReplayDriver`) violates the §6 enforcement rule? | Autoload count goes from N to N+1. The rule is "minimise autoloads"; this one is justified because `BaselineTrace` is also already an autoload and the driver must run before `EventBus.game_started`. Documented in §11 risks register. |

#### 4.1a.4 Implemented artifacts

| Artifact | Purpose |
|---|---|
| [src/autoload/baseline_trace.gd](../src/autoload/baseline_trace.gd) | Writes canonical JSONL command-flow entries and canonical final-state hashes. Supports buffered harness mode. |
| [src/autoload/replay_driver.gd](../src/autoload/replay_driver.gd) | Opt-in `--replay` driver for hot-seat and network. Submits through real command submitters and waits on command execution. |
| [scripts/run_baseline_traces.sh](../scripts/run_baseline_traces.sh) | One-command gate: hot-seat committed oracle plus real two-process network peer-equality check. |
| `tests/fixtures/baseline_traces/replay_hot_seat_solo.json` | Captured hot-seat Learning Scenario R1-R2 input stream. |
| `tests/fixtures/baseline_traces/baseline_trace_hot_seat_solo.jsonl` | Committed hot-seat command-flow oracle. |
| `tests/fixtures/baseline_traces/baseline_state_hash_hot_seat_solo.txt` | Committed hot-seat final-state hash oracle. |
| `tests/fixtures/baseline_traces/replay_network.json` | Captured network Learning Scenario R1-R2 input stream. |
| [tests/unit/test_baseline_trace_format.gd](../tests/unit/test_baseline_trace_format.gd) and [tests/unit/test_replay_driver.gd](../tests/unit/test_replay_driver.gd) | Unit coverage for canonical trace/hash behavior and replay-driver branch logic. |

**Sequencing requirement:** continue to commit only hot-seat trace/hash
fixtures. Do not add committed per-peer network JSONL traces or network
state-hash fixtures until the transport has a deterministic command pump
across separate process runs. The current network gate regenerates
diagnostic traces headlessly and compares only host/client final-state hashes
within the same run.

#### 4.1a.5 Operational decisions

1. **Real two-process network automation is required.** This remains
   non-negotiable because network debugging has been the most expensive
   failure surface so far.
2. **`ReplayDriver` is a production autoload, opt-in via `--replay`.** It is
   inert in every non-driver session and avoids duplicating the real boot path.
3. **Sync barrier is `command_executed` per expected `sequence`.** Wall-clock
   pacing stays out of the harness.
4. **Network replay uses one captured full command stream.** Each peer filters
   by `player_index`; the other peer's commands arrive through the production
   network path.
5. **Network generated traces are diagnostic only.** The acceptance invariant
   is host/client final-state-hash equality within the same run.

### 4.2 Acceptance criteria for closing Phase L

1. `bash scripts/lint_phase_k.sh` shows <= 4 allow-listed branches, none of them in `src/scenes/game_board/` for modal lifecycle (down from the current 10 after L1).
2. A `match`-style audit of the modal-open call sites shows each modal type opens through `ModalRouter` exclusively, with no direct calls remaining.
3. Test baseline: >= 147 scripts / >= 2 936 tests / >= 5 571 asserts / 0 failures (current baseline preserved or grown). The known post-summary Godot shutdown abort is tracked separately from GUT failures.
4. `bash scripts/run_baseline_traces.sh --all` passes: hot-seat trace/hash match committed fixtures and network host/client final-state hashes are equal within the same run.
5. Manual test L7 confirms modal lifecycle behaviour is equivalent between hot-seat and network, including regression coverage for `c673ef0`'s three lifecycle-anchored defects (displacement controller, activation-modal stale snapshot, brace canonical sort). Exact network command-trace equality across separate runs is not an acceptance criterion until a deterministic network pump exists.

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
| **M0.6** | **Runtime-registry boundary review.** Add a `docs/game_flow.md` §0 subsection that defines the boundary between `EffectRegistry`, `EffectFactory.rebuild_runtime_effects()`, and `RuleRegistry`. Pin the loaded Blinded Gunners bug (`d752ffd`) as the worked example: serialized faceup damage state must activate the accuracy-spend blocker immediately after load. Decide which first-six M rules are pure static predicates and which still need an `EffectRegistry` bridge. **No code changes.** | trivial | +0 (docs) | no |
| **M0.7** | **Command-scope model.** Add the `GLOBAL` / `PHASE` / `FLOW_STEP` scope taxonomy to `docs/game_flow.md` before adding command declarations. Inventory commands that intentionally run outside `interaction_flow` so M3/M4 do not misclassify replay, setup, phase-advance, or debug commands as illegal. **No code changes.** | low | +0 (docs) | no |
| **M1** | Add [src/core/state/flow_spec.gd](../src/core/state/flow_spec.gd) (RefCounted) with a frozen `_SPEC` table that translates `docs/game_flow.md` into machine form. Add `tests/unit/test_flow_spec.gd`: every `(flow_id, step_id)` produced by any test in `tests/unit/test_ui_projector.gd` must be present in `_SPEC`. | low | +200 / 0 | no |
| **M2** | Wire `UIProjector.project()` to consult `FlowSpec.get_spec(...)` for `controller_role` and `modals`. Today's hard-coded modal mapping in `UIProjector` becomes a lookup. Identical output asserted by `test_ui_projector.gd` (no test changes expected). | medium | +80 / −120 | yes |
| **M3** | **Parity gate I:** add a unit test that, for every command type currently registered with `GameCommand.register_type(...)`, asserts a static applicability declaration exists. The declaration includes `scope` (`GLOBAL`, `PHASE`, or `FLOW_STEP`) plus allowed phases or `(flow_id, step_id)` pairs as appropriate. Fail with a clear error listing missing commands. Then add the declarations command-by-command in this slice. No behaviour change yet. | low | +140 / 0 | no |
| **M4** | **Parity gate II:** `CommandProcessor.submit()` consults `FlowSpec.allowed_commands(state.flow, state.step)` before calling `cmd.validate()` only for `FLOW_STEP` commands. `PHASE` and `GLOBAL` commands are checked against their own declarations. Mismatch -> reject with a structured `{allowed: false, reason: "command X not allowed in step Y"}`. Run replay suite + manual test to catch missed declarations from M3. | medium | +40 / 0 | yes |
| **M5** | Add [src/core/effects/rule_registry.gd](../src/core/effects/rule_registry.gd) and [src/core/effects/flow_hook.gd](../src/core/effects/flow_hook.gd). Add `autoload/rule_bootstrap.gd` that calls every registered rule's static `register()`. **Empty registry** at this slice — registry behaves identically to today and does not replace `EffectRegistry`. Test: `RuleRegistry.validators_for(...)` returns `[]` for every step until rules migrate. | low | +180 / 0 | no |
| **M6** | `CommandProcessor.preflight()`: after FlowSpec allow-list passes, run `RuleRegistry.validators_for(flow, step, cmd.command_type)` in priority order; first denial wins. `AttackResolver.modify_dice_pool()`: consult `RuleRegistry.modifiers_for(flow, step, "dice_pool")`. `CommandProcessor.notify_observers()`: after execute, call `RuleRegistry.observers_for(...)` through a deferred follow-up command queue; observers never submit synchronously during `EventBus.command_executed`. **Empty registry** keeps behaviour identical. | medium | +140 / 0 | no |
| **M7** | Migrate **rule 1: Faulty Countermeasures** (defense-token spend validator). Single file, single VALIDATOR hook. Remove or bridge the current legacy effect path only after the new test proves identical behaviour after command-time registration and after save/load rebuild. Test: `tests/unit/test_rule_faulty_countermeasures.gd`. | low | +90 / −40 | yes |
| **M8** | Migrate **rule 2: Compartment Fire** (defense-token ready blocker in Status Phase). Demonstrates a `PHASE`-scope MODIFIER + multi-flow registration in one file. Include a load/rebuild assertion if the current implementation uses `EffectRegistry`. | low | +90 / −40 | yes |
| **M9** | Migrate **rule 3: Damaged Munitions** (attack-pool dice removal modifier). Demonstrates an `ATTACK_ROLL` MODIFIER hook and validates that active faceup-card state, not a stale runtime hook, decides applicability. | low | +90 / −40 | yes |
| **M10** | Migrate **rule 4: Point-Defense Failure** (squadron-attack-only modifier). Demonstrates a flow-conditional predicate and squadron keyword/effect bridge semantics. | low | +90 / −40 | yes |
| **M11** | Migrate **rule 5: Crew Panic** (BEFORE_REVEAL_DIAL choice modal as ENABLER). Demonstrates surfacing optional UI affordances through `UIIntent.affordances` populated by ENABLER hooks, with no modal lifecycle branch in scene code. | medium | +120 / −80 | yes |
| **M12** | Migrate **rule 6: Capacitor Failure** (no shields -> no recover, no redirect). Demonstrates a multi-hook rule: VALIDATOR on `recover_shields`, BLOCKER on redirect step. Documents the "one rule, multiple hooks" pattern and the active-state source for each hook. | medium | +110 / −60 | yes |
| **M13** | **Determinism guard:** add `tests/integration/test_rule_order_replay.gd`. Run a replay scenario that triggers ≥ 3 hooks in the same step on both peers (host + client harness), serialise hook execution order, assert byte-identical sequences. | low | +120 / 0 | no |
| **M14** | **Coverage tool:** `scripts/dump_flow_coverage.gd` — given a `(flow, step)`, prints all FlowSpec metadata + every registered rule. Used as a debugging aid; runs in `--headless`. | low | +80 / 0 | no |
| **M15** | Update `docs/implementation_plan.md` §1 baseline + §2 phase status + §4 open topics. Update [.github/copilot-instructions.md](../.github/copilot-instructions.md) "Non-Negotiable Rules" with rule §12 "New rules go through `RuleRegistry`". Update `.skills/architecture_patterns.md` with a Layer-3 (rules) section. | trivial | +0 (docs) | no |

### 5.2 Acceptance criteria for closing Phase M

1. `tests/unit/test_flow_spec.gd` covers 100% of `(flow_id, step_id)` pairs that appear in `tests/unit/test_ui_projector.gd`. New pair → CI fails.
2. Every `GameCommand` subclass declares an applicability scope plus its allowed phases or `(flow_id, step_id)` pairs. Static parity test enforces this.
3. `CommandProcessor.submit()` rejects a command whose declaration does not include the current flow/phase surface. Tested for `FLOW_STEP`, `PHASE`, and `GLOBAL` commands.
4. `RuleRegistry` contains the 6 migrated rules or documented bridges for any legacy `EffectRegistry` rule retained during M. Adding a 7th is reproducibly a one-file change (write rule + add to bootstrap list) unless it intentionally bridges a legacy effect.
5. Save/load regression covers at least one migrated persistent damage-card rule, including the loaded Blinded Gunners failure class.
6. Observer hooks use the deferred follow-up queue; no migrated rule submits synchronously during `command_executed`.
7. Determinism replay test green.
8. Test baseline: >= 147 scripts / >= 2 936 tests / >= 5 571 asserts / 0 failures; `bash scripts/lint_phase_k.sh` exits 0; `bash scripts/run_baseline_traces.sh --all` passes for any slice touching modal, replay, network, command-submission, or rule-observer flow.

---

## 6. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| L2/L3/L5 hot-seat modal migration breaks observable UX (timing, animations) | Medium | High | Each slice gated by manual test L7-style comparison. Incremental: one modal type at a time. Snapshot test of `UIIntent` per scenario step keeps regressions tight. |
| Hot-seat affordances (sequence button) don't have a clean network equivalent | Medium | Medium | L3 explicitly migrates affordances through `UIIntent.affordances`. If a true asymmetry remains, document it as an `affordance_kind` value with a clear semantic, not a `PlayMode` branch. |
| FlowSpec entries drift from runtime (someone adds a step without updating the spec) | Medium | High | M1 parity test fails CI on unknown pairs. M3/M4 parity tests fail on unknown commands. Two safety nets. |
| Rule self-registration ordering causes peer divergence | Low | Critical | M5 + M13 enforce sort order `(priority DESC, rule_id ASC)` and a determinism replay test. Static rule list — no dynamic registration after autoload. |
| Existing keyword effects break during M7–M12 migration | Medium | High | One rule per slice; existing tests retained; new test added for migrated rule. Old in-resolver code removed only after the new path is proven by the new test. |
| Runtime effect/rule registry not rebuilt after load (loaded Blinded Gunners class) | Medium | Critical | M0.6 defines the `EffectRegistry` / `RuleRegistry` boundary before code migration. Every persistent damage-card migration includes a save/load regression. `EffectFactory.rebuild_runtime_effects()` remains authoritative for legacy runtime hooks until a rule is fully migrated. |
| Observer hook submits follow-up command synchronously during network command broadcast | Medium | Critical | M6 introduces a deferred follow-up queue and forbids synchronous observer submission from inside `EventBus.command_executed`. Network replay gate must pass for any slice that adds observer hooks. |
| Save format break | Low | Critical | `interaction_flow` JSON shape unchanged; FlowSpec and RuleRegistry are computed/runtime-only; active rule state remains derived from serialized entities. Pin save format version if a slice must add serialized fields. |
| Replay break | Low | Critical | Replay determinism gated by M13. Run `bash scripts/run_baseline_traces.sh --all` locally on every L/M slice that touches modal, replay, network, command-submission, or rule-observer flow. |
| Scope creep ("while we're at it, let's redesign…") | High | Medium | Slice list is fixed. Every additional change must land as a separate phase (Phase N candidate). |
| Stale line/LOC references inside this plan (drafted 2026-05-10 against `game_board.gd` ≈ 3 055 LOC; file is now 1 464 LOC after K8/K10/K11/K12/K13) | Medium | Low | L0 already refreshed the inventory in `modal_classification.md` §L-Inventory. Treat the §4.1 slice descriptions as role-based (file + symbol + lint-allow-list entry), never as `:NNNN` line addresses. |
| New producer adds a `controller_player` ad-hoc instead of consulting FlowSpec (the 2026-05-11 displacement defect class) | Medium | High | M0.5 lands `FlowSpec.controller_role(flow_id, step_id) -> ControllerRole` and a parity test that fails CI when any `GameCommand.execute()` writes `interaction_flow.controller_player` without going through the spec. Worked example pinned in §5.1 M0/M0.5. |

---

## 7. How this aligns with existing plans

### 7.1 Phase K dependency

Phase K is complete for LM purposes. L0, L0.5, and L1 are also complete, so
the next code-bearing LM slice is **L2 Activation modal projection**.

Required Phase K foundations are present:

1. **K12 (`CommandRouterAdapter`) committed (`e17ff05`).** This is the single
   `EventBus.command_executed -> UIProjector.project` subscription point that
   L1's `ModalRouter` extends.
2. **K7 lint script in place and green.** `scripts/lint_phase_k.sh` currently
   reports `0 violations (10 allow-listed branches)`. L tightens the
   allow-list; the starting count is known.
3. **K14 (`AttackFlowExecutor`) committed (K14a `454fd0e` -> K14g
   `33e697f`).** Attack-flow payload construction, defense-commit canonical
   ordering, faceup/immediate-effect decision, and redirect continuation live
   in [src/core/combat/attack_flow_executor.gd](../src/core/combat/attack_flow_executor.gd)
   with isolated unit coverage in [tests/unit/test_attack_flow_executor.gd](../tests/unit/test_attack_flow_executor.gd).

Current post-fix snapshot (2026-05-14):

| File | LOC | Status |
|---|---:|---|
| [src/scenes/game_board/game_board.gd](../src/scenes/game_board/game_board.gd) | 1 462 | Under the Phase K 2 000 LOC ceiling. |
| [src/scenes/game_board/attack_executor.gd](../src/scenes/game_board/attack_executor.gd) | 2 479 | Over the long-term 1 500 LOC target; do not add new responsibilities. |
| [src/autoload/game_manager.gd](../src/autoload/game_manager.gd) | 2 269 | Over the long-term 1 500 LOC target; new behaviour belongs in focused helpers/controllers. |
| [src/autoload/save_game_manager.gd](../src/autoload/save_game_manager.gd) | 1 061 | Still a split candidate; LM should not grow it. |
| [src/scenes/game_board/command_router_adapter.gd](../src/scenes/game_board/command_router_adapter.gd) | 100 | Composition root for command-router projection paths. |
| [src/scenes/game_board/modal_router.gd](../src/scenes/game_board/modal_router.gd) | 221 | Projection-driven modal and HUD router introduced in L1. |
| [src/scenes/game_board/ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | 1 393 | Owns activation modal details; L6 must remove or relocate its network RPC branch. |

Recommended next sequence:

1. Begin L2 on a focused branch from the current post-L1 baseline.
2. Keep LM changes out of [src/scenes/game_board/attack_executor.gd](../src/scenes/game_board/attack_executor.gd), [src/autoload/game_manager.gd](../src/autoload/game_manager.gd), and [src/autoload/save_game_manager.gd](../src/autoload/save_game_manager.gd) unless the slice explicitly extracts responsibilities from them.
3. Run `bash scripts/run_baseline_traces.sh --all` for every slice that touches modal, replay, network, command-submission, or rule-observer flow.

### 7.2 Phase G4 unblocking

Phases G4.7 (Spectator), G4.8 (Reconnection runtime), and G4.9 (Turn
Timers) originally depended on Phase K. With K complete, they should wait
for L/M flow hardening because:

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

After Phase L closes, the only remaining `PlayMode.is_network()` /
`PlayMode.is_hot_seat()` branches outside `src/autoload/` are <= 4
allow-listed deployment-mode dispatchers (save/load/lobby surfaces). Camera
ownership may still consult `PlayMode.seat_controls_camera()` for per-modal
camera behaviour; that is not modal lifecycle authority and is not part of the
Phase K network/hot-seat lint floor.

After Phase M closes, every gameplay-rule decision is in the registry,
discoverable in seconds, and tested in isolation. Adding a new card is
a single-file change.

---

## 8. Quick-start guide for executing this plan

### Before starting L2

1. Confirm the current baseline includes L0/L0.5, L1, and the loaded-save
   persistent-effect fix (`d752ffd`).
2. Confirm `bash scripts/lint_phase_k.sh` exits `0` with 11 allow-listed
   branches before L migration or 10 allow-listed branches after L1.
3. Confirm the GUT green summary baseline is at least 147 scripts / 2 936
   tests / 5 571 asserts / 0 failures. The known post-summary Godot shutdown
   abort is not a test failure.
4. Run `bash scripts/run_baseline_traces.sh --all` before starting any modal,
   network, replay, command-submission, or rule-observer slice.
5. Start a focused branch for L1 (`phase-l/modal-router`) and keep replay
   artifact churn out of commits.

### During each Phase L/M slice

1. Implement the slice in a tight commit.
2. Run:
   ```bash
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
   bash scripts/lint_phase_k.sh
   ```
3. Confirm: 0 failures, expected script/assert counts preserved or grown, lint = 0 violations.
4. Run `bash scripts/run_baseline_traces.sh --all` for slices touching modal,
   replay, network, command-submission, or rule-observer flow.
5. Run the slice's manual test if marked `MT? = yes`, and wait for explicit
   user approval before committing code changes.
6. Update `docs/implementation_plan.md` §1 baseline + §2 status when a phase
   task or full phase closes.
7. Commit with conventional-commit message (`refactor(flow):` or `feat(rule):`).

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
4. The **2026-05-11 bug-batch (`c673ef0`) confirmed the symptoms predicted by §0** — three defects were *source-of-truth* failures (displacement `controller_player`, activation-modal stale snapshot, brace canonical-sort drift), not logic failures.
5. The **2026-05-13 loaded Blinded Gunners bug (`d752ffd`) exposed the runtime-rule half of the same problem**: serialized state was correct, but transient hooks were missing after load. The hardened Phase M plan now treats active-rule rebuild as a first-class contract.

This plan is *bounded* (concrete slice list, concrete LOC budget,
concrete acceptance gates), *aligned* (Phase K complete; L0/L0.5/L1 complete;
unblocks G4.7+ after L/M), and *minimally invasive* (no save format break,
no new RPC, no new EventBus channel, no wholesale replacement of existing
runtime-effect primitives).

**Verdict: safe to begin L2 now.** The plan is complete enough to drive the
activation-modal projection slice, with hot-seat and network replay gates
already in place.

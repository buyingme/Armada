# Refactoring Phases L & M — Unified Flow Authority and Rule Registry

> **Status:** COMPLETE - 2026-05-19. Phase L is complete (L0-L7); Phase M is complete (M0-M15).
> **Predecessors:** Phase K is complete. The deferred hot-seat modal-lifecycle work from Phase K §3.1d is now Phase L's scope.
> **Go-conditions (verified 2026-05-14):**
>   - K12 `CommandRouterAdapter` committed (`e17ff05`).
>   - K14 `AttackFlowExecutor` complete (K14a `454fd0e` -> K14g `33e697f`).
>   - L0 audit exists in [docs/modal_classification.md](modal_classification.md) §L-Inventory.
>   - L0.5 replay gate committed (`d752ffd`): `bash scripts/run_baseline_traces.sh --all` passes hot-seat trace/hash and real network host/client state-hash equality.
>   - `bash scripts/lint_phase_k.sh` exits `0` (4 allow-listed branches after L6; the L target floor is met).
>   - Closing baseline: 163 scripts / 3 096 tests / 6 209 asserts / 0 failures. Godot still reports known shutdown RID leak warnings in the runner output; no parse errors or GUT failures were reported.
>   - No `interaction_flow` schema change pending. No save-format change pending.
> **Successor:** Resume G4.7 (Spectator), G4.8 (Reconnection runtime), G4.9 (Turn Timers), then Phase 10c.
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
| L-G2 | Hot-seat opens, mirrors, and closes every gameplay modal (Activation, Squadron, Displacement, Attack, Immediate-Choice, Repair) via the same `CommandProcessor.command_executed -> UIProjector.project -> modal lifecycle` chain that network already uses. |
| L-G3 | Phase K's `scripts/lint_phase_k.sh` allow-list shrinks from 11 branches to <= 4 by L6. L6 explicitly moves the ship-activation network RPC guard out of scene/controller code and collapses duplicate load-dialog branches into one helper if needed. |
| M-G1 | Single `FlowSpec` registry covers every documented and enum-backed `(flow_id, step_id)` pair that `interaction_flow` can hold, including legacy/projected rows not currently exercised by `UIProjector` tests. Parity tests fail CI if `docs/game_flow.md`, `Constants`, or `UIProjector` drift. |
| M-G2 | Every `GameCommand` subclass declares an applicability scope: `GLOBAL`, `PHASE`, or `FLOW_STEP`. Flow-step commands declare `(flow_id, step_id)` pairs; phase/global commands declare the phase/system surface they belong to. Parity tests fail CI on missing declarations. |
| M-G3 | At least 6 representative rules/effects matching M7-M12 are migrated to `RuleRegistry` self-registration or explicitly mapped through the legacy `EffectRegistry` bridge: defense-token validation, status-phase modification, attack-pool modification, squadron-attack conditional modification, optional UI affordance enablement, and one multi-hook recover/redirect blocker. Adding the 7th is documented as a one-file change. |
| M-G4 | Determinism: hook execution order across peers is byte-identical (priority + lexicographic rule_id tie-break). Replay test asserts hook order. |
| LM-G1 | Test baseline maintained: >= 148 scripts / >= 2 956 tests / >= 5 629 asserts / 0 failures at every code-bearing commit; `godot --headless --import` clean when new scripts are added; `bash scripts/lint_phase_k.sh` exits 0; `bash scripts/run_baseline_traces.sh --all` passes for modal/network/replay/command-submission/rule-observer changes. |
| LM-G2 | All sliced commits keep the manual-test gate (per `.skills/copilot_instructions.md`). |
| LM-G3 | No save-format version bump. No new RPC channels. No new EventBus signals beyond what Phase L's modal-projection migration intrinsically requires. |

### 2.2 Non-Goals

- **No new gameplay features** during L or M. Bug fixes that fall out of the unification are in scope; feature additions are not.
- **No migration of every keyword** to the registry. Phase M proves keyword/effect bridge semantics only where the M7-M12 rules require them; broader keyword migration waits until next-touch.
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
|  src/core/state/flow_spec.gd  [RefCounted, static core helper]|
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

## Returns the spec for a given (flow_id, step_id) pair, or an empty
## Dictionary if the pair is not registered.  Phase M-G1: every documented
## pair that InteractionFlow can hold MUST be in the registry.
##
## Spec Dictionary keys:
##   "controller_role": Constants.ControllerRole
##       (NONE | ACTIVE_PLAYER | OPPOSING_PLAYER | ATTACKER |
##        DEFENDER_OR_ATTACKER | PAYLOAD_CONTROLLER | EITHER_PLAYER | SYSTEM)
##   "modals":          Array[Constants.ModalKind] visible in this step
##   "allowed_commands": Array[String] flow-step command_type strings legal here
##   "transitions":     Dictionary[String, String]
##       command_type -> next step_id (or "*" for "any step")
##   "source":          String ("command_produced" | "projection_only")
##   "rule_citation":   String  ("RR p.4 Step 4")
static func get_spec(flow_id: int, step_id: int) -> Dictionary:
    return _SPEC.get([flow_id, step_id], {})

static func has_spec(flow_id: int, step_id: int) -> bool:
   return _SPEC.has([flow_id, step_id])

static func resolve_controller_player(flow_id: int, step_id: int,
      game_state: GameState, context: Dictionary = {}) -> int:
   ...
```

The `_SPEC` table is a literal `const Dictionary` — no dynamic
mutation. Tests can iterate it.

M1 also adds `Constants.ControllerRole` with these values:

| Role | Resolution contract |
|---|---|
| `NONE` | Resolves to `-1`; no player owns the step. |
| `ACTIVE_PLAYER` | Resolves to the current activation/squadron active player from the provided state/context. |
| `OPPOSING_PLAYER` | Resolves to the non-moving/non-active player. `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` is the regression example. |
| `ATTACKER` | Resolves to the attacker's player index from attack context/payload. |
| `DEFENDER_OR_ATTACKER` | Resolves to the defender player when one exists, otherwise the attacker. Used for defense-token windows against non-player targets. |
| `PAYLOAD_CONTROLLER` | Resolves to an explicit `controller_player` carried in a validated payload/context, for card-defined chooser cases such as immediate critical choices. |
| `EITHER_PLAYER` | Command-phase simultaneous/either-player surface. Projection decides local interactivity from submitted-player state, not one global controller. |
| `SYSTEM` | Resolves to `-1`; deterministic system cleanup or game-over surface. |

`resolve_controller_player(...)` must return `-1` when a role cannot be
resolved from the supplied state/context, and tests must cover that failure
path. M2.5 migrates producers to this resolver; M1 only creates the contract
and unit tests for each role.

### 3.2.1 Command applicability scopes

Not every command belongs to a modal/interaction step. Phase M must not
accidentally make phase/system commands illegal merely because
`interaction_flow` is empty. M0.7 therefore defines the command scope model
before M3 adds declarations:

| Scope | Meaning | Examples |
|---|---|---|
| `FLOW_STEP` | Legal only during explicit `(flow_id, step_id)` pairs from `FlowSpec`. | attack roll, commit defense, redirect, displacement commit |
| `PHASE` | Legal during a game phase regardless of modal flow. | assign dial, start/advance round, status cleanup, repair action when no modal owns it yet, immediate-effect resolution in Ship/Squadron phases while debug follow-ups lack a dedicated flow surface |
| `GLOBAL` | Harness/system/debug command that is not gated by the current flow. Still runs normal `validate()`. | replay publish snapshot, debug damage, destroy-unit cleanup |

M4's `CommandProcessor` gate consults `FlowSpec.allowed_commands(...)` only
for `FLOW_STEP` commands. `PHASE` and `GLOBAL` commands get their own small
allow-list declarations so the parity test still covers them.

Post-M0.7 correction: `resolve_immediate_effect` must not be declared as
attack-flow-only in M3. Attack damage resolution and critical-choice flows own
the normal UI path, but the debug damage tool can submit the same command as an
immediate follow-up outside `ATTACK`. M3 should preserve current behaviour with
a `PHASE` declaration for `SHIP` and `SQUADRON` plus a debug-follow-up fixture;
later slices may narrow it only after that path has its own FlowSpec surface.

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
##   OBSERVER  — reacts after a command commits. Returns follow-up command
##               requests for the deferred queue; never mutates GameState
##               directly and never submits synchronously from inside
##               CommandProcessor.command_executed.
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

#### 3.3.1 Deferred follow-up queue

Observer hooks must return follow-up command requests; they must not call
`CommandProcessor.submit()` or `GameManager.submit_*()` themselves. M6 adds a
single queue owned by `CommandProcessor` so network broadcast order stays
stable:

1. Validate and execute command A.
2. Record command A.
3. Collect observer follow-ups for A into a FIFO queue without submitting them.
4. Emit `CommandProcessor.command_executed` for A.
5. After the emit returns, drain the follow-up queue through the normal
   `CommandProcessor.submit()` path, one command at a time.

This preserves the ordering lesson from Phase I6b-4d: the host must broadcast
A before any follow-up command B can be submitted and broadcast. During
`is_replaying`, observer follow-up generation is disabled; replayed follow-up
commands come from the captured command history so replay does not duplicate
generated commands.

M6 acceptance tests must prove:

- observer hooks cannot synchronously submit commands while they are being
   collected;
- the queue drains only after `CommandProcessor.command_executed` for the
   triggering command returns;
- replay mode does not synthesize duplicate observer follow-ups;
- a lint or unit guard fails if files under `src/core/effects/rules/` call
   `CommandProcessor.submit` or `GameManager.submit_` directly.

A rule file (one card/keyword = one file):

```gdscript
## src/core/effects/rules/damage_cards/ship/faulty_countermeasures.gd
##
## Rules Reference: damage card "Faulty Countermeasures",
## "You cannot spend exhausted defense tokens." (RRG p.12)
class_name FaultyCountermeasures
extends RefCounted

const RULE_ID := "damage_card.faulty_countermeasures"

static func register() -> void:
    RuleRegistry.register_rule(RULE_ID, [
        FlowHook.new(
            flow_id    = Constants.InteractionFlow.ATTACK,
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

Rule registration entry point (`src/autoload/rule_bootstrap.gd`) does
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

### 3.5 M7 MT lesson: selectable rules need three aligned surfaces

The Faulty Countermeasures manual-test bug exposed a structural trap in rule
migration: protecting only the final mutation command is insufficient when the
UI first submits a marker command or selection payload. The real defense flow
is `commit_defense` (selected indices) followed by one or more
`spend_defense_token` commands on the attacker peer. The first M7 draft
validated only `spend_defense_token`, so an illegal exhausted token could still
be selected and then scene code could apply local defense effects even if the
final command was rejected.

Rule integrations that expose player choices must now align three surfaces:

- **Rule surface:** one rule file registers every command expression of the
    illegal action, including marker commands (`commit_defense`) and mutation
    commands (`spend_defense_token`).
- **Payload surface:** core/application code publishes rule-derived
    eligibility in `interaction_flow.payload` using JSON-safe fields such as
    `blocked_defense_token_indices`.
- **UI surface:** panels render those payload fields as disabled/available
    choices and never re-implement card text locally.

Command-submit call sites must also treat an empty result as rejection and stop
scene-side effects immediately. This keeps `RuleRegistry` as the rule
authority, `GameState.interaction_flow` as the UI-state carrier, and panels as
renderers.

### 3.6 Rule file organization proposal

The RRG inventory shows future rules will span attack timing, defense tokens,
commands, movement/overlap, obstacles, squadrons and keywords, status/ready
costs, setup, objectives, upgrades, and special tokens. A flat
`src/core/effects/rules/` folder will quickly become hard to scan.

Use source-first grouping once the next migration makes the flat folder noisy:

```text
src/core/effects/rules/
   README.md
   core/
      attack/
      commands/
      movement/
      status/
   damage_cards/
      ship/
      crew/
   squadron_keywords/
   ship_keywords/
   upgrades/
      commander/
      officer/
      weapons_team/
      defensive_retrofit/
      ion_cannons/
      ordnance/
      turbolasers/
      support_team/
      title/
      other/
   objectives/
      assault/
      defense/
      navigation/
   obstacles/
   tokens/
```

Source-first grouping is intentionally user-facing: a contributor usually knows
the card, keyword, objective, obstacle, or token they are looking for before
they know its internal hook surface. Keep all hooks for one rule in one file,
even when that rule attaches to multiple flows, so multi-hook cards such as
Capacitor Failure remain discoverable as one behaviour.

### 3.7 How this collapses mode divergence

Hot-seat and network become *byte-identical* on the modal-lifecycle
path:

```
GameCommand.execute() writes interaction_flow into GameState
       │
       ▼
CommandProcessor.command_executed (both peers, both modes)
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
> The lint allow-list reports **4 branches** after L6, meeting the Phase L target floor.

| Slice | Scope | Risk | LOC delta | MT? |
|------:|---|---|---:|:---:|
| **L0** | **Complete.** Audit snapshot exists in [docs/modal_classification.md](modal_classification.md) §L-Inventory. It inventories the lint allow-list, direct callback modal opens, session-mode dispatchers, and the direct displacement co-anchor that lint cannot see. Future L slices update that inventory only when a slice closes or a target moves. | trivial | 0 | no |
| **L0.5** | **Complete.** Replay regression harness is committed: hot-seat diffs `baseline_trace_hot_seat_solo.jsonl` and `baseline_state_hash_hot_seat_solo.txt`; network runs a real two-process ENet host/client replay and gates on host/client final-state-hash equality. Per-peer network JSONL and hashes remain diagnostic only. `ReplayDriver` suppresses live auto `publish_attack_flow` snapshots during replay because the replay file already contains captured `PublishAttackFlowCommand` entries. Each L/M slice that touches modal/network/replay/command-submission flow must run `bash scripts/run_baseline_traces.sh --all`. | low | done | no |
| **L1** | **Complete.** Introduced `ModalRouter` ([`src/scenes/game_board/modal_router.gd`](../src/scenes/game_board/modal_router.gd), Node) as the single `CommandProcessor.command_executed` subscriber for projection-driven HUD, modal, and mirror routing. [`command_router_adapter.gd`](../src/scenes/game_board/command_router_adapter.gd) is now the composition root and delegates non-modal command reactions into the router. The former adapter `PlayMode.is_network()` branch was removed, dropping the lint allow-list from 11 to 10. Hot-seat still keeps direct lifecycle callbacks for the L2-L5 surfaces. | medium | done | yes |
| **L2** | **Complete.** Migrated **Activation modal** lifecycle to projection in hot-seat. `ShipActivationController` now prepares activation context before `ActivateShipCommand`, submits `advance_activation_step` in both modes, and leaves activation modal open/reopen to `ModalRouter` consuming the projected `UIIntent`. `ModalRouter` opens closed activation modals only for activation lifecycle commands (`activate_ship`, `convert_dial_to_token`, `advance_activation_step`) so unrelated repair/squadron spend commands do not reopen the modal mid-panel. `AttackPanelController` now handles `resolve_immediate_effect` cleanup through the same idempotent command reaction in both modes. Lint dropped from 10 to 8 allow-listed branches. | high | done | yes |
| **L3** | **Complete.** Migrated **Squadron-command activation modal** lifecycle to projection. `UIProjector.UIIntent` now carries `affordances["activation_sequence_button"]`, `SQUADRON_STEP` projects to the command-mode Squadron modal, and `ModalRouter` opens `ShipActivationController.open_squadron_command_from_interaction_state()` only from the authoritative `advance_activation_step("squadron_step")` edge. The token-convert hot-seat-only branch and command-mode squadron close direct button callback were removed; the lint floor dropped from 8 to 7 allow-listed branches. | high | done | yes |
| **L4** | **Complete.** Migrated **Displacement modal** lifecycle to projection in hot-seat. [`displacement_controller.gd`](../src/scenes/game_board/displacement_controller.gd) `start()` is now an effect of `SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE`, opened by `ModalRouter` after `StartDisplacementCommand` projects the authoritative flow. The maneuver producer now only submits `start_displacement`; both modes consume `interaction_flow.controller_player` so RRG "Overlapping", p.8's non-moving-player controller rule has one modal origin. Removed the §3.1a displacement-modal-origin allow-list site and added hot-seat/network router coverage in `test_modal_router.gd`. MT follow-ups fixed the no-repair-action `REPAIR_STEP` stall, CF-token reroll mirror sync, Squadron-command decline affordance, and stale activation auto-skip timers. | medium | done | yes |
| **L5** | **Complete.** Migrated **`_on_active_player_changed` content fork** to a single projected turn-transition path. `UIProjector.project_turn_transition()` now describes shared-screen handoff, active-player banners, passive waiting state, command-dial startup, Squadron observer startup, and camera/card perspective. [`game_board.gd`](../src/scenes/game_board/game_board.gd) applies that `UIIntent` without a `PlayMode.is_network()` lifecycle branch, dropping the lint floor from 6 to 5 allow-listed branches. | high | done | yes |
| **L6** | **Complete.** Lint tightening: `LoadGameDialog` now centralises its deployment-mode query in `_is_network_session()`, so hot-seat save blocking and host-side network-load broadcast derive from one load-dialog surface. `bash scripts/lint_phase_k.sh` now reports **4** allow-listed branches, meeting the post-L floor, and [.github/copilot-instructions.md](../.github/copilot-instructions.md) §7 documents that floor. | low | done | no |
| **L7** | **Complete.** Manual-test sweep passed in hot-seat and network. Automated pre-flight passed (`148 / 2 956 / 5 629`, lint `0 violations (4 allow-listed branches)`, `run_baseline_traces.sh --all` hot-seat trace/state + network peer-state equality). Network-mode annotations were created for the three lifecycle-anchored regression cases: `activation modal auto skip attack: pass`, `brace order test: pass`, and `displacement test: pass`. Annotation JSON files remain local ignored runtime evidence under `saves/annotations/`, not committed fixtures. | trivial (test only) | done | yes |

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

1. `bash scripts/lint_phase_k.sh` shows <= 4 allow-listed branches, none of them in `src/scenes/game_board/` for modal lifecycle (down from the current 7 after L3).
2. A `match`-style audit of the modal-open call sites shows each modal type opens through `ModalRouter` exclusively, with no direct calls remaining.
3. Test baseline: >= 147 scripts / >= 2 942 tests / >= 5 585 asserts / 0 failures (current baseline preserved or grown). The known post-summary Godot shutdown abort is tracked separately from GUT failures.
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
| **M0** | **COMPLETE 2026-05-14** - Author the **natural-language master document** [docs/game_flow.md](game_flow.md). One block per `(flow_id, step_id)` pair currently emitted by `interaction_flow`. Each block: controller role, allowed commands, visible modals, citations, transitions. Use the inventory from L0 + the existing `tests/unit/test_ui_projector.gd` cases as ground truth. **No code changes.** | low | +0 (docs) | no |
| **M0.5** | **COMPLETE 2026-05-15** - **Model-fitness review.** With `docs/game_flow.md` complete, do a deliberate reread asking three questions per (flow, step) block: (a) does `InteractionFlow.flow_type / step_id / controller_player / payload` carry every piece of information the prose requires? (b) are any two prose blocks describing what is logically the same step under different names (model duplication)? (c) does any prose block describe behaviour the current `GameCommand` set cannot express? Outcome: a short `docs/game_flow.md` §0 "Model fitness" subsection with the answers. If all three are clean (expected), proceed to M1. If any answer reveals a genuine model defect, stop and convert that defect into a separate, scoped slice before M1 — do **not** absorb model changes into M1's spec encoding. **Worked example to include in the review (do not skip):** the 2026-05-11 displacement bug (`c673ef0`) — RRG "Overlapping", p.8: *"the player who is NOT moving the ship places the overlapped squadrons, regardless of who owns them."* The producer in [`start_displacement_command.gd`](../src/core/commands/start_displacement_command.gd) had to invent `controller_player = 1 - maneuver_ship.owner_player` because no central declaration pinned that mapping. M0.5 confirms that `controller_role` is a *first-class column* of every FlowSpec entry (with enum values `ACTIVE_PLAYER`, `OPPOSING_PLAYER`, `DEFENDER`, `ATTACKER`, …); M1 encodes the roles and M2.5 migrates producers so this bug class becomes testable and syntactically hard to reintroduce. **No code changes.** | trivial | +0 (docs) | no |
| **M0.6** | **COMPLETE 2026-05-16** - **Runtime-registry boundary review.** Add a `docs/game_flow.md` §0 subsection that defines the boundary between `EffectRegistry`, `EffectFactory.rebuild_runtime_effects()`, and `RuleRegistry`. Pin the loaded Blinded Gunners bug (`d752ffd`) as the worked example: serialized faceup damage state must activate the accuracy-spend blocker immediately after load. Decide which first-six M rules are pure static predicates and which still need an `EffectRegistry` bridge. **No code changes.** | trivial | +0 (docs) | no |
| **M0.7** | **COMPLETE 2026-05-16** - **Command-scope model.** Add the `GLOBAL` / `PHASE` / `FLOW_STEP` scope taxonomy to `docs/game_flow.md` before adding command declarations. Inventory commands that intentionally run outside `interaction_flow` so M3/M4 do not misclassify replay, setup, phase-advance, or debug commands as illegal. **No code changes.** | low | +0 (docs) | no |
| **M1** | **COMPLETE 2026-05-16** - Added [src/core/state/flow_spec.gd](../src/core/state/flow_spec.gd) (RefCounted) with a static `_SPEC` table translating [docs/game_flow.md](game_flow.md) into machine form. Added `Constants.ControllerRole` with the exact §3.2 role set and `tests/unit/test_flow_spec.gd` coverage for every documented/enum-backed `(flow_id, step_id)` pair, including projection-only rows not covered by `tests/unit/test_ui_projector.gd`. Tests cover `get_spec()` empty-dictionary behaviour, `has_spec()`, deep-copy protection, `resolve_controller_player(...)`, and the `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE -> OPPOSING_PLAYER` regression. Verification: 149 / 2 976 / 5 754 GUT baseline, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | low | +260 / 0 | no |
| **M2** | **COMPLETE 2026-05-16** - Wired `UIProjector.project()` to consult `FlowSpec.get_spec(...)` for `controller_role` and `modals`. The former hard-coded modal switch now reads FlowSpec modal metadata, with invalid/no-step rows projecting `NONE`. Projection uses `EITHER_PLAYER` and system/no-controller roles from FlowSpec while preserving resolved `controller_player` fallback for legacy no-step rows. `project_turn_transition()` now carries an explicit boundary note: handoff/waiting/banner surfaces remain outside FlowSpec because they are not persisted `interaction_flow` rows. Verification: focused UIProjector + FlowSpec tests 49 / 216, full GUT 149 / 2 976 / 5 754, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | medium | +90 / −120 | yes |
| **M2.5** | **COMPLETE 2026-05-16** - **Producer controller contract.** Added `FlowSpec.make_interaction_flow(...)` as the producer-safe helper for resolved `InteractionFlow.controller_player` snapshots and migrated command/FSM producers through it. `StartDisplacementCommand` now derives the placement controller from `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE -> OPPOSING_PLAYER` and treats payload `controller_player` as an optional compatibility check rather than the source of truth. `PublishAttackFlowCommand` and `AttackFlowFSM` resolve attacker/defender/chooser ownership from FlowSpec context while preserving legacy snapshot fallback when older attack payloads lack identity fields. Activation, squadron, phase-advance, maneuver, and activation-step producers now write existing controller values through the FlowSpec active-player role. Added focused producer coverage for displacement's non-moving-player controller, attack defender/attacker/chooser fallback, and the new helper. Verification: full GUT 149 / 2 982 / 5 761 with 0 failures (known post-summary Godot abort), Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | medium | +80 / −40 | yes |
| **M3** | **COMPLETE 2026-05-16** - **Parity gate I.** Added [command_applicability.gd](../src/core/commands/command_applicability.gd) with static `GLOBAL` / `PHASE` / `FLOW_STEP` declarations for every registered production command and added `Constants.CommandScope`. [test_command_applicability.gd](../tests/unit/test_command_applicability.gd) isolates the production `CommandProcessor` registry, fails on missing or stale declarations, validates target shape, and checks FLOW_STEP pairs against `FlowSpec.allowed_commands`. `resolve_immediate_effect` is deliberately `PHASE: SHIP, SQUADRON` so attack immediates and debug-deal-damage follow-ups both remain represented. No runtime gate consumes the metadata yet. Verification: focused M3 tests 20 / 39, full GUT 150 / 2 992 / 5 774 with 0 failures (known post-summary Godot abort), Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | low | +340 / 0 | no |
| **M4** | **COMPLETE 2026-05-16** - **Parity gate II.** `CommandProcessor.submit()` now consults `CommandApplicability.check_command(...)` before calling `cmd.validate()`. `GLOBAL` commands bypass the flow/phase pre-flight, `PHASE` commands check `GameState.current_phase`, and `FLOW_STEP` commands require both a declared `(flow, step)` pair and agreement with `FlowSpec.allowed_commands`. Rejections use structured reasons such as `command X not allowed in step Y` and occur before command-specific validation. Added [test_command_processor_applicability.gd](../tests/unit/test_command_processor_applicability.gd) coverage for FLOW_STEP, PHASE, GLOBAL, missing-declaration, cleared-flow activation/squadron surfaces, attack immediate effects, and debug-deal-damage follow-ups. Replay gate refined the M3 inventory: controller-prevalidated attack commands, activation starters, movement, repair, and activation-end commands remain `PHASE` until later slices publish precise flow rows for every producer. MT annotations added the no-target Attack auto-advance fix: projected `ATTACK_STEP` with no targets now submits `advance_activation_step("maneuver_step")` through [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) instead of relying on a local modal refresh/reopen. Verification: focused M4 tests 43 / 163, activation-flow regression tests 56 / 105, full GUT 151 / 3 007 / 5 805 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, `git diff --check` clean, and baseline traces passing hot-seat trace/state plus network peer equality. | medium | +60 / 0 | yes |
| **M5** | **COMPLETE 2026-05-16** - Added [rule_registry.gd](../src/core/effects/rule_registry.gd), [flow_hook.gd](../src/core/effects/flow_hook.gd), and [rule_bootstrap.gd](../src/autoload/rule_bootstrap.gd). The registry is a static Phase M catalogue only: validators, modifiers, observers, blockers, and enablers can be declared and deterministically sorted, but the production bootstrap rule list is empty and no legacy `EffectRegistry` behaviour is replaced. `RuleBootstrap` runs before `CommandProcessor` and clears/replays registered rule scripts at startup; M5 intentionally invokes zero scripts. Tests cover empty hook queries for every FlowSpec pair, canonical `register_rule(...)` ids, deterministic ordering, and empty-bootstrap cleanup. Verification: focused M5 tests 14 / 116, full GUT 154 / 3 021 / 5 921 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | low | +180 / 0 | no |
| **M6** | **COMPLETE 2026-05-17** - `CommandProcessor.preflight()` now keeps the M4 applicability gate first, then runs `RuleRegistry.validators_for(flow, step, cmd.command_type)` in deterministic order before command-specific validation; first denial wins. `CommandProcessor` also owns the §3.3.1 observer FIFO: observers are collected before `command_executed`, drained after the triggering emit returns, rejected if they submit synchronously during collection, suppressed during replay, and suppressed on passive network mirrors. Network host/server paths use deferred submission so the triggering command is broadcast before observer follow-ups drain through the network-aware submitter. `AttackDiceResolver.apply_gather_hook()` now runs `RuleRegistry.modifiers_for(flow, step, "dice_pool")` after the legacy `EffectRegistry` `ATTACK_GATHER_DICE` hook, preserving existing behaviour with the empty production registry. Tests cover validator ordering, applicability-before-validator ordering, observer queue timing, replay/mirror suppression, synchronous observer-submit rejection, the rule-file guard, and dice-pool modifier stacking with the legacy registry. Verification: focused M6/M4/M5 regression set 6 scripts / 81 tests / 228 asserts, full GUT 155 / 3 031 / 5 947 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | medium | +170 / 0 | no |
| **M7** | **COMPLETE 2026-05-17** - Migrated **rule 1: Faulty Countermeasures** into [faulty_countermeasures.gd](../src/core/effects/rules/damage_cards/ship/faulty_countermeasures.gd), registered through [rule_bootstrap.gd](../src/autoload/rule_bootstrap.gd) as a single wildcard `VALIDATOR` hook for `ATTACK / ATTACK_DEFENSE_TOKENS` defense-token commands. The predicate reads active state from `ShipInstance.faceup_damage` and the selected/commanded token state, rejecting exhausted defense tokens for both `commit_defense` and `spend_defense_token` while letting invalid payloads fall through to canonical command validation. The legacy `DEFENSE_VALIDATE_TOKEN` `EffectRegistry` path remains as the UI-side bridge for `blocked_defense_token_indices` during Phase M. [test_rule_faulty_countermeasures.gd](../tests/unit/test_rule_faulty_countermeasures.gd) covers command-time registration, commit rejection, ready-token allowance, no-card allowance, other-ship isolation, and save/load plus `EffectFactory.rebuild_runtime_effects()` parity. MT found the marker-command/UI-affordance gap; the fix and the reusable workflow are documented in §3.5, [.github/skills/rule-integration/SKILL.md](../.github/skills/rule-integration/SKILL.md), and [src/core/effects/rules/README.md](../src/core/effects/rules/README.md). Verification: focused M7 regression set 5 scripts / 90 tests / 199 asserts with 0 failures, full GUT 156 / 3 040 / 5 982 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, baseline traces passing hot-seat trace/state plus network peer equality, and user MT pass. | low | +120 / 0 | yes |
| **M8** | **COMPLETE 2026-05-17** - Migrated **rule 2: Compartment Fire** into [compartment_fire.gd](../src/core/effects/rules/damage_cards/ship/compartment_fire.gd), registered through [rule_bootstrap.gd](../src/autoload/rule_bootstrap.gd) as a `MODIFIER` hook for `STATUS_CLEANUP / STATUS_CLEANUP_STEP` target `defense_token_readying`. [status_phase_cleanup_command.gd](../src/core/commands/status_phase_cleanup_command.gd) now applies RuleRegistry readying modifiers before falling back to remaining legacy status hooks, and [damage_card_effect_factory.gd](../src/core/effects/damage_card_effect_factory.gd) no longer registers Compartment Fire in `EffectRegistry`. Active status is read from each ship's `faceup_damage`, including after save/load plus runtime-effect rebuild, where the legacy bridge count remains zero. M8 also adopts the source-first rule folder grouping under [src/core/effects/rules/README.md](../src/core/effects/rules/README.md). Verification: focused M8 regression set 5 scripts / 93 tests / 171 asserts with 0 failures, full GUT 157 / 3 046 / 6 007 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus network peer equality. | low | +90 / −40 | yes |
| **M9** | **COMPLETE 2026-05-17** - Migrated **rule 3: Damaged Munitions** into [damaged_munitions.gd](../src/core/effects/rules/damage_cards/ship/damaged_munitions.gd), registered through [rule_bootstrap.gd](../src/autoload/rule_bootstrap.gd) as a `MODIFIER` hook for `ATTACK / ATTACK_ROLL` target `dice_pool`. [attack_dice_resolver.gd](../src/core/combat/attack_dice_resolver.gd) now exposes full `EffectContext` metadata for pre-roll choices and can apply one selected RuleRegistry pool modifier without rerunning legacy gather effects. [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) publishes a `pending_die_removal` payload when multiple colours are available, reuses the attack-panel die-choice section, applies the attacker-selected colour, and republishes the reduced `dice_pool` before obstruction/CF/roll. M9 removes Damaged Munitions from [damage_card_effect_factory.gd](../src/core/effects/damage_card_effect_factory.gd) while leaving Point-Defense Failure on the legacy bridge for M10. The predicate reads active state from the attacking ship's `faceup_damage` and applies only against ship defenders, including after save/load plus `EffectFactory.rebuild_runtime_effects()` with zero legacy Damaged Munitions effects. Verification: focused M9 regression set 5 scripts / 169 tests / 254 asserts with 0 failures, full GUT 158 / 3 062 / 6 072 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, `git diff --check` clean, baseline traces passing hot-seat trace/state plus network peer equality, and user MT pass. | low | +90 / −40 | yes |
| **M10** | **COMPLETE 2026-05-17** - Migrated **rule 4: Point-Defense Failure** into [point_defense_failure.gd](../src/core/effects/rules/damage_cards/ship/point_defense_failure.gd), registered through [rule_bootstrap.gd](../src/autoload/rule_bootstrap.gd) as a `MODIFIER` hook for `ATTACK / ATTACK_ROLL` target `dice_pool`. The predicate reads active state from the attacking ship's `faceup_damage`, applies only against squadron defenders, exposes the same `pending_die_removal` metadata as Damaged Munitions when multiple colours are available, and applies the attacker-selected colour before obstruction/CF/roll. [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) now handles RuleRegistry pre-roll die removals generically by rule id instead of naming a specific card. M10 removes Point-Defense Failure from [damage_card_effect_factory.gd](../src/core/effects/damage_card_effect_factory.gd), and save/load coverage proves `EffectFactory.rebuild_runtime_effects()` leaves zero legacy Point-Defense Failure effects while the RuleRegistry modifier still applies. Verification: focused M10 regression set 4 scripts / 76 tests / 173 asserts with 0 failures, full GUT 159 / 3 071 / 6 110 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, baseline traces passing hot-seat trace/state plus network peer equality, and user MT pass. | low | +90 / −40 | yes |
| **M11** | **COMPLETE 2026-05-18** - Migrated **rule 5: Crew Panic** into [crew_panic.gd](../src/core/effects/rules/damage_cards/ship/crew_panic.gd), registered through [rule_bootstrap.gd](../src/autoload/rule_bootstrap.gd) as an `ENABLER` hook for `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT` target `command_dial_reveal`. [UIProjector](../src/core/network/ui_projector.gd) now merges RuleRegistry enabler affordances, projecting `crew_panic_choices` from active `faceup_damage` plus hidden-dial state. [ship_card_panel.gd](../src/ui/ship/ship_card_panel.gd) invokes a generic pre-reveal handler before `reveal_dial`, so Crew Panic prompts on the first hidden-dial click rather than after reveal. Discard submits `spend_dial(mode=discard)` then command-backed `activate_ship(skip_reveal=true)`; damage submits `persistent_effect_damage` and then reveals normally. M11 removes Crew Panic from [damage_card_effect_factory.gd](../src/core/effects/damage_card_effect_factory.gd). Verification: unit suite 151 scripts / 2 947 tests / 5 857 asserts with 0 failures, full GUT 160 / 3 079 / 6 131 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, baseline traces passing hot-seat trace/state plus network peer equality, and user MT pass confirmed 2026-05-18. | medium | +120 / −80 | yes |
| **M12** | **COMPLETE 2026-05-18** - Migrated **rule 6: Capacitor Failure** into [capacitor_failure.gd](../src/core/effects/rules/damage_cards/ship/capacitor_failure.gd) as a one-rule/multiple-hooks example. The rule registers attack defense-token validators and blockers for `commit_defense`, `spend_defense_token`, and `select_redirect_zone`, plus repair-step validators and blockers for `repair_action` shield recovery/move targets. Active state comes from `ShipInstance.faceup_damage`; defense and repair helper UI eligibility consumes RuleRegistry blocker metadata, and [damage_card_effect_factory.gd](../src/core/effects/damage_card_effect_factory.gd) no longer rebuilds a legacy Capacitor Failure effect. Verification: focused M12 test 1 script / 12 tests / 57 asserts, focused bridge/helper regressions all green, full GUT 161 / 3 088 / 6 188 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, baseline traces passing hot-seat trace/state plus network peer state equality, `git diff --check` clean, and user MT pass confirmed 2026-05-18. | medium | +110 / −60 | yes |
| **M13** | **COMPLETE 2026-05-19** - Added [test_rule_order_replay.gd](../tests/integration/test_rule_order_replay.gd), a hot-seat replay-capture determinism guard for RuleRegistry observer ordering. The scenario registers three observer hooks on the same `ATTACK / ATTACK_ROLL` step in deliberately unsorted registration order, records hook ids plus generated follow-up command types, serializes the resulting [GameReplay](../src/core/commands/game_replay.gd) command history, and asserts `(priority DESC, rule_id ASC)` order through both hook callback order and executed follow-up history. It also canonicalizes the replay payload with the baseline trace JSON helper and verifies repeated local hot-seat runs are byte-identical. Network determinism remains covered by the existing L0.5 gate without adding committed network trace/hash fixtures. Verification: exact M13 test 1 script / 3 tests / 8 asserts, full GUT 162 / 3 091 / 6 196 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus real ENet network peer state equality. | low | +140 / 0 | yes |
| **M14** | **COMPLETE 2026-05-19** - Added [dump_flow_coverage.gd](../scripts/dump_flow_coverage.gd), a headless FlowSpec/RuleRegistry coverage tool. Given a `(flow, step)` as positional args or `--flow/--step`, it emits the FlowSpec source, controller role, modal metadata, allowed commands, transitions, rule citation, and every registered RuleRegistry hook for that surface with hook kind, rule id, priority, and command/target. [RuleRegistry](../src/core/effects/rule_registry.gd) now exposes `hooks_for_step()` so tooling can inspect registered hooks without scraping private arrays. [test_dump_flow_coverage.gd](../tests/unit/test_dump_flow_coverage.gd) covers argument parsing, FlowSpec metadata output, deterministic hook output, and invalid-pair diagnostics. Verification: focused M14 test 1 script / 5 tests / 13 asserts, headless smoke `ATTACK / ATTACK_ROLL` exits 0 and reports 2 dice-pool rule hooks, full GUT 163 / 3 096 / 6 209 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus real ENet network peer state equality. | low | +80 / 0 | yes |
| **M15** | **COMPLETE 2026-05-19** - Closed Phase M by updating [implementation_plan.md](implementation_plan.md) §1 baseline, §2 phase status, and §4 open topics; promoted the new-rule workflow into [.github/copilot-instructions.md](../.github/copilot-instructions.md) as Non-Negotiable Rule §12; and added the Phase M Layer 3 rules architecture block to [.skills/architecture_patterns.md](../.skills/architecture_patterns.md). The guidance now pins `RuleRegistry` as the default extension surface for new rules/card effects/keywords/upgrades/objectives/defense-token eligibility and rule-derived UI affordances, while preserving `EffectRegistry` only as a documented transient bridge rebuilt from serialized state. Verification: `git diff --check` clean, full GUT 163 / 3 096 / 6 209 with 0 failures, Phase K lint 0 violations / 4 allow-listed branches, and baseline traces passing hot-seat trace/state plus real ENet network peer state equality. | trivial | +0 (docs) | no |

M0.5 findings now reflected in [docs/game_flow.md](game_flow.md) §0.1 and
carried forward into M1-M4 planning:

- `InteractionFlow` remains fit for M1: `flow_type`, `step_id`, resolved
   `controller_player`, `visible_to`, and JSON-safe `payload` can carry the
   current prose requirements. M1 must add semantic `controller_role` to
   `FlowSpec` while keeping `InteractionFlow` as the resolved runtime snapshot.
- No blocking duplicate-step model defect was found. Legacy/projected rows such
   as `REVEAL_DIAL`, `SPEND_DIAL`, `SQUAD_MOVE`, `SQUAD_ATTACK`,
   `STATUS_CLEANUP_STEP`, and `GAME_OVER_STEP` stay in M1 for parity with
   `Constants`/`UIProjector`; M3/M4 must handle them through applicability
   declarations rather than renaming or dropping them.
- No current-command expressivity blocker was found. The current command set
   can express durable actions and produced flows, but M0.7/M3 must classify
   phase/system/projection-only surfaces as `GLOBAL`, `PHASE`, or `FLOW_STEP`
   before command gating lands.
- The displacement bug class remains the controller-role worked example:
   `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` is semantically
   `OPPOSING_PLAYER` (the non-moving player), so future producers must derive
   the resolved `controller_player` from `FlowSpec` instead of accepting an
   ad-hoc value.

M0.6 findings now reflected in [docs/game_flow.md](game_flow.md) §0.2 and
carried forward into M5-M12 planning:

- `EffectRegistry` remains the transient legacy hook executor during M; it is
   not serialized and must be rebuilt from authoritative entities by
   `EffectFactory.rebuild_runtime_effects()` after load.
- `RuleRegistry` is a static rule-definition catalogue, not an active-state
   store. Migrated predicates must read `GameState` entities directly or use a
   typed bridge that is rebuilt from those entities.
- The loaded Blinded Gunners bug (`d752ffd`) is the acceptance example: a
   serialized `faceup_damage.effect_id == "blinded_gunners"` must block accuracy
   spending immediately after deserialize + install in hot-seat, network, and
   replay.
- First-six rule boundary: Faulty Countermeasures, Compartment Fire, Damaged
   Munitions, Point-Defense Failure, Crew Panic, and Capacitor Failure target
   pure `RuleRegistry` predicates after their slices. Crew Panic is now a
   projected ENABLER affordance with no legacy `EffectRegistry` bridge.

M0.7 findings now reflected in [docs/game_flow.md](game_flow.md) §0.3 and
carried forward into M3-M4 planning:

- Command applicability has three scopes: `GLOBAL` bypasses flow/phase gates
   for sync, debug, and cleanup commands; `PHASE` declares allowed
   `Constants.GamePhase` values without requiring a modal step; `FLOW_STEP`
   declares explicit `(flow_type, step_id)` pairs from `FlowSpec`.
- Every currently registered command type is inventoried with a proposed M3
   scope. M3's parity test should fail on any new command missing a matching
   declaration.
- `publish_attack_flow` is deliberately `GLOBAL` because it writes the attack
   flow snapshot; gating it by the current step would block the synchronization
   command that keeps peers and replay aligned.
- `resolve_immediate_effect` must remain conservative in M3/M4. The normal
   attack UI path is `ATTACK_RESOLVE_DAMAGE` / `ATTACK_CRITICAL_CHOICE`, but
   debug-dealt immediate damage cards can submit the same command outside
   `ATTACK`, so an attack-only declaration would be a regression. The M3
   declaration should be `PHASE: SHIP, SQUADRON`, matching the command's
   existing `validate()` contract.
- Conservative `PHASE` declarations are intentional for broad utility and
   legacy effect surfaces (`spend_dial`, `spend_token`, `discard_token`,
   `set_speed`, `persistent_effect_damage`) until later slices give each path
   a precise projected step or migrated rule hook.
- The first M4 behaviour gate should preserve existing command legality before
   narrowing declarations. Tightening a `PHASE` command to `FLOW_STEP` belongs
   in the slice that adds the missing flow surface and regression coverage.
- M3 now encodes the inventory in `CommandApplicability`; M4 should consume
   that table without changing declaration scope in the same slice unless a
   failing regression test proves the M0.7 classification was too broad or too
   narrow.
- M4 replay gates proved several M3 declarations were too narrow for current
   runtime producers: attack commands can be submitted from legacy activation
   flow rows, activation starters can begin from cleared phase flow, and ship
   activation cleanup can run after attack flow clears. These commands now
   stay `PHASE`-scoped to match their existing validators; future tightening
   must first add the missing producer flow rows and regression coverage.
- M4 manual annotations proved activation auto-skip must be authoritative, not
   modal-local. When a projected `ATTACK_STEP` has no targets, the controller
   now submits `advance_activation_step("maneuver_step")`; otherwise a refresh
   can leave `GameState.interaction_flow` stuck at `ATTACK_STEP` while the
   modal's local `ShipActivationState` moves on to Maneuver.

### 5.2 Acceptance criteria for closing Phase M

1. `tests/unit/test_flow_spec.gd` covers 100% of valid pairs listed in `docs/game_flow.md` §1 and detailed sections, and asserts those names still exist in `Constants`. This is not the enum cross-product; projection-only/legacy rows are included in `_SPEC` with `source = "projection_only"`. New documented pair -> CI fails until FlowSpec and projector expectations are updated.
2. FlowSpec exposes the exact `Constants.ControllerRole` enum from §3.2 plus a producer-safe resolver/helper for resolved `controller_player`; interaction-flow producers use that helper. Regression tests cover every role's success path, the unresolved `-1` failure path, displacement's non-moving-player controller, and attack/activation ownership fallbacks.
3. Every `GameCommand` subclass declares an applicability scope plus its allowed phases or `(flow_id, step_id)` pairs. Static parity test enforces this, including a fixture proving `resolve_immediate_effect` is `PHASE: SHIP, SQUADRON` rather than attack-only while debug immediate effects still exist.
4. `CommandProcessor.submit()` rejects a command whose declaration does not include the current flow/phase surface. Tested for `FLOW_STEP`, `PHASE`, and `GLOBAL` commands, including attack immediate effects and debug-deal-damage immediate follow-ups in Ship/Squadron phases.
5. `RuleRegistry` contains the 6 migrated rules/effects or documented bridges for any legacy `EffectRegistry` rule retained during M. Adding a 7th is reproducibly a one-file change (write rule + add to bootstrap list) unless it intentionally bridges a legacy effect.
6. Save/load regression covers at least one migrated persistent damage-card rule, including the loaded Blinded Gunners failure class.
7. Observer hooks use the §3.3.1 deferred follow-up queue; no migrated rule submits synchronously during `CommandProcessor.command_executed`, replay does not synthesize duplicate follow-ups, and rule files are guarded against direct `CommandProcessor.submit` / `GameManager.submit_` calls.
8. Determinism replay test green, including hook-order/follow-up-order capture for repeated hot-seat runs and same-run ENet host/client equality.
9. Test baseline: >= 148 scripts / >= 2 956 tests / >= 5 629 asserts / 0 failures; `bash scripts/lint_phase_k.sh` exits 0; `bash scripts/run_baseline_traces.sh --all` passes for any slice touching modal, replay, network, command-submission, or rule-observer flow.

---

## 6. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| L2/L3/L5 hot-seat modal migration breaks observable UX (timing, animations) | Medium | High | Each slice gated by manual test L7-style comparison. Incremental: one modal type at a time. Snapshot test of `UIIntent` per scenario step keeps regressions tight. |
| Hot-seat affordances (sequence button) don't have a clean network equivalent | Medium | Medium | L3 explicitly migrates affordances through `UIIntent.affordances`. If a true asymmetry remains, document it as an `affordance_kind` value with a clear semantic, not a `PlayMode` branch. |
| FlowSpec entries drift from runtime (someone adds a step without updating the spec) | Medium | High | M1 parity tests compare FlowSpec against the valid pair inventory in `docs/game_flow.md`, `Constants`, and projector expectations, including legacy/projected pairs marked with `source = "projection_only"`. M3/M4 parity tests fail on unknown commands. Two safety nets. |
| Rule self-registration ordering causes peer divergence | Low | Critical | M5 + M13 enforce sort order `(priority DESC, rule_id ASC)` and a determinism replay test. Static rule list — no dynamic registration after autoload. |
| Existing keyword/effect bridges break during M7-M12 migration | Medium | High | One rule/effect per slice; existing tests retained; new test added for migrated rule. Broader keyword migration is out of scope; old in-resolver or legacy bridge code is removed only after the new path is proven by the new test. |
| Runtime effect/rule registry not rebuilt after load (loaded Blinded Gunners class) | Medium | Critical | M0.6 defines the `EffectRegistry` / `RuleRegistry` boundary before code migration. Every persistent damage-card migration includes a save/load regression. `EffectFactory.rebuild_runtime_effects()` remains authoritative for legacy runtime hooks until a rule is fully migrated. |
| Observer hook submits follow-up command synchronously during network command broadcast | Medium | Critical | M6 introduces the §3.3.1 deferred follow-up queue and forbids synchronous observer submission from inside `CommandProcessor.command_executed`. Network replay gate must pass for any slice that adds observer hooks. |
| Save format break | Low | Critical | `interaction_flow` JSON shape unchanged; FlowSpec and RuleRegistry are computed/runtime-only; active rule state remains derived from serialized entities. Pin save format version if a slice must add serialized fields. |
| Replay break | Low | Critical | Replay determinism gated by M13. Run `bash scripts/run_baseline_traces.sh --all` locally on every L/M slice that touches modal, replay, network, command-submission, or rule-observer flow. |
| Scope creep ("while we're at it, let's redesign…") | High | Medium | Slice list is fixed. Every additional change must land as a separate phase (Phase N candidate). |
| Stale line/LOC references inside this plan (drafted 2026-05-10 against `game_board.gd` ≈ 3 055 LOC; file is now 1 464 LOC after K8/K10/K11/K12/K13) | Medium | Low | L0 already refreshed the inventory in `modal_classification.md` §L-Inventory. Treat the §4.1 slice descriptions as role-based (file + symbol + lint-allow-list entry), never as `:NNNN` line addresses. |
| New producer adds a `controller_player` ad-hoc instead of consulting FlowSpec (the 2026-05-11 displacement defect class) | Medium | High | M1 lands `FlowSpec.controller_role(flow_id, step_id) -> ControllerRole`; M2.5 migrates producers through a resolver/helper and adds focused controller regression tests. Worked example pinned in §5.1 M0/M0.5. |

---

## 7. How this aligns with existing plans

### 7.1 Phase K dependency

Phase K and Phase L are complete for LM purposes. The M0 game-flow master
document, M0.5 model-fitness review, M0.6 runtime-registry boundary review,
and M0.7 command-scope model are complete; the next LM slice is **M1
FlowSpec encoding**.

Required Phase K foundations are present:

1. **K12 (`CommandRouterAdapter`) committed (`e17ff05`).** This is the single
   `CommandProcessor.command_executed -> UIProjector.project` subscription point that
   L1's `ModalRouter` extends.
2. **K7 lint script in place and green.** `scripts/lint_phase_k.sh` currently
   reports `0 violations (4 allow-listed branches)`. L6 met the
   post-L allow-list floor.
3. **K14 (`AttackFlowExecutor`) committed (K14a `454fd0e` -> K14g
   `33e697f`).** Attack-flow payload construction, defense-commit canonical
   ordering, faceup/immediate-effect decision, and redirect continuation live
   in [src/core/combat/attack_flow_executor.gd](../src/core/combat/attack_flow_executor.gd)
   with isolated unit coverage in [tests/unit/test_attack_flow_executor.gd](../tests/unit/test_attack_flow_executor.gd).
4. **L4 (`ModalRouter` displacement projection) complete.** The direct hot-seat
   `_displacement_controller.start()` call was removed from [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd);
   [modal_router.gd](../src/scenes/game_board/modal_router.gd) opens the displacement modal from the projected
   `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` intent in hot-seat and network.

Current post-fix snapshot (2026-05-14):

| File | LOC | Status |
|---|---:|---|
| [src/scenes/game_board/game_board.gd](../src/scenes/game_board/game_board.gd) | 1 462 | Under the Phase K 2 000 LOC ceiling. |
| [src/scenes/game_board/attack_executor.gd](../src/scenes/game_board/attack_executor.gd) | 2 479 | Over the long-term 1 500 LOC target; do not add new responsibilities. |
| [src/autoload/game_manager.gd](../src/autoload/game_manager.gd) | 2 271 | Over the long-term 1 500 LOC target; new behaviour belongs in focused helpers/controllers. |
| [src/autoload/save_game_manager.gd](../src/autoload/save_game_manager.gd) | 1 061 | Still a split candidate; LM should not grow it. |
| [src/scenes/game_board/command_router_adapter.gd](../src/scenes/game_board/command_router_adapter.gd) | 100 | Composition root for command-router projection paths. |
| [src/core/network/ui_projector.gd](../src/core/network/ui_projector.gd) | 182 | Pure `GameState.interaction_flow` projector; L3 added activation-sequence affordances. |
| [src/scenes/game_board/modal_router.gd](../src/scenes/game_board/modal_router.gd) | 248 | Projection-driven modal and HUD router introduced in L1, extended for activation lifecycle in L2 and squadron-command entry in L3. |
| [src/scenes/game_board/ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | 1 449 | Owns activation modal details; L2 removed the activation-step network-only submit branch and L3 moved command-mode squadron entry behind projection. |
| [src/scenes/game_board/squadron_phase_controller.gd](../src/scenes/game_board/squadron_phase_controller.gd) | 822 | Owns SquadronActivationModal; L3 removed its direct command-mode activation-button callback. |

Recommended next sequence:

1. Begin M1 from the current post-M0.7 docs baseline.
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

### Before starting M1

1. Confirm the current baseline includes L0/L0.5, L1, L2, L3, L4, L5, L6, L7, M0, M0.5, M0.6, M0.7, and the loaded-save
   persistent-effect fix (`d752ffd`).
2. Confirm `bash scripts/lint_phase_k.sh` exits `0` with 4 allow-listed
   branches after L6.
3. Confirm the GUT green summary baseline is at least 148 scripts / 2 947
   tests / 5 597 asserts / 0 failures. The known post-summary Godot shutdown
   abort is not a test failure.
4. Run `bash scripts/run_baseline_traces.sh --all` before starting any modal,
   network, replay, command-submission, or rule-observer slice.
5. Start a focused branch for M1 (`phase-m/flow-spec`) and keep replay
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
concrete acceptance gates), *aligned* (Phase K and Phase L complete;
unblocks G4.7+ after Phase M), and *minimally invasive* (no save format break,
no new RPC, no new EventBus channel, no wholesale replacement of existing
runtime-effect primitives).

**Verdict: safe to begin M1 next.** Phase L closed with hot-seat and network
manual-test parity, M0 captured the game-flow master document, M0.5 found no
blocking `InteractionFlow` model defect, M0.6 pinned the runtime-registry
boundary, M0.7 classified command scopes, and the replay/lint gates are
already in place for Phase M.

# Phase I — Interaction-Flow as Domain State

> Star Wars: Armada — Digital Edition
> Created: 2026-04-25
> Status: **PROPOSED**
> Predecessors: Phases A–H ✅, G4.1–G4.6 ✅, G4.6.5 ⏳, G4.6.6 T1a C1–C8 🔄
> Supersedes: G4.6.6 T1a producer-by-producer broadcast strategy

---

## 0. Why This Phase Exists

Network integration has stalled because cross-client UI synchronization is
implemented as a **second authoritative channel** (`NetworkInteractionState`
RPC) running in parallel with `command_result`. Every modal/sidebar/HUD
consumer has to be wired separately on the producer side, kept in order with
`requires_seq`, and shadowed by an active-player fallback. Coverage is
partial (sidebar, activation modal, squadron modal, HUD) and the attack
sub-FSM cannot be added under this model without ~40 producer call sites.

Root cause from `docs/architecture_assessment.md` §4.6 and §7.2:

- Attack sub-phases are an **implicit FSM driven by ~40 vars in `attack_executor.gd`**.
- `game_board.gd` (2 549 LOC) owns modal lifecycle and sprinkles
  `PlayMode.is_network()` / `NetworkManager.is_server()` branches throughout.
- Interaction state lives in active-client RAM, so reconnection cannot
  reconstruct it.

**Phase I promotes interaction-flow state to a serializable field of
`GameState`.** Once it is part of the snapshot, it travels for free over
`command_result`, replays correctly under `is_replaying`, survives
reconnection, and lets us delete the parallel `NetworkInteractionState`
channel and the `is_network()` branches in `game_board.gd`.

---

## 1. Target Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          PRESENTATION                            │
│                                                                  │
│  GameBoard (orchestrator, ~1 900 LOC after I7)                   │
│      │                                                           │
│      ├─ UIProjector  ◀────────────  reads GameState only          │
│      │     decides: which modal is open, who can interact        │
│      │     output: pure data → controllers/widgets                │
│      │                                                           │
│      ├─ Controllers (C1–C7, AttackUIController)                  │
│      └─ Modals / Widgets / Sidebar                               │
│                          ▲                                       │
│           reads only     │      no direct GameState mutation     │
│                          │                                       │
├──────────────────────────┼───────────────────────────────────────┤
│                          │                                       │
│                    APPLICATION                                   │
│                                                                  │
│  GameManager   CommandProcessor   AttackFlowFSM (NEW)            │
│                                                                  │
│  ─ Single submission path: GameManager → CommandSubmitter        │
│  ─ Single broadcast path:  CommandProcessor → command_result     │
│  ─ AttackFlowFSM advances InteractionFlow.attack_sub_step        │
│    by issuing GameCommands                                       │
├──────────────────────────────────────────────────────────────────┤
│                       DOMAIN / RULES                             │
│                                                                  │
│  GameState                                                       │
│   ├─ existing fields (round, phase, players, …)                  │
│   └─ interaction_flow: InteractionFlow   ◀── NEW FIELD            │
│                                                                  │
│  InteractionFlow (NEW, RefCounted, serializable)                 │
│   ├─ flow_type:        Constants.InteractionFlow                 │
│   ├─ step_id:          Constants.InteractionStep                 │
│   ├─ controller_player: int    (who must act)                    │
│   ├─ visible_to:       Constants.Visibility (all/owner/spectator)│
│   └─ payload:          Dictionary (step-local data, normalised)  │
│                                                                  │
│  EffectRegistry, ShipInstance, …  (unchanged)                    │
├──────────────────────────────────────────────────────────────────┤
│                          NETWORK                                 │
│                                                                  │
│  NetworkManager        CommandProcessor                          │
│    submit_command   →  validate + execute (server)               │
│    command_result   ←  carries GameState diff incl. flow         │
│                                                                  │
│  REMOVED: NetworkInteractionState RPC, broadcast_interaction_*   │
└──────────────────────────────────────────────────────────────────┘
```

### What changes vs. today

| Component | Today | Target | Change |
|-----------|-------|--------|--------|
| Interaction step truth | `_activation_ctx`, `_attack_executor` vars | `GameState.interaction_flow` field | **Move** |
| Cross-client UI sync | `_receive_interaction_state` RPC + `EventBus.interaction_state_changed` | Implicit via `command_result` (state diff) | **Delete RPC** |
| Attack sub-FSM | `attack_executor.gd` instance vars | `AttackFlowFSM` (RefCounted) | **Extract** |
| Modal authority decisions | 18 `is_network()` branches in `game_board.gd` | `UIProjector.project(state, local_player)` | **Centralise** |
| `NetworkInteractionState` class | First-class RefCounted resource | **Delete** (rolled into `InteractionFlow`) | **Delete** |
| `requires_seq` ordering | Explicit on every broadcast | Implicit (state always matches its `command_result`) | **Delete** |
| Reconnection UI restore | Not possible | Filtered `state_snapshot` rebuilds modals via UIProjector | **New capability** |

### What stays exactly the same

- All 26 `GameCommand` subclasses and 41 wired call sites
- `CommandSubmitter` strategy (`Local` / `Network`)
- `StateFilter` and information hiding (extended to filter `interaction_flow`)
- `CommandSyncGate` (Command Phase simultaneity)
- `GameRng`, `DamageDeck`, `EffectRegistry`, all damage cards
- All 89 test files, 2 633 tests

---

## 2. New Domain Type — `InteractionFlow`

```gdscript
## Authoritative description of the current interactive UI state.
## Mutated only by GameCommand.execute().  Serialized as part of GameState.
## Replaces the per-broadcast NetworkInteractionState RPC channel.
class_name InteractionFlow
extends RefCounted

var flow_type: Constants.InteractionFlow = Constants.InteractionFlow.NONE
var step_id: Constants.InteractionStep = Constants.InteractionStep.NONE
var controller_player: int = -1   ## −1 = no actor required (e.g. between turns)
var visible_to: Constants.Visibility = Constants.Visibility.ALL
var payload: Dictionary = {}      ## Step-local data, normalised (no Vector2/pixels)

func serialize() -> Dictionary: ...
static func deserialize(data: Dictionary) -> InteractionFlow: ...
func is_actor(player_index: int) -> bool: ...
```

New `Constants` enums:

| Enum | Values |
|------|--------|
| `InteractionFlow` | `NONE`, `COMMAND_PHASE`, `SHIP_ACTIVATION`, `SQUADRON_ACTIVATION`, `ATTACK`, `STATUS_CLEANUP`, `GAME_OVER` |
| `InteractionStep` | `NONE`, `WAIT_FOR_SHIP_SELECT`, `REVEAL_DIAL`, `SPEND_DIAL`, `MANEUVER`, `ATTACK_DECLARE`, `ATTACK_ROLL`, `ATTACK_MODIFY`, `ATTACK_DEFENSE_TOKENS`, `ATTACK_RESOLVE_DAMAGE`, `ATTACK_CRITICAL_CHOICE`, `SQUAD_ACTION_CHOICE`, `SQUAD_MOVE`, `SQUAD_ATTACK`, … |
| `Visibility` | `ALL`, `OWNER`, `SPECTATOR` |

---

## 3. New Application Service — `UIProjector`

```gdscript
## Pure projection from authoritative state to UI intent.
## Stateless; called by GameBoard whenever GameState.interaction_flow changes.
class_name UIProjector
extends RefCounted

class UIIntent:
    var modal_kind: Constants.ModalKind   ## NONE / ACTIVATION / SQUADRON / …
    var modal_payload: Dictionary
    var is_interactive: bool              ## false for opponent / spectator
    var hud_status_text: String
    var sidebar_active_unit_id: int

static func project(state: GameState, local_player_index: int) -> UIIntent:
    ## One pure function — single source of UI decisions.
```

Properties:

- **No EventBus emission**, no node access — pure transform.
- Called from a single signal handler `GameBoard._on_state_applied()`
  (subscribes to `EventBus.command_executed` / snapshot-applied signal).
- Replaces all 18 `is_network()` branches in `game_board.gd`.
- Fully unit-testable: feed in `GameState`, assert `UIIntent`.

---

## 4. Refactoring Phases

The plan is sliced into seven small, independently-shippable steps. Each
step ends with **all 2 633 existing tests green**, the `--server` headless
GUT run green, and a manual hot-seat smoke (LP scenario, round 1 attack).
No step deletes the parallel channel until I6.

| Step | Goal | LOC delta | Risk |
|------|------|----------|------|
| I0 | Inventory & freeze the producer surface | 0 | trivial |
| I1 | Add `InteractionFlow` + enums; thread through `GameState` (read-only field, no consumers yet) | +250 | low |
| I2 | Mutate `InteractionFlow` from existing commands (mirror, do not replace) | +400 | low |
| I3 | Extract `AttackFlowFSM` from `attack_executor.gd`; FSM writes `InteractionFlow` via commands | −400 / +600 | **medium** |
| I4 | Add `UIProjector`; reroute one consumer (HUD status) to it as a pilot | +180 | low |
| I5 | Migrate sidebar + activation modal + squadron modal to `UIProjector` | −120 / +60 | medium |
| I6 | Migrate attack UI to `UIProjector`; delete `NetworkInteractionState`, its RPC, and `is_network()` branches in `game_board.gd` | −600 net | medium |
| I7 | Reconnection acceptance test; documentation; remove dead code | small | low |

### I0 — Inventory & Freeze (1 day)

- Catalogue every site that mutates activation/attack flow state today.
  Output → `docs/interaction_flow_inventory.md` (one row per site, file:line,
  current owner, target step ID).
- Freeze: no new `NetworkInteractionState` producer wiring lands in master
  during Phase I. Existing C5/C6/C7/C8 producers stay until I5/I6.
- Add a CI lint that fails the build if a new `broadcast_interaction_state(`
  call site appears.

**Exit criteria:** inventory committed; lint active; no behaviour change.

### I1 — `InteractionFlow` Domain Type (1 day)

- Add `Constants.InteractionFlow`, `Constants.InteractionStep`,
  `Constants.Visibility` enums.
- Add `src/core/state/interaction_flow.gd` (RefCounted, serializable).
- Add `interaction_flow: InteractionFlow` field to `GameState` with
  `serialize()` / `deserialize()` round-trip.
- Add unit tests: enum coverage, serialize round-trip with payload,
  `is_actor()`.
- Add `StateFilter` rule: `interaction_flow.payload` is filtered per
  `visible_to`. Add 5 property-based tests.

**Exit criteria:** field exists, untouched by gameplay, all tests green
(2 633 + ~25 new).

### I2 — Mirror Flow into Commands (2 days)

- Every `GameCommand` that today triggers a `_broadcast_interaction_step()`
  call in `game_manager.gd` instead **mutates `state.interaction_flow`** as
  part of its `execute()`.
- Affected commands: `AssignDial`, `RevealDial`, `ActivateShip`,
  `AdvanceActivationStep`, `ExecuteManeuver`, `EndActivation`,
  `ActivateSquadron`, `AdvancePhaseCommand`, `StartRoundCommand`.
- The existing `_broadcast_interaction_step()` calls remain in place — this
  step adds the new path *alongside* the old one, with a unit-tested
  invariant: after every `command.execute()`, `state.interaction_flow`
  matches what `_broadcast_interaction_step()` would have built.
- Replay safety: under `is_replaying = true`, mutation still happens;
  EventBus emission still suppressed.

**Exit criteria:** invariant tests green for all 9 commands; existing
manual tests MT-G.01–08 green; no UI change yet.

### I3 — Extract `AttackFlowFSM` (3 days) — **MEDIUM RISK**

This is the deferred Phase F4 work plus the fix for the attack sub-FSM
coverage gap in §3 of the analysis.

- New file `src/core/combat/attack_flow_fsm.gd` (RefCounted).
- Move attack step transitions out of `attack_executor.gd` instance vars
  into FSM transitions that produce `GameCommand`s and update
  `interaction_flow.step_id`.
- Steps: `DECLARE → ROLL → MODIFY → DEFENSE_TOKENS → RESOLVE_DAMAGE →
  CRITICAL_CHOICE → END`.
- `attack_executor.gd` becomes a UI controller that reads
  `interaction_flow.payload` (dice pool, defender, etc.) and dispatches
  user input to the FSM.
- Use the incremental delegation pattern (`.skills/refactoring_guidelines.md`
  §8): keep file > 300 LOC editable; one helper at a time; commit per
  helper.
- Add ≥ 30 unit tests for the FSM, covering: critical-effect branch,
  redirect branch, brace branch, contain branch, salvo, no-defender.

**Exit criteria:** all attack tests green; `attack_executor.gd` ≤ 1 800 LOC;
manual MT-F5b.01–03 green.

**Status (2026-04-26): logically complete — LOC target deferred.**
- `5647edf` I3a: `AttackFlowFSM` (RefCounted) created with full transition
  table; wired into `attack_executor.gd` at 8 sites (`begin`, 6 `advance`,
  `end`).  +33 unit tests covering happy path, illegal transitions,
  controller resolution incl. squadron-vs-squadron, end+restart.
- `6fcc9f1` I3b: `patch_payload()` publishes per-step data into
  `interaction_flow.payload` at DECLARE (range_band, dice_pool), MODIFY
  (dice_results), DEFENSE_TOKENS (locked_tokens, modified_damage,
  defender_player).  +6 unit tests.
- `a89e9a8` I3c: payload at RESOLVE_DAMAGE (final_damage) and
  CRITICAL_CHOICE (chooser, card_title).
- LOC target (≤ 1 800 LOC for `attack_executor.gd`) **deferred**: no game
  logic was moved out of the executor.  Moving combat logic mid-Phase-I
  is a higher-risk change than the rest of Phase I and is not required
  for the acceptance gate (reconnection mid-attack).  The FSM publishes
  the data UIProjector (I4) and the projected attack UI (I6) need; that
  is what I3 was for.  A future refactor pass can shrink
  `attack_executor.gd` once the parallel RPC channel is gone.
- Tests: 2 716 (was 2 677 baseline). Lint OK.

### I4 — `UIProjector` Pilot — HUD (1 day)

- Add `src/core/network/ui_projector.gd` (despite the name, pure: no
  network code; lives under `core/network/` for cohesion with
  `state_filter.gd`).
- Connect `GameBoard._on_state_applied()` to `EventBus.command_executed`
  + snapshot-applied. Compute `UIProjector.project()` once per event.
- Reroute HUD status text (`UIPanelManager.set_network_status_text()`) to
  read from `UIIntent.hud_status_text`. Delete the active-player fallback
  for HUD only.
- Manual MT: HUD status text matches across two clients during a
  command-phase round.

**Exit criteria:** HUD status no longer reads `EventBus.interaction_state_changed`;
2 active-player fallback paths removed.

### I5 — Migrate Sidebar + Activation Modal + Squadron Modal (2 days)

- Sidebar (`activation_sidebar.gd`): replace
  `EventBus.interaction_state_changed` subscription with
  `EventBus.command_executed` + `UIProjector.project()`. Delete the
  active-player fallback path.
- Activation modal (`activation_modal.gd` + `_configure_and_open_activation_modal`):
  drive `set_interactable()` from `UIIntent.is_interactive`.
- Squadron modal: same pattern.
- Delete the 4 producer call sites in `_publish_post_command_interaction_state()`
  for these three flows.

**Exit criteria:** Manual MT-net.C5/C6/C7/C8 still green; 8 fewer
`is_network()` branches in `game_board.gd`; ~120 LOC removed.

### I6 — Migrate Attack UI; Delete Parallel Channel (3 days)

- Attack UI consumers read `UIIntent.modal_kind == ATTACK` and
  `interaction_flow.payload` (dice pool snapshot, defender, current step).
- Delete:
  - `src/core/network/network_interaction_state.gd`
  - `EventBus.interaction_state_changed` signal
  - `NetworkManager.broadcast_interaction_state()`,
    `_receive_interaction_state()`, `interaction_state_received` signal,
    `_latest_interaction_state` field
  - `GameManager._broadcast_interaction_step()`,
    `_publish_post_command_interaction_state()`,
    `_apply_interaction_state_if_ready()`,
    `_pending_interaction_by_version`,
    `_last_interaction_version`, `_last_applied_command_seq`
- Delete remaining `is_network()` branches in `game_board.gd` (target: ≤ 3
  branches, all confined to camera/perspective lock).
- `requires_seq` becomes obsolete: every `command_result` carries the
  authoritative `interaction_flow`.

**Exit criteria:** ≤ 3 `is_network()` branches in `game_board.gd`;
`game_board.gd` ≤ 2 200 LOC; the lint added in I0 catches regressions; all
2 633 tests green; manual MT-net full attack round green on two clients.

### I7 — Reconnection Acceptance + Cleanup (1 day)

- Add integration test using `TestNetworkHarness`: client disconnects
  mid-attack at `ATTACK_DEFENSE_TOKENS` step; reconnects; receives a single
  filtered `state_snapshot`; renders the exact modal of the active client
  with no further messages.
- This test is the **acceptance gate** for Phase I.
- Update `docs/progress_summary.md`, `docs/open_topics.md`, arc42 §5/§6/§8.
- Remove the I0 inventory file (now obsolete).

**Exit criteria:** reconnection test passes; baseline metrics updated.

---

## 5. Total Effort & Sequencing

| Step | Days | Cumulative |
|------|-----:|-----------:|
| I0 Inventory & freeze | 1 | 1 |
| I1 `InteractionFlow` type | 1 | 2 |
| I2 Mirror into commands | 2 | 4 |
| I3 Extract `AttackFlowFSM` | 3 | 7 |
| I4 `UIProjector` pilot (HUD) | 1 | 8 |
| I5 Migrate three flows | 2 | 10 |
| I6 Migrate attack; delete parallel channel | 3 | 13 |
| I7 Reconnection + cleanup | 1 | 14 |

**~14 focused days.** Each step is committable and ships to master with
zero behavioural regression until I6's deletions.

---

## 6. Safety Mechanisms

These guard against the failure modes that produced the current stall.

1. **Test gate per step.** No step lands until the full GUT run shows the
   expected script and assert counts. Parse-error silent drops are caught
   by §9 rule in copilot instructions.
2. **Invariant tests in I2.** For every command that writes
   `InteractionFlow`, an assertion verifies the new path matches the legacy
   `_broadcast_interaction_step()` payload. The legacy path is only
   removed in I6 *after* the invariant has been green for ≥ 4 steps.
3. **Lint in I0.** New `broadcast_interaction_state(` call sites or new
   `is_network()` branches in `src/scenes/` fail CI.
4. **Two clients smoke per step.** Steps I3–I7 each include a manual
   two-client run of the LP scenario before the user signs off the
   commit (per `.github/copilot-instructions.md` §9).
5. **Reconnection acceptance gate (I7).** If reconnection mid-attack does
   not render the right UI from a single snapshot, Phase I is not done.
   This is the test the current architecture cannot pass.
6. **Hot-seat regression budget = 0.** Any hot-seat test failure in any
   step is a stop-the-line event.

---

## 7. Architecture Compliance Across the Code Base

Phase I delivers these whole-codebase guarantees:

| Property | Mechanism | Verified by |
|----------|-----------|-------------|
| One mutation path | Only `GameCommand.execute()` mutates `GameState` (incl. `interaction_flow`) | §4.6 lint already in place |
| One UI-decision path | Only `UIProjector.project()` decides modal/HUD state | New lint: `EventBus.interaction_state_changed` is forbidden |
| One broadcast path | Only `command_result` carries cross-client state | `NetworkInteractionState` deleted in I6 |
| Network parity | Hot-seat and network use identical UI projection | UIProjector unit tests + two-client manual MT |
| Replay safety | `interaction_flow` serializes; replay reproduces UI deterministically | Replay tests extended in I7 |
| Reconnection | Filtered snapshot suffices to rebuild UI | I7 acceptance test |

Files that fall under the new rules (post-I6):

- `src/scenes/game_board/game_board.gd` — must contain ≤ 3 `is_network()`
  references; all UI decisions delegated to `UIProjector`.
- `src/autoload/game_manager.gd` — must not call
  `_broadcast_interaction_step()` (function deleted).
- `src/autoload/network_manager.gd` — must not contain
  `broadcast_interaction_state` or `_receive_interaction_state`.
- `src/ui/**/*.gd` — must not subscribe to a deleted signal.

---

## 8. Open Questions

| # | Question | Default answer (to be confirmed at I0) |
|---|----------|---------------------------------------|
| Q1 | Spectator visibility of `interaction_flow.payload` — full or filtered? | Filtered identically to player view |
| Q2 | Should `interaction_flow` go in a separate snapshot envelope or inside `GameState`? | Inside `GameState` — keeps one snapshot |
| Q3 | Is `AttackFlowFSM` a sibling of `EffectRegistry` or owned by `AttackExecutor`? | Sibling, owned by `GameManager` for testability |
| Q4 | Do we need `UIIntent` versioning for forward-compat? | No — derived from `GameState`, which is versioned |
| Q5 | Do we keep `CommandSyncGate`? | Yes — orthogonal; gates simultaneous reveal |

---

*End of plan.*

# Implementation Plan — Star Wars: Armada Digital Edition

> **Single source of truth** for project status, remaining work, and pointers
> to architecture and design references. Replaces and supersedes:
> `progress_summary.md`, `open_topics.md`, `refactoring_phase_i_plan.md`,
> `refactoring_test_strategy.md`, `g4_network_plan.md`, and
> `architecture_assessment.md` — all archived under [docs/old/](old/).
>
> Last updated: 2026-05-16 (Phase M1 FlowSpec skeleton; see §2 and [docs/refactoring_phase_lm_plan.md](refactoring_phase_lm_plan.md))

---

## 1. Current Baseline

| Metric | Value |
|--------|-------|
| GUT test scripts | 149 |
| GUT tests | 2 976 |
| GUT asserts | 5 754 |
| Failing tests | 0 |
| Last commit | `98262c8` — Phase M groundwork docs |

Runtime invariants:
- All `GameState` mutations route through `GameCommand.execute()`
  (§4.6 P1–P7 + debug all resolved).
- All UI flow state lives in `GameState.interaction_flow` and replicates over
  the canonical `command_result` channel (Phase I).
- Hot-seat and network use the same command path through a `CommandSubmitter`
  strategy; no parallel network channel.
- Deterministic replay via `GameRng` + `GameReplay` works in both modes.
- Phase L0.5 replay gate: `bash scripts/run_baseline_traces.sh --all` diffs
  the committed hot-seat trace/hash and verifies real two-process network
  host/client final-state-hash equality.  Network JSONL is diagnostic only;
  no committed network trace/hash fixture until the transport is deterministic
  across separate runs.

Verification note: the 2026-05-16 M1 full GUT summary is green
(149 / 2 976 / 5 754, 0 failures), but Godot 4.5.1 still aborted after the
summary with `recursive_mutex lock failed` / exit 134. Track the post-summary
abort separately; no parse errors or GUT failures were reported.

---

## 2. Implementation Phases — Status

### Game Features — All Complete

| Phase | Name | Status |
|-------|------|--------|
| 0 | Scale & Assets Foundation | ✅ |
| 1 | Core Geometry Engine | ✅ |
| 2 / 2b / 2c | Game Board, Token Placement, Deployment Zones | ✅ |
| 3 | Game State Wiring | ✅ |
| 4 / 4b / 4c–4g | Command Phase, Turn Mgmt, Activation, Tooltips, Fixed Round-1 | ✅ |
| L | Game Logging | ✅ |
| 5a / 5a+ / 5b / 5b-2 / 5c / 5d / 5e | Maneuver, Movement, Overlap, Range, Targeting, Shortcuts | ✅ |
| 6a–6c | Attack Resolution Pipeline | ✅ |
| 7 / 7b | Squadron Phase + Activation UI | ✅ |
| 8 | Status Phase, Scoring, Victory Screen | ✅ |
| 9 / 9.5 / 9.6 / 9.7 | Damage Cards, Repair, Squadron Command, 14/14 hooks, Debug Damage | ✅ |
| 10a / 10b | Immediate Damage Fixes, UI Polish | ✅ |
| 11 / 12 | Splash & Main Menu, Sound & Music | ✅ |

### Refactoring — All Complete

| Phase | Name | Outcome |
|-------|------|---------|
| A | Function Extraction | 95 functions >30 LOC → 0 violations |
| B | Narrow Interfaces | Callable injection, `#region` grouping |
| C | Controller Extraction | 7 controllers from `game_board` (3 390 → 2 799 LOC) |
| D | UI Builder Cleanup | UIStyleHelper, ShipCardPanel split (1 438 → 877) |
| E | Serialization | `serialize()`/`deserialize()` on all 11 core classes |
| F / F5 | Backbone + AttackExecutor Split | ActivationContext, UIPanelManager, 6 attack sub-resolvers; AE 3 008 → 1 883 |
| H | Geometry Centralisation | 6 inline approximations centralised |
| G | Command Pattern | 26 commands, 41 wired call sites, deterministic replay |
| **I** | **Interaction-Flow as Domain State** | **CLOSED 2026-05-02** — see §3 |

### Network — Phase G4 Status

| Sub-Phase | Status |
|-----------|--------|
| G4.0 Directory Reorg | ✅ |
| G4.1 Network Transport Foundation | ✅ |
| G4.2 Server-Side Command Processing | ✅ |
| G4.3 Information Hiding (`StateFilter`) | ✅ |
| G4.4 Command Phase Sync Gate | ✅ |
| G4.5 Lobby System | ✅ |
| G4.6 Chat System | ✅ |
| G4.6.5 Network Game Wiring | ✅ (largely subsumed by Phase I) |
| **G4.7 Spectator Mode** | ⏳ pending — post-K multiplayer hardening |
| **G4.8 Reconnection (runtime)** | ⏳ pending — acceptance test exists (Phase I7); RPC/timer runtime not yet implemented |
| **G4.9 Turn Timers** | ⏳ pending — post-K multiplayer hardening |
| G4.10 Dedicated Server Binary | ✅ |

### Refactoring — Phase K (Presentation-Layer Hardening)

Completed 2026-05-13. Detailed slice plan: [docs/refactoring_phase_k_plan.md](refactoring_phase_k_plan.md). Goals:
- Eliminate the **18** modal-authority `if PlayMode.is_*` branches across 5 files in `src/scenes/game_board/` (Phase I rule §7). 5 further session-mode discriminators in save/load + lobby flow are allow-listed.
- Decompose `game_board.gd` (3 055 LOC), `attack_executor.gd` (2 475 LOC), `game_manager.gd` (2 241 LOC), `save_game_manager.gd` (1 061 LOC) into focused controllers / RefCounted helpers.
- Treat LOC ceilings as extraction triggers, not documentation-cutting targets:
  keep comments that explain contracts, invariants, and replay/network/modal
  failure modes; extract behaviour when raw file length becomes uncomfortable.
- Existing `tests/unit/test_interaction_flow.gd` (27 tests) and `tests/unit/test_ui_projector.gd` (23 tests) extended where needed (no new files required by audit).
- Land `scripts/lint_phase_k.sh` + pre-commit hook (slice K7).

Status: **COMPLETE** — K0 through K15 complete. K10 (`DebugBoardController` extraction, F-key debug damage + replay save trigger) committed `9a1f763`. K11 (`ToolOverlayController` extraction, maneuver/range/targeting overlay + keyboard shortcuts) committed `ef2c84e`. K12 (`CommandRouterAdapter` + command-projection routing + modal overlap fix) committed `e17ff05`. K13 (`game_board.gd` function-size cleanup via helper extraction + dispatch simplification) committed `cf29d8f` (143 / 2887 / 5440, lint 0 violations). K14a committed `454fd0e`: extracted core `AttackFlowExecutor` payload builders and added `test_attack_flow_executor.gd`. K14b committed `c6b4b67`: extracted attack-state init/reset/roll/defense-payload helpers and delegated corresponding `AttackExecutor` call sites. K14c committed `1559fc4`: extracted defense-commit canonical ordering and queue initialization helpers. K14d committed `54df444`: extracted defense-queue polling + faceup-card counting and delegated corresponding scene-layer paths. K14e committed `06438e7`: extracted first-faceup decision + damage-summary construction and delegated corresponding scene-layer helpers. K14f committed `d99ca32`: extracted redirect-continuation decision. K14g committed `33e697f`: extracted faceup-card preparation and immediate-effect flow decision into `AttackFlowExecutor` pure helpers, delegated corresponding `AttackExecutor` call sites, and expanded `test_attack_flow_executor.gd`. K15 completed the remaining `attack_executor.gd` size/nesting cleanup pass.

### Refactoring — Phase L/M (Modal Lifecycle + Flow Authority)

Detailed slice plan: [docs/refactoring_phase_lm_plan.md](refactoring_phase_lm_plan.md). Goals:
- Phase L removes the remaining modal-lifecycle PlayMode branches by routing
  hot-seat and network through `UIProjector` + `ModalRouter`.
- Phase M promotes the flow/step model into a declarative `FlowSpec` / rule
  registry surface.
- Phase L0.5 adds the replay regression gate used by all L/M slices.

Status: **IN PROGRESS** — Phase L is complete; M0, M0.5, M0.6, M0.7, and M1 are complete; M2 is next. L0.5 replay
regression gate is complete and remains the required L/M automated gate:
- Hot-seat: committed JSONL trace + committed final-state hash.
- Network: real two-process ENet replay; host/client final-state hashes must
  match within the same run.  Network command traces and network final hashes
  are diagnostic only until a deterministic network pump exists.
- L1 result: [modal_router.gd](../src/scenes/game_board/modal_router.gd)
  owns the `CommandProcessor.command_executed` projection path; the lint floor
  dropped from 11 to 10 allow-listed branches.
- L2 result: [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd)
  submits activation-step transitions through commands in both hot-seat and
  network; [modal_router.gd](../src/scenes/game_board/modal_router.gd) opens
  closed activation modals from projected lifecycle commands; the lint floor
  dropped from 10 to 8 allow-listed branches.
- L3 result: [ui_projector.gd](../src/core/network/ui_projector.gd)
  projects the activation-sequence button affordance and maps ship-activation
  `SQUADRON_STEP` to the command-mode squadron modal; [modal_router.gd](../src/scenes/game_board/modal_router.gd)
  opens the squadron command modal from the authoritative `advance_activation_step`
  edge; the lint floor dropped from 8 to 7 allow-listed branches.
- L4 result: [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd)
  now only submits the authoritative `start_displacement` command after
  ship-squadron overlap; [modal_router.gd](../src/scenes/game_board/modal_router.gd)
  opens the displacement modal from the projected `SQUADRON_DISPLACEMENT /
  DISPLACEMENT_PLACE` intent in hot-seat and network. The lint floor dropped
  from 7 to 6 allow-listed branches. MT follow-up fixed a projected
  `REPAIR_STEP` stall when no repair action was available by deferring the
  controller peer's Repair-to-Attack advance through the authoritative command
  path and hiding stale past-step buttons during activation-modal refresh.
  Additional MT follow-ups now republish CF-token reroll dice through
  `interaction_flow`, carry final dice into the defense payload, expose
  Squadron command decline from the activation modal, bind activation
  auto-skip timers to their original step, and reject maneuver submits from
  active non-maneuver sub-steps.
- L5 result: [ui_projector.gd](../src/core/network/ui_projector.gd)
  projects active-player transition UI as `UIIntent` fields for shared-screen
  handoff, active-player banner, passive waiting status, command-dial startup,
  Squadron observer startup, and camera/card perspective. [game_board.gd](../src/scenes/game_board/game_board.gd)
  now applies that intent through one path; the lint floor dropped from 6 to
  5 allow-listed branches.
- L6 result: [load_game_dialog.gd](../src/ui/save/load_game_dialog.gd)
  centralises its deployment-mode network query in `_is_network_session()` and
  routes both hot-seat save blocking and host network-load broadcast checks
  through that helper; the lint floor dropped from 5 to 4 allow-listed branches.
- L7 result: manual-test sweep passed in hot-seat and network. Automated
  pre-flight preserved the `148 / 2 956 / 5 629` GUT baseline, Phase K lint
  reported `0 violations (4 allow-listed branches)`, and baseline traces
  passed hot-seat trace/state plus network peer-state equality. Network-mode
  annotations recorded pass evidence for activation auto-skip, brace canonical
  order, and displacement modal projection; annotation JSON files remain local
  ignored runtime artifacts under `saves/annotations/`.
- M0 result: [docs/game_flow.md](game_flow.md) is the human-readable master
  flow document for Phase M. It inventories every currently projected,
  produced, or legacy-compatible `(flow_type, step_id)` pair with controller
  role, modal kind, allowed command surface, transitions, citations, and
  known gaps for M0.5-M4. No source code changed.
- M0.5 result: [docs/game_flow.md](game_flow.md) now includes the model-fitness
  review for the three planned questions. The review found no blocking
  `InteractionFlow` model defect before `FlowSpec`; it records that M1 must
  make `controller_role` first-class, with `SQUADRON_DISPLACEMENT /
  DISPLACEMENT_PLACE` as the worked example for the non-moving-player rule.
  No source code changed.
- M0.6 result: [docs/game_flow.md](game_flow.md) now defines the runtime
  registry boundary: `EffectRegistry` remains transient and rebuilt from
  serialized entities by `EffectFactory.rebuild_runtime_effects()`, while
  `RuleRegistry` is a static definition catalogue and not an active-state
  store. The loaded Blinded Gunners bug is pinned as the save/load acceptance
  example, and the first-six rule migration decisions are recorded. No source
  code changed.
- M0.7 result: [docs/game_flow.md](game_flow.md) now defines the `GLOBAL` /
  `PHASE` / `FLOW_STEP` command applicability taxonomy and inventories every
  currently registered command type with a proposed M3 declaration scope. The
  findings are reflected in the Phase L/M plan so M3/M4 can add parity tests
  and gates without misclassifying setup, phase, sync, debug, or legacy-effect
  commands. No source code changed.
- M1 result: [flow_spec.gd](../src/core/state/flow_spec.gd) now encodes all
  25 documented interaction-flow pairs from [docs/game_flow.md](game_flow.md)
  as static machine-readable metadata, including controller roles, modal
  metadata, command surfaces, transitions, source tags, and rule citations.
  [test_flow_spec.gd](../tests/unit/test_flow_spec.gd) adds 20 tests / 125
  asserts covering pair parity, enum drift, projection-only rows, resolver
  success/failure paths, and the displacement non-moving-player regression.
  Automated gates: 149 / 2 976 / 5 754 GUT baseline with 0 failures (known
  post-summary Godot abort), Phase K lint 0 violations / 4 allow-listed
  branches, and baseline traces passing hot-seat trace/state plus network peer
  state equality.

---

## 3. Phase I Closure Summary

Phase I promoted UI-flow state to a serializable field of `GameState`,
eliminating the parallel `NetworkInteractionState` RPC channel. Outcome:

- **`InteractionFlow`** on `GameState` (`flow_type`, `step_id`,
  `controller_player`, `visible_to`, `payload`) — mutated only by
  `GameCommand.execute()`, replicates implicitly via `command_result`.
- **`AttackFlowFSM`** extracted from `attack_executor.gd` — pure
  state machine for attack sub-steps.
- **`UIProjector.project(state, local_player)`** — single source of
  truth for which modal is open, who can act. Replaces 14+
  `is_network()` branches in `game_board.gd`.
- **`StateFilter`** strips `Visibility.OWNER` payloads per peer.
- **Mirrored attack panels** — both peers render the same
  `AttackSimPanel` from `interaction_flow.payload`; controller-peer
  interactivity is gated by sub-step. Defender input flows back as
  commands (`SpendDefenseTokenCommand`, `CommitDefenseCommand`,
  `SelectRedirectZoneCommand`, `SelectEvadeDieCommand`,
  `RedirectDoneCommand`).
- **Squadron displacement** flows through `StartDisplacementCommand` +
  `CommitDisplacementCommand` so the modal opens for the non-moving
  player named by `interaction_flow.controller_player` (OV-002 fix).
- **Reconnection acceptance gate** ([tests/integration/test_reconnection_mid_attack.gd](../tests/integration/test_reconnection_mid_attack.gd)):
  pure-function chain `serialize → filter_for_player → deserialize → project`
  validates that any peer can reconstruct the correct UI from a single
  filtered snapshot at any attack sub-step.
- Deleted: `NetworkInteractionState`, `EventBus.interaction_state_changed`,
  `broadcast_interaction_state` RPC, `DefenseMirrorPanel`,
  `interaction_flow_inventory.md`, `scripts/lint_phase_i.sh`.

Detailed sub-step history (I0 through I7, R1–R7, I6b-4a–d, I6e-1–3) is
preserved in [docs/old/refactoring_phase_i_plan.md](old/refactoring_phase_i_plan.md)
and [docs/old/progress_summary.md](old/progress_summary.md).

---

## 4. Open Topics

### 4.1 Network Features Pending

| Item | Plan reference | Notes |
|------|---------------|-------|
| **G4.7 Spectator Mode** | [docs/old/g4_network_plan.md](old/g4_network_plan.md) §G4.7 | Both-players consent gate, omniscient view, perspective toggle, rate limiting (NW-009 / NW-010) |
| **G4.8 Reconnection runtime** | [docs/old/g4_network_plan.md](old/g4_network_plan.md) §G4.8 | Server-side timer pause, command replay since last seq, reconnect overlay UI. *Domain-side reconnection contract is already validated by the I7 integration suite.* |
| **G4.9 Turn Timers** | [docs/old/g4_network_plan.md](old/g4_network_plan.md) §G4.9 | Configurable per-turn timer, forfeit on timeout, restart from auto-save. Implement G4.9.6 (auto-save) first. |
| **Phase 10c** | — | Network requirement coverage gate — depends on G4.7–G4.9 |

### 4.2 Pending Network Requirements

NW-001 through NW-008 — covered by G4.7–G4.9 implementation. NW-006
(defender-controlled defense tokens over network) is closed by
Phase I R2.

### 4.3 Known Visual Bugs

| Bug | Severity | Observed | Notes |
|-----|----------|----------|-------|
| Activated squadron loses ghosted appearance after ship-overlap displacement | Minor (visual only) | 2026-04-12 | Squadron cannot be re-activated (logic correct); only the dimmed visual state is lost. |
| Repair effect not visible on ship token | Minor (visual only) | 2026-05-01 | Token's hull/shield pip overlay stale after repair until next refresh. Likely missing `ship_shields_changed` / `ship_hull_changed` emit on repair path. |
| Network: passive-peer auto-resolve damage cards don't refresh visuals | Minor (visual only) | 2026-05-01 | `GameManager._handle_remote_immediate_effect` emits only `command_dials_changed` + `ship_defense_token_changed`; missing `damage_card_flipped` + shield/hull deltas on passive peer. Closed by extracting `_emit_immediate_signals` into a shared helper. |
| **Ship activation modal visible behind squadron command modal** | **Minor (visual only)** | **2026-05-09** | **FIXED (K12-bugfix, pending commit)** — When opening squadron command during ship activation, the ship activation modal now closes before opening the squadron modal so they don't overlap. Fix in `ShipActivationController._on_squadron_step_entered()`. |

### 4.4 Manual Tests Pending

Most manual tests are stamped through Phase I (see archived
[docs/old/open_topics.md](old/open_topics.md) §4 for the full log,
including MT-PHI.01–06b-4d and MT-G4.x). New MTs to add per future phase
following the procedure in `.skills/copilot_instructions.md` § "Manual
Test Gate".

Bulk MTs that were never formally stamped (~150 tests across phases 2–12,
refactoring A–F, bug fixes) should be regression-stamped before the next
release milestone — full table preserved in
[docs/old/open_topics.md](old/open_topics.md) § "Never Formally Stamped".

---

## 5. Phase J — Save Games (Proposed)

Status: **PROPOSED** — awaiting approval before implementation.

### 5.1 Goal

End-to-end working save/load: write the full game state at safe points,
restart it later from the main menu (or from in-game), with a named
saves list. Hot-seat and network modes both supported; in network only
the host can save. Replaces the existing F5/F8 quicksave that only
serialises (load is logged but not applied).

### 5.2 Functional Requirements

| ID | Requirement |
|----|-------------|
| SG-1 | The full `GameState` (round, phase, fleets, ships, squadrons, dials, tokens, damage deck, RNG seed, `interaction_flow`) is serialised to a single JSON file under `user://saves/`. |
| SG-2 | A save's metadata header records: `scenario_id`, `scenario_name`, `game_mode` (`hot_seat` / `network`), `round`, `phase` (label), `created_at` (ISO timestamp), `app_version`, `display_name`. |
| SG-3 | Default save name template: `{scenario_name}_{game_mode}_R{round}_{phase}` (e.g. `Learning_HotSeat_R2_Ship`). The user can edit the name in a text field (with that template pre-filled) before confirming. |
| SG-4 | Save list groups saves by game mode; each row shows `display_name`, scenario name, round/phase, timestamp, and (in network) whether it is a host snapshot. |
| SG-5 | Save is only allowed at **safe points** (see §5.3). At unsafe points the Save button is disabled with an explanatory tooltip. **Superseded by SG-12 in J5.5: Save is enabled whenever a checkpoint exists.** |
| SG-6 | In network mode, only the host may save; clients see "Save Game" disabled / hidden. Hot-seat: always allowed (at safe points). |
| SG-7 | Loading a save restores the game such that play continues exactly from the saved point: same active player, same dials, same tokens, same damage cards, same RNG sequence; `interaction_flow` is `NONE` after load (we do not resume mid-attack — see §5.7 / Q5). |
| SG-8 | Loading is offered from (a) the main menu ("Load Game" button), and (b) the in-game ESC menu ("Load Game"). In both cases the active game is torn down before the saved state is installed. |
| SG-9 | In network mode, "Load Game" from the in-game menu is host-only; clients see Quit / Resume only. Loading from the main menu is offered to any user but only for hot-seat slot (see Q1 for network-load policy). |
| SG-10 | ESC on the main game board with no modal open opens the new in-game menu (see §5.4). On a second ESC press the menu closes ("Resume"). |
| SG-11 | Existing F5 quicksave keybind: removed (or aliased to "save with default name", see Q3). Existing F8 quickload removed in favour of the menu flow. |
| SG-12 | (J5.5) `SaveGameManager` maintains **two** internal checkpoint snapshots — one per game mode (`hot_seat`, `network`). Each is refreshed automatically every time `command_executed` fires while `can_save_now()` is true **and** `PlayMode` matches that checkpoint's mode. Each is persisted to disk at `res://saves/_checkpoint_hot_seat.json` and `res://saves/_checkpoint_network.json` so they survive crashes / app restarts. |
| SG-13 | (J5.5) Pressing **Save Game** writes a copy of the **current mode's** checkpoint (not the live state) under the user-chosen filename. The Save button is enabled whenever a checkpoint exists for the current mode — even when the live state is mid-flow. The dialog header shows the checkpoint's round/phase. |
| SG-14 | (J5.5) An **initial checkpoint** is written for the active mode when a new game starts (or a save is loaded), so Save is available from turn one. Loading a save in mode X only resets mode X's checkpoint; the other mode's checkpoint is untouched. |
| SG-15 | (J5.5) On Quit, the SaveOnQuitDialog's *Save & Quit* option is enabled whenever the **current mode's** checkpoint exists; it never greys out for safe-point reasons. |
| SG-16 | (J5.5) The internal checkpoint files are **hidden** from the named-saves portion of the LoadGameDialog list. Instead, each mode-section in the dialog renders a synthetic top row labelled "Resume Last Checkpoint" (see SG-18). |
| SG-17 | (J5.5) `is_dirty()` is **per-mode**: `true` iff the current mode's checkpoint signature differs from the value recorded at the last named save **of that mode**. Quitting hot-seat ignores the network checkpoint's dirtiness, and vice versa. |
| SG-18 | (J5.5) `LoadGameDialog` drops the All/Hot-Seat/Network filter tabs and renders two stacked sections with headers "Hot-Seat" and "Network". Each section starts with a synthetic **"Resume Last Checkpoint"** row (always shown; greyed when no checkpoint exists for that mode, secondary line shows scenario / round / phase / timestamp), followed by the named saves of that mode. Network rows (checkpoint + named) remain greyed when no host session is active. |

### 5.3 Safe Points

A save is allowed iff **all** of the following hold:

1. `GameState.interaction_flow.flow_type == NONE` — no attack / displacement /
   immediate-choice / dial-picker flow is open.
2. `CommandProcessor` history is consistent: no command is currently mid-execute.
3. No drag operation is in progress (dial drag, maneuver tool committed,
   squadron move overlay closed).
4. The current phase is one of:
   - **Command Phase** — only between dial assignments (no picker open) and at
     the round-1 fixed-commands gate.
   - **Ship Phase** — between ship activations (no `ShipActivationState` active).
   - **Squadron Phase** — between squadron activations (no squadron selected /
     no move overlay open).
   - **Status Phase** — at the very start or end of cleanup (between commands).

Implementation: `SaveGameManager.can_save_now()` reads
`GameState` + `GameManager` flags and returns `(bool, reason: String)`.
The reason populates the disabled-button tooltip.

### 5.4 In-Game ESC Menu (replaces `QuitConfirmationModal`)

New `GameMenuModal` (renames `QuitConfirmationModal` / extends it):

| Mode | Visible Buttons |
|------|-----------------|
| Hot-seat | Resume · Save Game · Load Game · Quit Game |
| Network host | Resume · Save Game · Load Game · Quit Game |
| Network client | Resume · Quit Game |

Behaviour:
- Resume / second ESC press closes the modal.
- Save Game opens `SaveGameDialog` (name field + Save / Cancel). Disabled at
  unsafe points with reason tooltip.
- Load Game opens `LoadGameDialog` (filtered list + Load / Cancel). On Load,
  the current game is torn down (back to main menu briefly, then re-enter
  game board with loaded state) — see §5.6.
- Quit Game returns to the main menu (current behaviour); separate
  confirmation step kept only if a save is unsaved (see Q4).

### 5.5 Main Menu Integration

- New "Load Game" button on the main menu (between "Learning Scenario" and
  "Host Game"). Opens `LoadGameDialog`. Selecting a save bypasses scenario
  picking and goes straight to the game board with the loaded state.
- Hot-seat / network filtering: the dialog tabs split saves by mode (Q1
  decides network-load policy).

### 5.6 Architecture Sketch

```
src/
├── autoload/
│   └── save_game_manager.gd     [extended: metadata header, list_with_meta(),
│                                  can_save_now(), load_and_restore()]
├── core/
│   └── state/
│       └── save_game_metadata.gd  [new RefCounted, validates header]
├── ui/
│   └── save/
│       ├── game_menu_modal.gd     [renamed from QuitConfirmationModal]
│       ├── save_game_dialog.gd    [new — name field, Save/Cancel]
│       └── load_game_dialog.gd    [new — list, filter, Load/Cancel]
```

- `GameManager.start_new_game_from_state(state, scenario_id)` — reuses the
  existing scenario loader for **fleet template re-association** (ship/
  squadron `Resource` templates can't be in JSON), then installs the
  deserialised `GameState`. Re-emits the post-`start_new_game` signals so
  the board rebuilds.
- The save file's `scenario_id` is required to reconstruct templates —
  otherwise `ShipInstance.template` and `SquadronInstance.template` are
  null. `AssetLoader.load_ship_data()` / `load_squadron_data()` are
  re-resolved by ship/squadron key recorded in the serialised
  `ShipInstance` / `SquadronInstance`.

### 5.7 Sub-Phase Breakdown

| Slice | Scope | Tests | MT |
|------:|-------|-------|----|
| J1 ✅ | `SaveGameMetadata` (header schema with `save_format_version=1`) + extend `SaveGameManager`: header read/write, HMAC sign/verify (shared with replay), `can_save_now()`, `list_with_meta()`. Add `display_name` to scenario JSONs. Remove F5/F8 debug bindings. | Unit tests: header round-trip, version rejection, HMAC tamper rejection, can_save_now matrix (all phases × flow states), list_with_meta. | — |
| J2 ✅ | `GameManager.start_new_game_from_state(state, scenario_id)` — install deserialised state, re-resolve templates, emit `game_started` so board rebuilds. Hot-seat only. | Unit / integration: round-trip serialize → deserialize → install → all ships present, dials match, damage deck matches. | Deferred to MT-J.5 (no user-facing surface in J2; F8 binding removed in J1 per Q3). |
| J3 ✅ | `GameMenuModal` replaces `QuitConfirmationModal`: 4 buttons (hot-seat/host) / 2 buttons (client), ESC-toggle, centred with main-menu button styling. Quit triggers "Save first?" sub-modal when game is dirty. Save / Load buttons stub-disabled. | Unit: button visibility per mode; ESC open/close; dirty-on-quit prompt. | MT-J.3 — ESC menu shows correct buttons in each mode; second ESC resumes; quit-when-dirty prompts. |
| J4 ✅ | `SaveGameDialog` — name field with default template, Save/Cancel, validation (non-empty, no path separators, max 64 chars), overwrite confirmation. Wired into `GameMenuModal` (hot-seat + host only). | Unit: name validation; default template builder. | MT-J.4 — save in hot-seat with default name and with edited name; verify file on disk. |
| J5 ✅ | `LoadGameDialog` (J5 design superseded by J5.5 two-section layout). | — | Folded into MT-J.5.5. |
| **J5.5 ✅** | **Per-mode checkpoint refresh** — `SaveGameManager` maintains a `Dictionary[mode -> {payload, signature, last_named}]` keyed by `PlayMode` (`hot_seat`, `network`). Refreshed on `CommandProcessor.command_executed` when `can_save_now()` is true, scoped to the active mode. Persisted as `_checkpoint_<mode>.json`. Initial checkpoint written on `EventBus.game_started`. `save_game()` copies the active mode's checkpoint payload under the new name. Save button enabled when current mode's checkpoint exists. SaveOnQuitDialog's Save & Quit enabled when checkpoint exists. SaveGameDialog title shows checkpoint round/phase. `is_dirty()` is per-mode. `LoadGameDialog` rewritten: two stacked mode sections; each starts with a synthetic "Resume Last Checkpoint" row (greyed when empty or network-without-host). | Unit: 2 839 tests pass; LoadGameDialog two-section layout, resume-row grey-out, network grey-out covered. | MT-J.5.5 — user-confirmed: mid-flow save captures last safe point; crash-resume preserves checkpoints; both mode sections render independently. |
| **J5.6 ✅** | **Hot-seat load actually works** — fix the two defects that currently break load: (a) `GameBoard._ready` unconditionally calls `bootstrap_game("learning_scenario")` which overwrites a state freshly installed by `start_new_game_from_state`; (b) `_spawn_learning_scenario_tokens()` reads positions from scenario JSON instead of from the loaded `GameState`. Add a `GameManager.is_state_preloaded` flag set by `start_new_game_from_state` and cleared after the board consumes it; gate `bootstrap_game` and the token spawner on this flag. Token spawning when preloaded reads `pos_x` / `pos_y` / `rotation_deg` / hull damage / token state / dial assignments from `ShipInstance` + `SquadronInstance`. Main-menu Load flow + ESC-menu Load flow both use the same path; ESC-menu load tears the board scene down and reloads it (cleaner than mutating in place). Network section in main-menu `LoadGameDialog` shown but **greyed** with tooltip "Load network saves from the lobby once both players are connected". | Unit: `GameManager` preload flag round-trip; token spawner branch; main-menu LoadGameDialog shows greyed network rows with tooltip. Integration: serialize → deserialize → install → board rebuild → all ship positions, dials, damage cards, RNG match. | MT-J.5.6 — user-confirmed: hot-seat load works from main menu and ESC menu. |
| **J6 ✅** | **Network-host save:** `SaveGameManager.save_game()` refuses on the network client (defense in depth — UI already hides the Save button for `Mode.NETWORK_CLIENT`). Host writes the file from its authoritative `GameState`; `NetworkManager.broadcast_save_notification(name)` (`@rpc("authority", "reliable")`) emits `save_notification_received` on the client; `SaveGameManager._on_remote_save_notification` shows a 3-second toast `Host saved the game as "<name>".` Tests: `test_save_game_refused_on_network_client`, `test_save_game_allowed_on_network_host`, `test_save_notification_signal_emittable`, `test_broadcast_save_notification_warns_when_not_server`. MT-J.6 confirmed by user 2026-05-03. **Note:** loading a network save from an in-session ESC menu is intentionally unsupported until J7 — the user-visible Load button is still shown but the load path is not RPC-backed; we did not add an interim grey-out because J7 will replace this UX entirely. |
| **J7 (reshape) ✅** | **Network load from the lobby and from an active session** — `LobbyRoom` adds a host-only `Load Game` button gated by `LobbyState.can_start()` (both connected + both Ready). Pressing it opens `LoadGameDialog` with `context = "lobby"` and `transition_to_board_on_load = false`: hot-seat rows greyed (tooltip *"Hot-seat saves can only be loaded from the main menu."*), network rows active. On Load the dialog calls `LobbyManager.host_load_save(state, meta)` instead of `start_new_game_from_state`+scene-change. `host_load_save` broadcasts `_receive_loaded_state.rpc(state.serialize(), scenario_id, meta.to_dict())` (`@rpc("authority", "reliable")`), then installs locally and emits `game_starting`. The client RPC handler shows a 2 s *"Host is loading the game…"* toast, deserialises, installs via `start_new_game_from_state`, and emits `load_state_received` + `game_starting` so the existing `MainMenu._on_lobby_game_start` path runs (sets PlayMode + submitter + `change_scene_to_file(GAME_BOARD)`). New signal `LobbyManager.load_state_received`. **In-session host load:** `LoadGameDialog._on_load_pressed` routes any host-side network load (lobby or in-session) through `LobbyManager.host_load_save`; the `host_load_save` gate accepts either lobby-Ready or `NetworkManager.peer_count >= 1`; both `host_load_save` and `_receive_loaded_state` call `_maybe_force_board_reload()` so when triggered from the game_board scene both peers reload via the standard `GameBoard._ready` preloaded-state path. **Three side-fixes shipped with J7:** (i) `_spawn_and_bind_tokens` seeds `ShipInstance.pos_x/pos_y/rotation_deg` and `SquadronInstance.pos_x/pos_y/rotation_deg` from the deployment placement so unmoved tokens no longer round-trip as origin (only `ExecuteManeuverCommand` / `MoveSquadronCommand` / `CommitDisplacementCommand` had previously written these fields); (ii) `GameManager.start_new_game_from_state` derives `active_player` from `interaction_flow.controller_player` (falling back to `initiative_player`) so a save taken mid-round restores the correct turn owner; (iii) the in-session ESC → Load path now reaches the client (was previously local-only on the host). Tests: `test_host_load_save_refused_when_not_server`, `test_host_load_save_refused_with_null_args`, `test_host_load_save_refused_when_lobby_not_startable`, `test_load_state_received_signal_emittable`, `test_hot_seat_named_row_disabled_in_lobby_context`, `test_network_named_row_enabled_in_lobby_context`. Old "re-host + kick" design dropped. MT-J.7 confirmed by user 2026-05-03 (lobby load + in-session host load + correct active player on resume). |
| **J8 ✅** | **Cleanup + arc42 §5 update + in-session hot-seat grey-out fix.** Deleted dead `src/ui/quit_confirmation_modal.gd` (+ `.uid`); removed last stale `QuitConfirmationModal` references in `game_menu_modal.gd` doc-comment and `docs/modal_classification.md`. Added a new "Save / Load Subsystem (Phase J)" subsection to `docs/arc42/05_building_block_view.md` covering `SaveGameManager`, `SaveGameMetadata`, `IntegritySigner`, `GameMenuModal`, `SaveGameDialog`, `LoadGameDialog`, `SaveOnQuitDialog`. **Bug fix found during MT-J.8:** in network mode the in-session ESC → Load dialog left hot-seat saves enabled — loading one would have torn down the network game without the connected client. `LoadGameDialog._is_hot_seat_blocked()` now also returns `true` when `context == "in_game"` and `PlayMode.is_network()`; `_hot_seat_blocked_tooltip()` returns *"Hot-seat saves cannot be loaded during a network session. Quit to the main menu first."* in that case. Lobby and pure hot-seat behaviour unchanged. Tests: `test_hot_seat_named_row_disabled_in_game_when_network_active`, `test_hot_seat_named_row_enabled_in_game_when_hot_seat_mode`. MT-J.8 confirmed by user 2026-05-03. |
| **J9 ✅** | **Path layout + checkpoint safety hardening.** **Paths:** new `PathConfig` static helper centralises `SAVES_DIR` / `REPLAYS_DIR` / `LOGS_DIR` / `ANNOTATIONS_DIR` / `SIGNING_KEY_FILE`. Editor and source builds keep using `res://saves/`, `res://replays/`, `res://logs/`; packaged exports use `user://` (which `project.godot` now pins to `~/Library/Application Support/Armada/` via `config/use_custom_user_dir = true` + `config/custom_user_dir_name = "Armada"`). `SaveGameManager`, `DebugMode`, `GameReplay`, `LoggingMode` all read paths from `PathConfig`. New `tests/unit/test_path_config.gd` (7 tests). New user guide subsection §11 in `docs/setup_network_game.md` documents where saves, replays, and logs land for editor vs. packaged builds. **Checkpoint safety:** narrowed `_SAFE_STEPS` to drop `NONE` and `ACTIVATION_DONE` (transient gaps that observed mid-squadron-command and mid-displacement captures); added structural invariant — refuse save if any ship has a revealed (popped) command dial; added phase-progression invariant — refuse save in SHIP/SQUADRON phase when no eligible activation remains (covers the brief window after the last activation but before `AdvancePhaseCommand` fires). `_capture_checkpoint` re-checks `can_save_now` itself as belt-and-braces. Initial checkpoint at `game_started` still writes the canonical `_checkpoint_<mode>.json` for crash recovery but no longer emits a numbered debug snapshot. Numbered debug snapshots (`_checkpoint_<mode>_NNN.json`) are written on every safe capture when `LoggingMode.enabled`, are surfaced in `LoadGameDialog` (gated on `LoggingMode.enabled`), and are no longer wiped at `game_started` — instead the per-mode counter seeds from the highest existing index, so loading `_001` to inspect a bad capture preserves `_002…_NNN`. **Side-fix:** moved `ShipInstance` / `SquadronInstance` position seeding earlier in `GameBoard._spawn_learning_scenario_tokens` (extracted to `_seed_instance_positions`) so the round-1 fixed-command auto-checkpoints record real deployment positions instead of (0, 0). Tests: 2 869 pass / 5 401 asserts; new tests `test_can_save_now_rejects_idle_none_step`, `test_can_save_now_rejects_ship_with_revealed_dial`, `test_can_save_now_rejects_ship_phase_with_no_unactivated_ships`. **MT-J.9** confirmed by user 2026-05-07: numbered checkpoints `_001…_NNN` are listable, loadable, and replay correctly; old broken captures are gone. |
| **J10 ✅** | **Application-launch artefact cleanup.** On every app start (autoload `_ready`), three categories of transient files from previous sessions are wiped before the new session begins: (i) numbered debug checkpoints `_checkpoint_<mode>_NNN.json` in `PathConfig.SAVES_DIR` — canonical `_checkpoint_<mode>.json` files are preserved so crash recovery still works; (ii) all `*.json` files in `PathConfig.REPLAYS_DIR`; (iii) all `*.log` files in `PathConfig.LOGS_DIR` (runs unconditionally, even when launched without `--logging`, so old logs don't accumulate on no-logging launches). New `SaveGameManager._cleanup_session_artifacts()` / `_delete_numbered_debug_snapshots()` / `_delete_files_in_dir()`; new `LoggingMode._cleanup_old_logs()` runs before today's log file is opened. Tests: `test_cleanup_session_artifacts_removes_numbered_checkpoints` (also verifies canonical preservation), `test_cleanup_session_artifacts_removes_replays`, `test_cleanup_old_logs_removes_log_files`. Tests instantiate the autoload via `.new()` without `add_child`, so `_ready` does not fire automatically and the cleanup methods are exercised directly. Total: 2 872 tests / 5 407 asserts. |
| **J11 ✅** | **Navigate-token yaw-bonus rules-violation fix.** Bug: spending a Navigate token (via dial→token convert + drop on card) granted the +1 yaw click that is reserved for the dial spend (RRG p.3, "Commands → Navigate"). Root cause: `GameBoard._on_dial_token_converted` constructs `ShipActivationState` **before** `ConvertDialToTokenCommand.execute()` runs (the synchronous `activation_modal_open` interaction-state callback in `NetworkHostCommandSubmitter` requires the context); at that moment the Navigate dial is still revealed on the stack, so `_resolve_navigate_availability` caches `_has_navigate_dial = true` and `_yaw_bonus_available = true`. The convert command then pops the dial, but the cached flags persist. Fix: new `ShipActivationState.refresh_navigate_availability()` re-reads the ship's dial / token state, guarded against running after any spend (`_total_speed_change == 0` and `_yaw_bonus_joint < 0`). Called from `GameBoard._on_maneuver_step_entered()` immediately before the maneuver tool opens — by which point the convert command has fully executed on every peer. Symmetric across hot-seat and network. New regression test `test_refresh_navigate_availability_after_dial_to_token_convert`. Total: 143 scripts / 2 873 tests / 5 410 asserts. **MT-J.11** confirmed by user 2026-05-08 in hot-seat and network mode. Commit `86d329e`. |

### 5.8 Out of Scope (this phase)

- Resuming mid-attack / mid-displacement (`interaction_flow != NONE`). The
  user's stated requirement says "safe points only", so loaded state always
  has `interaction_flow = NONE`. Mid-flow resume is technically possible
  (Phase I made it serializable) but is deferred — see Q5.
- Auto-save (covered by G4.9.6 turn-timer flow).
- Replay-file integration with saves (saves are independent of replay logs).
- Cloud / cross-device save sync.

### 5.9 Resolved Decisions (Approved 2026-05-02)

| ID | Decision |
|----|----------|
| Q1 | **Grey out** network saves when no network session is hosted. Tooltip: "Host a game to load this save". Loading a network save is only possible from the host-game flow (slice J7). |
| Q2 | Keep `res://saves/` for now (project-scoped, dev convenience). Migrate to `user://saves/` at publish time as a separate task. |
| Q3 | **Remove** F5 / F8 debug keybinds entirely. All save/load goes through the menu UI. |
| Q4 | **Prompt "Save first?"** on Quit when the game has advanced past the last save. Three-button modal: Save & Quit · Quit Without Saving · Cancel. (If `can_save_now()` is false, the Save & Quit option is disabled with the same tooltip reason as the Save button.) |
| Q5 | **Defer** mid-flow saves. Saves only allowed when `interaction_flow.flow_type == NONE`. Field remains serialisable for future use; loaded state always has flow=NONE. |
| Q6 | Add `save_format_version: 1` to metadata header. Loader rejects unknown versions with a clear error. |
| Q7 | **HMAC-signed**, same scheme as replay (`G4.10.5`). Reuse `ReplayWriter`'s signing helper or extract to a shared `IntegritySigner` utility — decide during J1 implementation. Tampered saves are rejected with a clear error toast. |
| Q8 | Read scenario human-readable name from the scenario JSON (`display_name` field). Fall back to ID title-case if the field is missing. Add the field to existing scenario JSONs as part of J1. |
| Q9 | Phase label in default name uses `Constants.GamePhase` enum name: `Command` / `Ship` / `Squadron` / `Status`. |
| Q10 | ESC menu stays centred, uses the standard main-menu button styling (`MainMenu`'s button theme). Reuse existing modal panel styling per `.skills/ui_styling.md`. |
| Q11 (J5.5) | **Checkpoint refresh trigger:** after every `command_executed` if `can_save_now()` is true. Unsafe-point commands do not refresh. Refresh writes to the **current mode's** slot only. |
| Q12 (J5.5) | **Save button enable rule:** enabled whenever a checkpoint exists **for the current mode** (even mid-flow). Disabled only when the current mode has no checkpoint yet (pre-`game_started` / corrupt). |
| Q13 (J5.5) | **Initial checkpoint:** written on `game_started` and after `start_new_game_from_state`, scoped to the active mode. Source: the freshly built `GameState`. |
| Q14 (J5.5) | **Quit dialog:** Save & Quit always enabled if **current mode's** checkpoint exists; tooltip "Saves last safe point: Round N, <Phase>". |
| Q15 (J5.5) | **Wording:** Save Game button label unchanged. Save dialog title: `Save Game (last safe point: Round N, <Phase>)`. SaveOnQuitDialog primary button: `Save & Quit (last safe point: Round N, <Phase>)`. |
| Q16 (J5.5) | **List visibility:** `_checkpoint_hot_seat` and `_checkpoint_network` are hidden from `list_saves()` / `list_with_meta()`. The filename prefix `_` is reserved for system saves. They surface only as the synthetic "Resume Last Checkpoint" row at the top of each mode section in `LoadGameDialog`. |
| Q17 (J5.5) | **Lifecycle:** persisted on disk; survives app exits. Each checkpoint is independent: loading a save in mode X replaces only mode X's checkpoint and clears mode X's `_last_named_signature`; the other mode's slot is untouched. Starting a new game in mode X likewise only replaces mode X's checkpoint. |
| Q18 (J5.5) | **display_name on save:** the user-typed name. The header's `current_round` / `phase` / `created_at` / `game_mode` are taken from the **checkpoint header** of the active mode, not the live state. |
| Q19 (J5.5) | **Dirty semantics:** per-mode. `is_dirty()` defaults to the active mode and returns `true` iff that mode's checkpoint signature differs from its `_last_named_signature`. SaveOnQuitDialog uses this; if false, Quit returns to the main menu silently without prompting. |
| Q20 (J5.5) | **LoadGameDialog layout:** two stacked sections (Hot-Seat / Network), each headed by a section label. Each section's first row is the synthetic "Resume Last Checkpoint" row (always present; greyed when empty or when network grey-out applies). Filter tabs are removed. |
| Q21 (J5.5) | **Resume row label:** fixed "Resume Last Checkpoint" main line; secondary line `"<scenario_name> · Round N · <Phase> · <created_at>"`. When empty: `"Empty — play a turn to create one."`. |
| Q22 (J5.6) | **Game-board init when state is preloaded:** `GameManager` exposes `is_state_preloaded: bool` (set by `start_new_game_from_state`, cleared by the board after `_ready`). `GameBoard._ready` skips `bootstrap_game()` and the JSON token spawner when the flag is true; instead it spawns tokens from `current_game_state` (positions, hull damage, defense tokens, command dials, squadron state). |
| Q23 (J5.6) | **Main-menu Network grey-out:** Network section in `LoadGameDialog` is shown when opened from the main menu, but every row (resume + named) is disabled with tooltip *"Load network saves from the lobby once both players are connected"*. Loading network from the main menu is forbidden. |
| Q24 (J7) | **Lobby Load gate:** "Load Game" button in `LobbyRoom` is host-only, enabled iff `NetworkManager.peer_count == 2` **and** both peers have pressed Ready. Otherwise disabled with tooltip *"Both players must be connected and Ready"*. |
| Q25 (J7) | **Lobby Load dialog context:** opened from the lobby, the dialog shows Hot-Seat greyed (informational; tooltip *"Hot-seat saves can only be loaded from the main menu"*) and Network active. |
| Q26 (J7) | **Network load broadcast:** new `RPC_LOAD_STATE` payload `{state: Dictionary, scenario_id: String, meta: Dictionary}`. Sent reliable from host to client after host installs state locally. Client installs via `start_new_game_from_state`, shows a 2 s *"Host is loading…"* toast, then transitions to the game board. Old "re-host + kick" design (previous J7) is dropped. |

#### Implications for slice plan

- **J1 scope expands:** add `save_format_version` field, HMAC signing/verification (extract or reuse from `ReplayWriter`), and `display_name` field in `learning_scenario.json` (and any other scenario JSONs).
- **J3 scope expands:** Quit button triggers an "unsaved changes" check; if dirty, opens the three-option Save/Quit/Cancel sub-modal.
- **J3/J4 styling:** match `MainMenu` button theme; centred panel using standard modal style.
- **J5/J7 grey-out:** `LoadGameDialog` shows network saves but disables them when `NetworkManager.is_server() == false`.
- **F5/F8 removal** moves from J8 to J1 (single small edit in `debug_mode.gd`).
- **J5.5 (new):** introduces the checkpoint subsystem inside `SaveGameManager`. Touches: J1 (save_game accepts checkpoint payload), J3 (SaveOnQuitDialog stops greying out + new tooltip), J4 (SaveGameDialog title shows checkpoint metadata), J5 (LoadGameDialog skips `_checkpoint`).

### 5.10 Checkpoint Subsystem (J5.5 design)

**Goal.** Decouple "what gets written when the player presses Save"
from "is the live game right now at a safe point". The player can press
ESC at any moment, even mid-attack, and still be able to save — the file
will contain the most recent safe-point snapshot. Per-mode slots keep
hot-seat and network campaigns independent.

**Storage.** Two system files, both excluded from the user-visible list
per Q16:
- `res://saves/_checkpoint_hot_seat.json`
- `res://saves/_checkpoint_network.json`

Format identical to a normal save: `{header, state}` with HMAC
signature in the header. The filename prefix `_` is reserved for
system saves.

**State held in `SaveGameManager`:**

```gdscript
# One slot per game mode.
var _checkpoints: Dictionary = {
    SaveGameMetadata.MODE_HOT_SEAT: _empty_slot(),
    SaveGameMetadata.MODE_NETWORK: _empty_slot(),
}
# _empty_slot() == {
#     "payload": {},        # last serialized {header, state}
#     "signature": "",      # short id used for dirty comparison
#     "last_named": "",     # signature recorded at last named save
# }
```

**Refresh trigger.** `EventBus.command_executed` → `_on_command_executed`:
1. Determine `mode = _current_game_mode()` (the slot to refresh).
2. If `can_save_now(current_game_state)` is false, return.
3. Build header via `build_metadata_for(current_game_state, "")`.
4. Serialize state, sign payload, store in `_checkpoints[mode].payload`.
5. Update `_checkpoints[mode].signature` (e.g. `created_at + command_count`).
6. Write atomically to `_checkpoint_<mode>.json`.

**Initial checkpoint.** `EventBus.game_started` → same logic for the
active mode, but skips the `can_save_now` gate. The other mode's slot
is left untouched.

**Save flow change.** `save_game(state, name, meta=null)`:
- Look up the current mode's slot. If `payload` is non-empty, copy its
  body and write under `name`, replacing only `display_name` in the
  header (and re-signing).
- If empty, fall back to live serialization (current behaviour).
- On success, set `_checkpoints[mode].last_named = signature`.

**Public API additions:**
- `has_checkpoint(mode: String = "") -> bool` (default = current mode)
- `checkpoint_metadata(mode: String = "") -> SaveGameMetadata`
- `checkpoint_payload(mode: String) -> Dictionary` (used by `LoadGameDialog`'s synthetic resume row to call `load_game_from_payload`)
- `load_game_from_checkpoint(mode: String) -> Dictionary` (returns same shape as `load_game`)

**Public API changes:**
- `is_dirty(mode: String = "") -> bool` — returns
  `slot.signature != slot.last_named` for the given mode
  (default = current mode).
- `can_save_now()` keeps existing semantics (used by the checkpoint
  refresh trigger), but is no longer consulted by the Save button.
- `list_with_meta()` skips any filename starting with `_`.

**UI changes:**
- `GameMenuModal._apply_save_button_state()`:
  enabled iff `SaveGameManager.has_checkpoint()` (current mode).
  Tooltip: `"Saves last safe point: Round N, <Phase>"`.
- `SaveGameDialog` title shows the same hint.
- `SaveOnQuitDialog` primary button: enabled iff `has_checkpoint()`
  for the current mode; label:
  `Save & Quit (last safe point: Round N, <Phase>)`.
- `LoadGameDialog` (rewritten layout):
  - Removes filter tabs.
  - Two stacked sections with headers "Hot-Seat" and "Network".
  - Each section starts with a synthetic **Resume Last Checkpoint** row
    (always present). When empty: greyed, secondary line
    `"Empty — play a turn to create one."`. When populated: secondary
    line `"<scenario_name> · Round N · <Phase> · <created_at>"`.
  - Followed by the named saves of that mode (sorted by `created_at`
    desc). Empty named-saves list under a section is fine — the
    resume row alone is shown.
  - Network section rows (resume + named) follow the existing
    grey-out rule: disabled when no host session is active.
  - Selecting the resume row → Load button calls
    `load_game_from_checkpoint("hot_seat" | "network")`.

**Persistence on app start.** `SaveGameManager._init` (or first call to
`has_checkpoint()`) reads both `_checkpoint_<mode>.json` files if they
exist, validates signature, populates `_checkpoints`. Invalid file →
ignored (treated as no-checkpoint for that mode).

**Edge cases handled:**
- Game ends (victory) → leave checkpoint in place; player can still save
  the final state via ESC menu before returning to main menu.
- Load a save in mode X → the loaded state's initial checkpoint
  replaces mode X's slot; `_checkpoints[X].last_named` is set to the
  new signature (so quit-without-saving doesn't prompt immediately
  after load). Mode ¬X's slot is untouched.
- Crash mid-game → next launch, the appropriate checkpoint exists; if
  user starts a new game in that mode, it is replaced. (Crash recovery
  UI surfaces via the resume row in `LoadGameDialog`.)
- Mode mismatch on resume row click: the row's metadata determines
  which slot to load; current `PlayMode` does not affect this.

---

## 6. Planned Extensions (Post-MVP)

Ordered by dependency:

1. **Phase L/M — Modal Lifecycle + Flow Authority** *(in progress; Phase L and M0-M0.7 complete, M1 next)* — see [docs/refactoring_phase_lm_plan.md](refactoring_phase_lm_plan.md). Removes remaining modal-lifecycle PlayMode branches through `UIProjector` + `ModalRouter`, then promotes flow/step handling into declarative specs.
2. **Saved Games** — Phase J ✅ done (J1–J11)
3. **Squadron Cards** — full data loading from JSON (already partially loaded)
4. **Fleet Builder** — point-based fleet construction UI
5. **Upgrade Cards** — effect hook system architecture is ready (`EffectRegistry`)
6. **Terrain / Obstacles** — geometry system extension
7. **Objectives** — scenario-variant scoring
8. **Multiplayer (full release)** — depends on G4.7–G4.9, auto-save, and L/M flow hardening

---

## 7. Document Map

### Active Architecture Docs

- [docs/arc42/](arc42/) — full arc42 architecture documentation (sections 00–12)
- [.skills/](../.skills/) — coding standards, refactoring guidelines, serialization contract, UI styling, copilot instructions

### Active Design Refs (kept; consult when modifying related code)

- [docs/modal_classification.md](modal_classification.md) — modal kinds, dismissibility, anchor patterns
- [docs/modal_timing_diagrams.md](modal_timing_diagrams.md) — modal lifecycle timing in network mode
- [docs/dial_activation_flow.md](dial_activation_flow.md) — dial reveal/spend sequence
- [docs/attack_target_resolver_call_site_map.md](attack_target_resolver_call_site_map.md) — attack target resolution call sites
- [docs/release_ops.md](release_ops.md) — release runbook for macOS export, DMG packaging, and two-machine LAN validation

### Archived (historical reference only — see [docs/old/](old/))

- [docs/old/progress_summary.md](old/progress_summary.md) — phase-by-phase history with commits and test counts
- [docs/old/open_topics.md](old/open_topics.md) — detailed §4.6 violations, MT log, pre-Phase-I tracker
- [docs/old/refactoring_phase_i_plan.md](old/refactoring_phase_i_plan.md) — Phase I plan (now closed)
- [docs/old/refactoring_test_strategy.md](old/refactoring_test_strategy.md) — Phase A–E manual test protocol
- [docs/old/g4_network_plan.md](old/g4_network_plan.md) — full G4 multiplayer plan (G4.7–G4.9 sections still authoritative)
- [docs/old/architecture_assessment.md](old/architecture_assessment.md) — refactor-vs-rewrite analysis (2026-04-07)
- [docs/old/implementation_plan.md](old/implementation_plan.md) — original phase plan
- [docs/old/refactoring_plan.md](old/refactoring_plan.md) — original Phases A–H plan
- [docs/old/test_plan_manual.md](old/test_plan_manual.md) — original MT plan

---

## 8. Update Procedure

When completing a phase or sub-phase task:

1. Update §1 baseline (test counts, last commit).
2. Update the relevant phase row in §2 (status, brief outcome).
3. If applicable, update §4 (move resolved items out, add new pending items).
4. Update arc42 §11 (`risks_and_technical_debt.md`) if technical debt
   changes.
5. Run the manual test gate (`.skills/copilot_instructions.md`).
6. Commit: `docs: <subject>` with body summarising the change. Use the
   `printf` + `git commit -F` pattern from `.github/copilot-instructions.md`.

> Historical detail (per-slice narratives, MT logs, fix follow-ups) lives
> in commit messages and the archived `docs/old/` files. Keep this file
> forward-looking and concise.

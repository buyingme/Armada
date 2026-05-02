# Implementation Plan — Star Wars: Armada Digital Edition

> **Single source of truth** for project status, remaining work, and pointers
> to architecture and design references. Replaces and supersedes:
> `progress_summary.md`, `open_topics.md`, `refactoring_phase_i_plan.md`,
> `refactoring_test_strategy.md`, `g4_network_plan.md`, and
> `architecture_assessment.md` — all archived under [docs/old/](old/).
>
> Last updated: 2026-05-02 (Phase J1 complete; Phase G4.7+ pending)

---

## 1. Current Baseline

| Metric | Value |
|--------|-------|
| GUT test scripts | 136 |
| GUT tests | 2 796 |
| GUT asserts | 5 252 |
| Failing tests | 0 |
| Last commit | `2c59f39` (Phase J1 — save metadata + HMAC + safe-point gate, 2026-05-02) |

Runtime invariants:
- All `GameState` mutations route through `GameCommand.execute()`
  (§4.6 P1–P7 + debug all resolved).
- All UI flow state lives in `GameState.interaction_flow` and replicates over
  the canonical `command_result` channel (Phase I).
- Hot-seat and network use the same command path through a `CommandSubmitter`
  strategy; no parallel network channel.
- Deterministic replay via `GameRng` + `GameReplay` works in both modes.

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
| **G4.7 Spectator Mode** | ⏳ pending |
| **G4.8 Reconnection (runtime)** | ⏳ pending — acceptance test exists (Phase I7); RPC/timer runtime not yet implemented |
| **G4.9 Turn Timers** | ⏳ pending |
| G4.10 Dedicated Server Binary | ✅ |

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
  `CommitDisplacementCommand` so the modal opens on the squadron-owner
  peer (OV-002 fix).
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
| SG-5 | Save is only allowed at **safe points** (see §5.3). At unsafe points the Save button is disabled with an explanatory tooltip. |
| SG-6 | In network mode, only the host may save; clients see "Save Game" disabled / hidden. Hot-seat: always allowed (at safe points). |
| SG-7 | Loading a save restores the game such that play continues exactly from the saved point: same active player, same dials, same tokens, same damage cards, same RNG sequence; `interaction_flow` is `NONE` after load (we do not resume mid-attack — see §5.7 / Q5). |
| SG-8 | Loading is offered from (a) the main menu ("Load Game" button), and (b) the in-game ESC menu ("Load Game"). In both cases the active game is torn down before the saved state is installed. |
| SG-9 | In network mode, "Load Game" from the in-game menu is host-only; clients see Quit / Resume only. Loading from the main menu is offered to any user but only for hot-seat slot (see Q1 for network-load policy). |
| SG-10 | ESC on the main game board with no modal open opens the new in-game menu (see §5.4). On a second ESC press the menu closes ("Resume"). |
| SG-11 | Existing F5 quicksave keybind: removed (or aliased to "save with default name", see Q3). Existing F8 quickload removed in favour of the menu flow. |

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
| J2 | `GameManager.start_new_game_from_state(state, scenario_id)` — install deserialised state, re-resolve templates, emit `game_started` so board rebuilds. Hot-seat only. | Unit / integration: round-trip serialize → deserialize → install → all ships present, dials match, damage deck matches. | MT-J.2 — F8 from debug now actually restores the game. |
| J3 | `GameMenuModal` replaces `QuitConfirmationModal`: 4 buttons (hot-seat/host) / 2 buttons (client), ESC-toggle, centred with main-menu button styling. Quit triggers "Save first?" sub-modal when game is dirty. Save / Load buttons stub-disabled. | Unit: button visibility per mode; ESC open/close; dirty-on-quit prompt. | MT-J.3 — ESC menu shows correct buttons in each mode; second ESC resumes; quit-when-dirty prompts. |
| J4 | `SaveGameDialog` — name field with default template, Save/Cancel, validation (non-empty, no path separators, max 64 chars), overwrite confirmation. Wired into `GameMenuModal` (hot-seat + host only). | Unit: name validation; default template builder. | MT-J.4 — save in hot-seat with default name and with edited name; verify file on disk. |
| J5 | `LoadGameDialog` — list with metadata, filter by game mode tab, Load/Cancel. Network-mode saves greyed out when no host session. Wired into both main menu and `GameMenuModal`. On load, tear down active game (if any), call `start_new_game_from_state`. | Unit: list rendering, filter; greyed-out network rows; round-trip from list selection. | MT-J.5 — load from main menu and from ESC menu; resume play; verify counts match. |
| J6 | Network-host save: `NetworkManager.is_server()` guard in dialog; "Save" submits a server-side save (host's authoritative `GameState`); broadcast result toast to client. | Unit: client cannot trigger save (host-only RPC guard). | MT-J.6 — host saves mid-network-game; verify file; client sees confirmation toast. |
| J7 | Network load (Q1-dependent): host loads a save → re-host with loaded state, clients are kicked with "Game reloaded — please rejoin" message. | Integration: host re-host flow. | MT-J.7 — host re-loads; client gets disconnect message; rejoin lands in correct state. |
| J8 | Cleanup: remove old `QuitConfirmationModal` references; update arc42 §05 to add `SaveGameMetadata` + `GameMenuModal`. | — | MT-J.8 — full hot-seat + network regression. |

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

#### Implications for slice plan

- **J1 scope expands:** add `save_format_version` field, HMAC signing/verification (extract or reuse from `ReplayWriter`), and `display_name` field in `learning_scenario.json` (and any other scenario JSONs).
- **J3 scope expands:** Quit button triggers an "unsaved changes" check; if dirty, opens the three-option Save/Quit/Cancel sub-modal.
- **J3/J4 styling:** match `MainMenu` button theme; centred panel using standard modal style.
- **J5/J7 grey-out:** `LoadGameDialog` shows network saves but disables them when `NetworkManager.is_server() == false`.
- **F5/F8 removal** moves from J8 to J1 (single small edit in `debug_mode.gd`).

---

## 6. Planned Extensions (Post-MVP)

Ordered by dependency:

1. **Saved Games** — Phase J (proposed in §5); depends on serialization (✅ done) + replay (✅ done)
2. **Squadron Cards** — full data loading from JSON (already partially loaded)
3. **Fleet Builder** — point-based fleet construction UI
4. **Upgrade Cards** — effect hook system architecture is ready (`EffectRegistry`)
5. **Terrain / Obstacles** — geometry system extension
6. **Objectives** — scenario-variant scoring
7. **Multiplayer (full release)** — depends on G4.7–G4.9 + auto-save

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

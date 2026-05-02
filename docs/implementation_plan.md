# Implementation Plan — Star Wars: Armada Digital Edition

> **Single source of truth** for project status, remaining work, and pointers
> to architecture and design references. Replaces and supersedes:
> `progress_summary.md`, `open_topics.md`, `refactoring_phase_i_plan.md`,
> `refactoring_test_strategy.md`, `g4_network_plan.md`, and
> `architecture_assessment.md` — all archived under [docs/old/](old/).
>
> Last updated: 2026-05-02 (Phase I closed; Phase G4.7+ pending)

---

## 1. Current Baseline

| Metric | Value |
|--------|-------|
| GUT test scripts | 134 |
| GUT tests | 2 761 |
| GUT asserts | 5 175 |
| Failing tests | 0 (2 pre-existing scenario-WIP failures from unrelated user edits to `learning_scenario.json`) |
| Last commit | `1c2b32c` (I7 reconnection acceptance gate, 2026-05-02) |

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

## 5. Planned Extensions (Post-MVP)

Ordered by dependency:

1. **Saved Games** — depends on serialization (✅ done) + replay (✅ done)
2. **Squadron Cards** — full data loading from JSON (already partially loaded)
3. **Fleet Builder** — point-based fleet construction UI
4. **Upgrade Cards** — effect hook system architecture is ready (`EffectRegistry`)
5. **Terrain / Obstacles** — geometry system extension
6. **Objectives** — scenario-variant scoring
7. **Multiplayer (full release)** — depends on G4.7–G4.9 + auto-save

---

## 6. Document Map

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

## 7. Update Procedure

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

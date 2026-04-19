# Open Topics

> Star Wars: Armada — Digital Edition
> Last updated: 2026-04-19 (G4.5)
> Current baseline: 123 scripts, 2 561 tests, 4 723 asserts

---

## 1. §4.6 Violations — Mutations Outside GameCommand.execute()

34 violations found across 8 files. Every mutation of `GameState`-owned data
must route through a `GameCommand.execute()` for replay/multiplayer safety.
P1–P7 + debug all resolved — G4 (network transport) unblocked.

### Priority 1 — Game Flow (3 violations → 2 commands) ✅ RESOLVED

Both commands implemented and wired:

| Command | Wired In |
|---------|----------|
| `AdvancePhaseCommand` | `game_manager.gd` — `advance_phase()` |
| `StartRoundCommand` | `game_manager.gd` — `_start_round()` |

Tests: `test_game_flow_commands.gd` — validate, execute, serialize/deserialize for both.

### Priority 2 — Status Phase Cleanup (5 violations → 2 commands) ✅ RESOLVED

Both commands implemented and wired:

| Command | Wired In |
|---------|----------|
| `StatusPhaseCleanupCommand` | `game_manager.gd` — `_perform_status_phase_cleanup()` |
| `DestroyUnitCommand` | `game_manager.gd` — `_on_ship_destroyed()` |

Tests: `test_status_destroy_commands.gd` — validate, execute, serialize/deserialize for both.

### Priority 3 — Attack Damage (7 violations → 1 command) ✅ RESOLVED

Single consolidated command implemented and wired:

| Command | Wired In |
|---------|----------|
| `ResolveDamageCommand` | `attack_executor.gd` — `_resolve_ship_damage()`, `_resolve_squadron_damage()` |

`_apply_single_redirect()` was already routed through `SelectRedirectZoneCommand`.
`_resolve_ship_damage()` destruction (`mark_destroyed()`) is now inside the command.
Shield absorption (`_absorb_shields`) replaced by pre-computation + command.
Damage card dealing (`_deal_damage_cards`, `_deal_single_faceup_card`) split into
pre-draw (deck stays in executor) and command-based mutation + post-process events.

Tests: `test_resolve_damage_command.gd` — validate, execute, serialize/deserialize.

### Priority 4 — Repair Actions (3 violations → 1 command) ✅ RESOLVED

Single parameterised command implemented and wired:

| Command | Wired In |
|---------|----------|
| `RepairActionCommand` | `repair_resolver.gd` — `move_shields()`, `recover_shields()`, `repair_hull()` via `GameManager.submit_repair_*()` |

Three action types dispatched by `action_type` discriminator: `move_shields`,
`recover_shields`, `repair_hull`. Resolver pre-validates affordability and
effect hooks, then delegates the actual `GameState` mutation to the command.
Point tracking remains in the resolver (transient session state).

Tests: `test_repair_action_command.gd` — validate (happy + rejection for all 3
action types), execute (move, recover, hull facedown/faceup/discard),
serialize/deserialize roundtrip.

### Priority 5 — Immediate Effects (8 violations → 1 command) ✅ RESOLVED

Single parameterised command implemented and wired:

| Command | Wired In |
|---------|----------|
| `ResolveImmediateEffectCommand` | `attack_executor.gd` — `_resolve_immediate_card_effect()`, `_on_immediate_choice_confirmed()` + `game_board.gd` — debug immediate effect paths |

Six damage card effects dispatched by `effect_id` discriminator:
`structural_damage`, `projector_misaligned`, `life_support_failure`,
`injured_crew`, `shield_failure`, `comm_noise`.  Presentation layer gathers
choices (async UI), then submits the command.  EventBus signals emitted by
callers after `execute()` returns.

Tests: `test_resolve_immediate_effect_command.gd` — validate (happy + rejection
for general, projector, injured_crew, shield_failure, comm_noise), execute for
all 6 effects, serialize/deserialize roundtrip.

### Priority 6 — Overlap, Speed, Persistent Effects (3 violations → 3 commands) ✅ RESOLVED

Three commands implemented and wired:

| Command | Wired In |
|---------|----------|
| `SetSpeedCommand` | `maneuver_tool_scene.gd` — `_handle_speed_change()` |
| `OverlapDamageCommand` | `game_board.gd` — `_apply_overlap_damage()` |
| `PersistentEffectDamageCommand` | `game_board.gd` — `_resolve_after_maneuver_hook()`, `_on_crew_panic_choice()` + `maneuver_tool_scene.gd` — `_resolve_speed_change_hook()` |

`apply_speed_change()` in `ShipActivationState` is now budget-only; the actual
`set_speed()` mutation is performed by `SetSpeedCommand`.
`_resolve_suffer_facedown()` in `DamageCardEffect` now flags `extra_damage_dealt`;
the caller pre-draws from `DamageDeck` and submits `PersistentEffectDamageCommand`.
Overlap damage pre-draws 2 cards and submits `OverlapDamageCommand`.

Tests: `test_p6_commands.gd` — validate (happy + rejection for all 3 commands),
execute (speed change, overlap survive/destroy, persistent effects), serialize/
deserialize roundtrip.

### Priority 7 — UI State & Tokens (3 violations → 2 commands) ✅ RESOLVED

Both commands implemented and wired:

| Command | Wired In |
|---------|----------|
| `DiscardTokenCommand` | `ship_card_panel.gd` — `_on_discard_token_click()` via `GameManager.submit_discard_token()` |
| `RevealDialCommand` | `ship_card_panel.gd` — `_try_ship_phase_activation()` / `_unreveal_other_ships()` + `dial_drag_controller.gd` — `_cancel_drag()` via `GameManager.submit_reveal_dial()` / `submit_unreveal_dial()` |

Token overflow discard now routes through `DiscardTokenCommand` (validates
overflow condition).  Dial reveal/unreveal now routes through `RevealDialCommand`
with `"action": "reveal"` or `"unreveal"` discriminator.

Tests: `test_p7_commands.gd` — validate (happy + rejection for both commands),
execute (discard, reveal, unreveal), serialize/deserialize roundtrip.

### Debug-only (1 violation → 1 command) ✅ RESOLVED

| Command | Wired In |
|---------|----------|
| `DebugDealDamageCommand` | `game_board.gd` — `_debug_deal_faceup_card()` via `GameManager.submit_debug_deal_damage()` |

Tests: `test_debug_deal_damage_command.gd` — validate (happy + rejection),
execute (persistent + immediate cards, hull math), serialize/deserialize roundtrip.

### Summary

| Priority | Violations | New Commands | Blocks Multiplayer |
|----------|-----------|-------------|-------------------|
| P1 | 3 | 2 | ✅ Done |
| P2 | 5 | 2 | ✅ Done |
| P3 | 7 | 1 | ✅ Done |
| P4 | 3 | 1 | ✅ Done |
| P5 | 8 | 1 | ✅ Done |
| P6 | 3 | 3 | ✅ Done |
| P7 | 3 | 2 | ✅ Done |
| Debug | 1 | 1 | ✅ Done |
| **Total** | **35** | **~14** | **All resolved — G4 unblocked** |

---

## 2. ~~Unwired Command Infrastructure~~ ✅ RESOLVED

All six command classes are now wired into their presentation-layer call sites:

| Command | Wired In |
|---------|----------|
| `RollDiceCommand` | `attack_executor.gd` — `_on_attack_roll_dice()` |
| `SpendDefenseTokenCommand` | `attack_executor.gd` — `_on_attack_defense_token_spent()` |
| `SelectRedirectZoneCommand` | `attack_executor.gd` — `_apply_single_redirect()` |
| `SkipAttackCommand` | `attack_executor.gd` — `_on_attack_skip()` + auto-skip |
| `MoveSquadronCommand` | `squadron_phase_controller.gd` — `_on_squadron_move_commit()` |
| `ExecuteManeuverCommand` | `game_board.gd` — `_on_execute_maneuver()` |

---

## 3. Remaining Implementation Phases

| Phase | Name | Status | Blocker |
|-------|------|--------|---------|
| G4.10 | Dedicated Server Binary | ✅ | ServerMain autoload, export preset, HMAC, CI |
| G4.1 | Network Transport Foundation | ✅ | NetworkManager, PlayerProfile, TestNetworkHarness |
| G4.2 | Server-Side Command Processing | ✅ | CommandSubmitter strategy, GameManager wiring, server RPCs |
| G4.3 | Information Hiding | ✅ | StateFilter utility, secret canary tests |
| G4.4 | Command Phase Sync Gate | ✅ | CommandSyncGate, NetworkManager wiring |
| G4.5–G4.9 | Lobby, Chat, etc. | ⏳ | Depends on G4.4 |
| 10c | Network Foundation | ⏳ | Depends on G4 |

All other implementation phases (0–12) are complete.

---

## 3.5 Known Visual Bugs

| Bug | Severity | Observed | Notes |
|-----|----------|----------|-------|
| Activated squadron loses ghosted appearance after ship-overlap displacement | Minor (visual only) | 2026-04-12 | When an activated squadron is displaced due to collision with a capital ship (e.g. VSD manoeuvring into it), the ghosted/dimmed activated visual state is lost. Game logic is correct — the squadron cannot be re-activated. |

## 3.6 Resolved Bugs

| Bug | Severity | Observed | Fixed | Notes |
|-----|----------|----------|-------|-------|
| Squadron attacks fail during Squadron Phase — dice not rolled | **Blocker** | 2026-04-13 | 2026-04-13 | `RollDiceCommand`, `SkipAttackCommand`, `SpendDefenseTokenCommand`, `SelectRedirectZoneCommand` only accepted SHIP phase. Squadron-phase attacks were rejected. Fix: accept both SHIP and SQUADRON phases. |
| No replay saved on game exit | Minor (DX) | 2026-04-14 | 2026-04-14 | `GameManager.auto_save_replay()` now saves to `res://replays/` on game over, ESC quit, victory quit, and window close. |

---

## 4. Open Manual Tests

233 manual test cases were written. 33 formally passed (with date stamps).
~200 remain untested or lack formal result annotations.

### Phase G4.10 — Dedicated Server Binary

### MT-G4.10.1 — ServerMain autoload does not affect normal game ✅ passed 2026-04-18

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the game normally (no `--server` flag) | Main menu appears, game is fully playable |
| 2 | Check console output | No "Dedicated server started" log message |
| 3 | Play a full round (command → ship → squadron → status) | All phases work identically to pre-G4.10 |

**Pass criteria:** Normal game flow is unaffected by the new ServerMain autoload.

### MT-G4.10.2 — ServerMain detects --server flag ✅ passed 2026-04-18

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `./scripts/run_game.sh --server` from terminal | Log shows "Dedicated server started — port=7350, scenario=''" |
| 2 | Check that PlayMode is NETWORK | Log shows "PlayMode=NETWORK, audio muted" |
| 3 | Ctrl+C to stop | Process exits cleanly |

**Pass criteria:** Server mode is correctly detected and configured.

### MT-G4.10.3 — HMAC replay signing ✅ passed 2026-04-18

Verified via 31 unit tests (`test_server_main.gd`): sign adds HMAC to header,
verify accepts correct key, rejects wrong key, detects tampered commands/header/
HMAC, survives file save/load roundtrip.

**Pass criteria:** HMAC signing and verification work correctly; tampering is detected.

### MT-G4.10.4 — Headless GUT validation ✅ passed 2026-04-18

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 119 scripts, 2460 tests, 0 failures |

**Pass criteria:** Full test suite passes in headless mode.

### Phase G4.1 — Network Transport Foundation

### MT-G4.1.1 — Normal game unaffected by NetworkManager + PlayerProfile ✅ passed 2026-04-18

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the game normally (no `--server` flag) | Main menu appears, game is fully playable |
| 2 | Check console output | No "Server hosting" or "Connecting to" log messages |
| 3 | Play a full round (command → ship → squadron → status) | All phases work identically to pre-G4.1 |

**Pass criteria:** New autoloads (PlayerProfile, NetworkManager) do not affect normal local play.

### MT-G4.1.2 — Headless GUT validation ✅ passed 2026-04-18

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 119 scripts, 2460 tests, 0 failures |

**Pass criteria:** Full test suite passes including new network tests.

### Phase G4.2 — Server-Side Command Processing

### MT-G4.2.1 — Normal game unaffected by CommandSubmitter + is_replaying

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the game normally (no `--server` flag) | Main menu appears, game is fully playable |
| 2 | Play a full round (command → ship → squadron → status) | All phases work identically to pre-G4.2 |
| 3 | Save replay with Shift+R | Replay file saved without errors |

**Pass criteria:** CommandSubmitter strategy (LocalCommandSubmitter default) does not affect normal local play.

### MT-G4.2.2 — Headless GUT validation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 120 scripts, 2480 tests, 0 failures |

**Pass criteria:** Full test suite passes including new G4.2 tests.

### Phase G4.3 — Information Hiding

### MT-G4.3.1 — Normal game unaffected by StateFilter ✅ passed 2026-04-18

StateFilter is a pure utility with no scene-tree or autoload dependency.
Normal local play does not invoke it. Verified by MT-G4.2.1 (game still works).

### MT-G4.3.2 — Headless GUT validation ✅ passed 2026-04-18

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 121 scripts, 2505 tests, 0 failures |

**Pass criteria:** Full test suite passes including 25 new StateFilter tests.

### Phase G4.4 — Command Phase Sync Gate

### MT-G4.4.1 — Normal game unaffected by CommandSyncGate ✅ passed 2026-04-19

CommandSyncGate is only activated in network mode. The sync gate
wiring in NetworkManager and GameManager does not affect hot-seat play
because `PlayMode.is_network()` returns false and the gate stays inactive.

### MT-G4.4.2 — Headless GUT validation ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 122 scripts, 2526 tests, 0 failures |

**Pass criteria:** Full test suite passes including 21 new CommandSyncGate tests.

### MT-G4.5.1 — Main menu Host/Join buttons

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game via `scripts/run_game.sh` | Splash screen appears, menu fades in after 2s |
| 2 | Observe main menu buttons | "Host Game" and "Join Game" buttons visible between "Learning Scenario" and "Quit" |
| 3 | Click "Host Game" | Host dialog appears with "Lobby Name:" input and Host/Cancel buttons |
| 4 | Click "Cancel" | Returns to main menu |
| 5 | Click "Join Game" | Join dialog appears with "Server IP Address:" input and Connect/Cancel buttons |
| 6 | Click "Cancel" | Returns to main menu |

**Pass criteria:** Both dialogs render correctly with UIStyleHelper modal styling (dark panel, blue border, gold title).

### MT-G4.5.2 — Host game creates lobby room

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "Host Game", enter "Test Lobby" as name, click "Host" | Lobby room appears with "Test Lobby" title and 6-char lobby code |
| 2 | Observe player list | P1 row shows host's display name, "Not Ready". P2 row shows "Waiting..." |
| 3 | Click "Ready" | Button text changes to "Not Ready", P1 row shows "✓ Ready" in green |
| 4 | Click "Not Ready" | Button text changes to "Ready", P1 row shows "Not Ready" |
| 5 | Click "Leave" | Returns to main menu |

**Pass criteria:** Lobby room displays correctly, ready toggle works, leave returns to menu.

### MT-G4.5.3 — Headless GUT validation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 123 scripts, 2561 tests, 0 failures |

**Pass criteria:** Full test suite passes including 35 new LobbyState tests.

### Awaiting First Test (highest priority — recent changes)

| ID | Description |
|----|-------------|
| MT-G.13 | Command registration count is now 13 | ✅ passed 2026-04-12 |
| MT-G.14 | Repair flow: dial + token spend through commands | ✅ passed 2026-04-12 (bug fixed) |
| MT-G.15 | Squadron command flow: dial + token spend through commands | ✅ passed 2026-04-12 |
| MT-P4.01–05 | Repair panel: move/recover/hull through commands | ✅ passed 2026-04-14 |
| MT-P5.01–07 | Immediate effects: all 6 card effects through commands | ✅ passed 2026-04-14 |
| MT-P6.01–08 | Overlap, speed, persistent: all 3 commands + bug fixes | ✅ passed 2026-04-15 |
| MT-P7.01–03 | Discard token, reveal/unreveal dial, replay save | ✅ passed 2026-04-18 |
| MT-G4.10.01–04 | Dedicated server binary: autoload, --server flag, HMAC, headless GUT | ✅ passed 2026-04-18 |
| MT-G4.1.01–02 | Network transport: normal game unaffected, headless GUT 119/2460 | ✅ passed 2026-04-18 |
| MT-G4.2.01–02 | Server-side command processing: normal game unaffected, headless GUT 120/2480 | ✅ passed 2026-04-18 |
| MT-G4.3.01–02 | Information hiding: normal game unaffected, headless GUT 121/2505 | ✅ passed 2026-04-18 |
| MT-G4.4.01–02 | Sync gate: normal game unaffected, headless GUT 122/2526 | ✅ passed 2026-04-19 |
| MT-G4.5.01 | Lobby system: main menu shows Host/Join buttons, host creates lobby room |
| MT-G4.5.02 | Lobby system: headless GUT 123/2561 |
| MT-G.16 | Concentrate Fire attack: dial + token spend through commands |
| MT-G.17 | Crew Panic faceup crit: dial discard through command |
| MT-G.18 | Navigate token on speed-0: token spend through command |
| MT-G.11 | Attack commands registered at startup | passed
| MT-G.12 | Movement commands registered at startup | passed

### Never Formally Stamped (bulk — by area)

Most of these were likely passed informally during development but never annotated.
A full regression pass should stamp or prune these.

| Area | Test Count | IDs |
|------|-----------|-----|
| Board & Camera (Phase 2) | 12 | MT-2.1–2.12 |
| Debug Placement (Phase 2b) | 7 | MT-2b.1–2b.7 |
| Command Phase (Phase 4) | 10 | MT-4.1–4.10 |
| Turn Management (Phase 4b) | 6 | MT-4b.1–4b.6 |
| Logging (Phase L) | 8 | MT-L.1–L.8 |
| Ship Activation (Phase 4c) | 11 | MT-4c.1–4c.11 |
| Keep/Convert (Phase 4d) | 4 | MT-4d.1–4d.4 |
| Token Overflow (Phase 4e) | 4 | MT-4e.1–4e.4 |
| Tooltips (Phase 4f) | 5 | MT-4f.1–4f.5 |
| Fixed Commands (Phase 4g) | 5 | MT-4g.1–4g.5 |
| Maneuver Tool (Phase 5a/5a+) | 11 | MT-5a.1–5a+.6 |
| Ship Movement (Phase 5b) | 12 | MT-5b.1–5b.12 |
| Range Overlay (Phase 5c) | 9 | MT-5c.1–5c.9 |
| Targeting List (Phase 5d) | 10 | MT-5d.1–5d.10 |
| Attack Pipeline (Phase 6) | 50+ | MT-6a–6c.* |
| Squadron Phase (Phase 7/7b) | 20 | MT-7.1–7b.9 |
| Status & Scoring (Phase 8) | 8 | MT-8.1–8.8 |
| Repair & Damage (Phase 9) | 13 | MT-9.1–9.5.7 |
| Damage Card Effects (Phase 9.6) | 11 | MT-9.6.01–9.6.11 |
| Overlap Handling (Phase 5b-2) | 6 | MT-5b2.1–5b2.6 |
| UI Polish (Phase 10b) | 3 | MT-10b.1–10b.3 |
| Splash & Menu (Phase 11) | 11 | MT-11.1–11.11 |
| Sound & Music (Phase 12) | 12 | MT-12.1–12.12 |
| Refactoring regressions | ~50 | MT-A*, MT-B*, MT-C*, MT-D*, MT-F* |
| Bug fixes & misc | ~15 | MT-BF.*, MT-LOS*, MT-PTBF.*, MT-DMG.*, MT-DSO.* |

> **Recommendation:** Do a focused regression pass on MT-G.13–G.18 (recent changes),
> then a broader sweep can be done before the next major milestone.

---

## 5. Requirements Still Pending

| Section | Status | Notes |
|---------|--------|-------|
| Network (NW-001–008) | ⏳ | 8 requirements, deferred to Phase 10c after G4 |

All other requirement sections are fully covered.

---

## 6. Planned Extensions (Post-MVP)

From the original refactoring plan, ordered by dependency:

1. **Saved Games** — depends on serialization (✅ done) + §4.6 resolution
2. **Squadron Cards** — data loading from JSON
3. **Fleet Builder** — point-based fleet construction UI
4. **Upgrade Cards** — effect hook system (✅ architecture ready)
5. **Terrain/Obstacles** — geometry system extension
6. **Objectives** — scenario-variant scoring
7. **Multiplayer** — depends on G4 + §4.6 P1–P4 resolution

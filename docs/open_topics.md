# Open Topics

> Star Wars: Armada — Digital Edition
> Last updated: 2026-04-27 (Phase I in progress — I0/I1/I2/I3/I4/I5 ✅)
> Current baseline: 130 scripts, 2 677 tests, 4 961 asserts

---

## 0. Phase I — Interaction-Flow as Domain State (IN PROGRESS)

Network integration is stuck because UI-flow state lives outside `GameState`
and is synchronised over a parallel RPC channel (`NetworkInteractionState`).
Phase I promotes interaction-flow state to a serializable field of
`GameState`, extracts `AttackFlowFSM`, introduces `UIProjector`, and deletes
the parallel channel.

**Plan:** [docs/refactoring_phase_i_plan.md](refactoring_phase_i_plan.md)

| Sub-step | Goal | Status |
|----------|------|--------|
| I0 | Inventory + freeze + CI lint | ✅ `d1769a8` |
| I1 | Add `InteractionFlow` + enums + `StateFilter` rule | ✅ `cd81086` (+27 tests) |
| I2 | Mirror flow into 7 commands (invariant test) | ✅ `7db873a` (+11 tests, MT passed 2026-04-26) |
| I3 | Extract `AttackFlowFSM` (deferred Phase F4) | ✅ `5647edf`/`6fcc9f1`/`a89e9a8` (+39 tests) — LOC target deferred |
| I4 | `UIProjector` pilot — HUD | ✅ MT-PHI.04 passed 2026-04-26 |
| I5 | Migrate sidebar + activation modal + squadron modal | ✅ MT-PHI.05 / 05b passed 2026-04-27 (fix log I5b-1…5 in `docs/modal_timing_diagrams.md`) |
| I6a | Migrate `game_board.gd` `interaction_state_changed` consumer to `UIProjector` + `command_executed` | ✅ `e288fa9` MT-PHI.06a passed 2026-04-28 |
| I6b | Project attack UI from `interaction_flow.payload` — slice 1: `UIIntent` extension; slice 2: AE payload extension (`defender_ship_index`/`speed`/`zone`); slice 3 (TBD): defender-side panel mirror, requires defense-step refactor — see `docs/refactoring_phase_i_plan.md` §I6b followups | 🔄 slices 1+2 complete |
| I6c | Delete `NetworkInteractionState` RPC + `EventBus.interaction_state_changed` + `GameManager._publish_interaction_state_for_command` | ✅ MT-PHI.06c passed 2026-04-28 (130 / 2 701 / 5 039) |
| I6d | Trim remaining `is_network()` branches in `game_board.gd` to ≤ 3 (camera/perspective only) | 🔄 partial — activation-modal authority migrated; 10 → 9 branches; remaining 9 require relocating host-only / divergent-timing logic out of `game_board.gd` (planned as I6e) |
| I7 | Reconnection acceptance test + cleanup | ⏳ |

### MT-PHI.01 — I1+I2 dormant flow does not regress live game ✅ passed 2026-04-26

**Purpose:** Verify that adding `GameState.interaction_flow` and mirroring
it into 7 commands does not change observable in-game behaviour while the
legacy `NetworkInteractionState` channel is still active.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Hot-seat: full round (Command → Ship → Squadron → Status) | Identical UI; no errors. |
| 2 | Networked: each seat activates one ship (`run_network_test.sh --gui-host --logging`) | Activation modal opens correctly on both clients; no double-modals or stuck waits. |
| 3 | F5 quicksave mid-Ship-Phase, then F8 quickload | Quickload toast logs round/phase; no crashes. (Quickload restore not yet implemented.) |
| 4 | Replay an existing file under `replays/` | Plays back without "InteractionFlow not found" errors. |

**Result:** All steps green on 2026-04-26. Continuing with I3.

### MT-PHI.04 — I4 `UIProjector` HUD pilot does not regress hot-seat or network HUD 🔄 pending

**Purpose:** Verify the new `UIProjector`-driven HUD status path produces
the same score-header text as the legacy parallel channel, in both
hot-seat and networked modes.  The projector runs in parallel with the
legacy handler in I4; this MT confirms there is no flicker, no stale text,
and no missing prompts.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Hot-seat: full Command Phase round | Score header shows "make your choices" while a player picks dials; identical to before. |
| 2 | Hot-seat: ship activation (dial reveal → maneuver → end) | Score header reads "make your choices" for the active player throughout; no flicker between commands. |
| 3 | Networked (`./scripts/run_network_test.sh --gui-host --logging`): each seat activates one ship | On controller's screen: "make your choices". On opponent's screen: "waiting for opponent's choice". Both update consistently after every command. |
| 4 | Networked: trigger one attack between two ships | HUD remains correct on both clients across declare → roll → defense → resolve. (Defense-token UI sync is still pending I5/I6 — only HUD text is in scope.) |
| 5 | Replay an existing `replays/*.json` | Plays back without errors; HUD status updates as commands stream in. |

**Acceptance:** No regression vs. baseline; HUD on both clients matches
controller/opponent expectation. Defense-token UI sync remains broken
(in-scope for I5/I6).

**MT-PHI.04 result (2026-04-26):** ✅ HUD path approved by user. Squadron
modal lifecycle bug discovered on client side — see known issue below;
to be fixed in I5.

### Known network-UI bugs to be closed by I5/I6

These are **pre-existing gaps** in the parallel `NetworkInteractionState`
channel, not regressions. Each must be a green MT step before its
sub-phase is complete.

| Bug | Repro | Closing step | MT |
|-----|-------|--------------|----|
| **Defender cannot spend defense tokens on client screen** | Networked attack: client is defender; dice roll arrives but no defense-token modal opens. | I6 (project attack UI from `interaction_flow.payload`). | MT-PHI.06 |
| **Client cannot activate Imperial squadrons** | _resolved I5 (2026-04-27)_ — `SqActModal` lifecycle now driven by `command_executed` + `UIProjector`; passive peer mirrors selection / move / handoff. Fix log I5b-1…5 in `docs/modal_timing_diagrams.md`. | I5 ✅ | MT-PHI.05 ✅ |
| **Activation modal sub-step inferred from local UI events** | _resolved I5 (2026-04-27)_ — modal sub-step now read from `state.interaction_flow.step_id`. | I5 ✅ | MT-PHI.05 ✅ |

Acceptance gate: a client disconnected mid-attack must rebuild its UI from
a single filtered `state_snapshot`.

While Phase I is in flight: **no new `NetworkInteractionState` producer
wiring lands in master**. Existing G4.6.6 T1a producers stay until I5/I6.

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
| G4.5 | Lobby System | ✅ | LobbyState, LobbyRoom, password, scenario picker |
| G4.6 | Chat System | ✅ | ChatManager, ChatPanel, lobby chat, rate limiting |
| G4.6.5 | Network Game Wiring | ⏳ | Submitter swap, game init RPC, command result handler, input lockout |
| G4.7 | Spectator Mode | ⏳ | Depends on G4.6.5 |
| G4.8 | Reconnection | ⏳ | Depends on G4.7 |
| G4.9 | Turn Timers | ⏳ | Depends on G4.8 |
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

### MT-G4.5.1 — Main menu Host/Join buttons ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game via `scripts/run_game.sh` | Splash screen appears, menu fades in after 2s |
| 2 | Observe main menu buttons | "Host Game" and "Join Game" buttons visible between "Learning Scenario" and "Quit" |
| 3 | Click "Host Game" | Host dialog appears with "Lobby Name:" input and Host/Cancel buttons |
| 4 | Click "Cancel" | Returns to main menu |
| 5 | Click "Join Game" | Join dialog appears with "Server IP Address:" input and Connect/Cancel buttons |
| 6 | Click "Cancel" | Returns to main menu |

**Pass criteria:** Both dialogs render correctly with UIStyleHelper modal styling (dark panel, blue border, gold title).

### MT-G4.5.2 — Host game creates lobby room ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "Host Game", enter "Test Lobby" as name, click "Host" | Lobby room appears with "Test Lobby" title and 6-char lobby code |
| 2 | Observe player list | P1 row shows host's display name, "Not Ready". P2 row shows "Waiting..." |
| 3 | Click "Ready" | Button text changes to "Not Ready", P1 row shows "✓ Ready" in green |
| 4 | Click "Not Ready" | Button text changes to "Ready", P1 row shows "Not Ready" |
| 5 | Click "Leave" | Returns to main menu |

**Pass criteria:** Lobby room displays correctly, ready toggle works, leave returns to menu.

### MT-G4.5.3 — Headless GUT validation ✅ passed 2026-04-19

### Phase G4.5/G4.6 — Network Features (localhost)

> **Setup:** Use `./scripts/run_network_test.sh` to launch test sessions.
> All tests below use localhost (127.0.0.1).

### MT-G4.5.4 — Password-protected lobby (host dialog) ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game, click "Host Game" | Host dialog shows "Lobby Name:" input AND "Password (optional):" input |
| 2 | Verify password field is secret | Characters are masked (dots/bullets), not visible |
| 3 | Enter a lobby name, leave password blank, click "Host" | Lobby room appears, no "🔒" lock indicator in header |
| 4 | Leave lobby, click "Host Game" again | Both fields are cleared |
| 5 | Enter a lobby name AND a password, click "Host" | Lobby room appears WITH "🔒 Password-protected" indicator |

**Pass criteria:** Password field is secret, optional, and lobby correctly shows lock status.

### MT-G4.5.5 — Password-protected lobby (join flow) ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `./scripts/run_network_test.sh --gui-host` | Two game instances launch |
| 2 | Instance 1: Host with password "secret" | Lobby room shows with 🔒 indicator |
| 3 | Instance 2: Click "Join Game" | Join dialog shows IP field AND "Password (if required):" field |
| 4 | Instance 2: Enter 127.0.0.1, leave password blank, click "Connect" | Toast: "Join failed: Incorrect lobby password." — returns to menu |
| 5 | Instance 2: Click "Join Game" again, enter 127.0.0.1 + correct password "secret" | Lobby room appears, P2 slot shows Instance 2's name |

**Pass criteria:** Wrong password is rejected; correct password allows join.

### MT-G4.5.6 — Scenario picker (host only) ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `./scripts/run_network_test.sh --gui-host` | Two instances launch |
| 2 | Instance 1: Host a game (no password) | Lobby room shows scenario dropdown set to "Learning Scenario" |
| 3 | Instance 1: Verify dropdown is enabled | Host can interact with the dropdown |
| 4 | Instance 2: Join the game via 127.0.0.1 | Lobby room shows scenario dropdown |
| 5 | Instance 2: Try to change scenario | Dropdown is disabled (greyed out) — only host can change |

**Pass criteria:** Scenario dropdown is host-only; clients see it but cannot interact.

### MT-G4.5.7 — Two-player lobby ready flow ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `./scripts/run_network_test.sh --gui-host` | Two instances launch |
| 2 | Instance 1: Host a game | Lobby room: P1 = host name, P2 = "Waiting..." |
| 3 | Instance 2: Join via 127.0.0.1 | Both instances: P1 = host, P2 = joiner |
| 4 | Instance 1: Click "Ready" | Both instances: P1 row shows "✓ Ready" in green |
| 5 | Instance 2: Click "Ready" | Both instances: both rows show "✓ Ready", status = "All players ready!" |
| 6 | Instance 1: Verify "Start Game" button | Button is enabled (was disabled before both ready) |
| 7 | Instance 1: Click "Start Game" | Both instances transition to game board |

**Pass criteria:** Ready state syncs between instances; game starts only when both ready.

### MT-G4.5.8 — Lobby leave and disconnect ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set up a two-player lobby (steps from MT-G4.5.7, 1–3) | Both in lobby |
| 2 | Instance 2: Click "Leave" | Instance 2 returns to main menu |
| 3 | Instance 1: Observe lobby | P2 slot reverts to "Waiting..." |
| 4 | Instance 2: Re-join via "Join Game" → 127.0.0.1 | P2 slot shows joiner name again |
| 5 | Instance 2: Close the window (force disconnect) | Instance 1: P2 slot reverts to "Waiting..." |

**Pass criteria:** Leave and disconnect both correctly update the host's lobby state.

### MT-G4.6.1 — Chat in lobby ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set up a two-player lobby (steps from MT-G4.5.7, 1–3) | Both in lobby |
| 2 | Instance 1: Find the chat area at the bottom of the lobby panel | Chat area visible with "Chat" header, text input, and "Send" button |
| 3 | Instance 1: Type "Hello" and press Enter | Message appears: "[Host Name]: Hello" in the chat area |
| 4 | Instance 2: Observe chat area | Same message "[Host Name]: Hello" appears |
| 5 | Instance 2: Type "Hi back!" and press Enter | Both instances show "[Joiner Name]: Hi back!" |
| 6 | Instance 1: Observe message colours | Own messages in blue tint, other player messages in light grey |

**Pass criteria:** Chat messages sync bidirectionally; own messages are visually distinct.

### MT-G4.6.2 — Chat rate limiting ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set up a two-player lobby | Both in lobby |
| 2 | Instance 2: Send 5 messages rapidly (type + Enter quickly) | All 5 messages appear in both instances |
| 3 | Instance 2: Send a 6th message immediately | Rate limit warning appears in Instance 2's chat: "Rate limited — wait Xs" |
| 4 | Wait 10 seconds, then send another message | Message goes through successfully |

**Pass criteria:** Server enforces 5 messages per 10-second window.

### MT-G4.6.3 — Chat message sanitization ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set up a lobby with chat | Both in lobby |
| 2 | Send a very long message (200+ characters) | Message is truncated to 200 characters |
| 3 | Send a message with leading/trailing whitespace | Message appears without extra whitespace |
| 4 | Send an empty message (just spaces) | Nothing happens — no message sent |

**Pass criteria:** Messages are sanitized before display.

### MT-G4.6.4 — Headless GUT validation (G4.6) ✅ passed 2026-04-19

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 124 scripts, 2586 tests, 0 failures |

**Pass criteria:** Full test suite passes including 22 ChatManager tests.

### Phase G4.6.5 — Network Game Wiring

### MT-G4.6.5.1 — Network game starts with synced state

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `./scripts/run_network_test.sh --gui-host` | Two instances launch |
| 2 | Instance 1: Host a game (no password) | Lobby room appears |
| 3 | Instance 2: Join via 127.0.0.1 | Both instances show two players |
| 4 | Both instances: Click "Ready" | Both rows show "✓ Ready" |
| 5 | Instance 1: Click "Start Game" | Both instances transition to game board |
| 6 | Observe both game boards | Identical ship and squadron placement on both instances |
| 7 | Observe phase | Command Phase begins on both instances |

**Pass criteria:** Both instances show the same game board with identical token positions. Shared RNG seed produces identical initial GameState.

### MT-G4.6.5.2 — Command Phase dial assignment over network

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a network game (steps from MT-G4.6.5.1, 1–5) | Both in Command Phase |
| 2 | Instance 1 (Player 0 / Rebels): Assign dials to all Rebel ships | Dials assigned locally |
| 3 | Instance 2 (Player 1 / Imperials): Assign dials to all Imperial ships | Dials assigned locally |
| 4 | After both players submit all dials | Dials are revealed simultaneously on both instances |
| 5 | Observe phase | Phase advances to Ship Phase on both instances |

**Pass criteria:** Command Phase sync gate holds dials until both players submit, then releases and advances.

### MT-G4.6.5.3 — Ship Phase activation over network

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete Command Phase (steps from MT-G4.6.5.2) | Ship Phase on both instances |
| 2 | Initiative player: Drag dial to activate a ship | Ship activates, opponent sees activation |
| 3 | Initiative player: Execute maneuver, end activation | Ship moves on both instances |
| 4 | Second player: Activate their ship | Ship activates on both instances |

**Pass criteria:** Ship activations round-trip through the server and appear on both clients.

### MT-G4.6.5.4 — Hot-seat regression

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game normally (single instance, no network) | Main menu appears |
| 2 | Click "Learning Scenario" | Game board appears with handoff overlay |
| 3 | Dismiss overlay, assign dials for Player 0 | Handoff overlay for Player 1 appears |
| 4 | Dismiss overlay, assign dials for Player 1 | Phase advances to Ship Phase |
| 5 | Play through Ship and Squadron phases | All phases work identically to pre-G4.6.5 |

**Pass criteria:** Hot-seat mode is completely unaffected by the network wiring changes.

### MT-G4.6.5.5 — Headless GUT validation (G4.6.5)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 124 scripts, 2587 tests, 0 failures |

**Pass criteria:** Full test suite passes with identical counts to pre-G4.6.5 baseline (124 scripts, 2587 tests, 4761 asserts).

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
| MT-G4.5.01 | Lobby system: main menu shows Host/Join buttons, host creates lobby room | ✅ passed 2026-04-19 |
| MT-G4.5.02 | Lobby system: headless GUT 124/2587 | ✅ passed 2026-04-19 |
| MT-G4.5.04 | Password-protected lobby (host dialog) | ✅ passed 2026-04-19 |
| MT-G4.5.05 | Password-protected lobby (join flow — requires 2 instances) | ✅ passed 2026-04-19 |
| MT-G4.5.06 | Scenario picker (host only — requires 2 instances) | ✅ passed 2026-04-19 |
| MT-G4.5.07 | Two-player lobby ready flow (requires 2 instances) | ✅ passed 2026-04-19 |
| MT-G4.5.08 | Lobby leave and disconnect (requires 2 instances) | ✅ passed 2026-04-19 |
| MT-G4.6.01 | Chat in lobby — bidirectional sync (requires 2 instances) | ✅ passed 2026-04-19 |
| MT-G4.6.02 | Chat rate limiting (requires 2 instances) | ✅ passed 2026-04-19 |
| MT-G4.6.03 | Chat message sanitization | ✅ passed 2026-04-19 |
| MT-G4.6.04 | Headless GUT 124/2587 | ✅ passed 2026-04-19 |
| MT-G4.6.5.01 | Network game starts with synced state (requires 2 instances) |
| MT-G4.6.5.02 | Command Phase dial assignment over network (requires 2 instances) |
| MT-G4.6.5.03 | Ship Phase activation over network (requires 2 instances) |
| MT-G4.6.5.04 | Hot-seat regression (single instance) |
| MT-G4.6.5.05 | Headless GUT 124/2587 |
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

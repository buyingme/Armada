# Progress Summary

> Star Wars: Armada — Digital Edition
> Last updated: 2026-04-27 (Phase I5 complete — sidebar / activation modal / squadron modal projected from `interaction_flow`)
> Archived originals: `docs/old/implementation_plan.md`, `docs/old/refactoring_plan.md`, `docs/old/test_plan_manual.md`

---

## Current Baseline

| Metric | Value |
|--------|-------|
| GUT test scripts | 132 |
| GUT tests | 2 726 |
| GUT asserts | 5 066 |
| Autoloads | 17 |
| Command classes | 27 (1 base + 26 concrete) |
| Wired command call sites | 41 |
| Core RefCounted classes | 8 |

---

## Implementation Phases

| Phase | Name | Status | Key Deliverables |
|-------|------|--------|-----------------|
| 0 | Scale & Assets Foundation | ✅ | Pixel-to-game-unit scale, asset loading, Constants autoload |
| 1 | Core Geometry Engine | ✅ | Positions, firing arcs, range bands, collisions, maneuver calculator |
| 2 | Game Board & Token Display | ✅ | Visual board, ship/squadron tokens, camera pan/zoom, scenario placement |
| 2b | Debug Token Placement | ✅ | Drag/rotate tokens, deployment zones, collision resolution, position save |
| 2c | Relaxed Deployment Zones | ✅ | Advisory-only zones in debug mode with toast warnings |
| 3 | Game State Wiring | ✅ | GameState/PlayerState ↔ visual tokens, ship card panels, defense tokens |
| 4 | Command Phase | ✅ | Dial selection, dial stack, tokens, picker modal, order modal |
| 4b | Turn Management | ✅ | Active player tracking, camera rotation, card panel swap, handoff overlay |
| L | Game Logging | ✅ | File-based logging via `--logging` CLI flag |
| 4c | Ship Activation | ✅ | Drag dial → ship token, reveal/spend dial flow |
| 4d | Keep-or-Convert Choice | ✅ | Drag to ship = keep, drag to card = convert to token |
| 4e | Token Overflow Discard | ✅ | Overflow prompt, duplicate auto-discard |
| 4f | Hover Tooltips | ✅ | Reusable tooltip system, global toggle |
| 4g | Fixed Round-1 Commands | ✅ | Pre-assigned dials from scenario JSON, skip command phase round 1 |
| 5a | Maneuver Tool | ✅ | Interactive maneuver tool, action toolbar (M/R/T/A) |
| 5a+ | Dynamic Alignment | ✅ | Auto-side alignment, speed +/− preview buttons |
| 5b | Ship Movement | ✅ | 5-step activation modal, Navigate command, ship snap placement |
| 5b-2 | Overlap Handling | ✅ | Ship–ship and ship–squadron overlap, displacement modal |
| 5c | Range Overlay | ✅ | "R" button with per-arc range band PNG overlays |
| 5d | Targeting List | ✅ | "T" modal listing all valid targets/threats with LOS/obstruction |
| 5e | Keyboard Shortcuts | ✅ | M/R/T keys for toolbar buttons |
| 6a–6c | Attack Resolution | ✅ | Full attack pipeline: declaration, dice, CF, defense tokens, damage, destruction |
| 7 | Squadron Phase | ✅ | Effect/Hook pipeline, engagement, movement, keywords, alternating activation |
| 7b | Squadron Activation UI | ✅ | Modal with move overlay, attack integration, activated dimming |
| 8 | Status Phase & Game Flow | ✅ | Scoring, elimination, victory screen, HUD, status phase cleanup |
| 9 | Repair & Damage Cards | ✅ | 52 damage cards, repair resolver, immediate + persistent effects, repair panel |
| 9.5 | Squadron Command | ✅ | SquadronCommandResolver, dual-mode modal |
| 9.6 | Damage Card Hooks | ✅ | All 14/14 hooks wired, all 22/22 cards working |
| 9.7 | Debug Faceup Damage | ✅ | Shift+D to deal any faceup damage card |
| 10a | Immediate Damage Fixes | ✅ | Shield Failure/Injured Crew/Comm Noise fixes, OpponentChoiceModal |
| 10b | UI Polish | ✅ | Card detail overlay, activation sidebar, movement preview |
| 11 | Splash & Main Menu | ✅ | Splash background, menu modal, Learning Scenario launch |
| 12 | Sound & Music | ✅ | SFX for all interactions, dynamic music, 12-track playlist |

---

## Refactoring Phases

| Phase | Name | Status | Key Outcome |
|-------|------|--------|-------------|
| A | Function Extraction | ✅ | Split all 95 functions >30 lines → 0 violations |
| B | Narrow Interfaces | ✅ | Callable injection, `#region` grouping, shared-var contracts |
| C | Controller Extraction | ✅ | 7 controllers from game_board (3 390 → 2 799 LOC) |
| D | UI Builder Cleanup | ✅ | Section builder pattern, UIStyleHelper, ShipCardPanel split (1 438 → 877) |
| E | Serialization | ✅ | serialize()/deserialize() on all 11 core classes, SaveGameManager |
| F | Backbone Extraction | ✅ | ActivationContext, UIPanelManager, 6 attack sub-resolvers |
| F5 | AttackExecutor Split | ✅ | AttackState, TargetSelector, TargetingListController (AE 3 008 → 1 883) |
| H | Geometry Centralisation | ✅ | 6 inline approximations → centralised, −195 lines dead code |
| G | Command Pattern | ✅ | GameCommand base, 26 concrete commands, 41 wired call sites, GameReplay, §4.6 P1–P7 + debug resolved |
| **I** | **Interaction-Flow as Domain State** | **🔄 in progress** | `InteractionFlow` field on `GameState`; `AttackFlowFSM` extracted; `UIProjector` replaces `is_network()` branches; deletes legacy interaction-state RPC. Plan: `docs/refactoring_phase_i_plan.md`. ~14 days, 7 sub-steps. **I0 ✅** inventory + freeze lint. **I1 ✅** `InteractionFlow` type + `GameState.interaction_flow` + `StateFilter` rule (2 666 tests). **I2 ✅** mirrored flow into 7 commands (advance_phase, activate_ship, convert_dial_to_token, execute_maneuver, end_activation, activate_squadron, advance_activation_step) + invariant test (2 677 tests, MT-PHI.01 passed 2026-04-26). **I3 ✅** `AttackFlowFSM` + interaction_flow.payload publishing at 5 transition sites (range_band, dice_pool, dice_results, locked_tokens, modified_damage, defender_player, final_damage, chooser, card_title); +39 unit tests; LOC target for `attack_executor.gd` deferred (no game logic moved — moving combat mid-Phase-I is higher-risk than acceptable; data is exposed for I4/I6). **I4 ✅** `UIProjector` HUD pilot — `src/core/network/ui_projector.gd` + `UIIntent`; wired to `CommandProcessor.command_executed` in `game_board.gd`; +10 unit tests; MT-PHI.04 passed 2026-04-26. **I5 ✅** sidebar / activation modal / squadron modal projected from `interaction_flow` via `UIProjector`; passive-peer modal lifecycle (open/select/move/handoff) mirrored on remote clients; round-2+ Command Phase opens dial picker on client; speculative round-1 picker closed on `command_phase_complete` (no out-of-phase `assign_dials`). Fix log I5b-1…5: see `docs/modal_timing_diagrams.md`. 132 scripts / 2 726 tests / 5 066 asserts; MT-PHI.05/05b passed 2026-04-27. Unblocks NW-006/007/008 cross-client UI parity. |

---

## Phase G — Command Pattern Detail

| Sub-Phase | Status | What |
|-----------|--------|------|
| G5: Deterministic RNG | ✅ | `GameRng` class, seeded Dice + DamageDeck |
| G1+G3: GameCommand + CommandProcessor | ✅ | Base class with registry, autoload with submit/history/replay pipeline |
| G2 Tier 1: 6 commands + wiring | ✅ | AssignDial, ActivateShip, EndActivation, ConvertDialToToken, ActivateSquadron, SpendToken |
| G2 Tier 2: 4 attack commands | ✅ | RollDice, SpendDefenseToken, SelectRedirectZone, SkipAttack — wired into AE |
| G2 Tier 3: 2 movement commands | ✅ | MoveSquadron, ExecuteManeuver — wired into presentation |
| G2 Wiring: SpendToken + SpendDial | ✅ | Return-value protocol: 7 token + 5 dial call sites wired |
| G6: GameReplay | ✅ | Record/playback, v1 file format, Shift+R save, auto-save on exit |
| §4.6 P5: Immediate Effects | ✅ | ResolveImmediateEffectCommand — 8 violations → 1 cmd, 4 call sites |
| §4.6 P6: Overlap/Speed/Persistent | ✅ | SetSpeedCommand + OverlapDamageCommand + PersistentEffectDamageCommand — 3 violations → 3 cmds |
| §4.6 P7: UI State & Tokens | ✅ | DiscardTokenCommand + RevealDialCommand — 3 violations → 2 cmds |
| §4.6 Debug: Faceup Damage | ✅ | DebugDealDamageCommand — 1 debug violation → 1 cmd |
| G4: Network Transport | 🔄 | Godot MultiplayerPeer — all §4.6 violations resolved |
| G4.0: Directory Reorganisation | ✅ | 59 files reorganised into domain sub-folders, zero breakage |
| G4.10: Dedicated Server Binary | ✅ | ServerMain autoload, export preset, HMAC replay signing, CI workflow |
| G4.1: Network Transport Foundation | ✅ | PlayerProfile, NetworkManager autoloads, ENet host/connect/disconnect, state machine, heartbeat, TestNetworkHarness |
| G4.2: Server-Side Command Processing | ✅ | CommandSubmitter strategy (Local/Network), GameManager wiring (31 sites), server-side RPCs, is_replaying flag |
| G4.3: Information Hiding | ✅ | StateFilter utility, dial/damage/RNG filtering, 25 unit tests with secret canary |
| G4.4: Command Phase Sync Gate | ✅ | CommandSyncGate, NetworkManager hold-and-release for dial assignments, 21 unit tests |
| G4.5: Lobby System | ✅ | LobbyState, LobbyManager autoload, LobbyRoom UI, main menu Host/Join buttons, lobby code generation, password-protected lobbies, scenario picker, 38 unit tests |
| G4.6: Chat System | ✅ | ChatManager autoload (history, RPCs, rate limiting), ChatPanel UI (scrollable, send, unread indicator, T-key toggle), lobby chat integration, 22 unit tests |
| G4.6.5: Network Game Wiring | ⏳ | Submitter swap, game init RPC, command result handler, GameBoard network mode, input lockout, state snapshot |
| G4.6.6 T1a C1: NetworkInteractionState | ✅ | `src/core/network/network_interaction_state.gd` — domain object with serialize/deserialize/is_newer_than/same_version; 25 unit tests |
| G4.6.6 T1a C2: Interaction state RPC | ✅ | `NetworkManager`: signal `interaction_state_received`, field `_latest_interaction_state`, `broadcast_interaction_state()`, `get_latest_interaction_state()`, `_receive_interaction_state` RPC with idempotency guard |
| G4.6.6 T1a C3: Ordered apply path | ✅ | `GameManager`: fields `_last_interaction_version`, `_pending_interaction_by_version`; `_on_interaction_state_received()`, `_apply_interaction_state_if_ready()`, `_flush_pending_interaction_states()`; `EventBus.interaction_state_changed` signal; 13 unit tests |
| G4.6.6 T1a C4: Command-seq consistency | ✅ | `GameManager`: field `_last_applied_command_seq`; tracked per command_result; flush called after every apply; `payload["requires_seq"]` gate; reset on new game |
| G4.6.6 T1a C5: Score-header status text | ✅ | `UIPanelManager.set_network_status_text()` + HUD suffix in network mode; `GameBoard` consumes `EventBus.interaction_state_changed` and also applies active-player fallback in `_handle_network_active_player()` so status text is visible before full interaction-state broadcast rollout; 2 unit tests |
| G4.6.6 T1a C6: Sidebar authoritative projection | 🔄 | `ActivationSidebar` now refreshes from `GameManager.current_game_state`, unit count changes trigger rebuild, active highlight syncs from `GameManager.get_activating_ship()/get_activating_squadron()`, and refresh is driven by phase/round/active-player/interaction-state + command-side-effect signals; 3 unit tests added |
| G4.6.6 T1a C7: Activation modal permission gates | ✅ | `ActivationModal.set_interactable()` added with control disable + handler guards for passive peers; `GameBoard` now applies controller-aware modal interactivity on interaction-state updates and all modal open/reopen paths via centralized `_configure_and_open_activation_modal()`; 3 unit tests added |
| G4.6.6 T1a C8: Squadron modal permission gates | ✅ | `SquadronActivationModal.set_interactable()` added with UI disable + handler guards for passive peers and click/input lockout; `SquadronPhaseController.set_modal_interactable()` applies gate at create/open; `GameBoard` authority helper now drives both activation and squadron modal interactivity from interaction controller ownership; 3 unit tests added |

### C5 Bug-Fix Learnings

- HUD status visibility must be driven by explicit UI state (`_network_status_text`) rather than `PlayMode` timing, because scene-transition order can temporarily lag mode updates.
- Interaction-state broadcasting still has no producer call sites; C5 therefore keeps an active-player fallback path to ensure the UX contract remains visible until C6+ wiring is complete.

---

## Architecture Hooks

| Hook | Phase | Status |
|------|-------|--------|
| AttackPipeline as callable | 6 | ✅ (Salvo/Counter-ready) |
| Effect timing in attack steps | 6 | ✅ |
| Effect timing in movement | 5b | ✅ |
| Geometry primitives | 1 | ✅ |
| State serialization | 3 + E | ✅ |
| GameCommand + CommandProcessor | G | ✅ 26 cmds, 41 sites |
| Deterministic RNG | G5 | ✅ |
| GameReplay | G6 | ✅ v1 format |
| Configurable hull zones | 1 | ✅ (Huge ships ready) |
| Pluggable keyword system | 7 | ✅ EffectRegistry |
| Damage card effect pattern | 9 | ✅ 14/14 hooks |

---

## Requirements Coverage

| Section | Count | Status |
|---------|-------|--------|
| Game Overview (GO) | 6 | ✅ |
| Setup (SU) | 18 | ✅ |
| Game Flow (GF) | 4 | ✅ |
| Command Phase (CP) | 8 | ✅ |
| Ship Phase (SP) | 16 | ✅ |
| Squadron Phase (SQ) | 9 | ✅ |
| Status Phase (ST) | 4 | ✅ |
| Play Mode (PM) | 4 | ✅ |
| Turn Flow (TF) | 14 | ✅ |
| Board Perspective (BP) | 6 | ✅ |
| Player Handoff (HO) | 5 | ✅ |
| Initiative (IN) | 3 | ✅ |
| Commands (CM) | 22 | ✅ |
| Attack Resolution (AT) | 28 | ✅ |
| Defense Tokens (DT) | 10 | ✅ |
| Damage (DM) | 12 | ✅ |
| Ship Movement (MV) | 13 | ✅ |
| Squadron Mechanics (SM) | 18 | ✅ |
| Overlapping (OV) | 8 | ✅ |
| Winning/Scoring (WN) | 4 | ✅ |
| Game Components (GC) | 18 | ✅ |
| UI Requirements (UI) | 34 | ✅ |
| Sound Effects (SFX) | 10 | ✅ |
| Music (MUS) | 14 | ✅ |
| Network (NW) | 8 | ⏳ deferred |
| Debug Mode (DBG) | 13 | ✅ |
| Game Logging (LOG) | 18 | ✅ |
| Hover Tooltip (TT) | 31 | ✅ |

---

## Manual Tests Passed

39 tests formally passed with date stamps (out of ~237 total written).

| ID | Description | Date |
|----|-------------|------|
| MT-H.01–03 | Geometry centralisation (squadron range, engagement, targeting) | 2026-04-11 |
| MT-F5b.01–03 | Ship attack, squadron attack, attack simulator | 2026-04-11 |
| MT-F5c.01–02 | Targeting list toggle, ghost ship in list | 2026-04-11 |
| MT-F5d.01–03 | TargetSelector (simulator + ship + squadron attacks) | 2026-04-12 |
| MT-G.01–08 | Full game regression, token convert, squadron, RNG, wiring (4 tests) | 2026-04-12 |
| MT-G.09–10 | CommandProcessor reset, replay file save | 2026-04-12 |
| MT-G.13–15 | Command registration (13 types), repair token spend, squadron dial spend | 2026-04-12 |
| MT-HF.01–02 | Pre-roll deselection, post-roll click block | 2026-04-12 |
| MT-P4.01–05 | Repair panel: move shields, recover shields, repair hull, replay save | 2026-04-14 |
| MT-P5.01–07 | Immediate effects: all 6 card effects through commands, replay save | 2026-04-14 |
| MT-P6.01–08 | Overlap, speed, persistent: SetSpeed, OverlapDamage, PersistentEffectDamage, card panel refresh, destruction, deferred Thruster Fissure | 2026-04-15 |
| MT-P7.01–03 | Discard token (overflow), reveal/unreveal dial, replay save after P7 ops | 2026-04-18 |
| MT-G4.10.01–04 | Dedicated server: autoload, --server flag, HMAC, headless GUT | 2026-04-18 |
| MT-G4.1.01–02 | Network transport: normal game unaffected, headless GUT 119/2460 | 2026-04-18 |
| MT-G4.2.01–02 | Server-side command processing: normal game, headless GUT 120/2480 | 2026-04-18 |
| MT-G4.3.01–02 | Information hiding: normal game, headless GUT 121/2505 | 2026-04-18 |
| MT-G4.4.01–02 | Sync gate: normal game, headless GUT 122/2526 | 2026-04-19 |

Phase 3 (9 tests) also passed but without formal date stamps.

---

## Key Commits (Phase G)

| Commit | Description |
|--------|-------------|
| `621b8b2` | G5: Deterministic RNG |
| `9d52bce` | G1+G3: GameCommand + CommandProcessor |
| `158fa91` | G2 T1: 6 concrete commands |
| `5575840` | G2 T2+T3: Movement + attack commands, positional data |
| `b7f37f7` | SpendTokenCommand wiring (7 call sites) |
| `515413e` | SpendDialCommand creation + wiring (5 call sites) |
| `8b720e7` | Docs: §4.6 violation roadmap + manual test plan |
| `d0fde4f` | Docs: consolidate into progress_summary + open_topics |
| `dab13cf` | Bug fix: allow attack commands in Squadron Phase |
| `150e3f5` | P3: ResolveDamageCommand (7 violations → 1 command) |
| `1da7df8` | Auto-save replay on game exit/game over |
| `edd98b5` | P4: RepairActionCommand (3 violations → 1 command) |
| `fe87813` | P5: ResolveImmediateEffectCommand (8 violations → 1 command) |\n| `69511d4` | P6: SetSpeedCommand + OverlapDamageCommand + PersistentEffectDamageCommand (3 violations → 3 commands) |
| `f8012ed` | P7: DiscardTokenCommand + RevealDialCommand (3 violations → 2 commands) |
| `91abf9e` | Debug: DebugDealDamageCommand + arc42 docs update |
| — | G4.10: Dedicated Server Binary |
| — | G4.1: Network Transport Foundation |
| — | G4.2: Server-Side Command Processing |

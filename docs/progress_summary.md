# Progress Summary

> Star Wars: Armada — Digital Edition
> Last updated: 2026-04-15
> Archived originals: `docs/old/implementation_plan.md`, `docs/old/refactoring_plan.md`, `docs/old/test_plan_manual.md`

---

## Current Baseline

| Metric | Value |
|--------|-------|
| GUT test scripts | 113 |
| GUT tests | 2 338 |
| GUT asserts | 4 204 |
| Autoloads | 12 |
| Command classes | 24 (1 base + 23 concrete) |
| Wired command call sites | 37 |
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
| G | Command Pattern | 🔄 | GameCommand base, 23 concrete commands, 37 wired call sites, GameReplay, §4.6 P1–P6 resolved |

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
| G4: Network Transport | ⏳ | Godot MultiplayerPeer — depends on §4.6 violations resolved |

---

## Architecture Hooks

| Hook | Phase | Status |
|------|-------|--------|
| AttackPipeline as callable | 6 | ✅ (Salvo/Counter-ready) |
| Effect timing in attack steps | 6 | ✅ |
| Effect timing in movement | 5b | ✅ |
| Geometry primitives | 1 | ✅ |
| State serialization | 3 + E | ✅ |
| GameCommand + CommandProcessor | G | ✅ 23 cmds, 37 sites |
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

26 tests formally passed with date stamps (out of ~233 total written).
All passing tests are from 2026-04-11 or 2026-04-12.

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
| `fe87813` | P5: ResolveImmediateEffectCommand (8 violations → 1 command) |

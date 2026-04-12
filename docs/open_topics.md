# Open Topics

> Star Wars: Armada — Digital Edition
> Last updated: 2026-04-13
> Current baseline: 108 scripts, 2 216 tests, 3 962 asserts

---

## 1. §4.6 Violations — Mutations Outside GameCommand.execute()

34 violations found across 8 files. Every mutation of `GameState`-owned data
must route through a `GameCommand.execute()` for replay/multiplayer safety.
P1–P4 block multiplayer; P5–P7 are deferrable.

### Priority 1 — Game Flow (3 violations → 2 commands) ✅ RESOLVED

Both commands implemented and wired:

| Command | Wired In |
|---------|----------|
| `AdvancePhaseCommand` | `game_manager.gd` — `advance_phase()` |
| `StartRoundCommand` | `game_manager.gd` — `_start_round()` |

Tests: `test_game_flow_commands.gd` — validate, execute, serialize/deserialize for both.

### Priority 2 — Status Phase Cleanup (5 violations → 2 commands)

| File | Method | Mutation | Command |
|------|--------|----------|---------|
| `game_manager.gd` | `_perform_status_phase_cleanup()` | ready tokens, reset activation, clear spent history (ships + squadrons) | `StatusPhaseCleanupCommand` |
| `game_manager.gd` | `_on_ship_destroyed()` | `clear_all_damage_cards()` | `DestroyUnitCommand` |

### Priority 3 — Attack Damage (7 violations → 2 commands)

| File | Method | Mutation | Command |
|------|--------|----------|---------|
| `attack_executor.gd` | `_apply_single_redirect()` | `reduce_shields(zone, 1)` | `ResolveDamageCommand` |
| `attack_executor.gd` | `_absorb_shields()` | `reduce_shields(zone, n)` | `ResolveDamageCommand` |
| `attack_executor.gd` | `_deal_damage_cards()` | `add_facedown_damage()` | `ResolveDamageCommand` |
| `attack_executor.gd` | `_deal_single_faceup_card()` | `add_faceup_damage()` | `ResolveDamageCommand` |
| `attack_executor.gd` | `_resolve_squadron_damage()` | `suffer_damage()`, `mark_destroyed()` | `ResolveDamageCommand` / `DestroyUnitCommand` |
| `attack_executor.gd` | `_resolve_ship_damage()` | `mark_destroyed()` | `DestroyUnitCommand` |

> Consolidation: single `ResolveDamageCommand` with full damage allocation + destruction flag.

### Priority 4 — Repair Actions (3 violations → 1 command)

| File | Method | Mutation | Command |
|------|--------|----------|---------|
| `repair_resolver.gd` | `move_shields()` | `reduce_shields()` + `restore_shields()` | `RepairActionCommand` |
| `repair_resolver.gd` | `recover_shields()` | `restore_shields(zone, 1)` | `RepairActionCommand` |
| `repair_resolver.gd` | `repair_hull()` | `remove_damage_card()` | `RepairActionCommand` |

### Priority 5 — Immediate Effects (8 violations → 1 command)

| File | Method | Mutation | Command |
|------|--------|----------|---------|
| `immediate_effect_resolver.gd` | 8 methods | shields, tokens, speed, dials, facedown damage, faceup→facedown flip | `ResolveImmediateEffectCommand` |

> Single command parameterised by `effect_id` + player-choice dictionary.

### Priority 6 — Overlap, Speed, Persistent Effects (3 violations → 3 commands)

| File | Mutation | Command |
|------|----------|---------|
| `game_board.gd` | overlap facedown + destruction | `OverlapDamageCommand` |
| `ship_activation_state.gd` | `set_speed(new_speed)` | `SetSpeedCommand` |
| `damage_card_effect.gd` | persistent effect facedown damage | `PersistentEffectDamageCommand` |

### Priority 7 — UI State & Tokens (3 violations → 2 commands)

| File | Mutation | Command |
|------|----------|---------|
| `ship_card_panel.gd` | token overflow discard | `DiscardTokenCommand` |
| `ship_card_panel.gd` | `reveal_top()` / `unreveal_top()` | `RevealDialCommand` |

### Debug-only (1 violation, not prioritised)

`game_board.gd` → `_apply_debug_damage_card()` → `DebugDealDamageCommand`

### Summary

| Priority | Violations | New Commands | Blocks Multiplayer |
|----------|-----------|-------------|-------------------|
| P1 | 3 | 2 | ✅ Done |
| P2 | 5 | 2 | Yes |
| P3 | 7 | 2 | Yes |
| P4 | 3 | 1 | Yes |
| P5 | 8 | 1 | No |
| P6 | 3 | 3 | No |
| P7 | 3 | 2 | No |
| **Total** | **34** | **~13** | P1–P4 = 18 blocking |

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
| G4 | Network Transport Layer | ⏳ | §4.6 P1–P4 violations must be resolved first |
| 10c | Network Foundation | ⏳ | Depends on G4 |

All other implementation phases (0–12) are complete.

---

## 3.5 Known Visual Bugs

| Bug | Severity | Observed | Notes |
|-----|----------|----------|-------|
| Activated squadron loses ghosted appearance after ship-overlap displacement | Minor (visual only) | 2026-04-12 | When an activated squadron is displaced due to collision with a capital ship (e.g. VSD manoeuvring into it), the ghosted/dimmed activated visual state is lost. Game logic is correct — the squadron cannot be re-activated. |

---

## 4. Open Manual Tests

233 manual test cases were written. 26 formally passed (with date stamps).
~200 remain untested or lack formal result annotations.

### Awaiting First Test (highest priority — recent changes)

| ID | Description |
|----|-------------|
| MT-G.13 | Command registration count is now 13 | ✅ passed 2026-04-12 |
| MT-G.14 | Repair flow: dial + token spend through commands | ✅ passed 2026-04-12 (bug fixed) |
| MT-G.15 | Squadron command flow: dial + token spend through commands | ✅ passed 2026-04-12 |
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

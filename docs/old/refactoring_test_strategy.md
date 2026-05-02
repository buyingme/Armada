# Refactoring Manual Test Strategy

> **Purpose:** Define what needs manual visual/interaction testing after each
> refactoring step. Automated GUT tests verify logic; this document covers
> what GUT cannot: visual layout, animations, click targets, and UX flow.
>
> **Rule:** After every step, run the full GUT suite first. Only proceed to
> manual testing if GUT passes with **87 scripts, 1 645 tests, 1 644 passing**.
> If any count drops, stop and fix parse errors before continuing.
>
> **Status:** Phase A in progress.
> Completed: A1-01 through A1-04, A1-09, A1-11, A2-01 through A2-05, A3-01, A4-03.
> Remaining: A1-05 through A1-08, A1-10, A1-12, A1-13, A4-01, A4-02, A4-04 through A4-07.

---

## Table of Contents

- [Phase A — Shrink Functions](#phase-a--shrink-functions)
  - [A1: UI `_build_ui()` Extraction](#a1-ui-_build_ui-extraction)
  - [A2: AttackExecutor Oversized Functions](#a2-attackexecutor-oversized-functions)
  - [A3: GameBoard Oversized Functions](#a3-gameboard-oversized-functions)
  - [A4: Other Files](#a4-other-files)
- [Phase B — Narrow Interfaces](#phase-b--narrow-interfaces)
- [Phase C — Extract Isolated Clusters](#phase-c--extract-isolated-clusters)
- [Phase D — UI Builder Cleanup](#phase-d--ui-builder-cleanup)
- [Phase E — Serialization & EventBus Cleanup](#phase-e--serialization--eventbus-cleanup)

---

## Phase A — Shrink Functions

### General Phase A Manual Test Protocol

Phase A only extracts private helpers within the same file — no interface
changes. The risk of visual regression is **near zero** but not zero
(accidental reordering of widget construction could shift layout).

**After each A1 sub-step (one UI file):**
1. Launch game: `./scripts/run_game.sh`
2. Verify the specific UI panel opens, displays correctly, and is dismissible.
3. Check that all buttons in the panel are clickable and produce the expected response.
4. Close/dismiss the panel and verify no visual artefacts remain.

### A1: UI `_build_ui()` Extraction

Each sub-step refactors one UI file. Listed in order of implementation.

---

#### A1-01: `attack_sim_panel.gd` — 3 oversized functions (218 + 43 + 36 lines) ✅

**What changes:** `_build_ui()` (218 lines) split into ~12 `_build_<section>()`
helpers. `_clear_content()` (43 lines) and `show_defense_section()` (36 lines)
split into smaller helpers.

**Manual test after GUT passes:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Press A key (Attack Simulator toggle) | Panel appears bottom-left with title "Attack Simulator" |
| 2 | Click a friendly ship | Attacker name + hull zone labels appear in panel |
| 3 | Click an enemy ship | Target info, dice count, LOS line, range band shown |
| 4 | Press A again | Panel dismisses cleanly |
| 5 | During Ship Phase: open Activation Modal → Attack step | Attack execution panel appears with Roll/Skip buttons |
| 6 | Click Roll Dice | Dice results shown, CF token reroll section visible if applicable |
| 7 | Click Confirm → Accuracy section | Lock buttons appear for defender tokens |
| 8 | Click Done → Defense section | Defense token spend buttons appear |
| 9 | Complete attack → Damage resolution | Damage numbers displayed, summary overlay appears |
| 10 | Resize window during any panel state | Panel repositions correctly, no clipping |

---

#### A1-02: `activation_modal.gd` — 3 oversized (90 + 82 + 57 lines) ✅

**What changes:** `_build_ui()` (82 lines) split into section builders.
`_update_step_display()` (90 lines) split per-step. `_create_step_row()`
(57 lines) split into label/button creation helpers.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Activate a ship (drop dial on token) → Show Activation Sequence | Modal appears with 4 step rows (Attack, Squadron, Maneuver, Repair) |
| 2 | Verify step highlighting | Current step highlighted, completed steps show check mark |
| 3 | Click each step button in sequence | Steps advance correctly, buttons enable/disable |
| 4 | Verify "End Activation" button | Appears after all steps, ends activation on click |
| 5 | Press Escape | Modal dismisses, "Show Activation Sequence" button appears |
| 6 | Click "Show Activation Sequence" | Modal re-opens at same state |
| 7 | Resize window with modal open | Modal stays centred |

---

#### A1-03: `squadron_activation_modal.gd` — 4 oversized (82 + 49 + 38 + 31 lines) ✅

**What changes:** `_build_ui()`, `_update_ui()`, `_try_select_squadron()`,
`_update_action_buttons()` each split into helpers.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Reach Squadron Phase | Squadron Activation Modal appears |
| 2 | Select a squadron | Squadron highlights, Move/Attack buttons appear |
| 3 | Click Move → move squadron | Movement overlay visible, position updates |
| 4 | Click Attack → select target | Attack flow starts correctly |
| 5 | Complete squadron activation | "Done" advances to next squadron or ends phase |
| 6 | Dismiss and re-open modal | State preserved |

---

#### A1-04: `ship_card_panel.gd` — 8 oversized functions ✅

**What changes:** `add_ship_entry()` (72), `_populate_damage_cards()` (64),
`_populate_dial_stack()` (50), `_compute_panel_size()` (43),
`_connect_eventbus_signals()` (37), `_handle_dial_stack_click()` (33),
`_create_dial_rect()` (33), `_on_discard_token_click()` (32) — each split
into helpers.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Game starts | Left (Rebel) and right (Imperial) card panels show correct ships |
| 2 | Verify ship entries | Name, hull bar, shield values, defense tokens, dial stack all visible |
| 3 | Click a command dial in the stack | Dial detail or order modal appears |
| 4 | Deal damage to a ship (via attack) | Damage cards appear in the panel correctly |
| 5 | Scroll panel if content overflows | Scrolling works, content not clipped |
| 6 | Token discard prompt | Clicking discard token triggers correct modal |
| 7 | Resize window | Panels reposition to left/right edges |

---

#### A1-05: `damage_summary_overlay.gd` — 1 oversized (86 lines) ✅

**What changes:** `_build_content()` split into header, card list, and
button section builders.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Complete an attack that deals damage | Summary overlay appears showing cards dealt |
| 2 | Verify card display | Face-up cards show name/effect, face-down show back |
| 3 | Click Dismiss | Overlay closes, game continues |

---

#### A1-06: `opponent_choice_modal.gd` — 1 oversized (73 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Deal a face-up damage card that requires opponent choice | Choice modal appears with options |
| 2 | Select an option | Choice confirmed, effect applied |

---

#### A1-07: `victory_screen.gd` — 1 oversized (73 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Complete all 6 rounds / destroy all enemy ships | Victory screen appears |
| 2 | Verify score display | Both players' scores shown correctly |
| 3 | Click "Main Menu" | Returns to main menu |

---

#### A1-08: `command_dial_picker.gd` — 2 oversized (58 + 45 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Enter Command Phase | Dial picker appears for first ship |
| 2 | Verify 4 command options displayed | Navigate, Squadron, Repair, Concentrate Fire |
| 3 | Select a command | Dial highlights, Confirm button active |
| 4 | View existing stack display | Previously assigned dials shown correctly |
| 5 | Confirm | Picker advances to next ship |

---

#### A1-09: `repair_panel.gd` — 1 oversized (55 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | During Repair step in Activation Modal | Repair panel appears |
| 2 | Verify repair options | Shield recovery + damage card options shown |
| 3 | Select repair action | Action applies, panel updates |

---

#### A1-10: `targeting_list_modal.gd` — 4 oversized (52 + 39 + 33 + 33 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Press T key (Targeting List) | Modal appears listing all ships/squadrons |
| 2 | Verify ship section | Ships listed with hull zone range data |
| 3 | Verify squadron section | Squadrons listed with distance data |
| 4 | Dismiss with T or Escape | Modal closes cleanly |

---

#### A1-11: `displacement_modal.gd` — 1 oversized (51 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Move a ship that overlaps squadrons | Displacement modal appears |
| 2 | Verify squadron checklist | Displaced squadrons listed with checkboxes |
| 3 | Select squadron, place it | Squadron moves to valid position |
| 4 | Click Commit | Displacement completes |

---

#### A1-12: `command_dial_order_modal.gd` — 1 oversized (64 lines) ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Click own ship's command dial stack in Ship Card Panel | Read-only order modal appears showing queued (hidden) dials in stack order, leftmost = next to reveal |
| 2 | Verify dial icons and position labels | Each dial shows correct command icon with #1, #2, … label below |
| 3 | Click anywhere on the modal | Modal dismisses cleanly |
| 4 | Click opponent's dial stack | Nothing happens (UI-023: opponent dials hidden) |

> **Rules Reference:** "Command Dials", bullet 5, p. 5 — *"A player can look
> at their ships' facedown command dials at any time. When a player looks at
> a ship's command dials, they must preserve the order in which the command
> dials are stacked."* — No reorder functionality exists.

---

#### A1-13: UI files — `tooltip_panel.gd` (48), `defense_token_display.gd` (40), `quit_confirmation_modal.gd` (38), `debug_help_panel.gd` (36) ✅

**Manual test (one pass for all 4):**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Hover over a token/button | Tooltip appears with correct text |
| 2 | Verify defense token sprites | Tokens display correct state (green/red/exhausted) |
| 3 | Press Escape (no modal open) | Quit confirmation appears |
| 4 | Click Cancel | Quit modal dismisses |
| 5 | Press F1 in debug mode | Debug help panel toggles |

---

### A2: AttackExecutor Oversized Functions ✅

23 oversized functions in `attack_executor.gd`. Implemented in batches
grouped by responsibility. All 21 original + 5 newly-discovered oversized
functions split. 0 functions >30 lines remain.

#### A2-01: Damage resolution — `_resolve_ship_damage()` (115 lines)

**What changes:** Extract `_apply_scatter_cancel()`, `_apply_brace_halve()`,
`_compute_final_damage()`, `_deal_damage_cards()`, `_emit_damage_events()`.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Complete an attack against a ship | Damage applied correctly |
| 2 | Use Scatter token | All damage cancelled |
| 3 | Use Brace token | Damage halved (rounded up) |
| 4 | Deal enough damage for face-up cards | Face-up damage card effect triggers |
| 5 | Destroy a ship | Elimination event fires, token removed |

---

#### A2-02: Attack sim target selection (59 + 59 + 34 lines)

**What changes:** `_attack_sim_handle_target_ship_click()`,
`_attack_sim_handle_target_squadron_click()`,
`_attack_sim_handle_ship_click()` — extract arc validation, range computation,
panel update into helpers.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | In attack sim, click attacker ship | Hull zone visuals appear |
| 2 | Click target ship | LOS line, range band, dice pool shown |
| 3 | Click target squadron | Same for squadron targeting |
| 4 | Click invalid target (out of arc) | No selection, panel shows warning |

---

#### A2-03: LOS computation (60 + 50 + 40 + 42 lines)

**What changes:** `_attack_sim_compute_and_show_los()`,
`_attack_sim_trace_los()`, `_attack_sim_compute_los_endpoints()`,
`_attack_sim_compute_range_endpoints()` — extract geometry math, overlay
setup, obstruction check into helpers.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Select attacker + target | LOS line drawn between correct points |
| 2 | Verify range line colour | Matches range band (close/medium/long) |
| 3 | Verify obstruction detection | Line changes when obstructed |

---

#### A2-04: Attack execution flow (51 + 50 + 46 + 43 + 39 + 34 + 33 lines)

**What changes:** `_attack_exec_begin_sequence()`, `start_ship_attack()`,
`start_squadron_attack()`, `_connect_attack_panel_signals()`,
`_attack_exec_start_accuracy()`, `_attack_exec_start_defense()`,
`_attack_exec_prepare_next_attack()` — extract state setup, panel wiring,
pool computation.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Full ship attack sequence | All phases flow correctly |
| 2 | Two hull-zone attack | Second attack available after first |
| 3 | Anti-squadron multi-target | Can target multiple squadrons |
| 4 | Skip attack | Phase advances without attacking |

---

#### A2-05: Defense tokens & redirect (54 + 42 + 40 + 35 + 46 + 43 + 31 lines)

**What changes:** `_on_attack_redirect_zone_selected()`,
`_on_evade_die_selected()`, `_on_attack_defense_token_spent()`,
`_apply_defense_token_effect()`, `_attack_exec_zone_has_targets()`,
`_attack_exec_finalize_attack()`, `_reset_exec_state()`, `_attack_sim_show_hull_zone_visuals()` — extract
validation steps, damage adjustment, zone scanning.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Spend Evade token | Die removal/reroll UI works |
| 2 | Spend Redirect token | Zone selection UI appears, damage redirected |
| 3 | Spend Brace during defense | Damage halved in real-time display |
| 4 | Spend Contain token | Critical prevented |
| 5 | Lock token with Accuracy | Token greyed out, cannot be spent |

---

### A3: GameBoard Oversized Functions ✅

7 oversized functions in `game_board.gd`.

#### A3-01: All 7 functions in one step ✅

**What changes:** `_create_turn_management_ui()` (62),
`_create_ship_card_panels()` (49), `_on_execute_maneuver()` (40),
`_spawn_learning_scenario_tokens()` (39), `_create_drag_preview()` (37),
`_squadron_has_valid_targets()` (34), `_on_squadron_step_entered()` (33)
— extract helpers.

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Game launches | Board displays correctly with all tokens |
| 2 | Card panels appear | Left/right panels with correct ships |
| 3 | Phase HUD shows | Round/phase label at top-centre |
| 4 | Activate ship, execute maneuver | Ship moves, overlaps handled |
| 5 | Drag command dial | Preview follows mouse, drops correctly |
| 6 | Enter Squadron Phase | Modal appears if squadrons can activate |

---

### A4: Other Files

Grouped into a single implementation step per file.

#### A4-01: `maneuver_tool_scene.gd` — 5 oversized

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Press M (maneuver tool) → select ship | Maneuver tool appears at ship front |
| 2 | Adjust speed, click joints | Tool articulates correctly |
| 3 | Ghost ship updates | Ghost position/rotation matches tool end |
| 4 | Confirm maneuver | Ship moves to ghost position |

---

#### A4-02: `token_mover.gd` — 4 oversized

**Manual test:** Covered by maneuver test (movement + overlap pushing).

---

#### A4-03: `game_manager.gd` — 3 oversized ✅

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Game starts → Round 1 commands auto-assigned | Correct commands for learning scenario |
| 2 | Activate ship via token conversion | Token added, overflow handled |
| 3 | Command picker confirmation | Dials assigned to correct ships |

---

#### A4-04: `damage_card_effect.gd` — 3 oversized

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Deal face-up damage with immediate effect | Effect triggers and resolves |
| 2 | Persistent effect active | Effect modifies ship stats during play |

---

#### A4-05: `overlap_resolver.gd` — 2 oversized

**Manual test:** Covered by maneuver test (overlap detection + damage).

---

#### A4-06: `main_menu.gd` — 2 oversized

**Manual test:**

| # | Action | Expected Result |
|---|--------|-----------------|
| 1 | Launch game | Main menu displays with title, buttons |
| 2 | Click "Learning Scenario" | Game starts |
| 3 | Settings/options | Modal appears |

---

#### A4-07: Remaining 8 files (1 function each)

Files: `immediate_effect_resolver.gd`, `ship_token.gd`, `firing_arc_overlay.gd`,
`music_manager.gd`, `maneuver_tool_state.gd`, `repair_resolver.gd`,
`squadron_data.gd`, `game_scale.gd`, `sfx_manager.gd`, `ship_base.gd`.

**Manual test:** No dedicated test needed — these are covered by the integration
tests above (attack flow, maneuver, repair, audio). Just verify GUT passes.

---

## Phase B — Narrow Interfaces

*To be detailed when Phase A is complete.*

## Phase C — Extract Isolated Clusters

*To be detailed when Phase B is complete.*

## Phase D — UI Builder Cleanup

*To be detailed when Phase C is complete.*

## Phase E — Serialization & EventBus Cleanup

*To be detailed when Phase D is complete.*

---

*Document created: 2026-04-04. Updated with each completed step.*

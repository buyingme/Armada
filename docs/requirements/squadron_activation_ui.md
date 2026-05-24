# Squadron Phase Activation UI — Requirements & Implementation Plan

> **Status:** DRAFT — awaiting approval before implementation.
> **Phase:** 7b (Squadron Phase UI)
> **Prerequisite phases:** Phase 7 (effect pipeline, engagement, movement validation), Phase 6 (attack execution pipeline)

---

## 1. Overview

The Squadron Phase currently has full turn-management logic in `GameManager`
(initiative-player-first, 2-per-turn alternation, auto-pass) but no
interactive UI. This document specifies the modal, overlays, and wiring
needed to let the player activate individual squadrons (select → move or
attack → commit), reusing existing systems wherever possible.

---

## 2. Rules Summary (authoritative text)

| Source | Key Rule |
|--------|----------|
| RRG "Squadron Phase" p.20 | First player activates two, then second player activates two; repeat. |
| RRG "Squadron Phase" p.20 | A player does not choose the 2nd squadron until after the 1st finishes. |
| RRG "Squadron Phase" p.20 | If only 1 unactivated remains, activate only that one. 0 → pass. |
| RRG "Squadron Phase" p.20 | A squadron can **either move or attack** when activated during this phase; not both. |
| RRG "Squadron Activation" p.19 | A squadron can activate and choose to **end its activation without moving or attacking**. |
| RRG "Squadron Activation" p.19 | After activation, toggle activation slider. |
| RRG "Squadron Activation" p.19 | Cannot activate if slider colour doesn't match initiative token. |
| RRG "Engagement" p.4 | Engaged squadron **cannot move** (SM-011). |
| RRG "Engagement" p.4 | Engaged squadron **must attack** an engaged enemy (SM-012). |
| RRG "Squadron Movement" p.19 | Pick up and place within distance band matching speed; no overlap. |
| RRG "Squadron Keywords" p.19 | **Rogue** — can move **and** attack during Squadron Phase (either order). |
| RRG "Squadron Keywords" p.19 | **Grit** — not prevented from moving while engaged by only 1 squadron. |
| RRG "Squadron Keywords" p.19 | **Heavy** — does not prevent engaged squadrons from attacking ships or moving. |
| RRG "Squadron Keywords" p.19 | **Escort** — engaged squadrons must target Escort first. |

---

## 3. Requirements

### 3.1 Squadron Activation Modal (SQA-xxx)

| ID | Requirement | Rules Source | Notes |
|----|-------------|--------------|-------|
| SQA-001 | When the Squadron Phase begins for the active player, a **Squadron Activation Modal** opens at bottom-centre (matching ActivationModal / AttackSimPanel positioning). | TF-008 | Anchor `PRESET_CENTER_BOTTOM`, offsets −120/−40. |
| SQA-002 | The modal title shows **"Squadron Phase — [Faction]"** and a subtitle **"Activate squadron N of M"** where N = current activation count within the turn (1 or 2) and M = min(remaining unactivated, `SQUADRONS_PER_ACTIVATION`). | SQ-003 | |
| SQA-003 | The modal prompt reads **"Click a squadron to activate"** while no squadron is selected. | — | |
| SQA-004 | When the player clicks an owned, unactivated squadron token, it becomes the **active squadron**. `GameManager.activate_squadron()` is called. The modal updates to show the squadron name and available actions. | SQ-003, SQ-006 | |
| SQA-005 | After selecting a squadron, the modal shows two action buttons: **"Move"** and **"Attack"**. | SQ-006 | |
| SQA-006 | If the squadron is **engaged** (and not bypassed by Heavy/Grit), the **"Move" button is disabled** with a tooltip "Engaged — cannot move". | SM-011 | Use `EngagementResolver.can_squadron_move()`. |
| SQA-007 | If the squadron has the **Rogue** keyword, **both Move and Attack can be performed** (in either order), matching command-activation behaviour. The modal tracks which actions have been taken and enables/disables accordingly. | RRG "Rogue" | Rogue ≠ normal Squadron Phase rules. |
| SQA-008 | A third button **"Skip (End Activation)"** is always available. Clicking it ends the activation without moving or attacking. | RRG "Squadron Activation" p.19 | "A squadron can activate and choose to end its activation without moving or attacking." |
| SQA-009 | After the player completes their chosen action(s) (or skips), the modal emits `squadron_activation_ended` via EventBus to advance GameManager's turn counter. | TF-010, TF-011 | |
| SQA-010 | After the Nth activation (N = `SQUADRONS_PER_ACTIVATION`), or when no unactivated squadrons remain, the modal closes and a **handoff/table-rotate** occurs for hot-seat mode. | TF-008, TF-012 | Reuse existing `_on_active_player_changed` flow + handoff overlay. |
| SQA-011 | The modal is **dismissable via Escape** (hides it, does not cancel the activation). A **"Show Squadron Modal"** button (similar to existing ShowActivationButton) allows re-opening. | `.skills/ui_styling.md` §6 | |
| SQA-012 | The modal uses the **standard panel style** from `.skills/ui_styling.md` §1 (dark blue-grey, blue border, rounded corners). | ui_styling.md | |
| SQA-013 | The **ShowActivationButton** (existing) is hidden during the Squadron Phase. Instead, a new **ShowSquadronModalButton** appears when the squadron modal is dismissed. | Consistency with Ship Phase behaviour | |

### 3.2 Movement Overlay (SQM-xxx)

| ID | Requirement | Rules Source | Notes |
|----|-------------|--------------|-------|
| SQM-001 | When "Move" is pressed, a **translucent brownish circle** overlay is drawn centred on the squadron's current position, with radius = max move distance for the squadron's speed (from `SquadronMover._get_max_move_distance()`). | SM-001, SM-002 | Colour: `Color(0.6, 0.4, 0.2, 0.2)` — semi-transparent brown. |
| SQM-002 | Simultaneously, an **armament range circle** is drawn: green outline for Imperial, red outline for Rebel squadrons, at distance 1 radius (`GameScale.distance_bands_px[0]`). | User req | Green = `Color(0.3, 0.8, 0.3, 0.5)`, Red = `Color(0.8, 0.3, 0.3, 0.5)`. "Armament range" = engagement/attack range = distance 1. |
| SQM-003 | The player clicks **on the board** to place the squadron at the target position. `SquadronMover.validate_move()` is called. If invalid (overlap or too far), the move is rejected with a brief error message and the player can re-click. | SM-001–005 | |
| SQM-004 | On valid placement, the squadron token snaps to the new position and the modal shows a **"Commit Move"** button. | User req | Two-click: click to preview position → "Commit Move" to finalise. |
| SQM-005 | On "Commit Move", engagement flags are recalculated via `EngagementResolver.update_engagement_flags()`, `EventBus.squadron_moved.emit()` fires, and if the squadron does NOT have Rogue, the activation ends. | SM-010, SM-015 | Rogue squadrons can still attack after moving. |
| SQM-006 | If no valid move target is available (squadron speed 0 or all reachable positions blocked), the button should still be available but clicking it results in a "stay in place" move (SM-005: staying is always valid). | SM-005 | |
| SQM-007 | Pressing Escape during move mode cancels the move (reverts position if previewed) and returns to the action-selection state. | Consistency | |

### 3.3 Attack Integration (SQA-ATK-xxx)

| ID | Requirement | Rules Source | Notes |
|----|-------------|--------------|-------|
| SQA-ATK-001 | When "Attack" is pressed, the existing **AttackSimPanel** is opened with the active squadron **pre-selected as the attacker**. | User req, reuse Phase 6 | Need a new `start_squadron_attack(squadron_token)` method on AttackExecutor. |
| SQA-ATK-002 | The AttackSimPanel enters target-selection mode. The player clicks an **enemy squadron** (anti-squadron armament) or an **enemy ship hull zone** (battery armament) to declare the target. | RRG "Attack" Step 1 | |
| SQA-ATK-003 | If the squadron is **engaged**, valid attack targets are restricted to engaged enemies (SM-012). If an engaged enemy has Escort, only Escort targets are valid (SM-031). | SM-012, SM-031 | Use `EngagementResolver.get_valid_engaged_targets()`. |
| SQA-ATK-004 | The full attack resolution pipeline executes: dice roll, accuracy step, defense tokens (if defender has them), damage resolution. | RRG "Attack" Steps 1–6 | Reuse all existing `AttackExecutor` logic. |
| SQA-ATK-005 | After attack completes (or is cancelled), control returns to the squadron modal. If the squadron does NOT have Rogue, the activation ends. | SQ-006 | |
| SQA-ATK-006 | **Counter attacks** resolve automatically after the attack (if applicable). | SM Keywords "Counter" | Already handled by AttackExecutor. |

### 3.4 Turn Management Wiring (SQA-TM-xxx)

| ID | Requirement | Rules Source | Notes |
|----|-------------|--------------|-------|
| SQA-TM-001 | The squadron modal opens automatically when `active_player_changed` fires during the Squadron Phase (after handoff overlay dismiss). | TF-008 | Wire into `_on_handoff_accepted()` in game_board.gd. |
| SQA-TM-002 | The `_on_activation_ended()` path for Squadron Phase is replaced: instead of the End Activation button driving it, the squadron modal's "Skip" or action-completion drives `EventBus.squadron_activation_ended.emit()`. | TF-011 | End Activation button is NOT shown during Squadron Phase (already the case). |
| SQA-TM-003 | After both players pass or all squadrons are activated, the phase advances to Status Phase automatically. | TF-012 | Already handled by `_advance_squadron_phase_turn()`. |
| SQA-TM-004 | Activated squadrons are visually dimmed (reduced alpha) on the board to indicate they cannot be selected again. | SQ-008 | Toggle visual on `activated_this_round = true`. |

---

## 4. Rules Compliance Check

| User Spec Item | Rules Compliance | Verdict |
|---|---|---|
| "A squadron may either move or attack, not both" | ✅ Matches RRG "Squadron Phase" exactly. | OK |
| "If engaged, cannot move" | ✅ Matches RRG "Engagement" SM-011. | OK |
| "Movement overlay = reachable area" | ✅ Matches RRG "Squadron Movement": place within distance band of speed. | OK |
| "Armament range circle = range 1" | ✅ Squadron attacks are at distance 1 (anti-squadron) or range of battery armament. Anti-squadron is always distance 1 by RRG. Battery can target ships within armament range. The circle is a helpful visual guide. | OK — note: battery attacks on ships have longer range (depends on dice colour). The circle showing distance 1 is correct for anti-squadron but not for anti-ship battery. See Ambiguity #1 below. |
| "After 2nd squadron, rotate table" | ✅ Matches RRG: players alternate after activating 2 (or fewer if that's all they have). | OK |
| "Repeat until all activated" | ✅ Matches RRG "Squadron Phase". | OK |
| Not mentioned: "A squadron can end activation without moving or attacking" | ⚠️ **Must add:** RRG explicitly allows skipping both. Added as SQA-008. | ADDED |
| Not mentioned: **Rogue** keyword | ⚠️ **Must handle:** Rogue squadrons can move AND attack during Squadron Phase. The learning scenario has neither X-wings nor TIE Fighters with Rogue, but the system should support it for correctness. | ADDED (SQA-007) |
| Not mentioned: **Grit** / **Heavy** interaction | ⚠️ **Must handle via RuleRegistry keyword surfaces:** Grit allows movement when engaged by only 1 squadron (unless that squadron lacks Heavy). Move-button state should use projected keyword eligibility, not just raw engagement. | Architecture note |

---

## 5. Resolved Ambiguities

| # | Question | Decision |
|---|----------|----------|
| 1 | **Armament range circle scope** — anti-squadron only or also battery? | Battery armament is also range 1 for squadrons. **One distance-1 circle covers both.** |
| 2 | **Overlay timing** — on selection or after pressing Move? | **Both overlays shown on squadron selection:** movement range (if eligible) AND armament range circle. Player sees all info immediately. |
| 3 | **Move preview flow** — snap + commit? | **Yes:** snap token to click position, show "Commit Move" button. Escape reverts. |
| 4 | **Engaged skip enforcement** — allow or block? | **Block:** disable "Skip" when engaged (SM-012). Engaged non-Rogue squadrons can only Attack. |
| 5 | **Activated visual** — alpha or grey overlay? | **Alpha reduction** to ~0.4. Simple, no new art. |

---

## 6. Implementation Plan

### 6.1 New Files

| # | File | Layer | Description |
|---|------|-------|-------------|
| 1 | `src/ui/squadron_activation_modal.gd` | UI | Modal panel guiding the player through squadron selection, action choice (Move/Attack/Skip), and commit. |
| 2 | `src/ui/squadron_move_overlay.gd` | UI | Node2D overlay drawing the movement-range circle and armament-range circle. |
| 3 | `src/ui/show_squadron_modal_button.gd` | UI | "Show Squadron Modal" button, analogous to `ShowActivationButton`. |
| 4 | `tests/unit/test_squadron_activation_modal.gd` | Test | Unit tests for modal state machine. |
| 5 | `tests/unit/test_squadron_move_overlay.gd` | Test | Unit tests for overlay geometry calculations. |
| 6 | `tests/integration/test_squadron_phase_flow.gd` | Test | Integration tests for full activation→move/attack→commit→advance flow. |

### 6.2 Modified Files

| # | File | Changes |
|---|------|---------|
| 1 | `src/scenes/game_board/game_board.gd` | Wire squadron modal lifecycle: create on Squadron Phase start, connect signals, handle handoff, pass squad token clicks to modal. |
| 2 | `src/scenes/game_board/attack_executor.gd` | Add `start_squadron_attack(squadron_token: SquadronToken)` method that pre-selects the attacker and enters target-selection mode. |
| 3 | `src/scenes/tokens/squadron_token.gd` | Add `set_activated_visual(activated: bool)` method to dim the token (modulate alpha). |
| 4 | `src/autoload/event_bus.gd` | (Possibly) add `squadron_move_started`, `squadron_move_committed` signals if needed for overlay coordination. |
| 5 | `src/autoload/game_manager.gd` | Minor: ensure `activate_squadron()` returns a success bool so the modal knows the activation was accepted. |
| 6 | `docs/implementation_plan.md` | Add Phase 7b section. |
| 7 | `docs/test_plan_manual.md` | Add Phase 7b manual test section. |

### 6.3 Implementation Steps (ordered)

| Step | Task | Depends On | Deliverables |
|------|------|------------|--------------|
| 1 | **SquadronToken visual dimming** — add `set_activated_visual()` | — | Modified `squadron_token.gd` |
| 2 | **SquadronMoveOverlay** — Node2D that draws movement circle + armament range circle. Pure visual, receives position + speed + faction as params. | — | New `squadron_move_overlay.gd` + tests |
| 3 | **SquadronActivationModal** — PanelContainer with state machine: `WAITING_FOR_SELECTION` → `ACTION_CHOICE` → `MOVING` → `ATTACKING` → `DONE`. Styled per ui_styling.md. | Step 2 | New `squadron_activation_modal.gd` + tests |
| 4 | **ShowSquadronModalButton** — simple button following ShowActivationButton pattern. | Step 3 | New `show_squadron_modal_button.gd` |
| 5 | **AttackExecutor.start_squadron_attack()** — new entry point that pre-selects a squadron attacker. Restricts targets per engagement rules. Emits `attack_exec_completed` when done. | — | Modified `attack_executor.gd` |
| 6 | **GameBoard wiring** — create modal in Squadron Phase, connect token clicks, wire attack executor, handle handoff, hide/show buttons. | Steps 1–5 | Modified `game_board.gd` |
| 7 | **Integration tests** — full flow: phase start → select squadron → move → commit → advance; select → attack → resolve → advance; skip; engaged restrictions; Rogue both actions. | Steps 1–6 | New test file |
| 8 | **Docs update** — implementation_plan.md Phase 7b + test_plan_manual.md. | Step 7 | Modified docs |

### 6.4 State Machine (SquadronActivationModal)

```
WAITING_FOR_SELECTION
    │  (player clicks owned unactivated squadron)
    ▼
ACTION_CHOICE
    │  ├──[Move]──► MOVING ──[Commit]──► DONE (or ACTION_CHOICE if Rogue)
    │  ├──[Attack]──► ATTACKING ──[Complete/Cancel]──► DONE (or ACTION_CHOICE if Rogue)
    │  └──[Skip]──► DONE
    ▼
DONE
    │  (emit squadron_activation_ended)
    │  (if more activations remain: → WAITING_FOR_SELECTION)
    │  (if turn complete: → close modal, trigger handoff)
```

### 6.5 Estimated Test Count

| Category | Estimated Tests |
|----------|----------------|
| Modal state machine (unit) | ~20 |
| Move overlay geometry (unit) | ~8 |
| Attack executor squadron entry (unit) | ~6 |
| Integration flow tests | ~15 |
| **Total new** | **~49** |
| **Running total** | **~1395** (from 1346 current) |

---

## 7. Out of Scope (deferred)

- Squadron Command activation during Ship Phase (SQ-007) — handled separately in Phase 9/10.
- Counter-attack animations — counter logic already works; visual polish deferred.
- Advanced keyword UI (Snipe range display, Intel aura, etc.) — future enhancement.
- Network mode synchronisation — hot-seat only for MVP.

# Refactoring Phase K — Presentation-Layer Hardening

> **Status:** PROPOSED — awaiting approval before implementation.
> **Drafted:** 2026-05-08
> **Predecessors:** Phases A–I (closed); Phase J (save subsystem, closed at J11).
> **Successor:** Resumes G4.7 (Spectator), G4.8 (Reconnection), G4.9 (Turn Timers), then Phase 10c.

---

## 1. Why Now

After the Phase I closure and Phase J save subsystem, the **core/domain layer is
industry-grade**: pure RefCounted, fully serialised, command-mediated, replay-safe.
The presentation layer, however, has accumulated four concrete kinds of debt that
will block or destabilise the next feature wave (G4.7+):

| Symptom | Concrete evidence |
|---|---|
| God-object scenes | [src/scenes/game_board/game_board.gd](../src/scenes/game_board/game_board.gd) **3 055 LOC**; [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) **2 475 LOC**; [game_manager.gd](../src/autoload/game_manager.gd) **2 241 LOC** |
| Phase I rule violations | **9** `if PlayMode.is_network()` / `is_hot_seat()` branches in scenes (rule §7 of `.github/copilot-instructions.md`) |
| Function-size / nesting drift | ~15 functions > 30 LOC, ~8 with > 3-level nesting (worst: `_attack_exec_begin_sequence` ~75 LOC / 5 levels) |
| Test gaps on Phase-I primitives | No dedicated `test_interaction_flow.gd`; `UIProjector` projection paths under-asserted |

The J11 navigate-token bug (yaw bonus surviving dial→token convert) was an
early symptom of category 1: state cached in a ~3 000-LOC scene class drifted
out of sync with a domain mutation. Fixing it after the fact required threading
a new helper through the controller. The next feature in the same area (e.g.
turn timers triggering forced-pass) will have the same exposure.

This plan is bounded, mechanical, and **fully covered by the existing test
suite (143 scripts / 2 873 tests / 5 410 asserts / 0 failures)**. It introduces
no new gameplay behaviour.

---

## 2. Goals & Non-Goals

### 2.1 Goals (quantified)

| ID | Target |
|----|--------|
| K-G1 | Zero `if PlayMode.is_network()` / `is_hot_seat()` occurrences in **interaction-flow / modal-authority code** under `src/scenes/game_board/`. (Lint script categorises sites — see §3.1a for the allow-list of session-mode discriminators in save/load dialogs and lobby flow.) |
| K-G2 | [game_board.gd](../src/scenes/game_board/game_board.gd) ≤ **2 000 LOC** (down from 3 055). Composition root only — no game-flow branches. |
| K-G3 | [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) ≤ **1 500 LOC** (down from 2 475) by extracting an `AttackFlowExecutor` (RefCounted) into `src/core/combat/`. |
| K-G4 | [game_manager.gd](../src/autoload/game_manager.gd) ≤ **1 500 LOC** (down from 2 241) by extracting `NetworkPhaseSync` and `GameCommandSubmitterRouter` helpers. |
| K-G5 | Zero functions > 30 LOC and zero functions with > 3-level nesting in `src/core/` and `src/scenes/`. |
| K-G6 | `tests/unit/test_interaction_flow.gd` (already 27 tests) and `tests/unit/test_ui_projector.gd` (already 23 tests) extended to cover any new `UIIntent` fields introduced in K1. **Existing files retained.** |
| K-G7 | Test baseline maintained: 0 failing tests at every commit; `godot --headless --import` clean. |
| K-G8 | All sliced commits keep manual-test gate (per `.skills/copilot_instructions.md`). |

### 2.2 Non-Goals

- No new gameplay features. No rules changes.
- No EventBus signal removals (the 3 leaky signals identified in the audit
  remain in scope for a follow-up Phase L; out of scope here).
- No file-format migration. No save-format version bump.
- No Godot API upgrade. Pinned to 4.5+ as today.
- No CI/CD setup (TD-2 remains; tracked separately).

---

## 3. Scope Inventory (audited 2026-05-09)

### 3.1 PlayMode-branch sites — full inventory

A deeper grep on 2026-05-09 found **28** real branches under `src/scenes/`
and `src/ui/` (the original audit undercounted at 9). They split into two
categories:

#### 3.1a Allow-listed: session-mode discriminators (NOT removed by K)

These check whether the running process is in a network session at all
(e.g. "is this a host?", "should the lobby button appear?"). They are
*not* interaction-flow / modal-authority decisions and are intrinsic to
the deployment mode. The lint script treats these files as
allow-listed:

| File | Line | Purpose |
|------|-----:|---|
| [save_game_dialog.gd](../src/ui/save/save_game_dialog.gd) | 270 | Network-client cannot save (defense in depth UI). |
| [load_game_dialog.gd](../src/ui/save/load_game_dialog.gd) | 371, 496 | Network-row enable/disable based on host session presence. |
| [game_menu_modal.gd](../src/ui/save/game_menu_modal.gd) | 401 | ESC menu button visibility (host vs client). |
| [lobby_room.gd](../src/scenes/lobby/lobby_room.gd) | 365 | Lobby is network-only by definition. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1325 | `_handle_command_dial_dropped` uses sentinel `-1` only in network mode (see Phase I doc-comment line 1339). May be revisited in K12 but not as part of K-G1. |

#### 3.1b Targeted for removal in K (interaction-flow / modal-authority)

| File | Line(s) | Slice | Resolution |
|------|---------|:-----:|---|
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 889, 892 | K2 | `_on_active_player_changed` — converge hot-seat + network handoff via shared `_apply_seat_handoff()` helper that branches on `state.active_player == local_player`. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1072, 1091 | K2 | `_on_command_executed_project_ui` — replace with `UIIntent.is_interactive` reads. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1508 | K2 | Activation-modal lifecycle — gate on `intent.modal_kind`. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 2138 | K2 | Maneuver overlap auto-resolve flag — set via `intent.is_interactive`. |
| [command_phase_controller.gd](../src/scenes/game_board/command_phase_controller.gd) | 165, 167 | K3 | Dial picker authority — `intent.modal_kind == COMMAND_DIALS` + `intent.is_interactive`. |
| [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) | 1033, 1050, 1244, 1394, 2045, 2054, 2212 | K4 | Panel read-only / camera focus / "is local actor" checks — `intent.is_interactive` + new `intent.is_active_seat()` helper. The two `_camera and is_hot_seat` patterns become `_camera and intent.allows_camera_rotation()` (new field — see K1). |
| [squadron_phase_controller.gd](../src/scenes/game_board/squadron_phase_controller.gd) | 378, 495 | K6 | Squadron move-submit gating — `intent.is_interactive` + flow-step read. |
| [displacement_controller.gd](../src/scenes/game_board/displacement_controller.gd) | 124, 342 | K5 | Displacement modal authority + validation — `intent.modal_kind == DISPLACEMENT` + `intent.is_interactive`. |

**Total to remove in K: 18 branches across 5 files.** (Down from the
original 9-branch over-estimate; the audit was both too low at the
file-fan-out level and too aggressive at including session-mode sites.)

### 3.1c New `UIIntent` field needed (K1)

After re-checking the layer rules, **no new UIIntent field is added in K1**.

`UIProjector.project()` lives in `src/core/network/` and extends
`RefCounted` — it cannot read autoload state (PlayMode) without violating
the downward-only dependency rule. The "is the local seat the camera
seat?" question is a deployment-mode property, not an interaction-flow
property, and therefore does not belong in `UIIntent`.

Instead, K1 introduces a tiny encapsulation helper as an autoload-side
addition (in `src/autoload/play_mode.gd`):

```gdscript
## True when this seat physically controls a dedicated camera.  In
## network mode every peer has its own camera (always true).  In
## hot-seat the camera follows the active player, so only the active
## seat returns true.  Used by scenes to choose between "rotate" and
## "lock" camera behaviour without branching on `is_network()` directly.
static func seat_controls_camera(active_player: int,
        local_player: int) -> bool:
    if PlayMode.is_network():
        return true
    return active_player == local_player
```

This keeps the deployment-mode branch in **one place** (PlayMode), and
scenes call `PlayMode.seat_controls_camera(...)` instead of branching
themselves. The autoload location is allowed by the layer rule.

The original plan's `modal_lifecycle` and `camera_focus` UIIntent fields
are **dropped** as unnecessary — every other audited site can use an
existing UIIntent field (`is_interactive`, `modal_kind`,
`controller_player`, `flow_type`, `step_id`, `payload`).

### 3.2 Functions exceeding 30 LOC / 3-level nesting (K3)

| File | Function | ~LOC | Nesting | Decomposition |
|------|---|---:|---:|---|
| game_board.gd | `_on_command_executed_project_ui()` | ~100 | 4 | `match` dispatch → per-result handler |
| game_board.gd | `_on_execute_maneuver()` | ~65 | 4 | extract overlap resolver + finalise |
| game_board.gd | `_resolve_maneuver_overlaps_ex()` | ~55 | 4 | overlap detector + damage applier + IF update |
| game_board.gd | `_on_active_player_changed()` | ~50 | 4 | camera + card swap + handoff helpers (then absorbed by K1) |
| attack_executor.gd | `_attack_exec_begin_sequence()` | ~75 | 5 | linear `_show_next_sequence_step()` chain |
| attack_executor.gd | `_apply_dice_roll_result()` | ~45 | 4 | extract CF-token branch |
| attack_executor.gd | `apply_defender_commit()` | ~50 | 3 | extract token-queue iterator |
| attack_executor.gd | `_emit_card_events()` | ~40 | 4 | extract faceup/facedown loops |
| game_manager.gd | `_on_activation_ended()` | ~35 | 4 | extract phase-advance branch |
| save_game_manager.gd | `save_game()` | ~80 | 5 | already partly extracted; finish the split |

### 3.3 God-object decomposition targets (K2)

#### K2a — game_board.gd → 5 sub-controllers

Concrete extraction, each a new `RefCounted`-or-`Node` controller wired into a
slimmer composition root:

| New controller | File | Responsibilities currently in game_board |
|---|---|---|
| `ShipActivationController` | `src/scenes/game_board/ship_activation_controller.gd` | dial drag → token convert → activation modal lifecycle → maneuver tool entry → overlap resolution wiring |
| `AttackPanelController` | `src/scenes/game_board/attack_panel_controller.gd` | mounting `AttackExecutor`, panel signal wiring, mirrored-panel projection on follower peer |
| `DebugBoardController` | `src/scenes/game_board/debug_board_controller.gd` | F-key debug damage, debug token apply, replay save (logging-mode-gated) |
| `ToolOverlayController` | `src/scenes/game_board/tool_overlay_controller.gd` | maneuver tool / range overlay / targeting overlay lifecycles |
| `CommandRouterAdapter` | `src/scenes/game_board/command_router_adapter.gd` | `EventBus.command_executed` → `UIProjector.project` → mutate UI; this is the **single** point where projection enters the scene tree |

#### K2b — attack_executor.gd → AttackFlowExecutor (core)

Move the FSM + dice/defense pipeline glue out of the scene layer:

```
src/core/combat/attack_flow_executor.gd     # NEW — RefCounted
src/scenes/game_board/attack_executor.gd    # KEEPS: panel mount, token queries, signal wiring
```

The new core class consumes / produces `Dictionary` payloads and never
touches the scene tree. The scene-side `attack_executor.gd` becomes a thin
adapter: ~700–900 LOC, all UI orchestration.

#### K2c — game_manager.gd → split

| New helper | Location | Responsibilities |
|---|---|---|
| `NetworkPhaseSync` | `src/core/network/network_phase_sync.gd` | All `_handle_remote_*` methods (phase-advance broadcast, immediate-effect signals, network damage hooks) |
| `GameCommandSubmitterRouter` | `src/core/commands/game_command_submitter_router.gd` | Thin facade for `submit_*` methods (currently duplicated dispatch in game_manager) |

GameManager keeps only: turn/phase state machine, command processor wiring,
new-game lifecycle.

#### K2d — save_game_manager.gd → split

| New helper | Location | Responsibilities |
|---|---|---|
| `CheckpointStore` | `src/autoload/save/checkpoint_store.gd` | Per-mode in-memory checkpoint + disk persist + numbered debug snapshots |
| `SaveGameSerializer` | `src/core/state/save_game_serializer.gd` | Pure serialize / deserialize of `GameState` + metadata round-trip |

`SaveGameManager` retains: public API (save/load/list), HMAC verify, session
artefact cleanup, signal emission.

### 3.4 Test gaps (K4)

| New test file | Coverage target |
|---|---|
| `tests/unit/test_interaction_flow.gd` | flow_type / step_id / controller_player / payload mutations; visibility filter; serialize / deserialize round-trip |
| `tests/unit/test_ui_projector.gd` | All flow types × {host, client, hot-seat-A, hot-seat-B} → expected `UIIntent` |
| `tests/unit/test_attack_flow_executor.gd` | (after K2b) FSM transitions for ship-attack and squadron-attack |
| `tests/unit/test_network_phase_sync.gd` | (after K2c) `_handle_remote_*` payloads emit correct EventBus signals |

### 3.5 Lint guards (K5)

New `scripts/lint_phase_k.sh`:

```bash
#!/usr/bin/env bash
set -e
fail=0
echo "→ checking PlayMode branches in presentation layer"
if git grep -nE 'if[[:space:]]+PlayMode\.is_(network|hot_seat)' -- src/scenes src/ui ; then
  echo "FAIL: PlayMode branches must be replaced with UIProjector.project()"; fail=1
fi
echo "→ checking function length (>30 LOC) in src/core and src/scenes"
# (awk pass over .gd files; reuse existing helper if present)
exit $fail
```

Wired into `.git/hooks/pre-commit` (instructions added to
`docs/setup_network_game.md` developer-setup section).

---

## 4. Slice Plan

Each slice = one commit (or a tight pair: implementation + tests). Every slice
ends in green tests, green import, and a manual-test gate when behaviour is
observable. Numbering matches the eventual phase-status table row.

| Slice | Scope | Risk | LOC delta | MT? |
|------:|---|---|---:|:---:|
| **K0** | Audit snapshot frozen — copy this plan into the repo, append §J11 row to implementation_plan §5.7. **No code changes.** Committed `664d368`. Refined 2026-05-09 with deeper audit (28 → 18 sites; one new UIIntent field instead of three). | trivial | 0 | no |
| **K1** | Add `PlayMode.seat_controls_camera(active_player, local_player) -> bool` static helper in [play_mode.gd](../src/autoload/play_mode.gd). Add unit tests for it (≥ 4 asserts: network always true; hot-seat active-seat true; hot-seat non-active false; hot-seat invalid params). **No UIProjector changes** (`src/core/` cannot read PlayMode). | low | +30 / 0 | no |
| **K2** | Replace 6 game_board branches (lines 889, 892, 1072, 1091, 1508, 2138) with `UIIntent` reads. Extract `_apply_seat_handoff(player_index, intent)` helper to remove the if/else split in `_on_active_player_changed`. | medium | +50 / −60 | yes |
| **K3** | Replace 2 branches in [command_phase_controller.gd](../src/scenes/game_board/command_phase_controller.gd) (lines 165 / 167). | medium | +10 / −20 | yes |
| **K4** | Replace 7 branches in [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) (lines 1033, 1050, 1244, 1394, 2045, 2054, 2212). | medium | +25 / −40 | yes |
| **K5** | Replace 2 branches in [displacement_controller.gd](../src/scenes/game_board/displacement_controller.gd) (lines 124, 342). | medium | +10 / −20 | yes |
| **K6** | Replace 2 branches in [squadron_phase_controller.gd](../src/scenes/game_board/squadron_phase_controller.gd) (lines 378, 495). | medium | +10 / −15 | yes |
| **K7** | Land lint script `scripts/lint_phase_k.sh` (with allow-list per §3.1a). Add pre-commit hook documentation. (No new tests — InteractionFlow + UIProjector tests already exist.) | low | +60 / 0 | no |
| **K8** | Extract `ShipActivationController` from game_board.gd (dial drag + activation modal + maneuver entry). Move ~400 LOC. | high | +450 / −400 | yes |
| **K9** | Extract `AttackPanelController` from game_board.gd. Move ~250 LOC. | high | +290 / −250 | yes |
| **K10** | Extract `DebugBoardController` from game_board.gd (F-key debug damage, replay save trigger). Move ~150 LOC. | medium | +180 / −150 | yes |
| **K11** | Extract `ToolOverlayController` from game_board.gd (maneuver/range/targeting overlay). Move ~200 LOC. | high | +230 / −200 | yes |
| **K12** | Introduce `CommandRouterAdapter` — single subscription to `EventBus.command_executed` that calls `UIProjector.project()` and routes to controllers. Removes the giant `_on_command_executed_project_ui` switch. | high | +180 / −100 | yes |
| **K13** | Function-size cleanup pass on what remains in game_board.gd (no extraction, only `match` dispatch + helper extraction). | medium | +0 / 0 | no |
| **K14** | Extract `AttackFlowExecutor` (RefCounted) into `src/core/combat/`. Add `test_attack_flow_executor.gd`. Scene-side `attack_executor.gd` becomes adapter. | high | +900 / −800 | yes |
| **K15** | Function-size + nesting cleanup pass on attack_executor.gd remainder. | medium | +0 / 0 | no |
| **K16** | Extract `NetworkPhaseSync` from game_manager.gd. | medium | +350 / −300 | yes |
| **K17** | Extract `GameCommandSubmitterRouter` from game_manager.gd. | medium | +250 / −200 | yes |
| **K18** | Extract `CheckpointStore` + `SaveGameSerializer` from save_game_manager.gd. | medium | +500 / −400 | yes |
| **K19** | Final lint pass: enforce `lint_phase_k.sh` exit 0; update `docs/arc42/05_building_block_view.md` with the new component diagram; close out the phase row in `implementation_plan.md`. | low | docs only | no |

**Estimated effort by risk class:** 6 medium + 6 high slices is the bulk. The
medium slices (K1–K7) are mechanical and individually small. The high slices
(K8–K12, K14) are substantive moves that demand careful diff review and a
proper MT gate but no rules logic changes.

### 4.1 Sequencing rationale

1. **K1–K7 first** (Phase I rule cleanup). These are small, low-risk, and
   immediately deliver the K-G1 metric. They also force the team to adopt
   `UIProjector` everywhere before K8 reorganises the surrounding code.
2. **K8–K13** (game_board split). Done in 5 commits so each is reviewable.
3. **K14–K15** (attack_executor split). Independent of K8–K13.
4. **K16–K18** (autoload splits). Independent; can interleave with the
   above if appetite allows.
5. **K19** finalises docs and lint enforcement.

### 4.2 Rollback boundary

Every slice is one commit on `master`. Any slice can be reverted with
`git revert` without disturbing the others. Slice K1 is the only slice that
adds public API to `UIProjector` — its revert window closes when K2 lands.

---

## 5. Safety Checklist (every slice)

Before committing a Phase K slice:

- [ ] `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` → 0 failing, expected script count, asserts ≥ baseline
- [ ] `godot --headless --import` clean (no missing `.gd.uid`)
- [ ] `scripts/lint_phase_k.sh` exit 0
- [ ] No new function exceeds 30 LOC; no new nesting > 3
- [ ] No new EventBus signal added (Phase K is a redistribution exercise)
- [ ] No new mutable field on `GameState` without `serialize()`/`deserialize()`
- [ ] Manual test gate executed and **user-approved** (per `.skills/copilot_instructions.md` § Manual Test Gate)
- [ ] `docs/implementation_plan.md` §1 baseline (test counts, last commit hash) updated
- [ ] If a slice changes architecture, `docs/arc42/05_building_block_view.md` updated in the same commit

---

## 6. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| K8/K9/K11 break network parity (extracted controller misses a code path that was scene-tree-coupled) | Medium | High | Each slice has its own MT gate covering hot-seat **and** network mode. Reconnection acceptance test (Phase I7) re-run before merge. |
| `UIProjector` API growth in K1 introduces churn | Low | Medium | Confine to `UIIntent` struct fields; mark each new field with the slice that consumes it; remove unused fields if a slice is reverted. |
| AttackFlowExecutor (K14) leaks a side-effect that scene-side AE used to absorb | Medium | High | Pre-write `test_attack_flow_executor.gd` in K14a (paired) with the same FSM transition coverage as the existing integration tests, then port. |
| Save subsystem regression (K18) breaks the J5.5 per-mode checkpoint contract | Low | High | Re-run `tests/unit/test_save_game_manager*.gd` + MT-J.5.5 / J.6 / J.7 / J.8 / J.9 / J.10 stamps. |
| Slice creep (a "K8" PR ends up doing K8+K9+K10) | Medium | Medium | Strict 1-commit-per-slice rule; any slice exceeding +500/−500 LOC must be split. |

---

## 7. Documentation & Skill Updates (in scope)

These are part of Phase K, **not** out-of-scope follow-ups. Updates ride
inside the slice that triggers them.

| Document | Slice | Update |
|---|:---:|---|
| `.github/copilot-instructions.md` | K1 | Add `lint_phase_k.sh` to "Verify" step (§9 of workflow). |
| `.skills/refactoring_guidelines.md` | K1 | Append §11 with K-quantified targets and the controller-extraction template (≤ 600 LOC composition root). |
| `.skills/architecture_patterns.md` | K1 | Add explicit section on `UIProjector` being the only PlayMode-aware code path in non-autoload layers. Add the lint guard reference. |
| `.skills/copilot_instructions.md` | K1 | Add Phase K MT scenario template (hot-seat + network parity check). |
| `docs/arc42/05_building_block_view.md` | K8, K14, K19 | New component diagram nodes for ShipActivationController / AttackPanelController / AttackFlowExecutor. |
| `docs/arc42/11_risks_and_technical_debt.md` | K0, K19 | Add TD-15 (Phase K open) at start; mark resolved at K19. |
| `docs/implementation_plan.md` | every slice | §1 baseline, §2 phase status, §4 open topics. |
| `docs/refactoring_phase_k_plan.md` (this file) | every slice | tick the slice table; record the commit hash. |

---

## 8. Definition of Done (Phase K)

Phase K closes when **all** of the following hold:

1. `scripts/lint_phase_k.sh` exits 0 on a clean checkout of `master`.
2. [game_board.gd](../src/scenes/game_board/game_board.gd) ≤ 2 000 LOC.
3. [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) ≤ 1 500 LOC.
4. [game_manager.gd](../src/autoload/game_manager.gd) ≤ 1 500 LOC.
5. Every function in `src/core/`, `src/scenes/`, `src/autoload/` is ≤ 30 LOC and ≤ 3 nesting levels.
6. `tests/unit/test_interaction_flow.gd` and `tests/unit/test_ui_projector.gd` exist with > 20 asserts each.
7. Test baseline ≥ current (143 / 2 873 / 5 410), 0 failures.
8. `docs/arc42/05_building_block_view.md` reflects the post-K composition.
9. `docs/implementation_plan.md` §2 shows Phase K row complete.

After Phase K closes, the next phase order is: **G4.7 Spectator → G4.8
Reconnection runtime → G4.9 Turn Timers → Phase 10c**.

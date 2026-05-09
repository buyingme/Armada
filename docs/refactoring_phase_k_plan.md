# Refactoring Phase K — Presentation-Layer Hardening

> **Status:** IN PROGRESS — K0 through K13 complete; K14a committed (`454fd0e`), K14b implemented in working tree.
> **Drafted:** 2026-05-08
> **Refined:** 2026-05-09 (deeper audit; UIIntent extension dropped — see §3.1c).
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
| Phase I rule violations | **13** modal-authority `if PlayMode.is_network()` / `is_hot_seat()` branches across 5 files in `src/scenes/game_board/` (rule §7 of `.github/copilot-instructions.md`); a further 10 session-mode discriminators are allow-listed — see §3.1 |
| Function-size / nesting drift | ~15 functions > 30 LOC, ~8 with > 3-level nesting (worst: `_attack_exec_begin_sequence` ~75 LOC / 5 levels) |
| Test gaps on Phase-I primitives | No dedicated `test_interaction_flow.gd`; `UIProjector` projection paths under-asserted |

The J11 navigate-token bug (yaw bonus surviving dial→token convert) was an
early symptom of category 1: state cached in a ~3 000-LOC scene class drifted
out of sync with a domain mutation. Fixing it after the fact required threading
a new helper through the controller. The next feature in the same area (e.g.
turn timers triggering forced-pass) will have the same exposure.

This plan is bounded, mechanical, and **fully covered by the existing test
suite (144 scripts / 2 897 tests / 5 484 asserts / 0 failures)**. It introduces
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
(e.g. "is this a host?", "is this a peer with a remote?"). They are
*not* "who can act" / modal-authority decisions and are intrinsic to
the deployment topology. The lint script treats these files (or
specific marked sites) as allow-listed:

| File | Line | Purpose |
|------|-----:|---|
| [save_game_dialog.gd](../src/ui/save/save_game_dialog.gd) | 270 | Network-client cannot save (defense in depth UI). |
| [load_game_dialog.gd](../src/ui/save/load_game_dialog.gd) | 371, 496 | Network-row enable/disable based on host session presence. |
| [game_menu_modal.gd](../src/ui/save/game_menu_modal.gd) | 401 | ESC menu button visibility (host vs client). |
| [lobby_room.gd](../src/scenes/lobby/lobby_room.gd) | 365 | Lobby is network-only by definition. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 889 | `_on_active_player_changed` dispatcher — hot-seat path builds handoff overlay + rotates camera; network path builds "waiting" UI + locks camera. The two flows are fundamentally different *content*, not "who is allowed to interact". |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1072 | `apply_remote_immediate_choice` is by definition a network-only concept (there is no "remote peer" in hot-seat). |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1091 | Modal-lifecycle dispatcher — Phase I migrated network to projection-driven modal lifecycle but **left hot-seat on direct callbacks**. Removing this branch would require migrating hot-seat to projection-driven modals (Phase L candidate — see §3.1d). |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1325 | `_handle_command_dial_dropped` uses sentinel `-1` only in network mode. May be revisited in K12 but not as part of K-G1. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1334 | `_submit_network_activation_step` is network-only by name and purpose (submits an `advance_activation_step` command for remote-peer sync). Hot-seat has no remote peer. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 1508 | Sequence-button origin — hot-seat opens locally, network drives via interaction state. Same architectural reason as line 1091. |
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 2138 | Displacement-modal origin — hot-seat opens directly, network opens via projection (Phase I6b-4c OV-002 fix). Same architectural reason as line 1091. |

#### 3.1b Targeted for removal in K (interaction-flow / modal-authority)

| File | Line(s) | Slice | Resolution |
|------|---------|:-----:|---|
| [game_board.gd](../src/scenes/game_board/game_board.gd) | 892 | K2 | Dead defensive guard (`if not PlayMode.is_hot_seat(): return` after the `is_network()` early-return at 891 — unreachable given the 2-mode enum). Delete. |
| [command_phase_controller.gd](../src/scenes/game_board/command_phase_controller.gd) | 165, 167 | K3 | `_build_player_order` enqueues ships for the seat that should be assigning dials. Rewritten to branch on `NetworkManager.get_local_player_index() >= 0` (the value that actually determines the queue) instead of reading `PlayMode` — same conceptual axis, no projector needed. |
| [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) | 1033, 1050, 1244, 1394, 2045, 2054, 2212 | K4 | Panel read-only flag, immediate-choice modal dispatch, and camera-rotate guards. All seven branches replaced with `NetworkManager.get_local_player_index()` comparisons (same conceptual axis as K3). Site `:2054` was a redundant `is_hot_seat()` guard after the network early-return at `:2045` — reduced to `if _camera:`. K1's `seat_controls_camera()` is not used here — its "true in network" semantic targets per-peer camera ownership, while these sites need the inverse "is this the hot-seat shared-camera case?". |
| [squadron_phase_controller.gd](../src/scenes/game_board/squadron_phase_controller.gd) | 378, 495 | K6 | Network-only side-effect dispatchers around squadron move commit: passive-peer modal advance after a remote `move_squadron`, and the zero-distance skip-move that informs the remote peer of an activation that ended without a real move. Both replaced with `NetworkManager.get_local_player_index()` comparisons (hot-seat returns -1) — same axis as K3/K4/K5. The original plan’s `intent.is_interactive` framing did not match the actual semantics (these are session-mode dispatchers, not modal-interactivity decisions). |
| [displacement_controller.gd](../src/scenes/game_board/displacement_controller.gd) | 124, 342 | K5 | Camera-rotation gating around squadron-displacement: hot-seat shares one camera so the controller rotates to the squadron-owner perspective; in network play each peer is already pinned to its own viewer. Both branches replaced with `NetworkManager.get_local_player_index() >= 0` (network) — same conceptual axis as K3/K4. The original plan's `intent.modal_kind == DISPLACEMENT` framing did not match the actual branch semantics (camera rotation, not modal authority). |

**Total to remove in K: 13 branches across 5 files.** (Down from 18 after the
K2 audit reclassified 5 game_board sites to §3.1a as session-mode
dispatchers — see §3.1d.)

#### 3.1d Out of scope for K — Phase L candidate

The Phase I migration of UI-flow state to `GameState.interaction_flow`
deliberately stopped short of converting **hot-seat** modal lifecycle to
the same projection-driven model used by network. In hot-seat, modals
are still opened by direct callbacks (e.g. `_show_activation_sequence_button`
at line 1508, `_displacement_controller.start()` at line 2138). Network
opens the same modals via `_on_command_executed_project_ui` reading the
flow.

Migrating hot-seat to also use projection-driven modal lifecycle would
collapse 4 of the 5 reclassified branches (1091, 1508, 2138, and parts
of 889) into a single uniform code path. This is non-trivial — the
`SHIP_ACTIVATION` / `SQUADRON_ACTIVATION` / `DISPLACEMENT` flows would
all need their hot-seat call sites refactored, and the activation-modal
"sequence button" semantic (which is hot-seat-specific UI affordance)
would need a network-side equivalent or an explicit suppression in the
projection.

**Recommended as Phase L** (post-K, post-G4.7-9). Out of scope for the
bounded mechanical Phase K.

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

### 3.5 Lint guards (K7)

New [scripts/lint_phase_k.sh](../scripts/lint_phase_k.sh): scans
`src/scenes/` and `src/ui/` for `if PlayMode.is_network()` / `is_hot_seat()`
branches and fails unless every hit is within ±8 lines of a
`# Phase K allow-list:` marker comment.  Pure comment lines are skipped.
The ±8-line window accommodates multi-line `if`-conditions where the
marker block sits above the boolean chain.

Run manually before every presentation-layer commit:

```bash
./scripts/lint_phase_k.sh
```

Non-zero exit on any un-marked branch.  Recommended pre-commit hook:

```bash
#!/usr/bin/env bash
exec ./scripts/lint_phase_k.sh
```

---

## 4. Slice Plan

Each slice = one commit (or a tight pair: implementation + tests). Every slice
ends in green tests, green import, and a manual-test gate when behaviour is
observable. Numbering matches the eventual phase-status table row.

| Slice | Scope | Risk | LOC delta | MT? |
|------:|---|---|---:|:---:|
| **K0** | Audit snapshot frozen — copy this plan into the repo, append §J11 row to implementation_plan §5.7. **No code changes.** Committed `664d368`. Refined 2026-05-09 with deeper audit (28 → 18 sites; one new UIIntent field instead of three). | trivial | 0 | no |
| **K1** | Add `PlayMode.seat_controls_camera(active_player, local_player) -> bool` static helper in [play_mode.gd](../src/autoload/play_mode.gd). Add unit tests for it (≥ 4 asserts: network always true; hot-seat active-seat true; hot-seat non-active false; hot-seat invalid params). **No UIProjector changes** (`src/core/` cannot read PlayMode). | low | +30 / 0 | no |
| **K2** | Delete dead defensive guard at game_board.gd:892 (unreachable given 2-mode enum). Add `# Phase K allow-list: session-mode dispatcher — see plan §3.1a` markers to lines 889, 1072, 1091, 1325, 1508, 2138 with brief rationale comments. **No converge of `_on_active_player_changed` paths** — see §3.1d (deferred to Phase L). | low | +30 / -3 | yes |
| **K3** | Replace 2 branches in [command_phase_controller.gd](../src/scenes/game_board/command_phase_controller.gd) (lines 165 / 167). `_build_player_order` rewritten to branch on `NetworkManager.get_local_player_index() >= 0` (returns -1 in hot-seat). | low | +12 / -8 | yes |
| **K4** | Replace 7 branches in [attack_executor.gd](../src/scenes/game_board/attack_executor.gd) (lines 1033, 1050, 1244, 1394, 2045, 2054, 2212). All seven became `NetworkManager.get_local_player_index()` comparisons; site `:2054` was a dead `is_hot_seat()` guard reduced to `if _camera:`. | medium | +30 / -10 | yes |
| **K5** | Replace 2 branches in [displacement_controller.gd](../src/scenes/game_board/displacement_controller.gd) (lines 124, 342). Both became `NetworkManager.get_local_player_index() >= 0` comparisons (same axis as K3/K4) — the branches gate camera rotation around squadron displacement, not modal authority. Committed `4b20607`. | low | +18 / -10 | yes |
| **K6** | Replace 2 branches in [squadron_phase_controller.gd](../src/scenes/game_board/squadron_phase_controller.gd) (lines 378, 495). Both became `NetworkManager.get_local_player_index()` comparisons — same axis as K3/K4/K5; the branches gate network-only side effects (passive-peer modal advance, skip-move broadcast), not modal authority. Committed `67885b1`. | low | +18 / -10 | yes |
| **K7** | Land lint script [scripts/lint_phase_k.sh](../scripts/lint_phase_k.sh). Forbids `if PlayMode.is_network()` / `is_hot_seat()` in `src/scenes/` and `src/ui/` unless a `# Phase K allow-list:` marker appears within ±8 lines. Allow-list inventory matches §3.1a exactly (11 sites: 6 in game_board, 1 lobby_room, 1 game_menu_modal, 1 save_game_dialog, 2 load_game_dialog). Markers added to the 5 sites that did not already carry one. Committed `<pending>`. | low | +90 / -5 | no |
| **K8** | Extract `ShipActivationController` from game_board.gd (dial drag + activation modal + maneuver entry). Move ~400 LOC. Split into K8a/K8b/K8c sub-slices below to keep diffs reviewable. | high | +450 / −400 | yes |
| **K8a** | First sub-slice: extract activation-modal lifecycle (open/close/mirror/sync), dial-drop entry points (`_on_dial_ship_activated`, `_on_dial_token_converted`), Crew Panic BEFORE_REVEAL_DIAL choice modal + token-overflow defer, and projection-driven open/close + step-sync helpers into [`ShipActivationController`](../src/scenes/game_board/ship_activation_controller.gd) (Node, ~660 LOC). Maneuver execute / overlap resolution / step routing remain on game_board.gd until K8b. game_board.gd: 3111 → 2678 LOC. Committed `f37ec18`. | high | +740 / −511 | yes |
| **K8b** | Move maneuver execute + overlap resolution + step handlers (`_on_attack_step_entered`, `_on_repair_step_entered`, `_on_squadron_step_entered`, `_on_squadron_step_skipped`, `_on_squadron_command_done`, `_on_repair_done`, `_on_attack_exec_completed`, `_on_attack_exec_cancelled`, `_on_activation_sequence_requested`, `_on_maneuver_step_entered`, `_on_execute_maneuver`, `_resolve_*_hook`, `_show_end_activation_after_maneuver`, `_build_other_ship_bases`, `_apply_overlap_damage`, `_emit_overlap_signals`, `_get_other_ship_token`, `_find_displaced_squadrons`) onto `ShipActivationController` and have the controller own the activation-modal / repair-panel / show-activation-button / attack-executor / squadron-phase-controller / displacement-controller signal connections. game_board.gd: 2678 → 2134 LOC; ship_activation_controller.gd: 658 → 1282 LOC. Committed `27bfdaf`. | high | +630 / −560 | yes |
| **K8c** | (folded into K8a) Crew Panic + token-overflow modal flow extraction. | — | — | — |
| **K9** | Extract `AttackPanelController` from game_board.gd. Owns the read-only [`AttackPanelMirror`](../src/ui/attack_panel_mirror.gd) sync (`sync_mirror_from_flow`), the attacker-side defender-response routing into `AttackExecutor` (`react_to_command` — `commit_defense` / `select_evade_die` / `select_redirect_zone` / `redirect_done` / `resolve_immediate_effect`), and the Attack Simulator toolbar / keyboard toggle (`_on_attack_simulator_requested`). game_board.gd: 2134 → 2054 LOC; attack_panel_controller.gd: 0 → 159 LOC. Committed `108305f`. | high | +160 / −80 | yes |
| **K10** | Extract `DebugBoardController` from game_board.gd (F-key debug damage, replay save trigger). Move ~150 LOC. Folded into the existing `DebugController` instead of a new class: Shift+D table, targeting state, input handlers, damage / immediate-effect modals, and the `debug_deal_damage` reactor moved over; `game_board.gd` keeps thin delegation. game_board.gd: 2054 → 1715 LOC; debug_controller.gd: 180 → 569 LOC. Committed `9a1f763`. | medium | +389 / −339 | yes |
| **K11** | Extract `ToolOverlayController` from game_board.gd (maneuver/range/targeting overlay). Move ~200 LOC. New controller owns the three sub-controllers, the M / R / T / A keyboard shortcuts, the toolbar request handlers, Escape routing, and the dismiss-other-tools coordination. game_board.gd: 1714 → 1598 LOC; tool_overlay_controller.gd: 0 → 244 LOC. Committed `ef2c84e`. | high | +287 / −158 | yes |
| **K12** | Introduce `CommandRouterAdapter` — single subscription to `EventBus.command_executed` that calls `UIProjector.project()` and routes to controllers. Removes the giant `_on_command_executed_project_ui` switch. | high | +180 / −100 | yes |
| **K13** | Function-size cleanup pass on what remains in game_board.gd. Landed as helper extraction + dispatch simplification in-place (no new controller/class extraction); all game_board functions now <= 30 LOC. Committed `cf29d8f`. | medium | +276 / -289 | no |
| **K14** | Extract `AttackFlowExecutor` (RefCounted) into `src/core/combat/`. K14a committed `454fd0e`: moved attack-flow payload builders (`compute_attack_identity_patch`, clear-target patch) into core helper, routed `attack_executor.gd` to delegate these builders, and added `test_attack_flow_executor.gd` with singleton-state isolation hooks. K14b is implemented in working tree: moved attack-state init/reset/roll parsing/defense payload builders into the core helper and delegated corresponding `attack_executor.gd` call sites; tests expanded and green. | high | +900 / −800 | yes |
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

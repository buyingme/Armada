# Progress Summary

> Star Wars: Armada — Digital Edition
> Last updated: 2026-05-01 (Phase I6b-3 R3 — defender peer drives Evade die selection via `SelectEvadeDieCommand`)
> Archived originals: `docs/old/implementation_plan.md`, `docs/old/refactoring_plan.md`, `docs/old/test_plan_manual.md`

---

## Current Baseline

| Metric | Value |
|--------|-------|
| GUT test scripts | 130 |
| GUT tests | 2 701 |
| GUT asserts | 5 039 |
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
| **I** | **Interaction-Flow as Domain State** | **🔄 in progress** | `InteractionFlow` field on `GameState`; `AttackFlowFSM` extracted; `UIProjector` replaces `is_network()` branches; deletes legacy interaction-state RPC. Plan: `docs/refactoring_phase_i_plan.md`. ~14 days, 7 sub-steps. **I0 ✅** inventory + freeze lint. **I1 ✅** `InteractionFlow` type + `GameState.interaction_flow` + `StateFilter` rule (2 666 tests). **I2 ✅** mirrored flow into 7 commands (advance_phase, activate_ship, convert_dial_to_token, execute_maneuver, end_activation, activate_squadron, advance_activation_step) + invariant test (2 677 tests, MT-PHI.01 passed 2026-04-26). **I3 ✅** `AttackFlowFSM` + interaction_flow.payload publishing at 5 transition sites (range_band, dice_pool, dice_results, locked_tokens, modified_damage, defender_player, final_damage, chooser, card_title); +39 unit tests; LOC target for `attack_executor.gd` deferred (no game logic moved — moving combat mid-Phase-I is higher-risk than acceptable; data is exposed for I4/I6). **I4 ✅** `UIProjector` HUD pilot — `src/core/network/ui_projector.gd` + `UIIntent`; wired to `CommandProcessor.command_executed` in `game_board.gd`; +10 unit tests; MT-PHI.04 passed 2026-04-26. **I5 ✅** sidebar / activation modal / squadron modal projected from `interaction_flow` via `UIProjector`; passive-peer modal lifecycle (open/select/move/handoff) mirrored on remote clients; round-2+ Command Phase opens dial picker on client; speculative round-1 picker closed on `command_phase_complete` (no out-of-phase `assign_dials`). Fix log I5b-1…5: see `docs/modal_timing_diagrams.md`. 132 scripts / 2 726 tests / 5 066 asserts; MT-PHI.05/05b passed 2026-04-27. **I6a ✅** `game_board.gd` no longer subscribes to `EventBus.interaction_state_changed`; HUD + ship-activation sub-step + modal lifecycle all read from `GameState.interaction_flow` after `command_executed`. Added SQUADRON_STEP/REPAIR_STEP/ATTACK_STEP/ACTIVATION_DONE to `Constants.InteractionStep` so the I2 mirror is complete. Mirror open call moved into `_on_remote_ship_activated` (after ctx setup) so passive peer reliably opens activation modal. 132 / 2 726 / 5 070; MT-PHI.06a passed 2026-04-28 (commit `e288fa9`). **I6b 🔄** *Slice 1* — `UIProjector.UIIntent` extended with `flow_type`, `step_id`, `modal_kind` (new `Constants.ModalKind` enum) and deep-copied `payload`; covers all attack sub-steps. +10 projector tests. *Slice 2* — `AttackFlowFSM` payload at DEFENSE_TOKENS now publishes `defender_ship_index`, `defender_speed`, `defender_zone` so the passive client can resolve which local `ShipInstance` is being attacked and what its speed/hit zone is, without a host-side `AttackState`. Pure additive (no UI behavior change). 132 / 2 736 / 5 104. **Defender defense-modal mirror is deferred to a dedicated slice 3** — investigation showed the host-side panel uses a multi-toggle + Commit-Defense flow with follow-on Brace/Evade/Redirect interactives that can't be mirrored from a single `defense_token_selected` signal; needs a controller-agnostic refactor of the defense step before NW-006 closes. Legacy producer + RPC kept alive until I6c. **I6c ✅** legacy parallel channel deleted in full — removed `src/core/network/network_interaction_state.gd`, `EventBus.interaction_state_changed`, `NetworkManager.broadcast_interaction_state` / `_receive_interaction_state` / `interaction_state_received` / `_latest_interaction_state` / `get_latest_interaction_state`, and `GameManager._publish_interaction_state_for_command` / `_broadcast_interaction_step` / `_on_interaction_state_received` / `_apply_interaction_state_if_ready` / `_flush_pending_interaction_states` plus the `_last_applied_command_seq` / `_last_interaction_version` / `_pending_interaction_by_version` ordering buffer. Deleted `tests/unit/test_network_interaction_state.gd` and `tests/unit/test_game_manager_interaction_state.gd`; updated `test_phase_i2_invariant.gd` header. 130 scripts / 2 701 tests / 5 039 asserts; MT-PHI.06c passed 2026-04-28. **I6d 🔄 partial** — first slice: `_is_local_activation_modal_controller()` now reads `interaction_flow.controller_player` directly (via the same projection model `UIProjector` uses). Removed dead `_interaction_controller_player` / `_has_interaction_controller` fields and their writes inside the command-executed callback. `is_network()` branches in `game_board.gd`: 10 → 9 (target ≤ 3). Initial commit broke hot-seat with `gs.active_player` (field lives on `GameManager`, not `GameState`); fixed before commit. The remaining 9 branches each guard divergent host/client logic (config source, host-only command submission, network-only modal lifecycle awaiting server result, hot-seat dial-token convert sequence button, etc.) and require relocating that logic out of `game_board.gd`. Scheduled as I6e after I6b-3. 130 / 2 701 / 5 039; MT-PHI.06d passed 2026-04-28. **I6b-3 🔄 slice A** — read-only `DefenseMirrorPanel` shown on the defender's peer in network mode at `ATTACK_DEFENSE_TOKENS` step. Reads `defender_ship_index` / `defender_zone` / `modified_damage` / `locked_tokens` directly from `interaction_flow.payload` via `UIProjector.UIIntent`; gated by `intent.controller_player == local && !attack_executor.is_in_exec_mode()` so neither the attacker peer nor hot-seat double-opens. Pure additive; no behavioural change for the existing `AttackSimPanel` defense flow on the attacker peer. Token toggling, Commit-Defense, Brace/Evade/Redirect interactives still owned by the attacker peer's `AttackExecutor`; slices B–F migrate state and authority. 131 / 2 712 / 5 057; MT-PHI.06b3-A passed 2026-04-28. **I6b-3 slice A follow-up** — first MT-PHI.06b3-A network run revealed the defender mirror never opened on the client peer: I6c's deletion of `NetworkInteractionState` had implicitly removed the replication of every `AttackFlowFSM.advance` / `patch_payload` / `begin` / `end` mutation (the FSM is driven from host-only `attack_executor.gd` and writes `GameState.interaction_flow` directly). Fix: `PublishAttackFlowCommand` (`src/core/commands/publish_attack_flow_command.gd`) — a pure flow-snapshot command (no game-logic side effects) submitted via `GameManager.submit_publish_attack_flow` after every FSM mutation; `_fsm_advance` / `_fsm_patch_payload` / `_publish_flow_snapshot` helpers in `AttackExecutor` route all 12 call sites + the two `begin` and the `end` through the canonical command channel. Hot-seat early-returns (`PlayMode.is_network()` guard). +1 script / +4 tests; full suite 132 / 2 716 / 5 067 (one pre-existing failure in `test_learning_scenario_setup` is from an unrelated user WIP edit to `Resources/Game_Components/scenarios/learning_scenario.json`). MT-PHI.06b3-A re-run pending. Squadron-overlap-displacement controller-authority bug surfaced during MT (modal opens on active player instead of displaced-squadron owner per OV-002); pre-existing — added as I6b-4 in `docs/refactoring_phase_i_plan.md` §I6 / `docs/open_topics.md`. **I6b-3 redesign (2026-04-29)** — slice A approach (separate read-only `DefenseMirrorPanel`) abandoned after design review: defender still had to click tokens on the attacker's screen, and two peers showed visually different panels for the same game state. New design: render the **same `AttackSimPanel`** on both peers, populated from `interaction_flow.payload`; interactivity gated per sub-step by `controller_player` (attacker for declare/roll/modify; defender for defense-tokens / evade target / redirect zone; chooser for critical-choice); defender input travels back via commands. Re-sliced as R1 (mirror panel read-only) → R2 (defender-controlled defense tokens, closes NW-006) → R3 (evade target) → R4 (redirect zone) → R5 (critical-choice chooser) → R6 (attacker-side read-only during defender sub-steps) → R7 (delete `DefenseMirrorPanel`, dead branches). `PublishAttackFlowCommand` retained as the replication channel. Implementation pending; this commit lands the design pivot in `docs/refactoring_phase_i_plan.md`, `docs/open_topics.md`, and this file. **R1a** — at the existing declare-site `_fsm_patch_payload` in `attack_executor.gd`, the attack identity (attacker kind / ship-or-squadron index / name / zone / zone-name; target kind / ship-or-squadron index / defender name / defender zone) is now published into `interaction_flow.payload` via `_compute_attack_identity_patch()`. Pure additive, no UI work, no game-logic side effects, no new commands. 132 / 2 716 / 5 067 (unchanged; only pre-existing scenario-WIP failure). MT-PHI.06b3-R1a pending. **I6b-3 R2 ✅** — defender peer is now interactive at `ATTACK_DEFENSE_TOKENS`. New `CommitDefenseCommand` (Tier 13, marker only) submitted by the defender peer when **Commit Defense** is pressed on `AttackPanelMirror`; the attacker peer's `AttackExecutor` reacts on `command_executed` and runs the existing spend pipeline. `AttackExecutor._attack_exec_start_defense` now publishes `defense_tokens` snapshot in `interaction_flow.payload` so the mirror can render the interactive section without consulting the host's `AttackState`; `apply_defender_commit(selected: Array[int])` is exposed for `game_board.gd` to call when `commit_defense` is broadcast. Network-side relaxation: `NetworkManager._submit_command_to_server` permits the attacker peer to author `spend_defense_token` / `select_redirect_zone` / `resolve_damage` against the defender's `player_index` during an active attack flow (read from `flow.payload.attacker_player`, not `flow.controller_player` which alternates per step). MT-driven follow-ups: (a) `_handle_remote_resolve_damage` re-emits `ship_shields_changed` / `ship_hull_changed` / `ship_defense_token_changed` so the client's shield pips & hull readout update; (b) `AttackFlowFSM.restart_for_next_attack(gs)` resets the FSM to IDLE→DECLARE between attacks (squadron-loop + 2-hull-zone) so subsequent advances aren't silently rejected by the legal-transition table, leaving the published flow stuck at `RESOLVE_DAMAGE`. Closes NW-006. 133 / 2 734 / 5 110 (1 pre-existing failure: scenario-WIP). MT-PHI.06b3-R2 passed 2026-04-30. **I6b-3 R2 follow-ups (commit `50a701b`, 2026-05-01)** — passive-peer (host-as-defender) damage visuals were missing because `_on_network_command_result`'s host-side gate (`cmd.player_index != local`) skipped `_handle_remote_command_effects` for client-authored `resolve_damage` whose `player_index` equals the defender's owner (the host). Fix: `NetworkManager._submit_command_to_server` tags `result["__remote_authored"] = true` on broadcast for any peer-authored command; `GameManager._on_network_command_result` runs the side-effect handler when either `player_index` differs or the flag is set. Also: `_handle_remote_resolve_damage` now re-emits `damage_card_dealt(ship, null, false)` (rebuilds `ShipCardPanel` damage column) and `damage_summary_requested` (triggers `DamageSummaryOverlay` close-up) on the passive peer; `_find_ship_from_command` prefers `payload["owner_player"]`; `AttackPanelMirror` caches dice-pool / dice-results to avoid stale rerenders, hides the dice strip + count on the next-attack transition; `AttackExecutor._publish_clear_target_patch` zeroes `dice_pool` / `dice_results` so the mirror does not re-render stale dice. Tests unchanged (133 / 2734 / 5109; same 1 pre-existing scenario-WIP failure). MT validated: host-as-defender single + multi card attacks (column refresh + close-up), dice cleanup on consecutive attacks (2-hull-zone + squadron loop), host-as-attacker regression. **I6b-3 R3 ✅ (commit pending)** — defender peer is now interactive at the Evade die-selection sub-step. New `SelectEvadeDieCommand` (Tier 13, marker only; payload `ship_index` + `die_index`) submitted by the defender peer when a die is clicked on the `AttackPanelMirror`'s evade section; the attacker peer's `AttackExecutor` reacts on `command_executed` and runs the existing `_apply_evade_remove` (long range) / `_apply_evade_reroll` (medium / close range) pipeline. `_attack_exec_start_evade()` now publishes `evade_active` / `evade_range_band` into `interaction_flow.payload` (cleared on apply and on the next-attack `_publish_clear_target_patch`). `AttackPanelMirror._apply_evade_section(payload)` opens the panel's `show_evade_die_selection(range_band)` and connects `evade_die_confirmed` once when the flag flips on; resets the section flag when it flips off so a subsequent evade re-opens cleanly. Attacker peer's local panel does not open the interactive evade section in network mode (mirrors the R2 defense-section gate). `GameBoard._on_command_executed_project_ui` reacts to `select_evade_die` by calling `_attack_executor.apply_defender_evade_die(die_index)`. 133 / 2741 / 5124 (1 pre-existing scenario-WIP failure). MT-PHI.06b3-R3 ✅ passed 2026-05-01. R3 follow-ups landed in the same slice: (a) `apply_defender_evade_die` now applies remove/reroll **before** publishing so a single `_fsm_patch_payload` broadcasts `evade_active=false` together with the mutated `dice_results` + new `modified_damage`; (b) `AttackPanelMirror`'s dice cache is now content-based (`_last_dice_results_payload: Array`) instead of size-only — a reroll mutates a die's face without changing array size, so the size cache was suppressing the redraw; (c) new `_apply_modified_damage_update(payload)` in the mirror refreshes the defense-section damage readout when an evade reroll mutates `modified_damage` mid-flight; (d) `AttackPanelMirror` is now hosted on its own `CanvasLayer` at layer **90** (matching `TargetSelector`'s real attack panel) so the dice strip + final modified attack result render **on top of** the `DamageSummaryOverlay` (layer 85) for the 1.2 s damage-info window — exactly like the hot-seat flow. **R4** (redirect zone) still owned by the attacker's panel — next slice. |

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

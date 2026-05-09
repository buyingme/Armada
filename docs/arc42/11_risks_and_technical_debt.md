# 11. Risks and Technical Debt

## 11.1 Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| R-1 | Rules complexity leads to implementation errors | High | High | Test-driven development, systematic rules extraction |
| R-2 | Godot Engine updates break compatibility | Low | Medium | Pin to Godot 4.5, test before upgrading |
| R-3 | Scope creep (too many features too early) | Medium | High | Clear prioritization, iterative development |
| R-4 | Performance issues with complex game states | Low | Medium | Profile early, optimize data structures |
| R-5 | UI/UX complexity for tabletop mechanics | Medium | Medium | Prototype UI early, iterate based on playtesting |
| R-6 | God-object files resist extension | High | High | Refactoring plan Phases A–I ✅. See `docs/implementation_plan.md`. |
| R-7 | Network-UI sync fragility (parallel RPC channel) | High | High | **Resolved** — Phase I promoted UI flow state into `GameState.interaction_flow`; legacy `NetworkInteractionState` channel deleted. |

## 11.2 Technical Debt

| ID | Description | Severity | Plan |
|----|-------------|----------|------|
| TD-1 | ~~Initial project setup — placeholder scenes and minimal UI~~ | ~~Low~~ | **Resolved** — full UI implemented. |
| TD-2 | No CI/CD pipeline yet | Medium | Set up GitHub Actions after refactoring. |
| TD-3 | ~~No data import pipeline from source rules~~ | ~~Medium~~ | **Resolved** — JSON-based card data with `AssetLoader`. |
| TD-4 | Functions exceeding 30-line guideline (95 functions across ~20 files) | Medium | Refactoring Phase A — extract private helpers within same file. |
| TD-5 | `UpgradeData` resource class unused in production code | Low | Placeholder for upgrade card features. Keep as-is until needed. |
| TD-6 | Reusable anchor-based panels may flash at inflated size for one frame before deferred layout correction | Low | Cosmetic only; `_request_deferred_layout()` pattern (ADR-011) corrects on next frame. |
| TD-7 | `game_board.gd` is **3 055 LOC** after Phases A–F. Composition root for the entire board scene; mixes activation orchestration, attack panel mounting, debug damage tooling, and tool overlay lifecycles. | **Medium** | Phase C: 7 controllers extracted. Phase F: ActivationContext (F1) + UIPanelManager (F3) extracted. Phase G complete: 26 command classes route all mutations through CommandProcessor. **Phase K (proposed)** will extract `ShipActivationController` / `AttackPanelController` / `DebugBoardController` / `ToolOverlayController` / `CommandRouterAdapter` to bring the file below 2 000 LOC. See [docs/refactoring_phase_k_plan.md](../refactoring_phase_k_plan.md). |
| TD-8 | ~~`attack_executor.gd` was 3 285 lines / 146 functions~~ | ~~High~~ | **Resolved** — Phase F4 extracted 4 RefCounted resolvers. Phase F5 extracted AttackState, TargetingListController, TargetSelector. AE reduced to 1 864 lines. **Note:** AE is now 2 475 LOC again (mirrored panels + Phase I integration). Phase K will extract `AttackFlowExecutor` (RefCounted) into `src/core/combat/` to bring the scene-side adapter below 1 500 LOC. |
| TD-15 | Presentation layer carries **9** `if PlayMode.is_network()` / `is_hot_seat()` branches in `src/scenes/` — Phase I rule §7 violations. Three god-object files: `game_board.gd` (3 055), `attack_executor.gd` (2 475), `game_manager.gd` (2 241). ~15 functions exceed the 30-LOC limit; ~8 nest deeper than 3 levels. No dedicated unit test for `InteractionFlow` or `UIProjector`. | **High** | Phase K (proposed 2026-05-08). Slice plan in [docs/refactoring_phase_k_plan.md](../refactoring_phase_k_plan.md). Goals: zero PlayMode branches in scenes/UI, file-size targets met, dedicated InteractionFlow + UIProjector tests, lint guard `scripts/lint_phase_k.sh` enforced. |
| TD-9 | `ship_card_panel.gd` is 1 407 lines — UI build + state sync + dial interaction + damage display | Medium | Refactoring Phase D3 — split into layout coordinator + entry builder + damage display. |
| TD-10 | `attack_sim_panel.gd` is 1 455 lines — monolithic `_build_ui()` (218 lines) | Medium | Refactoring Phases A1 + D1 — extract 12 `_build_<section>()` helpers, then UIStyleHelper. |
| TD-11 | ~~Missing `serialize()`/`deserialize()` on ShipInstance, SquadronInstance, DamageDeck, DamageCard, ShipActivationState~~ | ~~Medium~~ | **Resolved** — Phase E complete. All classes serializable. `SaveGameManager` autoload with F5/F8 debug keybinds. |
| TD-12 | ~~64 EventBus signals — risk of signal spaghetti as features grow~~ | ~~Medium~~ | **Resolved** — Phase E6 complete. 12 `#region` blocks group signals by domain. |
| TD-13 | All UI is procedurally built in GDScript (only 4 `.tscn` files) | Low | Workable but slower iteration; consider `.tscn` for new complex UI. |
| TD-14 | ~~UI flow state lives outside `GameState`; reconnection cannot reconstruct in-flight modals~~ | ~~High~~ | **Resolved** — Phase I (closed 2026-05-02). `GameState.interaction_flow` is serializable and replicates over `command_result`; `UIProjector` projects modal authority from filtered state. Reconnection acceptance gate at [tests/integration/test_reconnection_mid_attack.gd](../../tests/integration/test_reconnection_mid_attack.gd). |

## 11.3 Remaining Network Work (Phase G4.7+)

| Item | Status | Notes |
|------|--------|-------|
| G4.7 Spectator Mode | ⏳ pending | Both-players consent gate, omniscient view |
| G4.8 Reconnection runtime | ⏳ pending | Domain-side contract validated by Phase I7; runtime RPC pause/replay/timer not yet implemented |
| G4.9 Turn Timers | ⏳ pending | Server-enforced, forfeit on timeout, restart from auto-save |

> **Last audit:** 2026-05-08 — 143 scripts, 2 873 tests, 5 410 asserts, 0 failures.
> Architecture compliance, static typing, and doc comment coverage all PASS in core/.
> Phases A–I and J (J1–J11) complete. Phase K (presentation-layer hardening) **proposed** — see TD-15 and [docs/refactoring_phase_k_plan.md](../refactoring_phase_k_plan.md).

# 11. Risks and Technical Debt

## 11.1 Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| R-1 | Rules complexity leads to implementation errors | High | High | Test-driven development, systematic rules extraction, and the `.github/skills/rule-integration/SKILL.md` checklist for command/payload/UI parity. |
| R-2 | Godot Engine updates break compatibility | Low | Medium | Pin to Godot 4.5, test before upgrading |
| R-3 | Scope creep (too many features too early) | Medium | High | Clear prioritization, iterative development |
| R-4 | Performance issues with complex game states | Low | Medium | Profile early, optimize data structures |
| R-5 | UI/UX complexity for tabletop mechanics | Medium | Medium | Prototype UI early, iterate based on playtesting |
| R-6 | God-object files resist extension | High | High | Refactoring plan Phases A–I ✅. See `docs/implementation_plan.md`. |
| R-7 | Network-UI sync fragility (parallel RPC channel) | High | High | **Resolved** — Phase I promoted UI flow state into `GameState.interaction_flow`; legacy `NetworkInteractionState` channel deleted. |
| R-8 | Network replay command order is not deterministic across separate two-process ENet runs | High | Medium | Phase L0.5 gates network on host/client final-state-hash equality within the same run, keeps per-peer JSONL as diagnostics, and avoids committed network command/hash fixtures until a deterministic network pump exists. |

## 11.2 Technical Debt

| ID | Description | Severity | Plan |
|----|-------------|----------|------|
| TD-1 | ~~Initial project setup — placeholder scenes and minimal UI~~ | ~~Low~~ | **Resolved** — full UI implemented. |
| TD-2 | No CI/CD pipeline yet | Medium | Set up GitHub Actions after refactoring. |
| TD-3 | ~~No data import pipeline from source rules~~ | ~~Medium~~ | **Resolved** — JSON-based card data with `AssetLoader`. |
| TD-4 | Functions exceeding 30-line guideline (95 functions across ~20 files) | Medium | Refactoring Phase A — extract private helpers within same file. |
| TD-5 | `UpgradeData` resource class unused in production code | Low | Placeholder for upgrade card features. Keep as-is until needed. |
| TD-6 | Reusable anchor-based panels may flash at inflated size for one frame before deferred layout correction | Low | Cosmetic only; `_request_deferred_layout()` pattern (ADR-011) corrects on next frame. |
| TD-7 | ~~`game_board.gd` was 3 055 LOC after Phases A–F~~ | ~~Medium~~ | **Resolved by Phase K** — board composition root reduced to 1 464 LOC and stays below the 2 000 LOC ceiling. See [docs/refactoring_phase_k_plan.md](../refactoring_phase_k_plan.md). |
| TD-8 | `attack_executor.gd` remains above the Phase K scene-adapter ceiling after mirrored panels and Phase I integration. | High | Current size: 2 479 LOC. Keep new attack behavior in focused core/presentation helpers until a later extraction brings the adapter below 1 500 LOC. |
| TD-15 | Phase K guardrails are enforced, but residual allow-listed presentation branches and oversized legacy managers remain. | Medium | `scripts/lint_phase_k.sh` reports 0 violations and 7 explicit allow-listed branches after L3. Current tracked sizes: `game_board.gd` 1 462, `attack_executor.gd` 2 479, `game_manager.gd` 2 271, `save_game_manager.gd` 1 061, `command_router_adapter.gd` 100, `ui_projector.gd` 182, `modal_router.gd` 248, `ship_activation_controller.gd` 1 449, `squadron_phase_controller.gd` 822. Phase L/M work must add new behavior through focused helpers and keep modal/network decisions projected through `UIProjector`. |
| TD-9 | `ship_card_panel.gd` is 1 407 lines — UI build + state sync + dial interaction + damage display | Medium | Refactoring Phase D3 — split into layout coordinator + entry builder + damage display. |
| TD-10 | `attack_sim_panel.gd` is 1 455 lines — monolithic `_build_ui()` (218 lines) | Medium | Refactoring Phases A1 + D1 — extract 12 `_build_<section>()` helpers, then UIStyleHelper. |
| TD-11 | ~~Missing `serialize()`/`deserialize()` on ShipInstance, SquadronInstance, DamageDeck, DamageCard, ShipActivationState~~ | ~~Medium~~ | **Resolved** — Phase E complete. All classes serializable. `SaveGameManager` autoload with F5/F8 debug keybinds. |
| TD-12 | ~~64 EventBus signals — risk of signal spaghetti as features grow~~ | ~~Medium~~ | **Resolved** — Phase E6 complete. 12 `#region` blocks group signals by domain. |
| TD-13 | All UI is procedurally built in GDScript (only 4 `.tscn` files) | Low | Workable but slower iteration; consider `.tscn` for new complex UI. |
| TD-14 | ~~UI flow state lives outside `GameState`; reconnection cannot reconstruct in-flight modals~~ | ~~High~~ | **Resolved** — Phase I (closed 2026-05-02). `GameState.interaction_flow` is serializable and replicates over `command_result`; `UIProjector` projects modal authority from filtered state. Reconnection acceptance gate at [tests/integration/test_reconnection_mid_attack.gd](../../tests/integration/test_reconnection_mid_attack.gd). |
| TD-16 | Network replay harness cannot yet use committed per-command or committed final-state network fixtures because real localhost packet timing can change valid command interleavings between runs. | Medium | Phase L0.5 uses the stable invariant available today: hot-seat committed trace/hash plus network host/client state-hash equality. Future deterministic transport/tick work can promote network to committed fixtures. |
| TD-17 | ~~`src/core/effects/rules/` is still flat after the first production rule.~~ | ~~Low~~ | **Resolved by M8** — source-first grouping adopted under [src/core/effects/rules/README.md](../../src/core/effects/rules/README.md) with damage-card ship rules in `damage_cards/ship/`. |

## 11.3 Remaining Network Work (Phase G4.7+)

| Item | Status | Notes |
|------|--------|-------|
| G4.7 Spectator Mode | ⏳ pending | Both-players consent gate, omniscient view |
| G4.8 Reconnection runtime | ⏳ pending | Domain-side contract validated by Phase I7; runtime RPC pause/replay/timer not yet implemented |
| G4.9 Turn Timers | ⏳ pending | Server-enforced, forfeit on timeout, restart from auto-save |

> **Last audit:** 2026-05-17 — Phase M7 Faulty Countermeasures rule migration completed with MT pass; rule-integration skill and source-first rule folder proposal added. Network replay gates on host/client state-hash equality rather than committed network fixtures.
> Architecture compliance, static typing, and doc comment coverage all PASS in core/.
> Phases A–I, J (J1–J11), and K complete. Phase L/M modal and replay hardening continues under [docs/refactoring_phase_lm_plan.md](../refactoring_phase_lm_plan.md).

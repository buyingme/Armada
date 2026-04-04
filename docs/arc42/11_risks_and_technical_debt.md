# 11. Risks and Technical Debt

## 11.1 Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| R-1 | Rules complexity leads to implementation errors | High | High | Test-driven development, systematic rules extraction |
| R-2 | Godot Engine updates break compatibility | Low | Medium | Pin to Godot 4.5, test before upgrading |
| R-3 | Scope creep (too many features too early) | Medium | High | Clear prioritization, iterative development |
| R-4 | Performance issues with complex game states | Low | Medium | Profile early, optimize data structures |
| R-5 | UI/UX complexity for tabletop mechanics | Medium | Medium | Prototype UI early, iterate based on playtesting |
| R-6 | God-object files resist extension | High | High | Planned refactoring before post-MVP features |

## 11.2 Technical Debt

| ID | Description | Severity | Plan |
|----|-------------|----------|------|
| TD-1 | ~~Initial project setup — placeholder scenes and minimal UI~~ | ~~Low~~ | **Resolved** — full UI implemented. |
| TD-2 | No CI/CD pipeline yet | Medium | Set up GitHub Actions after refactoring. |
| TD-3 | ~~No data import pipeline from source rules~~ | ~~Medium~~ | **Resolved** — JSON-based card data with `AssetLoader`. |
| TD-4 | Functions exceeding 30-line guideline (~50 functions across 6 files) | Medium | Refactoring Phase R1 — extract helpers, split God Objects. |
| TD-5 | `UpgradeData` resource class unused in production code | Low | Placeholder for upgrade card features. Keep as-is until needed. |
| TD-6 | Reusable anchor-based panels may flash at inflated size for one frame before deferred layout correction | Low | Cosmetic only; `_request_deferred_layout()` pattern (ADR-011) corrects on next frame. |
| TD-7 | `game_board.gd` is 3 390 lines / ~130 functions — classic God Object | **High** | Extract DeploymentController, ActivationController, SquadronPhaseController, DisplacementController, ToolController, UIFactory. |
| TD-8 | `attack_executor.gd` is 3 008 lines / ~100 functions — handles sim + execution + damage + defense + multi-attack | **High** | Split into AttackSimulator, AttackPipeline, DefenseResolver, DamageApplicator. |
| TD-9 | `ship_card_panel.gd` is 1 407 lines — UI build + state sync + dial interaction + damage display | Medium | Extract DamageCardDisplay, DialStackWidget, TokenColumnWidget. |
| TD-10 | `attack_sim_panel.gd` is 1 455 lines — monolithic `_build_ui()` (~250 lines) | Medium | Extract section builders into composable sub-panels. |
| TD-11 | Missing `serialize()`/`deserialize()` on ShipInstance and SquadronInstance blocks save/load | Medium | Add before saved-game feature. |
| TD-12 | 64 EventBus signals — risk of signal spaghetti as features grow | Medium | Group signals into domain-specific sub-buses or typed event objects. |
| TD-13 | All UI is procedurally built in GDScript (only 4 `.tscn` files) | Low | Workable but slower iteration; consider `.tscn` for new complex UI. |

> **Last audit:** MVP complete — 87 scripts, 1 645 tests, 1 644 passing.
> Architecture compliance, static typing, and doc comment coverage all PASS.

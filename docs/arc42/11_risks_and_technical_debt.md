# 11. Risks and Technical Debt

## 11.1 Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| R-1 | Rules complexity leads to implementation errors | High | High | Test-driven development, systematic rules extraction |
| R-2 | Godot Engine updates break compatibility | Low | Medium | Pin to Godot 4.5, test before upgrading |
| R-3 | Scope creep (too many features too early) | Medium | High | Clear prioritization, iterative development |
| R-4 | Performance issues with complex game states | Low | Medium | Profile early, optimize data structures |
| R-5 | UI/UX complexity for tabletop mechanics | Medium | Medium | Prototype UI early, iterate based on playtesting |
| R-6 | God-object files resist extension | High | High | Refactoring plan Phases A–F ✅. See `docs/refactoring_plan.md`. |

## 11.2 Technical Debt

| ID | Description | Severity | Plan |
|----|-------------|----------|------|
| TD-1 | ~~Initial project setup — placeholder scenes and minimal UI~~ | ~~Low~~ | **Resolved** — full UI implemented. |
| TD-2 | No CI/CD pipeline yet | Medium | Set up GitHub Actions after refactoring. |
| TD-3 | ~~No data import pipeline from source rules~~ | ~~Medium~~ | **Resolved** — JSON-based card data with `AssetLoader`. |
| TD-4 | Functions exceeding 30-line guideline (95 functions across ~20 files) | Medium | Refactoring Phase A — extract private helpers within same file. |
| TD-5 | `UpgradeData` resource class unused in production code | Low | Placeholder for upgrade card features. Keep as-is until needed. |
| TD-6 | Reusable anchor-based panels may flash at inflated size for one frame before deferred layout correction | Low | Cosmetic only; `_request_deferred_layout()` pattern (ADR-011) corrects on next frame. |
| TD-7 | `game_board.gd` was 3 390 lines — now 2 207 after Phases A–F. Still above 500-line target but remaining code is activation orchestration tightly coupled to its controllers. | **Medium** | Phase C: 7 controllers extracted. Phase F: ActivationContext (F1) + UIPanelManager (F3) extracted. Further reduction requires Command pattern (Phase G). |
| TD-8 | ~~`attack_executor.gd` was 3 285 lines / 146 functions~~ | ~~High~~ | **Resolved** — Phase F4 extracted 4 RefCounted resolvers (AttackTargetResolver, AttackDiceResolver, DefenseTokenResolver, DamageDealer). Phase F5 extracted AttackState, TargetingListController, TargetSelector. AE reduced to 1 864 lines. |
| TD-9 | `ship_card_panel.gd` is 1 407 lines — UI build + state sync + dial interaction + damage display | Medium | Refactoring Phase D3 — split into layout coordinator + entry builder + damage display. |
| TD-10 | `attack_sim_panel.gd` is 1 455 lines — monolithic `_build_ui()` (218 lines) | Medium | Refactoring Phases A1 + D1 — extract 12 `_build_<section>()` helpers, then UIStyleHelper. |
| TD-11 | ~~Missing `serialize()`/`deserialize()` on ShipInstance, SquadronInstance, DamageDeck, DamageCard, ShipActivationState~~ | ~~Medium~~ | **Resolved** — Phase E complete. All classes serializable. `SaveGameManager` autoload with F5/F8 debug keybinds. |
| TD-12 | ~~64 EventBus signals — risk of signal spaghetti as features grow~~ | ~~Medium~~ | **Resolved** — Phase E6 complete. 12 `#region` blocks group signals by domain. |
| TD-13 | All UI is procedurally built in GDScript (only 4 `.tscn` files) | Low | Workable but slower iteration; consider `.tscn` for new complex UI. |

> **Last audit:** Refactoring Phases A–F + H complete — 100 scripts, 2 032 tests, 3 552 asserts, all passing.
> Architecture compliance, static typing, and doc comment coverage all PASS.

# 11. Risks and Technical Debt

## 11.1 Risks

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| R-1 | Rules complexity leads to implementation errors | High | High | Test-driven development, systematic rules extraction |
| R-2 | Godot Engine updates break compatibility | Low | Medium | Pin to Godot 4.5, test before upgrading |
| R-3 | Scope creep (too many features too early) | Medium | High | Clear prioritization, iterative development |
| R-4 | Performance issues with complex game states | Low | Medium | Profile early, optimize data structures |
| R-5 | UI/UX complexity for tabletop mechanics | Medium | Medium | Prototype UI early, iterate based on playtesting |

## 11.2 Technical Debt

| ID | Description | Severity | Plan |
|----|-------------|----------|------|
| TD-1 | Initial project setup — placeholder scenes and minimal UI | Low | Will be replaced during UI implementation phase |
| TD-2 | No CI/CD pipeline yet | Medium | Set up GitHub Actions after initial development |
| TD-3 | No data import pipeline from source rules | Medium | Build JSON → Resource converter during data phase |
| TD-4 | Functions exceeding 30-line guideline (across ~25 files) | Medium | Growth during Phase 5a–9.5 (maneuver tool scene, activation modal, game board, attack executor). Most are UI construction or draw methods. Refactor incrementally when touched; extract helper methods where clarity improves. Not blocking — UI builders lose locality if over-decomposed. |
| TD-5 | `UpgradeData` resource class unused in production code | Low | Placeholder for Phase 7 (Upgrade Cards). Keep as-is until needed. |
| TD-6 | Reusable anchor-based panels may flash at inflated size for one frame before deferred layout correction | Low | Cosmetic only — the `_request_deferred_layout()` pattern (ADR-011) corrects sizing on the next frame. If noticeable, mitigate by creating hidden sections lazily instead of pre-building them in `_build_ui()`. |
| TD-7 | `game_board.gd` is ~3087 lines with 147 functions | High | Largest single file by far. AttackExecutor extraction helped but game_board still handles placement, movement, activation wiring, squadron command, displacement, camera, debug controls. Plan: extract PlacementController, ActivationController, CameraController as dedicated Node children. |

> **Note:** This section will be updated as the project evolves.
> **Last audit:** Phase 9.5 / Phase 5b-2 complete — 87 scripts, 1628 tests, 1627 passing. Architecture compliance, static typing, and doc comment coverage all PASS.

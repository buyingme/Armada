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
| TD-4 | 59 functions exceed the 30-line guideline (across ~20 files) | Medium | Growth from 48→59 during Phase 5a/5b (maneuver tool scene, activation modal, ship token drawing). Most are UI construction or draw methods. Refactor incrementally when touched; extract helper methods where clarity improves. Not blocking — UI builders lose locality if over-decomposed. |
| TD-5 | `UpgradeData` resource class unused in production code | Low | Placeholder for Phase 7 (Upgrade Cards). Keep as-is until needed. |

> **Note:** This section will be updated as the project evolves.
> **Last audit:** Phase 5b complete — 56 src files (12,659 lines), 50 test files (10,094 lines), 847 tests passing across 50 scripts, 1,635 asserts. Architecture compliance, static typing, and doc comment coverage all PASS.

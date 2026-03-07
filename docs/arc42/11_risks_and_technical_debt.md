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

> **Note:** This section will be updated as the project evolves.

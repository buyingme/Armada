# Architecture Roadmap

This document is the single entry point for architecture transformation work.
It coordinates current discovery outputs, owner decisions, contracts, tests, and
Codex guardrails during the migration and clarification period.

This roadmap does not define the future architecture by itself. It tracks the
work needed to make architecture decisions safely.

## Cross-Reference Identifier System

| Prefix | Meaning | Owner document |
| --- | --- | --- |
| `RG-xxx` | Reality Gap | `docs/REALITY_GAP_REGISTER.md` |
| `BC-xxx` | Boundary Candidate | `docs/ARCHITECTURE_BOUNDARY_CANDIDATES.md` |
| `AT-xxx` | Architecture Task | This roadmap |
| `ADR-xxx` | Architecture Decision | Future ADR files |
| `CP-xxx` | Context Pack | Future context-pack files |
| `CON-xxx` | Contract | Future contract files |
| `TEST-xxx` | Test Strategy | Future test-strategy files |

Rules:

- Architecture work must reference applicable `RG-xxx`, `BC-xxx`, and `AT-xxx`
  IDs.
- ADRs must reference the gaps and boundary candidates they resolve.
- Contracts must reference the ADRs or owner decisions they implement.
- Test strategies must reference the contracts, gaps, or boundaries they
  protect.
- `BC-xxx` is the forward governance prefix for boundary candidates. Existing
  boundary candidate sections currently use `B-xxx`; map them as `B-001` to
  `BC-001`, `B-002` to `BC-002`, and so on. `B-005A` maps to `BC-005A`.

## Architecture Status Dashboard

| Area | Current Status | Risk | Codex Risk | Current Phase | Next Action |
| --- | --- | --- | --- | --- | --- |
| Live Game State Authority (`BC-001`) | Current implementation mostly known; decision options analyzed; no accepted ADR yet | High | Medium | ANALYZED | Create ADR for `RG-001`, `RG-003`, `RG-014` |
| Command Processing and Applicability (`BC-002`) | Command spine exists; invariant coverage needs to be mapped | High | High | TRIAGED | Add test coverage plan before broad changes |
| Interaction Flow and UI Projection (`BC-003`) | Key contradiction remains around command-only flow mutation vs attack workflow writes | High | High | TRIAGED | Owner decision, then ADR/contract |
| Setup Flow and Setup Package (`BC-004`) | Existing step-level setup contract exists; architecture context still spread across docs/code | High | Medium | TRIAGED | Create setup context pack |
| Rule and Validation Surfaces (`BC-005`) | Hybrid rule behavior exists; intended rule ownership unresolved | High | High | TRIAGED | Owner decision before new broad rule patterns |
| Game Component Rule Extension (`BC-005A`) | Expansion path for upgrades/objectives/special rules is not fully accepted | High | High | TRIAGED | Create ADR or context pack before feature work that adds behavior-changing rules |
| GameManager Orchestration (`BC-006`) | Actual hub responsibility is broader than some docs state | High | High | TRIAGED | Create context pack before deciding boundary |
| Network Command Sync and State Filtering (`BC-007`) | Implementation mostly known; test visibility is the weak point | High | High | TRIAGED | Create network/replay test strategy |
| Save/Load and Checkpoint Boundary (`BC-008`) | Implementation appears aligned; invariant coverage not explicitly mapped | High | Medium | TRIAGED | Create save/load test strategy |
| Replay and Baseline Trace Boundary (`BC-009`) | Replay pipeline exists; assumptions need test mapping and flow exception handling | High | High | TRIAGED | Create replay/baseline test strategy |
| Presentation Preview and Local Workflow (`BC-010`) | Temporary legacy and preview state exists; tolerated only where non-durable | Medium | High | TRIAGED | Add Codex guardrail; do not spread durable scene mutation |
| Static Content and Asset Loading (`BC-011`) | Current JSON/AssetLoader pipeline differs from stale Arc42 references | Medium | Low | TRIAGED | Documentation update after authority rules are in place |
| Fleet Builder to Runtime Setup Handoff (`BC-012`) | Handoff broadly works; special-rule activation after handoff unresolved | Medium | Medium | TRIAGED | Create fleet/setup context pack |
| EventBus Integration Boundary (`BC-013`) | EventBus is important but not exclusive in current code | Medium | Medium | TRIAGED | Owner decision before enforcing exclusivity |
| Documentation Authority Boundary (`BC-014`) | Authority hierarchy was unclear; this roadmap and `DOCUMENT_AUTHORITY.md` establish migration rules | Medium | High | CONTEXT UNDERSTOOD | Keep authority docs current during architecture work |

## Architecture Work Backlog

### AT-001 - Live Game State Authority ADR

| Field | Value |
| --- | --- |
| Type | ADR |
| Priority | Critical |
| Status | Backlog |
| Inputs | `RG-001`, `RG-003`, `RG-014`; `BC-001`; `BC-003`; `BC-006`; `docs/ARCHITECTURE_DECISION_TRIAGE.md`; `docs/current_state_architecture_maps.md`; relevant Arc42 sections |
| Outputs | `ADR-001` candidate; follow-up `CON-001` candidate |
| Dependencies | None |

### AT-002 - Interaction Flow and UI Projection Decision

| Field | Value |
| --- | --- |
| Type | ADR |
| Priority | Critical |
| Status | Backlog |
| Inputs | `RG-003`, `RG-004`, `RG-014`; `BC-003`; `BC-010`; `BC-007`; `docs/game_flow.md`; `FlowSpec`; `UIProjector`; attack-flow code |
| Outputs | `ADR-002` candidate; `CON-002` candidate |
| Dependencies | `AT-001` may constrain this task |

### AT-003 - Rule and Validation Surface Decision

| Field | Value |
| --- | --- |
| Type | ADR |
| Priority | Critical |
| Status | Backlog |
| Inputs | `RG-005`, `RG-006`, `RG-012`, `RG-013`; `BC-005`; `BC-005A`; `.github/skills/rule-integration/SKILL.md`; Arc42 rule sections |
| Outputs | `ADR-003` candidate; `CON-003` candidate |
| Dependencies | None |

### AT-004 - Game Component Rule Extension Context Pack

| Field | Value |
| --- | --- |
| Type | Context Pack |
| Priority | Critical |
| Status | Backlog |
| Inputs | `RG-005`, `RG-006`, `RG-011`, `RG-013`, `RG-015`; `BC-005A`; `BC-011`; `BC-012`; static component JSON; loader/setup/fleet/runtime code |
| Outputs | `CP-001` candidate; inputs for `ADR-003` and `CON-003` |
| Dependencies | None |

### AT-005 - Architecture Document Authority Rules

| Field | Value |
| --- | --- |
| Type | Codex Guardrail |
| Priority | Critical |
| Status | Completed |
| Inputs | `RG-008`, `RG-009`, `RG-010`, `RG-011`, `RG-012`, `RG-016`; `BC-014`; all current architecture docs |
| Outputs | `docs/architecture/DOCUMENT_AUTHORITY.md`; `.ai/instructions/project_status.md`; `docs/architecture/CODEX_WORKFLOW.md` |
| Dependencies | None |

### AT-006 - GameManager Orchestration Context Pack

| Field | Value |
| --- | --- |
| Type | Context Pack |
| Priority | High |
| Status | Backlog |
| Inputs | `RG-001`, `RG-002`, `RG-007`; `BC-006`; `BC-013`; `src/autoload/game_manager.gd`; `project.godot`; current-state maps |
| Outputs | `CP-002` candidate; inputs for future `ADR-004` |
| Dependencies | `AT-001` may constrain state ownership conclusions |

### AT-007 - Command Processing Test Strategy

| Field | Value |
| --- | --- |
| Type | Test Coverage |
| Priority | High |
| Status | Backlog |
| Inputs | `RG-003`, `RG-005`, `RG-012`, `RG-013`; `BC-002`; command registry; `CommandApplicability`; replay history |
| Outputs | `TEST-001` candidate; focused command/applicability tests |
| Dependencies | None |

### AT-008 - Network/Replay/State Filtering Test Strategy

| Field | Value |
| --- | --- |
| Type | Test Coverage |
| Priority | High |
| Status | Backlog |
| Inputs | `RG-002`, `RG-003`, `RG-004`, `RG-013`; `BC-007`; `BC-009`; `StateFilter`; `UIProjector`; replay/baseline scripts |
| Outputs | `TEST-002` candidate |
| Dependencies | `AT-002` may change flow invariants |

### AT-009 - Save/Load and Checkpoint Test Strategy

| Field | Value |
| --- | --- |
| Type | Test Coverage |
| Priority | High |
| Status | Backlog |
| Inputs | `RG-001`, `RG-013`, `RG-016`; `BC-008`; `SaveGameManager`; `GameState.serialize()` / `deserialize()` |
| Outputs | `TEST-003` candidate |
| Dependencies | `AT-001` may define live-state ownership rules |

### AT-010 - Setup Flow Context Pack

| Field | Value |
| --- | --- |
| Type | Context Pack |
| Priority | High |
| Status | Backlog |
| Inputs | `RG-015`, `RG-001`, `RG-004`; `BC-004`; `docs/setup_flow.md`; setup commands; setup UI; setup package code |
| Outputs | `CP-003` candidate |
| Dependencies | None |

### AT-011 - Fleet Builder to Runtime Handoff Context Pack

| Field | Value |
| --- | --- |
| Type | Context Pack |
| Priority | Medium |
| Status | Backlog |
| Inputs | `RG-015`, `RG-011`, `RG-013`; `BC-012`; fleet builder docs/code; setup package code |
| Outputs | `CP-004` candidate |
| Dependencies | `AT-004` for behavior-changing component rules |

### AT-012 - Static Content Documentation Update

| Field | Value |
| --- | --- |
| Type | Documentation Update |
| Priority | Medium |
| Status | Backlog |
| Inputs | `RG-008`, `RG-011`, `RG-016`; `BC-011`; current JSON/AssetLoader implementation; Arc42 static content references |
| Outputs | Arc42 update proposal or documentation patch |
| Dependencies | `AT-005`; `AT-004` for behavior-changing content boundary |

### AT-013 - EventBus Integration Decision

| Field | Value |
| --- | --- |
| Type | ADR |
| Priority | Medium |
| Status | Backlog |
| Inputs | `RG-002`, `RG-007`; `BC-013`; EventBus signal catalog; `GameManager` wrapper paths; Arc42 EventBus sections |
| Outputs | `ADR-004` candidate; `CON-004` candidate |
| Dependencies | `AT-006` recommended first |

### AT-014 - Presentation Preview Guardrail

| Field | Value |
| --- | --- |
| Type | Codex Guardrail |
| Priority | High |
| Status | Backlog |
| Inputs | `RG-004`, `RG-005`, `RG-014`; `BC-010`; scene-owned preview and attack workflow code |
| Outputs | Codex instruction update; optional `CON-005` candidate after owner decision |
| Dependencies | `AT-002` should define flow authority first |

### AT-015 - Documentation Authority Cleanup Pass

| Field | Value |
| --- | --- |
| Type | Documentation Update |
| Priority | Medium |
| Status | Backlog |
| Inputs | `RG-008`, `RG-009`, `RG-010`, `RG-011`, `RG-012`, `RG-016`; `BC-014`; Arc42; phase plans; current-state maps |
| Outputs | Staleness labels or targeted updates to existing docs |
| Dependencies | `AT-005`; relevant ADRs should be accepted before rewriting intended architecture |

### AT-016 - Setup Contract Test Mapping

| Field | Value |
| --- | --- |
| Type | Test Coverage |
| Priority | Medium |
| Status | Backlog |
| Inputs | `RG-015`, `RG-013`; `BC-004`; `docs/setup_flow.md`; existing setup tests |
| Outputs | `TEST-004` candidate |
| Dependencies | `AT-010` |

### AT-017 - Command/Rule Inventory Documentation Update

| Field | Value |
| --- | --- |
| Type | Documentation Update |
| Priority | Medium |
| Status | Backlog |
| Inputs | `RG-006`, `RG-012`; `BC-002`; `BC-005`; command registry; rule registry bootstrap |
| Outputs | Updated inventory docs or generated inventory note |
| Dependencies | `AT-003` for rule architecture language |

### AT-018 - Architecture Refactoring Candidate Register

| Field | Value |
| --- | --- |
| Type | Refactoring |
| Priority | Low |
| Status | Backlog |
| Inputs | Accepted ADRs and contracts only |
| Outputs | Future refactoring task list |
| Dependencies | At least one accepted ADR and related contract |

## Architecture Workflow State Machine

Standard lifecycle:

```text
DISCOVERED
    -> ANALYZED
    -> TRIAGED
    -> CONTEXT UNDERSTOOD
    -> OWNER DECISION
    -> ADR ACCEPTED
    -> CONTRACT CREATED
    -> TEST PROTECTED
    -> MIGRATION EXECUTED
    -> COMPLETED
```

State definitions:

| State | Meaning |
| --- | --- |
| DISCOVERED | A boundary, gap, or contradiction has been identified. |
| ANALYZED | Current implementation and relevant documentation have been compared. |
| TRIAGED | Risk, Codex risk, and next action are known. |
| CONTEXT UNDERSTOOD | A context pack or equivalent local evidence package exists. |
| OWNER DECISION | The owner has selected a direction or explicitly deferred it. |
| ADR ACCEPTED | The decision is recorded as accepted architecture. |
| CONTRACT CREATED | Behavioral or boundary invariants are written in a contract. |
| TEST PROTECTED | Important invariants have tests or a test strategy. |
| MIGRATION EXECUTED | Code/docs/tests have moved toward the accepted decision. |
| COMPLETED | No known governance work remains for this topic. |

Not every topic needs every state. For example, a stale inventory count may move
from TRIAGED to DOCUMENTATION UPDATE without an ADR. A high-risk boundary such
as `BC-003` should not skip owner decision and contract work.

## Architecture Kanban

### Backlog

- `AT-001` - Live Game State Authority ADR
- `AT-002` - Interaction Flow and UI Projection Decision
- `AT-003` - Rule and Validation Surface Decision
- `AT-004` - Game Component Rule Extension Context Pack
- `AT-006` - GameManager Orchestration Context Pack
- `AT-007` - Command Processing Test Strategy
- `AT-008` - Network/Replay/State Filtering Test Strategy
- `AT-009` - Save/Load and Checkpoint Test Strategy
- `AT-010` - Setup Flow Context Pack
- `AT-011` - Fleet Builder to Runtime Handoff Context Pack
- `AT-012` - Static Content Documentation Update
- `AT-013` - EventBus Integration Decision
- `AT-014` - Presentation Preview Guardrail
- `AT-015` - Documentation Authority Cleanup Pass
- `AT-016` - Setup Contract Test Mapping
- `AT-017` - Command/Rule Inventory Documentation Update
- `AT-018` - Architecture Refactoring Candidate Register

### In Progress

- None recorded.

### Blocked

- None blocked by external conditions yet.
- `AT-018` is intentionally waiting for accepted ADRs and contracts before it
  becomes actionable.

### Completed

- `AT-005` - Architecture Document Authority Rules

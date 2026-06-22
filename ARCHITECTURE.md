# Architecture

This document is the entry point for the project's architecture documentation.

It is written for new developers, future maintainers, Codex, ChatGPT, and the
project owner returning after a break.

## Architecture at a Glance

Current Architecture Governance:

- ✓ Context Pack methodology established.
- ✓ ADR governance established.
- ✓ Contract governance established.
- ✓ Rule Capability Package methodology established.

Current Phase: Architecture Operationalization.

Current Rule Integration Lifecycle:

```text
Context Pack
    ↓
ADR
    ↓
Contract
    ↓
Rule Capability Package
    ↓
Tests
    ↓
Migration
```

This snapshot is for orientation only. Check the roadmap, accepted ADRs, and
accepted contracts for current authority and status.

## 1. Purpose

This document provides orientation.

It explains where architecture information lives, which documents are
authoritative, how architecture work flows through the repository, and where new
work should start.

This document is not an architecture specification.

Architecture decisions live in ADRs.

Implementation contracts live in Contracts.

Evidence lives in Context Packs.

Do not treat this document as the source of truth for a specific architectural
decision, invariant, migration plan, or implementation detail. Use it to find
the document that owns that information.

## 2. Repository Architecture Overview

Architecture documentation lives primarily under `docs/architecture/`.

| Location | Purpose |
| --- | --- |
| `docs/architecture/ARCHITECTURE_ROADMAP.md` | Tracks architecture work, current phase, risks, dependencies, and next actions. |
| `docs/architecture/DOCUMENT_AUTHORITY.md` | Defines which document answers which kind of architecture question. |
| `docs/architecture/CODEX_WORKFLOW.md` | Defines how Codex should approach architecture-sensitive work. |
| `docs/architecture/context/` | Contains evidence packs describing what the implementation currently does. |
| `docs/architecture/adr/` | Contains accepted and proposed architecture decisions. |
| `docs/architecture/contracts/` | Contains accepted implementation invariants derived from architecture decisions. |
| `docs/architecture/templates/` | Contains reusable document structures for repeatable architecture work. |
| `docs/architecture/rule_capability_packages/` | Contains Rule Capability Packages that trace concrete rule behavior against CON-003. |
| `docs/architecture/decision_workbooks/` | Contains option analysis and review artifacts that support decisions. |
| Future test strategy documents | Will define architecture-level test obligations such as `TEST-xxx`. |
| Future migration documents | Will record accepted migration plans and migration status when needed. |

Older or broader architecture material may also exist elsewhere under `docs/`,
including Arc42, current-state maps, reality-gap registers, boundary candidates,
requirements, setup flow contracts, and implementation plans. Use the authority
rules before treating any one document as final.

## 3. Document Authority

When multiple documents disagree,
[`DOCUMENT_AUTHORITY.md`](docs/architecture/DOCUMENT_AUTHORITY.md) defines which
document is authoritative.

The short version:

- Accepted ADRs define accepted architecture decisions for their topics.
- Accepted Contracts define implementation invariants.
- Context Packs provide implementation evidence.
- Roadmaps and workbooks guide architecture work, but they are not final
  decisions.
- Older intended architecture remains useful, but it can be superseded by
  accepted ADRs, contracts, or verified implementation evidence.

For conflicts, do not guess. Follow the authority hierarchy and stop for owner
guidance when no accepted ADR, contract, or documented migration path resolves
the conflict.

## 4. Architecture Workflow

Architecture work normally flows through this lifecycle:

```text
Context Pack
    ↓
ADR
    ↓
Contract
    ↓
Rule Capability Package
    ↓
Tests
    ↓
Migration
```

Purpose of each step:

| Step | Purpose |
| --- | --- |
| Context Pack | Gather evidence about what the implementation currently does. |
| ADR | Decide the architecture direction for a topic. |
| Contract | Convert accepted architecture into implementation rules and invariants. |
| Rule Capability Package | Trace how a concrete behavior-changing rule satisfies ADR-003 and CON-003. |
| Tests | Protect accepted behavior, contracts, replay determinism, networking, save/load, and visibility where applicable. |
| Migration | Move the implementation in small accepted increments. |

This is a summary. Use
[`CODEX_WORKFLOW.md`](docs/architecture/CODEX_WORKFLOW.md) for the operational
workflow and decision logic.

## 5. Current Architecture Status

Use the repository structure to find the current architecture baseline.

Expected locations:

| Status Area | Where to Look |
| --- | --- |
| Accepted ADRs | `docs/architecture/adr/` |
| Accepted Contracts | `docs/architecture/contracts/` |
| Current Context Packs | `docs/architecture/context/` |
| Current Rule Capability Packages | `docs/architecture/rule_capability_packages/` |
| Current Architecture Baseline | Accepted ADRs, accepted Contracts, Baseline Evidence Context Packs, and the roadmap together. |

Do not infer project status from this file. Check the directories and the
roadmap.

## 6. Architecture Roadmap

The architecture roadmap lives at:

[`docs/architecture/ARCHITECTURE_ROADMAP.md`](docs/architecture/ARCHITECTURE_ROADMAP.md)

Use it to understand:

- Current architecture work areas.
- Risk and Codex-risk status.
- Architecture tasks and dependencies.
- Which work is backlog, in progress, blocked, or complete.
- What the next architecture action should be.

Do not duplicate roadmap content here. The roadmap is the working dashboard.

## 7. Working with Codex

Codex implements. The owner decides architecture.

Architecture-sensitive changes should start by checking:

1. The roadmap.
2. Document authority.
3. Accepted ADRs.
4. Accepted Contracts.
5. Relevant Context Packs.
6. Reality gaps or boundary candidates, if the area is unresolved.

Rule integration follows ADR-003 and CON-003:

- ADR-003 defines the accepted rule and validation surface architecture.
- CON-003 defines the Rule Capability Contract.
- Rule Capability Packages provide implementation traceability for concrete
  behavior-changing rules.
- Codex may gather evidence and recommend readiness.
- Codex may not mark a Rule Capability Package as `Integrated`.

Use [`CODEX_WORKFLOW.md`](docs/architecture/CODEX_WORKFLOW.md) for detailed
Codex behavior.

## 8. Quick Navigation

| Group | Need | Link |
| --- | --- | --- |
| Project | Project overview | [README.md](README.md) |
| Governance | Architecture roadmap | [ARCHITECTURE_ROADMAP.md](docs/architecture/ARCHITECTURE_ROADMAP.md) |
| Governance | Document authority | [DOCUMENT_AUTHORITY.md](docs/architecture/DOCUMENT_AUTHORITY.md) |
| Governance | Codex architecture workflow | [CODEX_WORKFLOW.md](docs/architecture/CODEX_WORKFLOW.md) |
| Architecture | Context Pack index | [docs/architecture/context/](docs/architecture/context/) |
| Architecture | ADR index | [docs/architecture/adr/](docs/architecture/adr/) |
| Architecture | Decision Workbooks | [docs/architecture/decision_workbooks/](docs/architecture/decision_workbooks/) |
| Implementation | Contract index | [docs/architecture/contracts/](docs/architecture/contracts/) |
| Implementation | Rule Capability Package directory | [docs/architecture/rule_capability_packages/](docs/architecture/rule_capability_packages/) |
| Templates | Rule Capability Package Template | [RULE_CAPABILITY_PACKAGE_TEMPLATE.md](docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md) |
| Templates | Context Pack Template | [CONTEXT_PACK_TEMPLATE.md](docs/architecture/templates/CONTEXT_PACK_TEMPLATE.md) |
| Future Work | Test documents | Future `TEST-xxx` documents |
| Future Work | Migration documents | Future migration documents |

## 9. Getting Started

### New Developer

Use this path when joining the project or returning after a long break.

Suggested reading order:

1. [README.md](README.md)
2. This file.
3. [DOCUMENT_AUTHORITY.md](docs/architecture/DOCUMENT_AUTHORITY.md)
4. [ARCHITECTURE_ROADMAP.md](docs/architecture/ARCHITECTURE_ROADMAP.md)
5. Accepted ADRs relevant to your work.
6. Accepted Contracts relevant to your work.
7. Relevant Context Packs for implementation evidence.

### New Codex Session

Use this path before architecture-sensitive implementation or documentation work.

Suggested reading order:

1. [CODEX_WORKFLOW.md](docs/architecture/CODEX_WORKFLOW.md)
2. [DOCUMENT_AUTHORITY.md](docs/architecture/DOCUMENT_AUTHORITY.md)
3. [ARCHITECTURE_ROADMAP.md](docs/architecture/ARCHITECTURE_ROADMAP.md)
4. Accepted ADRs and Contracts for the touched area.
5. Related Context Packs and Rule Capability Packages.

Before architecture-sensitive changes, classify whether the work is safe,
requires tests, requires a context pack, or needs owner decision.

### New Architecture Decision

Use this path when a topic needs an owner decision rather than direct implementation.

Suggested reading order:

1. Current roadmap task or owner request.
2. Relevant current-state and gap documents.
3. Relevant Context Packs, or create one if evidence is missing.
4. Decision workbooks, if option analysis is needed.
5. Draft ADR.
6. Owner decision.
7. Contract and test strategy after acceptance.

## 10. Architecture Principles

The project governance emphasizes:

- Evidence before decisions.
- Decisions before implementation.
- Contracts before migration.
- Traceability over documentation volume.
- References over duplication.
- Small accepted increments.
- AI-assisted, owner-governed architecture.

These principles summarize existing governance. They do not add new authority or
new contract semantics.

## 11. Maintenance

`ARCHITECTURE.md` should remain stable.

`ARCHITECTURE.md` should change infrequently. Whenever possible, add links to
newly accepted artifacts rather than expanding explanatory text. This document
should remain an orientation guide rather than becoming another source of
architectural truth.

Do not use this file to record detailed decisions, contract requirements,
evidence, or migration status. Put those in the appropriate ADR, Contract,
Context Pack, roadmap, test strategy, Rule Capability Package, or migration
document.

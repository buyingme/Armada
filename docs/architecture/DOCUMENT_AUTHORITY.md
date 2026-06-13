# Document Authority

This document defines which architecture documents represent which type of
truth during the architecture migration and clarification period.

No single document is automatically correct in all contexts. Current code,
accepted decisions, contracts, and historical intent each answer different
questions.

## Authority Principles

- Accepted ADRs outrank older intended architecture descriptions for the topic
  they decide.
- Contracts define behavioral invariants for implementation work.
- Current-state maps describe observed implementation reality; they do not by
  themselves approve that reality as long-term architecture.
- Reality gaps and boundary candidates identify decision candidates; they are
  not final decisions.
- Arc42 remains valuable as intended architecture and context, but sections may
  be stale until reconciled.
- When documents conflict and no accepted ADR or contract resolves the conflict,
  Codex must stop before architecture-sensitive implementation work and ask for
  owner guidance.

## Document Authority Table

| Document Type | Purpose | Represents | Authority Level | Codex May Modify Automatically | Owner Approval Required |
| --- | --- | --- | --- | --- | --- |
| Arc42 (`docs/arc42/`) | Long-form architecture description, goals, runtime views, decisions, risks | Intended architecture; historical decisions; partially outdated references | Medium unless superseded by accepted ADRs/contracts/current-state evidence | No broad rewrite. Small factual updates only when requested or clearly tied to accepted decisions | Yes for structural updates, decision language, or changes to intended architecture |
| Current State Architecture Map (`docs/current_state_architecture_maps.md`) | Code-derived architecture map | Current reality | High for observed implementation; low as future direction | Yes, when explicitly asked to update observed reality | Owner review recommended for major reinterpretation |
| Reality Gap Register (`docs/REALITY_GAP_REGISTER.md`) | Tracks discrepancies between intended docs and actual implementation | Temporary migration state; decision candidates | High for known gaps; not a decision authority | Yes, when explicitly asked to record new evidence or gaps | Required to close or reclassify major gaps |
| Boundary Candidates (`docs/ARCHITECTURE_BOUNDARY_CANDIDATES.md`) | Candidate ownership boundaries for future decisions/contracts | Temporary migration state; candidate boundaries | Medium-high for triage; not accepted architecture | Yes, when explicitly asked to update candidates | Required to mark a boundary accepted |
| Architecture Decision Triage (`docs/ARCHITECTURE_DECISION_TRIAGE.md`) | Classifies boundary candidates by next action | Temporary migration state; work prioritization | High for current triage status | Yes, when explicitly asked to update triage | Required to change decision status after owner decision |
| Architecture Roadmap (`docs/architecture/ARCHITECTURE_ROADMAP.md`) | Single entry point for transformation work | Temporary migration state; architecture program backlog; Codex operating priorities | High for work sequencing and task IDs | Yes, for task tracking and status updates when requested | Required for priority changes, new critical tasks, or completed decision claims |
| ADRs (`docs/architecture/adr/ADR-xxx-*.md`, future) | Records accepted architecture decisions | Accepted decisions | Very high for decided topics | No, except creating drafts when requested | Yes to accept, supersede, or reject |
| Context Packs (`docs/architecture/context/CP-xxx-*.md`, future) | Local evidence package for a boundary/topic | Current reality plus relevant intended docs and code evidence | High as evidence; not a decision | Yes, when requested | Owner approval not required unless it asserts decisions |
| Contracts (`docs/architecture/contracts/CON-xxx-*.md`, future, plus existing contracts such as `docs/setup_flow.md`) | Defines invariants and allowed behavior for implementation | Accepted behavioral contract | Very high for implementation | No, except draft/update when requested | Yes to create or change accepted contracts |
| Test Strategies (`docs/architecture/tests/TEST-xxx-*.md`, future) | Defines invariant coverage and test obligations | Required or planned test protection | High for testing expectations after accepted | Yes, when requested or derived from accepted contracts | Required to waive high-risk test obligations |
| Existing Copilot Instructions (`.github/copilot-instructions.md`) | General AI/coding guidance | Codex and Copilot operating rules; may lag architecture migration | Medium; superseded by accepted ADRs/contracts and `.ai/instructions/project_status.md` for migration safety | No broad rewrite unless requested | Required for persistent policy-level changes |
| Existing Skills (`.skills/*.md`, `.github/skills/*/SKILL.md`) | Specialized AI workflows and implementation rules | Codex operating rules and domain-specific guidance; may contain intended architecture | Medium-high for local workflow; superseded by accepted ADRs/contracts on conflicts | No broad rewrite unless requested | Required for changing normative workflow rules |
| Future Codex Instructions (`.ai/instructions/*.md`) | Short operational guardrails for AI agents | Codex operating rules during migration | High for AI behavior; does not decide architecture | Yes, when requested to update guardrails | Required if guardrail changes alter risk posture |

## Authority by Question Type

| Question | Primary Source | Secondary Source |
| --- | --- | --- |
| What does the code currently do? | Current State Architecture Map, relevant code | Context packs |
| What did the project intend historically? | Arc42, existing plans, existing skills | Reality Gap Register |
| What is accepted architecture now? | Accepted ADRs | Contracts |
| What must implementation preserve? | Contracts | Test strategies |
| What is unresolved? | Reality Gap Register, Boundary Candidates, Decision Triage | Architecture Roadmap |
| What should Codex do safely today? | `.ai/instructions/project_status.md`, `CODEX_WORKFLOW.md`, Architecture Roadmap | Existing Copilot instructions and skills |

## Conflict Resolution Rules

1. If an accepted ADR and an older doc disagree, follow the ADR.
2. If a contract and implementation convenience disagree, follow the contract.
3. If current code and Arc42 disagree, check the Reality Gap Register and
   Architecture Roadmap before changing code.
4. If no ADR, contract, or task resolves the conflict, do not normalize either
   side as correct.
5. For feature work in unresolved areas, prefer local existing patterns only
   when they do not spread a listed legacy pattern or deepen a reality gap.

## Document Modification Rules

- Do not mark a candidate boundary as accepted without owner decision.
- Do not close a reality gap because a code path exists; closure requires a
  decision, documentation update, test coverage, or explicit owner acceptance.
- Do not rewrite Arc42 to match current implementation until the owner has
  decided whether the implementation is intended architecture.
- Do not create contracts unless requested.
- Do not treat context packs as decisions.


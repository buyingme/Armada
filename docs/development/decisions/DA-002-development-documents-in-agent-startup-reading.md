# DA-002: Development Documents in Agent Startup Reading

> **Status:** Accepted
> **Authority:** Development Architecture Decision
> **Audience:** Project Owner, AI Agents
> **Date:** 2026-06-27
> **Amended:** 2026-08-18

---

## Context

The project now distinguishes between two related but separate documentation areas:

- Software Architecture: how the Armada software is structured.
- Development Architecture: how the project is developed with human and AI assistance.

The previous decision required a complete startup-reading set for every
architecture-sensitive task. That approach is consistent but loads more context
than many tasks require.

---

## Decision

This decision amends, rather than supersedes, the prior DA-002 direction.

Agent startup context shall use three-level routing:

1. Routine.
2. Bounded Architecture.
3. Uncertain/High-Risk Architecture.

Classify the task before loading context and select the minimum sufficient
context for its intent and affected behavior or authority. File type or
location alone does not determine risk. Uncertainty escalates conservatively;
unresolved authority requires Project Owner guidance.

An accepted implementation workbook with unambiguous accepted status and scope
is the authoritative execution specification for implementation within that
scope. `AGENTS.md` and that workbook may form the minimum initial context. The
workbook does not replace or override the existing document-authority hierarchy.
Additional authority is loaded only when required by the workbook or routing,
when evidence conflicts with it, when authority is ambiguous or contradictory,
or when a required invariant cannot be resolved from it.

A workflow-stage transition alone does not require a new Codex task.
Deliberately independent or high-risk verification gates remain separate when
their independence provides meaningful defect-detection value.

Agents shall use the least costly model capability that can reliably satisfy
the task's quality and risk requirements, and produce concise output unless
additional detail provides decision value.

---

## Rationale

Routing preserves the existing authority model while reducing unnecessary
context loading. It makes escalation explicit for tasks whose behavior or
authority impact requires broader evidence.

---

## Consequences

### Positive

- AI agents receive context proportionate to task risk.
- Owner authority is reinforced before implementation begins.
- Accepted implementation workbooks can be executed efficiently within their
  accepted scope.

### Trade-offs

- Correct classification is required before context loading.
- High-risk or uncertain work still requires broader authority review.

---

## Implementation Guidance

Update `AGENTS.md`, `.ai/instructions/AI_STARTUP_GUARDRAILS.md`, and
`docs/architecture/CODEX_WORKFLOW.md` consistently.

This decision does not change software architecture rules or the authority of
accepted ADRs, Contracts, Context Packs, or Rule Capability Packages.

---

## Related Documents

- `AGENTS.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
- `docs/architecture/CODEX_WORKFLOW.md`

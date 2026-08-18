# AI Startup Guardrails

Purpose:

This document provides a lightweight startup checklist for AI agents.

This document supplements, but does not replace, the architecture documentation.

This project is actively evolving.

Accepted architecture, implementation, and historical documentation may
temporarily diverge.

Resolve disagreements using `docs/architecture/DOCUMENT_AUTHORITY.md`.

Rules for AI agents:

- Do not assume Arc42 reflects the current implementation.
- Do not assume current implementation represents the final architecture.
- Follow accepted ADRs over older architectural descriptions.
- Follow contracts for behavioral invariants.
- Preserve local patterns unless the roadmap specifies a migration path.
- Do not introduce new architectural patterns without an owner decision.

Before changes, classify the task and load minimum sufficient context using the
three-level routing model in `docs/architecture/CODEX_WORKFLOW.md`. Task intent
and affected behavior or authority determine the route; file location alone
does not.

For architecture work, use the accepted authority and implementation evidence
applicable to the route. Escalate uncertainty conservatively. If authority
remains unresolved, stop and ask the owner for guidance.

Apply the accepted-workbook fast path only as defined in DA-002 and
`CODEX_WORKFLOW.md`; it remains subject to the existing document-authority
hierarchy.

If documentation and code conflict and no documented migration path exists,
stop and ask for owner guidance.

Architecture authority is still determined by
`docs/architecture/DOCUMENT_AUTHORITY.md`.

# AGENTS.md

Purpose:

This file provides lightweight startup instructions for AI agents.

It is not an architecture document.

## Startup Reading

Classify the task before loading context. Use the three-level routing model in
`docs/architecture/CODEX_WORKFLOW.md` and the decision in
`docs/development/decisions/DA-002-development-documents-in-agent-startup-reading.md`.

Start with this file and the minimum additional context for the classified
task. Do not automatically load the former complete startup-reading set.

For bounded architecture work, load only the applicable accepted authority and
implementation evidence. For uncertain or high-risk architecture work, load
the authority needed to resolve the uncertainty; stop and ask the owner when it
remains unresolved.

When an accepted implementation workbook has unambiguous status and applicable
scope, this file and that workbook may be the initial implementation context.
The workbook does not override the document-authority hierarchy; add authority
documents when the workbook, routing triggers, conflicting evidence, ambiguity,
or an unresolved invariant requires them.

## Architecture Rules

- Accepted ADRs and accepted Contracts are authoritative within the document authority model defined by `docs/architecture/DOCUMENT_AUTHORITY.md`.
- Use `DOCUMENT_AUTHORITY.md` to resolve document conflicts.
- Do not assume Arc42 reflects the current implementation.
- Do not assume current implementation is the final architecture.
- Preserve local patterns unless an accepted roadmap, ADR, or Contract defines a migration path.
- Do not introduce new architectural patterns without owner approval.

## Rule Work

Behavior-changing rule work follows:

- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`

Rule Capability Packages provide traceability for concrete rule behavior.

Codex may gather evidence and recommend readiness.

Codex may not mark a Rule Capability Package as `Integrated`.

## Conflict Handling

If documentation and code conflict, first check `DOCUMENT_AUTHORITY.md`,
accepted ADRs, accepted Contracts, and the roadmap.

If authority cannot resolve the conflict, stop and ask the owner for guidance
before changing architecture-sensitive code or documentation.

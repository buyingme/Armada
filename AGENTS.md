# AGENTS.md

Purpose:

This file provides lightweight startup instructions for AI agents.

It is not an architecture document.

Architecture orientation always begins with `ARCHITECTURE.md`.

## Startup Reading

For architecture-sensitive work, read these first:

1. `ARCHITECTURE.md`
2. `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
3. `docs/architecture/DOCUMENT_AUTHORITY.md`
4. `docs/architecture/ARCHITECTURE_ROADMAP.md`
5. `docs/architecture/CODEX_WORKFLOW.md`

Then read the accepted ADRs, Contracts, Context Packs, and Rule Capability
Packages relevant to the files being changed.

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

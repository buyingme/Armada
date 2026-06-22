# Project Status Guardrail

Purpose:

This document provides a lightweight startup checklist for AI agents.

Architecture orientation begins with `ARCHITECTURE.md`.

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

Before architecture-sensitive changes:

1. Read `ARCHITECTURE.md`.
2. Follow the reading guidance provided there.
3. Read `docs/architecture/DOCUMENT_AUTHORITY.md`.
4. Read `docs/architecture/ARCHITECTURE_ROADMAP.md`.
5. Read the relevant accepted ADRs.
6. Read the relevant accepted Contracts.
7. Read the relevant Context Packs.
8. If the area is still under clarification, consult `docs/REALITY_GAP_REGISTER.md`.

If documentation and code conflict and no documented migration path exists,
stop and ask for owner guidance.

When `ARCHITECTURE.md` and another orientation document differ,
`ARCHITECTURE.md` is the preferred entry point.

Architecture authority is still determined by
`docs/architecture/DOCUMENT_AUTHORITY.md`.

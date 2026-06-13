# Project Status Guardrail

This project is undergoing architecture clarification. Architecture documents,
current code, and implementation guidance may temporarily disagree.

Rules for AI agents:

- Do not assume Arc42 reflects the current implementation.
- Do not assume current implementation represents the final architecture.
- Follow accepted ADRs over older architectural descriptions.
- Follow contracts for behavioral invariants.
- Preserve local patterns unless the roadmap specifies a migration path.
- Do not introduce new architectural patterns without an owner decision.

Before architecture-sensitive changes:

1. Check `docs/architecture/ARCHITECTURE_ROADMAP.md`.
2. Check `docs/architecture/DOCUMENT_AUTHORITY.md`.
3. Read related ADRs, contracts, and context packs if they exist.
4. Check `docs/REALITY_GAP_REGISTER.md`.

If documentation and code conflict and no documented migration path exists,
stop and ask for owner guidance.


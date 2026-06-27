# DA-002: Development Documents in Agent Startup Reading

> **Status:** Accepted
> **Authority:** Development Architecture Decision
> **Audience:** Project Owner, AI Agents
> **Date:** 2026-06-27

---

## Context

The project now distinguishes between two related but separate documentation areas:

- Software Architecture: how the Armada software is structured.
- Development Architecture: how the project is developed with human and AI assistance.

`AGENTS.md` already defines startup reading for architecture-sensitive work. It currently focuses on software architecture documents only.

With the introduction of `AI_DEVELOPMENT_PRINCIPLES.md` and `AI_DEVELOPMENT_PROCESS.md`, AI agents also need to understand the development process before performing architecture-sensitive work.

---

## Decision

`AGENTS.md` shall include the development architecture documents in the mandatory startup reading for architecture-sensitive work.

The startup reading should include:

1. `ARCHITECTURE.md`
2. `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
3. `docs/development/AI_DEVELOPMENT_PROCESS.md`
4. `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
5. `docs/architecture/DOCUMENT_AUTHORITY.md`
6. `docs/architecture/ARCHITECTURE_ROADMAP.md`
7. `docs/architecture/CODEX_WORKFLOW.md`

The development documents do not replace the software architecture documents.

They define how AI-assisted development work is performed.

---

## Rationale

Architecture-sensitive work depends on two independent information sources:

• Software Architecture
• Development Architecture

Both are required to execute architecture-sensitive work consistently.

If agents do not read the development process documents at startup, different AI sessions may apply different working assumptions.

Adding these documents to startup reading keeps agent behaviour aligned with the project’s development architecture.

---

## Consequences

### Positive

- AI agents receive consistent process guidance before architecture-sensitive work.
- Owner authority is reinforced before implementation begins.
- Development architecture becomes visible to every agent session.
- The risk of prompt-specific or tool-specific working styles is reduced.

### Trade-offs

- Startup reading becomes slightly longer.
- Very small tasks may require more initial orientation.
- Development process documents must remain lightweight to avoid startup overhead.

---

## Implementation Guidance

Update `AGENTS.md` only.

Do not change software architecture rules.

Do not change accepted ADRs, Contracts, Context Packs, or Rule Capability Packages.

---

## Related Documents

- `AGENTS.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`

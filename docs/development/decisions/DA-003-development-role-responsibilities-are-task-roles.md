# DA-003: Development Role Responsibilities Are Task Roles

> **Status:** Accepted
> **Authority:** Development Architecture Decision
> **Audience:** Project Owner, AI Agents
> **Date:** 2026-06-27

---

## Context

`AI_DEVELOPMENT_PROCESS.md` defines several development roles:

- Project Owner
- Evidence Analyst
- Architecture Author
- Engineer
- Reviewer

These roles are useful because they separate responsibilities:

- evidence collection,
- owner decision-making,
- architecture authoring,
- implementation,
- verification.

However, there is a risk that these roles are misunderstood as requiring separate tools, separate AI products, or separate permanent agents.

That would make the process heavier than intended.

---

## Decision

Development roles describe responsibilities, not mandatory separate AI agents.

A single AI session may perform different roles in different tasks provided that each task clearly specifies the active role.

The active role is defined by the assigned task and its constraints.

Examples:

- A read-only repository analysis task uses the Evidence Analyst responsibility.
- A documentation update task uses the Architecture Author responsibility.
- A code implementation task uses the Engineer responsibility.
- A diff review task uses the Reviewer responsibility.

The Project Owner remains a human responsibility and is never delegated to AI.

---

## Rationale

The project is primarily developed by one Project Owner with AI assistance.

For this context, the process must remain lightweight.

Separate role definitions improve clarity, but requiring separate agents for every role would add unnecessary operational overhead.

The important boundary is not the tool.

The important boundary is the responsibility assigned to the current task.

---

## Consequences

### Positive

- Keeps the development process lightweight.
- Avoids unnecessary proliferation of AI agents.
- Preserves responsibility separation without requiring tool separation.
- Supports future AI tools without changing the process.

### Trade-offs

- The Owner must clearly state the intended role in each task.
- AI sessions must respect task constraints.
- Some tasks may require explicit clarification when role boundaries are unclear.

---

## Implementation Guidance

Update `AI_DEVELOPMENT_PROCESS.md` with two clarifications:

1. Add an Authority section explaining the relationship between the development process and software architecture.
2. Add an implementation note explaining that roles are responsibilities, not mandatory separate AI agents.

Do not change the role names.

Do not introduce additional roles.

Do not create new process documents for this decision.

---

## Related Documents

- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `AGENTS.md`

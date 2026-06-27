# AI Development Process

> **Status:** Draft\
> **Authority:** Development Process\
> **Audience:** Project Owner, AI Agents

## 1. Purpose

This document defines the AI-assisted development process for the Armada
project.

Goals:

-   Preserve architectural consistency.
-   Minimise AI-induced architecture drift.
-   Separate architecture from implementation.
-   Maintain traceability from project goals to implementation.
-   Allow AI tools to evolve without changing the development process.

AI assistants are engineering tools. The Project Owner remains
responsible for all architecture and implementation decisions.

------------------------------------------------------------------------

## 2. Authority

This document defines the Development Architecture for the Armada project.

The Development Architecture governs the software development process.

The Software Architecture governs the software system.

Whenever this document conflicts with software architecture documents,
`DOCUMENT_AUTHORITY.md` determines precedence.

This document never redefines software architecture.

------------------------------------------------------------------------

## 3. Guiding Principles

1.  Requirements before architecture.
2.  Evidence before decisions.
3.  Architecture before implementation.
4.  Verification before completion.
5.  AI assists.
6.  The Project Owner decides.

------------------------------------------------------------------------

## 4. Roles

### Project Owner

Responsible for:

-   defining goals
-   defining priorities
-   evaluating evidence
-   approving architecture
-   approving implementation
-   approving commits

The Project Owner is the final architectural authority.

### Evidence Analyst

Purpose:

Collect objective evidence from the repository.

Repository access: **Read-only**

Produces:

-   Evidence Reports
-   dependency analyses
-   documentation inventories
-   architecture consistency reports

Never:

-   modifies the repository
-   proposes implementation
-   makes architecture decisions

### Architecture Author

Purpose:

Update architecture after the Owner has made a decision.

Produces:

-   ADRs
-   Contracts
-   Context Packs
-   Architecture documentation

Never:

-   implements features
-   changes production code
-   redefines requirements

### Engineer

Purpose:

Implement accepted architecture.

Produces:

-   source code
-   tests
-   implementation documentation

Never:

-   redesign architecture
-   change accepted ADRs
-   change Contracts

### Reviewer

Purpose:

Verify architecture compliance.

Produces:

-   Review Reports
-   risk assessments
-   implementation verification

Never:

-   redesign architecture
-   introduce new requirements

### Implementation Note

The roles defined in this document describe responsibilities.

They do not require separate AI agents.

A single AI session may perform different roles depending on the assigned task.

The active role shall always be defined by the task specification.

------------------------------------------------------------------------

## 5. Development Workflow

``` text
Project Goal
        │
        ▼
Requirements
        │
        ▼
Evidence Collection
        │
        ▼
Owner Decision
        │
        ▼
Architecture Update
        │
        ▼
Implementation
        │
        ▼
Verification
```

------------------------------------------------------------------------

## 6. Tool Usage

### ChatGPT

Use for:

-   refining project goals
-   discussing architecture alternatives
-   creating task specifications
-   reviewing evidence reports
-   reviewing implementation strategies

### Codex Desktop

Use for:

-   repository inspection
-   evidence collection
-   dependency analysis
-   consistency checking

Normally operate in read-only mode.

### VS Code + Codex

Use for:

-   architecture documentation
-   implementation
-   testing
-   refactoring

Every repository modification shall be based on an explicit task.

------------------------------------------------------------------------

## 7. Owner Workflow

The Owner starts every activity by defining:

-   Goal
-   Scope
-   Constraints
-   Priority

The Owner does **not** write implementation prompts.

Instead, AI agents derive engineering tasks from the objective and the
repository state.

------------------------------------------------------------------------

## 8. Architecture Philosophy

Requirements describe **what** shall be built.

Architecture describes **how** requirements are realised.

Implementation follows architecture.

Implementation never defines architecture.

------------------------------------------------------------------------

## 9. Success Criteria

The process is successful when:

-   architecture remains consistent
-   AI agents remain interchangeable
-   new features integrate without architectural degradation
-   development remains efficient over the lifetime of the project
-   the Project Owner retains architectural control

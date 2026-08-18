# Token-Efficient Development Workflow — Working Notes

Status: Working Notes / Not Accepted Governance

## Goal

Token and credit consumption is an explicit optimization criterion for Armada development alongside:

- code quality,
- architectural correctness,
- first-time-right reliability.

The objective is not to trade quality for lower cost, but to eliminate context processing and agent output that provide little additional quality.

## Current Problem

The existing architecture-governed workflow is robust but likely token-inefficient.

Primary suspected cost drivers:

1. Repeated startup reading
   - Architecture-sensitive tasks may repeatedly load a large common set of governance and architecture documents.
   - Some documents may be read even when they are not materially relevant to the task.

2. Excessive Codex task churn
   - Draft, audit, refinement, verification, implementation, and repair are often performed as separate Codex tasks.
   - New tasks repeatedly reconstruct substantially the same context.

3. Prompt/document duplication
   - Long prompts sometimes restate requirements already defined by accepted ADRs, contracts, or implementation workbooks.
   - Accepted documentation should be referenced rather than reproduced.

4. Excessive completion output
   - Detailed reports can consume substantial output tokens.
   - Most implementation reviews need only changes, verification results, and exceptions/blockers.

5. Model over-selection
   - Sol should not automatically be used where Luna or Terra can reliably perform a narrowly specified task.

## Working Principles

### 1. Minimum Sufficient Context

Agents should read the minimum authoritative context necessary to perform the task safely.

AGENTS.md should ideally act as a context router, not as a mechanism that causes the complete architecture corpus to be loaded for every task.

### 2. One Coherent Work Package = One Codex Task

Do not start a new Codex task merely because the workflow moves to another stage.

The established quality workflow remains:

Draft → Architecture Audit → Very Small Refinement → Targeted Verification → Acceptance

Where practical, these stages should remain within one coherent Codex task when they concern the same artifact/work package.

A new task should represent a meaningful context or work-package boundary, not simply another prompt.

### 3. Accepted Documentation Is Referenced, Not Repeated

Once an ADR, contract, requirement, or implementation workbook is authoritative for a task, prompts should reference it instead of restating its technical content.

The documentation carries the specification; the prompt carries the execution instruction.

### 4. Concise Output by Default

Codex completion reports should normally contain only:

1. files changed,
2. verification performed and results,
3. deviations, blockers, or unresolved issues.

Detailed reasoning should be requested only when it provides decision value.

### 5. Use the Least Expensive Reliable Model

Model capability should be escalated according to task difficulty rather than defaulted to the strongest model.

Working hypothesis:

- Luna: mechanical/document discovery, inventories, narrow well-defined changes.
- Terra: normal implementation, refactoring, and analysis against established contracts.
- Sol: difficult architectural decisions, ambiguous cross-boundary problems, or high-risk reasoning.

First-time-right remains important: using a cheaper model is counterproductive if it causes repeated repair tasks.

## Proposed Audit

Before changing governance, perform a narrow read-only workflow-efficiency audit.

Initial scope should be limited to the documents that determine startup/context-loading behavior, such as:

- AGENTS.md
- AI_STARTUP_GUARDRAILS.md
- AI_DEVELOPMENT_PROCESS.md
- CODEX_WORKFLOW.md
- DOCUMENT_AUTHORITY.md

Do not automatically load ADRs, contracts, workbooks, or source code.

For each relevant rule classify it as:

KEEP / CONDITIONAL / COMPRESS / REMOVE

Evaluate four areas:

- startup reading,
- Codex task boundaries,
- prompt duplication,
- completion output.

Also reconstruct the startup reading dependency graph to identify rules that indirectly cause large amounts of documentation to be loaded.

Use a small representative sample of previous tasks to distinguish genuinely useful context from habitual/redundant context.

## Audit Strategy

Start the discovery audit with Luna and a deliberately narrow context.

Escalate to Terra or Sol only if the evidence demonstrates that deeper architectural reasoning is required.

The audit itself should follow the optimization principle:

small model + small context + narrow task + concise output

## Desired Outcome

The audit should produce:

1. a compact current-state cost/benefit matrix,
2. a proposed minimum-context workflow,
3. a minimal set of governance/document changes.

Avoid creating a large new governance framework.

## Core Optimization Rule

> Do not load what is not needed. Cache what remains.

And operationally:

> The documentation carries the architecture; the prompt carries the task.

Token efficiency must be improved without weakening architectural correctness or first-time-right reliability.

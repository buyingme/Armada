# CP-xxx: Context Pack Title

Status: Draft  
Purpose:  
This context pack documents the observed implementation before architecture decisions.  
It is evidence of current behavior, not an approved future architecture.  
Supports decisions:  
ADR-xxx Decision Title  
Related task: AT-xxx  
Related boundaries: BC-xxx  
Related gaps: RG-xxx

Context Pack lifecycle:

- Draft: Evidence gathering in progress.
- Under Review: Evidence completeness and correctness are being audited.
- Baseline Evidence: Current implementation is sufficiently understood to support ADR decisions, even when architecture decisions remain open.
- Superseded: Replaced by a newer context pack or accepted architecture documentation.

Allowed status values:

- Draft
- Under Review
- Baseline Evidence
- Superseded

## 1. Purpose

Describe the implementation area being documented.

Explain why this context pack exists:

- Which implementation boundary, subsystem, feature path, or architecture concern is being investigated.
- Which architecture task, boundary candidates, and reality gaps it supports.
- Which ADRs, contracts, test strategies, or follow-up context packs may use it as evidence.

State clearly that this document records current implementation evidence. It does not decide the future architecture.

## 2. Current Implementation

Document what is currently true in the implementation.

Use concrete evidence:

- Files
- Classes
- Functions
- Data files
- Tests
- Runtime flows
- Serialization payloads
- Network/replay paths

Separate facts from assumptions. If something is inferred rather than directly observed, label it as an inference.

Cover the relevant concerns for this context pack. Use only the subsections that apply:

### Static Data

Document static files, schemas, resources, JSON records, imported assets, and catalog metadata.

Include:

- Folder and file locations.
- Stable keys and identifiers.
- Loader paths.
- Data models.
- Which data is display/reference only.
- Which data can become behavior-changing when connected to runtime code.

### Runtime State

Document active state ownership in the current implementation.

Include:

- State classes and fields.
- Where static data becomes runtime state.
- Which fields are durable.
- Which fields are transient.
- Any state that is implied by static data but not currently represented at runtime.

### Command And Validation Paths

Document current command and validation behavior.

Include:

- Command classes.
- Command validation/preflight paths.
- Setup/fleet/runtime validators.
- Rule validators or blockers.
- Whether validation is authoritative gameplay logic or UI-only.

### Rule And Resolver Surfaces

Document observed rule execution surfaces.

Include:

- Registries.
- Resolver classes.
- Helper APIs.
- Direct command logic.
- UI projection hooks.
- Any hybrid ownership currently present.

Do not assume a single surface is authoritative unless an accepted ADR or contract says so.

### Serialization, Save/Load, Replay, And Network

Document how the implementation survives process, save, replay, or network boundaries.

Include:

- `serialize()` / `deserialize()` paths.
- Save/load managers.
- Replay command history.
- Network payloads and state filtering.
- Reconnect behavior.
- Hidden-information rules.
- Static-data lookup assumptions.

### UI And Projection

Document UI-facing behavior only where it affects architecture evidence.

Include:

- Projection classes.
- View intent/payload structures.
- UI-only preview state.
- Local presentation state that is not durable.
- Any UI predicates that could be mistaken for authoritative logic.

### Tests

Document concrete tests that protect or demonstrate the current behavior.

Group tests by concern when useful:

- Static content loading.
- Model parsing.
- Fleet/setup package flows.
- Command validation.
- Rule execution.
- Save/load.
- Replay.
- Network/reconnect.
- UI projection.

If tests exist but are not mapped to accepted architecture invariants, say so explicitly.

## 3. Known Risks

Document observed risks in the current implementation.

A risk is:

- A place where the current implementation may lead to errors.
- Missing protection.
- Unclear ownership.
- Potential future migration difficulty.
- A behavior split across multiple surfaces.
- Metadata that can be mistaken for active behavior.
- UI-only logic that can be mistaken for authoritative behavior.
- Missing or unclear save/load, replay, or network durability.

A risk is not a decision.

Do not prescribe architecture changes in this section. Record what makes the current state risky or fragile.

## 4. Evidence Map

Provide traceability from concerns to evidence.

| Concern | Current evidence | Files/classes | Related IDs |
| --- | --- | --- | --- |
| Example concern | Current observed behavior and what it proves | `path/to/file.gd`, `ClassName`, `function_name()` | AT-xxx, BC-xxx, RG-xxx |

Use this table to make later ADR work auditable. Every high-risk or decision-relevant claim should have at least one evidence row.

## 5. Open Evidence Questions

Only include missing implementation knowledge.

Examples:

- Unknown ownership of runtime state.
- Unknown serialization path.
- Unknown command validation path.
- Unknown test coverage for a current behavior.
- Unknown network/replay behavior.
- Unknown static-data loading path.

Do not include future design choices here.

If there are no unresolved evidence questions, state:

No unresolved evidence questions remain.

## 6. Architecture Decision Questions

Record questions that require ADR decisions.

Examples:

- Who should own a responsibility?
- Which boundary should become authoritative?
- Should a hybrid approach remain or be replaced?
- Which behavior should become contract-protected?
- Which migration path should be accepted?
- Which test obligations should become required?

These questions can remain open while the context pack is marked Baseline Evidence.

## 7. Next Recommended Steps

Reference likely follow-up work without prescribing architecture changes.

Examples:

- ADR-xxx decision analysis.
- CON-xxx contract draft after owner decision.
- TEST-xxx test strategy.
- Additional context pack for a neighboring boundary.
- Documentation update after accepted ADR/contract.

Keep recommendations scoped to process and evidence flow. Do not use this section to decide future architecture.

## Baseline Evidence Guidance

A context pack becomes Baseline Evidence when current implementation understanding is sufficient to support architecture decisions.

Baseline Evidence does not mean:

- The future architecture is decided.
- The current implementation is approved as the target architecture.
- Existing risks are resolved.
- Contracts or tests already exist.

Baseline Evidence means:

- The relevant implementation paths have been traced.
- Important evidence has been mapped to files/classes/functions/tests.
- Open questions are decision questions rather than missing implementation evidence.
- ADR work can proceed without more discovery as a prerequisite.

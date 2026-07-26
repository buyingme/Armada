# DR-001 — CON-006 Owner Decision Record

Status: Accepted

Supports:
- CON-006 (Attack Declaration Lifecycle Contract)

Date:
- 2026-07-26

---

# Purpose

This document records the Project Owner decisions made during the architectural review of the Attack Declaration Lifecycle.

It is **not** an authoritative architecture document.

Its purpose is to preserve the reasoning and accepted decisions that guide the revision and acceptance of CON-006.

Normative requirements belong exclusively in CON-006 and other accepted architecture documents.

---

# Background

The original CAP-ATTACK-001 underwent:

1. Forensic analysis
2. Architecture review
3. Revision workbook

The revision workbook concluded that the document should not become a new Architecture Capability document but instead be reclassified as:

**CON-006 – Attack Declaration Lifecycle Contract**

This Owner Decision Record captures the remaining architectural decisions required before drafting CON-006.

---

# Decision D-01 — Document Classification

Status: Accepted

Decision:

Reclassify CAP-ATTACK-001 as:

**CON-006 – Attack Declaration Lifecycle Contract**

Store under:

```
docs/architecture/contracts/
```

No new architecture document type shall be introduced.

Rationale:

The lifecycle is a behavioral contract rather than a capability specification. Existing Contract governance already provides the appropriate architectural home.

---

# Decision D-02 — Scope Boundary

Status: Accepted

Decision:

CON-006 governs only authoritative gameplay attack declaration.

Simulator functionality is explicitly outside the normative scope of the contract.

However, nothing in CON-006 shall prevent future simulator workflows, preview systems, or analysis tools from consuming the declaration interaction.

Rationale:

Gameplay authority and simulator behavior have different architectural responsibilities.

---

# Decision D-03 — Adjacent Authority Ownership

Status: Accepted

Decision:

CON-006 shall not assume ownership of gameplay state already owned elsewhere.

BeginAttackCommand coordinates existing authoritative owners but does not replace them.

Examples include:

- activation ownership
- hull zone ownership
- squadron attack history
- attack availability
- other authoritative gameplay state

CON-006 shall include an Adjacent Authority Matrix documenting:

- owner
- validated state
- coordinated mutations
- derived information

Rationale:

Preserves existing ownership boundaries while providing deterministic coordination.

---

# Decision D-04 — Skip Semantics

Status: Accepted

Decision:

SkipAttackCommand is an authoritative semantic command.

It commits the current declaration opportunity.

It is:

- replayable
- persisted
- network authoritative
- exactly-once

CON-006 shall define a Skip Effect Matrix describing the authoritative effects for each supported declaration context.

Rationale:

Skipping is gameplay state, not merely UI interaction.

---

# Decision D-05 — Preview / Begin Semantic Parity

Status: Accepted

Decision:

Given identical authoritative game state and identical declaration intent:

Preview and BeginAttackCommand shall produce identical gameplay legality.

This includes:

- legality
- target eligibility
- range
- obstruction
- attack pool determination
- rejection category

BeginAttackCommand may additionally reject due to transactional concerns including:

- stale state
- replay ordering
- controller changes
- concurrent mutations

Implementation sharing is not required.

Behavioral equivalence is required.

Rationale:

Architecture specifies behavior, not implementation.

---

# Decision D-06 — Repository Compatibility Policy

Status: Accepted

Decision:

Authoritative gameplay state shall never be reconstructed through inference.

Compatibility policy:

- Equivalent representation → Accept.
- Deterministic migration → Migrate.
- Ambiguous representation → Reject.

Authority shall never be inferred from:

- projections
- UI state
- interaction flow
- heuristics

Rationale:

Preserves replay determinism and authoritative state ownership.

---

# Decision D-07 — Migration Strategy

Status: Accepted

Decision:

Repository migrations shall distinguish:

## Implementation Slices

Behavior-inert implementation work that may be merged independently.

Examples:

- helper methods
- validators
- UI plumbing
- projections
- tests
- serialization support

## Semantic Slices

Behavior-changing architectural activation points.

Authoritative gameplay behavior changes only at explicit semantic cutover points.

Rollback is unrestricted before cutover.

Rollback after cutover requires an explicit compatibility strategy.

Rationale:

Allows incremental implementation while preserving deterministic behavior.

---

# Summary

The Project Owner accepted seven architectural decisions before drafting CON-006.

These decisions provide the architectural direction required to revise the original CAP into the authoritative Attack Declaration Lifecycle Contract.

The decisions in this record are supporting evidence only.

Normative requirements shall be incorporated into CON-006.

# Implementation Efficiency Log

## Purpose

Record empirical cost and workflow observations from significant implementation
work packages.

This log is development-process evidence, not architecture or implementation
authority. Its purpose is to improve future Codex task sizing, model selection,
context usage, and first-time-right implementation efficiency.

Credits are approximate and should be treated as comparative observations rather
than precise accounting.

---

## MATCH-001 — Player-Principal Binding

**Date:** 2026-08-18
**Work type:** Cross-cutting architecture implementation
**Result:** Accepted / committed
**Approximate Codex cost:** 190 credits

### Scope delivered

- canonical match-lifetime player-principal binding
- GameState ownership and serialization
- Hot-Seat and Network bootstrap/reconstruction
- Network principal authorization
- save format v4
- replay format v6
- network protocol v2
- replay baseline renewal
- BUG-034 diagnosis and repair
- repository test-fixture migration
- final convergence to 4069/4069 tests

### Efficiency assessment

**Overall:** Good

The absolute cost was high, but proportionate to a cross-cutting change affecting
state ownership, bootstrap, serialization, replay, networking, fixtures, and
repository-wide verification.

### Cost drivers

**Necessary**
- cross-cutting canonical-state implementation
- save/replay/protocol transitions
- BUG-034 investigation and repair
- baseline regeneration and verification

**Potentially avoidable**
- broad post-implementation test-fixture migration
- multiple convergence passes from 280 → 38 → 10 → 0 failures

### Main learning

When introducing a new mandatory canonical invariant, the implementation workbook
should inventory not only production construction/reconstruction seams but also:

- shared test factories
- direct GameState construction in tests
- serialized test fixtures
- save/replay fixtures
- bootstrap mocks/stubs

These migrations should be part of the initial implementation scope.

### Future application

For comparable cross-cutting work:

1. inventory production and test construction seams before implementation;
2. include fixture migration explicitly in the accepted workbook;
3. preserve strict production invariants rather than adding test conveniences;
4. run a representative broad test slice early after the canonical invariant is
   introduced;
5. use the least costly Codex capability that reliably fits each stage.

### Benchmark

~190 credits for this work package.

Use as an initial comparison point for future architecture-governed implementation
packages; do not yet treat it as a predictive norm.

(304 credits left after MATCH-001)



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

---

## CON-007 — Post-Attack Continuation Release

**Date:** 2026-08-19
**Work type:** Architecture decision and contract development
**Result:** Accepted / committed
**Approximate Codex cost:** TBD

### Scope delivered

- investigated ADR-007 Entry Gate B continuation prerequisites
- distinguished missing implementation from missing architecture
- created UX-005 post-attack continuation ownership decision workbook
- resolved six Project Owner decisions (PAC-OD-001–006)
- established context-specific continuation ownership
- established the existing CommandProcessor post-success seam as the live-authority
  release evaluator
- preserved existing entity-local progress owners and semantic commands
- created and audited CON-007 Post-Attack Continuation Release Contract
- clarified ADR-007 Entry Gate B interpretation
- established authoritative continuation mappings for:
  - normal ship attacks
  - ship anti-squadron iteration
  - Squadron Phase squadron attacks
  - ship-commanded squadron attacks
- established atomic exact-once inspection-consumption requirements
- established replay, mirror, save/load, and reconnect requirements
- enabled ADR-007 Entry Gate B to pass for UX-005 implementation planning

### Efficiency assessment

**Overall:** Good

Several iterations were required to distinguish an implementation prerequisite
from a genuine architecture prerequisite, but the resulting decision and contract
work removed an important ambiguity before UX-005 implementation.

The work avoided introducing a universal continuation owner or generic
continuation framework and established a narrow architecture that could reuse
existing semantic transactions.

### Cost drivers

**Necessary**
- repository evidence tracing across four post-attack contexts
- clarification of ADR-007 Entry Gate B
- Project Owner decisions on continuation ownership
- CON-007 drafting and architecture audit
- exact-once, replay, mirror, and reconstruction analysis

**Potentially avoidable**
- initial Gate B iterations treated missing future implementation as evidence
  that the architecture gate could not pass
- repeated seam investigation before the distinction between architecture
  readiness and implementation proof was made explicit

### Main learning

Architecture entry gates must distinguish between:

- architecture that must already exist before implementation can be authorized;
  and
- behavior that the accepted architecture explicitly authorizes the upcoming
  implementation to introduce.

A gate should not require the future implementation itself as evidence of
architecture readiness.

For continuation-heavy gameplay, ownership should be established before
implementation at the level of existing semantic transactions and canonical
state, without automatically introducing a generalized continuation framework.

### Future application

For comparable architecture-gated work:

1. classify every failed gate condition as architecture prerequisite,
   implementation prerequisite, or future verification obligation;
2. stop for Project Owner decisions only when ownership or semantics are
   genuinely unresolved;
3. prefer existing semantic commands and canonical owners over new generic
   abstractions;
4. define exact-once, replay, mirror, and reconstruction behavior before
   implementation;
5. once the architecture is accepted, treat missing authorized behavior as
   implementation work rather than repeatedly reopening the gate.

### Benchmark

Cost TBD.

Use primarily as a process benchmark for bounded architecture clarification and
contract development rather than as an implementation-cost benchmark.

---

## UX-005 — Completed-Attack Result Inspection

**Date:** 2026-08-19
**Work type:** Cross-cutting architecture-governed implementation
**Result:** Implementation complete; final acceptance deferred pending BUG-035 and manual QA
**Approximate Codex cost:** TBD

### Scope delivered

- UX-005 implementation workbook and substantial refinement
- four-context Gate B seam mapping
- completed-attack inspection canonical state
- replayable `AcknowledgeAttackResultCommand`
- acknowledgement satisfaction lifecycle
- atomic exact-once inspection consumption
- normal ship continuation integration
- ship anti-squadron continuation integration
- Squadron Phase continuation integration
- ship-commanded squadron continuation integration
- CommandProcessor live-authority release integration
- UI projection and recovery integration
- save/load and reconnect reconstruction
- replay and passive-mirror handling
- save format v5
- replay format v7
- network protocol v3
- mixed-version rejection requirements
- test-fixture and builder migration
- save eligibility coverage
- stale/duplicate continuation protection
- anti-squadron ownership correction:
  `CompleteAttackCommand` completes the individual attack while
  `SkipAttackCommand(squadron_done)` owns iteration closure
- initial automated convergence to 4069/4069 tests

### Efficiency assessment

**Overall:** Mixed

The canonical-state, command, persistence, replay, and network implementation was
strongly specified and converged successfully.

The implementation workbook benefited materially from architecture audit before
execution. That audit identified missing seam tracing, protocol justification,
fixture migration, reconstruction ordering, exact-once consumer mapping, and save
eligibility before implementation began.

However, subsequent manual QA exposed that the specification was substantially
stronger for canonical lifecycle semantics than for the exact player-visible UI
interaction expected after canonical continuation.

### Cost drivers

**Necessary**
- cross-cutting canonical inspection lifecycle
- four-context continuation integration
- save/replay/protocol version transitions
- persistence and reconstruction handling
- fixture migration
- exact-once and duplicate/stale protection
- anti-squadron ownership clarification discovered at implementation stop
- full-suite convergence

**Potentially avoidable**
- implementation began without a durable normative specification of the
  player-visible interaction required after each post-attack canonical state
- automated verification concentrated more strongly on canonical state,
  commands, and individual controller behavior than complete production UI
  interaction transitions
- this specification gap subsequently transferred significant convergence cost
  into BUG-035

### Main learning

For gameplay changes that alter continuation between UI interaction surfaces,
canonical-state and command specifications are necessary but not sufficient.

The implementation specification should also define, for each meaningful
canonical post-command state:

- which interaction surface must be visible;
- which interaction surfaces must not remain visible;
- which player actions must be available;
- which targets/options must be selectable;
- which semantic command each accepted action submits;
- what interaction state must follow that command.

Without this interaction contract, implementation and tests can converge on
internally consistent canonical behavior while still failing the intended manual
gameplay flow.

### Future application

For comparable gameplay-flow implementations:

1. retain the existing architecture-first treatment of canonical ownership,
   commands, replay, networking, and persistence;
2. inventory affected gameplay interaction surfaces before implementation;
3. define the expected UI projection for each meaningful canonical state;
4. include complete production interaction transitions in the implementation
   workbook or referenced UI requirements;
5. ensure regression tests exercise the real production projection path rather
   than only direct command/controller fixtures;
6. preserve manual gameplay QA as an acceptance gate for interaction-heavy
   changes.

### Benchmark

Cost TBD.

Treat UX-005 together with BUG-035 when evaluating the total cost of introducing
a new canonical lifecycle that changes existing gameplay interaction flow.

---

## BUG-035 — Post-Attack Interaction Recovery Convergence

**Date:** 2026-08-19 to 2026-08-20
**Work type:** Gameplay-flow defect investigation and repeated implementation/QA convergence
**Result:** Open; implementation repair deferred pending explicit UI-behavior specification
**Approximate Codex cost:** TBD

### Scope investigated and repaired

- initial post-acknowledgement gameplay stall
- normal ship second-attack presentation recovery
- ship-commanded squadron post-attack recovery
- canonical Squadron opportunity reprojection
- terminal Squadron-command capacity handling
- prevention of impossible `activation N+1 of N` presentation
- Squadron Phase post-attack selector recovery
- command-success-driven Squadron Phase projection
- normal ship legal versus no-legal-second-attack continuation
- duplicate Hot-Seat `resolve_damage` synchronous re-entry
- recovery-branch and regression-coverage audit
- commanded-squadron movement-legality correction using canonical
  `SquadronKeywordRuleHelper.can_move_with_heavy_rule`
- token-only terminal Squadron-command recovery
- dial-commanded squadron legal-movement preservation
- replay/passive-mirror non-synthesis coverage
- anti-squadron remaining/exhausted target recovery
- authoritative anti-squadron target legality through
  `TargetingListBuilder.authoritative_attack_entry`
- repeated expansion of production-resume regression coverage

Automated convergence points included:

- 4070/4070 tests
- 4074/4074 tests
- 4078/4078 tests
- 4081/4081 tests

Each convergence point remained architecture-lint and `git diff --check` clean.

### Efficiency assessment

**Overall:** Poor, with high-value process learning

The individual repairs were generally narrow and architecture-conformant, and
automated verification repeatedly reached a completely green repository.

Nevertheless, manual Hot-Seat testing repeatedly exposed adjacent interaction
failures immediately after green-suite convergence.

The dominant inefficiency was therefore not failure to run sufficient automated
tests. It was a test-reality and specification gap: neither Codex nor the tests
had a sufficiently explicit normative description of the complete intended
player interaction after each canonical post-attack state.

As a result, implementation repeatedly repaired the production path that could
be inferred from existing code, tests encoded the same inferred behavior, the
suite became green, and manual gameplay then exposed another missing interaction
transition.

### Cost drivers

**Necessary**
- diagnosis of genuinely different continuation contexts
- production-path tracing
- canonical movement-legality correction
- anti-squadron target-legality correction
- synchronous Hot-Seat race diagnosis
- replay/mirror verification
- repeated manual gameplay evidence
- recovery-branch coverage audit

**Potentially avoidable**
- multiple symptom-specific repair cycles before the branch structure was
  systematically audited
- automated tests that exercised simplified command/controller paths rather than
  the exact production UI lifecycle
- treating conceptual context coverage as equivalent to production branch
  coverage
- insufficient distinction between nominal action availability and canonical
  action legality
- repeated inference of intended UI behavior from existing callback code
- absence of an explicit inventory and normative specification of active gameplay
  interaction surfaces and transitions

### Main learning

A green automated suite does not establish gameplay-flow correctness when the
intended UI interaction is not independently specified.

For interaction-heavy gameplay, tests can unintentionally reproduce the same
assumptions as the implementation. This creates false convergence:

implementation
→ regression test
→ full suite green
→ manual gameplay
→ adjacent interaction failure.

The required corrective strategy is to establish an independent UI interaction
specification before further BUG-035 repair.

The specification should derive from both repository evidence and Project Owner
intent and should describe:

canonical state
→ required visible interaction surfaces
→ legal player actions
→ semantic command
→ required next interaction state.

The UI specification must remain a projection of canonical gameplay authority;
it must not become a second gameplay-state authority.

### Future application

For gameplay features with significant UI continuation behavior:

1. inventory all affected active-gameplay modals, selectors, panels, overlays,
   prompts, and interaction surfaces;
2. map the existing gameplay interaction flow;
3. distinguish repository-observed behavior from Project Owner intended behavior;
4. create a normative UI interaction-state specification before implementation;
5. explicitly model remaining-opportunity and terminal branches;
6. test real production transitions from canonical state through visible UI and
   player action to semantic command;
7. include branch intersections, not only individual branch dimensions;
8. use manual gameplay QA to validate the specification itself before declaring
   convergence;
9. when repeated green-suite/manual-QA divergence occurs, stop local patching and
   reassess specification and test-model completeness.

### Current process decision

Further BUG-035 closure work is deferred.

Before another repair cycle:

1. create an inventory of all active-gameplay interaction surfaces;
2. map the typical gameplay/UI flow;
3. review current behavior against Project Owner intent;
4. establish a durable normative UI interaction-state specification;
5. use that specification as the target for subsequent BUG-035 convergence.

### Combined post-MATCH-001 cost observation

The combined CON-007 architecture work, UX-005 implementation, and subsequent
BUG-035 convergence work consumed approximately **500 Codex credits**.

The individual allocation between CON-007, UX-005, and BUG-035 was not measured
reliably and should not be reconstructed retrospectively.

For comparison, the complete MATCH-001 implementation stage consumed
approximately **190 credits**.

The post-MATCH-001 UX-005 work therefore consumed approximately **2.6× the
MATCH-001 implementation-stage benchmark** without yet reaching final manual
acceptance.

This is considered a significant efficiency warning.

The principal observed cost escalation was repeated BUG-035 convergence:

implementation repair
→ expanded automated regression coverage
→ full-suite convergence
→ immediate manual discovery of another interaction defect.

After repeated occurrences, further local repair was suspended in favor of
establishing an explicit active-gameplay UI interaction specification.

### Process intervention

For future work, repeated automated convergence followed by manual falsification
should trigger an early specification/test-reality review.

As a default heuristic, after approximately **two materially similar
green-suite/manual-QA convergence failures**, stop further symptom-specific
repair and assess:

1. whether intended behavior is explicitly specified;
2. whether automated tests exercise the real production interaction path;
3. whether relevant branch intersections have been identified;
4. whether Codex is being forced to infer product/UX intent from existing code.

Resume implementation only after the missing specification or test-model gap is
understood.

credits left approx 750. (30 Euro)

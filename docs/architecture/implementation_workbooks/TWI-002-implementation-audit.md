# TWI-002 Architecture Audit Report

Audit scope: the current working-tree implementation, including the completed but uncommitted TWI-002 changes. This is not an audit of `HEAD` alone. The audit was read-only; no code or architecture changes were made.

## Startup documents read

Before inspecting the TWI-002 authorities or implementation, I read these startup documents in full, in this order:

1. [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md:1)
2. [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md:1)
3. [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md:1)
4. [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md:1)
5. [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md:1)
6. [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md:1)
7. [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md:1)

I then read the complete accepted authority set required by TWI-002:

- [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md:1)
- [ADR-003](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md:1)
- [ADR-004](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md:1)
- [ADR-005](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md:1)
- [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:1)
- [CON-003](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-003-rule-capability-contract.md:1)
- [CON-004](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-004-upgrade-runtime-contract.md:1)
- [CON-005](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-005-timing-window-implementation-contract.md:1)
- [TEST-003](/Users/Katharina/godot/Armada/docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md:1)
- [TWI-001](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/TWI-001-timing-window-state-implementation-workbook.md:1)
- [TWI-002](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md:1)

I also read the complete TWI-002 execution companion and inspected CAP-H9 as non-authoritative evidence. CAP-H9 correctly remains Draft/NOT_INTEGRATED.

## 1. Overall Rating

**Implementation readiness: 9.1/10**

**Confidence: High — approximately 94%**

The implementation is architecturally sound. Canonical ownership, command authority, continuation, persistence, replay, networking, projection, H9, ECM, and controller boundaries match the accepted architecture.

No blocking or high-severity architecture violations were found. No ownership leaks were found.

One narrow but direct TWI-002 protocol deviation exists: H9 and Concentrate Fire source enumeration performs some opportunity-legality filtering that the accepted workbook assigns to the subsequent derivation step. Current behavior remains correct and deterministic, but this teaches the wrong participant boundary to future timing-window implementations.

## 2. Architecture Compliance

| Accepted authority | Rating | Finding |
|---|---|---|
| ADR-001 | **Fully compliant** | `GameState` is the sole canonical owner of `CurrentAttackState`; semantic transitions are command-owned. Scenes, flow, and UI consume derived state. |
| ADR-003 | **Fully compliant** | Rule surfaces remain explicit and registered. Registry metadata is not treated as integration proof, and CAP-H9 remains Draft/NOT_INTEGRATED. |
| ADR-004 | **Fully compliant** | Runtime upgrades are owned by `ShipInstance`, identified by stable `runtime_upgrade_id`, use static `data_key` lookup, and serialize mutable JSON-safe state. |
| ADR-005 | **Fully compliant** | `GameState` owns lifecycle state; the orchestrator owns window behavior, re-derivation, continuation, and cleanup coordination. Commands own semantic mutation. |
| CON-001 | **Fully compliant** | Current-attack identity, dice, stage, CF status, defense state, and completion are canonical and replayable. Model C-S mirrors are one-way. |
| CON-003 | **Fully compliant** | RuleRegistry use and CAP traceability remain within contract. The implementation does not falsely advance H9 integration status. |
| CON-004 | **Fully compliant** | H9 and ECM guards remain on their owning runtime-upgrade instances and survive save, replay, and network reconstruction. |
| CON-005 | **Fully compliant** | All mandatory ownership, lifecycle, blocking, re-derivation, continuation, projection, serialization, reconnect, and failure-preservation behavior is implemented. |
| TEST-003 | **Fully compliant** | Required shared, H9-specific, production-route, replay, save/load, network, reconnect, projection, and failure evidence is executable and passing. |
| TWI-001 | **Fully compliant** | Slice 1 ownership and serialization semantics remain intact. `TimingWindowState` has not accumulated opportunities, UI state, runtime rules, or commands. |
| TWI-002 | **Mostly compliant** | All functional slices are present. The source-enumeration/derivation split is not implemented exactly as specified, and implementation work added a non-authoritative execution companion under `docs/architecture`. |

### Supporting evidence

- [`GameState`](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:46) owns both canonical state objects, clones them at its public boundary, and serializes/reconstructs them.
- [`TimingWindowState`](/Users/Katharina/godot/Armada/src/core/state/timing_window_state.gd:48) explicitly excludes rule, opportunity, command, and presentation authority.
- The [`TimingWindowOrchestrator`](/Users/Katharina/godot/Armada/src/core/timing_windows/timing_window_orchestrator.gd:38) owns opening, replacement, re-derivation, blocker determination, completion, continuation creation, reconstruction, and cleanup.
- [`CommandProcessor`](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:237) provides the single ordered post-success orchestration seam and preserves command sequence identity.
- [`RuleRegistry`](/Users/Katharina/godot/Armada/src/core/effects/rule_registry.gd:141) is a static participant index only.
- [`ShipInstance`](/Users/Katharina/godot/Armada/src/core/entities/ship_instance.gd:531) owns runtime-upgrade construction, state, serialization, and reconstruction.
- [`UIProjector`](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:405) derives timing-window presentation and controller-only intents without mutating authority.

### Verification performed

- Full repository suite: **3,959/3,959 tests passed**, across 237 scripts and 11,619 assertions.
- Hot-seat baseline trace and state comparison: passed.
- Two-process network baseline and host/client state equality: passed.
- Network state hash: `09d7f126124b01d4c061435eede6b119088dc87b28ac51b8822151dc68e6b21e`.
- Phase-K architecture lint: zero new violations; four existing allow-listed findings.
- Diff whitespace/error check: passed.

## 3. Workbook Compliance

### Implemented requirements

All functional TWI-002 slices are present:

- Immutable timing-window definitions.
- Static RuleRegistry participant discovery.
- Canonical derived opportunity schema.
- Stateless timing-window orchestration.
- Replayable explicit use and decline commands.
- Controller-aware projection and live routing.
- Canonical `CurrentAttackState` Model C-S migration.
- Concentrate Fire as a shared timing-window participant.
- H9 as the first clean runtime-upgrade participant.
- Production `ATTACK_MODIFY` opening after successful ship dice rolling.
- Orchestrator-owned ship confirmation continuation.
- Inactive direct confirmation retained only for squadron attacks.
- Atomic save version 1→2 and replay format 3→4 boundaries.
- Rejection of incompatible save, replay, and reconnect state.
- Host, mirror, replay, save/load, reconnect, and production-scene evidence.
- Swarm behavior preserved.
- Tarkin and ECM production behavior preserved.
- CAP-H9 left Draft/NOT_INTEGRATED.

### Partially implemented requirement

The accepted workbook defines source enumeration as returning only stable authoritative source identities. Concrete activation and dice legality must be evaluated later during opportunity derivation ([TWI-002 §11.5](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md:998)).

The current implementation filters too early:

- [`H9.enumerate_timing_window_sources()`](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd:43) calls `_is_h9_source_on_ship()`, which excludes discarded or disabled matching runtime instances during enumeration.
- The workbook explicitly requires every matching H9 runtime identity to be enumerated in `runtime_upgrade_id` order, with activation legality checked during derivation.
- The H9 function iterates `runtime_upgrades` directly and relies on the orchestrator’s later sorting rather than returning the required ordering itself.
- [`ConcentrateFireToken.enumerate_timing_window_sources()`](/Users/Katharina/godot/Armada/src/core/effects/rules/concentrate_fire_token.gd:36) calls `pending_source()`, which evaluates attack stage, CF resolution state, lifecycle context, and token legality before returning the source identity.

This does not create mutable authority or incorrect results. It is nevertheless a direct implementation-protocol deviation and a shortcut future participants could copy.

### Omitted requirements

No functional TWI-002 capability is omitted.

The narrow omission is focused evidence proving the raw enumeration boundary independently of opportunity derivation—for example, proving that an existing but currently ineligible H9 source is still enumerated while deriving zero opportunities.

### Other implementation deviation

Commit `e9d2f5e` added [TWI-002-remaining-implementation-execution-map.md](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/TWI-002-remaining-implementation-execution-map.md:1) alongside implementation work. It correctly labels itself an “Execution Companion” and does not amend an accepted authority, but this does not literally satisfy the workbook checklist item that no CAP or architecture document be modified by implementation work.

This is scope/document hygiene, not a runtime architecture violation.

## 4. Ownership Audit

| Surface | Required owner | Observed owner | Result |
|---|---|---|---|
| `TimingWindowState` | `GameState` | `GameState`, mutated through the orchestrator boundary | No leak |
| `CurrentAttackState` | `GameState` | `GameState`, mutated by replayable semantic commands | No leak |
| Runtime upgrades and guards | Owning `ShipInstance` | `ShipInstance.runtime_upgrades` | No leak |
| RuleRegistry | Static participant candidates only | Static descriptors and rule scripts | No leak |
| Timing Window Orchestrator | Lifecycle, derivation, blocker, completion, continuation | `TimingWindowOrchestrator` | No leak |
| GameManager | Composition, submission, ordered mirror integration | `GameManager` | No leak |
| InteractionFlow | Non-authoritative compatibility mirror | Derived flow state; not used as semantic attack authority | No leak |
| UIProjector | Derived viewer-specific projection | `UIProjector` | No leak |
| Controllers | Intent submission and transient UI selection | Controllers submit commands; no canonical writes | No leak |
| Scenes | Presentation and orchestration adapters | Scene-local caches mirror canonical state | No leak |
| Semantic commands | Rule and attack mutations | Registered replayable commands | Correct |
| Continuation | Orchestrator chooses; command stream executes | Orchestrator plus ordered processor follow-up | Correct |

`PublishAttackFlowCommand` remains as compatibility projection handling, but semantic attack reconstruction does not depend on it. Its presence is therefore not an authority leak.

## 5. Implementation Risks

### BLOCKING

None.

### HIGH

None.

### MEDIUM

**M-1 — Participant source enumeration performs derivation work**

H9 and Concentrate Fire filter concrete legality during source enumeration. This contradicts the accepted TWI-002 participant protocol even though the final opportunities are currently correct.

Impact:

- Establishes the wrong example for future participant implementations.
- Makes it harder to test source existence separately from current opportunity eligibility.
- Risks participant-specific drift in re-derivation behavior.

### LOW

**L-1 — Architecture-tree execution companion added during implementation**

A non-authoritative architecture execution companion was added in an implementation commit despite the workbook’s literal scope checklist. It does not change architectural authority or runtime behavior.

## 6. Positive Findings

- Canonical ownership is exceptionally clean: neither scenes nor `InteractionFlow` can become a second attack-state authority.
- The orchestrator is stateless and derives fresh opportunities from canonical state after every relevant success.
- Live execution, mirroring, and replay correctly avoid duplicate continuation synthesis.
- Ship confirmation is correctly restricted: orchestrator-owned for active ship timing windows and direct only for inactive squadron attacks.
- Failure paths preserve active/closing timing state instead of silently skipping blockers.
- H9 use mutates the canonical die and runtime guard atomically, with rollback on failure.
- H9 and CF both provide explicit replayable use and decline paths.
- Runtime-upgrade identities and rule state survive serialization without embedding scripts or scene objects.
- Save and replay format changes reject obsolete formats before deserialization or command application.
- Network ordering broadcasts the authoritative command before draining generated continuation commands.
- ECM cleanup is verified across hot-seat, host/mirror, and replay in [the shared protocol integration test](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:817).
- H9’s CAP and resource metadata correctly remain NOT_INTEGRATED; implementation evidence has not been mistaken for owner acceptance.

## 7. Required Corrections

Only these corrections are necessary for exact architectural/workbook compliance:

1. Make H9 source enumeration return every matching authoritative H9 runtime-upgrade identity in `runtime_upgrade_id` order. Move discarded, disabled, guard, activation, and dice legality checks into derivation.

2. Separate Concentrate Fire source identity resolution from current opportunity legality. Enumeration may establish that the authoritative ship/token source exists; stage, resolution-pending, continuation-context, and other activation checks belong in derivation.

3. Add focused tests that call source enumeration independently and prove:

   - an existing but currently ineligible source is still enumerated;
   - derivation returns no opportunity for that source;
   - H9 enumeration ordering is by `runtime_upgrade_id`.

4. For literal workbook scope compliance, remove or relocate the execution companion from the implementation change, or have the Project Owner accept it separately as planning evidence. No accepted ADR, Contract, TEST document, CAP, or workbook content needs to change.

No other refactoring or architectural redesign is required.

## 8. Acceptance Recommendation

**Accept with very small corrections**

Estimated correction profile:

- **Implementation effort:** approximately 3–6 hours, including focused tests.
- **Architectural risk:** Low.
- **Regression risk:** Low; localized to H9/CF discovery, with strong existing integration coverage.
- **Documentation correction:** Less than one hour or a Project Owner scope decision.

The implementation should not be rejected or subjected to broad refinement. Its authority and ownership model faithfully implements the accepted architecture. The required code correction is a narrow responsibility-boundary adjustment, not a change to behavior or architectural design.


## 9. Owner Decision Review

Owner review date: 2026-08-07
Decision authority: Project Owner

The Project Owner reviewed the remaining audit findings after accepting the overall audit conclusion that the TWI-002 implementation is architecturally sound and requires only very small refinement.

### OD-001 — M-1 Participant source enumeration performs derivation work

**Decision:** Accept finding. Targeted implementation refinement required.

**Rationale:**

The accepted TWI-002 workbook intentionally separates stable source enumeration from opportunity derivation. Although the current H9 and Concentrate Fire implementations are deterministic and functionally correct, retaining legality filtering during source enumeration would establish the wrong participant pattern for future timing-window integrations.

Preserving the workbook boundary provides the stronger long-term implementation model:

- enumeration returns stable authoritative source identities only;
- derivation evaluates activation, rule, lifecycle, guard, dice, and other current-opportunity legality;
- raw source existence can be tested independently from opportunity availability; and
- future timing-window participants have one consistent protocol to follow.

The correction SHALL remain narrow. It SHALL NOT redesign the timing-window architecture, change gameplay semantics, alter accepted ownership, or introduce unrelated refactoring.

**Required action:**

1. Refine H9 source enumeration so every matching authoritative H9 runtime-upgrade identity is enumerated in `runtime_upgrade_id` order, independent of current activation legality.
2. Move discarded, disabled, guard, activation, dice, and equivalent current-opportunity checks to derivation.
3. Separate Concentrate Fire source identity enumeration from stage, resolution, lifecycle-context, token-legality, and other opportunity checks, leaving those checks in derivation.
4. Add focused tests proving source enumeration independently from opportunity derivation, including deterministic H9 ordering.
5. Run targeted verification and existing affected integration/regression tests.

**Owner disposition:** OPEN — resolve before final TWI-002 implementation acceptance and commit.

### OD-002 — L-1 Architecture-tree execution companion added during implementation

**Decision:** No implementation correction required. Execution companion accepted as non-authoritative implementation evidence.

**Rationale:**

The execution companion is explicitly non-authoritative, does not amend an accepted ADR, Contract, TEST document, CAP, or implementation workbook, and preserves the authority of TWI-002 as the sole implementation specification. It provides useful implementation-planning and execution evidence without creating a second architecture or governance surface.

Removing or relocating the document would reduce useful implementation history without improving architectural correctness.

For TWI-002, the Project Owner therefore accepts the execution companion in its current location as implementation evidence. This Owner decision applies to this audit disposition and does not by itself amend accepted Development Architecture or create a new general document class or workflow requirement.

**Required action:** None.

**Owner disposition:** CLOSED — accepted by Project Owner.

### Owner Review Outcome

The audit recommendation remains:

**Accept with very small corrections.**

Only OD-001 / M-1 requires implementation work. OD-002 / L-1 is resolved by Owner decision and requires no repository change.

After OD-001 is implemented, perform the targeted verification defined by this audit. If the verification passes, append a Resolution section documenting the implementation outcome and final acceptance before committing TWI-002.


## Resolution

Resolution date: 2026-08-09

Owner decision source: Section 9, Owner Decision Review, in this document.

### OD-001 / M-1 Implementation Outcome

The participant source-enumeration boundary was refined without changing
gameplay semantics or accepted ownership:

- H9 source enumeration now resolves every matching authoritative H9 runtime
  upgrade on the canonical attacking ship without filtering discarded,
  disabled, guard, activation, or dice legality. It returns source identities
  in deterministic `runtime_upgrade_id` order. Existing H9 opportunity
  derivation retains all current-opportunity legality checks.
- Concentrate Fire source enumeration now resolves the authoritative attacking
  ship/token source identity without filtering attack stage,
  resolution-pending state, timing lifecycle/continuation context, or token
  legality. Existing Concentrate Fire opportunity derivation retains those
  legality checks.
- No lifecycle, continuation, command, RuleRegistry, serialization, save,
  replay, network, projection, or controller ownership changed.

### Focused Evidence Added

- `test_ineligible_h9_source_enumerates_but_derives_no_opportunity`
- `test_h9_source_enumeration_orders_runtime_ids_deterministically`
- `test_resolved_source_enumerates_but_derives_no_opportunity`
- `test_ship_without_concentrate_fire_token_derives_no_opportunity` now also
  proves that the authoritative source remains enumerated while derivation
  produces no opportunity.

The existing eligible H9 and Concentrate Fire behavior tests remain unchanged
in outcome and pass.

### Verification Performed

- H9 focused unit suite: 19/19 passing, 277 assertions.
- Concentrate Fire focused unit suite: 17/17 passing, 192 assertions.
- H9 shared protocol integration suite: 5/5 passing, 182 assertions.
- Concentrate Fire shared protocol integration suite: 2/2 passing, 38
  assertions.
- Shared timing-window protocol integration suite: 7/7 passing, 84 assertions.
- Full repository suite: 237 scripts, 3,962/3,962 tests passing, 11,651
  assertions.
- Hot-seat baseline trace and state: passing.
- Network baseline peer equality: passing; state hash
  `09d7f126124b01d4c061435eede6b119088dc87b28ac51b8822151dc68e6b21e`.
- Phase-K architecture lint: zero violations, with four existing allow-listed
  branches.
- `git diff --check`: passing.

### Technical Disposition

M-1 is technically **RESOLVED**. The implementation now matches the accepted
TWI-002 Section 11.5 source-enumeration/opportunity-derivation boundary, and
the focused tests protect that distinction independently.

This technical resolution completed the remaining implementation work required
before final TWI-002 Project Owner acceptance. OD-002 / L-1 required no
implementation change, and no unrelated architecture, behavior, or TWI-003
work was introduced.

### Final Project Owner Acceptance

Project Owner acceptance date: 2026-08-09

The Project Owner accepts the completed TWI-002 implementation.

- OD-001 / M-1: RESOLVED and verified.
- OD-002 / L-1: CLOSED by Owner decision.
- No BLOCKING, HIGH, MEDIUM, or unresolved required corrections remain.
- Required automated, baseline, network, lint, and diff verification passes.
- TWI-002 implementation status: COMPLETE AND ACCEPTED.

The implementation is approved for commit.

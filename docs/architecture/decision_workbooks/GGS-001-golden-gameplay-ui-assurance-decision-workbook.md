# GGS-001 — Executable Gameplay and UI Capability Assurance Decision Workbook

**Status:** Discovery Complete — Conditional GO; Prototype Decision Pending
**Owner:** Project Owner
**Decision class:** Testing / replay / UI architecture / development governance
**Implementation authorization:** None

## Repository Discovery Outcome

- Completed: 2026-10-06
- Evidence: [GGS-001 adversarial repository audit](../evidence/GGS-001-adversarial-repository-audit.md)
- Result: **Conditional GO**
- GGS: proceed toward a limited B-lite serialized-S0 prototype, subject to Owner authorization
- UIC: proceed through a bounded bootstrap/reconciliation pilot
- UIP: proceed only as a narrow semantic-pattern catalogue
- Setup: retain within the assurance initiative, but execute as a separate coordinated workstream
- Permanent GGS/UIC/UIP architecture and governance: **not yet accepted**

---

# 1. Purpose

Armada requires a scalable way to answer two different but related regression questions:

1. **Does an accepted gameplay capability still work authoritatively after subsequent changes?**
2. **Can the player still exercise every required gameplay decision through a complete, consistent and reusable production UI?**

The current test architecture provides extensive unit/integration coverage, production-path testing, manual Owner QA and full-match replay/baseline verification.

These mechanisms remain valuable, but they do not provide a cheap capability-level executable specification covering both authoritative gameplay and player interaction.

Full-match replay is particularly expensive as the primary evidence for individual gameplay capabilities because unrelated setup and gameplay may need to execute before the capability under test is reached, and failures may occur far from their originating divergence.

The project therefore investigates two complementary mechanisms:

- **Golden Gameplay Samples (GGS)** for authoritative gameplay behavior;
- **UI Capability Catalogue (UIC) and UI Pattern Catalogue (UIP)** for player-decision exposure, completeness and presentation reuse.

A later **UI Flow (UIF)** layer may provide automated production-UI interaction evidence for selected catalogue capabilities.

The primary objective is not maximum test quantity.

The primary objective is:

> **Reduce long-term implementation, regression-verification, manual-QA and Codex diagnosis cost while increasing confidence that accepted gameplay and its player-facing interaction remain complete and correct.**

---

# 2. Target Assurance Model

The intended testing pyramid is:

    Manual Owner QA
            ▲
            │
    Full-game replay / E2E
            ▲
            │
    UI Flow + selected visual tests
            ▲
            │
    Golden Gameplay Samples
            ▲
            │
    Integration / contract tests
            ▲
            │
         Unit tests

Each layer answers a different question.

## Unit tests

> Does an individual calculation/component behave correctly?

## Integration / contract tests

> Do authoritative components interact correctly?

## Golden Gameplay Samples

> Does this accepted gameplay capability or capability interaction still execute correctly through its authoritative gameplay path?

## UI Flow tests

> Can a human player still exercise the capability through the production UI?

## Full-game replay

> Does the complete game architecture remain coherent across long sequences and capability composition?

## Manual Owner QA

> Does the resulting game actually behave and present correctly from the player's perspective?

No upper layer replaces the lower layers.

---

# 3. Parallel Traceability Spine

The testing pyramid should be complemented by a semantic traceability spine:

    Rule / Requirement
            │
            ▼
    Gameplay Capability
            │
            ▼
    Authoritative Decision
            │
            ▼
         Command
            │
            ▼
      UI Capability
            │
            ▼
       UI Pattern

Tests attach to the appropriate level rather than attempting to prove every concern through one mechanism.

The desired result is that the project can answer questions such as:

- Which authoritative player decisions exist?
- Which commands commit those decisions?
- Can each required decision be exercised through production UI?
- Which reusable interaction pattern presents the decision?
- Which GGS protects its authoritative gameplay behavior?
- Which high-risk UI capabilities have production UI Flow coverage?
- Which capabilities intentionally lack automated UI Flow coverage?
- Which full-game replay proves long-horizon composition?

---

# 4. Part A — Golden Gameplay Samples

## 4.1 Definition

A Golden Gameplay Sample is:

> **A short, deterministic, authoritative executable example of one gameplay capability or meaningful capability interaction, beginning from an explicit canonical state and verified at meaningful checkpoints.**

Conceptually:

    explicit canonical initial state
            +
    short authoritative command sequence
            +
    authoritative RNG/results where applicable
            +
    expected canonical checkpoints
            =
    Golden Gameplay Sample

A GGS is not merely a shortened full-match replay.

---

# 5. GGS Goals

## GGS-GOAL-001 — Verification efficiency

Affected gameplay should normally be verifiable without executing an entire match.

## GGS-GOAL-002 — Diagnostic precision

A failing sample should identify the earliest meaningful divergence rather than only report a final-state/hash mismatch.

## GGS-GOAL-003 — Genuine gameplay provenance

Accepted samples should originate from genuine authoritative gameplay.

Codex must not synthesize, reconstruct, regenerate or update an accepted GGS merely to make verification pass.

## GGS-GOAL-004 — Automatic and manual execution

The target architecture should support:

- automatic verification;
- manual loading;
- manual replay;
- preferably command-by-command stepping.

## GGS-GOAL-005 — Controller independence

GGS describes authoritative gameplay rather than the controller that supplied the decision.

The same authoritative capability may eventually be driven by:

- Hot-Seat UI;
- Network;
- replay;
- automated testing;
- future bot/AI controllers.

## GGS-GOAL-006 — Preserve full-game replay

Full-match replay remains valuable as a long-horizon integration sentinel.

GGS changes its role; it does not eliminate it.

---

# 6. Proposed GGS Recording Workflow

The desired Owner-facing workflow is approximately:

1. Enter Debug mode.
2. Prepare the desired gameplay situation using authoritative debug facilities.
3. Select `Start Golden Gameplay Sample Recording`.
4. Supply required identity/metadata.
5. Capture current canonical state as sample S0.
6. Exercise the capability through genuine production gameplay.
7. Optionally mark meaningful checkpoints.
8. Stop recording.
9. Review the candidate.
10. Accept it as a valid Golden Gameplay Sample.

Everything before recording begins is scenario preparation.

Everything after recording begins belongs to the executable sample.

Repository discovery must determine whether existing replay, save/state, command-history, RNG, baseline and debug infrastructure can safely support this model.

---

# 7. GGS Identity

Samples should use stable capability-oriented identifiers.

Examples:

    GGS-CF-001
    GGS-CF-002
    GGS-DMG-010
    GGS-ATT-001
    GGS-SETUP-001

Example filename:

    GGS-CF-003-dial-token.<format>

The stable ID, not filename, should be authoritative.

Candidate metadata includes:

- sample ID;
- title;
- purpose;
- related capability package(s);
- related requirement/rule/issue where useful;
- sample format/version;
- creation provenance;
- acceptance provenance;
- expected checkpoints;
- compatibility dependencies where necessary.

The discovery must determine the minimum useful metadata without duplicating existing authoritative documentation.

---

# 8. GGS Lifecycle

Candidate lifecycle:

    Draft
      ↓
    Candidate
      ↓
    Valid
      ↓
    Invalid / Superseded

An accepted sample must never be silently regenerated because production behavior changed.

A failure must first be classified:

### Production regression

Repair production while preserving the accepted sample.

### Intentional accepted gameplay change

Owner reviews the changed semantics and explicitly replaces or supersedes the sample.

The discovery must recommend where sample lifecycle/status should be recorded.

---

# 9. GGS Checkpoints

Final-state-only comparison is not the preferred target.

A sample should support meaningful intermediate canonical checkpoints.

Example:

    S0
      ↓ BeginAttack
    S1
      ↓ RollDice
    S2
      ↓ ChooseConcentrateFire(Dial+Token)
    S3
      ↓ ChooseAddedDie(BLUE)
    S4
      ↓ optional reroll
    S5

Candidate checkpoint information may include:

- canonical state/digest;
- selected semantic expected values;
- authoritative RNG progression/result;
- timing/decision ownership;
- history/sequence cursor.

The implementation must avoid creating a second manually maintained representation of GameState.

---

# 10. GGS Failure Diagnostics

Automatic execution should ultimately report:

- sample ID;
- first divergent command/checkpoint;
- expected versus actual canonical result/digest;
- useful semantic differences where practical;
- RNG divergence where relevant.

The goal is to reduce diagnosis effort, not merely increase regression-test count.

---

# 11. Manual GGS Debugging

Desired eventual Debug-mode capability:

    Golden Gameplay Samples

    GGS-CF-001      Valid
    GGS-CF-002      Valid
    GGS-DMG-010     Failing

    [Load]
    [Replay]
    [Step]

Manual stepping should be investigated because deterministic sample execution may make it a comparatively inexpensive and high-value debugging capability.

This is a desired capability, not yet an implementation requirement.

---

# 12. Setup Phase Gap

Current replay does not cover Setup Phase.

Setup is gameplay and must ultimately be regression-testable.

The repository investigation must determine:

1. how Setup is currently represented;
2. which Setup decisions are authoritative commands;
3. which Setup interactions currently mutate state through UI/local/direct paths;
4. whether Setup state is canonical and serializable at meaningful decision boundaries;
5. what prevents deterministic Setup replay today;
6. whether GGS can directly represent Setup capabilities;
7. whether Setup support belongs in shared command/state infrastructure, existing replay, GGS, or some combination;
8. whether full-match replay should eventually begin before Setup rather than from post-Setup state.

Potential samples include:

    GGS-SETUP-001
    GGS-SETUP-002
    GGS-SETUP-003

Capturing arbitrary S0 for short capability samples must not become an excuse to permanently exclude Setup from regression verification.

---

# 13. Part B — UI Capability Catalogue

## 13.1 Purpose

The UI Capability Catalogue should answer:

> **Which authoritative gameplay decisions can the player exercise through the production UI, and how?**

It should catalogue semantic player-facing capabilities, not individual buttons, labels, containers or scene-tree nodes.

Example:

| ID | UI capability | Authoritative decision/command |
|---|---|---|
| UIC-ATT-001 | Declare Attack | attack declaration |
| UIC-CF-001 | Resolve Concentrate Fire | CF authoritative choices |
| UIC-ECM-001 | Resolve Electronic Countermeasures | ECM authoritative choice |
| UIC-SQD-001 | Select Squadron before commitment | selection/navigation |
| UIC-SQD-002 | Commit Squadron Activation | Move / Attack / Skip |
| UIC-MAN-001 | Determine Course | maneuver decision |
| UIC-MAN-002 | Execute Maneuver | maneuver commitment |

Exact entries must be derived from repository evidence and reconciled against authoritative requirements/architecture.

---

# 14. UI Catalogue Goals

## UIC-GOAL-001 — Decision completeness

Every player-facing authoritative decision should have an identifiable production UI path unless intentionally unavailable to a particular controller/mode.

## UIC-GOAL-002 — Authority traceability

The catalogue should make it possible to trace:

    requirement
        ↓
    decision
        ↓
    command
        ↓
    UI capability

The UI must expose authoritative decisions rather than invent gameplay authority.

## UIC-GOAL-003 — Reuse

Equivalent interaction semantics should preferentially use an accepted reusable UI pattern.

## UIC-GOAL-004 — Gap detection

The catalogue should reveal:

- authoritative decisions without production UI;
- UI interactions without clear authoritative decision ownership;
- duplicated presentation patterns;
- gameplay logic incorrectly owned by presentation;
- inconsistent interaction semantics;
- missing mode-specific exposure.

## UIC-GOAL-005 — Test planning

The catalogue should provide the inventory from which risk-based UI Flow coverage is selected.

---

# 15. UI Pattern Catalogue

A separate UI Pattern Catalogue should describe recurring interaction semantics.

It should not catalogue low-level Godot widgets.

Candidate examples:

## UIP-DEC-001 — Optional decision

    Effect Name

    [Use] [Decline]

## UIP-CHOICE-001 — Visible discrete choice

    Choose Resource

    [Dial] [Token] [Dial + Token]

## UIP-VISUAL-001 — Visual game-object choice

    Select die to add.

    [die image] [die image] [die image]

## UIP-ORDER-001 — Resolution ordering

    Choose resolution order

    [Asteroid → Station]
    [Station → Asteroid]

## UIP-ACK-001 — Acknowledgement

    Effect / event

    explanatory content

    [Acknowledge]

## UIP-CONFIRM-001 — Commitment boundary

Presentation for a reversible selection followed by explicit authoritative commitment.

These examples are hypotheses only.

Repository discovery must determine the actual recurring semantics and existing reusable components.

---

# 16. What Must Not Be Catalogued

The project should avoid a catalogue of:

- every Button;
- every Label;
- every VBox/HBox;
- every scene-tree path;
- every cosmetic element;
- implementation-specific node identities.

Example of undesired catalogue information:

    AttackSimPanel/VBox/HBox/Button3

The catalogue should describe stable interaction semantics, not fragile scene implementation.

---

# 17. Bootstrap Strategy for Existing Implementation

The project already contains substantial implemented gameplay and UI.

The initial catalogue should therefore be **mined from the repository**, not manually authored from scratch.

However:

> Existing implementation is discovery evidence, not automatically normative truth.

Codex should perform multi-directional discovery.

---

# 18. Forward Trace Discovery

Trace from authoritative intent toward presentation:

    requirement / capability package
            ↓
    authoritative gameplay decision
            ↓
    command
            ↓
    production UI path
            ↓
    interaction pattern
            ↓
    existing tests

For each candidate capability classify evidence as:

- **Observed** — directly demonstrated by repository evidence;
- **Inferred** — strongly implied but not explicitly established;
- **Unresolved** — ownership/intent cannot be determined safely.

Do not convert inference into architecture silently.

---

# 19. Reverse Trace Discovery

Independently trace production UI toward authority:

    production UI interaction
            ↓
    submitted action/command
            ↓
    authoritative decision owner
            ↓
    capability / requirement

This should identify:

### Missing UI

    authoritative decision
        ↓
    command
        ↓
    no production UI

### Orphan UI

    UI interaction
        ↓
    unclear/no authoritative owner

### Duplicated interaction semantics

    capability A ─┐
    capability B ─┼→ separate implementations of equivalent interaction
    capability C ─┘

### Presentation-owned gameplay

    UI
      ↓
    gameplay decision/effect occurs before authoritative command commitment

These are findings for review, not automatic authorization to refactor.

---

# 20. Reconciliation

The forward and reverse inventories must be reconciled against:

1. repository document authority;
2. accepted requirements;
3. accepted architecture;
4. capability packages;
5. gameplay rules where relevant;
6. actual production behavior.

The bootstrap process must not canonize an implementation defect merely because it currently exists.

Unresolved contradictions should be surfaced to the Owner.

---

# 21. Catalogue Maintenance Principle

The catalogue is valuable only if maintenance cost remains low.

It should therefore prefer references over duplicated specification.

A compact mapping is preferred:

| UIC | Capability | Decision/Command | UIP | GGS | UIF |
|---|---|---|---|---|---|
| UIC-CF-001 | CAP-CF-001 | CF resolution | UIP-DEC / UIP-VISUAL | GGS-CF-* | UIF-CF-* |

The discovery must determine whether this information can be maintained cheaply from existing authoritative documents.

If maintaining the catalogue requires duplicating the same semantics across multiple manually synchronized documents, the architecture should be reconsidered.

---

# 22. UI Flow Layer

The catalogue is not itself a UI test suite.

A later UI Flow layer should prove selected high-value production interactions.

Example:

    known canonical CF state
            ↓
    assert Concentrate Fire [Use] [Decline]
            ↓
    click Use
            ↓
    assert Dial / Token / Dial + Token
            ↓
    click Dial
            ↓
    assert legal die images
            ↓
    click BLUE die
            ↓
    verify authoritative result

UI Flow tests should interact through production UI rather than calling internal panel handlers as a substitute for player interaction.

---

# 23. Relationship Between GGS and UI Flow

Where practical, GGS and UIF should converge on equivalent authoritative outcomes.

Conceptually:

                 GGS-CF-003
                      │
               canonical behavior
                      │
            ┌─────────┴─────────┐
            ▼                   ▼
      Gameplay runner       UI Flow runner
            │                   │
      command execution      player actions
            │                   │
            └─────────┬─────────┘
                      ▼
             equivalent canonical
                    outcome

This can demonstrate that UI is a controller of authoritative gameplay rather than a parallel gameplay implementation.

---

# 24. Visual Regression

Selected stable UI Flow states may later receive screenshot/visual golden protection.

Visual testing is supplementary.

Priority should be:

1. semantic UI structure and interaction;
2. authoritative result;
3. selected visual regression where valuable.

The project should avoid indiscriminate full-screen screenshot comparison.

---

# 25. Coverage Policy

Comprehensive traceability does not imply comprehensive expensive UI automation.

For each meaningful gameplay decision, target consideration of:

| Evidence | Expectation |
|---|---|
| Requirement/rule ownership | Required |
| Authoritative decision ownership | Required |
| Command/commit mechanism | Required |
| UI capability | Required where player-facing |
| UI pattern | Required where reusable semantics apply |
| GGS | Normally required for meaningful accepted gameplay |
| UIF | Risk-based |
| Visual golden | Selective |
| Full-game replay | Very selective |

The exact policy requires repository discovery and Owner decision.

---

# 26. Proposed Development Definition of Done

Long-term candidate workflow for new gameplay capabilities:

    requirement / rule
            ↓
    authoritative decision
            ↓
    command
            ↓
    implementation
            ↓
    GGS consideration
            ↓
    UIC entry/update
            ↓
    existing UIP reused or new pattern justified
            ↓
    risk-based UIF consideration
            ↓
    ordinary verification
            ↓
    Owner acceptance

This is a target operating model, not yet adopted governance.

---

# 27. Incremental Introduction

A big-bang migration is explicitly discouraged.

## Stage 0 — Repository discovery

Inventory existing:

- gameplay decisions;
- commands;
- production UI exposure;
- recurring interaction semantics;
- tests;
- replay infrastructure;
- Setup Phase architecture.

Generate candidate UIC/UIP inventory.

No implementation.

## Stage 1 — Reconciliation

Compare candidate inventory against authoritative documentation and architecture.

Identify:

- missing UI;
- orphan UI;
- duplicated patterns;
- unclear ownership;
- presentation-owned gameplay;
- test-coverage gaps.

Owner resolves only genuine architectural/product decisions.

## Stage 2 — Establish UIC/UIP baseline

Create the accepted catalogue from reconciled evidence.

Do not require complete historical GGS/UIF coverage before adopting the catalogue.

Record missing historical coverage explicitly where useful.

## Stage 3 — Minimal GGS prototype

Implement the minimum vertical slice:

- capture current canonical S0;
- start recording;
- stop recording;
- stable identity;
- save candidate;
- load;
- automatic execution;
- final canonical verification.

Use only a few manually recorded experimental samples.

## Stage 4 — GGS checkpoints and diagnostics

Add:

- intermediate checkpoints;
- RNG verification;
- first-divergence diagnostics.

## Stage 5 — GGS catalogue/debug integration

As justified, add:

- lifecycle/status;
- debug sample browser;
- manual load;
- replay;
- step.

## Stage 6 — Regression integration

Support:

- verify one GGS;
- verify capability family;
- verify all GGS.

Integrate appropriately into convergence/CI.

## Stage 7 — Opportunistic historical backfill

Do not stop normal development merely to achieve arbitrary GGS coverage percentages.

Backfill according to:

- capability risk;
- historical regression frequency;
- complexity;
- architecture importance;
- capabilities touched by current work.

When an existing capability is materially changed, appropriate GGS coverage should normally be added.

## Stage 8 — UI Flow pilot

Choose a small number of high-value UICs.

Prefer capabilities that are:

- complex;
- historically regression-prone;
- interaction-heavy;
- reused across modes;
- architecturally important.

Validate production UI automation before broad adoption.

## Stage 9 — Risk-based UIF expansion

Expand UI Flow coverage based on value rather than percentage targets.

## Stage 10 — New Definition of Done

Only after the infrastructure has demonstrated favorable cost/benefit should UIC/UIP/GGS/UIF consideration become standard governance for new gameplay work.

---

# 28. GGS Options to Compare

Repository discovery must compare at minimum:

## Option A — Short current replay fixtures

Reuse current replay architecture with minimal changes.

## Option B — Golden Gameplay Samples

Explicit canonical initial state + short authoritative command stream + authoritative RNG/results + meaningful checkpoints.

This is the preferred hypothesis.

## Option C — Declarative scenario construction

Build initial state from purpose-specific scenario definitions.

This may have long-term potential but must be assessed for synthetic-state risk and duplicated gameplay semantics.

Hybrid options are allowed.

---

# 29. Required Repository Discovery — GGS

Investigate:

### Replay reuse

- ReplayDriver;
- replay serialization;
- replay format/versioning;
- CommandFactory;
- command history;
- sequencing;
- baseline verification.

Determine which can be reused unchanged.

### State capture

Determine whether current canonical state serialization can safely provide arbitrary GGS S0.

Identify states that cannot round-trip into actionable production gameplay.

### RNG

Determine how accepted ADR-012 RNG/result authority can be represented and verified.

### Checkpoints

Determine whether existing hashes/digests can be reused and what semantic diagnostics are worth adding.

### Debug recording

Determine whether existing recording can be bounded by explicit Start/Stop controls and current canonical state capture.

### Automated execution

Determine requirements for:

    verify one sample
    verify capability family
    verify all samples

### Manual execution

Assess effort for:

    load
    replay
    pause
    step
    inspect divergence

### Setup

Perform the Setup investigation defined in §12.

---

# 30. Required Repository Discovery — UIC/UIP

Codex must attempt to bootstrap the existing catalogue from repository evidence.

At minimum inspect:

- authoritative gameplay command classes;
- timing/decision opportunity representations;
- production controllers/orchestrators;
- production panels/modals;
- command submission adapters;
- reusable UI components;
- Hot-Seat and Network presentation paths;
- production-board tests;
- UI-focused tests;
- requirements;
- capability packages;
- relevant architecture contracts.

Produce candidate inventories for:

1. authoritative player decisions;
2. commands committing those decisions;
3. production UI capabilities exposing them;
4. recurring interaction patterns;
5. existing tests protecting them.

Estimate catalogue size.

Do not manually enumerate cosmetic UI elements.

---

# 31. Required Gap Analysis

The discovery must specifically identify evidence of:

- authoritative decisions without production UI;
- production UI without clear authoritative decision ownership;
- equivalent decision semantics implemented through inconsistent UI;
- duplicate UI implementations suitable for reuse;
- UI that performs gameplay authority before command commitment;
- decisions exposed differently in Hot-Seat and Network without documented reason;
- capabilities implemented but inadequately represented in tests;
- existing reusable UI patterns that could form the initial UIP catalogue;
- areas where catalogue maintenance would duplicate existing authoritative documents.

Findings must distinguish:

- confirmed defect;
- architecture concern;
- documentation gap;
- test gap;
- intentional variation;
- unresolved/Owner decision.

---

# 32. Cost/Benefit Assessment

For both GGS and UIC/UIP, assess:

- initial implementation/documentation cost;
- ongoing maintenance cost;
- expected regression-detection benefit;
- expected diagnostic benefit;
- expected manual-QA reduction;
- expected Codex investigation/convergence reduction;
- risk of documentation drift;
- risk of overengineering.

Use:

- Small;
- Medium;
- Large;
- Very Large

for implementation work packages.

Do not invent precise Codex-credit estimates where evidence is insufficient.

The principal decision question is:

> **Will this system reduce total long-term Armada development and verification effort enough to justify its implementation and maintenance cost?**

---

# 33. Architecture Constraints

Any recommended solution must preserve accepted principles including:

- canonical gameplay authority remains outside presentation;
- UI exposes decisions rather than owning gameplay effects;
- Network passive peers do not invent authoritative RNG/results;
- replay/GGS does not invent alternate gameplay semantics;
- recovery remains decision-equivalent and purpose-specific;
- no generic continuation owner/FSM merely for testing;
- debug gameplay mutation should use authoritative/canonical mechanisms;
- accepted fixtures/samples must not be silently regenerated;
- controller independence should be preserved where applicable.

Repository authority supersedes this workbook where conflict exists.

---

# 34. Non-Goals

This decision workbook does not authorize:

- GGS implementation;
- UIC/UIP implementation;
- UI refactoring;
- replay replacement;
- Setup refactoring;
- automated regeneration of replay fixtures;
- automated generation of accepted GGS;
- mass historical test creation;
- UI Flow implementation;
- screenshot testing;
- declarative scenario construction;
- removal of full-game replay;
- changes to gameplay rules.

---

# 35. Adversarial Audit Requirements

The repository audit must challenge the proposal rather than merely design toward it.

Specifically attempt to falsify:

1. that GGS materially improves on existing focused integration tests;
2. that arbitrary canonical S0 can be captured safely;
3. that existing replay infrastructure is reusable for GGS;
4. that intermediate checkpoints provide sufficient additional value;
5. that manual sample recording is maintainable;
6. that a UIC catalogue can be maintained without excessive duplication;
7. that UI patterns are actually reusable enough to justify formal catalogue entries;
8. that Codex can reliably bootstrap the catalogue from current code;
9. that GGS + UIC/UIP will reduce rather than increase long-term maintenance effort;
10. that Setup can join the same underlying architecture without disproportionate cost.

Look specifically for simpler alternatives.

A recommendation to narrow, postpone or reject part of this proposal is valid if supported by repository evidence.

---

# 36. Required Audit Output

Return:

## 1. Executive verdict

Rate separately:

- GGS feasibility;
- GGS expected long-term value;
- UIC feasibility;
- UIC expected long-term value;
- UIP feasibility/reuse value;
- combined architecture value.

## 2. Current replay architecture

What exists and what is reusable.

## 3. Setup Phase gap

Exact current authority/replay limitations and likely repair scope.

## 4. Current UI architecture

How authoritative decisions reach production UI today.

## 5. Candidate UIC inventory

Estimate and representative inventory derived from existing implementation.

Do not pretend uncertain entries are accepted.

## 6. Candidate UIP inventory

Identify genuinely recurring interaction semantics and existing reusable implementations.

## 7. Bidirectional traceability findings

Report missing/orphan/inconsistent paths.

## 8. Existing test coverage mapping

Map representative existing tests to the proposed assurance layers.

## 9. Option comparison

Compare GGS A/B/C and any superior hybrid.

## 10. Maintenance analysis

Determine whether UIC/UIP creates useful traceability or excessive duplicated documentation.

## 11. Recommended target architecture

Recommend the smallest architecture that achieves the intended long-term benefit.

## 12. Incremental implementation plan

Challenge and refine the staged introduction proposed in §27.

## 13. Effort assessment

Small / Medium / Large / Very Large by work package.

## 14. Cost/benefit conclusion

Explicitly answer whether the expected long-term savings justify the investment.

## 15. Risks and failure modes

Include risks of fixture drift, catalogue drift, over-testing, duplicated specifications and synthetic states.

## 16. Owner decisions required

Only genuine decisions that repository evidence cannot resolve.

## 17. Recommended next artifact

State whether the project should proceed with:

- no change;
- limited prototype;
- ADR;
- implementation workbook;
- separate Setup work;
- separate UIC/UIP work;
- or another evidence-gathering stage.

No implementation is authorized by this workbook.

---

# 37. Decision Gate

After the adversarial repository audit, the Owner should be able to decide:

1. whether GGS Approach B remains preferred;
2. whether GGS should be prototyped before architectural commitment;
3. how Setup becomes deterministically testable;
4. whether a UIC catalogue provides sufficient value;
5. whether a UIP catalogue provides genuine reuse rather than documentation overhead;
6. how much of the existing catalogue Codex can safely bootstrap;
7. what historical coverage should be backfilled;
8. what should instead be added opportunistically;
9. when GGS/UIC/UIP/UIF consideration should enter Definition of Done;
10. whether the combined system is expected to reduce total long-term development cost.

Until those decisions are made, this workbook authorizes discovery and adversarial audit only.

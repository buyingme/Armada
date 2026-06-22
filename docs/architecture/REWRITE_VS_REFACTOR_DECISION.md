# Rewrite vs Refactor Decision

This document evaluates whether the project should be fully rewritten,
incrementally refactored, selectively rewritten behind contracts, or partially
frozen while feature work continues elsewhere.

This is not an ADR and does not create a new architecture decision. It is a
program-level recommendation based on the current architecture discovery state.

## Inputs

- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/ARCHITECTURE_DECISION_TRIAGE.md`
- `docs/REALITY_GAP_REGISTER.md`
- `docs/current_state_architecture_maps.md`
- Existing tests, CI, lint, and baseline trace scripts
- Relevant code evidence only where needed

## Current Evidence Summary

The project is a large working Godot codebase with significant runtime behavior
already implemented and protected by tests. The current-state map records
existing GUT tests, CI workflows, phase/lint gates, baseline traces, save/load,
replay, network, command processing, setup, rules, and presentation systems.

The architecture discovery documents identify high-risk unresolved boundaries:

- `BC-001` Live Game State Authority: mostly known but high impact.
- `BC-002` Command Processing and Applicability: command spine exists, tests
  need explicit mapping.
- `BC-003` Interaction Flow and UI Projection: owner decision needed around
  command-only flow mutation versus attack-flow direct writes.
- `BC-005` / `BC-005A` Rule and Game Component Rule Extension: expansion path
  is not fully accepted.
- `BC-006` GameManager Orchestration: actual responsibility is broader than
  some intended documentation.
- `BC-007`, `BC-008`, `BC-009`: network, save/load, and replay are high-impact
  areas where regressions would be expensive.

Test and CI evidence:

- CI runs unit and integration GUT tests under Godot 4.5.1.
- `scripts/test.sh` runs the full headless GUT suite or focused subsets.
- `scripts/run_baseline_traces.sh` compares hot-seat replay trace/state hash
  and network host/client final state hash.
- The repository currently contains 217 unit/integration GUT test scripts.

Conclusion from evidence: this is not an unprotected prototype. It is a
functioning system with architectural contradictions and migration needs. That
strongly changes the rewrite calculus.

## Option Comparison

| Criterion | Full rewrite | Incremental refactor | Selective subsystem rewrite behind stable contracts | Freeze architecture-sensitive areas and continue feature work elsewhere |
| --- | --- | --- | --- | --- |
| Delivery risk | Very high | Medium | Medium-high per subsystem | Low short term, high long term |
| Regression risk | Very high | Medium | Medium if contracts/tests exist; high without them | Low in frozen areas, medium elsewhere |
| Migration cost | Very high | Medium | Medium to high per subsystem | Low initially |
| Testability | Poor until parity harness exists | Good with existing tests plus targeted additions | Good only after contracts and golden tests | Good for safe feature areas, weak for frozen gaps |
| Codex safety | Low | Medium-high with roadmap guardrails | Medium-high after contracts; low before contracts | Medium; safe only if freezes are respected |
| Ability to continue feature development | Poor | Good in safe areas | Good outside rewritten subsystem | Good outside frozen areas |
| Save/load impact | Very high | Controlled | High if subsystem owns serialized state | Low if avoided |
| Network impact | Very high | Controlled | High if subsystem crosses command/state sync | Low if avoided |
| Replay impact | Very high | Controlled | High if subsystem affects command history or deterministic state | Low if avoided |
| Godot scene/UI asset reuse | Risk of losing or redoing assets | High reuse | High reuse if boundary is narrow | High reuse |
| Risk of losing working behavior | Very high | Low to medium | Medium | Low short term |

## Option 1 - Full Rewrite

### Evaluation

| Factor | Assessment |
| --- | --- |
| Delivery risk | Very high. The system already contains working gameplay, setup, save/load, replay, network, fleet, rules, UI, and Godot asset behavior. Rebuilding all of that before users see value is a long interruption. |
| Regression risk | Very high. Many behaviors are encoded in code, tests, scenes, resources, and workflow assumptions that are not fully captured by contracts yet. |
| Migration cost | Very high. Requires parity for serialized state, network behavior, replay traces, Godot scenes, assets, rule surfaces, and setup flows. |
| Testability | Weak at the beginning. Existing tests can be reused as oracles, but a rewrite would first need compatibility layers and parity harnesses. |
| Codex safety | Low. Codex would have too much freedom in unresolved areas and could accidentally choose between architecture options that still require owner decisions. |
| Ability to continue feature development | Poor. Feature work would either stop or need duplicate implementation in old and new systems. |
| Save/load impact | Very high. Save schema compatibility, metadata, signatures, interaction flow state, damage deck, RNG, and setup/objective state would need explicit migration. |
| Network impact | Very high. Host/client command sync, filtering, lobby/setup handoff, and attack-flow mirror behavior would need parity. |
| Replay impact | Very high. Existing replay/baseline behavior depends on command history, deterministic RNG, serialized state, and flow snapshots. |
| Godot scene/UI asset reuse | Low to medium. Assets could be reused, but scene/controller behavior would likely need re-binding and re-validation. |
| Risk of losing working behavior | Very high. Existing behavior is distributed across runtime code, scene workflows, tests, and resources. |

### Fit

Full rewrite is the wrong default for the current situation. The architecture
has gaps, but the codebase is not disposable. The main problem is governance and
boundary clarification, not absence of working implementation.

Full rewrite would only be justified if the current implementation could no
longer support core requirements, or if contracts and tests proved that parity
can be achieved cheaply. Current evidence does not support that.

## Option 2 - Incremental Refactor

### Evaluation

| Factor | Assessment |
| --- | --- |
| Delivery risk | Medium. Refactors can be scoped to accepted tasks and protected by tests. |
| Regression risk | Medium. Risk remains in `BC-001`, `BC-003`, `BC-005`, `BC-007`, `BC-008`, and `BC-009`, but can be controlled by contracts and focused tests. |
| Migration cost | Medium. Work can follow `AT-xxx` sequencing and avoid high-risk areas until decisions exist. |
| Testability | Good. Existing GUT tests, CI, and baseline trace scripts can be extended rather than replaced. |
| Codex safety | Medium-high if `DOCUMENT_AUTHORITY.md`, `CODEX_WORKFLOW.md`, and `.ai/instructions/AI_STARTUP_GUARDRAILS.md` are followed. |
| Ability to continue feature development | Good. Safe feature areas can proceed while high-risk boundaries are clarified. |
| Save/load impact | Controlled. Changes can be kept behind current serialization contracts until `CON-xxx` documents exist. |
| Network impact | Controlled. Network-sensitive work can wait for `TEST-002` and related contracts. |
| Replay impact | Controlled. Replay/baseline traces can act as regression gates. |
| Godot scene/UI asset reuse | High. Existing scenes, resources, panels, and workflows stay usable. |
| Risk of losing working behavior | Low to medium. Existing behavior is preserved unless a focused migration deliberately changes it. |

### Fit

Incremental refactor fits the project state best. It respects that current code
contains valuable, working behavior while also acknowledging that some
boundaries need decisions, contracts, and tests before migration.

This option does not prohibit local replacement of poor subsystems. It requires
those replacements to be sequenced through contracts, tests, and stable
interfaces.

## Option 3 - Selective Subsystem Rewrite Behind Stable Contracts

### Evaluation

| Factor | Assessment |
| --- | --- |
| Delivery risk | Medium-high. Safe only when the subsystem boundary is narrow and externally observable behavior is contract-protected. |
| Regression risk | Medium with contracts/tests; high without them. |
| Migration cost | Medium to high depending on subsystem. Cost is acceptable for isolated helpers, high for state/network/replay systems. |
| Testability | Good for pure helpers and leaf subsystems. Weak for scene-orchestrated workflows unless a contract and harness exist. |
| Codex safety | Medium-high after contract creation. Low if Codex is asked to infer the new design in unresolved areas. |
| Ability to continue feature development | Good if rewritten subsystem is isolated and old behavior remains available until parity is proven. |
| Save/load impact | Low for non-serialized subsystems; high for stateful runtime systems. |
| Network impact | Low for local UI/pure helpers; high for command/state/projection paths. |
| Replay impact | Low for deterministic pure helpers; high for command, rule, RNG, and flow behavior. |
| Godot scene/UI asset reuse | Usually high if the rewrite is behind an adapter or helper boundary. |
| Risk of losing working behavior | Medium. Lower when old and new implementations can be compared side-by-side. |

### Fit

Selective subsystem rewrite is a useful technique, not the primary program
strategy. It should be allowed only after the subsystem has:

- a stable contract,
- focused tests,
- a rollback path or adapter,
- and a clear definition of externally observable behavior.

This option is appropriate for narrow helpers, generated inventories,
presentation-only panels, or isolated data adapters. It is not appropriate for
live state authority, attack flow, command processing, save/load, network, or
replay until those areas have accepted contracts and test strategies.

## Option 4 - Freeze Architecture-Sensitive Areas And Continue Feature Work Elsewhere

### Evaluation

| Factor | Assessment |
| --- | --- |
| Delivery risk | Low short term. Avoids destabilizing major systems. |
| Regression risk | Low in frozen areas, medium in nearby feature areas that accidentally touch them. |
| Migration cost | Low initially, but deferred architecture cost accumulates. |
| Testability | Good for safe feature work; weak for unresolved architecture because tests may not be added. |
| Codex safety | Medium. Safe if frozen areas are explicit and enforced; unsafe if feature work slips through unresolved boundaries. |
| Ability to continue feature development | Good in safe areas, poor for features requiring rules, setup, save/load, replay, network, or command changes. |
| Save/load impact | Low if avoided. |
| Network impact | Low if avoided. |
| Replay impact | Low if avoided. |
| Godot scene/UI asset reuse | High. |
| Risk of losing working behavior | Low short term. Risk shifts to long-term stagnation and inconsistent feature placement. |

### Fit

This is a tactical posture, not a full strategy. It is useful while owner
decisions are pending. It should not become permanent, because many important
future features depend on the unresolved rule, flow, setup, command, save/load,
network, and replay boundaries.

## Recommendation

Recommend Option 2: Incremental refactor as the program strategy.

Use Option 3 only as a controlled technique for narrow subsystems after
contracts and tests exist. Use Option 4 tactically for high-risk areas until
their architecture tasks are resolved. Reject Option 1 as the default strategy.

Rationale:

- The project already has substantial working behavior, tests, CI, baseline
  traces, save/load, replay, network, setup, rules, and Godot UI assets.
- The current problem is not that the implementation has no value; the problem
  is that several architecture boundaries are unresolved or under-contracted.
- Full rewrite would amplify the exact risks the roadmap is designed to reduce:
  undocumented behavior loss, Codex overreach, save/load incompatibility,
  network/replay regressions, and scene/UI asset churn.
- Incremental refactor preserves delivery while allowing the architecture to
  become more explicit through `AT-xxx`, `ADR-xxx`, `CON-xxx`, and `TEST-xxx`.

## Subsystems That Should Not Be Rewritten Now

Do not rewrite these without accepted contracts and test strategies:

- `BC-001` Live Game State Authority: `GameState`, state install paths, runtime
  state ownership.
- `BC-002` Command Processing and Applicability: `CommandProcessor`,
  `GameCommand`, command registry, command history, applicability checks.
- `BC-003` Interaction Flow and UI Projection: `InteractionFlow`, `FlowSpec`,
  `UIProjector`, attack-flow publication, modal authority.
- `BC-006` GameManager Orchestration: broad `GameManager` responsibility
  changes.
- `BC-007` Network Command Sync and State Filtering.
- `BC-008` Save/Load and Checkpoint Boundary.
- `BC-009` Replay and Baseline Trace Boundary.
- Existing setup behavior governed by `docs/setup_flow.md`, unless the affected
  step is explicitly covered.
- Existing Godot scene/UI assets that encode working user workflows.

## Subsystems That May Be Good Rewrite Candidates

These may be candidates for selective rewrite after contracts/tests or when
their behavior is leaf-level and observable:

- Static content inventory and documentation generation around `BC-011`.
- Small pure helpers or adapters with existing focused tests.
- Presentation-only UI widgets that do not own durable state, rule legality,
  command submission, save/load, network, or replay behavior.
- Fleet builder presentation helpers and list presenters, where roster payload
  contracts are not changed.
- Asset-loading adapters that preserve stable keys and current JSON behavior.
- Tooltip/audio/visual utility code with isolated state and existing tests.

These are candidates, not approvals. Each still needs local evidence before
implementation.

## Contracts Required Before Any Rewrite

At minimum:

- `CON-001` Live Game State Authority: allowed writers, serialized ownership,
  state install/load/bootstrap rules, and treatment of `InteractionFlow`.
- `CON-002` Interaction Flow and UI Projection: flow ownership, projection
  authority, command-only versus accepted exceptions, payload visibility, and
  network mirror behavior.
- `CON-003` Rule and Game Component Rule Extension: rule surfaces, active
  serialized state, command validation, projection payloads, and UI limits.
- `CON-004` Command Processing and Applicability: command lifecycle,
  applicability, command serialization, rule hooks, observer follow-ups, and
  replay expectations.
- `CON-005` Save/Load/Replay/Network State Compatibility: serialized schema,
  state filtering, deterministic RNG/deck behavior, command history, and
  baseline trace expectations.
- Existing `docs/setup_flow.md` remains the controlling setup contract until
  superseded by an accepted contract or ADR.

## Tests Required Before Any Rewrite

At minimum:

- `TEST-001` Command processing/applicability coverage for command registry,
  validation, execution, history, and flow-step gating.
- `TEST-002` Network/replay/state filtering coverage for `StateFilter`,
  `UIProjector`, command sync, attack-flow snapshots, and host/client state
  equivalence.
- `TEST-003` Save/load/checkpoint coverage for serialized `GameState`,
  metadata, HMAC/signature checks, and mode-specific load behavior.
- `TEST-004` Setup contract coverage for setup package bootstrap, initiative,
  objectives, obstacles, deployment, visibility, and transitions.
- Replay baseline coverage through `scripts/run_baseline_traces.sh`.
- Focused golden tests for any subsystem being selectively rewritten.
- Side-by-side parity tests where old and new implementations coexist.

## Smallest Safe Experiment

Run a selective rewrite experiment on a low-risk, leaf-level subsystem with
existing tests and no durable state ownership.

Recommended experiment:

1. Select one small static-content or presentation helper connected to
   `BC-011` or a non-authoritative fleet-builder presenter.
2. Define a tiny local contract in the task description, not a permanent
   architecture contract.
3. Add or identify focused tests that pin current observable behavior.
4. Implement the new helper behind the existing public call surface.
5. Run the focused tests, then the relevant GUT subset.
6. Confirm no changes to save/load, network, replay, command history, or
   serialized payloads.

Success criteria:

- No user-visible behavior loss.
- Existing public call surface preserved.
- Tests pass before and after replacement.
- Codex can complete the change without touching unresolved boundaries.

Failure criteria:

- The experiment requires changing `GameState`, command payloads,
  `InteractionFlow`, network snapshots, replay baselines, or setup contracts.
- The existing behavior cannot be stated clearly enough to test.
- The rewrite creates a new architecture pattern outside accepted documents.

## Decision Summary

| Option | Recommendation |
| --- | --- |
| Full rewrite | Reject as default. Too much working behavior and too many unresolved contracts would be put at risk. |
| Incremental refactor | Recommended program strategy. |
| Selective subsystem rewrite behind stable contracts | Allow as a controlled technique after contracts/tests. |
| Freeze architecture-sensitive areas and continue feature work elsewhere | Use tactically while owner decisions are pending. |

The project should continue as an incremental architecture transformation
program, not a rewrite program.

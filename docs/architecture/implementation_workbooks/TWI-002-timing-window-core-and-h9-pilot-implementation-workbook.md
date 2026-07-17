# TWI-002: Timing Window Core And H9 Pilot Implementation Workbook

Status: Draft

Purpose: Implementation Workbook
Tranche: MA-TW-001 Slices 2-8
Predecessor: TWI-001 -- Authoritative TimingWindowState (completed)
Authority:
- ADR-005
- CON-005
- TEST-003

This workbook prepares one implementation task made of seven ordered,
independently gated slices. It is not an ADR, a Contract, a TEST document, an
implementation authorization, or a replacement for CAP-H9-001.

## 1. Purpose

TWI-002 translates the accepted timing-window architecture into a
repository-grounded implementation plan for the shared timing-window core and
the first clean vertical consumer, H9 Turbolasers.

The workbook answers:

- how MA-TW-001 Slices 2-8 can be implemented without reopening Slice 1;
- where immutable timing-window definitions belong;
- where lifecycle orchestration integrates with the existing command stream;
- how RuleRegistry remains a candidate index rather than runtime authority;
- what canonical derived opportunities contain;
- how use, decline, continuation, cleanup, projection, replay, save/load,
  reconnect, and networking remain deterministic;
- how H9 proves the live path without copying the current local Swarm, Tarkin,
  or ECM timing patterns;
- which checkpoint must pass before each later slice begins;
- which work remains explicitly deferred.

The governing implementation criterion is:

> The resulting path must teach future implementations one repeatable
> timing-window protocol, not one H9-specific integration pattern.

## 2. Status And Authority

Status: Draft.

Document authority:

- ADR-005 is the architecture authority for timing-window ownership,
  opportunity derivation, orchestration, and continuation.
- CON-005 is the implementation-contract authority for every shared and H9
  timing-window obligation in this tranche.
- TEST-003 is the verification authority.
- ADR-003 and CON-003 govern rule surfaces and CAP traceability.
- ADR-004 and CON-004 govern H9 runtime-upgrade identity and mutable
  `rule_state` ownership.
- TIM-001 and TIM-002 are historical decision evidence. They do not override
  the accepted ADR or Contracts.
- TIM-002-owner-decisions records the accepted decisions incorporated into
  CON-005. It does not become an implementation authority.
- MA-TW-001 sequences the implementation work. It does not redefine
  architecture or verification obligations.
- MA-H9-001 supplies repository evidence and confirms H9 as the first clean
  consumer after the shared prerequisites.
- CAP-H9-001 remains the rule-specific behavior and evidence package. It is
  Draft/NOT_INTEGRATED and must not be advanced by this workbook.
- TWI-001 planned Slice 1. Its accepted and completed implementation is
  predecessor evidence and is not reopened here.
- TWI-002 is implementation planning only. Where it recommends a concrete
  file or function seam, ADR-005, CON-005, TEST-003, and the applicable CAP
  remain authoritative.

No Owner decision in TIM-002 is reopened. In particular, Version 1 retains:

- one active timing window;
- one current controller;
- RuleRegistry-only candidate discovery;
- derived, non-authoritative opportunities;
- explicit replayable use and decline for optional blockers;
- continuation derived from the static timing-window definition;
- explicit command-owned cleanup;
- one authoritative network command stream;
- repository-owned compatibility/versioning;
- shared protocol evidence plus unique CAP evidence;
- one immutable static definition table owned by the shared timing-window
  module.

## 3. Relationship To TWI-001

TWI-001 and its completed implementation provide:

- `GameState` ownership of `TimingWindowState`;
- an inactive default;
- one active lifecycle representation;
- distinct same-type lifecycle identity;
- deterministic controller-domain validation;
- governed JSON-safe lifecycle and continuation context;
- serialization and reconstruction through `GameState`;
- old-state reconstruction to inactive;
- fail-closed rejection of invalid present state;
- save/load, replay initialization, reconnect, and baseline evidence.

TWI-002 consumes those semantics through the public `GameState` /
`TimingWindowState` boundary. It must not:

- change Slice 1 serialized semantics merely to simplify later code;
- store opportunities, participant lists, runtime rule state, projection, or
  command objects in `TimingWindowState`;
- add a local timing-window schema version;
- weaken cloning or validation boundaries;
- reinterpret active terminal statuses;
- change the accepted missing/invalid-state compatibility behavior.

If a later slice appears to require one of those changes, implementation stops.
The dependency must be compared with CON-005 and TWI-001 before any edit to
Slice 1 state semantics is proposed.

## 4. Planning Tranche

### 4.1 Included

This workbook covers exactly MA-TW-001 Slices 2-8, in order:

1. immutable static timing-window definitions;
2. Timing Window Orchestrator core;
3. RuleRegistry participant indexing and canonical opportunity records;
4. timing-window command protocol integration;
5. projection and live interaction routing;
6. serialization, save/load, replay, reconnect, networking, cleanup, and
   shared TEST-003 evidence;
7. H9 as the first clean vertical pilot.

The first production timing-window definition and lifecycle activated by this
tranche is `ATTACK_MODIFY`. Tarkin and ECM provide design evidence, but their
timing-window definitions remain deferred until their migration slices because
their continuation and cleanup seams must be migrated with the consumer. This
keeps the Version 1 definition table to the smallest policy actually exercised
by Slices 2-8.

### 4.2 Explicitly Deferred

This workbook does not cover:

- MA-TW-001 Slice 9, Tarkin migration;
- MA-TW-001 Slice 10, ECM migration;
- MA-TW-001 Slice 11, final CAP evidence alignment;
- changes to CAP-H9-001, CAP-UPG-001, or CAP-ECM-001 status;
- Project Owner integration approval for any CAP;
- final cross-consumer acceptance;
- generalized nested-window mechanics;
- richer priority or pass systems;
- transport, RPC, packet, retry, or latency architecture;
- a general attack-flow rewrite;
- migration of Swarm into the shared timing-window protocol;
- replacing existing Tarkin or ECM local lifecycle behavior;
- a generic rule engine, effect-composition engine, cleanup framework, or
  timing-window framework.

The coexistence requirement for H9 is proven with a deterministic test
participant registered through the same RuleRegistry candidate path. Existing
Swarm behavior remains a regression surface, not a second production migration
inside this tranche.

## 5. Accepted Architecture Guards

The following guards apply to every slice and every checkpoint.

### 5.1 Authority Owners

| Concern | Sole authoritative owner |
| --- | --- |
| Shared lifecycle identity, stage, status, controller, context | `GameState`-owned `TimingWindowState` |
| Immutable timing-window policy | Shared timing-window module static definition table |
| Lifecycle opening, re-derivation coordination, completion decision, continuation coordination, shared lifecycle cleanup | Timing Window Orchestrator |
| Candidate participant indexing | Existing `RuleRegistry`, as static index only |
| H9 current-attack use/decline guard | H9 runtime upgrade `rule_state` on the attacking `ShipInstance` |
| H9 legality and effect semantics | H9 rule implementation and replayable H9 commands, using authoritative state |
| H9 dice mutation | `UseH9Command` through the accepted authoritative current-attack state owner |
| H9 decline mutation | `DeclineH9Command` through H9 runtime upgrade `rule_state` |
| Attack Modify continuation mutation | Existing replayable `confirm_attack_dice` command after it satisfies CON-005 continuation semantics |
| Projection and visibility | Derived `UIProjector` / `StateFilter` output only |
| Command sequencing and replay history | Existing command path and authoritative command stream |
| CAP rule-specific evidence | CAP-H9-001, after implementation evidence exists |

### 5.2 Explicit Non-Owners

These surfaces may integrate with or consume the lifecycle but must not decide
eligibility, completion, or continuation:

- `RuleRegistry`;
- `FlowSpec`;
- `CommandApplicability`;
- `CommandProcessor`;
- `GameManager`;
- `InteractionFlow`;
- `UIProjector`;
- `StateFilter`;
- modal and command routers;
- `AttackPanelMirror` and scene controllers;
- projection payloads;
- command result payloads;
- H9 rule code;
- CAP documents.

### 5.3 Prohibited Implementation Shapes

This tranche must not introduce:

- provider interfaces;
- catalog services;
- service locators;
- dependency-injection containers;
- strategy hierarchies;
- plugin systems;
- a registry distinct from `RuleRegistry`;
- runtime timing-window definition objects;
- serialized opportunity objects or queues;
- local participant lists;
- rule-owned or UI-owned continuation;
- callback-based authoritative cleanup;
- lifecycle state inside `InteractionFlow.payload`;
- a general effect graph or generic priority engine.

## 6. Repository Evidence

### 6.1 Documents Inspected

- `AGENTS.md`
- `ARCHITECTURE.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- `docs/architecture/decision_workbooks/TIM-001-timing-window-ownership-and-continuation-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-timing-window-implementation-obligations-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-owner-decisions.md`
- `docs/architecture/migration_assessments/MA-TW-001-cross-consumer-synthesis.md`
- `docs/architecture/migration_assessments/MA-H9-001-con-005-compliance.md`
- `docs/architecture/rule_capability_packages/CAP-H9-001-h9-turbolasers.md`
- `docs/architecture/implementation_workbooks/TWI-001-timing-window-state-implementation-workbook.md`
- `docs/game_flow.md`
- `.skills/testing_standards.md`
- `.skills/serialization_and_commands.md`

### 6.2 Slice 1 Evidence Inspected

- `src/core/state/timing_window_state.gd`
- `src/core/state/game_state.gd`
- `src/core/network/state_filter.gd`
- `src/autoload/save_game_manager.gd`
- `src/core/commands/game_replay.gd`
- `src/autoload/replay_driver.gd`
- `src/autoload/baseline_trace.gd`
- `scripts/run_baseline_traces.sh`
- Slice 1 additions in `tests/unit/test_game_state.gd`
- Slice 1 save/load, replay, reconnect, runtime-upgrade, and baseline changes
- committed Slice 1 change `70c1e75`

Slice 1 is committed and supplies the required lifecycle-state substrate.

### 6.3 Shared Runtime Evidence Inspected

- `src/core/effects/rule_registry.gd`
- `src/core/effects/flow_hook.gd`
- `src/autoload/rule_bootstrap.gd`
- `src/core/state/flow_spec.gd`
- `src/core/state/interaction_flow.gd`
- `src/core/commands/command_applicability.gd`
- `src/core/commands/game_command.gd`
- `src/autoload/command_processor.gd`
- `src/core/commands/command_submitter.gd`
- `src/core/commands/local_command_submitter.gd`
- `src/core/commands/network_host_command_submitter.gd`
- `src/core/commands/network_command_submitter.gd`
- `src/autoload/network_manager.gd`
- `src/autoload/game_manager.gd`
- `src/core/network/ui_projector.gd`
- `src/scenes/game_board/command_router_adapter.gd`
- `src/scenes/game_board/modal_router.gd`
- `src/scenes/game_board/attack_panel_controller.gd`
- `src/scenes/game_board/attack_panel_mirror.gd`

Key repository findings:

- `RuleRegistry` already centralizes deterministic static rule descriptors and
  sorts hooks by priority and rule identity. It has no timing-window candidate
  index yet.
- `RuleBootstrap` already provides one static registration root. H9 is not
  registered.
- `CommandProcessor` already owns registration, applicability, validation,
  execution, history, mirror execution, and a deferred follow-up queue. It must
  remain command infrastructure, not timing-window completion authority.
- local, host, and client submitters already distinguish local execution,
  authoritative host execution/broadcast, and client request/await behavior.
- network results are applied in command sequence order before local
  projection.
- `UIProjector` already derives intent and RuleRegistry enabler affordances
  from state, while `ModalRouter` dispatches presentation after
  `command_executed`.
- `StateFilter` already applies viewer-specific filtering to serialized
  `GameState`, but it does not yet derive or filter timing-window opportunities.

### 6.4 Attack And H9 Evidence Inspected

- `Resources/Game_Components/upgrades/turbolasers/h9_turbolasers.json`
- `Resources/Game_Components/upgrades/turbolasers/w0_h9_turbolasers_rules.txt`
- `src/core/combat/dice.gd`
- `src/core/combat/attack_state.gd`
- `src/core/combat/attack_flow_executor.gd`
- `src/core/combat/attack_flow_fsm.gd`
- `src/core/commands/publish_attack_flow_command.gd`
- `src/core/commands/reroll_attack_die_command.gd`
- `src/core/commands/skip_attack_modifier_command.gd`
- `src/core/commands/confirm_attack_dice_command.gd`
- `src/scenes/game_board/attack_executor.gd`
- `src/scenes/game_board/attack_panel_controller.gd`
- `src/scenes/game_board/attack_panel_mirror.gd`
- current Swarm rule and tests as coexistence/regression evidence

Key repository findings:

- H9 static data exists and remains `NOT_INTEGRATED`; no H9 rule or command
  implementation exists.
- red and blue dice have Accuracy faces; black dice do not.
- `ATTACK / ATTACK_MODIFY` already exists in `FlowSpec`, with attacker control
  and `confirm_attack_dice` as an allowed marker command.
- `confirm_attack_dice` is currently submitted from UI/GameManager and its
  `execute()` does not perform the authoritative continuation mutation. The
  attack scene reacts after command execution. This is migration evidence, not
  the accepted CON-005 endpoint.
- current `AttackState` holds attack identity and dice in scene-owned,
  non-serialized state. `InteractionFlow.payload` mirrors dice and identity for
  projection. H9 cannot treat that payload as command authority.
- `RerollAttackDieCommand` currently updates `InteractionFlow.payload`; this is
  useful command-shape evidence but not authority precedent for H9.
- current Swarm projection uses local payload flags and a rule-specific panel
  section. It must not be copied into H9.

### 6.5 Verification Evidence Inspected

- `tests/unit/test_rule_registry.gd`
- `tests/unit/test_flow_hook.gd`
- `tests/unit/test_flow_spec.gd`
- `tests/unit/test_command_applicability.gd`
- `tests/unit/test_ui_projector.gd`
- `tests/unit/test_state_filter.gd`
- `tests/unit/test_game_replay.gd`
- `tests/unit/test_replay_driver.gd`
- `tests/unit/test_network_command_result_ordering.gd`
- `tests/integration/test_reconnection_mid_attack.gd`
- attack-flow, attack-panel, dice, command, replay, save/load, and network
  harness tests located by repository search

The existing test organization supports focused unit files plus protocol-level
integration and baseline evidence. New shared protocol suites should reuse
those layers instead of creating a parallel test harness.

## 7. Current State And Required End State

### 7.1 Current State

The repository has authoritative serialized lifecycle state from Slice 1, but
no active producer or consumer of that state. Timing-window policy, candidate
discovery, opportunities, continuation gating, and shared evidence are absent.

Current attack-modifier behavior is distributed across:

- `FlowSpec` static flow metadata;
- scene-owned `AttackState`;
- `AttackFlowFSM` and `AttackExecutor`;
- `InteractionFlow.payload` projection;
- command applicability and command validators;
- `AttackPanelMirror` rule-specific rendering;
- GameManager submit helpers and remote command classification.

That distribution is valid implementation evidence but cannot become H9's
timing-window ownership model.

### 7.2 Required End State

After Slice 8:

1. `ATTACK_MODIFY` has one immutable static definition in the shared
   timing-window module.
2. The orchestrator opens and owns the active lifecycle using
   `GameState.timing_window_state`.
3. The orchestrator discovers candidates only through `RuleRegistry`.
4. H9 derives canonical opportunities from authoritative attack and runtime
   upgrade state.
5. H9 use and decline are explicit replayable commands with lifecycle identity.
6. The H9 runtime upgrade owns the current-attack resolved guard.
7. Opportunities are re-derived after each accepted relevant command.
8. The attacker selects among all currently available optional opportunities.
9. `confirm_attack_dice` is derived and submitted exactly once only after no
   blocking opportunities remain.
10. The continuation command performs its authoritative transition and normal
    validation; presentation reacts afterward.
11. Projection and live routing consume derived opportunities without
    authorizing them.
12. Save/load, replay, reconnect, host/client mirroring, visibility, cleanup,
    and failure behavior satisfy TEST-003.
13. Tarkin and ECM behavior is unchanged and remains transitional.

## 8. Dependency Order And Execution Rule

The implementation dependency is strict:

```text
completed Slice 1 lifecycle state
  -> Slice 2 static ATTACK_MODIFY definition
  -> Slice 3 orchestrator lifecycle core
  -> Slice 4 RuleRegistry candidates and derived opportunities
  -> Slice 5 command protocol and continuation integration
  -> Slice 6 projection and live route
  -> Slice 7 shared persistence/replay/network/cleanup evidence
  -> Slice 8 H9 clean pilot and unique evidence
```

No later slice begins until the preceding checkpoint passes. A single branch or
implementation task may carry the tranche, but each slice must leave the
repository in a deterministic, testable intermediate state. Do not implement
all seven slices and then attempt first verification.

The implementation may combine two adjacent slices in one commit only when:

- the earlier slice cannot compile without the immediately following seam;
- its focused checkpoint still runs separately;
- the diff can still be reviewed against both binary acceptance sets;
- no H9 behavior is introduced before the shared path exists.

## 9. Slice 2 -- Static Timing-Window Definition

### 9.1 Objective

Add the smallest immutable shared definition mapping needed by the first
consumer: `ATTACK_MODIFY`.

### 9.2 Prerequisites

- Slice 1 is committed and passing.
- No active timing-window producer exists.
- The existing `FlowSpec` row and `confirm_attack_dice` command remain
  repository evidence, not lifecycle policy owners.

### 9.3 Recommended Implementation Shape

Create one static, non-instantiated module under the existing core state/rule
area, preferably a narrow path such as:

- `src/core/timing_windows/timing_window_definitions.gd`

Use a constant Dictionary mapping or equivalent immutable static GDScript data.
Do not create definition instances, loaders, providers, services, or a new
registry.

The `ATTACK_MODIFY` entry contains only the CON-005 static policy equivalent to:

- timing-window identity;
- supported lifecycle stage or stages;
- fixed-controller policy: attacker;
- one RuleRegistry participant-index key for Attack Modify opportunities;
- canonical continuation command type: `confirm_attack_dice`;
- normal completion only through successful `confirm_attack_dice`;
- cancellation through the authoritative attack cancellation/end command path,
  including `skip_attack` when it exits an active Attack Modify interval;
- explicit replacement only when the authoritative attack flow replaces the
  active attack interval;
- close-and-open only after the prior interval has completed, cancelled, or
  been explicitly replaced, always with a fresh lifecycle identity.

Use stable string or enum-compatible values already used by serialization and
command registration. Do not copy dynamic `FlowSpec` payload, attacker
identity, dice, rule identities, visibility, legality, or command payloads into
the definition.

Only `ATTACK_MODIFY` is activated in this tranche. Later Tarkin and ECM
migrations add their definitions in the same mapping when their exact
continuation and cleanup paths are implemented.

### 9.4 Likely Change Surfaces

- new shared static definition module;
- focused static-definition unit test;
- preload from the future orchestrator only after Slice 3.

No changes are required yet to:

- `TimingWindowState`;
- `RuleRegistry`;
- `FlowSpec`;
- commands;
- projection;
- attack scenes.

### 9.5 Authority Guard

The table describes policy but never answers whether an H9 source is present,
whether a die is eligible, who the current runtime attacker is, whether the
window is complete, or whether continuation is currently legal.

### 9.6 Checkpoint

Expected state after Slice 2:

- the repository has one canonical shared definition location;
- it contains one inert `ATTACK_MODIFY` entry;
- no runtime lifecycle behavior changes;
- no definition object is serialized or instantiated.

Focused tests:

- known `ATTACK_MODIFY` lookup returns exactly the accepted static fields;
- unknown identity fails closed or returns no definition deterministically;
- returned data cannot mutate the canonical table through aliasing;
- forbidden dynamic keys are absent;
- `FlowSpec` remains unchanged and non-authoritative.

Proceed when all tests pass and review finds exactly one static owner.

Stop when:

- implementing the table appears to require callbacks or runtime objects;
- a second registry or provider is proposed;
- `FlowSpec` would become the owner;
- H9/Tarkin/ECM runtime behavior is pulled forward.

### 9.7 Binary Acceptance Criteria

- [ ] Exactly one shared static definition mapping exists.
- [ ] `ATTACK_MODIFY` maps to attacker control, the participant key, and
      `confirm_attack_dice` continuation.
- [ ] The mapping contains no runtime values or callbacks.
- [ ] No other surface owns competing timing-window policy.
- [ ] Focused tests pass.
- [ ] No runtime behavior changes.

## 10. Slice 3 -- Timing Window Orchestrator Core

### 10.1 Objective

Implement the minimum orchestrator that owns lifecycle transitions,
re-derivation coordination, blocker evaluation, continuation coordination,
exact-one prevention, and shared lifecycle cleanup.

### 10.2 Prerequisites

- Slice 2 definition tests pass.
- Slice 1 lifecycle state remains unchanged.
- No capability-specific behavior is needed to unit-test the lifecycle core;
  deterministic test participants may be introduced later in Slice 4.

### 10.3 Recommended Class Boundary

Add one narrow shared orchestrator, preferably:

- `src/core/timing_windows/timing_window_orchestrator.gd`

Use a `RefCounted` or static utility consistent with existing core modules. Do
not make it an autoload, scene node, generic service, or dependency-injection
target unless repository evidence at implementation time proves that the
existing command composition root cannot invoke it otherwise.

The public semantic operations should remain small and explicit:

- open a known timing window from authoritative lifecycle context;
- inspect/re-derive current opportunities;
- process one successful relevant command;
- close after successful continuation;
- cancel;
- replace;
- reconstruct/reconcile after load, replay initialization, reconnect, or
  mirror application.

Concrete method names and signatures are implementation details. They must not
expose mutable internal opportunity collections or accept UI/projection data as
authority.

### 10.4 Command-Stream Integration Seam

Use one explicit orchestrator invocation in the existing successful command
result path. The invocation may be placed beside `CommandProcessor` result
integration, but the boundary must be visible:

- `CommandProcessor` reports a successful authoritative mutation;
- the orchestrator decides whether the command affects an active timing
  window, re-derives, and decides whether continuation is due;
- the existing submitter/queue infrastructure submits the orchestrator-derived
  continuation as a normal command;
- `CommandProcessor` does not inspect blockers or decide completion.

The existing deferred follow-up ordering is useful mechanism evidence. It may
carry an orchestrator-produced continuation only if the triggering command is
recorded and broadcast first and if observer follow-ups cannot overtake or
duplicate the continuation.

Execution modes must be explicit and deterministic:

| Mode | Orchestrator behavior |
| --- | --- |
| Hot-seat/live authority | Re-derive and may request exactly one continuation submission. |
| Network host authority | Re-derive and may queue continuation behind the triggering authoritative result. |
| Network client mirror | Re-derive for local projection only; never synthesize commands. |
| Replay application | Re-derive and validate state; consume the recorded continuation command rather than synthesize a duplicate. |
| Save/load or reconnect reconstruction | Re-derive state/projection; do not synthesize a command merely because reconstruction occurred. |

Do not encode these as strategy classes. Use the smallest explicit invocation
context supported by current submitter and replay seams.

### 10.5 Lifecycle Semantics

The orchestrator must:

- reject unknown definition identities;
- enforce one active window;
- open with a fresh lifecycle identity;
- distinguish reopen of the same type from the prior interval;
- resolve the current controller from static policy and authoritative context;
- preserve the active lifecycle on discovery, derivation, or continuation
  failure;
- keep the window open while a blocker exists;
- prevent duplicate continuation for one lifecycle interval;
- clear only shared lifecycle state after successful continuation/close;
- support explicit cancellation and replacement without nesting;
- never mutate H9 or other rule-owned state.

### 10.6 Likely Change Surfaces

- new orchestrator module;
- shared definition preload;
- narrow command-result integration seam in `CommandProcessor` and/or the
  current submitter composition root;
- focused orchestrator lifecycle tests.

Do not yet add H9, projection, or production participant behavior.

### 10.7 Safe Intermediate State

After Slice 3 the orchestrator exists but no production flow opens a timing
window. Its lifecycle behavior is proven with direct state setup and controlled
test seams. Existing game behavior is unchanged.

### 10.8 Checkpoint

Focused tests prove:

- open from inactive creates one valid active lifecycle;
- opening while active is rejected unless explicit replacement is used;
- same-type reopen receives distinct identity;
- cancel, replace, and close follow permitted transitions;
- no-op/rejected commands do not trigger continuation;
- successful relevant commands request re-derivation;
- one blocker keeps the window open;
- zero blockers requests one continuation;
- repeated processing cannot request a second continuation;
- continuation failure leaves the lifecycle active and does no cleanup;
- mirror/replay/reconstruction modes do not synthesize continuation;
- no rule-owned state is mutated.

Proceed when the orchestrator can be tested without UI, GameManager lifecycle
logic, or a capability-specific shortcut.

Stop when:

- command ordering cannot guarantee trigger-before-continuation;
- replay would synthesize a duplicate continuation;
- client mirror would submit a command;
- exact-one prevention requires stored opportunity queues;
- the implementation makes `CommandProcessor` the completion owner.

### 10.9 Binary Acceptance Criteria

- [ ] One orchestrator owns all shared lifecycle transitions.
- [ ] `TimingWindowState` remains lifecycle-only.
- [ ] Live authority and mirror/replay modes are deterministic.
- [ ] Blocking and no-blocking paths are proven.
- [ ] Continuation failure preserves the active window.
- [ ] Exact-one continuation is proven.
- [ ] Existing runtime behavior remains unchanged.

## 11. Slice 4 -- Participant Indexing And Opportunity Records

### 11.1 Objective

Extend the existing `RuleRegistry` with one static timing-window participant
index and add one canonical derived opportunity shape.

### 11.2 Prerequisites

- Slice 3 lifecycle checkpoint passes.
- `RuleRegistry` remains the only registry.
- No production H9 candidate is registered yet.

### 11.3 RuleRegistry Extension

Extend the existing registration style rather than introducing a participant
service. The minimum entry identifies:

- capability identity;
- timing-window participant key;
- one repository-supported participant kind or derivation entry point;
- deterministic diagnostic identity.

The existing `RuleBootstrap` remains the single static registration root.
Registration may use a narrow descriptor or dictionary consistent with current
`FlowHook` patterns. It must not store runtime sources, current players,
opportunities, legality, ordering, visibility, continuation, or mutation.

The index returns candidates in deterministic order. It suppresses duplicate
candidates for the same capability identity and authoritative source identity
before derivation when the same static path is registered more than once.
Because runtime source identity is not known from static registration alone,
the suppression boundary must combine the static candidate with sources found
from authoritative state during derivation; it must not guess or cache sources
inside RuleRegistry.

Unknown/unsupported participant registration and invalid derivation must fail
closed with diagnostics, preserve authoritative state, present no ambiguous
opportunity, and prevent continuation for that evaluation pass.

### 11.4 Canonical Opportunity Shape

Use one derived plain Dictionary or equally minimal immutable-by-convention
record returned fresh on each derivation pass. Do not create persistent
opportunity instances or UUIDs.

Every opportunity contains exactly the semantic data accepted by CON-005:

- capability identity;
- source-owner kind;
- authoritative runtime-source identity;
- stable semantic opportunity key;
- controlling player identity;
- resolution kind: `OPTIONAL` or `REQUIRED_CHOICE`;
- blocking status;
- registered replayable use command intent;
- explicit decline command intent for optional blockers.

Command intents contain only:

- registered command type;
- minimum authoritative identity context, including active lifecycle identity
  and source identity.

The record contains no legality cache, mutable rule state, effect result,
projection labels, arbitrary callback, selected ordering, continuation
decision, or visibility authority.

Provide one shared constructor/validator/canonical-key helper so every future
participant produces the same shape. This helper is data validation, not a
provider, strategy, or effect engine.

### 11.5 Derivation Protocol

For every pass:

1. read the active static definition;
2. query RuleRegistry by its participant key;
3. resolve each candidate's runtime sources from authoritative state;
4. suppress duplicate candidates for the same capability/source pair;
5. ask each supported participant to derive zero or more opportunities;
6. validate every opportunity shape and controller;
7. build canonical identity from capability, owner kind, runtime source, and
   semantic key;
8. fail closed if duplicate derived identities remain;
9. return a fresh deterministic presentation order without choosing for the
   player.

An absent runtime source produces no opportunity and is not itself a failure.
A participant derivation error is a failure and must not be treated as no
opportunities.

### 11.6 Likely Change Surfaces

- `src/core/effects/rule_registry.gd`;
- `src/autoload/rule_bootstrap.gd` test setup only at this slice;
- orchestrator derivation path;
- one small canonical opportunity helper under the shared timing-window
  module, if keeping it inside the orchestrator would obscure validation;
- RuleRegistry and orchestrator unit tests;
- deterministic test participant fixtures under `tests/fixtures/`.

### 11.7 Safe Intermediate State

After Slice 4, only tests register timing-window participants. No production
flow opens a timing window and no H9 behavior exists.

### 11.8 Checkpoint

Focused tests prove:

- RuleRegistry lookup is deterministic and static;
- no local participant list exists;
- absent runtime source yields zero opportunities without mutation;
- duplicate static candidates suppress deterministically;
- unknown participant kind fails closed;
- participant derivation failure fails closed and blocks continuation;
- canonical identity includes all four identity components;
- no synthetic persistent UUID is used;
- duplicate derived identity fails closed without choosing or merging;
- all current opportunities are re-derived after relevant mutation;
- deterministic ordering never auto-selects an option;
- optional blockers always contain use and decline command intents.

Proceed when a test participant can exercise the entire discovery and
opportunity path without H9-specific code.

Stop when:

- RuleRegistry begins resolving runtime eligibility;
- opportunity records need mutable lifecycle state;
- callbacks appear in static definitions;
- a second registry or provider abstraction is proposed.

### 11.9 Binary Acceptance Criteria

- [ ] RuleRegistry is the only candidate source.
- [ ] Candidate identity and participant key are static.
- [ ] Canonical opportunity records are fresh and derived.
- [ ] Duplicate candidate and duplicate opportunity semantics differ exactly as
      required by CON-005.
- [ ] Player ordering is preserved.
- [ ] Focused protocol tests pass.

## 12. Slice 5 -- Command Protocol And Continuation Integration

### 12.1 Objective

Integrate lifecycle identity, use/decline validation, applicability agreement,
re-derivation, and normal replayable continuation into the existing command
path before adding production H9 behavior.

### 12.2 Prerequisites

- Slice 4 discovery/opportunity checkpoint passes.
- The shared test participant can produce blocking opportunities with command
  intents.
- No UI route is required to submit test commands.

### 12.3 Shared Command Identity

Every timing-window use, decline, marker, effect, follow-up, cleanup, and
continuation command must carry enough stable context to validate:

- active timing-window identity;
- lifecycle identity;
- source-owner identity;
- authoritative runtime-source identity;
- stable semantic opportunity key where applicable;
- acting player.

Do not serialize an opportunity record or projection payload into the command.
The command re-derives or directly validates current legality from
authoritative state.

### 12.4 Validation Agreement

For every timing-window command, all three layers must agree:

- `FlowSpec.allowed_commands` describes the accepted flow/step;
- `CommandApplicability` enforces the broad authoritative phase/flow/window
  boundary;
- concrete command `validate()` enforces lifecycle, controller, source,
  opportunity, cost, repeat-use/decline, and rule-specific legality.

No layer may allow UI/projection data to authorize the command. Wrong phase,
window, lifecycle, player, source, opportunity, cost, repeated use, repeated
decline, or stale selection rejects without mutation or continuation.

### 12.5 Continuation Command Integration

`confirm_attack_dice` remains the canonical `ATTACK_MODIFY` continuation. The
tranche must bring it to the CON-005 boundary:

- the orchestrator derives it from the static definition;
- UI and GameManager no longer decide that all blockers are resolved;
- the command carries and validates lifecycle identity when used as timing
  continuation;
- the command validates normal attack-flow legality;
- successful execution performs the authoritative Attack Modify exit mutation
  or invokes the existing authoritative attack-flow mutation seam;
- the orchestrator clears shared lifecycle state only after successful
  continuation;
- presentation handlers react to the result but do not perform the
  authoritative transition;
- a failed continuation leaves the timing window active and does not clear H9
  or shared state.

Existing non-timing replay compatibility must be considered explicitly. Do not
silently reinterpret old `confirm_attack_dice` entries. If old recorded
commands lack lifecycle identity, use the repository's existing replay/state
compatibility posture and document one deterministic reconstruction or reject
behavior in the implementation evidence.

`skip_attack` requires the parallel cancellation correction when submitted
inside an active `ATTACK_MODIFY` lifecycle. It is currently a replayable no-op
marker whose presentation pipeline performs flow control. In this tranche it
must validate the active lifecycle identity and perform or invoke the
authoritative attack cancellation/end mutation before the orchestrator clears
shared lifecycle state. Rejected cancellation leaves the window and H9 guard
unchanged. This does not broaden `skip_attack` behavior outside the active
timing-window case.

### 12.6 Opening The ATTACK_MODIFY Window

The existing replayable `publish_attack_flow(ATTACK_MODIFY)` command is the
preferred repository seam for opening the window because it already identifies
the transition in network command history.

For the H9 path to be deterministic:

- live hot-seat and network authority must both execute an authoritative
  command for entering `ATTACK_MODIFY`;
- scene-local `AttackFlowFSM` mutation before publication must not become the
  lifecycle authority;
- replay consumes the recorded opening command;
- client mirrors consume the host command in sequence;
- opening creates a fresh lifecycle identity and controller from authoritative
  attack context;
- duplicate publication must not reopen the same interval or create a second
  lifecycle.

The exact refactor of `submit_publish_attack_flow` and `AttackFlowFSM` is an
implementation decision, but the resulting command sequence must be identical
in hot-seat, host, client mirror, and replay.

### 12.7 Likely Change Surfaces

- shared command identity helper only if duplication would otherwise occur;
- `CommandProcessor` registration/integration tests;
- `FlowSpec`;
- `CommandApplicability`;
- `publish_attack_flow_command.gd`;
- `confirm_attack_dice_command.gd`;
- `skip_attack_command.gd` for active-window cancellation only;
- local/host/client submitter and network ordering seams where needed;
- attack flow command-reaction surface to remove authoritative transition from
  presentation;
- shared protocol command fixtures/tests.

Do not add H9 commands until the shared command checkpoint passes.

### 12.8 Safe Intermediate State

After Slice 5, a test participant can open a real `ATTACK_MODIFY` lifecycle,
resolve or decline through commands, re-derive, and continue exactly once.
Production H9 remains absent. Existing attack behavior without an active timing
window remains compatible.

### 12.9 Checkpoint

Focused tests prove:

- opening command creates one lifecycle in hot-seat authority mode;
- duplicate/open-stale commands fail deterministically;
- use and decline serialize/deserialize and enter command history;
- wrong player, wrong flow, wrong window, stale lifecycle, missing source,
  repeated use, and repeated decline reject consistently at applicability and
  concrete validation boundaries;
- one selected opportunity resolves per command;
- the orchestrator re-derives after success;
- remaining blockers prevent `confirm_attack_dice`;
- no blockers produce one queued continuation behind the resolving command;
- continuation executes through normal validation;
- continuation failure preserves lifecycle and rule state;
- active-window `skip_attack` cancellation is command-owned and cleans shared
  lifecycle only after its authoritative mutation succeeds;
- replay uses the recorded continuation and does not create a duplicate;
- clients never synthesize continuation;
- presentation reactions cannot bypass the command path.

Proceed only when command history order is stable and no UI is needed to prove
the full protocol.

Stop when:

- `confirm_attack_dice` still depends on a scene callback for authoritative
  mutation;
- hot-seat and network opening sequences differ semantically;
- replay requires an unapproved compatibility mechanism;
- a continuation can overtake the final opportunity command.

### 12.10 Binary Acceptance Criteria

- [ ] Every timing command validates lifecycle identity.
- [ ] FlowSpec, applicability, and concrete validation agree.
- [ ] Opening and continuation are commands in authoritative order.
- [ ] Rule commands never complete the window.
- [ ] Exactly one continuation occurs after final re-derivation.
- [ ] Failed continuation preserves active lifecycle and owned state.
- [ ] Replay and clients do not synthesize duplicates.

## 13. Slice 6 -- Projection And Live Route Integration

### 13.1 Objective

Project all current derived opportunities for the current viewer and dispatch
selected use/decline intents through the normal submitter path.

### 13.2 Prerequisites

- Slice 5 protocol passes without UI.
- Opportunity records contain canonical command intents.
- Viewer visibility and command authority remain separate.

### 13.3 Projection Shape

Extend `UIProjector.UIIntent` with one timing-window-oriented derived surface,
using the existing intent/affordance pattern rather than an H9-specific modal
model.

Projection may include display-safe copies of:

- lifecycle identity for stale UI detection, never as sole authorization;
- current controller;
- visible opportunity identity;
- command intent needed for dispatch;
- rule display key/text reference;
- resolution kind and whether decline is offered;
- public or owner-filtered status derived through accepted visibility rules.

Projection must not include or become:

- stored legality;
- authoritative opportunity ownership;
- mutable rule state;
- continuation decision;
- command result authority;
- hidden data used as authorization.

The projector re-derives from authoritative state or consumes a fresh
orchestrator derivation result from the same state revision. It must not read a
serialized opportunity queue.

### 13.4 Viewer Filtering

H9 is public under CAP-H9-001. Both players may observe availability,
use/decline, and changed dice. Only the current attacker may submit.

Shared projection tests must also prove the generic boundary:

- owner-only opportunities are absent or redacted for non-owners;
- hidden source details do not leak through command intents;
- visibility does not grant command authority;
- filtered reconnect data re-derives the same legal viewer projection;
- authoritative validation remains correct if a client submits stale or
  manually constructed visible intent data.

Use `StateFilter` for viewer-specific serialized-state filtering and
`UIProjector` for presentation derivation. Do not put authorization rules in
either surface.

### 13.5 Live Routing

Extend the existing `CommandRouterAdapter` / `ModalRouter` / attack-panel
composition with one timing-window-oriented controller surface. The UI:

- renders all currently selectable opportunities;
- lets the controller choose order;
- submits exactly the canonical use or decline command intent through
  `GameManager.get_command_submitter()` or the equivalent existing normal
  command path;
- disables or refreshes stale controls after a command is submitted;
- waits for authoritative network result before treating mutation as final;
- never submits `confirm_attack_dice` on the basis of local emptiness.

Reuse the current attack panel and tooltip mechanisms. Do not create an
H9-only modal when a shared Attack Modify opportunity list can fit the existing
panel.

### 13.6 Likely Change Surfaces

- `src/core/network/ui_projector.gd`;
- `src/core/network/state_filter.gd` where viewer filtering requires it;
- `InteractionFlow` payload construction only as derived display data;
- `CommandRouterAdapter` / `ModalRouter`;
- `AttackPanelController`, `AttackPanelMirror`, and existing attack panel UI;
- focused projector, filter, router, and panel tests.

### 13.7 Safe Intermediate State

After Slice 6, test participants can be rendered and submitted through the live
route. H9-specific labels and mutation remain absent until Slice 8. Existing
Swarm controls continue to work as a regression surface.

### 13.8 Checkpoint

Focused tests prove:

- all selectable opportunities are projected together;
- deterministic display order does not auto-select;
- public H9-shaped fixture data is visible to both viewers but interactive only
  for controller;
- owner-only/hidden fixture data is filtered correctly;
- stale projected intents fail authoritative command validation;
- modal/panel teardown does not clear authoritative state;
- live use and decline dispatch the same serialized commands as direct,
  replay, and network paths;
- UI cannot submit continuation;
- reconnect rebuilds projection without UI-local memory.

Proceed when the shared UI can operate using only derived intent and the normal
submitter.

Stop when:

- a modal or panel caches authoritative opportunity state;
- visibility filtering is used as authorization;
- H9-specific UI logic is required before the H9 rule exists;
- client-side emptiness triggers continuation.

### 13.9 Binary Acceptance Criteria

- [ ] Projection is fresh, viewer-specific, and non-authoritative.
- [ ] All optional choices are presented for player ordering.
- [ ] Live dispatch uses registered replayable commands.
- [ ] Only controller submissions validate.
- [ ] UI/modal closure owns no lifecycle or cleanup.
- [ ] Projection and live-route tests pass.

## 14. Slice 7 -- Shared Persistence, Replay, Network, Cleanup, And Protocol Evidence

### 14.1 Objective

Complete the shared TEST-003 protocol evidence before H9 becomes the first
production participant.

### 14.2 Prerequisites

- Slices 2-6 checkpoints pass.
- The full protocol is exercisable with deterministic test participants.
- The implementation uses existing serialization, replay, submitter, network
  mirror, filter, and reconnect paths.

### 14.3 Shared Evidence Strategy

Create reusable protocol suites that future timing-window CAPs can reference by
exact test and matrix category. Keep shared assertions about lifecycle
protocol separate from rule-specific assertions.

Preferred existing test layers:

| Evidence layer | Existing repository seam | Shared obligations |
| --- | --- | --- |
| Unit | RuleRegistry/orchestrator/command/projector tests | definitions, discovery, identity, duplicate/failure semantics, controller, validation |
| Protocol integration | direct command submitter with deterministic participants | open/use/decline/rederive/continue/cleanup sequence |
| Save/load | `GameState.serialize()` + `SaveGameManager` tests | active and post-window reconstruction |
| Replay | `GameReplay`, `ReplayDriver`, command history tests | recorded order, no stored opportunities, no duplicate continuation |
| Reconnect | serialize -> `StateFilter` -> deserialize -> `UIProjector` | lifecycle, rule state, visibility, derived projection |
| Network | submitter/NetworkManager/GameManager ordering harness | host authority, client mirror, no client synthesis, no overtaking |
| Runtime smoke | baseline/replay harness or focused scene integration | actual live route and modal/panel dispatch |

Do not create a timing-window-specific replay format, save format, transport,
or network harness if the existing surfaces can prove the obligation.

### 14.4 Serialization And Compatibility

- Continue serializing lifecycle through `GameState.timing_window_state`.
- Serialize rule-owned pending state on its accepted owner.
- Never serialize opportunities or participant lists.
- Missing old timing-window state reconstructs inactive as accepted by TWI-001.
- Invalid present timing-window state fails `GameState.deserialize()` and
  `SaveGameManager` reports `schema_invalid` as accepted by TWI-001.
- `SaveGameMetadata.CURRENT_VERSION` remains the save compatibility owner.
- `GameReplay.FORMAT_VERSION` remains the replay-file compatibility owner.
- Do not bump replay format merely because command types or canonical
  `GameState` serialized shape change compatibly.
- Any incompatible command/lifecycle payload change must choose one documented
  migrate, reconstruct, or reject behavior through existing authority.

### 14.5 Replay

Replay evidence must prove:

- opening, use, decline, effect, cleanup, and continuation commands occur in
  authoritative history order;
- opportunities are re-derived after each replayed command;
- replay never replays a stored opportunity queue;
- replay does not auto-submit a second continuation when the recorded
  continuation is next;
- stale lifecycle commands reject at the same point as live commands;
- continuation failure preserves the active lifecycle.

### 14.6 Save/Load And Reconnect

Evidence must cover:

- active window before choice;
- active window after one choice with another blocker remaining;
- state after final use/decline but before recorded continuation where the
  command sequence can represent that boundary;
- post-continuation state;
- cancelled/replaced/closed lifecycle identity;
- old-save absence and invalid-state failure inherited from Slice 1;
- viewer-specific projection after filtered reconnect;
- no resurrection of stale opportunities outside the window.

### 14.7 Networking

Use the existing host/client command stream:

- host validates and executes;
- triggering opportunity command broadcasts before continuation;
- client buffers/applies results in sequence;
- client re-derives projection after each mirrored result;
- client never creates use, decline, cleanup, effect, or continuation commands
  from local projection;
- remote command classification includes handled no-op entries for all shared
  timing protocol command types;
- out-of-order, delayed, duplicate, and stale results cannot mutate or
  continue the active lifecycle;
- host/client final authoritative state and projected state agree.

Transport or RPC redesign is outside this workbook.

### 14.8 Cleanup

Shared lifecycle cleanup belongs to the orchestrator. Test participants own
their own guard state through explicit test commands.

Evidence must cover:

- normal continuation;
- explicit close;
- cancellation;
- replacement;
- close-and-open with a fresh lifecycle identity;
- attack/phase/enclosing-flow exit where applicable;
- save/load or reconnect reconstruction of an invalidated window;
- rejected opportunity command;
- continuation failure;
- invalid registration;
- derivation failure;
- duplicate derived opportunity identity;
- repeated cleanup idempotency.

Failed commands must not clear unresolved guard state. Authoritative cleanup
must occur before projection cleanup.

### 14.9 Likely Change Surfaces

- shared timing-window unit/integration tests;
- existing save/load, replay, reconnect, network ordering, StateFilter, and
  UIProjector test files where their ownership boundary is already tested;
- `tests/fixtures/` deterministic participant/state builders;
- remote command classification in `GameManager` only where shared command
  types require an explicit no-op classification;
- baseline/replay fixture only after a later accepted implementation task
  authorizes expected fixture maintenance.

### 14.10 Safe Intermediate State

After Slice 7, the shared protocol has complete accepted evidence but no
production rule participant. The repository remains behaviorally unchanged for
Tarkin, ECM, H9, and existing Swarm.

### 14.11 Checkpoint

The checkpoint is the complete shared TEST-003 matrix, not only unit tests.

Required result:

- focused suites pass;
- full GUT suite passes;
- baseline traces pass or any intentional canonical state-shape hash change is
  isolated and reported for separate fixture maintenance;
- hot-seat command sequence is deterministic;
- host/client sequence and final state agree;
- replay and reconnect reconstruct the same lifecycle/projection;
- cleanup/failure matrix passes;
- no CAP-specific correctness claim is inferred from shared tests.

Proceed to H9 only after all shared categories are mapped to exact tests.

Stop when:

- any matrix category is represented only by a comment or planned test;
- a client synthesis path remains;
- a baseline difference cannot be explained by intentional serialized shape;
- shared tests require H9-specific behavior to pass.

### 14.12 Binary Acceptance Criteria

- [ ] Shared TEST-003 matrix is complete and cites exact tests.
- [ ] Serialization, save/load, replay, reconnect, and network paths agree.
- [ ] Host/client ordering prevents continuation overtaking.
- [ ] Cleanup/failure coverage is complete and idempotent.
- [ ] Visibility is verified separately from authorization.
- [ ] Shared tests make no rule-specific correctness claim.

## 15. Slice 8 -- H9 Clean Vertical Pilot

### 15.1 Objective

Implement H9 as the first production participant using only the shared path
proven by Slices 2-7.

### 15.2 Prerequisites

- all shared checkpoints pass;
- H9 catalog data remains `NOT_INTEGRATED` until evidence and Owner approval;
- no H9-specific lifecycle, continuation, projection, or registry path exists;
- current attack identity and dice can be made authoritative and serializable
  without treating `InteractionFlow.payload` or scene-local state as authority.

### 15.3 H9 Rule Boundary

Add one H9 rule implementation under the existing upgrade rule hierarchy and
register it through `RuleBootstrap` / `RuleRegistry`.

The rule implementation may:

- locate H9 runtime upgrade instances on the authoritative attacking ship;
- derive zero or one opportunity per independent H9 runtime source and stable
  semantic choice key;
- validate source activation, attack identity, controller, dice eligibility,
  same-color Accuracy availability, and current-attack guard;
- build canonical use and decline intents;
- expose display metadata through the existing tooltip/rule text mechanism.

The rule implementation must not:

- open or close the timing window;
- choose ordering;
- decide completion;
- submit continuation;
- own shared lifecycle state;
- store projection or opportunity state;
- mutate another capability's state.

### 15.4 Authoritative Attack State Dependency

H9 use must mutate authoritative current attack dice, and reconnect/save/load
must reconstruct those dice. Current repository evidence places the mutable
dice in scene-owned `AttackState` and mirrors them in
`InteractionFlow.payload`. Neither is sufficient as-is for CON-005 authority.

The minimum repository-consistent implementation is:

- retain the existing `AttackState` semantic owner for current attack identity
  and dice;
- make only the current-attack identity and dice semantics required by H9
  reachable from and serialized with authoritative `GameState`;
- make attack commands read and mutate that authoritative representation;
- derive `InteractionFlow.payload` from it for presentation;
- keep scene token/node references and purely visual attack fields transient;
- avoid creating a second H9-specific dice store.

This is an implementation completion of the CAP-H9 "attack state" owner, not a
transfer of dice into `TimingWindowState` or H9 `rule_state`.

Before implementing H9 commands, add a focused checkpoint proving one current
attack identity and dice array round-trip through `GameState` without serializing
scene nodes. If the existing `AttackState` cannot be split or attached without
a broader attack ownership decision, stop and report the dependency. Do not use
`InteractionFlow.payload` as a shortcut.

### 15.5 H9 Opportunity Derivation

For each attacking ship H9 runtime upgrade instance, derive from authoritative
state:

- capability identity for H9;
- source-owner kind: runtime ship upgrade;
- `runtime_upgrade_id`;
- stable semantic opportunity key tied to the current attack and H9 choice;
- controller: attacking player;
- resolution kind: optional;
- blocking: true while unresolved;
- `UseH9Command` intent;
- `DeclineH9Command` intent.

No opportunity is produced when:

- no H9 runtime source exists;
- source is inactive, discarded, disabled, or stale;
- current flow is not the active `ATTACK_MODIFY` lifecycle;
- attacker does not own the source;
- no die contains Hit or Critical and has a legal same-color Accuracy target;
- this source is already used or declined for this attack;
- lifecycle identity or attack identity is stale.

Multiple runtime H9 sources remain independent because identity includes each
`runtime_upgrade_id`.

### 15.6 UseH9Command

The use command must:

- be registered with `GameCommand` / `CommandProcessor`;
- be allowed only in `ATTACK / ATTACK_MODIFY` and the matching active timing
  lifecycle;
- carry acting player, lifecycle identity, current attack identity,
  `runtime_upgrade_id`, semantic opportunity key, selected die index, and
  selected same-color Accuracy face or the minimum deterministic equivalent;
- revalidate the source and selected die against current authoritative state;
- reject stale dice after any intervening modifier;
- reject wrong player/source/window/attack, repeated use/decline, illegal
  source face, no Accuracy target, and black dice;
- change exactly one eligible red or blue die to an Accuracy face;
- write the current-attack used guard to that H9 runtime upgrade `rule_state`;
- record normal command history;
- leave lifecycle completion to the orchestrator.

The command does not exhaust H9 or alter durable card state.

### 15.7 DeclineH9Command

The decline command must:

- carry the same authoritative lifecycle/source/attack identity boundary;
- revalidate current availability and controller;
- leave dice unchanged;
- write the current-attack declined guard to the H9 runtime upgrade
  `rule_state`;
- reject repeated decline, use-after-decline, decline-after-use, and stale
  lifecycle/source/attack identity;
- record an explicit command-history entry;
- leave lifecycle completion to the orchestrator.

### 15.8 Re-Derivation And Player Ordering

After each H9 use or decline:

- the orchestrator re-derives all Attack Modify participants;
- no cached H9 availability is trusted;
- all remaining blockers are projected together;
- the attacker chooses the next opportunity;
- `confirm_attack_dice` remains unavailable to the UI as a completion choice;
- the orchestrator submits it only after no blocker remains.

H9 coexistence must be proven with a second deterministic test participant
registered through the same production RuleRegistry path. The test must cover:

- second participant selected before H9;
- H9 selected before second participant;
- H9 invalidating the second participant;
- second participant changing dice and invalidating or changing H9 legality;
- another blocker remaining after H9 use or decline;
- final continuation only after all blockers resolve.

Do not migrate production Swarm merely to satisfy this test. Run current Swarm
tests as regression evidence.

### 15.9 H9 Cleanup

The orchestrator cleans only `TimingWindowState`. H9 guard cleanup occurs
through explicit authoritative command owners:

| Trigger | Required owner/path |
| --- | --- |
| H9 use | `UseH9Command` creates used guard. |
| H9 decline | `DeclineH9Command` creates declined guard. |
| Normal Attack Modify exit | Successful `confirm_attack_dice` command clears current-attack H9 guard before/with accepted exit mutation. |
| Attack end/cancellation | Existing replayable attack cancellation/end command path clears guard. |
| Window replacement/close-and-open | The authoritative replacement/closing command clears guard before new lifecycle projection. |
| Save/load or reconnect outside the attack | Deterministic reconstruction rejects or clears stale guard through an accepted authoritative reconstruction/lifecycle path; UI cleanup is insufficient. |
| Rejected H9 command | No cleanup and no lifecycle change. |
| Failed continuation | Guard and active lifecycle remain; no premature cleanup. |

Cleanup is idempotent. If no existing replayable attack command owns a required
abnormal exit, stop before adding a callback or scene observer. Determine
whether the existing cancellation/end command can own the mutation; introduce a
dedicated cleanup command only if CON-005's accepted fallback is actually
required.

### 15.10 Projection And Live Interaction

H9 uses the shared Attack Modify opportunity list:

- both players see public H9 availability/resolution;
- only the attacker can interact;
- H9 rule text uses the existing tooltip mechanism;
- use presents eligible dice and same-color Accuracy result;
- decline is explicit;
- network client waits for the host result before changing authoritative dice;
- changed dice flow into existing Accuracy spending and defense-token behavior;
- UI teardown and attack-panel mirror state are non-authoritative.

Do not add H9-specific continuation buttons or modal ownership.

### 15.11 Likely Change Surfaces

Production surfaces likely include:

- H9 rule implementation under `src/core/effects/rules/upgrades/`;
- `src/autoload/rule_bootstrap.gd`;
- `src/core/effects/rule_registry.gd` registration use;
- new `UseH9Command` and `DeclineH9Command` files;
- `src/autoload/command_processor.gd` registration;
- `src/core/state/flow_spec.gd`;
- `src/core/commands/command_applicability.gd`;
- minimum authoritative current-attack identity/dice serialization surface;
- attack opening/continuation commands and attack-flow projection seam;
- `src/core/network/ui_projector.gd`;
- `src/core/network/state_filter.gd` if filtering data shape changes;
- attack panel/controller/mirror generic opportunity rendering;
- `GameManager` remote command classification as handled no-op where no scene
  side effect is required.

Tests likely include:

- H9 rule derivation unit tests;
- H9 use and decline command tests;
- H9 runtime upgrade serialization/guard tests;
- FlowSpec/applicability agreement tests;
- shared protocol suite instantiated with H9;
- H9 plus second participant tests;
- projection/visibility/live-route tests;
- save/load, replay, reconnect, network sequence, and cleanup tests;
- existing Swarm, Accuracy, attack confirmation, and defense-token regressions;
- hot-seat and network baseline/runtime smoke evidence.

### 15.12 H9 Checkpoint

Expected state after Slice 8:

- H9 is implemented only through the shared timing-window path;
- no H9 local lifecycle or continuation code exists;
- attack dice and identity used for legality are authoritative and serialized;
- H9 guard lives only on its runtime upgrade owner;
- projection is derived;
- command history contains opening, use/decline, continuation, and downstream
  attack commands in accepted order;
- reconnect and replay reconstruct the same pending and post-resolution states;
- Tarkin and ECM behavior remains unchanged.

Proceed to Project Owner implementation review only when all H9-specific and
shared evidence is mapped. Do not update CAP status in this implementation
task.

Stop when:

- H9 needs `InteractionFlow.payload` as legality authority;
- attack identity/dice cannot be made authoritative within the accepted attack
  state boundary;
- H9 use/decline cannot be expressed as normal commands;
- cleanup requires a non-replayable callback;
- live and replay command sequences differ;
- current Swarm behavior regresses;
- any implementation requires a new architecture decision.

### 15.13 Binary Acceptance Criteria

- [ ] H9 is a RuleRegistry candidate, not a local participant.
- [ ] H9 opportunity identity uses runtime upgrade and attack identity.
- [ ] Use and decline are explicit replayable commands.
- [ ] Use changes exactly one legal die to same-color Accuracy.
- [ ] Decline changes no dice.
- [ ] H9 guard is rule-owned, serialized, and cleaned explicitly.
- [ ] Player-controlled coexistence and re-derivation are proven.
- [ ] `confirm_attack_dice` is the only normal exit and occurs exactly once.
- [ ] Projection, visibility, live route, replay, save/load, reconnect, and
      networking pass.
- [ ] Existing Swarm, Accuracy, attack confirmation, and defense behavior pass.
- [ ] CAP-H9 remains Draft/NOT_INTEGRATED pending separate evidence update and
      Owner approval.

## 16. Cross-Cutting Verification Plan

### 16.1 Verification Commands

At every slice, run the focused files added or changed. At the shared and H9
checkpoints, run the normal repository gates:

```bash
./scripts/run_tests.sh
./scripts/run_baseline_traces.sh --all
bash scripts/lint_phase_k.sh
git diff --check
```

Use the documented Codex approval workflow without `HOME` overrides or
repository-local sandbox workarounds.

### 16.2 TEST-003 Matrix

Before Slice 8 acceptance, exact tests must cover:

| TEST-003 category | Shared evidence | H9 unique evidence |
| --- | --- | --- |
| Lifecycle | open, one active, cancel, replace, close, reopen identity | ATTACK_MODIFY opens/closes on actual attack path |
| Ownership | GameState lifecycle; orchestrator decisions | H9 guard on runtime upgrade; dice on authoritative attack owner |
| Discovery | RuleRegistry candidates, duplicate suppression, invalid registration | H9 registered by capability/participant key |
| Opportunity derivation | canonical record, failure, duplicate identity | source/dice/guard legality per H9 |
| Player ordering | all choices projected, no auto-select | H9 plus second participant both orders |
| Commands/mutation | lifecycle identity, use/decline, stale rejection | exact die mutation and explicit decline |
| Re-derivation | after every accepted relevant command | H9/second participant create/invalidate cases |
| Continuation | no blockers, exact one, failure preservation | only `confirm_attack_dice` after H9 blockers |
| Cleanup | all shared trigger/failure categories | H9 guard normal/abnormal exit ownership |
| Serialization | lifecycle round-trip, no opportunities | attack dice/identity and H9 guard round-trip |
| Save/load | active/post/closed states | before choice, after use, after decline, after exit |
| Replay | recorded sequence, no duplicate synthesis | H9 use and decline histories |
| Reconnect | lifecycle + derived projection | before choice/use/decline/defense transition |
| Networking | host authority, ordered mirror, no client synthesis | H9 command classification and host/client dice equality |
| Projection/live route | derived, stale intent rejected | public H9 list, attacker-only interaction, tooltip |
| Visibility | owner/hidden/public generic cases | H9 public visibility and no authority transfer |
| Effect interaction | passive vs optional, coexistence | H9 plus second modifier; downstream Accuracy |
| Runtime smoke | shared live dispatch path | hot-seat and host/client H9 through defense window |

Passing shared protocol evidence does not prove H9 legality, mutation,
cleanup, visibility, or gameplay consequence. Passing H9 tests does not waive a
missing shared protocol category.

### 16.3 Command Sequence Oracles

Compare explicit command sequences, not only final state.

Minimum H9 use sequence:

1. authoritative opening command enters `ATTACK_MODIFY`;
2. `UseH9Command` resolves one H9 source;
3. zero or more other modifier use/decline commands resolve in player-selected
   order;
4. exactly one `confirm_attack_dice` continuation occurs;
5. existing Accuracy/defense/damage commands continue.

Minimum H9 decline sequence substitutes `DeclineH9Command` at step 2.

Hot-seat, host history, client mirror, replay, and baseline traces must agree on
semantic order. A client may receive projection between results but may not add
commands.

## 17. Compatibility And Versioning Posture

### 17.1 GameState And Saves

Reuse Slice 1 and `SaveGameMetadata.CURRENT_VERSION` behavior. Adding
authoritative current-attack serialization must be reviewed through the same
compatibility owner. Older state may reconstruct no active attack/timing window
only where that is semantically safe; invalid present state fails closed.

### 17.2 Replay

`GameReplay.FORMAT_VERSION` remains the replay-file compatibility owner. New
registered command types do not by themselves require a replay-file format
bump. Payload compatibility for `publish_attack_flow` and
`confirm_attack_dice` must be explicit because older replays may contain those
commands without lifecycle identity.

Select exactly one documented existing-authority behavior for old entries:

- reconstruct lifecycle identity from the recorded authoritative opening state
  when unique and safe; or
- reject the incompatible replay deterministically.

Do not guess and do not add a timing-window replay version.

### 17.3 Baselines

Canonical `GameState.serialize()` changes can intentionally change final-state
hashes without changing command traces. Do not preserve obsolete hashes. Update
fixtures only in an explicitly authorized baseline-maintenance task after the
implementation and semantic trace have been accepted.

### 17.4 Networking

No transport/version architecture is added here. Existing command serialization
and host/client state reconstruction carry the new fields and commands. Any
wire compatibility gap beyond existing command/state handling is outside
CON-005 and must be reported rather than solved with a timing-window transport.

## 18. Risks And Stop Conditions

### 18.1 High-Risk Implementation Areas

| Risk | Required control |
| --- | --- |
| `CommandProcessor` accidentally owns completion | Keep blocker/completion decision inside orchestrator; processor only invokes and submits. |
| Continuation overtakes final opportunity on network | Queue/broadcast trigger first; verify sequence and final state on host/client. |
| Replay synthesizes duplicate continuation | Re-derive in replay mode but consume recorded continuation only. |
| `InteractionFlow.payload` authorizes H9 | Establish serialized authoritative current-attack identity/dice before H9 commands. |
| RuleRegistry grows into runtime engine | Store only static candidate identity and participant key. |
| Opportunity cache becomes authority | Return fresh records each pass; never serialize/store mutable queue. |
| UI emptiness triggers confirm | UI submits only selected use/decline; orchestrator owns continuation. |
| H9 cleanup relies on panel teardown | Clear rule guard through explicit accepted command boundaries. |
| Shared tests overclaim CAP correctness | Maintain shared/unique matrix and exact references. |
| H9 overfits shared interfaces | Prove with generic fixtures and a second participant before H9. |
| Scope drifts into Swarm/Tarkin/ECM migration | Keep those as regression/evidence surfaces only. |

### 18.2 Mandatory Stop Conditions

Stop the implementation tranche when any of the following occurs:

- a slice checkpoint fails and the failure cannot be corrected within that
  slice's accepted boundary;
- repository evidence conflicts with ADR-005, CON-005, or TEST-003;
- Slice 1 semantics appear insufficient and would need reinterpretation;
- command ordering cannot preserve trigger-before-continuation;
- authoritative current-attack identity/dice cannot be represented without a
  broader ownership decision;
- compatibility behavior cannot be resolved through existing version owners;
- H9 requires architecture not present in the accepted documents;
- a provider, second registry, strategy layer, plugin, or generic engine
  appears necessary;
- Tarkin or ECM behavior must be migrated to make the H9 checkpoint pass;
- any shared or H9 TEST-003 category lacks executable evidence.

Do not bypass a stop condition with UI state, projection payloads, local
callbacks, synthetic commands, or test-only production branches.

## 19. Full-Tranche Binary Acceptance Criteria

The TWI-002 implementation is ready for Project Owner implementation review
only when every statement below is true.

### 19.1 Shared Core

- [ ] Slices 2-7 each passed their checkpoint before later work began.
- [ ] One immutable shared `ATTACK_MODIFY` definition exists.
- [ ] One orchestrator owns lifecycle and continuation decisions.
- [ ] One existing RuleRegistry owns candidate indexing only.
- [ ] Opportunities are canonical, derived, and never serialized.
- [ ] Duplicate candidates suppress and duplicate opportunities fail closed.
- [ ] One controller exists and optional ordering remains player-selected.
- [ ] Every optional blocker has replayable use and decline.
- [ ] Every timing command validates lifecycle identity.
- [ ] Rule commands never complete a window.
- [ ] Exactly one continuation follows final re-derivation.
- [ ] Continuation failure preserves lifecycle and owned state.
- [ ] UI, modal routing, GameManager, and CommandProcessor are non-owners.
- [ ] Save/load, replay, reconnect, networking, visibility, and cleanup shared
      suites pass.

### 19.2 H9 Pilot

- [ ] H9 uses the shared definition, registry, orchestrator, opportunity,
      command, projection, and evidence path.
- [ ] H9 source identity uses `runtime_upgrade_id` on the attacking ship.
- [ ] Current attack identity and dice used by commands are authoritative and
      serialized independently of projection.
- [ ] H9 use/decline guard exists only in runtime upgrade `rule_state`.
- [ ] H9 use and decline reject every CAP-defined stale/illegal/repeat case.
- [ ] H9 use mutates one legal die and decline mutates no die.
- [ ] Multiple H9 sources remain independent.
- [ ] H9 plus a second opportunity proves both player orders and re-derivation.
- [ ] Downstream Accuracy and defense-token behavior uses the authoritative
      changed dice.
- [ ] Every H9 cleanup trigger has one explicit command owner.
- [ ] Hot-seat, replay, host, client, reconnect, save/load, projection, and
      visibility evidence passes.
- [ ] Existing Swarm and attack behavior remains passing.

### 19.3 Scope And Authority

- [ ] Tarkin and ECM production behavior is unchanged.
- [ ] No CAP or architecture document was modified by implementation work.
- [ ] CAP-H9 remains Draft/NOT_INTEGRATED until separate evidence alignment and
      Project Owner approval.
- [ ] No new architecture layer was introduced.
- [ ] Full repository verification and diff checks pass.

## 20. Non-Goals And Deferred Work

The following remain outside TWI-002 even if implementation discovers nearby
cleanup opportunities:

- Tarkin timing-window migration and CAP update;
- ECM attack-time or Status Phase migration and CAP update;
- Swarm conversion into a production timing-window participant;
- final CAP evidence alignment for H9, Tarkin, or ECM;
- marking any CAP Integrated;
- generalized attack-state architecture beyond the minimum authoritative
  identity/dice needed by H9;
- generic participant provider contracts;
- reusable effect-composition abstractions;
- nested or simultaneous timing windows;
- priority passes or alternating priority;
- network transport redesign;
- save/replay version subsystem redesign;
- fixture updates before accepted implementation evidence;
- final cross-consumer TEST-003 acceptance.

## 21. Open Owner Questions

No unresolved architecture decision was found.

The concrete choices remaining are implementation decisions constrained by the
accepted architecture:

- exact GDScript file and method names;
- whether the canonical opportunity validator is colocated with the
  orchestrator or in one adjacent shared helper;
- the narrow invocation signature used by the existing command submitter path;
- the minimum serialization shape by which existing `AttackState` identity and
  dice become authoritative without scene references;
- exact test file organization.

If the authoritative attack-state checkpoint cannot be completed within those
constraints, it becomes a reported dependency and potential Owner question. It
must not be answered by making `InteractionFlow.payload` authoritative.

## 22. Implementation Readiness Assessment

TWI-002 is ready for targeted architecture review as a Draft implementation
workbook.

The architecture is sufficient to plan Slices 2-8 because:

- all shared owners are fixed;
- static policy ownership is fixed;
- the command and continuation protocol is fixed;
- discovery and opportunity identity are fixed;
- cleanup, replay, save/load, reconnect, network, projection, and evidence
  boundaries are fixed;
- H9 rule behavior and runtime-upgrade ownership are fixed;
- repository seams exist for definitions, registry registration, command
  processing, projection, filtering, replay, networking, and attack flow.

The principal implementation dependency is the current attack-state gap:
scene-owned `AttackState` and derived `InteractionFlow.payload` do not yet
provide the authoritative serialized dice boundary required by H9. This
workbook treats that as a required Slice 8 checkpoint under the already
accepted CAP-H9 attack-state owner. It is not permission to broaden the tranche
into an attack rewrite.

After Owner acceptance, implementation should proceed slice by slice and stop
at the first failed checkpoint. No later migration should begin until H9 and
the shared TEST-003 evidence have passed.

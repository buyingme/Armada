# TWI-002: Timing Window Core And H9 Pilot Implementation Workbook

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-07-18

Purpose: Implementation Workbook
Tranche: MA-TW-001 Slices 2-8
Predecessor: TWI-001 -- Authoritative TimingWindowState (completed)
Authority:
- ADR-001
- ADR-005
- CON-001
- CON-005
- TEST-003

This workbook prepares one implementation task made of seven ordered slices,
with separate shared-core and Model C-S/H9 stop/go gates. It is not an ADR, a
Contract, a TEST document, an implementation authorization, or a replacement
for CAP-H9-001.

## 1. Purpose

TWI-002 translates the accepted timing-window architecture into a
repository-grounded implementation plan for the shared timing-window core and
the first clean vertical consumer, H9 Turbolasers.

The workbook answers:

- how MA-TW-001 Slices 2-8 can be implemented without reopening Slice 1;
- how the accepted Model C-S current-attack migration gates production
  `ATTACK_MODIFY` and H9 activation without blocking behavior-inert shared core;
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

- ADR-001 is the architecture authority for canonical current-attack ownership
  and replayable-command ownership of semantic attack transitions.
- ADR-005 is the architecture authority for timing-window ownership,
  opportunity derivation, orchestration, and continuation.
- CON-001 is the implementation-contract authority for `CurrentAttackState`,
  semantic attack transactions, Model C-S migration, and their persistence,
  replay, reconnect, network, projection, and verification obligations.
- CON-005 is the implementation-contract authority for every shared and H9
  timing-window obligation in this tranche.
- TEST-003 is the verification authority.
- ADR-003 and CON-003 govern rule surfaces and CAP traceability.
- ADR-004 and CON-004 govern H9 runtime-upgrade identity and mutable
  `rule_state` ownership.
- TIM-001, TIM-002, and TIM-003 are historical decision evidence. They do not
  override the accepted ADRs or Contracts.
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
  file or function seam, ADR-001, ADR-005, CON-001, CON-005, TEST-003, and the
  applicable CAP remain authoritative.

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
  module;
- one canonical `GameState`-owned `CurrentAttackState`;
- replayable-command ownership of every semantic attack transition;
- one-way Model C-S compatibility from canonical current-attack state to
  non-authoritative scene, flow, and projection mirrors.

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

Slices 2-7 form one behavior-inert shared-core tranche. Slice 8 contains three
ordered checkpoints within the existing MA-TW-001 slice boundary:

- Slice 8A establishes the ADR-001/CON-001 Model C-S prerequisite for each
  individual attack, including the downstream Accuracy, defense, damage, and
  reconstruction interval consumed by H9 acceptance evidence.
- Slice 8B-1 migrates the existing ship-attacker Concentrate Fire token reroll
  into the shared protocol while production opening remains disabled.
- Slice 8B-2 implements H9 while automatic opening remains disabled, passes an
  Production Coexistence And H9 Pre-Activation Gate, and only then activates
  `ATTACK_MODIFY` for ship-attacker attacks.

These checkpoints do not add migration-assessment slices or change MA-TW-001.
They make the prerequisite and failure attribution explicit inside Slice 8.

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
- current-attack facts or semantic attack transitions outside one individual
  attack from accepted entry through Accuracy, defense, damage resolution, and
  terminal cleanup;
- migration of Swarm into the shared timing-window protocol;
- replacing existing Tarkin or ECM local lifecycle behavior;
- a generic rule engine, effect-composition engine, cleanup framework, or
  timing-window framework.

The production coexistence requirement for H9 is proven with the existing
Concentrate Fire token reroll represented as a shared optional blocker. Generic
invalidation cases that Concentrate Fire cannot express remain covered by the
deterministic shared test participant. Squadron-attacker attacks do not open the
shared `ATTACK_MODIFY` window in this tranche, so existing Swarm behavior remains
on its current procedural path and is a mandatory regression surface rather
than a second production migration.

## 5. Accepted Architecture Guards

The following guards apply to every slice and every checkpoint.

### 5.1 Authority Owners

| Concern | Sole authoritative owner |
| --- | --- |
| Current-attack-specific authoritative facts, including active attack identity and dice | `GameState`-owned `CurrentAttackState` under ADR-001 and CON-001 |
| Semantic attack entry, progression, rule-result, cancellation, replacement, and completion mutation | Replayable semantic attack commands as atomic transactions under CON-001 |
| Shared lifecycle identity, stage, status, controller, context | `GameState`-owned `TimingWindowState` |
| Immutable timing-window policy | Shared timing-window module static definition table |
| Lifecycle opening, re-derivation coordination, completion decision, continuation coordination, shared lifecycle cleanup | Timing Window Orchestrator |
| Candidate participant indexing | Existing `RuleRegistry`, as static index only |
| H9 current-attack use/decline guard | H9 runtime upgrade `rule_state` on the attacking `ShipInstance` |
| H9 legality and effect semantics | H9 rule implementation and replayable H9 commands, using authoritative state |
| H9 dice mutation | `UseH9Command` mutating canonical `CurrentAttackState` as one atomic transaction with the H9 runtime guard |
| H9 decline mutation | `DeclineH9Command` through H9 runtime upgrade `rule_state` |
| Attack Modify continuation mutation | Replayable `confirm_attack_dice` semantic attack transaction after it satisfies CON-001 and CON-005 |
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
- scene-owned `AttackState` and `AttackFlowFSM` mirrors;
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
- a general effect graph or generic priority engine;
- a second writable current-attack owner or reverse-write compatibility path.

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
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- `docs/architecture/decision_workbooks/TIM-001-timing-window-ownership-and-continuation-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-timing-window-implementation-obligations-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-owner-decisions.md`
- `docs/architecture/decision_workbooks/TIM-003-authoritative-attack-state-and-transition-ownership.md`
- `docs/architecture/decision_workbooks/TIM-003-owner-decisions.md`
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
- `GameCommand.serialize()` already carries the assigned command sequence;
  `CommandProcessor._next_sequence` is the existing live sequence allocator.
  Current mirror application routes through `_execute_and_record()` and
  overwrites the received server sequence, save/load resets that allocator, and
  reconnect ordering currently initializes from local history size. Those
  existing seams require the one preservation rule in Section 10.4.1 before a
  command-sequence-derived lifecycle identity can be used across reconstruction.
- `CommandProcessor._submit()` already has one successful authoritative-command
  boundary: execute and record, collect follow-ups, emit the triggering result,
  then drain follow-ups. `submit_deferred_followups()` plus the host/server
  submitters preserves broadcast-before-follow-up ordering. This is the single
  repository seam used by this workbook for orchestrator-produced continuation.
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
- `DiceFace.ACCURACY` is the one semantic Accuracy result for both red and blue
  dice, even where the physical die data contains that result more than once.
- `ATTACK / ATTACK_MODIFY` already exists in `FlowSpec`, with attacker control
  and `confirm_attack_dice` as an allowed marker command.
- `confirm_attack_dice` is currently submitted from UI/GameManager and its
  `execute()` does not perform the authoritative continuation mutation. The
  attack scene reacts after command execution. This is migration evidence, not
  the accepted CON-005 endpoint.
- current `AttackState` holds attack identity and dice in scene-owned,
  non-serialized state. `InteractionFlow.payload` mirrors dice and identity for
  projection. Under accepted ADR-001 and CON-001, both are legacy
  non-authoritative surfaces that must become one-way consumers of canonical
  `GameState.current_attack_state` during the Slice 8A checkpoint.
- `RerollAttackDieCommand` currently updates `InteractionFlow.payload`; this is
  useful command-shape evidence but not authority precedent for H9.
- `AttackExecutor._apply_dice_roll_result()` currently offers the Concentrate
  Fire token reroll before `_try_offer_swarm_reroll()` and then confirms. The
  former is the ship-attacker production blocker; the latter applies to the
  squadron-attacker path.
- `_attack_exec_finalize_attack()` advances a ship to its next attack and
  `_finalize_squadron_attack()` advances anti-squadron target iteration before
  enclosing `_finish_attack_execution()` runs. Individual attack retirement
  must therefore occur at the two finalize seams, not only at enclosing
  teardown.
- scene `AttackState` currently carries Accuracy locks, defense-token queues,
  Evade/Redirect progress, and damage-effect flags needed after H9. These are
  migration evidence for the Section 15.3 CON-001 membership classification,
  not permission to copy the scene object wholesale.
- current Swarm projection uses local payload flags and a rule-specific panel
  section. It must not be copied into H9.
- `GameReplay` currently emits unsigned format `1`, signed format `2`, and has
  no pre-application format rejection in `deserialize()` / `ReplayDriver`.

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
timing-window or current-attack ownership model. ADR-001 and CON-001 resolve
the former ownership gap: `GameState` owns canonical `CurrentAttackState`, and
replayable commands own semantic attack transitions.

### 7.2 Required End State

After Slice 8:

1. `GameState` owns the sole canonical JSON-safe `CurrentAttackState` for the
   attack facts exercised by the production path, and every semantic write to
   those facts occurs through a replayable command.
2. Scene attack state, `InteractionFlow`, and projection are one-way derived
   mirrors with no reverse write or command-authority path.
3. `ATTACK_MODIFY` has one immutable static definition in the shared
   timing-window module.
4. The orchestrator opens and owns the active lifecycle using
   `GameState.timing_window_state`.
5. The orchestrator discovers candidates only through `RuleRegistry`.
6. H9 derives canonical opportunities from authoritative attack and runtime
   upgrade state.
7. H9 use and decline are explicit replayable commands with lifecycle identity.
8. The H9 runtime upgrade owns the current-attack resolved guard.
9. Opportunities are re-derived after each accepted relevant command.
10. The attacker selects among all currently available optional opportunities.
11. `confirm_attack_dice` is derived and submitted exactly once only after no
   blocking opportunities remain.
12. The continuation command performs its authoritative semantic attack
    transition and normal
    validation; presentation reacts afterward.
13. Projection and live routing consume derived opportunities without
    authorizing them.
14. Save/load, replay, reconnect, host/client mirroring, visibility, cleanup,
    and failure behavior satisfy TEST-003.
15. Tarkin and ECM behavior is unchanged and remains transitional.

## 8. Dependency Order And Execution Rule

The implementation dependency is strict, with one behavior-inert shared-core
tranche followed by three ordered checkpoints inside Slice 8:

```text
completed Slice 1 lifecycle state
  -> Slice 2 static ATTACK_MODIFY definition
  -> Slice 3 orchestrator lifecycle core
  -> Slice 4 RuleRegistry candidates and derived opportunities
  -> Slice 5 shared command protocol and deferred-continuation seam
  -> Slice 6 projection and live route
  -> Slice 7 shared persistence/replay/network/cleanup evidence
  -> Shared Core Gate
  -> Slice 8A per-individual-attack Model C-S migration through damage/terminal
  -> Model C-S Gate
  -> Slice 8B-1 Concentrate Fire shared-participant migration
  -> Concentrate Fire Readiness Gate
  -> Slice 8B-2 H9 commands/rule with production opening disabled
  -> Production Coexistence And H9 Pre-Activation Gate
  -> ship-attacker ATTACK_MODIFY production trigger and unique evidence
```

No later item begins until the preceding checkpoint passes. Slices 2-7 are the
largest safe multi-slice implementation tranche: they may be carried by one
implementation task because they use deterministic test fixtures and leave all
production attack behavior inactive. Their individual focused checkpoints and
the Shared Core Gate remain mandatory.

Slice 8A, Slice 8B-1, and Slice 8B-2 may be carried in the same later
implementation task, but no checkpoint's edits begin until the preceding gate
passes. This preserves failure attribution between current-attack migration,
production modifier coexistence, and H9/timing activation. Do not implement all
stages and then attempt first verification.

The implementation may combine two adjacent slices in one commit only when:

- the earlier slice cannot compile without the immediately following seam;
- its focused checkpoint still runs separately;
- the diff can still be reviewed against both binary acceptance sets;
- no production timing opening or H9 behavior is introduced before the shared
  path, Model C-S Gate, and Concentrate Fire Readiness Gate exist.

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

Create one static, non-instantiated module at:

- `src/core/timing_windows/timing_window_definitions.gd`

Use a constant Dictionary mapping.
Do not create definition instances, loaders, providers, services, or a new
registry.

The `ATTACK_MODIFY` entry contains only the CON-005 static policy equivalent to:

- timing-window identity: `attack_modify`;
- supported lifecycle stage: `attack_modify`;
- fixed-controller policy: `fixed_attacker`;
- RuleRegistry participant-index key: `attack_modify`;
- canonical continuation command type: `confirm_attack_dice`;
- normal completion only through successful `confirm_attack_dice`;
- cancellation through the authoritative attack cancellation/end command path,
  including `skip_attack` when it exits an active Attack Modify interval;
- production replacement prohibited for `ATTACK_MODIFY` in this tranche;
- close-and-open only after the prior interval has completed or cancelled,
  always with a fresh lifecycle identity.

Use stable string or enum-compatible values already used by serialization and
command registration. Do not copy dynamic `FlowSpec` payload, attacker
identity, dice, rule identities, visibility, legality, or command payloads into
the definition.

At production opening, populate the governed Slice 1 continuation context as:

- `continuation_id`: `confirm_attack_dice`;
- `resume_point`: `attack_after_modify`;
- `source_id`: the active `CurrentAttackState` lifecycle identity;
- `source_type`: `current_attack`;
- `owner_player`: the canonical attacking player.

No additional continuation-context key is introduced.

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

Add one narrow shared orchestrator at:

- `src/core/timing_windows/timing_window_orchestrator.gd`

Implement it as one stateless `RefCounted` core module whose semantic operations
act on the supplied authoritative `GameState`. Do not instantiate or serialize
an orchestrator object. Do not make it an autoload, scene node, generic service,
or dependency-injection target.

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

Use exactly one integration seam: `CommandProcessor._submit()` invokes the
orchestrator after the successful command has executed and been recorded and
after existing RuleRegistry observer follow-ups for that command have been
collected, but before `command_executed` is emitted. No submitter, GameManager,
UI, rule implementation, or command-reaction handler invokes lifecycle
completion separately.

At that seam:

1. `CommandProcessor` supplies the successful command, result, authoritative
   `GameState`, and explicit execution mode.
2. The orchestrator re-derives when the command affects the active lifecycle.
3. The orchestrator returns no follow-up or exactly one normal replayable
   continuation command. `CommandProcessor` does not inspect blockers or
   construct that command.
4. The returned continuation is appended after already-collected observer
   follow-ups in the existing `_observer_followups` FIFO.
5. Local authority emits the triggering result and then drains the FIFO.
   Network authority uses `submit_deferred_followups()`, broadcasts the
   triggering result, and then drains through the existing host/server
   follow-up submitter. This preserves one command order in both paths.
6. When no blockers remain, the orchestrator marks the lifecycle `closing` in
   every execution mode. Live authority then returns the continuation; mirror
   and replay modes record the same lifecycle state but return no command. A
   second successful evaluation cannot queue a duplicate for that lifecycle
   identity. This is lifecycle state, not a stored command or opportunity
   queue.
7. If the queued continuation rejects, the existing rejection boundary invokes
   the orchestrator once for that rejected lifecycle command. The orchestrator
   preserves that same active `closing` lifecycle and all rule-owned state,
   re-derives projection, surfaces the failure, and queues no automatic retry or
   fallback. This fail-closed state is identical across reconstructed mirrors
   because the rejected command performs no authoritative mutation.

Rule observer follow-ups may execute before the queued continuation because
they are earlier in the same FIFO. The continuation still validates against
the resulting authoritative state. If an earlier follow-up creates a blocker,
that follow-up's post-success re-derivation restores the lifecycle from
`closing` to `open`; the already-queued stale continuation then rejects without
mutation. It cannot overtake that follow-up or close the lifecycle from stale
derivation.

Execution modes must be explicit and deterministic:

| Mode | Orchestrator behavior |
| --- | --- |
| Hot-seat/live authority | Re-derive and return at most one continuation to the existing FIFO. |
| Network host authority | Re-derive and return at most one continuation; broadcast the trigger before draining the FIFO. |
| Network client mirror | Re-derive for local projection only; never synthesize commands. |
| Replay application | Re-derive and validate state; consume the recorded continuation command rather than synthesize a duplicate. |
| Save/load or reconnect reconstruction | Re-derive state/projection; do not synthesize a command merely because reconstruction occurred. |

Represent the mode with one small closed value passed at this seam. Do not
encode modes as strategy classes or infer authority from UI or projection.

#### 10.4.1 Authoritative Sequence Assignment And Restoration

Use the existing command sequence as the sole source for command-sequence-based
lifecycle identity. `CommandProcessor` remains the only live owner and allocator
of the next-command sequence cursor. `CurrentAttackState` and
`TimingWindowState` store their resulting lifecycle identities; they do not
allocate sequences or store a competing cursor.

Apply exactly these rules:

1. A new game initializes the `CommandProcessor` cursor to `0`. A live local or
   live network-authority submission arrives unassigned (`sequence == -1`).
   After all preflight, rule, concrete-command, and atomic-candidate validation
   succeeds, `CommandProcessor` assigns the current cursor for the one
   execute-and-record transaction. Successful execution records the command and
   advances the cursor once. Any rejection occurs before that transaction and
   leaves the command unassigned, the cursor unchanged, and no history gap. A
   live client request that claims a preassigned sequence is rejected rather
   than trusted.
2. A network mirror or replay-mode authority command arrives with its
   non-negative authoritative sequence already serialized. Mirror/replay
   application must preserve that value rather than overwrite it. The value must
   equal the local expected cursor before command validation or mutation; a
   negative value, duplicate, or gap fails closed. Successful mirror/replay
   execution records that preserved value and advances the local cursor once;
   rejection leaves the cursor and history unchanged. A network host in replay
   mode validates the submitted value against its own loaded replay cursor, so
   the client does not become sequence authority. The existing `GameManager`
   network-result buffer remains responsible for waiting on an out-of-order
   future sequence before this exact mirror check.
3. Every accepted save/checkpoint records the non-negative
   `next_command_sequence` in its signed `SaveGameMetadata` header. Load restores
   that cursor into `CommandProcessor` after state/header validation and before
   any command, projection, or live routing resumes. The header carries the
   allocator state; it does not become a gameplay-state or lifecycle owner.
4. A reconnect snapshot carries the same `next_command_sequence` beside the
   filtered canonical `GameState` snapshot. The server captures both after one
   completed authoritative command boundary and before any later result is
   released to that reconnecting client. The client installs the state,
   restores the `CommandProcessor` cursor, and sets
   `GameManager._next_network_result_sequence` to that identical value as one
   reconstruction step before accepting post-snapshot command results. Results
   below it are stale; results above it remain buffered; the equal result is the
   only next applicable result.
5. Slice 7 full-game replay initializes the cursor to `0` and requires every
   recorded command to carry the exact next contiguous sequence. Slice 8A replay
   format 3 additionally records `initial_command_sequence` in the signed or
   unsigned header. `ReplayDriver` restores that value before applying format-3
   commands; full-game capture writes `0`, while replay initialized from an
   accepted reconstructed state uses the cursor paired with that initial state.

The save/reconnect/replay cursor is synchronization metadata for the existing
`CommandProcessor` sequence owner. It is not a UUID, attack counter, timing
counter, second identity authority, service, or manager. Missing, non-integral,
negative, or cross-owner-inconsistent cursor data follows the deterministic
compatibility/failure rules in Sections 14.6 and 17; it is never inferred from
scene, projection, local history length, or UI state.

### 10.5 Lifecycle Semantics

The orchestrator must:

- reject unknown definition identities;
- enforce one active window;
- open with lifecycle identity `<timing-window identity>:<opening command
  sequence>` using the already-assigned authoritative command sequence;
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
- the single command-result and rejection integration seam in
  `CommandProcessor` described in Section 10.4;
- the existing `CommandProcessor` sequence path, split deterministically between
  live-authority allocation and preassigned mirror/replay application, with one
  read/restore boundary for the next cursor;
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
- continuation rejection preserves the active `closing` lifecycle, queues no
  retry, and re-derives projection;
- an earlier queued follow-up that creates a blocker restores `closing` to
  `open` before the stale continuation validates;
- observer follow-ups remain ahead of an orchestrator continuation in the
  existing FIFO;
- live authority assigns one sequence after validation, while mirror/replay
  preserves an exact preassigned sequence and rejects duplicate/gap values;
- rejected live, mirror, and replay submissions leave the expected cursor and
  history unchanged;
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
- source-owner kind;
- the registered rule implementation script that performs source enumeration
  and opportunity derivation;
- deterministic diagnostic identity.

The existing `RuleBootstrap` remains the single static registration root. Use
one narrow descriptor stored by the existing `RuleRegistry`, consistent with
current `FlowHook` registration. Do not add participant-kind switches, provider
objects, a second registry, or capability-local registration lists. The
descriptor must not store runtime sources, current players, opportunities,
legality, ordering, visibility, continuation, or mutation.

The index returns candidates in deterministic order. It suppresses duplicate
candidates for the same capability identity and authoritative source identity
before derivation when the same static path is registered more than once.
Because runtime source identity is not known from static registration alone,
the suppression boundary must combine the static candidate with sources found
from authoritative state during derivation; it must not guess or cache sources
inside RuleRegistry.

Invalid participant registration and invalid derivation must fail closed with
diagnostics, preserve authoritative state, present no ambiguous opportunity,
and prevent continuation for that evaluation pass.

### 11.4 Canonical Opportunity Shape

Use one derived plain Dictionary returned fresh on each derivation pass. Put
its construction, validation, and canonical-key functions in one adjacent
stateless helper:

- `src/core/timing_windows/timing_window_opportunity.gd`

Do not create persistent opportunity instances, UUIDs, provider objects, or a
second lifecycle owner.

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

Every participant uses that helper so future capabilities produce the same
shape. The helper validates derived data only; it is not a provider, strategy,
registry, or effect engine.

### 11.5 Derivation Protocol

Runtime-source enumeration has one boundary. For every RuleRegistry descriptor,
the orchestrator invokes the registered rule implementation's timing-window
source-enumeration operation with authoritative `GameState` and the active
`TimingWindowState`. That operation returns a fresh deterministically ordered
list containing only source-owner kind and stable authoritative runtime-source
identity. It does not return opportunities, cache eligibility, mutate state, or
consult projection. The same registered rule implementation then derives
opportunities for each returned source identity by resolving current data from
its accepted authoritative runtime owner.

For every pass:

1. read the active static definition;
2. query RuleRegistry by its participant key;
3. invoke each registered rule implementation once to enumerate its runtime
   source identities from authoritative state;
4. sort sources by source-owner kind and stable runtime-source identity, then
   suppress duplicate capability/source pairs;
5. invoke that same rule implementation to derive zero or more opportunities
   for each surviving source identity;
6. validate every opportunity shape and controller;
7. build canonical identity from capability, owner kind, runtime source, and
   semantic key;
8. fail closed if duplicate derived identities remain;
9. return a fresh deterministic presentation order without choosing for the
   player.

An absent runtime source produces no opportunity and is not itself a failure.
A participant derivation error is a failure and must not be treated as no
opportunities.

For H9, this boundary resolves the attacking ship from canonical
`CurrentAttackState`, enumerates only that ship's `runtime_upgrades` in
`runtime_upgrade_id` order, and returns every matching H9 runtime-upgrade
identity. It does not filter concrete activation or dice legality during source
enumeration; H9 derivation performs those rule-specific checks. It does not
scan scene nodes, `InteractionFlow.payload`, UI state, or every ship as a
substitute for the current-attacker reference.

### 11.6 Likely Change Surfaces

- `src/core/effects/rule_registry.gd`;
- `src/autoload/rule_bootstrap.gd` test setup only at this slice;
- orchestrator derivation path;
- `src/core/timing_windows/timing_window_opportunity.gd`;
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
- invalid participant descriptor or missing registered rule operation fails
  closed;
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
- a second registry, participant-kind switch, or provider abstraction is
  proposed.

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

### 12.5 Shared Continuation Integration

Slice 5 proves continuation with registered test commands and deterministic
test participants. It does not alter `publish_attack_flow`,
`confirm_attack_dice`, `skip_attack`, scene attack state, or production attack
progression. The shared fixture definition uses one registered test
continuation command that:

- carries and validates lifecycle identity;
- performs one observable authoritative fixture-state mutation;
- succeeds or rejects through normal applicability and command validation;
- is derived only by the orchestrator from static definition and current
  authoritative fixture state;
- is queued only through the Section 10.4 deferred-follow-up seam;
- clears shared lifecycle state only after successful mutation;
- leaves the lifecycle active and rule-owned fixture state unchanged when it
  rejects.

The production `ATTACK_MODIFY` mapping remains present but behavior-inert. Its
`confirm_attack_dice` continuation is not queued until Slice 8A has made that
command an authoritative CON-001 semantic attack transaction and Slice 8B-2 has
activated the production lifecycle after both gates.

### 12.6 Shared Opening And Cancellation Fixtures

Use registered replayable test commands to open and cancel a fixture timing
window through the normal command path. They must prove fresh lifecycle
identity, duplicate-opening rejection, explicit cancellation, replacement,
close-and-open, and no client/replay synthesis without changing production
attack behavior.

Production semantic attack entry, `ATTACK_MODIFY` opening, confirmation,
cancellation, and replacement remain gated behind Slice 8A. No scene FSM or
`InteractionFlow.payload` mutation is used as test authority.

### 12.7 Likely Change Surfaces

- `CommandProcessor` registration/integration tests;
- `FlowSpec`;
- `CommandApplicability`;
- the Section 10.4 `CommandProcessor` seam;
- existing local/host/client submitter and network ordering tests without
  changing submitter ownership;
- shared protocol command fixtures/tests.

Do not edit production attack commands or add H9 commands in Slice 5.

### 12.8 Safe Intermediate State

After Slice 5, a test participant can open a fixture lifecycle, resolve or
decline through commands, re-derive, and continue exactly once through the
normal command stream. Production `ATTACK_MODIFY` remains inactive, H9 remains
absent, and existing attack behavior is unchanged.

### 12.9 Checkpoint

Focused tests prove:

- fixture opening command creates one lifecycle in hot-seat authority mode;
- duplicate/open-stale commands fail deterministically;
- use and decline serialize/deserialize and enter command history;
- wrong player, wrong flow, wrong window, stale lifecycle, missing source,
  repeated use, and repeated decline reject consistently at applicability and
  concrete validation boundaries;
- one selected opportunity resolves per command;
- the orchestrator re-derives after success;
- remaining blockers prevent the fixture continuation;
- no blockers produce one queued fixture continuation behind the resolving
  command and all earlier RuleRegistry observer follow-ups;
- continuation executes through normal validation;
- continuation failure preserves lifecycle and rule state;
- fixture cancellation is command-owned and cleans shared lifecycle only after
  its authoritative mutation succeeds;
- replay uses the recorded continuation and does not create a duplicate;
- clients never synthesize continuation;
- presentation reactions cannot bypass the command path.

Proceed only when command history order is stable and no UI is needed to prove
the full protocol.

Stop when:

- hot-seat and network fixture sequences differ semantically;
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
- [ ] Production attack commands and behavior remain unchanged.

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
  `GameManager.get_command_submitter()`;
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
| Save/load | `GameState.serialize()` + `SaveGameManager` tests | active and post-window reconstruction plus command-sequence cursor restoration |
| Replay | `GameReplay`, `ReplayDriver`, command history tests | preserved contiguous recorded sequence, no stored opportunities, no duplicate continuation |
| Reconnect | serialize -> `StateFilter` -> deserialize -> cursor restore -> `UIProjector` | lifecycle, rule state, sequence cursor, visibility, derived projection |
| Network | submitter/NetworkManager/GameManager ordering harness | host assignment, preserved mirror sequence, no client synthesis, no overtaking |
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
- An older command or lifecycle payload that lacks authoritative identity
  required for safe validation is unsupported. Section 17.2 defines the exact
  new replay-format rejection required by the Model C-S attack-history change;
  do not assume a pre-existing replay version check or reconstruct identity from
  projection, scene state, or `InteractionFlow`.

### 14.5 Replay

Replay evidence must prove:

- shared full-game replay initializes the expected command cursor to `0` and
  preserves every recorded command sequence; Section 17.2 format 3 adds the
  explicit `initial_command_sequence` needed for reconstructed initial state;
- a missing, negative, duplicate, or gapped sequence fails before command
  mutation;
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
- new saves/checkpoints round-trip the signed `next_command_sequence` and restore
  it before any resumed command;
- old saves without that cursor select only the Section 17.1 compatibility
  outcome;
- reconnect restores `CommandProcessor` and network-result ordering to the same
  server cursor before post-snapshot command application;
- viewer-specific projection after filtered reconnect;
- no resurrection of stale opportunities outside the window.

For reconstruction, use one recovery outcome. Structurally valid serialized
owners that are semantically inconsistent with one another are invalid
`GameState`; `GameState.deserialize()` fails and `SaveGameManager` surfaces
`schema_invalid`. Reconnect and replay initialization fail closed through their
existing invalid-state paths. Reconstruction never clears one owner to make an
inconsistent state appear valid, never synthesizes cleanup or continuation,
and never repairs from projection or scene mirrors.

Cursor reconstruction uses the same fail-closed posture. A present cursor that
is non-integral, negative, or inconsistent with a serialized active lifecycle
rejects through the surrounding save/reconnect/replay invalid-state path. It is
not repaired from command-history length. The only missing-cursor compatibility
case is the older-save case fixed in Section 17.1.

### 14.7 Networking

Use the existing host/client command stream:

- host validates and executes;
- live client requests carry `sequence == -1`; a client-supplied preassigned
  value is rejected unless the host is explicitly applying the same loaded
  replay and the value equals its replay cursor;
- triggering opportunity command broadcasts before continuation;
- client buffers/applies results in sequence;
- the server-assigned sequence survives command serialization and mirror
  application unchanged, and the mirror `CommandProcessor` advances from that
  same value rather than allocating a replacement;
- `GameManager` advances `_next_network_result_sequence` and invokes remote
  effects only after `submit_mirror()` successfully applies that exact sequence;
  failed mirror application leaves both cursors unchanged and stops result
  processing rather than skipping the authoritative sequence;
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

Live commands prevent stale cross-owner state by validating and applying every
terminal, cancellation, replacement, and cleanup mutation atomically through
the accepted replayable command owner. If live evaluation nevertheless detects
an inconsistent active lifecycle, it preserves all authoritative owners,
surfaces the diagnostic, presents no opportunities, and submits no
continuation. It does not guess which owner to clear.

Failed commands must not clear unresolved guard state. Authoritative cleanup
must occur before projection cleanup.

### 14.9 Likely Change Surfaces

- shared timing-window unit/integration tests;
- existing save/load, replay, reconnect, network ordering, StateFilter, and
  UIProjector test files where their ownership boundary is already tested;
- `SaveGameMetadata`, `SaveGameManager`, `GameManager` state installation and
  network-result ordering, and `GameReplay` / `ReplayDriver` only for the cursor
  carriers and restoration rules in Sections 10.4.1 and 17;
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
- host/client preserve the same assigned sequence and final state;
- rejected live or mirrored commands create no cursor advance or history gap;
- save/load, replay, and reconnect restore the expected sequence cursor and the
  same lifecycle/projection before later commands apply;
- cleanup/failure matrix passes;
- inconsistent serialized cross-owner state rejects through the existing
  invalid-state path without repair or synthesized cleanup;
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

Complete three ordered checkpoints inside Slice 8:

1. Slice 8A migrates each individual attack, from accepted entry through
   terminal damage resolution, to ADR-001 and CON-001 Model C-S.
2. Slice 8B-1 represents the existing ship-attacker Concentrate Fire token
   reroll in the shared protocol while production opening remains disabled.
3. Slice 8B-2 implements H9 through the shared path while production opening
   remains disabled, proves H9 and existing-modifier coexistence, and only then
   activates `ATTACK_MODIFY` for ship-attacker attacks.

### 15.2 Prerequisites

- all shared checkpoints pass;
- H9 catalog data remains `NOT_INTEGRATED` until evidence and Owner approval;
- no H9-specific lifecycle, continuation, projection, or registry path exists;
- ADR-001 and CON-001 are consumed as fixed authority; no ownership or semantic
  transition decision remains open.

### 15.3 Slice 8A -- Model C-S Current-Attack Prerequisite

Add one canonical JSON-safe `CurrentAttackState` boundary owned and serialized
by `GameState`. The boundary covers one individual attack, not a ship's complete
two-attack activation or an anti-squadron target loop.

#### 15.3.1 Individual-Attack Lifecycle

Use exactly this lifecycle:

1. After one target, attack zone, and attack context have passed existing
   legality checks, but before any attack-local dice-pool or rule mutation,
   submit `BeginAttackCommand`.
2. Successful entry creates one complete active `CurrentAttackState`. Its unique
   identity is `attack:<BeginAttackCommand.sequence>`. The command rejects while
   another current attack is active.
3. The identity remains unchanged through pre-roll choices, roll, Attack Modify,
   Accuracy, defense-token resolution, and damage resolution for that target.
4. After the target's damage/no-damage semantic resolution succeeds, submit
   `CompleteAttackCommand` before `_attack_exec_finalize_attack()` or
   `_finalize_squadron_attack()` selects another attack or target. Successful
   completion performs terminal cleanup and retires the state atomically.
5. Only after retirement may the next target or attack submit a new
   `BeginAttackCommand`, whose command sequence necessarily creates a different
   identity.

The sequence in step 2 is the authoritative sequence assigned or preserved by
Section 10.4.1. Local and network-host execution allocate it once; mirror and
replay execution consume the same serialized value; save/load and reconnect
restore the next cursor before another begin can execute. Consequently the same
accepted begin produces the same attack identity in every execution mode, and
the allocator cannot roll back and reuse an earlier post-migration identity.

For a ship's first and second attacks, the first attack completes before
`_attack_exec_prepare_next_attack()` routes the second; the second then begins
with a fresh identity. For ship anti-squadron fire, every squadron target in the
iteration has its own begin/complete pair and identity. The anti-squadron loop
never reuses one `CurrentAttackState` across targets.

`SkipAttackCommand` terminates an active individual attack for the explicit
reason `cancelled`, `flow_replaced`, or `flow_terminated`. It atomically cancels
the matching timing lifecycle, clears matching per-attack rule guards, and
retires `CurrentAttackState`. Direct active-state replacement is prohibited:
the replacement route first submits `SkipAttackCommand` with
`flow_replaced`, and only a successful result permits a fresh
`BeginAttackCommand`. A rejected cancellation leaves the old attack intact and
prevents replacement. This is a cancellation caused by flow replacement,
followed by a separate entry; it is not a CON-001 atomic active-attack
replacement transaction. An enclosing skip when no current attack is active
must not synthesize attack lifecycle or guard cleanup.

Save/load, replay, reconnect, and host/client reconstruction preserve the same
active identity and semantic stage; they do not submit a new begin or completion
command. Cross-owner state that cannot represent one consistent active attack
rejects through the invalid-state path. `_finish_attack_execution()` remains
enclosing scene teardown only and must assert that no current attack, timing
lifecycle, or matching per-attack guard remains. It does not retire an
individual attack.

#### 15.3.2 Authoritative Membership Boundary

Migrate the following current-attack facts because they are required to
validate, continue, serialize, or reconstruct the H9 acceptance interval:

- lifecycle identity and semantic stage;
- attacker and defender player identities, entity kinds, stable `GameState`
  entity references, and applicable hull zones;
- attack kind, range band, and committed obstruction outcome;
- the ordered attack dice pool before roll and the ordered current dice after
  roll, as canonical color/face records;
- the per-attack Concentrate Fire dial resolution and token-reroll resolution
  needed to prevent duplicate offer or use;
- committed Accuracy lock targets and whether Accuracy selection is complete;
- defense resolution stage, ordered committed defense-token references, and an
  ordered resolved-effect record containing each stable token reference and
  token type already applied;
- a pending Evade selected-die index plus expected source color/face, and
  ordered committed Redirect allocations by authoritative hull-zone reference;
- damage-resolution stage. Scatter, Brace, and Contain effects are derived from
  the resolved token-effect records; the calculated damage total is re-derived
  from canonical dice and those records rather than stored as a second fact.

Actual defense-token state, shields, hull damage, damage decks, command tokens,
and ship identity remain on their existing authoritative `GameState` owners and
are referenced rather than duplicated. Calculated damage totals, available
choices, legal ranges, projections, and display values are re-derived.
H9 and other capability-specific use/decline guards remain on their ADR-004
runtime owners and include the matching current-attack identity.

Do not copy the legacy scene `AttackState` wholesale. Exclude activation-level
iteration bookkeeping, display names, scene tokens, nodes, callables,
modal/animation state, timing opportunities, projection/UI payloads, and
rule-specific mutable state. `AttackState`, `AttackFlowFSM`, and
`InteractionFlow` are one-way consumers for every migrated fact.

#### 15.3.3 Semantic Command Boundary

Use these replayable atomic transactions:

1. `BeginAttackCommand` creates the complete individual-attack state described
   above.
2. Explicit Concentrate Fire dial use/decline commands record the pre-roll
   decision and canonical dice-pool change; scene callbacks no longer own that
   choice.
3. `RollDiceCommand` validates attack identity, stores its deterministic result,
   and progresses canonical stage to `ATTACK_MODIFY`.
4. Every dice-changing command, including the legacy Swarm
   `RerollAttackDieCommand`, reads and writes canonical current dice. Swarm
   routing remains procedural in this tranche, but it cannot retain a second
   writable dice owner.
5. `ConfirmAttackDiceCommand` always validates current-attack identity. For a
   ship attacker it additionally requires the matching active timing lifecycle
   and is the sole normal CON-005 continuation. For a squadron attacker in this
   tranche it requires `TimingWindowState` to be inactive and remains the
   existing post-Swarm semantic confirmation command. These cases are selected
   only from canonical attacker kind; callers cannot choose the mode.
6. Add one replayable Accuracy-lock commit command. Migrate
   `CommitDefenseCommand`, `SpendDefenseTokenCommand`,
   `SelectEvadeDieCommand`, `SelectRedirectZoneCommand`,
   `RedirectDoneCommand`, and `ResolveDamageCommand` so each validates the
   current-attack identity and atomically writes its semantic result to
   `CurrentAttackState` and any existing authoritative target owner it changes.
   Scene reactions occur only after success.
7. `CompleteAttackCommand` performs per-target terminal cleanup and retirement
   at the Section 15.3.1 seam. `SkipAttackCommand` owns cancellation,
   flow-replacement, and flow-termination retirement.
8. Remove `PublishAttackFlowCommand` from new semantic attack progression.
   Neither scene-mutates-first snapshots nor `InteractionFlow.payload` may
   reconstruct or authorize current-attack facts.

Each command is one semantic transaction, not one command per internal FSM
edge. Existing deterministic calculators may be called by a command, but their
results become authoritative only through the command.

### 15.4 Slice 8A Model C-S Gate

Slice 8B does not begin until focused evidence proves:

- canonical `CurrentAttackState` is the only writable owner of every migrated
  fact and validates before installation or mutation;
- first attack, second attack, and every anti-squadron target receive distinct
  begin/complete command pairs and lifecycle identities;
- local, network-host, mirror, and replay application produce the same attack
  identity from the same preserved `BeginAttackCommand.sequence`, while
  save/load and reconnect restore the next cursor before later attack entry;
- current-attack lifecycle identity is stable and serialized within one attack,
  rejects stale commands, and is retired before the next attack begins;
- entry, pre-roll choices, dice roll/mutation, Attack Modify confirmation,
  Accuracy locks, defense progression, damage resolution, cancellation,
  replacement/termination cleanup, and completion execute as replayable atomic
  semantic commands;
- hot-seat, host, client mirror, replay, save/load, and reconnect use the same
  semantic command order and canonical state;
- scene `AttackState`, `AttackFlowFSM`, `InteractionFlow`, projection, and UI
  cannot write migrated facts back or authorize commands;
- command failure leaves every touched authoritative owner unchanged;
- canonical state round-trips with no scene references and host/client state
  hashes agree;
- replay format 3 is emitted for signed and unsigned new histories and every
  other format rejects in `GameReplay.deserialize()` before command
  deserialization/application;
- save/load and reconnect resume before/after Attack Modify confirmation,
  during Accuracy, and during defense from canonical state without scene
  reconstruction authority;
- existing non-H9 attack, Swarm, Accuracy, defense-token, and damage paths pass
  while consuming canonical migrated facts.

Stop at this gate if any migrated fact has two writable owners, a semantic
transition remains scene-owned, an old snapshot is needed for command
authorization, or complete atomic failure cannot be proven. Those are CON-001
implementation failures, not choices to defer into H9. The gate also stops if
one identity spans two ship attacks or anti-squadron targets, or if downstream
Accuracy/defense legality still depends on writable scene-only state.

### 15.5 Slice 8B -- Production Coexistence And H9 Activation

#### 15.5.1 Existing Production Choice Inventory

Repository evidence identifies these existing choices around the roll/confirm
boundary:

- the Concentrate Fire dial adds a die before `RollDiceCommand`; Slice 8A moves
  that decision to canonical semantic commands, but it is not an Attack Modify
  participant;
- the Concentrate Fire token offers one reroll after roll and before confirm for
  a ship attacker;
- Swarm offers one reroll after roll and before confirm for a squadron attacker.

The implementation must reconfirm this inventory against the production route
and focused attack tests before activation. Discovery of another legal
post-roll/pre-confirm blocker stops Slice 8B-2 until that blocker has one
explicit coexistence outcome in this workbook's accepted scope.

#### 15.5.2 Slice 8B-1 -- Concentrate Fire Shared Participant

While automatic production opening remains disabled, add one direct
RuleRegistry participant for the ship-attacker Concentrate Fire token reroll.
Its runtime source is the canonical attacking `ShipInstance` plus that ship's
Concentrate Fire token. It derives at most one optional blocking opportunity
with the stable semantic key `concentrate_fire_token_reroll`.

Use one explicit `UseConcentrateFireTokenRerollCommand` and one explicit
`DeclineConcentrateFireTokenRerollCommand`. Both carry acting player, timing
lifecycle identity, current-attack identity, attacking-ship identity, and the
semantic key. Use additionally carries selected die index plus expected source
color and face. After complete validation, use atomically spends one token from
the existing ship owner, obtains the reroll through authoritative `GameState`
RNG, writes canonical current dice, and records the current-attack token result
as used. Decline changes no die or ship token and records the result as declined.
Any rejection mutates no owner. No prior scene mutation or separate
`SpendTokenCommand` is part of this decision.

The participant becomes unavailable after either result and the orchestrator
re-derives all participants. It uses the same projection, ordering, replay,
network, and continuation path as H9. It is a concrete repository rule
implementation registered through existing `RuleBootstrap` / `RuleRegistry`,
not a provider, service, second registry, or generic modifier framework.

#### 15.5.3 Concentrate Fire Readiness Gate

Slice 8B-2 does not begin until focused evidence proves:

- the Concentrate Fire token opportunity is present exactly when the existing
  ship-attacker choice is legal;
- use spends exactly one token and rerolls exactly the selected canonical die;
- decline preserves dice/token state and suppresses re-offer for that attack;
- no automatic confirm occurs while the Concentrate Fire blocker remains;
- a ship anti-squadron attack receives the same Concentrate Fire participant;
- a squadron-attacker roll does not open the shared window, and existing Swarm
  use/skip behavior and command traces remain passing while reading/writing
  canonical dice;
- the Section 15.5.1 inventory contains no unrepresented production blocker.

#### 15.5.4 Slice 8B-2 -- H9 Pre-Activation And Production Opening

After the Concentrate Fire Readiness Gate, add the H9 rule and commands under the
existing upgrade rule hierarchy and register them through `RuleBootstrap` /
`RuleRegistry`, but keep the successful `RollDiceCommand` production-opening
hook disabled. Exercise H9 with the shared test opening seam against canonical
individual-attack state.

Do not connect the production opening hook until focused evidence proves:

- H9 source/opportunity identity, use, decline, expected-source stale rejection,
  same-color target validation, atomic dice/guard mutation, and confirm cleanup;
- H9 plus Concentrate Fire in both orders with no blocker bypass;
- ship anti-squadron eligibility and per-target identity/guard reset;
- cancellation, flow-replacement, and flow-termination cleanup;
- save/load/replay/reconnect/network determinism before and after H9 and through
  downstream Accuracy/defense progression;
- no squadron-attacker timing opening and passing Swarm regression evidence.

This is the Production Coexistence And H9 Pre-Activation Gate. After it passes,
connect the single
Section 10.4 post-success hook: successful `RollDiceCommand` progression opens
the production shared window only when canonical attacker kind is ship. This
includes ship anti-ship and ship anti-squadron attacks; it excludes
squadron-attacker attacks, whose Swarm route remains procedural in this
tranche. The hook opens one fresh timing lifecycle from canonical current-attack
identity and derives attacker control from the static definition. Scene flow
publication does not open or reopen the window.

`ConfirmAttackDiceCommand` is the sole normal shared continuation. The
orchestrator queues it through the existing deferred FIFO only after
re-derivation finds no blocking opportunities. Successful confirmation
progresses canonical attack stage, clears matching rule guards, and closes
shared lifecycle state; rejection preserves the same active `closing` lifecycle
as defined in Section 10.4. `SkipAttackCommand` is the explicit
cancellation/flow-replacement/flow-termination path. `CompleteAttackCommand`
owns per-individual-attack terminal mutation under CON-001 and CON-005.

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

### 15.6 H9 Opportunity Derivation

For each attacking ship H9 runtime upgrade instance, derive from authoritative
state:

- capability identity for H9;
- source-owner kind: runtime ship upgrade;
- `runtime_upgrade_id`;
- stable semantic opportunity key: `change_die_to_accuracy`;
- controller: attacking player;
- resolution kind: optional;
- blocking: true while unresolved;
- `UseH9Command` intent;
- `DeclineH9Command` intent.

The H9 runtime guard has one deterministic semantic shape:
`current_attack_id` plus resolution `used` or `declined`. A guard matches only
that individual attack and exists only until the matching Attack Modify interval
successfully confirms or terminates abnormally. It cannot suppress H9 for a
later attack identity.

No opportunity is produced when:

- no H9 runtime source exists;
- source is inactive, discarded, disabled, or stale;
- canonical current-attack stage and active timing lifecycle do not both match
  `ATTACK_MODIFY`;
- attacker does not own the source;
- no die contains Hit or Critical and has a legal same-color Accuracy target;
- this source is already used or declined for this attack;
- lifecycle identity or attack identity is stale.

Multiple runtime H9 sources remain independent because identity includes each
`runtime_upgrade_id`.

### 15.7 UseH9Command

The use command must:

- be registered with `GameCommand` / `CommandProcessor`;
- be allowed only in `ATTACK / ATTACK_MODIFY` and the matching active timing
  lifecycle;
- carry acting player, lifecycle identity, current attack identity,
  `runtime_upgrade_id`, semantic opportunity key, selected die index, expected
  source color, expected source face, and target semantic face
  `DiceFace.ACCURACY`;
- validate that the canonical ordered die at that index still exactly matches
  both expected values before evaluating H9 legality;
- reject without mutation when the index is absent or the selected die's color
  or face changed after intent projection or another modifier;
- reject wrong player/source/window/attack, repeated use/decline, illegal
  source face, target face other than `DiceFace.ACCURACY`, source color without
  an Accuracy face, and black dice;
- change exactly one eligible red or blue die to the canonical
  `DiceFace.ACCURACY` semantic result;
- write `{current_attack_id, resolution: used}` to that H9 runtime upgrade
  `rule_state`;
- commit the canonical die mutation and runtime-upgrade guard as one atomic
  semantic transaction after all validation succeeds; any failure mutates
  neither owner;
- record normal command history;
- leave lifecycle completion to the orchestrator.

The command does not exhaust H9 or alter durable card state.

The command identifies the target with the one semantic
`DiceFace.ACCURACY` value; it does not carry a physical face index. The
validated expected source color must support that result. This satisfies the
CAP target-face obligation without introducing payload aliases for duplicate
physical Accuracy faces. The expected source color/face pair is a command
precondition, not a dice revision framework. It serializes in the normal command
payload and is checked identically on host, client mirror, and replay, so the
same stale command has the same rejection outcome in every execution mode.

### 15.8 DeclineH9Command

The decline command must:

- carry the same authoritative lifecycle/source/attack identity boundary;
- revalidate current availability and controller;
- leave dice unchanged;
- write `{current_attack_id, resolution: declined}` to the H9 runtime upgrade
  `rule_state`;
- reject repeated decline, use-after-decline, decline-after-use, and stale
  lifecycle/source/attack identity;
- record an explicit command-history entry;
- leave lifecycle completion to the orchestrator.

### 15.9 Re-Derivation And Player Ordering

After each H9 use or decline:

- the orchestrator re-derives all Attack Modify participants;
- no cached H9 availability is trusted;
- all remaining blockers are projected together;
- the attacker chooses the next opportunity;
- `confirm_attack_dice` remains unavailable to the UI as a completion choice;
- the orchestrator submits it only after no blocker remains.

Production coexistence must be proven with the Concentrate Fire participant
from Section 15.5.2. The test must cover:

- Concentrate Fire selected before H9;
- H9 selected before Concentrate Fire;
- Concentrate Fire changing the selected die and making a projected H9 command
  stale;
- another blocker remaining after H9 use or decline;
- final continuation only after all blockers resolve.

The shared deterministic test participant continues to prove participant
creation/invalidation combinations not expressible by Concentrate Fire. Do not
migrate production Swarm merely to satisfy those generic cases. Run current
Swarm tests as mandatory regression evidence.

### 15.10 H9 Cleanup

The orchestrator cleans only `TimingWindowState`. H9 guard cleanup occurs
through explicit authoritative command owners:

| Trigger | Required owner/path |
| --- | --- |
| H9 use | `UseH9Command` creates used guard. |
| H9 decline | `DeclineH9Command` creates declined guard. |
| Normal Attack Modify exit | Successful `confirm_attack_dice` clears the matching H9 guard atomically with accepted Attack Modify exit and closes `TimingWindowState`. |
| Individual attack cancellation | `SkipAttackCommand(reason=cancelled)` clears the matching guard in its atomic terminal transaction. |
| Flow replacement | `SkipAttackCommand(reason=flow_replaced)` clears the matching guard and current attack before replacement may begin. |
| Flow termination | `SkipAttackCommand(reason=flow_terminated)` clears the matching guard and current attack before scene teardown. |
| Individual attack completion | `CompleteAttackCommand` clears the matching guard in its atomic terminal transaction before the next attack or anti-squadron target begins. |
| Save/load or reconnect with an H9 guard without both a matching canonical attack and matching active timing lifecycle | Reject the inconsistent `GameState` through the existing invalid-state path; do not clear or repair the guard during reconstruction. |
| Save/load or reconnect before confirmation with a valid matching guard | Preserve it and re-derive the same remaining choices. |
| Save/load or reconnect after successful confirmation | Reconstruct the downstream attack stage with no H9 guard and no active Attack Modify timing lifecycle. |
| Rejected H9 command | No cleanup and no lifecycle change. |
| Failed continuation | Guard and active lifecycle remain; no premature cleanup. |

Cleanup is idempotent. The guard is scoped to one individual attack and is
cleared at the first successful normal confirmation or abnormal terminal exit,
not at ship-activation or anti-squadron-loop teardown. A reconnect before that
boundary cannot reset H9, and a first attack/target guard cannot suppress H9 for
the second attack/next target. No callback, scene observer, reconstruction
repair, or dedicated H9 cleanup command is permitted.

### 15.11 Projection And Live Interaction

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

### 15.12 Likely Change Surfaces

Production surfaces likely include:

- canonical `CurrentAttackState` under the `GameState` state boundary;
- new `BeginAttackCommand` and `CompleteAttackCommand` plus CON-001 migration
  of `RollDiceCommand`, `RerollAttackDieCommand`, `ConfirmAttackDiceCommand`,
  `SkipAttackCommand`, Accuracy, defense-token, Evade, Redirect, and damage
  semantic commands;
- explicit Concentrate Fire dial use/decline commands and the production
  Concentrate Fire token participant/use/decline commands;
- removal of `PublishAttackFlowCommand` from new semantic attack progression
  while retaining only the compatibility handling in Section 17.2;
- H9 rule implementation under `src/core/effects/rules/upgrades/`;
- `src/autoload/rule_bootstrap.gd`;
- `src/core/effects/rule_registry.gd` registration use;
- new `UseH9Command` and `DeclineH9Command` files;
- `src/autoload/command_processor.gd` registration;
- `src/core/commands/game_replay.gd` and `src/autoload/replay_driver.gd` for the
  Section 17.2 format boundary;
- `src/core/state/flow_spec.gd`;
- `src/core/commands/command_applicability.gd`;
- Model C-S one-way scene, flow, and projection mirror integration required by
  Sections 15.3-15.4;
- attack opening/continuation commands and attack-flow projection seam;
- `src/core/network/ui_projector.gd`;
- `src/core/network/state_filter.gd` for viewer-filtering integration and
  evidence;
- attack panel/controller/mirror generic opportunity rendering;
- `GameManager` remote command classification as handled no-op where no scene
  side effect is required.

Tests likely include:

- CON-001 current-attack lifecycle, semantic command, atomicity, Model C-S,
  serialization, replay, reconnect, network, and one-way mirror tests;
- distinct first/second attack and per-target anti-squadron lifecycle tests;
- cancellation, flow-replacement, flow-termination, interrupted reconstruction,
  and no-identity-reuse tests;
- canonical Accuracy-lock, defense progression, Evade, Redirect, damage, and
  reconnect/resume tests;
- Concentrate Fire dial and token use/decline command tests plus H9 coexistence;
- H9 rule derivation unit tests;
- H9 use/decline and expected-source stale-command tests;
- H9 runtime upgrade serialization/guard tests;
- FlowSpec/applicability agreement tests;
- shared protocol suite instantiated with H9;
- H9 plus production Concentrate Fire coexistence tests and generic shared
  invalidation-fixture tests;
- projection/visibility/live-route tests;
- save/load, replay, reconnect, network sequence, and cleanup tests;
- existing Swarm, Accuracy, attack confirmation, and defense-token regressions;
- hot-seat and network baseline/runtime smoke evidence.

### 15.13 H9 Checkpoint

Expected state after Slice 8:

- H9 is implemented only through the shared timing-window path;
- no H9 local lifecycle or continuation code exists;
- Slice 8A remains passing and per-individual-attack identity, dice, Accuracy,
  defense progression, and damage-continuation facts come only from canonical
  serialized `CurrentAttackState` or referenced existing authoritative owners;
- Slice 8B-1 remains passing and no legal Concentrate Fire token choice can be
  bypassed by shared-window continuation;
- H9 guard lives only on its runtime upgrade owner, references one individual
  attack identity, and clears on successful confirm or abnormal attack exit;
- projection is derived;
- command history contains opening, use/decline, continuation, and downstream
  attack commands in accepted order;
- reconnect and replay reconstruct the same pending and post-resolution states;
- ship anti-squadron H9 and per-target guard reset pass;
- Tarkin and ECM behavior remains unchanged.

Proceed to Project Owner implementation review only when all H9-specific and
shared evidence is mapped. Do not update CAP status in this implementation
task.

Stop when:

- H9 needs `InteractionFlow.payload` as legality authority;
- attack identity/dice cannot be made authoritative within the accepted attack
  state boundary or a semantic transition remains scene-owned;
- H9 use/decline cannot be expressed as normal commands;
- cleanup requires a non-replayable callback;
- live and replay command sequences differ;
- one identity spans multiple attacks or anti-squadron targets;
- Accuracy, defense, or damage continuation requires a writable scene-only fact;
- Concentrate Fire token can be bypassed by automatic continuation;
- a squadron-attacker attack opens the shared window before Swarm migration;
- current Swarm behavior regresses;
- any implementation requires a new architecture decision.

### 15.14 Binary Acceptance Criteria

- [ ] H9 is a RuleRegistry candidate, not a local participant.
- [ ] The Slice 8A Model C-S Gate passed before H9 production edits began.
- [ ] The Slice 8B-1 Concentrate Fire Readiness Gate passed before H9
      implementation began.
- [ ] The Production Coexistence And H9 Pre-Activation Gate passed before
      production opening.
- [ ] Every individual attack/anti-squadron target has one fresh attack identity
      and retires before the next begins.
- [ ] H9 opportunity identity uses runtime upgrade and attack identity.
- [ ] Use and decline are explicit replayable commands.
- [ ] H9 use carries expected source color/face and rejects a changed selected
      die identically in local, network, and replay execution.
- [ ] H9 use identifies `DiceFace.ACCURACY` as its target semantic face and
      validates that the expected source color supports it.
- [ ] Use changes exactly one legal die to same-color Accuracy.
- [ ] Decline changes no dice.
- [ ] H9 guard is rule-owned, serialized, scoped to one attack, preserved by
      reconnect before confirmation, and cleaned by confirm/cancel/replace/
      terminate paths.
- [ ] Concentrate Fire token and H9 coexist in both player-selected orders; no
      production blocker is bypassed.
- [ ] Ship anti-squadron attacks offer H9 and reset its guard for every target.
- [ ] Cancellation, flow replacement, and flow termination clean H9 through the
      authoritative terminal command transaction.
- [ ] `confirm_attack_dice` is the only normal exit and occurs exactly once.
- [ ] Projection, visibility, live route, replay, save/load, reconnect, and
      networking pass.
- [ ] Existing Swarm remains available on squadron-attacker attacks, which do
      not open the shared window in this tranche.
- [ ] Accuracy locks, defense progression, and damage resolution consume and
      advance authoritative current-attack state after H9.
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

Before Slice 8B acceptance, exact tests must cover:

| TEST-003 category | Shared evidence | H9 unique evidence |
| --- | --- | --- |
| Lifecycle | open, one active, cancel, replace, close, reopen identity | fresh attack/H9 identity for first, second, and every anti-squadron target |
| Ownership | GameState lifecycle; orchestrator decisions | H9 guard on runtime upgrade; dice on authoritative attack owner |
| Discovery | RuleRegistry candidates, duplicate suppression, invalid registration | H9 registered by capability/participant key |
| Opportunity derivation | canonical record, failure, duplicate identity | source/dice/guard legality per H9 |
| Player ordering | all choices projected, no auto-select | H9 and Concentrate Fire both orders; generic invalidation fixture |
| Commands/mutation | lifecycle identity, use/decline, stale rejection | exact die mutation/decline; expected source color/face stale rejection |
| Re-derivation | after every accepted relevant command | H9/Concentrate Fire order and legality changes |
| Continuation | no blockers, exact one, failure preservation | only `confirm_attack_dice` after both production blockers resolve |
| Cleanup | all shared trigger/failure categories | guard clears on confirm/complete/cancel/replace/terminate |
| Serialization | lifecycle round-trip, no opportunities, signed next-sequence cursor | per-attack identity/dice/Accuracy/defense state and H9 guard round-trip |
| Save/load | active/post/closed states plus cursor restoration | before choice; after use/decline/confirm; during Accuracy and defense |
| Replay | preserved contiguous full-game sequence from cursor 0, no duplicate synthesis | format 3 plus initial cursor; use/decline/continuation/terminal histories; old-format rejection |
| Reconnect | lifecycle, synchronized cursor, derived projection | matching guard before confirm; no guard after confirm; canonical Accuracy/defense resume |
| Networking | host assignment, preserved ordered mirror, no client synthesis | H9 command classification and host/client identity/dice equality |
| Projection/live route | derived, stale intent rejected | public H9 list, attacker-only interaction, tooltip |
| Visibility | owner/hidden/public generic cases | H9 public visibility and no authority transfer |
| Effect interaction | passive vs optional, coexistence | H9 plus Concentrate Fire; downstream Accuracy/defense |
| Runtime smoke | shared live dispatch path | ship anti-ship and anti-squadron H9 through defense/terminal |

Passing shared protocol evidence does not prove H9 legality, mutation,
cleanup, visibility, or gameplay consequence. Passing H9 tests does not waive a
missing shared protocol category.

The Slice 8A gate separately maps exact tests to CON-001 lifecycle, identity,
membership, commands, atomicity/failure, serialization, save/load, replay,
network, reconnect, projection/visibility, ownership-boundary, and Model C-S
migration evidence. TEST-003 categories are not renamed or broadened; the
CON-001 evidence establishes the accepted current-attack prerequisite consumed
by the H9 rows above.

### 16.3 Command Sequence Oracles

Compare explicit command sequences, not only final state.

Minimum H9 use sequence:

1. the replayable attack-entry command creates canonical current-attack state;
2. optional Concentrate Fire dial use/decline resolves canonically before roll;
3. `RollDiceCommand` records canonical dice, progresses semantic stage to
   `ATTACK_MODIFY`, and the post-success seam opens one timing lifecycle;
4. `UseH9Command` resolves one H9 source;
5. Concentrate Fire token use/decline and any remaining modifier commands
   resolve in player-selected
   order;
6. exactly one `confirm_attack_dice` continuation occurs and progresses
   canonical semantic attack stage;
7. Accuracy-lock, defense, and damage commands continue from canonical state;
8. after that target's resolution, and before selecting another attack/target,
   `CompleteAttackCommand` completes canonical current-attack state.

Minimum H9 decline sequence substitutes `DeclineH9Command` at step 4.

Hot-seat, host history, client mirror, replay, and baseline traces must agree on
semantic order. A client may receive projection between results but may not add
commands.

First/second ship attacks and anti-squadron target iteration repeat this entire
sequence with a new `BeginAttackCommand.sequence` identity. Cancellation,
replacement, or flow termination substitutes the matching `SkipAttackCommand`
terminal transaction for steps 7-8 and no next begin occurs before it succeeds.

## 17. Compatibility And Versioning Posture

### 17.1 GameState And Saves

Reuse Slice 1 and `SaveGameMetadata.CURRENT_VERSION` behavior. Adding
authoritative current-attack serialization uses that same compatibility owner.
New saves and checkpoints add the backward-compatible signed header field
`next_command_sequence`, captured from the sole `CommandProcessor` cursor at the
same save boundary as `GameState.serialize()`. A present value must be an
integral non-negative value greater than every sequence embedded in an active
current-attack or timing-window lifecycle identity. `SaveGameManager` returns it
with the validated load result, and the existing
`GameManager.start_new_game_from_state()` installation path restores
`CommandProcessor` to that value before command submission or projection resumes.

An older accepted save without `next_command_sequence` selects exactly one
compatibility outcome: it restores cursor `0` only when canonical current-attack
and timing-window state are both inactive and no serialized rule guard refers to
either lifecycle. This is safe because such a save predates command-sequence-
derived production lifecycle identity. If any such lifecycle or guard is
present, the missing cursor is `schema_invalid`; it is not inferred from scene,
flow, projection, or local history.

An older save with no `CurrentAttackState` reconstructs the inactive
representation only when the rest of authoritative state contains no active
attack. If legacy flow/projection data indicates an in-progress attack but
canonical current-attack facts are absent, loading rejects through
`schema_invalid`; it does not reconstruct authority from that legacy data.
Invalid present current-attack or timing-window state also fails closed.

### 17.2 Replay

Repository evidence is explicit: current unsigned replays emit
`GameReplay.FORMAT_VERSION == 1`, signing changes the header to
`SIGNED_FORMAT_VERSION == 2`, and neither `GameReplay.deserialize()` nor
`ReplayDriver` currently rejects a version before command application. Slice 8A
must therefore add, not assume, the compatibility boundary.

Use replay format value `3`, the first value that does not collide with either
current emitted format. Set `GameReplay.FORMAT_VERSION` to `3`; retain
`SIGNED_FORMAT_VERSION` only as the source-compatible alias
`SIGNED_FORMAT_VERSION := FORMAT_VERSION`. `sign_replay()` adds/verifies the
signature but writes the same semantic format value `3`; signing no longer
changes replay semantics to a second format number.

Every format-3 header also carries integral non-negative
`initial_command_sequence`. Full-game replay capture writes `0`. Replay capture
from an accepted reconstructed initial state writes the cursor paired with that
state. Before applying the first recorded command, `ReplayDriver` restores that
cursor into `CommandProcessor`; each command must then carry that value or the
next contiguous value. Replay application preserves the serialized value rather
than replacing it with a newly allocated local sequence.

`GameReplay.deserialize()` owns the check. After JSON/header shape validation
and before any command is deserialized or applied, it accepts exactly format
`3` and returns failure for every other value. `ReplayDriver` maps that failure
to its normal replay load-failure result and applies zero commands. Pre-migration
unsigned format `1`, signed format `2`, missing, non-integer, and unknown future
versions are therefore deterministically rejected. This rejection behavior and
its focused tests are implementation work in Slice 8A; no existing
unsupported-format path is claimed.

At that same pre-application boundary, `GameReplay.deserialize()` validates
`initial_command_sequence` and the complete serialized command-sequence column.
Missing, non-integral, negative, duplicate, decreasing, or gapped sequence data
returns the same replay load failure and applies zero commands. Runtime replay
application still checks each preserved value against the restored
`CommandProcessor` cursor so state divergence fails closed at the command seam.

In particular, pre-migration `publish_attack_flow`, `confirm_attack_dice`,
`skip_attack`, roll, or reroll history is not used to reconstruct missing
current-attack or timing lifecycle identity.

There is no command-by-command legacy attack-history migration, no inference
from `InteractionFlow` or scene snapshots, and no timing-window replay version.
Format-3 replays record the accepted semantic attack commands and the
orchestrator-produced continuation in authoritative order.

### 17.3 Baselines

Canonical `GameState.serialize()` changes can intentionally change final-state
hashes without changing command traces. Do not preserve obsolete hashes. Update
fixtures only in an explicitly authorized baseline-maintenance task after the
implementation and semantic trace have been accepted.

Committed replay fixtures with format `1` or `2` are expected to fail the new
format check until that authorized maintenance updates their headers and command
histories to format `3`. Slice 8A focused version/replay tests and semantic trace
review must pass before fixture maintenance; full baseline acceptance then
requires regenerated format-3 fixtures and no unexplained command drift.

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
| Mirror/load/reconnect replaces or rolls back command sequence | Keep `CommandProcessor` as sole allocator, preserve preassigned mirror/replay sequences, and restore the signed/synchronized next cursor before commands resume. |
| `InteractionFlow.payload` authorizes H9 | Require the Slice 8A Model C-S Gate before H9 commands and prohibit reverse writes from flow/scene mirrors. |
| Model C-S leaves two writable owners | Test every migrated fact for canonical-only writes and reject Slice 8A before production timing activation. |
| One attack identity spans a second attack/target | Complete and retire before `_attack_exec_finalize_attack()` or `_finalize_squadron_attack()` advances; assert a fresh begin sequence. |
| Downstream Accuracy/defense state remains scene-owned | Gate Slice 8A on canonical locks, defense progression, damage continuation, save/load, and reconnect evidence. |
| Automatic continuation bypasses Concentrate Fire | Keep production opening disabled until the Concentrate Fire Readiness Gate and later H9 coexistence gate pass. |
| Shared opening captures squadron Swarm prematurely | Gate the production trigger on canonical attacker kind ship and retain Swarm regression traces. |
| H9 intent acts on a changed die | Carry and validate selected index plus expected source color/face before all mutation. |
| Replay accepts pre-Model-C-S history | Detect exact format 3 in `GameReplay.deserialize()` before command deserialization/application. |
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
- repository evidence conflicts with ADR-001, ADR-005, CON-001, CON-005, or
  TEST-003;
- Slice 1 semantics appear insufficient and would need reinterpretation;
- command ordering cannot preserve trigger-before-continuation;
- mirror/replay application cannot preserve the authoritative command sequence,
  or save/reconnect cannot restore one synchronized next-command cursor;
- Slice 8A cannot satisfy the accepted CON-001 membership, atomic command,
  one-way mirror, or one-owner migration obligations;
- one current-attack identity spans multiple ship attacks or anti-squadron
  targets;
- Accuracy, defense, damage, or reconnect requires writable scene-only attack
  state;
- replay format 3 is not rejected before command application when unsupported;
- the Concentrate Fire Readiness Gate cannot represent Concentrate Fire without
  bypass or duplicate mutation;
- a squadron-attacker roll enters shared `ATTACK_MODIFY` before Swarm migration;
- H9 stale validation cannot compare the expected source color/face with the
  canonical selected die;
- H9 requires architecture not present in the accepted documents;
- a provider, second registry, strategy layer, plugin, or generic engine
  appears necessary;
- Tarkin, ECM, or Swarm timing-window behavior must be migrated to make the H9
  checkpoint pass;
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
- [ ] `CommandProcessor` allocates each authoritative sequence once, preserves
      preassigned mirror/replay sequences, and restores the signed/synchronized
      cursor before save/load or reconnect continuation.
- [ ] Rule commands never complete a window.
- [ ] Exactly one continuation follows final re-derivation.
- [ ] Continuation failure preserves lifecycle and owned state.
- [ ] UI, modal routing, and GameManager own no timing lifecycle; CommandProcessor
      owns command sequencing/invocation only and no completion decision.
- [ ] Save/load, replay, reconnect, networking, visibility, and cleanup shared
      suites pass.

### 19.2 H9 Pilot

Before the H9 criteria apply:

- [ ] The Slice 8A Model C-S Gate passed independently.
- [ ] `GameState` owns the only writable canonical `CurrentAttackState` for
      every fact migrated by this tranche.
- [ ] Every first/second ship attack and anti-squadron target uses a distinct
      begin/complete identity and retires before the next begins.
- [ ] The same `BeginAttackCommand.sequence` produces the same current-attack
      identity in local, host, mirror, replay, save/load, and reconnect paths.
- [ ] `BeginAttackCommand`, roll/dice-mutation commands,
      `ConfirmAttackDiceCommand`, Accuracy/defense/damage commands,
      `SkipAttackCommand`, and `CompleteAttackCommand` own the planned semantic
      transactions.
- [ ] Scene, flow, projection, and UI are one-way non-authoritative consumers
      for migrated facts.
- [ ] `GameReplay.deserialize()` accepts format 3 only, rejects prior unsigned
      format 1 and signed format 2 before command application, and no legacy
      attack history is reinterpreted.
- [ ] CON-001 save/load, replay, reconnect, network, atomicity, and migration
      evidence passes.

- [ ] H9 uses the shared definition, registry, orchestrator, opportunity,
      command, projection, and evidence path.
- [ ] Concentrate Fire token use/decline uses that same shared path before H9
      production activation; squadron Swarm remains reachable outside it.
- [ ] The Concentrate Fire Readiness Gate passes before H9 implementation, and
      the Production Coexistence And H9 Pre-Activation Gate passes before
      production opening.
- [ ] H9 source identity uses `runtime_upgrade_id` on the attacking ship.
- [ ] Current attack identity and dice used by commands are authoritative and
      serialized independently of projection.
- [ ] Accuracy locks, defense progression, and damage continuation required by
      H9 evidence are canonical and reconstructable without scene authority.
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
- migration of current-attack facts outside the explicit Model C-S stage in
  Section 15.3;
- general scene attack architecture or internal FSM redesign beyond removing
  semantic authority and reverse writes for the migrated facts;
- generic participant provider contracts;
- reusable effect-composition abstractions;
- nested or simultaneous timing windows;
- priority passes or alternating priority;
- network transport redesign;
- save/replay version subsystem redesign;
- fixture updates before accepted implementation evidence;
- final cross-consumer TEST-003 acceptance.

## 21. Open Owner Questions

No unresolved architecture or contract-shaping Owner decision remains.
ADR-001 and CON-001 resolve the former attack-state blocker. Sections 10.4,
10.4.1, 11.3-11.5, 15.3-15.10, and 17 define one implementation outcome for the
per-attack lifecycle, downstream canonical state, production modifier
coexistence, H9 stale precondition, cleanup, and replay compatibility seams.
Private helper identifiers and exact test-file placement may follow repository
naming conventions without changing behavior or ownership.

## 22. Implementation Readiness Assessment

TWI-002 is ready for Project Owner acceptance as a Draft implementation
workbook.

The architecture is sufficient to plan Slices 2-8 because:

- all shared owners are fixed;
- canonical current-attack ownership, membership, semantic command mutation,
  and Model C-S direction are fixed by ADR-001 and CON-001;
- static policy ownership is fixed;
- the command and continuation protocol is fixed;
- command-sequence assignment, mirror/replay preservation, and save/reconnect
  cursor restoration are fixed at the existing command synchronization seams;
- discovery and opportunity identity are fixed;
- cleanup, replay, save/load, reconnect, network, projection, and evidence
  boundaries are fixed;
- H9 rule behavior and runtime-upgrade ownership are fixed;
- repository seams exist for definitions, registry registration, command
  processing, projection, filtering, replay, networking, and attack flow.

The former current-attack architecture blocker is no longer open. It is an
explicit implementation prerequisite in Slice 8A under ADR-001 and CON-001,
with a binary Model C-S Gate before production modifier integration. Slice 8B-1
then has a separate Concentrate Fire Readiness Gate before H9 implementation.
H9 is implemented with production opening disabled, and the Production
Coexistence And H9 Pre-Activation Gate precedes production activation. Failure
at any gate stops later edits; it does not reopen
ownership or permit `InteractionFlow.payload` or scene state to become
authoritative.

After Owner acceptance, implement Slices 2-7 as the largest safe shared-core
tranche, preserving each focused checkpoint and the Shared Core Gate. Then
implement Slice 8A and stop for its Model C-S Gate. Implement Slice 8B-1 and stop
again for the Concentrate Fire Readiness Gate before Slice 8B-2. Implement H9
with production opening disabled, then stop for the Production Coexistence And
H9 Pre-Activation Gate. No production opening or later migration should begin
until that gate and the shared TEST-003 evidence have passed.

## 23. Previous Audit Finding Closure

This matrix preserves every finding carried forward from the previous TWI-002
audit and the required refinement input. No finding is removed by omission.

### 23.1 Prior Refinement Finding Closure

| ID | Severity | Previous finding | Classification | Closure in this workbook |
| --- | --- | --- | --- | --- |
| C-1 | Critical | Authoritative current-attack state and semantic attack-transition ownership were unresolved, so H9 depended on scene state or an unaccepted attack owner. | Superseded by accepted authority | ADR-001 and CON-001 are now governing authority; Sections 5, 7, and 15.3-15.4 translate them into a Model C-S prerequisite and gate. |
| M-1 | Medium | Slices 2-8 formed one strict chain that buried the attack prerequisite inside H9 and weakened failure attribution. | Resolved | Section 8 makes Slices 2-7 the behavior-inert shared-core tranche, gates Slice 8B-1 behind the Model C-S checkpoint, gates Slice 8B-2 behind Concentrate Fire readiness, and gates production opening behind H9 coexistence evidence. |
| M-2 | Medium | Runtime-source enumeration had multiple possible participant kinds or entry points and no single ownership boundary. | Resolved | Sections 11.3-11.5 define one RuleRegistry descriptor and one registered-rule source-enumeration/derivation boundary from authoritative state. |
| M-3 | Medium | Command-result/orchestrator integration allowed `CommandProcessor` and/or submitter placement and did not fix local/network follow-up order. | Resolved | Section 10.4 fixes one `CommandProcessor._submit()` seam and the existing deferred FIFO/broadcast order for all execution modes. |
| M-4 | Medium | Stale or inconsistent timing-window/H9 state could be rejected or cleared, leaving recovery and cleanup implementation-defined. | Resolved | Sections 14.6, 14.8, and 15.10 require invalid-state rejection on reconstruction, state preservation on live inconsistency, and command-owned terminal cleanup. |
| M-5 | Medium | Legacy replay entries could be reconstructed or rejected, leaving current-attack and lifecycle compatibility undefined. | Resolved | Section 17.2 selects format 3, adds exact validation in `GameReplay.deserialize()`, aliases signed format to the same value, and rejects every older format before command application. |
| M-6 | Medium | H9 use payload allowed a selected Accuracy face or another deterministic equivalent. | Resolved | Section 15.7 selects one payload: semantic target `DiceFace.ACCURACY` plus selected index and expected source color/face; no physical face index or alternate target representation is allowed. |
| M-7 | Medium | Production H9 could begin before canonical attack identity/dice and command-owned attack progression existed. | Resolved | Sections 15.3-15.5 prohibit H9 edits until the Model C-S and Concentrate Fire Readiness Gates pass, and prohibit production opening until the later H9 coexistence gate proves all production blockers. |
| L-1 | Low | Orchestrator shape and canonical opportunity-helper placement were left as alternatives. | Resolved | Sections 10.3 and 11.4 select a stateless `RefCounted` orchestrator module and one adjacent plain-Dictionary validation helper. |
| L-2 | Low | Static participant registration referred to unknown participant kinds and could invite a kind switch or provider layer. | Resolved | Section 11.3 stores the registered rule implementation directly and prohibits participant-kind switches and provider objects. |
| L-3 | Low | Open-question and readiness text still treated attack ownership, minimum state shape, and integration placement as future choices. | Resolved | Sections 21-22 state that no Owner decision remains and point to the single seams and Slice 8A gate defined by accepted authority. |

No previous finding remains unresolved.

### 23.2 Focused Acceptance-Audit Finding Closure

| ID | Severity | Focused finding | Classification | Closure in this workbook |
| --- | --- | --- | --- | --- |
| B-1 | Blocking | One current-attack identity could span a ship's two attacks or multiple anti-squadron targets because retirement was tied to enclosing attack-execution teardown. | Resolved | Sections 10.4.1 and 15.3.1 require one preserved authoritative sequence and a begin/complete pair per target, with retirement before `_attack_exec_finalize_attack()` / `_finalize_squadron_attack()` advances. |
| B-2 | Blocking | Production shared opening could bypass Concentrate Fire token reroll or Swarm before automatic confirmation. | Resolved | Sections 15.5.1-15.5.4 require the pre-H9 Concentrate Fire Readiness Gate, then H9/Concentrate Fire coexistence evidence before production opening; squadron-attacker Swarm remains reachable and mandatory regression evidence. |
| B-3 | Blocking | Slice 8A covered attack identity/dice but left downstream Accuracy, defense, and resume-critical facts potentially authoritative only in scene state. | Resolved | Sections 15.3.2-15.3.3 define the canonical membership and semantic command boundary through Accuracy, defense, damage, reconstruction, and per-target terminal cleanup without copying legacy `AttackState` wholesale. |
| M-1 | Medium | Replay planning assumed an existing unsupported-version rejection path and ignored the signed-format value. | Resolved | Section 17.2 records current values 1/2, selects non-colliding format 3, makes signed format an alias, and adds exact pre-application validation in `GameReplay.deserialize()`. |
| M-2 | Medium | H9 selected die index alone could act on a changed authoritative die after another modifier. | Resolved | Section 15.7 carries expected source color/face with attack identity and index, validates exact canonical equality, and specifies identical rejection for local, network, and replay execution. |
| M-3 | Medium | CAP-H9 evidence did not explicitly cover ship anti-squadron attacks, flow replacement/cancellation/termination cleanup, per-attack guard reset, or reconnect. | Resolved | Sections 15.3.1, 15.10, 15.12-15.14, 16.2, and 19.2 add each behavior as a binary checkpoint and evidence obligation. |

All six focused findings are resolved; none is partially resolved or still
unresolved.

### 23.3 Final Acceptance Refinement Closure

| Finding | Classification | Closure in this workbook |
| --- | --- | --- |
| Command-sequence-based attack identity was not deterministic across mirror, save/load, and reconnect. | Resolved | Sections 6.3, 10.4.1, 14.3-14.7, 15.3-15.4, and 17 select one `CommandProcessor` cursor, preserve preassigned mirror/replay sequences, and restore signed/synchronized cursors before resumed commands. |
| The Production Coexistence Gate required H9 evidence before H9 implementation could begin. | Resolved | Sections 8 and 15.5 split the pre-H9 Concentrate Fire Readiness Gate from the post-H9 Production Coexistence And H9 Pre-Activation Gate. |
| The H9 decline oracle referenced step 3 instead of the H9 step. | Resolved | Section 16.3 substitutes `DeclineH9Command` at step 4. |

No final acceptance finding remains partially resolved or unresolved.

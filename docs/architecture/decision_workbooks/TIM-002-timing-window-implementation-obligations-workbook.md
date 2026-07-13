# TIM-002: Timing-Window Implementation Obligations Workbook

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-07-13

Decision topic: Implementation obligations for the future Timing Window
Lifecycle Contract

Supports: Forthcoming CON-005

Primary authorities: ADR-005 and TEST-003

Related documents: TIM-001, ADR-003, ADR-004, CON-003, CON-004,
CAP-UPG-001, CAP-ECM-001, CAP-H9-001

Date: 2026-07-11

Owner: Project Owner decision required

This workbook is not an ADR and is not CON-005.

It prepares implementation-level owner decisions needed before drafting the
future Timing Window Lifecycle Contract. It does not authorize runtime
implementation, migration, generic rule-engine work, or Rule Capability Package
status changes.

Synchronization note: accepted Project Owner decisions are recorded in
`docs/architecture/decision_workbooks/TIM-002-owner-decisions.md`. This workbook
reflects those accepted decisions while preserving its Draft workbook status
until CON-005 is drafted through the normal architecture workflow.

## 1. Purpose

This workbook answers:

> What concrete implementation obligations are required so that timing-window
> implementations conform to ADR-005 and can satisfy TEST-003?

TIM-001 and ADR-005 decide timing-window ownership and continuation. TEST-003
decides verification evidence categories. This workbook identifies the
implementation contract decisions that remain before CON-005 can be drafted.

The workbook treats current implementation as evidence only. If current code
conflicts with accepted architecture, accepted ADRs and Contracts remain
authoritative.

## 2. Scope And Non-Goals

In scope:

- implementation obligations that CON-005 should define,
- required invariants for authoritative timing-window lifecycle state,
- required boundaries for opportunity derivation, commands, projection,
  serialization, replay, network, reconnect, visibility, cleanup, and failure,
- owner decisions needed before CON-005 drafting.

Out of scope:

- drafting CON-005,
- modifying ADR-005, TEST-003, Contracts, CAPs, runtime code, production tests,
  fixtures, roadmap, or governance,
- defining final production API names,
- implementing `TimingWindowState`,
- implementing a Timing Window Orchestrator,
- implementing participant discovery,
- refactoring ECM or Tarkin,
- implementing H9,
- creating a generic rule engine,
- creating a generic effect-composition engine,
- authorizing broad rule rollout,
- marking any CAP Integrated.

## 3. Documents And Surfaces Read

Startup and authority documents:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/CODEX_WORKFLOW.md`

Accepted architecture and verification documents:

- `docs/architecture/decision_workbooks/TIM-001-timing-window-ownership-and-continuation-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-owner-decisions.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`

Rule-specific evidence:

- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md`
- `docs/architecture/rule_capability_packages/CAP-H9-001-h9-turbolasers.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`

Developer guidance:

- `.github/copilot-instructions.md`
- `.github/skills/rule-integration/SKILL.md`
- `.skills/testing_standards.md`
- `.skills/serialization_and_commands.md`
- `docs/game_flow.md`

Implementation and test evidence inspected:

- `src/core/state/game_state.gd`
- `src/core/state/interaction_flow.gd`
- `src/core/state/flow_spec.gd`
- `src/core/state/ship_instance.gd`
- `src/core/commands/game_command.gd`
- `src/autoload/command_processor.gd`
- `src/core/commands/command_applicability.gd`
- `src/core/commands/status_phase_cleanup_command.gd`
- `src/core/commands/start_round_command.gd`
- `src/core/commands/tarkin_choice_command.gd`
- `src/core/commands/use_ecm_command.gd`
- `src/core/commands/decline_ecm_command.gd`
- `src/core/commands/ready_ecm_command.gd`
- `src/core/commands/decline_ecm_ready_command.gd`
- `src/core/commands/commit_defense_command.gd`
- `src/core/commands/spend_defense_token_command.gd`
- `src/core/commands/confirm_attack_dice_command.gd`
- `src/core/commands/publish_attack_flow_command.gd`
- `src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd`
- `src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd`
- `src/core/effects/rules/README.md`
- `src/autoload/rule_bootstrap.gd`
- `src/core/effects/rules/*`
- `src/core/network/ui_projector.gd`
- `src/core/network/state_filter.gd`
- `src/autoload/game_manager.gd`
- `src/autoload/network_manager.gd`
- `src/core/commands/network_command_submitter.gd`
- `src/autoload/save_game_manager.gd`
- `src/autoload/replay_driver.gd`
- `src/scenes/game_board/modal_router.gd`
- `src/scenes/game_board/attack_panel_mirror.gd`
- relevant tests found under `tests/unit` and `tests/integration`, including
  Tarkin, ECM, modal, FlowSpec, UIProjector, CommandApplicability, replay,
  save/load, network ordering, and attack-flow tests.

## 4. Accepted Architecture Baseline

ADR-005 decides:

- timing windows are authoritative lifecycle objects,
- serialized `TimingWindowState` is owned by `GameState`,
- the Timing Window Orchestrator owns lifecycle, discovery orchestration,
  recalculation, and continuation,
- commands remain the only replayable mutation surface,
- rule opportunities are derived from authoritative runtime state,
- opportunities are re-derived after every successful replayable command that
  resolves an opportunity,
- `RuleRegistry` remains a static participant index only,
- `InteractionFlow`, `FlowSpec`, `RuleSurface`, `UIProjector`, scene
  controllers, modal routers, and UI are non-authoritative derived surfaces,
- player-controlled opportunity ordering is preserved where rules allow it,
- ADR-005 does not introduce a generic rule engine or effect-composition
  engine.

TEST-003 decides:

- it is the authoritative verification strategy for interactive
  timing-window behavior governed by ADR-005,
- the verification matrix is the normative evidence structure,
- CON-005 shall derive implementation obligations from TEST-003 categories
  rather than redefining, renaming, or narrowing them,
- verification architecture owns evidence categories; implementation contracts
  own implementation obligations,
- waivers may defer evidence only with Project Owner approval and must be
  recorded in the applicable CAP.

ADR-003 and CON-003 decide:

- rule behavior is integrated only when all applicable surfaces are traced and
  evidenced,
- `RuleRegistry` is one implementation surface, not the architecture,
- commands, resolvers, state classes, projection, serialization, replay,
  network, visibility, and tests remain responsibility surfaces.

ADR-004 and CON-004 decide:

- active equipped upgrades become runtime upgrade instances on the owning
  `ShipInstance` by default,
- mutable upgrade card state, trigger guards, and rule-specific state live on
  the runtime upgrade instance by default,
- static upgrade data is referenced by `data_key` and is not copied into
  runtime state.

## 5. Current Implementation Evidence Baseline

### 5.1 Current Timing-Window-Like State

`GameState` currently owns `interaction_flow` and serializes it in
`GameState.serialize()` / `GameState.deserialize()` in
`src/core/state/game_state.gd`.

`InteractionFlow` stores `flow_type`, `step_id`, `controller_player`,
`visible_to`, and JSON-safe `payload` in
`src/core/state/interaction_flow.gd`. Its header documents that it is held in
`GameState.interaction_flow` and filtered by `StateFilter` before snapshots
leave the server.

Current reality:

- `InteractionFlow` is the serialized live interaction projection surface.
- It is not a full ADR-005 `TimingWindowState`.
- It can carry reconnect payloads, but accepted architecture forbids using its
  payload as gameplay authority.

### 5.2 Current Flow And Applicability Surfaces

`FlowSpec` in `src/core/state/flow_spec.gd` stores static rows for known
`flow_type` / `step_id` pairs, including modal kinds, controller roles, and
allowed commands.

`CommandApplicability` in `src/core/commands/command_applicability.gd` maps
commands to global, phase, or flow-step scopes and has explicit blocking for
Tarkin and ECM Status Phase unresolved prompts.

Current reality:

- Flow and applicability are table-driven for known steps.
- Current prompt-blocking logic is still rule-specific and does not represent a
  shared timing-window lifecycle.
- CON-005 must preserve agreement among `FlowSpec.allowed_commands`,
  `CommandApplicability`, and concrete command validation without making any
  of them the lifecycle owner.

### 5.3 Current Command Submission And Replay Surface

`GameCommand` in `src/core/commands/game_command.gd` registers command types,
serializes `type`, `player`, `sequence`, and `payload`, and deserializes
through the registry.

`CommandProcessor` in `src/autoload/command_processor.gd` performs
applicability preflight, rule-validator checks, concrete `validate()`,
execution, sequence assignment, history recording, UI signal emission, and
observer follow-up draining. `submit_mirror()` applies already-authoritative
network command results while suppressing observer follow-up synthesis.

Current reality:

- Commands and command history are the replayable mutation path.
- Observer follow-ups exist through `RuleRegistry.observers_for()`.
- `CommandProcessor` executes commands but ADR-005 says it must not decide
  timing-window completion.

### 5.4 Current Continuation Ownership

Tarkin:

- `AdvancePhaseCommand` can enter `SHIP_ACTIVATION /
  TARKIN_COMMAND_CHOICE`.
- `TarkinChoiceCommand` validates and executes the use or decline.
- `GrandMoffTarkin.record_choice()` stores the once-per-Ship-Phase guard on
  the source runtime upgrade instance.
- Current Tarkin continuation enters normal ship selection after the Tarkin
  command.

ECM Status Phase:

- `StatusPhaseCleanupCommand` opens `STATUS_CLEANUP /
  STATUS_CLEANUP_STEP` and projects ECM ready-cost choices.
- `ReadyECMCommand` and `DeclineECMReadyCommand` update
  `runtime_upgrade.rule_state.status_ready_cost` and do not remove it.
- `GameManager.submit_ready_ecm_runtime()` and
  `submit_decline_ecm_ready_runtime()` submit the choice, recalculate unresolved
  choices, and call the normal phase continuation only when none remain.
- `StartRoundCommand` validates that unresolved ECM ready-cost choices are
  absent and clears ECM ready-cost window state.

Current reality:

- Continuation is currently split across commands and `GameManager` helpers.
- The ECM modal repair proved that direct UI submission can bypass
  continuation unless routed through a GameManager-owned helper.
- ADR-005 requires a common orchestrating owner instead of rule commands, UI
  callers, modal routers, or `CommandProcessor` deciding completion.

### 5.5 Current Projection And Modal Routing

`UIProjector.project()` in `src/core/network/ui_projector.gd` derives a
`UIIntent` from `GameState.interaction_flow`, `FlowSpec`, and viewer identity.

`ModalRouter` in `src/scenes/game_board/modal_router.gd` renders projected
modal kinds and dispatches Tarkin and ECM ready-cost choices. ECM ready/decline
now routes through `GameManager.submit_ready_ecm_runtime()` and
`submit_decline_ecm_ready_runtime()`.

Current reality:

- Projection and modal routing are derived/live presentation paths.
- The live route matters for TEST-003, but it must not become gameplay
  authority.
- CON-005 must require stale projection rejection and live-route submission
  through the accepted authoritative orchestration path.

### 5.6 Current Serialization, Save/Load, Replay, Network, And Reconnect

`SaveGameManager` stores saves as `{"header": ..., "state":
GameState.serialize()}` and deserializes through `GameState.deserialize()` in
`src/autoload/save_game_manager.gd`.

`ReplayDriver` and `CommandProcessor.replay_commands()` replay serialized
commands rather than UI-local state.

`NetworkManager` broadcasts command results, and `NetworkCommandSubmitter`
queues outbound client commands while waiting for authoritative results, with a
narrow assign-dials exception. Recent network-ordering work added the invariant
that clients must apply authoritative server command results in server sequence
order before projecting later flow states.

Current reality:

- Serialized authoritative state and command history exist.
- Reconnect and projection are derived from serialized state plus mirrored
  command results.
- There is no generic active `TimingWindowState` yet.

### 5.7 Current RuleRegistry Usage

`src/core/effects/rules/README.md` describes `RuleRegistry` as static hook
definitions and serialized entities as active rule truth.

Examples include:

- damage-card blockers and validators for attack and defense-token commands,
- squadron keyword affordances such as Swarm in `ATTACK_MODIFY`,
- ECM rule registration for attack defense-token and Status Cleanup surfaces,
- command-token gain blockers read by Tarkin through `RuleSurface`.

Current reality:

- `RuleRegistry` can identify candidate participants and hooks.
- It does not own active state, opportunity eligibility, controller choice,
  timing-window completion, or continuation.

## 6. Decision Topics

### 6.1 Contract Boundary

#### Accepted constraints

ADR-005 owns timing-window architecture, authority, lifecycle ownership,
continuation ownership, non-authoritative opportunities, non-authoritative
RuleRegistry, and player-controlled ordering.

TEST-003 owns evidence categories, verification matrix, rollout evidence
obligations, and evidence-waiver governance.

The accepted principle is:

> Verification architecture owns evidence categories; implementation contracts
> own implementation obligations.

#### Repository evidence

- ADR-005 states a follow-up Timing Window Contract is required for
  implementation obligations.
- TEST-003 states CON-005 shall derive obligations from its verification
  categories rather than redefining or narrowing them.
- CON-003 and CON-004 show the repository pattern for converting ADR decisions
  into numbered implementation requirements.

#### Current reality

No CON-005 exists. Current implementation obligations for interactive timing
windows are distributed across CAPs, commands, `GameManager`, `FlowSpec`,
`CommandApplicability`, projection tests, and modal tests.

#### Problem

CON-005 needs a precise boundary so it neither re-decides ADR-005 nor weakens
TEST-003.

#### Options

Option A: CON-005 repeats ADR-005 and TEST-003 in implementation language.

Option B: CON-005 defines implementation invariants, semantic state
requirements, interface obligations, lifecycle mechanics, command obligations,
serialization obligations, cleanup obligations, and integration obligations
while referencing ADR-005 and TEST-003 as authorities.

#### Consequences

Option A risks authority duplication and inconsistent vocabulary.

Option B fits CON-003 and CON-004 precedent and preserves accepted authority.

#### Recommendation

Choose Option B.

CON-005 should own:

- implementation obligations,
- required invariants,
- required semantic state information,
- schema constraints without over-specifying final field names,
- participant and opportunity interface obligations,
- lifecycle mechanics,
- command obligations,
- serialization, replay, network, reconnect, visibility, cleanup, and failure
  obligations,
- integration obligations for CAPs and shared protocol suites.

CON-005 should not own:

- ADR-005 authority decisions,
- TEST-003 evidence categories,
- rule-specific CAP behavior,
- exact production class names unless required for a safe migration.

#### Owner decision status

No Project Owner architecture decision is required. Contract drafting style can
follow existing repository conventions without changing the implementation
obligations.

### 6.2 TimingWindowState Obligations

#### Accepted constraints

ADR-005 requires a dedicated serialized `TimingWindowState` owned by
`GameState`. It owns lifecycle only and must not store a mutable queue of
opportunities or duplicate rule truth.

#### Repository evidence

- `GameState` currently serializes `interaction_flow`.
- `InteractionFlow` serializes current projected flow identity and payload.
- Runtime upgrade guards such as Tarkin and ECM live in
  `ShipInstance.runtime_upgrades[*].rule_state`.
- `StartRoundCommand` validates unresolved ECM choices and clears ECM
  ready-cost guards on window exit.

#### Current reality

There is no dedicated `TimingWindowState`. `InteractionFlow` is carrying some
window-like facts, but it is a derived interaction surface.

#### Problem

CON-005 must define the minimum semantic information required for an
authoritative timing-window lifecycle object without turning it into rule
state or a cached opportunity queue.

#### Options

Option A: Treat existing `InteractionFlow` as the timing-window state.

Option B: Add a `GameState`-owned lifecycle state with semantic obligations for
active window identity, timing point, controlling or priority context, active
lifecycle status, continuation context sufficient to resume the lifecycle,
cancellation or replacement context, and serialization/reconstruction, while
leaving final field names flexible.

Option C: Store full opportunity lists in serialized timing-window state.

#### Consequences

Option A conflicts with ADR-005 because `InteractionFlow` and projection remain
non-authoritative.

Option B satisfies ADR-005 while keeping CON-005 narrow.

Option C conflicts with ADR-005 because opportunities are re-derived and not a
mutable queue.

#### Recommendation

Choose Option B.

CON-005 should require serialized semantic information sufficient to answer:

- whether a timing window is active,
- which timing-window lifecycle interval is active,
- which game-flow timing point the window represents,
- which player or priority context currently controls opportunity selection
  when applicable,
- which continuation context is needed to resume the lifecycle,
- whether the window is waiting for opportunities, waiting for continuation,
  closing, cancelled, or replaced,
- which lifecycle epoch or context prevents stale commands from applying after
  replacement,
- how the window reconstructs across save/load, replay initialization, network
  snapshots, and reconnect.

CON-005 should explicitly exclude:

- continuation commands, payloads, and serialized continuation descriptors,
- mutable opportunity queues,
- participant lists,
- `RuleRegistry` data,
- derived legality or visibility,
- projection, UI, and modal state,
- rule-specific use/decline guards,
- costs,
- card state,
- pending authorizations,
- selected die/token/effect results,
- static catalog data.

Accepted owner decision: `TimingWindowState` serializes only authoritative
lifecycle semantics. Opportunities, participant lists, projection data,
derived legality, static registry data, and rule-specific mutable state are
re-derived or owned by their existing authoritative owners.

### 6.3 TimingWindowOrchestrator Obligations

#### Accepted constraints

ADR-005 makes the Timing Window Orchestrator responsible for lifecycle,
discovery orchestration, recalculation after opportunity resolution, and
continuation. It does not own rule effects and is not a generic rule engine.

#### Repository evidence

- `GameManager._maybe_start_round_after_status_ready_cost()` currently performs
  ECM Status Phase recalculation and continuation.
- `TarkinChoiceCommand` currently performs Tarkin-local continuation.
- `CommandProcessor` submits and records commands but is not a lifecycle owner.

#### Current reality

Continuation is split across surfaces. This works for narrow cases but does not
scale to multiple opportunities in one window.

#### Problem

CON-005 must make "narrow orchestrator" enforceable.

#### Options

Option A: Let each rule command decide completion.

Option B: Let a central orchestrating owner open windows, coordinate
participant discovery, re-derive opportunities, determine blocking state,
submit or enable continuation, close windows, and clean up shared lifecycle
state.

Option C: Let UI or modal routers submit continuation after final choice.

#### Consequences

Option A duplicates lifecycle logic and caused known continuation fragility.

Option B matches ADR-005 and preserves commands as mutation owners.

Option C conflicts with projection and UI authority boundaries.

#### Recommendation

Choose Option B.

CON-005 should require the orchestrator to:

- open a timing window through an authoritative command or accepted
  orchestration path,
- create or update `TimingWindowState`,
- consume the immutable static timing-window definition for the active window
  directly from the shared timing-window module,
- coordinate participant discovery,
- request or invoke opportunity derivation from authoritative participants,
- determine whether blocking opportunities remain,
- preserve player-controlled ordering when rules permit,
- after every accepted opportunity command, re-derive opportunities before
  allowing continuation,
- submit or enable the associated continuation command exactly once when no
  blocking opportunities remain,
- prevent duplicate continuation,
- close the timing window on continuation, cancellation, replacement, or
  explicit cleanup,
- reconstruct derived opportunity projection after save/load, replay,
  snapshots, and reconnect,
- leave rule effects and mutable rule state on rule-specific owners.

Accepted owner decision: the Timing Window Orchestrator owns lifecycle,
discovery orchestration, recalculation, continuation, duplicate-continuation
prevention, and shared lifecycle cleanup. Concrete class structure and adapter
shape remain implementation details for CON-005 drafting and implementation.

### 6.4 Participant Discovery Obligations

#### Accepted constraints

ADR-005 permits `RuleRegistry` only as a static participant index. It must not
determine concrete eligibility, controlling player, order, completion,
continuation, or mutation.

#### Repository evidence

- `RuleRegistry.register_rule()` entries exist for damage cards, squadron
  keywords, ECM, and command-token blockers.
- `RuleRegistry.validators_for()` and `observers_for()` are used by
  `CommandProcessor`.
- `docs/game_flow.md` states `RuleRegistry` declares static hook definitions
  while active rule truth is derived from serialized entities.
- Some current behavior is local-call-site based, such as Tarkin active-source
  discovery and ECM helper methods.

#### Current reality

The repository has both static RuleRegistry hooks and local helper discovery.
Neither is a complete timing-window participant-discovery contract.

#### Problem

CON-005 must identify participants without making RuleRegistry authoritative
and without requiring a broad generic rule engine.

#### Options

Option A: RuleRegistry is the only participant discovery source.

Option B: Timing windows declare accepted participant discovery sources:
static RuleRegistry candidate index entries and explicit local call-site
participants. Both must derive concrete opportunities from authoritative
runtime state.

Option C: Each command hardcodes all participant discovery for its window.

#### Consequences

Option A is acceptable only if RuleRegistry remains a static candidate index
and never determines concrete runtime eligibility, ordering, completion,
continuation, or mutation.

Option B matches current mixed evidence but was rejected for Version 1 because
it introduces a second discovery path before evidence proves one is necessary.

Option C does not scale and reintroduces command-owned lifecycle.

#### Recommendation

Choose Option A for CON-005 Version 1.

CON-005 should require:

- static participant identity by timing-window identity and capability identity,
- deterministic candidate discovery order for stable presentation and replay
  comparison,
- concrete runtime derivation by rule-specific participants from authoritative
  serialized state,
- graceful handling of absent runtime sources and stale static registrations,
- duplicate participant suppression by capability identity plus authoritative
  runtime-source identity,
- performance guidance that discovery must be bounded by the RuleRegistry
  candidate index rather than scanning unrelated rules.

Accepted owner decision: RuleRegistry is the only participant-candidate source
for Version 1. It supplies candidates only and shall not determine legality,
ordering, completion, continuation, mutation, or visibility. Explicit local
call-site participant lists, provider abstractions, discovery strategy layers,
and speculative extension interfaces are excluded from Version 1.

### 6.5 Opportunity Derivation Obligations

#### Accepted constraints

Opportunities are derived from authoritative runtime state, are not stored as a
mutable queue, and must not use synthetic persistent UUIDs as an independent
source of identity.

#### Repository evidence

- Tarkin opportunity identity is grounded in `runtime_upgrade_id` and owning
  player.
- ECM attack-time authorization and Status Phase ready-cost guards are grounded
  in runtime upgrade `rule_state`.
- H9 CAP requires opportunity identity from H9 runtime upgrade source and
  current attack context.
- `InteractionFlow.payload` carries derived candidate data for UI and
  reconnect, but command validation recalculates from authoritative state.

#### Current reality

Rule opportunities are currently shaped per rule. No shared contract defines
their common semantic minimum.

#### Problem

CON-005 must define the semantic opportunity contract without finalizing a
production API.

#### Options

Option A: Opportunity payloads are arbitrary per rule with no shared semantic
requirements.

Option B: Every derived opportunity must expose a canonical semantic minimum:
capability identity, source-owner kind, authoritative runtime-source identity,
stable semantic opportunity key, controlling player identity, resolution kind,
use command intent, optional decline command intent, and blocking status.

Option C: Store every opportunity as a persistent serialized object.

#### Consequences

Option A cannot support shared continuation, visibility, replay, or TEST-003
evidence at scale.

Option B preserves rule-specific behavior while giving the orchestrator enough
information to present, select, and continue safely.

Option C conflicts with ADR-005 re-derivation.

#### Recommendation

Choose Option B.

CON-005 should require opportunity derivation to:

- produce deterministic, JSON-safe derived descriptors,
- ground identity in capability identity and authoritative runtime-source
  identity,
- include source-owner kind and a stable semantic opportunity key,
- include controlling player identity,
- classify `OPTIONAL` versus `REQUIRED_CHOICE` resolution kind,
- identify use command intent and optional decline command intent,
- identify blocking status,
- reject stale, repeated, invalidated, wrong-source, wrong-player, and
  wrong-window selections in command validation,
- re-evaluate legality after every accepted opportunity command.

Opportunity records are derived, never authoritative, and shall contain no
cached legality, ordering, visibility, UI state, continuation state, mutable
rule state, or effect results. Command intents contain only the registered
replayable command type and the minimum stable authoritative identity context.
Passive automatic effects are not interactive opportunities.

### 6.6 Player Control And Ordering Obligations

#### Accepted constraints

ADR-005 requires the orchestrator to preserve player-controlled ordering where
game rules allow it. It must not silently select an optional opportunity merely
because it appears first.

#### Repository evidence

- CAP-H9 requires multiple optional rules in `ATTACK_MODIFY` to be presented
  together and selected by the controlling player.
- CAP-ECM Status Phase says the controlling player chooses order when multiple
  optional rules exist and unresolved optional Status Phase choices block
  advancement.
- TEST-003 requires all currently selectable optional opportunities to be
  presented when game rules allow choice order.

#### Current reality

Tarkin is a single public prompt. ECM Status Phase can have multiple ECM
sources. H9 will require a timing-window-oriented modifier UI rather than an
H9-specific prompt.

#### Problem

CON-005 must prevent deterministic ordering from becoming hidden automatic
choice selection.

#### Options

Option A: Always resolve opportunities in deterministic sorted order.

Option B: Use deterministic ordering only for stable presentation,
comparison, mandatory rule-prescribed ordering, and accepted automation. When
rules grant choice, the controlling player selects exactly one opportunity to
resolve next.

#### Consequences

Option A violates ADR-005 for optional player-controlled choices.

Option B preserves player agency and replay determinism.

#### Recommendation

Choose Option B.

CON-005 should require wrong-player, stale-player, and observer-only
submissions to be rejected by both command applicability and concrete command
validation.

Accepted owner decision: each active timing window has exactly one
authoritative current controller. Each timing-window type declares a narrow
control policy that determines the current controller from authoritative
lifecycle state. Version 1 supports fixed-controller windows and
lifecycle-stage-derived controller windows. Alternating priority, pass-based
priority, simultaneous multi-player control, rule-specific controller
callbacks, and generic priority engines are excluded until concrete evidence
requires a focused CON-005 revision.

### 6.7 Rule Command Obligations

#### Accepted constraints

Commands remain the only replayable mutation surface. Rule commands mutate
rule-specific state and effects but do not decide timing-window completion.
Continuation commands validate and mutate their own continuation.

#### Repository evidence

- `TarkinChoiceCommand`, `UseECMCommand`, `DeclineECMCommand`,
  `ReadyECMCommand`, and `DeclineECMReadyCommand` are replayable commands.
- `CommitDefenseCommand` and `SpendDefenseTokenCommand` show that marker and
  mutation commands may both need rule-surface coverage.
- `FlowSpec.allowed_commands`, `CommandApplicability`, and concrete
  `validate()` functions all gate commands.
- `GameCommand.serialize()` records command payload and sequence for replay and
  network.

#### Current reality

Command coverage is strong but specific. There is no shared timing-window
command contract for use/decline/effect/marker/continuation relationships.

#### Problem

CON-005 must ensure all command paths that can express an illegal timing-window
action are covered.

#### Options

Option A: Only final mutation commands need timing-window legality.

Option B: Use, decline, marker, mutation, effect, follow-up, and continuation
commands must each be registered, serializable, replayable where applicable,
and validated consistently with `FlowSpec` and `CommandApplicability`.

#### Consequences

Option A repeats defects where marker commands bypassed final mutation rules.

Option B fits the rule-integration skill and TEST-003.

#### Recommendation

Choose Option B.

CON-005 should require:

- command payload identity sufficient for replay without UI,
- concrete `validate()` agreement with `FlowSpec.allowed_commands` and
  `CommandApplicability`,
- stale-window and stale-source rejection,
- wrong-player rejection,
- repeated-use and repeated-decline rejection,
- network sequence compatibility,
- no command-local timing-window completion,
- explicit decline commands for every optional blocking opportunity.

Accepted owner decision: every optional blocking opportunity provides both a
replayable Use command and a replayable Decline command. No implicit decline
semantics are permitted for optional blocking opportunities.

### 6.8 Continuation Obligations

#### Accepted constraints

After each successful opportunity command, the orchestrator re-derives
opportunities. If blocking opportunities remain, the window stays open. If no
blocking opportunities remain, the orchestrator submits or enables the existing
replayable continuation command. The continuation command validates and
performs the authoritative mutation.

#### Repository evidence

- `StartRoundCommand` is the replayable continuation from Status to Command and
  validates unresolved ECM choices.
- `confirm_attack_dice` is the normal continuation from `ATTACK_MODIFY` in
  H9 CAP.
- Tarkin currently transitions to ship selection after `tarkin_choice`.
- Network ordering bugs showed that continuation must not overtake earlier
  authoritative commands.

#### Current reality

Continuation can be automatic or player-enabled depending on flow. The
architecture requires one orchestrating owner either way.

#### Problem

CON-005 must govern continuation without forcing one user-experience shape for
all windows.

#### Options

Option A: The orchestrator always auto-submits continuation.

Option B: The orchestrator owns the completion decision and the timing-window
contract states whether completion auto-submits the existing continuation
command or enables it for the appropriate controller.

Option C: UI decides when no opportunities remain and submits continuation.

#### Consequences

Option A is too rigid for windows where a player confirmation command remains
the legal exit.

Option B matches ADR-005 wording and current examples.

Option C conflicts with non-authoritative UI.

#### Recommendation

Choose Option B.

CON-005 should require:

- continuation derived from timing-window identity, authoritative lifecycle
  context, and current authoritative game state,
- a canonical continuation mapping defined by the immutable static
  timing-window definition owned by the shared timing-window module,
- exact-one-continuation after completion,
- re-derivation immediately before continuation is submitted or enabled,
- duplicate continuation prevention,
- no continuation after rejected opportunity commands,
- continuation failure leaves the window authoritative and visible,
- replay/network ordering where continuation follows all prior opportunity
  commands.

Accepted owner decision: `TimingWindowState` shall not serialize continuation
commands, payloads, or descriptors. Continuation belongs to the timing window,
not to any participating rule, and continuation commands always pass normal
applicability and validation. Future continuation descriptors remain deferred
until concrete evidence requires them.

### 6.9 Projection And Interaction Obligations

#### Accepted constraints

Projection is derived, UI is presentation only, and projection payload cannot
authorize gameplay. The live route must use the accepted authoritative
submission path.

#### Repository evidence

- `UIProjector` derives `UIIntent` from state and viewer identity.
- `ModalRouter` consumes modal kinds and dispatches command submissions.
- The ECM modal bug occurred because the live route bypassed the continuation
  helper.
- `InteractionFlow.payload` is serialized and filtered but must not become
  rule truth.

#### Current reality

Projection works as a derived surface but can become risky when live UI paths
submit through generic paths that do not preserve timing-window continuation.

#### Problem

CON-005 must define live interaction obligations that are strong enough for
TEST-003 without making UI authoritative.

#### Options

Option A: Projection payloads can be trusted if they came from serialized
state.

Option B: Projection payloads are reconnect/display hints only; commands must
validate against authoritative state and the live route must submit through the
orchestrator-owned path.

#### Consequences

Option A can resurrect stale opportunities.

Option B matches accepted architecture and known defect repairs.

#### Recommendation

Choose Option B.

CON-005 should require:

- JSON-safe projection payloads,
- viewer-specific projection where needed,
- stale projection rejection,
- no UI-local rule legality,
- modal/router construction-path smoke evidence for live interactive rules,
- use and decline dispatch through the authoritative timing-window submission
  path,
- missing projection cannot make gameplay state legal or illegal.

No Project Owner architecture decision remains here. TEST-003 already requires
live-route evidence, and CON-005 can translate that evidence category into an
implementation obligation without reopening architecture.

### 6.10 Visibility And Information Filtering Obligations

#### Accepted constraints

ADR-003 and CON-003 make hidden information and visibility a responsibility
surface. TEST-003 requires owner-only, opponent-hidden, observer/spectator,
reconnect, serialization, replay, network, and filtering evidence where
applicable.

#### Repository evidence

- `InteractionFlow.visible_to` exists and is filtered by `StateFilter`.
- Tarkin, ECM, and H9 are public in their CAPs.
- Command dial contents remain private by payload/filtering, not by making
  flow authority private.

#### Current reality

The pilot upgrades are public, but future timing-window rules may include
private or owner-only choices.

#### Problem

CON-005 must distinguish authoritative state from transport and projection
filtering.

#### Options

Option A: Projection filtering can also decide command authorization.

Option B: Visibility filtering remains derived; command authorization is
validated from authoritative state and player identity, independent of hidden
UI data.

#### Consequences

Option A risks hidden-information leaks and UI-authority bugs.

Option B preserves authority boundaries.

#### Recommendation

Choose Option B.

CON-005 should require timing-window participants to classify:

- authoritative state visibility,
- projection visibility,
- command payload visibility,
- reconnect projection filtering,
- observer/spectator handling,
- whether hidden information is ever required in a submitted command payload.

No Project Owner architecture decision remains here. CON-005 can require the
classification categories while CAPs provide rule-specific visibility evidence
under TEST-003.

### 6.11 Serialization And Reconstruction Obligations

#### Accepted constraints

Authoritative state may serialize; opportunities are re-derived; projection
remains derived. Save/load and reconnect must not resurrect stale
opportunities.

#### Repository evidence

- `GameState.serialize()` serializes current phase, player states,
  `interaction_flow`, RNG, damage deck, and other state.
- `ShipInstance.serialize()` serializes `runtime_upgrades`.
- `InteractionFlow.serialize()` serializes derived payload.
- `SaveGameManager` signs and loads serialized game state.

#### Current reality

There is no serialized `TimingWindowState`. Existing serialized flow payloads
support reconnect but are not enough to own lifecycle.

#### Problem

CON-005 must define what must serialize and what must be re-derived.

#### Options

Option A: Serialize active opportunities as the primary source.

Option B: Serialize timing-window lifecycle semantics and rule-specific
authoritative state; re-derive opportunity sets and projection.

#### Consequences

Option A conflicts with ADR-005.

Option B matches accepted architecture and supports save/load/reconnect.

#### Recommendation

Choose Option B.

CON-005 should require serialization of:

- active timing-window identity,
- timing point or lifecycle interval,
- controlling or priority context where needed,
- continuation context sufficient to resume the lifecycle,
- cancellation/replacement epoch where needed,
- any rule-specific state on existing authoritative owners.

CON-005 should prohibit serialization of:

- mutable opportunity queues as authority,
- static component metadata copies,
- UI-local state as legality.

Accepted owner decision: serialized `TimingWindowState` participates in the
repository's existing authoritative compatibility/versioning mechanism.
CON-005 Version 1 shall not require a dedicated `TimingWindowState` version
field or timing-window-specific migration subsystem by default. If no
authoritative compatibility/versioning mechanism exists, Codex shall report the
gap for explicit architectural resolution before adding serialized
`TimingWindowState`.

### 6.12 Replay Obligations

#### Accepted constraints

Commands and command history remain replayable. Replay must reconstruct
opportunity availability from authoritative state and command history, not UI
state.

#### Repository evidence

- `GameCommand.serialize()` includes command type, player, sequence, and
  payload.
- `CommandProcessor.serialize_history()` serializes ordered history.
- Tarkin and ECM commands serialize rule choices and authorizations.
- TEST-003 requires use, decline, mutation, and continuation commands in
  authoritative order.

#### Current reality

Replay is command-history driven. There is no generic replay initialization for
active `TimingWindowState` yet.

#### Problem

CON-005 must make replay deterministic during active windows and inter-command
states.

#### Options

Option A: Replay active windows only through serialized `InteractionFlow`.

Option B: Replay command history into serialized authoritative state,
including `TimingWindowState` and rule-specific owners, then re-derive
opportunities and projection.

#### Consequences

Option A depends on projection state.

Option B fits ADR-005 and TEST-003.

#### Recommendation

Choose Option B.

CON-005 should require:

- explicit command-history ordering for use, decline, mutation, marker, and
  continuation commands,
- replay reconstruction during unresolved windows,
- inter-command state evidence where one command authorizes a later command,
- duplicate continuation prevention during replay,
- no replay dependence on UI-local state.

No Project Owner architecture decision remains here. CON-005 should require
deterministic replay reconstruction while leaving concrete open/close command
shape to contract drafting unless it materially affects authority.

### 6.13 Network And Reconnect Obligations

#### Accepted constraints

Authoritative peers produce commands; clients mirror command results in server
sequence order; clients do not synthesize rule use, decline, effect, or
continuation commands locally.

#### Repository evidence

- `NetworkManager` broadcasts command results.
- `NetworkCommandSubmitter` distinguishes local accepted/pending results from
  remote authoritative results.
- Network ordering repairs established that later results must buffer until
  earlier server sequences are applied.
- `StateFilter` and `UIProjector` support reconnect and viewer-specific
  projection.

#### Current reality

Network command sequencing exists, but timing-window-specific obligations are
spread across current tests and command handlers.

#### Problem

CON-005 must prevent host/client divergence in timing windows.

#### Options

Option A: Clients may synthesize continuation when their local projection shows
no opportunities remain.

Option B: Only the authoritative peer submits opportunity, effect, and
continuation commands; clients mirror authoritative results in sequence and
project from mirrored state.

#### Consequences

Option A risks duplicate continuation and divergence.

Option B matches accepted network authority.

#### Recommendation

Choose Option B.

CON-005 should require:

- authoritative peer ownership of command production,
- no client-local synthesis of use, decline, effect, or continuation commands,
- sequence-order mirror application,
- remote command-effect classification for every mirrored command in the
  protocol,
- reconnect reconstruction from serialized authoritative state plus derived
  projection,
- command-history and mirror comparison in protocol tests.

Accepted owner decision: CON-005 defines network-independent timing-window
protocol invariants only. Transport protocols, RPC mechanisms, packet ordering
and delivery strategies, reliability, retransmission, serialization formats,
latency handling, and engine-specific networking APIs belong in a dedicated
networking contract or implementation.

### 6.14 Cleanup And Failure Obligations

#### Accepted constraints

Temporary timing-window state must have one authoritative owner, explicit
creation, mutation, and cleanup/removal points, and cleanup on accepted exit,
cancellation, replacement, attack end, phase transition, or CAP-defined
triggers.

#### Repository evidence

- `StartRoundCommand` clears ECM Status Phase ready-cost guards on successful
  continuation.
- ECM helper methods clear stale ready-cost guards and attack-time pending
  authorizations.
- H9 CAP requires current-attack guard cleanup on `confirm_attack_dice`, attack
  end, cancellation, flow replacement, or explicit exit from
  `ATTACK_MODIFY`.
- TEST-003 requires rejected commands not to trigger continuation.

#### Current reality

Cleanup is currently rule-specific and command-specific. Shared timing-window
state cleanup does not exist yet.

#### Problem

CON-005 must define cleanup ownership without moving rule-specific state into
shared lifecycle state.

#### Options

Option A: The orchestrator clears all rule-specific state.

Option B: The orchestrator clears shared timing-window lifecycle state.
Rule-specific mutable or temporary state is cleaned only through explicit
authoritative and replayable command paths owned by the applicable rule or
enclosing game-flow lifecycle.

Option C: Each UI route clears state when it closes.

#### Consequences

Option A violates ADR-004 and CAP ownership for upgrade runtime state.

Option B preserves shared lifecycle ownership and rule-state boundaries.

Option C conflicts with non-authoritative UI.

#### Recommendation

Choose Option B.

CON-005 should require:

- cleanup owner for shared `TimingWindowState`,
- cleanup triggers for normal exit, cancellation, replacement, phase
  transition, attack end, round transition, save/load reconstruction outside
  the window, reconnect outside the window, and rejected/partial-failure paths,
- rule-specific cleanup through the rule's replayable Use command, replayable
  Decline command, rule-owned replayable follow-up command, or existing
  replayable lifecycle command that owns the relevant boundary,
- repeated cleanup idempotence,
- unresolved required guards must not be cleared by repeated cleanup before the
  window exits,
- projection cleanup follows authoritative cleanup and cannot lead it.

Accepted owner decision: every cleanup mutation has a single authoritative
command owner. The orchestrator shall not rely on implicit observers,
arbitrary callback cleanup, orchestrator-owned capability-specific cleanup
logic, or generic cleanup frameworks that mutate rule-owned state. Dedicated
cleanup commands are allowed only when no existing authoritative command can
safely own the cleanup.

### 6.15 Rule-Specific State Boundary

#### Accepted constraints

ADR-004 and CON-004 keep runtime upgrade state on the runtime upgrade instance.
ADR-005 timing-window state owns lifecycle only and does not absorb
rule-specific mutable state.

#### Repository evidence

- Tarkin once-per-Ship-Phase guard lives in the Tarkin runtime upgrade
  instance.
- ECM attack-time pending authorization and Status Phase ready-cost guard live
  in ECM runtime upgrade `rule_state`.
- H9 CAP requires current-attack used/declined guard in H9 runtime upgrade
  `rule_state`.

#### Current reality

Pilot rules already use runtime upgrade `rule_state` for mutable upgrade-owned
state. Shared timing-window lifecycle state does not exist.

#### Problem

CON-005 must prevent timing-window implementation from absorbing rule-specific
state.

#### Options

Option A: TimingWindowState stores all temporary state needed for active
opportunities.

Option B: TimingWindowState stores lifecycle facts only; rule-specific
participants store mutable rule state on existing owners and expose derived
opportunities from those owners.

#### Consequences

Option A conflicts with ADR-004/CON-004 and CAP evidence.

Option B preserves accepted ownership.

#### Recommendation

Choose Option B.

CON-005 should explicitly state that:

- costs,
- use/decline guards,
- pending authorizations,
- card readiness/exhaustion,
- selected dice/tokens/zones,
- effect results,
- rule-specific cleanup state

belong to rule-specific owners unless a later CAP documents an exception.

No Project Owner architecture decision remains here. The accepted serialization
decision limits shared `TimingWindowState` to authoritative lifecycle
semantics; rule-specific mutable state remains on existing owners.

### 6.16 Shared Protocol Suites And CAP Scaling

#### Accepted constraints

TEST-003 requires every timing-window CAP to include or reference a
verification matrix. Missing applicable evidence means the implementation is
incomplete.

#### Repository evidence

- Current Tarkin and ECM coverage includes command, modal, projection,
  save/load, replay, reconnect, network, and remote-effect tests.
- TEST-003 allows shared protocol evidence but does not allow missing
  CAP-specific evidence.
- The rule-integration skill requires command-sequence audits comparing
  expected, hot-seat, network host, and network client sequences.

#### Current reality

Tests are mostly rule-specific. Shared timing-window protocol suites do not
exist yet.

#### Problem

CON-005 should scale to many rules without duplicating every infrastructure
test in every CAP.

#### Options

Option A: Every CAP must duplicate every timing-window protocol test.

Option B: CON-005 permits shared protocol suites for common lifecycle
obligations, while each CAP supplies rule-specific deltas, fixtures,
visibility classification, and smoke evidence.

#### Consequences

Option A does not scale to 100+ rules.

Option B preserves TEST-003 evidence categories and keeps CAP-specific
responsibility.

#### Recommendation

Choose Option B.

CON-005 should require CAPs to identify which evidence is satisfied by shared
protocol suites and which remains rule-specific.

Accepted owner decision: shared timing-window protocol suites may be
referenced only for matching protocol obligations, and every CAP must still
provide capability-specific evidence for rule correctness, legality,
mutation, cleanup, visibility, interaction, invariants, failure paths, and
runtime smoke evidence where TEST-003 requires it.

### 6.17 Nested Timing Window Version 1 Posture

#### Accepted constraints

ADR-005 explicitly defers exact nested timing-window mechanics and whether
nested windows are supported in the first implementation.

ADR-005 still requires one authoritative lifecycle owner for an active timing
window, re-derivation after each successful opportunity command, and
continuation only after blocking opportunities are resolved.

TEST-003 requires active windows to survive save/load, replay, network mirror,
and reconnect, and requires cleanup on continuation, cancellation, replacement,
or other accepted exit paths.

#### Repository evidence

- Current Tarkin, ECM Status Phase, and H9 evidence all involve one active
  timing window at a time.
- Current `GameState` has one `interaction_flow`.
- No current implementation evidence shows a stack of simultaneously active
  timing-window lifecycles.
- `docs/game_flow.md` records adjacent and replacement-style flows, but not a
  nested timing-window protocol.

#### Current reality

The repository has no established nested timing-window state, serialization,
replay, network, reconnect, projection, or cleanup protocol.

Adjacent windows and follow-up flows exist, but they are not evidence of a
general nested lifecycle model.

#### Problem

CON-005 Version 1 needs a clear posture so implementation does not invent
nested behavior while translating ADR-005 into a narrow lifecycle contract.

#### Options

Option A: CON-005 Version 1 supports nested timing windows.

Option B: CON-005 Version 1 explicitly prohibits nested timing windows. Opening
a second timing window while one is active is invalid unless the current window
is first closed, cancelled, or replaced through a documented replacement path.

Option C: CON-005 Version 1 allows nested windows only for H9 or ECM if a CAP
needs them.

#### Consequences

Option A requires defining stack semantics, parent/child continuation,
serialization, replay, network ordering, reconnect projection, cleanup, and
failure handling. That would broaden CON-005 beyond the current evidence.

Option B preserves ADR-005, keeps Version 1 narrow, and prevents accidental
implicit nesting. It still allows later architecture to define nested mechanics
explicitly.

Option C would create rule-specific nested semantics before shared ownership is
defined and risks CAP-local architecture drift.

#### Recommendation

Choose Option B for CON-005 Version 1.

CON-005 should state that nested timing windows are deferred for the first
implementation. A timing-window opener must reject or surface invalid state
when another timing window is active unless the operation is an explicit
documented replacement, cancellation, or close-and-open transition.

This recommendation does not define nested timing-window architecture. It only
sets the Version 1 implementation posture.

Accepted owner decision: CON-005 Version 1 shall prohibit multiple
simultaneously active timing windows. A new timing window may begin only after
the current timing window has been explicitly completed, cancelled, replaced,
or closed. Supported transitions are close-and-open next window, cancel to a
replacement window, and replacement of the active window. Parent/child
hierarchies, recursive stacks, and concurrent active windows are excluded.

### 6.18 Migration And Pilot Readiness

#### Accepted constraints

This workbook must not create a migration plan. It should identify decisions
needed before auditing ECM/Tarkin, refactoring ECM/Tarkin, or implementing H9
as a clean pilot.

#### Repository evidence

- Tarkin is integrated but has command-local continuation for the current
  single opportunity shape.
- ECM is draft and includes both attack-time and Status Phase timing-window
  behavior.
- H9 is draft and intentionally depends on a timing-window-oriented Attack
  Modify UI and protocol.
- ADR-005 and TEST-003 are accepted, but CON-005 is not yet drafted.

#### Current reality

H9 is the best clean pilot candidate because it is not implemented yet and its
CAP already requires multiple optional modifier coexistence, recalculation,
player choice, and `confirm_attack_dice` continuation.

#### Problem

CON-005 must be clear enough before new timing-window implementation begins.

#### Options

Option A: Implement H9 before CON-005 to discover obligations in code.

Option B: Draft CON-005 after owner decisions on this workbook, then use H9 as
the first clean pilot and audit existing ECM/Tarkin against the new contract.

#### Consequences

Option A risks repeating ECM/Tarkin integration defects.

Option B follows the architecture workflow and avoids redesigning during
implementation.

#### Recommendation

Choose Option B.

Accepted owner decisions now cover:

- minimum `TimingWindowState` semantic information,
- continuation representation,
- participant discovery boundary,
- opportunity descriptor minimum,
- explicit decline obligations,
- window controller policy,
- cleanup ownership boundary,
- static timing-window definition ownership,
- serialized compatibility/versioning posture,
- network protocol boundary,
- shared protocol suite scope,
- nested timing-window Version 1 posture.

First migration or pilot selection remains later migration planning rather than
a CON-005 architecture decision.

#### Owner decision status

No Project Owner architecture decision is required in this workbook. First
pilot selection is migration planning and should be decided after CON-005 is
accepted.

### 6.19 Static Timing-Window Definition Ownership

#### Accepted constraints

ADR-005 assigns runtime lifecycle execution to the Timing Window Orchestrator
and keeps `RuleRegistry`, `InteractionFlow`, `FlowSpec`, `UIProjector`, CAPs,
rule implementations, and UI non-authoritative for timing-window lifecycle
policy.

#### Repository evidence

- `FlowSpec` currently stores flow-step metadata and allowed-command rows.
- `RuleRegistry` currently stores static rule hook/candidate information but
  does not own active rule truth.
- TIM-002 Decision 2 already relies on a timing-window definition for canonical
  continuation mapping.

#### Current reality

TIM-002 relied on static timing-window definitions but did not explicitly name
their owner or exclude competing policy locations.

#### Problem

CON-005 needs exactly one owner for static timing-window policy so Codex does
not add policy to `FlowSpec`, `RuleRegistry`, CAPs, rule implementations, or a
new abstraction layer.

#### Options

Option A: Store timing-window lifecycle policy in `FlowSpec`, CAPs, rule
implementations, or per-window helper code as needed.

Option B: Require one immutable static definition table owned by the shared
timing-window module and consumed directly by the Timing Window Orchestrator.

Option C: Introduce a catalog service, provider interface, strategy hierarchy,
dependency injection surface, plugin system, separate registry, runtime
definition objects, or other abstraction layer for timing-window definitions.

#### Consequences

Option A leaves competing lifecycle-policy owners and conflicts with ADR-005.

Option B resolves the ownership ambiguity with the smallest
repository-consistent static mapping and no new architecture layer.

Option C broadens the architecture before evidence proves a need.

#### Recommendation

Choose Option B.

CON-005 Version 1 should require one canonical immutable static definition for
each timing-window type. Each definition may contain only static policy
equivalent to:

- timing-window identity,
- supported lifecycle stages,
- control-policy kind,
- RuleRegistry participant-index key,
- canonical continuation mapping,
- permitted completion,
- permitted cancellation,
- permitted replacement,
- permitted close-and-open transitions.

The definition shall never contain runtime legality, derived opportunities,
player choices, rule-specific mutation, rule-specific cleanup, mutable state,
visibility results, runtime completion decisions, arbitrary callbacks, or
extension payloads.

Accepted owner decision: static timing-window definitions are owned by the
shared timing-window module and consumed directly by the Timing Window
Orchestrator. `FlowSpec`, `RuleRegistry`, CAPs, and rule implementations shall
not define competing timing-window lifecycle policy. If future evidence proves
the static mapping insufficient, any additional abstraction requires explicit
architectural revision.

## 7. Cross-Cutting Recommended Decisions

Recommended for CON-005:

1. Define CON-005 as an implementation-obligation contract derived from
   ADR-005 and TEST-003, not as an authority restatement.
2. Require `GameState`-owned serialized `TimingWindowState` with lifecycle
   semantics only.
3. Require a narrow orchestrator that owns lifecycle, discovery orchestration,
   recalculation, continuation, and shared lifecycle cleanup.
4. Require one immutable static timing-window definition table owned by the
   shared timing-window module and consumed directly by the Timing Window
   Orchestrator.
5. Use RuleRegistry as the only Version 1 participant-candidate source, while
   keeping RuleRegistry non-authoritative.
6. Exclude explicit local call-site participant lists, provider abstractions,
   discovery strategy layers, and speculative extension interfaces from
   Version 1.
7. Require opportunities to be re-derived from authoritative runtime state and
   represented by the accepted canonical derived opportunity record.
8. Require all use, decline, marker, mutation, effect, and continuation
   commands in a timing-window protocol to be registered, serializable,
   replayable where applicable, and mutually consistent across
   `FlowSpec.allowed_commands`, `CommandApplicability`, and concrete
   validation.
9. Require every optional blocking opportunity to provide explicit replayable
   Use and Decline commands.
10. Require one authoritative current controller determined by the timing-window
   type's narrow control policy.
11. Require continuation to be derived from timing-window identity,
    authoritative lifecycle context, and current authoritative game state, and
    to occur exactly once after recalculation proves no blocking opportunities
    remain.
12. Require projection and live UI routes to remain derived and route through
    authoritative timing-window submission.
13. Require shared lifecycle state, rule-specific state, and projection payload
    to remain separate.
14. Require network clients to mirror authoritative commands in sequence and
    never synthesize use, decline, effect, or continuation commands locally.
15. Reuse the repository's existing authoritative serialization-compatibility
    mechanism and reject, reconstruct, or migrate unsupported state
    deterministically.
16. Permit shared protocol suites for common evidence while keeping CAP-specific
    rule deltas mandatory.
17. Defer nested timing-window mechanics in Version 1 and reject or surface
    attempts to open a second active window unless the active window is
    explicitly replaced, cancelled, or closed first.

Alternatives rejected:

- making `InteractionFlow` or `UIProjector` authoritative,
- making `RuleRegistry` decide runtime eligibility or continuation,
- storing serialized mutable opportunity queues,
- letting individual rule commands decide whole-window completion,
- letting modal routers or UI decide completion,
- moving rule-specific mutable state into `TimingWindowState`,
- requiring a full generic rule engine or effect-composition engine.

## 8. Owner Q&A

The Project Owner decision memo resolves the Owner questions previously listed
in this section.

Accepted decisions integrated here:

1. `TimingWindowState` serializes only authoritative lifecycle semantics.
2. Continuation is derived from the timing-window definition and authoritative
   lifecycle context; `TimingWindowState` does not serialize continuation
   commands, payloads, or descriptors.
3. RuleRegistry is the only Version 1 participant-candidate source and remains
   non-authoritative.
4. Interactive opportunities use the accepted canonical derived opportunity
   record with canonical command intents.
5. Every optional blocking opportunity has explicit replayable Use and Decline
   commands.
6. Each active timing window has exactly one authoritative current controller
   determined by a narrow timing-window control policy.
7. CON-005 Version 1 prohibits multiple simultaneously active timing windows,
   except for explicit completion, cancellation, replacement, or close-and-open
   transitions.
8. Cleanup mutations use explicit authoritative command paths, and each owner
   cleans only its own state.
9. CON-005 defines network-independent timing-window protocol invariants; low
   level networking mechanics remain outside CON-005.
10. `TimingWindowState` uses the repository's existing authoritative
    serialization-compatibility/versioning mechanism unless evidence proves it
    insufficient.
11. Shared protocol evidence may be referenced, but every CAP must still prove
    its rule-specific correctness.
12. Static timing-window definitions are owned by the shared timing-window
    module, consumed directly by the Timing Window Orchestrator, and
    implemented as the smallest repository-consistent immutable static mapping.

No remaining Owner decision is required in TIM-002 before CON-005 drafting.
Concrete names, field names, production APIs, and migration sequencing remain
deferred implementation or contract-authoring details.

## 9. Contract Readiness Assessment

Assessment: Ready for Architecture Audit.

Rationale:

- ADR-005 and TEST-003 are accepted and provide stable authority.
- Current implementation evidence identifies the main contract gaps without
  showing an implementation impossibility.
- The recommended decisions preserve ADR-003, ADR-004, CON-003, and CON-004.
- Accepted Owner decisions resolve the implementation-contract questions
  needed before drafting CON-005.

No existing architecture contradiction was found.

## 10. Deferred Details For CON-005 Or Later Work

The following details should not be finalized in this workbook:

- exact `TimingWindowState` field names,
- exact immutable static timing-window definition field names,
- concrete participant interface signatures,
- concrete RuleRegistry APIs,
- orchestrator class structure,
- migration sequencing,
- nested timing-window mechanics beyond the Version 1 posture,
- production test implementation names,
- effect-composition semantics,
- H9 implementation details,
- ECM or Tarkin refactor plan.

## 11. Summary

TIM-002 now records the accepted owner decisions for a narrow implementation
contract: shared timing-window lifecycle state and orchestration should be
standardized, while rule-specific mutable state, rule effects, and capability
evidence remain owned by existing authoritative surfaces.

This is enough to proceed toward CON-005 drafting through the normal
architecture workflow.

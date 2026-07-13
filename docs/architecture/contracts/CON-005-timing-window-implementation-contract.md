# CON-005: Timing Window Implementation Contract

Contract ID: CON-005
Title: Timing Window Implementation Contract
Derived From: ADR-005, TIM-002, TEST-003
Related ADRs: ADR-003, ADR-004, ADR-005
Related Contracts: CON-003, CON-004
Related Tests: TEST-003
Related Evidence: TIM-001, TIM-002, CAP-UPG-001, CAP-ECM-001, CAP-H9-001
Owner: Project Owner accepted on 2026-07-13

Status: Accepted

After completing:

* architecture audit,
* targeted refinement,
* final targeted verification,
* and Project Owner review,

I accept CON-005 – Timing Window Implementation Contract as the authoritative implementation contract for timing-window capabilities governed by ADR-005.

CON-005 faithfully translates the accepted architecture and the twelve accepted TIM-002 Owner decisions into normative implementation obligations.

The contract establishes mandatory requirements for:

* TimingWindowState ownership and serialization;
* lifecycle identity and stale-command rejection;
* Timing Window Orchestrator responsibilities;
* immutable static timing-window definitions;
* RuleRegistry-only participant discovery for Version 1;
* canonical opportunity records and command intents;
* controller policy and player-controlled ordering;
* explicit replayable Use and Decline commands;
* continuation derivation, execution, and failure behavior;
* cleanup ownership and trigger coverage;
* projection and visibility boundaries;
* save/load, replay, reconnect, and serialization compatibility;
* network-independent multiplayer invariants;
* shared protocol evidence and CAP-specific correctness evidence;
* deterministic failure and duplicate-handling behavior.

I confirm that CON-005:

* preserves ADR-005 authority boundaries;
* remains consistent with ADR-003, ADR-004, CON-003, CON-004, and TEST-003;
* introduces no generic rule engine, priority engine, provider framework, cleanup framework, or additional abstraction layer;
* provides a deterministic and scalable implementation foundation for more than 100 timing-window capabilities;
* is ready to govern audits, migrations, refactors, and new implementations.

CON-005 is therefore accepted as the normative implementation contract for timing-window behavior.

Future timing-window implementations shall conform to CON-005 and provide the applicable TEST-003 evidence through their Rule Capability Packages.

Any future change that alters the accepted ownership model or timing-window architecture requires the normal architecture decision process rather than being introduced during implementation.

## Draft Note

This contract translates accepted timing-window architecture into mandatory
implementation obligations.

It does not decide new architecture. ADR-005 is the normative architecture
source for timing-window ownership and continuation. TIM-002 records accepted
implementation decisions that prepare this contract. TEST-003 defines the
mandatory verification architecture.

## 1. Purpose

CON-005 defines the implementation obligations required for timing-window
implementations to conform to ADR-005 and satisfy TEST-003.

This contract covers:

- authoritative timing-window lifecycle state,
- timing-window orchestration,
- static timing-window definitions,
- participant discovery,
- opportunity derivation,
- controller policy,
- use and decline protocols,
- continuation,
- cleanup,
- projection,
- visibility,
- serialization,
- replay,
- save/load,
- reconnect,
- networking invariants,
- Rule Capability Package obligations,
- TEST-003 evidence obligations,
- migration obligations for existing timing-window-like implementations.

## 2. Scope

### 2.1 In Scope

This contract applies to implementations that create, resolve, serialize,
project, replay, or mirror timing-window behavior.

It applies to rule capabilities whose behavior depends on player-visible or
command-resolved timing-window opportunities, including upgrade rules,
objectives, damage cards, squadron keywords, and future interactive rules.

### 2.2 Out Of Scope

This contract does not define:

- exact `TimingWindowState` field names,
- concrete class names,
- concrete API signatures,
- concrete RuleRegistry APIs,
- concrete participant interface signatures,
- transport-level networking mechanics,
- packet ordering or reliability mechanisms,
- effect-composition semantics,
- nested timing-window mechanics beyond the Version 1 posture defined here,
- implementation sequencing,
- migration scheduling,
- rollout approval.

Any item explicitly deferred by ADR-005 or TIM-002 remains outside CON-005
unless this contract states a mandatory invariant for it.

## 3. Relationship To Other Documents

### 3.1 ADR-005

ADR-005 defines the accepted architecture:

- timing windows are authoritative lifecycle objects,
- `TimingWindowState` is owned by `GameState`,
- the Timing Window Orchestrator owns lifecycle, discovery orchestration,
  recalculation, and continuation,
- commands remain the only replayable mutation surface,
- opportunities are derived from authoritative runtime state,
- RuleRegistry is a static participant index only,
- projection and UI surfaces are non-authoritative.

CON-005 implements those decisions as mandatory implementation obligations.

### 3.2 TIM-002

TIM-002 records accepted implementation decisions used to prepare CON-005.

CON-005 does not reopen TIM-002. Where this contract states Version 1
obligations, those obligations derive from TIM-002 owner decisions.

### 3.3 TEST-003

TEST-003 defines the mandatory verification architecture for interactive
timing-window capabilities.

CON-005 defines implementation obligations. TEST-003 defines evidence
categories. The accepted principle remains:

> Verification architecture owns evidence categories; implementation contracts
> own implementation obligations.

### 3.4 CON-003

CON-003 governs Rule Capability Packages.

Any CAP that participates in a timing window SHALL satisfy CON-003 and the
additional CAP obligations in this contract.

### 3.5 CON-004

CON-004 governs runtime upgrade instances.

Timing-window lifecycle state SHALL NOT absorb mutable runtime upgrade state
owned by CON-004 runtime upgrade instances. Upgrade-specific guards, costs,
card state, authorizations, and mutable effects remain on the accepted runtime
owner unless a later accepted contract explicitly changes that ownership.

## 4. Terms

**Timing window**: A game-flow interval in which one or more rule opportunities
may need to be resolved before the game may continue.

**TimingWindowState**: The authoritative serialized lifecycle state for the
currently active timing window. It is owned by `GameState`.

**Timing Window Orchestrator**: The implementation owner that opens timing
windows, coordinates participant discovery, re-derives opportunities, determines
whether blocking opportunities remain, enables or submits continuation, and
closes or replaces timing windows.

**Static timing-window definition**: The immutable shared timing-window policy
entry for a timing-window type.

**Rule opportunity**: A derived, non-authoritative description of a currently
eligible rule interaction within a timing window.

**Participant**: A rule capability candidate discovered through the accepted
static participant index.

**Continuation command**: The existing replayable command associated with
continuing after a timing window completes.

**Rule-specific state**: Mutable state owned by an existing authoritative owner,
such as a runtime upgrade instance, attack state, ship state, command-token
state, or another accepted rule owner.

**Timing-window command**: Any replayable command that acts inside, resolves,
continues, cancels, replaces, closes, or cleans up an active timing window,
including use commands, decline commands, marker commands, effect commands,
follow-up commands, cleanup commands, and continuation commands.

## 5. Normative Requirements

### 5.0 Contract-Wide Determinism Obligations

CON-005-DET-001: Whenever multiple implementation behaviors are possible,
CON-005 SHALL define one deterministic outcome for conforming timing-window
implementations.

CON-005-DET-002: Silent recovery, implementation-defined behavior,
best-effort guessing, local policy decisions, arbitrary selection, and implicit
fallbacks are prohibited unless CON-005 explicitly permits them.

CON-005-DET-003: When a timing-window implementation cannot safely proceed
under a defined obligation, it SHALL preserve authoritative state, surface a
diagnostic, and fail closed unless this contract defines a narrower outcome.

### 5.1 TimingWindowState Obligations

CON-005-STATE-001: `GameState` SHALL own authoritative timing-window lifecycle
state.

CON-005-STATE-002: At most one timing window SHALL be active in Version 1.
Multiple active timing windows, recursive timing-window stacks, and concurrent
parent/child timing windows are prohibited in Version 1.

CON-005-STATE-003: `TimingWindowState` SHALL represent lifecycle state only.
It SHALL NOT own rule-specific eligibility, costs, mutable effects, use guards,
decline guards, card state, token state, attack effects, or runtime upgrade
state.

CON-005-STATE-004: `TimingWindowState` SHALL include enough authoritative
semantic information to reconstruct the active lifecycle interval after
save/load, replay initialization, network reconnect, and mirrored command
application.

CON-005-STATE-005: Required semantic information includes the active
timing-window identity, lifecycle stage or timing point, active/inactive state,
and continuation context sufficient for the orchestrator to resume lifecycle
evaluation.

CON-005-STATE-005A: Required semantic information SHALL include sufficient
authoritative lifecycle identity to distinguish the currently active timing
window from a cancelled timing window, replaced timing window, closed timing
window, and a subsequently reopened timing window of the same timing-window
type.

CON-005-STATE-005B: CON-005 does not require a specific lifecycle-identity
implementation such as a UUID, integer epoch, generation counter, or exact
field name. It requires only the semantic ability to distinguish lifecycle
instances deterministically.

CON-005-STATE-006: If the current controller or priority owner cannot be
uniquely derived from the timing-window definition and authoritative game state,
`TimingWindowState` SHALL serialize the current controller or priority owner.

CON-005-STATE-007: `TimingWindowState` SHALL NOT serialize derived opportunity
queues, candidate participant lists, presentation order, UI state, modal state,
projection payloads, visibility results, RuleRegistry data, or rule-specific
mutable state.

CON-005-STATE-008: `TimingWindowState` SHALL support lifecycle replacement,
cancellation, and close-and-open transitions only where permitted by the static
timing-window definition.

CON-005-STATE-009: Repeated lifecycle initialization SHALL NOT create duplicate
active windows for the same unresolved lifecycle interval.

CON-005-STATE-010: Loading, replay initialization, or reconnect reconstruction
SHALL reject, surface as invalid, or fail closed when serialized timing-window
lifecycle state is inconsistent with the current authoritative game state.

CON-005-STATE-011: Save/load reconstruction, replay initialization, network
mirror application, and reconnect reconstruction SHALL preserve or reconstruct
the authoritative lifecycle identity needed to reject stale-window commands.

CON-005-STATE-012: If lifecycle identity cannot be reconstructed
deterministically, the timing-window state SHALL fail closed, preserve
authoritative rule-specific state, surface a diagnostic, and SHALL NOT
synthesize continuation.

### 5.2 TimingWindowOrchestrator Obligations

CON-005-ORCH-001: The Timing Window Orchestrator SHALL own opening timing
windows, closing timing windows, replacing timing windows, cancelling timing
windows, and coordinating lifecycle continuation.

CON-005-ORCH-002: The orchestrator SHALL coordinate participant discovery from
the accepted static participant index.

CON-005-ORCH-003: The orchestrator SHALL request or coordinate opportunity
derivation from rule-specific participants using authoritative serialized state.

CON-005-ORCH-004: The orchestrator SHALL re-derive all currently eligible
opportunities after every successful replayable command that resolves,
mutates, declines, or otherwise affects an opportunity in the active timing
window.

CON-005-ORCH-005: The orchestrator SHALL determine whether blocking
opportunities remain after re-derivation.

CON-005-ORCH-006: If blocking opportunities remain, the timing window SHALL
remain open.

CON-005-ORCH-007: If no blocking opportunities remain, the orchestrator SHALL
submit or enable the existing replayable continuation command associated with
that timing window according to the static timing-window definition.

CON-005-ORCH-008: The continuation command SHALL validate its own legality and
perform the authoritative mutation.

CON-005-ORCH-009: Individual rule commands, UI components, modal routers,
submission callers, and `CommandProcessor` SHALL NOT independently decide that
a timing window is complete.

CON-005-ORCH-010: The orchestrator SHALL prevent duplicate continuation for the
same completed timing-window interval.

CON-005-ORCH-011: The orchestrator SHALL NOT own rule effects, rule-specific
mutation, or rule-specific cleanup.

CON-005-ORCH-012: The orchestrator SHALL NOT be implemented as a generic rule
engine or a generic effect-composition engine.

CON-005-ORCH-013: The orchestrator SHALL recover deterministically after
save/load, replay initialization, reconnect, and mirrored command application by
using authoritative state and static definitions, not UI-local state.

### 5.3 Static Timing-Window Definition Obligations

CON-005-DEF-001: Version 1 SHALL use one canonical immutable static definition
for each timing-window type.

CON-005-DEF-002: Static timing-window definitions SHALL be owned by the shared
timing-window module and consumed directly by the Timing Window Orchestrator.

CON-005-DEF-003: Version 1 SHALL implement static definitions using the
smallest repository-consistent static mapping.

CON-005-DEF-004: CON-005 SHALL NOT require a catalog service, provider
interface, strategy hierarchy, dependency injection, plugin system, registry
distinct from RuleRegistry, runtime definition object, or additional
abstraction layer for timing-window definitions.

CON-005-DEF-005: A static timing-window definition MAY contain only static
policy equivalent to timing-window identity, supported lifecycle stages,
control-policy kind, RuleRegistry participant-index key, canonical continuation
mapping, permitted completion, permitted cancellation, permitted replacement,
and permitted close-and-open transitions.

CON-005-DEF-006: A static timing-window definition SHALL NOT contain runtime
legality, derived opportunities, player choices, rule-specific mutation,
rule-specific cleanup, mutable state, visibility results, runtime completion
decisions, arbitrary callbacks, or extension payloads.

CON-005-DEF-007: FlowSpec, RuleRegistry, CAPs, and rule implementations SHALL
NOT define competing timing-window lifecycle policy.

CON-005-DEF-008: Runtime legality, opportunity existence, controller
resolution, continuation eligibility, and completion SHALL be derived from
authoritative runtime state by the Timing Window Orchestrator.

CON-005-DEF-009: If future evidence proves that the static mapping is
insufficient, any additional abstraction SHALL require explicit architecture
revision.

### 5.4 Participant Discovery Obligations

CON-005-DISC-001: Version 1 participant discovery SHALL use RuleRegistry as the
only static participant candidate source.

CON-005-DISC-002: RuleRegistry SHALL remain a static participant index only.

CON-005-DISC-003: RuleRegistry SHALL NOT determine concrete runtime
eligibility, the current controlling player, player-selectable opportunity
order, timing-window completion, continuation, cleanup, visibility, or
authoritative mutation.

CON-005-DISC-004: RuleRegistry entries SHALL identify candidate participants by
capability identity and timing-window participation key.

CON-005-DISC-005: Participant discovery SHALL be deterministic.

CON-005-DISC-006: Discovery SHALL tolerate absent runtime sources by deriving no
opportunity for that source, mutating no state, and not continuing the timing
window solely because that candidate is missing. Continuation remains permitted
only when normal re-derivation proves that no blocking opportunities remain.

CON-005-DISC-007: Stale or invalid static registrations SHALL surface a
diagnostic, produce no opportunity, preserve authoritative state, and SHALL NOT
convert the registration into authoritative rule eligibility.

CON-005-DISC-008: Implementations SHALL NOT introduce local participant lists,
provider abstractions, strategy layers, plugin systems, or other discovery
frameworks unless later accepted architecture authorizes them.

CON-005-DISC-009: When participant discovery produces duplicate candidates for
the same capability identity and authoritative runtime-source identity, the
implementation SHALL deterministically suppress duplicates before opportunity
derivation. This suppression rule SHALL NOT alter runtime legality.

CON-005-DISC-010: Unknown participant types or unsupported participant types
SHALL fail closed, surface a diagnostic, present no opportunities for that
participant, preserve authoritative state, and SHALL NOT continue the timing
window because of that participant.

CON-005-DISC-011: Participant derivation failure SHALL preserve authoritative
timing-window state, surface the failure, and SHALL NOT synthesize
continuation or silently skip a blocking participant.

### 5.5 Opportunity Derivation Obligations

CON-005-OPP-001: Rule opportunities SHALL be derived from authoritative runtime
state.

CON-005-OPP-002: Opportunity identity SHALL be grounded in capability identity
and authoritative runtime-source identity.

CON-005-OPP-002A: The canonical opportunity identity SHALL consist of
capability identity, source-owner kind, authoritative runtime-source identity,
and stable semantic opportunity key.

CON-005-OPP-003: Opportunity identity SHALL NOT use synthetic persistent UUIDs
as an independent source of identity.

CON-005-OPP-004: An opportunity record SHALL be non-authoritative and SHALL NOT
be stored as a mutable queue.

CON-005-OPP-005: A derived opportunity SHALL include the minimum semantic
information needed for validation and projection: capability identity,
source-owner kind, authoritative runtime-source identity, stable semantic
opportunity key, controlling player identity, resolution kind, blocking status,
and registered replayable command intent for use and, when applicable, decline.

CON-005-OPP-006: Command intents in opportunity records SHALL reference
registered replayable command types and the minimum stable authoritative
identity context required to submit those commands.

CON-005-OPP-007: Opportunity records SHALL NOT contain mutable rule state,
stored legality decisions, authoritative player choice, continuation decisions,
visibility authority, arbitrary callbacks, or effect results.

CON-005-OPP-008: Legality SHALL be re-evaluated from authoritative state after
every accepted command that may affect the timing window.

CON-005-OPP-009: Stale opportunity selections SHALL be rejected by command
validation.

CON-005-OPP-010: Repeat use and repeat decline SHALL be rejected when the
rule-specific authoritative state indicates that the opportunity was already
resolved for the relevant lifecycle interval.

CON-005-OPP-011: Opportunity derivation SHALL support one rule invalidating
another, one rule creating a later opportunity, and state-dependent eligibility
changes.

CON-005-OPP-012: Presentation ordering MAY be deterministic for display and
replay comparison, but deterministic ordering SHALL NOT silently select an
optional opportunity for the player.

CON-005-OPP-013: If one derivation pass produces two or more opportunities with
the same canonical opportunity identity, the timing window SHALL fail closed.

CON-005-OPP-014: Duplicate derived opportunity identity failure SHALL present
no ambiguous opportunity, SHALL NOT continue the timing window, SHALL surface a
diagnostic, SHALL preserve authoritative state, and SHALL require correction
rather than silently selecting, merging, or discarding one opportunity.

### 5.6 Controller Policy Obligations

CON-005-CTRL-001: Each active timing window SHALL have one current controller
or a deterministic rule for deriving the current controller.

CON-005-CTRL-002: Version 1 SHALL support fixed-controller and
lifecycle-stage-derived controller timing windows.

CON-005-CTRL-003: Priority queues, pass histories, simultaneous multi-player
control, rule-specific controller callbacks, and generic priority engines are
outside Version 1 unless later accepted architecture authorizes them.

CON-005-CTRL-004: When game rules grant a player control over optional
opportunity order, projection SHALL present all currently selectable
opportunities for that player.

CON-005-CTRL-005: The system SHALL NOT select an optional opportunity merely
because it appears first in deterministic ordering.

CON-005-CTRL-006: Wrong-player submissions SHALL be rejected by applicability
and command validation.

CON-005-CTRL-007: Stale-controller submissions SHALL be rejected after
controller state changes.

CON-005-CTRL-008: Observer visibility SHALL NOT grant command authority.

### 5.7 Use And Decline Protocol Obligations

CON-005-PROT-001: Every optional blocking opportunity SHALL have an explicit
replayable use command and an explicit replayable decline command.

CON-005-PROT-002: Decline SHALL NOT be implicit for optional blocking
opportunities.

CON-005-PROT-003: Use and decline commands SHALL serialize all authoritative
identity needed to validate the selected opportunity from current authoritative
state.

CON-005-PROT-004: Use and decline commands SHALL be registered with the command
serialization, replay, applicability, and network mirror paths used by other
replayable commands.

CON-005-PROT-005: A use command SHALL mutate only the authoritative rule state,
cost state, or effect state that the relevant CAP and accepted contracts assign
to that rule.

CON-005-PROT-006: A decline command SHALL record an authoritative decline in
rule-owned state or another accepted owner when the opportunity must not be
re-offered during the same lifecycle interval.

CON-005-PROT-007: Use and decline commands SHALL NOT decide that the timing
window is complete.

CON-005-PROT-008: Marker, effect, and follow-up commands inside a timing window
SHALL preserve the same authority boundary: they mutate their own accepted
state and SHALL NOT independently perform lifecycle continuation.

CON-005-PROT-009: FlowSpec allowed commands, CommandApplicability, and concrete
command `validate()` SHALL agree for every timing-window command.

CON-005-PROT-010: Command validation SHALL reject wrong phase, wrong timing
window, wrong player, missing source, stale source, repeated use, repeated
decline, invalid cost, and stale opportunity selections.

CON-005-PROT-011: Every timing-window command SHALL validate against the
authoritative lifecycle identity of the active timing window.

CON-005-PROT-012: Stale-window commands SHALL be rejected deterministically.
This applies to use commands, decline commands, marker commands, effect
commands, follow-up commands, cleanup commands, and continuation commands.

CON-005-PROT-013: Rejected stale-window commands SHALL NOT mutate
authoritative state, clear lifecycle state, clean rule-owned temporary state,
trigger continuation, or update projection as if they had resolved an
opportunity.

### 5.8 Continuation Obligations

CON-005-CONT-001: Each timing-window type SHALL have a canonical continuation
mapping in its static timing-window definition.

CON-005-CONT-002: Continuation SHALL be associated with the timing window, not
with an individual participating rule.

CON-005-CONT-003: `TimingWindowState` SHALL NOT serialize continuation command
objects, command payloads, or mutable continuation descriptors.

CON-005-CONT-004: The orchestrator SHALL derive continuation from the static
timing-window definition, the lifecycle context, and current authoritative game
state.

CON-005-CONT-005: The continuation command SHALL remain a normal replayable
command and SHALL validate its own legality.

CON-005-CONT-006: The orchestrator SHALL submit or enable continuation only
after re-deriving opportunities and determining that no blocking opportunities
remain.

CON-005-CONT-007: The implementation SHALL enforce an exact-one-continuation
invariant for each completed timing-window interval.

CON-005-CONT-008: Rejected opportunity commands SHALL NOT trigger
continuation.

CON-005-CONT-009: UI, modal routing, command submission callers, rule commands,
and `CommandProcessor` SHALL NOT synthesize continuation independently.

CON-005-CONT-010: Network clients SHALL NOT synthesize continuation locally.
They SHALL mirror authoritative continuation commands.

CON-005-CONT-011: If continuation fails applicability, fails concrete
validation, fails submission, or cannot be constructed from the accepted static
timing-window definition and authoritative context, the current timing window
SHALL remain authoritative and active.

CON-005-CONT-012: Continuation failure SHALL NOT clear lifecycle state and
SHALL NOT execute cleanup that depends on successful continuation.

CON-005-CONT-013: After continuation failure, opportunities and projection
SHALL be re-derived from authoritative state, and the failure SHALL be
surfaced.

CON-005-CONT-014: Continuation failure SHALL NOT invent an alternative
continuation, synthesize a fallback continuation, submit duplicate
continuation, or automatically retry unless the static timing-window definition
explicitly permits a deterministic retry rule.

CON-005-CONT-015: Continuation SHALL still occur only after re-derivation
proves that no blocking opportunities remain.

### 5.9 Cleanup Obligations

CON-005-CLEAN-001: Every owner SHALL clean only the state it owns.

CON-005-CLEAN-002: The orchestrator SHALL clean shared timing-window lifecycle
state.

CON-005-CLEAN-003: Rule-specific temporary state SHALL be cleaned only by an
explicit authoritative replayable command path owned by the rule or enclosing
lifecycle.

CON-005-CLEAN-004: Preferred cleanup paths are rule use commands, rule decline
commands, rule follow-up commands, existing phase commands, existing attack
commands, existing round commands, existing action commands, cancellation
commands, replacement commands, and lifecycle commands.

CON-005-CLEAN-005: Dedicated cleanup commands MAY be introduced only when no
existing replayable command can own the cleanup without violating ownership.

CON-005-CLEAN-006: Implementations SHALL NOT rely on implicit lifecycle
observers, UI teardown, projection cleanup, modal closing, or non-replayable
callbacks to clean authoritative rule-specific state.

CON-005-CLEAN-007: A timing window SHALL NOT complete while rule-owned
temporary state remains unresolved when the relevant CAP or accepted contract
requires that state to be cleared before continuation.

CON-005-CLEAN-008: Cleanup SHALL be deterministic across hot-seat, replay,
save/load, reconnect, and network mirror paths.

CON-005-CLEAN-009: Repeated cleanup SHALL be idempotent or SHALL reject
deterministically without corrupting authoritative lifecycle or rule state.

CON-005-CLEAN-010: Projection cleanup SHALL NOT be treated as authoritative
cleanup.

CON-005-CLEAN-011: Every timing-window implementation and applicable CAP SHALL
define cleanup behavior for normal completion, including successful
continuation and explicit close.

CON-005-CLEAN-012: Every timing-window implementation and applicable CAP SHALL
define cleanup behavior for lifecycle transition triggers, including
cancellation, replacement, close-and-open, phase transition, attack end, round
transition, and action or enclosing flow completion where applicable.

CON-005-CLEAN-013: Every timing-window implementation and applicable CAP SHALL
define cleanup behavior for reconstruction and recovery triggers, including
save/load reconstruction when the serialized window is no longer valid, replay
initialization, and reconnect reconstruction when the window is no longer
valid.

CON-005-CLEAN-014: Every timing-window implementation and applicable CAP SHALL
define cleanup behavior for failure triggers, including rejected opportunity
commands, failed continuation, partial failure, invalid or stale lifecycle
identity, invalid participant registration, and duplicate derived opportunity
identity where cleanup is required.

CON-005-CLEAN-015: Authoritative cleanup SHALL occur before projection cleanup.

CON-005-CLEAN-016: Failed commands SHALL NOT clear unresolved required
rule-owned state prematurely.

CON-005-CLEAN-017: Cleanup trigger handling SHALL be idempotent.

### 5.10 Projection And Interaction Obligations

CON-005-PROJ-001: InteractionFlow, FlowSpec, RuleSurface, UIProjector, scene
controllers, modal routers, and UI SHALL remain non-authoritative derived
surfaces.

CON-005-PROJ-002: Projection SHALL be derived from authoritative state,
static timing-window definitions, and current rule opportunity derivation.

CON-005-PROJ-003: Projection payloads SHALL be JSON-safe when serialized or
transported through existing projection paths.

CON-005-PROJ-004: Projection payloads SHALL NOT authorize gameplay, own
opportunities, own lifecycle completion, own player choice, own costs, or own
rule-specific state.

CON-005-PROJ-005: Stale projection payloads SHALL NOT resurrect opportunities
or make stale selections authoritative.

CON-005-PROJ-006: Live UI routes SHALL submit accepted replayable commands
through the authoritative command submission path for the current game mode.

CON-005-PROJ-007: Modal routers and scene controllers SHALL NOT bypass
CommandApplicability or command `validate()`.

CON-005-PROJ-008: Reconnect projection SHALL be reconstructed from
authoritative state, not restored as authority from stale UI payload.

CON-005-PROJ-009: Missing projection SHALL NOT make an otherwise required
timing-window opportunity resolved.

CON-005-PROJ-010: Production-scene construction SHALL instantiate modal and
router dependencies through repository-safe construction patterns and SHALL NOT
make global class registration a source of gameplay authority.

### 5.11 Visibility Obligations

CON-005-VIS-001: Visibility filtering SHALL distinguish authoritative state,
transport filtering, projection filtering, and command authorization.

CON-005-VIS-002: Projection visibility SHALL NOT grant or remove command
authority.

CON-005-VIS-003: Command validation SHALL enforce controller and player
authorization independently from whether a player could see a projection.

CON-005-VIS-004: Public opportunities SHALL project consistently to both
players and observers according to existing visibility rules.

CON-005-VIS-005: Owner-only or hidden-information opportunities SHALL expose
only the information allowed by the relevant CAP and existing hidden-information
architecture.

CON-005-VIS-006: Reconnect and save/load SHALL reconstruct visibility from
authoritative state and existing filtering rules.

CON-005-VIS-007: Network clients SHALL NOT receive authority to act from hidden
or filtered projection data.

### 5.12 Serialization Obligations

CON-005-SER-001: Authoritative timing-window lifecycle state SHALL serialize
with `GameState`.

CON-005-SER-002: Rule-specific authoritative state SHALL serialize with its
accepted owner, such as runtime upgrade instances under CON-004.

CON-005-SER-003: Derived opportunities SHALL NOT serialize as authoritative
state.

CON-005-SER-004: Projection payloads MAY serialize only as derived reconnect or
presentation payloads and SHALL NOT be trusted as command authority.

CON-005-SER-005: Serialization SHALL preserve enough lifecycle context to
re-derive opportunities after load, replay initialization, and reconnect.

CON-005-SER-005A: Serialization SHALL preserve enough lifecycle identity to
reject commands from cancelled, replaced, closed, or earlier instances of a
timing window, including reopened windows of the same timing-window type.

CON-005-SER-006: Serialization SHALL preserve rule-specific temporary guards,
costs, selected values, or pending authorizations on their accepted owners when
those states are authoritative and still pending.

CON-005-SER-007: Save/load outside a timing window SHALL NOT resurrect stale
opportunities or stale projection payloads.

CON-005-SER-008: Implementation of `TimingWindowState` SHALL use the
repository's existing authoritative compatibility and versioning mechanism. If
no such mechanism exists for the affected serialized state, implementation
SHALL report that gap before adding `TimingWindowState`.

CON-005-SER-009: Incompatible serialized timing-window state SHALL be migrated,
reconstructed, rejected, or failed closed consistently across save/load, replay
initialization, and reconnect.

### 5.13 Replay Obligations

CON-005-REPLAY-001: Every timing-window mutation SHALL be represented by
replayable commands.

CON-005-REPLAY-002: Use commands, decline commands, marker commands, effect
commands, follow-up commands, cleanup commands, and continuation commands SHALL
replay in authoritative command-history order.

CON-005-REPLAY-003: Replay SHALL reconstruct opportunities from authoritative
state after each replayed command. It SHALL NOT replay stored opportunity
queues as authority.

CON-005-REPLAY-004: Replay SHALL preserve inter-command authorization state on
the accepted authoritative owner while that state is pending.

CON-005-REPLAY-005: Replay SHALL prevent duplicate continuation for a single
timing-window interval.

CON-005-REPLAY-006: Replay SHALL NOT depend on UI-local state, modal-local
state, or stale projection payloads to determine lifecycle completion.

CON-005-REPLAY-007: Replay initialization during an active timing window SHALL
reconstruct lifecycle state and rule-owned pending state before deriving
opportunities.

CON-005-REPLAY-008: Replay SHALL reject stale-window commands whose serialized
lifecycle identity does not match the authoritative active timing-window
lifecycle identity at the replay point.

CON-005-REPLAY-009: Replay SHALL preserve continuation failure behavior:
failed continuation leaves the timing window active, preserves lifecycle state,
does not run continuation-dependent cleanup, and does not synthesize fallback
continuation.

### 5.14 Save/Load Obligations

CON-005-SAVE-001: Save/load SHALL preserve active timing-window lifecycle state
when saving inside an active timing window.

CON-005-SAVE-002: Save/load SHALL preserve rule-owned pending state while that
state remains authoritative.

CON-005-SAVE-003: Save/load SHALL re-derive opportunities after load from
authoritative state.

CON-005-SAVE-004: Save/load SHALL NOT trust serialized projection payloads as
authority for opportunity legality, controller identity, or continuation.

CON-005-SAVE-005: Save/load after a timing-window exit SHALL not restore
opportunities from the exited window.

CON-005-SAVE-006: Save/load tests for timing-window capabilities SHALL cover
both pending-window and post-resolution states when the CAP can reach those
states.

CON-005-SAVE-007: Save/load SHALL preserve or reconstruct lifecycle identity so
commands from cancelled, replaced, closed, or previous instances of the same
timing-window type remain stale and are rejected after load.

### 5.15 Reconnect Obligations

CON-005-RECON-001: Reconnect SHALL reconstruct active timing-window lifecycle
state from authoritative serialized state.

CON-005-RECON-002: Reconnect SHALL reconstruct rule-owned pending state from
the accepted authoritative owner.

CON-005-RECON-003: Reconnect SHALL re-derive opportunities after authoritative
state reconstruction.

CON-005-RECON-004: Reconnect SHALL rebuild projection from re-derived
opportunities and visibility rules.

CON-005-RECON-005: Reconnect SHALL NOT treat client-local UI state or old
projection payloads as authoritative.

CON-005-RECON-006: Reconnect during the final unresolved opportunity before
continuation SHALL not allow continuation to overtake the required opportunity
command.

CON-005-RECON-007: Reconnect SHALL preserve or reconstruct lifecycle identity
so stale-window commands from cancelled, replaced, closed, or previous
instances of the same timing-window type are rejected after reconnect.

### 5.16 Networking Invariants

CON-005-NET-001: CON-005 owns network-independent timing-window protocol
invariants. It does not define transport, RPC, packet ordering, latency, or
network API details.

CON-005-NET-002: Multiplayer timing-window behavior SHALL use one
authoritative command stream.

CON-005-NET-003: Clients SHALL NOT locally synthesize rule use, decline,
effect, cleanup, or continuation commands.

CON-005-NET-004: Clients SHALL mirror authoritative command results in server
sequence order before projecting later flow states.

CON-005-NET-005: Continuation SHALL NOT overtake earlier authoritative
opportunity commands.

CON-005-NET-006: Network paths SHALL NOT bypass FlowSpec, CommandApplicability,
or concrete command validation.

CON-005-NET-007: Remote command-effect handlers SHALL classify every mirrored
timing-window command, including handled no-op commands when no local side
effect is required.

CON-005-NET-008: Host/client divergence detection for timing-window
capabilities SHALL compare command history, mirror order, deferred follow-up
state, authoritative owners, and projected state at the first divergence.

CON-005-NET-009: Network mirror paths SHALL apply timing-window commands only
when their lifecycle identity matches the authoritative active timing-window
lifecycle identity at the mirror point.

CON-005-NET-010: Out-of-order, delayed, or duplicated network results SHALL NOT
allow stale-window commands to mutate state, clear cleanup state, or trigger
continuation.

### 5.17 CAP Implementation Obligations

CON-005-CAP-001: A CAP that participates in a timing window SHALL identify the
timing-window type and timing point in which it participates.

CON-005-CAP-002: A CAP SHALL identify the authoritative runtime source for each
opportunity, including capability identity and source-owner identity.

CON-005-CAP-003: A CAP SHALL identify rule-specific mutable state and its
accepted owner.

CON-005-CAP-004: A CAP SHALL define use, decline, marker, effect, follow-up,
cleanup, and continuation interactions only to the extent needed for that rule.
It SHALL NOT redefine timing-window lifecycle ownership.

CON-005-CAP-005: A CAP SHALL state whether opportunities are optional,
required-choice, blocking, non-blocking, public, owner-only, or hidden, as
applicable.

CON-005-CAP-006: A CAP SHALL define cleanup obligations for rule-owned
temporary state.

CON-005-CAP-007: A CAP SHALL map TEST-003 evidence categories to shared and
rule-specific evidence.

CON-005-CAP-008: A CAP SHALL NOT be marked Integrated while unresolved
TEST-003 evidence waivers remain.

CON-005-CAP-009: Shared protocol suites MAY be referenced by a CAP only when
they are accepted, current, applicable, passing, and exactly referenced.

CON-005-CAP-010: Shared protocol evidence SHALL NOT replace required
rule-specific evidence for source identity, legality, mutation, cleanup,
visibility, failure behavior, guards, costs, effects, interactions, and runtime
smoke coverage where applicable.

CON-005-CAP-011: A timing-window CAP SHALL identify lifecycle identity inputs
required by its commands and SHALL define stale-window rejection evidence for
commands that can cross save/load, replay, network, or reconnect boundaries.

CON-005-CAP-012: A timing-window CAP SHALL define its duplicate-candidate and
duplicate-opportunity evidence when the capability can produce more than one
candidate or opportunity for the same timing window.

### 5.18 TEST-003 Verification Obligations

CON-005-TEST-001: Implementations SHALL provide TEST-003 evidence for every
timing-window capability before integration status advancement.

CON-005-TEST-002: Required evidence SHALL cover lifecycle, participant and
opportunity derivation, player control and ordering, one-at-a-time resolution,
re-derivation, commands and mutation, continuation, projection and live route,
serialization and save/load, replay, network and reconnect, cleanup and
failure, effect interaction boundaries, visibility and filtering.

CON-005-TEST-003: Evidence SHALL include the relevant unit, protocol or
integration, projection or UI route, replay or network, and runtime smoke
layers required by TEST-003.

CON-005-TEST-004: Temporary evidence waivers require Project Owner approval and
SHALL be explicitly recorded in the applicable CAP.

CON-005-TEST-005: Waivers MAY defer verification evidence. Waivers SHALL NOT
defer architecture, authority ownership, lifecycle definition, implementation
contracts, or accepted architectural obligations.

CON-005-TEST-006: A CAP containing unresolved waivers SHALL NOT be marked
Integrated.

CON-005-TEST-007: CON-005 implementers SHALL NOT rename, narrow, or redefine
TEST-003 evidence categories.

CON-005-TEST-008: TEST-003 evidence for timing-window implementations SHALL
cover deterministic behavior for stale-window commands, duplicate candidate
suppression, duplicate derived opportunity fail-closed behavior, invalid
registration handling, participant derivation failure, continuation failure,
and cleanup trigger categories.

### 5.19 Migration Obligations For Existing Implementations

CON-005-MIG-001: Existing timing-window-like implementations SHALL be audited
against ADR-005, TIM-002, TEST-003, and this contract before being treated as
CON-005-conformant.

CON-005-MIG-002: Migration SHALL identify current lifecycle owner,
continuation owner, rule-specific state owner, projection owner, command path,
serialization path, replay path, network path, reconnect path, and cleanup path.

CON-005-MIG-003: Migration SHALL correct any implementation that lets UI,
InteractionFlow, FlowSpec, RuleSurface, RuleRegistry, modal routing,
submission callers, or `CommandProcessor` own authoritative lifecycle
completion.

CON-005-MIG-004: Migration SHALL preserve accepted rule-specific behavior in
the relevant CAP.

CON-005-MIG-005: Migration SHALL NOT move runtime upgrade mutable state out of
runtime upgrade instances unless later accepted architecture authorizes that
change.

CON-005-MIG-006: Migration SHALL add or update TEST-003 evidence for each
capability migrated.

CON-005-MIG-007: Migration SHALL not mark a CAP Integrated solely because a
shared timing-window suite passes.

CON-005-MIG-008: Legacy behavior that violates ADR-005 or this contract SHALL
be documented as migration debt or corrected before integration status
advancement.

## 6. Deferred Implementation Details

The following details are intentionally deferred and SHALL NOT be inferred from
this contract:

- exact serialized field names for `TimingWindowState`,
- concrete `TimingWindowState` class shape,
- concrete Timing Window Orchestrator class structure,
- concrete participant interface signatures,
- concrete RuleRegistry API names,
- concrete static definition table layout,
- transport-level networking implementation,
- nested timing-window mechanics beyond Version 1 prohibition,
- effect-composition semantics,
- implementation sequencing,
- first migration target,
- rollout schedule.

Deferring these details does not weaken the ownership, lifecycle,
serialization, replay, networking, cleanup, CAP, or TEST-003 obligations in
this contract.

## 7. Contract Validation

An implementation is CON-005-conformant only when:

1. Authoritative timing-window lifecycle state is owned by `GameState`.
2. Rule-specific mutable state remains on accepted authoritative owners.
3. Static timing-window lifecycle policy has exactly one shared owner.
4. RuleRegistry is used only as a static participant candidate index.
5. Opportunities are derived and not stored as mutable authority.
6. Use, decline, mutation, cleanup, and continuation are replayable commands.
7. The orchestrator re-derives opportunities after every successful relevant
   command.
8. Continuation occurs only after no blocking opportunities remain.
9. UI and projection are non-authoritative.
10. Serialization, replay, save/load, reconnect, and network mirrors preserve
    the same authoritative lifecycle and command sequence.
11. CAP evidence satisfies TEST-003 and records any approved waiver.
12. Stale-window commands are rejected through authoritative lifecycle identity.
13. Duplicate candidates are suppressed before derivation, while duplicate
    derived opportunity identities fail closed.
14. Continuation failure leaves the timing window active and does not execute
    continuation-dependent cleanup.
15. Cleanup triggers are defined for normal completion, lifecycle transitions,
    reconstruction and recovery, and failure paths.

## 8. Related Documents

- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- `docs/architecture/decision_workbooks/TIM-001-timing-window-ownership-and-continuation-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-timing-window-implementation-obligations-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-owner-decisions.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md`
- `docs/architecture/rule_capability_packages/CAP-H9-001-h9-turbolasers.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`

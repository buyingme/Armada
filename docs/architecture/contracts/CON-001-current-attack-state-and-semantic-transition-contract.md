# CON-001: Current Attack State And Semantic Transition Contract

Contract ID: CON-001
Title: Current Attack State And Semantic Transition Contract
Status: Accepted
Derived From: ADR-001
Related ADRs: ADR-001, ADR-003, ADR-004, ADR-005
Related Contracts: CON-003, CON-004, CON-005
Related Verification: TEST-003 where timing-window behavior is involved

Accepted by: Owner
Accepted date: 2026-07-18
Supersedes: None
Superseded by: None

## Draft Note

This Contract translates the accepted architecture in ADR-001 into mandatory,
testable implementation obligations.

Until accepted by the Project Owner, this document is a Draft and is not yet
normative implementation authority. After acceptance, implementations of
`CurrentAttackState`, semantic attack transitions, attack capabilities, and
attack timing-window consumers SHALL conform to this Contract.

After acceptance, TWI-002 and later implementation workbooks SHALL consume
ADR-001 and CON-001 as their architecture and implementation authorities for
this scope.

This Contract does not decide architecture. ADR-001 remains the normative
architecture source.

## 1. Purpose

CON-001 defines the cross-component implementation obligations required to
implement the ADR-001 current-attack ownership and semantic-mutation model
consistently.

It governs:

- the lifecycle of the canonical `CurrentAttackState` owned by `GameState`;
- the replayable command protocol for semantic attack transitions;
- atomic validation, authorization, mutation, and failure behavior;
- serialization, save/load, replay, reconnect, and networking behavior;
- ownership boundaries with timing windows, runtime rule state, projection,
  interaction routing, scene state, and UI;
- the Model C-S migration constraints; and
- the verification evidence required for implementation acceptance.

## 2. Authority

### 2.1 Architectural Authority

ADR-001 is the normative architecture authority for:

- `GameState` ownership of one canonical JSON-safe `CurrentAttackState`;
- replayable-command ownership of semantic attack mutation;
- the membership boundary of `CurrentAttackState`;
- separation from timing-window lifecycle, runtime rule state, projection, and
  UI; and
- the Model C target and Model C-S migration constraint.

CON-001 implements those decisions. It SHALL NOT replace, broaden, narrow, or
reinterpret ADR-001.

### 2.2 Adjacent Authority

CON-001 SHALL be applied together with:

- ADR-003 and CON-003 for rule-capability ownership, command legality,
  execution-surface traceability, projection, visibility, and evidence;
- ADR-004 and CON-004 for runtime upgrade instance ownership and mutable
  upgrade state; and
- ADR-005 and CON-005 for `TimingWindowState`, timing-window orchestration,
  opportunity derivation, continuation, and timing-window cleanup.

When a concrete rule participates in an attack, its Rule Capability Package
SHALL preserve these adjacent authorities and SHALL NOT redefine
current-attack ownership or semantic-transition policy.

TIM-003 and TIM-003-owner-decisions remain historical decision evidence. They
SHALL NOT be used as normative architecture or implementation authority after
ADR-001 and CON-001 are accepted for this scope.

### 2.3 Contract Scope

This Contract applies to every implementation that creates, reads, mutates,
replaces, cancels, completes, serializes, reconstructs, projects, replays, or
networks the current attack.

It also applies to commands and rule capabilities that coordinate an atomic
semantic transaction across `CurrentAttackState` and another accepted
authoritative owner.

## 3. Terms

**Current attack**: The single active attack, if any, whose authoritative
current-attack-specific facts are owned by `GameState` through
`CurrentAttackState`.

**CurrentAttackState**: The canonical JSON-safe authoritative boundary for
current-attack-specific facts that satisfy ADR-001 membership criteria.

**Current-attack lifecycle identity**: Authoritative semantic identity
sufficient to distinguish the active attack from an earlier, completed,
cancelled, or replaced attack. This Contract does not prescribe its format.

**Semantic attack transition**: An attack entry, progression, rule-result
mutation, confirmation, cancellation, replacement, completion, or other
transaction that changes authoritative current-attack gameplay facts.

**Atomic semantic transaction**: One replayable command transaction that
validates and commits all authoritative changes required by one semantic
decision without exposing a partially committed authoritative result.

**Authoritative mirror**: A synchronized copy used by an accepted persistence,
replay, or networking path. It reproduces authoritative state but does not
create an additional mutation owner.

**Derived consumer**: A component that reads authoritative state to calculate,
route, filter, or present information without owning the underlying gameplay
facts.

## 4. CurrentAttackState Lifecycle Obligations

### 4.1 Ownership And Membership

CON-001-STATE-001: `GameState` SHALL own the single canonical
`CurrentAttackState` boundary.

CON-001-STATE-002: Authoritative game state SHALL represent zero or one active
current attack. Two simultaneous authoritative current attacks are prohibited.

CON-001-STATE-003: A fact SHALL belong in `CurrentAttackState` only when all of
the following are true:

1. the fact is JSON-safe;
2. the fact is specific to the active attack;
3. the fact is required to validate, execute, continue, cancel, replace,
   serialize, reconstruct, or resume that attack; and
4. the fact cannot be deterministically re-derived at the point of use from
   another accepted authoritative owner.

CON-001-STATE-004: A fact already owned elsewhere in authoritative
`GameState` SHALL be referenced through stable identity and SHALL NOT be copied
into `CurrentAttackState` as a second authority.

CON-001-STATE-005: `CurrentAttackState` SHALL NOT own:

- deterministic calculations or other derived information;
- rule-specific mutable state;
- timing-window lifecycle state;
- derived timing-window opportunities;
- scene objects or scene-node references;
- interaction-routing or projection payloads; or
- modal, animation, selection, or other UI state.

CON-001-STATE-006: Runtime construction, reconstruction, and mutation SHALL
validate `CurrentAttackState` invariants before the candidate state becomes
authoritative. A state that cannot satisfy this Contract SHALL NOT be installed
as authoritative current-attack state.

CON-001-STATE-007: No scene object, scene FSM, `InteractionFlow`, projection,
modal, UI component, rule implementation, or Rule Capability Package SHALL
install, replace, or independently mutate authoritative `CurrentAttackState`.

### 4.2 Lifecycle Identity

CON-001-ID-001: Every active current attack SHALL have authoritative lifecycle
identity sufficient to distinguish it from every earlier completed, cancelled,
or replaced attack relevant to command validation.

CON-001-ID-002: Current-attack lifecycle identity SHALL remain stable for the
duration of one active attack and SHALL change when a replacement creates a
different active attack.

CON-001-ID-003: Current-attack lifecycle identity SHALL be distinct in meaning
from timing-window lifecycle identity, runtime-rule source identity, and
projection identity.

CON-001-ID-004: Conforming implementations SHALL NOT infer that this Contract
prescribes a UUID, counter, composite key, field name, or concrete identity
representation.

CON-001-ID-005: Commands that target an active attack SHALL carry or derive
enough stable authoritative identity to reject a command intended for an
earlier, completed, cancelled, or replaced attack.

CON-001-ID-006: Lifecycle identity SHALL be preserved or deterministically
reconstructed across save/load, replay initialization, authoritative network
mirroring, and reconnect.

CON-001-ID-007: Lifecycle identity creation SHALL be deterministic from
authoritative state and serialized command context. It SHALL NOT depend on
scene-node identity, memory address, local load order, local UI state, or
unserialized random generation.

### 4.3 Creation And Existence

CON-001-LIFE-001: During live semantic progression, only a successful
replayable command representing semantic attack entry or replacement SHALL
start a new active `CurrentAttackState` lifecycle. Reconstruction MAY
reconstitute an already-existing serialized lifecycle under section 4.5 and
SHALL NOT be treated as a new semantic attack entry.

CON-001-LIFE-002: Attack creation SHALL validate all required authoritative
preconditions before installing the new state.

CON-001-LIFE-003: Normal attack entry SHALL reject when another current attack
is active. A different attack MAY become active only through a validated
semantic replacement transaction.

CON-001-LIFE-004: Creation SHALL atomically establish the complete valid
authoritative state required at that semantic entry point. No partially
initialized current attack SHALL become observable as authoritative state.

CON-001-LIFE-005: Creation SHALL derive input from accepted authoritative
owners and validated command intent. It SHALL NOT derive authority from scene,
projection, modal, or UI state.

CON-001-LIFE-006: Once created, `CurrentAttackState` SHALL remain the sole
authority for facts within its boundary until a successful semantic completion,
cancellation, or replacement transaction changes that lifecycle.

CON-001-LIFE-007: Repeated attack-entry submission for the same semantic event
SHALL NOT create duplicate active attacks.

### 4.4 Completion, Cancellation, Replacement, And Cleanup

CON-001-LIFE-008: Completion, cancellation, and replacement SHALL each occur
through an explicit replayable semantic attack command.

CON-001-LIFE-009: Successful completion or cancellation SHALL atomically leave
authoritative `GameState` with no active current attack.

CON-001-LIFE-010: Successful replacement SHALL atomically retire the previous
current attack and install one valid replacement with a distinct lifecycle
identity.

CON-001-LIFE-011: A terminal semantic transaction SHALL clean or retire only
current-attack facts owned by `CurrentAttackState`.

CON-001-LIFE-012: Rule-specific state cleanup SHALL remain on the accepted
runtime rule owner and SHALL occur only through the replayable command paths
permitted by CON-003, CON-004, CON-005, and the relevant Rule Capability
Package.

CON-001-LIFE-013: A terminal attack transaction SHALL NOT silently discard an
active attack-scoped timing window. Any timing-window completion,
cancellation, replacement, or close-and-open behavior SHALL conform to
CON-005.

CON-001-LIFE-014: When a CON-005 continuation command is also a semantic attack
transition, that replayable command MAY perform the authoritative
`CurrentAttackState` mutation. This SHALL NOT transfer timing-window
orchestration ownership to the command or attack-state ownership to the Timing
Window Orchestrator.

CON-001-LIFE-015: Failed completion, cancellation, or replacement SHALL leave
the existing authoritative current attack and every adjacent authoritative
owner unchanged.

CON-001-LIFE-016: Destruction of a scene object, modal, router, projection, or
UI surface SHALL NOT complete, cancel, replace, or clean authoritative
current-attack state.

CON-001-LIFE-017: While its owning `GameState` remains authoritative for an
ongoing match, removal or destruction of an active authoritative
`CurrentAttackState` representation is itself a semantic mutation and SHALL
occur only as part of a successful replayable completion, cancellation, or
replacement transaction. Disposal of the entire owning `GameState` is outside
this requirement.

CON-001-LIFE-018: After a successful terminal transaction, derived consumers
SHALL discard or re-derive stale current-attack mirrors. A stale mirror SHALL
NOT reinstall or resurrect the retired attack.

### 4.5 Reconstruction

CON-001-RECONSTRUCT-001: Reconstruction SHALL establish canonical
`CurrentAttackState` before commands, opportunities, projection, or UI are
derived from the reconstructed game state.

CON-001-RECONSTRUCT-002: Reconstruction SHALL preserve all authoritative facts
and lifecycle identity required to validate and resume the active attack.

CON-001-RECONSTRUCT-003: Reconstruction SHALL resolve stable references to
other authoritative owners and SHALL fail closed when required references are
missing, ambiguous, or semantically inconsistent.

CON-001-RECONSTRUCT-004: Reconstruction SHALL NOT use stale scene state,
`InteractionFlow`, projection payloads, modal state, or UI state as an
independent source of current-attack authority.

CON-001-RECONSTRUCT-005: Reconstruction of state that semantically contains no
active attack SHALL NOT synthesize an active `CurrentAttackState` from derived
or presentation data.

## 5. Semantic Mutation Obligations

### 5.1 Replayable Command Surface

CON-001-CMD-001: Every semantic attack transition and every semantic mutation
of `CurrentAttackState` SHALL occur through a replayable command.

CON-001-CMD-002: The semantic attack transitions governed by this Contract
SHALL include attack entry, progression, rule-result mutation, confirmation,
cancellation, replacement, and completion.

CON-001-CMD-003: A command SHALL represent one atomic semantic transaction,
not one command per internal scene-FSM edge.

CON-001-CMD-004: Internal FSM movement, animation, modal choreography, camera
movement, and transient scene coordination SHALL NOT require replayable
commands unless they change authoritative gameplay facts.

CON-001-CMD-005: If an internal transition changes an authoritative
current-attack fact, that change SHALL be part of a replayable semantic command
regardless of whether the transition is also represented in a scene FSM.

CON-001-CMD-006: Deterministic calculations required by a semantic transaction
MAY be performed by the command or an accepted deterministic calculation
surface invoked by the command. The resulting authoritative mutation SHALL be
committed by the command transaction.

CON-001-CMD-007: Replay history SHALL record accepted semantic decisions and
their command order. It SHALL NOT require separate replay decisions for
deterministic calculation steps.

CON-001-CMD-008: A command MAY coordinate one atomic semantic transaction
across `CurrentAttackState` and another accepted authoritative owner. Such
coordination SHALL NOT transfer ownership between those boundaries.

CON-001-CMD-009: Every semantic attack command SHALL participate in the
repository's accepted command registration, serialization, applicability,
replay, and network-mirroring paths that apply to replayable commands.

CON-001-CMD-010: A semantic attack command SHALL NOT install a caller-provided
`CurrentAttackState` snapshot, scene snapshot, or projection payload as
authority. Command intent and identity context SHALL be validated against
current authoritative state before mutation.

### 5.2 Validation And Authorization

CON-001-VAL-001: Every semantic attack command SHALL validate against current
authoritative state immediately before mutation.

CON-001-VAL-002: Validation SHALL include every applicable condition from the
following categories:

- current-attack lifecycle identity;
- current phase, flow, timing point, and semantic attack stage;
- controlling-player or submitting-player authorization;
- stable identity and existence of referenced authoritative owners;
- rule-specific legality, costs, guards, and effects;
- timing-window legality where CON-005 applies; and
- whether the requested semantic transition is permitted from the current
  authoritative state.

CON-001-VAL-003: `CommandApplicability`, `FlowSpec` command policy where
applicable, registered rule validation, and concrete command validation SHALL
not disagree about whether a semantic attack command is permitted.

CON-001-VAL-004: Authorization SHALL derive from authoritative state.
Projection visibility, modal availability, UI enablement, and possession of a
projection payload SHALL NOT grant command authority.

CON-001-VAL-005: Commands targeting an earlier, completed, cancelled, or
replaced current attack SHALL be rejected as stale.

CON-001-VAL-006: Repeated completion, cancellation, replacement, or other
single-use semantic transitions SHALL be rejected after the authoritative
state indicates that transition has already occurred.

CON-001-VAL-007: A rule implementation SHALL NOT weaken generic attack-command
validation. Rule-specific validation SHALL add to or specialize accepted
legality without establishing a competing mutation path.

### 5.3 Atomicity And Failure

CON-001-FAIL-001: A successful semantic attack command SHALL commit all
authoritative mutations required by its semantic transaction exactly once.

CON-001-FAIL-002: No partial authoritative result SHALL remain if validation,
authorization, deterministic calculation, or mutation fails.

CON-001-FAIL-003: A rejected or failed semantic attack command SHALL NOT:

- mutate `CurrentAttackState`;
- mutate an adjacent runtime rule owner;
- change timing-window lifecycle state;
- perform terminal cleanup;
- synthesize completion, cancellation, replacement, or continuation;
- update projection as though the command succeeded; or
- be recorded as a successful semantic transition.

CON-001-FAIL-004: Failure SHALL preserve the prior authoritative state,
surface a deterministic failure result or diagnostic, and fail closed.

CON-001-FAIL-005: Implementations SHALL NOT guess an alternative semantic
transition, silently skip a required transition, or use presentation state to
recover from command failure.

CON-001-FAIL-006: Delayed, duplicated, or out-of-order replay or network
delivery SHALL NOT cause a semantic transaction to be applied more than once.

## 6. Serialization Obligations

### 6.1 Canonical Serialization

CON-001-SER-001: Authoritative `CurrentAttackState` SHALL serialize as part of
canonical `GameState` serialization.

CON-001-SER-002: The serialized representation SHALL be JSON-safe and SHALL
contain no scene nodes, resources, callables, unserialized object identity,
memory addresses, modal state, or UI objects.

CON-001-SER-003: Serialization SHALL contain every authoritative
current-attack-specific fact required to validate, execute, continue, cancel,
replace, reconstruct, or resume the active attack.

CON-001-SER-004: Serialization SHALL preserve current-attack lifecycle identity
and all stable references required to resolve facts owned elsewhere in
authoritative `GameState`.

CON-001-SER-005: Serialization SHALL NOT duplicate facts that remain
authoritative on another state owner.

CON-001-SER-006: Serialization SHALL NOT persist deterministic calculations,
derived opportunities, projection payloads, or scene/UI state as
`CurrentAttackState` authority.

CON-001-SER-007: Semantically equivalent authoritative current-attack state
SHALL produce deterministic canonical serialization under the repository's
accepted canonicalization rules.

CON-001-SER-008: State with no active current attack SHALL serialize one
deterministic inactive representation under the chosen repository schema.

### 6.2 Compatibility And Invalid State

CON-001-SER-009: `CurrentAttackState` compatibility SHALL use the repository's
existing authoritative `GameState`, save, and replay compatibility mechanisms.

CON-001-SER-010: `CurrentAttackState` SHALL NOT introduce an independent local
version authority that competes with those existing compatibility mechanisms.

CON-001-SER-011: Every supported older serialized representation SHALL have one
documented deterministic reconstruction outcome.

CON-001-SER-012: Structurally invalid, semantically inconsistent, or unsupported
serialized current-attack state SHALL be rejected or failed closed through the
existing authoritative deserialization error path. Implementations SHALL NOT
guess missing semantic facts.

CON-001-SER-013: Version compatibility SHALL NOT make legacy projection,
`InteractionFlow`, scene, modal, or UI data an ongoing authority after
reconstruction.

CON-001-SER-014: Any compatibility migration that produces canonical
`CurrentAttackState` SHALL produce one authority for every migrated fact and
SHALL satisfy the Model C-S obligations in this Contract.

### 6.3 Save And Load

CON-001-SAVE-001: Saving during an active attack SHALL preserve all canonical
state and identity required to resume the same semantic attack after load.

CON-001-SAVE-002: Loading during an active attack SHALL reconstruct canonical
state before deriving rule opportunities, projection, interaction routing, or
UI.

CON-001-SAVE-003: Saving and loading after attack completion, cancellation, or
replacement SHALL NOT resurrect the retired attack or accept its stale
commands.

CON-001-SAVE-004: Save/load round trips SHALL preserve the same legal next
semantic transitions, controller authorization, rule-source references, and
timing-window relationship as the original authoritative state.

CON-001-SAVE-005: Save/load SHALL NOT depend on local scene or UI state to
reconstruct current-attack legality.

### 6.4 Replay

CON-001-REPLAY-001: Replay initialization SHALL reconstruct canonical
`CurrentAttackState` from authoritative serialized state before replaying later
semantic attack commands.

CON-001-REPLAY-002: Replay SHALL apply semantic attack commands in
authoritative command-history order.

CON-001-REPLAY-003: Replaying the same accepted command sequence from the same
initial authoritative state SHALL reproduce the same canonical current-attack
state and gameplay result.

CON-001-REPLAY-004: Replay SHALL reproduce deterministic calculations during
semantic command execution and SHALL NOT depend on separately recorded
calculation decisions.

CON-001-REPLAY-005: Replay SHALL NOT depend on scene FSM state, modal state, UI
state, or projection payloads to determine semantic attack progression.

CON-001-REPLAY-006: Replay SHALL preserve valid inter-command active-attack
state and SHALL reject stale commands after completion, cancellation, or
replacement.

CON-001-REPLAY-007: Replay SHALL apply each semantic completion, cancellation,
or replacement transaction exactly once.

### 6.5 Networking And Reconnect

CON-001-NET-001: Multiplayer attack behavior SHALL use one authoritative
semantic command stream.

CON-001-NET-002: Network clients SHALL NOT synthesize semantic attack
transitions, current-attack mutation, cancellation, replacement, completion,
or timing-window continuation locally.

CON-001-NET-003: Mirrored semantic attack commands SHALL be applied in
authoritative sequence order and validated against the current lifecycle
identity at the mirror point.

CON-001-NET-004: Delayed, duplicated, or out-of-order network results SHALL NOT
allow stale current-attack commands to mutate authoritative state.

CON-001-NET-005: Shared authoritative current-attack facts and semantic command
order SHALL agree between host and conforming mirrors. Viewer-specific filtered
data MAY differ only according to accepted visibility rules.

CON-001-NET-006: Reconnect SHALL reconstruct canonical current-attack state
from authoritative serialized state before rebuilding projection and live
interaction routing.

CON-001-NET-007: Reconnect SHALL preserve lifecycle identity and SHALL reject
commands for earlier, completed, cancelled, or replaced attacks.

CON-001-NET-008: Reconnect SHALL NOT restore attack authority from client-local
scene state, UI state, modal state, or stale projection payloads.

CON-001-NET-009: Visibility and transport filtering SHALL remain separate from
command authorization. Hidden or filtered information SHALL neither grant nor
remove semantic command authority.

## 7. Ownership Boundary Obligations

### 7.1 Responsibility Boundaries

| Surface | Permitted responsibility | Prohibited authority |
| --- | --- | --- |
| `GameState` | Own the canonical `CurrentAttackState` boundary and serialize it. | None within the ADR-001 ownership decision. |
| `CurrentAttackState` | Own current-attack-specific authoritative facts that satisfy the membership test. | Derived calculations, timing lifecycle, rule-specific mutable state, projection, routing, or UI state. |
| Replayable commands | Validate and perform atomic semantic attack transactions. | Redefining state ownership or timing-window orchestration policy. |
| `CommandProcessor` and submission infrastructure | Apply, order, record, and mirror accepted commands through existing command infrastructure. | Inventing semantic transitions, current-attack facts, or completion policy outside commands. |
| Runtime rule owners | Own rule-specific mutable state, guards, costs, and effects under accepted authority. | Competing current-attack state or semantic-transition policy. |
| `TimingWindowState` | Own timing-window lifecycle under ADR-005 and CON-005. | Current-attack facts, attack dice, attack effects, rule state, or semantic attack-transition policy. |
| Timing Window Orchestrator | Coordinate timing-window lifecycle, re-derivation, completion evaluation, cleanup coordination, and continuation. | Current-attack state ownership or authoritative attack mutation. |
| `RuleRegistry` and `RuleSurface` | Perform accepted static indexing or hook responsibilities. | Current-attack state ownership, semantic transition ownership, or command authorization. |
| `InteractionFlow`, `FlowSpec`, and projection | Route, filter, derive, and present viewer-appropriate interaction information. | Current-attack gameplay authority, mutation, or authorization. |
| Scene objects, scene FSMs, modal routers, and UI | Coordinate transient interaction and presentation and submit commands. | Durable current-attack facts, semantic mutation, completion, or cleanup authority. |
| Save/load, replay, reconnect, and network transport | Serialize, reconstruct, order, filter, and mirror accepted authority. | Creating a competing current-attack owner or deriving legality from transport/projection state. |

### 7.2 Cross-Boundary Requirements

CON-001-BOUND-001: Derived consumers MAY read canonical `CurrentAttackState`
but SHALL NOT write back as independent authorities.

CON-001-BOUND-002: Rule opportunities MAY read `CurrentAttackState` and
accepted runtime rule state. Opportunities SHALL remain derived and SHALL NOT
be stored as authoritative persistent attack state.

CON-001-BOUND-003: Rule-specific guards, costs, card state, selected values,
and mutable effects SHALL remain on their accepted runtime owners.

CON-001-BOUND-004: A replayable command coordinating multiple authoritative
owners SHALL validate and mutate each owner according to its governing ADR and
Contract.

CON-001-BOUND-005: Projection MAY expose viewer-appropriate current-attack
facts and affordances. Projection content or absence SHALL NOT authorize or
prohibit a command.

CON-001-BOUND-006: `InteractionFlow` and scene FSM state MAY mirror semantic
progress for routing or presentation only. They SHALL NOT determine the
authoritative semantic stage when canonical state disagrees.

CON-001-BOUND-007: Rule implementations and Rule Capability Packages SHALL
consume CON-001 and SHALL NOT define competing current-attack lifecycle,
membership, or mutation policy.

CON-001-BOUND-008: Implementations SHALL NOT infer or introduce a generic
attack engine, rule engine, timing framework, or effect-composition engine from
this Contract.

CON-001-BOUND-009: After each successful semantic attack command, projection
and live interaction routing SHALL be derived from the resulting authoritative
state before those surfaces present or route a later player action. Command
authorization SHALL remain on authoritative validation surfaces.

CON-001-BOUND-010: Viewer-specific filtering SHALL use accepted visibility
owners and SHALL NOT change the underlying authoritative current-attack facts
or their command authorization.

## 8. Migration Obligations

CON-001-MIG-001: Migration SHALL target Model C: one canonical
`GameState`-owned `CurrentAttackState` and replayable-command ownership of
semantic attack mutation.

CON-001-MIG-002: Migration MAY proceed in semantically complete stages under
Model C-S.

CON-001-MIG-003: Every migrated current-attack fact SHALL have exactly one
authoritative owner at every migration stage.

CON-001-MIG-004: For a migrated fact, temporary compatibility flow SHALL be one
way from canonical `CurrentAttackState` to a non-authoritative consumer or
mirror.

CON-001-MIG-005: A temporary compatibility consumer or mirror SHALL NOT write
the migrated fact back into canonical state, validate commands from its local
copy, or resolve conflicts as an independent authority.

CON-001-MIG-006: A migration stage SHALL NOT retain two writable sources for
the same current-attack fact.

CON-001-MIG-007: A migrated semantic transition SHALL use the replayable
command path for live play, save/load continuation, replay, network mirroring,
and reconnect.

CON-001-MIG-008: Temporary mirrors SHALL be removed when all applicable
consumers derive the migrated fact from canonical state and the required
verification evidence passes.

CON-001-MIG-009: Migration of one fact SHALL NOT move rule-specific mutable
state into `CurrentAttackState`, move timing lifecycle into
`CurrentAttackState`, or make projection authoritative.

CON-001-MIG-010: Migration completion for a current-attack fact SHALL require
evidence that:

1. canonical state is the only authoritative owner;
2. all semantic writes occur through replayable commands;
3. no reverse-write compatibility path remains;
4. save/load, replay, reconnect, and networking consume the canonical fact;
5. projection and scene state are derived; and
6. stale or duplicate commands cannot reapply the migrated transition.

CON-001-MIG-011: This Contract SHALL NOT be used to infer migration sequencing,
slice boundaries, rollout order, or the first capability to migrate.

## 9. Verification Obligations

### 9.1 Required Evidence

CON-001-TEST-001: Every implementation governed by CON-001 SHALL provide
sufficient objective evidence to establish every applicable requirement in this
Contract. Applicable behavioral obligations SHALL have automated evidence where
automation is practical. Architectural or structural obligations that are not
meaningfully automatable SHALL have objective structural or review evidence.
Non-automated evidence SHALL NOT replace automated behavioral evidence where
automation is practical.

CON-001-TEST-002: Verification SHALL cover the complete semantic protocol, not
only isolated state classes or command helpers.

CON-001-TEST-003: Required evidence SHALL include the applicable categories in
the following matrix:

| Area | Required evidence |
| --- | --- |
| Lifecycle | No-active to active creation, active existence, completion, cancellation, replacement, cleanup, and no resurrection. |
| Identity | Stable lifecycle identity, distinct replacement identity, stale-command rejection, and persistence across reconstruction boundaries. |
| Membership | JSON safety, accepted fact membership, stable references to other owners, and rejection of forbidden or duplicated authority. |
| Commands | Registration, serialization, applicability, concrete validation, authorization, exact-once mutation, and authoritative ordering. |
| Atomicity and failure | No partial mutation across all touched owners; failed commands preserve state and do not synthesize cleanup or continuation. |
| Serialization | Canonical active and inactive forms, deterministic round trip, invalid-state rejection, and compatibility behavior. |
| Save/load | Mid-attack resume, post-terminal non-resurrection, legal-next-transition equivalence, and stale identity rejection. |
| Replay | Semantic command order, deterministic reconstruction, exact-once terminal transitions, and no dependency on calculation or UI records. |
| Networking | Authoritative command order, shared-state agreement, stale/duplicate/out-of-order rejection, and no client-synthesized semantic transitions. |
| Reconnect | Canonical state reconstruction before projection, lifecycle identity preservation, and correct live interaction resumption. |
| Projection and visibility | Viewer-specific filtering, non-authoritative projection, command-side authorization, and absence of hidden-information authority. |
| Ownership boundaries | Runtime rule state, timing-window state, and current-attack state remain on their accepted owners during coordinated transactions. |
| Migration | One owner per migrated fact, canonical-to-mirror direction, no reverse writes, and removal of temporary mirrors at completion. |

CON-001-TEST-004: Unit evidence SHALL cover state invariants, identity,
serialization, command validation, command execution, and failure behavior.

CON-001-TEST-005: Protocol or integration evidence SHALL cover creation through
terminal semantic transition, including applicable rule and timing-window
interactions.

CON-001-TEST-006: Save/load, replay, reconnect, and network evidence SHALL use
the canonical production serialization and command paths rather than test-only
alternative authority.

CON-001-TEST-007: Verification SHALL compare canonical serialized state or its
accepted deterministic hash where repository verification uses state hashes.
Intentional canonical serialization changes MAY update accepted fixtures only
through the repository's normal fixture-review process.

CON-001-TEST-008: A behavior-changing attack capability SHALL map its
rule-specific evidence through its CON-003 Rule Capability Package. Shared
CON-001 protocol evidence SHALL NOT replace rule-specific legality, cost,
effect, cleanup, visibility, or interaction evidence.

CON-001-TEST-009: An attack capability participating in a timing window SHALL
also satisfy CON-005 and the applicable TEST-003 verification matrix without
renaming, narrowing, or redefining TEST-003 evidence categories.

CON-001-TEST-010: Live interaction-route evidence SHALL prove that scene,
router, modal, and UI paths submit the accepted replayable command and do not
perform a parallel authoritative mutation.

CON-001-TEST-011: An implementation SHALL NOT be considered CON-001-conformant
while an applicable requirement lacks sufficient passing evidence. The Project
Owner MAY approve and record a temporary evidence waiver under the governing
verification process. A waiver MAY defer or explicitly record missing evidence,
but it SHALL NOT make waived, deferred, missing, or incomplete evidence passing
and SHALL NOT establish full CON-001 conformance.

CON-001-TEST-012: Codex MAY recommend implementation readiness. Codex SHALL NOT
approve Contract acceptance, Rule Capability Package integration, or evidence
waivers.

## 10. Explicit Non-Goals

CON-001 does not define:

- concrete APIs;
- class placement beyond the accepted `GameState` ownership boundary;
- JSON field names, schemas, or payload layouts;
- command names, command catalogues, or command-result formats;
- attack-stage enumerations or internal FSM mechanics;
- calculation helper organization;
- projection payload schemas or UI composition;
- transport protocols, RPCs, packet formats, or reliability mechanisms;
- version numbers or concrete migration functions;
- implementation order, migration slices, or rollout sequencing;
- H9 implementation;
- ECM implementation;
- Tarkin implementation;
- scene architecture;
- a generic attack, rule, timing, or effect framework; or
- new architecture or ownership decisions.

## 11. Contract Conformance

An implementation is CON-001-conformant only when:

1. `GameState` owns the only authoritative `CurrentAttackState`.
2. Zero or one current attack is active and every active attack has stable
   lifecycle identity.
3. `CurrentAttackState` contains only facts permitted by the ADR-001 membership
   test.
4. Every semantic attack transition and mutation occurs through one replayable
   atomic command transaction.
5. Validation and authorization use authoritative state and reject stale,
   duplicate, wrong-player, and illegal transitions.
6. Failed commands leave all authoritative owners unchanged.
7. Completion, cancellation, and replacement retire or replace the current
   attack exactly once without UI-owned cleanup.
8. Serialization, save/load, replay, reconnect, and networking reconstruct the
   same canonical attack and command order.
9. Timing-window lifecycle and rule-specific mutable state remain on their
   accepted owners.
10. Projection, interaction routing, scene state, modal state, and UI remain
    derived and non-authoritative.
11. Model C-S migration preserves one owner and prohibits reverse writes.
12. All applicable verification obligations have sufficient passing evidence;
    no required evidence remains waived, deferred, missing, or incomplete.

## 12. Related Documents

- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`

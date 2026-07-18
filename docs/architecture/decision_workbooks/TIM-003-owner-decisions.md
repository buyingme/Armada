# TIM-003 Owner Decisions: Authoritative Attack State And Transition Ownership

Date: 2026-07-17

Decision status: Accepted by the Project Owner

Companion workbook:
`docs/architecture/decision_workbooks/TIM-003-authoritative-attack-state-and-transition-ownership.md`

Normative architectural extraction:
`docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`

## 1. Document Role

This companion record preserves the repository-backed reasoning behind the
three accepted TIM-003 Owner decisions. `ADR-001` is the normative
architectural authority; TIM-003 contains the concise historical decision
boundary, and this record retains the investigated alternatives, rejection
reasons, consequences, and migration implications as supporting evidence.

This document is architecture decision evidence. It is not an ADR, Contract,
implementation specification, migration plan, API definition, or JSON schema.
Accepted ADRs and Contracts retain their authority under
`docs/architecture/DOCUMENT_AUTHORITY.md`.

## 2. Authority And Investigation Basis

The investigation was constrained by:

- ADR-003 and CON-003 for authoritative state, command validation and mutation,
  serialization, replay, networking, and projection boundaries;
- ADR-004 and CON-004 for rule-specific mutable state on runtime rule owners;
- ADR-005 and CON-005 for timing-window state, lifecycle, opportunity,
  continuation, and command boundaries; and
- TEST-003 for timing-window verification obligations.

The principal repository evidence included:

- `src/core/combat/attack_state.gd`;
- `src/scenes/game_board/game_board.gd`;
- `src/scenes/game_board/attack_executor.gd`;
- `src/core/state/game_state.gd`;
- `src/core/state/interaction_flow.gd`;
- `src/core/commands/publish_attack_flow_command.gd`;
- `src/core/commands/confirm_attack_dice_command.gd`;
- `src/core/commands/skip_attack_command.gd`;
- `src/autoload/command_processor.gd`;
- `src/core/commands/game_replay.gd`;
- `src/core/network/ui_projector.gd`;
- the associated state, command, replay, projection, baseline, and networking
  tests; and
- CAP-H9-001, MA-H9-001, MA-TW-001, and TWI-002 as capability and planning
  evidence.

The investigation also considered the boundary candidates, reality-gap
register, architecture roadmap, and current-state maps. Repository code was
used as evidence of current behavior, not as authority for the target
architecture.

## 3. Question 1: Authoritative Current-Attack Owner

### 3.1 Architectural Problem

The repository distributes active-attack behavior across a scene-created
`AttackState`, the `AttackExecutor` FSM, marker and publication commands, and a
serialized `InteractionFlow` snapshot. The scene attack object contains
rule-relevant participants and dice but is not canonically serialized by
`GameState`. `InteractionFlow` supports routing, reconnect, and projection but
is constrained to remain non-authoritative.

H9 and later attack timing-window consumers require one source for legality,
mutation, save/load, replay, reconnect, networking, and downstream attack
resolution. The architecture therefore had to choose whether current-attack
authority remained scene-owned, became permanently split, or moved to one
durable `GameState` boundary.

### 3.2 Alternatives Considered

| Model | Architectural posture |
| --- | --- |
| Model A | Preserve scene-owned attack authority and bridge it into persistence, replay, and reconnect. |
| Model B | Permanently split authoritative facts and transitions between durable `GameState` state and scene attack state. |
| Model C | Establish one canonical JSON-safe `CurrentAttackState` owned by `GameState`. |
| Model C-S | Reach Model C through safe staged migration while preserving one authority for each migrated fact. |
| Model D | Derive live authority from `InteractionFlow` or command history without an explicit current-state owner. |

### 3.3 Repository Evidence

- `AttackState` is a scene-used `RefCounted` object with gameplay facts,
  derived display data, rule-related flags, and scene-object references. It has
  no canonical `GameState` serialization boundary.
- `game_board.gd` creates the active attack context, and `attack_executor.gd`
  performs the current semantic attack sequence.
- `GameState` serializes `InteractionFlow` and `TimingWindowState` but does not
  serialize the scene `AttackState` as canonical current-attack state.
- `PublishAttackFlowCommand` publishes a snapshot after scene mutation instead
  of owning the underlying semantic transition.
- Reconnect and projection consume serialized interaction state, but ADR-003,
  ADR-005, CON-003, and CON-005 prohibit routing and projection surfaces from
  becoming rule-legality or mutation authority.
- CAP-H9-001 requires authoritative current dice to be mutated once and then
  consumed by downstream defense behavior, replay, reconnect, and networking.

### 3.4 Reasons Alternatives Were Rejected

**Model A was rejected** because scene authority would require a permanent
exception or bridge for serialization, replay, reconnect, and networking. It
would preserve scene-order dependence and leave command mutation secondary to
scene execution.

**Model B was rejected** because permanent split ownership makes every new
attack fact and transition an ownership classification problem. It creates
ongoing synchronization, ordering, reconnect, and replay risk and permits two
surfaces to disagree about one active attack.

**Model D was rejected** because `InteractionFlow` is non-authoritative and
command history is not an authoritative live state surface for command
validation. Reconstruction from either would weaken the accepted projection
and command boundaries.

**Immediate all-at-once migration was not required** because repository
evidence supports staged replacement, provided staging does not create a
permanent split model. That need produced Model C-S as the migration posture,
not as a different target architecture.

### 3.5 Accepted Decision

Model C is accepted as the target architecture:

- `GameState` owns one canonical JSON-safe `CurrentAttackState`;
- that boundary is the sole authority for current-attack facts within its
  accepted scope;
- permanent split ownership is prohibited; and
- scene state, `InteractionFlow`, projection, and UI remain consumers or
  derived mirrors.

Model C-S is accepted as the migration posture:

- migration may proceed in safe, semantically complete stages;
- each migrated fact has one authority at a time;
- compatibility flow is one way from canonical state to a consumer;
- reverse authoritative writes are prohibited; and
- temporary compatibility boundaries do not become permanent architecture.

### 3.6 Consequences

- Save/load and reconnect have one canonical active-attack source.
- Replay and networking apply commands against the same durable state.
- Projection and interaction routing can be rebuilt without becoming
  authorization inputs.
- H9 and later attack rules no longer choose their own attack-state owner.
- Migration cost is accepted in exchange for eliminating permanent
  synchronization and dual-authority defects.

### 3.7 Migration Implications

The accepted posture defines direction rather than a migration plan. Downstream
planning must move semantic facts into the canonical boundary in complete
segments, prevent reverse writes for migrated facts, and remove temporary
mirrors once their consumers read canonical state. The accepted posture does
not prescribe slices, APIs, schemas, or file placement.

## 4. Question 2: Semantic Attack Transition Owner

### 4.1 Architectural Problem

Current scene code performs semantic attack transitions and then publishes or
confirms the resulting interaction state. Some commands record intent but do
not own the authoritative mutation. This makes live scene execution materially
different from replay and network command execution.

The investigation had to determine which surface owns semantic transitions and
how command boundaries should relate to the much finer internal scene FSM
edges.

### 4.2 Command-Boundary Investigation

The accepted command architecture already requires commands to validate and
perform authoritative gameplay mutation. The attack investigation confirmed
that the same boundary must cover semantic attack entry, progression,
rule-result mutation, confirmation, cancellation, replacement, and completion.

`PublishAttackFlowCommand`, `ConfirmAttackDiceCommand`, and
`SkipAttackCommand` demonstrate the current gap: publication or marker commands
can record a scene decision without owning all state changes that give that
decision gameplay meaning. That pattern cannot provide identical live, replay,
and network semantics once current-attack state becomes authoritative.

The Timing Window Orchestrator remains responsible for timing-window lifecycle
and for submitting or enabling the accepted continuation command. It does not
thereby acquire ownership of the attack mutation performed by that command.

### 4.3 Semantic Transition Investigation

A semantic transition changes authoritative gameplay meaning: it establishes,
progresses, mutates, confirms, cancels, replaces, or completes an attack.
Internal FSM movement, animation, modal choreography, and scene coordination do
not become semantic merely because they occur between two command boundaries.

The architecture requires command granularity to follow the atomic gameplay
transaction. Deterministic calculations needed to execute that transaction may
run within the command's authoritative execution. They do not require separate
commands or separate replay records.

### 4.4 Grouped Commands Versus Microcommands

**Grouped semantic commands were accepted.** One command represents one player
or system decision and all deterministic authoritative changes needed to make
that decision atomic.

**Microcommands for every FSM edge were rejected.** They would expose scene
implementation mechanics in the command log, permit partially applied semantic
transactions, increase ordering and replay surface area, and make command
protocol evolution depend on presentation flow.

**Scene-owned grouped transitions were rejected.** Grouping alone does not
resolve authority when the scene mutates first and commands only publish the
result.

### 4.5 Repository Evidence

- `AttackExecutor` currently performs semantic stage changes in scene code.
- `PublishAttackFlowCommand` synchronizes a snapshot after the scene state has
  changed.
- Existing confirm and skip commands act as markers for scene-owned behavior.
- `CommandProcessor`, replay, baseline traces, and network command submission
  already provide the shared replayable ordering surface expected by ADR-003
  and CON-003.
- ADR-005 and CON-005 require timing opportunities and continuation to use
  replayable commands while prohibiting rule commands and UI callers from
  owning timing-window completion.

### 4.6 Accepted Decision

- Replayable commands own every semantic attack transition.
- Commands represent atomic semantic transactions, not individual FSM edges.
- Commands may perform deterministic calculations required by their
  transaction.
- Replay records decisions and command order, not calculation steps.
- Presentation-only scene behavior remains non-authoritative.
- `TimingWindowState` owns timing-window lifecycle only; it does not own attack
  facts or semantic attack mutation.

### 4.7 Consequences

- Live play, replay, reconnect, and networking share one semantic mutation
  path.
- A successful command leaves the attack in one complete authoritative state;
  internal intermediate FSM positions do not become replay protocol.
- Command failure cannot be treated as a presentation event or silently
  completed by a caller.
- Exact command names, payloads, and internal calculation organization remain
  downstream Contract or implementation concerns.

## 5. Question 3: CurrentAttackState Content Boundary

### 5.1 Architectural Problem

Choosing `GameState` as the owner did not by itself determine what belongs in
`CurrentAttackState`. The current scene `AttackState` mixes several categories:
current-attack gameplay facts, values derivable from other state, rule-specific
mutable flags, and presentation or scene references. Copying that mixed object
into `GameState` would preserve existing ambiguity inside a new container.

The investigation therefore classified state by authority rather than by its
current class membership.

### 5.2 Boundary Investigation

The durable boundary must be sufficient to validate and execute semantic
attack commands and to serialize and resume an in-progress attack. It must not
duplicate facts already authoritative on ships, squadrons, upgrades, damage
cards, or other `GameState` entities. Stable identities can reference those
owners.

Information that is deterministically computable at the point of use remains
derived. This avoids creating two values that can disagree after replay,
reconnect, or protocol evolution.

Rule-specific mutable state remains on the runtime rule owner established by
ADR-004 and CON-004. The timing-window protocol retains timing lifecycle state
under ADR-005 and CON-005. Neither category moves into `CurrentAttackState`
merely because it participates in an attack.

### 5.3 Authority Classification

**Current-attack authoritative facts** belong in `CurrentAttackState` when
they are JSON-safe, specific to the active attack, required for semantic
validation, execution, continuation, cancellation, replacement, serialization,
or resumption, and not deterministically available from another accepted
authority.

**Derived information** remains calculated from authoritative facts.
Opportunities, display values, and deterministic rule calculations do not gain
authority by being convenient to cache or project. Timing-window controller
state remains governed separately by ADR-005 and CON-005.

**Rule-specific mutable state** remains on the applicable runtime upgrade,
damage-card, objective, or other accepted rule owner. H9 and ECM state do not
become attack-state fields.

**Timing lifecycle state** remains in `TimingWindowState`. Opportunities remain
freshly derived and are not stored as authoritative attack objects.

**Presentation and routing state** remains non-authoritative. Scene nodes,
modal progress, animation state, `InteractionFlow` payloads, projection data,
and UI selection state do not belong in canonical current-attack state.

### 5.4 Repository Evidence

- The current `AttackState` combines participant references, dice data,
  cached display names, rule-use flags, sub-step flags, deferred presentation
  handling, and scene object references.
- `GameState` serialization requires canonical JSON-safe state and stable
  reconstruction boundaries.
- ADR-004 and CON-004 already assign rule-specific mutable state to runtime
  rule owners.
- ADR-005 and CON-005 already assign timing lifecycle to `TimingWindowState`
  and require opportunities to be freshly derived.
- ADR-003, CON-003, and TEST-003 require projection and viewer-specific
  visibility to remain derived and non-authoritative.
- H9 requires current dice authority but does not require H9-owned state to
  move into the attack boundary.

### 5.5 Accepted Decision

`CurrentAttackState` stores current-attack-specific authoritative facts and
references other authoritative facts by stable identity. It does not store
information that is derived, rule-specific, timing-lifecycle-owned, or
presentational.

The accepted membership test is architectural and semantic. Exact fields,
serialization keys, command payloads, and reconstruction APIs are expressly
not decided here.

### 5.6 Consequences

- The canonical boundary can support legality, semantic mutation,
  persistence, replay, reconnect, and network equality without becoming a
  general attack framework.
- Existing mixed scene state must be classified before migration; current
  class membership does not establish future authority.
- Derived values are recomputed from canonical state, and rule-specific state
  remains independently testable on its accepted runtime owner.
- Projection may expose an authorized view of attack facts but cannot become
  the source used to authorize a command.

## 6. Architectural Principles

1. One authoritative owner exists for each gameplay fact.
2. `GameState` owns one canonical JSON-safe `CurrentAttackState`.
3. Replayable commands own semantic mutation.
4. A command represents an atomic semantic transaction, not an internal FSM
   edge.
5. Replay records decisions and ordering, not deterministic calculations.
6. `CurrentAttackState` stores current-attack facts, not derived information.
7. Facts already owned elsewhere are referenced rather than duplicated.
8. Rule runtime owners retain rule-specific mutable state.
9. `TimingWindowState` owns timing lifecycle only.
10. Projection, routing, scene mirrors, modal state, and UI remain
    non-authoritative.
11. Safe staged migration preserves one owner per migrated fact and cannot
    establish permanent split ownership.

## 7. Combined Decision Consequences

The three decisions form one boundary:

- Decision 1 identifies the authoritative state owner.
- Decision 2 identifies the authoritative semantic mutation surface.
- Decision 3 identifies the facts that may cross into that state boundary and
  preserves all adjacent accepted owners.

Together they give H9 and later attack timing-window consumers one source of
attack legality and mutation without broadening `TimingWindowState`, moving
rule-specific state, or granting authority to projection and scene workflow.

No further Project Owner architecture question remains within TIM-003's
scope. `ADR-001` has extracted the accepted architecture. Downstream documents
must consume that ADR and define implementation obligations without reopening
these decisions.

## 8. Downstream Document Updates Recorded At Acceptance

The ADR extraction and architecture-governance synchronization in this list
are now complete through `ADR-001` and the current governance records. The
remaining entries are retained as the historical downstream checklist.

After formal acceptance of TIM-003 documentation:

1. Extract the enduring state and transition ownership into the appropriate
   ADR under the BC-001 and BC-003 roadmap sequence.
2. Define any cross-component implementation obligations in the appropriate
   Contract without moving attack ownership into CON-005.
3. Update architecture roadmap and boundary-tracking documents to show the
   accepted target and migration posture.
4. Refine TWI-002 and related migration sequencing so they consume Model C and
   Model C-S rather than select ownership.
5. Update CAP-H9-001 only for traceability and retain rule behavior and
   rule-specific ownership in the CAP and its runtime owner.
6. Derive TEST-003-aligned verification for command ordering, serialization,
   replay, reconnect, networking, visibility, and projection in downstream
   implementation planning.

These updates may define implementation obligations and sequencing, but they
must not introduce permanent split ownership, scene-owned semantic mutation,
or attack-state authority in timing, rule, projection, or UI surfaces.

# ADR-001: Authoritative Current-Attack State And Transition Ownership

Status: Accepted

ADR-ID: ADR-001
Title: Authoritative Current-Attack State And Transition Ownership

Accepted by: Project Owner

Accepted date: 2026-07-17

Supersedes:
None

Superseded by:
None

Related:
- AT-001
- AT-002
- BC-001
- BC-003
- RG-003
- RG-004
- RG-014
- ADR-003
- ADR-004
- ADR-005
- CON-003
- CON-004
- CON-005

Inputs:
- `docs/architecture/decision_workbooks/TIM-003-authoritative-attack-state-and-transition-ownership.md`
- `docs/architecture/decision_workbooks/TIM-003-owner-decisions.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`

## 1. Context

Rules and game-flow transitions that operate during an active attack require
one authoritative source for command legality, semantic mutation, save/load,
replay, reconnect, networking, and downstream attack resolution.

The architecture must separate current-attack gameplay facts from timing-window
lifecycle, rule-specific mutable state, deterministic calculations, interaction
routing, and presentation state. It must also ensure that live play, replay,
and network execution use the same authoritative mutation path.

This ADR establishes that ownership boundary and mutation model for the active
attack.

## 2. Decision

### 2.1 CurrentAttackState Ownership

Model C is the target architecture.

`GameState` owns one canonical JSON-safe `CurrentAttackState` for the active
attack. `CurrentAttackState` is the sole authority for current-attack-specific
facts within its accepted boundary.

Scene attack objects, scene FSM state, `InteractionFlow`, projections, modal
state, and UI may consume, route, or mirror current-attack facts. They do not
own those facts independently and may not become alternative sources for
command legality or gameplay mutation.

Permanent split ownership of current-attack facts is prohibited.

### 2.2 Semantic Attack Mutation

Replayable commands own every semantic attack transition and every semantic
mutation of `CurrentAttackState`.

A command represents one atomic semantic transaction rather than one command
per internal FSM edge. Semantic attack transitions include attack entry,
progression, rule-result mutation, confirmation, cancellation, replacement,
and completion.

A command may perform the deterministic calculations and authoritative state
changes required to complete its semantic transaction atomically. Internal FSM
movement, animation, modal choreography, and transient scene coordination are
not independent semantic mutations and do not require separate commands.

Replay records accepted decisions and command order, not separately recorded
deterministic calculation steps. Replaying the same commands from the same
initial authoritative state must reproduce the same result.

### 2.3 CurrentAttackState Membership

A fact belongs in `CurrentAttackState` only when all of the following are true:

1. It is JSON-safe.
2. It is specific to the active attack.
3. It is required to validate, execute, continue, cancel, replace, serialize,
   or resume that attack.
4. It cannot be deterministically re-derived at the point of use from another
   accepted authoritative owner.

When a fact is already authoritative elsewhere in `GameState`,
`CurrentAttackState` references that owner through stable identity rather than
duplicating the fact.

`CurrentAttackState` does not own:

- deterministic calculations or other derived information;
- rule-specific mutable state;
- timing-window lifecycle state;
- derived timing-window opportunities;
- scene objects or scene-node references;
- interaction-routing or projection payloads; or
- modal, animation, selection, or other UI state.

### 2.4 Runtime Rule Ownership

Rule-specific mutable state remains on its accepted runtime owner. In
particular, upgrade-owned mutable state remains governed by ADR-004 and
CON-004. Participation in an attack does not move upgrade, damage-card,
objective, ability, or other rule-owned mutable state into
`CurrentAttackState`.

Replayable commands may coordinate an atomic semantic transaction across
`CurrentAttackState` and an existing rule-specific owner. This does not transfer
ownership between those state boundaries.

Rule implementations and Rule Capability Packages do not define competing
current-attack state or attack-transition policy.

### 2.5 Timing-Window Interaction

`TimingWindowState` owns timing-window lifecycle only under ADR-005 and
CON-005. It does not own current-attack facts, attack effects, attack dice,
rule-specific mutable state, or semantic attack-transition policy.

The Timing Window Orchestrator owns timing-window opening, re-derivation,
completion evaluation, cleanup coordination, and continuation coordination as
defined by ADR-005 and CON-005. When continuation is a semantic attack
transition, the replayable continuation command performs the authoritative
attack mutation. The orchestrator does not thereby become the attack-state or
attack-mutation owner.

Derived opportunities may read `CurrentAttackState` and accepted runtime rule
state. Opportunities do not become authoritative persistent attack state.

### 2.6 Projection And Interaction Routing

`InteractionFlow`, `FlowSpec`, `UIProjector`, scene controllers, scene FSMs,
modal routers, and UI remain derived and non-authoritative for current-attack
gameplay facts.

Projection may expose viewer-appropriate attack information and interaction
affordances. Visibility or absence in projection does not grant, remove, or
replace command authorization. Authoritative commands validate against
authoritative state.

### 2.7 Model C-S Migration Constraint

Model C-S is the accepted migration constraint for reaching Model C.

Migration may proceed in safe, semantically complete stages, subject to all of
the following enduring constraints:

1. Each migrated current-attack fact has exactly one authoritative owner at a
   time.
2. Temporary compatibility flow for a migrated fact is one way from canonical
   state to a non-authoritative consumer or mirror.
3. A compatibility surface may not write back as an independent authority.
4. Temporary compatibility boundaries may not become permanent split
   ownership.

Model C-S permits staged migration. It does not define a second target
architecture or an exception to Model C.

## 3. Architectural Rules

1. Every authoritative gameplay fact has one owner.
2. `GameState` owns one canonical JSON-safe `CurrentAttackState`.
3. Replayable commands own semantic attack mutation.
4. Commands represent atomic semantic transactions, not internal FSM edges.
5. Replay records decisions and command order, not deterministic calculations.
6. `CurrentAttackState` stores current-attack-specific authoritative facts,
   not derived information.
7. Facts already owned by another authoritative state owner are referenced,
   not duplicated.
8. Runtime rule owners retain rule-specific mutable state.
9. `TimingWindowState` owns timing-window lifecycle only.
10. Projection, interaction routing, scene mirrors, modal state, and UI remain
    non-authoritative.
11. Staged migration preserves one owner per migrated fact and may not create
    permanent split ownership.

## 4. Consequences

- Save/load and reconnect reconstruct the active attack from canonical
  `GameState`, not from scene or projection state.
- Replay and networking apply the same ordered semantic commands to the same
  authoritative current-attack state.
- Deterministic calculations are reproduced during authoritative command
  execution rather than independently recorded as replay decisions.
- Attack rules share one source for current-attack legality and outcomes while
  retaining their own rule-specific mutable state on accepted runtime owners.
- Timing-window capabilities may consume current-attack facts without moving
  attack authority into `TimingWindowState`, opportunities, or the
  orchestrator.
- Scene and UI code may retain presentation and interaction responsibilities
  but cannot become an alternative gameplay authority.
- Migration from scene-owned attack behavior may require temporary
  compatibility surfaces, but those surfaces remain one-way and
  non-authoritative.
- The project accepts migration cost in exchange for deterministic ownership,
  replay, reconnect, networking, and downstream rule integration.

## 5. Out Of Scope

This ADR does not define:

- concrete file or class placement beyond `GameState` ownership of the
  `CurrentAttackState` boundary;
- JSON fields, serialized keys, schemas, or versioning mechanics;
- APIs;
- command names, command payloads, or command-result schemas;
- attack-stage enumerations or internal FSM mechanics;
- exact calculation organization inside commands or resolvers;
- projection payload schemas or UI composition;
- migration slices, implementation sequencing, or compatibility-adapter
  design;
- Rule Capability Package behavior for a concrete rule;
- implementation Contracts, test strategies, or implementation workbooks; or
- a generic attack, rule, timing, or effect framework.

Those details remain the responsibility of downstream Contracts, verification
documents, capability packages, implementation workbooks, or implementation as
defined by document authority.

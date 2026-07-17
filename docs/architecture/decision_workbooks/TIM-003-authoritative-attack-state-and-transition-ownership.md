# TIM-003: Authoritative Attack State And Transition Ownership

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-07-17

Decision topic: Authoritative ownership of current-attack gameplay state and
attack lifecycle transitions

Prepared for: Project Owner acceptance
Date: 2026-07-16

Related roadmap boundaries: BC-001, BC-003, AT-001, AT-002

Related implementation planning: MA-TW-001, MA-H9-001, TWI-002

Companion decision record:
`docs/architecture/decision_workbooks/TIM-003-owner-decisions.md`

This workbook consolidates three accepted Project Owner decisions. It remains
a Decision Workbook rather than an ADR, Contract, implementation
specification, or authorization to change runtime code. Normative extraction
and implementation planning remain downstream work under
`docs/architecture/DOCUMENT_AUTHORITY.md`.

## 1. Purpose

TWI-002 exposed an unresolved architecture boundary around current-attack
facts and semantic attack transitions. The repository had a scene-owned attack
procedure and a serialized interaction-flow snapshot, but no accepted durable
owner for all rule-relevant current-attack facts.

TIM-003 now records the accepted resolution:

1. `GameState` owns one canonical JSON-safe `CurrentAttackState`.
2. Replayable commands own every semantic attack transition as an atomic
   semantic transaction.
3. `CurrentAttackState` stores current-attack-specific authoritative facts,
   while derived, rule-specific, timing-lifecycle, and presentation data remain
   on their accepted owners or surfaces.

The complete repository-backed reasoning is preserved in the companion
decision record. This workbook states the accepted boundary concisely so later
architecture and implementation documents can consume it without reopening
the Owner decisions.

## 2. Authority

Document authority is governed by
`docs/architecture/DOCUMENT_AUTHORITY.md`.

The accepted decisions are constrained by:

- ADR-003 and CON-003 for authoritative rule state, command validation and
  mutation, serialization, replay, networking, and non-authoritative
  projection;
- ADR-004 and CON-004 for rule-specific mutable state on runtime rule owners;
- ADR-005 and CON-005 for `TimingWindowState`, timing-window lifecycle,
  opportunities, continuation, and timing-window command authority; and
- TEST-003 for verification obligations.

TIM-001, TIM-002, TWI-001, TWI-002, MA-TW-001, MA-H9-001, CAP-H9-001,
repository code, and tests are evidence and planning inputs. They do not
supersede the accepted ADRs and Contracts.

## 3. Resolved Architecture Blocker

Repository evidence established that:

- scene code creates and advances the current attack;
- the scene-owned attack object contains rule-relevant participants and dice
  but has no canonical `GameState` serialization contract;
- `InteractionFlow` publishes a serialized snapshot for routing, reconnect,
  and projection but is non-authoritative for rule legality and mutation; and
- existing confirm and skip commands are publication markers rather than the
  authoritative owners of their semantic transitions.

TWI-002 requires H9 and the timing-window protocol to validate, mutate,
serialize, replay, reconnect, and network the same active attack. The accepted
decisions close the prior ambiguity by establishing one durable state owner
and one replayable mutation surface. No unresolved Owner question remains
within TIM-003's scope.

## 4. Accepted Decision 1: Current-Attack Ownership

### Decision

Model C is the target architecture:

- `GameState` owns one canonical JSON-safe `CurrentAttackState` for the active
  attack;
- `CurrentAttackState` is the sole authority for current-attack facts within
  its accepted boundary;
- scene attack objects, scene FSM state, `InteractionFlow`, projection, and UI
  may consume or mirror those facts but do not own them independently; and
- permanent split ownership of current-attack facts is prohibited.

Model C-S is the accepted migration posture. Migration may proceed in safe,
semantically complete stages, but each migrated fact has one authority at a
time. Temporary compatibility boundaries must flow one way from canonical
state to consumers and must not establish reverse authoritative writes or a
permanent second owner.

### Rationale

One `GameState`-owned boundary gives command validation, save/load, replay,
reconnect, networking, and downstream rules the same source of truth. Model
C-S permits controlled migration from the current scene workflow without
weakening the Model C destination.

## 5. Accepted Decision 2: Semantic Transition Ownership

### Decision

Replayable commands own every semantic attack transition. Each command
represents one atomic semantic transaction rather than one command per
internal FSM edge.

This includes semantic attack entry, progression, rule-result mutation,
confirmation, cancellation, replacement, and completion. A command may apply
the deterministic calculations and state changes required to complete its
transaction atomically. Pure presentation choreography and transient scene
coordination are not semantic transitions and remain non-authoritative.

Replay records accepted decisions and their command order, not separately
recorded calculation steps. Replaying the same commands from the same initial
state must reproduce the same authoritative result.

`TimingWindowState` owns timing-window lifecycle only. Timing-window use,
decline, and continuation commands remain governed by ADR-005 and CON-005;
they do not transfer attack facts or attack lifecycle ownership into
`TimingWindowState`.

### Rationale

Atomic semantic commands provide one mutation path for live play, replay, and
networking without coupling the command log to scene FSM mechanics. They also
prevent scene-first mutation followed by publication from becoming an
alternative authority path.

## 6. Accepted Decision 3: CurrentAttackState Boundary

### Decision

`CurrentAttackState` stores current-attack-specific authoritative facts. A
fact belongs in that boundary only when it is:

- JSON-safe;
- specific to the active attack;
- required to validate, execute, continue, cancel, replace, serialize, or
  resume that attack; and
- not deterministically re-derived at the point of use from another accepted
  authority.

`CurrentAttackState` references stable identities for facts already owned by
other authoritative `GameState` state rather than duplicating those facts.

The boundary excludes:

- deterministic calculations and other derived information;
- rule-specific mutable state owned under ADR-004 and CON-004;
- timing-window lifecycle state owned by `TimingWindowState`;
- opportunities, which remain freshly derived under ADR-005 and CON-005; and
- scene nodes, presentation choreography, `InteractionFlow` routing payloads,
  projections, modal state, and UI state.

### Rationale

The classification keeps the durable attack boundary sufficient for legality,
mutation, persistence, replay, reconnect, and networking without duplicating
other authoritative state or turning it into a rule, timing, or presentation
container.

## 7. Coherent Ownership Model

| Concern | Accepted authority |
| --- | --- |
| Current-attack-specific authoritative facts | `CurrentAttackState` owned by `GameState` |
| Semantic attack mutation | Replayable commands |
| Deterministic attack calculations | Derived during authoritative command execution or rule resolution |
| Timing-window lifecycle | `TimingWindowState` and the Timing Window Orchestrator under ADR-005 and CON-005 |
| Rule-specific mutable state | Existing runtime rule owner under ADR-004 and CON-004 |
| Candidate participant indexing | `RuleRegistry` as a static, non-authoritative index under ADR-005 and CON-005 |
| Projection and interaction routing | Derived, viewer-filtered, and non-authoritative |
| Save/load, replay, reconnect, and network reconstruction | Canonical `GameState` plus replayable command history as applicable |

State ownership and mutation ownership are complementary: `GameState` owns
the canonical state, while commands are the authoritative surface allowed to
change its semantic gameplay facts.

## 8. Architectural Principles

1. Every authoritative gameplay fact has one owner.
2. `GameState` owns one canonical JSON-safe `CurrentAttackState`.
3. Replayable commands own semantic gameplay mutation.
4. Commands represent atomic semantic transactions, not internal FSM edges.
5. Replay records decisions, not calculations.
6. `CurrentAttackState` stores authoritative facts, not derived information.
7. Existing authoritative facts are referenced, not duplicated.
8. Rule runtime owners retain rule-specific mutable state.
9. `TimingWindowState` owns timing lifecycle only.
10. Projection, interaction routing, scene mirrors, and UI are never
    authoritative gameplay state.
11. Staged migration must preserve single ownership and cannot establish a
    permanent split boundary.

## 9. Architectural Consequences

- Save/load and reconnect reconstruct the active attack from canonical
  `GameState`, not from scene state or projection payloads.
- Replay and networking apply the same ordered semantic commands to the same
  authoritative state; deterministic calculations are reproduced rather than
  separately recorded.
- Projection may expose viewer-appropriate current-attack information but
  cannot authorize commands or mutate attack state.
- H9 consumes and mutates authoritative attack facts through the accepted
  command boundary while retaining only H9-specific state on its runtime
  upgrade owner.
- Later ECM migration consumes the same attack authority without moving ECM
  state out of its runtime upgrade owner.
- Tarkin remains outside attack-state ownership but uses the same timing-window
  and replayable-command principles.

## 10. Required Downstream Updates After Acceptance

After TIM-003 is formally accepted:

1. Record the enduring ownership and transition rules in the appropriate ADR
   under the BC-001 and BC-003 roadmap sequence.
2. Define any required cross-component implementation obligations in the
   appropriate Contract without broadening CON-005's timing-window authority.
3. Update the architecture roadmap, boundary candidates, reality-gap register,
   and current-state maps to reflect the accepted target and migration posture.
4. Refine TWI-002 so its attack-state prerequisite, dependency order,
   checkpoints, H9 work, and verification consume these decisions rather than
   choose architecture.
5. Re-evaluate MA-TW-001 and MA-H9-001 sequencing only where the accepted
   prerequisite changes implementation order.
6. Update CAP-H9-001 only for traceability; CAPs do not acquire attack-state or
   lifecycle ownership.
7. Establish TEST-003-aligned evidence for serialization, replay, reconnect,
   networking, visibility, cleanup, and command ordering in downstream
   planning.

## 11. Explicit Deferrals

TIM-003 does not define:

- concrete class or file placement beyond the accepted `GameState` ownership
  boundary;
- JSON fields, serialization keys, or versioning mechanics;
- command names, payloads, result schemas, or APIs;
- attack-stage enumerations or internal FSM mechanics;
- migration slices, sequencing details, or compatibility-adapter design;
- scene reconstruction APIs;
- H9 opportunity derivation or effect implementation;
- ECM or Tarkin migration sequencing; or
- a generic attack, rule, timing, or effect framework.

Those details remain downstream ADR extraction, Contract definition,
implementation workbooks, or implementation work according to document
authority.

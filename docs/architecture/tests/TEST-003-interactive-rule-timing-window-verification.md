# TEST-003: Interactive Rule Timing-Window Verification

Test Strategy ID: TEST-003
Title: Interactive Rule Timing-Window Verification
Status: Accepted
Created: 2026-07-11
Owner: Project Owner
Accepted by: Project Owner
Accepted date: 2026-07-11

Related:
- ADR-003
- ADR-004
- ADR-005
- CON-003
- CON-004
- TIM-001
- CAP-UPG-001
- CAP-ECM-001
- CAP-H9-001

## Acceptance Note

TEST-003 is accepted as the authoritative verification strategy for
interactive rule timing-window behavior governed by ADR-005.

It defines verification obligations only. It does not define
`TimingWindowState` fields, discovery APIs, orchestrator classes, migration
sequencing, generic effect-composition semantics, or production test
implementations.

Acceptance establishes TEST-003 as the normative verification architecture for
interactive timing-window capabilities.

This document does not authorize broad rule rollout by itself and does not
change the authority of ADRs or Contracts.

## 1. Purpose

TEST-003 defines the mandatory verification evidence required for Rule
Capability Package implementations that participate in authoritative timing
windows.

It exists because ADR-005 makes timing windows authoritative lifecycle objects
and makes the Timing Window Orchestrator responsible for lifecycle, discovery
orchestration, recalculation, and continuation. TEST-003 defines the evidence
needed to prove that implementations preserve that architecture across
commands, projection, save/load, replay, network, reconnect, and live UI
routes.

## 2. Problem Statement

The Tarkin and Electronic Countermeasures pilots produced large amounts of
unit-level and command-level evidence, but later defects showed that green
tests were not enough when key protocol paths were not exercised end to end.

The missing evidence categories were specific:

- Command and state behavior was tested, but the live ECM Status Phase modal
  route was missing.
- Startup failed because the real router construction path was not exercised.
- The ECM choice command executed, but Status Phase did not continue because
  the live submission path bypassed the continuation helper.
- Component-level tests manually supplied continuation state that production
  had to create through the live protocol.
- Save/load, replay, network, and reconnect behavior were often proven
  separately rather than as one authoritative command protocol.

This was not a test quantity failure. It was a missing evidence-category and
missing end-to-end protocol-verification failure.

H9 Turbolasers shows the same risk before implementation: a future Attack
Modify timing window must prove player ordering, one-at-a-time opportunity
resolution, recalculation after each modifier, command-history sequencing,
projection derivation, and continuation through `confirm_attack_dice`.

## 3. Scope

TEST-003 applies to CAP implementations that do any of the following:

- open or participate in an authoritative timing window,
- expose mandatory or optional rule opportunities,
- block or delay normal game-flow continuation,
- require player choice,
- coexist with another opportunity in the same timing window,
- create, invalidate, or alter later opportunities,
- require replay, save/load, reconnect, or network synchronization.

Non-interactive timing rules may use a reduced subset only when the CAP records
why no player-visible projection, no choice ordering, no continuation block,
and no temporary opportunity state are applicable. They still must prove
authoritative state ownership, command or resolver mutation, serialization,
replay, network/reconnect, visibility, cleanup, and any relevant continuation
impact.

## 4. Required Verification Lifecycle

Applicable tests must prove the complete timing-window protocol, not only
isolated helper classes:

```text
window entry
    -> participant discovery
    -> runtime opportunity derivation
    -> player-visible projection
    -> player selection
    -> replayable command submission
    -> validation and authoritative mutation
    -> opportunity re-derivation
    -> repeated resolution where needed
    -> final continuation command
    -> window exit and cleanup
```

Each implementation must identify the authoritative owner at every lifecycle
point and prove that derived surfaces do not become authoritative.

## 5. Mandatory Evidence Categories

### 5.1 Window Lifecycle

Tests must prove:

- the timing window opens at the accepted game-flow point,
- the window remains open while blocking opportunities remain,
- the window does not open when preconditions are absent,
- the window survives save/load, replay initialization, network mirror, and
  reconnect when it is active,
- the window closes only through the accepted continuation, cancellation,
  replacement, or cleanup path.

### 5.2 Participant And Opportunity Discovery

Tests must prove:

- participants are discovered from the accepted static index or local call site
  without making `RuleRegistry` authoritative,
- concrete opportunities are derived from authoritative serialized runtime
  state,
- opportunity identity is grounded in capability identity and authoritative
  runtime-source identity,
- opportunities do not use synthetic persistent UUIDs as an independent source
  of identity,
- stale projection payloads cannot create or resurrect opportunities.

### 5.3 Player Control And Ordering

Tests must prove:

- the correct controlling player is projected and validated,
- wrong-player submissions are rejected,
- all currently selectable optional opportunities are presented when game rules
  allow the player to choose order,
- deterministic ordering is used only for stable presentation, comparison, or
  rule-prescribed automation,
- the system does not silently choose an optional opportunity merely because it
  appears first.

### 5.4 One-At-A-Time Resolution And Re-Derivation

Tests must prove:

- one selected opportunity resolves through one replayable command path at a
  time,
- after each accepted use or decline command, remaining opportunities are
  re-derived from authoritative state,
- one opportunity can invalidate another,
- one opportunity can create another,
- repeated use or repeated decline of the same current-window opportunity is
  rejected,
- derived projection is cleared or recalculated after each resolution.

### 5.5 Commands And Authoritative Mutation

Tests must prove:

- use, decline, marker, mutation, and continuation commands are registered,
  serializable, and replayable where applicable,
- `CommandApplicability`, `FlowSpec.allowed_commands`, and concrete command
  `validate()` agree,
- every command that can express an illegal action is rule-gated, including
  marker commands and final mutation commands,
- command payloads contain enough serialized identity to replay without UI,
- mutations occur through replayable commands or accepted resolver/follow-up
  paths, not UI state.

### 5.6 Continuation

Tests must prove:

- normal game-flow continuation is blocked while blocking opportunities remain,
- after a successful opportunity command, the orchestrating owner recalculates
  unresolved opportunities before continuation,
- the final continuation command is submitted or enabled only after no blocking
  opportunities remain,
- the continuation command validates its own legality and performs the
  authoritative mutation,
- individual rule commands, UI components, modal routers, submission callers,
  and `CommandProcessor` do not independently decide that the timing window is
  complete,
- exactly one final continuation occurs for a completed window.

### 5.7 Projection And Live Interaction Route

Tests must prove:

- `UIProjector` derives the visible prompt or affordance from authoritative
  state,
- `InteractionFlow.payload` is JSON-safe derived/reconnect payload and not the
  gameplay owner,
- the live router/modal/controller construction path exists and can dispatch
  the accepted command,
- the live path routes through the same authoritative submission orchestration
  required by the timing window,
- both use and decline actions can be submitted from the live path,
- missing or stale projected payload cannot make stale state authoritative.

### 5.8 Serialization And Save/Load

Tests must prove:

- active window identity and any required derived projection payload serialize
  safely,
- rule-specific mutable state remains on its authoritative owner,
- save/load during an unresolved window serializes authoritative state and
  re-derives the same pending opportunity set from that state,
- save/load after use or decline preserves guards, costs, card state, selected
  state, and cleanup status as defined by the CAP,
- save/load after window exit does not resurrect stale opportunities or stale
  guards.

### 5.9 Replay

Tests must prove:

- replay history contains every use, decline, mutation, and continuation
  command in authoritative order,
- replay reconstructs opportunity availability from authoritative state and
  command history,
- replay does not depend on UI-local state or projection-only payload,
- replay covers both accepted-use and explicit-decline paths,
- replay covers inter-command state when a rule creates pending authorization
  or temporary guard state.

### 5.10 Networking And Reconnect

Tests must prove:

- the authoritative peer produces and broadcasts commands in accepted sequence,
- clients mirror command results in server sequence order,
- remote clients do not synthesize use, decline, effect, or continuation
  commands locally,
- out-of-order delivery cannot apply later continuation before earlier
  opportunity commands,
- reconnect reconstructs active windows from serialized authoritative state and
  re-derives pending opportunities from that state,
- reconnect preserves temporary guards, costs, selected state, and derived
  projection without storing opportunities as authoritative persistent state,
- remote command-effect handling classifies every mirrored command required by
  the protocol.

### 5.11 Cleanup And Failure Behavior

Tests must prove:

- temporary timing-window state has one authoritative owner,
- creation, mutation, and cleanup/removal points are explicit,
- cleanup occurs on accepted window exit, cancellation, flow replacement,
  attack end, phase transition, save/load reconstruction outside the window, or
  other CAP-defined cleanup trigger,
- rejected use or decline commands do not trigger continuation,
- repeated cleanup cannot clear unresolved required guard state,
- failure paths leave projection and authoritative state consistent.

### 5.12 Effect Interaction Boundary

Tests must prove:

- passive effects remain automatic and are not presented as optional choices,
- optional effects that coexist in the same timing window are resolved in
  player-controlled order when rules permit,
- one optional effect cannot bypass another blocking opportunity,
- downstream effects read authoritative post-command state,
- the implementation does not introduce a generic effect-composition engine
  unless a later accepted ADR or Contract does so.

### 5.13 Visibility And Information Filtering

Tests must prove, where applicable:

- owner-only information is visible only to the owning player,
- opponent-hidden information remains hidden,
- observer and spectator views receive correctly filtered projections,
- reconnect reconstructs the correct viewer-specific projection,
- serialization of authoritative state does not imply unrestricted visibility,
- projection and filtering remain derived surfaces and never become gameplay
  authority,
- hidden information cannot be used to authorize commands,
- visibility filtering remains consistent after replay, save/load, reconnect,
  and network synchronization.

## 6. Test Layers

### 6.1 Unit Tests

Unit tests cover predicates, command validation, command execution,
serialization helpers, cleanup helpers, and source-owner isolation.

Unit tests are required, but they cannot substitute for protocol or live-route
evidence when a timing window opens UI, blocks continuation, or crosses
command boundaries.

### 6.2 Protocol / Integration Tests

Protocol tests cover the complete authoritative lifecycle across window entry,
participant discovery, opportunity derivation, command submission, mutation,
re-derivation, repeated resolution, final continuation command, window exit,
and cleanup.

Protocol tests are mandatory for every interactive timing-window CAP.

### 6.3 Projection / UI Routing Tests

Projection and UI routing tests cover the real `UIProjector`, modal-router, and
modal/controller construction path used in production.

They must prove that the live path can display the prompt, dispatch use and
decline commands, and route through the accepted authoritative submission path.

### 6.4 Replay / Network Tests

Replay and network tests cover command-history order, mirrored command order,
host/client agreement, reconnect reconstruction, and remote side-effect
classification.

They must compare expected and observed hot-seat, network host, and network
client command sequences and identify the first divergence when a failure is
found.

### 6.5 Runtime Smoke Evidence

Runtime smoke evidence is focused manual or automated production-scene evidence
that the live path works in the actual game scene.

Runtime smoke evidence complements automated tests. It does not replace
automated evidence where automated protocol, projection, replay, save/load, or
network testing is practical.

## 7. CAP Verification Matrix

Every timing-window CAP must include or reference a verification matrix with
these fields:

| Field | Required content |
| --- | --- |
| Timing-window identity | Flow, phase, step, and lifecycle interval. |
| Opener | Command, resolver, or orchestrator path that opens the window. |
| Participants | Static index/call-site participants considered for opportunity derivation. |
| Source owners | Authoritative runtime state owners for each opportunity. |
| Controller / priority rule | Which player chooses and how order is determined. |
| Use and decline commands | Replayable command names and payload identity requirements. |
| Authoritative state changed | State owners and fields changed by each command. |
| Re-derivation trigger | Successful commands or lifecycle events that force recalculation. |
| Continuation command | Existing replayable command that exits or continues the window. |
| Cleanup events | Events that remove temporary state and derived projection. |
| Unit tests | Predicate, validation, mutation, and helper evidence. |
| Protocol tests | End-to-end lifecycle evidence. |
| UI-route tests | Projector/router/modal construction and dispatch evidence. |
| Serialization tests | Save/load and serialized-state evidence. |
| Replay tests | Command-history and replay reconstruction evidence. |
| Network/reconnect tests | Host/client mirror, ordering, reconnect, and remote-effect evidence. |
| Visibility tests | Visibility rules, information filtering, viewer-specific projection, and hidden-information verification evidence. |
| Runtime smoke trace | Focused manual or automated live-path trace. |

Missing applicable evidence means the implementation is incomplete for
TEST-003 purposes.

## 8. Acceptance And Rollout Gate

A timing-window capability must not be marked `Integrated` or
implementation-complete unless all applicable TEST-003 obligations have passing
evidence.

Gate rules:

- Automated evidence is required where practical.
- Runtime smoke evidence complements automated evidence and does not replace it.
- Environment-only failures must be separated from product regressions and test
  expectation failures.
- "Nothing was run" is not a passing verification result.
- Full-suite commands must include intended directories and subdirectories.
- Generated runtime artifacts must not be committed unless intentionally
  tracked.
- Project Owner authority over final integration status remains governed by
  CON-003.

Codex may recommend readiness for owner review. Codex may not mark a Rule
Capability Package `Integrated`.

## 9. Relationship To Other Documents

ADR-005 defines timing-window ownership and lifecycle authority.

The forthcoming Timing Window Lifecycle Contract should define implementation
obligations, schemas, interfaces, and cleanup mechanics.

TEST-003 defines mandatory verification evidence for interactive rule
timing-window behavior.

Rule Capability Packages define rule-specific behavior, applicability,
ownership, and evidence mapping.

`.skills/testing_standards.md` remains developer guidance for writing tests
unless superseded by accepted architecture documents.

TEST-003 does not redefine ADR-004 runtime upgrade ownership, CON-003
capability scope, or CON-004 runtime upgrade state ownership.

## 10. Examples

### 10.1 Tarkin Plus Another Start-Of-Ship-Phase Rule

Tests must prove Tarkin does not immediately continue to ship selection while
another blocking start-of-Ship-Phase opportunity remains. After Tarkin use or
decline, opportunities are re-derived before normal ship selection is enabled.

### 10.2 Multiple ECM Status Phase Choices

Tests must prove the owning player can choose ready or decline for each
available ECM source, each choice is replayable, opportunities are re-derived
after each choice, exactly one final `start_round` occurs, and clients mirror
the authoritative sequence without synthesizing `start_round`.

### 10.3 H9 Plus Another Attack Modify Rule

Tests must prove the attacker controls optional modifier order, H9 use mutates
authoritative dice immediately, availability is re-derived after H9 use or
decline, another optional modifier may still resolve, and
`confirm_attack_dice` is the only normal exit after blocking opportunities are
resolved.

## 11. Non-Goals

TEST-003 does not:

- define `TimingWindowState` fields,
- define participant APIs,
- define orchestrator classes,
- implement production tests,
- implement H9,
- migrate Tarkin or ECM,
- define a generic effect-composition engine,
- change ADR-005 decisions.

## 12. Accepted Owner Decisions

### 12.1 TEST-003 Authority

TEST-003 is accepted as the authoritative verification strategy for interactive
timing-window behavior governed by ADR-005.

Acceptance establishes TEST-003 as the normative verification architecture for
interactive timing-window capabilities.

Acceptance does not authorize implementation rollout by itself and does not
change the authority of ADRs or Contracts.

### 12.2 Verification Matrix Authority

The TEST-003 verification matrix is accepted as the normative verification
structure for interactive timing-window capabilities.

CON-005 shall derive implementation obligations from these verification
categories rather than redefining, renaming, or narrowing them.

If future architectural evolution requires additional verification categories,
TEST-003 should be revised rather than modifying CON-005.

Architectural principle:

> Verification architecture owns evidence categories; implementation contracts
> own implementation obligations.

### 12.3 Evidence Waivers

Temporary evidence waivers are permitted only in exceptional circumstances.

Waiver rules:

- Project Owner approval is required.
- Codex may recommend waivers but may not approve them.
- Every waiver must be explicitly recorded in the applicable CAP.

Each waiver shall identify:

- waived TEST-003 evidence category,
- reason,
- implementation impact,
- planned resolution,
- Project Owner approval.

Waivers may defer verification evidence.

Waivers shall not defer:

- architecture,
- authority ownership,
- lifecycle definition,
- implementation contracts,
- accepted architectural obligations.

A Rule Capability Package containing unresolved waivers shall not be marked
Integrated until all applicable waivers have been resolved.

These accepted decisions do not reopen ADR-003, ADR-004, ADR-005, CON-003, or
CON-004.

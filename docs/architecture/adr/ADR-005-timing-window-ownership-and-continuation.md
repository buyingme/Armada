# ADR-005: Timing Window Ownership and Continuation

Status: Accepted

ADR-ID: ADR-005
Title: Timing Window Ownership and Continuation

Accepted by: Project Owner

Accepted date: 2026-07-11

Supersedes:
None

Superseded by:
None

Related:
- ADR-003
- ADR-004
- CON-003
- CON-004
- TIM-001
- CAP-UPG-001
- CAP-ECM-001
- CAP-H9-001

Inputs:
- `docs/architecture/decision_workbooks/TIM-001-timing-window-ownership-and-continuation-workbook.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`

## Acceptance Note

ADR-005 extracts the accepted TIM-001 owner decisions into an architecture
decision record.

After acceptance, ADR-005 is the normative architecture source for
timing-window ownership and continuation; TIM-001 remains supporting decision
evidence.

This ADR does not redesign TIM-001. It preserves ADR-003 rule-surface
authority, ADR-004 runtime upgrade ownership, CON-003 capability traceability,
and CON-004 runtime upgrade state ownership.

This ADR does not authorize broad implementation by itself. A follow-up Timing
Window Contract is required to define implementation obligations.

## 1. Context

Interactive timing windows can contain one or more rule opportunities that must
resolve before normal flow continues.

The need for common timing-window ownership became clear from the first
upgrade-rule pilots:

- Grand Moff Tarkin needs a start-of-Ship-Phase opportunity before normal ship
  activation continues.
- Electronic Countermeasures needs Status Phase and attack-time opportunities
  whose choices must remain replayable and deterministic.
- H9 Turbolasers requires Attack Modify opportunities to be resolved one at a
  time, with available opportunities recalculated after each resolution.

Without a common lifecycle owner, timing-window continuation can drift into
individual commands, `GameManager` helper paths, `InteractionFlow` payloads, or
UI routing. That creates replay, network, save/load, reconnect, and projection
risk.

Existing architecture already establishes the surrounding boundaries:

- ADR-003 delegates rule authority by responsibility surface and does not make
  `RuleRegistry`, `RuleSurface`, projection, or UI the whole rule architecture.
- CON-003 requires behavior-changing rules to trace state, validation,
  execution, projection, serialization, replay, network, visibility, and tests.
- ADR-004 and CON-004 make ship-owned runtime upgrade instances the default
  owner for mutable upgrade state, including rule-specific runtime state and
  trigger guards.
- Commands and command history remain the replayable mutation path for durable
  gameplay changes.

TIM-001 accepted a narrow timing-window lifecycle model to fit inside these
boundaries.

## 2. Decision

Timing windows are authoritative lifecycle objects.

A dedicated serialized `TimingWindowState` owned by `GameState` represents the
lifecycle of an active timing window.

The Timing Window Orchestrator owns:

- timing-window lifecycle,
- discovery orchestration,
- recalculation after opportunity resolution,
- continuation after the window is complete.

Commands remain the only replayable mutation surface for gameplay state
changes, rule choices, declines, effects, and continuation commands.

Rule opportunities are distinct from timing windows. A timing window identifies
the current game-flow interval. Rule opportunities identify currently eligible
rule interactions within that interval.

Rule opportunities are derived from authoritative runtime state. Opportunity
identity is grounded in authoritative runtime sources and capability identity.
Timing-window opportunities must not use synthetic persistent UUIDs as an
independent source of identity. The timing window must not duplicate rule
truth.

`TimingWindowState` must not store a mutable queue of opportunities.

After every successful replayable command that resolves one opportunity, the
orchestrator re-derives all currently eligible opportunities from
authoritative state before the window may continue.

If blocking opportunities remain after recalculation, the timing window remains
open.

If no blocking opportunities remain after recalculation, the orchestrator
submits or enables the existing replayable continuation command associated with
that timing window. The continuation command validates its own legality and
performs the authoritative mutation.

Individual rule commands, UI components, modal routers, submission callers, and
`CommandProcessor` do not independently decide that the timing window is
complete.

`RuleRegistry` remains a static participant index for timing-window discovery.
It may help identify participating capabilities and accepted call sites, but it
must not become an authoritative active rule-state store.

`RuleRegistry` must not determine concrete runtime eligibility, the current
controlling player, player-selectable opportunity order, timing-window
completion, continuation, or authoritative mutation.

Concrete runtime opportunities must be derived by rule-specific participants
from authoritative serialized state.

Rule-specific eligibility, use/decline guards, costs, mutable effects, and
runtime upgrade state remain on their existing authoritative owners under
ADR-003, ADR-004, CON-003, CON-004, and the relevant Rule Capability Package.

`InteractionFlow`, `FlowSpec`, `RuleSurface`, `UIProjector`, scene controllers,
modal routers, and UI remain non-authoritative derived surfaces for timing
windows.

When game rules permit a player to choose the order of optional opportunities,
the orchestrator preserves that control. It presents the currently selectable
opportunities for that player, and the player chooses exactly one opportunity
to resolve next.

Deterministic ordering may be used for stable presentation, replay comparison,
mandatory rule-prescribed ordering, and non-choice automation explicitly
allowed by the timing-window contract. Deterministic ordering must not silently
choose optional opportunities for the player.

This ADR does not introduce a generic rule engine, generic upgrade framework,
or effect-composition engine.

## 3. Non-Decisions

This ADR does not define:

- serialized fields of `TimingWindowState`,
- discovery APIs,
- orchestrator classes,
- implementation sequencing,
- migration sequencing,
- exact nested timing-window mechanics,
- whether nested windows are supported in the first implementation,
- the first migration target,
- effect-composition semantics,
- concrete rule-opportunity payload schemas,
- concrete `InteractionFlow` payload schemas,
- concrete command payload schemas.

Those belong in later artifacts.

## 4. Consequences

Future timing-based rules use the common timing-window lifecycle instead of
inventing command-local, UI-local, or projection-local continuation ownership.

Rule Capability Packages continue to own rule-specific behavior traceability.
They must still identify active state, validation, execution, projection,
serialization, replay, network, visibility, and tests under CON-003.

Runtime upgrade rule state remains governed by ADR-004 and CON-004. This ADR
does not move mutable upgrade state, card state, trigger guards, costs, or
rule-specific state out of runtime upgrade instances.

The Timing Window Orchestrator becomes the architectural owner for lifecycle,
recalculation, and continuation, but it does not own rule effects.

`RuleRegistry` can participate in discovery as a static index, but it remains
non-authoritative for active state.

`InteractionFlow`, `FlowSpec`, `RuleSurface`, `UIProjector`, and UI remain
derived presentation, applicability, or callback surfaces. They must not be used
as authoritative timing-window lifecycle or rule-state owners.

Commands remain required for replayable choices, declines, effects, and
continuations. Timing-window behavior must therefore remain compatible with
command history, replay, network mirroring, save/load, and reconnect.

A follow-up Timing Window Contract must define implementation obligations for
`TimingWindowState`, discovery, recalculation, continuation, serialization,
replay, network, reconnect, projection, and cleanup.

TEST-003 must define verification obligations for timing-window behavior,
including command ordering, recalculation, replay, network, save/load,
reconnect, visibility, and projection-derived-state checks.

This ADR adds one narrow lifecycle architecture surface. It does not authorize
a broad runtime rewrite or a generic rule engine.

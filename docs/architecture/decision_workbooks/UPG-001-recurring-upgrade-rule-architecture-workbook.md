# UPG-001: Recurring Upgrade Rule Architecture Workbook

Status: Draft  
Decision topic: Recurring upgrade-rule architecture for the first upgrade batch  
Supports: Future owner decision and possible ADR candidate  
Primary evidence: Upgrade evidence report, CP-001, ADR-003, CON-003, CAP-UPG-001  
Related boundaries: BC-005, BC-005A, BC-007, BC-008, BC-009, BC-012  
Related tasks: AT-004, AT-007, AT-008, AT-009, AT-011  

This workbook is not an ADR.

It prepares an owner decision for recurring upgrade-rule concerns before the
first batch of behavior-changing upgrades is implemented. It does not implement
code, design a full generic upgrade framework, create Rule Capability Packages
for all upgrades, or change any upgrade integration status.

## 1. Problem Statement

The project is preparing to implement the first batch of upgrade rules.

The repository currently contains 18 upgrade JSON records. All observed upgrade
records have `rules_integration.status: NOT_INTEGRATED`. Their printed rule
texts and metadata already identify recurring behavior surfaces:

- start-of-phase command choice and command-token grants,
- command dial reveal and command-token spend windows,
- command value and repair/squadron/maneuver modifiers,
- attack dice and critical effect choices,
- exhaustible upgrade cards and status-phase readying,
- range or distance-based effects,
- damage-deck and hidden-information effects.

Existing architecture evidence shows:

- Upgrade assignments are roster/setup facts.
- Upgrade assignments serialize through `FleetShipEntry`,
  `FleetUpgradeAssignment`, `FleetRoster`, and setup payloads.
- Fleet/setup validation consumes upgrade assignment data.
- Setup uses assigned upgrades for fleet-point calculation.
- No generic active runtime upgrade-state collection was observed on
  `ShipInstance`.
- `ShipInstance` serializes mutable ship state, command dials, command tokens,
  damage, shields, activation, position, owner, roster id, and static ship
  identity.
- Active behavior-changing rules require runtime state, command/resolver/setup
  paths, projection, serialization, replay, network/reconnect, visibility, and
  tests under ADR-003 and CON-003.

The recurring problem is not whether every upgrade should use one generic
framework. ADR-003 already rejects treating any single surface as the whole
architecture. The recurring problem is that the first batch of upgrades will
reuse the same unresolved decisions: active upgrade ownership, exhausted upgrade
state, timing windows, command-history representation, visibility, and minimum
test obligations.

If those decisions are not made once before implementation begins, each upgrade
will need to answer them locally. That increases the risk of inconsistent state
ownership, non-replayable choices, UI-only predicates, hidden-information leaks,
and metadata drifting ahead of evidence.

## 2. Decision Options

### Option A: Per-Upgrade Local Decisions Only

Each upgrade is implemented and documented through its own Rule Capability
Package. Each package independently decides runtime ownership, timing-window
handling, command-history representation, visibility, and tests.

This option relies only on ADR-003 and CON-003.

### Option B: Narrow Upgrade Architecture Decision For Recurring Concerns

Create a focused owner decision for the first upgrade batch that establishes
shared rules for:

- where active upgrade assignments are owned at runtime,
- how exhaustible/readied upgrade state is durably represented,
- how optional timing-window choices are represented,
- how choices, declines, and follow-up effects enter command history,
- how prompts and private payloads are classified for visibility,
- what minimum tests are required while TEST-003 is absent.

Each upgrade still receives its own Rule Capability Package when implemented.
The decision does not define a full generic framework and does not require every
future upgrade to fit one mechanism.

### Option C: Build Only The Grand Moff Tarkin Slice First

Use CAP-UPG-001 as the pilot. Make only the owner decisions needed for Grand
Moff Tarkin, then let later upgrades expose additional needs.

This option delays decisions about exhaustible upgrade cards, attack modifiers,
critical effects, command-dial rewrites, range auras, and damage-deck effects.

### Option D: Full Upgrade Framework Decision Now

Design a broad upgrade runtime framework before implementation. It would cover
all upgrade categories, all future timing windows, all state shapes, and all
future upgrade behaviors.

This option is outside the requested scope but is listed as a rejected boundary
so the owner can distinguish a narrow recurring-concern decision from a broad
framework effort.

## 3. Evaluation Of Options

| Criterion | Option A: Per-upgrade local | Option B: Narrow recurring decision | Option C: Tarkin-only pilot | Option D: Full framework |
| --- | --- | --- | --- | --- |
| Fits ADR-003 / CON-003 | Yes | Yes | Yes | Risky if it implies a new runtime subsystem before owner direction |
| Keeps scope small | Medium | High | High | Low |
| Handles first-batch recurring concerns | Low | High | Low-medium | High |
| Avoids premature generic design | High | High | High | Low |
| Reduces inconsistent runtime ownership | Low | High | Medium | High |
| Reduces replay/network risk | Medium | High | Medium | High if correct, high cost if wrong |
| Supports Rule Capability Packages | Yes | Yes | Yes | Yes, but may overconstrain them |
| Useful for Codex safety | Medium | High | Medium | Medium-high after completion |
| Migration cost | Low initially, higher later | Medium-low | Low initially, higher later | High |
| Evidence support | Medium | High | High for Tarkin only | Low for full future set |

### Option A Evidence Assessment

Evidence supports using Rule Capability Packages per upgrade. CON-003 already
requires each behavior-changing rule to identify ownership, surfaces, tests, and
integration evidence.

Evidence also shows this is insufficient by itself for the first batch. Several
planned upgrades repeat the same unresolved questions:

- `grand_moff_tarkin`, `wulff_yularen`, and token-spend liaison cards touch
  command-token state.
- `electronic_countermeasures`, `wulff_yularen`, and
  `assault_concussion_missiles` require upgrade exhaustion/readiness state.
- `defense_liaison`, `weapons_liaison`, and `leia_organa` touch command dials
  and command reveal timing.
- `h9_turbolasers`, `dominator`, and `enhanced_armament` touch attack dice
  modification.
- `overload_pulse`, `assault_concussion_missiles`, and `dodonnas_pride` touch
  critical-effect timing and damage resolution.

If every package chooses locally, repeated answers may diverge.

### Option B Evidence Assessment

Evidence supports a narrow recurring-concern decision.

CP-001 identifies no generic active runtime upgrade-state collection on
`ShipInstance`, while CON-003 says upgrades must identify roster/static source,
active runtime state needs, gameplay execution owner, projection impact,
save/load/replay/network impact, and tests. CAP-UPG-001 then confirms that even
the smallest safe COMMANDER candidate cannot proceed without an active ownership
decision.

The first batch also includes exhaustible, command-window, attack-window,
critical-window, and visibility-sensitive upgrades. Those are recurring
architecture concerns, not isolated implementation details.

### Option C Evidence Assessment

Evidence supports Grand Moff Tarkin as a pilot for command-token grants, phase
timing, command-history determinism, reconnect projection, and visibility.

Evidence does not support Tarkin as representative of the full first batch.
Tarkin does not cover:

- upgrade exhaustion/readiness,
- attack dice modification,
- critical effect replacement or selection,
- defense-token Accuracy exceptions,
- command-dial rewrites,
- range auras,
- damage-deck hidden information.

Tarkin alone is therefore too narrow to drive the recurring architecture.

### Option D Evidence Assessment

Evidence does not support designing a full generic upgrade framework now.

The repository has evidence for the first 18 upgrade records and the known rule
surfaces. It does not have evidence for all 100+ future upgrades. ADR-003 also
establishes capability-based integration and preserves multiple valid
implementation surfaces rather than requiring a universal runtime subsystem.

## 4. Recommended Decision

Recommended owner decision: choose Option B.

Make a narrow upgrade-rule architecture decision before implementing the first
batch. The decision should cover only recurring concerns that appear in the
observed upgrade records and the completed evidence report:

1. Active runtime ownership for upgrade assignments.
2. Durable state for exhaustible/readied upgrades.
3. Timing-window and optional-choice handling.
4. Command-history expectations for choices, declines, and follow-up effects.
5. Visibility policy for prompts and private payloads.
6. Minimum test obligations while TEST-003 is absent.

The decision should explicitly preserve ADR-003 and CON-003:

- Rule Capability Packages remain the integration evidence model.
- `RuleRegistry` remains one valid implementation surface, not the whole
  architecture.
- Commands, resolvers, state classes, projection, serialization, replay,
  network, and visibility remain valid ownership surfaces by responsibility.
- Static metadata remains descriptive and does not prove behavior is active.

The decision should explicitly avoid:

- a full generic upgrade framework,
- broad future-upgrade design,
- one package for all upgrades,
- integration status advancement,
- implementation details beyond ownership and contract obligations.

## 5. Consequences

Positive consequences:

- First-batch upgrades can share consistent answers for recurring state,
  timing, command-history, visibility, and testing questions.
- Rule Capability Packages for individual upgrades become smaller and more
  consistent because they can reference the accepted recurring decision.
- Codex risk is reduced: future sessions will not invent runtime ownership or
  timing-window handling per upgrade.
- Save/load, replay, network, reconnect, and hidden-information obligations are
  considered before behavior is implemented.
- The project avoids both extremes: local ad hoc decisions and a premature full
  framework.

Negative consequences:

- One additional owner decision is required before implementation begins.
- Some implementation work may wait for the decision.
- The decision may need a small follow-up contract before coding starts.
- If the first batch changes materially, the decision may need revision or a
  second workbook.

Migration consequences:

- Existing upgrade JSON should remain `NOT_INTEGRATED` until package evidence
  and owner approval justify status changes.
- Existing fleet/setup serialization remains evidence, not final active runtime
  ownership.
- Existing command, resolver, projection, serialization, replay, and network
  paths should be reused where they already own the relevant responsibility.

Testing consequences:

- While TEST-003 is absent, the owner must define minimum test obligations for
  the upgrade batch or explicitly accept transitional sufficiency per package.
- Any implemented upgrade should have tests mapped to its applicable surfaces:
  validation, execution, projection, serialization, replay, network/reconnect,
  visibility, and metadata/status alignment.

## 6. Open Owner Decisions

The owner needs to decide:

1. Which runtime surface owns active upgrade assignments after setup.
2. Whether active upgrade ownership is derived from serialized setup/roster
   state, copied into runtime ship/player/game state, or owned by another
   explicit state surface.
3. Which state surface owns exhausted/readied upgrade-card state.
4. Whether optional upgrade choices require explicit decline commands.
5. How timing-window prompts are inserted into or represented alongside
   `InteractionFlow`.
6. Whether upgrade follow-up effects are represented as direct commands,
   observer follow-up commands, resolver results, or another accepted command
   history shape.
7. Which visibility categories apply to:
   - owner-only prompts,
   - public choices,
   - hidden command dials,
   - hidden damage-deck payloads,
   - public token/dice/damage results.
8. Minimum test obligations before a package may advance from Draft to
   Identified, Implemented, Tested, or Integrated while TEST-003 is absent.
9. Whether the first batch needs one small follow-up contract before
   implementation, or whether the accepted decision plus CON-003 is sufficient.

## 7. Minimal Contract Needed After Decision

If the owner accepts Option B, the minimal follow-up contract should be narrow.

It should define only the recurring obligations needed by first-batch upgrade
implementation:

- Active upgrade assignment ownership rule.
- Exhaustible/readied upgrade state ownership rule.
- Timing-window representation rule for optional upgrade choices.
- Command-history rule for choices, declines, and follow-up effects.
- Serialization rule for upgrade source state, upgrade mutable state,
  interaction payloads, and command payloads.
- Replay rule requiring deterministic reconstruction from command history and
  serialized state.
- Network/reconnect rule requiring authoritative command sync, snapshot
  durability, and projection reconstruction.
- Visibility rule requiring owner/public/private classification before
  implementation.
- Transitional test minimum while TEST-003 is absent.
- Rule Capability Package reference rule: each implemented upgrade still needs
  its own package or package slice under CON-003.

This contract should not:

- introduce a full upgrade framework,
- define all future upgrade behavior,
- replace commands, resolvers, state classes, `RuleRegistry`, `UIProjector`,
  `StateFilter`, serialization, replay, or networking,
- mark any upgrade integrated.

## 8. Recommended Pilot Sequence

The pilot sequence should cover recurring architecture concerns with the fewest
upgrade rules.

1. `grand_moff_tarkin`
   - Covers active commander assignment, start-of-Ship-Phase timing, optional
     choice, command-token grant, command history, replay, network/reconnect,
     and visibility.

2. `electronic_countermeasures`
   - Covers exhaustible upgrade state, defense-token spend exception, Accuracy
     interaction, and status-phase ready cost.

3. `defense_liaison` or `weapons_liaison`
   - Covers command-token spend, before-reveal timing, command-dial rewrite,
     command visibility, and replayable dial mutation.

4. `h9_turbolasers` or `dominator`
   - Covers attack dice modification, player choice during attack effects,
     dice-pool mutation, and command-history representation of attack choices.

5. `overload_pulse` or `assault_concussion_missiles`
   - Covers critical-effect timing, defense-token or hull-zone damage mutation,
     and damage-resolution interaction.

6. `redemption` or `leia_organa`
   - Covers range/distance query ownership and cross-ship effect application.

`general_dodonna` should not be the first pilot. It is valuable later because it
tests private damage-deck choice, hidden information, deck-order mutation, and
discard behavior, but those risks are higher than needed for the first
architecture slice.

## 9. Readiness Assessment

Recommended next architecture artifact:

- ADR candidate or owner decision record for first-batch recurring upgrade-rule
  architecture.

Recommended status:

- Needs owner decision before implementation of the first upgrade batch.

Confidence:

- 8/10.

Rationale:

- Evidence is strong for recurring concerns in the 18 existing upgrade records.
- CP-001, ADR-003, CON-003, and CAP-UPG-001 align on the main unresolved
  ownership and surface questions.
- Confidence is not higher because the exact first twenty upgrades may include
  records not yet present in the repository, and TEST-003 is not accepted.

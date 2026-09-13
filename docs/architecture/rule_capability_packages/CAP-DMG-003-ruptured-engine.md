# CAP-DMG-003: Ruptured Engine

Package ID: CAP-DMG-003
Title: Ruptured Engine
Status: Draft
Component Type: damage card
Source Component: `ruptured_engine`
Related ADRs: ADR-003, ADR-006, ADR-010, ADR-012, ADR-013
Related Contracts: CON-003
Related Context Packs: CP-001
Related Tests: TEST-003; existing and required tests listed below
Created: 2026-09-12
Last Updated: 2026-09-12
Owner: Project Owner
Test Owner: Capability implementation owner; Project Owner review required
Capability Classification: mixed

## 1. Purpose

This package traces each faceup Ruptured Engine card instance after its ship
executes a Maneuver. After obstacle consequences converge, if the ship's
canonical speed dial is greater than one, each still-applicable instance makes
the ship suffer one damage on a hull zone chosen by its owner.

SMI-067/091 require Owner-approved CON-003 `Integrated` status before accepted
release/cutover depends on this slice. Its complete path may participate
earlier only after the whole workbook reaches Owner Decision 27's
`candidate-code-complete` condition in the unreleased 7/10/7 Integration
Candidate, without changing this Draft status.

Classification rationale: **mixed**. The effect originates from a damage-card
instance but participates in core Maneuver post-execution re-evaluation.

## 2. Scope

### Included Behavior

- Re-deriving all faceup Ruptured Engine instances when baseline Maneuver
  re-evaluation finds no remaining purpose-specific obstacle obligations.
- Canonical speed-dial `> 1` applicability, one effect per instance, and
  same-timing player order.
- Owner-selected hull zone; one suffered damage through shields; authority-only
  draws, passive application, survival, recovery, and exact-once return.

### Excluded Behavior

- Temporary collision speed, pre-obstacle invocation, and facedown copies.
- Directly dealing a facedown card instead of suffering damage.
- Generic post-execution effect, damage-card, Maneuver consequence,
  continuation, queue, stack, or FSM ownership.

### Dependencies

- ADR-006 active Maneuver execution identity and still-`OPEN` return boundary.
- Baseline SMI-064 re-evaluation with no remaining applicable obstacle
  obligations, plus survival re-evaluation; no persisted convergence marker is required.
- Stable public identity for each faceup DamageCard instance.
- Existing hull-zone/shield state, authority deck, passive ledger, and reusable
  one-point damage/draw/application helpers.

### Assumptions

- Applicability is re-derived after station or other prior effects may have
  discarded a source card or destroyed the ship.
- Maneuver invokes and awaits this package; it does not own card applicability,
  hull choice, damage, or exact-once state.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `ruptured_engine`
- Rules reference: card text in `damage_cards.json`; RRG timing and Damage rules

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: damage-deck loading; `src/core/damage/damage_card.gd`
- Metadata/status: no static CON-003 status claim; this package is `Draft`.

### Activation Conditions

- After all applicable obstacle consequences converge, an individual source
  card remains faceup on a surviving ship whose canonical speed dial is greater than one.

### Runtime Prerequisites

- Source instance identity, matching activation/execution identity, obstacle
  current absence of remaining obstacle obligations, canonical speed,
  rules-assigned ship-owner entitlement, legal hull
  zones, shields/hull, deck, and unresolved status.
- Current production observes raw `execute_maneuver`, collapses matching copies,
  and directly deals one facedown card before the accepted post-obstacle boundary.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | Each faceup `DamageCard` instance on `ShipInstance` plus Ruptured-Engine-specific pending state | The card instance supplies applicability; choice/exact-once state binds it to one execution after baseline re-evaluation finds no remaining obstacle obligations. | SMI-067, SMI-AC-027 |
| Validation | Ruptured-Engine-specific replayable choice/resolution command boundary | It validates that the submitter is the rules-assigned actor—the affected ship's owner—plus source identity/faceup status, execution, current eligibility, speed, hull zone, survival, order, and unresolved state. | ADR-003; CON-003 |
| Execution | Ruptured-Engine-specific command using one-point damage helpers | It applies suffered damage to the chosen hull zone; Maneuver and persistent direct-draw command do not own it. | Card text; RRG Damage; SMI-067 |
| Projection | `UIProjector` and Ruptured-Engine hull-zone/order route | Projection re-derives current applicable source instances and ship-owner legal zones. | ADR-010; TEST-003 |
| Serialization | `ShipInstance`, deck/ledger, active execution, and Ruptured-Engine-specific pending state | Source, order, choice, damage, and completion reconstruct without a generic obstacle-converged or stage marker. | SMI-080; ADR-013 |
| Replay | `CommandProcessor` history and deterministic authority deck progression | Per-instance choices and damage replay after remaining obstacle obligations are absent in accepted order. | ADR-012; SMI-081 |
| Network | Authority command processing plus passive application-result/snapshot paths | Only the rules-assigned ship owner chooses; authority mutates/draws; passive peers do not synthesize. | ADR-012; ADR-013 |
| Visibility | `StateFilter` and passive damage representation | Faceup source, choice, shields/hull, and counts are public; facedown identity/deck order stay hidden. | ADR-013 |
| Tests | Ruptured Engine package verification suite and runtime smoke owner | It owns unit, protocol, UI, persistence, replay, Network, visibility, destruction, re-derivation, and runtime smoke evidence. | CON-003; TEST-003; Section 8 |

All nine canonical CON-003 surfaces are **Required** for this mixed capability.
Exact implementation filenames may remain deferred until implementation.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Optional | Current `execute_maneuver` observer | Current call site is too early; registry may discover applicability but owns no mutation/state. |
| RuleSurface | Required | SMI-067 post-obstacle boundary | Explicit post-convergence invocation is required. |
| Commands | Required | `PersistentEffectDamageCommand` is current nonconforming evidence | Require instance-bound hull-zone choice/resolution and passive application contract. |
| Resolvers | Required | `ManeuverRuleResolver` speed predicate exists | Reuse pure predicate only after current state and per-instance multiplicity are preserved. |
| State Classes | Required | `ShipInstance.faceup_damage`; `DamageCard` lacks stable identity | Stable source identity and purpose-specific pending/exact-once state are missing. |
| Setup | Not Applicable | Damage card behavior begins in live ship state | No setup mutation. |
| UI Projection | Required | Current preview warning only | Authoritative post-obstacle hull-zone/order interaction is missing. |
| Serialization | Required | Current card/deck serialization is partial | Instance identity and pending choice/progress must round-trip. |
| Replay | Required | Existing history tests cover current direct draw only | Post-obstacle per-instance choices, draws, and destruction need proof. |
| Networking | Required | Existing damage application pattern is partial | Host/passive/reconnect evidence at accepted timing is missing. |

## 6. Runtime State

### Required Runtime State

- Stable faceup source-card instance identity.
- Matching activation and active Maneuver execution identities.
- Current canonical speed dial and the re-derived absence of remaining
  purpose-specific obstacle obligations. This absence is derived, not persisted
  as a generic `obstacle_converged` or Maneuver-stage marker.
- Per-source-instance pending/resolved fact, selected hull zone, and current
  shields/hull/deck/application state.

The concrete representation is deferred and must not deduplicate by `effect_id`.

### Lifecycle

- Created by: authoritative re-derivation when no applicable obstacle obligation remains.
- Updated by: player order/zone choice and Ruptured-Engine-specific command.
- Consumed by: accepted one-point damage for that source instance.
- Removed or expired by: completion, source discard/inactivity, or exceptional termination.

### Persistence

- Save/load path: source identity, active execution, and pending choice; eligibility
  is re-derived from remaining obligations rather than a persisted stage marker.
- Replay path: ordered per-instance choice/damage commands.
- Network/reconnect path: filtered snapshot and viewer-authorized results.

### Cleanup

- Cleanup owner: Ruptured-Engine-specific boundary with ADR-006 terminal cleanup.
- Cleanup trigger: resolution, source inactivity, ship destruction, or identity invalidation.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/effects/rules/damage_cards/ship/ruptured_engine.gd`; `src/core/damage/damage_card.gd`; `src/core/state/ship_instance.gd`; `src/core/movement/maneuver_rule_resolver.gd` | Predicate/source exist; timing and multiplicity are nonconforming. |
| Commands | `src/core/commands/persistent_effect_damage_command.gd` | Current direct-facedown semantic is incorrect for suffered damage. |
| Resolvers | `src/core/movement/maneuver_rule_resolver.gd` | Speed predicate is reusable; effect-ID deduplication is not. |
| Tests | `tests/unit/test_rule_ruptured_engine.gd`; `test_maneuver_rule_resolver.gd`; persistent command tests | Current behavior passes but does not prove accepted behavior. |
| Documentation | Card data; SMI-064, SMI-067, SMI-080/081, SMI-091; ADR-006 | Governing post-obstacle timing and ownership. |
| Related Rule Capability Packages | CAP-OBS-001, CAP-OBS-002, CAP-OBS-003 | These converge first; they do not own Ruptured Engine. |

## 8. Test Evidence

### Unit Tests

- Existing tests prove current registration, speed predicate, one direct draw,
  command history, and basic save/load only.
- Outstanding: post-obstacle re-derivation, source discarded by station,
  canonical versus temporary speed, legal hull choice, shields, multiple source
  instances/order, facedown inactivity, exact once, and rejection rollback.

### Integration Tests

- Outstanding: obstacles -> re-derive -> each Ruptured Engine -> return or
  exceptional termination, including destruction and multiple effects.

### Replay Tests

- Outstanding: post-obstacle command placement, per-instance choices/draws, and no duplication.

### Serialization Tests

- Outstanding: stable source identity and save/load after obstacles and between instances.

### Network Tests

- Outstanding: rules-assigned ship-owner validation, authority-only draws/follow-ups, passive
  application/non-synthesis, order, rejection, and reconnect.

### Visibility Tests

- Outstanding: public source/choice/result with hidden facedown identities/deck order.

### Regression Tests

- Outstanding: no pre-obstacle trigger; no trigger at speed 0/1 or after source discard.

### TEST-003 Verification Matrix

| Field | Required package evidence |
| --- | --- |
| Timing-window identity | Ship Activation / matching live ADR-006 Maneuver execution / remaining post-execution effects after re-derivation finds no remaining purpose-specific obstacle obligation, once per source instance. |
| Opener | Baseline Maneuver re-evaluation derives absence of remaining obstacle obligations, current survival/speed, and currently faceup Ruptured Engine instances; it does not read or create a generic convergence/stage marker. |
| Participants | Every then-applicable faceup Ruptured Engine instance, affected ship, rules-assigned ship owner, legal hull zones/shields, authority damage deck, and other accepted same-timing effects. |
| Source owners | Individual public faceup `DamageCard` instances on `ShipInstance`; Ruptured-Engine-specific pending choice/guard; existing ship/deck/ledger owners. |
| Controller / priority rule | The affected ship's owner chooses each hull zone and same-player same-timing order; first-player ordering applies across players under SMI-067. |
| Use and decline commands | One mandatory instance-bound hull-zone resolution command per source; decline is Not Applicable. Payload binds source-card, activation, execution, and chosen zone, not a generic obstacle-stage identity. Exact filename deferred. |
| Authoritative state changed | Selected hull-zone shields/hull, authority deck/damage state, per-source exact-once state, passive representation, and exceptional destruction state. |
| Re-derivation trigger | Each obstacle completion before entry, each accepted Ruptured Engine command, source discard/inactivity, target destruction, or recovery installation; derive remaining obligations every time. |
| Continuation command | Purpose-specific completion returns to the matching live Maneuver boundary; normal Maneuver completion is available only after no remaining post-execution obligation exists. Exact filename deferred. |
| Cleanup events | Per-instance resolution, source discard/inactivity, target destruction, exceptional activation termination, or Maneuver retirement. |
| Unit tests | Required derived-entry predicate, no generic marker, source identity, actor/order, speed, zone/shield/draw, exact-once, rejection, and destruction tests. |
| Protocol tests | Required obstacles -> re-derive remaining obligations -> project/order -> resolve each source -> Maneuver completion or exceptional termination lifecycle. |
| UI-route tests | Required ship-owner hull-zone/order projector/router/modal construction, dispatch, rejection recovery, and absence before obstacle obligations clear. |
| Serialization tests | Required stable source identity and recovery after obstacle commands or between pending instances, with eligibility re-derived rather than staged. |
| Replay tests | Required obstacle-command order followed by per-instance choices/damage/destruction without a persisted convergence marker or duplication. |
| Network/reconnect tests | Required actor validation, host-only mutation/draw/follow-up, passive application/non-synthesis, ordered re-derivation, and reconnect. |
| Visibility tests | Required public source/zone/result with authority-private facedown identities and deck order. |
| Runtime smoke trace | Outstanding production-scene trace from last obstacle obligation through all Ruptured Engine instances to Maneuver completion/termination. |

## 9. Risk Assessment

### Serialization / Replay / Network / Visibility Impact

- Serialization impact: high; post-obstacle choices can remain pending.
- Replay impact: high; re-derived source set, choices, and random draws are semantic.
- Network impact: high; authority-only progression must wait for ship-owner choices.
- Visibility impact: high; public faceup source/result coexist with hidden damage identities.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | high | Timing after variable obstacle sequence | Cross-capability ordered replay tests. |
| Serialization impact | high | Pending choices between source instances | Persist purpose-specific source/progress. |
| Network impact | high | Player choice and authority draws | TEST-003 end-to-end tests. |
| Visibility impact | high | Hidden facedown draw | ADR-013 filtering/application tests. |
| Migration impact | high | Current hook/primitive conflict with authority | Replace at post-obstacle boundary. |
| Complexity | high | Re-derivation, multiplicity, damage, destruction | Purpose-specific state with low-level helpers only. |

## 10. Integration Status

Current Status: Draft
Evidence Summary:

- Card data, source state, current predicate/hook, and focused tests exist.
- Accepted post-obstacle timing, damage semantics, instance identity, recovery,
  and distributed verification do not.

Outstanding Work:

- Implement/verify all applicable surfaces, migrate the current hook, complete
  CON-003/TEST-003 evidence, and obtain explicit Owner approval.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Draft preserves post-obstacle and per-card-instance authority. |

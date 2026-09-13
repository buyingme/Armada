# CAP-DMG-001: Thruster Fissure

Package ID: CAP-DMG-001
Title: Thruster Fissure
Status: Draft
Component Type: damage card
Source Component: `thruster_fissure`
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

This package traces each faceup Thruster Fissure card instance: when its ship
commits a Navigate speed-dial change of one or more during Determine Course,
that instance makes the ship suffer one damage before Move Ship. The ship owner
chooses the affected hull zone because the card does not specify one.

SMI-067 and SMI-091 require this package to reach Owner-approved CON-003
`Integrated` before accepted release/cutover depends on it. Its complete path
may participate earlier only after the whole workbook reaches Owner Decision
27's `candidate-code-complete` condition in the unreleased 7/10/7 Integration
Candidate, without changing this Draft status.

Classification rationale: **mixed**. The effect originates from a damage-card
instance but participates in the core Maneuver commitment lifecycle.

## 2. Scope

### Included Behavior

- Triggering once for every applicable faceup Thruster Fissure instance on the
  committed Navigate speed change, before any ship movement.
- Excluding temporary collision speed reduction and unchanged speed.
- Ship-owner hull-zone choice; one point of suffered damage through shields;
  authority-only draws, passive application, survival, recovery, and ordering.
- ADR-006 exceptional termination when this pre-move damage destroys the ship.

### Excluded Behavior

- Other speed changes, damage cards, and Navigate source-selection rules.
- Directly dealing a facedown card instead of suffering damage.
- A generic damage-card effect, timing-window, Maneuver consequence,
  continuation, queue, stack, or FSM owner.

### Dependencies

- Atomic ADR-006 Maneuver commitment exposing committed starting/resulting
  speed and the matching active Maneuver execution identity while Maneuver stays `OPEN`.
- Stable public identity for every faceup DamageCard instance.
- Existing ship hull-zone/shield state, authority damage deck, passive damage
  ledger, and reusable one-point damage/draw/application helpers.

### Assumptions

- The active Maneuver boundary invokes and awaits this package but does not own
  its source card, hull-zone choice, damage, or exact-once state.
- Same-player same-timing order and first-player cross-player order follow SMI-067.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `thruster_fissure`
- Rules reference: card text in `damage_cards.json`; RRG Commands/Navigate and timing rules

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: damage-deck loading; `src/core/damage/damage_card.gd`
- Metadata/status: damage-card data has no CON-003 integration-status claim;
  package status is the authoritative traceability status.

### Activation Conditions

- An individual `DamageCard` instance is faceup on the active ship when an
  accepted Navigate Maneuver commitment changes the canonical speed dial by at least one.

### Runtime Prerequisites

- Source card instance identity, matching activation/Maneuver execution,
  committed speed-change evidence, rules-assigned ship-owner entitlement, legal hull zones,
  shields/hull, damage deck, and unresolved status for that instance.
- Current production instead observes `execute_maneuver`, tests only whether
  any matching card exists, and directly deals one facedown card.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | Each faceup `DamageCard` instance on `ShipInstance` plus Thruster-Fissure-specific pending state | The card instance is the active rule source; choice/exact-once state binds that source to one activation/execution. | SMI-067, SMI-AC-027; `damage_card.gd` |
| Validation | Thruster-Fissure-specific replayable choice/resolution command boundary | It validates that the submitter is the rules-assigned actor—the affected ship's owner—plus faceup source identity, committed non-temporary speed change, execution identity, hull zone, survival, and unresolved status. | ADR-003; CON-003 |
| Execution | Thruster-Fissure-specific command using one-point damage helpers | It applies suffered damage to the chosen zone; neither Maneuver nor `PersistentEffectDamageCommand` owns this semantic. | Card text; RRG Damage; SMI-067 |
| Projection | `UIProjector` and Thruster-Fissure hull-zone route | Projection derives the pending source instance and ship-owner legal zones from canonical state. | ADR-010; TEST-003 |
| Serialization | `ShipInstance`, damage deck/ledger, active execution, and Thruster-Fissure-specific pending state | Source identity, choice, damage, and completion must reconstruct exactly. | SMI-080; ADR-013 |
| Replay | `CommandProcessor` history and deterministic authority deck progression | Per-instance choices and results replay in accepted order. | ADR-012; SMI-081 |
| Network | Authority command processing plus passive application-result/snapshot paths | Only the rules-assigned ship owner chooses; only authority draws and originates follow-ups. | ADR-012; ADR-013 |
| Visibility | `StateFilter` and passive damage representation | Faceup source, hull-zone choice, shields/hull, and counts are public; facedown identities/deck order stay hidden. | ADR-013 |
| Tests | Thruster Fissure package verification suite and runtime smoke owner | It owns unit, protocol, UI, persistence, replay, Network, visibility, destruction, chronology, and runtime smoke evidence. | CON-003; TEST-003; Section 8 |

All nine canonical CON-003 surfaces are **Required** for this mixed capability.
Exact implementation filenames may remain deferred until implementation.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Optional | Current rule is registered as an `execute_maneuver` observer | Current call site is wrong; a narrow discovery hook may remain, not execution ownership. |
| RuleSurface | Required | SMI-067 committed speed-change boundary | Must expose this package before Move Ship, not a shared post-execute observer. |
| Commands | Required | `PersistentEffectDamageCommand` is current nonconforming evidence | Require replayable instance-bound hull-zone choice/resolution and passive result application. |
| Resolvers | Required | `ManeuverRuleResolver` preview predicate exists | Preview may be reused after preserving multiplicity; authoritative applicability is re-derived. |
| State Classes | Required | `ShipInstance.faceup_damage`; `DamageCard` lacks stable instance identity | Stable instance identity and purpose-specific exact-once/pending state are outstanding. |
| Setup | Not Applicable | Damage card enters play through damage state, not setup | No setup mutation is introduced. |
| UI Projection | Required | Current preview warning only | Authoritative hull-zone interaction and re-entry route are missing. |
| Serialization | Required | Current cards serialize faceup/effect data | Instance identity and pending resolution must be added and round-tripped. |
| Replay | Required | Existing command history and rule tests are partial | Per-instance order, hull choice, draws, and pre-move destruction need proof. |
| Networking | Required | Existing damage application pattern is partial | Host/passive/reconnect behavior for this timing is missing. |

## 6. Runtime State

### Required Runtime State

- Stable source DamageCard instance identity and faceup status.
- Matching activation and active Maneuver execution identities.
- Committed starting/resulting speed sufficient to prove a qualifying Navigate change.
- Per-source-instance pending/resolved fact, selected hull zone, and current
  shield/hull/deck/application state.

The concrete representation is deferred; it must not be a deduplicated list of effect IDs.

### Lifecycle

- Created by: authoritative re-derivation immediately after qualifying Maneuver commitment.
- Updated by: player order/zone choice and Thruster-Fissure-specific command.
- Consumed by: accepted one-point damage for that source instance.
- Removed or expired by: completion, source becoming inactive, or ADR-006 exceptional termination.

### Persistence

- Save/load path: card instance, active execution, and pending choice/progress.
- Replay path: ordered per-instance choice/damage commands.
- Network/reconnect path: filtered snapshot and viewer-authorized application results.

### Cleanup

- Cleanup owner: Thruster-Fissure-specific boundary with ADR-006 terminal cleanup.
- Cleanup trigger: resolution, source inactivity, ship destruction, or identity invalidation.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/damage/damage_card.gd`; `src/core/state/ship_instance.gd`; `src/core/effects/rules/damage_cards/ship/thruster_fissure.gd`; `src/core/movement/maneuver_rule_resolver.gd` | Source/predicate exist; timing and multiplicity are nonconforming. |
| Commands | `src/core/commands/persistent_effect_damage_command.gd` | Direct facedown draw is the wrong damage semantic for this card. |
| Resolvers | `src/core/movement/maneuver_rule_resolver.gd` | Preview deduplicates effect IDs and is not authoritative execution. |
| Tests | `tests/unit/test_rule_thruster_fissure.gd`; `test_maneuver_rule_resolver.gd` | Current behavior passes focused tests but does not prove accepted behavior. |
| Documentation | Card data; SMI-067, SMI-080/081, SMI-091; ADR-006 | Governing timing, ownership, recovery, and completion. |
| Related Rule Capability Packages | Other same-timing card packages, if present | Ordering is re-derived without transferring ownership. |

## 8. Test Evidence

### Unit Tests

- Existing tests prove current registration/basic trigger/save-load behavior only.
- Outstanding: qualifying/nonqualifying committed change, temporary reduction
  exclusion, legal hull-zone choice, shields, per-instance multiplicity/order,
  facedown inactivity, exact once, and rejection rollback.

### Integration Tests

- Outstanding: atomic commitment -> each Thruster Fissure -> Move Ship or
  exceptional termination, including multiple copies and other same-timing effects.

### Replay Tests

- Outstanding: per-instance order, choices, draws, and no duplicate resolution.

### Serialization Tests

- Outstanding: stable card identity and save/load during each pending choice.

### Network Tests

- Outstanding: rules-assigned ship-owner validation, host-only follow-ups/draws, passive
  application, command order, and reconnect before movement.

### Visibility Tests

- Outstanding: public source/choice/result with hidden facedown identities/deck order.

### Regression Tests

- Outstanding: current late post-execute trigger and direct-facedown behavior are removed.

### TEST-003 Verification Matrix

| Field | Required package evidence |
| --- | --- |
| Timing-window identity | Ship Activation / matching live ADR-006 Maneuver execution / committed Navigate speed-change boundary during Determine Course, before Move Ship, once per source instance. |
| Opener | Accepted atomic Maneuver commitment exposes a qualifying non-temporary canonical speed change and matching activation/execution identities, then re-derives applicable faceup instances. |
| Participants | Every applicable faceup Thruster Fissure instance, affected ship, rules-assigned ship owner, legal hull zones/shields, authority damage deck, and other accepted same-timing effects. |
| Source owners | Individual public faceup `DamageCard` instances on `ShipInstance`; Thruster-Fissure-specific pending choice/guard; existing ship/deck/ledger owners. |
| Controller / priority rule | The affected ship's owner chooses each hull zone and same-player same-timing order; first-player ordering applies across players under SMI-067. |
| Use and decline commands | One mandatory instance-bound hull-zone resolution command per source; decline is Not Applicable. Payload binds source-card, activation, execution, and chosen-zone identities. Exact filename deferred. |
| Authoritative state changed | Selected hull-zone shields/hull, authority deck and damage state, per-source exact-once state, passive representation, and exceptional destruction state. |
| Re-derivation trigger | Each accepted instance command, source inactivity, ship destruction, or recovery installation; re-derive remaining same-timing obligations before Move Ship. |
| Continuation command | Purpose-specific completion returns to the same live Maneuver boundary; Move Ship cannot begin until no Thruster Fissure obligation remains. Exact existing/future command filename deferred. |
| Cleanup events | Per-instance resolution, source becoming facedown/discarded, target destruction, exceptional activation termination, or Maneuver retirement. |
| Unit tests | Required qualifying-change, temporary-change exclusion, source identity, actor/order, zone/shield/draw, exact-once, rejection, and destruction tests. |
| Protocol tests | Required commitment -> re-derive -> project/order -> resolve each source -> Move Ship or exceptional termination lifecycle. |
| UI-route tests | Required ship-owner hull-zone/order projector/router/modal construction, dispatch, rejection recovery, and no late post-execute prompt. |
| Serialization tests | Required stable source identity and recovery before/between pending instances. |
| Replay tests | Required commitment and per-instance command order, choices, damage, destruction, and no duplication. |
| Network/reconnect tests | Required actor validation, host-only mutation/draw/follow-up, passive non-synthesis/application, ordering, and reconnect before movement. |
| Visibility tests | Required public source/zone/result with authority-private facedown identities and deck order. |
| Runtime smoke trace | Outstanding production-scene trace from qualifying commitment through all instances to Move Ship or exceptional termination. |

## 9. Risk Assessment

### Serialization / Replay / Network / Visibility Impact

- Serialization impact: high; a pre-move choice blocks continuation.
- Replay impact: high; per-instance order and damage draws are semantic.
- Network impact: high; ship-owner choice and authority-only follow-ups must converge.
- Visibility impact: high; public source/result coexist with hidden damage identities.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | high | Ordered per-instance choices before movement | End-to-end history tests. |
| Serialization impact | high | Live pre-move choice | Persist source identity/pending state. |
| Network impact | high | Timing blocks movement across peers | TEST-003 protocol tests. |
| Visibility impact | high | Hidden facedown draw | ADR-013 tests. |
| Migration impact | high | Current hook and damage primitive are wrong | Replace at accepted boundary; retain only low-level helpers. |
| Complexity | high | Atomic commit, multiplicity, damage, destruction | Purpose-specific command/state only. |

## 10. Integration Status

Current Status: Draft
Evidence Summary:

- Card data, source state, current rule hook, preview, and focused tests exist.
- Accepted timing, damage semantics, stable instance identity, recovery, and distributed evidence do not.

Outstanding Work:

- Implement/verify all applicable surfaces, migrate current hook, complete
  CON-003/TEST-003 evidence, and obtain explicit Owner approval.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Draft reflects accepted per-card-instance and pre-move boundaries only. |

# CAP-DMG-002: Damaged Controls

Package ID: CAP-DMG-002
Title: Damaged Controls
Status: Draft
Component Type: damage card
Source Component: `damaged_controls`
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

This package traces each faceup Damaged Controls card instance during one
Maneuver that overlaps at least one ship or obstacle. Each applicable instance
deals one facedown damage card exactly once for that Maneuver at the
Owner-assigned SMI-064 boundary.

SMI-067/091 require Owner-approved CON-003 `Integrated` status before accepted
release/cutover depends on this slice. Its complete path may participate
earlier only after the whole workbook reaches Owner Decision 27's
`candidate-code-complete` condition in the unreleased 7/10/7 Integration
Candidate, without changing this Draft status.

Classification rationale: **mixed**. The effect originates from a damage-card
instance but participates at two accepted core Maneuver consequence boundaries.

## 2. Scope

### Included Behavior

- One resolution per applicable faceup Damaged Controls instance per Maneuver.
- Item 3 of SMI-064 when a ship collision exists; otherwise item 4 after
  Squadron displacement and before obstacle consequences for obstacle-only overlap.
- A ship-plus-obstacle Maneuver resolves each source instance at item 3 only,
  never again at item 4.
- Direct facedown-card dealing, authority-only draw, passive result application,
  same-timing order, survival, recovery, and exact-once return.

### Excluded Behavior

- Hull-zone selection or shield absorption; the rule directly deals a facedown card.
- Intermediate collision-search attempts or movement through an obstacle.
- Generic overlap-effect, damage-card, Maneuver consequence, continuation,
  queue, stack, or FSM ownership.

### Dependencies

- ADR-006 active Maneuver execution identity and still-`OPEN` consequence boundary.
- Stable public identity for each faceup DamageCard instance.
- Authoritative final ship/obstacle overlap facts and canonical obstacle detection.
- Existing authority damage deck, facedown damage state, passive ledger, and
  direct facedown draw/application helpers.

### Assumptions

- SMI-064's item-3/item-4 allocation and once-per-instance-per-Maneuver rule are settled Owner authority.
- Maneuver supplies final overlap evidence and invokes/awaits this package; it
  does not own the card effect or draw.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `damaged_controls`
- Rules reference: card text in `damage_cards.json`; incorporated FAQ timing; RRG timing rules

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: damage-deck loading; `src/core/damage/damage_card.gd`
- Metadata/status: no static CON-003 status claim; this package is `Draft`.

### Activation Conditions

- An individual source card is faceup when authoritative final resolution
  establishes at least one ship or obstacle overlap for the matching Maneuver.

### Runtime Prerequisites

- Source instance identity, activation/execution identities, final overlap
  category/identities, SMI-064 stage, target survival, deck, and unresolved status.
- Current production observes one caller-provided `did_overlap` Boolean, tests
  only for any matching card, and cannot prove obstacle-only or per-instance behavior.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | Each faceup `DamageCard` instance on `ShipInstance` plus Damaged-Controls-specific exact-once state | The card instance owns applicability; its guard binds one source to one activation/execution and item-3/item-4 allocation. | SMI-064, SMI-067, SMI-AC-027 |
| Validation | Damaged-Controls-specific replayable command boundary | It validates source faceup identity, activation/execution, final overlap evidence, current boundary, unresolved status, survival, and rules-assigned ordering actor where ordering is required. | ADR-003; CON-003 |
| Execution | Damaged-Controls-specific command using direct facedown draw/application helper | It deals one facedown card for one source instance and records exact-once completion atomically. | Card text; SMI-067 |
| Projection | `UIProjector` for any applicable same-timing order choice | Automatic resolution has no hull-zone prompt; any required order is offered only to the rules-assigned actor and derived from canonical applicable instances. | ADR-010; TEST-003 |
| Serialization | `ShipInstance`, damage deck/ledger, active execution, and Damaged-Controls-specific guards | Source identities and item-3/item-4 completion must survive recovery. | SMI-080; ADR-013 |
| Replay | `CommandProcessor` history and deterministic authority deck progression | Each source-instance command and resulting draw replay in order. | ADR-012; SMI-081 |
| Network | Authority command/follow-up processing plus passive application/snapshot paths | Passive peers never synthesize the automatic command or draw. | ADR-012; ADR-013 |
| Visibility | `StateFilter` and passive damage representation | Faceup source and facedown count are public; dealt card identity and remaining deck order stay hidden. | ADR-013 |
| Tests | Damaged Controls package verification suite and runtime smoke owner | It owns unit, protocol, conditional UI, persistence, replay, Network, visibility, chronology, exact-once, and runtime smoke evidence. | CON-003; TEST-003; Section 8 |

The canonical CON-003 surfaces State, Validation, Execution, Serialization,
Replay, Network, Visibility, and Tests are **Required**. Projection is
**Conditional**: required when rules-assigned same-timing order creates a real
choice; otherwise the package must record reduced TEST-003 rationale.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Optional | Current registered `execute_maneuver` observer | Current observer timing/input are insufficient; registry is not state or mutation owner. |
| RuleSurface | Required | SMI-064 item 3/item 4; SMI-067 | Separate accepted invocation points must converge on one per-instance guard. |
| Commands | Required | `PersistentEffectDamageCommand` is reusable primitive evidence | Require source-instance/execution-bound validation and atomic exact-once draw. |
| Resolvers | Required | Current `did_overlap`/preview predicates are partial | Authoritative final categories/identities and per-instance applicability are required. |
| State Classes | Required | `ShipInstance.faceup_damage`; no stable card identity/guard | Stable source identity and per-execution completion are missing. |
| Setup | Not Applicable | Damage card behavior begins in live ship state | No setup mutation. |
| UI Projection | Conditional | Same-timing choices require projection; a sole automatic instance does not | Record reduced TEST-003 rationale where no player choice exists. |
| Serialization | Required | Existing card/deck serialization is partial | Source identity and exact-once stage must round-trip. |
| Replay | Required | Current persistent damage history tests are partial | Per-instance order and item-3/item-4 placement need proof. |
| Networking | Required | Existing direct-draw application pattern is partial | Host-only follow-up, passive count, reconnect, and rejection need proof. |

## 6. Runtime State

### Required Runtime State

- Stable faceup source-card instance identity.
- Matching activation and Maneuver execution identities.
- Final `ship_overlap` and `obstacle_overlap` evidence, including obstacle identities.
- Per-source-instance unresolved/resolved guard for the Maneuver and its assigned
  SMI-064 boundary; damage deck and facedown count/application state.

The guard must not collapse instances by title, rule ID, or `effect_id`.

### Lifecycle

- Created by: authoritative final-overlap re-derivation at SMI-064 item 3 or 4.
- Updated by: same-timing order choice, if needed, and instance-bound command.
- Consumed by: atomic facedown draw plus exact-once guard update.
- Removed or expired by: Maneuver completion, source inactivity, or exceptional termination.

### Persistence

- Save/load path: source identity, active execution, overlap facts, guard, and damage state.
- Replay path: ordered per-instance semantic commands and deterministic deck.
- Network/reconnect path: filtered snapshot and facedown application result/count.

### Cleanup

- Cleanup owner: Damaged-Controls-specific boundary with ADR-006 cleanup.
- Cleanup trigger: resolution, Maneuver retirement, source inactivity, or destruction.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/effects/rules/damage_cards/ship/damaged_controls.gd`; `src/core/damage/damage_card.gd`; `src/core/state/ship_instance.gd`; `src/core/movement/maneuver_rule_resolver.gd` | Current predicate collapses copies and lacks obstacle evidence. |
| Commands | `src/core/commands/persistent_effect_damage_command.gd`; `src/core/commands/execute_maneuver_command.gd` | Draw helper/application exists; current caller Boolean and boundary are insufficient. |
| Resolvers | Scene collision path and `src/core/movement/maneuver_rule_resolver.gd` | Present evidence is not authoritative final multi-category detection. |
| Tests | `tests/unit/test_rule_damaged_controls.gd`; persistent command tests | Current basic behavior passes; accepted timing/multiplicity is unproven. |
| Documentation | Card/FAQ evidence; SMI-064, SMI-067, SMI-080/081, SMI-091; ADR-006 | Governing timing and ownership. |
| Related Rule Capability Packages | CAP-OBS-001, CAP-OBS-002, CAP-OBS-003 | Obstacle detection supplies evidence; obstacle effects remain separately owned. |

## 8. Test Evidence

### Unit Tests

- Existing tests prove registration, Boolean trigger, one draw, no-card, and basic save/load only.
- Outstanding: ship-only, obstacle-only, ship-plus-obstacle once, multiple
  obstacles once, duplicate source instances, facedown inactivity, stale/rejected
  commands, host-only follow-up, and exact-once atomicity.

### Integration Tests

- Outstanding: complete SMI-064 ordering, Squadron displacement before
  obstacle-only trigger, ordinary collision effects before item 3, destruction,
  return, and suppression of item 4 after item-3 resolution.

### Replay Tests

- Outstanding: per-instance ordered commands/draws and no duplicate on re-derivation.

### Serialization Tests

- Outstanding: save/load before item 3, between applicable instances, and before item 4.

### Network Tests

- Outstanding: authority-only automatic commands/draws, passive non-synthesis,
  facedown application, same ordering, stale rejection, and reconnect.

### Visibility Tests

- Outstanding: public source/count with hidden dealt-card identity and deck order.

### Regression Tests

- Outstanding: intermediate attempts do not trigger; speed zero can; one Boolean cannot erase category identity.

### TEST-003 Verification Matrix

| Field | Required package evidence |
| --- | --- |
| Timing-window identity | Ship Activation / matching live ADR-006 Maneuver execution / SMI-064 item 3 for ship collision or item 4 for obstacle-only overlap, once per source instance per Maneuver. |
| Opener | Baseline Maneuver re-derives applicable faceup instances from authoritative final overlap categories at the accepted item-3/item-4 boundary. |
| Participants | Every applicable faceup Damaged Controls instance, affected ship, authority damage deck, and any same-timing effects. Obstacle packages provide no ownership of this card effect. |
| Source owners | Individual public faceup `DamageCard` instances on `ShipInstance`; Damaged-Controls-specific exact-once guard; existing deck/ledger owners. |
| Controller / priority rule | Mutation is mandatory. If same-timing ordering creates a choice, validation and projection bind it to the rules-assigned actor; SMI-067 same-player and first-player ordering applies. |
| Use and decline commands | One mandatory instance-bound facedown-draw command per source; decline is Not Applicable. Payload binds source-card, activation, execution, and accepted item-3/item-4 context. Exact filename deferred. |
| Authoritative state changed | Authority deck, ship facedown damage, per-source exact-once guard, passive facedown count/application, and destruction state. |
| Re-derivation trigger | Each accepted instance command, source inactivity, target destruction, transition from item 3 to item 4, or recovery installation; item 4 excludes instances already resolved at item 3. |
| Continuation command | Purpose-specific completion returns to the matching live Maneuver boundary for the next SMI-064 obligation; no generic continuation owner. Exact filename deferred. |
| Cleanup events | Per-instance resolution, Maneuver retirement, source inactivity, target destruction, or exceptional activation termination. |
| Unit tests | Required category identity, item-3/item-4 validation, source identity, multiplicity, ordering actor, direct draw/application, exact-once, rejection, and destruction tests. |
| Protocol tests | Required final geometry -> item 3 or displacement -> item 4 -> re-derivation -> next consequence/termination lifecycle, including ship-plus-obstacle once. |
| UI-route tests | Required only when a real rules-assigned order choice exists; otherwise runtime projection must prove no fabricated prompt and record reduced TEST-003 rationale. |
| Serialization tests | Required before item 3, between source instances, and before item 4 with exact-once guards preserved. |
| Replay tests | Required per-instance command/draw order, item allocation, destruction, and no duplicate after recovery. |
| Network/reconnect tests | Required host-only automatic mutation/draw, passive non-synthesis/application, ordering, stale rejection, and reconnect at both boundaries. |
| Visibility tests | Required public faceup source/facedown count with hidden dealt-card identity and deck order. |
| Runtime smoke trace | Outstanding production-scene traces for ship-only, obstacle-only, and ship-plus-obstacle cases through return/termination. |

## 9. Risk Assessment

### Serialization / Replay / Network / Visibility Impact

- Serialization impact: high; exact-once guards span two possible sequence points.
- Replay impact: high; per-instance automatic commands and draws are ordered semantics.
- Network impact: high; authority follow-ups and hidden draws must not duplicate.
- Visibility impact: high; facedown identities remain authority-only.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | high | Multiple automatic instance commands | Ordered exact-once replay tests. |
| Serialization impact | high | Item-3/item-4 guard must resume | Persist purpose-specific guard. |
| Network impact | high | Passive non-synthesis is mandatory | Host/passive/reconnect tests. |
| Visibility impact | high | Hidden facedown identity | ADR-013 filtering/application tests. |
| Migration impact | high | Current Boolean/timing collapse accepted distinctions | Replace invocation while reusing low-level draw. |
| Complexity | high | Two invocation points share one per-instance invariant | One capability owner, no generic work framework. |

## 10. Integration Status

Current Status: Draft
Evidence Summary:

- Card data, current hook, direct-draw command infrastructure, and focused tests exist.
- Accepted category evidence, timing, stable source identity, multiplicity, and protocol coverage do not.

Outstanding Work:

- Implement/verify all applicable surfaces and exact-once semantics; complete
  CON-003/TEST-003 evidence; obtain explicit Owner approval.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Draft preserves the accepted item-3/item-4 and per-instance allocation. |

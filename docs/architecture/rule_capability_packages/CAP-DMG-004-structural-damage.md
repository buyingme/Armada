# CAP-DMG-004: Structural Damage

Package ID: CAP-DMG-004  
Title: Structural Damage  
Status: Draft  
Component Type: damage card  
Source Component: `structural_damage`  
Related ADRs: ADR-001, ADR-003, ADR-006, ADR-010, ADR-012, ADR-013, ADR-014  
Related Contracts: CON-001, CON-003  
Related Context Packs: CP-001  
Related Tests: TEST-003; required tests listed below  
Related Requirements: DM-005, DM-008  
Related Boundaries: ADR-001/CON-001 Attack authority and return dependency; ADR-014; ADR-012/ADR-013 and BUG-042 damage/RNG result-application boundary  
Related Gaps: ADR-014 physical-card identity, active-obligation, recovery, and purpose-specific return implementation gaps  
Created: 2026-09-12  
Last Updated: 2026-09-12  
Owner: Project Owner  
Test Owner: Capability implementation owner; Project Owner review required  
Capability Classification: mixed
Current Implementation Readiness: Partial; existing mutation is not ADR-014-conformant  
Remaining Card-Specific Repair Classification: B — bounded implementation repair  
External Prerequisite Complexity: C — shared ADR-014 foundation and authoritative damage-deck availability/recycling implementation
Package Authority Role: Traceability/integration artifact only; it owns no runtime authority

## 1. Purpose

This package traces Structural Damage: when this card is dealt faceup, deal the
ship one additional facedown damage card, then flip Structural Damage facedown.
It is a general damage-card capability usable from every legal faceup draw.

The capability is mixed because component-origin behavior blocks and returns to
an enclosing Attack, Maneuver, debug-authoritative, or future legal draw owner.

## 2. Scope

### Included Behavior

- Immediate mandatory resolution, one additional facedown draw, card flip,
  destruction re-evaluation, and exact-once composed return or termination.
- Invocation from Attack, still-OPEN ADR-006 Maneuver/Asteroid,
  debug-authoritative, and future legal sources without owning those contexts.

### Excluded Behavior

- General damage-deck availability, discard recycling, shuffle authority, RNG,
  and hidden deck ordering.
- Faceup draw causation and enclosing-flow completion ownership.
- A generic immediate-effect or continuation framework.

### Dependencies

- Stable physical faceup `DamageCard` instance identity.
- Authority-owned damage-deck availability/reshuffle boundary: an empty draw
  pile recycles and shuffles the discard pile before the required draw under
  DM-008 and the existing shared `DamageDeck` boundary. This capability neither
  defines the both-piles-empty outcome nor invents substitute/proxy damage.
- The ADR-014 purpose-specific source binding: matching `CurrentAttackState`,
  matching `ship_activation_id` plus active ADR-006 Maneuver-execution identity,
  authoritative debug application identity, or a future accepted source identity.

### Assumptions

- Authority alone shuffles; passive peers neither shuffle nor receive hidden
  card identities/order. Structural Damage consumes that shared boundary but
  does not own it.
- The source draw owner establishes the faceup card and surviving ship before
  invoking this capability.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `structural_damage`
- Rules reference id: DM-005; Structural Damage card text

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: `src/core/damage/damage_deck.gd`,
  `src/core/damage/damage_card.gd`
- Metadata: `timing = immediate`, `count = 8`

### Activation Conditions

- A specific Structural Damage instance is dealt faceup to a surviving ship.

### Runtime Prerequisites

- Stable card and ship identities, unresolved immediate-resolution identity,
  authority damage deck, and a live enclosing interaction where applicable.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | `ShipInstance` assigned-card collection and its at-most-one ADR-014 active record; authoritative damage deck outside this capability | The record references the stable physical card; it does not copy it. No player decision exists. | `damage_card.gd`; `damage_deck.gd`; ADR-014 |
| Validation | Structural branch of `ResolveImmediateEffectCommand` | Must validate card instance, ship, purpose-specific source, unresolved status, exact-once eligibility, and draw availability; no chooser is assigned. | `resolve_immediate_effect_command.gd` |
| Execution | Structural branch using shared deck draw/application boundary | Owns the extra facedown damage and flip, not recycling policy. | `_execute_structural_damage()` |
| Projection | Existing damage-card/hull projection routes | Projection reflects committed state only. | `immediate_effect_signals.gd`; `game_manager.gd` |
| Serialization | Existing state owners plus stable card/application identity | Exact instance and completion state must round-trip. | `damage_card.gd`; `game_state.gd` |
| Replay | `CommandProcessor` history and authority RNG/deck state | Ordered semantic commands reproduce draw, flip, destruction, and return. | ADR-012 |
| Network | Authority execution and passive application-result/snapshot paths | Passive peers apply accepted results without drawing or following up. | ADR-012; ADR-013 |
| Visibility | `StateFilter` and passive damage ledger | Faceup source is public; resulting facedown identity and deck order are hidden. | `state_filter.gd` |
| Tests | Structural Damage capability test owner | Owns unit, protocol, persistence, distributed, visibility, and runtime evidence. | CON-003; TEST-003 |

All nine canonical CON-003 surfaces are **Required**.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Not Applicable | No registration is used | Mandatory immediate behavior is command-owned. |
| RuleSurface | Not Applicable | No modifier/blocker is required | Legal sources invoke the capability directly. |
| Commands | Required | `ResolveImmediateEffectCommand` | Exists, but uses faceup array index and lacks enclosure/exact-once validation. |
| Resolvers | Required | `ImmediateEffectResolver` | Choice-less routing exists; its duplicate mutation path is not production authority. |
| State Classes | Required | `DamageCard`, `ShipInstance`, deck/ledger | Stable instance and exact-once application identities are missing. |
| Setup | Not Applicable | Card is loaded with the standard deck | No setup choice belongs to this rule. |
| UI Projection | Required | damage/hull/card refresh routes | Correct passive-peer refresh still lacks evidence. |
| Serialization | Required | card/deck/state serialization | Instance and unresolved-resolution round trips are outstanding. |
| Replay | Required | replayable command exists | Reshuffle, destruction, stale/duplicate, and return sequences are outstanding. |
| Networking | Required | application contract and passive ledger exist | Authority-only reshuffle/draw and passive non-synthesis need protocol proof. |

## 6. Runtime State

### Required Runtime State

- ShipInstance-owned physical faceup card instance, its matching ADR-014 active
  record until automatic completion, target ship, purpose-specific source
  identity, and shared authority deck state.

### Lifecycle

- Created atomically by: any accepted faceup damage-card draw owner, unless the
  complete automatic obligation resolves in that same accepted transaction.
- Updated by: the Structural Damage semantic command.
- Consumed by: destruction termination or the enclosing owner's composed return.
- Removed by: exact-once resolution or atomic destruction cleanup. Unrelated
  repair/removal/discard/flip/reassignment rejects while unresolved unless an
  accepted rule atomically resolves or terminates the matching obligation.
- If this authority physical card is later discarded/recycled and dealt again,
  the new assignment establishes a fresh ADR-014 obligation scoped to its new
  purpose-specific source identity. Prior resolution does not suppress it, and
  stale commands/identities from the earlier occurrence cannot authorize it;
  no generic permanent `immediate_resolved` flag is introduced.

### Persistence

- Save/load: canonical card, deck/RNG, ship, application and enclosing state.
- Replay: ordered draw-source, Structural Damage, termination/return commands.
- Network/reconnect: filtered snapshot and accepted passive application.

### Cleanup

- Cleanup owner: Structural Damage command for card-specific immediate mutation
  and record retirement; the Attack/Maneuver/debug source owns its own return or
  terminal cleanup. Debug resolution is terminal and has no composed return.
- Cleanup trigger: successful resolution or atomic destruction cleanup;
  unrelated invalidation rejects unless an accepted rule atomically terminates
  the obligation. The purpose-specific parent separately owns return/termination.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/damage/damage_card.gd`; `damage_deck.gd`; `passive_damage_ledger.gd` | Existing card/deck/hidden-state owners. |
| Commands | `src/core/commands/resolve_immediate_effect_command.gd` | Current command-owned mutation. |
| Resolvers | `src/core/damage/immediate_effect_resolver.gd` | Current routing plus non-production duplicate mutation. |
| Tests | `tests/unit/test_resolve_immediate_effect_command.gd`; `test_damage_deck.gd` | Direct effect and recycling unit evidence. |
| Documentation | card data; DM-005; ADR-012/013 | Rule and distributed authority. |
| Related packages | CAP-OBS-001 | Asteroid is one external faceup-draw source. |

## 8. Test Evidence

### Existing Evidence

- Unit: direct extra draw/flip and command validation; general deck recycling.
- Integration: one Attack sequence proves Structural resolution precedes attack completion in
  `tests/integration/test_current_attack_production_resume.gd`.
- Manual: BUG-042 Network acceptance includes Structural Damage but remains
  pending Owner QA.

### Outstanding Evidence

- Stable instance, wrong actor/enclosure, stale/duplicate, reshuffle boundary,
  passive visibility/application, save/load, reconnect, replay, destruction,
  all legal source contexts, and production-scene smoke tests.

### TEST-003 Verification Matrix

Structural Damage has no participant choice, but no TEST-003 lifecycle category
is omitted: player-selection UI is not applicable because the obligation is
mandatory and automatic; committed-state projection and runtime smoke remain
required.

| Category | Required package evidence |
| --- | --- |
| Opener / entry | Attack, Maneuver/Asteroid, and authoritative debug assignment atomically establish/resolve the ADR-014 obligation; future sources require accepted identity. |
| Participants / controller | No chooser or controller; authority performs the mandatory automatic effect. |
| Validation | Exact card/ship/source record, survival, deck availability, source identity, and exact-once eligibility; DM-008 and the shared DamageDeck boundary govern exhaustion, including the accepted both-piles-empty outcome. |
| Authoritative command | Structural command draws exactly one facedown card through the shared deck boundary and flips the source; it does not own recycling/RNG policy. |
| Continuation / return | Re-evaluate destruction; return exactly once to matching Attack or Maneuver parent, perform valid Attack terminal cleanup, suppress invalid Maneuver return, and terminate after debug. |
| State ownership | ShipInstance owns assigned cards and at most one referencing active record; deck owns draw/discard/RNG state. |
| Serialization | Round-trip physical identities, location, unresolved record, source parent, accepted RNG/deck state, including exhaustion/reshuffle and both-piles-empty cases. |
| Replay | Reproduce draw exhaustion, discard reshuffle, accepted RNG order, extra draw, flip, destruction, and exact return without live UI/passive synthesis. |
| Network protocol / application | Authority alone draws/shuffles; passive peers apply the realized aggregate damage/card result and never learn hidden identity/order. |
| Visibility / filtering | Retire faceup correlation after flip; hide added facedown identity, deck/discard order, RNG, command history, saves, and reconnect payloads as ADR-013 requires. |
| UI / projection | No decision modal; refresh public faceup/facedown aggregates, hull/destruction, and enclosing state from canonical application. |
| Runtime / manual smoke | Real Attack, Maneuver/Asteroid, and debug routes, including reshuffle and destruction, complete without duplicate return or stranded interaction. |

Shared negative/protocol tests SHALL cover duplicate physical copies of
Structural Damage, wrong/stale card, wrong ship, wrong actor payload where one
is supplied, stale purpose-specific parent, duplicate submission, exact-once
save/load recovery, reconnect, source-card lifecycle rejection/atomic cleanup,
passive application, and destruction. Damage-deck tests SHALL additionally
cover draw exhaustion plus discard reshuffle, both piles empty under the
accepted rule, authority RNG/save continuity, replay, passive aggregate
application, and hidden-card non-disclosure. BUG-042/ADR-012/ADR-013 remain the
external result-application boundary.

TEST-003 SHALL prove that `CommandApplicability`, `FlowSpec.allowed_commands`,
and `ResolveImmediateEffectCommand.validate()` agree: projection cannot offer a
canonically rejected command, protocol/replay cannot bypass validation,
automatic branches expose no manual command, and any legal command targets only
the current canonical obligation. Redeal coverage SHALL prove a fresh
assignment-scoped obligation and rejection of earlier-occurrence identities.

## 9. Risk Assessment

- Serialization/replay impact: high because physical identity, RNG/deck order,
  reshuffle and command order must converge.
- Network/visibility impact: high because passive peers must apply without
  drawing and must not learn the extra facedown identity.
- Metadata/status impact: remains Draft; static or production metadata SHALL
  NOT imply CON-003 integration before evidence and explicit Owner approval.

| Risk Area | Impact | Mitigation or Outstanding Work |
| --- | --- | --- |
| Replay | high | Reshuffle and exact command-order convergence tests. |
| Serialization | high | Persist card/application/deck/RNG/enclosure identities. |
| Network | high | Authority-only draw and passive non-synthesis tests. |
| Visibility | high | Faceup-to-hidden transition and filtered-history tests. |
| Migration | medium | Version stable card identity and keep dormant until compatible. |
| Complexity | medium | Reuse deck lifecycle; keep only card semantics here. |

## 10. Integration Status

Current Status: Draft  
Evidence Summary: Card data and a command-owned production mutation exist.

Outstanding Work:

- Implement shared identities and contextual return, close projection gaps,
  remove production ambiguity, and pass all applicable TEST-003 categories.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Drafted from settled rule direction and verified production evidence; no integration claim. |

## 12. Codex Checklist

- [x] Ownership, runtime state, required surfaces, risks, and existing evidence identified.
- [x] Non-applicable surfaces include rationale.
- [x] Missing TEST-003 evidence recorded.
- [ ] Applicable tests pass after required implementation repair.
- [ ] Independent coordinated architecture/rules audit complete.
- [ ] Ready for Owner Review.

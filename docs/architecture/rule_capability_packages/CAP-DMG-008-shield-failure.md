# CAP-DMG-008: Shield Failure

Package ID: CAP-DMG-008  
Title: Shield Failure  
Status: Draft  
Component Type: damage card  
Source Component: `shield_failure`  
Related ADRs: ADR-001, ADR-003, ADR-006, ADR-010, ADR-012, ADR-013, ADR-014  
Related Contracts: CON-001, CON-003  
Related Context Packs: CP-001  
Related Tests: TEST-003; required tests listed below  
Related Requirements: DM-005, DM-010 through DM-015  
Related Boundaries: ADR-001/CON-001 Attack authority and return dependency; ADR-014 purpose-specific immediate-resolution boundary  
Related Gaps: ADR-014 physical-card identity, active-obligation, recovery, Network filtering, and return implementation gaps  
Created: 2026-09-12  
Last Updated: 2026-09-12  
Owner: Project Owner  
Test Owner: Capability implementation owner; Project Owner review required  
Capability Classification: mixed
Current Implementation Readiness: Partial; rule mutation exists but actor, identity, and protocol are incomplete  
Remaining Card-Specific Repair Classification: B — bounded implementation repair  
External Prerequisite Complexity: C — shared ADR-014 foundation implementation
Package Authority Role: Traceability/integration artifact only; it owns no runtime authority

## 1. Purpose

This package traces Shield Failure: the opposing player may choose zero, one,
or two distinct hull zones; each chosen zone loses one shield; then the card
flips facedown. It is usable from every legal faceup draw source.

## 2. Scope

### Included Behavior

- Opposing-player choice including zero zones, distinct-zone validation,
  shield loss, card flip, exact-once completion, and composed return.
- Invocation from Attack, still-OPEN ADR-006 Maneuver/Asteroid,
  debug-authoritative, and future legal sources without owning those contexts.

### Excluded Behavior

- Faceup draw causation, general shield rules, enclosing completion, and generic
  immediate-effect/choice/continuation infrastructure.

### Dependencies

- Stable authority physical-card identity; target ship/shields; the matching
  ADR-014 record and canonical opponent of the damaged ship's owner; and the
  applicable Attack, Maneuver, debug, or future purpose-specific source identity.

### Assumptions

- Zero zones is a legal confirmed choice. Zones with zero shields remain legal
  choices and suffer no numerical change.
- "Opposing player" means the canonical player opposing the damaged ship's
  owner in every source context, not the current attacker.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `shield_failure`
- Rules reference id: DM-005, DM-010 through DM-015; Shield Failure card text

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: `damage_deck.gd`, `damage_card.gd`
- Metadata: `timing = immediate`, `count = 2`

### Activation Conditions

- A specific Shield Failure instance is dealt faceup to a surviving ship.

### Runtime Prerequisites

- Stable card/ship/enclosure identity and canonical current hull-zone shields.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | `ShipInstance.current_shields`, its assigned physical `DamageCard`, and its at-most-one ADR-014 active record | The record references the card and binds the opponent of the damaged ship's owner. | `src/core/state/ship_instance.gd`; `src/core/damage/damage_card.gd`; ADR-014 |
| Validation | Shield Failure command branch | Validates instance, ship, purpose-specific source, unresolved status, the canonical opponent of the damaged ship's owner, and 0–2 distinct legal zones. | `_validate_shield_failure_choice()` |
| Execution | Shield Failure command branch | Owns per-zone loss, flip/move and completion. | `_execute_shield_failure()` |
| Projection | `UIProjector` and existing choice/shield/card routes | Shows all zones and supports an explicit zero selection. | resolver/modal routes |
| Serialization | Existing state plus stable pending identity | Choice must resume without array/object authority. | `damage_card.gd`; `interaction_flow.gd`; `game_state.gd` |
| Replay | `CommandProcessor` history | Replays selected zone list and return in order. | command history architecture |
| Network | Authority command plus passive application/snapshot | Only rules-assigned opponent may submit; passive peers do not synthesize. | ADR-012 |
| Visibility | `StateFilter` | Card, shields and choice are public; resulting facedown identity is hidden. | ADR-013 |
| Tests | Shield Failure capability test owner | Owns full CON-003/TEST-003 evidence. | CON-003; TEST-003 |

All nine canonical CON-003 surfaces are **Required**.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Not Applicable | No registration exists | Immediate command owns the rule. |
| RuleSurface | Not Applicable | No modifier/blocker required | Legal draw sources invoke directly. |
| Commands | Required | `ResolveImmediateEffectCommand` | Current schema lacks stable card, actor, enclosure and exact-once validation. |
| Resolvers | Required | `get_required_choice()` | Correct opposing multi-select derivation; duplicate mutation path is not authority. |
| State Classes | Required | shields, card arrays, `InteractionFlow` | Stable physical/pending identity missing. |
| Setup | Not Applicable | Standard deck loading only | No setup behavior. |
| UI Projection | Required | attack mirror/debug controller/modal | Choice exists; recovery and context-independent route evidence are incomplete. |
| Serialization | Required | `damage_card.gd`; `interaction_flow.gd`; `game_state.gd` | Pending choice currently uses mutable array index. |
| Replay | Required | semantic command history | Choice/zero-choice, stale/duplicate and returns need proof. |
| Networking | Required | `command_applicability.gd`; `flow_spec.gd`; `resolve_immediate_effect_command.gd`; `command_processor.gd`; `state_filter.gd` | Actor admission and effect-specific passive shield refresh are missing. |

## 6. Runtime State

### Required Runtime State

- ShipInstance-owned physical card, target ship/current shields, and its
  matching ADR-014 record containing the damaged-owner opponent and
  purpose-specific source identity while unresolved.

### Lifecycle

- Created atomically by: accepted faceup draw owner; zero selected zones is a
  genuine deliberate choice, so this capability remains unresolved until the
  opponent submits it.
- Updated by: opposing player's confirmed 0–2-zone selection.
- Consumed by: Shield Failure command and enclosing return.
- Removed by: exact-once resolution or atomic destruction cleanup. Other
  source-card invalidation rejects unless an accepted rule atomically resolves
  or terminates the obligation.
- If this authority physical card is later discarded/recycled and dealt again,
  the new assignment establishes a fresh ADR-014 obligation scoped to its new
  purpose-specific source identity. Prior resolution does not suppress it, and
  stale commands/identities from the earlier occurrence cannot authorize it;
  no generic permanent `immediate_resolved` flag is introduced.

### Persistence

- Save/load, replay, Network/reconnect: canonical card/ship/shield/pending/enclosure
  state and ordered command; prompt is re-derived and viewer-filtered.

### Cleanup

- Cleanup owner: Shield Failure command for card-specific immediate mutation
  and record retirement; the purpose-specific parent owns return/termination.
  Debug completion is terminal.
- Cleanup trigger: resolution or atomic destruction cleanup; unrelated
  invalidation rejects unless an accepted rule atomically terminates the
  obligation. The purpose-specific parent separately owns return/termination.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/damage/damage_card.gd`; `src/core/state/ship_instance.gd`; `immediate_effect_resolver.gd` | Card/shield state and choice derivation. |
| Commands | `resolve_immediate_effect_command.gd` | Current validation/mutation. |
| Resolvers | `get_required_choice()` | Opponent, multi-select and all-zone options. |
| Tests | `test_immediate_effect_resolver.gd`; `test_resolve_immediate_effect_command.gd` | 0/1/2 zones, duplicate rejection, zero-shield, flip. |
| Documentation | `mvp_learning_scenario.md` DM-010–015; card data | Accepted rule details. |
| Related packages | CAP-OBS-001 | One external faceup-draw source. |

## 8. Test Evidence

### Existing Evidence

- Unit tests cover 0/1/2 selections, distinctness, per-zone shield loss,
  zero-shield zones, command validation and flip.

### Outstanding Evidence

- Stable/contextual identity, wrong actor, stale/duplicate, canonical recovery,
  all source contexts, composed return, replay, Network/passive shield refresh,
  visibility, real route and runtime smoke.

### TEST-003 Verification Matrix

| Category | Required package evidence |
| --- | --- |
| Opener / entry | Attack, Maneuver/Asteroid, and debug assignment atomically establish the exact unresolved card obligation. |
| Participants / controller | Canonical opponent of the damaged ship's owner chooses 0–2 zones in every source context; never infer actor from current attacker. |
| Validation | Exact card/ship/record/opponent/source identity; 0–2 distinct current legal hull zones; reject duplicates, invalid zones and stale state. |
| Authoritative command | One replayable command loses one shield per selected zone where possible, permits selected zero-shield zones, flips card, and retires record. |
| Continuation / return | Command owns shield/card mutation and record cleanup; matching Attack/Maneuver parent owns return/termination; debug is terminal. |
| State ownership | ShipInstance owns card/shields/record; record references card and binds canonical opponent plus purpose-specific source. |
| Serialization | Round-trip deliberate zero and 1/2-zone decisions, card, chooser, legal-choice facts and purpose-specific parent. |
| Replay | Reproduce 0/1/2 selections, zero-shield handling, flip, cleanup, destruction and exactly one valid return. |
| Network protocol / application | Admit only canonical opponent; passive peers apply authority shield/card result and never synthesize continuation. |
| Visibility / filtering | Choice/current shields are public as authorized; post-flip authority identity correlation is removed from state/history/reconnect. |
| UI / projection | Real route supports explicit zero confirmation and 1/2 distinct selections, including zero-shield zones, without forcing a zone. |
| Runtime / manual smoke | Live Attack, Maneuver/Asteroid and debug routes for every 0/1/2 branch, recovery and destruction. |

Required negative/protocol coverage includes duplicate physical copies,
wrong/stale card, wrong ship, wrong actor, stale purpose-specific parent,
duplicate submission, exact-once recovery, reconnect during the choice, replay,
passive filtering/application, lifecycle invalidation, destruction and invalid
return. Card cases cover deliberate zero, one and two zones, duplicate and
invalid zones, zones already at zero shields, and actor derivation outside
Attack.

TEST-003 SHALL prove that `CommandApplicability`, `FlowSpec.allowed_commands`,
and `ResolveImmediateEffectCommand.validate()` agree: projection cannot offer a
canonically rejected command, protocol/replay cannot bypass validation, and the
genuine decision exposes only 0–2-zone commands legal for the current canonical
obligation. Redeal coverage SHALL prove a fresh assignment-scoped obligation
and rejection of earlier-occurrence identities.

## 9. Risk Assessment

- Serialization/replay impact: medium; a blocking opposing choice requires
  stable card and interaction identity.
- Network/visibility impact: medium; actor validation and shield refresh must converge.
- Metadata/status impact: remains Draft; metadata SHALL NOT imply CON-003
  integration before complete evidence and explicit Owner approval.

| Risk Area | Impact | Mitigation or Outstanding Work |
| --- | --- | --- |
| Replay | medium | 0/1/2 selection and exact return sequences. |
| Serialization | medium | Pending identity/reconstruction tests. |
| Network | medium | Opponent admission, passive refresh, reconnect. |
| Visibility | medium | Public prompt and hidden post-flip identity. |
| Migration | medium | Version stable card/pending schema. |
| Complexity | medium | Preserve explicit multi-select semantics only. |

## 10. Integration Status

Current Status: Draft  
Evidence Summary: Correct rule semantics and direct command/unit evidence exist.

Outstanding Work:

- Implement identity/context/projection/recovery repairs and pass all applicable
  TEST-003 evidence.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Coordinated Draft preserving DM-010–015 semantics. |

## 12. Codex Checklist

- [x] Ownership, state, surfaces, risks, evidence, and N/A rationale identified.
- [x] Missing TEST-003 evidence recorded.
- [ ] Applicable tests pass after implementation repair.
- [ ] Independent coordinated architecture/rules audit complete.
- [ ] Ready for Owner Review.

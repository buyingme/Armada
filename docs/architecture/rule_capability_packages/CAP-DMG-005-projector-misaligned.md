# CAP-DMG-005: Projector Misaligned

Package ID: CAP-DMG-005  
Title: Projector Misaligned  
Status: Draft  
Component Type: damage card  
Source Component: `projector_misaligned`  
Related ADRs: ADR-001, ADR-003, ADR-006, ADR-010, ADR-012, ADR-013, ADR-014  
Related Contracts: CON-001, CON-003  
Related Context Packs: CP-001  
Related Tests: TEST-003; required tests listed below  
Related Requirements: DM-005  
Related Boundaries: ADR-001/CON-001 Attack authority and return dependency; ADR-014 purpose-specific immediate-resolution boundary  
Related Gaps: ADR-014 physical-card identity, active-obligation, recovery, Network filtering, and return implementation gaps  
Created: 2026-09-12  
Last Updated: 2026-09-12  
Owner: Project Owner  
Test Owner: Capability implementation owner; Project Owner review required  
Capability Classification: mixed
Current Implementation Readiness: Partial; core rule paths exist but pending identity and protocol are non-conformant  
Remaining Card-Specific Repair Classification: B — bounded implementation repair  
External Prerequisite Complexity: C — shared ADR-014 foundation implementation
Package Authority Role: Traceability/integration artifact only; it owns no runtime authority

## 1. Purpose

This package traces Projector Misaligned: the hull zone with the most remaining
shields loses all shields; when positive maxima are tied, the ship owner chooses
one tied zone; then the card flips facedown. It is source-context independent.

## 2. Scope

### Included Behavior

- Immediate maximum-shield derivation, conditional owner choice, shield loss,
  card flip, exact-once resolution, and composed return.
- Invocation from Attack, still-OPEN ADR-006 Maneuver/Asteroid,
  debug-authoritative, and future legal sources without owning those contexts.

### Excluded Behavior

- Faceup draw causation, general shield ownership, enclosing-flow completion,
  and generic immediate-effect/continuation infrastructure.

### Dependencies

- Stable authority physical-card identity; an ADR-014 record only while the
  obligation is unresolved; target ship; and matching `CurrentAttackState`,
  `ship_activation_id` plus ADR-006 Maneuver-execution, authoritative debug
  application, or future accepted purpose-specific source identity.

### Assumptions

- A unique maximum is mandatory and automatic. A positive tied maximum is the
  only package-owned player choice. With no remaining shields, no choice opens;
  the remainder resolves and the card flips.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `projector_misaligned`
- Rules reference id: DM-005; Projector Misaligned card text

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: `damage_deck.gd`, `damage_card.gd`
- Metadata: `timing = immediate`, `count = 2`

### Activation Conditions

- A specific Projector Misaligned instance is dealt faceup to a surviving ship.

### Runtime Prerequisites

- Stable card/ship/enclosure identity and current canonical hull-zone shields.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | `ShipInstance.current_shields`, its assigned physical `DamageCard`, and its at-most-one ADR-014 active record | The record references rather than copies the card; only a positive tie retains a player decision. | `ship_instance.gd`; `damage_card.gd`; ADR-014 |
| Validation | Projector branch of `ResolveImmediateEffectCommand` | Validates instance, ship, enclosure, owner actor, unresolved status, and tied-zone choice. | `_validate_projector_choice()` |
| Execution | Projector command branch | Owns shield loss, flip/move, and capability completion. | `_execute_projector_misaligned()` |
| Projection | `UIProjector` plus damage-card choice/card/shield routes | Derives prompt from canonical tie state; never owns the choice. | resolver/controller/mirror paths |
| Serialization | Existing state plus stable pending identity | Tie choice and enclosing identity must resume exactly. | `game_state.gd`; `interaction_flow.gd` |
| Replay | `CommandProcessor` history | Replays selected zone and return in order. | command history architecture |
| Network | Authority command plus passive application/snapshot | Wrong peer is rejected and passive peers do not synthesize. | ADR-012 |
| Visibility | `StateFilter` | Faceup card, shields and choice are public; resulting facedown identity is hidden. | ADR-013; `state_filter.gd` |
| Tests | Projector Misaligned capability test owner | Owns full CON-003/TEST-003 evidence. | CON-003; TEST-003 |

All nine canonical CON-003 surfaces are **Required**.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Not Applicable | No registration exists | Immediate command owns the rule. |
| RuleSurface | Not Applicable | No modifier/blocker is required | Legal sources invoke the capability. |
| Commands | Required | `ResolveImmediateEffectCommand` | Current schema uses card index and lacks actor/enclosure/exact-once validation. |
| Resolvers | Required | `ImmediateEffectResolver.get_required_choice()` | Correctly derives tied-zone choices; duplicate mutation path is not authority. |
| State Classes | Required | ship shields, faceup/facedown arrays, `InteractionFlow` | Stable instance/pending identity is missing. |
| Setup | Not Applicable | Standard deck loading only | No setup behavior. |
| UI Projection | Required | attack mirror and debug controller | Existing prompts are context-specific and incompletely recoverable. |
| Serialization | Required | `src/core/damage/damage_card.gd`; `src/core/state/game_state.gd`; `interaction_flow.gd` | Pending choice uses mutable array index; recovery proof is missing. |
| Replay | Required | semantic command history | Choice, stale/duplicate and source-context sequences need proof. |
| Networking | Required | `command_applicability.gd`; `flow_spec.gd`; `resolve_immediate_effect_command.gd`; `command_processor.gd`; `state_filter.gd` | Correct actor admission and effect-specific passive refresh are missing. |

## 6. Runtime State

### Required Runtime State

- ShipInstance-owned physical card, target ship/current shields, and the
  matching ADR-014 record while unresolved, including ship-owner chooser and
  the applicable purpose-specific source identity.

### Lifecycle

- Created atomically by: accepted faceup draw owner; a fully automatic branch
  may instead complete in that same accepted transaction.
- Updated by: owner choice command only when tied.
- Consumed by: command mutation and enclosing return.
- Removed by: exact-once resolution or atomic destruction cleanup. Other
  source-card invalidation rejects unless an accepted rule atomically resolves
  or terminates the obligation.
- If this authority physical card is later discarded/recycled and dealt again,
  the new assignment establishes a fresh ADR-014 obligation scoped to its new
  purpose-specific source identity. Prior resolution does not suppress it, and
  stale commands/identities from the earlier occurrence cannot authorize it;
  no generic permanent `immediate_resolved` flag is introduced.

### Persistence

- Save/load, replay, Network/reconnect: canonical card/ship/pending/enclosure
  state and ordered semantic command; projection is re-derived.

### Cleanup

- Cleanup owner: Projector command for card-specific immediate mutation and
  record retirement; the purpose-specific parent owns return/termination.
  Debug completion is terminal and has no gameplay composed return.
- Cleanup trigger: resolution or atomic destruction cleanup; unrelated
  invalidation rejects unless an accepted rule atomically terminates the
  obligation. The purpose-specific parent separately owns return/termination.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `damage_card.gd`; `ship_instance.gd` | Current card and shield owners. |
| Commands | `resolve_immediate_effect_command.gd` | Current validation/mutation. |
| Resolvers | `immediate_effect_resolver.gd` | Tie/choice derivation. |
| Tests | `test_resolve_immediate_effect_command.gd`; `test_immediate_effect_resolver.gd` | Unique, tied, no-shield and flip unit coverage. |
| Documentation | card data; DM-005 | Rule identity/text. |
| Related packages | CAP-OBS-001 | One external faceup-draw source. |

## 8. Test Evidence

### Existing Evidence

- Unit tests cover unique maximum, tied owner choice, selected-zone loss,
  no-shield behavior, validation and flip.

### Outstanding Evidence

- Stable identity, correct/wrong actor, stale/duplicate, canonical pending
  recovery, all source contexts, composed return, replay, Network/passive
  refresh, visibility and runtime smoke.

### TEST-003 Verification Matrix

| Category | Required package evidence |
| --- | --- |
| Opener / entry | Attack, Maneuver/Asteroid, and debug assignment atomically establish/resolve the record for the exact card. |
| Participants / controller | Damaged ship owner controls only a positive tied maximum; zero and unique maximum are automatic. |
| Validation | Card/ship/record/owner/source identity and current maxima; reject a submitted zone no longer tied at the positive maximum. |
| Authoritative command | One replayable Projector command applies automatic or selected-zone shield loss, flips the card, and retires the record exactly once. |
| Continuation / return | Card command cleans only its resolution; matching Attack/Maneuver parent owns return, destruction handling is context-specific, debug is terminal. |
| State ownership | ShipInstance owns card, shields, and at most one referencing ADR-014 record; projection is derived. |
| Serialization | Save/load zero, unique, and tied states plus exact card, chooser, legal-choice facts, and purpose-specific parent. |
| Replay | Reproduce automatic/choice branches, pending-state change/revalidation, shield loss, flip, cleanup, and one return. |
| Network protocol / application | Correct owner submits; passive peers apply authority result without synthesizing choice/continuation. |
| Visibility / filtering | Public shields/faceup choice are viewer-authorized; post-flip physical correlation is removed from state, history, reconnect, and logs. |
| UI / projection | No modal for zero/unique maximum; show all and only 2+ positive tied zones through the real controller route. |
| Runtime / manual smoke | Exercise live Attack, Maneuver/Asteroid, and debug routes plus state change while a tie choice is pending. |

Required negative/protocol coverage includes duplicate physical copies,
wrong/stale card, wrong ship, wrong actor, stale purpose-specific source/parent
identity, duplicate submission, exact-once recovery, reconnect during the tied
decision, replay, passive application/filtering, lifecycle invalidation,
destruction and invalid return. Card cases include zero shields, unique
maximum, two-way and larger ties, and shield changes while pending.

TEST-003 SHALL prove that `CommandApplicability`, `FlowSpec.allowed_commands`,
and `ResolveImmediateEffectCommand.validate()` agree: projection cannot offer a
canonically rejected command, protocol/replay cannot bypass validation,
automatic zero/unique branches expose no manual command, and the genuine tied
branch exposes only commands legal for the current canonical obligation.
Redeal coverage SHALL prove a fresh assignment-scoped obligation and rejection
of earlier-occurrence identities.

## 9. Risk Assessment

- Serialization/replay impact: medium; pending card and selected zone need stable
  identity and deterministic command history.
- Network/visibility impact: medium; public choice/state, hidden resulting card.
- Metadata/status impact: remains Draft; metadata SHALL NOT imply CON-003
  integration before complete evidence and explicit Owner approval.

| Risk Area | Impact | Mitigation or Outstanding Work |
| --- | --- | --- |
| Replay | medium | Ordered automatic/tied-choice and return tests. |
| Serialization | medium | Stable pending identity and reconstruction tests. |
| Network | medium | Actor admission, passive refresh and reconnect tests. |
| Visibility | medium | Public prompt and hidden post-flip identity tests. |
| Migration | medium | Version stable card/pending schema. |
| Complexity | medium | Keep tie semantics in this package; reuse low-level state plumbing. |

## 10. Integration Status

Current Status: Draft  
Evidence Summary: Correct card semantics and command/unit evidence exist.

Outstanding Work:

- Implement shared identity/context repairs and complete TEST-003 protocol,
  recovery, distributed, visibility and live-route evidence.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Coordinated Draft from settled semantics and production evidence. |

## 12. Codex Checklist

- [x] Ownership, state, surfaces, risks, evidence, and N/A rationale identified.
- [x] Missing TEST-003 evidence recorded.
- [ ] Applicable tests pass after implementation repair.
- [ ] Independent coordinated architecture/rules audit complete.
- [ ] Ready for Owner Review.

# CAP-DMG-007: Injured Crew

Package ID: CAP-DMG-007  
Title: Injured Crew  
Status: Draft  
Component Type: damage card  
Source Component: `injured_crew`  
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
Current Implementation Readiness: Partial; choice behavior exists but zero/one-option routing and protocol are incomplete  
Remaining Card-Specific Repair Classification: B — bounded implementation repair  
External Prerequisite Complexity: C — shared ADR-014 foundation implementation
Package Authority Role: Traceability/integration artifact only; it owns no runtime authority

## 1. Purpose

This package traces Injured Crew: immediately discard one available defense
token, then flip the card facedown. A sole token resolves automatically; with
multiple available tokens the ship owner chooses one. If none remains, open no
choice, mutate no token, and still flip the card and complete the effect.

## 2. Scope

### Included Behavior

- Available-token derivation, conditional owner choice, discard, no-token
  terminal branch, card flip, exact-once resolution, and composed return.
- Invocation from Attack, still-OPEN ADR-006 Maneuver/Asteroid,
  debug-authoritative, and future legal sources without owning those contexts.

### Excluded Behavior

- Faceup draw causation, general defense-token rules, enclosing completion, and
  generic immediate-effect/choice/continuation infrastructure.

### Dependencies

- Stable authority physical-card identity, target ship/token state, and the
  matching ADR-014 record while unresolved, bound to `CurrentAttackState`,
  `ship_activation_id` plus ADR-006 Maneuver execution, authoritative debug
  application, or a future accepted purpose-specific source identity.

### Assumptions

- Ready and exhausted tokens are available; already discarded tokens are not.
- Zero available tokens is an automatic no-token branch, never an impossible prompt.
- One available token resolves automatically; multiple available tokens create
  the ship-owner choice.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `injured_crew`
- Rules reference id: DM-005; Injured Crew card text

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: `damage_deck.gd`, `damage_card.gd`
- Metadata: `timing = immediate`, `count = 4`

### Activation Conditions

- A specific Injured Crew instance is dealt faceup to a surviving ship.

### Runtime Prerequisites

- Stable card/ship/enclosure identity and canonical defense-token states.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | `ShipInstance.defense_tokens`, its assigned physical `DamageCard`, and its at-most-one ADR-014 active record | The record references the card; player-choice projection exists only with multiple available tokens. | `src/core/state/ship_instance.gd`; `src/core/damage/damage_card.gd`; ADR-014 |
| Validation | Injured Crew command branch | Validates instance, ship, enclosure, owner actor, unresolved status and available token. | `_validate_injured_crew_choice()` |
| Execution | Injured Crew command branch | Owns discard or no-token branch, flip/move, and completion. | `_execute_injured_crew()` |
| Projection | `UIProjector` and existing choice/token/card routes | Derives only currently discardable tokens for the owner. | `immediate_effect_resolver.gd`; `damage_card_immediate_effect_controller.gd`; `attack_panel_mirror.gd` |
| Serialization | Existing state plus stable pending identity | Must resume a real choice without array/object references. | `damage_card.gd`; `interaction_flow.gd`; `game_state.gd` |
| Replay | `CommandProcessor` history | Replays chosen token or automatic no-token completion and return. | command history architecture |
| Network | Authority command plus passive application/snapshot | Correct owner submits; passive peers do not synthesize. | ADR-012 |
| Visibility | `StateFilter` | Card and token states/choice are public; post-flip identity is hidden. | ADR-013 |
| Tests | Injured Crew capability test owner | Owns full CON-003/TEST-003 evidence. | CON-003; TEST-003 |

All nine canonical CON-003 surfaces are **Required**.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Not Applicable | No registration exists | Immediate command owns the rule. |
| RuleSurface | Not Applicable | No modifier/blocker required | Legal draw sources invoke directly. |
| Commands | Required | `ResolveImmediateEffectCommand` | Current validator cannot complete the zero-token branch and lacks stable context. |
| Resolvers | Required | `get_required_choice()` | Correctly omits discarded tokens; empty result currently routes to a rejected command. |
| State Classes | Required | defense tokens and card arrays | Stable physical/pending identity missing. |
| Setup | Not Applicable | Standard deck loading only | No setup behavior. |
| UI Projection | Required | attack/debug modal routes | Owner prompt exists; canonical recovery and all source contexts are missing. |
| Serialization | Required | `damage_card.gd`; `interaction_flow.gd`; `game_state.gd` | Pending choice uses mutable index/transient references. |
| Replay | Required | command history | Zero-token, stale/duplicate and return evidence missing. |
| Networking | Required | `command_applicability.gd`; `flow_spec.gd`; `resolve_immediate_effect_command.gd`; `command_processor.gd`; `state_filter.gd` | Rules-assigned actor admission and passive effect-specific refresh need proof. |

## 6. Runtime State

### Required Runtime State

- ShipInstance-owned physical card, target ship/token states, and its matching
  ADR-014 record while unresolved, including owner chooser only for a real
  multiple-token decision and the purpose-specific source identity.

### Lifecycle

- Created atomically by: accepted faceup draw owner; zero/one-token automatic
  branches may instead complete in the same accepted transaction.
- Updated by: owner selection when a token is available.
- Consumed by: discard/no-token completion and enclosing return.
- Removed by: exact-once resolution or atomic destruction cleanup. Other
  source-card invalidation rejects unless atomically resolved/terminated by an
  accepted rule.
- If this authority physical card is later discarded/recycled and dealt again,
  the new assignment establishes a fresh ADR-014 obligation scoped to its new
  purpose-specific source identity. Prior resolution does not suppress it, and
  stale commands/identities from the earlier occurrence cannot authorize it;
  no generic permanent `immediate_resolved` flag is introduced.

### Persistence

- Save/load, replay, Network/reconnect: canonical card/ship/token/pending/enclosure
  state and ordered semantic commands; projection re-derived.

### Cleanup

- Cleanup owner: Injured Crew command for card-specific immediate mutation and
  record retirement; the purpose-specific parent owns return/termination.
  Debug completion is terminal.
- Cleanup trigger: resolution or atomic destruction cleanup; unrelated
  invalidation rejects unless an accepted rule atomically terminates the
  obligation. The purpose-specific parent separately owns return/termination.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/damage/damage_card.gd`; `src/core/state/ship_instance.gd`; `immediate_effect_resolver.gd` | Card/token state and option derivation. |
| Commands | `resolve_immediate_effect_command.gd` | Current validation/mutation and zero-token gap. |
| Resolvers | `get_required_choice()` | Ready/exhausted availability, discarded exclusion. |
| Tests | `test_immediate_effect_resolver.gd`; `test_resolve_immediate_effect_command.gd`; controller tests | Direct behavior and one debug live-route slice. |
| Documentation | card data; DM-005; MVP requirement correction note | Rule text. |
| Related packages | CAP-OBS-001 | One external faceup-draw source. |

## 8. Test Evidence

### Existing Evidence

- Unit tests cover ready/exhausted choices, discarded exclusion, discard, flip,
  command validation, and an Injured Crew debug-controller submission.

### Outstanding Evidence

- Automatic zero-token completion, stable/contextual identity, wrong actor,
  stale/duplicate, source-context return, save/reconnect/replay, passive refresh,
  visibility, real route and runtime smoke.

### TEST-003 Verification Matrix

| Category | Required package evidence |
| --- | --- |
| Opener / entry | Attack, Maneuver/Asteroid, and debug assignment atomically establish/resolve the exact card obligation. |
| Participants / controller | Damaged ship owner chooses only with multiple available tokens; zero and one are automatic. |
| Validation | Exact card/ship/record/owner/source identity and current ready/exhausted/discarded states; reject a token no longer available. |
| Authoritative command | One replayable command discards the selected/sole token or none, flips the card, and retires the record exactly once. |
| Continuation / return | Command owns card/token mutation and record cleanup; Attack/Maneuver owns valid return or termination; debug is terminal. |
| State ownership | ShipInstance owns card, defense tokens and at most one referencing ADR-014 record. |
| Serialization | Save/load all 0/1/multiple branches and pending multi-token decision with exact card, chooser and purpose-specific parent. |
| Replay | Reproduce option derivation, pending state change, discard/no-discard, flip, cleanup, destruction and one valid return. |
| Network protocol / application | Correct owner submits genuine choice; passive peers apply authority token/card result without synthesis. |
| Visibility / filtering | Public token/faceup semantics are projected; post-flip stable-card correlation is removed from state/history/reconnect. |
| UI / projection | No modal for zero/one; show all and only multiple available ready/exhausted tokens through the real route. |
| Runtime / manual smoke | Live Attack, Maneuver/Asteroid and debug routes, including token-state change while a choice is pending. |

Required negative/protocol coverage includes duplicate physical copies,
wrong/stale card, wrong ship, wrong actor, stale purpose-specific parent,
duplicate submission, exact-once recovery, reconnect during a multi-token
decision, replay, passive filtering/application, lifecycle invalidation,
destruction and invalid return. Card cases cover zero, one and multiple tokens;
ready, exhausted and discarded states; and state changes while pending.

TEST-003 SHALL prove that `CommandApplicability`, `FlowSpec.allowed_commands`,
and `ResolveImmediateEffectCommand.validate()` agree: projection cannot offer a
canonically rejected command, protocol/replay cannot bypass validation,
automatic zero/one-token branches expose no manual command, and the genuine
multiple-token branch exposes only commands legal for the current canonical
obligation. Redeal coverage SHALL prove a fresh assignment-scoped obligation
and rejection of earlier-occurrence identities.

## 9. Risk Assessment

- Serialization/replay impact: medium because a blocking owner choice must be
  reconstructed by physical card identity.
- Network/visibility impact: medium because actor admission and passive token/card refresh must agree.
- Metadata/status impact: remains Draft; metadata SHALL NOT imply CON-003
  integration before complete evidence and explicit Owner approval.

| Risk Area | Impact | Mitigation or Outstanding Work |
| --- | --- | --- |
| Replay | medium | Choice/no-token and exact return sequences. |
| Serialization | medium | Pending instance/enclosure recovery. |
| Network | medium | Owner admission, passive refresh, reconnect. |
| Visibility | medium | Public prompt and hidden post-flip identity. |
| Migration | medium | Version stable card/pending schema. |
| Complexity | medium | Explicit zero-token branch; no fabricated interaction. |

## 10. Integration Status

Current Status: Draft  
Evidence Summary: Main choice behavior exists; zero-token production completion and cross-surface proof do not.

Outstanding Work:

- Repair zero-token, identity, context, projection and recovery boundaries; pass
  all applicable TEST-003 evidence.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Coordinated Draft with settled zero-token semantics. |

## 12. Codex Checklist

- [x] Ownership, state, surfaces, risks, evidence, and N/A rationale identified.
- [x] Missing TEST-003 evidence recorded.
- [ ] Applicable tests pass after implementation repair.
- [ ] Independent coordinated architecture/rules audit complete.
- [ ] Ready for Owner Review.

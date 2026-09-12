# CAP-DMG-006: Life Support Failure

Package ID: CAP-DMG-006  
Title: Life Support Failure  
Status: Draft  
Component Type: damage card  
Source Component: `life_support_failure`  
Related ADRs: ADR-001, ADR-003, ADR-006, ADR-010, ADR-012, ADR-013, ADR-014  
Related Contracts: CON-001, CON-003  
Related Context Packs: CP-001  
Related Tests: TEST-003; required tests listed below  
Related Requirements: DM-005  
Related Boundaries: ADR-001/CON-001 Attack authority and return dependency; ADR-014 immediate exact-once boundary; existing RuleRegistry token-gain boundary  
Related Gaps: ADR-014 physical-card identity, active-obligation, recovery, Network filtering, and return implementation gaps  
Created: 2026-09-12  
Last Updated: 2026-09-12  
Owner: Project Owner  
Test Owner: Capability implementation owner; Project Owner review required  
Capability Classification: mixed
Current Implementation Readiness: Partial; immediate and persistent behavior exist but shared protocol evidence is incomplete  
Remaining Card-Specific Repair Classification: B — bounded implementation and coverage repair  
External Prerequisite Complexity: C — shared ADR-014 foundation implementation
Package Authority Role: Traceability/integration artifact only; it owns no runtime authority

## 1. Purpose

This package coherently traces both halves of Life Support Failure: immediately
discard all command tokens when dealt faceup, then keep the card faceup and
prevent that ship from having command tokens. It is usable from every legal
faceup draw and does not duplicate persistent-rule ownership.

## 2. Scope

### Included Behavior

- Immediate mandatory token discard, persistent token-gain restriction while
  this physical card remains faceup, exact-once immediate completion, and return.
- Invocation from Attack, still-OPEN ADR-006 Maneuver/Asteroid,
  debug-authoritative, and future legal sources without owning those contexts.

### Excluded Behavior

- Faceup draw causation, generic token management, repair/removal of damage
  cards, enclosing-flow completion, and generic immediate-effect infrastructure.

### Dependencies

- Stable authority physical-card identity and matching ADR-014 active record,
  `CommandTokenManager`, existing RuleRegistry token-gain call sites, and an
  applicable `CurrentAttackState`, `ship_activation_id` plus ADR-006
  Maneuver-execution, authoritative debug application, or future accepted
  purpose-specific source identity.

### Assumptions

- Existing `LifeSupportFailure` owns the continuing restriction; this package
  documents it and the immediate discard as one capability rather than creating
  a second persistent owner.
- Current production token-gain entry points are
  `ConvertDialToTokenCommand` and `TarkinChoiceCommand` leading to
  `GrandMoffTarkin.grant_command_tokens()`. Both SHALL enforce the existing
  `RuleSurface.TARGET_COMMAND_TOKEN_GAIN` restriction while Life Support
  Failure remains faceup. Every future token-gain surface SHALL route through
  that same accepted capability boundary without duplicating RuleRegistry
  authority.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `life_support_failure`
- Rules reference id: DM-005; Life Support Failure card text

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: `damage_deck.gd`, `damage_card.gd`
- Metadata: `timing = immediate_persistent`, `count = 2`

### Activation Conditions

- Immediate half: this instance is dealt faceup to a surviving ship.
- Persistent half: this same instance remains faceup on that ship.

### Runtime Prerequisites

- Stable card/ship identity, command-token state, exact-once command identity,
  and accepted token-gain command/RuleSurface call sites.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | ShipInstance-owned physical `DamageCard`, `ShipInstance.command_tokens`, and the at-most-one ADR-014 active record during the immediate half | The record references the card and retires after immediate resolution; the faceup card itself activates persistence. | `damage_card.gd`; `command_token_manager.gd`; ADR-014 |
| Validation | Immediate command plus `LifeSupportFailure` RuleRegistry validators/blockers | Immediate context and every later token-gain attempt require separate validation. | `resolve_immediate_effect_command.gd`; `life_support_failure.gd` |
| Execution | Immediate command clears tokens; token commands remain their own mutation owners | Persistent rule blocks rather than mutates through a parallel owner. | `_execute_life_support_failure()`; rule call sites |
| Projection | Existing token/card projection and RuleSurface blocker metadata | Shows committed token state and legal affordances only. | `immediate_effect_signals.gd`; `life_support_failure.gd` |
| Serialization | Card/ship/application state owners | Faceup instance and immediate completion must round-trip once. | `damage_card.gd`; `game_state.gd` |
| Replay | `CommandProcessor` history plus serialized faceup state | Replays discard; later token-gain legality derives from restored card state. | command/rule architecture |
| Network | Authority command and passive application/snapshot | Mirrors token discard/restriction without peer synthesis. | ADR-012/013 |
| Visibility | `StateFilter` | Faceup card and token counts are public; unrelated hidden state stays filtered. | `state_filter.gd` |
| Tests | Life Support Failure capability test owner | Owns immediate, persistent, protocol and distributed evidence. | CON-003; TEST-003 |

All nine canonical CON-003 surfaces are **Required**.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Required | `life_support_failure.gd`; `rule_bootstrap.gd` | Existing persistent validators/blockers are the sole persistent rule owner. |
| RuleSurface | Required | command-token-gain blocker/validator call sites | Must remain complete for every legal gain surface. |
| Commands | Required | immediate command; token-gain commands | Immediate schema lacks stable instance/enclosure/exact-once validation. |
| Resolvers | Required | immediate choice derivation | No choice; duplicate resolver mutation is not production authority. |
| State Classes | Required | faceup card and command tokens | Stable physical and exact-once application identity is missing. |
| Setup | Not Applicable | Standard deck loading only | No setup behavior. |
| UI Projection | Required | token/card refresh and blocker projection | Passive token refresh and source-context evidence are incomplete. |
| Serialization | Required | card/ship/flow state | Persistent rebuild is tested; unresolved immediate recovery is not. |
| Replay | Required | semantic command and derived rule state | Immediate-to-persistent continuity and return need proof. |
| Networking | Required | application/snapshot paths | Passive token refresh, reconnect and non-synthesis need proof. |

## 6. Runtime State

### Required Runtime State

- ShipInstance-owned physical faceup card, ship/token state, and its matching
  ADR-014 record until the immediate half completes; no player-pending or
  duplicate persistent state.

### Lifecycle

- Created atomically by: accepted faceup draw owner, or completed atomically in
  the same transaction when permitted.
- Updated by: immediate command; later card repair/removal changes persistence.
- Consumed by: immediate return and every accepted token-gain validation surface.
- Immediate record retires after token discard while the card remains faceup;
  later redeal creates a fresh assignment-scoped obligation. Persistent
  restriction ends only when accepted card lifecycle removes/flips the faceup
  source or the ship is destroyed.

### Persistence

- Save/load: card face state, tokens, application/enclosure; RuleRegistry derives restriction.
- Replay: immediate discard and later commands in history.
- Network/reconnect: public faceup/token state and passive application.

### Cleanup

- Cleanup owner: immediate command for token discard and ADR-014 record
  retirement; existing RuleRegistry/card lifecycle owns persistent activation;
  the purpose-specific parent owns return/termination. Debug is terminal.
- Cleanup trigger: immediate completion or atomic destruction cleanup. While the
  immediate record is unresolved, unrelated removal/flip rejects unless an
  accepted rule atomically terminates it; afterward normal lifecycle controls
  the persistent restriction. The parent separately owns return/termination.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/effects/rules/damage_cards/ship/life_support_failure.gd`; card/token owners | Existing persistent implementation. |
| Commands | `resolve_immediate_effect_command.gd`; token conversion commands | Immediate mutation and guarded token surfaces. |
| Resolvers | `immediate_effect_resolver.gd` | No-choice derivation. |
| Tests | `test_rule_life_support_failure.gd`; `test_resolve_immediate_effect_command.gd` | Immediate and persistent unit evidence, including save/load rebuild. |
| Documentation | card data; DM-005; `refactoring_phase_n_plan.md` | Rule text and existing ownership decision. |
| Related packages | CAP-OBS-001 | One external draw source. |

## 8. Test Evidence

### Existing Evidence

- Unit tests cover immediate token clearing, no-token success, persistent
  validators/blockers, command rejection, and persistent save/load rebuild.

### Outstanding Evidence

- Stable instance/context, exact-once, wrong enclosure, all token-gain surfaces,
  source-context return, passive projection, full replay, Network/reconnect,
  visibility and runtime smoke.

### TEST-003 Verification Matrix

Life Support Failure has no player decision, but no TEST-003 lifecycle category
is omitted: player-selection UI is not applicable because both immediate
discard and persistent restriction are automatic; status/blocker projection
and runtime smoke remain required.

| Category | Required package evidence |
| --- | --- |
| Opener / entry | Attack, Maneuver/Asteroid, and debug assignment atomically establish/resolve the exact immediate obligation; persistent restriction derives from the faceup card. |
| Participants / controller | No chooser/controller; authority performs immediate discard and later token-gain commands consult the persistent rule. |
| Validation | Exact card/ship/record/source identity and every token-gain surface; active-source invalidation rejects or atomically terminates. |
| Authoritative command | Immediate command discards all tokens and retires the record while leaving the card faceup; token commands retain their own mutation authority. |
| Continuation / return | Immediate command cleans its record; Attack/Maneuver parents own valid return/termination; debug ends terminally. Persistent restriction does not own continuation. |
| State ownership | ShipInstance owns card/tokens/record; existing `LifeSupportFailure` RuleRegistry rule is the sole derived persistent restriction owner. |
| Serialization | Save/load before/after immediate completion, multiple faceup copies, repair/removal/flip, and rebuild/remove the derived restriction without a permanent immediate flag. |
| Replay | Reproduce one immediate discard per assignment, fresh obligation on redeal, all later token-gain rejections, repairs and cleanup. |
| Network protocol / application | Authority applies discard/blocking decisions; passive peers apply public token/card results and do not synthesize follow-ups. |
| Visibility / filtering | Public faceup/token semantics remain visible; stable physical identity is not exposed and later concealment removes correlation. |
| UI / projection | No decision modal; every token-gain affordance reflects the RuleRegistry restriction and updates after repair/removal/flip. |
| Runtime / manual smoke | Real Attack, Maneuver/Asteroid, debug and every token-gain route; multiple-copy and repair lifecycle smoke. |

Required negative/protocol coverage includes duplicate physical copies,
wrong/stale card, wrong ship, wrong actor payload where supplied, stale parent,
duplicate submission, exact-once save/load/reconnect/replay, passive filtering,
destruction and invalid return. Capability-specific coverage SHALL enumerate
every token-gain surface, multiple faceup copies, immediate completion with the
card remaining faceup, repair/removal/flip, fresh obligation after redeal, and
rebuilding/removing the persistent restriction.

TEST-003 SHALL prove that `CommandApplicability`, `FlowSpec.allowed_commands`,
and each concrete authoritative command `validate()` path agree, including
`ConvertDialToTokenCommand` and `TarkinChoiceCommand` before
`GrandMoffTarkin.grant_command_tokens()`: projection cannot offer a canonically
rejected token-gain or immediate command, protocol/replay cannot bypass
validation, automatic branches expose no manual command, and every current or
future token-gain route enforces `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`.

## 9. Risk Assessment

- Serialization/replay impact: medium; persistence is derived correctly today,
  but immediate identity and continuity are incomplete.
- Network/visibility impact: medium; public state is simple, passive token refresh is incomplete.
- Metadata/status impact: remains Draft; metadata SHALL NOT imply CON-003
  integration before complete evidence and explicit Owner approval.

| Risk Area | Impact | Mitigation or Outstanding Work |
| --- | --- | --- |
| Replay | medium | Immediate/persistent continuity and return tests. |
| Serialization | medium | Stable instance/application recovery tests. |
| Network | medium | Passive token projection and reconnect tests. |
| Visibility | low | Public card/token state filtering tests. |
| Migration | medium | Version stable card identity without duplicating rule state. |
| Complexity | medium | Retain one persistent RuleRegistry owner. |

## 10. Integration Status

Current Status: Draft  
Evidence Summary: Immediate and persistent production behavior and strong unit evidence exist.

Outstanding Work:

- Repair shared identity/context/projection boundaries and complete TEST-003
  protocol, distributed, recovery, visibility and live-route evidence.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Coordinated Draft; existing persistent ownership preserved. |

## 12. Codex Checklist

- [x] Ownership, state, surfaces, risks, evidence, and N/A rationale identified.
- [x] Missing TEST-003 evidence recorded.
- [ ] Applicable tests pass after implementation repair.
- [ ] Independent coordinated architecture/rules audit complete.
- [ ] Ready for Owner Review.

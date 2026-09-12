# CAP-DMG-009: Comm Noise

Package ID: CAP-DMG-009  
Title: Comm Noise  
Status: Draft  
Component Type: damage card  
Source Component: `comm_noise`  
Related ADRs: ADR-001, ADR-003, ADR-006, ADR-010, ADR-012, ADR-013, ADR-014  
Related Contracts: CON-001, CON-003  
Related Context Packs: CP-001  
Related Tests: TEST-003; required tests listed below  
Related Requirements: DM-005  
Related Boundaries: ADR-001/CON-001 Attack authority and return dependency; ADR-014 purpose-specific immediate-resolution boundary; ADR-013 hidden-command filtering  
Related Gaps: ADR-014 physical-card identity, active-obligation, recovery, Network filtering, and return implementation gaps  
Created: 2026-09-12  
Last Updated: 2026-09-12  
Owner: Project Owner  
Test Owner: Capability implementation owner; Project Owner review required  
Capability Classification: mixed
Current Implementation Readiness: Partial; both mutations exist but settled 0/1/2-option routing is incomplete  
Remaining Card-Specific Repair Classification: B — bounded implementation repair  
External Prerequisite Complexity: C — shared ADR-014 foundation implementation
Package Authority Role: Traceability/integration artifact only; it owns no runtime authority

## 1. Purpose

This package traces Comm Noise. When dealt faceup, the opposing player chooses
between the currently legal alternatives: reduce speed by one or replace the
top hidden command dial. Sole speed resolves automatically; sole dial skips the
alternatives choice but retains the opponent's replacement-command decision;
two effects create an alternatives choice; none causes no gameplay mutation.
The card then flips facedown.

## 2. Scope

### Included Behavior

- Legal-option derivation, conditional opposing choice, speed or hidden-dial
  mutation, zero-option completion, card flip, exact-once resolution and return.
- Invocation from Attack, still-OPEN ADR-006 Maneuver/Asteroid,
  debug-authoritative, and future legal sources without owning those contexts.

### Excluded Behavior

- Faceup draw causation, general speed/navigation or dial-stack ownership,
  enclosing completion, and generic immediate-effect/choice/continuation logic.

### Dependencies

- Stable authority physical-card identity; canonical speed and hidden-dial
  availability; the matching ADR-014 record during any unresolved alternatives
  or replacement-value decision; and the applicable purpose-specific source
  identity.

### Assumptions

- Speed reduction is legal only above speed zero. Dial replacement is legal only
  with a top hidden dial. Any command value may replace it, including its current
  value; neither the old nor resulting hidden value is disclosed to unauthorized
  viewers. Sole speed is automatic; sole dial skips alternatives but retains the
  opponent's replacement-value decision; zero options still flips/completes.
- "Opposing player" means the canonical player opposing the damaged ship's
  owner in every source context, not the current attacker.

## 3. Rule Origin

### Component Source

- Component type: damage card
- Source component key: `comm_noise`
- Rules reference id: DM-005; Comm Noise card text

### Static Data

- Static data: `Resources/Game_Components/damage_cards.json`
- Loader/model: `damage_deck.gd`, `damage_card.gd`
- Metadata: `timing = immediate`, `count = 2`

### Activation Conditions

- A specific Comm Noise instance is dealt faceup to a surviving ship.

### Runtime Prerequisites

- Stable card/ship/enclosure identity, current speed, and filtered hidden-dial stack state.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | `ShipInstance.current_speed`, `CommandDialStack`, its assigned physical `DamageCard`, and its at-most-one ADR-014 active record | The record references the card and persists for a two-effect choice or sole-dial replacement-value decision. | `src/core/state/ship_instance.gd`; `command_dial_stack.gd`; `damage_card.gd`; ADR-014 |
| Validation | Comm Noise command branch | Validates instance, ship, purpose-specific source, unresolved status, canonical opponent of the damaged ship's owner, current alternative, and replacement command value where required. | `_validate_comm_noise_choice()` |
| Execution | Comm Noise command branch | Owns selected/sole/no-option result, flip/move and completion. | `_execute_comm_noise()` |
| Projection | `UIProjector` and existing choice/speed/dial/card routes | Projects legal alternatives and any replacement-value decision without exposing old or resulting hidden dial values to unauthorized viewers. | resolver/controller/filter paths |
| Serialization | Existing state plus stable pending identity | Must preserve speed/dial/card/enclosure and reconstruct a real two-option choice. | `game_state.gd`; `damage_card.gd`; `command_dial_stack.gd`; `interaction_flow.gd` |
| Replay | `CommandProcessor` history | Replays automatic/selected branch and return in order. | command history architecture |
| Network | Authority command plus passive application/snapshot | Opponent submits only a real choice; passive peers do not synthesize. | ADR-012 |
| Visibility | `StateFilter` command-dial filtering | Choice/result may be known; previous and unrelated hidden dial identities/order remain protected. | `state_filter.gd` |
| Tests | Comm Noise capability test owner | Owns full CON-003/TEST-003 evidence. | CON-003; TEST-003 |

All nine canonical CON-003 surfaces are **Required**.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Not Applicable | No registration exists | Immediate command owns the rule. |
| RuleSurface | Not Applicable | No modifier/blocker required | Legal draw sources invoke directly. |
| Commands | Required | `ResolveImmediateEffectCommand` | Current command always requires a choice and lacks stable actor/enclosure identity. |
| Resolvers | Required | `_build_comm_noise_options()` | Derives legal options but zero/one-option routing does not match settled semantics. |
| State Classes | Required | speed, dial stack, card arrays, flow | Stable physical/pending identity missing. |
| Setup | Not Applicable | Standard deck loading only | No setup behavior. |
| UI Projection | Required | attack mirror/debug controller/modal | Two-option prompt exists; automatic one/zero paths and recovery are incomplete. |
| Serialization | Required | `game_state.gd`; `damage_card.gd`; `command_dial_stack.gd`; `interaction_flow.gd` | Pending choice uses mutable index; hidden-state-safe recovery unproven. |
| Replay | Required | semantic command history | All availability branches, stale/duplicate and return need proof. |
| Networking | Required | submission/application/filter paths | Actor validation, passive speed refresh and hidden-dial proof are incomplete. |

## 6. Runtime State

### Required Runtime State

- ShipInstance-owned physical card, ship/current speed, hidden-dial
  availability, and its matching ADR-014 record while either the effect choice
  or replacement-command-value choice remains unresolved.

### Lifecycle

- Created atomically by: accepted faceup draw owner after legal-option
  derivation; sole-speed and zero-option branches may complete in that same
  accepted transaction.
- Updated by: the canonical opponent of the damaged ship's owner when choosing
  between two effects or selecting a replacement value for a sole dial effect.
- Consumed by: selected, sole-option, or zero-option command resolution and return.
- Removed by: exact-once resolution or atomic destruction cleanup. Other
  source-card invalidation rejects unless an accepted rule atomically resolves
  or terminates the obligation.
- If this authority physical card is later discarded/recycled and dealt again,
  the new assignment establishes a fresh ADR-014 obligation scoped to its new
  purpose-specific source identity. Prior resolution does not suppress it, and
  stale commands/identities from the earlier occurrence cannot authorize it;
  no generic permanent `immediate_resolved` flag is introduced.

### Persistence

- Save/load: card, speed, full-authority/owner dial state, pending/enclosure.
- Replay: ordered source, Comm Noise and return/termination commands.
- Network/reconnect: viewer-filtered dials and canonical pending projection.

### Cleanup

- Cleanup owner: Comm Noise command for card-specific immediate mutation and
  record retirement; the purpose-specific parent owns return/termination.
  Debug completion is terminal.
- Cleanup trigger: resolution or atomic destruction cleanup; unrelated
  invalidation rejects unless an accepted rule atomically terminates the
  obligation. The purpose-specific parent separately owns return/termination.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `immediate_effect_resolver.gd`; `ship_instance.gd`; `command_dial_stack.gd`; `damage_card.gd`; `state_filter.gd` | Options, canonical state and hidden-dial filtering. |
| Commands | `resolve_immediate_effect_command.gd` | Current validation/mutation and zero/one-option gap. |
| Resolvers | `_get_comm_noise_choices()` / `_build_comm_noise_options()` | Current alternative derivation. |
| Tests | `test_immediate_effect_resolver.gd`; `test_resolve_immediate_effect_command.gd` | Speed/dial choices and some unavailable-option unit evidence. |
| Documentation | card data; DM-005 | Rule identity/text plus settled correction in owner direction. |
| Related packages | CAP-OBS-001, CAP-DMG-003 | External draw source; current-speed result affects later Ruptured Engine re-derivation. |

## 8. Test Evidence

### Existing Evidence

- Unit tests cover speed reduction, reduction to zero, unavailable speed,
  dial replacement, no-dial cases, command validation and flip.

### Outstanding Evidence

- Mandatory sole option, zero-option completion, stable/contextual identity,
  wrong actor, stale/duplicate, Maneuver-to-Ruptured current-speed ordering,
  recovery/replay, passive speed/dial projection, hidden-dial visibility, real
  route and runtime smoke.

### TEST-003 Verification Matrix

| Category | Required package evidence |
| --- | --- |
| Opener / entry | Attack, Maneuver/Asteroid, and debug assignment derive legal effects and atomically establish/resolve the exact obligation. |
| Participants / controller | Canonical opponent of damaged ship owner chooses between two effects and chooses replacement value for any dial branch; never infer actor from attacker. |
| Validation | Exact card/ship/record/opponent/source identity, current speed/dial availability and submitted effect/value; any command value is legal. |
| Authoritative command | Resolve selected effect, sole speed automatically, sole dial after value choice, or no mutation when neither; then flip and retire exactly once. |
| Continuation / return | Command owns speed/dial/card mutation and record cleanup; matching Attack/Maneuver parent owns return/termination; debug is terminal. |
| State ownership | ShipInstance owns card/speed/record; CommandDialStack owns hidden dials; record references card and only required legal-choice facts. |
| Serialization | Save/load all availability branches and genuine decisions without revealing old dial; preserve exact card, chooser and purpose-specific source. |
| Replay | Reproduce effect/value choice, automatic branches, downstream current-speed ordering, flip, cleanup, destruction and one return. |
| Network protocol / application | Admit canonical opponent; authority mutates hidden dial; passive peers apply authorized result and never synthesize hidden outcome. |
| Visibility / filtering | Neither old nor resulting hidden dial value/identity/order is disclosed to unauthorized viewers in prompt, result, history, save or reconnect; post-flip correlation is retired. |
| UI / projection | Two effects: alternatives then value if dial; sole speed: no prompt; sole dial: value-only prompt; neither: no prompt. |
| Runtime / manual smoke | Live Attack, Maneuver/Asteroid and debug routes for both/sole-speed/sole-dial/neither, save/reconnect and destruction. |

Required negative/protocol coverage includes duplicate physical copies,
wrong/stale card, wrong ship, wrong actor, stale purpose-specific parent,
duplicate submission, exact-once recovery, reconnect during effect or value
choice, replay, passive filtering/application, lifecycle invalidation,
destruction and invalid return. Card cases cover all availability combinations,
every replacement command value including the existing value, downstream
speed-dependent ordering, and non-disclosure of old/resulting hidden values.

TEST-003 SHALL prove that `CommandApplicability`, `FlowSpec.allowed_commands`,
and `ResolveImmediateEffectCommand.validate()` agree: projection cannot offer a
canonically rejected command, protocol/replay cannot bypass validation,
automatic sole-speed/neither branches expose no manual command, and genuine
effect/replacement-value decisions expose only commands legal for the current
canonical obligation. Redeal coverage SHALL prove a fresh assignment-scoped
obligation and rejection of earlier-occurrence identities.

## 9. Risk Assessment

- Serialization/replay impact: high because availability depends on mutable speed
  and hidden dial state and can alter later Maneuver consequences.
- Network/visibility impact: high because the opponent acts without gaining the
  prior or unrelated hidden dial identities/order.
- Metadata/status impact: remains Draft; metadata SHALL NOT imply CON-003
  integration before complete evidence and explicit Owner approval.

| Risk Area | Impact | Mitigation or Outstanding Work |
| --- | --- | --- |
| Replay | high | All option-count branches and downstream ordering tests. |
| Serialization | high | Pending identity and hidden-dial-safe recovery. |
| Network | high | Opponent admission, passive speed/dial refresh, reconnect. |
| Visibility | high | Viewer-filtered prompt/result/history tests. |
| Migration | medium | Version card/pending schema without broad dial redesign. |
| Complexity | medium | Explicit 0/1/2-option derivation; no generic choice framework. |

## 10. Integration Status

Current Status: Draft  
Evidence Summary: Both mutations exist; current production routing mishandles zero and one legal option.

Outstanding Work:

- Repair option-count routing, identity/context/actor/projection/recovery
  boundaries and pass all applicable TEST-003 evidence.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Coordinated Draft with settled 0/1/2-option semantics. |

## 12. Codex Checklist

- [x] Ownership, state, surfaces, risks, evidence, and N/A rationale identified.
- [x] Missing TEST-003 evidence recorded.
- [ ] Applicable tests pass after implementation repair.
- [ ] Independent coordinated architecture/rules audit complete.
- [ ] Ready for Owner Review.

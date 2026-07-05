# CAP-ECM-001: Electronic Countermeasures Defense Token Override

Package ID: CAP-ECM-001
Title: Electronic Countermeasures Defense Token Override
Status: Draft
Component Type: upgrade
Source Component: electronic_countermeasures
Related ADRs: ADR-003, ADR-004
Related Contracts: CON-003, CON-004
Related Context Packs: CP-001
Related Tests: Required tests listed in this package
Created: 2026-07-05
Last Updated: 2026-07-05
Owner: Project Owner review required

## Identity

This Rule Capability Package covers the `electronic_countermeasures`
DEFENSIVE_RETROFIT upgrade behavior that allows a defending ship to exhaust
Electronic Countermeasures during the Spend Defense Tokens step to spend one
otherwise legal defense token that the attacker targeted with an Accuracy
result.

Static source:

- `Resources/Game_Components/upgrades/defensive_retrofit/electronic_countermeasures.json`
- `Resources/Game_Components/upgrades/defensive_retrofit/w0_electronic_countermeasures_rules.txt`

Observed metadata status:

- `rules_integration.status`: `NOT_INTEGRATED`
- `pending_rule_surfaces`: `attack.spend_defense_tokens.accuracy_override`,
  `status.ready_upgrade_card`
- `rule_surfaces`: accuracy-override enabler and status ready-cost validator
  metadata
- `runtime_state_requirements`: `upgrade_exhaustion_state`,
  `accuracy_targeted_tokens`, `spent_defense_tokens_this_attack`,
  `status_phase_ready_costs`

This package is a Draft architecture artifact only. It does not change upgrade
JSON, production code, metadata status, or integration status.

## Purpose

The purpose of this package is to preserve the completed evidence analysis and
accepted Project Owner decisions for Electronic Countermeasures as a CON-003
traceability artifact.

It identifies the accepted runtime upgrade ownership pattern, the required
defense-token surfaces, command model, evidence gaps, and required tests before
implementation work begins.

## Scope

Included behavior:

- Electronic Countermeasures availability during Attack Step 4: Spend Defense
  Tokens.
- Optional use by the defending ship that owns the runtime upgrade instance.
- Exhausting Electronic Countermeasures when accepted.
- Allowing exactly one eligible Accuracy-targeted defense token to be spent via
  the existing defense-token spend infrastructure.
- Validation, execution, projection, serialization, replay, network, visibility,
  and tests required for that behavior.

Excluded behavior:

- A generic upgrade framework.
- A generic timing-window framework.
- Other DEFENSIVE_RETROFIT upgrades.
- Other Accuracy effects.
- Redesign of the attack flow, defense-token flow, replay, network, or
  serialization architecture.
- Metadata status advancement.
- Marking this package `Integrated`.
- Any production implementation.

The non-recur Status Phase ready-cost that uses a Repair command token is
explicitly deferred to a later capability package or implementation slice. This
package implements only attack-time ECM behavior.

## Rules Summary

Electronic Countermeasures is an exhaustible DEFENSIVE_RETROFIT upgrade. While
defending, the ship may exhaust the card to spend one defense token that the
opponent targeted with an Accuracy result.

The static clarifications recorded in the catalog state that this effect does
not allow:

- spending a defense token while the defender is at speed 0,
- spending a defense token type already spent during the attack,
- spending the same defense token more than once during the attack.

The behavior is mixed:

- The rule source is static upgrade data.
- The active source is the defending ship's runtime upgrade instance.
- Availability depends on current attack/defense-token state.
- Accepting the ability mutates runtime upgrade `card_state`.
- Spending the selected token mutates ship defense-token state through the
  existing spend-defense-token path.
- The prompt and choice affect projection, replay, network, reconnect, and
  visibility.

Static metadata alone is not active behavior evidence.

## Accepted Implementation Decisions

The Project Owner has accepted these ECM-specific implementation decisions for
this package:

- ECM belongs to the defending ship's runtime upgrade instance.
- Static upgrade data remains immutable metadata referenced only by `data_key`.
- Mutable state belongs exclusively to the runtime upgrade instance.
- ECM is an optional ability.
- ECM shall be command-owned.
- Replayable commands shall be `UseECMCommand`, `DeclineECMCommand`, and the
  existing `SpendDefenseTokenCommand`.
- `UseECMCommand` validates ECM availability, exhausts the ECM runtime upgrade,
  creates a pending single-use authorization for one eligible Accuracy-targeted
  defense-token spend, and records `runtime_upgrade_id`.
- `UseECMCommand` does not select or spend the defense token.
- `DeclineECMCommand` explicitly records that the player declined ECM and
  becomes part of authoritative replay history.
- `SpendDefenseTokenCommand` selects the defense token, validates that the
  selected token is covered by the pending ECM authorization, performs the
  actual token spend, and clears the pending authorization after use.
- Existing `SpendDefenseTokenCommand` infrastructure shall be reused.
- Existing replay, serialization, reconnect, and networking architecture shall
  be reused.
- No new framework shall be introduced.
- The ECM interaction shall appear only if all availability conditions in this
  package are satisfied.
- ECM shall never ask the player to activate when no legal effect can occur.
- If ECM is unavailable, no ECM interaction shall be projected and the normal
  defense-token flow shall continue.
- If ECM is available, projection shall ask "Use Electronic Countermeasures?"
- If ECM is declined, `DeclineECMCommand` shall execute and the normal
  defense-token flow shall continue.
- If ECM is accepted, `UseECMCommand` shall execute, ECM shall exhaust, one
  Accuracy-targeted defense-token spend shall be authorized, and flow shall
  continue into the existing `SpendDefenseTokenCommand` path.
- The existing defense-token UI remains responsible for selecting the token to
  spend.
- ECM is completely public. Both players shall observe ECM availability, use,
  decline, selected defense token, and ECM exhaustion.
- Replay and reconnect shall reproduce the same public sequence.
- This package implements only attack-time ECM behavior; the non-recur Status
  Phase ready-cost using a Repair command token is deferred.

## Related Architecture Documents

- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/context/CP-001-game-component-rule-extension.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`

Authority notes:

- ADR-003 defines the accepted rule and validation surface architecture.
- ADR-004 defines the accepted runtime ownership model for active upgrade
  instances and mutable upgrade state.
- CON-003 defines the Rule Capability Package contract.
- CON-004 defines the implementation contract for runtime upgrade instances.
- CAP-UPG-001 provides the established Runtime Upgrade Pattern but does not
  decide ECM behavior.
- Codex may recommend readiness but may not mark this package `Integrated`.

## Runtime Ownership

Runtime ownership is governed by accepted ADR-004 and CON-004.

For this package, Electronic Countermeasures uses the default ownership model:
the source runtime upgrade instance belongs on the defending `ShipInstance` that
is carrying Electronic Countermeasures and references static upgrade data by
`data_key`.

The ECM rule exists only while that defending ship's runtime upgrade instance
exists in play. The ability is unavailable if the runtime upgrade instance is
missing, exhausted/not ready, discarded, disabled, or otherwise unusable.

Mutable ECM state belongs exclusively to the runtime upgrade instance. This
package does not create an exception to ADR-004 or CON-004.

## Runtime State

Required runtime facts:

- The defending ship's source runtime upgrade instance.
- The source runtime upgrade instance's `data_key`.
- The source runtime upgrade instance's `card_state`.
- Whether the source runtime upgrade instance is ready, exhausted, discarded, or
  disabled.
- The current attack interaction step.
- The defender identity and defense-token list.
- The set of Accuracy-targeted defense token indices for the current attack.
- The set of defense token types or token indices already spent during the
  current attack.
- The selected defense-token index when `SpendDefenseTokenCommand` spends under
  the pending ECM authorization.
- Resulting defense-token state after the existing spend-defense-token flow.

Canonical CON-004 runtime fields apply:

- `runtime_upgrade_id`
- `data_key`
- `owner_player_id`
- `source_ship_ref`
- `source_roster_entry_id`
- `source_assignment_id`
- `slot`
- `slot_index`
- `card_state`
- `trigger_guards`
- `rule_state`

Expected ECM-specific runtime state:

- `card_state.exhausted` / `card_state.readied` represent whether ECM is ready
  to use.
- `card_state.discarded` and `card_state.disabled` gate availability.
- Pending ECM authorization lives in the ECM runtime upgrade instance
  `rule_state`.
- Pending ECM authorization remains in `rule_state` only until cleared.
- Pending ECM authorization is valid only between `UseECMCommand` and the
  following authorized `SpendDefenseTokenCommand`.
- The pending authorization is valid only for the current attack, the defending
  ship, and one eligible Accuracy-targeted defense token.
- The pending authorization cannot be reused and cannot apply to another ship,
  token, attack, or later interaction step.
- The pending authorization must be serialized, replayed, and reconnect-safe
  while pending.
- The pending authorization must be cleared after the token spend, decline,
  attack end, or loss of the relevant interaction window.

This package does not currently require a once-per-round or once-per-phase
trigger guard. Exhaustion/readiness is the expected availability guard.

## Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| Static upgrade data | Required | `Resources/Game_Components/upgrades/defensive_retrofit/electronic_countermeasures.json`; `UpgradeData`; `AssetLoader` | Source exists, but metadata is not active behavior. |
| Fleet validation | Required | `FleetValidator`; `FleetUpgradeAssignment`; `FleetShipEntry` | Confirms legal defensive retrofit assignment before setup. |
| Runtime state | Required | ADR-004; CON-004; `ShipInstance.runtime_upgrades` pattern from CAP-UPG-001 implementation work | Source runtime upgrade instance belongs on the defending `ShipInstance` by default. |
| Attack state | Required | `AttackState.locked_tokens`; `AttackState.spent_tokens`; `InteractionStep.ATTACK_DEFENSE_TOKENS` | ECM availability depends on current attack defense-token state. |
| Command validation | Required | `CommandProcessor`; `CommandApplicability`; `UseECMCommand`; `DeclineECMCommand`; `SpendDefenseTokenCommand` | ECM shall be command-owned and must not bypass defense-token legality. |
| Command execution | Required | `UseECMCommand`; `DeclineECMCommand`; existing `SpendDefenseTokenCommand`; `ShipInstance.exhaust_defense_token`; runtime upgrade `card_state` mutation | Accepting ECM exhausts the runtime upgrade and authorizes one eligible Accuracy-targeted token spend; `SpendDefenseTokenCommand` spends the token. |
| RuleRegistry | Optional | `RuleRegistry`; `RuleSurface` | May be used only for suitable enabler/blocker surfaces; not a required passive observer. |
| RuleSurface | Required | Existing accuracy and defense-token blocker patterns; `RuleSurface.TARGET_ACCURACY_SPEND` evidence for Accuracy interactions | ECM must agree with existing rule-derived token spend eligibility. |
| Projection | Required | `InteractionFlow`; `FlowSpec`; `UIProjector`; attack defense-token modal | ECM requires an optional prompt or affordance only when it can have legal effect. |
| Serialization | Required | `GameState.serialize`; `PlayerState`; `ShipInstance`; `InteractionFlow`; command serialization | Runtime upgrade card state, active prompt payload, and defense-token state must survive save/load. |
| Replay | Required | `CommandProcessor` history; `GameReplay` | ECM acceptance/decline and token spend must replay deterministically. |
| Network | Required | `NetworkManager`; command result handling; snapshots; reconnect path | Authoritative command order and reconnect projection must agree. |
| Visibility | Required | `StateFilter`; `InteractionFlow.visible_to`; `UIProjector` | ECM availability, use, decline, selected token, and exhaustion are public. |
| Tests | Required | Required tests listed below | No existing tests prove ECM behavior active. |

## Validation

The ECM interaction shall only be offered if all of the following are true:

- The defending ship has a source runtime upgrade instance for
  `electronic_countermeasures`.
- ECM is ready.
- ECM is not discarded.
- ECM is not disabled.
- The defending ship is currently in `ATTACK_DEFENSE_TOKENS`.
- At least one Accuracy-targeted defense token exists that is otherwise legally
  spendable.

If any condition is not satisfied, no ECM interaction shall appear.

Required command validation checks:

- The submitting player is the defending ship's owner.
- The source runtime upgrade instance exists and belongs to the defending ship.
- The source runtime upgrade instance has `data_key =
  "electronic_countermeasures"`.
- The source runtime upgrade instance is ready, not exhausted, not discarded,
  and not disabled.
- The game is in the Spend Defense Tokens step for the relevant attack.
- The selected token index is currently Accuracy-targeted.
- The selected token is otherwise legally spendable under existing
  defense-token rules.
- The selected token is not discarded.
- The selected token does not violate speed-0 restrictions.
- The selected token type has not already been spent during this attack.
- The same defense token has not already been spent during this attack.
- The command references the source `runtime_upgrade_id` when targeting or
  mutating ECM.
- `UseECMCommand` validates ECM availability, records `runtime_upgrade_id`,
  exhausts the runtime upgrade, and creates a pending single-use authorization
  for one eligible Accuracy-targeted defense-token spend.
- `UseECMCommand` does not select or spend the defense token.
- `DeclineECMCommand` validates that the defender can decline the active ECM
  opportunity, records the decline in command history, and clears any pending
  ECM authorization for that opportunity.
- `SpendDefenseTokenCommand` selects the defense token, validates that any
  ECM-authorized Accuracy override covers the selected token for the current
  attack and defending ship, performs the final defense-token spend mutation,
  and clears the pending authorization after use.

Existing validation evidence:

- `SpendDefenseTokenCommand` validates ship identity, token index, token discard
  state, phase, and spend method.
- `DefenseTokenResolver` and attack-flow helper paths evaluate token spend
  blockers, spent-token limits, Accuracy locks, and token-specific defense
  rules.

Missing validation evidence:

- No ECM-specific command, preflight, applicability, or projection eligibility
  validation exists yet.

## Execution

If ECM is available:

1. Ask the defending player "Use Electronic Countermeasures?"
2. If the player declines:
   - execute `DeclineECMCommand`,
   - continue the normal defense-token step.
3. If the player accepts:
   - execute `UseECMCommand`,
   - exhaust ECM on the source runtime upgrade instance,
   - create a pending single-use authorization for one eligible
     Accuracy-targeted defense-token spend,
   - continue into the existing `SpendDefenseTokenCommand` flow.

The existing defense-token UI remains responsible for selecting the token.

Required execution behavior:

- ECM use is optional.
- ECM use is command-owned.
- ECM exhausts through runtime upgrade `card_state`.
- ECM decline is represented by `DeclineECMCommand`.
- ECM acceptance is represented by `UseECMCommand`.
- `UseECMCommand` does not select or spend the defense token.
- `SpendDefenseTokenCommand` selects the defense token, validates the pending
  ECM authorization, spends the token, and clears the authorization.
- ECM authorizes, and the existing defense-token flow spends, exactly one
  eligible Accuracy-targeted defense token.
- The pending authorization is single-use, current-attack-scoped,
  defending-ship-scoped, and must not survive token spend, decline, attack end,
  or loss of the relevant interaction window.
- ECM does not create an alternative defense-token mutation path when the
  existing spend-defense-token flow can be reused.
- ECM does not allow spending a token that normal defense-token legality would
  otherwise forbid.
- ECM does not ask the defender to activate when no legal effect can occur.
- The final command result must be deterministic for replay and network mirrors.

Existing execution evidence:

- `SpendDefenseTokenCommand` mutates ship defense-token state.
- `ShipInstance` owns defense-token state.
- Runtime upgrade instances own mutable upgrade card state under CON-004.

Missing execution evidence:

- No ECM-specific `UseECMCommand`, `DeclineECMCommand`, command-owned runtime
  upgrade mutation, pending authorization state, or authorization cleanup exists
  yet.

## Projection

Projection is required because ECM is optional and must be offered only when it
can produce a legal effect.

Required projection behavior:

- During `ATTACK_DEFENSE_TOKENS`, present an ECM affordance only to the
  defending player when every availability condition is satisfied.
- Do not present ECM when the source runtime upgrade instance is missing,
  exhausted/not ready, discarded, disabled, or has no eligible Accuracy-targeted
  token.
- Ask "Use Electronic Countermeasures?" when ECM is available.
- If the defender declines, submit `DeclineECMCommand` and return to the normal
  defense-token step without spending ECM.
- If the defender accepts, submit `UseECMCommand`, then continue through the
  existing defense-token flow.
- The existing defense-token UI remains responsible for selecting the token to
  spend.
- Both players can observe ECM availability, use, decline, selected token, and
  exhaustion through the projected public sequence.
- UI must render eligibility from serialized payload/projection data and must
  not re-implement ECM legality locally.

Existing projection evidence:

- `InteractionFlow` stores active flow, controller, visibility, and JSON-safe
  payload.
- `FlowSpec` lists allowed commands for `ATTACK_DEFENSE_TOKENS`.
- `UIProjector` maps attack defense-token steps to modal intent.
- Attack defense-token UI already renders blocked token indices from payload
  metadata.

Missing projection evidence:

- No ECM-specific FlowSpec command surface, payload metadata, UIProjector
  affordance, or modal routing exists yet.

## Serialization

Serialization impact is required.

State and payloads that may need serialization:

- The defending ship's ECM runtime upgrade instance.
- ECM `card_state.exhausted` and `card_state.readied`.
- Any active ECM prompt payload.
- Any pending single-use ECM authorization if the command/flow shape spans
  multiple submitted commands.
- Resulting ship defense-token state.
- Command payloads for `UseECMCommand`, `DeclineECMCommand`, and
  `SpendDefenseTokenCommand`.

Existing serialization evidence:

- CON-004 requires runtime upgrade instances to serialize with `ShipInstance`.
- `GameState.serialize()` serializes player states and interaction flow.
- `ShipInstance` serializes defense-token state.
- Commands serialize into command history.

Missing serialization evidence:

- No ECM-specific active prompt, command payload, or runtime upgrade mutation
  serialization test exists yet.

## Replay

Replay impact is required because ECM changes attack resolution and defense-token
state.

Required replay behavior:

- Replay history must contain explicit `UseECMCommand` and `DeclineECMCommand`
  entries.
- ECM exhaustion must replay deterministically.
- The selected defense-token spend must replay through the existing
  `SpendDefenseTokenCommand` path.
- Replay must preserve the command boundary: `UseECMCommand` creates only the
  pending authorization, while `SpendDefenseTokenCommand` selects, validates,
  spends, and clears it.
- Replay must not depend on local UI state or static metadata status to decide
  whether ECM was active.
- Replay must reproduce the same public availability, use, decline, selected
  token, and exhaustion sequence.

Existing replay evidence:

- `CommandProcessor` records command history.
- `GameReplay` replays serialized commands.
- `SpendDefenseTokenCommand` is serializable.

Missing replay evidence:

- No ECM-specific replay test exists.

## Network

Network impact is required.

Required network behavior:

- The authoritative peer/server accepts or rejects ECM commands.
- Remote peers mirror ECM exhaustion and the resulting defense-token spend in
  authoritative command sequence order.
- Remote peers preserve the command boundary: ECM use creates the pending
  authorization and the mirrored spend command selects, validates, spends, and
  clears it.
- Network behavior remains deterministic through the existing replay and
  command architecture.
- Reconnect during an ECM prompt reconstructs the correct prompt or defense
  token step from serialized state.
- Reconnect reconstructs ECM availability from authoritative state.
- Reconnect after ECM use reconstructs exhausted ECM card state and spent
  defense-token state.
- Passive peers must not synthesize ECM use, decline, or token spend locally.

Existing network evidence:

- Network code synchronizes commands, command results, snapshots, and reconnect
  projection.
- Existing remote command handling includes defense-token side effects.

Missing network evidence:

- No ECM-specific network, reconnect, or remote side-effect test exists.

## Visibility

Visibility impact is required.

Accepted visibility policy:

- ECM is completely public.
- Defense-token state is public.
- Accuracy-targeted defense-token indices are part of the attack flow and
  visible through defense-token UI state.
- Both players shall observe ECM availability, use, decline, selected defense
  token, and ECM exhaustion.
- Replay and reconnect shall reproduce the same public sequence.
- Runtime upgrade card exhausted/readied state is public once active upgrades
  are represented in public ship state.

## Risks

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Flow insertion | High | ECM occurs inside an existing attack defense-token step. | Use the accepted `UseECMCommand` / `DeclineECMCommand` / `SpendDefenseTokenCommand` shape without introducing a new framework. |
| Command sequencing | Medium | Accepting ECM exhausts an upgrade and authorizes a later defense-token spend. | Add command, replay, network, and reconnect tests for the accepted sequence. |
| Stale authorization | High | A pending ECM authorization is temporary and must not leak across ships, tokens, attacks, or steps. | Add validation and cleanup tests for spend, decline, attack end, and interaction-window loss. |
| No-effect prompt | Medium | ECM must not ask the player to activate when no legal token can be spent. | Projection and validation tests must cover no-eligible-token cases. |
| Defense-token legality | High | ECM overrides Accuracy targeting only; it must not bypass speed-0, already-spent, discarded, or blocker rules. | Reuse existing spend-defense-token infrastructure and add regression tests. |
| Replay | Medium | ECM choice changes attack outcome and card state. | Add replay tests for decline and use. |
| Network/reconnect | Medium | Prompt and command results affect live peer state and reconnect projection. | Add network/reconnect tests. |
| Deferred ready cost | Medium | Static metadata includes Repair-token ready cost, but this package implements only attack-time ECM behavior. | Track the non-recur Status Phase ready-cost in a later capability package or implementation slice. |
| Metadata drift | Medium | Static JSON currently says `NOT_INTEGRATED`. | Do not update metadata until evidence and owner approval support it. |

## Required Automated Tests

Required before this package can advance beyond Draft/Identified:

- Static/catalog test confirming ECM static upgrade data remains loadable and
  metadata remains a status claim, not active behavior proof.
- Setup/runtime materialization test proving a ship equipped with ECM gets a
  runtime upgrade instance with `data_key = "electronic_countermeasures"`.
- Save/load test proving ECM runtime upgrade `card_state` survives round trip.
- Projection eligibility tests proving ECM is offered only when all availability
  conditions are satisfied.
- Projection negative tests proving no ECM affordance appears when ECM is
  missing, exhausted/not ready, discarded, disabled, outside
  `ATTACK_DEFENSE_TOKENS`, or when no eligible Accuracy-targeted token exists.
- Command registration and applicability tests for `UseECMCommand` and
  `DeclineECMCommand`.
- Validation tests rejecting wrong player, wrong phase/step, missing source
  runtime upgrade instance, exhausted ECM, discarded ECM, disabled ECM, invalid
  token index, token not targeted by Accuracy, speed 0, already-spent token
  type, already-spent token index, and otherwise blocked tokens.
- Execution tests proving accepted ECM exhausts the runtime upgrade instance.
- Execution tests proving `UseECMCommand` authorizes exactly one eligible
  Accuracy-targeted token spend without selecting or spending the defense token.
- Execution tests proving `SpendDefenseTokenCommand` selects the defense token,
  validates the pending ECM authorization, performs the actual token spend
  through the existing defense-token path, and clears the authorization.
- Execution tests proving decline continues normal defense-token spending
  without exhausting ECM or spending a token and clears any pending ECM
  authorization for that opportunity.
- Cleanup tests proving pending ECM authorization cannot be reused, cannot apply
  to another ship, token, attack, or later step, and is cleared after token
  spend, decline, attack end, or loss of the relevant interaction window.
- Regression tests proving normal defense-token spending remains unchanged when
  ECM is unavailable or declined.
- Serialization tests for active ECM prompt payload if the flow can be saved
  during the prompt.
- Serialization, replay, and reconnect tests covering inter-command state after
  `UseECMCommand` creates pending authorization and before
  `SpendDefenseTokenCommand` clears it.
- Replay tests for ECM decline and ECM accepted use.
- Network command/result tests for ECM decline and ECM accepted use.
- Reconnect tests during ECM prompt and after ECM resolution.
- Visibility tests proving both players observe ECM availability, use, decline,
  selected defense token, and exhaustion.
- Metadata/status regression test if metadata is later advanced from
  `NOT_INTEGRATED`.

TEST-003 is not yet accepted, so the Project Owner determines whether test
coverage is sufficient for any non-Integrated status advancement.

## Required Manual Tests

Required before owner review of an implementation:

- Hot-seat attack where ECM is available and the defender accepts, chooses one
  Accuracy-targeted token, exhausts ECM, and spends that token.
- Hot-seat attack where ECM is available and the defender declines, then
  continues normal defense-token spending.
- Hot-seat attack where ECM is not available because no legal effect can occur;
  no ECM prompt or affordance appears.
- Save/load or reconnect during an ECM prompt if the implemented flow can pause
  at that point.
- Network attack where the remote defender uses ECM and both peers agree on ECM
  card state, spent defense-token state, and attack flow continuation.

Manual tests supplement automated tests. They do not replace required automated
coverage unless the Project Owner explicitly accepts a temporary exception.

## Open Questions

- What test threshold is sufficient while TEST-003 does not exist?

These questions do not reopen ADR-003, ADR-004, CON-003, or CON-004.

## Project Owner Decisions Required

Before status advancement, the Project Owner must decide or explicitly
delegate:

1. Minimum sufficient tests before status advancement.

   Rationale: TEST-003 remains unavailable, so the Project Owner determines test
   sufficiency for any status beyond Draft/Identified.

## Evidence Summary

1. Electronic Countermeasures exists as loadable static DEFENSIVE_RETROFIT
   upgrade data with `rules_integration.status = NOT_INTEGRATED`.
2. Static metadata identifies the relevant surfaces:
   `attack.spend_defense_tokens.accuracy_override` and
   `status.ready_upgrade_card`.
3. ADR-004 and CON-004 define the required runtime upgrade instance ownership
   pattern.
4. Existing attack flow has an `ATTACK_DEFENSE_TOKENS` step, defense-token
   payload fields, Accuracy-locked token state, and blocked-token metadata.
5. Existing defense-token infrastructure includes `SpendDefenseTokenCommand`,
   `DefenseTokenResolver`, `ShipInstance.defense_tokens`, and defense-token
   serialization.
6. The Project Owner has accepted `UseECMCommand`, `DeclineECMCommand`, and the
   existing `SpendDefenseTokenCommand` as the replayable command shape.
7. The Project Owner has accepted fully public ECM visibility.
8. The Project Owner has deferred the non-recur Status Phase Repair-token
   ready-cost to a later capability package or implementation slice.
9. Existing replay, network, reconnect, and projection surfaces can be reused,
   but ECM-specific behavior is not implemented.

## Evidence Gaps

- No ECM-specific command, command validation, or command-owned execution path.
- No ECM-specific projection affordance or `FlowSpec` allowed-command entry.
- No ECM-specific runtime upgrade `card_state` mutation.
- No ECM-specific pending authorization lifecycle implementation.
- No ECM-specific serialization/save-load test.
- No ECM-specific replay test.
- No ECM-specific network/reconnect test.
- No ECM-specific visibility test.
- No TEST-003-backed test sufficiency threshold.

## Integration Status

Current Status: Draft

Evidence summary:

- Static upgrade data exists and is loadable.
- Existing attack, defense-token, command, serialization, replay, network, and
  projection surfaces can support a narrow implementation.
- ADR-004 and CON-004 define active upgrade runtime ownership.
- Project Owner decisions for ECM runtime ownership, command-owned execution,
  explicit `UseECMCommand` and `DeclineECMCommand`, existing infrastructure
  reuse, public visibility, no-effect prompt suppression, ready-cost deferral,
  and no new framework are recorded.
- No active ECM runtime behavior exists in the evidence collected.

Outstanding work:

- Implementation.
- Tests across validation, execution, projection, serialization, replay,
  network, reconnect, and visibility.
- Owner determination of test sufficiency before status advancement while
  TEST-003 is unavailable.
- Metadata/status alignment after evidence exists.
- Owner review.

Approval state:

- Owner approval: not requested.
- Reviewers required: Project Owner; implementation owners for attack flow,
  commands, projection, serialization, replay, network, and visibility.
- Review date: Not applicable.

Status constraints:

- This package must remain Draft until the Project Owner advances it.
- This package must not be marked `Integrated` by Codex.
- Existing upgrade JSON must remain `NOT_INTEGRATED` unless separately updated
  under owner-approved work.

## Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-07-05 | Draft prepared | Created from completed evidence analysis. No integration approval claimed. |
| Codex | 2026-07-05 | Owner decisions recorded | Added accepted ECM command, visibility, runtime ownership, replay/network, and ready-cost scope decisions. Status remains Draft. |

## Recommended Implementation Task

Implement CAP-ECM-001 as a narrow Electronic Countermeasures attack-step
behavior slice. Use the ADR-004/CON-004 runtime upgrade instance on the
defending ship, keep static upgrade data referenced by `data_key`, mutate ECM
card state only on the runtime upgrade instance, implement `UseECMCommand` and
`DeclineECMCommand`, reuse existing `SpendDefenseTokenCommand` infrastructure,
and add focused validation, execution, projection, serialization, replay,
network, reconnect, visibility, and regression tests.

Do not update upgrade JSON integration status or mark this package `Integrated`
until owner review approves the evidence.

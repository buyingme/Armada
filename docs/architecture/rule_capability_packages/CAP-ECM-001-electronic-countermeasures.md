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
Last Updated: 2026-07-08
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

The non-recur Status Phase ready-cost that uses a Repair command token remains
a deferred implementation slice. This package now records the accepted
Project Owner decisions required to make that slice implementation-ready.

Those decisions do not advance CAP status, upgrade JSON status, or
implementation status.

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
- Attack-time ECM behavior and the deferred Status Phase ready-cost are separate
  implementation slices within this package.
- The deferred Status Phase ready-cost uses an ECM-specific command-owned
  implementation. It does not introduce a generic optional-rule framework or a
  generic upgrade-ready framework.
- During a timing window with multiple optional rules, the controlling player
  chooses the order in which to resolve available optional rules.
- One optional rule resolves completely before availability is recalculated.
- Declining one optional rule does not prevent using another optional rule in
  the same timing window.
- The available optional-rule list is recalculated after every accepted or
  declined optional rule.
- Permanent/passive effects continue to apply automatically and are not
  presented as optional choices.
- Unresolved optional Status Phase choices block advancement to the next Status
  Phase command.
- The ECM ready-cost timing location is immediately before `StartRoundCommand`,
  after `StatusPhaseCleanupCommand` has completed.
- ECM Status Phase ready-cost use is represented by a replayable
  `ReadyECMCommand`.
- ECM Status Phase ready-cost decline is represented by a replayable
  `DeclineECMReadyCommand`.
- `ReadyECMCommand` spends one Repair command token from the source ship
  carrying ECM and readies the source ECM runtime upgrade instance.
- ECM Status Phase ready-cost temporary guards live in the ECM runtime upgrade
  instance `rule_state` until the ready-cost window exits.
- The ECM-specific command-owned ready-cost implementation surface owns cleanup
  of `rule_state.status_ready_cost`.
- `ReadyECMCommand` and `DeclineECMReadyCommand` update the authoritative
  `rule_state.status_ready_cost` guard and do not remove it.
- The authoritative `rule_state.status_ready_cost` guard survives until the
  optional-rule window exits.
- ECM Status Phase ready-cost projection is derived from authoritative state and
  never owns gameplay state.
- The Status Phase ready-cost is public.

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

## Deferred Status Phase Ready-Cost Slice

This section records evidence for the printed Electronic Countermeasures
non-recur ready cost:

> During the Status Phase, you may spend 1 Repair token to ready this card.

The attack-time ECM behavior and the deferred Status Phase ready-cost are
separate implementation slices. This section records the accepted Project Owner
answers that make the Status Phase ready-cost slice implementation-ready.

### Existing Architecture Evidence

Status Phase command flow:

- `StatusPhaseCleanupCommand` is the existing replayable command for Status
  Phase cleanup.
- `StatusPhaseCleanupCommand.validate()` requires
  `Constants.GamePhase.STATUS`.
- `StatusPhaseCleanupCommand.execute()` readies exhausted defense tokens,
  resets activation flags, and clears spent command-dial history.
- `StatusPhaseCleanupCommand` does not ready runtime upgrade cards and does not
  spend command tokens.
- `StartRoundCommand` is the existing replayable command that transitions from
  Status Phase to Command Phase.
- `AdvancePhaseCommand` rejects `STATUS -> COMMAND` advancement and directs
  that `StartRoundCommand` be used.
- `GameManager._begin_status_phase()` currently performs status cleanup and
  then advances the phase on the authoritative peer.
- Network clients do not perform local Status Phase cleanup; they receive the
  authoritative cleanup and phase results.

Command-token evidence:

- `CommandTokenManager` supports checking, removing, spending, serializing, and
  deserializing command tokens.
- `SpendTokenCommand` removes one command token from a ship and is currently
  applicable in Ship Phase only.
- `DiscardTokenCommand` handles command-token overflow discard and is currently
  applicable in Ship Phase only.
- No existing command represents spending a Repair command token during Status
  Phase to ready an upgrade card.

Runtime upgrade evidence:

- CON-004 runtime upgrade instances live on the owning `ShipInstance` by
  default.
- ECM exhaustion/readiness is represented by the source runtime upgrade
  instance `card_state`.
- `ShipInstance` serialization preserves runtime upgrade `card_state` and
  `rule_state`.
- No generic upgrade-card readying command or helper is required by existing
  architecture.

Flow, projection, and save evidence:

- `FlowSpec` contains `STATUS_CLEANUP / STATUS_CLEANUP_STEP` with allowed
  commands `status_phase_cleanup` and `start_round`.
- `UIProjector` can project flow-specific modal intent and rule affordances, but
  no ECM Status Phase affordance exists.
- `SaveGameManager` treats `STATUS_CLEANUP_STEP` as a safe save point.
- Existing remote status-cleanup handling refreshes defense-token and command
  dial visuals; it does not refresh runtime upgrade card readiness.

RuleSurface evidence:

- `RuleSurface.TARGET_DEFENSE_TOKEN_READYING` exists for Status Phase defense
  token readying.
- `CompartmentFire` uses a Status Phase cleanup modifier to block defense-token
  readying.
- No existing `RuleSurface` target specifically represents upgrade-card readying
  or command-token payment for upgrade ready costs.

### Architecture Support Assessment

Existing architecture partially supports the ready-cost slice:

- Runtime ownership is already supported by ADR-004 and CON-004.
- The source ECM runtime upgrade instance is the authoritative owner of
  `card_state.exhausted` and `card_state.readied`.
- Command-token state and runtime upgrade state are both serialized through
  existing state owners.
- Existing command history, replay, network, and reconnect architecture can
  carry a narrow replayable command if one is added.

Existing architecture does not yet fully support the ready-cost slice:

- There is no existing Status Phase command that spends a Repair token and
  readies a runtime upgrade card.
- Existing Status Phase cleanup is automatic on the authoritative peer, so the
  ECM ready-cost prompt must be inserted after cleanup and before
  `StartRoundCommand`.
- Existing `FlowSpec` does not include a player-controlled Status Phase
  upgrade-ready choice.
- Existing remote status-cleanup side effects do not refresh runtime upgrade
  card readiness.

### Accepted Project Owner Answers

The Project Owner has accepted the following answers for the deferred ECM
Status Phase ready-cost slice:

1. If multiple optional Status Phase rules are simultaneously available, the
   controlling player chooses the order in which to resolve them.
2. Resolve one optional rule completely, recalculate the available optional
   rules, and repeat until no optional rules remain or the player declines all
   remaining optional rules.
3. Declining one optional rule does not prevent using another optional rule.
4. The available optional-rule list is recalculated after every accepted or
   declined optional rule.
5. Permanent/passive effects continue to apply automatically and never appear as
   optional choices.
6. Unresolved optional Status Phase decisions block advancement to the next
   Status Phase command.
7. The ECM ready-cost timing location is immediately before
   `StartRoundCommand`, after `StatusPhaseCleanupCommand` has completed.
8. The ECM ready-cost implementation remains ECM-specific and shall not create a
   generic optional-rule framework or generic upgrade-ready framework.

### Timing Location Decision

The ECM ready-cost opportunity occurs immediately before `StartRoundCommand`,
after `StatusPhaseCleanupCommand` has completed.

Rejected locations:

- Before `StatusPhaseCleanupCommand`: this would delay existing automatic
  cleanup and make optional upgrade readying precede established Status Phase
  cleanup.
- Inside `StatusPhaseCleanupCommand`: this would mix optional player choice into
  a system cleanup command and obscure replayable choice history.
- After `StatusPhaseCleanupCommand` without blocking `StartRoundCommand`: this
  would allow the Status Phase to advance before unresolved optional choices are
  resolved.

Consequences:

- Replay remains ordered as explicit commands:
  `advance_phase -> status_phase_cleanup -> ready/decline commands ->
  start_round`.
- Serialization can preserve a pending ready-cost prompt at a Status Phase
  safe point after cleanup and before `start_round`.
- Reconnect can reconstruct the ready-cost prompt from authoritative runtime
  upgrade state, command-token state, and temporary guards.
- Network mirrors apply status cleanup before any ECM ready-cost decision and
  apply `start_round` only after ready-cost choices are resolved.
- Command sequencing remains narrow: cleanup stays system-owned, ECM ready-cost
  stays command-owned, and `start_round` remains the transition to Command
  Phase.

### Expected Command Protocol

The command protocol below is the accepted protocol shape for the ECM
Status Phase ready-cost slice.

`ReadyECMCommand` and `DeclineECMReadyCommand` are ECM-specific replayable
commands for this slice.

Expected hot-seat sequence:

1. `advance_phase` enters `STATUS`.
2. `status_phase_cleanup` executes as the existing system cleanup command.
3. Projection presents the current public list of available optional Status
   Phase rules. For ECM, availability is derived from the source ECM runtime
   upgrade instance and source ship command-token state.
4. The controlling player chooses one available optional rule.
5. For ECM, the controlling player submits exactly one of:
   - `ReadyECMCommand`, referencing the ECM `runtime_upgrade_id`, or
   - `DeclineECMReadyCommand`, referencing the ECM `runtime_upgrade_id`.
6. `ReadyECMCommand` validates, spends one Repair token from the source ship,
   sets ECM `card_state.exhausted = false`, sets
   `card_state.readied = true`, and records a temporary resolved guard in the
   ECM runtime upgrade instance `rule_state`. It does not remove the
   authoritative `rule_state.status_ready_cost` guard.
7. `DeclineECMReadyCommand` validates and records a temporary declined guard in
   the ECM runtime upgrade instance `rule_state` without spending a token or
   readying ECM. It does not remove the authoritative
   `rule_state.status_ready_cost` guard.
8. Projection clears or recalculates the derived optional-rule list.
9. Repeat steps 3-8 until no optional Status Phase rules remain available or
   the player has declined all remaining optional rules.
10. `start_round` executes and transitions to Command Phase.
11. The authoritative `rule_state.status_ready_cost` guard survives until the
   optional-rule window exits. The ECM-specific command-owned ready-cost
   implementation surface clears it when the ready-cost window exits through
   `start_round`, flow replacement, cancellation, load/reconnect reconstruction
   outside the window, or another explicit exit from that Status Phase window.

Expected network host sequence:

1. The authoritative peer enters `STATUS` through `advance_phase`.
2. The authoritative peer executes and broadcasts `status_phase_cleanup`.
3. The authoritative peer projects the current public optional Status Phase rule
   list.
4. The controlling peer submits `ReadyECMCommand` or
   `DeclineECMReadyCommand` for the chosen ECM source when ECM is selected.
5. The authoritative peer validates, executes, records, and broadcasts the ECM
   command in `GameCommand.sequence` order.
6. Remote peers mirror the accepted command, update command-token state,
   runtime upgrade card state, authoritative guard state, and derived
   projection. `ReadyECMCommand` and `DeclineECMReadyCommand` update the guard
   and do not remove it.
7. The authoritative peer recalculates available optional rules.
8. Steps 3-7 repeat until no optional Status Phase rules remain available or the
   player has declined all remaining optional rules.
9. The authoritative peer executes and broadcasts `start_round`.
10. Remote peers mirror `start_round`; the ECM-specific command-owned
   ready-cost implementation surface clears ECM Status Phase ready-cost
   temporary guards for that window.

Expected network client sequence:

1. The client mirrors authoritative `advance_phase`.
2. The client mirrors authoritative `status_phase_cleanup`.
3. The client receives the projected public optional Status Phase rule list.
4. If the client controls the chosen ECM source, the client submits
   `ReadyECMCommand` or `DeclineECMReadyCommand` to the authoritative peer.
5. The client does not locally synthesize ECM ready-cost execution.
6. The client mirrors authoritative ECM command results in
   `GameCommand.sequence` order.
7. The client recalculates derived projection from mirrored authoritative state.
8. Steps 3-7 repeat until no optional Status Phase rules remain available or the
   player has declined all remaining optional rules.
9. The client mirrors authoritative `start_round`.
10. Reconnect reconstructs the same pending opportunity, ready/decline result,
   command-token state, runtime upgrade `card_state`, and
   `status_phase_cleanup` / `start_round` sequence from serialized state and
   command history.

### Runtime Ownership

The ECM runtime upgrade instance on the source `ShipInstance` remains the
authoritative owner of ECM card readiness:

- `card_state.exhausted = true` and `card_state.readied = false` means the ECM
  card is exhausted and may be eligible for the printed ready cost.
- The ready-cost command, if accepted, must mutate only the source runtime
  upgrade instance `card_state`.
- Static upgrade data remains referenced by `data_key` only.
- No fleet-level, player-level, projection-level, or UI-level owner of ECM
  readiness is introduced.

The source ship's `CommandTokenManager` remains the authoritative owner of the
Repair command token spent for the ready cost.

Temporary authoritative state:

- `rule_state.status_ready_cost` on the ECM runtime upgrade instance records
  ready-cost window facts needed to reject duplicate ready/decline and suppress
  repeated prompts during the same Status Phase window.
- `ReadyECMCommand` and `DeclineECMReadyCommand` update the authoritative
  `rule_state.status_ready_cost` guard and do not remove it.
- The authoritative `rule_state.status_ready_cost` guard survives until the
  optional-rule window exits.
- The ECM-specific command-owned ready-cost implementation surface owns cleanup
  of `rule_state.status_ready_cost`.
- The cleanup triggers are: `start_round` succeeds, the Status Phase ready-cost
  window is replaced, the flow is cancelled or replaced, save/load
  reconstruction determines the window is no longer active, reconnect
  reconstruction determines the window is no longer active, or another explicit
  exit from that Status Phase window occurs.
- Cleanup responsibility is limited to removing the temporary
  `rule_state.status_ready_cost` guard for the exited window. It does not change
  the already authoritative `card_state` result of `ReadyECMCommand` or the
  command-token result of `ReadyECMCommand`.

Derived projection state:

- `InteractionFlow.payload` may contain the currently projected optional-rule
  list, ECM source references, and UI copy.
- This projection state is derived from current phase/window, runtime upgrade
  `card_state`, runtime upgrade `rule_state`, and command-token state.
- Projection state is not authoritative for ECM readiness, Repair-token payment,
  duplicate rejection, or command legality.

### Validation And Execution Surfaces

Required validation for a future implementation:

- The game is in the Status Phase ready-cost window after
  `status_phase_cleanup` and before `start_round`.
- The command is submitted by the player who owns the source ship.
- The source ship exists, is controlled by the submitting player, and is not in
  an invalid state for using upgrade text.
- The source runtime upgrade instance exists on that ship.
- The source runtime upgrade instance has `data_key =
  "electronic_countermeasures"`.
- The source runtime upgrade instance is exhausted and not readied.
- The source runtime upgrade instance is not discarded.
- The source runtime upgrade instance is not disabled.
- The source ship has a Repair command token available to spend.
- The Repair token is spent from the source ship carrying ECM.
- A ready command cannot ready an already ready ECM card.
- A decline command cannot be submitted for an unavailable or already resolved
  ECM ready-cost opportunity.
- Repeated ready or decline commands for the same ready-cost opportunity are
  rejected.
- `start_round` is rejected while unresolved optional Status Phase choices
  remain available.

Required execution behavior for a future implementation:

- Accepted ready-cost execution spends exactly one Repair command token from
  the authoritative command-token owner.
- Accepted ready-cost execution sets ECM `card_state.exhausted = false` and
  `card_state.readied = true`.
- Accepted ready-cost execution must not copy static upgrade data into runtime
  state.
- Decline records an explicit replayable `DeclineECMReadyCommand`.
- `ReadyECMCommand` and `DeclineECMReadyCommand` update the authoritative ECM
  runtime upgrade `rule_state.status_ready_cost` guard for the current Status
  Phase ready-cost window and do not remove it.
- The authoritative `rule_state.status_ready_cost` guard survives until the
  optional-rule window exits and is cleaned only by the ECM-specific
  command-owned ready-cost implementation surface.
- The implementation must not create a generic upgrade-ready framework.

FlowSpec and CommandApplicability obligations:

- `FlowSpec` shall allow `ReadyECMCommand` and `DeclineECMReadyCommand` only in
  the Status Phase ready-cost window.
- `CommandApplicability` shall classify both commands as Status Phase
  ready-cost commands.
- `start_round` remains the Command Phase transition command but shall be
  blocked while available optional Status Phase rules remain unresolved.
- `status_phase_cleanup` remains the cleanup command and shall not own ECM
  optional player choice.

RuleSurface responsibility:

- RuleRegistry/RuleSurface is not required for ECM Status Phase ready-cost
  execution.
- If implementation uses an existing accepted RuleSurface call site to advertise
  ECM availability, that surface remains an affordance/enabler only.
- ECM command validation remains authoritative and shall not trust RuleSurface
  metadata or UI projection alone.

### Projection, Visibility, And Cleanup

Projection:

- The ECM ready-cost affordance must be derived from authoritative runtime
  upgrade state and command-token state.
- UI must not be the authority for ECM readiness, Repair token ownership, or
  payment legality.
- No affordance should appear when the ready cost cannot have legal effect.
- Projection must present all currently available optional Status Phase rules
  during the ready-cost window.
- Projection must recalculate after every accepted or declined optional rule.
- Projection must not present permanent/passive effects as choices.
- UI is responsible only for displaying the derived rule list and submitting the
  selected ECM ready or decline command.

Visibility:

- ECM readiness, exhaustion, Repair command tokens, ready-cost use, and
  ready-cost decline are public state.

Cleanup:

- Any projected Status Phase ECM ready-cost opportunity must be cleared after
  ready, decline, loss of the ready-cost window, flow replacement, save/load
  reconstruction, reconnect reconstruction, or transition out of the relevant
  Status Phase point.
- Runtime upgrade `card_state` remains authoritative after projection cleanup.
- `ReadyECMCommand` and `DeclineECMReadyCommand` update the authoritative
  `rule_state.status_ready_cost` guard and do not remove it.
- The authoritative `rule_state.status_ready_cost` guard survives until the
  optional-rule window exits.
- The ECM-specific command-owned ready-cost implementation surface owns cleanup
  of `rule_state.status_ready_cost`.
- The cleanup triggers are: `start_round` succeeds, the Status Phase ready-cost
  window is replaced, the flow is cancelled or replaced, save/load
  reconstruction determines the window is no longer active, reconnect
  reconstruction determines the window is no longer active, or another explicit
  exit from that Status Phase window occurs.
- Cleanup responsibility is limited to removing the temporary
  `rule_state.status_ready_cost` guard for the exited window. Projection
  cleanup does not own authoritative guard cleanup.

### Serialization, Replay, Reconnect, And Network

Serialization requirements for a future implementation:

- Runtime upgrade `card_state` must serialize after ECM is readied.
- Source ship command-token state must serialize after the Repair token is
  spent.
- Any pending ECM ready-cost prompt must serialize through existing
  `InteractionFlow` payload conventions if the game can be saved while the
  prompt is active.
- Runtime upgrade `rule_state.status_ready_cost` must serialize while the
  Status Phase ready-cost window is active.
- Save/load after `DeclineECMReadyCommand` must preserve the authoritative
  declined `rule_state.status_ready_cost` guard while the Status Phase
  ready-cost window remains active.
- Save/load while the prompt is open must reconstruct the same available
  optional-rule list from authoritative runtime upgrade state, command-token
  state, and temporary guards.
- Save/load after ECM is readied must preserve spent Repair token state, ECM
  `card_state.readied = true`, and absence of the resolved ECM source from the
  remaining optional-rule list.

Replay requirements for a future implementation:

- Ready and decline outcomes must be represented by replayable command history.
- `ReadyECMCommand` and `DeclineECMReadyCommand` update the authoritative
  `rule_state.status_ready_cost` guard and do not remove it; replay must retain
  the guard until the optional-rule window exits.
- Replay must reproduce Repair token payment, ECM card readiness, and the
  following Status Phase cleanup/start-round sequence.
- Replay must not infer ready-cost use from projection-only state.
- Replay evidence must include both accepted ready and explicit decline paths.
- Replay must preserve the accepted command order:
  `advance_phase -> status_phase_cleanup -> ready/decline commands ->
  start_round`.

Reconnect and network requirements for a future implementation:

- Reconnect during a pending ready-cost opportunity must reconstruct the same
  opportunity from serialized authoritative state.
- Reconnect after readying must reconstruct spent Repair token state and ECM
  ready `card_state`.
- Reconnect after `DeclineECMReadyCommand` must reconstruct the authoritative
  declined `rule_state.status_ready_cost` guard while the Status Phase
  ready-cost window remains active.
- Network mirrors must apply ready-cost results in authoritative command
  sequence order.
- Remote side effects must refresh both command-token display and runtime
  upgrade card readiness display.
- Network command handling must classify `ReadyECMCommand` and
  `DeclineECMReadyCommand` so remote peers update projection after each
  authoritative result.
- Network clients must not synthesize ready-cost execution locally.
- Out-of-order network command results must not allow `start_round` to apply
  before prior authoritative ready/decline results.

### Future Production Surfaces

A future implementation is expected to inspect or touch the following existing
surfaces:

- `src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd`
- `src/core/commands/status_phase_cleanup_command.gd`
- `src/core/commands/start_round_command.gd`
- `src/core/commands/spend_token_command.gd`
- `src/core/commands/command_applicability.gd`
- `src/core/state/flow_spec.gd`
- `src/core/network/ui_projector.gd`
- `src/autoload/game_manager.gd`
- `src/core/state/ship_instance.gd`
- `src/core/state/command_token_manager.gd`
- Status Phase modal/router/UI surfaces, if a player prompt is required.
- Replay, save/load, network, and reconnect tests covering Status Phase command
  history.

### Remaining Owner Decisions For Ready Cost

No remaining Project Owner decisions.

### Required Tests For Ready Cost

Required automated tests for a future implementation:

- Static/catalog test confirming ECM metadata exposes the Status Phase ready
  surface without treating metadata as active behavior.
- Runtime validation tests for correct phase/window, wrong player, missing
  source ship, missing runtime upgrade, wrong `data_key`, already ready ECM,
  discarded ECM, disabled ECM, missing Repair token, and duplicate ready/decline.
- Execution test proving a valid ready command spends exactly one Repair token
  from the source ship and sets ECM `card_state.exhausted = false` and
  `card_state.readied = true`.
- Decline test proving explicit decline is replayable.
- Guard lifecycle tests proving the authoritative
  `rule_state.status_ready_cost` guard is retained after `ReadyECMCommand`.
- Guard lifecycle tests proving the authoritative
  `rule_state.status_ready_cost` guard is retained after
  `DeclineECMReadyCommand`.
- Cleanup tests proving the ECM-specific command-owned ready-cost implementation
  surface clears `rule_state.status_ready_cost` on `start_round`.
- Cleanup tests proving the ECM-specific command-owned ready-cost implementation
  surface clears `rule_state.status_ready_cost` on flow replacement.
- Cleanup tests proving the ECM-specific command-owned ready-cost implementation
  surface clears `rule_state.status_ready_cost` on cancellation.
- Projection tests proving the affordance appears only for eligible ECM ready
  costs and disappears after ready, decline, or leaving the ready-cost window.
- Projection tests proving all currently available optional Status Phase rules
  are presented, one resolves at a time, and availability is recalculated after
  each accepted or declined rule.
- FlowSpec and CommandApplicability tests for any new ready/decline commands or
  Status Phase allowed-command changes.
- Tests proving `start_round` is blocked while optional Status Phase choices
  remain unresolved and allowed after all choices are resolved or declined.
- Serialization/save-load tests during a pending ready-cost prompt and after a
  successful ready payment.
- Save/load tests after `DeclineECMReadyCommand` proving the declined
  `rule_state.status_ready_cost` guard is preserved while the Status Phase
  ready-cost window remains active.
- Replay tests for ready and decline sequences through `status_phase_cleanup`
  and `start_round`.
- Network mirror tests proving command-token state and ECM card readiness update
  on remote peers.
- Network ordering tests proving `start_round` cannot mirror before prior
  authoritative ready/decline results.
- Reconnect tests during pending ready-cost opportunity and after readying.
- Reconnect tests after `DeclineECMReadyCommand` proving the declined
  `rule_state.status_ready_cost` guard is reconstructed while the Status Phase
  ready-cost window remains active.
- Public visibility tests for ready-cost availability, Repair token spend, ECM
  ready state, and explicit decline.
- Regression tests proving existing Status Phase defense-token cleanup,
  `CompartmentFire`, `SpendTokenCommand` Ship Phase behavior, and attack-time
  ECM behavior remain unchanged.

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
| Deferred ready cost | Medium | Static metadata includes Repair-token ready cost, and this package now records accepted decisions and evidence for the deferred Status Phase slice. | Keep attack-time behavior and Status Phase ready-cost tests separate. |
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
- Status Phase ready-cost tests listed in the deferred ready-cost section before
  implementing the printed Repair-token ready cost.
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
- Status Phase manual test, after the ready-cost slice is implemented, proving
  an exhausted ECM can be readied by spending a Repair token and both peers
  agree on command-token and runtime upgrade card state.

Manual tests supplement automated tests. They do not replace required automated
coverage unless the Project Owner explicitly accepts a temporary exception.

## Open Questions

- What test threshold is sufficient while TEST-003 does not exist?
- No remaining Project Owner decisions are required before implementing the
  deferred Status Phase ready-cost slice.

These questions do not reopen ADR-003, ADR-004, CON-003, or CON-004.

## Project Owner Decisions Required

Before status advancement, the Project Owner must decide or explicitly
delegate:

1. Minimum sufficient tests before status advancement.

   Rationale: TEST-003 remains unavailable, so the Project Owner determines test
   sufficiency for any status beyond Draft/Identified.

No remaining Project Owner decisions are required before implementing the
deferred Status Phase ready-cost slice.

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
   ready-cost to a later implementation slice.
9. Status Phase evidence shows existing cleanup, start-round, command-token,
   runtime-upgrade serialization, replay, network, and projection surfaces can
   support a narrow ready-cost implementation.
10. Existing replay, network, reconnect, and projection surfaces can be reused,
   but deferred Status Phase ready-cost behavior is not implemented.
11. The Project Owner has accepted the ECM Status Phase ready-cost timing,
   command protocol, state ownership, public visibility, optional-rule ordering,
   recalculation, and advancement-blocking decisions recorded in this package.

## Evidence Gaps

- No ECM-specific command, command validation, or command-owned execution path.
- No ECM-specific projection affordance or `FlowSpec` allowed-command entry.
- No ECM-specific runtime upgrade `card_state` mutation.
- No ECM-specific pending authorization lifecycle implementation.
- No ECM-specific serialization/save-load test.
- No ECM-specific replay test.
- No ECM-specific network/reconnect test.
- No ECM-specific visibility test.
- No Status Phase ready-cost implementation or tests.
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
  Status Phase ready-cost timing/protocol, and no new framework are recorded.
- Deferred Status Phase ready-cost evidence and accepted owner answers are
  recorded.
- No active Status Phase ECM Repair-token ready-cost behavior exists in the
  evidence collected for that slice.

Outstanding work:

- Implementation.
- Tests across validation, execution, projection, serialization, replay,
  network, reconnect, and visibility.
- Implementation and tests for the deferred Status Phase ready-cost slice.
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
| Codex | 2026-07-08 | Ready-cost evidence added | Recorded Status Phase ready-cost evidence, protocol options, owner questions, and tests. Status remains Draft. |
| Codex | 2026-07-08 | Ready-cost owner Q&A resolved | Recorded accepted timing, command protocol, state ownership, replay/network, and test obligations for the deferred Status Phase ready-cost slice. Status remains Draft. |

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

Implement the deferred Status Phase ready-cost slice as narrow ECM behavior
using the existing Status Phase, command-token, runtime upgrade, serialization,
replay, network, and projection surfaces. Do not introduce a generic
optional-rule framework or generic upgrade-ready framework.

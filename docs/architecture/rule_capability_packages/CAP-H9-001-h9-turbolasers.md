# CAP-H9-001: H9 Turbolasers Attack Dice Modification

## Identity

Package ID: CAP-H9-001

Rule: H9 Turbolasers

Source component: `h9_turbolasers`

Component type: upgrade card

Upgrade type: `TURBOLASERS`

Status: Draft

Implementation status: NOT_INTEGRATED

Created: 2026-07-07

This Rule Capability Package records the expected implementation obligations for
H9 Turbolasers. It does not mark the rule integrated and does not change upgrade
metadata.

## Purpose

H9 Turbolasers is the next candidate attack-modifier upgrade after Grand Moff
Tarkin and Electronic Countermeasures.

This package captures the evidence and accepted Project Owner decisions needed
before implementation so future Engineer work can follow ADR-003, ADR-004,
CON-003, CON-004, and the Runtime Upgrade Pattern without introducing a generic
upgrade framework.

## Scope

In scope:

- Optional H9 Turbolasers use during Attack Step 3: Resolve Attack Effects.
- Changing one eligible die face showing a Hit or Critical icon to a face with
  an Accuracy icon.
- Ship attacks and anti-squadron attacks performed by the equipped ship.
- Runtime upgrade ownership on the attacking ship carrying H9 Turbolasers.
- Command-owned player choice for use or decline.
- Public projection of the available H9 choice.
- The downstream gameplay consequence through Accuracy spending and transition
  into the defense-token window.
- Serialization, replay, reconnect, network mirroring, and tests for the H9
  rule behavior.

Out of scope:

- A generic attack-modifier framework.
- A generic timing-window queue.
- Other turbolaser upgrades.
- Status Phase ready-cost behavior.
- Upgrade JSON status changes.
- Production code or test implementation.
- Metadata status advancement.

## Rule Description

Canonical catalog evidence:

- `Resources/Game_Components/upgrades/turbolasers/h9_turbolasers.json`
  identifies the card as `h9_turbolasers`.
- The catalog upgrade type is `TURBOLASERS`.
- The catalog marks the card as a Modification.
- The catalog marks the card as not exhaustible.
- The catalog rule text states: while attacking, the attacker may change one die
  face with a Hit or Critical icon to a face with an Accuracy icon.
- The catalog timing notes place the effect during Attack Step 3: Resolve Attack
  Effects.
- The catalog integration status remains `NOT_INTEGRATED`.

Rules-reference evidence from the completed H9 research:

- Attack Step 3 includes resolving attack effects, modifying dice, and spending
  Accuracy icons.
- A die "change" effect rotates the die to the indicated face.
- Upgrade card effects are optional unless the text states otherwise.
- Red and blue attack dice have Accuracy faces in the current dice data.
- Black attack dice do not currently have Accuracy faces in the current dice
  data.

Accepted gameplay decisions:

- H9 applies to every attack performed by the equipped ship, including
  anti-squadron attacks.
- Eligible source faces are any die faces containing at least one Hit or
  Critical icon.
- The target Accuracy face must exist on the same die color.
- Black dice cannot be modified by H9 because they have no Accuracy face.
- The attacker chooses exactly one eligible die.
- Each H9 runtime upgrade instance is an independent rule source.

## Related Architecture Documents

- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md`
- `.github/skills/rule-integration/SKILL.md`

## Accepted Implementation Decisions

Gameplay:

- H9 applies to every attack performed by the equipped ship, including
  anti-squadron attacks.
- Eligible source faces are any die faces containing at least one Hit or
  Critical icon.
- The target Accuracy face must exist on the same die color.
- Black dice cannot be modified because they have no Accuracy face.
- The attacker chooses exactly one eligible die.
- Each runtime upgrade instance is an independent source.

Command model:

- H9 is command-owned.
- H9 uses `UseH9Command` and `DeclineH9Command`.
- Both commands are replayable.
- `UseH9Command` immediately changes authoritative dice.
- `DeclineH9Command` changes no dice.

Runtime ownership:

- Current-attack guard state lives in the H9 runtime upgrade instance
  `rule_state`.
- Projection remains derived.
- UI owns no gameplay state.

Attack modifier interaction:

- Multiple optional rules may coexist within `ATTACK_MODIFY`.
- The controlling player chooses the order.
- Resolve one optional rule at a time.
- Recalculate available optional rules after every modifier resolution.
- Passive effects are automatically applied and are not presented as choices.
- `confirm_attack_dice` remains the only exit from `ATTACK_MODIFY`.

UI principle:

- The modifier UI is timing-window oriented, not H9-specific.
- It presents all currently available optional rules.
- Available rule text shall be accessible through the existing tooltip
  mechanism.

Implementation details:

- Candidate legality is recalculated after every dice modification.
- H9 only changes dice; existing Accuracy spending remains unchanged.
- Reconnect during the modifier window is supported.
- After `UseH9Command` or `DeclineH9Command`, prompt/candidate projection state
  may be cleared or recalculated, but the authoritative consumed/declined guard
  remains in runtime upgrade `rule_state` until the attack modifier window
  exits.
- The authoritative H9 `rule_state` guard is removed only on
  `confirm_attack_dice`, attack end, cancellation, flow replacement, or another
  explicit exit from `ATTACK_MODIFY`.
- ECM-level protocol, replay, reconnect, network, and command-sequence testing
  is required.

## Runtime Ownership

The H9 Turbolasers source is the runtime upgrade instance on the attacking
`ShipInstance` that carries H9 Turbolasers.

The runtime upgrade instance SHALL reference static card data by `data_key`.
Full static card data SHALL NOT be copied into runtime state.

H9 Turbolasers does not require an exception to ADR-004 ownership. Commander,
fleet-wide, range/aura, and cross-ship exception handling is not involved.

The rule exists only while the source runtime upgrade instance is active in play
and eligible for the current attack.

## Runtime State

CON-004 runtime upgrade fields apply to the H9 Turbolasers runtime upgrade
instance.

Expected H9-specific durable runtime state:

- H9 is not exhaustible in the current catalog evidence.
- H9 does not require `card_state.exhausted` changes.
- H9 current-attack guard state lives in runtime upgrade `rule_state`.

Temporary attack-local state is required while the Attack Step 3 modifier window
is active:

- whether H9 is available for the current attack,
- eligible die indices,
- legal target Accuracy faces,
- whether the attacker has used or declined H9 for the current attack,
- the selected die and resulting face if H9 is used.

Temporary attack-local projection data may be represented in
`InteractionFlow.payload` while the attack modifier window is active, but it is
derived. The authoritative current-attack H9 use/decline guard remains the H9
runtime upgrade instance `rule_state`.

After `UseH9Command` or `DeclineH9Command`, prompt and candidate projection data
may be cleared or recalculated. The authoritative current-attack H9
consumed/declined guard remains in runtime upgrade `rule_state` until
`confirm_attack_dice`, attack end, cancellation, flow replacement, or another
explicit exit from `ATTACK_MODIFY`.

## Surface Traceability

| Surface | H9 obligation |
| --- | --- |
| Static upgrade data | Identify `h9_turbolasers`, `TURBOLASERS`, Modification, non-exhaustible, and rule text. |
| Fleet assignment | H9 remains a ship upgrade assigned through the `TURBOLASERS` slot. |
| Runtime materialization | Setup materializes the equipped H9 card into `ShipInstance.runtime_upgrades`. |
| Runtime lookup | Commands reference the source runtime upgrade instance by `runtime_upgrade_id`. |
| Rule surface | Existing attack modifier affordance surfaces advertise available optional rules during `ATTACK_MODIFY`. |
| Command validation | `UseH9Command` and `DeclineH9Command` validate against current attack state, source runtime upgrade, die state, player authority, and runtime `rule_state` guard. |
| Command execution | `UseH9Command` changes exactly one eligible die to a same-color Accuracy face; `DeclineH9Command` records no dice change. |
| Projection | UI shows H9 affordance from derived attack payload, not from UI-owned rule state. |
| Serialization | Runtime upgrade source and any active attack-local payload needed for reconnect are serialized. |
| Replay | H9 use or decline is replayed as command history. |
| Network | Authoritative command results are mirrored in sequence. |
| Visibility | H9 availability, use, decline, changed die, and generated Accuracy are public. |
| Tests | Tests must cover command protocol, validation, replay, reconnect, and network mirroring. |

## Validation Surfaces

H9 availability validation SHALL require:

- the current interaction is in the attack modifier window,
- the acting player is the attacker,
- the attacking ship owns an active H9 runtime upgrade instance,
- the command references that runtime upgrade instance by `runtime_upgrade_id`,
- the H9 runtime upgrade is not discarded or disabled,
- at least one attack die shows a face with a Hit or Critical icon,
- the selected die is still present and still eligible when the command resolves,
- the selected source face contains at least one Hit or Critical icon,
- the selected target face has an Accuracy icon on the same die color,
- the selected die color has an Accuracy face,
- H9 has not already been used or declined for the same attack according to the
  source runtime upgrade `rule_state` guard.

H9 validation SHALL NOT trust UI projection alone.

H9 validation SHALL reject stale, forged, wrong-player, wrong-phase,
wrong-source, wrong-attack, repeated-use, and illegal-die commands.

H9 validation SHALL recalculate candidate legality after every dice
modification and after every optional modifier resolution.

## Execution Surfaces

H9 execution is command-owned.

`UseH9Command` SHALL:

- record the source `runtime_upgrade_id`,
- identify the current attack,
- identify the selected die,
- identify the selected Accuracy face,
- validate against authoritative attack state at execution time,
- change exactly one eligible die face to the selected Accuracy face,
- update authoritative attack dice state used by later attack steps,
- write the current-attack use guard to the source runtime upgrade
  `rule_state`,
- record the use in command history.

`DeclineH9Command` SHALL:

- record the source `runtime_upgrade_id`,
- identify the current attack,
- validate that H9 is currently available,
- write the current-attack decline guard to the source runtime upgrade
  `rule_state`,
- record an explicit decline in command history,
- leave attack dice unchanged.

H9 execution SHALL NOT:

- exhaust H9 unless a later accepted rule source changes the card behavior,
- mutate static upgrade data,
- create a generic upgrade framework,
- make UI projection authoritative.

## Expected Complete Gameplay Protocol

The protocol must continue through the gameplay consequence of the changed die,
including Accuracy spending and transition into the defense-token window.

Expected common sequence:

1. `publish_attack_flow` enters `ATTACK_MODIFY` with current `dice_results`.
2. Attack modifier affordance evaluation exposes H9 if the source runtime
   upgrade and dice state are legal.
3. If multiple optional rules are available, the controlling player chooses one
   optional rule to resolve.
4. The attacker either uses H9 with `UseH9Command` or declines H9 with
   `DeclineH9Command`.
5. If H9 is used, the command changes one eligible die face to an Accuracy face
   in authoritative attack dice state.
6. If H9 is declined, authoritative attack dice state is unchanged.
7. Prompt/candidate projection state may be cleared or recalculated.
8. The H9 runtime upgrade `rule_state` retains the consumed/declined guard until
   the attack modifier window exits.
9. Available optional rules are recalculated from authoritative state.
10. The attacker may resolve another available optional rule or confirm attack
   dice through the existing attack flow.
11. `confirm_attack_dice` is the only exit from `ATTACK_MODIFY` during normal
   modifier resolution.
12. The attack pipeline reads the updated dice and calculates available Accuracy
   icons from authoritative attack dice state.
13. If the generated Accuracy is spent, existing Accuracy/defense-token lock
   handling records the selected defense token lock.
14. The attack proceeds into the defense-token window with any Accuracy locks
    applied.

### Hot-Seat Command Sequence

1. `publish_attack_flow(ATTACK_MODIFY)` is generated by the attack flow.
2. H9 availability is projected for the attacking player.
3. The attacking player submits `UseH9Command` or `DeclineH9Command`.
4. Command validation and execution run locally through the normal command
   processor.
5. Command history records use or decline.
6. Available optional rules are recalculated and projected locally.
7. The attacker may resolve another optional modifier or submit the existing
   attack-dice confirmation command.
8. `confirm_attack_dice` is the only exit from `ATTACK_MODIFY`.
9. The existing Accuracy spending and defense-token transition commands resolve
   from the updated authoritative dice state.

### Network Host Command Sequence

1. The host applies `publish_attack_flow(ATTACK_MODIFY)` in authoritative
   sequence.
2. H9 availability is projected from authoritative state.
3. The host validates and executes the H9 use or decline command when received
   from the attacking player.
4. The host broadcasts the authoritative command result by sequence.
5. Available optional rules are recalculated from authoritative state.
6. The host may resolve another optional modifier or apply the existing
   attack-dice confirmation command.
7. `confirm_attack_dice` is the only normal exit from `ATTACK_MODIFY`.
8. Clients mirror each command result in sequence.
9. The host applies subsequent Accuracy spending and defense-token transition
   commands in sequence.
10. Clients mirror each authoritative command result in sequence.

### Network Client Command Sequence

1. The client receives and mirrors `publish_attack_flow(ATTACK_MODIFY)`.
2. H9 availability is projected from mirrored authoritative state.
3. If the client controls the attacker, the client submits the H9 use or decline
   command to the host.
4. The client does not mutate authoritative dice state before receiving the
   host command result.
5. The client mirrors the host-approved H9 command result in sequence.
6. Available optional rules are recalculated from mirrored authoritative state.
7. The client may submit or mirror another optional modifier before
   `confirm_attack_dice`.
8. The client mirrors the attack-dice confirmation command as the only normal
   exit from `ATTACK_MODIFY`.
9. The client mirrors the Accuracy spending and defense-token transition
   commands in sequence.

## Authoritative State Lifecycle

| Step | Authoritative owner | H9 lifecycle obligation |
| --- | --- | --- |
| Setup materialization | `ShipInstance.runtime_upgrades` | H9 exists as a runtime upgrade instance on the owning ship. |
| Attack modifier publication | Attack state plus derived `InteractionFlow.payload` | H9 candidates may be exposed as temporary attack-local projection data. |
| H9 use | `UseH9Command`, attack dice state, and runtime upgrade `rule_state` | Selected die changes to Accuracy; H9 is marked used for the current attack; prompt/candidate projection may be cleared or recalculated. |
| H9 decline | `DeclineH9Command` and runtime upgrade `rule_state` | H9 is marked declined for the current attack; dice are unchanged; prompt/candidate projection may be cleared or recalculated. |
| Attack dice confirmation | Existing attack command history plus runtime upgrade `rule_state` cleanup | Updated dice are carried into subsequent attack steps; H9 current-attack guard is cleared because this exits `ATTACK_MODIFY`. |
| Accuracy spending | Existing attack/defense-token lock state | Generated Accuracy may lock a defense token through existing Accuracy handling. |
| Defense-token window | Existing attack flow and ship defense-token state | Defender sees defense-token options with any Accuracy locks applied. |
| Attack end, cancellation, or flow replacement | Existing attack cleanup plus runtime upgrade `rule_state` cleanup | H9 current-attack guard is cleared when the modifier window is left without normal confirmation. |

Projection SHALL remain a derived view of the authoritative state above.

## Projection Surfaces

Projection SHALL show H9 only when authoritative validation would allow a legal
effect.

Projection MAY include:

- source runtime upgrade identity,
- eligible die indices,
- legal target Accuracy faces,
- whether H9 has already been used or declined in the current attack.

Projection SHALL NOT be the source of truth for:

- H9 ownership,
- current attack identity,
- die legality,
- H9 use or decline,
- Accuracy locks.

Both players may observe H9 availability and resolution because the attack dice
and card use are public information.

## Attack Modifier Interaction

H9 shares Attack Step 3 timing with existing and future attack modifiers.

Existing repository evidence includes attack modifier support for Swarm and an
`ATTACK_MODIFY` flow.

Multiple optional rules may coexist within `ATTACK_MODIFY`. The controlling
player chooses the order, one optional rule resolves at a time, and available
optional rules are recalculated after every modifier resolution. Passive effects
are automatically applied and are not presented as choices.

`confirm_attack_dice` remains the only exit from `ATTACK_MODIFY`.

The modifier UI SHALL remain timing-window oriented rather than H9-specific. It
SHALL present all currently available optional rules, with available rule text
accessible through the existing tooltip mechanism.

## Serialization Impact

Serialization SHALL preserve:

- the H9 runtime upgrade instance on the attacking ship,
- `runtime_upgrade_id`,
- `data_key`,
- canonical CON-004 runtime fields,
- H9 current-attack guard state in runtime upgrade `rule_state` while present as
  the authoritative consumed/declined guard,
- current attack dice state after H9 use,
- any active `InteractionFlow` payload needed to reconnect during the H9 prompt
  only as derived projection/reconnect payload,
- any Accuracy locks produced after generated Accuracy is spent.

Serialization SHALL NOT copy full static H9 card data into runtime state.

Command validation SHALL recalculate H9 legality from authoritative attack
state and runtime upgrade `rule_state`. It SHALL NOT trust serialized
projection payload alone.

## Replay Impact

Replay SHALL reconstruct:

- H9 availability from runtime upgrade ownership and attack dice state,
- explicit H9 use or decline from command history,
- H9 current-attack guard state from command execution and serialized runtime
  upgrade `rule_state` when reconnect or save/load occurs during the modifier
  window,
- the changed die face when H9 is used,
- later Accuracy spending from existing attack command history,
- transition into the defense-token window from the updated dice state.

Replay SHALL NOT depend on UI-only state to reconstruct H9 effects.

## Network Impact

Network play SHALL treat the host-authoritative `UseH9Command` or
`DeclineH9Command` as the source of truth.

Clients SHALL mirror H9 command results in authoritative command sequence.

Clients SHALL NOT apply local speculative dice mutation as authoritative state.

Out-of-order network command results SHALL NOT allow H9 use, decline, Accuracy
spending, or defense-token transition to apply in a different order from the
host-authoritative sequence.

## Reconnect Impact

Reconnect SHALL reconstruct consistent state when reconnect occurs:

- before the H9 choice is made,
- after H9 use but before attack dice confirmation,
- after H9 decline but before attack dice confirmation,
- after generated Accuracy is spent,
- after transition into the defense-token window.

Reconnect reconstruction SHALL use serialized runtime upgrade state, serialized
attack flow state, and command history. It SHALL NOT require UI-local memory.

Reconnect projection may use serialized `InteractionFlow` payload as derived
display state, but H9 legality and consumed/declined status remain authoritative
only in attack state, command history, and runtime upgrade `rule_state`.

## Visibility Impact

H9 use is public.

The selected die is public.

The resulting Accuracy face is public.

Any Accuracy spending and defense-token locks are public.

No hidden-information handling is required for H9.

## Evidence Map

| Evidence | Finding |
| --- | --- |
| H9 upgrade JSON | Defines `h9_turbolasers`, `TURBOLASERS`, Modification, non-exhaustible, rule text, timing notes, and `NOT_INTEGRATED`. |
| H9 rules text resource | Repeats card text and Attack Step 3 timing. |
| Dice data | Red and blue dice have Accuracy faces; black dice do not. |
| ADR-003 | Rule behavior must identify correct validation, execution, projection, replay, network, and visibility surfaces. |
| ADR-004 | Active upgrades are runtime upgrade instances on `ShipInstance` by default. |
| CON-003 | This package must remain traceability evidence until owner-approved integration. |
| CON-004 | Commands involving runtime upgrades must reference runtime upgrade identity and preserve serialization/replay/reconnect obligations. |
| Existing attack modifier code | Swarm and attack modifier flow provide relevant local patterns, but do not define H9 behavior. |
| Tarkin and ECM packages | Provide package quality and runtime upgrade pattern precedent. |

## Required Automated Tests

Required validation tests:

- `FlowSpec.allowed_commands` allows `UseH9Command` and `DeclineH9Command`
  only in the accepted attack modifier window.
- `CommandApplicability` allows `UseH9Command` and `DeclineH9Command` only in
  the accepted attack modifier window.
- H9 is unavailable without an H9 runtime upgrade on the attacking ship.
- H9 is unavailable outside the attack modifier window.
- H9 is unavailable for the wrong player.
- H9 is unavailable when the runtime upgrade is discarded or disabled.
- H9 is unavailable when no die has a Hit or Critical icon.
- H9 rejects illegal source die indices.
- H9 rejects target faces without an Accuracy icon.
- H9 rejects target Accuracy faces that do not exist on the selected die color.
- H9 rejects black dice because black dice have no Accuracy face.
- H9 rejects stale commands after dice have changed.
- H9 rejects repeated use or decline for the same attack using the runtime
  upgrade `rule_state` guard.
- H9 rejects repeated use after H9 was used in the same attack.
- H9 rejects repeated decline after H9 was declined in the same attack.
- H9 rejects use after decline and decline after use in the same attack.

Required execution tests:

- H9 use changes exactly one eligible die to an Accuracy face.
- H9 can modify each eligible same-color red or blue Hit/Critical source face.
- H9 decline records an explicit command-history entry and changes no dice.
- H9 does not exhaust or mutate durable card state.
- H9-generated Accuracy can be spent by existing Accuracy handling.
- H9-generated Accuracy affects the defense-token window.
- H9 applies to anti-squadron attacks performed by the equipped ship.
- Multiple H9 runtime upgrade instances act as independent sources.
- Existing defense-token behavior remains unchanged when H9 is unavailable or
  declined.
- H9 current-attack guard cleanup occurs on `confirm_attack_dice`.
- H9 current-attack guard cleanup occurs on attack end.
- H9 current-attack guard cleanup occurs on cancellation.
- H9 current-attack guard cleanup occurs on flow replacement.

Required protocol tests:

- Hot-seat command sequence from attack modifier window through defense-token
  window.
- Network host sequence mirrors use, confirm, Accuracy spending, and
  defense-token transition in authoritative order.
- Network client sequence waits for authoritative H9 command result before
  treating dice mutation as authoritative.
- Command history replays H9 use and decline deterministically.
- Reconnect reconstructs state before choice, after use, after decline, after
  Accuracy spending, and in the defense-token window.
- Save/load during the H9 modifier window preserves the authoritative runtime
  upgrade `rule_state` guard and reconstructs derived projection.
- Projection derivation proves UI and `InteractionFlow` payload do not own H9
  legality.
- Public visibility covers H9 availability, use, decline, and changed die.
- Remote command-effect and mirror handling classify `UseH9Command` and
  `DeclineH9Command`.
- ECM-level protocol, replay, reconnect, network, and command-sequence
  comparison coverage exists for hot-seat, host, and client paths.

Required regression tests:

- Existing Swarm behavior still works.
- Existing attack modifier confirmation still works.
- Existing Accuracy spending still works without H9.
- H9 does not create a generic upgrade or timing-window surface.
- Multiple optional `ATTACK_MODIFY` rules can coexist; the controlling player
  chooses one at a time, and availability is recalculated after each modifier
  resolution.
- Network play preserves the case where another optional modifier remains after
  H9 use or decline and availability is recalculated before
  `confirm_attack_dice`.

## Required Manual Verification

Manual verification should include:

- Hot-seat attack where H9 changes a Hit or Critical die to Accuracy, spends the
  generated Accuracy, and proceeds into the defense-token window.
- Hot-seat attack where H9 is declined.
- Network host-controlled attacker using H9 and spending generated Accuracy.
- Network client-controlled attacker using H9 and spending generated Accuracy.
- Anti-squadron attack where H9 is available to the equipped attacking ship.
- Attack modifier window with more than one optional rule where the controlling
  player chooses order and availability is recalculated after each resolution.
- Reconnect during the H9 prompt.
- Reconnect after H9 use but before attack dice confirmation.
- Reconnect after generated Accuracy is spent.

## Risks

- Attack Step 3 already contains multiple modifier-like effects, and H9 must not
  accidentally impose a broad timing-window framework.
- If H9 availability is derived only from projection, replay and reconnect can
  diverge from authoritative state.
- If H9 use is not recorded as a command, replay cannot prove the optional
  choice.
- If attack-local H9 state is not cleared, stale use or decline data can leak
  into later attacks.
- If same-window modifier availability is not recalculated after each
  resolution, later optional rule choices can be projected from stale dice.
- If command validation does not enforce same-color Accuracy faces, future dice
  data changes can make H9 modify illegal targets.

## Open Questions

None currently recorded.

## Project Owner Decisions Required

None currently recorded.

## Evidence Gaps

- No H9 production implementation exists yet.
- No H9-specific automated tests exist yet.
- No implementation evidence exists yet for `UseH9Command` or
  `DeclineH9Command`.
- No implementation evidence exists yet for timing-window-oriented modifier UI.
- No implementation evidence exists yet for H9 replay, reconnect, or network
  command-sequence behavior.

## Integration Status

Status: Draft

Implementation status: NOT_INTEGRATED

H9 Turbolasers SHALL NOT be marked Integrated until:

- implementation conforms to ADR-003, ADR-004, CON-003, and CON-004,
- required validation, execution, projection, serialization, replay, reconnect,
  network, and visibility behavior is implemented,
- required tests pass,
- Project Owner explicitly accepts integration status advancement.

## Review History

- 2026-07-07: Draft package prepared from H9 research evidence for Project
  Owner review. No production code, tests, metadata, ADRs, Contracts, startup
  documents, roadmap, or governance documents were changed.
- 2026-07-07: Accepted Project Owner Q&A decisions recorded. Status remains
  Draft and implementation status remains `NOT_INTEGRATED`.
- 2026-07-07: Guard lifecycle, protocol, serialization, and test-obligation
  wording corrected before implementation.

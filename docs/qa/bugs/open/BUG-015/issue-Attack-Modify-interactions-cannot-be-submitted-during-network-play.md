# BUG-015 — Attack Modify interactions cannot be submitted during network play

Severity: High

Area: Attack Modify / Network Interaction Flow

Layer: Presentation | Command Routing | Networking

## Summary

During network play, a ship attack successfully reaches the shared Attack Modify timing window, but the controlling player cannot resolve any of its opportunities.

After rolling attack dice:

- the Roll Dice button remains visible instead of transitioning cleanly to Attack Modify;
- Concentrate Fire and H9 choices are presented;
- selecting Use for H9 or Concentrate Fire visibly enters die-selection mode;
- clicking an eligible die does nothing;
- selecting Decline also does nothing;
- no semantic Attack Modify command reaches authoritative command history;
- the attack cannot progress.

The same H9, Concentrate Fire, and interaction flow works correctly in hot-seat play.

## Environment

- Mode: Network
- Scenario: Debug Scenario
- Attacker: Victory II-class Star Destroyer
- H9 Turbolasers equipped
- Concentrate Fire available
- Current TWI-002 production activation with BUG-012, BUG-013 and BUG-014 repairs present

## Expected

After a successful network ship attack roll:

- Roll Dice presentation is replaced by the active Attack Modify interaction;
- the controlling player can select Use or Decline for each projected opportunity;
- choosing Use enters local parameter selection without authoritative mutation;
- clicking an eligible die submits exactly one complete semantic command to the authoritative host;
- choosing Decline submits the explicit Decline command immediately;
- accepted command results are mirrored and projected to both peers;
- remaining opportunities are re-derived;
- after all blockers are resolved, the attack can continue normally.

The network interaction should behave functionally the same as the verified hot-seat flow, subject only to host-authoritative command routing.

## Actual

The attack reaches Attack Modify and the available H9 and Concentrate Fire choices are displayed.

However:

- the Roll Dice button remains visible;
- selecting Use visually activates die-selection mode;
- eligible dice receive the expected visual selection treatment;
- clicking a die produces no visible or authoritative result;
- selecting Decline produces no result;
- no H9 or Concentrate Fire semantic command is recorded;
- the attack remains blocked in Attack Modify.

## Reproduction

1. Start a normal network game using the Debug Scenario.
2. Activate the Victory II-class Star Destroyer.
3. Begin a ship attack.
4. Use the Concentrate Fire dial if desired.
5. Roll attack dice.
6. Observe that the Roll Dice button remains visible.
7. Select Use for either H9 Turbolasers or Concentrate Fire Token.
8. Observe that the dice enter visible selection mode.
9. Click an eligible die.
10. Observe that nothing happens.
11. Alternatively select Decline.
12. Observe that nothing happens and the attack remains blocked.

Hot-seat execution of the corresponding scenario works correctly.

## Evidence

Attached:

- `annotation_20260806_225911_001.json`
- `replay_20260806_225919.json`

### Annotation evidence

At the captured failure state:

- `CurrentAttackState.active = true`
- `CurrentAttackState.stage = attack_modify`
- `cf_token_resolution = pending`
- canonical attack dice are present
- H9 runtime `rule_state` remains unresolved
- `TimingWindowState.active = true`
- `timing_window_id = attack_modify`
- lifecycle is open
- controller player is the attacker

The authoritative state therefore remains valid and is waiting for an unresolved Attack Modify player choice.

### Replay evidence

The replay reaches:

- sequence 43 — `begin_attack`
- sequence 45 — `use_concentrate_fire_dial`
- sequence 47 — `roll_dice`

After the roll, sequences 48–50 contain only `publish_attack_flow`.

The replay contains no accepted:

- `use_h9`
- `decline_h9`
- `use_concentrate_fire_token_reroll`
- `decline_concentrate_fire_token_reroll`
- `confirm_attack_dice`

The failure therefore occurs before successful semantic Attack Modify command execution and recording.

## Regression

Yes.

The corresponding H9 and Concentrate Fire interaction has been manually verified as functional in hot-seat play.

The defect is observed specifically in network play after the recent TWI-002 production activation and presentation-interaction repairs.

## Initial Classification

Network live-interaction / command-routing regression.

Current evidence suggests:

- authoritative timing-window state is correct;
- opportunity projection reaches presentation;
- local parameter-selection presentation can be entered;
- semantic Use and Decline commands do not successfully reach authoritative execution.

The exact failing network boundary has not yet been established.

The stale Roll Dice control may be another symptom of the same network presentation lifecycle failure, but this relationship is not yet proven.

## Scope

Root cause unknown.

Perform a forensic investigation of the complete network interaction path:

`authoritative Attack Modify state`
→ network projection
→ controlling-client AttackSimPanel
→ Use / Decline interaction
→ local parameter collection
→ die click
→ complete semantic intent
→ CommandRouterAdapter
→ GameManager submitter
→ NetworkManager client-to-host submission
→ host CommandProcessor
→ ordered network mirror
→ authoritative reprojection

The investigation must determine:

- why local Use selection becomes visible but die commitment submits nothing;
- why Decline submits nothing;
- whether commands are never emitted, rejected locally, lost before transport, rejected by the host, or fail to refresh after acceptance;
- why Roll Dice presentation remains visible after authoritative roll completion;
- whether the stale Roll Dice control and broken Attack Modify submissions share one lifecycle/routing defect;
- whether hot-seat and network use materially different live interaction routes;
- the first failing boundary;
- the smallest architecture-compliant repair surface.

Do not change command ownership, timing-window ownership, CurrentAttackState ownership, replay semantics, or networking authority unless the forensic investigation demonstrates an architecture conflict.

## Verification

After repair, verify:

- H9 Use works through the controlling network client.
- H9 Decline works through the controlling network client.
- Concentrate Fire Use works through the controlling network client.
- Concentrate Fire Decline works through the controlling network client.
- Parameter selection remains local until final die commitment.
- Die commitment submits exactly one semantic command.
- Host accepts and mirrors the command in authoritative order.
- Both peers display the same resulting canonical dice.
- Roll Dice presentation expires when Attack Modify becomes active.
- Remaining opportunities are correctly re-derived.
- Attack confirmation becomes available only after all blockers resolve.
- Hot-seat behavior remains unchanged.
- Replay, save/load, reconnect, and network determinism remain passing.

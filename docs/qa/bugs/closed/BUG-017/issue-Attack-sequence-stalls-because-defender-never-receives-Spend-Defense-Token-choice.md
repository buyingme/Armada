# BUG-017 — Network defense-token step not presented to defending client

## Status

In progress — root cause confirmed and repaired; retained here for Project
Owner review and any desired manual network verification.

## Summary

During a ship-to-ship attack in network play, the game reaches the Spend Defense Tokens step but the defending client is not presented with the defense-token modal/options.

The attack cannot continue normally because the game is waiting for the defender's decision while the required interaction is not available on the defender's client.

The issue has now been reproduced again during network baseline testing.

## Latest Reproduction

Round 2, Ship Phase.

- Attacker: Nebulon-B Escort Frigate, Player 0
- Defender: Victory II-class Star Destroyer, Player 1
- Range: Long
- Attack ID: `attack:151`

The attack proceeds normally through dice rolling and accuracy resolution.

After accuracy resolution, the attack enters the defense stage. The defending Imperial client should receive the Spend Defense Tokens interaction, but no usable defense-token modal/options are shown.

Gameplay is blocked at this point.

## Evidence / Key Observation

The captured authoritative attack state identifies Player 1 as the defender and shows that defense resolution is pending:

- `current_attack_state.defender_player = 1`
- `current_attack_state.stage = "defense"`
- `current_attack_state.defense_stage = "pending"`

However, the interaction flow still identifies Player 0 as controller and visibility owner:

- `interaction_flow.controller_player = 0`
- `interaction_flow.visible_to = 0`

The interaction payload itself correctly identifies:

- `defender_player = 1`
- `defender_name = "Victory II-class Star Destroyer"`

This creates an apparent contradiction:

**The canonical attack is waiting for Player 1's defense decision, while the projected interaction remains assigned/visible to Player 0.**

The replay provides matching evidence. After Player 0 commits accuracy resolution for `attack:151`, the subsequent `publish_attack_flow` commands continue to publish the defense-step flow with `controller_player = 0`.

No defense command from Player 1 follows before the captured replay ends.

## Expected Result

When an attack enters the Spend Defense Tokens step:

1. The defending player becomes the decision owner.
2. In network play, the defense-token interaction is presented to the defending player's client.
3. The defending player can select and resolve legal defense tokens.
4. The attack then continues normally.

## Actual Result

The authoritative attack state waits for Player 1's defense decision, but the interaction flow remains assigned to Player 0.

The defending client therefore does not receive/present the required defense-token interaction and the attack stalls.

## Reproduction Status

Confirmed multiple times.

The latest reproduction appears to be the same failure mode as the previous BUG-017 occurrence rather than a separate defect.

The latest evidence substantially narrows the likely failure area to the transition/projection of decision ownership from attacker to defender when entering the defense-token step.

## Scope / Notes

Observed in network play.

Do not assume that the defect is purely UI-side. The captured state already contains an incorrect or stale interaction-flow controller/visibility assignment before presentation on the defending client.

Investigation should therefore begin at the authoritative attack-flow/controller transition and its projection/network publication rather than at the defense-token modal itself.

## Root Cause And Repair — 2026-08-12

### Evidence clarification

`interaction_flow.visible_to = 0` is
`Constants.Visibility.ALL`; it does not identify Player 0 as a visibility
owner. The material mismatch is `step_id = 17` (`ATTACK_ROLL`) and
`controller_player = 0` after canonical state has already reached
`stage = "defense"`, `defense_stage = "pending"`, and
`defender_player = 1`.

### Confirmed root cause

The production command-result route handled an accepted `roll_dice` result
only when the scene pipeline identified the attack as Counter. A normal
attack therefore did not perform the derived `ROLL -> MODIFY` presentation
handoff at the accepted roll boundary.

For a ship attack with no blocking Attack Modify opportunities, the timing
orchestrator queues `confirm_attack_dice` as the roll's deterministic
continuation. That continuation and the automatic zero-accuracy
`commit_accuracy` can advance canonical `CurrentAttackState` through Accuracy
to Defense before the original roll submission returns. The caller's existing
post-submit stage guard then correctly refuses to apply a stale roll result,
but the earlier command-result route has already ignored the normal attack.

When defense starts, `AttackExecutor` correctly resolves Player 1 from the
canonical defender and requests `MODIFY -> DEFENSE_TOKENS`. The derived
`AttackFlowFSM` is still at `ROLL`, so its legal transition table rejects the
skipped `ROLL -> DEFENSE_TOKENS` transition and leaves the published flow at
`ATTACK_ROLL` under Player 0. Later payload patches add the correct defender
and defense-token data but do not change that stale step/controller.

### Exact latest-reproduction path

The format-5 replay records this sequence for `attack:151`:

1. `begin_attack` sequence 151 creates the canonical Player 0 attack against
   Player 1.
2. `publish_attack_flow` sequences 152–153 publish Declare and Roll; sequence
   153 is step 17/controller 0.
3. `roll_dice` sequence 154 canonically advances the attack to Attack Modify,
   but the normal-attack command reaction does not project `ROLL -> MODIFY`.
4. With no blocking opportunity, `confirm_attack_dice` sequence 155 advances
   canonical state to Accuracy. Sequence 156 republishes the still-stale
   step 17/controller 0 flow.
5. The zero-accuracy path submits `commit_accuracy` sequence 157, advancing
   canonical state to Defense pending for defender Player 1.
6. Defense entry attempts `ROLL -> DEFENSE_TOKENS`, which the derived FSM
   rejects. Sequences 158–160 consequently continue to publish step
   17/controller 0 even though their payload contains Player 1 and the correct
   defense-token data.
7. The Player 1 client mirrors those authoritative commands but never receives
   an `ATTACK_DEFENSE_TOKENS` projection, so it cannot construct the interactive
   defender panel or submit `commit_defense`.

The host/client logs match this path: canonical roll, confirm, and accuracy
commands succeed; defense reports three spendable tokens and two damage; no
Player 1 defense command follows. The later rejected host roll is a consequence
of the stale Roll presentation, not the cause.

### Repair

The accepted `roll_dice` command reaction now projects a roll result for any
matching active canonical attack, not only Counter attacks. It validates the
canonical attacker, canonical Attack Modify stage, and derived `ROLL` step,
then performs the existing one-way `_apply_dice_roll_result()` handoff. The
existing synchronous caller gained the same derived-step guard so a roll is
projected exactly once.

This is a presentation-lifecycle repair only:

- `CurrentAttackState` remains the canonical attack owner.
- Semantic commands and existing validators remain unchanged.
- Timing continuation ownership and order remain unchanged.
- `InteractionFlow`, `AttackFlowFSM`, scene state, controller state, and UI
  remain derived consumers and receive no reverse-write authority.
- No semantic command, canonical owner, compatibility bridge, general FSM,
  save field, replay field, or format version was added.
- TWI-003 declaration behavior and its accepted Begin/Skip boundary were not
  changed.

### Focused regression evidence

`test_zero_opportunity_network_roll_hands_defense_to_defender_client` exercises
the real `GameBoard` roll control with no Attack Modify opportunities, captures
the ordered authoritative command stream, mirrors that stream into a real
Player 1 client board, and proves:

- roll, confirm, and accuracy commands reach canonical Defense pending for
  defender Player 1;
- the host flow/FSM reaches `ATTACK_DEFENSE_TOKENS` under controller Player 1;
- the mirrored Player 1 `AttackPanelMirror` opens with defense input connected;
- the defender can construct exactly one `commit_defense` command as Player 1;
- the defender client does not adopt canonical attack ownership or synthesize
  commands while mirroring the authoritative stream.

Against the pre-repair implementation, this test failed at both host and
client boundaries: canonical state was Defense pending, while step/controller
remained 17/Player 0 and Player 1 had no defense controls. After the repair,
the containing production-resume suite passes 36/36 tests and 628 assertions.

Existing Hot-Seat/Network roll parity in the same suite remains passing.
Counter coverage passes 3/3 tests; shared current-attack protocol coverage
passes 25/25 tests; mid-attack reconnect coverage passes 7/7 tests.

### Verification

- Full repository suite: 237 scripts, 4,027/4,027 tests passing, 13,304
  assertions.
- Phase-K architecture lint: 0 violations, 4 existing allow-listed branches.
- `git diff --check`: passing.
- Save/replay formats: unchanged (save format 3, replay format 5).
- Baseline fixtures: not modified or renewed.

`./scripts/run_baseline_traces.sh --all` was run, but both baseline executions
stop before playback because the committed hot-seat and network replay fixtures
are format 4 while the accepted runtime requires format 5. This is a
pre-existing fixture/runtime compatibility condition and is outside this
repair. Per the explicit BUG-017 instruction, no fixture was renewed or
modified.

### Disposition

No new architecture decision is required. The established defect is the
missing accepted-roll projection boundary anticipated by the current
architecture, and the repair restores that boundary without changing
authoritative gameplay semantics. BUG-017 remains in progress and is not
closed or archived.

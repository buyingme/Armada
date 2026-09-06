# BUG-046 — Selecting Squadron Commits Activation Before Any Action Is Chosen

Severity: Medium
Area: Squadron Activation / Selection
Layer: Command Flow

## Expected

Selecting a squadron for inspection before choosing Move or Attack should remain
reversible.

The player should be able to inspect/select another eligible squadron until a
gameplay action commits the Squadron Activation.

This should behave consistently for:

- Squadron Phase activations;
- ship Squadron-command activations.

## Actual

After selecting an eligible squadron, the player cannot select a different
squadron even though neither Move nor Attack has been chosen.

The captured state shows the selected squadron already owns a canonical
activation identity while both actions remain unused:

- `activation_id = "squadron-activation:676"`
- `attack_action_disposition = "available"`
- `move_action_disposition = "available"`

Attempts to select another squadron can then be rejected because authority
already considers a Squadron Activation active.

## Reproduction

1. Reach either:
   - Squadron Phase, or
   - a ship Squadron Command with multiple eligible squadrons.
2. Select one eligible squadron.
3. Do not press Move or Attack.
4. Select another eligible squadron.

Result:
The second squadron cannot be selected because the first selection has already
committed an authoritative Squadron Activation.

Frequency: Observed in both Squadron Phase and command-activated squadron
interaction during manual testing.

## Evidence

- `annotation_20260906_070049_006.json`
- `game_20260906_063022.log`

The annotation states:

`After selecting a squadron in the squadron phase or command activated squadron,
i cannot select another squadron, even if i did not commit to use this squadron
by clicking move ore attack.`

The captured state shows an active squadron identity while both Move and Attack
remain available.

Related log warnings include rejected attempts to activate another squadron
because:

`Another squadron activation is active.`

## Initial Assessment

The likely issue is the Squadron Activation commitment boundary.

Current production behavior appears to submit/accept `ActivateSquadronCommand`
at selection time rather than when the player commits to Move or Attack.

Investigation must establish the accepted commitment semantics before changing
canonical ownership.

Check:

- Squadron Phase selection path;
- ship Squadron-command selection path;
- `ActivateSquadronCommand` submission boundary;
- modal/overlay transient selection state;
- Network confirmation gating;
- save/reconnect/replay implications if selection is currently durable.

Do not allow multiple simultaneous canonical Squadron Activations merely to make
selection reversible.

## Resolution

Root cause:

Fix:

Verification:

- Select squadron A without choosing Move or Attack.
- Select squadron B and verify selection can change without consuming capacity.
- Commit Move from the chosen squadron and verify activation becomes
  authoritative exactly once.
- Repeat with Attack as the first committed action.
- Verify both Squadron Phase and ship Squadron Command.
- Verify Network client/host behavior and rapid selection changes.
- Verify save/load/reconnect/replay contain only committed activation state.

# BUG-043 — Ship Speed Change Does Not Persist Into Next Round

Severity: High
Area: Ship Speed / Round Transition
Layer: Rules

## Expected

A ship's current speed is durable gameplay state.

When a ship changes speed during an activation, the resulting speed must remain
in effect until another gameplay rule or command changes it.

Advancing to a new round must not reset the ship to an earlier or scenario
default speed.

## Actual

During Network play, the Victory II-class Star Destroyer changed its speed to 1
during round 2.

At the beginning of round 3 the ship was again at speed 2 without the player
having changed it back.

The captured round-3 authoritative state reports:

- `current_round = 3`
- Victory II `current_speed = 2`

The game log shows accepted `set_speed` commands during the preceding Victory II
activation, followed by normal maneuver/activation completion.

## Reproduction

1. Start a Network game.
2. During a ship activation, change the Victory II's speed from 2 to 1.
3. Complete the activation and round normally.
4. Advance to the next round.
5. Inspect the ship's speed.

Result:
The Victory II is again at speed 2.

Frequency: Once observed; requires targeted reproduction.

## Evidence

- `annotation_20260906_064217_001.json`
- `game_20260906_063022.log`
- `replay_20260906_070521.json`

Annotation:

`the vsd did change its speed in round 2 to 1 and in round 3 it was at speed 2 again.`

Relevant log evidence includes accepted `set_speed` commands during the Victory II
activation before the subsequent round transition.

## Initial Assessment

This appears to be a canonical state/lifecycle defect rather than a display-only
issue.

Investigate:

- `SetSpeedCommand` execution and resulting `ShipInstance.current_speed`;
- maneuver execution after a speed change;
- End Activation cleanup;
- Status Phase cleanup / round transition;
- scenario/default-state reconstruction or projection paths that may overwrite
  current speed;
- Network authoritative vs mirrored state convergence.

Do not repair by storing separate UI speed state. `current_speed` must remain the
canonical source of truth.

## Resolution

Root cause:

Fix:

Verification:

- Change a ship from speed 2 to 1 and verify canonical speed becomes 1.
- Complete the activation and verify speed remains 1.
- Advance through Status Phase into the next round and verify speed remains 1.
- Verify both Network peers display the same speed.
- Verify Hot-Seat behavior.
- Verify save/load and replay preserve the changed speed.

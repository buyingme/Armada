# BUG-017 – Attack sequence stalls because defender never receives Spend Defense Token choice

Severity: High

Category: Gameplay / Network / Attack Resolution

## Summary

During the defense token step of a ship attack, the defending player (VSD) never receives the opportunity to spend or decline defense tokens. As a result, the attack sequence stalls indefinitely and cannot continue normally.

The issue has been independently reproduced twice.

## Expected Behavior

When the attack reaches the defense token step, the defending player should receive the appropriate interaction to spend or decline eligible defense tokens.

After the defender makes a choice (or no choice is available), the attack sequence should automatically continue to the next step.

## Actual Behavior

The Spend Defense Token interaction never appears for the defending VSD.

The attack remains permanently in the defense token step and the sequence cannot continue.

In one reproduction the attacking CR90 was forced to skip the attack entirely in order to unblock the game.

## Reproduction

1. Start a network game.
2. Perform a ship attack that reaches the Defense Token Spend step.
3. Observe the defending VSD client.
4. The Spend Defense Token interaction never appears.
5. The attack sequence stalls indefinitely.

## Evidence

### Reproduction 1

- Defending VSD never receives the Spend Defense Token choice.
- Attack sequence stalls permanently.
- Confirmed during network play.

### Reproduction 2

- Attack reaches the defense token step with modified damage = 0 after Damaged Munitions removes a die.
- The VSD still cannot spend or decline defense tokens.
- The attack does not progress automatically.
- The attacking CR90 must manually skip the attack to continue the game.

## Frequency

Reproduced twice.

## Notes

Both reproductions fail at the same interaction point: the transition through the Defense Token Spend step.

Although the game states differ (one attack has damage remaining, the other resolves to zero damage), the observable failure is identical, suggesting the issue is related to the interaction flow or controller hand-off for the defense token choice rather than the damage value itself.

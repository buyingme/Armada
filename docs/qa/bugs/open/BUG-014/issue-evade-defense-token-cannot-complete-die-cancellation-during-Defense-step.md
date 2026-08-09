# BUG-014 – Evade defense token cannot complete die cancellation during Defense step

## Summary

After spending an Evade defense token at long range, the required die-cancellation interaction never becomes available.

The Evade token is spent successfully, but no eligible die can be selected. The attack remains stalled in the Defense step and cannot continue through the normal Evade resolution.

This appears to be a regression. Evade die cancellation worked correctly before the recent Timing Window / H9 production activation work.

---

## Environment

- Branch: current TWI-002 production activation implementation
- Mode: Hot-seat
- Scenario: Debug Learning Scenario
- Manual smoke test after BUG-013 implementation

---

## Preconditions

- Ship attack against another ship.
- Long-range attack.
- Attack progresses normally through:
  - Concentrate Fire
  - H9
  - Confirm Attack Dice
  - Accuracy
- Defender spends an Evade token.

---

## Steps to Reproduce

1. Start the Debug Learning Scenario.
2. Attack the CR90 with the Victory II.
3. Resolve the Attack Modify step.
4. Resolve Accuracy.
5. Spend an Evade defense token.
6. Attempt to cancel one attack die.

---

## Expected Result

After the Evade token is spent:

- the eligible attack dice become selectable;
- selecting a die resolves the Evade effect;
- the attack continues normally to the next defense interaction.

---

## Actual Result

After the Evade token is spent:

- no die can be selected;
- the Evade interaction never completes;
- the attack remains stalled in the Defense step.

---

## Evidence

Attached:

- replay
- annotation(s)

The replay shows:

- Attack Modify completed successfully.
- Accuracy completed successfully.
- Evade token was spent.
- No subsequent Evade-resolution command was executed.
- The attack was later aborted.

The annotation shows:

- Defense step still active.
- Evade token already spent.
- No pending Evade interaction.
- No completed Evade resolution.

---

## Regression

Likely regression.

Evade die cancellation functioned correctly before the recent production activation work.

The regression appears after the Timing Window / Attack Modify integration.

---

## Initial Classification

Regression at the Defense Token interaction boundary.

The authoritative Spend Defense Token command succeeds, but the required follow-up Evade interaction does not occur.

No architectural ownership conclusion has been reached.

---

## Scope

Unknown.

Needs forensic investigation to determine where the Evade interaction is lost:

- SpendDefenseTokenCommand
- pending Evade state
- projection
- UI interaction
- Evade resolution command
- continuation

The investigation should determine whether this is:

- a projection regression,
- a controller/UI regression,
- or a continuation regression.

No repair approach has been selected yet.

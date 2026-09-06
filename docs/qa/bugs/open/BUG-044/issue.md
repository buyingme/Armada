# BUG-044 — Incorrect Attack Instruction Shown While Awaiting Opponent Acknowledgement

Severity: Medium
Area: Completed Attack Acknowledgement / Attack UI
Layer: Presentation

## Expected

While a completed attack is waiting for the other player's required
acknowledgement, the attacker's UI must continue to represent the completed
attack / acknowledgement state.

It must not display an instruction for a gameplay action that is not currently
legal, such as `Select Hull Zone`.

After acknowledgement convergence, the UI may display the instruction belonging
to the newly recovered gameplay state.

## Actual

During a Network anti-squadron attack, after the attacker acknowledges the
completed attack result but before the defender has acknowledged it, the
attacker UI displays:

`Select Hull Zone`

This is misleading because the completed attack inspection is still the active
interaction boundary and unrelated attack progression is not yet legal.

After the defender also acknowledges the result, the UI changes to the correct
text.

## Reproduction

1. In Network play, perform an anti-squadron attack.
2. Complete the attack.
3. Have the attacker acknowledge the attack result first.
4. Before the defender acknowledges, observe the attacker's UI instruction.
5. Have the defender acknowledge the result.

Result:
Before the second acknowledgement, the attacker temporarily sees
`Select Hull Zone`; after convergence, the correct instruction appears.

Frequency: Once observed.

## Evidence

- `annotation_20260906_065733_004.json`
- `game_20260906_063022.log`

The captured state contains a completed attack inspection with the attack result
and required player acknowledgements.

## Initial Assessment

Likely a presentation/recovery projection defect around the partially
acknowledged completed-attack inspection.

Canonical acknowledgement/attack validation should remain authoritative.

Investigate whether the attacker presentation:

- falls back to the enclosing ship Attack-step instruction after local
  acknowledgement;
- stops projecting the completed inspection once the local principal has
  acknowledged even though another required acknowledgement remains;
- refreshes correctly only when the inspection is fully satisfied.

Do not solve by allowing attack declaration while acknowledgement is still
outstanding.

## Resolution

Root cause:

Fix:

Verification:

- Complete an anti-squadron attack in Network play.
- Attacker acknowledges first.
- Verify attacker UI continues to display the proper waiting/completed-result
  state.
- Verify `Select Hull Zone` is not displayed prematurely.
- Defender acknowledges.
- Verify the correct enclosing gameplay instruction is then restored.
- Repeat with defender-first acknowledgement order.

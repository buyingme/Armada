# BUG-016 — Defense token confirmation sometimes requires multiple clicks

Severity: Low
Area: Ship Combat – Defense Token Resolution
Layer: Presentation | Command Flow

## Expected

When the defending player confirms defense token usage, the interaction should be accepted immediately after a single valid input and the attack sequence should continue without additional user interaction.

## Actual

During one network playtest, confirming defense token usage on the CR90 required several repeated clicks before the command was accepted. The attack sequence eventually continued successfully without becoming stuck.

The issue occurred once during the first playthrough after the H9 integration. It could not be reproduced during a subsequent test using the same scenario.

## Reproduction

Once

No reliable reproduction steps are currently known.

Observed during:
- Network play
- First gameplay after H9 integration
- CR90 defending against a Victory II-class Star Destroyer attack
- ECM interaction active

## Evidence

- annotation.json
- replay_20260807_103712.json
- replay_20260807_112425.json

The annotation captures the interaction while the attack is in the defense stage with ECM authorization active. The replay of the affected session and a subsequent successful replay have both been preserved for later comparison.

## Resolution

Root cause: Unknown.

Potential areas for investigation:
- Duplicate or delayed UI input handling.
- Interaction flow synchronization.
- Defense token confirmation command processing.
- Network timing or projector refresh timing during ECM-enabled defense resolution.

Fix: Pending investigation.

Verification:
- Reproduce the issue under identical network conditions.
- Verify that a single confirmation click always submits the defense token command.
- Execute multiple network playthroughs including ECM-enabled defense token resolution without repeated input requirements.

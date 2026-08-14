# BUG-004 — Command Token Not Refreshed After Grand Moff Tarkin Selection

Severity: Medium
Area: Grand Moff Tarkin
Layer: Projection

## Expected

After selecting a command token with Grand Moff Tarkin, the selected command token should immediately appear on the affected ship.

## Actual

The selected command token is correctly stored in the authoritative game state, but it is not immediately displayed in the UI.

The command token only becomes visible after an unrelated interaction causes the ship card to refresh (for example, enlarging and closing the ship card).

## Reproduction

1. Trigger the Grand Moff Tarkin command selection.
2. Choose a command token.
3. Observe the ship card.
4. Enlarge and close the ship card.

Result:
The command token only appears after the manual refresh.

Frequency: Always

## Evidence

annotation_20260730_064931_002.json

The captured state shows:

- Grand Moff Tarkin command selection has completed;
- the selected command token is already stored on the Imperial ship;
- `last_ship_phase_choice` has been recorded;
- the interaction has returned to the normal Ship Phase;
- the UI has not refreshed to display the updated command token.

20260814: manual retesting confirms that bug is still present. hot-set has been tested.
game_20260814_122718.log
replay_20260814_122914.json
annotation_20260814_122857_001.json

## Resolution

Root cause:

Fix:

Verification:

- Select a command token using Grand Moff Tarkin.
- Verify that the command token becomes visible immediately.
- Verify that no manual UI refresh is required.
- Verify reconnect, save/load, and repeated Tarkin activations continue to display the correct token.

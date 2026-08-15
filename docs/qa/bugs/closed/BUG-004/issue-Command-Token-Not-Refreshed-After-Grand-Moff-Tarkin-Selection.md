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

## Implementation Update — 2026-08-14

Confirmed root cause:

`TarkinChoiceCommand` correctly mutated each affected `ShipInstance`, but the
accepted-result presentation event was emitted only by
`GameManager._handle_remote_tarkin_choice()`. Synchronous Hot-Seat and network
host submissions through `ModalRouter` discarded the accepted result, so their
ship-card token columns had no refresh trigger.

Exact production failure path:

Tarkin modal selection -> accepted `TarkinChoiceCommand` -> canonical token
added -> `ModalRouter` ignored the result -> no `command_tokens_changed` event
-> stale ship card until magnification rebuilt the column.

Implemented fix:

- Added one accepted-result projector shared by the synchronous and mirrored
  Tarkin paths.
- `ModalRouter` projects only a non-empty, non-pending accepted result; network
  clients still wait for the authoritative mirror.
- The projector emits refresh events for the canonical affected
  `ShipInstance`; it does not own or copy command-token state.

Architecture/ownership:

`TarkinChoiceCommand` and `ShipInstance.command_tokens` remain authoritative.
The new route is presentation notification after acceptance only; no UI token
owner, compatibility write, protocol field, or serialized state was added.

Regression evidence:

- `test_accepted_tarkin_choice_refreshes_hotseat_and_mirrored_ship_cards`
  proves immediate Hot-Seat token rendering, repeated use, and the mirrored
  network refresh route.
- Existing Tarkin semantic/replay tests remain unchanged and passing.

Verification:

- focused `test_modal_router.gd`: 28/28 passed;
- focused `test_tarkin_choice_modal.gd`: 5/5 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: repaired by automated evidence; ready for Project Owner/manual
verification in Hot-Seat and Network modes.

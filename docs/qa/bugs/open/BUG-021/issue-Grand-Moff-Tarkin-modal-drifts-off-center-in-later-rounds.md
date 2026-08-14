# BUG-021 — Grand Moff Tarkin modal drifts off-center in later rounds

Severity: Low
Area: Modal UI / Grand Moff Tarkin
Layer: Presentation

## Expected

The Grand Moff Tarkin choice modal should appear centered consistently whenever it is opened.

Its position should remain stable across rounds and repeated openings.

Other modal dialogs should likewise retain their intended screen position when reopened.

## Actual

The Grand Moff Tarkin modal appears off-center.

In subsequent rounds, the modal moves progressively farther to the right side of the screen.

The underlying Grand Moff Tarkin interaction remains active and usable; the observed defect concerns the modal position/presentation.

It is currently unclear whether this is specific to the Grand Moff Tarkin modal or a more general modal-positioning issue.

## Reproduction

Once

Observed sequence:

1. Start a game with Grand Moff Tarkin.
2. Reach the Ship Phase and open the Tarkin command-choice modal.
3. Continue into later rounds.
4. Observe the Tarkin modal when it opens again.
5. The modal is no longer centered and appears progressively shifted to the right.

## Evidence

- `annotation_20260814_113440_001.json`

The captured state shows the Grand Moff Tarkin choice interaction active in round 2 for Player 1, while the reported defect concerns only the modal's screen position.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:
Open the Grand Moff Tarkin modal repeatedly across multiple rounds and verify that it remains centered each time.

Also check other reusable modal dialogs to determine whether the same position drift occurs more generally.

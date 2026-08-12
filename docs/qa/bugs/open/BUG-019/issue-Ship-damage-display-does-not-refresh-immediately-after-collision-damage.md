# BUG-019 — Ship damage display does not refresh immediately after collision damage

Severity: Low
Area: Ship UI / Damage Display
Layer: Presentation

## Expected

When a ship receives damage cards from a collision, the ship UI should immediately update to reflect the new damage state.

The displayed damage-card count/state should remain synchronized with the authoritative game state without requiring any additional UI interaction.

## Actual

After collision damage is applied, the authoritative game state contains the new damage card, but the ship UI does not immediately refresh.

The correct damage display appears only after magnifying/opening the ship card.

The issue is present on both host and client.

## Reproduction

Once

Observed sequence:

1. Cause a ship to receive damage from a collision.
2. Observe the ship UI after the damage is applied.
3. The newly dealt damage card is not reflected immediately.
4. Magnify/open the ship card.
5. The UI refreshes and then shows the correct damage state.

## Evidence

- `annotation_20260812_210816_001.json`
- `client_20260812_210323.log`

The captured authoritative state already contains the newly dealt facedown damage card, indicating that the underlying game state is correct and the defect is limited to UI refresh/presentation.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:
Reproduce collision damage and verify that the ship UI refreshes immediately on both host and client without requiring the ship card to be magnified or reopened.

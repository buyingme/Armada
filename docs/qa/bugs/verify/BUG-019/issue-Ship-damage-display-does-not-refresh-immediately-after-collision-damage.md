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

## Implementation Update — 2026-08-14

Confirmed root cause:

The host/client symptoms came from the two sides of the same accepted-result
gap. On the acting network client,
`ShipActivationController._apply_overlap_damage()` treated the non-empty
`awaiting_remote` sentinel as a completed result and emitted damage refreshes
before the mirrored command mutated canonical state; the log therefore showed
both card columns refreshing at facedown=0. On the passive host/peer, mirrored
`overlap_damage` handling emitted no damage-card or hull refresh for either
ship after canonical mutation.

Exact production failure path:

client submits collision damage -> premature pre-command refresh -> authority
executes and mirrors canonical cards -> remote effect handler performs no
post-command card/hull refresh -> both displays remain stale until card
magnification.

Implemented fix:

- The acting client now stops at the pending sentinel and waits for the
  accepted mirror.
- Mirrored overlap results resolve both canonical ships and emit card/hull
  projection refreshes for each after command application.
- Canonical card mutation remains entirely in `OverlapDamageCommand`.

Architecture/ownership:

No damage cache or UI-owned hull/card state was introduced. Presentation
events cause panels/tokens to re-read the already-mutated `ShipInstance`.
The semantic command, payload, replay, and save formats are unchanged.

Regression evidence:

- `test_pending_network_overlap_does_not_refresh_from_precommand_state`
  proves no optimistic refresh or canonical damage occurs while awaiting.
- `test_mirrored_overlap_result_refreshes_both_ship_presentations` proves both
  card and hull projections refresh from the accepted result.

Verification:

- focused `test_ship_activation_controller.gd`: 8/8 passed;
- focused `test_p6_commands.gd`: 29/29 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: repaired by automated evidence; ready for Project Owner/manual
collision verification in Hot-Seat and Network modes.

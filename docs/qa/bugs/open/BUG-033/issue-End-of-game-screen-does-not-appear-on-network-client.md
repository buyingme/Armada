# BUG-033 — End-of-game screen does not appear on network client

Severity: High
Area: End game / network play
Layer: Networking

## Expected

When the game ends in network play, the end-of-game state must be reflected on both instances.

Both the host and the client must transition to the end-of-game presentation and display the end-of-game screen.

## Actual

The game reached its end, but the end-of-game screen did not appear on the client side.

The client therefore remained without the expected final game presentation after the game had ended.

## Reproduction

Once

1. Start and play a network game with host and client.
2. Continue the game until the normal end-of-game condition is reached.
3. Observe the end-of-game transition on both instances.
4. The expected end-of-game screen does not appear on the client.

Observed at the end of Round 6.

## Evidence

A complete evidence package from the affected network gameplay run has been retained:

- `annotation_20260816_095035_001.json`
  - Records the observed defect on the client at the end of the game.
- `replay_20260816_095010.json`
  - Preserves the authoritative command/gameplay sequence from the affected run.
- Host and client logs from the affected gameplay run.
  - Preserve runtime and networking evidence surrounding the end-of-game transition.

The annotation, replay, and host/client logs should be investigated together to determine whether the authoritative end-of-game state was reached and propagated correctly, and where the client-side transition failed.

They are part of the BUG-033 evidence and should be retained until resolution and verification are complete.

## Resolution

Root cause: TBD.

Fix: TBD.

Verification: Complete a network game and verify that both host and client enter the authoritative end-of-game state and display the end-of-game screen. Verify through the replay and host/client logs that the end-game transition is deterministic and correctly synchronized.

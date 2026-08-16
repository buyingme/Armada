# BUG-032 — Injured Crew faceup damage effect does not trigger

Severity: High
Area: Critical damage cards / ship activation
Layer: Rules

## Expected

When a ship has the faceup **Injured Crew** damage card, its effect must trigger at the applicable timing point:

Choose and discard 1 of your defense tokens. Then flip this card facedown.

The player must be given the required choice of defense token, the selected token must be discarded, and Injured Crew must then be flipped facedown.

## Actual

The CR90 had **Injured Crew** faceup, but its effect did not trigger.

No choice of defense token was presented, no defense token was discarded, and the damage card effect was therefore not resolved.

Gameplay continued without applying the required critical damage effect.

## Reproduction

Once

1. Have a ship receive the **Injured Crew** faceup damage card.
2. Continue play until the timing point at which Injured Crew must resolve.
3. Observe whether the game requests selection of a defense token.
4. Observe whether the selected token is discarded and Injured Crew is flipped facedown.

Observed on the CR90 during Round 4.

## Evidence

A complete evidence package from the affected gameplay run has been retained:

- `annotation_20260816_094556_002.json`
  - Records that the faceup damage-card effect on the CR90 did not trigger.
- `annotation_20260816_094640_003.json`
  - Identifies the affected card as **Injured Crew** and records the expected effect.
- Replay from the affected gameplay run.
  - Preserves the authoritative command/gameplay sequence for reproduction and investigation.
- Logs from the affected gameplay run.
  - Preserve runtime evidence surrounding the failed damage-card resolution.

The replay and logs should be investigated together with the annotations when determining the root cause. They are part of the BUG-032 evidence and should be retained until resolution and verification are complete.

## Resolution

Root cause: TBD.

Current diagnostic evidence:

The Injured Crew effect works when the damage card is assigned through the existing debug tooling, while the effect failed when reached through normal gameplay.

This suggests that the damage-card rule implementation itself may be functional and that the defect may instead involve the authoritative gameplay path into damage-card rule processing, potentially including timing-window integration. This remains a hypothesis until verified.

The existing debug path is not yet a sufficient architectural reference because state-changing debug operations have not been established as consistently using canonical authoritative commands.

Dependency:

BUG-032 depends on `DBG-001 — Authoritative Debug State Mutation`.

BUG-032 must not be accepted as resolved until the relevant DBG-001 infrastructure has been implemented and the debug damage-card path can be used as an authoritative, replayable verification path.

Fix: TBD.

Verification:

1. Implement the relevant DBG-001 authoritative debug infrastructure.
2. Assign Injured Crew through the authoritative debug path and verify correct resolution.
3. Trigger Injured Crew through normal gameplay and verify correct resolution.
4. Confirm that both paths reach the same authoritative damage-card rule behavior.
5. Verify that the player must select a legal defense token.
6. Verify that the selected defense token is discarded.
7. Verify that Injured Crew is flipped facedown after resolution.
8. Verify correct behavior in hot-seat and network play.
9. Verify through replay/log evidence that the relevant state transitions follow the authoritative command and game-state path.

BUG-032 may be accepted as resolved only after both the normal gameplay path and the authoritative debug setup path pass verification.

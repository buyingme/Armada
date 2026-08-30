# BUG-032 — Injured Crew resolves but Hot-Seat UI does not reflect discarded defense token

Severity: Medium
Area: Critical damage cards / Hot-Seat presentation
Layer: UI / gameplay-state projection

## Expected

When a ship receives the faceup **Injured Crew** damage card:

> Choose and discard 1 of your defense tokens. Then flip this card facedown.

the required choice must be presented, the selected defense token must be discarded authoritatively, Injured Crew must be flipped facedown, and the UI must immediately reflect the resulting canonical state.

The behavior must be consistent in Hot-Seat and Network play.

## Actual

The original BUG-032 failure, in which Injured Crew did not trigger at all, is no longer observed after implementation of `DBG-001 — Authoritative Debug State Mutation`.

In current testing:

- Injured Crew triggers.
- The defense-token selection modal is presented.
- The player can select the defense token to discard.
- The damage-card effect proceeds through the authoritative damage-card path.

However, in **Hot-Seat mode**, the UI does not correctly update after the choice: the discarded defense token remains represented in the ship UI.

The equivalent interaction works correctly in Network mode.

The remaining defect therefore appears to be a Hot-Seat presentation/projection refresh problem rather than failure of the Injured Crew gameplay rule itself.

## Reproduction

Confirmed in current DBG-001 verification.

### Hot-Seat

1. Start a Hot-Seat game.
2. Use the authoritative DEBUG damage-card tooling to deal **Injured Crew** faceup to a ship with defense tokens.
3. Select a defense token when the Injured Crew choice modal appears.
4. Confirm the choice.
5. Observe the ship UI.

### Observed

The choice is accepted, but the discarded defense token remains represented in the UI.

### Network comparison

Repeat the equivalent test in Network mode.

The resulting UI correctly reflects the discarded defense token.

## Evidence

Current evidence includes:

- `annotation_20260830_080038_002.json`
  - Records that the Injured Crew selection modal is presented but the defense token does not disappear from the Hot-Seat UI.
- `game_20260830_074459.log`
  - Records the authoritative DBG-001 damage-card path, Injured Crew handling, DEBUG exit, and gameplay handoff.
- Current Network verification
  - The equivalent Injured Crew interaction updates correctly in Network play.

Historical BUG-032 evidence should be retained because it records the original failure before DBG-001 and demonstrates that the underlying failure mode has changed.

## Resolution

Root cause: TBD.

### Current diagnostic status

The original hypothesis that the normal gameplay path failed to reach damage-card rule processing is no longer supported by current testing.

Following DBG-001 implementation, damage-card effects are now observed to function through both DEBUG-assisted testing and normal gameplay.

The remaining confirmed BUG-032 defect is narrower:

**Hot-Seat does not correctly refresh/project the defense-token state after Injured Crew resolution, while Network does.**

The authoritative state and presentation paths should be compared before determining the fix. The UI must derive the resulting defense-token presentation from canonical gameplay state rather than receiving a special Injured Crew-specific presentation mutation.

Fix: TBD.

## Verification

BUG-032 may be accepted as resolved when:

1. Injured Crew presents the required legal defense-token choice.
2. The selected token is discarded authoritatively.
3. Injured Crew is flipped facedown after resolution.
4. Hot-Seat UI immediately reflects the discarded defense token.
5. Network UI continues to reflect the same canonical result correctly.
6. DEBUG-assisted and normal-gameplay damage paths produce equivalent rule behavior.
7. Replay/log evidence confirms the authoritative command/state transition.
8. No damage-card-specific presentation workaround or second state path is introduced.

## Dependency status

The previous dependency on `DBG-001 — Authoritative Debug State Mutation` has been satisfied.

DBG-001 has provided the authoritative debug path required to isolate the remaining BUG-032 behavior.

BUG-032 remains open only for the Hot-Seat presentation/projection defect described above.

# BUG-048 — Speed-0 Maneuver Interaction Is Missing or Rendered Incorrectly

## Status

Open

## Summary

The Ship Maneuver interaction does not correctly support a ship whose canonical speed is already 0.

Two related symptoms were observed during Owner manual acceptance testing:

1. When a speed-0 Maneuver tool is displayed, the wrong maneuver-tool geometry is shown. The first ship-side/root segment is rendered instead of the arrow-shaped terminal/facing segment required by the accepted speed-0 Maneuver behavior.
2. When a ship enters its Maneuver opportunity while its canonical speed is already 0, the Maneuver tool is not opened at all. The +/- speed controls are therefore unavailable, preventing the player from increasing speed even when a Navigate command permits a legal speed increase.

The second symptom makes a legal gameplay decision unreachable and is therefore functional, not merely cosmetic.

## Environment

- Mode: observed during current BUG-043 manual acceptance testing
- Scenario: Debug Scenario
- Relevant work: BUG-043 Maneuver capability integration
- Replay format: current candidate replay format 10

## Preconditions

A ship reaches its Maneuver opportunity at canonical speed 0.

For the speed-change case, the ship also has an available Navigate command/resource combination that legally permits increasing its speed.

## Steps to Reproduce

### Case A — Speed-0 representation

1. Activate a ship.
2. Reach the Maneuver opportunity.
3. Select/execute a legal speed-0 Maneuver.
4. Observe the displayed maneuver tool.

### Case B — Ship already at speed 0

1. Begin a ship activation with the ship's canonical speed already at 0.
2. Have a Navigate command available so that increasing speed is legal.
3. Progress normally to the Maneuver opportunity.
4. Observe the Maneuver interaction.

## Expected Result

Speed 0 uses the normal Maneuver interaction.

At speed 0:

- the maneuver tool is displayed;
- the visual representation uses the accepted arrow-shaped terminal/facing segment rather than the ship-side/root segment;
- the normal Maneuver speed controls are available;
- legal Navigate-based speed increases can be selected;
- illegal speed changes remain unavailable;
- committing an unchanged speed of 0 proceeds through the normal authoritative Maneuver execution path.

Pre-commit speed selection remains transient and must not restore an obsolete `SetSpeed` or special speed-0 bypass path.

## Actual Result

- The speed-0 Maneuver graphic uses the wrong maneuver-tool segment.
- The +/- speed controls are missing.
- If the ship is already at canonical speed 0 when the Maneuver opportunity is reached, the Maneuver tool is not shown at all.
- Consequently, a player cannot select a legal Navigate-based increase from speed 0.

## Impact

A ship already at speed 0 can be prevented from making an otherwise legal Navigate speed choice.

The defect also violates the accepted speed-0 Maneuver presentation semantics established during BUG-043.

## Classification

Functional UI / interaction defect with a presentation component.

The defect appears to be within the existing BUG-043 Maneuver interaction/projection scope. No new gameplay rule or architecture decision is currently identified.

## Acceptance Criteria

- A ship at canonical speed 0 enters the normal Maneuver interaction.
- The accepted speed-0 maneuver-tool representation is displayed.
- The +/- speed controls are projected through the normal Maneuver UI.
- Navigate-enabled speed 0 → 1 is reachable and commits correctly.
- Unchanged speed 0 → 0 remains a valid normal Maneuver.
- A ship without legal Navigate speed modification cannot make an illegal speed change.
- No obsolete pre-commit `SetSpeed`, special speed-0 execution bypass, or parallel Maneuver authority is introduced.
- Hot-Seat and Network presentation derive the same legal Maneuver choices from authoritative state.
- Focused regression coverage protects both the speed-0 entry and rendering cases.

## Relationship to Existing Work

- BUG-043 — Network Maneuver Preview / Speed Convergence and Maneuver capability integration
- ADR-006 — Ship Activation / Maneuver execution ownership
- Accepted BUG-043 implementation workbook

This issue should be repaired as part of the post-BUG-043 manual-acceptance stabilization batch rather than by redesigning Maneuver authority.

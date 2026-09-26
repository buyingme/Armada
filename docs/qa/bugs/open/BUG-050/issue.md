# BUG-050 — Out-of-Play Maneuver Destruction Omits Command-Owned Cleanup

## Status

Open

## Summary

The BUG-043 Stabilization Verification Refinement V3 processor test exposed a
new production defect in the final-play-area destruction boundary.

When `apply_maneuver_transform` applies the committed final transform outside
the play area, `CandidateApplyManeuverTransformCommand` correctly marks the
ship destroyed and suppresses normal Maneuver completion. However,
`CommandProcessor` does not capture `apply_maneuver_transform` as a command
that may newly destroy a ship. It therefore does not enqueue the existing
`destroy_unit` cleanup command.

The resulting history contains only `apply_maneuver_transform`; the required
single destruction cleanup and enclosing selection/end-game return are absent.

## Discovery

- Discovered while implementing V3 of the accepted BUG-043 Stabilization
  Verification Refinement.
- This is a newly demonstrated production defect, not an assumed consequence
  of an evidence gap.
- Per the refinement's bounded-scope rule, BUG-043 stabilization stopped when
  this defect was demonstrated. No production repair was attempted.

## Reproduction

1. Establish an active speed-0 Maneuver whose committed final transform leaves
   the ship base outside the play area.
2. Submit `apply_maneuver_transform` through a real `CommandProcessor` in live
   authority mode.
3. Inspect the ship and recorded command history.

## Expected Result

- The actual final transform is retained.
- The ship is destroyed exceptionally.
- Exactly one `destroy_unit` command performs canonical cleanup.
- No `complete_maneuver` command is recorded.
- The existing selection/end-game owner receives the exceptional return.

## Actual Result

- The actual final transform is retained.
- The ship is marked destroyed and its active Maneuver execution is cleared.
- No `destroy_unit` command is recorded.
- No command-owned selection/end-game cleanup follows.

## Evidence

Focused regression:

`tests/unit/test_candidate_apply_maneuver_transform_command.gd::test_v3_processor_out_of_play_cleanup_occurs_once_without_completion`

Observed history:

`["apply_maneuver_transform"]`

Expected history:

`["apply_maneuver_transform", "destroy_unit"]`

Production ownership evidence:

- `CandidateApplyManeuverTransformCommand.execute()` calls
  `ship.mark_destroyed()` when the applied result is outside the play area.
- `CommandProcessor._capture_destruction_candidates()` captures damage-producing
  commands but does not include `apply_maneuver_transform`.
- The processor can only enqueue command-owned destruction cleanup for targets
  captured before command execution.

## Scope Disposition

Repair is not authorized by the current bounded BUG-043 stabilization scope.
The defect requires owner disposition before V3 and subsequent V4–V8,
convergence, visual smoke, and replay-capture readiness can continue.

Any repair must reuse the existing `destroy_unit` and phase/selection return
owners. It must not add a generic continuation, FSM, or parallel destruction
authority.

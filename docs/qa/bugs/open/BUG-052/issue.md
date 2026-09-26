# BUG-052 — Save-7 Maneuver Recovery Does Not Normalize Canonical Integer Fields

## Status

Open

## Summary

The BUG-043 Stabilization Verification Refinement V5 production save/load
matrix exposed a serialization-boundary defect. `SaveGameManager` successfully
writes signed Save-7 files containing active Maneuver owners, but several
materially distinct states cannot be loaded, while saved obstacle geometry can
load without re-deriving the original overlap decision.

The strict owner validators correctly require canonical integer fields. The
JSON load path, however, passes parsed numeric values directly to those
validators. Godot JSON parsing represents the values as floats, and the
Maneuver/damage/obstacle installers do not restore the schema-owned integer
types before validation or use.

## Discovery

- Discovered while executing V5 of the accepted BUG-043 Stabilization
  Verification Refinement.
- This is a demonstrated production save/install defect, not an evidence-only
  deficiency.
- Per the refinement, stabilization stopped immediately. No repair was
  attempted.

## Reproduction

Use the production `SaveGameManager.save_game()` and `load_game()` path with
the V5 recovery matrix in:

`tests/integration/test_bug_043_stabilization_projection_recovery.gd::test_v5_production_save_install_and_filtered_reconnect_preserve_owners`

Observed examples:

1. A committed pre-movement execution saves successfully but `load_game()`
   returns `ok == false` with no restored state.
2. Active Debris, Station, Projector, Injured Crew, Shield Failure, Comm Noise,
   and automatic immediate boundaries likewise fail strict state
   deserialization.
3. A saved multi-obstacle-order state loads, but its canonical obstacles no
   longer re-derive the order decision; the evaluator incorrectly reaches
   `complete_maneuver`.

## Expected Result

- Every V5 authority owner round-trips through signed Save-7 JSON.
- Canonical integer fields retain their schema meanings after JSON parsing.
- The restored evaluator derives the same next action, actor, identity, and
  options.
- Filtered reconnect installation preserves the equivalent public decision.
- Completed or destroyed work remains closed and no command is synthesized.

## Actual Result

- Several active states are rejected during `GameState.deserialize()`.
- A loaded obstacle state can lose authoritative overlap recognition.
- Stable states without these integer-bearing active records still load.

## Production Cause Evidence

- `ShipInstance.deserialize()` copies the raw
  `active_maneuver_execution` into `install_maneuver_execution_for_save7()`.
  `_maneuver_committed_result_is_valid()` requires every `yaw_clicks` entry to
  be `TYPE_INT`, but signed JSON reload supplies numeric entries as floats.
- Active obstacle records are copied without normalizing fields such as
  `controller_player` before strict validation.
- Active immediate records are copied before
  `_active_immediate_resolution_is_valid()` requires `actor_player` to be an
  integer.
- `GameState._deserialize_representation()` duplicates `objectives` directly;
  obstacle `placing_player` and `placement_order` therefore retain JSON numeric
  representation instead of their canonical integer schema.

These are owner-boundary normalization omissions. Weakening the validators or
accepting arbitrary numeric representations as canonical state is not an
authorized repair.

## Scope Disposition

BUG-052 requires Owner disposition before V5 can continue and before V9, V6,
V8, convergence, visual smoke, or replay-capture readiness proceeds.

Any repair must normalize only the existing schema-defined integer fields at
their established deserialization owners. It must not add a generic migration
framework, duplicate state representation, compatibility mode, or new recovery
authority.

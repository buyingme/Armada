# BUG-051 — Maneuver Consequence Projection Violates Modal Chooser Contract

## Status

Open

## Summary

The BUG-043 Stabilization Verification Refinement V4 real-board projection
test exposed a production contract mismatch between the Ship Activation
controller and `OpponentChoiceModal`.

`ShipActivationController._maneuver_choice_descriptor()` writes the numeric
`action.player_index` into the descriptor's `chooser` field. The receiving
modal declares that field as a `String` and interprets the accepted symbolic
values `"owner"` and `"opponent"`. Opening any Maneuver consequence decision
therefore raises a runtime type error before the chooser label can be built.

The same failure occurs after a live command-result projection and after
canonical reconstruction. This prevents V4 from proving an actionable modal
even though the evaluator derives the correct command, actor, and options.

## Discovery

- Discovered while executing V4 of the accepted BUG-043 Stabilization
  Verification Refinement.
- This is a newly demonstrated production defect, not an assumed evidence
  gap.
- Per the refinement's bounded-scope rule, stabilization stopped immediately.
  No production repair was attempted.

## Reproduction

1. Install an active Maneuver execution whose next evaluator action is any
   genuine decision, such as multi-obstacle ordering.
2. Route a live command result through the real `GameBoard` modal router, or
   call its canonical reconstruction path.
3. Let `ShipActivationController.project_maneuver_consequence()` open the
   existing `OpponentChoiceModal`.

## Expected Result

- The modal opens with the evaluator-derived actor, identity, and options.
- The chooser label represents whether the local decision belongs to the ship
  owner or opponent.
- Live projection and reconstruction are equivalent and submit no command.

## Actual Result

- The controller supplies `chooser` as an integer player index.
- `OpponentChoiceModal._build_header_section()` assigns that value to a typed
  `String` variable.
- Godot reports: `Trying to assign value of type 'int' to a variable of type
  'String'.`
- The modal UI build is incomplete in both live projection and reconstruction.

## Evidence

Focused regression:

`tests/integration/test_bug_043_stabilization_projection_recovery.gd::test_v4_live_and_reconstructed_decision_projection_are_equivalent`

Production ownership evidence:

- `ShipActivationController._maneuver_choice_descriptor()` returns
  `"chooser": int(action["player_index"])`.
- `OpponentChoiceModal._build_header_section()` declares
  `var chooser: String = _choice_info.get("chooser", "opponent")` and supports
  the symbolic owner/opponent presentation contract.
- `ModalRouter` uses the same controller projection for live results and
  reconstruction, so both paths reproduce the mismatch without synthesizing
  gameplay work.

## Scope Disposition

Repair is not authorized by the current BUG-050 continuation authorization.
Owner disposition is required before V4 can continue and before V5–V8,
convergence, visual smoke, or replay-capture readiness proceeds.

Any repair should preserve the evaluator's numeric authoritative actor while
adapting only the presentation descriptor to the existing modal contract. It
must not create a second decision owner, generic decision framework, or
Network-specific presentation lifecycle.

# BUG-053 — Obstacle-Order Modal Emits a Non-Canonical Array Type

## Status

Open

## Summary

The BUG-043 Stabilization Verification Refinement V6 real-Network scenario
reconstructed the canonical multi-obstacle decision correctly for a newly
assigned endpoint, but the production presentation adapter submitted an
invalid command payload. `ShipActivationController` converts the selected
symbolic ordering with `String.split()`, producing a `PackedStringArray`, while
the accepted `commit_maneuver_obstacle_order` contract requires
`obstacle_ids:Array`.

This is a demonstrated production adapter defect, not an evidence-only gap.
The authoritative command rejected the submission without mutation.

## Discovery

- Discovered while executing V6 after BUG-052/V5 convergence.
- The real ENet scenario used the existing protocol-7 submission, broadcast,
  filtered reconnect, board reconstruction, modal, and principal gates.
- No replay fixture or replay evidence was created or modified.

## Reproduction

Run:

`./scripts/run_network_resume_acceptance.sh --bug-043-only`

The bounded scenario proves the following before the failure:

1. The host principal's attempt to submit player 0's speed-zero Maneuver is
   rejected without mutation.
2. The authenticated client controlling player 0 submits the legal speed-zero
   Maneuver.
3. Authority records exactly one `execute_maneuver` and one
   `apply_maneuver_transform`, then derives the multi-obstacle order decision.
4. The client disconnects while that decision is pending.
5. A replacement endpoint is explicitly assigned player 0, installs the
   filtered state at the correct cursor, and reconstructs the actionable
   `OpponentChoiceModal` for `commit_maneuver_obstacle_order`.
6. Confirming `obstacle:0|obstacle:1` reaches authority and is rejected with
   `Invalid obstacle-order payload.`

## Expected Result

The presentation adapter emits the existing exact command payload with
`obstacle_ids:Array[String]`. Authority accepts it once, broadcasts it in
order, and continues to the next purpose-specific consequence without any
parallel choice representation or weakened validation.

## Actual Result

`ShipActivationController._on_maneuver_consequence_choice()` assigns:

`payload["obstacle_ids"] = selected_id.split("|", false)`

Godot returns a `PackedStringArray`. The strict
`CandidateCommitManeuverObstacleOrderCommand.validate()` check requires an
ordinary `Array`, so the legitimate reconstructed modal submission rejects.

## Production Cause Evidence

- Canonical derivation is correct: the endpoint derives and projects
  `commit_maneuver_obstacle_order` for player 0 with both obstacle identities.
- Principal assignment is correct at the submission boundary: the replacement
  endpoint reports local player 0 before the attempt.
- The command reaches authority and fails the exact payload-type check.
- The state remains unchanged; no order command, obstacle consequence, or
  duplicate follow-up is accepted.

The mismatch is confined to the existing presentation-to-command adapter. It
does not authorize weakening the command schema, changing principal checks, or
introducing another chooser representation.

## Scope Disposition

BUG-053 requires Owner disposition before V6 can continue. V8, convergence,
the BUG-048 visual smoke, and the Owner replay-capture boundary remain
unreached.

The accumulated BUG-050 through BUG-053 findings should trigger a bounded
reassessment of BUG-043 integration-boundary conformance before further
implementation. They recur at distinct handoffs—processor cleanup,
canonical-to-modal projection, JSON-to-canonical installation, and
modal-to-command adaptation—rather than demonstrating one new gameplay owner.
Any reassessment should remain focused on exact existing contracts and must not
create a generic decision, continuation, migration, or adapter framework.

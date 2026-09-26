# BUG-057 — Pending Interaction Reconstruction Is Not Connected to Normal Board Entry

**Status:** Open

## Summary

Valid pending Maneuver/displacement interaction state can exist canonically after load/reconnect, but the normal GameBoard/router startup path does not reliably reconstruct the corresponding actionable interaction.

Existing tests can mask this defect by explicitly invoking controller projection/reconstruction helpers that production startup does not invoke in the same way.

## Observed Behavior

Ordinary pending Maneuver states do not satisfy the GameBoard reconstruction gate because that gate is tied to completed-Attack inspection.

The reconstruction helper therefore exists, but normal board initialization does not reliably route valid pending Maneuver state into it.

For displacement, explicit router reconstruction additionally passes `null` where the displacement route requires a live command/context and therefore rejects reconstruction.

Existing V6 test-driver behavior explicitly invokes controller projection, masking the missing production entry connection.

## Expected Behavior

When canonical state after load/reconnect contains a valid pending interaction, normal production board initialization/reconstruction must derive and expose the same legal decision that was available before interruption.

Reconstruction must occur through the existing purpose-specific evaluator/router/controller path.

Tests must not need to manually invoke a projection helper that normal production startup would not invoke.

For pending displacement, the reconstruction path must supply the existing information required by that purpose-specific route without manufacturing gameplay commands.

## Classification

Production reconstruction / board-entry integration defect.

This is a demonstrated production defect, not merely missing evidence.

## Architecture / Authority Constraints

- Preserve ADR-010 decision-equivalent recovery.
- Canonical gameplay state remains authoritative.
- Reconstruction must not submit semantic gameplay commands.
- Do not create synthetic commands merely to open UI.
- Preserve purpose-specific routing and ownership.
- Do not introduce a generic continuation/reconstruction FSM or interaction stack.
- Live and reconstructed presentation must converge on equivalent actor/options/actionability.
- No new architecture decision is currently identified.

## Evidence

Identified during the BUG-043 production-boundary conformance reassessment.

The normal GameBoard reconstruction entry is gated by completed-Attack inspection and does not cover ordinary pending Maneuver state.

The displacement reconstruction path requires context that the router currently supplies as `null`.

Existing V6 acceptance infrastructure explicitly invokes controller projection, allowing the test to bypass the missing normal production entry.

## Acceptance Criteria

- A pending Maneuver decision restored through the normal production load/reconnect path opens through normal board initialization without test-side projection calls.
- A pending displacement decision does the same.
- Reconstructed actor, options and actionability match the equivalent live interaction.
- Reconstruction submits no semantic gameplay command.
- No completed-Attack-specific gate is incorrectly required for unrelated pending Maneuver reconstruction.
- No generic reconstruction/continuation authority is introduced.

## Relationships

- BUG-043 — Ship Maneuver Capability Integration / stabilization.
- BUG-051 — related projection adapter defect.
- BUG-056 — recovered displacement payload representation defect.
- ADR-010 — decision-equivalent recovery.
- V4/V5/V6 stabilization evidence.

## Disposition

Include in the bounded BUG-043 production-boundary conformance stabilization batch.

Repair only the missing normal production entry/routing handoff. Do not redesign reconstruction architecture.

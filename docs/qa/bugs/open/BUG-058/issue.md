# BUG-058 — Filtered Recovery Reopens Already-Completed Maneuver Consequences

**Status:** Open

## Summary

Filtered Network/reconnect state correctly omits authority-only completion markers, but the Maneuver evaluator still interprets the absence of those markers as evidence that some already-completed consequences remain unresolved.

After reconnect, this can cause passive/reconstructed state to expose stale work that authority has already completed.

In the multiple Ruptured Engine instance case, authority rejects the stale choice.

## Observed Behavior

Authority-only completion/execution markers are intentionally removed from filtered state.

The current evaluator nevertheless uses absence of those markers when determining unresolved Maneuver work.

The reassessment identified these cases:

1. Multiple Ruptured Engine instances:
   - authority resolves the first instance;
   - reconnect occurs while the second remains pending;
   - filtered cards omit execution markers for both instances;
   - reconstructed evaluation selects the first instance again;
   - authority rejects the stale selection.

2. Obstacle consequences:
   - completed obstacle markers are omitted by filtering;
   - overlap re-derivation can interpret their absence as an unresolved obstacle consequence.

The filtering itself conforms to the privacy/passive-state contract. Publishing the authority-only markers to passive clients is not an acceptable repair.

## Expected Behavior

Filtered/reconstructed state must be sufficient to recover the viewer-authorized pending decision without requiring disclosure of authority-only completion markers.

Already-completed Maneuver consequences must not reopen after reconnect.

Remaining unresolved consequences must still be recoverable and actionable by the appropriate controller.

Passive/reconstruction logic must not synthesize authority-only history or gameplay commands.

## Classification

Production filtered-recovery / decision-equivalent reconstruction defect.

This is a demonstrated production defect, not merely missing evidence.

## Architecture / Authority Constraints

- Preserve filtered-state privacy boundaries.
- Do not expose authority-only execution/completion markers merely to simplify reconstruction.
- Preserve passive non-synthesis.
- Preserve canonical authority over consequence completion.
- Preserve purpose-specific Maneuver execution ownership.
- Reconstructed state must be decision-equivalent, not necessarily byte/state-shape equivalent to authority state.
- Do not introduce a generic continuation stack/FSM.
- No new architecture decision is currently identified.

## Evidence

Identified during the BUG-043 production-boundary conformance reassessment.

The state filter correctly removes authority-only markers.

The Maneuver evaluator subsequently treats their default absence as unresolved work.

The reassessment identified the resulting stale-selection behavior for multiple Ruptured Engine instances and the same absence-as-unresolved problem for completed obstacle consequences.

The correct repair must therefore occur within existing viewer-authorized recovery semantics rather than by publishing the hidden authority markers.

## Acceptance Criteria

- Resolve one consequence from a sequence containing additional pending consequences.
- Reconnect/install filtered state before the sequence is complete.
- Reconstruction exposes the correct next unresolved consequence, not an already-completed one.
- The demonstrated multi-instance Ruptured Engine case does not reopen the first resolved instance.
- Completed obstacle consequences do not reopen merely because authority-only completion markers are absent from filtered state.
- Remaining genuine pending decisions remain actionable.
- Authority-only markers remain filtered.
- Passive/reconstruction paths submit no semantic gameplay commands.
- Live and reconstructed gameplay converge to the same legal next decision or stable state.

## Relationships

- BUG-043 — Ship Maneuver Capability Integration / stabilization.
- ADR-010 — decision-equivalent recovery.
- ADR-013 — passive Network damage state representation.
- BUG-057 — normal production reconstruction entry.
- CAP-DMG-003 — Ruptured Engine capability.
- Maneuver obstacle consequence lifecycle.

## Disposition

Include in the bounded BUG-043 production-boundary conformance stabilization batch.

The repair must preserve the existing filtering contract. Do not solve the defect by exposing authority-only completion state to passive clients.

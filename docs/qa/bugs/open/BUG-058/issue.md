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
- The Project Owner accepted Alternative A on 2026-09-27; the bounded normative
  amendment is in the BUG-043 workbook and remains pending independent fidelity
  audit and Owner acceptance as implementation authority. Existing gameplay
  ownership and recovery guarantees remain unchanged.

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

Include in the bounded BUG-043 production-boundary conformance stabilization
batch under the accepted 2026-09-27 Owner decision below. Status remains Open:
the architecture decision is accepted, but the amended workbook wording still
requires a passing independent fidelity audit and Owner acceptance before it
is implementation authority. BUG-058 remains pending implementation and
verification; this documentation correction does not close the production defect.

The repair must preserve the existing filtering contract. Do not solve the defect by exposing authority-only completion state to passive clients.

## 2026-09-26 authority stop found during stabilization (historical)

At the stop, the accepted BUG-043 workbook §12.2.2 fixed exact authority and filtered state shapes. It omitted the persistent-card `last_*_execution_id` markers from public faceup cards and `last_maneuver_execution_id` from filtered obstacle placements. The full `obstacle_resolution_order` remained immutable, and completed purpose-specific obstacle records were removed. `InteractionFlow` did not carry a public remaining-consequence identity for this sequence.

Consequently, that schema gave a reconnect snapshot after resolving the first of multiple Ruptured Engine cards (or the first of multiple obstacles) no accepted public field distinguishing that completed instance from an otherwise identical still-pending one. The passive evaluator could not select the correct next instance from the filtered snapshot alone. Copying the authority markers would violate the explicit filtering/privacy contract; inferring them would synthesize authority-only progress. This evidence remains the basis for the repair.

**Former Owner-decision stop resolved on 2026-09-27:** the Owner accepted
Alternative A and the architecture/version allocation referenced below. This
does not accept the amended workbook wording: that separate implementation-
authority gate remains pending a passing independent fidelity audit and explicit
Owner acceptance. No production schema change was made in this documentation
pass. Implementation must still prove filtered reconnect and subsequent ordered
passive application equivalence.

## 2026-09-27 accepted Owner decision and normative allocation

The Project Owner accepted Alternative A as refined by the architecture-risk,
normative-design, and adversarial analyses: preserve decision-equivalent
recovery through a minimum purpose-specific, authority-derived,
viewer-authorized Maneuver consequence projection.

The decision is recorded in the pending normative amendment to the
[BUG-043 workbook](../../../../architecture/implementation_workbooks/BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md).
Its historical acceptance does not accept the current amended wording as
implementation authority. Subject to the audit and Owner acceptance gate, the
amendment specifies:

- Section 1.1 records successor authority and scoped supersession of relevant
  BUG-042 envelope/processing allocation; BUG-042 remains unchanged.
- Sections 12.2.2--12.2.3 define the filtered execution's closed
  `consequence_view` union and required complete `maneuver_consequence_view`
  replacement on every successful live Network semantic-command envelope.
  Existing public faceup-occurrence and obstacle identities are reused and all
  currently legal choices preserved. Damaged Controls exposes every currently
  legal next source at its accepted timing boundary; player source ordering is
  distinct from automatic overlap context and mandatory authority damage.
- Section 15.1 requires centralized capture frozen from the command's committed
  post-state, before callbacks/later commands; individual commands do not opt in
  or derive the view. Passive validation/installation is atomic with the owning
  command, without private-history reconstruction, and includes lifecycle,
  concealment, destruction, retirement, and reconstruction cleanup.
- Section 16 allocates Network protocol 8 after the final repository allocation
  check found no conflict. Save 7, replay 10, application contract 2, and
  passive-ledger schema 1 remain unchanged.
- Sections 19.13 and 20.3 define the implementation STOP and required evidence.

Existing gameplay owners and authority-private completion/execution markers
remain authoritative. No new canonical gameplay owner is introduced.
InteractionFlow may carry derived information but does not own pending
existence, legality, completion, or mutation. No generic pending-work mechanism,
queue/FSM, completion bitmap, generic transaction/rollback/snapshot service,
weakened filtering, or weakened recovery guarantee is authorized.

**Implementation STOP preserved:** if passive atomic validation/installation
cannot be implemented within the accepted command transaction boundary without
new generic transaction, rollback, or snapshot infrastructure, STOP for Owner
review rather than improvise. Any other new Owner decision or conflicting
version/schema requirement likewise requires review. Acceptance of this
allocation does not establish implementation conformance or waive those stops.

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
- The Project Owner accepted Alternative A's consequence representation and
  Option B's passive acceptance boundary on 2026-09-27. The Project Owner
  subsequently explicitly accepted the amended BUG-043 workbook on 2026-09-27
  as implementation authority for the remaining BUG-043 work, including BUG-058.
  Existing gameplay ownership, command-owned failure-atomicity, privacy, ordering,
  and recovery guarantees remain unchanged.

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
- Every independently checkable passive rejection condition rejects before
  canonical mutation. Accepted command application and frozen replacement
  installation/removal precede history/cursor advancement and every success
  observer, with no new input-dependent installation rejection.
- Existing command-owned application failures remain atomic. Authority proves
  semantic completeness from private facts; passive peers neither reconstruct
  that proof nor weaken public validation. Detailed evidence obligations remain
  in BUG-043 Section 20.3.

## Relationships

- BUG-043 — Ship Maneuver Capability Integration / stabilization.
- ADR-010 — decision-equivalent recovery.
- ADR-013 — passive Network damage state representation.
- BUG-057 — normal production reconstruction entry.
- CAP-DMG-003 — Ruptured Engine capability.
- Maneuver obstacle consequence lifecycle.

## Disposition

Include in the bounded BUG-043 production-boundary conformance stabilization
batch under the accepted 2026-09-27 Owner decisions below. Status remains Open:
the architecture directions and amended workbook wording are explicitly
Owner-accepted as implementation authority for the remaining BUG-043 work.
This status record makes no independent fidelity audit result claim. BUG-058
remains pending implementation and verification; this documentation amendment
does not close the production defect or claim implementation conformance.

The [BUG-043 workbook](../../../../architecture/implementation_workbooks/BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md)
is the sole normative implementation specification for this repair under the
explicit 2026-09-27 Owner acceptance and governing accepted ADRs/Contracts. This
issue preserves defect evidence and Owner rationale, not a competing implementation
contract. The current amended wording is accepted by the new explicit Owner
acceptance, not by inference from historical workbook acceptance.

The repair must preserve the existing filtering contract. Do not solve the defect by exposing authority-only completion state to passive clients.

## 2026-09-26 authority stop found during stabilization (historical)

At the stop, the accepted BUG-043 workbook §12.2.2 fixed exact authority and filtered state shapes. It omitted the persistent-card `last_*_execution_id` markers from public faceup cards and `last_maneuver_execution_id` from filtered obstacle placements. The full `obstacle_resolution_order` remained immutable, and completed purpose-specific obstacle records were removed. `InteractionFlow` did not carry a public remaining-consequence identity for this sequence.

Consequently, that schema gave a reconnect snapshot after resolving the first of multiple Ruptured Engine cards (or the first of multiple obstacles) no accepted public field distinguishing that completed instance from an otherwise identical still-pending one. The passive evaluator could not select the correct next instance from the filtered snapshot alone. Copying the authority markers would violate the explicit filtering/privacy contract; inferring them would synthesize authority-only progress. This evidence remains the basis for the repair.

**Former Owner-decision stop resolved on 2026-09-27:** the Owner accepted
Alternative A and the architecture/version allocation referenced below. This
did not itself accept the amended workbook wording. The subsequent explicit
2026-09-27 Owner acceptance now establishes that amended implementation authority.
No production schema change was made in this documentation pass. Implementation
must still prove filtered reconnect and subsequent ordered
passive application equivalence.

## 2026-09-27 accepted Owner decision and normative allocation

The Project Owner accepted Alternative A as refined by the architecture-risk,
normative-design, and adversarial analyses: preserve decision-equivalent
recovery through a minimum purpose-specific, authority-derived,
viewer-authorized Maneuver consequence projection.

The decision is recorded in the explicitly Owner-accepted amendment to the
[BUG-043 workbook](../../../../architecture/implementation_workbooks/BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md).
The explicit 2026-09-27 Owner acceptance establishes the current amended wording
as implementation authority for the remaining BUG-043 work. The amendment
specifies:

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
  or derive the view. As refined by the accepted Option B decision below, all
  independently checkable passive rejection conditions precede mutation;
  command application and installation/removal of the validated replacement
  share one observable acceptance boundary without a new input-dependent
  rejection point. Lifecycle, concealment, destruction, retirement, and
  reconstruction cleanup remain required without private-history reconstruction.
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

## 2026-09-27 implementation STOP and architectural cause

Implementation stopped at the proposed live passive replacement boundary.
The preceding BUG-043 amendment required command application followed by fallible
validation against resulting public state, with rejection restoring canonical
state, installed view, history, cursor, and success effects. Its Section 20.3
required forced failure after tentative canonical application.

The current [CommandProcessor](../../../../../src/autoload/command_processor.gd)
instead executes against live `GameState` and records history/advances the cursor
inside `_execute_and_record()`, before a newly added later check could reject.
There is no enclosing whole-state transaction or rollback mechanism. Moving
history recording later alone would not undo canonical mutation. Command-local
snapshots cover their own transactions, and detached filtered reconstruction
validation covers installation candidates; neither supplies a rollback boundary
for arbitrary late live-command replacement rejection. Inventing such a boundary
was not authorized, so the implementation STOP was required.

The separate semantic limitation is intentional: passive peers lack
authority-private completion/execution markers. Identical public facts can
correspond to different private completion histories and therefore different
correct legal-source sets or current obstacle identities. Post-mutation public
state cannot supply that missing proof. The workbook already assigns semantic
completeness to authority; the conflicting mechanism was its additional
fallible post-application public-consistency gate, not a legitimate requirement
to reproduce private validation.

## 2026-09-27 accepted Option B Owner decision

**Status: accepted architecture direction; amended BUG-043 workbook wording
explicitly accepted by the Project Owner on 2026-09-27 as implementation
authority for the remaining BUG-043 work. BUG-058 remains Open pending
implementation and verification.**

The Project Owner accepted Option B from the architecture analysis: the BUG-058
atomicity requirement was over-specified in mechanism, not in its observable
guarantee. This refines the passive acceptance boundary of the previously
accepted Alternative A consequence representation; those option labels refer
to different decisions, not competing representations.

The decision requires:

- all independently checkable passive rejection conditions to be validated
  before canonical mutation using authorized facts and existing owner boundaries;
- authority-side derivation/semantic validation to retain responsibility for
  completeness and hidden-history-dependent correctness of `consequence_view`;
- the owning command to perform its normal canonical transition after admission,
  followed by installation/removal of the already-validated frozen replacement
  before history, cursor advancement, success signals, presentation, callbacks,
  follow-ups, or subsequent commands can observe success;
- no new input-dependent rejection point in replacement installation;
- unchanged existing command-owned failure-atomicity obligations;
- post-application checks to be diagnostic/assertive only where successful
  prevalidation and command-owned application already guarantee their conditions;
  an otherwise rejectable input cannot be admitted by relabeling its check; and
- STOP for Owner review if a required passive rejection check genuinely cannot
  be completed before mutation using authorized facts and existing owner
  boundaries, or installation introduces a new input-dependent rejection point.

Observable atomicity remains mandatory: rejection leaves passive state, view,
history, cursor and success effects unchanged; success exposes a matching
command state and replacement at the same ordered acceptance boundary. Removing
mandatory late replacement rejection does not permit partial application,
post-success repair, skipped failed sequences, stale replacement reuse, or
weakened convergence. The view remains derived, viewer-authorized recovery
information, never gameplay authority. Authority-private history remains
filtered and is never synthesized by passive peers. Decision-equivalent
reconnect/recovery remains guaranteed, including subsequent ordered application.

The normative implementation wording is in BUG-043 Sections 1.1, 12.2.2--12.2.3,
15.1, 16.2, 19.13, 20.3, and 22, under the recorded explicit Owner acceptance.
No ADR or contract is created or amended. Network protocol 8, Save 7, Replay 10,
application contract 2, and passive-ledger schema 1 remain unchanged.

### Alternatives excluded by the decision

- **Generic transactional execution/rollback/snapshot infrastructure:** not
  authorized. It would broaden the command architecture and still could not
  establish hidden-history-dependent semantic completeness on a passive peer.
- **Maneuver-specific staging:** not authorized as an automatic fallback.
  Staging the view alone cannot undo command mutations; staging all touched
  owners risks expanding into damage, collision targets, displacement, and
  nested consequences. A demonstrated residual check must return for Owner
  review before any separate authorization.
- **Existing mechanisms alone:** ordered buffering, owner-local rollback, and
  detached reconstruction validation remain useful within their accepted scopes,
  but do not satisfy the former added late-rejection requirement by themselves.

**Implementation STOP retained under Option B:** return any residual required
check to the Owner rather than introducing rollback or staging, reconstructing
private history, or weakening validation. Existing command-owned atomicity is
not waived. The accepted direction resolves the architecture choice that
prompted the STOP; it does not demonstrate implementation feasibility. The
Project Owner subsequently explicitly accepted the amended workbook as
implementation authority on 2026-09-27. This status record does not claim an
independent fidelity audit result, implementation, or verification. All residual
technical STOP conditions remain in force. Any conflicting architecture,
schema, or version requirement also requires Owner review.

# BUG-055 — Immediate-Effect Presentation Adapter Uses Stale Branch Semantics

**Status:** Open

## Summary

The Attack/debug immediate-effect presentation path still uses legacy descriptor/branch assumptions that do not conform to the current canonical immediate-effect command contract.

Several concrete edge cases can therefore produce the wrong interaction shape or an invalid semantic payload.

## Observed Behavior

The production immediate-effect presentation/helper path retains stale assumptions about when an effect is automatic versus choice-driven and which branch-specific payload fields are required.

The production-boundary reassessment identified these mismatches:

1. Injured Crew with exactly one eligible defense token:
   - the resolver opens a choice;
   - the helper adds `defense_token_index`;
   - canonical validation permits that field only when multiple eligible tokens require a choice.

2. Comm Noise with neither speed nor dial available:
   - the empty-choice helper omits the required
     `comm_noise_action: "none"` payload value.

3. Comm Noise with only speed available:
   - presentation treats the effect as an opponent choice;
   - canonical authority classifies the branch as automatic.

These are representation/branch-conformance failures between the existing immediate-effect descriptor/helper and the current command contract.

## Expected Behavior

The presentation/helper layer must reflect the canonical immediate-effect branch already determined by existing authority.

Automatic branches must remain automatic.

Choice branches must expose only genuine legal choices.

The semantic payload produced by each branch must contain exactly the fields required by the existing canonical command contract.

In particular:

- single-option Injured Crew must follow the existing canonical single-option semantics rather than manufacturing a multi-option choice payload;
- Comm Noise with no speed or dial choice must preserve the required `"none"` action;
- speed-only Comm Noise must follow its existing automatic semantics.

## Classification

Production integration / immediate-effect presentation-to-command adapter defect.

This is a demonstrated production defect, not merely missing evidence.

## Architecture / Authority Constraints

- Preserve ADR-014 and the existing immediate-effect command/rule ownership.
- Preserve canonical automatic-versus-choice classification.
- Do not move rule branching into presentation.
- Do not weaken canonical payload validation.
- Do not introduce a second immediate-effect lifecycle.
- Do not create a generic decision framework.
- No new architecture decision is currently identified.

## Evidence

Identified during the BUG-043 production-boundary conformance reassessment.

The current immediate-effect descriptor/helper and canonical validator disagree on concrete Injured Crew and Comm Noise branches.

The reassessment also identified adjacent immediate-result visual consumption as a risk requiring focused verification, but that risk is not itself assumed to be part of this demonstrated defect unless execution proves it.

## Acceptance Criteria

- Exactly-one-option Injured Crew follows the canonical branch and produces a valid payload.
- Comm Noise with neither speed nor dial available produces the canonical `"none"` action.
- Speed-only Comm Noise follows the existing automatic branch and does not expose a false opponent choice.
- Genuine multi-option branches remain interactive where required.
- Canonical validators remain strict.
- No presentation path synthesizes gameplay authority or silently changes the canonical branch.

## Relationships

- BUG-043 — Ship Maneuver Capability Integration / stabilization.
- ADR-014 — Canonical Immediate Faceup Damage-Card Resolution.
- CAP-DMG-007 — Injured Crew capability.
- CAP-DMG-009 — Comm Noise capability.

## Disposition

Include in the bounded BUG-043 production-boundary conformance stabilization batch.

Repair the existing descriptor/helper adapters only. Adjacent visual-consumer behavior should be verified separately and repaired only if focused evidence demonstrates an actual failure.

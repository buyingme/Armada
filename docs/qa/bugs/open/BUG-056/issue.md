# BUG-056 — Recovered Squadron Displacement Payload Retains JSON Numeric Types

**Status:** Open

## Summary

A saved pending Squadron displacement interaction can be restored far enough to appear structurally valid, but nested identity fields in the recovered interaction payload retain JSON numeric representation instead of the canonical integer representation required by the production submission adapter.

As a result, a recovered displacement decision cannot be submitted successfully.

## Observed Behavior

Save-7 deserialization normalizes the InteractionFlow envelope, including its enum/controller fields.

However, nested displacement payload identities such as:

- `owner_player`
- `ship_index`

remain JSON numeric values after deserialization.

The production `submit_commit_displacement()` adapter requires canonical integer values and rejects the recovered values before the semantic command can be constructed.

Previous recovery evidence verified the flow envelope and evaluator waiting state, but did not prove successful submission of the recovered displacement decision.

## Expected Behavior

A valid signed Save-7 round-trip must restore the nested displacement identity fields into the canonical representation expected by the existing submission contract.

After recovery:

- its canonical player/ship identities must be preserved;
- a legal selection must submit successfully through the normal production adapter;
- invalid or fractional identities must remain rejected.

## Classification

Production persistence/recovery adapter defect.

This is a demonstrated production defect, not merely missing evidence.

## Architecture / Authority Constraints

- Preserve strict canonical integer identity semantics.
- Normalize representation at the appropriate deserialization/recovery boundary.
- Do not weaken command/submission validation to accept arbitrary JSON floats.
- Preserve existing InteractionFlow purpose-specific ownership.
- Do not introduce a generic migration layer solely for this interaction.
- Preserve Save-7 compatibility requirements from the accepted BUG-043 workbook.
- No new architecture decision is currently identified.

## Evidence

Identified during the BUG-043 production-boundary conformance reassessment after BUG-052 repaired the known Maneuver/immediate/obstacle integer restoration paths.

The remaining displacement-specific nested payload fields are not normalized by `InteractionFlow.deserialize()`, while the downstream production submission adapter explicitly requires integer identities.

The existing V5 evidence checked restored state and waiting semantics but did not submit the recovered displacement decision through this adapter.

## Acceptance Criteria

- A valid pending displacement interaction survives a signed Save-7 round-trip.
- Recovered `owner_player` and `ship_index` have the canonical integer representation required by production submission.
- A legal displacement confirmation successfully traverses the normal submission adapter and canonical command validation.
- Fractional/non-finite/otherwise invalid identities remain rejected.
- No unrelated InteractionFlow payload semantics are broadened.

## Relationships

- BUG-043 — Ship Maneuver Capability Integration / stabilization.
- BUG-052 — related Save-7 numeric restoration defect.
- ADR-010 — decision-equivalent recovery.
- Squadron displacement Maneuver consequence path.

## Disposition

Include in the bounded BUG-043 production-boundary conformance stabilization batch.

Repair the existing recovery/deserialization handoff and prove actual resumed submission, not merely successful deserialization.

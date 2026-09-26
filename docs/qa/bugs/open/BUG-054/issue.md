# BUG-054 — Thruster Fissure Source Identity Is Lost During Maneuver Confirmation

**Status:** Open

## Summary

During Maneuver consequence resolution, the Thruster Fissure evaluator derives the applicable public damage-card reference, but the presentation-to-command adapter does not preserve that identity when the player confirms the required hull-zone choice.

As a result, a genuine modal confirmation cannot construct the canonical Thruster Fissure resolution payload required by command validation.

## Observed Behavior

The Maneuver execution evaluator exposes the applicable Thruster Fissure identity through `public_card_refs`.

The pending action/modal path presents the required choice, but confirmation adds only the selected `hull_zone`.

The required `public_card_ref` is not transferred into the semantic command payload.

A genuine confirmation therefore reaches the command boundary without the source-card identity required by the canonical command contract.

Existing controller evidence can miss the defect because the test supplies the missing card reference directly rather than proving that the production presentation adapter carries it from evaluator output into the command.

## Expected Behavior

The existing Maneuver consequence path must preserve the authoritative public identity of the Thruster Fissure instance from evaluation through presentation and confirmation into the semantic command payload.

The presentation adapter must carry the applicable source identity supplied by the evaluator.

A genuine modal confirmation must produce a payload satisfying the existing Thruster Fissure command contract, including the applicable `public_card_ref` and selected `hull_zone`.

## Classification

Production integration / presentation-to-command adapter defect.

This is a demonstrated production defect, not merely missing evidence.

## Architecture / Authority Constraints

- Preserve existing Thruster Fissure ownership and canonical command validation.
- Preserve the existing public damage-card identity model.
- Do not introduce a parallel damage-card identity representation.
- Do not move gameplay authority into the UI.
- Do not weaken command validation to tolerate a missing source identity.
- No new architecture decision is currently identified.

## Evidence

Identified during the BUG-043 production-boundary conformance reassessment.

The evaluator provides `public_card_refs` separately from a payload that lacks `public_card_ref`.

The Maneuver presentation adapter does not transfer the selected/required reference into the command payload.

The canonical Thruster Fissure command requires one `public_card_ref:String`.

Existing controller testing injects the missing reference directly, while earlier composed-path evidence constructs the command directly, so neither proves the genuine confirmation seam.

## Acceptance Criteria

- A genuine Thruster Fissure Maneuver consequence reaches the normal modal through the production projection path.
- The applicable public card identity is preserved through that interaction.
- Confirming a legal hull zone produces the existing canonical command payload with the correct `public_card_ref` and `hull_zone`.
- Strict command validation accepts the correctly adapted payload.
- Invalid/stale card identities remain rejected.
- No duplicate or synthetic damage-card identity authority is introduced.

## Relationships

- BUG-043 — Ship Maneuver Capability Integration / stabilization.
- BUG-051 — related presentation-adapter conformance defect.
- BUG-053 — related presentation-to-command representation defect.
- CAP-DMG-001 — Thruster Fissure capability.
- ADR-010 — decision-equivalent recovery.

## Disposition

Include in the bounded BUG-043 production-boundary conformance stabilization batch.

Repair only the existing adapter/identity handoff. Do not broaden into generic interaction infrastructure.

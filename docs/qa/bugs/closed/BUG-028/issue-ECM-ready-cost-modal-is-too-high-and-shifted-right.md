# BUG-028 — ECM ready-cost modal is too high and shifted right

Severity: Low
Area: Status Phase / ECM UI
Layer: Presentation

## Expected

The Electronic Countermeasures ready-cost modal should be positioned consistently within the viewport and use the standard modal alignment.

The modal should remain visually centered and fully accessible regardless of player perspective or repeated use.

## Actual

The Electronic Countermeasures ready-cost modal appears too high on the screen and shifted to the right.

The issue is visual only. No associated failure of ECM ready-cost gameplay resolution was observed.

## Reproduction

Observed during the Status Phase of the 2026-08-14 network/Tarkin smoke test.

1. Exhaust Electronic Countermeasures.
2. Reach Status Phase cleanup.
3. Trigger the optional ECM ready-cost interaction.
4. Observe the ECM ready-cost modal.

Result:
- modal is positioned too high;
- modal is shifted to the right.

## Evidence

- Associated 2026-08-14 annotation and gameplay log.

The captured state is in Status Phase cleanup and concerns presentation of the ECM ready-cost interaction.

## Initial Assessment

Presentation-only.

Potential investigation areas:

- modal anchors;
- offsets;
- viewport centering;
- reusable modal positioning;
- player-perspective transforms;
- accumulated position offsets on reused modal instances.

Compare with other modal-position defects observed during the same test batch, including BUG-026.

Do not merge the issues unless investigation establishes a shared root cause.

## Resolution

Root cause:

`ECMReadyCostModal.centre_on_screen()` positioned the modal from its configured
`custom_minimum_size`. Dynamic content changed the actual rendered `size`, so
the position calculation used dimensions smaller than the visible modal and
placed its center high and to the right. Reuse repeated the mismatched
calculation.

Fix:

The modal now retains only the requested viewport size as transient layout
input and performs a deferred reset/centering pass from its actual rendered
size. Reopening runs the same idempotent layout pass. No canonical position,
visibility field, command, or gameplay state was introduced.

## Verification

Verify that:

- the ECM ready-cost modal is correctly centered/positioned;
- it remains fully within the viewport;
- repeated openings do not cause position drift;
- both player perspectives render it correctly;
- hot-seat and network presentation remain correct.

Automated regression evidence in `tests/unit/test_modal_router.gd` opens the
real ECM Status ready-cost modal, centers it against a fixed viewport, proves
both rendered axes are centered, then repeats the operation and proves there is
no accumulated drift.

Verification on 2026-08-14:

- focused `test_modal_router.gd`: 29/29 passed;
- focused ECM ready-cost command suite: 23/23 passed;
- full suite: 237 scripts, 4057/4057 tests, 13573 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches.

The repaired layout is ready for Project Owner/manual Hot-Seat and Network
verification.

# BUG-026 — Attack result modal is too wide and shifted

Severity: Low
Area: Combat UI / Attack Result
Layer: Presentation

## Expected

The attack result modal should be sized appropriately for its content and remain correctly positioned within the game viewport.

It should use the same stable modal positioning behavior across repeated attacks and for both player perspectives.

## Actual

The attack/result modal displayed to the attacker is too wide and appears shifted from its intended position.

The issue is visual only. No gameplay-state or attack-resolution failure was observed in association with the modal position.

## Reproduction

Observed during manual network gameplay.

1. Perform an attack.
2. Progress through the attack until the attack/result modal is displayed.
3. Observe the modal on the attacker's screen.

Result:
- the modal is wider than necessary;
- the modal is visibly shifted from its intended position.

## Evidence

- Associated annotation and gameplay log from the 2026-08-14 Tarkin/network smoke test.

## Initial Assessment

The defect appears presentation-only.

Potential investigation areas:
- modal sizing;
- anchors and offsets;
- reusable modal positioning;
- viewport-relative centering;
- whether repeated modal reuse accumulates position offsets.

The fix must not introduce gameplay-state or command-flow changes.

## Resolution

Root cause:

The reusable `AttackSimPanel` allowed its unwrapped dynamic title to enlarge
the panel's horizontal minimum size. Its deferred reuse/layout reset restored
only vertical size and offsets, so the enlarged width and horizontal shift
survived into the attack-result presentation and later attacks.

Fix:

The dynamic title now wraps and expands within the intended panel width, and
the existing deferred layout reset restores both horizontal size and symmetric
offsets from `custom_minimum_size`. The change is confined to local layout; no
gameplay or modal-position state was added.

## Verification

Verify that:

- the attack/result modal uses an appropriate width;
- the modal is correctly positioned;
- repeated attacks do not cause position drift;
- both player perspectives display the modal correctly;
- hot-seat and network presentation remain correct.

Automated regression evidence in `tests/unit/test_attack_sim_panel.gd` uses
long attacker/defender result titles, waits for the real deferred layout pass,
and proves the rendered width returns to the intended width and remains
centered. The same production panel is used by attacker and mirrored defender
views.

Verification on 2026-08-14:

- focused `test_attack_sim_panel.gd`: 65/65 passed;
- focused network/result projection and production resume suites:
  24/24 and 44/44 passed;
- full suite: 237 scripts, 4057/4057 tests, 13573 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches.

The repaired layout is ready for Project Owner/manual Hot-Seat and Network
verification.

# BUG-027 — Repair token spent but VSD shield recovery appears not to resolve

Severity: Medium
Area: Ship Commands / Repair
Layer: Gameplay | Presentation

## Expected

When a valid Repair token is spent and the player uses the available engineering points to recover shields, the selected shield recovery must be applied to authoritative ship state.

The resulting shield values must then be reflected immediately in the UI.

## Actual

During manual gameplay with the Victory II-class Star Destroyer, a Repair token was spent, but the intended shield repair appeared not to take place.

It is currently unclear whether:

- the authoritative shield recovery failed;
- the Repair resolution was only partially committed; or
- the authoritative state changed correctly but the UI failed to refresh.

## Reproduction

Observed once during the 2026-08-14 network/Tarkin smoke test.

1. Activate the Victory II-class Star Destroyer.
2. Resolve a Repair token.
3. Use the Repair effect to recover shields.
4. Observe the resulting VSD shield values.

Result:
- the Repair token is spent;
- the expected shield recovery does not appear to have occurred.

## Evidence

- Associated annotation from 2026-08-14.
- Associated gameplay log.

The annotation was captured in Round 3 during the VSD activation.

At capture time the authoritative VSD state shows:

- FRONT: 1 shield
- LEFT: 0 shields
- REAR: 1 shield
- RIGHT: 1 shield

The captured state alone does not establish the shield values immediately before Repair resolution and therefore does not yet prove whether the defect is authoritative gameplay resolution or presentation refresh.

## Initial Assessment

Root cause is unknown.

Investigate before modifying behavior.

Potential investigation areas:

- Repair-token command resolution;
- engineering-point allocation;
- shield-recovery command/state mutation;
- command-token consumption ordering;
- ship-state projection after Repair resolution;
- UI refresh after shield mutation.

Do not change Repair gameplay semantics solely from the visual symptom. First determine whether canonical shield state is incorrect or only its presentation is stale.

## Resolution

Root cause:

The original observation did not represent a canonical Repair failure. The
production transition at `repair_action` sequence 293 recovered the VSD front
shield from 0 to 1 exactly once; the later captured canonical state contains
that value, and the Repair token was spent once at sequence 294.

The defect was the mirrored presentation route. For accepted `repair_action`
results, `GameManager._handle_remote_repair_action()` emitted unrelated
defense-token or command-dial events. Shield and hull consumers therefore did
not receive the canonical result needed to refresh their displays.

Fix:

The remote accepted-result handler now consumes the existing command result
and emits the established `ship_shields_changed` events for source/destination
or recovered zones, and `ship_hull_changed` for hull repair. It reads the
already-mutated `ShipInstance`; it does not repeat Repair mutation or alter
Repair validation, engineering-point rules, command ownership, or serialized
state.

## Verification

After repair/investigation, verify:

- spending a Repair token consumes exactly one valid Repair token;
- selected shield recovery mutates canonical shield state exactly once;
- the UI immediately reflects the resulting canonical shields;
- Repair dial and Repair token resolution remain correct;
- hot-seat and network results are equivalent;
- replay/save-load preserve the resulting authoritative state.

Automated regression evidence in `tests/unit/test_repair_action_command.gd`
proves the canonical shield transition is 0 -> 1 before projection, the
mirrored accepted result emits exactly one `ship_shields_changed(ship,
"FRONT", 1)`, and projection does not mutate the shield a second time.

Verification on 2026-08-14:

- focused `test_repair_action_command.gd`: 23/23 passed;
- focused `test_repair_resolver.gd`: 37/37 passed;
- full suite: 237 scripts, 4057/4057 tests, 13573 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches.

Canonical Repair behavior is confirmed correct; the repaired presentation is
ready for Project Owner/manual Hot-Seat and Network verification.

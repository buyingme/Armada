# BUG-029 — Repair token display does not refresh after paying ECM ready cost

Severity: Low
Area: Ship UI / Command Tokens / ECM
Layer: Presentation / Projection

## Expected

When a Repair command token is spent to ready Electronic Countermeasures during Status Phase cleanup:

- the Repair token must be removed from authoritative ship state;
- ECM must become readied;
- the ship UI must immediately stop displaying the spent Repair token.

The displayed command-token state must remain synchronized with authoritative ship state without requiring another interaction or phase transition.

## Actual

The Repair token is correctly consumed and Electronic Countermeasures is correctly readied in authoritative game state, but the CR90 UI continues to display the spent Repair token.

The gameplay effect therefore succeeds while the presentation remains stale.

## Reproduction

Observed during the 2026-08-14 network/Tarkin smoke test.

1. Have an exhausted Electronic Countermeasures upgrade on the CR90.
2. Retain a Repair command token.
3. Reach Status Phase cleanup.
4. Spend the Repair token to ready ECM.
5. Continue into the next round.
6. Observe the CR90 command-token display.

Result:
- ECM has been readied;
- authoritative CR90 command-token state no longer contains the Repair token;
- the UI still displays the Repair token.

## Evidence

- Associated 2026-08-14 annotation and gameplay log.

The captured authoritative state confirms:

- CR90 `command_tokens.tokens = []`;
- Electronic Countermeasures `exhausted = false`;
- Electronic Countermeasures `readied = true`.

This establishes that the underlying gameplay mutation succeeded.

The remaining defect is presentation/projection refresh of the ship's displayed command tokens.

## Initial Assessment

The defect is presentation/projection only.

Potential investigation areas:

- ship UI refresh after command-token mutation outside normal ship activation;
- Status Phase projection refresh;
- command-token display caching;
- transition from Status Phase to the next Command Phase;
- whether ship UI refresh is triggered only by normal command-token acquisition/spending paths.

Compare with other known stale ship-state presentation defects before introducing a new refresh mechanism.

Canonical game state must remain the source of truth.

## Resolution

Root cause:

The issue's canonical-state assessment was correct. `ReadyECMCommand` spent
the Repair token and readied the ECM runtime upgrade exactly once. The missing
boundary was local accepted-result projection: synchronous Hot-Seat/host
submission continued Status cleanup but did not emit the ship token/card
refresh events. A separate remote-result handler had the needed behavior, so
local and mirrored paths were inconsistent.

Fix:

The existing remote refresh behavior was factored into one public
accepted-result projector. Both a synchronous accepted Status ready-cost
choice and the mirrored client result now resolve the canonical ship from the
result and emit the established command-token and ship-card refresh events.
Invalid/incomplete non-production results are ignored safely. The projector
does not spend a token or ready ECM; those mutations remain command-owned.

## Verification

After repair, verify:

- spending the Repair token removes it from canonical state exactly once;
- ECM becomes readied exactly once;
- the Repair token disappears from the ship UI immediately;
- no additional interaction is required to refresh the display;
- other command-token spending paths continue to refresh correctly;
- both host and client show the same token state;
- hot-seat behavior remains correct;
- save/load, reconnect, and replay reconstruct the correct display from canonical state.

Automated regression evidence proves that the production GameManager ready
path emits one token refresh and one card refresh after the one canonical
spend, and that `ShipCardPanel` immediately removes the token graphic by
re-reading the canonical `CommandTokenPool`. Mirrored projection uses the same
projector.

Verification on 2026-08-14:

- focused `test_ecm_status_ready_cost_command.gd`: 23/23 passed;
- focused `test_ship_card_panel.gd`: 26/26 passed;
- focused modal/router suite: 29/29 passed;
- full suite: 237 scripts, 4057/4057 tests, 13573 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches.

The repaired projection is ready for Project Owner/manual Hot-Seat and Network
verification.

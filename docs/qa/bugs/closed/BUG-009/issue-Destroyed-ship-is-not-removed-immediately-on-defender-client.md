# BUG-009 — Destroyed ship is not removed immediately on defender client

Severity: Medium
Area: Network / Ship Destruction
Layer: Presentation / Projection

## Expected

When a ship is destroyed by an accepted attack:

1. canonical game state must mark the ship destroyed;
2. all peers must receive the authoritative result;
3. the destroyed ship must be removed or otherwise shown as destroyed on both
   attacker and defender screens without requiring another gameplay event or
   manual refresh.

The defender's local presentation must derive from the same accepted canonical
state as the attacker.

## Actual

The CR90 Corvette A reached destruction during an attack.

On the attacker's screen, the CR90 was correctly shown as destroyed.

On the defender's screen, the CR90 was not shown as destroyed immediately.

The first observation therefore appeared to show a ship surviving at zero hull,
but a follow-up observation established that destruction had occurred
canonically and was already visible to the attacker.

The defect is therefore a stale defender/client presentation rather than an
obvious failure of canonical destruction.

## Reproduction

Observed during network play.

1. Attack the CR90 until the attack destroys it.
2. Observe the attacker screen.
3. Observe the defender screen immediately after the accepted destruction.

Result:

- attacker: CR90 is shown destroyed;
- defender: CR90 remains visible / does not immediately reflect destruction.

## Evidence

- `annotation_20260804_221638_001.json`
- `annotation_20260804_221817_002.json`

### First observation

The first annotation states:

`Another bug the CR90 was not destroyed at 0 hull.`

The captured state already contains:

- `destroyed = true` for the CR90;
- lethal accumulated damage;
- no active `CurrentAttackState`.

This means the canonical snapshot itself does not support the interpretation
that destruction failed.

### Follow-up observation

The second annotation clarifies:

`on the attacker screen the CR90 was actually destroyed. only on defender
screen this is not showing up right away.`

This narrows the issue to presentation/projection synchronization on the
defender side.

## Initial Assessment

The evidence strongly suggests a remote/client presentation refresh defect.

Likely investigation areas include:

- mirrored attack/damage result handling;
- destruction notification propagation;
- ship-scene removal or visibility refresh on the defending client;
- whether local attack resolution emits a destruction/ship-refresh signal that
  the mirrored client path does not emit;
- ordering between canonical damage installation and presentation refresh;
- whether destruction is projected only after a later unrelated board refresh.

The canonical `destroyed` state must remain authoritative.

Do not repair this by introducing separate client-owned destruction state or UI
state into `GameState`.

### Architecture Constraint

Ship destruction is canonical gameplay state.

The repair should therefore follow:

authoritative damage/destruction command
→ accepted/mirrored canonical state
→ derived ship presentation refresh/removal

The defender client must not independently infer, predict, or authoritatively
mark destruction.

Likewise, presentation state such as `ship_visible`, `destroyed_marker_visible`,
or equivalent UI flags should not become new canonical gameplay fields solely
to fix this refresh issue.

If investigation shows that the canonical destruction result itself is not
being distributed correctly, stop and report that separately rather than
masking the problem with local UI mutation.

## Relationship to BUG-019

BUG-009 and BUG-019 may share a presentation-refresh seam.

BUG-009:
- accepted ship destruction is not reflected immediately on the defender client.

BUG-019:
- ship damage display does not refresh immediately after collision damage.

Both suggest that some remote damage/destruction paths may fail to trigger the
same presentation refresh used by local paths.

Keep the issues separate for traceability, but investigate them together when
the Presentation / Projection batch is implemented.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- lethal attack marks the ship destroyed canonically;
- attacker presentation updates immediately;
- defender presentation updates immediately;
- destroyed ship is removed/hidden consistently on both peers;
- no duplicate destruction processing occurs;
- non-lethal damage still refreshes correctly;
- destruction caused by attack, collision, critical effect, and other damage
  transactions all use the correct projection path;
- Hot-Seat behavior remains correct;
- replay/reconnect reconstruct destroyed ships correctly;
- BUG-019 regression remains green.

## Implementation Update — 2026-08-14

Confirmed root cause:

Mirrored `ResolveDamageCommand` correctly installed canonical damage and
destruction, but remote presentation attempted to send a `ShipInstance`
through the token-typed `ship_destroyed` event. `GameBoard` had no canonical
instance destruction-refresh route, so the defender's board token remained.
The card/sidebar/score refreshes were likewise tied to the local token event.

Exact production failure path:

lethal attack accepted on authority -> mirror executes and marks defender
`ShipInstance` destroyed -> remote handler has the canonical instance but no
usable board-token refresh -> defender presentation stays active until an
unrelated rebuild.

Implemented fix:

- Accepted/mirrored hull projection now drives board-token retirement by
  resolving the local token from the canonical `ShipInstance`.
- Ship card, activation sidebar, and phase HUD re-read canonical state at the
  same projection boundary.
- Loaded destroyed ships are not recreated as board pieces.
- A transient token-node marker makes the local and mirrored fade routes
  idempotent; it is never consulted for gameplay authorization.

Architecture Constraint compliance:

Destruction remains command-owned canonical `ShipInstance` state. The repair
does not predict destruction, add client-owned visibility/destruction state,
or submit a semantic transition from presentation.

Regression evidence:

- `test_remote_lethal_hull_projection_removes_destroyed_ship_token` proves the
  defender-side token is retired from canonical destruction.
- `test_accepted_lethal_damage_projection_ghosts_without_magnification`
  proves immediate card projection.
- BUG-019 mirrored collision refresh and pending-result regressions also pass.

Verification:

- focused board/card/damage suites: 8/8, 25/25, and 29/29 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: repaired by automated evidence; ready for Project Owner/manual
attacker/defender Network verification.

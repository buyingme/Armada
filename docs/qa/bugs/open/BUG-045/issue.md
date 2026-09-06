# BUG-045 — Destroyed Squadrons Remain Visible On Host Board

Severity: High
Area: Squadron Destruction / Board Projection
Layer: Projection

## Expected

Once squadron destruction has been accepted authoritatively, a squadron with
`destroyed = true` must no longer remain presented as an active board piece.

Host and client presentation must update from the same canonical destruction
state.

## Actual

During Network play, two squadrons that had just been destroyed remained visible
on the host board.

The captured authoritative state already marks destroyed squadrons with:

- `destroyed = true`
- `current_hull = 0`

This indicates that destruction occurred canonically but the host board did not
immediately remove or hide the corresponding squadron presentation.

## Reproduction

1. Start a Network game.
2. Destroy one or more squadrons through normal combat.
3. Observe the host board immediately after authoritative destruction.

Result:
Destroyed squadron pieces remain visible on the host board.

Frequency: Once observed; two destroyed squadrons affected in the same run.

## Evidence

- `annotation_20260906_065933_005.json`
- `game_20260906_063022.log`

The annotation states:

`On host screen two squadrons that have just been destroyed remain visible.`

The captured game state already marks destroyed squadron instances as destroyed
with zero hull.

## Initial Assessment

The evidence supports a projection/presentation refresh failure, not failure of
canonical destruction.

Investigate:

- authoritative squadron-destruction result application;
- host-side destruction/removal notifications;
- squadron board-piece refresh/removal;
- whether destruction during anti-squadron attacks uses the same refresh path as
  other squadron damage;
- ordering relative to completed-attack acknowledgement and continuation.

Relationship to BUG-006 should be checked but not assumed:

- BUG-006 concerns destroyed squadrons reappearing after save/load.
- BUG-045 concerns already-destroyed squadrons remaining visible immediately
  after live Network destruction.

Do not add separate UI-owned destruction state.

## Resolution

Root cause:

Fix:

Verification:

- Destroy a squadron in live Network combat.
- Verify canonical `destroyed = true`.
- Verify the piece disappears immediately from host and client boards.
- Destroy multiple squadrons in succession.
- Verify no stale selectable/collidable board nodes remain.
- Verify completed-attack acknowledgement still behaves correctly.
- Verify Hot-Seat, reconnect, save/load, and replay projection remain correct.

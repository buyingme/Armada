# BUG-007 — Destroyed squadron position still blocks later squadron placement

Severity: Medium
Area: Squadron Displacement / Placement
Layer: Gameplay / Geometry

## Expected

Once a squadron is destroyed and removed from play, its former board position
must no longer participate in placement, overlap, collision, or displacement
validation.

A displaced squadron should be allowed to occupy that location if no other
currently active ship, squadron, obstacle, or applicable placement rule blocks it.

## Actual

After a squadron is destroyed, another squadron being displaced cannot be
placed in the location previously occupied by the destroyed squadron.

The destroyed squadron therefore appears to continue influencing placement
legality even though it is no longer an active game piece.

## Reproduction

Observed once.

1. Destroy a squadron.
2. Later cause another squadron to be displaced.
3. Attempt to place the displaced squadron in the former position of the
   destroyed squadron.

Result:

- the position is rejected / unavailable;
- the destroyed squadron's former location appears to remain blocked.

## Evidence

- `annotation_20260804_220955_001.json`

The captured canonical state includes a TIE Fighter Squadron with:

- `current_hull = 0`
- `destroyed = true`

The annotation records:

`I realized that after displacing a squadron the squadron cannot be placed in a spot where there was a destroyed squadron before.`

## Initial Assessment

Root cause is unknown.

Likely investigation areas include:

- displacement placement validation;
- squadron overlap/collision queries;
- board-object enumeration used by placement legality;
- whether destroyed squadrons remain in scene-level spatial collections;
- whether gameplay geometry queries filter by `destroyed`;
- stale collision shapes or scene nodes after destruction.

The fix should not remove destroyed squadrons from canonical history if the game
still needs them for replay/save/history purposes.

Instead, destroyed entities should be excluded from live spatial occupancy and
placement legality wherever the rules require them to be out of play.

## Relationship to BUG-006

BUG-006 and BUG-007 may share a lower-level destroyed-entity filtering problem,
but they represent different failures.

BUG-006:
- destroyed squadrons reappear after save/load reconstruction.

BUG-007:
- destroyed squadrons affect live displacement/placement legality.

Keep them separate unless investigation proves one common root cause and one
repair closes both.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- destroyed squadron positions no longer block displacement placement;
- living squadrons still block placement where appropriate;
- ships and obstacles still participate correctly in placement legality;
- destroying a squadron removes it from live spatial occupancy immediately;
- save/load does not reintroduce destroyed spatial blockers;
- replay and network mirrors produce equivalent placement legality;
- BUG-006 behavior is checked separately.

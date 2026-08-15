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

Reproduced at least twice during separate manual observations.

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

### Additional Reproduction — 2026-08-15

BUG-007 was reproduced again during Round 2 Squadron Phase.

Annotation:

`Here it happened again. a destroyed tie squaron blocks my ie squaron move.`

Evidence:

- `annotation_20260815_081759_002.json`

At the captured state:

- the game is in Squadron Phase;
- Player 1 is the canonical Squadron Phase controller;
- one TIE Fighter Squadron is canonically destroyed:
  - `current_hull = 0`
  - `destroyed = true`
- the destroyed squadron still has a retained canonical board position;
- other TIE Fighter Squadrons are actively being moved/activated;
- the player reports that the destroyed TIE's former position blocks another
  TIE Fighter's movement/placement.

This independently reproduces the original BUG-007 symptom and increases
confidence that the problem is persistent rather than a one-off interaction
failure.

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

The new reproduction makes destroyed-entity participation in live spatial
queries the leading investigation area.

The presence of a retained position on the destroyed SquadronInstance is not
itself necessarily incorrect: canonical position/history may legitimately be
retained for replay, scoring, save/load, or historical purposes.

The important invariant is that an entity with `destroyed = true` must no
longer contribute live spatial occupancy wherever the rules consider it
removed from play.

Investigation should therefore identify the exact placement/overlap query that
still consumes the destroyed squadron rather than solving the problem by
deleting its canonical position or removing it from serialized history.

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

# BUG-038 — Voluntary Anti-Squadron Finish Skips Remaining Ship Attack Opportunity

Severity: Medium
Area: Ship Attack / Anti-Squadron Attack
Layer: Command Flow / Attack Opportunity Semantics

## Expected

After a ship performs an anti-squadron attack from one hull zone, the controller
may voluntarily stop making further anti-squadron attacks from that current
anti-squadron hull-zone sequence without automatically forfeiting a distinct,
still-legal remaining Ship Attack opportunity.

If the ship still has another legal Ship Attack available from another unused
hull zone, finishing the current anti-squadron sequence should return to the
enclosing Ship Attack opportunity so the controller can either:

- declare another legal Ship Attack; or
- voluntarily finish the remaining Ship Attack opportunity.

Finishing the current anti-squadron sequence must not implicitly mean
"finish all remaining Ship Attacks" unless that is the explicit authoritative
semantic chosen by the player.

## Actual

During Hot-Seat manual QA, voluntarily skipping a further anti-squadron attack
after one anti-squadron child attack caused the entire remaining Ship Attack
opportunity to end automatically.

This was reproduced independently with:

- a Victory II-class Star Destroyer; and
- a CR90 Corvette A.

In both reproductions:

- one ship attack had been committed;
- only hull zone `0` was recorded as used;
- `CurrentAttackState` was inactive at the captured post-skip state;
- the remaining Ship Attack opportunity was not presented;
- gameplay advanced directly to Maneuver.

The captured canonical state therefore shows that the ship still had only one
committed attack / one used hull zone when the Attack step had already been
closed.

## Reproduction

### Reproduction A — Victory II-class Star Destroyer

1. Activate the Victory II-class Star Destroyer during Ship Phase.
2. Declare and resolve an anti-squadron attack from one hull zone.
3. After that child attack completes, reach the recovered anti-squadron choice
   while another legal squadron target remains.
4. Choose to stop/skip further anti-squadron attacks from the current sequence.
5. Observe the subsequent Ship Attack interaction.

Actual result:

The current anti-squadron sequence ends, but the enclosing Ship Attack step also
ends immediately and Maneuver becomes `OPEN`, even though another Ship Attack
opportunity from another hull zone should still be available.

### Reproduction B — CR90 Corvette A

Repeat the same sequence with the CR90.

Actual result:

The same behavior occurs: after voluntarily skipping the next anti-squadron
attack, no second-hull-zone Ship Attack opportunity is offered and gameplay
advances to Maneuver.

Frequency: 2/2 observed reproductions across two different ships.

## Evidence

- `annotation_20260823_123648_001.json`
- `annotation_20260823_123825_002.json`
- `game_20260823_122846.log`

### Annotation A — Victory II-class Star Destroyer

The captured state shows, after the voluntary anti-squadron finish:

- `current_attack_state.active == false`;
- `committed_attack_count == 1`;
- `used_attack_hull_zones == [0]`;
- `maneuver_opportunity_disposition == "OPEN"`.

The ship therefore reached Maneuver after only one committed attack / one used
hull zone.

### Annotation B — CR90 Corvette A

The captured state reproduces the same shape:

- `current_attack_state.active == false`;
- `committed_attack_count == 1`;
- `used_attack_hull_zones == [0]`;
- `maneuver_opportunity_disposition == "OPEN"`.

Again, the remaining Ship Attack opportunity was not exposed.

### Runtime log

The log shows the same semantic sequence for both reproductions.

For the Victory II-class Star Destroyer:

```text
Attack skipped by player
end_anti_squadron_attack(...)
end_attack_step(...)
Executed [skip_attack] seq=214
Attack execution done — completing attack step
ShipActivation — advancing activation step
```

For the CR90 Corvette A:

```text
Attack skipped by player
end_anti_squadron_attack(...)
end_attack_step(...)
Executed [skip_attack] seq=232
Attack execution done — completing attack step
ShipActivation — advancing activation step
```

The log therefore indicates that the skip path terminates both the current
anti-squadron sequence and the enclosing Ship Attack step.

## Initial Assessment

This issue was discovered while validating the recently repaired BUG-035
pre-commit voluntary anti-squadron finish path.

The current behavior suggests that one player interaction is being mapped onto
a broader authoritative semantic than intended:

```text
finish current anti-squadron sequence
        ↓
current implementation
        ↓
ordinary Ship Attack voluntary Skip
        ↓
end_anti_squadron_attack()
+ end_attack_step()
        ↓
Maneuver
```

The expected interaction appears to require distinguishing at least three
semantic levels:

1. abandon an uncommitted individual Attack candidate;
2. voluntarily finish the current anti-squadron hull-zone sequence;
3. voluntarily finish the enclosing remaining Ship Attack opportunity.

The current implementation appears to collapse (2) and (3).

## Requirements / Architecture Status

The correct repair is not authorized by this bug report alone.

Before implementation, audit accepted Attack and Ship Activation authority to
determine whether it already defines a distinct voluntary termination of a
non-exhausted anti-squadron iteration while preserving the enclosing Ship Attack
opportunity.

In particular, determine whether accepted authority distinguishes:

- voluntary finish of the current anti-squadron sequence while legal squadron
  targets remain;
- exhausted anti-squadron sequence termination;
- voluntary finish of all remaining Ship Attack opportunities.

Do not assume that either the ordinary Ship-context voluntary Skip or
`SkipAttackCommand(reason: squadron_done)` is automatically the correct
transaction.

If accepted requirements do not define this distinction, stop for an Owner
decision / requirements refinement before implementation.

Do not introduce or redefine a command merely to resolve BUG-038 without that
analysis.

## Relationship to BUG-035

BUG-038 was discovered during final BUG-035 Hot-Seat manual QA, but should be
tracked separately.

BUG-035 addressed completed-Attack reconstruction and composed-return
convergence, including recovery of the pre-commit choice after an
anti-squadron child attack.

BUG-038 concerns what authoritative semantic should result when the player
chooses to finish the current anti-squadron sequence while an enclosing Ship
Attack opportunity may still remain.

The previously repaired BUG-035 paths should not be reopened unless the
requirements audit proves that BUG-038 requires a correction to a shared
semantic assumption.

## Resolution

Root cause:

Requirements/Owner decision:

Fix:

Verification:

- Reproduce with a ship that has completed one anti-squadron attack from one
  hull zone and still has another legal Ship Attack from a different hull zone.
- Voluntarily finish further attacks in the current anti-squadron sequence.
- Verify no additional individual anti-squadron `BeginAttackCommand` is created.
- Verify the current anti-squadron sequence is authoritatively closed exactly
  once.
- Verify the enclosing Ship Attack opportunity remains live when another legal
  Ship Attack exists.
- Verify the player may then either declare another legal Ship Attack or
  voluntarily finish the enclosing Ship Attack opportunity.
- Verify the second Ship Attack may legally use a different unused hull zone.
- Verify Maneuver does not become `OPEN` merely from finishing the nested
  anti-squadron sequence while a live enclosing Ship Attack decision remains.
- Preserve the distinct exhausted-iteration behavior.
- Preserve the distinct whole-Ship-Attack voluntary-finish behavior.
- Verify exact-once command semantics.
- Verify Hot-Seat.
- Verify Network host/client authority/mirror behavior.
- Verify replay/save-load/reconnect behavior if the repair introduces or
  changes a mutating semantic path.

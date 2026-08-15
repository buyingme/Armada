# BUG-025 — Nebulon-B is intermittently unavailable as a legal attack target

Severity: High
Area: Combat / Targeting
Layer: Rules / Target Availability

## Expected

Whenever the Nebulon-B Escort Frigate is a legal attack target according to the
applicable attack rules, it must be offered consistently to the attacker.

This applies independently to:

- ship → ship attacks;
- squadron → ship attacks.

Target availability must be derived from the current attacker, defender,
geometry, firing arc/range or squadron distance rule, LOS, and applicable rule
state.

Equivalent legal attack situations must not depend on stale presentation,
previous attackers, previous target evaluations, or ship-specific target-list
artifacts.

## Actual

The Nebulon-B Escort Frigate is intermittently unavailable as an attack target.

The defect is not limited to squadron attacks.

Observed during the same broader manual test sequence:

1. an Imperial TIE Fighter Squadron could not attack the Nebulon-B and had to
   skip;
2. another TIE Fighter Squadron later could attack the Nebulon-B;
3. the Victory II-class Star Destroyer also reached a situation where the
   Nebulon-B could not be attacked;
4. Rebel squadron → Victory II attacks worked normally.

The common symptom is therefore increasingly associated with target discovery
or target legality involving the Nebulon-B, rather than one particular attack
type.

## Reproduction

Reproduced through multiple independent observations.

### Squadron case

1. Reach Squadron Phase.
2. Activate an Imperial TIE Fighter Squadron near the Nebulon-B.
3. Attempt to attack the Nebulon-B.

Observed:
- Nebulon-B is not offered as an attack target;
- player must skip.

A later TIE Fighter activation can attack the Nebulon-B successfully.

### Ship case

1. Reach Ship Phase.
2. Activate the Victory II-class Star Destroyer.
3. Attempt to declare the Nebulon-B Escort Frigate as target.

Observed:
- the VSD cannot attack the Nebulon-B.

This establishes that the symptom is not limited to squadron targeting.

## Evidence

- annotation: `the tie squaron could not attck the neb-b again. I had to skip`
- annotation: `The second tie squadron could attack the neb-B. very strange...`
- annotation: `I cannot attack the neb-b with the VSD!`
- associated gameplay replay/log evidence where available.

### Ship-case canonical evidence

The VSD failure capture is:

- Round 2;
- Ship Phase;
- no active `CurrentAttackState`;
- VSD alive;
- Nebulon-B alive;
- VSD and Nebulon-B both present in canonical game state.

The annotation explicitly records:

`I cannot attack the neb-b with the VSD!`

This is independent evidence that the target-availability defect extends beyond
squadron attacks.

## Evidence significance

The combined observations provide an important cross-context comparison.

The defect cannot currently be explained simply as:

- squadron distance-1 handling;
- a generic squadron → ship attack failure;
- a faction-specific squadron problem.

Both a squadron and a ship can fail to acquire the Nebulon-B as a target.

At the same time, other attackers can successfully target ships, and another
TIE can successfully target the Nebulon-B.

This points toward an intermittent or geometry/state-dependent defect in the
common targeting pipeline or a Nebulon-B-specific target representation.

### Historical BUG-010 evidence

Earlier annotations recorded the same broader targeting symptom during a
Victory II-class Star Destroyer activation.

In the first capture:

- the VSD could not attack the Nebulon-B Escort Frigate from its side arc;
- during the same activation the VSD could attack the CR90 Corvette A from its
  front arc;
- the CR90 attack proceeded normally.

In a subsequent capture:

- the VSD still could not attack the Nebulon-B from the side arc;
- the player therefore skipped the remaining attack.

Evidence:

- `annotation_20260804_221509_003.json`
- `annotation_20260804_221913_004.json`

This historical evidence strengthens the hypothesis that the defect involves
Nebulon-B target representation, hull-zone geometry, or target aggregation
rather than a general attack-flow failure.

It also establishes that the problem predates the later squadron-targeting
observations and can occur in normal ship → ship attacks.

### Additional Reproduction — 2026-08-15

BUG-025 was reproduced again during Round 2 Ship Phase.

Annotation:

`It happened again, I could not attack the neb-B from the VSDside arc! I had to skip the attack.`

Evidence:

- `annotation_20260815_081520_001.json`

At the captured state:

- the Victory II-class Star Destroyer is the active ship;
- its Attack step is active;
- it has already committed one attack;
- the Nebulon-B remains alive;
- the player reports that the Nebulon-B cannot be selected from the VSD side arc;
- the remaining attack therefore has to be skipped.

This independently confirms the recurring VSD side-arc → Nebulon-B target-availability failure already recorded in the historical BUG-010 evidence.

The repeated same-geometry symptom increases confidence that BUG-025 is tied to target geometry / hull-zone candidate derivation rather than a one-off presentation or stale-state event.

## Relationship to BUG-023

BUG-023 audited squadron attack distance semantics and corrected an inconsistency
where some consumers treated ship-style `close` range as equivalent to squadron
distance 1.

BUG-025 is different and broader.

The new ship → ship reproduction proves that BUG-025 cannot be explained solely
by squadron distance-1 handling.

Do not reopen BUG-023 automatically.

Its distance-1 invariant must remain protected while BUG-025 investigates the
broader target-discovery path.

## Initial Assessment

Root cause is unknown.

The new VSD reproduction substantially changes the investigation priority.

Investigate the shared targeting pipeline before making attack-type-specific
changes.

Potential investigation areas include:

- Nebulon-B hull-zone geometry;
- firing-arc and LOS calculations against the Nebulon-B;
- ship target aggregation from individual hull-zone candidates;
- transformation/rotation handling for the Nebulon-B model;
- target-list construction shared between ship and squadron attackers;
- stale target caches or previous attacker state;
- attacker/defender owner + entity-index identity;
- inconsistent filtering between candidate discovery and final presentation;
- whether one invalid hull-zone result incorrectly removes otherwise valid
  hull-zone candidates;
- differences between preview target discovery and authoritative BeginAttack
  validation.

For squadron attacks, continue to enforce the separate invariant:

**squadron attack legality = distance 1**

`close` must not be substituted for distance 1.

For ship attacks, normal ship range-band and firing-arc rules apply.

Do not merge those two range models while looking for the common defect.

Explicitly compare:

- VSD side arc → Nebulon-B;
- VSD front arc → CR90;
- other VSD arcs → Nebulon-B;
- other ships/arcs → Nebulon-B.

Determine whether the failure is tied to the Nebulon-B as a whole or only to
specific attacker/defender hull-zone combinations.

## Resolution

Root cause:

Two geometry defects in the shared authoritative target pipeline produced the
cross-context symptom; neither was a Nebulon-B data special case or a stale
target cache.

1. Ship hull-zone arc/range checks used ten fixed sample points per defending
   hull-edge segment. At the historical VSD side-arc coordinates, a narrow
   legal portion of the rotated Nebulon-B edge lay between those points. Arc
   discovery returned false (and range measurement could return `INF`) even
   though the finite edge crossed the VSD's firing-arc boundary.
2. Squadron-to-ship range/LOS validation treated any inclusive intersection
   with a defending arc-boundary segment as crossing another hull zone. A path
   that legally ended on the Nebulon-B hull-zone boundary was therefore
   rejected as `range path blocked`. This is the failure shown by the exact TIE
   coordinates in the reproduction log.

Forensic correction: the 2026-08-15 ship capture supports the player's report,
but its captured geometry projects the Nebulon-B into the already-used VSD
FRONT arc, not a demonstrably legal side arc. It does not by itself prove side
arc legality. The earlier 2026-08-04 coordinates do reproduce the narrow legal
VSD RIGHT-arc case and are the ship regression source. Historical BUG-010
evidence and all later reports remain preserved.

Fix:

`RangeFinder` now tests exact finite hull-edge intersections with the two
infinite firing-arc boundary rays and includes valid boundary points in the
existing endpoint range measurement. The non-endpoint ship range API delegates
to that same endpoint result, removing the former disagreement without adding
a second rule.

`LineOfSightChecker` now classifies only a strict interior intersection as
crossing a hull-zone boundary. Merely terminating the legal range/LOS path on
the target boundary is not treated as passing through another hull zone.

All consumers continue through the existing `TargetingListBuilder` /
`AttackTargetResolver` seam. `BeginAttackCommand` still re-derives and validates
the same authoritative entry; no UI targeting rule, Nebulon-B exception,
cache, protocol field, or new geometry authority was introduced.

Squadron legality remains the existing shared DISTANCE-1 predicate. Ship
`close` range is not used as a substitute: the protected distance-2-but-close
squadron cases remain rejected.

## Verification

After repair, verify at minimum:

### Ship → ship

- VSD can attack a legal Nebulon-B hull zone;
- different Nebulon-B orientations are handled correctly;
- different attacking VSD hull zones produce correct candidate sets;
- illegal arc/range/LOS combinations remain rejected.

### Squadron → ship

- TIE → Nebulon-B is offered whenever a legal distance-1 target exists;
- distance 2 remains illegal even if ship-style range is `close`;
- multiple identical TIE Fighters are evaluated independently.

### Cross-context consistency

- one attacker cannot leave stale targeting state affecting the next attacker;
- target discovery and authoritative BeginAttack validation agree;
- Nebulon-B behaves consistently as a target for ships and squadrons;
- other ship types remain unaffected;
- Hot-Seat and Network produce the same target set;
- replay/save/load/reconnect preserve equivalent targeting behavior;

Implemented regressions prove:

- the historical VSD RIGHT-arc → Nebulon-B geometry is projected and accepted
  by authoritative Begin at defender rotations 35°, 45°, and 55°;
- a CR90 at the same legal geometry remains a control target;
- a forged illegal attacker arc and an out-of-range state are rejected without
  stale target leakage;
- the exact previously failing TIE position now projects the Nebulon-B FRONT
  zone and authoritative Begin accepts that same entry;
- a second TIE control retains its FRONT/RIGHT entries;
- an exact hull-edge/arc-boundary interval narrower than the old sample gap is
  detected and measured;
- a path ending on a hull-zone boundary is legal while existing true-crossing,
  wrong-arc, LOS, and range rejections remain protected;
- squadron distance 1 to ship/squadron remains legal, while distance 2 even
  when ship-classified `close` remains illegal;
- Squadron Phase, shared target-list, direct Begin validation, network mirror,
  replay, save/load, and reconnect suites remain consistent.

Verification on 2026-08-15:

- `test_squadron_attack_target_recovery.gd`: 18/18 passed;
- `test_range_finder.gd`: 49/49 passed;
- `test_line_of_sight_checker.gd`: 43/43 passed;
- `test_targeting_list_builder.gd`: 35/35 passed;
- `test_attack_target_resolver.gd`: 24/24 passed;
- `test_attack_commands.gd`: 64/64 passed;
- `test_current_attack_shared_protocol.gd`: 25/25 passed;
- full suite: 237 scripts, 4064/4064 tests, 13645 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches;
- `git diff --check`: passed.

Status: repaired and moved to verification; Project Owner manual verification
of the reported VSD and TIE target scenarios remains required.
- BUG-005 and BUG-023 regressions remain green.

## Status

Verification — repaired across both squadron → ship and ship → ship attack
contexts. The earlier open assessment that the exact root cause was unknown is
preserved above as investigation history and is superseded by the confirmed
geometry causes in the Resolution section. Project Owner manual verification
remains required.

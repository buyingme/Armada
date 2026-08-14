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

## Resolution

Root cause:
TBD

Fix:
TBD

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
- BUG-005 and BUG-023 regressions remain green.

## Status

Open — reproduced across both squadron → ship and ship → ship attack contexts.
Exact root cause remains unknown.

# BUG-070 — Pre-Roll Empty-Pool Rules Clarification

**Status:** Preserved gameplay-rules evidence
**Evidence date:** 2026-10-03
**Method:** Single-agent, read-only rules inspection
**Implementation authority:** None — this document records the limits of the official rules evidence and does not itself establish project gameplay semantics.

## 1. Purpose

This evidence was produced during the independent audit of the BUG-070 / BUG-071 normative refinement.

The audit identified two BUG-070 gameplay outcomes that were internally consistent with the accepted Armada software architecture but were not demonstrated by the cited official game rules.

A focused follow-up inspection therefore checked the repository Rules Reference, Learn to Play, and available official rules material independently of the existing Owner decisions and software architecture.

## 2. Question 1 — Final die removed before Roll Attack Dice

### Question

If an attack successfully gathers one or more range-appropriate attack dice, but mandatory effects applied before rolling subsequently remove the final die, what happens to that individual attack?

Examples include:

- Point-Defense Failure removing the final die;
- obstruction removing the final die.

### Official-rules finding

**UNSPECIFIED.**

The Rules Reference attack sequence states that the attacker gathers attack dice appropriate for the range and cancels the attack if the attacker cannot gather any such dice.

The official FAQ repeats this principle for an attack that begins without any dice, even where an effect could add dice later.

Those provisions do not expressly address an attack that successfully gathered one or more dice and subsequently lost the final die through a mandatory effect before Roll Attack Dice.

Obstruction and Point-Defense Failure require removal before rolling but do not specify the outcome when the removed die was the final die.

The Rules Reference separately permits later effects to add dice after an attack pool has become empty during Resolve Attack Effects. That later timing case does not establish the outcome of a pool emptied before the initial roll.

The Learn to Play document likewise does not specify the final-die-removal case.

### Conclusion

Repository official rules material does not establish whether an attack whose final gathered die is removed before rolling:

- is cancelled;
- terminates through some other mechanism;
- proceeds with zero dice; or
- follows another outcome.

A project gameplay ruling is therefore required for deterministic digital implementation.

## 3. Question 2 — Anti-squadron continuation after such an individual attack

### Question

If an individual anti-squadron attack cannot proceed after mandatory pre-roll removal eliminates its final die, may the attacker continue to additional eligible squadron targets?

### Official-rules finding

**UNSPECIFIED.**

Step 6 of the Rules Reference permits a ship using anti-squadron armament to declare another eligible squadron and repeat the applicable attack steps.

The associated errata clarifies targeting and treats those repetitions as new attacks for card effects.

Neither provision specifies whether the additional-target step remains available when the preceding individual target's attack cannot proceed because its final die was removed before rolling.

The Learn to Play document does not resolve this edge case.

### Conclusion

Repository official rules material does not establish whether termination or cancellation of the affected individual attack:

- preserves the enclosing anti-squadron opportunity and permits another eligible target; or
- terminates the wider anti-squadron sequence.

A project gameplay ruling is therefore required if the individual attack does not proceed.

## 4. Rules-source relationship

No conflict was identified between the Rules Reference and Learn to Play for either question.

The Rules Reference remains the definitive source where it differs from Learn to Play, but neither document resolves these two edge cases.

These findings must not be represented as official Star Wars: Armada rulings.

## 5. Architecture consequence

BUG-070 cannot derive both required outcomes from official rules alone.

The software architecture may provide deterministic semantics for these otherwise unspecified cases, but those semantics must be identified explicitly as Owner gameplay rulings rather than as direct consequences of the Rules Reference or Learn to Play.

This evidence does not itself select those semantics.

The corresponding Owner gameplay ruling is preserved separately in the BUG-070 Owner Resolution.

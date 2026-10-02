# BUG-071 — Concentrate Fire resolves at the wrong attack step

## Status

Open

## Summary

The Concentrate Fire command effect is currently integrated at the wrong point in the
attack flow.

According to the Armada Rules Reference, Concentrate Fire is resolved during the
**Resolve Attack Effects** step of an attack, after the **Roll Attack Dice** step has
completed.

The current implementation must be audited and corrected so that Concentrate Fire does
not participate in gathering the initial attack pool or otherwise alter whether the
attack successfully reaches Resolve Attack Effects.

This defect was identified while analysing BUG-070.

## Expected behavior

The attack sequence must preserve the Rules Reference ordering:

1. Declare Target
2. Roll Attack Dice
   - gather the attack dice permitted by armament/range and applicable effects;
   - resolve effects that modify this step;
   - if no dice remain such that the attack cannot proceed, resolve the applicable
     attack-cancellation semantics.
3. Resolve Attack Effects
   - Concentrate Fire may be resolved here.
4. Continue through the remaining attack steps.

A Concentrate Fire command therefore cannot be used to rescue an attack that has already
failed/canceled during Roll Attack Dice.

### Concentrate Fire dial

The Concentrate Fire dial effect is resolved during **Resolve Attack Effects**, not while
gathering the initial attack pool.

It may add one attack die according to the applicable Concentrate Fire rules only after
the attack has successfully reached Resolve Attack Effects.

### Concentrate Fire token

The Concentrate Fire token effect must likewise occur at its rules-defined timing within
Resolve Attack Effects.

Its reroll behavior must not be represented as part of initial attack-pool gathering.

## Actual behavior

Current production behavior appears to integrate Concentrate Fire into the attack flow
too early.

This can make Concentrate Fire participate in or influence the initial attack-pool
construction rather than resolving at its correct Rules Reference timing.

The exact production seams and all affected dial/token paths require code-level
diagnosis before repair.

## Why this matters

The timing distinction is gameplay-significant.

In particular, an attack that reaches zero dice during Roll Attack Dice must not remain
alive merely because a Concentrate Fire dial could theoretically add a die later.

Resolve Attack Effects has not yet been reached, so Concentrate Fire is not available to
rescue that attack.

Incorrect timing can therefore change:

- whether an attack is legal/continues;
- zero-dice attack cancellation;
- attack-pool composition;
- Concentrate Fire dial consumption;
- Concentrate Fire token consumption;
- save/load and replay reconstruction of an attack;
- Network authoritative/passive convergence;
- bot/legal-action reasoning.

## Relationship to BUG-070

BUG-071 is related to, but distinct from, BUG-070.

BUG-070 concerns the authoritative outcome when mandatory processing removes the final
attack die and the attack reaches zero dice.

BUG-071 concerns the incorrect timing/integration of Concentrate Fire itself.

BUG-070 must not be repaired by allowing an incorrectly early Concentrate Fire effect to
rescue the zero-dice attack.

The two bugs may touch shared attack-pool machinery and should therefore be checked
together for regression evidence, but they should retain separate issue identities and
repair obligations.

## Architecture constraints

- Preserve ADR-001 / CON-001 attack authority and lifecycle ownership.
- Do not move gameplay authority into UI/presentation code.
- Do not introduce a generic attack continuation mechanism or FSM.
- Preserve committed attack/declaration semantics.
- Concentrate Fire timing must be represented through the existing authoritative attack
  lifecycle at the correct rules step.
- Hot-Seat, Network, save/load, reconnect, and replay must derive equivalent gameplay
  semantics.
- Existing correctly implemented attack effects must not change timing as collateral
  damage.

## Required investigation

Before implementation:

1. Trace the current Concentrate Fire dial path from command availability through attack
   pool mutation.
2. Trace the Concentrate Fire token path separately.
3. Identify where each effect currently mutates or influences the attack pool.
4. Compare those points with the authoritative Roll Attack Dice → Resolve Attack Effects
   boundary.
5. Identify any legality logic that currently assumes Concentrate Fire can contribute to
   the initially gathered pool.
6. Inspect save/load, replay and Network result application for the same assumption.
7. Inspect bot/attack-simulation/legal-target logic if it shares the affected production
   rules.
8. Determine whether correcting the timing exposes additional invalid assumptions about
   empty attack pools or attack cancellation.

## Required regression evidence

At minimum cover:

- normal attack without Concentrate Fire;
- Concentrate Fire dial adding a legal die during Resolve Attack Effects;
- Concentrate Fire token reroll at the correct timing;
- combined dial + token behavior where legal;
- attack whose initial gathered pool is valid and later uses Concentrate Fire;
- attack that cannot proceed through Roll Attack Dice and therefore cannot be rescued by
  Concentrate Fire;
- BUG-070 final-die-removal case;
- multi-die control case;
- ship attack;
- anti-squadron attack;
- Hot-Seat;
- Network authoritative and passive application;
- save/load and reconnect at affected attack boundaries;
- non-fixture replay reconstruction.

Where neighboring attack effects share the same pool/timing machinery, include focused
regression evidence demonstrating that their timing remains unchanged.

## Replay policy

Do not modify, synthesize, regenerate, transform, relabel, or replace accepted replay
fixtures as part of the repair.

Any required replay baseline renewal remains Owner-recorded evidence under the repository
replay workflow.

## Acceptance criteria

BUG-071 is resolved when:

- Concentrate Fire dial and token effects occur only at their correct Rules Reference
  timing;
- initial attack-pool gathering no longer depends on a later Concentrate Fire effect;
- an attack that terminates during Roll Attack Dice cannot be rescued by Concentrate Fire;
- canonical attack state and continuation remain recoverable;
- Hot-Seat and Network behavior are equivalent;
- persistence/reconnect/replay preserve the corrected semantics;
- required focused and production-path regressions pass;
- architecture/static verification and the full suite converge;
- no accepted architecture or unrelated attack semantics are changed.

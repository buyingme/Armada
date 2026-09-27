# BUG-064 — X-wing Squadron Critical Effect Does Not Deal Faceup Damage Card

## Status

Open

## Summary

When an X-wing Squadron attacks a ship and rolls a critical icon, the X-wing Squadron special effect is not applied.

The observed attack contained a critical die result, but the defending ship received normal hull damage only. No faceup damage card was dealt as required by the X-wing Squadron effect.

This is a gameplay-rule defect.

## Observed Behavior

During a Squadron Phase activation:

1. An X-wing Squadron attacked a Victory II-class Star Destroyer.
2. The attack rolled a critical result.
3. The attack resolved for 1 damage.
4. The defending ship suffered hull damage.
5. No faceup damage card was dealt by the X-wing Squadron special effect.

The captured state after resolution shows:

- attacker: X-wing Squadron;
- defender: Victory II-class Star Destroyer;
- attack kind: standard;
- one critical die result;
- final damage: 1;
- hull damage: 1;
- defender shields in the affected zone: 0;
- no faceup damage card on the defending ship.

The annotation records:

> The x-wing squadron special effect was not in place. A face up card was not dealt in the attack run even if I rolled a crit.

## Expected Behavior

When an X-wing Squadron attacks a ship and the conditions for its squadron critical effect are satisfied, the effect must be resolved according to the implemented X-wing Squadron rule.

The critical effect must be integrated into the authoritative attack-resolution path rather than implemented as a UI-only consequence.

If the effect requires a faceup damage card to be dealt, that card must be dealt through the existing authoritative damage-card infrastructure, including any applicable immediate or persistent damage-card effects.

The resulting canonical state, Network peers, replay, save/load, and presentation must all reflect the same result.

## Actual Behavior

The attack resolves without applying the X-wing Squadron special effect.

Normal attack damage is applied, but the expected faceup damage card is absent from the defending ship after resolution.

## Reproduction

Observed during manual Network testing.

1. Start a Network game containing an X-wing Squadron and an enemy ship.
2. Activate the X-wing Squadron.
3. Attack the enemy ship.
4. Roll a critical result satisfying the X-wing Squadron special-effect condition.
5. Resolve the attack.
6. Inspect the defending ship's damage cards.

### Observed Result

The attack deals its normal damage, but the X-wing Squadron critical effect does not deal the expected faceup damage card.

## Evidence

- Manual annotation captured during the failed attack.
- Captured canonical game state contains the completed attack and post-resolution ship state.

Relevant captured facts:

- `attacker.kind = squadron`
- attacker is `X-wing Squadron`
- `defender.kind = ship`
- defender is `Victory II-class Star Destroyer`
- attack contains a critical die result
- `final_damage = 1`
- `hull_damage = 1`
- defending ship `faceup_damage = []`

The evidence establishes the missing gameplay effect but does not by itself establish the implementation root cause.

## Initial Classification

Gameplay-rule / integration defect.

The exact failing seam is not yet established.

Investigation should determine whether the failure is in one or more of:

- X-wing Squadron rule registration/integration;
- squadron-versus-ship critical-effect eligibility;
- critical-effect selection/resolution;
- attack damage resolution;
- authoritative faceup damage-card dealing;
- continuation into immediate damage-card resolution;
- Network command/result application.

Do not assume the defect is presentation-only.

Do not bypass the existing authoritative attack or damage-card infrastructure to repair it.

## Architecture Constraints

The repair must preserve existing architecture:

- `CurrentAttack` and the accepted attack lifecycle remain authoritative for attack resolution.
- Squadron special effects must participate through the authoritative gameplay path.
- Damage cards must be dealt through the existing authoritative damage-card ownership and resolution mechanisms.
- Immediate damage-card effects must continue through their existing canonical resolution path.
- UI/presentation must not become gameplay authority.
- Network peers must derive/apply the same authoritative result.
- Replay must represent the authoritative gameplay transition rather than reconstructing the X-wing effect from presentation state.
- No X-wing-specific alternate attack lifecycle should be introduced.
- No generic continuation mechanism, callback stack, or gameplay FSM should be introduced solely for this repair.

## Scope

### In Scope

- reproduce the failed X-wing Squadron critical effect;
- identify the exact production seam where the effect is lost;
- verify the X-wing Squadron rule is registered and reachable;
- verify authoritative critical-effect eligibility and resolution;
- verify authoritative faceup damage-card dealing;
- verify continuation if the dealt faceup card has an immediate effect;
- implement the minimum architecture-compatible repair;
- add focused regression coverage;
- verify Network convergence for the repaired path.

### Out of Scope

- redesigning the general attack lifecycle;
- redesigning damage-card architecture;
- unrelated squadron abilities;
- unrelated Maneuver / BUG-043 / BUG-058 work;
- UI-only simulation of the missing effect;
- broad upgrade or squadron-rule refactoring unless investigation proves it necessary.

## Acceptance Criteria

1. An X-wing Squadron attacking a ship can resolve its special critical effect when its rules conditions are satisfied.
2. The effect is resolved through the authoritative attack path.
3. The required faceup damage card is dealt through the authoritative damage-card infrastructure.
4. The defending ship's canonical damage state reflects the dealt card.
5. A dealt immediate damage card enters its normal authoritative immediate-resolution lifecycle.
6. Persistent faceup damage-card effects remain represented through their existing canonical mechanisms.
7. Network peers converge on the same resulting state.
8. Replay records sufficient authoritative gameplay transitions to reproduce the result under the existing replay contract.
9. Attacks that do not satisfy the X-wing critical-effect conditions do not trigger the effect.
10. Normal squadron-versus-ship attacks without this effect remain unchanged.
11. Existing ship critical-effect behavior remains unchanged.
12. Focused automated regression coverage exercises the actual production seam responsible for the defect.

## Verification

At minimum:

- focused automated test for X-wing Squadron attacking a ship with the qualifying critical result;
- negative case where the X-wing effect must not trigger;
- canonical verification that the faceup card is actually dealt;
- Network verification of the same path;
- verification of an immediate faceup damage card if that path can result from the effect;
- regression verification for ordinary squadron-versus-ship damage resolution;
- regression verification for existing standard critical-effect handling.

If replay fixture renewal becomes necessary, follow the project replay-fixture policy:

- Codex must not generate, synthesize, reconstruct, patch, transform, relabel, or promote an accepted replay fixture;
- the Project Owner manually records genuine replay evidence;
- Codex may inspect and verify the Owner-recorded fixture afterward.

## Resolution

Pending investigation and implementation.

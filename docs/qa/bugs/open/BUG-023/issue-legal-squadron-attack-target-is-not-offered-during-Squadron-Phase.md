# BUG-023 — Legal distance-1 squadron attack target is not offered during Squadron Phase

Severity: High
Area: Squadron Phase / Targeting
Layer: Projection / Command Flow

## Expected

When a squadron is activated during the Squadron Phase and has a legal target at **distance 1**:

1. the legal target must be detected by the production targeting logic;
2. the squadron activation UI must present the Attack option;
3. the player must be able to select the legal target and begin the attack;
4. Move and Attack availability must reflect the squadron's canonical action state and the same distance-1 targeting rules used by command validation.

Important rule distinction:

**Squadron attacks are legal only at distance 1.**

This must not be treated as equivalent to the ship-attack range band `close`. A target may be at close range while still being at distance 2 and therefore illegal for a squadron attack.

## Actual

A TIE Fighter Squadron is activated during the Squadron Phase.

The production targeting diagnostics identify a hull zone of the Nebulon-B Escort Frigate at:

- `distance = 1`
- `range = close`

and explicitly accept it as a valid target:

`-> HIT ship 'Nebulon-B Escort Frigate' zone=FRONT`

However, the Squadron Phase controller subsequently reports:

`can_move=true, targets=false`

and the activation UI offers only movement.

The player therefore cannot begin an otherwise legal distance-1 squadron attack.

## Reproduction

Observed once.

1. Reach the Squadron Phase.
2. Activate the TIE Fighter Squadron shown in the evidence.
3. The Nebulon-B Escort Frigate has at least one hull zone at distance 1.
4. Observe the available squadron actions.

Result:

- production targeting identifies a valid distance-1 target;
- the Squadron Phase activation UI reports no attack targets;
- Attack cannot be selected.

## Evidence

- `annotation_20260814_130328_001.json`
- `game_20260814_130128.log`

### Canonical-state evidence

At the captured state:

- phase = Squadron Phase;
- controller = Player 1;
- active squadron is a TIE Fighter Squadron;
- `activation_context = "squadron_phase"`;
- `attack_action_disposition = "available"`;
- `move_action_committed = false`;
- `activated_this_round = false`.

The canonical action state therefore still permits the squadron to perform an attack if a legal distance-1 target exists.

### Production targeting evidence

For the relevant TIE Fighter, the log records:

Nebulon-B FRONT:

- distance ≈ 82 px
- `distance=1`
- `range=close`
- accepted:
  `-> HIT ship 'Nebulon-B Escort Frigate' zone=FRONT`

Other hull zones demonstrate why `close` must not be used as the squadron legality criterion.

For example, Nebulon-B REAR is reported as:

- `distance=2`
- `range=close`

This is still close range in ship-range terminology, but it is **not legal squadron attack distance**.

Despite the valid FRONT distance-1 target, the Squadron Phase controller then reports:

`Squadron overlay shown for tie_fighter_squadron (can_move=true, targets=false).`

This demonstrates a mismatch between legal distance-1 target discovery and the action availability projected to the player.

### Attack Simulator evidence

The Attack Simulator visually identifies the Nebulon-B as being at `close` range.

This is supporting geometrical evidence only.

It must **not** be used as proof of squadron attack legality unless the simulator also evaluates the explicit distance-1 rule. `close` and `distance 1` are not interchangeable.

The simulator should itself be reviewed to ensure that squadron attack planning communicates and applies distance-1 legality rather than ship-style close-range legality.

## Initial Assessment

The evidence suggests a mismatch between production distance-1 target discovery and the Squadron Phase action-availability projection.

The targeting diagnostics clearly distinguish:

- discrete squadron attack distance (`distance=1`, `distance=2`, etc.);
- ship-style range bands (`close`, `medium`, `long`).

The repair must preserve this distinction.

Potential investigation areas include:

- whether Squadron Phase target availability accidentally filters by `range == close` instead of `distance == 1`;
- whether valid distance-1 ship hull-zone results are lost when converting targeting-builder results into squadron activation targets;
- whether different consumers use inconsistent range representations;
- whether the Attack Simulator applies ship-style range-band logic to squadron attacks.

## Relationship to BUG-005

BUG-023 is closely related to the same range-model distinction addressed by BUG-005.

BUG-005 concerned squadron attacks being allowed beyond distance 1 because close-range classification was used too broadly.

BUG-023 concerns a legal distance-1 target being omitted from normal Squadron Phase attack availability.

Investigation should explicitly audit all squadron attack consumers to ensure they use **distance 1**, not generic `close` range, as the legality criterion.

Do not assume BUG-005 is fully unrelated merely because its direct regression tests pass; BUG-023 may expose another consumer of the old range-band model.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify explicitly:

- squadron → ship attack is available at distance 1;
- squadron → squadron attack is available at distance 1;
- distance 2 is rejected even when ship-style range is `close`;
- all greater distances are rejected;
- normal Squadron Phase projection and BeginAttack validation use the same distance-1 predicate;
- commanded-squadron attacks use the same predicate;
- Attack Simulator uses or clearly displays the same squadron distance-1 legality;
- moving a squadron causes target availability to be re-derived correctly;
- Hot-Seat and Network produce equivalent legal-target availability.

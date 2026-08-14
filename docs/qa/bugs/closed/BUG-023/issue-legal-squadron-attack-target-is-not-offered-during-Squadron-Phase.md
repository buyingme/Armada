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

The reported legal-target omission is not supported by the attached
reproduction once entity identity is correlated. The log audits six
same-named TIE Fighter squadrons without owner/index labels. The distance-1
FRONT/RIGHT hits quoted in the report were calculated for a different,
already-activated TIE; the selected active TIE's own target build did not
contain that legal candidate. Its `targets=false` projection therefore agreed
with its owner/index-local authoritative list. This corrects the initial
assessment: no conversion step was dropping a distance-1 target for the
captured active squadron.

The required all-consumer audit did establish a separate production
inconsistency in the same rule surface. Outgoing gameplay target construction
(used by Squadron Phase, commanded squadrons, post-movement derivation, and
`BeginAttackCommand` validation) used distance band 1, while both incoming
planning/threat collectors used ship range band `close`. Those incoming
consumers falsely reported distance-2-but-close squadron attacks as legal.

Fix:

Added one shared `TargetingListBuilder.is_squadron_attack_distance_legal()`
predicate based on `GameScale.get_distance_band(distance_px) == 1` and routed
all four squadron outgoing/incoming target consumers through it. Gameplay and
planning/debug projections therefore reuse one rule seam. The Attack
Simulator already draws its squadron radius from `distance_bands_px[0]`; its
private naming and documentation now say “distance 1” rather than “close” so
it does not communicate the wrong range model.

No targeting state or presentation became authoritative. Begin validation
continues to rebuild targets from canonical board geometry, and no independent
UI targeting rule was introduced.

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

Implemented regression evidence:

- Existing boundary tests exercise squadron → ship and squadron → squadron at
  distance 1 and prove both target offering and accepted `BeginAttackCommand`.
- Existing paired boundary tests use distance 2 while still classified
  `close` and prove both preview omission and forged Begin rejection.
- New incoming-threat tests use a scale where distance 1 ends at 181 px while
  close ends at 294 px, and prove distance-2/close squadron → ship and
  squadron → squadron threats are rejected.
- Normal Squadron Phase and commanded-squadron production tests use the same
  authoritative list builder. The BUG-022 production test additionally proves
  target availability is re-derived after movement.
- Exact owner/index and duplicate-name target recovery tests remain green,
  directly guarding the identity ambiguity present in the original evidence.
- Attack Simulator focused tests passed (29/29); targeting builder tests
  passed (35/35); production target recovery passed (16/16).
- Full repository suite: 4038/4038 passed.
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches).

Forensic evidence note: the original manual capture cannot prove the title's
claimed same-squadron omission because its diagnostics omit identity. That
historical limitation remains recorded and is not changed by later successful
verification. The real audited defect was the inconsistent distance-rule
consumer, and its shared distance-1 repair is covered automatically.

Project Owner manual verification:

- Verified resolved in Hot-Seat mode on 2026-08-14.
- Legal distance-1 squadron attack targets are offered and can be attacked.

Final status: resolved, architecture-audited, and manually verified.

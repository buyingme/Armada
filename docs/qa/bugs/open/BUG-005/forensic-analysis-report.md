# BUG-005 Forensic Investigation Report

## Scope and documents read

This was a read-only investigation. No repository files were modified and no tests were executed.

Startup documents read:

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

Architecture and migration authority read:

- [CON-006](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md)
- [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
- [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
- [MA-ATTACK-002](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-ATTACK-002-post-stabilization-con-006-compliance.md)

BUG-005 evidence read:

- [BUG-005 issue](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-005/issue-squadron-attack-allowed-beyond-range-1.md)
- [BUG-005 annotation](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-005/annotation_20260801_173628_001.json)

The BUG-005 folder contains one annotation.

Rules and bounded implementation evidence also inspected:

- [Rules Reference Guide](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:90)
- [production scale configuration](/Users/Katharina/godot/Armada/Resources/Game_Components/scale/scale_config.json:18)
- [GameScale](/Users/Katharina/godot/Armada/src/autoload/game_scale.gd:235)
- [TargetingListBuilder](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:889)
- [BeginAttackCommand](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:16)
- [TargetSelector](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:888)
- [RangeFinder](/Users/Katharina/godot/Armada/src/core/geometry/range_finder.gd:549)
- [AttackSimOverlay](/Users/Katharina/godot/Armada/src/scenes/tools/attack_sim_overlay.gd:193)
- [TargetingListBuilder tests](/Users/Katharina/godot/Armada/tests/unit/test_targeting_list_builder.gd:15)

## Finding

BUG-005 is a concrete `TargetingListBuilder` range-eligibility defect at the CON-006 declaration boundary.

The geometric squadron-to-squadron distance is measured correctly from base edge to base edge. The first incorrect decision occurs immediately afterward: `TargetingListBuilder` classifies that distance using the range side of the ruler and treats the complete close-range band as legal for a squadron attack.

The accepted rule instead limits a squadron attacker to distance 1. Range bands and distance bands are separate scales.

This defect affects both Preview and Begin because both use the same erroneous authoritative targeting entry. They agree with each other, but agree on the wrong gameplay result. It is therefore not a Preview/Begin parity divergence.

## Rules boundary

The Rules Reference states:

- A squadron’s defender must be at distance 1 during target declaration.
- A squadron’s attack range is distance 1.
- The ruler’s range side has close, medium, and long bands, while its distance side has bands 1–5.

Repository scale data preserves that distinction:

| Measurement | Production threshold |
|---|---:|
| Distance 1 maximum | 181 px |
| Close range maximum | 292 px |

Evidence:

- [Rules Reference attack declaration](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:94)
- [Rules Reference attack range](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:142)
- [Rules Reference range/distance distinction](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:937)
- [production thresholds](/Users/Katharina/godot/Armada/Resources/Game_Components/scale/scale_config.json:18)

`GameScale` also exposes the two scales separately: `get_range_band()` uses the close/medium/long thresholds, while `get_distance_band()` uses distance bands 1–5. [GameScale](/Users/Katharina/godot/Armada/src/autoload/game_scale.gd:235)

The rule is therefore not ambiguous. “Distance 1” and “close range” are not interchangeable.

## Production declaration path

1. `TargetingListBuilder.authoritative_attack_entry()` reconstructs participants from canonical `GameState` and builds the attacker’s outgoing target entries. [TargetingListBuilder](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:157)

2. For squadron-to-squadron attacks, `RangeFinder.measure_range_squad_to_squad()` calculates edge-to-edge distance. The measurement itself is consistent with the Rules Reference. [RangeFinder](/Users/Katharina/godot/Armada/src/core/geometry/range_finder.gd:549)

3. `_collect_squad_vs_squads()` passes the resulting distance to `GameScale.get_range_band()` and accepts it whenever the result is `close`. [TargetingListBuilder](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:997)

4. Consequently, every otherwise legal squadron target with an edge distance greater than 181 px but no greater than 292 px is beyond distance 1 yet is emitted as a legal targeting entry.

5. Standard squadron target selection calls that authoritative entry before creating Preview. A non-empty entry is treated as a legal candidate. [TargetSelector](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:888)

6. Confirm submits the resulting candidate to `BeginAttackCommand`.

7. `BeginAttackCommand` independently calls `TargetingListBuilder.authoritative_attack_entry()` again. It rejects an empty entry or mismatching submitted range, but the same defective predicate again returns a `close` entry. [BeginAttackCommand](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:31), [authoritative lookup](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:242)

8. Begin can therefore accept the attack and install `CurrentAttackState`. No presentation or scene-owned authority is needed for the failure.

The same range/distance conflation is also present in the squadron-to-ship outgoing-target path. [TargetingListBuilder](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:938)

## Earliest failing authoritative boundary

The earliest failing boundary is the authoritative target-eligibility query in `TargetingListBuilder._collect_squad_vs_squads()`.

The precise incorrect decision is the combination of:

- classifying the measured distance with `GameScale.get_range_band()`; and
- accepting the target when that result is `close`.

The prior geometric measurement is not the first failure. Preview, presentation, Confirm, and Begin are downstream consumers of the already incorrect entry.

Strictly under the architecture, `TargetingListBuilder` does not authorize a command. It supplies derived target-eligibility evidence. `BeginAttackCommand` owns authoritative command authorization. The builder’s incorrect entry is nevertheless the first failure because Begin relies on that entry for its required range validation.

## Preview and Begin

Given identical authoritative state and identical declaration intent, Preview and Begin cannot legally disagree on range under CON-006-PARITY-001 through PARITY-007.

The current standard squadron flow uses the same targeting surface at both boundaries:

- Preview requests an authoritative squadron candidate from `TargetingListBuilder`.
- Begin reconstructs the authoritative entry from current `GameState`.

For BUG-005, the available code evidence indicates agreement, not divergence. Both boundaries can classify an attack between distance 1 and close range as legal.

Begin may still reject after Preview for the transaction-only conditions permitted by CON-006, such as stale state or command ordering. Such a rejection would not constitute a legal range disagreement.

Classification: **not a Preview/Begin parity defect**.

## TargetingListBuilder and Begin legality

### TargetingListBuilder

`TargetingListBuilder` cannot compliantly identify a target beyond distance 1 as eligible for a normal squadron attack.

The current implementation can nevertheless emit such an entry when the edge-to-edge distance lies in the interval:

`distance 1 maximum < measured distance ≤ close-range maximum`

Classification: **TargetingListBuilder defect**, specifically an incorrect range-eligibility classification following an otherwise valid distance measurement.

### BeginAttackCommand

`BeginAttackCommand` cannot legally authorize a squadron attack beyond distance 1. CON-006 requires immediate authoritative validation of range.

The current implementation can accept the attack because its authoritative revalidation uses the same defective builder result. Payload parity does not protect against this case: both the submitted candidate and re-derived entry contain `close`.

Classification: **authoritative Begin validation defect caused by the shared targeting result**.

## Presentation and projection

No evidence identifies presentation or projection as the causal boundary.

The squadron attack overlay uses the distance 1 threshold for its visual circle, not the close-range threshold. [AttackSimOverlay](/Users/Katharina/godot/Armada/src/scenes/tools/attack_sim_overlay.gd:193)

This means the visual distance-1 boundary can be correct while the targeting builder accepts a target outside it. Presentation does not authorize Begin, and the production trace reaches the failure without any presentation-owned gameplay mutation.

Classification: **not a presentation/projection defect**.

## Rules interpretation

The accepted Rules Reference is explicit that squadron attacks use distance 1 and that range and distance are separate ruler scales.

Some local targeting comments and test fixtures conflate distance 1 with close range. In particular, the targeting-builder unit fixture assigns both close range and distance 1 the same 181 px threshold. [test fixture](/Users/Katharina/godot/Armada/tests/unit/test_targeting_list_builder.gd:15)

That fixture prevents the tests from exercising the production-only interval between 181 px and 292 px. The existing “beyond distance 1” test places its target far beyond both thresholds rather than immediately beyond distance 1. [existing test](/Users/Katharina/godot/Armada/tests/unit/test_targeting_list_builder.gd:729)

This explains why existing test evidence does not refute the defect. No tests were executed during this investigation.

Classification: **not an unresolved rules-interpretation issue**. The implementation and supporting test assumptions encode a conflation contradicted by the Rules Reference and production scale data.

## CON-006 obligations affected

The defect directly conflicts with:

- **Section 6.4 Resolver Surfaces:** mechanic-specific resolvers own deterministic target-eligibility and range calculations. The current derived eligibility result applies the wrong measurement scale.
- **Adjacent Authority Matrix — Range:** Preview and Begin must validate range through the applicable mechanic-specific resolver. [CON-006 range binding](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md:625)
- **CON-006-PREV-002:** Preview must apply accepted resolver and rule semantics. A beyond-distance-1 target is instead presented as preview-legal.
- **CON-006-ILLEGAL-001 and ILLEGAL-004:** an out-of-range selection must remain illegal and produce an out-of-range rejection category. The current path creates a candidate.
- **CON-006-PARITY-003:** Preview and Begin must apply the same accepted rule semantics. They share a calculation, but that calculation does not implement the accepted distance-1 rule.
- **CON-006-BEGIN-001 and BEGIN-002:** Begin must revalidate authoritative range immediately before mutation. The revalidation occurs but uses the wrong eligibility threshold.

CON-006-PARITY-007 is not the primary violation because identical Preview and Begin inputs do not produce different results. The shared result is incorrect at both boundaries.

ADR-001 and CON-001 ownership remain intact: `GameState` still owns `CurrentAttackState`, and Begin remains the replayable semantic mutation. BUG-005 is a declaration-rule compliance defect, not an ownership or command-lifecycle redesign issue.

## BUG-005 annotation limits

The annotation confirms the user report and records a post-resolution Squadron Phase state, but it does not preserve:

- which of the two activated X-wings attacked;
- which TIE fighter was selected;
- the authoritative play-area configuration used for the measurement;
- the Preview candidate;
- measured edge-to-edge distance;
- the targeting entry returned at selection;
- the Begin payload or validation result;
- the active `CurrentAttackState`, which was already inactive.

The issue’s statement that `ship_target_attack_counts` records squadron attack history is not supported by the implementation. That state records ship-against-ship attacks only. [GameState](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:149), [RollDiceCommand](/Users/Katharina/godot/Armada/src/core/commands/roll_dice_command.gd:74)

These omissions prevent exact reconstruction of the one observed attacker/defender pair. They do not prevent classification of the current production defect because the builder deterministically authorizes the complete interval between distance 1 and close range.

## Classification

| Candidate classification | Finding |
|---|---|
| CON-006 attack-declaration defect | Yes |
| Preview/Begin parity defect | No; both use the same erroneous result |
| `TargetingListBuilder` defect | Yes; primary failing implementation surface |
| Range-calculation defect | Yes at the range/distance eligibility-classification step; not in edge-distance geometry |
| Presentation/projection defect | No causal evidence |
| Rules interpretation issue | No unresolved ambiguity; accepted rules distinguish the scales |
| Unrelated defect | No |

## Evidence sufficiency

The available evidence is sufficient to classify BUG-005 and identify its earliest failing production boundary.

It is not sufficient to prove which specific X-wing/TIE pair produced the original annotation. That incident-level uncertainty lowers confidence slightly but does not alter the defect classification.

## TWI-ATTACK-001 disposition

BUG-005 belongs inside TWI-ATTACK-001.

The failure occurs before accepted Begin, directly within CON-006 target eligibility, Preview legality, out-of-range rejection, and Begin validation. MA-ATTACK-002 excluded BUG-005 implementation only unless the forensic investigation established a CON-006 relationship. That relationship is now established.

This finding does not add an architectural owner, reopen an Owner Decision, or extend into post-Begin attack resolution.

- Overall confidence: 9/10
- Earliest failing authoritative boundary: `TargetingListBuilder._collect_squad_vs_squads()` classifies a squadron edge distance using the close-range scale and emits an authoritative target-eligibility entry for targets beyond distance 1.
- CON-006 relationship: Yes
- TWI-ATTACK-001 relationship: Include
- Recommended next step: Record this report as the accepted BUG-005 scope disposition for TWI-ATTACK-001; preserve the missing exact-pair evidence as an incident limitation rather than delaying classification.

# Ship Maneuver Prerequisite Impact Analysis

**Status:** Discovery / non-normative
**Context:** BUG-043 Maneuver prerequisite analysis
**Purpose:** Preserve repository, rules, geometry, Rule Capability, and continuation findings needed before final Maneuver requirements and BUG-043 implementation-workbook refinement.

This document records discovery evidence and recommendations only. It does not establish normative architecture, approve Rule Capability integration, or replace accepted ADRs, contracts, requirements, or Owner decisions.

Owner decisions made after this analysis should be preserved in the appropriate normative documents rather than treated as amendments to this discovery report.

No files were modified, no tests were run, and BUG-043 was not updated. This is static repository/rules/architecture analysis only.

## 1. Squadron displacement findings

Tabletop requirements are explicit:

- The non-moving player places every displaced squadron, regardless of ownership, in any order.
- Every base must remain wholly inside the play area and cannot overlap any ship or squadron.
- The player must maximize the number directly touching the moved ship; they may not deliberately space them to reduce that number.
- Every remaining squadron must touch a squadron that itself touches the ship. A longer indirect chain is not sufficient.
- Obstacles neither prohibit displacement placement nor trigger an obstacle effect.
- Tabletop shield-dial assemblies count as ship base, but the Owner-settled digital footprint is the existing simplified rotated `ShipBase` rectangle.

Evidence: [RRG Overlapping](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:856), [RRG FAQ](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:2396), [Learn to Play](/Users/Katharina/godot/Armada/Resources/SWM01-ARMADA-LEARN-TO-PLAY/SWM01-ARMADA-LEARN-TO-PLAY.md:885), [accepted SMI-062](/Users/Katharina/godot/Armada/docs/requirements/gameplay_interactions/ship_maneuver_interaction.md:497).

Geometry:

- Every squadron is the same circle: fixed diameter 34.2 mm, approximately 80.73 px under the current 720 px/305 mm scale. No heterogeneous-size support is needed. [scale data](/Users/Katharina/godot/Armada/Resources/Game_Components/scale/scale_config.json:5), [SquadronBase](/Users/Katharina/godot/Armada/src/core/state/squadron_base.gd:21)
- The legal center locus for direct touching is the boundary of the ship rectangle offset outward by one squadron radius: four parallel segments plus four corner arcs, clipped by board limits and other ship/squadron exclusions.
- Remaining placements lie on radius-`2r` arcs around at least one directly touching squadron, again clipped by the board and blockers.
- Touching must be distinguished from overlapping with a consistent numerical policy. Current helpers classify exact tangency as overlap (`<=`) and then introduce a 1 px snap gap and a separate 5 px touching tolerance. Those predicates are not strong enough for authoritative maximum-touch proof. [current predicates](/Users/Katharina/godot/Armada/src/core/state/squadron_base.gd:42), [current placement validation](/Users/Katharina/godot/Armada/src/core/movement/overlap_resolver.gd:184)

Maximum-touch implications:

- Placement order does not change the mathematical optimum because bases are equal, but it does affect a greedy/manual sequence: an early legal placement can waste boundary space and reduce later capacity. The FAQ expressly prohibits accepting that result.
- “No opening remains around the player’s submitted arrangement” is insufficient. Authority must establish the maximum direct-touch count attainable by some legal placement of the complete displaced set, including legal second-ring placement for the remainder.
- This is a continuous packing problem with combinatorial choices. The equal-circle/rectangular-ship constraint reduces it substantially: relevant positions lie on a finite union of one-dimensional line/arc boundaries, so deterministic critical-event enumeration plus bounded dynamic programming or branch-and-bound can avoid exhaustive two-dimensional search. A simple first-fit greedy algorithm cannot prove compliance.
- Realistic affected sets should be small enough for a bounded search at commit time. Worst-case complexity remains exponential in the number of mutually interacting candidates, so performance limits and adversarial board tests are required.

Current gaps:

- Production detects affected squadrons and validates one direct-touch placement at a time. It has no play-area footprint test, second-ring support, full-batch legality, exact affected-set validation, or maximum-capacity proof. [OverlapResolver](/Users/Katharina/godot/Armada/src/core/movement/overlap_resolver.gd:160)
- The controller always snaps every squadron directly to the ship, then submits one batch. [DisplacementController](/Users/Katharina/godot/Armada/src/scenes/game_board/displacement_controller.gd:172)
- `CommitDisplacementCommand` validates controller, references, and normalized center coordinates only; it does not validate geometry or completeness. [CommitDisplacementCommand](/Users/Katharina/godot/Armada/src/core/commands/commit_displacement_command.gd:37)
- Tests cover individual contact/snap and command serialization, not maximum touching, chains, full-base board containment, or batch legality. [geometry tests](/Users/Katharina/godot/Armada/tests/unit/test_overlap_resolver.gd:179), [command tests](/Users/Katharina/godot/Armada/tests/unit/test_displacement_commands.gd:234)

Canonical state:

- With atomic batch commit, tentative drag positions and placement order need not be canonical. Save/load or reconnect can reconstruct from the final ship pose, active Maneuver identity, canonical squadron positions, and a recoverable unresolved displacement identity/set.
- If the exact affected set is reliably re-derived from those facts, no additional placement-progress state is necessary. Otherwise, the minimum durable displacement state is the Maneuver identity, controller, and affected squadron references—not tentative positions.
- Incremental per-squadron commits would require canonical committed/remaining sets and make reconstruction, rollback, and maximum-proof semantics materially more complex.
- This follows accepted reconstruction and non-authority rules. [SMI-080/081](/Users/Katharina/godot/Armada/docs/requirements/gameplay_interactions/ship_maneuver_interaction.md:653), [ADR-010](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md:73)

## 2. Viable displacement approaches

| Approach | Rules fidelity | Complexity | Network/replay | Architecture fit | UX |
|---|---|---:|---|---|---|
| **A. Free atomic batch + authoritative global validator** | High | Medium–High | High; accepted coordinates are recorded | High; existing semantic batch boundary | Medium; failures may be discovered at final commit |
| **B. Guided direct-ring-first placement, final atomic commit** | High | High | High; guidance remains transient | High | High; capacity/chain feedback reduces late rejection |
| **C. Authority proposes a deterministic maximum-touch arrangement; player accepts, assigns identities, or adjusts it** | High if free adjustment remains available | Medium–High | Very high | High | Medium–High; less frustrating but constrains interaction if made mandatory |
| **D. Retry, then authority-proposed deterministic fallback** | Conditional on Owner approval | Medium–High | High if final coordinates are recorded | High | High accessibility; weaker player control if fallback becomes compulsory |

The proposed random fallback is technically replayable only if authority records the final coordinates. Re-generating from a seed would also require fixed PRNG, candidate ordering, geometry precision, and version semantics. It adds no rules value and is less robust than a deterministic legal proposal.

## 3. Recommendation — not a decision

Recommend **Approach A**, with optional deterministic guidance or proposal layered on later.

It is the smallest reliable architecture change: retain player-controlled free placement, validate one atomic semantic batch, and use an equal-circle/offset-boundary capacity solver solely to prove maximum touching and full-chain legality. Tentative UI state remains disposable.

A forced automatic fallback, fixed slot system, grid approximation, or random placement should require explicit Owner approval because each can narrow the tabletop player’s placement freedom.

## 4. Continuation-composition findings

The current processor independently evaluates five post-success sources:

1. timing-window continuation;
2. attack/inspection continuation;
3. ship-commanded Squadron completion;
4. declined Squadron Move completion;
5. Ship Phase termination after persistent damage.

If more than one returns a command, it logs a conflict and enqueues none; there is no current priority rule. [CommandProcessor](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:397)

Concrete competition scenarios:

- A command closes a timing opportunity while also satisfying an attack or Maneuver enclosing boundary.
- A Maneuver damage command destroys the active ship while Maneuver would otherwise resume; destruction/phase termination must prevent return to a nonexistent Maneuver.
- Existing Maneuver damage observers enqueue damage before post-success continuations. A simultaneously queued Maneuver continuation could become stale after that damage. Existing tests prove observer follow-ups precede and can invalidate a timing continuation. [ordering test](/Users/Katharina/godot/Armada/tests/unit/test_timing_window_command_protocol.gd:173)
- `resolve_immediate_effect` participates in attack continuation when an attack is active. A valid active attack and executable Maneuver should be mutually exclusive; coexistence is an invariant failure, not a case for arbitrary priority.
- Commanded-Squadron completion and declined-Move completion belong to Squadron Activation contexts and should likewise be ineligible during a live Maneuver consequence.

Accepted architecture already determines composition:

- Nested work returns through existing enclosing purpose-specific owners; no stored generic continuation exists. [ODR-001](/Users/Katharina/godot/Armada/docs/architecture/decision_workbooks/ODR-001-composed-return-convergence-principle.md:49)
- ADR-006 explicitly assigns nested Maneuver consequences back to the active Maneuver boundary. [ADR-006](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-006-canonical-ship-activation-boundary-ownership.md:229)
- TimingWindowOrchestrator owns timing-window completion and re-derivation. [ADR-005](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md:88)
- The existing post-success seam may perform bounded purpose-specific evaluation but cannot become a manager, stack, queue, or FSM. [CON-007](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-007-post-attack-continuation-release-contract.md:242)

Conclusion: `ManeuverExecutionContinuation` can compose without new architecture. Priority is derivable from enclosing ownership:

- an active nested timing/package decision blocks Maneuver;
- Maneuver re-evaluates after that child completes;
- destruction terminates the Maneuver boundary;
- unrelated Attack/Squadron owners must be mutually excluded by canonical guards.

Therefore **B8 is an implementation-allocation and guard-definition problem, not a missing Owner decision**. It becomes an architecture question only if a valid canonical state can still produce two non-nested, simultaneously required transitions.

## 5. Minimum obstacle capability prerequisites

The standard game uses the six core-set shapes: three asteroid fields, two debris fields, and one station. [RRG standard pool](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:789)

| Type | Maneuver effect and choice | Current status | Minimum prerequisite |
|---|---|---|---|
| **Asteroid field** | Deal one faceup damage card; no obstacle-level choice, though the drawn card may create an immediate choice | Catalog only; no gameplay obstacle integration | Missing obstacle RCP; new authoritative detection/invocation; integrate existing damage-deck/immediate-effect pipeline |
| **Debris field** | Suffer two damage on one hull zone; ship owner chooses the zone | No gameplay obstacle integration | Missing obstacle RCP; new authoritative hull-zone choice and damage invocation |
| **Station** | Ship may discard one faceup or facedown damage card; owner chooses whether and which card | No gameplay obstacle integration | Missing obstacle RCP; new optional choice/visibility/semantic discard path |

Rules evidence: [obstacle effects](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:730), [unspecified hull-zone ownership](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:275).

No obstacle Rule Capability Package currently exists. Catalog metadata explicitly says `NOT_INTEGRATED`. [representative asteroid record](/Users/Katharina/godot/Armada/Resources/Game_Components/obstacles/asteroid_1.json:17)

Minimum package work is the three Maneuver-overlap behavior slices above, covering authoritative geometry, invocation, player choices, command/state ownership, save/load, replay, Network/visibility, and tests. Attack obstruction can remain a separate slice; CON-003 permits coherent partial capabilities. [CON-003 granularity](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-003-rule-capability-contract.md:349)

## 6. Minimum Maneuver-triggered damage-card prerequisites

| Card | Required behavior | Current implementation | Prerequisite classification |
|---|---|---|---|
| **Thruster Fissure** | When the ship changes speed by at least one as part of its Maneuver, suffer one damage | Registered observer and command-backed damage exist | Missing RCP; existing implementation needs exact timing/identity integration |
| **Damaged Controls** | During Move Ship, overlapping a ship or obstacle deals one additional facedown card | Registered observer exists, but current `did_overlap` coverage is incomplete without obstacles | Missing RCP; existing implementation needs obstacle and Maneuver-boundary integration |
| **Ruptured Engine** | After executing a maneuver at speed greater than one, suffer one damage | Registered observer and command-backed damage exist | Missing RCP; existing implementation needs composed-return/exact-once integration |

Evidence: [card data](/Users/Katharina/godot/Armada/Resources/Game_Components/damage_cards.json:36), [ManeuverRuleResolver](/Users/Katharina/godot/Armada/src/core/movement/maneuver_rule_resolver.gd:9), [registered production rules](/Users/Katharina/godot/Armada/src/autoload/rule_bootstrap.gd:9), [damage command](/Users/Katharina/godot/Armada/src/core/commands/persistent_effect_damage_command.gd:1).

The existing implementations are not sufficient RCP evidence by themselves; CON-003 explicitly says a hook, metadata claim, or individual test does not establish integration. [CON-003 checklist](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-003-rule-capability-contract.md:206)

`Thrust Control Malfunction` modifies Maneuver yaw but is not a Maneuver-triggered effect, so it is outside this prerequisite list under the settled Owner scope. Likewise, asteroid draws do not expand this prerequisite exercise into packages for every possible immediate damage card.

The three packages must pin exact timing. Current implementation collapses all three into `ExecuteManeuverCommand` observers, while the RRG distinguishes “when,” “during Move Ship,” and “after” timings and gives a player ordering control over their same-timing effects. [RRG timing](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:356), [Damaged Controls FAQ timing](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:2571)

## 7. Geometry/data prerequisites

Required before obstacle consumption:

- Authoritative local-space footprint contours for all six core obstacle tokens—not sprite rectangles, alpha bounds, or bounding-box factors.
- Stable `data_key` association, physical scale, origin, orientation, winding/closure convention, and version/hash behavior across peers.
- Authoritative transformed-polygon overlap against the accepted rectangular `ShipBase`.
- Defined boundary semantics for “part of base on top”: touching alone versus positive-area intersection, with robust deterministic numerical predicates.
- Tests for rotation, containment, edge/corner contact, multiple overlaps, speed zero, save/load, replay, and Network catalog consistency.

Current setup state already records `data_key`, normalized position, rotation, placing player, and placement order, which is enough to locate an authoritative contour once supplied. [setup obstacle state](/Users/Katharina/godot/Armada/src/core/commands/commit_setup_obstacle_command.gd:79)

Current obstacle geometry is explicitly an oriented box derived from sprite-bound factors and is therefore unsuitable as rules authority. [shape metadata](/Users/Katharina/godot/Armada/Resources/Game_Components/obstacles/asteroid_1.json:17), [current box construction](/Users/Katharina/godot/Armada/src/core/setup/setup_obstacle_validator.gd:134)

For squadrons, the fixed circular diameter and board dimensions already exist. Required work is a single authoritative circle/contact policy—not additional base-size data.

## 8. Remaining genuine Owner questions

1. Which displacement interaction/enforcement model should be accepted: reject-only, guided validation, deterministic proposal, or an authorized fallback?
2. May authority ever force or auto-accept a placement after retries, or must the non-moving player always make the final placement choice?
3. What is the exceptional policy if no legal complete placement exists even with second-ring placement inside the board? The RRG supplies no recovery rule for a fully blocked state.
4. Which source and verification process will be accepted as authoritative for each of the six obstacle contours?
5. If exact RRG timing analysis does not uniquely order Damaged Controls, obstacle resolution, and other after-Maneuver effects, what Owner interpretation should the corresponding RCP record?
6. If a slot/grid/quantized displacement method is considered, may it restrict otherwise legal tabletop positions? This is a rules/UX decision, not merely numerical implementation detail.

Not genuine Owner questions:

- heterogeneous squadron sizes;
- continuation manager architecture;
- a generic priority stack/queue/FSM;
- multiple-obstacle controller assignment or displacement-before-obstacles;
- whether core obstacle effects and the three named damage-card effects need RCPs.

## 9. Recommended sequencing before BUG-043 revision

1. Owner chooses the displacement interaction/fallback and impossible-placement policies.
2. Establish and approve the authoritative six-shape obstacle geometry source.
3. Prepare the three obstacle-overlap capability slices and the three Maneuver-triggered damage-card packages, including timing and ownership evidence.
4. Obtain the required CON-003 Owner reviews; do not mark anything `Integrated` through this analysis.
5. Correct accepted Maneuver requirements where they conflict with the settled automatic tool behavior, adding the chosen displacement semantics and approved rule-package timing interpretations.
6. Refine the existing purpose-specific continuation allocation and its mutual-exclusion/destruction guards; no new architecture document is indicated.
7. Only then revise BUG-043 to reference the approved requirements, geometry authority, package gates, and implementation allocations.
8. Implement and verify the prerequisite slices before the BUG-043 semantic cutover.

## Follow-up status

This analysis is preserved as discovery evidence.

Remaining Owner decisions are to be resolved through Q&A before normative
requirements, Rule Capability Packages, and the BUG-043 implementation workbook
are revised.

Do not treat recommendations in this document as accepted Owner decisions.

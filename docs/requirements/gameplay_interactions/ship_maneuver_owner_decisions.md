# Ship Maneuver Owner Decision Record

**Status:** Owner decisions — input to normative refinement
**Scope:** Ship Maneuver / BUG-043 prerequisite convergence
**Related requirement:** `docs/requirements/gameplay_interactions/ship_maneuver_interaction.md`
**Related discovery:** Ship Maneuver prerequisite impact analysis and Maneuver consequence timing discovery

## 1. Purpose and authority

This document preserves Project Owner decisions made after the Ship Maneuver prerequisite discovery and follow-up timing discovery.

Its purpose is to prevent loss, reinterpretation, or reconstruction of Owner decisions while the accepted Ship Maneuver requirements, Rule Capability Packages, and BUG-043 implementation workbook are subsequently refined.

These decisions are intentional project requirements and interpretations. Where an existing Ship Maneuver requirement conflicts with a decision recorded here, the normative requirement must be refined rather than silently preserving the conflict.

This record does not itself design implementation mechanisms, authorize a generic Maneuver state machine, approve a Rule Capability as `Integrated`, or replace the accepted architecture governing canonical ownership and composed return.

---

## 2. Maneuver-tool side selection

### Decision

Armada intentionally retains the existing deterministic automatic selection of Maneuver-tool side.

The player does **not** receive an additional choice between legal left/right Maneuver-tool placements when both are possible.

Existing production behavior is accepted and must not be redesigned merely to reproduce the corresponding tabletop placement choice.

Speed-0 support is the required extension to the existing behavior.

Existing requirements, including SMI-021 where applicable, must be corrected if they require explicit player selection of Maneuver-tool side.

### Rationale

Exposing an additional side-selection interaction provides insufficient gameplay value in the digital implementation to justify the additional interaction and state complexity.

The existing deterministic behavior is considered an acceptable digital simplification.

---

## 3. Authoritative obstacle geometry

### Decision

Each core obstacle requires an authoritative gameplay footprint that accurately represents the physical obstacle token.

Approximate sprite bounds, bounding rectangles, `SPRITE_BOUNDS_FACTOR`, or other presentation approximations must not become authoritative obstacle-collision geometry.

### Canonical contour source

The six core obstacle contours shall be derived once from the existing official obstacle artwork/assets, provided those assets can be verified as sufficiently faithful to the physical token outlines and known physical scale.

The resulting verified contours become explicit canonical gameplay geometry data.

Runtime gameplay must not derive authoritative collision geometry dynamically from sprites, sprite bounds, alpha masks, or presentation scaling.

Once accepted, canonical obstacle geometry remains independent of later artwork or presentation changes.

If a particular source asset cannot support sufficiently accurate contour derivation, an alternative authoritative source or measurement must be used for that obstacle rather than silently substituting an approximate footprint.

### Rationale

Obstacle shapes are irregular enough that approximate rectangular bounds can materially change gameplay outcomes.

At the same time, runtime dependence on presentation assets would violate the canonical/presentation boundary and introduce avoidable replay, Network, and maintenance risk.

A one-time derivation and verification provides sufficient tabletop fidelity while keeping runtime gameplay deterministic and presentation-independent.

---

## 4. Authoritative ship collision footprint

### Decision

Armada intentionally retains the existing simplified rectangular `ShipBase` footprint as the authoritative ship footprint for ship-overlap/collision resolution.

The digital implementation does not need to reproduce additional physical shield-dial assemblies, plastic framing, or other tabletop-model geometry around the ship base.

Where another rule legitimately requires a different geometric test, such as a play-area rule, that rule may use its appropriate purpose-specific footprint. This decision does not require one universal geometry representation for every rule.

### Rationale

The existing rectangular representation is sufficiently close for the digital implementation.

Additional physical-detail geometry would materially increase implementation and validation complexity without sufficient gameplay benefit.

This is an intentional digital approximation, not an accidental limitation.

---

## 5. Core obstacle Rule Capability ownership

### Decision

Core obstacle Maneuver effects must be integrated through the CON-003 Rule
Capability Package architecture before accepted release/cutover depends on
those effects. Owner Decisions 26--27 permit candidate-code-complete paths to run
together earlier in the unreleased 7/10/7 Integration Candidate solely to
gather the required evidence.

The baseline prerequisite scope is limited to the core Maneuver-overlap behavior required for:

- asteroid fields;
- debris fields;
- station.

BUG-043/Maneuver may determine that the committed Maneuver has produced an applicable obstacle interaction and may return through the purpose-specific Maneuver boundary, but BUG-043 must not become the canonical owner of asteroid, debris, or station rules.

Each required obstacle capability must establish its own authoritative effect/choice ownership and required save/load, replay, Network, recovery, and verification behavior.

BUG-043 must not invent a generic `ResolveManeuverObstacleCommand` merely to bypass missing Rule Capability ownership.

### Rationale

Obstacle rules are independent gameplay capabilities rather than intrinsic properties of the Maneuver implementation.

Embedding them in BUG-043 would create the wrong ownership boundary and would circumvent CON-003.

The prerequisite is deliberately narrow: it does not require unrelated obstacle capabilities such as attack obstruction to be completed unless required by the Maneuver slice.

---

## 6. Maneuver-triggered damage-card Rule Capabilities

### Decision

Damage-card effects required by the baseline Maneuver lifecycle must be
integrated through CON-003 Rule Capability Packages before accepted
release/cutover depends on them. Owner Decisions 26--27 permit candidate-code-
complete paths to run together earlier in the unreleased 7/10/7 Integration
Candidate solely to gather the required evidence.

The currently identified prerequisite scope is:

- Thruster Fissure;
- Damaged Controls;
- Ruptured Engine.

BUG-043 must not absorb canonical ownership of these card rules.

This decision does **not** authorize or require a general integration project for every damage card.

Other damage cards remain outside this prerequisite unless evidence demonstrates that they are required for the baseline Maneuver lifecycle.

### Rationale

The existing implementation contains Maneuver-related card behavior, but implementation hooks or generic effect IDs do not establish Rule Capability ownership.

Keeping card rules purpose-specific prevents Maneuver from becoming a generic rule-effect owner while limiting prerequisite expansion.

---

## 7. General cumulative damage-card principle

### Decision

Faceup damage-card effects are cumulative in general.

Each individual **faceup damage-card instance** is an independent active rules effect unless that card or another applicable rule explicitly establishes otherwise.

Therefore:

- two different applicable faceup damage cards each provide their respective effect;
- two identical applicable faceup damage cards each provide their effect independently;
- multiple card instances must not be collapsed merely because they share a card name, card type, rule ID, or `effect_id`;
- facedown damage cards do not provide active damage-card effects.

Where multiple applicable faceup damage-card effects belonging to the same player share the same timing, each effect resolves individually. Where the general timing rules assign ordering of those effects to that player, that player chooses their resolution order.

### Rationale

Card-instance identity matters to gameplay.

Treating an effect type as a Boolean such as “ship has Damaged Controls” loses legitimate cumulative effects when multiple faceup instances are present.

This principle is broader than BUG-043 and must eventually be represented at the appropriate damage-card/Rule Capability authority boundary.

---

## 8. Squadron displacement controller

### Decision

When a ship Maneuver displaces squadrons, the player opposing the player who moved the ship controls placement of the displaced squadrons.

This applies regardless of ownership of the individual displaced squadrons and preserves the existing interaction behavior.

### Rationale

This follows the intended Armada displacement interaction and prevents the moving player from gaining control over placement caused by their own ship movement.

---

## 9. Squadron displacement — authoritative placement semantics

### Decision

Squadron displacement remains player-controlled, but the final proposed displacement is authoritatively validated as a complete batch.

Tentative drag positions, exploration, and placement order remain transient.

Authority must determine the maximum number of affected squadrons that can legally be placed directly touching the moved ship.

The placement player must not gain an advantage by deliberately choosing an inefficient placement order or arrangement that causes fewer squadrons to touch the ship than legally possible.

A submitted batch is invalid if it places fewer squadrons directly touching the moved ship than the authoritative maximum.

Squadrons that are not part of the maximum direct-touch set must satisfy the applicable secondary placement requirement, including the requirement that they touch a squadron that directly touches the moved ship.

All squadron bases are treated as the same fixed size.

### Rationale

Simple per-squadron validation cannot establish compliance with the maximum-touch requirement.

An early legal placement can consume space and make a later placement appear impossible even though a better complete arrangement exists.

The authoritative question is therefore whether the **complete arrangement** satisfies the rules, not whether each placement was locally legal when submitted.

Keeping tentative placement transient avoids introducing unnecessary canonical placement-progress state.

---

## 10. Squadron displacement assistance

### Decision

When the player proposes an invalid or suboptimal displacement arrangement, the digital implementation should assist the player rather than rely on an arbitrary retry counter.

At minimum, the system should communicate the authoritative placement deficiency, such as the required maximum number of directly touching squadrons compared with the submitted arrangement.

The implementation may additionally provide deterministic placement guidance or a legal placement proposal.

Player-controlled placement remains the normal baseline interaction.

There is no accepted “two failed attempts then random placement” rule, and random fallback placement is not part of the baseline.

### Rationale

The authoritative maximum-placement analysis is already required to prevent exploitation.

Using its result to provide useful feedback is preferable to repeatedly rejecting the player without explanation or introducing an arbitrary retry threshold.

Random placement adds replay/determinism complexity without adding rules value.

---

## 11. Genuinely unplaceable displaced squadrons

### Decision

Authority must distinguish genuine inability to place a displaced squadron from inability caused by the player's chosen placement order or inefficient arrangement.

Authority first determines the maximum rules-legal placement for the complete affected set.

The opposing player then places the squadrons subject to that authoritative constraint.

After maximum legal placement has been established, any displaced squadron that genuinely cannot be legally placed in the play area is destroyed.

A player may not manufacture this destruction outcome through deliberately inefficient placement.

The Project Owner interprets the applicable Armada displacement and play-area rules as requiring destruction when a displaced squadron is genuinely unable to be returned legally to the play area after maximum legal placement has been established.

For Armada, that destruction is therefore treated as a rules consequence of genuine inability to return the displaced squadron legally to the play area. It is not an optional player choice, random fallback, or arbitrary digital penalty.

### Rationale

Dense Squadron formations, particularly around a small moving ship, can create cases where the displaced set exceeds the legally available placement space.

The maximum-placement requirement must be resolved before determining that a squadron is genuinely unplaceable; otherwise the placement player could exploit placement order to destroy squadrons improperly.

This records the Project Owner's rules interpretation resolving the ambiguity identified by the preserved consequence-timing discovery.

---

## 12. Final Maneuver geometry precedes consequences

### Decision

The authoritative final ship position and resulting overlap facts are established before consequences dependent on that geometry are resolved.

Intermediate plotted positions, reduced-speed attempts, collision-resolution attempts, or other transient positions used to determine the final Maneuver result do **not** independently trigger gameplay consequences.

Once final geometry has been established, consequences operate from those authoritative facts according to their applicable purpose-specific timing and ordering.

### Rationale

Intermediate algorithmic attempts are implementation mechanics, not independent gameplay events.

Allowing them to trigger effects could cause the number or order of effects to depend on the collision-search algorithm rather than the Maneuver actually executed.

This also provides a stable authoritative boundary for Network, replay, save/load, and recovery.

---

## 13. Maneuver consequence hierarchy

### Decision

After authoritative final geometry has been established, baseline Maneuver consequences resolve in this high-level order:

1. **Squadron displacement**
2. **Ordinary ship-collision consequences**
3. **Effects triggered by the ship collision**
4. **Obstacle-overlap consequences**
5. **Remaining applicable post-execution Maneuver effects**

This is the accepted purpose-specific consequence hierarchy.

Effects within each consequence group continue to obey their individual rules timing and applicable ordering rules.

Survival and applicability are re-evaluated after each consequence.

### Rationale

Squadron displacement completes the board geometry produced by the ship's final position. It therefore occurs first and must not disappear merely because a subsequent collision consequence destroys the moving ship.

Ordinary collision consequences are resolved before effects triggered by that collision.

Obstacle consequences then resolve against the resulting surviving canonical state.

Remaining post-execution effects follow after the physical board-interaction consequences have converged.

The hierarchy avoids allowing implementation-specific intermediate movement attempts to determine gameplay ordering.

---

## 14. Squadron displacement survives later ship destruction

### Decision

Required Squadron displacement is completed before ship-collision consequences.

If a subsequent collision consequence destroys the moving ship, already-completed final-position establishment and Squadron displacement are not undone.

### Rationale

The ship's final movement has already displaced the affected squadrons.

Those squadrons must leave the occupied space even if the moving ship is subsequently destroyed as a consequence of the collision.

This distinguishes geometry convergence from later survival-dependent Maneuver effects.

---

## 15. Damaged Controls — trigger multiplicity

### Decision

Each individual applicable **faceup instance** of Damaged Controls triggers **once per Maneuver** if that Maneuver overlaps one or more ships and/or obstacles.

The same Damaged Controls card instance does not trigger repeatedly because:

- multiple ships were overlapped;
- multiple obstacles were overlapped;
- both a ship and an obstacle were overlapped;
- collision resolution attempted multiple reduced speeds or intermediate positions.

Multiple faceup copies of Damaged Controls trigger independently and cumulatively.

Facedown copies do not trigger.

### Rationale

The gameplay event is the Maneuver producing an applicable overlap, not each internal collision-search attempt.

Per-attempt triggering would make card behavior depend on implementation mechanics.

The general cumulative damage-card principle requires every applicable faceup card instance to retain its own effect.

---

## 16. Ship-collision consequence ordering

### Decision

Within the ship-collision consequence boundary:

1. resolve the ordinary ship-collision consequence;
2. then resolve applicable effects triggered by that ship collision.

Where Damaged Controls is applicable because the Maneuver overlapped a ship, its applicable faceup instances resolve within this collision-triggered effect boundary.

Where multiple collision-triggered effects belonging to the same player share the same timing and the general timing rules assign ordering to that player, that player chooses their order.

Each effect resolves individually.

Survival and applicability are re-evaluated between consequences.

### Damaged Controls obstacle-overlap allocation resolved by normative refinement

Damaged Controls also applies when the qualifying Maneuver overlap consists of
obstacle overlap without ship collision. Accepted SMI-064 now places that
single obstacle-only resolution after collision-triggered effects and before
obstacle consequences.

When a Maneuver overlaps both a ship and an obstacle, the same faceup Damaged
Controls instance resolves no more than once during that Maneuver. The ship-
collision boundary owns that instance's resolution and the obstacle-only
boundary excludes it.

### Rationale

The collision is the underlying gameplay event for ship-collision consequences. Its ordinary consequence resolves before additional rules/card effects triggered by that collision.

This creates a stable and understandable event/consequence/effect relationship and prevents incidental implementation ordering from becoming rules authority.

Damaged Controls has broader applicability than ship collision alone, so its obstacle-only placement must not be inferred merely from the ship-collision ordering decision.

---

## 17. Squadron displacement versus later effects

### Decision

Required Squadron displacement resolves before Ruptured Engine and other remaining post-execution Maneuver effects.

### Rationale

Displacement completes the board geometry resulting from the committed final ship position.

It is therefore part of resolving the physical result of the Maneuver rather than a later optional/card consequence.

---

## 18. Obstacle consequences versus remaining post-execution effects

### Decision

Applicable obstacle-overlap consequences resolve before remaining post-execution Maneuver card/rule effects such as Ruptured Engine.

Obstacle consequences remain purpose-specific and resolve according to their own rules.

After the obstacle consequence boundary has converged, remaining applicable post-execution effects resolve according to their individual timing and ordering rules.

### Rationale

Physical board-interaction consequences should converge before remaining post-execution card/rule effects.

This produces a deterministic hierarchy:

`final geometry → displacement → collision → collision-triggered effects → obstacles → remaining post-execution effects`

rather than allowing the presence of a particular damage card to reorder the core board-resolution procedure.

---

## 19. Multiple obstacle ordering

### Decision

Where a Maneuver overlaps multiple obstacles and the applicable rules permit their effects to resolve in any order, the moving ship's controlling player chooses the order unless an accepted rule or Rule Capability assigns that choice elsewhere.

This is an Owner interpretation for rules-silent ordering and does not override explicit RRG or Rule Capability ordering.

### Rationale

The RRG permits multiple obstacle effects to resolve in any order but does not always assign an actor for that choice.

Assigning the choice to the moving ship's controller provides a deterministic digital interaction without introducing a generic ordering owner.

---

## 20. Survival and applicability during consequence resolution

### Decision

Survival and applicability are re-evaluated after each resolved Maneuver consequence.

If the moving ship is destroyed, later ship-dependent consequences must not be fabricated or executed against a ship that has left play.

This does not undo already-completed final geometry or Squadron displacement.

Independently applicable consequences belonging to another surviving game object retain their own purpose-specific authority.

### Rationale

Damage can destroy a ship during consequence resolution.

Continuing to apply later ship-dependent effects blindly would create effects against nonexistent canonical state, while rolling back already-resolved geometry would incorrectly erase gameplay that has already occurred.

---

## 21. Continuation architecture

### Decision / confirmed architectural constraint

No generic Maneuver continuation manager, continuation stack, callback queue, generic FSM, or generic rule-effect owner is authorized.

Nested Maneuver consequences return through their existing purpose-specific owners and the active Maneuver boundary is re-evaluated from canonical state.

The prerequisite discovery concluded that continuation composition is an implementation/guard-allocation problem under the already accepted composed-return architecture, not a missing Owner architecture decision.

If implementation evidence later demonstrates a valid canonical state that genuinely requires two non-nested simultaneous continuations, implementation must stop for architecture review rather than inventing a priority framework.

### Rationale

Accepted composed-return architecture already provides the ownership principle.

A new generic continuation mechanism would duplicate purpose-specific authority and recreate precisely the generic state/continuation architecture that the existing ADRs and contracts avoid.

---

## 22. Normative refinement boundary

The accepted Ship Maneuver requirements and the twelve RCPs translate these
decisions into their applicable normative and traceability surfaces. Owner
Decisions 24--26 are additionally incorporated by the 2026-09-12 audit
refinement.

The completed refinement addresses:

- Ship Maneuver interaction requirements;
- obstacle Rule Capability Packages for the required asteroid, debris, and station Maneuver slices;
- Rule Capability Packages for Thruster Fissure, Damaged Controls, and Ruptured Engine;
- the general cumulative faceup damage-card principle at the appropriate damage-card/rule authority level;
- authoritative obstacle geometry data and verification requirements;
- authoritative Squadron displacement validation semantics;
- purpose-specific Maneuver consequence ordering and recovery;
- the normative placement of Damaged Controls when its qualifying Maneuver overlap consists only of obstacle overlap;
- Structural Damage exhaustion with both damage piles empty;
- ordinary Station ownership and unsupported objective fail-closed behavior;
  and
- the unreleased Integration Candidate evidence sequence.
- Maneuver commitment versus canonical final-transform application timing.

This decision record must **not** be used as permission to expand BUG-043 into ownership of those prerequisite capabilities.

BUG-043 should be revised only after the required normative authority has converged sufficiently for the workbook to reference those decisions rather than reconstruct them.

---

## 23. Explicitly excluded conclusions

This decision record does **not** authorize:

- a generic Maneuver FSM;
- a generic consequence queue or stack;
- a generic continuation owner;
- a generic obstacle-effect command solely for BUG-043;
- runtime sprite-derived authoritative obstacle collision;
- heterogeneous Squadron base sizes;
- random Squadron displacement fallback;
- arbitrary retry-count behavior;
- automatic player-side Maneuver-tool selection changes beyond the already accepted deterministic behavior;
- integration of all damage cards;
- integration of unrelated obstacle capabilities;
- treating intermediate collision-search positions as independent gameplay events;
- collapsing multiple faceup damage-card instances into one effect;
- resolving the same faceup Damaged Controls instance more than once during one Maneuver merely because multiple qualifying overlaps occurred.

---

## 24. Structural Damage when both damage piles are empty

### Decision

When Structural Damage requires one additional facedown damage card, the
ordinary damage-deck rule first recycles and shuffles the discard pile if the
draw pile is empty.

If both the draw pile and discard pile are empty, no additional damage card is
dealt. The specific Structural Damage card still flips facedown and its
immediate-resolution obligation completes normally through its actual
purpose-specific enclosing boundary.

Authority does not synthesize damage, create a placeholder card, or leave a
pending interaction merely because no physical card is available.

### Rationale

The card requires dealing another physical damage card. When none exists in
either canonical pile, there is no legal physical card to transfer. Completing
the remaining printed effect preserves exact-once resolution without inventing
state or stranding the enclosing Attack, Maneuver, or debug application.

---

## 25. Ordinary Station behavior and objective suppression

### Decision

The Station Rule Capability owns only ordinary Station behavior.

Contested Outpost and any other objective that modifies or suppresses Station
behavior retain their own purpose-specific objective capability ownership. If
such an objective is active but the required objective capability is not
`Integrated`, the unsupported configuration fails closed before ordinary
Station behavior is invoked. The implementation must not silently apply the
ordinary Station effect as though the objective were absent.

BUG-043 does not absorb Contested Outpost or other objective integration and
does not create a generic Station-modifier, objective-modifier, or obstacle-
modifier framework.

### Rationale

Applying the ordinary effect in a configuration known to modify or suppress it
would produce incorrect gameplay. Failing closed preserves responsibility-
specific ownership without expanding the Maneuver integration into an
objective project or speculative framework.

---

## 26. Unreleased Integration Candidate evidence sequence

### Decision / workflow condition

The coordinated Maneuver implementation uses an **Unreleased Integration
Candidate** to gather CON-003 and TEST-003 evidence without creating a new
CON-003 lifecycle status.

The required sequence is:

`normative Draft acceptance → candidate-code-complete → unreleased testable
Integration Candidate → TEST-003 evidence → implementation-complete / Tested
readiness → explicit Owner Integrated approval → accepted release/cutover`

Only after the whole workbook reaches Decision 27's `candidate-code-complete`
condition and every activation prerequisite is satisfied may the complete
purpose-specific paths be activated together in an unreleased
save-7/replay-10/protocol-7 candidate. Runtime,
Network, recovery, replay, visibility, and cross-package evidence may then be
gathered before Owner `Integrated` approval. An incomplete path must never
become reachable merely to support incremental testing.

The candidate is not an RCP status, does not imply `Tested` or `Integrated`,
and is not an accepted release. Owner approval remains distinct for every RCP.

### Rationale

Live cross-package and distributed evidence requires the completed paths to be
reachable together, while CON-003 requires that evidence before an Owner can
approve `Integrated`. An unreleased candidate supplies that evidence boundary
without weakening package status or exposing incomplete behavior in a release.

---

## 27. Candidate-code-complete and manual replay capture

### Decision / workflow condition

`candidate-code-complete` is the pre-evidence implementation condition for the
Ship Maneuver / BUG-043 workbook. It means **all Codex-owned implementation and
test code required by the workbook exists**, including replay-10 format and
version logic, serialization and passive application, fail-closed compatibility
handling, and automated non-fixture replay tests.

`candidate-code-complete` is a workbook execution condition only. It is not a CON-003 or RCP lifecycle status and does not mean `Implemented`, `Tested`,
`Integrated`, or TEST-003 `implementation-complete`.

The term `implementation-complete` remains reserved for the existing TEST-003
threshold: every applicable TEST-003 obligation has passing evidence. This
decision does not amend, weaken, or create an exception to TEST-003.

Replay files and fixtures are not Codex implementation work. Codex must never
create, generate, synthesize, regenerate, transform, patch, or relabel replay
files or fixtures. Only after the implementation is candidate-code-complete
and the unreleased candidate has otherwise converged through non-fixture
verification does execution reach:

**STOP FOR OWNER REPLAY CAPTURE.**

The Project Owner manually records genuine replay-10 Hot-Seat and Network
files. Only then may Codex resume to inspect, hash, compare, integrate, and
verify those Owner-created files.

### Rationale

The separate condition permits the complete code surface to become testable
without falsely claiming the evidence threshold that TEST-003 reserves for
`implementation-complete`. Manual replay capture remains an Owner action after
the candidate is stable, not a missing implementation task or a fixture-
generation workaround.

---

## 28. Maneuver commitment and canonical transform timing

### Decision

Maneuver commitment does **not** immediately apply the ship's committed final
board transform to canonical ship position/orientation.

Commitment atomically establishes:

- the committed Maneuver result;
- canonical selected speed;
- applicable Navigate resource consumption;
- the committed geometry/result facts required for subsequent resolution; and
- the active Maneuver execution record.

The ship remains at its pre-Maneuver canonical board transform while mandatory
post-commitment / pre-movement obligations resolve.

Thruster Fissure resolves within this interval: after Maneuver commitment but
before the committed final board transform is applied.

Only after all applicable pre-movement obligations have converged, and if the
ship remains eligible to continue the Maneuver, is the committed final board
transform applied atomically to canonical ship position/orientation.

If the ship is destroyed before that transform is applied, the committed final
transform is not applied. The accepted destruction and Maneuver-cleanup rules
govern termination.

This decision does not change the accepted ordering of consequences that occur
after the committed final board transform has been applied.

### Rationale

Maneuver commitment and physical movement are distinct authoritative events.

The committed Maneuver result must be durable and recoverable before mandatory
effects that occur after commitment can resolve, while effects such as Thruster
Fissure must still resolve before the ship physically moves to its committed
destination.

Applying the final canonical transform during commitment would make that timing
impossible and would contradict the accepted Thruster Fissure requirement.

Separating commitment from final-transform application preserves the accepted
Maneuver execution record, decision-equivalent recovery, purpose-specific
continuation, and consequence ordering without introducing a generic Maneuver
FSM or continuation mechanism.

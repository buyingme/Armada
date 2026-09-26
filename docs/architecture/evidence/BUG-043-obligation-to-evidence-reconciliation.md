# BUG-043 Obligation-to-Evidence Reconciliation

**Status:** Evidence / Read-Only Reconciliation
**Scope:** BUG-043 Ship Maneuver Capability Integration and directly intersecting BUG-048 / BUG-049 behavior
**Repository baseline:** `56850e4166552bffb83b70e63cce986b4cac7aa9`
**Purpose:** Reconcile accepted BUG-043 implementation-workbook obligations against the evidence that actually demonstrates each required production seam or property.

> This document is an evidence artifact, not an architecture decision, contract, requirement, or implementation workbook.
>
> `SUFFICIENT`, `PARTIAL`, `MISSING`, and `MISALIGNED` classify the available evidence, not implementation correctness. Except where a production defect is explicitly demonstrated, an evidence deficiency must not be interpreted as proof of a production defect.

Read-only reconciliation completed at `56850e4166552bffb83b70e63cce986b4cac7aa9`. The worktree was clean. No files were changed and no tests were run; classifications are based on the checked-in production paths, tests, genuine replay artifacts, and bug evidence.

### Evidence matrix

| Obligation | Required production seam/property | Existing evidence | Classification | Minimum gap closure |
|---|---|---|---|---|
| Active Maneuver ownership and identity | `ShipInstance` exclusively owns one identity-bound execution; strict legal-state validation | [execution-state tests](/Users/Katharina/godot/Armada/tests/unit/test_maneuver_execution_state.gd:14), aggregate-conflict and exact-schema tests in [candidate execute](/Users/Katharina/godot/Armada/tests/unit/test_candidate_execute_maneuver_command.gd:25) | **SUFFICIENT** | None for this property |
| Live Maneuver entry at speed 0 | Ship Activation controller must open the normal tool; top/end segment and speed controls must be live | Controller still bypasses the tool at [ship_activation_controller.gd:1606](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1606); tool logic prioritizes `"root"` at [maneuver_tool_state.gd:177](/Users/Katharina/godot/Armada/src/core/movement/maneuver_tool_state.gd:177); tests construct the tool after bypassing entry and explicitly expect a root segment at [test_maneuver_tool_state.gd:138](/Users/Katharina/godot/Armada/tests/unit/test_maneuver_tool_state.gd:138) | **MISALIGNED** | BUG-048 fix plus a real controller-entry test proving tool creation, end-segment rendering, controls, 0→0, and 0→1 |
| Navigate speed modification | Transient choice; authority derives and consumes minimum source atomically | Transient preview tests, command source-consumption tests, and genuine positive-speed Navigate history in both replay fixtures | **PARTIAL** | Add live controller evidence for 0→1; retain rejection evidence when no legal source exists |
| Commitment and transform timing | `execute_maneuver` commits speed/result but preserves board transform; later authority applies transform exactly once | [candidate execute](/Users/Katharina/godot/Armada/tests/unit/test_candidate_execute_maneuver_command.gd:25), [apply-transform](/Users/Katharina/godot/Armada/tests/unit/test_candidate_apply_maneuver_transform_command.gd:34), and live processor sequencing in [processor convergence](/Users/Katharina/godot/Armada/tests/unit/test_maneuver_command_processor_convergence.gd:37); replay histories preserve execute→apply order | **SUFFICIENT** | None for canonical timing |
| Rejection rollback | Invalid commitment changes no resources, speed, execution, transform, history, or projection-success state | Atomic snapshot tests and controller stale-preview guard in [BUG-043 tests](/Users/Katharina/godot/Armada/tests/unit/test_bug_043_maneuver_speed_convergence.gd:163) | **SUFFICIENT** | None |
| Final play-area destruction | Apply actual final transform, then terminate exceptionally without normal completion | Direct out-of-play command test at [test_candidate_apply_maneuver_transform_command.gd:83](/Users/Katharina/godot/Armada/tests/unit/test_candidate_apply_maneuver_transform_command.gd:83) | **PARTIAL** | One live `CommandProcessor` sequence asserting exactly one destruction cleanup, no `complete_maneuver`, and correct next selection/end-game |
| Squadron displacement | Complete maximum legal batch, correct controller, authoritative exclusion/destruction | Pure maximum-batch tests, command/recovery/passive tests, modal-router projection, and both genuine replay fixtures contain displacement | **SUFFICIENT** | None for normal displacement semantics |
| Ship collision | Immutable closest target; transform/displacement before two-target damage; no target reselection | Authority tests, collision command exact-once/passive tests, and Hot-Seat/Network replay histories | **SUFFICIENT** | Terminal destruction remains covered separately below |
| Obstacle contours and final-only detection | Approved six-token contours; positive-area contact policy; actual final transform including speed 0 | Catalog hash/load and real-token rotation tests in [obstacle overlap tests](/Users/Katharina/godot/Armada/tests/unit/test_obstacle_overlap_authority.gd:54); speed-zero command-level overlap evidence | **PARTIAL** | Add real-contour boundary/contact cases and a live speed-zero final-only overlap path after BUG-048 |
| Multiple-obstacle ordering | Controller chooses every current overlap exactly once; order remains immutable and each package returns sequentially | Identity/order unit tests; controller payload dispatch; replay fixtures exercise individual asteroid, debris, and station paths, but not a genuine multi-overlap sequence | **PARTIAL** | One live multi-obstacle scenario through choice projection, authenticated submission, sequential package resolution, and completion |
| Thruster Fissure | Per-physical-instance pre-movement suffered damage; destruction suppresses transform | Comprehensive direct command, passive, recovery, multiple-copy, timing, and lethal tests in [Thruster tests](/Users/Katharina/godot/Armada/tests/unit/test_candidate_resolve_thruster_fissure_command.gd:31) | **SUFFICIENT** for canonical rule behavior | Live composition, transport, and terminal cleanup evidence remain cross-cutting gaps |
| Damaged Controls | Item 3 versus item 4; ship+obstacle resolves once; multiple copies and speed 0 | Direct ship/obstacle/both-category, recovery, passive, and exact-once tests in [Damaged Controls tests](/Users/Katharina/godot/Armada/tests/unit/test_candidate_resolve_damaged_controls_command.gd:57) | **SUFFICIENT** for canonical rule behavior | Add live composed-return and real Network evidence |
| Asteroid | Exact faceup assignment; all six immediate branches nest and return through Asteroid | All six branches are exercised through actual assignment/record/resolve commands in [obstacle tests](/Users/Katharina/godot/Armada/tests/unit/test_candidate_obstacle_consequences.gd:57); Hot-Seat replay includes one nested immediate outcome | **SUFFICIENT** for canonical nesting | Live processor/Network return evidence for all six outcomes is still needed |
| Debris | Two sequential points to one zone; stop after lethal first point; passive convergence | Normal, lethal-first, lethal-second, shield, and passive tests; both replay fixtures traverse the normal live branch | **SUFFICIENT** for rule behavior | Add processor-owned lethal cleanup coverage |
| Station | Faceup/facedown/decline/no-option; hidden-safe selection; unsupported modifier fails closed | Direct tests for every action and fail-closed objective; genuine Hot-Seat and Network histories cover both selection forms | **SUFFICIENT** | Positive objective-modifier evidence remains correctly not applicable while no such capability is Integrated |
| Ruptured Engine | Post-obstacle, current-speed, still-faceup, per-instance resolution | Direct multiple-copy/order, speed, faceup, passive-lethal, and completion tests in [Ruptured Engine tests](/Users/Katharina/godot/Armada/tests/unit/test_candidate_resolve_ruptured_engine_command.gd:41) | **SUFFICIENT** for canonical rule behavior | Add live composition, save/reconnect, and replay evidence |
| Immediate-damage identity/lifecycle | Stable physical identity, public occurrence identity, one active record, concealment retirement, passive application | Extensive foundation, duplicate-location, redeal, destruction, filtering, and strict-install tests in [identity foundation](/Users/Katharina/godot/Armada/tests/unit/test_immediate_damage_identity_foundation.gd:20) | **SUFFICIENT** | Full production save/reconnect remains separate below |
| Six immediate-card semantic branches | Structural exhaustion/reshuffle; Projector tie; Life Support persistent blocker; Injured 0/1/many; Shield 0–2; Comm Noise unions/hidden dial | Branch-complete command tests in [immediate-effect tests](/Users/Katharina/godot/Armada/tests/unit/test_candidate_resolve_immediate_effect_command.gd:23), source matrix, Life Support rule tests, and debug UI tests | **SUFFICIENT** for command/rule behavior | Their promised all-source live/save/replay/Network matrices are not complete |
| Normal completion and ordinary composed return | Fresh no-work proof; one `OPEN→CONSUMED`; no duplicate completion | Processor test proves no-consequence live composition; replay fixtures prove obstacle→completion histories; Network acceptance proves completion→End Activation | **SUFFICIENT** for tested ordinary paths | Extend to the currently direct-only persistent-card paths |
| Live return after Thruster/Damaged Controls/Ruptured/all Asteroid outcomes | Accepted consequence must traverse live post-success composition to the next obligation or completion | Most tests call commands directly and then inspect `ManeuverExecutionEvaluator.next_action()`; this does not execute the live composition seam | **MISALIGNED** | Submit each family through `CommandProcessor` and assert the exact generated history/return |
| Pre-movement lethal branch | Thruster/immediate damage clears execution without transform or `CONSUMED`, then performs one exceptional return | Direct authority and passive tests prove suppression and state cleanup, but do not traverse processor-owned `destroy_unit` and enclosing return | **PARTIAL** | Live authority plus passive Network test through damage→`destroy_unit`→selection/end-game |
| Post-movement lethal branches | Preserve transform/displacement; collision/obstacle/Ruptured death suppresses normal return; last/non-last branches exact once | Asteroid has strong live processor tests for last and non-last ships; collision, Debris, and Ruptured lethal tests stop at direct command/passive application | **PARTIAL** | Repeat processor terminal assertions for collision, Debris point 1/2, Damaged Controls, nested immediate, and Ruptured Engine |
| Attack immediate-damage nesting | Attack assignment→immediate resolution→one `complete_attack`; destruction cleanup ordered correctly | Structural Damage traverses production processor integration at [test_current_attack_production_resume.gd:392](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:392); all six source bindings are otherwise direct | **PARTIAL** | Processor-level automatic and choice branches for the remaining five cards, including lethal cleanup |
| Network speed-zero Defense | Automatic no-defense continuation must use authoritative submission and proceed to damage/completion | Adjacent tests cover semantic speed-zero rejection and Hot-Seat no-token continuation, but not this Network branch; Owner evidence demonstrates unauthorized host submission in [BUG-049](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-049/issue.md:1) | **MISALIGNED** | BUG-049 repair plus a real Network test from Accuracy through Defense, damage, completion, and composed return |
| Hot-Seat/Network player authority and principal submission | Player decisions traverse the submitter associated with the actor’s authenticated principal; automatic commands remain authority-originated | Real two-process acceptance submits one positive-speed Maneuver as the client at [driver.gd:1312](/Users/Katharina/godot/Armada/tests/acceptance/network_resume/driver.gd:1312); replay transport covers both sides but bypasses fresh player authorization | **PARTIAL** | Real host/client authoring for Maneuver, obstacle order, displacement controller, card choices, and rejection by the wrong principal |
| Passive ordered application and non-synthesis | Protocol-7 results apply in order without passive RNG, decisions, returns, or hidden identity | Command-level passive tests span movement and damage; real-ENet replay baseline compares host/client final state | **PARTIAL** | Add current live transport scenarios for representative automatic, choice, rejection, and lethal chains rather than relying chiefly on replay-mode transport |
| Live projection versus reconstruction | Live transitions open actionable UI; reconstruction rebuilds the same decision without submitting commands | Uncommitted tool reconstruction is tested; consequence routing test injects `_pending_maneuver_action` directly at [test_ship_activation_controller.gd:351](/Users/Katharina/godot/Armada/tests/unit/test_ship_activation_controller.gd:351), bypassing evaluator→router→modal projection | **MISALIGNED** | Instantiate the real board/router for each choice family in both live-command and reconstruction modes; assert owner actionability and passive read-only behavior |
| Save/load/reconnect | Production save/install/reconnect must preserve uncommitted, committed pre/post-movement, nested decision, completed, and destroyed states | Narrow serializer/helper round-trips exist, but no production save/reconnect test installs an active Maneuver or its nested consequence through the full seam | **MISALIGNED** | Full `GameState`/save-manager round-trips plus two-endpoint reconnect for the workbook’s enumerated states |
| Replay semantics | Replay-10 records and deterministically reapplies semantic order without synthesizing follow-ups | Genuine Hot-Seat/Network fixtures cover positive Navigate, apply, displacement, collision, all obstacle types, and one Hot-Seat immediate branch; the real-ENet replay harness is appropriate for convergence | **PARTIAL** | Add non-fixture replay tests for persistent-card and remaining immediate branches; Owner-record fresh replay-10 evidence containing legal speed 0 and Maneuver destruction—the current fixtures contain neither |
| Exact-once terminal cleanup | No duplicate consequence, completion, destruction, return, or dangling nested state | Strong per-command duplicate guards and asteroid terminal tests; full live terminal chains are absent for several damage sources | **PARTIAL** | One table-driven processor test over every lethal source, asserting exactly one cleanup/return and zero invalid completion |

## Findings

1. **BUG-048 and BUG-049 are confirmed gaps.** BUG-048 is not merely missing coverage: production still contains the speed-zero entry bypass, and the tool-state test protects the wrong root-segment rendering. BUG-049 has genuine runtime evidence of an unauthorized principal submission; existing tests exercise adjacent Hot-Seat and Network states but not that branch.

2. **Additional gaps found:**

   - Production save/load and reconnect evidence does not cover active Maneuver or nested consequence states.
   - Consequence projection tests bypass the real evaluator/router entry.
   - Persistent-card and most immediate-card returns are tested by direct execution plus evaluator inspection, not through live post-success composition.
   - Authenticated Network authoring is incomplete for Maneuver consequence choices and displacement.
   - Real-contour tests do not fully cover boundary/contact behavior.
   - The current replay fixtures omit two explicit workbook requirements: legal speed zero and a Maneuver destruction path.
   - Replay coverage also omits Thruster Fissure, Damaged Controls, Ruptured Engine, and five of the six nested immediate-card outcomes.

3. **Production defects versus evidence-only deficiencies:**

   - Demonstrated production defects: BUG-048 and BUG-049.
   - No additional production defect is proven by this reconciliation.
   - The remaining findings are evidence deficiencies, although live continuation, terminal cleanup, reconstruction, and principal-submission gaps are high-risk because they sit on the same class of seam that exposed BUG-048/049.

4. **Minimum complete stabilization scope:**

   - Repair BUG-048 within the existing Maneuver entry/tool projection.
   - Repair BUG-049 within the existing authoritative Attack continuation/submission path without weakening principal checks.
   - Add focused production-seam coverage for live consequence composition, terminal cleanup, full save/reconnect, authenticated Network choices, and live-versus-reconstructed projection.
   - Complete the missing replay evidence only after code and non-fixture tests converge; any new replay fixture must remain Owner-recorded.

5. **Evidence to add during stabilization:**

   - Real GameBoard speed-zero entry/render/0→1/0→0 tests in Hot-Seat and Network.
   - Real Network speed-zero-defense attack through completion.
   - Processor-owned return and lethal cleanup tests for every Maneuver consequence family.
   - Full-state save/load and two-endpoint reconnect scenarios for all materially distinct pending and terminal states.
   - Authenticated host/client authoring and wrong-principal rejection tests.
   - Missing deterministic replay tests, followed by Owner-recorded speed-zero and Maneuver-destruction replay evidence.
   - Real-contour edge/contact characterization.

6. **Owner architecture decision:** none is currently required. The accepted ownership and continuation boundaries are sufficient. Owner action will later be required for manual replay capture and any RCP `Integrated` approvals; all twelve RCPs currently remain `Draft`, but those are scheduled governance actions rather than new architecture decisions.

---

## Stabilization Verification Refinement

**Status:** Accepted refinement of this evidence reconciliation
**Purpose:** Reduce the `PARTIAL` / `MISALIGNED` findings above to the minimum non-redundant verification set required for BUG-043 stabilization.

This refinement does not change the accepted BUG-043 architecture or implementation workbook.

BUG-048 and BUG-049 remain the only demonstrated production defects. V1–V9 are evidence-closure obligations and must not be interpreted as additional production defects unless execution demonstrates otherwise.

The stabilization package must not expand silently when verification exposes another defect. Any newly demonstrated defect must be recorded and dispositioned before scope expands.

## 1. Minimum non-redundant verification matrix

| ID | Exact property proven | Production seam traversed | Reconciliation gaps closed | Why other combinations need no production-path test | Evidence |
|---|---|---|---|---|---|
| V1 | A canonical-speed-0 ship enters the normal Maneuver interaction; the terminal/facing segment and controls render; both 0→0 and legal Navigate 0→1 commit through normal authority; illegal increases reject atomically | Real `GameBoard` → Ship Activation controller → Maneuver tool → `execute_maneuver` → normal continuation | Live speed-0 entry; Navigate live evidence; speed-0 final-only path prerequisite; BUG-048 | Navigate consumption, rollback, commitment, and speed-zero overlap semantics are already proven at command/unit level. Only the controller-entry and presentation seam is missing | Automated scene integration for both commits; one focused manual visual smoke. V6 supplies Network equivalence |
| V2 | One accepted result repeatedly re-derives the next Maneuver obligation, exposes genuine decisions, and ultimately completes once | Real Hot-Seat `GameBoard`/router/controller plus `CommandProcessor` post-success composition | Thruster/Damaged Controls/Ruptured live return; all Asteroid-outcome return seam; multiple-obstacle ordering; ordinary composed return; live projection | Use one deliberately composed path: nonlethal Thruster → transform → obstacle-triggered Damaged Controls → ordered Asteroid/​Debris/​Station → one choice-type nested immediate card → Ruptured Engine → completion. Direct tests already prove every rule branch, all six immediate outcomes, Debris point semantics, Station unions, and per-instance guards. The shared post-success hook does not need every card outcome | Automated production integration |
| V3 | Each materially different exceptional boundary produces exactly one destruction cleanup and the correct enclosing return, without invalid Maneuver/Attack completion | `CommandProcessor` damage/destruction capture → `destroy_unit` → existing selection/end-game or Attack cleanup | Final play-area destruction; pre-movement lethal; post-movement lethal; Attack immediate lethal; exact-once terminal cleanup | Add only distinct ownership/timing cases: pre-movement Thruster death; out-of-play death after final transform; lethal collision of the non-moving target; lethal Attack immediate damage. Existing live Asteroid last/non-last tests already prove ordinary post-movement moving-ship cleanup. Direct tests sufficiently prove Debris point 1/2, Damaged Controls, Ruptured Engine, and other immediate sources | Automated processor integration |
| V4 | Live transition and reconstruction produce the same actor, identity, options, and actionability; passive viewers remain read-only and neither reconstruction nor passive application submits commands | Canonical state/evaluator → real router/modal/board projection, once following a live result and once following reconstruction | Live projection versus reconstruction | Use a table of distinct UI decision shapes—not every rule combination: obstacle order; hull-zone choice; Station union; immediate single-select; Shield Failure multi-select; Comm Noise union. Thruster/Debris/Ruptured share the hull-choice presentation shape. Existing command validation protects their separate payload semantics | Automated production-board projection/reconstruction |
| V5 | Production save/install preserves every materially distinct authority owner; completed or destroyed work does not reopen; reconstructed decisions remain equivalent | `SaveGameManager` full-state round-trip and filtered-state install → real board reconstruction | Save/load/reconnect | One parameterized recovery suite should cover: uncommitted `OPEN`; committed pre-movement; displacement; obstacle order; Debris; Station; Ruptured; each distinct immediate choice family; one automatic inter-command boundary; completed; destroyed. Distribute immediate cases across Attack/Maneuver/debug sources instead of testing every source × card. Existing exact-schema, source-binding, option, and serializer tests cover unexercised combinations | Automated save/load and filtered reconnect |
| V6 | Both authenticated players can author decisions assigned to them, the wrong principal is rejected without mutation, automatic work remains authority-authored, and a reconnected endpoint regains only its legal decision | Real two-process Network submission, broadcast, passive ordered application, filtered reconnect, projection | Authenticated Network authoring/principal rejection; passive ordered application/non-synthesis; representative real reconnect; Network half of BUG-048 | One composite scenario can cover client-authored speed-0 Maneuver/obstacle order, differently controlled displacement or nested immediate choice authored by the other principal, one wrong-principal attempt, and reconnect during that choice. Per-command actor and stale/wrong-actor validation is already proven below transport, so every command type need not be wrong-principal tested over ENet | Real-Network automated acceptance |
| V7 | A Network attack against a speed-0 defender advances from Accuracy through automatic no-defense handling, damage, one completion, and composed return without unauthorized submission | Real two-process Attack UI/controller → authoritative continuation/submission → mirrored results | BUG-049 / Network speed-zero Defense | This is source-specific and cannot be inferred from V6: the defect concerns automatic Attack continuation, not a player-authored Maneuver decision. Existing Hot-Seat no-defense evidence supplies semantic equivalence but did not traverse this Network owner | Real-Network automated acceptance |
| V8 | Recorded semantic commands replay deterministically in order; replay/passive modes synthesize no continuation, decision, RNG, or duplicate cleanup | In-memory replay-10 construction → serialize/deserialize → `submit_replay` and final-state/history comparison | Replay/non-fixture replay | Use one non-fixture semantic history covering each distinct command/result shape, with a representative automatic and choice immediate branch. Direct all-branch command tests prove the other card semantics; no production-path replay is needed for all six cards or every transport. After convergence, Owner-recorded evidence must add legal speed 0 and Maneuver destruction to the genuine replay corpus | Automated non-fixture replay, followed by Owner-recorded replay evidence |
| V9 | Every approved contour treats exact boundary-only contact as non-overlap and a small inward displacement as positive-area overlap; one real contour is detected from the actual final speed-0 transform | Approved contour catalog → overlap authority → committed final-transform Maneuver integration | Obstacle contour boundary evidence; final-only speed-zero overlap | Characterize all six datasets because each is separately canonical, but only at representative rotations with tangent/inward/outward placements. Do not test every edge, rotation, ship size, obstacle order, or recovery combination. One contour is enough to prove the shared live final-transform seam | Automated geometry plus automated production integration; existing Owner-approved contour visual packet remains sufficient |

The composite V2/V6 scenarios may map evidence to several capability packages, as explicitly permitted by the workbook, provided the results name every observed RCP boundary. The accepted workbook’s consolidated evidence requirements are at [BUG-043 workbook §14](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md:1363).

## 2. BUG-048/049 implementation obligations

### BUG-048

The package must:

- Remove the speed-zero controller bypass.
- Make speed zero use the accepted terminal/facing segment rather than the root segment.
- Preserve transient pre-commit speed selection.
- Support ordinary 0→0 commitment and legal Navigate-backed 0→1.
- Preserve rejection and rollback when no legal Navigate source exists.
- Introduce no pre-commit `SetSpeed`, special speed-zero completion path, or parallel Maneuver authority.
- Supply V1 and the speed-zero portion of V6/V9.

This remains within the existing Maneuver interaction/projection allocation documented in [BUG-048](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-048/issue.md:1).

### BUG-049

The package must first diagnose the exact ownership error, then:

- Route automatic no-defense continuation through the existing authoritative Attack lifecycle.
- Preserve player/principal entitlement checks.
- Avoid a Network-only Attack/Defense lifecycle.
- Prove damage, one `complete_attack`, and the enclosing composed return.
- Supply V7 in real Network operation.

The observed unauthorized host submission is evidence of the defect, but it does not authorize changing the defender’s principal or weakening validation. See [BUG-049](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-049/issue.md:1).

## 3. Evidence deliberately omitted

The stabilization package should not add:

- One live processor test for every persistent card, every immediate card, and every obstacle. Their rule semantics are already covered by direct command tests; V2 proves the shared live return seam.
- Live lethal tests for Debris point 1 and point 2, Damaged Controls, Ruptured Engine, every immediate card, and every obstacle. V3 covers distinct terminal ownership/timing; existing direct tests cover source-specific mutation.
- Every rule × Hot-Seat × Network × save × reconnect × replay combination.
- A wrong-principal real-Network attempt for every command type. One representative rejection proves the transport gate; command-level actor validation covers the vocabulary.
- A real two-process reconnect for every pending state. V5 exercises every materially distinct state/decision owner through filtered installation; V6 proves the actual endpoint reconnect seam once.
- Owner-recorded replay coverage for Thruster Fissure, Damaged Controls, Ruptured Engine, or all six immediate outcomes. Automated non-fixture replay closes those gaps. Genuine replay must satisfy the narrower mandatory history in workbook §17, including legal speed zero and destruction.
- A new replay fixture per scenario, or any generated/transformed fixture.
- Every permutation of multi-obstacle order.
- Every contour vertex, rotation, ship size, or epsilon value. Six-token representative boundary characterization plus one live final-transform case is sufficient.
- New manual contour review. The v3 packet is already Owner-approved and canonical at [contour evidence packet](/Users/Katharina/godot/Armada/docs/architecture/evidence/ship-maneuver-obstacle-contours/contour-evidence-packet-v3.md:1).
- Positive Station objective-modifier testing while no applicable objective capability is `Integrated`.
- Generic continuation/FSM/decision infrastructure or any architecture redesign.

## 4. Bounded stabilization scope

The resulting package contains only:

1. BUG-048 repair.
2. BUG-049 diagnosis and repair.
3. V1–V9 focused evidence additions.
4. Existing-suite/full-suite, architecture-lint, schema/registration, legacy-path, and authorized-file verification already required by the workbook.
5. Owner replay capture and later evidence integration at the mandated stop.
6. Final evidence mapping and RCP readiness recommendations.

No other production behavior should change merely because an evidence gap exists. If V2–V9 expose another defect, that defect should be recorded and dispositioned rather than silently expanding this package.

## 5. Recommended execution order

1. Implement BUG-048 and pass V1.
2. Diagnose and implement BUG-049; pass focused local Attack checks, then V7.
3. Add V2 normal composed-return coverage.
4. Add V3 distinct terminal-boundary coverage.
5. Add V4 projection/reconstruction and V5 recovery matrices.
6. Add V9 contour-boundary and final-transform integration evidence.
7. Add V6 composite real-Network authoring, rejection, passive convergence, and reconnect.
8. Add V8 automated non-fixture replay.
9. Run focused groups, full suite, lint, schema/registration and obsolete-path audits.
10. Perform the focused BUG-048 manual visual smoke.
11. Stop for Owner replay capture as required by [workbook §17](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md:1460).
12. Inspect/hash/integrate the byte-identical Owner recordings, run Hot-Seat and Network replay baselines, then prepare per-RCP readiness evidence.

## 6. Owner decision/action required

No new architecture decision is required. Existing authority is sufficient.

Owner actions still required by governance are:

- Manually record genuine replay-10 evidence after non-fixture convergence. The combined recorded corpus must add legal speed zero and a Maneuver destruction path.
- Later approve each RCP as `Integrated`; Codex may only recommend readiness.

The contour approval gate has already passed. Any newly discovered authority conflict, incompatible version allocation, or need for generic continuation infrastructure would be a stop requiring a separate Owner decision—not an extension of this stabilization package.

> **Relationship:** Follow-up resolution analysis for B1/B2 from
> `UX-006-UX-012-pre-implementation-architecture-audit.md`.

## 1. B1 recommended resolution

**Resolve B1 by removing the delayed card-cleanup interval, rather than making the temporary destruction follow-up durable.** Preserve the faceup inspection as immutable evidence of the dealt card, independent of its subsequent physical location.

This follows the accepted authority more directly than the workbook’s current proposal:

- **Documented requirement:** ADR-014 §2.3 requires destruction to atomically invalidate the immediate obligation **and transfer/remove assigned card ownership**. ADR-006 §3.5 requires the destroyed activation, Maneuver and dependent consequences to terminate atomically.
- **Production fact:** `mark_destroyed()` clears those activation/immediate/obstacle facts but leaves card transfer to a later `DestroyUnitCommand`. The processor preserves the interrupted-turn information only in a temporary follow-up payload.
- **Conclusion:** production’s split is implementation evidence, not authority to introduce a recoverable wait between those mutations. The workbook’s instruction to block destruction cleanup behind inspection conflicts with that atomic boundary.

Sources: [ADR-014 §2.3–2.4](../adr/ADR-014-canonical-immediate-faceup-damage-card-resolution.md#L229), [ADR-006 §3.5](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md#L274), [mark_destroyed](../../../src/core/state/ship_instance.gd#L274), [temporary destruction follow-up](../../../src/autoload/command_processor.gd#L383), [workbook §4.1](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L75).

The precise resolution is:

1. **The lethal source transaction completes destruction atomically.** It marks destruction, terminates invalid nested state, transfers cards through the existing ship/deck owners, and commits any exceptional Ship Phase return. Reuse the purpose-specific cleanup operations currently implemented by `DestroyUnitCommand`; do not submit another command inside an unfinished transaction or introduce transaction infrastructure.
2. **GameState retains the UX-006 inspection occurrence.** Store its stable identity, ship reference, immutable public card description/reference and principal acknowledgment sets. This is inspection evidence—not another writable card owner or immediate-effect obligation.
3. **Do not validate a lethal inspection by requiring the card still to be assigned.** `DamageDeck.discard()` flips the card facedown, which clears its public assignment reference. The inspection therefore needs its own immutable public occurrence snapshot. This does not expose hidden card identities.
4. **Acknowledgment release does not reach destruction cleanup in these paths:** cleanup has already committed. It enables the surviving Attack owner, or the existing exceptional phase-return boundary, to re-evaluate.
5. **Preserve the exceptional return before erasing its evidence.** Capture whether the ship owned the interrupted activation inside the lethal transaction and commit the resulting phase-controller fact atomically. Do not retain the destroyed activation or infer its former ownership during recovery.

The last point needs a narrow canonical phase representation: current cleanup writes the next controller only into `InteractionFlow`, and load reads it back from there. Make that outcome a GameState-owned Ship Phase fact, maintained by the relevant existing turn transitions; projection reads it. This closes the specific recovery gap without deciding the wider Ship Phase controller architecture.

Sources: [DestroyUnit cleanup and exceptional return](../../../src/core/commands/destroy_unit_command.gd#L146), [current recovery dependence on InteractionFlow](../../../src/autoload/game_manager.gd#L2381), [discard behavior](../../../src/core/damage/damage_deck.gd#L126), [ADR-010 ownership restrictions](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md#L88).

The required lifecycle cases then resolve as follows:

| Case | Authoritative result |
|---|---|
| Lethal asteroid assignment | Assignment creates inspection evidence; destruction terminates Maneuver and the newly established immediate obligation; card cleanup and exceptional return commit atomically. Inspection remains. No later obstacle or immediate effect runs. |
| Lethal attack damage | Same atomic destruction/card transfer. `CurrentAttackState` survives defender destruction; after faceup acknowledgment, normal terminal Attack cleanup produces the separate completed-attack inspection. |
| Nonlethal assignment, lethal immediate effect | Faceup inspection finishes first. The immediate command executes, then atomically performs destruction/card cleanup if lethal. Structural Damage’s additional card is facedown, so it creates no second UX-006 inspection. |
| Save/load or reconnect during lethal faceup inspection | Restore the destroyed, cleaned ship; committed phase outcome; surviving Attack owner where applicable; and the original inspection/acknowledgments. With one Network acknowledgment received, only the other remains required. |

These distinctions are explicit in the [asteroid lethal branch](../../../src/core/commands/candidate_resolve_asteroid_overlap_command.gd#L50), [immediate-effect lethal branch and Structural Damage](../../../src/core/commands/candidate_resolve_immediate_effect_command.gd#L365), and [ADR-014 §2.4](../adr/ADR-014-canonical-immediate-faceup-damage-card-resolution.md#L263).

A destruction-specific durable aftermath record is technically possible without becoming generic infrastructure. **It is unnecessary for this recommendation and cannot justify delaying card transfer under unchanged ADR-014.** Exact-once source transitions, permanent destruction, transferred card ownership and the existing inspection identity prevent duplicate cleanup and reopened inspection.

## 2. B2 recommended resolution

**Separate terminal-condition detection from terminal-result installation.** Detection immediately closes ordinary gameplay admission; installation waits for required inspection and terminal cleanup.

This preserves the existing “game ends immediately” requirement while honoring the settled inspection decisions. It does not give the two-second timer authority. [WN-001–004](../../requirements/mvp_learning_scenario.md#L552)

**Detection must use canonical post-transaction facts:**

- **Elimination:** evaluate permanent ship destruction after the entire accepted damage transaction, not a scene’s destruction signal or an attack-result snapshot.
- **Mutual destruction:** currently possible through one collision transaction damaging and destroying both ships. Evaluate both fleets after that transaction, before choosing the reason.
- **Final round:** require completion of the final Status boundary, including existing unresolved ready-cost choices. `current_round == 6` or `phase == STATUS` alone is insufficient.

Production evidence: [collision transaction](../../../src/core/commands/candidate_resolve_ship_collision_damage_command.gd#L103), [elimination and winner calculation](../../../src/core/state/scoring_calculator.gd#L60), [Status cleanup](../../../src/core/commands/status_phase_cleanup_command.gd#L68), [Status continuation](../../../src/autoload/game_manager.gd#L2595).

**Before installation, require:**

- completion of the already accepted lethal transaction, including all affected ships’ destruction/card cleanup;
- outstanding UX-006 acknowledgments;
- resolution of any still-valid immediate obligation belonging to the initiating consequence—never an obligation terminated by destruction;
- applicable Attack terminal cleanup and `CompleteAttackCommand`;
- all required completed-attack acknowledgments;
- final-round Status obligations when that is the completion reason.

Do **not** require another ordinary Attack, Move, obstacle consequence, activation or phase. In particular, a surviving moving ship must not continue later Maneuver consequences after its collision has eliminated the opponent. Those are subsequent gameplay, not cleanup of the accepted lethal transaction.

The existing post-attack release paths can otherwise expose another attack or a remaining squadron Move. Therefore the workbook must explicitly add **terminal match completion as the context-specific release consumer**. `CompleteMatchCommand` validates terminal readiness and atomically consumes any matching satisfied completed-attack inspection while installing the single terminal result. Failure leaves both unchanged.

Sources: [current release derivation](../../../src/core/state/current_attack_continuation.gd#L83), [CompleteAttack creation of inspection](../../../src/core/commands/complete_attack_command.gd#L25), [CON-007 release and exact-once rules](../contracts/CON-007-post-attack-continuation-release-contract.md#L147).

Ownership remains bounded:

- **GameState** owns the terminal result and phase-completion facts.
- **CompleteMatchCommand** performs the final transition and obtains scoring from `ScoringCalculator`.
- **CommandProcessor’s live-authority seam** selects eligible transitions; it owns no terminal workflow.
- **Passive peers** apply authoritative results without synthesizing completion.
- **GameManager/UI/timers** project the accepted result.

The interval needs no generic `ENDING` state or terminal-work list. Elimination remains derivable from permanent destruction. Final-round recovery needs a narrow canonical proof that Status cleanup ran for that round: today that proof exists only in `InteractionFlow.payload.status_phase_cleanup_complete`. Outstanding inspections and existing rule facts supply the remaining readiness conditions.

Admission must reject ordinary gameplay throughout this interval while permitting only the specifically applicable acknowledgment and terminal-cleanup commands. Reconnect reinstalls these facts before command admission. After result installation, remaining turn/opportunity facts cannot authorize gameplay; do not fabricate normal completion or Skip decisions merely to empty them.

## 3. Combined ordering/invariants

The requested chain is **not universally legal in its stated order**. Under the recommended resolution:

| Path | Legal ordering |
|---|---|
| Faceup assignment itself kills | Lethal assignment **plus destruction/card cleanup** → faceup inspection → applicable Attack completion → completed-attack inspection → terminal release/result |
| Immediate effect kills after a surviving assignment | Assignment → faceup inspection → immediate effect **plus destruction/card cleanup** → applicable Attack completion → completed-attack inspection → terminal release/result |
| Lethal asteroid without an Attack | Obstacle pre-effect acknowledgment → lethal assignment **plus destruction/card cleanup/exceptional return** → faceup inspection → terminal result if eliminated |
| Mutual lethal collision | Both damage/destruction results and both cleanups commit → terminal result; neither faceup nor completed-attack inspection is invented |
| Final round without elimination | Final Status cleanup → existing ready-cost decisions complete → canonical final-round completion proof → terminal result |

For a nonterminal destruction, the enclosing return reaches the next legitimate phase decision after inspection. For terminal destruction, re-evaluation reaches match completion; it does not execute normal parent gameplay.

Key invariants:

- Destroyed activation/Maneuver identities and immediate obligations never survive or resurrect.
- An inspection may survive its source’s destruction because it records a public occurrence.
- The same attack’s completed inspection cannot precede its faceup inspection and applicable immediate effect.
- Mutual destruction is assessed from the complete command post-state, not the first cleanup callback.
- Recovery never reconstructs cleanup, acknowledgments or exceptional return from history.
- A new stable state containing destroyed-but-not-cleaned ships is rejected under this design.

These preserve [ADR-006’s exceptional-termination rule](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md#L397) and [ADR-007’s damage-before-completed-inspection ordering](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md#L108).

## 4. Required authority/document amendments

- **Workbook §4.1:** replace delayed destruction cleanup and assigned-card-only validation with immutable occurrence inspection and atomic destruction cleanup. Specify canonical exceptional-turn recovery.
- **Workbook §4.3:** define detection, admission restrictions, readiness, final-round proof and atomic terminal release consumption.
- **ADR-007 §2 item 5 and §3.1:** explicitly admit terminal match completion as the consumer of a satisfied completed-attack inspection.
- **CON-007 RELEASE-003, §4 context mapping and SEAM-001/005:** recognize the accepted terminal-match transaction. Clarify that normal enclosing continuation—including BOUNDARY-004’s anti-squadron continuation—does not require further gameplay after terminal detection.
- **CON-007 BOUNDARY-003 and XO-002:** preserve their substance. Completion still waits for satisfaction and consumes atomically; no waiver or timer bypass is needed.
- **ADR-006 and ADR-014:** no weakening required. Document the bounded implementation alignment with their existing exceptional-termination and atomic-destruction requirements.

Representation consequences:

| Surface | Required treatment |
|---|---|
| New canonical facts | Immutable faceup inspection snapshot; recoverable exceptional Ship Phase controller outcome; round-specific Status-cleanup proof; the already-planned terminal result. **No delayed-destruction record or generic terminal FSM.** |
| Save 8 | Represent and validate these facts. Define explicit migration or rejection for ambiguous older states; never infer missing destruction history. |
| Protocol 9 | Carry the same public facts through filtered bootstrap, reconnect and passive application. |
| Application results | Revise lethal-source contracts to include atomic cleanup/public discards and phase effects; include inspection and Status-proof changes where produced. Version each actually changed contract; new terminal contract starts at its initial version. |
| Replay 10 | No demonstrated replay-container schema change. Changed command sequences/results require compatibility decisions and fresh Owner replay captures, not an automatic format bump. |

Atomic cross-owner coordination remains consistent with [ADR-001 §2.4](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md#L122); passive damage application remains governed by [ADR-013 §2.3](../adr/ADR-013-passive-network-damage-state-representation.md#L112).

## 5. Remaining Owner decisions

**NONE for the recommended resolution.**

The recommendation preserves the four settled decisions and follows existing atomic destruction, immediate elimination and mandatory inspection semantics. The narrow authority amendments above still require normal Owner acceptance before implementation.

Retaining the workbook’s **delayed physical card cleanup** would instead require explicit approval to change ADR-014’s atomic boundary. That alternative is not necessary to resolve B1 and is not assumed here.

## 6. Instructions for workbook refinement

1. Replace B1’s delayed-cleanup design with the atomic lifecycle above, retaining inspection evidence after card transfer.
2. Name each producing transaction and canonical owner for exceptional turn outcome, final-round proof and terminal result.
3. Add explicit terminal admission and release rules; prohibit normal gameplay continuation after detection.
4. Amend ADR-007/CON-007 alongside the workbook before implementation authorization.
5. Add production-seam evidence for every ordering row, including one-principal reconnect, lethal Structural Damage, mutual collision, remaining Rogue Move, interrupted Maneuver, final Status choices and duplicate terminal submission.
6. Verify passive application equals filtered authority after each boundary; test recovery without queued callbacks. Update result contracts, migration policy and Owner replay-capture gates accordingly.

No files were edited. The established **4,338/4,338** baseline was not rerun.

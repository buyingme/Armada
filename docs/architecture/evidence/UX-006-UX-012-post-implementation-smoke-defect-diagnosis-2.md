> **Evidence status:** Read-only post-implementation stabilization diagnosis, round 2.
>
> **Normative authority:** None. This report records evidence and analysis from
> BUG-069 and BUG-070 following the first stabilization repair and manual re-smoke.
> Accepted architecture, contracts, requirements, and Owner decisions remain authoritative.
>
> **Implementation authorization:** None. BUG-069 is diagnosed as a bounded
> implementation correction. BUG-070 requires the identified Owner gameplay-semantic
> decision before implementation.

**1. Overall diagnosis**

BUG-069 is an incomplete stabilization of Squadron presentation: canonical progression succeeds, but a retiring callback closes the next player’s interaction. BUG-070 is a separate, pre-existing attack-pool integration defect exposed by the smoke test.

The common pattern is **correctness tested within individual components without proving the complete production transition and its next actionable state**.

Inspected all ten files in BUG-069/070, relevant prior evidence, accepted authority, current working-tree implementation, and tests. Single agent; no files or fixtures changed; no runtime tests executed.

**2. BUG-069**

- **Symptom:** The first capture completes the Rebel squadron’s movement and activation, then stalls with Imperial canonically entitled to act. The second capture completes two Rebel activations—including a Skip—and two Imperial activations, then stalls on the **next Rebel turn**, with two Rebel squadrons still available. The annotation does not establish that the second individual Rebel activation failed.
- **Expected:** Every accepted completion should expose the next canonical squadron decision, including controller changes, without a banner callback.
- **Root cause:** Reentrant presentation teardown after successful authoritative completion.

The production path is:

`Move intent → ActivateSquadronCommand → accepted Move → modal.notify_move_completed → activation_done → CompleteSquadronActivationCommand → GameState commits next controller → command-result projection opens selection → original activation_done callback resumes → hide_ui`.

The **first incorrect transition** is the final `hide_ui()` in [SquadronPhaseController](/Users/Katharina/godot/Armada/src/scenes/game_board/squadron_phase_controller.gd:893). It tests whether the *completed squadron’s owner* still controls the phase, then hides the already-projected next controller’s selection. It also hides the reopen button. The [first log](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-069/game_20261001_203118.log:673) explicitly records successful completion, controller change, modal opening, and the retiring callback continuing afterward.

**Why Network works:** Hot-Seat deliberately skips passive-peer advancement. Network additionally refreshes the observer through `active_player_changed → should_begin_passive_squadron_observer → begin_activation_flow`; the remote controlling peer receives its own accepted-result projection. The [Network capture](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-070/game_20261001_203718.log:612) shows the observer reopening after the same retiring callback. Network success therefore does not prove the shared teardown is correct.

**Why it appears inconsistent:** Skip completes within the command-result callback, allowing the subsequent router projection to reopen selection. Movement submits completion from an outer callback, which resumes and hides selection **after** projection. The second capture demonstrates both orders.

- **Authority/workbook mapping:** UX-010 Slice 8 requires banner-independent continuation; UX-011 §4.4/Slice 6 requires actionable selection after canonical completion. CON-007-SQMOVE-007/008 and ADR-010 require equivalent decisions across supported modes and callback histories.
- **Why previous verification missed it:** The [BUG-065 regression](/Users/Katharina/godot/Armada/tests/integration/test_ship_activation.gd:213) verifies last-ship teardown and initial squadron intent, then stops before that squadron completes. Turn-count tests assert canonical controller changes; the relevant modal integration test exercises Skip and same-player continuation.
- **Proposed repair:** Make retiring activation cleanup preserve/rederive selection from the **current canonical phase/controller**, including a different controller. Remove the stale callback’s authority over next-turn visibility. Keep Network admission, result application, and working observer behavior intact; do not restore banners or compensate with delayed reopening.

**3. BUG-070**

- **Symptom:** Network host CR90, carrying Point-Defense Failure, attacks a TIE with one blue die. `begin_attack` succeeds at sequence 56; sequence 57 publishes presentation. Mandatory die removal is rejected, leaving `attack:56` active in `pre_roll`, pool `{"BLUE":1}`, with no resolved pool choice. The [log](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-070/game_20261001_203718.log:976) identifies the rejection precisely.
- **Expected, established by evidence:** Mandatory removal must remove the last die and yield a valid, recoverable continuation. Rejection followed by an inert interface is incorrect.
- **Root cause:** The rule permits removal to zero, but the command/state integration assumes every active attack retains a positive pool.

The production path is:

`Target confirmation → BeginAttackCommand derives one blue die → accepted attack/progress commitment → AttackExecutor derives mandatory rule choice → single available colour auto-submits ResolveAttackPoolChoiceCommand → PointDefenseFailure removes blue → command rejects zero`.

The **first incorrect seam** is [ResolveAttackPoolChoiceCommand._resolve_rule_choice](/Users/Katharina/godot/Armada/src/core/commands/resolve_attack_pool_choice_command.gd:115): `after_count <= 0` rejects the otherwise correct one-die reduction.

Two further barriers matter:

1. [CurrentAttackState._validated_pool](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:391) independently rejects an empty pool. Removing only the command check cannot repair this.
2. [AttackExecutor’s automatic-choice branch](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1670) returns “handled” despite submission failure, after hiding Confirm/Skip. Existing empty-pool presentation does not itself guarantee canonical termination or recovery.

- **Authority/workbook mapping:** ADR-001/CON-001 own attack mutation and terminal transactions; ADR-003/CON-003 require rule integration across command, state, presentation, and persistence; ADR-010 requires recoverable continuation. UX-006 exposes the persistent card but does not define a new zero-dice attack semantic.
- **Why verification missed it:** Point-Defense Failure tests cover multi-die removal and an already-empty input, not **one die → zero through the production command**. The state test explicitly enforces non-empty active pools. The previous repairs addressed other boundaries. Both rejecting guards already existed in commit `7bc978a`; this is not evidence that the recent UX repair introduced them.
- **Proposed repair:** Repair the complete last-die-removal outcome through existing attack owners: command acceptance, valid canonical outcome, accepted-result presentation, and reconstruction. Preserve committed attack/target history and correct anti-squadron continuation. Also handle rejection explicitly so failed automatic submission cannot leave an inert panel. **The exact zero-dice terminal semantic needs the narrow clarification in §8 before implementation.**

**4. Relationship to BUG-065–068**

| Prior defect | Relationship |
|---|---|
| BUG-065 | Same teardown-after-projection pattern, at a distinct boundary. Its ship-ending guard is present and initial selection now works; the broader stabilization was incomplete. |
| BUG-066 | Separate token-refresh defect; shares the missing end-to-end projection evidence problem. |
| BUG-067 | No evidence that either new defect explains its unresolved transport cause. |
| BUG-068 | Passed manual retest remains valid. Neither new defect reopens its acknowledgment repair. |

**5. Shared-root-cause / integration-pattern assessment**

There is **no demonstrated common runtime root cause** requiring a new framework.

There is a shared integration weakness: canonical owners, legacy callbacks, and presentation helpers disagree at boundary outcomes. Tests often stop at command acceptance, state mutation, or initial visibility.

Change the repair strategy to **bounded transition families**: prove each transition through callback completion and the next usable decision. For BUG-069, cover movement, Skip, attack completion, and controller changes together. For BUG-070, cover mandatory removal, zero-pool handling, and recovery together.

**6. Required regression evidence**

- **BUG-069:** Real board/modal composition; one-squadron handoff, two-squadron handoff, return to the first player, same-player continuation, opponent auto-pass, and phase exhaustion. Exercise Move, Skip, and attack completion. Assert visibility, interactivity, candidate switching, and successful next intent **after all synchronous callbacks and deferred intent work finish**.
- **Network preservation:** Repeat with host/client as completing actor and next controller; retain pending/rejected submission checks and filtered-state equality.
- **BUG-070:** Exact CR90/Point-Defense Failure/TIE one-blue-die reproduction through command admission. Cover first and subsequent anti-squadron targets, remaining/no remaining targets, multi-die control cases, duplicate/stale/wrong-player rejection, and actionable rejection recovery.
- **Shared pool boundary:** Inspect/test Damaged Munitions and obstruction removing the final die; they share affected machinery, although these captures do not reproduce them.
- **Persistence:** Save/load, reconnect, and non-fixture replay at the relevant accepted boundaries; prove identical continuation without duplicate removal or refunded attack consumption.
- Keep replay fixtures unchanged. Follow focused evidence with required static checks and full-suite convergence.

**7. Architecture/workbook impact**

BUG-069 needs implementation and verification corrections within existing authority.

BUG-070 demonstrates implementation drift between the rule and canonical attack machinery. It does **not** establish a need to redesign accepted ownership. The remaining uncertainty is a narrow gameplay outcome, not a justification for generic continuation infrastructure.

Any later rule repair needs CON-003 traceability; Codex must not mark a capability package `Integrated`.

**8. Owner decisions required**

**BUG-069: none.**

**BUG-070: confirm the outcome when mandatory pre-roll removal removes the last gathered die:** does the individual attack cancel, preserving already-committed attack/target consumption and returning through the existing enclosing attack owner, or continue through a zero-dice resolution?

Cancellation is suggested by existing UI branches, but those branches are inconsistent/incomplete. The repository’s [rules reference](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:99) explicitly addresses inability to gather dice; it does not unambiguously settle this post-gather removal boundary. Accepted architecture specifies ownership without selecting that gameplay outcome.

**Stop before implementing that semantic choice**, as requested. No architecture redesign is proposed.

**10. Recommended repair grouping/order**

1. Repair BUG-069’s complete Squadron completion/projection family; protect the working Network path.
2. Resolve BUG-070’s narrow gameplay clarification, then repair its command/state/continuation family as one slice.
3. Run combined production-path stabilization evidence and manual retests. Keep BUG-067 transport investigation separate.

**11. Recommended model/reasoning for implementation**

**GPT-6 Astra, high reasoning, single agent** for the combined work. BUG-069 alone is bounded enough for **GPT-6 Sol, high**. This is a task-specific recommendation; the key quality gate is complete transition evidence, consistent with [OpenAI’s model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection).

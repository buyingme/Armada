# BUG-070 / BUG-071 — Joint Production Diagnosis

**Status:** Preserved architecture evidence
**Evidence date:** 2026-10-02
**Repository baseline:** `ab3a21d`
**Method:** Single-agent, read-only production inspection
**Implementation authority:** None — this document does not authorize production changes

> This document preserves the joint production diagnosis performed after BUG-070
> and BUG-071 were identified during post-implementation smoke testing.
>
> It is evidence for the subsequent normative architecture refinement. Where this
> document conflicts with an accepted ADR, contract, or later Owner-accepted
> normative decision, the authoritative document governs.

**BUG-070 / BUG-071 — Joint production diagnosis**

Evidence date: 2026-10-02. Repository: `ab3a21d`. Single-agent, read-only inspection; no files or replay fixtures changed, no runtime tests executed. Startup routing: Uncertain/High-Risk Architecture because attack timing, persistence, and distributed application cross several accepted boundaries.

**1. Executive finding**

BUG-070 is confirmed: mandatory removal correctly produces an empty pool, but command validation rejects it; canonical state independently prohibits it; presentation then treats the failed automatic submission as handled.

BUG-071 is confirmed **for the dial**. The token already resolves after rolling in the shared Attack Modify window. Its integration still needs combined dial/token regression protection.

Existing ownership is sufficient: `GameState.CurrentAttackState`, replayable attack commands, existing timing-window orchestration, and existing enclosing Ship/Squadron owners. However, **an explicit authoritative end-of-GATHER-ATTACK-DICE boundary is missing**. The accepted TWI-002 workbook also expressly preserves the incorrect pre-roll dial timing.

**Disposition: stop before implementation for a narrow normative refinement.** The appended [Owner Resolution](UX-006-UX-012-post-implementation-smoke-defect-diagnosis-2.md#L117) settles cancellation semantics; those decisions need no reconsideration.

**2. Actual production attack-flow map**

The [Rules Reference](../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md#L89) distinguishes Declare Target → Roll Attack Dice, including gathering → Resolve Attack Effects → Spend Defense Tokens → Resolve Damage → additional squadron targets.

| Boundary | Actual production path and authority |
|---|---|
| Declare Target | `TargetSelector` holds transient intent. `BeginAttackCommand.validate/execute` rederives target legality, range, obstruction and initial pool; installs `pre_roll`; commits attack opportunity/history on the enclosing owner. Begin does not roll. [BeginAttackCommand](../../../src/core/commands/begin_attack_command.gd#L17) |
| Gathering before roll | Begin invokes registered pool modifiers without a selected removal colour. They expose choice metadata. `AttackExecutor.apply_begin_attack_result` sequences damage-card removal, an empty-pool check, obstruction, CF dial, then the Roll button. This sequencing is substantially scene-driven. [AttackExecutor](../../../src/scenes/game_board/attack_executor.gd#L1551) |
| Roll → Modify | `RollDiceCommand` requires `pre_roll`, resolved obstruction, resolved dial choice and a positive pool. It rolls canonical dice and changes the stage to `attack_modify`. **It does not verify completion of mandatory registered pool choices.** [RollDiceCommand](../../../src/core/commands/roll_dice_command.gd#L78) |
| Resolve Attack Effects | For ship attackers, the post-success seam opens the shared Attack Modify timing lifecycle. CF token and H9 opportunities are rederived; completion selects `ConfirmAttackDiceCommand`, which enters `accuracy`. Squadron attackers retain the procedural Swarm/confirmation path. [TimingWindowOrchestrator](../../../src/core/timing_windows/timing_window_orchestrator.gd#L563), [ConfirmAttackDiceCommand](../../../src/core/commands/confirm_attack_dice_command.gd#L27) |
| Later attack steps | Accuracy commitment enters defense; defense commands resolve selected tokens; damage resolution establishes `resolved` and the terminal outcome. `CurrentAttackContinuation` selects existing follow-ups, respecting Counter and faceup/immediate-effect obligations. [CurrentAttackContinuation](../../../src/core/state/current_attack_continuation.gd#L72) |
| Individual completion | `CompleteAttackCommand` requires resolved damage/outcome, retires CurrentAttack and establishes applicable completed-result inspection. Acknowledgment and enclosing progression are separate. [CompleteAttackCommand](../../../src/core/commands/complete_attack_command.gd#L29) |
| Individual cancellation | The existing active `SkipAttackCommand(reason="cancelled")` retires CurrentAttack and cleans matching attack/timing state without refunding Ship/Squadron commitments. It creates no completed-damage inspection. It currently neither validates gather completion nor supplies complete automatic post-cancellation convergence. [SkipAttackCommand](../../../src/core/commands/skip_attack_command.gd#L49) |

Neither scene FSM `ROLL` nor `InteractionFlow.ATTACK_ROLL` proves gathering is finished. Canonical `pre_roll` spans unresolved gathering and roll readiness; successful `RollDiceCommand` is the actual authoritative crossing into Modify, but its readiness predicate is incomplete.

**Production gather inventory**

| Path | Effect on the pool |
|---|---|
| Armament and range | `TargetingListBuilder` selects battery versus anti-squadron armament and range-permitted colours. `DicePool`/`RangeFinder` supply the shared calculations. Targeting excludes unavailable base armament/range; CF is not included in those calculations. [TargetingListBuilder](../../../src/core/combat/targeting_list_builder.gd#L605) |
| Counter entry | `BeginAttackCommand._derive_initial_pool` supplies Counter X blue dice through its separate branch. It returns before the normal gather-hook loop. [BeginAttackCommand](../../../src/core/commands/begin_attack_command.gd#L303) |
| Point-Defense Failure | Registered `ATTACK_ROLL / dice_pool` modifier; ship attacking squadron; selected colour loses one die. No selection means metadata only. [PointDefenseFailure.apply_attack_pool_modifier](../../../src/core/effects/rules/damage_cards/ship/point_defense_failure.gd#L42) |
| Damaged Munitions | Same mechanism for ship attacking ship. These two card predicates are mutually exclusive for one defender. [DamagedMunitions](../../../src/core/effects/rules/damage_cards/ship/damaged_munitions.gd) |
| Obstruction | Separate `ResolveAttackPoolChoiceCommand` branch subtracts one selected die and marks obstruction resolved. [ResolveAttackPoolChoiceCommand.execute](../../../src/core/commands/resolve_attack_pool_choice_command.gd#L39) |
| CF dial — incorrectly included | Adds one matching-colour die to canonical `dice_pool` before the initial roll. |
| Other registered rules | No other production gather-pool modifier/addition was found in the [bootstrap catalogue](../../../src/autoload/rule_bootstrap.gd#L9). Declaration blockers determine eligibility; H9, Swarm, token rerolls, Accuracy, defense and damage modifiers belong later. |

**All applicable gathering effects are not authoritatively guaranteed to finish.** Last-die removal is rejected; a temporary empty pool cannot be represented; scene callbacks perform premature empty checks; and direct roll admission can bypass unresolved card removal. The single pending-rule metadata slot is presentation evidence, not authoritative proof of gather completion.

**3. BUG-070 root cause and repair boundary**

The [capture log](../../qa/bugs/open/BUG-070/game_20261001_203718.log#L976), annotation and replay agree: CR90 attacks a TIE, Begin succeeds at sequence 56, presentation publishes at 57, then removal is rejected. `attack:56` remains `pre_roll`, with one blue die and no resolved pool choice.

Three connected failures explain the stall:

1. `ResolveAttackPoolChoiceCommand._resolve_rule_choice` rejects `after_count <= 0`, although the card correctly removed exactly one die.
2. `CurrentAttackState._validated_pool` requires a positive pool at every active stage. Consequently, removing the command guard alone also fails; obstruction encounters this state barrier directly. [CurrentAttackState](../../../src/core/state/current_attack_state.gd#L391)
3. `AttackExecutor._handle_attack_pool_die_choice` ignores the automatic submission’s failure return and reports “handled” after Confirm/Skip were hidden. Targeted rejection routing covers Begin/Skip, not pool choices. [Automatic-choice path](../../../src/scenes/game_board/attack_executor.gd#L1670), [rejection routing](../../../src/scenes/game_board/attack_panel_controller.gd#L199)

The repair boundary is **completion of gathering within the existing command-owned attack lifecycle**, before rolling or opening Attack Modify. Individual effects must finish their own work without deciding cancellation. Empty intermediate gathering state and terminal empty-pool cancellation must be distinguishable; nonempty blank results continue normally.

First and subsequent anti-squadron targets share this obligation:

- First Begin consumes one normal attack, records the hull zone, locks the anti-squadron zone and records the target.
- Subsequent Begins append target history without consuming another normal attack.
- Cancellation preserves those commitments and reevaluates remaining eligible targets independently. Exhaustion closes the iteration through the existing `squadron_done` transaction; the enclosing Ship Attack owner then determines another declaration or Maneuver. [ShipInstance.commit_attack](../../../src/core/state/ship_instance.gd#L1531)

The legacy `_auto_skip_zero_dice_squadron` callback is insufficient: it relies on scene flags/history and its exhaustion path does not establish the complete authoritative return. Its `attacked_squads.size() > 0` check is not a reliable “subsequent target” distinction—canonical mirroring already includes the first committed target.

**4. BUG-071 root cause and repair boundary**

**Dial.** Begin marks the dial pending from the revealed ship dial. Use/decline require `pre_roll`; use increments `dice_pool` and spends the revealed dial atomically. Roll rejects a pending dial, and CurrentAttack rejects a pending dial outside `pre_roll`. [UseConcentrateFireDialCommand](../../../src/core/commands/use_concentrate_fire_dial_command.gd), [stage invariants](../../../src/core/state/current_attack_state.gd#L350)

This is a semantic timing error, not merely misplaced UI. Use validation also lacks unresolved-card/obstruction guards, allowing a direct dial submission earlier than the scene’s nominal ordering.

At Resolve Attack Effects, adding a die means **rolling a new die into the existing results**, choosing a colour present in the current attack pool. Merely moving the button or changing its stage check would leave the command’s mutation and RNG behavior wrong. The [Rules Reference](../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md#L690) states this explicitly.

**Token.** Begin records potential availability, but `ConcentrateFireTokenRule.pending_source/validate_resolution_context` requires canonical `attack_modify` and its matching open timing lifecycle. Use rerolls one selected canonical result, spends one token and records used; decline preserves the resource/results. It does **not** participate in gathering. [Token participant](../../../src/core/effects/rules/concentrate_fire_token.gd#L134), [token command](../../../src/core/commands/use_concentrate_fire_token_reroll_command.gd)

Required integration assessment encompasses:

- Dial use/decline validation, CurrentAttack invariants, Roll readiness and Confirm readiness.
- [FlowSpec](../../../src/core/state/flow_spec.gd#L190) and [CommandApplicability](../../../src/core/commands/command_applicability.gd#L121).
- AttackExecutor offering/resume paths, panel signals, result routing and mirror refresh.
- Shared-window rederivation: a pending dial must prevent premature automatic confirmation, including when no token/H9 opportunity initially exists. H9 and token eligibility must reflect the added result.
- Combined-use legality: current independent per-attack flags do not encode the rules’ advance choice of dial/token/both or once-per-round resolution. A later Begin can reoffer the unspent counterpart. Preserve the existing rule that a combined token can reroll the added die; do not invent its semantics. [Command rules](../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md#L251)

No separate production bot attack planner was found. Direct command consumers inherit the readiness defects. The analysis simulator shares armament/range helpers and panels, but [TargetSelector’s simulator path](../../../src/scenes/game_board/target_selector.gd#L233) does not establish an independent CF execution model.

**5. Shared seams / interactions**

BUG-070 and BUG-071 share `pre_roll`, pool state, Roll admission, scene sequencing and reconstruction. They remain separate obligations: correct gather termination does not correct CF timing, and relocating CF does not repair mandatory-removal rejection.

Normal scene execution currently attempts removal before offering the dial; the captured BUG-070 attack has neither CF resource. Thus CF did not cause that captured stall. The dangerous interaction is admitting the dial as pre-roll pool construction or using it to bypass final-empty cancellation.

Also inspect `RollDiceCommand._record_ship_target_attack`: the separate Coolant Discharge ship-target counter is recorded only on successful roll, unlike Begin’s committed attack history. Cancellation coverage must distinguish these ledgers and preserve the settled commitment semantics.

**6. Persistence / Network / replay impact**

- **Save/load:** [GameState serialization/reconstruction](../../../src/core/state/game_state.gd#L1236) validates CurrentAttack before resume. Today it cannot load empty gathering state or pending-dial Modify state. `AttackExecutor._derive_pre_roll_resume_plan` reconstructs card → obstruction → dial → roll; an empty obstructed pool fails recovery. Corrected state must recover the same legal next decision without repeating removals.
- **Network:** [CommandProcessor](../../../src/autoload/command_processor.gd#L374) validates ordered commands before application. Pool/dial changes are currently deterministic; Roll/token commands apply authority-resolved random outcomes on passive peers. Moving dial addition after rolling introduces a random result into that transaction, requiring the existing ADR-012 result-application discipline. Passive peers must neither roll locally nor synthesize cancellation/continuation.
- **Replay:** Command order and RNG placement change. Existing pre-roll dial histories cannot silently acquire corrected semantics. Replay must apply recorded cancellation and enclosing transitions only; reconstruction cannot fabricate them.
- **Compatibility:** Current save/wire/replay versions are 8/9/10. Allocate compatibility explicitly for changed state semantics, command/result contracts and older histories. Do not assume an unchanged JSON shape means semantic compatibility. Fixture renewal, if necessary, remains Owner-recorded; existing fixtures stay untouched.

**7. Required regression evidence**

Existing tests provide useful but incomplete protection:

- Wrong invariant: [CurrentAttack state test](../../../tests/unit/test_current_attack_state.gd#L67) expressly rejects every empty active pool.
- Wrong timing assumption: [flow-coverage test](../../../tests/unit/test_dump_flow_coverage.gd#L46) expects dial commands at ATTACK_ROLL; dial atomic-failure setup uses `pre_roll`.
- Card tests cover multi-die removal, empty input and restored rule activation, not last-die removal through production submission. [Point-Defense tests](../../../tests/unit/test_rule_point_defense_failure.gd#L94)
- Correct neighbors: [token timing tests](../../../tests/unit/test_concentrate_fire_timing_window.gd), [token distributed protocol](../../../tests/integration/test_concentrate_fire_shared_protocol.gd), [attack shared protocol](../../../tests/integration/test_current_attack_shared_protocol.gd), and [production resume/continuation tests](../../../tests/integration/test_current_attack_production_resume.gd) cover blocking opportunities, resource use/decline, identities, passive behavior and neighboring continuation. Their existence does not establish these bugs are covered.

Minimum production-path families:

1. Exact BUG-070 reproduction; Point-Defense Failure, Damaged Munitions and obstruction removing the final die; combined card/obstruction processing; multicolour choices and multi-die controls.
2. No final evaluation while any applicable gather effect remains; no direct-roll bypass; temporary zero distinguished from completed zero; nonempty blanks continue.
3. First/subsequent anti-squadron cancellation, remaining/no remaining targets, obstructed then unobstructed targets, preserved history/count/zone, no retry, and a usable enclosing decision after callbacks finish.
4. Dial-only, token-only, combined use/decline, added-die reroll, current-colour legality, H9 ordering/rederivation, once-per-round constraints, and no CF availability/consumption for a gather-cancelled attack.
5. Wrong-player/stale/duplicate/reordered submissions and atomic failure, including actionable recovery after automatic rejection.
6. Hot-Seat, host/client in both attacker roles, RNG-free passive application, save/load and reconnect around each affected boundary, and non-fixture replay with exact command/state outcomes.

Preserve Swarm/Counter, Accuracy/defense, faceup/immediate processing, completed-result acknowledgment and terminal-match behavior. Runtime verification must culminate in required static checks, focused production evidence and full-suite convergence.

**8. Architecture / documentation impact**

[ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md) and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md) establish ownership and atomic transitions, but no complete-gather predicate or mandatory final-pool evaluation. CON-006 ends at Begin and excludes rolling/CF/cancellation. [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md#L34) governs completed-result inspection release; it does not supply a gather-cancellation boundary.

Furthermore, accepted [TWI-002 §15.5.1 and §16.3](../implementation_workbooks/TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md#L1815) explicitly place the dial before rolling and outside Attack Modify. This must be expressly superseded for BUG-071.

The smallest normative refinement is:

- Add a bounded CON-001 attack-step obligation: complete all applicable gathering effects; only then evaluate the final pool; cancel empty individual attacks through existing command authority while retaining commitments; otherwise roll and enter Resolve Attack Effects.
- State that both CF effects belong exclusively to Resolve Attack Effects.
- Clarify the cancellation return to existing enclosing owners, without treating cancellation as resolved-damage inspection or extending CON-007 into a generic continuation mechanism.
- Reconcile TWI-002’s conflicting timing inventory/oracle and record focused verification obligations.

No new FSM, lifecycle owner, rollback model or generic continuation framework is needed. The UX-006–UX-012 workbook remains relevant to downstream faceup inspection, terminal admission and recoverable presentation; it does not supply the missing gather boundary. Touched rules need CON-003 traceability; Codex must not mark packages Integrated.

**9. Genuine remaining Owner decision**

No BUG-070 gameplay decision remains open, and CF timing is explicit in the rules. The remaining gate is **Owner acceptance of the narrow normative boundary/refinement above**. This diagnosis stops there; it does not authorize an implementation mechanism or compatibility migration.

**10. Recommended repair grouping/order and model**

First accept the normative refinement and compatibility scope. Then handle the shared gather/roll boundary and CF relocation as one coordinated repair group, with separate BUG-070 and BUG-071 acceptance evidence. Follow with distributed/recovery verification and Owner manual smoke testing.

For that later work: **GPT-6 Astra, high reasoning, single agent**. This is a task-specific recommendation because atomic multi-owner changes, timing coexistence and replay compatibility require sustained cross-path reasoning, consistent with [OpenAI’s model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection).

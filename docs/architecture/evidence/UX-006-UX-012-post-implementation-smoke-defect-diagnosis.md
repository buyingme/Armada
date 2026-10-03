> **Evidence status:** Read-only post-implementation stabilization diagnosis.
>
> **Normative authority:** None. This report records evidence and analysis from
> manual-smoke defects BUG-065 through BUG-068. Accepted architecture, contracts,
> requirements, and the accepted UX-006–UX-012 implementation workbook remain
> authoritative.
>
> **Implementation authorization:** None. Confirmed bounded repairs may proceed only
> under the accepted repository governance. BUG-067 transport behavior remains
> unresolved pending additional runtime evidence.

**1. Overall diagnosis**

These are bounded implementation and verification defects, with **partial shared causation**. No demonstrated architecture gap requires changing accepted ownership.

I inspected all 15 files across the four folders: five annotations with full state snapshots, five logs, and five replays. No screenshots or separate saves were present. This was single-agent, read-only inspection; nothing was modified and no runtime tests were run.

The [accepted workbook](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md) supplies sufficient authority for the confirmed repairs. BUG-067’s transport failure remains only partially diagnosable from its host-side evidence.

**2. BUG-065**

- **Symptom:** Both Hot-Seat recordings reach Squadron Phase with controller 0, available squadrons, and zero committed activations, but cannot activate a squadron. Expected: immediately inspect candidates and commit through legal Move/Attack/Skip intent.
- **Root cause:** Synchronous signal ordering. `GameManager._on_activation_ended()` completes the last ship and advances phase; accepted-command projection opens squadron selection. The remaining listener for the original ship-ending signal then unconditionally calls `_squadron_phase_controller.hide_ui()`. **That teardown of the newly opened selection is the first incorrect interaction transition.** Removing ordinary banners removed the later handoff callback that previously reopened it.
- **Responsible production seam:** [ShipActivationController._on_board_activation_ended](../../../src/scenes/game_board/ship_activation_controller.gd#L1013), following [GameManager’s phase advancement](../../../src/autoload/game_manager.gd#L2308) and ModalRouter’s canonical selection projection.
- **Accepted requirement/authority:** Workbook Slice 8/UX-010 requires ordinary continuation without banner timing; §4.4/UX-011 requires actionable precommit inspection. ADR-010 requires equivalent actionable decisions regardless of callback history.
- **Why verification missed it:** Squadron tests construct Squadron Phase directly or open the modal explicitly; projector tests check banner flags. These do not exercise the full last-ship End Activation signal and its remaining listeners. The workbook’s composed production-path verification should have caught it.
- **Proposed repair:** Scope ship-ending teardown to the retiring ship/command presentation, preserving any Squadron Phase surface already derived from canonical state. Verify actionability after the entire signal finishes. Do not restore the banner or add delayed reopening as a compensating patch.

**3. BUG-066**

- **Symptom:** After asteroid → Injured Crew → token choice, the discarded defense token remains visible. Expected: immediate removal from the affected ship’s display.
- **Root cause:** Canonical resolution succeeds. The annotation contains token index 0 in `DISCARDED` state, Injured Crew facedown, and no remaining immediate obligation; replay sequence 16 records successful resolution. **The first incorrect transition is failure to invalidate the defense-token presentation after acceptance.**
- **Responsible production seam:** [CommandRouterAdapter._emit_candidate_damage_events](../../../src/scenes/game_board/command_router_adapter.gd#L224) refreshes damage, command tokens for Life Support Failure, and selected other effects, but omits Injured Crew’s defense-token notification. The Maneuver route bypasses the debug/Attack callback that emits it. [ShipCardPanel](../../../src/ui/ship/ship_card_panel.gd#L604) already knows how to rebuild from canonical tokens.
- **Accepted requirement/authority:** Workbook UX-006 preserves existing immediate-effect behavior across sources; ADR-014 owns resolution; CAP-DMG-007 traces token mutation and projection. UX-007 concerns **command tokens**, so it is analogous seam evidence, not the direct defense-token requirement.
- **Why verification missed it:** The immediate-controller test proves refresh through the **debug** route. Asteroid tests prove canonical mutation/return without the live token column. The discarded-token panel test checks structure after pre-discarded setup, not live removal.
- **Proposed repair:** Publish the existing defense-token refresh from accepted Injured Crew result projection for the affected ship, covering Hot-Seat and host as well as passive application. Preserve existing working routes without duplicate refresh responsibility; no token-rule changes.

**4. BUG-067**

- **Symptom:** Network client misses the final Nebulon-B movement; Rebel cannot activate a squadron. Expected: connected peers converge, and the controlling player receives actionable selection.
- **Root cause:** Two observations must be separated. The [host log](../../qa/bugs/open/BUG-067/game_20260930_232706.log#L318) records heartbeat timeout at **23:27:39**, disconnect at **23:27:40**, then the missing movement and Squadron transition at **23:27:41**. The client was already disconnected. The host-side squadron failure follows BUG-065’s teardown path.
- **Responsible production seam:** Shared selection teardown for the host symptom; separately, [NetworkManager heartbeat timeout/removal](../../../src/autoload/network_manager.gd#L1545) removes the endpoint before later results are distributed.
- **Accepted requirement/authority:** UX-010/011 and ADR-010 govern actionable selection. Workbook §§6–7 require connected passive convergence and reconnect installation. They do not establish that this timeout was erroneous.
- **Why verification missed it:** Existing transport tests cover lifecycle/ordering and scripted reconnect; heartbeat unit checks cover configuration. Neither proves this particular sustained desktop session. Replay records accepted gameplay, not heartbeat traffic, disconnect causes, or client installation failures.
- **Proposed repair:** Apply BUG-065’s shared presentation repair. **Hold transport implementation:** the folder contains no client log or client-state capture establishing why heartbeats stopped. No first *incorrect* transport transition can be proven; timeout/removal may have been correct. Obtain paired logs and heartbeat/process-liveness evidence before changing transport behavior.

**5. BUG-068**

- **Symptom:** “Acknowledge” merely selects an option; “Confirm” submits it. Expected: one explicit acknowledgment action per required principal.
- **Root cause:** [The Maneuver descriptor](../../../src/scenes/game_board/ship_activation_controller.gd#L1217) represents acknowledgment as an ordinary single-choice option. [OpponentChoiceModal](../../../src/ui/opponent_choice_modal.gd#L276) consequently separates selection from submission. **The first incorrect interaction mapping is acknowledgment → selectable option.** There are not two canonical acknowledgments.
- **Responsible production seam:** Maneuver acknowledgment presentation and its existing command-submission handler.
- **Accepted requirement/authority:** Workbook §4.2 and Owner decision UX-008 A define informational context plus acknowledgment, explicitly not a gameplay choice. Exact button count is presentation detail, not a new architecture decision.
- **Why verification missed it:** Command tests and Network acceptance submit acknowledgment commands directly; they bypass the actual button sequence. General choice-modal tests do not establish acknowledgment usability.
- **Proposed repair:** Render one acknowledgment action that submits the existing occurrence-bound command. Preserve pending/waiting state, principal validation, and rejection behavior; retain confirmation for genuine choices.

The log also exposes a separate bounded defect: immediately after asteroid damage, an automatic immediate-effect submission is rejected because faceup inspection remains pending. [ManeuverExecutionEvaluator](../../../src/core/movement/maneuver_execution_evaluator.gd#L15) checks inspection release for the non-immediate asteroid branch, but offers the immediate branch prematurely. Admission correctly prevents mutation. Repair the evaluator to derive waiting from the existing inspection gate; after release, derive the same legitimate effect. This is independent of the two-click symptom.

**6. Shared-root-cause / dependency map**

| Cause | Symptoms | Classification |
|---|---|---|
| Ship teardown closes newly projected squadron selection | BUG-065; BUG-067 host activation | Shared bounded defect; UX-010 integration drift |
| Missing accepted-result defense-token refresh | BUG-066 | Independent projection defect |
| Acknowledgment rendered as ordinary choice | BUG-068 clicks | Independent interaction defect |
| Immediate Maneuver action offered before inspection release | BUG-068 warning | Evaluator/admission disagreement |
| Heartbeat loss and endpoint removal | BUG-067 stale client | Proven interruption; underlying cause unresolved |

The common verification weakness is **missing requirement → complete production-path proof**, not evidence for a new common runtime abstraction.

**7. Required regression evidence**

- **065/shared 067:** Real last-ship End Activation through all listeners; Hot-Seat and Network, host/client last actor, either next controller. Assert selection remains visible/actionable after signal completion, candidate cycling changes no canonical state, and one chosen intent commits correctly.
- **066:** Real asteroid → inspection → Injured Crew choice → accepted result → existing panel. Assert canonical discard and immediate visible-token removal on each supported seat; retain Attack/debug and reconstruction coverage.
- **068:** Press the actual acknowledgment control once; assert one submission. Network’s first principal waits; second releases. Cover rejection, duplicate clicks, reconnect, and unchanged genuine-choice confirmation.
- **Inspection ordering:** Assert the Maneuver evaluator offers no immediate action while inspection is pending, then derives it after release without an intervening rejected automatic submission.
- **067 transport:** Paired real-process evidence across multiple heartbeat periods, followed by movement/phase convergence and explicit reconnect. Establish the timeout cause before selecting a repair.

Use non-fixture tests. Owner-recorded replay fixtures remain unchanged.

**8. Architecture/workbook impact**

**NONE to accepted architecture or Owner decisions.** Implementation corrections and missing verification are required. The workbook already defines the relevant ownership and ordering; no new continuation, acknowledgment, pending-work, or FSM infrastructure is warranted.

**9. Owner decisions required**

**NONE.** BUG-067 needs additional runtime evidence, not an architecture decision. Its transport repair remains undetermined.

**10. Recommended repair grouping/order**

1. Repair BUG-065’s shared teardown seam; verify BUG-067’s host symptom with it.
2. Repair BUG-066 accepted-result projection.
3. Repair BUG-068 acknowledgment presentation and the separately tested inspection-gating omission.
4. Diagnose BUG-067’s transport interruption independently before implementing a transport change.

**11. Recommended model/reasoning for implementation**

**GPT-6 Sol, high reasoning, single agent** for the confirmed bounded repairs. Keep BUG-067 transport diagnosis separate until paired evidence exists. This is a task-specific judgment following [OpenAI’s guidance to use the lightest model/effort that meets the quality bar](https://developers.openai.com/api/docs/guides/model-selection).

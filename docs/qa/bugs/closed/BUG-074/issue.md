Diagnosis complete. BUG-074 is a pre-existing adjacent production defect in the attack presentation FSM, not a Counter authority or continuation defect. It blocks acceptance of the current workbook implementation. No files or fixtures were modified.

1. **Exact failing sequence/seam**

   Replay commands `99–112` are authoritative and valid through damage resolution:

   - `99`: activate Player 0 X-wing.
   - `100`: begin parent `attack:100`.
   - `101–107`: Declare, Roll, Modify, and accuracy projections.
   - `108`: `commit_accuracy`; the squadron defender has no defense-token step.
   - `109`: command-owned `resolve_damage`; parent becomes resolved.
   - `110`: final-damage publication, incorrectly still step `18`.
   - `111`: attempted Counter transition publication, also step `18`.
   - `112`: Counter payload published with correct identities, but still step `18` and top-level controller `0`.

   The replay then ends at cursor `113`; there is no `counter_choice`, parent completion, acknowledgement, or child Begin. See [replay evidence](replay_20261011_145937.json).

2. **Canonical state validity**

   The gameplay facts are valid:

   - `attack:100` is active and resolved.
   - X-wing P0 attacked TIE Interceptor P1.
   - Two hull damage was applied; the defender survives on one hull.
   - Counter 2 is available.
   - The four Counter identities correctly reverse the parent participants.
   - Player 1 is the correct Counter controller.

   The complete canonical state is nevertheless **invalid/internally inconsistent** because its authoritative interaction projection is wrong:

   - `flow_type == 4` means `ATTACK`.
   - `step_id == 18` means `ATTACK_MODIFY`.
   - It should be `ATTACK_COUNTER_CHOICE` (`25`).
   - Top-level `controller_player` remains `0`, while the payload correctly says Counter controller `1`.

   Evidence: [annotation](annotation_20261011_145929_001.json).

3. **Expected versus actual continuation**

   Expected acceptance path:

   `resolved parent P` → canonical P-scoped Counter-choice projection → P1 `CounterChoiceCommand(true)` → parent completion → inspection `I` → exact-ID acknowledgements → server-side `CurrentAttackContinuation` derives child Counter Begin carrying `I` → child source `C` replaces P on its first publication → child progresses → ordinary source-scoped terminal clearing.

   Decline uses the same decision surface, records `accepted=false`, completes the parent, performs inspection/acknowledgement, and returns to the enclosing squadron activation without a child.

   Actual execution stops before the first `CounterChoiceCommand`. The no-defense `CommitAccuracy` continuation submits `resolve_damage` directly, while [apply_accuracy_result](../../../../../src/scenes/game_board/attack_executor.gd#L2455) returns with the scene-local FSM still at Modify. `_start_counter_choice_flow()` then attempts the illegal `MODIFY → COUNTER_CHOICE` transition. The FSM rejects it, but [_fsm_advance](../../../../../src/scenes/game_board/attack_executor.gd#L202) ignores that result and republishes the unchanged flow.

4. **Controlling endpoint and authority**

   The host controlled Player 0; the accepted remote peer controlled Player 1. Therefore the remote client was correctly entitled to make the Counter decision.

   [AttackPanelMirror](../../../../../src/scenes/game_board/attack_panel_mirror.gd#L556) only exposes Counter controls when the step is exactly `ATTACK_COUNTER_CHOICE`. Step `18` suppresses the UI. Even a forced submission would correctly fail [CounterChoiceCommand validation](../../../../../src/core/commands/counter_choice_command.gd#L29).

   This is not mapping-specific: either mapping can encounter the same stale FSM transition. The responsible UI merely reflects the invalid projection.

5. **Why automated Counter verification passed**

   Two gaps coincide:

   - The real-ENet Counter scenario [constructs an already-retired parent](../../../../../tests/acceptance/network_resume/driver.gd#L359), with a correct Counter-choice flow, `accepted=true`, and an installed inspection. It begins at acknowledgement and child release, bypassing live damage resolution, decision exposure, and `CounterChoiceCommand`.
   - The unit test [manually advances the FSM to Resolve Damage](../../../../../tests/unit/test_attack_executor_counter.gd#L65) before applying damage, so `RESOLVE_DAMAGE → COUNTER_CHOICE` succeeds.

   The existing unit file still passes `3/3`, confirming that it does not exercise the failing route.

6. **Causal classification**

   **UNRELATED — pre-existing adjacent defect.**

   Repository history places the three causal pieces before this workbook:

   - ignored FSM transition result: April 2026;
   - Counter presentation path: May 2026;
   - no-defense authoritative resolve bypass: August 2026.

   The accepted workbook dates from October 2026, and the current changes do not modify this pre-choice path. The workbook’s manual gate discovered the defect; its implementation did not introduce or alter the failing execution.

   There is no evidence of a shared root with BUG-073.

7. **Smallest architecture-consistent repair**

   At the accepted `resolve_damage` application boundary in `AttackExecutor.apply_damage_result()`:

   - reconcile only the existing scene-local `AttackFlowFSM` through its legal `MODIFY/DEFENSE_TOKENS → RESOLVE_DAMAGE` transition before publishing final damage or Counter;
   - do not submit another gameplay `resolve_damage`;
   - fail closed if that local transition is not legal;
   - then retain the existing `RESOLVE_DAMAGE → COUNTER_CHOICE` producer and UI route.

   This yields step `20` for final-damage publication and step `25`, controller P1, for Counter publication. No new owner, fallback, or validation relaxation is needed.

8. **Accepted-workbook conformance**

   No amendment is required. The workbook already requires a canonical parent-source `ATTACK_COUNTER_CHOICE` before the accepted parent/inspection/child lifecycle; see [Section 5.1](../../../../architecture/implementation_workbooks/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md#L310).

   This is a bounded implementation-conformance correction.

9. **Compatibility/version impact**

   None:

   - Save remains 10.
   - Network remains 11.
   - Replay remains 12.
   - No adapter or migration is required.

10. **Required regression coverage**

   Add a production-path regression that starts before `commit_accuracy` and proves:

   - accepted command-owned no-defense resolution advances the existing FSM to Resolve;
   - correct Counter projection and actual UI controls appear only for the controlling endpoint;
   - both accept and decline submit valid Counter choices;
   - acceptance performs parent completion, inspection, exact-ID acknowledgements, explicit child Begin, parent-to-child projection replacement, child progression, and terminal clearing;
   - decline completes without a child;
   - both real-ENet role mappings use the actual UI signal path;
   - rejected transitions publish no stale payload;
   - pending-choice and accepted-parent state survive Save 10/load/reconnect;
   - format-12 replay reproduces the complete lifecycle deterministically;
   - existing stale-publication, terminal, Counter inspection-release, and identity tests remain passing.

11. **Authorization and stop status**

   Implementation may proceed without a new Owner architecture decision. BUG-074 is acceptance-blocking because the Owner-controlled Counter gate cannot complete.

   Per instruction, I stopped after diagnosis. The BUG-074 replay and all Owner-controlled fixtures remain unchanged.

## Final acceptance preparation — 2026-10-15

Status: **OWNER ACCEPTED AND RESOLVED; BUG-074 closed.**

The Project Owner completed genuine Network gameplay verification and accepted
the result as **PASS**. The preserved successful session is:

- [Replay-12](replay_20261015_065840.json)
- [Network log](game_20261015_065610.log)
- [final acceptance evidence review](evidence/final-acceptance-evidence.md)

The accepted history proves a triggering-attack-destroyed TIE Interceptor can
accept Counter, enter one explicit authoritative child attack, traverse locked
Declare and normal Roll/resolution, complete both exact acknowledgement pairs,
release inspection J through the original X-wing Squadron activation, and
reach the next stable enclosing interaction.

The Owner separately revised the accepted workbook so additional
Owner-recorded histories for surviving Accept, surviving Decline, and destroyed
Decline are deferred to the GGS assurance backlog. All eight real-ENet
combinations, focused/full automated convergence, Save/reconnect and
compatibility coverage, the successful destroyed-Accept Replay-12, and the
validated permanent Network replay fixture remain acceptance evidence. The
deferral does not authorize GGS-001 Gate 2 or make GGS an automatic replacement
for Replay-12 assurance.

Compatibility remains Save 10 / Network 11 / Replay 12 with no adapter or
migration. Owner evidence and replay fixtures remain unchanged. The final
closure audit passed, and BUG-074 is resolved in the closed defect archive.

## 1. Original BLOCKER dispositions

1. **Required lifecycle identity — CLOSED.**
   The workbook now requires top-level `source_attack_id` to be captured by the central producer from canonical `CurrentAttackState.attack_id` when each command is created. It explicitly covers fresh Ship, Squadron, Counter-after-Begin, and reconstructed attacks, and prohibits execution-time substitution. See [workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md:254).

2. **No-active inter-attack publications — CLOSED in architecture, with one new refinement below.**
   The workbook correctly suppresses both `PublishAttackFlowCommand` and direct ATTACK-flow writes during next-squadron and second-hull-zone selection. It retains authority on existing `ShipInstance`/Squadron activation facts rather than extending the retired attack or creating a continuation owner. This is consistent with CON-001 and CON-007.

3. **Source-scoped terminal clearing — OPEN.**
   The new source predicate is correct, but the proposed command cannot reliably reach it:

   - Normal human completion installs `CompletedAttackInspection`; current preflight blocks `publish_attack_flow` while that inspection exists. See [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:336).
   - A host-side terminal publication submitted synchronously from `command_executed` can be executed/broadcast reentrantly before the triggering command’s broadcast completes. See [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:440) and [network_host_command_submitter.gd](/Users/Katharina/godot/Armada/src/core/commands/network_host_command_submitter.gd:22).
   - Counter replacement needs the parent attack’s accepted `ATTACK_COUNTER_CHOICE` projection until the child Counter Begin validates. A generic parent terminal clear can erase that prerequisite. See [counter_choice_command.gd](/Users/Katharina/godot/Armada/src/core/commands/counter_choice_command.gd:27) and [begin_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:431).

   **Smallest correction:** Add the terminal admission/ordering surfaces to scope. Permit only a strictly source-matching final publication through completed-inspection preflight, submit it after—not reentrantly within—the triggering Network result distribution, and explicitly omit it while an accepted parent Counter choice must survive until Counter Begin. A delayed parent clear must then reject against the child attack’s new ID.

4. **Compatibility/version contradiction — CLOSED.**
   Save 10, Network protocol 11, replay and signed-replay format 12, strict mismatch rejection, and manual replacement recording are correctly specified.

## 2. Original REQUIRED REFINEMENT dispositions

1. **Identity-free ship result normalization — CLOSED.**
   The field mapping matches production `resolved_outcome`: `affected_zone`, `post_resolution_shields`, `hull_damage`, `shield_absorbed`, `final_damage`, and `destroyed`. Canonical card collections remain the refresh source.

2. **Exact fallback eligibility — CLOSED.**
   Both explicit fields must be present and exact, or both absent. Partial, mistyped, invalid, and out-of-range identity fails without fallback. Fallback additionally requires `resolve_damage`, `target_kind == "ship"`, and a matching active canonical attack.

3. **Broad `GameState` validator excluded — CLOSED.**
   Section 4.3 clearly keeps the broad live-validator outside authorized scope.

4. **Expanded regression matrix — CLOSED relative to the original finding.**
   Producer-time capture, all attack entry paths, stale/duplicate rejection, inter-attack suppression, terminal identity, damage shapes, both mappings, reconnect, replay, and version boundaries are now represented.

## 3. NEW BLOCKER

No separate new blocker beyond the still-open original terminal-clearing blocker. The newly exposed Counter and Network-ordering contradictions are reasons that blocker remains open.

## 4. NEW REQUIRED REFINEMENTS

- **Counter distinction must be explicit.**
  The workbook’s phrases “pre-Begin Counter setup remains transient” and “Counter setup before Begin writes/publishes no canonical ATTACK flow” are too broad.

  Production has two different states:

  1. The parent attack’s canonical `ATTACK_COUNTER_CHOICE` projection is valid, source-scoped to the still-active parent attack, and required by `CounterChoiceCommand`.
  2. The child Counter attack’s premature `_flow_fsm.begin(game_state, …)` write before its own Begin is the noncanonical operation that must be suppressed.

  **Smallest correction:** State that parent Counter-choice publications remain source-scoped to the parent attack and that the accepted choice projection survives parent retirement until child Begin validates and replaces it. Only the child’s pre-Begin ATTACK write/publication is suppressed. Add this exact parent-ID → accepted choice → retirement → child-ID sequence to the matrix.

- **Name the inter-attack presentation projection surface.**
  Canonical enclosing facts are sufficient, but the current live projector is not: `UIProjector.project()` returns immediately for a NONE flow, while inactive-attack reconstruction currently creates a direct no-active ATTACK flow. See [ui_projector.gd](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:132) and [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:385).

  **Smallest correction:** Add the existing projection consumers—`UIProjector`/`ModalRouter` or the established `AttackPanelController` reconstruction seam—to authorized scope. Require them to derive local selection versus remote waiting directly from existing canonical activation facts without installing an ATTACK flow.

## 5. Optional observations

- The proposed diagnostic distinctions remain optional and must not become correctness checks.
- A narrow shared target-lookup helper remains acceptable.
- The workbook correctly retains STOP conditions rather than authorizing a new durable between-attacks state.

## 6. Compatibility/version assessment

**PASS**

- Save format 10 remains valid because no `GameState` or save schema change is required.
- Protocol 11 is sufficient for the required command semantic change.
- Replay and signed-replay format 12 are sufficient and correctly advance together.
- Strict protocol/replay rejection is preserved.
- No protocol-10 adapter, replay-11 migration, missing-ID inference, or other compatibility machinery is authorized.
- Both replay fixtures are correctly reserved for Owner-only recording. The prohibition on Codex generation, transformation, reconstruction, patching, header editing, and re-signing is explicit and sufficient.

The eventual terminal correction does not require another version increase if completed before protocol 11/replay 12 are accepted.

## 7. Regression-matrix assessment

The matrix is sufficient to reproduce the original mapping-1 facedown-only failure: it requires the delayed non-final publication to cross completion, acknowledgements, inspection consumption, and activation advance, then reject atomically. Mapping 0 and mapping 1 both require filtering and final-state convergence.

Before acceptance, add:

- terminal publication admission while `CompletedAttackInspection` exists;
- host reentrant/broadcast-order protection;
- replay execution of the same terminal sequence;
- parent Counter-choice preservation through retirement and child Begin;
- proof that a delayed parent terminal clear rejects after Counter replacement;
- live, save/load, and reconnect projection of inter-attack local selection versus remote waiting without any ATTACK-flow write.

## 8. Final verdict

**BLOCKED**

All original findings except terminal clearing are closed. The remote damage repair, version cutovers, manual fixture boundary, and original stale-publication matrix are satisfactory.

## 9. Owner acceptance and implementation authorization

The workbook is **not yet ready for Owner acceptance or implementation authorization**. It needs the terminal admission/ordering correction and the two required refinements above, followed by another targeted closure check.

No files were changed. Focused production tests passed: **36 tests, 95 assertions** covering Counter presentation, current attack-flow publication behavior, and damage resolution. `git diff --check` reported no errors. Fixtures, baselines, exact-RNG work, and GGS-001 Gate 2 were untouched.


## Second closure audit

1. **Remaining terminal blocker: CLOSED**

The revised terminal design is consistent with production ordering:

- The exact matching-final predicate excludes malformed, non-final, mismatched, stale, duplicate, newer-attack, and unrelated publications before mutation ([workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md:389)).
- `CommandProcessor` captures the pre-mutation flow, queues observer follow-ups before semantic continuations, and drains them FIFO only after the triggering submission returns ([command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:414)).
- Both remote-authored and host-authored Network paths distribute the trigger before draining follow-ups ([network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:1676), [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:2064)).
- Replay submissions suppress live observer derivation and therefore preserve explicit history order.
- No reentrant `command_executed` terminal submission or new lifecycle owner is required.

2. **Counter refinement: OPEN**

The parent/child identity distinction is now correct, but the sequence omits a production prerequisite:

- `CompleteAttackCommand` installs a `CompletedAttackInspection` before retiring the parent ([complete_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/complete_attack_command.gd:54)).
- `BeginAttackCommand` cannot validate until that inspection is satisfied and its exact ID is supplied ([begin_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:21)).
- The current satisfied-inspection release for a Squadron attacker derives `CompleteSquadronActivationCommand`, not the accepted Counter child Begin ([current_attack_continuation.gd](/Users/Katharina/godot/Armada/src/core/state/current_attack_continuation.gd:305)).
- Current presentation code attempts the child Begin from the parent-completion `command_executed` reaction ([attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:4098)). In Network play this may occur before parent-result distribution and on the parent attacker’s endpoint, which need not control the child Counter attacker.

Smallest correction: authorize the existing authoritative attack-continuation surface to derive the already-accepted child Counter Begin only after any completed inspection is satisfied, carrying its inspection ID and using the preserved parent Counter projection. Queue it through the existing post-success follow-up order; replay must contain the explicit recorded Begin and synthesize nothing. Remove reliance on the scene’s reentrant completion callback for semantic child entry.

3. **Inter-attack presentation refinement: OPEN**

The proposed canonical facts and `UIProjector → ModalRouter → AttackPanelController` design are sufficient and do not require synthetic attack identity. However, the authorized route is not currently entered during reconstruction:

- Board startup calls inactive attack reconstruction directly before creating the command-router adapter ([game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd:1343)).
- Its later `reconstruct_presentation()` condition does not include the no-active inter-attack state ([game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd:1391)).
- `game_board.gd` is absent from the workbook’s authorized production scope, despite the requirement that live, save/load, and reconnect all use the same route.

Smallest correction: add `game_board.gd` to authorized scope. Restrict its early resume path to active attacks and route an inactive canonical inter-attack decision through `_command_router_adapter.reconstruct_presentation()` after the router and viewer identity exist.

4. **NEW BLOCKER**

None.

5. **NEW REQUIRED REFINEMENT**

The Counter inspection-release and Network-authoring/order requirement described above. The GameBoard reconstruction entrypoint is the still-open prior inter-attack refinement, not separate new scope.

6. **Compatibility/version assessment**

**PASS.** Nothing found invalidates:

- Save format 10;
- Network protocol 11;
- replay and signed-replay format 12;
- strict mismatch rejection;
- no adapters or migrations;
- Owner-only manual replay recording.

Neither required correction needs a schema or version increase. Exact-RNG work and GGS-001 Gate 2 remain outside scope.

7. **Regression-matrix assessment**

The requested rows are present, but two additions are required:

- Combine Counter replacement with unsatisfied/satisfied inspection release, exact inspection-ID consumption, authority-side child Begin, and both Network role mappings.
- Exercise save/load and reconnect through the actual `GameBoard` ready/reload entrypoint, proving the router—not direct pre-router reconstruction—produces controller selection and remote waiting.

The mapping-1 facedown delayed-publication sequence remains adequately specified.

8. **Final verdict**

**PASS WITH REQUIRED REFINEMENTS**

9. **Owner acceptance and implementation authorization**

The workbook is **not yet ready** for Owner acceptance or implementation authorization. The terminal blocker is closed, but the Counter and inter-attack refinements remain open.

No files, fixtures, baselines, or production code were changed. Verification was static against the revised workbook, accepted authority, and the relevant production command, Network, replay, Counter, inspection, and reconstruction paths.


1. **Counter refinement: CLOSED**

The sequence is valid against production authority:

- `CurrentAttackContinuation` is the existing stateless evaluator used by the sole `CommandProcessor` post-success release seam.
- Existing `completed_attack_inspection_id` validation and `replace_satisfied_inspection_with_current_attack()` provide exact-ID, atomic inspection consumption with child installation.
- Live authority queues exactly one child Begin after final-acknowledgement distribution; endpoint ownership is bypassed only through the existing authoritative submitter.
- Unsatisfied, stale, duplicate, malformed, or mismatched states derive nothing.
- Scene-reentrant semantic Begin is explicitly prohibited.
- Replay suppresses derivation and applies the explicitly recorded Begin.
- Parent projection survives until child Begin and child publication replace it; delayed parent clearing then rejects unchanged.
- No owner or serialized state is added.

2. **GameBoard/inter-attack refinement: CLOSED**

The workbook now authorizes the necessary `game_board.gd` change and specifies the correct order:

- Early direct resume is limited to active attacks.
- Router/controller/viewer setup precedes inactive reconstruction.
- Next-squadron and second-hull-zone decisions enter the normal projector/router/controller route.
- Existing canonical `ShipInstance` activation progress and target legality are sufficient for local selection versus passive waiting.
- Save/load and reconnect use the real `GameBoard` ready/reload path.
- Both role mappings derive presentation from canonical player identity.
- No ATTACK-flow write, synthetic identity, or durable continuation owner is introduced.

3. **NEW BLOCKER**

None.

4. **NEW REQUIRED REFINEMENT**

None.

5. **Regression coverage assessment**

**SUFFICIENT.** The matrix explicitly covers the complete Counter inspection sequence, wrong/stale IDs, premature and duplicate prevention, absence of scene-reentrant Begin, child publication ordering, both Network mappings, history-only replay, actual GameBoard save/load and reconnect entrypoints, and both inter-attack decision shapes.

6. **Compatibility/version assessment**

**PASS.** Save 10, Network protocol 11, replay and signed-replay format 12, strict rejection, no adapters or migrations, and Owner-only manual fixture recording remain correct. Exact-RNG promotion and GGS-001 Gate 2 remain excluded.

7. **Final verdict: PASS**

8. The workbook is ready for Owner acceptance and subsequent implementation authorization.

**READY FOR OWNER ACCEPTANCE**

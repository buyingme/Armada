## 1. Overall verdict

**BLOCKED**

The workbook identifies the two defects separately and chooses the correct authority seam for stale-publication rejection. However, its proposed lifecycle predicate cannot safely accept current legitimate publications, cannot authenticate terminal clears, and is incompatible with existing Network/replay payloads.

## 2. Blockers

- **BLOCKER — Required `attack_id` is absent from current legitimate publications.**
  Fresh Ship, Squadron, and Counter flow payloads do not contain `flow_payload.attack_id`. Only reconstructed/resumed projection explicitly adds it. The existing Network replay contains 50 non-final publish commands, all without the proposed identifier. The workbook’s predicate would therefore reject current valid traffic. See [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2030), [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1695), and [attack_flow_executor.gd](/Users/Katharina/godot/Armada/src/core/combat/attack_flow_executor.gd:307).

  **Smallest correction:** Add the central publication producer to implementation scope and require it to snapshot the active canonical `CurrentAttackState.attack_id` into every post-Begin publication when the command is created. Explicitly cover fresh Ship, Squadron, Counter, and reconstructed attacks. Never infer a missing ID from whichever attack is active when the queued command later executes.

- **BLOCKER — Current inter-attack publications have no active attack.**
  Squadron and second-hull-zone continuation paths publish target-selection flow after the previous attack has retired but before the next Begin. The proposed absolute “non-final requires active attack” rule rejects them. See [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:4410).

  **Smallest correction:** Classify these paths explicitly. Prefer suppressing these noncanonical publications and deriving/transiently presenting the enclosing activation route; otherwise define an accepted canonical identity without creating a new lifecycle owner. Add focused regression coverage.

- **BLOCKER — Terminal clears carry no source attack identity.**
  `AttackFlowFsm.end()` clears the authority flow before the final command is created; the submitted final payload is empty. Host-attacker execution would reject its own clear under the proposed predicate, while a delayed remote clear cannot be distinguished from a newer ATTACK flow. See [attack_flow_fsm.gd](/Users/Katharina/godot/Armada/src/core/combat/attack_flow_fsm.gd:191), [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1135), and [publish_attack_flow_command.gd](/Users/Katharina/godot/Armada/src/core/commands/publish_attack_flow_command.gd:67).

  **Smallest correction:** Preserve the source `attack_id` before ending/resetting the FSM and include it in terminal publication commands. Permit a clear only when the current ATTACK projection carries that exact ID and no active replacement exists. If authority is already NONE/non-ATTACK, reject or omit the redundant command.

- **BLOCKER — Compatibility claims are contradicted by repository evidence.**
  A newly required publication identity changes the command/wire semantic model. Protocol version is currently 10, with an instruction to increment it when message format changes; replay version is 11 and existing affected fixtures lack the field. See [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:28), [game_replay.gd](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:31), and [replay_network.json](/Users/Katharina/godot/Armada/tests/fixtures/baseline_traces/replay_network.json:587).

  **Smallest correction:** Replace the workbook’s fixed “no protocol/replay/fixture change” conclusion with an Owner compatibility gate. Require the next accepted Network protocol and replay-format versions, followed by manual recording of affected replay fixtures under repository workflow—never fixture transformation.

## 3. Required refinements

- **REQUIRED REFINEMENT — Normalize the identity-free ship result shape.**
  Canonical ship lookup alone is insufficient. `resolved_outcome` provides `affected_zone`, `post_resolution_shields`, and `hull_damage`, while the current presentation handler expects `hull_zone`, `new_shields`, and nested `damage_application`/legacy card fields. Merely finding the ship can still omit shield and hull/card signals.

  **Smallest correction:** Specify a narrow `resolved_outcome` branch that maps those canonical fields and refreshes card state from the canonical `ShipInstance`. Test shield-only, facedown hull, faceup/inspection, and lethal results.

- **REQUIRED REFINEMENT — Make fallback eligibility exact.**
  Fallback must occur only when both explicit identity fields are absent. Partially present, mistyped, invalid, or out-of-range identity must fail rather than be coerced or silently replaced.

  **Smallest correction:** Require a recognized `target_kind == "ship"` result shape; if either `owner_player` or `ship_index` exists, require both as valid integers and prohibit fallback.

- **REQUIRED REFINEMENT — Keep the optional full-state validator off by default.**
  Current no-active inter-attack states demonstrate that a broad validator may reject valid intermediate production states.

  **Smallest correction:** State that the optional `GameState` validator is not part of this repair unless separate evidence covers fresh attacks, between-attack selection, completed inspection, cancellation, Counter replacement, terminal completion, direct host scene writes, save/load, replay, and reconnect.

- **REQUIRED REFINEMENT — Expand the regression matrix around producer and terminal semantics.**
  Add direct assertions for publication identity at creation, no-active inter-attack handling, source-scoped final clears, and exact presentation signals for each identity-free outcome shape.

## 4. Optional improvements

- **OPTIONAL:** Distinguish malformed, stale-active, retired-source, and mismatched-final rejection reasons in diagnostics. Logs must not become the correctness oracle.
- **OPTIONAL:** Share narrowly scoped canonical target-lookup code between Ship and Squadron handling if it remains a lookup utility, not a new identity or continuation framework.

## 5. Attack-lifecycle validation assessment

Validation in `PublishAttackFlowCommand` before mutation is the correct authority boundary and does not inherently create a new lifecycle owner. Exact comparison against canonical `CurrentAttackState.attack_id` is also correct.

The workbook is nevertheless unsafe as written because it assumes source identities that are not produced and treats all no-active publications uniformly. Once source IDs are captured at command creation and terminal/inter-attack paths are resolved, FIFO order and queue coalescing can remain optimizations rather than correctness mechanisms.

## 6. Remote damage-identity assessment

Canonical derivation from the active matching `CurrentAttackState` is sufficient and unambiguous for the diagnosed identity-free ship outcome: attack ID, kind, defender player, and defender index are canonical gameplay identity.

Endpoint, principal, network role, active player, and UI state must not participate. The current Squadron fallback follows the right pattern. The remaining deficiency is result-shape normalization after identity is recovered.

## 7. Distributed/reconnect/replay assessment

- Ordered Network execution makes the active attack available during the diagnosed identity-free damage callback, but timing must not substitute for ID validation.
- Reassociation and principal binding require no change.
- Reconstructed attacks already project their attack ID; fresh attacks do not.
- Canonical save state needs no new field, so a save-version change is not currently justified.
- Replay and Network compatibility do require an explicit cutover because old commands lack the newly mandatory identity.
- No new continuation or lifecycle owner is needed.

## 8. Regression-matrix sufficiency

The mapping-1 facedown-only scenario is well targeted: it delays the non-final publication beyond completion, acknowledgement, inspection consumption, and activation advance, then requires atomic rejection and convergence. The mapping-0 control and both role mappings are appropriate.

The matrix is not implementation-ready until it also proves:

- fresh Ship, Squadron, and Counter publications contain the source ID;
- inter-attack publications are suppressed or validly classified;
- final clears cannot affect a newer ATTACK flow;
- identity-free ship results emit correct shield, hull/card, summary, and destruction signals;
- new fixtures work under the accepted replay/protocol versions.

## 9. Compatibility/version assessment

The claim is only partly supportable:

- **No canonical state/save schema change:** supported.
- **No damage-result or principal-binding change:** supported.
- **No command semantic/schema change:** challenged.
- **No Network protocol change:** not supported.
- **No replay-format or fixture change:** disproved by the current fixture inventory.

## 10. Remaining Owner decisions

- Choose the protocol/replay compatibility cutover and authorize manual replacement recording for affected fixtures.
- Decide whether no-active inter-attack publications are suppressed as transient presentation or represented through an already-authoritative enclosing lifecycle.
- Accept a revised workbook before implementation begins.
- Keep exact-RNG baseline/hash promotion and GGS-001 Gate 2 separate and paused.

## 11. Implementation readiness

**Not ready.** The workbook should return to drafting until all four blockers and the required refinements are incorporated. The underlying repair direction is viable; the missing producer, terminal, and compatibility design is the barrier.

## 12. Files changed and verification performed

No files were changed. Existing uncommitted work, including the exact-RNG work and the untracked audit documents, was preserved.

Verification performed:

- Read repository workflow, document authority, applicable accepted ADRs/contracts, the diagnosis, workbook, production attack/network/replay code, and relevant tests.
- Inspected current replay fixtures: `replay_network.json` has 50 non-final attack-flow publications and all 50 lack nested `attack_id`.
- Ran focused unit suites for attack-flow publication and damage resolution: **43 tests, 165 assertions, all passed**.
- Ran whitespace/diff validation with no errors.
- Did not run baseline/hash promotion, modify fixtures, perform RNG implementation, or exercise unauthorized GGS-001 Gate 2.

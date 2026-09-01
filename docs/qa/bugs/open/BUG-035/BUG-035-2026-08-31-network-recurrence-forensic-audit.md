## Forensic conclusion

**Proven:** BUG-035 is a projection/recovery defect, not a missing semantic continuation command.

After lethal damage at seq 612, the commanded TIE’s attack is spent but its Move becomes legal because its last live non-Heavy engager was destroyed. Therefore, after seq 615, `CompleteSquadronActivationCommand` is correctly **not** derived. The required stable outcome is the same squadron’s recoverable Move decision. Production instead remains path-dependent: the live modal stays in `ATTACKING`, while the satisfied inspection is projected as a non-actionable result and prevents restoration of `ACTION_CHOICE`.

The `squadron_destroyed` errors are a separate Network event-payload defect. They did not block canonical destruction or semantic continuation evaluation.

All findings below are proven unless marked otherwise.

### Same-replay comparison

| Canonical boundary | Successful host branch | Failing client branch |
|---|---|---|
| Sequence | 210–226 | 598–615 |
| Commanding ship | Nebulon-B, `ship-activation:208` | VSD, `ship-activation:596` |
| Squadron activation | `squadron-activation:210` | `squadron-activation:598` |
| Context | `ship_squadron_command` | `ship_squadron_command` |
| Action state after attack | Move false; Attack `begun` | Move false; Attack `begun` |
| Damage outcome | TIE hull 3 → 1; survives | X-wing hull 1 → 0; destroyed |
| Post-damage engagement | Non-Heavy target remains engaged | Last live nearby non-Heavy engager removed |
| Legal remaining Move | No | **Yes** |
| Activation complete | Yes | **No** |
| Release result | `CompleteSquadronActivationCommand` seq 225 | Derived-only same-squadron Move; no command |
| Enclosing capacity | 1/2, OPEN; next squad seq 226 | 1/3, OPEN, but current squad must finish first |

The successful target remained engaged at approximately 80 px edge distance, inside distance-1. In the failing state, the destroyed target was within distance-1, but surviving enemy squadrons were approximately 366 px and 384 px edge distance away. Destroyed squadrons are excluded by the fresh engagement calculation.

## Requested findings

1. **Failing production sequence.** `begin_attack` 599 → damage resolution 612 → X-wing destruction → `complete_attack` 613 → expected rejection of a post-complete flow publication → acknowledgements 614/615. The resulting inspection is satisfied, `CurrentAttackState` is inactive, the VSD opportunity is OPEN at 1/3 capacity, and the attacking TIE retains activation 598 with Move uncommitted and Attack `begun`. Evidence: [replay](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-035/replay_20260831_212422.json), [annotation](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-035/annotation_20260831_212345_001.json), [terminal capture](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-035/game_20260831_212220_bug035_network_commanded_squadron_stall.txt).

2. **Closest successful same-replay sequence.** Host seq 210–225 is the closest control: a ship-commanded squadron attacks before moving, both acknowledgements execute, and completion 225 is followed by another commanded activation 226. The target survives, so engagement continues and Move is illegal. Earlier seq 88–128 is an additional successful commanded-squadron control.

3. **First semantic divergence.** Immediately after damage: successful seq 220 is non-lethal and retains engagement; failing seq 612 destroys the remaining nearby live engager and makes Move legal. This divergence is correct rules behavior. The **first defective divergence** occurs after seq 615, when the derived Move decision is not recovered into actionable presentation.

4. **Authoritative predicate.** [`GameState.is_squadron_activation_action_complete()`](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:158) requires both:

   - no legal remaining Move, using fresh canonical engagement; and
   - no remaining Attack.

   [`SquadronInstance.has_remaining_move_action()`](/Users/Katharina/godot/Armada/src/core/state/squadron_instance.gd:208) says an uncommitted ship-commanded Move remains available. Attack disposition `begun` makes the Attack unavailable. Fresh engagement makes the Move legal after destruction.

5. **Why no completion after seq 615.** [`CurrentAttackContinuation._derive_squadron_inspection_release()`](/Users/Katharina/godot/Armada/src/core/state/current_attack_continuation.gd:172) returns no command because the activation-complete predicate is false. This is required by CON-007’s derived-only remaining-action branch—not a continuation failure.

6. **Destruction-signal root cause.** The remote handler emits the defending player-0/index-0 **`SquadronInstance`**, hull 0 and destroyed, from [`_handle_remote_resolve_damage()`](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:3157). `SquadronInstance` extends `RefCounted`, while [`EventBus.squadron_destroyed`](/Users/Katharina/godot/Armada/src/autoload/event_bus.gd:98) and four failing subscribers require `Node`. Godot describes both Variant categories as “Object,” hence the confusing “Object to Object” diagnostic; the actual incompatibility is `RefCounted` → `Node`.

7. **Signal/stall causality.** **Independent.** Canonical damage had already reduced hull and marked destruction; `complete_attack` and both acknowledgements executed afterward. The failed callbacks perform no gameplay progression:

   - `GameManager`: no-op;
   - `SfxManager`: audio only;
   - `UIPanelManager`: HUD refresh;
   - `ActivationSidebar`: authoritative-state refresh.

   The `GameBoard` subscriber accepts `Variant` and can handle either a token or `SquadronInstance`. No semantic dependency on the callback exists, so no architecture violation of that form is present. The destruction mutation itself is relevant because it changes Move legality; the signal-delivery failure is not.

8. **Why regressions pass.** The legal-Move test, [`test_dial_commanded_attack_acknowledgement_retains_legal_move_interaction()`](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:2422), starts from an already completed, satisfied fixture and constructs the board afterward. Its fixture manually supplies a `SHIP_ACTIVATION/SQUADRON_STEP` projection and uses Heavy to permit movement. Reconstruction therefore restores `ACTION_CHOICE`; it never exercises a live modal’s `ATTACKING → ACTION_CHOICE` transition, lethal destruction, stale Attack flow, two-human ordered acknowledgements, or a client-authored attack. The terminal/capacity tests instead make Move illegal, so the generated completion command masks this projection gap.

9. **BUG-035 classification and repair boundary.** Current BUG-035 recurrence; implementation defect against CON-007 stable-outcome recovery and ADR-010 decision-equivalent recovery. The narrow boundary is the existing post-final-ack projection seam for a satisfied-but-unconsumed commanded-squadron inspection whose current squadron retains a legal action. Canonical state, predicates, commands, and exact-once consumption do not require alteration.

10. **BUG-031 disposition.** Remains distinct VERIFY. Both issues consult the same activation-completion predicate, but BUG-031 involved a submitted/rejected completion followed by presentation acting as though completion succeeded. Here no completion is derived because Move is genuinely legal. No shared root cause is proven, and no current range-message evidence was found.

11. **Separate destruction-signal BUG.** Yes. It has a distinct root cause, affected boundary, and repair/test matrix: inconsistent local-versus-remote event payload type. It should not be folded into BUG-035.

12. **Missing regression dimensions.**

   - Live production sequence from Begin through final acknowledgement, rather than a post-complete fixture.
   - Attack-before-Move.
   - Lethal destruction of the squadron’s **last live non-Heavy engager**, causing engagement-blocked → Move-legal.
   - Derived-only same-squadron Move with no completion command and satisfied inspection retained.
   - Two-human Network, specifically the observed client-authored attack plus passive host application.
   - Stale Attack flow/result precedence and live modal `ATTACKING → ACTION_CHOICE`.
   - Subsequent Move atomically consumes the inspection, followed by normal child/enclosing convergence.
   - Paired non-lethal control proving completion remains correct.

   **Hypothesis:** client ownership alone is not proven causal because the same-replay host controls are also non-lethal. It should remain a regression axis, not the claimed root cause.

13. **Workbook impact: narrow amendment.** The accepted workbook already authorizes the ship-commanded branch, but its verification matrix conflates “remaining action” with “capacity remains” and marks that row convergence-complete. Its capacity-remains acceptance sequence starts only after `CompleteSquadronActivationCommand`; the current failure is the earlier same-squadron remaining-action branch. Split those branches and add the dimensions above. No replacement workbook is warranted. See [workbook §2.4](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-035-anti-squadron-declaration-reconstruction-implementation-workbook.md:198) and [verification matrix](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-035-anti-squadron-declaration-reconstruction-implementation-workbook.md:585).

14. **Architecture/Owner decisions.** Accepted architecture is sufficient; no architectural stop gate is presently triggered. The production behavior is path-dependent presentation recovery, violating ADR-010, but semantic authority remains correctly canonical and live-authority-only. Owner acceptance is needed only for the narrow workbook acceptance/regression amendment before implementation. If implementation proves that material files outside the workbook’s authorized projection scope are required, workbook stop gate 6 applies. The separate destruction-signal issue should choose one consistent event payload contract, but it requires no BUG-035 architecture redesign.

The rejected `publish_attack_flow` is valid acknowledgement-barrier enforcement by CommandProcessor preflight. It neither changes the completion predicate nor causes the missing command. The stale flow it leaves is projection evidence only and must not become authority.

No files, tests, documents, baselines, or repository state were modified.

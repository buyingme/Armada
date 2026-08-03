# MA-ATTACK-002: Post-Stabilization CON-006 Attack Declaration Compliance Assessment

Status: Draft
Purpose: Migration Assessment
Consumer: Attack Declaration Flow
Historical Baseline: MA-ATTACK-001; MA-ATTACK-002 supersedes the previous workbook readiness recommendation recorded before BUG-005 was investigated.
Assessed Revision: `0a70a16e1cbce7a9bec256250374eddcc4f41e40`

Authority:

- ADR-001
- ADR-003
- ADR-004
- ADR-005
- CON-001
- CON-003
- CON-004
- CON-005
- CON-006
- TEST-003
- MA-ATTACK-001

---

## Purpose

This migration assessment records the post-stabilization compliance of the current attack-declaration implementation with accepted CON-006.

It compares the clean repository state after the accepted declaration and BUG-002 stabilization work with the historical pre-stabilization baseline preserved in MA-ATTACK-001.

This assessment:

- identifies which MA-ATTACK-001 findings are resolved, partially resolved, unchanged, or superseded;
- records the remaining CON-006 compliance scope;
- evaluates relevant open bugs only for their relationship to that remaining scope;
- establishes the evidence required before drafting TWI-ATTACK-001;
- remains implementation evidence only.

It does not redefine architecture, reopen accepted Owner Decisions, prescribe implementation order, define implementation slices, or serve as an implementation workbook.

CON-006 scope ends at an accepted `BeginAttackCommand` or an accepted no-active declaration `SkipAttackCommand`. Active attack completion, cancellation, replacement, cleanup, Step 6 continuation, and second-attack continuation are neighboring post-Begin context only.

---

## Documents And Evidence Reviewed

### Startup Documents

The following mandatory startup documents were read:

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

### Architecture And Verification Authority

- [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
- [ADR-003](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md)
- [ADR-004](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md)
- [ADR-005](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md)
- [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
- [CON-003](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-003-rule-capability-contract.md)
- [CON-004](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-004-upgrade-runtime-contract.md)
- [CON-005](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-005-timing-window-implementation-contract.md)
- [CON-006](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md)
- [TEST-003](/Users/Katharina/godot/Armada/docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md)
- [MA-ATTACK-001](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-ATTACK-001-con-006-compliance.md)

The accepted Migration Assessments for Tarkin, ECM, H9, and the cross-consumer timing-window synthesis were inspected for document conventions.

### Stabilization Evidence

- [Verified declaration repair plan](/Users/Katharina/godot/Armada/docs/qa/bugs/verify/BUG-000/issue-ATTACK-001-target-reassignment-con006-repair-plan.md)
- [BUG-002 issue](/Users/Katharina/godot/Armada/docs/qa/bugs/verify/BUG-002/issue_attack-sequence-early-termination.md)
- [Accepted BUG-002 forensic analysis](/Users/Katharina/godot/Armada/docs/qa/bugs/verify/BUG-002/forensic-analysis-report.md)
- [BUG-002 forensic follow-up](/Users/Katharina/godot/Armada/docs/qa/bugs/verify/BUG-002/forensic-analysis-report-2.md)
- Current production implementation and focused automated evidence committed by `7bc978a` and `0a70a16`.

The completed architecture-preservation verification referenced by the assessment request was treated as accepted review input. No standalone repository document containing that review was found. Current implementation ownership was therefore also checked directly against the accepted contracts.

### Open Bugs Reviewed

- [BUG-001 / NOTE-001 — Network Save/Load Session Bootstrap Investigation](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-001/issue_network-save-load-session-bootstrap.md)
- [BUG-003 — Attack Can Be Skipped After Commitment](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-003/issue-cant-skip-after-commit.md)
- [BUG-004 — Command Token Not Refreshed After Grand Moff Tarkin Selection](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-004/issue-Command-Token-Not-Refreshed-After-Grand-Moff-Tarkin-Selection.md)
- [BUG-005 — Squadron Attack Allowed Beyond Range 1](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-005/issue-squadron-attack-allowed-beyond-range-1.md)
- [BUG-005 forensic analysis](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-005/forensic-analysis-report.md)

The associated BUG-003, BUG-004, and BUG-005 annotations were also reviewed.

---

## Assessed Revision And Worktree

The assessed repository state is:

- Branch: `master`
- Revision: `0a70a16e1cbce7a9bec256250374eddcc4f41e40`
- Commit date: `2026-08-02T05:45:43+02:00`
- Commit subject: `fix(attack): complete BUG-002 authoritative attack continuation repair`
- Worktree: clean
- `git status --short`: no output
- `git diff --stat`: no output

Unlike MA-ATTACK-001, this is a stable committed repository baseline rather than a dirty mixed worktree.

Repository identifiers require one clarification: the accepted target-reassignment stabilization is stored under `docs/qa/bugs/verify/BUG-000` and names its related defect `BUG-ATTACK-001`. The currently open repository `BUG-001` is the separate network save/load bootstrap investigation. These records are not treated as the same defect.

This assessment did not execute tests. It relies on committed automated evidence and the accepted stabilization record.

---

## Post-Stabilization Baseline

### Transient Preview And Confirm

`TargetSelector` now owns one explicit transient declaration candidate and a pending flag. Candidate selection remains outside canonical state:

- [target_selector.gd:130](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:130)
- [target_selector.gd:134](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:134)
- [target_selector.gd:1152](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1152)
- [target_selector.gd:1183](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1183)

A legal selection creates Preview without submitting Begin. Replacement, deselection, and illegal selection remain transient. Explicit declaration Confirm reads the current candidate and submits one Begin:

- [attack_executor.gd:1391](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1391)
- [test_squadron_attack_target_recovery.gd:345](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:345)
- [test_squadron_attack_target_recovery.gd:395](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:395)

The replay-visible declaration replacement sequence `Begin → Skip(flow_replaced) → Begin` has been removed. Preview A → B → C produces one accepted Begin for the final candidate:

- [test_current_attack_shared_protocol.gd:533](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:533)
- [test_attack_commands.gd:622](/Users/Katharina/godot/Armada/tests/unit/test_attack_commands.gd:622)

### Pending And Rejection Recovery

The declaration interaction is disabled while Begin or Skip is pending. Accepted results clear the candidate; rejected results retain or restore the prior declaration:

- [attack_executor.gd:1483](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1483)
- [attack_executor.gd:1507](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1507)
- [test_squadron_attack_target_recovery.gd:166](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:166)
- [test_squadron_attack_target_recovery.gd:312](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:312)

Network authority now returns targeted rejection acknowledgements, clears the client submission gate, and reports the rejection to declaration presentation:

- [network_command_submitter.gd:69](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:69)
- [network_manager.gd:695](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:695)
- [game_manager.gd:2257](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2257)
- [test_squadron_attack_target_recovery.gd:431](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:431)

### Authoritative Ship Attack Progress

`ShipInstance` now owns serialized activation-local attack progress:

- `attack_step_active`
- `committed_attack_count`
- `used_attack_hull_zones`
- `anti_squadron_attack_zone`
- `anti_squadron_target_history`

Evidence:

- [ship_instance.gd:98](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:98)
- [ship_instance.gd:342](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:342)
- [ship_instance.gd:362](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:362)
- [ship_instance.gd:382](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:382)
- [ship_instance.gd:572](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:572)

`AdvanceActivationStepCommand` initializes or closes that progress together with the authoritative activation step:

- [advance_activation_step_command.gd:66](/Users/Katharina/godot/Armada/src/core/commands/advance_activation_step_command.gd:66)

For a standard ship attack, Begin fails closed without an active attack opportunity. It validates the ship-owned progress and atomically commits it with `CurrentAttackState`, restoring the progress snapshot if state installation fails:

- [begin_attack_command.gd:16](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:16)
- [begin_attack_command.gd:48](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:48)
- [begin_attack_command.gd:109](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:109)

### Neighboring Post-Begin Continuation Context

The following behavior is outside CON-006 but is material stabilization context:

- an anti-squadron attack can continue against multiple eligible squadrons without consuming another normal attack;
- the same surviving squadron can be attacked during two independently legal normal attacks;
- a second normal attack can use another hull zone;
- `CompleteAttackCommand` retires the individual attack and derives continuation from `ShipInstance`;
- inactive Step 6 and second-attack continuations reconstruct after save/load and filtered-state reconnect.

Evidence:

- [complete_attack_command.gd:36](/Users/Katharina/godot/Armada/src/core/commands/complete_attack_command.gd:36)
- [test_ship_instance.gd:336](/Users/Katharina/godot/Armada/tests/unit/test_ship_instance.gd:336)
- [test_ship_instance.gd:360](/Users/Katharina/godot/Armada/tests/unit/test_ship_instance.gd:360)
- [test_current_attack_shared_protocol.gd:142](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:142)
- [test_current_attack_shared_protocol.gd:282](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:282)
- [test_current_attack_production_resume.gd:471](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:471)
- [test_current_attack_production_resume.gd:584](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:584)

These post-Begin behaviors do not determine any CON-006 compliance classification.

### Architecture Preservation

The stabilization retains:

- `GameState` ownership of canonical `CurrentAttackState`;
- `ShipInstance` ownership of ship activation-local attack progress;
- replayable commands as semantic mutation surfaces;
- scene and UI surfaces as coordinators and projections;
- existing replay, networking, serialization, and projection channels.

No new authoritative owner, command protocol, compatibility layer, or architecture document was introduced by the BUG-002 stabilization.

---

## Overall Assessment

The current repository is **Partially compliant** with CON-006.

The stabilization resolved the declaration interaction’s most visible lifecycle gaps:

- Preview no longer begins an attack;
- candidate replacement is transient;
- explicit declaration Confirm exists;
- replacement no longer creates replay-visible active cancellation;
- pending and rejection recovery are implemented;
- network rejection releases the client submission gate;
- standard ship Begin coordinates canonical attack state with serialized ship attack progress.

The main remaining compliance boundary is the authoritative enclosing transaction:

- declaration Skip remains a no-active command result without context-specific authoritative effects;
- squadron activation/action/attack progress remains modal-local rather than serialized on its accepted existing owners;
- standard squadron Begin does not atomically commit that enclosing progress;
- command applicability remains phase-scoped and does not agree with the applicable flow policies and complete opportunity validation;
- ship Preview and Begin do not yet have complete semantic-parity evidence;
- durability and distribution evidence remains incomplete for squadron contexts and post-Skip state.

The completed BUG-005 forensic investigation establishes an additional CON-006 declaration-legality defect: `TargetingListBuilder` applies the close-range threshold rather than the distinct distance-1 threshold when deriving squadron outgoing target eligibility. Preview and Begin consume the same incorrect result.

---

## MA-ATTACK-001 Delta Matrix

| MA-ATTACK-001 responsibility | Original conclusion | Current repository evidence | Delta classification | Remaining obligation | TWI-ATTACK-001 |
|---|---|---|---|---|---|
| Supported declaration contexts and all four pairings | Partially compliant | Four pairings are exercised through canonical Begin tests ([test_current_attack_shared_protocol.gd:314](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:314)), but complete Rogue, Squadron Phase, and ship-phase Squadron-command declaration transactions are not represented on authoritative enclosing owners. | Partially resolved | Prove and complete every CON-006 supported enclosing context. | Yes |
| `GameState` ownership of `CurrentAttackState` | Fully compliant | Private clone-protected state, serialization, validation, and setter ownership remain unchanged. | Unchanged | None. | No |
| Complete attack-entry facts and declaration context | Partially compliant | Begin creates complete individual-attack state and standard ship Begin now commits ship progress, but squadron action/opportunity facts remain absent. | Partially resolved | Complete applicable enclosing context for squadron declarations and declaration Skip. | Yes |
| Adjacent authoritative owners | Non-compliant | `ShipInstance` now owns serialized ship progress ([ship_instance.gd:98](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:98)); squadron move/attack progress remains modal-local ([squadron_activation_modal.gd:98](/Users/Katharina/godot/Armada/src/ui/combat/squadron_activation_modal.gd:98)). | Partially resolved | Bind squadron opportunity, action, and attack history to existing authoritative owners. | Yes |
| `TargetSelector` sole transient candidate ownership | Partially compliant | `TargetSelector._declaration_candidate` is the sole mutable command-intent candidate; shared `AttackState` is documented as derived scene projection. | Resolved | Preserve as regression evidence. | No |
| First legal selection produces Preview without a command | Partially compliant | Selection creates a candidate and confirm affordance without changing command cursor or `CurrentAttackState`. | Resolved | Preserve as regression evidence. | No |
| Replace, deselect, and illegal selection remain transient | Partially compliant | A → B → C replacement, illegal-selection preservation, and reselection/deselection tests now record no semantic command before Confirm. | Resolved | Preserve as regression evidence. | No |
| Preview and Begin semantic parity | Partially compliant | Standard squadron Preview reuses the authoritative targeting candidate, while ship Preview still derives through scene geometry and Begin re-derives through `TargetingListBuilder`. | Partially resolved | Establish full behavioral parity for every supported pairing and context. | Yes |
| Explicit declaration Confirm | Not implemented | `_on_declaration_confirm()` submits Begin from the current complete candidate. | Resolved | Preserve distinction from dice confirmation. | No |
| Pending gate and rejection recovery | Partially compliant | Candidate interaction is gated while pending; local and network rejection restore the prior declaration and release the network submitter. | Resolved | Preserve as regression evidence. | No |
| Begin validation and atomic authoritative mutation | Partially compliant | Standard ship Begin validates and atomically commits `ShipInstance` progress plus `CurrentAttackState`, with rollback. Squadron adjacent-owner mutations remain absent. | Partially resolved | Complete atomicity for supported squadron contexts. | Yes |
| Declaration Skip while no attack is active | Non-compliant | A no-active voluntary Skip still returns a result without committing context-specific enclosing progress ([skip_attack_command.gd:41](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:41), [skip_attack_command.gd:73](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:73)). | Unchanged | Implement the CON-006 Skip effect matrix for every supported context. | Yes |
| `InteractionFlow` and UI derived from authoritative declaration state | Partially compliant | Pre-Begin Preview now preserves the enclosing flow. Accepted Begin publishes attack flow after canonical state exists. Accepted no-active Skip still routes through scene teardown without an authoritative enclosing mutation. | Partially resolved | Derive post-Skip routing from the resulting authoritative context. | Yes |
| Runtime rule and timing-window ownership | Fully compliant | Begin continues to use accepted targeting and rule surfaces. Ordinary Preview and declaration Skip do not synthesize timing-window state. | Unchanged | Maintain and verify applicable TEST-003 boundaries. | No separate migration |
| Deterministic identity and atomic multi-owner transition | Partially compliant | Attack identity remains sequence-derived; ship progress rollback is explicit. Squadron Begin and declaration Skip remain incomplete multi-owner transactions. | Partially resolved | Complete deterministic atomic transitions for remaining contexts. | Yes |
| Serialization and compatibility | Partially compliant | Ship progress is now serialized and Preview remains absent. Squadron action history, post-Skip context, and explicit post-cutover rollback evidence remain incomplete. | Partially resolved | Complete canonical representations and compatibility evidence for remaining semantic cutovers. | Yes |
| Save/load and reconstruction | Partially compliant | Active attacks and inactive ship continuations reconstruct; saves before Begin contain no Preview. Squadron declaration progress and context-specific post-Skip reconstruction are not established. | Partially resolved | Cover all supported contexts and post-Skip state. | Yes |
| Replay semantics and equivalence | Partially compliant | Preview replacement is absent from history and Confirm yields one Begin. Declaration Skip still replays a context-free no-op, and squadron adjacent progress is incomplete. | Partially resolved | Establish complete Begin/Skip end-state equivalence. | Yes |
| Network authority and host/client equivalence | Partially compliant | Targeted rejection, accepted Begin mirroring, replacement equivalence, and ship progress parity are covered. Remaining Skip and squadron-owner gaps persist. | Partially resolved | Mirror complete remaining Begin/Skip transactions and routes. | Yes |
| Reconnect from filtered canonical state | Partially compliant | Active and inactive ship continuation reconstruction is covered through direct filtered-state boundaries. No production `StateFilter.filter_for_player` call site was found, and squadron/post-Skip reconstruction remains incomplete. | Partially resolved | Prove the production reconnect path and remaining context reconstruction. | Yes |
| Migration cutover and rollback compatibility | Not implemented | The Preview/Confirm/replacement semantic cutover is explicit and committed, and its legacy replacement behavior is rejected. Remaining cutovers and post-cutover rollback compatibility evidence are not present. | Partially resolved | Record compatibility and rollback evidence for remaining semantic cutovers. | Yes |
| Required verification matrix | Partially compliant | Coverage now includes transient replacement, Confirm, rejection, ship progress, replay, host/client parity, save/load, and reconnect reconstruction. Full supported-context Skip, squadron ownership, parity, production reconnect, and relevant timing evidence remain absent. | Partially resolved | Complete the CON-006 and applicable TEST-003 matrix. | Yes |

### MA-ATTACK-001 Defect-Finding Delta

| Historical defect finding | Current status | Evidence and disposition |
|---|---|---|
| Rejected network commands can leave the client awaiting authority | Resolved | Targeted rejection acknowledgement and `reject_awaiting()` now release the gate. No TWI implementation work remains beyond regression evidence. |
| Skip call sites can advance without an accepted command result | Partially resolved | Explicit declaration and Step 6 paths now check pending, rejection, and accepted results. `_auto_skip_ship_attack()` still submits `no_targets` and immediately tears down without checking acceptance ([attack_executor.gd:942](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:942)). This remains within the declaration Skip migration boundary. |
| Pre-entry ship `ATTACK` flow can be serialized while `CurrentAttackState` is inactive | Resolved | Pre-Begin selection now preserves the enclosing activation flow; the attack flow is published only after accepted Begin. |
| Network save/load bootstrap report | Unchanged as an open report | It remains an independent session-restoration investigation on an overlapping verification boundary. |
| Attack sequence early termination | Superseded by accepted stabilization | BUG-002 is in `verify`, with user verification recorded for hot-seat and network. Step 6 and second-attack behavior remain post-Begin regression context and must not be reimplemented by TWI-ATTACK-001. |

---

## Current CON-006 Compliance Matrix

| CON-006 responsibility | Classification | Repository evidence |
|---|---|---|
| Supported declaration contexts and four attacker/defender pairings | Partially compliant | Four pairings use canonical Begin in [test_current_attack_shared_protocol.gd:314](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:314). Complete authoritative Rogue, Squadron Phase, and Squadron-command action progress is absent from `SquadronInstance`. |
| `GameState` ownership of canonical `CurrentAttackState` | Fully compliant | Canonical state remains private, clone-protected, serialized, reference-validated, and installed through a validating setter in `GameState`. |
| Transient candidate ownership | Fully compliant | `TargetSelector` owns `_declaration_candidate`; `AttackExecutor` coordinates Confirm, Skip, pending, and accepted-result cleanup without adopting candidate authority. |
| Preview without semantic mutation | Fully compliant | Candidate creation does not mutate `CurrentAttackState`, timing state, or command history. |
| Replacement, deselection, and illegal selection | Fully compliant | Replacement emits no Begin or Skip; illegal selection preserves the prior candidate; reselection clears it. Production interaction tests cover these paths. |
| Preview/Begin semantic parity | Partially compliant | Standard squadron selection and Begin reuse the same `TargetingListBuilder` candidate facts, so BUG-005 is not a Preview/Begin disagreement; both consume the same incorrect squadron range result. Ship Preview still uses scene geometry while Begin revalidates against authoritative model reconstruction. |
| Explicit declaration Confirm | Fully compliant | One declaration Confirm submits one Begin for the current candidate, distinct from later dice confirmation. |
| Pending and rejection handling | Fully compliant | One in-flight declaration command is enforced; rejected Begin/Skip restores the prior interaction; targeted network rejection releases the submission gate. |
| Begin validation | Partially compliant | Begin validates phase, identity, target entry, range, obstruction, rules, pool, and standard ship progress, but its shared targeting result applies the wrong squadron range threshold. It also does not validate complete authoritative squadron action/opportunity history. |
| Begin adjacent-owner atomicity | Partially compliant | Standard ship Begin snapshots and commits `ShipInstance` progress atomically with `CurrentAttackState`. Equivalent squadron adjacent-owner mutation is absent. |
| Declaration Skip semantics by context | Non-compliant | No-active voluntary/no-target Skip does not validate or commit the context-specific ship, Squadron Phase, Rogue, or Squadron-command effects required by CON-006 section 11. |
| Authoritative enclosing progress | Partially compliant | Ship attack-step, hull-zone, count, and Step 6 history are serialized on `ShipInstance`. Squadron move/attack entitlement remains modal-local. |
| `InteractionFlow` and projection | Partially compliant | Preview preserves enclosing flow and accepted Begin publishes derived attack flow. Declaration Skip still depends on scene teardown rather than resulting authoritative context. |
| Command applicability versus flow policy | Non-compliant | `begin_attack` and `skip_attack` remain phase-scoped in [command_applicability.gd:87](/Users/Katharina/godot/Armada/src/core/commands/command_applicability.gd:87), while `FlowSpec` assigns them to specific activation and `ATTACK_DECLARE` surfaces ([flow_spec.gd:113](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd:113), [flow_spec.gd:175](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd:175)). Concrete validation does not close this complete context gap. |
| Runtime rule and timing-window ownership | Fully compliant | Target/rule checks remain on accepted resolver and rule surfaces; ordinary declaration behavior does not synthesize or clear timing-window authority. |
| Determinism and atomic failure | Partially compliant | Sequence-derived identity, standard ship rollback, rejection preservation, and successful-command recording exist. Remaining squadron and Skip multi-owner mutations are absent. |
| Serialization and compatibility | Partially compliant | `CurrentAttackState` and ship progress serialize deterministically; Preview does not. Complete squadron and post-Skip representations and post-cutover rollback evidence are missing. |
| Replay | Partially compliant | Confirm produces one Begin and replacement produces no command. Declaration Skip replays without the required enclosing mutation, and supported squadron contexts remain incomplete. |
| Networking | Partially compliant | Authoritative validation, targeted rejection, accepted-command broadcast, mirror execution, and ship-progress equivalence exist. Skip and squadron adjacent-owner equivalence remain incomplete. |
| Save/load | Partially compliant | Active Begin state and inactive ship continuation reconstruct, and Preview remains absent. Complete post-Skip and squadron declaration states are not represented. |
| Reconnect | Partially compliant | Filtered-state reconstruction tests cover active attacks, pre-Begin absence of Preview, and inactive ship continuation. Evidence remains direct-boundary rather than a production reconnect transport path, and remaining contexts are incomplete. |
| Migration cutover and rollback | Partially compliant | The accepted declaration Preview/Confirm semantic cutover is complete. Remaining cutovers and explicit post-cutover rollback compatibility are not evidenced. |
| Required verification evidence | Partially compliant | Strong coverage exists for the stabilized declaration and ship progression. Full supported-context, Skip-effect, parity, production reconnect, compatibility, and applicable timing-window evidence remains missing. |

---

## Open-Bug Disposition Assessment

| Bug | Reported behavior and evidence | Governing authority and overlap | Implementation boundary | Relationship | Recommended disposition | Blocking stage |
|---|---|---|---|---|---|---|
| BUG-001 / NOTE-001 — Network Save/Load Session Bootstrap Investigation | A loaded network game appears to behave or report itself as Hot Seat; host/client logs and replay output may not restart. The issue contains observations and hypotheses but no attack-specific state divergence evidence. | CON-006 serialization, networking, save/load, replay, and reconnect obligations overlap at verification level. Runtime session/bootstrap ownership is outside attack declaration itself. | Network session mode, load bootstrap, logging, replay initialization, and runtime services. | Independent defect on an overlapping boundary | Investigate before final production verification | Does not block assessment or workbook drafting. It can block final production network save/load verification until its effect on session authority is known. |
| BUG-003 — Attack Can Be Skipped After Commitment | Skip remains available after dice are rolled. The annotation shows an active `CurrentAttackState` at `attack_modify` with authoritative dice results. | CON-006 explicitly excludes active attack cancellation and post-Begin behavior. CON-001 and attack-resolution rules govern the active lifecycle. | Post-Begin action projection and active Skip authorization. | Independent defect on an overlapping boundary | Exclude and defer | Does not block TWI drafting, acceptance, or CON-006 implementation. Keep separate post-Begin verification. |
| BUG-004 — Command Token Not Refreshed After Grand Moff Tarkin Selection | Authoritative command-token state is correct, but the ship-card UI refreshes only after another interaction. | Tarkin projection and applicable timing-window capability authority; no attack-declaration obligation is implicated. | Tarkin projection and ship-card refresh. | Clearly unrelated | Exclude and defer | No TWI stage is blocked. |
| BUG-005 — Squadron Attack Allowed Beyond Range 1 | The completed forensic investigation establishes that squadron distance is measured correctly edge-to-edge, after which the outgoing-target query applies the complete close-range band instead of the distinct distance-1 threshold. | CON-006 resolver ownership, target legality, Preview semantics, out-of-range rejection, and Begin validation apply directly. Preview and Begin consume the same targeting result. | `TargetingListBuilder` squadron-to-squadron and squadron-to-ship outgoing target eligibility. | Established CON-006 non-compliance | Include in TWI-ATTACK-001 | No longer blocks workbook drafting or acceptance as an unresolved investigation; it becomes mandatory workbook scope. |

### BUG-005 Specific Finding

The completed [BUG-005 forensic analysis](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-005/forensic-analysis-report.md) establishes that distance 1 and close range are distinct production thresholds: distance 1 ends at 181 px while close range ends at 292 px.

Squadron-to-squadron distance is measured correctly from base edge to base edge. `TargetingListBuilder` then classifies that result with the close/medium/long range surface and accepts the complete close-range band. The same range/distance conflation is present in squadron-to-ship outgoing target eligibility:

- [targeting_list_builder.gd:938](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:938)
- [targeting_list_builder.gd:997](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:997)
- [scale_config.json:18](/Users/Katharina/godot/Armada/Resources/Game_Components/scale/scale_config.json:18)

Standard squadron Preview resolves its candidate through this builder, and `BeginAttackCommand` independently re-derives the authoritative entry through the same surface. Both therefore consume the same incorrect result. BUG-005 is established CON-006 non-compliance, but it is not a Preview/Begin disagreement, a presentation defect, or an unresolved rules interpretation.

### Network Save/Load Bootstrap Finding

BUG-001 overlaps the durability and network-verification surface but does not currently establish an attack declaration defect.

The load path broadcasts serialized `GameState` and installs it on both peers:

- [lobby_manager.gd:167](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:167)
- [lobby_manager.gd:484](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:484)

The report instead identifies possible failure to restore network mode, role, logging, replay recording, or runtime services.

It should not be absorbed into TWI-ATTACK-001 without evidence that canonical attack state or command authority differs after load. Its investigation is required to establish whether production network save/load can serve as valid CON-006 acceptance evidence.

---

## Remaining Migration Scope For TWI-ATTACK-001

### Mandatory CON-006 Compliance Work

TWI-ATTACK-001 should cover these remaining outcomes:

- Every supported ship, Squadron Phase, Rogue, and ship-phase Squadron-command declaration context has an authoritative enclosing opportunity and controller.
- `BeginAttackCommand` validates and atomically commits all applicable existing adjacent owners.
- Squadron move/attack entitlement, attack use, and remaining-action state are authoritative and serializable on the accepted existing owners.
- No-active `SkipAttackCommand` implements the complete context-specific CON-006 Skip effect matrix.
- Accepted Skip cannot be replaced by scene teardown, modal completion, or a context-free command result.
- Automatic no-target declaration handling depends on an accepted authoritative Skip result.
- Command applicability, applicable `FlowSpec` policy, and concrete Begin/Skip validation agree.
- Preview and Begin produce equivalent gameplay legality for all supported pairings and contexts.
- BUG-005 squadron-to-squadron and squadron-to-ship declaration eligibility enforces distance 1 rather than the complete close-range band; Preview and Begin reject targets beyond distance 1 using the same accepted resolver semantics; production scale thresholds and verification evidence preserve the distinction between distance 1 and close range.
- Post-Begin or post-Skip routing derives from the accepted authoritative result.
- Serialization, compatibility, replay, networking, save/load, and reconnect preserve complete Begin and Skip end states.
- Migration-cutover and rollback-compatibility evidence exists for remaining semantic cutovers.
- The full CON-006 and applicable TEST-003 verification matrix passes through production-representative paths.

These are outcome boundaries, not implementation tasks or order.

### Final Production-Verification Prerequisite

#### Network Save/Load Session Bootstrap

The investigation must establish whether loading a network save restores:

- network mode;
- host/client roles;
- authoritative command submission;
- mirrored results;
- replay recording;
- relevant session metadata.

This investigation determines whether the defect is only logging/replay bootstrap or whether it invalidates production network save/load evidence.

### Optional Cleanup

The following may be considered only if behavior-inert and not allowed to expand TWI scope:

- correcting obsolete comments that describe `SkipAttackCommand` as universally non-mutating;
- removing stale declaration terminology made obsolete by the accepted replacement cutover;
- consolidating evidence references after accepted verification.

Optional cleanup is not a compliance objective.

### Excluded Defects And Behavior

TWI-ATTACK-001 should exclude:

- active attack completion, cancellation, cleanup, or replacement;
- BUG-003 post-commit Skip behavior;
- anti-squadron Step 6 continuation implementation;
- second normal attack continuation implementation;
- unrelated attack-resolution, dice, defense, critical, or damage behavior;
- BUG-004 Tarkin projection;
- general networking or replay cleanup unrelated to Begin/Skip declaration state;
- the network bootstrap repair unless its investigation proves a direct declaration-authority dependency;
- unrelated UI layout or presentation cleanup.

### Completed Stabilization That Must Not Be Reimplemented

The workbook should preserve as existing baseline:

- one transient declaration candidate owned by `TargetSelector`;
- Preview without command submission;
- replacement, deselection, and illegal-selection preservation;
- explicit declaration Confirm;
- one Begin for the confirmed final candidate;
- removal of `Begin → Skip(flow_replaced) → Begin`;
- pending declaration gating;
- local and network rejection recovery;
- canonical `CurrentAttackState` ownership;
- authoritative ship attack-step initialization;
- ship hull-zone, attack-count, and anti-squadron history ownership;
- standard ship Begin atomic progress commit and rollback;
- BUG-002 Step 6 and second-attack continuation;
- ship-progress serialization;
- active and inactive ship continuation reconstruction;
- existing replay and host/client stabilization evidence.

---

## Verification Assessment

Committed automated evidence now covers:

- transient Preview;
- replacement A → B → C;
- illegal-selection preservation;
- deselection;
- explicit Confirm;
- rejected Begin;
- rejected declaration Skip;
- network pending and rejection behavior;
- all four attacker/defender pairings;
- tampered authoritative-entry rejection;
- one accepted Begin for the confirmed candidate;
- absence of replay-visible replacement Skip;
- standard ship progress validation and rollback;
- Step 6 and second-attack neighboring behavior;
- host/client and replay equivalence;
- active attack save/load;
- inactive Step 6 and second-attack save/load;
- filtered-state reconnect reconstruction.

Material verification gaps remain for:

- the complete supported-context matrix;
- authoritative Squadron Phase, Rogue, and Squadron-command action progress;
- each declaration Skip effect-matrix row;
- automatic no-target Skip rejection behavior;
- full ship Preview/Begin parity;
- post-Skip serialization and reconstruction;
- production reconnect transport/filter behavior;
- production network save/load after session bootstrap;
- compatibility and rollback at remaining cutovers;
- production-threshold evidence for squadron-to-squadron and squadron-to-ship targets immediately inside and outside distance 1 through both Preview and Begin, with distance 1 and close range kept distinct;
- applicable TEST-003 timing-window interactions at declaration boundaries.

---

## Migration Risks

- **Squadron ownership risk:** squadron move/attack state remains modal-local and crosses both Squadron Phase and ship-phase Squadron-command contexts.
- **Skip coupling risk:** one command type covers no-active declaration Skip and neighboring active/sub-step behavior; only the no-active context-specific branch belongs in CON-006.
- **Flow-policy risk:** phase-scoped applicability currently permits Begin and Skip more broadly than the flow policies and complete opportunity state.
- **Parity risk:** ship Preview and authoritative Begin use different geometry reconstruction paths.
- **Serialization risk:** complete ship progress exists, but squadron and post-Skip enclosing state remain incomplete.
- **Network verification risk:** filtered-state reconnect evidence is direct-boundary, and the open network-load bootstrap report may prevent representative production verification.
- **Squadron range-semantics risk:** `TargetingListBuilder` applies the complete close-range band to squadron outgoing target eligibility, so Preview and Begin share the same incorrect result; the existing targeting-list test fixture collapses the distinct production thresholds and does not expose the affected interval.
- **Regression risk:** completed Preview/Confirm and BUG-002 behavior spans shared selector, executor, command, replay, network, load, and projection paths and must remain unchanged during the remaining migration.
- **Scope risk:** post-Begin BUG-002 and BUG-003 behavior occurs in the same executor but is outside the CON-006 lifecycle.

These risks do not establish an architectural ambiguity.

---

## Workbook Readiness

Verdict: **Ready to draft TWI-ATTACK-001.**

The accepted architecture is sufficient. No new ADR, Contract, TEST document, or Owner Decision is required.

The completed BUG-005 forensic investigation establishes a direct CON-006 declaration-legality defect and places it in mandatory TWI-ATTACK-001 scope. It no longer blocks workbook drafting or acceptance as an unresolved investigation.

The network save/load bootstrap investigation does not block workbook drafting. It must be resolved sufficiently to establish whether production network save/load can provide valid final verification evidence.

No unresolved investigation blocks TWI-ATTACK-001 drafting.

---

## Recommendation

MA-ATTACK-002 is ready for Owner review as the current post-stabilization repository evidence base.

TWI-ATTACK-001 is ready to draft with BUG-005 included as mandatory declaration-compliance scope. The network save/load bootstrap investigation remains a final production-verification prerequisite unless it proves a direct declaration-state defect.

No unresolved architectural ambiguity was identified.

No repository files were modified and no tests were executed during this assessment.

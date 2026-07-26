# MA-ATTACK-001: CON-006 Attack Declaration Compliance Assessment

Status: Accepted
Purpose: Migration Assessment
Consumer: Attack Declaration Flow

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

---

## Purpose

This migration assessment records the compliance of the current attack
declaration implementation with accepted CON-006.

It establishes the repository evidence and migration baseline needed to prepare
TWI-ATTACK-001. It is implementation evidence only. It does not redefine the
accepted architecture, reopen accepted Owner Decisions, prescribe detailed
implementation, define implementation order, or serve as an implementation
workbook.

The assessed baseline is the dirty worktree inspected on 2026-07-26. It is not
repository HEAD and is not claimed to be a stable implementation baseline.

---

## Documents And Evidence Reviewed

### Startup And Authority Guidance

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

### Accepted Architecture And Verification

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

[DR-001](/Users/Katharina/godot/Armada/docs/architecture/decision_workbooks/DR-001-CON-006-owner-decisions.md)
was reviewed as supporting decision evidence. It is not substituted for the
accepted architecture listed above.

### Migration-Assessment Conventions

- [MA-TARKIN-001](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-TARKIN-001-con-005-compliance.md)
- [MA-ECM-001](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-ECM-001-con-005-compliance.md)
- [MA-H9-001](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-H9-001-con-005-compliance.md)
- [MA-TW-001](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-TW-001-cross-consumer-synthesis.md)

### Repository Evidence

The review covered the complete current-worktree attack declaration path:

- canonical game state and current-attack state;
- begin and declaration-skip commands, plus neighboring active-attack
  completion context;
- rule and command applicability validation;
- ship and squadron target selection;
- preview and declaration-entry behavior;
- enclosing activation and squadron-action progress;
- command recording and replay;
- serialization, save, load, and reconstruction;
- network command submission and mirroring;
- reconnect filtering and UI projection;
- integration and unit coverage relevant to CON-006.

The material implementation evidence is cited in the assessment below.

---

## Current Worktree Baseline

The assessment describes the current dirty worktree, not repository HEAD.
At the start of the assessment, `git diff --stat` reported 68 tracked files
changed, with 5,523 insertions and 1,044 deletions. `git status --short` also
reported substantial untracked attack implementation and verification files,
including the new begin and complete commands, `CurrentAttackState`, attack
continuations, and multiple tests.

The worktree is therefore an in-progress mixed state containing both established
implementation and unfinished attack migration work. The repository evidence is
useful for compliance assessment, but the worktree is not a stable
implementation baseline.

### Current Implementation Structure

CON-006 scope in this assessment ends at an accepted
`BeginAttackCommand` or an accepted no-active declaration
`SkipAttackCommand`. References below to active Skip, active-attack
replacement or cancellation, `CompleteAttackCommand`, and other post-Begin
behavior are retained only as neighboring implementation context. They do not
contribute to CON-006 compliance classifications or required migration
outcomes.

#### Authoritative State Ownership And Lifecycle

`GameState` owns a private `CurrentAttackState`, returns it by clone, serializes
it, deserializes it, and installs it only through a validating setter:

- [game_state.gd:55](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:55)
- [game_state.gd:181](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:181)
- [game_state.gd:205](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:205)
- [game_state.gd:266](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:266)

`CurrentAttackState` is a value-like authoritative record with active attack
identity, attacker and target identity, attack kind, zones, range, obstruction,
dice pools, attack stage, and resolution fields. Its deserializer enforces exact
keys and semantic validation:

- [current_attack_state.gd:1](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:1)
- [current_attack_state.gd:59](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:59)
- [current_attack_state.gd:178](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:178)
- [current_attack_state.gd:259](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:259)
- [current_attack_state.gd:307](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:307)

Within CON-006, `BeginAttackCommand` validates and installs an active
`CurrentAttackState`. As neighboring context outside the CON-006 lifecycle,
`CompleteAttackCommand` validates a resolved active attack and clears it, while
active `SkipAttackCommand` clears the active attack and associated timing/ECM
state:

- [begin_attack_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:14)
- [begin_attack_command.gd:43](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:43)
- [complete_attack_command.gd:16](/Users/Katharina/godot/Armada/src/core/commands/complete_attack_command.gd:16)
- [skip_attack_command.gd:68](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:68)

Declaration-entry and enclosing activation progress are not owned entirely by
that canonical state. `AttackExecutor`, `TargetSelector`, `ActivationContext`,
`ShipActivationState`, and `SquadronActivationModal` retain procedural and
modal-local progress:

- [attack_executor.gd:120](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:120)
- [target_selector.gd:145](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:145)
- [activation_context.gd:1](/Users/Katharina/godot/Armada/src/core/state/activation_context.gd:1)
- [ship_activation_state.gd:1](/Users/Katharina/godot/Armada/src/core/state/ship_activation_state.gd:1)
- [squadron_activation_modal.gd:98](/Users/Katharina/godot/Armada/src/ui/combat/squadron_activation_modal.gd:98)

The resulting ownership model is split between command-owned canonical
`CurrentAttackState` and scene/modal-owned declaration and enclosing progress.

#### Preview, Begin, Declaration Skip, And Neighboring Active-Attack Context

Ship and squadron target selection writes transient target data into a shared
scene `AttackState`. Standard squadron targeting additionally retains one
transient candidate entry in `TargetSelector`:

- [target_selector.gd:130](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:130)
- [target_selector.gd:667](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:667)
- [target_selector.gd:847](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:847)

Preview is produced by scene target resolution. The standard squadron path
overrides range and obstruction from the canonical candidate entry. A legal
target in execution mode emits `target_locked` immediately after preview, and
`AttackExecutor` submits `BeginAttackCommand` from that signal:

- [target_selector.gd:1138](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1138)
- [target_selector.gd:1179](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1179)
- [attack_executor.gd:265](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:265)
- [attack_executor.gd:793](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:793)
- [attack_executor.gd:1305](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1305)

There is no separate declaration Confirm. The visible attack-panel Confirm
occurs later, after attack dice are finalized, and submits
`ConfirmAttackDiceCommand`:

- [attack_executor.gd:1921](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1921)

After the current path has already accepted Begin, a later target change makes
`AttackExecutor` submit `SkipAttackCommand` with reason `flow_replaced` and then
submit another `BeginAttackCommand`. That active-attack replacement is outside
CON-006 and is retained only as neighboring implementation context:

- [attack_executor.gd:804](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:804)
- [test_squadron_attack_target_recovery.gd:280](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:280)
- [test_current_attack_shared_protocol.gd:348](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:348)

The neighboring replay-visible lifecycle is therefore
`Begin → Skip(flow_replaced) → Begin`. It does not define CON-006 replacement
compliance; the declaration-scope gap is the absence of transient replacement
before explicit Confirm and accepted Begin.

When no attack is active, `SkipAttackCommand` accepts a phase-scoped skip and
returns a result without mutating authoritative state:

- [skip_attack_command.gd:41](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:41)
- [skip_attack_command.gd:68](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:68)

Outside the CON-006 lifecycle, attack completion clears canonical attack state
through `CompleteAttackCommand`, after which scene code updates local fired-zone,
attacked-squadron, and attack-count progress. This evidence is retained only as
neighboring implementation context:

- [attack_executor.gd:3780](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3780)
- [attack_executor.gd:3846](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3846)
- [attack_executor.gd:3873](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3873)

#### Commands And Validation

`BeginAttackCommand` validates the phase, stable attacker and target identity,
attack pairing, authoritative candidate entry, submitted range and obstruction,
rule blockers, and non-empty attack pool. Candidate facts are reconstructed
from `GameState` through `TargetingListBuilder`, and rule modifiers are obtained
through `RuleRegistry`:

- [begin_attack_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:14)
- [begin_attack_command.gd:81](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:81)
- [begin_attack_command.gd:125](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:125)
- [begin_attack_command.gd:186](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:186)
- [targeting_list_builder.gd:157](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:157)
- [targeting_list_builder.gd:202](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:202)

The command does not validate or mutate the complete enclosing declaration
opportunity required by CON-006, including controller-step progression,
hull-zone use, squadron action history, and already-targeted progress. Those
facts remain absent from the command transaction or scene-owned:

- [ship_instance.gd:430](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:430)
- [squadron_instance.gd:207](/Users/Katharina/godot/Armada/src/core/state/squadron_instance.gd:207)
- [squadron_activation_modal.gd:270](/Users/Katharina/godot/Armada/src/ui/combat/squadron_activation_modal.gd:270)

`CommandApplicability` declares Begin and Skip as phase-scoped commands in Ship
and Squadron phases rather than enforcing the `ATTACK_DECLARE` step recorded by
`FlowSpec`:

- [command_applicability.gd:87](/Users/Katharina/godot/Armada/src/core/commands/command_applicability.gd:87)
- [flow_spec.gd:174](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd:174)

#### Replay, Persistence, Save, And Load

`CommandProcessor` assigns command sequence numbers, performs preflight and
command validation, executes accepted commands, and records non-empty successful
results. `GameReplay` uses a strict format and validates contiguous sequence
numbers:

- [command_processor.gd:225](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:225)
- [command_processor.gd:450](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:450)
- [game_replay.gd:31](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:31)
- [game_replay.gd:114](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:114)
- [game_replay.gd:153](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:153)

`GameState` serializes `InteractionFlow`, timing-window state, and
`CurrentAttackState`. Its deserializer rejects an `ATTACK` interaction flow when
`CurrentAttackState` is inactive:

- [game_state.gd:181](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:181)
- [game_state.gd:228](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:228)
- [game_state.gd:236](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:236)

The ship declaration path publishes `ATTACK` flow before Begin, while the
squadron path explicitly avoids publishing it because canonical attack state is
not active:

- [attack_executor.gd:871](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:871)
- [attack_executor.gd:927](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:927)

`SaveGameManager` serializes state and command cursor, validates active attack
and timing cursor relationships, and deserializes state during load. Its normal
safe-point gate does not include mid-activation or attack steps:

- [save_game_manager.gd:63](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:63)
- [save_game_manager.gd:130](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:130)
- [save_game_manager.gd:270](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:270)
- [save_game_manager.gd:318](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:318)
- [save_game_manager.gd:546](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:546)

Active-attack save/load and replay equivalence have substantial integration
coverage:

- [test_current_attack_shared_protocol.gd:296](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:296)
- [test_current_attack_production_resume.gd:434](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:434)
- [test_game_replay.gd:93](/Users/Katharina/godot/Armada/tests/unit/test_game_replay.gd:93)

The persistence record does not include all enclosing activation and declaration
progress required at the accepted-Begin end boundary or after declaration Skip.

#### Networking, Reconnect, And UI Projection

`NetworkCommandSubmitter` gates a client while it awaits the authoritative
result. The server validates and broadcasts accepted commands. The client
applies the mirrored command through the command processor:

- [network_command_submitter.gd:1](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:1)
- [network_command_submitter.gd:41](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:41)
- [network_manager.gd:580](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:580)
- [game_manager.gd:2285](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2285)

`StateFilter` retains canonical attack state while filtering serialized state.
`UIProjector` derives controller/modal intent from `InteractionFlow` and timing
state. Active-attack `AttackExecutor` reconstruction derives a resume plan and
reprojects interaction flow from `CurrentAttackState`:

- [state_filter.gd:20](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:20)
- [ui_projector.gd:122](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:122)
- [attack_executor.gd:297](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:297)
- [modal_router.gd:209](/Users/Katharina/godot/Armada/src/scenes/game_board/modal_router.gd:209)

Repository search found no production call site for
`StateFilter.filter_for_player`; the current reconnect integration test states
that it exercises a function-call boundary rather than a production RPC chain:

- [test_reconnection_mid_attack.gd:1](/Users/Katharina/godot/Armada/tests/integration/test_reconnection_mid_attack.gd:1)
- [test_reconnection_mid_attack.gd:77](/Users/Katharina/godot/Armada/tests/integration/test_reconnection_mid_attack.gd:77)

Reconstruction restores an individual active attack but explicitly does not
restore enclosing prior attack history:

- [attack_executor.gd:160](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:160)
- [attack_executor.gd:349](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:349)

---

## Overall Assessment

The current implementation is **Partially compliant** with CON-006 overall.

It has a substantial authoritative attack core: `GameState` owns canonical
`CurrentAttackState`; Begin is command-mediated; authoritative candidate
reconstruction and rule hooks exist; and accepted-Begin state serialization,
replay, network mirroring, and reconstruction are exercised. Command-mediated
active Skip and completion remain neighboring context outside CON-006.

It is not CON-006 conformant because declaration remains partly procedural and
scene-owned. Selection immediately begins an attack instead of entering a
transient preview followed by explicit declaration Confirm, so no
declaration-scope transient replacement interval exists. The later terminal
Skip and new Begin are neighboring active-attack behavior outside CON-006.
No-active declaration Skip is an authoritative no-op. Required adjacent
authoritative owners and enclosing progress are absent or scene-owned.
Durability and reconstruction cover the accepted-Begin end state more
completely than declaration entry or post-Skip enclosing progress.

No evidence reviewed requires a change to the accepted architecture.

---

## CON-006 Compliance Matrix

| CON-006 responsibility | Classification | Repository evidence |
|---|---|---|
| Supported declaration contexts and all four attacker/target pairings | Partially compliant | Begin accepts Ship or Squadron phases and validates ship/squadron identities and attack kind ([begin_attack_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:14), [begin_attack_command.gd:81](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:81)); integration coverage exercises the four pairings ([test_current_attack_shared_protocol.gd:140](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:140)). The command does not represent the complete enclosing declaration context. |
| `GameState` ownership of canonical `CurrentAttackState` | Fully compliant | Private ownership, clone access, serialization, strict deserialization, reference validation, and validating installation are present ([game_state.gd:55](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:55), [game_state.gd:181](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:181), [game_state.gd:266](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:266), [game_state.gd:282](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:282)). |
| Complete authoritative attack-entry facts and declaration context | Partially compliant | `CurrentAttackState` carries complete individual-attack facts and Begin populates them ([current_attack_state.gd:59](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:59), [begin_attack_command.gd:43](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:43)). Enclosing opportunity, controller-step, hull-zone-use, action-history, and already-targeted facts are not part of the Begin transaction. |
| Adjacent authoritative owners for enclosing declaration and activation progress | Non-compliant | `ActivationContext` and `ShipActivationState` are procedural `RefCounted` scene state ([activation_context.gd:1](/Users/Katharina/godot/Armada/src/core/state/activation_context.gd:1), [ship_activation_state.gd:1](/Users/Katharina/godot/Armada/src/core/state/ship_activation_state.gd:1)); squadron move/attack history is modal-local ([squadron_activation_modal.gd:98](/Users/Katharina/godot/Armada/src/ui/combat/squadron_activation_modal.gd:98), [squadron_activation_modal.gd:270](/Users/Katharina/godot/Armada/src/ui/combat/squadron_activation_modal.gd:270)); serialized ship/squadron instances do not carry the required progress ([ship_instance.gd:430](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:430), [squadron_instance.gd:207](/Users/Katharina/godot/Armada/src/core/state/squadron_instance.gd:207)). |
| `TargetSelector` as sole owner of transient declaration selection | Partially compliant | `TargetSelector` owns one explicitly transient squadron candidate ([target_selector.gd:130](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:130)), but it also receives and mutates a shared `AttackState` owned by `AttackExecutor` ([target_selector.gd:145](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:145), [target_selector.gd:667](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:667), [target_selector.gd:847](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:847)). |
| First legal selection produces preview without authoritative command | Partially compliant | Preview is calculated and displayed ([target_selector.gd:1138](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1138), [target_selector.gd:1179](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1179)), but execution mode immediately emits `target_locked`, which submits Begin ([attack_executor.gd:793](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:793), [attack_executor.gd:1305](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1305)). |
| Replace, deselect, and illegal-selection behavior remains transient before Confirm | Partially compliant | Scene code supports deselection and rejection ([target_selector.gd:685](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:685), [target_selector.gd:863](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:863), [target_selector.gd:1073](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1073)). A legal target immediately proceeds to Begin, so the required pre-Confirm transient replacement interval is absent ([target_selector.gd:1179](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1179), [attack_executor.gd:793](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:793)). The later `Skip(flow_replaced)` and new Begin are neighboring active-attack behavior outside CON-006 and do not determine this classification ([attack_executor.gd:804](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:804)). |
| Preview and Begin use the same authoritative candidate facts and legality | Partially compliant | Begin reconstructs authoritative candidates through `TargetingListBuilder` ([begin_attack_command.gd:186](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:186), [targeting_list_builder.gd:157](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:157)). Standard squadron preview reuses canonical range/obstruction, while ship preview remains scene-resolved ([target_selector.gd:1138](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1138), [target_selector.gd:1153](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1153)). |
| Explicit declaration Confirm | Not implemented | A legal target automatically starts Begin ([target_selector.gd:1179](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1179), [attack_executor.gd:793](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:793)). The implemented Confirm is a later dice-stage command, not declaration Confirm ([attack_executor.gd:1921](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1921)). |
| Pending-command gate and rejection recovery | Partially compliant | Remote Begin uses pending fields and the network submitter queues while awaiting authority ([attack_executor.gd:120](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:120), [network_command_submitter.gd:41](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:41)). The gate clears on an accepted result ([network_command_submitter.gd:69](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:69)); the server does not return a rejection result on invalid commands ([network_manager.gd:590](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:590)). |
| Begin validation and atomic authoritative mutation | Partially compliant | Begin validates identity, pairing, candidates, submitted facts, rules, and pool before one `CurrentAttackState` installation ([begin_attack_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:14), [begin_attack_command.gd:43](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:43), [begin_attack_command.gd:125](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:125)). Required adjacent-owner mutations are absent from the transaction. |
| Declaration Skip when no attack is active | Non-compliant | No-active Skip accepts by phase and returns a command result without validating an enclosing opportunity or mutating authoritative progress ([skip_attack_command.gd:41](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:41), [skip_attack_command.gd:68](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:68)). |
| `InteractionFlow` and UI state derived from authoritative declaration state | Partially compliant | Active reconstruction projects flow from `CurrentAttackState` ([attack_executor.gd:297](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:297)), and `UIProjector` is flow-derived ([ui_projector.gd:122](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:122)). Pre-Begin ship flow is published while attack state is inactive, whereas squadron flow is kept local to avoid that mismatch ([attack_executor.gd:871](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:871), [attack_executor.gd:927](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:927)). |
| Runtime rule and timing-window ownership remains on accepted shared surfaces | Fully compliant | Begin obtains authoritative candidate facts and rule modifiers through shared targeting/rule surfaces ([begin_attack_command.gd:125](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:125), [targeting_list_builder.gd:157](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:157)). In declaration scope, the no-active Skip branch returns without authoritative mutation and does not synthesize timing-window state or cleanup ([skip_attack_command.gd:41](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:41), [skip_attack_command.gd:68](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:68)). No active-Skip or post-Begin behavior is used as evidence for this classification. |
| Deterministic identity and atomic multi-owner transition | Partially compliant | Attack identity is derived from the command sequence, and command execution records only successful non-empty results ([begin_attack_command.gd:43](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:43), [command_processor.gd:450](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:450)). The transaction does not include the adjacent authoritative owners required by CON-006, and the processor has no generalized multi-owner snapshot rollback for this path. |
| Serialization and compatibility of declaration state | Partially compliant | `CurrentAttackState` has strict exact-key serialization/deserialization ([current_attack_state.gd:203](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:203), [current_attack_state.gd:259](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd:259)). Enclosing declaration progress is missing, and `GameState.deserialize` rejects the pre-entry `ATTACK`-flow/inactive-attack combination the ship path can publish ([game_state.gd:236](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:236), [attack_executor.gd:871](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:871)). |
| Save, load, and reconstruction | Partially compliant | State and cursor persistence, accepted-Begin state validation, and accepted-Begin state resume tests exist ([save_game_manager.gd:130](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:130), [save_game_manager.gd:270](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:270), [test_current_attack_production_resume.gd:434](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:434)). Normal save points exclude mid-attack states, and post-Skip enclosing progress is not fully authoritative ([save_game_manager.gd:63](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:63), [attack_executor.gd:160](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:160)). |
| Replay semantics and equivalence | Partially compliant | Replay format and sequence validation are strict, with accepted-Begin state equivalence coverage ([game_replay.gd:114](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:114), [test_game_replay.gd:233](/Users/Katharina/godot/Armada/tests/unit/test_game_replay.gd:233), [test_current_attack_shared_protocol.gd:296](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:296)). In declaration scope, no-active Skip records an authoritative no-op rather than the required enclosing transition. The neighboring `Begin → Skip(flow_replaced) → Begin` active-replacement sequence is outside CON-006 and does not determine this classification. |
| Network authority and host/client equivalence | Partially compliant | Server validation, accepted-command broadcast, and mirrored client execution exist ([network_manager.gd:580](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:580), [game_manager.gd:2285](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2285)); equivalence is tested ([test_current_attack_shared_protocol.gd:296](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:296)). Rejection does not return a result to release the client awaiting gate, and declaration-entry/enclosing progress is incomplete. |
| Reconnect reconstruction from filtered canonical state | Partially compliant | Filter/project/reconstruct behavior is covered at a direct function boundary ([state_filter.gd:20](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:20), [test_reconnection_mid_attack.gd:77](/Users/Katharina/godot/Armada/tests/integration/test_reconnection_mid_attack.gd:77), [test_current_attack_production_resume.gd:471](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:471)). No production `StateFilter.filter_for_player` call site was found, and enclosing prior-attack history is not reconstructed ([attack_executor.gd:160](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:160)). |
| Migration cutover and rollback compatibility | Not implemented | No repository artifact or verification was found that identifies CON-006 semantic-slice cutovers or post-cutover rollback compatibility. Current tests still assert replay-visible replacement Skip behavior ([test_squadron_attack_target_recovery.gd:280](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:280)). |
| Required verification matrix | Partially compliant | Tests cover four pairings, active-state protocol, replay, save/load, mirrored networking, and direct-boundary reconnect ([test_current_attack_shared_protocol.gd:140](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:140), [test_current_attack_production_resume.gd:434](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:434), [test_reconnection_mid_attack.gd:77](/Users/Katharina/godot/Armada/tests/integration/test_reconnection_mid_attack.gd:77)). The required explicit-Confirm, transient replacement, authoritative declaration Skip, enclosing-progress, rejection, production reconnect, and timing-window declaration cases are absent or exercise current non-conforming behavior. |

---

## Strengths

- Canonical individual-attack ownership is explicit, value-like, clone-protected,
  serializable, and reference-validated.
- Begin derives target facts and rule modifiers from authoritative shared
  surfaces rather than accepting client/UI calculations as authority.
- Begin uses the command pathway and participates in deterministic command
  sequencing and replay. Active Skip and completion use command pathways as
  neighboring context outside CON-006.
- Accepted-Begin state serialization, load, host/client mirroring, replay, and
  passive reconstruction have substantial verification evidence.
- UI projection and accepted-Begin state resume already use shared
  interaction-flow and projection surfaces rather than introducing a separate
  attack-only network protocol.
- Tests make the neighboring out-of-scope active-replacement sequence and
  protocol behavior observable, providing useful baseline context without
  affecting CON-006 classification.

---

## Known Repository Defects

Implementation defects and architectural compliance gaps are recorded as
separate categories. A repository defect may also serve as evidence for a
CON-006 compliance classification when it directly demonstrates failure to
satisfy a CON-006 obligation; that does not make the defect an architectural
conclusion.

### Rejected Network Commands Can Leave The Client Awaiting Authority

`NetworkCommandSubmitter` clears its awaiting gate only when an authoritative
result is received. The server returns without a rejection response for unknown,
misattributed, invalid, or empty-result commands:

- [network_command_submitter.gd:69](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:69)
- [network_manager.gd:590](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:590)

The observable implementation consequence is that a rejected client command can
leave the submitter awaiting and later submissions queued.

### Some Skip Call Sites Advance Procedural Flow Without Accepting The Result

The automatic ship-skip path submits Skip and immediately finishes the scene
flow without checking acceptance. The anti-squadron loop path likewise advances
when the Skip result is empty or rejected:

- [attack_executor.gd:915](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:915)
- [attack_executor.gd:4111](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:4111)

This is a command-result handling defect. It is distinct from the architectural
gap that no-active declaration Skip lacks the required authoritative enclosing
transition.

### Pre-Entry Ship Flow Can Be Serialized In A Form Rejected By Deserialization

The ship path publishes `ATTACK` interaction flow before an active
`CurrentAttackState` exists. `GameState.deserialize` rejects that combination.
The squadron path explicitly avoids publishing it:

- [attack_executor.gd:871](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:871)
- [attack_executor.gd:927](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:927)
- [game_state.gd:236](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:236)

This is an internal persistence consistency defect. It does not determine the
accepted declaration architecture.

### Open Network Save/Load Bootstrap Defect Evidence

The worktree contains an open repository note reporting that a loaded network
session can appear as Hot Seat and may lack the expected host/client logs and
replay artifact:

- [BUG-001-network-save-load-session-bootstrap.md](/Users/Katharina/godot/Armada/docs/unresolved_bugs/BUG-001-network-save-load-session-bootstrap.md)

The note is implementation evidence, not accepted architectural authority.

The worktree is also known to carry an unresolved attack-sequence defect from
the preceding implementation work. This assessment does not attempt to repair
or generalize from that runtime defect. Source-visible sequence and
command-result defects are recorded above; runtime failure does not influence
the accepted architectural conclusions.

---

## Non-Compliant Obligations

These are architectural compliance gaps against accepted CON-006, not
implementation defect reports:

- declaration lacks an explicit Confirm boundary;
- the first legal selection can submit Begin immediately;
- the required pre-Confirm transient replacement interval is absent; the later
  replay-visible `Begin → Skip(flow_replaced) → Begin` sequence is neighboring
  active-attack behavior outside CON-006;
- no-active declaration Skip is an authoritative no-op;
- the Begin/Skip declaration transaction does not validate and mutate all
  required adjacent authoritative owners;
- enclosing ship and squadron declaration/activation progress remains absent or
  scene/modal-owned;
- transient declaration selection ownership is split between
  `TargetSelector` and shared scene `AttackState`;
- ship preview and Begin do not use one complete canonical fact path;
- command applicability is phase-scoped rather than consistently constrained by
  the `ATTACK_DECLARE` interaction step;
- serialization, save/load, replay, networking, reconnect, and UI reconstruction
  do not yet preserve the complete declaration-entry and post-Skip enclosing
  progress required by CON-006;
- migration cutover and rollback compatibility evidence is absent;
- the full CON-006 and applicable TEST-003 verification matrix is incomplete.

---

## Legacy Patterns

The following current patterns form the migration baseline:

- automatic Begin from `TargetSelector.target_locked`;
- shared mutable scene `AttackState` spanning selector and executor;
- neighboring active-attack replacement through terminal Skip followed by a
  new Begin, outside the CON-006 lifecycle;
- overloaded Skip semantics for both active attack termination and no-active
  declaration flow;
- phase-only applicability for Begin and Skip despite an `ATTACK_DECLARE` flow
  step;
- procedural `ActivationContext` and `ShipActivationState`;
- modal-local squadron moved/attacked flags;
- neighboring post-completion scene mutation of fired zones, attacked
  squadrons, and attack counters outside the CON-006 lifecycle;
- ship pre-entry interaction-flow publication without active attack state;
- reconstruction of the individual active attack without its complete enclosing
  attack history;
- direct-boundary reconnect verification without a production filter/transport
  call chain.

This section records existing implementation patterns. It does not endorse them
as architecture.

---

## Natural Migration Groupings

The repository evidence forms three technically coherent implementation
boundaries. These boundaries are unordered.

### Transient Declaration Interaction

This boundary contains target selection, preview, deselection, illegal-target
handling, replacement before Confirm, transient ownership, pending interaction,
and the explicit declaration Confirm boundary. These behaviors share the same
selector/executor interaction and repeated manual interaction surface.

### Authoritative Declaration Transaction And Enclosing Progress

This boundary contains Begin, declaration Skip, command applicability,
authoritative opportunity validation, adjacent authoritative owners, enclosing
ship/squadron progress, and terminal handoff after accepted Begin or declaration
Skip. These behaviors form one authoritative gameplay transaction boundary and
cannot be assessed independently without repeating lifecycle verification.

### Durability, Distribution, And Reconstruction

This boundary contains serialization compatibility, save/load, replay, network
authority and rejection handling, reconnect filtering, UI projection, and
accepted-Begin end-state/post-Skip reconstruction. These consumers all depend
on the same authoritative declaration and enclosing-progress representation.

Splitting behavior within any of these boundaries would separate tightly
coupled lifecycle facts and multiply equivalent manual verification. Combining
the three boundaries into one would obscure the distinct transient,
authoritative-transaction, and durability responsibilities.

---

## Required Migration Work

The remaining work is expressed here only as required compliance outcomes, not
as implementation tasks or order.

### Transient Declaration Interaction Outcomes

- A legal first selection, replacement, deselection, and rejection remain
  transient until explicit declaration Confirm.
- One transient owner supplies preview facts consistent with authoritative Begin
  validation.
- Pending and rejected declaration commands preserve a recoverable interaction
  projection.

### Authoritative Declaration Transaction And Enclosing-Progress Outcomes

- Confirm submits one authoritative Begin for the accepted declaration.
- Declaration Skip produces the authoritative enclosing transition required by
  CON-006 when no attack is active.
- Begin and Skip validate and mutate the required attack and adjacent-owner facts
  as one deterministic transition.
- Enclosing ship and squadron declaration progress is authoritative and is
  present at the accepted-Begin or declaration-Skip CON-006 end boundary.

### Durability, Distribution, And Reconstruction Outcomes

- Declaration-entry, accepted-Begin end-state, and post-Skip state have
  consistent serialization and compatibility behavior.
- Replay and host/client command streams represent the accepted declaration
  lifecycle without transient replacement commands.
- Save/load and reconnect reconstruct the same canonical declaration and
  enclosing progress into derived UI.
- Applicable CON-006 and TEST-003 verification covers the required local,
  replay, network, reconnect, and timing-window cases.

---

## Migration Difficulty

Migration difficulty is **significant**.

The individual canonical attack record and command infrastructure are already
substantial, which reduces uncertainty around the accepted-Begin end state.
Difficulty comes from the breadth of the declaration boundary:
selector/executor coupling, missing adjacent authoritative ownership,
scene-local activation progress, command applicability, strict serialization,
replay-visible current behavior, network waiting semantics, reconnect
reconstruction, and verification that currently encodes part of the legacy
sequence.

The large dirty worktree increases baseline and regression uncertainty. It does
not create an architectural ambiguity.

---

## Implementation Risks

- **Baseline risk:** the assessment spans substantial tracked and untracked
  changes rather than a stable revision.
- **Sequence risk:** an unresolved neighboring attack-sequence defect is present
  in the worktree, and several scene call sites can advance after an unaccepted
  Skip. Active-attack sequence behavior remains outside CON-006.
- **Ownership risk:** current declaration and enclosing progress crosses
  `GameState`, commands, `AttackExecutor`, `TargetSelector`, activation objects,
  and modal-local fields.
- **Lifecycle coupling risk:** target preview and automatic Begin cross the
  CON-006 end boundary into neighboring active replacement, active Skip,
  completion, and post-completion scene mutation through signals and procedural
  callbacks. Those later behaviors are context only.
- **Serialization risk:** strict current-attack deserialization coexists with a
  pre-entry flow state that it rejects; adjacent progress is not serialized.
- **Replay risk:** current integration assertions preserve the neighboring,
  out-of-scope `Begin → Skip(flow_replaced) → Begin` sequence as part of the
  observed protocol baseline.
- **Networking risk:** rejected commands can leave the client awaiting, while
  only accepted commands are mirrored.
- **Reconnect risk:** tests cover a direct filter/project boundary, but no
  production state-filter call chain was found.
- **Projection risk:** active resume reprojects flow from canonical attack state,
  while pre-entry ship and squadron paths use different flow publication
  behavior.
- **Rule/geometry coupling risk:** authoritative target reconstruction depends on
  `TargetingListBuilder`; ship geometry reconstruction includes asset texture
  sizing ([targeting_list_builder.gd:238](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd:238)).
- **Verification risk:** substantial tests exist, but some assert the
  neighboring out-of-scope active-replacement sequence while the complete
  declaration matrix is not present.
- **Legacy-code risk:** authoritative command state and procedural scene state
  coexist in the same lifecycle, increasing the chance that one path retains
  legacy progress after another path migrates.

These are implementation and migration risks. None is evidence for changing the
accepted architecture.

---

## Risk If Left Unchanged

- Declaration remains without transient target replacement; neighboring replay
  and network history continue to expose later target changes as terminal
  active-attack transitions outside CON-006.
- Declaration Skip can be recorded without advancing authoritative enclosing
  progress.
- Save/load and reconnect can restore the accepted-Begin current attack without
  enough authoritative context to reconstruct the complete enclosing sequence.
- Scene/modal-local progress can diverge from command-owned canonical attack
  state across declaration rejection, load, or reconnect, and across
  neighboring out-of-scope active Skip and completion.
- A serialized pre-entry ship declaration can fail the current `GameState`
  deserialization invariant.
- Rejected network commands can leave clients unable to submit subsequent
  commands through the existing awaiting gate.
- UI projection remains dependent on path-specific procedural reconstruction
  rather than complete authoritative declaration and enclosing state.

---

## Verification Assessment

Current verification is substantial for the accepted-Begin state and related
durability. It also includes neighboring active-attack evidence; active
completion and active Skip below are outside CON-006 and do not determine its
classifications:

- all four attacker/target pairings;
- begin validation and canonical-state installation;
- neighboring active attack completion and active Skip;
- command sequence and replay equivalence;
- accepted-Begin state save/load;
- host/client mirror equivalence;
- passive accepted-Begin state reconstruction;
- filtered-state reconnect projection at a direct function boundary;
- replay format and contiguous sequence validation.

Material gaps remain for:

- explicit declaration Confirm;
- first preview without Begin;
- transient replace/deselect/illegal behavior through Confirm;
- one Begin per accepted declaration;
- authoritative no-active declaration Skip and enclosing progression;
- atomic adjacent-owner mutation and rollback;
- post-Skip enclosing progress across save/load, replay, network, and reconnect;
- rejected-command recovery;
- production reconnect transport/filter integration;
- compatibility and rollback behavior at migration cutovers;
- applicable TEST-003 timing-window cases at declaration boundaries.

This assessment did not execute tests. The repository was explicitly known to
contain an unresolved attack-sequence defect, and runtime failures were excluded
from architectural conclusions as required by the assessment scope.

---

## Migration Feasibility

Migration is feasible within the accepted architecture.

The repository already contains the command processor, canonical
`CurrentAttackState`, shared rule and candidate surfaces, strict serialization,
replay sequencing, network mirroring, state filtering, UI projection, and
accepted-Begin state reconstruction needed to support the accepted direction.
The remaining gaps concern implementation ownership and lifecycle conformance,
not missing architectural decisions.

No additional ADR, Contract, TEST-document change, or Owner Decision is
indicated by this assessment.

---

## Recommendation

MA-ATTACK-001 is ready for Owner review as the preserved repository assessment
for future TWI-ATTACK-001 planning.

From an architecture perspective, the evidence is sufficient to prepare an
implementation workbook against accepted CON-006. Implementation should not
begin from the current dirty worktree until the existing implementation state is
stabilized and understood as a reproducible baseline. The evidence does not
establish that every reported runtime defect must be resolved before planning;
it establishes that the baseline and its known defects must be unambiguous.

No additional architecture work is required based on this assessment.

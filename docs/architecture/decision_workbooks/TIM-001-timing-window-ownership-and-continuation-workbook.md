# Timing Window Ownership And Continuation Workbook

Status: Accepted

Decision topic: Authoritative timing-window ownership and continuation
Supports: Forthcoming ADR extraction and timing-window lifecycle contract
Primary evidence: Tarkin implementation, ECM implementation, H9 CAP, ADR-003,
ADR-004, CON-003, CON-004
Related packages: CAP-UPG-001, CAP-ECM-001, CAP-H9-001

Accepted direction: Option D — Dedicated Narrow Timing-Window State/Orchestrator
Accepted by: Project Owner
Accepted date: 2026-07-11

Date: 2026-07-11

This workbook is not an ADR.

It records the owner decision for timing windows that contain one or more
optional or mandatory rule opportunities and must resolve deterministically
before normal flow continues. It does not implement runtime code, replace
`CommandProcessor`, replace `FlowSpec` or `InteractionFlow`, define a generic
rule engine, or mark any Rule Capability Package integrated.

This workbook records accepted architecture decisions only. It does not
authorize runtime implementation by itself.

## 1. Problem Statement

The current implementation has proven several interactive rule shapes:

- Grand Moff Tarkin opens a start-of-Ship-Phase prompt before normal ship
  selection.
- Electronic Countermeasures opens attack-time and Status Phase opportunities
  whose authoritative mutable state belongs to the ECM runtime upgrade instance.
- H9 Turbolasers requires an Attack Modify timing window where optional attack
  modifiers can be resolved one at a time and recalculated before attack dice
  are confirmed.

These examples expose a recurring architecture question:

Which surface authoritatively owns timing-window identity, opening, closing,
opportunity discovery, one-at-a-time resolution, recalculation, ordering,
continuation, replay, network, save/load, and reconnect?

The answer must scale to future upgrades, objectives, damage cards, squadron
keywords, and core rules without introducing a speculative generic rule engine
or moving rule truth into UI projection.

## 2. Documents And Surfaces Read

Startup and governance documents read:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/CODEX_WORKFLOW.md`

Architecture and rule documents read:

- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md`
- `docs/architecture/rule_capability_packages/CAP-H9-001-h9-turbolasers.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`
- `docs/architecture/decision_workbooks/UPG-001-recurring-upgrade-rule-architecture-workbook.md`
- `docs/architecture/decision_workbooks/ADR-003-direction-summary.md`
- `docs/game_flow.md`

Developer guidance read:

- `.github/copilot-instructions.md`
- `.github/skills/rule-integration/SKILL.md`
- `.skills/testing_standards.md`

Implementation surfaces inspected:

- `src/core/state/interaction_flow.gd`
- `src/core/state/flow_spec.gd`
- `src/core/commands/command_applicability.gd`
- `src/autoload/game_manager.gd`
- `src/autoload/command_processor.gd`
- `src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd`
- `src/core/commands/tarkin_choice_command.gd`
- `src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd`
- `src/core/commands/use_ecm_command.gd`
- `src/core/commands/decline_ecm_command.gd`
- `src/core/commands/ready_ecm_command.gd`
- `src/core/commands/decline_ecm_ready_command.gd`
- `src/core/commands/status_phase_cleanup_command.gd`
- `src/core/commands/start_round_command.gd`
- `src/core/commands/commit_defense_command.gd`
- `src/core/commands/spend_defense_token_command.gd`
- `src/core/network/ui_projector.gd`
- `src/scenes/game_board/modal_router.gd`

H9 production implementation surfaces were not found. Evidence for H9 comes
from `CAP-H9-001` and existing generic attack-modifier command surfaces.

## 3. Current-State Evidence

### 3.1 Command Authority

`CommandProcessor` validates command applicability, runs rule validators,
executes commands, assigns sequence numbers, records command history, emits
presentation signals, and drains deterministic follow-ups. This is the
repository's replayable mutation path.

`submit_mirror()` applies already-authoritative network command results on
clients while suppressing observer follow-up synthesis. The recent network
ordering work reinforces that clients must mirror authoritative command results
in server sequence order before projecting later flow state.

### 3.2 InteractionFlow And FlowSpec

`InteractionFlow` is serialized active interactive UI state held on
`GameState`. It stores `flow_type`, `step_id`, `controller_player`,
`visible_to`, and JSON-safe `payload`.

`FlowSpec` is static metadata for known flow/step pairs. It declares controller
roles, modal kinds, allowed commands, and transition notes. It does not mutate
state and does not own rule effects.

`UIProjector` reads `GameState.interaction_flow` and static `FlowSpec` metadata
to create a derived UI intent. Projection can expose affordances but is not an
authoritative rule owner.

### 3.3 Tarkin Evidence

Grand Moff Tarkin is command-owned:

- `AdvancePhaseCommand` can enter `SHIP_ACTIVATION /
  TARKIN_COMMAND_CHOICE` when an active Tarkin source is found.
- `CommandApplicability` blocks non-`tarkin_choice` commands while the prompt
  is unresolved.
- `TarkinChoiceCommand` validates phase, flow, controller, source identity, and
  duplicate use.
- `TarkinChoiceCommand.execute()` records the once-per-Ship-Phase guard on the
  runtime upgrade instance, grants tokens, and directly enters
  `WAIT_FOR_SHIP_SELECT`.
- `ModalRouter` renders the projected Tarkin modal and submits the replayable
  command.

This works for the current single Tarkin source but embeds continuation into the
rule command. If another start-of-Ship-Phase rule coexists, direct transition
from `TarkinChoiceCommand` to ship selection would need to become a
recalculation step.

### 3.4 ECM Evidence

Attack-time ECM is command-owned and runtime-upgrade-owned:

- `UseECMCommand` validates ECM availability, exhausts the runtime upgrade, and
  creates pending authorization in runtime upgrade `rule_state`.
- `DeclineECMCommand` records explicit decline state.
- `CommitDefenseCommand` records which locked token was selected under pending
  ECM authorization.
- `SpendDefenseTokenCommand` validates the pending authorization, spends the
  token, and clears authorization.
- Projection decorates `InteractionFlow.payload` from authoritative runtime
  state and attack state.

Status Phase ECM ready cost shows the continuation problem more directly:

- `StatusPhaseCleanupCommand` opens `STATUS_CLEANUP /
  STATUS_CLEANUP_STEP` and projects `ecm_ready_cost_choices` /
  `optional_status_rules`.
- `ReadyECMCommand` and `DeclineECMReadyCommand` resolve one source and write a
  current-window guard to runtime upgrade `rule_state.status_ready_cost`.
- `StartRoundCommand` is the existing replayable continuation from Status to
  Command and clears the status ready-cost window state.
- `GameManager.submit_ready_ecm_runtime()` and
  `submit_decline_ecm_ready_runtime()` currently orchestrate "choice command
  first, then `start_round` only if no unresolved choices remain."

The recent live-modal bug showed that if UI submits the choice directly through
the generic command submitter, the choice command executes but continuation is
not triggered. That is evidence against leaving timing-window continuation only
to arbitrary UI callers.

### 3.5 H9 Evidence

`CAP-H9-001` defines a future Attack Modify timing window:

- `UseH9Command` and `DeclineH9Command` are replayable.
- `UseH9Command` changes authoritative dice immediately.
- Current-attack use/decline guard lives in the H9 runtime upgrade instance
  `rule_state`.
- Multiple optional rules may coexist in `ATTACK_MODIFY`.
- The controlling player chooses the order.
- One optional rule resolves at a time.
- Available optional rules are recalculated after every modifier resolution.
- `confirm_attack_dice` is the only normal exit from `ATTACK_MODIFY`.

No H9 production implementation exists yet, so this workbook treats H9 as a
forward-looking evidence case rather than implemented behavior.

## 4. Confirmed Gaps

- No single authoritative surface currently owns timing-window lifecycle across
  Tarkin, ECM Status Phase, and the future H9 window.
- Tarkin continuation is command-local and assumes no remaining start-of-phase
  opportunities.
- ECM Status Phase continuation is `GameManager`-local and can be bypassed when
  UI uses the generic submitter.
- `InteractionFlow.payload` can carry projected choices, but ADR-003 and the
  ECM defects show that payload must not become authoritative rule state.
- `CommandApplicability` has special prompt-blocking checks for Tarkin and ECM
  Status Phase, which does not scale cleanly to many timing windows.
- No shared contract states how multiple optional opportunities are ordered,
  recalculated, invalidated, or continued when one choice creates or removes
  another opportunity.
- No shared test obligation exists for partial-window save/load, replay,
  reconnect, network mirror ordering, and projection-as-derived-state for
  timing windows.

## 5. Non-Goals

- Do not design a generic upgrade framework.
- Do not design a generic effect-composition engine.
- Do not replace `CommandProcessor`, command history, `FlowSpec`,
  `InteractionFlow`, `UIProjector`, or runtime upgrade ownership.
- Do not make `InteractionFlow`, `FlowSpec`, `RuleSurface`, UI, modal routers,
  or projection authoritative.
- Do not serialize static upgrade/card metadata into runtime state.
- Do not implement H9, additional ECM behavior, or any production code.
- Do not mark any ADR, Contract, or Rule Capability Package accepted.

## 6. Evaluation Criteria

Options are evaluated for:

- architectural clarity,
- deterministic sequencing,
- support for multiple rules,
- support for multiple players,
- support for nested or adjacent windows,
- effect recalculation,
- continuation ownership,
- replay determinism,
- network ordering,
- save/load/reconnect fidelity,
- UI independence,
- testability,
- implementation complexity,
- migration cost,
- overengineering risk,
- scalability to 100+ upgrades and future interactive rules.

## 7. Decision Options

### Option A: GameManager-Owned Timing Windows

`GameManager` owns timing-window lifecycle and continuation. Rule commands
resolve individual choices; after each successful command, `GameManager`
discovers remaining opportunities and submits the continuation command when the
window is complete.

#### Tarkin Walkthrough

- Ship Phase begins.
- `GameManager` discovers Tarkin and another start-of-Ship-Phase rule.
- It projects one opportunity.
- `TarkinChoiceCommand` resolves and writes runtime upgrade guard state.
- `GameManager` recalculates remaining start-of-Ship-Phase opportunities.
- If another rule remains, it projects that rule. If none remain, it enters ship
  selection.

This fixes the current single-source assumption but puts rule-window sequencing
inside a central application service.

#### ECM Walkthrough

- Status cleanup executes.
- `GameManager` discovers all unresolved ECM ready-cost opportunities from
  authoritative runtime upgrade state.
- Ready/decline resolves one choice.
- `GameManager` recalculates.
- It submits `start_round` only after the final choice.

This matches the current ECM repair direction.

#### H9 Walkthrough

- Attack Modify begins.
- `GameManager` discovers H9 and another optional modifier.
- The attacker resolves one modifier.
- `GameManager` recalculates dice/modifier availability.
- It remains in Attack Modify until `confirm_attack_dice`.

This would make `GameManager` responsible for attack-specific modifier
sequencing, which is outside its current phase-orchestration focus.

#### Edge Cases

- Invalidating another rule: `GameManager` must recalculate from authoritative
  state after every command.
- Creating a new opportunity: `GameManager` must know the window's discovery
  hooks.
- Two players controlling opportunities: `GameManager` must switch projected
  controller by opportunity.
- Decline: decline command writes rule state; `GameManager` recalculates.
- Save/load partial window: serialized `GameState` and `InteractionFlow`
  restore current projection, but discovery logic remains outside serialized
  state.

#### Assessment

This is straightforward for phase boundaries but risks making `GameManager` the
owner of every future timing-window protocol. That creates a scaling and
coupling problem for attack-local and rule-specific windows.

### Option B: InteractionFlow/FlowSpec-Owned Timing Windows

`InteractionFlow` and `FlowSpec` own timing-window identity, available
opportunities, controller ownership, transitions, and continuation.

#### Tarkin Walkthrough

- Ship Phase begins and writes `TARKIN_COMMAND_CHOICE` or a broader
  start-of-Ship-Phase flow.
- `InteractionFlow.payload` carries the remaining start-of-phase choices.
- `TarkinChoiceCommand` mutates runtime upgrade state and updates payload.
- `FlowSpec` transition metadata identifies whether to project another choice
  or continue to ship selection.

#### ECM Walkthrough

- Status cleanup writes `STATUS_CLEANUP_STEP` with all ECM choices in payload.
- Ready/decline commands remove one payload entry.
- Payload emptiness allows `start_round`.

#### H9 Walkthrough

- Attack Modify payload carries all optional modifiers.
- Use/decline commands update payload and transition metadata.
- `confirm_attack_dice` exits.

#### Edge Cases

- Invalidating another rule: payload must be recalculated or it becomes stale.
- Creating a new opportunity: commands must mutate payload or FlowSpec must run
  dynamic discovery, which it does not do today.
- Two players controlling opportunities: payload must encode per-opportunity
  controller and interactivity.
- Decline: payload and runtime state both need updates.
- Save/load partial window: payload serializes, but command validation must not
  trust it as the source of legality.

#### Assessment

This option overloads projection/state-description surfaces. It conflicts with
the established rule that `InteractionFlow.payload` is JSON-safe projected
state and that `UIProjector`/RuleSurface are derived. It would also make static
`FlowSpec` responsible for dynamic discovery and effect recalculation.

### Option C: Command-Owned Continuation Protocol

Each rule command owns its local continuation. After a choice command executes,
it decides whether to project the next choice or continue normal flow.

#### Tarkin Walkthrough

- `TarkinChoiceCommand` resolves Tarkin.
- It discovers remaining start-of-Ship-Phase rules.
- If another opportunity remains, it writes that flow. Otherwise it enters ship
  selection.

#### ECM Walkthrough

- `ReadyECMCommand` or `DeclineECMReadyCommand` resolves one choice.
- It discovers remaining ECM ready-cost choices.
- It submits or writes continuation to `start_round` when none remain.

#### H9 Walkthrough

- `UseH9Command` or `DeclineH9Command` resolves one modifier.
- It recalculates attack modifiers.
- It either projects the next modifier or leaves `confirm_attack_dice` as the
  only exit.

#### Edge Cases

- Invalidating another rule: every command must know the whole window's
  discovery model.
- Creating a new opportunity: every command must know how to re-enter the
  shared window.
- Two players controlling opportunities: every command must encode controller
  selection.
- Decline: each decline command owns its own continuation.
- Save/load partial window: continuation depends on the next command invoked,
  not a common lifecycle owner.

#### Assessment

This preserves command authority but duplicates lifecycle logic across rules.
The ECM modal bug is direct evidence that continuation tied to a particular
submission path is fragile. Command-owned mutation should remain; command-owned
window orchestration should not become the general pattern.

### Option D: Dedicated Narrow Timing-Window State/Orchestrator

A narrow timing-window model owns lifecycle and continuation for declared
interactive windows. It is not a generic rule engine. It does not own rule
effects. It coordinates known timing windows by reading authoritative state,
asking CAP-specific discovery helpers for currently legal opportunities,
projecting one opportunity or a deterministic list, recalculating after each
replayable command, and submitting or enabling the existing replayable
continuation command only when the window is complete.

Authoritative mutable rule state remains where ADR-004 and the relevant CAP put
it, such as runtime upgrade `rule_state`. Commands remain the only mutation and
history surface for choices, declines, effects, and continuations.
`InteractionFlow` remains the serialized projection of the current interactive
surface. `FlowSpec` remains static metadata for legal flow/command pairs.

#### Tarkin Walkthrough

- Ship Phase begins.
- The start-of-Ship-Phase timing window opens.
- Discovery finds Tarkin and another start-of-Ship-Phase rule from
  authoritative state.
- The orchestrator projects one deterministic opportunity, including
  controller and source identity.
- `TarkinChoiceCommand` resolves and writes runtime upgrade guard state.
- The orchestrator recalculates.
- It projects the remaining opportunity or continues to
  `WAIT_FOR_SHIP_SELECT` when the window is complete.

#### ECM Walkthrough

- `StatusPhaseCleanupCommand` completes deterministic cleanup and opens the
  Status Phase optional ready-cost window.
- Discovery finds unresolved ECM ready-cost opportunities from runtime upgrade
  state.
- Ready/decline commands resolve one opportunity and write
  `rule_state.status_ready_cost`.
- The orchestrator recalculates.
- It submits the existing `StartRoundCommand` only after no unresolved
  opportunities remain.
- Remote clients mirror `status_phase_cleanup`, ready/decline, and
  `start_round` in host sequence order. They do not synthesize `start_round`.

#### H9 Walkthrough

- Attack Modify opens.
- Discovery finds H9 and another optional attack modifier from authoritative
  attack state and runtime upgrade state.
- The attacker chooses one available optional modifier.
- `UseH9Command` or `DeclineH9Command` resolves one opportunity and writes H9
  current-attack guard state.
- The orchestrator recalculates dice/modifier availability.
- Another optional modifier can be resolved if available.
- `confirm_attack_dice` remains the only normal exit from `ATTACK_MODIFY`.

#### Edge Cases

- Invalidating another rule: discovery is rerun after every successful
  replayable command.
- Creating a new opportunity: discovery can include newly legal opportunities
  on the next recalculation.
- Two players controlling opportunities: each discovered opportunity carries
  an authoritative controller; projection derives interactivity from it.
- Decline: decline commands are explicit history entries and participate in
  recalculation.
- Save/load partial window: serialized authoritative state plus
  `InteractionFlow` reconstructs the visible pending window; validation
  recalculates legality from authoritative state.

#### Assessment

This option best separates responsibilities. It provides one owner for timing
window lifecycle without taking rule effects away from commands or mutable rule
state away from runtime upgrade instances. It requires a small new architectural
surface, so it should be specified by ADR/Contract before implementation.

### Option E: Documentation/Contract Only

Keep current code patterns and add documentation that every CAP must define
its own timing-window ownership and continuation.

#### Tarkin Walkthrough

Tarkin remains command-local unless its CAP requires change. Additional
start-of-Ship-Phase rules must document how they interact with Tarkin.

#### ECM Walkthrough

ECM remains `GameManager`-orchestrated for Status Phase and command-owned for
attack-time authorization.

#### H9 Walkthrough

H9 CAP defines its own Attack Modify recalculation and continuation rules.

#### Edge Cases

- Invalidating another rule: each CAP must document how it recalculates.
- Creating a new opportunity: each CAP must document whether this is allowed.
- Two players controlling opportunities: each CAP must document controller
  handling.
- Decline: each CAP must document replayable decline commands.
- Save/load partial window: each CAP must document projection and runtime state.

#### Assessment

This is low-cost but insufficient. The project already hit concrete Tarkin,
ECM, network-ordering, and modal-continuation failures from local patterns.
Documentation alone will not give future implementations a reliable owner for
cross-rule ordering and continuation.

## 8. Accepted Direction Decisions

### D-001 — Timing-Window Lifecycle Authority

A dedicated serialized `TimingWindowState` owned by `GameState` will represent
the lifecycle of an active timing window.

`TimingWindowState` owns timing-window lifecycle only.

It does not own:

- rule-specific eligibility;
- use/decline guards;
- costs;
- mutable effects;
- runtime upgrade state.

Those remain on their existing authoritative owners according to ADR-003,
ADR-004, and the relevant CAP.

The exact serialized schema remains unresolved and must be defined by the ADR.

### D-002 — Timing Windows And Rule Opportunities Are Distinct

A timing window identifies the current game-flow interval.

Rule opportunities identify currently eligible rule interactions within that
interval.

Opportunity identity must be grounded in authoritative runtime sources and
capability identity rather than synthetic persistent UUIDs.

The timing window must not duplicate rule truth.

### D-003 — Opportunities Are Re-Derived, Not Stored As A Mutable Queue

`TimingWindowState` must not own a cached mutable queue of opportunities.

After every successful replayable command that resolves one opportunity, the
orchestrator re-derives all remaining eligible opportunities from authoritative
state.

This supports:

- one rule invalidating another;
- one rule creating a new opportunity;
- state-dependent eligibility changes;
- save/load, reconnect, replay, and network determinism.

The window may continue only after the current eligible-opportunity set has
been recalculated.

### D-004 — Player-Controlled Resolution Order

When game rules grant a player control over the order of optional opportunities
in a timing window, the orchestrator must present all currently selectable
opportunities for that player.

The player chooses exactly one opportunity to resolve next.

The orchestrator must not select an optional opportunity merely because it
appears first in deterministic ordering.

Deterministic ordering may be used only for:

- stable presentation;
- replay comparison;
- mandatory ordering prescribed by game rules;
- non-choice automation explicitly allowed by the timing-window contract.

After the selected opportunity resolves through a replayable command, all
opportunities are re-derived before another selection is made.

## 9. Final Accepted Architecture Decisions

The Project Owner has accepted the TIM-001 architecture decisions below. This
section is compact normative source material for the forthcoming ADR.

- Timing windows are authoritative lifecycle objects represented by a dedicated
  serialized `TimingWindowState` owned by `GameState`.
- The Timing Window Orchestrator owns timing-window lifecycle, recalculation,
  and continuation.
- Commands remain the replayable mutation surface for choices, declines,
  effects, and continuation commands.
- Rule opportunities are distinct from timing windows and are derived from
  authoritative runtime state.
- Opportunity identity is grounded in authoritative runtime sources and
  capability identity, not synthetic persistent UUIDs.
- `TimingWindowState` must not store a mutable opportunity queue.
- After every successful replayable command that resolves an opportunity, the
  orchestrator re-derives the current eligible-opportunity set before the
  window may continue.
- `RuleRegistry` remains a static participant index only. It may help discover
  participating capabilities, but it must not become an authoritative active
  rule-state store.
- Rule-specific eligibility, use/decline guards, costs, mutable effects, and
  runtime upgrade state remain on their existing authoritative owners under
  ADR-003, ADR-004, and the relevant CAP.
- `InteractionFlow`, `FlowSpec`, `RuleSurface`, `UIProjector`, and UI remain
  non-authoritative derived surfaces.
- When game rules permit player control over optional opportunity order, the
  orchestrator presents the currently selectable opportunities for that player
  and the player chooses exactly one opportunity to resolve next.
- Deterministic ordering may be used for stable presentation, replay
  comparison, mandatory rule-prescribed ordering, and non-choice automation
  explicitly allowed by the timing-window contract. It must not silently choose
  optional opportunities for the player.
- Rule effects remain CAP-specific. TIM-001 does not define a generic rule
  engine or effect-composition engine.
- This workbook does not authorize runtime implementation by itself.

## 10. Evaluation Matrix

| Criterion | A: GameManager | B: Flow/Payload | C: Command-local | D: Narrow orchestrator | E: Docs only |
| --- | --- | --- | --- | --- | --- |
| Architectural clarity | Medium | Low | Medium-low | High | Low |
| Deterministic sequencing | Medium-high | Medium | Medium | High | Low-medium |
| Multiple rules in one window | Medium | Medium | Low | High | Low |
| Multiple players | Medium | Medium | Low-medium | High | Low-medium |
| Nested/adjacent windows | Medium-low | Low | Low | Medium-high | Low |
| Recalculation after effects | Medium | Low-medium | Low-medium | High | Low |
| Continuation ownership | Medium | Low | Low | High | Low |
| Replay determinism | High if commands used | Risky if payload-owned | Medium | High | Medium |
| Network ordering | Medium | Medium-low | Medium-low | High | Medium |
| Save/load/reconnect | Medium | Risky | Medium-low | High | Medium |
| UI independence | High | Low | High | High | Medium |
| Testability | Medium | Medium-low | Low-medium | High | Low-medium |
| Complexity | Medium | Medium | Low initially | Medium | Low |
| Migration cost | Medium | Medium-high | Low initially | Medium | Low |
| Overengineering risk | Medium | Medium | Low | Medium | Low |
| Scalability to 100+ upgrades | Low-medium | Low | Low | High | Low |

## 11. Effect Composition Boundary

This workbook should not decide full effect composition.

Timing-window ownership should guarantee:

- when a timing window opens and closes,
- which authoritative state is used to discover legal opportunities,
- deterministic ordering of opportunity presentation,
- one-at-a-time resolution where required,
- explicit replayable use/decline commands,
- recalculation after each successful command,
- cleanup ownership on window exit,
- continuation only after no blocking opportunities remain,
- save/load, replay, network, and reconnect behavior for partial windows.

Timing-window ownership should not define card-specific composition semantics
such as additive versus replacement effects, caps, dice-face transformation
rules, token-spend costs, expiry duration, or conflict priority. Those remain
CAP-specific unless later evidence justifies a separate effect-composition
decision.

## 12. Migration Implications

With Option D accepted as the direction, migration can be incremental:

1. Write an ADR for timing-window lifecycle ownership.
2. Add a narrow contract for timing-window discovery, resolution,
   recalculation, projection, continuation, and cleanup.
3. Preserve existing Tarkin and ECM behavior until touched by a focused slice.
4. Use H9 as the first implementation that requires multiple optional rules in
   the same Attack Modify window, or backfit ECM Status Phase first if needed.
5. Move Tarkin start-of-Ship-Phase continuation from command-local transition
   into the timing-window protocol when a second start-of-Ship-Phase rule is
   implemented.

No migration should copy static upgrade metadata into runtime state or move
mutable upgrade rule state out of `ShipInstance.runtime_upgrades`.

## 13. Testing Implications

Until a formal `TEST-003` artifact exists, every timing-window implementation
should include tests for:

- FlowSpec allowed commands and CommandApplicability gates.
- Command validation for wrong player, wrong phase, stale source, missing
  source, duplicate use/decline, and forged projection payload.
- Command-history ordering: choice/decline command first, continuation command
  second when applicable.
- One-at-a-time resolution with recalculation after each successful command.
- Rule invalidation of another opportunity.
- Rule creation of a new opportunity.
- Two players controlling opportunities in the same timing window.
- Decline as an explicit replayable command.
- Save/load during a partially resolved window.
- Replay through a partially resolved window.
- Reconnect projection during a partially resolved window.
- Network host/client command-sequence equality and first-divergence checks.
- Remote command-effect classification for every mirrored command.
- Projection derivation: UI and `InteractionFlow.payload` do not own legality.
- Cleanup on normal continuation, cancellation, attack/phase end, and flow
  replacement.

These obligations align with the existing Interactive Rule Audit guidance in
`.github/skills/rule-integration/SKILL.md`.

## 14. Recommendation And Conclusion

Architectural ownership has been decided. TIM-001 accepts Option D,
Dedicated Narrow Timing-Window State/Orchestrator.

The orchestrator should be explicitly narrow:

- It owns timing-window lifecycle, ordering, recalculation, and continuation.
- It does not own rule effects.
- It does not decide card-specific effect composition.
- It does not replace command validation or command history.
- It does not replace `FlowSpec`, `InteractionFlow`, `RuleSurface`, or
  `UIProjector`.
- It reads authoritative serialized state and CAP-specific discovery helpers.
- It writes projected interaction state only through command-owned or
  lifecycle-owned mutation paths.
- It submits or enables existing replayable continuation commands only after
  unresolved opportunities are gone.

Remaining work concerns ADR creation, the Timing Window Contract, `TEST-003`,
implementation, and migration. The architecture direction itself is no longer
open in this workbook.

This workbook has fulfilled its purpose. It should now serve as historical
design evidence for the forthcoming ADR.

## 15. Rejected Options

Rejected as primary direction:

- Option A, because `GameManager` would become the owner of attack-local and
  rule-local sequencing details.
- Option B, because `InteractionFlow` and `FlowSpec` are projection/static
  metadata surfaces, not authoritative dynamic rule owners.
- Option C, because command-local continuation duplicates lifecycle logic and
  has already produced bypass risk.
- Option E, because documentation-only guidance does not solve the concrete
  ownership gap.

## 16. Remaining Implementation-Planning Questions

The accepted architecture direction leaves these implementation-planning
questions open:

1. Should the first version support nested timing windows, or explicitly
   prohibit/defer them?
2. Which timing window should be the first migration target?
3. Should the Timing Window Contract be drafted before implementation or in
   parallel with the ADR extraction?
4. What formal obligations belong in `TEST-003`?

## 17. Proposed Next Artifacts

- ADR candidate: Timing Window Ownership And Continuation.
- Contract candidate: Timing Window Lifecycle Contract.
- TEST-003 candidate: Interactive Rule Timing-Window Verification.
- CAP-H9 implementation-readiness update after the timing-window decision, if
  H9 is chosen as the first consumer.
- Focused migration task for the selected first implementation target.

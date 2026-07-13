# MA-TW-001: Cross-Consumer Timing-Window Implementation Synthesis

Status: Draft
Purpose: Migration Synthesis
Consumer: ECM, Grand Moff Tarkin, and H9 timing-window consumers
Authority:
- ADR-003
- ADR-004
- ADR-005
- CON-003
- CON-004
- CON-005
- TEST-003

This document is implementation planning evidence only. It does not redefine
architecture, create new authority, or modify any Rule Capability Package.

## 1. Purpose

This synthesis converts the ECM, Grand Moff Tarkin, and H9 CON-005 migration
assessments into one deterministic implementation roadmap for the accepted
timing-window architecture.

It answers:

- which infrastructure is shared;
- which work remains capability-specific;
- which dependency order minimizes implementation risk;
- which implementation slices should be used;
- which consumer should validate each slice;
- when CAP evidence should be updated;
- which implementation order gives Codex the most deterministic path.

This document organizes implementation work only. ADR-005 remains the
architecture authority, CON-005 remains the implementation contract, and
TEST-003 remains the verification authority.

## 2. Inputs

Architecture:

- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`

Contracts:

- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`

Verification:

- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`

Capability documentation:

- `docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/rule_capability_packages/CAP-H9-001-h9-turbolasers.md`

Migration assessments:

- `docs/architecture/migration_assessments/MA-ECM-001-con-005-compliance.md`
- `docs/architecture/migration_assessments/MA-TARKIN-001-con-005-compliance.md`
- `docs/architecture/migration_assessments/MA-H9-001-con-005-compliance.md`

## 3. Shared Infrastructure Themes

All three consumers depend on the same missing shared timing-window
infrastructure:

- `GameState` needs authoritative `TimingWindowState` with lifecycle identity,
  active/inactive state, controlling context, continuation identity, and
  serialization support.
- One immutable static timing-window definition table is needed in the shared
  timing-window module. It supplies static lifecycle policy consumed by the
  orchestrator.
- A Timing Window Orchestrator must own lifecycle, participant discovery
  orchestration, opportunity re-derivation, completion checks, and continuation.
- `RuleRegistry` must become a static participant/candidate index only. It must
  not decide runtime eligibility, ordering, completion, continuation, or
  mutation.
- Opportunities must be canonical derived records grounded in capability
  identity and authoritative runtime-source identity.
- Commands must carry enough timing-window identity to reject stale, wrong
  window, wrong player, repeated use, and repeated decline submissions.
- Projection and live UI routes must consume derived opportunities without
  becoming authoritative.
- Cleanup and failure handling must be owned by the timing-window lifecycle
  owner and must be idempotent.
- Serialization, replay, save/load, reconnect, and network mirroring must
  preserve lifecycle state and re-derive opportunities from authoritative state.
- Shared TEST-003 protocol suites are needed so future CAPs do not duplicate
  all timing-window evidence from scratch.

## 4. Shared Infrastructure Backlog

| Item | Why It Exists | Dependencies | Consumers Affected |
| --- | --- | --- | --- |
| `TimingWindowState` lifecycle identity | CON-005 requires authoritative lifecycle state owned by `GameState`; all three assessments found this absent. | None. | ECM, Tarkin, H9 |
| Immutable static timing-window definitions | CON-005 requires one canonical static definition per window type; assessments found lifecycle policy distributed or absent. | Shared timing-window module location. | ECM, Tarkin, H9 |
| Timing Window Orchestrator core | ADR-005 assigns lifecycle, recalculation, and continuation to the orchestrator; current implementations use local owners. | `TimingWindowState`; static definitions. | ECM, Tarkin, H9 |
| RuleRegistry participant candidate indexing | ADR-005 permits `RuleRegistry` only as a static index; current participation is local or capability-specific. | Static definitions; orchestrator discovery path. | ECM, Tarkin, H9 |
| Canonical opportunity derivation | TEST-003 and CON-005 require derived, non-authoritative opportunities with stable identity and duplicate handling. | Orchestrator; participant indexing. | ECM, Tarkin, H9 |
| Command lifecycle identity validation | Rule commands must validate against the active timing-window lifecycle and reject stale selections. | `TimingWindowState`; opportunity identity. | ECM, Tarkin, H9 |
| FlowSpec and CommandApplicability integration | Allowed-command surfaces must agree with concrete command validation without becoming authoritative. | Command lifecycle identity validation. | ECM, Tarkin, H9 |
| Projection and modal route integration | Live UI must present derived opportunities and dispatch accepted commands through the authoritative path. | Opportunity derivation; command integration. | ECM, Tarkin, H9 |
| Continuation and exact-one prevention | Continuation must occur only after re-derivation shows no blocking opportunities; duplicate continuation must be prevented. | Orchestrator core; command results. | ECM, Tarkin, H9 |
| Cleanup and failure protocol | Guards, pending state, stale projections, cancellation, flow replacement, and rejected commands need deterministic cleanup behavior. | Orchestrator core; rule-specific cleanup hooks or commands. | ECM, Tarkin, H9 |
| Serialization, replay, save/load, reconnect, and network sequencing | TEST-003 requires deterministic reconstruction and no client-synthesized rule or continuation commands. | Lifecycle state; command identity; projection integration. | ECM, Tarkin, H9 |
| Shared TEST-003 protocol suites | 100+ future rules need reusable evidence without weakening CAP-specific tests. | Initial orchestrator and one clean pilot. | ECM, Tarkin, H9 and future timing-window rules |

## 5. Capability-specific Backlog

### ECM

- Migrate status ready-cost continuation out of `GameManager` local helper logic
  into the shared timing-window continuation path.
- Migrate attack-time ECM and Status Phase ready-cost opportunities to canonical
  derived opportunity records.
- Preserve ECM runtime upgrade ownership for `rule_state`, pending attack-time
  authorization, ready-cost guards, and `card_state`.
- Preserve `UseECMCommand`, `DeclineECMCommand`, `ReadyECMCommand`,
  `DeclineECMReadyCommand`, and existing `SpendDefenseTokenCommand`
  responsibilities.
- Add lifecycle identity validation to ECM use, decline, ready, defense-token
  spend, and related marker/commit paths.
- Ensure ECM pending authorization remains single-use, current-attack scoped,
  defending-ship scoped, serialized, replayed, reconnect-safe, and cleared by
  the documented owner.
- Replace stale projection or `InteractionFlow` authority assumptions with
  derived projection from authoritative state.
- Add shared and ECM-specific TEST-003 evidence for multiple ready-cost choices,
  pending authorization, reconnect, network sequencing, visibility, cleanup, and
  failure paths.

### Tarkin

- Move Tarkin start-of-Ship-Phase continuation out of `TarkinChoiceCommand`.
- Derive the Tarkin opportunity from the source runtime upgrade, current phase,
  trigger guard, owner, and token-gain legality.
- Add lifecycle identity validation to Tarkin choice and decline submissions.
- Preserve Tarkin runtime upgrade ownership for the once-per-Ship-Phase trigger
  guard.
- Preserve public visibility, duplicate token auto-discard, overflow through
  `DiscardTokenCommand`, token-gain blockers, and deterministic player ship
  ordering.
- Handle duplicate Tarkin candidate or opportunity detection as fail-closed
  implementation evidence rather than implicit first-match behavior.
- Add TEST-003 evidence for start-of-Ship-Phase continuation, no bypass,
  network mirror ordering, reconnect, replay, and projection derivation.

### H9

- Implement H9 as the first clean CON-005 timing-window pilot after shared
  infrastructure exists.
- Register H9 as a candidate participant for the Attack Modify timing window.
- Derive H9 opportunities from the attacking ship's runtime upgrade, current
  attack, eligible dice, same-color Accuracy availability, and current
  runtime-upgrade guard state.
- Implement replayable `UseH9Command` and `DeclineH9Command` with lifecycle
  identity validation.
- Store the current-attack consumed or declined guard on the H9 runtime upgrade
  `rule_state`.
- Mutate exactly one legal die to the same-color Accuracy face on use; leave
  existing Accuracy spending unchanged.
- Preserve player-controlled ordering with any other optional Attack Modify
  participant and keep `confirm_attack_dice` as the only exit.
- Add full TEST-003 evidence for use, decline, repeated rejection, cleanup,
  public visibility, save/load, replay, reconnect, network, and coexistence with
  another optional modifier.

## 6. Dependency Graph

1. Establish `TimingWindowState` lifecycle identity and serialization.
2. Add immutable static timing-window definitions in the shared timing-window
   module.
3. Implement the Timing Window Orchestrator core lifecycle, re-derivation,
   continuation, close, cancellation, replacement, and failure behavior.
4. Add RuleRegistry participant candidate indexing and canonical opportunity
   derivation.
5. Integrate command lifecycle identity validation, `FlowSpec`, and
   `CommandApplicability`.
6. Integrate projection, `InteractionFlow`, modal routing, and live command
   submission through derived opportunities.
7. Add shared serialization, save/load, replay, reconnect, network, cleanup, and
   TEST-003 protocol suites.
8. Implement H9 as the first clean pilot.
9. Migrate Tarkin as the first existing implementation.
10. Migrate ECM last as the highest-complexity existing implementation.
11. Update CAP evidence after each consumer has passing CON-005 and TEST-003
    evidence.

H9 should validate the shared Attack Modify path before legacy migrations.
Tarkin should validate migration of a simpler existing timing-window consumer.
ECM should validate the hardest combination of attack-time authorization,
Status Phase ready-cost, multiple choices, cleanup, and continuation behavior.

## 7. Implementation Slices

### Slice 1: Authoritative TimingWindowState

Objective:

- Add the minimum `GameState`-owned lifecycle state required by CON-005.

Files likely affected:

- `src/core/state/game_state.gd`
- GameState serialization and deserialization surfaces
- save/load, replay initialization, reconnect reconstruction tests

TEST-003 evidence expected:

- lifecycle state serializes;
- stale or inactive lifecycle identities are distinguishable;
- projection remains derived.

Consumers unlocked:

- ECM, Tarkin, H9.

### Slice 2: Static Timing-window Definitions

Objective:

- Add one immutable shared mapping for timing-window static policy, starting
  with the minimum window definitions needed by H9, Tarkin, and ECM.

Files likely affected:

- a shared timing-window module under the existing core state/rule area;
- focused static-definition tests.

TEST-003 evidence expected:

- definitions contain only static lifecycle policy;
- runtime legality and opportunity existence remain derived elsewhere.

Consumers unlocked:

- H9 first; Tarkin and ECM after their window definitions are added.

### Slice 3: Timing Window Orchestrator Core

Objective:

- Centralize lifecycle opening, re-derivation, blocking-opportunity checks,
  continuation, close, cancellation, replacement, and duplicate-continuation
  prevention.

Files likely affected:

- shared timing-window module;
- `CommandProcessor` result integration points;
- existing GameManager continuation seams only where orchestration is currently
  local.

TEST-003 evidence expected:

- command resolves one opportunity;
- opportunities are re-derived;
- blocking opportunities keep the window open;
- exactly one continuation occurs after the final blocker.

Consumers unlocked:

- H9 pilot and later Tarkin/ECM migrations.

### Slice 4: Participant Indexing And Opportunity Records

Objective:

- Make `RuleRegistry` a static participant candidate index and define canonical
  derived opportunity records.

Files likely affected:

- RuleRegistry and rule bootstrap surfaces;
- new timing-window opportunity derivation helpers;
- participant discovery tests.

TEST-003 evidence expected:

- missing runtime sources produce no opportunity;
- duplicate opportunities fail closed or are suppressed according to CON-005;
- opportunity identity is capability plus authoritative runtime-source identity.

Consumers unlocked:

- H9 candidate registration; Tarkin and ECM candidate migration.

### Slice 5: Command Protocol Integration

Objective:

- Require timing-window commands to validate lifecycle identity, source identity,
  controller, stale selection, repeated use, repeated decline, and command
  applicability agreement.

Files likely affected:

- `FlowSpec`
- `CommandApplicability`
- rule command serializers and validators
- focused command tests

TEST-003 evidence expected:

- wrong player, wrong window, stale window, repeated use, and repeated decline
  are rejected consistently;
- `FlowSpec`, `CommandApplicability`, and concrete command validation agree.

Consumers unlocked:

- H9 commands first; Tarkin and ECM command migrations.

### Slice 6: Projection And Live Route Integration

Objective:

- Project current derived opportunities and route live use or decline actions
  through the accepted authoritative submission path.

Files likely affected:

- `src/core/network/ui_projector.gd`
- `src/core/state/interaction_flow.gd`
- modal router and timing-window modal/controller surfaces
- scene-level command routing tests

TEST-003 evidence expected:

- UI payload cannot authorize gameplay;
- stale projection cannot resurrect opportunities;
- both players observe public opportunities where required;
- live route dispatches the same commands as replay and network.

Consumers unlocked:

- H9 public Attack Modify UI; Tarkin and ECM live prompts.

### Slice 7: Persistence, Replay, Reconnect, Network, And Cleanup Suites

Objective:

- Add shared tests and implementation support for lifecycle reconstruction,
  command-history ordering, mirror sequencing, remote command classification,
  reconnect projection, cleanup, cancellation, and flow replacement.

Files likely affected:

- GameState serialization tests;
- replay tests;
- network mirror tests;
- reconnect tests;
- cleanup/failure tests.

TEST-003 evidence expected:

- authoritative peer broadcasts commands in order;
- clients do not synthesize use, decline, effect, or continuation commands;
- continuation cannot overtake prior opportunity commands;
- cleanup is idempotent and owned by the lifecycle owner.

Consumers unlocked:

- H9 pilot acceptance evidence; Tarkin and ECM migration evidence.

### Slice 8: H9 Clean Pilot

Objective:

- Implement H9 on the new timing-window path without copying legacy local
  continuation or projection patterns.

Files likely affected:

- H9 rule implementation;
- `UseH9Command` and `DeclineH9Command`;
- Attack Modify timing-window participant registration;
- attack dice projection and modal/controller surfaces;
- H9-focused TEST-003 tests.

TEST-003 evidence expected:

- one optional modifier resolved at a time;
- player selects ordering when multiple optional modifiers are available;
- availability re-derives after use or decline;
- `confirm_attack_dice` is the only Attack Modify exit.

Consumers unlocked:

- Shared timing-window path validated for a clean CAP.

### Slice 9: Tarkin Migration

Objective:

- Move Tarkin from command-owned continuation to shared timing-window lifecycle
  while preserving existing implemented behavior.

Files likely affected:

- `src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd`
- `src/core/commands/tarkin_choice_command.gd`
- start-of-Ship-Phase flow/projection/modal tests
- Tarkin replay, network, reconnect, save/load tests

TEST-003 evidence expected:

- active prompt cannot be bypassed;
- Tarkin choice or decline resolves one opportunity;
- start-of-Ship-Phase continuation happens only after re-derivation;
- no remote client synthesizes continuation.

Consumers unlocked:

- First migrated existing consumer.

### Slice 10: ECM Migration

Objective:

- Migrate ECM attack-time and Status Phase ready-cost interactions to shared
  timing-window lifecycle while preserving ECM runtime upgrade ownership.

Files likely affected:

- ECM rule implementation;
- ECM use, decline, ready, ready-decline commands;
- `SpendDefenseTokenCommand` and related defense-token marker/commit paths;
- status cleanup/start-round orchestration seams;
- ECM projection/modal/router tests;
- ECM replay, network, reconnect, save/load tests.

TEST-003 evidence expected:

- pending authorization remains in runtime upgrade `rule_state`;
- multiple ECM ready-cost choices resolve one at a time;
- repeated cleanup cannot clear unresolved guards;
- final continuation occurs after the final unresolved choice;
- attack-time and Status Phase ECM both reconstruct correctly.

Consumers unlocked:

- Highest-complexity legacy migration complete.

### Slice 11: CAP Evidence Alignment

Objective:

- Update each CAP only after its implementation has passing CON-005 and TEST-003
  evidence.

Files likely affected:

- `CAP-H9-001-h9-turbolasers.md`
- `CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `CAP-ECM-001-electronic-countermeasures.md`

TEST-003 evidence expected:

- CAP evidence references the shared timing-window categories and the
  capability-specific deltas.

Consumers unlocked:

- Documentation reflects implementation evidence without premature status
  claims.

## 8. Pilot Strategy

First clean implementation: H9.

H9 has no production implementation to unwind, exercises the Attack Modify
timing window, requires player-controlled optional ordering, and can validate
the accepted lifecycle without preserving legacy continuation code. The H9
assessment identifies it as a strong clean pilot after shared prerequisites.

First migration: Grand Moff Tarkin.

Tarkin is already implemented and has narrower timing-window behavior than ECM:
one start-of-Ship-Phase opportunity, one explicit choice/decline command, public
state, deterministic token grants, and clear continuation behavior. It is the
lowest-risk existing consumer for proving migration mechanics.

Last migration: ECM.

ECM should migrate last because it spans attack-time authorization and Status
Phase ready-cost behavior, has pending inter-command state, multiple possible
choices, cleanup sensitivity, and prior defects around continuation,
projection, and stale payload ownership. It is the correct stress test after the
shared path and Tarkin migration are proven.

## 9. CAP Update Strategy

CAP-H9:

- Update after the H9 clean pilot has passing CON-005 and TEST-003 evidence.
- Record the shared timing-window evidence, H9-specific command evidence,
  Attack Modify ordering evidence, replay/network/reconnect evidence, and
  cleanup evidence.
- Do not mark integrated before the implementation and evidence are complete.

CAP-UPG-001 / Tarkin:

- Update after Tarkin migration has passing CON-005 and TEST-003 evidence.
- Record that the existing Integrated status under earlier contracts is not by
  itself CON-005 compliance.
- Add evidence for shared lifecycle ownership, derived opportunities,
  continuation, network mirroring, replay, reconnect, and no-bypass behavior.

CAP-ECM:

- Update after ECM migration and stress tests pass.
- Record both attack-time ECM and Status Phase ready-cost timing-window evidence.
- Include pending authorization lifecycle, ready-cost guard lifecycle,
  continuation, multi-choice behavior, replay, reconnect, network, and cleanup
  evidence.

CAP updates should follow implementation evidence. They should not be used to
pre-authorize behavior or substitute for TEST-003 results.

## 10. Codex Implementation Guidance

- Implement shared infrastructure before capability behavior. Legacy consumers
  should not be patched into CON-005 one local helper at a time.
- Keep every slice small enough to validate with one consumer and one focused
  TEST-003 evidence set.
- Use H9 to validate the clean path before migrating Tarkin or ECM.
- Preserve existing runtime owners: timing-window lifecycle in
  `TimingWindowState`; upgrade mutable state in runtime upgrade `rule_state`;
  projection as derived output.
- Do not let `RuleRegistry`, UIProjector, modal routers, `InteractionFlow`, or
  `CommandProcessor` decide timing-window completion.
- Compare expected and observed command sequences in hot-seat, host, and client
  runs for every interactive rule slice.
- Prefer shared protocol tests plus capability-specific deltas. This keeps the
  approach scalable for 100+ future timing-window rules.
- Fail closed on duplicate opportunities, stale lifecycle identities, missing
  runtime sources, unknown participants, and derivation errors.
- Update CAP evidence only after the implementation and verification are in
  place.

## 11. Risks

- Implementing H9 before the shared lifecycle exists would likely reproduce the
  legacy local-continuation patterns found in ECM and Tarkin.
- Migrating ECM before Tarkin would combine new infrastructure risk with the
  most complex legacy consumer.
- Overbuilding the static definition table could accidentally introduce a new
  abstraction layer. Version 1 should remain the smallest repository-consistent
  immutable mapping required by CON-005.
- Network and replay defects are likely if continuation can overtake opportunity
  commands or if clients synthesize continuation locally.
- Projection bugs are likely if UI payloads are treated as authorization instead
  of derived display state.
- CAP updates made before evidence exists could create documentation drift.
- Shared tests may become too broad if they try to prove every capability detail;
  they should prove shared protocol obligations and leave rule-specific deltas
  to the CAP tests.

No architecture ambiguity was identified by the three migration assessments.
The remaining risks are implementation sequencing, verification coverage, and
legacy migration control.

## 12. Recommendation

Recommended implementation order:

1. Implement `GameState`-owned `TimingWindowState` lifecycle identity and
   serialization.
2. Add immutable static timing-window definitions in the shared timing-window
   module.
3. Implement the Timing Window Orchestrator core for lifecycle,
   re-derivation, continuation, close, cancellation, replacement, and failure.
4. Add RuleRegistry participant candidate indexing and canonical opportunity
   derivation.
5. Integrate command lifecycle identity validation with `FlowSpec`,
   `CommandApplicability`, and concrete command validation.
6. Integrate UIProjector, `InteractionFlow`, modal routing, and live command
   submission as derived presentation and dispatch surfaces.
7. Add shared TEST-003 suites for serialization, save/load, replay, reconnect,
   network, cleanup, failure, and command-sequence comparison.
8. Implement H9 as the first clean pilot and update CAP-H9 after evidence
   passes.
9. Migrate Tarkin as the first existing consumer and update CAP-UPG-001 after
   evidence passes.
10. Migrate ECM last and update CAP-ECM after evidence passes.
11. Run cross-consumer TEST-003 verification and use the results as the baseline
    for future timing-window capabilities.

This order maximizes deterministic implementation by proving shared lifecycle
behavior once, validating it with a clean pilot, then applying it to existing
consumers in increasing complexity.

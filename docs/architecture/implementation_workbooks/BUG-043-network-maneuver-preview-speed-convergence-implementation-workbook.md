# Ship Maneuver Capability Integration And BUG-043 Convergence Implementation Workbook

Accepted by: Project Owner
Accepted date: 2026-09-13

Owner acceptance: BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md is accepted as the sole implementation specification for BUG-043 and the associated Maneuver/Immediate-Damage integration work described by the workbook.
The previously accepted BUG-043 workbook revision is superseded and no longer implementation authority.
Implementation must follow the accepted workbook without redesign. Any conflict with accepted architecture or an unresolved Owner decision is a STOP condition.
Replay files/fixtures remain Owner-recorded only, after candidate-code-complete and the workbook’s non-fixture convergence gate.

Prepared: 2026-09-12

Owner: Project Owner

Implementation posture: documentation only; no implementation is authorized by
this Draft

Purpose: provide one coordinated implementation specification for the complete
Ship Maneuver capability integration, all twelve prerequisite Rule Capability
Packages, BUG-043 reconciliation, staged activation, and the single final
compatibility cutover.

## 1. Scope, authority, and single-workbook rule

### 1.1 Authority posture

This is **Uncertain/High-Risk Architecture** drafting under
[CODEX_WORKFLOW](../CODEX_WORKFLOW.md) and
[DA-002](../../development/decisions/DA-002-development-documents-in-agent-startup-reading.md)
because it coordinates accepted ownership across Maneuver, damage, obstacles,
Attack return, Network/passive execution, recovery, and compatibility. The
uncertainty is resolved by the accepted sources below; this workbook does not
reopen their decisions.

After explicit Project Owner acceptance, this file SHALL be the sole executable
implementation specification for the scope in Section 1.3. Until then it is an
audit candidate, authorizes no production change, and SHALL NOT be treated as
evidence that any capability is Implemented, Tested, or Integrated.

Accepted normative authority, in descending topic-specific order:

1. [ADR-006](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md),
   for `ShipInstance` ownership, Maneuver commitment, active execution,
   exceptional termination, and exact completion;
2. [ADR-014](../adr/ADR-014-canonical-immediate-faceup-damage-card-resolution.md),
   for stable authority physical-card identity, immediate obligation ownership,
   purpose-specific source binding, exact-once resolution, recovery, and
   concealment;
3. [Ship Maneuver requirements](../../requirements/gameplay_interactions/ship_maneuver_interaction.md)
   and the incorporated decisions preserved in the
   [Ship Maneuver Owner Decision Record](../../requirements/gameplay_interactions/ship_maneuver_owner_decisions.md),
   especially SMI-001--004, SMI-010--052, SMI-060--071, SMI-080--081,
   SMI-090--091, and SMI-AC-001--027;
4. [ADR-003](../adr/ADR-003-rule-and-validation-surfaces.md),
   [CON-003](../contracts/CON-003-rule-capability-contract.md), and
   [TEST-003](../tests/TEST-003-interactive-rule-timing-window-verification.md),
   for responsibility-specific rule implementation, package status, and
   evidence sufficiency;
5. [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md),
   [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md),
   [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md), and
   [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md),
   for Attack identity, command-owned mutation, Attack cleanup, and
   purpose-specific return;
6. [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md),
   for canonical-first recovery and replaceable presentation;
7. [ADR-008](../adr/ADR-008-durable-match-lifetime-player-principal-binding.md)
   and [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md),
   for authoritative player/principal entitlement and reconnect;
8. [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md)
   and [ADR-013](../adr/ADR-013-passive-network-damage-state-representation.md),
   for authority-only live RNG, command-owned passive result application, and
   filtered damage state; and
9. [Replay Baseline Workflow](../../development/REPLAY_BASELINE_WORKFLOW.md),
   only for recording, hashing, promotion, and verification procedure. It is
   not gameplay, replay-format, or compatibility authority.

The twelve RCPs remain distinct CON-003 traceability/integration artifacts and
do not own gameplay behavior:

- [CAP-DMG-001](../rule_capability_packages/CAP-DMG-001-thruster-fissure.md),
  [CAP-DMG-002](../rule_capability_packages/CAP-DMG-002-damaged-controls.md), and
  [CAP-DMG-003](../rule_capability_packages/CAP-DMG-003-ruptured-engine.md);
- [CAP-DMG-004](../rule_capability_packages/CAP-DMG-004-structural-damage.md),
  [CAP-DMG-005](../rule_capability_packages/CAP-DMG-005-projector-misaligned.md),
  [CAP-DMG-006](../rule_capability_packages/CAP-DMG-006-life-support-failure.md),
  [CAP-DMG-007](../rule_capability_packages/CAP-DMG-007-injured-crew.md),
  [CAP-DMG-008](../rule_capability_packages/CAP-DMG-008-shield-failure.md), and
  [CAP-DMG-009](../rule_capability_packages/CAP-DMG-009-comm-noise.md); and
- [CAP-OBS-001](../rule_capability_packages/CAP-OBS-001-asteroid-maneuver-overlap.md),
  [CAP-OBS-002](../rule_capability_packages/CAP-OBS-002-debris-maneuver-overlap.md),
  and [CAP-OBS-003](../rule_capability_packages/CAP-OBS-003-station-maneuver-overlap.md).

Their current status is `Draft`. This workbook references their accepted rule
sources and evidence obligations; it neither promotes their status nor converts
an RCP into a runtime or gameplay authority.

### 1.2 BUG-043 consolidation and preserved history

This file is an in-place consolidation candidate for the former **BUG-043:
Network Maneuver Preview Speed Convergence Implementation Workbook**. While
this file remains `Draft`, it does **not** supersede the former accepted
SetSpeed-centered revision introduced by git commit `28241a6` and refined at
git commit `4c2797f`.

Project Owner acceptance of this Draft SHALL perform one explicit authority
transition: accept this workbook as the sole implementation specification and
retire the former accepted BUG-043 revision from executable authority. The
acceptance record must name both actions. After that transition, the old
revisions remain historical evidence in git only and SHALL NOT be executed as
a parallel plan. If the Owner does not accept both halves, implementation stops
because two competing Maneuver authorities would remain.

Still-valid forensic history remains referenced by the
[BUG-043 issue](../../qa/bugs/open/BUG-043/issue.md), its
[annotation](../../qa/bugs/open/BUG-043/annotation_20260906_064217_001.json),
and its
[recorded replay](../../qa/bugs/open/BUG-043/replay_20260906_070521.json).
They prove the former asynchronous preview divergence and obsolete pre-commit
command path. They do not override amended ADR-006, ADR-014, or the accepted
Ship Maneuver requirements and SHALL NOT be relabeled or transformed into
replay-10 fixtures.

[TWI-003](TWI-003-authoritative-current-attack-state-implementation-workbook.md)
remains historical implementation authority for its completed Attack and
declaration-adjacent Ship Activation scope. It owns no current Maneuver record,
consequence, capability, or compatibility work. No second Maneuver workbook may
remain executable after this workbook is accepted.

### 1.3 Included capability

The coordinated scope is exactly:

- WP1 — Maneuver execution/identity substrate;
- WP-ID — one ADR-014 Immediate Damage substrate and CAP-DMG-004--009;
- WP2 — Thruster Fissure / CAP-DMG-001;
- WP3a — ship, squadron, and play-area authority;
- WP3b — obstacle detection and Damaged Controls / CAP-DMG-002;
- WP4 — Asteroid, Debris, and Station / CAP-OBS-001--003;
- WP5 — Ruptured Engine / CAP-DMG-003 and final consequence convergence; and
- WP6 — BUG-043 reconciliation, staged activation, verification, and the
  coordinated compatibility cutover.

The accepted normal lifecycle remains:

```text
OPEN + no active execution       = uncommitted transient exploration
OPEN + matching active execution = committed Maneuver resolving consequences
CONSUMED + no active execution   = completed Maneuver
```

Only completion after every mandatory consequence may perform the second to
third transition. Exceptional destruction clears the activation and nested
state without fabricating `CONSUMED`.

### 1.4 Explicit exclusions

This workbook SHALL NOT introduce or authorize:

- a generic continuation, FSM, stage machine, stack, queue, callback owner,
  route token, pending-work list, effect engine, or obstacle manager;
- another writable activation, Maneuver, physical-card, immediate-resolution,
  damage, obstacle, Attack, RNG, or Network authority;
- approximate, rectangular, sprite-derived, alpha-mask-derived, or runtime
  presentation-derived obstacle geometry;
- an all-damage-card or unrelated obstacle/objective integration project;
- persistence of uncommitted speed, yaw, tool geometry, drag state, preview,
  modal state, or `awaiting_remote`;
- compatibility adapters or dual schemas solely for obsolete development
  artifacts;
- a long-lived feature flag; or
- generation, refresh, synthesis, reconstruction, patching, transformation,
  relabeling, programmatic regeneration, or any other attempted creation of a
  Hot-Seat or Network replay fixture.

### 1.5 Dependency graph

The accepted allocation, with internal convergence checkpoints added to repair
sequencing without creating another work package or owner, is:

```text
WP1 foundation: ShipInstance execution identity/guards/serialization helpers
                 ↓
WP3a pure final-course/final-transform/collision/displacement authority
                 ↓
WP1/WP3a joint commitment convergence
  (one atomic ExecuteManeuver transaction; neither WP is complete before this)
        ├────────────────────────────→ WP2
        ├────────────────────────────→ WP3b pre-contour-safe
        └────────────────────────────→ WP-ID Maneuver binding

WP-ID foundation → six card slices candidate-code-complete
        ├────────────────────────────→ WP2 / WP3b card / WP5 dependencies
        └────────────────────────────→ Asteroid may enter WP4
                                       (no Asteroid evidence required to
                                        complete WP-ID implementation)

WP3a authority + OWNER-VERIFIED CONTOUR GATE
                 ↓
WP3b active ─────────────────────────→ WP4 ─────────→ WP5
                                        ↑
                                        └─ six WP-ID card branches complete

All completed prerequisite paths
                 ↓
WP6 candidate-code-complete save-7 / replay-10 / protocol-7 Integration Candidate
  (activate complete purpose-specific paths together; incomplete paths absent)
                 ↓
TEST-003/runtime/Network/non-fixture replay convergence
                 ↓
STOP FOR OWNER REPLAY CAPTURE
                 ↓
Owner-recorded Hot-Seat + Network replay-10 files
             ↓
Owner-replay integration + Tested evidence/readiness per RCP
                 ↓
twelve distinct explicit Owner Integrated approvals
                 ↓
accepted release/cutover of the already-versioned candidate
```

These precision edges do not redesign the allocation:

- WP1 first supplies the narrow owner/identity substrate; WP3a then supplies
  the authoritative derivation consumed by their joint commitment checkpoint;
  neither work package claims completion until `ExecuteManeuverCommand` uses
  both atomically;
- authoritative real-obstacle detection in WP3b reads WP3a's actual final
  transform and cannot activate before both the joint checkpoint and contour
  gate;
- CAP-DMG-001--003 and CAP-OBS-001--003 require the stable physical-card and
  passive damage foundations owned once by WP-ID; and
- Asteroid requires all six immediate-card branches to be candidate-code-
  complete before its draw path activates, but Asteroid cross-source evidence
  is gathered later in WP4 and is not a WP-ID candidate-code-complete gate.

### 1.6 Independent-audit correction record

| Finding | Disposition in this Draft |
| --- | --- |
| C1 — Structural exhaustion | Closed by Owner Decision 24, CAP-DMG-004, WP-ID slice/evidence, and the command/result ledger: both piles empty means no added card, source flip, normal completion, no synthetic damage/pending interaction. |
| C2 — Station/objective boundary | Closed by Owner Decision 25, SMI-091, CAP-OBS-003, WP4, and schema/evidence rows: ordinary Station remains package-owned; unsupported modifying objective configuration fails closed; no generic modifier framework. |
| C3 — pre-release evidence cycle | Closed by Owner Decisions 26--27 and Sections 11, 13, 16, 17, 20, and 22: `candidate-code-complete` is the pre-evidence workbook condition; TEST-003 retains `implementation-complete`; the candidate is not a CON-003 status or release. |
| B1 — WP1/WP3a sequencing | Closed by the WP1 foundation → WP3a pure authority → joint commitment checkpoint; no new top-level architecture. |
| B2 — WP-ID/Asteroid cycle | Closed by separating six-branch candidate-code-complete readiness from later WP4 Asteroid cross-source evidence. |
| B3 — schema ledger | Closed by Section 12.2's exact command, authority-result, application-result, canonical-state, passive-state, version, cleanup, and return schemas. No schema field is deferred to WP6. |
| B4 — subordinate Network schemas | Closed by explicit application-contract 1→2 allocation and evidence-based retention of the exact passive-ledger schema at version 1 under protocol 7. |
| B5 — supersession | Closed conditionally: Owner acceptance must simultaneously accept this workbook and retire the former accepted BUG-043 revision. |
| B6 — checkpoints/open decisions | Closed by the ordered Owner checkpoints and explicit statement that no semantic decision remains unresolved. |

## 2. Baseline and entry gate

### 2.1 One drift-detection capture

At implementation start, record one dated entry report. Reuse the accepted
discovery and RCP evidence; do not repeat broad architecture discovery unless a
hash, path, or behavior below drifted.

Capture exactly:

1. repository `HEAD`, branch/worktree, `git status --short`, and the diff stat;
2. hashes of this accepted workbook, ADR-006, ADR-014, Ship Maneuver
   requirements/Owner decisions, CON-003, TEST-003, and all twelve RCPs;
3. one current full-suite result, or a same-`HEAD`/same-worktree result whose
   provenance is recorded, including total/pass/fail/skip and every failure;
4. Phase-K architecture lint output;
5. current `SaveGameMetadata.CURRENT_VERSION`, `GameReplay.FORMAT_VERSION`,
   `GameReplay.SIGNED_FORMAT_VERSION`, `NetworkManager.PROTOCOL_VERSION`,
   `GameCommand.APPLICATION_CONTRACT_VERSION`, and
   `PassiveDamageLedger.SCHEMA_VERSION`;
6. the status and approval state of all twelve RCPs;
7. existence and signatures of the production seams in Section 2.3;
8. current BUG-043 implementation/diff state, including any uncommitted legacy
   patch and its ownership;
9. canonical obstacle-contour evidence status for every one of the six tokens;
10. read-only names and SHA-256 hashes of existing baseline and BUG-043 replay
    evidence, without copying or changing them; and
11. pre-existing test/lint failures classified under Section 2.4.

The drafting snapshot was `HEAD 2d1842de188392788d2745d0c91a9848a588455e`
on `master`, with versions `save 6 / replay 9 / protocol 6 / application
contract 1 / passive damage ledger 1` and
`SIGNED_FORMAT_VERSION == FORMAT_VERSION`. All twelve RCPs were `Draft`, with
Owner approval not requested. This is drafting evidence only; the future entry
report replaces it.

The drafting worktree also contained pre-existing, user-owned BUG-043 changes
in `game_manager.gd`, `maneuver_tool_state.gd`, `ship_activation_state.gd`,
`ship_activation_controller.gd`, `maneuver_tool_scene.gd`,
`tests/unit/test_attack_commands.gd`,
`tests/unit/test_network_command_result_ordering.gd`, and
`tests/unit/test_ship_activation_state.gd`, plus the untracked
`tests/unit/test_bug_043_maneuver_speed_convergence.gd`. They encode
the obsolete pre-commit SetSpeed convergence direction and are implementation
evidence/removal targets, not accepted future behavior. A later implementer
must preserve, attribute, and reconcile them without destructive overwrite.

### 2.2 Version and status entry assertions

| Item | Required entry value | Drift response |
| --- | --- | --- |
| Save owner | `SaveGameMetadata.CURRENT_VERSION == 6` | Stop compatibility work and identify the accepted intervening allocation. |
| Replay owner | `GameReplay.FORMAT_VERSION == 9`; signed alias equal | Stop; do not reuse replay 10 without resolving the conflict. |
| Network owner | `NetworkManager.PROTOCOL_VERSION == 6` | Stop; do not reuse protocol 7 without resolving the conflict. |
| Application-result owner | `GameCommand.APPLICATION_CONTRACT_VERSION == 1` | Stop; do not reuse contract 2 or change an exact result under contract 1. |
| Passive hidden-damage owner | `PassiveDamageLedger.SCHEMA_VERSION == 1` with its current exact four fields/meanings | Stop if schema 1 drifted; do not silently widen it. |
| RCP state | Twelve distinct packages, each with explicit current status | Stop if a package disappeared, merged, or claims unsupported advancement. |
| Workbook authority | Owner acceptance of this file explicitly retired the former accepted BUG-043 revision | Stop if either half of that authority transition is absent or another workbook competes. |
| Contours | Missing until Section 18 evidence is Owner-approved | Continue only the pre-contour-safe scope. |

### 2.3 Existing production seams to revalidate, not rediscover

| Area | Existing seam/evidence | Entry disposition |
| --- | --- | --- |
| Activation owner | `src/core/state/ship_instance.gd`, `game_state.gd` | Four historical ADR-006 facts exist; active Maneuver execution does not. |
| Commitment | `execute_maneuver_command.gd`, `game_manager.gd` | Current caller-authored result and early consumption are migration targets. |
| Transient tool | `maneuver_tool_state.gd`, `maneuver_tool_scene.gd`, `ship_activation_state.gd`, `ship_activation_controller.gd` | Preserve reusable pure preview; remove pre-commit canonical writes and speed-zero bypass. |
| Course/overlap | `maneuver_calculator.gd`, `overlap_resolver.gd` | Reuse pure model-space logic; scene geometry is advisory only. |
| Displacement | `start_displacement_command.gd`, `commit_displacement_command.gd`, displacement UI/controller | Preserve purpose-specific command ownership; replace incremental legality with complete-batch authority. |
| Damage model | `damage_card.gd`, `damage_deck.gd`, `passive_damage_ledger.gd`, `ship_instance.gd` | Reuse owners; add stable authority identity and single-location lifecycle once. |
| Immediate damage | `resolve_immediate_effect_command.gd`, `immediate_effect_resolver.gd`, `debug_deal_damage_command.gd`, Attack damage commands | Current array-index and duplicated resolver mutation are nonconforming evidence. |
| Maneuver cards | `thruster_fissure.gd`, `damaged_controls.gd`, `ruptured_engine.gd`, `persistent_effect_damage_command.gd`, `maneuver_rule_resolver.gd` | Current raw observer timing, effect-id collapse, and direct-facedown primitive are removal/refactor targets. |
| Obstacles | setup placement, `GameState.objectives`, obstacle catalog/specs | Stable placement order exists; no authoritative contours or live core effects exist. |
| Projection | `flow_spec.gd`, `command_applicability.gd`, `ui_projector.gd`, controllers/routers | Derived surfaces only; they must agree with command validation. |
| Continuation | `command_processor.gd` post-success composition and purpose-specific return patterns | Reuse authority-side call site without treating its FIFO as canonical state. |
| Save/recovery | `save_game_metadata.gd`, `save_game_manager.gd`, state serializers/installers | Exact-version, canonical-first installation remains the owner. |
| Replay | `game_replay.gd`, `replay_driver.gd`, command history | Seed-plus-semantic-history replay; no live result payload persistence. |
| Network/passive | `network_manager.gd`, command submitters, `state_filter.gd`, ordered result application | Authority validates/mutates; passive peers apply command-owned authorized results. |

### 2.4 Failure classification

**Hard entry blockers:** unaccepted or conflicting authority; absent required
canonical owner; another competing workbook; version allocation drift; an
unattributed overlapping dirty change that cannot be preserved; a relevant
baseline failure that prevents distinguishing new regression; or a required
surface whose current topology contradicts accepted ownership. Missing contour
approval is a hard blocker only for the scopes listed in Section 18.

**Expected implementation gaps:** absent active Maneuver record; premature
Maneuver consumption; pre-commit SetSpeed/resource mutation; speed-zero bypass;
missing stable physical-card identity and active immediate record; array-index
immediate resolution; incomplete passive correlations; effect-id
deduplication; missing complete-batch displacement validation; missing canonical
contours/detection/obstacle effects; and incomplete TEST-003 evidence. These are
work, not entry failures.

**Pre-existing unrelated failures:** record the exact test/lint name, command,
first failure, ownership, and whether it reproduces on the unchanged entry
snapshot. Do not repair, waive, or count it as new-work success. A new failure
in an affected surface is not “unrelated” merely because a similar failure
predated the task.

## 3. WP1 — Maneuver execution and identity substrate

### 3.1 Allocation

The active ship's `ShipInstance` remains the sole writable ADR-006 owner. Add
one narrow JSON-safe active Maneuver execution value owned there; `GameState`
only aggregates, serializes, and validates cross-ship uniqueness. The value may
retain only the execution identity, matching activation identity, committed
speed-change fact needed by CAP-DMG-001, and non-derivable purpose-specific
commit/completion evidence permitted by ADR-006. It SHALL NOT duplicate current
speed, consumed resources, final transform, damage, squadron positions,
obstacle/package state, or a list of pending work.

The implementation SHALL provide narrow owner operations for:

- atomic commitment against matching activation, Maneuver `OPEN`, and no
  current execution;
- identity-bound updates of only accepted non-derivable execution evidence;
- exact normal completion after a fresh positive proof of no mandatory work;
- snapshot/rollback of every canonical fact touched by commitment;
- normal activation cleanup; and
- exceptional termination/destruction cleanup without fabricated completion.

No public caller writes execution fields directly. Unknown/missing fields,
empty or stale identities, invalid owner combinations, more than one active
execution, `CONSUMED + record`, `OPEN + mismatched record`, and any record on an
inactive/destroyed owner reject before installation or mutation.

### 3.2 Commitment versus completion

`ExecuteManeuverCommand` remains the one authoritative commitment transaction.
Its future schema carries player intent and stable identities, not caller-owned
final transforms or overlap Booleans. Authority re-derives current starting
speed/resources/rule modifiers, minimum Navigate source consumption, legal
speed/yaw/tool side, committed course, actual final result, and rollback data.

Acceptance atomically consumes the selected minimum sources, applies canonical
speed/result, creates the active execution, and leaves Maneuver `OPEN`.
Rejection changes none of speed, resources, transform, execution, opportunity,
history, cursor, or projection-success state. Normal completion is a later
identity-bound semantic transition and is unavailable while any purpose-
specific owner reports mandatory work.

WP1 is sequenced internally rather than pretending that the complete command
can precede WP3a. First land the ShipInstance execution value, guards,
serialization helpers, and pure re-evaluation interface behavior-inert. WP3a
then lands the pure authority derivation used by commitment. Finally, one
**WP1/WP3a joint commitment checkpoint** replaces caller-authored geometry and
proves atomic intent validation, source consumption, final transform,
execution-record creation, and rollback. This checkpoint creates no new work
package, owner, or state; WP1 and WP3a are not candidate-code-complete until it
passes.

### 3.3 Serialization, recovery, and authority-side re-evaluation

Implement strict serializer/deserializer and owner/aggregate validators as
dormant save-7 branches; current save-6 output remains unchanged until WP6.
Save/load and full-authority reconstruction distinguish the three legal states
in Section 1.3. Uncommitted `OPEN` rebuilds transient exploration from current
canonical facts. Committed `OPEN` re-evaluates remaining consequences without
repeating speed/resource consumption, movement, or completed consequences.

Add one pure Maneuver-specific authority-side evaluator at the existing
post-success/reconstruction composition seam. It re-reads current survival,
activation/execution identities, final canonical facts, and each purpose-
specific consequence owner, and returns at most one currently legal semantic
command or completion. It stores no route, queue, priority list, stage, or
continuation token. Mirror and replay modes never synthesize a command.

### 3.4 Exceptional termination and behavior-inert landing

Every destruction path reachable from Maneuver must atomically clear the
active activation/execution and the enumerated nested state whose identity is
invalidated. It must not mark Maneuver `CONSUMED`, emit normal completion, or
return to a nonexistent boundary. Cleanup is idempotent.

The value type, owner guards, pure evaluator, strict future-version serializer
helpers, and focused tests are safe to land behavior-inert. They remain
unregistered/unrouted and must not change save-6, replay-9, protocol-6, live
command schemas, or production behavior before WP6.

WP1 foundation convergence requires focused owner, aggregate, identity,
serialization-helper, reconstructed re-evaluation, duplicate/stale, and
destruction tests that do not require final geometry. Final WP1 convergence
occurs only at the joint WP1/WP3a checkpoint and additionally requires
intent-only command validation, authority-derived final geometry, atomic
source consumption/transform/record creation, rollback, speed zero, and
purpose-specific return tests. Stop if implementation requires a generic
activation FSM/continuation structure or a writable owner outside
`ShipInstance`.

## 4. WP-ID — shared ADR-014 Immediate Damage substrate

### 4.1 One physical-card identity and ownership lifecycle

Implement stable authority identity exactly once in the canonical damage model.
Each physical card receives its identity in authoritative deck construction and
retains it for its entire physical lifetime. Equal card types remain distinct.
The authoritative deck owns cards in draw/discard; assignment transfers the
same physical object to the target `ShipInstance`; repair/discard transfers it
back. A card exists in exactly one location. Commands, records, projection, and
UI reference it and never create another writable copy.

`effect_id` selects behavior only. It never identifies a physical occurrence.
Installation validates identity uniqueness across draw pile, discard, every
ship's faceup/facedown assignment, and every active obligation. Duplicate,
missing, conflicting-location, dangling, or mismatched identity fails closed.

### 4.2 One ShipInstance-owned active immediate record

Add exactly one narrow active immediate-resolution record slot to
`ShipInstance`. It references the assigned faceup source card and retains only
the ADR-014-allowed facts needed for this obligation: damaged ship where not
inherent, actual rules actor, minimum recoverable choice facts, exact-once
state, and one closed purpose-specific enclosing identity:

- Attack `CurrentAttackState` identity;
- Maneuver `ship_activation_identity` plus active Maneuver execution identity;
- authoritative debug-application identity; or
- a later separately accepted source identity.

Use typed/validated purpose-specific alternatives; no arbitrary dictionary,
callback, next command, route, generic continuation, generic choice payload,
stage, stack, queue, or pending-work field is permitted. Individual card slices
may add card-specific validation/mutation behavior, but SHALL NOT add another
active record, physical-card registry, occurrence identity, or permanent
`immediate_resolved` flag.

### 4.3 Atomic assignment, resolution, and cleanup

Every legal faceup assignment command must atomically either assign the card
and establish one matching unresolved record, or complete a wholly automatic
obligation in the same accepted transaction when the accepted architecture
allows it. No unresolved immediate card may exist without its record.

The resolving semantic command validates current card ownership/faceup state,
ship survival, record, actor, legal choice/outcome, enclosing identity,
application identity/order, and exact-once eligibility. Acceptance atomically
applies only that card rule and retires the obligation. Stale, duplicate,
wrong-card, wrong-ship, wrong-actor, wrong-enclosure, wrong-choice,
wrong-application, and wrong-order submissions fail before mutation, history,
cursor, projection success, or enclosing return.

Unrelated repair, removal, discard, flip, or reassignment rejects while the
source obligation is unresolved unless that accepted transition atomically
resolves or terminates it. Destruction clears the record and transfers/removes
assigned cards through the accepted damage lifecycle. Attack retains its own
terminal cleanup where applicable; destroyed active Maneuver suppresses return;
debug completion is terminal.

### 4.4 Persistence, passive application, and bindings

Future save-7 serialization preserves full authority physical identities,
single locations, deck/RNG state, active record, actor/choice facts,
exact-once state, and enclosing identity. Replay-10 reconstructs the full
authority model from seed and semantic commands; it does not consume live
passive result identities or ledgers.

Filtering exposes only viewer-authorized public semantics. A temporary public
faceup occurrence/application identity may exist only as narrowly required by
the current command/decision. When the card becomes facedown, passive public
card state and all faceup correlation retire atomically; only the ADR-013
facedown count remains. Logs, history, results, saves, reconnect, and UI must
not correlate the later hidden card to its earlier public occurrence.

Every RNG/damage mutation defines command-owned authority-result projection,
validation, and application. Authority alone draws/shuffles. Passive peers
never synthesize draws, resolution, or composed return. Reuse shared
transaction identity/application helpers across Attack, Maneuver, and
authoritative debug without merging their enclosing identities. Debug remains
subject to ADR-013 and creates no Network-only disclosure exception.

WP-ID foundation convergence requires exhaustive ownership/location install
validation, strict serializer helpers, assignment/retirement atomicity,
redeal-as-fresh-obligation, destruction/card-lifecycle cleanup, passive
filtering/application, correlation retirement, and Attack/Maneuver/debug
binding tests. Maneuver binding stays unreachable until WP1 exists.

## 5. WP-ID — bounded sequential CAP-DMG-004--009 slices

Implement these slices sequentially on the single WP-ID substrate. After each
slice, run its focused tests and shared negative protocol set; do not run the
full repository suite until the WP-ID convergence checkpoint. Detailed gameplay
semantics remain in the linked RCP and its accepted rule sources.

### 5.1 Structural Damage — CAP-DMG-004

| Obligation | Implementation specification |
| --- | --- |
| Production surfaces | Structural branch of `ResolveImmediateEffectCommand`; shared `DamageDeck` draw/recycle/RNG and passive application helpers; card/ship projection; purpose-specific return. Remove duplicate mutation authority from `ImmediateEffectResolver`. |
| Commands/state | Exact source physical-card identity and one active record; request the mandatory extra facedown draw through the shared deck boundary, then source flip, retirement, and survival check. If draw and discard are both empty, deal no additional card, synthesize no damage, flip the source, and complete normally under Owner Decision 24. The capability does not own recycling policy. |
| Applicability protocol | `CommandApplicability`, `FlowSpec`, automatic routing, and `validate()` agree that no player choice exists and only the current obligation can execute. |
| UI/passive | No choice modal; refresh public card/damage/hull/parent state. Authority alone recycles/shuffles/draws; passive applies authorized aggregate result and loses faceup correlation on flip. |
| Recovery/replay | Save/reconnect before automatic command and after completion; replay draw exhaustion, reshuffle, the both-piles-empty no-draw completion, extra draw when available, flip, destruction, and one valid Attack/Maneuver return or terminal debug completion. |
| Exact-once/tests | Duplicate-copy, redeal, stale/wrong card/ship/enclosure/application, duplicate resolution, lifecycle rejection, passive visibility, Attack/debug plus direct purpose-binding tests, and runtime smoke. Asteroid cross-source evidence is added in WP4. |
| Stop | Stop if the deck recycling owner contradicts Owner Decision 24; never invent proxy damage or retain a pending interaction when both piles are empty. |

### 5.2 Life Support Failure — CAP-DMG-006

| Obligation | Implementation specification |
| --- | --- |
| Production surfaces | Immediate command branch; `ShipInstance` token state; existing `LifeSupportFailure` RuleRegistry/RuleSurface token-gain restriction; every current token-gain command; projection/filtering. |
| Commands/state | Immediate discard-all-tokens retires the active record while the physical card remains faceup; persistent behavior derives only from that faceup card. No permanent immediate flag or second persistent owner. |
| Applicability protocol | Automatic immediate branch exposes no manual command. `CommandApplicability`, `FlowSpec`, every immediate/token-gain `validate()`, and `RuleSurface.TARGET_COMMAND_TOKEN_GAIN` agree. |
| UI/passive | No immediate choice modal; token/card status and every token-gain affordance update. Passive peers apply public token mutation and never originate restriction/follow-up. |
| Recovery/replay | Round-trip before/after immediate completion; rebuild/remove persistent restriction on faceup lifecycle; replay every token-gain rejection and fresh redeal obligation. |
| Exact-once/tests | Multiple copies, zero tokens, all token-gain surfaces including conversion and Tarkin paths, repair/removal/flip, stale/wrong identities, destruction, visibility, and runtime routes. |
| Stop | Stop if any token-gain surface bypasses the accepted shared rule surface or would require duplicate persistent state. |

### 5.3 Projector Misaligned — CAP-DMG-005

| Obligation | Implementation specification |
| --- | --- |
| Production surfaces | Projector branch of `ResolveImmediateEffectCommand`; canonical hull-zone shields; choice derivation; projector/router/controller; passive shield/card application. |
| Commands/state | Zero shields and unique maximum are automatic; a positive tied maximum creates the damaged-ship-owner decision. Resolve shield loss, flip, and record retirement atomically. |
| Applicability protocol | Applicability, FlowSpec, projection, and `validate()` re-derive the current positive maximum/tie and agree on whether a command is legal. |
| UI/passive | No prompt for zero/unique maximum; offer all and only tied positive-max zones to the owner. Passive peers apply authorized shield/card result and retire correlation. |
| Recovery/replay | Reconstruct zero, unique, and tied states; revalidate if shields change while pending; replay choice/automatic branches and exact return. |
| Exact-once/tests | Two or more identical cards, all tie sizes, stale zone/actor/card/ship/enclosure, duplicate, destruction, Attack/debug plus direct purpose-binding tests, reconnect, filtering, and smoke. Asteroid cross-source evidence is added in WP4. |
| Stop | Stop if presentation must own tie legality or if a passive result would expose hidden physical identity. |

### 5.4 Injured Crew — CAP-DMG-007

| Obligation | Implementation specification |
| --- | --- |
| Production surfaces | Injured Crew immediate command; canonical defense-token state; option resolver; damage-card controller/router; passive token/card result application. |
| Commands/state | Zero available tokens completes automatically with no token mutation; one available ready/exhausted token resolves automatically; multiple available tokens create the damaged-ship-owner choice; discarded tokens are unavailable. Flip and retire exactly once. |
| Applicability protocol | Applicability, FlowSpec, projection, and `validate()` agree for 0/1/multiple and re-derive current availability before mutation. |
| UI/passive | Only the genuine multiple-token choice opens; show all and only current ready/exhausted tokens. Passive peers apply authority result without choosing or returning. |
| Recovery/replay | Save/reconnect mid-choice, state change while pending, all automatic branches, replay selection/no-selection, destruction, and return. |
| Exact-once/tests | Duplicate cards, ready/exhausted/discarded combinations, wrong/stale actor/token/card/ship/enclosure, duplicate, redeal, filtering, all legal sources, and smoke. |
| Stop | Stop if zero/one-option handling requires a fabricated pending interaction or mutable array position as authority. |

### 5.5 Shield Failure — CAP-DMG-008

| Obligation | Implementation specification |
| --- | --- |
| Production surfaces | Shield Failure command; hull-zone shields; multi-select projection/controller; principal/actor validation; passive shield/card application. |
| Commands/state | Canonical opponent of the damaged ship's owner chooses zero, one, or two distinct legal hull zones in every source context. Zero-shield zones remain legal. Apply losses, flip, and retire atomically. |
| Applicability protocol | Applicability, FlowSpec, projection, and `validate()` agree on actor, 0--2 cardinality, distinctness, current zones, and current obligation. |
| UI/passive | Support explicit zero confirmation and 1/2 selections; never infer actor from current attacker. Passive peers apply authorized public result and retire physical correlation. |
| Recovery/replay | Round-trip/reconnect every cardinality; replay selections, zero-shield handling, destruction, and exact purpose-specific return. |
| Exact-once/tests | Duplicate/invalid zones, wrong/stale actor/card/ship/enclosure, duplicate submission, non-Attack actor derivation, redeal, filtering, all legal sources, and smoke. |
| Stop | Stop if opponent entitlement cannot be derived from accepted player/principal state or an authority physical identity would cross filtering. |

### 5.6 Comm Noise — CAP-DMG-009

| Obligation | Implementation specification |
| --- | --- |
| Production surfaces | Comm Noise command/resolver; `ShipInstance.current_speed`; `CommandDialStack`; choice/value projection; `StateFilter`; passive speed/dial/card result application. |
| Commands/state | Re-derive legal speed/dial alternatives. Sole speed is automatic; sole dial opens only opponent replacement-value choice; two alternatives open opponent effect choice and then value if dial; zero options mutates neither speed nor dial. Any command value, including current, is legal. Flip/retire exactly once. |
| Applicability protocol | Applicability, FlowSpec, both decision projections, and `validate()` agree on option count, canonical opponent, current speed, hidden-dial availability, and replacement value. |
| UI/passive | Show only genuine decisions. Neither prior nor resulting hidden dial value/identity/order is disclosed to unauthorized viewers in prompt, result, history, logs, save, or reconnect. |
| Recovery/replay | Round-trip both decision shapes and all 0/1/2-option branches; replay downstream speed-dependent re-evaluation, including later Ruptured Engine eligibility. |
| Exact-once/tests | All availability combinations, every replacement value, wrong/stale actor/card/ship/enclosure, duplicates, redeal, destruction, passive speed refresh, hidden-dial filtering, legal sources, and smoke. |
| Stop | Stop if passive correctness appears to require the old/resulting hidden dial value or stable authority card identity. |

WP-ID is candidate-code-complete when all six branches and the shared
identity/location/assignment/retirement/negative matrix pass using Attack,
debug, and direct purpose-binding evidence without a second record, identity,
or return owner. Maneuver binding waits for the joint WP1/WP3a checkpoint.
Asteroid is deliberately **not** required to complete WP-ID: after all six
branches are candidate-code-complete, WP4 may activate Asteroid and gather the
real cross-source evidence attributed back to CAP-DMG-004--009 and
CAP-OBS-001. Tested readiness for those RCPs waits for that later evidence.

## 6. WP2 — Thruster Fissure / CAP-DMG-001

Implement [CAP-DMG-001](../rule_capability_packages/CAP-DMG-001-thruster-fissure.md)
as one purpose-specific instance-bound capability on WP1 and the WP-ID physical
identity/passive substrate.

- Re-derive every still-faceup physical Thruster Fissure instance from the
  accepted committed Navigate speed change. Temporary collision reduction and
  unchanged speed never qualify.
- Expose it at committed Determine Course timing before Move Ship. Commitment
  establishes the matching Maneuver identity and qualifying speed-change fact;
  it does not silently perform later movement first.
- The affected ship's owner selects the hull zone and same-player ordering when
  required. One damage is **suffered** through shields/hull and the shared
  authority damage-deck/application boundary; it is not a direct-facedown draw.
- Purpose-specific Thruster state/command binds source-card, activation,
  execution, actor, order, and zone. It resolves once per faceup instance and
  returns to Maneuver for fresh survival/applicability re-evaluation.
- Save/load and reconnect preserve a live per-instance decision without
  replaying commitment or movement. Replay records accepted per-instance
  choices/damage in authority order. Passive peers apply viewer-authorized
  results and synthesize nothing.
- If damage destroys the moving ship, the accepted transaction performs
  ADR-006/ADR-014 cleanup and suppresses Move Ship, normal Maneuver completion,
  and return.

Focused evidence: qualifying/nonqualifying changes, multiple copies and
same-timing order, hull zones/shields/draw, rollback, wrong/stale identities and
actor, duplicate/exact-once, save/load/reconnect/replay, passive filtering,
destruction-before-movement, UI route, and runtime smoke. Retire the current
late raw `execute_maneuver` observer/direct-facedown behavior at WP6, after the
replacement is complete and unreachable-path audit passes.

Stop if the capability cannot bind stable card plus Maneuver identities, if
suffered damage lacks a canonical owner, or if movement would have to precede
the accepted timing.

## 7. WP3a — ship, squadron, and play-area authority

WP3a consumes the behavior-inert WP1 identity/guard foundation. Its pure
geometry and complete-batch algorithms land before live commitment. WP3a then
converges jointly with WP1 when `ExecuteManeuverCommand` calls those authority
helpers atomically; no WP3a route may independently mutate an execution record
or become live before that checkpoint.

### 7.1 Final course, speed zero, and ship overlap

Move authoritative course/attachment/final-transform derivation into pure
model-space movement helpers called by the commitment transaction. The command
accepts legal intent; authority derives tool side, actual course, attempted
transform, and normalized final transform. Scene tokens, ghosts, warnings, and
caller-authored `did_overlap`/final coordinates are never authority.

Speed zero uses the same commitment/execution identity and consequence path:
no translation or ordinary yaw, unchanged canonical transform, but full final
ship/squadron/obstacle overlap evaluation. It never uses the legacy scene-only
completion shortcut.

Ship collision uses the Owner-approved simplified rectangular `ShipBase`.
Search successively lower temporary speeds using committed yaw, without
changing canonical speed. Record only the stable non-derivable closest collided
ship reference/evidence required by the purpose-specific collision boundary;
intermediate attempts trigger nothing. The actual final transform becomes
canonical once.

Evaluate SMI-065 play-area destruction from that actual post-reduction final
position using the purpose-specific base footprint that excludes shield dials
and plastic dial frames. This is a final-result terminal check, not a new
SMI-064 consequence category. A plotted/superseded out-of-bounds position is
irrelevant. Destruction uses exceptional termination and invokes no later
ship-dependent work.

### 7.2 Squadron affected set and complete-batch authority

From the accepted final transform, derive the complete stable owner/index set
of overlapped squadrons. The player who did not move the ship controls
placement, regardless of squadron ownership. Tentative identities, positions,
and order remain transient.

Extend the purpose-specific displacement commands so authority validates one
complete batch containing every placed identity/position and every excluded
identity. It must compute:

1. the maximum-cardinality legally placeable subset;
2. player-selected identities only among equally maximal subsets;
3. within that subset, the maximum legal direct-touch count against the moved
   ship;
4. every remaining placed squadron's legal secondary touch;
5. play-area inclusion and no ship/squadron overlap; and
6. destruction of exactly the identities genuinely excluded from the chosen
   maximum subset.

A suboptimal batch rejects with deterministic deficiency information; it
cannot manufacture destruction. No retry counter or random placement exists.
One accepted command authoritatively places/destroys the complete batch and
returns to the matching Maneuver execution.

### 7.3 Accepted project ordering and collision consequence

For a surviving final-result boundary, preserve SMI-064:

```text
final transform
→ complete Squadron displacement
→ ordinary ship-collision damage
→ ship-collision-triggered effects
→ obstacle-only Damaged Controls if not already resolved for that instance
→ obstacle consequences
→ remaining post-execution effects
```

Ordinary collision damage deals one facedown card to the moving ship and one to
the stable closest collided ship through the accepted damage command/application
boundary. The closest target, exact-once key, and resolved bit are the exact
`active_maneuver_execution.ship_collision` evidence in Section 12.2; the
automatic `resolve_ship_collision_damage` v2 command consumes only that
evidence and may not reselect a target from post-displacement geometry. Damage
application and destruction caused by either draw complete
before collision-triggered effects. Completed final geometry and Squadron
displacement are not rolled back by later destruction. Every purpose-specific
command revalidates survival/applicability and returns through the Maneuver
evaluator; UI callbacks do not return gameplay control.

Focused evidence covers course derivation, all legal speeds including zero,
temporary reduction and closest identity, actual-final play-area cases,
stable affected-set derivation, maximum subset/direct-touch proofs,
complete-batch rejection/acceptance, unplaceable destruction, collision damage
and immediate-card nesting, return, recovery, Network/passive application, and
destruction. Stop if scene geometry or incremental placement must become
authority, or if a generic displacement/Maneuver work list appears necessary.

## 8. WP3b — obstacle detection and Damaged Controls / CAP-DMG-002

### 8.1 Pre-contour-safe scope

Before Owner contour approval, only these artifacts may proceed:

- JSON-safe canonical contour value/data structures with explicit units,
  local origin, orientation, winding, contact policy, version, and hash fields,
  but no asserted real-token vertices;
- a pure deterministic polygon/ship-base collision algorithm operating on
  injected model-space contours/transforms;
- synthetic shapes and characterization tests for rotation, winding,
  boundary contact, scale, false positives/negatives, and deterministic order;
- final-transform integration interfaces that remain unreachable without an
  approved contour dataset; and
- the ship-collision branch of
  [CAP-DMG-002](../rule_capability_packages/CAP-DMG-002-damaged-controls.md)
  after WP3a supplies authoritative collision evidence.

Synthetic tests prove algorithm behavior only. They are not evidence that any
real obstacle contour or detection result is accurate.

### 8.2 Mandatory contour STOP

**STOP FOR OWNER CONTOUR APPROVAL.** Section 18 defines the evidence packet and
the exact work that must stop. No canonical real-token vertices, catalog
replacement, authoritative real-obstacle detection, or RCP completion may be
accepted before that approval.

### 8.3 Post-gate authoritative detection

After approval, install the immutable verified contours for `asteroid_1..3`,
`debris_1..2`, and `station`, preserving the approved version/hash. Authority
transforms those contours from canonical setup placement and tests overlap
against the moving ship's actual final `ShipBase`. Touch without one shape lying
on another follows the approved contact policy. Moving through an obstacle and
intermediate collision-search positions remain inert.

Return stable setup placement identity/order and obstacle component key, never
scene-token array position. Multiple current overlaps are re-derived from
canonical final state. The moving ship's controller chooses among RRG-permitted
orders unless another accepted gameplay-rule authority assigns the choice.
Selecting one establishes that obstacle package's purpose-specific state; no
generic obstacle command or resolved-work queue is introduced.

### 8.4 Damaged Controls

Re-derive each physical faceup Damaged Controls instance from authoritative
final category evidence:

- ship overlap resolves it once at SMI-064 item 3, after ordinary collision;
- obstacle-only overlap resolves it once at item 4, after displacement and
  before obstacle consequences; and
- ship plus obstacle resolves that same instance only at item 3.

Each faceup instance gets its own execution-bound exact-once guard and direct
facedown draw/application command. Multiple ships, multiple obstacles, both
categories, reduced-speed attempts, and duplicate effect ids never multiply or
collapse one physical instance incorrectly. Facedown/inactive cards do not
apply. Re-derive after every consequence and recovery; authority alone draws,
passive peers apply the count/result, and later destruction suppresses invalid
return.

WP3b evidence includes approved-contour install validation, all six real-token
rotations/contact cases, final-only/speed-zero detection, stable identities,
ship-only/obstacle-only/both-category Damaged Controls, multiple copies and
obstacles, item-3/item-4 ordering, save/load/reconnect/replay, passive
non-synthesis/visibility, exact-once, rejection, destruction, and runtime smoke.

## 9. WP4 — CAP-OBS-001 through CAP-OBS-003

Implement three separate package-owned boundaries. Shared geometry and
low-level damage/discard helpers do not merge their state, commands, choices,
completion facts, evidence, or RCP status. Baseline Maneuver owns detection,
cross-obstacle order, invocation, and return to re-evaluation only.

### 9.1 Asteroid — CAP-OBS-001

The asteroid-specific command validates selected asteroid placement,
activation/execution identity, approved final overlap, survival, and unresolved
package state; authority then draws one faceup card exactly once. It uses the
WP-ID assignment boundary to transfer the physical card and atomically
establish/complete its immediate obligation.

**Activation gate:** the shared WP-ID substrate and all six legal immediate
branches CAP-DMG-004--009 must be candidate-code-complete before an Asteroid
draw can become reachable. They need not already possess Asteroid cross-source
evidence or Tested readiness; WP4 creates that evidence and attributes it to
both CAP-OBS-001 and the applicable immediate-card RCP. Static deck probability
is not a reason to leave an outcome incomplete.

The cross-source path is exactly:

```text
Asteroid draw
→ WP-ID atomic physical-card assignment + immediate obligation
→ responsibility-specific CAP-DMG-004--009 resolution or destruction
→ return to the still-live Asteroid owner
→ Asteroid exact-once completion
→ purpose-specific return to the still-live Maneuver owner
```

Asteroid never resolves, skips, defaults, or owns an immediate card. If the ship
is destroyed, card/asteroid/Maneuver cleanup follows the accepted terminal
owners and no normal return is fabricated.

### 9.2 Debris — CAP-OBS-002

The debris-specific boundary validates the selected placement and affected
ship-owner actor, presents one hull-zone choice, then suffers two damage points
sequentially against that same chosen zone inside one safe accepted mutation
unless production evidence proves a genuine semantic interruption. Shields,
draws, and destruction are re-evaluated in
order. Persist midpoint state only if a real accepted inter-command boundary
exists; do not invent one for implementation convenience.

### 9.3 Station — CAP-OBS-003

The station-specific optional boundary belongs to the affected ship's
controller. It derives current legal faceup/facedown damage choices, supports
`use_faceup` by exact `public_card_ref`, `use_facedown` by hidden ordinal, or
explicit `decline`, and authority emits exact `no_option` automatically without
a prompt when no legal card exists. It uses damage-deck
discard/application helpers but not Engineering/Repair ownership. Facedown
selection remains hidden until the accepted discard becomes public.

CAP-OBS-003 owns ordinary Station behavior only. Before invoking it, authority
checks the configured objective through the existing purpose-specific
objective/capability evidence. If Contested Outpost or another objective would
modify or suppress Station and that objective capability is not `Integrated`,
the unsupported configuration fails closed; ordinary Station behavior is not
used as fallback. An Integrated objective retains its own accepted behavior
and surface. WP4 and BUG-043 do not absorb objective integration or introduce a
generic Station/objective/obstacle modifier framework.

Each WP4 package requires its RCP's focused unit, protocol, UI where applicable,
serialization, replay, Network/reconnect, visibility, exact-once, ordering,
destruction, and runtime evidence. Stop if any package lacks a purpose-specific
owner/command, if objective behavior must be invented, if Asteroid immediate
coverage is incomplete, or if a generic obstacle-effect manager is proposed.

## 10. WP5 — Ruptured Engine and final consequence convergence

Implement [CAP-DMG-003](../rule_capability_packages/CAP-DMG-003-ruptured-engine.md)
only after WP4 converges. The Maneuver evaluator derives the absence of every
remaining purpose-specific obstacle obligation; it does not read or write an
`obstacle_complete`, consequence-stage, or generic progress marker.

At each re-evaluation:

1. require the matching live activation/execution and surviving ship;
2. re-derive that no obstacle obligation remains;
3. read current canonical speed, not temporary collision speed;
4. re-derive every physical Ruptured Engine instance still faceup after prior
   Station/other consequences;
5. expose one instance-bound ship-owner hull-zone/order decision at a time only
   when speed is greater than one;
6. suffer one damage through shields/hull using command-owned passive result
   application;
7. record exact-once completion for that source/execution atomically; and
8. re-evaluate survival, faceup state, speed, remaining instances, and every
   other mandatory consequence before continuing.

No pre-obstacle invocation, effect-id collapse, or direct-facedown primitive is
valid. Save/load/reconnect resume pending instance/order/zone decisions without
storing a generic stage. Replay preserves obstacle commands before Ruptured
Engine commands. Destruction clears the active activation/execution and
purpose-specific nested state and suppresses normal return.

Final completion is a fresh positive proof, not a stored marker. Only when the
legal committed result exists and WP1/WP2/WP3a/WP3b/WP4/WP5 plus any other
Integrated mandatory owner report no remaining obligation may the existing
purpose-specific Ship Activation completion transition atomically perform:

```text
Maneuver OPEN + matching active execution
→ Maneuver CONSUMED + no active execution
```

Duplicate/stale completion, identity mismatch, non-`OPEN` disposition, dead
ship, or any current obligation rejects before mutation. End Activation remains
a separate enclosing interaction.

WP5 evidence covers current-versus-temporary speed, discarded/flipped source,
multiple copies/order, hull zones/shields/damage, post-obstacle ordering,
save/load/reconnect/replay, passive result/visibility, destruction, no-stage
recovery, exact completion proof, record retirement, duplicate completion, and
runtime smoke.

## 11. WP6 — unreleased staged integration and BUG-043 cutover

### 11.1 Integration-candidate phase

WP6 first creates an **unreleased integration candidate** only after all Codex-owned
implementation and test code required by this workbook is
`candidate-code-complete`, including replay-10 format/version logic,
serialization/application, compatibility handling, and automated non-fixture
replay tests. Its mutually wired purpose-specific paths become reachable for
evidence under the coordinated save-7/replay-10/protocol-7 boundary. This is
the **Unreleased Integration Candidate** from Owner Decisions 26--27: a workflow and
implementation condition, not a new CON-003 lifecycle status, a `Tested` claim,
an `Integrated` claim, or an accepted release. No incomplete path is made
reachable merely for incremental testing. Dormancy is achieved by
registration/routing/candidate-assembly order, never by a long-lived runtime
feature flag.

WP6 owns:

- removal of obsolete BUG-043 pre-commit SetSpeed/resource mutation,
  accepted-result preview repair, pending-speed snapshots, stale-preview guards,
  and speed-zero scene completion from the Ship Activation Maneuver path;
- removal of raw `execute_maneuver` observers and effect-id-deduplicated
  Thruster Fissure, Damaged Controls, and Ruptured Engine follow-ups once their
  replacements are complete;
- final command registration, conformance to the exact Section 12.2 schemas,
  applicability, `FlowSpec`, result
  contracts, routers/controllers, projection, filtering, recovery, and remote
  command-effect classification;
- activation of every complete purpose-specific Attack/Maneuver/debug,
  displacement, card, obstacle, and return path;
- cross-package ordering, exact-once, destruction, and cleanup integration;
- full candidate verification and per-RCP evidence updates/recommendations;
- the single coordinated candidate compatibility boundary in Section 16; and
- promotion of that already-versioned candidate to the accepted release only
  after Tested readiness, explicit per-RCP Owner approval, and Owner-recorded
  replay evidence.

`SetSpeedCommand` may remain for valid behavior outside this Maneuver
interaction. Only its pre-commit Maneuver usage is removed. Old scene callbacks
and observers are deleted/superseded only after structural searches prove the
new purpose-specific path is complete.

### 11.2 Candidate admission, evidence, and release

Candidate assembly begins only after every prerequisite implementation path
that will be registered is complete, the contour gate has passed for all real-
obstacle paths, exact schemas in Section 12 are locked, and an unreachable-path
audit finds no incomplete route. WP6 then activates the complete serializers,
command vocabulary, routes, application contracts, filtered state, and version
constants together as an unreleased 7/10/7 candidate. There is no supported
intermediate combination and no mixed old/new Maneuver session.

The candidate gathers TEST-003, runtime, Hot-Seat, Network, save/load,
reconnect, visibility, destruction, non-fixture replay, and cross-package
evidence. After it has otherwise converged and is stable enough to justify
manual recording, Section 17 reaches **STOP FOR OWNER REPLAY CAPTURE**.
Verification of the Owner-created replay files then completes any remaining
Tested-readiness evidence. Each RCP
remains individually reviewable; Codex may recommend readiness, but only the
Owner may mark it `Integrated`.

Only after twelve distinct explicit Owner approvals and a final no-drift check
may the already-versioned candidate become the accepted release/cutover. This
promotion changes no version again and creates no additional compatibility
format.

## 12. Dormant-to-active ledger

### 12.1 Activation ledger

| Artifact | Safe to land dormant? | Must remain unreachable until | Activation owner | Activation gate | Removal/supersession target |
| --- | --- | --- | --- | --- | --- |
| WP1 execution value/owner guards/pure evaluator | Yes | WP1/WP3a joint commitment checkpoint, then WP6 candidate | WP1/WP3a then WP6 | Foundation tests; authority derivation; all candidate consequence owners complete | Early consumption and callback-owned completion |
| Future save-7 Maneuver serializer/validator helpers | Yes, without changing save-6 output | Coordinated version cutover | WP6 save owner | All future fields/install validation pass | Missing/defaulted record inference |
| Future replay-10 Maneuver schemas | Yes, unselected by format 9 | Coordinated version cutover | WP6 replay owner | All commands registered and deterministic | Replay-9 SetSpeed→execute meaning |
| Stable authority physical-card identity and location validators | Yes | No live writer/serializer until complete atomic lifecycle | WP-ID foundation; WP6 publication | Ownership/install/redeal/destruction tests | Array position and effect id as occurrence identity |
| Public faceup-card occurrence reference and Ship active immediate-resolution record | Yes | Attack/debug/Asteroid source commands atomically establish exact public ref→physical mapping and any obligation | WP-ID foundation | Duplicate-title/copy, save/load/reconnect, concealment retirement, Attack/Maneuver/debug v2 binding, and strict stale/exact-once validation | Array index/effect id as occurrence identity; UI/InteractionFlow as pending authority |
| Future save-7 damage/deck/record serializers | Yes, dormant branch | Coordinated version cutover | WP6 save owner | All six slices and install/filter tests | Legacy identity-less save shape |
| Immediate-card resolving branches | Yes, direct-test only | Each branch candidate-code-complete; Maneuver binding needs joint WP1/WP3a; Asteroid waits for all six candidate-code-complete branches | WP-ID slice then WP6 route activation | Shared negative evidence; WP4 later supplies Asteroid cross-source evidence | Resolver mutation, array-index commands |
| Thruster Fissure command/state/evaluator | Yes | WP1 + WP-ID identity foundation | WP2 then WP6 | Pre-move protocol and destruction proof | Raw execute observer/direct-facedown path |
| WP3a pure course/ShipBase/play-area/squadron algorithms plus closest-collision evidence and ordinary collision command | Yes; command direct-test only | Joint WP1/WP3a commitment establishes immutable closest-target evidence; live command waits for complete Maneuver path | WP3a then WP6 | Pure characterization, exact collision target/key persistence, two-target atomic damage/application, duplicate rejection, destruction and purpose-specific return | Scene-derived transform/overlap authority; legacy identity-only `overlap_damage` payload/result |
| Complete-batch displacement command changes | Yes, direct-test only | WP3a complete and live Maneuver identities active | WP3a then WP6 | Maximum-placement protocol/recovery tests | Incremental placement/callback return |
| Contour value type and synthetic algorithm tests | Yes | N/A for synthetic-only testing | WP3b | Pre-contour-safe audit | Sprite/bounds authority assumptions |
| Real six-token contour dataset | No acceptance before Owner gate | Section 18 approval | WP3b after Owner approval | Provenance/scale/origin/winding/contact/version/hash | `SPRITE_BOUNDS_FACTOR`/oriented boxes for gameplay |
| Authoritative real-obstacle detection | No | WP3a + contour approval | WP3b then WP6 | Real-token and final-only evidence | Scene/runtime sprite detection |
| Damaged Controls ship branch | Yes, direct-test only | WP3a collision facts | WP3b then WP6 | Item-3 exact-once evidence | Boolean/effect-id raw observer |
| Damaged Controls obstacle branch | No | Contour approval + authoritative detection | WP3b then WP6 | Item-4/both-category protocol | Caller `did_overlap` Boolean |
| Asteroid command/state | Yes only after contours for real integration; synthetic direct tests may precede | WP-ID all six + WP3b active | WP4 then WP6 | Nested immediate outcomes, passive RNG, return | Any asteroid-owned immediate resolution |
| Debris command/state | Yes only as direct-test code after contour gate | WP3b active | WP4 then WP6 | Same-zone sequential damage/recovery | Generic/Attack-scoped damage owner |
| Station use/decline/no-option state and command union | Yes only as direct-test code after contour gate | WP3b active and no unsupported Station-modifying objective configuration | WP4 then WP6 | Exact `use_faceup`/`use_facedown`/`decline`/authority `no_option` schemas, public-ref/facedown-ordinal validation, hidden-safe ordinary path and unsupported-objective fail-closed proof; positive modifier proof only if an applicable objective capability is already Integrated | Repair semantics, impossible empty enum branch, or generic Station/objective modifier owner |
| Ruptured Engine command/state | Yes, direct-test only | WP4 convergence | WP5 then WP6 | Post-obstacle re-derivation/exact-once | Raw execute observer/direct-facedown path |
| Applicability and `FlowSpec` routes | No partial live route | Matching command/state/projector complete | WP6 | Three-way consistency tests per command | Legacy broad/manual routes |
| UI projection/controllers/automatic evaluators | Projection helpers may land; live trigger may not | Full authoritative source and recovery exist | WP6 | Live-route, reconnect, non-synthesis tests | Modal/callback legality and completion |
| StateFilter/result-application changes | Helpers may land; no schema publication | Complete command contract and protocol 7 | WP6 | Exact `PublicFaceupDamageCard`, Attack/debug assignment, collision, Station, Comm Noise viewer-specific install/application/correlation tests | Hidden identity/dial disclosure, passive draw, or legacy card index |
| Command registration and remote-effect classification | No partial vocabulary | Every corresponding handler/result/route complete | WP6 | Exact registration/schema audit | Missing or legacy classifications |
| Legacy BUG-043 pre-commit paths | Existing only; do not extend | Remove at cutover | WP6 | Replacement path proven | Pending SetSpeed snapshots, preview acceptance repair, speed-zero bypass |
| Old raw Maneuver observers | Existing only; do not extend | Remove at cutover | WP6 | WP2/WP3b/WP5 proven | `execute_maneuver` observer generation/deduplication |
| Version constants and application-contract version | No intermediate bump | Every candidate path/schema candidate-code-complete | WP6 candidate assembly | Section 16 atomic 7/10/7 plus application-contract-v2 boundary | 6/9/6 and application contract v1 old semantics |
| Replay files/fixtures | No; they are not implementation work | Candidate-code-complete, otherwise-converged unreleased candidate justifies manual replay-10 capture | Project Owner, then Codex inspection/integration/verification | Section 17 STOP satisfied | Replay-9 files remain historical, never transformed |

Audit fails if a “must remain unreachable” artifact appears in live command
registration, applicability, FlowSpec, projection, automatic evaluation,
serializer output, state filtering, or protocol before its gate.

### 12.2 Command/result/state schema ledger

This ledger is complete before workbook acceptance. Field names, types, enum
values, required/conditional rules, identity formats, command types, result
shapes, and owners below are fixed implementation allocation; WP6 verifies
them and does not design or rename them. Every serialized dictionary and
application-result body uses an exact key set. Unknown keys, missing required
keys, wrong types, invalid enum values, blank required identities, or fields
present outside their stated union branch reject before installation or
mutation.

#### 12.2.1 Shared exact conventions

- JSON types are `String`, `int`, `float`, `bool`, `Dictionary`, and `Array[T]`.
  Integers remain integers after JSON decoding; positions are finite normalized
  `float` values; hull zones are existing `current_shields` key `String`s.
- Every serialized command retains the existing exact envelope field
  `"player":int`; the in-memory `GameCommand` property is
  `player_index:int`. `GameCommand.deserialize()` maps `"player"` to
  `player_index`, and `GameCommand.serialize()` maps `player_index` to
  `"player"`. There is no serialized `"player_index"` field, payload actor
  alias, or second actor field; both `player` and `player_index` are forbidden
  inside `payload`. For a real player decision, the submitter supplies the
  serialized `"player"` value (`0|1`), which deserializes to `player_index` and
  must validate against the authoritative rules-assigned actor/controller and
  principal entitlement. For an automatic command, no caller supplies an
  actor: authority constructs the command, derives in-memory `player_index`
  from canonical state, and serialization emits that value as `"player"`
  (`owner_player` for ship-owned automatic immediate/obstacle/collision work,
  current attacker for Attack damage, moving-ship owner for Maneuver
  completion, and the already-authorized host issuer for debug assignment).
  Such a command is never accepted from a remote/player submission surface.
  The derived value is routing/audit identity, not a fabricated rules choice;
  `actor_player` remains `-1` in automatic immediate state. Passive/result
  application uses the accepted command's deserialized `player_index` and
  authoritative/filtered pre-state; it never trusts a viewer-supplied actor
  from an application result, projection, or payload.
- `maneuver_execution_id:String` is authority-generated as
  `"maneuver:<command-sequence>"`. `physical_card_id:String` is generated once
  as `"damage:<zero-based-deck-construction-ordinal>"` before the first shuffle.
  `obstacle_id:String` is generated as `"obstacle:<placement_order>"` when the
  setup placement commits. `debug_application_id:String` is authority-generated
  as `"debug:<command-sequence>"` by accepted `debug_deal_damage`. All are
  non-empty and globally unique in their owning aggregate.
- `public_card_ref:String` is generated as
  `"faceup:<assignment-command-sequence>:<draw-ordinal>"`; draw ordinal is zero
  for a one-card assignment. It is unique for the lifetime of one match across
  all faceup assignments, including duplicate physical copies of the same
  title/effect. Authority stores it on that faceup `DamageCard` beside, but not
  derived from, `physical_card_id`; that object is the one exact mapping.
  `immediate_resolution_id:String` is `"immediate:<public_card_ref>"`.
  `PublicDamageCard` remains the existing six-field discard value;
  `PublicFaceupDamageCard` is the exact seven-field value
  `{public_card_ref:String,trait_type:String,title:String,is_faceup:true,
  effect_text:String,timing:String,effect_id:String}`. Filtered faceup arrays,
  faceup additions, projections, and reconnect use `PublicFaceupDamageCard`.
  No filtered value contains `physical_card_id`.
- Authority save/load serializes both identities only while the card is
  faceup, rejects a missing/blank/duplicate `public_card_ref`, and restores the
  one-to-one mapping before command admission. Filtered reconnect serializes
  only `PublicFaceupDamageCard`; replay deterministically regenerates the same
  reference from assignment command sequence/ordinal. A command selecting a
  visible card supplies `public_card_ref:String`; authority resolves it to
  exactly one currently faceup card on the identified ship, then validates
  physical identity, enclosing identity, and the purpose-specific exact-once
  key. Zero or multiple matches, the right reference on the wrong ship, a
  stale assignment, or an already-retired obligation rejects before mutation.
  Title/effect/index equality never substitutes for reference equality.
- Faceup-to-facedown transition atomically erases `public_card_ref` before the
  card enters authority facedown serialization and removes it from filtered
  state, results, projection, and reconnect. Faceup discard consumes the
  reference in `faceup_removals` but emits only six-field `PublicDamageCard` in
  public discard. A later redeal receives a new reference. These references
  are never placed in `PassiveDamageLedger`, facedown state, or future logs;
  filtered/exposed command history and reconnect publication also remove the
  retired reference. Full-authority replay history may retain the accepted
  semantic command identity under ADR-014, but it is never a live viewer-
  filtered correlation surface.
- `exact_once_key:String` is authority-only and exact:
  `"immediate:attack:<attack_id>:<physical_card_id>"`,
  `"immediate:maneuver:<ship_activation_identity>:<maneuver_execution_id>:<physical_card_id>"`,
  or `"immediate:debug:<debug_application_id>:<physical_card_id>"`.
- Enclosing enums are `enclosing_kind = "attack" | "maneuver" | "debug"`.
  Maneuver immediate sources additionally use
  `maneuver_source_kind = "asteroid"` and `maneuver_source_id = obstacle_id` in
  this workbook. No arbitrary source, next-command, or route value is legal.
- Dispositions are existing activation values `"INACTIVE" | "OPEN" |
  "CONSUMED"`. Purpose-specific resolution disposition is only `"OPEN" |
  "CONSUMED"`; records are absent rather than serialized as an inactive
  placeholder.

#### 12.2.2 Exact authoritative and filtered state schemas

| State owner/key | Exact schema and rules | Retirement/filtering |
| --- | --- | --- |
| `DamageCard` authority serialization | Existing six keys plus required `physical_card_id:String`; while faceup, required `public_card_ref:String`; while facedown or in draw/discard, `public_card_ref` is forbidden. The three applicable persistent cards conditionally carry exactly one matching key: `last_thruster_fissure_execution_id:String`, `last_damaged_controls_execution_id:String`, or `last_ruptured_engine_execution_id:String`. The conditional key is absent on other card types and initially `""`. | Physical id persists deck↔ship↔discard. Public ref persists only for that faceup occurrence and maps to this physical object. Last-execution value changes only on accepted matching resolution and cannot suppress a later distinct execution. Filtered faceup serialization is exactly `PublicFaceupDamageCard`; filtered discard uses six-field `PublicDamageCard`; all authority-only keys are omitted. |
| `ShipInstance.active_maneuver_execution` | Absent or exact `{maneuver_execution_id:String, ship_activation_identity:String, navigate_speed_changed:bool, obstacle_resolution_order:Array[String], ship_collision:Dictionary}`. `ship_collision` is exactly `{kind:"none"}` or `{kind:"closest_ship",target_owner_player:int,target_ship_index:int,exact_once_key:String,damage_resolved:bool}`. Its key is exactly `"collision:<ship_activation_identity>:<maneuver_execution_id>:<target_owner_player>:<target_ship_index>"`. The closest-target branch is the non-derivable result of the accepted RRG closest-ship comparison across every ship overlapped by the attempted committed result, including deterministic accepted tie handling; it is established atomically with final-course/final-transform commitment, before displacement or collision damage, and is immutable except `damage_resolved:false→true`. Order is empty until no obstacle choice is required or an accepted `commit_maneuver_obstacle_order` supplies every currently overlapped `obstacle_id` exactly once; afterward immutable. | Exists only with matching activation and Maneuver `OPEN`. Collision result survives transform/displacement changes so recovery never recomputes closest from final position. Accepted collision damage sets `damage_resolved:true` atomically with both damage applications. Normal completion removes the whole record while setting `CONSUMED`; destruction removes it without `CONSUMED`, along with any invalid nested collision state. |
| `ShipInstance.active_immediate_resolution` | Authority state is absent or base exact `{immediate_resolution_id:String, public_card_ref:String, physical_card_id:String, effect_id:String, actor_player:int, exact_once_key:String, enclosing_kind:String}` plus exactly one enclosure branch: Attack `{attack_id:String}`; Maneuver `{ship_activation_identity:String, maneuver_execution_id:String, maneuver_source_kind:"asteroid", maneuver_source_id:String}`; debug `{debug_application_id:String}`. `actor_player` is `-1` only for automatic cards, otherwise the accepted rules actor. Filtered state uses that exact applicable branch but omits `physical_card_id` and `exact_once_key`; it exists only while `public_card_ref` remains public. | Removed atomically on resolution/destruction. Faceup→facedown removes the entire filtered record, so no public reference can correlate the physical facedown card. It never stores a choice, stage, callback, or continuation. |
| Obstacle placement in `GameState.objectives["obstacles"]` | Authority state uses the existing placement keys plus required `obstacle_id:String` and authority-only `last_maneuver_execution_id:String`; the latter initially `""` and changes only when that placement's ordinary effect completes for the matching execution. Filtered placement has the same exact shape except that `last_maneuver_execution_id` is always omitted. | Placement persists. The filtered active purpose record and InteractionFlow carry only the viewer-needed public unresolved identity; the authority exact-once marker is save/replay state and never published. |
| `ShipInstance.active_asteroid_resolution` | Absent or exact `{maneuver_execution_id:String, ship_activation_identity:String, obstacle_id:String, immediate_resolution_id:String, disposition:"OPEN"}`. | Created atomically with faceup assignment; removed after nested immediate return or destruction, setting the obstacle's last-execution marker only on normal completion. |
| `ShipInstance.active_debris_resolution` | Absent or exact `{maneuver_execution_id:String, ship_activation_identity:String, obstacle_id:String, controller_player:int, disposition:"OPEN"}`. No damage midpoint is stored because the two points resolve in one command. | Removed after accepted damage/destruction return; obstacle marker records normal completion. |
| `ShipInstance.active_station_resolution` | Absent or exact `{maneuver_execution_id:String, ship_activation_identity:String, obstacle_id:String, controller_player:int, disposition:"OPEN"}`. | Removed after decline, discard, no-option completion, suppression, or destruction; obstacle marker records normal ordinary completion. Unsupported modifying objectives create no record and fail closed. |
| `InteractionFlow.payload` additions | Every Maneuver/Card/Obstacle decision contains required `owner_player:int`, `ship_index:int`, `ship_activation_identity:String`, `maneuver_execution_id:String` when Maneuver-bound, plus only the command-specific public choice fields listed below. `controller_player` remains the rules actor and `visible_to` uses the existing enum. | Re-derived from authoritative state; cleared/replaced on accepted command or terminal cleanup. It never contains `physical_card_id`, `exact_once_key`, hidden dial value, or authority deck order. |
| `PassiveDamageLedger` | Unchanged exact schema-1 `{schema_version:1, draw_count:int, discard_pile:Array[PublicDamageCard], facedown_counts:Dictionary[String,int]}`. `PublicDamageCard` remains the existing exact six public card fields with no identity. | Installed only as filtered live-Network state. No physical/public transaction identity, RNG, hidden order, or new schema-1 field is permitted. |

#### 12.2.3 Exact result envelope and damage application body

Every affected application-contract command uses the existing exact envelope:

`{protocol_version:7, application_contract:String,
application_contract_version:2, viewer_player:int,
application_result:Dictionary, presentation_result:{}}`.

The command data carries its ordinary `sequence`; the envelope does not add a
second sequence. `application_contract` equals the command type listed below.
For converted commands, `application_result` has the exact command-specific
shape below. It is transient, validated against the filtered pre-state, and is
neither saved nor replayed.

`PublicFaceupAddition` is an exact tagged union. A non-immediate faceup card is
`{public_card_ref:String,trait_type:String,title:String,is_faceup:true,
effect_text:String,timing:"persistent",effect_id:String,
immediate_obligation:"none"}`. An immediate or immediate-persistent assignment
is `{public_card_ref:String,trait_type:String,title:String,is_faceup:true,
effect_text:String,timing:"immediate"|"immediate_persistent",effect_id:String,
immediate_obligation:"open",immediate_resolution_id:String,
actor_player:int}`. The latter is emitted only after the same transaction has
installed the matching `active_immediate_resolution`; `actor_player` is the
rules chooser or `-1` for an automatic branch. Missing/mismatched record,
reference, effect, actor, or enclosing identity invalidates the whole result.

All commands that suffer/deal/discard damage compose this exact required
`damage_application:Dictionary`:

`{owner_player:int, ship_index:int,
shield_changes:Array[{zone:String,new_shields:int}], facedown_delta:int,
faceup_additions:Array[PublicFaceupAddition],
faceup_removals:Array[String], public_discards:Array[PublicDamageCard],
new_hull:int, destroyed:bool}`.

Arrays are present even when empty; `facedown_delta` may be negative only for
an accepted discard. The authoritative command derives hidden physical-card,
deck-order, and RNG facts from canonical authority state, but none is an
application-result field. `project_application_result()` emits exactly the
viewer-authorized body above, with no extra authority-only extension. A faceup
removal reference is consumed atomically and retained nowhere in passive state.
For Station `decline`/`no_option`, the exact empty application still contains
the affected `owner_player`/`ship_index`, empty arrays, `facedown_delta:0`, the
unchanged `new_hull:int`, and `destroyed:false`; `{}` is never a successful
application result.

#### 12.2.4 Exact command, result, actor, and return schemas

| Command type and actor | Exact payload after serialized `"player"` → in-memory `player_index` mapping | Exact authority result / passive application result | Cleanup and purpose-specific return |
| --- | --- | --- | --- |
| `execute_maneuver`; moving ship controller | Required `{ship_index:int, ship_activation_identity:String, speed:int, yaw_clicks:Array[int], yaw_bonus_joint:int}`. `speed>=0`; yaw array length is zero at speed 0 and otherwise equals joint count; bonus is `-1` or a legal joint. No `pos_x`, `pos_y`, `rotation_deg`, `did_overlap`, `speed_delta`, or source-selection field is legal. | Authority and application exact `{owner_player:int, ship_index:int, ship_activation_identity:String, maneuver_execution_id:String, speed:int, yaw_clicks:Array[int], yaw_bonus_joint:int, navigate_dial_spent:bool, navigate_token_spent:bool, navigate_speed_changed:bool, pos_x:float, pos_y:float, rotation_deg:float, maneuver_opportunity_disposition:"OPEN"}`. Contract id `execute_maneuver`, v2. | Atomically applies minimum source consumption, speed/final transform, and execution record. Rejection rolls all back. It invokes only the matching execution evaluator. |
| `complete_maneuver`; authority-generated for moving controller | Required `{owner_player:int, ship_index:int, ship_activation_identity:String, maneuver_execution_id:String}`. | Authority/application exact same four identities plus `{maneuver_opportunity_disposition:"CONSUMED", maneuver_execution_retired:true}`. Contract id `complete_maneuver`, v2. | Legal only after fresh proof of no mandatory consequence. Atomically consumes Maneuver and removes execution; never used for destruction. |
| `commit_maneuver_obstacle_order`; moving ship controller | Required four Maneuver identities plus `obstacle_ids:Array[String]`, containing every currently overlapped unresolved obstacle exactly once. | Authority/application exact four identities plus accepted `obstacle_ids:Array[String]`. Contract id `commit_maneuver_obstacle_order`, v2. | Stores the immutable choice in the execution record, then returns to that execution evaluator. No generic queue is created. |
| `start_displacement`; authority-generated for moving controller | Required four Maneuver identities plus `displaced_squadrons:Array[{owner:int,squadron_index:int}]`, unique and complete. `controller_player` is forbidden in payload and derived as the non-moving player. | Authority/application exact four identities plus `{controller_player:int, displaced_squadrons:Array[{owner:int,squadron_index:int}]}`. Contract id `start_displacement`, v2. | Opens only the existing displacement decision bound to the Maneuver execution. |
| `commit_displacement`; non-moving controller | Required `{owner_player:int, ship_index:int, ship_activation_identity:String, maneuver_execution_id:String, placements:Array[{owner:int,squadron_index:int,pos_x:float,pos_y:float}], excluded_squadrons:Array[{owner:int,squadron_index:int}]}`; union is the complete affected set with no duplicate identity. | Authority/application exact four Maneuver identities plus `{placements:Array[{owner:int,squadron_index:int,pos_x:float,pos_y:float}], destroyed_squadrons:Array[{owner:int,squadron_index:int}]}`. Contract id `commit_displacement`, v2. Rejected deficiency is not an accepted result and exposes `{required_placeable_count:int, submitted_placeable_count:int, required_direct_touch_count:int, submitted_direct_touch_count:int}` only through rejection projection. | Accepted batch atomically places/destroys, clears displacement state, and returns to the matching execution. |
| `resolve_ship_collision_damage`; authority-generated, in-memory `player_index` derived from moving `owner_player` and serialized as `"player"` | Required `{owner_player:int,ship_index:int,ship_activation_identity:String,maneuver_execution_id:String,target_owner_player:int,target_ship_index:int,exact_once_key:String}`. Every field must equal the active execution's `ship_collision:"closest_ship"` branch; player submission and any payload actor alias are forbidden. | Exact authority and every viewer application result: the same seven identities plus `{moving_damage_application:Dictionary,target_damage_application:Dictionary,collision_damage_resolved:true}`. Each nested dictionary is the Section 12.2.3 shape for its named ship and contains only aggregate facedown damage/hull/destruction facts; no drawn physical identity appears. Contract id `resolve_ship_collision_damage`, v2. | Authority validates both surviving targets, unresolved key, two legal facedown draws, and `damage_resolved:false`, applies one ordinary facedown card to each ship atomically, then sets `damage_resolved:true`. Duplicate/stale/wrong-target/key submissions reject. Destruction performs ADR-006 terminal cleanup; otherwise control returns only to the matching Maneuver execution for collision-triggered effects. |
| `resolve_damage` Attack ship branch; current attacker | Exact existing v2 intent `{attack_id:String}`; serialized `"player"` is required, deserializes to `player_index`, and must equal the current attacker. Target, damage, critical/faceup ordinals, and physical cards are authority-derived. | Exact authority/application result `{attack_id:String,target_kind:"ship",owner_player:int,ship_index:int,damage_application:Dictionary}`. Every faceup assignment is represented once in `damage_application.faceup_additions` as `PublicFaceupAddition`; no actor alias, `physical_card_id`, deck order, RNG state, or mutable array index appears. Contract id `resolve_damage`, v2. | In the same accepted Attack transaction, authority maps each public ref to its assigned physical card and atomically installs the matching ADR-014 record for every `immediate_obligation:"open"` entry, bound to the same `attack_id`; at most one unresolved immediate record may exist on the target, so any result that would violate that invariant rejects/rolls back. Passive application validates the accepted command actor against filtered pre-state plus attack identity, derived damage/critical ordinals, exact additions, ledger deltas, and matching public record before mutation. Attack return remains Attack-owned. |
| `debug_deal_damage`; authorized host debug issuer | Exact existing intent `{owner_player:int,ship_index:int,effect_id:String}`; serialized `"player"` is required, deserializes to the in-memory `player_index` recording the accepted host issuer, and no actor field is permitted in payload. Authority derives `debug_application_id:"debug:<sequence>"` and selects the accepted top-most matching physical draw-pile card; clients cannot submit it. | Exact authority/application result `{debug_application_id:String,owner_player:int,ship_index:int,damage_application:Dictionary}` with exactly one `PublicFaceupAddition` in `faceup_additions`. It contains no actor alias, `physical_card_id`, deck index/order, or legacy `card_index`. Contract id `debug_deal_damage`, v2. | Validation requires host-debug authority from the accepted command's `player_index`, exact target/effect availability, unique new public ref, and no conflicting active immediate record. Assignment and any required ADR-014 record are atomic and bound to `debug_application_id`; passive application validates the one public addition plus ledger delta without reading actor identity from the result. Non-immediate debug assignment terminates after assignment; immediate resolution returns only to that debug application and then terminates. |
| `resolve_immediate_effect`; recorded player actor or authority-generated automatic branch | Required base `{owner_player:int,ship_index:int,public_card_ref:String,immediate_resolution_id:String,enclosing_kind:String}` plus the matching enclosure identity fields from state. Player branches require serialized `"player"` → `player_index==actor_player`; automatic branches derive `player_index==owner_player` and serialize it as `"player"`, require `actor_player==-1`, and reject player/remote submission. No payload/result actor alias is legal. Conditional choice union: Projector `{projector_zone:String}` only for a positive tie; Injured `{defense_token_index:int}` only when multiple; Shield `{shield_zones:Array[String]}` of 0--2 distinct zones; Comm Noise uses Section 12.2.5; Structural/Life Support and other automatic branches add no choice key. | Exact authority/application result repeats the five-field command base and its exact Attack/Maneuver/debug enclosure branch, then adds `{effect_id:String,source_disposition:"faceup"|"facedown",obligation_retired:true,damage_application:Dictionary,effect_result:Dictionary}`. It contains no command-actor field. Non-Comm exact effect results remain Structural `{additional_card_dealt:bool}`, Projector `{zone:String,shields_lost:int}`, Life Support `{tokens_cleared:bool}`, Injured `{defense_token_index:int}`, and Shield `{shield_zones:Array[String]}`; Comm authority/filter unions are Section 12.2.5. Contract id `resolve_immediate_effect`, v2. | Resolves the exact public ref→physical mapping and active record once, validates actor from the accepted command plus canonical state rather than the result, applies mutation, atomically retires record/public ref and its exact-once key, then binds return solely through its typed Attack/Maneuver/debug enclosure. Debug terminates; destruction suppresses invalid Maneuver return. |
| `resolve_thruster_fissure`; affected ship owner | Required `{owner_player:int, ship_index:int, ship_activation_identity:String, maneuver_execution_id:String, public_card_ref:String, hull_zone:String}`. | Authority/application exact identities plus `{public_card_ref:String, hull_zone:String, damage_application:Dictionary}`. Contract id matches command, v2. | Sets only `last_thruster_fissure_execution_id`, retires its decision, then returns to the matching execution; destruction terminates it. |
| `resolve_damaged_controls`; authority-generated for moving controller | Required `{owner_player:int, ship_index:int, ship_activation_identity:String, maneuver_execution_id:String, public_card_ref:String, overlap_kind:"ship"|"obstacle", obstacle_id:String}`; `obstacle_id` required only for obstacle and forbidden for ship. | Authority/application exact payload identities plus `{damage_application:Dictionary}`. Contract id matches command, v2. | Sets only `last_damaged_controls_execution_id`; returns to matching execution or terminates on destruction. The prior marker rejects a second category for the same card/execution. |
| `resolve_asteroid_overlap`; authority-generated for moving controller | Required four Maneuver identities plus `{obstacle_id:String}`. | Exact authority/application result is the four identities plus `{obstacle_id:String, immediate_resolution_id:String, damage_application:Dictionary}`. Physical-card/deck/RNG facts remain canonical authority state and are not result fields. Contract id matches command, v2. | Atomically creates asteroid state and WP-ID assignment/obligation. Nested immediate return marks obstacle completion and resumes the matching execution; Asteroid never resolves the card. |
| `resolve_debris_overlap`; affected ship owner | Required four Maneuver identities plus `{obstacle_id:String, hull_zone:String}`. | Authority/application exact payload identities plus `{damage_application:Dictionary}` representing both sequential points. Contract id matches command, v2. | One command applies both points, records obstacle completion, retires debris state, and returns or terminates. |
| `resolve_station_overlap`; affected ship owner for use/decline, authority-generated for no option | Required four Maneuver identities plus exact action union: `{obstacle_id:String,action:"use_faceup",public_card_ref:String}`; `{obstacle_id:String,action:"use_facedown",facedown_ordinal:int}`; `{obstacle_id:String,action:"decline"}`; or `{obstacle_id:String,action:"no_option"}`. Selection fields are forbidden outside their branch. Use/decline requires submitted serialized `"player"` → `player_index==controller_player`; `no_option` derives `player_index==owner_player`, serializes it as `"player"`, requires zero currently legal faceup and facedown cards, and rejects player/remote submission. | Exact authority/application result is the four Maneuver identities plus `{obstacle_id:String,action:"use_faceup"|"use_facedown"|"decline"|"no_option",damage_application:Dictionary}`. It has no command-actor field. Faceup use consumes exactly the referenced visible occurrence; facedown use consumes exactly the validated ordinal without returning identity. Decline/no-option carry the exact empty damage application. The selected physical identity is never a result field. Contract id `resolve_station_overlap`, v2. | Each accepted branch validates actor only from the accepted command plus canonical state, sets the obstacle exact-once marker, removes `active_station_resolution`, and returns to the matching execution. `no_option` is legal only after fresh zero-option re-derivation. Unsupported modifying objectives reject before this command/state exists. Positive modifier paths exist only in a separately Integrated objective capability. |
| `resolve_ruptured_engine`; affected ship owner | Required `{owner_player:int, ship_index:int, ship_activation_identity:String, maneuver_execution_id:String, public_card_ref:String, hull_zone:String}`. | Authority/application exact identities plus `{public_card_ref:String, hull_zone:String, damage_application:Dictionary}`. Contract id matches command, v2. | Sets only `last_ruptured_engine_execution_id`, retires its decision, then returns for exact completion proof or terminates on destruction. |

#### 12.2.5 Comm Noise exact choice and result union

For the active Comm Noise record, authority freshly derives
`speed_available:bool = current_speed > 0` and
`dial_available:bool = hidden_top_dial_exists`. These are predicates, not
serialized record fields. The four exact availability branches are:

| Availability | Exact command branch after the Section 12.2.4 base | Serialized `"player"` / in-memory `player_index` |
| --- | --- | --- |
| speed and dial | `{comm_noise_action:"speed"}` or `{comm_noise_action:"dial",replacement_command:int}` | Submitted `"player"` is required, maps to `player_index`, and must equal the canonical opponent of `owner_player`; `replacement_command` is exactly `0|1|2|3` (`NAVIGATE|SQUADRON|CONCENTRATE_FIRE|REPAIR`). |
| speed only | `{comm_noise_action:"speed"}` | Authority derives `player_index=owner_player` and serializes it as `"player"`; player/remote submission forbidden. |
| dial only | `{comm_noise_action:"dial",replacement_command:int}` | Submitted `"player"` is required, maps to `player_index`, and must equal the canonical opponent of `owner_player`; same exact enum. There is no redundant alternatives prompt. |
| neither | `{comm_noise_action:"none"}` | Authority derives `player_index=owner_player` and serializes it as `"player"`; player/remote submission forbidden. |

`replacement_command` is required only for `"dial"` and forbidden for
`"speed"`/`"none"`. Any enum value may replace the current value, including
the same value. Validation requires the exact current public ref→physical-card
mapping, unresolved `immediate_resolution_id`, authority-only
`exact_once_key`, damaged ship, canonical opponent where submitted, enclosing
identity, current availability branch, and exact payload field set. Stale
availability, wrong actor, wrong enclosure, duplicate command, or a
replacement outside `0..3` rejects before mutation.

The common authority result is the exact `resolve_immediate_effect` result in
Section 12.2.4 with `effect_id:"comm_noise"`,
`source_disposition:"facedown"`, `obligation_retired:true`, and one exact
authority `effect_result` branch:

- speed: `{comm_noise_action:"speed",new_speed:int}`;
- dial: `{comm_noise_action:"dial",dial_changed:true,replacement_command:int}`;
- neither: `{comm_noise_action:"none"}`.

No authority result contains the old dial value. Viewer filtering leaves speed
and neither unchanged. For dial, a viewer authorized for the damaged ship's
hidden dial or the canonical opponent who selected the replacement receives
the authority branch; every other viewer receives exactly
`{comm_noise_action:"dial",dial_changed:true}`. The filtered command history,
projection, reconnect state, application result, diagnostics, and presentation
must not contain either the old value or the replacement value for an
unauthorized viewer. Passive application of a dial branch validates only the
viewer-authorized result against filtered dial count/decision state and applies
the command-owned filtered dial update; it does not infer, synthesize, or
compare a hidden value.

All four branches atomically apply their permitted mutation, flip the source
facedown, erase `public_card_ref`, remove the active immediate record, and
retire its authority exact-once key. Their `damage_application` therefore has
that ref once in `faceup_removals`, `facedown_delta:1`, no faceup addition or
public discard, unchanged shields, and the resulting hull/destruction facts.
`"none"` performs no speed/dial mutation
but performs that same flip/retirement. Destruction performs the enclosing
terminal cleanup. Otherwise the typed Attack/Maneuver/debug enclosure alone
owns the single return; no branch stores continuation state.

Automatic branches use their same purpose-specific owning command generated by
authority. They contain the exact discriminator required above (`"none"` or
`"no_option"` where specified) and omit every player-choice-only field. Passive
peers apply the validated v2 result and never originate the command, next
consequence, or return.

Repository evidence fixes the subordinate live-Network allocations:

- `GameCommand.APPLICATION_CONTRACT_VERSION` is currently `1`. Because the
  existing `resolve_immediate_effect` contract has an empty result and uses
  array-index intent while this candidate changes its semantic intent/result,
  every converted affected command uses application contract **2** at the
  protocol-7 candidate boundary. Contract 1 is not accepted for those changed
  shapes and no per-fixture adapter is added.
- `PassiveDamageLedger.SCHEMA_VERSION` is currently `1`, with the exact fields
  `schema_version`, `draw_count`, `discard_pile`, and `facedown_counts`.
  ADR-013 keeps it as aggregate hidden damage state, and the new transient
  public occurrence/application identity belongs to command results and
  filtered public faceup state, not this ledger. Therefore schema version
  **1 remains allocated**. This workbook requires no ledger-field or meaning
  change; any proposed change is outside this accepted schema and must stop for
  new authority rather than being invented during implementation.
- `StateFilter`, `CommandProcessor`, and `NetworkManager` must reject a wrong
  protocol, wrong application-contract id/version, non-exact result shape, or
  wrong passive-ledger schema before state installation/application.

The schema audit in WP6 is now a conformance check against this ledger. It may
find an authority conflict and stop; it may not choose fields, rename commands,
change unions, add a generic record, or defer schema design.

## 13. CON-003 evidence ledger — twelve distinct RCPs

Workbook acceptance, `candidate-code-complete`, TEST-003
`implementation-complete`, `Tested` readiness, and `Integrated` are distinct
facts. The workbook may be accepted before code exists. Candidate-code-complete
means all workbook-required Codex implementation and test code exists, but it
cannot claim TEST-003 `implementation-complete` until every applicable
obligation has passing evidence. Passing evidence may support `Tested`
readiness but does not supply metadata, surface review, or Owner approval. Only
the Project Owner may approve `Integrated` for each package.

The exact evidence sequence is:

```text
normative Draft acceptance
→ candidate-code-complete
→ unreleased testable Integration Candidate
→ TEST-003 evidence
→ implementation-complete / Tested evidence-readiness
→ explicit Owner Integrated approval
→ accepted release/cutover
```

Candidate-code-complete and the Integration Candidate are workbook execution
conditions only. Neither is written as an RCP status. Candidate-code-complete
purpose-specific paths are activated together there to obtain evidence;
incomplete paths remain absent and unreachable. `Implementation-complete`
retains exactly the TEST-003 meaning and threshold.

| RCP → WP | Candidate-code-complete evidence | TEST-003 implementation-complete / Tested-readiness evidence | Explicit Owner Integrated approval requires |
| --- | --- | --- | --- |
| CAP-DMG-001 → WP2 | Instance-bound pre-move trigger; suffered-damage command/choice; exact-once/recovery/passive/destruction; old hook retired in candidate | Full RCP unit/protocol/UI/save/replay/Network/visibility/runtime matrix, including multiple copies and destruction before movement | Complete CON-003 surface/metadata review, TEST-003 evidence, ordering review, and recorded Owner approval for CAP-DMG-001 |
| CAP-DMG-002 → WP3b | Item-3/item-4 instance guard; authoritative category evidence; direct draw/application; contour-gated obstacle branch | Ship-only, obstacle-only, both, multiple-copy/obstacle, speed-zero, recovery/replay/Network/visibility/runtime matrix | Approved contours plus full package/metadata evidence and recorded Owner approval for CAP-DMG-002 |
| CAP-DMG-003 → WP5 | Post-obstacle re-derivation; still-faceup/current-speed checks; suffered damage; exact-once and no-stage completion integration | Multiple copies/order, station discard, speed 0/1/>1, recovery/replay/Network/visibility/destruction/runtime matrix | Complete surface/metadata and final consequence-order review plus recorded Owner approval for CAP-DMG-003 |
| CAP-DMG-004 → WP-ID | Structural automatic command on shared identity/lifecycle; deck exhaustion/recycle integration; both-piles-empty no-draw/normal completion; exact return | All legal sources, reshuffle/both-piles-empty without synthesized damage or pending interaction, passive correlation, recovery/replay/destruction/runtime matrix | Shared foundation accepted, Owner Decision 24 conformance, full package/metadata evidence, and recorded Owner approval for CAP-DMG-004 |
| CAP-DMG-005 → WP-ID | Projector automatic/tie branches, canonical actor/choice, flip/retire, exact return | Zero/unique/all tie sizes, state-change revalidation, source/recovery/distributed/visibility/runtime matrix | Full package/metadata evidence and recorded Owner approval for CAP-DMG-005 |
| CAP-DMG-006 → WP-ID | Immediate token discard plus one existing persistent blocker across every token-gain surface | Multiple copies, all gain routes, repair/redeal, recovery/replay/Network/projection/runtime matrix | Full immediate+persistent surface/metadata alignment and recorded Owner approval for CAP-DMG-006 |
| CAP-DMG-007 → WP-ID | Correct 0/1/multiple token routing, owner command, flip/retire, return | Token-state combinations, stale-change recovery, all sources/distributed/visibility/runtime matrix | Full package/metadata evidence and recorded Owner approval for CAP-DMG-007 |
| CAP-DMG-008 → WP-ID | Canonical opponent 0--2 distinct-zone decision, passive result, flip/retire, return | All cardinalities/zone states, non-Attack actor, recovery/replay/Network/visibility/runtime matrix | Full package/metadata evidence and recorded Owner approval for CAP-DMG-008 |
| CAP-DMG-009 → WP-ID | Correct 0/1/2 alternatives and replacement-value routing; hidden-dial-safe mutation/application; return | All availability/value branches, downstream speed order, recovery/replay/Network/filtering/runtime matrix | Explicit hidden-information review, full package/metadata evidence, and recorded Owner approval for CAP-DMG-009 |
| CAP-OBS-001 → WP4 | Approved-contour eligibility; asteroid command; six candidate-code-complete WP-ID branches; assignment/nesting; exact-once/return/destruction | All three contours, speed zero, multi-obstacle order, six immediate outcomes attributed to both packages, RNG/passive/recovery/replay/runtime matrix | Contour evidence, completed cross-source evidence without requiring prior immediate-card Integrated status, package/metadata alignment, and recorded Owner approval for CAP-OBS-001 |
| CAP-OBS-002 → WP4 | Approved-contour eligibility; ship-owner zone; two sequential same-zone damage; exact return | Both contours/rotations, shields/draw/destruction point order, recovery/replay/Network/visibility/runtime matrix | Contour and package/metadata evidence, atomicity review, and recorded Owner approval for CAP-OBS-002 |
| CAP-OBS-003 → WP4 | Approved-contour eligibility; ordinary Station controller use/decline/no-option; hidden-safe discard; unsupported modifying objective fails closed | Mandatory faceup/facedown choice, decline/no-option, ordinary path, unsupported-objective rejection, recovery/replay/Network/visibility/runtime matrix; positive modifier evidence only when an applicable objective capability already exists at Integrated, otherwise not applicable | Contour, Owner Decision 25, hidden-information, package/metadata evidence, conditional-objective disposition, and recorded Owner approval for CAP-OBS-003 |

Codex may populate evidence and recommend each package as ready for Owner
review. It may not grant or record the Owner's `Integrated` decision on the
Owner's behalf.

## 14. Consolidated cross-package TEST-003 matrix

Evidence reports SHALL name the RCP IDs in every applicable result; “all tests
pass” alone is insufficient.

| Evidence category | Required proof | Applicable RCP mapping |
| --- | --- | --- |
| Unit | Pure predicates, identity/location validators, mutation, rollback, cleanup, geometry, card options, obstacle effects, and package-specific negative cases | CAP-DMG-001--009; CAP-OBS-001--003, with per-ID test names |
| Integration/protocol | Opener → derive → project/automatic resolve → command → re-derive → exact return/termination; Attack/debug/Asteroid assignment establishes exact public ref and obligation; closest-collision evidence drives exactly one two-target collision command; cross-source nesting and SMI-064 order | All twelve; Asteroid additionally maps every CAP-DMG-004--009 nested outcome; WP2/3b/5 map Maneuver lifecycle; WP3a collision evidence is prerequisite evidence |
| Applicability | Current source, actor, lifecycle, ordering, and decision shape; no inactive/facedown/stale source | Each of CAP-DMG-001--009 and CAP-OBS-001--003 individually |
| FlowSpec | Only genuine player decisions/routes are allowed; automatic branches expose none; incomplete dormant routes absent | Choice RCPs CAP-DMG-001/003/005/007/008/009, CAP-OBS-002/003; conditional order routes CAP-DMG-002 and CAP-OBS-001--003; automatic branches of all twelve |
| `validate()` | Exact agreement with applicability/FlowSpec; wrong card/ship/actor/enclosure/application/placement and duplicate/out-of-order reject before mutation | All twelve; shared negative set plus RCP-specific choices |
| Projection/UI | Viewer-authorized source, actor, choices, deficiency guidance, and live route; no fabricated prompt for automatic/no-option branches | All twelve, with explicit reduced rationale for automatic CAP-DMG-002/004/006 and CAP-OBS-001 branches |
| Save/load | Full authority identity/location/RNG and active purpose state round-trip; completed work does not reopen | All twelve; CAP-DMG-004--009 every Attack/Maneuver/debug source; obstacles pending/complete states |
| Replay | Replay-10 semantic order, deterministic authority RNG, no UI/passive input, no duplicate automatic follow-up | All twelve; CAP-OBS-001 nested immediate order; CAP-DMG-003 after obstacles |
| Network protocol | Protocol-7 exact schemas retain serialized `"player":int` ↔ in-memory `player_index:int`; entitled submissions validate the accepted command actor, automatic commands serialize the authority-derived actor, and passive results contain/trust no actor alias. Include Attack/debug faceup assignment v2, ordinary collision v2, Station four-action union, Comm Noise per-viewer result unions, ordered passive command-owned application, and rejection atomicity | All twelve, identified per command/result contract, plus WP3a ordinary collision |
| Passive result application | Viewer-authorized realized facts validate/apply inside owning command; no passive draw/shuffle/resolution/return | All damage RCPs and all three obstacle RCPs because each touches damage or nested damage |
| Reconnect | Decision-equivalent filtered install before admission; exact pending actor/options/identity without hidden authority reconstruction | All twelve; test every genuine choice and representative automatic inter-command boundary |
| Visibility/filtering | `PublicFaceupDamageCard.public_card_ref` is unique/recoverable while faceup but never reveals physical identity; duplicate-title cards remain distinct; stale refs reject; faceup→facedown correlation is retired from exposed history/reconnect; Comm Noise old/resulting dials obey the exact entitled/unauthorized unions; Station faceup-ref and facedown-ordinal selection are safe | All CAP-DMG RCPs; CAP-OBS-001/002 via damage, CAP-OBS-003 via both selection forms |
| Destruction/cleanup | Identity-bound cleanup, no dangling card/obstacle/displacement state, no invalid return or fabricated `CONSUMED`; completed geometry/displacement retained when required | All twelve plus WP1/WP3a cross-package paths |
| Runtime smoke | Real production route in Hot-Seat and Network for use/automatic/decline where applicable, rejection, recovery, normal return, and destruction | Each RCP individually; scenario may cover multiple IDs only if evidence labels every observed boundary |

## 15. Network and passive boundary

The coordinated implementation SHALL preserve all of these invariants:

- live Network authority alone owns and advances RNG, hidden damage-deck order,
  stable physical-card identities, and every facedown identity;
- passive peers receive no live seed/resumable RNG, hidden deck order,
  placeholder card, opaque hidden identity, or private dial information;
- passive peers never synthesize player decisions, automatic card/obstacle
  resolution, draws, shuffles, damage, completion, or composed returns;
- every damage/RNG result is projected, validated, and atomically applied by
  its owning semantic command using command, ordered sequence, filtered
  pre-state, lifecycle identities, and viewer-authorized realized facts;
- transport, `GameManager`, `StateFilter`, UI, and logs do not mutate canonical
  damage outside that command boundary;
- authority full state and passive filtered state are decision-equivalent for
  the viewer, not byte-identical;
- a public faceup occurrence/application identity is as narrow and temporary
  as possible and cannot correlate that card after it becomes facedown;
- Comm Noise reveals neither the old nor replacement hidden dial value or
  identity to an unauthorized viewer; its opponent decision remains actionable
  using only permitted option/value semantics;
- fresh install, resume, and reconnect publish the correct filtered ledger,
  public faceup cards, and recoverable purpose-specific decision before command
  admission; and
- Attack, Maneuver, debug, each obstacle, and each card retain their own
  enclosing identity and return. No generic Network continuation or passive
  equality repair is introduced.

Invalid/missing/stale/duplicate/out-of-order passive results fail closed without
canonical mutation, history/cursor advance, follow-up, or success presentation.
Replay remains full-authority seed-plus-history re-execution and never consumes
live passive results.

## 16. Coordinated candidate and release compatibility cutover

The only permitted boundary is:

| Owner | Current | Final | Required behavior |
| --- | ---: | ---: | --- |
| `SaveGameMetadata.CURRENT_VERSION` | 6 | 7 | Save 7 requires the complete Maneuver, physical-card, location, immediate-record, purpose-specific state, and validation shape. Save 6 rejects before body installation. |
| `GameReplay.FORMAT_VERSION` and signed alias | 9 | 10 | Replay 10 records the new commitment and all accepted consequence/completion commands. Replay 9 rejects before command application. |
| `NetworkManager.PROTOCOL_VERSION` | 6 | 7 | Protocol 7 carries the complete new command/result/state vocabulary. Protocol 6 fails handshake before play. |
| `GameCommand.APPLICATION_CONTRACT_VERSION` | 1 | 2 | Contract 2 gates changed exact intent/result shapes, especially immediate damage and the new purpose-specific damage/obstacle application paths. Contract 1 rejects for changed commands. |
| `PassiveDamageLedger.SCHEMA_VERSION` | 1 | 1 | Repository evidence shows the accepted four-field aggregate hidden-state schema remains sufficient; transient public occurrence/application identity stays outside the ledger. Any required field/meaning change is a stop, not a silent schema-1 widening. |

The 7/10/7 plus application-contract-2 constants activate together when WP6
assembles the **unreleased** candidate, before Tested readiness and Owner
`Integrated` approval, because those complete live paths are required to gather
evidence. They are not released at that point. After Owner-recorded replay verification and
twelve explicit approvals, release/cutover accepts the already-versioned
candidate without another bump.

Protocol 7 retains the existing serialized command-envelope field
`"player":int`; only the in-memory property is named `player_index`. This
correction is not a wire-schema rename, does not allocate another protocol
version, and requires no compatibility adapter beyond the already coordinated
protocol-6-to-7 fail-closed cutover.

Do not bump an intermediate format or contract for WP1, WP-ID, any individual
card, contour data, WP3a, or an obstacle slice. Do not dual-write, default missing fields,
infer from `InteractionFlow`, transform history, translate old commands, accept
mixed peers, or add adapters solely for old development fixtures. Old
incompatible schemas fail closed through their existing compatibility owners.

`BaselineTrace.FORMAT_VERSION` is independent and remains unchanged unless its
own trace schema actually changes; a replay semantic/version change alone does
not allocate a trace version.

Before changing constants, re-run the version allocation search. Any
intervening accepted use of save 7, replay 10, protocol 7, or application
contract 2 is a hard stop for authority resolution, not permission to choose
new numbers silently. `PassiveDamageLedger` schema 1 must retain its exact
current fields and meanings.

## 17. Replay/manual-capture hard STOP

Replay files/fixtures are not implementation work, and their creation or
modification is forbidden throughout implementation and candidate convergence.
First reach `candidate-code-complete`: implement every Codex-owned code and test
surface required by this workbook, including replay-10 format/version logic,
serialization/application, exact old-version rejection, compatibility handling,
deterministic replay logic, and automated non-fixture replay tests. Then
continue all otherwise-converged non-fixture verification until the unreleased
candidate is stable enough to justify manual recording. Only then:

**STOP FOR OWNER REPLAY CAPTURE.**

Codex SHALL NOT generate, refresh, synthesize, reconstruct, patch, transform,
convert, relabel, programmatically regenerate, or otherwise attempt creation of
any replay file or fixture. It SHALL NOT edit an old replay-9 header/history into
replay 10 or use BUG-043's recorded evidence as a replacement.

The Project Owner manually records genuine replay-10 files through the real
application paths:

- one Hot-Seat replay file; and
- one authoritative-host Network replay file used by both peers.

Together the recorded scenarios must exercise the baseline-required semantic
history selected in the final evidence plan, including positive-speed Navigate
commitment, legal speed zero, ship overlap/collision, displacement, at least one
approved obstacle path with any nested immediate card, normal completion, and a
destruction path. If one genuine playthrough cannot cover all cases, the Owner
records additional genuine replay files; Codex does not synthesize missing history.

Only after Owner capture may Codex resume to inspect format/provenance, compute
hashes, compare command sequences, copy/promote a byte-identical recorded input
through the accepted workflow, integrate references, and run Hot-Seat/Network
baseline verification. The source recording and promoted replay must remain
byte-identical. Any pre-commit Maneuver `set_speed`, omitted required
consequence/completion command, or Hot-Seat/Network semantic divergence returns
to implementation before another Owner recording.

## 18. Contour hard STOP

No canonical obstacle contour data or authoritative real-obstacle detection is
accepted until the Owner approves one evidence packet covering every token:

1. exact source asset/measurement and verified provenance;
2. evidence that the source faithfully represents the physical token outline;
3. physical dimensions and pixel/measurement-to-project-world scale;
4. canonical local origin/pivot, axes, orientation, and placement rotation
   convention;
5. vertex order and winding;
6. contact/touch-versus-overlap rule, numeric tolerance, and deterministic edge
   policy;
7. explicit vertices in canonical units for asteroid 1--3, debris 1--2, and
   station;
8. immutable dataset version and cryptographic hash;
9. visual/measurement verification at representative rotations and scale; and
10. recorded Project Owner approval tying the evidence to the version/hash.

Before approval, work that **may continue** is WP1; WP-ID foundation and all six
immediate slices; WP2; WP3a; WP3b's data types, pure algorithm, synthetic tests,
and ship-collision Damaged Controls branch; and WP6 bookkeeping/direct test
scaffolding that activates nothing.

Work that **must stop** is asserting real contour vertices; replacing catalog
geometry as gameplay authority; authoritative real-obstacle detection; the
obstacle-only Damaged Controls branch; all WP4 package activation/convergence;
WP5 entry/activation; any RCP Tested/Integrated recommendation dependent on real
contours; WP6 live integration, compatibility cutover, Owner replay capture, and
release convergence.

If official assets are insufficient, stop for an alternative authoritative
source or physical measurement. Never substitute sprite bounds, an oriented
box, alpha-mask extraction at runtime, guessed scale, or “close enough” hand
tracing.

## 19. Stop and escalation conditions

Implementation stops rather than improvises when:

1. accepted architecture conflicts with production topology and authority
   hierarchy cannot resolve it;
2. a required canonical owner or atomic mutation surface is absent;
3. correctness appears to require a generic continuation, FSM, stage, stack,
   queue, callback owner, pending-work record, or generic effect/obstacle owner;
4. passive correctness appears to require authority-only identity, RNG, deck
   order, facedown card, or hidden dial disclosure;
5. approximate or runtime presentation-derived obstacle geometry would be
   required;
6. a card implementation or proposed test contradicts its RCP's accepted rule
   sources or settled Owner decisions;
7. a save/replay/protocol number or compatibility assumption is no longer
   valid;
8. another workbook or legacy path would remain a competing Maneuver
   implementation authority;
9. a legal Asteroid outcome lacks complete WP-ID handling;
10. a purpose-specific consequence cannot return without inventing a generic
    mechanism;
11. a real canonical state presents two non-nested simultaneous returns that
    accepted composed-return authority cannot order; or
12. any genuine new Owner gameplay, architecture, geometry, compatibility, or
    visibility decision appears.

The stop report names the exact state/path, conflicting sources, safe work that
is already complete, and the smallest Owner decision needed. It does not spend
credits redesigning settled architecture.

The independent-audit C findings are resolved by Owner Decisions 24--27. No
Owner architecture, gameplay, or workflow decision remains unresolved in this
Draft. Workbook acceptance/legacy retirement, contour evidence approval,
manual replay capture, twelve per-RCP `Integrated` approvals, and final
release acceptance are scheduled actions under settled criteria, not open
semantics.

## 20. Verification and convergence

### 20.1 Incremental checkpoints

| Checkpoint | Verification |
| --- | --- |
| Entry | One drift baseline/full suite (or proven same-snapshot result), architecture lint, versions/status/contour/worktree inventory. |
| WP1 foundation | Focused owner/aggregate/serialization-helper/recovery/destruction tests; structural dormant-reference search; no final-geometry claim. |
| WP3a pure authority | Course/final-transform/collision/play-area/displacement characterization without a live route. |
| WP1/WP3a joint checkpoint | `ExecuteManeuverCommand` intent-only schema, atomic derivation/source consumption/transform/record creation/rollback, speed zero, and recovery. Neither WP is complete before this passes. |
| WP-ID foundation | Identity/location/install/assignment/retirement/filter/application/redeal/destruction tests. |
| Each WP-ID slice | RCP-focused unit/protocol/negative/UI as applicable; no repository full suite after each card. |
| WP-ID implementation convergence | Shared all-six Attack/debug/direct-purpose-binding matrix, save/load/reconnect/non-fixture replay/passive filtering; no Asteroid dependency. |
| WP2 | Pre-move timing, per-instance suffered damage, destruction-before-movement, recovery/distributed tests. |
| WP3a | Geometry/speed-zero/collision/play-area/maximum-displacement/collision-nesting groups. |
| Contour approval + WP3b | Evidence hash audit, synthetic plus all real-contour characterization, Damaged Controls two-boundary protocol. |
| WP4 | Separate CAP-OBS-001/002/003 suites; Asteroid supplies the six later cross-source evidence rows. Station always covers ordinary behavior and unsupported-objective fail-closed behavior; positive modifier evidence is required only if an applicable objective capability already exists at `Integrated`, otherwise it is not applicable. |
| WP5 | Post-obstacle re-derivation, no-stage recovery, exact final completion/retirement and destruction. |
| WP6 unreleased 7/10/7 candidate | Activate only complete paths plus application contract 2; run affected unit/integration/save/non-fixture replay/Network/reconnect/visibility/runtime groups, full suite, architecture lint, and structural/registration/schema/legacy-path audit. |
| Pre-capture convergence | Exact old-version/contract rejection, non-fixture replay, and all other candidate evidence stable enough to justify manual capture; then Section 17 STOP. |
| Post-capture Tested readiness | Hash/provenance, Hot-Seat and two-process Network replay baselines, per-RCP matrix completion, full suite, real runtime coverage, architecture lint, diff/whitespace and authorized-file audit. |
| Owner approval and release | Twelve explicit Integrated decisions, final no-drift check, then accept the already-versioned candidate as release without another bump. |

Focused groups run after coherent mutations, not after every helper edit. Full
suites run at the entry baseline, the otherwise-converged pre-capture
candidate, and final post-Owner-replay convergence unless a failure or risk
justifies another run.

### 20.2 Final convergence evidence

Release convergence requires:

- every workbook gate and all twelve RCP-specific evidence rows satisfied;
- twelve explicit Owner `Integrated` approvals recorded in their own packages;
- all focused and full automated results passing, with unrelated baseline
  failures separately resolved or explicitly Owner-disposed;
- real Hot-Seat and Network runtime coverage for both authoring sides where
  entitlement differs, including rejection and reconnect;
- save/load at uncommitted `OPEN`, committed `OPEN`, each genuine nested
  decision family, completed Maneuver, and destruction;
- replay-10 Hot-Seat and Network files manually recorded by the Owner and then
  inspected, integrated, and verified by Codex;
- protocol-7 ordered passive application/non-synthesis and viewer filtering;
- no faceup-to-facedown correlation or Comm Noise hidden-dial disclosure;
- exact cleanup of activation, execution, immediate, displacement, card,
  obstacle, and package state on every terminal path;
- no live pre-commit SetSpeed/spend, speed-zero bypass, raw superseded observer,
  duplicate authority, or incomplete route;
- architecture lint, structural authority checks, cross-reference checks,
  `git diff --check`, and authorized-file review; and
- a concise final evidence report mapping each result to its WP and RCP IDs.

## 21. Token/credit-efficient execution and Owner checkpoints

After acceptance, a later implementation task starts with `AGENTS.md` and this
workbook. Load only the active WP's linked RCP and authority needed to resolve a
drift/conflict; do not reread every source at every checkpoint. Reuse the entry
hashes and accepted discovery instead of repeating broad tracing.

Keep one coherent Codex implementation task where practical. Do not delegate or
spawn subagents unless the Owner explicitly requests it. Report only completed
scope, evidence, blockers, and next gate. Use focused tests within slices and
full verification only at the meaningful convergence boundaries in Section 20.

Owner checkpoints are:

1. accept this workbook after focused independent re-audit and explicitly
   retire the former accepted BUG-043 revision in the same authority action;
2. approve the Section 18 contour evidence/version/hash;
3. allow no replay-file/fixture creation or modification by Codex; when the
   candidate is `candidate-code-complete` and otherwise converged through
   non-fixture verification, reach Section 17's **STOP FOR OWNER REPLAY
   CAPTURE**, then manually record genuine replay-10 Hot-Seat and Network files;
4. grant or deny `Integrated` independently for each of the twelve RCPs after
   post-capture Tested evidence/readiness is complete; and
5. accept or reject release/cutover of the already-versioned candidate after
   all twelve approvals and the final no-drift check.

Any new decision returns to the Owner; settled decisions are not re-litigated
or redesigned to save an implementation step.

## 22. Final ordered execution checklist

- [ ] Obtain one Owner action that accepts this workbook and explicitly retires
  the former accepted BUG-043 revision; then confirm sole-workbook authority,
  hashes, baseline tests/lint, versions 6/9/6, RCP statuses, and contour status.
- [ ] Complete WP1 dormant Maneuver owner/identity/re-evaluation/cleanup
  foundation without claiming final command convergence.
- [ ] Complete WP3a pure final-course/final-transform/collision/play-area/
  displacement authority, then pass the joint WP1/WP3a atomic commitment
  checkpoint.
- [ ] Complete WP-ID once: stable physical identity/location, one active
  immediate record, atomic assignment/retirement, persistence, passive
  filtering/application, and Attack/Maneuver/debug bindings.
- [ ] Complete sequential CAP-DMG-004, 006, 005, 007, 008, and 009 slices and
  their shared negative/cross-source evidence.
- [ ] Complete WP2 CAP-DMG-001 before-movement suffered-damage path.
- [ ] Complete only WP3b pre-contour-safe work, then STOP for Owner contour
  approval.
- [ ] After approval, complete real obstacle detection and CAP-DMG-002 item-3/
  item-4 exact-once behavior.
- [ ] Complete WP4 separately for CAP-OBS-001, CAP-OBS-002, and CAP-OBS-003;
  keep Asteroid blocked until all six immediate branches are candidate-code-
  complete, then attribute its cross-source evidence to both package sides;
  fail closed for unsupported Station-modifying objective configurations.
- [ ] Complete WP5 CAP-DMG-003, post-obstacle re-derivation, exact completion
  proof, `OPEN -> CONSUMED`, and active-record retirement.
- [ ] Build the unreleased WP6 candidate; remove obsolete BUG-043/raw-observer
  paths; register only complete purpose-specific behavior; activate save 7,
  replay 10, protocol 7, and application contract 2 together; keep passive
  ledger schema 1 exact; verify old schemas fail closed.
- [ ] Run non-fixture replay verification and continue until the candidate has
  otherwise converged and is stable enough for manual recording; then **STOP
  FOR OWNER REPLAY CAPTURE**.
- [ ] After genuine Owner replay capture, inspect/hash/promote byte-identically and
  verify Hot-Seat and Network replay-10 baselines; complete the TEST-003 matrix
  and recommend each RCP separately for Owner review.
- [ ] Obtain twelve explicit Owner `Integrated` approvals, run final full/
  runtime/save-load/reconnect/replay/visibility/destruction/architecture-lint
  convergence, and accept the already-versioned candidate as the release
  cutover without another version change.

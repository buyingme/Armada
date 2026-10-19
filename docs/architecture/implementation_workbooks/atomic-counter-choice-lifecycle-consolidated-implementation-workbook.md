# Atomic Counter-Choice Lifecycle — Consolidated Implementation Workbook

Status: **Owner ACCEPTED 2026-10-17; Stages A–C Owner ACCEPTED and Stage D
implementation AUTHORIZED 2026-10-19; Stages E/F remain NOT AUTHORIZED.**
Prepared: 2026-10-17. Architecture accepted by the Project Owner after
independent acceptance audit and targeted re-audit. The independent
implementation-readiness audit passed without blockers. Boundary B
implementation was **STOPPED at workbook acceptance**; its uncommitted partial
changes were preserved. Workbook acceptance alone authorized no production
implementation, test change, fixture recording, or baseline promotion. The
later, separate Stage A and Stage B Owner directions are recorded below.

Scope: BC-009 / AT-008 Counter parent publication, choice, retirement, child,
inspection, and enclosing return, integrated with the preserved Boundary B
Attack-publication command-codec repair. The accepted
[architecture design](atomic-counter-choice-publication-architecture-design.md)
and its complete transition matrix are the architecture authority for this
bounded package. This Owner-accepted workbook is the controlling implementation
specification for the atomic Counter lifecycle refactoring and integration of
the stopped Boundary B command-codec repair. Execution still requires separate
Owner authorization. It neither reopens accepted BUG-074 or Boundary
A nor authorizes GGS-001 work.

## 1. Authority, scope, and exclusions

| Authority | Use in this package |
| --- | --- |
| [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md), [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md), and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md) | One canonical active Attack, replayable semantic mutation, source-scoped Counter disposition, and decision-equivalent reconstruction. |
| [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md) and [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md) | Legitimate inspection **I** witness, exact-once **I**/**J** consumption, no empty inspection, and composed return through existing Squadron/phase/Ship owners. |
| [Counter requirements](../../requirements/gameplay_interactions/counter_attack_interaction.md) | Complete Counter publication, single choice, locked child Declare, ordinary Roll, and enclosing return. |
| [Atomic architecture design](atomic-counter-choice-publication-architecture-design.md) | Accepted production command inventory, installed-flow policy, source and role checks, atomic ordering, live Network admission, transition matrix, and stop gates. |
| [Boundary A accepted workbook](interaction-flow-integer-reconstruction-repair-implementation-workbook.md) | Completed, committed, Owner-accepted state reconstruction. Four Counter identities remain mandatory at actionable `ATTACK_COUNTER_CHOICE`; do not duplicate or weaken this normalization. |
| [Boundary B stopped proposal](attack-publication-command-codec-integer-reconstruction-repair-proposal.md) | Preserve its partial command-codec, preflight, Escort, and test changes until separately audited for integration. Its Replay-12 stop is historical; the accepted architecture supersedes old-current compatibility expectations, not the evidence. |
| [BUG-074 accepted workbook](network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md) | Closure and Owner evidence remain historical. Preserve its three deferred GGS Counter replay variations in that assurance backlog. |

The package must not add a generic continuation owner, stack, transaction
framework, second FSM, gameplay family, or projection-owned decision. It must
not alter historical Replay-12 files, accepted hashes, baselines, or Owner
evidence. The separate non-flow `pos_x` precision finding and GGS-001 are
excluded. A different architecture or compatibility policy requires a new
Owner decision before code changes.

## 2. Entry gates and dependency order

| Gate | Required evidence before the next dependent stage |
| --- | --- |
| E0 — workbook authority | Independent audit and Owner workbook acceptance completed 2026-10-17. Separate explicit Owner implementation authorization remains required; acceptance alone does not resume Boundary B. Record the uncommitted Boundary B file/test diff and preserve it unchanged until authorized integration. |
| E1 — Boundary C prerequisite | A separately scoped, Owner-authorized `CurrentAttackState.resolved_outcome` JSON reconstruction repair is implemented and accepted. Genuine GameState JSON roundtrips restore native canonical Squadron `requested_hull_damage`, `actual_hull_damage`, and `post_resolution_hull` and any affected outcome members without unrelated full-state divergence. Zero, positive, and excess-over-remaining-hull values retain exact types and values. This package must not implement, hide, or silently normalize Boundary C. Until E1 passes, reconstructed Counter publication and full-state digest acceptance remain blocked. |
| E2 — version/fixture plan | Collision-check Save 11 / Network 12 / Replay 13 constants, exact state/command schemas, legacy rejection, current runner paths, hardcoded version assertions, and retained historical artifacts before changing a version. Identify the Owner's manual Hot-Seat, Network, and Counter replay capture obligations and the current-format acceptance inputs. No fixture changes occur at this gate. |
| E3 — incremental production gates | Each stage below passes its focused rejection, source, state, and digest proof before the next stage. A failed command leaves state, flow, inspections, history, sequence, and observer queue unchanged. |
| E4 — integrated evidence | Full suite converges after version-compatible genuine replays and reviewed baselines exist; focused and integration, both real-ENet role mappings, reconnect, replay, runner, and manual acceptance evidence all pass. The Owner alone accepts the final implementation. |

The recommended execution order is E0 → E1 → E2 → Stages A–E → Owner manual
recording → Stage F integrated verification → Owner implementation checkpoint.
Boundary C may be prepared independently, but no Counter or Boundary B
implementation may start from workbook acceptance alone or treat an unresolved
Boundary C hash as success.

## 3. Canonical decision ownership and distinguishability

The table implements the accepted DA-002 / CODEX_WORKFLOW ownership check.
Each witness must survive the supported save, replay, reconnect, and lost
follow-up boundaries. An atomically consumed decision needs no duplicate
surviving witness when the resulting canonical state determines every next
legal action.

| Decision | Authorized decision maker | Commitment command | Canonical owner and durable outcome | Recovery witness | Single-use consumption boundary | Acceptance and ordering guarantee |
| --- | --- | --- | --- | --- | --- | --- |
| Counter Accept/Decline | Entitled Counter Squadron player | Source-bound `CounterChoiceCommand` | Active parent `CurrentAttackState`: absent → `accepted` or `declined`; flow boolean is a mirror only. | Exact parent `attack_id`, disposition, and canonical Squadron eligibility. | With **I**, parent completion transfers witness; no-**I** Accept is consumed by atomic child Begin; no-**I** Decline by terminal completion. | Complete publication after accepted/broadcast damage, exact parent source and controller, one native boolean choice, no duplicate or premature completion. |
| Parent result acknowledgement | Required human principals | `AcknowledgeAttackResultCommand` | Legitimate inspection **I** with immutable source-scoped Counter witness and received principals. | **I** source, decision witness, required/received sets, and original activation owner. | Exact satisfied **I** consumed with child Begin for Accept or enclosing Squadron consumer for Decline. | No empty **I**, no acknowledgement-driven gameplay mutation, exact source and principal, atomic rejection. |
| Counter child and result inspection | Counter player controls ordinary child choices; required principals acknowledge **J**. | Source-bound Counter `BeginAttackCommand`, child commands, `CompleteAttackCommand`, then acknowledgement when **J** exists. | Active child `CurrentAttackState`; after completion, legitimate **J** when required, otherwise original Squadron route. | Child attack identity; **J** source/defender and satisfaction; retained original `SquadronInstance` activation. | **J** consumed by one legal Move, Move-decline, or terminal Squadron completion; no-**J** uses direct enclosing route. | Locked Declare, ordinary Roll, no second child, exact **J** consumption with mutation, and no final publication as retirement. |
| Enclosing Squadron/phase/Ship choice | Original Squadron controller and, where applicable, active phase or Ship controller. | Existing Move, Move-decline, `CompleteSquadronActivationCommand`, `AdvancePhaseCommand`, or `AdvanceActivationStepCommand`. | `SquadronInstance` action/activation facts, `GameState` phase progress, and commanding `ShipInstance` opportunity/count. | Those canonical owners, including retained destroyed original Squadron. | Each existing accepted command commits its action or completion once. | Destroyed original has no Move; phase advances only on exhaustion; Ship voluntary finish remains a live choice and is never synthesized by recovery. |

| Observable boundary | Distinguishable canonical state and legal continuation |
| --- | --- |
| Resolved parent before publication | Active resolved parent with absent disposition and canonical Squadron owners permits one complete publication, subject to faceup barrier; no choice is yet committed. |
| Published pending choice | Active parent disposition remains absent; complete source-matching flow exposes the one recoverable Counter decision. |
| Committed Accept versus Decline | Active parent disposition is native `accepted` versus `declined`; different retirement commands cannot converge to the same canonical state. |
| Parent retired with **I** | Parent is inactive; source-scoped **I** witness distinguishes child Begin from enclosing release through acknowledgement and lost-follow-up intervals. |
| No-**I** parent retirement | Accept's one command installs a distinct active Counter child and Declare; Decline's one command installs inactive parent plus enclosing Squadron route. There is no witness-free intermediate state. |
| Child completion with or without **J** | A legitimate **J** with source/defender/satisfaction persists until its consumer; without **J**, completion installs the original Squadron route. The parent's retired choice need not survive once both outcomes have the same legal enclosing behavior. |
| Original Squadron and enclosing return | Surviving or destroyed `SquadronInstance`, phase progress, and Ship opportunity/count uniquely identify a legal Move choice, terminal Squadron completion, phase exhaustion, automatic Ship exhaustion, or a stable voluntary Ship choice. A pending queue or flow cannot disambiguate them. |

## 4. Staged implementation package

### Stage A — exact state schema, versions, and recovery validation

After E1/E2, extend only the active parent `CurrentAttackState` with the
accepted source-scoped absent/accepted/declined disposition and legitimate
inspection **I** with an immutable matching witness. Preserve deterministic
inactive state and exact schema validation. Integrate a pure,
purpose-specific Counter consistency check after GameState has reconstructed
Attack, Squadrons, inspection, and flow. It checks source, roles, controller,
availability, BLUE pool, decision mirror, and Squadron `final_damage` against
native canonical `resolved_outcome.requested_hull_damage`. Reject missing,
malformed, negative, fractional, nonfinite, wrong-type, or inconsistent values;
never default to zero, cast a float, or use capped `actual_hull_damage`.
Installed **I** uses its validated Squadron result as the comparison witness
after the parent retires. Implement Save 11 / Network 12 / Replay 13 version
gates without migrating obsolete development saves or accepting mixed peers.

**Stage A exit:** exact direct/JSON state roundtrips, negative reconstruction,
pending/accepted/declined/**I** source checks, and canonical digest comparisons
pass where unrelated state is stable. Boundary A flow restoration continues to
pass unchanged. Any Boundary C or `pos_x` full-state difference is identified
at its first field and remains a stop, not a local Counter normalization.

### Stage B — stopped Boundary B codec integration and command admission

Audit the preserved Boundary B partial diff before editing it. Reuse its one
declared-integer command-codec policy for native integers and permitted
integral JSON floats; preserve accepted mixed strings, booleans, optional
fields, unknown passthrough, and Escort's narrowly authorized unused
`target_player` conversion removal. The pure publication-specific
container/integer/installed-Counter preflight runs before publication rule
hooks. `PublishAttackFlowCommand.validate()` then performs full owner and
semantic checks. Add the equally narrow pure `counter_choice` safe-shape and
exact-source prehook guard before the registered
`CounterKeyword.validate_counter_choice()` preflight hook can inspect or
coerce submitted data; full choice legality remains in
`CounterChoiceCommand.validate()`. Exercise direct submissions and genuine
JSON-decoded commands with malformed `accepted`, participant indices, and
nested Counter dice-pool values: non-boolean `accepted`, string/list or
fractional indices, wrong pool containers, and malformed nested `BLUE`
counts, including direct-only nonfinite values. Reject these before hook
invocation or side effects without changing the submitted payload. Direct and JSON
wrong-container, malformed integer, stale source, duplicate, downgrade,
replacement, and premature-final commands reject atomically. Do not copy
Boundary A's state normalization into this codec.

**Stage B exit:** focused direct/JSON codec and execution tests, Coolant
Discharge, Escort, and registered Counter preflight-hook safety, including
malformed `accepted`, participant-index, and nested dice-pool specimens; exact
flow hash on valid reconstruction; and proof that rejection precedes hook
side effects with no canonical state/flow, history, sequence, or observer
follow-up queue change. The obsolete Replay-12 sequence 58 is never admitted
as a current complete Counter publication.

### Stage C — atomic ordered publication and secure live Network origin

At the accepted `ResolveDamageCommand` boundary, remove every
Counter-eligible preacceptance or callback-driven local flow mutation and
publication, including `final_damage` patches and nested submissions.
Construct one detached complete Counter candidate from the resolved parent,
canonical Squadrons, and legal same-source installed predecessor, with
`final_damage` equal to validated **requested** Squadron hull damage even when
greater than actual applied damage. Select one post-success follow-up, with
no competing parent completion. Damage execution/history and live Network
broadcast precede dependent publication submission/broadcast in both role
mappings. Reject client-originated Counter-step publication at live Network
ingress and host player-route submit; allow only trusted host-generated
authoritative submission. Separate recorded replay execution retains ordinary
deterministic command validation. Preserve all other valid publication and
unknown-field behavior.

**Stage C exit:** zero, positive, and excess-damage publication proof; no
incomplete Counter flow at any observable boundary; direct/JSON and hook
rejections; accepted damage-before-publication ordering on both real role
mappings; passive applies once and never originates publication. Lost
publication is re-derived once from canonical owners.

### Stage D — single-use choice, semantic retirement, and child

The production `AttackExecutor._on_counter_attack_requested()` and
`_on_counter_attack_skipped()` paths and
`AttackPanelMirror._submit_counter_choice()` must obtain the exact active
parent `CurrentAttackState.attack_id`, compare it with the complete installed
Counter flow, and pass it through `GameManager.submit_counter_choice()` into
the submitted command. Submission context uses canonical source and Squadron
identities rather than retained scene tokens; Stage E proves the recovered
UI path after reconstruction and board reload. `CounterChoiceCommand`
validates that exact source on the real UI, direct-command, and JSON-command
paths.

`CounterChoiceCommand` commits disposition once through the existing Attack
value-install seam, mirrored to flow. A decided parent with legitimate **I**
transfers its witness at one `CompleteAttackCommand`; Accept retains the
Counter projection until source-bound child Begin, while Decline installs the
enclosing Squadron route. No-**I** Accept uses one Counter-only
`BeginAttackCommand` to replace the still-active parent with child/Declare;
no-**I** Decline completes and installs the enclosing route. Prevent final
publication from clearing these semantic states. After child Begin, the
existing Network Roll projection follow-up derives from installed
child/Declare, not retired parent flow. Child uses locked Declare and ordinary
Roll/attack rules. Its completion creates legitimate **J** only when required;
otherwise it installs the enclosing route.

**Stage D exit:** direct/JSON and real UI Accept/Decline through both
`AttackExecutor` and `AttackPanelMirror` into `GameManager` pass with an
already presented legal Counter choice; each submission carries and validates
the exact parent `attack_id`. This gate does not depend on `GameBoard` reload
or `AttackExecutor.resume_current_attack()` recovery. Both **I** and no-**I**
paths, stale/duplicate/premature rejection, child locked Declare/Roll,
inspection witness JSON, and command-boundary atomicity pass.
At every interruption, two outcomes needing different next commands have
different canonical witnesses. No artificial inspection or generic owner is
introduced.

### Stage E — exact-once release and composed-return recovery

Share the purpose-specific owner predicates used by post-success and live
reconstruction. Evaluate faceup barrier, active parent, satisfied **I**/**J**,
original Squadron action/completion, then Squadron Phase or Ship Squadron
Command. On `GameBoard` ready/reload, its
`AttackExecutor.resume_current_attack()` path must recover a complete,
source-matching pending Counter choice from canonical parent and Squadron
owners. It must preserve the pending choice and its exact parent source rather
than replace the installed Counter projection with Resolve Damage. Consume an
inspection only with its authorized semantic consumer.
Retain the original Squadron's activation even when Counter child damage
destroyed it; its Move is illegal and terminal Squadron completion consumes
**J** once when present. Validate Squadron-to-Status exhaustion for both
canonical empty shapes; recover lost automatic phase/Ship advances. Where a
Ship command still has capacity and an eligible Squadron, preserve the live
select-or-voluntary-finish decision and never auto-finish it. Passive/replay
submit no derived continuation. Continue through existing enclosing owners to
a recoverable live decision or stable state.

**Stage E exit:** after genuine GameState JSON reconstruction of a pending
choice, `GameBoard` reload through `AttackExecutor.resume_current_attack()`
preserves the source-bound Counter decision without Resolve Damage
replacement or a second publication. End-to-end real UI Accept and Decline
through `AttackExecutor` and `AttackPanelMirror` into `GameManager` submit and
validate the exact parent `attack_id` after that reload. Both role mappings,
**I**/**J** and no-inspection paths, surviving/destroyed Counter attacker and
destroyed original activating
Squadron, Squadron Phase and commanded-Squadron contexts, lost observer
follow-ups, interruption, Save/reconnect, replay non-synthesis, and exact-once
composed return pass. No ownerless intermediate or duplicate child exists.

### Stage F — integrated compatibility and acceptance verification

After Stages A–E, request the Owner's genuine manual Replay-13 Hot-Seat,
Network, and Counter recordings. The Counter recording may double as a
baseline only if the baseline coverage and provenance requirements are met.
Retain all old Replay-12 inputs, BUG-074 evidence, traces, and hashes as
historical artifacts. Do not synthesize, transform, re-sign, relabel, or
mechanically migrate a replay. The Owner controls approval of any replacement
expected trace/hash after first-field diagnosis.

Update `scripts/run_baseline_traces.sh --all` and
`scripts/run_network_resume_acceptance.sh` to consume required Replay-13
inputs, including the Network compatibility replay; a missing current replay
must fail rather than skip. Update
`tests/acceptance/network_resume/assertions.gd` and other direct assertions
for Save 11 / Network 12 / Replay 13. Preserve the existing runner roles:
Hot-Seat command trace and final hash comparison; Network host/client final
hash convergence; real ENet handshake, filtered snapshot, role assignment,
resume/reconnect, ordered replay, and Counter variants. Require both
`--counter-only` and full Network resume runs as applicable, plus the complete
repository test suite and `git diff --check`/documentation checks. If any
version-compatible baseline or full-suite test fails, classify the first
cause and rerun after an authorized correction; no fixture or hash promotion
may turn an unexplained failure into a pass.

**Stage F exit:** focused, integration, recovery, baseline, full suite, both
real-ENet role mappings, and replay tests all pass on current-format inputs;
all assertions use the current version policy; canonical full-state digests
converge after any independently classified reconstruction defect is
separately resolved;
Owner manual gameplay and recording provenance are logged. Independent
implementation audit then precedes the explicit Owner acceptance checkpoint.

## 5. Verification matrix and manual evidence

| Gate | Minimum proof |
| --- | --- |
| State and choice | Native absent/accepted/declined, source ID, direct/JSON and real UI Accept/Decline through `AttackExecutor`, `AttackPanelMirror`, and `GameManager`: Stage D proves an already presented legal choice; Stage E repeats end-to-end after pending-choice JSON reconstruction and `GameBoard` reload. Exact parent `attack_id` propagation, Attack/Counter roles and pool, no duplicate, stale source, or projection-only decision; full-state JSON at each active-parent and **I** boundary. |
| Damage/publication | Zero, positive, and requested damage exceeding remaining hull; native requested integer, exact published `final_damage`, malformed/missing/float canonical rejection, legal predecessor, one complete publication, callback silence, damage broadcast before publication. |
| Inspection and child | Legitimate **I** witness, no empty **I**, no-**I** atomic replacement/Decline route, locked child Declare and ordinary Roll, **J** only when required, source-matched acknowledgement and single-use consumption. |
| Recovery and composed return | Save/load and reconnect at every matrix row; `GameBoard` reload → `AttackExecutor.resume_current_attack()` preserves the source-bound pending Counter choice and does not replace it with Resolve Damage; killed automatic follow-up, surviving/destroyed Counter attacker, destroyed original activating Squadron with/without **J**, legal Move or terminal completion, Squadron Phase exhaustion, Ship voluntary finish versus automatic exhaustion, final stable state. |
| Security, replay, compatibility | Direct and genuine JSON malformed publication/choice commands with Coolant Discharge, Escort, and registered Counter preflight hooks; malformed `accepted`, participant indices, and nested dice-pool values reject before hook side effects with state/flow, history, sequence, and follow-up queue unchanged; client-originated Counter publication rejected in both mappings; trusted host publication accepted; Replay-13 ordered execution and version rejection; Save-10 ambiguity and Network-11 mixed-peer rejection; unchanged historical evidence. |
| Baseline and manual checkpoint | Genuine Owner-recorded replacement Hot-Seat/Network/Counter replays with provenance; current baseline runners and assertions; first-field comparison of changed trace/hash; full suite, real ENet, reconnect, and manual host/client gameplay smoke. Owner separately accepts implementation and evidence. |

The accepted design's [complete transition matrix](atomic-counter-choice-publication-architecture-design.md#23-complete-counter-transition-matrix-proposed-contract)
is the per-command test inventory. Every rejected direct or JSON command must
preserve canonical state, flow, inspection, command history, next sequence,
and observer follow-up queue. For aggregate hashes, prove unrelated state
stable first; report a Boundary C or position-precision difference separately
and stop the affected aggregate claim. A passing command trace or equal peer
hash alone is insufficient.

## 6. Mandatory STOP conditions

Stop the dependent stage and report a concrete first failing command/state
field if any of the following occurs:

1. E0 or E1 lacks separate Owner acceptance/authorization, Boundary C remains
   unresolved, or the stopped Boundary B partial diff cannot be integrated
   without changing its accepted integer/mixed-field policy.
2. A Counter choice, disposition, **I** witness, **J** release, or enclosing
   decision depends on `InteractionFlow`, scene state, replay history, callback,
   or an in-memory queue rather than its accepted canonical owner; a UI
   submitter omits or changes the exact parent source; or board reload replaces
   a pending Counter choice with Resolve Damage.
3. A precommit or callback flow write exposes incomplete Counter choice;
   damage publication overtakes its accepted/broadcast parent; live client
   publication passes host admission; or replay requires a different
   deterministic legality rule.
4. An authorized semantic retirement cannot atomically transfer or consume
   its witness and install the child or enclosing route; a rejected command
   changes state/history/sequence/queue; or recovery creates a duplicate
   choice, publication, child, inspection consumption, or phase/Ship advance.
5. Squadron `final_damage` uses capped actual damage, missing/malformed
   requested damage is coerced, JSON reconstruction changes a canonical
   outcome type, or a full-state hash differs without first-field diagnosis.
6. A current baseline uses Replay-12, a runner skips a required Replay-13
   input, hardcoded Save-10/Network-11/Replay-12 assertions remain, a replay
   is automatically recorded/transformed, or historical fixture/hash/evidence
   is overwritten.
7. Full-suite, real ENet, reconnect, replay, baseline, or manual evidence
   fails; required proof is waived; an unapproved new owner, architecture,
   format behavior, or compatibility migration is needed; or actual plus
   forecast exceeds the Owner-approved economic limit.

The accepted design estimates roughly **12–16 implementation days plus 12–16
focused, integration, Network, replay, and compatibility verification days**
for the integrated package, excluding separately authorized Boundary C work,
manual Owner recording, and independent audits. This is a forecast, not a
budget authorization. Any material increase requires review before dependent
work continues.

## 7. Status and Owner checkpoints

**Owner acceptance — 2026-10-17:** Following successful independent
architecture and implementation-readiness audits, the Project Owner accepts
this consolidated workbook as the controlling implementation specification
for the atomic Counter lifecycle refactoring and integration of the stopped
Boundary B command-codec repair. The Owner accepts its staged plan,
dependencies, verification gates, Save 11 / Network 12 / Replay 13
compatibility policy, and mandatory STOP conditions.

This acceptance does **not** authorize implementation. Boundary A remains
complete; Boundary B's partial implementation remains **STOPPED** and
preserved. Boundary C requires a separately authorized repair and Owner
acceptance before integrated work. The Owner must manually record replacement
replay fixtures through genuine application execution; historical evidence
remains unchanged. Separate explicit Owner implementation authorization is
required. After authorized implementation, the Owner reviews any new oracles
and separately accepts final implementation and manual evidence.

**Stage A implementation direction — 2026-10-18:** The Owner separately
authorized E2 and then Stage A only. E2 passed before production changes; its
version, runner, assertion, historical-artifact, and genuine Owner-recording
inventory is in the [E2 implementation-entry record](../evidence/atomic-counter-stage-a-e2-entry-record.md).
Stage A implementation and focused evidence are recorded there for a separate
Owner acceptance checkpoint. Boundary B's uncommitted partial work remains
stopped and preserved. Stages B–F and replacement fixture recording remain
unauthorized by this direction.

**Stage A acceptance and Stage B direction — 2026-10-18:** The Owner accepted
the Stage A implementation and authorized Stage B implementation under this
workbook. Stage B may review and reuse the preserved Boundary B partial work;
its command admission, validation, hook-safety, and atomic-rejection exit gates
remain binding. Stages C–F, fixture recording, and baseline promotion remain
unauthorized. The [E2 implementation-entry record](../evidence/atomic-counter-stage-a-e2-entry-record.md)
separates completed Stage A assertion updates from later-stage obligations and
inventories the immutable BUG-074 diagnosis replay.

**Stage B implementation checkpoint — 2026-10-18:** Focused command admission,
codec, owner-consistency, installed-flow, source-bound choice, hook-safety,
and rejection-atomicity verification passed. The
[Stage B implementation evidence](../evidence/atomic-counter-stage-b-implementation-evidence.md)
records exact results and the later-stage full-suite failures. At that
checkpoint Stage B awaited independent audit and Owner acceptance; Stages C–F
were unauthorized.

**Stage B Owner acceptance and Stage C direction — 2026-10-18:** The Owner
accepted Stage B after independent audit PASS and closed predecessor-consistency
blocker B-1. The accepted Stage A/B implementation and evidence are committed
in `e7f48fe`. The Owner separately authorized Stage C under this workbook:
atomic ordered Counter publication and trusted live Network origin only.
Stages D–F remain unauthorized; no replay fixture, baseline, hash, or
historical Owner evidence promotion is authorized.

**Stage C implementation checkpoint — 2026-10-19:** The bounded atomic
publication, authoritative Network origin, and damage-before-publication
implementation and focused verification are recorded in the
[Stage C implementation evidence](../evidence/atomic-counter-stage-c-implementation-evidence.md).
Stage C awaits independent audit and Owner acceptance. Stages D–F remain
unauthorized; the existing full Counter ENet scenario and deferred full-suite
failures remain assigned to their later-stage gates.

**Stage C Owner acceptance and Stage D direction — 2026-10-19:** The Owner
accepted Stage C following independent audit PASS and separately authorized
Stage D under this workbook: source-bound single-use Counter choice, semantic
parent retirement, inspection **I**/**J** boundaries, and atomic child Begin.
The [Stage C evidence](../evidence/atomic-counter-stage-c-implementation-evidence.md)
records the corrected related-suite assertion count and the separate
mapping-1 ENet rerun provenance. Stages E/F remain unauthorized. No replay
fixture, baseline, hash, or historical Owner evidence promotion is authorized.

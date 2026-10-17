# Atomic Counter-Choice Publication — Architecture Design

Status: **Architecture ACCEPTED by Project Owner on 2026-10-17 after independent
acceptance audit and targeted re-audit; implementation NOT AUTHORIZED.**
Boundary B remains stopped and its partial implementation is preserved. This
design records the Project Owner's accepted direction to prefer future canonical
atomicity over compatibility with obsolete development replay histories. It
does not reopen BUG-074 acceptance or authorize production implementation,
fixture recording, or promotion. The dated normative amendments to ADR-007,
CON-001, CON-007, and Counter requirements implement its accepted architecture.
Scope: BC-009 / AT-008 and the Counter parent
publication/recovery seam only.

**Owner decision and audit correction:** The Owner accepted Option B: the active
parent `CurrentAttackState` owns the source-scoped absent/accepted/declined
Counter disposition; `InteractionFlow` is projection only. The earlier draft treated presence of
`InteractionFlow.payload.counter_choice_accepted` as the decided marker. That
would make projection the sole owner of a semantic decision and contradicts
ADR-001 and ADR-010. Sections 2 and 4 specify the accepted retirement
handoff. The Owner accepted preservation of the decision in a legitimate
inspection **I** through the narrow ADR-007 amendment. This architecture
acceptance does not authorize implementation.

## 1. Authority and chosen invariant

[ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
keep attack facts in `CurrentAttackState` and command-owned semantic mutation;
`InteractionFlow` and scene FSMs are routing/projection, not competing attack
owners. [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md)
requires an equivalent legal Counter decision after supported reconstruction.
[CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md)
preserves the existing inspection/child/composed-return order and prohibits
passive or replay synthesis. [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md)
and [ADR-013](../adr/ADR-013-passive-network-damage-state-representation.md)
require canonical Network reconstruction and ordered passive application.
The accepted [Counter requirements](../../requirements/gameplay_interactions/counter_attack_interaction.md)
retain locked child Declare, ordinary Roll, and enclosing return.

**Accepted canonical publication invariant:** For one active parent attack
source, entry into `ATTACK_COUNTER_CHOICE` installs one complete, source-scoped
flow through one accepted `PublishAttackFlowCommand` in live play. Before its
command is submitted or any authoritative, passive, saved, or replay-reconstructible
`GameState` can show that step, the payload
contains `counter_attack_available == true`, the valid Counter controller,
canonical Counter dice pool, all four exact participant identities, and the
matching parent `attack_id`; the outer controller resolves to that same
Counter player. No incomplete Counter-choice flow/publication is externally
observable or recoverable. Missing, partial, malformed, stale, or inconsistent
Counter data fails closed before this step becomes visible. No additional
readiness flag, continuation owner, FSM, or command type is proposed. The
minimum canonical disposition and its format consequences are assessed below.

This preserves the accepted [Boundary A](interaction-flow-integer-reconstruction-repair-implementation-workbook.md)
rule: every reconstructed `ATTACK_COUNTER_CHOICE` requires the four valid
identities. The prior [intermediate-publication checkpoint](../evidence/boundary-b-counter-intermediate-publication-architecture-proof-checkpoint.md)
remains historical diagnostic evidence; its proposed exception for an inert
identity-free Counter step is **not** selected.

## 2. Canonical ownership proof and architecture alternatives

### 2.1 Production state at interruption boundaries

`CounterChoiceCommand.execute()` currently writes the choice only into
`InteractionFlow.payload`. The active `CurrentAttackState` has no Counter
decision field; its resolved stage, outcome, participants, and the Squadron
models are identical after Accept and Decline. `CompleteAttackCommand.execute()`
replaces it with the strict deterministic inactive value.
`CompletedAttackInspection` contains source, participants, attack kind, result,
and acknowledgement sets, but no choice. Command history is recorded for
ordered replay, not embedded in `GameState.serialize()` or a canonical
save/reconnect owner. A destroyed Counter Squadron remains model-resolvable;
destruction does not reveal whether its player accepted Counter.

| Situation | Existing canonical facts distinguish it? |
| --- | --- |
| Opportunity pending | Yes: resolved, eligible non-Counter Squadron parent and canonical Squadron models. Publication may still be outstanding; routing is not opportunity authority. |
| Accepted versus declined | **No.** Both leave the same canonical parent and Squadron facts; only flow and command history distinguish them today. |
| Parent completed | Only partly: the current attack is inactive and, when required, inspection **I** names the completed source. **I** does not identify the prior choice. With no required human principal, no inspection exists and inactive state does not identify which parent completed. |
| Counter child begun | Yes: the new active attack has Counter kind and reversed participants. It does not recover the vanished parent choice in the completion-to-child interval. |

### 2.2 Options and recommendation

**A — derive disposition solely from existing canonical facts:** Before choice,
eligibility is derivable. After choice, no accepted canonical fact changes, so
Accept and Decline collapse to the same state. `CompleteAttackCommand` cannot
enforce single use; inspection **I** cannot select child versus ordinary
release. Reading flow, command history, scene state, or an in-memory follow-up
would create path-dependent authority. Reusing an unrelated attack, damage, or
Squadron field merely hides new mutable state in the wrong owner. **Option A
fails** interruption after either choice, Save/Load, Network reconnect, and
the destroyed-Counter-attacker case.

**B — minimum source-scoped disposition (Owner selected):** During the active parent,
`CurrentAttackState` owns one optional purpose-specific disposition: absent
means no choice has committed; native `accepted` or `declined` means one has.
The existing `attack_id` scopes it; eligibility and pool remain derived from
the Attack and Squadron owners. `CounterChoiceCommand` alone commits it through
the validated `GameState.set_current_attack_state()` replacement path.
`InteractionFlow.counter_choice_accepted`, if retained for UI, becomes a
one-way derived mirror and is never read for legality, completion, or recovery.
This is an attack continuation decision, not a rule-owned mutable resource.

On completion, B requires **sequential ownership transfer**. If inspection
**I** exists, `CompleteAttackCommand` must atomically copy the immutable
source-scoped decision witness to a narrowly extended inspection and retire
the parent. **I** is then the sole post-completion witness until consumed.
This is the narrow Owner-accepted exception to
[ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md)'s
ordinary result/acknowledgement content rule, recorded in its dated atomic
Counter amendment. It does not reclassify the choice as an ordinary result
fact or authorize a generic continuation descriptor.

If there are **no required inspection principals**, ADR-007 forbids an empty
inspection. The existing `BeginAttackCommand` can be narrowly specified as a
**Counter-only semantic replacement**: with no **I**, its source-matching
accepted parent remains active until that one replayable command retires it
and installs the child. This uses CON-001-LIFE-010, not
`CompleteAttackCommand` followed by a witness-free inactive interval.
Its validated command intent must carry the exact parent `attack_id`;
that intent is not a persisted state owner. The current Begin validation and
execution do **not** support this path, so CON-001/CON-007 and the Counter
requirements must explicitly authorize the narrow replacement. Decline uses
ordinary `CompleteAttackCommand` to retire the parent and returns through
the enclosing Squadron owner. The dated CON-001/CON-007 and Counter
requirements amendments authorize only this narrow future behavior.
Retaining the disposition in inactive
`CurrentAttackState`, inventing an empty **I**, or relying on a queue/flow is
prohibited.

**Accepted architecture:** Implement the Owner-selected B only under a
separately accepted consolidated implementation workbook and authorization.
There is one decision owner at a time: active parent; then legitimate **I**
when one exists; then no surviving parent decision after authorized child
entry or ordinary release. The ADR-007 and CON-001/CON-007 amendments are
accepted; implementation remains stopped.

| Concern | A: existing facts only | B: source-scoped disposition |
| --- | --- | --- |
| Canonical owner | None for a committed choice; Attack/Squadron owners prove only eligibility. | Active `CurrentAttackState`; after atomic completion, inspection **I** alone where required. |
| Commit command | Current `CounterChoiceCommand` would have no accepted canonical fact to mutate. | `CounterChoiceCommand` validates and installs a replacement active Attack with `accepted` or `declined`; flow update is a derived mirror. |
| Single use and completion | Cannot distinguish already chosen from still pending or choose child versus ordinary completion. | Canonical absence gates the first choice; decided value gates exactly one parent completion, whose source ID is checked. |
| **I** and child Begin | **I** identifies a completed parent but contains no choice, so child entry cannot be derived. | Completion transfers one immutable witness to **I**; exact satisfaction and source check permit child Begin for Accept, ordinary release for Decline; consumer atomically retires **I**. |
| Save/Load and Network | Snapshot/reconnect lose the choice; replay history alone cannot repair a mid-game snapshot. | Reconstruct the active disposition or inspection witness before projection; host alone derives missing follow-ups, passive client mirrors recorded commands. |
| Recovery after Accept/Decline | Both recover as the same state, including when the Counter Squadron was destroyed. | Accept/Decline recover separately from canonical state; destroyed Squadron remains a valid model reference, not an alternate decision signal. |
| Compatibility and proof | No schema change, but cannot pass decision-equivalent recovery. | Exact serialized schemas and hashes change; test fail-closed obsolete states, direct commands, accepted Save 11 / Network 12 / Replay 13 gates, interruption at every handoff, and no-inspection atomicity. |

### 2.3 Complete Counter transition matrix (proposed contract)

Each row names an observable accepted-command boundary, or a stable decision
between commands. The listed owner, not the flow, determines the next command.
The live host/Hot-Seat authority may re-derive a missing automatic command
after Save/Load or reconnect; passive Network and replay apply only recorded
commands. **I** is a legitimate parent inspection and **J** a legitimate child
inspection, each created only when it has required principals. The current
implementation does **not** satisfy the proposed choice, retirement,
destroyed-Squadron, or lost-follow-up rows.

| Transition | Canonical owner and precondition | Observable command boundary and postcondition | Reject before mutation | Decision-equivalent recovery |
| --- | --- | --- | --- | --- |
| Parent damage resolution | Active parent `CurrentAttackState`; source-matching legal damage command and retained Squadron activation. | `ResolveDamageCommand` installs resolved outcome and records one sequence; Counter disposition absent. Its callback changes presentation only. | Duplicate damage, wrong source, inactive parent, nested callback flow publication. | Resolved parent and Squadron models re-evaluate Counter eligibility; no callback-owned state is needed. |
| Counter unavailable after damage | Resolved parent and canonical Squadron owners show no eligible Counter (including destroyed target). | Ordinary `CompleteAttackCommand` follows existing attack completion and inspection rules; no Counter publication. | False Counter publication or fabricated child/decision. | Existing resolved-attack/inspection evaluator re-derives ordinary completion or stable pending legal decision. |
| Counter eligibility and publication | Resolved eligible non-Counter Squadron parent, surviving Counter target, canonical Counter Squadron and disposition absent; installed route passes Section 2.5. | Only after damage acceptance and, in Network play, its broadcast, one trusted host/Hot-Seat `PublishAttackFlowCommand` installs complete source-matching `ATTACK_COUNTER_CHOICE`; replay applies its recorded command. | Partial/false/malformed identities, pool or owner mismatch; live peer-originated Counter publication; duplicate, downgrade, stale replacement, premature final clear. | Before publication, live authority re-derives one complete candidate; after publication, pending choice is stable. Passive/replay synthesize none. |
| Counter Accept or Decline | Active resolved parent disposition absent, complete consistent installed Counter flow, exact `attack_id` in command and flow, entitled Counter controller. | `CounterChoiceCommand` commits native `accepted` or `declined` in that parent; flow boolean mirrors it. | Missing/wrong/old source even with same participants, duplicate choice, mismatched identities/controller, flow-only marker, missing publication. | Parent disposition determines exactly one matching retirement transaction; lost queue is re-derived. |
| Parent retirement with **I** | Decided active parent; legitimate nonempty required-principal set. | `CompleteAttackCommand` copies immutable decision witness to **I**, makes parent inactive; Accept retains Counter route, Decline installs enclosing Squadron route atomically. | Undecided parent, wrong source, inspection already present, direct final Counter publication. | Unsatisfied **I** is an acknowledgement decision; after satisfaction, its witness selects child Begin or enclosing release. |
| Parent retirement, no **I**, Accept | Decided active parent `accepted`; no required principals; exact parent source and child eligibility. | One Counter-only `BeginAttackCommand` replaces active parent with child and installs child Declare; no inactive interval. | `CompleteAttackCommand`, missing/stale source, premature or duplicate Begin. | Before Begin, retained decided parent re-derives that exact command; afterward child owns its own attack. |
| Parent retirement, no **I**, Decline | Decided active parent `declined`; no required principals and unique enclosing Squadron activation. | `CompleteAttackCommand` makes parent inactive and installs the enclosing Squadron route in the same command. | Counter Begin, standalone final clear, missing/wrong enclosing owner. | Squadron action facts plus route select a stable Move decision or one completion; lost follow-up is re-derived. |
| **I** acknowledgement and Accept release | Legitimate source-matching **I** witness `accepted`; exact required principals received. | `AcknowledgeAttackResultCommand` only satisfies **I**; then source-bound `BeginAttackCommand` consumes **I** and installs child plus Declare atomically. | Unsatisfied/wrong **I**, Decline witness, second Begin or acknowledgement. | Satisfied **I** re-derives one Begin; consumed **I** cannot release twice. |
| **I** acknowledgement and Decline release | Legitimate source-matching **I** witness `declined`; exact required principals received; original Squadron activation retained. | Acknowledgement only satisfies **I**; the applicable Move, Move-decline, or `CompleteSquadronActivationCommand` consumes it atomically. | Counter Begin, premature release, wrong inspection or activation. | Satisfied **I** re-evaluates enclosing Squadron legality; a legal Move is a stable choice. |
| Counter child attack | Child `CurrentAttackState` and original `SquadronInstance`; parent decision and **I** retired. | Accepted child Begin installs Declare, then ordinary locked Declare, Roll, damage, and completion commands run. | Second parent child, unlocked declaration, parent Counter publication replacement. | Child attack and existing timing owners reconstruct; Network Roll projection follow-up is re-derived once. |
| Child completion with **J** | Resolved child; legitimate nonempty required-principal set; original Squadron activation retained even if destroyed. | `CompleteAttackCommand` makes child inactive, creates **J**; acknowledgement satisfies **J** without release. | Enclosing Move/completion before satisfaction; duplicate child completion. | **J** source and defender identity plus original Squadron owner re-derive exactly one authorized release. |
| Child completion, no **J** | Resolved child; no required principals; unique original Squadron activation. | `CompleteAttackCommand` makes child inactive and installs enclosing Squadron route atomically; no inspection. | Stale child Attack route, final publication as sole cleanup, synthetic **J**. | Squadron action facts and route re-derive a missing completion or preserve a legal Move decision. |
| **J** release, original Squadron survives | Satisfied **J** with child defender equal to unique active original Squadron. | Legal Move or Move-decline consumes **J**; if no legal Move, `CompleteSquadronActivationCommand` consumes **J** and marks activation complete. | Wrong defender/source, duplicate consumption, completion while legal action remains. | **J** stays until its one consumer commits; then Squadron owner and context determine enclosing return. |
| **J** release, original Squadron destroyed | Same satisfied **J** and retained original Squadron identity/context; `is_destroyed()` makes legal Move false. | One `CompleteSquadronActivationCommand` with exact **J** ID consumes **J** and marks the original activation complete. | Move, Move-decline, abandonment because defender died, wrong/duplicate **J**. | Satisfied **J** re-derives this completion after interruption; failure leaves **J** and activation unchanged. |
| No-**J** release, original Squadron destroyed | Child inactive; original destroyed but retained with active activation/action facts; enclosing route installed. | One `CompleteSquadronActivationCommand` without inspection ID marks original activation complete. | Move, Move-decline, synthetic inspection, duplicate completion. | Live/reconstructed owner evaluator re-derives completion if its follow-up was lost. |
| Squadron Phase return | `SquadronInstance` activation complete; `GameState` phase controller/count own turn progress. | Completion installs `WAIT_FOR_SQUAD_SELECT` and commits controller/count; only when both sides have no surviving unactivated Squadrons, existing `AdvancePhaseCommand` moves to Status. | Second completion, stale controller, phase advance with eligible Squadron, active activation/inspection/attack, invalid phase progress, passive/replay auto-submit. | Stable next selection; exhaustion may have inactive progress after a last completion or active initial progress with zero eligible Squadrons. Both live-only paths re-derive one phase advance. |
| Ship Squadron Command return | `SquadronInstance` complete; commanding `ShipInstance` identity, capacity, committed count, and eligible remaining Squadrons own command progress. | Completion installs `SHIP_ACTIVATION/SQUADRON_STEP`. Capacity exhausted or no eligible Squadron derives existing `AdvanceActivationStepCommand(repair_step)`; otherwise the player's selection **or voluntary finish** is stable. | Stale ship/activation, second completion, automatic finish while eligible choice remains, duplicate advance after opportunity consumed. | Shared pure evaluator re-derives only an automatic lost advance; with eligible Squadron, it waits for explicit player finish, never invents that decision. |

All rows require direct-command and genuine JSON/replay command decoding tests
at the relevant boundary. Rejection must leave canonical GameState (including
flow and inspections), command history, sequence, and observer follow-up queue
unchanged. Replay consumes only accepted recorded commands; old development
recordings are historical evidence, not an exception to these guards.

For **I** paths, `CompleteAttackCommand.execute()` creates the legitimate
nonempty inspection with its witness before retiring the parent; the one
accepted command is the handoff. The witness is immutable, keyed by existing
`source_attack_id`, and may have only `accepted` or `declined` values for an
eligible Counter parent. It is not a generic continuation descriptor.
`AcknowledgeAttackResultCommand` changes only received principals. For a
declined **I**, the exact accepted Move/Move-decline/activation-completion
consumer retires **I**; for an accepted **I**, Counter Begin does so.

For no-**I** Accept, `CurrentAttackContinuation` and the existing
`GameManager.release_reconstructed_completed_attack_inspection()` live-only
seam must derive the same source-bound Counter Begin from the still-active
decided parent. The command's Counter-only validation branch must require:
`completed_attack_inspection_id` empty, no installed **I**, exactly matching
`counter_source_attack_id`, resolved damage/outcome, native `accepted`
disposition, legal Counter participants/dice/target, and no live attack timing
window. It must reject a different source even if the same Squadron pair can
attack again later. The command prepares the complete child and validates all
adjacent owners before one semantic replacement through the existing
`GameState.set_current_attack_state()` value-install seam. Parent rule-runtime
cleanup and replacement of the parent projection with child Declare belong to
that accepted transaction. If any step can fail after retirement, the exact
parent and adjacent owners must remain unchanged; the current Begin rollback
to *inactive* is not valid for this branch. No generic transaction framework
or persisted handoff fact is needed. Because the child has a distinct
sequence-derived `attack_id`, replay and passive peers apply the same one
replacement command. `CommandProcessor._enqueue_counter_begin_publication()`
must then inspect the accepted child and its Declare projection, rather than
the vanished parent Counter-choice flow, before queuing the existing Network
Roll publication. This is a derived projection follow-up, not a second child
Begin or decision owner.
The parent choice belongs to the Counter Squadron's player; parent completion
belongs to the original attacker; child Begin belongs to the Counter
Squadron's player. In either Network role mapping, the host's existing
authoritative follow-up submission must carry that child player index without
granting the passive client command-generation authority. The same actor
mapping applies to **I**-backed child Begin after acknowledgement.

For no-**I** Decline, `CompleteAttackCommand` remains terminal completion under
CON-001-LIFE-009. It must atomically replace the source-matching Counter
projection with the canonical enclosing Squadron route when it retires the
parent; today's later queued final publication cannot be the sole cleanup,
since Save/reconnect may observe and lose that queue. The same route replacement
is required for Decline with **I** (the inspection still blocks progression)
and for Counter-child completion with no **J**. An empty flow is insufficient:
`derive_reconstructed_cancelled_attack_return()` currently requires
`SQUADRON_ACTIVATION/ACTION_CHOICE` or
`SHIP_ACTIVATION/SQUADRON_STEP` before it can recover automatic Squadron
completion. The terminal-publication collector must not issue a duplicate
clear for these branches. The following decision or automatic completion is
re-derived from retained Squadron action facts at the live and reconstructed
authority seams. The route identifies the applicable context, never the
retired Counter disposition. If those facts do not uniquely select the next
action, implementation stops before adding a new owner.

The same matrix covers a destroyed *eligible Counter attacker*: its
`SquadronInstance` remains addressable and Counter value is derived from that
model; ordinary destroyed-squadron selection is still prohibited. The parent
attacker is the Counter target and must remain alive. A destroyed or missing
Counter target, wrong source/role mapping, unexpected extra **I**, or
inconsistent projection rejects before choice, completion, or Begin mutation.
The no-**J** child completion is the same no-human-principal terminal
projection/return seam, scoped here to the Counter child; it creates no
inspection and stores no parent decision. If the existing Squadron activation
facts cannot recover its next decision or automatic completion, this design
stops rather than adding a continuation field.

### 2.4 Destroyed original Squadron and enclosing return

The original activating Squadron is the Counter child's defender. Damage can
destroy it, but its roster object and `activation_id`, context, and
`ATTACK_ACTION_BEGUN` remain canonical until activation completion;
`GameState.get_active_squadron_activation()` still finds it. Destruction is
not a reason to lose the return. `MoveSquadronCommand` and
`DeclineSquadronMoveCommand` already reject destroyed squadrons, while
`GameState.has_legal_remaining_squadron_move_action()` currently omits that
check. Add `is_destroyed()` to this owner-local legal-Move query, so no Move
opportunity can appear and `is_squadron_activation_action_complete()` agrees
with command legality. Do not write a fictitious Move-declined disposition.

With **J**, remove only the destroyed-Squadron exclusion from
`CurrentAttackContinuation._derive_counter_child_inspection_release()`;
retain exact **J** source/child-defender matching, unique active Squadron,
valid activation/context, and satisfaction checks. It derives
`CompleteSquadronActivationCommand` carrying the exact **J** ID. That command
already accepts a destroyed but active Squadron, commits its activation and
phase progress where applicable, and consumes **J** in the same accepted
transaction. A failed command leaves both facts unchanged. With no **J**,
child completion installs the enclosing route, and the existing live/recovery
Squadron owner evaluator derives the same completion without an inspection ID.
Neither path may offer Move or Move-decline, synthesize **J**, or drop the
destroyed Squadron's activation.

In Squadron Phase, completion commits `GameState`'s controller/count and
projects `WAIT_FOR_SQUAD_SELECT`. `AdvancePhaseCommand.validate()` currently
checks ordering and absence of an active Squadron but **does not check
exhaustion**. Restrict its Squadron→Status branch to valid phase progress, no
active attack/inspection/Squadron activation, and no surviving unactivated
Squadrons for **either** player. Permit the two canonical exhausted shapes:
inactive controller/count zero after the last completion, or active initial
controller/count zero immediately after entering an empty Squadron Phase.
The latter is produced by `AdvancePhaseCommand` entering Squadron Phase and
`GameManager._begin_squadron_phase()` auto-skipping it. Any active controller
with an eligible Squadron remains a selection, never an automatic advance.
Derive the existing phase-advance command from these facts at the live-only
post-success/reconstruction seam, not solely from
`GameManager._on_local_squadron_phase_progress_committed()` or the phase-entry
callback.

In Ship Squadron Command, completion projects
`SHIP_ACTIVATION/SQUADRON_STEP`. `GameManager.derive_commanded_squadron_terminal_transition()`
currently returns automatic `AdvanceActivationStepCommand(repair_step)` only
when capacity is exhausted or no eligible commanded Squadron remains; it takes
the just-completed command and thus cannot recover a lost follow-up. Factor
that predicate into one pure, ship-identity-scoped canonical evaluation used
after success and on reconstruction. When capacity remains **and** an eligible
Squadron remains, leave a stable player choice: select another Squadron or
voluntarily finish through the existing Ship activation UI and
`AdvanceActivationStepCommand`. Recovery must not auto-submit the voluntary
finish. `AdvanceActivationStepCommand.validate()` still checks active
Squadron absence and the open/unreached Ship opportunity; explicit player
finish is distinct from the automatic exhausted branch. Neither return adds a
persisted owner, readiness marker, or new transaction type. If uniqueness or
phase/ship legality cannot be shown, stop rather than guess a return.

### 2.5 Canonical consistency and installed-flow admission policy

The accepted Owner decision requires one **pure, purpose-specific Counter
consistency policy** at the existing Counter rule/attack validation seam. It
reads `GameState`, a candidate or installed `InteractionFlow`, and the active
parent or inspection **I**. Its decision result comes exclusively from the
active canonical disposition or the transferred inspection witness. It stores
nothing and never derives a choice from flow, scene tokens, or command history.

| Boundary | Required owner and comparison |
| --- | --- |
| Active parent, including a proposed publication | `CurrentAttackState` must be active, damage-resolved, non-Counter, and Squadron versus Squadron. Its exact `attack_id`, parent attacker/defender player and index, and the two `GameState.get_squadron()` models are authoritative. `CounterKeyword.is_counter_trigger_available()` must hold. The parent attacker (Counter target) must survive; the Counter Squadron may be destroyed. `counter_attacker_*` must equal the parent defender; `counter_target_*` must equal the parent attacker. `counter_controller_player`, payload `controller_player` when present, and outer flow controller must equal the Counter Squadron owner. `counter_attack_available` must be literal `true`; after the existing integer type checks, `counter_dice_pool` must match the canonical positive `{"BLUE": X}` from that Squadron's Counter value under the existing Counter pool matching rules (no new color-key or count coercion). `resolved_outcome.target_kind` must be Squadron, its `requested_hull_damage` must be present as a native nonnegative integer, and candidate `final_damage` must be the same native integer; neither capped `actual_hull_damage` nor a missing/defaulted/coerced value can satisfy this comparison. The step must be `ATTACK_COUNTER_CHOICE`, its source must match the active parent, and no decision marker is permitted in a *new* publication. |
| Installed Counter flow with active parent | The same source/participants/controller/pool and `final_damage == requested_hull_damage` comparison must still match the active parent and Squadron owners. Absent disposition means no decision mirror; `accepted`/`declined` requires an exact native boolean mirror. A flow marker alone cannot decide; a decided parent without its consistent installed Counter step is invalid before retirement. |
| Retired parent awaiting inspection **I** | `CurrentAttackState` is inactive and `CompletedAttackInspection` must exist. Its exact `source_attack_id`, attack kind, attacker/defender references, proposed immutable decision witness, and validated Squadron result replace the retired attack as the parent authority. For Accept, installed Counter flow remains and must match reversed identities, controller, availability, pool, `true` mirror, and `final_damage` equal to **I**'s native `requested_hull_damage`. For Decline, the enclosing Squadron route replaces Counter flow in the completion command; **I** alone carries the `declined` witness. A flow cannot supply a missing witness; no undecided retired Counter projection is recoverable. |
| Counter child after **I** consumption or no-**I** parent replacement | The parent projection cannot remain installed as a reconstructible snapshot: **I** has been consumed or the still-active parent replaced, and the child `CurrentAttackState` does not retain a parent source identity. `BeginAttackCommand.execute()` must install the child `ATTACK_DECLARE` projection in the same accepted command that installs the child attack, as it already does for ordinary attacks. The existing `_enqueue_counter_begin_publication()` follow-up must be retargeted to the installed child/Declare state to supply the subsequent `ATTACK_ROLL` projection; it currently requires the old parent Counter-choice flow and would otherwise skip Roll. No parent decision remains independently authoritative after this point. |

**Installed-flow admission is a separate command precondition.** At
`CommandProcessor`'s existing publication preflight, after Boundary B's pure
container/integer safety check and before any publication rule hook, a pure
Counter-specific guard reads the *currently installed* canonical
`GameState.interaction_flow` and canonical parent disposition. If the installed
flow is `ATTACK_COUNTER_CHOICE`, **every** direct or JSON-decoded
`PublishAttackFlowCommand` rejects before hooks: a same-source Counter repeat
is a duplicate; a same-parent earlier/non-Counter step is a downgrade; a
different-source publication is a stale replacement; `final=true` is a
premature clear. This applies whether the parent disposition is absent,
`accepted`, or `declined`, and while a legitimate **I** awaits release. A
malformed installed Counter flow fails closed at state reconstruction; it is
not repaired by a later publication. No early guard canonicalizes the
submitted payload or mutates state. Repeat the installed-flow and disposition
preconditions in `PublishAttackFlowCommand.validate()` before `execute()`;
the early guard protects hooks, while command validation remains the full
legality boundary. This is a narrow extension of the accepted Boundary B
publication preflight, not a generic command-validation framework.

For a **new** Counter-step publication, validation also requires an active,
resolved, eligible same-source parent with disposition absent and no pending
inspection. Once the preacceptance `AttackExecutor._fsm_advance(RESOLVE_DAMAGE)`
write is removed, a genuine accepted damage command can leave the installed
Attack projection at same-source `ATTACK_MODIFY` (no defense),
`ATTACK_DEFENSE_TOKENS` (defense resolved), or `ATTACK_RESOLVE_DAMAGE` (an
already accepted projection). Admit exactly these reachable Attack
predecessors when their source, phase, and canonical damage/defense state
agree. The direct Counter publication replaces that projection in one accepted
command; an extra intermediate Resolve Damage publication would reintroduce a
callback/ordering dependency. An installed Counter or any other Attack step is
never replaceable. A direct legal damage-command path may instead retain an
enclosing non-Attack route: admit it only when that route and the canonical
parent/Squadron owners match, then construct the complete candidate entirely
from those owners. An unrelated installed flow, inactive/decided parent, or
inconsistent source fails closed. `publish_attack_flow` has global command
applicability and `PublishAttackFlowCommand.validate()` currently checks a
target spec, not the predecessor edge in `FlowSpec`; add this narrow
owner-backed predecessor check at command validation rather than widening
general flow transitions.

**Only accepted semantic commands retire the installed Counter step.** A
decided parent's `CompleteAttackCommand` may replace it with the enclosing
Squadron route for Decline (with or without **I**); Accept with **I** retains
it until the source-bound child Begin consumes **I** and atomically installs
child Declare; Accept without **I** uses that same atomic child replacement
directly. Neither `PublishAttackFlowCommand(final=true)` nor a subsequent
ordinary publication is a legal Counter retirement transaction. The parent
completion and Begin commands must validate their exact canonical witness,
source, inspection, and installed-flow preconditions before mutation. The
terminal publication observer must skip these semantic retirements, leaving
no queued clear to lose on Save/reconnect. This protection does not prohibit
ordinary publications once the accepted retirement has installed the next
route/child; those still follow their own lifecycle validation.

This is **semantic consistency**, separate from type restoration. Boundary B's
existing declared-integer codec and pure early preflight reject malformed
publication structure and restore permitted integral JSON numbers. Boundary A
restores `InteractionFlow` integer fields and requires all four identities at
`ATTACK_COUNTER_CHOICE`. Neither layer proves those values match the Attack or
Squadron owners. Apply the same Counter policy after codec normalization in
`PublishAttackFlowCommand.validate()` (before `execute()`), in
`CounterChoiceCommand.validate()` and the parent-completion gate, and after
`GameState._deserialize_representation()` has reconstructed the flow, attack,
Squadrons, and optional inspection. The reconstruction call covers full Save,
Network/passive, and replay state installation; `InteractionFlow.deserialize()`
remains a structural/type boundary. An inconsistent complete Counter flow
rejects the whole reconstructed state. Do not alter non-Counter publications,
mixed fields, or unknown-field compatibility.

### 2.6 Production-path completeness cross-check

The current `PublishAttackFlowCommand.validate()` verifies candidate source
and required identities but does not compare an installed Counter step or
canonical disposition; `execute()` overwrites the flow. `CommandProcessor`
preflights publication hooks before command validation and its terminal
observer can queue a later final clear. These are the exact admission and
retirement seams in Sections 2.3 and 2.5. The existing
`CurrentAttackContinuation` and `BeginAttackCommand` cannot yet perform the
Option-B no-**I** replacement, so each parent handoff requires the stated
normative amendment and implementation proof.

After a child destroys its original activating Squadron,
`GameState.get_active_squadron_activation()` still returns the retained
activation. `CurrentAttackContinuation._derive_counter_child_inspection_release()`
currently rejects it because `is_destroyed()` is true, and
`GameState.has_legal_remaining_squadron_move_action()` can report a Move that
the Move commands reject. `CompleteSquadronActivationCommand` already validates
and consumes a satisfied **J** with completion, and marks the Squadron
activated; the proposed narrow legality/release changes make that existing
consumer reachable. Its Squadron Phase controller/count and commanding
`ShipInstance` facts are the subsequent owners. Phase advance currently comes
from post-completion and empty-phase-entry callbacks; its command validation
does not test Squadron exhaustion. The Ship step evaluator takes the just-run
completion command. Both need the stated live-only canonical reconstruction
entry. `derive_reconstructed_cancelled_attack_return()` requires an enclosing
route, explaining the atomic route installation at no-**I** Decline and
no-**J** child completion.

With those bounded corrections, every proposed intermediate has one owner:
active parent, legitimate **I**, active child, legitimate **J**, then original
Squadron and enclosing phase/Ship. There is no durable owner for a lost
observer queue, so any route retirement or phase/Ship follow-up that remains
queue-only would be a **non-recoverable gap and stop condition**. A proposed
transition does not become accepted authority merely by appearing in this
matrix.

### 2.7 Complete production command-boundary inventory

This inventory follows the actual executable entry paths, not only the
intended matrix. Each required correction maps to a row in Section 2.3. A
direct `CommandProcessor.submit()` or reconstructed command still passes the
same command preflight/validation; Network ingress adds a separate origin
restriction and replay uses its own bootstrap route.

| Entry or seam observed in production | Current behavior and proposed boundary; matrix rows |
| --- | --- |
| Damage command producers and submitters | `AttackExecutor._attack_exec_resolve_damage()`, `_resolve_squadron_damage()`, and `_resolve_ship_damage()` call `GameManager.submit_resolve_*_damage()`; no-defense continuation can derive `resolve_damage` after `commit_accuracy`. Before submission, `_attack_exec_resolve_damage()` currently calls `_fsm_advance(RESOLVE_DAMAGE)`, which writes/publishes local flow. For a parent canonically eligible for Counter, remove this preacceptance write/publication as well as later callback writes. `LocalCommandSubmitter.submit`, `NetworkHostCommandSubmitter.submit`, and client `NetworkCommandSubmitter.submit` reach authority differently. Only accepted `ResolveDamageCommand` source/outcome opens publication eligibility. Parent damage and publication rows. |
| Network live ingress and trusted authority | `NetworkManager._submit_command_to_server()` deserializes peer input, checks peer/principal association with `cmd.player_index`, then uses `CommandProcessor.submit_deferred_followups()`. That seat check is insufficient for an engine-owned Counter-step publication if the attacker is the client. Reject every live peer-originated non-final `publish_attack_flow` targeting `ATTACK_COUNTER_CHOICE` **before** CommandProcessor, irrespective of asserted player or valid payload. `NetworkHostCommandSubmitter.submit()` is the local player path and must likewise refuse that step; trusted host-generated publication enters through `submit_authoritative()` or server observer-follow-up submission, never the player path or live peer RPC. Other command legality stays in CommandProcessor. Publication row. |
| Command codec, preflight, and hooks | `GameCommand.deserialize()` restores envelope/declared integers and Boundary B nested publication integers. `CommandProcessor._submit()` checks sequence and application contract, then `preflight()` runs Boundary B publication shape checks, terminal/inspection/applicability checks, and rule hooks **before** `command.validate()`. Add the pure installed-Counter publication guard before hooks; add a pure `counter_choice` safe-shape and exact-source guard before its `CounterKeyword.validate_counter_choice()` hook can coerce fields. Full source/identity/decision/semantic checks remain in each command's `validate()`. Publication and choice rows. |
| Damage execution, callbacks, and nested publication | `_execute_and_record()` installs damage, history, and sequence before `_enqueue_post_success_continuation()` and `command_executed.emit()`. `AttackPanelController` routes accepted `resolve_damage` to `AttackExecutor.apply_damage_result()`; direct damage submitters call it too, and host `NetworkManager._distribute_command_result_data()` synchronously emits local `command_result_received` before peer RPC. `apply_damage_result()` currently calls `_fsm_patch_payload({"final_damage": ...})`, zero/positive Squadron paths call `_maybe_offer_counter_attack()`, and `_start_counter_choice_flow()` calls `_fsm_advance()` plus `_publish_counter_payload()`. Those helpers mutate `GameState.interaction_flow` and `GameManager.submit_publish_attack_flow()` may recursively submit/broadcast. For a Counter-eligible result, all such callbacks become presentation-only; no FSM `advance(game_state)`, payload patch, snapshot/final publication, or nested command submission is permitted. Include `final_damage` in the later detached complete Counter publication from the validated canonical Squadron `resolved_outcome.requested_hull_damage`; `actual_hull_damage` is the capped application amount, not the published damage. Parent damage and publication rows. |
| Ordered post-success and broadcast | `CommandProcessor._enqueue_post_success_continuation()` is the single live-authority producer for the complete Counter publication after accepted damage; one continuation is selected, with no competing auto-completion. `NetworkManager._submit_command_to_server()` and `handle_host_command()` distribute the accepted damage result, then `_drain_server_observer_followups()` submits/broadcasts the queued publication. Hot-Seat drains after `command_executed`; passive/mirror and replay collect none. Reject or re-derive a lost publication from the resolved parent; never infer it from callback tokens. Parent damage and publication rows. |
| Choice producers and commit | `AttackExecutor._on_counter_attack_requested/_skipped()` currently build from transient pending Squadron tokens; `AttackPanelMirror._submit_counter_choice()` copies flow payload; both call `GameManager.submit_counter_choice()`, which copies context but does not add source. Require both producers to read exact active parent `attack_id` and compare the complete installed flow before building a choice. Direct and JSON commands must carry the same exact string. `CounterChoiceCommand.validate()` checks source, owner, four identities, native `accepted`, and absent canonical disposition; `execute()` installs parent disposition once and only mirrors it to flow. Choice row. |
| Parent/child semantic installation | `CompleteAttackCommand.execute()` currently makes Attack inactive and creates **I** but leaves flow for a later `_enqueue_terminal_attack_publication()` clear. `BeginAttackCommand.execute()` installs a distinct child and Declare flow, but currently rejects active parent; the proposed Counter-only no-**I** replacement and **I** witness handoff are required. Decline completion and no-**J** child completion install enclosing route atomically. `_enqueue_terminal_attack_publication()` must not queue a final clear for those paths; `_enqueue_counter_begin_publication()` must use installed child/Declare rather than retired parent Counter flow. Parent retirement, child Begin/completion rows. |
| Enclosing consumers and callbacks | `AcknowledgeAttackResultCommand` satisfies **I**/**J** only; `MoveSquadronCommand`, `DeclineSquadronMoveCommand`, or `CompleteSquadronActivationCommand` consume the exact satisfied inspection with enclosing mutation. Destroyed original Squadron completes without Move. `GameManager._on_local_squadron_phase_progress_committed()` currently calls phase advance only after live completion; `GameManager.derive_commanded_squadron_terminal_transition()` currently needs that completion command. Share owner-derived automatic predicates with reconstruction while retaining explicit voluntary Ship finish. **I**, **J**, Squadron Phase, Ship return rows. |
| Replay and passive execution | `ReplayDriver` decodes with `GameCommand.deserialize()` and uses `submit_replay`; `CommandProcessor.submit_replay()` suppresses `command_executed` and observers. Network replay uses separate `_submit_replay_command_to_server()` / `submit_replay_deferred_followups()` with sequence validation and no live-principal claim; it must admit valid **recorded** Counter publications. Passive clients receive ordered results and call `submit_mirror()` (or `submit_replay()` during replay), never derive host publications or follow-ups. All rows use identical command legality and deterministic execution; only live ingress applies the peer-origin prohibition. |
| Save/reconnect and lost follow-ups | `GameState._deserialize_representation()` installs Attack, Squadron, inspection, and flow before Counter consistency checks. `GameManager.release_reconstructed_completed_attack_inspection()` invokes current-attack, cancelled-return, and inspection evaluators only on live authority. Extend those owner-derived evaluations for missing complete publication, decided parent, **I**/**J** release, destroyed original completion, and exhausted phase/Ship advance; passive/replay synthesize none. Every installed route and owner must survive JSON reconstruction without a queue. All recovery cells in Section 2.3. |

The inventory exposes four bypasses omitted by a flow-only design: direct or
JSON choice without source; accepted-damage callbacks issuing nested
publication before the parent broadcast; a validly seated but untrusted
Network client submitting the engine-owned Counter step; and phase/Ship
callbacks as the sole source of terminal progress. Section 2.3 and the
command contracts below close each one without making scene, queue, or
`InteractionFlow` a gameplay owner. A duplicate automatic publication or
completion must be rejected by exact installed state after the first accepted
command; recovery re-evaluates owners and submits at most one missing command.

On live reconstruction, evaluate in canonical dependency order: faceup
obligation; active resolved parent (complete publication or decided
retirement); satisfied **I**/**J** release; inactive attack plus active
original Squadron completion; then exhausted Squadron Phase or Ship Squadron
Command progress. A prior applicable barrier stops lower enclosing evaluation.
The same owner predicates must drive the corresponding live post-success
follow-up. This order prevents a phase/Ship advance from racing an unconsumed
inspection or an active Squadron, and prevents a recovered Counter publication
from competing with parent completion. Passive and Replay-13 installations
validate state but submit none of these derived commands.

## 3. Atomic commitment through existing ordered commands

The current `AttackExecutor._start_counter_choice_flow()` calls `_fsm_advance()`
before `_publish_counter_payload(true)`. `_fsm_advance()` writes
`GameState.interaction_flow` before submission; this violates the proposed
rejection invariant. The correction is **not** to patch the live FSM first.

1. After accepted `resolve_damage` reaches `STAGE_RESOLVED`, derive the
   complete prospective Counter flow from the active parent attack and
   canonical Squadrons. Copy the source-matching parent presentation payload
   only when its installed Attack step is `ATTACK_MODIFY`,
   `ATTACK_DEFENSE_TOKENS`, or `ATTACK_RESOLVE_DAMAGE` and the canonical
   resolved damage/defense owners agree; fill required
   post-damage presentation values from the resolved canonical outcome, never
   from scene tokens or the damage callback. For a Squadron parent, set
   published `final_damage` to `CurrentAttackState.resolved_outcome`
   `requested_hull_damage`, **not** `actual_hull_damage`. The accepted
   `ResolveDamageCommand._execute_squadron()` writes requested damage from
   `attack.derive_damage(game_state)` and caps actual damage at the defender's
   remaining hull. Require the resolved Squadron outcome to contain a native,
   nonnegative integer `requested_hull_damage` consistent with its target kind;
   absent, negative, wrong-type, fractional, or nonfinite values fail closed
   before publication. Do not use `int()`, a default zero, the command result,
   or a presentation callback as a replacement source. Zero, positive, and
   excess-over-remaining-hull requested values retain their exact requested
   amount in the published payload. On JSON reconstruction, the same
   canonical validation applies before recovery can publish; an integral JSON
   float still requires a separately authorized `resolved_outcome`
   reconstruction correction to restore the canonical integer. This design
   neither implements nor masks that independent Boundary C defect.
   Add the complete Counter patch and parent `attack_id`,
   then use `FlowSpec.make_interaction_flow()` and the existing
   `GameManager.build_publish_attack_flow_command()` on that *detached* flow.
   Validate this purpose-specific same-source predecessor set before
   `ATTACK_COUNTER_CHOICE` installation. A direct legal damage command with
   an enclosing non-Attack route must prove that route and the canonical
   parent/Squadron owners agree before constructing the same complete flow;
   no other installed Attack step is admissible.
   Failure to cover a legal direct path is an implementation stop, not
   permission to drop its Counter decision. Do not call
   `AttackFlowFSM.advance(game_state, ...)`, `patch_payload(game_state, ...)`,
   or alter the installed flow or live scene FSM while constructing it.
2. At `CurrentAttackContinuation._derive_followup()` / CommandProcessor's
   `_enqueue_post_success_continuation()` seam, select and queue **only** this
   complete `PublishAttackFlowCommand` for an eligible unresolved parent after
   successful `resolve_damage`; do not also queue ordinary completion. The
   damage command has already executed and entered history, but on Network
   host the accepted damage result must be distributed before the queued
   publication is submitted and distributed. `NetworkManager.handle_host_command()`
   and `_submit_command_to_server()` already drain observer follow-ups only
   after result distribution; preserve that order in both role mappings.
   `AttackExecutor._attack_exec_resolve_damage()` must first stop calling
   `_fsm_advance(RESOLVE_DAMAGE)` on a canonically Counter-eligible parent:
   that is a callback-driven local flow write/publication **before** damage
   acceptance. `AttackExecutor.apply_damage_result()` is reached both by direct damage
   submitters and by `command_executed`, and host result distribution can invoke
   it synchronously before peer RPC. At a Counter-eligible boundary it must
   perform **presentation only**: no `_fsm_patch_payload({"final_damage": ...})`,
   `_fsm_advance()`, `_publish_counter_payload()`,
   `GameManager.submit_publish_attack_flow()`, local `InteractionFlow` write,
   or recursive command submission. Scene-only FSM reconciliation via a null
   GameState is permitted; it cannot install or publish canonical flow.
   `AttackPanelController`, mirror, and remote-result callbacks inherit this
   prohibition. The queued publication is engine-owned: use the trusted host
   authoritative submission path, retaining the parent attacker as command
   player even when the host controls the defender. This covers host=P0 and
   host=P1 without granting the remote client publication authority.
   Hot-Seat uses the same accepted ordered command commit; ReplayDriver
   applies only a recorded publication. No second publication or generic
   transaction/rollback mechanism is introduced.
3. On live Network ingress,
   `NetworkManager._submit_command_to_server()` must reject a peer-supplied
   non-final `publish_attack_flow` whose `step_id` is
   `ATTACK_COUNTER_CHOICE`, **after safe decoding but before authority
   execution**, irrespective of a correct seat association or a replay-mode
   flag observed on that live RPC. The accepted
   publication comes only from host-owned post-success/reconstruction
   submission. `NetworkHostCommandSubmitter.submit()` must also refuse this
   player-route publication; only its `submit_authoritative()` or the server's
   own observer-follow-up drain may commit it. The separate replay-bootstrap
   RPC and local replay submitter
   still execute a valid recorded publication through ordinary deterministic
   command validation/sequence checks, not the live peer-origin gate.
   `CommandProcessor` runs the retained Boundary B pure structure/integer
   preflight, then the pure installed-Counter guard, **both before rule hooks**;
   after hooks, `PublishAttackFlowCommand.validate()` repeats admission and
   checks full owner consistency, then `execute()` installs the complete flow.
   Only the accepted
   command may make `ATTACK_COUNTER_CHOICE` observable. Rejection leaves the
   canonical flow, history, sequence, and observer follow-up queue unchanged;
   no scene-local actionable Counter flow has been installed to undo.
   `AttackExecutor._maybe_offer_counter_attack()` and
   `_start_counter_choice_flow()` cease to publish or install the step; after
   accepted publication, they rebind presentation from canonical state and
   `AttackFlowFSM.restore_projection()` (which writes no `GameState`). UI
   affordance projection consumes the canonical disposition; controller
   entitlement and single-use legality never come from the flow.
4. A recovered resolved parent with eligible Counter but no Counter step can
   derive the *same* prospective publication at the existing
   `CurrentAttackContinuation.derive_reconstructed_resolved_attack()` /
   `GameManager.release_reconstructed_completed_attack_inspection()` live
   authority seam. A complete Counter step derives no second publication;
   its choice status comes from `CurrentAttackState`. Wrong-source, malformed,
   or inconsistent installed flows fail
   closed. Passive Network and replay reconstruction derive none. This closes
   the post-damage/pre-publication reconnect window without a durable queue.

The single Counter-step publication replaces the old two-publication
transition. It can shift later command sequences, sequence-derived
attack/inspection IDs, and final hashes; it does not change an envelope or
stored format by itself. The integrated Option B state and no-**I** Begin
contracts do change serialized content as specified in Section 7.

## 4. Single-use decision, recovery, and composed return

The proposed `CurrentAttackState` disposition is the sole active-parent
decided marker. It is absent before a choice; when present it has only the
native values `accepted` or `declined`. The flow boolean may mirror that
decision for presentation but cannot create it. A mismatched, malformed, or
source-stale mirror fails closed. Neither `bool(get(...))` nor truthiness may
collapse absent and Decline.

| Canonical state | Permitted action and recovery |
| --- | --- |
| Active resolved parent, disposition absent | Exactly one entitled `CounterChoiceCommand` may be accepted. `CompleteAttackCommand.validate()` rejects premature completion. Reconstruction derives the same pending opportunity from Attack/Squadron owners and queues no completion or child. |
| Active resolved parent, disposition `accepted` | Further choices reject before mutation. With required principals, the live/reconstructed evaluator derives one parent `CompleteAttackCommand` and child waits for **I**. With no required principals, it derives one source-bound Counter Begin replacement directly from the still-active parent; no separate completion or inactive gap is permitted. |
| Active resolved parent, disposition `declined` | Same duplicate-choice rejection and exactly-once parent `CompleteAttackCommand`; no child is derivable. Completion installs the enclosing Squadron route atomically, with or without **I**. Subsequent **I** release, when one exists, follows ordinary Squadron return. |
| Inactive parent with source-matching inspection **I** | The proposed inspection witness is the sole decision owner. `accepted` may derive one Counter child `BeginAttackCommand` only after exact satisfaction; `declined` may derive only ordinary enclosing continuation. The successful consumer atomically consumes **I**. Repeated release cannot consume it again. |
| No-inspection terminal path | Accept uses the proposed Counter-only `BeginAttackCommand` replacement under CON-001-LIFE-010; Decline uses `CompleteAttackCommand` under LIFE-009 with atomic enclosing-route installation and canonical Squadron return. Neither creates an empty inspection. |

`CounterChoiceCommand` must carry an exact, nonempty string `attack_id` equal
to **both** the active resolved parent `CurrentAttackState.attack_id` and the
installed complete Counter flow's `payload.attack_id`. Neither a default from
the installed flow nor equality of the four Squadron identities can substitute
for this source binding: those participants can fight again in a later attack.
`GameManager.submit_counter_choice()` must require the source in the context;
both `AttackExecutor` and `AttackPanelMirror` producers read the active parent
and compare the flow before submission. The same requirement applies to direct
`CounterChoiceCommand` construction and `GameCommand.deserialize()` of JSON.
The ID is a command-intent field, not a new persisted owner or integer codec
field. A missing, wrong-type, stale, or mismatched ID rejects before rule hooks
or mutation, including when player and all four identities happen to match.

`CounterChoiceCommand.validate()` must require that source, native boolean
`accepted`, owner-consistent flow, matching four command identities, and
**absence** of the canonical disposition. A pure command-specific prehook
check in `CommandProcessor.preflight()` must validate safe command shape,
exact source, and canonical decided-state guard before
`CounterKeyword.validate_counter_choice()` can coerce fields or inspect a
malformed pool; full gameplay legality remains in command validation. The
early check stores nothing and does not mutate/canonicalize the submitted
payload. `CounterKeyword.project_counter_affordance()`
and the UI router may expose the choice only while the canonical disposition
is absent.
`AttackExecutor._on_counter_attack_requested()` / `_on_counter_attack_skipped()`
must build their submission context from the active canonical Attack and
Squadrons after recovery, checking the installed flow as a mirror rather than
requiring `_pending_counter_attacker`
or `_pending_counter_target` scene tokens. `CompleteAttackCommand.validate()` must
consult the canonical disposition for an eligible resolved parent: absent
blocks completion, `declined` permits it, `accepted` permits it only when a
legitimate nonempty **I** must be created, and malformed/inconsistent data
rejects. `CurrentAttackContinuation._counter_decision_pending()` and
`derive_reconstructed_resolved_attack()` must use that same tri-state plus
the canonical required-principal derivation, selecting completion, no-**I**
Counter replacement, or a pending choice rather than repeating eligibility
alone. The existing CommandProcessor live post-success queue submits the one
derived transaction; reconstruction uses
`GameManager.release_reconstructed_completed_attack_inspection()` only on the
live authority. Once completion or replacement commits, the active parent is
retired, so repeated evaluation cannot derive it again. A stale queued or
direct duplicate is rejected before mutation.

After completion, `CurrentAttackContinuation._derive_counter_inspection_release()`
and `BeginAttackCommand._validate_counter_identity()` must read the proposed
inspection witness and exact source/participants, never
`InteractionFlow.counter_choice_accepted`, when deriving or validating child
entry. The ordinary Decline release reads the same inspection witness and
enclosing Squadron owner. A flow mirror may be checked for consistency but
cannot select the branch. This is a sequential handoff, with no moment at
which the active Attack and inspection both own a writable choice. In the
no-**I** Accept branch, source-bound Counter Begin validates and replaces the
still-active parent directly; it cannot use flow or a prior
`CompleteAttackCommand` as a witness. In the no-**I** Decline branch, terminal
completion replaces the parent Counter projection with the enclosing route in
the same command, so an
inactive/no-**I** snapshot cannot expose an actionable stale choice.
Reconstructed enclosing progression is selected only from the existing
Squadron and phase/ship owners.

`AttackExecutor.resume_current_attack()` currently maps every resolved attack
to Resolve Damage and can overwrite the installed Counter projection. Its
bounded Counter branch must derive the decision from the canonical disposition,
then validate/rebuild the source-matching scene-only flow and UI route. For a legal
destroyed Counter Squadron, use the retained canonical model and the existing
transient token type only if visual presentation needs it; ordinary selection
remains prohibited. A destroyed Counter *target* is ineligible. The current
inspection/Counter-child authority, locked child Declare, ordinary Roll,
inspection **J**, and CON-007 composed return stay with their existing
owners. Neither a reconstruction pass nor a UI callback may synthesize a
choice, acknowledgement, child, or return command on a passive peer or replay.

### 4.1 Command-level acceptance contract

All commands below use the existing ordered `CommandProcessor` pipeline. The
listed postcondition must be installed by the accepted command itself;
callbacks and queued follow-ups cannot complete part of its mutation. A failed
precondition or execution must preserve GameState, flow, inspection, history,
sequence, and observer queue. JSON-decoded commands face the same semantic
checks as direct commands.

| Command | Exact Counter-scope precondition | Accepted postcondition |
| --- | --- | --- |
| `ResolveDamageCommand` | Active matching parent ID, completed defense, entitled attacker, legal target/damage owner. | One resolved parent/outcome and damage mutation; no Counter flow or `final_damage` callback write. Subsequent publication is a separate ordered command. |
| `PublishAttackFlowCommand` to Counter step | Safe full payload; active resolved eligible same-source parent, disposition absent, legal installed predecessor, no **I**, exact participants/controller/BLUE pool, native nonnegative Squadron `requested_hull_damage`; live Network origin is trusted host. | One complete Counter projection with source and `final_damage` exactly equal to canonical requested damage; no choice decision committed. |
| `CounterChoiceCommand` | Exact `attack_id` string matches active parent and installed Counter flow; complete consistent step, native boolean, entitled controller, four identities, disposition absent. | One source-scoped parent disposition `accepted` or `declined` and matching flow mirror. |
| Parent `CompleteAttackCommand` | Exact decided source; legitimate **I** principal set or Decline no-**I**; no pending inspection/timing. Accept no-**I** is forbidden. | Parent inactive; legitimate **I** receives immutable witness if required. Decline installs enclosing route atomically; Accept with **I** retains Counter projection. |
| Counter child `BeginAttackCommand` | Exact parent source intent, canonical `accepted` witness from active parent with no **I** or satisfied source-matching **I**; legal reversed participants/pool/target and no prior child. | One distinct child attack plus Declare projection; consumes **I** when present or atomically replaces still-active parent when absent. |
| `AcknowledgeAttackResultCommand` for **I**/**J** | Exact existing inspection and entitled required principal, no duplicate acknowledgement. | Adds only that acknowledgement; satisfaction permits, but does not perform, its release. |
| Counter-child `ResolveDamageCommand` / `CompleteAttackCommand` | Matching active child and ordinary damage/terminal gates; original Squadron activation remains unique. | Resolved child then inactive child; create legitimate **J** if required, otherwise install enclosing route in completion. Parent decision is not recreated. |
| Move, Move-decline, or `CompleteSquadronActivationCommand` | Original Squadron identity/context, no active attack, legal remaining action; exact satisfied **I**/**J** ID when present. Destroyed original permits completion only, never Move. | One inspection consumption with action or activation completion; completion commits Squadron/phase progress and enclosing route. |
| `AdvancePhaseCommand(SQUADRON→STATUS)` | No active attack/inspection/Squadron activation, valid phase progress, **both** players have no surviving unactivated Squadron, and one of the two exhausted progress shapes in Section 2.4. | Status phase installed once; duplicate or premature advance rejects. |
| `AdvanceActivationStepCommand(repair_step)` | Command validation requires matching active Ship identity, open/unreached Squadron opportunity, and no active Squadron. Its **automatic producer** additionally requires capacity exhausted or no eligible commanded Squadron. With another eligible Squadron, only the existing player-originated voluntary finish may submit the same command; this distinction is a producer/ingress obligation, not a new payload flag. | Existing Ship opportunity consumed and Repair step installed once. Recovery derives only the automatic path. |

## 5. Verification obligations

| Boundary | Required proof |
| --- | --- |
| Production transition and atomicity | From actual no-defense `commit_accuracy` → `resolve_damage` and explicit Squadron damage submitters, including zero, positive, and lethal damage, assert the first and only Counter-step publication is a detached complete candidate with `final_damage` equal to native canonical `requested_hull_damage`, source, controller, literal `available=true`, four native integer identities, and exact BLUE pool. Cover requested damage zero, positive below remaining hull, and greater than remaining hull; in the last case assert published damage exceeds capped `actual_hull_damage`. Repeat through genuine GameState JSON reconstruction and lost-publication recovery. Missing, negative, wrong-type, fractional, nonfinite, or float-after-JSON canonical requested values must reject or stop recovery without a flow/history/queue mutation until Boundary C restores the exact canonical type. Do not make this Counter producer a `resolved_outcome` normalizer; require separate Boundary C resolution before the reconstructed-valid cases can pass. Exercise installed `ATTACK_MODIFY`, `ATTACK_DEFENSE_TOKENS`, and `ATTACK_RESOLVE_DAMAGE` same-source predecessors where reachable; reject every other Attack predecessor and an unrelated enclosing route. Instrument pre-command `_attack_exec_resolve_damage`, direct `apply_damage_result`, `AttackPanelController.command_executed`, host `command_result_received`, and passive mirror callbacks: none may write flow, publish a `final_damage` patch, or recursively submit a command at the eligible boundary. Capture GameState/flow hash, history, sequence, and queue before callbacks and rejected candidates. Assert accepted damage execution/history and host result distribution precede queued publication submission and peer delivery in both role mappings. Test one continuation only, no duplicate publication, and lost-publication reconstruction. |
| Installed publication protection | With a complete installed Counter flow and each canonical disposition (absent, accepted, declined, or transferred to **I**), submit direct and genuine replay-JSON publications: duplicate same-source Counter, same-parent earlier step, different-source Attack, and `final=true`. Include registered Coolant Discharge and Escort hooks. All reject before hooks or mutation; compare full GameState/flow digest, command history, sequence, and observer follow-up queue. Also reject a new Counter candidate over an unrelated installed Attack step or a decided parent. After each authorized semantic retirement, prove ordinary child/enclosing publications work and no final clear is queued. |
| Shared policy and reconstruction | Direct and JSON publications with wrong parent source, reversed identity, controller, Counter pool, eligibility, destroyed target, false/absent availability, stale attack, or `final_damage` unequal to canonical `requested_hull_damage` reject before mutation. Test a candidate incorrectly using capped `actual_hull_damage` for excess damage. Boundary B still tests malformed integer/container input separately. Full `GameState` JSON validates the active canonical disposition or the transferred inspection witness against its flow mirror, including native requested damage and exact published `final_damage`; a missing, mismatched, or projection-only decision rejects. Test exact canonical/full-state hashes for prepublication, pending, accepted, declined, retired-with-**I**, no-**I** Decline completed, and child-begun states where unrelated state is stable. Preserve unrelated mixed/unknown fields and report unrelated digest divergence separately; do not declare full-state convergence while the separate Boundary C outcome reconstruction defect remains. |
| Choice and completion rejection | Direct and genuine JSON-decoded `counter_choice` Accept/Decline require exact native string `attack_id` matching both active parent and flow. Test missing, wrong type, old source with identical players/Squadron indices, flow-source mismatch, wrong player, mismatched identities, malformed `accepted`/pool, duplicate after canonical `accepted` or `declined`, and malformed disposition through prehook and command validation. Valid direct/JSON choices commit once and roundtrip exactly. Premature direct/JSON `complete_attack` with absent disposition and no-**I** accepted disposition rejects; decided states permit only matching terminal transaction. Wrong/stale source Counter Begin, missing source intent, premature child, wrong/unsatisfied **I**, duplicate child, and subsequent choice reject. Every rejection preserves GameState, flow, history, sequence, inspection, and observer queue. |
| Live Network origin and replay separation | In host=P0/defender=P1 and host=P1/defender=P0, send a valid Counter-step publication from the client with correctly associated attacker seat, plus forged player/identity and JSON-invalid forms. The live RPC rejects before CommandProcessor execution, history, queue, or broadcast; targeted rejection releases client awaiting state. The host player-route `NetworkHostCommandSubmitter.submit()` also refuses a Counter-step publication. The trusted server post-success and recovery routes accept the same valid candidate and broadcast it only after damage; passive applies it once. Separate Replay-13 local and Network replay-bootstrap paths accept the genuine recorded publication at its exact cursor and reject malformed or stale recorded entries by ordinary deterministic command validation, without using the live peer-origin exception. |
| Network/reconnect | In host=P0/defender=P1 and host=P1/defender=P0, the server derives and submits one engine-owned publication. The passive client never synthesizes publication, choice, completion, child, or enclosing return. Reconnect after damage but before publication recovers one missing publication; after publication recovers the pending choice; after either decision recovers the matching completion or no-**I** replacement from `CurrentAttackState`. Reconnect after completion derives child versus ordinary release from **I**, never flow; no-**I** Decline derives only enclosing Squadron progression. Repeat after **I** satisfaction, lost no-**I** Begin, lost **J** release, lost Squadron completion, and lost phase/Ship step advance. Prove child/Declare causes existing Network Roll publication exactly once despite retirement of parent flow. Compare authority/passive state, history cursor, controller, and hashes where stable. |
| UI and destroyed models | Real `GameBoard` ready/reload and `AttackExecutor.resume_current_attack()` derive the choice from canonical disposition and project a source-matching flow. The affordance exists only while canonical disposition is absent; recovered submission uses Attack/Squadron identities without requiring retained tokens. A destroyed eligible Counter Squadron remains model-resolvable and is never ordinarily selectable; detached visual token is transient and singular. Destroyed Counter target and ordinary destroyed attacker reject. |
| Accept, Decline, child and return | For surviving/destroyed Counter attacker × Accept/Decline × both role mappings, start before real parent damage resolution. With **I**: Accept transfers witness, waits for acknowledgements, then one child Begin consumes **I**; Decline transfers witness, atomically installs enclosing route, and returns through Squadron owner. Without **I**: Accept remains on active parent until source-bound Begin replaces it; Decline completes to inactive and installs enclosing route. Interrupt/save/reconnect/replay at every row of Section 2.3, including child Begin and child completion with/without **J**. Verify no queued final publication supplies retirement or return. Compare locked child Declare, ordinary Roll/resolution, exact **J**, original-Squadron Move/completion, duplicate rejection, and passive/replay non-synthesis. |
| Destroyed original activating Squadron | In Squadron Phase and Ship Squadron Command, have the Counter child destroy its original activating defender. Cover legitimate **J** and no-**J** paths, both Network role mappings, JSON roundtrip after child damage/completion, after **J** acknowledgement, and before enclosing completion. Assert no Move/Move-decline affordance or command, retained active activation identity, exact once **J** consumption with `CompleteSquadronActivationCommand` when present, and completion without an ID when absent. Kill the live observer follow-up and recover completion; then independently lose phase advance or Ship `repair_step` advance and recover it from canonical owners. Assert final phase controller/Status or Ship step and full-state digest convergence where other reconstruction boundaries are stable. |
| Phase exhaustion and Ship voluntary finish | Direct and JSON `AdvancePhaseCommand(SQUADRON→STATUS)` reject while either player has a surviving unactivated Squadron, an active activation/attack/inspection, or invalid phase progress; accept inactive/zero progress after last completion and active-initial/zero progress after entering an empty phase. Lose the phase callback in each exhausted shape and recover exactly one advance. In Ship Squadron Command, after a completed child with remaining capacity and an eligible Squadron, reconnect and show stable select-or-voluntary-finish; assert no automatic Repair advance. Explicit player finish remains legal. At exhausted capacity or no eligible Squadron, lose the observer follow-up, recover exactly one `repair_step` advance, and reject its duplicate. Cover both Network mappings and replay non-synthesis. |
| Replay, formats, baselines | Require Save-11 signed JSON and exact Attack/inspection reconstruction, rejection of incompatible Save-10, Network-12 handshake/filter/reconnect in both mappings and rejection of Network-11 peers, and Replay-13 version rejection plus ordered JSON execution. Current Hot-Seat and Network baseline replay inputs must be genuine Owner-recorded Replay-13 inputs; the new Counter history must contain one complete publication and its full lifecycle. Update `scripts/run_baseline_traces.sh --all`, `scripts/run_network_resume_acceptance.sh` (including `--counter-only` and its Network replay compatibility path), their fixture selection, and `tests/acceptance/network_resume/assertions.gd` to require current format/protocol and mandatory replay evidence. Update direct version assertions in focused/integration tests. Both runners and their assertions must pass with version-compatible inputs before integrated acceptance; a missing or rejected current replay is a failure, not a skip or waived baseline. Preserve all Replay-12 recordings, trace oracles, hashes, and BUG-074 evidence unchanged as historical. Compare any candidate Replay-13 trace/hash against the reviewed behavior, diagnose the first unexpected canonical-state difference (including Boundary C or position precision) before Owner-authorized oracle promotion, and never accept a replacement hash merely because replay terminates or Network peers agree. |

## 6. Accepted normative amendment traceability

The dated amendments below align normative authority with this accepted
architecture; completed Boundary A authority and earlier Owner evidence stay
unchanged. The consolidated implementation workbook remains a separate draft.

| Document | Accepted alignment; historical evidence preserved |
| --- | --- |
| [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md) | Its dated accepted amendment permits one immutable, source-scoped Counter decision witness (`accepted`/`declined`) in an otherwise legitimate, nonempty inspection **I** as a narrow exception to its result/acknowledgement-only content rule. The witness is copied atomically from the decided parent at `CompleteAttackCommand`, never mutated by acknowledgement, and removed with exact **I** consumption. It is not a route or generic continuation descriptor. The ban on empty/artificial inspections and all acknowledgement rules remain. |
| [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md) | Its dated accepted amendment specifies active-parent Counter disposition, exact source/type validation, command-owned single-use mutation, deterministic inactive form, and fail-closed legacy reconstruction. `CounterChoiceCommand` requires exact parent `attack_id` on direct and JSON entry, with prehook shape/source guard and canonical single-use commit. No-**I** Accept uses one Counter-only `BeginAttackCommand` semantic replacement under LIFE-010: it retires the resolved parent and installs a distinct child; `CompleteAttackCommand` under LIFE-009 is prohibited for that branch. For Decline, completion replaces installed Counter projection with enclosing Squadron route; direct final publication cannot retire it. Failure leaves parent, adjacent owners, flow, history, sequence, and queue unchanged. No other active-parent Begin becomes legal. |
| [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md) | With **I**, completion transfers witness; Accept retains Counter projection until exact child Begin, while Decline installs enclosing route. Satisfaction gates exact child Begin or enclosing consumer, which consumes **I** atomically. Without **I**, Accept's source-bound Begin is terminal replacement/release; Decline completes to inactive and installs enclosing route atomically. A child Counter result creates **J** only when required; if no **J**, completion installs enclosing route. A destroyed original activating Squadron has no legal Move and completes through existing Squadron activation transaction, consuming **J** exactly once when present. Re-evaluate exhausted Squadron Phase and Ship progress on lost follow-up; preserve a legal Ship selection/voluntary-finish choice without auto-finishing it. Passive/replay do not synthesize. Preserve composed return and no generic owner. |
| [Accepted Counter requirements](../../requirements/gameplay_interactions/counter_attack_interaction.md) | Its dated CAI-001–003 amendment says pending/accepted/declined belong to active Attack; a legitimate **I** carries only copied witness after completion. The Section 3 non-goal now permits only the Owner-approved purpose-specific disposition and **I** witness. Exact source-bound single-use choice, complete parent-source publication after accepted/broadcast damage, canonical requested Squadron damage, trusted Network origin, installed-flow protection, retirement, child, destroyed-original return, and decision-equivalent recovery are explicit. CAI-010/020/030 and the ban on a generic owner remain. |
| [Squadron Phase historical requirements](../../requirements/squadron_activation_ui.md) | A dated successor clarification, backed by amended CON-007, restricts Squadron→Status to no surviving unactivated Squadron on either side and no active attack/inspection/activation. Both initial active/zero and post-completion inactive/zero exhausted shapes remain legal; turn selection and handoff behavior stay with existing owners. |
| [Boundary A accepted workbook](interaction-flow-integer-reconstruction-repair-implementation-workbook.md) and [parent identity resolution](../evidence/counter-parent-identity-save10-roundtrip-resolution.md) | Left unchanged. Their strict four-field presence, range/type restoration, and whole-state rejection for incomplete `ATTACK_COUNTER_CHOICE` remain accepted. The new CON-001 amendment defines the flow boolean as a mirror checked at `GameState` reconstruction; old sequence 58 stays historical. |
| [Boundary B stopped proposal](attack-publication-command-codec-integer-reconstruction-repair-proposal.md) | Its dated successor note retains the shared integer policy, pure preflight, Escort correction, mixed/unknown compatibility, and command requiredness. The consolidated workbook integrates installed-Counter guard, owner-consistency, trusted Network origin, and direct/JSON rejection proof. The old 83-command Replay-12 final-hash gate is historical; current evidence requires Owner-recorded Replay-13. Partial codec implementation remains stopped. |
| [BUG-074 accepted implementation workbook](network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md) | Its dated successor note records the complete ordered publication, canonical disposition and inspection handoff, no-inspection proof, recovery, child-Declare replacement, version review, and manual replacement replay. Original acceptance and the three deferred GGS assurance variations remain historical and unchanged. |

ADR-001, ADR-010, and ADR-011 already require canonical ownership, recovery,
and host-controlled Network admission; no amendment to those principles is
needed. The Owner accepted Option B, the narrow ADR-007 inspection exception,
the CON-001/CON-007 and Counter requirements transitions, and the Save 11 /
Network 12 / Replay 13 policy on 2026-10-17. Their dated normative amendments
and the consolidated workbook preparation are authorized; the existing
Boundary B authorization still does not resume production implementation.

## 7. Replay compatibility and manual Owner recording

A repository JSON inventory found four historical format-12 BUG-074 recordings
with an identity-free Counter-step publication: the accepted
[`replay_20261015_065840.json`](../../qa/bugs/closed/BUG-074/replay_20261015_065840.json)
at sequence 58, plus
[`replay_20261011_212019.json`](../../qa/bugs/closed/BUG-074/replay_20261011_212019.json)
at 58,
[`replay_20261012_203616.json`](../../qa/bugs/closed/BUG-074/replay_20261012_203616.json)
at 58, and
[`replay_20261013_204337.json`](../../qa/bugs/closed/BUG-074/replay_20261013_204337.json)
at 59. They are incompatible with the strict Counter publication gate and
must remain immutable historical/defect evidence, not current conformance
fixtures. The two currently installed baseline replay inputs under
[`tests/fixtures/baseline_traces`](../../../tests/fixtures/baseline_traces/)
contain no Counter-choice commands or Counter-step publications, but **both
are format 12** and therefore cannot be current Replay-13 conformance inputs.
Their existing Hot-Seat trace and state-hash oracles are also historical and
must remain unchanged. A current-format Hot-Seat baseline and a current-format
Network baseline are required regardless of Counter coverage; the separate
new Counter replay supplies that coverage. The accepted BUG-074 final evidence
and its old final hash remain historical claims about that recording, not new
implementation acceptance criteria.

Option B adds an active-attack field and a narrowly approved
inspection field. Both classes currently enforce exact serialized key sets;
their JSON state shape and canonical hashes would change. The no-**I** Counter
Begin also needs a source `attack_id` in its command intent. No new command
type, envelope, protocol message, or persisted continuation owner is
proposed. **Accepted Owner version policy: Save 11, Network 12, Replay 13.**
The formats have not been implemented; they are gates for the separately
authorized integrated production package.

| Surface | Concrete compatibility consequence and decision gate |
| --- | --- |
| Save 11 | Bump signed-save metadata from 10 to 11 with the new exact Attack/inspection schema. Reject obsolete development Save-10 states at the version gate; no migration requirement or projection-derived choice. Preserve historical signed files unchanged. Verify new pending/decided/inspection and inactive/non-Counter JSON roundtrips. |
| Network 12 | Bump handshake protocol from 11 to 12 so mixed builds cannot exchange changed snapshots or Counter Begin semantics. Verify filtered snapshots, passive ordered application, host=P0/P1, and reconnect at every matrix row. Network-11 peers fail cleanly at handshake. |
| Replay 13 | Bump replay format from 12 to 13 for changed command/state semantics and require version-appropriate playback. The old seq58→59→60 history and both installed format-12 baseline inputs are incompatible with current-format playback and remain immutable historical evidence. The Owner must genuinely record new Replay-13 Hot-Seat, Network, and Counter inputs through gameplay; the Counter recording may serve a baseline role only if it also satisfies that baseline's coverage and provenance. New expected traces or hashes need separate diagnosis and Owner-authorized promotion. No mechanical migration, synthesis, relabeling, or replacement of historical files. |

**Current-format acceptance gate:** The two replay inputs consumed by
[`run_baseline_traces.sh`](../../../scripts/run_baseline_traces.sh) and the
Network replay consumed by
[`run_network_resume_acceptance.sh`](../../../scripts/run_network_resume_acceptance.sh)
are hardwired today to format-12 baseline paths. The latter's
[`assertions.gd`](../../../tests/acceptance/network_resume/assertions.gd)
also hardcodes replay format 12 and protocol v11. The authorized integrated
implementation package must point these runners at genuinely Owner-recorded
Replay-13 inputs, require their presence and valid current-format headers,
and update every exercised version assertion to Save 11 / Network 12 /
Replay 13. Run the Hot-Seat trace/hash comparison, Network host/client hash
comparison, real ENet resume/replay compatibility scenarios, and focused
Counter role-mapping cases. A current baseline may use new paths while the
old inputs/oracles remain immutable; filename reuse is not permission to
overwrite historical evidence. `run_baseline_traces.sh --network` currently
skips a missing replay, so integrated acceptance must instead fail if the
required current Network input is absent. A failing old format-12 replay is
expected historical incompatibility, **not** a passing current baseline.
Updating a runner or assertion without valid new input does not close this
gate. Neither this design nor Boundary B alone authorizes fixture or oracle
promotion.

Missing disposition in a legacy active parent is safe as *absent* only when
canonical facts prove no Counter choice could already have committed. An
obsolete eligible Counter parent with no disposition, or an inspection **I**
lacking a witness where either Accept or Decline is possible, is semantically
ambiguous and must fail closed, even if flow appears to say otherwise. Distinguish
obsolete missing from new pending by the accepted Save/Network/Replay version
gate, never by projection. No migration obligation is proposed for obsolete
development saves. Any hash change needs first-field diagnosis and
Owner-approved baseline action. For any new or changed Hot-Seat state hash,
trace, or Network final hash, retain first-field canonical comparison against
the applicable reviewed behavior, identify expected schema/semantic changes,
and investigate unrelated differences before accepting an oracle. Equal
Network peer hashes alone establish convergence, not correctness.
The Owner must manually record fresh Replay-13 Hot-Seat and Network baseline
inputs and a complete-publication Counter replay through ordinary gameplay
after the authorized production correction, retain the originals separately,
and provide provenance and consent for any new acceptance/expected hash or
trace. Codex may validate their signatures, ordered commands, one atomic
Counter publication in the Counter recording, both identities and exact child
source/inspection history, replay exhaustion, and host/client convergence;
Codex must not synthesize, transform, re-sign, promote, or overwrite the
recordings. The three previously deferred Counter variations remain in the
GGS assurance backlog, with no new recording duty inferred from this design.

## 8. Cost, risk, and stop gates

The atomic prospective producer alone is **Small–Medium**. Option A would be
smaller but fails recovery. Owner-selected B adds exact-schema versioning,
command-owned decision commit, inspection handoff, Counter-only no-**I** Begin
replacement, exact choice-source binding, callback-free damage projection,
host-only live publication ingress, installed-publication protection, semantic
enclosing-route retirement, destroyed-original Squadron release, phase/Ship
gate correction, strict requested-damage comparison, current-format baseline
runner/assertion adaptation, and lost-follow-up recovery to the earlier scope. The
combined package is provisionally **Large production plus Large verification**
(roughly 12–16 implementation days and 12–16 focused,
integration, Network, replay, and compatibility verification days, excluding
manual Owner recording and independent audit). This is a planning range, not
an authorization or a new economic ceiling; it supersedes the earlier 2–4
plus 3–5 day estimate. Risk is **High** at authority
handoff, legacy JSON, deferred broadcast ordering, host=P1 authority,
post-choice interruption, host callback recursion, untrusted client-origin
publication, installed-flow replacement, destroyed visual tokens, destroyed
original activation, phase exhaustion, voluntary Ship finish, lost follow-ups, and
sequence-derived child IDs. The existing Boundary B authorization does not
extend to this work.

**STOP** if a source-matching permitted predecessor and complete prospective
Counter projection cannot be validated from canonical owners without local
precommit; the existing ordered follow-up path cannot broadcast
damage before its Counter publication for both role mappings; a Counter-eligible
damage callback still mutates flow, publishes `final_damage`, or recursively
submits any publication; a client-originated live Counter-step publication can
pass the host ingress or host player submitter; a direct or JSON Counter choice
without exact parent `attack_id` can commit; a rejected
submission leaves an unrecorded actionable host flow; a full Counter flow
cannot be checked against the active parent or the approved **I** witness; child Begin cannot replace
the consumed parent's projection in the same accepted command; any incomplete
Counter step reaches a peer or reconstruction; resumed Accept/Decline differs
from uninterrupted play; child or inspection advances twice; an unapproved
new owner/FSM/queue, generic transaction, or version change becomes
necessary; no-**I** Accept can retire the parent without a source-bound
atomic child replacement; no-**I** Decline can leave a stale actionable
Counter projection or lose an automatic Squadron return; a direct or replay
publication can overwrite an installed Counter step or clear it before its
authorized semantic retirement; a destroyed original Squadron is offered Move,
loses **J**, or fails to complete its activation; a lost phase/Ship follow-up
cannot be recovered from existing owners; phase validation
admits a premature Squadron→Status transition or recovery auto-finishes an
eligible Ship Squadron Command choice; a version gate
admits mixed incompatible Network peers or an ambiguous old save; canonical
Squadron `requested_hull_damage` is missing/malformed or publication uses
capped actual damage; JSON recovery would require this Counter package to
silently normalize Boundary C; a current baseline runner still consumes
Replay-12, skips a missing Replay-13 input, or retains Save-10/Network-11/
Replay-12 acceptance assertions; a baseline changes without first-field
diagnosis and Owner-authorized promotion; or actual plus forecast exceeds an
Owner-approved economic limit once one is set. Historical Replay-12
incompatibility alone is not a reason to weaken this invariant.

**Architecture status: Owner ACCEPTED after independent acceptance audit and
targeted re-audit; implementation and Boundary B resumption remain STOPPED.**
The production inventory and transition matrix are accepted design authority;
production does not yet implement them. No ownerless or inherently
non-recoverable state remains in the accepted lifecycle **provided** semantic
retirement installs the enclosing route atomically, the owner-based recovery
evaluators are shared after success and reconstruction, and exact source/owner
validation passes. Failure of any proof is an implementation stop, not license
for another owner. The normative documents now reflect the accepted decision.
The consolidated implementation workbook passed independent audit and was
Owner-accepted on 2026-10-17. Separate Boundary C prerequisite authority and
explicit implementation authorization are still required before the combined
production package may start. Any
replacement Counter replay remains a later manual Owner recording obligation.

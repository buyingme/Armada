# Counter Attack — Gameplay-Interaction Requirements

> **Status:** Accepted
> **Scope:** Counter choice, accepted Counter child entry, and composed return
> across supported Squadron Activation contexts.
> **Architecture context:** ADR-001 / ADR-010 / CON-007.
> **Authority posture:** This is a TO-BE requirements specification. It is
> subordinate to accepted ADRs and Contracts; it is not a new lifecycle,
> continuation owner, or implementation plan.

Accepted by: Project Owner
Accepted date: 2026-10-12
Accepted atomic-publication amendment date: 2026-10-17

## 1. Purpose and authority

This specification records the accepted player-facing boundary for a Counter
child attack. It resolves the behavior that was formerly described only in the
historical [`game_flow.md`](../../game_flow.md).

Applicable authority remains:

- [ADR-001](../../architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
  for canonical current-attack ownership;
- [ADR-010](../../architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md)
  for decision-equivalent recovery; and
- [CON-007](../../architecture/contracts/CON-007-post-attack-continuation-release-contract.md)
  for inspection consumption and composed return through existing enclosing
  owners; and
- [Ship Activation gameplay-interaction requirements](ship_activation_interaction.md),
  especially SAI-030 and SAI-035, for the commanded-Squadron enclosing context.

## 2. Counter-child interaction requirements

### CAI-001 — Complete Counter choice and canonical decision

An eligible resolved Squadron parent exposes one complete
`ATTACK_COUNTER_CHOICE` publication only after its damage command is accepted
and, in Network play, broadcast. The publication identifies the exact parent
attack, Counter controller and participants, availability, and canonical
Counter dice pool. No incomplete Counter choice is observable or recoverable.
For Squadron damage, published `final_damage` equals the validated canonical
`requested_hull_damage`, including when it exceeds actual damage capped by
remaining hull. Missing or malformed canonical requested damage rejects; a
presentation result or callback cannot supply it.

The Counter Squadron's entitled player makes one Accept or Decline choice.
The active parent `CurrentAttackState` owns the source-scoped absent,
accepted, or declined disposition. `InteractionFlow` is projection only.
Duplicate, stale, wrong-source, premature, or malformed choices reject
without gameplay mutation. Only the live authoritative host may originate
the Counter-step publication in Network play; replay applies recorded
accepted commands in order.

### CAI-002 — Parent retirement and inspection I

With a legitimate completed-result inspection **I**, parent completion
atomically transfers the decided source-scoped disposition to one immutable
inspection witness before retiring the parent. An accepted witness permits
the exact Counter child Begin after required acknowledgements; a declined
witness permits the applicable enclosing Squadron continuation. Each consumer
consumes **I** with its own successful mutation. An empty or artificial **I**
is forbidden.

Without **I**, Accept keeps the decided parent active until one source-bound
Counter child Begin atomically replaces it. Without **I**, Decline completes
the parent and installs the enclosing Squadron route in the same command.
No witness-free recoverable interval or separate final-flow clear may stand
in for these transitions.

### CAI-003 — Recovery and single-use publication

Save/load, Network reconnect, and live-authority lost-follow-up recovery
derive the same pending choice or next authorized command from canonical
Attack, Squadron, and legitimate inspection owners. Complete Counter
publications reject repeat, downgrade, stale replacement, and premature
clear. A decided parent cannot expose another choice or complete through the
wrong branch. Passive Network and replay do not create follow-up commands.
The accepted format gates are Save 11 / Network 12 / Replay 13; historical
Replay-12 evidence remains historical and new replay inputs require genuine
manual Owner recording.

### CAI-010 — Locked declaration

After an accepted Counter creates its child attack, the child enters
`ATTACK_DECLARE` with attacker, target, range, obstruction, and Counter dice
pool already locked by authoritative parent and child state.

Both endpoints may present the locked attacker-to-target relationship. No
attacker selection, target selection, hull-zone selection, attack decline, or
other declaration decision is exposed. Locked Declare is neither an
acknowledgement nor an additional player decision. Presentation proceeds
automatically from locked Declare to `ATTACK_ROLL` through the existing attack
pipeline.

### CAI-020 — Roll and subsequent attack interaction

At Roll, the Counter controller receives the normal applicable
player-controlled attack interaction. Subsequent Counter resolution uses the
normal applicable attack pipeline, including legal modifiers, confirmation,
defense, damage, completion, and completed-result inspection behavior.

The non-controlling endpoint receives the corresponding passive presentation.
No separate Counter attack lifecycle or presentation-only authority is
created.

### CAI-030 — Composed return

The Counter child attacker and controller own only the applicable decisions of
the child attack. They do not replace the original activated Squadron or the
owners of its enclosing activation context.

After the Counter child completes, a legitimate completed-result inspection
**J**, when required, blocks return until it is satisfied. Satisfaction makes
CON-007 release evaluation eligible and triggers re-evaluation of the original
activated Squadron; it does not itself consume **J**. When no inspection is
required, child completion installs the enclosing route directly and creates
no **J**.

If Move remains legal, the derived Move decision is the next live legal
decision and a satisfied **J** remains pending. The authoritative Move
or explicit Move-decline transaction consumes matching **J**, when present,
atomically with its canonical mutation. If no legal Squadron action remains,
the existing authoritative Squadron-completion transaction consumes matching
**J**, when present, atomically. A destroyed original activating Squadron has
no Move opportunity and completes through that same transaction. Further
return proceeds through the existing Squadron Phase or commanded-Squadron/Ship
Activation owners until the next canonical stable state or live legal decision
is reached. A remaining legal Ship Squadron Command choice may be voluntarily
finished by the player; recovery must not make that decision automatically.

Child attack termination, terminal publication, or satisfied-but-unconsumed
**J** without the corresponding live Move decision is not completion of
this composed-return boundary. **J** must never be consumed merely to expose
a derived decision.

## 3. Explicit non-goals

These requirements introduce only the Owner-accepted, source-scoped parent
Counter disposition and legitimate inspection **I** witness in their existing
canonical owners. They introduce no Counter-specific lifecycle owner,
continuation stack, generic activation state machine, fallback authority, or
other persisted continuation state. Detailed Counter eligibility and dice
rules remain with their applicable rules authority.

## 4. Traceability

| Requirement | Decision / authority source |
| --- | --- |
| CAI-001–003 | Project Owner atomic Counter architecture acceptance, 2026-10-17; ADR-001; amended ADR-007 / CON-001 / CON-007 |
| CAI-010 | Project Owner Counter-child interaction decision, 2026-10-12; ADR-001 |
| CAI-020 | Project Owner Counter-child interaction decision, 2026-10-12; ADR-010 |
| CAI-030 | Project Owner composed-return acceptance decision, 2026-10-12; CON-007; SAI-030/SAI-035 |

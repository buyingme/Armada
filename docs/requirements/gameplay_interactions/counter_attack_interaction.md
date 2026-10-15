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

After the Counter child completes, satisfaction of its completed-result
inspection makes CON-007 release evaluation eligible and triggers
re-evaluation of the original activated Squadron. Satisfaction does not itself
consume the inspection.

If Move remains legal, the derived Move decision is the next live legal
decision and the satisfied inspection remains pending. The authoritative Move
or explicit Move-decline transaction consumes the matching inspection
atomically with its canonical mutation. If no legal Squadron action remains,
the existing authoritative Squadron-completion transaction consumes the
matching inspection atomically. Further return proceeds through the existing
Squadron Phase or commanded-Squadron/Ship Activation owners until the next
canonical stable state or live legal decision is reached.

Child attack termination, terminal publication, or satisfied-but-unconsumed
inspection without the corresponding live Move decision is not completion of
this composed-return boundary. The inspection must never be consumed merely to
expose a derived decision.

## 3. Explicit non-goals

These requirements do not introduce a Counter-specific lifecycle owner,
continuation stack, generic activation state machine, fallback authority, or
new persisted state. Detailed Counter eligibility and dice rules remain with
their applicable rules authority.

## 4. Traceability

| Requirement | Decision / authority source |
| --- | --- |
| CAI-010 | Project Owner Counter-child interaction decision, 2026-10-12; ADR-001 |
| CAI-020 | Project Owner Counter-child interaction decision, 2026-10-12; ADR-010 |
| CAI-030 | Project Owner composed-return acceptance decision, 2026-10-12; CON-007; SAI-030/SAI-035 |

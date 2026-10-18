# Boundary B Counter Intermediate Publication — Architecture-Proof Checkpoint

Status: **Draft evidence and proposed contract correction; Owner decision required.**
Boundary B implementation remains stopped. This document does not amend accepted
authority or authorize implementation. Scope: BC-009 / AT-008 and the accepted
BUG-074 Replay-12 Counter transition at sequences 58–60.

## Authority and observed history

- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
  and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
  make `CurrentAttackState` the attack-fact authority; `InteractionFlow`, its
  scene FSM, and UI are non-authoritative projection/routing surfaces.
- [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md)
  requires the same legal decision after supported reconstruction, including
  Network reconnect, while permitting disposable presentation work.
- [Counter interaction requirements](../../requirements/gameplay_interactions/counter_attack_interaction.md)
  require an accepted Counter child to enter locked Declare and then ordinary
  Roll, with composed return through existing owners. They do not define a
  separate intermediate Counter decision or new owner.
- [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md)
  requires ordered replay, passive Network application without synthesized
  continuations, and reconstruction before release evaluation.
- [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md)
  requires canonical gameplay facts and legal decisions to survive Network
  resume without deriving player authority from an endpoint or UI. [ADR-013](../adr/ADR-013-passive-network-damage-state-representation.md)
  requires the passive canonical representation to remain equivalent after
  each accepted command sequence; it does not grant a Counter exception.
- The accepted [Boundary A workbook](../implementation_workbooks/interaction-flow-integer-reconstruction-repair-implementation-workbook.md)
  and [Counter parent-identity resolution](counter-parent-identity-save10-roundtrip-resolution.md)
  currently require all four Counter identities at every reconstructed
  `ATTACK_COUNTER_CHOICE` flow. Missing or partial identity rejects the flow
  and enclosing `GameState`, regardless of decision availability.
- The accepted [Replay-12](../../qa/bugs/closed/BUG-074/replay_20261015_065840.json)
  records sequence 58 as a non-final `ATTACK_COUNTER_CHOICE` publication for
  `attack:47` with outer controller 1 and the retained parent-attack payload,
  but without `counter_attack_available`, `counter_controller_player`,
  `counter_dice_pool`, payload `controller_player`, or any of the four Counter
  participant identities. Sequence 59 retains that attack payload and adds
  `counter_attack_available=true`, both controller fields as 1, BLUE Counter
  dice 2, and identities attacker `(1,0)` / target `(0,0)`. Sequence 60 is
  player 1's accepted `counter_choice` with matching identities.

The existing [AttackExecutor](../../../src/scenes/game_board/attack_executor.gd)
generates the two publications by advancing and publishing the Counter step,
then patching and publishing the Counter payload. Each is a separate ordered
Network command. Hot-Seat mutates the local projection without those
publications; replay applies the recorded commands without reproducing the
scene callback. Sequence 58 is therefore a **transient projection artifact as
gameplay authority**, but an **accepted command-applied state boundary** in
Network/replay history. Calling it transient does not make a snapshot or an
interactive pause at that cursor safely reconstructible.

## Current safety and recovery findings

| Boundary | Sequence-58 behavior | Consequence |
|---|---|---|
| Counter legality | `CounterChoiceCommand` and Counter's rule validator require `counter_attack_available`; the command also checks controller and all four matching identities. `BeginAttackCommand` and Counter child continuation require the accepted choice and identities. | No legal Counter choice or child follows from sequence 58 alone. Missing fields must never be defaulted into a choice. |
| Projection | `UIProjector` selects the Counter modal and interactivity from step and outer controller. Counter's affordance hook returns no Counter action while availability is absent. The Network mirror panel lacks payload controller and cannot submit. | A modal/interactive shell can be shown before an actionable choice exists. Proof must assert no enabled Counter action or child in both role mappings, rather than treating modal visibility as authority. |
| State reconstruction | `InteractionFlow.deserialize()` rejects sequence 58 because the four identities are missing; `GameState.deserialize()` and the Network state filter fail with it. | Existing Boundary A cannot reconstruct a command boundary the producer and accepted replay expose. Ordinary named Save 10 is gated away from this step, but that gate does not establish Network/replay safety. |
| Reconnect and replay | A passive peer receives ordered publications; a reconnect snapshot can be requested at a command cursor. Replay-12 must apply sequence 58, then 59, then 60 without rewriting history or synthesizing 59. | Continuous playback may move immediately to 59, but cursor-58 filtering/reconnect and any interactive pause are unproven and currently fail or lack the decision. |
| Canonical facts and recovery | `CurrentAttackState` holds parent participant player/index and attack kind; Squadron state supplies Counter keyword eligibility and dice. `CurrentAttackContinuation._counter_decision_pending()` derives eligibility from those owners. After sequence 60, the existing accepted-choice marker and matching parent identities in `InteractionFlow`, plus the canonical inspection, govern the child/release boundary. The current resolved-attack scene resume plan instead returns to `RESOLVE_DAMAGE` and does not rebuild the Counter choice. | Existing owners are factually sufficient to derive eligibility and participants; **implemented decision-equivalent recovery from sequence 58 is not proven**. No new field or owner is justified by this evidence. The exact reconstruction path needs proof before acceptance. |
| Composed return | Accepted choice/inspection and child Begin have separate exact identity and release checks. | Sequence 58 cannot substitute for the accepted parent projection, consume inspection, or initiate child/return. |

## Smallest proposed correction — requires Owner acceptance

**Decision requested:** May a separately recorded, non-actionable
`ATTACK_COUNTER_CHOICE` publication with no Counter identities be a supported
reconstructible command boundary? The following is a proposed narrow amendment,
not current authority:

1. At this step, `counter_attack_available` may be absent or the literal
   boolean `false` only for an **inert** Counter projection. With that shape,
   all four participant identities may be absent together. An absent/false
   value does not grant Counter choice, child Begin, inspection release, or a
   Counter affordance. `counter_choice_accepted` must be absent or false.
2. Literal `true` makes the Counter choice actionable only with all four
   valid identities. The established field-specific integer ranges and JSON
   integer restoration apply. Existing controller, dice-pool, active-attack,
   source-identity, rule-legality, and accepted-child checks remain required.
3. If any identity is present, **all four** must be present and valid. A full
   set with availability absent/false remains inert, preserving the previously
   accepted complete-identity shape; a partial set rejects. Malformed identity
   types/values, malformed availability or accepted flags, and a true accepted
   flag without an actionable choice reject. No field is inferred or defaulted
   from the parent attack during deserialization.
4. Any present optional declared Counter controller or dice member retains
   its existing field-specific validation. Unknown-field compatibility and
   the command's complete legality checks remain unchanged. The special
   absent-identity allowance is limited to this one step and only when
   availability is absent/false.
5. Boundary A's step-level four-field presence rule and Boundary B's matching
   publication rule would need an explicit Owner-approved adjustment.
   Reconstruction of sequence 58 must preserve its exact payload and hash;
   sequence 59 must restore the complete actionable shape. Neither repair may
   introduce another Counter lifecycle or continuation owner.

An alternative is to make future Counter publication atomic and treat the
recorded sequence 58 as a bounded legacy replay case. That still needs an
explicit compatibility/reconstruction policy for the immutable accepted
history and independently delivered Network commands. Current accepted
authority does not choose between these policies. **STOP before changing
Boundary A, Boundary B, UI/recovery, or publication semantics.**

## Architecture-proof obligations before implementation acceptance

1. In both host/player role mappings, produce the genuine 58-like then
   59-like Network sequence. At each cursor compare host/passive flow form,
   controller, legal affordances, command history/sequence, and absence or
   presence of Counter choice. Test interrupted delivery after the first
   publication and subsequent ordered application.
2. JSON-roundtrip the exact sequence-58 and sequence-59 flows through both
   full-authority and passive reconstruction. Compare exact flow serialization
   and canonical flow hash. Check full-state hashes only after unrelated state
   is separately stable; fail closed on Boundary C or other divergence.
3. At cursor 58, test absent and literal-false availability; all identities
   absent, all four valid, partial identity, malformed scalar/nested values,
   malformed booleans, and contradictory accepted flag. Wrong shapes must
   reject without mutation of state, command history, sequence, or follow-up
   queue. A valid inert shape must not expose or accept `counter_choice` or
   derive child Begin, including after UI rebuild/reconnect.
4. At cursor 59, require valid four-field identity, exact integer restoration,
   correct controller and Counter pool, an actionable choice in both role
   mappings, and rejection of every missing/partial/malformed identity.
5. Load and execute all 83 immutable Replay-12 commands in order, including
   58→59→60; compare the accepted final hash and existing baseline. Pause at
   58 and verify no synthesized publication or decision. Keep formats Save 10,
   Network 11, Replay 12 and all fixtures/hashes unchanged.
6. From reconstructed actionable Counter state, verify accepted choice,
   inspection satisfaction, exactly-once child Begin, locked Declare, Roll,
   and CON-007 composed return under both role mappings. Separately prove
   whether cursor-58 reconnect can resume safely from canonical parent attack
   and Squadron facts without scene-local pending tokens; if not, stop rather
   than inventing state or ownership.

## Existing 88-failure full-suite run

The stopped [Boundary B proposal](../implementation_workbooks/attack-publication-command-codec-integer-reconstruction-repair-proposal.md)
records 4,380/4,468 passing and 88 failing, but **does not retain a failure
list**. The retained Boundary B temporary log is the Replay-12 execution log,
not that full-suite run. Earlier retained full-suite logs have
different test counts: Boundary A 4,461/4,461 passed; one prior sandboxed
Ship-ordinal run had 69 failures, including fleet-library write/UI failures,
and its later unsandboxed 4,450/4,450 run passed. Those logs cannot classify
the later 88 individually. Current classification is **88 unverified by
retained failure log**; Counter-contract failures are plausible for tests
constructing partial Counter flows, while fleet-library failures previously
had an unrelated environmental cause. No count may be assigned to either
class without the missing run artifact. Do not rerun the full suite solely
for this checkpoint.

## Stop gates and audit status

- No Boundary B coding, replay rewrite, fixture/hash promotion, or accepted
  Boundary A change before the Owner selects and records a contract policy.
- Stop on a cursor-58 reconstruction/recovery failure, an actionable inert
  projection, a child/inspection side effect, a Network role divergence, a
  changed accepted replay hash, an unexplained whole-state divergence, or a
  need for new canonical fields/owners.
- The 88 failures cannot be treated as classified or waived from the available
  retained logs. Their classification needs the original run output or a
  separately authorized later verification run.

**NOT READY for independent acceptance audit.** This is a reviewable evidence
checkpoint and Owner decision request, not an accepted amendment.
